extends "res://scripts/entities/basic_enemy.gd"

var fire_interval := 2.0
var fire_left := 1.0
var staple_damage := 10.0
var staple_speed := 170.0
var staple_distance := 300.0
var staple_radius := 5.0
var attack_windup_seconds := 0.35
var preparing_attack := false
var recoil_left := 0.0


func configure_special(config: DemoConfig) -> void:
	experience_drop_count = config.stapler_experience_drop_count
	fire_interval = config.stapler_fire_interval
	fire_left = fire_interval
	staple_damage = config.staple_damage
	staple_speed = config.staple_speed
	staple_distance = config.staple_max_distance
	staple_radius = config.staple_collision_radius
	attack_windup_seconds = minf(config.stapler_attack_windup_seconds, fire_interval * 0.8)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead or not is_instance_valid(target):
		return
	fire_left -= delta
	recoil_left = maxf(0.0, recoil_left - delta)
	if fire_left <= attack_windup_seconds and fire_left > 0.0 and not preparing_attack:
		preparing_attack = true
		_play_visual_animation(&"attack_prepare")
	if preparing_attack:
		var windup_progress := 1.0 - clampf(fire_left / maxf(attack_windup_seconds, 0.001), 0.0, 1.0)
		set_visual_state_offset(Vector2(0.0, -lerpf(0.0, 4.0, windup_progress)))
		queue_redraw()
	if fire_left <= 0.0:
		fire_left = fire_interval
		preparing_attack = false
		recoil_left = 0.12
		set_visual_state_offset(Vector2(0.0, 3.0))
		var world := get_tree().get_first_node_in_group("dream_world")
		if world != null:
			world.spawn_staple(global_position, global_position.direction_to(target.global_position), staple_damage, staple_speed, staple_distance, staple_radius, target)
	if not preparing_attack and recoil_left <= 0.0:
		set_visual_state_offset(Vector2.ZERO)
		_play_visual_animation(&"walk")


func _draw() -> void:
	if not preparing_attack or not is_instance_valid(target):
		return
	var progress := 1.0 - clampf(fire_left / maxf(attack_windup_seconds, 0.001), 0.0, 1.0)
	var direction := global_position.direction_to(target.global_position)
	draw_line(Vector2.ZERO, direction * lerpf(18.0, 34.0, progress), Color(0.9, 0.39, 0.34, 0.35 + progress * 0.5), 2.0)
	draw_circle(Vector2.ZERO, lerpf(20.0, 13.0, progress), Color(0.94, 0.55, 0.42, 0.7), false, 2.0)
