class_name DreamDialogueGlyphFallFX
extends Control

## Visual effect spawned when dialogue typewriter is interrupted.
## Already-revealed characters detach from the source label, tumble downward
## with randomized initial velocities, gravity, and angular rotation, and fade
## out smoothly at the end of their lifetime. Strictly pure UI presentation.

const GRAVITY: float = 520.0
const LIFETIME: float = 0.5
const FADE_START: float = 0.35
const FADE_DURATION: float = 0.15
const FONT_RES := preload("res://scripts/ui/crisp_interaction_font.gd")

class GlyphData:
	var label: Label
	var pos: Vector2
	var vel: Vector2
	var rot: float = 0.0
	var angular_velocity: float = 0.0

var elapsed: float = 0.0
var _glyphs: Array[GlyphData] = []


static func spawn_from_label(parent: Node, source_label: Label, visible_count: int) -> Node:
	if source_label == null:
		return null

	var fx: Control = (load("res://scripts/ui/dialogue/dream_dialogue_glyph_fall_fx.gd") as GDScript).new()
	fx.name = "DreamDialogueGlyphFallFX"
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.top_level = true
	fx.position = Vector2.ZERO

	if parent != null:
		parent.add_child(fx)
	elif source_label.is_inside_tree() and source_label.get_tree().root != null:
		source_label.get_tree().root.add_child(fx)

	var full_text: String = source_label.text
	var total_len: int = full_text.length()
	var count: int = total_len if visible_count < 0 else mini(visible_count, total_len)

	var font: Font = FONT_RES.get_font()
	var font_color: Color = source_label.get_theme_color(&"font_color")

	for i in range(count):
		var char_str: String = full_text.substr(i, 1)
		if char_str.strip_edges().is_empty():
			continue

		var bounds: Rect2 = source_label.get_character_bounds(i)
		var glyph_label := Label.new()
		glyph_label.name = "Glyph_%d" % i
		glyph_label.text = char_str
		glyph_label.add_theme_font_override(&"font", font)
		glyph_label.add_theme_font_size_override(&"font_size", 12)
		if font_color.a > 0.0:
			glyph_label.add_theme_color_override(&"font_color", font_color)
		glyph_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var start_pos: Vector2 = source_label.global_position + bounds.position
		glyph_label.global_position = start_pos
		if bounds.size.x > 0.0 and bounds.size.y > 0.0:
			glyph_label.pivot_offset = bounds.size * 0.5

		fx.add_child(glyph_label)

		var g := GlyphData.new()
		g.label = glyph_label
		g.pos = start_pos
		g.vel = Vector2(randf_range(-40.0, 40.0), randf_range(20.0, 60.0))
		g.angular_velocity = randf_range(-5.0, 5.0)
		fx._glyphs.append(g)

	return fx


func _process(delta: float) -> void:
	elapsed += delta
	for g in _glyphs:
		g.pos += g.vel * delta
		g.vel.y += GRAVITY * delta
		g.rot += g.angular_velocity * delta
		if is_instance_valid(g.label):
			g.label.global_position = g.pos
			g.label.rotation = g.rot

	if elapsed > FADE_START:
		var alpha: float = clampf((LIFETIME - elapsed) / FADE_DURATION, 0.0, 1.0)
		modulate.a = alpha

	if elapsed >= LIFETIME:
		queue_free()
