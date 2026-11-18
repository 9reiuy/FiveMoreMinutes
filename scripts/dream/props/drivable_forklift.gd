class_name DrivableForklift
extends CharacterBody2D
## Gameplay stays in the existing 2D world. The original forklift follows it in 3D.

const MODEL := preload("res://scripts/dream/props/mini_forklift_3d.gd")
const PLAYER := preload("res://scripts/entities/dream_player.gd")
const BURNING := preload("res://scripts/dream/burning_effects.gd")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONTACT_RESPONSE := preload("res://scripts/dream/props/forklift_contact_response.gd")
const DRIVE_AUDIO := preload("res://scripts/dream/props/forklift_drive_audio.gd")
const BOOST_WIND := preload("res://scripts/dream/props/forklift_boost_wind.gd")
const PIXELS_PER_METRE := 32.0
const VEHICLE_LAYER := 4 | (1 << 6)
const FORWARD_SPEED := 10.5
const REVERSE_SPEED := 4.8
const ACCELERATION := 8.4
const BRAKING := 19.5
const COAST_DECELERATION := 5.4
const MAX_STEERING := deg_to_rad(38.0)
const WHEELBASE := (MODEL.FRONT_AXLE.x - MODEL.REAR_AXLE.x) * MODEL.MODEL_SCALE
const HANDBRAKE_STEERING := deg_to_rad(48.0)
const HANDBRAKE_DECELERATION := 7.0
const NORMAL_YAW_RATE := 1.65
const HANDBRAKE_YAW_RATE := 3.6
const ROAD_GRIP := 18.0
const SLIDING_GRIP := 1.8
const MAX_BODY_ROLL := deg_to_rad(4.5)
const ROTATION_SWEEP_STEP := deg_to_rad(2.0)
const BOOST_SPEED := 18.0
const BOOST_DURATION := 0.75
const BOOST_COOLDOWN := 3.0
const BOARD_DISTANCE := 1.55
const MAX_HP := 300.0
const SMOKE_HEALTH := 90.0

signal health_changed(current: float, maximum: float)
signal vehicle_destroyed

var world: Node3D
var visual: MODEL
var driver: PLAYER
var floor_height := 0.0
var speed := 0.0
var steering := 0.0
var handbraking := false
var body_roll := 0.0
var _handbrake_blend := 0.0
var _travel_direction := Vector2.ZERO
var boost_left := 0.0
var boost_recharge := 0.0
var active := false
var exit_blocked := false
var floor_support: Callable
var max_hp := MAX_HP
var hp := MAX_HP
var destroyed := false
var smoking := false
var damage_effects: Node3D
var _impact_cooldowns: Dictionary[int, float] = {}
var _smoke_left := 0.0
var _transferring := false
var _driver_state := {}
var contact_response_enabled := true
var _impact_yaw_velocity := 0.0
var _impact_lean := 0.0
var _impact_pitch := 0.0
var _spark_cooldown := 0.0
var drive_audio: DRIVE_AUDIO
var boost_wind: BOOST_WIND


func configure(owner_world: Node3D, model: MODEL, height := 0.0) -> void:
	world = owner_world
	visual = model
	floor_height = height
	position = Vector2(model.position.x, model.position.z) * PIXELS_PER_METRE
	rotation = -model.rotation.y
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	max_slides = 6
	safe_margin = 0.02 * PIXELS_PER_METRE
	process_physics_priority = -50
	add_to_group(&"damageable_props")
	collision_layer = 0
	collision_mask = 1 | 2 | 4 | 8 | 32
	if world.has_method("is_vehicle_floor_supported"):
		floor_support = Callable(world, "is_vehicle_floor_supported")
	damage_effects = BURNING.install(world)
	if world.has_method("_firearm_fx"):
		world._firearm_fx().prewarm(world.get("camera_3d") as Camera3D)
	# Separate low forks from the chassis so the open space between the tines stays open.
	_add_box(Rect2(MODEL.CHASSIS_MIN_X, -MODEL.OUTER_WIDTH * 0.5,
		MODEL.CHASSIS_MAX_X - MODEL.CHASSIS_MIN_X, MODEL.OUTER_WIDTH))
	for side in [-1, 1]:
		_add_box(Rect2(MODEL.CHASSIS_MAX_X, side * 0.30 * MODEL.MODEL_SCALE - 0.07,
			MODEL.FORK_TIP_X - MODEL.CHASSIS_MAX_X, 0.14))
	drive_audio = DRIVE_AUDIO.new()
	drive_audio.name = "DriveAudio"
	drive_audio.position = Vector3(-0.3, 0.6, 0.0)
	visual.add_child(drive_audio)
	boost_wind = BOOST_WIND.new()
	visual.add_child(boost_wind)


