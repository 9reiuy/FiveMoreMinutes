extends Node

## 触手怪生成器：每 tentacle_spawn_interval 秒尝试一批（1~5 只），全图上限 tentacle_max_alive。
## 使用 _process 的 delta 累加：自动跟随 Engine.time_scale（快睡 1.5x），
## 暂停（get_tree().paused）时处理停止，即完全属于梦境时间体系，不使用真实时间。

signal tentacle_spawn_requested(spawn_position: Vector2)

@export var config: DemoConfig

var running := true
var accumulator := 0.0
var arena_bounds := Rect2(24, 24, 992, 432)
var player: Node2D
var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.randomize()
	accumulator = maxf(config.tentacle_spawn_interval, 0.1) if config != null else 30.0


func _process(delta: float) -> void:
	if not running or config == null or not is_instance_valid(player):
		return
	accumulator -= delta
	if accumulator > 0.0:
		return
	accumulator = maxf(config.tentacle_spawn_interval, 0.1)
	var alive_count := get_tree().get_nodes_in_group("tentacle_enemies").size()
	var remaining := maxi(0, config.tentacle_max_alive - alive_count)
	var batch := mini(random.randi_range(config.tentacle_spawn_batch_min, config.tentacle_spawn_batch_max), remaining)
	var reserved: Array[Vector2] = []
	for _index in range(batch):
		var spawn_position: Variant = _find_spawn_position(reserved)
		if spawn_position == null:
			continue
		reserved.append(spawn_position)
		tentacle_spawn_requested.emit(spawn_position)


## 优先屏幕外：必须落在相机可见矩形外扩 enemy_spawn_visibility_margin 的禁区之外
## （复用 dream_world.get_camera_visible_world_rect）；找不到屏外点时退而求其次
## 只要求 ≥ tentacle_min_spawn_distance_from_player。位置限定在场地内并与已有触手保持间距。
func _find_spawn_position(reserved: Array[Vector2]) -> Variant:
	var forbidden_rect: Variant = _get_forbidden_spawn_rect()
	if forbidden_rect != null:
		var forbidden: Rect2 = forbidden_rect
		var preferred: Variant = _try_find_offscreen(30, forbidden, reserved)
		if preferred != null:
			return preferred
	return _try_find(30, config.tentacle_min_spawn_distance_from_player, reserved)


## 生成禁区：与常规怪共用 dream_world 的相机可见矩形函数；取不到时返回 null。
func _get_forbidden_spawn_rect() -> Variant:
	var dream_world := get_tree().get_first_node_in_group("dream_world")
	if dream_world == null or not dream_world.has_method("get_camera_visible_world_rect"):
		return null
	return dream_world.get_camera_visible_world_rect().grow(config.enemy_spawn_visibility_margin)


func _try_find_offscreen(attempts: int, forbidden_rect: Rect2, reserved: Array[Vector2]) -> Variant:
	var area := arena_bounds.grow(-20.0)
	for _attempt in range(maxi(1, attempts)):
		var candidate := Vector2(random.randf_range(area.position.x, area.end.x), random.randf_range(area.position.y, area.end.y))
		if forbidden_rect.has_point(candidate):
			continue
		if candidate.distance_to(player.global_position) < config.tentacle_min_spawn_distance_from_player:
			continue
		if not _has_spacing(candidate, reserved):
			continue
		return candidate
	return null


func _try_find(attempts: int, min_player_distance: float, reserved: Array[Vector2]) -> Variant:
	var area := arena_bounds.grow(-20.0)
	for _attempt in range(maxi(1, attempts)):
		var candidate := Vector2(random.randf_range(area.position.x, area.end.x), random.randf_range(area.position.y, area.end.y))
		if candidate.distance_to(player.global_position) < min_player_distance:
			continue
		if not _has_spacing(candidate, reserved):
			continue
		return candidate
	return null


func _has_spacing(candidate: Vector2, reserved: Array[Vector2]) -> bool:
	for tentacle in get_tree().get_nodes_in_group("tentacle_enemies"):
		if is_instance_valid(tentacle) and candidate.distance_to(tentacle.global_position) < 34.0:
			return false
	for position in reserved:
		if candidate.distance_to(position) < 34.0:
			return false
	return true
