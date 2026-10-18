extends Area2D
## Passive corpse contact sensor. Never a projectile/hurtbox or player blocker.
var actor: Node2D

func _ready() -> void:
	actor = get_parent() as Node2D
	collision_layer = 0
	collision_mask = 1 | 8
	monitorable = false
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0
	capsule.height = 32.0
	shape.shape = capsule
	add_child(shape)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.dead or not actor.death_landed:
		return
	rotation = actor.character_visual.rotation
	position = Vector2(0,-14).rotated(rotation)
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
