class_name DreamWeaponPose
extends RefCounted

## Shared 2D weapon pose. Gameplay actors remain Node2D authorities; this
## helper only returns the same ellipse offset and local muzzle for visual and
## hit/query callers to consume.
static func solve(
	aim_direction: Vector2,
	side_radius: float = 14.0,
	forward_radius: float = 9.0,
	muzzle_distance: float = 11.0
) -> Dictionary:
	var direction := aim_direction.normalized() if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	return {
		"aim_direction": direction,
		"orbit_offset": Vector2(direction.x * side_radius, direction.y * forward_radius),
		"muzzle_local": Vector2(muzzle_distance, 0.0),
		"melee_local": Vector2(muzzle_distance, 0.0),
		"facing": -1.0 if direction.x < 0.0 else 1.0,
	}

