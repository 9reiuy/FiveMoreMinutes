extends SceneTree
## Authoring tool for the baked, editable vehicle scenes.
## Ground-level origin, front +Z, axle rotation around local X.

const OUTPUT := "res://scenes/dream/props/vehicles"
const VEHICLE_WEAR = preload("res://shaders/dream3d/vehicle_surface_wear.gdshader")
const VEHICLES := [
	{
		"name": "Sedan", "paint": Color("755354"), "sill": .25, "tyre": .32, "tyre_width": .22,
		"axles": Vector2(-1.32, 1.32), "track": .74, "roof": 1.38, "roof_width": .65,
		"wear": {"seed": Vector2(12, 7), "bonnet": Vector4(.34, 1.27, .57, 1.71),
			"roof": Vector4(-.44, -.82, -.49, -.55), "flank": Vector4(-.63, .56, -.17, .53), "side": -1.0},
		"cabin": Vector4(-1.46, .96, -.98, .33),
		"body": [
			Vector4(-2.13, .75, .66, .72), Vector4(-1.96, .84, .76, .82),
			Vector4(-1.46, .865, .81, .875), Vector4(-.86, .865, .83, .90),
			Vector4(.96, .865, .81, .88), Vector4(1.73, .84, .73, .80),
			Vector4(2.08, .76, .66, .72),
		],
	},
	{
		"name": "SUV", "paint": Color("65715c"), "sill": .34, "tyre": .37, "tyre_width": .255,
		"axles": Vector2(-1.37, 1.36), "track": .82, "roof": 1.77, "roof_width": .74,
		"wear": {"seed": Vector2(27, 5), "bonnet": Vector4(.46, 1.37, .58, 1.83),
			"roof": Vector4(.38, -1.48, .53, -.89), "flank": Vector4(-1.01, .77, -.44, .70), "side": 1.0},
		"cabin": Vector4(-2.04, .98, -1.84, .53),
		"body": [
			Vector4(-2.16, .87, .83, .93), Vector4(-2.04, .93, .91, 1.00),
			Vector4(-1.63, .95, .94, 1.03), Vector4(.98, .95, .94, 1.03),
			Vector4(1.78, .93, .91, 1.00), Vector4(2.13, .87, .84, .92),
		],
	},
	{
		"name": "FUV", "paint": Color("586f80"), "sill": .255, "tyre": .325, "tyre_width": .225,
		"axles": Vector2(-1.38, 1.34), "track": .765, "roof": 1.68, "roof_width": .72,
		"wear": {"seed": Vector2(41, 9), "bonnet": Vector4(-.42, 1.57, -.31, 1.93),
			"roof": Vector4(.48, -1.62, .59, -1.24), "flank": Vector4(-.76, .68, .08, .65), "side": 1.0},
		"cabin": Vector4(-2.03, 1.42, -1.82, .70),
		"body": [
			Vector4(-2.16, .80, .75, .86), Vector4(-2.03, .88, .82, .91),
			Vector4(-1.56, .91, .85, .94), Vector4(.94, .91, .85, .94),
			Vector4(1.42, .89, .81, .90), Vector4(1.88, .85, .73, .80),
			Vector4(2.12, .76, .65, .72),
		],
	},
	{
		"name": "CargoVan", "paint": Color("d5d7ce"), "sill": .33, "tyre": .35, "tyre_width": .235,
		"axles": Vector2(-1.66, 1.55), "track": .85, "roof": 2.09, "roof_width": .87,
		"wear": {"seed": Vector2(53, 11), "bonnet": Vector4(.29, 1.82, .42, 2.19),
			"roof": Vector4(.48, -1.76, .58, -1.28), "flank": Vector4(-1.37, .66, -.35, .62), "side": 1.0},
		"cabin": Vector4(-2.49, 1.56, -2.37, .84),
		"body": [
			Vector4(-2.56, .92, .89, .98), Vector4(-2.39, .97, .97, 1.065),
			Vector4(-1.91, .995, .985, 1.075), Vector4(1.23, .995, .985, 1.075),
			Vector4(1.56, .966, .93, 1.025), Vector4(2.15, .93, .82, .91),
			Vector4(2.48, .87, .74, .825),
		],
	},
]


