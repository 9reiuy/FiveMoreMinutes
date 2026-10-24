class_name EnemyBodyPart
extends CharacterBody2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")

## Employee死亡后的完整身体部件残骸。
## 地面Root使用CharacterBody2D碰撞，Sprite只通过fake_height表现2.5D高度。
const CONFIG := preload("res://resources/demo_config.tres")
const WORLD_COLLISION_MASK := (1 << 0) | (1 << 2)

@onready var visual: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Body parts are intentionally short-lived: they keep their physical burst
## but fade during the same ~0.8 s window instead of lingering as corpses.
## 总生命周期约0.8秒；仅在最后0.2秒渐隐，保证飞散/落地阶段仍清晰可见。
const TOTAL_LIFETIME := 0.8
const FADE_DURATION := 0.2

var horizontal_velocity := Vector2.ZERO
var fake_height := 0.0
var vertical_velocity := 0.0
var gravity := 420.0
var air_drag := 55.0
var ground_drag := 180.0
var wall_bounce_retention := 0.68
var ground_vertical_retention := 0.48
var ground_horizontal_retention := 0.74
var minimum_bounce_velocity := 18.0
var settle_speed := 14.0
var lifetime_left := TOTAL_LIFETIME
var angular_velocity := 0.0
var settled := false
var room_bounds := Rect2()
var _last_wall_normal := Vector2.ZERO
var _last_wall_hit_time := -10.0
var fade_started := false
var fade_tween: Tween
var _bleed_world: WeakRef
var _bleed_room_id := -1
var _bleed_floor_token := -1
var _bleed_pulses_left := 0
var _bleed_interval_left := 0.0
const GROUND_BLEED_INTERVAL := 0.18


func configure_ground_bleed(world: Node, source_room_id: int) -> void:
	# Existing detached parts only; never create another dismemberment path.
	if _bleed_world != null or world == null or not world.has_method("spawn_blood_trail"):
		return
	_bleed_world = weakref(world)
	_bleed_room_id = source_room_id
	if world.has_method("get_current_floor_token"):
		_bleed_floor_token = int(world.call("get_current_floor_token"))
	_bleed_pulses_left = 3
	_bleed_interval_left = GROUND_BLEED_INTERVAL
	set_process(true)


func _process(delta: float) -> void:
	if _bleed_pulses_left <= 0:
		set_process(false)
		return
	var world := _bleed_world.get_ref() as Node if _bleed_world != null else null
	if not is_instance_valid(world) or world.is_queued_for_deletion() or lifetime_left <= 0.0:
		_bleed_pulses_left = 0
		return
	if _bleed_floor_token >= 0 and int(world.call("get_current_floor_token")) != _bleed_floor_token:
		_bleed_pulses_left = 0
		return
	_bleed_interval_left -= maxf(delta, 0.0)
	if _bleed_interval_left > 0.0:
		return
	# A long frame never catches up multiple droplets at the same position.
	_bleed_interval_left = GROUND_BLEED_INTERVAL
	if world.has_method("resolve_environment_debris_room_id"):
		_bleed_room_id = int(world.call("resolve_environment_debris_room_id", global_position, _bleed_room_id))
	if _bleed_room_id < 0:
		_bleed_pulses_left = 0
		return
	world.call("spawn_blood_trail", global_position, _bleed_room_id,
		horizontal_velocity.normalized() if horizontal_velocity.length_squared() > 0.001 else Vector2.RIGHT, 0.35)
	_bleed_pulses_left -= 1


func set_room_runtime_active(active_room: bool) -> void:
	if not active_room:
		_bleed_pulses_left = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = WORLD_COLLISION_MASK
	gravity = float(CONFIG.employee_knockdown_fake_gravity)
	# 与Employee的击倒惯性使用同一组当前手感参数。
	air_drag = 55.0
	ground_drag = 180.0
	wall_bounce_retention = 0.68
	ground_vertical_retention = 0.48
	ground_horizontal_retention = 0.74
	minimum_bounce_velocity = 18.0
	settle_speed = 14.0
	set_physics_process(true)


