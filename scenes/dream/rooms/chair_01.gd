extends RigidBody2D

const HIT_FLASH_SHADER := preload("res://shaders/sprite_alpha_outline.gdshader")
const CONFIG := preload("res://resources/demo_config.tres")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
## All formal furniture keeps its authored per-scene relative durability, then
## receives this single runtime multiplier exactly once on initialization.
const FORMAL_FURNITURE_HEALTH_MULTIPLIER := 5.0

## Furniture size is a gameplay authority.  It is intentionally resolved from
## the 2D ground footprint, never from Sprite/3D presentation bounds.
const SIZE_CATEGORY_AUTO := 0
const SIZE_CATEGORY_SMALL := 1
const SIZE_CATEGORY_MEDIUM := 2
const SIZE_CATEGORY_LARGE := 3
const VAULT_OVERRIDE_AUTO := 0
const VAULT_OVERRIDE_FORCE_ALLOW := 1
const VAULT_OVERRIDE_FORCE_DENY := 2

## AUTO thresholds are deliberately conservative.  Authored furniture with a
## semantic height/weight exception uses an explicit category in its scene.
const AUTO_SMALL_MAX_DIMENSION := 18.0
const AUTO_SMALL_MAX_AREA := 256.0
const AUTO_MEDIUM_MAX_DIMENSION := 40.0
const AUTO_MEDIUM_MAX_AREA := 700.0

@export var max_hp: float = 20.0
## Explicit gameplay metadata for the Player's Space action.  Visual height is
## intentionally not inferred from the sprite; scenes opt in only for low props.
@export var vaultable: bool = false
@export_enum("AUTO", "SMALL", "MEDIUM", "LARGE") var furniture_size_category: int = SIZE_CATEGORY_AUTO
@export_enum("AUTO", "FORCE_ALLOW", "FORCE_DENY") var vault_override: int = VAULT_OVERRIDE_AUTO
@export var bullet_knockback: float = 90.0
@export_range(0.02, 0.3, 0.01) var hit_flash_duration: float = 0.08

@export var shatter_piece_scene: PackedScene
@export var shatter_size: int = 8

@export var shatter_speed_min: float = 45.0
@export var shatter_speed_max: float = 100.0

@export var shatter_up_min: float = 35.0
@export var shatter_up_max: float = 75.0
## Rare Books drop is authored per furniture scene; empty means no drop.
@export_enum("none", "cabinet", "table", "trash_can") var books_drop_category: String = "none"
@export_range(0.0, 5.0, 0.05) var debris_disappear_start_delay: float = 0.8
@export_range(0.01, 0.5, 0.01) var debris_piece_interval_min: float = 0.03
@export_range(0.01, 0.5, 0.01) var debris_piece_interval_max: float = 0.08
## Swivel/Wheeled office chair physics mechanics
@export var is_swivel_chair: bool = false
@export var seat_angular_damp: float = 2.5
@export var seat_spin_sensitivity: float = 16.0

var hp: float
var authored_max_hp: float = 0.0
var seat_rotation: float = 0.0
var seat_angular_velocity: float = 0.0
var destroyed: bool = false
var hit_flash_tween: Tween
var hit_flash_material: ShaderMaterial
var impact_contacts: Dictionary = {}
var impact_last_hit_msec: Dictionary = {}
var previous_physics_velocity := Vector2.ZERO
var impact_grace_left := 0.0
var character_collision_exceptions: Dictionary = {}
var last_impact_sound_msec := -1000000
var last_damage_direction := Vector2.RIGHT
## Visual-only arrival arc for room encounter drops. Gameplay remains a 2D
## ground RigidBody2D at the authored cell; only the Sprite2D is lifted.
var sky_drop_height := 0.0
var sky_drop_vertical_velocity := 0.0
var sky_drop_gravity := 520.0
var sky_drop_base_position := Vector2.ZERO
var sky_drop_delay := 0.0
## Runtime room gate used by the 3D transition presentation.  It pauses the
## existing RigidBody/Area2D in place without resetting HP, destroyed state,
## velocity or the authoritative gameplay position.
var room_runtime_active := true
var room_saved_collision_layer := 0
var room_saved_collision_mask := 0
var room_saved_freeze := false
var room_saved_contact_monitor := false
var room_saved_visible := true
var resolved_size_category: int = SIZE_CATEGORY_AUTO


