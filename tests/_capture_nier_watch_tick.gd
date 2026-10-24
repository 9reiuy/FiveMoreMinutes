extends SceneTree

const OUT := "E:/GameProjects/FiveMinuteMore/_nier_watch_tick"
const ACCENT := Color("396fe2")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	print("WATCH_TICK_INIT")
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("WATCH_TICK_BEGIN")
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

	var status := Label.new()
	status.position = Vector2(8, 4)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 11)
	host.add_child(status)

	var title := Label.new()
	title.text = "watch_tick + < > hover white"
	title.position = Vector2(40, 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 13)
	host.add_child(title)

	var panel_script: GDScript = load("res://scripts/ui/settings_panel.gd") as GDScript
	var styler: Object = panel_script.new()
	print("STYLER=", styler)

	var cycles: Array[OptionButton] = []
	var cycle_labels := ["配色方案", "阴影质量"]
	var cycle_items := [["方案 1", "关闭"], ["低", "默认", "高"]]
	for i in range(2):
		var row := HBoxContainer.new()
		row.position = Vector2(48, 64 + i * 36)
		row.add_theme_constant_override("separation", 16)
		host.add_child(row)
		var desc := Label.new()
		desc.text = cycle_labels[i]
		desc.custom_minimum_size = Vector2(96, 0)
		desc.add_theme_color_override("font_color", ACCENT)
		row.add_child(desc)
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(160, 22)
		opt.focus_mode = Control.FOCUS_NONE
		for item in cycle_items[i]:
			opt.add_item(item)
		opt.select(0 if i == 0 else 2)
		row.add_child(opt)
		styler.call("_style_nier_cycle", opt)
		cycles.append(opt)

	var sliders: Array[HSlider] = []
	var slabels := ["总音量", "音乐", "音效"]
	var vals := [62.0, 48.0, 74.0]
	for i in range(3):
		var row := HBoxContainer.new()
		row.position = Vector2(48, 160 + i * 40)
		row.add_theme_constant_override("separation", 12)
		host.add_child(row)
		var desc := Label.new()
		desc.text = slabels[i]
		desc.custom_minimum_size = Vector2(72, 0)
		desc.add_theme_color_override("font_color", ACCENT)
		row.add_child(desc)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = vals[i]
		slider.custom_minimum_size = Vector2(240, 22)
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var pct := Label.new()
		pct.name = "Pct"
		pct.text = "%d%%" % int(vals[i])
		pct.add_theme_color_override("font_color", ACCENT)
		row.add_child(pct)
		styler.call("_style_nier_slider", slider)
		sliders.append(slider)

	print("LAYOUT_DONE")
	await tick(0.2)
	print("AFTER_TICK")

	var shot := 0
	var palette: OptionButton = cycles[0]
	var caption := palette.get_node_or_null("NierCycleCaption") as HBoxContainer
	var left: Label = null
	var mid: Label = null
	if caption != null:
		left = caption.get_node_or_null("LeftBracket") as Label
		mid = caption.get_node_or_null("Value") as Label
	print("CAPTION=", caption != null, " left=", left != null)

	status.text = "rest: brackets accent #396FE2"
	for _i in range(5):
		await _save(shot)
		shot += 1
		await tick(0.02)
	print("REST_SHOTS_DONE shot=", shot)

	status.text = "hover: < > white, value stays accent"
	styler.call("_on_nier_cycle_bracket_hover", palette, true)
	styler.call("_on_nier_cycle_bracket_hover", cycles[1], true)
	await tick(0.04)
	if left != null and mid != null:
		print("HOVER_LEFT=", left.get_theme_color("font_color"), " MID=", mid.get_theme_color("font_color"))
	for _i in range(7):
		await _save(shot)
		shot += 1
		await tick(0.02)
	print("HOVER_SHOTS_DONE shot=", shot)

	status.text = "exit hover"
	styler.call("_on_nier_cycle_bracket_hover", palette, false)
	styler.call("_on_nier_cycle_bracket_hover", cycles[1], false)
	await tick(0.04)
	for _i in range(3):
		await _save(shot)
		shot += 1
		await tick(0.02)

	status.text = "hover + volume drag"
	styler.call("_on_nier_cycle_bracket_hover", palette, true)
	var master: HSlider = sliders[0]
	var hi: Texture2D = master.get_theme_icon("grabber_highlight", "HSlider")
	if hi != null:
		master.add_theme_icon_override("grabber", hi)
	await tick(0.03)
	for v in range(20, 90, 5):
		master.value = float(v)
		var pct_lab := master.get_parent().get_node_or_null("Pct") as Label
		if pct_lab:
			pct_lab.text = "%d%%" % v
		await _save(shot)
		shot += 1
		await tick(0.018)
	print("DRAG_DONE shot=", shot)

	await _save(shot)
	var full := root.get_texture().get_image()
	if full:
		full.save_png(OUT + "/full_hover.png")
		full.get_region(Rect2i(40, 55, 320, 90)).save_png(OUT + "/crop_cycle_hover.png")

	var left_c := left.get_theme_color("font_color") if left != null else Color()
	var mid_c := mid.get_theme_color("font_color") if mid != null else Color()
	var rf := FileAccess.open(OUT + "/report.txt", FileAccess.WRITE)
	rf.store_string(
		"task=watch_tick + cycle bracket hover white\n"
		+ "accent=#396FE2\n"
		+ "hover_bracket=%s\n" % str(left_c)
		+ "value_color=%s\n" % str(mid_c)
		+ "shots=%d\n" % shot
	)
	rf.close()
	if styler is Node:
		(styler as Node).free()
	print("SHOTS=", shot, " HOVER_LEFT=", left_c, " MID=", mid_c, " OK")
	quit(0)


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img:
		img.save_png(OUT + "/f%03d.png" % i)