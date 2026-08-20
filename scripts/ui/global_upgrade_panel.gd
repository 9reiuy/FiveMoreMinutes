class_name GlobalUpgradePanel
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CATALOG := preload("res://scripts/data/permanent_upgrade_catalog.gd")

signal progression_changed

@export var config: DemoConfig

@onready var ram_label: Label = $RAM
@onready var option_group: PixelOptionGroup = $OptionGroup
@onready var upgrade_list: VBoxContainer = $UpgradeScroll/UpgradeList

var progression_state: Dictionary = {}
var purchase_options: Array[Button] = []


func _ready() -> void:
	ram_label.add_theme_font_override("font", PixelFont.get_font())
	if not progression_state.is_empty():
		_rebuild()


func configure(state: Dictionary) -> void:
	progression_state = state
	CATALOG.ensure_state(progression_state)
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	option_group.clear_options()
	purchase_options.clear()
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()
	ram_label.text = "RAM  %d" % int(progression_state.get("ram", 0))
	for id: String in CATALOG.IDS:
		upgrade_list.add_child(_create_upgrade_card(id))
	option_group.register_options(purchase_options)


func _create_upgrade_card(id: String) -> Control:
	var level := CATALOG.get_level(progression_state, id)
	var capped := level >= config.permanent_upgrade_max_level
	var price := CATALOG.get_price(level, config)
	var ram := int(progression_state.get("ram", 0))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(292, 74)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101823")
	panel_style.border_color = Color("3e627a")
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", panel_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.texture = CATALOG.get_icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 1)
	row.add_child(text_column)
	var title := Label.new()
	title.add_theme_font_override("font", PixelFont.get_font())
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("c1cbd1"))
	title.text = "%s  %d/%d" % [CATALOG.get_display_name(id), level, config.permanent_upgrade_max_level]
	text_column.add_child(title)
	var description := Label.new()
	description.add_theme_font_override("font", PixelFont.get_font())
	description.add_theme_font_size_override("font_size", 8)
	description.add_theme_color_override("font_color", Color("718894"))
	description.text = CATALOG.get_description(id)
	text_column.add_child(description)
	var effect := Label.new()
	effect.add_theme_font_override("font", PixelFont.get_font())
	effect.add_theme_font_size_override("font_size", 8)
	effect.add_theme_color_override("font_color", Color("8799a4"))
	effect.text = "当前：%s    下一级：%s" % [
		CATALOG.get_effect_value(id, level, config),
		"--" if capped else CATALOG.get_effect_value(id, level + 1, config),
	]
	text_column.add_child(effect)
	var purchase := Button.new()
	purchase.z_index = 2
	purchase.custom_minimum_size = Vector2(76, 38)
	purchase.focus_mode = Control.FOCUS_NONE
	purchase.flat = true
	purchase.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	purchase.add_theme_font_override("font", PixelFont.get_font())
	purchase.add_theme_font_size_override("font_size", 9)
	purchase.add_theme_color_override("font_color", Color("8fb4b5") if not capped and ram >= price else Color("465b62"))
	purchase.add_theme_color_override("font_hover_color", Color("d5dde0"))
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		purchase.add_theme_stylebox_override(state, empty)
	purchase.text = "MAX" if capped else ("升级\n%d RAM" % price if ram >= price else "RAM不足\n需要%d" % price)
	purchase.pressed.connect(_purchase.bind(id))
	row.add_child(purchase)
	purchase_options.append(purchase)
	return card


func _purchase(id: String) -> void:
	var result := CATALOG.purchase(progression_state, id, config)
	if result == &"purchased":
		SFX.play_event(&"purchase")
		progression_changed.emit()
	else:
		SFX.play_event(&"forbidden")
	_rebuild()
