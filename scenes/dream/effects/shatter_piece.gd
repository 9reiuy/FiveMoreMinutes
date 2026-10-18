extends Node2D


var ground_velocity: Vector2 = Vector2.ZERO

# 假的Z高度
var height: float = 0.0
var vertical_velocity: float = 0.0

var gravity: float = 260.0
var drag: float = 90.0

var landed: bool = false
var disappear_left: float = -1.0
var fade_duration := 0.35
var fade_started := false


func setup(
	texture: Texture2D,
	start_velocity: Vector2,
	up_velocity: float,
	disappear_delay: float = 0.8
) -> void:
	$Sprite2D.texture = texture

	ground_velocity = start_velocity
	vertical_velocity = up_velocity
	disappear_left = maxf(0.0, disappear_delay)

	# 少量随机旋转
	rotation = randf_range(-0.15, 0.15)


func _process(delta: float) -> void:
	if disappear_left >= 0.0:
		disappear_left -= delta
		if fade_started:
			modulate.a = clampf(disappear_left / fade_duration, 0.0, 1.0)
			if disappear_left <= 0.0:
				queue_free()
				return
		elif disappear_left <= 0.0:
			fade_started = true
			disappear_left = fade_duration
	if landed:
		return

	# 在地面方向上向外飞
	var end := global_position + ground_velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters2D.create(global_position, end, 1 | 4))
	if not hit.is_empty():
		end = Vector2(hit.position) + Vector2(hit.normal) * 2.0
		ground_velocity = Vector2.ZERO
	global_position = end

	ground_velocity = ground_velocity.move_toward(
		Vector2.ZERO,
		drag * delta
	)

	# 模拟碎块腾空
	vertical_velocity -= gravity * delta
	height += vertical_velocity * delta

	if height <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		ground_velocity = Vector2.ZERO
		landed = true

	# Sprite向上偏移，模拟高度
	$Sprite2D.position.y = -height
