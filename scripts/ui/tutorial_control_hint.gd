extends Control
## A three-second tutorial cue with a directional fade across panel and text.
const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
const BACKGROUND := preload("res://shaders/ui/tutorial_control_hint.gdshader")
const TEXT_MASK := preload("res://shaders/ui/tutorial_control_hint_text.gdshader")
const WIDTH := 228.0
const LIFETIME_MSEC := 3000
const ENTER_MSEC := 360.0
const FADE_MSEC := 320.0
const SWEEP_MSEC := 3000.0

var content: Control
var label: Label
var background: ColorRect
var _background_material: ShaderMaterial
var _text_material: ShaderMaterial
var _started_at_msec := 0
var _reveal_progress := 0.0
var _closing_at_msec := -1
var _closing_duration_msec := FADE_MSEC
var _closing_from := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_material = ShaderMaterial.new()
	_background_material.shader = BACKGROUND
	background.material = _background_material
	content.add_child(background)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_material = ShaderMaterial.new()
	_text_material.shader = TEXT_MASK
	label.material = _text_material
	label.add_theme_font_override("font", FONT.get_font())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("e5e9e6"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label)
	dismiss(true)

func present(message: String) -> void:
	if message.is_empty():
		dismiss()
		return
	label.text = message
	var height := maxf(30.0, float(message.split("\n").size()) * 14.0 + 14.0)
	size = Vector2(WIDTH, height)
	content.size = size
	background.size = size
	_background_material.set_shader_parameter("panel_size", size)
	_background_material.set_shader_parameter("sweep_phase", 0.0)
	label.position = Vector2(8, 6)
	label.size = size - Vector2(16, 12)
	content.position = Vector2.ZERO
	content.modulate.a = 1.0
	_started_at_msec = Time.get_ticks_msec()
	_closing_at_msec = -1
	_set_reveal(0.0)
	show()
	set_process(true)

func dismiss(immediate: bool = false) -> void:
	if immediate:
		hide()
		set_process(false)
		return
	if not visible or _closing_at_msec >= 0:
		return
	_closing_at_msec = Time.get_ticks_msec()
	_closing_from = _reveal_progress
	_closing_duration_msec = minf(FADE_MSEC, maxf(1.0, float(LIFETIME_MSEC - (_closing_at_msec - _started_at_msec))))
	set_process(true)

func _set_reveal(progress: float) -> void:
	_reveal_progress = clampf(progress, 0.0, 1.0)
	_background_material.set_shader_parameter("reveal_progress", _reveal_progress)
	_text_material.set_shader_parameter("reveal_progress", _reveal_progress)

func _process(_delta: float) -> void:
	var elapsed := Time.get_ticks_msec() - _started_at_msec
	if elapsed >= LIFETIME_MSEC:
		dismiss(true)
		return
	_background_material.set_shader_parameter("sweep_phase", fmod(float(elapsed) / SWEEP_MSEC, 1.0))
	if _closing_at_msec >= 0:
		var closing_elapsed := Time.get_ticks_msec() - _closing_at_msec
		if closing_elapsed >= _closing_duration_msec:
			dismiss(true)
			return
		_set_reveal(_closing_from * (1.0 - smoothstep(0.0, _closing_duration_msec, float(closing_elapsed))))
	else:
		var entering := smoothstep(0.0, ENTER_MSEC, float(elapsed))
		var leaving := 1.0 - smoothstep(LIFETIME_MSEC - FADE_MSEC, float(LIFETIME_MSEC), float(elapsed))
		_set_reveal(minf(entering, leaving))
