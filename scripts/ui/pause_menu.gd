class_name GlobalPauseMenu
extends CanvasLayer

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal resume_requested
signal exit_to_main_menu_requested

@onready var root: Control = $Root
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
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_entered.connect(_play_hover.bind(button))
	resume_button.pressed.connect(_request_resume)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(_request_exit)
	settings_back.pressed.connect(_close_settings)


func open_pause() -> void:
	if root.visible:
		return
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_open = false
	_sync_page()
	root.visible = true


func close_pause() -> void:
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
	title.text = "设置 // SETTINGS" if settings_open else "暂停 // PAUSED"
	menu_buttons.visible = not settings_open
	settings_panel.visible = settings_open
	settings_back.visible = settings_open


func _play_hover(button: BaseButton) -> void:
	if button.visible and not button.disabled:
		SFX.play_event(&"ui_hover")
