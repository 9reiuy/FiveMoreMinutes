class_name BlackBloodEffect
extends Node2D

var wall_collision_mask: int = 1
## Sequential droplet rays share only their query object, never hit results.
var _airborne_wall_query: PhysicsRayQueryParameters2D
var _pool_circle_query: PhysicsShapeQueryParameters2D
var _pool_circle_shape: CircleShape2D
var ground_bounds_local := Rect2()
var ground_bounds_enabled := false
## The 3D office uses its complete floor footprint instead of a source-room
## rectangle. The old 2D Dream never supplies this context.
var ground_sampling_scale := 1.0

## 血迹落地形态图章类型（微图章系统）
enum StampType {
	CORE_SPLAT = 0,    ## 主冲击斑：不规则十字/聚团块，有机肉质核心
	SATELLITE_DOT = 1, ## 卫星拖尾溅点：细碎随机落点 (1x1 ~ 2x2)
	WALL_DRIP = 2,     ## 墙面流淌泪痕：沿重力向下的下坠细线与末端滴珠
	STANDARD_DROP = 3, ## 标准 2x2 血滴
	PIXEL_CELL = 4     ## 地面血泊的固定世界像素格
}

var ground_pixels: Array[Vector2] = []
var ground_pixel_types: Array[int] = []
var airborne_pixels: Array[Dictionary] = []
var ballistic_death_spray := false
var landed_death_droplets := 0
const DEATH_SPRAY_GRAVITY := 680.0
const DEATH_SPRAY_DRAG := 96.0
const DEATH_SPRAY_MAX_DROPLETS := 96
# Mixed low/descending, level and higher arcs. Close drops hit first;
# distant drops follow without a common flight time or flattening timer.
const DEATH_SPRAY_FLIGHT_BANDS := [
	{"height":Vector2(4.0,8.0), "vertical":Vector2(-65.0,-20.0), "distance":Vector2(12.0,30.0)},
	{"height":Vector2(8.0,14.0), "vertical":Vector2(-10.0,20.0), "distance":Vector2(24.0,50.0)},
	{"height":Vector2(12.0,20.0), "vertical":Vector2(10.0,45.0), "distance":Vector2(35.0,70.0)},
	{"height":Vector2(16.0,26.0), "vertical":Vector2(30.0,70.0), "distance":Vector2(45.0,80.0)}
]
const DEATH_SPRAY_SPLASH_RADIUS_RANGE := Vector2(1.5,4.0)
const DEATH_SPRAY_LARGE_SPLASH_RANGE := Vector2(5.0,7.5)

var elapsed: float = 0.0
var settle_seconds: float = 0.22
var lifetime_seconds: float = 15.0
const FADE_DURATION := 2.0
var settled: bool = false
var pool_growth_active: bool = false
var pool_growth_elapsed: float = 0.0
var pool_growth_duration: float = 0.0
var pool_min_scale: float = 1.0
var pool_max_scale: float = 1.0
var ground_visual_scale: float = 1.0
## Only the 3D office opts into a stronger first-frame wound blot. The old
## 2D Dream keeps its existing splat topology and timing.
var office_impact_blot := false
var office_pool_core := false
var _pool_growth_cells: Array[Vector2] = []
var _pool_growth_cursor := 0
var _pool_cell_arrivals := PackedFloat32Array()
var _static_merge_notified := false
const MAX_POOL_CELLS := 8192
const POOL_VISIBILITY_BLOCK_SIZE := 16.0
## Former radial morphology retained only for explicit comparison fixtures.
const POOL_SATELLITE_CLUSTERS := 90
const POOL_BOUNDARY_SAMPLES := 512
const POOL_EDGE_REACH := 1.55
const IMPACT_OUTER_FAN := 0.85
## Full-size deposits arrive independently; no radial reveal or stamp scaling.
const POOL_DEPOSIT_EDGE_SAMPLES := 64
var _pool_capture_elapsed := 0.0
var fade_started: bool = false
var fade_tween: Tween

# The normal 2D DreamWorld lets this effect create a child WallLayer stain.
# The 3D prototype instead supplies a surface callback so the same computed
# blood pixels can be presented by a depth-tested 3D carrier without creating
# a second blood simulation.
var surface_world: Node = null
var surface_room_id: int = -1
var depth_replica := false
## 3D presentation may bind a lightweight carrier for the currently airborne
## droplets.  This is deliberately a weak reference: the carrier is only a
## visual sink and must never keep a settled blood effect alive.
var _airborne_visual_sink_ref: WeakRef = null

# 旧 2D 回退路径仍然一次血液效果最多生成一块明显墙血。
var wall_stain_spawned: bool = false

# 3D 路径允许多面墙/门同时受血：同一面（同一条边）的后续血滴
# 累加进同一块血迹，形成喷溅分布，而不是 N 个互相覆盖的整溅斑。
const MAX_WALL_STAIN_SURFACES := 3
var wall_stain_accumulators: Dictionary = {}


func _reset_runtime() -> void:
	ground_pixels.clear()
	_pool_growth_cells.clear()
	_pool_cell_arrivals.clear()
	_pool_growth_cursor = 0
	_static_merge_notified = false
	_pool_capture_elapsed = 0.0
	ground_pixel_types.clear()
	airborne_pixels.clear()
	ballistic_death_spray=false
	landed_death_droplets=0

	elapsed = 0.0
	settled = false
	pool_growth_active = false
	pool_growth_elapsed = 0.0
	pool_growth_duration = 0.0
	pool_min_scale = 1.0
	pool_max_scale = 1.0
	ground_visual_scale = 1.0
	wall_stain_spawned = false
	wall_stain_accumulators.clear()
	fade_started = false
	if is_instance_valid(fade_tween):
		fade_tween.kill()
	# 只重置透明度，保留血液当前的橙色RGB。
	self_modulate.a = 1.0


func set_surface_context(world: Node, room_id: int = -1) -> void:
	surface_world = world
	surface_room_id = room_id


## Bind/unbind the optional 3D airborne presentation sink.  The simulation
## remains entirely inside this node; the sink only receives read-only snapshots.
func bind_airborne_visual_sink(sink: Node) -> void:
	if sink == null or not is_instance_valid(sink):
		_airborne_visual_sink_ref = null
		return
	_airborne_visual_sink_ref = weakref(sink)


func unbind_airborne_visual_sink(sink: Node = null) -> void:
	if _airborne_visual_sink_ref == null:
		return
	if sink == null:
		_airborne_visual_sink_ref = null
		return
	var bound: Variant = _airborne_visual_sink_ref.get_ref()
	if bound == sink or not is_instance_valid(bound):
		_airborne_visual_sink_ref = null


func _notify_airborne_visual_sink() -> void:
	if depth_replica or _airborne_visual_sink_ref == null:
		return
	var sink: Variant = _airborne_visual_sink_ref.get_ref()
	if sink == null or not is_instance_valid(sink) or sink.is_queued_for_deletion():
		_airborne_visual_sink_ref = null
		return
	if sink.has_method("sync_from_effect"):
		sink.call("sync_from_effect", self)


## Safe read-only copy for the 3D airborne carrier.  Never expose the mutable
## simulation dictionaries: presentation code must not be able to alter
## velocity, height, landing or wall-hit decisions.
func get_airborne_visual_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for particle in airborne_pixels:
		var visible_variant: Variant = particle.get("visible", true)
		var size_variant: Variant = particle.get("size", 2.0)
		snapshot.append(
			{
				"position": Vector2(particle.get("position", Vector2.ZERO)),
				"height": maxf(float(particle.get("height", 0.0)), 0.0),
				"size": maxf(float(size_variant), 1.0),
				"visible": bool(visible_variant),
				"velocity": Vector2(particle.get("velocity", Vector2.ZERO)),
				"vertical": float(particle.get("vertical", 0.0))
			}
		)
	return snapshot


## Called by the 3D world after setup has populated the source.  The bridge is
## often created before setup so wall raycasts have a live physics world; this
## explicit revision makes the first static capture deterministic.
func notify_visual_setup_complete() -> void:
	if depth_replica:
		return
	_last_payload_signature = -1
	content_version += 1
	queue_redraw()
	_notify_airborne_visual_sink()


## Multi-surface wall staining bookkeeping. The 3D world keys stains by wall
## edge (or door leaf) and funnels every droplet that reaches the same surface
## into one accumulating stain held here.
func wall_stain_for_key(surface_key: String) -> BlackBloodEffect:
	if not wall_stain_accumulators.has(surface_key):
		return null
	var stain: BlackBloodEffect = wall_stain_accumulators[surface_key].get_ref()
	return stain if is_instance_valid(stain) else null


func can_register_wall_stain(surface_key: String) -> bool:
	return wall_stain_accumulators.has(surface_key) or wall_stain_accumulators.size() < MAX_WALL_STAIN_SURFACES


func register_wall_stain(surface_key: String, stain: BlackBloodEffect) -> bool:
	if wall_stain_accumulators.has(surface_key):
		return true
	if wall_stain_accumulators.size() >= MAX_WALL_STAIN_SURFACES:
		return false
	wall_stain_accumulators[surface_key] = weakref(stain)
	return true


func set_depth_replica(enabled: bool) -> void:
	depth_replica = enabled
	set_process(not enabled)
	set_physics_process(not enabled)


## Capture 内容版本号：载荷（地面/空中像素数量、状态位）变化时递增。
## 供 ActorDepthBridge 的静态捕获路径使用——settle 后不再每帧重绘
## SubViewport，只有新血滴/墙面冲击真正改变画面时才刷新一次。
var _last_payload_signature := -1
var content_version: int = 0


func get_capture_content_version() -> int:
	return content_version


func _ground_capture_draw_matches(source: BlackBloodEffect) -> bool:
	if ground_pixels != source.ground_pixels or ground_pixel_types != source.ground_pixel_types:
		return false
	if ground_visual_scale != source.ground_visual_scale or office_pool_core != source.office_pool_core:
		return false
	if ground_bounds_enabled != source.ground_bounds_enabled or ground_bounds_local != source.ground_bounds_local:
		return false
	if pool_growth_active != source.pool_growth_active or pool_growth_duration != source.pool_growth_duration:
		return false
	# This optional draw-time rim gate belongs to the replica, not the source.
	# Normal ground replicas have no simulation cells, but preserve it if present.
	if office_pool_core and pool_growth_active and not _pool_growth_cells.is_empty() and pool_growth_elapsed != source.pool_growth_elapsed:
		return false
	return true


