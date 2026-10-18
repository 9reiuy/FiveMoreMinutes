extends SceneTree

## Comprehensive test suite for OTXO & Hotline Miami Contiguous Mansion Generator.
## Validates:
## 1. Direct generator BSP subdivision, graph connectivity, boss degree invariant == 1, glass windows.
## 2. Dream3DRandomDungeon engine integration and layout validation across 20 seeds.
## 3. BreakableGlassWindow3D damage, shatter signal, and collision removal.
## 4. Backward compatibility with standard macro_corridor generator.

const DUNGEON_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const OTXO_GENERATOR := preload("res://scripts/dream/dream_otxo_mansion_generator.gd")
const GLASS_WINDOW_SCRIPT := preload("res://scripts/dream/breakable_glass_window_3d.gd")
const DEMO_CONFIG_TRES := preload("res://resources/demo_config.tres")


func _init() -> void:
	var failures: Array[String] = []
	var log_lines: Array[String] = []
	log_lines.append("--- Starting OTXO Mansion Generation Test Suite ---")

	_test_otxo_generator_direct(failures)
	log_lines.append("Direct generator test completed. Failures: %d" % failures.size())

	_test_otxo_dungeon_integration(failures)
	log_lines.append("Dungeon integration test completed. Failures: %d" % failures.size())

	_test_otxo_glass_window_behavior(failures)
	log_lines.append("Glass window behavior test completed. Failures: %d" % failures.size())

	_test_backward_compatibility(failures)
	log_lines.append("Backward compatibility test completed. Failures: %d" % failures.size())

	var f := FileAccess.open("res://tests/otxo_test_result.log", FileAccess.WRITE)
	if failures.is_empty():
		log_lines.append("ALL OTXO MANSION TESTS PASSED SUCCESSFULLY!")
		if f != null:
			f.store_string("\n".join(log_lines))
			f.close()
		quit(0)
	else:
		log_lines.append("ERRORS:\n" + "\n".join(failures))
		if f != null:
			f.store_string("\n".join(log_lines))
			f.close()
		push_error("OTXO MANSION TESTS FAILED with %d errors:\n%s" % [failures.size(), "\n".join(failures)])
		quit(1)


func _test_otxo_generator_direct(failures: Array[String]) -> void:
	print("Running test_otxo_generator_direct...")
	var rng := RandomNumberGenerator.new()
	var test_seeds := [12345, 67890, 112233, 445566, 778899, 990011, 42, 1337, 2026, 9999]

	for s in test_seeds:
		rng.seed = s
		var options := {
			"otxo_mansion_room_count": 16,
			"otxo_mansion_glass_chance": 0.40,
			"otxo_mansion_loop_ratio": 0.50,
			"building_width": 64,
			"building_height": 48,
		}
		var result: Dictionary = OTXO_GENERATOR.generate(rng, options)
		if result.is_empty():
			failures.append("Seed %d: generator returned empty dictionary" % s)
			continue

		var rooms: Array = result.get("rooms", [])
		if rooms.size() < 10 or rooms.size() > 20:
			failures.append("Seed %d: room count unexpected: %d" % [s, rooms.size()])

		var spawn_id: int = result.get("spawn_room_id", -1)
		var key_id: int = result.get("key_room_id", -1)
		var boss_id: int = result.get("boss_room_id", -1)
		var boss_door_id: int = result.get("boss_door_id", -1)

		if spawn_id < 0 or key_id < 0 or boss_id < 0:
			failures.append("Seed %d: invalid role ids spawn=%d key=%d boss=%d" % [s, spawn_id, key_id, boss_id])

		if boss_id == spawn_id or boss_id == key_id:
			failures.append("Seed %d: boss room shares id with spawn or key" % s)

		# Check Boss Room Degree == 1 invariant
		var boss_room: Dictionary = rooms[boss_id]
		var boss_conns: Array = boss_room.get("connections", [])
		if boss_conns.size() != 1:
			failures.append("Seed %d: Boss room degree invariant violated! Degree = %d (expected 1)" % [s, boss_conns.size()])

		if boss_door_id < 0:
			failures.append("Seed %d: invalid boss_door_id %d" % [s, boss_door_id])

		# Check graph connectivity
		var visited: Dictionary = {0: true}
		var queue: Array[int] = [0]
		while not queue.is_empty():
			var curr: int = queue.pop_front()
			for nxt in rooms[curr].get("connections", []):
				if not visited.has(nxt):
					visited[nxt] = true
					queue.append(nxt)
		if visited.size() != rooms.size():
			failures.append("Seed %d: graph disconnected! Reached %d of %d rooms" % [s, visited.size(), rooms.size()])

		# Check loop ratio
		var connections: Array = result.get("connections", [])
		if connections.size() <= rooms.size() - 1:
			failures.append("Seed %d: No loops generated! Connections = %d, rooms = %d" % [s, connections.size(), rooms.size()])

		# Check glass windows
		var glass_edges: Dictionary = result.get("glass_wall_edges", {})
		if glass_edges.is_empty():
			failures.append("Seed %d: No glass windows generated" % s)

		# Check that no glass windows connect into boss_room_id
		var room_cells: Dictionary = result.get("room_cells", {})
		for g_key in glass_edges.keys():
			var g_edge: Dictionary = glass_edges[g_key]
			var axis: String = g_edge["axis"]
			var x: int = g_edge["x"]
			var y: int = g_edge["y"]
			var c1 := Vector2i(x - 1, y) if axis == "V" else Vector2i(x, y - 1)
			var c2 := Vector2i(x, y) if axis == "V" else Vector2i(x, y)
			var r1: int = room_cells.get(c1, -1)
			var r2: int = room_cells.get(c2, -1)
			if r1 == boss_id or r2 == boss_id:
				failures.append("Seed %d: Glass window connects directly to boss room %d!" % [s, boss_id])
				break


