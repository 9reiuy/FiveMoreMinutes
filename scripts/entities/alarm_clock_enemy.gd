extends "res://scripts/entities/basic_enemy.gd"

signal special_defeated(at_position: Vector2, experience_value: int, rarity: String)

enum State { APPROACH, CHARGE, DEATH_DELAY, CHAIN_TRIGGERED, DEAD }

var state := State.APPROACH
var state_left := 0.0
var has_exploded := false
var reward_emitted := false
var enemy_config: DemoConfig


func _ready() -> void:
	super._ready()
	if enemy_config != null and visual != null:
		visual_base_scale = Vector2.ONE * enemy_config.alarm_enemy_visual_scale
		visual.scale = visual_base_scale


func configure(new_target: Node2D, _health: float, _damage: float, bounds: Rect2, new_separation_strength: float, new_separation_radius: float, config: DemoConfig = null) -> void:
	super.configure(new_target, config.alarm_enemy_max_hp, config.alarm_enemy_contact_damage, bounds, new_separation_strength, new_separation_radius, config)
	enemy_config = config
	movement_speed = config.alarm_enemy_movement_speed
	contact_damage = 0.0


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	if state in [State.DEATH_DELAY, State.CHAIN_TRIGGERED, State.CHARGE]:
		velocity = Vector2.ZERO
		state_left -= delta
		if state_left <= 0.0:
			_explode()
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = (direction * movement_speed + _get_separation_velocity()).limit_length(movement_speed)
	move_and_slide()
	update_direction_animation()
	if global_position.distance_to(target.global_position) <= enemy_config.alarm_enemy_trigger_distance:
		state = State.CHARGE
		state_left = enemy_config.alarm_enemy_charge_seconds
		_play_visual_animation(&"charge")
		queue_redraw()


func take_damage(amount: float, hit_origin: Vector2 = Vector2.INF) -> void:
	if state in [State.DEATH_DELAY, State.CHAIN_TRIGGERED, State.DEAD]:
		return
	current_health -= amount
	if current_health <= 0.0:
		dead = true
		set_auto_aim_locked(false)
		state = State.DEATH_DELAY
		state_left = enemy_config.alarm_enemy_death_delay
		_play_visual_animation(&"death_delay")
		queue_redraw()
	else:
		super.take_damage(0.0, hit_origin)


func trigger_chain() -> void:
	if has_exploded or state in [State.DEATH_DELAY, State.CHAIN_TRIGGERED, State.DEAD]:
		return
	dead = true
	set_auto_aim_locked(false)
	state = State.CHAIN_TRIGGERED
	state_left = enemy_config.alarm_enemy_chain_delay
	_play_visual_animation(&"death_delay")


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	dead = true
	set_auto_aim_locked(false)
	state = State.DEAD
	_play_visual_animation(&"explode")
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= enemy_config.alarm_enemy_explosion_radius:
		target.receive_damage(enemy_config.alarm_enemy_explosion_damage)
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > enemy_config.alarm_enemy_explosion_radius:
			continue
		if enemy.has_method("trigger_chain"):
			enemy.trigger_chain()
		elif enemy.has_method("take_damage"):
			enemy.take_damage(enemy_config.alarm_enemy_explosion_damage, global_position)
	if not reward_emitted:
		reward_emitted = true
		special_defeated.emit(global_position, enemy_config.alarm_enemy_blue_exp_value, "blue")
	queue_redraw()
	await get_tree().create_timer(0.16, false).timeout
	queue_free()


func _draw() -> void:
	if state in [State.CHARGE, State.DEATH_DELAY, State.CHAIN_TRIGGERED]:
		draw_circle(Vector2.ZERO, enemy_config.alarm_enemy_explosion_radius, Color(0.65, 0.18, 0.20, 0.18))
		draw_circle(Vector2.ZERO, enemy_config.alarm_enemy_explosion_radius, Color("a75b65"), false, 2.0)
