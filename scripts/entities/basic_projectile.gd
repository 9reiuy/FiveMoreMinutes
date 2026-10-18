extends Node2D

const CONFIG := preload("res://resources/demo_config.tres")
const PROJECTILE_TRAIL_PATH := NodePath("ProjectileTrail")
const PROJECTILE_GLOW_SHADER := preload("res://shaders/projectile_visual_glow.gdshader")
## Presentation-only multiplier for the compact tracer head. Gameplay
## collision, swept distance and damage deliberately remain unchanged.
## The current tracer presentation is reduced to half of the previous 2x
## enlargement.  This only affects the captured Sprite2D; projectile gameplay
## size, speed, damage and collision remain unchanged.
const PROJECTILE_VISUAL_SCALE_MULTIPLIER := 1.0

## The projectile's gameplay body remains unchanged, but its presentation is
## deliberately minimal and high contrast. The head and tracer are baked into
## one small texture so they share exactly one 2D transform and one 3D depth
## carrier; this prevents a child trail from drifting below the projectile.
static var _tracer_texture: Texture2D
const TRACER_TEXTURE_SIZE := Vector2i(56, 11)
const TRACER_HEAD_ANCHOR_X := 49
const TRACER_TAIL_START_X := 7
const TRACER_TAIL_END_X := 43
const TRACER_HEAD_CENTER_X := 49
const TRACER_HEAD_RADIUS_SQUARED := 4.5

## 普通手枪与霰弹共用的轻量弹丸。
## 每个Physics Tick只查询本帧真实经过的线段，不再遍历全地图Enemy/Hurtbox/Furniture。
## Layer 1/3为正式World Wall，Layer 4为Furniture/WorldWeapon，Layer 5为Projectile Hurtbox。
const PROJECTILE_COLLISION_MASK := 1 | 4 | 8 | 16
const MAX_IGNORED_COLLIDERS := 12

@export var speed := 155.0
@export var lifetime := 1.4

var direction := Vector2.RIGHT
## Explicit travel velocity exposed to the presentation layer. Movement still
## uses the existing direction/speed authority; this is the same vector so the
## trail never needs to read a weapon or actor transform.
var velocity := Vector2.ZERO
var damage := 10.0
var consumed := false
var max_distance := 270.0
var traveled := 0.0
var source_faction: StringName = &"player"
## 只保存稳定的实例ID；射手可能在弹丸飞行期间死亡并被释放。
## 不保留Node强引用，避免延迟命中把previously freed对象传入强类型函数。
var shooter_instance_id := 0
var source_weapon_id: StringName = &"basic"
## Projectile penetration is intentionally kept in the shared projectile path:
## each pistol shot, rifle shot and shotgun pellet gets its own roll.
var penetration_chance := 0.10
var max_penetrations := 1
var penetration_count := 0
var hit_targets: Dictionary = {}
var _initial_spawn_verified := false
var office_ballistics := false
const MAX_OFFICE_SEGMENT_HITS := 32
const HISTORY_WINDOW_SECONDS := 0.06
const TERMINAL_TRAIL_SECONDS := 0.04
const MAX_TRAIL_SAMPLES := 16
# Formal 1500px/s occupies 90px; the bound keeps the single depth capture safe.
const MAX_TRAIL_RADIUS_PIXELS := 112.0
var _trail_clock := 0.0
var _trail_history: Array[Dictionary] = []
var _terminal_trail_remaining := 0.0
var _history_texture: ImageTexture
var _history_texture_size := Vector2i.ZERO
var _office_tracer_update_pending := false
var _cached_bullet_sprite: Sprite2D
var _ray_query: PhysicsRayQueryParameters2D
var _cast_exclude_rids: Array[RID] = []
var _cached_dream_world: Node
static var _history_texture_pool: Dictionary = {}
static var _history_image_pool: Dictionary = {}
const MAX_POOLED_TEXTURES_PER_SIZE := 32


