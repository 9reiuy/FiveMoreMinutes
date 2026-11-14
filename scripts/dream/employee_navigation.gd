extends RefCounted
## Gameplay navigation uses the same body and collision world as locomotion.
## Floor connectivity alone cannot see furniture, moving leaves or wall corners.
const STEP := 16.0
const FLOOR_STEP := 32.0
const STATIC_MASK := 1 | 4 | 8 | 32
const MAX_CACHE_MSEC := 700
const MAX_SEARCHES_PER_PHYSICS_FRAME := 2

class WalkGraph extends AStar2D:
	var navigator: WeakRef
	func _filter_neighbor(from_id: int, to_id: int) -> bool:
		return not navigator.get_ref()._graph_edge_clear(from_id,to_id)

var graph: WalkGraph
var point_ids: Dictionary = {}
var floor_revision := -1
var floor_count := -1
var world_ref: WeakRef
var actor: CharacterBody2D
var body: CollisionShape2D
var body_transform := Transform2D.IDENTITY
var body_offset := Vector2.ZERO
var body_radius := 7.0
var space: PhysicsDirectSpaceState2D
var query := PhysicsShapeQueryParameters2D.new()
var point_clear: Dictionary = {}
var edge_clear: Dictionary = {}
var searches := 0
var sweep_queries := 0
var search_usec := 0
var max_search_usec := 0
var graph_build_usec := 0
var _search_frame := -1
var _frame_searches := 0

func _prepare(world: Node, employee: CharacterBody2D) -> bool:
	world_ref = weakref(world)
	actor = employee
	body = employee.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null or body.shape == null or not employee.is_inside_tree(): return false
	space = employee.get_world_2d().direct_space_state
	query.shape = body.shape
	query.exclude = [employee.get_rid()]
	# Characters are handled by steering and move_and_slide, not baked into the
	# static route. In particular a chase destination can be Player's position.
	var player: Variant = world.get("player")
	if is_instance_valid(player) and player is CollisionObject2D:
		query.exclude = [employee.get_rid(),player.get_rid()]
	body_transform = body.global_transform
	body_offset = body_transform.origin-employee.global_position
	body_radius = body.shape.radius * maxf(body.global_scale.x,body.global_scale.y) if body.shape is CircleShape2D else 7.0
	query.collision_mask = employee.collision_mask & STATIC_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.35
	return true

func _transform_at(point: Vector2) -> Transform2D:
	var transform := body_transform
	transform.origin = point+body_offset
	return transform

func _floor_clear(point: Vector2) -> bool:
	var world: Node = world_ref.get_ref()
	var center := point+body_offset
	# Account for the feet collider's actual offset and width, not a center ray.
	var radius := body_radius
	for offset in [Vector2.ZERO,Vector2.LEFT*radius,Vector2.RIGHT*radius,Vector2.UP*radius,Vector2.DOWN*radius]:
		if not world.floor_cells.has(Vector2i(((center+offset)/FLOOR_STEP).round())): return false
	return true

func _floor_segment_clear(from: Vector2, to: Vector2) -> bool:
	var world: Node = world_ref.get_ref()
	var previous := Vector2i((from/FLOOR_STEP).round())
	var steps := maxi(1,ceili(from.distance_to(to)/8.0))
	for i in range(steps+1):
		var point := from.lerp(to,float(i)/steps)
		if not _floor_clear(point): return false
		var cell := Vector2i((point/FLOOR_STEP).round())
		if cell == previous: continue
		if cell.x != previous.x and cell.y != previous.y:
			var corner_x := Vector2i(cell.x,previous.y)
			var corner_y := Vector2i(previous.x,cell.y)
			if not (world._can_cross_floor_edge(previous,corner_x,false) and world._can_cross_floor_edge(corner_x,cell,false)
				and world._can_cross_floor_edge(previous,corner_y,false) and world._can_cross_floor_edge(corner_y,cell,false)): return false
		elif not world._can_cross_floor_edge(previous,cell,false): return false
		previous = cell
	return true

func _can_walk(from: Vector2, to: Vector2) -> bool:
	query.transform = _transform_at(from)
	query.motion = to-from
	sweep_queries += 1
	var fraction := space.cast_motion(query)
	if fraction.size() < 2 or fraction[0] < 0.999: return false
	query.transform = _transform_at(to)
	query.motion = Vector2.ZERO
	if not space.intersect_shape(query,1).is_empty(): return false
	return _floor_segment_clear(from,to)

func is_segment_clear(world: Node, employee: CharacterBody2D, from: Vector2, to: Vector2) -> bool:
	return _prepare(world,employee) and _can_walk(from,to)

func is_position_clear(world: Node, employee: CharacterBody2D, point: Vector2) -> bool:
	if not _prepare(world,employee) or not _floor_clear(point): return false
	query.transform = _transform_at(point); query.motion = Vector2.ZERO
	return space.intersect_shape(query,1).is_empty()

