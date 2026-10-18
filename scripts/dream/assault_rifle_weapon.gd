extends Node

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")

signal weapon_fired(recoil_multiplier: float)

var damage := 3.0
var attack_interval := 0.15
var attack_range := 270.0
var projectile_speed := 180.0
var active := false:
	set(value):
		active = value
		if not active:
			_reset_spread()
var cooldown_left := 0.0
var recoil_multiplier := 0.8
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
## Total cone angle, in degrees. Sustained fire adds one degree per real shot.
@export_range(0.0, 30.0, 0.1) var base_spread_degrees := 2.0
@export_range(0.0, 30.0, 0.1) var max_spread_degrees := 6.0
@export_range(0.0, 5.0, 0.1) var spread_growth_per_shot := 1.0
@export_range(0.01, 2.0, 0.01) var spread_recovery_seconds := 0.25
var current_spread_degrees := 2.0


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	var parameters: Dictionary = FIREARM_RULES.parameters(config, &"assault_rifle")
	damage = float(parameters.damage)
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.weapon_interval_for_rate(float(parameters.interval)) / maxf(attack_speed, 0.01)
	attack_range = float(parameters.range) + int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	projectile_speed = float(parameters.speed)
	recoil_multiplier = config.assault_rifle_recoil_multiplier
	_reset_spread()


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	var trigger_held: bool = get_parent().should_trigger_weapon_attack()
	if not trigger_held:
		var recovery_rate := (maxf(max_spread_degrees, base_spread_degrees) - base_spread_degrees) / maxf(spread_recovery_seconds, 0.001)
		current_spread_degrees = move_toward(current_spread_degrees, base_spread_degrees, recovery_rate * maxf(delta, 0.0))
	if cooldown_left > 0.0 or not trigger_held:
		return
	var empty_before_attempt := false
	if get_parent().has_method("is_weapon_empty_for_attack"):
		empty_before_attempt = bool(get_parent().call("is_weapon_empty_for_attack"))
	if not get_parent().try_consume_ammo_for_attack():
		if empty_before_attempt:
			SFX.play_weapon_dry_fire()
		return
	cooldown_left = attack_interval
	_fire(get_parent().get_aim_direction(), true)
	weapon_fired.emit(recoil_multiplier)


func _fire(direction: Vector2, allow_extra: bool) -> void:
	var world := get_tree().get_first_node_in_group(&"dream_world")
	var origin: Vector2 = get_parent().get_projectile_origin()
	var projectile := PROJECTILE_SCENE.instantiate()
	var projectile_spawned := false
	var shot_direction: Vector2 = FIREARM_RULES.directions(direction, 1, current_spread_degrees)[0]
	FIREARM_RULES.setup_projectile(projectile, shot_direction, damage, attack_range, projectile_speed, &"player", get_parent() as Node2D, &"assault_rifle")
	# Register the bridge only after the real 2D projectile has its muzzle origin;
	# the projectile itself remains the authoritative moving gameplay object.
	projectile.global_position = origin
	if world != null:
		world.add_projectile(projectile, get_parent() as Node2D)
		projectile_spawned = projectile.is_inside_tree()
		world.spawn_weapon_muzzle(origin, direction, &"assault_rifle", get_parent() as Node2D)
		world.spawn_shell_ejection(origin, direction, &"assault_rifle")
	else:
		var fallback_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		fallback_parent.add_child(projectile)
		projectile.global_position = origin
		projectile_spawned = projectile.is_inside_tree()
	if projectile_spawned:
		current_spread_degrees = clampf(current_spread_degrees + spread_growth_per_shot, base_spread_degrees, maxf(max_spread_degrees, base_spread_degrees))
		SFX.play_weapon_fire()
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire(direction, false)


func _reset_spread() -> void:
	current_spread_degrees = base_spread_degrees


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(delay, 0.0)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval, 0.001), 0.0, 1.0)


func apply_damage_upgrade(multiplier: float) -> void:
	damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	attack_interval /= maxf(multiplier, 0.01)


func apply_range_upgrade(pixels: float) -> void:
	attack_range += pixels
