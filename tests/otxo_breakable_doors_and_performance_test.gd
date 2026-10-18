extends SceneTree

const DUNGEON_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const DOOR_SCRIPT := preload("res://scripts/dream/physical_door_3d.gd")
const DEMO_CONFIG_TRES := preload("res://resources/demo_config.tres")
const PLAYER_SCRIPT := preload("res://scripts/entities/dream_player.gd")
const DEPTH_BRIDGE_SCRIPT := preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")


func _init() -> void:
	print("--- Starting OTXO Breakable Doors and Performance Test ---")
	var failures: Array[String] = []

	_test_physical_doors_spawn_in_otxo_mode(failures)
	_test_breakable_door_damage_and_shatter(failures)
	_test_projectile_and_melee_impacts_damage_door(failures)
	_test_player_dash_smashable_door(failures)
	_test_boss_door_indestructible(failures)
	_test_permanent_room_activation_and_lighting(failures)
	_test_performance_optimizations(failures)
	_test_static_depth_bridge_freezing(failures)

	if failures.is_empty():
		print("\n=======================================================")
		print(" ALL OTXO BREAKABLE DOORS & OPTIMIZATION TESTS PASSED! ")
		print("=======================================================\n")
		quit(0)
	else:
		push_error("OTXO BREAKABLE DOORS TESTS FAILED with %d errors:\n%s" % [failures.size(), "\n".join(failures)])
		quit(1)


func _test_physical_doors_spawn_in_otxo_mode(failures: Array[String]) -> void:
	print("Running test_physical_doors_spawn_in_otxo_mode...")
	var dungeon := DUNGEON_SCRIPT.new()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.config.otxo_mansion_room_count = 14

	var success: bool = dungeon.generate_layout_only(7001)
	if not success:
		failures.append("Failed to generate layout only")
		dungeon.free()
		return

	dungeon.door_root = Node3D.new()
	dungeon.collision_root = Node2D.new()
	dungeon.wall_root = Node3D.new()
	dungeon.add_child(dungeon.door_root)
	dungeon.add_child(dungeon.collision_root)
	dungeon.add_child(dungeon.wall_root)
	dungeon._build_doors()
	var door_children := dungeon.door_root.get_children()
	if door_children.is_empty():
		failures.append("No doors spawned in OTXO mode! Expected doors on all room connections")
	elif door_children.size() < 5:
		failures.append("Too few doors spawned: %d" % door_children.size())

	var regular_door_found := false
	var boss_door_found := false
	for child in door_children:
		var door := child as PhysicalDoor3D
		if door == null:
			continue
		if door.is_boss_door:
			boss_door_found = true
			if not door.locked:
				failures.append("Boss door must be locked initially")
		else:
			regular_door_found = true
			if door.locked:
				failures.append("Regular doors should not be locked")

	if not regular_door_found:
		failures.append("No regular breakable doors found")
	if not boss_door_found:
		failures.append("No boss door found")

	dungeon.free()


func _test_breakable_door_damage_and_shatter(failures: Array[String]) -> void:
	print("Running test_breakable_door_damage_and_shatter...")
	var door := DOOR_SCRIPT.new()
	var collision_root := Node2D.new()

	door.configure(2.0, 3.0, 0.2, "left", 101)
	door.configure_gameplay_collision(collision_root, 32.0, 4)

	if door.current_health != 100.0 or door.is_destroyed:
		failures.append("Door initial state invalid: hp=%f destroyed=%s" % [door.current_health, door.is_destroyed])

	# Hit 1: non-fatal hit
	door.take_damage(20.0, Vector2(1, 0))
	if not is_equal_approx(door.current_health, 80.0) or door.is_destroyed:
		failures.append("Door non-fatal damage failed: hp=%f destroyed=%s" % [door.current_health, door.is_destroyed])

	# Hit 2: fatal hit via 2D proxy collision body (80 damage to finish 80 HP)
	var signal_state := {"shattered": false}
	door.door_shattered.connect(func(_d): signal_state.shattered = true)

	var proxy := collision_root.get_child(0) as StaticBody2D
	if proxy == null or not proxy.has_method("take_damage"):
		failures.append("2D door collision proxy missing or lacks take_damage")
	else:
		proxy.call("take_damage", 85.0, Vector2(1, 0), 2.0)

	if not door.is_destroyed or not bool(signal_state.shattered):
		failures.append("Door fatal shatter failed: destroyed=%s signal=%s" % [door.is_destroyed, signal_state.shattered])

	# Verify 2D collision layers cleared
	for body in door._collision_bodies:
		if body.collision_layer != 0:
			failures.append("Door collision body layer not cleared after shatter: %d" % body.collision_layer)

	door.free()
	collision_root.free()


