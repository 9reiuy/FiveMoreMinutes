class_name PermanentUpgradeCatalog
extends RefCounted

const IDS: Array[String] = ["visual_cortex", "hippocampus", "prefrontal"]
const NAMES := {
	"visual_cortex": "枕叶视觉皮层",
	"hippocampus": "海马体",
	"prefrontal": "前额叶皮层",
}
const DESCRIPTIONS := {
	"visual_cortex": "扩大所有武器的有效攻击范围。",
	"hippocampus": "提高进入梦境时的最大生命值。",
	"prefrontal": "缩短所有武器的攻击间隔。",
}
const ICONS := {
	"visual_cortex": preload("res://assets/ui/products/visual_cortex_icon.png"),
	"hippocampus": preload("res://assets/ui/products/hippocampus_icon.png"),
	"prefrontal": preload("res://assets/ui/products/prefrontal_icon.png"),
}


static func ensure_state(meta: Dictionary) -> Dictionary:
	# 保留旧存档字段名 permanent_upgrades，避免眠网迁移后清空既有等级。
	var levels: Dictionary = meta.get("permanent_upgrades", {})
	for id in IDS:
		levels[id] = maxi(0, int(levels.get(id, 0)))
	meta.permanent_upgrades = levels
	meta.ram = maxi(0, int(meta.get("ram", 0)))
	return levels


static func get_level(meta: Dictionary, id: String) -> int:
	return int(ensure_state(meta).get(id, 0))


static func get_display_name(id: String) -> String:
	return str(NAMES.get(id, id))


static func get_description(id: String) -> String:
	return str(DESCRIPTIONS.get(id, ""))


static func get_icon(id: String) -> Texture2D:
	return ICONS.get(id) as Texture2D


static func get_price(level: int, config: DemoConfig) -> int:
	if level < 0 or level >= config.permanent_upgrade_max_level or level >= config.permanent_upgrade_prices.size():
		return 0
	return maxi(0, int(config.permanent_upgrade_prices[level]))


static func get_effect_value(id: String, level: int, config: DemoConfig) -> String:
	match id:
		"visual_cortex": return "范围 +%dpx" % int(level * config.visual_cortex_range_per_level)
		"hippocampus": return "生命 +%d" % int(level * config.hippocampus_health_per_level)
		"prefrontal": return "攻速 ×%.1f" % (1.0 + level * config.prefrontal_attack_speed_per_level)
	return "--"


## 返回 purchased / insufficient / capped / invalid，购买成功时直接更新旧存档兼容字段。
static func purchase(meta: Dictionary, id: String, config: DemoConfig) -> StringName:
	if not id in IDS:
		return &"invalid"
	var levels := ensure_state(meta)
	var level := int(levels.get(id, 0))
	if level >= config.permanent_upgrade_max_level:
		return &"capped"
	var price := get_price(level, config)
	var ram := int(meta.get("ram", 0))
	if ram < price:
		return &"insufficient"
	meta.ram = ram - price
	levels[id] = level + 1
	meta.permanent_upgrades = levels
	return &"purchased"
