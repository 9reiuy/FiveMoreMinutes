extends Node3D

## Deterministic room/corridor lighting for the generated 3D presentation.
## Gameplay floor/room topology remains authoritative; this node only creates
## visual lights from already-valid cells and never invents a second map.

const FIXTURE_SIZE := Vector2(1.35, 0.46)
const CEILING_LIGHT_HEIGHT_OFFSET := 0.10
const WORLD_LIGHT_CULL_MASK := 7 | 8  # + cutout occluder furniture layer
const INVALID_LIGHT_CELL := Vector2i(2147483647, 2147483647)
## Keep the assigned region inside the cone's falloff shoulder, not at its
## zero-light cutoff. Generated fixtures only; authored tutorial values stay.
const ROOM_RANGE_SHOULDER := 1.20
const ROOM_ANGLE_SHOULDER_DEGREES := 5.0
const ROOM_RADIAL_ATTENUATION := 0.20
const ROOM_ANGULAR_ATTENUATION := 0.15
const WALL_PAIR_MIN_SPACING := 1.25

@export_range(0.0, 4.0, 0.05) var ceiling_light_wall_clearance := 0.5
## Energy remains unchanged. Range/angle exports are retained for authored
## callers; generated fixtures use their planned responsibility rectangles.
@export_range(0.0, 8.0, 0.05) var light_energy := 0.50
@export_range(1.0, 64.0, 0.1) var light_range := 28.0
@export_range(45.0, 170.0, 1.0) var light_angle := 125.0
## The floor is lit primarily by unshadowed spot and center fill.
@export_range(0.0, 1.0, 0.01) var floor_fill_energy := 0.20
@export_range(1.0, 32.0, 0.5) var floor_fill_range_padding := 1.5
@export_range(0.05, 2.0, 0.05) var spot_attenuation := 0.42
@export_range(0.05, 2.0, 0.05) var spot_angle_attenuation := 0.45
@export_range(0.05, 2.0, 0.05) var floor_fill_attenuation := 0.65
@export_range(0.0, 1.0, 0.01) var cone_light_energy_ratio := 0.0
## The fixture is a visual light source in its own right.  Keep this separate
## from `light_energy`: the latter controls illumination of the floor while
## these values control the lamp's visible tube/panel.
@export var fixture_color := Color(0.86, 0.93, 1.0, 1.0)
@export_range(0.0, 4.0, 0.05) var fixture_emission_energy := 1.25
## Housing opacity only; luminous tubes/diffusers remain independently visible.
@export_range(0.0, 1.0, 0.01) var fixture_opacity := 0.30
@export var shadow_enabled := false
## Office opt-in: candidates are selected by the floor shadow manager.
@export var managed_shadows := false
@export var hide_ceiling_fixtures := true
## Kept as scene-compatible tuning fields for authored rooms.  Generated room
## light counts are deliberately determined by the formal size class below,
## rather than by a distance/spacing heuristic.
@export_range(2.0, 16.0, 0.5) var room_light_spacing_cells := 6.0
@export_range(2.0, 20.0, 0.5) var corridor_light_spacing_cells := 7.0
@export_range(0.0, 8.0, 0.25) var door_clearance_cells := 2.0


var room_light_plans: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _shadow_candidates: Array[Light3D] = []


func get_shadow_candidates() -> Array[Light3D]:
	return _shadow_candidates.duplicate()


func _register_shadow_candidate(light: Light3D, room_id: int) -> void:
	if not managed_shadows:
		return
	light.shadow_enabled = false
	light.shadow_bias = 0.035
	light.shadow_normal_bias = 0.6
	light.set_meta(&"shadow_kind", &"interior")
	light.set_meta(&"dream_room_id", room_id)
	light.set_meta(&"shadow_room_id", room_id)
	light.set_meta(&"shadow_scope_radius", light.spot_range if light is SpotLight3D else 0.0)
	_shadow_candidates.append(light)