## Copies the effect's already-simulated pixels into a passive SubViewport
## duplicate used by the 3D depth bridge.  No second particle simulation runs.
func copy_depth_visual_state_to(target: Node) -> void:
	var replica := target as BlackBloodEffect
	if replica == null:
		return
	var ground_only_capture := target.has_meta(&"blood_ground_only_capture") and bool(target.get_meta(&"blood_ground_only_capture", false))
	var redraw_needed := not ground_only_capture or not replica._ground_capture_draw_matches(self) or bool(get_meta(&"test_legacy_ground_redraw", false))
	if ground_only_capture and has_meta(&"test_ground_redraw_stats"):
		var stats: Dictionary = get_meta(&"test_ground_redraw_stats")
		stats.copies += 1
		stats.redraws += int(redraw_needed)
	if redraw_needed:
		replica.ground_pixels = ground_pixels.duplicate()
		replica.ground_pixel_types = ground_pixel_types.duplicate()
	# A 3D Ground Capture replica must never draw the airborne copy as a second
	# ground-plane ghost.  The direct 2D source intentionally keeps both layers.
	if ground_only_capture:
		if not replica.airborne_pixels.is_empty():
			replica.airborne_pixels.clear()
	else:
		replica.airborne_pixels = airborne_pixels.duplicate(true)
	replica.elapsed = elapsed
	replica.settled = settled
	replica.pool_growth_active = pool_growth_active
	replica.pool_growth_elapsed = pool_growth_elapsed
	replica.pool_growth_duration = pool_growth_duration
	replica.pool_min_scale = pool_min_scale
	replica.pool_max_scale = pool_max_scale
	replica.ground_visual_scale = ground_visual_scale
	replica.office_pool_core = office_pool_core
	replica.ground_bounds_local = ground_bounds_local
	replica.ground_bounds_enabled = ground_bounds_enabled
	replica.surface_world = surface_world
	replica.ground_sampling_scale = ground_sampling_scale
	replica.fade_started = fade_started
	replica.self_modulate = self_modulate
	replica.content_version = content_version
	if redraw_needed:
		replica.queue_redraw()
	# 载荷签名：像素数量或状态位变化（落地、新墙面冲击、淡出）才递增版本，
	# 让桥的静态捕获路径按需刷新一次，之后回到 UPDATE_DISABLED。
	# The 3D ground replica must not be invalidated by airborne-only changes.
	# Use the captured replica counts here so a ground-only target's signature
	# reflects only ground/wall content (while the normal 2D copy still includes
	# the source airborne count).
	var captured_airborne_count := replica.airborne_pixels.size()
	var payload := replica.ground_pixels.size() * 1000003 + captured_airborne_count * 97
	payload += (1 if fade_started else 0) * 31 + (2 if settled else 0) + int(round(self_modulate.a * 100.0))
	if payload != _last_payload_signature:
		_last_payload_signature = payload
		content_version += 1


func set_ground_bounds(bounds: Rect2) -> void:
	var local_min := to_local(bounds.position)
	var local_max := to_local(bounds.end)
	ground_bounds_local = Rect2(local_min, local_max - local_min)
	ground_bounds_enabled = ground_bounds_local.size.x > 1.0 and ground_bounds_local.size.y > 1.0


func _is_ground_world_position_valid(world_position: Vector2) -> bool:
	if surface_world != null and is_instance_valid(surface_world) and surface_world.has_method("_is_blood_ground_allowed"):
		return bool(surface_world.call("_is_blood_ground_allowed", world_position))
	if not ground_bounds_enabled:
		return true
	return ground_bounds_local.grow(-1.0).has_point(to_local(world_position))


# ============================================================
# 墙体射线
# ============================================================

func _raycast_environment(
	from_local: Vector2,
	to_local_position: Vector2
) -> Dictionary:
	if not is_inside_tree():
		return {}

	var from_world: Vector2 = to_global(
		from_local
	)

	var to_world_position: Vector2 = to_global(
		to_local_position
	)

	if (
		from_world.distance_squared_to(
			to_world_position
		)
		<= 0.001
	):
		return {}

	var query: PhysicsRayQueryParameters2D
	if bool(get_meta(&"test_legacy_airborne_ray_query", false)):
		query = PhysicsRayQueryParameters2D.create(from_world, to_world_position, wall_collision_mask)
	else:
		if _airborne_wall_query == null:
			_airborne_wall_query = PhysicsRayQueryParameters2D.new()
		query = _airborne_wall_query
		query.from = from_world
		query.to = to_world_position
		query.collision_mask = wall_collision_mask

	query.collide_with_bodies = true
	query.collide_with_areas = false

	return (
		get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)


func _find_wall_layer(
	hit: Dictionary
) -> Node2D:
	# --------------------------------------------------------
	# 第一种：
	# RayCast直接返回WallLayer或它下面的碰撞节点。
	# --------------------------------------------------------

	var collider: Object = hit.get(
		"collider",
		null
	)

	if collider is Node:
		var current: Node = collider as Node

		while current != null:
			if current.name == "WallLayer":
				return current as Node2D

			current = current.get_parent()

	# --------------------------------------------------------
	# 第二种：
	# 从当前GroundDebrisRoot向上找房间根节点。
	#
	# 房间结构：
	#
	# room_xxx
	# ├ GroundLayer
	# ├ GroundDebrisRoot
	# ├ WallLayer
	# ├ DoorLayer
	# └ YSortRoot
	# --------------------------------------------------------

	var ancestor: Node = self

	while ancestor != null:
		var candidate := ancestor.get_node_or_null(
			"WallLayer"
		) as Node2D

		if candidate != null:
			return candidate

		ancestor = ancestor.get_parent()

	return null


# ============================================================
# 直接在 WallLayer 上创建墙血
#
# 这里不再：
# - 发Signal
# - 使用Callable
# - 调DreamWorld
# - 创建WallBloodRoot
#
# 因为这里本身已经拿到了100%真实的墙体Hit。
# ============================================================

func _spawn_wall_stain_from_hit(
	hit: Dictionary,
	impact_speed: float = -1.0
) -> void:
	if hit.is_empty():
		return

	var hit_position: Vector2 = hit.get(
		"position",
		global_position
	)

	var hit_normal: Vector2 = hit.get(
		"normal",
		Vector2.ZERO
	)

	if hit_normal.length_squared() <= 0.001:
		return

	var safe_normal: Vector2 = hit_normal.normalized()

	# A 3D environment has no WallLayer Node2D to parent the old stain to.
	# Hand the exact collision point, normal, impact speed and THIS effect to
	# the world bridge: it accumulates same-wall droplets into one stain per
	# surface (wall edge or swinging door leaf) and creates it on first hit.
	var is_3d_surface := true
	if surface_world != null and is_instance_valid(surface_world) and surface_world.has_method("is_wall_blood_surface_collider"):
		is_3d_surface = bool(surface_world.call("is_wall_blood_surface_collider", hit.get("collider")))
	if is_3d_surface and surface_world != null and is_instance_valid(surface_world) and surface_world.has_method("spawn_wall_blood_from_hit"):
		surface_world.call("spawn_wall_blood_from_hit", hit_position, safe_normal, surface_room_id, self, impact_speed)
		return

	if (
		surface_world != null
		and is_instance_valid(surface_world)
		and surface_world.has_method("is_blood_door_collider")
		and bool(surface_world.call("is_blood_door_collider", hit.get("collider")))
		and surface_world.has_method("spawn_door_blood_from_hit")
	):
		surface_world.call("spawn_door_blood_from_hit", hit_position, safe_normal, hit.get("collider"), self, impact_speed)
		return

	# ========================================================
	# 只允许“上墙”生成墙血（旧 2D DreamWorld 回退路径）
	#
	# 上方墙体的碰撞法线朝向房间内部，
	# 因此通常是 Vector2.DOWN：
	#
	# normal.y > 0
	#
	# 同时要求Y分量明显大于X，
	# 避免墙角斜法线误判成上墙。
	# ========================================================

	if wall_stain_spawned:
		return

	var is_top_wall: bool = (
		safe_normal.y > 0.5
		and absf(safe_normal.y) > absf(safe_normal.x)
	)

	if not is_top_wall:
		# 左墙 / 右墙 / 下墙：
		# 不生成墙血。
		#
		# 注意这里只是不生成墙血，
		# 原来的RayCast裁切仍然继续工作，
		# 所以普通血依旧不会穿出墙外。
		return

	var wall_layer := _find_wall_layer(
		hit
	)

	if wall_layer == null:
		return

	var wall_blood := BlackBloodEffect.new()

	if wall_blood == null:
		return

	wall_stain_spawned = true

	wall_blood.name = "WallBloodEffect"

	wall_layer.add_child(
		wall_blood
	)

	# 不使用高Z，避免遮住角色。
	wall_blood.z_index = 0
	wall_blood.z_as_relative = true
	wall_blood.y_sort_enabled = false

	# ========================================================
	# 空气墙碰撞线往墙体内部18像素
	# 才认定为真正的上墙视觉表面。
	# ========================================================

	const AIR_WALL_TO_VISUAL_WALL_OFFSET := 18.0

	wall_blood.global_position = (
		hit_position
		- safe_normal
		* AIR_WALL_TO_VISUAL_WALL_OFFSET
	)

	wall_blood.setup_wall_stain(
		safe_normal
	)

func _append_ground_pixel_clipped(
	target_offset: Vector2,
	stamp_type: int = StampType.STANDARD_DROP
) -> void:
	var sampling_scale := ground_sampling_scale if surface_world != null and is_instance_valid(surface_world) else 1.0
	var sampled_offset := target_offset * sampling_scale
	if ground_bounds_enabled and not _is_ground_world_position_valid(to_global(target_offset)):
		var safe_bounds := ground_bounds_local.grow(-1.0)
		var clamped_local := Vector2(
			clampf(target_offset.x, safe_bounds.position.x, safe_bounds.end.x),
			clampf(target_offset.y, safe_bounds.position.y, safe_bounds.end.y)
		)
		target_offset = clamped_local
		sampled_offset = target_offset * sampling_scale
	var hit: Dictionary = _raycast_environment(
		Vector2.ZERO,
		sampled_offset
	)

	# ========================================================
	# 没碰到空气墙：
	# 正常生成原始地面血。
	# ========================================================

	if hit.is_empty():
		if _is_ground_world_position_valid(to_global(sampled_offset)):
			ground_pixels.append(target_offset)
			ground_pixel_types.append(stamp_type)
		return

	var hit_position: Vector2 = hit.get(
		"position",
		global_position
	)

	var hit_normal: Vector2 = hit.get(
		"normal",
		Vector2.ZERO
	)

	var safe_normal: Vector2 = (
		hit_normal.normalized()
		if hit_normal.length_squared() > 0.001
		else Vector2.ZERO
	)

	# ========================================================
	# 上墙墙血仍然使用真实空气墙碰撞。
	#
	# _spawn_wall_stain_from_hit() 内部自己判断：
	# 只有上墙才真正生成墙血。
	# ========================================================

	_spawn_wall_stain_from_hit(
		hit
	)

	if safe_normal.length_squared() <= 0.001:
		var safe_local := to_local(hit_position)
		if _is_ground_world_position_valid(to_global(safe_local)):
			ground_pixels.append(safe_local / sampling_scale)
			ground_pixel_types.append(stamp_type)
		return

	# In the 3D office a closed door or solid wall is an actual boundary.
	# Do not apply the old 2D wall-penetration allowance across it.
	if surface_world != null and is_instance_valid(surface_world):
		var floor_side := to_local(hit_position + safe_normal * 2.0)
		if _is_ground_world_position_valid(to_global(floor_side)):
			ground_pixels.append(floor_side / sampling_scale)
			ground_pixel_types.append(stamp_type)
		return

	# ========================================================
	# 地面血允许进入空气墙18像素
	# ========================================================

	const GROUND_BLOOD_AIR_WALL_ALLOWANCE := 18.0

	var target_world_position: Vector2 = to_global(
		target_offset
	)

	# -normal 指向墙体内部。
	var into_wall_direction: Vector2 = (
		-safe_normal
	)

	# 计算这个血点穿过Physics空气墙以后，
	# 实际深入了多少像素。
	var penetration_depth: float = (
		target_world_position
		- hit_position
	).dot(
		into_wall_direction
	)

	# ========================================================
	# 关键：
	#
	# 只深入0～18px：
	# 保留原始血点位置。
	#
	# 这样空气墙和视觉墙面之间
	# 才真正能够出现地面血。
	# ========================================================

	if penetration_depth <= GROUND_BLOOD_AIR_WALL_ALLOWANCE:
		ground_pixels.append(
			target_offset
		)
		ground_pixel_types.append(stamp_type)
		return

	# ========================================================
	# 超过18px：
	# 才截断到真正视觉边界。
	# ========================================================

	var visual_boundary_position: Vector2 = (
		hit_position
		+ into_wall_direction
		* GROUND_BLOOD_AIR_WALL_ALLOWANCE
	)

	var safe_local := to_local(visual_boundary_position)
	if _is_ground_world_position_valid(to_global(safe_local)):
		ground_pixels.append(safe_local)
		ground_pixel_types.append(stamp_type)

