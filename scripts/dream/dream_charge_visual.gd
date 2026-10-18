class_name DreamChargeVisual
extends RefCounted

## Shared visual-only charge animation setup for Player and Enemy.  The
## texture is the only asset authority; frame size/count are derived from its
## actual dimensions so a future sheet layout cannot silently crop the effect.

static func configure(
	sprite: AnimatedSprite2D,
	texture: Texture2D,
	fps: float,
	tint: Color = Color.WHITE,
	loop: bool = true
) -> int:
	if sprite == null or texture == null:
		return 0
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	if frames.has_animation(&"charge"):
		frames.remove_animation(&"charge")
	frames.add_animation(&"charge")
	frames.set_animation_speed(&"charge", maxf(fps, 1.0))
	frames.set_animation_loop(&"charge", loop)

	var texture_size: Vector2 = texture.get_size()
	var frame_count := 0
	var frame_side := int(roundf(texture_size.y))
	var columns := int(floor(texture_size.x / float(frame_side))) if frame_side > 0 else 0
	var rows := int(floor(texture_size.y / float(frame_side))) if frame_side > 0 else 0
	var square_sheet := (
		frame_side > 0
		and columns > 0
		and rows > 0
		and is_equal_approx(texture_size.x, float(columns * frame_side))
		and is_equal_approx(texture_size.y, float(rows * frame_side))
	)
	if square_sheet:
		for row in range(rows):
			for column in range(columns):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(
					float(column * frame_side),
					float(row * frame_side),
					float(frame_side),
					float(frame_side)
				)
				atlas.filter_clip = true
				frames.add_frame(&"charge", atlas)
				frame_count += 1
	else:
		# A non-tiled asset is still a valid one-frame charge effect.  Do not
		# invent a crop or assume a particular atlas layout.
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2.ZERO, texture_size)
		atlas.filter_clip = true
		frames.add_frame(&"charge", atlas)
		frame_count = 1

	sprite.sprite_frames = frames
	sprite.animation = &"charge"
	sprite.frame = 0
	sprite.speed_scale = 1.0
	sprite.self_modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.set_meta(&"depth_visual_unlit", true)
	sprite.hide()
	return maxi(frame_count, 1)


static func set_full_frame(sprite: AnimatedSprite2D, frame_count: int) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.stop()
	sprite.animation = &"charge"
	sprite.frame = maxi(frame_count - 1, 0)
	sprite.show()
