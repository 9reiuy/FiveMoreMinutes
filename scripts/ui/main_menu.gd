extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal continue_requested
signal new_game_requested
signal global_progress_changed
signal quit_requested

@export var config: DemoConfig

@onready var menu_content: Control = $MenuContent
@onready var menu_option_group: PixelOptionGroup = $MenuContent/MenuTriangle
@onready var button_list: HBoxContainer = $MenuContent/ButtonList
@onready var continue_button: Button = $MenuContent/ButtonList/Continue
@onready var start_button: Button = $MenuContent/ButtonList/Start
@onready var settings_button: Button = $MenuContent/ButtonList/Settings
@onready var quit_button: Button = $MenuContent/ButtonList/Quit
@onready var home_screen_eye: TextureRect = $HomeScreenVisual/Canvas/CharacterLayer/Home_Screen_chr_eye
@onready var home_screen_eye_mask: TextureRect = $HomeScreenVisual/Canvas/CharacterLayer/Home_Screen_chr_eye_mask
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

# 主菜单选项使用 Home Screen 美术指定的蓝色：默认 #264586，悬停 #396FE2。
const MENU_ENTRY_COLOR := Color("264586")
const MENU_ENTRY_HOVER_COLOR := Color("396fe2")
const MENU_ENTRY_DISABLED_COLOR := MENU_ENTRY_COLOR

# Four Home Screen textures share one 1260x710 source canvas.  The center is
# derived from the mask's actual non-transparent bounds (x625..672/y207..226).
const HOME_SCREEN_CANVAS_SIZE := Vector2(1260.0, 710.0)
const EYE_FOLLOW_SOURCE_CENTER := Vector2(648.5, 216.5)
# Latest art alignment: compared with the old symmetric 5px range, top,
# bottom and left are reduced by 1px, while right is extended by 1px.
const EYE_OFFSET_LEFT := 4.0
const EYE_OFFSET_RIGHT := 6.0
const EYE_OFFSET_UP := 4.0
const EYE_OFFSET_DOWN := 4.0
const EYE_FOLLOW_DISTANCE := 200.0
const EYE_FOLLOW_RESPONSE_SECONDS := 0.08
const EYE_IDLE_RETURN_DELAY_SECONDS := 3.0
const EYE_IDLE_RETURN_RESPONSE_SECONDS := 0.28

var eye_offset := Vector2.ZERO
var eye_origin_position := Vector2.ZERO
var eye_material: ShaderMaterial
var last_mouse_position := Vector2.ZERO
var eye_mouse_idle_seconds := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	button_list.add_theme_constant_override("separation", config.main_menu_button_spacing)
	for entry in [continue_button, start_button, settings_button, quit_button]:
		_style_menu_entry(entry)
	for overlay_button in [primary_button, back_button]:
		_style_button(overlay_button)
	continue_button.disabled = not has_save
	menu_option_group.register_options([continue_button, start_button, settings_button, quit_button])
	overlay_option_group.register_options([primary_button, back_button])
	continue_button.gui_input.connect(_on_continue_gui_input)
	continue_button.pressed.connect(_on_continue)
	start_button.pressed.connect(_on_start)
	settings_button.pressed.connect(_show_settings)
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
	eye_origin_position = home_screen_eye.position
	eye_material = home_screen_eye.material as ShaderMaterial
	if eye_material != null:
		# 真实的不规则 Alpha 遮罩来自固定的 Mask 节点；Eye 自身只移动 position。
		eye_material.set_shader_parameter(&"mask_texture", home_screen_eye_mask.texture)
	last_mouse_position = get_viewport().get_mouse_position()
	_set_eye_position(Vector2.ZERO)


func _process(delta: float) -> void:
	_update_eye_follow(delta)


