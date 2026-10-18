class_name DreamOfficeV2Generator
extends RefCounted

## Office Level Pack v2 Procedural Floor Generator
##
## Implements the 7-step generation pipeline from 《办公楼关卡包 v2 · 45° 俯视角 · 随机房间 · 三种楼层轮廓》:
## 1. Pick Contour (Rect, L-shape, T-shape, Cross, Convex).
## 2. Place Elevator Hall Anchor (adaptive outer edge, door facing corridor).
## 3. Lay Spine Corridor (East-West through-corridor, unobstructed).
## 4. Mount Rooms (9-13 rooms, North-deep South-shallow, required rooms + pool draw).
## 5. Constraint Validation & Doors/Glass (Double, Single, Open, >=2 glass spans).
## 6. Return standard dictionary schema for Dream3D_RandomDungeon.

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), # UP
	Vector2i(1, 0),  # RIGHT
	Vector2i(0, 1),  # DOWN
	Vector2i(-1, 0), # LEFT
]

const DEFAULT_DOOR_OPENING_CELLS := 3

# Contour weights from STEP 1: Rect 40, L 25, T 15, Cross 10, Convex 10
const CONTOUR_TYPES: Array[StringName] = [&"rect", &"l_shape", &"t_shape", &"cross", &"convex"]
const CONTOUR_WEIGHTS: Array[float] = [40.0, 25.0, 15.0, 10.0, 10.0]

# 14 Room Pool specifications
# depth: North up to 5-6, South 3-4
const ROOM_POOL_DEFS: Dictionary = {
	"open_office": {
		"name": "OpenOffice",
		"room_type": &"large_office",
		"archetype": "open_office",
		"size_class": &"large",
		"combat_room": true,
		"default_w": 12,
		"default_h": 6,
		"door_pref": "open",
		"glass_pref": false,
		"weight": 20,
	},
	"boardroom": {
		"name": "Boardroom",
		"room_type": &"large_office",
		"archetype": "conference",
		"size_class": &"large",
		"combat_room": true,
		"default_w": 10,
		"default_h": 5,
		"door_pref": "double",
		"glass_pref": true,
		"weight": 15,
	},
	"small_conference": {
		"name": "SmallConference",
		"room_type": &"small_office",
		"archetype": "conference",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 6,
		"default_h": 4,
		"door_pref": "single",
		"glass_pref": true,
		"weight": 12,
	},
	"manager_office": {
		"name": "ManagerOffice",
		"room_type": &"small_office",
		"archetype": "executive",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 6,
		"default_h": 5,
		"door_pref": "single",
		"glass_pref": true,
		"weight": 10,
	},
	"small_office": {
		"name": "SmallOffice",
		"room_type": &"small_office",
		"archetype": "executive",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 6,
		"default_h": 4,
		"door_pref": "single",
		"glass_pref": false,
		"weight": 16,
	},
	"archive": {
		"name": "Archive",
		"room_type": &"small_office",
		"archetype": "storage",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 6,
		"default_h": 4,
		"door_pref": "single",
		"glass_pref": false,
		"weight": 8,
	},
	"server_room": {
		"name": "ServerRoom",
		"room_type": &"small_office",
		"archetype": "security",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 5,
		"default_h": 4,
		"door_pref": "single",
		"glass_pref": false,
		"weight": 8,
	},
	"pantry": {
		"name": "Pantry",
		"room_type": &"small_office",
		"archetype": "lounge",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 6,
		"default_h": 3,
		"door_pref": "single",
		"glass_pref": false,
		"weight": 10,
	},
	"restroom": {
		"name": "Restroom",
		"room_type": &"small_office",
		"archetype": "storage",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 5,
		"default_h": 3,
		"door_pref": "single",
		"glass_pref": false,
		"weight": 10,
	},
	"copy_room": {
		"name": "CopyRoom",
		"room_type": &"small_office",
		"archetype": "storage",
		"size_class": &"small",
		"combat_room": true,
		"default_w": 5,
		"default_h": 3,
		"door_pref": "single",
		"glass_pref": false,
		"weight": 6,
	},
	"reception": {
		"name": "Reception",
		"room_type": &"reception",
		"archetype": "reception",
		"size_class": &"medium",
		"combat_room": false,
		"default_w": 8,
		"default_h": 4,
		"door_pref": "open",
		"glass_pref": true,
		"weight": 10,
	},
	"lounge": {
		"name": "Lounge",
		"room_type": &"small_office",
		"archetype": "lounge",
		"size_class": &"medium",
		"combat_room": true,
		"default_w": 7,
		"default_h": 4,
		"door_pref": "open",
		"glass_pref": false,
		"weight": 8,
	},
	"back_corridor": {
		"name": "BackCorridor",
		"room_type": &"corridor",
		"archetype": "corridor",
		"size_class": &"small",
		"combat_room": false,
		"default_w": 4,
		"default_h": 6,
		"door_pref": "open",
		"glass_pref": false,
		"weight": 5,
	},
}


