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
var source_faction: StringName = &"player"
var shooter_instance_id: int = 0

func setup(new_direction: Vector2, new_damage: float, new_speed: float, new_distance: float, new_width: float, new_initial_speed_ratio: float, new_acceleration_duration: float, new_acceleration_curve: Curve, texture_forward_angle_deg: float = 180.0, new_source_faction: StringName = &"player", new_source_actor: Node2D = null) -> void:
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0001 else Vector2.RIGHT
	damage = new_damage
	speed = new_speed
	max_distance = new_distance
	wave_width = new_width
	initial_speed_ratio = clampf(new_initial_speed_ratio, 0.0, 1.0)
	acceleration_duration = maxf(new_acceleration_duration, 0.001)
	acceleration_curve = new_acceleration_curve
	source_faction = new_source_faction
	shooter_instance_id = new_source_actor.get_instance_id() if is_instance_valid(new_source_actor) else 0
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
	var world := get_tree().get_first_node_in_group("dream_world")
	if world != null and world.has_method("is_room_projectile_path_clear") and not world.is_room_projectile_path_clear(movement_start, movement_end):
		queue_free()
		return
	global_position = movement_end
	traveled += step
	_damage_segment_colliders(movement_start, movement_end, world)
	# 剑气是 World projectile；生命周期只由已飞行距离决定，不用地图/镜头边界做出生资格。
	if traveled >= max_distance:
		queue_free()


## 剑气仍然可以穿透多个目标，但只查询本帧真正扫过的物理形状，
## 不再让每一发剑气每帧遍历全地图Enemy与Furniture分组。
func _damage_segment_colliders(origin: Vector2, endpoint: Vector2, world: Node) -> void:
	var segment_length := origin.distance_to(endpoint)
	if segment_length <= 0.001:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(segment_length + 4.0, maxf(wave_width, 2.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(direction.angle(), origin.lerp(endpoint, 0.5))
	query.collision_mask = 1 | 2 | 8
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var live_shooter := _get_live_shooter()
	if live_shooter is CollisionObject2D:
		query.exclude = [(live_shooter as CollisionObject2D).get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var collider := hit.get("collider") as Node
		if collider == null or collider.get_instance_id() == shooter_instance_id or collider.is_in_group(&"world_weapon_pickups"):
			continue
		var collider_id := collider.get_instance_id()
		if hit_enemies.has(collider_id):
			continue
		if collider.is_in_group(&"damageable_props"):
			hit_enemies[collider_id] = true
			collider.take_damage(damage, direction, 1.0)
		elif collider.is_in_group(&"dream_enemies"):
			hit_enemies[collider_id] = true
			if source_faction == &"enemy" and world != null and world.has_method("resolve_enemy_projectile_hit"):
				world.resolve_enemy_projectile_hit(collider, damage, origin, shooter_instance_id, &"katana")
			elif source_faction != &"enemy" and world != null:
				world.resolve_player_hit(collider, damage, origin)
		elif collider.is_in_group(&"dream_player") and source_faction == &"enemy":
			hit_enemies[collider_id] = true
			collider.receive_damage(damage, &"employee_katana_wave", origin)


func _get_live_shooter() -> Node2D:
	if shooter_instance_id <= 0 or not is_instance_id_valid(shooter_instance_id):
		return null
	return instance_from_id(shooter_instance_id) as Node2D


func _draw() -> void:
	# 月牙高度随 wave_width 联动，保持宽度按帧原始比例缩放，旋转已由 setup 对准飞行方向。
	var frame_size := WAVE_TEXTURE.get_size()
	var height := maxf(wave_width * 1.6, 20.0)
	var width := height * frame_size.x / frame_size.y
	draw_texture_rect(WAVE_TEXTURE, Rect2(-width * 0.35, -height * 0.5, width, height), false)
