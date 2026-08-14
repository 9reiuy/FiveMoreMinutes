extends Node2D

# 三倍扩图后的梦境地图可走区域；旧小地图尺寸会让榴弹出生即越界立即爆炸（脚底爆炸根因）。
const ARENA_BOUNDS := Rect2(24, 24, 992, 432)
# 爆炸视觉统一使用 HolyNova 序列帧，尺寸随爆炸视觉半径联动。
const HOLY_NOVA_SCENE := preload("res://scenes/entities/holy_nova_effect.tscn")

var target_position := Vector2.ZERO
var direction := Vector2.RIGHT
var speed := 300.0
var explosion_radius := 150.0
var explosion_visual_radius := 150.0
var enemy_damage := 30.0
var self_damage := 10.0
var owner_player: Node2D
var travel_time := 0.0
var minimum_travel_seconds := 0.12
var exploded := false


func setup(target: Vector2, new_speed: float, radius: float, visual_radius: float, damage: float, player_damage: float, player: Node2D, fallback_direction: Vector2 = Vector2.RIGHT) -> void:
	target_position = target
	direction = global_position.direction_to(target_position)
	if direction.length_squared() < 0.001:
		# 目标与出生点重合（鼠标贴在玩家身上）：优先用最近一次有效瞄准方向，绝不取消本次投掷。
		direction = fallback_direction.normalized() if fallback_direction.length_squared() > 0.0001 else Vector2.RIGHT
	speed = new_speed
	explosion_radius = radius
	explosion_visual_radius = visual_radius
	enemy_damage = damage
	self_damage = player_damage
	owner_player = player
	queue_redraw()


func _process(delta: float) -> void:
	if exploded:
		return
	travel_time += delta
	var remaining := global_position.distance_to(target_position)
	global_position = global_position.move_toward(target_position, speed * delta)
	rotation += delta * 7.0
	if not ARENA_BOUNDS.has_point(global_position) or (remaining <= speed * delta + 0.5 and travel_time >= minimum_travel_seconds):
		_explode()


func _explode() -> void:
	if exploded:
		return
	exploded = true
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null:
		for enemy in get_tree().get_nodes_in_group("dream_enemies"):
			if not is_instance_valid(enemy) or bool(enemy.get("dead")):
				continue
			# 保持原有“敌人中心在爆炸半径内”判定；触手怪等大体型敌人
			# 额外按受击区形状判定，炸到身体任意有效部位都结算伤害。
			var in_radius := global_position.distance_to(enemy.global_position) <= explosion_radius
			if not in_radius and enemy.has_method("distance_to_hurtbox"):
				in_radius = float(enemy.distance_to_hurtbox(global_position)) <= explosion_radius
			if in_radius:
				world.resolve_player_hit(enemy, enemy_damage, global_position)
	if is_instance_valid(owner_player) and global_position.distance_to(owner_player.global_position) <= explosion_radius:
		owner_player.receive_damage(self_damage)
	_spawn_explosion_visual()
	queue_free()


## 爆炸特效交给 HolyNova 播放，榴弹本体在爆炸后立即回收。
func _spawn_explosion_visual() -> void:
	var effect := HOLY_NOVA_SCENE.instantiate()
	effect.global_position = global_position
	effect.setup(explosion_visual_radius)
	var container := get_parent()
	if is_instance_valid(container):
		container.add_child(effect)


func _draw() -> void:
	if not exploded:
		draw_circle(Vector2.ZERO, 6.0, Color("647b8c"))
		draw_rect(Rect2(-2, -8, 4, 3), Color("b7c6cc"))
