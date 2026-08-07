class_name PixelFont
extends RefCounted

## Code-drawn UI and Control themes use the same licensed Chinese pixel font.
const FONT: Font = preload("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf")


static func get_font() -> Font:
	return FONT
