extends RefCounted
## The generated floor owns durable topology; dash prediction only asks questions.
## Commits run after physics query flushing and never create a synthetic door.

static func allowed(world: Node3D) -> bool:
	if not is_instance_valid(world) or not world.is_inside_tree(): return false
	if world.lazy_room_presentation or world.floor_transition_in_progress or world.transition_in_progress: return false
	if world.transition_phase != &"IDLE" or world.run_finished or world.get_tree().paused: return false
	if not world._floor_path_cache_enabled: return false # Layout/render preparation has not committed yet.
	var player: Node = world.player
	return is_instance_valid(player) and not bool(player.get("dead")) and bool(player.get("movement_enabled"))

static func wall_for_key(world: Node3D, key: String) -> Node3D:
	if not world.wall_edges.has(key) or world.edge_states.get(key) != &"WALL": return null
	if world.broken_shared_walls.has(key): return null
	for map: Dictionary in [world.door_edges, world.door_opening_edges, world.glass_wall_edges, world.window_wall_edges]:
		if map.has(key): return null
	# Every real generated masonry wall is destructible. Floor support is the
	# phase movement controller's authority, not a reason to preserve a boundary.
	if not is_instance_valid(world.wall_root) or not is_instance_valid(world.collision_root): return null
	var suffix := key.replace(":", "_")
	var wall := world.wall_root.get_node_or_null("Wall_" + suffix) as Node3D
	var body := world.collision_root.get_node_or_null("WallCollision_" + suffix) as StaticBody2D
	if not is_instance_valid(wall) or wall.is_queued_for_deletion() or not wall.has_method("configure_wall"): return null
	if not is_instance_valid(body) or body.is_queued_for_deletion(): return null
	if String(body.get_meta(&"generated_wall_edge", "")) != key or (body.collision_layer & world.WORLD_WALL_LAYER) == 0: return null
	return wall

static func query(world: Node3D, from: Vector2, to: Vector2, body_radius: float) -> Array[String]:
	var result: Array[String] = []
	if bool(world.get_meta(&"test_disable_shared_wall_breaches",false)): return result
	if not allowed(world) or not from.is_finite() or not to.is_finite() or from.is_equal_approx(to): return result
	var cell_size: float = world.CELL_PIXELS
	var radius := maxf(0.0, body_radius)
	var margin: float = radius + world.wall_thickness * cell_size * .5
	var bounds := Rect2(from, Vector2.ZERO).expand(to).grow(margin + cell_size * .5)
	var lo := Vector2i(floori(bounds.position.x / cell_size), floori(bounds.position.y / cell_size))
	var hi := Vector2i(ceili(bounds.end.x / cell_size), ceili(bounds.end.y / cell_size))
	# Short actual movement segments touch only a handful of grid edges.
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for axis in ["H", "V"]:
				var key := "%s:%d:%d" % [axis, x, y]
				if not world.wall_edges.has(key): continue
				var edge: Dictionary = world.wall_edges[key]
				var center: Vector2 = world._edge_gameplay_position(edge)
				var half_size := Vector2(cell_size * .5, world._architectural_wall_thickness(edge) * cell_size * .5)
				if axis == "V": half_size = Vector2(half_size.y, half_size.x)
				if not _sweep_hits_rect(from, to, Rect2(center - half_size, half_size * 2.0), radius): continue
				if wall_for_key(world, key) != null: result.append(key)
	return result

static func _sweep_hits_rect(from: Vector2, to: Vector2, bounds: Rect2, radius: float) -> bool:
	if not _segment_hits_rect(from, to, bounds.grow(radius)): return false
	if _segment_hits_rect(from, to, bounds): return true
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for index in 4:
		var closest := Geometry2D.get_closest_points_between_segments(from, to, corners[index], corners[(index + 1) % 4])
		if closest[0].distance_squared_to(closest[1]) <= radius * radius: return true
	return false

static func _segment_hits_rect(from: Vector2, to: Vector2, bounds: Rect2) -> bool:
	var step := to - from
	var first := 0.0
	var last := 1.0
	for axis in 2:
		if absf(step[axis]) < .00001:
			if from[axis] < bounds.position[axis] or from[axis] > bounds.end[axis]: return false
			continue
		var a: float = (bounds.position[axis] - from[axis]) / step[axis]
		var b: float = (bounds.end[axis] - from[axis]) / step[axis]
		first = maxf(first, minf(a, b))
		last = minf(last, maxf(a, b))
		if first > last: return false
	return true