func _ready() -> void:
	if authored_max_hp <= 0.0:
		authored_max_hp = max_hp
	max_hp = authored_max_hp * FORMAL_FURNITURE_HEALTH_MULTIPLIER
	hp = max_hp
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	previous_physics_velocity = Vector2.ZERO
	impact_grace_left = CONFIG.furniture_impact_spawn_grace
	# Props layer 4；同时监听World、Player、Enemy、Props。Enemy使用layer 2。
	set_collision_mask_value(2, true)
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 8)
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	room_saved_collision_layer = collision_layer
	room_saved_collision_mask = collision_mask
	room_saved_freeze = freeze
	room_saved_contact_monitor = contact_monitor
	room_saved_visible = visible
	_setup_hit_flash_material()
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sky_drop_base_position = sprite.position
	resolved_size_category = resolve_size_category()
	# `vaultable` remains a compatibility property for the existing Dash/Vault
	# resolver.  Its final value is now derived from the shared category profile;
	# old serialized false values are not treated as FORCE_DENY.
	vaultable = is_vaultable()
	if not is_swivel_chair:
		var scene_path := scene_file_path.to_lower()
		var n_name := name.to_lower()
		var office_kind := String(get_meta(&"office_furniture_kind", "")).to_lower()
		if scene_path.contains("office_chair") or n_name.contains("office_chair") or office_kind == "chair" or office_kind.contains("office_chair"):
			is_swivel_chair = true
	if is_swivel_chair:
		if linear_damp > 2.0:
			linear_damp = 1.2
		if mass > 2.0:
			mass = 1.25
	set_physics_process(true)
	if not sleeping_state_changed.is_connected(_on_chair_sleeping_state_changed):
		sleeping_state_changed.connect(_on_chair_sleeping_state_changed)


func get_gameplay_footprint_half_extents() -> Vector2:
	## Return world-axis half extents of the ground CollisionShape2D.
	## The CollisionShape2D transform is included, so authored node scale and
	## any legacy local offset are represented correctly. Hurtbox/visual bounds
	## are not part of this authority.
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return Vector2(8.0, 8.0)
	var rect := collision.shape.get_rect()
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in corners:
		var world_corner := collision.to_global(corner)
		minimum.x = minf(minimum.x, world_corner.x)
		minimum.y = minf(minimum.y, world_corner.y)
		maximum.x = maxf(maximum.x, world_corner.x)
		maximum.y = maxf(maximum.y, world_corner.y)
	return (maximum - minimum) * 0.5


func get_gameplay_footprint_center() -> Vector2:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	return collision.global_position if collision != null else global_position


func resolve_size_category() -> int:
	if furniture_size_category != SIZE_CATEGORY_AUTO:
		return furniture_size_category
	var half_extents := get_gameplay_footprint_half_extents()
	var dimensions := half_extents * 2.0
	var area := dimensions.x * dimensions.y
	var maximum_dimension := maxf(dimensions.x, dimensions.y)
	if maximum_dimension <= AUTO_SMALL_MAX_DIMENSION and area <= AUTO_SMALL_MAX_AREA:
		return SIZE_CATEGORY_SMALL
	if maximum_dimension <= AUTO_MEDIUM_MAX_DIMENSION and area <= AUTO_MEDIUM_MAX_AREA:
		return SIZE_CATEGORY_MEDIUM
	return SIZE_CATEGORY_LARGE


func get_size_category() -> int:
	if resolved_size_category == SIZE_CATEGORY_AUTO:
		resolved_size_category = resolve_size_category()
	return resolved_size_category


func get_size_category_name() -> StringName:
	match get_size_category():
		SIZE_CATEGORY_SMALL:
			return &"SMALL"
		SIZE_CATEGORY_MEDIUM:
			return &"MEDIUM"
		SIZE_CATEGORY_LARGE:
			return &"LARGE"
		_:
			return &"AUTO"


func _profile_value(property_name: StringName, fallback: float) -> float:
	var value: Variant = CONFIG.get(property_name)
	return fallback if value == null else maxf(float(value), 0.0)


func get_push_response() -> float:
	match get_size_category():
		SIZE_CATEGORY_SMALL:
			return _profile_value(&"furniture_small_push_response", 1.25)
		SIZE_CATEGORY_LARGE:
			return _profile_value(&"furniture_large_push_response", 0.65)
		_:
			return _profile_value(&"furniture_medium_push_response", 1.0)


func get_kick_response() -> float:
	match get_size_category():
		SIZE_CATEGORY_SMALL:
			return _profile_value(&"furniture_small_kick_response", 1.25)
		SIZE_CATEGORY_LARGE:
			return _profile_value(&"furniture_large_kick_response", 0.0)
		_:
			return _profile_value(&"furniture_medium_kick_response", 0.80)


func get_combat_impulse_response() -> float:
	match get_size_category():
		SIZE_CATEGORY_SMALL:
			return _profile_value(&"furniture_small_combat_impulse_response", 1.10)
		SIZE_CATEGORY_LARGE:
			return _profile_value(&"furniture_large_combat_impulse_response", 0.35)
		_:
			return _profile_value(&"furniture_medium_combat_impulse_response", 0.85)


func is_vaultable() -> bool:
	if vault_override == VAULT_OVERRIDE_FORCE_ALLOW:
		return true
	if vault_override == VAULT_OVERRIDE_FORCE_DENY:
		return false
	return get_size_category() != SIZE_CATEGORY_LARGE


