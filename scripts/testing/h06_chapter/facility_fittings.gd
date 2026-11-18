extends RefCounted
## The chapter shares one industrial kit, but every loaded area owns its instances and finishes.

const KIT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
const DECK := preload("res://scripts/testing/h06_chapter/facility_deck.gdshader")
const WALL := preload("res://scripts/testing/h06_chapter/facility_wall.gdshader")
const VESSEL := preload("res://scripts/testing/h06_chapter/pressure_vessel.gdshader")
const SHUTTER := preload("res://scripts/testing/h06_chapter/facility_shutter.gdshader")
const CONCRETE := "res://art/Dream/CC0/PolyHavenResearch/concrete_floor_worn_001_"
const TILES := "res://art/Dream/CC0/AtriumLoop11/polyhaven/large_grey_tiles_"
const PRECAST := "res://art/Dream/CC0/AtriumLoop11/polyhaven/precast_concrete_wall_diff_1k.jpg"
const EXTRA_MODELS := ["Prop_Barrel_Large","Prop_PipeHolder","Prop_Computer","Door_Frame_Square"]
const CARTON := "res://art/Dream/office_lowpoly/kenney/cardboardBoxClosed.glb"
enum Deck { LAB, STAFF, FREIGHT, GRAPHITE }
const FLOOR_COLOURS := ["bfc0bc","d1cec2","969b99","646963"]
const FLOOR_SPANS := [Vector2(2.4,1.6),Vector2(1.6,1.6),Vector2(3.2,2.2),Vector2(2.2,1.3)]
const SERVICE_GRATES := {
	"calibration":Rect2(-7.75,-31.6,3.15,5.55),
	"guard":Rect2(-25.25,-32.4,2.05,5.5), "inspection":Rect2(-40,-34.9,3.15,7.5),
	"archive":Rect2(-42,-19,2.1,5.4), "pump":Rect2(-24.8,-18.7,2.75,6.0),
	"secret":Rect2(12.05,5.1,4.25,.30), "receiving":Rect2(-42,-.1,13,2.4),
	"west_bank":Rect2(-8.8,18.1,14.6,1.85), "east_bank":Rect2(-6.6,24.0,14.2,2.1),
	"sorting":Rect2(1.8,33.2,3.2,20.5), "loading":Rect2(-6.3,59.5,21,2.65),
	"outbound":Rect2(11.7,68,2.45,17), "transfer_floor":Rect2(10,88.2,65.5,2.6),
	"inbound":Rect2(68.2,67,2.2,17.2), "return_dock":Rect2(56,58.8,20.6,2.1),
	"return_bay":Rect2(62.5,38.2,2.45,15), "dispatch":Rect2(48.1,32.8,14,2),
	"armory":Rect2(30.2,46.6,10.4,1.35), "arena":Rect2(35.65,-12.8,4.7,18.75),
}

var kit: KIT
var wall := ShaderMaterial.new()
var graphite_wall: ShaderMaterial
var shutter := ShaderMaterial.new()
var paint := StandardMaterial3D.new()
var graphite := StandardMaterial3D.new()
var lamp := StandardMaterial3D.new()
var decks := {}
var source_bounds := {}
var vessel_finishes := {}
var timber := StandardMaterial3D.new()

func _init(materials: KIT) -> void:
	kit = materials
	wall.shader = WALL
	wall.set_shader_parameter("precast",load(PRECAST))
	graphite_wall = wall.duplicate() as ShaderMaterial
	graphite_wall.set_shader_parameter("enamel",Color("62655f"))
	shutter.shader = SHUTTER
	paint.albedo_color = Color("ddbc37")
	paint.roughness = .80
	graphite.albedo_color = Color("444843")
	graphite.roughness = .77
	timber.albedo_color = Color("836c53")
	timber.roughness = .94
	lamp.albedo_color = Color("e8e5d7")
	lamp.emission_enabled = true
	lamp.emission = Color("f5efd8")
	lamp.emission_energy_multiplier = 1.65

func floor_material(kind: Deck) -> ShaderMaterial:
	if not decks.has(kind):
		var mat := ShaderMaterial.new()
		mat.shader = DECK
		mat.set_shader_parameter("base",Color(FLOOR_COLOURS[kind]))
		mat.set_shader_parameter("slab_span",FLOOR_SPANS[kind])
		if kind==Deck.STAFF:
			mat.set_shader_parameter("concrete",load(TILES+"diff_1k.jpg"))
			mat.set_shader_parameter("surface_normal",load(TILES+"nor_gl_1k.jpg"))
			mat.set_shader_parameter("roughness_map",load(TILES+"rough_1k.jpg"))
		else:
			mat.set_shader_parameter("concrete",load(CONCRETE+"Diffuse.res"))
			mat.set_shader_parameter("surface_normal",load(CONCRETE+"nor_gl.res"))
			mat.set_shader_parameter("roughness_map",load(CONCRETE+"Rough.res"))
		decks[kind] = mat
	return decks[kind]

