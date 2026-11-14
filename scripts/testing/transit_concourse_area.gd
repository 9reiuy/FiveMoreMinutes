extends RefCounted
## 0-4 is authored on the plan's one-metre grid. The service turn is the entry.

const M := preload("res://scripts/testing/maintenance_environment.gd")
const PRISM := preload("res://scripts/testing/megastructure_whitebox_geometry.gd")
const FIXTURES := preload("res://scripts/testing/transit_concourse_fixtures.gd")
const SURFACE := preload("res://shaders/dream3d/transit_surfaces.gdshader")

const WEST := Rect2i(0, 0, 11, 3)
const SPINE := Rect2i(11, -11, 4, 26)
const EAST := Rect2i(15, 0, 12, 3)
const WAITING := Rect2i(17, -4, 10, 4)
const LAUNDRY := Rect2i(3, 4, 7, 7)
const LAUNDRY_LINK := Rect2i(10, 7, 1, 2)
const WASHROOM := Rect2i(16, 4, 11, 7)
const WASHROOM_LINK := Rect2i(15, 7, 1, 2)
const SERVICE := Rect2i(6, 13, 5, 2)
const SECTIONS := [WEST, SPINE, EAST, WAITING, LAUNDRY, LAUNDRY_LINK, WASHROOM, WASHROOM_LINK, SERVICE]
const SECTION_NAMES := ["WestPassage", "Spine", "EastPassage", "WaitingArea", "Laundry", "LaundryThreshold",
	"Washroom", "WashroomThreshold", "ServiceTurn"]
const SECTION_FINISH := [0, 0, 0, 0, 1, 0, 2, 0, 3]
const CEILING := 2.56
const WALL := .19
const GUARDS := [
	{"name": "ConcourseWestGuard", "at": Vector2(6.92, 1.19), "facing": Vector2.RIGHT, "weapon": "lucille"},
	{"name": "LaundryGuard", "at": Vector2(5.08, 8.17), "facing": Vector2.RIGHT, "weapon": "lucille"},
	{"name": "WashroomEntryGuard", "at": Vector2(16.30, 7.88), "facing": Vector2.LEFT, "weapon": "lucille"},
	{"name": "WashroomRearGuard", "at": Vector2(24.83, 7.52), "facing": Vector2.LEFT, "weapon": "lucille"},
	{"name": "ConcourseEastGuard", "at": Vector2(17.78, 1.43), "facing": Vector2.LEFT, "weapon": "lucille"},
	{"name": "WaitingWestGuard", "at": Vector2(18.58, -1.88), "facing": Vector2.DOWN, "weapon": "basic"},
	{"name": "WaitingEastGuard", "at": Vector2(23.30, -2.55), "facing": Vector2.DOWN, "weapon": "basic"},
]

var _world: Node3D
var cutout := preload("res://scripts/dream/authored_occlusion_cutout.gd").new()
var _art: Node3D
var _offset: Vector2i


func _init(world: Node3D, art: Node3D, offset: Vector2i) -> void:
	_world = world
	_art = art
	_offset = offset


static func room_source(offset: Vector2i) -> Dictionary:
	var bounds := WEST
	var cells: Array[String] = []
	for section: Rect2i in SECTIONS:
		bounds = bounds.merge(section)
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				cells.append("%d,%d" % [x + offset.x, z + offset.y])
	bounds.position += offset
	return {"id": "transit", "label": "B4 地铁通道", "kind": "corridor", "cells": cells,
		"bounds": {"x": bounds.position.x, "y": bounds.position.y, "w": bounds.size.x, "h": bounds.size.y}}


