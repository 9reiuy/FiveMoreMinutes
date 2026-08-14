extends Node2D

# 三倍扩图后的梦境地图可走区域；旧小地图尺寸会让剑气出生即越界被释放（偶发无剑气根因）。
# 剑气视觉使用 SP301_04 月牙帧；素材自身默认朝向为尖端朝 -x（开口朝 +x），
# 因此默认补偿 180°，使视觉尖端与飞行方向一致（katana_wave_texture_forward_angle_deg）。
const WAVE_TEXTURE: Texture2D = preload("res://art/Effects/SP301_nyknck/SP301_04.png")

var direction := Vector2.RIGHT
var damage := 10.0
var speed := 450.0
var max_distance := 300.0
var wave_width := 1.0
var traveled := 0.0
var acceleration_elapsed := 0.0
var initial_speed_ratio := 1.0
var acceleration_duration := 0.001
var acceleration_curve: Curve
var hit_enemies: Dictionary = {}

func setup(new_direction: Vector2, new_damage: float, new_speed: float, new_distance: float, new_width: float, new_initial_speed_ratio: float, new_acceleration_duration: float, new_acceleration_curve: Curve, texture_forward_angle_deg: float = 180.0) -> void:
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0001 else Vector2.RIGHT
	damage = new_damage
	speed = new_speed
	max_distance = new_distance
	wave_width = new_width
	initial_speed_ratio = clampf(new_initial_speed_ratio, 0.0, 1.0)
	acceleration_duration = maxf(new_acceleration_duration, 0.001)
	acceleration_curve = new_acceleration_curve
	# 游戏逻辑运动方向与素材默认朝向拆开：最终旋转 = 瞄准方向角 + 素材补偿角。
	rotation = direction.angle() + deg_to_rad(texture_forward_angle_deg)
	var hit_shape := get_node("HitArea/CollisionShape2D") as CollisionShape2D
	var rectangle := hit_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(8.0, wave_width)
	queue_redraw()


func _process(delta: float) -> void:
	acceleration_elapsed = minf(acceleration_elapsed + delta, acceleration_duration)
	var acceleration_progress := clampf(acceleration_elapsed / acceleration_duration, 0.0, 1.0)
	var sampled_progress := acceleration_curve.sample_baked(acceleration_progress) if acceleration_curve != null else acceleration_progress
	var current_speed := lerpf(speed * initial_speed_ratio, speed, sampled_progress)
	var step := minf(current_speed * delta, maxf(0.0, max_distance - traveled))
	var movement_start := global_position
	var movement_end := movement_start + direction * step
	global_position = movement_end
	traveled += step
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var enemy_id := enemy.get_instance_id()
		var closest_point := Geometry2D.get_closest_point_to_segment(enemy.global_position, movement_start, movement_end)
		# 受击区接口：普通敌人等效原 13px 半径圆，触手怪等大体型按身体形状判定。
		var hurt_distance: float = enemy.distance_to_hurtbox(closest_point) if enemy.has_method("distance_to_hurtbox") else maxf(0.0, closest_point.distance_to(enemy.global_position) - 13.0)
		if not hit_enemies.has(enemy_id) and hurt_distance <= wave_width * 0.5:
			hit_enemies[enemy_id] = true
			var world := get_tree().get_first_node_in_group("dream_world")
			if world != null:
				world.resolve_player_hit(enemy, damage, global_position - direction)
	# 剑气是 World projectile；生命周期只由已飞行距离决定，不用地图/镜头边界做出生资格。
	if traveled >= max_distance:
		queue_free()


func _draw() -> void:
	# 月牙高度随 wave_width 联动，保持宽度按帧原始比例缩放，旋转已由 setup 对准飞行方向。
	var frame_size := WAVE_TEXTURE.get_size()
	var height := maxf(wave_width * 1.6, 20.0)
	var width := height * frame_size.x / frame_size.y
	draw_texture_rect(WAVE_TEXTURE, Rect2(-width * 0.35, -height * 0.5, width, height), false)
