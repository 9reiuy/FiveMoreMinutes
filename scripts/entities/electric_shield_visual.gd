class_name ElectricShieldVisual
extends AnimatedSprite2D

const FRAME_COUNT := 60
const FRAME_PATH := "res://art/Effects/Effect_ElectricShield_1/Effect_ElectricShield_1_%03d.png"
const ANIMATION := &"electric_shield"

var shield_active := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_sprite_frames()
	set_shield_active(false)


func configure(animation_fps: float, visual_scale: float) -> void:
	if sprite_frames != null and sprite_frames.has_animation(ANIMATION):
		sprite_frames.set_animation_speed(ANIMATION, maxf(animation_fps, 1.0))
	scale = Vector2.ONE * maxf(visual_scale, 0.01)


func set_shield_active(active: bool) -> void:
	if shield_active == active and visible == active:
		return
	shield_active = active
	visible = active
	if active:
		play(ANIMATION)
	else:
		stop()
		frame = 0


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ANIMATION)
	frames.set_animation_loop(ANIMATION, true)
	frames.set_animation_speed(ANIMATION, 30.0)
	for index in FRAME_COUNT:
		var path := FRAME_PATH % index
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("Electric shield frame missing: %s" % path)
			continue
		frames.add_frame(ANIMATION, texture)
	sprite_frames = frames
