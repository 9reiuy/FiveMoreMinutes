extends RefCounted
## Full-height galvanized shelving and stock, batched by finish.

const FINISH := preload("res://shaders/dream3d/storage_stock.gdshader")
const DEPTH := .88
const HEIGHT := 2.32
const LEVELS := [.23, .81, 1.39, 1.97]


static func finishes() -> Dictionary:
	return {
		"zinc": _finish(Color("8d9a94"), .64, .35, .57),
		"deck": _finish(Color("57675f"), .77, .24, .53),
		"recess": _finish(Color("2d3733"), .89, .10, .22),
		"kraft": _finish(Color("987a55"), .93, .10, .38),
		"faded": _finish(Color("ac9973"), .94, .10, .44),
		"paper": _finish(Color("c5c8b6"), .87, .17, .38),
		"tape": _finish(Color("97876b"), .75, .17, .23),
	}


static func build(parent: Node3D, length: float, variant: int, materials: Dictionary) -> void:
	var parts := {}
	for name: String in materials:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(materials[name])
		parts[name] = surface

	var span := length - .078
	var bay_width := span * .5
	var front := DEPTH * .5
	for x: float in [-span * .5 + .053, 0.0, span * .5 - .053]:
		for z: float in [-front + .052, front - .052]:
			_box(parts.zinc, Vector3(.085, HEIGHT, .077), Vector3(x, HEIGHT * .5, z))
			_box(parts.deck, Vector3(.14, .046, .141), Vector3(x, .023, z))
		for slot in 11:
			_box(parts.recess, Vector3(.025, .041, .008), Vector3(x, .31 + slot * .174, front - .012))
	for bay in 2:
		var center_x := (bay - .5) * bay_width
		for direction: float in [-1.0, 1.0]:
			var brace := Vector2(bay_width - .14, direction * 1.93)
			_box(parts.zinc, Vector3(brace.length(), .058, .037), Vector3(center_x, 1.16, -front + .021),
				Basis(Vector3.BACK, brace.angle()))
		for tier in LEVELS.size():
			var y: float = LEVELS[tier]
			_box(parts.deck, Vector3(bay_width - .047, .060, DEPTH - .065), Vector3(center_x, y, 0))
			for z: float in [-front + .032, front - .032]:
				_box(parts.zinc, Vector3(bay_width - .043, .077, .046), Vector3(center_x, y - .011, z))
			_box(parts.paper, Vector3(.134, .044, .008), Vector3(center_x - bay_width * .35, y - .004, front - .006))
			for slot in 3:
				var pattern := (variant * 7 + bay * 4 + tier * 5 + slot * 3) % 11
				var x := center_x + (slot - 1) * bay_width * .31
				var foot := Vector3(x, y + .030, -.042 + .038 * (pattern % 3))
				if pattern in [0, 4, 10]:
					continue
				if pattern in [2, 7, 9]:
					_roll(parts, foot, .150 + .026 * (pattern % 3), .54 + .048 * (pattern % 4))
				else:
					var carton := Vector3(.46 + .047 * (pattern % 3), .24 + .051 * (pattern % 4), .53 + .042 * (pattern % 3))
					_carton(parts, foot, carton, pattern in [1, 8])

	var mesh := ArrayMesh.new()
	for surface: SurfaceTool in parts.values():
		surface.commit(mesh)
	var visual := MeshInstance3D.new()
	visual.name = "StorageCabinetRun"
	visual.mesh = mesh
	parent.add_child(visual)


static func _finish(colour: Color, roughness: float, specular: float, wear: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FINISH
	material.set_shader_parameter("finish_colour", colour)
	material.set_shader_parameter("finish_roughness", roughness)
	material.set_shader_parameter("finish_specular", specular)
	material.set_shader_parameter("surface_wear", wear)
	return material


static func _box(surface: SurfaceTool, size: Vector3, at: Vector3, basis := Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	surface.append_from(mesh, 0, Transform3D(basis, at))


static func _carton(parts: Dictionary, foot: Vector3, size: Vector3, faded: bool) -> void:
	_box(parts.faded if faded else parts.kraft, size, foot + Vector3.UP * size.y * .5)
	_box(parts.tape, Vector3(.089, .007, size.z * .97), foot + Vector3.UP * (size.y + .004))
	_box(parts.paper, Vector3(.172, .077, .008), foot + Vector3(size.x * .22, size.y * .64, size.z * .5 + .003))


static func _roll(parts: Dictionary, foot: Vector3, radius: float, length: float) -> void:
	var axis := Basis(Vector3.RIGHT, PI * .5)
	var roll := CylinderMesh.new()
	roll.radial_segments = 10
	roll.rings = 1
	roll.top_radius = radius
	roll.bottom_radius = radius
	roll.height = length
	var center := foot + Vector3.UP * radius
	parts.paper.append_from(roll, 0, Transform3D(axis, center))
	var core := CylinderMesh.new()
	core.radial_segments = 10
	core.rings = 1
	core.top_radius = radius * .37
	core.bottom_radius = core.top_radius
	core.height = .011
	for end: float in [-1.0, 1.0]:
		parts.recess.append_from(core, 0, Transform3D(axis, center + Vector3.BACK * end * length * .5))
