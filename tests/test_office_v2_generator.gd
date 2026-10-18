extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const GENERATOR = preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const OFFICE_V2 = preload("res://scripts/dream/dream_office_v2_generator.gd")

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
	print("=== STARTING TASK-017 LEVEL PACK V2 GENERATOR TEST ===")

	var contours: Array[StringName] = [&"rect", &"l_shape", &"t_shape", &"cross", &"convex"]
	var gen: Node = GENERATOR.new()

	# -------------------------------------------------------------
	# Test Suite 1: Test All 5 Contours Across Multiple Seeds
	# -------------------------------------------------------------
	for contour in contours:
		print("\n--- Testing Contour: %s ---" % contour)
		for seed_val in [42001, 1337, 7777, 99999]:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_val
			var data: Dictionary = OFFICE_V2.generate(rng, {"contour_type": String(contour), "floor_index": 1})
			check(not data.is_empty(), "Contour %s (seed %d): Generated non-empty layout" % [contour, seed_val])
			if data.is_empty():
				continue

			var rooms: Array = data.get("rooms", [])
			var room_count := rooms.size()
			check(room_count >= 9 and room_count <= 13, "Contour %s (seed %d): Room count in [9, 13] (got %d)" % [contour, seed_val, room_count])

			# Check required rooms: Elevator, Open Office, Boardroom, Pantry, Restroom
			var has_elevator := false
			var has_open_office := false
			var has_boardroom := false
			var has_pantry := false
			var has_restroom := false

			for r in rooms:
				var r_name := String(r.get("name", ""))
				var r_type := StringName(r.get("room_type", &""))
				var arch := String(r.get("archetype", ""))

				if r_type == &"elevator_lobby":
					has_elevator = true
				if arch == "open_office":
					has_open_office = true
				if arch == "conference" and r.get("size_class") == &"large":
					has_boardroom = true
				if r_name.contains("Pantry") or arch == "lounge":
					has_pantry = true
				if r_name.contains("Restroom") or (arch == "storage" and r.get("size_class") == &"small"):
					has_restroom = true

			check(has_elevator, "Contour %s (seed %d): Elevator Hall exists" % [contour, seed_val])
			check(has_open_office, "Contour %s (seed %d): Open Office exists" % [contour, seed_val])
			check(has_boardroom, "Contour %s (seed %d): Boardroom exists" % [contour, seed_val])
			check(has_pantry, "Contour %s (seed %d): Pantry exists" % [contour, seed_val])
			check(has_restroom, "Contour %s (seed %d): Restroom exists" % [contour, seed_val])

			# Check glass spans >= 2
			var glass_edges: Dictionary = data.get("glass_wall_edges", {})
			check(glass_edges.size() >= 2, "Contour %s (seed %d): Breakable glass edges >= 2 (got %d)" % [contour, seed_val, glass_edges.size()])

			# Check Elevator sliding door
			var has_sliding_door := false
			for d_edge in data.get("door_edges", {}).values():
				if bool(d_edge.get("is_elevator_sliding_door", false)):
					has_sliding_door = true
					break
			check(has_sliding_door, "Contour %s (seed %d): Elevator sliding door exists" % [contour, seed_val])

	# -------------------------------------------------------------
	# Test Suite 2: Full Dream3D_RandomDungeon Integration
	# -------------------------------------------------------------
	print("\n--- Testing Dream3D_RandomDungeon Integration ---")
	for test_seed in [42001, 1337, 7777]:
		var ok: bool = gen.generate_layout_only(test_seed)
		check(ok, "Seed %d: generate_layout_only succeeded" % test_seed)
		if not ok:
			continue

		# Connectivity: Path from Elevator spawn cell to all other rooms
		for target_id in range(gen.rooms.size()):
			if target_id == gen.elevator_room_id:
				continue
			var target_cell: Vector2i = gen.rooms[target_id].get("center_cell")
			var path: Array = gen.find_floor_path(gen.spawn_cell, target_cell)
			check(not path.is_empty(), "Seed %d: Valid path from spawn to room %d (%s)" % [test_seed, target_id, gen.rooms[target_id].get("name")])

		# Encounter plans & Badge Carrier
		gen._build_room_encounter_plans()
		var total_badge_carriers := 0
		var badge_carrier_room_id := -1

		for r in gen.rooms:
			var r_id: int = int(r.get("id"))
			gen._resolve_room_encounter_descriptor(r_id)
			var enc: Dictionary = gen.room_encounters.get(r_id, {})
			var enemy_spawns: Array = enc.get("enemy_spawns", [])
			var planned_count: int = int(enc.get("planned_enemy_count", 0))

			var is_safe_zone: bool = (r_id == gen.elevator_room_id or r_id == gen.corridor_room_id or StringName(r.get("room_type")) in [&"reception", &"corridor", &"elevator_lobby", &"main_lobby"])
			if is_safe_zone:
				check(planned_count == 0, "Seed %d: Safe zone room %d (%s) has 0 planned enemies" % [test_seed, r_id, r.get("name")])
				check(enemy_spawns.is_empty(), "Seed %d: Safe zone room %d has 0 enemy spawn descriptors" % [test_seed, r_id])
			else:
				check(planned_count > 0, "Seed %d: Combat room %d (%s) has >0 planned enemies (got %d)" % [test_seed, r_id, r.get("name"), planned_count])

			for sp in enemy_spawns:
				if bool(sp.get("badge_carrier", false)):
					total_badge_carriers += 1
					badge_carrier_room_id = r_id

		check(total_badge_carriers == 1, "Seed %d: Exactly 1 badge carrier planned (got %d)" % [test_seed, total_badge_carriers])
		check(badge_carrier_room_id != gen.elevator_room_id and badge_carrier_room_id != gen.corridor_room_id, "Seed %d: Badge carrier is in combat room %d" % [test_seed, badge_carrier_room_id])

	gen.free()

	# -------------------------------------------------------------
	# Test Suite 3: Runtime Scene Instantiation & Validation
	# -------------------------------------------------------------
	print("\n--- Testing Runtime Scene Instantiation ---")
	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = true
	root.add_child(world)

	for runtime_seed in [42001, 1337]:
		check(world.regenerate(runtime_seed), "Runtime Seed %d: Scene regenerate succeeded" % runtime_seed)
		await frames(8)

		check(not world.player_has_left_elevator_cab, "Runtime Seed %d: Player starts inside elevator cab" % runtime_seed)
		check(world.elevator_doors_open, "Runtime Seed %d: Elevator doors open on floor entry" % runtime_seed)
		check(is_instance_valid(world.elevator_sliding_door_root), "Runtime Seed %d: Elevator sliding door node exists" % runtime_seed)

		# Runtime enemy verification
		var runtime_carriers := 0
		var enemies_in_elevator := 0
		if world.enemy_root != null:
			for enemy in world.enemy_root.get_children():
				if not is_instance_valid(enemy):
					continue
				var r_id := int(enemy.get_meta(&"dream_room_id", -1))
				if r_id == world.elevator_room_id:
					enemies_in_elevator += 1
				if bool(enemy.get_meta(&"employee_badge_carrier", false)):
					runtime_carriers += 1

		check(enemies_in_elevator == 0, "Runtime Seed %d: 0 enemies spawned in elevator room (got %d)" % [runtime_seed, enemies_in_elevator])
		check(runtime_carriers == 1, "Runtime Seed %d: Exactly 1 badge carrier spawned in world (got %d)" % [runtime_seed, runtime_carriers])

	world.free()
	await frames(4)

	print("\n==================================================")
	print("TOTAL CHECKS: ", checks)
	print("TOTAL FAILURES: ", failures.size())
	if failures.is_empty():
		print("ALL TASK-017 TESTS PASSED SUCCESSFULLY!")
	else:
		print("FAILED ASSERTIONS:")
		for f in failures:
			print("  - ", f)
	print("==================================================\n")

	quit(0 if failures.is_empty() else 1)
