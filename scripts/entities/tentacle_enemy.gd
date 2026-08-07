extends "res://scripts/entities/basic_enemy.gd"

## 触手怪：Crawling Depths Tentacle 素材。不移动、只造成接触伤害，
## 伤害/描边/受击反馈全部沿用基类统一体系；死亡掉落 1 个紫色经验球，额外掉落 1 个红心。

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


## 触手没有死亡序列帧：禁用碰撞后淡出，结束后才结算紫色经验与红心并回收。
func _begin_death_sequence() -> void:
	if death_processed:
		return
	death_processed = true
	set_physics_process(false)
	var shape := get_node_or_null("CollisionShape2D")
	if shape != null:
		shape.set_deferred("disabled", true)
	set_auto_aim_locked(false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade.finished
	if not is_inside_tree():
		return
	special_defeated.emit(global_position, tentacle_config.tentacle_purple_exp_value, "purple")
	heart_drop_requested.emit(global_position)
	queue_free()
