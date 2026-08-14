class_name BedroomConfirmationDialog
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
# 纯文字选项配色：默认淡蓝灰，悬停变亮，禁用变暗（不用降 Alpha 假装变细）。
const CHOICE_COLOR := Color("8ebcd8")
const CHOICE_HOVER_COLOR := Color("d8f1ff")
const CHOICE_DISABLED_COLOR := Color("56758a")
const PORTRAIT_IDLE := preload("res://art/Chr/chr.png")
const PORTRAIT_TALK_A := preload("res://art/Chr/chr__normal_talk.png")
const PORTRAIT_TALK_B := preload("res://art/Chr/chr__normal_talk2.png")
const PORTRAIT_OUTLINE_SHADER := preload("res://shaders/sprite_alpha_outline.gdshader")

signal confirmed
signal cancelled
signal session_started
signal session_ended

@export var config: DemoConfig

@onready var input_blocker: Control = $InputBlocker
@onready var portrait: Control = $Portrait
@onready var character_art: TextureRect = $Portrait/CharacterArt
@onready var dialogue_panel: Control = $DialoguePanel
@onready var prompt_label: Label = $DialoguePanel/Margin/Content/Prompt
@onready var buttons: VBoxContainer = $DialoguePanel/Margin/Content/ChoiceContainer
@onready var confirm_button: Button = $DialoguePanel/Margin/Content/ChoiceContainer/ConfirmChoice
@onready var cancel_button: Button = $DialoguePanel/Margin/Content/ChoiceContainer/CancelChoice

var animating := false
var message_only := false
var animation_token := 0
var active_tween: Tween
var dialogue_target_position := Vector2.ZERO
var confirm_choice_text := ""
var cancel_choice_text := ""
var full_prompt_text := ""
var typewriter_active := false
var typewriter_accumulator := 0.0
var visible_talk_character_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_target_position = dialogue_panel.position
	_apply_choice_styles()
	confirm_button.pressed.connect(_on_confirmed)
	cancel_button.pressed.connect(_on_cancelled)
	confirm_button.mouse_entered.connect(_set_choice_hover.bind(confirm_button, true))
	confirm_button.mouse_exited.connect(_set_choice_hover.bind(confirm_button, false))
	cancel_button.mouse_entered.connect(_set_choice_hover.bind(cancel_button, true))
	cancel_button.mouse_exited.connect(_set_choice_hover.bind(cancel_button, false))
	input_blocker.gui_input.connect(_on_blocker_gui_input)
	character_art.texture = PORTRAIT_IDLE
	_apply_portrait_outline()


func _apply_portrait_outline() -> void:
	# 所有正式角色共用CharacterArt入口；只切换Texture，材质和节点几何始终不变。
	var outline_material := ShaderMaterial.new()
	outline_material.shader = PORTRAIT_OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_enabled", 1.0)
	outline_material.set_shader_parameter("outline_color", config.dialogue_portrait_outline_color)
	outline_material.set_shader_parameter("outline_inner_at_texture_edge", 1.0)
	outline_material.set_shader_parameter("color_filter", config.dialogue_portrait_filter_color)
	outline_material.set_shader_parameter("color_filter_strength", config.dialogue_portrait_filter_strength)
	var source_size := character_art.texture.get_size()
	var display_scale := minf(
		character_art.size.x / maxf(source_size.x, 1.0),
		character_art.size.y / maxf(source_size.y, 1.0)
	)
	outline_material.set_shader_parameter(
		"outline_width_source_pixels",
		config.dialogue_portrait_outline_width_px / maxf(display_scale, 0.001)
	)
	character_art.material = outline_material


func _process(delta: float) -> void:
	# 入场淡入完成后才开始逐字，避免短句在立绘尚未出现时已经播放完。
	if not visible or animating or not typewriter_active:
		return
	typewriter_accumulator += delta * config.opening_characters_per_second
	while typewriter_accumulator >= 1.0 and typewriter_active:
		typewriter_accumulator -= 1.0
		_reveal_next_character()
		if prompt_label.visible_characters >= full_prompt_text.length():
			_complete_typewriter()


func _apply_choice_styles() -> void:
	# 对话选项为纯文字：无任何底框/描边/阴影，单次绘制即最细字重，
	# 悬停仅变色，不再表现为厚重按钮。
	var empty := StyleBoxEmpty.new()
	for button in [confirm_button, cancel_button]:
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", CHOICE_COLOR)
		button.add_theme_color_override("font_hover_color", CHOICE_HOVER_COLOR)
		button.add_theme_color_override("font_pressed_color", CHOICE_HOVER_COLOR)
		button.add_theme_color_override("font_focus_color", CHOICE_COLOR)
		button.add_theme_color_override("font_disabled_color", CHOICE_DISABLED_COLOR)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)