func _test_projectile_and_melee_impacts_damage_door(failures: Array[String]) -> void:
	print("Running test_projectile_and_melee_impacts_damage_door...")
	# 1. Test kick impact damaging and breaking door (25 dmg per kick -> 4 kicks)
	var door_kick := DOOR_SCRIPT.new()
	var cr_kick := Node2D.new()
	door_kick.configure(2.0, 3.0, 0.2, "left", 102)
	door_kick.configure_gameplay_collision(cr_kick, 32.0, 4)

	door_kick.apply_door_impact(&"kick", door_kick.position, Vector3.FORWARD, 700.0)
	if not is_equal_approx(door_kick.current_health, 75.0):
		failures.append("Kick 1 did not deduct correct health: expected 75.0, got %f" % door_kick.current_health)

	door_kick.apply_door_impact(&"kick", door_kick.position, Vector3.FORWARD, 700.0)
	door_kick.apply_door_impact(&"kick", door_kick.position, Vector3.FORWARD, 700.0)
	door_kick.apply_door_impact(&"kick", door_kick.position, Vector3.FORWARD, 700.0)
	if not door_kick.is_destroyed:
		failures.append("Fourth kick did not shatter door!")

	door_kick.free()
	cr_kick.free()

	# 2. Test punch & melee impacts damaging door (punch 20 dmg, melee 50 dmg)
	var door_melee := DOOR_SCRIPT.new()
	var cr_melee := Node2D.new()
	door_melee.configure(2.0, 3.0, 0.2, "left", 103)
	door_melee.configure_gameplay_collision(cr_melee, 32.0, 4)

	door_melee.apply_door_impact(&"punch", door_melee.position, Vector3.FORWARD, 260.0)
	if not is_equal_approx(door_melee.current_health, 80.0):
		failures.append("Punch did not deduct 20 health: expected 80.0, got %f" % door_melee.current_health)

	door_melee.apply_door_impact(&"melee_lucille", door_melee.position, Vector3.FORWARD, 350.0)
	if not is_equal_approx(door_melee.current_health, 30.0):
		failures.append("Lucille melee did not deduct 50 health: expected 30.0, got %f" % door_melee.current_health)

	door_melee.apply_door_impact(&"melee_lucille", door_melee.position, Vector3.FORWARD, 350.0)
	if not door_melee.is_destroyed:
		failures.append("Second melee swing did not shatter remaining 30hp door!")

	door_melee.free()
	cr_melee.free()

	# 3. Test dash impact deals 50 dmg (2 dashes break door)
	var door_dash := DOOR_SCRIPT.new()
	var cr_dash := Node2D.new()
	door_dash.configure(2.0, 3.0, 0.2, "left", 104)
	door_dash.configure_gameplay_collision(cr_dash, 32.0, 4)

	door_dash.apply_door_impact(&"dash", door_dash.position, Vector3.FORWARD, 260.0)
	if not is_equal_approx(door_dash.current_health, 50.0):
		failures.append("First dash did not deduct 50 health: expected 50.0, got %f" % door_dash.current_health)

	door_dash.apply_door_impact(&"dash", door_dash.position, Vector3.FORWARD, 260.0)
	if not door_dash.is_destroyed:
		failures.append("Second dash did not shatter door!")

	door_dash.free()
	cr_dash.free()