func build() -> void:
	var floors := [
		_surface(Color("807461"), Color("47443e"), Vector2(1.08, 1.08), .58, .30),
		_surface(Color("8898a4"), Color("515d6c"), Vector2(.83, .83), .51, .18),
		_surface(Color("486569"), Color("3a5457"), Vector2(2.45, 2.45), .48, .13, false, .43),
	]
	var sides := [
		_surface(Color("ccc1aa"), Color("7f7562"), Vector2(.36, .36), .44, .28, true),
		_surface(Color("849298"), Color("4c585f"), Vector2(1.36, 2.33), .65, .20, true),
		_surface(Color("6b9186"), Color("adbeb1"), Vector2(.31, .31), .31, .12, true),
	]
	var entry_fade := Vector2(SERVICE.position.x - .5, SERVICE.position.x + 1.4) + Vector2.ONE * _offset.x
	for finishes: Array in [floors, sides]:
		var connector := finishes[0].duplicate() as ShaderMaterial
		connector.set_shader_parameter("west_fade", entry_fade)
		finishes.append(connector)
	var slabs := _group("RoomFloors")
	var cells := {}
	for index in SECTIONS.size():
		var rect: Rect2i = SECTIONS[index]
		var center := Vector2(rect.position) + Vector2(rect.size) * .5 - Vector2(.5, .5)
		var finish: int = SECTION_FINISH[index]
		M.box(slabs, SECTION_NAMES[index], Vector3(rect.size.x, .12, rect.size.y),
			Vector3(center.x, -.06, center.y), floors[finish])
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells[Vector2i(x, z)] = finish

	var boundaries := _group("TiledWalls")
	_build_boundaries(boundaries, cells, sides)
	_build_concourse(_group("ConcourseDetails"))
	var fixtures := FIXTURES.new()
	var laundry := _group("LaundryFixtures")
	_build_laundry(laundry, fixtures)
	cutout.register_tree(laundry)
	var washroom := _group("WashroomFixtures")
	_build_washroom(washroom, fixtures)
	cutout.register_tree(washroom)
	var waiting := _group("WaitingSeats")
	_build_waiting(waiting, fixtures)
	cutout.register_tree(waiting)
	_build_lights(_group("ConcourseLights"))


