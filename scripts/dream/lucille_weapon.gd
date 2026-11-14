extends Node

signal weapon_fired(recoil_multiplier: float)
signal melee_impact(hit_something: bool)
signal melee_furniture_hit(direction: Vector2)

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONFIG := preload("res://resources/demo_config.tres")
const SWEEP := preload("res://scripts/dream/melee_sweep.gd")
const SWEEP_VISUAL := preload("res://scripts/dream/melee_sweep_visual_3d.gd")
const COMBO_GRACE := 0.26
const INPUT_GRACE := 0.15
const FINISHER_DROP_PIXELS := 7.0
const FINISHER_ARC_DROP := 0.22

@export_enum("lucille", "books", "melee_plank", "melee_pipe", "melee_pipe_wrench", "melee_wrench", "melee_crowbar", "melee_machete") var weapon_id: String = "lucille"
var damage := 30.0
var attack_range := 80.0
var attack_arc_radians := deg_to_rad(160.0)
var attack_interval := 0.6
var knockback_multiplier := 4.0
var active := false:
	set(value):
		active = value
		if not active:
			cancel_swing()
var melee_action_active := false
var cooldown_left := 0.25
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
var impact_delay := 0.04
var windup_seconds := 0.04
var strike_seconds := 0.10
var recover_seconds := 0.10
var swing_elapsed := 0.0
var swing_direction := Vector2.RIGHT
var direction_locked := false
var sweep_progress := 0.0
var combo_stage := 0
var combo_reversed := false
var attack_buffered: bool:
	get: return _buffer_left > 0.0
var _buffer_left := 0.0
var _chain_left := 0.0
var _entry_weight := 0.0
var _entry_drop := 0.0
var _feedback_sent := false
var _furniture_feedback_sent := false
var _door_hit := false
var _extra_pending := false
var _extra_left := 0.0
var _swing_allows_extra := true
var _floor_token := -1
var _melee_shape: CircleShape2D
var _melee_query: PhysicsShapeQueryParameters2D
var _path_query: PhysicsRayQueryParameters2D
var _melee_handled: Dictionary = {}
var _cached_dream_world: Node
var _visual: Node3D
var _reach_limits := PackedFloat32Array()
var parry_armed := false
var parry_feedback_sent := false

func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	cancel_swing()
	if weapon_id == "books":
		damage = config.books_damage
		attack_range = config.player_books_attack_range
		attack_arc_radians = deg_to_rad(config.player_books_attack_arc_degrees)
		knockback_multiplier = config.get_lucille_knockback_force() / maxf(config.gun_knockback_force, 0.001) * config.books_knockback_multiplier
	else:
		damage = config.lucille_damage
		attack_range = config.player_lucille_attack_range
		attack_arc_radians = deg_to_rad(config.player_lucille_attack_arc_degrees)
		knockback_multiplier = config.get_lucille_knockback_force() / maxf(config.gun_knockback_force, 0.001)
	attack_range *= DreamGunAtlas.get_melee_range_multiplier(weapon_id)
	var speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	var base_interval: float = config.books_attack_interval if weapon_id == "books" else config.lucille_attack_interval
	attack_interval = config.weapon_interval_for_rate(base_interval) / maxf(speed, 0.01)
	windup_seconds = config.lucille_character_windup_seconds / maxf(speed, 0.01)
	strike_seconds = config.lucille_character_strike_seconds / maxf(speed, 0.01)
	recover_seconds = config.lucille_character_recover_seconds / maxf(speed, 0.01)
	impact_delay = windup_seconds

func _process(delta: float) -> void:
	if get_parent().has_method("combat_action_delta"): delta=get_parent().combat_action_delta(delta)
	if not active:
		return
	if combo_stage > 0 or attack_buffered:
		if not _can_continue():
			cancel_swing()
		else:
			_chain_left = maxf(_chain_left - delta, 0.0)
			_buffer_left = maxf(_buffer_left - delta, 0.0)
			if _chain_left <= 0.0 and not melee_action_active and not _extra_pending:
				combo_stage = 0
				combo_reversed = false
	cooldown_left -= delta
	if not melee_action_active and not _extra_pending and cooldown_left <= 0.0 and get_parent().should_trigger_weapon_attack():
		cooldown_left = attack_interval
		_perform_swing(true)

