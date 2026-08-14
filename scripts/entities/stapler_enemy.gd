extends "res://scripts/entities/basic_enemy.gd"

## 精灵射手（Legacy internal ID: stapler）：冷却结束进入攻击状态时立即停止移动，
## 原地完整播放 attack_prepare 序列，到达 huntress_shoot_projectile_frame（弓弦释放帧）
## 时生成箭矢；动画播完恢复 walk 移动。攻击目标位置在进入攻击时锁定兜底。

var fire_interval := 2.0
var fire_left := 1.0
var staple_damage := 10.0
var staple_speed := 170.0
var staple_distance := 300.0
var staple_radius := 5.0
var enemy_config: DemoConfig
var attacking := false
var fired_this_cycle := false
var attack_target_position := Vector2.ZERO


func configure_special(config: DemoConfig) -> void:
	experience_drop_count = config.stapler_experience_drop_count
	fire_interval = config.stapler_fire_interval
	fire_left = fire_interval
	staple_damage = config.staple_damage
	staple_speed = config.staple_speed
	staple_distance = config.staple_max_distance
	staple_radius = config.staple_collision_radius
	enemy_config = config


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target):
		attacking = false
		return
	if attacking:
		# 攻击序列期间完全停止移动：velocity=0 且不调用父类寻路/位移。
		if enemy_config == null or enemy_config.huntress_attack_stop_before_shot:
			velocity = Vector2.ZERO
		if not fired_this_cycle and visual != null and enemy_config != null \
				and visual.frame >= enemy_config.huntress_shoot_projectile_frame:
			_fire_staple()
		# 动画播完后恢复移动；防御性兜底避免卡死在攻击状态。
		if visual == null or not visual.is_playing():
			_end_attack()
		return
	fire_left -= delta
	if fire_left <= 0.0:
		_begin_attack()
		return
	super._physics_process(delta)


func _begin_attack() -> void:
	attacking = true
	fired_this_cycle = false
	velocity = Vector2.ZERO
	# 锁定进入攻击时的目标位置：射箭方向优先实时目标，目标失效时用锁定位置。
	attack_target_position = target.global_position
	set_visual_state_offset(Vector2.ZERO)
	if visual != null:
		visual.stop()
		_play_visual_animation(&"attack_prepare")


func _end_attack() -> void:
	attacking = false
	fire_left = fire_interval
	if not fired_this_cycle:
		_fire_staple()
	set_visual_state_offset(Vector2.ZERO)
	_play_visual_animation(&"walk")


func _fire_staple() -> void:
	if fired_this_cycle:
		return
	fired_this_cycle = true
	var world := get_tree().get_first_node_in_group("dream_world")
	if world == null:
		return
	var aim_position := attack_target_position
	if is_instance_valid(target):
		aim_position = target.global_position
	var direction := global_position.direction_to(aim_position)
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	# 每次攻击独立生成一枚新弹丸；world.spawn_staple 每次实例化新节点，
	# 不持有也不销毁上一发仍在飞行中的弹丸。
	world.spawn_staple(global_position, direction, staple_damage, staple_speed, staple_distance, staple_radius, target)
	if world.has_method("spawn_bullet_sequence"):
		world.spawn_bullet_sequence(global_position, direction)


func _draw() -> void:
	# 攻击序列期间的瞄准提示线：指向锁定/实时目标。
	if not attacking:
		return
	var aim_position := attack_target_position
	if is_instance_valid(target):
		aim_position = target.global_position
	var direction := global_position.direction_to(aim_position)
	if direction.length_squared() < 0.0001:
		return
	draw_line(Vector2.ZERO, direction * 26.0, Color(0.9, 0.39, 0.34, 0.45), 2.0)
	draw_circle(Vector2.ZERO, 14.0, Color(0.94, 0.55, 0.42, 0.55), false, 2.0)
