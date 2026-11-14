extends Control
## Cached drawing commands: only rebuild when the message or viewport changes.
## Broad, nested low-alpha outlines form the soft light spill on the UI canvas.
## This requires neither 3D bloom nor a screen copy / second world viewport.
const GLOW_RINGS := [
	Vector2(32, 0.012), Vector2(28, 0.018), Vector2(24, 0.025),
	Vector2(20, 0.036), Vector2(17, 0.050), Vector2(14, 0.070),
	Vector2(11, 0.100), Vector2(8, 0.140), Vector2(6, 0.180),
	Vector2(4, 0.230), Vector2(2, 0.280),
]
var _font: Font
var _lines := PackedStringArray()
var _font_size := 16
var _ink := Color.WHITE
var _glow := false


func _ready() -> void:
	resized.connect(queue_redraw)


func configure(font: Font, text: String, font_size: int, color: Color, glow: bool) -> void:
	_font = font
	_lines = text.split("\n")
	_font_size = font_size
	_ink = color
	_glow = glow
	queue_redraw()


func _draw() -> void:
	if _font == null or _lines.is_empty():
		return
	var height := _font.get_height(_font_size)
	var baseline := (size.y - height * _lines.size()) * 0.5 + _font.get_ascent(_font_size)
	for index in _lines.size():
		var text := _lines[index]
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var at := Vector2((size.x - width) * 0.5, baseline + index * height)
		if _glow:
			var radius_scale := clampf(float(_font_size) / 176.0, 0.65, 1.30)
			for ring in GLOW_RINGS:
				draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size,
					maxi(1, roundi(ring.x * radius_scale)), Color(_ink, ring.y))
			# A white inner bloom leads into the wider neutral light spill.
			draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size,
				maxi(1, roundi(2.0 * radius_scale)), Color(_ink.lerp(Color.WHITE, 0.8), 0.36))
		else:
			draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 1, _ink)
			draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _ink)