func queue_press() -> void:
	if not _can_continue():
		return
	var duration := windup_seconds + strike_seconds + recover_seconds
	var swing_left := duration - swing_elapsed if melee_action_active else 0.0
	var extra_left := _extra_left + duration if _extra_pending else 0.0
	# Buffer one click through the remaining cooldown; never spend it early.
	_buffer_left = maxf(cooldown_left, maxf(swing_left, extra_left)) + INPUT_GRACE
	_floor_token = _current_floor_token(_dream_world())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_buffer_left = 0.0

func _physics_process(delta: float) -> void:
	if get_parent().has_method("combat_action_delta"): delta=get_parent().combat_action_delta(delta)
	if _extra_pending:
		if not _can_continue():
			cancel_swing()
			return
		_extra_left -= delta
		if _extra_left <= 0.0:
			_extra_pending = false
			_perform_swing(false)
	if not melee_action_active:
		return
	if not _can_continue():
		cancel_swing()
		return
	var previous_elapsed := swing_elapsed
	swing_elapsed += maxf(delta, 0.0)
	if not direction_locked:
		swing_direction = _aim_direction()
		direction_locked = swing_elapsed >= windup_seconds
	var previous_progress := sweep_progress
	sweep_progress = SWEEP.strike_progress(swing_elapsed, windup_seconds, strike_seconds)
	var owner := get_parent() as Node2D
	if swing_elapsed >= windup_seconds and previous_elapsed < windup_seconds + strike_seconds:
		_resolve_sweep(owner, owner.global_position, previous_progress, sweep_progress)
	_publish_snapshot()
	if swing_elapsed >= windup_seconds + strike_seconds + recover_seconds:
		var repeat := _swing_allows_extra and randf() < extra_attack_chance
		_finish_swing()
		if repeat:
			_extra_pending = true
			_extra_left = extra_attack_delay

func _perform_swing(allow_extra: bool) -> void:
	if melee_action_active or not _can_continue():
		return
	_entry_weight = pose_weight()
	_entry_drop = grip_drop()
	combo_reversed = combo_stage > 0 and not combo_reversed
	combo_stage = 1 + combo_stage % 3
	_chain_left = maxf(cooldown_left, windup_seconds + strike_seconds + recover_seconds) + COMBO_GRACE
	if allow_extra:
		_buffer_left = 0.0
	melee_action_active = true
	swing_elapsed = 0.0
	sweep_progress = 0.0
	direction_locked = false
	swing_direction = _aim_direction()
	_swing_allows_extra = allow_extra
	_feedback_sent = false
	_furniture_feedback_sent = false
	_door_hit = false
	_melee_handled.clear()
	var world := _dream_world()
	_floor_token = _current_floor_token(world)
	parry_armed=false
	parry_feedback_sent=false
	if world!=null and world.has_method("get_combat_defense"):
		parry_armed=world.get_combat_defense().claim_click()
	SFX.play_event(&"melee_swing")
	weapon_fired.emit(1.0)
	_publish_snapshot()

func _can_continue() -> bool:
	var owner := get_parent()
	if not (active and is_instance_valid(owner) and owner.get("dead") != true
		and owner.get("dashing") != true and owner.get("kick_active") != true
		and owner.get("vault_active") != true and owner.get("airborne_knockback") != true
		and owner.get("tactical_plan_active") != true
		and owner.get("movement_enabled") != false and owner.get("attacking_enabled") != false
		and owner.get("selected_weapon_id") == weapon_id):
		return false
	if _floor_token >= 0 and (combo_stage > 0 or attack_buffered or _extra_pending):
		return _current_floor_token(_dream_world()) == _floor_token
	return true

func _current_floor_token(world: Node) -> int:
	if not is_instance_valid(world):
		return -1
	var token: Variant = world.get("_layout_generation")
	return -1 if token == null else int(token)

func _aim_direction() -> Vector2:
	var owner := get_parent() as Node2D
	var direction := owner.global_position.direction_to(owner.get_constrained_aim_position())
	if direction.length_squared() <= 0.001:
		direction = owner.get("last_aim_direction") if owner.get("last_aim_direction") is Vector2 else swing_direction
	return direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT

func cancel_swing() -> void:
	var had_pose := melee_action_active or combo_stage > 0
	combo_stage = 0
	combo_reversed = false
	_chain_left = 0.0
	_buffer_left = 0.0
	_floor_token = -1
	_extra_pending = false
	if had_pose:
		_finish_swing()
	elif is_instance_valid(_visual):
		_visual.hide()

func _finish_swing() -> void:
	melee_action_active = false
	direction_locked = false
	if is_instance_valid(_visual):
		_visual.hide()
	var owner := get_parent()
	if is_instance_valid(owner) and owner.has_method("finish_melee_swing_snapshot"):
		owner.finish_melee_swing_snapshot()

func _exit_tree() -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()

func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world

func _sweep_angle_at(progress: float) -> float:
	return SWEEP.angle_at(1.0 - progress if combo_reversed else progress, attack_arc_radians)

func pose_weight() -> float:
	if combo_stage == 0:
		return 0.0
	if melee_action_active:
		return lerpf(_entry_weight, 1.0, smoothstep(0.0, windup_seconds, swing_elapsed))
	return smoothstep(0.0, COMBO_GRACE, _chain_left)

func grip_drop() -> float:
	var drop := FINISHER_DROP_PIXELS if combo_stage == 3 else 0.0
	if melee_action_active:
		return lerpf(_entry_drop, drop, smoothstep(0.0, windup_seconds, swing_elapsed))
	return drop * pose_weight()

func _publish_snapshot() -> void:
	var owner := get_parent() as Node2D
	var recovery := clampf((swing_elapsed - windup_seconds - strike_seconds) / maxf(recover_seconds, 0.001), 0.0, 1.0)
	var snapshot := {"weapon_id": weapon_id, "origin": owner.global_position,
		"direction": swing_direction, "reach": attack_range, "arc": attack_arc_radians,
		"sweep": sweep_progress, "angle": _sweep_angle_at(sweep_progress),
		"sweep_reversed": combo_reversed,
		"elapsed": swing_elapsed, "duration": windup_seconds + strike_seconds + recover_seconds,
		"opacity": 1.0 - recovery, "locked": direction_locked}
	if owner.has_method("apply_melee_swing_snapshot"):
		owner.apply_melee_swing_snapshot(snapshot)
	var world := _dream_world() as Node3D
	if world == null or not world.has_method("_cell_world_size"):
		return
	# Use the same spatial plane as the held sprite, not a head-height plane.
	# The body's vertical reference plane then naturally separates rear/front
	# arc pixels; leave ordinary wall/furniture depth testing enabled.
	var bridge_ref: Variant = owner.get_meta(&"depth_visual_bridge", null)
	var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
	if is_instance_valid(bridge):
		var grip: Dictionary = bridge.get_weapon_visual_snapshot(owner.global_position)
		if grip.has("world_origin"):
			snapshot["visual_height"] = world.to_local(grip.world_origin).y
	if combo_stage == 3:
		snapshot["visual_height"] = maxf(0.042, float(snapshot.get("visual_height", 0.4)) - FINISHER_ARC_DROP)
	if not is_instance_valid(_visual):
		_visual = SWEEP_VISUAL.new()
		_visual.name = "PlayerMeleeSweep_" + weapon_id
		# A stashed/rolled-back floor owns the passive carrier just like its
		# blood and debris. Regeneration cannot leave an old arc in the new floor.
		var floor_owner := world.get("floor_root") as Node
		if floor_owner == null:
			floor_owner = world
		floor_owner.add_child(_visual)
	if sweep_progress > 0.0:
		_reach_limits.resize(33)
		for index in 33:
			var angle := SWEEP.angle_at(float(index) / 32.0, attack_arc_radians)
			var tip := owner.global_position + swing_direction.rotated(angle) * attack_range
			_reach_limits[index] = _trace_reach(owner, owner.global_position, tip)
		_visual.sync_snapshot(world, snapshot, _reach_limits)

