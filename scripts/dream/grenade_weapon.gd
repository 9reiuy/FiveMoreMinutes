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
var spawn_offset_px := 14.0
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
	spawn_offset_px = config.grenade_spawn_offset_px
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
	var player := get_parent()
	var world := get_tree().get_first_node_in_group("dream_world")
	if world == null or not is_instance_valid(player):
		# 每次正式攻击必须创建投射物；实例化链路断裂时明确报错，不默默吞掉。
		push_error("Grenade throw failed: dream_world or player missing, no projectile spawned for this attack cycle.")
		return
	# 手动模式目标快照来自鼠标世界坐标（get_constrained_aim_position），方向则统一走
	# get_aim_direction（内部已保留 last_aim_direction），零向量也不会取消投掷。
	var aim_direction: Vector2 = player.get_aim_direction()
	if aim_direction.length_squared() < 0.0001:
		aim_direction = Vector2.RIGHT
	var grenade := GRENADE_SCENE.instantiate()
	# 出生点沿瞄准方向偏移，保证落在当前玩家碰撞体外侧，视觉仍像从手中投出；
	# 挂点对齐恢复原尺寸后的躯干中心。
	grenade.global_position = player.get_grenade_origin() + aim_direction * spawn_offset_px
	grenade.setup(target_position, projectile_speed, explosion_radius, explosion_visual_radius, damage, self_damage, player, aim_direction)
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
	# 榴弹伤害结算半径按武器规则保持固定；范围增益只联动爆炸视觉半径，
	# 保证 HolyNova 特效随范围 buff 同步变大。
	explosion_visual_radius = maxf(explosion_visual_radius + pixels, 16.0)