func _contact_offset(contact_point: Variant) -> Vector2:
	if not contact_point is Vector2:
		return Vector2.ZERO
	# A force is applied at the actual 2D contact, with a footprint-sized cap so
	# a distant attack source cannot create an absurd lever arm.
	var local_point: Vector2 = to_local(contact_point as Vector2)
	var half := get_gameplay_footprint_half_extents()
	local_point.x = clampf(local_point.x, -half.x, half.x)
	local_point.y = clampf(local_point.y, -half.y, half.y)
	return local_point.rotated(global_rotation)


func _apply_contact_force(force: Vector2, contact_point: Variant = null) -> void:
	wake_furniture_physics()
	var offset := _contact_offset(contact_point)
	if offset.length_squared() > 0.01:
		apply_force(force, offset)
	else:
		apply_central_force(force)


func _apply_contact_impulse(impulse: Vector2, contact_point: Variant = null) -> void:
	wake_furniture_physics()
	var offset := _contact_offset(contact_point)
	if offset.length_squared() > 0.01:
		apply_impulse(impulse, offset)
	else:
		apply_central_impulse(impulse)


func apply_player_push(direction: Vector2, base_force: float, alignment: float = 1.0, contact_point: Variant = null) -> bool:
	if destroyed or base_force <= 0.0 or direction.length_squared() <= 0.0001:
		return false
	var response := get_push_response()
	if response <= 0.0:
		return false
	_apply_contact_force(
		direction.normalized()
		* base_force
		* response
		* clampf(alignment, 0.0, 1.0),
		contact_point
	)
	return true


func apply_player_kick_impulse(direction: Vector2, base_impulse: float, contact_point: Variant = null) -> bool:
	if destroyed or base_impulse <= 0.0 or direction.length_squared() <= 0.0001:
		return false
	var response := get_kick_response()
	if response <= 0.0:
		return false
	_apply_contact_impulse(direction.normalized() * base_impulse * response, contact_point)
	if is_swivel_chair:
		_apply_swivel_hit_torque(direction, 1.0, contact_point)
	return true


func apply_external_impulse(direction: Vector2, base_impulse: float, contact_point: Variant = null) -> bool:
	if destroyed or base_impulse <= 0.0 or direction.length_squared() <= 0.0001:
		return false
	var response := get_combat_impulse_response()
	if response <= 0.0:
		return false
	_apply_contact_impulse(direction.normalized() * base_impulse * response, contact_point)
	return true


func set_room_runtime_active(active: bool) -> void:
	if room_runtime_active == active:
		if not active:
			visible = false
		return
	room_runtime_active = active
	var hurtbox := get_node_or_null("Hurtbox") as Area2D
	var hurt_collision := hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D if hurtbox != null else null
	if not active:
		room_saved_collision_layer = collision_layer
		room_saved_collision_mask = collision_mask
		room_saved_freeze = freeze
		room_saved_contact_monitor = contact_monitor
		room_saved_visible = visible
		visible = false
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		freeze = true
		sleeping = true
		contact_monitor = false
		set_physics_process(false)
		if hurtbox != null:
			hurtbox.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitorable", false)
		if hurt_collision != null:
			hurt_collision.set_deferred("disabled", true)
		return
	set_deferred("collision_layer", room_saved_collision_layer)
	set_deferred("collision_mask", room_saved_collision_mask)
	freeze = room_saved_freeze
	contact_monitor = room_saved_contact_monitor
	visible = room_saved_visible and not destroyed
	set_physics_process(true)
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
	if hurt_collision != null:
		hurt_collision.set_deferred("disabled", false)


func notify_visual_dirty() -> void:
	if has_meta(&"depth_visual_bridge"):
		var bridge_ref: Variant = get_meta(&"depth_visual_bridge")
		if bridge_ref is WeakRef:
			var bridge: Variant = bridge_ref.get_ref()
			if bridge != null and is_instance_valid(bridge) and bridge.has_method("mark_visual_dirty"):
				bridge.call("mark_visual_dirty")
	if has_meta(&"furniture_3d_visual"):
		var visual_ref: Variant = get_meta(&"furniture_3d_visual")
		if visual_ref is WeakRef:
			var visual: Variant = visual_ref.get_ref()
			if visual != null and is_instance_valid(visual) and visual.has_method("wake_visual_process"):
				visual.call("wake_visual_process")


var _cached_sprite: Sprite2D

func wake_furniture_physics() -> void:
	if room_runtime_active and not destroyed:
		set_physics_process(true)

func _on_chair_sleeping_state_changed() -> void:
	if not sleeping:
		wake_furniture_physics()

