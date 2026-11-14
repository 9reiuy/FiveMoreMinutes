extends RefCounted
## Authored garage area. Geometry is authored locally, while the floor graph,
## collision bodies and gameplay anchors use the owning world's coordinates.

const MAINTENANCE = preload("res://scripts/testing/maintenance_environment.gd")
const CONCRETE_PRISM = preload("res://scripts/testing/megastructure_whitebox_geometry.gd")
const GARAGE_ART = preload("res://scripts/testing/parking_garage_art.gd")
const VAN_AMBUSH = preload("res://scripts/testing/parking_van_ambush.gd")
const FLOOR_FINISH = preload("res://shaders/dream3d/parking_concrete_floor.gdshader")
const VEHICLE_WEAR = preload("res://shaders/dream3d/vehicle_surface_wear.gdshader")
const GARAGE_BED := preload("res://sfx/parking/garage_room_tone.wav")
const SEDAN = preload("res://scenes/dream/props/vehicles/VehicleSedan.tscn")
const SUV = preload("res://scenes/dream/props/vehicles/VehicleSUV.tscn")
const FUV = preload("res://scenes/dream/props/vehicles/VehicleFUV.tscn")
const HALL := Rect2i(0, 0, 15, 29)
const ENTRY := Rect2i(-2, 24, 2, 2)
const EXIT := Rect2i(15, 1, 3, 2)
const END_FADE := Vector4(-2.48, -.5, 14.5, 17.48)
const VEHICLE_RECESS := Rect2i(5, -1, 5, 1)
const SECTIONS := [HALL, ENTRY, EXIT]
const SECTION_NAMES := ["MainSlab", "EntranceSlab", "ExitSlab"]
const SPAWN := Vector2i(-1, 25)
const COLUMN_X := [4, 10]
const COLUMN_Z := [4.0, 10.5, 17.0, 23.5]
const CEILING_HEIGHT := 2.65
const PARKED_CARS := [
	{"name": "NorthLeftFUV", "scene": FUV, "at": Vector2(2, 2.25), "yaw": -PI * .5, "paint": Color("b9bcc5")},
	{"name": "UpperLeftSUV", "scene": SUV, "at": Vector2(2, 7.82), "yaw": PI * .5, "paint": Color("69784a")},
	{"name": "MiddleRightSedan", "scene": SEDAN, "at": Vector2(12, 13.52), "yaw": PI * .5, "paint": Color("557798")},
	{"name": "AngledLeftSedan", "scene": SEDAN, "at": Vector2(1.98, 20.60), "yaw": -61.0 * PI / 180.0, "paint": Color("864a45"), "angled": true},
	{"name": "SouthRightSUV", "scene": SUV, "at": Vector2(12, 26.85), "yaw": -PI * .5, "paint": Color("a37a45")},
]
const ENCOUNTER := [
	{"name": "UpperRightGuard", "at": Vector2(7.12, .94), "facing": Vector2.DOWN, "weapon": "basic", "crash_guard": true},
	{"name": "MiddleLeftGuard", "at": Vector2(1.64, 13.40), "facing": Vector2.RIGHT, "weapon": "lucille"},
	{"name": "LowerLeftGuard", "at": Vector2(.83, 15.55), "facing": Vector2.RIGHT, "weapon": "lucille"},
	{"name": "MiddleRightGuard", "at": Vector2(10.03, 15.45), "facing": Vector2.LEFT, "weapon": "basic"},
	{"name": "EntrancePatrol", "at": Vector2(1.76, 25.38), "facing": Vector2.RIGHT, "weapon": "lucille",
		"patrol_end": Vector2(5.86, 25.38)},
]


var _world: Node3D
var cutout := preload("res://scripts/dream/authored_occlusion_cutout.gd").new()
var floor_root: Node3D
var wall_root: Node3D
var _offset: Vector2i
var _joined_entry: bool
var _joined_exit: bool
var _cells: Dictionary = {}


func _init(world: Node3D, floor: Node3D, walls: Node3D,
		offset := Vector2i.ZERO, joined_entry := false, joined_exit := false) -> void:
	_world = world
	floor_root = floor
	wall_root = walls
	_offset = offset
	_joined_entry = joined_entry
	_joined_exit = joined_exit
	for section: Rect2i in SECTIONS:
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				_cells[Vector2i(x, z)] = true


static func layout_source(room_key: String = "entry", offset := Vector2i.ZERO) -> Dictionary:
	var cells: Array[String] = []
	var footprint := HALL
	for section: Rect2i in SECTIONS:
		footprint = footprint.merge(section)
		for z in range(section.position.y, section.end.y):
			for x in range(section.position.x, section.end.x):
				cells.append("%d,%d" % [x + offset.x, z + offset.y])
	footprint.position += offset
	var center := HALL.get_center() + offset
	var bounds := {"x": footprint.position.x, "y": footprint.position.y,
		"w": footprint.size.x, "h": footprint.size.y}
	return {"type": "PARKING_0_2", "checks": {"ok": true}, "bounds": bounds,
		"rooms": [{"id": room_key, "label": "B2 停车场", "kind": "open_office", "cells": cells, "bounds": bounds}],
		"anchors": {room_key: "%d,%d" % [center.x, center.y]},
		"doors": [], "furniture": [], "enemies": []}


