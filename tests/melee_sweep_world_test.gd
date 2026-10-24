extends "res://tests/dream3d_combat_parity_test.gd"
var aim := Vector2.RIGHT
var impacts := 0

func prepare_player(point: Vector2, kind := "lucille") -> Node:
	player.global_position = point
	player.dead = false
	player.movement_enabled = true
	player.set_attacking_enabled(true)
	player.equip_weapon(kind, CONFIG, {})
	player.set_physics_process(false)
	var weapon: Node = player.get_active_weapon()
	weapon.set_process(false)
	weapon.set_physics_process(false)
	return weapon

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(120), "Formal world generation")
	player = world.player
	player.set_meta(&"presentation_pointer_position", func() -> Vector2:
		return world.camera_3d.unproject_position(world.get_gameplay_world_position(player.global_position + aim * 180.0, 0.0)))
	var time_controller: Node = root.get_node("DreamTimeController")
	time_controller.set_process(false)
	Engine.time_scale = 1.0
	# An isolated off-map physics fixture avoids unrelated layout collisions;
	# actors, damage, death, doors and the 3D sweep are the formal runtime types.
	anchor = Vector2(12000,12000)
	var weapon := prepare_player(anchor)
	weapon.melee_impact.connect(func(_hit: bool) -> void: impacts += 1)
	for angle in [-50.0, 0.0, 50.0]:
		var enemy := enemy_at(anchor + Vector2(74,0).rotated(deg_to_rad(angle)), 1.0, 0.0)
		enemy.sky_drop_active = false
		enemy.sky_drop_height = 0.0
		enemy.set_process(false)
	await frames(2)
	time_controller.reset_hit_stop()
	world.camera_impulse_offset = Vector3.ZERO
	aim = Vector2.RIGHT
	weapon._perform_swing(false)
	weapon._physics_process(.15)
	aim = Vector2.LEFT
	check(player.get_aim_direction().dot(Vector2.RIGHT) > .99, "Actual character facing stays locked with the strike")
	check(player.visual.position.is_equal_approx(player.visual_home_position + player.lucille_character_offset), "Character offset is applied in the same snapshot as the weapon")
	check(impacts == 1, "Three lethal real-enemy hits produce one impact event")
	check(world.enemy_root.get_children().filter(func(enemy: Node) -> bool: return enemy.get("dead") == true).size() == 3, "Real enemies die from sweep")
	check(time_controller.hitstop_active and is_equal_approx(time_controller.hitstop_remaining_real, .04), "Multi-kill uses 40ms rather than stacking 70ms death freezes")
	check(world._player_melee_damage_depth == 0, "Nested death handling releases aggregate-feedback scope")
	check(world.camera_impulse_offset.length() < .30, "Multi-kill uses a single light camera impulse")
	weapon.cancel_swing()
	check(player.lucille_character_offset == Vector2.ZERO and player.weapon_motion.rotation == 0.0, "Cancel immediately resets both body and held pose")
	player.set_attacking_enabled(false)
	check(not weapon.melee_action_active and not weapon._visual.visible, "Actual attack disable immediately clears arc")
	# Real generated hinged door and its synchronized 2D mirror, not a mock.
	var physical_door: Node3D
	for candidate in world.door_root.get_children():
		if candidate is PhysicalDoor3D and not candidate.locked:
			physical_door = candidate
			break
	check(physical_door != null, "Generated floor provides a real unlocked door")
	if physical_door != null:
		physical_door.set_physics_process(false)
		var body: Node2D = physical_door._collision_bodies[0]
		var normal := Vector2.DOWN.rotated(body.rotation)
		var door_point: Vector2 = physical_door.get_leaf_center_2d(0)
		weapon = prepare_player(door_point - normal * 24.0)
		aim = normal
		await frames(2)
		weapon._perform_swing(false)
		weapon._physics_process(.15)
		check(physical_door.get_meta(&"last_impact_source", &"") == &"melee_lucille", "Real 2D mirror accepts sweep as formal door impact")
		weapon.cancel_swing()
	# Regenerate three floors with an in-flight sweep on each one.
	var old_carrier: WeakRef
	for floor_seed in [121,122,123]:
		weapon = prepare_player(anchor)
		aim = Vector2.RIGHT
		weapon._perform_swing(false)
		weapon._physics_process(.09)
		old_carrier = weakref(weapon._visual)
		check(weapon._visual.get_parent() == world.floor_root, "Carrier belongs to disposable floor %d" % floor_seed)
		check(world.regenerate(floor_seed), "Regenerate next formal floor %d" % floor_seed)
		await frames(2)
		check(old_carrier.get_ref() == null, "Old carrier is released on floor change %d" % floor_seed)
		check(world.find_children("PlayerMeleeSweep_*", "Node3D", true, false).is_empty(), "New floor has no stale wide arc %d" % floor_seed)
	print("MELEE_SWEEP_WORLD checks=", checks, " failures=", failures.size())
	world.free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
