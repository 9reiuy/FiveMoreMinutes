class_name CinematicDialogue
extends BedroomConfirmationDialog
## Opt-in narrative presentation. The existing dialogue controller still owns
## paging, typewriter, choices, actions and session signals.

const READABLE_FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
const VEIL_SHADER := preload("res://shaders/ui/cinematic_dialogue_veil.gdshader")
const CHOICE_LIST := preload("res://scripts/ui/dialogue/cinematic_choice_list.gd")
const GLYPH_FALL := preload("res://scripts/ui/dialogue/dream_dialogue_glyph_fall_fx.gd")
const INTERRUPT_TEXT := "闭嘴"
const GLYPH_LIFT := 136.0
const ART_REGION := PLAYER_PORTRAITS.DIALOGUE_REGION
const LEFT_REST := Vector2(35.0, 108.0)
const RIGHT_REST := Vector2(435.0, 108.0)
const TEXT_WIDTH := 422.0
const TEXT_BOTTOM := 351.0

signal interrupt_pressed
signal option_pressed(index: int)

@export var left_portrait: Texture2D = PORTRAIT_IDLE
@export var right_portrait: Texture2D = PORTRAIT_IDLE
@export var right_portrait_states: Dictionary[StringName, Texture2D] = {}
@export var left_source_region := ART_REGION
@export var right_source_region := ART_REGION
@export var right_speaker_id: StringName = &"right"
@export_enum("left", "right") var default_speaker_side := "left"
@export var two_person_dialogue := false
@export var use_side_choices := false
@export var externally_driven := false:
	set(value):
		externally_driven = value
		if is_node_ready(): _apply_input_ownership()
@export_range(0.0, 1.0, 0.01) var listener_opacity := 0.90
@export_range(0.0, 1.0, 0.01) var listener_brightness := 0.43
@export_range(0.0, 50.0, 1.0) var listener_drop := 29.0
@export_range(0.0, 0.8, 0.01) var background_dim := 0.38
@export_range(0.1, 0.8, 0.01) var entrance_seconds := 0.32

@onready var right_art: TextureRect = $Portrait/RightCharacterArt
@onready var background: ColorRect = $DimBackground
@onready var veil: ColorRect = $ArcVeil
@onready var side_choice_list: CHOICE_LIST = $SideChoiceList

var active_side: StringName = &"left"
var _speaker_tween: Tween
var _veil_tween: Tween
var _external_text := ""
var _external_page_starts: Array[int] = []
var _external_speaker_position := Vector2.ZERO
var _external_player_position := Vector2.ZERO
var _external_normal_options := false
var _external_interrupt_text := ""
var _interrupt_fragments: Control
var _next_external_expression: StringName = &"normal"
var _entering := false
var _presentation_progress := 1.0:
	set(value):
		_presentation_progress = value
		if is_instance_valid(veil) and veil.material != null:
			(veil.material as ShaderMaterial).set_shader_parameter(&"presentation_progress", value)


func _ready() -> void:
	super._ready()
	var font := READABLE_FONT.get_font()
	prompt_label.add_theme_font_override(&"font", font)
	prompt_label.add_theme_font_size_override(&"font_size", 12)
	prompt_label.add_theme_constant_override(&"line_spacing", 5)
	prompt_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.65))
	prompt_label.add_theme_constant_override(&"shadow_offset_y", 1)
	prompt_label.add_theme_constant_override(&"shadow_offset_x", 0)
	choice_option_group.show_selection_frame = false
	choice_option_group.enable_hover_scale = false
	if use_side_choices:
		side_choice_list.attach(buttons, choice_option_group)
		side_choice_list.interrupt_pressed.connect(_on_interrupt_pressed)
	background.color = Color(0.0, 0.0, 0.0, background_dim)
	var material := ShaderMaterial.new()
	material.shader = VEIL_SHADER
	veil.material = material
	_refresh_portrait()
	_apply_speaker_state(false)
	_apply_input_ownership()
	right_art.hide()


