extends SceneTree

const OUT := "res://.runtime/terminal_menu_sample_20261106"
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print("PASS " if ok else "FAIL ", message)


func frames(count: int) -> void:
	for _i in count:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/" + name + ".png") == OK, "capture " + name)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func action(name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = name
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func click(button: Button) -> void:
	var position := root.get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await frames(2)
	check(root.gui_get_hovered_control() == button, "mouse reaches " + button.name)
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func capture_motion(chrome: Control, group: PixelOptionGroup) -> void:
	chrome._play_intro()
	chrome._animate_main_intro()
	var timestamps: Array[int] = []
	for i in 64:
		if i == 50:
			group.activate_delta(1, false)
		await frames(3)
		await RenderingServer.frame_post_draw
		timestamps.append(Time.get_ticks_msec())
		root.get_texture().get_image().save_png(OUT + "/motion_%02d.png" % i)
	var timing := FileAccess.open(OUT + "/motion_timing.json", FileAccess.WRITE)
	timing.store_string(JSON.stringify(timestamps))
	timing.close()


func capture_pause_motion(chrome: Control, group: PixelOptionGroup) -> void:
	chrome._play_intro()
	chrome._animate_pause_intro()
	for i in 14:
		if i == 7:
			group.activate_delta(1, false)
		await frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "/pause_motion_%02d.png" % i)


func bright_portrait_pixels(image: Image) -> int:
	var count := 0
	for y in range(110, 510, 4):
		for x in range(465, 815, 4):
			var color := image.get_pixel(x, y)
			if color.g > 0.28 and color.b > 0.30:
				count += 1
	return count


