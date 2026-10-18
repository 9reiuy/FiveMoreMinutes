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
const PORTRAIT_PANIC_FILTER := Color("ff7890")
const DEFAULT_PANEL_POS := Vector2(235.0, 188.0)
const DEFAULT_PANEL_SIZE := Vector2(385.0, 154.0)
const CENTERED_PANEL_POS := Vector2(110.0, 188.0)
const CENTERED_PANEL_SIZE := Vector2(420.0, 154.0)
const DIALOGUE_DEFAULT_CONTENT_WIDTH := 349.0
const DIALOGUE_DEFAULT_CONTENT_HEIGHT := 124.0
const DIALOGUE_MARGIN_LEFT := 18.0
const DIALOGUE_MARGIN_RIGHT := 18.0
const DIALOGUE_MARGIN_TOP := 16.0
const DIALOGUE_MARGIN_BOTTOM := 14.0
const DIALOGUE_CONTENT_SEPARATION := 6.0
const DIALOGUE_CHOICE_SEPARATION := 1.0

signal confirmed
signal cancelled
signal action_requested(action_id: StringName)
signal session_started
signal session_ended
## Stable dialogue metadata only.  World scenes resolve this ID to their own
## authoritative Speaker node; the shared UI never looks up scene nodes or
## talks to a Camera directly.
signal line_presented(speaker_id: StringName)

@export var config: DemoConfig

@onready var input_blocker: Control = $InputBlocker
@onready var portrait: Control = $Portrait
@onready var character_art: TextureRect = $Portrait/CharacterArt
@onready var dialogue_panel: Control = $DialoguePanel
@onready var choice_option_group: PixelOptionGroup = $DialoguePanel/ChoiceOptionGroup
@onready var dialogue_margin: MarginContainer = $DialoguePanel/Margin
@onready var prompt_label: Label = $DialoguePanel/Margin/Content/Prompt
@onready var buttons: VBoxContainer = $DialoguePanel/Margin/Content/ChoiceContainer
@onready var confirm_button: Button = $DialoguePanel/Margin/Content/ChoiceContainer/ConfirmChoice
@onready var cancel_button: Button = $DialoguePanel/Margin/Content/ChoiceContainer/CancelChoice

var animating := false
var message_only := false
var animation_token := 0
var active_tween: Tween
var dialogue_target_position := Vector2.ZERO
var full_prompt_text := ""
var typewriter_active := false
var typewriter_accumulator := 0.0
var visible_talk_character_count := 0
var dialogue_lines: Array = []
var dialogue_line_index := 0
var current_line: Dictionary = {}
var current_choices: Array = []
var choice_buttons: Array[Button] = []
var pre_delay_remaining := 0.0
var post_delay_remaining := 0.0
var line_ready := false
var prompt_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_target_position = dialogue_panel.position
	_apply_choice_styles()
	choice_buttons = [confirm_button, cancel_button]
	choice_option_group.register_options(choice_buttons)
	for button in [confirm_button, cancel_button]:
		button.set_meta(&"pixel_option_center_pivot", true)
	_center_choice_visuals()
	confirm_button.pressed.connect(_on_choice_pressed.bind(0))
	cancel_button.pressed.connect(_on_choice_pressed.bind(1))
	input_blocker.gui_input.connect(_on_blocker_gui_input)
	character_art.texture = PORTRAIT_IDLE
	_apply_portrait_outline()
	# Keep the text geometry finite even when this shared dialog is instantiated
	# outside a themed scene. Smart wrapping handles CJK boundaries as well as
	# normal English word boundaries; pagination below uses the same Label.
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.clip_text = false
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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


func _apply_portrait_expression(expression: StringName) -> void:
	var material := character_art.material as ShaderMaterial
	if material == null:
		return
	var panicked := expression == &"fear" or expression == &"panic"
	material.set_shader_parameter(
		"color_filter",
		PORTRAIT_PANIC_FILTER if panicked else config.dialogue_portrait_filter_color
	)
	material.set_shader_parameter(
		"color_filter_strength",
		maxf(config.dialogue_portrait_filter_strength, 0.34) if panicked else config.dialogue_portrait_filter_strength
	)


