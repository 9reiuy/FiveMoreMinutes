class_name DreamOTXOMansionGenerator
extends RefCounted

## Procedural Contiguous Office & Mansion Generator (OTXO & Hotline Miami style).
##
## Architectural Structure (TASK-016-B):
## 1. Top-Center Elevator Zone: Elevator Cab + Elevator Porch (Formal Floor Exit & Spawn).
## 2. Central Reception Area: Directly below elevator porch (Non-combat greeting zone).
## 3. Main Central Lobby: Grand open foyer connecting Reception, Corridors, and Central Lounge.
## 4. Left & Right Wing Corridors: East-west main thoroughfares (100% clear of obstacles).
## 5. Exactly Two Large Rooms:
##    - Left Large Room: Open Office Bullpen (Combat zone).
##    - Right Large Room: Boardroom Conference Hall (Combat zone).
## 6. Flanking Small Rooms: Executive offices, server room, archives, storage, and break lounges.
## 7. Non-combat areas (Elevator, Porch, Reception, Lobby, Corridors) spawn ZERO enemies.
## 8. Seamless Engine Contract: Returns exact dictionary schema expected by dream_3d_random_dungeon.gd.

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), # UP
	Vector2i(1, 0),  # RIGHT
	Vector2i(0, 1),  # DOWN
	Vector2i(-1, 0), # LEFT
]

const DEFAULT_BUILDING_WIDTH := 64
const DEFAULT_BUILDING_HEIGHT := 48
const DEFAULT_DOOR_OPENING_CELLS := 4


