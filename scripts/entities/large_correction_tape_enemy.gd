extends "res://scripts/entities/basic_enemy.gd"

enum State { TRACKING, CHARGING, DASHING, BETWEEN_DASHES, RECOVERING }

var state := State.TRACKING
var state_time := 0.0
var dash_direction := Vector2.RIGHT
var dash_remaining := 0.0
var completed_dashes := 0
var hit_this_dash := false
var trigger_distance := 150.0
var charge_seconds := 0.75
var dash_distance := 200.0
var dash_speed := 360.0
var dash_damage := 24.0
var dash_count := 3
var dash_interval := 0.2
var recovery_seconds := 0.5
var size_multiplier := 1.8
var dash_time_left := 0.0
var dash_max_seconds := 1.25


func configure_special(config: DemoConfig) -> void:
	trigger_distance = config.large_correction_trigger_distance
	charge_seconds = config.large_correction_charge_seconds
	dash_distance = config.large_correction_dash_distance
	dash_speed = config.large_correction_dash_speed
	dash_damage = config.large_correction_dash_damage
	dash_count = config.large_correction_dash_count
	dash_interval = config.large_correction_dash_interval
	recovery_seconds = config.large_correction_recovery_seconds
	size_multiplier = config.large_correction_size_multiplier
	dash_max_seconds = config.correction_dash_max_seconds
	$CollisionShape2D.scale = Vector2.ONE * size_multiplier
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_instance_valid(target) or target.get("dead") == true:
		if state != State.RECOVERING and state != State.TRACKING:
			_enter_recovery()
		return
	match state:
		State.TRACKING:
			if global_position.distance_to(target.global_position) <= trigger_distance:
				state = State.CHARGING
				state_time = charge_seconds
				completed_dashes = 0
				_read_dash_direction()
				_play_visual_animation(&"charge")
				queue_redraw()
			else:
				super._physics_process(delta)
		State.CHARGING:
			velocity = Vector2.ZERO
			state_time -= delta
			var charge_progress := 1.0 - clampf(state_time / maxf(charge_seconds, 0.001), 0.0, 1.0)
			set_visual_state_offset(-dash_direction * lerpf(2.0, 7.0, charge_progress) + Vector2(sin(state_time * 76.0) * 2.0, 0.0))
			queue_redraw()
			if state_time <= 0.0:
				_read_dash_direction()
				_begin_dash()
		State.DASHING:
			_update_dash(delta)
		State.BETWEEN_DASHES:
			velocity = Vector2.ZERO
			state_time -= delta
			queue_redraw()
			if state_time <= 0.0:
				_read_dash_direction()
				_begin_dash()
		State.RECOVERING:
			velocity = Vector2.ZERO
			state_time -= delta
			if state_time <= 0.0:
				state = State.TRACKING


func _read_dash_direction() -> void:
	dash_direction = global_position.direction_to(target.global_position)


func _begin_dash() -> void:
	state = State.DASHING
	set_visual_state_offset(Vector2.ZERO)
	_play_visual_animation(&"walk")
	dash_remaining = dash_distance
	dash_time_left = dash_max_seconds
	hit_this_dash = false
	queue_redraw()


func _update_dash(delta: float) -> void:
	dash_time_left -= delta
	if dash_time_left <= 0.0:
		_finish_current_dash()
		return
	var movement := minf(dash_speed * movement_speed_multiplier * delta, dash_remaining)
	var next := global_position + dash_direction * movement
	next.x = clampf(next.x, arena_bounds.position.x, arena_bounds.end.x)
	next.y = clampf(next.y, arena_bounds.position.y, arena_bounds.end.y)
	var moved := global_position.distance_to(next)
	global_position = next
	dash_remaining -= moved
	if not hit_this_dash and global_position.distance_to(target.global_position) < 29.0:
		hit_this_dash = true
		target.receive_damage(dash_damage)
	if moved + 0.01 < movement or dash_remaining <= 0.0:
		_finish_current_dash()


func _finish_current_dash() -> void:
	velocity = Vector2.ZERO
	dash_remaining = 0.0
	dash_time_left = 0.0
	dash_direction = Vector2.ZERO
	completed_dashes = clampi(completed_dashes + 1, 0, maxi(1, dash_count))
	if completed_dashes < maxi(1, dash_count) and is_instance_valid(target) and target.get("dead") != true:
		state = State.BETWEEN_DASHES
		state_time = dash_interval
		_read_dash_direction()
	else:
		_enter_recovery()
	queue_redraw()


func _enter_recovery() -> void:
	velocity = Vector2.ZERO
	dash_remaining = 0.0
	dash_time_left = 0.0
	dash_direction = Vector2.ZERO
	state = State.RECOVERING
	state_time = recovery_seconds
	set_visual_state_offset(Vector2.ZERO)
	_play_visual_animation(&"walk")
	queue_redraw()


func _draw() -> void:
	var flash := state == State.CHARGING or state == State.BETWEEN_DASHES
	if flash:
		var progress := 1.0 - clampf(state_time / maxf(charge_seconds, 0.001), 0.0, 1.0) if state == State.CHARGING else 0.65
		draw_line(Vector2.ZERO, dash_direction * lerpf(42.0, 66.0, progress), Color(0.96, 0.33, 0.28, 0.9), 4.0)
		draw_arc(Vector2.ZERO, lerpf(34.0, 23.0, progress), 0.0, TAU, 24, Color(1.0, 0.62, 0.42, 0.85), 3.0)
