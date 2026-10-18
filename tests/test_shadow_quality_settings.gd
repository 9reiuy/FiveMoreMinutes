extends SceneTree

const TEST_PATH := "res://.runtime/shadow_quality_test.cfg"
const PANEL := preload("res://scenes/ui/settings_panel.tscn")
const THEME := preload("res://assets/fonts/pixel_theme.tres")

class TestSettings extends "res://scripts/app/settings_manager.gd":
	func _save_settings(_path: String = SETTINGS_PATH) -> void:
		super._save_settings("res://.runtime/shadow_quality_test.cfg")

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var settings := TestSettings.new()
	settings.values = settings.defaults.duplicate(true)
	_check(settings.get_shadow_quality() == "standard", "Default shadow quality must be standard")
	var notifications: Array = []
	settings.setting_changed.connect(func(key: StringName, value: Variant): notifications.append([key, value]))
	for quality in ["low", "high", "standard"]:
		settings.set_setting(&"shadow_quality", quality)
		_check(settings.get_shadow_quality() == quality, "Quality setter failed: " + quality)
		var saved := ConfigFile.new()
		_check(saved.load(TEST_PATH) == OK, "Quality settings persistence failed")
		_check(saved.get_value("graphics", "shadow_quality") == quality, "Quality did not persist: " + quality)
	_check(notifications.size() == 3, "Each actual quality change must emit setting_changed")
	settings.set_setting(&"shadow_quality", "invalid")
	_check(settings.get_shadow_quality() == "standard", "Invalid quality must fall back safely")
	settings.set_setting(&"shadow_quality", 12)
	_check(settings.get_shadow_quality() == "standard", "Non-string quality must fall back safely")
	_check(notifications.size() == 3, "No redundant change event for unchanged normalized values")
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "music_volume", 37)
	legacy.set_value("graphics", "palette_enabled", true)
	legacy.save(TEST_PATH)
	settings._load_settings(TEST_PATH)
	_check(settings.get_shadow_quality() == "standard", "Old config without quality needs default")
	_check(settings.get_palette_enabled() and settings.get_volume(&"music_volume") == 37, "Other saved choices must survive")
	legacy.set_value("graphics", "shadow_quality", "high")
	legacy.save(TEST_PATH)
	settings._load_settings(TEST_PATH)
	_check(settings.get_shadow_quality() == "high", "Saved quality must load")
	legacy.set_value("graphics", "shadow_quality", "bad")
	legacy.save(TEST_PATH)
	settings._load_settings(TEST_PATH)
	_check(settings.get_shadow_quality() == "standard", "Invalid saved quality must normalize")
	settings.free()
	var panel := PANEL.instantiate() as Control
	panel.theme = THEME
	root.add_child(panel)
	await process_frame
	await process_frame
	var option := panel.get_node("ShadowQuality/Option") as OptionButton
	_check(option.item_count == 3, "Settings UI must expose three qualities")
	_check(panel.get_combined_minimum_size().y <= 230.0, "Settings must fit 360px menu with title/back button: %s" % panel.get_combined_minimum_size())
	print("Shadow quality panel minimum: ", panel.get_combined_minimum_size())
	panel.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if "--capture" in OS.get_cmdline_user_args():
		var menu: CanvasLayer = load("res://scenes/ui/pause_menu.tscn").instantiate()
		root.add_child(menu)
		menu.open_pause()
		menu._open_settings()
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/shadow_quality_settings.png")
		menu.free()
	print("Shadow quality settings: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
