extends RefCounted
## One grounded death pose, driven by the same damped joints as enemy corpses.

const JOINT := preload("res://scripts/entities/corpse_ragdoll_joint.gd")
const PIXELS_PER_CELL := 32.0
const DROP_REST_HEIGHT := 0.14
const SOLID_MASK := 4 | 8

class Limb:
	var part: Node2D
	var rest: Transform2D
	var was_visible: bool
	var offset := Vector2.ZERO
	var velocity := Vector2.ZERO
	var angle := 0.0
	var spin := 0.0

	func _init(node: Node2D, kick: Vector2, angular_kick: float) -> void:
		part = node
		rest = node.transform
		was_visible = node.visible
		velocity = kick
		spin = angular_kick

	func step(dt: float, landed: bool) -> void:
		var result := JOINT.step(offset, velocity, angle, spin, dt, 1.8, 205.0, 14.0, 185.0, 14.0, landed)
		offset = result[0]
		velocity = result[1]
		angle = clampf(result[2], -0.58, 0.58)
		spin = result[3]
		part.position = rest.origin + offset
		part.rotation = rest.get_rotation() + angle


class DroppedWeapon extends Node2D:
	var fake_height := 0.0


var weapon: DroppedWeapon
var height := 0.0
var landed := false
var _actor: CharacterBody2D
var _world: Node
var _visual: Node2D
var _rest_visual: Transform2D
var _visual_home: Vector2
var _landing_angle := 0.0
var _elapsed := 0.0
var _ground_velocity := Vector2.ZERO
var _vertical_velocity := 0.0
var _bounced := false
var _limbs: Array[Limb] = []
var _drop_velocity := Vector2.ZERO
var _drop_vertical := 0.0
var _drop_spin := 0.0
var _drop_bounced := false
var _drop_ray: PhysicsRayQueryParameters2D


func begin(
	actor: CharacterBody2D, world: Node, visual: Node2D, home: Vector2,
	parts: Array[Node2D], direction: Vector2, incoming_velocity: Vector2, initial_height: float
) -> void:
	_actor = actor
	_world = world
	_visual = visual
	_rest_visual = visual.transform
	_visual_home = home
	height = maxf(initial_height, 0.0)
	_vertical_velocity = 53.0
	_ground_velocity = (direction * 83.0 + incoming_velocity * 0.20).limit_length(118.0)
	var screen_kick := direction
	if world is Node3D and world.has_method("get_gameplay_world_position"):
		var camera := world.get("camera_3d") as Camera3D
		if camera != null:
			var origin: Vector3 = world.get_gameplay_world_position(actor.global_position, 0.0)
			var end: Vector3 = world.get_gameplay_world_position(actor.global_position + direction * 32.0, 0.0)
			screen_kick = (camera.unproject_position(end) - camera.unproject_position(origin)).normalized()
	var side := signf(screen_kick.x if absf(screen_kick.x) > 0.12 else screen_kick.y)
	_landing_angle = (1.47 if side >= 0.0 else -1.47)
	# BodyPivot carries the combined head and torso. Feet and hands swing
	# independently around their authored positions with a small joint radius.
	_limbs.append(Limb.new(parts[0], -screen_kick * 13.0, -side * 2.7))
	_limbs.append(Limb.new(parts[1], -screen_kick * 26.0 + Vector2.UP * 8.0, side * 7.0))
	_limbs.append(Limb.new(parts[2], -screen_kick * 19.0 + Vector2.DOWN * 5.0, -side * 5.5))
	_limbs.append(Limb.new(parts[3], -screen_kick * 16.0, side * 5.0))
	_limbs.append(Limb.new(parts[4], -screen_kick * 21.0, -side * 6.0))
	parts[1].show()
	parts[2].show()
	_visual.show()
	_visual.modulate = Color.WHITE
	_visual.position = _visual_home + Vector2.UP * height


func detach_weapon(actor: CharacterBody2D, world: Node, held: Sprite2D, direction: Vector2) -> void:
	if held == null or not held.visible or held.texture == null:
		return
	var point := held.global_position
	var angle := held.global_rotation
	var start_height := 19.0
	_drop_velocity = direction.orthogonal() * 136.0 - direction * 27.0
	var reference: Variant = actor.get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if is_instance_valid(bridge) and world is Node3D and world.has_method("get_gameplay_world_position"):
		var camera := world.get("camera_3d") as Camera3D
		if camera != null:
			var grip: Dictionary = bridge.get_weapon_visual_snapshot(point)
			if not grip.is_empty():
				var axis: Dictionary = bridge.get_weapon_visual_snapshot(point + held.global_transform.x.normalized() * 8.0)
				var origin: Vector3 = grip.world_origin
				var along: Vector3 = axis.get("world_origin", origin)
				var screen_axis := camera.unproject_position(along) - camera.unproject_position(origin)
				var local: Vector3 = world.to_local(origin)
				point = Vector2(local.x, local.z) * PIXELS_PER_CELL
				start_height = maxf((local.y - DROP_REST_HEIGHT) * PIXELS_PER_CELL, 0.0)
				_drop_velocity = _foreground_release(actor, world, camera, origin, direction)
				if screen_axis.length_squared() > 0.01:
					angle = screen_axis.angle()
	weapon = DroppedWeapon.new()
	weapon.name = "PlayerDeathWeapon"
	weapon.top_level = true
	weapon.fake_height = start_height
	var pixels := held.duplicate(0) as Sprite2D
	pixels.name = "WeaponSprite"
	pixels.transform = Transform2D(0.0, held.global_scale.abs(), 0.0, Vector2.ZERO)
	pixels.position.y = -start_height if not is_instance_valid(bridge) else 0.0
	weapon.add_child(pixels)
	actor.add_child(weapon)
	weapon.global_position = point
	weapon.rotation = angle
	_drop_vertical = 48.0
	_drop_spin = 10.0 if direction.x >= 0.0 else -10.0
	_drop_ray = PhysicsRayQueryParameters2D.new()
	_drop_ray.collision_mask = SOLID_MASK
	if is_instance_valid(world) and world.has_method("project_player_death_weapon"):
		world.call_deferred("project_player_death_weapon", weapon, DROP_REST_HEIGHT)


