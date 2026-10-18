extends SceneTree

## High-volume validator for the macro Room Graph contract.  This test is data
## only: it never builds meshes or starts the runtime scene, so failures point
## directly at topology generation rather than rendering order.

const GENERATOR_SCRIPT := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const FIRST_SEED := 51001
const SEED_COUNT := 1000


func _init() -> void:
	var failures: Array[String] = []
	var shape_counts: Dictionary = {}
	var corridor_axis_counts := {"horizontal": 0, "vertical": 0, "l_turn": 0}
	var min_room_count := 999999
	var max_room_count := 0
	var min_floor_count := 999999
	var max_floor_count := 0
	var total_loops := 0

	for index in range(SEED_COUNT):
		var test_seed := FIRST_SEED + index
		var generator := GENERATOR_SCRIPT.new()
		generator.generate_on_ready = false
		generator.spawn_content = false
		generator.room_count = 12
		var generated: bool = generator.generate_layout_only(test_seed)
		var report: Dictionary = generator.get_validation_report()
		if not generated or not bool(report.get("valid", false)):
			failures.append("seed %d did not generate a valid layout: %s" % [test_seed, report])
			generator.free()
			continue
		min_room_count = mini(min_room_count, generator.rooms.size())
		max_room_count = maxi(max_room_count, generator.rooms.size())
		min_floor_count = mini(min_floor_count, generator.floor_cells.size())
		max_floor_count = maxi(max_floor_count, generator.floor_cells.size())
		total_loops += int(report.get("loop_count", -1))
		if generator.rooms.size() != 12:
			failures.append("seed %d room count=%d" % [test_seed, generator.rooms.size()])
		_validate_rooms(generator, test_seed, failures, shape_counts)
		_validate_corridors(generator, test_seed, failures, corridor_axis_counts)
		_validate_connections(generator, test_seed, failures)
		if int(report.get("boss_entry_count", 0)) != 1 or not bool(report.get("boss_single_entry", false)):
			failures.append("seed %d Boss is not a single-entry leaf: %s" % [test_seed, report])
		if generator.find_floor_path(generator.spawn_cell, generator.rooms[generator.boss_room_id]["center_cell"], false).size() != 0:
			failures.append("seed %d Boss path bypasses the lock" % test_seed)
		var first_signature: String = generator.get_layout_signature()
		var repeated: bool = generator.generate_layout_only(test_seed)
		if not repeated or first_signature != generator.get_layout_signature():
			failures.append("seed %d is not deterministic" % test_seed)
		generator.free()

	if min_room_count == 999999:
		min_room_count = 0
	if min_floor_count == 999999:
		min_floor_count = 0
	for shape_name in ["square", "rectangle", "irregular", "stepped", "hollow"]:
		if int(shape_counts.get(shape_name, 0)) <= 0:
			failures.append("enabled room shape never appeared: %s" % shape_name)
	if int(corridor_axis_counts.get("horizontal", 0)) <= 0:
		failures.append("no horizontal corridor observed")
	if int(corridor_axis_counts.get("vertical", 0)) <= 0:
		failures.append("no vertical corridor observed")
	if int(corridor_axis_counts.get("l_turn", 0)) <= 0:
		failures.append("no L-turn corridor observed")

	print("MACRO GRAPH seeds=%d rooms=%d..%d floor=%d..%d loops_avg=%.2f shapes=%s corridors=%s" % [
		SEED_COUNT,
		min_room_count,
		max_room_count,
		min_floor_count,
		max_floor_count,
		float(total_loops) / float(SEED_COUNT),
		shape_counts,
		corridor_axis_counts,
	])
	if not failures.is_empty():
		for failure in failures.slice(0, 40):
			push_error(failure)
		print("MACRO GRAPH FAILURES=%d (showing up to 40)" % failures.size())
		quit(1)
		return
	print("PASS: validated %d macro Room Graph seeds." % SEED_COUNT)
	quit(0)


