extends Node
var _cached_dream_world: Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")

signal weapon_fired(recoil_multiplier: float)

const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")

var damage := 3.0
var attack_interval := 0.8
var attack_range := 270.0
var pellet_count := 9
var spread_degrees := 30.0
var projectile_speed := 155.0
var active := false
var cooldown_left := 0.0
var recoil_multiplier := 1.8
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08



func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	var parameters := FIREARM_RULES.parameters(config, &"shotgun")
	damage = float(parameters.damage)
	pellet_count = int(parameters.pellets)
	spread_degrees = float(parameters.spread_degrees)
	projectile_speed = maxf(1.0, float(parameters.speed))
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.weapon_interval_for_rate(float(parameters.interval)) / maxf(attack_speed, 0.01)
	attack_range = float(parameters.range) + int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	recoil_multiplier = config.shotgun_recoil_multiplier


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0 or not get_parent().should_trigger_weapon_attack():
		return
	_fire_once()


func _fire_once() -> bool:
	var empty_before_attempt := false
	if get_parent().has_method("is_weapon_empty_for_attack"):
		empty_before_attempt = bool(get_parent().call("is_weapon_empty_for_attack"))
	if not get_parent().try_consume_ammo_for_attack():
		if empty_before_attempt:
			SFX.play_weapon_dry_fire()
		return false
	cooldown_left = attack_interval
	_fire_full_volley(get_parent().get_aim_direction(), true)
	weapon_fired.emit(recoil_multiplier)
	return true


func _fire_full_volley(direction: Vector2, allow_extra: bool) -> void:
	var world := _dream_world()
	var volley_spawned := false
	if world != null:
		for pellet_direction in FIREARM_RULES.directions(direction, pellet_count, spread_degrees):
			var projectile := PROJECTILE_SCENE.instantiate()
			projectile.global_position = get_parent().get_projectile_origin()
			FIREARM_RULES.setup_projectile(projectile, pellet_direction, damage, attack_range, projectile_speed, &"player", get_parent() as Node2D, &"shotgun")
			world.add_projectile(projectile, get_parent() as Node2D)
			volley_spawned = volley_spawned or projectile.is_inside_tree()
		if world.has_method("spawn_weapon_muzzle"):
			world.spawn_weapon_muzzle(get_parent().get_projectile_origin(), direction, &"shotgun", get_parent() as Node2D)
		# 一次Volley只抛出一个弹壳，绝不随pellet_count倍增。
		if world.has_method("spawn_shell_ejection"):
			world.spawn_shell_ejection(get_parent().get_projectile_origin(), direction, &"shotgun")
	if volley_spawned:
		SFX.play_weapon_fire()
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire_full_volley(direction, false)


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
	attack_range += pixels
