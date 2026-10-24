extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/_nier_v6_capture"
const ACCENT := Color("396fe2")
const KNOCKOUT := Color("0e140d")


func _init() -> void:
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("HOVER_SPRING_CAPTURE_START")
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

	var status := Label.new()
	status.position = Vector2(16, 8)
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_override("font", PixelFont.get_font())
	status.add_theme_font_size_override("font_size", 11)
	host.add_child(status)

	var menu_host := Control.new()
	menu_host.position = Vector2(40, 40)
	menu_host.size = Vector2(300, 280)
	host.add_child(menu_host)

	var group := PixelOptionGroup.new()
	group.solid_fill = true
	group.show_selection_frame = false
	group.enable_hover_scale = false
	group.selected_text_color = KNOCKOUT
	group.unselected_text_color = ACCENT
	group.option_frame_spring_duration = 0.14
	group.option_frame_spring_start_scale = 0.35
	group.option_frame_spring_overshoot = 1.25
	group.option_text_spring_overshoot = 1.14
	group.size = Vector2(300, 280)
	menu_host.add_child(group)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(40, 16)
	vbox.add_theme_constant_override("separation", 14)
	menu_host.add_child(vbox)

	var labels := ["继续游戏", "开始游戏", "设置", "退出"]
	var buttons: Array[Button] = []
	for t in labels:
		var b := Button.new()
		b.text = t
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(180, 22)
		b.add_theme_font_override("font", PixelFont.get_font())
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", ACCENT)
		var empty := StyleBoxEmpty.new()
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(state, empty)
		vbox.add_child(b)
		buttons.append(b)

	await tick(0.05)
	await tick(0.05)
	group.register_options(buttons)
	await tick(0.05)

	var all_expands: Array = []
	var shot_i := 0

	for bi in range(buttons.size()):
		status.text = "hover -> %s" % labels[bi]
		group.activate_option(buttons[bi], false)
		print("ACTIVATE ", labels[bi], " expand=", group._frame_expand)
		for f in range(9):
			await tick(0.016)
			all_expands.append(float(group._frame_expand))
			print("H%d F%d expand=%.4f" % [bi, f, group._frame_expand])
			await _save(shot_i)
			shot_i += 1
		await tick(0.04)

	status.text = "back -> restore"
	group.clear_highlight()
	await tick(0.06)
	await _save(shot_i)
	shot_i += 1
	group.activate_option(buttons[0], false)
	print("BACK_RESTORE expand=", group._frame_expand)
	for f in range(10):
		await tick(0.016)
		all_expands.append(float(group._frame_expand))
		print("BACK F%d expand=%.4f" % [f, group._frame_expand])
		await _save(shot_i)
		shot_i += 1

	var vmax := -999.0
	var vmin := 999.0
	for v in all_expands:
		vmax = maxf(vmax, float(v))
		vmin = minf(vmin, float(v))
	var ok := vmax >= 1.15 and vmin <= 0.55
	var report := "samples=%d\nmax=%.4f min=%.4f\nspring_ok=%s\nexpands=%s\n" % [
		all_expands.size(), vmax, vmin, str(ok), str(all_expands)
	]
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report)
	print(report)
	print("HOVER_SPRING_CAPTURE_DONE ok=", ok)
	quit(0 if ok else 2)


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		print("NO_IMG ", i)
		return
	img.save_png("%s/f%03d.png" % [OUT_DIR, i])
	print("SHOT ", i)
