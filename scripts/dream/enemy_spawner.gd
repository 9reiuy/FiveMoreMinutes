extends Node

signal spawn_requested(spawn_position: Vector2, health_multiplier: float, damage_multiplier: float, enemy_type: String)

@export var config: DemoConfig

var running := true
var alarm_active := false
var alarm_elapsed := 0.0
var accumulator := 0.0
var current_dream_minutes := 240.0
var arena_bounds := Rect2(28, 48, 584, 274)
var random := RandomNumberGenerator.new()
var player: Node2D
var run_elapsed_seconds := 0.0
var stress_spawn_multiplier := 1.0
var endless_mode := false
var difficulty_day := 1


func _ready() -> void:
	random.randomize()
	current_dream_minutes = config.dream_start_minutes
	accumulator = get_current_spawn_interval()


func _process(delta: float) -> void:
	if not running:
		return
	var current_count := get_tree().get_nodes_in_group("dream_enemies").size()
	if current_count >= config.maximum_enemies:
		return
	accumulator -= delta
	if accumulator > 0.0:
		return
	accumulator = get_current_spawn_interval()
	var health_multiplier := get_health_multiplier()
	var damage_multiplier := get_damage_multiplier()
	var batch_count := mini(maxi(1, config.enemy_spawn_count_per_interval), config.maximum_enemies - current_count)
	var reserved_positions: Array[Vector2] = []
	for _spawn_index in range(batch_count):
		var spawn_position: Variant = _find_valid_spawn_position(reserved_positions)
		if spawn_position != null:
			reserved_positions.append(spawn_position)
			spawn_requested.emit(spawn_position, health_multiplier, damage_multiplier, _choose_enemy_type())


func set_run_elapsed(seconds: float) -> void:
	run_elapsed_seconds = maxf(0.0, seconds)


func set_difficulty_day(day: int) -> void:
	difficulty_day = maxi(day, 1)
	accumulator = minf(accumulator, get_current_spawn_interval())


func set_stress_spawn_multiplier(multiplier: float) -> void:
	stress_spawn_multiplier = maxf(1.0, multiplier)
	accumulator = minf(accumulator, get_current_spawn_interval())


func _choose_enemy_type() -> String:
	var pool := get_unlocked_enemy_types()
	var total_weight := 0.0
	for enemy_id in pool:
		total_weight += maxf(0.0, float(config.enemy_base_spawn_weights.get(enemy_id, 1.0)))
	if total_weight <= 0.0:
		return pool[0]
	var roll := random.randf_range(0.0, total_weight)
	for enemy_id in pool:
		roll -= maxf(0.0, float(config.enemy_base_spawn_weights.get(enemy_id, 1.0)))
		if roll <= 0.0:
			return enemy_id
	return pool.back()


func get_unlocked_enemy_types() -> Array[String]:
	var pool: Array[String] = []
	for enemy_id in ["basic", "correction", "stapler", "alarm_clock", "mailbox"]:
		if difficulty_day >= get_enemy_unlock_day(enemy_id):
			pool.append(enemy_id)
	if pool.is_empty():
		pool.append("basic")
	return pool


func get_enemy_unlock_day(enemy_id: String) -> int:
	return maxi(1, int(config.enemy_unlock_days.get(enemy_id, 999999)))


func get_difficulty_stage_seconds(for_day: int = -1) -> float:
	var day := difficulty_day if for_day < 1 else for_day
	return float(maxi(day - 1, 0)) * maxf(config.difficulty_seconds_per_day, 0.0)


func get_health_multiplier(for_day: int = -1) -> float:
	return 1.0 + get_difficulty_stage_seconds(for_day) * config.enemy_health_growth_per_second


func get_damage_multiplier(for_day: int = -1) -> float:
	return 1.0 + get_difficulty_stage_seconds(for_day) * config.enemy_damage_growth_per_second


func request_valid_spawn_position() -> Variant:
	return _find_valid_spawn_position([])


func set_alarm_state(active: bool, elapsed_seconds: float) -> void:
	alarm_active = active
	alarm_elapsed = maxf(0.0, elapsed_seconds)


func set_dream_time(total_minutes: float) -> void:
	current_dream_minutes = total_minutes


func get_current_spawn_interval() -> float:
	# 保留旧线性lerp曲线：一天等价于旧曲线的一个完整阶段；达到正式最小间隔后继续由硬下限保护。
	var progress := clampf(float(difficulty_day - 1), 0.0, 1.0)
	var interval := lerpf(config.enemy_initial_spawn_interval, config.enemy_minimum_spawn_interval, progress)
	var stress_adjusted := interval / maxf(stress_spawn_multiplier, 1.0)
	return maxf(stress_adjusted, config.stress_absolute_minimum_spawn_interval)


func _find_valid_spawn_position(reserved_positions: Array[Vector2] = []) -> Variant:
	if not is_instance_valid(player):
		return null
	# 屏幕外环带策略：候选点在场地内随机，必须落在相机可见矩形外扩
	# enemy_spawn_visibility_margin 的禁区之外；重试有限次，失败则跳过
	# 该只敌人，绝不回退到玩家脚下/屏幕中央或无限循环。
	var forbidden_rect := _get_forbidden_spawn_rect()
	for _attempt in range(maxi(1, config.enemy_spawn_position_max_retries)):
		var candidate := _random_arena_position()
		if forbidden_rect.has_point(candidate):
			continue
		if _is_spawn_position_valid(candidate, reserved_positions):
			return candidate
	return null


## 生成禁区：dream_world 相机可见矩形 + 安全边距；取不到相机信息时
## 退化为以玩家为中心的可见尺寸估计（viewport 640×360），仍保证屏外。
func _get_forbidden_spawn_rect() -> Rect2:
	var margin := config.enemy_spawn_visibility_margin
	var dream_world := get_tree().get_first_node_in_group("dream_world")
	if dream_world != null and dream_world.has_method("get_camera_visible_world_rect"):
		return dream_world.get_camera_visible_world_rect().grow(margin)
	return Rect2(player.global_position - Vector2(320, 180), Vector2(640, 360)).grow(margin)


func _is_spawn_position_valid(candidate: Vector2, reserved_positions: Array[Vector2]) -> bool:
	if not arena_bounds.has_point(candidate):
		return false
	if candidate.distance_to(player.global_position) < config.enemy_minimum_spawn_distance:
		return false
	for enemy in get_tree().get_nodes_in_group("dream_enemies"):
		if is_instance_valid(enemy) and candidate.distance_to(enemy.global_position) < config.enemy_spawn_minimum_spacing:
			return false
	for reserved in reserved_positions:
		if candidate.distance_to(reserved) < config.enemy_spawn_minimum_spacing:
			return false
	return true


func _random_arena_position() -> Vector2:
	return Vector2(random.randf_range(arena_bounds.position.x, arena_bounds.end.x), random.randf_range(arena_bounds.position.y, arena_bounds.end.y))
