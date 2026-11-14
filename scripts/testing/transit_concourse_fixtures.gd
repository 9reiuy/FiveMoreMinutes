extends RefCounted
## Low-poly fixtures for the transit level, lit by the owning room.

const M := preload("res://scripts/testing/maintenance_environment.gd")
const PRISM := preload("res://scripts/testing/megastructure_whitebox_geometry.gd")
const STOCK := preload("res://shaders/dream3d/storage_stock.gdshader")
const FURNITURE := preload("res://scripts/dream/office_furniture_catalog.gd")

var _steel := M.metal(Color("a5aca8"), .43)
var _dark := M.metal(Color("353b3c"), .74)
var _porcelain := M.metal(Color("d4dfd9"), .25)
var _washer := _paint(Color("b5bec1"), .55, .28)
var _dryer := _paint(Color("537271"), .61, .49)
var _partition := _paint(Color("365357"), .49, .30)
var _seat := _paint(Color("597b80"), .61, .36)


func machine(parent: Node3D, title: String, at: Vector2, dryer: bool) -> void:
	var root := _mount(parent, title, Vector3(at.x, 0, at.y), PI if dryer else 0.0)
	var height := 1.40 if dryer else 1.17
	var body := _dryer if dryer else _washer
	M.box(root, "RaisedPlinth", Vector3(1.13, .13, .96), Vector3(0, .065, 0), _dark)
	M.box(root, "Cabinet", Vector3(1.23, height - .16, .98), Vector3(0, (height + .08) * .5, 0), body)
	M.box(root, "SeamedTop", Vector3(1.20, .045, .96), Vector3(0, height - .032, 0), body)
	var port_y := height * .48
	if dryer:
		M.box(root, "ServiceDoorRim", Vector3(.83, .53, .043), Vector3(0, port_y, .498), _steel)
		M.box(root, "DryerDoor", Vector3(.76, .46, .039), Vector3(0, port_y, .526), body)
		for slot in 3:
			M.box(root, "AirSlot", Vector3(.41, .022, .022), Vector3(0, .26 + slot * .045, .504), _dark)
			M.box(root, "ExhaustSlot", Vector3(.53, .012, .032), Vector3(0, height - .003, -.31 + slot * .064), _dark)
	else:
		var glass := M.metal(Color("25363b"), .18)
		glass.metallic = .35
		var drum := M.cylinder(root, "WasherGlass", .31, .052, Vector3(0, port_y, .51), glass)
		drum.rotation.x = PI * .5
		var ring := TorusMesh.new()
		ring.inner_radius = .285
		ring.outer_radius = .374
		ring.rings = 16
		ring.ring_segments = 8
		var bezel := MeshInstance3D.new()
		bezel.name = "DrumBezel"
		bezel.mesh = ring
		bezel.material_override = _steel
		bezel.position = Vector3(0, port_y, .522)
		bezel.rotation.x = PI * .5
		root.add_child(bezel)
	M.box(root, "DoorPull", Vector3(.062, .15, .069), Vector3(.35, port_y, .536), _dark)

	var console := _mount(root, "ControlBank", Vector3(0, height - .04, .345))
	console.rotation.x = -.31
	M.box(console, "SlopedControl", Vector3(1.17, .203, .26), Vector3.ZERO, _steel if dryer else body)
	for x in [-.33, -.10, .13]:
		var dial := M.cylinder(console, "Dial", .067 if x == -.33 else .045, .052,
			Vector3(x, .053, .135), _dark)
		dial.rotation.x = PI * .5
	M.box(console, "Indicator", Vector3(.13, .062, .022), Vector3(.382, .058, .139),
		M.metal(Color("979854") if dryer else Color("506d61"), .52))


func folding_table(parent: Node3D, at: Vector2) -> void:
	var root := _mount(parent, "FoldingTable", Vector3(at.x, 0, at.y))
	for x in [-1.26, 1.26]:
		for z in [-.27, .27]:
			M.box(root, "SquareTubeLeg", Vector3(.083, .76, .083), Vector3(x, .38, z), _steel)
		M.box(root, "Crossbar", Vector3(.081, .071, .62), Vector3(x, .28, 0), _steel)
	M.box(root, "TableApron", Vector3(2.92, .15, .61), Vector3(0, .713, 0), _dark)
	M.box(root, "FoldingSurface", Vector3(3.15, .09, .83), Vector3(0, .817, 0),
		_paint(Color("bec6bf"), .65, .22))
	for index in 2:
		M.box(root, "FoldedLinen", Vector3(.47 - index * .041, .047, .31),
			Vector3(-1.06 + index * .02, .886 + index * .048, -.08), _porcelain)


func vanity(parent: Node3D, at: Vector2) -> void:
	var root := _mount(parent, "Vanity", Vector3(at.x, 0, at.y))
	const BAY := 1.39
	const DEPTH := .94
	const TOP := .88
	var slab := _paint(Color("769395"), .40, .15)
	var mirror := M.metal(Color("7c9696"), .095)
	mirror.metallic = .78
	mirror.metallic_specular = .72
	M.box(root, "CounterFascia", Vector3(BAY * 4, .129, .075), Vector3(0, TOP - .065, DEPTH * .46), slab)
	M.box(root, "Backsplash", Vector3(BAY * 4, .22, .085), Vector3(0, TOP + .09, -DEPTH * .46), slab)
	for x in [-2.48, 2.48]:
		M.box(root, "CounterLeg", Vector3(.11, .83, .10), Vector3(x, .415, .30), _steel)
	for index in 4:
		var x := (index - 1.5) * BAY
		_basin(root, Vector3(x, TOP, 0), Vector2(BAY, DEPTH), slab)
		M.pipe(root, Vector3(x, TOP, -.31), Vector3(x, TOP + .23, -.31), .029, _steel)
		M.pipe(root, Vector3(x, TOP + .23, -.31), Vector3(x, TOP + .23, -.144), .029, _steel)
		M.box(root, "TapControl", Vector3(.066, .058, .071), Vector3(x + .155, TOP + .03, -.29), _steel)
		M.box(root, "MirrorFrame", Vector3(1.12, .87, .052), Vector3(x, 1.61, -.52), _dark)
		M.box(root, "Mirror", Vector3(1.057, .805, .025), Vector3(x, 1.61, -.486), mirror)


