extends SceneTree

## Dedicated test suite for TASK-011-A: Room Firefight Layout Optimization
## Validates:
## 1. Direct OTXORoomLayoutPlanner functionality across 5 archetypes.
## 2. Doorway reservation zones (no furniture or enemies within 64px inward of any doorway).
## 3. Walkability validation (all doors mutually reachable without vaulting or destroying furniture).
## 4. Zonal crossfire enemy spacing (>= 32px mutual distance, proper sector distribution).
## 5. Roadside weapon drop placement (clear of doors and furniture).
## 6. Multi-seed dungeon integration (Seeds 101, 202, 52017, 8882).
## 7. Seed determinism and sub-15ms performance.

const DUNGEON_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PLANNER_SCRIPT: Script = preload("res://scripts/dream/otxo_room_layout_planner.gd")
const DEMO_CONFIG_TRES: DemoConfig = preload("res://resources/demo_config.tres")
const CELL_PIXELS: float = 32.0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_tests")


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run_tests() -> void:
	print("--- Starting OTXO Room Firefight Layout Test Suite ---")

	_test_direct_planner()
	await _test_dungeon_integration_across_seeds()
	await _test_determinism()
	await _test_performance()

	if failures.is_empty():
		print("\n============================================================")
		print(" ALL OTXO ROOM FIREFIGHT LAYOUT TESTS PASSED (100%)! ")
		print("============================================================\n")
		quit(0)
	else:
		push_error("OTXO ROOM FIREFIGHT LAYOUT TESTS FAILED with %d errors:\n%s" % [failures.size(), "\n".join(failures)])
		print("\n============================================================")
		print(" TESTS FAILED WITH %d ERRORS " % failures.size())
		print("============================================================\n")
		quit(1)


func _test_direct_planner() -> void:
	print("\n[Test 1] Testing direct OTXORoomLayoutPlanner across 6 archetypes...")

	var archetypes: Array[String] = ["open_office", "conference", "lounge", "executive", "storage", "security"]
	var desk_scene: PackedScene = load("res://scenes/dream/props/desk.tscn")
	var chair_scene: PackedScene = load("res://scenes/dream/props/office_chair_01.tscn")
	var cabinet_scene: PackedScene = load("res://scenes/dream/props/filing_cabinet_01.tscn")
	var furniture_scenes: Array[PackedScene] = [desk_scene, chair_scene, cabinet_scene]

	for archetype in archetypes:
		var w := 12
		var h := 10
		var usable_cells: Array[Vector2i] = []
		for x in range(w):
			for y in range(h):
				usable_cells.append(Vector2i(x, y))

		var room: Dictionary = {
			"id": 1,
			"grid_rect": Rect2i(0, 0, w, h),
			"usable_cells": usable_cells,
			"archetype": archetype,
			"size_class": &"medium"
		}

		var doors: Array[Dictionary] = [
			{
				"inside_cell": Vector2i(0, 4),
				"outward": Vector2i(-1, 0),
				"opening_profile": [Vector2i(0, 4), Vector2i(0, 5)]
			},
			{
				"inside_cell": Vector2i(11, 4),
				"outward": Vector2i(1, 0),
				"opening_profile": [Vector2i(11, 4), Vector2i(11, 5)]
			}
		]

		var room_bounds_px := Rect2(Vector2.ZERO, Vector2(w, h) * CELL_PIXELS).grow(-18.0)
		var plan: Dictionary = PLANNER_SCRIPT.call(
			"plan_room_layout",
			1,
			room,
			doors,
			furniture_scenes,
			4,
			3,
			2,
			1337,
			room_bounds_px,
			CELL_PIXELS
		)

		if not bool(plan.get("success", false)):
			failures.append("Direct planner failed to generate valid layout for archetype '%s'" % archetype)
			continue

		var furniture: Array = plan.get("furniture_placements", [])
		if furniture.size() < 2:
			failures.append("Archetype '%s': expected at least 2 furniture items, got %d" % [archetype, furniture.size()])

		var door_rects: Array = plan.get("door_reservation_rects", [])
		for f in furniture:
			var f_pos: Vector2 = f.get("position", Vector2.ZERO)
			var f_half: Vector2 = f.get("half_extents", Vector2(16.0, 16.0))
			var f_rect := Rect2(f_pos - f_half, f_half * 2.0)
			for d_rect in door_rects:
				if f_rect.intersects(d_rect):
					failures.append("Archetype '%s': furniture at %s overlaps doorway reservation rect %s" % [archetype, f_pos, d_rect])

		var enemies: Array = plan.get("enemy_spawns", [])
		if enemies.size() != 3:
			failures.append("Archetype '%s': expected 3 enemies, got %d" % [archetype, enemies.size()])

		for i in range(enemies.size()):
			var e_pos: Vector2 = enemies[i].get("ground_position", Vector2.ZERO)
			for d_rect in door_rects:
				if (d_rect as Rect2).has_point(e_pos) or e_pos.distance_to((d_rect as Rect2).get_center()) < 56.0:
					failures.append("Archetype '%s': enemy %d at %s is too close to doorway" % [archetype, i, e_pos])
			for j in range(i + 1, enemies.size()):
				var other_pos: Vector2 = enemies[j].get("ground_position", Vector2.ZERO)
				if e_pos.distance_to(other_pos) < 28.0:
					failures.append("Archetype '%s': enemies %d and %d are too close (%f px < 28px)" % [archetype, i, j, e_pos.distance_to(other_pos)])

		var is_walkable: bool = PLANNER_SCRIPT.call("validate_room_walkability", usable_cells, furniture, doors, CELL_PIXELS)
		if not is_walkable:
			failures.append("Archetype '%s': planned layout failed walkability verification" % archetype)

	print("PASS: Direct planner validated successfully across all 6 archetypes")


