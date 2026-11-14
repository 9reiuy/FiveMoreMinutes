extends Node

signal setting_changed(setting_name: StringName, value: Variant)
signal settings_loaded

const SETTINGS_PATH := "user://game_settings.cfg"
const LEGACY_SETTINGS_PATH := "user://game_settings.json"
const CONFIG := preload("res://resources/demo_config.tres")
const AUDIO_KEYS := [&"master_volume", &"music_volume", &"sfx_volume"]
const ACCESSIBILITY_KEYS := ["auto_vault_enabled", "screen_shake_enabled", "canned_laughter_enabled"]
const SHADOW_QUALITIES := ["low", "standard", "high"]
var defaults := {
	"master_volume": 100,
	"music_volume": 70,
	"sfx_volume": 80,
	"pixelation_enabled": false,
	"shadow_quality": "standard",
	"auto_vault_enabled": true,
	"screen_shake_enabled": true,
	"canned_laughter_enabled": true
}

var values: Dictionary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus(&"Music", &"Master")
	_ensure_audio_bus(&"SFX", &"Master")
	values = defaults.duplicate(true)
	_load_settings()
	_apply_all_audio()
	settings_loaded.emit()


func get_setting(setting_name: StringName, fallback: Variant = null) -> Variant:
	return values.get(String(setting_name), fallback)


func get_volume(setting_name: StringName) -> int:
	return clampi(int(get_setting(setting_name, 100)), 0, 100)


func get_shadow_quality() -> String:
	return _normalize_shadow_quality(get_setting(&"shadow_quality", "standard"))


func _normalize_shadow_quality(value: Variant) -> String:
	return String(value) if value is String and value in SHADOW_QUALITIES else "standard"


func set_volume(setting_name: StringName, value: float) -> void:
	if not setting_name in AUDIO_KEYS:
		return
	_set_setting(setting_name, clampi(roundi(value), 0, 100))


## 通用设置写入（UI 正式入口）。只允许 defaults 里声明过的键，
## 持久化到 user://game_settings.cfg 并广播 setting_changed。
func set_setting(setting_name: StringName, value: Variant) -> void:
	if not defaults.has(String(setting_name)):
		push_warning("SettingsManager: unknown setting '%s'" % String(setting_name))
		return
	var normalized: Variant = _normalize_setting(setting_name, value)
	_set_setting(setting_name, normalized)


func _normalize_setting(setting_name: StringName, value: Variant) -> Variant:
	if String(setting_name) in ACCESSIBILITY_KEYS:
		return bool(value)
	var normalized: Variant = value
	match setting_name:
		&"pixelation_enabled": normalized = bool(value)
		&"shadow_quality": normalized = _normalize_shadow_quality(value)
	return normalized


func _set_setting(setting_name: StringName, value: Variant) -> void:
	var key := String(setting_name)
	if values.get(key) == value:
		return
	values[key] = value
	if setting_name in AUDIO_KEYS:
		_apply_audio_setting(setting_name)
	# User changes and explicit settings migrations share one persistence path.
	_save_settings()
	setting_changed.emit(setting_name, value)


func _load_settings(path: String = SETTINGS_PATH) -> void:
	values = defaults.duplicate(true)
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key in AUDIO_KEYS:
			values[String(key)] = clampi(int(file.get_value("audio", String(key), defaults[String(key)])), 0, 100)
		# Apply the requested native-resolution default to existing profiles once.
		# Later explicit changes in Settings remain the player's choice.
		var native_default_applied := bool(file.get_value("graphics", "native_resolution_default_applied", false))
		values["pixelation_enabled"] = bool(file.get_value("graphics", "pixelation_enabled", false)) if native_default_applied else false
		values["shadow_quality"] = _normalize_shadow_quality(
			file.get_value("graphics", "shadow_quality", "standard")
		)
		for key in ACCESSIBILITY_KEYS:
			values[key] = bool(file.get_value("accessibility", key, defaults[key]))
		if not native_default_applied:
			_save_settings(path)
		return
	_migrate_legacy_settings()
	_save_settings(path)


func _migrate_legacy_settings() -> void:
	if not FileAccess.file_exists(LEGACY_SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_SETTINGS_PATH))
	if not parsed is Dictionary:
		return
	var legacy: Variant = parsed.get("settings", {})
	# 已废弃的旧设置不再迁移；这里只迁移仍然有效的音量数据。
	if legacy is Dictionary:
		for key in AUDIO_KEYS:
			if legacy.has(String(key)):
				values[String(key)] = clampi(int(legacy[String(key)]), 0, 100)


func _save_settings(path: String = SETTINGS_PATH) -> void:
	var file := ConfigFile.new()
	for key in AUDIO_KEYS:
		file.set_value("audio", String(key), get_volume(key))
	file.set_value("graphics", "pixelation_enabled", bool(get_setting(&"pixelation_enabled", false)))
	file.set_value("graphics", "native_resolution_default_applied", true)
	file.set_value("graphics", "shadow_quality", get_shadow_quality())
	for key in ACCESSIBILITY_KEYS:
		file.set_value("accessibility", key, bool(get_setting(StringName(key), defaults[key])))
	file.save(path)


func _ensure_audio_bus(bus_name: StringName, send_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	if bus_name != &"Master":
		AudioServer.set_bus_send(bus_index, send_name)


func _apply_all_audio() -> void:
	_apply_bus_volume(&"Master", get_volume(&"master_volume"))
	_apply_bus_volume(&"Music", get_volume(&"music_volume"))
	_apply_bus_volume(&"SFX", get_volume(&"sfx_volume"))


func _apply_audio_setting(setting_name: StringName) -> void:
	match setting_name:
		&"master_volume": _apply_bus_volume(&"Master", get_volume(setting_name))
		&"music_volume": _apply_bus_volume(&"Music", get_volume(setting_name))
		&"sfx_volume": _apply_bus_volume(&"SFX", get_volume(setting_name))


func _apply_bus_volume(bus_name: StringName, percent: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized := clampf(float(percent) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.0001)))
