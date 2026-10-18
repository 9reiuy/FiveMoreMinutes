extends Node

signal setting_changed(setting_name: StringName, value: Variant)
signal settings_loaded

const SETTINGS_PATH := "user://game_settings.cfg"
const LEGACY_SETTINGS_PATH := "user://game_settings.json"
const CONFIG := preload("res://resources/demo_config.tres")
const AUDIO_KEYS := [&"master_volume", &"music_volume", &"sfx_volume"]
const SHADOW_QUALITIES := ["low", "standard", "high"]
var defaults := {
	"master_volume": 100,
	"music_volume": 70,
	"sfx_volume": 80,
	"pixelation_enabled": true,
	"palette_enabled": true,
	"palette_scheme": 1,
	"shadow_quality": "standard"
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


func get_palette_enabled() -> bool:
	return bool(get_setting(&"palette_enabled", true))


func get_palette_scheme() -> int:
	return clampi(int(get_setting(&"palette_scheme", 1)), 1, 5)


func get_shadow_quality() -> String:
	return _normalize_shadow_quality(get_setting(&"shadow_quality", "standard"))


func _normalize_shadow_quality(value: Variant) -> String:
	return String(value) if value is String and value in SHADOW_QUALITIES else "standard"


func set_volume(setting_name: StringName, value: float) -> void:
	if not setting_name in AUDIO_KEYS:
		return
	_set_setting(setting_name, clampi(roundi(value), 0, 100))


func set_palette_enabled(enabled: bool) -> void:
	_set_setting(&"palette_enabled", bool(enabled))


func set_palette_scheme(scheme: int) -> void:
	_set_setting(&"palette_scheme", clampi(scheme, 1, 5))


## 通用设置写入（UI 正式入口）。只允许 defaults 里声明过的键，
## 持久化到 user://game_settings.cfg 并广播 setting_changed。
func set_setting(setting_name: StringName, value: Variant) -> void:
	if not defaults.has(String(setting_name)):
		push_warning("SettingsManager: unknown setting '%s'" % String(setting_name))
		return
	var normalized: Variant = _normalize_setting(setting_name, value)
	_set_setting(setting_name, normalized)


func _normalize_setting(setting_name: StringName, value: Variant) -> Variant:
	var normalized: Variant = value
	match setting_name:
		&"pixelation_enabled": normalized = bool(value)
		&"palette_enabled": normalized = bool(value)
		&"palette_scheme": normalized = clampi(int(value), 1, 5)
		&"shadow_quality": normalized = _normalize_shadow_quality(value)
	return normalized


func _set_setting(setting_name: StringName, value: Variant) -> void:
	var key := String(setting_name)
	if values.get(key) == value:
		return
	values[key] = value
	if setting_name in AUDIO_KEYS:
		_apply_audio_setting(setting_name)
	# All user-facing settings share one persistence path.  This is called only
	# after a user change (or a dedicated setter), never while loading values.
	_save_settings()
	setting_changed.emit(setting_name, value)


func _load_settings(path: String = SETTINGS_PATH) -> void:
	values = defaults.duplicate(true)
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key in AUDIO_KEYS:
			values[String(key)] = clampi(int(file.get_value("audio", String(key), defaults[String(key)])), 0, 100)
		# Pixel lighting was a different, retired effect. An old value must not
		# override the default of the new selective pixelation setting.
		values["pixelation_enabled"] = bool(
			file.get_value("graphics", "pixelation_enabled", bool(defaults["pixelation_enabled"]))
		)
		values["shadow_quality"] = _normalize_shadow_quality(
			file.get_value("graphics", "shadow_quality", "standard")
		)
		if file.has_section_key("graphics", "palette_enabled"):
			values["palette_enabled"] = bool(file.get_value("graphics", "palette_enabled", true))
		elif file.has_section_key("graphics", "palette_scheme"):
			# 旧配置迁移：无论旧值是方案 1 还是方案 2，均迁移为方案 1（true）
			values["palette_enabled"] = true
		else:
			values["palette_enabled"] = bool(defaults["palette_enabled"])
		values["palette_scheme"] = clampi(int(file.get_value("graphics", "palette_scheme", 1)), 1, 5)
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
		if legacy.has("palette_enabled"):
			values["palette_enabled"] = bool(legacy["palette_enabled"])
		elif legacy.has("palette_scheme"):
			values["palette_enabled"] = true


func _save_settings(path: String = SETTINGS_PATH) -> void:
	var file := ConfigFile.new()
	for key in AUDIO_KEYS:
		file.set_value("audio", String(key), get_volume(key))
	file.set_value("graphics", "pixelation_enabled", bool(get_setting(&"pixelation_enabled", true)))
	file.set_value("graphics", "palette_enabled", get_palette_enabled())
	file.set_value("graphics", "palette_scheme", get_palette_scheme())
	file.set_value("graphics", "shadow_quality", get_shadow_quality())
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
