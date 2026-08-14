class_name ComputerOverlay
extends Control

## 卧室电脑桌面与应用窗口。记事本、21点和梦境浏览器共用同一像素窗口壳。
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
signal shutdown_requested
signal balance_changed
signal story_weapon_changed(weapon_id: String)

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const WINDOW_SHELL := preload("res://scripts/ui/computer_window_shell.gd")

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
const APP_WINDOW_NORMAL_RECT := Rect2(112, 52, 448, 266)
const APP_WINDOW_MAX_RECT := Rect2(62, 42, 516, 274)
const START_BUTTON_RECT := Rect2(62, 318, 42, 14)
const TASK_BUTTON_RECT := Rect2(108, 318, 108, 14)
const START_MENU_RECT := Rect2(62, 267, 118, 51)
const SHUTDOWN_RECT := Rect2(66, 290, 110, 24)

# 桌面图标名称（仅视觉）。
const ICON_NAMES := ["记事本", "回收站", "梦境浏览器", "21点"]

var hovered_close := false
var hovered_blackjack := false
var hovered_browser := false
var hovered_notepad := false
var hovered_start := false
var hovered_task := ""
var hovered_shutdown := false
var hovered_window_action := ""
var active_app := "notepad"
var app_minimized := false
var running_apps: Array[String] = ["notepad"]
var minimized_apps: Dictionary = {}
var app_maximized := false
var start_menu_open := false
var restore_position := APP_WINDOW_NORMAL_RECT.position
var restore_size := APP_WINDOW_NORMAL_RECT.size
var app_window_rect := APP_WINDOW_NORMAL_RECT
var _anim_tween: Tween
var bedroom_time_minutes := 1260.0
var persistent_state: Dictionary = {}
@onready var blackjack_app: BlackjackApp = $BlackjackApp
@onready var dream_browser_app: DreamBrowserApp = $DreamBrowserApp


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	blackjack_app.balance_changed.connect(_on_blackjack_balance_changed)
	dream_browser_app.weapon_selected.connect(_on_browser_weapon_selected)
	_layout_active_app()


func configure(state: Dictionary) -> void:
	persistent_state = state
	blackjack_app.configure(state)
	dream_browser_app.configure(state)
	_validate_story_weapon()


func set_bedroom_time(total_minutes: float) -> void:
	bedroom_time_minutes = total_minutes
	queue_redraw()