func _process(delta: float) -> void:
	# 入场淡入完成后才开始逐字，避免短句在立绘尚未出现时已经播放完。
	if not visible or animating:
		return
	if pre_delay_remaining > 0.0:
		pre_delay_remaining = maxf(0.0, pre_delay_remaining - delta)
		return
	if not typewriter_active:
		if post_delay_remaining > 0.0:
			post_delay_remaining = maxf(0.0, post_delay_remaining - delta)
			if post_delay_remaining <= 0.0:
				_on_line_ready()
		return
	var seconds_per_character := maxf(0.001, float(current_line.get("typewriter_speed", 1.0 / maxf(config.opening_characters_per_second, 1.0))))
	typewriter_accumulator += delta / seconds_per_character
	while typewriter_accumulator >= 1.0 and typewriter_active:
		typewriter_accumulator -= 1.0
		_reveal_next_character()
		if prompt_label.visible_characters >= full_prompt_text.length():
			_complete_typewriter()


func _apply_choice_styles() -> void:
	# 对话选项为纯文字：无任何底框/描边/阴影，单次绘制即最细字重，
	# 悬停仅变色，不再表现为厚重按钮。
	var empty := StyleBoxEmpty.new()
	for button in choice_buttons:
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", CHOICE_COLOR)
		button.add_theme_color_override("font_hover_color", CHOICE_HOVER_COLOR)
		button.add_theme_color_override("font_pressed_color", CHOICE_HOVER_COLOR)
		button.add_theme_color_override("font_focus_color", CHOICE_COLOR)
		button.add_theme_color_override("font_disabled_color", CHOICE_DISABLED_COLOR)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)


func _center_choice_visuals() -> void:
	for button in choice_buttons:
		if button.visible:
			_center_choice_visual(button)


func _center_choice_visual(button: Button) -> void:
	if button == null or button.size.x <= 0.0:
		return
	var font := button.get_theme_font(&"font")
	var font_size := button.get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var leading_width := config.option_triangle_size + config.option_triangle_text_gap
	var combined_width := leading_width + text_width
	# Each choice gets its own left content margin. Triangle + gap + actual text
	# therefore share one independently measured group centered in the row.
	var text_left := maxf(0.0, (button.size.x - combined_width) * 0.5 + leading_width)
	var centered_empty := StyleBoxEmpty.new()
	centered_empty.content_margin_left = text_left
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, centered_empty)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT


func open(prompt: String, confirm_text: String, cancel_text: String, confirm_enabled: bool = true) -> void:
	if visible:
		return
	var choices := [
		{"text": confirm_text, "action_id": "close", "next": "close", "enabled": confirm_enabled},
		{"text": cancel_text, "action_id": "close", "next": "close"},
	]
	await open_data({"id": "legacy_inline", "lines": [{"text": prompt, "choices": choices}]})


func open_message(prompt: String) -> void:
	if visible:
		return
	await open_data({"id": "legacy_inline", "lines": [{"text": prompt}]})


func open_dialogue(dialogue_id: StringName, replacements: Dictionary = {}) -> void:
	await open_data(TextContent.get_dialogue(dialogue_id, replacements))


func open_data(entry: Dictionary) -> void:
	if visible:
		return
	dialogue_lines = _prepare_dialogue_lines(entry.get("lines", []))
	if dialogue_lines.is_empty():
		dialogue_lines = _prepare_dialogue_lines(TextContent.get_dialogue(&"common_missing_dialogue").lines)
	dialogue_line_index = 0
	_show_current_line()
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
	dialogue_lines.clear()
	current_line.clear()
	current_choices.clear()
	choice_option_group.clear_highlight()
	_stop_talking_portrait()
	_apply_portrait_expression(&"normal")
	portrait.modulate.a = 0.0
	dialogue_panel.modulate.a = 0.0
	if was_visible:
		session_ended.emit()


func _on_confirmed() -> void:
	_on_choice_pressed(0)


func _on_cancelled() -> void:
	if animating:
		return
	if typewriter_active:
		_complete_typewriter()
		return
	if not line_ready:
		return
	if dialogue_line_index < dialogue_lines.size() - 1:
		dialogue_line_index += 1
		_show_current_line()
		return
	SFX.play_event(&"confirm")
	var completion_action := StringName(str(current_line.get("completion_action_id", "")))
	_finish_dialog(false, completion_action)


