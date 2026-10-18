class_name DreamSpawnWarning
extends Node2D

signal finished(payload: Dictionary, spawn_position: Vector2)

var payload: Dictionary = {}
var duration := 0.9
var elapsed := 0.0
var completed := false


func setup(data: Dictionary, warning_duration: float) -> void:
	payload = data.duplicate(true)
	duration = maxf(warning_duration, 0.1)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if completed:
		return
	elapsed = minf(duration, elapsed + delta)
	queue_redraw()
	if elapsed < duration:
		return
	completed = true
	finished.emit(payload, global_position)
	queue_free()


func _draw() -> void:
	var progress := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var pulse := 1.0 + sin(elapsed * 14.0) * 0.08
	draw_circle(Vector2.ZERO, 15.0 * pulse, Color(0.18, 0.29, 0.46, 0.34))
	draw_arc(Vector2.ZERO, 17.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, Color("c3d4ee"), 2.0)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color(0.45, 0.57, 0.76, 0.7), 1.0)
	var track := Rect2(-18, 20, 36, 4)
	draw_rect(track, Color("111526"))
	draw_rect(Rect2(track.position + Vector2.ONE, Vector2((track.size.x - 2.0) * progress, 2.0)), Color("91a8cf"))
