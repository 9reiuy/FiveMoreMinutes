class_name PhoneShopUI
extends RefCounted

## 手机商店页共享绘制工具。所有函数接收目标 CanvasItem（self），
## 让 bedroom_phone 与 QuicklinkContent 都能绘制到自己的画布，避免重复实现。
## 16bit 像素风：统一用“高光/暗部斜切面 + 硬边框”的像素斜面语言，
## 参考跑腿类 APP 的顶部栏/商品列表/购买按钮结构，不改变任何命中矩形。

# 16bit 调色板：深藏青底 + 青蓝主色 + 琥珀点缀（价格/促销感）。
const ACCENT := Color("4fb3c9")
const ACCENT_DIM := Color("2c6a80")
const AMBER := Color("d9a441")
const PANEL_DARK := Color("101823")
const PANEL_BORDER := Color("0a0e15")


static func draw_app_header(canvas: CanvasItem, screen: Rect2, back_rect: Rect2, pointer: Vector2, chinese: String, english: String, font: Font, chinese_size: int, english_size: int, triangle_anim_elapsed: float = 0.0) -> void:
	# 顶部栏保留16bit色带；返回这个普通文本Action使用共享Option视觉。
	# 色带宽度严格等于屏幕可显示区宽度（screen），不再硬编码 160 导致超出手机框。
	var band := Rect2(screen.position.x, 32, screen.size.x, 38)
	canvas.draw_rect(band, Color("1b2b3d"))
	canvas.draw_rect(Rect2(screen.position.x, 66, screen.size.x, 2), Color("0b121c"))
	canvas.draw_rect(Rect2(screen.position.x, 68, screen.size.x, 1), ACCENT_DIM)
	# pointer 为手机局部坐标的鼠标位置（绘制画布可能已被 ScreenClip 平移）。
	PixelOptionGroup.draw_custom_option(canvas, back_rect, "‹ 返回", back_rect.has_point(pointer), true, font, 10, triangle_anim_elapsed)
	canvas.draw_string(font, Vector2(68, 51), chinese, HORIZONTAL_ALIGNMENT_LEFT, 69, chinese_size, Color("e3ebf0"))
	canvas.draw_string(font, Vector2(68, 64), english, HORIZONTAL_ALIGNMENT_LEFT, 69, english_size, Color("7fa0b0"))


static func draw_pixel_product_card(canvas: CanvasItem, rect: Rect2, icon: Texture2D, title: String, description: String, font: Font) -> void:
	# 商品卡：深色底 + 硬边框 + 左上高光/右下暗部的像素斜面，图标放在内嵌小面板里。
	canvas.draw_rect(rect, PANEL_DARK)
	canvas.draw_rect(rect.grow(-2), Color("182431"))
	canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("3e627a"), 1.0)
	canvas.draw_line(rect.position + Vector2(0, rect.size.y - 1), rect.end, PANEL_BORDER, 1.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 7), Vector2(32, 32)), Color("0c141d"))
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 7), Vector2(32, 32)), Color("2c4658"), false, 1.0)
	canvas.draw_texture(icon, rect.position + Vector2(6, 9))
	canvas.draw_rect(Rect2(rect.position + Vector2(40, 12), Vector2(rect.size.x - 48, 1)), ACCENT_DIM)
	canvas.draw_string(font, rect.position + Vector2(42, 22), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 10, Color("dfe6ea"))
	canvas.draw_string(font, rect.position + Vector2(42, 37), description, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 7, Color("8aa3b0"))


static func draw_pixel_shop_button(canvas: CanvasItem, rect: Rect2, label: String, disabled: bool, hovered: bool, font: Font, triangle_anim_elapsed: float = 0.0) -> void:
	# 商品卡保持不变；购买这个普通文本Action使用共享Option语言，命中矩形不变。
	var label_size := 5 if label.length() > 7 else 7
	PixelOptionGroup.draw_custom_option(canvas, rect, label, hovered, not disabled, font, label_size, triangle_anim_elapsed)
