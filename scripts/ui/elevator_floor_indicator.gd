extends Control

const INK := Color("e6dfcb")
const QUIET := Color("7d8587")
const AMBER := Color("ffbd70")
var floor_index := 0
var target_index := 0
var floor_count := 1
var travelling := false
var retry := false

func present(current: int, target: int, count: int, moving: bool, retrying: bool) -> void:
	floor_index = current
	target_index = target
	floor_count = maxi(count, maxi(current, target) + 1)
	travelling = moving
	retry = retrying
	queue_redraw()

func _draw() -> void:
	var font := PixelFont.get_font()
	var center_y := roundf(size.y * 0.47)
	var x := roundf(maxf(29.0, size.x * 0.075))
	var low := maxi(-1, floor_index - 3)
	var high := mini(floor_count - 1, maxi(floor_index + 4, low + 6))
	low = maxi(-1, mini(low, high - 6))
	draw_line(Vector2(x + 26, center_y - 87), Vector2(x + 26, center_y + 80), Color("333a3e"), 1.0)
	draw_string(font, Vector2(x - 14, center_y - 96), "LIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, QUIET)
	for index in range(low, high + 1):
		var current := index == floor_index
		var y := center_y + float(high + low - 2 * index) * 10.0
		var text := _floor_name(index)
		var font_size := 26 if current else 13
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if current:
			draw_rect(Rect2(x - 21, y - 14, 44, 29), Color("272728"))
			draw_line(Vector2(x - 21, y - 14), Vector2(x - 21, y + 15), AMBER, 2.0)
		draw_string(font, Vector2(roundf(x - width * 0.5), roundf(y + (8.0 if current else 4.0))), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK if current else QUIET)
		if travelling and index == target_index and not current:
			draw_circle(Vector2(x + 26, y), 2.0, AMBER)
	if travelling:
		var status := "重试" if retry else ("上行" if target_index > floor_index else "下行")
		draw_string(font, Vector2(x - 21, center_y + 99), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AMBER)
		draw_string(font, Vector2(x - 21, center_y + 115), "%s > %s" % [_floor_name(floor_index), _floor_name(target_index)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)

func _floor_name(index: int) -> String:
	return "L" if index < 0 else str(index + 1)
