extends SceneTree

const OUT := "E:/GameProjects/FiveMinuteMore/ui-previews"
const TMP := "E:/GameProjects/FiveMinuteMore/_nier_check_outline_hover"
const PANEL_SCENE := "res://scenes/ui/settings_panel.tscn"
const ACCENT := Color("396fe2")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(TMP)
	print("CHECK_OUTLINE_HOVER_INIT")
	call_deferred("run")

func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout

func run() -> void:
	print("CHECK_OUTLINE_HOVER_BEGIN")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	root.size = Vector2i(640, 360)

	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)

	var packed := load(PANEL_SCENE) as PackedScene
	if packed == null:
		push_error("missing settings_panel")
		quit(1)
		return
	var panel := packed.instantiate() as Control
	panel.position = Vector2(80, 40)
	host.add_child(panel)
	await tick(0.2)

	var check: CheckBox = panel.get_node_or_null("Rows/Pixelation/Check") as CheckBox
	var desc: Button = panel.get_node_or_null("Rows/Pixelation/Desc") as Button
	if check == null:
		# Rows may be wrapped in RowsCenter
		check = _find_named(panel, "Check", "Pixelation") as CheckBox
		desc = _find_named(panel, "Desc", "Pixelation") as Button
	if check == null or desc == null:
		push_error("pixelation check/desc missing")
		quit(2)
		return

	check.button_pressed = true
	await tick(0.05)

	var status := Label.new()
	status.position = Vector2(8, 4)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 11)
	host.add_child(status)

	# Rest: no hover
	if panel.has_method("_refresh_all_nier_checkbox_hovers"):
		panel.call("_refresh_all_nier_checkbox_hovers")
	status.text = "rest checked: blue outline + blue fill"
	await tick(0.05)
	await _shot(0, "rest")

	# Force hover icons directly (outline white, fill blue)
	if panel.has_method("_apply_nier_checkbox_icons"):
		panel.call("_apply_nier_checkbox_icons", check, true)
	status.text = "hover checked: WHITE outline + blue fill"
	await tick(0.05)
	await _shot(1, "hover")

	# Animate: rest -> hover -> rest for GIF at normal speed
	var frames: Array[Image] = []
	for i in range(8):
		panel.call("_apply_nier_checkbox_icons", check, false)
		status.text = "rest"
		await tick(0.06)
		frames.append(await _grab_crop(check, desc))
	for i in range(14):
		panel.call("_apply_nier_checkbox_icons", check, true)
		status.text = "hover outline white"
		await tick(0.06)
		frames.append(await _grab_crop(check, desc))
	for i in range(8):
		panel.call("_apply_nier_checkbox_icons", check, false)
		status.text = "rest"
		await tick(0.06)
		frames.append(await _grab_crop(check, desc))

	for i in range(frames.size()):
		frames[i].save_png("%s/f%03d.png" % [TMP, i])
	print("FRAMES=%d" % frames.size())

	# Also save side-by-side compare
	var rest_img := Image.load_from_file(TMP + "/rest_crop.png")
	var hover_img := Image.load_from_file(TMP + "/hover_crop.png")
	if rest_img and hover_img:
		var w := rest_img.get_width() + hover_img.get_width() + 8
		var h := maxi(rest_img.get_height(), hover_img.get_height())
		var cmp := Image.create(w, h, false, Image.FORMAT_RGBA8)
		cmp.fill(Color(0.02, 0.025, 0.03, 1))
		cmp.blit_rect(rest_img, Rect2i(Vector2i.ZERO, rest_img.get_size()), Vector2i(0, 0))
		cmp.blit_rect(hover_img, Rect2i(Vector2i.ZERO, hover_img.get_size()), Vector2i(rest_img.get_width() + 8, 0))
		cmp.save_png(OUT + "/settings-checkbox-outline-hover-compare.png")
		cmp.save_png(TMP + "/compare.png")

	var rf := FileAccess.open(TMP + "/report.txt", FileAccess.WRITE)
	rf.store_line("hover=white_outline fill=blue_accent unchecked_inner=none")
	rf.store_line("accent=#396FE2")
	rf.close()
	print("CHECK_OUTLINE_HOVER_DONE")
	quit(0)

func _find_named(root_n: Node, leaf: String, parent_name: String) -> Node:
	for n in root_n.find_children(leaf, "", true, false):
		if n.get_parent() != null and String(n.get_parent().name) == parent_name:
			return n
	return null

func _grab_crop(check: Control, desc: Control) -> Image:
	await tick(0.0)
	var full := root.get_texture().get_image()
	var rect := desc.get_global_rect().merge(check.get_global_rect()).grow(18)
	rect.position.x = maxf(rect.position.x - 24, 0)
	var r := Rect2i(Vector2i(rect.position), Vector2i(rect.size))
	r.size.x = mini(r.size.x, full.get_width() - r.position.x)
	r.size.y = mini(r.size.y, full.get_height() - r.position.y)
	return full.get_region(r)

func _shot(idx: int, tag: String) -> void:
	await tick(0.0)
	var full := root.get_texture().get_image()
	full.save_png("%s/%s_full.png" % [TMP, tag])
	# Rough crop around pixelation row area
	var crop := full.get_region(Rect2i(60, 80, 420, 120))
	crop.save_png("%s/%s_crop.png" % [TMP, tag])
	crop.save_png("%s/%s.png" % [OUT, "settings-checkbox-" + tag])
	print("SHOT %s" % tag)