func _apply_input_ownership() -> void:
	set_process(not externally_driven)
	# The reception controller receives advance/cancel events. Only actual
	# choice buttons consume GUI input; there is no second typing clock.
	var filter := Control.MOUSE_FILTER_IGNORE if externally_driven else Control.MOUSE_FILTER_STOP
	mouse_filter = filter
	input_blocker.mouse_filter = filter
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if externally_driven else Control.MOUSE_FILTER_PASS
	dialogue_margin.mouse_filter = dialogue_panel.mouse_filter
	$DialoguePanel/Margin/Content.mouse_filter = dialogue_panel.mouse_filter


func _set_portrait_crop(art: TextureRect, source: Texture2D, region: Rect2) -> void:
	if source == null:
		art.texture = null
		return
	var crop := region if region.has_area() else Rect2(Vector2.ZERO, source.get_size())
	var current := art.texture as AtlasTexture
	if current != null and current.atlas == source and current.region == crop:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = crop
	atlas.filter_clip = true
	art.texture = atlas


func _apply_portrait_outline() -> void:
	# Keep the original portrait colors. The scene veil supplies the fade, with
	# no colored outline or extra render target around the character.
	character_art.material = null
	right_art.material = null


func _prepare_dialogue_lines(source_lines: Array) -> Array:
	var styled: Array = []
	var speakers: Dictionary = {}
	for raw in source_lines:
		if not raw is Dictionary: continue
		var speaker := str(raw.get("speaker", raw.get("speaker_side", ""))).strip_edges()
		if not speaker.is_empty() and speaker.to_lower() not in ["system", "narrator"]:
			speakers[speaker] = true
	var paired := two_person_dialogue or speakers.size() >= 2
	for raw in source_lines:
		if not raw is Dictionary:
			continue
		var line: Dictionary = raw.duplicate(true)
		# Legacy bedroom entries explicitly store 18px for the old box. The new
		# two-line presentation owns its font geometry without rewriting data.
		line.font_size = 12
		line.two_person_dialogue = bool(raw.get("two_person_dialogue", paired))
		if not line.has("text_color"): line.text_color = "#F4F4F4"
		styled.append(line)
	return super._prepare_dialogue_lines(styled)


func _dialogue_content_width() -> float:
	return TEXT_WIDTH


func _dialogue_page_line_capacity(font_size: int, _choice_count: int) -> int:
	var height := prompt_label.get_theme_font(&"font").get_height(font_size)
	# Interline spacing occurs between lines, not below the final line.
	return maxi(1, floori((44.0 + 5.0) / maxf(height + 5.0, 1.0)))


func _apply_line_presentation() -> void:
	var previous_side := active_side
	var side := str(current_line.get("speaker_side", ""))
	if side.is_empty():
		var speaker := StringName(str(current_line.get("speaker", "")))
		side = default_speaker_side if speaker == &"" else ("right" if speaker == right_speaker_id else "left")
	var has_right := bool(current_line.get("two_person_dialogue", two_person_dialogue)) and right_portrait != null
	active_side = &"right" if has_right and side == "right" else &"left"
	prompt_label.add_theme_color_override(&"font_color", Color.from_string(str(current_line.get("text_color", "#F4F4F4")), Color("f4f4f4")))
	prompt_label.add_theme_font_size_override(&"font_size", maxi(8, int(current_line.get("font_size", 12))))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	portrait.visible = str(current_line.get("portrait", "normal")) != "hidden"
	character_art.visible = left_portrait != null
	right_art.visible = has_right
	var choices_height := 0.0 if use_side_choices else current_choices.size() * 20.0
	var panel_height := 52.0 + choices_height
	dialogue_panel.size = Vector2(TEXT_WIDTH, panel_height)
	dialogue_target_position = Vector2(114.0, TEXT_BOTTOM - panel_height)
	dialogue_panel.position = dialogue_target_position
	if veil.material != null:
		(veil.material as ShaderMaterial).set_shader_parameter(&"bottom_lift", choices_height)
	_apply_portrait_expression(StringName(str(current_line.get("expression", "normal"))))
	_apply_speaker_state(visible and previous_side != active_side)
	if prompt_tween != null and prompt_tween.is_valid(): prompt_tween.kill()
	var fade_in := maxf(0.0, float(current_line.get("fade_in", 0.0)))
	prompt_label.modulate.a = 0.0 if fade_in > 0.0 else 1.0
	if fade_in > 0.0:
		prompt_tween = create_tween()
		prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, fade_in)


