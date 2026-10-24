extends SceneTree

const OUT := "E:/GameProjects/FiveMinuteMore/_nier_slider_ontop"
const ACCENT := Color("396fe2")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	print("SLIDER_ONTOP_INIT")
	call_deferred("run")


func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout


func run() -> void:
	print("SLIDER_ONTOP_BEGIN")
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
	title.text = "grabber above ant-line (production _style_nier_slider)"
	title.position = Vector2(40, 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 13)
	host.add_child(title)

	# Instantiate styler OFF-tree so UnifiedSettingsPanel._ready does not run.
	var panel_script: GDScript = load("res://scripts/ui/settings_panel.gd") as GDScript
	var styler: Object = panel_script.new()
	print("STYLER=", styler)

	var sliders: Array[HSlider] = []
	var labels := ["Master", "Music", "SFX"]
	var vals := [62.0, 48.0, 74.0]
	for i in range(3):
		var row := HBoxContainer.new()
		row.position = Vector2(48, 80 + i * 48)
		row.add_theme_constant_override("separation", 12)
		host.add_child(row)
		var desc := Label.new()
		desc.text = labels[i]
		desc.custom_minimum_size = Vector2(72, 0)
		desc.add_theme_color_override("font_color", ACCENT)
		row.add_child(desc)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = vals[i]
		slider.custom_minimum_size = Vector2(240, 22)
		slider.size = Vector2(240, 22)
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var pct := Label.new()
		pct.text = "%d%%" % int(vals[i])
		pct.add_theme_color_override("font_color", ACCENT)
		row.add_child(pct)
		styler.call("_style_nier_slider", slider)
		sliders.append(slider)

	await tick(0.1)
	var master: HSlider = sliders[0]
	var drawer := master.get_node_or_null("NierDashTrack") as Control
	var behind := false
	if drawer != null:
		behind = bool(drawer.show_behind_parent)
	print("SHOW_BEHIND=", behind, " drawer=", drawer != null)

	var shot := 0
	status.text = "default thin blue I | show_behind_parent=%s" % str(behind)
	for _i in range(5):
		await _save(shot)
		shot += 1
		await tick(0.03)

	status.text = "hover bold white I ON TOP of dashes"
	var hi: Texture2D = master.get_theme_icon("grabber_highlight", "HSlider")
	if hi != null:
		for s in sliders:
			s.add_theme_icon_override("grabber", hi)
	await tick(0.05)
	for _i in range(5):
		await _save(shot)
		shot += 1
		await tick(0.03)

	status.text = "sweep — grabber crosses dashes uncovered"
	for v in range(8, 96, 5):
		master.value = float(v)
		await tick(0.0)
		await _save(shot)
		shot += 1
		await tick(0.018)

	await RenderingServer.frame_post_draw
	var full := root.get_texture().get_image()
	if full:
		full.save_png(OUT + "/full_hover.png")
		full.get_region(Rect2i(40, 70, 380, 170)).save_png(OUT + "/crop_three.png")
		full.get_region(Rect2i(110, 78, 260, 40)).save_png(OUT + "/crop_hover.png")

	var rf := FileAccess.open(OUT + "/report.txt", FileAccess.WRITE)
	rf.store_string(
		"root_cause=NierDashTrack child drew after HSlider parent; grabber is parent theme icon\n"
		+ "fix=drawer.show_behind_parent=true\n"
		+ "show_behind_parent=%s\n" % str(behind)
		+ "tick_sfx=slot_tick (generated 45ms UI tick, rate-limited by sfx_slot_tick_min_interval)\n"
		+ "shots=%d\n" % shot
	)
	rf.close()
	if styler is Node:
		(styler as Node).free()
	print("SHOTS=", shot, " BEHIND=", behind, " OK")
	quit(0)


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img:
		img.save_png(OUT + "/f%03d.png" % i)
