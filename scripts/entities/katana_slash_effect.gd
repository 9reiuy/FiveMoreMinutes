extends Node2D

# 斩击视觉改用 SP301 序列帧，按生命周期推进帧索引。
const SLASH_FRAMES: Array[Texture2D] = [
	preload("res://art/Effects/SP301_nyknck/SP301_01.png"),
	preload("res://art/Effects/SP301_nyknck/SP301_02.png"),
	preload("res://art/Effects/SP301_nyknck/SP301_03.png"),
	preload("res://art/Effects/SP301_nyknck/SP301_04.png"),
	preload("res://art/Effects/SP301_nyknck/SP301_05.png"),
]

var direction := Vector2.RIGHT
var radius := 50.0
var lifetime := 0.18
var elapsed := 0.0


func setup(new_direction: Vector2, new_radius: float, duration: float = 0.18) -> void:
	direction = new_direction.normalized()
	radius = new_radius
	lifetime = maxf(duration, 0.01)
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	var alpha := 1.0 - clampf(elapsed / lifetime, 0.0, 1.0)
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var frame_index := mini(int(progress * SLASH_FRAMES.size()), SLASH_FRAMES.size() - 1)
	var frame := SLASH_FRAMES[frame_index]
	var frame_size := frame.get_size()
	# 以斩击半径决定绘制宽度，帧中心放在挥砍弧线前方，保持旋转中心在玩家身上。
	var width := radius * 2.0
	var height := width * frame_size.y / frame_size.x
	draw_texture_rect(frame, Rect2(radius * 0.35 - width * 0.5, -height * 0.5, width, height), false, Color(1.0, 1.0, 1.0, alpha))
