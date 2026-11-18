extends SceneTree

const SETTINGS := preload("res://scripts/app/settings_manager.gd")
const PANEL := preload("res://scenes/ui/settings_panel.tscn")
const TEST_PATH := "res://.runtime/pixelation_setting_test.cfg"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var settings: Node = SETTINGS.new()
	settings.values = settings.defaults.duplicate(true)
	_check(settings.get_setting(&"pixelation_enabled", true) == false, "The world must default to native resolution")
	_check(not settings.defaults.has("pixel_filter_enabled"), "Retired pixel lighting key must be absent")
	var legacy := ConfigFile.new()
	legacy.set_value("graphics", "pixel_filter_enabled", false)
	legacy.set_value("graphics", "palette_enabled", false)
	legacy.set_value("graphics", "pixelation_enabled", true)
	legacy.set_value("graphics", "native_resolution_default_applied", true)
	_check(legacy.save(TEST_PATH) == OK, "Could not create legacy settings fixture")
	settings._load_settings(TEST_PATH)
	_check(settings.get_setting(&"pixelation_enabled", true) == false, "Old graphics settings must use the native-resolution default")
	_check(not settings.values.has("palette_enabled"), "Other graphics settings must still load")
	settings.set_setting(&"pixelation_enabled",true)
	_check(not settings.get_setting(&"pixelation_enabled",true),"Retired setting cannot be enabled")
	settings._save_settings(TEST_PATH)
	var saved := ConfigFile.new()
	_check(saved.load(TEST_PATH) == OK, "Could not reload settings")
	_check(not saved.has_section_key("graphics", "pixelation_enabled"), "Retired setting must not be saved")
	_check(not saved.has_section_key("graphics", "pixel_filter_enabled"), "Retired key must not be saved")
	var panel := PANEL.instantiate()
	root.add_child(panel)
	await process_frame
	_check(not panel.has_node("Rows/Pixelation"),"Settings must not expose a pixelation control")
	_check(is_instance_valid(panel.shadow_quality_option),"Shadow quality control is retained")
	panel.queue_free()
	settings.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Pixelation settings: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