func setup_from_sprite(
	source_sprite: Sprite2D,
	new_horizontal_velocity: Vector2,
	initial_vertical_velocity: float,
	initial_angular_velocity: float,
	initial_fake_height: float = 0.0
) -> void:
	if source_sprite == null or not is_instance_valid(source_sprite):
		return
	visual.texture_filter = source_sprite.texture_filter
	visual.texture = source_sprite.texture
	visual.centered = source_sprite.centered
	visual.offset = source_sprite.offset
	visual.flip_h = source_sprite.flip_h
	visual.flip_v = source_sprite.flip_v
	visual.region_enabled = source_sprite.region_enabled
	visual.region_rect = source_sprite.region_rect
	visual.hframes = source_sprite.hframes
	visual.vframes = source_sprite.vframes
	visual.frame = source_sprite.frame
	visual.modulate = source_sprite.modulate
	visual.self_modulate = source_sprite.self_modulate
	# Source Sprite可能正处于Employee的击倒假高度中。把它拆成
	# 地面Root位置 + 视觉fake_height，避免死亡瞬间把部件“吸”回地面，
	# 同时保留真实墙体碰撞只发生在地面Root上。
	var safe_fake_height := maxf(initial_fake_height, 0.0)
	global_position = source_sprite.global_position + Vector2(0.0, safe_fake_height).rotated(source_sprite.global_rotation)
	global_rotation = source_sprite.global_rotation
	global_scale = source_sprite.global_scale
	horizontal_velocity = new_horizontal_velocity
	vertical_velocity = maxf(initial_vertical_velocity, 0.0)
	angular_velocity = initial_angular_velocity
	fake_height = safe_fake_height
	settled = false
	lifetime_left = TOTAL_LIFETIME
	fade_started = false
	if is_instance_valid(fade_tween):
		fade_tween.kill()
	visual.position = Vector2(0.0, -fake_height)
	# The copied Sprite global position may include CharacterVisual offsets or a
	# lethal knockback frame that was just outside the wall.  Clamp the ground
	# root immediately; the visual fake height remains independent above it.
	_constrain_to_room_bounds()


func set_room_bounds(bounds: Rect2) -> void:
	# 开放门洞没有墙碰撞；死亡残骸仍限制在死亡所在房间，避免飞入相邻房间。
	room_bounds = bounds


func constrain_to_room_bounds() -> void:
	_constrain_to_room_bounds()


func _physics_process(delta: float) -> void:
	if lifetime_left > 0.0:
		lifetime_left -= delta
		if lifetime_left <= FADE_DURATION and not fade_started:
			_begin_fade_out()
		if lifetime_left <= 0.0:
			# 释放由Fade Tween的完成回调负责，避免生命周期末尾整块消失。
			return

	if settled:
		return

	if horizontal_velocity.length_squared() > 0.001:
		var collision := move_and_collide(horizontal_velocity * delta)
		if collision != null:
			var normal := collision.get_normal()
			var now := Time.get_ticks_msec() * 0.001
			# 同一墙面在极短时间内不重复翻转，避免墙边疯狂左右振荡。
			if now - _last_wall_hit_time > 0.08 or normal.dot(_last_wall_normal) < 0.95:
				horizontal_velocity = horizontal_velocity.bounce(normal) * wall_bounce_retention
				global_position += normal * 0.35
				_last_wall_normal = normal
				_last_wall_hit_time = now
		_constrain_to_room_bounds()

	var drag := air_drag if fake_height > 0.0 or vertical_velocity > 0.0 else ground_drag
	horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, drag * delta)

	vertical_velocity -= gravity * delta
	fake_height += vertical_velocity * delta
	if fake_height <= 0.0:
		var impact_speed := absf(vertical_velocity)
		fake_height = 0.0
		horizontal_velocity *= ground_horizontal_retention
		if impact_speed >= minimum_bounce_velocity:
			SFX.play_event(&"body_impact")
			vertical_velocity = impact_speed * ground_vertical_retention
		else:
			vertical_velocity = 0.0

	visual.position.y = -fake_height
	visual.rotation += angular_velocity * delta
	angular_velocity = move_toward(angular_velocity, 0.0, 3.5 * delta)

	if fake_height <= 0.0 and is_zero_approx(vertical_velocity) and horizontal_velocity.length() <= settle_speed:
		horizontal_velocity = Vector2.ZERO
		visual.position.y = 0.0
		settled = true
		if fade_started:
			_stop_fade_physics()


func _begin_fade_out() -> void:
	if fade_started or visual == null:
		return

	fade_started = true
	# 若残骸已经停止，渐隐阶段不再保留无意义的碰撞/物理处理。
	if settled:
		_stop_fade_physics()

	var duration := clampf(lifetime_left, 0.05, FADE_DURATION)
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_LINEAR)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(visual, "modulate:a", 0.0, duration)
	fade_tween.tween_callback(Callable(self, "queue_free"))


func _stop_fade_physics() -> void:
	set_physics_process(false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)


func _constrain_to_room_bounds() -> void:
	var world: Node = _bleed_world.get_ref() if _bleed_world != null else null
	if is_instance_valid(world) and world.has_method("can_fall_through_exterior"):
		return # Formal 3D wall collisions, not a birth-room rectangle, own motion.
	if room_bounds.size.x <= 0.0 or room_bounds.size.y <= 0.0:
		return
	var clamped := Vector2(
		clampf(global_position.x, room_bounds.position.x, room_bounds.end.x),
		clampf(global_position.y, room_bounds.position.y, room_bounds.end.y)
	)
	var correction := clamped - global_position
	if correction.length_squared() <= 0.0001:
		return
	global_position = clamped
	if absf(correction.x) > 0.001:
		horizontal_velocity.x = -horizontal_velocity.x * wall_bounce_retention
	if absf(correction.y) > 0.001:
		horizontal_velocity.y = -horizontal_velocity.y * wall_bounce_retention
