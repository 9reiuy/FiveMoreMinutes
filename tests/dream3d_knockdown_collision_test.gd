extends "res://tests/dream3d_combat_parity_test.gd"


func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41006), "knockdown generation")
	player = world.player
	world.run_interface.auto_open_upgrades = false
	world.target_highlight.set_physics_process(false)
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell) * 32.0
	player.global_position = anchor
	await frames(3)

	var enemy := enemy_at(anchor, 1000.0, 0.0)
	enemy.global_position = anchor
	enemy.set_physics_process(false)
	await frames(3)
	enemy.separation_query_left = 0.0
	enemy._update_local_separation(0.20)
	check(enemy.cached_separation_velocity.length() > 0.0, "Enemy local separation includes overlapping Player body")

	var health_before: float = player.current_health
	player.start_airborne_knockback(Vector2.RIGHT, 180.0)
	player.receive_damage(1.0, &"test_during_airborne")
	check(is_equal_approx(player.current_health, health_before), "airborne knockdown is invulnerable through damage gate")
	player.external_knockback_velocity = Vector2.ZERO
	player.airborne_grounded_sliding = true
	await frames(2)
	check(not player.airborne_knockback and player.knockback_recovery_left > 0.0, "settled launch enters explicit get-up recovery")
	player.receive_damage(1.0, &"test_during_getup")
	check(is_equal_approx(player.current_health, health_before), "get-up recovery remains invulnerable")

	await create_timer(CONFIG.player_knockback_recovery_seconds + 0.35).timeout
	player.receive_damage(1.0, &"test_post_getup_grace")
	check(is_equal_approx(player.current_health, health_before), "post-getup 0.8 second grace remains active")
	await create_timer(0.55).timeout
	player.receive_damage(1.0, &"test_after_grace")
	check(player.current_health < health_before, "damage resumes after get-up plus 0.8 seconds")

	print("KNOCKDOWN COLLISION checks=", checks, " failures=", failures.size())
	world.free()
	await frames(12)
	quit(1 if failures.size() else 0)
