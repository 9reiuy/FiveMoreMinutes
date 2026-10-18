class_name DreamDialogueController
extends Node

## Manages typewriter timing, unified single-clock countdown authority,
## 20% interrupt window gate, and coordinates with DreamDialogueBubble.
## Supports single dialogue lines and multi-line sequences (TASK-019-B).

signal dialogue_interrupted
signal dialogue_finished(interrupted: bool, action_id: Variant)
signal dialogue_option_selected(index: int, choice_data: Dictionary)
signal dialogue_sequence_finished
signal dialogue_line_started(line_index: int, line_data: Dictionary)
signal state_changed(old_state: State, new_state: State)
signal progress_updated(progress_ratio: float, typed_chars: int)

enum State {
	IDLE,
	TYPING_INTERRUPT,
	NORMAL_OPTIONS,
	WAITING_INPUT,
	INTERRUPTED,
	CLOSED
}

const INTERRUPT_WINDOW: State = State.TYPING_INTERRUPT
const TYPING_NORMAL: State = State.NORMAL_OPTIONS

const DEFAULT_TYPEWRITER_SPEED: float = 0.035
const DEFAULT_INTERRUPT_THRESHOLD: float = 0.20
const DEFAULT_COUNTDOWN_EXTRA: float = 4.0
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const GlyphFallFX := preload("res://scripts/ui/dialogue/dream_dialogue_glyph_fall_fx.gd")

var state: State = State.IDLE:
	set(new_val):
		if state != new_val:
			var prev: State = state
			state = new_val
			state_changed.emit(prev, new_val)

var current_bubble: Control = null
var current_text: String = ""
var current_choices: Array = []
var current_speaker_hud_pos: Vector2 = Vector2.ZERO
var current_player_hud_pos: Vector2 = Vector2.ZERO

var total_chars: int = 0
var typed_chars: int = 0

# Unified Countdown Authority (Single Clock)
var elapsed: float = 0.0
var typewriter_duration: float = 0.0
var line_total_duration: float = 4.0
var elapsed_ratio: float = 0.0
var progress_ratio: float = 0.0
var remaining_ratio: float = 1.0
var progress: float = 0.0 # Mirrors progress_ratio (starts at 0.0, grows to 1.0)

var typewriter_speed: float = DEFAULT_TYPEWRITER_SPEED
var interrupt_threshold: float = DEFAULT_INTERRUPT_THRESHOLD
var countdown_extra: float = DEFAULT_COUNTDOWN_EXTRA
var blip_sound: StringName = &"text_blip"
var interrupt_sound: StringName = &"confirm"

# Multi-line sequence state
var _is_in_sequence: bool = false
var _is_playing_sequence_line: bool = false
var _sequence_lines: Array = []
var _sequence_index: int = 0
var _speaker_hud_pos_getter: Callable = Callable()
var _player_hud_pos_getter: Callable = Callable()
var _sequence_options: Dictionary = {}
var _line_start_frame:=0
var _is_transitioning_line: bool = false


func _process(delta: float) -> void:
	if state != State.TYPING_INTERRUPT and state != State.NORMAL_OPTIONS and state != State.WAITING_INPUT:
		return

	# Dynamic speaker & player tracking during sequences
	if _is_in_sequence:
		if _speaker_hud_pos_getter.is_valid():
			var pos_variant: Variant = _speaker_hud_pos_getter.call()
			if pos_variant is Vector2:
				set_speaker_hud_position(pos_variant)
		if _player_hud_pos_getter.is_valid():
			var player_pos_variant: Variant = _player_hud_pos_getter.call()
			if player_pos_variant is Vector2:
				set_player_hud_position(player_pos_variant)

	# Special case: instant typing
	if typewriter_speed <= 0.0:
		typed_chars = total_chars
		typewriter_duration = 0.0

	# Advance single clock (left-to-right: 0.0 -> 1.0)
	elapsed += delta
	elapsed_ratio = clampf(elapsed / line_total_duration if line_total_duration > 0.0 else 1.0, 0.0, 1.0)
	progress_ratio = elapsed_ratio
	remaining_ratio = clampf(1.0 - progress_ratio, 0.0, 1.0)
	progress = progress_ratio

	# Typewriter text reveal & blip sound
	if typewriter_speed > 0.0:
		if elapsed < typewriter_duration:
			var target_chars: int = clampi(int(elapsed / typewriter_speed), 0, total_chars)
			while typed_chars < target_chars:
				typed_chars += 1
				var char_revealed: String = current_text.substr(typed_chars - 1, 1)
				if not char_revealed.strip_edges().is_empty():
					SFX.play_event(blip_sound)
		else:
			while typed_chars < total_chars:
				typed_chars += 1
				var char_revealed: String = current_text.substr(typed_chars - 1, 1)
				if not char_revealed.strip_edges().is_empty():
					SFX.play_event(blip_sound)

	_update_bubble_progress()

	# 20% Interrupt Window Gate Check (progress_ratio > 0.20 -> NORMAL_OPTIONS)
	if state == State.TYPING_INTERRUPT and progress_ratio > interrupt_threshold:
		state = State.NORMAL_OPTIONS
		if is_instance_valid(current_bubble) and current_bubble.has_method("transition_to_normal_options"):
			current_bubble.transition_to_normal_options()

	# Countdown Expiration Check (progress_ratio >= 1.0)
	if progress_ratio >= 1.0:
		_on_line_countdown_finished()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_in_sequence or not is_active():
		return
	if bool(_sequence_options.get("compact_dialogue",false)):
		if event.is_action_pressed(&"ui_cancel"):
			dismiss_if_active()
			dialogue_finished.emit(false,&"cancelled")
			get_viewport().set_input_as_handled()
			return
		if Engine.get_process_frames()<=_line_start_frame: return
	if state == State.TYPING_INTERRUPT:
		return # Red interrupt window active: do not advance on player inputs
	if _is_transitioning_line:
		return

	# Only allow advancing if current line has no choices to click
	if not current_choices.is_empty():
		return

	var is_interact_action: bool = event.is_action_pressed(&"pickup_weapon") or event.is_action_pressed(&"ui_accept")
	var is_left_click: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			is_left_click = true

	if is_interact_action or is_left_click:
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		advance_sequence()