func _apply_speaker_state(animated: bool) -> void:
	if _speaker_tween != null and _speaker_tween.is_valid(): _speaker_tween.kill()
	var tint := Color(listener_brightness, listener_brightness, listener_brightness, listener_opacity)
	var left_color := Color.WHITE if active_side == &"left" else tint
	var right_color := Color.WHITE if active_side == &"right" else tint
	var left_pos := LEFT_REST + Vector2(0.0, listener_drop if active_side == &"right" else 0.0)
	var right_pos := RIGHT_REST + Vector2(0.0, listener_drop if active_side == &"left" else 0.0)
	if not animated:
		character_art.modulate = left_color
		right_art.modulate = right_color
		character_art.position = left_pos
		right_art.position = right_pos
		return
	_speaker_tween = create_tween().set_parallel(true)
	_speaker_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_speaker_tween.tween_property(character_art, "modulate", left_color, 0.16)
	_speaker_tween.tween_property(right_art, "modulate", right_color, 0.16)
	_speaker_tween.tween_property(character_art, "position", left_pos, 0.18)
	_speaker_tween.tween_property(right_art, "position", right_pos, 0.18)


func _refresh_portrait() -> void:
	var left_expression := portrait_expression if active_side == &"left" else &"normal"
	var left_source := left_portrait
	if left_source == PORTRAIT_IDLE:
		left_source = PLAYER_PORTRAITS.texture_for(left_expression)
	_set_portrait_crop(character_art, left_source, left_source_region)

	var right_expression := portrait_expression if active_side == &"right" else &"normal"
	var right_source := right_portrait
	if not right_portrait_states.is_empty():
		right_source = right_portrait_states.get(right_expression, right_portrait)
	elif right_source == PORTRAIT_IDLE:
		right_source = PLAYER_PORTRAITS.texture_for(right_expression)
	_set_portrait_crop(right_art, right_source, right_source_region)


func _apply_portrait_expression(expression: StringName) -> void:
	# Character-specific names must not be normalized through the player's set.
	portrait_expression = expression
	_refresh_portrait()


func _animate_in() -> void:
	_clear_interrupt_fragments()
	animation_token += 1
	var token := animation_token
	session_started.emit()
	visible = true
	animating = true
	_entering = true
	if _speaker_tween != null and _speaker_tween.is_valid(): _speaker_tween.kill()
	if _veil_tween != null and _veil_tween.is_valid(): _veil_tween.kill()
	_apply_speaker_state(false)
	var left_target := character_art.position
	var right_target := right_art.position
	character_art.position.x = -character_art.size.x - 24.0
	right_art.position.x = 664.0
	portrait.position = Vector2.ZERO
	portrait.modulate.a = 1.0
	background.modulate.a = 0.0
	veil.modulate.a = 1.0
	_presentation_progress = 0.0
	dialogue_panel.position = dialogue_target_position
	dialogue_panel.modulate.a = 0.0
	active_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "_presentation_progress", 1.0, entrance_seconds)
	active_tween.tween_property(character_art, "position", left_target, entrance_seconds)
	if right_art.visible:
		active_tween.tween_property(right_art, "position", right_target, entrance_seconds)
	active_tween.tween_property(background, "modulate:a", 1.0, entrance_seconds)
	_sync_side_choices()
	await active_tween.finished
	if token == animation_token and visible:
		_entering = false
		animating = false
		dialogue_panel.modulate.a = 1.0
		_sync_side_choices()


func _finish_dialog(was_confirmed: bool, action_id: StringName = &"") -> void:
	_entering = false
	if use_side_choices:
		side_choice_list.conceal()
	if _veil_tween != null and _veil_tween.is_valid(): _veil_tween.kill()
	if _speaker_tween != null and _speaker_tween.is_valid(): _speaker_tween.kill()
	var seconds := maxf(0.0, float(current_line.get("fade_out", config.dialog_animation_seconds)))
	# Hide letters before the supporting black matte moves away.
	dialogue_panel.modulate.a = 0.0
	_veil_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_veil_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_veil_tween.tween_property(self, "_presentation_progress", 0.0, seconds)
	_veil_tween.tween_property(character_art, "position:x", -character_art.size.x - 24.0, seconds)
	if right_art.visible:
		_veil_tween.tween_property(right_art, "position:x", 664.0, seconds)
	_veil_tween.tween_property(background, "modulate:a", 0.0, seconds)
	await super._finish_dialog(was_confirmed, action_id)