func _on_choice_pressed(choice_index: int) -> void:
	if animating or choice_index < 0 or choice_index >= current_choices.size():
		return
	if typewriter_active:
		_complete_typewriter()
		return
	if not line_ready:
		return
	var choice: Dictionary = current_choices[choice_index]
	if not bool(choice.get("enabled", true)):
		return
	SFX.play_event(&"confirm")
	var action_id := StringName(str(choice.get("action_id", "close")))
	var next_id := str(choice.get("next", "close"))
	if next_id != "close" and not next_id.is_empty():
		dialogue_lines = _prepare_dialogue_lines(TextContent.get_dialogue(StringName(next_id)).get("lines", []))
		dialogue_line_index = 0
		_show_current_line()
		if action_id != &"close" and not str(action_id).is_empty() and TextContent.is_action_allowed(action_id):
			action_requested.emit(action_id)
		return
	_finish_dialog(choice_index == 0, action_id)


func _finish_dialog(was_confirmed: bool, action_id: StringName = &"") -> void:
	animating = true
	choice_option_group.clear_highlight()
	animation_token += 1
	var token := animation_token
	active_tween = create_tween().set_parallel(true)
	var fade_out := maxf(0.0, float(current_line.get("fade_out", config.dialog_animation_seconds)))
	active_tween.tween_property(portrait, "modulate:a", 0.0, fade_out)
	active_tween.tween_property(dialogue_panel, "position", dialogue_target_position + Vector2(0.0, 8.0), fade_out * 0.8)
	active_tween.tween_property(dialogue_panel, "modulate:a", 0.0, fade_out * 0.65)
	await active_tween.finished
	if token != animation_token:
		return
	visible = false
	animating = false
	message_only = false
	_stop_talking_portrait()
	_apply_portrait_expression(&"normal")
	session_ended.emit()
	if was_confirmed:
		confirmed.emit()
	else:
		cancelled.emit()
	if not str(action_id).is_empty() and action_id != &"close":
		if TextContent.is_action_allowed(action_id):
			action_requested.emit(action_id)
		else:
			push_error("[DIALOGUE DATA ERROR]\nfile: <runtime>\nid: action\nline: -\nreason: blocked action_id '%s'" % action_id)


func _gui_input(event: InputEvent) -> void:
	if visible:
		accept_event()
	if visible and message_only and not animating and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_cancelled()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if visible and message_only and not animating and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_cancelled()
	input_blocker.accept_event()


func _begin_typewriter(prompt: String, line_data: Dictionary = {}) -> void:
	current_line = line_data
	full_prompt_text = prompt
	prompt_label.text = full_prompt_text
	prompt_label.visible_characters = 0
	typewriter_accumulator = 0.0
	visible_talk_character_count = 0
	pre_delay_remaining = maxf(0.0, float(current_line.get("pre_delay", 0.0)))
	post_delay_remaining = 0.0
	line_ready = false
	var seconds_per_character := float(current_line.get("typewriter_speed", 1.0 / maxf(config.opening_characters_per_second, 1.0)))
	typewriter_active = not full_prompt_text.is_empty() and seconds_per_character > 0.0
	if not typewriter_active:
		prompt_label.visible_characters = -1
	# 每句开始先保持静止图；第一个实际可见字符出现时才切换到 Talk A。
	character_art.texture = PORTRAIT_IDLE
	_apply_line_presentation()
	if not typewriter_active and pre_delay_remaining <= 0.0:
		_complete_typewriter()


func _complete_typewriter() -> void:
	prompt_label.visible_characters = -1
	typewriter_active = false
	_stop_talking_portrait()
	post_delay_remaining = maxf(0.0, float(current_line.get("post_delay", current_line.get("display_duration", 0.0))))
	if post_delay_remaining <= 0.0:
		_on_line_ready()


func _reveal_next_character() -> void:
	if prompt_label.visible_characters >= full_prompt_text.length():
		return
	var revealed_character := full_prompt_text.substr(prompt_label.visible_characters, 1)
	prompt_label.visible_characters += 1
	# 嘴型与文字 Reveal 使用同一个入口；空白、换行及控制字符不推动说话帧。
	if _is_visible_talk_character(revealed_character):
		if bool(current_line.get("blip", true)):
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


