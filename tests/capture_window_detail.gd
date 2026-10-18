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

	# Position player right near the window in room 1
	var office_room_id := 1
	dungeon.current_room_id = office_room_id
	dungeon._set_active_presentation_room(office_room_id)
	dungeon._rebuild_active_room_presentation()
	
	var off_room: Dictionary = dungeon.rooms[office_room_id]
	var off_center: Vector2i = off_room.get("center_cell", Vector2i.ZERO)
	var win_pos: Vector2 = Vector2(float(off_center.x) - 2.0, float(off_center.y) + 3.5) * 32.0
	if dungeon.player != null:
		dungeon.player.position = win_pos
		dungeon.player.global_position = win_pos
	dungeon._update_camera_and_actor_projection()
	await frames(10)
	await RenderingServer.frame_post_draw

	var tex := root.get_texture()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			img.save_png(ARTIFACT_DIR + "shot_2_window_wall_cutaway.png")
			print("Saved updated shot_2_window_wall_cutaway.png")

	dungeon.queue_free()
	canvas_layer.queue_free()
	quit(0)
