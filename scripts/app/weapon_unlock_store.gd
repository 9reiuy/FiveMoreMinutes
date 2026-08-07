# ==========================================
# 文件名称: weapon_unlock_store.gd
# 功能:     武器解锁的跨存档持久化。玩家在任意存档中解锁的武器
#           会记录到全局（user://），新开存档时自动继承，不会被重新锁定。
# 修改说明: 解锁仍由原有系统触发（结局/迟到/旷工/天数），本类只负责
#           在保存时同步全局、在开新档时回填。
# ==========================================
class_name WeaponUnlockStore
extends RefCounted

const UNLOCK_FILE := "user://weapon_unlocks.cfg"
const WEAPON_IDS := ["shotgun", "beam", "katana", "grenade"]
const STATE_KEYS := {
	"shotgun": "shotgun_unlocked",
	"beam": "beam_weapon_unlocked",
	"katana": "katana_unlocked",
	"grenade": "grenade_weapon_unlocked",
}


## 读取全局已解锁的武器集合。
static func get_unlocked() -> Dictionary:
	var result: Dictionary = {}
	var config := ConfigFile.new()
	if config.load(UNLOCK_FILE) != OK:
		return result
	for weapon in WEAPON_IDS:
		result[weapon] = bool(config.get_value("weapons", weapon, false))
	return result


## 把存档 state 中已解锁的武器同步进全局（保存时调用）。
static func sync_from(state: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(UNLOCK_FILE)
	var changed := false
	for weapon in WEAPON_IDS:
		if bool(state.get(STATE_KEYS[weapon], false)):
			config.set_value("weapons", weapon, true)
			changed = true
	if changed or not config.has_section("weapons"):
		config.save(UNLOCK_FILE)


## 把全局已解锁的武器回填进存档 state（新开存档/读档时调用）。
static func apply_to(state: Dictionary) -> void:
	var unlocked := get_unlocked()
	for weapon in WEAPON_IDS:
		if bool(unlocked.get(weapon, false)):
			state[STATE_KEYS[weapon]] = true
