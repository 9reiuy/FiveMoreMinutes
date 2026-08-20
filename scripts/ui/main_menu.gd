extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal continue_requested
signal new_game_requested
signal endless_requested
signal global_progress_changed
signal quit_requested

@export var config: DemoConfig

@onready var menu_content: Control = $MenuContent
@onready var menu_option_group: PixelOptionGroup = $MenuContent/MenuSelectionFrame
@onready var button_list: VBoxContainer = $MenuContent/ButtonList
@onready var continue_button: Button = $MenuContent/ButtonList/Continue
@onready var start_button: Button = $MenuContent/ButtonList/Start
@onready var endless_button: Button = $MenuContent/ButtonList/Endless
@onready var somnia_button: Button = $MenuContent/ButtonList/Somnia
@onready var quit_button: Button = $MenuContent/ButtonList/Quit
@onready var overlay: Control = $Overlay
@onready var overlay_option_group: PixelOptionGroup = $Overlay/OverlayOptionGroup
@onready var overlay_title: Label = $Overlay/Panel/Content/Title
@onready var overlay_message: Label = $Overlay/Panel/Content/Message
@onready var primary_button: Button = $Overlay/Panel/Content/Buttons/Primary
@onready var back_button: Button = $Overlay/Panel/Content/Buttons/Back
@onready var settings_panel: UnifiedSettingsPanel = $Overlay/Panel/Content/SettingsPanel
@onready var global_upgrade_panel: Control = $Overlay/Panel/Content/GlobalUpgradePanel
@onready var footer_link: Control = $FooterLink
@onready var version_label: Label = $FooterLink/VersionText
@onready var group_label: Label = $FooterLink/GroupText
@onready var announcement_window: AnnouncementWindow = $AnnouncementWindow

var has_save := false
var overlay_mode := ""
var progression_state: Dictionary = {}

# 主菜单选项纯文字配色：默认 #374C4D，悬停变亮。
const MENU_ENTRY_COLOR := Color("374c4d")
const MENU_ENTRY_HOVER_COLOR := Color("8fb4b5")
const MENU_ENTRY_DISABLED_COLOR := Color("233031")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	button_list.add_theme_constant_override("separation", config.main_menu_button_spacing)
	for entry in [continue_button, start_button, endless_button, somnia_button, quit_button]:
		_style_menu_entry(entry)
	for overlay_button in [primary_button, back_button]:
		_style_button(overlay_button)
	continue_button.disabled = not has_save
	menu_option_group.register_options([continue_button, start_button, endless_button, somnia_button, quit_button])
	overlay_option_group.register_options([primary_button, back_button])
	continue_button.gui_input.connect(_on_continue_gui_input)
	continue_button.pressed.connect(_on_continue)
	start_button.pressed.connect(_on_start)
	endless_button.pressed.connect(_on_endless)
	somnia_button.pressed.connect(_show_somnia)
	quit_button.pressed.connect(_show_confirmation.bind("quit"))
	primary_button.pressed.connect(_on_primary)
	back_button.pressed.connect(_return_to_menu)
	global_upgrade_panel.progression_changed.connect(_on_global_progress_changed)
	global_upgrade_panel.configure(progression_state)
	# 底栏拆为两个独立点击区：版本号（Hover 变亮 + 点击开全屏公告）
	# 与进度群号（保留原有群链接），两者不重叠。
	footer_link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_footer_label(version_label, config.game_version_text, _on_version_clicked)
	_setup_footer_label(group_label, config.community_group_text, _on_group_clicked)
	_layout_footer()
	# 公告不再进入主菜单自动弹出；打开入口为版本号点击 show_announcement()。
	if is_instance_valid(announcement_window):
		announcement_window.closed.connect(_on_announcement_closed)


func _style_menu_entry(button: Button) -> void:
	# 纯文字选项：无按钮底框，悬停时颜色变亮并轻微放大。
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", MENU_ENTRY_COLOR)
	button.add_theme_color_override("font_hover_color", MENU_ENTRY_HOVER_COLOR)
	button.add_theme_color_override("font_pressed_color", MENU_ENTRY_HOVER_COLOR)
	button.add_theme_color_override("font_focus_color", MENU_ENTRY_COLOR)
	button.add_theme_color_override("font_disabled_color", MENU_ENTRY_DISABLED_COLOR)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)