func setup(
	spray_direction: Vector2,
	lethal: bool,
	random: RandomNumberGenerator = null,
	environment_collision_mask: int = 1,
	intensity: float = 1.0,
	droplet_multiplier: float = 1.0,
	speed_multiplier: float = 1.0,
	spread_multiplier: float = 1.0
) -> void:
	wall_collision_mask = environment_collision_mask

	_reset_runtime()

	var rng: RandomNumberGenerator = (
		random
		if random != null
		else RandomNumberGenerator.new()
	)

	if random == null:
		rng.randomize()

	var direction: Vector2 = (
		spray_direction.normalized()
		if spray_direction.length_squared() > 0.001
		else Vector2.RIGHT
	)
	# Death burst config is allowed to exceed the ordinary blood-intensity
	# range so the fixed dismember modifier remains observable instead of being
	# clipped back to the normal 1.8 ceiling.
	var spray_intensity: float = clampf(intensity, 0.35, 3.0)
	var safe_droplet_multiplier: float = clampf(droplet_multiplier, 0.25, 3.0)
	var safe_speed_multiplier: float = clampf(speed_multiplier, 0.25, 3.0)
	var safe_spread_multiplier: float = clampf(spread_multiplier, 0.25, 3.0)
	ballistic_death_spray=lethal and office_impact_blot and not bool(get_meta(&"test_legacy_death_spray",false))

	# ========================================================
	# 伤口附近血点
	# ========================================================

	var center_count_base: int = (
		8
		if lethal
		else 4
	)
	var center_count: int = maxi(
		1,
		int(round(float(center_count_base) * spray_intensity * (safe_droplet_multiplier if lethal else 1.0)))
	)

	for index in range(center_count):
		var angle: float = rng.randf_range(
			-PI,
			PI
		)

		var distance: float = rng.randf_range(
			0.5,
			5.0
		)

		var offset: Vector2 = (
			Vector2.RIGHT.rotated(angle)
			* distance
		)

		if not ballistic_death_spray:
			_append_ground_pixel_clipped(offset,StampType.CORE_SPLAT)
	if office_impact_blot:
		for index in range(14):
			var blot_angle := rng.randf_range(-PI, PI)
			var blot_distance := rng.randf_range(0.5, 8.0)
			if not ballistic_death_spray:
				_append_ground_pixel_clipped(Vector2.RIGHT.rotated(blot_angle)*blot_distance,StampType.CORE_SPLAT)

	# ========================================================
	# 地面方向性喷血
	# ========================================================

	var ground_spray_count_base: int = (
		26
		if lethal
		else 13
	)
	var ground_spray_count: int = maxi(
		1,
		int(round(float(ground_spray_count_base) * spray_intensity * (safe_droplet_multiplier if lethal else 1.0)))
	)
	var spray_angle_limit: float = 0.22 * (safe_spread_multiplier if lethal else 1.0)
	var organic_impact := office_impact_blot and not bool(get_meta(&"test_legacy_otxo_morphology", false))

	for index in range(ground_spray_count):
		var spray_angle: float = rng.randf_range(
			-spray_angle_limit,
			spray_angle_limit
		)
		# Retain a dominant wound direction, with a smaller wide satellite fan.
		if organic_impact and index % 3 == 0:
			spray_angle *= IMPACT_OUTER_FAN / maxf(spray_angle_limit, 0.01)

		var max_ground_distance: float = (58.0 if lethal else 36.0) * (0.85 + spray_intensity * 0.15)
		var distance: float = rng.randf_range(
			4.0,
			max_ground_distance
		)

		var offset: Vector2 = (
			direction.rotated(
				spray_angle
			)
			* distance
		)

		offset += Vector2(
			rng.randf_range(
				-1.5,
				1.5
			),
			rng.randf_range(
				-1.5,
				1.5
			)
		)

		var spray_stamp := StampType.CORE_SPLAT if distance < 14.0 else StampType.SATELLITE_DOT
		if not ballistic_death_spray:
			_append_ground_pixel_clipped(offset,spray_stamp)

	# ========================================================
	# 空中血滴
	# ========================================================

	var airborne_count_base: int = (
		20
		if lethal
		else 10
	)
	var airborne_count: int = maxi(
		1,
		int(round(float(airborne_count_base) * spray_intensity * (safe_droplet_multiplier if lethal else 1.0)))
	)

	for index in range(airborne_count):
		var particle_direction: Vector2 = (
			direction.rotated(
				rng.randf_range(
					-0.18,
					0.18
				)
			)
		)

		var min_speed: float = (260.0 if lethal else 170.0) * (0.9 + spray_intensity * 0.1) * (safe_speed_multiplier if lethal else 1.0)
		var max_speed: float = (520.0 if lethal else 340.0) * (0.9 + spray_intensity * 0.1) * (safe_speed_multiplier if lethal else 1.0)
		var velocity: Vector2 = particle_direction * rng.randf_range(min_speed, max_speed)

		airborne_pixels.append(
			{
				"position": Vector2.ZERO,
				"velocity": velocity,
				"height": rng.randf_range(
					4.0,
					12.0
				),
				"vertical": rng.randf_range(
					38.0,
					80.0
				)
			}
		)

	if ballistic_death_spray:
		_setup_ballistic_death_spray(rng,direction,airborne_count+ground_spray_count,safe_speed_multiplier,safe_spread_multiplier)
	queue_redraw()


func _setup_ballistic_death_spray(random: RandomNumberGenerator, direction: Vector2, count: int, speed_multiplier: float, spread_multiplier: float) -> void:
	# Preserve the legacy caller RNG advance. Cosmetic payload uses a copy.
	var rng := RandomNumberGenerator.new()
	rng.state=random.state
	ground_pixels.clear(); ground_pixel_types.clear(); airborne_pixels.clear()
	for index in mini(count,DEATH_SPRAY_MAX_DROPLETS):
		var angle := rng.randf_range(-0.85,0.85)*clampf(spread_multiplier/1.55,0.7,1.3)
		if index%5==0: angle=rng.randf_range(-PI,PI)
		var travel_direction := direction.rotated(angle)
		var band: Dictionary=DEATH_SPRAY_FLIGHT_BANDS[index%DEATH_SPRAY_FLIGHT_BANDS.size()]
		var height := rng.randf_range(band.height.x,band.height.y)
		var vertical := rng.randf_range(band.vertical.x,band.vertical.y)
		var flight_time := (vertical+sqrt(vertical*vertical+2.0*DEATH_SPRAY_GRAVITY*height))/DEATH_SPRAY_GRAVITY
		var distance := clampf(rng.randf_range(band.distance.x,band.distance.y)*clampf(speed_multiplier/1.45,0.75,1.3),12.0,94.0)
		var speed := distance/flight_time+DEATH_SPRAY_DRAG*flight_time*0.5
		airborne_pixels.append({"position":Vector2.ZERO,"velocity":travel_direction*speed,
			"height":height,"vertical":vertical,"size":rng.randf_range(2.0,3.5) if index%4==0 else rng.randf_range(1.0,2.0),
			"splash_radius":rng.randf_range(DEATH_SPRAY_LARGE_SPLASH_RANGE.x,DEATH_SPRAY_LARGE_SPLASH_RANGE.y) if index%5==0 else rng.randf_range(DEATH_SPRAY_SPLASH_RADIUS_RANGE.x,DEATH_SPRAY_SPLASH_RADIUS_RANGE.y),
			"splash_seed":rng.randi(),"particle_id":index})
	settled=airborne_pixels.is_empty()


