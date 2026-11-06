extends RefCounted
## Builds an editable 3D kitbash from licensed CC0 props. +Z is the front.

const SOURCE_DIR := "res://art/preview/screen_wall/cc0/"
const CRT := SOURCE_DIR + "televisionvintage.glb"
const SERVER := SOURCE_DIR + "server_rack.glb"
const ANTENNA := SOURCE_DIR + "televisionantenna.glb"

static func build() -> Node3D:
	var wall := Node3D.new()
	wall.name = "ScreenWallModel"
	var screens := Node3D.new()
	screens.name = "Televisions"
	wall.add_child(screens)
	# Position, visible glass size, yaw / pitch / roll, depth, option, tint.
	var layout := [
		[Vector3(-2.30, 6.55, 0.45), Vector2(1.90, 1.62), Vector3(-5, 21, -7), "new_game", "新游戏", Color("8bb7c1")],
		[Vector3(-0.18, 7.60, -0.35), Vector2(2.28, 1.62), Vector3(-4, -3, 3), "", "", Color("c4bdcf")],
		[Vector3(2.00, 6.76, 0.65), Vector2(1.30, 2.28), Vector3(2, -25, 7), "", "", Color("aab9af")],
		[Vector3(2.65, 4.58, 1.20), Vector2(2.20, 1.70), Vector3(-3, -31, -6), "continue", "继续", Color("9eafc9")],
		[Vector3(-3.42, 4.22, 1.65), Vector2(1.36, 2.02), Vector3(5, 44, -4), "", "", Color("acb7c9")],
		[Vector3(-1.33, 4.65, -0.12), Vector2(2.25, 1.72), Vector3(3, 12, 4), "settings", "设置", Color("c2b49f")],
		[Vector3(0.50, 5.70, 1.00), Vector2(2.05, 2.05), Vector3(-2, -7, -4), "", "", Color("95b4ac")],
		[Vector3(0.68, 3.55, 0.30), Vector2(2.36, 1.85), Vector3(4, -6, -3), "quit", "退出游戏", Color("c4a5b1")],
		[Vector3(-2.57, 1.73, 1.48), Vector2(1.87, 1.43), Vector3(8, 33, 7), "", "", Color("9cb4bc")],
		[Vector3(-0.38, 1.83, 1.02), Vector2(1.34, 1.20), Vector3(10, 8, -6), "", "", Color("b5a9ba")],
		[Vector3(-1.67, 2.97, 0.50), Vector2(1.18, 0.94), Vector3(-3, 13, -7), "", "", Color("b1b5a3")],
		[Vector3(2.65, 1.62, 1.65), Vector2(1.55, 1.38), Vector3(4, -40, 9), "", "", Color("bbb09c")],
	]
	for i in layout.size():
		var row: Array = layout[i]
		var tv := _television(i, row[1], row[4], row[5])
		tv.position = row[0]
		tv.rotation_degrees = row[2]
		tv.set_meta("action_id", row[3])
		tv.set_meta("option_text", row[4])
		tv.set_meta("screen_tint", row[5])
		screens.add_child(tv)
	var racks := Node3D.new()
	racks.name = "ServerBanks"
	wall.add_child(racks)
	for side in [-1.0, 1.0]:
		for j in 3:
			var rack := _server(j, side)
			racks.add_child(rack)
			rack.position = Vector3(side * (4.4 + 0.59 * j), 0.03, 0.44 - j * 0.72)
			rack.rotation_degrees.y = -side * (28.0 + j * 9.0)
	# The steel chassis behind the monitors makes the stack physically supported.
	var support := Node3D.new()
	support.name = "SteelSupports"
	wall.add_child(support)
	var iron := material(Color("18191b"))
	for y in [0.34, 2.0, 3.50, 5.69, 6.72]:
		box(support, "Crossbeam", Vector3(0, y, -0.81), Vector3(6.1, 0.10, 1.12), iron)
	for x in [-2.9, -0.85, 2.7]:
		box(support, "Upright", Vector3(x, 3.6, -1.25), Vector3(0.12, 7.2, 0.15), iron)
	var cables := Node3D.new()
	cables.name = "CableHarnesses"
	wall.add_child(cables)
	_build_cables(cables, screens)
	# Gather the ceiling and floor harnesses into the narrower central alcove.
	for bundle in cables.get_children():
		if not String(bundle.name).begins_with("MonitorLead"):
			bundle.scale.x = 0.72
	var ground := Node3D.new()
	ground.name = "GroundAndBackdrop"
	wall.add_child(ground)
	box(ground, "Floor", Vector3(0, -0.18, 0), Vector3(22, 0.30, 12), material(Color("0a131c")))
	box(ground, "BackWall", Vector3(0, 4.7, -2.7), Vector3(22, 10, 0.18), material(Color("09131a")))
	for side in [-1.0, 1.0]:
		box(ground, "ForegroundPowerUnit", Vector3(side * 7.3, 0.6, 3.1), Vector3(1.65, 1.4, 1.6), material(Color("18282d")))
		for k in 7:
			box(ground, "PowerVent", Vector3(side * 7.3, 0.19 + k * 0.13, 3.915), Vector3(1.3, 0.035, 0.02), material(Color("060e15")))
		box(ground, "PowerLED", Vector3(side * 7.8, 1.12, 3.925), Vector3(0.075, 0.055, 0.025), material(Color("bc8048"), true))
	_set_owner(wall, wall)
	return wall


