extends "res://scripts/entities/basic_enemy.gd"

signal special_defeated(at_position: Vector2, experience_value: int, rarity: String)
signal split_requested(at_position: Vector2, count: int)

enum State { APPROACH, SLAM_CHARGE, COOLDOWN, DEAD }

var state := State.APPROACH
var state_left := 0.0
var slam_direction := Vector2.RIGHT
var reward_emitted := false
var enemy_config: DemoConfig


func configure(new_target: Node2D, _health: float, _damage: float, bounds: Rect2, new_separation_strength: float, new_separation_radius: float, config: DemoConfig = null) -> void:
	super.configure(new_target, config.mailbox_enemy_max_hp, config.mailbox_enemy_contact_damage, bounds, new_separation_strength, new_separation_radius, config)
	enemy_config = config
	movement_speed = config.mailbox_enemy_movement_speed


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	if state == State.SLAM_CHARGE:
		velocity = Vector2.ZERO
		state_left -= delta
		if state_left <= 0.0:
			_perform_slam()
		return
	if state == State.COOLDOWN:
		state_left -= delta
		if state_left <= 0.0:
			state = State.APPROACH
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < 22.0 and contact_cooldown <= 0.0:
		contact_cooldown = 0.8
		target.receive_damage(contact_damage)
	if distance <= enemy_config.mailbox_enemy_attack_trigger_distance:
		state = State.SLAM_CHARGE
		state_left = enemy_config.mailbox_enemy_slam_windup
		slam_direction = global_position.direction_to(target.global_position)
		_play_visual_animation(&"slam_charge")
		queue_redraw()
		return
	velocity = (global_position.direction_to(target.global_position) * movement_speed + _get_separation_velocity()).limit_length(movement_speed)
	move_and_slide()
	update_direction_animation()


func _perform_slam() -> void:
	_play_visual_animation(&"slam")
	var offset := target.global_position - global_position
	if offset.length() <= enemy_config.mailbox_enemy_slam_range and absf(slam_direction.angle_to(offset.normalized())) <= deg_to_rad(enemy_config.mailbox_enemy_slam_angle * 0.5):
		target.receive_damage(enemy_config.mailbox_enemy_slam_damage)
	state = State.COOLDOWN
	state_left = enemy_config.mailbox_enemy_attack_cooldown
	queue_redraw()


func take_damage(amount: float, hit_origin: Vector2 = Vector2.INF) -> void:
	if state == State.DEAD:
		return
	current_health -= amount
	if current_health <= 0.0:
		dead = true
		set_auto_aim_locked(false)
		state = State.DEAD
		_play_visual_animation(&"death")
		if not reward_emitted:
			reward_emitted = true
			special_defeated.emit(global_position, enemy_config.mailbox_enemy_purple_exp_value, "purple")
			split_requested.emit(global_position, enemy_config.mailbox_enemy_split_count)
		await get_tree().create_timer(0.18, false).timeout
		queue_free()
	else:
		super.take_damage(0.0, hit_origin)


func _draw() -> void:
	if state != State.SLAM_CHARGE:
		return
	var half_angle := deg_to_rad(enemy_config.mailbox_enemy_slam_angle * 0.5)
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(9):
		var angle := lerpf(-half_angle, half_angle, float(index) / 8.0)
		points.append(slam_direction.rotated(angle) * enemy_config.mailbox_enemy_slam_range)
	draw_colored_polygon(points, Color(0.55, 0.22, 0.28, 0.18))
	draw_polyline(points, Color("9b6573"), 2.0)