func _add_box(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D" if get_child_count() == 0 else "ForkCollision"
	var box := RectangleShape2D.new()
	box.size = rect.size * PIXELS_PER_METRE
	shape.shape = box
	shape.position = rect.get_center() * PIXELS_PER_METRE
	add_child(shape)


func set_active(enabled: bool) -> void:
	if not enabled:
		_release_driver()
	active = enabled
	collision_layer = VEHICLE_LAYER if enabled and not destroyed else 0
	set_physics_process(enabled)
	set_process_unhandled_key_input(enabled)


func get_forward_direction() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)


func transfer_to(physics_parent: Node2D, visual_parent: Node3D) -> void:
	# Reparenting emits tree-exit too. Preserve the mounted driver during a live region transfer.
	_transferring = true
	reparent(physics_parent, true)
	_transferring = false
	visual.reparent(visual_parent, true)
	if is_instance_valid(driver):
		add_collision_exception_with(driver)


func is_combat_target_for(attacker: Node2D) -> bool:
	return is_damage_runtime_active() and is_instance_valid(driver) \
		and is_instance_valid(attacker) and attacker.get("target") == driver


func get_combat_target_position(from: Vector2) -> Vector2:
	# Melee must reach the occupied vehicle's real perimeter, rather than its inaccessible seat.
	var closest := global_position
	var distance := INF
	for child in get_children():
		var shape := child as CollisionShape2D
		if shape == null or shape.disabled:
			continue
		var bounds := shape.shape.get_rect()
		var contact := shape.to_global(shape.to_local(from).clamp(bounds.position, bounds.end))
		if from.distance_squared_to(contact) < distance:
			closest = contact
			distance = from.distance_squared_to(contact)
	return closest


func get_obstacle_rect() -> Rect2:
	return Transform2D(global_rotation, global_position / PIXELS_PER_METRE) * MODEL.get_footprint_rect()


func get_projectile_blocking_height() -> float:
	return floor_height + MODEL.MAST_TOP_Y


func get_projectile_blocking_rect(_height: float) -> Rect2:
	var shape := get_node("CollisionShape2D") as CollisionShape2D
	return shape.shape.get_rect()


func is_damage_runtime_active() -> bool:
	return active and not destroyed


func take_damage(amount: float, _direction := Vector2.ZERO, _force_multiplier := 1.0) -> void:
	if not is_damage_runtime_active() or not is_finite(amount) or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	smoking = hp > 0.0 and hp <= SMOKE_HEALTH
	health_changed.emit(hp, max_hp)
	if hp == 0.0:
		destroyed = true
		if is_instance_valid(boost_wind): boost_wind.clear()
		call_deferred("_explode")


func _explode() -> void:
	var at := visual.to_global(Vector3(0.0, 0.65, 0.0))
	collision_layer = 0
	if is_instance_valid(driver):
		# If both doors are obstructed, the destroyed body itself becomes the clear exit.
		if not try_exit():
			_release_driver()
	visual.hide()
	if is_instance_valid(damage_effects):
		damage_effects.explosion(at)
	vehicle_destroyed.emit()


func save_state() -> Dictionary:
	return {"position": global_position / PIXELS_PER_METRE, "heading": global_rotation,
		"height": floor_height, "hp": hp, "destroyed": destroyed}


func restore_state(state: Dictionary) -> void:
	reset_motion()
	hp = clampf(float(state.get("hp", MAX_HP)), 0.0, MAX_HP)
	destroyed = hp <= 0.0 or bool(state.get("destroyed", false))
	smoking = not destroyed and hp <= SMOKE_HEALTH
	visual.visible = not destroyed
	if destroyed:
		collision_layer = 0


