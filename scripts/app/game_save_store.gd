class_name GameSaveStore
extends RefCounted

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
const REQUIRED_KEYS := ["balance", "ram", "melatonin_inventory", "weekday_index", "permanent_upgrades"]


static func has_valid_save() -> bool:
	return not load_game().is_empty()


static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary or int(parsed.get("version", -1)) != SAVE_VERSION:
		return {}
	var state: Variant = parsed.get("state", {})
	if not state is Dictionary:
		return {}
	for key in REQUIRED_KEYS:
		if not state.has(key):
			return {}
	if not state.permanent_upgrades is Dictionary:
		return {}
	return state.duplicate(true)


static func save_game(state: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "state": state}, "  "))
	file.close()
	return true

