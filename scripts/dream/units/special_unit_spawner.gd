extends RefCounted
const CITY=preload("res://scripts/dream/preview/sample_neon_city.gd")

static func robots(world: Node3D) -> void:
	var choices: Array[int]=[]
	for room: Dictionary in world.rooms:
		var id:=int(room.id)
		if id!=world.spawn_room_id and id!=world.boss_room_id and world._is_combat_room(room): choices.append(id)
	var rng:=RandomNumberGenerator.new(); rng.seed=world.active_seed+4919
	while not choices.is_empty():
		var index:=rng.randi_range(0,choices.size()-1)
		var id:=choices[index]; choices.remove_at(index)
		var avoid: Array[Vector2]=[world.player.global_position]
		var point: Vector2=world._random_room_position(id,22.0,avoid)
		if point!=Vector2.ZERO and world._spawn_hotel_robot(id,point,world._hotel_robot_visual_container()): return

static func window_runs(world: Node3D) -> Array[Dictionary]:
	var outside: Dictionary=CITY.classify_void(world.floor_cells,world.building_rect).external
	var groups: Dictionary={}
	for key in world.window_wall_edges:
		if not world.wall_edges.has(key) or world.door_edges.has(key): continue
		var edge: Dictionary=world.wall_edges[key]
		var sides: Array=world._edge_side_cells(edge)
		if sides.size()!=2: continue
		var inside: Vector2i=sides[0] if world.floor_cells.has(sides[0]) else sides[1]
		var exterior: Vector2i=sides[1] if inside==sides[0] else sides[0]
		var room_id:=int(world.room_cells.get(inside,-1))
		if not outside.has(exterior) or room_id<0 or room_id==world.spawn_room_id or room_id==world.boss_room_id: continue
		if not world._is_combat_room(world.rooms[room_id]): continue
		var inward:=Vector2(inside-exterior)
		var boundary: Vector2=world._edge_gameplay_position(edge)
		var normal_axis:=boundary.x if absf(inward.x)>.5 else boundary.y
		var group_key: String="%s:%s:%s" % [room_id,inward,normal_axis]
		if not groups.has(group_key): groups[group_key]={"inward":inward,"room_id":room_id,"points":[]}
		groups[group_key].points.append(boundary)
	var result: Array[Dictionary]=[]
	for key in groups:
		var group: Dictionary=groups[key]
		var tangent:=Vector2(-group.inward.y,group.inward.x)
		group.points.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.dot(tangent)<b.dot(tangent))
		var run: Array[Vector2]=[]
		for point: Vector2 in group.points:
			if not run.is_empty() and point.distance_to(run.back())>33.0:
				result.append({"inward":group.inward,"room_id":group.room_id,"points":run.duplicate()}); run.clear()
			run.append(point)
		if not run.is_empty(): result.append({"inward":group.inward,"room_id":group.room_id,"points":run})
	return result

static func drones(world: Node3D, container: Node3D) -> void:
	var runs:=window_runs(world)
	var rng:=RandomNumberGenerator.new(); rng.seed=world.active_seed+7523
	var made:=0
	while not runs.is_empty() and made<2:
		var index:=rng.randi_range(0,runs.size()-1)
		var run: Dictionary=runs[index]; runs.remove_at(index)
		var route: Array[Vector3]=[]
		for point: Vector2 in run.points:
			var exterior: Vector2=point-run.inward*32.0*.95
			# Do not cross another wing of a concave building.
			if world.floor_cells.has(Vector2i((exterior/32.0).round())): continue
			route.append(world.to_global(Vector3(exterior.x/32.0,1.45,exterior.y/32.0)))
		if route.is_empty(): continue
		if route.size()==1:
			# Even a single-cell window gets a short hover patrol, never a
			# stationary sentry or a route through neighbouring solid walls.
			var tangent: Vector3=(world.global_basis*Vector3(-run.inward.y,0,run.inward.x)).normalized()
			var center:=route[0]
			route=[center-tangent*.2,center+tangent*.2]
		var drone: Node3D=world.EXTERIOR_DRONE_SCRIPT.new()
		drone.name="ExteriorPatrolDrone_%d" % made
		drone.world=world; drone.player=world.player; drone.hit_parent=world.enemy_root
		drone.patrol_points=route; drone.patrol_center=route[0]
		drone.inward_normal=run.inward; drone.boundary_2d=run.points[0]
		drone.set_meta(&"dream_room_id",run.room_id)
		container.add_child(drone); made+=1