func _seat_position() -> Vector2:
	var seat := MODEL.SEAT_ANCHOR_LOCAL
	return global_transform * (Vector2(seat.x, seat.z) * PIXELS_PER_METRE)


func can_board(candidate: PLAYER) -> bool:
	if not active or destroyed or is_instance_valid(driver) or not is_instance_valid(candidate):
		return false
	if candidate.dead or not candidate.movement_enabled or candidate.dashing \
		or candidate.vault_active or candidate.airborne_knockback or candidate.kick_active \
		or candidate.knockback_recovery_left > 0.0 or candidate.external_knockback_left > 0.0 \
		or is_instance_valid(candidate.mounted_vehicle):
		return false
	var feet := candidate.body_collision.global_position
	if feet.distance_to(_seat_position()) > BOARD_DISTANCE * PIXELS_PER_METRE:
		return false
	var ray := PhysicsRayQueryParameters2D.create(feet, _seat_position(), candidate.collision_mask,
		[get_rid(), candidate.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func board(candidate: PLAYER) -> bool:
	if not can_board(candidate):
		return false
	# The display can reparent the world into its real 3D viewport after build.
	# Prime that final pipeline once rather than at the first solid collision.
	if world.has_method("_firearm_fx"):
		world._firearm_fx().prewarm(world.get("camera_3d") as Camera3D)
	driver = candidate
	_driver_state = {
		"movement": driver.movement_enabled, "attack": driver.attacking_enabled,
		"keep_pose": driver._keep_weapon_pose, "mask": driver.collision_mask,
		"weapon_visible": driver.weapon_root.visible, "shadow_visible": driver.get_node("Shadow").visible,
	}
	var bridge: Node3D = world.get("player_depth_bridge")
	if is_instance_valid(bridge):
		_driver_state["ground_height"] = bridge.get("ground_surface_height")
		_driver_state["bridge_visible"] = bridge.visible
		bridge.show()
	driver.clear_scripted_locomotion()
	driver._cancel_punch()
	driver.set_attacking_enabled(false)
	driver.movement_enabled = false
	driver.collision_mask = 0
	driver.mounted_vehicle = self
	driver.weapon_root.hide()
	driver.get_node("Shadow").hide()
	visual.set_driver_onboard(true)
	add_collision_exception_with(driver)
	exit_blocked = false
	_sync_driver()
	return true


func try_exit() -> bool:
	if not is_instance_valid(driver):
		return false
	var exit := _find_exit()
	if not exit.is_finite():
		exit_blocked = true
		return false
	var passenger := driver
	_release_driver()
	passenger.global_position += exit - passenger.body_collision.global_position
	return true


func _find_exit() -> Vector2:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = driver.body_collision.shape
	query.collision_mask = int(_driver_state.mask)
	query.exclude = [driver.get_rid()]
	var side_distance := MODEL.OUTER_WIDTH * 0.5 + 0.48
	for offset: Vector2 in [Vector2(-0.13, side_distance), Vector2(-0.13, -side_distance),
		Vector2(-0.55, side_distance + 0.30), Vector2(-0.55, -side_distance - 0.30),
		Vector2(MODEL.CHASSIS_MIN_X - 0.50, 0.0)]:
		var at := global_transform * (offset * PIXELS_PER_METRE)
		if floor_support.is_valid() and not bool(floor_support.call(at / PIXELS_PER_METRE)):
			continue
		query.transform = Transform2D(driver.body_collision.global_rotation, at)
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		var ray := PhysicsRayQueryParameters2D.create(_seat_position(), at, query.collision_mask,
			[get_rid(), driver.get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return at
	return Vector2.INF


func _release_driver() -> void:
	reset_motion()
	if is_instance_valid(visual):
		visual.set_driver_onboard(false)
	if not is_instance_valid(driver):
		driver = null
		_driver_state.clear()
		return
	var passenger := driver
	driver = null
	remove_collision_exception_with(passenger)
	passenger.mounted_vehicle = null
	passenger.collision_mask = int(_driver_state.mask)
	passenger.movement_enabled = bool(_driver_state.movement) and not passenger.dead
	passenger.set_attacking_enabled(bool(_driver_state.attack) and not passenger.dead,
		bool(_driver_state.keep_pose))
	passenger.weapon_root.visible = bool(_driver_state.weapon_visible)
	passenger.get_node("Shadow").visible = bool(_driver_state.shadow_visible)
	passenger.velocity = Vector2.ZERO
	var bridge: Node3D = world.get("player_depth_bridge")
	if is_instance_valid(bridge) and _driver_state.has("ground_height"):
		bridge.set("ground_surface_height", floor_height)
		bridge.visible = bool(_driver_state.bridge_visible)
	if not passenger.dead:
		passenger._update_direction_animation(Vector2.ZERO, 0.0)
	_driver_state.clear()


func reset_motion() -> void:
	if is_instance_valid(drive_audio):
		drive_audio.stop_all()
	if is_instance_valid(boost_wind):
		boost_wind.clear()
	speed = 0.0
	velocity = Vector2.ZERO
	steering = 0.0
	boost_left = 0.0
	handbraking = false
	_handbrake_blend = 0.0
	_travel_direction = Vector2.ZERO
	_impact_yaw_velocity = 0.0
	_impact_lean = 0.0
	_impact_pitch = 0.0
	_spark_cooldown = 0.0
	body_roll = 0.0
	if is_instance_valid(visual):
		visual.set_body_roll(0.0)


func start_boost() -> bool:
	if not active or destroyed or not is_instance_valid(driver) or boost_recharge > 0.0 \
		or Input.is_action_pressed(&"roll"):
		return false
	boost_left = BOOST_DURATION
	boost_recharge = BOOST_COOLDOWN
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_E:
		var used := try_exit() if is_instance_valid(driver) else board(world.get("player") as PLAYER)
		if used or is_instance_valid(driver):
			# E is also weapon pickup. Consume its polling path for this press.
			world.set("weapon_interaction_consumed_until_release", true)
			get_viewport().set_input_as_handled()
	elif key == KEY_SHIFT and is_instance_valid(driver):
		start_boost()
		get_viewport().set_input_as_handled()
	elif key == KEY_SPACE and is_instance_valid(driver):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_spark_cooldown = maxf(0.0, _spark_cooldown - delta)
	_impact_yaw_velocity *= exp(-8.0 * delta)
	_impact_lean = move_toward(_impact_lean, 0.0, 0.32 * delta)
	_impact_pitch = move_toward(_impact_pitch, 0.0, 0.30 * delta)
	for id: int in _impact_cooldowns.keys():
		_impact_cooldowns[id] -= delta
		if _impact_cooldowns[id] <= 0.0:
			_impact_cooldowns.erase(id)
	boost_recharge = maxf(0.0, boost_recharge - delta)
	boost_left = maxf(0.0, boost_left - delta)
	if not is_instance_valid(visual):
		set_active(false)
		queue_free()
		return
	if destroyed:
		if is_instance_valid(drive_audio): drive_audio.stop_all()
		if is_instance_valid(boost_wind): boost_wind.clear()
		return
	if smoking:
		_smoke_left -= delta
		if _smoke_left <= 0.0 and is_instance_valid(damage_effects):
			_smoke_left = 0.22
			var exhaust := visual.to_global(Vector3(-0.63, 0.86, 0.0))
			damage_effects.effects.emit_smoke(damage_effects.effects.to_local(exhaust), 3, 0.60)
	if not is_instance_valid(driver):
		if is_instance_valid(drive_audio): drive_audio.stop_all()
		if is_instance_valid(boost_wind): boost_wind.clear()
		return
	if driver.dead or driver.airborne_knockback:
		_release_driver()
		return
	var throttle := Input.get_axis(&"move_down", &"move_up")
	var turn := Input.get_axis(&"move_left", &"move_right")
	# Space retains its on-foot roll binding; only the mounted controller reads it as a handbrake.
	handbraking = Input.is_action_pressed(&"roll")
	_handbrake_blend = move_toward(_handbrake_blend, 1.0 if handbraking else 0.0,
		(8.0 if handbraking else 4.0) * delta)
	var target := throttle * (FORWARD_SPEED if throttle >= 0.0 else REVERSE_SPEED)
	var response := ACCELERATION
	if handbraking:
		# The brake wins over throttle/boost; it never propels or pivots a stationary vehicle.
		target = 0.0
		response = HANDBRAKE_DECELERATION
		boost_left = 0.0
	elif is_zero_approx(throttle):
		response = COAST_DECELERATION
	elif speed * throttle < -0.05:
		# Opposite throttle first brakes to a stop, then engages reverse on the next tick.
		target = 0.0
		response = BRAKING
	elif boost_left > 0.0 and throttle > 0.0:
		target = BOOST_SPEED
		response = ACCELERATION * 3.0
	if not handbraking and absf(speed) > absf(target) and speed * target >= 0.0:
		response = BRAKING
	speed = move_toward(speed, target, response * delta)
	var steering_limit := lerpf(MAX_STEERING / (1.0 + absf(speed) * 0.12),
		HANDBRAKE_STEERING, _handbrake_blend)
	steering = move_toward(steering, turn * steering_limit, 2.8 * delta)
	var yaw_limit := lerpf(NORMAL_YAW_RATE, HANDBRAKE_YAW_RATE,
		_handbrake_blend * smoothstep(0.75, 4.0, absf(speed)))
	var yaw_step := (clampf(speed * tan(steering) / WHEELBASE, -yaw_limit, yaw_limit) + _impact_yaw_velocity) * delta
	var previous_yaw := global_rotation
	# Sweep the long forks through small rotation steps as well as through translation.
	if not is_zero_approx(yaw_step):
		var steps := maxi(1, ceili(absf(yaw_step) / ROTATION_SWEEP_STEP))
		for i in steps:
			var rotated_pose := Transform2D(global_rotation + yaw_step / steps, global_position)
			if not _supported(rotated_pose) or test_move(rotated_pose, Vector2.ZERO, null, 0.04, true):
				break
			global_rotation += yaw_step / steps
	var forward := get_forward_direction()
	if _travel_direction.is_zero_approx() or is_zero_approx(speed):
		_travel_direction = forward
	else:
		# Retain travel momentum while the body yaws, then regain grip smoothly on release.
		# Unit direction plus signed speed prevents steering from creating kinetic energy.
		var grip := lerpf(ROAD_GRIP, SLIDING_GRIP, _handbrake_blend)
		_travel_direction = _travel_direction.slerp(forward, 1.0 - exp(-grip * delta)).normalized()
	velocity = _travel_direction * speed * PIXELS_PER_METRE
	var next_pose := global_transform
	next_pose.origin += velocity * delta
	var before := global_position
	if _supported(next_pose):
		var impact_speed := velocity.length() / PIXELS_PER_METRE
		var incoming := velocity
		move_and_slide()
		_hit_enemies(impact_speed, before)
		if contact_response_enabled and get_slide_collision_count() > 0:
			var contact := CONTACT_RESPONSE.resolve(self, incoming)
			velocity = contact.velocity
			_impact_yaw_velocity = clampf(_impact_yaw_velocity + float(contact.yaw), -0.9, 0.9)
			_impact_lean = clampf(_impact_lean + float(contact.lean), -0.04, 0.04)
			_impact_pitch = clampf(_impact_pitch + float(contact.pitch), -0.035, 0.035)
			if contact.hard_hit: boost_left = 0.0
			_emit_contact_sparks(contact.spark)
		var direction_sign := signf(speed)
		if velocity.dot(forward) * direction_sign < -0.1 * velocity.length(): direction_sign = -direction_sign
		speed = direction_sign * velocity.length() / PIXELS_PER_METRE
		if not is_zero_approx(speed):
			_travel_direction = velocity.normalized() * signf(speed)
	else:
		speed = 0.0
		velocity = Vector2.ZERO
		_travel_direction = forward
	var distance := (global_position - before).dot(get_forward_direction()) / PIXELS_PER_METRE
	if absf(distance) > 0.001:
		exit_blocked = false
	if world.has_method("get_vehicle_floor_height"):
		var front := global_transform * (Vector2(MODEL.FRONT_AXLE.x, 0.0) * MODEL.MODEL_SCALE * PIXELS_PER_METRE)
		var rear := global_transform * (Vector2(MODEL.REAR_AXLE.x, 0.0) * MODEL.MODEL_SCALE * PIXELS_PER_METRE)
		var front_y := float(world.call("get_vehicle_floor_height", front / PIXELS_PER_METRE))
		var rear_y := float(world.call("get_vehicle_floor_height", rear / PIXELS_PER_METRE))
		floor_height = lerpf(rear_y, front_y, -MODEL.REAR_AXLE.x / (MODEL.FRONT_AXLE.x - MODEL.REAR_AXLE.x))
		visual.rotation.z = atan2(front_y - rear_y, WHEELBASE)
	visual.position = Vector3(global_position.x / PIXELS_PER_METRE, floor_height,
		global_position.y / PIXELS_PER_METRE)
	visual.rotation.y = -global_rotation
	var yaw_rate := angle_difference(previous_yaw, global_rotation) / maxf(delta, 0.0001)
	var lean := clampf(-clampf(yaw_rate / HANDBRAKE_YAW_RATE, -1.0, 1.0) * MAX_BODY_ROLL * _handbrake_blend + _impact_lean, -MAX_BODY_ROLL, MAX_BODY_ROLL)
	body_roll = move_toward(body_roll, lean, MAX_BODY_ROLL * 7.0 * delta)
	visual.set_body_roll(body_roll, _impact_pitch)
	visual.animate_drive(distance, steering, handbraking)
	_sync_driver()
	if is_instance_valid(drive_audio):
		drive_audio.sync_motion(absf(speed) / FORWARD_SPEED,
			boost_left > 0.0 and throttle > 0.0 and not handbraking and absf(speed) > 0.4,
			handbraking and _handbrake_blend > 0.15 and absf(speed) > 0.6, delta)
	if is_instance_valid(boost_wind):
		boost_wind.sync_motion(absf(speed),
			boost_left > 0.0 and throttle > 0.0 and not handbraking, delta)


func _emit_contact_sparks(contact: Dictionary) -> void:
	if contact.is_empty() or _spark_cooldown > 0.0 or not world.has_method("_firearm_fx"): return
	_spark_cooldown = 0.12
	var point: Vector2 = contact.point
	var local := to_local(point) / PIXELS_PER_METRE
	var height := 0.20 if local.x > MODEL.CHASSIS_MAX_X else 0.55
	var normal: Vector2 = contact.normal
	var normal_world := (world.global_basis * Vector3(normal.x, 0, normal.y)).normalized()
	world._firearm_fx().impact(world.get_gameplay_world_position(point, height), normal_world, &"metal", contact.strength, 0.35)


func _hit_enemies(impact_speed: float, origin: Vector2) -> void:
	if impact_speed < 1.1:
		return
	for index in get_slide_collision_count():
		var enemy := get_slide_collision(index).get_collider() as EmployeeEnemy
		if not is_instance_valid(enemy) or enemy.dead or _impact_cooldowns.has(enemy.get_instance_id()):
			continue
		_impact_cooldowns[enemy.get_instance_id()] = 0.75
		enemy.take_damage(clampf(impact_speed * 10.0, 8.0, 180.0), origin,
			maxf(impact_speed * PIXELS_PER_METRE * 2.0, 160.0), &"player_vehicle_impact")


func _supported(pose: Transform2D) -> bool:
	if not floor_support.is_valid():
		return true
	for axle: Vector2 in [MODEL.FRONT_AXLE, MODEL.REAR_AXLE]:
		for side in [-1, 1]:
			var wheel := pose * (Vector2(axle.x, side * 0.45) * MODEL.MODEL_SCALE * PIXELS_PER_METRE)
			if not bool(floor_support.call(wheel / PIXELS_PER_METRE)):
				return false
	return true


func _sync_driver() -> void:
	driver.global_position += _seat_position() - driver.body_collision.global_position
	driver.velocity = Vector2.ZERO
	driver.last_move_direction = get_forward_direction()
	var bridge: Node3D = world.get("player_depth_bridge")
	if is_instance_valid(bridge):
		bridge.set("ground_surface_height", floor_height + MODEL.FOOTWELL_Y)
		bridge.show()


func get_control_hint(candidate: PLAYER) -> String:
	if is_instance_valid(driver):
		if exit_blocked:
			return "下车位置被挡住　·　移到空地后按 E 下车"
		return "叉车 %d/300　W/S 行驶　A/D 转向　空格 手刹漂移　Shift 加速　E 下车" % ceili(hp)
	return "E　驾驶叉车" if can_board(candidate) else ""


func _exit_tree() -> void:
	if not _transferring:
		_release_driver()