func _basin(parent: Node3D, at: Vector3, bay: Vector2, slab: Material) -> void:
	var counter := SurfaceTool.new()
	var bowl := SurfaceTool.new()
	counter.begin(Mesh.PRIMITIVE_TRIANGLES)
	counter.set_material(slab)
	bowl.begin(Mesh.PRIMITIVE_TRIANGLES)
	bowl.set_material(_porcelain)
	for index in 16:
		var a := Vector2.from_angle(float(index) * TAU / 16.0)
		var b := Vector2.from_angle(float(index + 1) * TAU / 16.0)
		var outer_a := a * bay * .5 / maxf(absf(a.x), absf(a.y))
		var outer_b := b * bay * .5 / maxf(absf(b.x), absf(b.y))
		var edge_a := at + Vector3(a.x * .29, 0, a.y * .23)
		var edge_b := at + Vector3(b.x * .29, 0, b.y * .23)
		var bottom_a := at + Vector3(a.x * .129, -.16, a.y * .103)
		var bottom_b := at + Vector3(b.x * .129, -.16, b.y * .103)
		var corner_a := at + Vector3(outer_a.x, 0, outer_a.y)
		var corner_b := at + Vector3(outer_b.x, 0, outer_b.y)
		PRISM._triangle(counter, corner_a, corner_b, edge_b, Vector3.UP)
		PRISM._triangle(counter, corner_a, edge_b, edge_a, Vector3.UP)
		var normal := (bottom_a - edge_a).cross(edge_b - edge_a).normalized()
		if normal.y < 0:
			normal = -normal
		PRISM._triangle(bowl, edge_a, edge_b, bottom_b, normal)
		PRISM._triangle(bowl, edge_a, bottom_b, bottom_a, normal)
		PRISM._triangle(bowl, bottom_a, bottom_b, at - Vector3.UP * .16, Vector3.UP)
	var visual := MeshInstance3D.new()
	visual.name = "InsetPorcelainBasin"
	visual.mesh = bowl.commit(counter.commit())
	parent.add_child(visual)
	M.cylinder(parent, "Drain", .044, .011, at - Vector3.UP * .151, _dark)


func stalls(parent: Node3D, at: Vector2) -> void:
	var root := _mount(parent, "Cubicles", Vector3(at.x, 0, at.y))
	for index in 4:
		var x := (index - 1.5) * 1.62
		M.box(root, "StallPartition", Vector3(.09, 1.70, 1.85), Vector3(x, 1.04, 0), _partition)
		M.box(root, "StallStanchion", Vector3(.082, 1.89, .11), Vector3(x, .945, -.90), _steel)
	M.box(root, "StallHeadRail", Vector3(4.93, .062, .12), Vector3(0, 1.94, -.90), _steel)
	for index in 3:
		var x := (index - 1) * 1.62
		var door := _mount(root, "CubicleLeaf", Vector3(x - .72, 0, -.88), -PI * .47 if index == 0 else 0.0)
		M.box(door, "StallPanel", Vector3(1.40, 1.45, .068), Vector3(.70, .91, 0), _partition)
		M.box(door, "Latch", Vector3(.096, .055, .042), Vector3(1.18, .935, -.047), _steel)
		var toilet := FURNITURE.make_visual("toilet")
		toilet.name = "PorcelainToilet"
		toilet.position = Vector3(x, 0, .54)
		toilet.rotation.y = PI
		root.add_child(toilet)


func seat_bank(parent: Node3D, at: Vector2, yaw := 0.0) -> void:
	var root := _mount(parent, "WaitingSeatBank", Vector3(at.x, 0, at.y), yaw)
	M.box(root, "SeatBeam", Vector3(2.79, .11, .18), Vector3(0, .40, .04), _dark)
	for x in [-1.15, 1.15]:
		M.box(root, "Leg", Vector3(.10, .40, .12), Vector3(x, .20, 0), _steel)
		M.box(root, "FootRail", Vector3(.15, .07, .67), Vector3(x, .035, .015), _steel)
	for x in [-.91, 0.0, .91]:
		M.box(root, "MouldedSeat", Vector3(.78, .111, .66), Vector3(x, .512, .034), _seat)
		M.box(root, "RolledFront", Vector3(.75, .062, .065), Vector3(x, .485, .345), _seat)
		var back := M.box(root, "SlopingBackrest", Vector3(.76, .51, .11), Vector3(x, .754, -.296), _seat)
		back.rotation.x = -.19
	for x in [-1.352, -.455, .455, 1.352]:
		M.pipe(root, Vector3(x, .43, .247), Vector3(x, .723, .247), .033, _steel)
		M.pipe(root, Vector3(x, .723, .247), Vector3(x, .723, -.23), .033, _steel)


static func _paint(colour: Color, roughness: float, wear: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STOCK
	material.set_shader_parameter("finish_colour", colour)
	material.set_shader_parameter("finish_roughness", roughness)
	material.set_shader_parameter("surface_wear", wear)
	return material


static func _mount(parent: Node3D, title: String, at: Vector3, yaw := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = title
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	return root
