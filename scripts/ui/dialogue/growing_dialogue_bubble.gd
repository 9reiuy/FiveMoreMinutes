extends DreamDialogueBubble
## Character dialogue: a speaker-anchored, four-sided fade that grows with the
## revealed text. Gameplay and countdown ownership remain in the controller.

const DIALOGUE_FONT := preload("res://scripts/ui/pixel_font.gd")
const GRADIENT_SHADER := preload("res://shaders/dialogue_gradient_halftone.gdshader")
const DIALOGUE_FONT_SIZE := 14
const MIN_PANEL_WIDTH := 72.0
const MAX_PANEL_WIDTH := 220.0
const MIN_PANEL_HEIGHT := 32.0
const HORIZONTAL_PADDING := 16.0
const TOP_PADDING := 7.0
const BOTTOM_PADDING := 8.0

var _fade: Tween
var _prefix := ""
var arrow_tip := Vector2.ZERO
var _below := false
var text_clip: Control
var _text_width := MIN_PANEL_WIDTH - HORIZONTAL_PADDING * 2.0
var _hint := false
var _compact_mode := true
var gradient_panel: ColorRect
var gradient_material: ShaderMaterial
var _timer_fill: ColorRect


func _ready() -> void:
	super._ready()
	gradient_panel = ColorRect.new()
	gradient_panel.name = "GradientHalftone"
	gradient_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gradient_material = ShaderMaterial.new()
	gradient_material.shader = GRADIENT_SHADER
	gradient_panel.material = gradient_material
	add_child(gradient_panel)
	move_child(gradient_panel, 0)
	background.hide()
	# The fading panel replaces the solid frame and its pointer. The dialogue
	# remains anchored to the speaker and the timer keeps its existing clock.
	speaker_arrow.hide()
	progress_track.hide()
	progress_fill_bar.hide()
	_timer_fill = ColorRect.new()
	_timer_fill.name = "RemainingTime"
	_timer_fill.color = Color(0.72, 0.77, 0.82, 0.34)
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_fill_clip.add_child(_timer_fill)
	_timer_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_clip = Control.new()
	text_clip.name = "TextClip"
	text_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_clip.clip_contents = true
	add_child(text_clip)
	dialogue_label.reparent(text_clip)
	dialogue_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin_container.hide()
	hide()


func _exit_tree() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	super._exit_tree()


func _setup_font() -> void:
	if dialogue_label == null:
		return
	dialogue_label.add_theme_font_override(&"font", DIALOGUE_FONT.get_font())
	dialogue_label.add_theme_font_size_override(&"font_size", DIALOGUE_FONT_SIZE)
	dialogue_label.add_theme_color_override(&"font_color", Color.WHITE)
	dialogue_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	dialogue_label.add_theme_constant_override(&"outline_size", 1)


func present_hint(speaker: Vector2) -> void:
	if not visible or _is_dismissing:
		show_dialogue("...", speaker, [])
		_hint = true
		set_typing_progress(0, 3)
		progress_bar_container.hide()
	set_speaker_hud_position(speaker)


func _setup_options() -> void:
	if _compact_mode:
		_is_interrupt_mode = false
		interrupt_container.hide()
		normal_options_container.hide()
		options_container.hide()
	else:
		super._setup_options()


func show_dialogue(text: String, speaker: Vector2, choices: Array, interrupt_text: String = "") -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	_hint = false
	_compact_mode = choices.is_empty() and interrupt_text.is_empty()
	super.show_dialogue(text, speaker, choices, interrupt_text)
	background.hide()
	speaker_arrow.hide()
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prefix = ""
	dialogue_label.text = ""
	dialogue_label.visible_characters = -1
	custom_minimum_size = Vector2.ZERO
	size = Vector2(MIN_PANEL_WIDTH, MIN_PANEL_HEIGHT)
	_text_width = MIN_PANEL_WIDTH - HORIZONTAL_PADDING * 2.0
	progress_bar_container.show()
	if _compact_mode:
		options_container.hide()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_layout()


