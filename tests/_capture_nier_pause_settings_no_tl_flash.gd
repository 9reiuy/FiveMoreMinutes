extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/ui-previews/pause-settings-no-tl-flash"
const ACCENT := Color("396fe2")
const KNOCKOUT := Color("f2efe6")
const PAGE_TWEEN_SECONDS := 0.20


func _init() -> void:
	print("PAUSE_SETTINGS_FLASH_INIT")
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("PAUSE_SETTINGS_FLASH_BEGIN")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	root.size = Vector2i(640, 360)

	var host := Control.new()
	host.size = Vector2(640, 360)
	root.add_child(host)

	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.01, 0.017, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)

	var f3 := Label.new()
	f3.text = "[F3] debug"
	f3.position = Vector2(4, 2)
	f3.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	f3.add_theme_font_size_override("font_size", 12)
	host.add_child(f3)

	var status := Label.new()
	status.position = Vector2(4, 18)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 11)
	host.add_child(status)

	var option_group := PixelOptionGroup.new()
	option_group.solid_fill = true
	option_group.show_selection_frame = false
	option_group.enable_hover_scale = false
	option_group.selected_text_color = KNOCKOUT
	option_group.unselected_text_color = ACCENT
	option_group.option_frame_spring_duration = 0.12
	option_group.option_frame_spring_start_scale = 0.20
	option_group.option_frame_spring_overshoot = 1.20
	option_group.option_text_spring_start_scale = 0.82
	option_group.option_text_spring_overshoot = 1.12
	option_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(option_group)

	var panel := Control.new()
	panel.position = Vector2(140, 30)
	panel.size = Vector2(360, 300)
	host.add_child(panel)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(title)

	var menu_buttons := VBoxContainer.new()
	menu_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_buttons.add_theme_constant_override("separation", 10)
	layout.add_child(menu_buttons)

	var resume_b := _btn("继续游戏")
	var settings_b := _btn("设置")
	var exit_b := _btn("退出到主菜单")
	menu_buttons.add_child(resume_b)
	menu_buttons.add_child(settings_b)
	menu_buttons.add_child(exit_b)

	var settings_panel := Control.new()
	settings_panel.custom_minimum_size = Vector2(340, 180)
	settings_panel.visible = false
	layout.add_child(settings_panel)
	var settings_label := Label.new()
	settings_label.text = "总音量 / 音乐 / 音效"
	settings_label.add_theme_color_override("font_color", ACCENT)
	settings_label.position = Vector2(40, 40)
	settings_panel.add_child(settings_label)

	var settings_back := _btn("返回")
	settings_back.visible = false
	settings_back.custom_minimum_size = Vector2(250, 34)
	layout.add_child(settings_back)

	await tick(0.12)
	option_group.register_options([resume_b, settings_b, exit_b, settings_back] as Array[Button])
	await tick(0.08)
	print("REGISTERED selectable=", option_group.get_selectable_options().size())

	var report := PackedStringArray()
	var flash_hits := 0
	var shot := 0

	status.text = "hover 设置"
	option_group.activate_option(settings_b, false)
	print("AFTER_HOVER pos=", option_group._frame_position, " size=", option_group._frame_size, " a=", option_group._frame_alpha)
	for _i in range(8):
		await tick(0.016)
		flash_hits += _check_flash(option_group, report, "hover")
		await _save(shot)
		shot += 1

	status.text = "click spring 设置"
	option_group._play_confirm_spring(settings_b)
	print("SPRING_BUSY=", option_group.is_confirm_spring_busy())
	await option_group.wait_confirm_spring()
	print("SPRING_DONE pos=", option_group._frame_position, " a=", option_group._frame_alpha)
	for _i in range(2):
		await tick(0.016)
		flash_hits += _check_flash(option_group, report, "spring_tail")
		await _save(shot)
		shot += 1

	status.text = "handoff fixed"
	option_group.clear_highlight()
	print("CLEARED pos=", option_group._frame_position, " size=", option_group._frame_size, " a=", option_group._frame_alpha)
	title.text = "设置"
	menu_buttons.visible = false
	menu_buttons.modulate.a = 1.0
	settings_panel.visible = true
	settings_panel.modulate.a = 0.0
	settings_back.visible = true
	settings_back.modulate.a = 0.0
	option_group.set_hover_suppressed(true)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(settings_panel, "modulate:a", 1.0, PAGE_TWEEN_SECONDS)
	tw.tween_property(settings_back, "modulate:a", 1.0, PAGE_TWEEN_SECONDS)

	var elapsed := 0.0
	while elapsed < PAGE_TWEEN_SECONDS + 0.04:
		await tick(0.016)
		elapsed += 0.016
		flash_hits += _check_flash(option_group, report, "handoff")
		status.text = "handoff t=%.2f pos=%s a=%.2f" % [elapsed, str(option_group._frame_position.round()), option_group._frame_alpha]
		await _save(shot)
		shot += 1
	option_group.set_hover_suppressed(false)
	settings_back.modulate.a = 1.0
	settings_panel.modulate.a = 1.0
	print("HANDOFF_DONE flash_hits=", flash_hits)
	await _save(shot)
	shot += 1

	status.text = "返回"
	option_group.clear_highlight()
	title.text = "暂停"
	settings_panel.visible = false
	settings_back.visible = false
	menu_buttons.visible = true
	menu_buttons.modulate.a = 0.0
	option_group.set_hover_suppressed(true)
	var tw2 := create_tween()
	tw2.tween_property(menu_buttons, "modulate:a", 1.0, PAGE_TWEEN_SECONDS)
	elapsed = 0.0
	while elapsed < PAGE_TWEEN_SECONDS + 0.04:
		await tick(0.016)
		elapsed += 0.016
		flash_hits += _check_flash(option_group, report, "return")
		await _save(shot)
		shot += 1
	option_group.set_hover_suppressed(false)
	menu_buttons.modulate.a = 1.0
	var opts := option_group.get_selectable_options()
	print("RETURN selectable=", opts.size())
	if not opts.is_empty():
		option_group.activate_option(opts[0], false)
	for _i in range(10):
		await tick(0.016)
		flash_hits += _check_flash(option_group, report, "restored")
		await _save(shot)
		shot += 1

	var shared := option_group._solid_frame_width()
	var settled_w := option_group._frame_size.x
	report.append("restored shared_w=%.1f frame_w=%.1f expand=%.3f pos=%s" % [shared, settled_w, option_group._frame_expand, str(option_group._frame_position)])
	report.append("flash_hits=%d shots=%d" % [flash_hits, shot])
	var ok := flash_hits == 0 and settled_w > 8.0 and option_group._frame_position.x > 24.0
	report.append("ok=%s" % str(ok))
	var report_text := "\\n".join(report) + "\\n"
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report_text)
	print(report_text)
	print("PAUSE_SETTINGS_FLASH_DONE ok=", ok, " flash_hits=", flash_hits)
	quit(0 if ok else 2)


func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(250, 38)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", ACCENT)
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(state, empty)
	return b


func _check_flash(group: PixelOptionGroup, report: PackedStringArray, tag: String) -> int:
	if group._frame_alpha <= 0.001:
		return 0
	var p: Vector2 = group._frame_position
	if p.x < 24.0 and p.y < 24.0 and group._frame_size.x > 1.0:
		var line := "FLASH[%s] pos=%s size=%s a=%.3f" % [tag, str(p), str(group._frame_size), group._frame_alpha]
		report.append(line)
		print(line)
		return 1
	return 0


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/f%03d.png" % [OUT_DIR, i])