func _land_ballistic_droplet(particle: Dictionary, block_cache: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed=int(particle.splash_seed)
	var radius: float=particle.splash_radius
	var velocity: Vector2=particle.velocity
	var patch := {"center":particle.position,"radii":Vector2(radius,radius*rng.randf_range(0.65,1.05)),"angle":velocity.angle(),"arrival":0.0}
	var occupied := {}
	for cell in ground_pixels: occupied[cell]=true
	_rasterize_pool_deposit(patch,rng,occupied,block_cache,false,true)
	landed_death_droplets+=1


# ============================================================
# 受伤移动拖痕
# ============================================================

## Overlapping floor strokes along accumulated real corpse displacement.
## Longitudinal grooves and torn edges form a smear, not a dotted trail.
func setup_drag_smear(
	random: RandomNumberGenerator,
	environment_collision_mask: int,
	world_start: Vector2,
	world_end: Vector2,
	intensity: float = 1.0,
	width_pixels: float = 4.0
) -> void:
	wall_collision_mask = environment_collision_mask
	_reset_runtime()
	ground_sampling_scale = 1.0
	var start := to_local(world_start)
	var finish := to_local(world_end)
	var movement := finish - start
	var length := movement.length()
	if length > 0.001 and length <= 48.0:
		var rng := random if random != null else RandomNumberGenerator.new()
		if random == null:
			rng.randomize()
		var direction := movement / length
		var side := direction.orthogonal()
		var half_width := clampf(width_pixels*0.5,0.5,12.0)*clampf(sqrt(maxf(intensity,0.0)),0.72,1.0)
		# Global path phase keeps grooves continuous across independently spawned segments.
		var phase := 0.63
		var path_origin := world_start.dot(direction)
		var visited: Dictionary = {}
		for row in ceili(length) + 1:
			var along := minf(float(row), length)
			var path_distance := path_origin+along
			var row_width := maxf(0.5,half_width*(0.76+sin(path_distance*0.17+phase)*0.16+sin(path_distance*0.59+phase)*0.12))
			var lobe := half_width*0.4*pow(maxf(0.0,sin(path_distance*0.19+0.9)),3.0)
			var left_width := row_width+lobe
			for column in range(-ceili(left_width), ceili(row_width) + 1):
				if (column<0 and -float(column)>left_width) or (column>=0 and float(column)>row_width):
					continue
				# Two long, uneven grooves survive single-pixel-gap consolidation.
				if half_width>=3.5 and (absf(float(column)-half_width*0.28)<1.1 or absf(float(column)+half_width*0.58)<1.1) and sin(path_distance*0.13+phase)>-0.65:
					continue
				var point := (start + direction * along + side * float(column)).round()
				var world_point := to_global(point)
				var edge_hash := (int(world_point.x)*374761393+int(world_point.y)*668265263)&0x7fffffff
				if absf(float(column))>half_width*0.62 and edge_hash%5==0: continue
				if visited.has(point):
					continue
				visited[point] = true
				# Smears stay on the floor: a closed door/wall clips them rather
				# than manufacturing a wall spray or leaking into another room.
				if _is_ground_world_position_valid(to_global(point)) and _raycast_environment(start, point).is_empty():
					ground_pixels.append(point)
					ground_pixel_types.append(StampType.PIXEL_CELL)
	settled = true
	_enter_static_presentation()
	queue_redraw()


func setup_trail(
	random: RandomNumberGenerator = null,
	environment_collision_mask: int = 1,
	intensity: float = 1.0,
	spray_direction: Vector2 = Vector2.ZERO,
	airborne_count: int = 0
) -> void:
	wall_collision_mask = environment_collision_mask

	_reset_runtime()

	var rng: RandomNumberGenerator = (
		random
		if random != null
		else RandomNumberGenerator.new()
	)

	if random == null:
		rng.randomize()

	var trail_intensity := clampf(intensity, 0.35, 1.5)
	var count: int = clampi(
		int(round(float(rng.randi_range(4, 7)) * trail_intensity)),
		2,
		12
	)
	var direction := (
		spray_direction.normalized()
		if spray_direction.length_squared() > 0.001
		else Vector2.ZERO
	)
	var airborne_direction := direction if direction.length_squared() > 0.001 else Vector2.RIGHT
	var safe_airborne_count := clampi(airborne_count, 0, count)

	for index in range(count):
		var angle: float = rng.randf_range(
			-PI,
			PI
		)

		var distance: float = rng.randf_range(
			0.5,
			5.5
		)

		var offset: Vector2 = (
			Vector2.RIGHT.rotated(angle)
			* distance
		)

		offset.y *= 0.65

		offset += Vector2(
			rng.randf_range(
				-0.8,
				0.8
			),
			rng.randf_range(
				-0.5,
				0.5
			)
		)
		if direction.length_squared() > 0.001:
			offset += direction * rng.randf_range(0.0, 4.0 * trail_intensity)

		if index < safe_airborne_count:
			var particle_direction := airborne_direction.rotated(rng.randf_range(-0.28, 0.28))
			var particle_speed := rng.randf_range(65.0, 120.0) * (0.75 + trail_intensity * 0.25)
			airborne_pixels.append(
				{
					"position": offset,
					"velocity": particle_direction * particle_speed,
					"height": rng.randf_range(1.5, 4.0),
					"vertical": rng.randf_range(12.0, 24.0),
					"size": 2.0,
					"visible": true
				}
			)
		else:
			var trail_stamp := StampType.CORE_SPLAT if index % 2 == 0 else StampType.SATELLITE_DOT
			_append_ground_pixel_clipped(offset, trail_stamp)

	settled = airborne_pixels.is_empty()
	if settled:
		_enter_static_presentation()
	else:
		set_process(true)
	queue_redraw()
	_notify_airborne_visual_sink()


# ============================================================
# 死亡大血泊
# ============================================================

func setup_death_pool(
	random: RandomNumberGenerator = null,
	environment_collision_mask: int = 1,
	intensity: float = 1.0,
	growth_duration: float = 0.45,
	min_scale: float = 0.35,
	max_scale: float = 1.0,
	deposit_direction: Vector2 = Vector2.ZERO
) -> void:
	wall_collision_mask = environment_collision_mask

	_reset_runtime()

	var rng: RandomNumberGenerator = (
		random
		if random != null
		else RandomNumberGenerator.new()
	)

	if random == null:
		rng.randomize()

	var pool_intensity := clampf(intensity, 0.35, 3.0)
	var count: int = clampi(
		int(round(float(rng.randi_range(90, 125)) * pool_intensity)),
		28,
		200
	)

	# 多频角向扰动函数（Noise Distorted Boundary）：
	# 模拟阿米巴变形虫（Amoeba-like）的不规则伪足与液面张力
	var phase_lobe := rng.randf_range(0.0, TAU)
	var phase_sub := rng.randf_range(0.0, TAU)
	var phase_micro := rng.randf_range(0.0, TAU)
	var primary_lobes := float(rng.randi_range(3, 5))

	for index in range(count):
		# Office occupancy replaces the old sampled core. Only retain a small
		# satellite seed set; clipping is performed once by the block cache.
		if office_pool_core and index >= 24:
			break
		var angle: float = rng.randf_range(
			-PI,
			PI
		)

		var lobe_wave := sin(angle * primary_lobes + phase_lobe) * 0.32
		var sub_wave := cos(angle * 2.0 + phase_sub) * 0.16
		var micro_wave := sin(angle * 7.0 + phase_micro) * 0.08
		var organic_factor := clampf(1.0 + lobe_wave + sub_wave + micro_wave, 0.48, 1.55)

		var max_radius_at_angle := 26.0 * organic_factor

		var distance_ratio: float = rng.randf()
		# 70% 集中在中内部形成实心有机血斑，30% 落在边缘形成犬牙交错的毛刺伪足
		if rng.randf() < 0.70:
			distance_ratio = distance_ratio * distance_ratio
		else:
			distance_ratio = lerpf(0.60, 1.0, distance_ratio)

		var distance: float = lerpf(
			0.5,
			max_radius_at_angle,
			distance_ratio
		)

		var offset: Vector2 = (
			Vector2.RIGHT.rotated(angle)
			* distance
		)

		offset.y *= 0.62

		offset += Vector2(
			rng.randf_range(
				-2.0,
				2.0
			),
			rng.randf_range(
				-1.5,
				1.5
			)
		)

		var pool_stamp := StampType.CORE_SPLAT if distance_ratio < 0.72 else StampType.SATELLITE_DOT
		if office_pool_core:
			if pool_stamp == StampType.SATELLITE_DOT:
				ground_pixels.append(offset)
				ground_pixel_types.append(pool_stamp)
		else:
			_append_ground_pixel_clipped(offset, pool_stamp)

	pool_growth_duration = maxf(growth_duration, 0.0)
	pool_growth_elapsed = 0.0
	var scale_limit := 3.0 if office_pool_core else 2.0
	pool_min_scale = clampf(min_scale, 0.1, scale_limit)
	pool_max_scale = maxf(clampf(max_scale, 0.1, scale_limit), pool_min_scale)
	ground_visual_scale = pool_min_scale if pool_growth_duration > 0.0 else pool_max_scale
	pool_growth_active = pool_growth_duration > 0.0 and pool_max_scale > pool_min_scale
	if office_pool_core:
		_setup_pixel_pool(phase_lobe, phase_sub, phase_micro, primary_lobes, rng, pool_intensity, deposit_direction)
	settled = true
	if not pool_growth_active:
		_enter_static_presentation()
	queue_redraw()


## Office deposits use fixed one-pixel cells. The former radial reveal below
## is selected only by explicit comparison metadata.
func _setup_pixel_pool(phase: float, sub_phase: float, micro_phase: float, lobes: float, rng: RandomNumberGenerator = null, intensity: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	var block_cache := _new_blood_cell_query_cache()
	var satellite_cells: Array[Vector2] = []
	for i in ground_pixels.size():
		if ground_pixel_types[i] == StampType.SATELLITE_DOT:
			satellite_cells.append((ground_pixels[i] * pool_max_scale).round())
	ground_pixels.clear()
	ground_pixel_types.clear()
	ground_visual_scale = 1.0
	ground_sampling_scale = 1.0
	if not bool(get_meta(&"test_legacy_otxo_morphology", false)) and not bool(get_meta(&"test_radial_pool_reveal", false)):
		_setup_deposited_pool(rng, intensity, direction, block_cache)
		return
	var organic := not bool(get_meta(&"test_legacy_otxo_morphology", false))
	var radius := minf(26.0 * pool_max_scale, 54.0)
	if organic:
		# Blood amount varies the footprint, without scaling individual pixels.
		radius *= clampf(sqrt(intensity / 1.7), 0.72, 1.12)
	var edge_reach := POOL_EDGE_REACH if organic else 1.45
	var extent := mini(int(ceil(radius * edge_reach)), 100)
	var height_extent := int(ceil(radius * edge_reach * 0.62))
	var maximum_radius_squared := pow(radius * edge_reach, 2.0)
	var boundaries := PackedFloat32Array()
	if organic:
		# Cache angular shape once; avoid multiple trigonometric calls per cell.
		for index in POOL_BOUNDARY_SAMPLES:
			var angle := float(index) * TAU / POOL_BOUNDARY_SAMPLES
			var jagged := sin(angle * 19.0 + micro_phase) * sin(angle * 31.0 + sub_phase) * 0.085
			var notch := pow(maxf(0.0, cos(angle * 3.0 + sub_phase)), 10.0) * 0.18
			# Unequal lobes and a broad one-sided spill avoid a regular star/flower.
			boundaries.append(clampf(0.98 + sin(angle * lobes + phase) * 0.17 + cos(angle + sub_phase) * 0.13 + cos(angle * 2.0 + micro_phase) * 0.10 + jagged - notch, 0.48, edge_reach))
	var entire_pool_safe := false
	if block_cache.has(&"query_batch") and is_inside_tree() and is_instance_valid(surface_world) and surface_world.has_method("_is_blood_ground_block_allowed"):
		# Include the outer droplets in the shortcut's proof, not just the core.
		var pool_margin := radius * (1.85 if organic else 1.45) + 4.0
		var p_corners := [
			to_global(Vector2(-pool_margin, -pool_margin * 0.62)),
			to_global(Vector2(pool_margin, -pool_margin * 0.62)),
			to_global(Vector2(pool_margin, pool_margin * 0.62)),
			to_global(Vector2(-pool_margin, pool_margin * 0.62))
		]
		var pool_bounds := Rect2(p_corners[0], Vector2.ZERO)
		for p in p_corners:
			pool_bounds = pool_bounds.expand(p)
		if bool(surface_world.call("_is_blood_ground_block_allowed", pool_bounds)):
			if _pool_circle_query == null:
				_pool_circle_query = PhysicsShapeQueryParameters2D.new()
				_pool_circle_shape = CircleShape2D.new()
				_pool_circle_query.shape = _pool_circle_shape
				_pool_circle_query.collide_with_areas = false
				_pool_circle_query.collide_with_bodies = true
			_pool_circle_shape.radius = pool_margin
			_pool_circle_query.transform = Transform2D(0.0, global_position)
			_pool_circle_query.collision_mask = wall_collision_mask
			if get_world_2d().direct_space_state.intersect_shape(_pool_circle_query, 1).is_empty():
				entire_pool_safe = true
	for y in range(-height_extent, height_extent + 1):
		var ry := float(y) / 0.62
		var ry_sq := ry * ry
		for x in range(-extent, extent + 1):
			var rx := float(x)
			var rad_len_sq := rx * rx + ry_sq
			if rad_len_sq > maximum_radius_squared:
				continue
			var radial := Vector2(rx, ry)
			var angle := radial.angle()
			var boundary: float
			if organic:
				boundary = boundaries[posmod(int(round(angle * POOL_BOUNDARY_SAMPLES / TAU)), POOL_BOUNDARY_SAMPLES)]
			else:
				boundary = clampf(1.0 + sin(angle * lobes + phase) * 0.24 + cos(angle * 2.0 + sub_phase) * 0.12 + sin(angle * 7.0 + micro_phase) * 0.05, 0.55, 1.45)
			var bound := radius * boundary
			if rad_len_sq > bound * bound:
				continue
			var cell := Vector2(rx, float(y))
			if not entire_pool_safe and not _is_pool_cell_allowed(cell, block_cache):
				continue
			_pool_growth_cells.append(cell)
			if _pool_growth_cells.size() >= MAX_POOL_CELLS:
				break
		if _pool_growth_cells.size() >= MAX_POOL_CELLS:
			break
	if organic and rng != null:
		# Separate islands mix single droplets and small jagged clusters. Their
		# empty gaps remain visible instead of being filled by the growing core.
		# Cosmetic detail must not advance the world's content/loot RNG.
		var satellite_rng := RandomNumberGenerator.new()
		satellite_rng.state = rng.state
		for index in POOL_SATELLITE_CLUSTERS:
			var angle := satellite_rng.randf_range(0.0, TAU)
			var boundary := boundaries[posmod(int(round(angle * POOL_BOUNDARY_SAMPLES / TAU)), POOL_BOUNDARY_SAMPLES)]
			var distance := radius * maxf(boundary + 0.12, satellite_rng.randf_range(1.15, 1.8))
			var center := Vector2(cos(angle) * distance, sin(angle) * distance * 0.62).round()
			var size := satellite_rng.randi_range(1, 3) if index % 3 == 0 else 0
			for y in range(-size, size + 1):
				for x in range(-size, size + 1):
					if x*x + y*y > size*size + 1: continue
					var cell := center + Vector2(x, y)
					if absf(cell.x) < 100.0 and absf(cell.y) < 100.0:
						satellite_cells.append(cell)
	# Keep sparse pre-sampled edge droplets so the final silhouette retains its
	# impact texture instead of becoming a uniformly filled smooth oval.
	var occupied: Dictionary = {}
	for cell in _pool_growth_cells: occupied[cell] = true
	for cell in satellite_cells:
		if _pool_growth_cells.size() >= MAX_POOL_CELLS:
			break
		if occupied.has(cell) or absf(cell.x) >= 100.0 or absf(cell.y) >= 100.0:
			continue
		if entire_pool_safe or _is_pool_cell_allowed(cell, block_cache):
			_pool_growth_cells.append(cell)
			occupied[cell] = true
	# Bucket shells avoid tens of thousands of interpreted comparator calls
	# while keeping the same centre-to-edge reveal on the fixed pixel grid.
	var rings: Dictionary = {}
	for cell in _pool_growth_cells:
		var ring := int(Vector2(cell.x, cell.y / 0.62).length_squared() / 16.0)
		if not rings.has(ring):
			rings[ring] = []
		rings[ring].append(cell)
	var ring_keys := rings.keys()
	ring_keys.sort()
	_pool_growth_cells.clear()
	for ring in ring_keys:
		_pool_growth_cells.append_array(rings[ring])
	_reveal_pixel_pool(0.0 if pool_growth_active else 1.0)

## Bake small, independent irregular deposits in arrival order. Each deposit
## appears at its final position and footprint; existing blood never moves.
## Only a few wound-adjacent patches arrive after the short initial splash.
func _new_blood_cell_query_cache() -> Dictionary:
	# One synchronous operation/frame only; never retain results across doors
	# or floor changes. Overrides keep their original per-cell validators.
	var cache := {}
	if get_script().get_global_name()==&"BlackBloodEffect" and is_inside_tree() and is_instance_valid(surface_world) and surface_world.has_method("_begin_blood_ground_query_batch"):
		var context: Dictionary=surface_world.call("_begin_blood_ground_query_batch")
		if not context.is_empty():
			context[&"transform"]=global_transform
			context[&"ray_space"]=get_world_2d().direct_space_state
			var ray := PhysicsRayQueryParameters2D.create(global_position,global_position,wall_collision_mask)
			ray.collide_with_bodies=true; ray.collide_with_areas=false
			context[&"ray"]=ray; cache[&"query_batch"]=context
	return cache


func _setup_deposited_pool(random: RandomNumberGenerator, intensity: float, direction: Vector2, block_cache: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	if random != null:
		rng.state = random.state
	else:
		rng.seed = 73013
	var footprint := clampf(pool_max_scale / 2.05, 0.35, 1.45) * clampf(sqrt(intensity / 1.7), 0.75, 1.22)
	var spill_angle := direction.angle() if direction.length_squared() > 0.001 else rng.randf_range(-PI, PI)
	var patches: Array[Dictionary] = []
	# Unequal overlapping deposits leave a small wound mass, not a giant disk.
	for spec in [
		[Vector2(-2, 1), Vector2(14, 11), 0.0],
		[Vector2(-11, -2), Vector2(10, 8), 0.08],
		[Vector2(7, 5), Vector2(8, 6), 0.11],
		[Vector2(10, -7), Vector2(7, 5), 0.15]
	]:
		patches.append({"center": (spec[0] as Vector2).rotated(spill_angle) * footprint,
			"radii": (spec[1] as Vector2) * footprint, "angle": spill_angle + rng.randf_range(-0.4, 0.4), "arrival": float(spec[2])})
	# Only wound-adjacent seepage belongs to this floor-only effect. Remote
	# splashes now come exclusively from actual airborne droplet touchdowns.
	# Late seepage is local and sparse; it cannot uncover an outer radial rim.
	for index in 3:
		patches.append({"center": Vector2(-15.0 + index * 13.0, 7.0 if index % 2 == 0 else -8.0).rotated(spill_angle) * footprint,
			"radii": Vector2(4.0, 3.0) * footprint, "angle": spill_angle,
			"arrival": 0.45 + float(index) * 0.275})
	patches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.arrival) < float(b.arrival))
	var entire_pool_safe := _deposited_pool_bounds_are_clear(block_cache)
	var occupied: Dictionary = {}
	for patch in patches:
		_rasterize_pool_deposit(patch, rng, occupied, block_cache, entire_pool_safe)
		if _pool_growth_cells.size() >= MAX_POOL_CELLS:
			break
	_reveal_pixel_pool(0.0 if pool_growth_active else 1.0)


func _deposited_pool_bounds_are_clear(block_cache: Dictionary) -> bool:
	if not block_cache.has(&"query_batch") or not is_inside_tree() or not is_instance_valid(surface_world) or not surface_world.has_method("_is_blood_ground_block_allowed"):
		return false
	var corners := PackedVector2Array()
	for point in [Vector2(-100, -100), Vector2(100, -100), Vector2(100, 100), Vector2(-100, 100)]:
		corners.append(to_global(point))
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for point in corners: bounds = bounds.expand(point)
	if not bool(surface_world.call("_is_blood_ground_block_allowed", bounds)):
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = corners
	query.shape = shape
	query.collision_mask = wall_collision_mask
	query.collide_with_areas = false
	query.margin = 0.0
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _rasterize_pool_deposit(patch: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary, block_cache: Dictionary, entire_pool_safe: bool, land_immediately: bool=false) -> void:
	if (ground_pixels.size() if land_immediately else _pool_growth_cells.size())>=MAX_POOL_CELLS: return
	var center: Vector2 = patch.center
	var radii: Vector2 = patch.radii
	var angle: float = patch.angle
	var arrival: float = patch.arrival
	var sine := sin(angle)
	var cosine := cos(angle)
	var phase := rng.randf_range(-PI, PI)
	var second_phase := rng.randf_range(-PI, PI)
	var boundaries := PackedFloat32Array()
	for index in POOL_DEPOSIT_EDGE_SAMPLES:
		var edge_angle := float(index) * TAU / POOL_DEPOSIT_EDGE_SAMPLES
		boundaries.append(1.0 + sin(edge_angle * 3.0 + phase) * 0.20 + sin(edge_angle * 7.0 + second_phase) * 0.12 + cos(edge_angle * 11.0 + phase) * 0.07)
	var reach := radii.length() * 1.4 + 1.0
	var first_x := maxi(-99, floori(center.x - reach))
	var last_x := mini(99, ceili(center.x + reach))
	var first_y := maxi(-99, floori(center.y - reach))
	var last_y := mini(99, ceili(center.y + reach))
	for y in range(first_y, last_y + 1):
		for x in range(first_x, last_x + 1):
			var dx := float(x) - center.x
			var dy := float(y) - center.y
			var local := Vector2((dx * cosine + dy * sine) / maxf(radii.x, 0.5), (-dx * sine + dy * cosine) / maxf(radii.y, 0.5))
			var distance_squared := local.length_squared()
			if distance_squared > 1.96: continue
			var boundary := boundaries[posmod(int(round(local.angle() * POOL_DEPOSIT_EDGE_SAMPLES / TAU)), POOL_DEPOSIT_EDGE_SAMPLES)]
			if distance_squared > boundary * boundary: continue
			# Uneven nicks and voids at each splash edge, never an alpha gradient.
			var hash_value := (x * 374761393 + y * 668265263 + int(phase * 1000.0)) & 0x7fffffff
			if distance_squared > 0.65 and hash_value % 7 == 0: continue
			var cell := Vector2(x, y)
			if occupied.has(cell): continue
			if not entire_pool_safe and not _is_pool_cell_allowed(cell, block_cache): continue
			occupied[cell] = true
			if land_immediately:
				ground_pixels.append(cell); ground_pixel_types.append(StampType.PIXEL_CELL)
			else:
				_pool_growth_cells.append(cell); _pool_cell_arrivals.append(arrival)
			if (ground_pixels.size() if land_immediately else _pool_growth_cells.size())>=MAX_POOL_CELLS: return


## Cache only provably safe blocks for this setup call. The convex query
## covers every segment from the source to the block, including thin walls
## between corner rays. Border blocks retain the original per-pixel checks.
func _is_pool_cell_allowed(cell: Vector2, block_cache: Dictionary) -> bool:
	var has_batch := block_cache.has(&"query_batch")
	if is_inside_tree() and is_instance_valid(surface_world) and surface_world.has_method("_is_blood_ground_block_allowed"):
		var block := Vector2i(floori(cell.x / POOL_VISIBILITY_BLOCK_SIZE), floori(cell.y / POOL_VISIBILITY_BLOCK_SIZE))
		if not block_cache.has(block):
			var base := Vector2(block) * POOL_VISIBILITY_BLOCK_SIZE
			var corners := PackedVector2Array()
			for offset in [Vector2.ZERO, Vector2(POOL_VISIBILITY_BLOCK_SIZE, 0), Vector2.ONE * POOL_VISIBILITY_BLOCK_SIZE, Vector2(0, POOL_VISIBILITY_BLOCK_SIZE)]:
				corners.append(to_global(base + offset))
			var bounds := Rect2(corners[0], Vector2.ZERO)
			for point in corners:
				bounds = bounds.expand(point)
			var status: int = 0
			if has_batch:
				var ctx: Dictionary = block_cache[&"query_batch"]
				var fl_cells: Dictionary = ctx[&"floor"]
				var c_size: float = ctx[&"cell_size"]
				var f_cell := Vector2i(roundi(bounds.position.x / c_size), roundi(bounds.position.y / c_size))
				var l_cell := Vector2i(roundi(bounds.end.x / c_size), roundi(bounds.end.y / c_size))
				var any_floor := false
				var all_floor := true
				for fy in range(f_cell.y, l_cell.y + 1):
					for fx in range(f_cell.x, l_cell.x + 1):
						if fl_cells.has(Vector2i(fx, fy)):
							any_floor = true
						else:
							all_floor = false
				if not any_floor:
					status = -1
				else:
					corners.append(global_position)
					var shape: ConvexPolygonShape2D = block_cache.get(&"_reusable_convex")
					var query: PhysicsShapeQueryParameters2D = block_cache.get(&"_reusable_query")
					if query == null:
						shape = ConvexPolygonShape2D.new()
						query = PhysicsShapeQueryParameters2D.new()
						query.shape = shape
						query.collision_mask = wall_collision_mask
						query.collide_with_areas = false
						query.margin = 0.0
						block_cache[&"_reusable_convex"] = shape
						block_cache[&"_reusable_query"] = query
					shape.points = Geometry2D.convex_hull(corners)
					if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
						status = 1 if all_floor else 2
				block_cache[block] = status
			else:
				var safe := bool(surface_world.call("_is_blood_ground_block_allowed", bounds))
				if safe:
					corners.append(global_position)
					var shape: ConvexPolygonShape2D = block_cache.get(&"_reusable_convex")
					var query: PhysicsShapeQueryParameters2D = block_cache.get(&"_reusable_query")
					if query == null:
						shape = ConvexPolygonShape2D.new()
						query = PhysicsShapeQueryParameters2D.new()
						query.shape = shape
						query.collision_mask = wall_collision_mask
						query.collide_with_areas = false
						query.margin = 0.0
						block_cache[&"_reusable_convex"] = shape
						block_cache[&"_reusable_query"] = query
					shape.points = Geometry2D.convex_hull(corners)
					safe = get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
				block_cache[block] = safe
		var cached_val: Variant = block_cache[block]
		var block_status: int = (1 if bool(cached_val) else 0) if cached_val is bool else int(cached_val)
		if block_status == 1:
			return true
		if block_status == -1:
			return false
		if has_batch:
			var context: Dictionary = block_cache[&"query_batch"]
			var transform_snapshot: Transform2D = context[&"transform"]
			var point := transform_snapshot * cell
			var cells: Dictionary = context[&"floor"]
			var cell_size: float = context[&"cell_size"]
			if not cells.has(Vector2i(roundi(point.x / cell_size), roundi(point.y / cell_size))):
				return false
			if block_status == 2:
				return true
			var ray: PhysicsRayQueryParameters2D = context[&"ray"]
			if ray.from.distance_squared_to(point) > 0.001:
				ray.to = point
				var ray_space: PhysicsDirectSpaceState2D = context[&"ray_space"]
				if not ray_space.intersect_ray(ray).is_empty():
					return false
			var point_query: PhysicsPointQueryParameters2D = context[&"point"]
			point_query.position = point
			var point_space: PhysicsDirectSpaceState2D = context[&"point_space"]
			return point_space.intersect_point(point_query, 1).is_empty()
	if has_batch:
		var context: Dictionary = block_cache[&"query_batch"]
		var transform_snapshot: Transform2D = context[&"transform"]
		var point := transform_snapshot * cell
		var cells: Dictionary = context[&"floor"]
		var cell_size: float = context[&"cell_size"]
		if not cells.has(Vector2i(roundi(point.x/cell_size),roundi(point.y/cell_size))): return false
		var point_query: PhysicsPointQueryParameters2D = context[&"point"]
		point_query.position = point
		var point_space: PhysicsDirectSpaceState2D = context[&"point_space"]
		if not point_space.intersect_point(point_query,1).is_empty(): return false
		var ray: PhysicsRayQueryParameters2D = context[&"ray"]
		if ray.from.distance_squared_to(point) <= 0.001: return true
		ray.to = point
		var ray_space: PhysicsDirectSpaceState2D = context[&"ray_space"]
		return ray_space.intersect_ray(ray).is_empty()
	return _is_ground_world_position_valid(to_global(cell)) and _raycast_environment(Vector2.ZERO, cell).is_empty()


func _reveal_pixel_pool(progress: float) -> void:
	if not _pool_cell_arrivals.is_empty():
		while _pool_growth_cursor < _pool_growth_cells.size() and _pool_cell_arrivals[_pool_growth_cursor] <= progress + 0.00001:
			ground_pixels.append(_pool_growth_cells[_pool_growth_cursor])
			ground_pixel_types.append(StampType.PIXEL_CELL)
			_pool_growth_cursor += 1
		return
	var fraction := lerpf(pow(pool_min_scale / maxf(pool_max_scale, 0.001), 2.0), 1.0, progress)
	var target_count := mini(int(ceil(_pool_growth_cells.size() * fraction)), _pool_growth_cells.size())
	while _pool_growth_cursor < target_count:
		ground_pixels.append(_pool_growth_cells[_pool_growth_cursor])
		ground_pixel_types.append(StampType.PIXEL_CELL)
		_pool_growth_cursor += 1


# ============================================================
# 墙面血迹
# ============================================================

func setup_wall_stain(
	wall_normal: Vector2,
	random: RandomNumberGenerator = null,
	impact_speed: float = -1.0
) -> void:
	_reset_runtime()

	var rng: RandomNumberGenerator = (
		random
		if random != null
		else RandomNumberGenerator.new()
	)

	if random == null:
		rng.randomize()

	var normal: Vector2 = (
		wall_normal.normalized()
		if wall_normal.length_squared() > 0.001
		else Vector2.RIGHT
	)

	# local X = normal方向
	# local Y = 沿墙方向
	rotation = normal.angle()

	# ========================================================
	# 撞击信息继承（§20）：
	# 高速喷血 → 墙面更大更密的喷溅；
	# 低速滴血 → 只留下小血点。
	# 旧调用（未传速度）保持原有尺寸。
	# ========================================================

	var speed_scale := 1.0
	if impact_speed >= 0.0:
		speed_scale = clampf(impact_speed / 150.0, 0.3, 1.5)

	# ========================================================
	# 墙面主体血迹
	#
	# 此处的原点已经是：
	# 空气墙 - 18px 后的真正视觉墙面。
	# ========================================================

	var count: int = maxi(
		int(round(float(rng.randi_range(65, 90)) * speed_scale)),
		10
	)

	for index in range(count):
		var along_wall: float = rng.randf_range(
			-14.0,
			14.0
		) * speed_scale

		# 从真正墙面向墙内部再深入少量距离。
		var into_wall: float = rng.randf_range(
			-12.0,
			1.0
		) * speed_scale

		var density: float = rng.randf_range(
			0.35,
			1.0
		)

		ground_pixels.append(
			Vector2(
				into_wall,
				along_wall * density
			)
		)
		ground_pixel_types.append(StampType.SATELLITE_DOT)

	# 撞击中心浓血。
	var dense_count: int = maxi(
		int(round(24.0 * speed_scale)),
		4
	)

	for index in range(dense_count):
		ground_pixels.append(
			Vector2(
				rng.randf_range(
					-6.0,
					1.0
				) * speed_scale,
				rng.randf_range(
					-6.0,
					6.0
				) * speed_scale
			)
		)
		ground_pixel_types.append(StampType.CORE_SPLAT)

	# 墙面流淌泪痕（Wall Drip）：沿重力向下的下坠细线与末端滴珠
	var drip_count: int = maxi(
		int(round(float(rng.randi_range(3, 6)) * speed_scale)),
		1
	)
	for index in range(drip_count):
		var drip_into := rng.randf_range(-5.0, 0.5) * speed_scale
		var drip_along := rng.randf_range(-8.0, 8.0) * speed_scale
		ground_pixels.append(
			Vector2(drip_into, drip_along)
		)
		ground_pixel_types.append(StampType.WALL_DRIP)

	settled = true
	_enter_static_presentation()
	queue_redraw()


## 同一面墙的后续血滴撞上已有血迹：沿墙扩展这一块血迹，
## 而不是再叠一整块新溅斑。像素使用 setup_wall_stain 的同一局部坐标系：
## local X = 向墙内（normal 轴），local Y = 沿墙（tangent 轴）。
func is_visual_settled() -> bool:
	# 桥冻结条件与 _enter_static_presentation 一致：视觉真正静止
	# （settled 且无空中血滴）才算 settled。
	return settled and airborne_pixels.is_empty() and not pool_growth_active


## Rasterize the exact ground stamps before combining them. Both effects use
## the same world pixel grid; removing an overlapping stamp cannot erase blood.
func _ground_cells_in_target(effect: BlackBloodEffect) -> Dictionary:
	var cells: Dictionary = {}
	# Snapshot only for this synchronous rasterization, keeping the original
	# two transform operations (not a precomposed matrix) before pixel rounding.
	var source_transform := effect.global_transform
	var target_inverse := global_transform.affine_inverse()
	var uncached := bool(get_meta(&"test_uncached_ground_transforms", false))
	var compact_pixels := not bool(get_meta(&"test_legacy_ground_merge", false))
	for i in effect.ground_pixels.size():
		var p: Vector2 = (effect.ground_pixels[i] * effect.ground_visual_scale).round()
		var stamp: int = effect.ground_pixel_types[i] if i < effect.ground_pixel_types.size() else StampType.STANDARD_DROP
		if stamp == StampType.PIXEL_CELL and compact_pixels:
			# The existing compact floor atlas is already one pixel per stamp.
			# Keep both transforms and the exact rounding order, without allocating
			# a one-element offset array for every settled pixel.
			var cell := to_local(effect.to_global(p)).round() if uncached else (target_inverse * (source_transform * p)).round()
			cells[cell] = true
			continue
		var offsets: Array[Vector2] = []
		var h := (int(p.x) * 374761393 + int(p.y) * 668265263) & 0x7fffffff
		match stamp:
			StampType.PIXEL_CELL:
				offsets.append(Vector2.ZERO)
			StampType.CORE_SPLAT:
				for y in range(-1, 2):
					for x in range(-1, 2):
						offsets.append(Vector2(x, y))
				for bit in 4:
					if h & (1 << bit):
						offsets.append([Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)][bit])
			StampType.SATELLITE_DOT:
				offsets.append(Vector2.ZERO)
				if h % 3 == 1:
					offsets.append(Vector2.RIGHT)
				elif h % 3 == 2:
					offsets.append(Vector2.DOWN)
			StampType.WALL_DRIP:
				return {} # Vertical stains must never enter a floor atlas.
			_:
				offsets.assign([Vector2(-1, -1), Vector2(0, -1), Vector2(-1, 0), Vector2.ZERO])
		for offset in offsets:
			var cell := to_local(effect.to_global(p + offset)).round() if uncached else (target_inverse * (source_transform * (p + offset))).round()
			cells[cell] = true
	return cells


