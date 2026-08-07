extends Node2D

# 爆炸特效：播放一次 HolyNova 序列帧，宽高按实际爆炸半径联动。
const NOVA_FRAMES: Array[Texture2D] = [
	preload("res://art/Effects/HolyNova/Frames/HolyNova_01.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_02.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_03.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_04.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_05.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_06.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_07.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_08.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_09.png"),
	preload("res://art/Effects/HolyNova/Frames/HolyNova_10.png"),
]
const FRAME_SECONDS := 0.045

# 原帧 128x64（2:1 椭圆环），按自然比例绘制：宽=2倍半径，高=1倍半径。
var explosion_radius := 40.0
var elapsed := 0.0


func setup(new_radius: float) -> void:
	explosion_radius = maxf(new_radius, 4.0)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= FRAME_SECONDS * NOVA_FRAMES.size():
		queue_free()


func _draw() -> void:
	var frame_index := mini(int(elapsed / FRAME_SECONDS), NOVA_FRAMES.size() - 1)
	var frame := NOVA_FRAMES[frame_index]
	var width := explosion_radius * 2.0
	var height := explosion_radius
	draw_texture_rect(frame, Rect2(-width * 0.5, -height * 0.5, width, height), false)