func close_without_signal() -> void:
	_entering = false
	_external_interrupt_text = ""
	_clear_interrupt_fragments()
	if use_side_choices:
		side_choice_list.conceal()
	if _speaker_tween != null and _speaker_tween.is_valid(): _speaker_tween.kill()
	if prompt_tween != null and prompt_tween.is_valid(): prompt_tween.kill()
	if _veil_tween != null and _veil_tween.is_valid(): _veil_tween.kill()
	super.close_without_signal()
	active_side = &"left"
	_apply_speaker_state(false)
	_refresh_portrait()
	_presentation_progress = 1.0


func _exit_tree() -> void:
	_clear_interrupt_fragments()


func _apply_choice_styles() -> void:
	super._apply_choice_styles()
	for button in choice_buttons:
		button.add_theme_font_override(&"font", READABLE_FONT.get_font())
		button.add_theme_font_size_override(&"font_size", 12)
		button.add_theme_color_override(&"font_color", Color("bec4c9"))
		button.add_theme_color_override(&"font_hover_color", Color.WHITE)
		button.add_theme_color_override(&"font_pressed_color", Color.WHITE)


func _rebuild_choice_buttons(choices: Array) -> void:
	super._rebuild_choice_buttons(choices)
	if use_side_choices:
		side_choice_list.prepare(choice_buttons)


func _begin_typewriter(prompt: String, line_data: Dictionary = {}) -> void:
	prompt_label.show()
	super._begin_typewriter(prompt, line_data)
	_sync_side_choices()


func _complete_typewriter() -> void:
	super._complete_typewriter()
	_sync_side_choices()


func _on_line_ready() -> void:
	super._on_line_ready()
	_sync_side_choices()


func _sync_side_choices() -> void:
	if not use_side_choices:
		return
	var ready_for_choices := _external_normal_options if externally_driven else line_ready
	if can_interrupt_typing():
		side_choice_list.show_interrupt(_external_interrupt_text if externally_driven else INTERRUPT_TEXT)
	elif visible and not animating and ready_for_choices and not current_choices.is_empty():
		side_choice_list.reveal()
	else:
		side_choice_list.conceal()


func can_interrupt_typing() -> bool:
	if not is_visible_in_tree() or not use_side_choices or (animating and not _entering):
		return false
	return not _external_interrupt_text.is_empty() if externally_driven else typewriter_active


func _on_interrupt_pressed() -> void:
	if not can_interrupt_typing():
		return
	if externally_driven:
		interrupt_pressed.emit()
	else:
		SFX.play_event(&"confirm")
		dismiss_interrupted()


func dismiss_interrupted() -> void:
	# Keep the letters on this canvas after the portrait and matte have left.
	if prompt_label.visible_characters > 0 and prompt_label.modulate.a > 0.0:
		_interrupt_fragments = GLYPH_FALL.spawn_from_label(get_parent(), prompt_label, prompt_label.visible_characters, GLYPH_LIFT)
	_stop_talking_portrait()
	_external_interrupt_text = ""
	line_ready = false
	pre_delay_remaining = 0.0
	post_delay_remaining = 0.0
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	_finish_dialog(false)


func _clear_interrupt_fragments() -> void:
	if is_instance_valid(_interrupt_fragments):
		_interrupt_fragments.hide()
		_interrupt_fragments.queue_free()
	_interrupt_fragments = null


func _can_choose() -> bool:
	return not use_side_choices or side_choice_list.interactive


func _on_choice_pressed(index: int) -> void:
	if not _can_choose():
		return
	if not externally_driven:
		super._on_choice_pressed(index)
		return
	if animating or not visible: return
	if index >= 0 and index < current_choices.size() and bool(current_choices[index].get("enabled", true)):
		option_pressed.emit(index)


