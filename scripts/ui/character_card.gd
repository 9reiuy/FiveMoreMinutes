extends Control

## Replacement for the old two-column SkillsMenu.  This is deliberately a
## small, self-contained profile card: the DreamWorld owns the persistent
## dictionary and this control only edits it through one signal.
signal close_requested
signal reopen_requested
signal profile_change_requested(profile: Dictionary)

@onready var backdrop: ColorRect = $Backdrop
@onready var card_panel: Panel = $CardPanel
@onready var hp_cells: HBoxContainer = $CardPanel/HealthCells
@onready var hp_value: Label = $CardPanel/HealthValue
@onready var attack_value: Label = $CardPanel/CombatStats/AttackValue
@onready var preview_anchor: Node2D = $CardPanel/PreviewAnchor

var player: Node
var profile_state: Dictionary = {}
var config: DemoConfig
var card_tween: Tween
var closing := false
var preview: Node2D
var preview_head: Sprite2D
var preview_body_pivot: Node2D
var preview_body: Sprite2D
var preview_left_foot: Sprite2D
var preview_right_foot: Sprite2D
var preview_left_hand: Sprite2D
var preview_right_hand: Sprite2D
var preview_head_frames: Array = []
var preview_breath_time := 0.0
var preview_blink_delay := 3.5
var preview_blink_left := 0.0
var preview_blink_frame := 0

const CARD_SIZE := Vector2(560.0, 292.0)
const SEGMENT_SIZE := Vector2(14.0, 12.0)
const ACTIVE_HP_COLOR := Color("a7b05a")
const INACTIVE_COLOR := Color("403b49")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	card_panel.size = CARD_SIZE
	_build_segments(hp_cells)


func open(player_ref: Node, profile_ref: Dictionary, config_ref: DemoConfig) -> void:
	player = player_ref
	profile_state = profile_ref
	config = config_ref
	refresh_data(player, profile_state, config)
	visible = true
	closing = false
	backdrop.visible = true
	_kill_tween()
	var target: Vector2 = _target_position()
	card_panel.position = Vector2(target.x, _viewport_size().y + 18.0)
	card_tween = create_tween()
	card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	card_tween.tween_property(card_panel, "position", target, config.character_card_enter_seconds)


func close() -> void:
	if not visible:
		return
	closing = true
	_kill_tween()
	var target: Vector2 = _target_position()
	var hidden: Vector2 = Vector2(target.x, _viewport_size().y + 18.0)
	card_tween = create_tween()
	card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	card_tween.tween_property(card_panel, "position", hidden, config.character_card_exit_seconds)
	card_tween.finished.connect(_finish_close)


func is_closing() -> bool:
	return closing


func refresh_data(player_ref: Node, profile_ref: Dictionary, config_ref: DemoConfig) -> void:
	player = player_ref
	profile_state = profile_ref
	config = config_ref
	var hp: int = _hp_cells()
	var max_cells: int = config.character_card_max_stat_cells
	hp_value.text = "%d / %d HP" % [hp * int(config.character_card_hp_per_cell), max_cells * int(config.character_card_hp_per_cell)]
	attack_value.text = "%d" % roundi(_attack_value())
	_set_segments(hp_cells, hp, ACTIVE_HP_COLOR)
	if not is_instance_valid(preview):
		_refresh_preview()


