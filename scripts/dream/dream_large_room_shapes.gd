extends RefCounted
## A topology pass over the existing BSP leaves. No second room generator,
## meshes, physics bodies or alternative navigation implementation.
static func apply(world: Node, rng: RandomNumberGenerator) -> void:
	for room in world.rooms:
		var rect: Rect2i = room.grid_rect
		room["shape"] = &"rectangle"
		room["void_rect"] = Rect2i()
		room["is_large"] = rect.size.x >= 16 and rect.size.y >= 16 and rect.get_area() >= 320
		if room.is_large and int(room.id) != world.spawn_room_id:
			var total: float = world.rectangle_large_weight + world.irregular_large_weight + world.courtyard_large_weight
			var roll := rng.randf() * maxf(total, 0.001)
			var kind := &"rectangle"
			if roll >= world.rectangle_large_weight + world.irregular_large_weight:
				kind = &"courtyard"
			elif roll >= world.rectangle_large_weight:
				kind = &"irregular"
			var cut := Rect2i()
			if kind == &"courtyard":
				# Four-cell-wide ring on every side. The solid core is NOT floor.
				cut = rect.grow(-4)
			elif kind == &"irregular":
				var size := Vector2i(maxi(4, rect.size.x / 3), maxi(4, rect.size.y / 3))
				var start_corner := rng.randi_range(0, 3)
				for attempt in 4:
					var corner := (start_corner + attempt) % 4
					var point := Vector2i(rect.position.x if corner % 2 == 0 else rect.end.x-size.x, rect.position.y if corner < 2 else rect.end.y-size.y)
					var candidate := Rect2i(point, size)
					if _clear_of_doors(world, candidate):
						cut = candidate
						break
			if cut.has_area() and _clear_of_doors(world, cut):
				room.shape = kind
				room.void_rect = cut
				for y in range(cut.position.y, cut.end.y):
					for x in range(cut.position.x, cut.end.x):
						var cell := Vector2i(x, y)
						world.floor_cells.erase(cell)
						world.room_cells.erase(cell)
						world.corridor_cells.erase(cell)
		var cells: Array[Vector2i] = []
		var center: Vector2i = room.center_cell
		var best := 1000000
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if int(world.room_cells.get(cell, -1)) != int(room.id):
					continue
				cells.append(cell)
				if not rect.grow(-2).has_point(cell) or (room.void_rect.has_area() and room.void_rect.grow(1).has_point(cell)):
					continue
				var distance := absi(cell.x-center.x) + absi(cell.y-center.y)
				if distance < best:
					best = distance
					room.center_cell = cell
		room["usable_cells"] = cells
	# Reuse the normal edge->WallStraight3D->2D collision pipeline for holes.
	for cell in world.floor_cells:
		for direction in world.CARDINAL_DIRECTIONS:
			if world.floor_cells.has(cell + direction):
				continue
			var edge := {"axis": "H", "x": cell.x, "y": cell.y + (1 if direction.y > 0 else 0)} if direction.y != 0 else {"axis": "V", "x": cell.x + (1 if direction.x > 0 else 0), "y": cell.y}
			var key: String = world._edge_key(edge)
			if not world.door_opening_edges.has(key) and not world.door_edges.has(key) and not world._is_main_opening(edge):
				world.wall_edges[key] = edge
				world.edge_states[key] = &"WALL"
	for corridor in world.corridors:
		corridor.cells = world.corridor_cells.duplicate()

static func _clear_of_doors(world: Node, cut: Rect2i) -> bool:
	for edge in world.door_edges.values():
		for offset in world.DOOR_OPENING_CELLS:
			var segment: Dictionary = edge.duplicate()
			segment["y" if edge.axis == "V" else "x"] += offset
			for side in world._edge_side_cells(segment):
				if cut.grow(3).has_point(side):
					return false
	return not cut.grow(3).has_point(world.spawn_cell)
