extends SceneTree
const OUT := "res://.runtime/screen_wall_static_20261108/"
var menu: Control
var wall: Node3D
var checks := 0
var failures := 0
var captures := {}
var snow_events: Array = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int) -> void:
	for index in count: await process_frame

func quiet(display: Node3D) -> void:
	display.hovering = false
	display.noise_amount = 0.0
	display.option_mix = 0.0
	display._reset_broadcast(false)
	display.signal_wait = 9999.0
	display._process(0.0)

func reception(display: Node3D, style: int, elapsed: float = 0.3) -> void:
	quiet(display)
	display._begin_broadcast()
	display.signal_style = style
	display.signal_hold = 1.0
	display._process(elapsed)

func measure(samples: PackedVector2Array) -> Dictionary:
	var power := 0.0
	var peak := 0.0
	for sample in samples:
		power += sample.length_squared()
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	var rms := sqrt(power / maxf(float(samples.size() * 2), 1.0))
	return {"frames": samples.size(), "rms_dbfs": linear_to_db(maxf(rms, 0.00000001)), "peak_dbfs": linear_to_db(maxf(peak, 0.00000001))}

func run() -> void:
	print("TV_STATIC_AUDIO_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if not AudioServer.is_bus_mute(0) or AudioServer.get_driver_name() != "WASAPI" or not OS.get_user_data_dir().contains("static_user"):
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await frames(4)
	wall = menu.wall_view
	# Hold actual display states while checking the audio, independently of the
	# random schedule and native cursor. The formal-entry regression covers input.
	menu.set_process(false)
	wall.set_process(false)
	wall._set_hovered(null)
	for display in wall.displays:
		display.set_process(false)
		quiet(display)
		display.snow_visibility_changed.connect(func(active: bool): snow_events.append({"screen": display.navigation_order, "active": active, "frame": Engine.get_process_frames()}))
	await frames(3)
	var player: AudioStreamPlayer = menu.snow_audio
	var original_player_id := player.get_instance_id()
	var stream := player.stream as AudioStreamWAV
	check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and absf(stream.get_length() - 4.0) < 0.001, "approved TV-static excerpt is a real loopable audio resource")
	check(not player.playing and menu.snow_displays.is_empty(), "ordinary portrait and fine CRT grain do not play static")
	check(player.bus == &"UI" and player.max_polyphony == 1 and AudioServer.get_bus_send(AudioServer.get_bus_index(&"UI")) == &"SFX", "one static voice uses the existing UI to SFX controls")
	check(menu.ambience_audio.playing and menu.ambience_audio.volume_db <= -30.0, "dream ambience keeps its existing quiet independent playback")
	check(menu.settings_television.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).is_empty(), "static audio is owned by the main menu, not its settings television")
	var ui_bus := AudioServer.get_bus_index(&"UI")
	var tap := AudioEffectCapture.new()
	tap.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(ui_bus)
	AudioServer.add_bus_effect(ui_bus, tap)
	var option: Node3D = wall.displays[6]
	option.set_hovered(true)
	option._process(0.02)
	await frames(3)
	check(option.snow_visible and option.effect.get_shader_parameter("noise_amount") > 0.99 and player.playing, "hover snow starts sound with the actual visible shader state")
	check(is_equal_approx(player.volume_db, -26.0), "static settles at its low minus-26-dB trim")
	tap.clear_buffer()
	await create_timer(0.25).timeout
	captures["snow"] = measure(tap.get_buffer(tap.get_frames_available()))
	check(int(captures.snow.frames) > 5000 and float(captures.snow.rms_dbfs) > -60.0 and float(captures.snow.rms_dbfs) < -35.0 and float(captures.snow.peak_dbfs) < -28.0, "real WASAPI mix contains quiet static before the muted Master")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "hover_snow.png") == OK, "actual game Camera captured during audible-in-data snow")
	option._process(0.4)
	check(not option.snow_visible and option.effect.get_shader_parameter("noise_amount") == 0.0 and not menu.snow_audio_active, "audio release follows snow ending before the option dwell phase finishes")
	await frames(4)
	check(not player.playing, "static player stops after the short anti-click release")
	tap.clear_buffer()
	await create_timer(0.2).timeout
	captures["after_snow"] = measure(tap.get_buffer(tap.get_frames_available()))
	check(float(captures.after_snow.peak_dbfs) < -90.0, "real UI-bus audio returns to silence when snow ends")
	quiet(option)
	var decorative: Array = wall.displays.filter(func(display): return display.action_id.is_empty())
	var first: Node3D = decorative[0]
	var second: Node3D = decorative[1]
	reception(first, first.BroadcastStyle.SNOW)
	await frames(4)
	check(first.snow_visible and first.noise_amount == 0.0 and first.signal_mix == 1.0 and player.playing, "random full-screen snow plays even when hover noise is zero")
	var before_overlap := player.get_playback_position()
	reception(second, second.BroadcastStyle.SNOW)
	await frames(3)
	check(menu.snow_displays.size() == 2 and player.get_instance_id() == original_player_id and player.get_playback_position() >= before_overlap, "overlapping snow shares one continuing voice without restart or stacking")
	check(is_equal_approx(player.volume_db, -26.0) and root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).size() == 1, "multiple televisions retain the same low volume")
	first._process(2.0)
	await frames(3)
	check(not first.snow_visible and second.snow_visible and player.playing and menu.snow_displays.size() == 1, "one television ending does not silence another snowy television")
	second._process(2.0)
	await frames(4)
	check(not player.playing and menu.snow_displays.is_empty(), "last timed snow ending stops the shared sound")
	reception(first, first.BroadcastStyle.COLOR_BARS, 0.02)
	await frames(3)
	check(first.signal_noise > 0.0 and first.signal_mix == 1.0 and not first.snow_visible and not player.playing, "color bars masking transient noise do not falsely trigger snow audio")
	quiet(first)
	option._begin_broadcast()
	option.signal_hold = 1.0
	option._process(0.02)
	await frames(3)
	check(option.signal_style == option.BroadcastStyle.OPTION and option.signal_noise > 0.0 and option.snow_visible and player.playing, "visible snow in the ambient option flicker also triggers sound")
	option._process(0.05)
	await frames(4)
	check(option.signal_noise == 0.0 and not option.snow_visible and not player.playing, "clean ambient option text stops the snow sound")
	quiet(option)
	reception(first, first.BroadcastStyle.SNOW)
	await frames(3)
	menu._show_settings()
	check(menu.snow_audio_suspended and not player.playing and wall.process_mode == Node.PROCESS_MODE_DISABLED, "opening settings immediately stops snow behind the disabled wall")
	check(menu.ambience_audio.playing, "settings retains the separate dream ambience")
	menu._close_settings_television()
	await frames(4)
	check(first.snow_visible and not menu.snow_audio_suspended and player.playing, "closing settings resumes sound only if the restored wall still shows snow")
	quiet(first)
	await frames(4)
	menu._show_settings()
	menu._close_settings_television()
	await frames(4)
	check(not player.playing and menu.snow_displays.is_empty(), "closing settings on a clean wall stays quiet")
	for index in 8:
		reception(first, first.BroadcastStyle.SNOW)
		quiet(first)
	reception(first, first.BroadcastStyle.SNOW)
	await frames(4)
	check(player.playing and menu.snow_displays.size() == 1 and is_equal_approx(player.volume_db, -26.0), "rapid transitions cancel stale stop callbacks and recover one quiet voice")
	first.power_off()
	await frames(4)
	check(not first.snow_visible and not player.playing, "a powered-off snowy television stops its sound immediately")
	reception(second, second.BroadcastStyle.SNOW)
	await frames(3)
	for display in wall.displays:
		display.set_process(true)
	await wall.play_shutdown()
	await frames(4)
	check(wall.displays.all(func(display): return display.powered_off) and menu.snow_displays.is_empty() and not player.playing, "complete television shutdown leaves no static audio")
	AudioServer.remove_bus_effect(ui_bus, effect_index)
	var player_ref: WeakRef = weakref(player)
	menu.queue_free()
	await frames(5)
	check(player_ref.get_ref() == null and root.find_children("ScreenSnowAudio", "AudioStreamPlayer", true, false).is_empty(), "leaving the main menu frees the static voice")
	check(AudioServer.is_bus_mute(0), "private Master mute retained throughout all actual audio checks")
	var result := {"pid": OS.get_process_id(), "checks": checks, "failures": failures, "audio": AudioServer.get_driver_name(), "master_muted": AudioServer.is_bus_mute(0), "captures": captures, "snow_events": snow_events, "scope": "formal main-menu scene, actual snow/hover/overlap/settings/shutdown lifecycle and WASAPI data capture; no speaker audition or performance claim"}
	var file := FileAccess.open(OUT + "static_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	print("TV_STATIC_RESULT checks=", checks, " failures=", failures, " exit=", 1 if failures else 0)
	quit(1 if failures else 0)
