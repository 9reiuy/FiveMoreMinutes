extends "res://tests/forklift_combat_test.gd"
## Boarding-specific native Camera trace, before changing any production rendering.

var records: Array[Dictionary] = []
var original_camera := Transform3D.IDENTITY
var original_rig := Transform3D.IDENTITY
var original_fov := 35.0
var environment: Environment


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	print("BOARDING_PROBE_PID ", OS.get_process_id())
	create_timer(180.0).timeout.connect(func() -> void: push_error("boarding probe timed out"); quit(1))
	call_deferred("run")


func sample_boarding(label: String, count: int, fixed_camera := false, pan := false) -> void:
	var folder := evidence.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for i in count:
		await physics_frame
		await process_frame
		if fixed_camera:
			world.camera_rig.transform = original_rig
			world.camera_3d.global_transform = original_camera
			world.camera_3d.fov = original_fov
			if pan: world.camera_rig.position += Vector3(sin(float(i) / float(count - 1) * TAU) * 1.6, 0, 0)
		await RenderingServer.frame_post_draw
		var bridge = world.player_depth_bridge
		records.append({"label": label, "frame": i, "floor": lift.floor_height,
			"vehicle": lift.visual.global_position, "feet": world._feet(),
			"ground": bridge.ground_surface_height, "actor": bridge.actor_sprite.global_position,
			"camera": world.camera_3d.global_transform, "fov": world.camera_3d.fov,
			"elevation": world._camera_elevation, "mounted": lift.driver == world.player,
			"ssr": environment.ssr_enabled, "glow": environment.glow_enabled,
			"bullets": get_nodes_in_group(&"dream_projectiles").size(),
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0})
		root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	print("BOARDING_CASE ", label)


func run() -> void:
	evidence = OS.get_environment("FLICKER_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter_chapter(CHAPTER.Save.CALIBRATED)
	world.restart_queued = true
	for enemy in world.enemy_root.get_children(): enemy.queue_free()
	await frames(6)
	park(PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, 0.13))
	world.player.invulnerability_left = 120.0
	await frames(40)
	check(lift.can_board(world.player), "normal 1-2 entrance allows boarding")
	environment = world.get_world_3d().environment
	original_camera = world.camera_3d.global_transform
	original_rig = world.camera_rig.transform
	original_fov = world.camera_3d.fov
	await sample_boarding("on_foot", 36, true)
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == world.player, "E boards the actual chapter forklift")
	await sample_boarding("boarded_transition", 60)
	await sample_boarding("boarded_fixed", 60, true)
	await sample_boarding("boarded_pan", 96, true, true)
	environment.ssr_enabled = false
	await frames(12)
	await sample_boarding("boarded_no_ssr", 96, true, true)
	environment.ssr_enabled = true
	lift.visual.set_driver_onboard(false)
	await frames(12)
	await sample_boarding("boarded_parked_materials", 96, true, true)
	lift.visual.set_driver_onboard(true)
	world.player_depth_bridge.hide()
	await frames(12)
	await sample_boarding("boarded_no_actor", 96, true, true)
	world.player_depth_bridge.show()
	check(lift.try_exit(), "driver can exit after the rendering comparison")
	await frames(24)
	await sample_boarding("on_foot_after", 96, true, true)
	verify_audio()
	FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"records": records, "checks": checks, "failures": failures, "pid": OS.get_process_id(),
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"scope": "1-2 boarding trigger. Native muted actual Camera; diagnostic frame readbacks are not performance certification."}, "\t"))
	print("BOARDING_PROBE frames=", records.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
