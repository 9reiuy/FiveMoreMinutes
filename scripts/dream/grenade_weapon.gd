extends Node

signal weapon_fired(recoil_multiplier: float)

const GRENADE_SCENE := preload("res://scenes/entities/grenade_projectile.tscn")

var damage := 30.0
var attack_interval := 3.0
var attack_range := 420.0
var projectile_speed := 300.0
var explosion_radius := 150.0
var explosion_visual_radius := 150.0
var self_damage := 10.0
var active := false
var cooldown_left := 0.25
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	damage = config.grenade_enemy_damage
	projectile_speed = config.grenade_projectile_speed
	explosion_radius = config.grenade_explosion_radius
	explosion_visual_radius = config.grenade_explosion_visual_radius
	self_damage = config.grenade_player_self_damage
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.grenade_attack_interval / maxf(attack_speed, 0.01)


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_interval
	_throw(get_parent().get_constrained_aim_position(), true)
	weapon_fired.emit(1.2)


func _throw(target_position: Vector2, allow_extra: bool) -> void:
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		var grenade := GRENADE_SCENE.instantiate()
		grenade.global_position = get_parent().global_position
		grenade.setup(target_position, projectile_speed, explosion_radius, explosion_visual_radius, damage, self_damage, get_parent())
		world.add_projectile(grenade)
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_throw(target_position, false)


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(0.0, delay)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval, 0.001), 0.0, 1.0)


func apply_damage_upgrade(multiplier: float) -> void:
	damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	attack_interval /= maxf(multiplier, 0.01)


func apply_range_upgrade(pixels: float) -> void:
	# Grenade damage/visual radius is intentionally fixed at 150 px by the weapon rule.
	pass
