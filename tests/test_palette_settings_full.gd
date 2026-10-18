extends SceneTree

const SETTINGS_MGR := preload("res://scripts/app/settings_manager.gd")
const PALETTE_SHADER := preload("res://shaders/palette_quantize.gdshader")
const SETTINGS_PANEL := preload("res://scenes/ui/settings_panel.tscn")
const PIXEL_THEME := preload("res://assets/fonts/pixel_theme.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST PALETTE SETTINGS FULL START ---")
	
	# 1. Verify shader uniform and 16 colors
	var shader_code := PALETTE_SHADER.code
	assert(shader_code.find("uniform bool palette_enabled") != -1, "palette_enabled uniform missing")
	assert(shader_code.find("uniform int palette_scheme") == -1, "palette_scheme uniform should be removed")
	assert(shader_code.find("PALETTE_00") != -1, "PALETTE_00 constant missing")
	assert(shader_code.find("PALETTE_15") != -1, "PALETTE_15 constant missing")
	assert(shader_code.find("0.0196078, 0.0235294, 0.0392157") != -1, "PALETTE_00 (#05060A) vec3 values incorrect")
	assert(shader_code.find("0.9294118, 0.9490196, 1.0000000") != -1, "PALETTE_15 (#EDF2FF) vec3 values incorrect")
	assert(shader_code.find("nearest_palette_color") != -1, "nearest_palette_color function missing")
	assert(shader_code.find("SCHEME2_00") == -1, "Scheme 2 should not exist")
	assert(shader_code.find("SCHEME3_00") == -1, "Scheme 3 should not exist")
	assert(shader_code.find("SCHEME4_00") == -1, "Scheme 4 should not exist")
	assert(shader_code.find("SCHEME5_00") == -1, "Scheme 5 should not exist")
	assert(shader_code.find("is_blood_semantic_marker") != -1, "Blood semantic missing")
	assert(shader_code.find("is_charge_semantic_marker") != -1, "Charge semantic missing")
	assert(shader_code.find("is_pickup_shine_semantic_marker") != -1, "Pickup shine semantic missing")
	print("Shader uniform & code verification PASSED")

	# 2. Test SettingsManager defaults and operations
	var sm: Node = SETTINGS_MGR.new()
	sm.values = sm.defaults.duplicate(true)
	assert(sm.get_setting(&"palette_enabled") == true, "Default palette_enabled should be true")
	assert(sm.get_palette_enabled() == true, "Default get_palette_enabled() should be true")
	print("Default setting verification PASSED")

	# 3. Test setting toggles
	sm.set_palette_enabled(false)
	assert(sm.get_palette_enabled() == false, "set_palette_enabled(false) failed")
	sm.set_palette_enabled(true)
	assert(sm.get_palette_enabled() == true, "set_palette_enabled(true) failed")
	print("Toggle verification PASSED")

	# 4. Verify GPL files exist and deleted schemes do not exist
	assert(FileAccess.file_exists("res://art/5min_more_palette.gpl"), "5min_more_palette.gpl missing")
	var gpl_main := FileAccess.get_file_as_string("res://art/5min_more_palette.gpl")
	assert(gpl_main.begins_with("GIMP Palette"), "Invalid GPL header in 5min_more_palette.gpl")
	assert(gpl_main.find("#05060A") != -1, "#05060A missing from 5min_more_palette.gpl")
	assert(gpl_main.find("#EDF2FF") != -1, "#EDF2FF missing from 5min_more_palette.gpl")

	assert(FileAccess.file_exists("res://art/5min_more_palette_sorted.gpl"), "5min_more_palette_sorted.gpl missing")
	for s in [2, 3, 4, 5]:
		var extra_gpl := "res://art/5min_more_palette_scheme%d.gpl" % s
		assert(not FileAccess.file_exists(extra_gpl), "%s should have been deleted" % extra_gpl)
	print("GPL files verification PASSED")

	# 5. Test Settings Panel UI (2 items: 方案 1 and 关闭)
	var panel = SETTINGS_PANEL.instantiate()
	panel.theme = PIXEL_THEME
	root.add_child(panel)
	await process_frame
	await process_frame
	var option: OptionButton = panel.get_node("PaletteScheme/ControlRow/Option")
	assert(option.item_count == 2, "Settings panel option must have 2 items, got %d" % option.item_count)
	assert(option.get_item_text(0) == "方案 1", "Option 0 should be 方案 1")
	assert(option.get_item_text(1) == "关闭", "Option 1 should be 关闭")
	print("Settings panel UI verification PASSED")
	panel.queue_free()
	sm.free()

	print("--- TEST PALETTE SETTINGS FULL ALL PASSED ---")
	quit(0)
