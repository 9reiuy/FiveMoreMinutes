class_name ReceptionWaitressNPC
extends Node2D
enum ConversationMode { ACTIVE, PASSIVE }
@export var conversation_mode: ConversationMode=ConversationMode.PASSIVE

## Peaceful Waitress NPC Actor standing behind the reception desk.
## Complies with AGENTS.md aesthetic and behavioral standards:
## - Authentic 32x32 character visual atlas using res://art/Dream/enemy/waitress.png
## - Nearest pixel filtering on all visual canvas items
## - Subtle idle breathing motion via sine wave (sin(time * 3.0) * 0.5px)
## - Multi-frame blinking timer (open -> blink -> closed -> open)
## - Forward-facing South orientation towards approaching player
## - Full interaction integration for DreamInteractionResolver & dialogue systems
## - Non-aggressive, stationary, does not attack.

signal interaction_requested

const WAITRESS_ATLAS: Texture2D = preload("res://art/Dream/enemy/waitress.png")
const SHADOW_TEXTURE: Texture2D = preload("res://art/Dream/shadow.png")

const HEAD_OPEN_REGION: Rect2 = Rect2(32, 0, 28, 32)
const HEAD_BLINK_REGION: Rect2 = Rect2(32, 32, 28, 32)
const HEAD_CLOSED_REGION: Rect2 = Rect2(32, 64, 28, 32)
const BODY_REGION: Rect2 = Rect2(64, 0, 32, 32)
const LEFT_FOOT_REGION: Rect2 = Rect2(108, 12, 4, 9)
const RIGHT_FOOT_REGION: Rect2 = Rect2(113, 12, 4, 9)
const LEFT_HAND_REGION: Rect2 = Rect2(134, 15, 5, 4)
const RIGHT_HAND_REGION: Rect2 = Rect2(149, 15, 5, 4)

@export var interaction_enabled: bool = true
@export_range(16.0, 128.0, 1.0) var interaction_radius: float = 105.0

var character_visual: Node2D
var body_pivot: Node2D
var head: Sprite2D
var body: Sprite2D
var left_foot: Sprite2D
var right_foot: Sprite2D
var left_hand: Sprite2D
var right_hand: Sprite2D
var shadow: Sprite2D

var head_base_pos: Vector2 = Vector2(-16, -20)
var body_base_pos: Vector2 = Vector2(-16, -8)
var body_pivot_base_pos: Vector2 = Vector2(0, -16)

var head_frame_open: AtlasTexture
var head_frame_blink: AtlasTexture
var head_frame_closed: AtlasTexture

# Blinking state
var blink_timer: float = 0.0
var next_blink_interval: float = 3.5
var blink_phase: int = 0 # 0: open, 1: half-blink, 2: closed
var blink_phase_left: float = 0.0

# Breathing timer
var breath_time: float = 0.0

var interaction_targeted: bool = false


func _init() -> void:
	name = "ReceptionWaitressNPC"
	_setup_groups()
	_build_visuals()
	_reset_blink_delay()


func _ready() -> void:
	_setup_groups()
	_build_visuals()
	_reset_blink_delay()


func _setup_groups() -> void:
	if not is_in_group(&"reception_interaction_targets"):
		add_to_group(&"reception_interaction_targets")
	if not is_in_group(&"tutorial_interaction_targets"):
		add_to_group(&"tutorial_interaction_targets")
	if not is_in_group(&"reception_npc"):
		add_to_group(&"reception_npc")