func _show_current_line() -> void:
	if dialogue_line_index < 0 or dialogue_line_index >= dialogue_lines.size():
		return
	current_line = dialogue_lines[dialogue_line_index] if dialogue_lines[dialogue_line_index] is Dictionary else {}
	current_choices = current_line.get("choices", []).duplicate(true)
	line_presented.emit(StringName(str(current_line.get("speaker", ""))))
	message_only = current_choices.is_empty()
	_rebuild_choice_buttons(current_choices)
	_begin_typewriter(str(current_line.get("text", "")), current_line)


## Prepare narrative lines as stable pages before typewriter reveal begins.  The
## split point is selected from the actual Label wrapping result, never from a
## fixed character count, so CJK and proportional English text both fit.
func _prepare_dialogue_lines(source_lines: Array) -> Array:
	var prepared: Array = []
	for raw_line in source_lines:
		if not raw_line is Dictionary:
			continue
		var base: Dictionary = raw_line.duplicate(true)
		var text := str(base.get("text", ""))
		var font_size := maxi(8, int(base.get("font_size", 18)))
		var raw_choices: Variant = base.get("choices", [])
		var choice_count: int = 0
		if raw_choices is Array:
			choice_count = (raw_choices as Array).size()
		var pages := _paginate_text_by_layout(text, font_size, choice_count)
		if pages.is_empty():
			pages = [""]
		for page_index in pages.size():
			var page: Dictionary = base.duplicate(true)
			page["text"] = pages[page_index]
			if page_index < pages.size() - 1:
				# Intermediate pages are ordinary Continue pages. Choices and
				# completion actions stay on the final page only.
				page["choices"] = []
				page["wait_for_input"] = true
				page["auto_continue"] = false
				page.erase("completion_action_id")
			prepared.append(page)
	return prepared


func _paginate_text_by_layout(text: String, font_size: int, choice_count: int) -> Array[String]:
	if text.is_empty():
		return [""]
	var max_lines := _dialogue_page_line_capacity(font_size, choice_count)
	var pages: Array[String] = []
	var remaining := text
	while not remaining.is_empty():
		var split_index := _find_page_split_index(remaining, max_lines, font_size)
		split_index = clampi(split_index, 1, remaining.length())
		var page := remaining.substr(0, split_index).strip_edges()
		if page.is_empty():
			page = remaining.substr(0, 1)
		pages.append(page)
		remaining = remaining.substr(split_index).lstrip(" \t")
	return pages


func _find_page_split_index(text: String, max_lines: int, font_size: int) -> int:
	var current := ""
	var last_break := 0
	for index in text.length():
		var character := text.substr(index, 1)
		var candidate := current + character
		if _wrapped_line_count(candidate, font_size) <= max_lines:
			current = candidate
			if character == " " or character == "\t" or character == "\n":
				last_break = index + 1
			continue
		# Prefer the last word boundary for Latin text. CJK has no spaces,
		# therefore the current character boundary is the correct fallback.
		return last_break if last_break > 0 else index
	return text.length()


func _dialogue_page_line_capacity(font_size: int, choice_count: int) -> int:
	var panel_height := float(dialogue_panel.size.y)
	if panel_height <= 0.0:
		panel_height = DIALOGUE_DEFAULT_CONTENT_HEIGHT + DIALOGUE_MARGIN_TOP + DIALOGUE_MARGIN_BOTTOM
	var margin_top := float(dialogue_margin.get_theme_constant(&"margin_top")) if dialogue_margin != null else DIALOGUE_MARGIN_TOP
	var margin_bottom := float(dialogue_margin.get_theme_constant(&"margin_bottom")) if dialogue_margin != null else DIALOGUE_MARGIN_BOTTOM
	var available_height := panel_height - margin_top - margin_bottom
	if choice_count > 0:
		var choice_height := float(confirm_button.custom_minimum_size.y) * choice_count
		choice_height += DIALOGUE_CHOICE_SEPARATION * maxf(0.0, float(choice_count - 1))
		available_height -= DIALOGUE_CONTENT_SEPARATION + choice_height
	if available_height <= 0.0:
		available_height = DIALOGUE_DEFAULT_CONTENT_HEIGHT
	var font := prompt_label.get_theme_font(&"font")
	var line_height := float(font_size)
	if font != null:
		line_height = maxf(1.0, font.get_height(font_size))
	return maxi(1, floori(available_height / maxf(line_height, 1.0)))