func can_absorb_ground_effect(other: BlackBloodEffect, extent: float = 108.0) -> bool:
	return not _prepare_ground_merge(other, extent).is_empty()


## A synchronous operation-local result, never cached across frames. Door,
## transform, scale and content changes are read again at every merge attempt.
func _prepare_ground_merge(other: BlackBloodEffect, extent: float) -> Dictionary:
	if not is_instance_valid(other) or other == self or depth_replica or other.depth_replica:
		return {}
	if not bool(get_meta(&"blood_floor_visual", false)) or not bool(other.get_meta(&"blood_floor_visual", false)):
		return {}
	if surface_room_id != other.surface_room_id or not is_visual_settled() or not other.is_visual_settled() or fade_started or other.fade_started:
		return {}
	if surface_world != other.surface_world or get_meta(&"blood_floor_token", -1) != other.get_meta(&"blood_floor_token", -1):
		return {}
	if not _raycast_environment(Vector2.ZERO, to_local(other.global_position)).is_empty():
		return {}
	var cells := _ground_cells_in_target(self)
	var incoming := _ground_cells_in_target(other)
	if cells.is_empty() or incoming.is_empty():
		return {}
	for cell in incoming:
		cells[cell] = true
	if cells.size() > MAX_POOL_CELLS:
		return {}
	for cell in cells:
		if cell.x < -extent or cell.y < -extent or cell.x + 1.0 > extent or cell.y + 1.0 > extent:
			return {}
	return cells


