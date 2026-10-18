class_name OTXORoomLayoutPlanner
extends RefCounted

## OTXORoomLayoutPlanner
## Joint layout planner for OTXO Mansion rooms.
## Organizes furniture into distinct functional clusters by archetype, guarantees clear
## walking paths between all doorways via BFS, places enemies in zonal crossfire stances,
## and positions weapon drops along open transit lanes.

const CELL_PIXELS: float = 32.0
const DOOR_RESERVATION_DEPTH_CELLS: int = 2
const DOOR_RESERVATION_MARGIN_PIXELS: float = 14.0
const FURNITURE_PLAYER_CLEARANCE: float = 14.0
const ENEMY_MIN_SPACING: float = 32.0
const ENEMY_DOOR_CLEARANCE: float = 64.0
const ENEMY_FURNITURE_CLEARANCE: float = 16.0
const DROP_DOOR_CLEARANCE: float = 48.0
const DROP_FURNITURE_CLEARANCE: float = 20.0
const MAX_ATTEMPTS: int = 4

static var _footprint_cache: Dictionary = {}
static var _collision_rect_cache: Dictionary = {}

## Approved room groups use catalog footprints; only their placement changes.
## The sample identity is deliberately not involved in this planner.
static func _plan_office_combat(room: Dictionary, doors: Array, enemy_count: int, rng: RandomNumberGenerator, bounds: Rect2, cell: float, drop_count: int = 0) -> Dictionary:
	const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
	const LOGIC = preload("res://scenes/dream/props/desk.tscn")
	const CHAIR = preload("res://scenes/dream/props/office_chair_01.tscn")
	var kind := String(room.get("archetype", "open_office"))
	var entry_reception := bool(room.get("elevator_reception", false))
	if entry_reception:
		doors = doors.duplicate()
		var rect: Rect2i = room.grid_rect
		doors.append({"inside_cell": Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1), "outward": Vector2i.DOWN, "opening_cells": 3})
	var reserves: Array[Rect2] = []
	# Pack door centers are start+1, rather than a full opening profile. Reserve
	# every opening cell and never relax the two-cell depth for many doors.
	for door in doors:
		var profiled: Dictionary = door.duplicate()
		if not profiled.has("opening_profile") and int(door.get("opening_cells", 1)) > 1:
			var outward: Vector2i = door.get("outward", Vector2i.ZERO)
			var tangent := Vector2i(0, 1) if outward.x != 0 else Vector2i(1, 0)
			var opening_profile: Array[Vector2i] = []
			for slot in range(int(door.opening_cells)):
				opening_profile.append(Vector2i(door.inside_cell) + tangent * (slot - 1))
			profiled["opening_profile"] = opening_profile
		reserves.append_array(get_doorway_reservation_rects([profiled], cell))
	var usable: Array = room.get("usable_cells", [])
	var walkable: Array = room.get("shape_cells", usable)
	var first := rng.randi_range(0, 1)
	var rejected := {"bounds": 0, "door": 0, "overlap": 0, "floor": 0, "route": 0}
	for attempt in range(192):
		var specs := _office_room_group(kind, bounds.size, attempt / 96)
		if specs.is_empty():
			break
		var furniture: Array = []
		var areas: Array[Dictionary] = []
		var valid := true
		var area := 0.0
		var mirrored := (first + attempt) % 2 == 1
		var quarter_turn := 0 if entry_reception else (attempt / 2) % 4
		var angle := float(quarter_turn) * PI * .5
		var shifts := [Vector2.ZERO, Vector2(0, .12), Vector2(.12, 0), Vector2(-.12, 0), Vector2(0, .24), Vector2(0, -.12), Vector2(.06, .18), Vector2(-.06, .18), Vector2(.18, 0), Vector2(-.18, 0), Vector2(0, .18), Vector2(0, -.18)]
		var shift: Vector2 = shifts[(attempt / 8) % shifts.size()] * bounds.size
		if entry_reception:
			shift.x = 0.0
		for spec in specs:
			var offset: Vector2 = spec[1]
			var rotation := float(spec[2])
			if String(spec[0]) == "chair":
				rotation += PI
			if mirrored:
				offset.x = -offset.x
				rotation = -rotation
			var position: Vector2 = bounds.get_center() + offset.rotated(angle) + shift
			rotation += angle
			var original_rect: Rect2 = CATALOG.footprint(String(spec[0]))
			var local_rect := _office_rotated_rect(original_rect, rotation)
			var occupied := Rect2(position + local_rect.position, local_rect.size)
			if not bounds.encloses(occupied):
				rejected.bounds += 1
				valid = false
				break
			for reservation in reserves:
				if occupied.intersects(reservation):
					rejected.door += 1
					valid = false
			for placed in furniture:
				var previous: Rect2 = placed.collision_rect
				previous.position += Vector2(placed.position)
				if occupied.intersects(previous):
					rejected.overlap += 1
					valid = false
			if not _office_rect_on_floor(occupied, walkable, cell):
				rejected.floor += 1
				valid = false
			if not valid:
				break
			area += occupied.get_area()
			furniture.append({"scene": CHAIR if String(spec[0]) == "chair" else LOGIC, "position": position, "rotation": rotation, "collision_rect": local_rect, "half_extents": local_rect.size * .5, "office_kind": String(spec[0]), "functional_group": kind})
			areas.append({"category": "conference_table" if String(spec[0]) == "table" else "seating" if String(spec[0]) == "sofa" else "storage" if String(spec[0]) in ["cabinet", "shelf", "server"] else "workstation", "center": position, "center_cell": Vector2i((position / cell).round()), "rect": occupied})
		if not valid or (entry_reception and not _office_entry_lane_clear(bounds, furniture, cell)) or area > bounds.get_area() * .4 or not _office_wide_routes(walkable, furniture, doors, cell) or not _office_group_bypasses(kind, walkable, furniture, cell) or not _has_office_dash_lane(bounds, furniture, cell):
			if valid:
				rejected.route += 1
			continue
		var reachable := _office_reachable_floor(walkable, furniture, doors, cell)
		var spawn_cells: Array = usable.filter(func(point: Variant): return reachable.has(Vector2i(point)))
		var enemies := calculate_tactical_enemy_spawns(spawn_cells, furniture, doors, reserves, bounds, enemy_count, rng, cell)
		if enemies.size() != enemy_count:
			continue
		var drops := calculate_roadside_drops(spawn_cells, furniture, enemies, doors, reserves, bounds, drop_count, rng, cell)
		return {"success": true, "attempt": attempt, "furniture_placements": furniture, "enemy_spawns": enemies, "drop_spawns": drops, "door_reservation_rects": reserves, "functional_areas": areas}
	return {"success": false, "failure_reason": "approved_group_does_not_fit:" + kind, "rejected_candidates": rejected, "furniture_placements": [], "enemy_spawns": [], "drop_spawns": [], "door_reservation_rects": reserves, "functional_areas": []}

static func _office_entry_lane_clear(bounds: Rect2, furniture: Array, cell: float) -> bool:
	var lane := Rect2(Vector2(bounds.get_center().x - cell * 1.5, bounds.position.y), Vector2(cell * 3.0, bounds.size.y))
	for item in furniture:
		var obstacle: Rect2 = item.collision_rect
		obstacle.position += Vector2(item.position)
		if lane.intersects(obstacle):
			return false
		if String(item.office_kind) == "reception" and Vector2.DOWN.rotated(float(item.rotation)).dot(Vector2.DOWN) < .99:
			return false
	return true

