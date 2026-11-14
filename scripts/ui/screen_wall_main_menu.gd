extends "res://scripts/ui/main_menu.gd"
## Reuse the established menu/state/confirmation controller with the 3D view.
const WALL_SCENE := preload("res://scenes/preview/screen_wall_review.tscn")
const WALL_FONT := preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const SETTINGS_TELEVISION := preload("res://scenes/ui/pause_menu.tscn")
const AMBIENCE_STREAM := preload("res://sfx/preview/screen_wall_ambience.res")
const AMBIENCE_VOLUME_DB := -30.0
const AMBIENCE_FADE_IN_SECONDS := 2.0
const AMBIENCE_FADE_OUT_SECONDS := 1.2
const SNOW_STREAM := preload("res://sfx/preview/screen_wall_static.res")
const SNOW_VOLUME_DB := -26.0
const SNOW_EDGE_SECONDS := 0.012
var wall_view: Node3D
var wall_viewport: SubViewport
var wall_texture: TextureRect
var launching_game := false
var settings_television: CanvasLayer
var saved_wall_update_mode := SubViewport.UPDATE_ALWAYS
var saved_wall_process_mode := Node.PROCESS_MODE_ALWAYS
var ambience_audio: AudioStreamPlayer
var ambience_tween: Tween
var snow_audio: AudioStreamPlayer
var snow_audio_tween: Tween
var snow_displays: Dictionary = {}
var snow_audio_active := false
var snow_audio_suspended := false

func _ready() -> void:
	super._ready()
	$Background.hide()
	$HomeScreenVisual.hide()
	$GameTitle.hide()
	menu_content.hide()
	menu_option_group.set_process(false)
	wall_viewport = SubViewport.new()
	wall_viewport.name = "ScreenWallViewport"
	wall_viewport.own_world_3d = true
	wall_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(wall_viewport)
	wall_texture = TextureRect.new()
	wall_texture.name = "ScreenWallBackground"
	wall_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall_texture.texture = wall_viewport.get_texture()
	add_child(wall_texture)
	move_child(wall_texture, 0)
	_resize_wall()
	wall_view = WALL_SCENE.instantiate()
	wall_view.preview_only = false
	wall_view.show_footer = false
	wall_view.interaction_scale = float(wall_viewport.size.x) / maxf(size.x, 1.0)
	wall_view.menu_requested.connect(_on_wall_action)
	wall_view.disabled_menu_requested.connect(func(_id: StringName): SFX.play_event(&"forbidden"))
	wall_viewport.add_child(wall_view)
	wall_view.set_option_enabled(&"continue", has_save)
	resized.connect(_resize_wall)
	get_viewport().size_changed.connect(_resize_wall)
	footer_link.position = Vector2(0, 344)
	footer_link.size = Vector2(640, 14)
	footer_link.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for label in [version_label, group_label]:
		label.add_theme_font_override("font", WALL_FONT)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color("5e686d"))
	_layout_footer()
	settings_television=SETTINGS_TELEVISION.instantiate()
	settings_television.name="MainMenuSettingsTelevision"
	settings_television.settings_only=true
	settings_television.resume_requested.connect(_close_settings_television)
	add_child(settings_television)
	_start_ambience()
	_setup_snow_audio()

func _setup_snow_audio() -> void:
	snow_audio = AudioStreamPlayer.new()
	snow_audio.name = "ScreenSnowAudio"
	snow_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	snow_audio.stream = SNOW_STREAM
	snow_audio.bus = &"UI"
	snow_audio.max_polyphony = 1
	snow_audio.volume_db = -70.0
	add_child(snow_audio)
	for display in wall_view.displays:
		display.snow_visibility_changed.connect(_on_snow_visibility_changed.bind(display.get_instance_id()))
		_on_snow_visibility_changed(display.snow_visible, display.get_instance_id())

func _on_snow_visibility_changed(active: bool, display_id: int) -> void:
	if active:
		snow_displays[display_id] = true
	else:
		snow_displays.erase(display_id)
	_sync_snow_audio()

