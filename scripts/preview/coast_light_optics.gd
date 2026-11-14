extends Node3D
## The production halo, dirt map and native fog components, adapted to the coast.
const STOCK := preload("res://scripts/dream/office_light_optics.gd")
@export_range(0.0,1.0,.01) var dirt_strength := .22
var coast: Node3D
var camera: Camera3D
var halos: Array[Dictionary] = []
var mist: Array[FogVolume] = []
var previous_environment: Environment
var environment: Environment
var original_fog_lights: Dictionary = {}
var halos_enabled := true
var mist_enabled := true
var _cloned_materials: Dictionary = {}
var _cloned_meshes: Dictionary = {}
var _added_camera_layer := false
var _base_fog_light_energy := 0.0

func _ready() -> void: call_deferred("configure")

func smooth_material(source: Material) -> Material:
	if not source is BaseMaterial3D: return source
	if not _cloned_materials.has(source):
		var finish := source.duplicate() as BaseMaterial3D
		finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cloned_materials[source] = finish
	return _cloned_materials[source]

func smooth_mesh(source: Mesh) -> Mesh:
	if source==null: return null
	if not _cloned_meshes.has(source):
		var result := source.duplicate() as Mesh
		for i in result.get_surface_count():
			var finish := source.surface_get_material(i)
			if finish is BaseMaterial3D:
				if result is ArrayMesh: result.surface_set_material(i,smooth_material(finish))
				elif result is PrimitiveMesh: result.material=smooth_material(finish)
		_cloned_meshes[source]=result
	return _cloned_meshes[source]

func configure() -> void:
	coast=get_parent()
	camera=coast.camera
	_added_camera_layer=(camera.cull_mask&STOCK.CAMERA_LAYER)==0
	for node in coast.find_children("*","",true,false):
		if node is MeshInstance3D:
			if node.material_override is BaseMaterial3D: node.material_override=smooth_material(node.material_override)
			if node.mesh!=null: node.mesh=smooth_mesh(node.mesh)
		elif node is MultiMeshInstance3D and node.multimesh!=null:
			var source: MultiMesh=node.multimesh
			var result:=MultiMesh.new()
			result.transform_format=source.transform_format
			result.use_colors=source.use_colors
			result.use_custom_data=source.use_custom_data
			result.mesh=smooth_mesh(source.mesh)
			result.instance_count=source.instance_count
			for i in source.instance_count:
				if source.transform_format==MultiMesh.TRANSFORM_3D: result.set_instance_transform(i,source.get_instance_transform(i))
				else: result.set_instance_transform_2d(i,source.get_instance_transform_2d(i))
				if source.use_colors: result.set_instance_color(i,source.get_instance_color(i))
				if source.use_custom_data: result.set_instance_custom_data(i,source.get_instance_custom_data(i))
			result.visible_instance_count=source.visible_instance_count
			node.multimesh=result
	for index in coast.atmosphere.signal_nodes.size():
		var node: MeshInstance3D=coast.atmosphere.signal_nodes[index]
		# The shore bank is one optical group: all six points have halos,
		# and one representative point reveals the reduced, camera-fixed dirt.
		add_halo(node,node.material_override,Color("FFD695"),.46,.18,index==2)
	var emitters: Node3D=coast.get_node("OffshoreAtmosphere/CoastOpticsAnchors")
	for anchor: Marker3D in emitters.get_children():
		add_halo(anchor,null,anchor.get_meta(&"optics_tint"),float(anchor.get_meta(&"optics_gain")),float(anchor.get_meta(&"optics_half_length")),true)
	previous_environment=camera.environment
	var source: Environment=previous_environment if previous_environment!=null else coast.get_node("CoastEnvironment").environment
	environment=source.duplicate()
	_base_fog_light_energy=environment.fog_light_energy
	environment.volumetric_fog_enabled=true
	environment.volumetric_fog_density=0.0
	environment.volumetric_fog_length=180.0
	environment.volumetric_fog_anisotropy=.16
	environment.volumetric_fog_emission_energy=0.0
	environment.volumetric_fog_ambient_inject=0.0
	environment.volumetric_fog_gi_inject=0.0
	environment.volumetric_fog_temporal_reprojection_amount=.62
	camera.environment=environment
	for light: Light3D in coast.find_children("*","Light3D",true,false):
		original_fog_lights[light]=light.light_volumetric_fog_energy
		light.light_volumetric_fog_energy=0.0
	for name in ["CliffCyanFill","WestQuayLight","EastFreightLight"]:
		var light: Light3D=coast.get_node("SpatialLighting/CoastLocalColours/"+name)
		light.light_volumetric_fog_energy=1.1 if name=="CliffCyanFill" else 1.6
	for volume: FogVolume in find_children("*","FogVolume",false,false): mist.append(volume)
	RenderingServer.frame_pre_draw.connect(sync)
	sync()

func add_halo(anchor: Node3D, signal_material: ShaderMaterial, tint: Color, gain: float, half_length: float, dirt: bool) -> void:
	var node := MeshInstance3D.new()
	node.name="ProductionHalo_%02d"%halos.size()
	var quad := QuadMesh.new()
	quad.size=Vector2(2,2)
	node.mesh=quad
	node.layers=STOCK.CAMERA_LAYER
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.ignore_occlusion_culling=true
	node.custom_aabb=AABB(Vector3.ONE*-3.0,Vector3.ONE*6.0)
	var finish := ShaderMaterial.new()
	finish.shader=STOCK.SURFACE
	finish.set_shader_parameter(&"lens_dirt",STOCK.DIRT.texture())
	finish.set_shader_parameter(&"fixture_tint",tint)
	finish.set_shader_parameter(&"half_length",half_length)
	finish.set_shader_parameter(&"reveals_dirt",dirt)
	finish.set_shader_parameter(&"dirt_strength",dirt_strength)
	node.material_override=finish
	add_child(node)
	camera.cull_mask|=STOCK.CAMERA_LAYER
	halos.append({"node":node,"anchor":anchor,"signal":signal_material,"gain":gain})

func sync() -> void:
	if not is_instance_valid(camera): return
	if coast.atmosphere.static_horizon:
		# Cloud cover dims the ambient haze, not the fixed coastal emitters.
		environment.fog_light_energy=_base_fog_light_energy*lerpf(.25,1.0,coast.moon_visibility)
	for item in halos:
		var node: MeshInstance3D=item.node
		node.global_position=item.anchor.global_position
		var power: float=float(item.signal.get_shader_parameter(&"power")) if item.signal!=null else 1.0
		node.visible=halos_enabled and item.anchor.is_visible_in_tree()
		node.material_override.set_shader_parameter(&"luminous_gain",power*float(item.gain) if halos_enabled else 0.0)
		node.material_override.set_shader_parameter(&"dirt_strength",dirt_strength)
	for volume in mist: volume.visible=mist_enabled

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync): RenderingServer.frame_pre_draw.disconnect(sync)
	for light in original_fog_lights:
		if is_instance_valid(light): light.light_volumetric_fog_energy=original_fog_lights[light]
	if is_instance_valid(camera) and camera.environment==environment: camera.environment=previous_environment
	if _added_camera_layer and is_instance_valid(camera): camera.cull_mask&=~STOCK.CAMERA_LAYER
