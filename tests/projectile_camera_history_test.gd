extends SceneTree
## A real tutorial Camera and its GPU captures, not a substitute 2D drawing.
const OUT := "res://.runtime/projectile_history_projection_20261030"
const BULLET := preload("res://scenes/entities/basic_projectile.tscn")
var main: Node
var world: Node
var failures := 0
var checks := 0
var measurements: Array = []
var legacy := false
var formal := false
var enemy_shooter: Node2D

func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for i in count: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ", label)

func sample_error(bridge: Node3D, camera: Camera3D, expected: Vector2) -> float:
	var image: Image = bridge.render_viewport.get_texture().get_image()
	var best := INF
	for y in image.get_height():
		for x in image.get_width():
			# Match the actual spatial carrier's alpha scissor. Transparent
			# viewport compositing also affects the readback alpha of the old tail.
			if image.get_pixel(x, y).a <= .05: continue
			var local := Vector2(x + .5, y + .5) - Vector2(image.get_size()) * .5
			var point: Vector3 = bridge.actor_sprite.to_global(Vector3(local.x, -local.y, 0) / 32.)
			best = minf(best, expected.distance_to(camera.unproject_position(point)))
	return best

func verify(shot: Node2D, label: String) -> void:
	var bridge: Node3D = shot.get_meta(&"depth_visual_bridge").get_ref() if shot.has_meta(&"depth_visual_bridge") else null
	# Old tutorial registration omitted this metadata. Find its actual carrier
	# so the regression can still measure the pre-fix rendered result.
	if bridge == null:
		for candidate in world.actor_depth_bridges_root.get_children():
			if candidate.get("source_actor") == shot: bridge = candidate; break
	check(bridge != null, label + " has a live depth carrier")
	if bridge == null: return
	bridge._process(0.)
	await frames(3)
	var camera: Camera3D = world.camera_3d
	var origin: Vector3 = shot.get_meta(&"shot_visual_origin", world.to_global(Vector3(shot.position.x / 32., .65, shot.position.y / 32.)))
	var gameplay: Vector2 = shot.get_meta(&"shot_gameplay_origin", shot.position)
	var worst := 0.
	for index in range(2, shot._trail_history.size()):
		var point: Vector2 = shot._trail_history[index].position
		var delta := point - gameplay
		var expected := camera.unproject_position(origin + world.global_basis * Vector3(delta.x, 0, delta.y) / 32.)
		worst = maxf(worst, sample_error(bridge, camera, expected))
	measurements.append({"label": label, "max_screen_error_px": worst})
	check(worst < 3., "%s history aligns to Camera projection (%.3fpx)" % [label, worst])
	if not formal and label in ["direction_1", "direction_5", "camera_moved", "turn"]:
		root.get_texture().get_image().save_png(OUT + ("/before/" if legacy else "/") + label + ".png")

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(OUT)
	legacy = "--legacy" in OS.get_cmdline_user_args()
	formal = "--formal" in OS.get_cmdline_user_args()
	create_timer(150., true, false, true).timeout.connect(func(): quit(2))
	main = load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	await frames(90)
	main.persistent_day_state = main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume()
	await frames(150)
	world = main._supported_dream_world
	world.player.position = Vector2(4, 6) * 32.
	world.player.set_physics_process(false)
	world._update_camera_and_projection(0.)
	world.set_process(false)
	await frames(8)
	if formal:
		main.chapter_one.state.stage = "ASCENT"
		main._show_dream("basic")
		while main.transition_running: await process_frame
		world = main._supported_dream_world
		while world.floor_transition_in_progress: await process_frame
		for room in world.rooms:
			if world._is_combat_room(room):
				world.player.global_position = Vector2(room.center_cell) * 32.; world.activate_room(int(room.id)); break
		await frames(30)
		world.player.set_physics_process(false)
		world.set_process(false)
		world._update_camera_and_actor_projection(0.)
		for candidate in world.enemy_root.get_children():
			if candidate is EmployeeEnemy and not candidate.dead:
				enemy_shooter = candidate; break
	for direction_index in 8:
		var direction := Vector2.from_angle(direction_index * TAU / 8.)
		var shot: Node2D = BULLET.instantiate()
		var shooter: Node2D = (enemy_shooter if direction_index >= 4 and enemy_shooter != null else world.player) if formal else null
		shot.position = shooter.get_projectile_origin() if shooter != null else world.player.position
		shot.setup(direction, 1., 1000., 1500., &"enemy" if shooter == enemy_shooter and shooter != null else &"player", shooter)
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_projectile(shot, shooter)
		if legacy:
			# Recreate the previous tutorial's actual registration: default
			# 128-square capture, off-centre anchor and no frozen shot origin.
			shot.remove_meta(&"shot_visual_origin"); shot.remove_meta(&"shot_gameplay_origin")
			var old_bridge: Node = shot.get_meta(&"depth_visual_bridge").get_ref()
			old_bridge.render_viewport.size = Vector2i(128, 128)
			old_bridge.viewport_offset = Vector2(64, 96)
		shot._trail_clock = .06
		for index in 7:
			shot._trail_history.append({"position": shot.position - direction * (6 - index) * 12., "time": index * .01})
		shot._update_office_tracer()
		await verify(shot, "direction_%d" % direction_index)
		if direction_index == 1:
			var frozen: Array = shot._trail_history.duplicate(true)
			world.camera_3d.global_position += Vector3(1.5, 1., -.7)
			var focus: Vector2 = world.player.position / 32.
			world.camera_3d.look_at(world.to_global(Vector3(focus.x, .65, focus.y)), Vector3.UP)
			await verify(shot, "camera_moved")
			check(shot._trail_history == frozen, "moving Camera leaves historical world points unchanged")
			# A bend must retain its own old positions instead of rotating every
			# old point to match the newest velocity.
			shot.rotation += PI / 2.
			shot._trail_history[2].position += Vector2(-20, 14)
			shot._update_office_tracer()
			await verify(shot, "turn")
		shot.queue_free(); await frames(3)
	var file := FileAccess.open(OUT + ("/formal_checks.json" if formal else ("/before/camera_checks.json" if legacy else "/camera_checks.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "gpu": RenderingServer.get_video_adapter_name(), "measurements": measurements}, "\t")); file.close()
	main.queue_free(); await frames(6)
	preload("res://scripts/entities/basic_projectile.gd")._history_texture_pool.clear()
	print("PROJECTILE_CAMERA_HISTORY checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
