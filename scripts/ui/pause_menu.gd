class_name GlobalPauseMenu
extends CanvasLayer

const SFX := preload("res://scripts/audio/sfx_manager.gd")
# NieR list：与主菜单统一 #396FE2 实心选中反色。
const TEXT_COLOR := Color("396fe2")
const TEXT_HOVER_COLOR := Color("396fe2")
const TEXT_DISABLED_COLOR := Color("264586")
const SELECTED_TEXT_COLOR := Color("f2efe6")  # cream on accent fill
const PAGE_TWEEN_SECONDS := 0.20

signal resume_requested
signal exit_to_main_menu_requested

@onready var root: Control = $Root
@onready var option_group: PixelOptionGroup = $Root/PauseOptionGroup
@onready var title: Label = $Root/Panel/Layout/Title
@onready var menu_buttons: VBoxContainer = $Root/Panel/Layout/MenuButtons
@onready var settings_panel: Control = $Root/Panel/Layout/SettingsPanel
@onready var settings_back: Button = $Root/Panel/Layout/SettingsBack

var settings_open := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _page_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	var resume_button: Button = $Root/Panel/Layout/MenuButtons/Resume
	var settings_button: Button = $Root/Panel/Layout/MenuButtons/Settings
	var exit_button: Button = $Root/Panel/Layout/MenuButtons/ExitToMenu
	for button in [resume_button, settings_button, exit_button, settings_back]:
		_style_text_button(button)
	option_group.solid_fill = true
	option_group.show_selection_frame = false
	option_group.enable_hover_scale = false
	option_group.selected_text_color = SELECTED_TEXT_COLOR
	option_group.unselected_text_color = TEXT_COLOR
	option_group.option_frame_spring_duration = 0.12
	option_group.option_frame_spring_start_scale = 0.20
	option_group.option_frame_spring_overshoot = 1.20
	option_group.option_text_spring_start_scale = 0.82
	option_group.option_text_spring_overshoot = 1.12
	option_group.register_options([resume_button, settings_button, exit_button, settings_back])
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_back.pressed.connect(_on_settings_back_pressed)


func _style_text_button(button: Button) -> void:
	# 纯文字按钮：删除像素底框，最细字重单次绘制，悬停只变色。
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_HOVER_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_HOVER_COLOR)
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED_COLOR)


func open_pause() -> void:
	if root.visible:
		return
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_open = false
	option_group.clear_highlight()
	_sync_page(false)
	root.visible = true


func close_pause() -> void:
	option_group.clear_highlight()
	root.visible = false
	settings_open = false
	Input.mouse_mode = previous_mouse_mode


func is_open() -> bool:
	return root.visible


func handle_escape() -> void:
	if settings_open:
		_close_settings()
	else:
		_request_resume()



func _await_pause_spring() -> void:
	await option_group.wait_confirm_spring()


func _on_resume_pressed() -> void:
	await _await_pause_spring()
	_request_resume()


func _on_settings_pressed() -> void:
	await _await_pause_spring()
	_open_settings()


func _on_exit_pressed() -> void:
	await _await_pause_spring()
	_request_exit()


func _on_settings_back_pressed() -> void:
	await _await_pause_spring()
	_close_settings()


func _request_resume() -> void:
	SFX.play_event(&"confirm")
	resume_requested.emit()


func _open_settings() -> void:
	SFX.play_event(&"confirm")
	settings_open = true
	_sync_page()


func _close_settings() -> void:
	SFX.play_event(&"confirm")
	settings_open = false
	_sync_page()


func _request_exit() -> void:
	SFX.play_event(&"confirm")
	exit_to_main_menu_requested.emit()


func _sync_page(animate: bool = true) -> void:
	option_group.clear_highlight()
	title.text = "设置" if settings_open else "暂停"
	if animate and root.visible:
		_tween_page_swap(settings_open)
	else:
		_snap_page()


func _snap_page() -> void:
	_kill_page_tween()
	menu_buttons.visible = not settings_open
	menu_buttons.modulate.a = 1.0
	settings_panel.visible = settings_open
	settings_panel.modulate.a = 1.0
	settings_back.visible = settings_open
	settings_back.modulate.a = 1.0


func _kill_page_tween() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_tween = null


func _tween_page_swap(to_settings: bool) -> void:
	_kill_page_tween()
	var outgoing: Control = menu_buttons if to_settings else settings_panel
	var incoming: Control = settings_panel if to_settings else menu_buttons
	outgoing.visible = true
	incoming.visible = true
	outgoing.modulate.a = 1.0
	incoming.modulate.a = 0.0
	settings_back.visible = true
	if to_settings:
		settings_back.modulate.a = 0.0
	_page_tween = create_tween()
	_page_tween.set_parallel(true)
	_page_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(outgoing, "modulate:a", 0.0, PAGE_TWEEN_SECONDS)
	_page_tween.tween_property(incoming, "modulate:a", 1.0, PAGE_TWEEN_SECONDS)
	if to_settings:
		_page_tween.tween_property(settings_back, "modulate:a", 1.0, PAGE_TWEEN_SECONDS)
	else:
		_page_tween.tween_property(settings_back, "modulate:a", 0.0, PAGE_TWEEN_SECONDS * 0.75)
	_page_tween.chain().tween_callback(func() -> void:
		outgoing.visible = false
		outgoing.modulate.a = 1.0
		settings_back.visible = to_settings
		settings_back.modulate.a = 1.0
		if not to_settings:
			var opts := option_group.get_selectable_options()
			if not opts.is_empty():
				option_group.activate_option(opts[0], false)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not root.visible:
		return
	if settings_open and settings_panel is UnifiedSettingsPanel:
		var settings := settings_panel as UnifiedSettingsPanel
		if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
			settings.activate_row_delta(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
			settings.activate_row_delta(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
			if settings.trigger_active_row() or option_group.trigger_active():
				get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		option_group.activate_delta(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		option_group.activate_delta(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		if option_group.trigger_active():
			get_viewport().set_input_as_handled()
