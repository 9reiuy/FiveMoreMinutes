extends RefCounted
## Wall topology, openings and actual 2D footprints own chapter staging.
const CATALOG=preload("res://scripts/dream/office_furniture_catalog.gd")
static func edge_point(edge: Dictionary) -> Vector2:
	return Vector2(float(edge.x)-(0.5 if edge.axis=="V" else 0.),float(edge.y)-(0.5 if edge.axis=="H" else 0.))
static func footprint(item: Node2D) -> Rect2:
	var local:=Rect2(-Vector2(16,16),Vector2(32,32))
	var collider: CollisionShape2D=item.get_node_or_null("CollisionShape2D")
	if collider!=null and collider.shape!=null: local=collider.shape.get_rect(); local.position+=collider.position
	var result:=Rect2(item.global_position+local.position.rotated(item.rotation),Vector2.ZERO)
	for point in [local.position,local.position+Vector2(local.size.x,0),local.end,local.position+Vector2(0,local.size.y)]: result=result.expand(item.global_position+Vector2(point).rotated(item.rotation))
	return result
static func wall_sites(world: Node, room_id: int, span: int=1) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for key in world.wall_edges:
		if world.door_edges.has(key) or world.door_opening_edges.has(key) or world.window_wall_edges.has(key): continue
		var edge: Dictionary=world.wall_edges[key]
		var cell:=Vector2i(int(edge.x),int(edge.y))
		if int(world.room_cells.get(cell,-1))!=room_id: continue
		var inward:=Vector2.DOWN if edge.axis=="H" else Vector2.RIGHT
		var point:=edge_point(edge)
		var valid:=true
		for collection in [world.door_edges,world.door_opening_edges,world.window_wall_edges]:
			for opening_key in collection:
				var opening: Dictionary=world.wall_edges.get(opening_key,world.door_edges.get(opening_key,{}))
				if not opening.is_empty() and point.distance_to(edge_point(opening))<1.5: valid=false
		for offset in range(-span,span+1):
			var neighbor: Dictionary=edge.duplicate(); neighbor["x" if edge.axis=="H" else "y"]+=offset
			var other: String=world._edge_key(neighbor)
			if not world.wall_edges.has(other) or world.window_wall_edges.has(other) or world.door_edges.has(other) or world.door_opening_edges.has(other): valid=false
		if valid: result.append({"edge":edge.duplicate(),"point":point,"inward":inward,"key":key})
	result.sort_custom(func(a,b): return a.point.distance_squared_to(Vector2(world.rooms[room_id].center_cell))<b.point.distance_squared_to(Vector2(world.rooms[room_id].center_cell)))
	return result
static func camera_site(world: Node, room_id: int) -> Dictionary:
	for site in wall_sites(world,room_id):
		var blocked:=false
		var point: Vector2=(site.point+site.inward*.25)*32.
		for item in world.furniture_root.get_children():
			if not item is Node2D: continue
			var kind: String=item.get_meta("office_furniture_kind","")
			if CATALOG.size_of(kind).y>1.5 and footprint(item).grow(14).has_point(point): blocked=true
		if not blocked: return site
	return {}
static func maintenance_site(world: Node, room_id: int) -> Dictionary:
	var sites:=wall_sites(world,room_id,2)
	for repack in [false,true]:
		for site in sites:
			var point: Vector2=site.point+site.inward*1.1
			var size:=Vector2(4.4,2.4) if site.inward==Vector2.DOWN else Vector2(2.4,4.4)
			var bounds:=Rect2((point-size*.5)*32.,size*32.)
			if repack: _clear_bay(world,room_id,bounds)
			var blocked:=false
			for item in world.furniture_root.get_children():
				if item is Node2D and footprint(item).grow(4).intersects(bounds): blocked=true
			if not blocked:
				site["position"]=site.point+site.inward*.65; site["bounds"]=bounds
				return site
	return {}
static func _clear_bay(world: Node, room_id: int, bay: Rect2) -> void:
	var moved: Array=[]
	for item in world.furniture_root.get_children():
		if not item is Node2D or not footprint(item).grow(4).intersects(bay): continue
		var original: Vector2=item.position
		var found:=false
		for cell in world.floor_cells:
			if int(world.room_cells.get(cell,-1))!=room_id or Vector2(cell).distance_to(Vector2(world.rooms[room_id].center_cell))<2.5: continue
			item.position=Vector2(cell)*32.
			var rect:=footprint(item).grow(8)
			var valid:=not rect.intersects(bay)
			for point in [rect.position,rect.end,rect.position+Vector2(rect.size.x,0),rect.position+Vector2(0,rect.size.y)]:
				if not world.floor_cells.has(Vector2i((Vector2(point)/32.).round())): valid=false
			for other in world.furniture_root.get_children():
				if other!=item and other is Node2D and rect.intersects(footprint(other)): valid=false
			for edge: Dictionary in world.door_edges.values():
				if rect.grow(70).has_point(edge_point(edge)*32.): valid=false
			if valid: found=true; break
		if not found:
			item.position=original
			for change in moved: change[0].position=change[1]
			return
		moved.append([item,original])
