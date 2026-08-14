extends Node2D

# 弹丸本体使用 SP402 序列首帧静态保持，直到命中或销毁；后续序列帧由枪口子特效完整播放。
const BULLET_TEXTURE: Texture2D = preload("res://art/Effects/SP402_nyknck/SP402_01.png")
# SP402_01 帧内弹丸内容中心约在 (39.5, 16)，绘制时将其对准弹体坐标。
const BULLET_CONTENT_CENTER := Vector2(39.5, 16.0)

@export var speed := 310.0
@export var lifetime := 1.4

var direction := Vector2.RIGHT
var damage := 10.0
var consumed := false
var max_distance := 270.0
var traveled := 0.0


func _ready() -> void:
	_configure_soft_glow()


func _configure_soft_glow() -> void:
	var glow := get_node_or_null("SoftGlow") as SoftGlow
	if glow != null:
		var config := preload("res://resources/demo_config.tres") as DemoConfig
		glow.configure(config.projectile_glow_color, config.projectile_glow_alpha, config.projectile_glow_radius)


func setup(new_direction: Vector2, new_damage: float, new_max_distance: float = 270.0, new_speed: float = -1.0) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	max_distance = new_max_distance
	if new_speed > 0.0:
		speed = new_speed
	# SP402 素材的前进轴是局部 -x（弹头朝左、拖尾在右），
	# 朝向用旋转角 + PI 单独处理，帧内容保持原样不倒放。
	rotation = direction.angle() + PI
	queue_redraw()


func _process(delta: float) -> void:
	if consumed:
		return
	var step := speed * delta
	position += direction * step
	traveled += step
	lifetime -= delta
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if is_instance_valid(enemy) and not enemy.dead and _hits_enemy(enemy):
			consumed = true
			var world := get_tree().get_first_node_in_group("dream_world")
			if world != null:
				world.resolve_player_hit(enemy, damage, global_position)
			queue_free()
			return
	if lifetime <= 0.0 or traveled >= max_distance:
		queue_free()


## 命中判定走敌人受击区接口：普通敌人等效于原有 13px 半径圆，
## 触手怪等大体型敌人按贴合身体的受击形状判定。
func _hits_enemy(enemy: Node2D) -> bool:
	if enemy.has_method("distance_to_hurtbox"):
		return float(enemy.distance_to_hurtbox(global_position)) <= 0.0
	return global_position.distance_to(enemy.global_position) < 13.0


func _draw() -> void:
	# 弹丸本体帧在飞行全程保持显示，拖影包含在帧内。
	var frame_size := BULLET_TEXTURE.get_size()
	draw_texture_rect(BULLET_TEXTURE, Rect2(-BULLET_CONTENT_CENTER, frame_size), false)
