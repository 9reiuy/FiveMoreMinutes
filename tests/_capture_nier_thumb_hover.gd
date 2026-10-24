extends SceneTree

const OUT := "E:/GameProjects/FiveMinuteMore/_nier_thumb_capture"
const LOG := "E:/GameProjects/FiveMinuteMore/_nier_thumb_capture/progress.txt"
const ACCENT := Color("396fe2")
const CREAM := Color("f2efe6")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_log("INIT")
	call_deferred("run")

func _log(msg: String) -> void:
	var f := FileAccess.open(LOG, FileAccess.WRITE_READ)
	if f == null:
		f = FileAccess.open(LOG, FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(msg)
	f.close()
	print(msg)

func tick(s: float = 0.016) -> void:
	await create_timer(s).timeout

func run() -> void:
	_log("RUN")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	DisplayServer.window_set_size(Vector2i(640, 360))
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

	# Left labels + option group (fast spring)
	var g_host := Control.new()
	g_host.position = Vector2(24, 40)
	g_host.size = Vector2(280, 160)
	host.add_child(g_host)
	var group := PixelOptionGroup.new()
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	group.solid_fill = true
	group.show_selection_frame = false
	group.enable_hover_scale = false
	group.selected_text_color = CREAM
	group.unselected_text_color = ACCENT
	group.option_frame_spring_duration = 0.12
	group.option_frame_spring_start_scale = 0.20
	group.option_frame_spring_overshoot = 1.20
	group.option_text_spring_start_scale = 0.82
	group.option_text_spring_overshoot = 1.12
	group.option_frame_solid_v_pad = 0.0
	g_host.add_child(group)
	g_host.move_child(group, 0)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(28, 8)
	vbox.add_theme_constant_override("separation", 8)
	g_host.add_child(vbox)
	var labels := ["总音量", "音乐", "音效", "像素化"]
	var btns: Array[Button] = []
	for t in labels:
		var b := Button.new()
		b.text = t
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(96, 0)
		b.add_theme_color_override("font_color", ACCENT)
		b.add_theme_font_size_override("font_size", 14)
		var empty := StyleBoxEmpty.new()
		for st in [&"normal", &"hover", &"pressed", &"focus"]:
			b.add_theme_stylebox_override(st, empty)
		vbox.add_child(b)
		btns.append(b)

	# Right: three sliders styled like settings (static, no spring)
	var panel := UnifiedSettingsPanel.new() if false else null
	var sliders_host := Control.new()
	sliders_host.position = Vector2(320, 48)
	sliders_host.size = Vector2(280, 200)
	host.add_child(sliders_host)
	var s_title := Label.new()
	s_title.text = "滑杆 hover → 白"
	s_title.add_theme_color_override("font_color", ACCENT)
	sliders_host.add_child(s_title)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 80
	slider.position = Vector2(0, 40)
	slider.size = Vector2(160, 20)
	slider.focus_mode = Control.FOCUS_NONE
	sliders_host.add_child(slider)
	_style_slider(slider)

	var pct := Label.new()
	pct.text = "80%"
	pct.position = Vector2(170, 40)
	pct.add_theme_color_override("font_color", ACCENT)
	sliders_host.add_child(pct)

	await tick(0.1)
	group.register_options(btns)
	await tick(0.05)
	_log("DUR=%.2f START=%.2f" % [group.option_frame_spring_duration, group.option_frame_spring_start_scale])

	var shot := 0
	# Fast spring cycle on left labels only
	for bi in [0, 1, 2, 1]:
		status.text = "spring %s dur=0.12" % labels[bi]
		group.activate_option(btns[bi], false)
		await tick(0.0)
		for f in range(8):
			await tick(0.016)
			await _save(shot)
			shot += 1
		_log("spring_frame H=%.0f e=%.2f" % [group._frame_size.y, group._frame_expand])

	# Slider thumb: blue (default) then force highlight icon as if hovered
	status.text = "thumb BLUE (default)"
	await tick(0.05)
	await _save(shot)
	shot += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/thumb_blue.png" % OUT)

	status.text = "thumb WHITE (hover)"
	# Simulate hover: swap grabber to white (same as grabber_highlight)
	var white := _ibeam(Color.WHITE)
	slider.add_theme_icon_override("grabber", white)
	await tick(0.05)
	await _save(shot)
	shot += 1
	await _save(shot)
	shot += 1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/thumb_white.png" % OUT)

	# Restore blue
	slider.add_theme_icon_override("grabber", _ibeam(ACCENT))
	status.text = "thumb restored BLUE"
	await tick(0.05)
	await _save(shot)
	shot += 1

	_log("SHOTS=%d OK" % shot)
	# Write report
	var rf := FileAccess.open("%s/report.txt" % OUT, FileAccess.WRITE)
	rf.store_string("duration=0.12 start=0.20 overshoot=1.20\nleft_label_spring=yes right_control_spring=no\nthumb_hover=grabber_highlight white\nshots=%d\n" % shot)
	rf.close()
	quit(0)

func _style_slider(slider: HSlider) -> void:
	var empty := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("slider", empty)
	slider.add_theme_stylebox_override("grabber_area", empty)
	slider.add_theme_stylebox_override("grabber_area_highlight", empty)
	var blue := _ibeam(ACCENT)
	var white := _ibeam(Color.WHITE)
	slider.add_theme_icon_override("grabber", blue)
	slider.add_theme_icon_override("grabber_highlight", white)
	slider.add_theme_icon_override("grabber_disabled", blue)
	# dash track
	var drawer := Control.new()
	drawer.name = "NierDashTrack"
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer.draw.connect(func() -> void:
		var mid_y := drawer.size.y * 0.5
		var x := 0.0
		while x < drawer.size.x:
			var seg := minf(x + 4.0, drawer.size.x)
			drawer.draw_line(Vector2(x, mid_y), Vector2(seg, mid_y), ACCENT, 1.0)
			x = seg + 3.0
	)
	slider.add_child(drawer)

func _ibeam(color: Color) -> ImageTexture:
	var img := Image.create(5, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(5):
		img.set_pixel(x, 0, color)
		img.set_pixel(x, 13, color)
	for y in range(14):
		img.set_pixel(2, y, color)
	return ImageTexture.create_from_image(img)

func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img:
		img.save_png("%s/f%03d.png" % [OUT, i])
