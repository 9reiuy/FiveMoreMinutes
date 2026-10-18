extends SceneTree

const DUNGEON_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const DOOR_SCRIPT := preload("res://scripts/dream/physical_door_3d.gd")
const ENEMY_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const ENEMY_SCRIPT := preload("res://scripts/entities/employee_enemy.gd")
const DEMO_CONFIG_TRES := preload("res://resources/demo_config.tres")
const PLAYER_SCRIPT := preload("res://scripts/entities/dream_player.gd")


func _init() -> void:
	print("--- Starting OTXO Enemy AI & Breakable Door Parity Tests ---")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: Array[String] = []

	_test_door_hp_and_damage_scaling(failures)
	_test_boss_door_immutability(failures)
	_test_movement_speeds(failures)
	_test_vision_fov_and_blind_spot(failures)
	_test_sound_hearing_range(failures)
	_test_lkp_and_sweep_search(failures)
	_test_weapon_ranges(failures)
	_test_enemy_door_kick_collision(failures)

	if failures.is_empty():
		print("\n=======================================================")
		print(" ALL OTXO ENEMY AI & DOOR PARITY TESTS PASSED! ")
		print("=======================================================\n")
		quit(0)
	else:
		push_error("OTXO ENEMY AI PARITY TESTS FAILED with %d errors:\n%s" % [failures.size(), "\n".join(failures)])
		quit(1)


func _make_enemy(cfg: DemoConfig = null, target_node: Node2D = null) -> EmployeeEnemy:
	var enemy := ENEMY_SCENE.instantiate() as EmployeeEnemy
	root.add_child(enemy)
	var resolved_cfg := cfg if cfg != null else (DEMO_CONFIG_TRES.duplicate() as DemoConfig)
	enemy.configure(target_node, 100.0, 0.0, Rect2(0, 0, 2000, 2000), 1.0, 20.0, resolved_cfg)
	enemy.set_physics_process(false)
	return enemy


func _test_door_hp_and_damage_scaling(failures: Array[String]) -> void:
	print("Running test_door_hp_and_damage_scaling...")
	var door := DOOR_SCRIPT.new()
	var collision_root := Node2D.new()
	door.configure(2.0, 3.0, 0.2, "left", 301)
	door.configure_gameplay_collision(collision_root, 32.0, 4)

	if door.max_health != 100.0 or door.current_health != 100.0:
		failures.append("Door max_health or current_health not 100.0: max=%f cur=%f" % [door.max_health, door.current_health])

	# 1. Kick deals 25 dmg (4 kicks break)
	door.apply_door_impact(&"kick", door.position, Vector3.FORWARD, 700.0)
	if not is_equal_approx(door.current_health, 75.0):
		failures.append("Kick 1 did not deduct 25 HP: expected 75.0, got %f" % door.current_health)

	# 2. Punch deals 20 dmg
	door.apply_door_impact(&"punch", door.position, Vector3.FORWARD, 260.0)
	if not is_equal_approx(door.current_health, 55.0):
		failures.append("Punch did not deduct 20 HP: expected 55.0, got %f" % door.current_health)

	# 3. Dash deals 50 dmg
	door.apply_door_impact(&"dash", door.position, Vector3.FORWARD, 260.0)
	if not is_equal_approx(door.current_health, 5.0):
		failures.append("Dash did not deduct 50 HP: expected 5.0, got %f" % door.current_health)

	# 4. Final kick finishes door
	door.apply_door_impact(&"kick", door.position, Vector3.FORWARD, 700.0)
	if not door.is_destroyed:
		failures.append("Final kick did not shatter 5hp door!")

	door.free()
	collision_root.free()


