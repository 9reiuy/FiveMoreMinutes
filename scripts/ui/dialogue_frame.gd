extends Control

const BACKGROUND := Color("0f1e29")
const BORDER := Color("73aed8")
const MUTED_LINE := Color("56758a")
const ACCENT := Color(1.0, 1.0, 1.0, 0.82)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, BACKGROUND)
	# Broken and slightly offset lines keep the frame angular without forming a white box.
	draw_line(Vector2(0, 0), Vector2(size.x * 0.58, 0), BORDER, 2.0)
	draw_line(Vector2(size.x * 0.64, 0), Vector2(size.x, 0), BORDER, 2.0)
	draw_line(Vector2(0, 0), Vector2(0, size.y), BORDER, 2.0)
	draw_line(Vector2(0, size.y), Vector2(size.x * 0.76, size.y), BORDER, 2.0)
	draw_line(Vector2(size.x * 0.82, size.y), Vector2(size.x, size.y), BORDER, 2.0)
	draw_line(Vector2(size.x, 0), Vector2(size.x, size.y * 0.72), BORDER, 2.0)
	draw_line(Vector2(size.x, size.y * 0.79), Vector2(size.x, size.y), BORDER, 2.0)
	draw_line(Vector2(8, 6), Vector2(size.x * 0.32, 6), MUTED_LINE, 1.0)
	draw_line(Vector2(size.x - 7, 20), Vector2(size.x - 7, size.y * 0.45), MUTED_LINE, 1.0)
	draw_line(Vector2(24, 0), Vector2(70, 0), ACCENT, 1.0)
	# Small asymmetric corner and glitch marks.
	draw_line(Vector2(-5, 14), Vector2(12, 14), BORDER, 1.0)
	draw_line(Vector2(12, 14), Vector2(12, 5), BORDER, 1.0)
	draw_line(Vector2(size.x - 24, size.y - 7), Vector2(size.x + 5, size.y - 7), MUTED_LINE, 1.0)
	draw_line(Vector2(size.x * 0.46, size.y + 3), Vector2(size.x * 0.58, size.y + 3), BORDER, 1.0)