func absorb_ground_effect(other: BlackBloodEffect, extent: float = 108.0) -> bool:
	var cells := _prepare_ground_merge(other, extent)
	if cells.is_empty():
		return false
	if bool(get_meta(&"test_legacy_ground_merge", false)):
		# Diagnostic old path: repeat the rasterization that previously followed
		# can_absorb. Normal gameplay uses only the operation-local union above.
		cells = _ground_cells_in_target(self)
		for cell in _ground_cells_in_target(other): cells[cell] = true
	# One pass closes only tiny, nearly enclosed holes, without bridging gaps.
	var candidates: Dictionary = {}
	for cell in cells:
		for step in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var candidate: Vector2 = cell + step
			if not cells.has(candidate):
				candidates[candidate] = int(candidates.get(candidate, 0)) + 1
	for cell in candidates:
		if cells.size() >= MAX_POOL_CELLS:
			break
		if candidates[cell] < 3 or absf(cell.x) >= extent or absf(cell.y) >= extent:
			continue
		if _is_ground_world_position_valid(to_global(cell)) and _raycast_environment(Vector2.ZERO, cell).is_empty():
			cells[cell] = true
	if is_equal_approx(ground_visual_scale, 1.0) and cells.size() == ground_pixels.size() and ground_pixel_types.all(func(stamp: int) -> bool: return stamp == StampType.PIXEL_CELL):
		var unchanged := true
		for cell in ground_pixels:
			if not cells.has(cell):
				unchanged = false
				break
		if unchanged:
			return true
	ground_pixels.clear()
	ground_pixel_types.clear()
	for cell in cells:
		ground_pixels.append(cell)
		ground_pixel_types.append(StampType.PIXEL_CELL)
	ground_visual_scale = 1.0
	ground_sampling_scale = 1.0
	content_version += 1
	_notify_bridge_dirty()
	queue_redraw()
	return true