func start_dialogue(
	bubble: Control,
	text: String,
	choices: Array,
	speaker_hud_pos: Vector2,
	options: Dictionary = {},
	player_hud_pos: Vector2 = Vector2.ZERO
) -> void:
	if not _is_playing_sequence_line:
		_is_in_sequence = false

	_cleanup_bubble_connections()

	current_bubble = bubble
	current_text = text
	current_choices = choices
	current_speaker_hud_pos = speaker_hud_pos
	current_player_hud_pos = player_hud_pos
	if current_player_hud_pos == Vector2.ZERO and options.has("player_hud_pos"):
		var opt_pos: Variant = options["player_hud_pos"]
		if opt_pos is Vector2:
			current_player_hud_pos = opt_pos

	typewriter_speed = float(options.get("typewriter_speed", DEFAULT_TYPEWRITER_SPEED))
	interrupt_threshold = float(options.get("interrupt_threshold", DEFAULT_INTERRUPT_THRESHOLD))
	countdown_extra = float(options.get("countdown_extra", DEFAULT_COUNTDOWN_EXTRA))
	blip_sound = StringName(options.get("blip_sound", &"text_blip"))
	interrupt_sound = StringName(options.get("interrupt_sound", &"confirm"))

	total_chars = text.length()
	typed_chars = 0
	elapsed = 0.0
	elapsed_ratio = 0.0
	progress_ratio = 0.0
	remaining_ratio = 1.0
	progress = 0.0

	# Unified single clock calculation:
	# line_total_duration = typewriter_duration + countdown_extra (4.0s)
	if typewriter_speed > 0.0:
		typewriter_duration = float(total_chars) * typewriter_speed
	else:
		typewriter_duration = 0.0
	line_total_duration = typewriter_duration + countdown_extra

	if is_instance_valid(current_bubble):
		if current_bubble.has_signal("interrupt_pressed"):
			if not current_bubble.interrupt_pressed.is_connected(trigger_interrupt):
				current_bubble.interrupt_pressed.connect(trigger_interrupt)
		if current_bubble.has_signal("option_pressed"):
			if not current_bubble.option_pressed.is_connected(_on_bubble_option_pressed):
				current_bubble.option_pressed.connect(_on_bubble_option_pressed)

		if current_bubble.has_method("set_player_hud_position") and current_player_hud_pos != Vector2.ZERO:
			current_bubble.set_player_hud_position(current_player_hud_pos)

		if current_bubble.has_method("show_dialogue"):
			if options.has("interrupt_text"):
				current_bubble.show_dialogue(text, speaker_hud_pos, choices, options["interrupt_text"])
			else:
				current_bubble.show_dialogue(text, speaker_hud_pos, choices)
		elif current_bubble.has_method("set_speaker_hud_position"):
			current_bubble.set_speaker_hud_position(speaker_hud_pos)

		if current_bubble.has_method("set_player_hud_position") and current_player_hud_pos != Vector2.ZERO:
			current_bubble.set_player_hud_position(current_player_hud_pos)

		if current_bubble.has_method("set_typing_progress"):
			current_bubble.set_typing_progress(progress_ratio, 0)

	if total_chars == 0:
		state = State.NORMAL_OPTIONS
		if is_instance_valid(current_bubble) and current_bubble.has_method("transition_to_normal_options"):
			current_bubble.transition_to_normal_options()
		_update_bubble_progress()
	else:
		state = State.NORMAL_OPTIONS if bool(options.get("compact_dialogue",false)) else State.TYPING_INTERRUPT
	_line_start_frame=Engine.get_process_frames()


