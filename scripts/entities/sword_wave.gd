extends Node2D

const ARENA_BOUNDS := Rect2(30, 54, 580, 258)

var direction := Vector2.RIGHT
var damage := 10.0
var speed := 450.0
var max_distance := 300.0
var wave_width := 1.0
var traveled := 0.0
var acceleration_elapsed := 0.0
var initial_speed_ratio := 1.0
var acceleration_duration := 0.001
var acceleration_curve: Curve
var hit_enemies: Dictionary = {}

func setup(new_direction: Vector2, new_damage: float, new_speed: float, new_distance: float, new_width: float, new_initial_speed_ratio: float, new_acceleration_duration: float, new_acceleration_curve: Curve) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed
	max_distance = new_distance
	wave_width = new_width
	initial_speed_ratio = clampf(new_initial_speed_ratio, 0.0, 1.0)
	acceleration_duration = maxf(new_acceleration_duration, 0.001)
	acceleration_curve = new_acceleration_curve
	rotation = direction.angle()
	var hit_shape := get_node("HitArea/CollisionShape2D") as CollisionShape2D
	var rectangle := hit_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(8.0, wave_width)
	queue_redraw()


func _process(delta: float) -> void:
	acceleration_elapsed = minf(acceleration_elapsed + delta, acceleration_duration)
	var acceleration_progress := clampf(acceleration_elapsed / acceleration_duration, 0.0, 1.0)
	var sampled_progress := acceleration_curve.sample_baked(acceleration_progress) if acceleration_curve != null else acceleration_progress
	var current_speed := lerpf(speed * initial_speed_ratio, speed, sampled_progress)
	var step := minf(current_speed * delta, maxf(0.0, max_distance - traveled))
	var movement_start := global_position
	var movement_end := movement_start + direction * step
	global_position = movement_end
	traveled += step
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var enemy_id := enemy.get_instance_id()
		var closest_point := Geometry2D.get_closest_point_to_segment(enemy.global_position, movement_start, movement_end)
		if not hit_enemies.has(enemy_id) and closest_point.distance_to(enemy.global_position) <= wave_width * 0.5 + 13.0:
			hit_enemies[enemy_id] = true
			var world := get_tree().get_first_node_in_group("dream_world")
			if world != null:
				world.resolve_player_hit(enemy, damage, global_position - direction)
	if traveled >= max_distance or not ARENA_BOUNDS.has_point(global_position):
		queue_free()


func _draw() -> void:
	draw_line(Vector2(0, -wave_width * 0.5), Vector2(0, wave_width * 0.5), Color(0.78, 0.88, 1.0, 0.85), 3.0)
	draw_line(Vector2(-5, -wave_width * 0.35), Vector2(-5, wave_width * 0.35), Color(0.42, 0.55, 0.76, 0.55), 2.0)
	for offset in [10.0, 16.0, 23.0]:
		draw_line(Vector2(-offset, -wave_width * 0.22), Vector2(-offset, wave_width * 0.22), Color("517b98", 0.42), 2.0)