static func _acquire_pooled_image(dimensions: Vector2i) -> Image:
	var cached: Variant = _history_image_pool.get(dimensions)
	if cached is Image:
		var img := cached as Image
		img.fill(Color.TRANSPARENT)
		return img
	var created := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	created.fill(Color.TRANSPARENT)
	_history_image_pool[dimensions] = created
	return created


static func _release_history_texture(tex: ImageTexture, size: Vector2i) -> void:
	if tex == null or size.x <= 0 or size.y <= 0:
		return
	var bucket: Array = _history_texture_pool.get(size, [])
	if bucket.size() < MAX_POOLED_TEXTURES_PER_SIZE:
		bucket.append(tex)
		_history_texture_pool[size] = bucket


func _clear_history_texture() -> void:
	if _history_texture != null:
		_release_history_texture(_history_texture, _history_texture_size)
		_history_texture = null
		_history_texture_size = Vector2i.ZERO


func _exit_tree() -> void:
	_clear_history_texture()


func enable_office_ballistics() -> void:
	# Explicit 3D opt-in; old 2D retains its movement and collision contract.
	office_ballistics = true
	_update_office_tracer()


func _record_trail_position() -> void:
	if not _trail_history.is_empty() and is_equal_approx(float(_trail_history.back().time), _trail_clock):
		_trail_history.back().position = global_position
	else:
		_trail_history.append({"position": global_position, "time": _trail_clock})
	_trim_trail_history()


func _trim_trail_history() -> void:
	var cutoff := _trail_clock - HISTORY_WINDOW_SECONDS
	while _trail_history.size() > 1 and float(_trail_history[1].time) <= cutoff:
		_trail_history.pop_front()
	if _trail_history.size() > 1 and float(_trail_history[0].time) < cutoff:
		var first := _trail_history[0]
		var second := _trail_history[1]
		var ratio := (cutoff - float(first.time)) / maxf(float(second.time) - float(first.time), 0.000001)
		_trail_history[0] = {"position": (first.position as Vector2).lerp(second.position, ratio), "time": cutoff}
	while _trail_history.size() > MAX_TRAIL_SAMPLES:
		# Keep both endpoints at very small slow-motion deltas; discard the
		# closest interior timestamp rather than shortening the time window.
		var remove_index := 1
		var closest_interval := INF
		for index in range(1, _trail_history.size() - 1):
			var interval := float(_trail_history[index + 1].time) - float(_trail_history[index - 1].time)
			if interval < closest_interval:
				closest_interval = interval
				remove_index = index
		_trail_history.remove_at(remove_index)