static func material(color: Color, emission := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	mat.metallic = 0.0
	mat.metallic_specular = 0.08
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.6
	return mat


static func box(parent: Node3D, label: String, position: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = position
	node.material_override = mat
	parent.add_child(node)
	return node


static func _map_crt_vertex(v: Vector3, size: Vector2) -> Vector3:
	# Keep the original CRT bevel, knobs and rear enclosure; resize the glass,
	# compress the side controls, and keep a narrow bezel for a monitor wall.
	var x: float
	if v.x < 0.0345:
		x = -size.x * 0.5 + (v.x - 0.0345) * 2.7
	elif v.x <= 0.2675:
		x = (v.x - 0.151) / 0.233 * size.x
	else:
		x = size.x * 0.5 + (v.x - 0.2675) * 2.1
	var y: float
	if v.y < 0.034:
		y = -size.y * 0.5 + (v.y - 0.034) * 2.7
	elif v.y <= 0.236:
		y = (v.y - 0.135) / 0.202 * size.y
	else:
		y = size.y * 0.5 + (v.y - 0.236) * 2.7
	return Vector3(x, y, v.z * 3.3)


static func _television(index: int, size: Vector2, option: String, tint: Color) -> Node3D:
	var tv := Node3D.new()
	tv.name = "TV_%02d" % (index + 1)
	tv.set_meta("screen_size", size)
	tv.set_meta("asset_source", "Kenney Furniture Kit / televisionVintage / CC0")
	var original: Node3D = load(CRT).instantiate()
	var source := original.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := ArrayMesh.new()
	for surface in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in vertices.size():
			vertices[v] = _map_crt_vertex(vertices[v], size)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		# Reshaping isn't uniform. Regenerate actual face normals after the edit.
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.generate_normals()
		st.commit(mesh)
	var chassis := MeshInstance3D.new()
	chassis.name = "CC0_CRT_Chassis"
	chassis.mesh = mesh
	tv.add_child(chassis)
	var colors := [Color("515457"), Color("242527"), Color("363739"), Color("101214")]
	for surface in mesh.get_surface_count():
		var color: Color = colors[surface % colors.size()]
		if index in [1, 8]:
			color = color.lerp(Color("b4b1a7"), 0.42)
		elif index % 3 == 2:
			color = color.lerp(Color("17191d"), 0.44)
		chassis.set_surface_override_material(surface, material(color))
	original.free()
	var glass := MeshInstance3D.new()
	glass.name = "Screen"
	glass.mesh = _glass_mesh(size)
	glass.material_override = material(tint * 0.45, true)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tv.add_child(glass)
	var screen_body := StaticBody3D.new()
	screen_body.name = "ScreenHitArea"
	screen_body.collision_layer = 2
	screen_body.collision_mask = 0
	tv.add_child(screen_body)
	_add_shape(screen_body, Vector3(0, 0, 0.025), Vector3(size.x, size.y, 0.035))
	var body := StaticBody3D.new()
	body.name = "ChassisOcclusion"
	body.collision_layer = 1
	body.collision_mask = 0
	tv.add_child(body)
	_add_shape(body, Vector3(0.10, 0, -0.80), Vector3(size.x + 0.40, size.y + 0.18, 0.16))
	for side in [-1.0, 1.0]:
		_add_shape(body, Vector3(0.10, side * (size.y * 0.5 + 0.05), -0.39), Vector3(size.x + 0.40, 0.10, 0.80))
	_add_shape(body, Vector3(-size.x * 0.5 - 0.05, 0, -0.39), Vector3(0.10, size.y, 0.80))
	_add_shape(body, Vector3(size.x * 0.5 + 0.14, 0, -0.39), Vector3(0.28, size.y, 0.80))
	# Slim vents and sockets added to the donated housing, fully modeled on sides.
	var dark := material(Color("061016"))
	for side in [-1.0, 1.0]:
		for v in 6:
			box(tv, "SideVent", Vector3(side * (size.x * 0.5 + (0.095 if side < 0.0 else 0.30)), -size.y * 0.24 + v * 0.10, -0.43), Vector3(0.012, 0.025, 0.36), dark)
	box(tv, "StatusLED", Vector3(size.x * 0.5 + 0.17, -size.y * 0.34, 0.012), Vector3(0.045, 0.035, 0.025), material(tint, true))
	var nameplate := Label3D.new()
	nameplate.name = "ChassisID"
	nameplate.text = "%02d" % (index + 1)
	nameplate.font = load("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
	nameplate.font_size = 16
	nameplate.pixel_size = 0.004
	nameplate.position = Vector3(size.x * 0.5 + 0.16, -size.y * 0.12, 0.015)
	nameplate.modulate = Color("77989d")
	nameplate.outline_size = 0
	tv.add_child(nameplate)
	if index in [0, 3]:
		var antenna: Node3D = load(ANTENNA).instantiate()
		antenna.name = "CC0_Antenna"
		antenna.scale = Vector3.ONE * 2.3
		antenna.position = Vector3(0, size.y * 0.5 + 0.10, -0.32)
		tv.add_child(antenna)
	return tv


static func _glass_mesh(size: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const NX := 16
	const NY := 12
	for y in NY + 1:
		for x in NX + 1:
			var uv := Vector2(float(x) / NX, float(y) / NY)
			var q := uv * 2.0 - Vector2.ONE
			var puff := 0.06 * (1.0 - q.x * q.x) * (1.0 - q.y * q.y)
			st.set_uv(uv)
			st.add_vertex(Vector3(q.x * size.x * 0.5, -q.y * size.y * 0.5, -0.045 + puff))
	for y in NY:
		for x in NX:
			var a := y * (NX + 1) + x
			for index in [a, a + 1, a + NX + 1, a + 1, a + NX + 2, a + NX + 1]:
				st.add_index(index)
	st.generate_normals()
	return st.commit()


static func _add_shape(body: StaticBody3D, position: Vector3, dimensions: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position = position
	body.add_child(collision)


static func _server(index: int, side: float) -> Node3D:
	var group := Node3D.new()
	group.name = ("Left" if side < 0 else "Right") + "Rack_%02d" % index
	var rack: Node3D = load(SERVER).instantiate()
	rack.name = "CC0_ServerRack"
	rack.scale = Vector3(1.65, 3.0 - index * 0.21, 1.12)
	group.add_child(rack)
	for node in rack.find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		# The opaque stock glass would hide the equipment; leave the door frame.
		if String(piece.name).contains("slate") and String(piece.get_parent().name).contains("door"):
			piece.visible = false
		for s in piece.mesh.get_surface_count():
			var old := piece.get_active_material(s) as StandardMaterial3D
			if old == null:
				continue
			var mat := old.duplicate() as StandardMaterial3D
			mat.albedo_color = mat.albedo_color.lerp(Color("202124"), 0.84)
			mat.roughness = 0.97
			mat.metallic = 0.0
			mat.metallic_specular = 0.03
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			piece.set_surface_override_material(s, mat)
	var panel := material(Color("292a2d"))
	var grille := material(Color("090a0c"))
	for row in 12:
		var y := 0.25 + row * 0.43
		box(group, "ServerDrawer", Vector3(0, y, 0.59), Vector3(0.90, 0.32, 0.12), panel)
		for vent in 5:
			box(group, "ServerVent", Vector3(-0.25 + vent * 0.098, y, 0.655), Vector3(0.048, 0.20, 0.012), grille)
		box(group, "ServerLED", Vector3(0.34, y + 0.055, 0.66), Vector3(0.04, 0.035, 0.015), material(Color("6bafa2") if row % 4 else Color("be855d"), true))
	return group


static func _build_cables(parent: Node3D, screens: Node3D) -> void:
	var dark := material(Color("071117"))
	var teal := material(Color("203b40"))
	var amber := material(Color("534433"))
	# Ceiling bundles, then individual leads into rear sockets of every monitor.
	for side in [-1.0, 1.0]:
		for strand in 6:
			var offset := strand * 0.075
			var points := PackedVector3Array([
				Vector3(side * (8.3 + offset), 9.3, -0.5),
				Vector3(side * (6.4 + offset), 7.9, 0.5),
				Vector3(side * (4.8 + offset), 7.45 - offset, 0.8),
				Vector3(side * (3.3 + offset), 7.2 - offset, 0.4),
				Vector3(side * (2.1 + offset), 6.82, -0.6),
			])
			cable(parent, "CeilingBundle", points, 0.030 + (strand % 2) * 0.014, dark if strand % 3 else teal)
		for strand in 5:
			var points := PackedVector3Array([
				Vector3(side * (6.6 + strand * 0.08), 7.4, 0.4),
				Vector3(side * (5.96 + strand * 0.06), 5.8, 1.2),
				Vector3(side * (5.9 + strand * 0.10), 3.7, 1.7),
				Vector3(side * (6.5 + strand * 0.09), 1.1, 1.3),
				Vector3(side * (4.3 + strand * 0.11), 0.08, 2.2),
				Vector3(side * (1.2 + strand * 0.12), 0.08, 3.1),
			])
			cable(parent, "SideLoom", points, 0.035 + (strand % 2) * 0.018, dark if strand % 3 else teal)
	for i in screens.get_child_count():
		var tv := screens.get_child(i) as Node3D
		var side := -1.0 if tv.position.x < 0 else 1.0
		var top: float = tv.get_meta("screen_size").y * 0.5
		var socket := tv.transform * Vector3(0.55, top, -0.65)
		var points := PackedVector3Array([socket, socket + Vector3(0.2, 0.32, 0.25), Vector3(side * (5.45 + i * 0.03), maxf(0.5, socket.y - 0.7), -0.7), Vector3(side * 6.2, maxf(0.3, socket.y - 1.0), 0.2)])
		cable(parent, "MonitorLead_%02d" % i, points, 0.026, teal if i % 3 else dark)
	# Two readable foreground loops follow seams instead of obscuring menu words.
	cable(parent, "HangingLoopLeft", PackedVector3Array([Vector3(-4.0,8.6,1.2),Vector3(-3.2,7.4,1.45),Vector3(-2.0,6.92,1.5),Vector3(-1.2,7.5,1.35),Vector3(-0.7,8.8,0.4)]),0.055,dark)
	cable(parent, "HangingLoopRight", PackedVector3Array([Vector3(3.5,8.4,1.1),Vector3(4.85,7.0,1.1),Vector3(5.65,6.4,1.6),Vector3(6.4,7.05,1.0),Vector3(6.8,8.3,-0.4)]),0.050,dark)
	for i in 9:
		var points := PackedVector3Array()
		for k in 28:
			var t := float(k) / 27.0
			points.append(Vector3(-7.0 + t * 14.0, 0.045 + i * 0.007, 1.35 + i * 0.15 + sin(t * TAU * 1.2 + i * 0.6) * 0.58))
		cable(parent, "FloorCable", points, 0.025 + (i % 3) * 0.009, amber if i == 5 else dark)
	for side in [-1.0,1.0]:
		var coil := PackedVector3Array()
		for i in 90:
			var t := i / 89.0
			var a := t * TAU * 3.3
			coil.append(Vector3(side * 4.8 + cos(a) * (0.9 + t * 0.4), 0.06 + t * 0.04, 2.1 + sin(a) * (0.45 + t * 0.15)))
		cable(parent, "CoiledSlack", coil, 0.045, teal)


static func cable(parent: Node3D, label: String, controls: PackedVector3Array, radius: float, mat: Material) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.13
	for i in controls.size():
		var previous := controls[maxi(0, i - 1)]
		var next := controls[mini(controls.size() - 1, i + 1)]
		var tangent := (next - previous) * 0.18
		curve.add_point(controls[i], -tangent if i > 0 else Vector3.ZERO, tangent if i < controls.size() - 1 else Vector3.ZERO)
	var points := curve.get_baked_points()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 6
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var normal := tangent.cross(Vector3.UP).normalized()
		if normal.length_squared() < 0.5:
			normal = tangent.cross(Vector3.RIGHT).normalized()
		var binormal := tangent.cross(normal).normalized()
		for side in SIDES:
			var a := float(side) / SIDES * TAU
			var offset := normal * cos(a) + binormal * sin(a)
			st.set_normal(offset)
			st.add_vertex(points[i] + offset * radius)
	for i in points.size() - 1:
		for side in SIDES:
			var a := i * SIDES + side
			var b := i * SIDES + (side + 1) % SIDES
			for v in [a,b,a+SIDES,b,b+SIDES,a+SIDES]:
				st.add_index(v)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = mat
	parent.add_child(node)


static func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		# Bake normal editable nodes rather than preserving imported-scene links
		# alongside owned duplicates of the imported descendants.
		child.scene_file_path = ""
		_set_owner(child, owner_node)
