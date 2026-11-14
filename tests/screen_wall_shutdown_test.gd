extends SceneTree
## Independent GameTestLab gate for the timed CRT shutdown and input quarantine.
var OUT := "res://.runtime/screen_wall_shutdown_20261107/"
var lab: Control
var menu: Control
var checks := 0
var failures := 0
var trace: Array = []
var requests: Array = []
var origin := 0
var evidence: Array = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			OUT = argument.trim_prefix("--output-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int) -> void:
	for index in count: await process_frame

func pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)

func click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform() * point
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)

func screen_point(index: int) -> Vector2:
	var tv: Node3D = menu.wall_view.displays[index]
	return menu.wall_view.camera.unproject_position(tv.chassis.to_global(Vector3(0, 0, 0.04))) / Vector2(menu.wall_viewport.size) * menu.size

func choose(index: int) -> void:
	var point := screen_point(index)
	pointer(point)
	await frames(34)
	await click(point)

func now() -> float:
	return (Time.get_ticks_usec() - origin) / 1000000.0

func mark(event: String, display: Node3D) -> void:
	trace.append({"event": event, "tv": String(display.chassis.name), "at": now()})

func create_lab(saved: bool) -> void:
	trace = []
	requests = []
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/preview/screen_wall_menu_candidate.tscn"
	root.add_child(lab)
	menu = lab.presentation
	menu.has_save = saved
	menu.wall_view.preview_frame_limit = 60
	menu.wall_view.unfocused_frame_limit = 60
	menu.wall_view._apply_preview_frame_limit(false)
	menu.new_game_requested.connect(func(): requests.append({"action": "new_game", "at": now()}))
	menu.continue_requested.connect(func(): requests.append({"action": "continue", "at": now()}))
	for display in menu.wall_view.displays:
		display.power_off_started.connect(mark.bind("start", display))
		display.power_off_finished.connect(mark.bind("off", display))
	await frames(45)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "Camera " + label)