func _update_office_tracer() -> void:
	_office_tracer_update_pending = false
	if _cached_bullet_sprite == null:
		_cached_bullet_sprite = get_node_or_null(^"BulletSprite") as Sprite2D
	var sprite := _cached_bullet_sprite
	if sprite == null: return
	var inverse_scale := Vector2.ONE / sprite.scale.abs().max(Vector2(0.001, 0.001))
	var points: Array[Vector2] = []
	var lower := Vector2(-3, -5)
	var upper := Vector2(3, 5)
	for sample in _trail_history:
		var relative: Vector2 = sample.position - global_position
		if relative.length_squared() > MAX_TRAIL_RADIUS_PIXELS * MAX_TRAIL_RADIUS_PIXELS:
			relative = relative.normalized() * MAX_TRAIL_RADIUS_PIXELS
		var point := relative.rotated(-global_rotation) * inverse_scale
		points.append(point)
		lower = lower.min(point - Vector2(2, 2))
		upper = upper.max(point + Vector2(2, 2))
	var anchor := -lower.floor()
	var dimensions := Vector2i(upper.ceil() - lower.floor() + Vector2.ONE)
	var picture := _acquire_pooled_image(dimensions)
	# Rasterize actual time-stamped travel, including turns and cutoff interpolation.
	var inv_history_window := 1.0 / HISTORY_WINDOW_SECONDS
	var dim_x := dimensions.x
	var dim_y := dimensions.y
	for index in range(1, points.size()):
		var from := points[index - 1]
		var to := points[index]
		var steps := maxi(1, int(ceil(from.distance_to(to))))
		var inv_steps := 1.0 / float(steps)
		var t0 := float(_trail_history[index - 1].time)
		var t1 := float(_trail_history[index].time)
		for step in range(steps + 1):
			var ratio := float(step) * inv_steps
			var sample_time := lerpf(t0, t1, ratio)
			var alpha := clampf(1.0 - (_trail_clock - sample_time) * inv_history_window, 0.0, 1.0) * 0.82
			var pixel := Vector2i((from.lerp(to, ratio) + anchor).round())
			var px := pixel.x
			if px >= 0 and px < dim_x:
				for offset_y in range(-1, 2):
					var y := pixel.y + offset_y
					if y >= 0 and y < dim_y:
						var cur_a := picture.get_pixel(px, y).a
						if alpha > cur_a:
							picture.set_pixel(px, y, Color(1.0, 1.0, 1.0, alpha))
	if not consumed:
		var ax := int(anchor.x)
		var ay := int(anchor.y)
		for x in range(-2, 3):
			for y in range(-2, 3):
				if x * x + y * y <= 4:
					picture.set_pixel(ax + x, ay + y, Color.WHITE)
	if _history_texture == null or _history_texture_size != dimensions:
		if _history_texture != null:
			_release_history_texture(_history_texture, _history_texture_size)
		var bucket: Array = _history_texture_pool.get(dimensions, [])
		if not bucket.is_empty():
			_history_texture = bucket.pop_back() as ImageTexture
			_history_texture.update(picture)
		else:
			_history_texture = ImageTexture.create_from_image(picture)
		_history_texture_size = dimensions
	else:
		_history_texture.update(picture)
	sprite.texture = _history_texture
	sprite.position = -anchor * sprite.scale
	var glow := sprite.material as ShaderMaterial
	if glow != null:
		glow.set_shader_parameter(&"head_uv", (anchor + Vector2(0.5, 0.5)) / Vector2(dimensions))
		glow.set_shader_parameter(&"glow_strength", 0.0 if consumed else clampf(float(CONFIG.get("projectile_visual_glow_strength")), 0.0, 1.0))


func _request_office_tracer_update() -> void:
	# Physics still records every step. A live capture bridge consumes the latest
	# texture immediately before synchronization, not intermediate unseen steps.
	var reference: Variant = get_meta(&"depth_visual_bridge") if has_meta(&"depth_visual_bridge") else null
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if bool(get_meta(&"test_legacy_tracer_steps", false)) or not is_instance_valid(bridge) or not bridge.configured:
		_update_office_tracer()
		return
	_office_tracer_update_pending = true


func flush_office_tracer_update() -> void:
	if not _office_tracer_update_pending:
		return
	_office_tracer_update_pending = false
	_update_office_tracer()


func _physics_process_office(delta: float) -> void:
	velocity = direction * speed
	rotation = velocity.angle()
	if not _initial_spawn_verified:
		_initial_spawn_verified = true
		var shooter := _get_live_shooter()
		if shooter is Node2D:
			var origin: Vector2 = shooter.call("get_aim_origin") if shooter.has_method("get_aim_origin") else shooter.global_position
			var muzzle := global_position
			if origin.distance_to(muzzle) > 0.1:
				global_position = origin
				_sweep_office_to(muzzle, false)
				if consumed: return
	if _trail_history.is_empty(): _record_trail_position()
	_trail_clock += maxf(delta, 0.0)
	var remaining := maxf(0.0, max_distance-traveled)
	var step := minf(speed*delta,remaining)
	if step <= 0.0 or lifetime <= 0.0:
		_despawn(); return
	var start := global_position
	_sweep_office_to(start+direction*step, true)
	lifetime -= delta
	if consumed: return
	_record_trail_position()
	_request_office_tracer_update()
	if lifetime <= 0.0 or traveled >= max_distance-0.001: _despawn()


