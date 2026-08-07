extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal continue_requested
signal new_game_requested
signal endless_requested
signal quit_requested

@export var config: DemoConfig

@onready var menu_content: Control = $MenuContent
@onready var button_list: VBoxContainer = $MenuContent/ButtonList
@onready var continue_button: Button = $MenuContent/ButtonList/Continue
@onready var start_button: Button = $MenuContent/ButtonList/Start
@onready var endless_button: Button = $MenuContent/ButtonList/Endless
@onready var settings_button: Button = $MenuContent/ButtonList/Settings
@onready var quit_button: Button = $MenuContent/ButtonList/Quit
@onready var overlay: Control = $Overlay
@onready var overlay_title: Label = $Overlay/Panel/Content/Title
@onready var overlay_message: Label = $Overlay/Panel/Content/Message
@onready var primary_button: Button = $Overlay/Panel/Content/Buttons/Primary
@onready var back_button: Button = $Overlay/Panel/Content/Buttons/Back
@onready var settings_panel: UnifiedSettingsPanel = $Overlay/Panel/Content/SettingsPanel
@onready var footer_link: Control = $FooterLink
@onready var footer_text: Label = $FooterLink/Text
@onready var announcement_window: AnnouncementWindow = $AnnouncementWindow

var has_save := false
var overlay_mode := ""
var buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buttons = [continue_button, start_button, endless_button, settings_button, quit_button, primary_button, back_button]
	button_list.add_theme_constant_override("separation", config.main_menu_button_spacing)
	for button in buttons:
		_style_button(button)
		button.mouse_entered.connect(_on_button_hovered.bind(button))
	continue_button.disabled = not has_save
	continue_button.gui_input.connect(_on_continue_gui_input)
	continue_button.pressed.connect(_on_continue)
	start_button.pressed.connect(_on_start)
	endless_button.pressed.connect(_on_endless)
	settings_button.pressed.connect(_show_settings)
	quit_button.pressed.connect(_show_confirmation.bind("quit"))
	primary_button.pressed.connect(_on_primary)
	back_button.pressed.connect(_return_to_menu)
	footer_text.text = "%s　　%s" % [config.game_version_text, config.community_group_text]
	footer_text.add_theme_font_override("font", PixelFont.get_font())
	footer_text.add_theme_font_size_override("font_size", 11)
	footer_text.add_theme_color_override("font_color", Color("777984"))
	footer_link.mouse_entered.connect(_on_footer_hover.bind(true))
	footer_link.mouse_exited.connect(_on_footer_hover.bind(false))
	footer_link.gui_input.connect(_on_footer_input)
	# 公告窗口：进入主菜单时自动播放淡入动画（内容来自 res://data/announcement.txt）。
	if is_instance_valid(announcement_window):
		announcement_window.closed.connect(_on_announcement_closed)


func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("c9c7ce"))
	button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	button.add_theme_color_override("font_disabled_color", Color("535560"))
	button.add_theme_stylebox_override("normal", _button_box(Color(0.07, 0.08, 0.12, 0.88), Color("3e4350"), 1))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.15, 0.18, 0.23, 0.96), Color("7894a5"), 2))
	button.add_theme_stylebox_override("pressed", _button_box(Color(0.20, 0.24, 0.28, 1.0), Color("9ab6c8"), 2))
	button.add_theme_stylebox_override("disabled", _button_box(Color(0.055, 0.058, 0.075, 0.74), Color("292b34"), 1))


func _button_box(color: Color, border: Color, _width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	# Identical geometry in every state prevents the parent Container from relaying out on hover/press.
	box.border_width_left = 2
	box.border_width_top = 1
	box.border_width_right = 3
	box.border_width_bottom = 2
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _play_confirm() -> void:
	SFX.play_event(&"confirm")


func _on_button_hovered(button: BaseButton) -> void:
	if button.visible and not button.disabled:
		SFX.play_event(&"ui_hover")


func _on_continue_gui_input(event: InputEvent) -> void:
	if continue_button.disabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SFX.play_event(&"forbidden")
		continue_button.accept_event()


func _on_continue() -> void:
	_play_confirm()
	continue_requested.emit()


func _on_start() -> void:
	if has_save:
		_show_confirmation("new_game")
	else:
		_play_confirm()
		new_game_requested.emit()


func _on_endless() -> void:
	_play_confirm()
	endless_requested.emit()


func _show_placeholder(title: String, message: String) -> void:
	_play_confirm()
	overlay_mode = "placeholder"
	overlay_title.text = title
	overlay_message.text = message
	overlay_message.visible = true
	primary_button.visible = false
	settings_panel.visible = false
	back_button.text = "返回"
	menu_content.visible = false
	overlay.visible = true


func _show_settings() -> void:
	_play_confirm()
	overlay_mode = "settings"
	overlay_title.text = "设置 // SETTINGS"
	overlay_message.visible = false
	primary_button.visible = false
	settings_panel.visible = true
	back_button.text = "返回"
	menu_content.visible = false
	overlay.visible = true


func _show_confirmation(mode: String) -> void:
	_play_confirm()
	overlay_mode = mode
	primary_button.visible = true
	settings_panel.visible = false
	overlay_message.visible = true
	if mode == "new_game":
		overlay_title.text = "覆盖存档"
		overlay_message.text = "已有游戏进度。\n开始新游戏会覆盖现有进度。"
		primary_button.text = "开始新游戏"
	else:
		overlay_title.text = "退出游戏"
		overlay_message.text = "确定要退出游戏吗？"
		primary_button.text = "退出"
	back_button.text = "返回"
	menu_content.visible = false
	overlay.visible = true


func _on_primary() -> void:
	_play_confirm()
	primary_button.disabled = true
	back_button.disabled = true
	if overlay_mode == "new_game":
		new_game_requested.emit()
	elif overlay_mode == "quit":
		quit_requested.emit()


func _return_to_menu() -> void:
	_play_confirm()
	overlay.visible = false
	menu_content.visible = true
	overlay_mode = ""
	settings_panel.visible = false
	overlay_message.visible = true
	primary_button.disabled = false
	back_button.disabled = false


func _on_footer_hover(hovered: bool) -> void:
	footer_text.add_theme_color_override("font_color", Color.WHITE if hovered else Color("777984"))
	if hovered:
		SFX.play_event(&"ui_hover")


func _on_footer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var result := OS.shell_open(config.community_group_url)
		if result != OK:
			push_warning("无法打开进度群链接，错误码：%d" % result)
		footer_link.accept_event()


func _on_announcement_closed() -> void:
	# 公告关闭后不阻塞主菜单；需要再次显示时可调用 announcement_window.show_announcement()。
	pass
