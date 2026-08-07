class_name ComputerOverlay
extends Control

## 电脑界面 Overlay（纯展示，无任何实际功能按钮）。
##
## 风格参考"旧电脑桌面 / Y2K / 像素感 / 轻微压抑感"，仅借鉴氛围与布局，
## 全部视觉元素为本项目原创绘制（_draw 逐帧绘制，与手机 UI 风格一致）。
##
## 打开/关闭由卧室脚本 bedroom.gd 控制：
##   - _open_computer()  -> open()
##   - _close_computer() <- closed 信号 / ESC（见 bedroom.gd consume_escape）
##
## 打开时本 Control 覆盖全屏且 mouse_filter = STOP，
## 因此卧室中的床、药瓶、遮光帘与手机都会被阻断，鼠标只能操作本界面。
## 除右上角关闭按钮外，其它所有图标、窗口、任务栏按钮都只做视觉，不做功能。

signal closed

const SFX := preload("res://scripts/audio/sfx_manager.gd")

# ---- 布局常量（全屏 640×360）----
# 显示器外壳与屏幕区域。
const BEZEL_RECT := Rect2(54, 20, 532, 320)
const SCREEN_RECT := Rect2(60, 26, 520, 308)
const TOP_BAR_HEIGHT := 14.0
const TASKBAR_HEIGHT := 18.0
# 右上角关闭按钮：唯一有功能的按钮（关闭整个电脑界面）。
const CLOSE_RECT := Rect2(558.0, 28.0, 18.0, 11.0)
# 桌面图标列（仅视觉）。
const ICON_ORIGIN := Vector2(74, 56)
const ICON_SPACING := 46.0
const ICON_SIZE := 16.0
# 主窗口（仅视觉）与后面叠放的装饰小窗口（仅视觉）。
const BACK_WINDOW_RECT := Rect2(150, 96, 220, 140)
const MAIN_WINDOW_RECT := Rect2(228, 74, 300, 200)
const WINDOW_TITLE_HEIGHT := 15.0

# 桌面图标名称（仅视觉）。
const ICON_NAMES := ["我的文档", "回收站", "梦境浏览器", "睡眠日记"]

var hovered_close := false
var _anim_tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


## 打开电脑界面：淡入显示。
func open() -> void:
	if visible:
		return
	hovered_close = false
	visible = true
	modulate.a = 0.0
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	queue_redraw()


## 关闭电脑界面：淡出后隐藏并通知卧室恢复交互。
func close() -> void:
	if not visible:
		return
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_anim_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hovered := CLOSE_RECT.has_point(event.position)
		if next_hovered != hovered_close:
			hovered_close = next_hovered
			queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 唯一功能入口：右上角关闭按钮。其它位置点击无响应（纯展示）。
		if CLOSE_RECT.has_point(event.position):
			SFX.play_event(&"phone_operation")
			close()
		accept_event()


func _draw() -> void:
	if not visible:
		return
	# 压暗背景：阻断视觉焦点，同时提示卧室交互已被阻断。
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.68))
	_draw_monitor_bezel()
	_draw_wallpaper()
	_draw_top_bar()
	_draw_desktop_icons()
	_draw_back_window()
	_draw_main_window()
	_draw_taskbar()
	_draw_close_button()


# ---- 以下为纯视觉绘制，全部为原创像素风内容 ----

func _draw_monitor_bezel() -> void:
	draw_rect(BEZEL_RECT, Color("23262e"))
	draw_rect(BEZEL_RECT, Color("3c414d"), false, 1.0)
	# 屏幕底色（保证任何情况下不会出现空白黑屏）。
	draw_rect(SCREEN_RECT, Color("141a26"))


func _draw_wallpaper() -> void:
	var wallpaper := Rect2(SCREEN_RECT.position + Vector2(0, TOP_BAR_HEIGHT), Vector2(SCREEN_RECT.size.x, SCREEN_RECT.size.y - TOP_BAR_HEIGHT - TASKBAR_HEIGHT))
	# 色阶化横向色带：Y2K 风格的暗色天空渐变（低饱和、轻微压抑）。
	var band_colors := [Color("141a26"), Color("171f2e"), Color("1a2436"), Color("1d2a3e"), Color("1a2436"), Color("16202e")]
	var band_height := wallpaper.size.y / float(band_colors.size())
	for index in band_colors.size():
		draw_rect(Rect2(wallpaper.position.x, wallpaper.position.y + index * band_height, wallpaper.size.x, band_height + 1.0), band_colors[index])
	# 大像素月亮：用逐行矩形拼出圆，保持像素感。
	_draw_pixel_circle(wallpaper.position + Vector2(400, 74), 26.0, Color(0.78, 0.82, 0.86, 0.16))
	_draw_pixel_circle(wallpaper.position + Vector2(400, 74), 19.0, Color(0.85, 0.88, 0.9, 0.14))
	# 稀疏星点。
	var stars := [Vector2(40, 30), Vector2(96, 64), Vector2(150, 22), Vector2(250, 48), Vector2(320, 20), Vector2(460, 40), Vector2(490, 96), Vector2(60, 120)]
	for star in stars:
		draw_rect(Rect2(wallpaper.position + star, Vector2(1, 1)), Color(0.8, 0.85, 0.9, 0.35))
	# 扫描线：每 4 行压暗 1 行，旧显示器质感。
	var y := 0.0
	while y < wallpaper.size.y:
		draw_rect(Rect2(wallpaper.position.x, wallpaper.position.y + y, wallpaper.size.x, 1.0), Color(0.0, 0.0, 0.0, 0.06))
		y += 4.0