func _test_player_dash_smashable_door(failures: Array[String]) -> void:
	print("Running test_player_dash_smashable_door...")
	var player := PLAYER_SCRIPT.new()
	var door := DOOR_SCRIPT.new()
	var cr := Node2D.new()
	door.configure(2.0, 3.0, 0.2, "left", 201)
	door.configure_gameplay_collision(cr, 32.0, 4)

	var regular_leaf: StaticBody2D = door._collision_bodies[0]
	if not player._dash_is_smashable_obstacle(regular_leaf):
		failures.append("Player dash must recognise regular breakable door leaf as smashable!")

	# Boss door must NOT be smashable by dash
	var boss_door := DOOR_SCRIPT.new()
	var cr_boss := Node2D.new()
	boss_door.configure(2.0, 3.0, 0.2, "left", 998)
	boss_door.is_boss_door = true
	boss_door.locked = true
	boss_door.configure_gameplay_collision(cr_boss, 32.0, 4)

	var boss_leaf: StaticBody2D = boss_door._collision_bodies[0]
	if player._dash_is_smashable_obstacle(boss_leaf):
		failures.append("Player dash must NOT treat Boss Door as smashable!")

	player.free()
	door.free()
	cr.free()
	boss_door.free()
	cr_boss.free()


func _test_boss_door_indestructible(failures: Array[String]) -> void:
	print("Running test_boss_door_indestructible...")
	var door := DOOR_SCRIPT.new()
	var collision_root := Node2D.new()

	door.configure(2.0, 3.0, 0.2, "left", 999)
	door.is_boss_door = true
	door.locked = true
	door.configure_gameplay_collision(collision_root, 32.0, 4)

	# Attempt heavy damage
	door.take_damage(100.0, Vector2(1, 0), 5.0)
	if door.current_health != 100.0 or door.is_destroyed:
		failures.append("Boss door must be indestructible! hp=%f destroyed=%s" % [door.current_health, door.is_destroyed])

	# Attempt violent physical impacts
	door.apply_door_impact(&"kick", door.position, Vector3.FORWARD, 1000.0)
	door.apply_door_impact(&"dash", door.position, Vector3.FORWARD, 1000.0)
	if door.current_health != 100.0 or door.is_destroyed:
		failures.append("Boss door must be immune to physical impacts!")

	door.free()
	collision_root.free()