func start_dialogue_sequence(
	bubble: Control,
	lines: Array,
	speaker_hud_pos_getter: Callable,
	options: Dictionary = {},
	player_hud_pos_getter: Callable = Callable()
) -> void:
	dismiss_if_active()

	if lines.is_empty():
		dialogue_sequence_finished.emit()
		dialogue_finished.emit(false, &"sequence_finished")
		return

	current_bubble = bubble
	_is_in_sequence = true
	_sequence_lines = lines.duplicate()
	_sequence_index = 0
	_speaker_hud_pos_getter = speaker_hud_pos_getter
	_player_hud_pos_getter = player_hud_pos_getter
	_sequence_options = options.duplicate()
	_is_transitioning_line = false

	_play_sequence_line(_sequence_index)


func advance_sequence() -> void:
	if not _is_in_sequence or _is_transitioning_line:
		return
	if state == State.TYPING_INTERRUPT or state == State.INTERRUPTED or state == State.CLOSED or state == State.IDLE:
		return

	_advance_to_next_sequence_line()


func trigger_interrupt() -> void:
	if state != State.TYPING_INTERRUPT:
		return

	state = State.INTERRUPTED
	_is_in_sequence = false
	_is_transitioning_line = false

	var source_label: Label = null
	if is_instance_valid(current_bubble):
		if current_bubble.has_method("get_dialogue_label"):
			source_label = current_bubble.get_dialogue_label()
		elif current_bubble.has_node("MarginContainer/VBoxContainer/DialogueLabel"):
			source_label = current_bubble.get_node("MarginContainer/VBoxContainer/DialogueLabel") as Label
		elif current_bubble.has_node("DialogueLabel"):
			source_label = current_bubble.get_node("DialogueLabel") as Label

	if source_label != null:
		source_label.visible = false
		var fx_parent: Node = current_bubble.get_parent() if current_bubble.get_parent() != null else current_bubble
		GlyphFallFX.spawn_from_label(fx_parent, source_label, typed_chars)

	SFX.play_event(interrupt_sound)
	dialogue_interrupted.emit()

	_handle_interrupt_dismiss()


func select_option(index: int) -> void:
	if state != State.NORMAL_OPTIONS and state != State.WAITING_INPUT:
		return

	var choice_data: Dictionary = {}
	if index >= 0 and index < current_choices.size():
		var raw: Variant = current_choices[index]
		if raw is Dictionary:
			choice_data = raw as Dictionary

	var action_id: Variant = choice_data.get("action_id", &"")
	if action_id is String:
		action_id = StringName(action_id)

	dialogue_option_selected.emit(index, choice_data)

	if is_instance_valid(current_bubble) and current_bubble.has_method("dismiss"):
		current_bubble.dismiss()

	_cleanup_bubble_connections()
	state = State.CLOSED

	if _is_in_sequence:
		_is_in_sequence = false
		dialogue_sequence_finished.emit()

	dialogue_finished.emit(false, action_id)


func dismiss_if_active() -> void:
	if state == State.IDLE or state == State.CLOSED:
		return

	_is_in_sequence = false
	_is_transitioning_line = false

	if is_instance_valid(current_bubble) and current_bubble.has_method("dismiss"):
		current_bubble.dismiss()

	_cleanup_bubble_connections()
	current_bubble = null
	state = State.IDLE
	typed_chars = 0
	progress = 0.0
	elapsed = 0.0
	remaining_ratio = 0.0
	elapsed_ratio = 0.0


func set_speaker_hud_position(pos: Vector2) -> void:
	current_speaker_hud_pos = pos
	if is_instance_valid(current_bubble) and current_bubble.has_method("set_speaker_hud_position"):
		current_bubble.set_speaker_hud_position(pos)


func set_player_hud_position(pos: Vector2) -> void:
	current_player_hud_pos = pos
	if is_instance_valid(current_bubble) and current_bubble.has_method("set_player_hud_position"):
		current_bubble.set_player_hud_position(pos)


func can_interrupt() -> bool:
	return state == State.TYPING_INTERRUPT


func is_typing() -> bool:
	return (state == State.TYPING_INTERRUPT or state == State.NORMAL_OPTIONS) and elapsed < typewriter_duration


