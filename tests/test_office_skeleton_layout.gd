extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const GENERATOR = preload("res://scripts/dream/dream_3d_random_dungeon.gd")

var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING TASK-016-B OFFICE SKELETON LAYOUT TEST ===")

	# -------------------------------------------------------------
	# Test Suite 1: Multi-Seed Structural & Generator Verification
	# -------------------------------------------------------------
	var test_seeds: Array[int] = [
		42001, 42002, 42003, 42004, 42005,
		1337, 7777, 99999, 100, 2026,
		51515, 88888, 31415, 27182, 12345
	]

	var non_combat_ids: Array[int] = [0, 1, 2, 3, 13, 14]
	var gen: Node = GENERATOR.new()

	for test_seed in test_seeds:
		var ok: bool = gen.generate_layout_only(test_seed)
		check(ok, "Seed %d: generate_layout_only returned true" % test_seed)
		if not ok:
			continue

		# 1. Total room count
		check(gen.rooms.size() == 15, "Seed %d: exactly 15 rooms generated (got %d)" % [test_seed, gen.rooms.size()])

		# 2. Exactly 2 Large Rooms on the entire floor
		var large_rooms: Array[Dictionary] = []
		for r in gen.rooms:
			if r.get("size_class", &"small") == &"large":
				large_rooms.append(r)
		check(large_rooms.size() == 2, "Seed %d: exactly 2 Large Rooms on floor (got %d)" % [test_seed, large_rooms.size()])

		var left_large_found := false
		var right_large_found := false
		for lr in large_rooms:
			check(bool(lr.get("combat_room", false)), "Seed %d: Large room %d is combat room" % [test_seed, lr.get("id")])
			var center_x: int = lr.get("center_cell", Vector2i.ZERO).x
			if center_x < 0:
				left_large_found = true
			elif center_x > 0:
				right_large_found = true
		check(left_large_found and right_large_found, "Seed %d: One large room in West wing (X < 0) and one in East wing (X > 0)" % test_seed)

		# 3. Elevator Room (Top-Center)
		check(gen.elevator_room_id == 14, "Seed %d: elevator_room_id is 14" % test_seed)
		var elev_anchor: Vector2i = gen.elevator_anchor_cell
		check(elev_anchor.y <= -26 and absi(elev_anchor.x) <= 2, "Seed %d: elevator anchor is top-center (%s)" % [test_seed, str(elev_anchor)])

		# 4. Non-combat rooms verification
		for ncid in non_combat_ids:
			if ncid < gen.rooms.size():
				var r: Dictionary = gen.rooms[ncid]
				check(not bool(r.get("combat_room", true)), "Seed %d: Room %d (%s) is non-combat" % [test_seed, ncid, r.get("name")])

		# 5. Semantic room types
		check(StringName(gen.rooms[0].get("room_type")) == &"reception", "Seed %d: Room 0 is reception" % test_seed)
		check(StringName(gen.rooms[1].get("room_type")) == &"main_lobby", "Seed %d: Room 1 is main_lobby" % test_seed)
		check(StringName(gen.rooms[2].get("room_type")) == &"corridor", "Seed %d: Room 2 is corridor" % test_seed)
		check(StringName(gen.rooms[3].get("room_type")) == &"corridor", "Seed %d: Room 3 is corridor" % test_seed)
		check(StringName(gen.rooms[13].get("room_type")) == &"corridor", "Seed %d: Room 13 is corridor" % test_seed)
		check(StringName(gen.rooms[14].get("room_type")) == &"elevator_lobby", "Seed %d: Room 14 is elevator_lobby" % test_seed)

		# 6. Graph Connectivity: Path from Elevator to all other rooms
		for target_id in range(gen.rooms.size()):
			if target_id == gen.elevator_room_id:
				continue
			var target_cell: Vector2i = gen.rooms[target_id].get("center_cell")
			var path = gen.find_floor_path(gen.spawn_cell, target_cell)
			check(not path.is_empty(), "Seed %d: Valid path from spawn to room %d (%s)" % [test_seed, target_id, gen.rooms[target_id].get("name")])

		# 7. Encounter plans and Badge Carrier placement
		gen._build_room_encounter_plans()
		var total_badge_carriers := 0
		var badge_carrier_room_id := -1

		for r in gen.rooms:
			var r_id: int = int(r.get("id"))
			gen._resolve_room_encounter_descriptor(r_id)
			var enc: Dictionary = gen.room_encounters.get(r_id, {})
			var enemy_spawns: Array = enc.get("enemy_spawns", [])
			var planned_count: int = int(enc.get("planned_enemy_count", 0))

			if non_combat_ids.has(r_id):
				check(planned_count == 0, "Seed %d: Room %d has 0 planned enemies" % [test_seed, r_id])
				check(enemy_spawns.is_empty(), "Seed %d: Room %d has 0 enemy spawn descriptors" % [test_seed, r_id])
			else:
				check(planned_count > 0, "Seed %d: Combat room %d has >0 planned enemies (got %d)" % [test_seed, r_id, planned_count])

			for sp in enemy_spawns:
				if bool(sp.get("badge_carrier", false)):
					total_badge_carriers += 1
					badge_carrier_room_id = r_id

		check(total_badge_carriers == 1, "Seed %d: Exactly 1 badge carrier planned (got %d)" % [test_seed, total_badge_carriers])
		check(not non_combat_ids.has(badge_carrier_room_id), "Seed %d: Badge carrier is in combat room %d (NOT in non-combat zones)" % [test_seed, badge_carrier_room_id])

	gen.free()
	print("--- Generator Multi-Seed Verification Complete ---")

	# -------------------------------------------------------------
	# Test Suite 2: Full Scene Runtime Instantiation & Validation
	# -------------------------------------------------------------
	print("--- Instantiating Full Dream3D_RandomDungeon Scene ---")
	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = true
	root.add_child(world)

	for runtime_seed in [42001, 1337]:
		check(world.regenerate(runtime_seed), "Seed %d: Scene regenerate succeeded" % runtime_seed)
		await frames(8)

		# 1. Player Spawn
		check(not world.player_has_left_elevator_cab, "Seed %d: Player starts inside elevator cab" % runtime_seed)
		check(world.elevator_doors_open, "Seed %d: Elevator doors open on floor entry" % runtime_seed)

		# 2. Sliding Door Root
		check(is_instance_valid(world.elevator_sliding_door_root), "Seed %d: Elevator sliding door node exists" % runtime_seed)

		# 3. Runtime Enemies Verification
		var runtime_carriers := 0
		var enemies_in_non_combat := 0
		if world.enemy_root != null:
			for enemy in world.enemy_root.get_children():
				if not is_instance_valid(enemy):
					continue
				var r_id := int(enemy.get_meta(&"dream_room_id", -1))
				if non_combat_ids.has(r_id):
					enemies_in_non_combat += 1
					print("FAIL: Enemy spawned in non-combat room %d: %s" % [r_id, enemy.name])
				if bool(enemy.get_meta(&"employee_badge_carrier", false)):
					runtime_carriers += 1

		check(enemies_in_non_combat == 0, "Seed %d: 0 enemies spawned in non-combat rooms (got %d)" % [runtime_seed, enemies_in_non_combat])
		check(runtime_carriers == 1, "Seed %d: Exactly 1 employee badge carrier spawned in world (got %d)" % [runtime_seed, runtime_carriers])

		# 4. Furniture in Elevator / Corridors vs Reception
		var elev_furniture_count := 0
		var corridor_furniture_count := 0
		var reception_furniture_count := 0

		if world.furniture_root != null:
			for item in world.furniture_root.get_children():
				if not is_instance_valid(item):
					continue
				var r_id := int(item.get_meta(&"dream_room_id", -1))
				if r_id == 14: # Elevator Cab
					elev_furniture_count += 1
				elif r_id == 13 or r_id == 2 or r_id == 3: # Porch and Corridors
					corridor_furniture_count += 1
				elif r_id == 0: # Reception
					reception_furniture_count += 1

		check(elev_furniture_count == 0, "Seed %d: 0 furniture in Elevator Cab (got %d)" % [runtime_seed, elev_furniture_count])
		check(corridor_furniture_count == 0, "Seed %d: 0 furniture in Corridors and Porch (got %d)" % [runtime_seed, corridor_furniture_count])
		print("Seed %d: Reception furniture count: %d" % [runtime_seed, reception_furniture_count])

	world.free()
	await frames(4)

	print("\n==================================================")
	print("TOTAL CHECKS: ", checks)
	print("TOTAL FAILURES: ", failures.size())
	if failures.is_empty():
		print("ALL TESTS PASSED SUCCESSFULLY!")
	else:
		print("FAILED ASSERTIONS:")
		for f in failures:
			print("  - ", f)
	print("==================================================\n")

	quit(0 if failures.is_empty() else 1)
