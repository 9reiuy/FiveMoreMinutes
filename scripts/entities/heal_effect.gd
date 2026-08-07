extends Node2D

# 回血特效：围绕角色身体中心播放一次 Heal 序列帧，播完自动销毁。
const HEAL_FRAMES: Array[Texture2D] = [
	preload("res://art/Effects/Heal/Frames/Heal_01.png"),
	preload("res://art/Effects/Heal/Frames/Heal_02.png"),
	preload("res://art/Effects/Heal/Frames/Heal_03.png"),
	preload("res://art/Effects/Heal/Frames/Heal_04.png"),
	preload("res://art/Effects/Heal/Frames/Heal_05.png"),
	preload("res://art/Effects/Heal/Frames/Heal_06.png"),
	preload("res://art/Effects/Heal/Frames/Heal_07.png"),
	preload("res://art/Effects/Heal/Frames/Heal_08.png"),
	preload("res://art/Effects/Heal/Frames/Heal_09.png"),
	preload("res://art/Effects/Heal/Frames/Heal_10.png"),
	preload("res://art/Effects/Heal/Frames/Heal_11.png"),
	preload("res://art/Effects/Heal/Frames/Heal_12.png"),
]
const FRAME_SECONDS := 0.06

# 原帧 64x64，缩到 36px 左右避免遮挡角色。
var display_size := 36.0
var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= FRAME_SECONDS * HEAL_FRAMES.size():
		queue_free()


func _draw() -> void:
	var frame_index := mini(int(elapsed / FRAME_SECONDS), HEAL_FRAMES.size() - 1)
	var frame := HEAL_FRAMES[frame_index]
	draw_texture_rect(frame, Rect2(-display_size * 0.5, -display_size * 0.5, display_size, display_size), false)
