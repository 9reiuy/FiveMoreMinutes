extends SceneTree
## Formal entry lifecycle, real save routing and shared focus budget.
var OUT := "res://.runtime/screen_wall_menu_promotion_20261107/"
const SAVE := preload("res://scripts/app/game_save_store.gd")
var main: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			OUT = arg.trim_prefix("--output-dir=").trim_suffix("/") + "/"
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
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)

func choose(index: int) -> void:
	var menu: Control = main.current_screen
	var display: Node3D = menu.wall_view.displays[index]
	var projected: Vector2 = menu.wall_view.camera.unproject_position(display.chassis.to_global(Vector3(0, 0, 0.04)))
	var point := projected / Vector2(menu.wall_viewport.size) * menu.size
	pointer(point)
	await frames(34)
	await click(point)

func wait_for_screen(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(main.current_screen) and main.current_screen.scene_file_path == path and not main.transition_running:
			await frames(6)
			return true
	return false

func approved_avatar_present() -> bool:
	var wall: Node3D = main.current_screen.get("wall_view")
	if wall == null:
		return false
	var avatar: Node3D = wall.get("avatar")
	return avatar != null and avatar.scene_file_path == "res://art/preview/screen_wall/avatar/screen_wall_avatar.tscn" and avatar.get_node_or_null("Geometry") != null

func ambience_players() -> Array[Node]:
	return root.find_children("MenuAmbience", "AudioStreamPlayer", true, false)

func exit_pause_to_menu() -> void:
	if main.pause_menu.has_method("option_screen_position"):
		while main.pause_menu.wall_view.entering: await process_frame
		await click(main.pause_menu.option_screen_position(&"exit_to_menu"))
	else:
		await click(main.pause_menu.get_node("Root/Panel/Layout/MenuButtons/ExitToMenu").get_global_rect().get_center())

func run() -> void:
	print("MAIN_MENU_ENTRY_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "Dummy" or not AudioServer.is_bus_mute(0) or not OS.get_user_data_dir().contains("formal_user"):
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var budget := root.get_node("FrameBudget")
	check(budget.enabled and budget.startup_limit == 60, "global budget enabled with the project default")
	root.focus_entered.emit()
	check(Engine.max_fps == 60, "window focus applies 60 FPS")
	SAVE.clear_game()
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await frames(65)
	check(main.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn" and main.current_screen.wall_view.displays.size() == 12, "formal app entry now loads the television menu")
	check(approved_avatar_present(), "formal menu loads the approved permanent avatar scene")
	var initial_ambience: AudioStreamPlayer = main.current_screen.ambience_audio
	var initial_ambience_id := initial_ambience.get_instance_id()
	var ambience_stream := initial_ambience.stream as AudioStreamOggVorbis
	check(ambience_stream != null and absf(ambience_stream.get_length() - 607.988) < 0.01 and ambience_stream.loop and ambience_stream.loop_offset == 0.0, "menu ambience retains and loops the complete 10-minute recording")
	check(initial_ambience.playing and initial_ambience.bus == &"SFX" and initial_ambience.volume_db <= -30.0 and initial_ambience.pitch_scale == 1.0 and ambience_players().size() == 1, "one quiet menu bed uses the existing unprocessed sound-effects bus")
	var initial_snow: AudioStreamPlayer = main.current_screen.snow_audio
	var initial_snow_id := initial_snow.get_instance_id()
	check(initial_snow.bus == &"UI" and root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).size() == 1, "formal menu owns one snow-synchronised UI audio voice")
	check(not main.pause_allowed and not main.current_screen.has_save, "fresh profile keeps menu and save rules")
	await key(KEY_ESCAPE)
	await frames(20)
	check(main.current_screen.overlay_mode == "settings" and main.current_screen.settings_television.is_open() and not main.pause_menu.is_open(), "formal Escape opens television settings exactly once")
	check(initial_ambience.playing and initial_ambience.can_process() and not initial_ambience.stream_paused and ambience_players().size() == 1, "settings keeps the same ambience playing while the television wall is disabled")
	var settings := root.get_node("SettingsManager")
	settings.set_volume(&"sfx_volume", 25)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))), 0.25) and AudioServer.is_bus_mute(0), "existing sound-effects volume controls the bed while private Master remains muted")
	settings.set_volume(&"sfx_volume", 0)
	await key(KEY_ESCAPE)
	await frames(24)
	check(not main.current_screen.settings_television.is_open(), "formal Escape closes television settings")
	await create_timer(2.1).timeout
	check(is_equal_approx(initial_ambience.volume_db, -30.0), "ambience fade-in settles at the requested very low gain")
	initial_ambience.seek(607.9)
	await create_timer(0.3).timeout
	check(initial_ambience.playing and initial_ambience.get_playback_position() < 1.0, "end of the full recording wraps and continues playing")
	root.focus_exited.emit()
	check(Engine.max_fps == 30, "unfocused formal menu applies 30 FPS")
	root.focus_entered.emit()
	check(Engine.max_fps == 60, "focus restores 60 FPS")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "formal_menu.png") == OK, "formal Camera capture")
	var old_wall_id: int = main.current_screen.wall_view.get_instance_id()
	await choose(6)
	check(main.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn" and main.current_screen.launching_game and not SAVE.has_valid_save(), "new-game save and scene creation wait for the closing televisions")
	check(initial_ambience.volume_db < -30.0, "entering the game fades the menu ambience with the shutdown sequence")
	if not await wait_for_screen("res://scenes/ui/opening.tscn"):
		check(false, "new game enters the established opening")
		quit(1)
		return
	check(true, "new game enters the established opening")
	check(SAVE.has_valid_save(), "new game creates a valid private save through the existing store")
	check(not is_instance_id_valid(old_wall_id), "television world freed after entering the game")
	check(not is_instance_id_valid(initial_ambience_id) and ambience_players().is_empty(), "new game frees the ambience player and leaves no menu bed in gameplay")
	check(not is_instance_id_valid(initial_snow_id) and root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).is_empty(), "new game frees the snow voice without leaking static into gameplay")
	check(Engine.max_fps == 60, "foreground cap persists outside the menu")
	await key(KEY_ESCAPE)
	await frames(4)
	check(main.pause_menu.is_open() and paused, "existing pause menu still opens in game")
	root.focus_exited.emit()
	check(Engine.max_fps == 30 and budget.can_process(), "background cap remains active while gameplay is paused")
	root.focus_entered.emit()
	check(Engine.max_fps == 60, "paused foreground restores 60 FPS")
	await exit_pause_to_menu()
	if not await wait_for_screen("res://scenes/ui/main_menu.tscn"):
		check(false, "pause Exit returns to the formal television menu")
		quit(1)
		return
	check(not paused and main.current_screen.has_save, "pause Exit returns to an enabled Continue and clears pause")
	check(ambience_players().size() == 1 and main.current_screen.ambience_audio.playing, "returning from gameplay starts exactly one ambience player")
	check(root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).size() == 1, "return to menu recreates exactly one snow voice")
	check(main.current_screen.wall_view.displays[0].option_enabled, "real saved profile enables the Continue television")
	await choose(0)
	check(main.current_screen.scene_file_path == "res://scenes/ui/main_menu.tscn" and main.current_screen.launching_game, "Continue waits for the closing televisions before loading 3D")
	if not await wait_for_screen("res://scenes/dream/preview/SelectivePixelPreview.tscn"):
		check(false, "Continue restores saved 3D gameplay")
		quit(1)
		return
	check(is_instance_valid(main._supported_dream_world), "Continue restores saved 3D gameplay")
	check(ambience_players().is_empty(), "Continue also removes the menu ambience from gameplay")
	check(root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).is_empty(), "Continue also removes all menu snow voices")
	check(Engine.max_fps == 60, "cap persists in 3D gameplay")
	await key(KEY_ESCAPE)
	await frames(4)
	check(main.pause_menu.is_open(), "existing pause opens after Continue")
	await exit_pause_to_menu()
	check(await wait_for_screen("res://scenes/ui/main_menu.tscn"), "second gameplay return restores the television menu")
	check(approved_avatar_present(), "returning from gameplay restores the approved avatar")
	check(ambience_players().size() == 1 and main.current_screen.ambience_audio.playing, "repeated menu returns keep one bed without stacking")
	check(root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).size() == 1, "repeated menu returns do not stack snow voices")
	check(AudioServer.is_bus_mute(0), "private mute retained across the full lifecycle")
	root.focus_exited.emit()
	check(Engine.max_fps == 30, "menu reload keeps the global background cap")
	var file := FileAccess.open(OUT + "formal_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "checks": checks, "failures": failures,
		"audio": AudioServer.get_driver_name(), "save_path": OS.get_user_data_dir(),
		"scope": "formal menu/new game/private save/Continue/3D/pause/return lifecycle, not full-game certification"}, "\t"))
	file.close()
	# The native cursor also retains these two dynamically built textures.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	main.queue_free()
	await frames(5)
	print("MAIN_MENU_ENTRY_RESULT checks=", checks, " failures=", failures, " exit=", 1 if failures else 0)
	quit(1 if failures else 0)