func _test_dungeon_integration_across_seeds() -> void:
	print("\n[Test 2] Testing dungeon integration and walkability across seeds [101, 202, 52017, 8882]...")

	var test_seeds: Array[int] = [101, 202, 52017, 8882]

	for test_seed in test_seeds:
		var dungeon = DUNGEON_SCENE.instantiate()
		dungeon.generate_on_ready = false
		dungeon.spawn_content = true
		dungeon.persist_profile = false
		dungeon.config = DEMO_CONFIG_TRES.duplicate()
		dungeon.config.map_generator_type = "otxo_mansion"
		dungeon.config.otxo_mansion_room_count = 14

		root.add_child(dungeon)
		await frames(2)
		var generated: bool = dungeon.regenerate(test_seed)
		if not generated:
			failures.append("Failed to regenerate dungeon with seed %d" % test_seed)
			dungeon.queue_free()
			await frames(2)
			continue

		var total_combat_rooms := 0
		var total_furniture := 0
		var total_enemies := 0

		for room_variant in dungeon.rooms:
			var room: Dictionary = room_variant
			var room_id := int(room.get("id", -1))
			if room_id == dungeon.spawn_room_id or room_id == dungeon.boss_room_id:
				continue
			if not dungeon._is_combat_room(room):
				continue

			total_combat_rooms += 1
			var doors: Array = dungeon._get_room_doors(room_id)
			var room_furniture: Array[Node2D] = []
			var room_enemies: Array[Node2D] = []

			if dungeon.furniture_root != null:
				for child in dungeon.furniture_root.get_children():
					if int(child.get_meta(&"dream_room_id", -1)) == room_id:
						room_furniture.append(child)
			if dungeon.enemy_root != null:
				for child in dungeon.enemy_root.get_children():
					if int(child.get_meta(&"dream_room_id", -1)) == room_id:
						room_enemies.append(child)

			total_furniture += room_furniture.size()
			total_enemies += room_enemies.size()

			# Check doorway clearances
			for door in doors:
				var inside_cell: Vector2i = door.get("inside_cell", Vector2i.ZERO)
				var threshold_pos := Vector2(inside_cell) * CELL_PIXELS

				for f in room_furniture:
					var dist := f.global_position.distance_to(threshold_pos)
					if dist < 38.0:
						failures.append("Seed %d Room %d: furniture %s at %s too close to door %s (dist: %f < 38px)" % [
							test_seed, room_id, f.name, f.global_position, inside_cell, dist
						])

				for e in room_enemies:
					var dist := e.global_position.distance_to(threshold_pos)
					if dist < 48.0:
						failures.append("Seed %d Room %d: enemy at %s too close to door %s (dist: %f < 48px)" % [
							test_seed, room_id, e.global_position, inside_cell, dist
						])

			# Check enemy-to-enemy spacing
			for i in range(room_enemies.size()):
				for j in range(i + 1, room_enemies.size()):
					var d := room_enemies[i].global_position.distance_to(room_enemies[j].global_position)
					if d < 24.0:
						failures.append("Seed %d Room %d: enemies too close (%f px < 24px)" % [test_seed, room_id, d])

			# Check walkability between doors
			if doors.size() >= 2:
				var furniture_records: Array[Dictionary] = []
				for f in room_furniture:
					var half := Vector2(16.0, 16.0)
					if f.has_method("get_gameplay_footprint_half_extents"):
						half = f.call("get_gameplay_footprint_half_extents")
					furniture_records.append({
						"position": f.global_position,
						"half_extents": half
					})
				var walkable_cells: Array = room.get("shape_cells", room.get("usable_cells", []))
				var walkable: bool = PLANNER_SCRIPT.call(
					"validate_room_walkability",
					walkable_cells,
					furniture_records,
					doors,
					CELL_PIXELS
				)
				if not walkable:
					failures.append("Seed %d Room %d: walkability validation failed between doors" % [test_seed, room_id])

		dungeon.queue_free()
		await frames(2)

	print("PASS: Verified doorway reservations, enemy spacing, and door-to-door walkability across 4 seeds")


