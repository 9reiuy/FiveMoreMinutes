extends Node
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
signal weapon_fired(recoil_multiplier: float)

const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")

@export var damage := 10.0
@export var attack_interval := 0.62
@export var attack_range := 270.0

var active := true
var cooldown_left := 0.25
var recoil_multiplier := 1.0
var projectile_speed := 155.0
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	var parameters := FIREARM_RULES.parameters(config, &"basic")
	damage = float(parameters.damage)
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	attack_interval = config.weapon_interval_for_rate(float(parameters.interval)) / maxf(attack_speed, 0.01)
	attack_range = float(parameters.range) + int(permanent_upgrades.get("visual_cortex", 0)) * config.visual_cortex_range_per_level
	projectile_speed = float(parameters.speed)
	recoil_multiplier = config.basic_weapon_recoil_multiplier


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	if not get_parent().has_method("should_trigger_weapon_attack") or not get_parent().should_trigger_weapon_attack():
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
	var world := get_tree().get_first_node_in_group("dream_world")
	var origin: Vector2 = get_parent().get_projectile_origin()
	var projectile := PROJECTILE_SCENE.instantiate()
	var projectile_spawned := false
	var shot_direction: Vector2 = FIREARM_RULES.directions(direction)[0]
	FIREARM_RULES.setup_projectile(projectile, shot_direction, damage, attack_range, projectile_speed, &"player", get_parent() as Node2D, &"basic")
	# Set the gameplay origin before registering the depth bridge.  This avoids
	# one frame where the 3D carrier captures the freshly-instantiated projectile
	# at (0, 0) instead of at the muzzle.
	projectile.global_position = origin
	if world != null:
		# 发射点对齐恢复原尺寸后的躯干挂点（仅视觉出生位置，射程不变）。
		world.add_projectile(projectile, get_parent() as Node2D)
		projectile_spawned = projectile.is_inside_tree()
		if world.has_method("spawn_weapon_muzzle"):
			world.spawn_weapon_muzzle(origin, direction, &"pistol", get_parent() as Node2D)
		if world.has_method("spawn_shell_ejection"):
			world.spawn_shell_ejection(origin, direction, &"basic")
	else:
		# 房间场景单独运行时没有DreamWorld弹丸容器，仍使用同一个正式弹丸场景完成射击测试。
		var fallback_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		fallback_parent.add_child(projectile)
		projectile.global_position = origin
		projectile_spawned = projectile.is_inside_tree()
	if projectile_spawned:
		SFX.play_weapon_fire()
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			_fire(direction, false)


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(0.0, delay)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval,0.001),0.0,1.0)
