extends RefCounted
## Parking paint, fluorescent fixtures and service hardware for 0-2.

const MAINTENANCE = preload("res://scripts/testing/maintenance_environment.gd")
const PAINT = preload("res://shaders/dream3d/parking_lane_paint.gdshader")
const STALL_COLOUR := Color("bfc2b1")
const LANE_COLOUR := Color("a6af9a")
const PAINT_HEIGHT := .009
const STALL_WIDTH := .092
const COLUMN_SETBACK := .72
const SHUTTER_RAISED_Y := 2.285
const SHUTTER_RAIL_HEIGHT := .036
const SHUTTER_RIB_PITCH := .114


static func build_markings(parent: Node3D, hall: Rect2i, entry: Rect2i, exit: Rect2i, columns_x: Array, columns_z: Array) -> Array[Rect2]:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bays: Array[Rect2] = []
	var sides := [Vector2(hall.position.x - .23, columns_x[0] + .28),
		Vector2(columns_x[1] - .28, hall.end.x - .77)]
	# Two full bays per gap. Each pier has an unmarked strip through the entire
	# depth of the parking band, so no stall or boundary runs into a column.
	for side: Vector2 in sides:
		for index in columns_z.size() - 1:
			_stall_group(mesh, bays, side, columns_z[index] + COLUMN_SETBACK, columns_z[index + 1] - COLUMN_SETBACK, 2)
	_stall_group(mesh, bays, sides[0], .40, columns_z[0] - COLUMN_SETBACK, 1)
	_stall_group(mesh, bays, sides[0], entry.end.y - .22, hall.end.y - .74, 1)
	_stall_group(mesh, bays, sides[1], columns_z.back() + COLUMN_SETBACK + .28, columns_z.back() + COLUMN_SETBACK + 2.90, 1)

	var lane_center := float(hall.get_center().x)
	for z: float in [3.15, 9.1, 16.4, 19.15, 24.58, 27.0]:
		_stripe(mesh, Vector2(lane_center, z - .43), Vector2(lane_center, z + .43), .088, LANE_COLOUR)
	_arrow(mesh, Vector2(2.06, entry.end.y - 1.0), Vector2.RIGHT)
	for z: float in [5.78, 13.28, 21.8]:
		_arrow(mesh, Vector2(lane_center, z), Vector2.UP)
	_arrow(mesh, Vector2(exit.position.x - 3.25, exit.position.y + .50), Vector2.RIGHT)

	var finish := ShaderMaterial.new()
	finish.shader = PAINT
	var markings := MeshInstance3D.new()
	markings.name = "ParkingAndLanePaint"
	markings.mesh = mesh.commit()
	markings.material_override = finish
	markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings.set_meta(&"stall_bays", bays)
	parent.add_child(markings)
	return bays


static func _stall_group(mesh: SurfaceTool, bays: Array[Rect2], side: Vector2, front: float, back: float, count: int) -> void:
	var spacing := (back - front) / count
	var inset := STALL_WIDTH * .5
	for index in count + 1:
		var z := front + spacing * index
		_stripe(mesh, Vector2(side.x + inset, z), Vector2(side.y - inset, z), STALL_WIDTH, STALL_COLOUR)
		if index < count:
			bays.append(Rect2(side.x, z, side.y - side.x, spacing))
	for x: float in [side.x, side.y]:
		_stripe(mesh, Vector2(x, front - inset), Vector2(x, back + inset), STALL_WIDTH, STALL_COLOUR)


static func _arrow(mesh: SurfaceTool, at: Vector2, direction: Vector2) -> void:
	var base := at + direction * .13
	var side := direction.orthogonal() * .34
	_stripe(mesh, at - direction * .62, base, .13, LANE_COLOUR)
	_triangle(mesh, base - side, base + side, at + direction * .61, LANE_COLOUR)


static func _stripe(mesh: SurfaceTool, start: Vector2, end: Vector2, width: float, colour: Color) -> void:
	var offset := (end - start).normalized().orthogonal() * width * .5
	_triangle(mesh, start - offset, end - offset, end + offset, colour)
	_triangle(mesh, start - offset, end + offset, start + offset, colour)


static func _triangle(mesh: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, colour: Color) -> void:
	if (b - a).cross(c - a) < 0.0:
		var swap := b
		b = c
		c = swap
	for point: Vector2 in [a, b, c]:
		mesh.set_normal(Vector3.UP)
		mesh.set_color(colour)
		mesh.add_vertex(Vector3(point.x, PAINT_HEIGHT, point.y))


