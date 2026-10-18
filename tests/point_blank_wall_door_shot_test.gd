extends "res://tests/dream3d_combat_parity_test.gd"

## Point-blank walls stop bullets; office bullets damage physical doors and pass through.

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41002), "dungeon generation")
	player = world.player
	world.run_interface.auto_open_upgrades = false
	world.target_highlight.set_physics_process(true)
	player.set_physics_process(false)
	player.invulnerability_left = 100

	var room_info: Dictionary = world.rooms[world.spawn_room_id]
	var center: Vector2 = Vector2(room_info.center_cell) * 32.0
	var room_bounds_px: Rect2 = world._room_bounds_pixels(world.spawn_room_id, 0.0)

	# -------------------------------------------------------------------------
	# 1. Point-blank Solid Wall Shooting
	# -------------------------------------------------------------------------
	print("--- Testing Point-blank Solid Wall Shooting ---")
	var solid_wall: StaticBody2D = null
	for child in world.collision_root.get_children():
		if child is StaticBody2D and child.name.begins_with("WallCollision_V_"):
			if child.global_position.distance_to(center) < 250.0:
				solid_wall = child
				break
	check(solid_wall != null, "Found solid vertical room wall")

	var wall_pos: Vector2 = solid_wall.global_position if solid_wall != null else center + Vector2(-100, 0)
	var wall_dir := Vector2.LEFT
	var wall_touch_pos := Vector2.ZERO

	if center.x >= wall_pos.x:
		wall_dir = Vector2.LEFT
		wall_touch_pos = Vector2(wall_pos.x + 16.0, wall_pos.y)
	else:
		wall_dir = Vector2.RIGHT
		wall_touch_pos = Vector2(wall_pos.x - 16.0, wall_pos.y)

	print("Solid wall name: ", solid_wall.name, " wall_pos: ", wall_pos, " center: ", center, " wall_dir: ", wall_dir)
	player.global_position = wall_touch_pos
	player.set_meta(&"aim_direction_override", wall_dir)
	player.call("_update_held_weapon_aim")
	await frames(2)

	var safe_muzzle: Vector2 = player.get_projectile_origin()
	var room_side_check: bool = (safe_muzzle.x >= wall_pos.x + 7.0) if wall_dir == Vector2.LEFT else (safe_muzzle.x <= wall_pos.x - 7.0)
	check(room_side_check, "Player muzzle clamped on room side of wall (muzzle.x=%.1f, wall.x=%.1f, dir=%s)" % [safe_muzzle.x, wall_pos.x, wall_dir])

	# Fire pistol into the solid wall
	player.equip_weapon("basic", CONFIG, {})
	player.call("_update_held_weapon_aim")
	player.auto_weapon._fire(wall_dir, false)
	check(get_nodes_in_group("active_basic_projectiles").size() == 1, "Pistol creates one real projectile before wall impact")
	await frames(1)

	for p in get_nodes_in_group("active_basic_projectiles"):
		if is_instance_valid(p) and not p.consumed:
			var bullet_room_side: bool = (p.global_position.x >= wall_pos.x + 6.0) if wall_dir == Vector2.LEFT else (p.global_position.x <= wall_pos.x - 6.0)
			check(bullet_room_side, "Pistol bullet spawned on room side of solid wall")

	await frames(4)
	var active_after := 0
	for p in get_nodes_in_group("active_basic_projectiles"):
		if is_instance_valid(p) and not p.consumed:
			active_after += 1
	check(active_after == 0, "Pistol bullet consumed by solid wall collision without penetrating")

	# Fire shotgun into the solid wall
	player.equip_weapon("shotgun", CONFIG, {})
	player.call("_update_held_weapon_aim")
	player.shotgun_weapon._fire_full_volley(wall_dir, false)
	check(get_nodes_in_group("active_basic_projectiles").size() == player.shotgun_weapon.pellet_count, "Shotgun creates full volley before wall impact")
	await frames(1)
	for p in get_nodes_in_group("active_basic_projectiles"):
		if is_instance_valid(p) and not p.consumed:
			var pellet_room_side: bool = (p.global_position.x >= wall_pos.x + 5.0) if wall_dir == Vector2.LEFT else (p.global_position.x <= wall_pos.x - 5.0)
			check(pellet_room_side, "Shotgun pellet spawned on room side of solid wall")
	await frames(5)
	var active_pellets := 0
	for p in get_nodes_in_group("active_basic_projectiles"):
		if is_instance_valid(p) and not p.consumed:
			active_pellets += 1
	check(active_pellets == 0, "All shotgun pellets consumed by solid wall collision")

	# -------------------------------------------------------------------------
	# 2. Point-blank Physical Door Shooting & Target Highlight
	# -------------------------------------------------------------------------
	print("--- Testing Point-blank Physical Door Shooting & Target Highlight ---")
	check(not get_nodes_in_group("physical_door_3d").is_empty(), "Dungeon contains generated physical doors")
	# Use an owned closed door in this room: a generated door in another room
	# may have its gameplay collision disabled by room activation.
	var test_door := DOOR.instantiate() as PhysicalDoor3D
	test_door.configure(1.84, 3.0, 0.1, "left", 7002, &"single")
	test_door.position = Vector3(center.x / 32.0, 0.0, center.y / 32.0)
	test_door.rotation.y = PI * 0.5
	world.door_root.add_child(test_door)
	test_door.configure_gameplay_collision(world.collision_root, 32.0, 4)
	test_door.set_gameplay_collision_enabled(true)
	test_door.locked = false
	test_door.latched = true
	test_door.door_max_angle_degrees = 5.0
	test_door.max_health = 500.0
	test_door.current_health = 500.0
	test_door.door_leaf.freeze = true
	test_door.door_leaf.rotation = Vector3.ZERO
	test_door.door_leaf.position = Vector3(0.0, test_door.door_height * 0.5, 0.0)
	test_door._sync_gameplay_collision()
	await frames(2)
	var door_body := test_door._collision_bodies[0] as StaticBody2D
	var door_pos := door_body.global_position
	var to_door := Vector2.RIGHT
	player.global_position = door_pos - to_door * 16.0 + Vector2(0, 12)
	player.set_meta(&"aim_direction_override", to_door)
	player.equip_weapon("basic", world.config, {})
	player.call("_update_held_weapon_aim")
	var enemy_behind := enemy_at(door_pos + to_door * 50.0 + Vector2(0, 12), 200.0)
	await frames(2)
	check(door_body.collision_layer == 4, "Closed door fixture has live gameplay collision")
	var selected: Node = world.target_highlight.find_target(player.get_aim_origin(), to_door, 200.0, player.get_rid())
	check(selected != enemy_behind, "Closed physical door blocks target selection")
	check((player.get_projectile_origin() - door_pos).dot(to_door) < 0.0, "Muzzle begins on player's side of closed door")
	var door_hp_before := test_door.current_health
	var enemy_hp_before := enemy_behind.current_health
	player.auto_weapon._fire(to_door, false)
	await frames(6)
	check(test_door.current_health < door_hp_before, "Office pistol damages closed door before passing through")
	check(enemy_behind.current_health < enemy_hp_before, "Office pistol continues beyond physical door")
	door_hp_before = test_door.current_health
	enemy_hp_before = enemy_behind.current_health
	player.equip_weapon("shotgun", world.config, {})
	player.call("_update_held_weapon_aim")
	player.shotgun_weapon._fire_full_volley(to_door, false)
	await frames(6)
	check(test_door.current_health < door_hp_before, "Office shotgun pellets damage closed door")
	check(enemy_behind.current_health < enemy_hp_before, "Office shotgun continues beyond physical door")
	enemy_behind.free()
	test_door.free()
	for projectile in get_nodes_in_group("active_basic_projectiles"):
		projectile.queue_free()
	await frames(2)
	# -------------------------------------------------------------------------
	# 3. Enemy Point-blank Shooting Anti-penetration
	# -------------------------------------------------------------------------
	print("--- Testing Enemy Point-blank Shooting ---")
	var enemy_wall_pos := wall_touch_pos
	var test_enemy := enemy_at(enemy_wall_pos, 100.0)
	test_enemy.equip_weapon("basic")
	await frames(2)

	var enemy_safe_muzzle: Vector2 = test_enemy.get_projectile_origin()
	var enemy_muzzle_dot: float = (enemy_safe_muzzle - wall_pos).dot(wall_dir)
	check(enemy_muzzle_dot <= 1.0, "Enemy muzzle clamped in front of wall")

	test_enemy._spawn_bullet(wall_dir, 10.0, 270.0, 155.0, &"basic")
	await frames(1)
	for p in get_nodes_in_group("active_basic_projectiles"):
		if is_instance_valid(p) and not p.consumed:
			var p_dot: float = (p.global_position - wall_pos).dot(wall_dir)
			check(p_dot <= 2.0, "Enemy bullet spawned on room side of wall")
	await frames(5)
	test_enemy.free()
	await frames(2)

	# -------------------------------------------------------------------------
	# 4. Open Room Shooting Regression Check
	# -------------------------------------------------------------------------
	print("--- Testing Open Room Normal Shooting ---")
	player.global_position = center + Vector2(-60.0, 0.0)
	player.set_meta(&"aim_direction_override", Vector2.RIGHT)
	player.call("_update_held_weapon_aim")
	await frames(2)

	var target_enemy := enemy_at(center + Vector2(60.0, 0.0), 100.0)
	await frames(2)

	var target_hp_before: float = target_enemy.current_health
	player.equip_weapon("basic", CONFIG, {})
	var open_muzzle: Vector2 = player.get_projectile_origin()
	check(open_muzzle.x > player.global_position.x + 10.0, "Open room muzzle maintains nominal forward distance")

	player.auto_weapon._fire(Vector2.RIGHT, false)
	await frames(20)
	check(target_enemy.current_health < target_hp_before, "Open room normal shooting damages enemy as expected")
	target_enemy.free()
	await frames(4)

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n==========================================")
	print("CHECKS RUN: ", checks)
	print("FAILURES: ", failures.size())
	if not failures.is_empty():
		for f in failures:
			print("  FAILED: ", f)
		print("==========================================")
		quit(1)
	else:
		print("ALL POINT-BLANK WALL AND OFFICE DOOR TESTS PASSED!")
		print("==========================================")
		quit(0)
