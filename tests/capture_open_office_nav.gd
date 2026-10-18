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

	dungeon.regenerate(42001)
	await frames(15)

	var open_room_id := 0
	var conn_room_id := 3
	dungeon.current_room_id = conn_room_id
	dungeon._set_active_presentation_room(open_room_id)
	dungeon._rebuild_active_room_presentation()

	# Open edges between room 0 and room 3
	var open_edges: Array[Dictionary] = dungeon._get_open_boundary_edges_between(open_room_id, conn_room_id)
	var boundary_pos: Vector2 = Vector2.ZERO
	if not open_edges.is_empty():
		boundary_pos = dungeon._boundary_edge_center_pixels(open_edges[open_edges.size() / 2])
	else:
		var c0: Vector2 = Vector2(dungeon.rooms[open_room_id]["center_cell"]) * 32.0
		var c3: Vector2 = Vector2(dungeon.rooms[conn_room_id]["center_cell"]) * 32.0
		boundary_pos = (c0 + c3) * 0.5

	# Position player on the hallway side (Room 3)
	var player_pos: Vector2 = boundary_pos + Vector2(0.0, 70.0)
	if dungeon.player != null:
		dungeon.player.position = player_pos
		dungeon.player.global_position = player_pos
		if dungeon.player.has_method("set_aim_direction"):
			dungeon.player.call("set_aim_direction", Vector2(0.0, -1.0))

	# Spawn/position enemy in Room 0 (Open Office) aiming straight at player across boundary
	var enemy_pos: Vector2 = boundary_pos + Vector2(0.0, -50.0)
	var enemy: EmployeeEnemy = null
	if dungeon.enemy_root != null and dungeon.enemy_root.get_child_count() > 0:
		enemy = dungeon.enemy_root.get_child(0) as EmployeeEnemy
	if enemy == null:
		enemy = dungeon.EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
		dungeon.enemy_root.add_child(enemy)

	enemy.global_position = enemy_pos
	enemy.position = enemy_pos
	enemy.set_meta(&"dream_room_id", open_room_id)
	enemy.target = dungeon.player
	enemy.last_known_target_position = player_pos
	enemy.has_last_known_target_position = true
	enemy.last_known_room = conn_room_id
	enemy.held_weapon_id = "revolver"
	enemy.hostile = true
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	enemy.can_see_target = true

	# Aim flashlight
	if dungeon.get("night_lighting") != null:
		dungeon.night_lighting.set_flashlight_enabled(true)
		dungeon.night_lighting.aim_flashlight(player_pos, enemy_pos)

	# Simulate 30 physics frames of direct pursuit across the boundary
	for f in range(30):
		enemy._update_attack_player(0.016)
		enemy.global_position += enemy.velocity * 0.016
		dungeon.sync_employee_ground_region(enemy)
		await physics_frame
		await process_frame

	dungeon._update_camera_and_actor_projection()
	await frames(10)
	await RenderingServer.frame_post_draw

	var tex := root.get_texture()
	if tex != null:
		var img := tex.get_image()
		var out_path := ARTIFACT_DIR + "shot_open_office_nav_cross.png"
		img.save_png(out_path)
		print("Saved open office nav screenshot to ", out_path)

	quit(0)