func _foreground_release(actor: Node2D, world: Node3D, camera: Camera3D, grip: Vector3, impact: Vector2) -> Vector2:
	var inverse := world.global_basis.inverse()
	var camera_right := inverse * camera.global_basis.x
	var camera_near := inverse * camera.global_basis.z
	var right := Vector2(camera_right.x, camera_right.z).normalized()
	var near := Vector2(camera_near.x, camera_near.z).normalized()
	var torso: Vector3 = world.get_gameplay_world_position(actor.global_position, 0.65)
	var screen_offset := camera.unproject_position(grip).x - camera.unproject_position(torso).x
	# Keep a clearly offset grip on its own side. A centered grip falls on
	# the side away from the body roll, with foreground space for both silhouettes.
	var side := signf(screen_offset) if absf(screen_offset) > 6.0 else -signf(impact.dot(right))
	return (right * side * 135.0 + near * 123.0).limit_length(175.0)


func step(delta: float) -> void:
	if _elapsed >= 0.85:
		return
	var remaining := minf(delta, 0.067)
	while remaining > 0.0001:
		var dt := minf(remaining, 0.016)
		remaining -= dt
		_elapsed += dt
		_step_body(dt)
		_step_weapon(dt)


func _step_body(dt: float) -> void:
	var from := _actor.global_position
	var motion := _ground_velocity * dt
	if _crosses_exterior(from, from + motion):
		_ground_velocity = Vector2.ZERO
	elif motion.length_squared() > 0.0001:
		var contact := _actor.move_and_collide(motion, false, 0.02)
		if contact != null:
			_ground_velocity = _ground_velocity.slide(contact.get_normal()) * 0.46
	_ground_velocity *= exp(-(11.0 if landed else 4.0) * dt)

	if not landed:
		_vertical_velocity -= 440.0 * dt
		height += _vertical_velocity * dt
		if height <= 0.0 and _vertical_velocity < 0.0:
			height = 0.0
			if not _bounced:
				_bounced = true
				_vertical_velocity = 15.0
				for limb in _limbs:
					limb.velocity.y -= 17.0
					limb.spin *= -0.65
			else:
				landed = true

	var hip := Vector2(0.0, -7.0)
	_visual.rotation = lerp_angle(_visual.rotation, _landing_angle, 1.0 - exp(-12.5 * dt))
	_visual.position = _visual_home + hip - hip.rotated(_visual.rotation) + Vector2.UP * height
	for limb in _limbs:
		limb.step(dt, landed)


func _step_weapon(dt: float) -> void:
	if not is_instance_valid(weapon):
		return
	var from := weapon.global_position
	var destination := from + _drop_velocity * dt
	if _crosses_exterior(from, destination):
		_drop_velocity *= -0.28
	elif _drop_velocity.length_squared() > 0.05:
		_drop_ray.from = from
		_drop_ray.to = destination
		var hit := _actor.get_world_2d().direct_space_state.intersect_ray(_drop_ray)
		if hit.is_empty():
			weapon.global_position = destination
		else:
			weapon.global_position = hit.position + hit.normal * 0.5
			_drop_velocity = _drop_velocity.bounce(hit.normal) * 0.38
			_drop_spin *= -0.65

	_drop_vertical -= 510.0 * dt
	var next_height := weapon.fake_height + _drop_vertical * dt
	if next_height <= 0.0:
		if not _drop_bounced:
			_drop_bounced = true
			_drop_vertical = 29.0
			_drop_velocity *= 0.58
			_drop_spin *= -0.42
		else:
			_drop_vertical = 0.0
	weapon.fake_height = maxf(next_height, 0.0)
	weapon.rotation += _drop_spin * dt
	var drag := 16.0 if weapon.fake_height <= 0.0 and _drop_vertical <= 0.0 else 3.8
	_drop_velocity *= exp(-drag * dt)
	_drop_spin *= exp(-drag * dt)
	if not is_instance_valid(_world) or not _world.has_method("project_player_death_weapon"):
		weapon.get_node(^"WeaponSprite").position.y = -weapon.fake_height


func _crosses_exterior(from: Vector2, to: Vector2) -> bool:
	return is_instance_valid(_world) and _world.has_method("can_fall_through_exterior") \
		and _world.can_fall_through_exterior(from, to)


func focus_point(ground: Vector2) -> Vector2:
	if not is_instance_valid(weapon):
		return ground
	return ground + (weapon.global_position - ground).limit_length(65.0) * 0.45


func restore() -> void:
	if is_instance_valid(weapon):
		weapon.hide()
		weapon.queue_free()
	weapon = null
	_visual.transform = _rest_visual
	_visual.position = _visual_home
	_visual.modulate = Color.WHITE
	for limb in _limbs:
		limb.part.transform = limb.rest
		limb.part.visible = limb.was_visible
