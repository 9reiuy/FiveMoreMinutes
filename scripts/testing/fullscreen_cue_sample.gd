extends Control
## Independent production-art test room for the reusable cut-in layer.
const LAB := preload("res://scenes/testing/GameTestLab.tscn")
const CUE := preload("res://scenes/ui/fullscreen_player_cue.tscn")
const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")

@export var autoplay := true
@export var whitebox := false
var lab: Control
var cue: CanvasLayer
var ready_sample := false
var hint_layer: CanvasLayer
var last_selection := 1
var _sequence_generation := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab = LAB.instantiate()
	add_child(lab)
	while not lab.ready_world:
		await get_tree().process_frame
	lab.mode.select(0 if whitebox else 1)
	lab.seed_box.value = 42001
	lab.enemies.value = 4
	lab.checks.ai.button_pressed = true
	lab.checks.special.button_pressed = false
	lab.checks.uncapped.button_pressed = false
	await lab.rebuild()
	lab.panel.hide()
	lab.hud.hide()
	cue = CUE.instantiate()
	add_child(cue)
	_build_hint()
	ready_sample = true
	if autoplay:
		await get_tree().create_timer(1.2).timeout
		if is_inside_tree():
			play_selection(1)


func _build_hint() -> void:
	hint_layer = CanvasLayer.new()
	hint_layer.layer = 170
	add_child(hint_layer)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 12
	label.offset_top = -34
	label.offset_right = -12
	label.offset_bottom = -8
	label.text = "全屏跳切 · 文字出现时固定 0.05×\n1 背后    2 保持 / 移动    3 撤离    R 重播    F1 隐藏说明    Esc 退出"
	label.add_theme_font_override(&"font", FONT.get_font())
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color("dceaf2"))
	label.add_theme_color_override(&"font_shadow_color", Color("080c14"))
	label.add_theme_constant_override(&"shadow_outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_layer.add_child(label)


func play_selection(selection: int) -> void:
	if not ready_sample:
		return
	last_selection = selection
	_sequence_generation += 1
	var generation := _sequence_generation
	if selection == 2:
		cue.play_cue("保持", 0.34)
		await cue.cue_finished
		if not is_inside_tree() or generation != _sequence_generation:
			return
		await get_tree().create_timer(0.085).timeout
		if is_inside_tree() and generation == _sequence_generation:
			cue.play_cue("移动", 0.34)
	else:
		cue.play_cue("撤离" if selection == 3 else "背后")


func _input(event: InputEvent) -> void:
	if not ready_sample or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: play_selection(1)
		KEY_2: play_selection(2)
		KEY_3: play_selection(3)
		KEY_R: play_selection(last_selection)
		KEY_F1: hint_layer.visible = not hint_layer.visible
		KEY_ESCAPE:
			cue.cancel()
			get_tree().quit()
		_: return
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_sequence_generation += 1