func _physics_process(_delta: float) -> void:
	var delta := _delta
	var needs_work := false
	if sky_drop_delay > 0.0 or sky_drop_height > 0.0:
		needs_work = true
		if _cached_sprite == null:
			_cached_sprite = get_node_or_null(^"Sprite2D") as Sprite2D
		var sprite := _cached_sprite
		if sprite != null:
			if sky_drop_delay > 0.0:
				sky_drop_delay = maxf(0.0, sky_drop_delay - delta)
			elif sky_drop_height > 0.0:
				sky_drop_vertical_velocity -= sky_drop_gravity * delta
				sky_drop_height = maxf(0.0, sky_drop_height + sky_drop_vertical_velocity * delta)
				sprite.position = sky_drop_base_position + Vector2(0.0, -sky_drop_height)
				if sky_drop_height <= 0.0:
					sky_drop_vertical_velocity = 0.0
					sprite.position = sky_drop_base_position
	if not character_collision_exceptions.is_empty():
		needs_work = true
		var now_msec := Time.get_ticks_msec()
		for id_variant in character_collision_exceptions.keys():
			var collider_id := int(id_variant)
			if now_msec < int(character_collision_exceptions[collider_id]):
				continue
			character_collision_exceptions.erase(collider_id)
			if is_instance_id_valid(collider_id):
				var body := instance_from_id(collider_id) as PhysicsBody2D
				if body != null:
					remove_collision_exception_with(body)
	if is_swivel_chair and not destroyed:
		if absf(seat_angular_velocity) > 0.001:
			needs_work = true
			seat_rotation += seat_angular_velocity * delta
			seat_rotation = wrapf(seat_rotation, -PI, PI)
			seat_angular_velocity = move_toward(seat_angular_velocity, 0.0, absf(seat_angular_velocity) * seat_angular_damp * delta)
			notify_visual_dirty()
		else:
			seat_angular_velocity = 0.0
	if not destroyed:
		var vel_sq := linear_velocity.length_squared()
		if vel_sq >= 4.0:
			needs_work = true
			notify_visual_dirty()
			if vel_sq >= 36.0:
				var world := get_tree().get_first_node_in_group(&"dream_world")
				if world != null and world.has_method("try_transfer_furniture_through_door"):
					world.try_transfer_furniture_through_door(self)
	if not needs_work and (sleeping or freeze) and character_collision_exceptions.is_empty():
		set_physics_process(false)


func start_sky_drop(height_pixels: float = 96.0, delay_seconds: float = 0.0) -> void:
	wake_furniture_physics()
	if _cached_sprite == null:
		_cached_sprite = get_node_or_null(^"Sprite2D") as Sprite2D
	var sprite := _cached_sprite
	if sprite == null:
		return
	sky_drop_base_position = sprite.position
	sky_drop_height = maxf(height_pixels, 0.0)
	sky_drop_vertical_velocity = 0.0
	sky_drop_delay = maxf(delay_seconds, 0.0)
	sprite.position = sky_drop_base_position + Vector2(0.0, -sky_drop_height)


