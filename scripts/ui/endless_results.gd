class_name EndlessResults
extends Control

signal restart_requested
signal main_menu_requested

var summary: Dictionary = {}

@onready var title: Label = $Panel/Content/Title
@onready var stats: Label = $Panel/Content/Stats
@onready var restart_button: Button = $Panel/Content/Buttons/Restart
@onready var menu_button: Button = $Panel/Content/Buttons/Menu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title.add_theme_font_override("font", PixelFont.get_font())
	stats.add_theme_font_override("font", PixelFont.get_font())
	for button in [restart_button, menu_button]:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", _button_box(Color("17202a"), Color("517b98")))
		button.add_theme_stylebox_override("hover", _button_box(Color("243543"), Color("8caec1")))
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	stats.text = "生存时间  %s\n最终等级  %d" % [_format_duration(float(summary.get("survival_seconds", 0.0))), int(summary.get("level", 1))]


func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_content_margin_all(7.0)
	return box


func _format_duration(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]
