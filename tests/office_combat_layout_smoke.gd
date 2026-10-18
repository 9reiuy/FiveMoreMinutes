extends SceneTree

const GENERATOR = preload("res://scripts/dream/office_level_pack_generator.gd")
const PLANNER = preload("res://scripts/dream/otxo_room_layout_planner.gd")

func _initialize() -> void:
	var failures := 0
	for index in range(GENERATOR.SHAPES.size() * 5):
		var shape: StringName = GENERATOR.SHAPES[index / 5]
		var rng := RandomNumberGenerator.new()
		rng.seed = 120 + index % 5
		var layout: Dictionary = GENERATOR.generate_shape(rng, shape)
		if layout.is_empty():
			print("EMPTY ", shape)
			failures += 1
			continue
		for room in layout.rooms:
			if room.archetype in ["corridor", "elevator_lobby"]:
				continue
			var doors: Array = []
			for connection in layout.connections:
				if connection.a == room.id:
					doors.append(connection.door_a)
				elif connection.b == room.id:
					doors.append(connection.door_b)
			var rect: Rect2i = room.grid_rect
			var plan: Dictionary = PLANNER.plan_room_layout(room.id, room, doors, [], 8, 2, 0, rng.seed, Rect2((Vector2(rect.position) - Vector2.ONE * .5) * 32.0, Vector2(rect.size) * 32.0).grow(-18))
			if not plan.success:
				print("FAILED ", shape, " ", room.archetype, " ", rect)
				failures += 1
	print("COMBAT LAYOUT failures=", failures)
	quit(1 if failures else 0)
