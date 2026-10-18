extends Area2D
class_name BossKeyPickup

signal collected

## Employee Badge is a formal world pickup: it never auto-collects on touch.  The
## shared E resolver (dream_3d_random_dungeon._update_world_weapon_interaction)
## marks the nearest candidate targeted; pressing E calls collect().  Proximity
## drives the unified white outline through the same depth-bridge highlight the
## enemies use, and the interaction prompt stays on the layer-20 HUD.

@export_range(16.0, 64.0, 1.0) var interaction_radius := 34.0

var is_collected := false
var interaction_targeted := false
var owner_world: Node
var room_id := -1


func _ready() -> void:
	# Keep the legacy scene/script path for UID compatibility, but expose only
	# the new runtime semantic to the Random3D interaction resolver.
	add_to_group(&"employee_badge_pickup")


func configure(world: Node, assigned_room_id: int) -> void:
	owner_world = world
	room_id = assigned_room_id


func is_available_for(_requester: Node) -> bool:
	return not is_collected


func set_interaction_targeted(targeted: bool) -> void:
	if interaction_targeted == targeted:
		return
	interaction_targeted = targeted
	var reference: Variant = get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if bridge != null and bridge.has_method("set_target_highlight"):
		bridge.set_target_highlight(targeted)


## Same HUD contract as WorldWeaponPickup: the world only supplies the anchor
## and text; the layer-20 CanvasLayer keeps the prompt above the 3D scene.
func get_interaction_prompt_state() -> Dictionary:
	if not interaction_targeted or is_collected or not visible:
		return {}
	return {
		"text": "E 拾取员工工牌",
		"position": global_position,
	}


func collect() -> void:
	if is_collected:
		return
	is_collected = true
	set_interaction_targeted(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	visible = false
	if owner_world != null and owner_world.has_method("collect_employee_badge"):
		owner_world.call_deferred("collect_employee_badge", self)
	collected.emit()