func run() -> void:
	print("TERMINAL_SAMPLE PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
		push_error("Private muted settings were not active before scene entry")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("This visual test requires a real renderer")
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	create_timer(180.0, true, false, true).timeout.connect(func(): quit(2))
	var review: Node = load("res://scenes/preview/terminal_menu_review.tscn").instantiate()
	root.add_child(review)
	await frames(115)
	var game: Node = review.game
	var menu: Node = game.current_screen
	check(menu.has_node("TerminalMainSample"), "sample attaches to real main menu")
	check(game.pause_menu.root.has_node("TerminalPauseSample"), "sample attaches to real pause menu")
	var chrome: Control = menu.get_node("TerminalMainSample")
	check(menu.start_button.get_parent() == chrome.rows, "actual menu buttons are presented in the new rows")
	menu._set_eye_position(Vector2(3, -2))
	check(menu.eye_material.shader.resource_path == "res://shaders/home_screen_eye_mask.gdshader" and menu.eye_material.get_shader_parameter(&"mask_texture") == menu.home_screen_eye_mask.texture and menu.home_screen_eye.position == menu.eye_origin_position + Vector2(3, -2), "eye retains the original texture, mask shader and motion")
	menu._set_eye_position(Vector2.ZERO)
	check(menu.home_screen_eye.z_index > chrome.screen_glass.z_index and is_equal_approx(menu.home_screen_eye.modulate.a, 1.0), "original eye renders above glass effects after reveal")
	check(chrome.screen_glass.material.shader.resource_path == "res://shaders/ui/terminal_sample_crt.gdshader" and chrome.screen_glass.mouse_filter == Control.MOUSE_FILTER_IGNORE, "curved glass leaves input untouched")
	await shot("main")
	await RenderingServer.frame_post_draw
	var normal_view := root.get_texture().get_image()
	var original_iris_pixels := 0
	for y in range(230, 320):
		for x in range(600, 710):
			var color := normal_view.get_pixel(x, y)
			if color.r > 0.48 and color.g < 0.20 and color.b > 0.18 and color.b < 0.30:
				original_iris_pixels += 1
	check(original_iris_pixels > 0, "original red iris remains visible in the rendered image")
	var all_visible := true
	for button: Button in chrome.option_buttons:
		all_visible = all_visible and root.get_visible_rect().encloses(button.get_global_rect())
	check(all_visible, "all menu operations remain within the visible viewport")
	chrome._play_intro()
	chrome._animate_main_intro()
	await frames(3)
	check(chrome.reveal_progress < 0.15 and menu.home_screen_eye.modulate.a < 0.01, "portrait and eye start hidden before the scan")
	await RenderingServer.frame_post_draw
	var before_scan := root.get_texture().get_image()
	await frames(30)
	check(chrome.reveal_progress > 0.1 and chrome.reveal_progress < 0.9, "scan advances through the portrait")
	await frames(100)
	check(chrome.reveal_progress >= 1.0 and is_equal_approx(menu.home_screen_eye.modulate.a, 1.0), "scan reveals the full portrait and unchanged eye")
	await RenderingServer.frame_post_draw
	var after_scan := root.get_texture().get_image()
	check(bright_portrait_pixels(after_scan) > bright_portrait_pixels(before_scan) + 500, "actual rendered portrait appears behind the moving scan")
	chrome.scan_elapsed = 2.0
	await frames(6)
	await RenderingServer.frame_post_draw
	var contour_before := root.get_texture().get_image()
	await frames(45)
	await RenderingServer.frame_post_draw
	var contour_after := root.get_texture().get_image()
	var changed_pixels := 0
	for y in range(190, 490, 3):
		for x in range(140, 420, 3):
			var before_color := contour_before.get_pixel(x, y)
			var after_color := contour_after.get_pixel(x, y)
			if absf(before_color.r - after_color.r) + absf(before_color.g - after_color.g) + absf(before_color.b - after_color.b) > 0.012:
				changed_pixels += 1
	check(changed_pixels > 20, "background contour geometry moves over time")
	await capture_motion(chrome, menu.menu_option_group)
	check(chrome.intro > 0.99, "menu entrance animation finishes")
	await action(&"ui_down")
	check(menu.menu_option_group.get_active_index() >= 0, "keyboard navigation selects an available item")
	menu.menu_option_group.activate_option(menu.settings_button, false)
	await action(&"ui_right")
	check(menu.menu_option_group.get_active_index() == 3, "right arrow selects the next horizontal button")
	await click(menu.settings_button)
	await frames(35)
	check(menu.overlay.visible and menu.overlay_mode == "settings", "mouse opens actual main settings")
	var sm: Node = root.get_node("SettingsManager")
	var music_slider: HSlider = menu.settings_panel.music_slider
	var hatched_track := music_slider.get_node_or_null("TerminalHatchedTrack") as Control
	var old_track := music_slider.get_node_or_null("NierDashTrack") as Control
	check(hatched_track != null and old_track != null and not old_track.visible, "settings uses the hatched slider track")
	if hatched_track != null:
		check(hatched_track.size.x > 0.0 and hatched_track.size.y > 0.0, "hatched slider track has a visible layout")
	var previous_music: int = sm.get_volume(&"music_volume")
	sm.set_volume(&"music_volume", 65)
	await frames(10)
	check(int(music_slider.value) == 65 and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "real slider value updates while private master stays muted")
	await shot("main_settings")
	sm.set_volume(&"music_volume", previous_music)
	await frames(5)
	var before_pixelation: bool = sm.get_setting(&"pixelation_enabled")
	menu.settings_panel.row_select.activate_option(menu.settings_panel.pixelation_desc, false)
	await action(&"ui_accept")
	await frames(5)
	check(bool(sm.get_setting(&"pixelation_enabled")) != before_pixelation, "keyboard toggles a real setting")
	menu.settings_panel.row_select.activate_option(menu.settings_panel.pixelation_desc, false)
	await action(&"ui_accept")
	await frames(5)
	check(bool(sm.get_setting(&"pixelation_enabled")) == before_pixelation, "test restores the private setting")
	await key(KEY_ESCAPE)
	await frames(30)
	check(not menu.overlay.visible, "escape returns from main settings")
	menu.has_save = true
	menu.menu_option_group.activate_option(menu.start_button, false)
	await action(&"ui_accept")
	await frames(35)
	check(menu.overlay.visible and menu.overlay_mode == "new_game", "new game retains save-overwrite confirmation")
	await key(KEY_ESCAPE)
	await frames(30)
	check(not menu.overlay.visible, "escape cancels overwrite confirmation")
	await key(KEY_F8)
	for _i in 800:
		await frames(1)
		if game.pause_menu.is_open():
			break
	await frames(30)
	check(game.pause_menu.is_open() and paused, "F8 enters reception and opens real paused menu")
	var pause_sample: Control = game.pause_menu.root.get_node("TerminalPauseSample")
	var resume_button: Button = game.pause_menu.get_node("Root/Panel/Layout/MenuButtons/Resume")
	check(absf(pause_sample.highlight_x - (resume_button.get_global_rect().position.x - pause_sample.get_global_rect().position.x - 28.0)) < 1.0, "pause selection stays aligned after the entrance animation")
	await shot("pause")
	var pause_menu: Node = game.pause_menu
	await capture_pause_motion(pause_sample, pause_menu.option_group)
	pause_menu.option_group.activate_option(pause_menu.get_node("Root/Panel/Layout/MenuButtons/Settings"), false)
	await action(&"ui_accept")
	await frames(35)
	check(pause_menu.settings_open and paused, "keyboard opens actual pause settings")
	await shot("pause_settings")
	await key(KEY_ESCAPE)
	await frames(30)
	check(pause_menu.is_open() and not pause_menu.settings_open and paused, "escape returns to pause page without resuming")
	await key(KEY_ESCAPE)
	await frames(10)
	check(not pause_menu.is_open() and not paused, "escape resumes gameplay")
	await key(KEY_ESCAPE)
	await frames(25)
	check(pause_menu.is_open() and paused, "escape reopens pause")
	await click(pause_menu.get_node("Root/Panel/Layout/MenuButtons/ExitToMenu"))
	await frames(100)
	check(not paused and game.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn", "mouse exits pause to the real main menu and releases pause")
	check(game.current_screen.has_node("TerminalMainSample"), "sample reattaches when returning to the main menu")
	review.queue_free()
	await frames(5)
	print("TERMINAL_SAMPLE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
