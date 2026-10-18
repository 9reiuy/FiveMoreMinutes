extends SceneTree

const DUNGEON_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PALETTE_SHADER: Shader = preload("res://shaders/palette_quantize.gdshader")
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/7b4560e6-4b84-4f9d-aa7f-8e2769c901c9/"

func _init() -> void:
	call_deferred("_run_capture")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func _run_capture() -> void:
	print("--- STARTING FORMAL SCREENSHOT CAPTURE ---")
	var dungeon = DUNGEON_SCENE.instantiate()
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

	dungeon.regenerate(7777)
	await frames(10)

	# Ensure flashlight is completely OFF
	if dungeon.night_lighting != null and dungeon.night_lighting.flashlight != null:
		dungeon.night_lighting.flashlight.visible = false
		dungeon.night_lighting.flashlight.light_energy = 0.0

	var target_rooms := {}
	for room in dungeon.rooms:
		var arch: String = room.get("archetype", "")
		if (arch == "office" or arch == "open_office") and not target_rooms.has("office"):
			target_rooms["office"] = room.id
		elif arch == "conference" and not target_rooms.has("conference"):
			target_rooms["conference"] = room.id
		elif arch == "lounge" and not target_rooms.has("lounge"):
			target_rooms["lounge"] = room.id
		elif arch == "storage" and not target_rooms.has("storage"):
			target_rooms["storage"] = room.id

	print("Target rooms found: ", target_rooms)

	var archetypes := ["office", "conference", "lounge", "storage"]
	for arch in archetypes:
		var r_id: int = target_rooms.get(arch, -1)
		if r_id < 0:
			print("Warning: Room for ", arch, " not found in seed 7777")
			continue
		
		var room: Dictionary = dungeon.rooms[r_id]
		var center_cell: Vector2i = room.get("center_cell", Vector2i.ZERO)
		var center_pos: Vector2 = Vector2(center_cell) * 32.0

		dungeon.current_room_id = r_id
		dungeon._set_active_presentation_room(r_id)
		dungeon._rebuild_active_room_presentation()

		if dungeon.player != null:
			dungeon.player.position = center_pos
			dungeon.player.global_position = center_pos
		dungeon._update_camera_and_actor_projection()
		await frames(8)

		# Ensure flashlight stays OFF
		if dungeon.night_lighting != null and dungeon.night_lighting.flashlight != null:
			dungeon.night_lighting.flashlight.visible = false
			dungeon.night_lighting.flashlight.light_energy = 0.0

		# Capture with Palette ON
		mat.set_shader_parameter("palette_enabled", true)
		await frames(5)
		var img_on := root.get_viewport().get_texture().get_image()
		if img_on != null:
			var path_on := ARTIFACT_DIR + "room_%s_palette_on.png" % arch
			img_on.save_png(path_on)
			print("Saved: ", path_on)

		# Capture with Palette OFF
		mat.set_shader_parameter("palette_enabled", false)
		await frames(5)
		var img_off := root.get_viewport().get_texture().get_image()
		if img_off != null:
			var path_off := ARTIFACT_DIR + "room_%s_palette_off.png" % arch
			img_off.save_png(path_off)
			print("Saved: ", path_off)

	# Capture AFTER comparison (Room 2, exact same vantage as before)
	mat.set_shader_parameter("palette_enabled", true)
	dungeon.current_room_id = 2
	dungeon._set_active_presentation_room(2)
	dungeon._rebuild_active_room_presentation()
	if dungeon.player != null:
		dungeon.player.position = Vector2(-500.0, -520.0)
		dungeon.player.global_position = Vector2(-500.0, -520.0)
	dungeon._update_camera_and_actor_projection()
	if dungeon.night_lighting != null and dungeon.night_lighting.flashlight != null:
		dungeon.night_lighting.flashlight.visible = false
		dungeon.night_lighting.flashlight.light_energy = 0.0
	await frames(8)
	var img_compare := root.get_viewport().get_texture().get_image()
	if img_compare != null:
		var path_compare := ARTIFACT_DIR + "comparison_after_ambient.png"
		img_compare.save_png(path_compare)
		print("Saved: ", path_compare)

	dungeon.queue_free()
	canvas_layer.queue_free()
	print("--- FORMAL SCREENSHOT CAPTURE COMPLETE ---")
	quit(0)
