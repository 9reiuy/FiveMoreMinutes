extends PanelContainer
## A short, nearby instruction. Never a permanent corner HUD.
const FONT = preload("res://scripts/ui/crisp_interaction_font.gd")
var label: Label
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("101722e8"); skin.border_color = Color("718394")
	skin.set_border_width_all(1); skin.content_margin_left = 8; skin.content_margin_right = 8
	skin.content_margin_top = 5; skin.content_margin_bottom = 5
	add_theme_stylebox_override("panel", skin)
	label = Label.new(); label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT.get_font()); label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("d5dce2")); add_child(label)
	hide()
func present(text: String, anchor: Vector2) -> void:
	if text.is_empty(): hide(); return
	label.text = text; reset_size()
	var extent := get_combined_minimum_size()
	var screen := get_viewport_rect().size
	position = Vector2(clampf(anchor.x - extent.x * .5, 8, screen.x - extent.x - 8), clampf(anchor.y, 8, screen.y - extent.y - 8)).round()
	show()
func _process(_delta: float) -> void:
	if get_tree().paused: hide()
