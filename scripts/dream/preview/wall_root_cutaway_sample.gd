extends "res://scripts/dream/preview/wall_cut_face_texture_sample.gd"
## Isolated alternative: existing near walls become a low continuous wall root.
const ROOT_SECTION = preload("res://shaders/dream3d/office_wall_section.gdshader")
var geometry := preload("res://scripts/dream/office_wall_cutaway_geometry.gd").new()
const ROOT_HEIGHT := 0.12
const FOOT_HEIGHT := 0.34
const FOOT_LENGTH := 0.25
var visual_thickness := 0.25
var root_height := ROOT_HEIGHT
var knee_height := FOOT_HEIGHT
var bevel_length := FOOT_LENGTH
var post_length := 0.20
var mesh_records: Dictionary = {}
var root_meshes: Dictionary = {}
var root_wall_count := 0
var foot_count := 0
var added_mesh_instances := 0
var _root_shader_cache: Dictionary = {}
var thin_meshes: Dictionary = geometry.thin_meshes
var geometry_materials: Dictionary = {}
var joined_meshes: Dictionary = geometry.joined_meshes

func _section_texture_for(height:float,depth:float)->ImageTexture:
	var key:=Vector2(height,depth)
	if not textures.has(key): textures[key]=ImageTexture.create_from_image(section_image(height,depth))
	return textures[key]

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	var endpoints: Dictionary = {}
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		var v := wall.get_node("WallMesh") as MeshInstance3D
		var id := wall.get_instance_id()
		if not mesh_records.has(id): mesh_records[id]={"wall":weakref(wall),"mesh":v.mesh,"cut":bool(wall.cutaway_mode),"replacement":null,"pane_visible":bool(wall.window_pane.visible) if wall.window_pane!=null else false}
		for sign_x in [-1.0,1.0]:
			var p: Vector3 = world.to_local(wall.to_global(Vector3(sign_x*.5,0,0)))
			var key := Vector2i(roundi(p.x*32),roundi(p.z*32))
			if not endpoints.has(key): endpoints[key]=[]
			endpoints[key].append(wall)
	for wall in world.wall_root.get_children():
		if selected_walls.has(wall) or wall.get_node_or_null("WallMesh")==null: continue
		for sign_x in [-1.0,1.0]:
			var p: Vector3=world.to_local(wall.to_global(Vector3(sign_x*.5,0,0)))
			var key:=Vector2i(roundi(p.x*32),roundi(p.z*32))
			if not endpoints.has(key): endpoints[key]=[]
			endpoints[key].append(wall)
	root_wall_count=0; foot_count=0
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		var v := wall.get_node("WallMesh") as MeshInstance3D
		var record: Dictionary = mesh_records[wall.get_instance_id()]
		if wall.cutaway_mode:
			var feet: Array[bool]=[]
			for sign_x in [-1.0,1.0]:
				var p: Vector3 = world.to_local(wall.to_global(Vector3(sign_x*.5,0,0)))
				var key := Vector2i(roundi(p.x*32),roundi(p.z*32))
				var connects := false
				var junction := false
				for other in endpoints[key]:
					if other!=wall and bool(other.cutaway_mode) and absf(other.global_basis.x.normalized().dot(wall.global_basis.x.normalized()))>.99: connects=true
					if other!=wall and not bool(other.cutaway_mode) and absf(other.global_basis.x.normalized().dot(wall.global_basis.x.normalized()))<.1: junction=true
				connects=connects and not junction
				feet.append(not connects)
				if not connects: foot_count+=1
			var phase: float = float(posmod(roundi(wall.position.x if absf(wall.basis.x.x)>.5 else -wall.position.z),3))
			var key := Vector4(float(wall.wall_height),minf(float(wall.wall_thickness),visual_thickness),1.0 if feet[0] else 0.0,1.0 if feet[1] else 0.0)
			var mesh_key := "%s:%s:%s:%s:%s:%s"%[key,phase,root_height,knee_height,bevel_length,post_length]
			if not root_meshes.has(mesh_key): root_meshes[mesh_key]=_make_root_mesh(key.x,key.y,feet[0],feet[1],phase)
			v.mesh=root_meshes[mesh_key]; record.replacement=v.mesh; root_wall_count+=1
		else:
			var base:Mesh=wall.get("_base_wall_mesh") if not bool(wall.window_variant) else wall.get("_window_wall_mesh")
			v.mesh=_thin_mesh(base,minf(base.get_aabb().size.z,visual_thickness))
		v.mesh=_join_corner(v.mesh,wall,endpoints)
		if wall.window_pane!=null: wall.window_pane.visible=bool(wall.wall_visual_visible) and not bool(wall.cutaway_mode)
	super._process(delta)
	# A whole-mesh override has precedence over every surface override.
	# Keep its wall-facing material, but allow the original section surface
	# to display the same cut texture on the post, inner cut and low root.
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		var visual: MeshInstance3D=wall.wall_mesh
		if visual.material_override!=null:
			visual.set_surface_override_material(0,visual.material_override)
			visual.set_surface_override_material(1,visual.material_override)
			visual.material_override=null
		# Geometry now owns the cut. The legacy fragment cut would erase the
		# newly retained tall posts above the former flat 30-percent height.
		for surface in 2:
			var source: Material=visual.get_surface_override_material(surface)
			if source is ShaderMaterial and not source.get_meta("geometry_cut",false):
				var material_key:=source.get_instance_id()
				if not geometry_materials.has(material_key):
					var material:=source.duplicate() as ShaderMaterial
					material.set_shader_parameter("architecture_cutaway",false)
					material.set_meta("geometry_cut",true)
					geometry_materials[material_key]=material
				visual.set_surface_override_material(surface,geometry_materials[material_key])
		var key:=Vector2(float(wall.wall_height),visual.mesh.get_aabb().size.z)
		if not tops.has(key):
			var material:=ShaderMaterial.new(); material.shader=ROOT_SECTION
			material.set_shader_parameter("section_pixels",_section_texture_for(key.x,key.y))
			material.set_shader_parameter("section_height",key.x)
			material.set_shader_parameter("section_thickness",key.y)
			tops[key]=material
		visual.set_surface_override_material(2,tops[key])
	for top: ShaderMaterial in tops.values(): top.shader=ROOT_SECTION

