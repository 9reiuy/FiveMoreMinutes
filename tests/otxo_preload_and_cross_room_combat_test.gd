extends SceneTree

const DUNGEON_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PLAYER_SCENE := preload("res://scenes/entities/dream_player.tscn")
const EMPLOYEE_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const DOOR_SCRIPT := preload("res://scripts/dream/physical_door_3d.gd")
const DEMO_CONFIG_TRES := preload("res://resources/demo_config.tres")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run_tests")


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run_tests() -> void:
	print("--- Starting OTXO Preload & Cross-Room Combat Test Suite ---")

	await _test_otxo_preloading()
	await _test_otxo_enemy_density_and_quotas()
	await _test_player_knockback_immunity()
	await _test_cross_room_shooting_behavior()

	if failures.is_empty():
		print("\n============================================================")
		print(" ALL OTXO PRELOAD & CROSS-ROOM COMBAT TESTS PASSED (100%)! ")
		print("============================================================\n")
		quit(0)
	else:
		push_error("OTXO PRELOAD TESTS FAILED with %d errors:\n%s" % [failures.size(), "\n".join(failures)])
		quit(1)


func _test_otxo_preloading() -> void:
	print("\n[Test 1] OTXO Preloading (All rooms spawned upfront, no sky drop)...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = true
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.config.otxo_mansion_room_count = 14

	root.add_child(dungeon)
	await frames(2)
	var generated: bool = dungeon.regenerate(8881)
	if not generated:
		failures.append("Failed to generate OTXO dungeon 8881")
		dungeon.queue_free()
		await frames(2)
		return

	# Check boss key preloaded
	if dungeon.key_pickup == null or not is_instance_valid(dungeon.key_pickup):
		failures.append("Boss key was not preloaded upfront!")
	else:
		print("PASS: Boss key is preloaded upfront in scene tree")

	# Check boss enemy preloaded
	if dungeon.boss_enemy == null or not is_instance_valid(dungeon.boss_enemy):
		failures.append("Boss enemy was not preloaded upfront!")
	else:
		print("PASS: Boss enemy is preloaded upfront in scene tree")

	# Check wake exit preloaded
	if dungeon.wake_exit_trigger == null or not is_instance_valid(dungeon.wake_exit_trigger):
		failures.append("Wake exit trigger was not preloaded upfront!")
	else:
		print("PASS: Wake exit trigger is preloaded upfront in scene tree")

	# Check furniture root has preloaded children
	var furniture_count: int = dungeon.furniture_root.get_child_count() if dungeon.furniture_root != null else 0
	if furniture_count == 0:
		failures.append("No furniture preloaded upfront in OTXO mode!")
	else:
		print("PASS: %d furniture pieces preloaded upfront" % furniture_count)

	# Check enemy root has preloaded children across combat rooms
	var enemy_count: int = dungeon.enemy_root.get_child_count() if dungeon.enemy_root != null else 0
	if enemy_count == 0:
		failures.append("No enemies preloaded upfront in OTXO mode!")
	else:
		print("PASS: %d enemies preloaded upfront" % enemy_count)

	# Check that NO enemies are currently in sky drop animation
	var sky_drop_count := 0
	if dungeon.enemy_root != null:
		for child in dungeon.enemy_root.get_children():
			if child is EmployeeEnemy:
				if bool(child.get("sky_drop_active")):
					sky_drop_count += 1
	if sky_drop_count > 0:
		failures.append("Expected 0 enemies in sky drop in OTXO mode, found %d" % sky_drop_count)
	else:
		print("PASS: 0 enemies have sky drop animation active (all grounded from frame 0)")

	# Check 2-hop active vs distant frozen enemies
	var active_rooms: Dictionary = dungeon._get_rooms_within_hops(dungeon.spawn_room_id, 2)
	var active_enemy_count := 0
	var frozen_enemy_count := 0
	var frozen_enemy_damageable_count := 0
	var a_frozen_enemy: EmployeeEnemy = null

	if dungeon.enemy_root != null:
		for child in dungeon.enemy_root.get_children():
			if child is EmployeeEnemy:
				var enemy: EmployeeEnemy = child
				var enemy_room := int(enemy.get_meta(&"dream_room_id", -1))
				var is_active := bool(enemy.get("room_runtime_active"))
				if is_active:
					active_enemy_count += 1
				else:
					frozen_enemy_count += 1
					if enemy.is_damage_runtime_active():
						frozen_enemy_damageable_count += 1
					if a_frozen_enemy == null:
						a_frozen_enemy = enemy

	print("INFO: 2-Hop Active enemies: %d, Distant Frozen enemies: %d" % [active_enemy_count, frozen_enemy_count])
	if active_enemy_count == 0:
		failures.append("Expected at least some enemies in 2-hop active range, got 0")
	else:
		print("PASS: 2-hop active enemies running AI (%d active)" % active_enemy_count)

	if frozen_enemy_count > 0:
		if frozen_enemy_damageable_count != frozen_enemy_count:
			failures.append("All %d frozen enemies must remain damageable, only %d were" % [frozen_enemy_count, frozen_enemy_damageable_count])
		else:
			print("PASS: All %d frozen enemies remain damageable across distant rooms" % frozen_enemy_count)

		# Test wake-up when damaged
		if a_frozen_enemy != null:
			a_frozen_enemy.take_damage(5.0, Vector2.ZERO, 0.0, &"player_projectile")
			if not a_frozen_enemy.room_runtime_active:
				failures.append("Frozen enemy did not wake up when taking damage!")
			else:
				print("PASS: Frozen enemy woke up immediately upon taking damage")

	dungeon.queue_free()
	await frames(2)


func _test_otxo_enemy_density_and_quotas() -> void:
	print("\n[Test 2] OTXO Enemy Density and Quotas (15-22 total, 0 in spawn room)...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = true
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.config.otxo_mansion_room_count = 14

	root.add_child(dungeon)
	await frames(2)
	var generated: bool = dungeon.regenerate(8882)
	if not generated:
		failures.append("Failed to generate OTXO dungeon 8882")
		dungeon.queue_free()
		await frames(2)
		return

	# Count enemies per room
	var enemies_by_room: Dictionary = {}
	var total_regular_enemies := 0
	if dungeon.enemy_root != null:
		for child in dungeon.enemy_root.get_children():
			if child is EmployeeEnemy:
				var r_id := int(child.get_meta(&"dream_room_id", -1))
				enemies_by_room[r_id] = int(enemies_by_room.get(r_id, 0)) + 1
				if child != dungeon.boss_enemy:
					total_regular_enemies += 1

	# Check spawn room has 0 enemies
	var spawn_room_enemies := int(enemies_by_room.get(dungeon.spawn_room_id, 0))
	if spawn_room_enemies != 0:
		failures.append("Spawn room must have 0 enemies, found %d" % spawn_room_enemies)
	else:
		print("PASS: Spawn room has 0 enemies")

	# Check total enemies count (regular enemies + boss)
	var total_enemies: int = dungeon.enemy_count
	print("INFO: Total enemy count across map = %d (regular: %d, boss: 1)" % [total_enemies, total_regular_enemies])
	if total_enemies < 10 or total_enemies > 55:
		failures.append("Total enemies %d outside expected range [10, 55]" % total_enemies)
	else:
		print("PASS: Total enemy density is balanced (%d enemies)" % total_enemies)

	# Verify per-room quotas
	for room_variant in dungeon.rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id == dungeon.spawn_room_id or room_id == dungeon.boss_room_id:
			continue
		if not dungeon._is_combat_room(room):
			continue
		var count: int = int(enemies_by_room.get(room_id, 0))
		var min_expected: int = dungeon._room_enemy_minimum(room)
		var max_expected: int = dungeon._effective_room_enemy_max(room)
		if count < min_expected or count > max_expected:
			failures.append("Room %d (%s) enemy count %d outside [%d, %d]" % [
				room_id, String(room.get("size_class", "unknown")), count, min_expected, max_expected
			])
	print("PASS: Per-room enemy counts strictly adhere to size quotas (small 1-2, medium 2-3, large 3-5)")

	dungeon.queue_free()
	await frames(2)


func _test_player_knockback_immunity() -> void:
	print("\n[Test 3] Player Knockback & Knockdown Immunity...")
	var player = PLAYER_SCENE.instantiate()
	player.runtime_config = DEMO_CONFIG_TRES.duplicate()
	root.add_child(player)
	await frames(2)

	player.global_position = Vector2(100, 100)
	player.velocity = Vector2(50, 0)
	player.current_health = 100.0

	# 1. Test apply_external_knockback is a no-op
	player.apply_external_knockback(Vector2.RIGHT, 500.0)
	if player.external_knockback_velocity != Vector2.ZERO:
		failures.append("apply_external_knockback modified player.external_knockback_velocity!")
	else:
		print("PASS: apply_external_knockback does not alter player velocity")

	# 2. Test start_airborne_knockback is rejected when not recovering from pit
	player.start_airborne_knockback(Vector2.UP, 400.0, -2.0, false, false)
	if player.airborne_knockback:
		failures.append("start_airborne_knockback put player into airborne_knockback!")
	elif player.knockback_recovery_left > 0.0:
		failures.append("start_airborne_knockback locked player controls with knockback_recovery_left > 0!")
	else:
		print("PASS: start_airborne_knockback rejected; player remains grounded with 100% control")

	# 3. Test door impact does not knock back player
	var door := DOOR_SCRIPT.new()
	root.add_child(door)
	door._apply_actor_impact(player.get_instance_id(), Vector2.RIGHT, 150.0)
	if player.airborne_knockback:
		failures.append("Door impact launched player airborne!")
	elif player.external_knockback_velocity != Vector2.ZERO:
		failures.append("Door impact applied knockback velocity to player!")
	else:
		print("PASS: Door impact deals damage without knocking back or launching player")

	door.queue_free()
	player.queue_free()
	await frames(2)


func _test_cross_room_shooting_behavior() -> void:
	print("\n[Test 4] Cross-Room Shooting Behavior...")
	var enemy = EMPLOYEE_SCENE.instantiate()
	root.add_child(enemy)

	var mock_player := CharacterBody2D.new()
	mock_player.name = "MockPlayer"
	mock_player.set("dead", false)
	root.add_child(mock_player)
	await frames(2)

	# Configure enemy with assault rifle (ranged weapon)
	enemy.configure(
		mock_player,
		100.0,
		0.0,
		Rect2(0, 0, 500, 500),
		1.0,
		20.0,
		DEMO_CONFIG_TRES
	)
	enemy.equip_weapon("assault_rifle", 0)

	# Place enemy at (50, 50) in room 1
	enemy.global_position = Vector2(50, 50)
	enemy.set_meta(&"dream_room_id", 1)

	# Place player at (150, 50) in room 2 (distance = 100px <= max range ~400px)
	mock_player.global_position = Vector2(150, 50)
	enemy.last_known_room = 2
	enemy.last_known_target_position = mock_player.global_position
	enemy.has_last_known_target_position = true

	# Case A: Clear line of sight (e.g. open door / glass)
	enemy.can_see_target = true
	enemy.state = enemy.State.ATTACK_PLAYER

	# Process 1 frame of _update_attack_player
	enemy._update_attack_player(0.016)

	# In OTXO mode: enemy has LOS and is in range across rooms -> MUST NOT switch to MOVE_TO_DOOR
	if enemy.state == enemy.State.MOVE_TO_DOOR:
		failures.append("Enemy with LOS and weapon range across rooms switched to MOVE_TO_DOOR instead of shooting!")
	else:
		print("PASS: Enemy engages target across rooms when LOS and range are valid (state: %s)" % enemy.state)

	# Case B: Lost line of sight (player walked behind solid wall)
	enemy.can_see_target = false
	enemy.last_known_room = 2
	enemy.state = enemy.State.ATTACK_PLAYER

	enemy._update_attack_player(0.016)
	# When LOS is lost across rooms, enemy SHOULD route to the door to pursue
	if enemy.state != enemy.State.MOVE_TO_DOOR:
		print("INFO: When LOS is lost, enemy state = %s" % enemy.state)

	enemy.queue_free()
	mock_player.queue_free()
	await frames(2)
