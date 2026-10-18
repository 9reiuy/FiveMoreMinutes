extends Node2D

## Passive presentation sync; only the real effect advances its lifetime.
func copy_depth_visual_state_to(target: Node2D) -> void:
	target.set("elapsed", elapsed)
	target.set("frame_duration", frame_duration)
	target.queue_redraw()

## 弹丸类武器的 SP402 序列帧子特效：在发射点完整播放 SP402_01..05 五帧。
## 弹丸实体本体飞行时保持首帧（SP402_01）常驻，本特效独立播放后续动画，
## 播放进度只由自身计时驱动，不阻塞武器下一发开火（射速仍由攻击间隔控制）。

const FRAMES: Array[Texture2D] = [
	preload("res://art/Effects/SP402_nyknck/SP402_01.png"),
	preload("res://art/Effects/SP402_nyknck/SP402_02.png"),
	preload("res://art/Effects/SP402_nyknck/SP402_03.png"),
	preload("res://art/Effects/SP402_nyknck/SP402_04.png"),
	preload("res://art/Effects/SP402_nyknck/SP402_05.png"),
]
# 统一以帧右缘（弹丸出膛侧）为锚点：首帧弹体贴近特效原点，
# 后续帧的拖影自然向后（-x）延展，序列播放不跳动。
const FRAME_ANCHOR := Vector2(44.0, 16.0)

var elapsed := 0.0
var frame_duration := 0.05


func setup(direction: Vector2, seconds_per_frame: float = 0.05) -> void:
	frame_duration = maxf(seconds_per_frame, 0.01)
	# 素材真实时序为 SP402_01→05（弹头从右向左运动、拖尾在右）。
	# 精灵的“前进轴”是局部 -x，因此朝向用旋转角 + PI 单独处理，
	# 动画帧仍按 01→05 正序播放，绝不倒放。
	rotation = (direction.normalized().angle() + PI) if direction.length_squared() > 0.0001 else PI
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	var frame_index := int(elapsed / frame_duration)
	if frame_index >= FRAMES.size():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var frame_index := mini(int(elapsed / frame_duration), FRAMES.size() - 1)
	var texture := FRAMES[frame_index]
	draw_texture_rect(texture, Rect2(-FRAME_ANCHOR, texture.get_size()), false)