func _update_eye_follow(delta: float) -> void:
	if not is_instance_valid(home_screen_eye) or not home_screen_eye.is_visible_in_tree():
		return
	var eye_rect := home_screen_eye_mask.get_global_rect()
	if eye_rect.size.x <= 0.0 or eye_rect.size.y <= 0.0:
		return
	# Both values are in Control/global canvas coordinates.  This deliberately
	# avoids Node2D.to_local(), which does not exist for Control nodes.
	var eye_center_ratio := EYE_FOLLOW_SOURCE_CENTER / HOME_SCREEN_CANVAS_SIZE
	var eye_screen_center := eye_rect.position + eye_rect.size * eye_center_ratio
	var mouse_position := get_viewport().get_mouse_position()
	if mouse_position.distance_squared_to(last_mouse_position) > 0.01:
		last_mouse_position = mouse_position
		eye_mouse_idle_seconds = 0.0
	else:
		eye_mouse_idle_seconds += delta
	var mouse_delta := mouse_position - eye_screen_center
	var target_offset := Vector2.ZERO
	if eye_mouse_idle_seconds < EYE_IDLE_RETURN_DELAY_SECONDS and mouse_delta.length_squared() > 0.0001:
		var strength := clampf(mouse_delta.length() / EYE_FOLLOW_DISTANCE, 0.0, 1.0)
		var direction := mouse_delta.normalized()
		var horizontal_limit := EYE_OFFSET_RIGHT if direction.x >= 0.0 else EYE_OFFSET_LEFT
		var vertical_limit := EYE_OFFSET_DOWN if direction.y >= 0.0 else EYE_OFFSET_UP
		# Intersect the mouse direction with the asymmetric movement rectangle.
		# This preserves direction while reaching the exact -4/+6/-4/+4 borders.
		var x_distance := horizontal_limit / absf(direction.x) if absf(direction.x) > 0.0001 else INF
		var y_distance := vertical_limit / absf(direction.y) if absf(direction.y) > 0.0001 else INF
		target_offset = direction * minf(x_distance, y_distance) * strength
	# Exponential smoothing gives the requested short response without spring,
	# overshoot, or accumulated position drift.
	var response_seconds := EYE_IDLE_RETURN_RESPONSE_SECONDS if eye_mouse_idle_seconds >= EYE_IDLE_RETURN_DELAY_SECONDS else EYE_FOLLOW_RESPONSE_SECONDS
	var response := 1.0 - exp(-delta / maxf(response_seconds, 0.001))
	eye_offset = _clamp_eye_offset(eye_offset.lerp(target_offset, response))
	_set_eye_position(eye_offset)


func _set_eye_position(offset_pixels: Vector2) -> void:
	if not is_instance_valid(home_screen_eye):
		return
	# 不累加、不缩放、不旋转：每帧只写入相对于原始布局的二维位置。
	eye_offset = _clamp_eye_offset(offset_pixels)
	home_screen_eye.position = eye_origin_position + eye_offset
	if eye_material == null:
		return
	var safe_size := Vector2(maxf(home_screen_eye.size.x, 1.0), maxf(home_screen_eye.size.y, 1.0))
	# Eye 节点移动后反向补偿遮罩采样坐标，使 Mask 始终固定在原始 Canvas。
	eye_material.set_shader_parameter(&"mask_offset_uv", eye_offset / safe_size)


func _clamp_eye_offset(value: Vector2) -> Vector2:
	return Vector2(
		clampf(value.x, -EYE_OFFSET_LEFT, EYE_OFFSET_RIGHT),
		clampf(value.y, -EYE_OFFSET_UP, EYE_OFFSET_DOWN)
	)


func _exit_tree() -> void:
	_set_eye_position(Vector2.ZERO)


func _style_menu_entry(button: Button) -> void:
	# 纯文字选项：无按钮底框，悬停只改变文字颜色；Triangle 由独立层绘制。
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


func configure_progression(state: Dictionary) -> void:
	progression_state = state
	if is_node_ready():
		global_upgrade_panel.configure(progression_state)


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