func _surface(face: Color, grout: Color, tile: Vector2, roughness: float, wear: float,
		wall := false, speckle := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("face_colour", face)
	mat.set_shader_parameter("joint_colour", grout)
	mat.set_shader_parameter("tile_span", tile)
	mat.set_shader_parameter("joint_width", .011 if wall else .014)
	mat.set_shader_parameter("finish_roughness", roughness)
	mat.set_shader_parameter("wear", wear)
	mat.set_shader_parameter("terrazzo", speckle)
	mat.set_shader_parameter("wall_surface", wall)
	mat.set_shader_parameter("skirting_colour", grout.darkened(.52))
	mat.set_shader_parameter("north_fade", Vector2(SPINE.position.y - .49, -8.75) + Vector2.ONE * _offset.y)
	return mat


func _group(title: String) -> Node3D:
	var group := Node3D.new()
	group.name = title
	_art.add_child(group)
	return group


func _build_boundaries(parent: Node3D, cells: Dictionary, sides: Array) -> void:
	var black := M.wall_top_black()
	for outward: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var tangent := Vector2i(abs(outward.y), abs(outward.x))
		for cell: Vector2i in cells:
			var finish: int = cells[cell]
			if not _wall_edge(cells, cell, outward, finish) or _wall_edge(cells, cell - tangent, outward, finish):
				continue
			var end := cell + tangent
			while _wall_edge(cells, end, outward, finish):
				end += tangent
			var center := Vector2(cell) + Vector2(outward) * .5 + Vector2(end - cell - tangent) * .5
			var size := Vector2(end - cell) + Vector2(outward).abs() * WALL
			var footprint := Rect2(center - size * .5, size)
			var name := "TransitWall_%d_%d_%d_%d" % [cell.x, cell.y, outward.x, outward.y]
			var visual := MeshInstance3D.new()
			visual.name = name
			visual.mesh = top_black_wall(footprint, outward, CEILING, sides[finish], black)
			parent.add_child(visual)
			cutout.register_mesh(visual)
			_solid(name, footprint)


func _wall_edge(cells: Dictionary, cell: Vector2i, outward: Vector2i, finish: int) -> bool:
	if outward == Vector2i.LEFT and cell.x == SERVICE.position.x and SERVICE.has_point(cell):
		return false
	if outward == Vector2i.UP and cell.y == SPINE.position.y and SPINE.has_point(cell):
		return false
	return cells.get(cell, -1) == finish and not cells.has(cell + outward)


static func top_black_wall(footprint: Rect2, outward: Vector2i, height: float, tile: Material, black: Material) -> ArrayMesh:
	var corners := PackedVector2Array([footprint.position, Vector2(footprint.end.x, footprint.position.y),
		footprint.end, Vector2(footprint.position.x, footprint.end.y)])
	var cover := SurfaceTool.new()
	cover.begin(Mesh.PRIMITIVE_TRIANGLES)
	cover.set_material(black)
	var facing := SurfaceTool.new()
	facing.begin(Mesh.PRIMITIVE_TRIANGLES)
	facing.set_material(tile)
	var up := Vector3.UP * height
	var inside := -Vector3(outward.x, 0, outward.y)
	var top := PackedVector3Array()
	for corner in corners:
		top.append(Vector3(corner.x, height, corner.y))
	PRISM._triangle(cover, top[0], top[1], top[2], Vector3.UP)
	PRISM._triangle(cover, top[0], top[2], top[3], Vector3.UP)
	# Only the face bordering the playable floor carries the wall finish.
	for index in corners.size():
		var next := (index + 1) % corners.size()
		var a := top[index] - up
		var b := top[next] - up
		var direction := corners[next] - corners[index]
		var normal := Vector3(direction.y, 0, -direction.x).normalized()
		var surface := facing if normal.dot(inside) > .5 else cover
		PRISM._triangle(surface, a, b, top[next], normal)
		PRISM._triangle(surface, a, top[next], top[index], normal)
	return facing.commit(cover.commit())


func _solid(title: String, footprint: Rect2, yaw := 0.0) -> void:
	var body := StaticBody2D.new()
	body.name = title
	body.position = (footprint.get_center() + Vector2(_offset)) * _world.CELL_PIXELS
	body.rotation = yaw
	body.collision_layer = _world.WORLD_WALL_LAYER
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = footprint.size * _world.CELL_PIXELS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	_world.collision_root.add_child(body)


func _build_concourse(parent: Node3D) -> void:
	var rail := M.metal(Color("998f78"), .43)
	var clip := M.metal(Color("514c43"), .65)
	_sign(parent, "B4  CONCOURSE", Vector3(5.25, 2.04, -.373), 0, 2.30)
	_sign(parent, "PLATFORM  ↑", Vector3(10.626, 1.85, -4.55), PI * .5, 1.66)
	_sign(parent, "WAITING  →", Vector3(16.02, 1.82, -.374), 0, 1.68)
	_room_frame(parent, "LAUNDRY", 9.50, 1.0)
	_room_frame(parent, "WASHROOM", 15.50, -1.0)
	for index in 3:
		_wall_print(parent, Vector3(4.12 + index * 1.18, 1.20, -.370), index)
	for x: float in [10.74, 14.26]:
		M.pipe(parent, Vector3(x, .91, -8.52), Vector3(x, .91, -3.72), .048, rail)
		for z: float in [-8.43, -6.96, -5.34, -3.80]:
			var wall_x := 10.60 if x < 12.0 else 14.40
			M.box(parent, "HandrailRose", Vector3(.042, .14, .14), Vector3(wall_x, .86, z), clip)
			M.pipe(parent, Vector3(wall_x, .86, z), Vector3(x, .91, z), .028, rail)
	var tread := M.metal(Color("9a8153"), .87)
	for z: float in [-8.38, -8.67]:
		M.box(parent, "WornTreadMarker", Vector3(3.55, .014, .095), Vector3(12.5, .012, z), tread)
	var grate := M.metal(Color("45433a"), .82)
	M.box(parent, "ServiceDrain", Vector3(.74, .017, .59), Vector3(7.21, .014, 13.52), grate)
	for index in 7:
		M.box(parent, "GrateBar", Vector3(.039, .009, .55), Vector3(6.93 + index * .093, .026, 13.52), clip)


func _room_frame(parent: Node3D, text: String, x: float, facing: float) -> void:
	var trim := M.metal(Color("565a53"), .67)
	for z: float in [6.55, 8.45]:
		M.box(parent, "RoomJamb", Vector3(.22, 2.08, .11), Vector3(x, 1.04, z), trim)
	M.box(parent, "RoomHead", Vector3(.22, .31, 2.02), Vector3(x, 2.23, 7.5), trim)
	_sign(parent, text, Vector3(x + facing * .143, 2.23, 7.5), facing * PI * .5, 1.55)


func _build_laundry(parent: Node3D, fixtures: FIXTURES) -> void:
	for index in 4:
		var x := 3.77 + index * 1.52
		for row in 2:
			var dryer := row == 1
			var z := 9.82 if dryer else 4.18
			var title := "%s_%d" % ["Dryer" if dryer else "Washer", index + 1]
			fixtures.machine(parent, title, Vector2(x, z), dryer)
			_solid(title, Rect2(x - .63, z - .52, 1.26, 1.06))
	fixtures.folding_table(parent, Vector2(6.06, 7.14))
	_solid("LaundryFoldingTable", Rect2(4.49, 6.73, 3.15, .83))
	var beam := M.metal(Color("6b5649"), .80)
	M.box(parent, "LaundryWallTopRail", Vector3(6.64, .115, .08), Vector3(6, 2.27, 3.63), beam)
	for x in [3.0, 4.5, 6.0, 7.5, 9.0]:
		M.box(parent, "RailRivet", Vector3(.044, .044, .021), Vector3(x, 2.27, 3.68), beam)
	var plumbing := M.metal(Color("85837a"), .59)
	M.pipe(parent, Vector3(2.83, 1.58, 3.68), Vector3(9.10, 1.58, 3.68), .043, plumbing)
	for index in 4:
		var x := 3.77 + index * 1.52
		M.pipe(parent, Vector3(x, 1.58, 3.68), Vector3(x, 1.11, 3.68), .032, plumbing)


func _build_washroom(parent: Node3D, fixtures: FIXTURES) -> void:
	var vanity := Vector2(19.15, 4.15)
	fixtures.vanity(parent, vanity)
	_solid("WashroomVanity", Rect2(vanity - Vector2(2.78, .47), Vector2(5.56, .94)))
	var stalls := Vector2(23.69, 9.39)
	fixtures.stalls(parent, stalls)
	for index in 4:
		var x := stalls.x + (index - 1.5) * 1.62
		_solid("StallPartition", Rect2(x - .051, stalls.y - .925, .102, 1.85))
	for index in 3:
		var x := stalls.x + (index - 1) * 1.62
		var angle := PI * .47 if index == 0 else 0.0
		var center := Vector2(x - .72, stalls.y - .88) + Vector2(.70, 0).rotated(angle)
		_solid("StallLeaf", Rect2(center - Vector2(.70, .04), Vector2(1.40, .08)), angle)
		_solid("StallToilet", Rect2(x - .325, stalls.y + .115, .65, .85))
	var metal := M.metal(Color("8a9690"), .46)
	var inset := M.metal(Color("263b3c"), .71)
	M.box(parent, "TowelDispenser", Vector3(.69, .62, .16), Vector3(23.08, 1.52, 3.69), metal)
	M.box(parent, "TowelSlot", Vector3(.56, .065, .014), Vector3(23.08, 1.38, 3.777), inset)
	var diffuser := M.metal(Color("d2eee7"), .49)
	diffuser.emission_enabled = true
	diffuser.emission = Color("caece5")
	diffuser.emission_energy_multiplier = .84
	for x: float in [17.76, 20.54]:
		M.box(parent, "VanityLampTray", Vector3(1.58, .105, .11), Vector3(x, 2.26, 3.64), inset)
		M.box(parent, "VanityLampDiffuser", Vector3(1.49, .056, .09), Vector3(x, 2.228, 3.708), diffuser)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 2.19, 3.91)
		light.light_color = Color("c5e9e2")
		light.light_energy = .62
		light.light_cull_mask = 15
		light.omni_range = 2.26
		light.omni_attenuation = 1.3
		parent.add_child(light)