class MeshBatch:
	var surfaces: Dictionary = {}

	func triangle(material: Material, a: Vector3, b: Vector3, c: Vector3, outside: Vector3) -> void:
		var normal := (c - a).cross(b - a)
		if normal.length_squared() < .0000000001:
			return
		if normal.dot(outside) < 0.0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		if not surfaces.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			surfaces[material] = surface
		var target: SurfaceTool = surfaces[material]
		for point: Vector3 in [a, b, c]:
			target.set_normal(normal.normalized())
			target.add_vertex(point)

	func quad(material: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outside: Vector3) -> void:
		triangle(material, a, b, c, outside)
		triangle(material, a, c, d, outside)

	func box(material: Material, center: Vector3, size: Vector3) -> void:
		var p := center - size * .5
		var q := center + size * .5
		var a := Vector3(p.x, p.y, p.z)
		var b := Vector3(q.x, p.y, p.z)
		var c := Vector3(q.x, q.y, p.z)
		var d := Vector3(p.x, q.y, p.z)
		var e := Vector3(p.x, p.y, q.z)
		var f := Vector3(q.x, p.y, q.z)
		var g := Vector3(q.x, q.y, q.z)
		var h := Vector3(p.x, q.y, q.z)
		quad(material, a, b, c, d, Vector3.FORWARD)
		quad(material, e, h, g, f, Vector3.BACK)
		quad(material, a, d, h, e, Vector3.LEFT)
		quad(material, b, f, g, c, Vector3.RIGHT)
		quad(material, d, c, g, h, Vector3.UP)
		quad(material, a, e, f, b, Vector3.DOWN)

	func bake() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for surface: SurfaceTool in surfaces.values():
			surface.index()
			surface.commit(mesh)
		return mesh


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not create vehicle scene directory")
		quit(1)
		return
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--model="):
			requested = argument.trim_prefix("--model=")
	var wrote := false
	for spec: Dictionary in VEHICLES:
		if not requested.is_empty() and spec.name != requested:
			continue
		var car := _make_vehicle(spec)
		var packed := PackedScene.new()
		error = packed.pack(car)
		if error == OK:
			error = ResourceSaver.save(packed, OUTPUT.path_join("Vehicle%s.tscn" % spec.name))
		car.free()
		if error != OK:
			push_error("Could not save %s (%s)" % [spec.name, error])
			quit(1)
			return
		print("Baked editable vehicle: ", spec.name)
		wrote = true
	if not wrote:
		push_error("Unknown vehicle model: " + requested)
	quit(0 if wrote else 1)


func _make_vehicle(spec: Dictionary) -> Node3D:
	var car := Node3D.new()
	car.name = "Vehicle%s" % spec.name
	var front: Vector4 = spec.body.back()
	var rear: Vector4 = spec.body.front()
	var half_width: float = spec.track + spec.tyre_width * .5
	for station: Vector4 in spec.body:
		half_width = maxf(half_width, station.y)
	car.set_meta(&"vehicle_footprint", Vector2(2.0 * half_width, front.x - rear.x + .16))
	var mats := {
		"paint": _worn_finish("Worn body paint", spec.paint, .56, .30, spec, 0),
		"trim": _worn_finish("Road dust on rubber and trim", Color("222829"), .85, .12, spec, 1),
		"glass": _worn_finish("Smoked safety glass", Color("263844"), .34, .32, spec, 2),
		"steel": _material("Satin hardware", Color("939b98"), .52, .27),
		"white": _material("Lamp reflector", Color("d0d0b4"), .44, .29),
		"red": _material("Tail lamp lens", Color("8c302d"), .48, .25),
		"amber": _material("Turn signal lens", Color("ac773c"), .47, .21),
	}
	var hull := MeshBatch.new()
	_build_hull(hull, spec, mats)
	_mesh_node(car, "BodyShell", hull.bake())
	var cabin := MeshBatch.new()
	_build_cabin(cabin, spec, mats)
	_mesh_node(car, "CabinAndRoof", cabin.bake())
	var trim := MeshBatch.new()
	_build_trim(trim, spec, mats)
	_mesh_node(car, "BumpersAndTrim", trim.bake())

	var wheel_mesh := _build_wheel(spec, mats)
	var wheels := Node3D.new()
	wheels.name = "Wheels"
	_own(car, wheels)
	for axle: String in ["Front", "Rear"]:
		for side: String in ["Left", "Right"]:
			var wheel := Node3D.new()
			wheel.name = axle + side
			wheel.position = Vector3(-spec.track if side == "Left" else spec.track, spec.tyre,
				spec.axles.y if axle == "Front" else spec.axles.x)
			_own(wheels, wheel)
			_mesh_node(wheel, "Spin", wheel_mesh)
	if spec.name == "CargoVan":
		_build_cargo_doors(car, rear, mats)
		_make_portal_compatible(car, spec)
	return car