func _sweep_office_to(end: Vector2, count_range: bool) -> void:
	# Requery the SAME tick's remaining segment after each permitted hit. A
	# glass collider remains registered until deferred removal, so hit_targets
	# excludes it immediately. No teleport through unseen solid geometry.
	for attempt in MAX_OFFICE_SEGMENT_HITS:
		var start := global_position
		var hit := _cast_movement_segment(start,end)
		if hit.is_empty():
			global_position = end
			if count_range: traveled += start.distance_to(end)
			return
		global_position = hit.get("position",end)
		if count_range: traveled += start.distance_to(global_position)
		_handle_collision(hit.get("collider") as Node,hit.get("normal",Vector2.ZERO))
		if consumed: return
		if global_position.distance_squared_to(end) < 0.000001: return
	# Fail closed on malformed stacks; never advance past an untested collider.
	_despawn()


func _ready() -> void:
	# The BulletSprite is a self-lit presentation carrier in 3D. Keep this
	# semantic marker on the gameplay projectile so the depth bridge can choose
	# its dedicated emissive material without adding a per-projectile Light3D.
	set_meta(&"depth_visual_unshaded", true)
	set_meta(&"projectile_self_emission", true)
	# The 3D world registers the single contiguous BulletSprite tracer in one
	# depth bridge after this node enters the tree.  The legacy ProjectileTrail
	# node remains hidden for scene compatibility; keeping one visual carrier
	# preserves the same ground/depth anchor and prevents the tail from drifting
	# below the projectile head.
	var legacy_trail := get_node_or_null(PROJECTILE_TRAIL_PATH) as CanvasItem
	if legacy_trail != null:
		legacy_trail.hide()
	_configure_projectile_visual()


func _configure_projectile_visual() -> void:
	if _cached_bullet_sprite == null:
		_cached_bullet_sprite = get_node_or_null(^"BulletSprite") as Sprite2D
	var bullet_sprite := _cached_bullet_sprite
	if bullet_sprite == null:
		return
	var glow_material := bullet_sprite.material as ShaderMaterial
	if glow_material == null or glow_material.shader != PROJECTILE_GLOW_SHADER:
		glow_material = ShaderMaterial.new()
		glow_material.shader = PROJECTILE_GLOW_SHADER
		bullet_sprite.material = glow_material
	glow_material.set_shader_parameter(
		&"glow_strength",
		clampf(float(CONFIG.get("projectile_visual_glow_strength")), 0.0, 1.0)
	)
	# The world opts in before this node enters the tree. Refresh the dynamic
	# texture's head UV now that its shader exists, including the birth frame.
	if office_ballistics:
		_update_office_tracer()


