extends Node2D

var direction := Vector2.RIGHT
var beam_length := 150.0
var beam_width := 12.0
var lifetime := 0.15
var initial_lifetime := 0.15


func setup(new_direction: Vector2, new_length: float, new_width: float, display_seconds: float) -> void:
	direction = new_direction
	beam_length = new_length
	beam_width = new_width
	lifetime = display_seconds
	initial_lifetime = maxf(display_seconds, 0.001)
	queue_redraw()


func _process(delta: float) -> void:
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0)
	draw_line(Vector2.ZERO, direction * beam_length, Color("384c68", alpha * 0.45), beam_width + 5.0)
	draw_line(Vector2.ZERO, direction * beam_length, Color("517b98", alpha * 0.82), beam_width)
	draw_line(Vector2.ZERO, direction * beam_length, Color("b4cad6", alpha), maxf(2.0, beam_width * 0.28))
	for distance in range(12, int(beam_length), 18):
		draw_rect(Rect2(direction * distance - Vector2(2, 2), Vector2(4, 4)), Color("9ab6c8", alpha * 0.7))