func _test_boss_door_immutability(failures: Array[String]) -> void:
	print("Running test_boss_door_immutability...")
	var door := DOOR_SCRIPT.new()
	var collision_root := Node2D.new()
	door.configure(2.0, 3.0, 0.2, "left", 999)
	door.is_boss_door = true
	door.locked = true
	door.configure_gameplay_collision(collision_root, 32.0, 4)

	door.take_damage(200.0, Vector2.RIGHT, 10.0)
	door.apply_door_impact(&"dash", door.position, Vector3.FORWARD, 1000.0)
	door.apply_door_impact(&"kick", door.position, Vector3.FORWARD, 1000.0)

	if door.current_health != 100.0 or door.is_destroyed:
		failures.append("Boss door must remain indestructible: hp=%f destroyed=%s" % [door.current_health, door.is_destroyed])

	door.free()
	collision_root.free()


func _test_movement_speeds(failures: Array[String]) -> void:
	print("Running test_movement_speeds...")
	var cfg := DEMO_CONFIG_TRES.duplicate()
	if cfg.employee_movement_speed != 100.0:
		failures.append("demo_config employee_movement_speed should be 100.0, got %f" % cfg.employee_movement_speed)
	if cfg.employee_run_speed_multiplier != 1.6:
		failures.append("demo_config employee_run_speed_multiplier should be 1.6, got %f" % cfg.employee_run_speed_multiplier)

	var enemy := _make_enemy(cfg)

	if enemy.movement_speed != 100.0:
		failures.append("Enemy movement_speed not 100.0, got %f" % enemy.movement_speed)

	# Patrol / Wander move speed
	enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	var patrol_speed: float = enemy._get_current_move_speed()
	if not is_equal_approx(patrol_speed, 100.0):
		failures.append("Enemy patrol speed should be 100.0, got %f" % patrol_speed)

	# Chase / Attack Player move speed
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	var chase_speed: float = enemy._get_current_move_speed()
	if not is_equal_approx(chase_speed, 160.0):
		failures.append("Enemy chase speed should be 160.0 (100 * 1.6), got %f" % chase_speed)

	enemy.free()


func _test_vision_fov_and_blind_spot(failures: Array[String]) -> void:
	print("Running test_vision_fov_and_blind_spot...")
	var cfg := DEMO_CONFIG_TRES.duplicate()
	if cfg.employee_vision_fov_degrees != 120.0:
		failures.append("employee_vision_fov_degrees should be 120.0, got %f" % cfg.employee_vision_fov_degrees)
	if cfg.employee_vision_range != 360.0:
		failures.append("employee_vision_range should be 360.0, got %f" % cfg.employee_vision_range)

	var player = PLAYER_SCRIPT.new()
	var enemy := _make_enemy(cfg, player)
	enemy.uses_visual_perception = true
	enemy.global_position = Vector2(500.0, 500.0)
	enemy.last_facing_direction = Vector2.RIGHT # Facing +X

	# Target in front (offset angle 0 deg) within range
	var front_target: Vector2 = enemy.global_position + Vector2(200.0, 0.0)
	var facing := enemy._get_gameplay_facing_direction()
	var offset := front_target - enemy.global_position
	var half_fov := deg_to_rad(cfg.employee_vision_fov_degrees * 0.5)
	var front_in_cone := facing.dot(offset.normalized()) >= cos(half_fov)
	if not front_in_cone:
		failures.append("Front target at 200px should be inside 120 deg FOV cone")

	# Target at 45 deg (within 60 deg half-angle)
	var angle_45_target: Vector2 = enemy.global_position + Vector2(200.0, 0.0).rotated(deg_to_rad(45.0))
	var offset_45 := angle_45_target - enemy.global_position
	var in_cone_45 := facing.dot(offset_45.normalized()) >= cos(half_fov)
	if not in_cone_45:
		failures.append("Target at 45 deg should be inside 120 deg FOV cone")

	# Target at 80 deg (outside 60 deg half-angle)
	var angle_80_target: Vector2 = enemy.global_position + Vector2(200.0, 0.0).rotated(deg_to_rad(80.0))
	var offset_80 := angle_80_target - enemy.global_position
	var in_cone_80 := facing.dot(offset_80.normalized()) >= cos(half_fov)
	if in_cone_80:
		failures.append("Target at 80 deg should be outside 120 deg FOV cone")

	# Blind spot: Target directly behind (-X)
	var behind_target: Vector2 = enemy.global_position - Vector2(100.0, 0.0)
	var offset_behind := behind_target - enemy.global_position
	var behind_in_cone := facing.dot(offset_behind.normalized()) >= cos(half_fov)
	if behind_in_cone:
		failures.append("Behind target must be rejected by FOV cone (blind spot)")

	enemy.free()
	player.free()