func setup(new_direction: Vector2, new_damage: float, new_max_distance: float = 270.0, new_speed: float = -1.0, new_source_faction: StringName = &"player", new_source_actor: Node2D = null, weapon_id: StringName = &"basic") -> void:
	consumed = false
	traveled = 0.0
	penetration_count = 0
	hit_targets.clear()
	_initial_spawn_verified = false
	_trail_clock = 0.0
	_office_tracer_update_pending = false
	_trail_history.clear()
	_terminal_trail_remaining = 0.0
	_clear_history_texture()
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0001 else Vector2.RIGHT
	damage = new_damage
	max_distance = maxf(new_max_distance, 0.0)
	if new_speed > 0.0:
		speed = new_speed
	velocity = direction * speed
	# max_distance is the formal range authority, but lifetime is also a
	# defensive despawn limit.  After the requested 50% speed reduction, the
	# old 1.4s limit would otherwise truncate a 270px shot at roughly 217px.
	# Extend only as far as needed to reach the authored range; fast/custom
	# projectiles keep their existing lifetime.
	lifetime = maxf(lifetime, max_distance / maxf(speed, 0.001))
	source_faction = new_source_faction
	shooter_instance_id = new_source_actor.get_instance_id() if is_instance_valid(new_source_actor) else 0
	source_weapon_id = weapon_id
	penetration_chance = clampf(float(CONFIG.projectile_penetration_chance), 0.0, 1.0)
	# This first implementation permits at most one additional enemy per
	# projectile, even if an external resource accidentally contains a larger
	# value.  Future armour-piercing weapons can opt into a separate rule.
	max_penetrations = clampi(int(CONFIG.projectile_max_penetrations), 0, 1)
	var effective_visual_scale := PROJECTILE_VISUAL_SCALE_MULTIPLIER
	if _cached_bullet_sprite == null:
		_cached_bullet_sprite = get_node_or_null(^"BulletSprite") as Sprite2D
	var bullet_sprite := _cached_bullet_sprite
	if bullet_sprite != null:
		bullet_sprite.texture = _get_tracer_texture()
		bullet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bullet_sprite.modulate = Color.WHITE
		# The texture is authored with the gameplay origin at the single white
		# head. Keeping the sprite uncentered makes the tail, head and 2D muzzle
		# position one continuous transform before the depth bridge copies it.
		bullet_sprite.centered = false
		bullet_sprite.offset = Vector2.ZERO
		# Assault Rifle keeps its smaller tracer scale only; the projectile root
		# and its swept collision path retain their original size/speed.
		var visual_scale := 1.0
		if weapon_id == &"assault_rifle":
			visual_scale = clampf(
				float(CONFIG.assault_rifle_projectile_visual_scale),
				0.25,
				1.0
			)
		var base_visual_scale := bullet_sprite.scale
		effective_visual_scale = visual_scale * PROJECTILE_VISUAL_SCALE_MULTIPLIER
		bullet_sprite.scale = Vector2(
			absf(base_visual_scale.x),
			absf(base_visual_scale.y)
		) * effective_visual_scale
		# Sprite2D scales its uncentered texture around the Sprite2D origin.  The
		# previous code positioned the sprite in unscaled texture pixels and then
		# applied the 2x presentation scale, moving the white head ~5px below the
		# projectile root.  Anchor the actual head centre after the final scale so
		# the first BulletSprite pixel stays on the same 2D/3D plane as the muzzle.
		var head_anchor := Vector2(
			float(TRACER_HEAD_CENTER_X),
			float(TRACER_TEXTURE_SIZE.y - 1) * 0.5
		)
		bullet_sprite.position = Vector2(
			-head_anchor.x * bullet_sprite.scale.x,
			-head_anchor.y * bullet_sprite.scale.y
		)
	# Older scenes may still contain the custom Node2D trail. Keep that node for
	# compatibility, but hide it: the contiguous tracer texture above is the
	# sole visual source and therefore cannot be rendered below the head.
	var projectile_trail := get_node_or_null(PROJECTILE_TRAIL_PATH) as CanvasItem
	if projectile_trail != null:
		projectile_trail.hide()
	# 新Bullets素材朝局部+X；只旋转根节点，不创建Shader/Gradient/Light。
	rotation = velocity.angle()