func _build_waiting(parent: Node3D, fixtures: FIXTURES) -> void:
	for x: float in [18.99, 22.44]:
		fixtures.seat_bank(parent, Vector2(x, -3.73))
		_solid("WaitingSeatBank", Rect2(x - 1.41, -4.14, 2.82, .83))
	_sign(parent, "B4   WAITING AREA", Vector3(20.77, 1.89, -4.37), 0, 2.76)
	_wall_print(parent, Vector3(24.94, 1.58, -4.369), 1)
	var bin := M.metal(Color("75847f"), .61)
	var top := M.metal(Color("333f3d"), .82)
	M.cylinder(parent, "StationBin", .285, .70, Vector3(25.62, .35, -3.82), bin)
	M.cylinder(parent, "BinMouth", .238, .041, Vector3(25.62, .716, -3.82), top)
	_solid("StationBin", Rect2(25.335, -4.105, .57, .57))


func _sign(parent: Node3D, text: String, at: Vector3, yaw: float, width: float) -> void:
	var sign := Node3D.new()
	sign.name = "StationSign"
	sign.position = at
	sign.rotation.y = yaw
	parent.add_child(sign)
	M.box(sign, "EnamelBoard", Vector3(width, .31, .049), Vector3.ZERO, M.metal(Color("35322b"), .70))
	var label := Label3D.new()
	label.text = text
	label.font_size = 23
	label.pixel_size = .0103
	label.outline_size = 0
	label.modulate = Color("e5d9bf")
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position.z = .027
	sign.add_child(label)