func _test_otxo_dungeon_integration(failures: Array[String]) -> void:
	print("Running test_otxo_dungeon_integration...")
	var test_seeds := [7001, 7002, 7003, 7004, 7005]

	for s in test_seeds:
		var dungeon := DUNGEON_SCRIPT.new()
		dungeon.generate_on_ready = false
		dungeon.spawn_content = false
		dungeon.config = DEMO_CONFIG_TRES.duplicate()
		dungeon.config.map_generator_type = "otxo_mansion"
		dungeon.config.otxo_mansion_room_count = 14
		dungeon.config.otxo_mansion_glass_chance = 0.35
		dungeon.config.otxo_mansion_loop_ratio = 0.45

		var success: bool = dungeon.generate_layout_only(s)
		var report: Dictionary = dungeon.get_validation_report()
		if not success or not bool(report.get("valid", false)):
			failures.append("Dungeon Integration Seed %d failed validation: %s" % [s, report])
			dungeon.free()
			continue

		if dungeon.boss_room_id < 0 or dungeon.key_room_id < 0 or dungeon.spawn_room_id < 0:
			failures.append("Dungeon Integration Seed %d: role IDs invalid" % s)

		if dungeon._get_room_degree(dungeon.boss_room_id) != 1:
			failures.append("Dungeon Integration Seed %d: Boss room degree = %d != 1" % [s, dungeon._get_room_degree(dungeon.boss_room_id)])

		if dungeon.glass_wall_edges.is_empty():
			failures.append("Dungeon Integration Seed %d: glass_wall_edges empty" % s)

		dungeon.free()


func _test_otxo_glass_window_behavior(failures: Array[String]) -> void:
	print("Running test_otxo_glass_window_behavior...")
	var window := GLASS_WINDOW_SCRIPT.new()
	var collision_root := Node2D.new()

	var edge := {"axis": "H", "x": 5, "y": 10}
	window.configure_window(edge, "H:5:10", 3.0, 0.2, collision_root)

	if window.current_health != 1.0 or window.is_shattered:
		failures.append("GlassWindow initial state invalid: hp=%f shattered=%s" % [window.current_health, window.is_shattered])

	# Hit 1: non-fatal
	window.take_damage(0.4)
	if is_equal_approx(window.current_health, 0.6) == false or window.is_shattered:
		failures.append("GlassWindow non-fatal hit failed: hp=%f shattered=%s" % [window.current_health, window.is_shattered])

	# Hit 2: fatal
	var signal_state := {"shattered": false}
	window.window_shattered.connect(func(_w): signal_state.shattered = true)

	window.take_damage(0.7, Vector2(1, 0))
	if not window.is_shattered or not bool(signal_state.shattered):
		failures.append("GlassWindow shatter failed: shattered=%s signal=%s" % [window.is_shattered, signal_state.shattered])

	if window.collision_body_2d.collision_layer != 0:
		failures.append("GlassWindow collision layer not cleared after shatter: %d" % window.collision_body_2d.collision_layer)

	window.free()
	collision_root.free()


func _test_backward_compatibility(failures: Array[String]) -> void:
	print("Running test_backward_compatibility...")
	var test_seeds := [8001, 8002, 8003]

	for s in test_seeds:
		var dungeon := DUNGEON_SCRIPT.new()
		dungeon.generate_on_ready = false
		dungeon.spawn_content = false
		dungeon.config = DEMO_CONFIG_TRES.duplicate()
		dungeon.config.map_generator_type = "macro_corridor"

		var success: bool = dungeon.generate_layout_only(s)
		var report: Dictionary = dungeon.get_validation_report()
		if not success or not bool(report.get("valid", false)):
			failures.append("Backward Compat Seed %d failed: %s" % [s, report])

		dungeon.free()