static func build_services(parent: Node3D, hall: Rect2i, column_x: Array, column_z: Array, bays: Array[Rect2]) -> void:
	var root := Node3D.new()
	root.name = "GarageServices"
	parent.add_child(root)
	var metal := MAINTENANCE.metal(Color("454b43"), .67)
	var rubber := MAINTENANCE.metal(Color("262a25"), .92)
	rubber.metallic = 0.0
	var paint := MAINTENANCE.metal(Color("878062"), .83)
	paint.metallic = 0.0
	for x: int in column_x:
		MAINTENANCE.pipe(root, Vector3(x, 2.53, .15), Vector3(x, 2.53, hall.end.y - 1.08), .046, metal)
		MAINTENANCE.pipe(root, Vector3(x + .23, 2.43, .15), Vector3(x + .23, 2.43, hall.end.y - 1.08), .025, rubber)
		for z: float in column_z:
			MAINTENANCE.box(root, "ColumnKickGuard", Vector3(1.036, .15, 1.036), Vector3(x, .075, z), rubber)
			MAINTENANCE.box(root, "ColumnSafetyBand", Vector3(1.018, .22, 1.018), Vector3(x, .26, z), paint)
	# Low wheel stops sit at the backs of the parking bays, clear of the road.
	for bay in bays:
		var x := bay.position.x + .36 if bay.position.x < hall.get_center().x else bay.end.x - .36
		MAINTENANCE.box(root, "WheelStop", Vector3(.14, .085, 1.12), Vector3(x, .0425, bay.get_center().y), rubber)


static func build_lighting(parent: Node3D, hall: Rect2i, entry: Rect2i, exit: Rect2i, column_x: Array, column_z: Array) -> void:
	var rows: Array[float] = [1.45]
	for index in column_z.size() - 1:
		rows.append((column_z[index] + column_z[index + 1]) * .5)
	var anchors: Array[Vector3] = []
	for z in rows:
		anchors.append(Vector3(column_x[0] - .14, 2.43, z - .18))
		anchors.append(Vector3(column_x[1] + .14, 2.43, z + .30))
	anchors.append(Vector3(entry.position.x + 1.05, 2.43, entry.position.y + .47))
	anchors.append(Vector3(column_x[1] + .14, 2.43, hall.end.y - 2.64))
	anchors.append(Vector3(exit.position.x + 1.31, 2.37, exit.position.y + .32))
	for index in anchors.size():
		var fixture := MAINTENANCE.cold_fixture(parent, "GarageFluorescent_%02d" % index, anchors[index], index)
		var housing: MeshInstance3D = fixture.get_node("LampHousing")
		housing.mesh.size = Vector3(1.65, .12, .17)
		housing.material_override.albedo_color = Color("3a4138")
		var tube: MeshInstance3D = fixture.get_node("ColdTube")
		tube.mesh.size = Vector3(1.46, .07, .20)
		tube.position = Vector3(0, -.086, .05)
		tube.material_override.albedo_color = Color("d1dbca")
		tube.material_override.emission = Color("ccd9c2")
		tube.material_override.emission_energy_multiplier = 1.28
		var light: OmniLight3D = fixture.get_node("ColdPool")
		light.position = Vector3(0, -.27, .04)
		light.light_color = Color("d0dbca") if index % 2 == 0 else Color("bccfbe")
		light.light_energy = 1.65 if index == anchors.size() - 1 else 2.3
		light.omni_range = 3.7 if index == anchors.size() - 1 else 6.15
		light.omni_attenuation = 1.4


static func build_portals(parent: Node3D, entry: Rect2i, exit: Rect2i) -> void:
	var plate := MAINTENANCE.metal(Color("23392d"), .65)
	for portal in [[entry.position.x + .72, entry.position.y + .5, "B2"],
		[exit.position.x + 1.12, exit.position.y + .5, "EXIT >"]]:
		var x: float = portal[0]
		var z: float = portal[1]
		var is_exit: bool = portal[2] == "EXIT >"
		var sign_at := Vector3(x, 2.04, z - .855)
		var backing := plate
		if is_exit:
			backing = plate.duplicate() as StandardMaterial3D
			backing.emission_enabled = true
			backing.emission = Color("298e4f")
			backing.emission_energy_multiplier = .65
		MAINTENANCE.box(parent, "ExitSignPlate" if is_exit else "SignPlate", Vector3(1.30, .31, .06), sign_at, backing)
		var sign := Label3D.new()
		sign.name = "ExitWayfinding" if is_exit else "Wayfinding"
		sign.text = portal[2]
		sign.font_size = 28
		sign.pixel_size = .0094
		sign.outline_size = 0
		sign.modulate = Color(.40, 1.32, .62) if is_exit else Color("c7d8c6")
		sign.position = sign_at + Vector3(0, 0, .032)
		parent.add_child(sign)
		if is_exit:
			var green := OmniLight3D.new()
			green.name = "ExitGlow"
			green.position = sign_at + Vector3(0, -.08, .38)
			green.light_color = Color("54ff86")
			green.light_energy = .72
			green.light_cull_mask = 15
			green.omni_range = 2.15
			green.omni_attenuation = 1.6
			parent.add_child(green)