## 共享家具物理回调：只有新发生且速度达标的Player/Enemy碰撞造成固定20伤害。
## 当前接触集合与时间冷却同时防止持续挤压时逐物理帧重复结算。
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if destroyed:
		return
	impact_grace_left = maxf(0.0, impact_grace_left - state.step)
	if impact_grace_left > 0.0:
		# Keep real collisions enabled during activation, but do not interpret the
		# physics solver's initial separation impulse as a damaging furniture hit.
		impact_contacts.clear()
		previous_physics_velocity = state.linear_velocity
		return
	var observed: Dictionary = {}
	# The solver may already have reduced current velocity on the first contact
	# frame. Retain the preceding physics-frame velocity so a genuinely fast
	# chair cannot lose its impact eligibility merely because collision worked.
	var impact_velocity := state.linear_velocity
	if previous_physics_velocity.length_squared() > impact_velocity.length_squared():
		impact_velocity = previous_physics_velocity
	var impact_speed := impact_velocity.length()
	var resolved_velocity := state.linear_velocity
	var combined_boundary_normal := Vector2.ZERO
	var boundary_retention := 1.0
	for contact_index in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(contact_index) as Node
		if collider == null:
			continue
		var collider_id := collider.get_instance_id()
		observed[collider_id] = true
		# A fast-moving furniture body is an explicit impact source for a physical
		# door.  Stationary contact remains a normal boundary collision and never
		# opens the door; the cooldown also prevents one impact from being queued
		# every physics frame while the prop rests against the leaf.
		if collider.has_meta(&"physical_door") and bool(collider.get_meta(&"physical_door", false)):
			var door_now_msec := Time.get_ticks_msec()
			var door_cooldown_msec := int(CONFIG.furniture_impact_target_cooldown * 1000.0)
			if impact_speed >= CONFIG.furniture_impact_minimum_speed and door_now_msec - int(impact_last_hit_msec.get(collider_id, -door_cooldown_msec)) >= door_cooldown_msec:
				impact_last_hit_msec[collider_id] = door_now_msec
				call_deferred("_apply_door_impact_by_id", collider_id, impact_velocity.normalized(), impact_speed)
			combined_boundary_normal += state.get_contact_local_normal(contact_index).rotated(state.transform.get_rotation()).normalized()
			boundary_retention = minf(boundary_retention, CONFIG.furniture_wall_bounce_retention)
			continue
		var is_character := collider.is_in_group("dream_enemies")
		if is_character and not impact_contacts.has(collider_id) and impact_speed >= CONFIG.furniture_impact_minimum_speed:
			var now_msec := Time.get_ticks_msec()
			var cooldown_msec := int(CONFIG.furniture_impact_target_cooldown * 1000.0)
			if now_msec - int(impact_last_hit_msec.get(collider_id, -cooldown_msec)) >= cooldown_msec:
				impact_contacts[collider_id] = true
				impact_last_hit_msec[collider_id] = now_msec
				call_deferred("_deal_impact_damage_by_id", collider_id, impact_velocity.normalized(), impact_speed)
				call_deferred("_temporarily_ignore_character_by_id", collider_id)
				if now_msec - last_impact_sound_msec >= 80:
					last_impact_sound_msec = now_msec
					SFX.play_event(&"furniture_impact")
				# 命中角色只损失部分速度，仍可继续命中路径上的其他目标。
				resolved_velocity = impact_velocity * CONFIG.furniture_velocity_retention_after_character_hit
				# 越过接触面，避免角色PhysicsBody在下一帧把高速家具吸停。
				state.transform.origin += impact_velocity.normalized() * 2.0
			continue
		var local_normal := state.get_contact_local_normal(contact_index)
		var world_normal := local_normal.rotated(state.transform.get_rotation()).normalized()
		if collider is RigidBody2D and collider.is_in_group(&"pushable_prop"):
			var transfer := impact_velocity * CONFIG.furniture_prop_impulse_multiplier
			call_deferred("_transfer_impulse_by_id", collider_id, transfer)
			combined_boundary_normal += world_normal
			boundary_retention = minf(boundary_retention, CONFIG.furniture_prop_bounce_retention)
		else:
			combined_boundary_normal += world_normal
			boundary_retention = minf(boundary_retention, CONFIG.furniture_wall_bounce_retention)
	# 墙角可能同时报告两条接触法线；合并后只反射一次，避免连续bounce互相抵消并锁死。
	if combined_boundary_normal.length_squared() > 0.001:
		resolved_velocity = impact_velocity.bounce(combined_boundary_normal.normalized()) * boundary_retention
		if impact_speed >= CONFIG.furniture_impact_minimum_speed:
			var wall_now_msec := Time.get_ticks_msec()
			if wall_now_msec - last_impact_sound_msec >= 100:
				last_impact_sound_msec = wall_now_msec
				SFX.play_event(&"wall_impact")
	for previous_id in impact_contacts.keys():
		if not observed.has(previous_id):
			impact_contacts.erase(previous_id)
	var limited_velocity := resolved_velocity.limit_length(CONFIG.maximum_knockback_speed)
	# The direct-state setter wakes the body even if the velocity is identical.
	# Let the engine sleep resting furniture; every actual bounce/clamp still
	# writes its exact velocity and real pushes/impulses wake bodies normally.
	if not bool(get_meta(&"test_skip_unchanged_furniture_velocity",true)) or limited_velocity != state.linear_velocity:
		state.linear_velocity = limited_velocity
	previous_physics_velocity = state.linear_velocity


func _apply_door_impact_by_id(collider_id: int, impact_direction: Vector2, impact_speed: float) -> void:
	if not is_instance_id_valid(collider_id):
		return
	var collider := instance_from_id(collider_id) as Node
	if collider == null or not collider.has_meta(&"physical_door"):
		return
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("resolve_door_impact_from_collision"):
		# Mass × relative speed is the existing furniture physics impulse scale;
		# Door converts it into a bounded hinge impulse at the collision position.
		world.call(
			"resolve_door_impact_from_collision",
			collider,
			global_position,
			impact_direction,
			mass * impact_speed,
			&"furniture"
		)


func _temporarily_ignore_character_by_id(collider_id: int) -> void:
	if not is_instance_id_valid(collider_id):
		return
	var body := instance_from_id(collider_id) as PhysicsBody2D
	if body == null:
		return
	add_collision_exception_with(body)
	character_collision_exceptions[collider_id] = Time.get_ticks_msec() + maxi(120, int(CONFIG.furniture_impact_target_cooldown * 1000.0))


func _deal_impact_damage_by_id(target_instance_id: int, impact_direction: Vector2, impact_speed: float = -1.0) -> void:
	if not is_instance_id_valid(target_instance_id):
		return
	var target_node := instance_from_id(target_instance_id) as Node
	if destroyed or not is_instance_valid(target_node):
		return
	if target_node.is_in_group("dream_enemies") and target_node.has_method("take_damage"):
		target_node.set_meta(&"last_damage_source", &"furniture_impact")
		var resolved_speed := CONFIG.furniture_impact_minimum_speed if impact_speed < 0.0 else impact_speed
		var knockdown_force := maxf(CONFIG.furniture_impact_enemy_knockback, resolved_speed * CONFIG.furniture_impact_knockdown_force_multiplier)
		if target_node.has_method("start_knockdown"):
			# 把实际冲击力度传进伤害接口，致死时身体零件也会沿真实家具速度飞出。
			target_node.take_damage(CONFIG.furniture_impact_damage, global_position, knockdown_force, &"furniture_impact")
			if is_instance_valid(target_node) and not bool(target_node.get("dead")):
				target_node.start_knockdown(impact_direction, &"furniture_impact", knockdown_force)
		else:
			target_node.take_damage(CONFIG.furniture_impact_damage, global_position)
			if target_node.has_method("apply_knockback"):
				target_node.apply_knockback(impact_direction, CONFIG.furniture_impact_enemy_knockback)