func build_floor() -> void:
	var concrete := ShaderMaterial.new()
	concrete.shader = FLOOR_FINISH
	concrete.set_shader_parameter("passage_end_fade", _end_fade())
	var lane_start: float = COLUMN_X[0] + .5
	var lane_end: float = COLUMN_X[1] - .5
	# Both finishes share the same slab plane. The road turns follow the actual
	# entrance and exit rectangles all the way to their outside walls.
	concrete.set_shader_parameter("main_road", _shift_bounds(Vector4(lane_start, HALL.position.y - .5, lane_end, HALL.end.y - .5)))
	concrete.set_shader_parameter("entry_turn", _shift_bounds(Vector4(ENTRY.position.x - .5, ENTRY.position.y - .5, lane_start, ENTRY.end.y - .5)))
	concrete.set_shader_parameter("exit_turn", _shift_bounds(Vector4(lane_end, EXIT.position.y - .5, EXIT.end.x - .5, EXIT.end.y - .5)))
	for index in SECTIONS.size():
		var section: Rect2i = SECTIONS[index]
		var center := Vector2(section.position) + Vector2(section.size) * .5 - Vector2(.5, .5)
		MAINTENANCE.box(floor_root, SECTION_NAMES[index], Vector3(section.size.x, .12, section.size.y),
			Vector3(center.x, -.06, center.y), concrete)
	var bays := GARAGE_ART.build_markings(floor_root, HALL, ENTRY, EXIT, COLUMN_X, COLUMN_Z)
	GARAGE_ART.build_services(floor_root, HALL, COLUMN_X, COLUMN_Z, bays)
	_build_parked_cars(bays)


func _build_parked_cars(bays: Array[Rect2]) -> void:
	var group := Node3D.new()
	group.name = "ParkedCars"
	floor_root.add_child(group)
	for slot: Dictionary in PARKED_CARS:
		var at: Vector2 = slot.at
		if not slot.get("angled", false):
			for bay in bays:
				if bay.has_point(at):
					at = bay.get_center()
					break
		var car: Node3D = slot.scene.instantiate()
		car.name = slot.name
		car.rotation.y = slot.yaw
		# The axle pivot is slightly off-center on some models. Center the
		# visible bumper span within the marked bay and its collision body.
		var bumpers: AABB = car.get_node("BumpersAndTrim").get_aabb()
		car.position = Vector3(at.x, 0.0, at.y) - car.basis.z * bumpers.get_center().z
		_set_car_paint(car, slot.paint)
		group.add_child(car)
		cutout.register_tree(car)
		var size: Vector2 = car.get_meta(&"vehicle_footprint")
		size.y = bumpers.size.z
		_add_collision(String(car.name) + "Body", Rect2(at - size * .5, size), -car.rotation.y)


func _set_car_paint(car: Node3D, colour: Color) -> void:
	var finishes: Dictionary = {}
	for node: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(index) as ShaderMaterial
			if source == null or source.shader != VEHICLE_WEAR or source.get_shader_parameter("finish_mode") != 0:
				continue
			if not finishes.has(source):
				var painted: ShaderMaterial = source.duplicate()
				painted.set_shader_parameter("finish_colour", colour)
				finishes[source] = painted
			node.set_surface_override_material(index, finishes[source])


func build_walls() -> void:
	# Merge contiguous exterior edges without adding walls between slabs.
	for outward: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var tangent := Vector2i(abs(outward.y), abs(outward.x))
		for cell: Vector2i in _cells:
			if not _has_wall_edge(cell, outward) or _has_wall_edge(cell - tangent, outward):
				continue
			var end := cell + tangent
			while _has_wall_edge(end, outward):
				end += tangent
			var center := Vector2(cell) + Vector2(outward) * .5 + Vector2(end - cell - tangent) * .5
			var size := Vector2(end - cell) + Vector2(outward).abs() * .22
			var cutaway := outward == Vector2i.DOWN
			var footprint := Rect2(center - size * .5, size)
			if outward == Vector2i.LEFT and cell.x == ENTRY.position.x:
				if not _joined_entry:
					_add_collision("EntranceAirWall", footprint)
			elif outward == Vector2i.RIGHT and cell.x == EXIT.end.x - 1:
				if not _joined_exit:
					_add_collision("ExitAirWall", footprint)
			else:
				_add_concrete_block("Boundary_%d_%d_%d_%d" % [cell.x, cell.y, outward.x, outward.y],
					footprint, .52 if cutaway else CEILING_HEIGHT)
	for row in COLUMN_Z.size():
		var z: float = COLUMN_Z[row]
		for x: int in COLUMN_X:
			_add_concrete_block("Column_%d_%02d" % [x, row + 1], Rect2(x - .5, z - .5, 1, 1), CEILING_HEIGHT)
	# Collision stays in the authoritative 2D gameplay world. The 3D opening
	# has no body, so the vehicle presentation can cross the threshold.
	_add_collision("VehicleEntryAirWall", Rect2(VEHICLE_RECESS.position.x - .5, VEHICLE_RECESS.end.y - .61,
		VEHICLE_RECESS.size.x, .22))


