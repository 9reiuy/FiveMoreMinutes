extends CanvasLayer
const GENERATOR = preload("res://scripts/dream/preview/office_flank_generator.gd")
var status: Label
var changing := false

func _ready() -> void:
	status = Label.new()
	status.position = Vector2(16, 12)
	status.add_theme_font_size_override("font_size", 10)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	_refresh()

func _refresh() -> void:
	status.text = "独立预览 · 种子 %d · 不保存进度\nF1–F5 切换 / F6 随机 · WASD 移动\n鼠标射击 · R 换弹 · E 交互" % get_parent().seed

func _unhandled_input(event: InputEvent) -> void:
	if changing or get_parent().floor_transition_in_progress or not event is InputEventKey or not event.pressed or event.echo:
		return
	var value := -1
	if event.keycode >= KEY_F1 and event.keycode <= KEY_F5:
		value = GENERATOR.SEEDS[event.keycode - KEY_F1]
	elif event.keycode == KEY_F6:
		value = int(Time.get_ticks_usec() % 2147483647)
	if value < 0:
		return
	changing = true
	get_parent().seed = value
	get_parent().base_floor_seed = value
	get_parent().regenerate(value)
	_refresh()
	changing = false
	get_viewport().set_input_as_handled()
