extends SceneTree

# The five-shape pack is the formal generator; the sample has its own scene.
const GENERATOR = preload("res://scripts/dream/office_level_pack_generator.gd")
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _connected_rooms(layout: Dictionary) -> int:
	var reached := {int(layout.elevator_room_id): true}
	var frontier: Array[int] = [int(layout.elevator_room_id)]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for connection in layout.connections:
			var a := int(connection.get("a", -1))
			var b := int(connection.get("b", -1))
			var neighbor := b if a == current else (a if b == current else -1)
			if neighbor >= 0 and not reached.has(neighbor):
				reached[neighbor] = true
				frontier.append(neighbor)
	return reached.size()

func run() -> void:
	for shape in GENERATOR.SHAPES:
		for seed in range(120, 140):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var layout: Dictionary = GENERATOR.generate_shape(rng, shape)
			verify(not layout.is_empty(), "%s seed %d generated" % [shape, seed])
			if layout.is_empty():
				continue
			var repeated_rng := RandomNumberGenerator.new()
			repeated_rng.seed = seed
			var repeated: Dictionary = GENERATOR.generate_shape(repeated_rng, shape)
			verify(repeated.get("floor_cells", {}) == layout.floor_cells and repeated.get("door_edges", {}) == layout.door_edges and repeated.get("glass_wall_edges", {}) == layout.glass_wall_edges, "%s seed %d deterministic geometry" % [shape, seed])
			var rooms: Array = layout.rooms
			verify(rooms.size() >= 9 and rooms.size() <= 13, "%s room count %d" % [shape, rooms.size()])
			for required in ["open_office", "conference_large", "pantry", "restroom", "reception"]:
				verify(rooms.any(func(room: Dictionary): return room.archetype == required), "%s has %s" % [shape, required])
			verify(int(layout.glass_group_count) >= 2, "%s has two glass groups" % shape)
			verify(int(layout.boss_room_id) == -1, "%s has no boss" % shape)
			verify(layout.floor_cells.has(layout.spawn_cell), "%s valid spawn" % shape)
			verify(_connected_rooms(layout) == rooms.size(), "%s all rooms connect to lift" % shape)
	var shape_seeds: Dictionary = {}
	for seed in range(1, 300):
		var pick_rng := RandomNumberGenerator.new()
		pick_rng.seed = seed
		var pick: Dictionary = GENERATOR.generate(pick_rng)
		if not pick.is_empty() and not shape_seeds.has(pick.floor_shape):
			shape_seeds[pick.floor_shape] = seed
	for shape in GENERATOR.SHAPES:
		verify(shape_seeds.has(shape), "optional generator can select %s" % shape)
	var world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	verify(not bool(world.use_authored_office_sample), "normal entry defaults to random office")
	verify(world.regenerate(120), "normal entry generates random seed 120")
	verify(GENERATOR.SHAPES.has(world.floor_shape), "production selects one of the five silhouettes")
	verify(world.elevator_floor_door != null and world.elevator_approach_trigger != null, "random elevator is present")
	verify(world.badge_carrier_room_id >= 0, "random floor has a badge carrier")
	world.queue_free()
	await process_frame
	print("OFFICE FORMAL PACK checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
