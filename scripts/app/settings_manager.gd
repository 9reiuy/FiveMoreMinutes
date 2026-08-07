extends Node

signal setting_changed(setting_name: StringName, value: Variant)
signal settings_loaded

const SETTINGS_PATH := "user://game_settings.cfg"
const LEGACY_SETTINGS_PATH := "user://game_settings.json"
const CONFIG := preload("res://resources/demo_config.tres")
const AUDIO_KEYS := [&"master_volume", &"music_volume", &"sfx_volume"]
var defaults := {
	"master_volume": 100,
	"music_volume": 70,
	"sfx_volume": 80,
	"sleepwalk_mode": false,
	"fast_sleep_enabled": CONFIG.fast_sleep_default_enabled
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


func get_sleepwalk_mode() -> bool:
	return bool(get_setting(&"sleepwalk_mode", false))


func get_fast_sleep_enabled() -> bool:
	return bool(get_setting(&"fast_sleep_enabled", true))


func set_volume(setting_name: StringName, value: float) -> void:
	if not setting_name in AUDIO_KEYS:
		return
	_set_setting(setting_name, clampi(roundi(value), 0, 100))


func set_sleepwalk_mode(enabled: bool) -> void:
	_set_setting(&"sleepwalk_mode", enabled)


func set_fast_sleep_enabled(enabled: bool) -> void:
	_set_setting(&"fast_sleep_enabled", enabled)


func _set_setting(setting_name: StringName, value: Variant) -> void:
	var key := String(setting_name)
	if values.get(key) == value:
		return
	values[key] = value
	if setting_name in AUDIO_KEYS:
		_apply_audio_setting(setting_name)
	_save_settings()
	setting_changed.emit(setting_name, value)


func _load_settings() -> void:
	values = defaults.duplicate(true)
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		for key in AUDIO_KEYS:
			values[String(key)] = clampi(int(file.get_value("audio", String(key), defaults[String(key)])), 0, 100)
		values.sleepwalk_mode = bool(file.get_value("gameplay", "sleepwalk_mode", defaults.sleepwalk_mode))
		values.fast_sleep_enabled = bool(file.get_value("gameplay", "fast_sleep_enabled", defaults.fast_sleep_enabled))
		return
	_migrate_legacy_settings()
	_save_settings()


func _migrate_legacy_settings() -> void:
	if not FileAccess.file_exists(LEGACY_SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_SETTINGS_PATH))
	if not parsed is Dictionary:
		return
	var legacy: Variant = parsed.get("settings", {})
	if legacy is Dictionary:
		values.sleepwalk_mode = bool(legacy.get("sleepwalk_mode", defaults.sleepwalk_mode))
		values.fast_sleep_enabled = bool(legacy.get("fast_sleep_enabled", defaults.fast_sleep_enabled))


func _save_settings() -> void:
	var file := ConfigFile.new()
	for key in AUDIO_KEYS:
		file.set_value("audio", String(key), get_volume(key))
	file.set_value("gameplay", "sleepwalk_mode", get_sleepwalk_mode())
	file.set_value("gameplay", "fast_sleep_enabled", get_fast_sleep_enabled())
	file.save(SETTINGS_PATH)


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
