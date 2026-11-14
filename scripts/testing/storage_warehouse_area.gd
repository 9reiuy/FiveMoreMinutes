extends RefCounted
## 0-3. All coordinates below are in metres relative to the garage seam.

const MAINTENANCE := preload("res://scripts/testing/maintenance_environment.gd")
const PRISM := preload("res://scripts/testing/megastructure_whitebox_geometry.gd")
const CABINET := preload("res://scripts/testing/storage_warehouse_cabinet.gd")
const FLOOR := preload("res://shaders/dream3d/storage_floor.gdshader")

const ENTRY := Rect2i(0, 0, 4, 2)
const WEST_LEG := Rect2i(2, 2, 2, 4)
const SOUTH_TURN := Rect2i(4, 4, 3, 2)
const RETURN_LEG := Rect2i(5, 0, 2, 4)
const HALL := Rect2i(7, -3, 14, 12)
const EXIT := Rect2i(21, 2, 4, 2)
const SECTIONS := [ENTRY, WEST_LEG, SOUTH_TURN, RETURN_LEG, HALL, EXIT]
const SECTION_NAMES := ["EntryPassage", "WestLeg", "SouthTurn", "ReturnLeg", "Stockroom", "ExitPassage"]
const WEST_EDGE := -.5
const END_FADE := Vector4(WEST_EDGE, 1.9, 21.7, EXIT.end.x - .51)
const CEILING_HEIGHT := 2.58
const WALL_THICKNESS := .21
const RETURN_DOOR_CENTER := Vector2(5.5, RETURN_LEG.end.y - .5)
const RETURN_DOOR_WIDTH := 1.64
const RETURN_DOOR_HEIGHT := 2.12
const CABINET_RUNS := [
	[Rect2i(8, -3, 5, 1), 0.0],
	[Rect2i(12, -2, 1, 4), -PI * .5],
	[Rect2i(15, -3, 5, 1), 0.0],
	[Rect2i(17, -2, 1, 4), -PI * .5],
	[Rect2i(8, 8, 5, 1), PI],
	[Rect2i(10, 4, 1, 4), PI * .5],
	[Rect2i(15, 8, 5, 1), PI],
	[Rect2i(15, 4, 1, 4), PI * .5],
]
const PIERS := [Vector2i(9, 0), Vector2i(18, 0), Vector2i(9, 5), Vector2i(18, 5)]
const GUARDS := [
	{"name": "WestTurnGuard", "at": Vector2(3, 4), "facing": Vector2.DOWN, "weapon": "lucille"},
	{"name": "NorthWestGuard", "at": Vector2(10, -1), "facing": Vector2.DOWN, "weapon": "lucille"},
	{"name": "SouthCabinetGuard", "at": Vector2(12, 6), "facing": Vector2.UP, "weapon": "basic"},
	{"name": "NorthGapGuard", "at": Vector2(14, -3), "facing": Vector2.DOWN, "weapon": "basic"},
	{"name": "CentralAisleGuard", "at": Vector2(16, 2), "facing": Vector2.LEFT, "weapon": "lucille"},
]
const EXIT_WAVE := [
	{"name": "ExitFrontGuard", "at": Vector2(21, 3), "facing": Vector2.LEFT, "weapon": "lucille"},
	{"name": "ExitMiddleGuard", "at": Vector2(23, 2), "facing": Vector2.LEFT, "weapon": "basic"},
	{"name": "ExitRearGuard", "at": Vector2(24, 3), "facing": Vector2.LEFT, "weapon": "lucille"},
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
	var bounds := ENTRY
	var cells: Array[String] = []
	for section: Rect2i in SECTIONS:
		bounds = bounds.merge(section)
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				cells.append("%d,%d" % [x + offset.x, z + offset.y])
	bounds.position += offset
	return {"id": "storage", "label": "B3 仓储区", "kind": "open_office", "cells": cells,
		"bounds": {"x": bounds.position.x, "y": bounds.position.y, "w": bounds.size.x, "h": bounds.size.y}}


static func blocked_cells(offset: Vector2i) -> Dictionary:
	var cells := {}
	for cabinet in CABINET_RUNS:
		var rect: Rect2i = cabinet[0]
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells[offset + Vector2i(x, z)] = true
	for pier: Vector2i in PIERS:
		cells[offset + pier] = true
	return cells


func build() -> void:
	var fade := END_FADE + Vector4.ONE * _offset.x
	var tile := ShaderMaterial.new()
	tile.shader = FLOOR
	tile.set_shader_parameter("passage_end_fade", fade)
	var slabs := _group("TileSlabs")
	for index in SECTIONS.size():
		var rect: Rect2i = SECTIONS[index]
		var center := Vector2(rect.position) + Vector2(rect.size) * .5 - Vector2(.5, .5)
		MAINTENANCE.box(slabs, SECTION_NAMES[index], Vector3(rect.size.x, .12, rect.size.y),
			Vector3(center.x, -.06, center.y), tile)

	var wall := MAINTENANCE.concrete(false)
	wall.set_shader_parameter("concrete_colour", Color("68716b"))
	wall.set_shader_parameter("wetness", .14)
	wall.set_shader_parameter("passage_end_fade", fade)
	var walls := _group("Boundaries")
	_build_boundaries(walls, wall)
	_build_return_divider(walls, wall)
	var finishes := CABINET.finishes()
	_build_stock(walls, wall, finishes)
	_build_ventilation(finishes)
	_build_lighting()


func _group(title: String) -> Node3D:
	var group := Node3D.new()
	group.name = title
	_art.add_child(group)
	return group


func _build_boundaries(parent: Node3D, wall: Material) -> void:
	var cells := {}
	for section: Rect2i in SECTIONS:
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				cells[Vector2i(x, z)] = true
	# The floor union includes the narrow gap between the two entry legs.
	for outward: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var tangent := Vector2i(abs(outward.y), abs(outward.x))
		for cell: Vector2i in cells:
			if not _wall_edge(cells, cell, outward) or _wall_edge(cells, cell - tangent, outward):
				continue
			var end := cell + tangent
			while _wall_edge(cells, end, outward):
				end += tangent
			var center := Vector2(cell) + Vector2(outward) * .5 + Vector2(end - cell - tangent) * .5
			var size := Vector2(end - cell) + Vector2(outward).abs() * WALL_THICKNESS
			var footprint := Rect2(center - size * .5, size)
			if outward == Vector2i.LEFT and cell.x == ENTRY.position.x:
				continue
			if outward == Vector2i.RIGHT and cell.x == EXIT.end.x - 1:
				continue
			var title := "StorageWall_%d_%d_%d_%d" % [cell.x, cell.y, outward.x, outward.y]
			_add_wall(parent, title, footprint, .48 if outward == Vector2i.DOWN else CEILING_HEIGHT, wall)


func _wall_edge(cells: Dictionary, cell: Vector2i, outward: Vector2i) -> bool:
	# This outside edge is part of the longer doorway divider below.
	if outward == Vector2i.LEFT and cell.x == HALL.position.x and cell.y >= SOUTH_TURN.end.y:
		return false
	return cells.has(cell) and not cells.has(cell + outward)


static func blocks_return_edge(first: Vector2i, second: Vector2i) -> bool:
	return (first.y == second.y and first.y >= RETURN_LEG.end.y and first.y < SOUTH_TURN.end.y
		and mini(first.x, second.x) == HALL.position.x - 1 and maxi(first.x, second.x) == HALL.position.x)


static func is_in_stockroom(position: Vector2) -> bool:
	# Match the floor-cell boundaries, including the inner side of the service
	# door. Arrival by a roll through another wall is the same room entry.
	var cell := Vector2i((position + Vector2(.5, .5)).floor())
	return HALL.has_point(cell) or RETURN_LEG.has_point(cell)


static func sound_is_on_stockroom_side(position: Vector2) -> bool:
	# The exit passage is connected to the hall, not to the entrance corridor.
	# Keep the gameplay room / reinforcement trigger independent of acoustics.
	var cell := Vector2i((position+Vector2(.5,.5)).floor())
	return HALL.has_point(cell) or RETURN_LEG.has_point(cell) or EXIT.has_point(cell)


func _build_return_divider(parent: Node3D, wall: Material) -> void:
	var divider_x := HALL.position.x - .5
	var start_z := RETURN_DOOR_CENTER.y
	var length := HALL.end.y - .5 - start_z
	_add_wall(parent, "StorageReturnDivider", Rect2(divider_x - WALL_THICKNESS * .5, start_z,
		WALL_THICKNESS, length), CEILING_HEIGHT, wall)
	var frame := MAINTENANCE.metal(Color("455850"), .67)
	var side := (RETURN_LEG.size.x - RETURN_DOOR_WIDTH) * .5
	for direction: float in [-1.0, 1.0]:
		var x := RETURN_DOOR_CENTER.x + direction * (RETURN_DOOR_WIDTH + side) * .5
		cutout.register_mesh(MAINTENANCE.box(parent, "ServiceDoorJamb", Vector3(side, RETURN_DOOR_HEIGHT + .12, .25),
			Vector3(x, (RETURN_DOOR_HEIGHT + .12) * .5, start_z), frame))
		_add_collision("ServiceDoorJamb", Rect2(x - side * .5, start_z - .125, side, .25))
	cutout.register_mesh(MAINTENANCE.box(parent, "ServiceDoorHead", Vector3(RETURN_LEG.size.x, .13, .25),
		Vector3(RETURN_DOOR_CENTER.x, RETURN_DOOR_HEIGHT + .065, start_z), frame))
	MAINTENANCE.box(parent, "ServiceDoorThreshold", Vector3(RETURN_DOOR_WIDTH, .022, .235),
		Vector3(RETURN_DOOR_CENTER.x, .012, start_z), frame)


func _add_wall(parent: Node3D, title: String, footprint: Rect2, height: float, wall: Material) -> void:
	var corners := PackedVector2Array([footprint.position, Vector2(footprint.end.x, footprint.position.y),
		footprint.end, Vector2(footprint.position.x, footprint.end.y)])
	var mesh := PRISM._prism(corners, height)
	mesh.surface_set_material(1, wall)
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.mesh = mesh
	parent.add_child(visual)
	cutout.register_mesh(visual)
	if height < CEILING_HEIGHT:
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shadow := MeshInstance3D.new()
		shadow.name = "FullHeightShadow"
		shadow.mesh = PRISM._prism(corners, CEILING_HEIGHT)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		visual.add_child(shadow)
	_add_collision(title, footprint)


func _add_collision(title: String, footprint: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = title
	body.position = (footprint.get_center() + Vector2(_offset)) * _world.CELL_PIXELS
	body.collision_layer = 4
	body.collision_mask = 0
	var rectangle := RectangleShape2D.new()
	rectangle.size = footprint.size * _world.CELL_PIXELS
	var collision := CollisionShape2D.new()
	collision.shape = rectangle
	body.add_child(collision)
	_world.collision_root.add_child(body)


func _build_stock(walls: Node3D, wall: Material, finishes: Dictionary) -> void:
	var stock := _group("StorageCabinets")
	for index in CABINET_RUNS.size():
		var run: Rect2i = CABINET_RUNS[index][0]
		var footprint := Rect2(Vector2(run.position) - Vector2(.5, .5), Vector2(run.size))
		var center := footprint.get_center()
		var cabinet := Node3D.new()
		cabinet.name = "CabinetRun_%02d" % (index + 1)
		cabinet.position = Vector3(center.x, 0, center.y)
		cabinet.rotation.y = CABINET_RUNS[index][1]
		stock.add_child(cabinet)
		CABINET.build(cabinet, maxi(run.size.x, run.size.y), index, finishes)
		cutout.register_tree(cabinet)
		_add_collision(cabinet.name, footprint.grow(-.026))
	for index in PIERS.size():
		var center := Vector2(PIERS[index])
		var footprint := Rect2(center - Vector2(.5, .5), Vector2.ONE)
		_add_wall(walls, "StoragePier_%d" % (index + 1), footprint, CEILING_HEIGHT, wall)
	_sign(stock, "B3   STORES", Vector3(1.29, 1.89, -.348))
	_sign(stock, "EXIT  >", Vector3(21.59, 1.99, 1.64))


func _build_ventilation(finishes: Dictionary) -> void:
	var ventilation := _group("Ventilation")
	var inside_wall := WALL_THICKNESS * .5
	_wall_duct(ventilation, "ReturnExtract", Vector3(HALL.position.x - .5 - inside_wall, 2.23, 4.43),
		1.36, finishes)
	_wall_duct(ventilation, "StockroomExtract", Vector3(HALL.end.x - .5 - inside_wall, 2.27, -.69),
		3.28, finishes)


func _wall_duct(parent: Node3D, title: String, at: Vector3, length: float, finishes: Dictionary) -> void:
	var duct := Node3D.new()
	duct.name = title
	duct.position = at
	duct.rotation.y = -PI * .5
	parent.add_child(duct)

	var zinc: Material = finishes.zinc
	var band: Material = finishes.deck
	var recess: Material = finishes.recess
	var inlet_x := -length * .5 + .16
	var drop_x := length * .5 - .16
	MAINTENANCE.box(duct, "WallFeed", Vector3(.32, .25, .27), Vector3(inlet_x, 0, .103), band)
	MAINTENANCE.box(duct, "Trunk", Vector3(length, .28, .32), Vector3(0, 0, .224), zinc)
	for x: float in [inlet_x + .18, drop_x - .19]:
		MAINTENANCE.box(duct, "Flange", Vector3(.055, .323, .366), Vector3(x, 0, .224), band)
		MAINTENANCE.box(duct, "WallBracket", Vector3(.09, .085, .18), Vector3(x, -.152, .096), band)
	MAINTENANCE.box(duct, "DropElbow", Vector3(.34, .08, .35), Vector3(drop_x, -.13, .224), band)
	MAINTENANCE.box(duct, "VerticalDrop", Vector3(.28, .44, .28), Vector3(drop_x, -.35, .224), zinc)
	MAINTENANCE.box(duct, "GrilleHousing", Vector3(.64, .37, .25), Vector3(drop_x, -.66, .218), zinc)
	MAINTENANCE.box(duct, "GrilleRecess", Vector3(.55, .286, .025), Vector3(drop_x, -.66, .350), recess)
	for row in 5:
		var blade := MAINTENANCE.box(duct, "Louvre", Vector3(.53, .026, .043),
			Vector3(drop_x, -.768 + row * .054, .371), zinc)
		blade.rotation.x = -.36
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func spawn_guard(world: Node3D, offset: Vector2i, room_id: int, slot: Dictionary) -> void:
	var position: Vector2 = (Vector2(slot.at) + Vector2(offset)) * world.CELL_PIXELS
	var enemy: EmployeeEnemy = world._spawn_regular_employee(room_id, position, &"employee", false, slot.weapon)
	if enemy == null:
		return
	enemy.name = slot.name
	enemy.set_room_runtime_active(true)
	enemy._apply_live_facing(slot.facing)
	enemy._update_weapon_aim()
	var station: Array[Vector2] = [position]
	enemy.set_authored_patrol_route(station)


func _sign(parent: Node3D, words: String, at: Vector3) -> void:
	MAINTENANCE.box(parent, "EnamelSign", Vector3(1.29, .28, .04), at,
		MAINTENANCE.metal(Color("353f3a"), .81))
	var lettering := Label3D.new()
	lettering.text = words
	lettering.font_size = 24
	lettering.pixel_size = .009
	lettering.outline_size = 0
	lettering.modulate = Color("bfc9b7")
	lettering.position = at + Vector3(0, 0, .022)
	parent.add_child(lettering)


func _build_lighting() -> void:
	var lights := _group("Fluorescents")
	var steel := MAINTENANCE.metal(Color("444e46"), .78)
	var tube := MAINTENANCE.metal(Color("e1e9d9"), .55)
	tube.emission_enabled = true
	tube.emission = Color("e1e9d9")
	tube.emission_energy_multiplier = 1.32
	var mounts := [
		[Vector2(1.81, .08), 0.0, 3.2],
		[Vector2(3.20, 2.82), PI * .5, 3.45],
		[Vector2(4.43, 4.06), 0.0, 3.6],
		[Vector2(6.16, 1.03), PI * .5, 3.35],
		[Vector2(8.58, 1.48), 0.0, 4.15],
		[Vector2(14.26, 1.36), 0.0, 4.4],
		[Vector2(19.28, 1.42), 0.0, 4.15],
		[Vector2(22.17, 2.02), 0.0, 2.4],
		[Vector2(9.22, 6.68), 0.0, 2.75],
		[Vector2(14.23, 6.64), 0.0, 2.7],
		[Vector2(18.96, 6.66), 0.0, 2.65],
	]
	for index in mounts.size():
		var at: Vector2 = mounts[index][0]
		var cabinet_fill := index >= 8
		var fixture := Node3D.new()
		fixture.name = "TwinTube_%02d" % (index + 1)
		fixture.position = Vector3(at.x, CEILING_HEIGHT, at.y)
		fixture.rotation.y = mounts[index][1]
		lights.add_child(fixture)
		MAINTENANCE.box(fixture, "Tray", Vector3(1.70, .095, .15), Vector3.ZERO, steel)
		var emitters: Array[MeshInstance3D] = []
		for x: float in [-.80, .80]:
			MAINTENANCE.box(fixture, "SocketPair", Vector3(.11, .09, .34), Vector3(x, -.014, 0), steel)
		for z: float in [-.121, .121]:
			var diffuser := MAINTENANCE.cylinder(fixture, "FluorescentTube", .041, 1.54,
				Vector3(0, -.030, z), tube)
			diffuser.rotation.z = PI * .5
			diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			emitters.append(diffuser)
		var light := SpotLight3D.new()
		light.name = "LightPool"
		light.position.y = -.135
		light.rotation.x = -PI * .5 + (.43 if cabinet_fill else 0.0)
		light.light_color = Color("d9e5d8") if index % 2 == 0 else Color("c8d9cc")
		light.light_energy = mounts[index][2]
		light.light_specular = .64
		light.light_cull_mask = 15
		light.shadow_caster_mask = 15
		light.shadow_enabled = not cabinet_fill
		light.shadow_bias = .035
		light.shadow_normal_bias = .24
		light.spot_range = 5.3 if cabinet_fill else 6.5
		light.spot_angle = 63.0
		light.spot_attenuation = 1.28
		light.spot_angle_attenuation = .89
		fixture.add_child(light)
		preload("res://scripts/dream/office_light_optics.gd").mark_fixture(fixture, light, emitters)
