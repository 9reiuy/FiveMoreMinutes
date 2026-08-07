class_name UpgradeCatalog
extends RefCounted

const RARITY_BLUE := "blue"
const RARITY_PURPLE := "purple"
const RARITY_GOLD := "gold"


static func generate_options(config: DemoConfig, owned: Dictionary, random: RandomNumberGenerator, count: int = 3) -> Array[Dictionary]:
	var catalog := _build_catalog(config)
	var result: Array[Dictionary] = []
	var used_families: Dictionary = {}
	for _slot in count:
		var chosen: Dictionary = {}
		var last_rarity := RARITY_BLUE
		for _attempt in maxi(1, config.rarity_reroll_attempts):
			last_rarity = _roll_rarity(config, random)
			var candidates := _valid_candidates(catalog, owned, used_families, last_rarity)
			if not candidates.is_empty():
				chosen = candidates[random.randi_range(0, candidates.size() - 1)]
				break
		if chosen.is_empty():
			# Gold falls back through purple to blue; purple falls back to blue.
			var fallback := [RARITY_PURPLE, RARITY_BLUE] if last_rarity == RARITY_GOLD else [RARITY_BLUE]
			for rarity in fallback:
				var candidates := _valid_candidates(catalog, owned, used_families, rarity)
				if not candidates.is_empty():
					chosen = candidates[random.randi_range(0, candidates.size() - 1)]
					break
		if chosen.is_empty():
			break
		result.append(chosen.duplicate(true))
		used_families[chosen.family] = true
	return result


static func get_owned_cards(config: DemoConfig, owned: Dictionary) -> Array[Dictionary]:
	var catalog := _build_catalog(config)
	var result: Array[Dictionary] = []
	for family in owned:
		var level := int(owned[family])
		if level <= 0:
			continue
		var selected: Dictionary = {}
		for option in catalog:
			if option.family != family:
				continue
			if int(option.get("replace_rank", 0)) == level or int(option.get("replace_rank", 0)) == 0:
				selected = option
				if int(option.get("replace_rank", 0)) == level:
					break
		if selected.is_empty():
			continue
		var effect := str(selected.description)
		if family == "damage_boost": effect = "累计伤害倍率：×%.2f" % pow(config.damage_upgrade_multiplier, level)
		elif family == "attack_speed_boost": effect = "累计攻击速度：×%.2f" % pow(config.normal_attack_speed_upgrade_multiplier, level)
		elif family == "range_boost": effect = "攻击范围：+%dpx" % int(config.normal_range_upgrade_pixels * level)
		elif family == "hypnic_jerk": effect = "最大冲刺充能：%d" % (1 + level)
		elif family == "consciousness_drift": effect = "额外攻击概率：%d%%" % int(minf(1.0, level * config.consciousness_drift_chance_per_level) * 100.0)
		result.append({
			"family": family, "name": selected.name, "rarity": selected.rarity,
			"rarity_name": _rarity_name(selected.rarity), "level": level, "effect": effect
		})
	return result


static func _rarity_name(rarity: String) -> String:
	if rarity == RARITY_GOLD: return "金色"
	if rarity == RARITY_PURPLE: return "紫色"
	return "蓝色"


static func _valid_candidates(catalog: Array[Dictionary], owned: Dictionary, used: Dictionary, rarity: String) -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	for option in catalog:
		if option.rarity != rarity or used.has(option.family):
			continue
		var current := int(owned.get(option.family, 0))
		if option.get("replace_rank", 0) > 0:
			if int(option.replace_rank) <= current:
				continue
		elif current >= int(option.max_level):
			continue
		valid.append(option)
	return valid


static func _roll_rarity(config: DemoConfig, random: RandomNumberGenerator) -> String:
	var total := maxf(config.rarity_blue_probability + config.rarity_purple_probability + config.rarity_gold_probability, 0.0001)
	var roll := random.randf() * total
	if roll < config.rarity_blue_probability:
		return RARITY_BLUE
	if roll < config.rarity_blue_probability + config.rarity_purple_probability:
		return RARITY_PURPLE
	return RARITY_GOLD


