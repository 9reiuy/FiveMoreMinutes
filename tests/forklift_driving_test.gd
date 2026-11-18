extends SceneTree
## Real GameTestLab input/collision coverage, followed by the authored chapter entry.

const VEHICLE := preload("res://scripts/dream/props/drivable_forklift.gd")
const MODEL := preload("res://scripts/dream/props/mini_forklift_3d.gd")
const LAB := "res://scenes/testing/GameTestLab.tscn"
var checks: Array[String] = []
var failures: Array[String] = []
var metrics: Array[Dictionary] = []
var input_events: Array[Dictionary] = []
var evidence := ""
var native := false
var lab
var world
var lift: VEHICLE
var shots := 0


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok:
		failures.append(label)
		push_error(label)
	print("PASS " if ok else "FAIL ", label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func verify_audio() -> void:
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		check(false, "private master volume must already be muted before scene entry")
		quit(1)


func key(code: Key, pressed := true, echo := false) -> void:
	var frame_times: Array[float] = []
	var stamp := [Time.get_ticks_usec()]
	var trace := func() -> void:
		var now := Time.get_ticks_usec()
		frame_times.append((now - stamp[0]) * 0.001)
		stamp[0] = now
	process_frame.connect(trace)
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await frames(2)
	await process_frame
	process_frame.disconnect(trace)
	input_events.append({"key": code, "pressed": pressed, "echo": echo, "frames_ms": frame_times})


func place_feet(at: Vector2) -> void:
	world.player.global_position += at * 32.0 - world.player.body_collision.global_position
	world.player.velocity = Vector2.ZERO


func park(at: Vector2, yaw := 0.0) -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "roll"]:
		Input.action_release(action)
	lift.reset_motion()
	lift.global_position = at * 32.0
	lift.global_rotation = yaw
	lift.speed = 0.0
	lift.steering = 0.0
	lift.velocity = Vector2.ZERO
	lift.visual.position = Vector3(at.x, lift.floor_height, at.y)
	lift.visual.rotation.y = -yaw
	if is_instance_valid(lift.driver):
		lift._sync_driver()


func block(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = VEHICLE.VEHICLE_LAYER
	body.collision_mask = 0
	body.position = rect.get_center() * 32.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size * 32.0
	shape.shape = box
	body.add_child(shape)
	world.collision_root.add_child(body)
	return body


func capture(label: String) -> void:
	if not native:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label + ".png"))


func sample(label: String, driving := false) -> void:
	var raw: Array[float] = []
	var before := Time.get_ticks_usec()
	for i in 150:
		if driving and i % 60 == 0:
			Input.action_release("move_down" if i % 120 == 0 else "move_up")
			Input.action_press("move_up" if i % 120 == 0 else "move_down")
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append((now - before) * 0.001)
		before = now
	Input.action_release("move_up")
	Input.action_release("move_down")
	var sorted := raw.duplicate()
	sorted.sort()
	var over_budget := 0
	for value in raw:
		if value > 16.667:
			over_budget += 1
	metrics.append({"label": label, "frames_ms": raw, "p50_ms": sorted[74],
		"p95_ms": sorted[142], "p99_ms": sorted[148], "max_ms": sorted[-1],
		"frames_over_16_667_ms": over_budget})


