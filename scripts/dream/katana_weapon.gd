extends Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")

signal weapon_fired(recoil_multiplier: float)

const WAVE_SCENE := preload("res://scenes/entities/sword_wave.tscn")
const SLASH_SCENE := preload("res://scenes/entities/katana_slash_effect.tscn")

var damage := 30.0
var attack_interval := 2.0
var attack_range := 50.0
var wave_damage := 10.0
var wave_speed := 450.0
var wave_distance := 300.0
var wave_width := 16.0
var wave_initial_speed_ratio := 0.35
var wave_acceleration_duration := 0.25
var wave_acceleration_curve: Curve
var active := false
var cooldown_left := 0.25
var recoil_multiplier := 1.0
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	damage = config.katana_melee_damage
	wave_damage = config.katana_wave_damage
	wave_speed = config.katana_wave_speed
	wave_width = config.katana_wave_width
	wave_initial_speed_ratio = config.katana_wave_initial_speed_ratio
	wave_acceleration_duration = config.katana_wave_acceleration_duration
	wave_acceleration_curve = config.katana_wave_acceleration_curve
	var permanent_range := int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	attack_range = config.katana_melee_radius + permanent_range
	wave_distance = config.katana_wave_max_distance + permanent_range
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.katana_attack_interval / maxf(attack_speed, 0.01)


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_interval
	_fire_full_attack(get_parent().get_aim_direction(), true)
	weapon_fired.emit(recoil_multiplier)


func _fire_full_attack(direction: Vector2, allow_extra: bool) -> void:
	SFX.play_event(&"weapon_fire")
	var origin: Vector2 = get_parent().global_position
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if is_instance_valid(enemy) and not enemy.dead and origin.distance_to(enemy.global_position) <= attack_range:
			var hit_world := get_tree().get_first_node_in_group("dream_world")
			if hit_world != null:
				hit_world.resolve_player_hit(enemy, damage, origin)
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		var slash := SLASH_SCENE.instantiate()
		slash.global_position = origin
		slash.setup(direction, attack_range, preload("res://resources/demo_config.tres").katana_afterimage_seconds)
		world.add_weapon_effect(slash)
		var wave := WAVE_SCENE.instantiate()
		wave.global_position = origin
		wave.setup(direction, wave_damage, wave_speed, wave_distance, wave_width, wave_initial_speed_ratio, wave_acceleration_duration, wave_acceleration_curve)
		world.add_projectile(wave)
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire_full_attack(direction, false)


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(0.0, delay)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval, 0.001), 0.0, 1.0)


func apply_damage_upgrade(multiplier: float) -> void:
	damage *= multiplier
	wave_damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	attack_interval /= maxf(multiplier, 0.01)


func apply_range_upgrade(pixels: float) -> void:
	attack_range += pixels
	wave_distance += pixels