func _test_sound_hearing_range(failures: Array[String]) -> void:
	print("Running test_sound_hearing_range...")
	var cfg := DEMO_CONFIG_TRES.duplicate()
	var hearing_range: float = cfg.employee_sound_hearing_range
	if hearing_range != 700.0:
		failures.append("employee_sound_hearing_range should be 700.0, got %f" % hearing_range)

	var enemy := _make_enemy(cfg)
	enemy.set_meta(&"dream_room_id", 1)
	enemy.global_position = Vector2(500.0, 500.0)
	enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	enemy.hostile = false
	enemy.held_weapon_id = "basic"

	# Sound within hearing range (500 px < 700 px)
	var near_sound := enemy.global_position + Vector2(500.0, 0.0)
	enemy.on_room_gunshot(near_sound, 1)
	if enemy.state != EmployeeEnemy.State.INVESTIGATE_GUNSHOT:
		failures.append("Sound within 500px should trigger INVESTIGATE_GUNSHOT, got state=%d" % enemy.state)
	if enemy.gunshot_threat_position != near_sound:
		failures.append("Gunshot threat position not stored properly")

	# Sound beyond hearing range (900 px > 700 px)
	enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	var far_sound := enemy.global_position + Vector2(900.0, 0.0)
	enemy.on_room_gunshot(far_sound, 1)
	if enemy.state != EmployeeEnemy.State.NEUTRAL_WANDER:
		failures.append("Sound beyond 700px (at 900px) must be ignored, got state=%d" % enemy.state)

	enemy.free()


func _test_lkp_and_sweep_search(failures: Array[String]) -> void:
	print("Running test_lkp_and_sweep_search...")
	var cfg := DEMO_CONFIG_TRES.duplicate()
	var player = PLAYER_SCRIPT.new()
	var enemy := _make_enemy(cfg, player)
	enemy.set_meta(&"dream_room_id", 1)
	enemy.last_known_room = 1
	enemy.global_position = Vector2(500.0, 500.0)
	enemy.held_weapon_id = "basic"
	enemy.hostile = true
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER

	# Simulate Player losing LOS: set LKP far away (>10px)
	var lkp_far := Vector2(550.0, 500.0)
	enemy._remember_target_position(lkp_far, 1, Vector2.ZERO)
	enemy.can_see_target = false

	# Call _update_attack_player: enemy steers toward LKP and sets lkp_search_time_left to 2.0
	enemy._update_attack_player(0.016)
	if enemy.lkp_search_time_left != 2.0:
		failures.append("Enemy moving toward LKP should set lkp_search_time_left to 2.0s, got %f" % enemy.lkp_search_time_left)

	# Enemy reaches LKP (dist <= 10.0)
	enemy.global_position = lkp_far
	enemy._update_attack_player(0.1)
	if enemy.lkp_search_time_left >= 2.0 or enemy.lkp_search_time_left <= 0.0:
		failures.append("Enemy at LKP should decrement sweep search time, got %f" % enemy.lkp_search_time_left)

	# Advance time past 2.0s sweep
	enemy.lkp_search_time_left = 0.01
	enemy._update_attack_player(0.05)
	if enemy.has_last_known_target_position:
		failures.append("Enemy after sweep expiration should clear has_last_known_target_position")
	if enemy.state != EmployeeEnemy.State.NEUTRAL_WANDER:
		failures.append("Enemy after sweep expiration should transition to NEUTRAL_WANDER, got state=%d" % enemy.state)

	enemy.free()
	player.free()


