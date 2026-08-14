# 文件名称: announcement_window.gd
# 功能:     主菜单全屏公告控制器（点击版本号打开 / 像素淡入 / 内容加载 / 底部关闭）
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
# 进入主菜单不再自动弹公告；打开入口为主菜单底部“版本号”点击。
# ==========================================
class_name AnnouncementWindow
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
# 公告内容读取位置：
# 修改 res://data/announcement.txt 即可改变主菜单公告文字
const ANNOUNCEMENT_FILE := "res://data/announcement.txt"

signal closed

@onready var title_label: Label = $Title
@onready var close_button: Button = $CloseButton
@onready var content_scroll: ScrollContainer = $BodyScroll
@onready var announcement_text: Label = $BodyScroll/AnnouncementText

var _enter_tween: Tween


func _ready() -> void:
	_process_mode_always()
	# 进入主菜单不自动弹公告：默认隐藏，等待主菜单版本号点击调用 show_announcement()。
	visible = false
	_style_close_button()
	close_button.pressed.connect(_on_close)
	announcement_text.add_theme_font_override("font", PixelFont.get_font())
	title_label.add_theme_font_override("font", PixelFont.get_font())
	_load_announcement()


func _process_mode_always() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _load_announcement() -> void:
	if not FileAccess.file_exists(ANNOUNCEMENT_FILE):
		announcement_text.text = "（暂无公告）"
		push_error("公告文件缺失：%s" % ANNOUNCEMENT_FILE)
		return
	var content := FileAccess.get_file_as_string(ANNOUNCEMENT_FILE).strip_edges()
	announcement_text.text = content if not content.is_empty() else "（暂无公告）"


func _style_close_button() -> void:
	# 纯文字关闭按钮：无像素底框，悬停仅变亮；位于全屏底部安全区中央。
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.flat = true
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", PixelFont.get_font())
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_color_override("font_color", Color("c9c7ce"))
	close_button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	close_button.add_theme_color_override("font_pressed_color", Color("d5dde0"))
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		close_button.add_theme_stylebox_override(state, empty)


func _play_enter_animation() -> void:
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	visible = true
	content_scroll.scroll_vertical = 0
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.28)
	_enter_tween = tween


func _on_close() -> void:
	SFX.play_event(&"phone_operation")
	visible = false
	closed.emit()


## 打开全屏公告（并重播淡入动画）。入口：主菜单版本号点击。
func show_announcement() -> void:
	_play_enter_animation()
