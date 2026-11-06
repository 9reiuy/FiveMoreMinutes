extends SceneTree
## The only setup shortcuts place the actor and arm the tutorial exercise.
## Actual held-fire/reload input, projectile movement, collision and Camera run.
const OUT := "res://.runtime/projectile_history_projection_20261030/live"
var main: Node
var world: Node
var checks := 0
var failures := 0
var times: Array = []
var captured_projectiles := 0
var selected_weapon := "basic"
var target_point := Vector3(4, .65, 2.6)
var shots := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int = 4) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ", label)
func record(seconds: float, label: String) -> void:
	var started := Time.get_ticks_msec()
	var last := -100
	Input.action_press("attack")
	while Time.get_ticks_msec() - started < seconds * 1000.:
		await RenderingServer.frame_post_draw
		var elapsed := Time.get_ticks_msec() - started
		if elapsed - last < 30: continue
		last = elapsed
		var image := root.get_texture().get_image()
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
		image.save_png(OUT + "/frame_%04d.png" % times.size())
		times.append({"time_ms": Time.get_ticks_msec(), "label": label})
		for shot in get_nodes_in_group(&"dream_projectiles"):
			if shot._trail_history.size() < 2: continue
			var bridge: Node = shot.get_meta(&"depth_visual_bridge").get_ref()
			if bridge != null and bool(shot.get_meta(&"projectile_history_projected", false)):
				captured_projectiles += 1
	Input.action_release("attack")
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps = 60
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(OUT)
	create_timer(120., true, false, true).timeout.connect(func(): quit(2))
	main = load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(90)
	main.persistent_day_state = main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume(); await frames(150)
	world = main._supported_dream_world
	var training: Node = world.get_node("ChapterTraining")
	training.stage = 3; training._setup_training(); await frames(30)
	world.player.position = Vector2(128, 240)
	world.player.set_meta("presentation_pointer_gate", func(): return true)
	world.player.set_meta("presentation_pointer_position", func(): return world.camera_3d.unproject_position(target_point))
	if not InputMap.has_action("attack"): InputMap.add_action("attack")
	world.player.confirmed_projectile_fired.connect(func(): shots += 1)
	var health: float = training.training_target.current_health
	training.picked = true
	world.player.equip_weapon("basic", world.CONFIG); await frames(15)
	await record(2.2, "pistol")
	check(shots > 0, "actual held-fire emits projectiles")
	check(training.training_target.current_health < health, "actual tutorial projectile hits target")
	# Camera pan during live shots, with the same recorded world trajectory.
	world.camera_aim_offset += Vector3(.8, 0, -.5)
	world.player.equip_weapon("assault_rifle", world.CONFIG); await frames(8)
	await record(1.5, "rifle_camera_pan")
	target_point = Vector3(6.8, .65, 5.5)
	world.player.equip_weapon("shotgun", world.CONFIG); await frames(8)
	await record(2.2, "shotgun_sideways")
	check(captured_projectiles > 10, "live moving projectiles use projected history")
	Input.action_release("attack"); await create_timer(.8).timeout
	check(get_nodes_in_group(&"dream_projectiles").is_empty(), "shots and expired trails clear after blocking contact")
	var file := FileAccess.open(OUT + "/timing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "fired": shots, "live_projectile_observations": captured_projectiles, "frames": times}, "\t")); file.close()
	main.queue_free(); await frames(8)
	preload("res://scripts/entities/basic_projectile.gd")._history_texture_pool.clear()
	print("PROJECTILE_LIVE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
