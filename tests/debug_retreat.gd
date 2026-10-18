extends SceneTree

const PLAYER_SCENE := preload("res://scenes/entities/dream_player.tscn")
const EMPLOYEE_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const DEMO_CONFIG_TRES := preload("res://resources/demo_config.tres")

func _init() -> void:
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
	enemy.can_see_target = true
	enemy.has_last_known_target_position = true
	enemy.last_known_target_position = player.global_position
	enemy.last_known_room = -1
	enemy.set_meta(&"dream_room_id", -1)

	for i in 5:
		await physics_frame

	print("Before Step 1:")
	print("  vel: ", enemy.velocity)
	print("  can_see_target: ", enemy.can_see_target)
	print("  has_known_target: ", enemy._has_known_target())

	# Step 1
	enemy.ranged_attack_windup_pending = true
	enemy.current_ammo = 10
	enemy.reload_left = 0.0
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	enemy._update_attack_player(0.016)
	print("After Step 1:")
	print("  vel: ", enemy.velocity)
	print("  can_see_target: ", enemy.can_see_target)
	print("  has_known_target: ", enemy._has_known_target())
	print("  state: ", enemy.state)

	# Step 2
	enemy.current_ammo = 0
	enemy.reload_left = 1.5
	enemy._update_attack_player(0.016)
	print("After Step 2:")
	print("  vel: ", enemy.velocity)
	print("  can_see_target: ", enemy.can_see_target)
	print("  has_known_target: ", enemy._has_known_target())
	print("  state: ", enemy.state)
	var toward = (player.global_position - enemy.global_position).normalized()
	print("  toward: ", toward)
	print("  dot: ", enemy.velocity.dot(toward))

	quit(0)
