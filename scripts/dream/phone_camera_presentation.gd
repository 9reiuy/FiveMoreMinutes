extends RefCounted

## A phone-only modifier consumed by each world's existing camera authority.
## It neither owns a Camera nor advances gameplay, dialogue or the clock.
static func zoom_factor(weight: float) -> float:
	return lerpf(1.0, 1.0 / 1.4, clampf(weight, 0.0, 1.0))


static func focus_offset(camera: Camera3D, weight: float, fov: float, ortho_size: float = 0.0) -> Vector3:
	if not is_instance_valid(camera) or weight <= 0.0:
		return Vector3.ZERO
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var width := ortho_size * aspect
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		# The eye's local distance to the rig stays fixed; avoid feeding the
		# previous composition shift back into the next frame's displacement.
		width = 2.0 * camera.position.length() * tan(deg_to_rad(fov) * 0.5) * aspect
	var parent := camera.get_parent_node_3d().get_parent_node_3d()
	var right := camera.global_basis.x.normalized()
	if is_instance_valid(parent):
		right = parent.global_basis.inverse() * right
	return -right * width * 0.18 * clampf(weight, 0.0, 1.0)
