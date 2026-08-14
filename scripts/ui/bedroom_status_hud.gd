class_name BedroomStatusHUD
extends Control

# 压力三档像素表情（临时占位图，待人工替换最终美术）：
# stress <= config.stress_face_happy_max → 开心；
# < config.stress_face_sweat_min → 一般；其余 → 流汗。
const FACE_HAPPY := preload("res://assets/art/ui/stress/stress_happy.png")
const FACE_NORMAL := preload("res://assets/art/ui/stress/stress_normal.png")
const FACE_SWEAT := preload("res://assets/art/ui/stress/stress_sweat.png")
const SATIETY_ICON_RECT := Rect2(160, 18, 24, 24)

@export var config: DemoConfig

var stress_value := 0
var persistent_state: Dictionary = {}
var satiety_hovered := false
var tooltip_position := Vector2.ZERO


func _ready() -> void:
	set_process_input(true)


func bind_state(state: Dictionary) -> void:
	persistent_state = state
	queue_redraw()


func refresh() -> void:
	if not bool(persistent_state.get("food_eaten_today", false)):
		satiety_hovered = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var next_hovered := bool(persistent_state.get("food_eaten_today", false)) and SATIETY_ICON_RECT.has_point(event.position)
	if next_hovered == satiety_hovered and (not next_hovered or tooltip_position == event.position):
		return
	satiety_hovered = next_hovered
	tooltip_position = event.position
	queue_redraw()


func set_stress(value: int) -> void:
	stress_value = clampi(value, 0, config.stress_max)
	# 压力每次变化（含每帧同步）都会走到这里，表情随之实时刷新。
	queue_redraw()


func update_stress_face(stress: int) -> Texture2D:
	if stress <= config.stress_face_happy_max:
		return FACE_HAPPY
	if stress < config.stress_face_sweat_min:
		return FACE_NORMAL
	return FACE_SWEAT


func _draw() -> void:
	var font := PixelFont.get_font()
	# 像素外框已删除：只保留 表情 + 压力数值 + 段位条，如 "☺ 压力 20"。
	# 像素表情图标：随压力值三档切换（Nearest 过滤，与 UI 像素密度一致）。
	draw_texture_rect(update_stress_face(stress_value), Rect2(19, 20, 24, 24), false)
	draw_string(font, Vector2(44, 29), "压力  %d / %d" % [stress_value, config.stress_max], HORIZONTAL_ALIGNMENT_LEFT, 104, 11, Color("29343c"))
	draw_string(font, Vector2(43, 28), "压力  %d / %d" % [stress_value, config.stress_max], HORIZONTAL_ALIGNMENT_LEFT, 104, 11, Color("c4cdd2"))
	var filled := ceili(float(stress_value) / maxf(config.stress_max, 1.0) * 10.0)
	for segment in range(10):
		var segment_color := Color("5f8298") if segment < filled else Color("202d38")
		draw_rect(Rect2(44 + segment * 9, 37, 7, 6), segment_color)
	if bool(persistent_state.get("food_eaten_today", false)):
		_draw_satiety_icon(SATIETY_ICON_RECT.position)
		if satiety_hovered:
			var tooltip_size := Vector2(50, 20)
			var viewport_size := get_viewport_rect().size
			var tooltip_origin := Vector2(minf(tooltip_position.x + 10.0, viewport_size.x - tooltip_size.x - 4.0), minf(tooltip_position.y + 12.0, viewport_size.y - tooltip_size.y - 4.0))
			draw_rect(Rect2(tooltip_origin, tooltip_size), Color("101b27"))
			draw_rect(Rect2(tooltip_origin, tooltip_size), Color("58778a"), false, 1.0)
			draw_string(font, tooltip_origin + Vector2(5, 14), "吃饱了", HORIZONTAL_ALIGNMENT_LEFT, 42, 9, Color("c4cdd2"))


func _draw_satiety_icon(origin: Vector2) -> void:
	# 原创16×16像素胃轮廓，按1.5倍整数像素块绘制；只传达状态，不提供点击行为。
	var pixel := 1.5
	var color := Color("86a9b8")
	var points := [Vector2i(7,1),Vector2i(7,2),Vector2i(8,3),Vector2i(8,4),Vector2i(9,5),Vector2i(11,5),Vector2i(13,6),Vector2i(14,8),Vector2i(14,11),Vector2i(13,13),Vector2i(11,14),Vector2i(8,14),Vector2i(6,13),Vector2i(5,11),Vector2i(5,9),Vector2i(4,8),Vector2i(3,8),Vector2i(2,7),Vector2i(2,5),Vector2i(3,4),Vector2i(4,5),Vector2i(4,7),Vector2i(5,8),Vector2i(7,8),Vector2i(9,7),Vector2i(9,6),Vector2i(7,5),Vector2i(6,3)]
	for point in points:
		draw_rect(Rect2(origin + Vector2(point) * pixel, Vector2(pixel, pixel)), color)
