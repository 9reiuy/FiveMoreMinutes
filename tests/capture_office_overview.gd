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
	print("--- STARTING OFFICE OVERVIEW SCREENSHOT CAPTURE ---")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.persist_profile = false
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

	dungeon.regenerate(42001)
	await frames(10)

	# Disable combat physics
	dungeon.player.set_physics_process(false)
	dungeon.player.invulnerability_left = 1000.0
	for enemy in dungeon.enemy_root.get_children():
		enemy.set_physics_process(false)

	# Targets to capture:
	# 1. Reception (Room 0) & Elevator
	# 2. Main Lobby (Room 1)
	# 3. Left Large Room (Room 4 - Open Office)
	# 4. Right Large Room (Room 5 - Conference)
	var targets = [
		{"name": "shot_office_reception_area.png", "room_id": 0},
		{"name": "shot_office_main_lobby.png", "room_id": 1},
		{"name": "shot_office_large_room_left.png", "room_id": 4},
		{"name": "shot_office_large_room_right.png", "room_id": 5},
	]

	for t in targets:
		var r_id: int = int(t["room_id"])
		var room_center: Vector2i = dungeon.rooms[r_id].center_cell
		var target_pos: Vector2 = Vector2(room_center) * dungeon.CELL_PIXELS

		dungeon.player.global_position = target_pos
		dungeon.activate_room(r_id)
		await frames(10)

		if dungeon.camera_3d != null:
			var world_target: Vector3 = dungeon._map_gameplay_to_world(target_pos)
			var offset: Vector3 = dungeon.camera_3d.offset_position if "offset_position" in dungeon.camera_3d else Vector3(0, 18, 12)
			dungeon.camera_3d.global_position = world_target + offset
			dungeon.camera_3d.look_at(world_target, Vector3.UP)

		await frames(5)
		await RenderingServer.frame_post_draw

		var img: Image = root.get_texture().get_image()
		var out_path: String = ARTIFACT_DIR + String(t["name"])
		img.save_png(out_path)
		print("Saved screenshot to: ", out_path)

	dungeon.free()
	canvas_layer.free()
	await frames(4)
	print("--- CAPTURE FINISHED ---")
	quit(0)
