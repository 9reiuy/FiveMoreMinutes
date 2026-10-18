extends RefCounted

static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func make(width: float, depth: float, height: float) -> MeshInstance3D:
	var key := Vector2(width, depth)
	if not meshes.has(key):
		meshes[key] = _closed_cut_mesh(width, depth)
	if not materials.has(height):
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/dream3d/architecture_slice_cap.gdshader")
		material.set_shader_parameter("wall_height", height)
		materials[height] = material
	var cap := MeshInstance3D.new()
	cap.name = "ArchitecturalCutSurface"
	cap.mesh = meshes[key]
	cap.material_override = materials[height]
	cap.extra_cull_margin = height
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cap


static func _closed_cut_mesh(width: float, depth: float) -> ArrayMesh:
	# A plane alone leaves the freshly cut front/back of doors and window
	# frames hollow. A shallow skirt closes those exposed faces while the
	# shader keeps every vertex on the same flat cut height as the wall.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var count := maxi(ceili(width * 32.0), 1)
	var x0 := -width * .5
	var z0 := -depth * .5
	var z1 := depth * .5
	var skirt := .0625
	for index in count:
		var left := x0 + width * float(index) / float(count)
		var right := x0 + width * float(index + 1) / float(count)
		_add_quad(vertices, normals, Vector3(left, 0, z0), Vector3(right, 0, z0), Vector3(right, 0, z1), Vector3(left, 0, z1), Vector3.UP)
		_add_quad(vertices, normals, Vector3(left, -skirt, z1), Vector3(right, -skirt, z1), Vector3(right, 0, z1), Vector3(left, 0, z1), Vector3.BACK)
		_add_quad(vertices, normals, Vector3(right, -skirt, z0), Vector3(left, -skirt, z0), Vector3(left, 0, z0), Vector3(right, 0, z0), Vector3.FORWARD)
	_add_quad(vertices, normals, Vector3(x0, -skirt, z0), Vector3(x0, -skirt, z1), Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.LEFT)
	_add_quad(vertices, normals, Vector3(-x0, -skirt, z1), Vector3(-x0, -skirt, z0), Vector3(-x0, 0, z0), Vector3(-x0, 0, z1), Vector3.RIGHT)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_quad(vertices: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))
	for _index in 6:
		normals.append(normal)
