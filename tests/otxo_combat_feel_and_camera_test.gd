extends SceneTree

const DUNGEON_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const DEMO_CONFIG_TRES = preload("res://resources/demo_config.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/dream_player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	print("--- Starting OTXO Combat Feel and Camera Look-Ahead Test Suite ---")

	await _test_extended_camera_aim_look_ahead()
	await _test_player_firearm_recoil_and_camera_shake()
	await _test_player_hurt_directional_shake()
	await _test_enemy_hit_and_kill_feedback()

	print("\n=====================================================================")
	if failures.is_empty():
		print(" ALL OTXO COMBAT FEEL AND CAMERA TESTS PASSED (100%)! ")
	else:
		print(" FAILED (%d errors):" % failures.size())
		for f in failures:
			print("  - " + f)
	print("=====================================================================\n")

	quit(0 if failures.is_empty() else 1)


func _test_extended_camera_aim_look_ahead() -> void:
	print("\n[Test 1] Extended Camera Aim Look-Ahead Range (OTXO Parity)...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()

	root.add_child(dungeon)
	await frames(2)

	# Verify configuration values match OTXO large look-ahead specifications
	if dungeon.config.camera_aim_max_offset_x < 150.0:
		failures.append("camera_aim_max_offset_x expected >= 150.0, got %f" % dungeon.config.camera_aim_max_offset_x)
	if dungeon.config.camera_aim_max_offset_y < 90.0:
		failures.append("camera_aim_max_offset_y expected >= 90.0, got %f" % dungeon.config.camera_aim_max_offset_y)
	if dungeon.config.camera_aim_distance_for_max_offset < 300.0:
		failures.append("camera_aim_distance_for_max_offset expected >= 300.0, got %f" % dungeon.config.camera_aim_distance_for_max_offset)
	if dungeon.config.camera_aim_smoothing < 8.0:
		failures.append("camera_aim_smoothing expected >= 8.0, got %f" % dungeon.config.camera_aim_smoothing)

	# Test horizontal max aim offset (500px right, fully converged with large delta)
	dungeon.camera_aim_offset = Vector3.ZERO
	var offset_x_converged: Vector3 = dungeon.compute_camera_aim_offset(Vector2.ZERO, Vector2(500.0, 0.0), 10.0)
	var expected_world_x: float = dungeon.config.camera_aim_max_offset_x / 32.0 # 160 / 32 = 5.0
	if absf(offset_x_converged.x - expected_world_x) > 0.05:
		failures.append("Expected horizontal aim offset ~%f, got %f" % [expected_world_x, offset_x_converged.x])

	# Test vertical max aim offset (500px down)
	dungeon.camera_aim_offset = Vector3.ZERO
	var offset_y_converged: Vector3 = dungeon.compute_camera_aim_offset(Vector2.ZERO, Vector2(0.0, 500.0), 10.0)
	var expected_world_z: float = dungeon.config.camera_aim_max_offset_y / 32.0 # 100 / 32 = 3.125
	if absf(offset_y_converged.z - expected_world_z) > 0.05:
		failures.append("Expected vertical aim offset ~%f, got %f" % [expected_world_z, offset_y_converged.z])

	# Test half distance proportional scaling
	dungeon.camera_aim_offset = Vector3.ZERO
	var half_dist: float = dungeon.config.camera_aim_distance_for_max_offset * 0.5
	var offset_half: Vector3 = dungeon.compute_camera_aim_offset(Vector2.ZERO, Vector2(half_dist, 0.0), 10.0)
	var expected_half_x: float = expected_world_x * 0.5
	if absf(offset_half.x - expected_half_x) > 0.05:
		failures.append("Expected half-distance aim offset ~%f, got %f" % [expected_half_x, offset_half.x])

	dungeon.queue_free()
	await frames(2)


func _test_player_firearm_recoil_and_camera_shake() -> void:
	print("\n[Test 2] Player Firearm Recoil and Weapon-Differentiated Camera Impulse...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.add_to_group(&"dream_world")

	root.add_child(dungeon)
	await frames(2)

	var player = PLAYER_SCENE.instantiate()
	player.runtime_config = dungeon.config
	root.add_child(player)
	await frames(2)

	# Test 1: Shotgun firing
	player.selected_weapon_id = &"shotgun"
	dungeon.camera_impulse_offset = Vector3.ZERO
	dungeon.camera_shake_amplitude = 0.0

	var aim_dir: Vector2 = player.get_aim_direction().normalized()
	player._apply_firearm_recoil(1.0)

	var impulse_dir := Vector2(dungeon.camera_impulse_offset.x, dungeon.camera_impulse_offset.z)
	var dot_product: float = aim_dir.dot(impulse_dir)
	if dot_product >= 0.0:
		failures.append("Shotgun recoil should kick camera opposite to aim direction, got dot=%f" % dot_product)
	if dungeon.camera_shake_amplitude <= 0.02:
		failures.append("Shotgun should cause noticeable camera shake amplitude, got %f" % dungeon.camera_shake_amplitude)
	var shotgun_amplitude: float = dungeon.camera_shake_amplitude

	# Test 2: Pistol firing
	dungeon.camera_impulse_offset = Vector3.ZERO
	dungeon.camera_shake_amplitude = 0.0
	player.selected_weapon_id = &"handgun"
	player._apply_firearm_recoil(1.0)

	impulse_dir = Vector2(dungeon.camera_impulse_offset.x, dungeon.camera_impulse_offset.z)
	dot_product = aim_dir.dot(impulse_dir)
	if dot_product >= 0.0:
		failures.append("Pistol recoil should kick camera opposite to aim direction, got dot=%f" % dot_product)
	if dungeon.camera_shake_amplitude >= shotgun_amplitude:
		failures.append("Pistol shake (%f) should be less than shotgun shake (%f)" % [dungeon.camera_shake_amplitude, shotgun_amplitude])

	player.queue_free()
	dungeon.queue_free()
	await frames(2)


func _test_player_hurt_directional_shake() -> void:
	print("\n[Test 3] Player Hurt Directional Shockwave and Intensity...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.add_to_group(&"dream_world")

	root.add_child(dungeon)
	await frames(2)

	var player = PLAYER_SCENE.instantiate()
	player.runtime_config = dungeon.config
	root.add_child(player)
	await frames(2)

	# Take damage from left (bullet flying right Vector2(1, 0))
	dungeon.camera_impulse_offset = Vector3.ZERO
	dungeon.camera_shake_amplitude = 0.0

	player.receive_damage(30.0, &"employee_projectile", Vector2.INF, Vector2(1.0, 0.0))

	if dungeon.camera_impulse_offset.x <= 0.0:
		failures.append("Damage from left (flying right) should push camera right (+X), got x=%f" % dungeon.camera_impulse_offset.x)
	if dungeon.camera_shake_amplitude < 0.04:
		failures.append("Heavy damage (30.0) should trigger strong camera shake, got amplitude=%f" % dungeon.camera_shake_amplitude)

	player.queue_free()
	dungeon.queue_free()
	await frames(2)


func _test_enemy_hit_and_kill_feedback() -> void:
	print("\n[Test 4] Enemy Hit and Defeat Camera Punch...")
	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.add_to_group(&"dream_world")

	root.add_child(dungeon)
	await frames(2)

	var player = PLAYER_SCENE.instantiate()
	player.runtime_config = dungeon.config
	dungeon.player = player
	root.add_child(player)
	player.global_position = Vector2.ZERO
	await frames(2)

	# Test Enemy Defeated / Kill Camera Punch (enemy at (100, 0))
	dungeon.camera_impulse_offset = Vector3.ZERO
	dungeon.camera_shake_amplitude = 0.0

	dungeon._on_enemy_defeated(Vector2(100.0, 0.0), 1)

	if dungeon.camera_impulse_offset.x <= 0.0:
		failures.append("Kill camera punch should push towards kill direction (+X), got x=%f" % dungeon.camera_impulse_offset.x)
	if dungeon.camera_shake_amplitude < 0.04:
		failures.append("Kill camera punch should trigger heavy shake amplitude, got %f" % dungeon.camera_shake_amplitude)

	# Test Combat Impact knockback handling
	dungeon.camera_impulse_offset = Vector3.ZERO
	dungeon.camera_shake_amplitude = 0.0

	dungeon.request_combat_impact(500.0, Vector2(0.0, 1.0), &"kick")
	if dungeon.camera_impulse_offset.z <= 0.0:
		failures.append("Combat impact downwards should kick camera +Z, got z=%f" % dungeon.camera_impulse_offset.z)

	player.queue_free()
	dungeon.queue_free()
	await frames(2)