## 视觉静态化：源节点停帧（append_wall_impact 负责唤醒），
## 并通知 ActorDepthBridge 冻结其完整 _process（若桥已存在）。
func _enter_static_presentation() -> void:
	# 只有"已 settled 且空中血滴全部落地"才允许进入静态表现：
	# setup 的即时墙检测可能在 stain 仍有 airborne 内容时经过 settled=true
	# 分支——冻结那种 stain 会杀死剩余血滴的飞行模拟（血滴悬空、永不落地）。
	if not settled or not airborne_pixels.is_empty() or pool_growth_active:
		return
	set_process(false)
	var reference: Variant = get_meta(&"depth_visual_bridge") if has_meta(&"depth_visual_bridge") else null
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if bridge != null and bridge.has_method("freeze_static_visual"):
		bridge.call("freeze_static_visual")
	if not depth_replica and not _static_merge_notified and bool(get_meta(&"blood_floor_visual", false)) and is_instance_valid(surface_world) and surface_world.has_method("_on_blood_effect_settled"):
		_static_merge_notified = true
		surface_world.call_deferred("_on_blood_effect_settled", weakref(self))


## 冻结后有新载荷时唤醒桥做一次同步+捕获，随后桥会自动重新冻结。
func _notify_bridge_dirty() -> void:
	var reference: Variant = get_meta(&"depth_visual_bridge") if has_meta(&"depth_visual_bridge") else null
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if bridge != null and bridge.has_method("mark_visual_dirty"):
		bridge.call("mark_visual_dirty")


func append_wall_impact(
	world_impact_position: Vector2,
	wall_normal: Vector2,
	impact_speed: float,
	random: RandomNumberGenerator = null
) -> void:
	if not settled:
		return

	var rng: RandomNumberGenerator = (
		random
		if random != null
		else RandomNumberGenerator.new()
	)

	if random == null:
		rng.randomize()

	var normal: Vector2 = (
		wall_normal.normalized()
		if wall_normal.length_squared() > 0.001
		else Vector2.RIGHT
	)

	var offset := world_impact_position - global_position
	var along_wall := offset.dot(Vector2(-normal.y, normal.x))

	var speed_scale := 1.0
	if impact_speed >= 0.0:
		speed_scale = clampf(impact_speed / 150.0, 0.3, 1.5)

	var count: int = clampi(
		int(round(rng.randf_range(7.0, 14.0) * speed_scale)),
		3,
		24
	)

	var added_any := false
	for index in range(count):
		var px := Vector2(
			rng.randf_range(-5.0, 1.0) * speed_scale,
			along_wall + rng.randf_range(-6.0, 6.0) * (0.5 + speed_scale * 0.5)
		)
		if ground_pixels.size() < 240:
			ground_pixels.append(px)
			ground_pixel_types.append(StampType.SATELLITE_DOT)
			added_any = true

	var dense_count: int = clampi(
		int(round(5.0 * speed_scale)),
		1,
		10
	)

	for index in range(dense_count):
		var px := Vector2(
			rng.randf_range(-2.0, 1.0),
			along_wall + rng.randf_range(-2.0, 2.0)
		)
		if ground_pixels.size() < 240:
			ground_pixels.append(px)
			ground_pixel_types.append(StampType.CORE_SPLAT)
			added_any = true

	var drip_count: int = clampi(int(round(1.5 * speed_scale)), 1, 3)
	for index in range(drip_count):
		var px := Vector2(
			rng.randf_range(-2.5, 0.5) * speed_scale,
			along_wall + rng.randf_range(-5.0, 5.0)
		)
		if ground_pixels.size() < 240:
			ground_pixels.append(px)
			ground_pixel_types.append(StampType.WALL_DRIP)
			added_any = true

	if added_any:
		queue_redraw()
		# 冻结后有新载荷：唤醒桥做一次同步+捕获再重新冻结（血迹永久累积支持）。
		_notify_bridge_dirty()

