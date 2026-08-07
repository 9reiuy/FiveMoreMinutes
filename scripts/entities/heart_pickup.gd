extends Node2D

# 红心拾取物：使用 res://art/icon/EXP/health.png 序列帧动画（循环、Nearest）。
# 6帧宽度不同（14/12/10/4/12/14，高13），按各帧自身尺寸居中绘制防抖。
# 拾取手感（弹出+磁吸）与旧版一致，回复量 heal_amount 不变，拾取后仍触发角色 Heal 动画。
const CONFIG := preload("res://resources/demo_config.tres")
const HEART_SHEET := preload("res://art/icon/EXP/health.png")
const HEART_FRAME_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 14, 13), Rect2(16, 0, 12, 13), Rect2(32, 0, 10, 13),
	Rect2(51, 0, 4, 13), Rect2(64, 0, 12, 13), Rect2(80, 0, 14, 13),
]
const FRAME_SECONDS := 0.1

signal collected(heal_amount: float)

var heal_amount := 15.0
var target: Node2D
var consumed := false
var pop_elapsed := 0.0
var anim_elapsed := 0.0
var draw_offset := Vector2.ZERO
var frames: Array[AtlasTexture] = []


func _ready() -> void:
	scale = Vector2.ONE * 0.35
	if frames.is_empty():
		for region in HEART_FRAME_REGIONS:
			var frame := AtlasTexture.new()
			frame.atlas = HEART_SHEET
			frame.region = region
			frames.append(frame)


func _process(delta: float) -> void:
	pop_elapsed = minf(pop_elapsed + delta, CONFIG.kill_pop_animation_seconds)
	var pop_progress := clampf(pop_elapsed / maxf(CONFIG.kill_pop_animation_seconds, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - pop_progress, 3.0)
	scale = Vector2.ONE * lerpf(0.35, 1.0, eased)
	draw_offset.y = -sin(pop_progress * PI) * 9.0
	anim_elapsed += delta
	queue_redraw()
	if consumed or not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < 92.0:
		global_position = global_position.move_toward(target.global_position, 145.0 * delta)
	if global_position.distance_to(target.global_position) < 15.0:
		consumed = true
		collected.emit(heal_amount)
		queue_free()


func _draw() -> void:
	if frames.is_empty():
		return
	var frame_index := int(anim_elapsed / FRAME_SECONDS) % frames.size()
	var frame_texture: AtlasTexture = frames[frame_index]
	var frame_size := frame_texture.region.size
	draw_texture_rect(frame_texture, Rect2(draw_offset - frame_size * 0.5, frame_size), false)
