extends Node

signal weapon_fired(recoil_multiplier: float)
signal melee_impact(hit_something: bool)
signal melee_furniture_hit(direction: Vector2)

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONFIG := preload("res://resources/demo_config.tres")

## Shared close-range swing weapon.  Lucille and Books intentionally use the
## same hit/query pipeline; only their authored data differs.
@export_enum("lucille", "books") var weapon_id: String = "lucille"
var damage := 30.0
var attack_range := 30.0
var attack_arc_radians := deg_to_rad(120.0)
var attack_interval := 0.6
var knockback_multiplier := 4.0
var active := false
## True through the complete swing lifecycle, including impact delay and any
## authored extra swing.  This is a time-activity state, not a hit-frame pulse.
var melee_action_active := false
var cooldown_left := 0.25
var extra_attack_chance := 0.0
var extra_attack_delay := 0.08
var impact_delay := 0.12
var _melee_shape: CircleShape2D
var _melee_query: PhysicsShapeQueryParameters2D


func configure_weapon(config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	if weapon_id == "books":
		damage = config.books_damage
		attack_range = config.books_attack_range
		attack_arc_radians = deg_to_rad(config.books_attack_arc_degrees)
		knockback_multiplier = config.get_lucille_knockback_force() / maxf(config.gun_knockback_force, 0.001) * config.books_knockback_multiplier
	else:
		damage = config.lucille_damage
		attack_range = config.lucille_attack_range
		attack_arc_radians = deg_to_rad(config.lucille_attack_arc_degrees)
		knockback_multiplier = config.get_lucille_knockback_force() / maxf(config.gun_knockback_force, 0.001)
	var attack_speed := 1.0 + int(permanent_upgrades.get("prefrontal", 0)) * config.prefrontal_attack_speed_per_level
	# Keep this explicit instead of nesting conditional expressions so the
	# shared swing script remains easy for Godot's static analyzer to type.
	var base_interval: float = config.lucille_attack_interval
	if weapon_id == "books":
		base_interval = config.books_attack_interval
	attack_interval = config.weapon_interval_for_rate(base_interval) / maxf(attack_speed, 0.01)
	impact_delay = clampf(config.melee_swing_impact_delay, 0.0, maxf(attack_interval - 0.01, 0.0))


func _process(delta: float) -> void:
	if not active:
		return
	cooldown_left -= delta
	if cooldown_left > 0.0 or not get_parent().should_trigger_weapon_attack():
		return
	cooldown_left = attack_interval
	_perform_swing(true)


func _perform_swing(allow_extra: bool) -> void:
	if not active or not is_instance_valid(get_parent()):
		return
	var root_swing := not melee_action_active
	melee_action_active = true
	SFX.play_event(&"melee_swing")
	var owner := get_parent() as Node2D
	# Melee gameplay is authored from the actor's formal ground position. The
	# WeaponOrigin is visually offset above that pivot, which would skew the
	# angular test and make side/below furniture fall outside the attack arc.
	var origin: Vector2 = owner.global_position
	var direction: Vector2 = origin.direction_to(get_parent().get_constrained_aim_position())
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	# 先发出攻击开始事件，让视觉进入第1阶段；实际伤害在Impact阶段结算。
	weapon_fired.emit(1.0)
	var wait_seconds: float = maxf(impact_delay, 0.0)
	if wait_seconds > 0.0:
		await get_tree().create_timer(wait_seconds, false).timeout
	if (
		not active
		or not is_instance_valid(get_parent())
		or get_parent().get("dead") == true
		or get_parent().get("dashing") == true
		or get_parent().get("kick_active") == true
		or get_parent().get("airborne_knockback") == true
	):
		if root_swing:
			melee_action_active = false
		return
	owner = get_parent() as Node2D
	if owner == null:
		if root_swing:
			melee_action_active = false
		return
	# Resolve the formal ground pose again at the impact frame. The actor may
	# have moved or rotated during the authored swing delay; visual weapon orbit
	# does not change the 2D gameplay attack origin.
	origin = owner.global_position
	direction = origin.direction_to(owner.get_constrained_aim_position())
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var hit_something: bool = _resolve_swing_hits(owner, origin, direction)
	melee_impact.emit(hit_something)
	if allow_extra and randf() < extra_attack_chance:
		await get_tree().create_timer(extra_attack_delay, false).timeout
		if active and is_instance_valid(get_parent()) and not get_parent().dead:
			await _perform_swing(false)
	if root_swing:
		melee_action_active = false


func _resolve_swing_hits(owner: Node2D, origin: Vector2, direction: Vector2) -> bool:
	# 判定圆心是Player本体；HeldWeapon挂点只负责视觉，不再把10px直线当近战范围。
	var world := get_tree().get_first_node_in_group(&"dream_world")
	var handled: Dictionary = {}
	var hit_something := false
	var hit_furniture := false
	var half_arc := attack_arc_radians * 0.5
	for enemy in get_tree().get_nodes_in_group(&"dream_enemies"):
		if not is_instance_valid(enemy) or enemy.get("dead") == true:
			continue
		var to_enemy: Vector2 = origin.direction_to(enemy.global_position)
		if to_enemy.length_squared() <= 0.0001 or absf(direction.angle_to(to_enemy)) > half_arc:
			continue
		var distance := origin.distance_to(enemy.global_position)
		if enemy.has_method("distance_to_hurtbox"):
			distance = float(enemy.distance_to_hurtbox(origin))
		if distance > attack_range:
			continue
		handled[enemy.get_instance_id()] = true
		if world != null and world.has_method("resolve_player_hit"):
			var result: Dictionary = world.resolve_player_hit(
				enemy,
				damage,
				origin,
				StringName(weapon_id)
			)
			if not result.is_empty():
				hit_something = true
	# 家具使用同一个60°/20px瞬时扇形；一次Swing的handled表保证每个目标只结算一次。
	if _melee_query == null:
		_melee_shape = CircleShape2D.new()
		_melee_query = PhysicsShapeQueryParameters2D.new()
		_melee_query.shape = _melee_shape
		_melee_query.collide_with_bodies = true
		_melee_query.collide_with_areas = false
		_melee_query.collision_mask = 8
	_melee_shape.radius = maxf(attack_range, 1.0)
	_melee_query.transform = Transform2D(0.0, origin)
	_melee_query.exclude = [owner.get_rid()] if owner is CollisionObject2D else []
	for hit in owner.get_world_2d().direct_space_state.intersect_shape(_melee_query, 16):
		var prop := hit.get("collider") as Node
		if prop == null or handled.has(prop.get_instance_id()) or not prop.is_in_group(&"damageable_props"):
			continue
		var to_prop := origin.direction_to((prop as Node2D).global_position)
		if to_prop.length_squared() <= 0.0001 or absf(direction.angle_to(to_prop)) > half_arc:
			continue
		if (
			world != null
			and world.has_method("is_room_projectile_path_clear")
			and not bool(world.is_room_projectile_path_clear(origin, (prop as Node2D).global_position))
		):
			continue
		handled[prop.get_instance_id()] = true
		if prop.has_method("take_damage"):
			prop.take_damage(damage, direction, knockback_multiplier)
			# Emit the furniture impact cue at the same frame as the accepted
			# gameplay hit.  The Player callback below is reserved for recoil.
			SFX.play_melee_furniture_hit()
			hit_something = true
			hit_furniture = true
	# All formal melee weapons share this one impact entry.  The force comes
	# from the weapon's configured knockback multiplier rather than a second
	# per-weapon door constant; the door applies its own lever-arm torque once.
	if world != null and world.has_method("apply_door_impact_near"):
		var door_force := CONFIG.gun_knockback_force * maxf(knockback_multiplier, 0.0)
		if bool(world.call("apply_door_impact_near", origin, direction, attack_range, door_force, StringName("melee_%s" % weapon_id), owner.get_instance_id())):
			hit_something = true
	if hit_furniture:
		melee_furniture_hit.emit(direction)
	return hit_something


func set_extra_attack(chance: float, delay: float) -> void:
	extra_attack_chance = clampf(chance, 0.0, 1.0)
	extra_attack_delay = maxf(delay, 0.0)


func get_cooldown_progress() -> float:
	return clampf(1.0 - cooldown_left / maxf(attack_interval, 0.001), 0.0, 1.0)


func apply_damage_upgrade(multiplier: float) -> void:
	damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	var safe_multiplier: float = maxf(multiplier, 0.01)
	attack_interval /= safe_multiplier
	impact_delay /= safe_multiplier


func apply_range_upgrade(pixels: float) -> void:
	attack_range += pixels
