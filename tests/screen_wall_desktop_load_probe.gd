extends SceneTree
## Native offscreen GPU measurement; no screenshot readback or forced drawing.
var out := "res://.runtime/screen_wall_stutter_20261108/"
var menu: Control
var samples: Array = []
var checks := 0
var failures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): out = arg.trim_prefix("--output-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func wait_frames(count: int) -> void:
	for index in count: await process_frame

func check_private_mute() -> bool:
	if AudioServer.get_driver_name() == "WASAPI" and AudioServer.is_bus_mute(0) and OS.get_user_data_dir().contains("desktop_probe"):
		return true
	AudioServer.set_bus_mute(0, true)
	quit(2)
	return false

func capture_case(label: String, settings: bool, focused: bool) -> void:
	if not check_private_mute(): return
	if settings: menu._show_settings()
	elif menu._settings_are_open(): menu._close_settings_television()
	root.get_node("FrameBudget").apply_window_focus(focused)
	await create_timer(1.0).timeout
	var television: CanvasLayer = menu.settings_television
	check(menu.wall_viewport.render_target_update_mode == (SubViewport.UPDATE_DISABLED if settings else SubViewport.UPDATE_ALWAYS), label + " wall update mode")
	check(television.wall_viewport.render_target_update_mode == (SubViewport.UPDATE_ALWAYS if settings else SubViewport.UPDATE_DISABLED), label + " settings update mode")
	check(Engine.max_fps == (60 if focused else 30), label + " frame cap")
	var raw: Array = []
	var began := Time.get_ticks_usec()
	var previous := began
	while Time.get_ticks_usec() - began < 4000000:
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append({"frame_ms": (now-previous)/1000.0,
			"wall_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(menu.wall_viewport.get_viewport_rid()) if not settings else 0.0,
			"settings_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(television.wall_viewport.get_viewport_rid()) if settings else 0.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		previous = now
	var stats := {}
	for metric in ["frame_ms", "wall_gpu_ms", "settings_gpu_ms", "draw_calls"]:
		var values: Array = raw.map(func(row): return row[metric])
		values.sort()
		stats[metric] = {"p50": values[values.size()/2], "p95": values[floori(values.size()*0.95)], "p99": values[floori(values.size()*0.99)], "max": values.back()}
	samples.append({"case": label, "fps_limit": Engine.max_fps, "stats": stats, "raw": raw})
	print("DESKTOP_LOAD_CASE ", label, " ", stats.frame_ms)

func run() -> void:
	print("DESKTOP_LOAD_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if not check_private_mute(): return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-30000, -30000))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/preview/screen_wall_menu_candidate.tscn"
	root.add_child(lab)
	menu = lab.presentation
	var deadline := Time.get_ticks_msec() + 12000
	while not menu.settings_television.television_warmed and Time.get_ticks_msec() < deadline: await process_frame
	check(menu.settings_television.television_warmed, "closed settings finishes startup preparation")
	check(not paused, "menu is not globally paused")
	check(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED, "normal VSync enabled")
	RenderingServer.viewport_set_measure_render_time(menu.wall_viewport.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(menu.settings_television.wall_viewport.get_viewport_rid(), true)
	await capture_case("menu_60_A", false, true)
	await capture_case("settings_60_B", true, true)
	await capture_case("menu_60_A2", false, true)
	await capture_case("settings_30", true, false)
	await capture_case("menu_30", false, false)
	for index in 3:
		menu._show_settings()
		await wait_frames(12)
		menu._close_settings_television()
		await wait_frames(3)
		check(not menu._settings_are_open() and not paused and menu.wall_view.interaction_enabled, "repeat settings closes cleanly " + str(index))
	check(check_private_mute(), "private mute survives all settings reloads")
	var file := FileAccess.open(out + "desktop_load.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "audio": AudioServer.get_driver_name(), "gpu": RenderingServer.get_video_adapter_name(), "checks": checks, "failures": failures,
		"conditions": "same production-art GameTestLab, native offscreen 1280x720, normal VSync, WASAPI/private prelaunch mute, 1s warmup and 4s measured per case, no forced draw/readback. Does not directly measure desktop responsiveness.", "settings_warmup_ms": menu.settings_television.warmup_msec, "cases": samples}, "\t"))
	file.close()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	lab.queue_free()
	await wait_frames(4)
	print("DESKTOP_LOAD_RESULT checks=", checks, " failures=", failures, " exit=", 1 if failures else 0)
	quit(1 if failures else 0)