static func _office_rotated_rect(rect: Rect2, angle: float) -> Rect2:
	var result := Rect2(rect.position.rotated(angle), Vector2.ZERO)
	for point in [rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		result = result.expand(Vector2(point).rotated(angle))
	return result

static func _office_rect_on_floor(rect: Rect2, cells: Array, cell: float) -> bool:
	var available := {}
	for point in cells:
		available[Vector2i(point)] = true
	for x in range(floori((rect.position.x + cell * .5) / cell), ceili((rect.end.x + cell * .5) / cell)):
		for y in range(floori((rect.position.y + cell * .5) / cell), ceili((rect.end.y + cell * .5) / cell)):
			if not available.has(Vector2i(x, y)):
				return false
	return true

static func _office_wide_routes(cells: Array, furniture: Array, doors: Array, cell: float) -> bool:
	var inflated: Array = []
	for item in furniture:
		var copy: Dictionary = item.duplicate()
		# Validator adds 14px player clearance AND intersects a 28px cell box.
		# Total obstacle-to-path-center clearance is therefore 1.5 cells.
		copy.collision_rect = Rect2(item.collision_rect).grow(cell * 1.5 - 14.0 - FURNITURE_PLAYER_CLEARANCE)
		inflated.append(copy)
	var available := {}
	for point in cells:
		available[Vector2i(point)] = true
	var interior: Array[Vector2i] = []
	for point in cells:
		var center := Vector2i(point)
		var clear := true
		for x in range(-1, 2):
			for y in range(-1, 2):
				if not available.has(center + Vector2i(x, y)):
					clear = false
		if clear:
			interior.append(center)
	# A retained cell and its eight neighbors cover a 3x3 floor square. Door
	# throats may be narrower; the validator advances inward to their main lane.
	return validate_room_walkability(interior, inflated, doors, cell)

static func _office_reachable_floor(cells: Array, furniture: Array, doors: Array, cell: float) -> Dictionary:
	# Spawn only in the door-connected component, not inside a closed stall or
	# an inaccessible pocket enclosed by a functional group.
	var available := {}
	for point in cells:
		var center := Vector2(point) * cell
		var blocked := false
		for item in furniture:
			var obstacle: Rect2 = item.collision_rect
			obstacle.position += Vector2(item.position)
			if obstacle.grow(FURNITURE_PLAYER_CLEARANCE + 14.0).has_point(center):
				blocked = true
				break
		if not blocked:
			available[Vector2i(point)] = true
	var frontier: Array[Vector2i] = []
	for door in doors:
		var inside: Vector2i = door.get("inside_cell", Vector2i.ZERO)
		var inward: Vector2i = -Vector2i(door.get("outward", Vector2i.ZERO))
		for step in range(4):
			var entry := inside + inward * step
			if available.has(entry):
				frontier.append(entry)
				break
		if not frontier.is_empty():
			break
	var reached := {}
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if reached.has(current):
			continue
		reached[current] = true
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if available.has(next) and not reached.has(next):
				frontier.append(next)
	return reached

static func _office_group_bypasses(kind: String, cells: Array, furniture: Array, cell: float) -> bool:
	if kind in ["archive", "storage", "server"]:
		return _office_row_end_bypasses(cells, furniture, cell)
	var targets: Array = []
	if kind in ["conference", "conference_large", "meeting_small"]:
		targets = ["table", "chair"]
	elif kind in ["lounge", "manager", "executive", "small_office", "reception"]:
		targets = ["sofa", "coffee_table"]
	else:
		return true
	var group := Rect2()
	for item in furniture:
		if String(item.office_kind) in targets:
			var rect: Rect2 = item.collision_rect
			rect.position += Vector2(item.position)
			group = rect if group.size == Vector2.ZERO else group.merge(rect)
	if group.size == Vector2.ZERO:
		return false
	var width := cell * 2.0
	var strips := [Rect2(group.position - Vector2(width, 0), Vector2(width, group.size.y)), Rect2(Vector2(group.end.x, group.position.y), Vector2(width, group.size.y)), Rect2(group.position - Vector2(0, width), Vector2(group.size.x, width)), Rect2(Vector2(group.position.x, group.end.y), Vector2(group.size.x, width))]
	var clear: Array[bool] = []
	for strip: Rect2 in strips:
		var valid := _office_rect_on_floor(strip, cells, cell)
		for item in furniture:
			if String(item.office_kind) in targets:
				continue
			var rect: Rect2 = item.collision_rect
			rect.position += Vector2(item.position)
			if strip.intersects(rect):
				valid = false
		clear.append(valid)
	return (clear[0] and clear[1]) or (clear[2] and clear[3])

static func _office_row_end_bypasses(cells: Array, furniture: Array, cell: float) -> bool:
	var rows := {}
	var along_y := true
	for item in furniture:
		if String(item.office_kind) not in ["cabinet", "shelf", "server"]:
			continue
		along_y = absf(cos(float(item.rotation))) < .5
		var key := roundi(float(item.position.x if along_y else item.position.y))
		var rect: Rect2 = item.collision_rect
		rect.position += Vector2(item.position)
		rows[key] = rect if not rows.has(key) else Rect2(rows[key]).merge(rect)
	for row: Rect2 in rows.values():
		var width := cell * 2.0
		var strips: Array[Rect2] = []
		if along_y:
			strips = [Rect2(Vector2(row.get_center().x - width * .5, row.position.y - width), Vector2(width, width)), Rect2(Vector2(row.get_center().x - width * .5, row.end.y), Vector2(width, width))]
		else:
			strips = [Rect2(Vector2(row.position.x - width, row.get_center().y - width * .5), Vector2(width, width)), Rect2(Vector2(row.end.x, row.get_center().y - width * .5), Vector2(width, width))]
		for strip in strips:
			if not _office_rect_on_floor(strip, cells, cell):
				return false
			for item in furniture:
				var obstacle: Rect2 = item.collision_rect
				obstacle.position += Vector2(item.position)
				if strip.intersects(obstacle.grow(-.01)):
					return false
	return not rows.is_empty()

static func _office_room_group(kind: String, size: Vector2, reduced: int) -> Array:
	# Each entry is [catalog kind, group-local center, 2D rotation]. Chair
	# specifications aim -Y; convert to the approved model's +Y front above.
	var specs: Array = []
	var side := minf(size.x * .27, 210.0)
	var top := -minf(size.y * .30, 180.0)
	match kind:
		"open_office":
			for x in [-side, side]:
				for y in [top, 65.0] if reduced == 0 else [top]:
					specs.append_array([["workstation", Vector2(x, y), 0.0], ["chair", Vector2(x, y + 38), 0.0]])
			specs.append(["cabinet", Vector2(0, top), 0.0])
		"conference_large", "conference", "meeting_small":
			specs = [["table", Vector2.ZERO, 0.0], ["whiteboard", Vector2(-side - 40, -65), -PI * .5], ["cabinet", Vector2(-side - 40, 65), -PI * .5]]
			for x in [-48.0, 0.0, 48.0]:
				for y in [-38.0, 38.0]:
					specs.append(["chair", Vector2(x, y), PI if y < 0 else 0.0])
		"small_office", "manager", "executive":
			specs = [["workstation", Vector2(-side, top), 0.0], ["chair", Vector2(-side, top + 38), 0.0], ["cabinet", Vector2(side, top), 0.0], ["sofa", Vector2(side, 65), 0.0], ["coffee_table", Vector2(side, 115), 0.0]]
		"pantry":
			specs = [["fridge", Vector2(-side - 35, -65), -PI * .5], ["sink", Vector2(-side - 35, -30), -PI * .5], ["appliance_counter", Vector2(-side - 35, 15), -PI * .5], ["dining_table", Vector2(side, 25), 0.0], ["chair", Vector2(side, 65), 0.0], ["chair", Vector2(side, -15), PI]]
		"restroom":
			for x in [-side, -side + 64]:
				specs.append_array([["toilet", Vector2(x, top), 0.0], ["partition", Vector2(x - 20, top + 8), 0.0], ["partition", Vector2(x + 20, top + 8), 0.0], ["stall_door", Vector2(x, top + 35), 0.0]])
			specs.append(["washbasin", Vector2(side, 40), PI * .5])
		"archive", "storage", "server":
			var asset := "server" if kind == "server" else "cabinet" if kind == "archive" else "shelf"
			for x in [-side, side]:
				for y in [-90.0, 0.0, 90.0] if reduced == 0 else [-72.0, 72.0]:
					specs.append([asset, Vector2(x, y), -PI * .5 if x < 0 else PI * .5])
			if kind == "archive":
				specs.append(["sorting_table", Vector2(0, top), 0.0])
		"printing":
			specs = [["copier", Vector2(-side, 0), 0.0], ["cabinet", Vector2(0, top), 0.0], ["counter", Vector2(side, 0), PI * .5]]
		"reception":
			specs = [["reception", Vector2(-side, -45), 0.0], ["chair", Vector2(-side, -80), PI], ["sofa", Vector2(side, 20), 0.0], ["coffee_table", Vector2(side, 70), 0.0], ["plant", Vector2(side, top), 0.0]]
		"lounge":
			specs = [["sofa", Vector2(0, -55), 0.0], ["sofa", Vector2(0, 55), PI], ["coffee_table", Vector2.ZERO, 0.0], ["shelf", Vector2(-side, top), 0.0], ["plant", Vector2(side, top), 0.0]]
	return specs

static func _has_office_dash_lane(bounds: Rect2, furniture: Array, cell: float) -> bool:
	# Three-cell-wide combat space, at least one unmodified ordinary Dash long.
	for size in [Vector2(6, 3) * cell, Vector2(3, 6) * cell]:
		for x in range(ceili(bounds.position.x / cell), floori((bounds.end.x - size.x) / cell) + 1):
			for y in range(ceili(bounds.position.y / cell), floori((bounds.end.y - size.y) / cell) + 1):
				var lane := Rect2(Vector2(x, y) * cell, size)
				var clear := true
				for item in furniture:
					var rect: Rect2 = item.collision_rect
					rect.position += Vector2(item.position)
					if lane.intersects(rect):
						clear = false
						break
				if clear:
					return true
	return false
static var _resolved_scene_cache: Dictionary = {}


static func get_furniture_collision_rect(scene: PackedScene) -> Rect2:
	if scene == null:
		return Rect2(-16.0, -16.0, 32.0, 32.0)
	var path := scene.resource_path
	if _collision_rect_cache.has(path):
		return _collision_rect_cache[path]
	var rect := Rect2(-16.0, -16.0, 32.0, 32.0)
	var dummy := scene.instantiate() as Node2D
	if dummy != null:
		var col := dummy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null and col.shape != null:
			var shape_rect: Rect2 = col.shape.get_rect()
			var eff_size := shape_rect.size * col.scale
			var eff_center := col.position
			rect = Rect2(eff_center - eff_size * 0.5, eff_size)
		elif dummy.has_method("get_gameplay_footprint_half_extents"):
			var h: Variant = dummy.call("get_gameplay_footprint_half_extents")
			if h is Vector2:
				var half_vec: Vector2 = h as Vector2
				rect = Rect2(-half_vec, half_vec * 2.0)
		dummy.free()
	_collision_rect_cache[path] = rect
	return rect


static func get_furniture_half_extents(scene: PackedScene) -> Vector2:
	if scene == null:
		return Vector2(16.0, 16.0)
	var path := scene.resource_path
	if _footprint_cache.has(path):
		return _footprint_cache[path]
	var r := get_furniture_collision_rect(scene)
	var half := Vector2(maxf(absf(r.position.x), absf(r.end.x)), maxf(absf(r.position.y), absf(r.end.y)))
	_footprint_cache[path] = half
	return half


static func get_doorway_reservation_rects(doors: Array, cell_pixels: float = CELL_PIXELS) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var depth_cells := 1 if doors.size() >= 5 else DOOR_RESERVATION_DEPTH_CELLS
	for door_variant in doors:
		var door: Dictionary = door_variant
		var inside_cell: Vector2i = door.get("inside_cell", Vector2i.ZERO)
		var outward: Vector2i = door.get("outward", Vector2i.ZERO)
		var inward := -outward

		var profile_cells: Array[Vector2i] = []
		var profile_variant: Variant = door.get("opening_profile", [])
		if profile_variant is Array and not (profile_variant as Array).is_empty():
			for c in (profile_variant as Array):
				if c is Vector2i:
					profile_cells.append(c)
		if profile_cells.is_empty():
			profile_cells.append(inside_cell)

		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)

		for base_cell in profile_cells:
			for step in range(0, depth_cells + 1):
				var target_cell := base_cell + inward * step
				var center := Vector2(target_cell) * cell_pixels
				var cell_min := center - Vector2.ONE * (cell_pixels * 0.5 + DOOR_RESERVATION_MARGIN_PIXELS)
				var cell_max := center + Vector2.ONE * (cell_pixels * 0.5 + DOOR_RESERVATION_MARGIN_PIXELS)
				min_pos.x = minf(min_pos.x, cell_min.x)
				min_pos.y = minf(min_pos.y, cell_min.y)
				max_pos.x = maxf(max_pos.x, cell_max.x)
				max_pos.y = maxf(max_pos.y, cell_max.y)

		result.append(Rect2(min_pos, max_pos - min_pos))
	return result