func _ensure_graph(world: Node) -> void:
	if graph != null and floor_revision == world._layout_generation and floor_count == world.floor_cells.size(): return
	var started := Time.get_ticks_usec()
	floor_revision = world._layout_generation; floor_count = world.floor_cells.size()
	graph = WalkGraph.new(); graph.navigator = weakref(self)
	graph.neighbor_filter_enabled = true
	point_ids.clear()
	for floor_cell: Vector2i in world.floor_cells:
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
			var cell: Vector2i = floor_cell*2+offset
			if point_ids.has(cell) or not world.floor_cells.has(Vector2i((Vector2(cell)/2.0).round())): continue
			var id := point_ids.size()
			point_ids[cell] = id; graph.add_point(id,Vector2(cell)*STEP)
	for cell: Vector2i in point_ids:
		for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
			if point_ids.has(cell+direction): graph.connect_points(point_ids[cell],point_ids[cell+direction])
	graph_build_usec += Time.get_ticks_usec()-started

func _graph_point_clear(id: int) -> bool:
	if point_clear.has(id): return point_clear[id]
	var point := graph.get_point_position(id)
	var world: Node = world_ref.get_ref()
	var own_room: int = int(actor.get_meta(&"dream_room_id",-1))
	var room: int = world._room_id_at_position(point)
	var in_transit: bool = actor.state == actor.State.ROOM_TRANSIT
	var transit_room: int = actor.route_target_room_id
	var allowed: bool = room >= 0 and (room == own_room or world.are_rooms_openly_connected(own_room,room)
		or (in_transit and room in [transit_room,actor.previous_room_id]))
	if in_transit and room < 0:
		var source_room: int = actor.previous_room_id if own_room == transit_room else own_room
		var connection: Dictionary = world._connection_between_rooms(source_room,transit_room)
		allowed = int(connection.get("corridor_id",-2)) == world.get_corridor_id_at_position(point)
	if allowed:
		query.transform = _transform_at(point); query.motion = Vector2.ZERO
		allowed = _floor_clear(point) and space.intersect_shape(query,1).is_empty()
	point_clear[id] = allowed
	return allowed

func _graph_edge_clear(from_id: int, to_id: int) -> bool:
	var key := Vector2i(mini(from_id,to_id),maxi(from_id,to_id))
	if edge_clear.has(key): return edge_clear[key]
	var clear := _graph_point_clear(to_id) and _graph_point_clear(from_id) and _can_walk(graph.get_point_position(from_id),graph.get_point_position(to_id))
	edge_clear[key] = clear
	return clear

func _nearby_point(point: Vector2, must_connect: bool) -> int:
	var cell := Vector2i((point/STEP).round())
	var best := -1
	var distance := INF
	# A goal inside furniture is projected to reachable free floor nearby.
	for y in range(-3,4):
		for x in range(-3,4):
			var id: int = point_ids.get(cell+Vector2i(x,y),-1)
			if id < 0: continue
			var candidate := graph.get_point_position(id)
			var candidate_distance := candidate.distance_squared_to(point)
			if candidate_distance >= distance or not _graph_point_clear(id): continue
			if must_connect and not _can_walk(point,candidate): continue
			best = id; distance = candidate_distance
	return best

func next_target(world: Node, employee: CharacterBody2D, destination: Vector2, cache: Dictionary) -> Vector2:
	if not _prepare(world,employee): return employee.global_position
	var origin := employee.global_position
	if _can_walk(origin,destination): return destination
	_ensure_graph(world)
	var id := employee.get_instance_id()
	var finish := Vector2i((destination/STEP).round())
	var now := Time.get_ticks_msec()
	var entry: Dictionary = cache.get(id,{})
	var path: PackedVector2Array = entry.get("path",PackedVector2Array())
	var index: int = entry.get("index",0)
	while index < path.size() and origin.distance_to(path[index]) <= 5.0: index += 1
	var stale: bool = entry.get("finish") != finish or entry.get("revision",-1) != floor_revision
	# A body-clear route does not expire merely because 700ms have elapsed.
	# Retry exhausted/partial routes; geometry changes are checked each step.
	if index >= path.size(): stale = stale or now-int(entry.get("time",0)) > MAX_CACHE_MSEC
	if not stale and index < path.size(): stale = not _can_walk(origin,path[index])
	if stale or entry.is_empty():
		var physics_frame := Engine.get_physics_frames()
		if _search_frame != physics_frame: _search_frame = physics_frame; _frame_searches = 0
		if _frame_searches >= MAX_SEARCHES_PER_PHYSICS_FRAME:
			return path[index] if index < path.size() and _can_walk(origin,path[index]) else origin
		_frame_searches += 1
		var started := Time.get_ticks_usec()
		point_clear.clear(); edge_clear.clear()
		var start_id := _nearby_point(origin,true)
		var finish_id := _nearby_point(destination,false)
		path = PackedVector2Array(); index = 0
		if start_id >= 0 and finish_id >= 0:
			searches += 1
			path = graph.get_point_path(start_id,finish_id,true)
		var elapsed := Time.get_ticks_usec()-started
		search_usec += elapsed; max_search_usec = maxi(max_search_usec,elapsed)
		entry = {"finish":finish,"revision":floor_revision,"time":now,"path":path}
		while index < path.size() and origin.distance_to(path[index]) <= 5.0: index += 1
	# String-pull only through body-clear segments. Never cut a wall corner.
	var next := origin
	if index < path.size() and _can_walk(origin,path[index]):
		next = path[index]
		for farther in range(index+1,mini(index+9,path.size())):
			if not _can_walk(origin,path[farther]): break
			next = path[farther]; index = farther
	entry["index"] = index; cache[id] = entry
	return next # A failed path holds at safe floor instead of walking at a wall.
