extends SceneTree
const SAMPLE = preload("res://scenes/dream/preview/CharacterHandOrbitSample.tscn")
const RIG = preload("res://scripts/dream/preview/elliptical_hand_rig.gd")
var checks := 0
var failures: Array[String] = []
var output := "res://.runtime/character_hand_orbit_20261023"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var gpu := "--gpu" in OS.get_cmdline_user_args()
	if gpu: preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var sample = SAMPLE.instantiate()
	sample.manual_step = true
	root.add_child(sample)
	await process_frame
	check(sample.actors.size() == 2, "A/B actors exist")
	check(current_scene == null, "Standalone lab does not enter Main or a random floor")
	check(RIG.orbit(0).is_equal_approx(Vector2(12, 0)), "Orbit horizontal radius 12")
	check(RIG.orbit(PI * 0.5).is_equal_approx(Vector2(0, 6)), "Orbit vertical radius 6")
	var actor = sample.actors[1]
	var health: float = actor.current_health
	var speed: float = actor.movement_speed
	var samples: Array = []
	for mode in 4:
		sample.set_mode(mode)
		for direction_index in 8:
			var aim := Vector2.from_angle(direction_index * TAU / 8.0)
			sample.ground = Vector2.ZERO
			for frame in 40: sample.step(1.0 / 60.0, Vector2.ZERO, aim)
			var snap: Dictionary = sample.rigs[1].snapshot.duplicate()
			check(snap.left.is_finite() and snap.right.is_finite(), "Finite hands %d/%d" % [mode, direction_index])
			check(actor.left_hand_part.visible and actor.right_hand_part.visible, "Both hands visible %d/%d" % [mode, direction_index])
			if direction_index == 2:
				check(snap.left_depth == 1 and snap.right_depth == 1, "Facing down places hands in front")
			if direction_index == 6:
				check(snap.left_depth == -1 and snap.right_depth == -1, "Facing up places hands behind")
			if mode > 0:
				check(snap.right.distance_to(snap.grip) < 0.05, "Main hand stays on weapon grip %d/%d" % [mode, direction_index])
			if gpu and direction_index % 2 == 0:
				for frame in 3: await process_frame
				await RenderingServer.frame_post_draw
				var name := "mode_%d_direction_%d.png" % [mode, direction_index]
				root.get_texture().get_image().save_png(output.path_join(name))
				samples.append(name)
		# Movement/attack/dash are presentation-only; player remains disabled.
		sample.attack = 0.0
		sample.dash = 0.18
		sample.dash_direction = Vector2.RIGHT
		for frame in 30: sample.step(1.0 / 60.0, Vector2(290, 0), Vector2.RIGHT)
		check(actor.current_health == health and actor.movement_speed == speed, "No health or speed writes in mode %d" % mode)
		check(actor.process_mode == Node.PROCESS_MODE_DISABLED and not actor.attacking_enabled, "Gameplay/weapon authority stays disabled %d" % mode)
	check(not sample.carriers[1].no_depth_test, "3D carrier keeps depth testing")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_4
	sample._unhandled_input(key)
	check(sample.mode == 3, "Keyboard selects bat in the playable sample")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	sample._unhandled_input(click)
	check(sample.attack == 0.0, "Mouse click starts presentation action")
	var first_angle := 0.0
	var last_angle := 0.0
	for frame in 24:
		sample.step(1.0 / 60.0, Vector2.ZERO, Vector2.RIGHT)
		if frame == 0: first_angle = sample.rigs[1].snapshot.angle
		last_angle = sample.rigs[1].snapshot.angle
	check(absf(angle_difference(first_angle, last_angle)) > 1.0, "Bat visibly swings instead of only changing its orbit centre")
	key.keycode = KEY_SPACE
	sample.ground = Vector2.ZERO
	sample._unhandled_input(key)
	check(sample.dash > 0.0, "Space starts sample dash")
	var start: Vector2 = sample.ground
	sample.step(1.0 / 60.0, Vector2.ZERO, Vector2.RIGHT)
	check(sample.ground.distance_to(start) > 0.1, "Dash advances within sample stage bounds")
	key.keycode = KEY_T
	sample._unhandled_input(key)
	check(sample.automatic, "Automatic turntable can be toggled")
	var before: Vector2
	var after: Vector2
	for hz in [30, 120]:
		sample.rigs[1].initialized = false
		sample.rigs[1].step(0.0, Vector2.LEFT, Vector2.ZERO)
		for frame in hz:
			sample.rigs[1].step(1.0 / hz, Vector2.RIGHT, Vector2.ZERO)
		if hz == 30: before = sample.rigs[1].snapshot.grip
		else: after = sample.rigs[1].snapshot.grip
	check(before.distance_to(after) < 0.01, "Exponential follow is independent of 30/120Hz updates")
	# Record deterministic motion through the actual Camera3D, not a drawn mockup.
	if gpu:
		sample.set_mode(3)
		for frame in 120:
			if frame % 36 == 0: sample.attack = 0.0
			sample.ground = Vector2.ZERO
			sample.step(1.0 / 30.0, Vector2.ZERO, Vector2.from_angle(frame * TAU / 120.0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("motion_%03d.png" % frame))
	var report := {"checks": checks, "failures": failures, "gpu": gpu,
		"images": samples, "scope": "Standalone 3D camera A/B sample only; no formal player integration, no added eight-direction art, no gameplay damage"}
	var file := FileAccess.open(output.path_join("gpu_report.json" if gpu else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("HAND_ORBIT_SAMPLE checks=", checks, " failures=", failures.size())
	sample.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
