class_name TarotCardView
extends Control

signal card_selected(view: TarotCardView)
signal card_hovered(view: TarotCardView, hovered: bool)

const CARD_WIDTH: float = 153.0
const CARD_HEIGHT: float = 237.0
const CARD_SIZE := Vector2(CARD_WIDTH, CARD_HEIGHT)
const SFX := preload("res://scripts/audio/sfx_manager.gd")

const COLOR_UPRIGHT := Color(1.0, 0.85, 0.35, 1.0) # Gold / Amber
const COLOR_REVERSED := Color(0.38, 0.78, 1.0, 1.0) # Cold Cyan / Indigo

@onready var card_shadow: Control = get_node_or_null("CardShadow")
@onready var card_flipper: Control = get_node_or_null("CardFlipper")
@onready var card_back: TextureRect = get_node_or_null("CardFlipper/CardBack")
@onready var card_front: Control = get_node_or_null("CardFlipper/CardFront")
@onready var card_art: TextureRect = get_node_or_null("CardFlipper/CardFront/CardArt")
@onready var label_container: Control = get_node_or_null("LabelContainer")
@onready var card_name_label: Label = get_node_or_null("LabelContainer/BadgeContent/CardNameLabel") if has_node("LabelContainer/BadgeContent/CardNameLabel") else get_node_or_null("LabelContainer/CardNameLabel")
@onready var orientation_label: Label = get_node_or_null("LabelContainer/BadgeContent/OrientationLabel") if has_node("LabelContainer/BadgeContent/OrientationLabel") else get_node_or_null("LabelContainer/OrientationLabel")
@onready var selection_glow: Control = get_node_or_null("SelectionGlow")

var draw_result: TarotDrawResult:
	set(val):
		draw_result = val
		_update_card_display()

var is_revealed: bool = false
var is_selected: bool = false:
	set(val):
		is_selected = val
		_update_selection_visual()

var is_hovered: bool = false
var interactive: bool = false:
	set(val):
		interactive = val
		mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

var base_position: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2.ONE
var base_rotation_degrees: float = 0.0
var base_z_index: int = 0

var _flip_tween: Tween
var _hover_tween: Tween
var _glow_tween: Tween


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5

	if card_flipper != null:
		card_flipper.pivot_offset = CARD_SIZE * 0.5
	if card_art != null:
		card_art.pivot_offset = CARD_SIZE * 0.5
		card_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if card_back != null:
		card_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if base_position == Vector2.ZERO:
		base_position = position
	base_scale = scale
	base_rotation_degrees = rotation_degrees
	base_z_index = z_index

	if draw_result != null:
		_update_card_display()
	else:
		_reset_visuals_facedown()


func _reset_visuals_facedown() -> void:
	if card_back != null:
		card_back.visible = true
	if card_front != null:
		card_front.visible = false
	if label_container != null:
		label_container.visible = false
	if selection_glow != null:
		selection_glow.visible = false
	if card_art != null:
		card_art.rotation_degrees = 0.0


func _update_card_display() -> void:
	if not is_inside_tree():
		return
	if draw_result == null:
		_reset_visuals_facedown()
		return

	var def := draw_result.card_def
	if def != null:
		if card_art != null and def.front_texture != null:
			card_art.texture = def.front_texture
		if card_back != null and def.back_texture != null:
			card_back.texture = def.back_texture
		if card_name_label != null:
			card_name_label.text = def.display_name_zh
	else:
		if card_name_label != null:
			card_name_label.text = ""

	if orientation_label != null:
		if draw_result.is_reversed:
			orientation_label.text = "逆位"
			orientation_label.modulate = COLOR_REVERSED
		else:
			orientation_label.text = "正位"
			orientation_label.modulate = COLOR_UPRIGHT

	if is_revealed:
		if card_back != null:
			card_back.visible = false
		if card_front != null:
			card_front.visible = true
		if label_container != null:
			label_container.visible = true
			label_container.rotation_degrees = 0.0
		if card_art != null:
			card_art.rotation_degrees = 180.0 if draw_result.is_reversed else 0.0
	else:
		_reset_visuals_facedown()


