extends RefCounted
## Tutorial-only industrial training bays; lesson authority stays in ChapterTraining.
const ART := preload("res://scripts/testing/maintenance_environment.gd")
const SURFACE := preload("res://shaders/dream3d/tutorial_facility_surface.gdshader")
const WEAR := preload("res://scripts/story/tutorial_surface_wear.gd")
const CABINET_POSITION := Vector3(2.7,0,2.22)
const CABINET_PICKUP_POSITION := Vector2(2.7,2.37)*32.0
const CABINET_APPROACH_POSITION := Vector2(2.7,3.20)*32.0
const CABINET_WEAPON_HEIGHT := 1.05
var world: Node3D
var root: Node3D
var blue: Material
var yellow: Material
var steel: Material

class BoxBatch:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	func box(at: Vector3, size: Vector3, rotation := Basis.IDENTITY) -> void:
		var box_mesh := BoxMesh.new(); box_mesh.size = size
		var arrays := box_mesh.surface_get_arrays(0)
		var offset := vertices.size()
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: vertices.append(rotation*point+at)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: normals.append(rotation*normal)
		uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		for index: int in arrays[Mesh.ARRAY_INDEX]: indices.append(index+offset)
	func build() -> ArrayMesh:
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return mesh

static func surface(kind: int, colour: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader = SURFACE
	material.set_shader_parameter("finish_kind",kind)
	material.set_shader_parameter("finish_colour",colour)
	material.set_shader_parameter("wear_strength",1.2)
	return material

static func wall_material() -> ShaderMaterial: return surface(0,Color("36545b"))

static func floor_material(gallery: bool, bounds: Rect2i) -> ShaderMaterial:
	var material := surface(3 if gallery else 2,Color("34515d") if gallery else Color("929f99"))
	material.set_shader_parameter("floor_bounds",Vector4(bounds.position.x-.5,bounds.position.y-.5,bounds.end.x-.5,bounds.end.y-.5))
	return material

static func gallery_divider(item: Node3D) -> bool:
	return String(item.name).begins_with("Wall_10_") and String(item.name).ends_with("_W")

static func bay_front(item: Node3D) -> bool:
	return String(item.name).begins_with("Wall_8_") and String(item.name).ends_with("_E")

static func fixture(parent: Node3D, title: String, at: Vector3, index: int, yaw: float) -> Node3D:
	var holder := Node3D.new(); holder.name = title; holder.position = at; holder.rotation.y = yaw
	parent.add_child(holder)
	var metal := ART.metal(Color("253c43"),.62)
	var phosphor := ART.metal(Color("c3dedc"),.4)
	phosphor.emission_enabled = true; phosphor.emission = Color("b3d6d6"); phosphor.emission_energy_multiplier = 2.1
	var length := 2.8 if index < 3 else 1.55
	var housing := ART.box(holder,"LampHousing",Vector3(length+.16,.12,.22),Vector3.ZERO,metal)
	var tube := ART.box(holder,"ColdTube",Vector3(length,.045,.13),Vector3(0,-.085,.02),phosphor)
	if index >= 3:
		# The camera-side corridor wall is already sectioned away. Its high
		# fixtures follow that cutaway rather than floating across the actor.
		# Physical lights, shadow casters and room-power ownership remain intact.
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var light := _pool(holder,"ColdPool",Vector3(0,-.32,.38),2.8 if index < 3 else 2.2,7.0 if index < 3 else 5.8)
	preload("res://scripts/dream/office_light_optics.gd").mark_fixture(holder,light,[tube])
	if index < 3:
		# A second long ribbon washes the yellow back wall; it is owned by the
		# same room power holder, including its luminous diffuser and optics.
		var room: Rect2i = [Rect2i(1,18,8,6),Rect2i(1,8,8,10),Rect2i(1,2,8,6)][index]
		var ribbon := Node3D.new(); ribbon.name = "BackWallRibbon"; holder.add_child(ribbon)
		ribbon.global_position = Vector3(.88,2.22,room.get_center().y-.5)
		ribbon.global_rotation.y = PI*.5
		ART.box(ribbon,"Housing",Vector3(room.size.y-.8,.1,.18),Vector3.ZERO,metal)
		var line := ART.box(ribbon,"Diffuser",Vector3(room.size.y-1.0,.045,.10),Vector3(0,-.07,.03),phosphor)
		var wash := _pool(ribbon,"WallWash",Vector3(0,-.30,.62),3.5,5.6)
		preload("res://scripts/dream/office_light_optics.gd").mark_fixture(ribbon,wash,[line])
	return holder

static func _pool(parent: Node3D, title: String, at: Vector3, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new(); light.name = title; light.position = at
	light.light_color = Color("bbd8db"); light.light_energy = energy
	light.omni_range = radius; light.omni_attenuation = 1.5; light.light_specular = .8
	light.light_cull_mask = 15; light.shadow_caster_mask = 15
	light.shadow_enabled = true; light.shadow_bias = .03; light.shadow_normal_bias = .18
	parent.add_child(light); return light

func install(owner_world: Node3D) -> void:
	world = owner_world
	root = Node3D.new(); root.name = "TrainingFacilityArt"; world.get_node("TutorialGeometry").add_child(root)
	blue = world.authored_cutout.material_for(wall_material())
	yellow = world.authored_cutout.material_for(surface(1,Color("c29727")))
	steel = world.authored_cutout.material_for(WEAR.equipment_material(Color("2e4146"),.61))
	var tread := surface(4,Color("a98c36"))
	tread.set_shader_parameter("floor_bounds",Vector4(8.5,1.5,9.7,23.5))
	_box("YellowObservationWalkway",Vector3(1.15,.012,22.0),Vector3(9.07,.008,12.5),tread,false)
	_box("WalkwayEdge",Vector3(.055,.008,22.0),Vector3(9.67,.009,12.5),surface(5,Color("c8b36b")),false)
	for index in 3:
		var rect: Rect2i = world.FLOOR_SECTIONS[index]
		var centre := Vector3(4.5,0,rect.position.y+(rect.size.y-1)*.5)
		_box("Bay%dYellowTiledWall" % (index+1),Vector3(.045,2.30,rect.size.y-.50),Vector3(.655,1.26,centre.z),yellow,false)
		_box("Bay%dDarkSkirting" % (index+1),Vector3(.08,.19,rect.size.y-.40),Vector3(.69,.095,centre.z),steel,false)
		_box("Bay%dYellowThreshold" % (index+1),Vector3(.50,.012,2.90),Vector3(8.22,.01,[21.0,13.0,5.0][index]),tread,false)
		_beam(rect.position.y-.5,rect.size.y)
	for z: float in [1.5,7.5,17.5,23.5]: _pier(z)
	for span: Vector2 in [Vector2(1.5,3.5),Vector2(6.5,7.5),Vector2(7.5,11.5),Vector2(14.5,17.5),Vector2(17.5,19.5),Vector2(22.5,23.5)]:
		_fence(span)
	var layout := world.get_node("TutorialGeometry/ChapterLayout")
	for index in 3:
		var gate := layout.get_node("Architecture/"+["PreparationDoor","EntryToDash","DashToRange"][index]) as Node3D
		_gate_mesh(gate)
		_quiet_indicator(gate)
		_label("BayNumber%d" % index,str(index+1),Vector3(8.88,2.12,[22.9,16.9,6.9][index]),.014,60)
		_label("BayName%d" % index,["INDUCTION","MOBILITY","BALLISTICS"][index],Vector3(8.89,2.72,[21.0,13.0,5.0][index]),.007,36)
	_quiet_indicator(layout.get_node("Architecture/Exit"))
	_board(Vector3(8.99,1.52,18.3),false)
	_board(Vector3(8.99,1.52,9.0),true)
	_console(Vector3(9.15,0,9.2))
	_weapon_cabinet()
	layout.get_node("Range/WeaponTray").hide()
	layout.get_node("Range/TrainingWeapon").position = Vector3(CABINET_PICKUP_POSITION.x/32.0,CABINET_WEAPON_HEIGHT,CABINET_PICKUP_POSITION.y/32.0)
	for z: float in [1.8,7.8,17.8]:
		_box("OverheadReturn",Vector3(1.35,.36,.52),Vector3(7.75,2.98,z),blue)
		_box("ReturnTopBlack_"+str(z),Vector3(1.37,.025,.54),Vector3(7.75,3.173,z),world.authored_cutout.top_black)
		var vent := BoxBatch.new()
		for row in 7: vent.box(Vector3(7.69,2.86, z-.20+row*.065),Vector3(1.17,.018,.022))
		_batch("VentLouvres",vent,steel)
	# The former glazed inserts sat on solid front walls. Netting now exposes
	# those bays without a duplicate glass/trim layer.
	for mesh: Node3D in layout.get_node("Movement").get_children():
		if String(mesh.name).begins_with("Observation"): mesh.hide()
	_seal_wall_tops(layout.get_node("Architecture"))

func _seal_wall_tops(architecture: Node3D) -> void:
	var caps := BoxBatch.new()
	for wall: Node3D in architecture.get_children():
		if not wall.has_meta(&"cutaway") or not wall.is_visible_in_tree(): continue
		var visual: MeshInstance3D = wall.wall_mesh
		var bounds := visual.get_aabb()
		var transform: Transform3D = world.global_transform.affine_inverse()*visual.global_transform
		var scale := transform.basis.get_scale().abs()
		var at := transform*Vector3(bounds.get_center().x,bounds.end.y+.012,bounds.get_center().z)
		caps.box(at,Vector3(bounds.size.x*scale.x+.02,.025,bounds.size.z*scale.z+.025),transform.basis.orthonormalized())
	# The existing wall blockers already own these caps' cutout masks. Do not
	# turn the empty space between merged caps into one giant blocker AABB.
	_batch("WallTopBlack",caps,world.authored_cutout.top_black,false)
	for gate: Node3D in architecture.get_children():
		if not gate.has_method("bind_gameplay"): continue
		var cap := ART.box(gate,"HeaderTopBlack",Vector3(gate.width+.025,.025,.365),Vector3(0,gate.height+.173,.02),world.authored_cutout.top_black)
		world.authored_cutout.register_mesh(cap)

func _box(title: String, size: Vector3, at: Vector3, material: Material, blocker := true) -> MeshInstance3D:
	var mesh := ART.box(root,title,size,at,material)
	_set_finish_bounds(mesh,material)
	if blocker: world.authored_cutout.register_mesh(mesh)
	return mesh

func _batch(title: String, batch: BoxBatch, material: Material, blocker := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); mesh.name = title; mesh.mesh = batch.build(); mesh.material_override = material; root.add_child(mesh)
	_set_finish_bounds(mesh,material)
	if blocker: world.authored_cutout.register_mesh(mesh)
	return mesh

func _set_finish_bounds(mesh: MeshInstance3D, material: Material) -> void:
	var finish := material as ShaderMaterial
	var reference := steel as ShaderMaterial
	if finish != null and reference != null and finish.shader == reference.shader:
		WEAR.set_mesh_bounds(mesh)

func _beam(start: float, length: float) -> void:
	_box("BayLintel",Vector3(.66,.38,length),Vector3(8.5,2.98,start+length*.5),blue)
	_box("LintelTopBlack",Vector3(.68,.025,length),Vector3(8.5,3.183,start+length*.5),world.authored_cutout.top_black)

func _pier(z: float) -> void:
	world._spawn_wall_collision(Vector2(8.5,z)*32.0,Vector2(.80,.72)*32.0,"FacilityPier_"+str(z))
	_box("StructuralPier",Vector3(.70,3.2,.60),Vector3(8.5,1.6,z),blue)
	_box("PierFoot",Vector3(.80,.24,.72),Vector3(8.5,.12,z),steel)
	_box("PierTopBlack",Vector3(.72,.025,.62),Vector3(8.5,3.213,z),world.authored_cutout.top_black)

func _fence(span: Vector2) -> void:
	var net := BoxBatch.new()
	for z in range(ceili(span.x/.3),floori(span.y/.3)+1):
		net.box(Vector3(8.50,1.35,z*.3),Vector3(.022,2.18,.022))
	for y in range(1,10): net.box(Vector3(8.50,y*.24,(span.x+span.y)*.5),Vector3(.022,.022,span.y-span.x))
	for y: float in [.23,2.46]: net.box(Vector3(8.5,y,(span.x+span.y)*.5),Vector3(.09,.07,span.y-span.x))
	_batch("ObservationSafetyMesh",net,steel)
	_box("MeshKickPlate",Vector3(.10,.22,span.y-span.x),Vector3(8.5,.11,(span.x+span.y)*.5),blue)

func _gate_mesh(gate: Node3D) -> void:
	var leaf := gate.get_node("Leaf") as MeshInstance3D
	for part: Node3D in leaf.get_children(): part.hide()
	var net := BoxBatch.new()
	for x: float in [-1.42,1.42]: net.box(Vector3(x,0,0),Vector3(.085,2.68,.09))
	for y: float in [-1.30,1.30]: net.box(Vector3(0,y,0),Vector3(2.90,.085,.09))
	for index in range(-4,5): net.box(Vector3(index*.3,0,0),Vector3(.022,2.58,.022))
	for index in range(-5,6): net.box(Vector3(0,index*.24,0),Vector3(2.80,.022,.022))
	leaf.mesh = net.build(); leaf.material_override = steel
	WEAR.set_mesh_bounds(leaf)
	ART.box(leaf,"YellowKickPlate",Vector3(2.74,.34,.05),Vector3(0,-1.06,0),yellow)

func _quiet_indicator(gate: Node3D) -> void:
	gate.indicator_light_scale = .18
	gate.status_light.omni_range = 2.15
	gate._set_indicator(gate.is_open)

func _label(title: String, text: String, at: Vector3, density: float, font_size: int) -> void:
	var label := Label3D.new(); label.name = title; label.text = text
	label.position = at; label.rotation.y = PI*.5; label.pixel_size = density; label.font_size = font_size
	label.modulate = Color("d5d7bb"); label.outline_size = 0; label.shaded = true
	root.add_child(label)

func _board(at: Vector3, safety: bool) -> void:
	_box("OperationsNoticeboard",Vector3(.08,.83,1.48),at,steel)
	_box("CorkPanel",Vector3(.028,.70,1.33),at+Vector3(.055,0,0),surface(5,Color("5e5846")))
	var paper := surface(5,Color("b6b7a6"))
	for index in 5:
		_box("PinnedSheet",Vector3(.018,.25+index%2*.08,.20),at+Vector3(.082,.15 if index%2==0 else -.13,-.50+index*.25),paper,false)
		_box("SheetHeading",Vector3(.022,.025,.15),at+Vector3(.095,.20 if index%2==0 else -.08,-.50+index*.25),blue,false)
	if safety: _box("SafetyNotice",Vector3(.022,.25,.17),at+Vector3(.10,-.12,-.50),yellow,false)

func _console(at: Vector3) -> void:
	world._spawn_wall_collision(Vector2(at.x,at.z)*32.0,Vector2(.68,1.25)*32.0,"ObservationControlDesk")
	var furniture := BoxBatch.new()
	furniture.box(at+Vector3(0,.80,0),Vector3(.68,.08,1.25))
	for z: float in [-.50,.50]:
		for x: float in [-.25,.25]: furniture.box(at+Vector3(x,.39,z),Vector3(.06,.74,.06))
	furniture.box(at+Vector3(-.15,.98,.30),Vector3(.25,.29,.36))
	furniture.box(at+Vector3(.14,.86,-.20),Vector3(.22,.03,.44))
	_batch("ObservationControlDesk",furniture,steel)
	_box("ConsolePaperwork",Vector3(.33,.012,.21),at+Vector3(.05,.85,.18),surface(5,Color("acb5ae")),false)

func _weapon_cabinet() -> void:
	var art_root := root
	var cabinet := Node3D.new(); cabinet.name="WeaponCabinet"; root.add_child(cabinet)
	root=cabinet
	var body: Material = world.authored_cutout.material_for(WEAR.equipment_material(Color("596859"),.68))
	var backing: Material = world.authored_cutout.material_for(WEAR.equipment_material(Color("899083"),.80))
	var at := CABINET_POSITION
	world._spawn_wall_collision(Vector2(at.x,at.z)*32.0,Vector2(1.48,.57)*32.0,"WeaponCabinetBody")
	_box("Plinth",Vector3(1.48,.17,.57),at+Vector3(0,.085,0),steel)
	_box("Backing",Vector3(1.32,1.82,.055),at+Vector3(0,1.08,-.235),backing)
	for x: float in [-.70,.70]: _box("CabinetSide",Vector3(.075,1.90,.52),at+Vector3(x,1.10,0),body)
	_box("CabinetTop",Vector3(1.48,.10,.57),at+Vector3(0,2.10,0),body)
	_box("LowerShelf",Vector3(1.35,.065,.51),at+Vector3(0,.78,0),body)
	_box("LowerDoor",Vector3(1.32,.57,.055),at+Vector3(0,.46,.275),body)
	_box("DoorHandle",Vector3(.24,.045,.045),at+Vector3(.36,.60,.32),steel)
	for y: float in [1.02,1.58]: _box("MountingRail",Vector3(1.14,.065,.055),at+Vector3(0,y,-.17),body)
	var holes := BoxBatch.new()
	for row in 6:
		for column in 7: holes.box(at+Vector3(-.48+column*.16,.94+row*.16,-.200),Vector3(.025,.025,.012))
	_batch("PegboardPerforations",holes,steel,false)
	_box("WeaponRest",Vector3(.38,.045,.12),at+Vector3(0,1.00,.12),steel)
	# The open right-hand leaf leaves the weapon directly accessible, without
	# adding a second cabinet interaction or a decorative duplicate of the gun.
	var hinge := at+Vector3(.70,1.39,.28)
	var basis := Basis(Vector3.UP,deg_to_rad(110.0))
	var leaf := BoxBatch.new()
	for x: float in [0.0,-1.32]: leaf.box(hinge+basis*Vector3(x,0,0),Vector3(.055,1.16,.065),basis)
	for y: float in [-.55,.55]: leaf.box(hinge+basis*Vector3(-.66,y,0),Vector3(1.32,.055,.065),basis)
	for x in range(1,9): leaf.box(hinge+basis*Vector3(-x*.15,0,0),Vector3(.018,1.06,.018),basis)
	for y in range(-3,4): leaf.box(hinge+basis*Vector3(-.66,y*.15,0),Vector3(1.24,.018,.018),basis)
	_batch("OpenMeshDoor",leaf,body)
	var door_center := hinge+basis*Vector3(-.66,0,0)
	world._spawn_wall_collision(Vector2(door_center.x,door_center.z)*32.0,Vector2(1.32,.065)*32.0,"WeaponCabinetDoor")
	world.collision_root.get_node("WeaponCabinetDoor").rotation=-deg_to_rad(110.0)
	_box("CabinetIDPlate",Vector3(1.12,.15,.025),at+Vector3(0,1.97,.285),yellow,false)
	var label := Label3D.new(); label.name="CabinetName"; label.text="TRAINING / 01"
	label.position=at+Vector3(0,1.97,.305); label.pixel_size=.0045; label.font_size=28
	label.outline_size=0; label.shaded=true; label.modulate=Color("25343a"); root.add_child(label)
	root=art_root
