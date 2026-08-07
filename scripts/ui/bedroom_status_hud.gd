class_name BedroomStatusHUD
extends Control

@export var config: DemoConfig

var stress_value := 0


func set_stress(value: int) -> void:
	stress_value = clampi(value, 0, config.stress_max)
	queue_redraw()


func _draw() -> void:
	var font := PixelFont.get_font()
	var panel := Rect2(12, 12, 144, 42)
	draw_rect(panel, Color(0.03, 0.045, 0.065, 0.88))
	draw_rect(panel, Color("517b98"), false, 2.0)
	# Original geometric pixel head icon; no external asset is required.
	draw_rect(Rect2(19, 21, 18, 18), Color("314a60"))
	draw_rect(Rect2(22, 18, 12, 4), Color("718da0"))
	draw_rect(Rect2(23, 26, 3, 3), Color("b6c8d0"))
	draw_rect(Rect2(30, 26, 3, 3), Color("b6c8d0"))
	draw_line(Vector2(24, 34), Vector2(32, 34), Color("8ba2ae"), 2.0)
	draw_string(font, Vector2(43, 28), "压力值  %d / %d" % [stress_value, config.stress_max], HORIZONTAL_ALIGNMENT_LEFT, 104, 10, Color("c4cdd2"))
	var filled := ceili(float(stress_value) / maxf(config.stress_max, 1.0) * 10.0)
	for segment in range(10):
		var segment_color := Color("5f8298") if segment < filled else Color("202d38")
		draw_rect(Rect2(44 + segment * 9, 37, 7, 6), segment_color)