func set_typing_progress(progress_ratio: float, visible_chars: int) -> void:
	_progress = clampf(progress_ratio, 0.0, 1.0)
	var prefix := _current_text.substr(0, clampi(visible_chars, 0, _current_text.length()))
	if prefix != _prefix:
		_prefix = prefix
		dialogue_label.text = prefix
		dialogue_label.visible_characters = -1
		var font: Font = DIALOGUE_FONT.get_font()
		var longest_line := 0.0
		for line in prefix.split("\n"):
			longest_line = maxf(longest_line, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, DIALOGUE_FONT_SIZE).x)
		var width := clampf(longest_line + HORIZONTAL_PADDING * 2.0, MIN_PANEL_WIDTH, MAX_PANEL_WIDTH)
		_text_width = width - HORIZONTAL_PADDING * 2.0
		dialogue_label.size = Vector2(_text_width, 0)
		# Resize with the revealed prefix so no newly typed glyph is clipped while
		# an animation catches up; wrapped lines increase the panel's height.
		var height := maxf(MIN_PANEL_HEIGHT, dialogue_label.get_minimum_size().y + TOP_PADDING + BOTTOM_PADDING)
		size = Vector2(ceilf(width), ceilf(height))
	if not _compact_mode and _progress > 0.20 and _is_interrupt_mode:
		transition_to_normal_options()
	_layout()


func _process(_delta: float) -> void:
	if visible:
		_layout()
		if not _compact_mode:
			_update_options_position()


func _layout() -> void:
	_update_bubble_position()
	if is_instance_valid(gradient_panel):
		gradient_panel.size = size
		gradient_material.set_shader_parameter(&"panel_size", size)
	if is_instance_valid(text_clip):
		text_clip.position = Vector2(HORIZONTAL_PADDING, TOP_PADDING)
		text_clip.size = Vector2(maxf(1, size.x - HORIZONTAL_PADDING * 2.0), maxf(1, size.y - TOP_PADDING - BOTTOM_PADDING))
		dialogue_label.position = Vector2.ZERO
		dialogue_label.size = Vector2(_text_width, dialogue_label.get_minimum_size().y)
	progress_bar_container.position = Vector2(HORIZONTAL_PADDING, roundf(size.y - 5.0))
	progress_bar_container.size = Vector2(maxf(1, size.x - HORIZONTAL_PADDING * 2.0), 1.0)
	_update_progress_bar(_progress)


func _update_progress_bar(progress_ratio: float) -> void:
	_progress = clampf(progress_ratio, 0.0, 1.0)
	if not is_instance_valid(progress_bar_container) or not is_instance_valid(progress_fill_clip):
		return
	if is_instance_valid(progress_track):
		progress_track.hide()
	if is_instance_valid(progress_fill_bar):
		progress_fill_bar.hide()
	var full_width := progress_bar_container.size.x
	var cut := roundf(full_width * _progress)
	progress_fill_clip.position = Vector2(cut, 0)
	progress_fill_clip.size = Vector2(maxf(0.0, full_width - cut), 1.0)
	progress_fill_clip.visible = _progress < 1.0


func _update_bubble_position() -> void:
	_below = _speaker_hud_pos.y - size.y - 14 < SCREEN_MARGIN
	var y := _speaker_hud_pos.y + 24 if _below else _speaker_hud_pos.y - size.y - 14
	position = Vector2(roundf(clampf(_speaker_hud_pos.x - size.x * 0.5, SCREEN_MARGIN, maxf(SCREEN_MARGIN, SCREEN_SIZE.x - size.x - SCREEN_MARGIN))), roundf(clampf(y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, SCREEN_SIZE.y - size.y - SCREEN_MARGIN))))
	update_speaker_position()


func update_speaker_position() -> void:
	if is_instance_valid(speaker_arrow):
		speaker_arrow.hide()
	arrow_tip = (_speaker_hud_pos - position + Vector2(0, 4 if _below else -3)).round()


func dismiss(fade_time: float = 0.18) -> void:
	if _is_dismissing:
		return
	_is_dismissing = true
	if _fade and _fade.is_valid():
		_fade.kill()
	if fade_time <= 0.0:
		hide()
		options_container.hide()
		_is_dismissing = false
		return
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(self, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not _compact_mode:
		_fade.tween_property(options_container, "modulate:a", 0.0, fade_time)
	_fade.chain().tween_callback(func():
		hide()
		options_container.hide()
		_is_dismissing = false
	)
