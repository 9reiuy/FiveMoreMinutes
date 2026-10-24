extends SceneTree

const OUT_DIR := "E:/GameProjects/FiveMinuteMore/_nier_blue_restored"

func _init() -> void:
	call_deferred("run")

func tick(sec: float = 0.016) -> void:
	await create_timer(sec).timeout

func run() -> void:
	print("BLUE_RESTORE_BEGIN")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	root.size = Vector2i(640, 360)

	var packed := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause := packed.instantiate() as GlobalPauseMenu
	root.add_child(pause)
	await tick(0.08)
	pause.open_pause()
	await tick(0.1)

	var resume: Button = pause.get_node("Root/Panel/Layout/MenuButtons/Resume")
	var settings: Button = pause.get_node("Root/Panel/Layout/MenuButtons/Settings")
	var exit_btn: Button = pause.get_node("Root/Panel/Layout/MenuButtons/ExitToMenu")
	var group: PixelOptionGroup = pause.option_group
	var cfg = load("res://resources/demo_config.tres")
	print("FILL=", cfg.option_frame_fill_color, " SHARED=", group._solid_frame_width())

	var shot := 0
	for b in [resume, settings, exit_btn]:
		group.activate_option(b, false)
		for f in range(6):
			await tick(0.016)
			await _save(shot)
			shot += 1
		print("SETTLED ", b.text, " w=", group._frame_size.x)

	pause.settings_open = true
	pause._sync_page(false)
	await tick(0.15)
	var sp = pause.settings_panel
	print("SP size=", sp.size, " visible=", sp.visible)
	var rows = sp.rows
	print("ROWS parent=", rows.get_parent().name if rows.get_parent() else "?", " pos=", rows.position, " size=", rows.size)
	var master_desc: Button = sp.master_desc
	var row_select: PixelOptionGroup = sp.row_select
	row_select.activate_option(master_desc, false)
	for f in range(8):
		await tick(0.016)
		await _save(shot)
		shot += 1
	# activate a short row too
	row_select.activate_option(sp.pixelation_desc, false)
	for f in range(6):
		await tick(0.016)
		await _save(shot)
		shot += 1

	var report := "fill=%s shared=%.1f rows_pos=%s rows_size=%s sp_size=%s parent=%s shots=%d\n" % [
		str(cfg.option_frame_fill_color), group._solid_frame_width(),
		str(rows.global_position), str(rows.size), str(sp.size),
		rows.get_parent().name if rows.get_parent() else "?",
		shot,
	]
	FileAccess.open("%s/report.txt" % OUT_DIR, FileAccess.WRITE).store_string(report)
	print(report)
	print("BLUE_RESTORE_DONE")
	quit(0)

func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/f%03d.png" % [OUT_DIR, i])
