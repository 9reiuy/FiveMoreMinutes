extends Node2D
const HELMET := preload("res://scripts/entities/safety_helmet.gd")
var owner_world: Node3D
var interaction_radius := 34.0
var interaction_targeted := false
var collected := false
var room_runtime_active := true


func _ready() -> void:
	add_to_group(&"world_equipment_pickups")
	var hat := Sprite2D.new()
	hat.name = "HatSprite"
	hat.texture = HELMET.texture()
	hat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hat)


func is_available_for(requester: Node) -> bool:
	return not collected and room_runtime_active and is_instance_valid(requester) \
		and requester.has_method("equip_safety_helmet") and not bool(requester.get("dead")) \
		and not bool(requester.get("helmet_equipped"))


func set_interaction_targeted(targeted: bool) -> void:
	interaction_targeted = targeted
	var reference: Variant = get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if is_instance_valid(bridge):
		bridge.set_target_highlight(targeted)


func get_interaction_prompt_state() -> Dictionary:
	return {} # Ground equipment uses the shared white highlight without a proximity label.


func collect() -> void:
	var player: Node2D = owner_world.get("player") if is_instance_valid(owner_world) else null
	if not is_available_for(player) or global_position.distance_to(player.global_position) > interaction_radius:
		return
	if not bool(player.call("equip_safety_helmet")):
		return
	collected = true
	set_interaction_targeted(false)
	hide()
	queue_free()


func set_room_runtime_active(active: bool) -> void:
	room_runtime_active = active
	visible = active and not collected
	if not active:
		set_interaction_targeted(false)