func _process(delta: float) -> void:
	elapsed += delta

	if pool_growth_active:
		pool_growth_elapsed += delta
		_pool_capture_elapsed += delta
		var growth_t := clampf(
			pool_growth_elapsed / maxf(pool_growth_duration, 0.001),
			0.0,
			1.0
		)
		# Deposits use their arrival times, never the old expanding radial gate.
		var eased_t := growth_t if not _pool_cell_arrivals.is_empty() else (1.0 - pow(1.0 - growth_t, 3.0) if office_pool_core else growth_t * growth_t * (3.0 - 2.0 * growth_t))
		var previous_count := ground_pixels.size()
		if office_pool_core:
			if _pool_capture_elapsed >= 1.0 / 30.0 or growth_t >= 1.0:
				_reveal_pixel_pool(eased_t)
				_pool_capture_elapsed = 0.0
		else:
			ground_visual_scale = lerpf(pool_min_scale, pool_max_scale, eased_t)
		# The 3D bridge uses the effect's content version in its static-capture
		# signature.  A growing pool is still one effect, but each scale step must
		# invalidate that capture so the passive replica follows the same growth.
		if not office_pool_core or previous_count != ground_pixels.size():
			content_version += 1
			_notify_bridge_dirty()
			queue_redraw()
		if growth_t >= 1.0:
			pool_growth_active = false
			ground_visual_scale = 1.0 if office_pool_core else pool_max_scale
			_pool_growth_cells.clear()
			_pool_cell_arrivals.clear()
			_enter_static_presentation()
		_notify_airborne_visual_sink()
		return

	if not settled:
		var previous_ground_count := ground_pixels.size()
		var surviving_particles: Array[Dictionary] = []
		var landing_cache: Dictionary = {}
		var landing_cache_started := false

		for particle in airborne_pixels:
			var current_position: Vector2 = particle.get(
				"position",
				Vector2.ZERO
			)

			var velocity: Vector2 = particle.get(
				"velocity",
				Vector2.ZERO
			)

			var movement_delta := delta
			var ballistic_height := float(particle.get("height",0.0))
			var ballistic_vertical := float(particle.get("vertical",0.0))
			var touching_down := false
			if ballistic_death_spray:
				var touchdown_time := (ballistic_vertical+sqrt(ballistic_vertical*ballistic_vertical+2.0*DEATH_SPRAY_GRAVITY*maxf(ballistic_height,0.0)))/DEATH_SPRAY_GRAVITY
				touching_down=touchdown_time<=delta
				movement_delta=minf(delta,maxf(touchdown_time,0.0))
			var next_position := current_position+velocity*movement_delta

			# ====================================================
			# 空中血滴撞墙（先于地面边界裁切）
			#
			# 表面检测必须用“未裁切”的下一步位置：
			# 血滴飞向墙 → 真正撞上墙 → 生成墙血并结束。
			# 不能先被房间边界弹回再落地，否则墙永远不会被命中，
			# 血滴也会穿过墙体落到隔壁房间的地面上。
			# ====================================================

			var wall_hit: Dictionary = _raycast_environment(
				current_position,
				next_position
			)

			if not wall_hit.is_empty():
				_spawn_wall_stain_from_hit(
					wall_hit,
					velocity.length()
				)

				# 血滴撞墙后结束。
				continue

			# Actual walls were checked above. Stop droplets at the floor outline,
			# while allowing them to pass through a valid open doorway.
			if not _is_ground_world_position_valid(to_global(next_position)):
				if surface_world != null and is_instance_valid(surface_world) and not ground_bounds_enabled:
					# Stop at the last real floor pixel, not at a room rectangle.
					var safe_position := current_position
					var unsafe_position := next_position
					for _step in range(7):
						var midpoint := (safe_position + unsafe_position) * 0.5
						if _is_ground_world_position_valid(to_global(midpoint)):
							safe_position = midpoint
						else:
							unsafe_position = midpoint
					next_position = safe_position
					velocity = Vector2.ZERO
				else:
					var safe_bounds := ground_bounds_local.grow(-1.0)
					var local_next := next_position
					var boundary_normal := Vector2.ZERO
					if local_next.x < safe_bounds.position.x:
						local_next.x = safe_bounds.position.x
						boundary_normal.x = 1.0
					elif local_next.x > safe_bounds.end.x:
						local_next.x = safe_bounds.end.x
						boundary_normal.x = -1.0
					if local_next.y < safe_bounds.position.y:
						local_next.y = safe_bounds.position.y
						boundary_normal.y = 1.0
					elif local_next.y > safe_bounds.end.y:
						local_next.y = safe_bounds.end.y
						boundary_normal.y = -1.0
					next_position = local_next
					if boundary_normal != Vector2.ZERO and velocity.dot(boundary_normal) < 0.0:
						velocity = velocity.bounce(boundary_normal) * 0.2

			particle["position"] = next_position

			particle["velocity"] = velocity.move_toward(
				Vector2.ZERO,
				(DEATH_SPRAY_DRAG if ballistic_death_spray else 320.0)*movement_delta
			)

			var height: float = float(
				particle.get(
					"height",
					0.0
				)
			)

			var vertical_velocity: float = float(
				particle.get(
					"vertical",
					0.0
				)
			)

			if ballistic_death_spray:
				height=maxf(0.0,height+vertical_velocity*movement_delta-0.5*DEATH_SPRAY_GRAVITY*movement_delta*movement_delta)
				vertical_velocity-=DEATH_SPRAY_GRAVITY*movement_delta
			else:
				height=maxf(0.0,height+vertical_velocity*delta)
				vertical_velocity-=300.0*delta

			particle["height"] = height
			particle["vertical"] = vertical_velocity
			if ballistic_death_spray and touching_down:
				if not landing_cache_started:
					landing_cache=_new_blood_cell_query_cache(); landing_cache_started=true
				_land_ballistic_droplet(particle,landing_cache)
				continue

			surviving_particles.append(
				particle
			)

		airborne_pixels = surviving_particles

		# ====================================================
		# 空中血最终落地
		# ====================================================

		if ballistic_death_spray:
			settled=airborne_pixels.is_empty()
		elif elapsed >= settle_seconds:
			for particle in airborne_pixels:
				var landing_position: Vector2 = (
					particle.get(
						"position",
						Vector2.ZERO
					)
				)
				var landing_speed: float = (particle.get("velocity", Vector2.ZERO) as Vector2).length()
				var landing_stamp := StampType.CORE_SPLAT if landing_speed > 90.0 else StampType.SATELLITE_DOT
				_append_ground_pixel_clipped(
					landing_position,
					landing_stamp
				)

			airborne_pixels.clear()
			settled = true
		if ground_pixels.size()!=previous_ground_count:
			# Static ground captures may sleep while all droplets are airborne.
			# Wake once per simulation frame with real new ground content, before
			# the final merge; otherwise every touchdown appears together at rest.
			content_version+=1
			_notify_bridge_dirty()
	_enter_static_presentation()

	# ========================================================
	# 血迹在本场 Dream 内永久保留：不按时间渐隐、不自动释放。
	# 只有换日 regenerate（_clear_generated_building）或场景销毁会清除它们；
	# _begin_fade_out 仅保留为显式 API，正常流程不再触发。
	# ========================================================

	queue_redraw()
	_notify_airborne_visual_sink()


func _begin_fade_out() -> void:
	if fade_started:
		return

	fade_started = true
	var duration := clampf(
		lifetime_seconds - elapsed,
		0.05,
		FADE_DURATION
	)
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_LINEAR)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(self, "self_modulate:a", 0.0, duration)
	fade_tween.tween_callback(Callable(self, "queue_free"))


# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var ground_color := Color(
		"d96b18"
	)

	var total_pixels := ground_pixels.size()
	var legacy_pixel_hash := bool(get_meta(&"test_legacy_pixel_draw_hash",false))
	for i in range(total_pixels):
		var pixel := ground_pixels[i]
		if office_pool_core and pool_growth_active and not _pool_growth_cells.is_empty() and ground_pixel_types[i] != StampType.PIXEL_CELL:
			# The earliest frame is already a broad connected stain; reveal the
			# sparse outer rim over time rather than magnifying every dot at once.
			var reveal_t := clampf(pool_growth_elapsed / maxf(pool_growth_duration, 0.001), 0.0, 1.0)
			var edge_ease := 1.0 - pow(1.0 - reveal_t, 3.0)
			if pixel.length() > lerpf(10.0, 44.0, edge_ease):
				continue
		var scaled_pixel := pixel * ground_visual_scale
		if office_pool_core and ground_bounds_enabled and not ground_bounds_local.grow(-1.0).has_point(scaled_pixel):
			continue
		var p := scaled_pixel.round()
		var stamp := ground_pixel_types[i] if i < ground_pixel_types.size() else StampType.STANDARD_DROP
		# Exact one-pixel cells do not use the deterministic shape hash below.
		# Keep the same position, colour and native draw command; skip only unused
		# integer work for dense settled/merged 3D stains.
		if stamp==StampType.PIXEL_CELL and not legacy_pixel_hash:
			draw_rect(Rect2(p,Vector2.ONE),ground_color)
			continue

		# 伪随机确定性哈希（根据像素坐标产生固定的形态扰动，重绘无闪烁）
		var h := (int(p.x) * 374761393 + int(p.y) * 668265263) & 0x7fffffff

		match stamp:
			StampType.PIXEL_CELL:
				draw_rect(Rect2(p, Vector2.ONE), ground_color)
			StampType.CORE_SPLAT:
				# 主冲击斑：中心 3x3 团块 + 随机突触伪足
				draw_rect(Rect2(p - Vector2.ONE, Vector2(3.0, 3.0)), ground_color)
				if (h & 1) != 0:
					draw_rect(Rect2(p + Vector2(2.0, 0.0), Vector2(1.0, 1.0)), ground_color)
				if (h & 2) != 0:
					draw_rect(Rect2(p - Vector2(2.0, 0.0), Vector2(1.0, 1.0)), ground_color)
				if (h & 4) != 0:
					draw_rect(Rect2(p + Vector2(0.0, 2.0), Vector2(1.0, 1.0)), ground_color)
				if (h & 8) != 0:
					draw_rect(Rect2(p - Vector2(0.0, 2.0), Vector2(1.0, 1.0)), ground_color)

			StampType.SATELLITE_DOT:
				# 卫星拖尾溅点：细碎随机微点 (1x1 ~ 2x1/1x2)
				var mode := h % 3
				if mode == 0:
					draw_rect(Rect2(p, Vector2(1.0, 1.0)), ground_color)
				elif mode == 1:
					draw_rect(Rect2(p, Vector2(2.0, 1.0)), ground_color)
				else:
					draw_rect(Rect2(p, Vector2(1.0, 2.0)), ground_color)

			StampType.WALL_DRIP:
				# 墙面流淌泪痕：沿重力向下的下坠流淌泪痕 (长 4~8 像素垂线 + 底部滴珠)
				var drip_len := 4.0 + float(h % 5)
				var drip_end := p + Vector2(0.0, drip_len)
				draw_line(p, drip_end, ground_color, 1.5)
				draw_rect(Rect2(drip_end.round() - Vector2(0.5, 0.0), Vector2(2.0, 2.0)), ground_color)

			_:
				# 标准血滴斑 (2x2)
				draw_rect(
					Rect2(
						p - Vector2.ONE,
						Vector2(2.0, 2.0)
					),
					ground_color
				)

	var airborne_color := Color(
		"ff9a2e"
	)

	for particle in airborne_pixels:
		var height: float = float(
			particle.get(
				"height",
				0.0
			)
		)

		var position: Vector2 = particle.get(
			"position",
			Vector2.ZERO
		)

		var velocity: Vector2 = particle.get(
			"velocity",
			Vector2.ZERO
		)

		var vertical: float = float(
			particle.get(
				"vertical",
				0.0
			)
		)

		var point: Vector2 = (
			position
			+ Vector2(
				0.0,
				-height
			)
		)

		# 2D 投影屏幕速度矢量（水平飞行速度 + 垂直重力升降带来的 Y 轴位移）
		var screen_vel := velocity + Vector2(0.0, -vertical)
		var speed := screen_vel.length()

		if speed > 18.0:
			# 空中血滴速度拉伸线（Velocity Streaks）
			var streak_len := clampf(speed * 0.034, 3.0, 13.0)
			var streak_dir := screen_vel.normalized()
			var tail := point - streak_dir * streak_len
			draw_line(tail.round(), point.round(), airborne_color, 1.8)
			draw_rect(
				Rect2(
					point.round() - Vector2.ONE,
					Vector2(2.0, 2.0)
				),
				airborne_color
			)
		else:
			draw_rect(
				Rect2(
					point.round()
						- Vector2.ONE,
					Vector2(
						2.0,
						2.0
					)
				),
				airborne_color
			)
