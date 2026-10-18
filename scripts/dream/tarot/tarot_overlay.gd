class_name TarotOverlay
extends Control

signal selection_finished(selected_result: TarotDrawResult)
signal state_changed(new_state: State)

enum State {
	IDLE,
	ENTERING,
	SHUFFLING,
	DEALING,
	REVEALING,
	CHOOSING,
	COMMITTED,
	EXITING,
}

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/ui/tarot/tarot_card_view.tscn")
const CARD_BACK_TEX: Texture2D = preload("res://art/ui/tarot/card_back.png")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const TarotCardViewScript := preload("res://scripts/dream/tarot/tarot_card_view.gd")

const CARD_WIDTH: float = 153.0
const CARD_HEIGHT: float = 237.0
const CARD_SIZE := Vector2(CARD_WIDTH, CARD_HEIGHT)

const SLOT_X_LEFT: float = -190.0
const SLOT_X_CENTER: float = 0.0
const SLOT_X_RIGHT: float = 190.0

const SLOT_OFFSETS: Array[Vector2] = [
	Vector2(SLOT_X_LEFT, 0.0),
	Vector2(SLOT_X_CENTER, 0.0),
	Vector2(SLOT_X_RIGHT, 0.0),
]

@onready var dim_background: ColorRect = get_node_or_null("DimBackground")
@onready var header_container: Control = get_node_or_null("HeaderContainer")
@onready var title_label: Label = get_node_or_null("HeaderContainer/TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("HeaderContainer/SubtitleLabel")
@onready var card_slot_container: Control = get_node_or_null("CardSlotContainer")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")

var current_state: State = State.IDLE:
	set(val):
		current_state = val
		state_changed.emit(current_state)

var cards: Array[TarotCardView] = []
var _deck_stack: Control = null
var _selected_result: TarotDrawResult = null


func _ready() -> void:
	if prompt_label != null:
		prompt_label.visible = false
	if dim_background != null:
		dim_background.mouse_filter = Control.MOUSE_FILTER_STOP


func get_slot_position(index: int) -> Vector2:
	if index >= 0 and index < SLOT_OFFSETS.size():
		return SLOT_OFFSETS[index]
	return Vector2.ZERO


func get_cards() -> Array[TarotCardView]:
	return cards.duplicate()


func start_tarot_sequence(hand: Array = []) -> void:
	if hand.is_empty():
		var controller := TarotDrawController.new()
		hand = controller.draw_three()

	# Clean up previous state
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()
	cards.clear()

	if _deck_stack != null and is_instance_valid(_deck_stack):
		_deck_stack.queue_free()
		_deck_stack = null

	_selected_result = null
	visible = true
	modulate.a = 1.0

	if prompt_label != null:
		prompt_label.visible = false
		prompt_label.modulate.a = 0.0

	# Fade in background and header
	if dim_background != null:
		dim_background.visible = true
		dim_background.modulate.a = 0.0
		var bg_tween := create_tween()
		bg_tween.tween_property(dim_background, "modulate:a", 1.0, 0.3)

	if header_container != null:
		header_container.visible = true
		header_container.modulate.a = 0.0
		var header_tween := create_tween()
		header_tween.tween_property(header_container, "modulate:a", 1.0, 0.3)

	# Stage 1: Deck enters from screen bottom to center
	current_state = State.ENTERING
	_create_deck_stack()
	if _deck_stack != null:
		_deck_stack.position = Vector2(0.0, 450.0)
		var enter_tween := create_tween()
		enter_tween.tween_property(_deck_stack, "position", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await enter_tween.finished
		if not is_inside_tree():
			return

	# Stage 2: Shuffle animation (~0.6s) with tarot_shuffle
	current_state = State.SHUFFLING
	SFX.play_event(&"tarot_shuffle")
	await _animate_shuffle(0.6)
	if not is_inside_tree():
		return

	# Stage 3: Deal 3 cards facedown to Left, Center, Right with slight rotation variation and spring overshoot
	current_state = State.DEALING
	var draw_count := mini(hand.size(), 3)
	for i in range(draw_count):
		var view := CARD_VIEW_SCENE.instantiate() as TarotCardView
		view.draw_result = hand[i]
		view.is_revealed = false
		view.interactive = false
		card_slot_container.add_child(view)

		var start_pos := Vector2.ZERO - view.size * 0.5
		var target_pos := get_slot_position(i) - view.size * 0.5
		var target_rot: float = 0.0
		match i:
			0: target_rot = -3.0
			1: target_rot = 0.0
			2: target_rot = 3.0

		view.position = start_pos
		view.scale = Vector2.ONE
		view.rotation_degrees = 0.0
		view.base_position = target_pos
		view.base_rotation_degrees = target_rot
		view.base_scale = Vector2.ONE
		view.base_z_index = i * 2
		view.z_index = view.base_z_index
		cards.append(view)

	# Discard temporary deck stack
	if _deck_stack != null and is_instance_valid(_deck_stack):
		_deck_stack.queue_free()
		_deck_stack = null

	# Stagger deal animations with spring overshoot
	for i in range(cards.size()):
		var c := cards[i]
		var deal_tween := create_tween().set_parallel(true)
		deal_tween.tween_property(c, "position", c.base_position, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal_tween.tween_property(c, "rotation_degrees", c.base_rotation_degrees, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		SFX.play_event(&"tarot_deal")
		if i < cards.size() - 1:
			await get_tree().create_timer(0.08).timeout
			if not is_inside_tree():
				return

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	# Stage 4: Reveal cards staggered (Left -> wait 0.2s -> Center -> wait 0.2s -> Right) calling flip()
	current_state = State.REVEALING
	for i in range(cards.size()):
		cards[i].flip()
		if i < cards.size() - 1:
			await get_tree().create_timer(0.2).timeout
			if not is_inside_tree():
				return

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	# Stage 5: Once all 3 are flipped, set state = CHOOSING, enable interactive = true, show PromptLabel
	current_state = State.CHOOSING
	for c in cards:
		c.interactive = true
		c.card_selected.connect(_on_card_selected)

	if prompt_label != null:
		prompt_label.visible = true
		prompt_label.modulate.a = 0.0
		var p_tween := create_tween()
		p_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _create_deck_stack() -> void:
	if card_slot_container == null:
		return
	_deck_stack = Control.new()
	_deck_stack.name = "DeckStack"
	_deck_stack.custom_minimum_size = CARD_SIZE
	_deck_stack.size = CARD_SIZE
	_deck_stack.pivot_offset = CARD_SIZE * 0.5
	_deck_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_slot_container.add_child(_deck_stack)

	# Create a layered deck stack of 4 card backs with subtle 1px offsets
	for i in range(4):
		var rect := TextureRect.new()
		rect.texture = CARD_BACK_TEX
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.offset_left = -CARD_WIDTH * 0.5 + (i * -1.0)
		rect.offset_top = -CARD_HEIGHT * 0.5 + (i * -2.0)
		rect.offset_right = CARD_WIDTH * 0.5 + (i * -1.0)
		rect.offset_bottom = CARD_HEIGHT * 0.5 + (i * -2.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deck_stack.add_child(rect)


func _animate_shuffle(duration: float) -> Signal:
	var t := create_tween()
	var steps := 6
	var step_time := duration / float(steps)

	for s in range(steps):
		var angle := 4.0 if (s % 2 == 0) else -4.0
		var offset_x := 18.0 if (s % 2 == 0) else -18.0
		if s == steps - 1:
			angle = 0.0
			offset_x = 0.0
		t.tween_property(_deck_stack, "rotation_degrees", angle, step_time).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(_deck_stack, "position:x", offset_x, step_time).set_trans(Tween.TRANS_SINE)

	return t.finished


func _on_card_selected(view: TarotCardView) -> void:
	if current_state != State.CHOOSING:
		return

	# Stage 6: Player clicks one card -> COMMITTED, interactive = false
	current_state = State.COMMITTED
	_selected_result = view.draw_result

	for c in cards:
		c.interactive = false

	# Hide prompt label & header
	if prompt_label != null:
		var p_tween := create_tween()
		p_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.15)
	if header_container != null:
		var h_tween := create_tween()
		h_tween.tween_property(header_container, "modulate:a", 0.0, 0.15)

	# Unselected cards rapidly shrink and fly outward
	for c in cards:
		if c == view:
			continue
		var fly_tween := create_tween().set_parallel(true)
		var fly_pos: Vector2
		if c.position.x < view.position.x - 30.0:
			fly_pos = c.position + Vector2(-450.0, 80.0)
		elif c.position.x > view.position.x + 30.0:
			fly_pos = c.position + Vector2(450.0, 80.0)
		else:
			fly_pos = c.position + Vector2(0.0, 450.0)

		fly_tween.tween_property(c, "position", fly_pos, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tween.tween_property(c, "scale", Vector2.ZERO, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tween.tween_property(c, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Selected card moves to screen center, scales up 1.25x with punch, plays tarot_select
	view.z_index = 100
	var center_pos := Vector2.ZERO - view.size * 0.5
	var select_tween := create_tween().set_parallel(true)
	select_tween.tween_property(view, "position", center_pos, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	select_tween.tween_property(view, "rotation_degrees", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Overshoot punch then settle at 1.25x
	select_tween.tween_property(view, "scale", Vector2(1.36, 1.36), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	select_tween.chain().tween_property(view, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	SFX.play_event(&"tarot_select")
	view.is_selected = true

	# Hold for 0.8s for clear readability
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return

	current_state = State.EXITING
	selection_finished.emit(_selected_result)


func dismiss(duration: float = 0.3) -> Signal:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, duration)
	t.finished.connect(func():
		visible = false
		modulate.a = 1.0
		current_state = State.IDLE
		for c in cards:
			if is_instance_valid(c):
				c.queue_free()
		cards.clear()
	)
	return t.finished
