class_name BedroomConfirmationDialog
extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal confirmed
signal cancelled

@export var config: DemoConfig

@onready var input_blocker: Control = $InputBlocker
@onready var portrait: Control = $Portrait
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_target_position = dialogue_panel.position
	confirm_button.pressed.connect(_on_confirmed)
	cancel_button.pressed.connect(_on_cancelled)
	confirm_button.mouse_entered.connect(_set_choice_hover.bind(confirm_button, true))
	confirm_button.mouse_exited.connect(_set_choice_hover.bind(confirm_button, false))
	cancel_button.mouse_entered.connect(_set_choice_hover.bind(cancel_button, true))
	cancel_button.mouse_exited.connect(_set_choice_hover.bind(cancel_button, false))
	input_blocker.gui_input.connect(_on_blocker_gui_input)


func open(prompt: String, confirm_text: String, cancel_text: String, confirm_enabled: bool = true) -> void:
	if visible:
		return
	message_only = false
	buttons.visible = true
	prompt_label.text = prompt
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
	prompt_label.text = prompt
	await _animate_in()


func _animate_in() -> void:
	animation_token += 1
	var token := animation_token
	visible = true
	animating = true
	portrait.position = config.dialog_portrait_appearance_position - Vector2(36.0, 0.0)
	portrait.modulate.a = 0.0
	dialogue_panel.position = dialogue_target_position + Vector2(0.0, 8.0)
	dialogue_panel.modulate.a = 0.0
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(portrait, "position", config.dialog_portrait_appearance_position, config.dialog_animation_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(portrait, "modulate:a", 1.0, config.dialog_animation_seconds)
	active_tween.tween_property(dialogue_panel, "position", dialogue_target_position, config.dialog_animation_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(dialogue_panel, "modulate:a", 1.0, config.dialog_animation_seconds * 0.75)
	await active_tween.finished
	if token == animation_token and visible:
		animating = false


func close_without_signal() -> void:
	animation_token += 1
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	visible = false
	animating = false
	message_only = false
	portrait.modulate.a = 0.0
	dialogue_panel.modulate.a = 0.0


func _on_confirmed() -> void:
	if animating or confirm_button.disabled:
		return
	SFX.play_event(&"confirm")
	_finish_dialog(true)


func _on_cancelled() -> void:
	if animating:
		return
	SFX.play_event(&"confirm")
	_finish_dialog(false)


func _finish_dialog(was_confirmed: bool) -> void:
	animating = true
	animation_token += 1
	var token := animation_token
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(portrait, "position", config.dialog_portrait_appearance_position - Vector2(36.0, 0.0), config.dialog_animation_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	active_tween.tween_property(portrait, "modulate:a", 0.0, config.dialog_animation_seconds)
	active_tween.tween_property(dialogue_panel, "position", dialogue_target_position + Vector2(0.0, 8.0), config.dialog_animation_seconds * 0.8)
	active_tween.tween_property(dialogue_panel, "modulate:a", 0.0, config.dialog_animation_seconds * 0.65)
	await active_tween.finished
	if token != animation_token:
		return
	visible = false
	animating = false
	message_only = false
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
