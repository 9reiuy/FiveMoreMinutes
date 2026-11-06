extends "res://tests/woo_polygon_performance_test.gd"
## Same native four-room route, doors and combat fixtures. Use the actual
## merged entry defaults, including exterior light and the new art compositor.
func _fresh() -> void:
	_release_input()
	if is_instance_valid(lab):
		await lab.retire_drawing()
		lab.queue_free()
		await frames(4)
	lab = load(SCENE).instantiate()
	root.add_child(lab)
	while not lab.sample_ready or lab.busy or lab._loading_layer.visible: await process_frame
	lab.sample_ui.hide(); lab.hud.hide(); lab.panel.hide()
	await frames(90)

func run() -> void:
	output_path = "res://.runtime/hellkind_purple_sample_20261103/combined_art_visibility/performance"
	if "--surface-check" in OS.get_cmdline_user_args():
		output_path = "res://.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/performance"
	DirAccess.make_dir_recursive_absolute(output_path)
	create_timer(300.0,true,false,true).timeout.connect(func(): if not done: finish(2))
	if DisplayServer.get_name() == "headless": failures.append("Native GPU renderer required"); finish(1); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-20000,-20000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _fresh()
	await phase("combined_stationary",6.0,true,"stationary")
	await phase("combined_navigation",16.0,true,"navigation")
	await phase("combined_doors",8.0,true,"doors")
	await _fresh()
	await phase("combined_mixed",19.0,true,"mixed")
	finish(0 if failures.is_empty() else 1)