func flip(animated: bool = true) -> Tween:
	if is_revealed:
		return null

	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()

	if not animated:
		is_revealed = true
		if card_back != null:
			card_back.visible = false
		if card_front != null:
			card_front.visible = true
		if label_container != null:
			label_container.visible = true
			label_container.modulate.a = 1.0
			label_container.rotation_degrees = 0.0
		if card_art != null:
			card_art.rotation_degrees = 180.0 if (draw_result != null and draw_result.is_reversed) else 0.0
		if card_flipper != null:
			card_flipper.scale = Vector2.ONE
		return null

	SFX.play_event(&"tarot_flip")
	_flip_tween = create_tween()
	_flip_tween.set_parallel(false)

	# Phase 1: Fold card horizontally to 0 scale
	if card_flipper != null:
		_flip_tween.tween_property(card_flipper, "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Midpoint: swap face visibility and rotate artwork if reversed
	_flip_tween.tween_callback(func():
		is_revealed = true
		if card_back != null:
			card_back.visible = false
		if card_front != null:
			card_front.visible = true
		if label_container != null:
			label_container.visible = true
			label_container.modulate.a = 1.0
			label_container.rotation_degrees = 0.0
		if card_art != null:
			card_art.rotation_degrees = 180.0 if (draw_result != null and draw_result.is_reversed) else 0.0
	)

	# Phase 2: Unfold scale:x back to 1.0 with vertical punch & settle
	_flip_tween.set_parallel(true)
	if card_flipper != null:
		_flip_tween.tween_property(card_flipper, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_flip_tween.tween_property(card_flipper, "scale:y", 1.08, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_flip_tween.chain().tween_property(card_flipper, "scale:y", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	return _flip_tween


func _on_mouse_entered() -> void:
	if not interactive or is_selected:
		return
	is_hovered = true
	z_index = base_z_index + 10
	SFX.play_event(&"tarot_deal")
	card_hovered.emit(self, true)
	_animate_hover(true)


func _on_mouse_exited() -> void:
	if not is_hovered:
		return
	is_hovered = false
	if not is_selected:
		z_index = base_z_index
	card_hovered.emit(self, false)
	_animate_hover(false)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return

	if event is InputEventMouseMotion and is_hovered and not is_selected:
		var motion := event as InputEventMouseMotion
		var rel_x: float = motion.position.x - size.x * 0.5
		var tilt: float = clampf((rel_x / (size.x * 0.5)) * 2.0, -2.5, 2.5)
		rotation_degrees = base_rotation_degrees + tilt

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not is_selected:
				card_selected.emit(self)
				accept_event()


func _animate_hover(hovered: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true)
	if hovered:
		var target_pos := Vector2(base_position.x, base_position.y - 20.0)
		_hover_tween.tween_property(self, "position", target_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "scale", base_scale * 1.06, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if card_shadow != null:
			_hover_tween.tween_property(card_shadow, "position", Vector2(8, 22), 0.15)
			_hover_tween.tween_property(card_shadow, "modulate:a", 0.35, 0.15)
	else:
		_hover_tween.tween_property(self, "position", base_position, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "scale", base_scale, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "rotation_degrees", base_rotation_degrees, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if card_shadow != null:
			_hover_tween.tween_property(card_shadow, "position", Vector2(4, 8), 0.18)
			_hover_tween.tween_property(card_shadow, "modulate:a", 0.5, 0.18)


func _update_selection_visual() -> void:
	if selection_glow == null:
		return
	if is_selected:
		selection_glow.visible = true
		if _glow_tween != null and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(selection_glow, "modulate:a", 1.0, 0.4).from(0.4).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(selection_glow, "modulate:a", 0.4, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		selection_glow.visible = false
		if _glow_tween != null and _glow_tween.is_valid():
			_glow_tween.kill()