func _sync_snow_audio() -> void:
	var active := not snow_audio_suspended and not snow_displays.is_empty()
	if active == snow_audio_active:
		return
	snow_audio_active = active
	if snow_audio_tween != null and snow_audio_tween.is_valid():
		snow_audio_tween.kill()
	snow_audio_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if active:
		# Overlapping televisions share one continuous voice at the same low gain.
		if not snow_audio.playing:
			snow_audio.volume_db = -70.0
			snow_audio.play()
		snow_audio_tween.tween_property(snow_audio, "volume_db", SNOW_VOLUME_DB, SNOW_EDGE_SECONDS)
	else:
		snow_audio_tween.tween_property(snow_audio, "volume_db", -70.0, SNOW_EDGE_SECONDS)
		snow_audio_tween.tween_callback(snow_audio.stop)

func _suspend_snow_audio(suspended: bool) -> void:
	snow_audio_suspended = suspended
	if suspended:
		if snow_audio_tween != null and snow_audio_tween.is_valid(): snow_audio_tween.kill()
		snow_audio.stop()
		snow_audio_active = false
	else:
		_sync_snow_audio()

func _start_ambience() -> void:
	ambience_audio = AudioStreamPlayer.new()
	ambience_audio.name = "MenuAmbience"
	# Keep the bed running while the settings television pauses its 3D view.
	ambience_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	ambience_audio.stream = AMBIENCE_STREAM
	# Like weather ambience, use the existing unprocessed SFX route so gameplay
	# time-scale/low-pass effects cannot carry over into the menu's drone.
	ambience_audio.bus = &"SFX"
	ambience_audio.max_polyphony = 1
	ambience_audio.volume_db = -70.0
	add_child(ambience_audio)
	ambience_audio.play()
	ambience_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_tween.tween_property(ambience_audio, "volume_db", AMBIENCE_VOLUME_DB, AMBIENCE_FADE_IN_SECONDS)

func _fade_out_ambience() -> void:
	if ambience_tween != null and ambience_tween.is_valid():
		ambience_tween.kill()
	ambience_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_tween.tween_property(ambience_audio, "volume_db", -70.0, AMBIENCE_FADE_OUT_SECONDS)
	ambience_tween.tween_callback(ambience_audio.stop)

func _resize_wall() -> void:
	if wall_viewport == null:
		return
	var scale_factor := get_viewport().get_final_transform().get_scale().abs()
	wall_viewport.size = Vector2i((size * scale_factor).round()).max(Vector2i(2, 2))
	if wall_view != null:
		wall_view.interaction_scale = float(wall_viewport.size.x) / maxf(size.x, 1.0)

func _process(_delta: float) -> void:
	if wall_view == null:
		return
	wall_view.set_interaction_enabled(not launching_game and not overlay.visible and not announcement_window.visible and not _settings_are_open())
	wall_view.set_option_enabled(&"continue", has_save)

func _input(event: InputEvent) -> void:
	if wall_view == null:
		return
	if _settings_are_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			consume_escape()
			get_viewport().set_input_as_handled()
		return
	if launching_game:
		if event is InputEventMouseMotion:
			_forward_wall_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not announcement_window.visible:
		consume_escape()
		get_viewport().set_input_as_handled()
		return
	var blocked := overlay.visible or announcement_window.visible
	if blocked and not event is InputEventMouseMotion:
		return
	if not (event is InputEventMouse or event is InputEventKey):
		return
	_forward_wall_input(event)

func _forward_wall_input(event: InputEvent) -> void:
	var copy := event.duplicate() as InputEvent
	if copy is InputEventMouse:
		copy.position = (event.position - global_position) * Vector2(wall_viewport.size) / size
		copy.global_position = copy.position
	wall_viewport.push_input(copy, true)
	if wall_viewport.is_input_handled():
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if launching_game or _settings_are_open():
		return
	if overlay.visible or announcement_window.visible:
		super._unhandled_input(event)

func _on_wall_action(action: StringName) -> void:
	if launching_game:
		return
	match action:
		&"continue":
			if has_save: _on_continue()
			else: SFX.play_event(&"forbidden")
		&"new_game": _on_start()
		&"settings": _show_settings()
		&"quit": _show_confirmation("quit")

func _on_continue() -> void:
	if has_save:
		_begin_game_after_shutdown(&"continue")

func _on_start() -> void:
	if launching_game:
		return
	if has_save:
		_show_confirmation("new_game")
	else:
		_begin_game_after_shutdown(&"new_game")