static func validate_room_walkability(
	walkable_cells: Array,
	placed_furniture: Array,
	doors: Array,
	cell_pixels: float = CELL_PIXELS
) -> bool:
	if walkable_cells.is_empty():
		return false

	var walkable_set: Dictionary = {}
	for cell_variant in walkable_cells:
		walkable_set[Vector2i(cell_variant)] = true

	var blocked_cells: Dictionary = {}
	for item in placed_furniture:
		var pos: Vector2 = item.get("position", Vector2.ZERO)
		var clearance := FURNITURE_PLAYER_CLEARANCE
		var col_r: Rect2 = item.get("collision_rect", Rect2())
		var blocked_rect: Rect2
		if col_r.size != Vector2.ZERO:
			blocked_rect = Rect2(
				pos.x + col_r.position.x - clearance,
				pos.y + col_r.position.y - clearance,
				col_r.size.x + clearance * 2.0,
				col_r.size.y + clearance * 2.0
			)
		else:
			var half: Vector2 = item.get("half_extents", Vector2(16.0, 16.0))
			blocked_rect = Rect2(
				pos.x - half.x - clearance,
				pos.y - half.y - clearance,
				(half.x + clearance) * 2.0,
				(half.y + clearance) * 2.0
			)
		var min_cx := floori(blocked_rect.position.x / cell_pixels)
		var max_cx := ceili(blocked_rect.end.x / cell_pixels)
		var min_cy := floori(blocked_rect.position.y / cell_pixels)
		var max_cy := ceili(blocked_rect.end.y / cell_pixels)
		for cx in range(min_cx, max_cx + 1):
			for cy in range(min_cy, max_cy + 1):
				var c := Vector2i(cx, cy)
				if walkable_set.has(c):
					var c_center := Vector2(c) * cell_pixels
					var c_rect := Rect2(c_center.x - 14.0, c_center.y - 14.0, 28.0, 28.0)
					if blocked_rect.intersects(c_rect):
						blocked_cells[c] = true

	var entry_cells: Array[Vector2i] = []
	for door_variant in doors:
		var door: Dictionary = door_variant
		var inside: Vector2i = door.get("inside_cell", Vector2i.ZERO)
		var outward: Vector2i = door.get("outward", Vector2i.ZERO)
		var inward := -outward

		var profile_cells: Array[Vector2i] = []
		var profile_variant: Variant = door.get("opening_profile", [])
		if profile_variant is Array and not (profile_variant as Array).is_empty():
			for c in (profile_variant as Array):
				if c is Vector2i:
					profile_cells.append(c)
		if profile_cells.is_empty():
			profile_cells.append(inside)

		var found_entry := false
		for base_cell in profile_cells:
			for step in range(0, 4):
				var cand := base_cell + inward * step
				if walkable_set.has(cand) and not blocked_cells.has(cand):
					if not entry_cells.has(cand):
						entry_cells.append(cand)
					found_entry = true
					break
			if found_entry:
				break
		if not found_entry:
			return false

	if entry_cells.is_empty():
		return false

	var queue: Array[Vector2i] = [entry_cells[0]]
	var visited: Dictionary = {entry_cells[0]: true}
	var head := 0
	var DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while head < queue.size():
		var curr := queue[head]
		head += 1
		for dir in DIRS:
			var nxt := curr + dir
			if walkable_set.has(nxt) and not blocked_cells.has(nxt) and not visited.has(nxt):
				visited[nxt] = true
				queue.append(nxt)

	if entry_cells.size() >= 2:
		for i in range(1, entry_cells.size()):
			if not visited.has(entry_cells[i]):
				return false
		return true
	else:
		var required_reachable := mini(12, maxi(6, roundi(float(walkable_cells.size()) * 0.35)))
		return visited.size() >= required_reachable