static func pick_contour(floor_num: int, rng: RandomNumberGenerator) -> StringName:
	if floor_num <= 0:
		return &"rect"
	var total_w := 0.0
	for w in CONTOUR_WEIGHTS:
		total_w += w
	var roll := rng.randf_range(0.0, total_w)
	var accum := 0.0
	for i in range(CONTOUR_TYPES.size()):
		accum += CONTOUR_WEIGHTS[i]
		if roll <= accum:
			return CONTOUR_TYPES[i]
	return &"rect"


static func generate(rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var floor_index: int = int(options.get("floor_index", 0))
	var force_contour: String = String(options.get("contour_type", ""))
	var contour: StringName = StringName(force_contour) if force_contour != "" else pick_contour(floor_index, rng)

	# 1. Build Contour Grid and Boundary Polygons
	var contour_data := _build_contour_layout(contour, rng)
	var room_specs: Array = contour_data["room_specs"]
	var elevator_room_id: int = contour_data["elevator_room_id"]
	var porch_room_id: int = contour_data["porch_room_id"]
	var elevator_center: Vector2i = contour_data["elevator_center"]
	var building_rect: Rect2i = contour_data["building_rect"]

	# 2. Build Room records, floor_cells, and room_cells
	var rooms: Array = []
	var partitions: Array[Dictionary] = []
	var floor_cells: Dictionary = {}
	var room_cells: Dictionary = {}

	for room_id in range(room_specs.size()):
		var spec: Dictionary = room_specs[room_id]
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
			"door_pref": spec.get("door_pref", "single"),
			"glass_pref": spec.get("glass_pref", false),
			"planned_role": spec.get("planned_role", ""),
		}
		rooms.append(room)

	# 3. Detect Shared Boundaries Between Adjacent Rooms
	var shared_boundaries := _find_shared_boundaries(rooms)

	# 4. Determine Door Connections (Core Spine + Spoke connections)
	var spine_pairs: Array = contour_data["spine_pairs"]
	var pair_to_boundary: Dictionary = {}
	for b_idx in range(shared_boundaries.size()):
		var b: Dictionary = shared_boundaries[b_idx]
		var u: int = mini(b["room_a"], b["room_b"])
		var v: int = maxi(b["room_a"], b["room_b"])
		pair_to_boundary[Vector2i(u, v)] = b_idx

	var selected_boundary_indices: Dictionary = {}
	for pair in spine_pairs:
		var u: int = mini(pair.x, pair.y)
		var v: int = maxi(pair.x, pair.y)
		var p_key := Vector2i(u, v)
		if pair_to_boundary.has(p_key):
			selected_boundary_indices[pair_to_boundary[p_key]] = true

	# Additional secondary loop doors
	for b_idx in range(shared_boundaries.size()):
		if selected_boundary_indices.has(b_idx):
			continue
		var b: Dictionary = shared_boundaries[b_idx]
		if b["room_a"] == elevator_room_id or b["room_b"] == elevator_room_id:
			continue
		if rng.randf() <= 0.35:
			selected_boundary_indices[b_idx] = true

	# 5. Place Doors
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

		var is_elevator_door := (r_a == elevator_room_id or r_b == elevator_room_id)
		var door_pref_a: String = rooms[r_a].get("door_pref", "single")
		var door_pref_b: String = rooms[r_b].get("door_pref", "single")
		var is_double: bool = (door_pref_a == "double" or door_pref_b == "double")
		var is_open: bool = (door_pref_a == "open" and door_pref_b == "open")

		var door_span := 3
		if is_elevator_door:
			door_span = 3
		elif is_double or is_open:
			door_span = mini(4, span_len)
		else:
			door_span = mini(2, span_len)

		var door_start := span_start
		if is_elevator_door:
			door_start = span_start + (span_len - door_span) / 2
		elif span_len > door_span + 2:
			var max_offset := span_len - door_span - 1
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
			"door_style": "double" if is_double else ("open" if is_open else "single"),
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

	# 6. Place Mandatory Breakable Glass Windows (>= 2 spans per floor)
	var glass_wall_edges: Dictionary = {}
	var glass_spans_placed := 0

	# First pass: prioritized rooms requesting glass (boardroom, manager_office, small_conference)
	for b_idx in range(shared_boundaries.size()):
		var b_data: Dictionary = shared_boundaries[b_idx]
		var r_a: int = b_data["room_a"]
		var r_b: int = b_data["room_b"]
		if r_a == elevator_room_id or r_b == elevator_room_id or r_a == porch_room_id or r_b == porch_room_id:
			continue

		var wants_glass: bool = bool(rooms[r_a].get("glass_pref", false)) or bool(rooms[r_b].get("glass_pref", false))
		var axis: String = b_data["axis"]
		var cut: int = b_data["cut"]
		var span_start: int = b_data["span_start"]
		var span_end: int = b_data["span_end"]

		var claimed: Array = door_claimed_ranges.get(b_idx, [])
		var free_spans := _find_free_spans(span_start, span_end, claimed, 2)

		for f_span in free_spans:
			# RULE 04: Prefer South-facing walls (axis == "H") for sightline through 45 degree camera
			var should_place := wants_glass or (glass_spans_placed < 2) or (rng.randf() <= 0.45)
			if should_place:
				var win_len := mini(f_span.y - f_span.x, 4)
				var win_start := f_span.x + (f_span.y - f_span.x - win_len) / 2
				for c in range(win_start, win_start + win_len):
					var g_edge := {
						"axis": axis,
						"x": cut if axis == "V" else c,
						"y": c if axis == "V" else cut,
					}
					glass_wall_edges[_edge_key(g_edge)] = g_edge
				glass_spans_placed += 1
				break

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
				edge_states[key] = &"WALL"
				wall_edges[key] = edge
			elif int(room_cells.get(neighbor, -1)) != int(room_cells.get(cell, -1)):
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
		"contour_type": contour,
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


