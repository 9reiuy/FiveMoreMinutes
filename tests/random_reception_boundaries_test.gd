extends SceneTree

const GENERATOR = preload("res://scripts/dream/office_level_pack_generator.gd")
const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")
const LEGACY = preload("res://scripts/dream/dream_otxo_mansion_generator.gd")
const SAMPLE = preload("res://scripts/dream/office_sample_floor.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for shape in GENERATOR.SHAPES:
		for seed in range(120, 130):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var layout: Dictionary = GENERATOR.generate_shape(rng, shape)
			check(not layout.is_empty(), "generation " + String(shape))
			if layout.is_empty():
				continue
			var room: Dictionary = layout.rooms[layout.elevator_room_id]
			check(room.archetype == "reception" and room.room_type == &"elevator_lobby" and not room.combat_room, "entry identity and safety")
			check(not room.authored_sample, "random identity is not sample")
			var facade: Dictionary = room.elevator_facade_edge
			check(facade.elevator_cab_inward == Vector2.DOWN, "cab stays outside reception, exit north")
			check(int(facade.y) == room.grid_rect.end.y, "facade flush with south wall")
			for x in range(int(facade.x), int(facade.x) + 3):
				var key: String = LEGACY._edge_key({"axis": "H", "x": x, "y": facade.y})
				check(not layout.wall_edges.has(key) and layout.door_opening_edges.has(key), "real facade opening")
			var doors: Array = []
			for connection in layout.connections:
				if connection.a == room.id:
					doors.append(connection.door_a)
				elif connection.b == room.id:
					doors.append(connection.door_b)
				if connection.a == room.id or connection.b == room.id:
					check(not connection.is_elevator_sliding_door, "corridor access remains normal door")
			var rect: Rect2i = room.grid_rect
			var bounds := Rect2((Vector2(rect.position) - Vector2.ONE * .5) * 32, Vector2(rect.size) * 32).grow(-18)
			var plan: Dictionary = PLANNER.plan_room_layout(room.id, room, doors, [], 6, 0, 0, seed, bounds)
			check(plan.success, "reception furniture fits")
			check(plan.enemy_spawns.is_empty(), "safe reception has no enemies")
			check(PLANNER._office_entry_lane_clear(bounds, plan.furniture_placements, 32), "3-cell central route and front desk faces arrival")
			var kinds: Array = plan.furniture_placements.map(func(item: Dictionary): return item.office_kind)
			check(kinds.has("reception") and kinds.has("chair") and kinds.has("sofa") and kinds.has("coffee_table"), "core reception ensemble")
			var repeated: Dictionary = PLANNER.plan_room_layout(room.id, room, doors, [], 6, 0, 0, seed, bounds)
			check(repeated == plan, "reception deterministic")
			for boundary in LEGACY._find_shared_boundaries(layout.rooms):
				var a: Dictionary = layout.rooms[boundary.room_a]
				var b: Dictionary = layout.rooms[boundary.room_b]
				if a.archetype != "open_office" and b.archetype != "open_office":
					continue
				var open := GENERATOR._office_corridor_boundary(a, b)
				for slot in range(int(boundary.span_start), int(boundary.span_end)):
					var key: String = LEGACY._edge_key({"axis": boundary.axis, "x": int(boundary.cut) if boundary.axis == "V" else slot, "y": slot if boundary.axis == "V" else int(boundary.cut)})
					check((layout.edge_states.get(key) == &"OPEN") == open, "office opens only to corridor")
					if not open and not layout.door_opening_edges.has(key) and not layout.glass_wall_edges.has(key):
						check(layout.wall_edges.has(key), "neighbor-room wall survives")
	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = 120
	var sample: Dictionary = SAMPLE.generate(sample_rng)
	check(not sample.is_empty(), "sample generates")
	var lift: Dictionary = sample.rooms[sample.elevator_room_id]
	check(lift.archetype == "elevator_lobby" and not lift.elevator_reception and not lift.has("elevator_facade_edge"), "sample lift layout unchanged")
	check(sample.connections.any(func(item: Dictionary): return item.is_elevator_sliding_door), "sample authored lift connection preserved")
	print("RANDOM RECEPTION BOUNDARIES checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
