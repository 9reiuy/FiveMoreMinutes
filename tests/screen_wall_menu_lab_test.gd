extends SceneTree
## UI admission gate in GameTestLab, before promoting the menu scene.
const CANDIDATE := "res://scenes/preview/screen_wall_menu_candidate.tscn"
var OUT := "res://.runtime/screen_wall_menu_promotion_20261107/"
var lab: Control
var menu: Control
var checks := 0
var failures := 0
var actions := {"new_game": 0, "continue": 0, "quit": 0}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			OUT = argument.trim_prefix("--output-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

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
	var display: Node3D = menu.wall_view.displays[index]
	var projected: Vector2 = menu.wall_view.camera.unproject_position(display.chassis.to_global(Vector3(0, 0, 0.04)))
	return projected / Vector2(menu.wall_viewport.size) * menu.size + menu.global_position

func choose(index: int) -> void:
	var point := screen_point(index)
	pointer(point)
	await frames(34)
	check(menu.wall_view.hovered == menu.wall_view.displays[index], "native pointer reaches television " + str(index + 1))
	await click(point)
	await frames(18)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "Camera capture " + label)

func create_lab(saved: bool = false) -> void:
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = CANDIDATE
	root.add_child(lab)
	menu = lab.presentation
	menu.has_save = saved
	menu.wall_view.preview_frame_limit = 60
	menu.wall_view.unfocused_frame_limit = 60
	menu.wall_view._apply_preview_frame_limit(false)
	menu.new_game_requested.connect(func(): actions.new_game += 1)
	menu.continue_requested.connect(func(): actions.continue += 1)
	menu.quit_requested.connect(func(): actions.quit += 1)
	await frames(65)

func wait_for_request(action: String, count: int) -> void:
	var deadline := Time.get_ticks_msec() + 4500
	while actions[action] < count and Time.get_ticks_msec() < deadline:
		await process_frame

func reload_lab(saved: bool = false) -> void:
	lab.queue_free()
	await frames(5)
	await create_lab(saved)

