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
		# 纯文字按钮：无像素底框，悬停仅变亮。
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_color_override("font_color", Color("8fb3bc"))
		button.add_theme_color_override("font_hover_color", Color("d5dde0"))
		button.add_theme_color_override("font_pressed_color", Color("d5dde0"))
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	stats.text = "生存时间  %s\n最终等级  %d" % [_format_duration(float(summary.get("survival_seconds", 0.0))), int(summary.get("level", 1))]


func _format_duration(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [total / 60, total % 60]