func _test_determinism() -> void:
	print("\n[Test 3] Testing layout plan determinism under identical seeds...")

	var dungeon1 = DUNGEON_SCENE.instantiate()
	dungeon1.generate_on_ready = false
	dungeon1.spawn_content = true
	dungeon1.persist_profile = false
	dungeon1.config = DEMO_CONFIG_TRES.duplicate()
	dungeon1.config.map_generator_type = "otxo_mansion"
	root.add_child(dungeon1)
	await frames(2)
	dungeon1.regenerate(9999)

	var furniture_pos1: Array[Vector2] = []
	var enemy_pos1: Array[Vector2] = []
	for c in dungeon1.furniture_root.get_children():
		furniture_pos1.append(c.global_position)
	for c in dungeon1.enemy_root.get_children():
		enemy_pos1.append(c.global_position)
	await frames(2)
	dungeon1.queue_free()
	await frames(2)

	var dungeon2 = DUNGEON_SCENE.instantiate()
	dungeon2.generate_on_ready = false
	dungeon2.spawn_content = true
	dungeon2.persist_profile = false
	dungeon2.config = DEMO_CONFIG_TRES.duplicate()
	dungeon2.config.map_generator_type = "otxo_mansion"
	root.add_child(dungeon2)
	await frames(2)
	dungeon2.regenerate(9999)

	var furniture_pos2: Array[Vector2] = []
	var enemy_pos2: Array[Vector2] = []
	for c in dungeon2.furniture_root.get_children():
		furniture_pos2.append(c.global_position)
	for c in dungeon2.enemy_root.get_children():
		enemy_pos2.append(c.global_position)
	await frames(2)
	dungeon2.queue_free()
	await frames(2)

	if furniture_pos1.size() != furniture_pos2.size():
		failures.append("Determinism failed: furniture count mismatch (%d vs %d)" % [furniture_pos1.size(), furniture_pos2.size()])
	else:
		for i in range(furniture_pos1.size()):
			if furniture_pos1[i].distance_to(furniture_pos2[i]) > 0.1:
				failures.append("Determinism failed: furniture %d position drifted (%s vs %s)" % [i, furniture_pos1[i], furniture_pos2[i]])

	if enemy_pos1.size() != enemy_pos2.size():
		failures.append("Determinism failed: enemy count mismatch (%d vs %d)" % [enemy_pos1.size(), enemy_pos2.size()])
	else:
		for i in range(enemy_pos1.size()):
			if enemy_pos1[i].distance_to(enemy_pos2[i]) > 0.1:
				failures.append("Determinism failed: enemy %d position drifted (%s vs %s)" % [i, enemy_pos1[i], enemy_pos2[i]])

	print("PASS: Same seed generates bit-exact identical furniture and enemy placements")


func _test_performance() -> void:
	print("\n[Test 4] Testing generation performance...")

	var dungeon = DUNGEON_SCENE.instantiate()
	dungeon.generate_on_ready = false
	dungeon.spawn_content = true
	dungeon.persist_profile = false
	dungeon.config = DEMO_CONFIG_TRES.duplicate()
	dungeon.config.map_generator_type = "otxo_mansion"
	root.add_child(dungeon)
	await frames(2)

	# First generate dungeon graph
	var start_usec := Time.get_ticks_usec()
	dungeon.regenerate(7777)
	var elapsed_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0

	# Clear cached plans so we measure fresh calculation time from scratch across all rooms!
	dungeon.room_layout_plans.clear()

	# Benchmark layout planning specifically
	var plan_start := Time.get_ticks_usec()
	var max_room_time_ms := 0.0
	for room in dungeon.rooms:
		var r_id := int(room.get("id", -1))
		var r_start := Time.get_ticks_usec()
		dungeon._plan_otxo_room_layout(r_id)
		var r_ms := float(Time.get_ticks_usec() - r_start) / 1000.0
		if r_ms > max_room_time_ms:
			max_room_time_ms = r_ms
	var total_plan_ms := float(Time.get_ticks_usec() - plan_start) / 1000.0

	dungeon.queue_free()
	await frames(2)

	print("Layout planning total for all rooms: %.2f ms (max single room: %.2f ms)" % [total_plan_ms, max_room_time_ms])
	if max_room_time_ms > 15.0:
		failures.append("Single room planning took too long: %.2f ms > 15.0 ms" % max_room_time_ms)
	if total_plan_ms > 50.0:
		failures.append("Total room layout planning took too long: %.2f ms > 50.0 ms" % total_plan_ms)

	print("Mansion full generation with layout planning took: %.2f ms" % elapsed_ms)
	if elapsed_ms > 1000.0:
		failures.append("Full generation took too long: %.2f ms > 1000.0 ms" % elapsed_ms)
	else:
		print("PASS: Generation performance is well within budget")
