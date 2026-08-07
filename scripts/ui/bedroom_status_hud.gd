class_name BedroomStatusHUD
extends Control

# 压力三档像素表情（临时占位图，待人工替换最终美术）：
# stress <= config.stress_face_happy_max → 开心；
# < config.stress_face_sweat_min → 一般；其余 → 流汗。
const FACE_HAPPY := preload("res://assets/art/ui/stress/stress_happy.png")
const FACE_NORMAL := preload("res://assets/art/ui/stress/stress_normal.png")
const FACE_SWEAT := preload("res://assets/art/ui/stress/stress_sweat.png")

@export var config: DemoConfig

var stress_value := 0


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
	var panel := Rect2(12, 12, 144, 42)
	draw_rect(panel, Color(0.03, 0.045, 0.065, 0.88))
	draw_rect(panel, Color("517b98"), false, 2.0)
	# 像素表情图标：随压力值三档切换（Nearest 过滤，与 UI 像素密度一致）。
	draw_texture_rect(update_stress_face(stress_value), Rect2(19, 20, 24, 24), false)
	draw_string(font, Vector2(43, 28), "压力值  %d / %d" % [stress_value, config.stress_max], HORIZONTAL_ALIGNMENT_LEFT, 104, 10, Color("c4cdd2"))
	var filled := ceili(float(stress_value) / maxf(config.stress_max, 1.0) * 10.0)
	for segment in range(10):
		var segment_color := Color("5f8298") if segment < filled else Color("202d38")
		draw_rect(Rect2(44 + segment * 9, 37, 7, 6), segment_color)