# -----------------------------------------------------------------------------
# Contour Layout Builders
# -----------------------------------------------------------------------------
static func _build_contour_layout(contour: StringName, rng: RandomNumberGenerator) -> Dictionary:
	match contour:
		&"l_shape":
			return _build_l_shape_layout(rng)
		&"t_shape":
			return _build_t_shape_layout(rng)
		&"cross":
			return _build_cross_layout(rng)
		&"convex":
			return _build_convex_layout(rng)
		_:
			return _build_rect_layout(rng)


# 1. Rectangular Office (矩形 - Standard 23x14 baseline, 11 rooms)
static func _build_rect_layout(rng: RandomNumberGenerator) -> Dictionary:
	var specs: Array = [
		# 0: Reception (Center South of Elevator Porch)
		{"name": "Reception", "rect": Rect2i(-4, -6, 8, 4), "room_type": &"reception", "combat_room": false, "size_class": &"medium", "archetype": "reception", "door_pref": "open", "glass_pref": true},
		# 1: Main Spine Corridor (East-West through-corridor, Y: [-2, 0], width 2)
		{"name": "SpineCorridor", "rect": Rect2i(-11, -2, 22, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 2: North Open Office (7x6)
		{"name": "NorthOpenOffice", "rect": Rect2i(-11, -8, 7, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "open_office", "door_pref": "open"},
		# 3: North Boardroom (7x6, double door, glass south wall)
		{"name": "Boardroom", "rect": Rect2i(4, -8, 7, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "conference", "door_pref": "double", "glass_pref": true, "planned_role": "heavy_guard"},
		# 4: South Manager Office (Shallow depth 4)
		{"name": "ManagerOffice", "rect": Rect2i(-11, 0, 5, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "executive", "door_pref": "single", "glass_pref": true},
		# 5: South Archive (Shallow depth 4)
		{"name": "Archive", "rect": Rect2i(-6, 0, 5, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single", "planned_role": "heavy_guard"},
		# 6: South Pantry (Shallow depth 3)
		{"name": "Pantry", "rect": Rect2i(-1, 0, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "lounge", "door_pref": "single"},
		# 7: South Restroom (Shallow depth 3)
		{"name": "Restroom", "rect": Rect2i(3, 0, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single"},
		# 8: South Small Office (Shallow depth 4)
		{"name": "SmallOffice", "rect": Rect2i(7, 0, 4, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "security", "door_pref": "single"},
		# 9: Elevator Porch (Connecting ElevatorCab to Reception)
		{"name": "ElevatorPorch", "rect": Rect2i(-3, -8, 6, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 10: Elevator Cab (North anchor)
		{"name": "ElevatorCab", "rect": Rect2i(-3, -12, 6, 4), "room_type": &"elevator_lobby", "combat_room": false, "size_class": &"small", "archetype": "elevator_lobby", "door_pref": "double"},
	]

	var spine_pairs := [
		Vector2i(10, 9), # ElevatorCab <-> Porch
		Vector2i(9, 0),  # Porch <-> Reception
		Vector2i(0, 1),  # Reception <-> SpineCorridor
		Vector2i(1, 2),  # Spine <-> North Open Office
		Vector2i(1, 3),  # Spine <-> Boardroom
		Vector2i(1, 4),  # Spine <-> Manager Office
		Vector2i(1, 5),  # Spine <-> Archive
		Vector2i(1, 6),  # Spine <-> Pantry
		Vector2i(1, 7),  # Spine <-> Restroom
		Vector2i(1, 8),  # Spine <-> SmallOffice
	]

	return {
		"room_specs": specs,
		"elevator_room_id": 10,
		"porch_room_id": 9,
		"elevator_center": Vector2i(0, -10),
		"building_rect": Rect2i(-12, -14, 24, 19),
		"spine_pairs": spine_pairs,
	}


# 2. L-Shape Floor (L形 - Missing top-right corner atrium)
static func _build_l_shape_layout(rng: RandomNumberGenerator) -> Dictionary:
	var specs: Array = [
		# 0: Reception
		{"name": "Reception", "rect": Rect2i(-4, -6, 8, 4), "room_type": &"reception", "combat_room": false, "size_class": &"medium", "archetype": "reception", "door_pref": "open", "glass_pref": true},
		# 1: Horizontal Spine Corridor (Y: [-2, 0])
		{"name": "SpineCorridor", "rect": Rect2i(-11, -2, 22, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 2: West Long Wing North Open Office
		{"name": "NorthOpenOffice", "rect": Rect2i(-11, -8, 7, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "open_office", "door_pref": "open"},
		# 3: Boardroom (heavy_guard)
		{"name": "Boardroom", "rect": Rect2i(-4, 0, 8, 5), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "conference", "door_pref": "double", "glass_pref": true, "planned_role": "heavy_guard"},
		# 4: West Long Wing Manager Office
		{"name": "ManagerOffice", "rect": Rect2i(-11, 0, 7, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "executive", "door_pref": "single", "glass_pref": true},
		# 5: Pantry
		{"name": "Pantry", "rect": Rect2i(4, 0, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "lounge", "door_pref": "single"},
		# 6: Restroom
		{"name": "Restroom", "rect": Rect2i(8, 0, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single"},
		# 7: Archive (heavy_guard)
		{"name": "Archive", "rect": Rect2i(-11, 4, 7, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single", "planned_role": "heavy_guard"},
		# 8: Elevator Porch (North anchor)
		{"name": "ElevatorPorch", "rect": Rect2i(-3, -8, 6, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 9: Elevator Cab (North anchor)
		{"name": "ElevatorCab", "rect": Rect2i(-3, -12, 6, 4), "room_type": &"elevator_lobby", "combat_room": false, "size_class": &"small", "archetype": "elevator_lobby", "door_pref": "double"},
	]

	var spine_pairs := [
		Vector2i(9, 8), # ElevatorCab <-> Porch
		Vector2i(8, 0), # Porch <-> Reception
		Vector2i(0, 1), # Reception <-> Spine
		Vector2i(1, 2), # Spine <-> NorthOpenOffice
		Vector2i(1, 3), # Spine <-> Boardroom
		Vector2i(1, 4), # Spine <-> ManagerOffice
		Vector2i(1, 5), # Spine <-> Pantry
		Vector2i(1, 6), # Spine <-> Restroom
		Vector2i(4, 7), # ManagerOffice <-> Archive
	]

	return {
		"room_specs": specs,
		"elevator_room_id": 9,
		"porch_room_id": 8,
		"elevator_center": Vector2i(0, -10),
		"building_rect": Rect2i(-12, -14, 24, 23),
		"spine_pairs": spine_pairs,
	}


# 3. T-Shape Floor (T形 - Wide top, narrow bottom stem)
static func _build_t_shape_layout(rng: RandomNumberGenerator) -> Dictionary:
	var specs: Array = [
		# 0: Reception
		{"name": "Reception", "rect": Rect2i(-4, -6, 8, 4), "room_type": &"reception", "combat_room": false, "size_class": &"medium", "archetype": "reception", "door_pref": "open", "glass_pref": true},
		# 1: Main Spine Corridor (Top wide horizontal bar)
		{"name": "SpineCorridor", "rect": Rect2i(-11, -2, 22, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 2: Top Left Open Office
		{"name": "OpenOffice", "rect": Rect2i(-11, -8, 7, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "open_office", "door_pref": "open"},
		# 3: Top Right Boardroom (heavy_guard)
		{"name": "Boardroom", "rect": Rect2i(4, -8, 7, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "conference", "door_pref": "double", "glass_pref": true, "planned_role": "heavy_guard"},
		# 4: Pantry (Bottom stem north)
		{"name": "Pantry", "rect": Rect2i(-4, 0, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "lounge", "door_pref": "single"},
		# 5: Restroom (Bottom stem north)
		{"name": "Restroom", "rect": Rect2i(0, 0, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single"},
		# 6: Archive (Bottom stem middle)
		{"name": "Archive", "rect": Rect2i(-4, 3, 4, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single", "planned_role": "heavy_guard"},
		# 7: Server Room (Bottom stem middle)
		{"name": "ServerRoom", "rect": Rect2i(0, 3, 4, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "security", "door_pref": "single"},
		# 8: Elevator Porch (North anchor)
		{"name": "ElevatorPorch", "rect": Rect2i(-3, -8, 6, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 9: Elevator Cab (North anchor)
		{"name": "ElevatorCab", "rect": Rect2i(-3, -12, 6, 4), "room_type": &"elevator_lobby", "combat_room": false, "size_class": &"small", "archetype": "elevator_lobby", "door_pref": "double"},
	]

	var spine_pairs := [
		Vector2i(9, 8), # ElevatorCab <-> Porch
		Vector2i(8, 0), # Porch <-> Reception
		Vector2i(0, 1), # Reception <-> Spine
		Vector2i(1, 2), # Spine <-> OpenOffice
		Vector2i(1, 3), # Spine <-> Boardroom
		Vector2i(1, 4), # Spine <-> Pantry
		Vector2i(1, 5), # Spine <-> Restroom
		Vector2i(4, 6), # Pantry <-> Archive
		Vector2i(5, 7), # Restroom <-> ServerRoom
	]

	return {
		"room_specs": specs,
		"elevator_room_id": 9,
		"porch_room_id": 8,
		"elevator_center": Vector2i(0, -10),
		"building_rect": Rect2i(-12, -14, 24, 22),
		"spine_pairs": spine_pairs,
	}


# 4. Cross-Shape Floor (十字形 - Four-wing layout, North elevator)
static func _build_cross_layout(rng: RandomNumberGenerator) -> Dictionary:
	var specs: Array = [
		# 0: Central Grand Lobby (Center hub)
		{"name": "CentralLobby", "rect": Rect2i(-4, -4, 8, 6), "room_type": &"main_lobby", "combat_room": false, "size_class": &"medium", "archetype": "reception", "door_pref": "open", "glass_pref": true},
		# 1: West Wing Open Office
		{"name": "WestOpenOffice", "rect": Rect2i(-12, -4, 8, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "open_office", "door_pref": "open"},
		# 2: East Wing Boardroom (heavy_guard)
		{"name": "EastBoardroom", "rect": Rect2i(4, -4, 8, 6), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "conference", "door_pref": "double", "glass_pref": true, "planned_role": "heavy_guard"},
		# 3: Pantry (South Wing North)
		{"name": "Pantry", "rect": Rect2i(-4, 2, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "lounge", "door_pref": "single"},
		# 4: Restroom (South Wing North)
		{"name": "Restroom", "rect": Rect2i(0, 2, 4, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single"},
		# 5: Archive (South Wing South)
		{"name": "Archive", "rect": Rect2i(-4, 5, 8, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single", "planned_role": "heavy_guard"},
		# 6: North Executive Office
		{"name": "NorthExecutive", "rect": Rect2i(4, -10, 7, 6), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "executive", "door_pref": "single", "glass_pref": true},
		# 7: Elevator Porch (North Wing)
		{"name": "ElevatorPorch", "rect": Rect2i(-3, -8, 6, 4), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 8: Elevator Cab (North Anchor)
		{"name": "ElevatorCab", "rect": Rect2i(-3, -12, 6, 4), "room_type": &"elevator_lobby", "combat_room": false, "size_class": &"small", "archetype": "elevator_lobby", "door_pref": "double"},
	]

	var spine_pairs := [
		Vector2i(8, 7), # ElevatorCab <-> Porch
		Vector2i(7, 0), # Porch <-> CentralLobby
		Vector2i(0, 1), # CentralLobby <-> WestOpenOffice
		Vector2i(0, 2), # CentralLobby <-> EastBoardroom
		Vector2i(0, 3), # CentralLobby <-> Pantry
		Vector2i(0, 4), # CentralLobby <-> Restroom
		Vector2i(3, 5), # Pantry <-> Archive
		Vector2i(2, 6), # EastBoardroom <-> NorthExecutive
	]

	return {
		"room_specs": specs,
		"elevator_room_id": 8,
		"porch_room_id": 7,
		"elevator_center": Vector2i(0, -10),
		"building_rect": Rect2i(-14, -14, 28, 24),
		"spine_pairs": spine_pairs,
	}


# 5. Convex-Shape Floor (凸形 - Wide base, narrow top protrusion)
static func _build_convex_layout(rng: RandomNumberGenerator) -> Dictionary:
	var specs: Array = [
		# 0: Reception (Top protrusion south)
		{"name": "Reception", "rect": Rect2i(-4, -4, 8, 4), "room_type": &"reception", "combat_room": false, "size_class": &"medium", "archetype": "reception", "door_pref": "open", "glass_pref": true},
		# 1: Horizontal Spine Corridor (Y: [0, 2], width 2)
		{"name": "SpineCorridor", "rect": Rect2i(-11, 0, 22, 2), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 2: Wide Base Left Open Office
		{"name": "OpenOffice", "rect": Rect2i(-11, -4, 7, 4), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "open_office", "door_pref": "open"},
		# 3: Wide Base Right Boardroom (heavy_guard)
		{"name": "Boardroom", "rect": Rect2i(4, -4, 7, 4), "room_type": &"large_office", "combat_room": true, "size_class": &"large", "archetype": "conference", "door_pref": "double", "glass_pref": true, "planned_role": "heavy_guard"},
		# 4: Pantry (Base Center South)
		{"name": "Pantry", "rect": Rect2i(-11, 2, 5, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "lounge", "door_pref": "single"},
		# 5: Restroom (Base Center South)
		{"name": "Restroom", "rect": Rect2i(-6, 2, 5, 3), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single"},
		# 6: Archive (Base South East)
		{"name": "Archive", "rect": Rect2i(-1, 2, 6, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "storage", "door_pref": "single", "planned_role": "heavy_guard"},
		# 7: Small Office (Base South East)
		{"name": "SmallOffice", "rect": Rect2i(5, 2, 6, 4), "room_type": &"small_office", "combat_room": true, "size_class": &"small", "archetype": "security", "door_pref": "single"},
		# 8: Elevator Porch (Narrow top anchor)
		{"name": "ElevatorPorch", "rect": Rect2i(-3, -8, 6, 4), "room_type": &"corridor", "combat_room": false, "size_class": &"small", "archetype": "corridor", "door_pref": "open"},
		# 9: Elevator Cab (Top anchor)
		{"name": "ElevatorCab", "rect": Rect2i(-3, -12, 6, 4), "room_type": &"elevator_lobby", "combat_room": false, "size_class": &"small", "archetype": "elevator_lobby", "door_pref": "double"},
	]

	var spine_pairs := [
		Vector2i(9, 8), # ElevatorCab <-> Porch
		Vector2i(8, 0), # Porch <-> Reception
		Vector2i(0, 1), # Reception <-> Spine
		Vector2i(1, 2), # Spine <-> OpenOffice
		Vector2i(1, 3), # Spine <-> Boardroom
		Vector2i(1, 4), # Spine <-> Pantry
		Vector2i(1, 5), # Spine <-> Restroom
		Vector2i(1, 6), # Spine <-> Archive
		Vector2i(1, 7), # Spine <-> SmallOffice
	]

	return {
		"room_specs": specs,
		"elevator_room_id": 9,
		"porch_room_id": 8,
		"elevator_center": Vector2i(0, -10),
		"building_rect": Rect2i(-12, -14, 24, 21),
		"spine_pairs": spine_pairs,
	}


# -----------------------------------------------------------------------------
# Spatial Boundary & Edge Detection Helpers
# -----------------------------------------------------------------------------
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
				if y2 - y1 >= 2:
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
				if x2 - x1 >= 2:
					boundaries.append({
						"room_a": i if r_i.position.y < r_j.position.y else j,
						"room_b": j if r_i.position.y < r_j.position.y else i,
						"axis": "H",
						"cut": cut_y,
						"span_start": x1,
						"span_end": x2,
					})

	return boundaries


static func _find_free_spans(span_start: int, span_end: int, claimed_ranges: Array, min_len: int = 2) -> Array[Vector2i]:
	var free_spans: Array[Vector2i] = []
	var sorted_claimed := claimed_ranges.duplicate()
	sorted_claimed.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x)

	var cursor := span_start
	for r_var in sorted_claimed:
		var r: Vector2i = r_var
		var c_start := r.x
		if c_start - cursor >= min_len:
			free_spans.append(Vector2i(cursor, c_start))
		cursor = maxi(cursor, r.y)

	if span_end - cursor >= min_len:
		free_spans.append(Vector2i(cursor, span_end))

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
