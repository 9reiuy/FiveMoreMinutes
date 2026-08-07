extends Node2D

@export var speed := 310.0
@export var lifetime := 1.4

var direction := Vector2.RIGHT
var damage := 10.0
var consumed := false
var max_distance := 270.0
var traveled := 0.0
var trail_length := 10.0


func _ready() -> void:
	trail_length = preload("res://resources/demo_config.tres").projectile_trail_length


func setup(new_direction: Vector2, new_damage: float, new_max_distance: float = 270.0, new_speed: float = -1.0) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	max_distance = new_max_distance
	if new_speed > 0.0:
		speed = new_speed


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
	var local_direction := -direction.rotated(-rotation)
	draw_line(Vector2.ZERO, local_direction * trail_length, Color("517b98", 0.55), 2.0)
	draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), Color("9ab6c8"))
	draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), Color("d2dce2"))
