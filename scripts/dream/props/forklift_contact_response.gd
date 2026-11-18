extends RefCounted
## Arcade vehicle mass in the same relative units as the authored rigid props.
const MASS := 12.0
const ENEMY_MASS := 1.1
const PIXELS_PER_METRE := 32.0
const TANGENT_FRICTION := 0.10


static func resolve(vehicle: CharacterBody2D, incoming: Vector2) -> Dictionary:
	var motion := incoming
	var forward := vehicle.global_transform.x.normalized()
	var strongest := 0.0
	var pitch := 0.0
	var lean := 0.0
	var yaw := 0.0
	var hard_hit := false
	var handled: Dictionary = {}
	var spark: Dictionary = {}
	var spark_energy := 0.0
	for i in vehicle.get_slide_collision_count():
		var collision := vehicle.get_slide_collision(i)
		var collider := collision.get_collider()
		if not is_instance_valid(collider): continue
		var normal := collision.get_normal().normalized()
		var key := "%d:%s" % [collider.get_instance_id(), normal.snapped(Vector2.ONE * 0.02)]
		if handled.has(key): continue
		handled[key] = true
		var relative := motion - collision.get_collider_velocity()
		var closing := -relative.dot(normal)
		if closing <= 0.01: continue
		var inverse_other_mass := 0.0
		var inverse_rotation_mass := 0.0
		var response := 1.0
		var prop := collider as RigidBody2D
		var movable := is_instance_valid(prop) and not prop.freeze and prop.is_in_group(&"pushable_prop")
		if movable:
			if prop.has_method("get_combat_impulse_response"):
				response = maxf(0.0, float(prop.call("get_combat_impulse_response")))
			movable = response > 0.0
			if movable:
				inverse_other_mass = response / maxf(prop.mass, 0.01)
				var state := PhysicsServer2D.body_get_direct_state(prop.get_rid())
				if state != null:
					var arm := collision.get_position() - prop.global_position
					inverse_rotation_mass = pow(arm.cross(normal), 2.0) * state.inverse_inertia * response
		elif collider is EmployeeEnemy:
			# Existing combat owns the enemy's knockback and blood. The vehicle
			# loses only the momentum appropriate to a much lighter contact.
			inverse_other_mass = 1.0 / ENEMY_MASS
		var metres_per_second := closing / PIXELS_PER_METRE
		var restitution := lerpf(0.10, 0.20, smoothstep(2.0, 14.0, metres_per_second)) if metres_per_second > 1.1 else 0.0
		if inverse_other_mass > 0.0: restitution = 0.05
		var impulse := (1.0 + restitution) * closing / (1.0 / MASS + inverse_other_mass + inverse_rotation_mass)
		if movable:
			prop.sleeping = false
			if prop.has_method("apply_external_impulse"):
				if prop.call("apply_external_impulse", -normal, impulse, collision.get_position()) == false:
					impulse = (1.0 + restitution) * closing * MASS
			else:
				prop.apply_impulse(-normal * impulse, collision.get_position() - prop.global_position)
		var normal_change := impulse / MASS
		motion += normal * normal_change
		# Tyre/body friction consumes only a small part of the tangential
		# motion. A grazing contact must not erase the whole velocity vector.
		var tangent := relative.slide(normal)
		if not tangent.is_zero_approx():
			motion -= tangent.normalized() * minf(tangent.length(), normal_change * TANGENT_FRICTION)
		var change_mps := normal_change / PIXELS_PER_METRE
		var incidence := absf(relative.normalized().dot(normal))
		var arm := (collision.get_position() - vehicle.global_position) / PIXELS_PER_METRE
		yaw += clampf(arm.cross(normal) * change_mps * (1.0 - incidence) * 0.16, -0.6, 0.6)
		if change_mps > strongest:
			strongest = change_mps
			pitch = clampf(forward.dot(normal) * change_mps * 0.003, -0.035, 0.035)
			lean = clampf(forward.orthogonal().dot(normal) * change_mps * 0.006, -0.04, 0.04)
		hard_hit = hard_hit or (change_mps > 2.5 and incidence > 0.7)
		var energy := change_mps * metres_per_second
		if not collider is EmployeeEnemy and metres_per_second > 0.9 and change_mps > 0.25 and energy > spark_energy:
			spark_energy = energy
			spark = {"point":collision.get_position(),"normal":normal,"strength":clampf(sqrt(energy)/8.0,0.35,1.5)}
	return {"velocity":motion,"yaw":yaw,"lean":lean,"pitch":pitch,"hard_hit":hard_hit,"spark":spark}
