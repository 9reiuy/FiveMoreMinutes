extends RefCounted
## Local basement art/lighting. No office dressing or global source changes.
const CONCRETE = preload("res://shaders/dream3d/maintenance_concrete.gdshader")

static func concrete(floor_surface: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader=CONCRETE
	material.set_shader_parameter("floor_surface",floor_surface)
	material.set_shader_parameter("concrete_colour",Color("555d60") if floor_surface else Color("697070"))
	material.set_shader_parameter("wetness",.85 if floor_surface else .36)
	return material

static func wall_top_black() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name="Top_Black"
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color.BLACK
	material.roughness=1.0;material.metallic_specular=0.0
	return material

static func metal(colour: Color, roughness: float=.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=colour;material.roughness=roughness
	material.metallic=.18;material.metallic_specular=.3
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material

static func box(parent: Node3D, title: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.name=title
	var mesh := BoxMesh.new();mesh.size=size;node.mesh=mesh
	node.position=at;node.material_override=material;parent.add_child(node)
	return node

static func cylinder(parent: Node3D, title: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.name=title
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius
	mesh.height=height;mesh.radial_segments=10;mesh.rings=1
	node.mesh=mesh;node.position=at;node.material_override=material;parent.add_child(node)
	return node

static func pipe(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var delta := b-a
	if delta.length()<.001:return
	var node := cylinder(parent,"ServicePipe",radius,delta.length(),(a+b)*.5,material)
	var axis := Vector3.UP.cross(delta.normalized())
	if axis.length()>.001:node.quaternion=Quaternion(axis.normalized(),acos(clampf(Vector3.UP.dot(delta.normalized()),-1,1)))

static func configure_environment(world: Node3D) -> void:
	var environment: Environment=world.get_node("Lighting/WorldEnvironment").environment.duplicate()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("020508")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("7897aa");environment.ambient_light_energy=.075
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssr_enabled=true;environment.ssao_enabled=true
	environment.ssao_radius=.45;environment.ssao_intensity=.75
	environment.glow_enabled=true;environment.glow_intensity=.22;environment.glow_bloom=.08
	world.get_node("Lighting/WorldEnvironment").environment=environment

static func cold_fixture(parent: Node3D, title: String, at: Vector3, index: int, yaw: float=0.0, facing_side: float=1.0) -> Node3D:
	var steel := metal(Color("29393f"))
	var tube := metal(Color("91d9ed"),.38)
	tube.emission_enabled=true;tube.emission=Color("74bedb");tube.emission_energy_multiplier=1.6
	var fixture := Node3D.new();fixture.name=title;fixture.position=at;fixture.rotation.y=yaw
	parent.add_child(fixture)
	box(fixture,"LampHousing",Vector3(1.1,.17,.26),Vector3.ZERO,steel)
	var diffuser := box(fixture,"ColdTube",Vector3(.88,.055,.12),Vector3(0,-.1,.05),tube)
	var light := OmniLight3D.new();light.name="ColdPool"
	light.position=Vector3(0,-.32,.35*facing_side)
	light.light_color=Color("92bddb") if index%2==0 else Color("76b9d3")
	light.light_energy=2.7 if index in [0,4] else 1.9
	light.omni_range=7.0 if index in [0,4] else 5.5
	light.omni_attenuation=1.35;light.light_specular=1.0
	light.light_cull_mask=15;light.shadow_caster_mask=15
	light.shadow_enabled=true;light.shadow_bias=.03;light.shadow_normal_bias=.32
	fixture.add_child(light)
	preload("res://scripts/dream/office_light_optics.gd").mark_fixture(fixture, light, [diffuser])
	return fixture

static func build_lighting(world: Node3D) -> void:
	configure_environment(world)
	var anchors := [Vector3(3.8,2.6,2.5),Vector3(14,2.35,2.45),Vector3(19,2.2,8.6),Vector3(24,2.35,2.45),Vector3(34.6,2.6,2.7)]
	for index in anchors.size():cold_fixture(world.ceiling_light_root,"ColdFixture_%02d" % index,anchors[index],index,0.0,-1.0 if index==2 else 1.0)

static func build_services(world: Node3D) -> void:
	var root := Node3D.new();root.name="MaintenanceServices";world.floor_root.add_child(root)
	var steel := metal(Color("40515a"),.45)
	var dark := metal(Color("1f2c31"),.6)
	var band := metal(Color("747f81"),.4)
	# The mains follow the rear wall contour, leaving all three alcoves free.
	var contour: Array=preload("res://scripts/testing/megastructure_whitebox_layout.gd").WEST
	for lane in 2:
		for index in range(contour.size()-1):
			var a: Vector2=preload("res://scripts/testing/megastructure_whitebox_layout.gd").horizontal(contour[index])
			var b: Vector2=preload("res://scripts/testing/megastructure_whitebox_layout.gd").horizontal(contour[index+1])
			pipe(root,Vector3(a.x,2.02+lane*.3,a.y+.14),Vector3(b.x,2.02+lane*.3,b.y+.14),.105 if lane==0 else .065,steel)
	for x in range(1,38,3):
		var y := -.35 if x<8 or x>30 else 3.58
		if x in [13,25]:continue
		box(root,"PipeClamp",Vector3(.08,.65,.09),Vector3(x,2.1,y),band)
	# Recessed drainage strip at the lane edge; the slots are visual, not holes.
	box(root,"DrainBed",Vector3(17,.018,.24),Vector3(19,.016,7.25),dark)
	for index in range(68):
		box(root,"DrainRib",Vector3(.055,.012,.25),Vector3(10.65+index*.25,.03,7.25),steel)
	# Wall-base service conduits grouped beside the two equipment bays.
	for x in [1.2,6.8,31.0,36.7]:
		pipe(root,Vector3(x,.18,-.24),Vector3(x,2.1,-.24),.08,dark)
		cylinder(root,"ValveBody",.13,.12,Vector3(x,.95,-.12),steel).rotation.x=PI*.5
		box(root,"ValveHandle",Vector3(.34,.045,.05),Vector3(x,.95,-.03),band)

static func prop_specs() -> Array:
	return [
		{"kind":"pump","room":0,"at":Vector2(3.5,1.4),"size":Vector3(2.4,1.05,1.35)},
		{"kind":"case","room":0,"at":Vector2(5.1,9.8),"size":Vector3(1.65,.72,1.0)},
		{"kind":"switchgear","room":2,"at":Vector2(35.8,1.1),"size":Vector3(1.45,1.9,1.0)},
		{"kind":"pump","room":2,"at":Vector2(31.7,1.5),"size":Vector3(1.9,1.15,1.3)},
		{"kind":"generator","room":2,"at":Vector2(32.0,9.7),"size":Vector3(2.4,1.3,1.4)},
		{"kind":"case","room":2,"at":Vector2(34.0,9.9),"size":Vector3(1.15,.62,.85)}]

static func prop_visual(kind: String, size: Vector3) -> Node3D:
	var root := Node3D.new();root.name="Maintenance_"+kind
	var body := metal(Color("3b5056"),.5)
	var black := metal(Color("15252b"),.68)
	var edge := metal(Color("6d797b"),.42)
	var stripe := metal(Color("9c8f57"),.7)
	box(root,"Footing",Vector3(size.x,.12,size.z),Vector3(0,.06,0),black)
	if kind=="pump":
		box(root,"PumpSkid",Vector3(size.x,.14,size.z),Vector3(0,.17,0),edge)
		for direction in [-1.0,1.0]:
			var motor := cylinder(root,"Motor",size.z*.23,size.x*.66,Vector3(0,size.y*.5,direction*size.z*.26),body)
			motor.rotation.z=PI*.5
			pipe(root,Vector3(-size.x*.38,size.y*.5,direction*size.z*.26),Vector3(-size.x*.38,size.y*.92,direction*size.z*.26),.075,edge)
		box(root,"TopServicePlate",Vector3(size.x*.5,.08,size.z*.65),Vector3(0,size.y*.88,0),body)
	elif kind=="generator":
		box(root,"GeneratorCase",Vector3(size.x*.95,size.y*.78,size.z*.9),Vector3(0,size.y*.5,0),body)
		for index in 9:
			box(root,"TopVent",Vector3(size.x*.72,.025,.045),Vector3(0,size.y*.9,-size.z*.3+index*size.z*.075),black)
		box(root,"ControlPanel",Vector3(size.x*.23,size.y*.4,.04),Vector3(size.x*.25,size.y*.53,size.z*.46),edge)
	elif kind=="switchgear":
		box(root,"ElectricalEnclosure",Vector3(size.x,size.y*.9,size.z),Vector3(0,size.y*.52,0),body)
		box(root,"DoorPanel",Vector3(size.x*.86,size.y*.77,.035),Vector3(0,size.y*.52,size.z*.51),edge)
		box(root,"RecessedBreaker",Vector3(size.x*.58,size.y*.25,.055),Vector3(0,size.y*.63,size.z*.54),black)
		for index in 4:box(root,"BreakerSwitch",Vector3(.09,.13,.035),Vector3(-.25+index*.17,size.y*.64,size.z*.59),stripe)
		box(root,"TopCap",Vector3(size.x*1.04,.08,size.z*1.04),Vector3(0,size.y,0),black)
	else:
		box(root,"ToolCase",Vector3(size.x,size.y*.8,size.z),Vector3(0,size.y*.48,0),body)
		box(root,"Lid",Vector3(size.x*1.02,.12,size.z*1.02),Vector3(0,size.y*.9,0),edge)
		for direction in [-1.0,1.0]:
			box(root,"Latches",Vector3(.12,.2,.06),Vector3(direction*size.x*.32,size.y*.67,size.z*.52),stripe)
		box(root,"Handle",Vector3(size.x*.3,.08,.14),Vector3(0,size.y+.02,0),black)
	return root