func _process(delta: float) -> void:
	if not visible or closing or preview == null:
		return
	preview_breath_time += delta
	_preview_idle_motion()
	_update_preview_blink(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("skill_menu"):
		return
	if closing:
		reopen_requested.emit()
	else:
		close_requested.emit()
	get_viewport().set_input_as_handled()


func _build_segments(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	for _index in range(10):
		var segment := ColorRect.new()
		segment.custom_minimum_size = SEGMENT_SIZE
		segment.size = SEGMENT_SIZE
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(segment)


func _set_segments(container: HBoxContainer, lit_count: int, active_color: Color) -> void:
	var index := 0
	for child in container.get_children():
		var segment := child as ColorRect
		if segment != null:
			segment.color = active_color if index < lit_count else INACTIVE_COLOR
		index += 1


func _refresh_preview() -> void:
	if not is_instance_valid(player):
		return
	var source: Node2D = player.get_node_or_null("CharacterVisual") as Node2D
	if source == null:
		return
	if is_instance_valid(preview):
		preview.queue_free()
	preview = source.duplicate() as Node2D
	preview_anchor.add_child(preview)
	preview.position = Vector2.ZERO
	preview.rotation = 0.0
	var scale_value: float = float(player.get("character_visual_scale"))
	preview.scale = Vector2.ONE * maxf(scale_value, 0.1)
	preview.modulate = Color.WHITE
	preview_head = preview.get_node_or_null("BodyPivot/Head") as Sprite2D
	preview_body_pivot = preview.get_node_or_null("BodyPivot") as Node2D
	preview_body = preview.get_node_or_null("BodyPivot/Body") as Sprite2D
	preview_left_foot = preview.get_node_or_null("LeftFoot") as Sprite2D
	preview_right_foot = preview.get_node_or_null("RightFoot") as Sprite2D
	preview_left_hand = preview.get_node_or_null("BodyPivot/LeftHand") as Sprite2D
	preview_right_hand = preview.get_node_or_null("BodyPivot/RightHand") as Sprite2D
	preview_head_frames.clear()
	var frame_variant: Variant = player.get("player_head_frames")
	if frame_variant is Array:
		preview_head_frames = (frame_variant as Array).duplicate()
	for part_variant in [preview_head, preview_body, preview_left_foot, preview_right_foot]:
		var part: CanvasItem = part_variant as CanvasItem
		if part != null:
			part.visible = true
	if preview_left_hand != null:
		preview_left_hand.visible = true
	if preview_right_hand != null:
		preview_right_hand.visible = true
	_preview_reset_transforms()
	preview_blink_delay = randf_range(2.0, 6.0)
	preview_blink_left = 0.0
	preview_blink_frame = 0


func _preview_reset_transforms() -> void:
	if preview == null or not is_instance_valid(player):
		return
	preview.rotation = 0.0
	# The preview is anchored by the card, not by the in-world Player offset.
	preview.position = Vector2.ZERO
	if preview_body_pivot != null:
		var pivot_position: Variant = player.get("body_base_position")
		if pivot_position is Vector2:
			preview_body_pivot.position = pivot_position
		preview_body_pivot.rotation = 0.0
	for pair in [
		[preview_head, "head_base_position"],
		[preview_left_foot, "left_leg_base_position"],
		[preview_right_foot, "right_leg_base_position"],
		[preview_left_hand, "left_hand_base_position"],
		[preview_right_hand, "right_hand_base_position"],
	]:
		var node := pair[0] as Node2D
		if node == null:
			continue
		var base: Variant = player.get(pair[1])
		if base is Vector2:
			node.position = base
		node.rotation = 0.0
	if preview_head != null and not preview_head_frames.is_empty():
		preview_head.texture = preview_head_frames[0] as Texture2D


func _preview_idle_motion() -> void:
	if preview_body_pivot == null:
		return
	var period: float = config.player_idle_breath_period if config != null else 1.8
	var amplitude: float = config.player_idle_body_breath_pixels if config != null else 1.0
	var lift: float = roundf(sin(preview_breath_time * TAU / maxf(period, 0.1)) * amplitude)
	var base_pivot: Variant = player.get("body_base_position")
	if base_pivot is Vector2:
		preview_body_pivot.position = (base_pivot as Vector2) + Vector2(0.0, -lift)


func _update_preview_blink(delta: float) -> void:
	if preview_head == null or preview_head_frames.size() < 3:
		return
	if preview_blink_left > 0.0:
		preview_blink_left -= delta
		var frame: int = 1 if preview_blink_left > 0.05 else 2
		if frame != preview_blink_frame:
			preview_blink_frame = frame
			preview_head.texture = preview_head_frames[frame] as Texture2D
		return
	preview_blink_delay -= delta
	if preview_blink_delay <= 0.0:
		preview_blink_left = 0.14
		preview_blink_frame = 1
		preview_head.texture = preview_head_frames[1] as Texture2D
		preview_blink_delay = randf_range(2.0, 6.0)


func _hp_cells() -> int:
	if is_instance_valid(player) and player.has_method("get_character_card_hp_cells"):
		return int(player.get_character_card_hp_cells())
	return int(profile_state.get("character_hp_cells", 4))


func _attack_value() -> float:
	if is_instance_valid(player) and player.has_method("get_character_card_attack_value"):
		return float(player.get_character_card_attack_value())
	return 2.0


func _target_position() -> Vector2:
	var viewport: Vector2 = _viewport_size()
	return Vector2(roundf((viewport.x - CARD_SIZE.x) * 0.5), roundf((viewport.y - CARD_SIZE.y) * 0.5))


func _viewport_size() -> Vector2:
	return get_viewport_rect().size


func _kill_tween() -> void:
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()
	card_tween = null


func _finish_close() -> void:
	if not closing:
		return
	closing = false
	visible = false
	backdrop.visible = false
