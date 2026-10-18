class_name OfficeLevelPackGenerator
extends RefCounted

## Five seeded office silhouettes. The output deliberately retains the
## Dream3D room/edge contract so gameplay, badges and room activation stay owned
## by the existing dungeon.
const CELL_SCALE := 2
const DOOR_CELLS := 3
const SHAPES := [&"rectangle", &"l", &"t", &"cross", &"convex"]
const WEIGHTS := [40, 25, 15, 10, 10]
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const LEGACY = preload("res://scripts/dream/dream_otxo_mansion_generator.gd")


static func generate(rng: RandomNumberGenerator, _options: Dictionary = {}) -> Dictionary:
	var roll := rng.randi_range(0, 99)
	var shape: StringName = SHAPES[0]
	var cumulative := 0
	for i in SHAPES.size():
		cumulative += WEIGHTS[i]
		if roll < cumulative:
			shape = SHAPES[i]
			break
	return generate_shape(rng, shape)


static func generate_shape(rng: RandomNumberGenerator, shape: StringName) -> Dictionary:
	if not SHAPES.has(shape):
		return {}
	# Combat space is reserved before furnishing. One authored cell = two gameplay cells.
	var specs: Array[Dictionary] = []
	var north := ["archive", "conference_large", "server"]
	var middle := ["small_office", "pantry", "open_office"]
	var south := ["printing", "elevator_lobby", "restroom"]
	match shape:
		&"rectangle":
			north[2] = ""
		&"l":
			north = ["open_office", "conference_large", ""]
			middle = ["small_office", "pantry", ""]
			south = ["printing", "restroom", "elevator_lobby"]
			specs.append(_room_spec("manager", Rect2i(-7, 14, 14, 10)))
		&"t":
			north = ["archive", "conference_large", "open_office"]
			middle = ["small_office", "pantry", "restroom"]
			south = ["elevator_lobby", "lounge", ""]
		&"cross":
			north = ["", "conference_large", ""]
			middle = ["restroom", "pantry", "open_office"]
			south = ["", "elevator_lobby", ""]
			specs.append(_room_spec("manager", Rect2i(-7, -34, 14, 10)))
			specs.append(_room_spec("archive", Rect2i(-35, -10, 14, 10)))
			specs.append(_room_spec("server", Rect2i(21, -10, 14, 10)))
		&"convex":
			north = ["", "conference_large", ""]
			middle = ["open_office", "pantry", "server"]
			south = ["archive", "elevator_lobby", "restroom"]
			specs.append(_room_spec("printing", Rect2i(-35, 4, 14, 10)))
			specs.append(_room_spec("lounge", Rect2i(21, 4, 14, 10)))
	for col in 3:
		var x := -21 + col * 14
		if not north[col].is_empty():
			var north_depth := 16 if north[col] == "open_office" else 14
			specs.append(_room_spec(north[col], Rect2i(x, -10 - north_depth, 14, north_depth)))
		if not middle[col].is_empty():
			var middle_rect := Rect2i(x, -10, 14, 10)
			if middle[col] == "open_office" and shape in [&"rectangle", &"cross", &"convex"]:
				middle_rect = Rect2i(x, -16, 14, 16)
			specs.append(_room_spec(middle[col], middle_rect))
		if not south[col].is_empty():
			specs.append(_room_spec(south[col], Rect2i(x, 4, 14, 10)))
	specs.append(_room_spec("corridor", Rect2i(-35, 0, 70, 4) if shape in [&"cross", &"convex"] else Rect2i(-21, 0, 42, 4)))
	# Variation is bounded to optional room roles; required rooms stay present.
	for spec in specs:
		if spec.kind == "elevator_lobby":
			# Keep lift identity independent from the room's furnishing role.
			spec["elevator_reception"] = true
		if spec.kind == "archive" and rng.randf() < 0.5:
			spec.kind = "manager"
		elif spec.kind == "archive" and rng.randf() < 0.25:
			spec.kind = "storage"
		elif spec.kind == "printing" and rng.randf() < 0.4:
			spec.kind = "reception"
		elif spec.kind == "small_office" and rng.randf() < 0.4:
			spec.kind = "meeting_small"
	return build_from_specs(rng, shape, specs)


