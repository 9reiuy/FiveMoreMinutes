extends "res://tests/forklift_driving_test.gd"
## Exercise the normal 1-2 entrance, real bullets, the shared VFX and streamed driving.

const CHAPTER := preload("res://scripts/testing/h06_chapter/chapter_world.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const PROJECTILE := preload("res://scenes/entities/basic_projectile.tscn")


func enter_chapter(checkpoint: int, vehicle: Dictionary = {}) -> void:
	set_meta(CHAPTER.RETRY_KEY, {"checkpoint": checkpoint, "forklift": vehicle})
	check(change_scene_to_file("res://scenes/testing/H06ChapterWhiteboxLab.tscn") == OK, "chapter scene loads")
	await scene_changed
	await frames(6)
	verify_audio()
	world = current_scene.presentation.world
	lift = world.blockout.forklift


func walk_to(mark: Vector2) -> bool:
	for i in 360:
		var offset: Vector2 = mark - world._feet()
		if offset.length() < 0.18:
			world.player.clear_scripted_locomotion()
			return true
		world.player.set_scripted_locomotion(offset.normalized(), minf(8.0, offset.length() * 20.0) * 32.0)
		await physics_frame
	world.player.clear_scripted_locomotion()
	return false


func drive_until(arrived: Callable) -> bool:
	Input.action_press("move_up")
	var reached := false
	for i in 260:
		await physics_frame
		if bool(arrived.call()):
			reached = true
			break
	Input.action_release("move_up")
	lift.speed = 0.0
	lift.velocity = Vector2.ZERO
	return reached


func check_follow_camera(label: String) -> void:
	world.camera_lead = Vector3(3.0, 0.0, 2.0)
	world.authoritative_camera_fov = 42.0
	var viewing = world.blockout.windows.values()[0] if not world.blockout.windows.is_empty() else null
	world._frame_encounter(world._feet(), 0.5, viewing)
	check(world.camera_lead == Vector3.ZERO and is_equal_approx(world.authoritative_camera_fov, world.GAMEPLAY_CAMERA_FOV),
		label + " follows the player without a forced cutaway or zoom")


func test_damage() -> void:
	park(PLAN.FORKLIFT_START)
	check(lift.try_exit(), "driver can leave the 1-2 forklift")
	place_feet(PLAN.FORKLIFT_START + Vector2(-2.2, 0.0))
	await frames(4)
	var bullet = PROJECTILE.instantiate()
	bullet.position = world.player.global_position
	bullet.setup(Vector2.RIGHT, 10.0, 200.0, 500.0, &"player", world.player, &"basic")
	world.add_projectile(bullet, world.player)
	await frames(24)
	check(is_equal_approx(lift.hp, 290.0), "a normal swept bullet damages the elevated forklift")
	place_feet(PLAN.FORKLIFT_START + Vector2(-0.13, 1.2))
	await frames(3)
	check(lift.board(world.player), "driver can board the damaged forklift")
	var player_health: float = world.player.current_health
	world.player.receive_damage(20.0, &"employee_projectile", Vector2.INF, Vector2.LEFT)
	check(is_equal_approx(lift.hp, 270.0) and world.player.current_health == player_health,
		"incoming driver hits use the vehicle's 300-point health pool")
	lift.take_damage(lift.hp - 91.0)
	await frames(3)
	check(not lift.smoking, "91 HP remains above the smoke threshold")
	lift.take_damage(1.0)
	await frames(60)
	check(lift.smoking and lift.hp == 90.0 and not lift.damage_effects.effects.particles.is_empty(),
		"90 HP starts the shared engine smoke")
	await capture("02-low-health-smoke")
	Engine.max_fps = 0
	await sample("low-health-parked")
	await sample("low-health-driving", true)
	park(PLAN.FORKLIFT_START)
	var explosions_before: int = lift.damage_effects.effects.explosion.serial
	world.player.invulnerability_left = 30.0
	process_frame.connect(func() -> void: lift.take_damage(lift.hp), CONNECT_ONE_SHOT)
	await sample("first-vehicle-explosion")
	check(lift.destroyed and lift.hp == 0.0 and not lift.smoking and lift.collision_layer == 0,
		"zero HP destroys the vehicle and removes its collision")
	check(lift.damage_effects.effects.explosion.serial == explosions_before + 1,
		"destruction emits the existing CC0 explosion exactly once")
	check(lift.driver == null and world.player.mounted_vehicle == null and world.player.movement_enabled
		and world.player_depth_bridge.is_visible_in_tree(), "explosion safely releases the driver and restores the character")
	check(not lift.can_board(world.player), "a destroyed forklift cannot be boarded")
	lift.take_damage(999.0)
	await frames(3)
	check(lift.damage_effects.effects.explosion.serial == explosions_before + 1,
		"repeated lethal hits cannot replay the explosion")
	await capture("03-destroyed")
	world.player.force_hazard_death(&"forklift_damage_retry")
	check(world.restart_current_floor_after_death(), "destroyed-vehicle retry uses the normal handler")
	await scene_changed
	await frames(6)
	verify_audio()
	world = current_scene.presentation.world
	if world.blockout.visit == PLAN.Visit.GALLERY:
		check(await walk_to(Vector2(-5.5, -27.6)), "return from the original checkpoint to the destroyed vehicle")
	lift = world.blockout.forklift
	check(is_instance_valid(lift) and lift.destroyed and lift.collision_layer == 0
		and lift.damage_effects.effects.explosion.serial == 0, "retry restores destruction without an invisible blocker or a second blast")


func test_streaming() -> void:
	var at := Vector2(-18.5, -1.4)
	await enter_chapter(CHAPTER.Save.PUMP, {"visit": PLAN.Visit.WEST, "position": at,
		"heading": PI * 0.5, "height": PLAN.upper_height(at), "hp": 260.0})
	world.stage = CHAPTER.Stage.RETURN
	for enemy in world.enemy_root.get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	place_feet(at + Vector2(1.2, 0.0))
	await frames(3)
	check(lift.board(world.player), "the loaded checkpoint forklift is driveable at the staircase")
	check(await drive_until(func() -> bool: return world._feet().y > 3.0), "drive down the upper staircase")
	check(lift.floor_height > 0.2 and lift.floor_height < 2.5 and absf(lift.visual.rotation.z) > 0.1,
		"the forklift follows the staircase height and slope")
	await capture("04-stairs")
	check(await drive_until(func() -> bool: return world._feet().y > 7.05), "all wheels reach the lower landing")
	check(world.on_lower_floor and absf(lift.floor_height) < 0.02, "the vehicle changes floor together with the player")
	var vehicle_id := lift.get_instance_id()
	park(lift.global_position / 32.0, 0.0)
	check(await drive_until(func() -> bool: return world.blockout.visit == PLAN.Visit.EMPTY_HANGAR),
		"drive through the real 1-2 return threshold")
	print("STREAM_STATE visit=", world.blockout.visit, " hp=", lift.hp, " driver=", lift.driver == world.player,
		" position=", lift.global_position / 32.0, " stage=", world.stage)
	check(lift.get_instance_id() == vehicle_id and lift.driver == world.player and lift.hp == 260.0,
		"streaming preserves the same vehicle, health and driver")
	check_follow_camera("return hangar")
	world.blockout.set_gate("cargo_access", false)
	world.checkpoint = CHAPTER.Save.TRANSFER
	park(Vector2(0.5, 11.1), PI * 0.5)
	check(await drive_until(func() -> bool: return world.blockout.visit == PLAN.Visit.FREIGHT),
		"drive into the freight district without losing the vehicle")
	check_follow_camera("1-3 freight")
	world.stage = CHAPTER.Stage.CHASE
	world.chase_grace = 300.0
	park(Vector2(50.2, 34.0), PI)
	check(await drive_until(func() -> bool: return world.blockout.visit == PLAN.Visit.STAFF),
		"drive through the freight exit into 1-4")
	check(lift.driver == world.player and lift.hp == 260.0 and lift.get_parent() == world.blockout.physics_root,
		"1-4 owns the transferred vehicle with no duplicate")
	check_follow_camera("1-4 staff")
	await capture("05-staff-driving")
	var old_vehicle: WeakRef = weakref(lift)
	world.player.force_hazard_death(&"forklift_streaming_retry")
	check(world.restart_current_floor_after_death(), "transferred-vehicle retry uses the normal handler")
	await scene_changed
	await frames(6)
	verify_audio()
	world = current_scene.presentation.world
	lift = world.blockout.forklift
	check(not is_instance_valid(old_vehicle.get_ref()) and is_instance_valid(lift) and lift.hp == 260.0
		and lift.driver == null, "retry recreates one healthy parked vehicle in the current district")


func run() -> void:
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	if evidence.is_empty(): evidence = "user://forklift_revision_test"
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	await enter_chapter(CHAPTER.Save.OBSERVATION)
	check(not is_instance_valid(lift), "the first room has no extra forklift")
	check(await walk_to(Vector2(-5.5, -27.6)), "walk through the normal 1-2 entrance")
	lift = world.blockout.forklift
	check(is_instance_valid(lift) and lift.active and lift.hp == 300.0
		and lift.global_position.distance_to(PLAN.FORKLIFT_START * 32.0) < 0.01,
		"one 300-HP forklift waits beside the 1-2 entrance")
	check_follow_camera("1-2 west")
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, 0.0))
	await frames(3)
	await key(KEY_E)
	await key(KEY_E, false)
	check(lift.driver == world.player, "the initially parked forklift boards from its open side")
	await frames(10)
	await capture("00-entrance-driving")
	await key(KEY_E)
	await key(KEY_E, false)
	world.player.weapon_fired.connect(func(_recoil): shots += 1)
	await driving_checks("1-2", PLAN.FORKLIFT_START)
	await frames(15)
	check(world.player_depth_bridge.is_visible_in_tree() and world.player_depth_bridge.actor_sprite.is_visible_in_tree(),
		"the seated real player is displayed while driving")
	await capture("01-west-driving")
	await test_damage()
	await test_streaming()
	current_scene.queue_free()
	await frames(5)
	check(AudioServer.is_bus_mute(0), "private audio remains muted")
	var result := {"checks": checks, "failures": failures, "metrics": metrics, "input_events": input_events,
		"renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(),
		"audio": AudioServer.get_driver_name(), "pid": OS.get_process_id(),
		"scope": "Normal chapter entrance, real projectile damage and mounted transfers. Stair sections use separate aligned driving fixtures. Uncapped short frame samples retain the first explosion. Not whole-game certification."}
	var file := FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("FORKLIFT_REVISION checks=", checks.size(), " failures=", failures.size(), " evidence=", evidence)
	quit(0 if failures.is_empty() else 1)
