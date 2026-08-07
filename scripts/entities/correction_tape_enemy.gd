extends "res://scripts/entities/basic_enemy.gd"

enum State { TRACKING, CHARGING, DASHING, RECOVERING }

var state := State.TRACKING
var state_time := 0.0
var dash_direction := Vector2.RIGHT
var dash_remaining := 0.0
var trigger_distance := 150.0
var charge_seconds := 0.75
var dash_distance := 200.0
var dash_speed := 360.0
var dash_damage := 18.0
var recovery_seconds := 0.5
var hit_this_dash := false
var dash_time_left := 0.0
var dash_max_seconds := 1.25
var charge_audio: AudioStreamPlayer


func configure_special(config: DemoConfig) -> void:
	experience_drop_count = config.correction_experience_drop_count
	trigger_distance = config.correction_trigger_distance
	charge_seconds = config.correction_charge_seconds
	dash_distance = config.correction_dash_distance
	dash_speed = config.correction_dash_speed
	dash_damage = config.correction_dash_damage
	recovery_seconds = config.correction_recovery_seconds
	dash_max_seconds = config.correction_dash_max_seconds
	charge_audio = AudioStreamPlayer.new()
	charge_audio.bus = &"Characters"
	charge_audio.stream = TextBlipFactory.create(config)
	charge_audio.volume_db = -18.0
	add_child(charge_audio)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_instance_valid(target) or target.get("dead") == true:
		if state == State.DASHING or state == State.CHARGING:
			_enter_recovery()
		return
	match state:
		State.TRACKING:
			if global_position.distance_to(target.global_position) <= trigger_distance:
				state = State.CHARGING
				state_time = charge_seconds
				dash_direction = global_position.direction_to(target.global_position)
				charge_audio.play()
				_play_visual_animation(&"charge")
				queue_redraw()
			else:
				super._physics_process(delta)
		State.CHARGING:
			velocity = Vector2.ZERO
			state_time -= delta
			var charge_progress := 1.0 - clampf(state_time / maxf(charge_seconds, 0.001), 0.0, 1.0)
			set_visual_state_offset(-dash_direction * lerpf(1.0, 5.0, charge_progress) + Vector2(sin(state_time * 70.0) * 1.5, 0.0))
			queue_redraw()
			if state_time <= 0.0:
				state = State.DASHING
				set_visual_state_offset(Vector2.ZERO)
				_play_visual_animation(&"walk")
				dash_remaining = dash_distance
				dash_time_left = dash_max_seconds
				hit_this_dash = false
		State.DASHING:
			_update_dash(delta)
		State.RECOVERING:
			velocity = Vector2.ZERO
			state_time -= delta
			if state_time <= 0.0:
				state = State.TRACKING


func _update_dash(delta: float) -> void:
	dash_time_left -= delta
	if dash_time_left <= 0.0:
		_enter_recovery()
		return
	var movement := minf(dash_speed * movement_speed_multiplier * delta, dash_remaining)
	var next := global_position + dash_direction * movement
	next.x = clampf(next.x, arena_bounds.position.x, arena_bounds.end.x)
	next.y = clampf(next.y, arena_bounds.position.y, arena_bounds.end.y)
	var moved := global_position.distance_to(next)
	global_position = next
	dash_remaining -= moved
	if not hit_this_dash and global_position.distance_to(target.global_position) < 23.0:
		hit_this_dash = true
		target.receive_damage(dash_damage)
	if moved + 0.01 < movement or dash_remaining <= 0.0:
		_enter_recovery()


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
	if state == State.CHARGING:
		var progress := 1.0 - clampf(state_time / maxf(charge_seconds, 0.001), 0.0, 1.0)
		draw_line(Vector2.ZERO, dash_direction * lerpf(28.0, 48.0, progress), Color(0.88, 0.34, 0.28, 0.55 + progress * 0.4), 3.0)
		draw_arc(Vector2.ZERO, lerpf(22.0, 15.0, progress), 0.0, TAU, 20, Color(0.95, 0.57, 0.42, 0.8), 2.0)