static func build_from_specs(rng: RandomNumberGenerator, shape: StringName, specs: Array[Dictionary], authored_links: Array = [], authored_glass: Array = []) -> Dictionary:
	var lift_id := -1
	for i in specs.size():
		if specs[i].kind == "elevator_lobby":
			lift_id = i
	if lift_id < 0:
		return {}
	var rooms: Array = []
	var partitions: Array[Dictionary] = []
	var floor_cells: Dictionary = {}
	var room_cells: Dictionary = {}
	var min_cell := Vector2i(2147483647, 2147483647)
	var max_cell := Vector2i(-2147483647, -2147483647)
	for room_id in specs.size():
		var spec: Dictionary = specs[room_id]
		var rect: Rect2i = spec.rect
		min_cell = Vector2i(mini(min_cell.x, rect.position.x), mini(min_cell.y, rect.position.y))
		max_cell = Vector2i(maxi(max_cell.x, rect.end.x), maxi(max_cell.y, rect.end.y))
		var shape_cells: Array[Vector2i] = []
		var usable_cells: Array[Vector2i] = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if floor_cells.has(cell):
					return {}
				floor_cells[cell] = &"room"
				room_cells[cell] = room_id
				shape_cells.append(cell)
				if x > rect.position.x and x < rect.end.x - 2 and y > rect.position.y and y < rect.end.y - 2:
					usable_cells.append(cell)
		var kind: String = "reception" if bool(spec.get("elevator_reception", false)) else spec.kind
		var safe := kind in ["elevator_lobby", "reception"]
		var center := rect.position + rect.size / 2
		rooms.append({
			"id": room_id, "name": kind.capitalize() + str(room_id), "grid_rect": rect,
			"center_cell": center, "geometric_center_cell": center,
			"macro_coord": Vector2i(room_id, 0), "shape": &"rectangle",
			"size_class": &"large" if kind in ["open_office", "conference_large"] else &"medium",
			"office_combat_layout": true,
			"elevator_reception": bool(spec.get("elevator_reception", false)),
			"authored_sample": not authored_links.is_empty(),
			"sample_key": spec.get("key", kind),
			"navigation_role": &"circulation" if kind == "corridor" else &"room",
			"shape_cells": shape_cells, "usable_cells": usable_cells,
			"connections": [], "neighbors": [], "room_type": &"elevator_lobby" if room_id == lift_id else (&"corridor" if kind == "corridor" else &"normal"),
			"combat_room": not safe, "state": &"UNSEEN", "revealed": false,
			"activated": false, "cleared": safe, "archetype": kind,
		})
		partitions.append({"id": room_id, "rect": rect})
	var corridor_id := -1
	for i in rooms.size():
		if rooms[i].archetype == "corridor":
			corridor_id = i
	var boundaries: Array[Dictionary] = []
	for candidate in LEGACY._find_shared_boundaries(rooms):
		if authored_links.is_empty() and (int(candidate.room_a) == lift_id or int(candidate.room_b) == lift_id) and int(candidate.room_a) != corridor_id and int(candidate.room_b) != corridor_id:
			continue
		boundaries.append(candidate)
	var edges: Array[int] = []
	# Connect each frontage to the main circulation spine first. A generic
	# boundary-order spanning tree tends to snake through neighbouring offices
	# and can more than double the authored travel distance.
	var reached: Dictionary = {lift_id: true, corridor_id: true}
	if not authored_links.is_empty():
		for i in boundaries.size():
			var boundary: Dictionary = boundaries[i]
			var ka: String = rooms[int(boundary.room_a)].sample_key
			var kb: String = rooms[int(boundary.room_b)].sample_key
			for link in authored_links:
				if (ka == link[0] and kb == link[1]) or (ka == link[1] and kb == link[0]):
					edges.append(i)
					boundary["authored_start"] = int(link[2])
					boundary["authored_style"] = String(link[3])
					break
		for room in rooms:
			reached[int(room.id)] = true
	for i in boundaries.size():
		if not authored_links.is_empty():
			break
		var frontage: Dictionary = boundaries[i]
		if int(frontage.room_a) == corridor_id or int(frontage.room_b) == corridor_id:
			edges.append(i)
			reached[int(frontage.room_a)] = true
			reached[int(frontage.room_b)] = true
	while reached.size() < rooms.size():
		var found := -1
		for i in boundaries.size():
			var b: Dictionary = boundaries[i]
			if reached.has(int(b.room_a)) != reached.has(int(b.room_b)):
				if found < 0:
					found = i
				if String(b.axis) == "H":
					found = i
					break
		if found < 0:
			if OS.get_environment("OFFICE_LAYOUT_DEBUG") == "1":
				print("OFFICE disconnected ", shape, " reached=", reached, " boundaries=", boundaries)
			return {}
		edges.append(found)
		reached[int(boundaries[found].room_a)] = true
		reached[int(boundaries[found].room_b)] = true
	for i in boundaries.size():
		if not authored_links.is_empty():
			break
		if edges.has(i):
			continue
		var b: Dictionary = boundaries[i]
		if int(b.room_a) != lift_id and int(b.room_b) != lift_id and rng.randf() < 0.18:
			edges.append(i)
	var connections: Array = []
	var door_edges: Dictionary = {}
	var door_opening_edges: Dictionary = {}
	for boundary_index in edges:
		var b: Dictionary = boundaries[boundary_index]
		var a := int(b.room_a)
		var c := int(b.room_b)
		var axis: String = b.axis
		var cut: int = b.cut
		var span_start: int = b.span_start
		var span_end: int = b.span_end
		var is_lift := (a == lift_id or c == lift_id) and not bool(specs[lift_id].get("elevator_reception", false))
		var style := String(b.get("authored_style", _door_style(specs[a].kind, specs[c].kind)))
		if bool(specs[lift_id].get("elevator_reception", false)) and (a == lift_id or c == lift_id):
			style = "double"
		var opening := 4 if style == "open" else (DOOR_CELLS if style == "double" else CELL_SCALE)
		# Leave a contiguous wall span for the glass partition beside a door.
		var start: int = int(b.get("authored_start", (span_start + span_end - opening) / 2))
		var kind_a: String = specs[a].kind
		var kind_c: String = specs[c].kind
		var door_style := "elevator" if is_lift else style
		var edge := {"axis": axis, "x": cut if axis == "V" else start, "y": start if axis == "V" else cut,
			"opening_cells": opening, "opening_start": start, "opening_end": start + opening,
			"region_a_id": a, "region_b_id": c, "door_id": connections.size(),
			"connection_id": connections.size(), "door_direction": axis,
			"hinge_side": "left", "shared_boundary_length": span_end - span_start,
			"door_style": door_style, "is_elevator_sliding_door": is_lift}
		edge["wall_edge"] = edge.duplicate(true)
		edge["door_position"] = LEGACY._edge_world_position(edge)
		door_edges[LEGACY._edge_key(edge)] = edge
		for slot in range(start, start + opening):
			var piece := {"axis": axis, "x": cut if axis == "V" else slot,
				"y": slot if axis == "V" else cut, "door_id": edge.door_id,
				"connection_id": edge.connection_id, "region_a_id": a, "region_b_id": c,
				"is_elevator_sliding_door": is_lift}
			door_opening_edges[LEGACY._edge_key(piece)] = piece
		var inside_a := Vector2i(cut - 1, start + 1) if axis == "V" else Vector2i(start + 1, cut - 1)
		var outward := Vector2i.RIGHT if axis == "V" else Vector2i.DOWN
		var inside_c := inside_a + outward
		connections.append({"id": connections.size(), "door_id": edge.door_id, "a": a, "b": c,
			"length": 0, "door_a": {"inside_cell": inside_a, "outside_cell": inside_c,
				"outward": outward, "room_id": a, "opening_cells": opening},
			"door_b": {"inside_cell": inside_c, "outside_cell": inside_a,
				"outward": -outward, "room_id": c, "opening_cells": opening},
			"door_edge": edge, "door_style": door_style, "is_elevator_sliding_door": is_lift})
		rooms[a].connections.append(c)
		rooms[a].neighbors.append(c)
		rooms[c].connections.append(a)
		rooms[c].neighbors.append(a)
	var glass_edges: Dictionary = {}
	var glass_boundaries := 0
	var glass_order: Array[int] = []
	for i in boundaries.size():
		glass_order.append(i)
	glass_order.sort_custom(func(left: int, right: int) -> bool:
		var a: Dictionary = boundaries[left]
		var b: Dictionary = boundaries[right]
		var a_front := int(a.room_a) == corridor_id or int(a.room_b) == corridor_id
		var b_front := int(b.room_a) == corridor_id or int(b.room_b) == corridor_id
		var a_other := int(a.room_b) if int(a.room_a) == corridor_id else int(a.room_a)
		var b_other := int(b.room_b) if int(b.room_a) == corridor_id else int(b.room_a)
		var a_priority := 0 if a_front and String(a.axis) == "H" and int(rooms[a_other].grid_rect.position.y) < 0 else (1 if a_front else 2)
		var b_priority := 0 if b_front and String(b.axis) == "H" and int(rooms[b_other].grid_rect.position.y) < 0 else (1 if b_front else 2)
		return a_priority < b_priority if a_priority != b_priority else left < right
	)
	for i in glass_order:
		var b: Dictionary = boundaries[i]
		var a := int(b.room_a)
		var c := int(b.room_b)
		if a == lift_id or c == lift_id:
			continue
		var arch_a: String = String(rooms[a].get("archetype", ""))
		var arch_c: String = String(rooms[c].get("archetype", ""))
		var sample_a: String = String(rooms[a].get("sample_key", ""))
		var sample_c: String = String(rooms[c].get("sample_key", ""))
		if arch_a == "open_office" or arch_c == "open_office" or sample_a == "office" or sample_c == "office":
			continue
		var run_start := -1
		var has_glass_run := false
		for slot in range(int(b.span_start), int(b.span_end) - 2):
			var open_run := true
			for check_slot in range(slot, slot + 3):
				var check_edge := {"axis": b.axis, "x": int(b.cut) if b.axis == "V" else check_slot,
					"y": check_slot if b.axis == "V" else int(b.cut)}
				if door_opening_edges.has(LEGACY._edge_key(check_edge)):
					open_run = false
					break
			if open_run:
				run_start = slot
				has_glass_run = true
				break
		if not has_glass_run:
			continue
		for slot in range(run_start, run_start + 3):
			var glass_edge := {"axis": b.axis, "x": int(b.cut) if b.axis == "V" else slot,
				"y": slot if b.axis == "V" else int(b.cut)}
			glass_edges[LEGACY._edge_key(glass_edge)] = glass_edge
		glass_boundaries += 1
		if glass_boundaries >= 2:
			break
	if not authored_glass.is_empty():
		glass_edges.clear()
		glass_boundaries = authored_glass.size()
		for section in authored_glass:
			for slot in range(int(section[2]), int(section[2]) + int(section[3])):
				var glass_edge := {"axis": String(section[0]), "x": int(section[1]) if section[0] == "V" else slot, "y": slot if section[0] == "V" else int(section[1])}
				glass_edges[LEGACY._edge_key(glass_edge)] = glass_edge
	if glass_boundaries < 2:
		if OS.get_environment("OFFICE_LAYOUT_DEBUG") == "1":
			print("OFFICE missing glass ", shape, " boundaries=", boundaries, " count=", glass_boundaries)
		return {}
	var wall_edges: Dictionary = {}
	var internal_walls: Dictionary = {}
	var edge_states: Dictionary = {}
	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		for direction in DIRS:
			var neighbor := cell + direction
			var wall: Dictionary = LEGACY._edge_from_inside(cell, direction)
			var key: String = LEGACY._edge_key(wall)
			if not floor_cells.has(neighbor):
				edge_states[key] = &"WALL"
				wall_edges[key] = wall
			elif int(room_cells.get(neighbor, -1)) != int(room_cells.get(cell, -1)):
				var room_a_id: int = int(room_cells.get(cell, -1))
				var room_b_id: int = int(room_cells.get(neighbor, -1))
				if _office_corridor_boundary(rooms[room_a_id], rooms[room_b_id]):
					edge_states[key] = &"OPEN"
					continue
				if door_edges.has(key):
					edge_states[key] = &"DOOR"
				elif door_opening_edges.has(key):
					edge_states[key] = &"DOOR_OPENING"
				elif glass_edges.has(key):
					edge_states[key] = &"GLASS_WINDOW"
					wall_edges[key] = wall
					internal_walls[key] = wall
				else:
					edge_states[key] = &"WALL"
					wall_edges[key] = wall
					internal_walls[key] = wall
	var lift_rect: Rect2i = rooms[lift_id].grid_rect
	if bool(rooms[lift_id].get("elevator_reception", false)):
		# Exterior facade: exiting walks north directly into the reception.
		var facade_start := lift_rect.position.x + lift_rect.size.x / 2 - 1
		var facade := {"axis": "H", "x": facade_start, "y": lift_rect.end.y, "opening_cells": DOOR_CELLS, "opening_start": facade_start, "opening_end": facade_start + DOOR_CELLS, "region_a_id": lift_id, "region_b_id": -1, "door_id": connections.size(), "connection_id": -1, "door_direction": "H", "door_style": "elevator", "is_elevator_sliding_door": true, "elevator_cab_inward": Vector2.DOWN}
		facade["wall_edge"] = facade.duplicate(true)
		facade["door_position"] = LEGACY._edge_world_position(facade)
		rooms[lift_id]["elevator_facade_edge"] = facade
		door_edges[LEGACY._edge_key(facade)] = facade
		for slot in range(facade_start, facade_start + DOOR_CELLS):
			var piece := {"axis": "H", "x": slot, "y": lift_rect.end.y, "door_id": connections.size(), "connection_id": -1, "region_a_id": lift_id, "region_b_id": -1, "is_elevator_sliding_door": true}
			var facade_key := LEGACY._edge_key(piece)
			door_opening_edges[facade_key] = piece
			edge_states[facade_key] = &"DOOR" if slot == facade_start else &"DOOR_OPENING"
			wall_edges.erase(facade_key)
			internal_walls.erase(facade_key)
	var spawn_cell: Vector2i = lift_rect.position + lift_rect.size / 2
	spawn_cell = Vector2i(spawn_cell.x, lift_rect.end.y - 3 if bool(rooms[lift_id].get("elevator_reception", false)) else lift_rect.position.y + 2)
	if not _all_rooms_within_travel_budget(spawn_cell, rooms, floor_cells, edge_states):
		return {}
	return {"floor_shape": shape, "building_rect": Rect2i(min_cell, max_cell - min_cell),
		"rooms": rooms, "partitions": partitions, "corridors": [], "connections": connections,
		"floor_cells": floor_cells, "room_cells": room_cells, "corridor_cells": {},
		"wall_edges": wall_edges, "internal_wall_edges": internal_walls,
		"door_edges": door_edges, "door_opening_edges": door_opening_edges,
		"glass_wall_edges": glass_edges, "glass_group_count": glass_boundaries, "edge_states": edge_states,
		"spawn_room_id": lift_id, "spawn_cell": spawn_cell,
		"main_entrance": {"start_cell": spawn_cell}, "next_door_id": connections.size() + (1 if bool(rooms[lift_id].get("elevator_reception", false)) else 0),
		"elevator_room_id": lift_id, "elevator_anchor_cell": spawn_cell,
		"key_room_id": -1, "boss_room_id": -1, "boss_door_id": -1}