func set_grate(floor_mesh: MeshInstance3D, footprint: Rect2) -> void:
	floor_mesh.set_instance_shader_parameter("grate_rect",Vector4(footprint.position.x,footprint.position.y,footprint.end.x,footprint.end.y))

## Fit the source mesh by its rendered bounds. Most kit modules have an off-centre authoring pivot.
func fit(parent: Node3D, model: String, center: Vector3, size: Vector3, rotation_degrees := Vector3.ZERO) -> Node3D:
	var node: Node3D
	if model.begins_with("res://"):
		if not kit._quat_cache.has(model):kit._quat_cache[model]=load(model) as PackedScene
		node = (kit._quat_cache[model] as PackedScene).instantiate() as Node3D
		parent.add_child(node)
		kit._calibrate_industrial_node(node,false)
	else:
		node = kit.spawn_quaternius(parent,model,Vector3.ZERO,0,Vector3.ONE,false,model in EXTRA_MODELS)
	if not source_bounds.has(model):
		var combined := AABB()
		var first := true
		var inv := node.global_transform.affine_inverse()
		var meshes := node.find_children("*","MeshInstance3D",true,false)
		if node is MeshInstance3D: meshes.append(node)
		for visual: MeshInstance3D in meshes:
			var box: AABB = inv * visual.global_transform * visual.get_aabb()
			combined = box if first else combined.merge(box)
			first = false
		source_bounds[model] = combined
	var original: AABB = source_bounds[model]
	var basis := Basis.from_euler(rotation_degrees * PI / 180.).scaled_local(size / original.size.max(Vector3(.0001,.0001,.0001)))
	node.transform = Transform3D(basis, center - basis * original.get_center())
	return node

func pallet_base(parent: Node3D, center: Vector3, size: Vector2) -> void:
	for i in 3:
		kit.box(parent,"PalletRunner",Vector3(size.x*.105,.116,size.y),center+Vector3((i-1)*size.x*.392,.058,0),timber)
	for i in 5:
		kit.box(parent,"DeckBoard",Vector3(size.x,.050,size.y*.16),center+Vector3(0,.141,(i-2)*size.y*.20),timber)

func packed_pallet(parent: Node3D, bottom: Vector3, size: Vector3) -> void:
	pallet_base(parent,bottom,Vector2(size.x,size.z))
	var columns := clampi(roundi(size.x/.9),1,2)
	var rows := clampi(roundi(size.z/.95),1,3)
	var layers := 2 if size.y>1.0 else 1
	var carton_size := Vector3(size.x*.93/columns,(size.y-.166)/layers,size.z*.93/rows)
	for tier in layers:
		for j in rows:
			for i in columns:
				if tier>0 and rows*columns>2 and j==rows-1 and i==0: continue
				var offset := Vector3(size.x*((i+.5)/columns-.5),.166+carton_size.y*(tier+.5),size.z*((j+.5)/rows-.5))
				fit(parent,CARTON,bottom+offset,carton_size)

func archive_shelf(parent: Node3D, rect: Rect2, bottom: float, h: float) -> void:
	var center := rect.get_center()
	for x: float in [rect.position.x+.06,rect.end.x-.06]:
		for z: float in [rect.position.y+.06,rect.end.y-.06]:
			kit.box(parent,"ArchiveUpright",Vector3(.075,h,.08),Vector3(x,bottom+h*.5,z),graphite)
	for tier in 2:
		var top := bottom+.16+tier*h*.48
		kit.box(parent,"ArchiveShelf",Vector3(rect.size.x,.075,rect.size.y),Vector3(center.x,top-.038,center.y),graphite)
		var count := maxi(2,roundi(rect.size.y/1.22))
		for i in count:
			if tier==1 and i==1: continue
			var box_size := Vector3(rect.size.x*.79,.46,rect.size.y/count*.76)
			var at := Vector3(center.x,top+.23,rect.position.y+(i+.5)*rect.size.y/count)
			fit(parent,CARTON,at,box_size)

func wall_cladding(parent: Node3D, rect: Rect2, bottom: float, height: float, outward: Vector2) -> void:
	var run := maxf(rect.size.x,rect.size.y)
	if height<2.3 or run<4.6 or outward==Vector2.DOWN: return
	var inward := -outward
	var axis := Vector2.RIGHT if outward.x==0 else Vector2.DOWN
	var yaw := rad_to_deg(atan2(inward.y,-inward.x))
	var center := rect.get_center() + inward * (minf(rect.size.x,rect.size.y)*.5+.052)
	var count := clampi(floori(run / 4.6),1,5)
	var pitch := run / count
	for i in count:
		var spot := center + axis * ((i+.5)*pitch - run*.5)
		var at := Vector3(spot.x,bottom+height*.51,spot.y)
		var panel := fit(parent,"WallAstra_Straight_Flat",at,Vector3(.085,height-.20,minf(4.25,pitch-.34)),Vector3(0,yaw,0))
		kit.cutout.register_tree(panel)
		if outward==Vector2.UP and i%2==0:
			var mount := Vector3(spot.x,bottom+height-.22,spot.y+.13)
			fit(parent,"Prop_Light_Wide",mount,Vector3(1.55,.16,.26))
			kit.box(parent,"Diffuser",Vector3(1.31,.055,.04),mount+Vector3(0,-.031,.134),lamp)

