class_name DreamMacroRoomGraph
extends RefCounted

## Deterministic macro topology for 3D Random Dream.
##
## This generator deliberately does not partition one contiguous office slab.
## It first creates a graph of macro room nodes, places each room on a sparse
## macro grid, then routes an independent corridor between each graph edge.
## The returned dictionaries use the existing gameplay-cell contract so the
## wall, floor, door, collision and pathfinding systems can remain shared.

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]
const MACRO_LIMIT := 3
# Keep one or two free cells between the largest (22-cell) room tiers while
# making the room graph visibly tighter than the original 26-cell spacing.
const DEFAULT_MACRO_PITCH := 24
const DEFAULT_ROOM_MAX_WIDTH := 16
const DEFAULT_ROOM_MAX_HEIGHT := 16
const DEFAULT_MEDIUM_MIN_WIDTH := 16
const DEFAULT_MEDIUM_MIN_HEIGHT := 16
const DEFAULT_MEDIUM_MAX_WIDTH := 20
const DEFAULT_MEDIUM_MAX_HEIGHT := 20
const DEFAULT_LARGE_MIN_WIDTH := 20
const DEFAULT_LARGE_MIN_HEIGHT := 20
const DEFAULT_LARGE_MAX_WIDTH := 22
const DEFAULT_LARGE_MAX_HEIGHT := 22
const DEFAULT_ROOM_MIN_RING := 3


static func generate(rng: RandomNumberGenerator, options: Dictionary) -> Dictionary:
	var requested_count := maxi(3, int(options.get("room_count", 12)))
	var generation_bounds: Rect2i = options.get("generation_bounds", Rect2i(-96, -76, 192, 152))
	var attempts := maxi(1, int(options.get("max_attempts", 40)))
	var profile := {
		"attempts": 0,
		"macro_graph_empty": 0,
		"cell_layout_empty": 0,
		"validation_rejects": 0,
		"success": false,
	}
	for _attempt in range(attempts):
		profile["attempts"] = int(profile["attempts"]) + 1
		var macro_data := _build_macro_graph(rng, requested_count, options)
		if macro_data.is_empty():
			profile["macro_graph_empty"] = int(profile["macro_graph_empty"]) + 1
			continue
		var layout := _build_cell_layout(rng, macro_data, generation_bounds, options)
		if layout.is_empty():
			profile["cell_layout_empty"] = int(profile["cell_layout_empty"]) + 1
			continue
		if _validate_layout(layout, generation_bounds, options):
			profile["success"] = true
			var success_sink_variant: Variant = options.get("startup_profile_sink", null)
			if success_sink_variant is Callable:
				success_sink_variant.call(profile)
			return layout
		profile["validation_rejects"] = int(profile["validation_rejects"]) + 1
	var failure_sink_variant: Variant = options.get("startup_profile_sink", null)
	if failure_sink_variant is Callable:
		failure_sink_variant.call(profile)
	return {}


