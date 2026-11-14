extends RefCounted


static func step(
	pos: Vector2, vel: Vector2, rot: float, rot_vel: float, dt: float,
	max_distance: float, stiffness: float, damping: float,
	rot_stiffness: float, rot_damping: float, landed: bool
) -> Array:
	if landed:
		# Keep the joint attached, while retaining its landing angle.
		max_distance = minf(max_distance, 4.0)
		rot_stiffness = 0.0
		rot_damping = 4.0
	var acc := -stiffness * pos - damping * vel
	vel += acc * dt
	pos += vel * dt
	if max_distance > 0.0 and pos.length() > max_distance:
		pos = pos.limit_length(max_distance)
		if pos.dot(vel) > 0.0:
			vel -= pos.normalized() * pos.normalized().dot(vel)
	var rot_acc := -rot_stiffness * rot - rot_damping * rot_vel
	rot_vel += rot_acc * dt
	rot += rot_vel * dt
	return [pos, vel, clampf(rot, -2.35, 2.35), rot_vel]