func clear_lights() -> void:
	room_light_plans.clear()
	_shadow_candidates.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func build_for_world(world: Node) -> void:
	clear_lights()
	if world == null:
		return
	var floor_cells: Dictionary = world.get("floor_cells")
	var room_cells: Dictionary = world.get("room_cells")
	if floor_cells == null or room_cells == null:
		return
	var rooms_variant: Variant = world.get("rooms")
	if not rooms_variant is Array:
		return
	var ceiling_y := float(world.get("wall_height")) + (-CEILING_LIGHT_HEIGHT_OFFSET if managed_shadows else CEILING_LIGHT_HEIGHT_OFFSET)
	for room_variant in rooms_variant:
		if not room_variant is Dictionary:
			continue
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id < 0:
			continue
		var elevator_id: int = int(world.get("elevator_room_id")) if world.get("elevator_room_id") != null else -1
		var r_type: StringName = StringName(room.get("room_type", &""))
		var arch: String = String(room.get("archetype", ""))
		if not bool(room.get("elevator_reception", false)) and (room_id == elevator_id or r_type == &"elevator_lobby" or arch == "elevator_lobby"):
			continue
		var valid_cells := _room_floor_cells(room, room_id, floor_cells, room_cells)
		if valid_cells.is_empty():
			continue
		var room_bounds := _bounds_for_cells(valid_cells)
		var archetype := String(room.get("archetype", "office"))
		var plan := plan_room_lights(valid_cells, room, world, ceiling_y)
		room_light_plans[room_id] = plan.duplicate(true)
		for index in range(plan.size()):
			_create_planned_light(plan[index], index, room_bounds, ceiling_y, archetype)
		_create_room_center_fill(room_id, room_bounds, ceiling_y, archetype)
	# Transition stubs are intentionally short-lived presentation geometry.  The
	# endpoint gradient owns their visual falloff; avoid constructing lights for
	# the hidden logical corridor or for rooms that have not been entered.
	if not bool(world.get("lazy_room_presentation")):
		_build_corridor_lights(world, floor_cells, ceiling_y)


