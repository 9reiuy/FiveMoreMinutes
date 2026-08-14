class_name ComputerWindowShell
extends RefCounted

const TITLE_HEIGHT := 15.0
const BUTTON_SIZE := Vector2(9, 9)


static func button_rect(window_rect: Rect2, action: String) -> Rect2:
	var index: int = int({"minimize": 0, "maximize": 1, "close": 2}.get(action, -1))
	if index < 0:
		return Rect2()
	return Rect2(window_rect.end.x - 36.0 + index * 12.0, window_rect.position.y + 3.0, BUTTON_SIZE.x, BUTTON_SIZE.y)


static func content_rect(window_rect: Rect2) -> Rect2:
	return Rect2(window_rect.position + Vector2(1, TITLE_HEIGHT + 1), window_rect.size - Vector2(2, TITLE_HEIGHT + 2))


static func draw(canvas: CanvasItem, window_rect: Rect2, title_text: String, hovered_action: String = "", maximized: bool = false) -> void:
	canvas.draw_rect(window_rect, Color("10131a"))
	canvas.draw_rect(window_rect, Color("4d5875"), false, 1.0)
	var title_rect := Rect2(window_rect.position, Vector2(window_rect.size.x, TITLE_HEIGHT))
	canvas.draw_rect(title_rect, Color("57628a"))
	canvas.draw_string(PixelFont.get_font(), title_rect.position + Vector2(5, 11), title_text, HORIZONTAL_ALIGNMENT_LEFT, int(window_rect.size.x - 46), 8, Color("d8dde8"))
	for action in ["minimize", "maximize", "close"]:
		var rect := button_rect(window_rect, action)
		var active: bool = hovered_action == str(action)
		canvas.draw_rect(rect, Color("5d688e") if active else Color("39415c"))
		canvas.draw_rect(rect, Color("aab6d1") if active else Color("7c88a8"), false, 1.0)
		match action:
			"minimize":
				canvas.draw_rect(Rect2(rect.position + Vector2(2, 6), Vector2(5, 1)), Color("c8d0e0"))
			"maximize":
				canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(5, 5)), Color("c8d0e0"), false, 1.0)
				if maximized:
					canvas.draw_rect(Rect2(rect.position + Vector2(1, 3), Vector2(5, 5)), Color("c8d0e0"), false, 1.0)
			"close":
				canvas.draw_line(rect.position + Vector2(2, 2), rect.end - Vector2(2, 2), Color("c8d0e0"), 1.0)
				canvas.draw_line(Vector2(rect.end.x - 2, rect.position.y + 2), rect.position + Vector2(2, rect.size.y - 2), Color("c8d0e0"), 1.0)
