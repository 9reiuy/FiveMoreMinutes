extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/_nier_v5_capture"
const ACCENT := Color("396fe2")
const KNOCKOUT := Color("0e140d")


func _init() -> void:
	call_deferred("run")


func tick() -> void:
	await create_timer(0.02).timeout


func run() -> void:
	print("RUN_START")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)

	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)

	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.035, 1)
	bg.size = Vector2(640, 360)
	host.add_child(bg)

	var tl := Label.new()
	tl.position = Vector2(24, 12)
	tl.text = "MENU click spring"
	tl.add_theme_color_override("font_color", ACCENT)
	host.add_child(tl)

	var tr := Label.new()
	tr.position = Vector2(330, 12)
	tr.text = "SETTINGS zh / 2-col"
	tr.add_theme_color_override("font_color", ACCENT)
	host.add_child(tr)

	var menu_host := Control.new()
	menu_host.position = Vector2(24, 40)
	menu_host.size = Vector2(280, 240)
	host.add_child(menu_host)

	var group := PixelOptionGroup.new()
	group.solid_fill = true
	group.show_selection_frame = false
	group.enable_hover_scale = false
	group.selected_text_color = KNOCKOUT
	group.unselected_text_color = ACCENT
	group.option_frame_spring_duration = 0.11
	group.option_frame_spring_start_scale = 0.32
	group.option_frame_spring_overshoot = 1.18
	group.size = Vector2(280, 240)
	menu_host.add_child(group)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(30, 10)
	vbox.add_theme_constant_override("separation", 12)
	menu_host.add_child(vbox)

	var labels := ["继续游戏", "开始游戏", "设置", "退出"]
	var buttons: Array[Button] = []
	for label_text in labels:
		var b := Button.new()
		b.text = label_text
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(170, 20)
		b.add_theme_font_override("font", PixelFont.get_font())
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", ACCENT)
		var empty := StyleBoxEmpty.new()
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(state, empty)
		vbox.add_child(b)
		buttons.append(b)
		b.pressed.connect(func() -> void:
			group.clear_highlight()
		)

	var settings_panel: Control = load("res://scenes/ui/settings_panel.tscn").instantiate()
	settings_panel.position = Vector2(330, 40)
	settings_panel.size = Vector2(290, 280)
	host.add_child(settings_panel)

	await tick()
	await tick()
	group.register_options(buttons)
	group.activate_option(buttons[2], false)
	await tick()
	await tick()
	await _save("00_settled")

	buttons[2].pressed.emit()
	print("POST click expand=", group._frame_expand, " busy=", group._confirm_spring_busy)

	var expands: Array[float] = []
	for i in range(1, 14):
		await tick()
		expands.append(float(group._frame_expand))
		await _save("%02d_spring" % i)

	var vmax := -999.0
	var vmin := 999.0
	for v in expands:
		vmax = maxf(vmax, v)
		vmin = minf(vmin, v)
	var ok := vmax > 1.05 or vmin < 0.85
	var report := "expands=%s\nmax=%s min=%s\nspring_visible=%s\n" % [
		str(expands), str(vmax), str(vmin), str(ok)
	]
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report)
	print(report)
	await _save("30_final")
	print("DONE")
	quit(0 if ok else 2)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		print("NO_IMG ", name)
		return
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())