func driving_checks(label: String, at: Vector2) -> void:
	park(at)
	place_feet(at + Vector2(-0.13, 3.0))
	check(not lift.can_board(world.player), label + " boarding requires proximity to the cab")
	place_feet(at + Vector2(-0.13, 1.20))
	await frames(3)
	var collision_before: int = world.player.collision_mask
	var weapon_before: String = world.player.selected_weapon_id
	var ammo_before: int = world.player.get("current_ammo") if world.player.get("current_ammo") != null else -1
	check(lift.can_board(world.player), label + " cab can be approached on foot")
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == world.player and world.player.mounted_vehicle == lift, label + " E boards through normal input")
	check(not world.player.movement_enabled and not world.player.attacking_enabled
		and not world.player.weapon_root.visible, label + " driving owns movement and stows the equipped gun")
	check(lift.visual.drive_wheels.size() == 4, label + " original model has four independently turning wheels")
	var original_position := lift.global_position
	Input.action_press("move_up")
	await frames(30)
	check(lift.speed > 0.4 and lift.speed < VEHICLE.FORWARD_SPEED
		and lift.global_position.x > original_position.x + 6.0, label + " W accelerates progressively")
	var wheel: Node3D = lift.visual.drive_wheels[0].get_child(0)
	check(absf(wheel.rotation.z) > 0.01, label + " wheels roll with actual travel")
	check(world.player.body_collision.global_position.distance_to(lift._seat_position()) < 0.05,
		label + " driver remains attached to the moving seat")
	Input.action_release("move_up")
	Input.action_press("move_down")
	await frames(2)
	check(lift.speed >= 0.0, label + " opposite throttle brakes before reversing")
	await frames(42)
	check(lift.speed < -0.1, label + " continued S engages reverse")
	Input.action_release("move_down")
	park(at)
	Input.action_press("move_up")
	Input.action_press("move_right")
	await frames(35)
	check(lift.global_rotation > 0.05, label + " D turns right while moving forward")
	Input.action_release("move_right")
	park(at)
	Input.action_press("move_up")
	Input.action_press("move_left")
	await frames(35)
	check(lift.global_rotation < -0.05, label + " A turns left while moving forward")
	Input.action_release("move_left")
	park(at)
	Input.action_press("move_down")
	Input.action_press("move_right")
	await frames(35)
	check(lift.global_rotation < -0.05, label + " steering reverses naturally in reverse gear")
	park(at)
	lift.boost_recharge = 0.0
	Input.action_press("move_up")
	lift.speed = VEHICLE.FORWARD_SPEED
	await key(KEY_SHIFT)
	check(lift.boost_left > 0.0 and lift.speed > VEHICLE.FORWARD_SPEED, label + " Shift triggers a forward boost")
	await frames(18)
	var recharge: float = lift.boost_recharge
	await key(KEY_SHIFT, true, true)
	check(lift.boost_recharge <= recharge and not lift.start_boost(), label + " holding Shift and key repeat cannot stack boosts")
	await key(KEY_SHIFT, false)
	await frames(50)
	check(lift.boost_left == 0.0 and lift.speed <= VEHICLE.FORWARD_SPEED + 0.15,
		label + " boost ends automatically and speed returns to its normal limit")
	park(at)
	var before_roll := lift.global_position
	Input.action_press("roll")
	await frames(3)
	Input.action_release("roll")
	check(not world.player.dashing and lift.global_position.distance_to(before_roll) < 0.1,
		label + " Space cannot launch a player roll from inside the vehicle")
	Input.action_press("weapon_next")
	await frames(2)
	Input.action_release("weapon_next")
	check(world.player.selected_weapon_id == weapon_before, label + " weapon switching is suspended while driving")
	var shots_before := shots
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await key(KEY_R)
	await key(KEY_R, false)
	await frames(10)
	click.pressed = false
	Input.parse_input_event(click)
	check(shots == shots_before and world.player.selected_weapon_id == weapon_before,
		label + " shooting and reload inputs preserve the stowed loadout")
	if ammo_before >= 0:
		check(int(world.player.get("current_ammo")) == ammo_before, label + " driving consumes no ammunition")
	await capture(label + "-seated")
	var wall := block(Rect2(at + Vector2(3.0, -2.5), Vector2(0.25, 5.0)))
	await frames(2)
	Input.action_press("move_up")
	lift.boost_recharge = 0.0
	lift.start_boost()
	await frames(75)
	check(lift.global_position.x / 32.0 + MODEL.FORK_TIP_X < at.x + 3.08,
		label + " boosted forks stop against a real wall without tunnelling")
	park(at)
	wall.queue_free()
	await frames(2)
	var blockers: Array[StaticBody2D] = []
	for rect in [Rect2(-1.8, 0.9, 4.0, 0.9), Rect2(-1.8, -1.8, 4.0, 0.9), Rect2(-2.0, -1.8, 0.8, 3.6)]:
		blockers.append(block(Rect2(rect.position + at, rect.size)))
	await frames(2)
	check(not lift.try_exit() and lift.driver == world.player, label + " obstructed exits keep the driver safely seated")
	for body in blockers:
		body.queue_free()
	await frames(2)
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == null and world.player.mounted_vehicle == null
		and world.player.movement_enabled and world.player.attacking_enabled,
		label + " E exits and restores movement and combat")
	check(world.player.collision_mask == collision_before and world.player.weapon_root.visible
		and world.player.selected_weapon_id == weapon_before, label + " dismount restores collision and the original weapon")
	check(not world.player.test_move(world.player.global_transform, Vector2.ZERO, null, 0.04, true),
		label + " dismount lands outside the vehicle and surrounding walls")
	check(lift.board(world.player), label + " the same forklift can be boarded again")
	lift.set_active(false)
	check(world.player.mounted_vehicle == null and world.player.movement_enabled
		and lift.collision_layer == 0, label + " region deactivation releases controls and collision")
	lift.set_active(true)
	place_feet(at + Vector2(-0.13, 1.20))
	check(lift.board(world.player), label + " region reactivation permits boarding")


