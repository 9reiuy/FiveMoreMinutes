extends Area2D
## Passive corpse contact sensor. Never a projectile/hurtbox or player blocker.
var actor: Node2D
var contact_shape: CollisionShape2D
var pose_signature := 0
var shape_center := Vector2.ZERO
var projected_to_floor := false

func _init() -> void:
	# Configure the passive sensor before it joins an active physics space.
	# A thrown weapon can create this sensor inside body_entered.
	collision_layer = 0
	collision_mask = 1 | 8
	monitorable = false

func _ready() -> void:
	actor = get_parent() as Node2D
	_create_contact_shape.call_deferred()

func _create_contact_shape() -> void:
	if not is_inside_tree() or is_queued_for_deletion():return
	contact_shape = CollisionShape2D.new()
	contact_shape.shape = ConvexPolygonShape2D.new()
	add_child(contact_shape)
	sync_pose()

func _part_points(node: Node2D, points: PackedVector2Array, inverse_visual: Transform2D, padding: float = 2.0) -> void:
	if not node.visible: return
	if node is Sprite2D and node.texture != null:
		# Parts are already cropped atlas regions. Keep a small contact allowance
		# around head, torso, hands and feet without reading GPU images per tick.
		var rect: Rect2 = node.get_rect().grow(padding)
		var relative := inverse_visual*node.global_transform
		for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
			points.append(relative*corner)
	for child in node.get_children():
		if child is Node2D: _part_points(child,points,inverse_visual,padding)

func sync_pose() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(contact_shape): return
	var visual: Node2D = actor.character_visual
	transform = Transform2D(0.0,shape_center) if projected_to_floor else visual.transform*Transform2D(0.0,shape_center)
	var points := PackedVector2Array()
	_part_points(visual,points,visual.global_transform.affine_inverse())
	if points.size()<3:
		points = PackedVector2Array([Vector2(-18,-40),Vector2(18,-40),Vector2(18,8),Vector2(-18,8)])
	var bridge: Node
	if actor.death_landed and actor.has_meta(&"depth_visual_bridge"):
		var bridge_ref: Variant = actor.get_meta(&"depth_visual_bridge")
		bridge = bridge_ref.get_ref() if bridge_ref is WeakRef else null
	var projection_stamp: int = bridge.get_corpse_contact_projection_signature() if is_instance_valid(bridge) and bridge.has_method("get_corpse_contact_projection_signature") else 0
	var signature := hash([points,visual.transform,projection_stamp])
	if signature==pose_signature: return
	pose_signature = signature
	projected_to_floor = false
	if is_instance_valid(bridge) and bridge.has_method("project_corpse_contact_points"):
		var local_points := PackedVector2Array()
		for point in points: local_points.append(visual.transform*point)
		var projected: PackedVector2Array = bridge.project_corpse_contact_points(local_points)
		if projected.size()==points.size():
			points = projected
			projected_to_floor = true
	var hull := Geometry2D.convex_hull(points)
	if hull.size()>1 and hull[0].is_equal_approx(hull[-1]): hull.remove_at(hull.size()-1)
	var bounds := Rect2(hull[0],Vector2.ZERO)
	for point in hull: bounds = bounds.expand(point)
	shape_center = bounds.get_center()
	for i in hull.size(): hull[i] -= shape_center
	transform = Transform2D(0.0,shape_center) if projected_to_floor else visual.transform*Transform2D(0.0,shape_center)
	(contact_shape.shape as ConvexPolygonShape2D).points = hull

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.dead or not actor.death_landed:
		return
	sync_pose()
	for body in get_overlapping_bodies():
		try_push(body, delta)

func try_push(body: Node2D, delta: float) -> bool:
	if not is_instance_valid(actor) or not actor.dead or not actor.death_landed:
		return false
	if not is_instance_valid(body) or body.is_queued_for_deletion(): return false
	var contact_velocity := Vector2.ZERO
	var rotating_contact := false
	if body == actor.target and body is CharacterBody2D:
		if bool(body.get("dead")): return false
		contact_velocity = body.velocity
	elif body is RigidBody2D and body.is_in_group(&"damageable_props") and body.is_in_group(&"pushable_prop"):
		# Rotating furniture has velocity at its surface even without translation.
		var arm := global_position-body.global_position
		contact_velocity = body.linear_velocity + Vector2(-arm.y,arm.x)*body.angular_velocity
		rotating_contact = absf(body.angular_velocity) > 0.1 and body.linear_velocity.length_squared() < 16.0
	else:
		return false
	if contact_velocity.length_squared() < 16.0: return false
	var away := global_position-body.global_position
	if away.length_squared() < 0.01 or rotating_contact: away = contact_velocity
	away = away.normalized()
	var closing_speed := contact_velocity.dot(away)
	if closing_speed <= 0.0: return false
	actor.receive_corpse_contact(away*minf(closing_speed,360.0)*minf(delta*9.0,1.0))
	return true
