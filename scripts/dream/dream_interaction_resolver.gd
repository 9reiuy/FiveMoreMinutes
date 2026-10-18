class_name DreamInteractionResolver
extends Node

## Shared nearest-target selector for the formal Dream E interaction.
## The owning world remains responsible for the action itself (swap, collect,
## dialogue, and so on); this component owns only candidate eligibility,
## distance priority, and the single highlighted target.

var actor: Node2D
var candidate_groups: Array[StringName] = []
var current_target: Node2D


func configure(source_actor: Node2D, groups: Array) -> void:
	clear_target()
	actor = source_actor
	candidate_groups.clear()
	for group_variant in groups:
		candidate_groups.append(StringName(str(group_variant)))


func update_target() -> Node2D:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		clear_target()
		return null
	var nearest: Node2D
	var nearest_distance := INF
	var seen: Dictionary = {}
	for group_name in candidate_groups:
		for candidate_variant in get_tree().get_nodes_in_group(group_name):
			var candidate := candidate_variant as Node2D
			if candidate == null or not is_instance_valid(candidate):
				continue
			var candidate_id := candidate.get_instance_id()
			if seen.has(candidate_id):
				continue
			seen[candidate_id] = true
			if not _is_available(candidate):
				continue
			var radius_variant: Variant = candidate.get("interaction_radius")
			var radius := 34.0 if radius_variant == null else maxf(float(radius_variant), 0.0)
			var distance := actor.global_position.distance_squared_to(candidate.global_position)
			if distance <= radius * radius and distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
	set_target(nearest)
	return current_target


func set_target(target: Node2D) -> void:
	if current_target == target:
		return
	if current_target != null and is_instance_valid(current_target) and current_target.has_method("set_interaction_targeted"):
		current_target.call("set_interaction_targeted", false)
	current_target = target
	if current_target != null and is_instance_valid(current_target) and current_target.has_method("set_interaction_targeted"):
		current_target.call("set_interaction_targeted", true)


func clear_target() -> void:
	set_target(null)


func _is_available(candidate: Node2D) -> bool:
	if candidate is CanvasItem and not (candidate as CanvasItem).visible:
		return false
	if candidate.has_method("is_interaction_available"):
		return bool(candidate.call("is_interaction_available", actor))
	if candidate.has_method("is_available_for"):
		return bool(candidate.call("is_available_for", actor))
	return true
