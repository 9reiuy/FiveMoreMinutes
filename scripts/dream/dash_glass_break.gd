extends RefCounted
## Dash contact uses the live 2D pane footprint. Glass owners retain their own
## damage, shatter visuals, collision teardown and connected topology signals.
const FLOOR_STATE := preload("res://scripts/dream/shared_wall_breach.gd")

static func query(world: Node3D, from: Vector2, to: Vector2, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	if not FLOOR_STATE.allowed(world) or not from.is_finite() or not to.is_finite(): return result
	if not is_finite(radius) or radius < 0 or from.is_equal_approx(to): return result
	var seen := {}
	# Both exterior facade panes and native continuous-glass cells use this
	# group on their real collision proxy, plus a weakref to the 3D owner.
	for node in world.get_tree().get_nodes_in_group(&"glass_windows"):
		var body := node as StaticBody2D
		var owner := _owner_for_body(world, body)
		if owner == null or seen.has(owner.get_instance_id()): continue
		for child in body.get_children():
			var shape := child as CollisionShape2D
			if shape == null or shape.disabled or not shape.shape is RectangleShape2D: continue
			if not _sweep_hits_shape(from, to, radius, shape): continue
			seen[owner.get_instance_id()] = true
			result.append(owner)
			break
	return result

static func commit(world: Node3D, targets: Array, token: int, direction: Vector2) -> int:
	if not is_instance_valid(world) or token != world.get_current_floor_token() or not FLOOR_STATE.allowed(world): return 0
	var shattered := 0
	var seen := {}
	for target in targets:
		# A connected shatter callback may change the floor. Never carry the rest
		# of this batch into a later generation, even if a caller passed old nodes.
		if token != world.get_current_floor_token() or not FLOOR_STATE.allowed(world): break
		if not is_instance_valid(target) or not target is Node3D: continue
		var owner := target as Node3D
		if seen.has(owner.get_instance_id()): continue
		seen[owner.get_instance_id()] = true
		var body := owner.get("collision_body_2d") as StaticBody2D
		if _owner_for_body(world, body) != owner: continue
		# shatter() is the existing one-shot authority. Its window_shattered signal
		# already updates exterior openings/native glass topology exactly once.
		owner.call("shatter", direction)
		shattered += 1
	return shattered

static func _owner_for_body(world: Node3D, body: StaticBody2D) -> Node3D:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.collision_layer == 0: return null
	if not body.is_in_group(&"glass_windows"): return null
	var collision_root: Node = world.get("collision_root")
	var wall_root: Node = world.get("wall_root")
	if not is_instance_valid(collision_root) or not collision_root.is_ancestor_of(body): return null
	if not is_instance_valid(wall_root): return null
	var owner := body.get("window_owner") as Node3D
	if not is_instance_valid(owner):
		var reference: Variant = body.get_meta(&"glass_window_3d", null)
		if reference is WeakRef: owner = reference.get_ref() as Node3D
	if not is_instance_valid(owner) or owner.is_queued_for_deletion(): return null
	if not wall_root.is_ancestor_of(owner) or not owner.is_in_group(&"breakable_glass_windows"): return null
	if bool(owner.get("is_shattered")) or not owner.has_method("shatter"): return null
	if owner.get("collision_body_2d") != body: return null
	var shape: CollisionShape2D = owner.get("collision_shape_2d")
	if not is_instance_valid(shape) or shape.disabled: return null
	return owner

static func _sweep_hits_shape(from: Vector2, to: Vector2, radius: float, shape: CollisionShape2D) -> bool:
	var bounds := shape.shape.get_rect()
	var corners := PackedVector2Array()
	for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		corners.append(shape.global_transform * point)
	if Geometry2D.is_point_in_polygon(from, corners) or Geometry2D.is_point_in_polygon(to, corners): return true
	for index in 4:
		var a := corners[index]
		var b := corners[(index + 1) % 4]
		if Geometry2D.segment_intersects_segment(from, to, a, b) != null: return true
		var closest := Geometry2D.get_closest_points_between_segments(from, to, a, b)
		if closest[0].distance_squared_to(closest[1]) <= radius * radius: return true
	return false