func _style_button(button: Button) -> void:
	# 覆盖弹窗（确认/退出/覆盖存档）的按钮同样改为纯文字：
	# 暗化背景上居中显示，无底框，悬停仅变亮。
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", MENU_ENTRY_HOVER_COLOR)
	button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	button.add_theme_color_override("font_pressed_color", Color("d5dde0"))
	button.add_theme_color_override("font_focus_color", MENU_ENTRY_HOVER_COLOR)
	button.add_theme_color_override("font_disabled_color", MENU_ENTRY_DISABLED_COLOR)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)


func _play_confirm() -> void:
	SFX.play_event(&"confirm")


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


func configure_progression(state: Dictionary) -> void:
	progression_state = state
	if is_node_ready():
		global_upgrade_panel.configure(progression_state)


func _show_somnia() -> void:
	_play_confirm()
	overlay_mode = "somnia"
	overlay_title.text = "眠网 // GLOBAL UPGRADES"
	overlay_message.visible = false
	primary_button.visible = false
	settings_panel.visible = false
	global_upgrade_panel.visible = true
	global_upgrade_panel.configure(progression_state)
	back_button.text = "返回"
	menu_content.visible = false
	menu_option_group.clear_highlight()
	overlay.visible = true


func _on_global_progress_changed() -> void:
	global_progress_changed.emit()


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
	if overlay.visible and overlay_mode == "settings":
		return
	_play_confirm()
	overlay_mode = "settings"
	overlay_title.text = "设置 // SETTINGS"
	overlay_message.visible = false
	primary_button.visible = false
	settings_panel.visible = true
	global_upgrade_panel.visible = false
	back_button.text = "返回"
	menu_content.visible = false
	menu_option_group.clear_highlight()
	overlay.visible = true


func _show_confirmation(mode: String) -> void:
	_play_confirm()
	overlay_mode = mode
	primary_button.visible = true
	settings_panel.visible = false
	global_upgrade_panel.visible = false
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
	menu_option_group.clear_highlight()
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
	overlay_option_group.clear_highlight()
	overlay.visible = false
	menu_content.visible = true
	overlay_mode = ""
	settings_panel.visible = false
	global_upgrade_panel.visible = false
	overlay_message.visible = true
	primary_button.disabled = false
	back_button.disabled = false


func consume_escape() -> bool:
	if overlay.visible:
		_return_to_menu()
	else:
		_show_settings()
	return true


func _setup_footer_label(label: Label, text: String, on_click: Callable) -> void:
	# 纯文字底栏项：默认细体暗色，Hover 只变亮（不加框/不放大），点击触发各自行为。
	label.text = text
	label.add_theme_font_override("font", PixelFont.get_font())
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MENU_ENTRY_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.mouse_entered.connect(_on_footer_label_hover.bind(label, true))
	label.mouse_exited.connect(_on_footer_label_hover.bind(label, false))
	label.gui_input.connect(_on_footer_label_input.bind(label, on_click))


func _layout_footer() -> void:
	# 两段文字作为一个整体居中，中间间隔两个全角空格宽；点击区互不重叠。
	var font := PixelFont.get_font()
	var version_size: Vector2 = font.get_string_size(version_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var group_size: Vector2 = font.get_string_size(group_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var gap_width: float = font.get_string_size("　　", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var total_width := version_size.x + gap_width + group_size.x
	var start_x := roundf((footer_link.size.x - total_width) * 0.5)
	var center_y := roundf((footer_link.size.y - version_size.y) * 0.5)
	version_label.position = Vector2(start_x, center_y)
	version_label.size = Vector2(version_size.x, footer_link.size.y)
	group_label.position = Vector2(start_x + version_size.x + gap_width, center_y)
	group_label.size = Vector2(group_size.x, footer_link.size.y)


func _on_footer_label_hover(label: Label, hovered: bool) -> void:
	label.add_theme_color_override("font_color", MENU_ENTRY_HOVER_COLOR if hovered else MENU_ENTRY_COLOR)
	if hovered:
		SFX.play_event(&"ui_hover")


func _on_footer_label_input(event: InputEvent, label: Label, on_click: Callable) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		on_click.call()
		label.accept_event()


func _on_version_clicked() -> void:
	SFX.play_event(&"phone_operation")
	if is_instance_valid(announcement_window):
		announcement_window.move_to_front()
		announcement_window.show_announcement()


func _on_group_clicked() -> void:
	var result := OS.shell_open(config.community_group_url)
	if result != OK:
		push_warning("无法打开进度群链接，错误码：%d" % result)


func _on_announcement_closed() -> void:
	# 公告关闭后不阻塞主菜单；需要再次显示时可调用 announcement_window.show_announcement()。
	pass
