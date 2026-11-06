extends RefCounted
## Only the real travelled body sweep may request a physical-door destruction.
const FLOOR_STATE := preload("res://scripts/dream/shared_wall_breach.gd")
const GLASS_SWEEP := preload("res://scripts/dream/dash_glass_break.gd")

static func query(world: Node3D, from: Vector2, to: Vector2, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	if not FLOOR_STATE.allowed(world) or not from.is_finite() or not to.is_finite(): return result
	if not is_finite(radius) or radius < 0 or from.is_equal_approx(to): return result
	var seen := {}
	for node in world.get_tree().get_nodes_in_group(&"physical_doors"):
		var body := node as StaticBody2D
		var door := _owner_for_body(world, body)
		if door == null or seen.has(door.get_instance_id()): continue
		for child in body.get_children():
			var shape := child as CollisionShape2D
			if shape == null or shape.disabled or not shape.shape is RectangleShape2D: continue
			if not GLASS_SWEEP._sweep_hits_shape(from, to, radius, shape): continue
			seen[door.get_instance_id()] = true
			result.append(door)
			break
	return result

static func commit(world: Node3D, targets: Array, token: int, direction: Vector2) -> int:
	if not is_instance_valid(world) or token != world.get_current_floor_token() or not FLOOR_STATE.allowed(world): return 0
	var removed := 0
	var seen := {}
	for target in targets:
		if token != world.get_current_floor_token() or not FLOOR_STATE.allowed(world): break
		if not is_instance_valid(target) or not target is Node3D or seen.has(target.get_instance_id()): continue
		var door := target as Node3D
		seen[door.get_instance_id()] = true
		var bodies: Variant = door.get("_collision_bodies")
		if not bodies is Array: continue
		var valid := false
		for body in bodies:
			if _owner_for_body(world, body) == door: valid = true; break
		if valid and door.call("shatter_from_dash", direction): removed += 1
	return removed

static func _owner_for_body(world: Node3D, body: StaticBody2D) -> Node3D:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.collision_layer == 0 or not body.is_in_group(&"physical_doors"): return null
	var collision_root: Node = world.get("collision_root")
	var door_root: Node = world.get("door_root")
	if not is_instance_valid(collision_root) or not collision_root.is_ancestor_of(body) or not is_instance_valid(door_root): return null
	var door := body.get("door_owner") as Node3D
	if not is_instance_valid(door):
		var reference: Variant = body.get_meta(&"physical_door_node",null)
		if reference is WeakRef: door = reference.get_ref() as Node3D
	if not is_instance_valid(door) or door.is_queued_for_deletion() or not door_root.is_ancestor_of(door): return null
	if bool(door.get("is_destroyed")) or not door.has_method("shatter_from_dash"): return null
	if not door._collision_bodies.has(body): return null
	return door
