extends "res://tests/forklift_combat_test.gd"
## No firing and no moving actors: pan the real Camera only through the presentation pointer.
var observations: Array[Dictionary] = []
var source_lights: Array[Dictionary] = []
var source_environment: Environment
var source_ssr := false
var source_glow := false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("CAMERA_SPARKLE_PID ", OS.get_process_id())
	create_timer(120.0).timeout.connect(func() -> void: push_error("camera diagnostic timed out"); quit(1))
	call_deferred("run")


func pointer(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	current_scene.presentation._input(event)


func camera_path(label: String, ssr: bool, specular: bool, glow: bool) -> void:
	source_environment.ssr_enabled = ssr
	source_environment.glow_enabled = glow
	for state in source_lights:
		var light: Light3D = state.node.get_ref()
		if is_instance_valid(light): light.light_specular = state.specular if specular else 0.0
	world.camera_aim_offset = Vector3.ZERO
	pointer(Vector2(640, 360))
	await frames(20)
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 144:
		var phase := i * TAU / 144.0
		pointer(Vector2(640 + 530 * sin(phase), 360 + 300 * cos(phase)))
		await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var camera: Camera3D = world.camera_3d
		var row := {"case": label, "frame": i, "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
			"fov": camera.fov, "ssr": source_environment.ssr_enabled, "glow": source_environment.glow_enabled,
			"enemies": world.enemy_root.get_child_count(), "projectiles": get_nodes_in_group(&"dream_projectiles").size(),
			"muzzles": world.floor_root.has_node("FirearmFlashFX"), "player": str(world.player.global_position),
			"crate_screen": camera.unproject_position(world.to_global(Vector3(-21.2, 4.84, -16.4)))}
		observations.append(row)
		if i % 2 == 0:
			root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	check(get_nodes_in_group(&"dream_projectiles").is_empty() and world.enemy_root.get_child_count() == 0,
		label + " has no enemies or bullets")
	print("CAMERA_SPARKLE_PATH ", label)


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.PUMP)
	world.restart_queued = true
	for enemy in world.enemy_root.get_children(): enemy.queue_free()
	await frames(4)
	place_feet(Vector2(-25.5, -18.7))
	world.player.movement_enabled = false
	world.player.set_attacking_enabled(false, true)
	source_environment = world.camera_3d.environment
	if source_environment == null:
		source_environment = world.get_node("Lighting/WorldEnvironment").environment
	source_ssr = source_environment.ssr_enabled
	source_glow = source_environment.glow_enabled
	print("CAMERA_SPARKLE_ENV ssr=", source_ssr, " glow=", source_glow)
	for light: Light3D in world.find_children("*", "Light3D", true, false):
		source_lights.append({"node": weakref(light), "specular": light.light_specular})
	await frames(30)
	await camera_path("original_a", source_ssr, true, source_glow)
	await camera_path("without_ssr", false, true, source_glow)
	await camera_path("without_specular", source_ssr, false, source_glow)
	await camera_path("without_glow", source_ssr, true, false)
	await camera_path("original_b", source_ssr, true, source_glow)
	check(observations.size() == 720, "all five camera paths completed")
	var file := FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"records": observations, "checks": checks, "failures": failures,
		"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(),
		"audio": AudioServer.get_driver_name(), "scope": "Stationary player, no enemies or bullets, pointer-driven real Camera. Temporary per-scene SSR/specular/glow exclusions; readbacks are diagnostic, not performance samples."}, "\t"))
	verify_audio()
	current_scene.queue_free()
	await frames(4)
	print("CAMERA_SPARKLE_PROBE frames=", observations.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