## 保留同步测试/旧调用入口；跨Physics帧的正式路径始终传instance_id。
func _deal_impact_damage(target_node: Node, impact_direction: Vector2, impact_speed: float = -1.0) -> void:
	if is_instance_valid(target_node):
		var target_id := target_node.get_instance_id()
		impact_contacts[target_id] = true
		impact_last_hit_msec[target_id] = Time.get_ticks_msec()
		_deal_impact_damage_by_id(target_id, impact_direction, impact_speed)


func _transfer_impulse_by_id(target_instance_id: int, impulse: Vector2) -> void:
	if not is_instance_id_valid(target_instance_id):
		return
	var body := instance_from_id(target_instance_id) as RigidBody2D
	if body != null and body != self:
		if body.has_method(&"_apply_contact_impulse"):
			body.call(&"_apply_contact_impulse", impulse, global_position)
		else:
			body.apply_central_impulse(impulse)


func _exit_tree() -> void:
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()


func take_damage(
	damage: float,
	hit_direction: Vector2,
	knockback_multiplier: float = 1.0,
	contact_point: Variant = null
) -> void:
	if destroyed or damage <= 0.0 or not is_damage_runtime_active():
		return

	hp -= damage
	if hit_direction.length_squared() > 0.001:
		last_damage_direction = hit_direction.normalized()
	_play_hit_flash()
	notify_visual_dirty()

	# 普通命中颗粒
	play_hit_particles(hit_direction)

	# Every effective furniture damage event has one centralized 0~1 debris
	# roll.  The World owns atlas selection, room validation and spray motion so
	# bullets, melee and kicks cannot grow parallel drop implementations.
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("spawn_furniture_damage_debris"):
		world.spawn_furniture_damage_debris(self, hit_direction)

	# 被子弹击中后的物理击退
	if hit_direction.length_squared() > 0.0:
		apply_combat_impulse(
			hit_direction,
			CONFIG.gun_knockback_force * maxf(knockback_multiplier, 0.0),
			contact_point
		)

	if hp <= 0.0:
		destroy()


## All combat sources feed the same RigidBody impulse path. Damage and force
## remain independent, and heavy furniture naturally moves less because its
## authored mass is still authoritative.
func apply_combat_impulse(hit_direction: Vector2, force: float, contact_point: Variant = null) -> void:
	if destroyed or force <= 0.0 or hit_direction.length_squared() <= 0.0001:
		return
	var response := get_combat_impulse_response()
	if response <= 0.0:
		return
	_apply_contact_impulse(hit_direction.normalized() * force * response, contact_point)
	if is_swivel_chair:
		var mult: float = force / CONFIG.gun_knockback_force
		_apply_swivel_hit_torque(hit_direction, mult, contact_point)


func _apply_swivel_hit_torque(hit_direction: Vector2, multiplier: float = 1.0, contact_point: Variant = null) -> void:
	if not is_swivel_chair or destroyed:
		return
	wake_furniture_physics()
	var norm_dir := hit_direction.normalized()
	var offset := _contact_offset(contact_point) if contact_point != null else Vector2.ZERO
	var torque_factor := 0.0
	var arm_len := offset.length()
	var footprint_radius := maxf(get_gameplay_footprint_half_extents().length(), 12.0)

	if arm_len > 1.5:
		# 2D cross product: r.x * F.y - r.y * F.x
		torque_factor = (offset.x * norm_dir.y - offset.y * norm_dir.x) / footprint_radius

	# If hit was near center, add a slight randomized deflection spin
	if absf(torque_factor) < 0.25:
		var random_sign := 1.0 if randf() > 0.5 else -1.0
		torque_factor += random_sign * randf_range(0.4, 0.7)

	torque_factor = clampf(torque_factor, -1.5, 1.5)
	var spin_impulse: float = torque_factor * seat_spin_sensitivity * maxf(multiplier, 0.6)
	seat_angular_velocity = clampf(seat_angular_velocity + spin_impulse, -45.0, 45.0)
	notify_visual_dirty()


