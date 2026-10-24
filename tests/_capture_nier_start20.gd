extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/_nier_start20_capture"
const ACCENT := Color("396fe2")
const KNOCKOUT := Color("0e140d")


func _init() -> void:
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("START20_CAPTURE_BEGIN")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	var host := Control.new()
	host.size = Vector2(640, 360)
	vp.add_child(host)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.02, 1)
	bg.size = Vector2(640, 360)
	host.add_child(bg)

	var status := Label.new()
	status.position = Vector2(12, 6)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 13)
	host.add_child(status)

	var menu_host := Control.new()
	menu_host.position = Vector2(36, 36)
	menu_host.size = Vector2(360, 300)
	host.add_child(menu_host)

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
	group.size = Vector2(360, 300)
	menu_host.add_child(group)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(36, 12)
	vbox.add_theme_constant_override("separation", 14)
	menu_host.add_child(vbox)

	var labels := ["开始游戏", "设置", "制作名单", "退出游戏"]
	var buttons: Array[Button] = []
	for t in labels:
		var b := Button.new()
		b.text = t
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(200, 22)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", ACCENT)
		var empty := StyleBoxEmpty.new()
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(state, empty)
		vbox.add_child(b)
		buttons.append(b)

	await tick(0.08)
	group.register_options(buttons)
	await tick(0.08)

	var settle_w := group._solid_frame_width()
	print("SETTLE_FRAME_W=", settle_w)

	var first3: Array = []
	var all_expands: Array = []
	var shot_i := 0

	status.text = "start20  0.20 -> 1.20 -> 1.0"
	group.activate_option(buttons[1], false)
	var e0 := float(group._frame_expand)
	first3.append(e0)
	all_expands.append(e0)
	print("F0_IMMEDIATE expand=%.4f" % e0)
	status.text = "expand=%.2f  settleW=%.0f  (start stub)" % [e0, settle_w]
	await _save(vp, shot_i)
	shot_i += 1

	for f in range(1, 14):
		await tick(0.016)
		var e := float(group._frame_expand)
		all_expands.append(e)
		if f <= 2:
			first3.append(e)
		print("F%d expand=%.4f" % [f, e])
		status.text = "expand=%.2f  settleW=%.0f" % [e, settle_w]
		await _save(vp, shot_i)
		shot_i += 1

	for bi in [0, 2, 3, 1]:
		group.activate_option(buttons[bi], false)
		var ei := float(group._frame_expand)
		all_expands.append(ei)
		print("ACTIVATE_%d expand=%.4f" % [bi, ei])
		status.text = "expand=%.2f  %s" % [ei, labels[bi]]
		await _save(vp, shot_i)
		shot_i += 1
		for f in range(7):
			await tick(0.016)
			var e := float(group._frame_expand)
			all_expands.append(e)
			status.text = "expand=%.2f  %s" % [e, labels[bi]]
			await _save(vp, shot_i)
			shot_i += 1

	var first_ok := first3.size() >= 1 and float(first3[0]) <= 0.25 and float(first3[0]) >= 0.15
	var rising := first3.size() >= 3 and float(first3[2]) >= float(first3[0])
	var not_half := float(first3[0]) < 0.50
	var vmax := -999.0
	for v in all_expands:
		vmax = maxf(vmax, float(v))
	var report := "settle_frame_w=%.1f\nfirst3=%s\nfirst_ok=%s rising=%s not_half=%s\nmax=%.4f\nsamples=%d\n" % [
		settle_w, str(first3), str(first_ok), str(rising), str(not_half), vmax, all_expands.size()
	]
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report)
	print(report)
	var ok := first_ok and rising and not_half and vmax >= 1.15
	print("START20_CAPTURE_DONE ok=", ok)
	quit(0 if ok else 2)


func _save(vp: SubViewport, i: int) -> void:
	await tick(0.0)
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("NO_TEX ", i)
		return
	var img := tex.get_image()
	if img == null:
		print("NO_IMG ", i)
		return
	img.save_png("%s/f%03d.png" % [OUT_DIR, i])
	print("SHOT ", i)
