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
	_check(legacy.save(TEST_PATH) == OK, "Could not create legacy settings fixture")
	settings._load_settings(TEST_PATH)
	_check(settings.get_setting(&"pixelation_enabled", true) == false, "Old graphics settings must use the native-resolution default")
	_check(not settings.values.has("palette_enabled"), "Other graphics settings must still load")
	settings.values["pixelation_enabled"] = false
	settings._save_settings(TEST_PATH)
	var saved := ConfigFile.new()
	_check(saved.load(TEST_PATH) == OK, "Could not reload settings")
	_check(saved.get_value("graphics", "pixelation_enabled", true) == false, "Pixelation toggle must persist")
	_check(not saved.has_section_key("graphics", "pixel_filter_enabled"), "Retired key must not be saved")
	var panel := PANEL.instantiate()
	root.add_child(panel)
	await process_frame
	# The settings presentation reparents these controls during _ready().
	var checkbox: CheckBox = panel.pixelation_check
	var caption: Button = panel.pixelation_desc
	_check(is_instance_valid(checkbox), "Settings must expose pixelation checkbox")
	_check(is_instance_valid(caption) and caption.text.begins_with("像素化"), "Pixelation label is missing")
	_check(is_instance_valid(checkbox) and not checkbox.button_pressed, "The settings UI starts with pixelation off")
	panel.queue_free()
	settings.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Pixelation settings: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