func open(prompt: String, confirm_text: String, cancel_text: String, confirm_enabled: bool = true) -> void:
	if visible:
		return
	message_only = false
	buttons.visible = true
	_begin_typewriter(prompt)
	confirm_choice_text = confirm_text
	cancel_choice_text = cancel_text
	_set_choice_hover(confirm_button, false)
	_set_choice_hover(cancel_button, false)
	confirm_button.disabled = not confirm_enabled
	await _animate_in()


func open_message(prompt: String) -> void:
	if visible:
		return
	message_only = true
	buttons.visible = false
	_begin_typewriter(prompt)
	await _animate_in()


func _animate_in() -> void:
	animation_token += 1
	var token := animation_token
	session_started.emit()
	visible = true
	animating = true
	# 立绘使用原始 16:9 完整画布，不裁剪、不平移；仅做透明度淡入。
	portrait.position = Vector2.ZERO
	portrait.modulate.a = 0.0
	dialogue_panel.position = dialogue_target_position + Vector2(0.0, 8.0)
	dialogue_panel.modulate.a = 0.0
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(portrait, "modulate:a", 1.0, config.dialog_animation_seconds)
	active_tween.tween_property(dialogue_panel, "position", dialogue_target_position, config.dialog_animation_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(dialogue_panel, "modulate:a", 1.0, config.dialog_animation_seconds * 0.75)
	await active_tween.finished
	if token == animation_token and visible:
		animating = false


func close_without_signal() -> void:
	var was_visible := visible
	animation_token += 1
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	visible = false
	animating = false
	message_only = false
	_stop_talking_portrait()
	portrait.modulate.a = 0.0
	dialogue_panel.modulate.a = 0.0
	if was_visible:
		session_ended.emit()


func _on_confirmed() -> void:
	if animating or confirm_button.disabled:
		return
	if typewriter_active:
		_complete_typewriter()
		return
	SFX.play_event(&"confirm")
	_finish_dialog(true)


func _on_cancelled() -> void:
	if animating:
		return
	if typewriter_active:
		_complete_typewriter()
		return
	SFX.play_event(&"confirm")
	_finish_dialog(false)


func _finish_dialog(was_confirmed: bool) -> void:
	animating = true
	animation_token += 1
	var token := animation_token
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(portrait, "modulate:a", 0.0, config.dialog_animation_seconds)
	active_tween.tween_property(dialogue_panel, "position", dialogue_target_position + Vector2(0.0, 8.0), config.dialog_animation_seconds * 0.8)
	active_tween.tween_property(dialogue_panel, "modulate:a", 0.0, config.dialog_animation_seconds * 0.65)
	await active_tween.finished
	if token != animation_token:
		return
	visible = false
	animating = false
	message_only = false
	_stop_talking_portrait()
	session_ended.emit()
	if was_confirmed:
		confirmed.emit()
	else:
		cancelled.emit()


func _gui_input(event: InputEvent) -> void:
	if visible:
		accept_event()
	if visible and message_only and not animating and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_cancelled()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if visible and message_only and not animating and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_cancelled()
	input_blocker.accept_event()


func _set_choice_hover(button: Button, hovered: bool) -> void:
	var choice_text := confirm_choice_text if button == confirm_button else cancel_choice_text
	button.text = ("› " if hovered else "  ") + choice_text
	if hovered and visible and not animating and not button.disabled:
		SFX.play_event(&"ui_hover")


func _begin_typewriter(prompt: String) -> void:
	full_prompt_text = prompt
	prompt_label.text = full_prompt_text
	prompt_label.visible_characters = 0
	typewriter_accumulator = 0.0
	visible_talk_character_count = 0
	typewriter_active = not full_prompt_text.is_empty()
	# 每句开始先保持静止图；第一个实际可见字符出现时才切换到 Talk A。
	character_art.texture = PORTRAIT_IDLE


func _complete_typewriter() -> void:
	prompt_label.visible_characters = -1
	typewriter_active = false
	_stop_talking_portrait()


func _reveal_next_character() -> void:
	if prompt_label.visible_characters >= full_prompt_text.length():
		return
	var revealed_character := full_prompt_text.substr(prompt_label.visible_characters, 1)
	prompt_label.visible_characters += 1
	# 嘴型与文字 Reveal 使用同一个入口；空白、换行及控制字符不推动说话帧。
	if _is_visible_talk_character(revealed_character):
		SFX.play_event(&"text_blip")
		visible_talk_character_count += 1
		# 第1、2个可见字使用A，第3、4个使用B；每两个可见字才切换一次。
		var frame_group := int((visible_talk_character_count - 1) / 2) % 2
		character_art.texture = PORTRAIT_TALK_A if frame_group == 0 else PORTRAIT_TALK_B


func _is_visible_talk_character(character: String) -> bool:
	if character.is_empty():
		return false
	var codepoint := character.unicode_at(0)
	return codepoint > 32 and not (codepoint >= 127 and codepoint <= 159)


func _stop_talking_portrait() -> void:
	typewriter_active = false
	visible_talk_character_count = 0
	if character_art != null:
		character_art.texture = PORTRAIT_IDLE