func run_lab() -> void:
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world:
			break
	check(lab.ready_world, "independent GameTestLab loads")
	verify_audio()
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = false
	lab.enemies.value = 0
	for mode in [0, 1]:
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		world.player.weapon_fired.connect(func(_recoil): shots += 1)
		var model := MODEL.new()
		model.position = Vector3(7.0, 0.0, 19.0)
		world.add_child(model)
		lift = VEHICLE.new()
		lift.configure(world, model)
		lift.floor_support = func(p: Vector2) -> bool: return Rect2(0.5, 14.5, 13.0, 9.0).has_point(p)
		world.collision_root.add_child(lift)
		lift.set_active(true)
		await frames(4)
		await driving_checks("whitebox" if mode == 0 else "production-art", Vector2(7.0, 19.0))
		park(Vector2(7.0, 19.0))
		await sample("whitebox-parked" if mode == 0 else "art-parked")
		await sample("whitebox-driving" if mode == 0 else "art-driving", true)
		park(Vector2(7.0, 19.0))
		world.player.lab_ignore_damage = false
		world.player.force_hazard_death(&"forklift_lifecycle_test")
		await frames(3)
		check(lift.driver == null and world.player.mounted_vehicle == null,
			"driver death releases vehicle ownership in mode %d" % mode)
		var old_lift: WeakRef = weakref(lift)
		var old_model: WeakRef = weakref(model)
		await lab.rebuild()
		check(not is_instance_valid(old_lift.get_ref()) and not is_instance_valid(old_model.get_ref()),
			"reset frees both vehicle authority and original model in mode %d" % mode)
	lab.queue_free()
	await frames(3)


