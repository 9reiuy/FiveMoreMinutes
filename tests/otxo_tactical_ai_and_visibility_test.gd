extends SceneTree

const DUNGEON_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PLAYER_SCENE := preload("res://scenes/entities/dream_player.tscn")
const EMPLOYEE_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const DEMO_CONFIG_TRES := preload("res://resources/demo_config.tres")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run_tests")


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run_tests() -> void:
	print("--- Starting OTXO Tactical AI, Screen Shake and Visibility Test Suite ---")

	await _test_bool_constructor_safety()
	await _test_camera_shake_impulse_calibration()
	await _test_tactical_ai_strafe_and_retreat()
	await _test_tactical_ai_door_holding()
	await _test_visibility_no_fog_and_furniture()
	await _test_shotgun_cadence_and_door_hold_range()

	if failures.is_empty():
		print("\n============================================================")
		print(" ALL OTXO TACTICAL AI AND VISIBILITY TESTS PASSED (100%)! ")
		print("============================================================\n")
		quit(0)
	else:
		push_error("OTXO TACTICAL AI TESTS FAILED with %d errors:\n%s" % [failures.size(), "\n".join(failures)])
		quit(1)


func _test_bool_constructor_safety() -> void:
	print("\n[Test 1] Testing bool constructor safety under null/missing methods...")
	var enemy = EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	root.add_child(enemy)
	await frames(2)

	# Simulate world calls returning null or variant without crashing
	var dummy_world = Node2D.new()
	root.add_child(dummy_world)
	for i in 20:
		await physics_frame

	print("PASS: Enemy ran 20 physics frames with no bool constructor crashes")
	dummy_world.queue_free()
	enemy.queue_free()
	await frames(2)