func _room_floor_cells(room: Dictionary, room_id: int, floor_cells: Dictionary, room_cells: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var source: Array = room.get("usable_cells", [])
	if source.is_empty():
		for cell_variant in floor_cells.keys():
			var cell: Vector2i = cell_variant
			if int(room_cells.get(cell, -1)) == room_id:
				result.append(cell)
	else:
		for cell_variant in source:
			if not cell_variant is Vector2i:
				continue
			var cell: Vector2i = cell_variant
			if floor_cells.has(cell) and int(room_cells.get(cell, -1)) == room_id:
				result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return result


## One deterministic plan owns positions, orientations and coverage. It reads
## architectural descriptors, never live furniture transforms or layout RNG.
func plan_room_lights(cells: Array[Vector2i], room: Dictionary, world: Node, ceiling_y: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if cells.is_empty():
		return result
	var bounds := _bounds_for_cells(cells)
	var area := Rect2(Vector2(bounds.position) - Vector2.ONE * 0.5, Vector2(bounds.size))
	var valid: Dictionary = {}
	for cell in cells:
		valid[cell] = true
	var size_class := String(room.get("size_class", "small"))
	var budget := 4 if size_class == "large" else (2 if size_class == "medium" else 1)
	var archetype := String(room.get("archetype", "office"))
	var room_id := int(room.get("id", -1))
	# usable_cells deliberately excludes a two-cell furniture-placement border
	# in the mansion. Wall mounting and light responsibility need the complete
	# architectural floor, not that inset furniture mask.
	var architectural_floor: Dictionary = {}
	var architectural_cells: Array[Vector2i] = []
	var floor_cells: Dictionary = world.get("floor_cells")
	var room_owners: Dictionary = world.get("room_cells")
	for cell: Vector2i in floor_cells:
		if int(room_owners.get(cell, -1)) == room_id:
			architectural_floor[cell] = true
			architectural_cells.append(cell)
	var coverage_area := area
	if not architectural_cells.is_empty():
		var floor_bounds := _bounds_for_cells(architectural_cells)
		coverage_area = Rect2(Vector2(floor_bounds.position) - Vector2.ONE * 0.5, Vector2(floor_bounds.size))
	var long_x := area.size.x >= area.size.y
	var center := area.get_center()
	var seat_center := center
	var plans: Dictionary = world.get("room_layout_plans")
	var room_plan: Dictionary = plans.get(room_id, {})
	var functional: Array = room_plan.get("functional_areas", [])
	for feature: Dictionary in functional:
		var category := String(feature.get("category", ""))
		if category == "conference_table" and archetype in ["conference", "conference_large", "meeting_small"]:
			# The formal table generator aligns its group with the room long axis.
			center = Vector2(feature.get("center_cell", center))
			break
	for feature: Dictionary in functional:
		if String(feature.get("category", "")) == "seating":
			seat_center = Vector2(feature.get("center_cell", center))
			break
	var doors := _door_clearance_rects(world)
	var walls := _solid_wall_segments(world)
	var sconces: Array[Dictionary] = []
	var ceiling_count := budget
	if archetype == "lounge" and budget > 1:
		sconces = _plan_sconces(architectural_floor, world, doors, seat_center, budget / 2, room_id, ceiling_y)
		if not sconces.is_empty():
			ceiling_count = budget / 2
	var slim := maxf(area.size.x, area.size.y) / maxf(1.0, minf(area.size.x, area.size.y)) >= 1.8
	var row_only := slim or archetype in ["conference", "conference_large", "meeting_small", "archive", "server", "storage"]
	var footprint := _fixture_size(archetype)
	if not long_x:
		footprint = Vector2(footprint.y, footprint.x)
	var positions := _resolve_group(center, area.size, ceiling_count, long_x, row_only, footprint, valid, doors, walls)
	if bool(room.get("authored_sample", false)) and String(room.get("sample_key", "")) in ["server", "archive"] and ceiling_count == 2:
		# Place the existing pair over the two equipment banks, not together in
		# the central aisle. Keep the same count, coverage and room ownership.
		var equipment_pair: Array[Vector2] = [
			Vector2(area.position.x + area.size.x * .20, center.y),
			Vector2(area.position.x + area.size.x * .80, center.y),
		]
		var pair_valid := true
		for point in equipment_pair:
			if not _footprint_clear(Rect2(point - footprint * .5, footprint), valid, doors, walls):
				pair_valid = false
				break
		if pair_valid:
			positions = equipment_pair
	# If the chosen ceiling group cannot fit, do not leave a wall-only dark room.
	if positions.is_empty() and not sconces.is_empty():
		sconces.clear()
		positions = _resolve_group(area.get_center(), area.size, budget, long_x, row_only, footprint, valid, doors, walls)
	for point in positions:
		result.append({
			"kind": &"ceiling", "room_id": room_id,
			"position": Vector3(point.x, ceiling_y, point.y),
			"yaw": 0.0 if long_x else PI * 0.5,
			"coverage": _responsibility_rect(point, positions, coverage_area),
			"archetype": archetype
		})
	result.append_array(sconces)
	return result


func _fixture_size(archetype: String) -> Vector2:
	match archetype:
		"conference": return Vector2(2.2, 0.22)
		"lounge", "executive": return Vector2(0.94, 0.94)
		"storage", "security": return Vector2(1.35, 0.38)
		_: return FIXTURE_SIZE


func _pattern(size: Vector2, count: int, long_x: bool, row_only: bool) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if count == 4 and not row_only:
		for x in [-1.0 / 6.0, 1.0 / 6.0]:
			for y in [-1.0 / 6.0, 1.0 / 6.0]:
				points.append(Vector2(x, y) * size)
	else:
		var axis := Vector2.RIGHT if long_x else Vector2.DOWN
		var length := size.x if long_x else size.y
		for index in range(count):
			points.append(axis * length * (float(index + 1) / float(count + 1) - 0.5))
	return points


func _resolve_group(center: Vector2, size: Vector2, count: int, long_x: bool, row_only: bool,
		footprint: Vector2, valid: Dictionary, doors: Array[Rect2], walls: Array[Rect2]) -> Array[Vector2]:
	var shifts: Array[Vector2] = []
	for y in range(-4, 5):
		for x in range(-4, 5):
			shifts.append(Vector2(x, y) * 0.5)
	shifts.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if not is_equal_approx(a.length_squared(), b.length_squared()):
			return a.length_squared() < b.length_squared()
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	while count >= 1:
		var pattern := _pattern(size, count, long_x, row_only)
		# First translate the intact pattern; only then reduce spacing symmetrically.
		for spacing: float in [1.0, 0.85, 0.70, 0.55]:
			for shift in shifts:
				var candidate: Array[Vector2] = []
				var legal := true
				for offset in pattern:
					var point := center + shift + offset * spacing
					var rect := Rect2(point - footprint * 0.5, footprint)
					if not _footprint_clear(rect, valid, doors, walls):
						legal = false
						break
					for previous in candidate:
						if rect.grow(0.15).intersects(Rect2(previous - footprint * 0.5, footprint)):
							legal = false
							break
					if not legal:
						break
					candidate.append(point)
				if legal:
					return candidate
		count = count / 2
	return []


func _footprint_clear(rect: Rect2, valid: Dictionary, doors: Array[Rect2], walls: Array[Rect2]) -> bool:
	var padded := rect.grow(ceiling_light_wall_clearance)
	for y in range(floori(padded.position.y + 0.5), ceili(padded.end.y + 0.5)):
		for x in range(floori(padded.position.x + 0.5), ceili(padded.end.x + 0.5)):
			if not valid.has(Vector2i(x, y)):
				return false
	for door in doors:
		if rect.intersects(door):
			return false
	for wall in walls:
		if padded.intersects(wall):
			return false
	return true


func _edge_segment(edge: Dictionary) -> Rect2:
	var point := Vector2(float(edge.get("x", 0)), float(edge.get("y", 0)))
	if String(edge.get("axis", "")) == "H":
		return Rect2(point + Vector2(-0.5, -0.51), Vector2(1.0, 0.02))
	return Rect2(point + Vector2(-0.51, -0.5), Vector2(0.02, 1.0))


func _solid_wall_segments(world: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var edges: Dictionary = world.get("wall_edges")
	for edge: Dictionary in edges.values():
		result.append(_edge_segment(edge))
	return result


func _door_clearance_rects(world: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var seen: Dictionary = {}
	for source: String in ["door_edges", "door_opening_edges"]:
		var edges: Dictionary = world.get(source)
		for key in edges:
			if seen.has(key):
				continue
			seen[key] = true
			result.append(_edge_segment(edges[key]).grow(door_clearance_cells))
	return result


func _responsibility_rect(point: Vector2, positions: Array[Vector2], area: Rect2) -> Rect2:
	var low := area.position
	var high := area.end
	for other in positions:
		if other.x < point.x - 0.01:
			low.x = maxf(low.x, (other.x + point.x) * 0.5)
		elif other.x > point.x + 0.01:
			high.x = minf(high.x, (other.x + point.x) * 0.5)
		if other.y < point.y - 0.01:
			low.y = maxf(low.y, (other.y + point.y) * 0.5)
		elif other.y > point.y + 0.01:
			high.y = minf(high.y, (other.y + point.y) * 0.5)
	return Rect2(low, high - low)


func _plan_sconces(valid: Dictionary, world: Node, doors: Array[Rect2], seat: Vector2,
		count: int, room_id: int, ceiling_y: float) -> Array[Dictionary]:
	var wall_edges: Dictionary = world.get("wall_edges")
	var excluded: Dictionary = {}
	for source: String in ["window_wall_edges", "glass_wall_edges", "door_edges", "door_opening_edges"]:
		var edges: Dictionary = world.get(source)
		excluded.merge(edges)
	var groups: Dictionary = {}
	var keys := wall_edges.keys()
	keys.sort()
	for key in keys:
		if excluded.has(key):
			continue
		var edge: Dictionary = wall_edges[key]
		if world.has_method("_edge_in_active_presentation") and not world.call("_edge_in_active_presentation", edge):
			continue
		if world.has_method("_edge_touches_corridor") and world.call("_edge_touches_corridor", edge):
			continue
		var cell := Vector2i(int(edge["x"]), int(edge["y"]))
		var horizontal := String(edge["axis"]) == "H"
		var before := cell - (Vector2i.DOWN if horizontal else Vector2i.RIGHT)
		if valid.has(before) == valid.has(cell):
			continue
		var inward := Vector2.DOWN if horizontal else Vector2.RIGHT
		if valid.has(before):
			inward = -inward
		var segment := _edge_segment(edge)
		var near_door := false
		for door in doors:
			if segment.intersects(door):
				near_door = true
				break
		if near_door:
			continue
		var fixed := float(cell.y if horizontal else cell.x) - 0.5
		var group_key := "%s:%s:%s" % [edge["axis"], fixed, inward]
		if not groups.has(group_key):
			groups[group_key] = {"horizontal": horizontal, "fixed": fixed, "inward": inward, "cells": []}
		groups[group_key]["cells"].append(cell.x if horizontal else cell.y)
	var best: Array[Dictionary] = []
	var best_score := INF
	for group: Dictionary in groups.values():
		var coordinates: Array = group["cells"]
		coordinates.sort()
		var run_start := 0
		for index in range(coordinates.size()):
			if index + 1 < coordinates.size() and int(coordinates[index + 1]) == int(coordinates[index]) + 1:
				continue
			var low := float(coordinates[run_start]) - 0.5 + 0.35
			var high := float(coordinates[index]) + 0.5 - 0.35
			run_start = index + 1
			# Two sconces need breathing room, not merely non-overlapping meshes.
			var minimum_run := WALL_PAIR_MIN_SPACING * 3.0 if count == 2 else 0.65
			if high - low < minimum_run:
				continue
			var candidate: Array[Dictionary] = []
			var score := 0.0
			var inward: Vector2 = group["inward"]
			for slot in range(count):
				var along := lerpf(low, high, float(slot + 1) / float(count + 1))
				var point := Vector2(along, float(group["fixed"])) if group["horizontal"] else Vector2(float(group["fixed"]), along)
				score += point.distance_squared_to(seat)
				point += inward * 0.09
				candidate.append({
					"kind": &"wall", "room_id": room_id, "inward": inward,
					"position": Vector3(point.x, (ceiling_y + (CEILING_LIGHT_HEIGHT_OFFSET if managed_shadows else -CEILING_LIGHT_HEIGHT_OFFSET)) * 0.65, point.y),
					"yaw": atan2(-inward.x, -inward.y),
					"coverage": Rect2(point + inward * 1.5 - Vector2.ONE * 1.5, Vector2.ONE * 3.0),
					"archetype": "lounge"
				})
			if score < best_score:
				best_score = score
				best = candidate
	return best


func _create_planned_light(plan: Dictionary, index: int, bounds: Rect2i, ceiling_y: float, archetype: String) -> void:
	var room_id := int(plan["room_id"])
	if plan["kind"] == &"wall":
		_create_sconce(plan, index)
		return
	var node_name := "Room%d_CeilingLight%d" % [room_id, index]
	_create_light_at(node_name, room_id, plan["position"], bounds, ceiling_y, &"room", 1, archetype)
	var holder := get_node(NodePath(node_name)) as Node3D
	holder.set_meta(&"light_plan", plan.duplicate(true))
	var fixture := holder.get_node("FixtureMesh") as Node3D
	fixture.rotation.y = float(plan["yaw"])
	var spot := holder.get_node("RoomLight") as SpotLight3D
	var area: Rect2 = plan["coverage"]
	var point := Vector2(holder.position.x, holder.position.z)
	var farthest := (point - area.position).abs().max((area.end - point).abs())
	var radius := farthest.length() * 1.08
	var height := maxf(0.1, ceiling_y)
	spot.spot_range = (sqrt(radius * radius + height * height) + 0.5) * ROOM_RANGE_SHOULDER
	if managed_shadows:
		# Four quadrant fixtures cover the authored office. Limiting each cone
		# to its actual work zone avoids redrawing distant rooms into its map.
		spot.spot_range = minf(spot.spot_range, 8.0)
	spot.spot_angle = clampf(rad_to_deg(atan2(radius, height)) + ROOM_ANGLE_SHOULDER_DEGREES, 20.0, 85.0)
	spot.spot_attenuation = ROOM_RADIAL_ATTENUATION
	spot.spot_angle_attenuation = ROOM_ANGULAR_ATTENUATION
	spot.shadow_enabled = false
	if managed_shadows:
		spot.set_meta(&"shadow_scope_radius", spot.spot_range)


func _create_sconce(plan: Dictionary, index: int) -> void:
	var holder := Node3D.new()
	holder.name = "Room%d_WallLight%d" % [int(plan["room_id"]), index]
	holder.position = plan["position"]
	holder.rotation.y = float(plan["yaw"])
	holder.set_meta(&"dream_room_id", int(plan["room_id"]))
	holder.set_meta(&"light_plan", plan.duplicate(true))
	add_child(holder)
	_fixture_part(holder, "WallMount", Vector3(0.42, 0.38, 0.06), Vector3.ZERO, false, true)
	_fixture_part(holder, "Diffuser", Vector3(0.34, 0.28, 0.15), Vector3(0.0, 0.0, -0.10), true, true)
	var light := SpotLight3D.new()
	light.name = "WallLight"
	light.position = Vector3(0.0, -0.06, -0.25)
	# Aim the cone's center at its local responsibility area. At -0.35 the
	# center ray reached the floor beyond the light's entire 3.5-unit range.
	light.rotation.x = -PI / 3.0
	light.light_color = Color(0.96, 0.93, 0.86)
	light.light_energy = light_energy * 0.5
	light.spot_range = 3.5
	light.spot_angle = 70.0
	light.spot_attenuation = 1.0
	light.light_cull_mask = WORLD_LIGHT_CULL_MASK
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	holder.add_child(light)
	_register_shadow_candidate(light, int(plan["room_id"]))


func _find_light_cell(
	target: Vector2i,
	valid_cells: Array[Vector2i],
	valid_set: Dictionary,
	used: Array[Vector2i],
	room: Dictionary,
	world: Node,
	require_interior: bool,
	allow_nearest: bool = false
) -> Vector2i:
	if not allow_nearest:
		if not valid_set.has(target) or used.has(target):
			return INVALID_LIGHT_CELL
		if not _clear_of_doors(target, int(room.get("id", -1)), world):
			return INVALID_LIGHT_CELL
		if require_interior and not _cell_clear_for_light(target, valid_set, int(room.get("id", -1)), world):
			return INVALID_LIGHT_CELL
		return target
	var best := INVALID_LIGHT_CELL
	var best_distance := INF
	for cell in valid_cells:
		if not valid_set.has(cell) or used.has(cell):
			continue
		var room_id := int(room.get("id", -1))
		if not _clear_of_doors(cell, room_id, world):
			continue
		if require_interior and not _cell_clear_for_light(cell, valid_set, room_id, world):
			continue
		var distance := Vector2(cell).distance_squared_to(Vector2(target))
		if distance < best_distance or (
			is_equal_approx(distance, best_distance)
			and (cell.y < best.y or (cell.y == best.y and cell.x < best.x))
		):
			best_distance = distance
			best = cell
	return best


func _cell_clear_for_light(cell: Vector2i, valid_set: Dictionary, room_id: int, world: Node) -> bool:
	# The authored wall margin is checked against the actual gameplay Floor set;
	# this prevents a fixture from being put over a wall/void while the template
	# itself remains deterministic.
	# One gameplay-cell margin is sufficient for the 1.35-cell fixture: using a
	# two-cell square here would reject every candidate in narrow/irregular
	# rooms, forcing the fixed layout to fall back onto a wall-adjacent cell.
	var radius := maxi(1, ceili(ceiling_light_wall_clearance))
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if not valid_set.has(cell + Vector2i(dx, dy)):
				return false
	if not _clear_of_doors(cell, room_id, world):
		return false
	return true


func _clear_of_doors(cell: Vector2i, _room_id: int, world: Node) -> bool:
	var seen: Dictionary = {}
	for source_name in [&"door_edges", &"door_opening_edges"]:
		var source_variant: Variant = world.get(source_name)
		if not source_variant is Dictionary:
			continue
		var edge_map: Dictionary = source_variant
		for edge_variant in edge_map.values():
			if not edge_variant is Dictionary:
				continue
			var edge: Dictionary = edge_variant
			var edge_id := String(edge.get("axis", "")) + ":" + str(int(edge.get("x", 0))) + ":" + str(int(edge.get("y", 0)))
			if seen.has(edge_id):
				continue
			seen[edge_id] = true
			var axis := String(edge.get("axis", ""))
			var edge_point := Vector2(float(edge.get("x", 0)), float(edge.get("y", 0)))
			if axis == "H":
				edge_point.y -= 0.5
			elif axis == "V":
				edge_point.x -= 0.5
			else:
				continue
			if Vector2(cell).distance_to(edge_point) <= door_clearance_cells:
				return false
	return true


func _build_corridor_lights(world: Node, floor_cells: Dictionary, ceiling_y: float) -> void:
	var corridors_variant: Variant = world.get("corridors")
	if not corridors_variant is Array:
		return
	for corridor_variant in corridors_variant:
		if not corridor_variant is Dictionary:
			continue
		var corridor: Dictionary = corridor_variant
		var cells := _corridor_cells(corridor, floor_cells)
		if cells.is_empty():
			continue
		var bounds := _bounds_for_cells(cells)
		var corridor_id := int(corridor.get("id", -1))
		var valid_set: Dictionary = {}
		for cell in cells:
			valid_set[cell] = true
		var center := Vector2i(
			roundi((float(bounds.position.x) + float(bounds.end.x - 1)) * 0.5),
			roundi((float(bounds.position.y) + float(bounds.end.y - 1)) * 0.5)
		)
		# Corridors are intentionally narrow, so the room-style interior margin
		# would reject every cell.  Door clearance and real Floor membership are
		# still enforced, and exactly one center fixture is created.
		var cell := _find_light_cell(
			center, cells, valid_set, [], {"id": -1}, world, false, true
		)
		if cell == INVALID_LIGHT_CELL:
			continue
		_create_light_at(
			"Corridor%d_CeilingLight0" % corridor_id,
			corridor_id,
			Vector3(float(cell.x), ceiling_y, float(cell.y)),
			bounds,
			ceiling_y,
			&"corridor",
			1
		)


func _corridor_cells(corridor: Dictionary, floor_cells: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var raw: Variant = corridor.get("cells", [])
	if raw is Dictionary:
		for cell_variant in raw.keys():
			if cell_variant is Vector2i and floor_cells.has(cell_variant):
				result.append(cell_variant)
	elif raw is Array:
		for cell_variant in raw:
			if cell_variant is Vector2i and floor_cells.has(cell_variant):
				result.append(cell_variant)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return result


func _bounds_for_cells(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func _create_light_at(
	node_name: String,
	owner_id: int,
	world_position: Vector3,
	coverage_rect: Rect2i,
	ceiling_y: float,
	owner_kind: StringName = &"room",
	fixture_count: int = 1,
	archetype: String = "office"
) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = world_position
	if owner_kind == &"corridor":
		holder.set_meta(&"dream_room_id", -1)
		holder.set_meta(&"dream_corridor_id", owner_id)
	else:
		holder.set_meta(&"dream_room_id", owner_id)
	add_child(holder)

	var fixture := _build_fixture_mesh(holder, archetype, coverage_rect)
	if hide_ceiling_fixtures and not node_name.begins_with("Authored"):
		fixture.visible = false

	var light := SpotLight3D.new()
	light.name = "RoomLight"
	light.rotation.x = -PI * 0.5
	light.light_energy = light_energy
	light.light_cull_mask = WORLD_LIGHT_CULL_MASK
	light.shadow_enabled = shadow_enabled
	if managed_shadows:
		# Four overlapping office cones plus exterior daylight otherwise clip
		# pale furniture and the floor to white in the formal game camera.
		light.light_energy *= 0.6

	match archetype:
		"conference":
			light.light_color = Color(0.88, 0.92, 0.98, 1.0)
		"lounge", "executive":
			light.light_color = Color(0.96, 0.93, 0.86, 1.0)
		"storage", "security":
			light.light_color = Color(0.84, 0.89, 0.98, 1.0)
		_:
			light.light_color = Color(0.86, 0.91, 0.98, 1.0)

	var spot_coverage := _spot_coverage(coverage_rect, ceiling_y, fixture_count, owner_kind)
	light.light_color = preload("res://scripts/dream/dream_room_environment_theme.gd").profile(archetype).light
	light.spot_range = spot_coverage.x
	if managed_shadows:
		light.spot_range = minf(light.spot_range, 8.0)
	light.spot_angle = spot_coverage.y
	light.spot_attenuation = spot_attenuation
	light.spot_angle_attenuation = spot_angle_attenuation
	holder.add_child(light)
	_register_shadow_candidate(light, owner_id)


func _create_room_center_fill(
	room_id: int,
	bounds: Rect2i,
	ceiling_y: float,
	archetype: String
) -> void:
	var holder := Node3D.new()
	holder.name = "Room%d_CenterFill" % room_id
	var center_x := (float(bounds.position.x) + float(bounds.end.x - 1)) * 0.5
	var center_z := (float(bounds.position.y) + float(bounds.end.y - 1)) * 0.5
	holder.position = Vector3(center_x, ceiling_y - 0.15, center_z)
	holder.set_meta(&"dream_room_id", room_id)
	add_child(holder)

	var fill := OmniLight3D.new()
	fill.name = "RoomFillLight"
	var half_diagonal := Vector2(bounds.size).length() * 0.5
	var fill_slant_range := sqrt(half_diagonal * half_diagonal + ceiling_y * ceiling_y)
	fill.omni_range = maxf(3.0, fill_slant_range + floor_fill_range_padding)
	fill.omni_attenuation = floor_fill_attenuation

	match archetype:
		"conference":
			fill.light_color = Color(0.72, 0.78, 0.88, 1.0)
		"lounge", "executive":
			fill.light_color = Color(0.78, 0.75, 0.70, 1.0)
		"storage", "security":
			fill.light_color = Color(0.68, 0.74, 0.84, 1.0)
		_:
			fill.light_color = Color(0.70, 0.76, 0.86, 1.0)

	fill.light_energy = floor_fill_energy
	if managed_shadows:
		# A weak local fill preserves readability without erasing main shadows.
		fill.light_energy *= 0.35
		fill.omni_range = maxf(2.0, minf(fill.omni_range, float(mini(bounds.size.x, bounds.size.y)) * 0.5))
	fill.light_color = preload("res://scripts/dream/dream_room_environment_theme.gd").profile(archetype).light
	fill.light_specular = 0.0
	fill.light_cull_mask = WORLD_LIGHT_CULL_MASK
	fill.shadow_enabled = false
	holder.add_child(fill)


## Open rails never cover the luminous top surface. Every component shares the
## same local X axis, including rods and cage; orientation belongs to the group.
func _build_fixture_mesh(holder: Node3D, archetype: String, coverage_rect: Rect2i) -> MeshInstance3D:
	var size := _fixture_size(archetype)
	var warm := archetype in ["lounge", "executive"]
	var fixture := _fixture_part(holder, "FixtureMesh", Vector3(0.025, 0.025, size.y), Vector3.ZERO, false, warm)
	_fixture_part(fixture, "NearRail", Vector3(size.x, 0.05, 0.035), Vector3(0, 0, -size.y * 0.5 + 0.0175), false, warm)
	_fixture_part(fixture, "FarRail", Vector3(size.x, 0.05, 0.035), Vector3(0, 0, size.y * 0.5 - 0.0175), false, warm)
	for sign_value: float in [-1.0, 1.0]:
		_fixture_part(fixture, "EndRail", Vector3(0.035, 0.05, size.y), Vector3(sign_value * (size.x * 0.5 - 0.0175), 0, 0), false, warm)
	if warm:
		_fixture_part(fixture, "Diffuser", Vector3(size.x - 0.09, 0.035, size.y - 0.09), Vector3(0, 0.025, 0), true, true)
	elif archetype == "conference":
		_fixture_part(fixture, "Diffuser", Vector3(size.x - 0.1, 0.035, size.y - 0.09), Vector3(0, 0.025, 0), true, false)
		for sign_value: float in [-1.0, 1.0]:
			_fixture_part(fixture, "SuspensionRod", Vector3(0.015, 0.3, 0.015), Vector3(sign_value * 0.95, 0.15, 0), false, false)
	elif archetype in ["storage", "security"]:
		_fixture_part(fixture, "Tube", Vector3(1.18, 0.04, 0.08), Vector3(0, 0.025, 0), true, false)
		for x: float in [-0.38, 0.0, 0.38]:
			_fixture_part(fixture, "Cage", Vector3(0.015, 0.025, size.y), Vector3(x, -0.025, 0), false, false)
	else:
		for z: float in [-0.12, 0.12]:
			_fixture_part(fixture, "Tube", Vector3(1.15, 0.04, 0.065), Vector3(0, 0.025, z), true, false)
	fixture.rotation.y = 0.0 if coverage_rect.size.x >= coverage_rect.size.y else PI * 0.5
	return fixture


func _fixture_part(parent: Node3D, part_name: String, size: Vector3, offset: Vector3, luminous: bool, warm: bool) -> MeshInstance3D:
	var key := str(size)
	if not _mesh_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_mesh_cache[key] = mesh
	var color := Color(0.96, 0.93, 0.86) if warm else fixture_color
	if not luminous:
		color = Color(0.48, 0.51, 0.55)
	# Only the housing is translucent. Tubes/diffusers must remain readable
	# above the floor after the existing final palette quantization.
	color.a = 1.0 if luminous else fixture_opacity
	var material_key := "%s:%s:%s" % [color, luminous, fixture_emission_energy]
	if not _material_cache.has(material_key):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if luminous else BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		material.roughness = 0.7
		if luminous:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = Color(color.r, color.g, color.b)
			material.emission_energy_multiplier = fixture_emission_energy
		_material_cache[material_key] = material
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = _mesh_cache[key]
	part.material_override = _material_cache[material_key]
	part.position = offset
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


## Compatibility adapter for authored rooms (currently the 3D tutorial).
## Random Dream uses build_for_world(), but the tutorial supplies explicit
## cell positions and still calls the former private helper.  Keep that call
## on the same fixture/light implementation so there is only one lighting
## authority and no second ad-hoc light stack.
func _create_light(light_id: int, cell: Vector2i, ceiling_y: float) -> void:
	_create_light_at(
		"AuthoredCeilingLight%d" % light_id,
		light_id,
		Vector3(float(cell.x), ceiling_y, float(cell.y)),
		Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3)),
		ceiling_y,
		&"room",
		1
	)


## Return the actual SpotLight footprint needed for this room tier.
##
## The old fixed 79-degree cone was sized for a dense fixture layout and only
## produced a small bright disc when a Small room had one light.  Derive the
## target radius from the room bounds and number of fixtures, then convert it
## to a cone angle at the real ceiling height.  Corridor lights intentionally
## use their narrow cross-section rather than trying to illuminate the full
## corridor length; dark ends remain valid for a one-light corridor.
func _spot_coverage(
	coverage_rect: Rect2i,
	ceiling_y: float,
	fixture_count: int,
	owner_kind: StringName
) -> Vector2:
	var room_size := Vector2(coverage_rect.size)
	var half_diagonal := room_size.length() * 0.5
	# Each fixture owns a real portion of the room, but its cone must still
	# reach the far corners of that portion.  Dividing the room diagonal by
	# sqrt(fixture_count) under-covered the corners after the layout changed to
	# 1/2/4 fixtures, which was the source of the visible broken light bands.
	var target_radius := half_diagonal
	if fixture_count > 1:
		# The fixtures are laid out as a regular row/2x2 grid.  Keep a small
		# overlap for a continuous transition without shrinking the footprint.
		target_radius *= 0.92
	if owner_kind == &"corridor":
		# One corridor lamp covers its centre section.  Use the short axis as the
		# footprint authority so the cone does not wash the entire level.
		var short_axis := float(mini(coverage_rect.size.x, coverage_rect.size.y))
		target_radius = minf(target_radius, maxf(short_axis * 0.9, 1.5))
	target_radius += 0.75
	var height := maxf(absf(ceiling_y), 0.5)
	var required_angle := rad_to_deg(2.0 * atan(target_radius / height)) + 6.0
	var angle := clampf(maxf(light_angle, required_angle), 45.0, 170.0)
	var slant_range := sqrt(target_radius * target_radius + height * height) + 1.0
	return Vector2(maxf(light_range, slant_range), angle)
