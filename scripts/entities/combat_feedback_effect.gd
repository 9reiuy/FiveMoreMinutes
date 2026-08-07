extends Node2D

var direction := Vector2.RIGHT
var is_kill := false
var lifetime := 0.18
var elapsed := 0.0
var phase_offsets := PackedFloat32Array()
var primary_color := Color("517b98")
var secondary_color := Color("9ab6c8")
var warning_color := Color("9b4658")


func setup(new_direction: Vector2, kill_effect: bool, requested_lifetime: float, new_primary: Color = Color("517b98"), new_secondary: Color = Color("9ab6c8"), new_warning: Color = Color("9b4658")) -> void:
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0001 else Vector2.RIGHT
	is_kill = kill_effect
	lifetime = maxf(0.05, requested_lifetime if kill_effect else minf(requested_lifetime, 0.16))
	primary_color = new_primary
	secondary_color = new_secondary
	warning_color = new_warning
	var fragment_count := 10 if is_kill else 6
	phase_offsets.resize(fragment_count)
	for index in fragment_count:
		phase_offsets[index] = fmod(float(index * 97 + get_instance_id()), 360.0) * PI / 180.0
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var alpha := 1.0 - progress
	var base_color := Color(primary_color, alpha) if not is_kill else Color(warning_color, alpha)
	for index in phase_offsets.size():
		var spread := Vector2.RIGHT.rotated(phase_offsets[index])
		if not is_kill:
			spread = (direction + spread * 0.85).normalized()
		var distance := lerpf(3.0, 28.0 if is_kill else 16.0, progress)
		var fragment_position := spread * distance
		var pixel_size := 3.0 if index % 3 == 0 else 2.0
		draw_rect(Rect2(fragment_position - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size), base_color)
	if not is_kill:
		draw_line(-direction * 3.0, direction * lerpf(12.0, 4.0, progress), Color(secondary_color, alpha), 2.0)
	else:
		draw_circle(Vector2.ZERO, lerpf(5.0, 18.0, progress), Color(secondary_color, alpha * 0.7), false, 2.0)
