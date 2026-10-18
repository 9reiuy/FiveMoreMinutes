extends "res://tests/dream3d_combat_parity_test.gd"

## Focused regression coverage for the approved C -> B -> D -> A batch.  The
## test intentionally calls the public ownership/door APIs in both request
## orders instead of relying on SceneTree callback order.

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(60231), "regression generation")
	player = world.player
	world.run_interface.auto_open_upgrades = false
	world.target_highlight.set_physics_process(false)
	var start := Vector2(world.rooms[world.spawn_room_id].center_cell) * 32.0
	player.global_position = start
	await frames(2)

	# C/B: first accepted airborne transition is protected and extracts exactly
	# one active weapon through the world-owned forced-drop callback.
	player.equip_weapon("shotgun", CONFIG, {})
	var weapons_before := world.get_tree().get_nodes_in_group(&"world_weapon_pickups").size()
	var hp_before: float = player.current_health
	player.start_airborne_knockback(Vector2.RIGHT, 220.0)
	check(player.airborne_knockback, "first Player knock enters airborne")
	check(player.ranged_weapon_id.is_empty(), "Player active ranged weapon ownership cleared on knock")
	check(world.get_tree().get_nodes_in_group(&"world_weapon_pickups").size() == weapons_before + 1,
		"knock forced-drop creates exactly one world pickup")
	var velocity_after_first: Vector2 = player.velocity
	player.receive_damage(10.0, &"test_reentry")
	player.apply_external_knockback(Vector2.LEFT, 900.0)
	check(is_equal_approx(player.current_health, hp_before), "Player damage rejected during airborne recovery")
	check(player.velocity.x >= velocity_after_first.x, "Player knock velocity is not reset by re-entry")

	# D: soft Enemy reservation never hides the pickup from Player, and the
	# explicit Player commit wins whether the soft request was queued first.
	player.equip_weapon("basic", CONFIG, {})
	var pickup := preload("res://scenes/dream/world_weapon_pickup.tscn").instantiate() as WorldWeaponPickup
	pickup.weapon_id = "shotgun"
	world.world_weapon_root.add_child(pickup)
	pickup.global_position = player.global_position + Vector2(8.0, 0.0)
	var enemy := enemy_at(player.global_position + Vector2(18.0, 0.0), 100.0, 0.0)
	var enemy_request: bool = world.request_enemy_world_weapon_pickup(enemy, pickup)
	check(enemy_request and pickup.reserved_by == enemy, "Enemy reservation is soft")
	check(pickup.is_available_for(player), "soft Enemy reservation leaves Player available")
	world._swap_world_weapon(pickup)
	check(player.ranged_weapon_id == "shotgun", "Player explicit pickup overrides Enemy reservation")
	check(world.pending_enemy_pickup_requests.is_empty(), "Player commit cancels stale Enemy request before pickup recycle")
	check(not is_instance_valid(pickup) or pickup.ownership_state != WorldWeaponPickup.OwnershipState.ENEMY_CLAIMED,
		"Enemy cannot retain committed ownership after Player pickup")
	# D: exercise both request orders repeatedly.  The pickup-level ownership
	# API is intentionally used here so this proof does not depend on the
	# SceneTree order of the Player and Enemy callbacks.
	var pickup_race_ok := true
	for iteration in range(100):
		var race_pickup := preload("res://scenes/dream/world_weapon_pickup.tscn").instantiate() as WorldWeaponPickup
		race_pickup.weapon_id = "shotgun"
		world.world_weapon_root.add_child(race_pickup)
		race_pickup.global_position = player.global_position
		var player_won := false
		var enemy_requested := false
		if iteration % 2 == 0:
			enemy_requested = world.request_enemy_world_weapon_pickup(enemy, race_pickup)
			player_won = race_pickup.request_player_pickup(player)
		else:
			player_won = race_pickup.request_player_pickup(player)
			enemy_requested = world.request_enemy_world_weapon_pickup(enemy, race_pickup)
		pickup_race_ok = pickup_race_ok and player_won and (
			(enemy_requested and iteration % 2 == 0)
			or (not enemy_requested and iteration % 2 == 1)
		) and race_pickup.ownership_state == WorldWeaponPickup.OwnershipState.PLAYER_CLAIMED
		world.cancel_enemy_world_weapon_pickup(enemy, race_pickup)
		race_pickup.release_reservation(player)
		race_pickup.free()
	check(pickup_race_ok, "100 same-tick pickup races: Player wins in both request orders")
	if is_instance_valid(enemy):
		enemy.free()

	# A: one logical doorway grants one holder.  The first holder releases only
	# after exit; the opposite-side waiter then receives the next grant.
	var chosen_edge: Dictionary = {}
	for edge_variant in world.door_edges.values():
		var edge: Dictionary = edge_variant
		if int(edge.get("door_id", -1)) != world.boss_door_id:
			chosen_edge = edge
			break
	if not chosen_edge.is_empty():
		var sides: Array[Vector2i] = world._edge_side_cells(chosen_edge)
		var room_a := int(world.room_cells.get(sides[0], -1))
		var room_b := int(world.room_cells.get(sides[1], -1))
		var first := enemy_at(world._door_center_pixels(chosen_edge), 100.0, 0.0)
		var second := enemy_at(world._door_center_pixels(chosen_edge), 100.0, 0.0)
		first.set_meta(&"dream_room_id", room_a)
		second.set_meta(&"dream_room_id", room_b)
		var plan_a: Dictionary = world.get_employee_door_plan(first, room_b)
		var plan_b: Dictionary = world.get_employee_door_plan(second, room_a)
		first._begin_route_to_room(room_b)
		second._begin_route_to_room(room_a)
		first.global_position = plan_a.get("approach", first.global_position)
		second.global_position = plan_b.get("approach", second.global_position)
		var first_grant: bool = world.request_employee_door_transit(first, room_b, first.route_direction, first.door_transit_id)
		var second_grant: bool = world.request_employee_door_transit(second, room_a, second.route_direction, second.door_transit_id)
		check(first_grant and not second_grant, "door transit has one deterministic holder")
		world.release_employee_door_transit(first)
		check(world.employee_has_door_transit_grant(second, second.door_transit_id),
			"door release grants the waiting opposite-side Enemy")
		world.release_employee_door_transit(second)

		# Repeat the same doorway arbitration in alternating request order.  This
		# catches regressions where a stale holder or callback order lets both
		# sides enter ROOM_TRANSIT at once.
		var door_matrix_ok := true
		for iteration in range(100):
			world.door_transit_registry.clear()
			first.door_transit_granted = false
			first.door_transit_id = -1
			second.door_transit_granted = false
			second.door_transit_id = -1
			first.state = EmployeeEnemy.State.MOVE_TO_DOOR
			second.state = EmployeeEnemy.State.MOVE_TO_DOOR
			var grant_first := false
			var grant_second := false
			if iteration % 2 == 0:
				grant_first = world.request_employee_door_transit(first, room_b, first.route_direction, int(chosen_edge.get("door_id", -1)))
				grant_second = world.request_employee_door_transit(second, room_a, second.route_direction, int(chosen_edge.get("door_id", -1)))
			else:
				grant_second = world.request_employee_door_transit(second, room_a, second.route_direction, int(chosen_edge.get("door_id", -1)))
				grant_first = world.request_employee_door_transit(first, room_b, first.route_direction, int(chosen_edge.get("door_id", -1)))
			var holder: EmployeeEnemy = first if world.employee_has_door_transit_grant(first, int(chosen_edge.get("door_id", -1))) else second if world.employee_has_door_transit_grant(second, int(chosen_edge.get("door_id", -1))) else null
			var waiter: EmployeeEnemy = second if holder == first else first if holder == second else null
			door_matrix_ok = door_matrix_ok and ((grant_first and not grant_second) or (grant_second and not grant_first)) and holder != null and waiter != null
			if holder != null:
				world.release_employee_door_transit(holder)
				door_matrix_ok = door_matrix_ok and world.employee_has_door_transit_grant(waiter, int(chosen_edge.get("door_id", -1)))
				world.release_employee_door_transit(waiter)
		check(door_matrix_ok, "100 alternating two-sided doorway grants have no double holder/deadlock")

		# A stale combat holder must be released without waiting for a timeout;
		# the queued opposite-side employee receives the opening immediately.
		world.door_transit_registry.clear()
		first.door_transit_granted = false
		first.door_transit_id = -1
		second.door_transit_granted = false
		second.door_transit_id = -1
		first.state = EmployeeEnemy.State.MOVE_TO_DOOR
		second.state = EmployeeEnemy.State.MOVE_TO_DOOR
		world.request_employee_door_transit(first, room_b, first.route_direction, int(chosen_edge.get("door_id", -1)))
		world.request_employee_door_transit(second, room_a, second.route_direction, int(chosen_edge.get("door_id", -1)))
		first.state = EmployeeEnemy.State.KNOCKED_DOWN
		world._cleanup_door_transit_registry()
		check(world.employee_has_door_transit_grant(second, int(chosen_edge.get("door_id", -1))), "stale knocked-down door holder releases to waiter")
		world.release_employee_door_transit(second)
		first.free()
		second.free()

		# A 5v5 logical doorway soak.  The registry is exercised at 60 Hz for
		# 120 seconds worth of ticks without relying on SceneTree callback order.
		# Each release models the holder crossing the exit threshold; the next
		# grant must alternate sides when both queues are populated.
		var stress_enemies: Array[EmployeeEnemy] = []
		var stress_door_id := int(chosen_edge.get("door_id", -1))
		for side in range(2):
			var stress_from := room_a if side == 0 else room_b
			var stress_to := room_b if side == 0 else room_a
			var stress_direction: StringName = world._direction_between_rooms(stress_from, stress_to)
			for slot in range(5):
				var stress_enemy := enemy_at(world._door_center_pixels(chosen_edge), 100.0, 0.0)
				stress_enemy.set_meta(&"dream_room_id", stress_from)
				stress_enemy.route_target_room_id = stress_to
				stress_enemy.route_direction = stress_direction
				stress_enemy.door_transit_id = stress_door_id
				stress_enemy.state = EmployeeEnemy.State.MOVE_TO_DOOR
				stress_enemies.append(stress_enemy)
		var stress_passes := [0, 0]
		var stress_ok := true
		for tick in range(7200):
			for stress_enemy in stress_enemies:
				if not is_instance_valid(stress_enemy) or stress_enemy.door_transit_granted:
					continue
				var stress_from := int(stress_enemy.get_meta(&"dream_room_id", -1))
				var stress_to := room_b if stress_from == room_a else room_a
				world.request_employee_door_transit(
					stress_enemy,
					stress_to,
					stress_enemy.route_direction,
					stress_door_id
				)
			var stress_entry: Dictionary = world.door_transit_registry.get(stress_door_id, {})
			var stress_holder := stress_entry.get("holder") as EmployeeEnemy
			if stress_holder == null or not is_instance_valid(stress_holder):
				stress_ok = false
				break
			var holder_side := 0 if int(stress_holder.get_meta(&"dream_room_id", -1)) == room_a else 1
			stress_passes[holder_side] += 1
			world.release_employee_door_transit(stress_holder)
			var active_holders := 0
			for entry_variant in world.door_transit_registry.values():
				var entry: Dictionary = entry_variant
				if int(entry.get("holder_id", -1)) >= 0:
					active_holders += 1
			stress_ok = stress_ok and active_holders <= 1
		print("5V5 DOOR SOAK ticks=7200 passes_a=%d passes_b=%d" % [stress_passes[0], stress_passes[1]])
		check(stress_ok and stress_passes[0] > 0 and stress_passes[1] > 0 and abs(stress_passes[0] - stress_passes[1]) <= 1,
			"5v5 doorway soak: both sides pass with no starvation or double holder")
		for stress_enemy in stress_enemies:
			world.release_employee_door_transit(stress_enemy)
			stress_enemy.free()
		world.door_transit_registry.clear()
	else:
		check(false, "regression found an interior doorway")

	print("COMBAT FIXES REGRESSION checks=%d failures=%d" % [checks, failures.size()])
	world.free()
	await frames(12)
	quit(1 if failures.size() > 0 else 0)