## Inactive cached rooms share world coordinates with the visible room. Their
## props must not be damageable even when a projectile performs a manual group scan.
func is_damage_runtime_active() -> bool:
	if not room_runtime_active:
		return false
	var ancestor: Node = self
	while ancestor != null:
		# Avoid a hard DreamRoomTemplate type dependency here.  Furniture scenes
		# are also used by the standalone random-building prototype, and the
		# template itself preloads these scenes; duck-typing keeps that resource
		# graph acyclic while preserving the authored room activity contract.
		if ancestor.has_method("get_room_arena_bounds") and ancestor.get("room_active") != null:
			# A direct neighbour is intentionally hidden but remains simulated so
			# projectiles/melee and physical furniture motion can cross an open door.
			return bool(ancestor.get("room_active")) or bool(ancestor.get("room_simulation_active"))
		ancestor = ancestor.get_parent()
	# A hidden source CanvasLayer is the 3D presentation boundary, not an
	# inactive room. Keep formal furniture damage enabled for a live bridge.
	if has_meta(&"depth_visual_bridge"):
		var bridge: Variant = get_meta(&"depth_visual_bridge")
		if bridge is WeakRef and is_instance_valid(bridge.get_ref()):
			return visible and is_inside_tree()
	if visible and is_inside_tree():
		var p: Node = get_parent()
		while p != null:
			if p is CanvasLayer:
				return true
			p = p.get_parent()
	return is_visible_in_tree()


func begin_impact_grace() -> void:
	impact_grace_left = maxf(impact_grace_left, CONFIG.furniture_impact_spawn_grace)
	impact_contacts.clear()
	previous_physics_velocity = linear_velocity


func reset_spawn_physics() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	previous_physics_velocity = Vector2.ZERO
	begin_impact_grace()


func _setup_hit_flash_material() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	# 每个家具实例持有独立ShaderMaterial；同源场景的其它家具不会同步闪白。
	hit_flash_material = ShaderMaterial.new()
	hit_flash_material.shader = HIT_FLASH_SHADER
	hit_flash_material.set_shader_parameter("outline_enabled", 0.0)
	hit_flash_material.set_shader_parameter("outline_only", 0.0)
	hit_flash_material.set_shader_parameter("flash_amount", 0.0)
	sprite.material = hit_flash_material


