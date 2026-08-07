extends Node2D

signal finished

var amount := 0
var is_critical := false
var elapsed := 0.0
var duration := 0.65
var drift := Vector2.ZERO


func _ready() -> void:
	visible = false
	set_process(false)


func activate(at_position: Vector2, new_amount: int, critical: bool) -> void:
	global_position = at_position + Vector2(randf_range(-5.0, 5.0), 0.0)
	amount = maxi(1, new_amount)
	is_critical = critical
	elapsed = 0.0
	drift = Vector2(randf_range(-7.0, 7.0), -25.0)
	modulate.a = 1.0
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	position += drift * delta
	modulate.a = 1.0 - clampf(elapsed / duration, 0.0, 1.0)
	if elapsed >= duration:
		visible = false
		set_process(false)
		finished.emit()


func _draw() -> void:
	var color := Color("e05a5a") if is_critical else Color.WHITE
	draw_string(PixelFont.get_font(), Vector2(-18, 0), str(amount), HORIZONTAL_ALIGNMENT_CENTER, 36, 14, color)