static func edges_between(world: Node3D, a: int, b: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in world.dash_breach_links.values():
		if (int(record.a) == a and int(record.b) == b) or (int(record.a) == b and int(record.b) == a):
			result.append(record.edge)
	return result

static func register_open_edge(world: Node3D, key: String, edge: Dictionary, refresh_caches: bool = true) -> void:
	if edge.is_empty() or world._edge_key(edge) != key or world.edge_states.get(key) != &"OPEN": return
	if world.wall_edges.has(key) or world.door_edges.has(key): return
	var sides: Array = world._edge_side_cells(edge)
	if sides.size() != 2 or not world.floor_cells.has(sides[0]) or not world.floor_cells.has(sides[1]): return
	var a: int = int(world.room_cells.get(sides[0], -1))
	var b: int = int(world.room_cells.get(sides[1], -1))
	if a < 0 or b < 0 or a >= world.rooms.size() or b >= world.rooms.size() or a == b: return
	world.dash_breach_links[key] = {"edge": edge.duplicate(true), "a": a, "b": b, "rooms": [a, b]}
	for pair in [[a, b], [b, a]]:
		world._add_room_connection(int(pair[0]), int(pair[1]))
		var room: Dictionary = world.rooms[int(pair[0])]
		if room.has("neighbors") and not room.neighbors.has(pair[1]): room.neighbors.append(pair[1])
	if refresh_caches:
		world._open_connected_rooms_cache.clear()
		world._open_boundary_edges_cache.clear()
		world.employee_path_cache.clear()
		world._current_floor_path_adjacency()

static func commit(world: Node3D, keys: Array, token: int, direction: Vector2) -> int:
	if token != world.get_current_floor_token() or not allowed(world): return 0
	var profiling := bool(world.get_meta(&"test_profile_shared_wall_breach", false))
	var commit_started := Time.get_ticks_usec() if profiling else 0
	var profile := {"requested": keys.size(), "wall_count": world.wall_edges.size(), "effect_usec": 0, "fixtures_usec": 0, "remove_usec": 0}
	if profiling: world.last_shared_wall_breach_profile = profile
	var removed := 0
	for key_variant in keys:
		var key := String(key_variant)
		var wall := wall_for_key(world, key)
		if wall == null: continue
		var edge: Dictionary = world.wall_edges[key].duplicate(true)
		var sides: Array = world._edge_side_cells(edge)
		var a: int = int(world.room_cells.get(sides[0], -1))
		var b: int = int(world.room_cells.get(sides[1], -1))
		var started := Time.get_ticks_usec() if profiling else 0
		# Capture the approved face/material before the supporting wall is freed.
		if not bool(world.get_meta(&"test_disable_shared_wall_vfx",false)):
			preload("res://scripts/dream/shared_wall_break_effect.gd").spawn(world, wall, direction)
		if profiling:
			profile.effect_usec += Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
		world._remove_shared_wall_fixtures(wall)
		_forget_visibility_wall(world, wall)
		if profiling:
			profile.fixtures_usec += Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
		var batches: Node = world.wall_root.get_node_or_null("WallShadowBatches")
		if is_instance_valid(batches) and batches.has_method("remove_edge"): batches.remove_edge(key)
		wall.free()
		for body in world.collision_root.get_children():
			if String(body.get_meta(&"generated_wall_edge", "")) == key or String(body.get_meta(&"generated_air_wall_edge", "")) == key:
				body.free()
		world.wall_edges.erase(key)
		world.internal_wall_edges.erase(key)
		world.edge_states[key] = &"OPEN"
		var record := {"edge": edge, "a": a, "b": b, "rooms": [a, b]}
		world.broken_shared_walls[key] = record.duplicate(true)
		register_open_edge(world, key, edge, false)
		if profiling: profile.remove_usec += Time.get_ticks_usec() - started
		removed += 1
	if removed > 0:
		var started := Time.get_ticks_usec() if profiling else 0
		world._open_connected_rooms_cache.clear()
		world._open_boundary_edges_cache.clear()
		world.employee_path_cache.clear()
		world._current_floor_path_adjacency()
		if profiling:
			profile["navigation_usec"] = Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
		world._refresh_shared_wall_breach_presentation()
		if profiling: profile["presentation_usec"] = Time.get_ticks_usec() - started
	if profiling:
		profile["removed"] = removed
		profile["total_usec"] = Time.get_ticks_usec() - commit_started
		print("SHARED_WALL_BREACH_PROFILE ", JSON.stringify(profile))
	return removed

static func _forget_visibility_wall(world: Node3D, wall: Node3D) -> void:
	var visibility: Node = world.room_visibility
	if not is_instance_valid(visibility): return
	for property in ["near_walls", "near_corridor_walls"]:
		var entries: Dictionary = visibility.get(property)
		for walls: Array in entries.values(): walls.erase(wall)
	for property in ["_near_wall_ids", "_near_corridor_wall_ids"]:
		var entries: Dictionary = visibility.get(property)
		for ids: Dictionary in entries.values(): ids.erase(wall.get_instance_id())