## Ray-test real wall/door and furniture footprints. Only the target itself
## is excluded; high cabinets may be hit, but never hit through.
func _trace_reach(owner: Node2D, origin: Vector2, endpoint: Vector2, target: Node = null) -> float:
	if _path_query == null:
		_path_query = PhysicsRayQueryParameters2D.new()
		_path_query.collision_mask = 4 | 8
		_path_query.collide_with_areas = false
		_path_query.hit_from_inside = true
	var excluded: Array[RID] = []
	if owner is CollisionObject2D:
		excluded.append(owner.get_rid())
	if target is CollisionObject2D:
		excluded.append(target.get_rid())
	_path_query.from = origin
	_path_query.to = endpoint
	var space := owner.get_world_2d().direct_space_state
	for attempt in 64:
		_path_query.exclude = excluded
		var hit := space.intersect_ray(_path_query)
		if hit.is_empty():
			return origin.distance_to(endpoint)
		var collider := hit.get("collider") as Node
		if collider != null and collider.is_in_group(&"damageable_props"):
			var category := int(collider.call("get_size_category")) if collider.has_method("get_size_category") else 3
			if category <= 2 and collider is CollisionObject2D:
				excluded.append(collider.get_rid())
				continue
		return maxf(origin.distance_to(hit.position) - 0.5, 0.0)
	# Exhausting a query budget is blocked, never a clear path.
	return 0.0