func _wall_print(parent: Node3D, at: Vector3, design: int) -> void:
	M.box(parent, "PrintFrame", Vector3(.90, 1.25, .073), at, M.metal(Color("383632"), .78))
	var art := Image.create_empty(48, 64, false, Image.FORMAT_RGBA8)
	var paper := Color("aab4a4") if design == 1 else Color("33483e") if design == 0 else Color("b99e70")
	art.fill(paper)
	art.fill_rect(Rect2i(3, 3, 42, 8), Color("373d3a"))
	art.fill_rect(Rect2i(6, 5, 25, 2), Color("d9d2b7"))
	art.fill_rect(Rect2i(6, 8, 17, 1), Color("b5ae96"))
	if design == 1:
		_print_line(art, Vector2(7, 15), Vector2(26, 40), Color("517e82"))
		_print_line(art, Vector2(26, 40), Vector2(43, 54), Color("517e82"))
		_print_line(art, Vector2(9, 42), Vector2(28, 22), Color("9e654b"))
		_print_line(art, Vector2(28, 22), Vector2(41, 23), Color("9e654b"))
		for dot in [Vector2i(16, 27), Vector2i(24, 37), Vector2i(34, 46), Vector2i(23, 27)]:
			art.fill_rect(Rect2i(dot, Vector2i(3, 3)), Color("dbd4b3"))
	else:
		var ink := Color("c0a963") if design == 0 else Color("6d4a44")
		for row in 26:
			var inset := floori(float(row) / 3.0)
			art.fill_rect(Rect2i(9 + inset, 21 + row, 30 - inset * 2, 1), ink)
		art.fill_rect(Rect2i(17, 23, 14, 4), Color("4e5c57"))
		art.fill_rect(Rect2i(12, 38, 24, 3), Color("ded1ab"))
	for row in 3:
		art.fill_rect(Rect2i(6, 54 + row * 2, 29 - row * 5, 1), Color("444940"))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(art)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = .76
	var quad := QuadMesh.new()
	quad.size = Vector2(.82, 1.17)
	var display := MeshInstance3D.new()
	display.name = "WeatheredStationPrint"
	display.position = at + Vector3.BACK * .039
	display.mesh = quad
	display.material_override = material
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(display)