func run() -> void:
	print("MENU_LAB_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
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
	await create_lab()
	check(menu.wall_view.displays.size() == 12, "lab loads all twelve production-art televisions")
	check(menu.wall_viewport.own_world_3d, "menu owns an isolated camera/lighting world")
	check(menu.wall_viewport.size == Vector2i(1280, 720), "native render resolution retained")
	check(not menu.wall_view.displays[0].option_enabled, "no-save Continue is disabled")
	check(not menu.menu_content.visible and not menu.get_node("HomeScreenVisual").visible, "legacy presentation hidden")
	check(menu.version_label.text == "V0.5.0" and menu.group_label.text.contains("833796070"), "configured version and community retained")
	check(menu.version_label.is_visible_in_tree() and menu.group_label.is_visible_in_tree(), "footer visible")
	check(menu.group_label.gui_input.get_connections().size() > 0, "community link retains its click binding without opening an external page")
	await shot("menu_idle")
	menu._show_settings()
	var television: CanvasLayer=menu.settings_television
	check(television.settings_only and television.settings_open and not paused,"main-menu television opens directly to settings without pausing")
	check(television.wall_view.entering and television.wall_view.terminal.chassis.position.y>television.wall_view.REST_Y+6.0,"main-menu settings starts above the camera")
	await frames(28)
	check(not television.wall_view.entering and absf(television.wall_view.terminal.chassis.position.y-television.wall_view.REST_Y)<0.001,"main-menu television drops and settles at center")
	check(television.settings_back.text.contains("主菜单"),"main-menu settings labels its return destination")
	var terminal: Node3D=television.wall_view.terminal
	terminal._process(8.0)
	check(not terminal.ambient_signals_enabled and not terminal.signal_active,"settings television remains free of random failures")
	var pause_tint: Color=terminal.effect.get_shader_parameter("screen_tint")
	check(pause_tint.is_equal_approx(menu.wall_view.displays[3].base_tint),"settings and main menu share the same blue")
	var quality: OptionButton=television.settings_panel.shadow_quality_option
	check(quality.get_theme_color("font_color").a==0.0 and quality.get_theme_color("font_hover_color").a==0.0,"main-menu settings hides duplicate quality text")
	await shot("settings_shared_television")
	var back_at: Vector2=television.content_screen_position(television.settings_back.get_global_rect().get_center())
	pointer(back_at)
	await frames(3)
	await click(back_at)
	await frames(18)
	check(not television.is_open() and menu.wall_view.interaction_enabled,"embedded return button restores the main-menu wall")
	var eye_center: Vector2 = menu.wall_view.source_to_viewport(menu.wall_view.EYE_CENTER) / Vector2(menu.wall_viewport.size) * menu.size
	pointer(eye_center + Vector2(110, 0))
	await frames(35)
	print("MENU_LAB_EYE right center=", eye_center, " mouse=", menu.wall_view.mouse_position, " offset=", menu.wall_view.eye_offset, " scale=", menu.wall_view.interaction_scale)
	check(absf(menu.wall_view.eye_offset.x - 3.3) < 0.15 and absf(menu.wall_view.eye_offset.y) < 0.1, "native pointer scale preserves original 200-pixel follow radius")
	pointer(eye_center + Vector2(240, 0))
	await frames(35)
	check(menu.wall_view.eye_offset.x > 5.8, "native pointer reaches original rightward eye limit")
	pointer(eye_center - Vector2(240, 0))
	await frames(35)
	print("MENU_LAB_EYE left mouse=", menu.wall_view.mouse_position, " offset=", menu.wall_view.eye_offset)
	check(menu.wall_view.eye_offset.x < -3.8 and absf(menu.wall_view.eye_offset.y) < 0.1, "native pointer scale preserves original leftward eye tracking")
	if "--eye-only" in OS.get_cmdline_user_args():
		lab.queue_free()
		await frames(5)
		quit(1 if failures else 0)
		return
	pointer(Vector2(30, 30))
	await key(KEY_RIGHT)
	check(menu.wall_view.hovered == menu.wall_view.displays[6], "keyboard skips disabled Continue")
	await key(KEY_RIGHT)
	await frames(34)
	check(menu.wall_view.hovered == menu.wall_view.displays[5], "keyboard reaches Settings through embedded viewport")
	await key(KEY_ENTER)
	await frames(20)
	check(menu.overlay_mode == "settings" and menu.settings_television.is_open(), "keyboard Enter opens the television settings")
	await key(KEY_ESCAPE)
	await frames(24)
	await choose(0)
	check(actions.continue == 0, "disabled Continue cannot emit a load request")
	await choose(6)
	check(menu.launching_game and actions.new_game == 0, "new game waits for the television shutdown")
	await wait_for_request("new_game", 1)
	check(actions.new_game == 1 and not menu.overlay.visible, "new game without a save retains direct start request")
	await reload_lab(true)
	check(menu.wall_view.displays[0].option_enabled, "valid save enables Continue")
	await choose(0)
	await wait_for_request("continue", 1)
	check(actions.continue == 1, "Continue emits the existing load signal")
	await reload_lab(true)
	await choose(6)
	check(menu.overlay.visible and menu.overlay_mode == "new_game" and actions.new_game == 1, "save overwrite requires the existing confirmation")
	check(not menu.wall_view.interaction_enabled, "modal blocks underlying televisions")
	await shot("overwrite_confirmation")
	await click(screen_point(0))
	check(actions.continue == 1, "confirmation blocks click-through")
	await click(menu.back_button.get_global_rect().get_center())
	await frames(26)
	check(not menu.overlay.visible and not menu.menu_content.visible, "cancel returns to the television wall")
	await choose(6)
	await click(menu.primary_button.get_global_rect().get_center())
	await frames(26)
	await wait_for_request("new_game", 2)
	check(actions.new_game == 2, "confirm emits one existing new-game request")
	await reload_lab(true)
	await choose(5)
	check(menu.settings_television.is_open() and menu.settings_television.settings_open, "television opens the shared CRT settings panel")
	check(menu.wall_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"covered main-menu wall stops rendering")
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		check(false, "settings preserved private mute")
		quit(2)
		return
	check(AudioServer.is_bus_mute(0), "settings preserved private mute")
	await shot("settings")
	await key(KEY_ESCAPE)
	await frames(24)
	check(not menu.settings_television.is_open() and menu.wall_viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS, "Escape closes the settings television and restores the main menu")
	await choose(8)
	check(menu.overlay.visible and menu.overlay_mode == "quit" and actions.quit == 0, "Exit retains its confirmation")
	await click(menu.primary_button.get_global_rect().get_center())
	await frames(26)
	check(actions.quit == 1, "confirm emits the existing quit request")
	menu._return_to_menu()
	await frames(24)
	await click(menu.version_label.get_global_rect().get_center())
	await frames(24)
	check(menu.announcement_window.visible, "version opens the existing announcement")
	check(not menu.wall_view.interaction_enabled, "announcement blocks underlying menu")
	await click(menu.announcement_window.close_button.get_global_rect().get_center())
	await frames(12)
	check(not menu.announcement_window.visible and menu.wall_view.interaction_enabled, "announcement closes back to the menu")
	for index in 3:
		var old_id: int = menu.wall_view.get_instance_id()
		lab.queue_free()
		await frames(5)
		check(not is_instance_id_valid(old_id), "old television world freed on reload " + str(index))
		await create_lab()
		check(menu.wall_view.displays.size() == 12, "reload restores complete menu " + str(index))
	root.size = Vector2i(1280, 800)
	await frames(12)
	check(root.get_texture().get_image().get_size() == Vector2i(1280, 720), "16:9 picture retained in a 16:10 window")
	check(menu.wall_viewport.size == Vector2i(1280, 720), "nested view keeps native letterboxed resolution")
	await choose(5)
	check(menu.overlay_mode == "settings", "letterboxed pointer mapping remains correct")
	await key(KEY_ESCAPE)
	await frames(24)
	await shot("menu_letterbox")
	var raw: Array = []
	var last := Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(menu.wall_viewport.get_viewport_rid(), true)
	for index in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append({"frame_ms": (now - last) / 1000.0,
			"wall_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(menu.wall_viewport.get_viewport_rid())})
		last = now
	var values: Array = raw.map(func(row): return row.frame_ms)
	values.sort()
	var timing := {"p50": values[90], "p95": values[171], "p99": values[178], "max": values.back()}
	var file := FileAccess.open(OUT + "lab_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "timing_ms": timing, "raw": raw,
		"gpu": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name(),
		"scope": "independent GameTestLab UI admission, not whole-game certification"}, "\t"))
	file.close()
	lab.queue_free()
	await frames(5)
	print("MENU_LAB_RESULT checks=", checks, " failures=", failures, " exit=", 1 if failures else 0)
	quit(1 if failures else 0)
