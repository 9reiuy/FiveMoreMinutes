extends Node2D

var direction := Vector2.RIGHT
var radius := 50.0
var lifetime := 0.18
var elapsed := 0.0


func setup(new_direction: Vector2, new_radius: float, duration: float = 0.18) -> void:
	direction = new_direction.normalized()
	radius = new_radius
	lifetime = maxf(duration, 0.01)
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	var alpha := 1.0 - clampf(elapsed / lifetime, 0.0, 1.0)
	for offset in range(3):
		draw_arc(Vector2(-offset * 4, 0), radius - offset * 4, -1.15, 1.15, 28, Color(0.32 + offset * 0.14, 0.48 + offset * 0.10, 0.60 + offset * 0.08, alpha * (1.0 - offset * 0.2)), 3.0 - offset * 0.5)