static func _room_spec(kind: String, rect: Rect2i) -> Dictionary:
	return {"kind": kind, "rect": rect}


static func _office_corridor_boundary(a: Dictionary, b: Dictionary) -> bool:
	var office_a := String(a.get("archetype", "")) == "open_office" or String(a.get("sample_key", "")) == "office"
	var office_b := String(b.get("archetype", "")) == "open_office" or String(b.get("sample_key", "")) == "office"
	var corridor_a := String(a.get("archetype", "")) == "corridor"
	var corridor_b := String(b.get("archetype", "")) == "corridor"
	# Authored sample corridor aliases preserve their approved frontage.
	if bool(a.get("authored_sample", false)) and bool(b.get("authored_sample", false)):
		corridor_a = corridor_a or String(a.get("sample_key", "")) in ["north", "south", "east", "west"]
		corridor_b = corridor_b or String(b.get("sample_key", "")) in ["north", "south", "east", "west"]
	return (office_a and corridor_b) or (office_b and corridor_a)


static func _all_rooms_within_travel_budget(start: Vector2i, rooms: Array, floor_cells: Dictionary, edge_states: Dictionary) -> bool:
	# Thirty-two authored cells equal 64 formal gameplay cells. Doors and open
	# passages count as traversable; intact glass and walls do not.
	var distances: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		var next_distance: int = int(distances[cell]) + 1
		for direction in DIRS:
			var neighbor := cell + direction
			if not floor_cells.has(neighbor) or distances.has(neighbor):
				continue
			var edge_key: String = LEGACY._edge_key(LEGACY._edge_from_inside(cell, direction))
			if edge_states.get(edge_key, &"") in [&"WALL", &"GLASS_WINDOW"]:
				continue
			distances[neighbor] = next_distance
			frontier.append(neighbor)
	for room_variant in rooms:
		var room: Dictionary = room_variant
		if String(room.get("archetype", "")) == "corridor":
			continue
		var center: Vector2i = room.get("center_cell", Vector2i.ZERO)
		if not distances.has(center) or int(distances[center]) > 32 * CELL_SCALE:
			if OS.get_environment("OFFICE_LAYOUT_DEBUG") == "1":
				print("OFFICE route rejected ", room.archetype, " center=", center, " distance=", distances.get(center, -1))
			return false
	return true


static func _door_style(a: String, b: String) -> String:
	if a in ["open_office", "lounge"] or b in ["open_office", "lounge"]:
		return "open"
	if a == "conference_large" or b == "conference_large":
		return "double"
	return "single"