static func generate(rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var b_width: int = maxi(int(options.get("building_width", DEFAULT_BUILDING_WIDTH)), 48)
	var b_height: int = maxi(int(options.get("building_height", DEFAULT_BUILDING_HEIGHT)), 36)
	var glass_chance: float = clampf(float(options.get("otxo_mansion_glass_chance", 0.35)), 0.0, 1.0)
	var loop_ratio: float = clampf(float(options.get("otxo_mansion_loop_ratio", 0.45)), 0.0, 1.0)

	var half_w := b_width / 2
	var half_h := b_height / 2
	var slab := Rect2i(-half_w + 2, -half_h + 2, b_width - 4, b_height - 4)

	# 1. Author Office Skeleton Blueprint Specs
	# Center X span: [-10, 10] (20 wide)
	# Left Wing X span: [-30, -10] (20 wide)
	# Right Wing X span: [10, 30] (20 wide)
	# Slab Y span: [-22, 22] (44 high)
	var specs: Array[Dictionary] = [
		# 0: Reception Area (Center North, directly under Elevator Porch)
		{
			"name": "Reception",
			"rect": Rect2i(-10, -22, 20, 12),
			"room_type": &"reception",
			"combat_room": false,
			"size_class": &"medium",
			"archetype": "reception",
		},
		# 1: Main Central Lobby (Center Middle, grand open foyer)
		{
			"name": "MainLobby",
			"rect": Rect2i(-10, -10, 20, 14),
			"room_type": &"main_lobby",
			"combat_room": false,
			"size_class": &"medium",
			"archetype": "lounge",
		},
		# 2: Left Wing Main Corridor (Horizontal thoroughfare)
		{
			"name": "LeftCorridor",
			"rect": Rect2i(-30, -2, 20, 4),
			"room_type": &"corridor",
			"combat_room": false,
			"size_class": &"small",
			"archetype": "corridor",
		},
		# 3: Right Wing Main Corridor (Horizontal thoroughfare)
		{
			"name": "RightCorridor",
			"rect": Rect2i(10, -2, 20, 4),
			"room_type": &"corridor",
			"combat_room": false,
			"size_class": &"small",
			"archetype": "corridor",
		},
		# 4: Left Large Room (1st of 2 Large Rooms - Open Office Bullpen)
		{
			"name": "LeftLargeRoom",
			"rect": Rect2i(-30, 2, 20, 20),
			"room_type": &"large_office",
			"combat_room": true,
			"size_class": &"large",
			"archetype": "open_office",
		},
		# 5: Right Large Room (2nd of 2 Large Rooms - Boardroom & Executive Conference)
		{
			"name": "RightLargeRoom",
			"rect": Rect2i(10, 2, 20, 20),
			"room_type": &"large_office",
			"combat_room": true,
			"size_class": &"large",
			"archetype": "conference",
		},
		# 6: Left Small Room 1 (Manager's Executive Office)
		{
			"name": "LeftSmall1",
			"rect": Rect2i(-30, -12, 20, 10),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"small",
			"archetype": "executive",
		},
		# 7: Left Small Room 2 (Archive & Records Storage)
		{
			"name": "LeftSmall2",
			"rect": Rect2i(-30, -22, 20, 10),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"small",
			"archetype": "storage",
		},
		# 8: Right Small Room 1 (IT & Server Infrastructure)
		{
			"name": "RightSmall1",
			"rect": Rect2i(10, -22, 10, 10),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"small",
			"archetype": "security",
		},
		# 9: Right Small Room 2 (Confidential Archive & Security)
		{
			"name": "RightSmall2",
			"rect": Rect2i(20, -22, 10, 10),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"small",
			"archetype": "storage",
		},
		# 10: Right Small Room 3 (Department Meeting Room)
		{
			"name": "RightSmall3",
			"rect": Rect2i(10, -12, 20, 10),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"small",
			"archetype": "conference",
		},
		# 11: Central Break Lounge (Cafeteria / Pantry / Rest Lounge)
		{
			"name": "CentralBreakLounge",
			"rect": Rect2i(-10, 4, 20, 10),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"medium",
			"archetype": "lounge",
		},
		# 12: South Annex (Operations & Maintenance)
		{
			"name": "SouthAnnex",
			"rect": Rect2i(-10, 14, 20, 8),
			"room_type": &"small_office",
			"combat_room": true,
			"size_class": &"small",
			"archetype": "security",
		},
		# 13: Elevator Porch (North Doorway Transition to Reception)
		{
			"name": "ElevatorPorch",
			"rect": Rect2i(-7, -26, 15, 4),
			"room_type": &"corridor",
			"combat_room": false,
			"size_class": &"small",
			"archetype": "corridor",
		},
		# 14: Elevator Cab (Formal Spawn & Floor Exit Point)
		{
			"name": "ElevatorCab",
			"rect": Rect2i(-3, -30, 7, 4),
			"room_type": &"elevator_lobby",
			"combat_room": false,
			"size_class": &"small",
			"archetype": "elevator_lobby",
		},
	]

	var elevator_room_id := 14
	var porch_room_id := 13
	var elevator_center := Vector2i(0, -28)
	var b_top := -32
	var building_rect := Rect2i(-half_w, b_top, b_width, half_h - b_top)

	# 2. Build Room records, floor_cells, and room_cells
	var rooms: Array = []
	var partitions: Array[Dictionary] = []
	var floor_cells: Dictionary = {}
	var room_cells: Dictionary = {}

	for room_id in range(specs.size()):
		var spec: Dictionary = specs[room_id]
		var rect: Rect2i = spec["rect"]
		partitions.append({
			"id": room_id,
			"rect": rect,
		})
		var center := Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		if room_id == elevator_room_id:
			center = elevator_center

		var shape_cells: Array[Vector2i] = []
		var usable_cells: Array[Vector2i] = []

		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				shape_cells.append(cell)
				floor_cells[cell] = &"room"
				room_cells[cell] = room_id
				if x > rect.position.x + 1 and x < rect.end.x - 2 and y > rect.position.y + 1 and y < rect.end.y - 2:
					usable_cells.append(cell)

		if usable_cells.is_empty():
			usable_cells = shape_cells.duplicate()

		var combat: bool = bool(spec.get("combat_room", false))
		var room: Dictionary = {
			"id": room_id,
			"name": spec.get("name", "Room%d" % room_id),
			"grid_rect": rect,
			"center_cell": center,
			"geometric_center_cell": center,
			"macro_coord": Vector2i(room_id, 0),
			"shape": &"rectangle",
			"size_class": spec.get("size_class", &"small"),
			"shape_cells": shape_cells,
			"usable_cells": usable_cells,
			"connections": [],
			"neighbors": [],
			"room_type": spec.get("room_type", &"normal"),
			"combat_room": combat,
			"state": &"UNSEEN",
			"revealed": false,
			"activated": false,
			"cleared": not combat,
			"archetype": spec.get("archetype", "office"),
		}
		rooms.append(room)

	# 3. Detect All Shared Boundaries Between Adjacent Rooms
	var shared_boundaries := _find_shared_boundaries(rooms)

	# 4. Mandatory Core Spine Edge Pairs (Guaranteed connectivity)
	var core_spine_pairs := [
		Vector2i(14, 13), # Elevator Cab <-> Porch
		Vector2i(13, 0),  # Porch <-> Reception
		Vector2i(0, 1),   # Reception <-> Main Lobby
		Vector2i(1, 2),   # Main Lobby <-> Left Wing Corridor
		Vector2i(1, 3),   # Main Lobby <-> Right Wing Corridor
		Vector2i(1, 11),  # Main Lobby <-> Central Break Lounge
		Vector2i(2, 4),   # Left Wing Corridor <-> Left Large Room
		Vector2i(2, 6),   # Left Wing Corridor <-> Left Small 1
		Vector2i(6, 7),   # Left Small 1 <-> Left Small 2
		Vector2i(3, 5),   # Right Wing Corridor <-> Right Large Room
		Vector2i(3, 10),  # Right Wing Corridor <-> Right Small 3
		Vector2i(10, 8),  # Right Small 3 <-> Right Small 1
		Vector2i(10, 9),  # Right Small 3 <-> Right Small 2
		Vector2i(11, 12), # Central Break Lounge <-> South Annex
	]

	# Build boundary index mapping for quick lookup: (min_id, max_id) -> boundary_idx
	var pair_to_boundary: Dictionary = {}
	for b_idx in range(shared_boundaries.size()):
		var b: Dictionary = shared_boundaries[b_idx]
		var u: int = mini(b["room_a"], b["room_b"])
		var v: int = maxi(b["room_a"], b["room_b"])
		pair_to_boundary[Vector2i(u, v)] = b_idx

	# Select connections: Core spine first, then Kruskal MST completion, then loop additions
	var selected_boundary_indices: Dictionary = {}
	for pair in core_spine_pairs:
		var u: int = mini(pair.x, pair.y)
		var v: int = maxi(pair.x, pair.y)
		var p_key := Vector2i(u, v)
		if pair_to_boundary.has(p_key):
			selected_boundary_indices[pair_to_boundary[p_key]] = true

	# Add random loop connections across remaining shared walls
	for b_idx in range(shared_boundaries.size()):
		if selected_boundary_indices.has(b_idx):
			continue
		var b: Dictionary = shared_boundaries[b_idx]
		# Do not add extra doors into the Elevator Cab
		if b["room_a"] == elevator_room_id or b["room_b"] == elevator_room_id:
			continue
		if rng.randf() <= loop_ratio:
			selected_boundary_indices[b_idx] = true

	# 5. Place Doors on Selected Boundaries
	var connections: Array = []
	var door_edges: Dictionary = {}
	var door_opening_edges: Dictionary = {}
	var door_claimed_ranges: Dictionary = {}
	var next_door_id := 0

	for b_idx in selected_boundary_indices.keys():
		var b_data: Dictionary = shared_boundaries[b_idx]
		var r_a: int = b_data["room_a"]
		var r_b: int = b_data["room_b"]
		var axis: String = b_data["axis"]
		var cut: int = b_data["cut"]
		var span_start: int = b_data["span_start"]
		var span_end: int = b_data["span_end"]
		var span_len: int = span_end - span_start

		# Special sliding door between Elevator Cab and Porch
		var is_elevator_door := (r_a == elevator_room_id or r_b == elevator_room_id)
		var door_span := 3 if is_elevator_door else DEFAULT_DOOR_OPENING_CELLS
		var door_start := span_start

		if is_elevator_door:
			door_start = -1 # Centered at X [-1, 2]
		elif span_len > door_span + 2:
			var max_offset := span_len - door_span - 2
			var offset := clampi(rng.randi_range(1, max_offset), 1, max_offset)
			door_start = span_start + offset
		var door_end := door_start + door_span

		if not door_claimed_ranges.has(b_idx):
			door_claimed_ranges[b_idx] = []
		var claimed_list: Array = door_claimed_ranges[b_idx]
		claimed_list.append(Vector2i(door_start, door_end))
		door_claimed_ranges[b_idx] = claimed_list

		var door_edge: Dictionary = {
			"axis": axis,
			"x": cut if axis == "V" else door_start,
			"y": door_start if axis == "V" else cut,
			"opening_cells": door_span,
			"opening_start": door_start,
			"opening_end": door_end,
			"region_a_id": r_a,
			"region_b_id": r_b,
			"door_id": next_door_id,
			"connection_id": connections.size(),
			"door_direction": axis,
			"hinge_side": "left" if posmod(cut + door_start, 2) == 0 else "right",
			"shared_boundary_length": span_len,
			"is_elevator_sliding_door": is_elevator_door,
		}
		door_edge["wall_edge"] = door_edge.duplicate(true)
		door_edge["door_position"] = _edge_world_position(door_edge)

		var door_root_key := _edge_key(door_edge)
		door_edges[door_root_key] = door_edge

		for c in range(door_start, door_end):
			var op_edge: Dictionary = {
				"axis": axis,
				"x": cut if axis == "V" else c,
				"y": c if axis == "V" else cut,
				"door_id": next_door_id,
				"connection_id": connections.size(),
				"region_a_id": r_a,
				"region_b_id": r_b,
				"is_elevator_sliding_door": is_elevator_door,
			}
			door_opening_edges[_edge_key(op_edge)] = op_edge

		var inside_a := Vector2i(cut - 1, door_start + 1) if axis == "V" else Vector2i(door_start + 1, cut - 1)
		var outward_a := Vector2i(1, 0) if axis == "V" else Vector2i(0, 1)
		var inside_b := Vector2i(cut, door_start + 1) if axis == "V" else Vector2i(door_start + 1, cut)
		var outward_b := -outward_a

		var conn: Dictionary = {
			"id": connections.size(),
			"door_id": next_door_id,
			"a": r_a,
			"b": r_b,
			"length": 0,
			"door_a": {"inside_cell": inside_a, "outside_cell": inside_b, "outward": outward_a, "room_id": r_a, "opening_cells": door_span},
			"door_b": {"inside_cell": inside_b, "outside_cell": inside_a, "outward": outward_b, "room_id": r_b, "opening_cells": door_span},
			"door_edge": door_edge,
			"is_elevator_sliding_door": is_elevator_door,
		}
		connections.append(conn)

		rooms[r_a]["connections"].append(r_b)
		rooms[r_a]["neighbors"].append(r_b)
		rooms[r_b]["connections"].append(r_a)
		rooms[r_b]["neighbors"].append(r_a)

		next_door_id += 1

	# 6. Place Breakable Glass Windows on Non-Door Wall Spans
	var glass_wall_edges: Dictionary = {}
	for b_idx in range(shared_boundaries.size()):
		var b_data: Dictionary = shared_boundaries[b_idx]
		var r_a: int = b_data["room_a"]
		var r_b: int = b_data["room_b"]
		# No glass windows into elevator cab or porch
		if r_a == elevator_room_id or r_b == elevator_room_id or r_a == porch_room_id or r_b == porch_room_id:
			continue
		var arch_a: String = rooms[r_a].get("archetype", "")
		var arch_b: String = rooms[r_b].get("archetype", "")
		if arch_a == "open_office" or arch_b == "open_office":
			continue

		var axis: String = b_data["axis"]
		var cut: int = b_data["cut"]
		var span_start: int = b_data["span_start"]
		var span_end: int = b_data["span_end"]

		var claimed: Array = door_claimed_ranges.get(b_idx, [])
		var free_spans := _find_free_spans(span_start, span_end, claimed, 3)
		for f_span in free_spans:
			if rng.randf() <= glass_chance:
				var win_len := mini(f_span.y - f_span.x, 4)
				var win_start := f_span.x + (f_span.y - f_span.x - win_len) / 2
				for c in range(win_start, win_start + win_len):
					var g_edge := {
						"axis": axis,
						"x": cut if axis == "V" else c,
						"y": c if axis == "V" else cut,
					}
					glass_wall_edges[_edge_key(g_edge)] = g_edge

	# 7. Generate Exterior & Interior Wall Edges and Edge States
	var wall_edges: Dictionary = {}
	var internal_wall_edges: Dictionary = {}
	var edge_states: Dictionary = {}

	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		for dir in CARDINAL_DIRECTIONS:
			var neighbor := cell + dir
			var edge := _edge_from_inside(cell, dir)
			var key := _edge_key(edge)

			if not floor_cells.has(neighbor):
				# Outer wall facing outside
				edge_states[key] = &"WALL"
				wall_edges[key] = edge
			elif int(room_cells.get(neighbor, -1)) != int(room_cells.get(cell, -1)):
				# Shared interior boundary
				var room_a_id: int = int(room_cells.get(cell, -1))
				var room_b_id: int = int(room_cells.get(neighbor, -1))
				var edge_arch_a: String = rooms[room_a_id].get("archetype", "") if room_a_id >= 0 and room_a_id < rooms.size() else ""
				var edge_arch_b: String = rooms[room_b_id].get("archetype", "") if room_b_id >= 0 and room_b_id < rooms.size() else ""
				if edge_arch_a == "open_office" or edge_arch_b == "open_office":
					edge_states[key] = &"OPEN"
					continue
				if door_edges.has(key):
					edge_states[key] = &"DOOR"
				elif door_opening_edges.has(key):
					edge_states[key] = &"DOOR_OPENING"
				elif glass_wall_edges.has(key):
					edge_states[key] = &"GLASS_WINDOW"
					wall_edges[key] = edge
					internal_wall_edges[key] = edge
				else:
					edge_states[key] = &"WALL"
					wall_edges[key] = edge
					internal_wall_edges[key] = edge

	return {
		"building_rect": building_rect,
		"rooms": rooms,
		"partitions": partitions,
		"corridors": [],
		"connections": connections,
		"floor_cells": floor_cells,
		"room_cells": room_cells,
		"corridor_cells": {},
		"wall_edges": wall_edges,
		"internal_wall_edges": internal_wall_edges,
		"door_edges": door_edges,
		"door_opening_edges": door_opening_edges,
		"glass_wall_edges": glass_wall_edges,
		"edge_states": edge_states,
		"spawn_room_id": elevator_room_id,
		"spawn_cell": elevator_center,
		"main_entrance": {"start_cell": elevator_center},
		"next_door_id": next_door_id,
		"elevator_room_id": elevator_room_id,
		"elevator_anchor_cell": elevator_center,
		"corridor_room_id": porch_room_id,
		"key_room_id": -1,
		"boss_room_id": -1,
		"boss_door_id": -1,
	}


static func _find_shared_boundaries(rooms: Array) -> Array[Dictionary]:
	var boundaries: Array[Dictionary] = []
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var r_i: Rect2i = rooms[i]["grid_rect"]
			var r_j: Rect2i = rooms[j]["grid_rect"]

			# Check Vertical shared wall
			if r_i.end.x == r_j.position.x or r_j.end.x == r_i.position.x:
				var cut_x := r_i.end.x if r_i.end.x == r_j.position.x else r_j.end.x
				var y1 := maxi(r_i.position.y, r_j.position.y)
				var y2 := mini(r_i.end.y, r_j.end.y)
				if y2 - y1 >= DEFAULT_DOOR_OPENING_CELLS:
					boundaries.append({
						"room_a": i if r_i.position.x < r_j.position.x else j,
						"room_b": j if r_i.position.x < r_j.position.x else i,
						"axis": "V",
						"cut": cut_x,
						"span_start": y1,
						"span_end": y2,
					})

			# Check Horizontal shared wall
			if r_i.end.y == r_j.position.y or r_j.end.y == r_i.position.y:
				var cut_y := r_i.end.y if r_i.end.y == r_j.position.y else r_j.end.y
				var x1 := maxi(r_i.position.x, r_j.position.x)
				var x2 := mini(r_i.end.x, r_j.end.x)
				if x2 - x1 >= DEFAULT_DOOR_OPENING_CELLS:
					boundaries.append({
						"room_a": i if r_i.position.y < r_j.position.y else j,
						"room_b": j if r_i.position.y < r_j.position.y else i,
						"axis": "H",
						"cut": cut_y,
						"span_start": x1,
						"span_end": x2,
					})

	return boundaries


static func _find_free_spans(span_start: int, span_end: int, claimed_ranges: Array, min_len: int) -> Array[Vector2i]:
	var free_spans: Array[Vector2i] = []
	var sorted_claimed := claimed_ranges.duplicate()
	sorted_claimed.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x)

	var cursor := span_start + 1
	for r_var in sorted_claimed:
		var r: Vector2i = r_var
		var c_start := r.x - 1
		if c_start - cursor >= min_len:
			free_spans.append(Vector2i(cursor, c_start))
		cursor = maxi(cursor, r.y + 1)

	if (span_end - 1) - cursor >= min_len:
		free_spans.append(Vector2i(cursor, span_end - 1))

	return free_spans


static func _edge_key(edge: Dictionary) -> String:
	return "%s:%d:%d" % [edge["axis"], int(edge["x"]), int(edge["y"])]


static func _edge_from_inside(cell: Vector2i, direction: Vector2i) -> Dictionary:
	if direction == Vector2i.UP:
		return {"axis": "H", "x": cell.x, "y": cell.y}
	if direction == Vector2i.DOWN:
		return {"axis": "H", "x": cell.x, "y": cell.y + 1}
	if direction == Vector2i.LEFT:
		return {"axis": "V", "x": cell.x, "y": cell.y}
	return {"axis": "V", "x": cell.x + 1, "y": cell.y}


static func _edge_world_position(edge: Dictionary) -> Vector3:
	if String(edge["axis"]) == "H":
		return Vector3(float(edge["x"]), 0.0, float(edge["y"]) - 0.5)
	return Vector3(float(edge["x"]) - 0.5, 0.0, float(edge["y"]))