static func calculate_archetype_clusters(
	archetype: String,
	room_bounds_cells: Rect2i,
	doors: Array,
	attempt: int,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var clusters: Array[Dictionary] = []
	var min_x := room_bounds_cells.position.x
	var min_y := room_bounds_cells.position.y
	var w := room_bounds_cells.size.x
	var h := room_bounds_cells.size.y
	var center := Vector2i(min_x + w / 2, min_y + h / 2)

	match archetype:
		"open_office":
			var anchor1: Vector2i
			var anchor2: Vector2i
			if attempt % 2 == 0:
				anchor1 = Vector2i(min_x + maxi(2, w / 4), min_y + maxi(2, h / 4))
				anchor2 = Vector2i(min_x + mini(w - 2, 3 * w / 4), min_y + mini(h - 2, 3 * h / 4))
			else:
				anchor1 = Vector2i(min_x + mini(w - 2, 3 * w / 4), min_y + maxi(2, h / 4))
				anchor2 = Vector2i(min_x + maxi(2, w / 4), min_y + mini(h - 2, 3 * h / 4))
			if attempt >= 2:
				anchor1 += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
				anchor2 += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			clusters.append({"center_cell": anchor1, "radius_cells": 2, "furniture_limit": 3})
			clusters.append({"center_cell": anchor2, "radius_cells": 2, "furniture_limit": 3})

		"conference", "conference_large", "meeting_small":
			var conf_center := center
			if attempt == 1:
				var offset := Vector2i.ZERO
				if not doors.is_empty():
					var d_in: Vector2i = doors[0].get("inside_cell", center)
					offset = Vector2i(signi(center.x - d_in.x), signi(center.y - d_in.y))
				conf_center += offset
			elif attempt >= 2:
				conf_center += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			clusters.append({"center_cell": conf_center, "radius_cells": 2, "furniture_limit": 6})

		"lounge", "executive":
			var is_horizontal_transit := true
			if doors.size() >= 2:
				var d1: Vector2i = doors[0].get("inside_cell", center)
				var d2: Vector2i = doors[1].get("inside_cell", center)
				if absi(d2.y - d1.y) > absi(d2.x - d1.x):
					is_horizontal_transit = false

			if is_horizontal_transit:
				var split_y: int
				if attempt % 2 == 0:
					split_y = min_y + mini(h - 2, roundi(float(h) * 0.70))
				else:
					split_y = min_y + maxi(2, roundi(float(h) * 0.30))
				var a1 := Vector2i(min_x + maxi(2, w / 4), split_y)
				var a2 := Vector2i(min_x + mini(w - 2, 3 * w / 4), split_y)
				if attempt >= 2:
					a1 += Vector2i(rng.randi_range(-1, 1), 0)
					a2 += Vector2i(rng.randi_range(-1, 1), 0)
				clusters.append({"center_cell": a1, "radius_cells": 2, "furniture_limit": 3})
				clusters.append({"center_cell": a2, "radius_cells": 2, "furniture_limit": 3})
			else:
				var split_x: int
				if attempt % 2 == 0:
					split_x = min_x + mini(w - 2, roundi(float(w) * 0.70))
				else:
					split_x = min_x + maxi(2, roundi(float(w) * 0.30))
				var a1 := Vector2i(split_x, min_y + maxi(2, h / 4))
				var a2 := Vector2i(split_x, min_y + mini(h - 2, 3 * h / 4))
				if attempt >= 2:
					a1 += Vector2i(0, rng.randi_range(-1, 1))
					a2 += Vector2i(0, rng.randi_range(-1, 1))
				clusters.append({"center_cell": a1, "radius_cells": 2, "furniture_limit": 3})
				clusters.append({"center_cell": a2, "radius_cells": 2, "furniture_limit": 3})

		"storage", "archive":
			var door_edges: Dictionary = {}
			for d_variant in doors:
				var out_v: Vector2i = d_variant.get("outward", Vector2i.ZERO)
				if out_v.y < 0:
					door_edges["north"] = true
				elif out_v.y > 0:
					door_edges["south"] = true
				elif out_v.x < 0:
					door_edges["west"] = true
				elif out_v.x > 0:
					door_edges["east"] = true

			var target_edges: Array[String] = []
			for edge_name in ["north", "south", "west", "east"]:
				if not door_edges.has(edge_name):
					target_edges.append(edge_name)
			if target_edges.is_empty():
				target_edges = ["north", "south"]

			var chosen_edge: String = target_edges[attempt % target_edges.size()]
			match chosen_edge:
				"north":
					var a1 := Vector2i(min_x + maxi(2, w / 3), min_y + 1)
					var a2 := Vector2i(min_x + mini(w - 2, 2 * w / 3), min_y + 1)
					clusters.append({"center_cell": a1, "radius_cells": 2, "furniture_limit": 3})
					clusters.append({"center_cell": a2, "radius_cells": 2, "furniture_limit": 3})
				"south":
					var a1 := Vector2i(min_x + maxi(2, w / 3), min_y + h - 2)
					var a2 := Vector2i(min_x + mini(w - 2, 2 * w / 3), min_y + h - 2)
					clusters.append({"center_cell": a1, "radius_cells": 2, "furniture_limit": 3})
					clusters.append({"center_cell": a2, "radius_cells": 2, "furniture_limit": 3})
				"west":
					var a1 := Vector2i(min_x + 1, min_y + maxi(2, h / 3))
					var a2 := Vector2i(min_x + 1, min_y + mini(h - 2, 2 * h / 3))
					clusters.append({"center_cell": a1, "radius_cells": 2, "furniture_limit": 3})
					clusters.append({"center_cell": a2, "radius_cells": 2, "furniture_limit": 3})
				"east":
					var a1 := Vector2i(min_x + w - 2, min_y + maxi(2, h / 3))
					var a2 := Vector2i(min_x + w - 2, min_y + mini(h - 2, 2 * h / 3))
					clusters.append({"center_cell": a1, "radius_cells": 2, "furniture_limit": 3})
					clusters.append({"center_cell": a2, "radius_cells": 2, "furniture_limit": 3})

		"security":
			var best_corner := Vector2i(min_x + 2, min_y + 2)
			var max_dist := -1.0
			var corners: Array[Vector2i] = [
				Vector2i(min_x + 2, min_y + 2),
				Vector2i(min_x + w - 3, min_y + 2),
				Vector2i(min_x + 2, min_y + h - 3),
				Vector2i(min_x + w - 3, min_y + h - 3)
			]
			for c in corners:
				var min_d_door := 9999.0
				for d_var in doors:
					var d_in: Vector2i = d_var.get("inside_cell", center)
					min_d_door = minf(min_d_door, float(c.distance_to(d_in)))
				if min_d_door > max_dist:
					max_dist = min_d_door
					best_corner = c
			if attempt >= 1:
				best_corner += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			clusters.append({"center_cell": best_corner, "radius_cells": 2, "furniture_limit": 4})

		"lobby":
			var c1 := Vector2i(min_x + 2, min_y + 2)
			var c2 := Vector2i(min_x + w - 3, min_y + h - 3)
			clusters.append({"center_cell": c1, "radius_cells": 2, "furniture_limit": 1})
			clusters.append({"center_cell": c2, "radius_cells": 2, "furniture_limit": 1})

		_:
			clusters.append({"center_cell": center, "radius_cells": 2, "furniture_limit": 4})

	return clusters


static func _resolve_prop_scene(prop_key: String, available_scenes: Array) -> PackedScene:
	if _resolved_scene_cache.has(prop_key):
		return _resolved_scene_cache[prop_key]

	var file_fragment: String = ""
	match prop_key:
		"desk": file_fragment = "desk.tscn"
		"office_chair": file_fragment = "office_chair_01.tscn"
		"chair": file_fragment = "chair"
		"small_table": file_fragment = "small_table_01.tscn"
		"filing_cabinet": file_fragment = "filing_cabinet_01.tscn"
		"trash_can": file_fragment = "trash_can_01.tscn"
		"storage_cabinet": file_fragment = "storage_cabinet_01.tscn"
		"fridge": file_fragment = "fridge_01.tscn"
		"parcel_box": file_fragment = "parcel_box_01.tscn"
		"sticker_box": file_fragment = "sticker_parcel_box_01.tscn"
		"side_table": file_fragment = "side_table_01.tscn"
		"wardrobe": file_fragment = "wardrobe_01.tscn"
		_: file_fragment = prop_key

	for sc in available_scenes:
		if sc is PackedScene and sc.resource_path.find(file_fragment) != -1:
			_resolved_scene_cache[prop_key] = sc
			return sc

	var default_paths := {
		"desk": "res://scenes/dream/props/desk.tscn",
		"office_chair": "res://scenes/dream/props/office_chair_01.tscn",
		"chair": "res://scenes/dream/props/office_chair_01.tscn",
		"small_table": "res://scenes/dream/props/small_table_01.tscn",
		"filing_cabinet": "res://scenes/dream/props/filing_cabinet_01.tscn",
		"trash_can": "res://scenes/dream/props/trash_can_01.tscn",
		"storage_cabinet": "res://scenes/dream/props/storage_cabinet_01.tscn",
		"fridge": "res://scenes/dream/props/fridge_01.tscn",
		"parcel_box": "res://scenes/dream/props/parcel_box_01.tscn",
		"sticker_box": "res://scenes/dream/props/sticker_parcel_box_01.tscn",
		"side_table": "res://scenes/dream/props/side_table_01.tscn",
		"wardrobe": "res://scenes/dream/props/wardrobe_01.tscn",
	}
	if default_paths.has(prop_key):
		var path: String = default_paths[prop_key]
		if ResourceLoader.exists(path):
			var loaded := load(path) as PackedScene
			if loaded != null:
				_resolved_scene_cache[prop_key] = loaded
				return loaded

	if not available_scenes.is_empty() and available_scenes[0] is PackedScene:
		return available_scenes[0] as PackedScene
	return null


static func _build_compound_unit_specs(
	archetype: String,
	room_bounds: Rect2i,
	doors: Array,
	attempt: int,
	rng: RandomNumberGenerator,
	furniture_scenes: Array
) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var min_x := room_bounds.position.x
	var min_y := room_bounds.position.y
	var w := room_bounds.size.x
	var h := room_bounds.size.y
	var center := Vector2i(min_x + w / 2, min_y + h / 2)

	match archetype:
		"open_office":
			var a1 := Vector2i(min_x + maxi(2, w / 4), min_y + maxi(2, h / 4))
			var a2 := Vector2i(min_x + mini(w - 3, 3 * w / 4), min_y + mini(h - 3, 3 * h / 4))
			if attempt >= 1:
				a1 += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
				a2 += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))

			var u1_items: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "office_chair", "offset": Vector2(0.0, 18.0)}
			]
			if attempt == 0 and w >= 10:
				u1_items.append({"prop": "filing_cabinet", "offset": Vector2(36.0, -7.0)})

			var u1_compact: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "office_chair", "offset": Vector2(0.0, 18.0)}
			]

			var u2_items: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "office_chair", "offset": Vector2(0.0, 18.0)}
			]
			if attempt == 0 and w >= 10:
				u2_items.append({"prop": "trash_can", "offset": Vector2(-32.0, -7.0)})

			var u2_compact: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "office_chair", "offset": Vector2(0.0, 18.0)}
			]

			specs.append({
				"name": "workstation_north",
				"category": "workstation",
				"priority": 10,
				"preferred_center": a1,
				"items": u1_items,
				"compact_items": u1_compact
			})
			specs.append({
				"name": "workstation_south",
				"category": "workstation",
				"priority": 9,
				"preferred_center": a2,
				"items": u2_items,
				"compact_items": u2_compact
			})

		"conference", "conference_large", "meeting_small":
			var is_horizontal := (w >= h)
			var conf_center := center
			if attempt >= 1:
				conf_center += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))

			var items: Array[Dictionary] = []
			var compact: Array[Dictionary] = []
			if is_horizontal:
				items.append({"prop": "desk", "offset": Vector2(-24.0, 0.0)})
				items.append({"prop": "desk", "offset": Vector2(24.0, 0.0)})
				items.append({"prop": "chair", "offset": Vector2(-24.0, -36.0)})
				items.append({"prop": "chair", "offset": Vector2(24.0, 18.0)})
				if attempt == 0:
					items.append({"prop": "chair", "offset": Vector2(24.0, -36.0)})
					items.append({"prop": "chair", "offset": Vector2(-24.0, 18.0)})

				compact.append({"prop": "desk", "offset": Vector2(-24.0, 0.0)})
				compact.append({"prop": "desk", "offset": Vector2(24.0, 0.0)})
				compact.append({"prop": "chair", "offset": Vector2(-24.0, -36.0)})
				compact.append({"prop": "chair", "offset": Vector2(24.0, 18.0)})
			else:
				items.append({"prop": "desk", "offset": Vector2(0.0, -18.0)})
				items.append({"prop": "desk", "offset": Vector2(0.0, 18.0)})
				items.append({"prop": "chair", "offset": Vector2(-32.0, -18.0)})
				items.append({"prop": "chair", "offset": Vector2(32.0, 18.0)})
				if attempt == 0:
					items.append({"prop": "chair", "offset": Vector2(32.0, -18.0)})
					items.append({"prop": "chair", "offset": Vector2(-32.0, 18.0)})

				compact.append({"prop": "desk", "offset": Vector2(0.0, -18.0)})
				compact.append({"prop": "desk", "offset": Vector2(0.0, 18.0)})
				compact.append({"prop": "chair", "offset": Vector2(-32.0, -18.0)})
				compact.append({"prop": "chair", "offset": Vector2(32.0, 18.0)})

			specs.append({
				"name": "conference_table",
				"category": "conference_table",
				"priority": 10,
				"preferred_center": conf_center,
				"items": items,
				"compact_items": compact
			})

		"lounge", "executive":
			var seat_center := Vector2i(min_x + maxi(2, w / 3), min_y + h / 2)
			var tea_center := Vector2i(min_x + mini(w - 2, 3 * w / 4), min_y + maxi(2, h / 4))
			if attempt >= 1:
				seat_center += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
				tea_center += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))

			var seating_items: Array[Dictionary] = [
				{"prop": "small_table", "offset": Vector2.ZERO},
				{"prop": "chair", "offset": Vector2(-28.0, 0.0)},
				{"prop": "chair", "offset": Vector2(28.0, 0.0)}
			]
			var seating_compact: Array[Dictionary] = [
				{"prop": "small_table", "offset": Vector2.ZERO},
				{"prop": "chair", "offset": Vector2(-28.0, 0.0)}
			]
			var tea_items: Array[Dictionary] = [
				{"prop": "fridge", "offset": Vector2.ZERO},
				{"prop": "trash_can", "offset": Vector2(22.0, 0.0)}
			]
			var tea_compact: Array[Dictionary] = [
				{"prop": "fridge", "offset": Vector2.ZERO}
			]
			specs.append({
				"name": "seating_cluster",
				"category": "seating",
				"priority": 10,
				"preferred_center": seat_center,
				"items": seating_items,
				"compact_items": seating_compact
			})
			specs.append({
				"name": "tea_corner",
				"category": "tea_corner",
				"priority": 6,
				"preferred_center": tea_center,
				"items": tea_items,
				"compact_items": tea_compact
			})

		"storage", "archive":
			var rack_center := Vector2i(min_x + maxi(2, w / 3), min_y + 1)
			var cargo_center := Vector2i(min_x + mini(w - 2, 2 * w / 3), min_y + mini(h - 2, 2 * h / 3))
			if attempt >= 1:
				rack_center += Vector2i(rng.randi_range(-1, 1), 0)
				cargo_center += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))

			var rack_items: Array[Dictionary] = [
				{"prop": "storage_cabinet", "offset": Vector2(-22.0, 0.0)},
				{"prop": "storage_cabinet", "offset": Vector2(22.0, 0.0)}
			]
			var rack_compact: Array[Dictionary] = [
				{"prop": "storage_cabinet", "offset": Vector2.ZERO}
			]
			var cargo_items: Array[Dictionary] = [
				{"prop": "parcel_box", "offset": Vector2.ZERO},
				{"prop": "sticker_box", "offset": Vector2(18.0, 0.0)}
			]
			if attempt == 0:
				cargo_items.append({"prop": "parcel_box", "offset": Vector2(0.0, 14.0)})

			var cargo_compact: Array[Dictionary] = [
				{"prop": "parcel_box", "offset": Vector2.ZERO},
				{"prop": "sticker_box", "offset": Vector2(18.0, 0.0)}
			]

			specs.append({
				"name": "storage_rack",
				"category": "storage",
				"priority": 8,
				"preferred_center": rack_center,
				"items": rack_items,
				"compact_items": rack_compact
			})
			specs.append({
				"name": "cargo_cluster",
				"category": "storage",
				"priority": 7,
				"preferred_center": cargo_center,
				"items": cargo_items,
				"compact_items": cargo_compact
			})

		"security":
			var sec_center := Vector2i(min_x + maxi(2, w / 3), min_y + maxi(2, h / 3))
			var sec_items: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "office_chair", "offset": Vector2(0.0, 18.0)},
				{"prop": "filing_cabinet", "offset": Vector2(36.0, -7.0)}
			]
			var sec_compact: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "office_chair", "offset": Vector2(0.0, 18.0)}
			]
			specs.append({
				"name": "security_post",
				"category": "security",
				"priority": 10,
				"preferred_center": sec_center,
				"items": sec_items,
				"compact_items": sec_compact
			})

		"manager":
			specs.append(_office_unit("manager_desk", center, ["desk", "office_chair", "filing_cabinet"]))
		"small_office":
			specs.append(_office_unit("private_desk", center, ["desk", "office_chair"]))
		"pantry":
			specs.append(_office_unit("pantry_counter", Vector2i(center.x, min_y + 2), ["fridge", "small_table", "trash_can"]))
		"restroom":
			specs.append(_office_unit("restroom_divider", Vector2i(center.x, min_y + 2), ["storage_cabinet", "trash_can"]))
		"printing":
			specs.append(_office_unit("print_station", Vector2i(center.x, min_y + 2), ["storage_cabinet", "sticker_box"]))
		"reception":
			specs.append(_office_unit("reception_desk", center, ["desk", "office_chair"]))
		"server":
			specs.append(_office_unit("server_racks", Vector2i(center.x, min_y + 2), ["storage_cabinet", "storage_cabinet"]))

		_:
			var def_center := center
			var def_items: Array[Dictionary] = [
				{"prop": "desk", "offset": Vector2.ZERO},
				{"prop": "chair", "offset": Vector2(0.0, 18.0)}
			]
			specs.append({
				"name": "primary_unit",
				"category": "general",
				"priority": 10,
				"preferred_center": def_center,
				"items": def_items,
				"compact_items": def_items
			})

	return specs


