extends Control
## Presents authored choices and the separate typing interrupt button.

signal interrupt_pressed

const ROW_SHADER := preload("res://shaders/ui/dialogue_choice_halftone.gdshader")
const READABLE_FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
const MIN_ROW_WIDTH := 168.0
const ROW_HEIGHT := 23.0
const ROW_GAP := 4
const RIGHT_MARGIN := 12.0
const BOTTOM := 284.0
const LABEL_LEFT := 22.0
const LABEL_RIGHT := 55.0
const SLIDE_SECONDS := 0.25
const INTERRUPT_SLIDE_SECONDS := 0.16

@onready var interrupt_button: Button = $InterruptChoice

var interactive := false
var _rows: VBoxContainer
var _navigation: PixelOptionGroup
var _options: Array[Button] = []
var _materials: Dictionary[Button, ShaderMaterial] = {}
var _selection := -2
var _rest_position := Vector2.ZERO
var _slide: Tween
var _interrupt_slide: Tween
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _owns_mouse_mode := false


func _ready() -> void:
	set_process(false)
	visibility_changed.connect(_sync_mouse_mode)
	interrupt_button.size = Vector2(MIN_ROW_WIDTH, ROW_HEIGHT)
	interrupt_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	interrupt_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interrupt_button.add_theme_font_override(&"font", READABLE_FONT.get_font())
	interrupt_button.add_theme_font_size_override(&"font_size", 12)
	interrupt_button.add_theme_color_override(&"font_color", Color("ff7779"))
	for state in [&"font_hover_color", &"font_hover_pressed_color", &"font_pressed_color", &"font_focus_color"]:
		interrupt_button.add_theme_color_override(state, Color("ffa19c"))
	_style_row(interrupt_button, MIN_ROW_WIDTH)
	var material := _materials[interrupt_button]
	material.set_shader_parameter(&"selected", 1.0)
	material.set_shader_parameter(&"selected_fill", Vector3(0.17, 0.038, 0.048))
	interrupt_button.mouse_entered.connect(_paint_interrupt)
	interrupt_button.mouse_exited.connect(_paint_interrupt)
	interrupt_button.focus_entered.connect(_paint_interrupt)
	interrupt_button.focus_exited.connect(_paint_interrupt)
	interrupt_button.pressed.connect(func(): interrupt_pressed.emit())
	_paint_interrupt()


func _sync_mouse_mode() -> void:
	if not is_visible_in_tree():
		_restore_mouse_mode()
	elif not _owns_mouse_mode:
		_mouse_mode_before = Input.mouse_mode
		_owns_mouse_mode = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restore_mouse_mode() -> void:
	if not _owns_mouse_mode:
		return
	_owns_mouse_mode = false
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = _mouse_mode_before


func _exit_tree() -> void:
	_restore_mouse_mode()


func attach(rows: VBoxContainer, navigation: PixelOptionGroup) -> void:
	_rows = rows
	_navigation = navigation
	_navigation.hide()
	_rows.reparent(self, false)
	_rows.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override(&"separation", ROW_GAP)
	conceal()


func prepare(options: Array[Button]) -> void:
	_conceal_choices()
	if not interrupt_button.visible:
		hide()
	_options = options
	var width := MIN_ROW_WIDTH
	var count := 0
	for button in options:
		if not button.visible:
			continue
		count += 1
		var label_width := button.get_theme_font(&"font").get_string_size(button.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size(&"font_size")).x
		width = maxf(width, label_width + LABEL_LEFT + LABEL_RIGHT)
	width = minf(ceilf(width), 268.0)
	for button in options:
		if button.visible:
			_style_row(button, width)
	var height := count * ROW_HEIGHT + maxi(0, count - 1) * ROW_GAP
	_rows.size = Vector2(width, height)
	_rest_position = Vector2(640.0 - RIGHT_MARGIN - width, maxf(58.0, BOTTOM - height))
	_rows.position = _rest_position
	_selection = -2
	_paint_selection(-1)


