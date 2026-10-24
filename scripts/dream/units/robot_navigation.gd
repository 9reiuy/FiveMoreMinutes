extends RefCounted
## One indoor robot: bounded, real-collision navigation, no navigation-only walls.
static func clear(unit: CharacterBody2D, point: Vector2) -> bool:
	if not unit.bounds.has_point(point): return false
	var radius: float=15.0*unit.SIZE_RATIO
	for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		if not unit.world.floor_cells.has(Vector2i(((point+offset*radius)/32.0).round())): return false
	if unit._nav_query==null:
		unit._nav_query=PhysicsShapeQueryParameters2D.new()
		var shape:=CircleShape2D.new(); shape.radius=radius
		unit._nav_query.shape=shape
	var query: PhysicsShapeQueryParameters2D=unit._nav_query
	query.transform=Transform2D(0,point); query.collision_mask=1|4|8
	query.exclude=[unit.get_rid()]; query.collide_with_areas=false
	return unit.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

static func path(unit: CharacterBody2D, destination: Vector2) -> Array[Vector2]:
	var start:=Vector2i((unit.global_position/32.0).round())
	var desired:=Vector2i((destination/32.0).round())
	var queue: Array[Vector2i]=[start]
	var visited: Dictionary={start:start}
	var best:=start
	var index:=0
	var passable: Dictionary={}
	while index<queue.size() and index<1024:
		var cell:=queue[index]; index+=1
		if cell.distance_squared_to(desired)<best.distance_squared_to(desired): best=cell
		if cell==desired: break
		for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=cell+step
			if visited.has(next) or not unit.world.floor_cells.has(next): continue
			if not passable.has(next): passable[next]=clear(unit,Vector2(next)*32.0)
			if not passable[next]: continue
			if not unit.world._can_cross_floor_edge(cell,next,false): continue
			visited[next]=cell; queue.append(next)
	var result: Array[Vector2]=[]
	while best!=start:
		result.push_front(Vector2(best)*32.0); best=visited[best]
	return result
