extends "res://scripts/entities/basic_enemy.gd"

## 触手怪：Crawling Depths Tentacle 素材。不移动、只造成接触伤害，
## 伤害/描边/受击反馈全部沿用基类统一体系；死亡掉落 1 个紫色经验球，额外掉落 1 个红心。
## 序列帧使用四周带 4px 透明边距的 tentacle_sheet_padded.png：
## 原帧内容贴着 region 边缘，描边 shader 采样 UV±2px 越界被裁，
## 加透明 padding 后 2px 白描边在所有帧完整显示，帧内容/游戏尺寸不变。

signal special_defeated(at_position: Vector2, experience_value: int, rarity: String)
signal heart_drop_requested(at_position: Vector2)

var tentacle_config: DemoConfig


func configure(new_target: Node2D, _health: float, _damage: float, bounds: Rect2, new_separation_strength: float, new_separation_radius: float, config: DemoConfig = null) -> void:
	super.configure(new_target, config.tentacle_max_hp, config.tentacle_contact_damage, bounds, new_separation_strength, new_separation_radius, config)
	tentacle_config = config
	movement_speed = 0.0


func get_visual_scale(new_config: DemoConfig) -> float:
	return new_config.tentacle_visual_scale


## 不移动：跳过基类追击逻辑，只按受击冷却结算接触伤害。
func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target):
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	if global_position.distance_to(target.global_position) < 22.0 and contact_cooldown <= 0.0:
		contact_cooldown = 0.8
		target.receive_damage(contact_damage)


func update_direction_animation() -> void:
	pass


## 全身受击区：贴合触手身体轮廓的竖直胶囊（局部轴 (0,-36)~(0,6)、半径 11）
## + 底部圆盘（(0,12)、半径 12）；不把 40×64 帧内的透明空白计入受击。
func get_hurt_radius() -> float:
	return 48.0


func distance_to_hurtbox(world_point: Vector2) -> float:
	var local := to_local(world_point)
	var axis_top := Vector2(0.0, -36.0)
	var axis_bottom := Vector2(0.0, 6.0)
	var axis_t := clampf((local.y - axis_top.y) / maxf(axis_bottom.y - axis_top.y, 0.001), 0.0, 1.0)
	var body_distance := local.distance_to(axis_top.lerp(axis_bottom, axis_t)) - 11.0
	var root_distance := local.distance_to(Vector2(0.0, 12.0)) - 12.0
	return maxf(0.0, minf(body_distance, root_distance))


## 触手没有死亡序列帧：禁用碰撞后淡出，结束后才结算紫色经验与红心并回收。
func _begin_death_sequence() -> void:
	if death_processed:
		return
	death_processed = true
	set_physics_process(false)
	# 全身受击区由多个碰撞形状拼合，死亡时一并禁用。
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	set_auto_aim_locked(false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade.finished
	if not is_inside_tree():
		return
	special_defeated.emit(global_position, tentacle_config.tentacle_purple_exp_value, "purple")
	heart_drop_requested.emit(global_position)
	queue_free()
