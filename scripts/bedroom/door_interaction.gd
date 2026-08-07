class_name BedroomDoorInteraction
extends Node2D

@export var config: DemoConfig

var interactable := false
var hovered := false
var delivery_waiting := false
var glow_alpha := 0.0


func set_state(can_interact: bool, is_hovered: bool, is_waiting: bool) -> void:
	interactable = can_interact
	hovered = is_hovered and can_interact
	delivery_waiting = is_waiting
	queue_redraw()


func get_interaction_rect(viewport_size: Vector2 = Vector2(640, 360)) -> Rect2:
	return Rect2(0.0, 0.0, viewport_size.x * config.door_interaction_width_ratio, viewport_size.y)


func _process(delta: float) -> void:
	var target := 1.0 if hovered else 0.0
	var seconds := config.door_glow_fade_in_seconds if target > glow_alpha else config.door_glow_fade_out_seconds
	glow_alpha = move_toward(glow_alpha, target, delta / maxf(seconds, 0.001))
	queue_redraw()


func _draw() -> void:
	if glow_alpha > 0.001 and interactable:
		var strength := config.door_glow_opacity * glow_alpha
		if delivery_waiting:
			strength *= config.door_waiting_glow_multiplier
		var strip_count := 8
		var strip_width := config.door_glow_width / strip_count
		for strip in range(strip_count):
			var ratio := 1.0 - float(strip) / float(strip_count)
			var alpha := strength * ratio * ratio
			draw_rect(Rect2(strip * strip_width, 0, ceilf(strip_width) + 1.0, 360), Color(0.9, 0.96, 1.0, alpha))
	if delivery_waiting:
		var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.009) * 0.22
		var color := Color(0.82, 0.91, 0.96, pulse)
		# A small pixel arrow and parcel remain visible while the phone is open, but do not accept input.
		draw_rect(Rect2(16, 158, 18, 12), Color(0.12, 0.18, 0.24, 0.92))
		draw_rect(Rect2(16, 158, 18, 12), color, false, 2.0)
		draw_line(Vector2(38, 164), Vector2(55, 164), color, 3.0)
		draw_line(Vector2(49, 158), Vector2(55, 164), color, 3.0)
		draw_line(Vector2(49, 170), Vector2(55, 164), color, 3.0)
		if interactable:
			draw_string(PixelFont.get_font(), Vector2(10, 189), "外卖到了", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