func _material(title: String, colour: Color, roughness: float, specular: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = title
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic_specular = specular
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


func _worn_finish(title: String, colour: Color, roughness: float, specular: float, spec: Dictionary, mode: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = title
	material.resource_local_to_scene = true
	material.shader = VEHICLE_WEAR
	material.set_shader_parameter("finish_colour", colour)
	material.set_shader_parameter("finish_roughness", roughness)
	material.set_shader_parameter("finish_specular", specular)
	material.set_shader_parameter("finish_mode", mode)
	material.set_shader_parameter("wear_amount", .88)
	material.set_shader_parameter("stain_offset", spec.wear.seed)
	material.set_shader_parameter("upper_scrape", spec.wear.bonnet)
	material.set_shader_parameter("roof_scrape", spec.wear.roof)
	material.set_shader_parameter("flank_scrape", spec.wear.flank)
	material.set_shader_parameter("flank_side", spec.wear.side)
	material.set_shader_parameter("roof_height", spec.roof)
	return material


func _own(parent: Node3D, child: Node3D) -> void:
	parent.add_child(child)
	child.owner = parent.owner if parent.owner != null else parent


func _mesh_node(parent: Node3D, title: String, mesh: Mesh) -> void:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	_own(parent, node)


# Each body station stores Z, shoulder half-width, shoulder height, deck height.
func _profile(spec: Dictionary, z: float) -> Vector4:
	for index in spec.body.size() - 1:
		var a: Vector4 = spec.body[index]
		var b: Vector4 = spec.body[index + 1]
		if z <= b.x:
			return a.lerp(b, clampf((z - a.x) / (b.x - a.x), 0.0, 1.0))
	return spec.body.back()


func _arch(spec: Dictionary, z: float) -> float:
	var radius: float = spec.tyre + .082
	var nearest: float = minf(absf(z - spec.axles.x), absf(z - spec.axles.y))
	var arch := sqrt(maxf(0.0, 1.0 - pow(nearest / radius, 2.0)))
	return lerpf(spec.sill, spec.tyre * 2.0 + .054, arch)


func _shoulder(p: Vector4, side: float) -> Vector3:
	return Vector3(side * p.y, p.z, p.x)


func _deck(p: Vector4, side: float) -> Vector3:
	return Vector3(side * (p.y - .088), p.w, p.x)


func _lower(spec: Dictionary, p: Vector4, side: float) -> Vector3:
	return Vector3(side * (p.y - .046), _arch(spec, p.x), p.x)


func _build_hull(batch: MeshBatch, spec: Dictionary, mats: Dictionary) -> void:
	var stations: Array[float] = []
	for p: Vector4 in spec.body:
		stations.append(p.x)
	for axle: float in [spec.axles.x, spec.axles.y]:
		for fraction: float in [-1.0, -.86, -.59, -.28, 0.0, .28, .59, .86, 1.0]:
			stations.append(axle + fraction * (spec.tyre + .082))
	stations.sort()
	for index in stations.size() - 1:
		var a := _profile(spec, stations[index])
		var b := _profile(spec, stations[index + 1])
		if spec.name != "CargoVan" or b.x > 1.08:
			batch.quad(mats.paint, _deck(a, -1), _deck(a, 1), _deck(b, 1), _deck(b, -1), Vector3.UP)
		for side: float in [-1.0, 1.0]:
			var outside := Vector3(side, 0, 0)
			var low_a := _lower(spec, a, side)
			var low_b := _lower(spec, b, side)
			var high_a := _shoulder(a, side)
			var high_b := _shoulder(b, side)
			var lip_a := low_a.lerp(high_a, .09)
			var lip_b := low_b.lerp(high_b, .09)
			batch.quad(mats.paint, lip_a, lip_b, high_b, high_a, outside)
			batch.quad(mats.trim if spec.name == "SUV" else mats.paint, low_a, low_b, lip_b, lip_a, outside)
			batch.quad(mats.paint, high_a, high_b, _deck(b, side), _deck(a, side), outside + Vector3.UP)
			batch.quad(mats.trim, low_a, low_b, low_b - outside * .17, low_a - outside * .17, Vector3.DOWN)
	for end: Vector4 in [spec.body.front(), spec.body.back()]:
		if spec.name == "CargoVan" and end.x < 0.0:
			continue
		var outside := Vector3(0, 0, signf(end.x))
		batch.quad(mats.paint, _lower(spec, end, -1), _lower(spec, end, 1), _shoulder(end, 1), _shoulder(end, -1), outside)
		batch.quad(mats.paint, _shoulder(end, -1), _shoulder(end, 1), _deck(end, 1), _deck(end, -1), outside)
	batch.box(mats.trim, Vector3(0, spec.sill + .014, 0), Vector3(spec.track * 1.38, .11, 3.68))


func _build_cabin(batch: MeshBatch, spec: Dictionary, mats: Dictionary) -> void:
	var shape: Vector4 = spec.cabin
	var rear := _profile(spec, shape.x)
	var front := _profile(spec, shape.y)
	var top := [
		Vector3(-spec.roof_width, spec.roof - .055, shape.z),
		Vector3(spec.roof_width, spec.roof - .055, shape.z),
		Vector3(spec.roof_width * .96, spec.roof - .055, shape.w),
		Vector3(-spec.roof_width * .96, spec.roof - .055, shape.w),
	]
	var foot := [_deck(rear, -1) - Vector3.UP * .013, _deck(rear, 1) - Vector3.UP * .013,
		_deck(front, 1) - Vector3.UP * .013, _deck(front, -1) - Vector3.UP * .013]
	var cap: Array[Vector3] = []
	for p: Vector3 in top:
		cap.append(Vector3(p.x * .924, spec.roof, p.z + .066 if p.z < 0.0 else p.z - .066))
	batch.quad(mats.paint, cap[0], cap[1], cap[2], cap[3], Vector3.UP)
	for edge in 4:
		var next := (edge + 1) % 4
		var outside: Vector3 = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT][edge]
		batch.quad(mats.paint, top[edge], top[next], cap[next], cap[edge], outside + Vector3.UP)
		if spec.name == "CargoVan" and edge == 0:
			continue
		var pane: Array[Vector3] = [foot[edge], foot[next], top[next], top[edge]]
		batch.quad(mats.paint, pane[0], pane[1], pane[2], pane[3], outside)
		if edge % 2 == 0:
			_window(batch, mats, pane, Rect2(.061, .112, .878, .793), outside)
		else:
			var ranges := [Vector2(.045, .468), Vector2(.514, .950)]
			if spec.name == "SUV":
				ranges = [Vector2(.04, .266), Vector2(.314, .598), Vector2(.640, .949)]
			elif spec.name == "FUV":
				ranges = [Vector2(.04, .224), Vector2(.268, .588), Vector2(.632, .949)]
			elif spec.name == "CargoVan":
				ranges = [Vector2(.54, .77), Vector2(.818, .954)]
			if edge == 3:
				ranges = ranges.map(func(span: Vector2): return Vector2(1.0 - span.y, 1.0 - span.x))
			for span: Vector2 in ranges:
				_window(batch, mats, pane, Rect2(span.x, .125, span.y - span.x, .77), outside)
			if spec.name == "CargoVan":
				var seam_x := .458 if edge == 1 else .525
				_pane_quad(batch, mats.steel, pane, Rect2(seam_x, .12, .008, .63), outside * .010, outside)
				var panel_x := .086 if edge == 1 else .598
				_pane_quad(batch, mats.steel, pane, Rect2(panel_x, .205, .315, .022), outside * .011, outside)

	if spec.name == "SUV":
		for side: float in [-1.0, 1.0]:
			var x: float = spec.roof_width * side * .79
			for z: float in [shape.z + .28, shape.w - .21]:
				batch.box(mats.trim, Vector3(x, spec.roof + .028, z), Vector3(.07, .055, .18))
			batch.box(mats.steel, Vector3(x, spec.roof + .065, (shape.z + shape.w) * .5),
				Vector3(.055, .045, shape.w - shape.z - .36))
	elif spec.name == "FUV":
		batch.box(mats.trim, Vector3(0, spec.roof + .004, -.45), Vector3(.82, .008, 1.26))
		batch.box(mats.glass, Vector3(0, spec.roof + .011, -.45), Vector3(.75, .008, 1.18))
	elif spec.name == "CargoVan":
		for x: float in [-.48, 0.0, .48]:
			batch.box(mats.paint, Vector3(x, spec.roof + .012, -.72), Vector3(.055, .023, 2.62))


func _pane_point(points: Array[Vector3], uv: Vector2, offset: Vector3) -> Vector3:
	return points[0].lerp(points[1], uv.x).lerp(points[3].lerp(points[2], uv.x), uv.y) + offset


func _window(batch: MeshBatch, mats: Dictionary, pane: Array[Vector3], uv: Rect2, outside: Vector3) -> void:
	var normal := (pane[1] - pane[0]).cross(pane[3] - pane[0]).normalized()
	if normal.dot(outside) < 0.0:
		normal = -normal
	_pane_quad(batch, mats.trim, pane, uv.grow(.009), normal * .010, outside)
	_pane_quad(batch, mats.glass, pane, uv, normal * .019, outside)


func _pane_quad(batch: MeshBatch, material: Material, pane: Array[Vector3], uv: Rect2, offset: Vector3, outside: Vector3) -> void:
	batch.quad(material, _pane_point(pane, uv.position, offset),
		_pane_point(pane, Vector2(uv.end.x, uv.position.y), offset),
		_pane_point(pane, uv.end, offset), _pane_point(pane, Vector2(uv.position.x, uv.end.y), offset), outside)


func _build_trim(batch: MeshBatch, spec: Dictionary, mats: Dictionary) -> void:
	var nose: Vector4 = spec.body.back()
	var tail: Vector4 = spec.body.front()
	for end: Vector4 in [nose, tail]:
		var facing := signf(end.x)
		batch.box(mats.trim, Vector3(0, spec.sill + .13, end.x + facing * .027),
			Vector3(end.y * 1.91, .19, .104))
		batch.box(mats.steel, Vector3(0, spec.sill + .205, end.x + facing * .081),
			Vector3(end.y * 1.62, .031, .012))
	var grill_y := nose.z - .151
	batch.box(mats.trim, Vector3(0, grill_y, nose.x + .019), Vector3(.68, .168, .049))
	for y: float in [-.046, .0, .046]:
		batch.box(mats.steel, Vector3(0, grill_y + y, nose.x + .047), Vector3(.58, .019, .013))
	for end: Vector4 in [nose, tail]:
		var facing := signf(end.x)
		batch.box(mats.white, Vector3(0, spec.sill + .103, end.x + facing * .085), Vector3(.269, .087, .017))
		for x: float in [-.07, .0, .07]:
			batch.box(mats.trim, Vector3(x, spec.sill + .102, end.x + facing * .095), Vector3(.038, .017, .008))

	for side: float in [-1.0, 1.0]:
		var lamp_x := side * (nose.y - .222)
		batch.box(mats.trim, Vector3(lamp_x, nose.z - .101, nose.x + .012), Vector3(.373, .148, .046))
		batch.box(mats.white, Vector3(lamp_x - side * .035, nose.z - .086, nose.x + .04), Vector3(.25, .096, .021))
		batch.box(mats.amber, Vector3(lamp_x + side * .129, nose.z - .086, nose.x + .04), Vector3(.061, .096, .021))
		var vertical: bool = spec.name in ["FUV", "CargoVan"]
		var lamp_size := Vector3(.115, .252, .051) if vertical else Vector3(.345, .105, .048)
		var lamp_y := tail.z - .042 if vertical else tail.z - .073
		var tail_light_x := side * (tail.y - (.054 if spec.name == "CargoVan" else .19))
		batch.box(mats.red, Vector3(tail_light_x, lamp_y, tail.x - .028), lamp_size)
		batch.box(mats.white, Vector3(tail_light_x, lamp_y - .041, tail.x - .054), Vector3(.085, .028, .013))

		var mirror_z: float = spec.cabin.y - .17
		var p := _profile(spec, mirror_z)
		batch.box(mats.trim, Vector3(side * (p.y - .037), p.w + .102, mirror_z), Vector3(.267, .044, .07))
		batch.box(mats.paint, Vector3(side * (p.y + .115), p.w + .132, mirror_z), Vector3(.172, .095, .143))
		batch.box(mats.glass, Vector3(side * (p.y + .122), p.w + .132, mirror_z - .075), Vector3(.127, .052, .014))

		for z: float in [-.86, .34]:
			var profile := _profile(spec, z)
			batch.box(mats.trim, Vector3(side * (profile.y + .005), profile.z - .083, z), Vector3(.025, .035, .17))
			batch.box(mats.steel, Vector3(side * (profile.y + .023), profile.z - .076, z), Vector3(.016, .019, .13))
		if spec.name == "FUV":
			batch.box(mats.trim, Vector3(side * .915, .77, -.81), Vector3(.018, .026, 1.25))
		elif spec.name == "SUV":
			batch.box(mats.trim, Vector3(side * .935, .36, -.028), Vector3(.12, .069, 1.67))
		elif spec.name == "CargoVan":
			batch.box(mats.trim, Vector3(side * .985, .47, -.44), Vector3(.048, .108, 2.60))


func _build_cargo_doors(car: Node3D, rear: Vector4, mats: Dictionary) -> void:
	var portal := MeshBatch.new()
	portal.box(mats.trim, Vector3(0, .56, rear.x + .46), Vector3(1.76, .10, .98))
	portal.box(mats.trim, Vector3(0, 1.31, rear.x + .96), Vector3(1.75, 1.54, .08))
	portal.box(mats.paint, Vector3(0, 2.005, rear.x + .008), Vector3(1.88, .125, .12))
	for side: float in [-1.0, 1.0]:
		portal.box(mats.paint, Vector3(side * .894, 1.32, rear.x + .005), Vector3(.105, 1.45, .12))
	_mesh_node(car, "CargoOpening", portal.bake())
	var doors := Node3D.new()
	doors.name = "RearDoors"
	_own(car, doors)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Left" if side < 0.0 else "Right"
		hinge.position = Vector3(side * .851, 0, rear.x - .025)
		_own(doors, hinge)
		var leaf := MeshBatch.new()
		var center := -side * .419
		leaf.box(mats.paint, Vector3(center, 1.30, 0), Vector3(.815, 1.42, .074))
		leaf.box(mats.trim, Vector3(center, 1.63, -.041), Vector3(.576, .455, .027))
		leaf.box(mats.glass, Vector3(center, 1.63, -.058), Vector3(.505, .383, .018))
		leaf.box(mats.trim, Vector3(-side * .742, 1.17, -.051), Vector3(.058, .155, .035))
		leaf.box(mats.steel, Vector3(center, .894, -.043), Vector3(.584, .021, .019))
		_mesh_node(hinge, "DoorLeaf", leaf.bake())


func _make_portal_compatible(car: Node3D, spec: Dictionary) -> void:
	# All van surfaces use the same per-instance clipping plane at the shutter.
	var finishes: Dictionary = {}
	for node: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var standard := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if standard == null:
				continue
			if not finishes.has(standard):
				var finish := _worn_finish(standard.resource_name, standard.albedo_color, standard.roughness,
					standard.metallic_specular, spec, 1)
				finish.set_shader_parameter("wear_amount", 0.0)
				finishes[standard] = finish
			node.mesh.surface_set_material(surface, finishes[standard])


func _build_wheel(spec: Dictionary, mats: Dictionary) -> ArrayMesh:
	var batch := MeshBatch.new()
	var tyre := _material("Tyre rubber", Color("1c2021"), .95, .10)
	var sidewall := _material("Tyre sidewall", Color("282d2d"), .88, .13)
	var tyre_dust := _material("Road dust on tyre tread", Color("333330"), .96, .10)
	var radius: float = spec.tyre
	var half: float = spec.tyre_width * .5
	var cross_section := [Vector2(-half, radius * .89), Vector2(-half * .69, radius),
		Vector2(half * .69, radius), Vector2(half, radius * .89)]
	for index in 14:
		var a := TAU * float(index) / 14.0
		var b := TAU * float(index + 1) / 14.0
		var outside := Vector3(0, cos((a + b) * .5), sin((a + b) * .5))
		for ring in cross_section.size() - 1:
			batch.quad(tyre_dust if index >= 4 and index <= 7 else tyre, _wheel_point(cross_section[ring], a), _wheel_point(cross_section[ring], b),
				_wheel_point(cross_section[ring + 1], b), _wheel_point(cross_section[ring + 1], a), outside)
		for side: float in [-1.0, 1.0]:
			var x := side * half
			var normal := Vector3(side, 0, 0)
			var inner := Vector2(x, radius * .57)
			var outer := Vector2(x, radius * .89)
			batch.quad(sidewall, _wheel_point(inner, a), _wheel_point(outer, a), _wheel_point(outer, b), _wheel_point(inner, b), normal)
			var rim := Vector2(x + side * .004, radius * .565)
			batch.triangle(mats.steel if index % 2 == 0 else mats.trim,
				Vector3(rim.x, 0, 0), _wheel_point(rim, a), _wheel_point(rim, b), normal)
			var hub := Vector2(x + side * .008, radius * .198)
			batch.triangle(mats.steel, Vector3(hub.x, 0, 0), _wheel_point(hub, a), _wheel_point(hub, b), normal)
	return batch.bake()


func _wheel_point(section: Vector2, angle: float) -> Vector3:
	return Vector3(section.x, cos(angle) * section.y, sin(angle) * section.y)
