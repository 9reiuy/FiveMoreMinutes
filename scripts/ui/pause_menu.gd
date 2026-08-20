class_name GlobalPauseMenu
extends CanvasLayer

const SFX := preload("res://scripts/audio/sfx_manager.gd")
# 纯文字选项配色（与主菜单统一）：无底框/描边，悬停仅变亮。
const TEXT_COLOR := Color("374c4d")
const TEXT_HOVER_COLOR := Color("8fb3bc")
const TEXT_DISABLED_COLOR := Color("223032")

signal resume_requested
signal exit_to_main_menu_requested

@onready var root: Control = $Root
@onready var option_group: PixelOptionGroup = $Root/PauseOptionGroup
@onready var title: Label = $Root/Panel/Layout/Title
@onready var menu_buttons: VBoxContainer = $Root/Panel/Layout/MenuButtons
@onready var settings_panel: UnifiedSettingsPanel = $Root/Panel/Layout/SettingsPanel
@onready var settings_back: Button = $Root/Panel/Layout/SettingsBack

var settings_open := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	var resume_button: Button = $Root/Panel/Layout/MenuButtons/Resume
	var settings_button: Button = $Root/Panel/Layout/MenuButtons/Settings
	var exit_button: Button = $Root/Panel/Layout/MenuButtons/ExitToMenu
	for button in [resume_button, settings_button, exit_button, settings_back]:
		_style_text_button(button)
	option_group.register_options([resume_button, settings_button, exit_button, settings_back])
	resume_button.pressed.connect(_request_resume)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(_request_exit)
	settings_back.pressed.connect(_close_settings)


func _style_text_button(button: Button) -> void:
	# 纯文字按钮：删除像素底框，最细字重单次绘制，悬停只变色。
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
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
	_sync_page()
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


func _sync_page() -> void:
	option_group.clear_highlight()
	title.text = "设置 // SETTINGS" if settings_open else "暂停 // PAUSED"
	menu_buttons.visible = not settings_open
	settings_panel.visible = settings_open
	settings_back.visible = settings_open
