class_name PhoneShopUI
extends RefCounted

## 手机商店页共享绘制工具。所有函数接收目标 CanvasItem（self），
## 让 bedroom_phone 与 QuicklinkContent 都能绘制到自己的画布，避免重复实现。


static func draw_app_header(canvas: CanvasItem, back_rect: Rect2, chinese: String, english: String, font: Font, chinese_size: int, english_size: int) -> void:
	canvas.draw_rect(back_rect, Color("303440"))
	canvas.draw_string(font, Vector2(14, 56), "‹ 返回", HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color("b0afb6"))
	canvas.draw_string(font, Vector2(68, 51), chinese, HORIZONTAL_ALIGNMENT_LEFT, 69, chinese_size, Color("b8b5bd"))
	canvas.draw_string(font, Vector2(68, 64), english, HORIZONTAL_ALIGNMENT_LEFT, 69, english_size, Color("747985"))


static func draw_pixel_product_card(canvas: CanvasItem, rect: Rect2, icon: Texture2D, title: String, description: String, font: Font) -> void:
	canvas.draw_rect(rect, Color("151d25"))
	canvas.draw_rect(rect, Color("3f6478"), false, 2.0)
	canvas.draw_line(rect.position + Vector2(5, 5), rect.position + Vector2(18, 5), Color("7696a9"), 1.0)
	canvas.draw_texture(icon, rect.position + Vector2(6, 9))
	canvas.draw_string(font, rect.position + Vector2(42, 22), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 10, Color("c7cbd0"))
	canvas.draw_string(font, rect.position + Vector2(42, 37), description, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 7, Color("7f909b"))


static func draw_pixel_shop_button(canvas: CanvasItem, rect: Rect2, label: String, disabled: bool, hovered: bool, font: Font) -> void:
	var fill := Color("252d35") if disabled else (Color("3c6479") if hovered else Color("2d4b5d"))
	var border := Color("46535e") if disabled else (Color("a3bfd0") if hovered else Color("62859a"))
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.0)
	# Corner cuts keep the card visibly pixel-built without changing its hit box.
	canvas.draw_rect(Rect2(rect.position, Vector2(2, 2)), Color("111721"))
	canvas.draw_rect(Rect2(rect.end - Vector2(2, 2), Vector2(2, 2)), Color("111721"))
	var label_size := 5 if label.length() > 7 else 7
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 11), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, Color("6d737a") if disabled else Color("d0d9de"))