func _on_primary() -> void:
	if launching_game:
		return
	if overlay_mode == "new_game":
		_begin_game_after_shutdown(&"new_game")
	else:
		super._on_primary()

func _begin_game_after_shutdown(action: StringName) -> void:
	if launching_game:
		return
	launching_game = true
	_fade_out_ambience()
	primary_button.disabled = true
	back_button.disabled = true
	_kill_page_tween()
	overlay.hide()
	_page_tween = create_tween()
	_page_tween.tween_property(footer_link, "modulate:a", 0.0, 0.12)
	await wall_view.play_shutdown()
	ambience_audio.stop()
	_suspend_snow_audio(true)
	wall_texture.modulate = Color.BLACK
	if action == &"continue":
		continue_requested.emit()
	else:
		new_game_requested.emit()

func consume_escape() -> bool:
	if launching_game:
		return true
	if _settings_are_open():
		settings_television.handle_escape()
		return true
	return super.consume_escape()

func _settings_are_open() -> bool:
	return settings_television!=null and settings_television.is_open()

func _show_settings() -> void:
	if launching_game or _settings_are_open(): return
	_play_confirm()
	_kill_page_tween()
	overlay.hide()
	settings_panel.hide()
	overlay_mode="settings"
	wall_view.set_interaction_enabled(false)
	wall_view.hover_audio.stop()
	if wall_view.hover_audio_tween!=null and wall_view.hover_audio_tween.is_valid(): wall_view.hover_audio_tween.kill()
	_suspend_snow_audio(true)
	saved_wall_update_mode=wall_viewport.render_target_update_mode
	saved_wall_process_mode=wall_view.process_mode
	wall_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	wall_view.process_mode=Node.PROCESS_MODE_DISABLED
	settings_television.open_settings_page()

func _close_settings_television() -> void:
	settings_television.close_pause()
	overlay_mode=""
	wall_view.process_mode=saved_wall_process_mode
	wall_viewport.render_target_update_mode=saved_wall_update_mode
	wall_view.set_interaction_enabled(true)
	_suspend_snow_audio(false)

func _return_to_menu() -> void:
	if _settings_are_open():
		_close_settings_television()
	else:
		super._return_to_menu()

func _tween_to_overlay() -> void:
	_kill_page_tween()
	menu_content.hide()
	overlay.show()
	overlay.modulate.a = 0.0
	if wall_view != null: wall_view.set_interaction_enabled(false)
	_page_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(overlay, "modulate:a", 1.0, PAGE_TWEEN_SECONDS)

func _tween_to_menu() -> void:
	_kill_page_tween()
	menu_content.hide()
	_page_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(overlay, "modulate:a", 0.0, PAGE_TWEEN_SECONDS)
	_page_tween.tween_callback(func() -> void:
		overlay.hide()
		overlay.modulate.a = 1.0
		if wall_view != null: wall_view.set_interaction_enabled(true)
	)

func _layout_footer() -> void:
	if wall_view == null:
		super._layout_footer()
		return
	var a := WALL_FONT.get_string_size(version_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var b := WALL_FONT.get_string_size(group_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var gap := WALL_FONT.get_string_size("    ", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var start := (640.0 - a - b - gap) * 0.5
	version_label.position = Vector2(start, 0)
	version_label.size = Vector2(a, 14)
	group_label.position = Vector2(start + a + gap, 0)
	group_label.size = Vector2(b, 14)

func _on_footer_label_hover(label: Label, hovered: bool) -> void:
	label.add_theme_color_override("font_color", Color("a7d7d8") if hovered else Color("5e686d"))
	if hovered: SFX.play_event(&"watch_tick")

func _exit_tree() -> void:
	_kill_page_tween()
	if ambience_tween != null and ambience_tween.is_valid(): ambience_tween.kill()
	if is_instance_valid(ambience_audio): ambience_audio.stop()
	if snow_audio_tween != null and snow_audio_tween.is_valid(): snow_audio_tween.kill()
	if is_instance_valid(snow_audio): snow_audio.stop()
	snow_displays.clear()
	if is_instance_valid(settings_television) and settings_television.is_open(): settings_television.close_pause()
