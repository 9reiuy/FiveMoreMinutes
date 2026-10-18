class_name TutorialGuide
extends Node2D

signal interaction_requested

@export_range(16.0, 96.0, 1.0) var interaction_radius := 58.0

@onready var panic_indicator: Sprite2D = $CharacterVisual/PanicIndicator
@onready var character_visual: Node2D = $CharacterVisual

var interaction_targeted := false
var interaction_enabled := true
var expression: StringName = &"normal"


func _ready() -> void:
	add_to_group(&"tutorial_interaction_targets")
	set_expression(&"normal")


func is_interaction_available(_requester: Node) -> bool:
	return visible and interaction_enabled


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		set_interaction_targeted(false)


func set_interaction_targeted(targeted: bool) -> void:
	if interaction_targeted == targeted:
		return
	interaction_targeted = targeted
	var reference: Variant = get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if bridge != null and bridge.has_method("set_target_highlight"):
		bridge.call("set_target_highlight", targeted)


func get_interaction_prompt_state() -> Dictionary:
	if not interaction_targeted or not visible or not interaction_enabled:
		return {}
	return {
		"text": "E 交谈",
		"position": global_position,
	}


func request_interaction(_requester: Node) -> void:
	if is_interaction_available(_requester):
		interaction_requested.emit()


func set_expression(next_expression: StringName) -> void:
	expression = next_expression
	var panicked := expression == &"fear" or expression == &"panic"
	if panic_indicator != null:
		panic_indicator.visible = panicked
	if character_visual != null:
		character_visual.modulate = Color(1.0, 0.82, 0.88, 1.0) if panicked else Color.WHITE