func _wrapped_line_count(text: String, font_size: int) -> int:
	var previous_text := prompt_label.text
	var previous_visible_characters := prompt_label.visible_characters
	var previous_size := prompt_label.size
	var previous_font_size := prompt_label.get_theme_font_size(&"font_size")
	var previous_wrap := prompt_label.autowrap_mode
	var width := _dialogue_content_width()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override(&"font_size", font_size)
	prompt_label.size = Vector2(width, maxf(previous_size.y, DIALOGUE_DEFAULT_CONTENT_HEIGHT))
	prompt_label.text = text
	prompt_label.visible_characters = -1
	var line_count := maxi(1, prompt_label.get_line_count())
	prompt_label.text = previous_text
	prompt_label.visible_characters = previous_visible_characters
	prompt_label.size = previous_size
	prompt_label.autowrap_mode = previous_wrap
	prompt_label.add_theme_font_size_override(&"font_size", previous_font_size)
	return line_count


func _dialogue_content_width() -> float:
	var width := float(dialogue_margin.size.x) if dialogue_margin != null else 0.0
	if width <= 0.0:
		width = float(dialogue_panel.size.x) - DIALOGUE_MARGIN_LEFT - DIALOGUE_MARGIN_RIGHT
	if width <= 0.0:
		width = DIALOGUE_DEFAULT_CONTENT_WIDTH
	return width


func _apply_line_presentation() -> void:
	_apply_portrait_expression(StringName(str(current_line.get("expression", "normal"))))
	prompt_label.add_theme_color_override("font_color", Color.from_string(str(current_line.get("text_color", "#D3E0E8")), Color("d3e0e8")))
	prompt_label.add_theme_font_size_override("font_size", maxi(8, int(current_line.get("font_size", 18))))
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.clip_text = false
	match str(current_line.get("alignment", "left")):
		"center": prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"right": prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_: prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	match str(current_line.get("position", "bottom")):
		"top": dialogue_target_position.y = 18.0
		"center", "middle": dialogue_target_position.y = 103.0
		_: dialogue_target_position.y = 188.0
	dialogue_panel.position.y = dialogue_target_position.y
	portrait.visible = str(current_line.get("portrait", "normal")) != "hidden"
	# Auto-center dialogue panel when portrait is hidden (no character art).
	if not portrait.visible:
		var panel_width: float = dialogue_panel.size.x
		dialogue_target_position.x = (640.0 - panel_width) * 0.5
	else:
		dialogue_target_position.x = 235.0
	dialogue_panel.position.x = dialogue_target_position.x
	if prompt_tween != null and prompt_tween.is_valid():
		prompt_tween.kill()
	var fade_in := maxf(0.0, float(current_line.get("fade_in", 0.0)))
	prompt_label.modulate.a = 0.0 if fade_in > 0.0 else 1.0
	if fade_in > 0.0:
		prompt_tween = create_tween()
		prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, fade_in)


func _on_line_ready() -> void:
	if line_ready:
		return
	line_ready = true
	buttons.visible = not current_choices.is_empty()
	if not bool(current_line.get("wait_for_input", true)) and bool(current_line.get("auto_continue", false)):
		call_deferred("_on_cancelled")


func _rebuild_choice_buttons(choices: Array) -> void:
	while choice_buttons.size() < choices.size():
		var button := Button.new()
		button.custom_minimum_size = confirm_button.custom_minimum_size
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", confirm_button.get_theme_font_size("font_size"))
		buttons.add_child(button)
		choice_buttons.append(button)
		button.pressed.connect(_on_choice_pressed.bind(choice_buttons.size() - 1))
	for index in choice_buttons.size():
		var button := choice_buttons[index]
		button.visible = index < choices.size()
		if not button.visible:
			continue
		var choice: Dictionary = choices[index] if choices[index] is Dictionary else {}
		button.text = str(choice.get("text", "…"))
		button.disabled = not bool(choice.get("enabled", true))
		button.set_meta(&"pixel_option_center_pivot", true)
	_apply_choice_styles()
	choice_option_group.register_options(choice_buttons)
	_center_choice_visuals()
	buttons.visible = false
