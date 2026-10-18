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
	_check(settings.get_setting(&"pixelation_enabled", false) == true, "Pixelation must default to on")
	_check(not settings.defaults.has("pixel_filter_enabled"), "Retired pixel lighting key must be absent")
	var legacy := ConfigFile.new()
	legacy.set_value("graphics", "pixel_filter_enabled", false)
	legacy.set_value("graphics", "palette_enabled", false)
	_check(legacy.save(TEST_PATH) == OK, "Could not create legacy settings fixture")
	settings._load_settings(TEST_PATH)
	_check(settings.get_setting(&"pixelation_enabled", false) == true, "Old lighting setting must not change pixelation default")
	_check(settings.get_setting(&"palette_enabled", true) == false, "Other graphics settings must still load")
	settings.values["pixelation_enabled"] = false
	settings._save_settings(TEST_PATH)
	var saved := ConfigFile.new()
	_check(saved.load(TEST_PATH) == OK, "Could not reload settings")
	_check(saved.get_value("graphics", "pixelation_enabled", true) == false, "Pixelation toggle must persist")
	_check(not saved.has_section_key("graphics", "pixel_filter_enabled"), "Retired key must not be saved")
	var panel := PANEL.instantiate()
	root.add_child(panel)
	await process_frame
	var checkbox := panel.get_node_or_null("Pixelation/ControlRow/Check") as CheckBox
	_check(checkbox != null, "Settings must expose pixelation checkbox")
	_check((panel.get_node("Pixelation/Label") as Label).text.begins_with("像素化"), "Pixelation label is missing")
	panel.queue_free()
	settings.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Pixelation settings: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
