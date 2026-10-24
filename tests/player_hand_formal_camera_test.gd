extends "res://tests/phone_tab_delivery.gd"
const HANDS = preload("res://scripts/entities/player_hand_presentation.gd")
func render_pose() -> void:
	world.player_depth_bridge._process(0.0)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"): quit(2); return
	output = "res://.runtime/player_hand_symmetry_20261023"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	main._show_dream("basic")
	await ready_main()
	world = main._supported_dream_world
	var deadline := Time.get_ticks_msec() + 60000
	while world.floor_transition_in_progress and Time.get_ticks_msec() < deadline: await wait(0.05)
	check(not world.floor_transition_in_progress, "Actual Main enters formal floor")
	var player = world.player
	check(player.hand_presentation != null, "Formal Main player owns hand presentation")
	check(world.player_depth_bridge.character_projection, "Formal separated 3D projection remains active")
	# Use a clear generated office so foreground entrance walls cannot hide
	# the very grip pixels this acceptance recording needs to inspect.
	var found := false
	for room in world.rooms:
		if String(room.get("archetype", "")) != "open_office": continue
		for cell in room.get("usable_cells", []):
			var point := Vector2(cell) * 32.0
			if world._content_position_is_clear(point, 85.0):
				player.global_position = point
				world.activate_room(int(room.id))
				found = true
				break
		if found: break
	check(found, "A clear formal office is available for camera acceptance")
	player.invulnerability_left = 1000.0
	await wait(0.2)
	var start: Vector2 = player.global_position
	Input.action_press("move_right")
	await wait(0.15)
	Input.action_release("move_right")
	check(player.global_position.distance_to(start) > 3.0, "Normal formal-player movement input still works")
	player.velocity = Vector2.ZERO
	await wait(0.1)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	player.invulnerability_left = 0.0
	player.visual.visible = true
	player.visual.modulate = Color.WHITE
	var frame_index := 0
	var bat_grips: Dictionary = {}
	for id in ["lucille", "basic", "assault_rifle", ""]:
		player.configure_weapon(id, load("res://resources/demo_config.tres"), {})
		for index in 8:
			var aim := Vector2.from_angle(index * TAU / 8.0)
			player.last_aim_direction = aim
			player.set_meta(&"aim_direction_override", aim)
			player._update_direction_animation(Vector2.ZERO, 1.0 / 60.0)
			player._update_held_weapon_aim()
			await render_pose()
			var grip_copy: Node2D = world.player_depth_bridge.weapon_capture_root.find_child("PlayerGripHands", true, false)
			check(grip_copy != null, "Formal weapon plane contains hands %s/%d" % [id, index])
			if grip_copy != null:
				check(grip_copy.visible == not id.is_empty(), "Passive copy follows actual hand visibility")
				if id == "lucille":
					var weapon_copy := grip_copy
					while weapon_copy.get_parent() != world.player_depth_bridge.weapon_capture_root:
						weapon_copy = weapon_copy.get_parent()
					var main_grip: Node2D = grip_copy.get_node("RightGrip")
					bat_grips[index] = main_grip.global_position - weapon_copy.global_position
			root.get_texture().get_image().save_png(output.path_join("pose_%03d.png" % frame_index))
			frame_index += 1
	for index in 4:
		check(((bat_grips[index] + bat_grips[index + 4]) * 0.5).distance_to(Vector2(0, 18)) < 0.1,
			"Actual weapon capture keeps opposite grips centred without sideways drift %d" % index)
	player.configure_weapon("lucille", load("res://resources/demo_config.tres"), {})
	for frame in 60:
		var aim := Vector2.RIGHT
		player.last_aim_direction = aim
		player.set_meta(&"aim_direction_override", aim)
		var elapsed := float(frame % 15 + 1) / 60.0
		player.apply_melee_swing_snapshot({"weapon_id": "lucille", "direction": aim,
			"elapsed": elapsed, "duration": 0.25, "angle": lerpf(-1.2, 1.2, elapsed / 0.25), "opacity": 1.0})
		await render_pose()
		root.get_texture().get_image().save_png(output.path_join("swing_%03d.png" % frame))
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED, "GPU capture does not steal focus")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Actual Main -> formal random-floor Camera3D, controlled poses and existing melee snapshots"}, "\t"))
	file.close()
	print("PLAYER_HAND_FORMAL checks=", checks, " failures=", failures.size())
	main.free()
	quit(0 if failures.is_empty() else 1)
