extends "res://tests/forklift_combat_test.gd"
## Matched lab handling curves, native Camera evidence and real swept blood contacts.

var observations: Array[Dictionary] = []
var baseline := false
const START := Vector2(4.0, 18.0)
const SURFACE := preload("res://scripts/dream/floor_surface_blood.gd")


func curve(label: String, handbrake: bool, turn := 1.0) -> Dictionary:
	park(START if turn > 0.0 else START + Vector2(0.0, 2.5))
	lift.speed = VEHICLE.FORWARD_SPEED
	Input.action_press("move_up")
	Input.action_press("move_right" if turn > 0.0 else "move_left")
	if handbrake: Input.action_press("roll")
	var path: Array[Dictionary] = []
	var previous := lift.global_position
	var travelled := 0.0
	var slip := 0.0
	begin_trace()
	for i in 39:
		await physics_frame
		travelled += lift.global_position.distance_to(previous) / 32.0
		previous = lift.global_position
		if lift.velocity.length() > 1.0:
			slip = maxf(slip, absf(lift.velocity.angle_to(lift.get_forward_direction())))
		path.append({"frame": i, "position": lift.global_position / 32.0,
			"heading": lift.global_rotation, "speed": lift.speed, "velocity": lift.velocity / 32.0})
	end_trace(label)
	var result := {"label": label, "heading": absf(lift.global_rotation), "path_metres": travelled,
		"radius_metres": travelled / maxf(absf(lift.global_rotation), 0.001), "slip_radians": slip, "path": path}
	observations.append(result)
	park(START)
	return result


func setup_vehicle() -> void:
	var model := MODEL.new()
	model.position = Vector3(START.x, 0.0, START.y)
	world.add_child(model)
	lift = VEHICLE.new()
	lift.configure(world, model)
	lift.floor_support = func(p: Vector2) -> bool: return Rect2(0.5, 14.5, 13.0, 9.0).has_point(p)
	world.collision_root.add_child(lift)
	lift.set_active(true)
	place_feet(START + Vector2(-0.13, 1.2))
	await frames(4)
	check(lift.board(world.player), "board drift fixture")


