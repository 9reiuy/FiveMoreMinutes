extends RefCounted
## Shared pixel geometry for living human hands. No gameplay state is written.
static var _bat_grips: Dictionary = {}
const WEAPONS := preload("res://scripts/data/dream_gun_atlas.gd")

static func facing_right(direction: Vector2) -> bool:
	# Angle -> vector round trips can change the sign of a near-zero X at UP.
	return direction.x >= -.001

static func orbit_center(phase: float) -> Vector2:
	return Vector2(cos(phase) * 12.0, 8.0 + sin(phase) * 6.0)

static func orbit_depth(phase: float, previous: int) -> int:
	return (-1 if sin(phase) < 0.0 else 1) if absf(sin(phase)) > .08 else previous

static func bat_grip(sprite: Sprite2D) -> Vector2:
	if not _bat_grips.has(sprite.texture):
		var rect := sprite.texture.get_image().get_used_rect()
		var fallback := Vector2(rect.position.x + 2.0, rect.get_center().y)
		_bat_grips[sprite.texture] = WEAPONS.get_melee_grip_pixels(sprite.texture, fallback)
	var size := sprite.texture.get_size()
	var point: Vector2 = _bat_grips[sprite.texture]
	if sprite.flip_h: point.x = size.x - point.x
	if sprite.flip_v: point.y = size.y - point.y
	return point - size * .5

static func align_bat(sprite: Sprite2D, facing_right: bool = true) -> void:
	sprite.flip_h = false
	sprite.offset = -bat_grip(sprite)
	sprite.rotation = -PI / 3.0 if facing_right else PI / 3.0

static func apply_grips(sprite: Sprite2D, weapon_id: String, left: Sprite2D, right: Sprite2D) -> void:
	if sprite.texture == null: return
	if WEAPONS.uses_lucille_motion(weapon_id):
		right.position = sprite.transform * (bat_grip(sprite) + sprite.offset)
		left.position = sprite.transform * (bat_grip(sprite) + sprite.offset + Vector2(3,0))
	else:
		var size := sprite.texture.get_size()
		var point := Vector2(-size.x * .22, size.y * .12)
		if sprite.flip_v: point.y = -point.y
		right.position = sprite.transform * (point + sprite.offset)
		var spacing := 7.0 if weapon_id in ["assault_rifle","mp5","shotgun"] else 2.0
		left.position = sprite.transform * (point + sprite.offset + Vector2(spacing,0))
	left.rotation = sprite.rotation * .25
	right.rotation = sprite.rotation * .25
