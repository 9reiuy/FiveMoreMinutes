extends RefCounted
## Instances the author's CC0 modules; vertices and topology remain unchanged.
const ART := "res://art/Dream/CC0/QuaterniusSciFiStandard/"
const M:=preload("res://scripts/testing/maintenance_environment.gd")
const TRANSIT:=preload("res://shaders/dream3d/transit_surfaces.gdshader")
var bounds: Dictionary={}
var scenes: Dictionary={}
var materials: Dictionary={}
var placements: Array[Node3D]=[]
var whitebox:=false
var finishes: Dictionary={}
func _init(neutral:=false) -> void:
	whitebox=neutral
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string(ART+"CONVERSION.json"))
	for record: Dictionary in records:
		var p: Array=record.bounds.position
		var s: Array=record.bounds.size
		bounds[record.name]=AABB(Vector3(p[0],p[1],p[2]),Vector3(s[0],s[1],s[2]))

static func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if node is MeshInstance3D:result.append(node)
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):result.append(mesh)
	return result

func material(original: StandardMaterial3D,shade: float) -> StandardMaterial3D:
	var name:=original.resource_name
	var key:=name+":"+str(shade)
	if materials.has(key):return materials[key]
	var adapted:=original.duplicate() as StandardMaterial3D
	adapted.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	adapted.roughness=maxf(adapted.roughness,.72)
	adapted.metallic=minf(adapted.metallic,.18)
	adapted.metallic_specular=.18
	adapted.normal_scale=.35
	if name=="M_Glass":
		adapted.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		adapted.albedo_color=Color(.90,.92,.94,.065)
		adapted.roughness=.16
		adapted.metallic=0.0
	elif name=="M_Light":
		adapted.emission_enabled=true
		adapted.emission=Color("eceef0")
		adapted.emission_energy_multiplier=1.4
	else:
		adapted.albedo_color*=Color(shade,shade,shade)
	if whitebox and name!="M_Glass" and name!="M_Light":
		adapted.albedo_texture=null
		adapted.normal_enabled=false
		adapted.albedo_color=Color("9d9d9d")
	materials[key]=adapted
	return adapted

func shared_surface(title: String,original: StandardMaterial3D) -> Material:
	if whitebox:return null
	var ground:=title in ["LowerStructuralPlatform","GroundFloorMechBay"]
	var walk:=title in ["WalkwayFloor","DescendingCC0Ramp"]
	var wall:=title in ["ContinuousOuterLaboratoryWall","OutsideCornerClosure","EntranceSideWall","WalkwaySupportToBase"]
	if not ground and not wall and not walk:return null
	if original.resource_name not in ["MI_Trim_03","MI_Trim_01_Floor"]:return null
	var key:=title+":"+original.resource_name
	if finishes.has(key):return finishes[key]
	var material: ShaderMaterial
	if ground:
		material=M.concrete(true)
		material.set_shader_parameter("concrete_colour",Color("535b62"))
		material.set_shader_parameter("wetness",.38)
	else:
		material=ShaderMaterial.new()
		material.shader=TRANSIT
		material.set_shader_parameter("face_colour",Color("aeb2b5") if wall else Color("858b90"))
		material.set_shader_parameter("joint_colour",Color("51585e") if wall else Color("3a424b"))
		material.set_shader_parameter("tile_span",Vector2(2.8,1.1) if wall else Vector2(.95,.95))
		material.set_shader_parameter("finish_roughness",.65 if wall else .54)
		material.set_shader_parameter("wear",.19 if wall else .26)
		material.set_shader_parameter("wall_surface",wall)
		material.set_shader_parameter("occlusion_cutout_enabled",true)
	material.resource_name="Level11Shared_"+title
	material.set_meta(&"shared_style_source",material.shader.resource_path)
	finishes[key]=material
	return material

func place(parent: Node3D,model: String,title: String,centre: Vector3,size: Vector3,angles:=Vector3.ZERO) -> Node3D:
	if not scenes.has(model):scenes[model]=load(ART+model+".scn")
	var node: Node3D=scenes[model].instantiate()
	node.name=title
	var source: AABB=bounds[model]
	var scale:=Vector3.ONE
	for axis in 3:
		if source.size[axis]>.001 and size[axis]>0:scale[axis]=size[axis]/source.size[axis]
	node.rotation=angles
	node.scale=scale
	node.position=centre-node.basis*source.get_center()
	node.set_meta(&"cc0_source_model",model)
	node.set_meta(&"atrium_role",title)
	node.set_meta(&"cc0_source_scene",ART+model+".scn")
	parent.add_child(node)
	var shade:=.90
	if title=="LowerStructuralPlatform":shade=.40
	elif title=="SquareRaisedDisplayTop":shade=.68
	elif title=="WalkwayFloor":shade=.64
	elif title.begins_with("CorridorProtectiveGlass"):shade=.62
	for mesh in meshes(node):
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(surface) as StandardMaterial3D
			if original!=null:
				var shared:=shared_surface(title,original)
				mesh.set_surface_override_material(surface,shared if shared!=null else material(original,shade))
	placements.append(node)
	return node
