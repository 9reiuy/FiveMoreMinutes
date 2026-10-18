extends CanvasLayer
var label: Label
var changing := false

func _ready() -> void:
	label = Label.new()
	label.position = Vector2(12,12)
	label.add_theme_font_size_override("font_size",10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	refresh()

func refresh() -> void:
	var world := get_parent()
	label.text = "四骨架独立试玩 · %s · 种子 %d · 不保存\nF1–F4 骨架 / F5 上一种子 / F6 下一种子\nWASD 移动 · 鼠标射击 · R 换弹 · E 交互" % [world.preview_topology,world.skeleton_source.get("seed",world.seed)]

func _unhandled_input(event: InputEvent) -> void:
	var world := get_parent()
	if changing or world.floor_transition_in_progress or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_F1 and event.keycode <= KEY_F4:
		world.skeleton_type = world.TYPES[event.keycode-KEY_F1]
	elif event.keycode == KEY_F5 or event.keycode == KEY_F6:
		world.seed = 1001 + posmod(world.seed-1001+(-1 if event.keycode == KEY_F5 else 1),10)
	else:
		return
	changing = true
	world.layout_file = ""
	world.base_floor_seed = world.seed
	world.regenerate(world.seed)
	refresh()
	changing = false
	get_viewport().set_input_as_handled()