func _print_line(art: Image, a: Vector2, b: Vector2, colour: Color) -> void:
	var steps := ceili(a.distance_to(b))
	for index in steps + 1:
		var point := Vector2i(a.lerp(b, float(index) / steps).round())
		art.fill_rect(Rect2i(point, Vector2i(2, 2)), colour)


func _build_lights(parent: Node3D) -> void:
	var housing := M.metal(Color("51514b"), .71)
	var locations := [
		[Vector2(2.60, .12), 0.0], [Vector2(7.65, .19), 0.0], [Vector2(13.76, -.08), PI * .5],
		[Vector2(11.31, -4.18), PI * .5], [Vector2(13.70, -7.53), PI * .5],
		[Vector2(13.74, 5.45), PI * .5], [Vector2(11.29, 10.32), PI * .5], [Vector2(8.65, 13.67), 0.0],
		[Vector2(17.62, 1.02), 0.0], [Vector2(23.38, .58), 0.0], [Vector2(21.06, -2.33), 0.0],
	]
	for entry in locations:
		_light(parent, entry[0], entry[1], Color("f3ddc3"), 3.65, false, housing)
	for at: Vector2 in [Vector2(4.24, 6.16), Vector2(8.34, 8.39)]:
		_light(parent, at, 0.0, Color("d5e0e7"), 4.10, true, housing)
	for at: Vector2 in [Vector2(17.50, 6.45), Vector2(22.73, 5.29), Vector2(24.78, 7.12)]:
		_light(parent, at, 0.0, Color("c5eeea"), 4.23, true, housing)


func _light(parent: Node3D, at: Vector2, yaw: float, colour: Color, energy: float,
		panel: bool, housing: Material) -> void:
	var fixture := Node3D.new()
	fixture.name = "CeilingPanel" if panel else "ConcourseFluorescent"
	fixture.position = Vector3(at.x, CEILING, at.y)
	fixture.rotation.y = yaw
	parent.add_child(fixture)
	var span := 1.50 if panel else 1.40
	if panel:
		for z: float in [-.26, .26]:
			M.box(fixture, "PanelFrame", Vector3(span + .13, .098, .074), Vector3(0, 0, z), housing)
		for x: float in [-.784, .784]:
			M.box(fixture, "PanelEnd", Vector3(.075, .097, .50), Vector3(x, 0, 0), housing)
	else:
		M.box(fixture, "FixtureTray", Vector3(span + .14, .10, .22), Vector3.ZERO, housing)
	var glass := M.metal(colour, .55)
	glass.emission_enabled = true
	glass.emission = colour
	glass.emission_energy_multiplier = .91 if panel else 1.25
	var diffuser := M.box(fixture, "Diffuser", Vector3(span, .061, .46 if panel else .24),
		Vector3(0, -.05, 0), glass)
	diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if panel:
		M.box(fixture, "DiffuserMullion", Vector3(.047, .108, .51), Vector3(0, -.027, 0), housing)
	var light := SpotLight3D.new()
	light.name = "CeilingLightPool"
	light.position.y = -.15
	light.rotation.x = -PI * .5
	light.light_color = colour
	light.light_energy = energy
	light.light_specular = .63
	light.light_cull_mask = 15
	light.shadow_caster_mask = 15
	light.shadow_enabled = true
	light.shadow_bias = .035
	light.shadow_normal_bias = .24
	light.spot_angle = 65.0
	light.spot_range = 6.5
	light.spot_attenuation = 1.25
	light.spot_angle_attenuation = .88
	fixture.add_child(light)
	preload("res://scripts/dream/office_light_optics.gd").mark_fixture(fixture, light, [diffuser])