static func _get_tracer_texture() -> Texture2D:
	if _tracer_texture != null and is_instance_valid(_tracer_texture):
		return _tracer_texture
	var image := Image.create(
		TRACER_TEXTURE_SIZE.x,
		TRACER_TEXTURE_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center_y := float(TRACER_TEXTURE_SIZE.y - 1) * 0.5
	# Tail is a contiguous, rear-facing pixel gradient. It is intentionally
	# drawn into the same texture as the single round head, not as a separate
	# node with an independent transform.
	for x in range(TRACER_TAIL_START_X, TRACER_TAIL_END_X + 1):
		var progress := float(x - TRACER_TAIL_START_X) / float(TRACER_TAIL_END_X - TRACER_TAIL_START_X)
		# RGB stays white for the whole streak; only alpha fades to zero at the
		# far end so the tail never turns into a dark/black after-image.
		var alpha := lerpf(0.0, 0.82, pow(progress, 0.72))
		var half_width := lerpf(0.5, 1.5, progress)
		for y in TRACER_TEXTURE_SIZE.y:
			if absf(float(y) - center_y) <= half_width:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	# One compact pixel disc is the complete projectile head.  The old version
	# intentionally drew two discs, which made every shot look like two bullets.
	var center_x := TRACER_HEAD_CENTER_X
	for y in TRACER_TEXTURE_SIZE.y:
		for x in range(maxi(0, center_x - 2), mini(TRACER_TEXTURE_SIZE.x, center_x + 3)):
			var dx := float(x - center_x)
			var dy := float(y) - center_y
			if dx * dx + dy * dy <= TRACER_HEAD_RADIUS_SQUARED:
				image.set_pixel(x, y, Color.WHITE)
	_tracer_texture = ImageTexture.create_from_image(image)
	return _tracer_texture


func _physics_process(delta: float) -> void:
	if consumed:
		if office_ballistics and _terminal_trail_remaining > 0.0:
			_trail_clock += maxf(delta, 0.0)
			_terminal_trail_remaining = maxf(0.0, _terminal_trail_remaining - delta)
			_trim_trail_history()
			_request_office_tracer_update()
			if _cached_bullet_sprite == null:
				_cached_bullet_sprite = get_node_or_null(^"BulletSprite") as Sprite2D
			var sprite := _cached_bullet_sprite
			if sprite != null: sprite.modulate.a = _terminal_trail_remaining / TERMINAL_TRAIL_SECONDS
			if _terminal_trail_remaining <= 0.0:
				set_physics_process(false)
				queue_free()
		return
	if office_ballistics:
		_physics_process_office(delta)
		return
	if not _initial_spawn_verified:
		_initial_spawn_verified = true
		var live_shooter := _get_live_shooter()
		if live_shooter != null and is_instance_valid(live_shooter):
			var shooter_origin: Vector2 = (
				live_shooter.call("get_aim_origin")
				if live_shooter.has_method("get_aim_origin")
				else (live_shooter as Node2D).global_position
			)
			if shooter_origin.distance_to(global_position) > 0.1:
				var spawn_hit := _cast_movement_segment(shooter_origin, global_position)
				if not spawn_hit.is_empty():
					var hit_position: Vector2 = spawn_hit.get("position", global_position)
					global_position = hit_position
					traveled += shooter_origin.distance_to(hit_position)
					_handle_collision(spawn_hit.get("collider") as Node, spawn_hit.get("normal", Vector2.ZERO))
					return
	# Keep the presentation vector in lockstep with the authoritative gameplay
	# movement vector. This also covers callers that adjust speed between ticks.
	velocity = direction * speed
	rotation = velocity.angle()
	var remaining_distance := maxf(0.0, max_distance - traveled)
	var step := minf(speed * delta, remaining_distance)
	if step <= 0.0 or lifetime <= 0.0:
		_despawn()
		return
	var movement_start := global_position
	var movement_end := movement_start + direction * step
	var hit := _cast_movement_segment(movement_start, movement_end)
	if not hit.is_empty():
		var hit_position: Vector2 = hit.get("position", movement_end)
		global_position = hit_position
		traveled += movement_start.distance_to(hit_position)
		lifetime -= delta
		_handle_collision(hit.get("collider") as Node, hit.get("normal", Vector2.ZERO))
		return
	global_position = movement_end
	traveled += step
	lifetime -= delta
	if lifetime <= 0.0 or traveled >= max_distance:
		_despawn()


## WorldWeapon和发射者不是伤害目标；命中它们时继续查询同一运动线段后方的第一个正式目标。

func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world


func _cast_movement_segment(from_position: Vector2, to_position: Vector2) -> Dictionary:
	_cast_exclude_rids.clear()
	var furniture_hit: Dictionary = {}
	var live_shooter := _get_live_shooter()
	if live_shooter is CollisionObject2D:
		_cast_exclude_rids.append((live_shooter as CollisionObject2D).get_rid())
	var space_state := get_world_2d().direct_space_state
	if _ray_query == null:
		_ray_query = PhysicsRayQueryParameters2D.new()
		_ray_query.collide_with_bodies = true
		_ray_query.collide_with_areas = true
		_ray_query.hit_from_inside = true
	_ray_query.from = from_position
	_ray_query.to = to_position
	_ray_query.collision_mask = PROJECTILE_COLLISION_MASK
	for _attempt in range(64 if office_ballistics else MAX_IGNORED_COLLIDERS):
		_ray_query.exclude = _cast_exclude_rids
		var hit := space_state.intersect_ray(_ray_query)
		if hit.is_empty():
			return furniture_hit
		var collider := hit.get("collider") as Node
		if not _should_ignore_collider(collider):
			var owner_node := _resolve_damage_owner(collider)
			if has_meta(&"shot_height_pixels") and owner_node is Node2D and owner_node.is_in_group(&"damageable_props"):
				var height_hit: Dictionary = preload("res://scripts/dream/office_furniture_catalog.gd").shot_hit(owner_node, from_position, to_position, float(get_meta(&"shot_height_pixels")))
				if not height_hit.is_empty():
					hit["position"] = height_hit.position
					if furniture_hit.is_empty() or from_position.distance_squared_to(hit.position) < from_position.distance_squared_to(furniture_hit.position):
						furniture_hit = hit
			else:
				return furniture_hit if not furniture_hit.is_empty() and from_position.distance_squared_to(furniture_hit.position) < from_position.distance_squared_to(hit.position) else hit
		if collider is CollisionObject2D:
			_cast_exclude_rids.append((collider as CollisionObject2D).get_rid())
		else:
			return {}
	if office_ballistics and furniture_hit.is_empty():
		return {"position":from_position,"collider":null}
	return furniture_hit


func _should_ignore_collider(collider: Node) -> bool:
	if collider == null:
		return true
	var target := _resolve_damage_owner(collider)
	if not is_instance_valid(target):
		return true
	if shooter_instance_id > 0 and target.get_instance_id() == shooter_instance_id:
		return true
	if hit_targets.has(target.get_instance_id()):
		return true
	if target.is_in_group(&"world_weapon_pickups"):
		return true
	if source_faction == &"player" and target.is_in_group(&"dream_player"):
		return true
	return false


func _handle_collision(collider: Node, hit_normal: Vector2 = Vector2.ZERO) -> void:
	if consumed:
		return
	if collider == null:
		_despawn()
		return
	var world := _dream_world()
	# The 3D office owns presentation mapping. Keep the authoritative 2D hit
	# point and shot-height snapshot unchanged; a legacy 2D world has no visual
	# callback and therefore retains its original collision/damage path.
	if world is Node3D and world.has_method("spawn_firearm_impact_visual"):
		var visual_normal := hit_normal if hit_normal.length_squared() > 0.0001 else -direction
		world.call(
			"spawn_firearm_impact_visual",
			global_position,
			visual_normal,
			collider,
			float(get_meta(&"shot_height_pixels", 0.0))
		)
	# Legacy DoorLeafCollision2D is terminal. Office bullets damage it and pass.
	# Impacts still use the real hinge; penetrating a locked door does not unlock it.
	if collider.has_meta(&"physical_door") and bool(collider.get_meta(&"physical_door", false)):
		if world != null and world.has_method("resolve_door_impact_from_collision"):
			var door_force := CONFIG.gun_knockback_force * CONFIG.get_furniture_projectile_force_multiplier(source_weapon_id)
			world.call(
				"resolve_door_impact_from_collision",
				collider,
				global_position,
				direction,
				door_force,
				StringName("projectile_%s" % String(source_weapon_id)),
				shooter_instance_id
			)
		if collider.has_method("take_damage"):
			collider.call("take_damage", damage, direction, 1.0)
		if office_ballistics:
			hit_targets[collider.get_instance_id()] = true
			return
		_despawn()
		return
	var target := _resolve_damage_owner(collider)
	if not is_instance_valid(target):
		_despawn()
		return
	if office_ballistics and target.is_in_group(&"glass_windows"):
		hit_targets[target.get_instance_id()] = true
		if target.has_method("take_damage"):
			target.call("take_damage",damage,direction,1.0)
		return
	if target.is_in_group(&"damageable_props"):
		if target.has_method("is_damage_runtime_active") and not bool(target.is_damage_runtime_active()):
			_despawn()
			return
		var target_id := target.get_instance_id()
		if not hit_targets.has(target_id):
			hit_targets[target_id] = true
			if target.has_method("take_damage"):
				var force_multiplier := CONFIG.get_furniture_projectile_force_multiplier(source_weapon_id)
				if target.has_method(&"_apply_contact_impulse"):
					target.take_damage(damage, direction, force_multiplier, global_position)
				else:
					target.take_damage(damage, direction, force_multiplier)
		# A height-filtered hit crossed actual solid furniture, regardless of size.
		if has_meta(&"shot_height_pixels"):
			_despawn()
			return
		# Legacy 2D retains its existing size-based rule.
		# Large furniture (fridges, wardrobes, beds, filing/storage cabinets) stops bullets.
		var allows_pass_through := false
		if target.has_method("get_size_category"):
			var size_cat: int = int(target.call("get_size_category"))
			# 1: SMALL, 2: MEDIUM, 3: LARGE
			if size_cat == 1 or size_cat == 2:
				allows_pass_through = true
		elif target.has_method("is_vaultable") and bool(target.call("is_vaultable")):
			allows_pass_through = true
		elif target.get("vaultable") == true:
			allows_pass_through = true

		if allows_pass_through:
			return
		_despawn()
		return
	elif target.is_in_group(&"dream_enemies"):
		var target_id := target.get_instance_id()
		if hit_targets.has(target_id):
			return
		hit_targets[target_id] = true
		var damage_result: Dictionary = {}
		if source_faction == &"enemy":
			# Friendly fire使用原始武器伤害，且不会经过Player暴击/伤害倍率。
			if world != null and world.has_method("resolve_enemy_projectile_hit"):
				damage_result = world.resolve_enemy_projectile_hit(target, damage, global_position, shooter_instance_id, source_weapon_id)
		elif world != null:
			# 保留武器ID供统一战斗反馈分级（霰弹比普通枪击更重）。
			damage_result = world.resolve_player_hit(
				target,
				damage,
				global_position,
				StringName("player_projectile_%s" % String(source_weapon_id))
			)
		if _roll_enemy_penetration():
			# Keep the real projectile alive and let the next swept segment find
			# another target.  hit_targets prevents re-damaging this enemy.
			return
	elif target.is_in_group(&"dream_player") and source_faction == &"enemy":
		if target.has_method("receive_damage"):
			target.receive_damage(damage, &"employee_projectile", global_position, direction)
	# Walls, closed Door blockers, furniture and players remain terminal hits.
	_despawn()


func _roll_enemy_penetration() -> bool:
	if penetration_count >= max_penetrations or penetration_chance <= 0.0:
		return false
	if randf() >= penetration_chance:
		return false
	penetration_count += 1
	return true


func _resolve_damage_owner(collider: Node) -> Node:
	if collider.has_method("get_damage_owner"):
		return collider.get_damage_owner()
	return collider


func _get_live_shooter() -> Node:
	if shooter_instance_id <= 0 or not is_instance_id_valid(shooter_instance_id):
		return null
	return instance_from_id(shooter_instance_id) as Node


func _despawn() -> void:
	if consumed: return
	consumed = true
	remove_from_group(&"active_basic_projectiles")
	remove_from_group(&"dream_projectiles")
	if office_ballistics:
		_record_trail_position()
		_request_office_tracer_update()
		_terminal_trail_remaining = TERMINAL_TRAIL_SECONDS
		# Remaining ticks only fade presentation: consumed blocks movement/damage.
	else:
		set_physics_process(false)
		queue_free()