## 打开电脑界面：淡入显示。
func open() -> void:
	if visible:
		return
	hovered_close = false
	hovered_window_action = ""
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
	hovered_close = false
	hovered_blackjack = false
	hovered_browser = false
	hovered_notepad = false
	hovered_start = false
	hovered_task = ""
	hovered_shutdown = false
	hovered_window_action = ""
	start_menu_open = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hovered := CLOSE_RECT.has_point(event.position)
		var next_blackjack := (active_app.is_empty() or app_minimized) and _blackjack_icon_rect().has_point(event.position)
		var next_browser := (active_app.is_empty() or app_minimized) and _browser_icon_rect().has_point(event.position)
		var next_notepad := (active_app.is_empty() or app_minimized) and _notepad_icon_rect().has_point(event.position)
		var next_start := START_BUTTON_RECT.has_point(event.position)
		var next_task := _task_at(event.position)
		var next_shutdown := start_menu_open and SHUTDOWN_RECT.has_point(event.position)
		var next_window_action := _window_action_at(event.position)
		if next_hovered != hovered_close or next_blackjack != hovered_blackjack or next_browser != hovered_browser or next_notepad != hovered_notepad or next_start != hovered_start or next_task != hovered_task or next_shutdown != hovered_shutdown or next_window_action != hovered_window_action:
			hovered_close = next_hovered
			hovered_blackjack = next_blackjack
			hovered_browser = next_browser
			hovered_notepad = next_notepad
			hovered_start = next_start
			hovered_task = next_task
			hovered_shutdown = next_shutdown
			hovered_window_action = next_window_action
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_close or hovered_blackjack or hovered_browser or hovered_notepad or hovered_start or not hovered_task.is_empty() or hovered_shutdown or not hovered_window_action.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if start_menu_open and SHUTDOWN_RECT.has_point(event.position):
			SFX.play_event(&"phone_operation")
			start_menu_open = false
			shutdown_requested.emit()
			close()
			accept_event()
		elif START_BUTTON_RECT.has_point(event.position):
			SFX.play_event(&"phone_operation")
			start_menu_open = not start_menu_open
			queue_redraw()
			accept_event()
		elif not _task_at(event.position).is_empty():
			SFX.play_event(&"phone_operation")
			var requested_app := _task_at(event.position)
			if not active_app.is_empty() and active_app != requested_app:
				minimized_apps[active_app] = true
			active_app = requested_app
			app_minimized = false
			minimized_apps.erase(active_app)
			start_menu_open = false
			_layout_active_app()
			queue_redraw()
			accept_event()
		elif CLOSE_RECT.has_point(event.position):
			SFX.play_event(&"phone_operation")
			close()
			accept_event()
		elif not _window_action_at(event.position).is_empty():
			SFX.play_event(&"phone_operation")
			_handle_window_action(_window_action_at(event.position))
			accept_event()
		elif (active_app.is_empty() or app_minimized) and _browser_icon_rect().has_point(event.position):
			SFX.play_event(&"phone_operation")
			_open_app("browser")
			accept_event()
		elif (active_app.is_empty() or app_minimized) and _blackjack_icon_rect().has_point(event.position):
			SFX.play_event(&"phone_operation")
			_open_app("blackjack")
			accept_event()
		elif (active_app.is_empty() or app_minimized) and _notepad_icon_rect().has_point(event.position):
			SFX.play_event(&"phone_operation")
			_open_app("notepad")
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
	if active_app.is_empty():
		_draw_back_window()
	if not active_app.is_empty() and not app_minimized:
		WINDOW_SHELL.draw(self, app_window_rect, _active_app_title(), hovered_window_action, app_maximized)
		if active_app == "notepad":
			_draw_main_window()
	_draw_taskbar()
	if start_menu_open:
		_draw_start_menu()
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
	draw_string(font, Vector2(528, bar.position.y + 10), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9aa4b2"))


func _draw_desktop_icons() -> void:
	var font := get_theme_default_font()
	for index in ICON_NAMES.size():
		var origin := ICON_ORIGIN + Vector2(0, index * ICON_SPACING)
		_draw_pixel_icon(index, origin)
		draw_string(font, origin + Vector2(-3, ICON_SIZE + 9), ICON_NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, 40, 7, Color("b8c0cc"))
		if index == 3 and hovered_blackjack:
			draw_rect(Rect2(origin - Vector2(3, 3), Vector2(44, 36)), Color("6c91a5"), false, 1.0)
		elif index == 2 and hovered_browser:
			draw_rect(Rect2(origin - Vector2(3, 3), Vector2(44, 36)), Color("6c91a5"), false, 1.0)
		elif index == 0 and hovered_notepad:
			draw_rect(Rect2(origin - Vector2(3, 3), Vector2(44, 36)), Color("6c91a5"), false, 1.0)


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
		3:  # 21点：两张像素扑克牌
			draw_rect(Rect2(origin + Vector2(2, 1), Vector2(9, 13)), Color("d1d4d5"))
			draw_rect(Rect2(origin + Vector2(7, 3), Vector2(8, 12)), Color("8797a5"))
			draw_string(get_theme_default_font(), origin + Vector2(3, 11), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("6e3546"))


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
	var content := WINDOW_SHELL.content_rect(app_window_rect)
	var font := get_theme_default_font()
	# 窗口正文：轻微压抑风格的静态文字（无交互）。
	var lines := [
		"今天是1999年",
		"",
		"备忘：",
		"1. 交房租。",
		"2. 不要盯着屏幕太久。",
		"3. 梦里的事情，醒来就该忘掉。",
		"",
		"—— 系统提示：该文档从未被保存。"
	]
	for index in lines.size():
		draw_string(font, content.position + Vector2(8, 15 + index * 13), lines[index], HORIZONTAL_ALIGNMENT_LEFT, int(content.size.x - 16), 8, Color("8a93a8"))


func _draw_taskbar() -> void:
	var bar := Rect2(SCREEN_RECT.position.x, SCREEN_RECT.end.y - TASKBAR_HEIGHT, SCREEN_RECT.size.x, TASKBAR_HEIGHT)
	draw_rect(bar, Color("333a4a"))
	draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x, 1.0), Color("4a5366"))
	var font := get_theme_default_font()
	# "开始"按钮（仅视觉）。
	var start := START_BUTTON_RECT
	draw_rect(start, Color("414a5e"))
	draw_rect(start, Color("6f7989"), false, 1.0)
	draw_rect(Rect2(start.position + Vector2(3, 3), Vector2(4, 4)), Color("5c8a72"))
	draw_rect(Rect2(start.position + Vector2(8, 3), Vector2(4, 4)), Color("8a5c6e"))
	draw_rect(Rect2(start.position + Vector2(3, 8), Vector2(4, 4)), Color("5c6e8a"))
	draw_rect(Rect2(start.position + Vector2(8, 8), Vector2(4, 4)), Color("a08a4e"))
	draw_string(font, start.position + Vector2(16, 11), "开始", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("c8d0e0"))
	for index in running_apps.size():
		var app_id := running_apps[index]
		var task := _task_rect(index)
		var minimized := bool(minimized_apps.get(app_id, false))
		var task_fill := Color("222936") if minimized else Color("374153")
		if hovered_task == app_id: task_fill = task_fill.lightened(0.12)
		draw_rect(task, task_fill)
		draw_rect(task, Color("57628a"), false, 1.0)
		draw_string(font, task.position + Vector2(5, 11), _app_task_name(app_id), HORIZONTAL_ALIGNMENT_LEFT, int(task.size.x - 10), 7, Color("aab3c5"))
	# 右下角时钟（静态，仅视觉）。
	draw_string(font, Vector2(bar.end.x - 34, bar.position.y + 12), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9aa4b2"))


func _draw_start_menu() -> void:
	draw_rect(START_MENU_RECT, Color("141a24"))
	draw_rect(START_MENU_RECT, Color("596577"), false, 1.0)
	draw_rect(Rect2(START_MENU_RECT.position, Vector2(20, START_MENU_RECT.size.y)), Color("2d5269"))
	var fill := Color("6c3542") if hovered_shutdown else Color("3b303a")
	draw_rect(SHUTDOWN_RECT, fill)
	draw_rect(SHUTDOWN_RECT, Color("687484"), false, 1.0)
	draw_rect(Rect2(SHUTDOWN_RECT.position + Vector2(6, 7), Vector2(8, 8)), Color("a84a58"), false, 2.0)
	draw_string(get_theme_default_font(), SHUTDOWN_RECT.position + Vector2(22, 16), "关机", HORIZONTAL_ALIGNMENT_LEFT, 70, 9, Color("d5dbe4"))


func _draw_close_button() -> void:
	# 唯一功能按钮：关闭整个电脑界面（悬停提亮）。
	var base := Color("8a3b47") if not hovered_close else Color("a84a58")
	draw_rect(CLOSE_RECT, base)
	draw_rect(CLOSE_RECT, Color("d8dde8"), false, 1.0)
	draw_line(CLOSE_RECT.position + Vector2(5, 3), CLOSE_RECT.end - Vector2(5, 3), Color.WHITE, 2.0)
	draw_line(Vector2(CLOSE_RECT.end.x - 5, CLOSE_RECT.position.y + 3), CLOSE_RECT.position + Vector2(5, CLOSE_RECT.size.y - 3), Color.WHITE, 2.0)


func _blackjack_icon_rect() -> Rect2:
	return Rect2(ICON_ORIGIN + Vector2(-4, 3 * ICON_SPACING - 4), Vector2(48, 40))


func _browser_icon_rect() -> Rect2:
	return Rect2(ICON_ORIGIN + Vector2(-4, 2 * ICON_SPACING - 4), Vector2(48, 40))


func _notepad_icon_rect() -> Rect2:
	return Rect2(ICON_ORIGIN + Vector2(-4, -4), Vector2(48, 40))


func _active_app_title() -> String:
	match active_app:
		"blackjack": return "21点 // BLACKJACK"
		"browser": return "梦境浏览器 // DREAM BROWSER"
		_: return "readme.txt - 记事本"


func _app_task_name(app_id: String) -> String:
	match app_id:
		"blackjack": return "21点"
		"browser": return "梦境浏览器"
		_: return "readme.txt"


func _open_app(app_id: String) -> void:
	if not active_app.is_empty() and active_app != app_id:
		minimized_apps[active_app] = true
	if not app_id in running_apps:
		running_apps.append(app_id)
	active_app = app_id
	app_minimized = false
	minimized_apps.erase(app_id)
	start_menu_open = false
	if not app_maximized:
		app_window_rect = Rect2(restore_position, restore_size)
	blackjack_app.configure(persistent_state)
	dream_browser_app.configure(persistent_state)
	_layout_active_app()
	queue_redraw()


func _window_action_at(point: Vector2) -> String:
	if active_app.is_empty() or app_minimized:
		return ""
	for action in ["minimize", "maximize", "close"]:
		if WINDOW_SHELL.button_rect(app_window_rect, action).has_point(point): return action
	return ""


func _handle_window_action(action: String) -> void:
	match action:
		"minimize":
			app_minimized = true
			minimized_apps[active_app] = true
		"maximize":
			if app_maximized:
				app_window_rect = Rect2(restore_position, restore_size)
				app_maximized = false
			else:
				restore_position = app_window_rect.position
				restore_size = app_window_rect.size
				app_window_rect = APP_WINDOW_MAX_RECT
				app_maximized = true
		"close":
			running_apps.erase(active_app)
			minimized_apps.erase(active_app)
			active_app = ""
			app_minimized = false
			app_maximized = false
			app_window_rect = APP_WINDOW_NORMAL_RECT
	blackjack_app.visible = false
	dream_browser_app.visible = false
	hovered_window_action = ""
	_layout_active_app()
	queue_redraw()


func _task_rect(index: int) -> Rect2:
	return Rect2(TASK_BUTTON_RECT.position + Vector2(index * (TASK_BUTTON_RECT.size.x + 3.0), 0), TASK_BUTTON_RECT.size)


func _task_at(point: Vector2) -> String:
	for index in running_apps.size():
		if _task_rect(index).has_point(point):
			return running_apps[index]
	return ""


func _layout_active_app() -> void:
	var content := WINDOW_SHELL.content_rect(app_window_rect)
	blackjack_app.position = content.position
	blackjack_app.size = content.size
	dream_browser_app.position = content.position
	dream_browser_app.size = content.size
	blackjack_app.visible = active_app == "blackjack" and not app_minimized
	dream_browser_app.visible = active_app == "browser" and not app_minimized


func _validate_story_weapon() -> void:
	var current := str(persistent_state.get("current_weapon_id", "basic"))
	if not dream_browser_app.is_weapon_unlocked(current):
		persistent_state.current_weapon_id = "basic"
		story_weapon_changed.emit("basic")


func _on_browser_weapon_selected(weapon_id: String) -> void:
	if not dream_browser_app.is_weapon_unlocked(weapon_id): return
	persistent_state.current_weapon_id = weapon_id
	dream_browser_app.configure(persistent_state)
	story_weapon_changed.emit(weapon_id)


func _on_blackjack_balance_changed() -> void:
	balance_changed.emit()
