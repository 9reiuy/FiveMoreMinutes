extends RefCounted
## Floor-scoped, event-driven presentation. Room face materials remain owned by
## WallSegment3D and ApprovedOfficeArt; this service only supplies mesh profiles.
const GEOMETRY=preload("res://scripts/dream/office_wall_cutaway_geometry.gd")
const SECTION=preload("res://shaders/dream3d/office_wall_section.gdshader")
var geometry=GEOMETRY.new()
var world: Node3D
var walls: Array[Node3D]=[]
var endpoints: Dictionary={}
var records: Dictionary={}
var sections: Dictionary={}
var fixtures: Array[Dictionary]=[]
var refresh_count:=0
var last_refresh_usec:=0

func configure(source: Node3D)->void:
	world=source; geometry=GEOMETRY.new(); walls.clear(); endpoints.clear(); records.clear(); sections.clear(); fixtures.clear()
	for wall in world.wall_root.get_children():
		if not wall.has_method("set_office_cutaway_profile"): continue
		walls.append(wall)
		for side in [-1.0,1.0]:
			var key:=_endpoint_key(wall,side)
			if not endpoints.has(key): endpoints[key]=[]
			endpoints[key].append(wall)
	for wall in walls:
		var base: Mesh=wall.get("_window_wall_mesh") if wall.window_variant else wall.get("_base_wall_mesh")
		var depth: float=minf(base.get_aabb().size.z,.25)
		var miters:=Vector2.ZERO
		for index in 2:
			var side: float=-1.0 if index==0 else 1.0
			var neighbors: Array=endpoints[_endpoint_key(wall,side)].filter(func(other): return other!=wall)
			if neighbors.size()!=1: continue
			var other: Node3D=neighbors[0]
			if absf(other.global_basis.x.normalized().dot(wall.global_basis.x.normalized()))>.01: continue
			var point: Vector3=wall.to_global(Vector3(side*.5,0,0))
			miters[index]=-side*signf((other.global_position-point).dot(wall.global_basis.z.normalized()))
		var full: Mesh=geometry.join_mesh(geometry._thin_mesh(base,depth),miters)
		var key:=Vector2(float(wall.wall_height),depth)
		if not sections.has(key):
			var section:=ShaderMaterial.new(); section.shader=SECTION
			section.set_shader_parameter("section_pixels",ImageTexture.create_from_image(GEOMETRY.section_image(key.x,key.y)))
			section.set_shader_parameter("section_height",key.x); section.set_shader_parameter("section_thickness",key.y)
			sections[key]=section
		records[wall.get_instance_id()]={"full":full,"depth":depth,"miters":miters,"section":sections[key]}
	# Wall-mounted purely visual details follow the thinner visible face.
	for fixture in world.wall_root.get_children():
		if not fixture is MeshInstance3D or not String(fixture.name).begins_with("WallFixture_"): continue
		var nearest: Node3D
		var distance:=.36
		for wall in walls:
			var p: Vector3=wall.to_local(fixture.global_position); p.y=0
			if p.length_squared()<distance: nearest=wall; distance=p.length_squared()
		if nearest!=null:
			var p: Vector3=nearest.to_local(fixture.global_position)
			p.z=signf(p.z)*(float(records[nearest.get_instance_id()].depth)*.5+maxf(0,absf(p.z)-float(nearest.wall_thickness)*.5))
			fixture.global_position=nearest.to_global(p)
			fixtures.append({"node":fixture,"wall":nearest})
	refresh()

func _endpoint_key(wall: Node3D,side: float)->Vector2i:
	var p: Vector3=world.to_local(wall.to_global(Vector3(side*.5,0,0)))
	return Vector2i(roundi(p.x*32),roundi(p.z*32))

func refresh()->void:
	if not is_instance_valid(world) or walls.is_empty() or not is_instance_valid(walls[0]): return
	if walls[0].get_parent()!=world.wall_root: return # Old floor may be in the rollback stash.
	var started:=Time.get_ticks_usec()
	for wall in walls:
		if not is_instance_valid(wall): continue
		var record: Dictionary=records[wall.get_instance_id()]
		var posts: Array[bool]=[]
		for side in [-1.0,1.0]:
			var continues:=false
			var junction:=false
			for other in endpoints[_endpoint_key(wall,side)]:
				if other==wall: continue
				var alignment: float=absf(other.global_basis.x.normalized().dot(wall.global_basis.x.normalized()))
				if other.cutaway_mode and alignment>.99: continues=true
				if not other.cutaway_mode and alignment<.1: junction=true
			posts.append(not continues or junction)
		var phase: float=float(posmod(roundi(wall.position.x if absf(wall.basis.x.x)>.5 else -wall.position.z),3))
		var cut: Mesh=geometry.join_mesh(geometry.cut_mesh(float(wall.wall_height),record.depth,posts[0],posts[1],phase),record.miters)
		wall.set_office_cutaway_profile(record.full,cut,record.section)
	for fixture in fixtures:
		if is_instance_valid(fixture.node) and is_instance_valid(fixture.wall): fixture.node.visible=not fixture.wall.cutaway_mode
	refresh_count+=1; last_refresh_usec=Time.get_ticks_usec()-started