func _style_row(button: Button, width: float) -> void:
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = button.text if width >= 268.0 else ""
	var inset := StyleBoxEmpty.new()
	inset.content_margin_left = LABEL_LEFT
	inset.content_margin_right = LABEL_RIGHT
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, inset)
	button.add_theme_color_override(&"font_disabled_color", Color("87949b"))
	var material: ShaderMaterial = _materials.get(button)
	if material == null:
		material = ShaderMaterial.new()
		material.shader = ROW_SHADER
		var decoration := ColorRect.new()
		decoration.name = "HalftoneRow"
		decoration.show_behind_parent = true
		decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decoration.material = material
		button.add_child(decoration)
		decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_materials[button] = material
	material.set_shader_parameter(&"row_size", Vector2(width, ROW_HEIGHT))
	material.set_shader_parameter(&"disabled", float(button.disabled))


func reveal() -> void:
	if interactive or _slide != null:
		return
	interactive = false
	_navigation.set_hover_suppressed(true)
	for button in _options:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.position = Vector2(650.0, _rest_position.y)
	_rows.modulate.a = 0.25
	_rows.show()
	_hide_interrupt()
	show()
	_slide = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_slide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_rows, "position:x", _rest_position.x, SLIDE_SECONDS)
	_slide.tween_property(_rows, "modulate:a", 1.0, SLIDE_SECONDS * 0.78)
	_slide.finished.connect(_finish_slide, CONNECT_ONE_SHOT)


func _finish_slide() -> void:
	_slide = null
	interactive = true
	_navigation.set_hover_suppressed(false)
	for button in _options:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _navigation.get_active_index() < 0:
		_navigation.activate_delta(1, false)
	_paint_selection(_navigation.get_active_index())
	set_process(true)


func show_interrupt(label: String) -> void:
	_conceal_choices()
	if interrupt_button.text != label:
		interrupt_button.text = label
	if interrupt_button.visible:
		return
	var rest_x := 640.0 - RIGHT_MARGIN - MIN_ROW_WIDTH
	interrupt_button.position = Vector2(rest_x + 64.0, BOTTOM - ROW_HEIGHT)
	interrupt_button.modulate.a = 0.45
	interrupt_button.show()
	show()
	_paint_interrupt()
	_interrupt_slide = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_interrupt_slide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_interrupt_slide.tween_property(interrupt_button, "position:x", rest_x, INTERRUPT_SLIDE_SECONDS)
	_interrupt_slide.tween_property(interrupt_button, "modulate:a", 1.0, INTERRUPT_SLIDE_SECONDS)


func _hide_interrupt() -> void:
	if _interrupt_slide != null and _interrupt_slide.is_valid():
		_interrupt_slide.kill()
	_interrupt_slide = null
	interrupt_button.hide()


func _paint_interrupt() -> void:
	var lit := interrupt_button.is_hovered() or interrupt_button.has_focus()
	_materials[interrupt_button].set_shader_parameter(&"accent", Vector3(1.0, 0.55, 0.52) if lit else Vector3(0.92, 0.32, 0.36))


func conceal() -> void:
	_conceal_choices()
	_hide_interrupt()
	hide()


func _conceal_choices() -> void:
	if not _rows.visible and _slide == null and not interactive:
		return
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
	interactive = false
	if _rows.is_visible_in_tree():
		_navigation.clear_highlight()
	_navigation.set_hover_suppressed(false)
	_rows.hide()
	set_process(false)


func _process(_delta: float) -> void:
	_paint_selection(_navigation.get_active_index())


func _paint_selection(index: int) -> void:
	if index == _selection:
		return
	_selection = index
	for row_index in _options.size():
		var button := _options[row_index]
		var material: ShaderMaterial = _materials.get(button)
		if material == null:
			continue
		var active := row_index == index and not button.disabled
		material.set_shader_parameter(&"selected", float(active))
		button.add_theme_color_override(&"font_color", Color("d9f6ec") if active else Color("d6dde0"))