func _test_weapon_ranges(failures: Array[String]) -> void:
	print("Running test_weapon_ranges...")
	var enemy := _make_enemy()

	# Lucille
	enemy.held_weapon_id = "lucille"
	if enemy._weapon_desired_range() != 30.0:
		failures.append("Lucille desired range expected 30.0, got %f" % enemy._weapon_desired_range())
	if enemy._weapon_max_range() != 44.0:
		failures.append("Lucille max range expected 44.0, got %f" % enemy._weapon_max_range())

	# Shotgun
	enemy.held_weapon_id = "shotgun"
	if enemy._weapon_desired_range() != 140.0:
		failures.append("Shotgun desired range expected 140.0, got %f" % enemy._weapon_desired_range())
	if enemy._weapon_max_range() != 220.0:
		failures.append("Shotgun max range expected 220.0, got %f" % enemy._weapon_max_range())

	# Assault Rifle
	enemy.held_weapon_id = "assault_rifle"
	if enemy._weapon_desired_range() != 380.0:
		failures.append("Assault Rifle desired range expected 380.0, got %f" % enemy._weapon_desired_range())
	if enemy._weapon_max_range() != 500.0:
		failures.append("Assault Rifle max range expected 500.0, got %f" % enemy._weapon_max_range())

	# Basic / SMG
	enemy.held_weapon_id = "basic"
	if enemy._weapon_desired_range() != 250.0:
		failures.append("Basic desired range expected 250.0, got %f" % enemy._weapon_desired_range())
	if enemy._weapon_max_range() != 350.0:
		failures.append("Basic max range expected 350.0, got %f" % enemy._weapon_max_range())

	enemy.free()


func _test_enemy_door_kick_collision(failures: Array[String]) -> void:
	print("Running test_enemy_door_kick_collision...")
	var door := DOOR_SCRIPT.new()
	var cr := Node2D.new()
	root.add_child(cr)
	door.configure(2.0, 3.0, 0.2, "left", 501)
	door.configure_gameplay_collision(cr, 32.0, 4)

	var enemy := _make_enemy()
	enemy.hostile = true
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	enemy.global_position = Vector2(100.0, 100.0)

	var leaf_body := cr.get_child(0) as StaticBody2D
	leaf_body.global_position = Vector2(110.0, 100.0)

	# Verify the door resolution logic works on the 2D collision body without constructor errors
	var door_node: Node = null
	if leaf_body.get("door_owner") is Node:
		door_node = leaf_body.get("door_owner") as Node
	elif leaf_body.has_meta(&"physical_door_node"):
		var d_ref = leaf_body.get_meta(&"physical_door_node")
		door_node = d_ref.get_ref() if d_ref is WeakRef else d_ref
	elif leaf_body.has_method("apply_door_impact"):
		door_node = leaf_body

	if door_node == null or not door_node.has_method("apply_door_impact"):
		failures.append("Failed to resolve door owner from 2D collision proxy")
	else:
		var is_locked: bool = door_node.get("locked") == true
		var is_destroyed: bool = door_node.get("is_destroyed") == true
		var is_boss: bool = door_node.get("is_boss_door") == true
		if not is_locked and not is_destroyed and not is_boss:
			door_node.call("apply_door_impact", &"kick", Vector3(enemy.global_position.x / 32.0, 1.5, enemy.global_position.y / 32.0), Vector3.RIGHT, 450.0)

	if door.current_health >= 100.0:
		failures.append("Door should have received kick impact damage: hp=%f" % door.current_health)

	enemy.free()
	door.free()
	cr.free()