func _build_visuals() -> void:
	if character_visual != null and is_instance_valid(character_visual):
		return

	# Ground contact shadow (compatible with ActorDepthBridge3D and 2D renderer)
	shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = SHADOW_TEXTURE
	shadow.modulate = Color(0, 0, 0, 0.42)
	shadow.z_index = -4
	shadow.position = Vector2(0, 3)
	shadow.scale = Vector2(0.42, 0.18)
	add_child(shadow)

	# CharacterVisual root
	character_visual = Node2D.new()
	character_visual.name = "CharacterVisual"
	character_visual.position = Vector2(0, -18.25)
	add_child(character_visual)

	# Feet (Nearest pixel filter)
	left_foot = Sprite2D.new()
	left_foot.name = "LeftFoot"
	left_foot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left_foot.position = Vector2(-5, -9)
	left_foot.texture = _make_atlas(LEFT_FOOT_REGION)
	left_foot.centered = false
	character_visual.add_child(left_foot)

	right_foot = Sprite2D.new()
	right_foot.name = "RightFoot"
	right_foot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right_foot.position = Vector2(0, -9)
	right_foot.texture = _make_atlas(RIGHT_FOOT_REGION)
	right_foot.centered = false
	character_visual.add_child(right_foot)

	# BodyPivot for torso, head, and hands
	body_pivot = Node2D.new()
	body_pivot.name = "BodyPivot"
	body_pivot.position = body_pivot_base_pos
	character_visual.add_child(body_pivot)

	# Head frames
	head_frame_open = _make_atlas(HEAD_OPEN_REGION)
	head_frame_blink = _make_atlas(HEAD_BLINK_REGION)
	head_frame_closed = _make_atlas(HEAD_CLOSED_REGION)

	head = Sprite2D.new()
	head.name = "Head"
	head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.position = head_base_pos
	head.texture = head_frame_open
	head.centered = false
	body_pivot.add_child(head)

	# Body / Torso
	body = Sprite2D.new()
	body.name = "Body"
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.position = body_base_pos
	body.texture = _make_atlas(BODY_REGION)
	body.centered = false
	body_pivot.add_child(body)

	# Hands
	left_hand = Sprite2D.new()
	left_hand.name = "LeftHand"
	left_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left_hand.position = Vector2(-11, 8)
	left_hand.texture = _make_atlas(LEFT_HAND_REGION)
	left_hand.centered = false
	body_pivot.add_child(left_hand)

	right_hand = Sprite2D.new()
	right_hand.name = "RightHand"
	right_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right_hand.position = Vector2(4, 8)
	right_hand.texture = _make_atlas(RIGHT_HAND_REGION)
	right_hand.centered = false
	body_pivot.add_child(right_hand)


func _make_atlas(region: Rect2) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = WAITRESS_ATLAS
	tex.region = region
	return tex


func _process(delta: float) -> void:
	_update_breathing(delta)
	_update_blinking(delta)


func _update_breathing(delta: float) -> void:
	breath_time += delta
	# Subtle vertical bounce on body and head: sin(time * 3.0) * 0.5px
	var breath_offset: float = sin(breath_time * 3.0) * 0.5
	if head != null:
		head.position.y = head_base_pos.y + breath_offset
	if body != null:
		body.position.y = body_base_pos.y + breath_offset * 0.5


func _update_blinking(delta: float) -> void:
	if head == null:
		return

	if blink_phase == 0:
		# Waiting for next blink
		blink_timer -= delta
		if blink_timer <= 0.0:
			blink_phase = 1
			blink_phase_left = 0.06
			head.texture = head_frame_blink
	elif blink_phase == 1:
		# Half-blink phase
		blink_phase_left -= delta
		if blink_phase_left <= 0.0:
			blink_phase = 2
			blink_phase_left = 0.06
			head.texture = head_frame_closed
	elif blink_phase == 2:
		# Fully closed phase
		blink_phase_left -= delta
		if blink_phase_left <= 0.0:
			blink_phase = 0
			head.texture = head_frame_open
			_reset_blink_delay()


func _reset_blink_delay() -> void:
	blink_timer = randf_range(2.5, 5.0)


# =============================================================================
# Interaction System Contract
# =============================================================================

func is_interaction_available(_requester: Node = null) -> bool:
	return visible and interaction_enabled


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		set_interaction_targeted(false)


func set_interaction_targeted(targeted: bool) -> void:
	if interaction_targeted == targeted:
		return
	interaction_targeted = targeted
	if has_meta(&"depth_visual_bridge"):
		var reference: Variant = get_meta(&"depth_visual_bridge")
		var bridge: Node = reference.get_ref() if reference is WeakRef else null
		if bridge != null and bridge.has_method("set_target_highlight"):
			bridge.call("set_target_highlight", targeted)


func get_interaction_prompt_state() -> Dictionary:
	if not interaction_targeted or not is_interaction_available():
		return {}
	return {
		"text": "[E] 交谈",
		"position": global_position,
	}


func request_interaction(requester: Node = null) -> void:
	if is_interaction_available(requester):
		interaction_requested.emit()