static func _build_macro_graph(rng: RandomNumberGenerator, requested_count: int, options: Dictionary = {}) -> Dictionary:
	var coords: Array[Vector2i] = [Vector2i.ZERO]
	var occupied: Dictionary = {Vector2i.ZERO: true}
	var parent_by_coord: Dictionary = {}
	while coords.size() < requested_count:
		var frontier: Array[Vector2i] = []
		for coord in coords:
			for direction in CARDINAL_DIRECTIONS:
				var candidate := coord + direction
				if absi(candidate.x) > MACRO_LIMIT or absi(candidate.y) > MACRO_LIMIT:
					continue
				if occupied.has(candidate) or frontier.has(candidate):
					continue
				frontier.append(candidate)
		if frontier.is_empty():
			return {}
		# Prefer a varied frontier, while slightly favouring positions that keep
		# the graph compact. The tree remains connected regardless of the choice.
		var selected := frontier[rng.randi_range(0, frontier.size() - 1)]
		var best_score := -1000000
		for candidate in frontier:
			var adjacent_count := 0
			for direction in CARDINAL_DIRECTIONS:
				if occupied.has(candidate + direction):
					adjacent_count += 1
			var score := adjacent_count * 20 - absi(candidate.x) - absi(candidate.y)
			if rng.randf() < 0.28:
				score += rng.randi_range(0, 12)
			if score > best_score:
				best_score = score
				selected = candidate
		coords.append(selected)
		occupied[selected] = true
		# Pick one deterministic parent from the already occupied neighbours.
		var parent_candidates: Array[Vector2i] = []
		for direction in CARDINAL_DIRECTIONS:
			if occupied.has(selected - direction) and selected - direction != selected:
				parent_candidates.append(selected - direction)
		if parent_candidates.is_empty():
			return {}
		parent_by_coord[selected] = parent_candidates[rng.randi_range(0, parent_candidates.size() - 1)]

	var edges: Array[Dictionary] = []
	var edge_pairs: Dictionary = {}
	for coord in coords:
		if not parent_by_coord.has(coord):
			continue
		var parent: Vector2i = parent_by_coord[coord]
		_add_macro_edge(edges, edge_pairs, coords.find(parent), coords.find(coord), parent, coord)

	# A small number of extra adjacent links creates loops without turning the
	# macro map into a dense mesh of junctions. Every loop is optional.
	var loop_candidates: Array[Dictionary] = []
	for first_index in range(coords.size()):
		for second_index in range(first_index + 1, coords.size()):
			var delta: Vector2i = coords[second_index] - coords[first_index]
			if absi(delta.x) + absi(delta.y) != 1:
				continue
			var key := _macro_pair_key(first_index, second_index)
			if edge_pairs.has(key):
				continue
			loop_candidates.append({"a": first_index, "b": second_index, "a_coord": coords[first_index], "b_coord": coords[second_index]})
	# Do not use Array.shuffle() here: it uses the global RNG and breaks seed
	# reproducibility. Shuffle with the generator supplied by the caller.
	for index in range(loop_candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap_value: Dictionary = loop_candidates[index]
		loop_candidates[index] = loop_candidates[swap_index]
		loop_candidates[swap_index] = swap_value
	var loop_limit := mini(int(options.get("macro_max_loops", 2)), loop_candidates.size())
	for candidate in loop_candidates:
		if edges.size() >= requested_count - 1 + loop_limit:
			break
		if rng.randf() > 0.30:
			continue
		_add_macro_edge(edges, edge_pairs, int(candidate.a), int(candidate.b), candidate.a_coord, candidate.b_coord)
	return {"coords": coords, "edges": edges}


static func _add_macro_edge(
	edges: Array[Dictionary],
	edge_pairs: Dictionary,
	a_index: int,
	b_index: int,
	a_coord: Vector2i,
	b_coord: Vector2i
) -> void:
	var key := _macro_pair_key(a_index, b_index)
	if edge_pairs.has(key):
		return
	edge_pairs[key] = true
	edges.append({
		"a": a_index,
		"b": b_index,
		"a_coord": a_coord,
		"b_coord": b_coord,
	})


static func _build_cell_layout(
	rng: RandomNumberGenerator,
	macro_data: Dictionary,
	generation_bounds: Rect2i,
	options: Dictionary
) -> Dictionary:
	var coords: Array[Vector2i] = macro_data.get("coords", [])
	var macro_edges: Array[Dictionary] = macro_data.get("edges", [])
	if coords.is_empty() or macro_edges.size() < coords.size() - 1:
		return {}
	var macro_pitch := maxi(14, int(options.get("macro_pitch", DEFAULT_MACRO_PITCH)))
	var min_width := maxi(4, int(options.get("min_room_width", 10)))
	var min_height := maxi(4, int(options.get("min_room_height", 10)))
	# Small keeps the shipped 10..16 cell range. Medium/Large are independent
	# authored tiers so a room is not merely a scaled copy of the old prototype.
	var small_max_width := maxi(min_width, int(options.get("small_room_max_width", options.get("macro_room_max_width", DEFAULT_ROOM_MAX_WIDTH))))
	var small_max_height := maxi(min_height, int(options.get("small_room_max_height", options.get("macro_room_max_height", DEFAULT_ROOM_MAX_HEIGHT))))
	var medium_min_width := maxi(min_width, int(options.get("medium_room_min_width", DEFAULT_MEDIUM_MIN_WIDTH)))
	var medium_min_height := maxi(min_height, int(options.get("medium_room_min_height", DEFAULT_MEDIUM_MIN_HEIGHT)))
	var medium_max_width := maxi(medium_min_width, int(options.get("medium_room_max_width", DEFAULT_MEDIUM_MAX_WIDTH)))
	var medium_max_height := maxi(medium_min_height, int(options.get("medium_room_max_height", DEFAULT_MEDIUM_MAX_HEIGHT)))
	var large_min_width := maxi(medium_min_width, int(options.get("large_room_min_width", DEFAULT_LARGE_MIN_WIDTH)))
	var large_min_height := maxi(medium_min_height, int(options.get("large_room_min_height", DEFAULT_LARGE_MIN_HEIGHT)))
	var large_max_width := maxi(large_min_width, int(options.get("large_room_max_width", DEFAULT_LARGE_MAX_WIDTH)))
	var large_max_height := maxi(large_min_height, int(options.get("large_room_max_height", DEFAULT_LARGE_MAX_HEIGHT)))
	var corridor_width: int = maxi(2, int(options.get("corridor_width", 4)))
	var opening_cells: int = maxi(1, int(options.get("door_opening_cells", 4)))
	var door_corner_clearance := maxi(1, int(options.get("door_corner_clearance", 3)))

	var rooms: Array[Dictionary] = []
	var room_cells: Dictionary = {}
	var floor_cells: Dictionary = {}
	var corridor_cells: Dictionary = {}
	var corridors: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var door_edges: Dictionary = {}
	var door_opening_edges: Dictionary = {}
	var open_edge_keys: Dictionary = {}
	var next_door_id := 0

	for room_id in range(coords.size()):
		var size_class := _choose_size_class(rng, options)
		var width := small_max_width
		var height := small_max_height
		match size_class:
			&"medium":
				width = _random_even_size(rng, medium_min_width, medium_max_width)
				height = _random_even_size(rng, medium_min_height, medium_max_height)
			&"large":
				width = _random_even_size(rng, large_min_width, large_max_width)
				height = _random_even_size(rng, large_min_height, large_max_height)
			_:
				width = _random_even_size(rng, min_width, small_max_width)
				height = _random_even_size(rng, min_height, small_max_height)
		var center := coords[room_id] * macro_pitch
		var rect := Rect2i(center - Vector2i(width / 2, height / 2), Vector2i(width, height))
		var shape := _choose_shape(rng, options, size_class)
		var shape_cells := _shape_cells(rect, shape, rng)
		if shape_cells.is_empty():
			return {}
		var representative_cell := _representative_cell(shape_cells, rect)
		var room: Dictionary = {
			"id": room_id,
			"grid_rect": rect,
			# The geometric center may be the void of a hollow/irregular room.
			# Keep a guaranteed walkable representative for graph/path validation.
			"center_cell": representative_cell,
			"geometric_center_cell": center,
			"macro_coord": coords[room_id],
			"shape": shape,
			"size_class": size_class,
			"shape_cells": shape_cells.duplicate(),
			"usable_cells": [],
			"connections": [],
			"neighbors": [],
			"room_type": &"normal",
			"state": &"UNSEEN",
			"revealed": false,
			"activated": false,
			"cleared": false,
		}
		var usable: Array[Vector2i] = []
		for cell in shape_cells:
			room_cells[cell] = room_id
			floor_cells[cell] = &"room"
			if rect.grow(-2).has_point(cell):
				usable.append(cell)
		room["usable_cells"] = usable if not usable.is_empty() else shape_cells.duplicate()
		rooms.append(room)

	for graph_edge in macro_edges:
		var a_id := int(graph_edge.get("a", -1))
		var b_id := int(graph_edge.get("b", -1))
		if a_id < 0 or b_id < 0 or a_id >= rooms.size() or b_id >= rooms.size():
			return {}
		var a_room: Dictionary = rooms[a_id]
		var b_room: Dictionary = rooms[b_id]
		var direction: Vector2i = b_room["macro_coord"] - a_room["macro_coord"]
		if absi(direction.x) + absi(direction.y) != 1:
			return {}
		var opening_profile_a := _find_boundary_profile(a_room, direction, opening_cells, door_corner_clearance)
		# Straight corridors require the two complete doorway profiles to share
		# one tangent coordinate. Select the far profile on that exact axis;
		# otherwise this candidate layout is rejected and the outer generator
		# retries with a different room graph/shape combination.
		var tangent_start_a := _profile_tangent_start(opening_profile_a, direction)
		var opening_profile_b := _find_boundary_profile(
			b_room,
			-direction,
			opening_cells,
			door_corner_clearance,
			0,
			tangent_start_a
		)
		if opening_profile_a.is_empty() or opening_profile_b.is_empty():
			return {}
		var opening_start_a: Vector2i = opening_profile_a["start_cell"]
		var terminal_profile_a: Array[Vector2i] = _shift_profile(opening_profile_a["cells"], direction)
		var terminal_profile_b: Array[Vector2i] = _shift_profile(opening_profile_b["cells"], -direction)
		var corridor_id := corridors.size()
		var corridor: Dictionary = {
			"id": corridor_id,
			"room_a": a_id,
			"room_b": b_id,
			"direction": direction,
			"macro_a": a_room["macro_coord"],
			"macro_b": b_room["macro_coord"],
			"cells": [],
			# Keep the explicit cell-unit name as the topology authority.  `width`
			# remains as a compatibility alias for older diagnostics.
			"width_cells": corridor_width,
			"width": corridor_width,
			"opening_cells": opening_cells,
			"shoulder_cells_each_side": maxi(0, int((corridor_width - opening_cells) / 2)),
			"kind": &"straight",
			"state": &"UNSEEN",
			"revealed": false,
		}
		# Route from the complete four-cell terminal profiles.  The terminal is the
		# opening profile translated by one cell into the corridor; a single anchor
		# is deliberately not used as a width/centre authority.
		var route: Dictionary = _route_cardinal_corridor(opening_profile_a, opening_profile_b, direction, corridor_width)
		var routed_cells: Array = route.get("cells", [])
		corridor["kind"] = route.get("kind", &"straight")
		corridor["opening_profile_a"] = opening_profile_a["cells"].duplicate()
		corridor["opening_profile_b"] = opening_profile_b["cells"].duplicate()
		corridor["terminal_profile_a"] = terminal_profile_a.duplicate()
		corridor["terminal_profile_b"] = terminal_profile_b.duplicate()
		if routed_cells.is_empty():
			return {}
		for cell in routed_cells:
			if room_cells.has(cell):
				return {}
			corridor["cells"].append(cell)
			corridor_cells[cell] = corridor_id
			floor_cells[cell] = &"corridor"
		corridors.append(corridor)

		var opening_start: Vector2i = opening_profile_a["start_cell"]
		var door_edge := _edge_from_inside(opening_start, direction)
		var door_key := _edge_key(door_edge)
		var opening_keys: Array[String] = []
		for offset in range(opening_cells):
			var coordinate_cell: Vector2i = opening_profile_a["cells"][offset]
			var opening_edge := _edge_from_inside(coordinate_cell, direction)
			var opening_key := _edge_key(opening_edge)
			if offset > 0:
				opening_keys.append(opening_key)
				door_opening_edges[opening_key] = door_edge
		# The far end is an open Room->Corridor threshold. This keeps one physical
		# Door per graph connection, matching the current transit API while the
		# corridor remains a separate region in gameplay.
		var far_opening_start: Vector2i = opening_profile_b["start_cell"]
		for offset in range(opening_cells):
			var far_cell: Vector2i = opening_profile_b["cells"][offset]
			open_edge_keys[_edge_key(_edge_from_inside(far_cell, -direction))] = true

		var connection_id := connections.size()
		var door_data_a := {
			"inside_cell": opening_start,
			"outside_cell": opening_start + direction,
			"outward": direction,
			"room_id": a_id,
			"opening_cells": opening_cells,
			"opening_width_cells": opening_cells,
			"opening_profile": opening_profile_a["cells"].duplicate(),
			"opening_start_cell": opening_profile_a["start_cell"],
			"opening_end_cell": opening_profile_a["end_cell"],
			"opening_tangent": opening_profile_a["tangent"],
			"opening_normal": opening_profile_a["normal"],
			"opening_start": int(opening_start.y if direction.x != 0 else opening_start.x),
			"opening_end": int(opening_start.y if direction.x != 0 else opening_start.x) + opening_cells,
			"terminal_profile": terminal_profile_a.duplicate(),
			"corridor_width_cells": corridor_width,
			"shoulder_cells_each_side": maxi(0, int((corridor_width - opening_cells) / 2)),
		}
		var door_data_b := {
			"inside_cell": far_opening_start,
			"outside_cell": far_opening_start - direction,
			"outward": -direction,
			"room_id": b_id,
			"opening_cells": opening_cells,
			"opening_width_cells": opening_cells,
			"opening_profile": opening_profile_b["cells"].duplicate(),
			"opening_start_cell": opening_profile_b["start_cell"],
			"opening_end_cell": opening_profile_b["end_cell"],
			"opening_tangent": opening_profile_b["tangent"],
			"opening_normal": opening_profile_b["normal"],
			"opening_start": int(far_opening_start.y if direction.x != 0 else far_opening_start.x),
			"opening_end": int(far_opening_start.y if direction.x != 0 else far_opening_start.x) + opening_cells,
			"terminal_profile": terminal_profile_b.duplicate(),
			"corridor_width_cells": corridor_width,
			"shoulder_cells_each_side": maxi(0, int((corridor_width - opening_cells) / 2)),
		}
		connections.append({
			"id": connection_id,
			"door_id": next_door_id,
			"a": a_id,
			"b": b_id,
			"length": _manhattan(a_room["center_cell"], b_room["center_cell"]) + routed_cells.size(),
			"door_a": door_data_a,
			"door_b": door_data_b,
			"opening_profile_a": opening_profile_a["cells"].duplicate(),
			"opening_profile_b": opening_profile_b["cells"].duplicate(),
			"terminal_profile_a": terminal_profile_a.duplicate(),
			"terminal_profile_b": terminal_profile_b.duplicate(),
			"opening_width_cells": opening_cells,
			"corridor_id": corridor_id,
			"corridor_width_cells": corridor_width,
			"door_throat_width_cells": opening_cells,
			"shoulder_cells_each_side": maxi(0, int((corridor_width - opening_cells) / 2)),
			"door_count": 1,
		})
		_add_room_link(rooms, a_id, b_id)
		_add_room_link(rooms, b_id, a_id)
		var boundary_length := int(a_room["grid_rect"].size.y if direction.x != 0 else a_room["grid_rect"].size.x)
		door_edge.merge({
			"connection_id": connection_id,
			"door_id": next_door_id,
			"region_a_id": a_id,
			"region_b_id": b_id,
			"corridor_id": corridor_id,
			"boundary_room_id": a_id,
			"kind": &"room_corridor",
			"door_direction": &"V" if direction.x != 0 else &"H",
			"outward": direction,
			"hinge_side": "left" if posmod(next_door_id + a_id, 2) == 0 else "right",
			"shared_boundary_length": boundary_length,
			"opening_cells": opening_cells,
			"opening_width_cells": opening_cells,
			"opening_profile": opening_profile_a["cells"].duplicate(),
			"opening_start_cell": opening_profile_a["start_cell"],
			"opening_end_cell": opening_profile_a["end_cell"],
			"opening_tangent": opening_profile_a["tangent"],
			"opening_normal": opening_profile_a["normal"],
			"terminal_profile": terminal_profile_a.duplicate(),
			"opening_start": int(opening_start.y if direction.x != 0 else opening_start.x),
			"opening_end": int(opening_start.y if direction.x != 0 else opening_start.x) + opening_cells,
			"corridor_width_cells": corridor_width,
			"door_throat_width_cells": opening_cells,
			"shoulder_cells_each_side": maxi(0, int((corridor_width - opening_cells) / 2)),
			"opening_keys": opening_keys,
			"door_edge": door_edge.duplicate(true),
			"wall_edge": door_edge.duplicate(true),
			"door_position": _edge_world_position(door_edge),
			"corner_clearance_valid": _door_clearance_valid(a_room, opening_start, direction, opening_cells, door_corner_clearance),
			"macro_edge": graph_edge.duplicate(true),
		})
		door_edges[door_key] = door_edge
		next_door_id += 1

	var all_floor_rect := _bounds_for_cells(floor_cells.keys())
	if all_floor_rect.size == Vector2i.ZERO:
		return {}
	var building_rect := all_floor_rect.grow(2)
	var spawn_room: Dictionary = rooms[0]
	var entrance := _make_sealed_entrance(spawn_room, macro_data, rng)
	if entrance.is_empty():
		return {}
	var edge_states: Dictionary = {}
	var wall_edges: Dictionary = {}
	# Build all room and corridor boundaries from the final Floor Cell topology.
	# No BSP cut is consulted here; every empty gap is genuinely outside a room.
	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		for direction_cell in CARDINAL_DIRECTIONS:
			var neighbor := cell + direction_cell
			if floor_cells.has(neighbor):
				continue
			var edge := _edge_from_inside(cell, direction_cell)
			var key := _edge_key(edge)
			if door_edges.has(key):
				edge_states[key] = &"DOOR"
			elif door_opening_edges.has(key):
				edge_states[key] = &"DOOR_OPENING"
			elif open_edge_keys.has(key):
				edge_states[key] = &"OPEN"
			else:
				edge_states[key] = &"WALL"
				wall_edges[key] = edge
	for key_variant in door_opening_edges.keys():
		var key: String = key_variant
		if not edge_states.has(key):
			edge_states[key] = &"DOOR_OPENING"
	for key_variant in open_edge_keys.keys():
		var key: String = key_variant
		if not edge_states.has(key):
			edge_states[key] = &"OPEN"

	return {
		"building_rect": building_rect,
		"rooms": rooms,
		"partitions": [],
		"corridors": corridors,
		"connections": connections,
		"floor_cells": floor_cells,
		"room_cells": room_cells,
		"corridor_cells": corridor_cells,
		"wall_edges": wall_edges,
		"door_edges": door_edges,
		"door_opening_edges": door_opening_edges,
		"edge_states": edge_states,
		"spawn_room_id": 0,
		"spawn_cell": entrance["spawn_cell"],
		"main_entrance": entrance,
		"next_door_id": next_door_id,
		"macro_graph": macro_data,
	}


static func _choose_size_class(rng: RandomNumberGenerator, options: Dictionary = {}) -> StringName:
	var names: Array[StringName] = [&"small", &"medium", &"large"]
	var weights: Array[float] = [
		maxf(0.0, float(options.get("small_room_weight", 0.45))),
		maxf(0.0, float(options.get("medium_room_weight", 0.35))),
		maxf(0.0, float(options.get("large_room_weight", 0.20))),
	]
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return &"small"
	var roll := rng.randf() * total
	for index in names.size():
		roll -= weights[index]
		if roll <= 0.0:
			return names[index]
	return names.back()


static func _choose_shape(rng: RandomNumberGenerator, options: Dictionary = {}, size_class: StringName = &"large") -> StringName:
	var names: Array[StringName] = [&"square", &"rectangle", &"irregular", &"stepped", &"hollow"]
	var weights: Array[float] = [
		maxf(0.0, float(options.get("macro_square_weight", 0.22))),
		maxf(0.0, float(options.get("macro_rectangle_weight", 0.26))),
		maxf(0.0, float(options.get("macro_irregular_weight", 0.21))),
		maxf(0.0, float(options.get("macro_stepped_weight", 0.15))),
		maxf(0.0, float(options.get("macro_hollow_weight", 0.16))),
	]
	# Keep Small rooms readable and open; reserve the more complex silhouettes
	# for Medium/Large where there is enough walkable area around the cut-outs.
	if size_class == &"small":
		weights[2] = 0.0
		weights[3] = 0.0
		weights[4] = 0.0
	elif size_class == &"medium":
		weights[4] *= 0.35
	else:
		# Large spaces get an explicit authored mix: rectangle, irregular/L and
		# hollow/courtyard silhouettes remain common instead of being drowned out
		# by the small-room weights.
		weights[1] = maxf(0.0, float(options.get("rectangle_large_weight", weights[1])))
		weights[2] = maxf(0.0, float(options.get("irregular_large_weight", weights[2])))
		weights[4] = maxf(0.0, float(options.get("courtyard_large_weight", weights[4])))
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return &"rectangle"
	var roll := rng.randf() * total
	for index in names.size():
		roll -= weights[index]
		if roll <= 0.0:
			return names[index]
	return names.back()


static func _representative_cell(cells: Array[Vector2i], rect: Rect2i) -> Vector2i:
	if cells.is_empty():
		return rect.position
	var target := Vector2(rect.get_center())
	var best: Vector2i = cells[0]
	var best_distance := INF
	for cell in cells:
		var distance := Vector2(cell).distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


static func _shape_cells(rect: Rect2i, shape: StringName, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	if shape == &"square":
		var side := mini(rect.size.x, rect.size.y)
		var inset_x := (rect.size.x - side) / 2
		var inset_y := (rect.size.y - side) / 2
		cells = []
		for y in range(rect.position.y + inset_y, rect.position.y + inset_y + side):
			for x in range(rect.position.x + inset_x, rect.position.x + inset_x + side):
				cells.append(Vector2i(x, y))
	elif shape == &"irregular":
		var cut_w := maxi(2, rect.size.x / 3)
		var cut_h := maxi(2, rect.size.y / 3)
		var corner := rng.randi_range(0, 3)
		var cut := Rect2i(
			rect.position.x if corner % 2 == 0 else rect.end.x - cut_w,
			rect.position.y if corner < 2 else rect.end.y - cut_h,
			cut_w,
			cut_h
		)
		cells = cells.filter(func(cell: Vector2i) -> bool: return not cut.has_point(cell))
	elif shape == &"stepped":
		cells = []
		var steps := maxi(1, mini(3, rect.size.x / 4))
		for y in range(rect.position.y, rect.end.y):
			var row := y - rect.position.y
			var inset := mini(steps, row / maxi(1, rect.size.y / 3))
			for x in range(rect.position.x + inset, rect.end.x - inset):
				cells.append(Vector2i(x, y))
	elif shape == &"hollow":
		# Keep the established outer room footprint but reduce the central void
		# by one gameplay cell on every side.  The ring remains large enough for
		# the existing doorway/usable-cell validators; the important invariant is
		# that this is an inset of the previous void, not a resized room.
		var ring := maxi(1, DEFAULT_ROOM_MIN_RING - 1)
		var void_rect := rect.grow(-ring)
		if void_rect.size.x >= 2 and void_rect.size.y >= 2:
			cells = cells.filter(func(cell: Vector2i) -> bool: return not void_rect.has_point(cell))
	return cells


static func _random_even_size(rng: RandomNumberGenerator, minimum: int, maximum: int) -> int:
	var min_even := maxi(2, int(ceili(float(minimum) / 2.0)) * 2)
	var max_even := maxi(min_even, int(floori(float(maximum) / 2.0)) * 2)
	var count := maxi(0, (max_even - min_even) / 2)
	return min_even + rng.randi_range(0, count) * 2


static func _find_boundary_profile(
	room: Dictionary,
	direction: Vector2i,
	opening_cells: int = 1,
	corner_clearance: int = 0,
	tangent_bias: int = 0,
	forced_tangent_start: int = 2147483647
) -> Dictionary:
	var rect: Rect2i = room["grid_rect"]
	var shape_cells: Array = room["shape_cells"]
	var center: Vector2i = room["center_cell"]
	var width: int = maxi(1, opening_cells)
	var tangent: Vector2i = _tangent_vector(direction)
	var tangent_start_min: int = rect.position.y if direction.x != 0 else rect.position.x
	var tangent_start_max: int = rect.end.y - width if direction.x != 0 else rect.end.x - width
	if tangent_start_max < tangent_start_min:
		return {}
	var boundary_coordinate: int = 0
	if direction == Vector2i.RIGHT:
		boundary_coordinate = rect.end.x - 1
	elif direction == Vector2i.LEFT:
		boundary_coordinate = rect.position.x
	elif direction == Vector2i.DOWN:
		boundary_coordinate = rect.end.y - 1
	else:
		boundary_coordinate = rect.position.y
	var preferred_coordinate: int = center.y + tangent_bias if direction.x != 0 else center.x + tangent_bias
	var candidates: Array[Dictionary] = []
	# Enumerate the complete discrete opening profile directly.  This avoids
	# assigning a different meaning to an "anchor" on even-width openings.
	for tangent_start in range(tangent_start_min, tangent_start_max + 1):
		if forced_tangent_start != 2147483647 and tangent_start != forced_tangent_start:
			continue
		var opening_start: Vector2i = Vector2i(boundary_coordinate, tangent_start) if direction.x != 0 else Vector2i(tangent_start, boundary_coordinate)
		var profile_cells: Array[Vector2i] = []
		var valid: bool = true
		for offset in range(width):
			var cell: Vector2i = opening_start + tangent * offset
			if not shape_cells.has(cell):
				valid = false
				break
			profile_cells.append(cell)
		if not valid or not _door_clearance_valid(room, opening_start, direction, width, corner_clearance):
			continue
		var profile_midpoint_twice: int = tangent_start * 2 + width - 1
		var preferred_midpoint_twice: int = preferred_coordinate * 2
		candidates.append({
			"start_cell": opening_start,
			"end_cell": profile_cells.back(),
			"cells": profile_cells,
			"tangent": tangent,
			"normal": direction,
			"width": width,
			"distance": absi(profile_midpoint_twice - preferred_midpoint_twice),
			"tangent_start": tangent_start,
		})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_distance: int = int(a["distance"])
		var b_distance: int = int(b["distance"])
		if a_distance == b_distance:
			return int(a["tangent_start"]) < int(b["tangent_start"])
		return a_distance < b_distance
	)
	return candidates[0]


static func _profile_tangent_start(profile: Dictionary, direction: Vector2i) -> int:
	var cells: Array = profile.get("cells", [])
	if cells.is_empty():
		return 2147483647
	var first_cell: Vector2i = cells[0]
	return first_cell.y if direction.x != 0 else first_cell.x


static func _find_boundary_anchor(room: Dictionary, direction: Vector2i, opening_cells: int = 1, corner_clearance: int = 0, tangent_bias: int = 0) -> Vector2i:
	# Compatibility helper for the sealed entrance path.  Corridor connections
	# use _find_boundary_profile() directly and never infer a width from this
	# legacy single-cell return value.
	var profile := _find_boundary_profile(room, direction, opening_cells, corner_clearance, tangent_bias)
	if profile.is_empty():
		return Vector2i(999999, 999999)
	return profile["start_cell"]


static func _shift_profile(profile_cells: Array, offset: Vector2i) -> Array[Vector2i]:
	var shifted: Array[Vector2i] = []
	for cell_variant in profile_cells:
		var cell: Vector2i = cell_variant
		shifted.append(cell + offset)
	return shifted


static func _route_cardinal_corridor(profile_a: Dictionary, profile_b: Dictionary, direction: Vector2i, width: int) -> Dictionary:
	var corridor_width: int = maxi(1, width)
	var cells_a: Array = profile_a.get("cells", [])
	var cells_b: Array = profile_b.get("cells", [])
	if cells_a.size() != corridor_width or cells_b.size() != corridor_width:
		return {}
	if cells_a.is_empty() or cells_b.is_empty():
		return {}
	var tangent: Vector2i = _tangent_vector(direction)
	if profile_a.get("tangent", tangent) != tangent or profile_b.get("tangent", tangent) != tangent:
		return {}
	if profile_a.get("normal", direction) != direction or profile_b.get("normal", -direction) != -direction:
		return {}
	var terminal_a: Array[Vector2i] = _shift_profile(cells_a, direction)
	var terminal_b: Array[Vector2i] = _shift_profile(cells_b, -direction)
	var normal_a: Vector2i = terminal_a[0]
	var normal_b: Vector2i = terminal_b[0]
	var travel_sign: int = direction.x if direction.x != 0 else direction.y
	var normal_delta: int = (normal_b.x - normal_a.x) if direction.x != 0 else (normal_b.y - normal_a.y)
	if travel_sign == 0 or normal_delta * travel_sign <= 0:
		return {}
	var tangent_a: int = terminal_a[0].y if direction.x != 0 else terminal_a[0].x
	var tangent_b: int = terminal_b[0].y if direction.x != 0 else terminal_b[0].x
	var result: Array[Vector2i] = []
	# The current macro contract is deliberately stricter than the historical
	# L-route compatibility code: a connection is valid only when both complete
	# terminal profiles share one tangent coordinate.  The profile is then
	# swept along the connection normal, producing exactly one straight segment.
	if tangent_a != tangent_b:
		return {}
	_append_normal_band(result, _normal_coordinate(normal_a, direction), _normal_coordinate(normal_b, direction), tangent_a, direction, corridor_width)
	if not _contains_profile(result, terminal_a) or not _contains_profile(result, terminal_b):
		return {}
	return {"cells": result, "kind": &"straight", "terminal_profile_a": terminal_a, "terminal_profile_b": terminal_b}


static func _normal_coordinate(cell: Vector2i, direction: Vector2i) -> int:
	return cell.x if direction.x != 0 else cell.y


static func _append_normal_band(
	result: Array[Vector2i],
	from_normal: int,
	to_normal: int,
	tangent_start: int,
	direction: Vector2i,
	width: int
) -> void:
	var first_normal: int = mini(from_normal, to_normal)
	var last_normal: int = maxi(from_normal, to_normal)
	for normal_coordinate in range(first_normal, last_normal + 1):
		for offset in range(width):
			var tangent_coordinate: int = tangent_start + offset
			var cell: Vector2i = Vector2i(normal_coordinate, tangent_coordinate) if direction.x != 0 else Vector2i(tangent_coordinate, normal_coordinate)
			if not result.has(cell):
				result.append(cell)


static func _append_tangent_band(
	result: Array[Vector2i],
	from_tangent: int,
	to_tangent: int,
	bend_normal: int,
	destination_normal: int,
	direction: Vector2i,
	width: int
) -> void:
	var first_tangent: int = mini(from_tangent, to_tangent)
	# Arguments identify profile starts; include the complete source and
	# destination cross-sections, not just one row at each start coordinate.
	var last_tangent: int = maxi(from_tangent + width - 1, to_tangent + width - 1)
	# Keep the destination cross-section entirely on the corridor side of the
	# destination room.  For a right/down travel direction the room is beyond
	# the terminal, while for left/up it is behind the terminal.
	var travel_sign: int = direction.x if direction.x != 0 else direction.y
	var normal_start: int = destination_normal - (width - 1) if travel_sign > 0 else destination_normal
	for tangent_coordinate in range(first_tangent, last_tangent + 1):
		for offset in range(width):
			var normal_coordinate: int = normal_start + offset
			var cell: Vector2i = Vector2i(normal_coordinate, tangent_coordinate) if direction.x != 0 else Vector2i(tangent_coordinate, normal_coordinate)
			if not result.has(cell):
				result.append(cell)


static func _contains_profile(route_cells: Array[Vector2i], profile_cells: Array[Vector2i]) -> bool:
	for cell in profile_cells:
		if not route_cells.has(cell):
			return false
	return true


static func _opening_start_for_anchor(anchor: Vector2i, direction: Vector2i, opening_cells: int) -> Vector2i:
	# Kept only for compatibility with older callers.  New connections pass an
	# explicit opening profile and never infer a profile from this helper.
	var tangent := _tangent_vector(direction)
	return anchor - tangent * int(floori(float(opening_cells) / 2.0))


static func _tangent_vector(direction: Vector2i) -> Vector2i:
	return Vector2i(0, 1) if direction.x != 0 else Vector2i(1, 0)


static func _edge_from_inside(cell: Vector2i, direction: Vector2i) -> Dictionary:
	if direction == Vector2i.UP:
		return {"axis": "H", "x": cell.x, "y": cell.y}
	if direction == Vector2i.DOWN:
		return {"axis": "H", "x": cell.x, "y": cell.y + 1}
	if direction == Vector2i.LEFT:
		return {"axis": "V", "x": cell.x, "y": cell.y}
	return {"axis": "V", "x": cell.x + 1, "y": cell.y}


static func _edge_key(edge: Dictionary) -> String:
	return "%s:%d:%d" % [edge["axis"], int(edge["x"]), int(edge["y"])]


static func _edge_world_position(edge: Dictionary) -> Vector3:
	if String(edge["axis"]) == "H":
		return Vector3(float(edge["x"]), 0.0, float(edge["y"]) - 0.5)
	return Vector3(float(edge["x"]) - 0.5, 0.0, float(edge["y"]))


static func _door_clearance_valid(room: Dictionary, opening_start: Vector2i, direction: Vector2i, opening_cells: int, corner_clearance: int) -> bool:
	var rect: Rect2i = room["grid_rect"]
	var coordinate := opening_start.y if direction.x != 0 else opening_start.x
	var start := rect.position.y if direction.x != 0 else rect.position.x
	var end := rect.end.y if direction.x != 0 else rect.end.x
	return coordinate - start >= corner_clearance and end - (coordinate + opening_cells) >= corner_clearance


static func _make_sealed_entrance(room: Dictionary, macro_data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var neighbors: Array = []
	for edge_variant in macro_data.get("edges", []):
		var edge: Dictionary = edge_variant
		if int(edge.get("a", -1)) == int(room["id"]):
			neighbors.append(edge["b_coord"] - room["macro_coord"])
		elif int(edge.get("b", -1)) == int(room["id"]):
			neighbors.append(edge["a_coord"] - room["macro_coord"])
	var available: Array[Vector2i] = []
	for direction in CARDINAL_DIRECTIONS:
		if not neighbors.has(direction):
			available.append(direction)
	if available.is_empty():
		available = CARDINAL_DIRECTIONS.duplicate()
	var direction: Vector2i = available[rng.randi_range(0, available.size() - 1)]
	var entrance_profile := _find_boundary_profile(room, direction)
	var inside: Vector2i = entrance_profile["start_cell"] if not entrance_profile.is_empty() else room["center_cell"]
	var inward := -direction
	var spawn := inside + inward * 2
	var shape_cells: Array = room["shape_cells"]
	if not shape_cells.has(spawn):
		spawn = inside
	return {
		"side": "N" if direction == Vector2i.UP else "E" if direction == Vector2i.RIGHT else "S" if direction == Vector2i.DOWN else "W",
		"inside_cell": inside,
		"spawn_cell": spawn,
		"outward": direction,
		"inward": inward,
		"sealed": true,
	}


static func _add_room_link(rooms: Array[Dictionary], from_id: int, to_id: int) -> void:
	var links: Array = rooms[from_id].get("connections", [])
	if not links.has(to_id):
		links.append(to_id)
	rooms[from_id]["connections"] = links
	var neighbors: Array = rooms[from_id].get("neighbors", [])
	if not neighbors.has(to_id):
		neighbors.append(to_id)
	rooms[from_id]["neighbors"] = neighbors


static func _macro_pair_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _bounds_for_cells(cells: Array) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var min_x := 100000000
	var min_y := 100000000
	var max_x := -100000000
	var max_y := -100000000
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


static func _validate_layout(layout: Dictionary, generation_bounds: Rect2i, options: Dictionary) -> bool:
	var rooms: Array = layout.get("rooms", [])
	var floor_cells: Dictionary = layout.get("floor_cells", {})
	var room_cells: Dictionary = layout.get("room_cells", {})
	var corridor_cells: Dictionary = layout.get("corridor_cells", {})
	var layout_corridors: Array = layout.get("corridors", [])
	var connections: Array = layout.get("connections", [])
	var building_rect: Rect2i = layout.get("building_rect", Rect2i())
	var expected_corridor_width: int = maxi(2, int(options.get("corridor_width", 4)))
	var expected_opening_cells: int = maxi(1, int(options.get("door_opening_cells", 4)))
	if expected_corridor_width != 4 or expected_opening_cells != 4:
		return false
	if rooms.size() < 3 or floor_cells.is_empty() or not generation_bounds.encloses(building_rect):
		return false
	var occupied_rooms: Dictionary = {}
	for room in rooms:
		var shape_cells: Array = room.get("shape_cells", [])
		if shape_cells.is_empty():
			return false
		for cell_variant in shape_cells:
			var cell: Vector2i = cell_variant
			if occupied_rooms.has(cell) or not room_cells.has(cell) or not floor_cells.has(cell):
				return false
			occupied_rooms[cell] = true
	# Every graph edge has a non-empty corridor and every corridor cell is a
	# distinct non-room floor cell. This is the key macro-vs-gameplay invariant.
	var occupied_corridors: Dictionary = {}
	for corridor in layout_corridors:
		if corridor.get("cells", []).is_empty():
			return false
		if int(corridor.get("width_cells", corridor.get("width", 0))) != expected_corridor_width:
			return false
		for cell_variant in corridor.get("cells", []):
			var cell: Vector2i = cell_variant
			if occupied_corridors.has(cell) or room_cells.has(cell) or not corridor_cells.has(cell):
				return false
			occupied_corridors[cell] = true
		if String(corridor.get("kind", "")) != "straight":
			return false
		var corridor_direction: Vector2i = corridor.get("direction", Vector2i.ZERO)
		if not _is_straight_corridor_cells(corridor.get("cells", []), corridor_direction, expected_corridor_width):
			return false
		var corridor_terminal_a: Array = corridor.get("terminal_profile_a", [])
		var corridor_terminal_b: Array = corridor.get("terminal_profile_b", [])
		if corridor_terminal_a.size() != expected_corridor_width or corridor_terminal_b.size() != expected_corridor_width:
			return false
		for terminal_variant in corridor_terminal_a:
			var terminal_cell_a: Vector2i = terminal_variant
			if not occupied_corridors.has(terminal_cell_a):
				return false
		for terminal_variant in corridor_terminal_b:
			var terminal_cell_b: Vector2i = terminal_variant
			if not occupied_corridors.has(terminal_cell_b):
				return false
	for cell_variant in corridor_cells.keys():
		var cell: Vector2i = cell_variant
		if not occupied_corridors.has(cell) or not floor_cells.has(cell):
			return false
	if connections.size() < rooms.size() - 1:
		return false
	for connection_variant in connections:
		var connection: Dictionary = connection_variant
		if int(connection.get("corridor_width_cells", 0)) != expected_corridor_width:
			return false
		if int(connection.get("door_throat_width_cells", expected_opening_cells)) != expected_opening_cells:
			return false
		var corridor_id := int(connection.get("corridor_id", -1))
		if corridor_id < 0 or corridor_id >= layout_corridors.size():
			return false
		var connection_corridor: Dictionary = layout_corridors[corridor_id]
		for side_key in [&"door_a", &"door_b"]:
			var door_data: Dictionary = connection.get(side_key, {})
			if int(door_data.get("opening_cells", 0)) != expected_opening_cells:
				return false
			if int(door_data.get("corridor_width_cells", 0)) != expected_corridor_width:
				return false
			if int(door_data.get("shoulder_cells_each_side", -1)) != int((expected_corridor_width - expected_opening_cells) / 2):
				return false
			var opening_profile: Array = door_data.get("opening_profile", [])
			var terminal_profile: Array = door_data.get("terminal_profile", [])
			var outward: Vector2i = door_data.get("outward", Vector2i.ZERO)
			var opening_tangent: Vector2i = door_data.get("opening_tangent", Vector2i.ZERO)
			var opening_normal: Vector2i = door_data.get("opening_normal", Vector2i.ZERO)
			if opening_profile.size() != expected_opening_cells or terminal_profile.size() != expected_opening_cells:
				return false
			if opening_normal != outward or opening_tangent != _tangent_vector(outward):
				return false
			for profile_index in range(expected_opening_cells):
				var opening_cell: Vector2i = opening_profile[profile_index]
				var expected_terminal: Vector2i = opening_cell + outward
				var actual_terminal: Vector2i = terminal_profile[profile_index]
				if actual_terminal != expected_terminal:
					return false
				if profile_index > 0:
					var previous_opening: Vector2i = opening_profile[profile_index - 1]
					if opening_cell != previous_opening + opening_tangent:
						return false
				if not corridor_cells.has(actual_terminal) or not connection_corridor.get("cells", []).has(actual_terminal):
					return false
		var terminal_a_for_connection: Array = connection_corridor.get("terminal_profile_a", [])
		var terminal_b_for_connection: Array = connection_corridor.get("terminal_profile_b", [])
		var connection_door_a: Dictionary = connection.get("door_a", {})
		var connection_door_b: Dictionary = connection.get("door_b", {})
		if terminal_a_for_connection != connection_door_a.get("terminal_profile", []) or terminal_b_for_connection != connection_door_b.get("terminal_profile", []):
			return false
	for edge_variant in layout.get("door_edges", {}).values():
		var edge: Dictionary = edge_variant
		if String(edge.get("kind", "")) != "room_corridor":
			continue
		if int(edge.get("opening_cells", 0)) != expected_opening_cells:
			return false
		if int(edge.get("corridor_width_cells", 0)) != expected_corridor_width:
			return false
		if int(edge.get("opening_end", 0)) != int(edge.get("opening_start", 0)) + expected_opening_cells:
			return false
		var edge_profile: Array = edge.get("opening_profile", [])
		var edge_terminal_profile: Array = edge.get("terminal_profile", [])
		if edge_profile.size() != expected_opening_cells or edge_terminal_profile.size() != expected_opening_cells:
			return false
		var edge_normal: Vector2i = edge.get("opening_normal", Vector2i.ZERO)
		var edge_tangent: Vector2i = edge.get("opening_tangent", Vector2i.ZERO)
		if edge_normal == Vector2i.ZERO or edge_tangent != _tangent_vector(edge_normal):
			return false
		for profile_index in range(expected_opening_cells):
			var edge_opening_cell: Vector2i = edge_profile[profile_index]
			var edge_terminal_cell: Vector2i = edge_terminal_profile[profile_index]
			if edge_terminal_cell != edge_opening_cell + edge_normal:
				return false
			if profile_index > 0 and edge_opening_cell != edge_profile[profile_index - 1] + edge_tangent:
				return false
	if not _floor_cells_connected(floor_cells):
		return false
	return true


static func _is_straight_corridor_cells(cells_variant: Variant, direction: Vector2i, width: int) -> bool:
	if not cells_variant is Array or cells_variant.is_empty():
		return false
	if direction not in CARDINAL_DIRECTIONS:
		return false
	var cells: Array = cells_variant
	var tangent_values: Dictionary = {}
	var normal_values: Dictionary = {}
	var min_tangent := 2147483647
	var max_tangent := -2147483647
	var min_normal := 2147483647
	var max_normal := -2147483647
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		var tangent := cell.y if direction.x != 0 else cell.x
		var normal := cell.x if direction.x != 0 else cell.y
		tangent_values[tangent] = true
		normal_values[normal] = true
		min_tangent = mini(min_tangent, tangent)
		max_tangent = maxi(max_tangent, tangent)
		min_normal = mini(min_normal, normal)
		max_normal = maxi(max_normal, normal)
	if max_tangent - min_tangent + 1 != width:
		return false
	for tangent in range(min_tangent, max_tangent + 1):
		if not tangent_values.has(tangent):
			return false
	for normal in range(min_normal, max_normal + 1):
		if not normal_values.has(normal):
			return false
		for tangent in range(min_tangent, max_tangent + 1):
			var cell := Vector2i(normal, tangent) if direction.x != 0 else Vector2i(tangent, normal)
			if not cells.has(cell):
				return false
	return cells.size() == (max_normal - min_normal + 1) * width


static func _floor_cells_connected(floor_cells: Dictionary) -> bool:
	if floor_cells.is_empty():
		return false
	var keys := floor_cells.keys()
	var start: Vector2i = keys[0]
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in CARDINAL_DIRECTIONS:
			var neighbor := current + direction
			if floor_cells.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited.size() == floor_cells.size()
