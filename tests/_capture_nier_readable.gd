extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/_nier_readable_capture"
const ACCENT := Color("396fe2")
const KNOCKOUT := Color("f2efe6")


func _init() -> void:
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("READABLE_CAPTURE_BEGIN")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# Off-screen / minimized: no focus steal
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

	var status := Label.new()
	status.position = Vector2(8, 4)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 11)
	host.add_child(status)

	var settings_host := Control.new()
	settings_host.position = Vector2(24, 28)
	settings_host.size = Vector2(300, 200)
	host.add_child(settings_host)
	var settings_group := _make_group(settings_host)
	var settings_vbox := VBoxContainer.new()
	settings_vbox.position = Vector2(28, 8)
	settings_vbox.add_theme_constant_override("separation", 6)
	settings_host.add_child(settings_vbox)
	var settings_labels := ["总音量", "音乐", "音效", "像素化", "配色滤镜", "阴影品质", "游戏辅助功能"]
	var settings_btns: Array[Button] = []
	for t in settings_labels:
		var b := _make_btn(t, 14, Vector2(128, 0))
		settings_vbox.add_child(b)
		settings_btns.append(b)

	var menu_host := Control.new()
	menu_host.position = Vector2(24, 250)
	menu_host.size = Vector2(600, 80)
	host.add_child(menu_host)
	var menu_group := _make_group(menu_host)
	var menu_hbox := HBoxContainer.new()
	menu_hbox.position = Vector2(28, 20)
	menu_hbox.add_theme_constant_override("separation", 18)
	menu_host.add_child(menu_hbox)
	var menu_labels := ["继续", "设置", "退出游戏"]
	var menu_btns: Array[Button] = []
	for t in menu_labels:
		var b := _make_btn(t, 17, Vector2(0, 0))
		menu_hbox.add_child(b)
		menu_btns.append(b)

	await tick(0.1)
	settings_group.register_options(settings_btns)
	menu_group.register_options(menu_btns)
	await tick(0.1)

	var report := PackedStringArray()
	report.append("AFTER cream=#f2efe6 v_pad=0 per-option width text+12 ink-hug")

	var shot := 0
	status.text = "settings 配色滤镜"
	settings_group.activate_option(settings_btns[4], false)
	await tick(0.0)
	var s_settle_w := settings_group._solid_frame_width(settings_btns[4])
	var s_h0 := settings_group._frame_size.y
	var s_w0 := settings_group._frame_size.x
	var s_row := settings_btns[4].size.y
	var s_pitch := settings_btns[5].get_global_rect().get_center().y - settings_btns[4].get_global_rect().get_center().y
	var line := "SETTINGS settle_w=%.1f frame=%.0fx%.0f row_h=%.1f pitch=%.1f expand=%.2f" % [
		s_settle_w, s_w0, s_h0, s_row, s_pitch, settings_group._frame_expand
	]
	report.append(line)
	print(line)
	await _save(shot)
	shot += 1
	for f in range(10):
		await tick(0.016)
		status.text = "settings e=%.2f H=%.0f" % [settings_group._frame_expand, settings_group._frame_size.y]
		await _save(shot)
		shot += 1
	var s_h_final := settings_group._frame_size.y
	var bleed := s_h_final > (s_pitch - 1.0)
	report.append("SETTINGS_FINAL H=%.1f pitch=%.1f bleed=%s" % [s_h_final, s_pitch, str(bleed)])

	status.text = "menu 继续"
	menu_group.activate_option(menu_btns[0], false)
	await tick(0.0)
	var m_settle_w := menu_group._solid_frame_width(menu_btns[0])
	var m_h0 := menu_group._frame_size.y
	var m_w0 := menu_group._frame_size.x
	var m_row := menu_btns[0].size.y
	var m_text := menu_group._measure_button_text(menu_btns[0])
	line = "MENU settle_w=%.1f frame=%.0fx%.0f row_h=%.1f text=%.0fx%.0f expand=%.2f" % [
		m_settle_w, m_w0, m_h0, m_row, m_text.x, m_text.y, menu_group._frame_expand
	]
	report.append(line)
	print(line)
	await _save(shot)
	shot += 1
	for f in range(10):
		await tick(0.016)
		status.text = "menu e=%.2f H=%.0f W=%.0f" % [menu_group._frame_expand, menu_group._frame_size.y, menu_group._frame_size.x]
		await _save(shot)
		shot += 1

	# Settled stills for delivery
	settings_group.activate_option(settings_btns[4], false)
	await tick(0.25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/settings_settled.png" % OUT_DIR)
	menu_group.activate_option(menu_btns[0], false)
	await tick(0.25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/menu_settled.png" % OUT_DIR)
	report.append("SETTINGS_SETTLED H=%.1f W=%.1f" % [settings_group._frame_size.y, settings_group._frame_size.x])
	report.append("MENU_SETTLED H=%.1f W=%.1f" % [menu_group._frame_size.y, menu_group._frame_size.x])

	for bi in [3, 4, 5, 4]:
		settings_group.activate_option(settings_btns[bi], false)
		status.text = "cycle %s H=%.0f" % [settings_labels[bi], settings_group._frame_size.y]
		await _save(shot)
		shot += 1
		for f in range(5):
			await tick(0.016)
			await _save(shot)
			shot += 1

	var cream_ok := settings_group.selected_text_color.r > 0.85
	var ok := (not bleed) and s_h_final <= 16.0 and m_h0 <= 18.0 and s_settle_w < 160.0 and m_settle_w < 100.0 and cream_ok
	report.append("cream_ok=%s H_ok settings<=16 menu<=18" % str(cream_ok))
	report.append("ok=%s" % str(ok))
	var report_text := "\n".join(report) + "\n"
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report_text)
	print(report_text)
	print("READABLE_CAPTURE_DONE ok=", ok, " shots=", shot)
	quit(0 if ok else 2)


func _make_group(parent: Control) -> PixelOptionGroup:
	var group := PixelOptionGroup.new()
	group.solid_fill = true
	group.show_selection_frame = false
	group.enable_hover_scale = false
	group.selected_text_color = KNOCKOUT
	group.unselected_text_color = ACCENT
	group.option_frame_spring_duration = 0.20
	group.option_frame_spring_start_scale = 0.20
	group.option_frame_spring_overshoot = 1.20
	group.option_text_spring_start_scale = 0.82
	group.option_text_spring_overshoot = 1.12
	group.option_frame_solid_v_pad = 0.0
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(group)
	return group


func _make_btn(text: String, font_size: int, mins: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if mins != Vector2.ZERO:
		b.custom_minimum_size = mins
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", ACCENT)
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(state, empty)
	return b


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		print("NO_IMG ", i)
		return
	img.save_png("%s/f%03d.png" % [OUT_DIR, i])
	if i % 5 == 0:
		print("SHOT ", i)