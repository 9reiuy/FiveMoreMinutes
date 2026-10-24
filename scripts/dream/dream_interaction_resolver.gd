class_name DreamInteractionResolver
extends Node

## Shared nearest-target selector for the formal Dream E interaction.
## The owning world remains responsible for the action itself (swap, collect,
## dialogue, and so on); this component owns only candidate eligibility,
## distance priority, and the single highlighted target.

var actor: Node2D
var candidate_groups: Array[StringName] = []
var current_target: Node2D
var _group_cache_frame: int = -1
var _group_cache: Dictionary = {}  # StringName -> Array
var _seen_ids: Dictionary = {}


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
	_seen_ids.clear()
	var frame := Engine.get_process_frames()
	if frame - _group_cache_frame > 1 or _group_cache.is_empty():
		_group_cache_frame = frame
		_group_cache.clear()
		for group_name in candidate_groups:
			_group_cache[group_name] = get_tree().get_nodes_in_group(group_name)
	for group_name in candidate_groups:
		var members: Array = _group_cache.get(group_name, [])
		for candidate_variant in members:
			# Group snapshots can outlive a pickup, even within the same frame.
			# Validate the raw Variant BEFORE a typed cast can touch a freed object.
			if not _is_live_candidate(candidate_variant):
				continue
			var candidate := candidate_variant as Node2D
			var candidate_id := candidate.get_instance_id()
			if _seen_ids.has(candidate_id):
				continue
			_seen_ids[candidate_id] = true
			if not _is_available(candidate):
				continue
			# Eligibility callbacks belong to gameplay objects and may delete them.
			if not _is_live_candidate(candidate) or not is_instance_valid(actor):
				continue
			var radius_variant: Variant = candidate.get("interaction_radius")
			var radius := 34.0 if radius_variant == null else maxf(float(radius_variant), 0.0)
			var distance := actor.global_position.distance_squared_to(candidate.global_position)
			if distance <= radius * radius and distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
	set_target(nearest)
	return current_target


func _is_live_candidate(candidate: Variant) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate is Node2D
		and not candidate.is_queued_for_deletion()
		and candidate.is_inside_tree()
		and candidate.can_process()
		and not bool(candidate.get_meta(&"exterior_falling",false))
	)


func set_target(target: Variant) -> void:
	# The provisional nearest can also be freed by a later candidate's callback.
	var next: Node2D = target as Node2D if _is_live_candidate(target) else null
	if not is_instance_valid(current_target):
		current_target = null
	if current_target == next:
		return
	var previous: Variant = current_target
	current_target = null
	if is_instance_valid(previous) and previous.has_method("set_interaction_targeted"):
		previous.call("set_interaction_targeted", false)
	if not _is_live_candidate(next):
		return
	current_target = next
	if current_target.has_method("set_interaction_targeted"):
		current_target.call("set_interaction_targeted", true)
	if not _is_live_candidate(current_target):
		current_target = null


func clear_target() -> void:
	set_target(null)
	_group_cache.clear()
	_group_cache_frame = -1


func _is_available(candidate: Node2D) -> bool:
	if candidate is CanvasItem and not (candidate as CanvasItem).visible:
		return false
	if candidate.has_method("is_interaction_available"):
		return bool(candidate.call("is_interaction_available", actor))
	if candidate.has_method("is_available_for"):
		return bool(candidate.call("is_available_for", actor))
	return true
