extends SceneTree

const DUNGEON_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PALETTE_SHADER: Shader = preload("res://shaders/palette_quantize.gdshader")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/"

func _initialize() -> void:
	call_deferred("_run_capture")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run_capture() -> void:
	var dungeon: Node = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	root.add_child(dungeon)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 1000
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE_SHADER
	mat.set_shader_parameter("palette_enabled", true)
	overlay.material = mat
	canvas_layer.add_child(overlay)
	root.add_child(canvas_layer)

	dungeon.regenerate(41001)
	await frames(15)

	# Position player in Room 1 near the desks and enemy
	var office_room_id := 1
	dungeon.current_room_id = office_room_id
	dungeon._set_active_presentation_room(office_room_id)
	dungeon._rebuild_active_room_presentation()
	
	var off_room: Dictionary = dungeon.rooms[office_room_id]
	var off_center: Vector2i = off_room.get("center_cell", Vector2i.ZERO)
	var pos: Vector2 = Vector2(float(off_center.x), float(off_center.y)) * 32.0
	if dungeon.player != null:
		dungeon.player.position = pos
		dungeon.player.global_position = pos
		# Aim flashlight towards the enemy/desks to illuminate them
		if dungeon.player.has_method("set_aim_direction"):
			dungeon.player.call("set_aim_direction", Vector2(1, -0.5).normalized())
	if dungeon.get("night_lighting") != null:
		dungeon.night_lighting.set_flashlight_enabled(true)
		var aim_target: Vector2 = pos + Vector2(100.0, -40.0)
		dungeon.night_lighting.aim_flashlight(pos, aim_target)
	dungeon._update_camera_and_actor_projection()
	await frames(10)
	await RenderingServer.frame_post_draw

	# 1. Capture with reduced character lighting (character_light_scale = 0.50)
	var tex := root.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png(ARTIFACT_DIR + "shot_character_lighting_reduced.png")
			print("Saved shot_character_lighting_reduced.png")

	# 2. For side-by-side comparison, temporarily set character_light_scale = 1.0 on depth bridges
	var bridges = root.get_tree().get_nodes_in_group(&"actor_depth_bridges")
	for b in root.find_children("*", "Node3D", true, false):
		var sprite = b.get_node_or_null("DepthVisual") as Sprite3D
		if sprite != null and sprite.material_override is ShaderMaterial:
			var sm := sprite.material_override as ShaderMaterial
			if sm.get_shader_parameter("character_light_scale") != null and float(sm.get_shader_parameter("character_light_scale")) < 0.9:
				sm.set_shader_parameter("character_light_scale", 1.0)

	await frames(5)
	await RenderingServer.frame_post_draw

	tex = root.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png(ARTIFACT_DIR + "shot_character_lighting_baseline.png")
			print("Saved shot_character_lighting_baseline.png")

	dungeon.queue_free()
	canvas_layer.queue_free()
	quit(0)
