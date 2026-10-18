extends Node3D
const SECTION_SHADER = preload("res://shaders/dream3d/preview_wall_section.gdshader")
var world: Node
var selected_room_id := -1
var selected_walls: Array[Node3D] = []
var selected_actors: Array[Node3D] = []
var section_texture: ImageTexture
var cap_vertex_count := 0
var cap_batch_count := 0
var cap_raster_cells := 0
var originals: Dictionary = {}
var materials: Dictionary = {}
var shaders: Dictionary = {}
var tops: Dictionary = {}
var textures: Dictionary = {}
func _section_texture_for(height: float, depth: float) -> ImageTexture:
	var key:=Vector2(height,depth)
	if not textures.has(key): textures[key]=ImageTexture.create_from_image(section_image(height,depth))
	return textures[key]
func apply(source: Node, room_id: int) -> void:
	if is_instance_valid(world): restore()
	world=source; selected_room_id=room_id; process_priority=1000
	section_texture=_section_texture_for(float(world.wall_height),float(world.wall_thickness))
	for wall in world.wall_root.get_children():
		if not wall is Node3D or wall.get_node_or_null("WallMesh")==null: continue
		for cell in world.call("_edge_side_cells",wall.get_meta(&"edge",{})):
			if int(world.room_cells.get(cell,-1))==room_id:
				selected_walls.append(wall); selected_actors.append(wall); break
	_process(0.0)
static func section_image(height:float,thickness:float)->Image:
	var image:=Image.create(maxi(4,roundi(thickness*32)),maxi(4,roundi(height*32)),false,Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c:=Color("a3aaa2")
			var edge:=mini(x,image.get_width()-1-x)
			if edge==0: c=Color("deded0")
			elif edge==1: c=Color("bbc0b4")
			elif y%64==0: c=Color("929d92")
			image.set_pixel(x,y,c)
	return image
func _process(_delta:float)->void:
	if not is_instance_valid(world): return
	for wall in selected_walls:
		if not is_instance_valid(wall): continue
		var v:=wall.get_node("WallMesh") as MeshInstance3D
		if not originals.has(v.get_instance_id()):
			var ss:Array[Material]=[]
			for i in v.mesh.get_surface_count(): ss.append(v.get_surface_override_material(i))
			originals[v.get_instance_id()]={"node":weakref(v),"override":v.material_override,"surfaces":ss}
		if v.material_override is ShaderMaterial: v.material_override=_end_material(v.material_override,wall)
		else:
			var m:Material=v.get_active_material(0)
			if m is ShaderMaterial: v.set_surface_override_material(0,_end_material(m,wall))
			if v.mesh.get_surface_count()>2:
				var key:=Vector2(float(wall.wall_height),v.mesh.get_aabb().size.z)
				if not tops.has(key):
					var top:=ShaderMaterial.new(); top.shader=SECTION_SHADER
					top.set_shader_parameter("section_pixels",_section_texture_for(key.x,key.y))
					top.set_shader_parameter("section_height",key.x)
					top.set_shader_parameter("section_thickness",key.y)
					tops[key]=top
				v.set_surface_override_material(2,tops[key])
func _end_material(source:ShaderMaterial,wall:Node3D)->ShaderMaterial:
	if source.shader==null or source.get_meta(&"wall_end_sample",false): return source
	var depth: float=wall.wall_mesh.mesh.get_aabb().size.z
	var id: String="%d:%s"%[source.get_instance_id(),depth]
	if not materials.has(id):
		var code:String=source.shader.code
		if not code.contains("void vertex()") or not code.contains("ROUGHNESS ="): return source
		if not shaders.has(code):
			var decl:="uniform sampler2D section_pixels : source_color, filter_nearest, repeat_disable;\nuniform float section_height=2.6;\nuniform float section_thickness=0.5;\nvarying vec3 section_local;\nvarying vec3 section_normal;\nvoid vertex()"
			var patched:=code.replace("void vertex()",decl)
			patched=patched.replace("void vertex() {","void vertex() {\nsection_local=VERTEX; section_normal=NORMAL;")
			patched=patched.replace("void vertex(){","void vertex(){\nsection_local=VERTEX; section_normal=NORMAL;")
			patched=patched.replace("ROUGHNESS =","if(abs(section_normal.x)>0.8){vec2 section_uv=vec2(section_local.z/section_thickness+0.5,1.0-section_local.y/section_height); ALBEDO=texture(section_pixels,section_uv).rgb; EMISSION=ALBEDO*0.18;}\nROUGHNESS =")
			var shader:=Shader.new(); shader.code=patched; shaders[code]=shader
		var result:=source.duplicate() as ShaderMaterial
		result.shader=shaders[code]; result.set_meta(&"wall_end_sample",true)
		result.set_shader_parameter("section_pixels",_section_texture_for(float(wall.wall_height),depth))
		result.set_shader_parameter("section_height",float(wall.wall_height))
		result.set_shader_parameter("section_thickness",depth)
		materials[id]=result
	return materials[id]
func restore()->void:
	for r:Dictionary in originals.values():
		var v:MeshInstance3D=r.node.get_ref()
		if not is_instance_valid(v): continue
		v.material_override=r.override
		for i in mini(r.surfaces.size(),v.mesh.get_surface_count()): v.set_surface_override_material(i,r.surfaces[i])
	originals.clear(); selected_walls.clear(); selected_actors.clear(); materials.clear(); world=null