func inspect_sequence(label: String, capture: bool) -> void:
	check(menu.launching_game and not menu.wall_view.interaction_enabled, label + " locks the television inputs")
	check(requests.is_empty(), label + " has no early game request")
	check(not menu.wall_view.hover_audio.playing, label + " stops the hover sound")
	var wall: Node3D = menu.wall_view
	check(wall.power_off_audio.volume_db == wall.hover_volume_db and wall.power_off_audio.bus == wall.hover_audio.bus and wall.power_off_audio.max_polyphony == 1, "shutdown audio shares hover gain/bus and uses one voice")
	var center := Vector2.ZERO
	for display in wall.displays:
		center += wall.camera.unproject_position(display.chassis.global_position)
	center /= wall.displays.size()
	var distances := {}
	for display in wall.displays:
		distances[String(display.chassis.name)] = wall.camera.unproject_position(display.chassis.global_position).distance_squared_to(center)
	var injected := false
	var captured_line := false
	var captured_eye := false
	var frame_data: Array = []
	var raw_frames: Array = []
	var tick := 0
	var deadline := Time.get_ticks_msec() + 5000
	while requests.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
		tick += 1
		var off_count := 0
		for display in wall.displays:
			if display.powered_off: off_count += 1
		raw_frames.append({"at": now(), "off_count": off_count, "eye_progress": wall.displays[6].power_down})
		if not injected and now() > 0.30:
			injected = true
			await click(screen_point(6))
			await key(KEY_ESCAPE)
			await key(KEY_ENTER)
			check(not menu.overlay.visible and not menu.announcement_window.visible, "click/Enter/Escape cannot interrupt the closing sequence")
		if capture and not captured_line:
			for display in wall.displays:
				if display.power_down > 0.45 and display.power_down < 0.70:
					captured_line = true
					await shot("collapse_line")
					break
		if capture and not captured_eye and off_count == 11 and not wall.displays[6].powering_off:
			captured_eye = true
			await shot("only_eye")
		if capture and tick % 2 == 0:
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			frame.resize(640, 360, Image.INTERPOLATE_NEAREST)
			frame_data.append({"at": now(), "image": frame})
	var starts: Array = trace.filter(func(row): return row.event == "start")
	var ends: Array = trace.filter(func(row): return row.event == "off")
	check(starts.size() == 12 and ends.size() == 12, label + " closes each of the twelve televisions once")
	if starts.size() == 12 and ends.size() == 12:
		var inward := true
		for i in 10:
			inward = inward and distances[starts[i].tv] >= distances[starts[i + 1].tv]
		check(inward, label + " starts at the projected perimeter and moves inward")
		check(starts.back().tv == "TV_07" and ends.back().tv == "TV_07", label + " keeps the eye television last")
		var peripheral_end: float = ends.filter(func(row): return row.tv != "TV_07").map(func(row): return row.at).max()
		var eye_start: float = starts.back().at
		check(eye_start - peripheral_end >= 0.30 and eye_start - peripheral_end <= 0.80, label + " eye-only delay is within 0.3-0.8 seconds")
		check(absf((eye_start - peripheral_end) - 0.55) < 0.08, label + " eye-only delay follows the 0.55-second setting")
		check(requests.size() == 1 and requests[0].at >= ends.back().at, label + " emits exactly one game request after the final CRT closes")
	var lights_off := true
	var screens_off := true
	for display in wall.displays:
		lights_off = lights_off and not display.spill_light.visible and display.spill_light.light_energy == 0.0
		screens_off = screens_off and display.powered_off and display.effect.get_shader_parameter("power_down") == 1.0 and not display.chassis.get_node("StatusLED").visible
	check(lights_off and screens_off, label + " extinguishes glass, screen spill and television indicators")
	if capture:
		await shot("all_off")
		check(captured_eye and captured_line, "Camera evidence includes the collapsing line and eye-only hold")
		var timings: Array = []
		for i in frame_data.size():
			frame_data[i].image.save_png(OUT + "motion_%03d.png" % i)
			timings.append(frame_data[i].at)
		var timing := FileAccess.open(OUT + "motion_timing.json", FileAccess.WRITE)
		timing.store_string(JSON.stringify(timings))
		frame_data.clear()
	evidence.append({"case": label, "trace": trace.duplicate(true), "requests": requests.duplicate(true), "raw_frames": raw_frames})
	lab.queue_free()
	await frames(5)

func run() -> void:
	print("SHUTDOWN_LAB_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await create_lab(false)
	origin = Time.get_ticks_usec()
	await choose(0)
	check(not menu.launching_game and trace.is_empty() and requests.is_empty(), "disabled Continue cannot start a shutdown")
	origin = Time.get_ticks_usec()
	await choose(6)
	await inspect_sequence("new_game", true)
	await create_lab(true)
	origin = Time.get_ticks_usec()
	await choose(0)
	await inspect_sequence("continue", false)
	await create_lab(true)
	origin = Time.get_ticks_usec()
	await choose(6)
	check(menu.overlay.visible and trace.is_empty(), "overwrite confirmation appears before any television closes")
	await click(menu.back_button.get_global_rect().get_center())
	await frames(24)
	check(not menu.launching_game and trace.is_empty(), "canceling overwrite leaves every television on")
	await choose(6)
	origin = Time.get_ticks_usec()
	await click(menu.primary_button.get_global_rect().get_center())
	await frames(12)
	await inspect_sequence("confirmed_new_game", false)
	await create_lab(false)
	origin = Time.get_ticks_usec()
	await choose(6)
	var old_wall_id: int = menu.wall_view.get_instance_id()
	lab.queue_free()
	await frames(140)
	check(not is_instance_id_valid(old_wall_id) and requests.is_empty(), "removing a menu during shutdown cannot emit a late game request")
	check(AudioServer.is_bus_mute(0), "private mute retained")
	var file := FileAccess.open(OUT + "shutdown_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "checks": checks, "failures": failures, "audio": AudioServer.get_driver_name(), "cases": evidence}, "\t"))
	file.close()
	print("SHUTDOWN_LAB_RESULT checks=", checks, " failures=", failures, " exit=", 1 if failures else 0)
	quit(1 if failures else 0)
