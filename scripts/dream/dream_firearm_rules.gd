extends RefCounted

## Authoritative base firearm data. Actor upgrades, aim error and cadence jitter
## are applied by the caller after this shared lookup.
static func parameters(config: Resource, weapon_id: StringName) -> Dictionary:
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


static func _value(config: Resource, field: String, fallback: float) -> float:
	if config == null:
		return fallback
	var value: Variant = config.get(field)
	return fallback if value == null else float(value)


## Spread is the total cone angle. One random trajectory in each equal sector
## keeps shotgun coverage readable; one pellet gives ordinary aim scatter.
static func directions(direction: Vector2, pellet_count: int = 1, spread_degrees: float = 0.0, random_source: RandomNumberGenerator = null) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := maxi(1, pellet_count)
	var spread := maxf(0.0, spread_degrees)
	var sector_width := spread / float(count)
	var center := direction.normalized()
	for index in range(count):
		var minimum := -spread * 0.5 + sector_width * float(index)
		var maximum := minimum + sector_width
		var angle := 0.0
		if spread > 0.0:
			angle = random_source.randf_range(minimum, maximum) if random_source != null else randf_range(minimum, maximum)
		result.append(center.rotated(deg_to_rad(angle)))
	return result


static func setup_projectile(projectile: Node, direction: Vector2, damage: float, distance: float, speed: float, team: StringName, source: Node2D, weapon_id: StringName) -> void:
	projectile.setup(direction, damage, distance, speed, team, source, weapon_id)