func validate_handbrake(label: String) -> void:
	# Recovery needs open road. Starting near the south wall conflated a
	# genuine collision reaction with tyre grip returning after a drift.
	park(START + Vector2(0.0, -2.0))
	lift.speed = VEHICLE.FORWARD_SPEED
	lift.boost_left = 0.5
	lift.boost_recharge = 0.0
	lift.visual.rotation.z = 0.08
	Input.action_press("move_up")
	Input.action_press("move_right")
	await key(KEY_SPACE)
	var rear: Node3D
	var front: Node3D
	for pivot in lift.visual.drive_wheels:
		if bool(pivot.get_meta(&"rear")): rear = pivot.get_child(0)
		else: front = pivot.get_child(0)
	var rear_before := rear.rotation.z
	var front_before := front.rotation.z
	await frames(12)
	check(lift.handbraking and not world.player.dashing, label + " physical Space applies the handbrake without a player roll")
	check(lift.speed < VEHICLE.FORWARD_SPEED and lift.speed > 0.0 and lift.boost_left == 0.0
		and not lift.start_boost(), label + " handbrake decelerates despite W and takes priority over boost")
	check(lift.body_roll < -0.025 and absf(lift.body_roll) <= VEHICLE.MAX_BODY_ROLL + 0.0001,
		label + " right drift gives a slight outward body lean bounded to 4.5 degrees")
	check(absf(lift.visual.rotation.x) < 0.0001 and is_equal_approx(lift.visual.rotation.z, 0.08),
		label + " suspension lean preserves wheel contact and independent ramp pitch")
	check(lift.visual.body_mesh_instance.rotation.x < -0.025
		and lift.visual.windshield_mesh_instance.transform.is_equal_approx(lift.visual.body_mesh_instance.transform),
		label + " opaque body and windshield lean together")
	check(is_equal_approx(rear.rotation.z, rear_before) and not is_equal_approx(front.rotation.z, front_before),
		label + " held handbrake locks rear wheel spin while the front tyres roll")
	check_seat(label + " handbraking")
	check(lift.visual.get_driver_seat_transform().origin.distance_to(MODEL.SEAT_ANCHOR_LOCAL) < 0.0001,
		label + " visual seat pivots without sliding the driver sideways")
	await capture(label + "-handbrake-body-lean")
	await key(KEY_SPACE, false)
	Input.action_release("move_right")
	var open_recovery := true
	for i in 30:
		await physics_frame
		open_recovery = open_recovery and lift.get_slide_collision_count() == 0
	check(open_recovery, label + " grip recovery is measured without an obstacle contact")
	check(not lift.handbraking and lift._handbrake_blend == 0.0 and absf(lift.body_roll) < 0.001,
		label + " releasing Space restores grip and settles the body")
	check(absf(lift.velocity.angle_to(lift.get_forward_direction())) < 0.02,
		label + " lateral slide recovers progressively to the steering direction")
	lift.visual.rotation.z = 0.0
	park(START)
	await key(KEY_SPACE)
	Input.action_press("move_up")
	Input.action_press("move_right")
	await frames(30)
	check(lift.speed == 0.0 and lift.global_position.distance_to(START * 32.0) < 0.01
		and absf(lift.global_rotation) < 0.001 and absf(lift.body_roll) < 0.001,
		label + " handbrake cannot spin or propel a stationary forklift")
	await key(KEY_SPACE, false)
	park(START + Vector2(2.0, 1.0))
	lift.speed = -VEHICLE.REVERSE_SPEED
	Input.action_press("move_down")
	Input.action_press("move_right")
	Input.action_press("roll")
	await frames(15)
	check(lift.global_rotation < -0.1 and lift.body_roll > 0.01 and lift.speed < 0.0,
		label + " reversing handbrake respects steering and outward lean direction")
	park(START)
	lift.speed = VEHICLE.FORWARD_SPEED
	Input.action_press("move_up")
	Input.action_press("move_right")
	Input.action_press("roll")
	await frames(14)
	var motion := lift.velocity
	var lean := lift.body_roll
	var transfer_physics := Node2D.new()
	world.collision_root.add_child(transfer_physics)
	var transfer_visual := Node3D.new()
	world.add_child(transfer_visual)
	lift.transfer_to(transfer_physics, transfer_visual)
	check(lift.driver == world.player and world.player.mounted_vehicle == lift
		and lift.velocity == motion and lift.body_roll == lean and lift.handbraking,
		label + " live region reparent preserves driver and drift momentum")
	lift.transfer_to(world.collision_root, world)
	transfer_physics.queue_free()
	transfer_visual.queue_free()
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == null and not lift.handbraking and lift.velocity == Vector2.ZERO
		and lift._handbrake_blend == 0.0 and lift.body_roll == 0.0,
		label + " dismount clears handbrake momentum and suspension")
	Input.action_release("roll")
	Input.action_release("move_up")
	Input.action_release("move_right")
	await key(KEY_SPACE, false)
	await frames(3)
	await key(KEY_SPACE)
	check(world.player.dashing, label + " Space still rolls on foot")
	await key(KEY_SPACE, false)
	await frames(80)
	park(START)
	place_feet(START + Vector2(-0.13, 1.2))
	await frames(3)
	check(lift.board(world.player), label + " boarding works after drifting and on-foot roll")
	var wall := block(Rect2(8.0, 14.5, 0.10, 9.0))
	await frames(3)
	lift.speed = VEHICLE.BOOST_SPEED
	Input.action_press("move_up")
	Input.action_press("move_right")
	Input.action_press("roll")
	var contacted := false
	var crossed := false
	for i in 45:
		await physics_frame
		contacted = contacted or lift.get_slide_collision_count() > 0
		crossed = crossed or lift.global_position.x / 32.0 > 8.10
	check(contacted and not crossed, label + " high-speed drift uses swept wall collision")
	check(lift._supported(lift.global_transform), label + " drifting keeps all wheel patches over valid floor")
	wall.queue_free()
	lift.set_active(false)
	check(not lift.handbraking and lift._travel_direction == Vector2.ZERO and lift.body_roll == 0.0,
		label + " unload clears all transient drift state")
	lift.set_active(true)
	park(START)
	place_feet(START + Vector2(-0.13, 1.2))
	await frames(3)
	check(lift.board(world.player), label + " reactivated vehicle boards cleanly")
	lift.restore_state(lift.save_state())
	check(not lift.handbraking and lift.speed == 0.0 and lift.body_roll == 0.0,
		label + " checkpoint restoration starts parked without residual slide")


