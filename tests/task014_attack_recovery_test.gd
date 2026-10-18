extends "res://tests/dream3d_combat_parity_test.gd"

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	check(world.regenerate(41003), "attack recovery floor")
	player = world.player
	player.set_physics_process(false)
	world.set_process(false)
	world.target_highlight.set_physics_process(false)
	var cases := 0
	for connection in world.connections.slice(0, 10):
		var from_room := int(connection.a)
		var to_room := int(connection.b)
		world.activate_room(from_room)
		for spawned in world.enemy_root.get_children():
			spawned.set_physics_process(false)
		var edge: Dictionary = connection.door_edge
		var door_center: Vector2 = world._door_center_pixels(edge)
		var inward: Vector2 = Vector2(connection.door_a.outward)
		for weapon_id in ["basic", "shotgun", "lucille"]:
			var enemy := enemy_at(door_center - inward * 42.0)
			enemy.set_meta("dream_room_id", from_room)
			enemy.set_room_bounds(world._room_bounds_pixels(from_room, 2))
			enemy.equip_weapon(weapon_id)
			enemy.hostile = true
			enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
			enemy.can_see_target = true
			player.global_position = door_center + inward * 110.0
			enemy._remember_target_position(player.global_position, to_room)
			enemy.attack_cooldown_left = 1000.0
			enemy._update_attack_player(0.016)
			# A legitimate windup must not accrue a stuck timer.
			enemy.ranged_attack_windup_pending = true
			enemy.attack_movement_intent = true
			enemy._update_stuck_detection(1.0)
			check(enemy.stuck_elapsed == 0.0, "windup exemption")
			enemy.ranged_attack_windup_pending = false
			enemy.attack_movement_intent = false
			enemy._update_stuck_detection(1.0)
			check(enemy.stuck_elapsed == 0.0, "stationary attack exemption")
			# Inject the measured condition (zero displacement despite movement
			# intent), then run real collision movement from the selected recovery.
			enemy.attack_movement_intent = true
			enemy.stuck_anchor = enemy.global_position
			enemy.steering_commit_left = 0.0
			enemy._update_stuck_detection(0.7)
			check(enemy.steering_commit_left > 0.0 or enemy.state == EmployeeEnemy.State.MOVE_TO_DOOR, "attack chooses recovery " + weapon_id)
			var origin := enemy.global_position
			var max_step := 0.0
			for tick in 20:
				await physics_frame
				var previous := enemy.global_position
				if enemy.state == EmployeeEnemy.State.ATTACK_PLAYER:
					enemy._update_attack_player(1.0 / 60.0)
					enemy.move_and_slide()
				else:
					enemy.set_physics_process(true)
				max_step = maxf(max_step, previous.distance_to(enemy.global_position))
			check(enemy.global_position.distance_to(origin) > 2.5, "recovery physically moves " + weapon_id)
			check(max_step < 10.0, "recovery does not teleport")
			enemy.free()
			cases += 1
	print("TASK014 ATTACK cases=", cases, " checks=", checks, " failures=", failures.size())
	world.free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