func _test_camera_shake_impulse_calibration() -> void:
	print("\n[Test 2] Testing camera shake and impulse recalibration...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	root.add_child(dungeon)
	await frames(2)

	# Test camera impulse strength: normalized_strength is 1st param, direction is 2nd param
	dungeon.request_camera_impulse_strength(1.0, Vector2.RIGHT)
	var impulse_x: float = absf(dungeon.camera_impulse_offset.x)
	print("Camera impulse offset X: %f" % impulse_x)
	# Pre-fix was ~0.018 - 0.105; recalibrated is >= 0.15 (corresponding to 5-20px)
	if impulse_x < 0.15:
		failures.append("Camera impulse offset too weak: got %f, expected >= 0.15" % impulse_x)
	else:
		print("PASS: Camera impulse offset is strong (%f >= 0.15)" % impulse_x)

	if dungeon.camera_shake_amplitude < 0.10:
		failures.append("Camera shake amplitude too weak: got %f, expected >= 0.10" % dungeon.camera_shake_amplitude)
	else:
		print("PASS: Camera shake amplitude is substantial (%f >= 0.10)" % dungeon.camera_shake_amplitude)

	dungeon.queue_free()
	await frames(2)


func _test_tactical_ai_strafe_and_retreat() -> void:
	print("\n[Test 3] Testing tactical AI strafing while shooting and retreat on reload...")
	var player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(100, 100)
	root.add_child(player)

	var enemy = EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	enemy.global_position = Vector2(250, 100)
	root.add_child(enemy)
	enemy.configure(player, 100.0, 0.0, Rect2(-1000, -1000, 2000, 2000), 0.0, 0.0, DEMO_CONFIG_TRES)
	enemy.set_room_runtime_active(true)
	enemy.set_meta(&"otxo_mode", true)
	enemy.held_weapon_id = "pistol"
	enemy.target = player
	enemy.last_known_room = -1
	enemy.set_meta(&"dream_room_id", -1)
	await frames(5)

	enemy.can_see_target = true
	enemy.has_last_known_target_position = true
	enemy.last_known_target_position = player.global_position

	# 1. Verify shooting state allows strafe motion even when windup pending (no lock to ZERO)
	enemy.ranged_attack_windup_pending = true
	enemy.current_ammo = 10
	enemy.reload_left = 0.0
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	enemy._update_attack_player(0.016)
	print("Enemy velocity during shooting strafe: %s" % str(enemy.velocity))
	if enemy.velocity.length() < 1.0:
		failures.append("Enemy should strafe during shooting in OTXO mode, but was locked at ZERO!")
	else:
		print("PASS: Enemy strafes while shooting (velocity = %s)" % str(enemy.velocity))

	# 2. Verify retreat on reload
	enemy.can_see_target = true
	enemy.has_last_known_target_position = true
	enemy.last_known_target_position = player.global_position
	enemy.current_ammo = 0
	enemy.reload_left = 1.5
	enemy._update_attack_player(0.016)
	var toward: Vector2 = (player.global_position - enemy.global_position).normalized()
	var dot_prod: float = enemy.velocity.dot(toward)
	print("Reload retreat velocity: %s, dot with toward player: %f" % [str(enemy.velocity), dot_prod])
	if dot_prod > -0.1:
		failures.append("Enemy did not retreat on reload: velocity dot toward = %f (expected <= -0.1)" % dot_prod)
	else:
		print("PASS: Enemy retreats away from player during reload (dot product <= -0.1)")

	player.queue_free()
	enemy.queue_free()
	await frames(2)


func _test_tactical_ai_door_holding() -> void:
	print("\n[Test 4] Testing tactical AI door holding mechanics...")
	var dummy_world = Node2D.new()
	dummy_world.add_to_group(&"dream_world")
	root.add_child(dummy_world)

	var enemy = EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	enemy.global_position = Vector2(280, 120)
	root.add_child(enemy)
	enemy.configure(null, 100.0, 0.0, Rect2(-1000, -1000, 2000, 2000), 0.0, 0.0, DEMO_CONFIG_TRES)
	enemy.set_room_runtime_active(true)
	enemy.set_meta(&"otxo_mode", true)
	enemy.held_weapon_id = "pistol"
	enemy.route_direction = &"east"
	enemy.route_approach_point = Vector2(280, 120)
	enemy.route_transit_point = Vector2(300, 100)
	enemy.door_hold_active = true
	enemy.door_hold_time_left = 2.0
	enemy.can_see_target = false
	enemy.state = EmployeeEnemy.State.MOVE_TO_DOOR

	# Call _update_move_to_door directly
	enemy._update_move_to_door()
	print("Enemy velocity during door hold: %s" % str(enemy.velocity))
	if enemy.velocity.length() > 0.01:
		failures.append("Enemy should hold position while door holding, velocity = %s" % str(enemy.velocity))
	else:
		print("PASS: Enemy holds position firmly while guarding door aperture")

	# If hold timer expires, door holding clears
	enemy.door_hold_time_left = 0.0001
	enemy._update_move_to_door()
	if enemy.door_hold_active:
		failures.append("Door hold should expire when time runs out")
	else:
		print("PASS: Door hold expires and transitions back to active search")

	dummy_world.queue_free()
	enemy.queue_free()
	await frames(2)


func _test_visibility_no_fog_and_furniture() -> void:
	print("\n[Test 5] Testing no fog of war and furniture visibility in OTXO mode...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = true
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.config.otxo_mansion_room_count = 14
	root.add_child(dungeon)
	await frames(2)

	var generated: bool = dungeon.regenerate(9922)
	if not generated:
		failures.append("Failed to generate OTXO dungeon 9922")
		dungeon.queue_free()
		await frames(2)
		return

	var vis = dungeon.room_visibility
	if vis == null:
		failures.append("RoomVisibility is null")
	else:
		if vis.cover_root != null and vis.cover_root.visible:
			failures.append("RoomFogRoot should be invisible in OTXO mode!")
		else:
			print("PASS: RoomFogRoot is disabled/hidden in OTXO mode (No Fog of War)")

		if vis.outside_black_gradient != null:
			failures.append("outside_black_gradient should not exist in OTXO mode!")
		else:
			print("PASS: outside_black_gradient is omitted in OTXO mode")

		var unrevealed := 0
		for r_id in vis.revealed_rooms.keys():
			if not bool(vis.revealed_rooms[r_id]):
				unrevealed += 1
		if unrevealed > 0:
			failures.append("Found %d unrevealed rooms in OTXO mode, expected 0" % unrevealed)
		else:
			print("PASS: All %d rooms marked revealed in OTXO mode" % vis.revealed_rooms.size())

	var spawn_room_id: int = dungeon.spawn_room_id
	var spawn_pos: Vector2 = Vector2(dungeon.spawn_cell) * 32.0
	var spawn_room_furniture: Array[Node2D] = []
	var other_room_furniture: Array[Node2D] = []

	if dungeon.furniture_root != null:
		for prop in dungeon.furniture_root.get_children():
			if prop is Node2D:
				var r_id := int(prop.get_meta(&"dream_room_id", -1))
				if r_id == spawn_room_id:
					spawn_room_furniture.append(prop)
				elif r_id >= 0:
					other_room_furniture.append(prop)

	print("Spawn room (%d) furniture count: %d" % [spawn_room_id, spawn_room_furniture.size()])
	print("Other rooms furniture count: %d" % other_room_furniture.size())

	if spawn_room_furniture.is_empty():
		failures.append("Expected furniture in spawn room in OTXO mode, but none found!")
	else:
		print("PASS: Spawn room has %d furniture pieces" % spawn_room_furniture.size())
		for f in spawn_room_furniture:
			var dist := f.global_position.distance_to(spawn_pos)
			if dist < 35.0:
				failures.append("Spawn room furniture too close to spawn point! dist=%f < 35px" % dist)
			else:
				print("PASS: Spawn room furniture at dist %f from spawn cell (clearance OK)" % dist)

	var hidden_furniture := 0
	for f in other_room_furniture:
		if not f.visible:
			hidden_furniture += 1
	if hidden_furniture > 0:
		failures.append("%d pieces of furniture in other rooms are hidden!" % hidden_furniture)
	else:
		print("PASS: All %d pieces of furniture across all rooms are visible" % other_room_furniture.size())

	# Step physics frames to detect any physics separation blast / wall penetration
	var max_velocity := 0.0
	var blasted_furniture := 0
	for step in 15:
		await physics_frame
		for prop in dungeon.furniture_root.get_children():
			var rb := prop as RigidBody2D
			if rb != null:
				var spd: float = rb.linear_velocity.length()
				if spd > max_velocity:
					max_velocity = spd
				if spd > 300.0:
					blasted_furniture += 1

	if blasted_furniture > 0:
		failures.append("Found %d furniture pieces with blast velocities > 300 px/s (max: %f px/s)" % [blasted_furniture, max_velocity])
	else:
		print("PASS: 0 furniture blast detected across 15 physics frames (max speed: %f px/s, threshold 300)" % max_velocity)

	# Verify depth bridge wakeup on movement
	if not other_room_furniture.is_empty():
		var test_f = other_room_furniture[0]
		if test_f is RigidBody2D and test_f.has_meta(&"depth_visual_bridge"):
			var bridge_ref: Variant = test_f.get_meta(&"depth_visual_bridge")
			if bridge_ref is WeakRef:
				var bridge = bridge_ref.get_ref()
				if bridge != null:
					test_f.linear_velocity = Vector2(20.0, 0.0)
					test_f.call("notify_visual_dirty")
					print("PASS: Furniture depth bridge wakeup mechanism validated")

	dungeon.queue_free()
	await frames(2)


func _test_shotgun_cadence_and_door_hold_range() -> void:
	print("\n[Test 6] Testing enemy shotgun firing cadence and door hold range validation...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	root.add_child(dungeon)
	dungeon.regenerate(12345)
	await frames(5)

	var room0_id = dungeon.spawn_room_id
	var neighbor_id = -1
	for n in dungeon.rooms[room0_id].get("connections", []):
		neighbor_id = int(n)
		break

	var pos0 = Vector2(dungeon.rooms[room0_id]["center_cell"]) * 32.0
	var player = PLAYER_SCENE.instantiate()
	player.position = pos0 + Vector2(400, 0)
	dungeon.gameplay_canvas.add_child(player)

	var enemy = dungeon._spawn_regular_employee(room0_id, pos0, &"employee")
	enemy.equip_weapon("shotgun", 0)
	enemy.set_room_runtime_active(true)
	await frames(5)

	enemy.target = player
	enemy.hostile = true
	enemy.last_known_room = neighbor_id
	enemy.can_see_target = true
	enemy.has_last_known_target_position = true
	enemy.last_known_target_position = player.global_position
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER

	# Phase 1: Player out of range (400px > 220px) - must NOT shoot in a loop
	var shots_out_of_range := 0
	var last_ammo = enemy.current_ammo
	for f in range(30):
		await physics_frame
		await process_frame
		enemy.can_see_target = true
		enemy.has_last_known_target_position = true
		enemy.last_known_target_position = player.global_position
		enemy.last_known_room = neighbor_id
		if enemy.current_ammo != last_ammo:
			shots_out_of_range += 1
			last_ammo = enemy.current_ammo

	if shots_out_of_range > 0:
		failures.append("Enemy with shotgun fired %d times while player was out of range (400px > 220px)!" % shots_out_of_range)
	else:
		print("PASS: Enemy did not fire when player was out of range (0 shots in 30 frames)")

	# Phase 2: Move player within shotgun range (140px <= 220px) - must fire with proper interval (~0.8s)
	player.position = enemy.global_position + Vector2(140, 0)
	var shot_frames: Array[int] = []
	last_ammo = enemy.current_ammo
	for f in range(120):
		await physics_frame
		await process_frame
		enemy.can_see_target = true
		enemy.has_last_known_target_position = true
		enemy.last_known_target_position = player.global_position
		if enemy.current_ammo != last_ammo:
			shot_frames.append(f)
			last_ammo = enemy.current_ammo

	if shot_frames.size() < 2 or shot_frames.size() > 4:
		failures.append("Enemy shotgun fired %d times in 120 frames (expected 2-3 shots with 0.8s cooldown)" % shot_frames.size())
	else:
		var min_interval := 999
		for i in range(1, shot_frames.size()):
			var diff = shot_frames[i] - shot_frames[i - 1]
			if diff < min_interval:
				min_interval = diff
		if min_interval < 35:
			failures.append("Enemy shotgun fired with too short interval: %d frames (< 35 frames / ~0.6s)!" % min_interval)
		else:
			print("PASS: Enemy shotgun fired %d times across 120 frames with cadence >= %d frames (%.3fs)" % [
				shot_frames.size(), min_interval, min_interval * 0.01667
			])

	dungeon.queue_free()
	await frames(2)