func validate_blood(label: String) -> void:
	var surface: Node3D = SURFACE.install(world)
	check(is_instance_valid(surface), label + " shared floor blood host is installed")
	for collision_mode in ["nonlethal", "lethal", "drifting"]:
		var lethal: bool = collision_mode == "lethal"
		var drifting: bool = collision_mode == "drifting"
		park(START)
		var target := START + Vector2(3.4, 0.5 if drifting else 0.0)
		var enemy := spawn_attacker(target, "basic")
		enemy.set_physics_process(false)
		enemy.global_position += target * 32.0 - enemy.get_node("CollisionShape2D").global_position
		enemy.maximum_health = 1000.0
		enemy.current_health = 10.0 if lethal else 1000.0
		await frames(3)
		var events_before: int = surface.accepted_blood_events
		var landed_before: int = surface.hit_count
		begin_trace()
		lift.speed = VEHICLE.FORWARD_SPEED
		Input.action_press("move_up")
		if drifting:
			Input.action_press("move_right")
			Input.action_press("roll")
		for i in 60:
			await physics_frame
			if enemy.current_health < (10.0 if lethal else 1000.0): break
		if drifting:
			check(lift.handbraking and absf(lift.body_roll) > 0.001,
				label + " accepted drifting impact combines handbrake, suspension and blood")
		Input.action_release("move_up")
		Input.action_release("move_right")
		Input.action_release("roll")
		lift.reset_motion()
		check(enemy.current_health < (10.0 if lethal else 1000.0) and enemy.impact_blood_spawned,
			label + " accepted " + collision_mode + " swept contact emits impact blood")
		check(enemy.dead == lethal, label + " blood does not change the actual damage or death decision")
		check(surface.accepted_blood_events == events_before + 1,
			label + " exactly one shared blood spray per accepted contact")
		var after_hit := enemy.current_health
		await frames(5)
		end_trace(label + "-first-" + collision_mode + "-contact")
		await capture(label + "-" + collision_mode + "-blood-spray")
		await frames(72)
		check(surface.hit_count > landed_before and not surface.faces.is_empty(),
			label + " droplets deposit persistent blood on actual floor or wall surfaces")
		check(enemy.current_health == after_hit, label + " stopped forklift cannot repeatedly damage a touching enemy")
		await capture(label + "-" + collision_mode + "-blood-settled")
		observations.append({"label": label + "-blood", "lethal": lethal, "drifting": drifting,
			"accepted": surface.accepted_blood_events - events_before, "surface_hits": surface.hit_count - landed_before,
			"persistent_faces": surface.faces.size()})
		await clear_attackers()
	park(START)


func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world: break
	check(lab.ready_world, "independent drift lab loads")
	verify_audio()
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = false
	for mode in [0, 1]:
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		await setup_vehicle()
		var label := "whitebox" if mode == 0 else "production-art"
		await sample(label + "-parked")
		var normal := await curve(label + "-normal-before", false)
		var drifting := await curve(label + "-space-first", true)
		await curve(label + "-normal-after", false)
		await curve(label + "-space-repeat", true)
		if not baseline:
			check(drifting.heading > normal.heading * 1.5 and drifting.radius_metres < normal.radius_metres * 0.65,
				label + " Space makes a substantially sharper turn at the same entry speed")
			check(drifting.slip_radians > normal.slip_radians + 0.15,
				label + " drift retains visible lateral momentum rather than instantly realigning")
			var left := await curve(label + "-space-left", true, -1.0)
			check(absf(left.heading - drifting.heading) < 0.05,
				label + " left and right handbrake turns have matching response")
			await validate_handbrake(label)
			await validate_blood(label)
		check(lift.try_exit(), label + " dismount")
		var old: WeakRef = weakref(lift)
		await lab.rebuild()
		verify_audio()
		check(not is_instance_valid(old.get_ref()), label + " rebuild releases vehicle")
	lab.queue_free()
	await frames(4)
	var report := {"checks": checks, "failures": failures, "metrics": metrics, "observations": observations,
		"baseline": baseline, "renderer": RenderingServer.get_current_rendering_method(),
		"display": DisplayServer.get_name(), "audio": AudioServer.get_driver_name(), "pid": OS.get_process_id(),
		"scope": "Matched independent lab handling curves and bounded raw frame windows; no whole-game performance claim."}
	var file := FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("FORKLIFT_DRIFT checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
