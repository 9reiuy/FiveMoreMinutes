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
	query.transform=Transform2D(0,point); query.motion=Vector2.ZERO; query.collision_mask=1|4|8|32
	query.exclude=[unit.get_rid()]; query.collide_with_areas=false
	return unit.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

static func segment_clear(unit: CharacterBody2D, from: Vector2, to: Vector2) -> bool:
	if not clear(unit,to): return false
	var query: PhysicsShapeQueryParameters2D=unit._nav_query
	query.transform=Transform2D(0,from); query.motion=to-from
	var fractions:=unit.get_world_2d().direct_space_state.cast_motion(query)
	query.motion=Vector2.ZERO
	if fractions.size()<2 or fractions[0]<0.999: return false
	var previous:=Vector2i((from/32.0).round())
	for i in range(1,maxi(1,ceili(from.distance_to(to)/8.0))+1):
		var point:=from.move_toward(to,i*8.0)
		if not unit.bounds.has_point(point): return false
		var cell:=Vector2i((point/32.0).round())
		if not unit.world.floor_cells.has(cell): return false
		if cell!=previous and not unit.world._can_cross_floor_edge(previous,cell,false): return false
		previous=cell
	return true

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
			var from: Vector2=unit.global_position if cell==start else Vector2(cell)*32.0
			if not segment_clear(unit,from,Vector2(next)*32.0): continue
			visited[next]=cell; queue.append(next)
	var result: Array[Vector2]=[]
	while best!=start:
		result.push_front(Vector2(best)*32.0); best=visited[best]
	return result
