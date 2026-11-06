extends SceneTree
## Offline authoring only: the deliverable contains saved, editable geometry.
var original: Script
const PROFILE = preload("res://scripts/preview/coast_cliff_profile.gd")
const OUT := "res://resources/preview/coast_city_cliff"
var root_coast: Node3D
var facade: ShaderMaterial
func _initialize() -> void: call_deferred("run")
func height_at(x: float,z: float) -> float: return PROFILE.height(x,z,original.coast_distance(x,z))
func own(node: Node, parent: Node) -> void:
	parent.add_child(node); node.owner=root_coast
func box(parent: Node3D,name: String,center: Vector3,size: Vector3) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); node.name=name; node.position=center
	var mesh:=BoxMesh.new(); mesh.size=size; node.mesh=mesh
	node.material_override=facade; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	own(node,parent); return node
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(OUT)
	root_coast=load("res://scenes/preview/night_coast.tscn").instantiate()
	original=root_coast.get_script()
	assert(original.can_instantiate(), "Coast controller must compile before authoring the grid")
	root_coast.set_meta("cliff_platform_sample",true)
	root_coast.editor_description="海崖平台＋低处沙滩＋远处城市航空灯摩斯码，独立待验收小样。"
	var layout:=preload("res://scripts/preview/coast_authored_layout.gd").new(); layout.bind(root_coast)
	var terrain: MeshInstance3D=root_coast.get_node("SandRidge")
	var rock_material:=terrain.material_override.duplicate() as ShaderMaterial
	rock_material.shader=preload("res://shaders/preview/coast_cliff_rock.gdshader")
	rock_material.set_shader_parameter("sand_lit_tint",Color(.72,.57,.42))
	rock_material.set_shader_parameter("sand_cool_tint",Color(.46,.35,.29))
	terrain.material_override=rock_material
	var arrays: Array=terrain.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:=PackedVector3Array(); normals.resize(vertices.size())
	for i in vertices.size():
		var p:=vertices[i]; p.y=height_at(p.x,p.z); vertices[i]=p
		var dx: float=(height_at(p.x+.25,p.z)-height_at(p.x-.25,p.z))/.5
		var dz: float=(height_at(p.x,p.z+.25)-height_at(p.x,p.z-.25))/.5
		normals[i]=Vector3(-dx,1.,-dz).normalized()
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	assert(ResourceSaver.save(mesh,OUT+"/cliff_platform.res")==OK)
	# Use a stable external asset, not an in-memory-only terrain replacement.
	terrain.mesh=load(OUT+"/cliff_platform.res")
	for prop in root_coast.get_node("DuneDressing").get_children():
		if not prop is Node3D or not prop.has_meta("walk_obstacle_radius"): continue
		prop.position.y += height_at(prop.position.x,prop.position.z)-layout.height_at(prop.position.x,prop.position.z)
	for lamp in root_coast.get_node("SpatialLighting").get_children():
		if lamp is Node3D and String(lamp.name).begins_with("ShoreWorklight"):
			lamp.position.y=height_at(lamp.position.x,lamp.position.z)
	var spawn: Marker3D=root_coast.get_node("PlayerSpawn"); spawn.position.y=height_at(spawn.position.x,spawn.position.z)
	# A small lateral reveal lets the Camera see the cliff wall and lower beach,
	# rather than showing only the flat top from directly behind the character.
	root_coast.get_node("CameraRig/LowOffset").position.x=4.8
	# Remove the old unanchored sea-line point lights in this sample only.
	var atmosphere: Node3D=root_coast.get_node("OffshoreAtmosphere")
	for node in atmosphere.get_children():
		if String(node.name).begins_with("SoftHorizonSignal_"): node.free()
	var city:=Node3D.new(); city.name="DistantCity"; own(city,atmosphere)
	city.editor_description="远处城市：所有楼体、空中连廊、屋顶航空障碍灯均为可编辑3D节点。"
	facade=ShaderMaterial.new(); facade.shader=load("res://shaders/preview/coast_city_silhouette.gdshader")
	facade.resource_local_to_scene=true
	var distant: ShaderMaterial=facade.duplicate(); distant.set_shader_parameter("city_tint",Vector3(.030,.042,.068))
	for i in 28:
		var x: float=-560.+i*41.
		var h: float=34.+fposmod(float(i*i*17),53.)
		var building:=box(city,"FarBlock_%02d"%i,Vector3(x,h*.5,-830.-float(i%3)*12.),Vector3(22.+float(i%4)*7.,h,22.))
		building.material_override=distant
	var xs: Array[float]=[-480,-410,-335,-270,-200,-125,-40,50,135,225,320,410,480]
	var heights: Array[float]=[75,88,125,156,105,98,190,94,115,135,75,105,65]
	var zs: Array[float]=[-740,-690,-720,-630,-680,-710,-650,-730,-680,-650,-780,-760,-800]
	for i in xs.size():
		var tower:=Node3D.new(); tower.name="Megastructure_%02d"%i
		tower.position=Vector3(xs[i],0,zs[i]); own(tower,city)
		var w: float=48.+float(i%3)*16.; var h: float=heights[i]
		box(tower,"LowerPodium",Vector3(0,h*.12,0),Vector3(w*1.15,h*.24,46.))
		box(tower,"MainShaft",Vector3(0,h*.52,0),Vector3(w,h*.56,39.))
		box(tower,"UpperTerrace",Vector3(-w*.10,h*.90,0),Vector3(w*.68,h*.20,31.))
		box(tower,"ServiceCrown",Vector3(-w*.1,h+1.5,0),Vector3(w*.3,3.,18.))
		if i in [1,3,5,6,8,9,11]:
			var beacon:=MeshInstance3D.new(); beacon.name="RoofAviationBeacon"
			beacon.position=Vector3(-w*.1,h+4.5,1.)
			var quad:=QuadMesh.new(); quad.size=Vector2(14,14); beacon.mesh=quad
			var glow:=ShaderMaterial.new(); glow.shader=load("res://shaders/preview/coast_aviation_beacon.gdshader"); glow.resource_local_to_scene=true
			beacon.material_override=glow; beacon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beacon.set_meta("chapter_signal",i in [3,6,9]); own(beacon,tower)
			box(tower,"BeaconMast",Vector3(-w*.1,h+4.5,0),Vector3(.9,3.,.9))
	for pair in [[3,4],[6,7],[8,9]]:
		var a:=int(pair[0]); var b:=int(pair[1]); var h:=minf(heights[a],heights[b])*.55
		box(city,"SkyBridge_%02d"%a,Vector3((xs[a]+xs[b])*.5,h,(zs[a]+zs[b])*.5),Vector3(absf(xs[b]-xs[a]),4.5,8.))
	var packed:=PackedScene.new(); assert(packed.pack(root_coast)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/preview/night_coast_city_cliff_sample.tscn")==OK)
	print("CITY_CLIFF_AUTHORED ",root_coast.find_children("*","",true,false).size()," saved nodes, terrain vertices=",vertices.size())
	root_coast.free(); quit()
