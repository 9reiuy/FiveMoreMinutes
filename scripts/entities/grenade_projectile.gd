extends Node2D

const ARENA_BOUNDS := Rect2(30, 54, 580, 258)

var target_position := Vector2.ZERO
var direction := Vector2.RIGHT
var speed := 300.0
var explosion_radius := 150.0
var explosion_visual_radius := 150.0
var enemy_damage := 30.0
var self_damage := 10.0
var owner_player: Node2D
var travel_time := 0.0
var minimum_travel_seconds := 0.12
var exploded := false
var explosion_visual_progress := 0.0
var explosion_alpha := 1.0


func setup(target: Vector2, new_speed: float, radius: float, visual_radius: float, damage: float, player_damage: float, player: Node2D) -> void:
	target_position = target
	direction = global_position.direction_to(target_position)
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	speed = new_speed
	explosion_radius = radius
	explosion_visual_radius = visual_radius
	enemy_damage = damage
	self_damage = player_damage
	owner_player = player
	queue_redraw()


func _process(delta: float) -> void:
	if exploded:
		return
	travel_time += delta
	var remaining := global_position.distance_to(target_position)
	global_position = global_position.move_toward(target_position, speed * delta)
	rotation += delta * 7.0
	if not ARENA_BOUNDS.has_point(global_position) or (remaining <= speed * delta + 0.5 and travel_time >= minimum_travel_seconds):
		_explode()


func _explode() -> void:
	if exploded:
		return
	exploded = true
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		for enemy in get_tree().get_nodes_in_group("dream_enemies"):
			if is_instance_valid(enemy) and not bool(enemy.get("dead")) and global_position.distance_to(enemy.global_position) <= explosion_radius:
				world.resolve_player_hit(enemy, enemy_damage, global_position)
	if is_instance_valid(owner_player) and global_position.distance_to(owner_player.global_position) <= explosion_radius:
		owner_player.receive_damage(self_damage)
	set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "explosion_visual_progress", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "explosion_alpha", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(_value: float): queue_redraw(), 0.0, 1.0, 0.18)
	await tween.finished
	queue_free()


func _draw() -> void:
	if not exploded:
		draw_circle(Vector2.ZERO, 6.0, Color("647b8c"))
		draw_rect(Rect2(-2, -8, 4, 3), Color("b7c6cc"))
	else:
		var radius := explosion_visual_radius * explosion_visual_progress
		draw_circle(Vector2.ZERO, radius, Color(0.32, 0.48, 0.60, 0.25 * explosion_alpha))
		draw_circle(Vector2.ZERO, radius, Color(0.60, 0.71, 0.78, explosion_alpha), false, 3.0)