func _join_corner(source: Mesh,wall: Node3D,endpoints: Dictionary)->Mesh:
	var miters:=Vector2.ZERO
	for index in 2:
		var side: float=-1.0 if index==0 else 1.0
		var point: Vector3=wall.to_global(Vector3(side*.5,0,0))
		var local: Vector3=world.to_local(point)
		var key:=Vector2i(roundi(local.x*32),roundi(local.z*32))
		var neighbors: Array=[]
		for other in endpoints.get(key,[]):
			if other!=wall: neighbors.append(other)
		# Only an actual two-way L needs a miter. Straight seams, T and X
		# already have a continuous through-wall covering their intersection.
		if neighbors.size()!=1: continue
		var other: Node3D=neighbors[0]
		if not selected_walls.has(other): continue
		if absf(other.global_basis.x.normalized().dot(wall.global_basis.x.normalized()))>.01: continue
		var toward: float=(other.global_position-point).dot(wall.global_basis.z.normalized())
		miters[index]=-side*signf(toward)
	return geometry.join_mesh(source,miters)

func _thin_mesh(source:Mesh,depth:float)->Mesh:
	return geometry._thin_mesh(source,depth)

func _end_material(source:ShaderMaterial,wall:Node3D)->ShaderMaterial:
	var result: ShaderMaterial = super._end_material(source,wall)
	if result.shader!=null and result.shader.code.contains("EMISSION=ALBEDO*0.18;"):
		var code: String=result.shader.code
		if not _root_shader_cache.has(code):
			var shader:=Shader.new(); shader.code=code.replace("EMISSION=ALBEDO*0.18;","EMISSION=ALBEDO*0.30;"); _root_shader_cache[code]=shader
		result.shader=_root_shader_cache[code]
	return result

static func section_image(height:float,thickness:float)->Image:
	return preload("res://scripts/dream/office_wall_cutaway_geometry.gd").section_image(height,thickness)

func _make_root_mesh(height:float,depth:float,left:bool,right:bool,phase:float)->ArrayMesh:
	geometry.root_height=root_height; geometry.knee_height=knee_height
	geometry.bevel_length=bevel_length; geometry.post_length=post_length
	return geometry._make_root_mesh(height,depth,left,right,phase)

func restore()->void:
	for record:Dictionary in mesh_records.values():
		var wall:Node3D=record.wall.get_ref()
		if not is_instance_valid(wall): continue
		wall.wall_mesh.mesh=wall.get("_cutaway_window_mesh") if wall.cutaway_mode and wall.window_variant else wall.get("_cutaway_wall_mesh") if wall.cutaway_mode else wall.get("_window_wall_mesh") if wall.window_variant else wall.get("_base_wall_mesh")
		if wall.window_pane!=null: wall.window_pane.visible=bool(wall.wall_visual_visible)
	mesh_records.clear(); root_meshes.clear(); thin_meshes.clear(); root_wall_count=0; foot_count=0
	super.restore()
	geometry_materials.clear()
	joined_meshes.clear()
