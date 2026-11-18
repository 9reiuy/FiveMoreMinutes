extends Node3D
## A local reproduction using the user's textures and tutorial light formula.
const FILL:=preload("res://shaders/testing/interactive_gas_tutorial.gdshader")
const OUTLINE:=preload("res://shaders/testing/interactive_gas_tutorial_outline.gdshader")
const MASK:=preload("res://shaders/testing/interactive_gas_tutorial_mask.gdshader")
const ASSET_ROOT:="res://.runtime/stylized_smokes_tutorial_20261116/"
const INK:=Color("687b95")
const PAPER:=Color.WHITE
var gas: Node3D
var materials: Array[ShaderMaterial]=[]
var banks: Array[MultiMesh]=[]
var outer_banks: Array[MultiMesh]=[]
var anchors: Array[Dictionary]=[]
var mesh: ArrayMesh
var clock:=0.0
var reference_mode:=false
var reference_paused:=false
var silhouette_strategy:="whole_mesh"
var unit_radius:=.65

static func build_puff_mesh() -> ArrayMesh:
	# A single connected smooth union of round lobes has curved folds instead
	# of the angular silhouette produced by a radial sphere displacement.
	var positions:=FileAccess.get_file_as_bytes(ASSET_ROOT+"puff_vertices.f32").to_float32_array()
	var directions:=FileAccess.get_file_as_bytes(ASSET_ROOT+"puff_normals.f32").to_float32_array()
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	for i in positions.size()/3:
		vertices.append(Vector3(positions[i*3],positions[i*3+1],positions[i*3+2]))
		normals.append(Vector3(directions[i*3],directions[i*3+1],directions[i*3+2]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func _load_texture(name: String) -> Texture2D:
	var image:=Image.load_from_file(ProjectSettings.globalize_path(ASSET_ROOT+name))
	if image==null:
		push_error("Missing user-supplied tutorial texture: "+name)
		return null
	return ImageTexture.create_from_image(image)

func _build() -> void:
	mesh=build_puff_mesh()
	unit_radius=0.0
	for point: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		unit_radius=maxf(unit_radius,point.length()*1.08+.07)
	var textures:=[_load_texture("T_MarbleNoise5_tiled.png"),_load_texture("T_PerlinNoise_Tiled11_inv.png"),_load_texture("T_Noise_001R.png")]
	for index in 2:
		var material:=ShaderMaterial.new()
		material.shader=FILL if index==0 else OUTLINE
		material.set_shader_parameter("marble_noise",textures[0])
		material.set_shader_parameter("cell_noise",textures[1])
		material.set_shader_parameter("detail_noise",textures[2])
		material.render_priority=3 if index==0 else 2
		material.set_shader_parameter("outline_width",0.0 if index==0 else .05)
		material.set_shader_parameter("ink_color",INK)
		materials.append(material)
		var bank:=MultiMesh.new()
		bank.transform_format=MultiMesh.TRANSFORM_3D
		bank.use_colors=true
		bank.mesh=mesh
		bank.instance_count=64
		bank.visible_instance_count=0
		var carrier:=MultiMeshInstance3D.new()
		carrier.multimesh=bank
		carrier.material_override=material
		carrier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(carrier)
		if index==0: banks.append(bank)
		else: outer_banks.append(bank)
	if reference_mode:
		var shadow:=MultiMeshInstance3D.new()
		shadow.multimesh=banks[0]
		var material: ShaderMaterial=materials[0].duplicate()
		material.shader=MASK
		material.render_priority=0
		shadow.material_override=material
		shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(shadow)
		materials.append(material)

func configure_gas(owner_gas: Node3D) -> void:
	gas=owner_gas
	_build()
	for material in materials:
		material.set_shader_parameter("gas_density",gas.solver.output)
		material.set_shader_parameter("gas_velocity",gas.solver.velocity_output)
		material.set_shader_parameter("gas_minimum",gas.bounds.position)
		material.set_shader_parameter("gas_extent",gas.bounds.size)
		material.set_shader_parameter("gas_world_to_local",gas.global_transform.affine_inverse())
	var fixed:=RandomNumberGenerator.new()
	fixed.seed=0xF1E1D
	for z in 4:
		for x in 5:
			anchors.append({"point":Vector3(2.6+x*1.8+fixed.randf_range(-.10,.10),fixed.randf_range(1.15,1.5),3.8+z*1.8+fixed.randf_range(-.10,.10)),
				"size":fixed.randf_range(1.15,1.5),"seed":fixed.randf()})
	_limit_puff_sizes(anchors)
	_refresh_clouds()

func configure_reference() -> void:
	reference_mode=true
	_build()
	for material in materials:
		material.set_shader_parameter("gas_field_enabled",false)
		material.set_shader_parameter("age_dissolve_enabled",true)
	_refresh_reference()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if reference_mode:
		if not reference_paused: clock+=delta
		_refresh_reference()
	elif is_instance_valid(gas) and gas.solver.ready:
		_refresh_clouds()

func _set_instance(index: int,point: Vector3,size: float,seed: float,envelope:=1.0,stretch:=Vector3.ONE,age:=0.0) -> void:
	var rotation:=Basis.from_euler(Vector3(seed*3.1+clock*.07,seed*6.28,seed*1.7))
	var safe_size:=maxf(.0001,size)
	var transform:=Transform3D(rotation*Basis.from_scale(Vector3(safe_size,safe_size*1.08,safe_size)*stretch),point)
	for bank in [banks[0],outer_banks[0]]:
		bank.set_instance_transform(index,transform)
		bank.set_instance_color(index,Color(seed,age,1.0,envelope))

func _limit_puff_sizes(puffs: Array[Dictionary],separation_ratio:=.43) -> void:
	for i in puffs.size():
		var nearest:=INF
		for j in puffs.size():
			if i==j: continue
			nearest=minf(nearest,Vector3(puffs[i].point).distance_to(puffs[j].point))
		# Reserve a visible gap instead of intersecting two opaque smoke meshes.
		puffs[i].size=minf(float(puffs[i].size),nearest*separation_ratio/unit_radius)

func _refresh_clouds() -> void:
	clock=gas.solver.clock
	_sync_style_lights()
	for material in materials: material.set_shader_parameter("smoke_clock",clock)
	for i in anchors.size():
		var anchor:=anchors[i]
		_set_instance(i,anchor.point,anchor.size,anchor.seed)
	banks[0].visible_instance_count=anchors.size()
	outer_banks[0].visible_instance_count=anchors.size()

func _refresh_reference() -> void:
	_sync_style_lights()
	for material in materials: material.set_shader_parameter("smoke_clock",clock)
	var puffs: Array[Dictionary]=[]
	for i in 9:
		var t:=fposmod(float(i)/9.0+clock*.10,1.0)
		var envelope:=smoothstep(0.0,.08,t)*(1.0-smoothstep(.83,1.0,t))
		var point:=Vector3(sin(t*8.0+clock*.15)*(.18+t*.65)+t*.4,.35+pow(t,1.35)*6.4,cos(t*7.0+clock*.12)*(.12+t*.5))
		puffs.append({"point":point,"size":lerpf(.5,1.85,t)*envelope,"seed":float(i)/9.0,"age":t})
	_limit_puff_sizes(puffs,.66)
	for i in puffs.size():
		_set_instance(i,puffs[i].point,puffs[i].size,puffs[i].seed,1.0,Vector3.ONE,puffs[i].age)
	for i in 8:
		var t:=fposmod(float(i)/8.0+clock*.12,1.0)
		var envelope:=sin(t*PI)
		var point:=Vector3(sin(float(i)*4.7+clock*.27)*(.45+t*.85)+.4,4.3+t*2.2,cos(float(i)*3.8+clock*.21)*.6)
		_set_instance(9+i,point,.32+t*.28,float(i)/8.0,envelope,Vector3(1.6,.45,.6),.74+t*.24)
	banks[0].visible_instance_count=17
	outer_banks[0].visible_instance_count=17

func _sync_style_lights() -> void:
	var sources:=PackedVector4Array()
	if reference_mode:
		for child in get_parent().get_children():
			if child is DirectionalLight3D:
				var direction: Vector3=child.global_basis.z
				sources.append(Vector4(direction.x,direction.y,direction.z,0.0))
				break
	else:
		for light: OmniLight3D in gas._volume_lights:
			if light.is_visible_in_tree() and light.light_energy>0.0:
				var point:=light.global_position
				sources.append(Vector4(point.x,point.y,point.z,1.0))
		if is_instance_valid(gas.world.night_lighting):
			for light: OmniLight3D in gas.world.night_lighting.muzzle_lights:
				if light.is_visible_in_tree() and sources.size()<4:
					var point:=light.global_position
					sources.append(Vector4(point.x,point.y,point.z,1.0))
	var count:=sources.size()
	sources.resize(4)
	for material in materials:
		material.set_shader_parameter("style_light_sources",sources)
		material.set_shader_parameter("style_light_count",count)
