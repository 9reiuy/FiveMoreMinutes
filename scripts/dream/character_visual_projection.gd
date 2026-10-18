extends RefCounted
## CPU counterpart of character_reference_depth.gdshaderinc. No gameplay writes.

static func intersect_reference_plane(camera: Camera3D, colour_world: Vector3,
		plane_origin: Vector3, plane_normal: Vector3) -> Vector3:
	var eye := camera.global_position
	var ray := colour_world - eye
	var divisor := plane_normal.dot(ray)
	if absf(divisor) < 0.00001:
		return colour_world
	var ratio := plane_normal.dot(plane_origin - eye) / divisor
	return eye + ray * ratio if ratio > 0.0 else colour_world

static func set_material_plane(material: ShaderMaterial, origin: Vector3, normal: Vector3) -> void:
	if material == null:
		return
	material.set_shader_parameter("reference_depth_enabled", true)
	material.set_shader_parameter("reference_plane_origin", origin)
	material.set_shader_parameter("reference_plane_normal", normal)
