extends RefCounted
## Native 12px Chinese glyphs for dialogue and world-anchored HUD text.
## The 9x9 bold face remains available to the global UI theme; its dense
## small Chinese glyphs are not used for these readability-critical labels.

const SOURCE: FontFile = preload("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
static var _font: FontFile


static func get_font() -> FontFile:
	if _font == null:
		_font = SOURCE.duplicate() as FontFile
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.keep_rounding_remainders = false
		_font.oversampling = 1.0
	return _font