func barrel(parent: Node3D, center: Vector3, length: float, diameter: float, upright := false,
		colour := Color(.87,.85,.79), oxidized := false) -> Node3D:
	var angle := Vector3.ZERO if upright else Vector3(0,0,-90)
	var model := fit(parent,"Prop_Barrel_Large",center,Vector3(diameter,length,diameter),angle)
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D: meshes.append(model)
	for mesh: MeshInstance3D in meshes:
		for index in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(index) as StandardMaterial3D
			var finish_key := [source,colour,oxidized]
			if not vessel_finishes.has(finish_key):
				var enamel := ShaderMaterial.new()
				enamel.shader = VESSEL
				enamel.set_shader_parameter("trim",source.albedo_texture)
				enamel.set_shader_parameter("trim_normal",source.normal_texture)
				enamel.set_shader_parameter("enamel",colour)
				if oxidized:
					enamel.set_shader_parameter("collar",colour.darkened(.29))
					enamel.set_shader_parameter("yellow",Color("694e3d"))
					enamel.set_shader_parameter("oxide",.72)
				vessel_finishes[finish_key] = enamel
			mesh.set_surface_override_material(index,vessel_finishes[finish_key])
	return model

func pipe_bank(parent: Node3D, at: Vector3, length: float, depth: float, height: float, yaw := 0., oxidized := false) -> void:
	var bank := Node3D.new()
	bank.name = "PressureVesselRack"
	bank.position = at
	bank.rotation.y = deg_to_rad(yaw)
	parent.add_child(bank)
	var diameter := minf(height*.49,depth*.64)
	var vessel_col := Color("4e5658") if oxidized else Color(.87,.85,.79)
	fit(bank,"Prop_PipeHolder",Vector3(0,height*.18,0),Vector3(length*.92,height*.36,depth))
	barrel(bank,Vector3(0,height*.39,depth*.13),length,diameter,false,vessel_col,oxidized)
	barrel(bank,Vector3(0,height*.77,-depth*.15),length*.96,diameter,false,vessel_col,oxidized)

func alignment_gate(parent: Node3D, base: Vector3, width: float, height: float, yaw := 0.) -> void:
	var frame := Node3D.new()
	frame.name = "AlignmentGantry"
	frame.position = base
	frame.rotation.y = deg_to_rad(yaw)
	parent.add_child(frame)
	fit(frame,"Door_Frame_Square",Vector3(0,height*.5,0),Vector3(width,height,.21))
	var radius := minf(width*.30,height*.27)
	var center := Vector3(0,height*.63,.04)
	kit.pipe(frame,Vector3(0,height-.10,.04),center+Vector3.UP*radius,.032,graphite)
	kit.torus_ring(frame,"AlignmentRing",radius,radius*.75,center,paint,Vector3(90,0,0))

## Use the open steel rail module on its side as the lamp tray. Only the narrow service bays have an overhead assembly.
func service_canopy(parent: Node3D, center: Vector3, length: float, width: float, yaw: float) -> Array[MeshInstance3D]:
	var tray := Node3D.new()
	tray.name = "ServiceLightingTray"
	tray.position = center
	tray.rotation.y = deg_to_rad(yaw)
	parent.add_child(tray)
	for side in [-1,1]:
		kit.box(tray,"Channel",Vector3(.10,.15,length),Vector3(width*.5*side,0,0),graphite)
	var modules := maxi(1,roundi(length/2.6))
	var span := length/modules
	var diffusers: Array[MeshInstance3D] = []
	for i in modules:
		var z := (i+.5)*span-length*.5
		fit(tray,"Prop_Rail_4",Vector3(0,.055,z),Vector3(.065,width,span),Vector3(0,0,90))
		var fixture := Vector3(width*.33,-.065,z)
		fit(tray,"Prop_Light_Wide",fixture,Vector3(span*.64,.12,.18),Vector3(0,90,0))
		diffusers.append(kit.box(tray,"Diffuser",Vector3(.057,.046,span*.55),fixture+Vector3(.09,0,0),lamp))
	kit.cutout.register_tree(tray)
	return diffusers

func stencil(parent: Node3D, number: String, at: Vector3, height: float) -> void:
	var digits := Label3D.new()
	digits.name = "BayNumber"+number
	digits.text = number
	digits.font_size = 112
	digits.pixel_size = height/84.
	digits.modulate = Color("282b29")
	digits.outline_size = 0
	digits.double_sided = false
	digits.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(digits)
	digits.position = at