func _validate_rooms(generator: Node, test_seed: int, failures: Array[String], shape_counts: Dictionary) -> void:
	var occupied: Dictionary = {}
	for room_variant in generator.rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		var shape_name := String(room.get("shape", ""))
		shape_counts[shape_name] = int(shape_counts.get(shape_name, 0)) + 1
		var shape_cells: Array = room.get("shape_cells", [])
		if shape_cells.is_empty() or not generator.room_cells.has(room.get("center_cell", Vector2i.ZERO)):
			failures.append("seed %d room %d has no valid shape/center" % [test_seed, room_id])
		for cell_variant in shape_cells:
			var cell: Vector2i = cell_variant
			if occupied.has(cell):
				failures.append("seed %d rooms overlap at %s" % [test_seed, cell])
			occupied[cell] = room_id
			if int(generator.room_cells.get(cell, -1)) != room_id or not generator.floor_cells.has(cell):
				failures.append("seed %d room %d cell map mismatch at %s" % [test_seed, room_id, cell])
		for cell_variant in room.get("usable_cells", []):
			var usable_cell: Vector2i = cell_variant
			if int(generator.room_cells.get(usable_cell, -1)) != room_id:
				failures.append("seed %d room %d usable cell outside room at %s" % [test_seed, room_id, usable_cell])


func _validate_corridors(generator: Node, test_seed: int, failures: Array[String], axis_counts: Dictionary) -> void:
	var corridor_occupancy: Dictionary = {}
	for corridor_variant in generator.corridors:
		var corridor: Dictionary = corridor_variant
		var corridor_id := int(corridor.get("id", -1))
		var cells: Array = corridor.get("cells", [])
		if cells.is_empty():
			failures.append("seed %d corridor %d is empty" % [test_seed, corridor_id])
		for cell_variant in cells:
			var cell: Vector2i = cell_variant
			if corridor_occupancy.has(cell):
				failures.append("seed %d corridors overlap at %s" % [test_seed, cell])
			corridor_occupancy[cell] = corridor_id
			if generator.room_cells.has(cell) or int(generator.corridor_cells.get(cell, -1)) != corridor_id or not generator.floor_cells.has(cell):
				failures.append("seed %d corridor %d cell map mismatch at %s" % [test_seed, corridor_id, cell])
		var kind := String(corridor.get("kind", "straight"))
		if kind == "l":
			axis_counts["l_turn"] = int(axis_counts.get("l_turn", 0)) + 1
		else:
			var macro_a: Vector2i = corridor.get("macro_a", Vector2i.ZERO)
			var macro_b: Vector2i = corridor.get("macro_b", Vector2i.ZERO)
			if macro_a.y == macro_b.y:
				axis_counts["horizontal"] = int(axis_counts.get("horizontal", 0)) + 1
			elif macro_a.x == macro_b.x:
				axis_counts["vertical"] = int(axis_counts.get("vertical", 0)) + 1
	for cell_variant in generator.corridor_cells.keys():
		var cell: Vector2i = cell_variant
		if not generator.floor_cells.has(cell):
			failures.append("seed %d corridor map contains non-floor cell %s" % [test_seed, cell])


func _validate_connections(generator: Node, test_seed: int, failures: Array[String]) -> void:
	var door_ids: Dictionary = {}
	for connection_variant in generator.connections:
		var connection: Dictionary = connection_variant
		if int(connection.get("door_count", 0)) != 1:
			failures.append("seed %d connection %d has door_count=%s" % [test_seed, connection.get("id", -1), connection.get("door_count", -1)])
		var door_id := int(connection.get("door_id", -1))
		if door_id < 0 or door_ids.has(door_id):
			failures.append("seed %d duplicate/invalid door id=%d" % [test_seed, door_id])
		door_ids[door_id] = true
		var a := int(connection.get("a", -1))
		var b := int(connection.get("b", -1))
		var corridor_id := int(connection.get("corridor_id", -1))
		if a < 0 or b < 0 or a == b or corridor_id < 0 or corridor_id >= generator.corridors.size():
			failures.append("seed %d invalid connection %d endpoints" % [test_seed, int(connection.get("id", -1))])
		for side_key in ["door_a", "door_b"]:
			var side: Dictionary = connection.get(side_key, {})
			if not generator.floor_cells.has(side.get("inside_cell", Vector2i.ZERO)):
				failures.append("seed %d connection %d missing %s floor side" % [test_seed, int(connection.get("id", -1)), side_key])
	if door_ids.size() != generator.connections.size():
		failures.append("seed %d connection/door cardinality mismatch" % test_seed)
