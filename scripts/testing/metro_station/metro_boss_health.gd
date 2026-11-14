extends Control
## Level 0-6 boss bar anchored to the active game viewport.

const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
const BAR := preload("res://shaders/ui/metro_boss_health.gdshader")
const BAR_SIZE := Vector2(324.0, 22.0)

var _fill: ShaderMaterial
var _ratio := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = .5
	anchor_right = .5
	anchor_top = .25
	anchor_bottom = .25
	offset_left = -BAR_SIZE.x * .5
	offset_right = BAR_SIZE.x * .5
	# Centre the fill at one quarter of the viewport height, with its name above.
	offset_top = -23.0
	offset_bottom = 14.0

	var title := Label.new()
	title.name = "BossName"
	title.text = "公司职员A"
	title.size = Vector2(BAR_SIZE.x, 14.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override(&"font", FONT.get_font())
	title.add_theme_font_size_override(&"font_size", 12)
	title.add_theme_color_override(&"font_color", Color("ff574d"))
	title.add_theme_color_override(&"font_shadow_color", Color(0.46, 0.025, 0.018, .8))
	title.add_theme_constant_override(&"shadow_offset_x", 0)
	title.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(title)

	var bar := ColorRect.new()
	bar.name = "HealthFill"
	bar.position.y = 12.0
	bar.size = BAR_SIZE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = ShaderMaterial.new()
	_fill.shader = BAR
	_fill.set_shader_parameter(&"size_px", BAR_SIZE)
	bar.material = _fill
	add_child(bar)


func set_health_ratio(ratio: float) -> void:
	if not is_equal_approx(ratio, _ratio):
		_ratio = clampf(ratio, 0.0, 1.0)
		_fill.set_shader_parameter(&"health_ratio", _ratio)


func dismiss() -> void:
	set_health_ratio(0.0)
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(self, "modulate:a", 0.0, .32)
	fade.tween_callback(get_parent().queue_free)