func _has_wall_edge(cell: Vector2i, outward: Vector2i) -> bool:
	var neighbor := cell + outward
	return _cells.has(cell) and not _cells.has(neighbor) and not VEHICLE_RECESS.has_point(neighbor)


func _add_concrete_block(title: String, footprint: Rect2, height: float) -> void:
	var corners := PackedVector2Array([footprint.position,
		Vector2(footprint.end.x, footprint.position.y), footprint.end,
		Vector2(footprint.position.x, footprint.end.y)])
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.mesh = CONCRETE_PRISM._prism(corners, height, _end_fade())
	wall_root.add_child(visual)
	cutout.register_mesh(visual)
	if height < CEILING_HEIGHT:
		# A low foreground cut still blocks light at the real wall height.
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var blocker := MeshInstance3D.new()
		blocker.name = "FullHeightShadow"
		blocker.mesh = CONCRETE_PRISM._prism(corners, CEILING_HEIGHT)
		blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		visual.add_child(blocker)
	_add_collision(title, footprint)


func _add_collision(title: String, footprint: Rect2, angle := 0.0) -> void:
	var body := StaticBody2D.new()
	body.name = title
	body.collision_layer = 4
	body.collision_mask = 0
	var center := footprint.get_center() + Vector2(_offset)
	body.position = center * _world.CELL_PIXELS
	body.rotation = angle
	body.set_meta(&"garage_footprint", Transform2D(angle, center) * Rect2(-footprint.size * .5, footprint.size))
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = footprint.size * _world.CELL_PIXELS
	body.add_child(shape)
	_world.collision_root.add_child(body)


func _shift_bounds(bounds: Vector4) -> Vector4:
	return bounds + Vector4(_offset.x, _offset.y, _offset.x, _offset.y)


func _end_fade() -> Vector4:
	return END_FADE + Vector4.ONE * _offset.x


func build_lighting(parent: Node3D) -> void:
	GARAGE_ART.build_lighting(parent, HALL, ENTRY, EXIT, COLUMN_X, COLUMN_Z)


func build_portals(parent: Node3D, room_id: int) -> VAN_AMBUSH:
	GARAGE_ART.build_portals(parent, ENTRY, EXIT)
	var gate := GARAGE_ART.build_vehicle_entry(parent, VEHICLE_RECESS)
	for part: Node in gate.get_children():
		if part is MeshInstance3D and part.name != &"BlackInteriorFloor":
			cutout.register_mesh(part, part.name in [&"BottomRail", &"ShutterCurtain"])
	var ribs := gate.get_node(^"ShutterRibs") as MultiMeshInstance3D
	ribs.material_override = cutout.material_for(ribs.multimesh.mesh.surface_get_material(0))
	if not _world.spawn_content:
		return null
	var footprint: Rect2 = _world.collision_root.get_node("Column_10_02").get_meta(&"garage_footprint")
	footprint.position -= Vector2(_offset)
	var ambush := VAN_AMBUSH.new()
	ambush.name = "VanAmbush"
	parent.add_child(ambush)
	ambush.configure(_world, gate, footprint, HALL, room_id)
	cutout.register_tree(ambush.van, true)
	return ambush


func spawn_guards(room_id: int) -> void:
	for slot: Dictionary in ENCOUNTER:
		var position: Vector2 = (Vector2(slot.at) + Vector2(_offset)) * _world.CELL_PIXELS
		var enemy: EmployeeEnemy = _world._spawn_regular_employee(room_id, position, &"employee", false, slot.weapon)
		if enemy == null:
			continue
		enemy.name = slot.name
		enemy.set_room_runtime_active(true)
		enemy._apply_live_facing(slot.facing)
		enemy._update_weapon_aim()
		var route: Array[Vector2] = [position]
		if slot.has("patrol_end"):
			route.push_front((Vector2(slot.patrol_end) + Vector2(_offset)) * _world.CELL_PIXELS)
		enemy.set_authored_patrol_route(route)
		if slot.get("crash_guard", false):
			enemy.set_meta(&"garage_crash_guard", true)
			enemy.set_physics_process(false)


static func make_room_tone() -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.name = "GarageRoomTone"
	# Steady room tone stays off the gameplay time-scale bus.
	voice.bus = &"SFX"
	voice.volume_db = -18.0
	var stream := GARAGE_BED.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	voice.stream = stream
	return voice


static func duck_room_tone(voice: AudioStreamPlayer, previous: Tween) -> Tween:
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := voice.create_tween()
	tween.tween_property(voice, "volume_db", -30.0, 0.04)
	tween.tween_interval(0.55)
	tween.tween_property(voice, "volume_db", -18.0, 1.2)
	return tween
