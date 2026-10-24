extends RefCounted
## Shared angular clock for gameplay, held pose and the world-space pixel arc.
static func strike_progress(elapsed: float, windup: float, strike: float) -> float:
	var t := clampf((elapsed - windup) / maxf(strike, 0.001), 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.0)

static func angle_at(progress: float, arc: float) -> float:
	return lerpf(-arc * 0.5, arc * 0.5, clampf(progress, 0.0, 1.0))

static func contains_point(point: Vector2, origin: Vector2, direction: Vector2, reach: float, start_angle: float, end_angle: float) -> bool:
	var offset := point - origin
	if offset.length_squared() > reach * reach + 0.001:
		return false
	if offset.length_squared() < 0.001:
		return true
	var angle := direction.angle_to(offset)
	return angle >= minf(start_angle, end_angle) - 0.001 and angle <= maxf(start_angle, end_angle) + 0.001
