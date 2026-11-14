extends RefCounted

const BODY_RECOIL_DECAY := 14.0
const BODY_RECOIL_SETTLE_SPEED := 1.0


static func body_recoil_after_shot(
	config: Resource,
	weapon_id: StringName,
	direction: Vector2,
	current: Vector2,
	multiplier: float
) -> Vector2:
	var strength: float
	match weapon_id:
		&"shotgun":
			strength = _value(config, "player_shotgun_recoil", 155.0)
		&"assault_rifle", &"mp5":
			strength = _value(config, "player_assault_rifle_recoil", 55.0)
		_:
			return current
	if strength <= 0.0 or direction.is_zero_approx():
		return current
	strength *= maxf(multiplier, 0.5)
	# Limit rapid-fire stacking without truncating a stronger kick from the
	# previous weapon if the shooter switches during its recovery.
	var limit := maxf(strength * 2.0, current.length())
	return (current - direction.normalized() * strength).limit_length(limit)


static func decay_body_recoil(current: Vector2, delta: float) -> Vector2:
	var remaining := current * exp(-BODY_RECOIL_DECAY * delta)
	if remaining.length_squared() < BODY_RECOIL_SETTLE_SPEED * BODY_RECOIL_SETTLE_SPEED:
		return Vector2.ZERO
	return remaining


## Authoritative base firearm data. Actor upgrades, aim error and cadence jitter
## are applied by the caller after this shared lookup.
static func parameters(config: Resource, weapon_id: StringName) -> Dictionary:
	if weapon_id == &"mp5":
		# Derive AFTER the world's 3D tuning, retaining the real rifle bullet.
		var rifle := parameters(config, &"assault_rifle")
		rifle["interval"] *= 0.5
		rifle["range"] *= 0.5
		return rifle
	var fields: Array[String] = []
	var defaults: Array[float] = []
	match weapon_id:
		&"basic":
			fields = ["basic_weapon_damage", "basic_weapon_range", "basic_projectile_speed", "basic_weapon_attack_interval"]
			defaults = [10.0, 270.0, 155.0, 0.3]
		&"assault_rifle":
			fields = ["assault_rifle_damage", "assault_rifle_range", "assault_rifle_projectile_speed", "assault_rifle_attack_interval"]
			defaults = [3.0, 270.0, 180.0, 0.15]
		&"shotgun":
			fields = ["shotgun_pellet_damage", "shotgun_max_distance", "shotgun_projectile_speed", "shotgun_attack_interval"]
			defaults = [3.0, 270.0, 155.0, 0.8]
		_:
			push_error("Unknown firearm: " + String(weapon_id))
			return {}
	return {
		"damage": _value(config, fields[0], defaults[0]),
		"range": _value(config, fields[1], defaults[1]),
		"speed": _value(config, fields[2], defaults[2]),
		"interval": _value(config, fields[3], defaults[3]),
		"pellets": maxi(1, int(_value(config, "shotgun_pellet_count", 9.0))) if weapon_id == &"shotgun" else 1,
		"spread_degrees": maxf(0.0, _value(config, "shotgun_spread_degrees", 30.0)) if weapon_id == &"shotgun" else 0.0,
	}


static func range_multiplier(weapon_id: StringName) -> float:
	return 0.5 if weapon_id == &"mp5" else 1.0


static func spread_multiplier(weapon_id: StringName) -> float:
	return 2.0 if weapon_id == &"mp5" else 1.0


static func _value(config: Resource, field: String, fallback: float) -> float:
	if config == null:
		return fallback
	var value: Variant = config.get(field)
	return fallback if value == null else float(value)


## Spread is the total cone angle. Pellets sample the entire cone independently,
## allowing clusters and gaps instead of guaranteeing one pellet in each lane.
## A single pellet retains the same ordinary aim-scatter sampling as before.
static func directions(direction: Vector2, pellet_count: int = 1, spread_degrees: float = 0.0, random_source: RandomNumberGenerator = null) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := maxi(1, pellet_count)
	var spread := maxf(0.0, spread_degrees)
	var center := direction.normalized()
	for _index in range(count):
		var angle := 0.0
		if spread > 0.0:
			angle = random_source.randf_range(-spread * .5, spread * .5) if random_source != null else randf_range(-spread * .5, spread * .5)
		result.append(center.rotated(deg_to_rad(angle)))
	return result


static func setup_projectile(projectile: Node, direction: Vector2, damage: float, distance: float, speed: float, team: StringName, source: Node2D, weapon_id: StringName) -> void:
	projectile.setup(direction, damage, distance, speed, team, source, weapon_id)
