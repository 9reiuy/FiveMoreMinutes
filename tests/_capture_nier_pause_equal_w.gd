extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/_nier_pause_equal_w"
const ACCENT := Color("396fe2")
const KNOCKOUT := Color("f2efe6")


func _init() -> void:
	print("PAUSE_EQUAL_W_INIT")
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("PAUSE_EQUAL_W_BEGIN")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	root.size = Vector2i(640, 360)

	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1)
	bg.size = Vector2(640, 360)
	host.add_child(bg)

	var title := Label.new()
	title.text = "暂停"
	title.position = Vector2(48, 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 28)
	host.add_child(title)

	var status := Label.new()
	status.position = Vector2(8, 4)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 11)
	host.add_child(status)

	var menu_host := Control.new()
	menu_host.position = Vector2(40, 80)
	menu_host.size = Vector2(360, 220)
	host.add_child(menu_host)

	var group := PixelOptionGroup.new()
	group.solid_fill = true
	group.show_selection_frame = false
	group.enable_hover_scale = false
	group.selected_text_color = KNOCKOUT
	group.unselected_text_color = ACCENT
	group.option_frame_spring_duration = 0.12
	group.option_frame_spring_start_scale = 0.20
	group.option_frame_spring_overshoot = 1.20
	group.option_text_spring_start_scale = 0.82
	group.option_text_spring_overshoot = 1.12
	group.option_frame_solid_v_pad = 0.0
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_host.add_child(group)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(36, 8)
	vbox.add_theme_constant_override("separation", 10)
	menu_host.add_child(vbox)

	var labels := ["继续游戏", "设置", "退出到主菜单"]
	var buttons: Array[Button] = []
	for t in labels:
		var b := Button.new()
		b.text = t
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(200, 22)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", ACCENT)
		var empty := StyleBoxEmpty.new()
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(state, empty)
		vbox.add_child(b)
		buttons.append(b)

	# Hidden settings-back sibling (mirrors pause_menu.register_options mix).
	var settings_back := Button.new()
	settings_back.text = "返回"
	settings_back.flat = true
	settings_back.visible = false
	settings_back.focus_mode = Control.FOCUS_NONE
	settings_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	settings_back.add_theme_font_size_override("font_size", 17)
	settings_back.add_theme_color_override("font_color", ACCENT)
	menu_host.add_child(settings_back)

	await tick(0.08)
	var regs: Array[Button] = [buttons[0], buttons[1], buttons[2], settings_back]
	group.register_options(regs)
	await tick(0.08)

	var report := PackedStringArray()
	var shared := group._solid_frame_width()
	report.append("shared_settle_w=%.1f" % shared)
	print("SHARED_SETTLE_W=", shared)
	for i in range(buttons.size()):
		var tw := group._measure_button_text(buttons[i]).x
		report.append("label[%d] %s text_w=%.1f" % [i, labels[i], tw])
		print("LABEL ", labels[i], " text_w=", tw)

	var widths: Array = []
	var shot := 0
	for bi in range(buttons.size()):
		status.text = "pause -> %s" % labels[bi]
		group.activate_option(buttons[bi], false)
		for f in range(10):
			await tick(0.016)
			status.text = "%s e=%.2f W=%.0f" % [labels[bi], group._frame_expand, group._frame_size.x]
			await _save(shot)
			shot += 1
		await tick(0.04)
		var w := group._frame_size.x
		widths.append(w)
		var line := "SETTLED[%d] %s frame_w=%.1f shared=%.1f expand=%.3f" % [bi, labels[bi], w, shared, group._frame_expand]
		report.append(line)
		print(line)
		await _save(shot)
		shot += 1

	var equal := true
	for w in widths:
		if absf(float(w) - float(widths[0])) > 0.5:
			equal = false
	report.append("equal_widths=%s widths=%s" % [str(equal), str(widths)])
	print("EQUAL=", equal, " WIDTHS=", widths)

	status.text = "handoff click 设置"
	group.activate_option(buttons[1], false)
	for f in range(8):
		await tick(0.016)
		await _save(shot)
		shot += 1
	var pause_w_at_settings := group._frame_size.x
	group.clear_highlight()
	settings_back.visible = true
	var mid_shared := group._solid_frame_width()
	report.append("handoff pause_w_at_设置=%.1f mid_tween_shared=%.1f (settings_back visible)" % [pause_w_at_settings, mid_shared])
	print("HANDOFF pause_w=", pause_w_at_settings, " mid_shared=", mid_shared)
	await _save(shot)
	shot += 1

	var ok := equal and absf(float(widths[0]) - shared) <= 1.0
	report.append("ok=%s shots=%d" % [str(ok), shot])
	var report_text := "\n".join(report) + "\n"
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report_text)
	print(report_text)
	print("PAUSE_EQUAL_W_DONE ok=", ok)
	quit(0 if ok else 2)


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/f%03d.png" % [OUT_DIR, i])
