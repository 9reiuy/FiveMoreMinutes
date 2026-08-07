extends Node2D

# 弹丸本体使用 SP401 序列中最完整的一帧静态保持，直到命中或销毁。
const BULLET_TEXTURE: Texture2D = preload("res://art/Effects/SP401_nyknck/SP401_04.png")
# SP401_04 帧内弹丸内容中心约在 (18.5, 15.5)，绘制时将其对准弹体坐标。
const BULLET_CONTENT_CENTER := Vector2(18.5, 15.5)

@export var speed := 310.0
@export var lifetime := 1.4

var direction := Vector2.RIGHT
var damage := 10.0
var consumed := false
var max_distance := 270.0
var traveled := 0.0


func setup(new_direction: Vector2, new_damage: float, new_max_distance: float = 270.0, new_speed: float = -1.0) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	max_distance = new_max_distance
	if new_speed > 0.0:
		speed = new_speed
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	if consumed:
		return
	var step := speed * delta
	position += direction * step
	traveled += step
	lifetime -= delta
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if is_instance_valid(enemy) and not enemy.dead and global_position.distance_to(enemy.global_position) < 13.0:
			consumed = true
			var world := get_tree().get_first_node_in_group("dream_world")
			if world != null:
				world.resolve_player_hit(enemy, damage, global_position)
			queue_free()
			return
	if lifetime <= 0.0 or traveled >= max_distance:
		queue_free()


func _draw() -> void:
	# 弹丸本体帧在飞行全程保持显示，拖影包含在帧内。
	var frame_size := BULLET_TEXTURE.get_size()
	draw_texture_rect(BULLET_TEXTURE, Rect2(-BULLET_CONTENT_CENTER, frame_size), false)
