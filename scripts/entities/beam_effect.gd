extends Node2D

# 激光主体改用 projetilNew 素材的纺锤光束行带绘制，长度直接绑定实际攻击范围。
const BEAM_TEXTURE: Texture2D = preload("res://art/Effects/projetilNew.png")
const BEAM_REGION := Rect2(0, 146, 256, 26)

var direction := Vector2.RIGHT
var beam_length := 150.0
var beam_width := 12.0
var lifetime := 0.15
var initial_lifetime := 0.15
var beam_texture: AtlasTexture


func _init() -> void:
	beam_texture = AtlasTexture.new()
	beam_texture.atlas = BEAM_TEXTURE
	beam_texture.region = BEAM_REGION


func setup(new_direction: Vector2, new_length: float, new_width: float, display_seconds: float) -> void:
	direction = new_direction
	beam_length = new_length
	beam_width = new_width
	lifetime = display_seconds
	initial_lifetime = maxf(display_seconds, 0.001)
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0)
	var height := maxf(8.0, beam_width * 1.6)
	# 外层辉光用同一行带放大淡化绘制，主体保持像素原色。
	draw_texture_rect(beam_texture, Rect2(0.0, -height * 0.75, beam_length, height * 1.5), false, Color(0.55, 0.75, 1.0, alpha * 0.4))
	draw_texture_rect(beam_texture, Rect2(0.0, -height * 0.5, beam_length, height), false, Color(1.0, 1.0, 1.0, alpha))