func _play_hit_flash() -> void:
	if destroyed or hit_flash_material == null:
		return
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	hit_flash_material.set_shader_parameter("flash_amount", 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.set_trans(Tween.TRANS_LINEAR)
	hit_flash_tween.tween_method(_set_hit_flash_amount, 1.0, 0.0, maxf(hit_flash_duration, 0.02))


func _set_hit_flash_amount(value: float) -> void:
	if hit_flash_material != null:
		hit_flash_material.set_shader_parameter("flash_amount", clampf(value, 0.0, 1.0))


func play_hit_particles(hit_direction: Vector2) -> void:
	var particles := get_node_or_null(
		"HitParticles"
	) as CPUParticles2D

	if particles == null:
		return

	if hit_direction.length_squared() > 0.0:
		particles.direction = hit_direction.normalized()

	particles.restart()
	particles.emitting = true


func spawn_texture_shatter() -> void:
	var sprite := get_node_or_null(
		"Sprite2D"
	) as Sprite2D

	if sprite == null:
		push_warning(
			"无法碎裂家具：没有找到 Sprite2D。"
		)
		return

	if sprite.texture == null:
		push_warning(
			"无法碎裂家具：Sprite2D 没有 Texture。"
		)
		return

	if shatter_piece_scene == null:
		push_warning(
			"无法碎裂家具：没有设置 Shatter Piece Scene。"
		)
		return

	if shatter_size <= 0:
		push_warning(
			"无法碎裂家具：Shatter Size 必须大于 0。"
		)
		return

	var debris_root := _find_room_debris_root()

	if debris_root == null:
		push_warning(
			"无法碎裂家具：没有找到 ground_debris_root。"
		)
		return

	var source_texture: Texture2D
	var source_region: Rect2

	# ------------------------------
	# AtlasTexture
	# ------------------------------
	if sprite.texture is AtlasTexture:
		var atlas_texture := sprite.texture as AtlasTexture

		if atlas_texture == null:
			return

		source_texture = atlas_texture.atlas
		source_region = atlas_texture.region

	# ------------------------------
	# 普通 Texture + Sprite Region
	# ------------------------------
	else:
		source_texture = sprite.texture

		if sprite.region_enabled:
			source_region = sprite.region_rect
		else:
			source_region = Rect2(
				Vector2.ZERO,
				source_texture.get_size()
			)

	if source_texture == null:
		push_warning(
			"无法碎裂家具：源纹理为空。"
		)
		return

	if source_region.size.x <= 0.0:
		return

	if source_region.size.y <= 0.0:
		return

	# Sprite 左上角局部位置
	var sprite_top_left: Vector2 = sprite.offset

	if sprite.centered:
		sprite_top_left -= source_region.size * 0.5

	# 家具只切成沿最长轴分开的两段，仍然直接采样当前Sprite的正式材质Region。
	for piece_index in range(2):
		var piece_region := source_region
		var local_piece_origin := Vector2.ZERO
		if source_region.size.x >= source_region.size.y:
			var first_width := floorf(source_region.size.x * 0.5)
			var piece_width := first_width if piece_index == 0 else source_region.size.x - first_width
			var offset_x := 0.0 if piece_index == 0 else first_width
			piece_region = Rect2(source_region.position + Vector2(offset_x, 0.0), Vector2(piece_width, source_region.size.y))
			local_piece_origin = Vector2(offset_x, 0.0)
		else:
			var first_height := floorf(source_region.size.y * 0.5)
			var piece_height := first_height if piece_index == 0 else source_region.size.y - first_height
			var offset_y := 0.0 if piece_index == 0 else first_height
			piece_region = Rect2(source_region.position + Vector2(0.0, offset_y), Vector2(source_region.size.x, piece_height))
			local_piece_origin = Vector2(0.0, offset_y)

		var piece_texture := AtlasTexture.new()

		piece_texture.atlas = source_texture
		piece_texture.region = piece_region
		piece_texture.filter_clip = true

		var piece := shatter_piece_scene.instantiate() as Node2D

		if piece == null:
			continue

		debris_root.add_child(piece)

		var local_offset := sprite_top_left + local_piece_origin + piece_region.size * 0.5

		piece.global_position = sprite.to_global(local_offset)

		var direction := (piece.global_position - sprite.global_position).normalized()

		if direction.length_squared() <= 0.001:
			direction = Vector2.LEFT if piece_index == 0 else Vector2.RIGHT

		direction = direction.rotated(randf_range(-0.3, 0.3))

		var scatter_velocity := direction * randf_range(shatter_speed_min, shatter_speed_max)

		var upward_velocity := randf_range(shatter_up_min, shatter_up_max)

		if piece.has_method("setup"):
			piece.call("setup", piece_texture, scatter_velocity, upward_velocity, debris_disappear_start_delay)
		var world := get_tree().get_first_node_in_group(&"dream_world")
		if world != null and world.has_method("register_depth_visual"):
			world.call("register_depth_visual", piece, [^"Sprite2D"])


## 优先使用当前家具所属Room自己的残骸容器，避免多房间缓存时把碎片生成到别的Room。
func _find_room_debris_root() -> Node2D:
	var ancestor := get_parent()
	while ancestor != null:
		var local_root := ancestor.get_node_or_null("GroundDebrisRoot") as Node2D
		if local_root != null and local_root.is_in_group("ground_debris_root"):
			return local_root
		ancestor = ancestor.get_parent()
	return get_tree().get_first_node_in_group("ground_debris_root") as Node2D


func destroy() -> void:
	if destroyed:
		return

	destroyed = true
	notify_visual_dirty()
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()

	# Destruction is guarded above, so the extra 0~3 debris burst happens once
	# per furniture lifetime and after the lethal hit has already been accepted.
	var world_for_debris := get_tree().get_first_node_in_group(&"dream_world")
	if world_for_debris != null and world_for_debris.has_method("spawn_furniture_destroy_debris"):
		world_for_debris.spawn_furniture_destroy_debris(self, last_damage_direction)

	# 必须在隐藏原图之前生成碎片（未被 3D 视觉接管时生成 2D 切片碎片）
	if not bool(get_meta(&"has_3d_visual", false)):
		spawn_texture_shatter()

	# 只在最终销毁入口抽取一次；Books不参与普通房间武器生成池。
	if books_drop_category != "none":
		var world := get_tree().get_first_node_in_group(&"dream_world")
		if world != null and world.has_method("try_drop_books_from_furniture"):
			world.try_drop_books_from_furniture(self, StringName(books_drop_category))

	# 隐藏家具本体
	var sprite := get_node_or_null(
		"Sprite2D"
	) as Sprite2D

	if sprite != null:
		sprite.hide()

	# 隐藏家具底部圆形阴影
	var shadow := get_node_or_null(
		"Shadow"
	) as Sprite2D

	if shadow != null:
		shadow.hide()

	notify_visual_dirty()

	# 关闭家具实体碰撞
	var body_collision := get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if body_collision != null:
		body_collision.set_deferred(
			"disabled",
			true
		)

	# 关闭 Hurtbox Collision
	var hurtbox_collision := get_node_or_null(
		"Hurtbox/CollisionShape2D"
	) as CollisionShape2D

	if hurtbox_collision != null:
		hurtbox_collision.set_deferred(
			"disabled",
			true
		)

	# 关闭 Hurtbox
	var hurtbox := get_node_or_null(
		"Hurtbox"
	) as Area2D

	if hurtbox != null:
		hurtbox.set_deferred(
			"monitoring",
			false
		)

		hurtbox.set_deferred(
			"monitorable",
			false
		)

	# 如果还有旧 BreakParticles，
	# 可以继续作为辅助爆碎效果
	var break_particles := get_node_or_null(
		"BreakParticles"
	) as CPUParticles2D

	if break_particles != null:
		break_particles.restart()
		break_particles.emitting = true

	await get_tree().create_timer(0.6).timeout

	queue_free()
