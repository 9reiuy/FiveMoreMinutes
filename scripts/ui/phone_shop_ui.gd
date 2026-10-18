class_name PhoneShopUI
extends RefCounted

## 手机商店页共享绘制工具。所有函数接收目标 CanvasItem（self），
## 让 bedroom_phone 与 QuicklinkContent 都能绘制到自己的画布，避免重复实现。
## 16bit 像素风：统一用“高光/暗部斜切面 + 硬边框”的像素斜面语言，
## 参考跑腿类 APP 的顶部栏/商品列表/购买按钮结构，不改变任何命中矩形。

# 16bit 调色板：深藏青底 + 青蓝主色 + 琥珀点缀（价格/促销感）。
const ACCENT := Color("91a8cf")
const ACCENT_DIM := Color("596b93")
const AMBER := Color("d9a441")
const PANEL_DARK := Color("252e4b")
const PANEL_BORDER := Color("11182b")


static func draw_app_header(canvas: CanvasItem, screen: Rect2, back_rect: Rect2, pointer: Vector2, chinese: String, english: String, font: Font, chinese_size: int, english_size: int) -> void:
	# 顶部栏与返回按钮恢复Phone自身的16bit像素斜面视觉。
	# 色带宽度严格等于屏幕可显示区宽度（screen），不再硬编码 160 导致超出手机框。
	var band := Rect2(screen.position.x, 32, screen.size.x, 38)
	canvas.draw_rect(band, Color("394568"))
	canvas.draw_rect(Rect2(screen.position.x, 66, screen.size.x, 2), Color("11182b"))
	canvas.draw_rect(Rect2(screen.position.x, 68, screen.size.x, 1), ACCENT_DIM)
	# pointer 为手机局部坐标的鼠标位置（绘制画布可能已被 ScreenClip 平移）。
	var back_fill := Color("6579a4") if back_rect.has_point(pointer) else Color("4b587d")
	canvas.draw_rect(back_rect, back_fill)
	canvas.draw_line(back_rect.position, back_rect.position + Vector2(back_rect.size.x, 0), Color("a8bce0"), 1.0)
	canvas.draw_line(back_rect.position + Vector2(0, back_rect.size.y - 1), back_rect.end, Color("1b2238"), 1.0)
	canvas.draw_string(font, Vector2(14, 56), "‹ 返回", HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color("d8e6ec"))
	canvas.draw_string(font, Vector2(68, 51), chinese, HORIZONTAL_ALIGNMENT_LEFT, 69, chinese_size, Color("e3ebf0"))
	canvas.draw_string(font, Vector2(68, 64), english, HORIZONTAL_ALIGNMENT_LEFT, 69, english_size, Color("7fa0b0"))


static func draw_pixel_product_card(canvas: CanvasItem, rect: Rect2, icon: Texture2D, title: String, description: String, font: Font) -> void:
	# 商品卡：深色底 + 硬边框 + 左上高光/右下暗部的像素斜面，图标放在内嵌小面板里。
	canvas.draw_rect(rect, PANEL_DARK)
	canvas.draw_rect(rect.grow(-2), Color("303a5a"))
	canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("8197bd"), 1.0)
	canvas.draw_line(rect.position + Vector2(0, rect.size.y - 1), rect.end, PANEL_BORDER, 1.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 7), Vector2(32, 32)), Color("161d32"))
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 7), Vector2(32, 32)), Color("667aa4"), false, 1.0)
	canvas.draw_texture(icon, rect.position + Vector2(6, 9))
	canvas.draw_rect(Rect2(rect.position + Vector2(40, 12), Vector2(rect.size.x - 48, 1)), ACCENT_DIM)
	canvas.draw_string(font, rect.position + Vector2(42, 22), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 10, Color("dfe6ea"))
	canvas.draw_string(font, rect.position + Vector2(42, 37), description, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 7, Color("8aa3b0"))


static func draw_pixel_shop_button(canvas: CanvasItem, rect: Rect2, label: String, disabled: bool, hovered: bool, font: Font) -> void:
	# Phone商店按钮使用原有像素斜面；不接入主菜单Triangle/SelectionFrame/Scale。
	var fill: Color
	var top_light: Color
	var bottom_dark: Color
	if disabled:
		fill = Color("2a3041")
		top_light = Color("444b61")
		bottom_dark = Color("111522")
	elif hovered:
		fill = Color("687ca9")
		top_light = Color("b3c5e5")
		bottom_dark = Color("2a3453")
	else:
		fill = Color("4b587d")
		top_light = Color("8298bf")
		bottom_dark = Color("222b46")
	canvas.draw_rect(rect, fill)
	canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), top_light, 1.0)
	canvas.draw_line(rect.position, rect.position + Vector2(0, rect.size.y), top_light.darkened(0.25), 1.0)
	canvas.draw_line(rect.position + Vector2(0, rect.size.y - 1), rect.end, bottom_dark, 1.0)
	canvas.draw_line(rect.position + Vector2(rect.size.x - 1, 0), rect.end - Vector2(0, 1), bottom_dark, 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(2, 2)), Color("0b1119"))
	canvas.draw_rect(Rect2(rect.end - Vector2(2, 2), Vector2(2, 2)), Color("0b1119"))
	var label_size := 5 if label.length() > 7 else 7
	var label_color := Color("5f666e") if disabled else (Color("f2f7f9") if hovered else Color("d0e2e9"))
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 11), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, label_color)