func is_waiting_input() -> bool:
	return (state == State.NORMAL_OPTIONS or state == State.WAITING_INPUT) and elapsed >= typewriter_duration


func is_active() -> bool:
	return state != State.IDLE and state != State.CLOSED


func _update_bubble_progress() -> void:
	if is_instance_valid(current_bubble) and current_bubble.has_method("set_typing_progress"):
		current_bubble.set_typing_progress(progress_ratio, typed_chars)
	progress_updated.emit(progress_ratio, typed_chars)


func _on_line_countdown_finished() -> void:
	if _is_in_sequence:
		_advance_to_next_sequence_line()
	else:
		if is_instance_valid(current_bubble) and current_bubble.has_method("dismiss"):
			current_bubble.dismiss()
		_cleanup_bubble_connections()
		state = State.CLOSED
		dialogue_finished.emit(false, &"timeout")


func _play_sequence_line(index: int) -> void:
	if index < 0 or index >= _sequence_lines.size():
		_finish_sequence()
		return

	var raw_line: Variant = _sequence_lines[index]
	var line_text: String = ""
	var line_choices: Array = []
	var line_options: Dictionary = _sequence_options.duplicate()
	var line_dict: Dictionary = {}

	if raw_line is Dictionary:
		line_dict = raw_line as Dictionary
		line_text = str(line_dict.get("text", ""))
		if line_dict.has("choices") and line_dict["choices"] is Array:
			line_choices = line_dict["choices"] as Array
		for key: Variant in line_dict.keys():
			var skey: String = str(key)
			if skey != "text" and skey != "choices":
				line_options[skey] = line_dict[key]
	elif raw_line is String:
		line_text = str(raw_line)
		line_dict = {"text": line_text}

	var pos: Vector2 = current_speaker_hud_pos
	if _speaker_hud_pos_getter.is_valid():
		var pos_variant: Variant = _speaker_hud_pos_getter.call()
		if pos_variant is Vector2:
			pos = pos_variant

	var player_pos: Vector2 = current_player_hud_pos
	if _player_hud_pos_getter.is_valid():
		var player_pos_variant: Variant = _player_hud_pos_getter.call()
		if player_pos_variant is Vector2:
			player_pos = player_pos_variant
	elif line_options.has("player_hud_pos"):
		var opt_player_pos: Variant = line_options["player_hud_pos"]
		if opt_player_pos is Vector2:
			player_pos = opt_player_pos

	dialogue_line_started.emit(index, line_dict)

	_is_playing_sequence_line = true
	start_dialogue(current_bubble, line_text, line_choices, pos, line_options, player_pos)
	_is_playing_sequence_line = false


func _advance_to_next_sequence_line() -> void:
	if not _is_in_sequence or _is_transitioning_line:
		return

	_sequence_index += 1
	if _sequence_index >= _sequence_lines.size():
		_finish_sequence()
		return

	_is_transitioning_line = true
	if bool(_sequence_options.get("compact_dialogue",false)) and is_instance_valid(current_bubble):
		current_bubble.dismiss(.10)

	var tree: SceneTree = get_tree()
	if tree != null:
		await tree.create_timer(0.10).timeout

	_is_transitioning_line = false

	if not _is_in_sequence or state == State.INTERRUPTED or state == State.CLOSED or state == State.IDLE:
		return

	_play_sequence_line(_sequence_index)


func _finish_sequence() -> void:
	_is_in_sequence = false
	_is_transitioning_line = false
	if is_instance_valid(current_bubble) and current_bubble.has_method("dismiss"):
		current_bubble.dismiss()
	_cleanup_bubble_connections()
	state = State.CLOSED
	dialogue_sequence_finished.emit()
	dialogue_finished.emit(false, &"sequence_finished")


func _handle_interrupt_dismiss() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		await tree.create_timer(0.5).timeout

	if is_instance_valid(current_bubble) and current_bubble.has_method("dismiss"):
		current_bubble.dismiss()

	_cleanup_bubble_connections()
	state = State.CLOSED
	dialogue_finished.emit(true, &"interrupt")


func _on_bubble_option_pressed(index: int) -> void:
	select_option(index)


func _cleanup_bubble_connections() -> void:
	if is_instance_valid(current_bubble):
		if current_bubble.has_signal("interrupt_pressed") and current_bubble.interrupt_pressed.is_connected(trigger_interrupt):
			current_bubble.interrupt_pressed.disconnect(trigger_interrupt)
		if current_bubble.has_signal("option_pressed") and current_bubble.option_pressed.is_connected(_on_bubble_option_pressed):
			current_bubble.option_pressed.disconnect(_on_bubble_option_pressed)


func _exit_tree() -> void:
	_cleanup_bubble_connections()
