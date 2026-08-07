extends Node2D

## 经验球：使用 res://art/icon/EXP 序列帧动画（循环、Nearest、按帧尺寸居中防抖）。
## 蓝经验 = Blue_EXP.png 5帧（10×9 @ x=0/16/32/48/64），
## 紫经验 = Purple_EXP.png 6帧（10×9 @ x=0/16/32/48/64/81），所有紫色 EXP 统一复用。
## 数值、磁吸半径、拾取判定与旧版完全一致，只替换视觉。

const CONFIG := preload("res://resources/demo_config.tres")
const BLUE_SHEET := preload("res://art/icon/EXP/Blue_EXP.png")
const PURPLE_SHEET := preload("res://art/icon/EXP/Purple_EXP.png")
const BLUE_FRAME_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 10, 9), Rect2(16, 0, 10, 9), Rect2(32, 0, 10, 9),
	Rect2(48, 0, 10, 9), Rect2(64, 0, 10, 9),
]
const PURPLE_FRAME_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 10, 9), Rect2(16, 0, 10, 9), Rect2(32, 0, 10, 9),
	Rect2(48, 0, 10, 9), Rect2(64, 0, 10, 9), Rect2(81, 0, 10, 9),
]
const FRAME_SECONDS := 0.1

signal collected(amount: int)

@export var value := 1
var target: Node2D
var consumed := false
var pop_elapsed := 0.0
var anim_elapsed := 0.0
var draw_offset := Vector2.ZERO
var frames: Array[AtlasTexture] = []


func _ready() -> void:
	scale = Vector2.ONE * 0.35
	if frames.is_empty():
		_build_frames(BLUE_SHEET, BLUE_FRAME_REGIONS)


func configure(new_value: int, rarity: String = "normal") -> void:
	value = maxi(1, new_value)
	if rarity == "purple":
		_build_frames(PURPLE_SHEET, PURPLE_FRAME_REGIONS)
	else:
		_build_frames(BLUE_SHEET, BLUE_FRAME_REGIONS)


func _build_frames(sheet: Texture2D, regions: Array[Rect2]) -> void:
	frames.clear()
	for region in regions:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
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
		collected.emit(value)
		queue_free()


func _draw() -> void:
	if frames.is_empty():
		return
	var frame_index := int(anim_elapsed / FRAME_SECONDS) % frames.size()
	var frame_texture: AtlasTexture = frames[frame_index]
	var frame_size := frame_texture.region.size
	# 按各帧自身尺寸居中绘制，避免帧间尺寸差异造成抖动。
	draw_texture_rect(frame_texture, Rect2(draw_offset - frame_size * 0.5, frame_size), false)