func run_chapter() -> void:
	var chapter_script := load("res://scripts/testing/h06_chapter/chapter_world.gd")
	var plan := load("res://scripts/testing/h06_chapter/chapter_layout.gd")
	set_meta(chapter_script.RETRY_KEY, {"checkpoint": chapter_script.Save.CROSS_DOCK,
		"forklift": {"visit": plan.Visit.FREIGHT, "position": Vector2(54.1348, 97.9),
			"height": 0.0, "heading": 0.0, "hp": 300.0}})
	check(change_scene_to_file("res://scenes/testing/H06ChapterWhiteboxLab.tscn") == OK,
		"normal first-chapter launcher scene loads")
	await scene_changed
	await frames(5)
	verify_audio()
	world = current_scene.presentation.world
	world.chase_grace = 300.0
	lift = world.blockout.forklift
	check(is_instance_valid(lift) and lift.active and world.blockout.visit == plan.Visit.FREIGHT,
		"existing freight forklift is connected to its live region")
	check(world.blockout.physics_root.get_node_or_null("forklift") == null,
		"the original fixed forklift collider is replaced")
	world.player.weapon_fired.connect(func(_recoil): shots += 1)
	var at := lift.global_position / 32.0
	await driving_checks("chapter", at)
	park(at)
	await frames(30)
	check(absf(world.player_depth_bridge.ground_surface_height - MODEL.FOOTWELL_Y) < 0.001,
		"chapter floor tracking keeps the seated driver in the footwell")
	check(lift.visual.body_mesh_instance.is_visible_in_tree()
		and lift.visual.body_mesh_instance.get_active_material(0) is StandardMaterial3D
		and world.player_depth_bridge.is_visible_in_tree(),
		"driving keeps the original roof and body opaque with the driver carrier active")
	check(world.instruction.text.contains("Shift") and world.instruction.text.contains("下车"),
		"existing chapter HUD shows the driving controls")
	await capture("chapter-driving")
	for angle in [PI * 0.5, PI, -PI * 0.5]:
		park(at, angle)
		await frames(5)
		check(world.player.body_collision.global_position.distance_to(lift._seat_position()) < 0.05,
			"driver follows the turning cab at %d degrees" % roundi(rad_to_deg(angle)))
	park(at)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await sample("chapter-parked")
	world.chase_grace = 0.0
	world.chase_distance = world.mech_path.get_closest_offset(Vector2(6.1, 57.7))
	var crawler_start: Vector2 = world.mech_path.sample_baked(world.chase_distance)
	world.blockout.mech.position = Vector3(crawler_start.x, 0.0, crawler_start.y)
	world.player.invulnerability_left = 20.0
	seed(1101601)
	for at_enemy: Vector2 in [at + Vector2(6.0, -3.0), at + Vector2(9.0, -5.0)]:
		world._spawn_regular_employee(0, at_enemy * 32.0, &"employee", false, "assault_rifle")
	var drive_combined := "--parked-combined" not in OS.get_cmdline_user_args()
	await sample("chapter-%s-with-chase-and-two-armed-enemies" % ("driving" if drive_combined else "parked"), drive_combined)
	check(not world.player.dead and world.blockout.mech.position.distance_to(Vector3(crawler_start.x, 0.0, crawler_start.y)) > 0.1,
		"bounded combined workload runs driving and the real crawler together")
	world.chase_grace = 300.0
	for enemy in world.enemy_root.get_children():
		enemy.queue_free()
	await frames(2)
	park(at + Vector2(4.0, 0.0))
	check(lift.try_exit(), "chapter dismount succeeds after moving the original forklift")
	place_feet(at)
	await frames(2)
	check(not world.player.test_move(world.player.global_transform, Vector2.ZERO, null, 0.04, true),
		"the former parking space has no invisible fixed collider")
	check(world.vehicle_obstacles.has(lift.get_obstacle_rect()) and not world.vehicle_obstacles.has(plan.PROPS.forklift[0]),
		"crawler obstacle planning follows the moved forklift instead of its old parking space")
	place_feet(at + Vector2(3.87, 1.2))
	await frames(5)
	await capture("chapter-dismounted")
	check(lift.visual.body_mesh_instance.get_surface_override_material(0) != null and world.player.weapon_root.visible
		and world.player_depth_bridge.is_visible_in_tree(),
		"dismount restores the parked cutout materials and original weapon presentation")
	check(lift.board(world.player), "chapter forklift remains reusable")
	var old_lift: WeakRef = weakref(lift)
	var old_model: WeakRef = weakref(lift.visual)
	world.player.force_hazard_death(&"forklift_chapter_retry")
	await frames(3)
	check(world.player.mounted_vehicle == null and lift.driver == null,
		"chapter death releases the mounted player")
	check(world.restart_current_floor_after_death(), "chapter retry uses its existing checkpoint handler")
	await scene_changed
	await frames(6)
	verify_audio()
	world = current_scene.presentation.world
	world.chase_grace = 300.0
	check(not is_instance_valid(old_lift.get_ref()) and not is_instance_valid(old_model.get_ref())
		and is_instance_valid(world.blockout.forklift) and world.player.mounted_vehicle == null,
		"retry removes the old vehicle and creates one clean parked forklift")
	var unused: WeakRef = weakref(world.blockout.forklift)
	world.prepared = world._plan_region(plan.Visit.STAFF)
	world._set_lower(true)
	world._place_feet(Vector2(46.0, 34.0))
	world._enter_prepared()
	await frames(90)
	check(not is_instance_valid(unused.get_ref()) and world.player.movement_enabled
		and world.player.mounted_vehicle == null, "leaving freight unloads its vehicle and preserves on-foot control")
	current_scene.queue_free()
	await frames(5)


func run() -> void:
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	if evidence.is_empty():
		evidence = "user://forklift_drive_test"
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
	var time_controller := root.get_node_or_null("DreamTimeController")
	if time_controller != null:
		time_controller.slow_time_enabled = false
	Engine.time_scale = 1.0
	if "--chapter" in OS.get_cmdline_user_args():
		await run_chapter()
	else:
		await run_lab()
	check(AudioServer.is_bus_mute(0), "private test audio stays muted")
	var report := {"checks": checks, "failures": failures, "metrics": metrics, "input_events": input_events,
		"renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name(),
		"pid": OS.get_process_id(), "scope": "Bounded real-input GameTestLab or authored chapter fixture. Workload labels identify parked/driving, smoke and enemy conditions. Timed windows retain raw uncapped wall frame intervals including first combined-load frames. Not GPU attribution or whole-game performance certification."}
	var file := FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("FORKLIFT_RESULT checks=", checks.size(), " failures=", failures.size(), " evidence=", evidence)
	quit(0 if failures.is_empty() else 1)