func _draw_pixel_circle(center: Vector2, radius: float, color: Color) -> void:
	var r := int(radius)
	for dy in range(-r, r + 1):
		var half := int(sqrt(maxf(0.0, radius * radius - float(dy * dy))))
		if half <= 0:
			continue
		draw_rect(Rect2(center.x - half, center.y + dy, half * 2, 1.0), color)


func _draw_top_bar() -> void:
	var bar := Rect2(SCREEN_RECT.position, Vector2(SCREEN_RECT.size.x, TOP_BAR_HEIGHT))
	draw_rect(bar, Color("2c3140"))
	draw_rect(Rect2(bar.position.x, bar.end.y - 1.0, bar.size.x, 1.0), Color("3f4757"))
	var font := get_theme_default_font()
	draw_string(font, bar.position + Vector2(6, 10), "旧梦OS 98 · 未激活", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9aa4b2"))
	# 右侧状态小图标（音量/信号占位，仅视觉）。
	draw_rect(Rect2(500, bar.position.y + 4, 8, 6), Color("6f7989"))
	draw_rect(Rect2(512, bar.position.y + 3, 2, 8), Color("6f7989"))
	draw_rect(Rect2(516, bar.position.y + 5, 2, 6), Color("6f7989"))
	draw_rect(Rect2(520, bar.position.y + 7, 2, 4), Color("6f7989"))
	draw_string(font, Vector2(528, bar.position.y + 10), "21:04", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9aa4b2"))


func _draw_desktop_icons() -> void:
	var font := get_theme_default_font()
	for index in ICON_NAMES.size():
		var origin := ICON_ORIGIN + Vector2(0, index * ICON_SPACING)
		_draw_pixel_icon(index, origin)
		draw_string(font, origin + Vector2(-3, ICON_SIZE + 9), ICON_NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, 40, 7, Color("b8c0cc"))


## 按索引绘制 16×16 像素图标（文件夹/回收站/浏览器/日记本）。
func _draw_pixel_icon(index: int, origin: Vector2) -> void:
	match index:
		0:  # 文件夹
			draw_rect(Rect2(origin + Vector2(1, 3), Vector2(6, 3)), Color("8f7a4e"))
			draw_rect(Rect2(origin + Vector2(1, 5), Vector2(14, 9)), Color("b39a63"))
			draw_rect(Rect2(origin + Vector2(1, 5), Vector2(14, 1)), Color("c9b27c"))
		1:  # 回收站
			draw_rect(Rect2(origin + Vector2(3, 3), Vector2(10, 2)), Color("7f8899"))
			draw_rect(Rect2(origin + Vector2(4, 5), Vector2(8, 9)), Color("5d6675"))
			draw_rect(Rect2(origin + Vector2(6, 6), Vector2(1, 7)), Color("454d5c"))
			draw_rect(Rect2(origin + Vector2(9, 6), Vector2(1, 7)), Color("454d5c"))
		2:  # 梦境浏览器（地球）
			_draw_pixel_circle(origin + Vector2(8, 8), 7.0, Color("3d6b6b"))
			draw_rect(Rect2(origin + Vector2(1, 7), Vector2(14, 2)), Color(0.55, 0.75, 0.75, 0.5))
			draw_rect(Rect2(origin + Vector2(7, 1), Vector2(2, 14)), Color(0.55, 0.75, 0.75, 0.5))
		3:  # 睡眠日记（书本）
			draw_rect(Rect2(origin + Vector2(2, 2), Vector2(12, 12)), Color("4a3a5c"))
			draw_rect(Rect2(origin + Vector2(2, 2), Vector2(2, 12)), Color("332845"))
			draw_rect(Rect2(origin + Vector2(6, 5), Vector2(6, 1)), Color("8d7ba5"))
			draw_rect(Rect2(origin + Vector2(6, 8), Vector2(5, 1)), Color("8d7ba5"))


func _draw_back_window() -> void:
	# 叠放在主窗口后面的装饰窗口（"正在加载"，仅视觉）。
	draw_rect(BACK_WINDOW_RECT, Color("0e1118"))
	draw_rect(BACK_WINDOW_RECT, Color("394152"), false, 1.0)
	var title := Rect2(BACK_WINDOW_RECT.position, Vector2(BACK_WINDOW_RECT.size.x, WINDOW_TITLE_HEIGHT))
	draw_rect(title, Color("414a5e"))
	var font := get_theme_default_font()
	draw_string(font, title.position + Vector2(4, 11), "正在加载…", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("8a93a5"))
	# 假进度条。
	var bar := Rect2(BACK_WINDOW_RECT.position + Vector2(16, 60), Vector2(140, 8))
	draw_rect(bar, Color("1a202c"))
	draw_rect(bar, Color("394152"), false, 1.0)
	draw_rect(Rect2(bar.position, Vector2(88, 8)), Color("55617a"))


func _draw_main_window() -> void:
	draw_rect(MAIN_WINDOW_RECT, Color("10131a"))
	draw_rect(MAIN_WINDOW_RECT, Color("4d5875"), false, 1.0)
	var title := Rect2(MAIN_WINDOW_RECT.position, Vector2(MAIN_WINDOW_RECT.size.x, WINDOW_TITLE_HEIGHT))
	draw_rect(title, Color("57628a"))
	var font := get_theme_default_font()
	draw_string(font, title.position + Vector2(5, 11), "readme.txt - 记事本", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("d8dde8"))
	# 标题栏右侧三个窗口按钮（最小化/最大化/关闭）：全部仅视觉，不可点击。
	for index in 3:
		var button := Rect2(title.end.x - 36.0 + index * 12.0, title.position.y + 3, 9, 9)
		draw_rect(button, Color("39415c"))
		draw_rect(button, Color("7c88a8"), false, 1.0)
		match index:
			0: draw_rect(Rect2(button.position + Vector2(2, 6), Vector2(5, 1)), Color("c8d0e0"))
			1: draw_rect(Rect2(button.position + Vector2(2, 2), Vector2(5, 5)), Color("c8d0e0"), false, 1.0)
			2:
				draw_line(button.position + Vector2(2, 2), button.end - Vector2(2, 2), Color("c8d0e0"), 1.0)
				draw_line(Vector2(button.end.x - 2, button.position.y + 2), button.position + Vector2(2, button.size.y - 2), Color("c8d0e0"), 1.0)
	# 窗口正文：轻微压抑风格的静态文字（无交互）。
	var lines := [
		"今天是第 1096 天没有做过梦。",
		"",
		"备忘：",
		"1. 交房租。",
		"2. 不要盯着屏幕太久。",
		"3. 梦里的事情，醒来就该忘掉。",
		"",
		"—— 系统提示：该文档从未被保存。"
	]
	for index in lines.size():
		draw_string(font, MAIN_WINDOW_RECT.position + Vector2(8, WINDOW_TITLE_HEIGHT + 14 + index * 13), lines[index], HORIZONTAL_ALIGNMENT_LEFT, int(MAIN_WINDOW_RECT.size.x - 16), 8, Color("8a93a8"))


func _draw_taskbar() -> void:
	var bar := Rect2(SCREEN_RECT.position.x, SCREEN_RECT.end.y - TASKBAR_HEIGHT, SCREEN_RECT.size.x, TASKBAR_HEIGHT)
	draw_rect(bar, Color("333a4a"))
	draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x, 1.0), Color("4a5366"))
	var font := get_theme_default_font()
	# "开始"按钮（仅视觉）。
	var start := Rect2(bar.position + Vector2(2, 2), Vector2(42, bar.size.y - 4))
	draw_rect(start, Color("414a5e"))
	draw_rect(start, Color("6f7989"), false, 1.0)
	draw_rect(Rect2(start.position + Vector2(3, 3), Vector2(4, 4)), Color("5c8a72"))
	draw_rect(Rect2(start.position + Vector2(8, 3), Vector2(4, 4)), Color("8a5c6e"))
	draw_rect(Rect2(start.position + Vector2(3, 8), Vector2(4, 4)), Color("5c6e8a"))
	draw_rect(Rect2(start.position + Vector2(8, 8), Vector2(4, 4)), Color("a08a4e"))
	draw_string(font, start.position + Vector2(16, 11), "开始", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("c8d0e0"))
	# 任务按钮：当前打开的 readme.txt（仅视觉）。
	var task := Rect2(start.end.x + 4, start.position.y, 92, start.size.y)
	draw_rect(task, Color("2a303e"))
	draw_rect(task, Color("57628a"), false, 1.0)
	draw_string(font, task.position + Vector2(5, 11), "readme.txt", HORIZONTAL_ALIGNMENT_LEFT, 84, 7, Color("aab3c5"))
	# 右下角时钟（静态，仅视觉）。
	draw_string(font, Vector2(bar.end.x - 34, bar.position.y + 12), "21:04", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9aa4b2"))


func _draw_close_button() -> void:
	# 唯一功能按钮：关闭整个电脑界面（悬停提亮）。
	var base := Color("8a3b47") if not hovered_close else Color("a84a58")
	draw_rect(CLOSE_RECT, base)
	draw_rect(CLOSE_RECT, Color("d8dde8"), false, 1.0)
	draw_line(CLOSE_RECT.position + Vector2(5, 3), CLOSE_RECT.end - Vector2(5, 3), Color.WHITE, 2.0)
	draw_line(Vector2(CLOSE_RECT.end.x - 5, CLOSE_RECT.position.y + 3), CLOSE_RECT.position + Vector2(5, CLOSE_RECT.size.y - 3), Color.WHITE, 2.0)
