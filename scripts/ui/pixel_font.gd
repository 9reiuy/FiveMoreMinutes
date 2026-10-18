class_name PixelFont
extends RefCounted

## Code-drawn UI and Control themes use the same licensed Chinese pixel font.
const FONT: Font = preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")


static func get_font() -> Font:
	return FONT