static func _office_unit(name: String, center: Vector2i, props: Array[String]) -> Dictionary:
	var items: Array[Dictionary] = []
	for i in props.size():
		items.append({"prop": props[i], "offset": Vector2(float(i) * 38.0, 0.0)})
	return {"name": name, "category": name, "priority": 10,
		"preferred_center": center, "items": items,
		"compact_items": [items[0]] if not items.is_empty() else []}


static func _is_tall_office_prop(scene: PackedScene) -> bool:
	var path := scene.resource_path.to_lower()
	return "cabinet" in path or "wardrobe" in path or "fridge" in path


static func _try_place_furniture(
	archetype: String,
	room_bounds: Rect2i,
	usable_cells: Array,
	walkable_cells: Array,
	doors: Array,
	door_reservation_rects: Array[Rect2],
	room_bounds_pixels: Rect2,
	furniture_scenes: Array,
	desired_count: int,
	attempt: int,
	rng: RandomNumberGenerator,
	cell_pixels: float = CELL_PIXELS,
	out_functional_areas: Array = []
) -> Array[Dictionary]:
	if desired_count <= 0 or furniture_scenes.is_empty():
		return []

	var usable_set: Dictionary = {}
	for cell_variant in usable_cells:
		usable_set[Vector2i(cell_variant)] = true

	var placed: Array[Dictionary] = []
	var placed_cells: Dictionary = {}

	var spiral_offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1),
		Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2),
		Vector2i(2, 1), Vector2i(-2, 1), Vector2i(1, 2), Vector2i(-1, 2)
	]
	if attempt >= 1:
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var off := Vector2i(dx, dy)
				if not spiral_offsets.has(off):
					spiral_offsets.append(off)

	# 1. First attempt: place compound functional units atomically with compact fallback
	if attempt < 3:
		var specs := _build_compound_unit_specs(archetype, room_bounds, doors, attempt, rng, furniture_scenes)
		for unit_spec in specs:
			if placed.size() >= desired_count:
				break

			var pref_center: Vector2i = unit_spec.get("preferred_center", room_bounds.position)
			var full_items_spec: Array = unit_spec.get("items", [])
			var compact_items_spec: Array = unit_spec.get("compact_items", [])
			if full_items_spec.is_empty():
				continue

			var candidate_lists_to_try: Array[Array] = [full_items_spec]
			if not compact_items_spec.is_empty():
				candidate_lists_to_try.append(compact_items_spec)

			var shuffled_offsets := spiral_offsets.duplicate()
			for i in range(shuffled_offsets.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp: Vector2i = shuffled_offsets[i]
				shuffled_offsets[i] = shuffled_offsets[j]
				shuffled_offsets[j] = tmp

			var unit_placed := false
			for offset in shuffled_offsets:
				if unit_placed:
					break
				var candidate_center: Vector2i = pref_center + offset
				if not usable_set.has(candidate_center):
					continue
				if placed_cells.has(candidate_center):
					continue

				var base_pos := Vector2(candidate_center) * cell_pixels

				for items_spec in candidate_lists_to_try:
					if placed.size() + items_spec.size() > desired_count:
						continue

					var candidate_items: Array[Dictionary] = []
					var conflict := false

					for item_info in items_spec:
						var prop_key: String = item_info.get("prop", "")
						var rel_offset: Vector2 = item_info.get("offset", Vector2.ZERO)
						var scene := _resolve_prop_scene(prop_key, furniture_scenes)
						if scene == null:
							conflict = true
							break

						var col_rect := get_furniture_collision_rect(scene)
						var half := get_furniture_half_extents(scene)
						var item_pos := base_pos + rel_offset
						var item_world_rect := Rect2(item_pos + col_rect.position, col_rect.size)

						if not room_bounds_pixels.encloses(item_world_rect.grow(2.0)):
							conflict = true
							break
						if _is_tall_office_prop(scene) and item_world_rect.end.y > room_bounds_pixels.end.y - 3.0 * cell_pixels:
							conflict = true
							break

						for d_rect in door_reservation_rects:
							if item_world_rect.intersects(d_rect):
								conflict = true
								break
						if conflict:
							break

						for existing in placed:
							var ex_world_rect: Rect2 = existing.get("world_rect", Rect2())
							if item_world_rect.intersects(ex_world_rect.grow(1.5)):
								conflict = true
								break
						if conflict:
							break

						# Intra-unit collision check: candidate items within the same unit must not overlap
						for prev_ci in candidate_items:
							var prev_world_rect: Rect2 = prev_ci.get("world_rect", Rect2())
							if item_world_rect.intersects(prev_world_rect.grow(1.5)):
								conflict = true
								break
						if conflict:
							break

						candidate_items.append({
							"scene": scene,
							"scene_path": scene.resource_path,
							"position": item_pos,
							"half_extents": half,
							"collision_rect": col_rect,
							"world_rect": item_world_rect
						})

					if conflict:
						continue

					# Check BFS walkability tentatively
					var tentative_placed := placed.duplicate()
					for ci in candidate_items:
						tentative_placed.append(ci)

					if validate_room_walkability(walkable_cells, tentative_placed, doors, cell_pixels):
						for ci in candidate_items:
							placed.append(ci)
						placed_cells[candidate_center] = true
						out_functional_areas.append({
							"name": unit_spec.get("name", "compound_unit"),
							"category": unit_spec.get("category", "general"),
							"center_cell": candidate_center,
							"center_pos": base_pos,
							"priority": int(unit_spec.get("priority", 5))
						})
						unit_placed = true
						break

	# 2. Supplementary individual placement if more items are needed or fallback
	if placed.size() < maxi(1, desired_count - 1):
		var clusters := calculate_archetype_clusters(archetype, room_bounds, doors, attempt, rng)
		var cluster_idx := 0
		var needed := desired_count

		for _step in range(needed * 8):
			if placed.size() >= needed:
				break
			if clusters.is_empty():
				break

			var cluster: Dictionary = clusters[cluster_idx % clusters.size()]
			var center_cell: Vector2i = cluster.get("center_cell", room_bounds.position)

			var scene: PackedScene = furniture_scenes[rng.randi_range(0, furniture_scenes.size() - 1)]
			var half := get_furniture_half_extents(scene)

			var candidate_found := false
			var candidate_pos := Vector2.ZERO
			var candidate_cell := Vector2i.ZERO

			var shuffled_offsets := spiral_offsets.duplicate()
			for i in range(shuffled_offsets.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp: Vector2i = shuffled_offsets[i]
				shuffled_offsets[i] = shuffled_offsets[j]
				shuffled_offsets[j] = tmp

			for offset in shuffled_offsets:
				var cell_to_try: Vector2i = center_cell + offset
				if not usable_set.has(cell_to_try):
					continue
				if placed_cells.has(cell_to_try):
					continue

				var pos := Vector2(cell_to_try) * cell_pixels + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
				var col_rect := get_furniture_collision_rect(scene)
				var item_world_rect := Rect2(pos + col_rect.position, col_rect.size)

				if not room_bounds_pixels.encloses(item_world_rect.grow(2.0)):
					continue
				if _is_tall_office_prop(scene) and item_world_rect.end.y > room_bounds_pixels.end.y - 3.0 * cell_pixels:
					continue

				var in_doorway := false
				for d_rect in door_reservation_rects:
					if item_world_rect.intersects(d_rect):
						in_doorway = true
						break
				if in_doorway:
					continue

				var overlaps_other := false
				for other in placed:
					var other_world_rect: Rect2 = other.get("world_rect", Rect2())
					if other_world_rect.size == Vector2.ZERO:
						var other_pos: Vector2 = other.get("position", Vector2.ZERO)
						var other_half: Vector2 = other.get("half_extents", Vector2.ZERO)
						other_world_rect = Rect2(other_pos - other_half, other_half * 2.0)
					if item_world_rect.intersects(other_world_rect.grow(1.5)):
						overlaps_other = true
						break
				if overlaps_other:
					continue

				candidate_found = true
				candidate_pos = pos
				candidate_cell = cell_to_try
				break

			if candidate_found:
				var col_rect := get_furniture_collision_rect(scene)
				var tentative := placed.duplicate()
				tentative.append({
					"scene": scene,
					"scene_path": scene.resource_path,
					"position": candidate_pos,
					"half_extents": half,
					"collision_rect": col_rect,
					"world_rect": Rect2(candidate_pos + col_rect.position, col_rect.size)
				})

				if validate_room_walkability(walkable_cells, tentative, doors, cell_pixels):
					placed.append({
						"scene": scene,
						"scene_path": scene.resource_path,
						"position": candidate_pos,
						"half_extents": half,
						"collision_rect": col_rect,
						"world_rect": Rect2(candidate_pos + col_rect.position, col_rect.size)
					})
					placed_cells[candidate_cell] = true

			cluster_idx += 1

	if placed.size() >= maxi(1, desired_count - 1):
		if validate_room_walkability(walkable_cells, placed, doors, cell_pixels):
			return placed

	return []


static func calculate_tactical_enemy_spawns(
	usable_cells: Array,
	placed_furniture: Array,
	doors: Array,
	door_reservation_rects: Array[Rect2],
	room_bounds_pixels: Rect2,
	planned_count: int,
	rng: RandomNumberGenerator,
	cell_pixels: float = CELL_PIXELS
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if planned_count <= 0 or usable_cells.is_empty():
		return result

	var primary_door_pos := Vector2.ZERO
	if not doors.is_empty():
		primary_door_pos = Vector2(doors[0].get("inside_cell", Vector2i.ZERO)) * cell_pixels
	elif not usable_cells.is_empty():
		primary_door_pos = Vector2(usable_cells[0]) * cell_pixels

	var room_center := room_bounds_pixels.get_center()

	var vantage_candidates: Array[Vector2] = []
	var flank_candidates: Array[Vector2] = []
	var depth_candidates: Array[Vector2] = []
	var general_candidates: Array[Vector2] = []

	var door_to_center := (room_center - primary_door_pos).normalized()

	for cell_variant in usable_cells:
		var cell := Vector2i(cell_variant)
		var pos := Vector2(cell) * cell_pixels

		if not room_bounds_pixels.has_point(pos):
			continue

		var near_door := false
		for d_rect in door_reservation_rects:
			if d_rect.has_point(pos) or pos.distance_to(d_rect.get_center()) < ENEMY_DOOR_CLEARANCE:
				near_door = true
				break
		if near_door:
			continue

		var near_furniture := false
		for item in placed_furniture:
			var f_pos: Vector2 = item.get("position", Vector2.ZERO)
			var f_half: Vector2 = item.get("half_extents", Vector2(16.0, 16.0))
			if pos.distance_to(f_pos) < f_half.length() + ENEMY_FURNITURE_CLEARANCE:
				near_furniture = true
				break
		if near_furniture:
			continue

		var is_vantage := false
		for item in placed_furniture:
			var f_pos: Vector2 = item.get("position", Vector2.ZERO)
			var f_half: Vector2 = item.get("half_extents", Vector2(16.0, 16.0))
			var dist := pos.distance_to(f_pos)
			if dist >= f_half.length() + ENEMY_FURNITURE_CLEARANCE and dist <= f_half.length() + 48.0:
				var to_door := (primary_door_pos - pos).normalized()
				var to_f := (f_pos - pos).normalized()
				if to_door.dot(to_f) > 0.4:
					is_vantage = true
					break
		if is_vantage:
			vantage_candidates.append(pos)

		var to_pos := (pos - room_center).normalized()
		if absf(door_to_center.cross(to_pos)) > 0.45:
			flank_candidates.append(pos)

		if pos.distance_to(primary_door_pos) > room_bounds_pixels.size.length() * 0.45:
			depth_candidates.append(pos)

		general_candidates.append(pos)

	var occupied: Array[Vector2] = []

	var _pick_best := func(pool: Array[Vector2], fallback_pool: Array[Vector2], min_dist: float) -> Vector2:
		var shuffled := pool.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Vector2 = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp
		for cand in shuffled:
			var ok := true
			for occ in occupied:
				if cand.distance_to(occ) < min_dist:
					ok = false
					break
			if ok:
				return cand

		var fallback_shuffled := fallback_pool.duplicate()
		for i in range(fallback_shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Vector2 = fallback_shuffled[i]
			fallback_shuffled[i] = fallback_shuffled[j]
			fallback_shuffled[j] = tmp
		for cand in fallback_shuffled:
			var ok := true
			for occ in occupied:
				if cand.distance_to(occ) < min_dist:
					ok = false
					break
			if ok:
				return cand
		return Vector2.INF

	for enemy_idx in range(planned_count):
		var chosen_pos := Vector2.INF
		var role := "patrol"

		if enemy_idx == 0:
			chosen_pos = _pick_best.call(vantage_candidates, general_candidates, ENEMY_MIN_SPACING)
			role = "vantage"
			if chosen_pos == Vector2.INF:
				chosen_pos = _pick_best.call(flank_candidates, general_candidates, ENEMY_MIN_SPACING)
				role = "flank"
		elif enemy_idx == 1:
			chosen_pos = _pick_best.call(flank_candidates, general_candidates, ENEMY_MIN_SPACING)
			role = "flank"
			if chosen_pos == Vector2.INF:
				chosen_pos = _pick_best.call(depth_candidates, general_candidates, ENEMY_MIN_SPACING)
				role = "depth"
		elif enemy_idx == 2:
			chosen_pos = _pick_best.call(depth_candidates, general_candidates, ENEMY_MIN_SPACING)
			role = "depth"
		else:
			chosen_pos = _pick_best.call(general_candidates, general_candidates, ENEMY_MIN_SPACING)
			role = "depth"

		if chosen_pos == Vector2.INF:
			chosen_pos = _pick_best.call(general_candidates, general_candidates, 24.0)
		if chosen_pos == Vector2.INF:
			chosen_pos = _pick_best.call(general_candidates, general_candidates, 16.0)

		if chosen_pos != Vector2.INF:
			occupied.append(chosen_pos)
			var enemy_type: StringName = &"waitress" if rng.randf() < 0.35 else &"employee"
			result.append({
				"type": enemy_type,
				"ground_position": chosen_pos,
				"role": role
			})

	return result


static func calculate_roadside_drops(
	usable_cells: Array,
	placed_furniture: Array,
	enemy_spawns: Array,
	doors: Array,
	door_reservation_rects: Array[Rect2],
	room_bounds_pixels: Rect2,
	planned_count: int,
	rng: RandomNumberGenerator,
	cell_pixels: float = CELL_PIXELS
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if planned_count <= 0 or usable_cells.is_empty():
		return result

	var candidates: Array[Vector2] = []
	for cell_variant in usable_cells:
		var cell := Vector2i(cell_variant)
		var pos := Vector2(cell) * cell_pixels

		if not room_bounds_pixels.has_point(pos):
			continue

		var near_door := false
		for d_rect in door_reservation_rects:
			if d_rect.has_point(pos) or pos.distance_to(d_rect.get_center()) < DROP_DOOR_CLEARANCE:
				near_door = true
				break
		if near_door:
			continue

		var near_furniture := false
		for item in placed_furniture:
			var f_pos: Vector2 = item.get("position", Vector2.ZERO)
			var f_half: Vector2 = item.get("half_extents", Vector2(16.0, 16.0))
			if pos.distance_to(f_pos) < f_half.length() + DROP_FURNITURE_CLEARANCE:
				near_furniture = true
				break
		if near_furniture:
			continue

		var near_enemy := false
		for e in enemy_spawns:
			var e_pos: Vector2 = e.get("ground_position", Vector2.ZERO)
			if pos.distance_to(e_pos) < 24.0:
				near_enemy = true
				break
		if near_enemy:
			continue

		candidates.append(pos)

	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2 = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var occupied: Array[Vector2] = []
	for cand in candidates:
		if result.size() >= planned_count:
			break
		var ok := true
		for occ in occupied:
			if cand.distance_to(occ) < 28.0:
				ok = false
				break
		if ok:
			occupied.append(cand)
			result.append({
				"type": &"weapon",
				"ground_position": cand
			})

	if result.size() < planned_count:
		for cand in candidates:
			if result.size() >= planned_count:
				break
			var ok := true
			for occ in occupied:
				if cand.distance_to(occ) < 16.0:
					ok = false
					break
			if ok:
				occupied.append(cand)
				result.append({
					"type": &"weapon",
					"ground_position": cand
				})

	return result


static func plan_room_layout(
	room_id: int,
	room: Dictionary,
	doors: Array,
	furniture_scenes: Array,
	desired_furniture_count: int,
	planned_enemy_count: int,
	planned_drops: int,
	room_seed: int,
	room_bounds_pixels: Rect2,
	cell_pixels: float = CELL_PIXELS
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(room_seed, 1)
	if bool(room.get("office_combat_layout", false)):
		return _plan_office_combat(room, doors, planned_enemy_count, rng, room_bounds_pixels, cell_pixels, planned_drops)

	var door_rects := get_doorway_reservation_rects(doors, cell_pixels)
	var room_bounds_cells: Rect2i = room.get("grid_rect", Rect2i())
	var usable_cells: Array = room.get("usable_cells", [])
	var shape_cells: Array = room.get("shape_cells", usable_cells)
	var walkable_cells: Array = shape_cells if not shape_cells.is_empty() else usable_cells
	var archetype: String = String(room.get("archetype", "open_office"))

	for attempt in range(MAX_ATTEMPTS):
		var functional_areas: Array[Dictionary] = []
		var furniture := _try_place_furniture(
			archetype,
			room_bounds_cells,
			usable_cells,
			walkable_cells,
			doors,
			door_rects,
			room_bounds_pixels,
			furniture_scenes,
			desired_furniture_count,
			attempt,
			rng,
			cell_pixels,
			functional_areas
		)

		if not furniture.is_empty():
			var enemies := calculate_tactical_enemy_spawns(
				usable_cells,
				furniture,
				doors,
				door_rects,
				room_bounds_pixels,
				planned_enemy_count,
				rng,
				cell_pixels
			)
			var drops := calculate_roadside_drops(
				usable_cells,
				furniture,
				enemies,
				doors,
				door_rects,
				room_bounds_pixels,
				planned_drops,
				rng,
				cell_pixels
			)

			return {
				"success": true,
				"attempt": attempt,
				"furniture_placements": furniture,
				"enemy_spawns": enemies,
				"drop_spawns": drops,
				"door_reservation_rects": door_rects,
				"functional_areas": functional_areas
			}

	# Safe fallback: if full cluster placement didn't succeed, try placing 1-2 compact items that preserve walkability
	for fallback_count in [2, 1, 0]:
		if fallback_count == 0:
			var enemies := calculate_tactical_enemy_spawns(
				usable_cells,
				[],
				doors,
				door_rects,
				room_bounds_pixels,
				planned_enemy_count,
				rng,
				cell_pixels
			)
			var drops := calculate_roadside_drops(
				usable_cells,
				[],
				enemies,
				doors,
				door_rects,
				room_bounds_pixels,
				planned_drops,
				rng,
				cell_pixels
			)
			return {
				"success": true,
				"attempt": MAX_ATTEMPTS,
				"furniture_placements": [],
				"enemy_spawns": enemies,
				"drop_spawns": drops,
				"door_reservation_rects": door_rects,
				"functional_areas": []
			}
		var fallback_areas: Array[Dictionary] = []
		var fallback_furniture := _try_place_furniture(
			archetype,
			room_bounds_cells,
			usable_cells,
			walkable_cells,
			doors,
			door_rects,
			room_bounds_pixels,
			furniture_scenes,
			fallback_count,
			MAX_ATTEMPTS - 1,
			rng,
			cell_pixels,
			fallback_areas
		)
		if not fallback_furniture.is_empty():
			var enemies := calculate_tactical_enemy_spawns(
				usable_cells,
				fallback_furniture,
				doors,
				door_rects,
				room_bounds_pixels,
				planned_enemy_count,
				rng,
				cell_pixels
			)
			var drops := calculate_roadside_drops(
				usable_cells,
				fallback_furniture,
				enemies,
				doors,
				door_rects,
				room_bounds_pixels,
				planned_drops,
				rng,
				cell_pixels
			)
			return {
				"success": true,
				"attempt": MAX_ATTEMPTS,
				"furniture_placements": fallback_furniture,
				"enemy_spawns": enemies,
				"drop_spawns": drops,
				"door_reservation_rects": door_rects,
				"functional_areas": fallback_areas
			}

	return {
		"success": false,
		"attempt": MAX_ATTEMPTS,
		"furniture_placements": [],
		"enemy_spawns": [],
		"drop_spawns": [],
		"door_reservation_rects": door_rects
	}
