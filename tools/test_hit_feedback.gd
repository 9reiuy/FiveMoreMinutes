extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TESTING HIT FEEDBACK & HEALTH BAR INTEGRATION ===")
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	for i in range(5):
		await process_frame

	var player = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var enemy_root = scene.get_node("GameplayCanvas/GameplayWorld/EnemyRoot")
	var standoff_enemy = enemy_root.get_child(0)

	print("[1] Player initial health: ", player.current_health, " / ", player.maximum_health)
	assert(player.current_health > 0, "Player must have positive health!")

	print("[2] Standoff enemy initial health: ", standoff_enemy.current_health)
	assert(standoff_enemy.current_health > 0, "Standoff enemy must have positive health!")

	# Simulate damage on player
	player.receive_damage(20.0, &"test_bullet", Vector2(192, 1000), Vector2.DOWN)
	print("    Player health after 20 damage: ", player.current_health)
	assert(player.current_health == 60.0, "Player health should now be 60.0!")

	# Simulate damage on enemy
	standoff_enemy.take_damage(5.0, standoff_enemy.global_position, 100.0, &"player_projectile")
	print("    Standoff enemy health after 5 damage: ", standoff_enemy.current_health)
	assert(standoff_enemy.current_health == 5.0, "Enemy health should now be 5.0!")

	print("=== BASIC HEALTH DAMAGE LOGIC VERIFIED! ===")
	quit(0)
