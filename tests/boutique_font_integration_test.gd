extends SceneTree

func _initialize():
	AudioServer.set_bus_mute(0, true)
	var failures := 0
	var theme := load("res://assets/fonts/pixel_theme.tres") as Theme
	var font := theme.default_font as FontFile
	var helpers := [load("res://scripts/ui/pixel_font.gd").get_font(), load("res://scripts/ui/crisp_interaction_font.gd").get_font()]
	for candidate in [font] + helpers:
		if not candidate is FontFile or candidate.antialiasing != TextServer.FONT_ANTIALIASING_NONE or candidate.subpixel_positioning != TextServer.SUBPIXEL_POSITIONING_DISABLED:
			failures += 1
		for character in "正在换弹员工卡电梯设置继续退出游戏0123456789ABCabc":
			if not candidate.has_char(character.unicode_at(0)):
				push_error("Missing glyph: " + character)
				failures += 1
	for license_path in ["res://assets/fonts/boutique_bitmap/OFL-9x9.txt", "res://assets/fonts/boutique_bitmap/OFL-7x7.txt"]:
		if not FileAccess.file_exists(license_path) or "SIL OPEN FONT LICENSE Version 1.1" not in FileAccess.get_file_as_string(license_path):
			failures += 1
	if not font.resource_path.ends_with("BoutiqueBitmap9x9_Bold_1.9.ttf"):
		failures += 1
	print("BOUTIQUE_FONT_FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
