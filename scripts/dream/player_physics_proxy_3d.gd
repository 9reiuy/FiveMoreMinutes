extends AnimatableBody3D
class_name PlayerPhysicsProxy3D

## Presentation/interaction proxy only. The formal actor remains the existing
## CharacterBody2D. This body mirrors ground X/Z and only forwards an explicit
## door-push intent (for example an Employee crossing a planned doorway). A
## normal Player walk must never turn into a door-opening force.

@export var source_path: NodePath = NodePath("../GameplayCanvas/GameplayWorld/DreamPlayer")
@export var world_scale: float = 32.0
@export var proxy_height: float = 0.5
@export var door_group: StringName = &"physical_door_3d"
@export var push_doors: bool = true

var source_actor: Node2D
var push_cooldown_left := 0.0
var _cached_parent_3d: Node3D
var _door_cache: Array = []
var _door_cache_msec: int = 0
const DOOR_CACHE_TTL_MSEC: int = 500


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 0
	collision_mask = 0
	source_actor = get_node_or_null(source_path) as Node2D


func _physics_process(delta: float) -> void:
	push_cooldown_left = maxf(0.0, push_cooldown_left - delta)
	if not is_instance_valid(source_actor):
		source_actor = get_node_or_null(source_path) as Node2D
	if source_actor == null:
		return
	if bool(source_actor.get("dead")):
		set_physics_process(false)
		return
	if _cached_parent_3d == null or not is_instance_valid(_cached_parent_3d):
		_cached_parent_3d = get_parent_node_3d()
	var parent_3d := _cached_parent_3d
	if parent_3d == null:
		return
	var ground_position := _ground_anchor_position()
	var inv_scale := 1.0 / maxf(world_scale, 0.01)
	var target_position := parent_3d.to_global(Vector3(
		ground_position.x * inv_scale,
		proxy_height,
		ground_position.y * inv_scale
	))
	var motion := target_position - global_position
	if motion.length_squared() > 0.00000001:
		global_position = target_position
	if push_doors and push_cooldown_left <= 0.0 and _has_explicit_door_push_intent():
		if motion.length_squared() < 0.0000001:
			var actor_velocity_variant: Variant = source_actor.get("velocity")
			var actor_velocity := Vector2.ZERO if actor_velocity_variant == null else Vector2(actor_velocity_variant)
			motion = parent_3d.global_basis * Vector3(actor_velocity.x, 0.0, actor_velocity.y) / maxf(world_scale, 0.01) * delta
		if motion.length_squared() < 0.0000001:
			var destination: Variant = source_actor.get("route_transit_point")
			if destination is Vector2:
				var intended := Vector2(destination) - ground_position
				motion = parent_3d.global_basis * Vector3(intended.x, 0, intended.y)
		if motion.length_squared() < 0.0000001:
			return
		var now_msec := Time.get_ticks_msec()
		if now_msec - _door_cache_msec >= DOOR_CACHE_TTL_MSEC or _door_cache.is_empty():
			_door_cache = get_tree().get_nodes_in_group(door_group)
			_door_cache_msec = now_msec
		var world := get_tree().get_first_node_in_group(&"dream_world")
		var push_force := 260.0
		if world != null and world.get("door_push_force") != null:
			push_force = float(world.get("door_push_force"))
		for door in _door_cache:
			if is_instance_valid(door) and door.has_method("request_proxy_impact"):
				if door.call("request_proxy_impact", target_position, motion, delta, push_force):
					# One deliberate push, not an impact on every contact frame.
					push_cooldown_left = 0.45
					break


func _has_explicit_door_push_intent() -> bool:
	if source_actor == null:
		return false
	if source_actor.has_method("is_door_push_intent_active"):
		return bool(source_actor.call("is_door_push_intent_active"))
	var intent_variant: Variant = source_actor.get("door_push_intent")
	return intent_variant != null and bool(intent_variant)


func _ground_anchor_position() -> Vector2:
	if source_actor == null:
		return Vector2.ZERO
	return source_actor.global_position