static func build_vehicle_entry(parent: Node3D, recess: Rect2i) -> Node3D:
	var doorway := Node3D.new()
	doorway.name = "VehicleEntry"
	var width := float(recess.size.x)
	var depth := float(recess.size.y)
	doorway.position = Vector3(recess.position.x + width * .5 - .5, 0, recess.end.y - .5)
	parent.add_child(doorway)

	var black := MAINTENANCE.wall_top_black()
	var interior_floor := MAINTENANCE.box(doorway, "BlackInteriorFloor", Vector3(width, .12, depth),
		Vector3(0, -.06, -depth * .5), black)
	interior_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MAINTENANCE.box(doorway, "BlackInteriorBack", Vector3(width, 2.65, .06),
		Vector3(0, 1.325, -depth), black)

	var rail := MAINTENANCE.metal(Color("3e4845"), .53)
	var slat := MAINTENANCE.metal(Color("68716b"), .49)
	var seam := MAINTENANCE.metal(Color("292e2c"), .68)
	for side: float in [-1.0, 1.0]:
		var x := side * (width * .5 - .079)
		MAINTENANCE.box(doorway, "BlackInteriorSide", Vector3(.10, 2.65, depth),
			Vector3(x, 1.325, -depth * .5), black)
		MAINTENANCE.box(doorway, "ShutterGuide", Vector3(.158, 2.57, .22), Vector3(x, 1.285, .014), rail)
		MAINTENANCE.box(doorway, "GuideSlot", Vector3(.043, 2.44, .028), Vector3(x, 1.22, .133), seam)
	MAINTENANCE.box(doorway, "RollerHousing", Vector3(width + .10, .27, .38),
		Vector3(0, 2.62, -.034), rail)
	# Only the upper stack of raised slats is visible. Keep the vehicle opening
	# clear below the bottom rail at y=2.27.
	for index in 4:
		MAINTENANCE.box(doorway, "RaisedSlat", Vector3(width - .24, .050, .084),
			Vector3(0, 2.325 + .053 * index, .137), slat)
	var clear_width := width - .24
	MAINTENANCE.box(doorway, "BottomRail", Vector3(clear_width, SHUTTER_RAIL_HEIGHT, .13),
		Vector3(0, SHUTTER_RAISED_Y, .142), seam)
	var curtain := MAINTENANCE.box(doorway, "ShutterCurtain", Vector3(clear_width, 1.0, .060),
		Vector3(0, SHUTTER_RAISED_Y, .134), slat)
	curtain.hide()
	var rib := BoxMesh.new()
	rib.size = Vector3(clear_width, .025, .028)
	rib.material = seam
	var ribs := MultiMesh.new()
	ribs.transform_format = MultiMesh.TRANSFORM_3D
	ribs.mesh = rib
	ribs.instance_count = floori(SHUTTER_RAISED_Y / SHUTTER_RIB_PITCH)
	ribs.visible_instance_count = 0
	for index in ribs.instance_count:
		ribs.set_instance_transform(index, Transform3D(Basis.IDENTITY,
			Vector3(0, (index + .66) * SHUTTER_RIB_PITCH, 0)))
	var ribs_node := MultiMeshInstance3D.new()
	ribs_node.name = "ShutterRibs"
	ribs_node.position.z = .165
	ribs_node.multimesh = ribs
	doorway.add_child(ribs_node)
	return doorway


static func lower_vehicle_shutter(doorway: Node3D, fraction: float) -> void:
	var rail: MeshInstance3D = doorway.get_node("BottomRail")
	var curtain: MeshInstance3D = doorway.get_node("ShutterCurtain")
	var ribs: MultiMeshInstance3D = doorway.get_node("ShutterRibs")
	rail.position.y = lerpf(SHUTTER_RAISED_Y, SHUTTER_RAIL_HEIGHT * .5, fraction)
	var span := SHUTTER_RAISED_Y - rail.position.y
	var lower_edge := rail.position.y + SHUTTER_RAIL_HEIGHT * .5
	curtain.visible = span > .001
	curtain.position.y = lower_edge + span * .5
	curtain.scale.y = maxf(span, .001)
	ribs.position.y = lower_edge
	ribs.multimesh.visible_instance_count = floori(span / SHUTTER_RIB_PITCH + .20)