func _target_samples(target: Node2D, origin: Vector2) -> PackedVector2Array:
	var samples := PackedVector2Array([target.global_position])
	var shape_node := target.get_node_or_null(^"Hurtbox/CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = target.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return samples
	var rect := shape_node.shape.get_rect()
	var local := shape_node.to_local(origin)
	if shape_node.shape is CircleShape2D:
		var radius: float = shape_node.shape.radius
		local = local.limit_length(radius)
	else:
		local = local.clamp(rect.position, rect.end)
	samples.append(shape_node.to_global(local))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		if not shape_node.shape is CircleShape2D:
			samples.append(shape_node.to_global(corner))
	return samples

func _target_in_slice(owner: Node2D, target: Node2D, origin: Vector2, first: float, last: float) -> bool:
	return _find_slice_contact(owner, target, origin, swing_direction, first, last).is_finite()

func _find_slice_contact(owner: Node2D, target: Node2D, origin: Vector2, direction: Vector2,
		first: float, last: float, surface_first := false) -> Vector2:
	var samples := _target_samples(target, origin)
	if surface_first and samples.size() > 1:
		var center := samples[0]
		samples[0] = samples[1]
		samples[1] = center
	for point in samples:
		if SWEEP.contains_point(point, origin, direction, attack_range, first, last):
			if _trace_reach(owner, origin, point, target) + 0.75 >= origin.distance_to(point):
				return point
	return Vector2.INF

func _enemy_within_reach(enemy: Node2D, origin: Vector2) -> bool:
	if enemy.has_method("distance_to_hurtbox"):
		return float(enemy.distance_to_hurtbox(origin)) <= attack_range
	return enemy.global_position.distance_squared_to(origin) <= attack_range * attack_range

func get_attack_preview_direction() -> Vector2:
	if not _can_continue():
		return Vector2.ZERO
	return swing_direction if melee_action_active and direction_locked else _aim_direction()

func is_target_in_attack_preview(target: Node2D, direction := Vector2.ZERO) -> bool:
	if not is_instance_valid(target):
		return false
	if direction.is_zero_approx():
		direction = get_attack_preview_direction()
		if direction.is_zero_approx():
			return false
	var owner := get_parent() as Node2D
	var origin := owner.global_position
	if not _enemy_within_reach(target, origin):
		return false
	var half_arc := attack_arc_radians * 0.5
	return _find_slice_contact(owner, target, origin, direction, -half_arc, half_arc, true).is_finite()

func _resolve_sweep(owner: Node2D, origin: Vector2, previous: float, current: float) -> bool:
	var world := _dream_world()
	var first := _sweep_angle_at(previous)
	var last := _sweep_angle_at(current)
	var accepted := false
	var enemies: Array = world.get_dream_enemies_snapshot() if world != null and world.has_method("get_dream_enemies_snapshot") else get_tree().get_nodes_in_group(&"dream_enemies")
	for candidate in enemies:
		if not is_instance_valid(candidate) or not candidate is Node2D or candidate.is_queued_for_deletion() or not candidate.is_inside_tree():
			continue
		var enemy := candidate as Node2D
		if not is_instance_valid(enemy) or enemy.get("dead") == true or _melee_handled.has(enemy.get_instance_id()):
			continue
		if not _enemy_within_reach(enemy, origin):
			continue
		var point := _find_slice_contact(owner, enemy, origin, swing_direction, first, last, true)
		if not point.is_finite():
			continue
		_melee_handled[enemy.get_instance_id()] = true
		if world != null and world.has_method("resolve_player_hit"):
			var source := StringName(DreamGunAtlas.get_behavior_id(weapon_id))
			var result: Dictionary
			if world.has_method("resolve_player_melee_hit"):
				var radial := origin.direction_to(point)
				if radial.is_zero_approx():
					radial = swing_direction.rotated(last)
				var tangent := radial.rotated(-PI * 0.5 if combo_reversed else PI * 0.5)
				result = world.resolve_player_melee_hit(enemy, damage, origin, source, point, tangent,
					FINISHER_ARC_DROP if combo_stage == 3 else 0.0)
			else:
				result = world.resolve_player_hit(enemy, damage, origin, source)
			accepted = not result.is_empty() or accepted
	if _melee_query == null:
		_melee_shape = CircleShape2D.new()
		_melee_query = PhysicsShapeQueryParameters2D.new()
		_melee_query.shape = _melee_shape
		_melee_query.collision_mask = 8 | 4
		_melee_query.collide_with_bodies = true
		_melee_query.collide_with_areas = false
	_melee_shape.radius = maxf(attack_range, 1.0)
	_melee_query.transform = Transform2D(0.0, origin)
	var exclusions: Array[RID] = []
	if owner is CollisionObject2D:
		exclusions.append(owner.get_rid())
	_melee_query.exclude = exclusions
	for hit in owner.get_world_2d().direct_space_state.intersect_shape(_melee_query, 128):
		var candidate: Variant = hit.get("collider")
		if not is_instance_valid(candidate) or not candidate is Node2D or candidate.is_queued_for_deletion(): continue
		var prop := candidate as Node2D
		if prop == null or _melee_handled.has(prop.get_instance_id()):
			continue
		if not prop.has_meta(&"physical_door") and not prop.is_in_group(&"damageable_props"):
			continue
		if not _target_in_slice(owner, prop, origin, first, last):
			continue
		if prop.has_meta(&"physical_door") and world != null and world.has_method("resolve_door_impact_from_collision"):
			if not _door_hit:
				var samples := _target_samples(prop, origin)
				var impact := samples[1] if samples.size() > 1 else prop.global_position
				_door_hit = bool(world.resolve_door_impact_from_collision(prop, impact, swing_direction.rotated(last), CONFIG.gun_knockback_force * knockback_multiplier, StringName("melee_%s" % DreamGunAtlas.get_behavior_id(weapon_id)), owner.get_instance_id()))
				accepted = _door_hit or accepted
			_melee_handled[prop.get_instance_id()] = true
		elif prop.is_in_group(&"damageable_props") and prop.has_method("take_damage"):
			_melee_handled[prop.get_instance_id()] = true
			prop.take_damage(damage, swing_direction, knockback_multiplier)
			SFX.play_melee_furniture_hit()
			accepted = true
			if not _furniture_feedback_sent:
				_furniture_feedback_sent = true
				melee_furniture_hit.emit(swing_direction)
	if accepted and not _feedback_sent:
		_feedback_sent = true
		melee_impact.emit(true)
	return accepted

## Compatibility hook for diagnostic callers; live attacks use incremental slices.
func _resolve_swing_hits(owner: Node2D, origin: Vector2, direction: Vector2) -> bool:
	swing_direction = direction.normalized()
	_melee_handled.clear()
	return _resolve_sweep(owner, origin, 0.0, 1.0)

func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(delay, 0.0)

func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval, 0.001), 0.0, 1.0)

func apply_damage_upgrade(multiplier: float) -> void:
	damage *= multiplier

func apply_attack_speed_upgrade(multiplier: float) -> void:
	var speed := maxf(multiplier, 0.01)
	attack_interval /= speed
	windup_seconds /= speed
	strike_seconds /= speed
	recover_seconds /= speed
	impact_delay = windup_seconds

func apply_range_upgrade(pixels: float) -> void:
	attack_range += pixels * DreamGunAtlas.get_melee_range_multiplier(weapon_id)
