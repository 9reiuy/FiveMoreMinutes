# ==========================================
# 文件名称: announcement_window.gd
# 功能:     主菜单公告窗口控制器（显示/隐藏/像素淡入动画/内容加载/关闭）
# 修改说明: 只做公告窗口框架，不写死公告内容
#
# 公告内容修改位置:
# res://data/announcement.txt
#
# 公告窗口场景文件位置:
# res://scenes/ui/announcement_window.tscn
#
# 注意:
# 不要直接修改本脚本里的文字，修改 res://data/announcement.txt 即可
# ==========================================
class_name AnnouncementWindow
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
# 公告内容读取位置：
# 修改 res://data/announcement.txt 即可改变主菜单公告文字
const ANNOUNCEMENT_FILE := "res://data/announcement.txt"

signal closed

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Content/TitleBar/Title
@onready var close_button: Button = $Panel/Content/TitleBar/CloseButton
@onready var content_scroll: ScrollContainer = $Panel/Content/ContentScroll
@onready var announcement_text: Label = $Panel/Content/ContentScroll/AnnouncementText

var _enter_tween: Tween


func _ready() -> void:
	_process_mode_always()
	_style_close_button()
	close_button.pressed.connect(_on_close)
	announcement_text.add_theme_font_override("font", PixelFont.get_font())
	title_label.add_theme_font_override("font", PixelFont.get_font())
	_load_announcement()
	# 进入主菜单时的像素淡入动画：从透明 + 轻微上移（0.3s）。
	_play_enter_animation()


func _process_mode_always() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _load_announcement() -> void:
	if not FileAccess.file_exists(ANNOUNCEMENT_FILE):
		announcement_text.text = "（暂无公告）"
		push_warning("公告文件缺失：%s" % ANNOUNCEMENT_FILE)
		return
	var content := FileAccess.get_file_as_string(ANNOUNCEMENT_FILE).strip_edges()
	announcement_text.text = content if not content.is_empty() else "（暂无公告）"


func _style_close_button() -> void:
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", PixelFont.get_font())
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_color_override("font_color", Color("c9c7ce"))
	close_button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	close_button.add_theme_stylebox_override("normal", _pixel_box(Color(0.12, 0.14, 0.19, 0.95), Color("3e4350"), 1))
	close_button.add_theme_stylebox_override("hover", _pixel_box(Color(0.20, 0.24, 0.30, 0.98), Color("a3bfd0"), 2))
	close_button.add_theme_stylebox_override("pressed", _pixel_box(Color(0.26, 0.30, 0.36, 1.0), Color("9ab6c8"), 2))


func _pixel_box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.border_width_left = width + 1
	box.border_width_top = width
	box.border_width_right = width + 1
	box.border_width_bottom = width
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


func _play_enter_animation() -> void:
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	visible = true
	modulate.a = 0.0
	var start_y := position.y + 10.0
	position.y = start_y
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.28)
	tween.parallel().tween_property(self, "position:y", start_y - 10.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_enter_tween = tween


func _on_close() -> void:
	SFX.play_event(&"phone_operation")
	visible = false
	closed.emit()


## 重新显示公告窗口（并重播淡入动画）。
func show_announcement() -> void:
	_play_enter_animation()
