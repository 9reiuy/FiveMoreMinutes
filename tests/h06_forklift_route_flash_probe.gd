extends "res://tests/h06_forklift_boarding_probe.gd"
## The user's full route: normal entry, calibration E, drive, dismount, shoot.

var shooting := false

func shoot(held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = held
	event.position = Vector2(980, 315)
	Input.parse_input_event(event)
	world.player.set_meta(&"force_weapon_attack", held)


func trace_case(label: String, count: int, fire := false, pointer_pan := false) -> void:
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for i in count:
		if fire and i % 22 == 0: shoot(true)
		if fire and i % 22 == 3: shoot(false)
		if pointer_pan:
			var event := InputEventMouseMotion.new()
			event.position = Vector2(640 + sin(float(i) / float(count) * TAU) * 420, 290)
			Input.parse_input_event(event)
		await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var lights: Array[Dictionary] = []
		for light: Light3D in world.find_children("*", "Light3D", true, false):
			if light.is_visible_in_tree() and light.light_energy > 0:
				lights.append({"path": str(world.get_path_to(light)), "at": light.global_position,
					"energy": light.light_energy, "range": light.omni_range if light is OmniLight3D else 0})
		records.append({"label": label, "frame": i, "mounted": lift.driver == world.player,
			"vehicle": lift.visual.global_position, "floor": lift.floor_height, "feet": world._feet(),
			"camera": world.camera_3d.global_transform, "fov": world.camera_3d.fov,
			"lights": lights, "bullets": get_nodes_in_group(&"dream_projectiles").size(),
			"player_dead": world.player.dead, "hp": lift.hp})
		root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	shoot(false)
	print("ROUTE_CASE ", label, " feet=", world._feet(), " mounted=", lift.driver == world.player)


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.ENTRANCE)
	world.player.invulnerability_left = 180.0
	place_feet(Vector2(-5.5, -18.5))
	await frames(60)
	check(world.checkpoint == CHAPTER.Save.OBSERVATION, "normal entry visits the observation room")
	place_feet(Vector2(-5.5, -23.4))
	await frames(60)
	check(await walk_to(Vector2(-5.5, -26.0)), "player walks through the normal 1-1 to 1-2 passage")
	await frames(100)
	check(world.blockout.visit == PLAN.Visit.WEST, "normal streamed entry activates 1-2")
	lift = world.blockout.forklift
	place_feet(PLAN.GALLERY_CONSOLE + Vector2(0, .6))
	await frames(5)
	await key(KEY_E)
	await key(KEY_E, false)
	check(not world.blockout.closed.calibration, "E opens the 1-2 checkpoint before boarding")
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, .13))
	await frames(16)
	await trace_case("before_boarding", 36)
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == world.player, "E boards after the door has been opened")
	await trace_case("after_boarding", 36)
	# Clear the inspection bench before turning toward the checkpoint opening.
	Input.action_press("move_up")
	for i in 120:
		await physics_frame
		if lift.global_position.y / 32.0 < -30.1: break
	Input.action_release("move_up")
	park(Vector2(lift.global_position.x / 32.0, -30.1), -PI)
	Input.action_press("move_up")
	for i in 360:
		await physics_frame
		if lift.global_position.x / 32.0 < -18.5 or lift.destroyed: break
	Input.action_release("move_up")
	await trace_case("in_middle_driving", 1)
	check(lift.global_position.x / 32.0 < -14.0 and not lift.destroyed, "forklift reaches the central warehouse through the open door")
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == null and world.player.mounted_vehicle == null, "E dismounts in the warehouse center")
	await trace_case("dismounted_before_shooting", 48, false, true)
	await trace_case("dismounted_shooting", 132, true, true)
	await trace_case("after_shooting_pan", 132, false, true)
	verify_audio()
	FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"records": records, "checks": checks, "failures": failures, "pid": OS.get_process_id(),
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"scope": "Normal chapter entrance -> streamed 1-2 -> E calibration -> E board -> W drive center -> E exit -> fire -> pan. Real AI retained."}, "\t"))
	print("ROUTE_PROBE frames=", records.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
