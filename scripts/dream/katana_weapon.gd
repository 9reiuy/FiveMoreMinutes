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
# 剑气生成与攻击 CD 解耦保护：每次攻击事件自增序号，同一序号只生成一道剑气。
var katana_attack_sequence_id := 0
var wave_spawned_for_sequence := -1


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
	perform_katana_attack(true)
	weapon_fired.emit(recoil_multiplier)


## 一次完整太刀攻击 = 近战判定 + 1 道剑气，两者同属一个攻击事件。
## 剑气不依赖近战是否命中、也不依赖是否存在自动锁定目标；
## 瞄准方向统一取正式瞄准接口，零向量时回退 last_valid_aim / 玩家默认面朝。
func perform_katana_attack(allow_extra: bool) -> void:
	katana_attack_sequence_id += 1
	var sequence := katana_attack_sequence_id
	var direction := _resolve_attack_direction()
	SFX.play_event(&"weapon_fire")
	var origin: Vector2 = get_parent().global_position
	_perform_melee_hit(origin, direction)
	_spawn_katana_wave(origin, direction, sequence)
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			perform_katana_attack(false)


func _resolve_attack_direction() -> Vector2:
	var direction: Vector2 = get_parent().get_aim_direction()
	if direction.length_squared() < 0.0001:
		# 鼠标与玩家重合等零向量情况：get_aim_direction 内部已保留 last_aim_direction，
		# 这里再兑底玩家默认面朝，保证本次剑气绝不取消。
		direction = Vector2.RIGHT
	return direction


func _perform_melee_hit(origin: Vector2, direction: Vector2) -> void:
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


## 剑气生成带序号 guard：每个 attack_cycle 只生成一次，不漏不重。
func _spawn_katana_wave(origin: Vector2, direction: Vector2, sequence: int) -> void:
	if wave_spawned_for_sequence == sequence:
		return
	wave_spawned_for_sequence = sequence
	var world := get_tree().get_first_node_in_group("dream_world")
	if world == null:
		# 每次正式攻击必须生成 1 道剑气；链路断裂时明确报错，不默默丢失。
		push_error("Katana wave spawn failed: dream_world missing for attack sequence %d." % sequence)
		return
	var wave := WAVE_SCENE.instantiate()
	wave.global_position = origin
	wave.setup(direction, wave_damage, wave_speed, wave_distance, wave_width, wave_initial_speed_ratio, wave_acceleration_duration, wave_acceleration_curve, preload("res://resources/demo_config.tres").katana_wave_texture_forward_angle_deg)
	world.add_projectile(wave)


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
