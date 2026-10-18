extends RefCounted
## Legacy XP curve retained for manual/old-save compatibility only.
## Official 2D/3D Dream runs no longer instantiate or call this resource.
static func requirement(config: DemoConfig, level: int) -> int:
	var cap := maxi(1, config.experience_requirement_cap)
	if level <= 1:
		return clampi(config.first_level_experience_requirement, 1, cap)
	var growth := maxi(2, config.experience_growth_base)
	var required := 1
	for _power in level:
		if required > cap / growth:
			return cap
		required *= growth
	return mini(required, cap)

static func grant(profile: Dictionary, config: DemoConfig, raw: int, upgrades: Dictionary,
		level: int, experience: int, carry: float) -> Dictionary:
	# This resource remains available for manual/legacy callers only.  The
	# formal Dream runtime no longer grants XP or applies a Brainstem multiplier.
	var scaled: float = float(raw) + carry
	var amount := int(floor(scaled))
	experience += amount
	profile["experience_total"] = maxi(1, int(profile.get("experience_total", 1)) + raw)
	var levels := 0
	while experience >= requirement(config, level):
		experience -= requirement(config, level)
		level += 1
		levels += 1
		profile["unspent_stat_points"] = int(profile.get("unspent_stat_points", 0)) + 1
	return {"level": level, "experience": experience, "carry": scaled - amount, "levels": levels, "amount": amount}

static func apply_skill(player: Node, config: DemoConfig, skill_levels: Dictionary, option: Dictionary) -> void:
	var family := str(option.family)
	if int(option.get("replace_rank", 0)) > 0:
		skill_levels[family] = int(option.replace_rank)
	else:
		skill_levels[family] = int(skill_levels.get(family, 0)) + 1
	match str(option.id):
		"damage_boost": player.apply_damage_upgrade(config.damage_upgrade_multiplier)
		"attack_speed_boost": player.apply_attack_speed_upgrade(config.normal_attack_speed_upgrade_multiplier)
		"range_boost": player.apply_range_upgrade(config.normal_range_upgrade_pixels)
		"sleep_paralysis_blue": player.configure_sleep_paralysis(config.sleep_paralysis_blue_still_seconds, config.sleep_paralysis_blue_heal_per_second)
		"sleep_paralysis_purple": player.configure_sleep_paralysis(config.sleep_paralysis_purple_still_seconds, config.sleep_paralysis_purple_heal_per_second)
		"sleep_paralysis_gold": player.configure_sleep_paralysis(config.sleep_paralysis_gold_still_seconds, config.sleep_paralysis_gold_heal_per_second)
		"sleep_spindle_blue": player.configure_sleep_spindle(config.sleep_spindle_blue_interval, config.sleep_spindle_max_layers)
		"sleep_spindle_purple": player.configure_sleep_spindle(config.sleep_spindle_purple_interval, config.sleep_spindle_max_layers)
		"sleep_spindle_gold": player.configure_sleep_spindle(config.sleep_spindle_gold_interval, config.sleep_spindle_max_layers)
		"hypnic_jerk": player.add_dash_charge_capacity(config)
		"consciousness_drift": player.configure_consciousness_drift(int(skill_levels[family]), config)
		"dissociation": player.enable_dissociation(config)