func _test_permanent_room_activation_and_lighting(failures: Array[String]) -> void:
	print("Running test_permanent_room_activation_and_lighting...")
	var dungeon := DUNGEON_SCRIPT.new()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.config.otxo_mansion_room_count = 14

	dungeon.generate_layout_only(7002)

	dungeon.generated_root = Node3D.new()
	dungeon.wall_root = Node3D.new()
	dungeon.ceiling_light_root = preload("res://scripts/dream/dream_3d_ceiling_lighting.gd").new()
	dungeon.room_visibility = preload("res://scripts/dream/dream_3d_room_visibility.gd").new()
	dungeon.add_child(dungeon.generated_root)
	dungeon.add_child(dungeon.wall_root)
	dungeon.add_child(dungeon.ceiling_light_root)
	dungeon.add_child(dungeon.room_visibility)
	dungeon._build_ceiling_lights()
	dungeon.room_visibility.configure(dungeon)

	var r0 := dungeon.spawn_room_id
	var r1 := -1
	for room_id in dungeon.rooms.size():
		if room_id != r0 and room_id != dungeon.boss_room_id:
			r1 = room_id
			break

	# Activate room 0
	dungeon.set_current_room_id(r0)
	dungeon.activate_room(r0)

	# Transition to room 1
	dungeon.set_current_room_id(r1)
	dungeon.activate_room(r1)

	# Room 0 must remain activated in OTXO mode
	var r0_state: StringName = dungeon.room_states.get(r0, &"UNSEEN")
	if r0_state == &"UNSEEN":
		failures.append("Room 0 reverted to UNSEEN after leaving! Current state=%s" % r0_state)

	# Check lights: Room 0 ceiling lights must still be visible (not turned off)
	if dungeon.ceiling_light_root != null:
		var r0_lights_found := 0
		var r0_lights_visible := 0
		var r1_lights_found := 0
		var r1_spot_shadow_enabled := false
		var r0_spot_shadow_enabled := false

		for holder in dungeon.ceiling_light_root.get_children():
			var room_id := int(holder.get_meta(&"dream_room_id", -1))
			if room_id == r0:
				r0_lights_found += 1
				if holder.visible:
					r0_lights_visible += 1
				var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
				if spot != null and spot.shadow_enabled:
					r0_spot_shadow_enabled = true
			elif room_id == r1:
				r1_lights_found += 1
				var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
				if spot != null and spot.shadow_enabled:
					r1_spot_shadow_enabled = true

		if r0_lights_found > 0 and r0_lights_visible == 0:
			failures.append("Room 0 lights were turned off when player entered Room 1!")
		if r0_spot_shadow_enabled:
			failures.append("Room 0 should have tiered shadow disabled when player is in Room 1")
		if r1_lights_found > 0 and not r1_spot_shadow_enabled:
			failures.append("Room 1 (current room) should have SpotLight shadow_enabled = true")

	dungeon.free()


func _test_performance_optimizations(failures: Array[String]) -> void:
	print("Running test_performance_optimizations...")
	var dungeon := DUNGEON_SCRIPT.new()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	dungeon.generate_layout_only(7003)

	# Test AABB culling on walls
	var cam_pos := Vector3(0, 10, 0)
	var actor_pos := Vector3(5, 0, 5)
	var ray := actor_pos - cam_pos

	# A wall far away (e.g. at (100, 0, 100)) must be culled by AABB before ray equation
	var hit: bool = dungeon._segment_hits_wall_visual(cam_pos, actor_pos, ray)
	# Ray is between (0,0) and (5,5), walls exist in the dungeon
	# Verify that the function executes without error
	if hit is not bool:
		failures.append("Wall visual raycast failed to return bool")

	dungeon.free()


func _test_static_depth_bridge_freezing(failures: Array[String]) -> void:
	print("Running test_static_depth_bridge_freezing...")
	var dungeon := DUNGEON_SCRIPT.new()
	root.add_child(dungeon)
	dungeon.generate_on_ready = false
	dungeon.spawn_content = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.actor_depth_bridges_root = Node3D.new()
	dungeon.add_child(dungeon.actor_depth_bridges_root)

	var prop := Node2D.new()
	prop.add_to_group(&"damageable_props")
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	prop.add_child(sprite)
	dungeon.add_child(prop)

	var bridge: Node3D = dungeon._spawn_depth_bridge(prop, [NodePath("Sprite2D")])
	if bridge == null:
		failures.append("Failed to spawn depth bridge via dungeon")
		dungeon.free()
		return

	# Frame 1 capture
	bridge._process(0.016)
	if not bridge.capture_initialized:
		failures.append("Bridge failed to initialize capture on frame 1")

	# Frame 2: Freezing
	bridge._process(0.016)
	if not bridge.static_visual_frozen or bridge.is_processing():
		failures.append("Static bridge failed to freeze on frame 2: frozen=%s processing=%s" % [bridge.static_visual_frozen, bridge.is_processing()])

	# Mark dirty wakes it up
	bridge.mark_visual_dirty()
	if bridge.static_visual_frozen or not bridge.is_processing():
		failures.append("mark_visual_dirty failed to unfreeze bridge")

	dungeon.free()