static func _build_catalog(config: DemoConfig) -> Array[Dictionary]:
	return [
		_entry("damage_boost", "damage_boost", RARITY_BLUE, "锋利的念头", "攻击伤害提高%d%%" % int((config.damage_upgrade_multiplier - 1.0) * 100.0), config.normal_upgrade_max_level),
		_entry("attack_speed_boost", "attack_speed_boost", RARITY_BLUE, "加速的念头", "攻击循环速度提高%d%%" % int((config.normal_attack_speed_upgrade_multiplier - 1.0) * 100.0), config.normal_upgrade_max_level),
		_entry("range_boost", "range_boost", RARITY_BLUE, "延伸的念头", "攻击范围增加%dpx" % int(config.normal_range_upgrade_pixels), config.normal_upgrade_max_level),
		_variant("sleep_paralysis_blue", "sleep_paralysis", RARITY_BLUE, "睡眠瘫痪", "静止%.0f秒后每秒恢复%.0f生命" % [config.sleep_paralysis_blue_still_seconds, config.sleep_paralysis_blue_heal_per_second], 1),
		_variant("sleep_paralysis_purple", "sleep_paralysis", RARITY_PURPLE, "睡眠瘫痪", "静止%.0f秒后每秒恢复%.0f生命" % [config.sleep_paralysis_purple_still_seconds, config.sleep_paralysis_purple_heal_per_second], 2),
		_variant("sleep_paralysis_gold", "sleep_paralysis", RARITY_GOLD, "睡眠瘫痪", "静止%.0f秒后每秒恢复%.0f生命" % [config.sleep_paralysis_gold_still_seconds, config.sleep_paralysis_gold_heal_per_second], 3),
		_variant("sleep_spindle_blue", "sleep_spindle", RARITY_BLUE, "睡眠纺锤", "每%.0f秒获得一层一次性护盾" % config.sleep_spindle_blue_interval, 1),
		_variant("sleep_spindle_purple", "sleep_spindle", RARITY_PURPLE, "睡眠纺锤", "每%.0f秒获得一层一次性护盾" % config.sleep_spindle_purple_interval, 2),
		_variant("sleep_spindle_gold", "sleep_spindle", RARITY_GOLD, "睡眠纺锤", "每%.0f秒获得一层一次性护盾" % config.sleep_spindle_gold_interval, 3),
		_entry("hypnic_jerk", "hypnic_jerk", RARITY_PURPLE, "入睡抽动", "最大冲刺充能增加1", config.hypnic_jerk_max_bonus_charges),
		_entry("consciousness_drift", "consciousness_drift", RARITY_PURPLE, "意识漂移", "额外攻击概率提高%d%%" % int(config.consciousness_drift_chance_per_level * 100.0), config.consciousness_drift_max_level),
		_entry("rapid_eye", "rapid_eye", RARITY_PURPLE, "快速眼动", "受伤后使怪物移动降至%d%%，持续%.0f秒" % [int(config.rapid_eye_slow_multiplier * 100.0), config.rapid_eye_duration_seconds], config.rapid_eye_max_acquisitions),
		_entry("dissociation", "dissociation", RARITY_GOLD, "意识解离", "首次致命伤害时恢复%.0f生命并获得%.0f秒无敌" % [config.dissociation_revive_health, config.dissociation_invulnerability_seconds], config.dissociation_max_acquisitions)
	]


static func _entry(id: String, family: String, rarity: String, name: String, description: String, max_level: int) -> Dictionary:
	return {"id": id, "family": family, "rarity": rarity, "name": name, "description": description, "max_level": max_level}


static func _variant(id: String, family: String, rarity: String, name: String, description: String, rank: int) -> Dictionary:
	return {"id": id, "family": family, "rarity": rarity, "name": name, "description": description, "max_level": 1, "replace_rank": rank}