func set_next_dialogue_expression(expression: StringName) -> void:
	_next_external_expression = expression


func show_dialogue(text: String, speaker_position: Vector2, choices: Array, interrupt_text: String = INTERRUPT_TEXT) -> void:
	var expression := _next_external_expression
	_next_external_expression = &"normal"
	var reuse := visible and not animating and externally_driven
	if not reuse: close_without_signal()
	_external_text = text
	_external_speaker_position = speaker_position
	_external_normal_options = false
	_external_interrupt_text = interrupt_text if not text.is_empty() else ""
	var styled_choices: Array = []
	for choice in choices:
		styled_choices.append(choice.duplicate(true) if choice is Dictionary else {"text": str(choice)})
	prompt_label.show()
	var line := {"text": text, "choices": styled_choices, "expression": expression, "typewriter_speed": 0.0, "blip": false}
	if reuse:
		dialogue_lines = _prepare_dialogue_lines([line])
		dialogue_line_index = 0
		_show_current_line()
	else:
		open_data({"lines": [line]})
	_external_page_starts.clear()
	var cursor := 0
	for page: Dictionary in dialogue_lines:
		var start := text.find(str(page.text), cursor)
		_external_page_starts.append(maxi(cursor, start))
		cursor = _external_page_starts.back() + str(page.text).length()
	set_typing_progress(0.0, 0)


func set_typing_progress(_progress: float, visible_chars: int) -> void:
	if not visible or _external_page_starts.is_empty(): return
	if visible_chars >= _external_text.length():
		_external_interrupt_text = ""
	if _entering:
		prompt_label.visible_characters = 0
		buttons.visible = false
		return
	var page := 0
	for index in range(1, _external_page_starts.size()):
		if visible_chars > _external_page_starts[index]: page = index
	if dialogue_line_index != page:
		dialogue_line_index = page
		_show_current_line()
	prompt_label.visible_characters = clampi(visible_chars - _external_page_starts[page], 0, full_prompt_text.length())
	if use_side_choices:
		_sync_side_choices()
	else:
		buttons.visible = _external_normal_options and not current_choices.is_empty()


func transition_to_normal_options() -> void:
	_external_normal_options = true
	if use_side_choices:
		_sync_side_choices()
	else:
		buttons.visible = not current_choices.is_empty()


func set_speaker_hud_position(position: Vector2) -> void:
	_external_speaker_position = position


func set_player_hud_position(position: Vector2) -> void:
	_external_player_position = position


func get_speaker_hud_position() -> Vector2:
	return _external_speaker_position


func get_player_hud_position() -> Vector2:
	return _external_player_position


func get_dialogue_label() -> Label:
	return prompt_label


func is_dialogue_visible() -> bool:
	return visible


func is_dialogue_entering() -> bool:
	return visible and _entering


func keeps_dialogue_presentation_between_lines() -> bool:
	return externally_driven


func dismiss(seconds: float = 0.15) -> void:
	if not visible: return
	if active_tween != null and active_tween.is_valid(): active_tween.kill()
	current_line["fade_out"] = seconds
	_finish_dialog(false)


func consume_escape() -> bool:
	if not visible or externally_driven: return false
	if not animating: _on_cancelled()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or animating: return
	if externally_driven:
		if current_choices.is_empty(): return
		if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down"):
			if _can_choose():
				choice_option_group.activate_delta(-1 if event.is_action_pressed(&"ui_up") else 1)
		elif event.is_action_pressed(&"ui_accept"):
			if _can_choose():
				if choice_option_group.get_active_index() < 0: choice_option_group.activate_delta(1, false)
				_on_choice_pressed(choice_option_group.get_active_index())
		else: return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"pickup_weapon"):
		if message_only or typewriter_active: _on_cancelled()
		elif _can_choose():
			if choice_option_group.get_active_index() < 0: choice_option_group.activate_delta(1, false)
			_on_choice_pressed(choice_option_group.get_active_index())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_on_cancelled()
		get_viewport().set_input_as_handled()
	elif not message_only and not typewriter_active and (event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")):
		if _can_choose():
			choice_option_group.activate_delta(-1 if event.is_action_pressed(&"ui_up") else 1)
		get_viewport().set_input_as_handled()
