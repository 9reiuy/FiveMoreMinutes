class_name WorldWeaponPickup
extends RigidBody2D
var _cached_dream_world: Node
## Shared per-frame group list for thrown-weapon mutual exceptions.
static var _pickup_group_cache: Array = []
static var _pickup_group_cache_frame: int = -1

const DREAM_GUN_ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")
const CONFIG := preload("res://resources/demo_config.tres")
const PICKUP_SHINE_SHADER := preload("res://shaders/world_weapon_pickup_shine.gdshader")
## Shared throw-flight constants. The Player trajectory predictor reads the
## same values consumed by the real pickup flight instead of inventing a
## second ballistic model.
const DEFAULT_THROW_FAKE_HEIGHT_PEAK_PIXELS := 24.0
const DEFAULT_THROW_FAKE_HEIGHT_LAUNCH_VELOCITY := 220.0
const DEFAULT_THROW_FAKE_HEIGHT_GRAVITY := 540.0
const THROW_COLLISION_SHAPE_SIZE := Vector2(26.0, 12.0)

@export_enum("basic", "shotgun", "lucille", "assault_rifle", "books") var weapon_id := "basic"
@export_range(0, 3, 1) var skin_index := 0
@export_range(16.0, 64.0, 1.0) var interaction_radius := 34.0

@onready var weapon_sprite: Sprite2D = $WeaponSprite
@onready var shadow: Sprite2D = $Shadow
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_collision: CollisionShape2D = $InteractionArea/CollisionShape2D

var player_in_range := false
var interaction_targeted := false
var pickup_shine_material: ShaderMaterial
var pickup_shine_phase_offset := 0.0
var reserved_by: Node
## AI reservations are deliberately soft.  The item remains WORLD-owned until
## an ownership commit, and an explicit Player request always has priority over
## an Enemy reservation in the same gameplay tick.
enum OwnershipState { WORLD, PLAYER_CLAIMED, ENEMY_CLAIMED }
var ownership_state: OwnershipState = OwnershipState.WORLD
var claimed_by: Node
var default_linear_damp: float = 7.0
var default_angular_damp: float = 8.0
var default_continuous_cd: int = 0
var default_collision_layer: int = 0
var default_collision_mask: int = 0
## Authored body layers are retained as the temporary THROWN profile.  Ground
## and LANDED pickups deliberately use no solid body collision; only the
## InteractionArea remains available for pickup queries.
var thrown_collision_layer: int = 8
var thrown_collision_mask: int = 15
var default_freeze := false
## Presentation/runtime gate used by the generated Room Graph.  A pickup keeps
## its authoritative 2D position, ownership and throw state while an inactive
## room is isolated from physics and interaction.
var room_runtime_active := true
var room_saved_visible := true
var room_saved_contact_monitor := false
var room_saved_interaction_monitoring := true
var room_saved_interaction_monitorable := true
var room_saved_interaction_disabled := false
## Optional handoff value captured from the Player's effective held Sprite scale.
## A negative value means use the shared held-weapon scale for regular drops.
var visual_scale_override: float = -1.0
## Shadow is a ground projection, not part of the rotating/fake-height weapon
## visual.  Keep its authored offset/scale while the rigid body spins.
var shadow_ground_offset := Vector2.ZERO
var shadow_base_scale := Vector2.ONE
## Encounter drops use the same 2D ground position as every other weapon.  The
## vertical arrival is only a visual offset consumed by the shared depth bridge
## and never changes the gameplay transform or ownership rules.
var sky_drop_height := 0.0
var sky_drop_vertical_velocity := 0.0
var sky_drop_gravity := 520.0
var sky_drop_base_position := Vector2.ZERO
var sky_drop_delay := 0.0
## Thrown weapons keep their authoritative RigidBody2D on the ground plane, but
## their visual carrier follows a short fake-height arc so a flying weapon is
## drawn above settled floor loot.  The bridge consumes `fake_height`; no
## gameplay transform or collision is moved vertically.
@export_range(8.0, 64.0, 1.0) var throw_fake_height_peak_pixels: float = DEFAULT_THROW_FAKE_HEIGHT_PEAK_PIXELS
@export_range(40.0, 600.0, 10.0) var throw_fake_height_launch_velocity: float = DEFAULT_THROW_FAKE_HEIGHT_LAUNCH_VELOCITY
@export_range(100.0, 1200.0, 10.0) var throw_fake_height_gravity: float = DEFAULT_THROW_FAKE_HEIGHT_GRAVITY
var fake_height := 0.0
var throw_fake_height := 0.0
var throw_fake_vertical_velocity := 0.0
var throw_fake_base_position := Vector2.ZERO

## held -> thrown -> dropped is one WorldWeapon lifecycle.  Throw damage is
## enabled only while the real RigidBody is moving above the danger threshold.
var thrown_active := false
var throw_damage := 0.0
var throw_force := 0.0
var thrower_instance_id := 0
var throw_pickup_lockout_left := 0.0
var thrower_left_pickup_radius := false
var throw_elapsed := 0.0
var thrown_hit_targets: Dictionary = {}
## A thrown pickup temporarily uses the authored world collision mask (walls,
## doors and furniture remain solid) and opts out of collisions with the other
## WorldWeaponPickup bodies.  Ground/LANDED items use no solid body mask.
## Weak references let the exception policy survive pickups being freed while
## the throw is in flight.
var thrown_weapon_collision_exceptions: Dictionary = {}
var thrown_collision_exception_refresh_left := 0.0
var previous_linear_velocity := Vector2.ZERO
## A melee weapon gets at most one break roll during one held -> thrown cycle.
## Firearms never enter this path.
var throw_break_checked := false



func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world


func _ready() -> void:
	weapon_id = DREAM_GUN_ATLAS.sanitize_weapon_id(weapon_id)
	add_to_group(&"world_weapon_pickups")
	add_to_group(&"pushable_prop")
	add_to_group(&"kickable_prop")
	default_linear_damp = linear_damp
	default_angular_damp = angular_damp
	default_continuous_cd = continuous_cd
	default_collision_layer = collision_layer
	default_collision_mask = collision_mask
	thrown_collision_layer = default_collision_layer if default_collision_layer != 0 else 8
	thrown_collision_mask = default_collision_mask if default_collision_mask != 0 else 15
	default_freeze = freeze
	room_saved_visible = visible
	room_saved_interaction_monitoring = interaction_area.monitoring if interaction_area != null else true
	room_saved_interaction_monitorable = interaction_area.monitorable if interaction_area != null else true
	room_saved_interaction_disabled = interaction_collision.disabled if interaction_collision != null else false
	mass = DREAM_GUN_ATLAS.get_world_mass(weapon_id)
	contact_monitor = true
	# The script deliberately enables contact reporting for thrown-impact
	# handling.  Cache that effective authored runtime value so a room gate does
	# not silently disable contact callbacks when the pickup becomes current again.
	room_saved_contact_monitor = contact_monitor
	max_contacts_reported = maxi(max_contacts_reported, 8)
	body_entered.connect(_on_physics_body_entered)
	var interaction_shape := interaction_collision.shape as CircleShape2D
	if interaction_shape != null:
		interaction_shape.radius = interaction_radius
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	_setup_pickup_shine()
	_refresh_visual()
	sky_drop_base_position = weapon_sprite.position
	throw_fake_base_position = weapon_sprite.position
	if shadow != null:
		shadow_ground_offset = shadow.position
		shadow_base_scale = shadow.scale
		shadow.top_level = true
		shadow.global_position = global_position + shadow_ground_offset
		shadow.global_rotation = 0.0
		shadow.global_scale = shadow_base_scale


func set_room_runtime_active(active: bool) -> void:
	"""Pause a room-owned pickup without resetting its gameplay state.

	The current room presentation is the only place where a WorldWeaponPickup
	may run physics or expose its interaction Area2D.  All cached values are
	restored when the room becomes current again, so authored layer/mask and
	throw-flight state remain authoritative.
	"""
	if room_runtime_active == active:
		if not active:
			visible = false
		return
	room_runtime_active = active
	if not active:
		room_saved_visible = visible
		room_saved_contact_monitor = contact_monitor
		room_saved_interaction_monitoring = interaction_area.monitoring if interaction_area != null else true
		room_saved_interaction_monitorable = interaction_area.monitorable if interaction_area != null else true
		room_saved_interaction_disabled = interaction_collision.disabled if interaction_collision != null else false
		visible = false
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		freeze = true
		sleeping = true
		contact_monitor = false
		set_physics_process(false)
		if interaction_area != null:
			interaction_area.set_deferred("monitoring", false)
			interaction_area.set_deferred("monitorable", false)
		if interaction_collision != null:
			interaction_collision.set_deferred("disabled", true)
		return
	freeze = default_freeze
	contact_monitor = room_saved_contact_monitor
	visible = room_saved_visible and not weapon_id.is_empty()
	set_physics_process(true)
	_apply_collision_policy()


func _setup_pickup_shine() -> void:
	if weapon_sprite == null:
		return
	pickup_shine_material = ShaderMaterial.new()
	pickup_shine_material.shader = PICKUP_SHINE_SHADER
	weapon_sprite.material = pickup_shine_material
	# Keep this pickup carrier unshaded so the white sweep remains stable in both
	# direct 3D presentation and the final screen palette pass.
	if bool(CONFIG.get(&"world_weapon_shine_enabled")):
		set_meta(&"depth_visual_unshaded", true)
	var period := maxf(float(CONFIG.get("world_weapon_shine_period")), 0.1)
	# A stable per-instance offset prevents multiple room drops from sweeping in
	# lockstep without introducing a gameplay RNG or a per-frame random value.
	pickup_shine_phase_offset = fmod(float(get_instance_id()) * 0.61803398875, period)
	pickup_shine_material.set_shader_parameter(
		&"shine_strength",
		clampf(float(CONFIG.get("world_weapon_shine_strength")), 0.0, 1.0)
	)
	pickup_shine_material.set_shader_parameter(
		&"shine_width",
		clampf(float(CONFIG.get("world_weapon_shine_width")), 0.005, 0.5)
	)
	pickup_shine_material.set_shader_parameter(&"shine_period", period)
	pickup_shine_material.set_shader_parameter(&"shine_phase_offset", pickup_shine_phase_offset)
	# Keep the sweep highlight explicitly white even if a reused material or
	# renderer default supplies a stale tint.
	pickup_shine_material.set_shader_parameter(&"shine_color", Color.WHITE)
	_update_pickup_shine_state()


func _update_pickup_shine_state() -> void:
	if pickup_shine_material == null:
		return
	var valid := not weapon_id.is_empty()
	var grounded := (
		valid
		and visible
		and ownership_state == OwnershipState.WORLD
		and not thrown_active
		and throw_fake_height <= 0.01
		and sky_drop_height <= 0.01
		and sky_drop_delay <= 0.0
	)
	pickup_shine_material.set_shader_parameter(
		&"shine_enabled",
		bool(CONFIG.get("world_weapon_shine_enabled")) and grounded
	)


func _is_throw_airborne() -> bool:
	return thrown_active or throw_fake_height > 0.01


func _apply_ground_collision_policy() -> void:
	if not room_runtime_active or weapon_id.is_empty():
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		return
	if thrown_active:
		# Only an actively flying throw gets the authored solid mask so it can
		# still hit walls, doors, furniture and actors.  Other pickups are
		# excluded below through the scoped exception policy.
		set_deferred("collision_layer", thrown_collision_layer)
		set_deferred("collision_mask", thrown_collision_mask)
	else:
		# GROUND and LANDED are never solid gameplay obstacles.  Their separate
		# InteractionArea remains available for normal pickup detection.
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)


func _apply_interaction_policy() -> void:
	var can_pickup := room_runtime_active and not weapon_id.is_empty() and not _is_throw_airborne()
	if interaction_area != null:
		interaction_area.set_deferred(
			"monitoring",
			can_pickup and room_saved_interaction_monitoring
		)
		interaction_area.set_deferred(
			"monitorable",
			can_pickup and room_saved_interaction_monitorable
		)
	if interaction_collision != null:
		interaction_collision.set_deferred(
			"disabled",
			not can_pickup or room_saved_interaction_disabled
		)


func _apply_collision_policy() -> void:
	_apply_ground_collision_policy()
	_apply_interaction_policy()


func _physics_process(delta: float) -> void:
	previous_linear_velocity = linear_velocity
	var visual_height := 0.0
	if sky_drop_delay > 0.0:
		sky_drop_delay = maxf(0.0, sky_drop_delay - delta)
		visual_height = sky_drop_height
	elif sky_drop_height > 0.0:
		sky_drop_vertical_velocity -= sky_drop_gravity * delta
		sky_drop_height = maxf(0.0, sky_drop_height + sky_drop_vertical_velocity * delta)
		visual_height = sky_drop_height
		if sky_drop_height <= 0.0:
			sky_drop_vertical_velocity = 0.0
	# A manual throw is a horizontal gameplay impulse plus this independent
	# visual arc.  Let the height finish naturally even if the horizontal body
	# has already come to rest and `_finish_throw()` has cleared thrown_active.
	if throw_fake_height > 0.0:
		throw_fake_vertical_velocity -= throw_fake_height_gravity * delta
		throw_fake_height = maxf(0.0, throw_fake_height + throw_fake_vertical_velocity * delta)
		visual_height = maxf(visual_height, throw_fake_height)
		if throw_fake_height <= 0.0:
			throw_fake_vertical_velocity = 0.0
			# Horizontal motion may have settled before the visual arc lands.
			# Keep the weapon-vs-weapon exception until this exact landing point;
			# the ground collision policy is restored only after the visual arc lands.
			if not thrown_active:
				_clear_thrown_weapon_collision_policy()
				_apply_collision_policy()
	if weapon_sprite != null:
		if throw_fake_height > sky_drop_height:
			weapon_sprite.position = throw_fake_base_position + Vector2(0.0, -throw_fake_height)
		elif sky_drop_height > 0.0 or sky_drop_delay > 0.0:
			weapon_sprite.position = sky_drop_base_position + Vector2(0.0, -sky_drop_height)
		elif visual_height <= 0.0:
			weapon_sprite.position = sky_drop_base_position
	fake_height = visual_height
	throw_pickup_lockout_left = maxf(0.0, throw_pickup_lockout_left - delta)
	# Record the first frame in which the thrown item has genuinely left the
	# original thrower's pickup radius.  This keeps the short lockout from
	# becoming a permanent block when the item later comes back, while still
	# preventing the same-tick auto-pickup race.
	_update_thrower_exit_state()
	if thrown_active or throw_fake_height > 0.0:
		thrown_collision_exception_refresh_left = maxf(
			0.0,
			thrown_collision_exception_refresh_left - delta
		)
		if thrown_collision_exception_refresh_left <= 0.0:
			_refresh_thrown_weapon_collision_policy()
			thrown_collision_exception_refresh_left = 0.10
		throw_elapsed += delta
		if (
			throw_elapsed >= CONFIG.world_weapon_throw_max_duration
			or (
				throw_elapsed >= 0.08
				and linear_velocity.length() <= CONFIG.world_weapon_throw_minimum_speed
			)
		):
			_finish_throw()
	if shadow != null:
		# The rigid body may rotate and bounce; the shadow remains anchored to the
		# ground projection at the weapon's real world position.
		shadow.global_position = global_position + shadow_ground_offset
		shadow.global_rotation = 0.0
		shadow.global_scale = shadow_base_scale
	_update_pickup_shine_state()


func start_sky_drop(height_pixels: float = 96.0, delay_seconds: float = 0.0) -> void:
	if weapon_sprite == null:
		return
	throw_fake_height = 0.0
	throw_fake_vertical_velocity = 0.0
	sky_drop_base_position = weapon_sprite.position
	sky_drop_height = maxf(height_pixels, 0.0)
	sky_drop_vertical_velocity = 0.0
	sky_drop_delay = maxf(delay_seconds, 0.0)
	weapon_sprite.position = sky_drop_base_position + Vector2(0.0, -sky_drop_height)
	fake_height = sky_drop_height


func configure(new_weapon_id: String, new_skin_index: int = -1) -> void:
	set_weapon_id(new_weapon_id, new_skin_index)


func set_weapon_id(new_weapon_id: String, new_skin_index: int = -1) -> void:
	# The registry is authoritative.  Unknown/deleted IDs intentionally load as
	# an empty pickup instead of silently granting a basic weapon.
	weapon_id = DREAM_GUN_ATLAS.sanitize_weapon_id(new_weapon_id)
	if new_skin_index >= 0:
		skin_index = DREAM_GUN_ATLAS.normalize_skin_index(weapon_id, new_skin_index)
	elif weapon_id != "books":
		skin_index = 0
	visual_scale_override = -1.0
	mass = DREAM_GUN_ATLAS.get_world_mass(weapon_id)
	if is_node_ready():
		_refresh_visual()


func get_weapon_display_name() -> String:
	return DREAM_GUN_ATLAS.get_display_name(weapon_id)


func is_player_in_range() -> bool:
	return player_in_range


func try_reserve(requester: Node) -> bool:
	_cleanup_stale_ownership()
	if not room_runtime_active or not is_instance_valid(requester) or _is_player_requester(requester):
		return false
	if ownership_state != OwnershipState.WORLD:
		return false
	if is_instance_valid(reserved_by) and reserved_by != requester:
		return false
	reserved_by = requester
	return true


func release_reservation(requester: Node = null) -> void:
	_cleanup_stale_ownership()
	if (
		ownership_state == OwnershipState.PLAYER_CLAIMED
		and (requester == null or claimed_by == requester or not is_instance_valid(claimed_by))
	):
		_return_player_claim_to_world()
		return
	if (
		ownership_state == OwnershipState.ENEMY_CLAIMED
		and (requester == null or claimed_by == requester or not is_instance_valid(claimed_by))
	):
		ownership_state = OwnershipState.WORLD
		claimed_by = null
	if requester == null or reserved_by == requester or not is_instance_valid(reserved_by):
		reserved_by = null


func is_reserved_for(requester: Node) -> bool:
	return is_instance_valid(reserved_by) and reserved_by == requester


func is_available_for(requester: Node) -> bool:
	_cleanup_stale_ownership()
	if not room_runtime_active or weapon_id.is_empty():
		return false
	if not is_instance_valid(requester):
		return false
	if _is_throw_airborne():
		return false
	if (
		throw_pickup_lockout_left > 0.0
		and thrower_instance_id > 0
		and is_instance_valid(requester)
		and requester.get_instance_id() == thrower_instance_id
	):
		return false
	# A committed Player claim is final until the world consumes/releases it.
	if ownership_state == OwnershipState.PLAYER_CLAIMED:
		return claimed_by == requester
	# Enemy ownership is committed only by the world's arbitration pass.  Other
	# actors (including Player) must not consume it after that commit.
	if ownership_state == OwnershipState.ENEMY_CLAIMED:
		return claimed_by == requester
	# Enemy reservations are deliberately soft and do not veto an explicit
	# Player target.  request_player_pickup() atomically clears that reservation
	# before the world swaps ownership.
	if _is_player_requester(requester):
		return true
	return not is_instance_valid(reserved_by) or reserved_by == requester


func request_player_pickup(requester: Node) -> bool:
	## Deterministic ownership commit for an explicit Player interaction.  This
	## is stronger than is_available_for(): an Enemy may have a soft reservation,
	## but it can never win once the Player's valid request is committed.
	_cleanup_stale_ownership()
	if not room_runtime_active or not is_instance_valid(requester) or not _is_player_requester(requester):
		return false
	if not is_available_for(requester):
		return false
	reserved_by = null
	claimed_by = requester
	ownership_state = OwnershipState.PLAYER_CLAIMED
	return true


func request_enemy_pickup(requester: Node) -> bool:
	## Enemy pickup requests remain reservations until the owning world resolves
	## them.  They never become a hard claim merely because AI ran first.
	_cleanup_stale_ownership()
	if not room_runtime_active or not is_instance_valid(requester) or _is_player_requester(requester):
		return false
	return try_reserve(requester)


func commit_enemy_pickup(requester: Node) -> bool:
	## Called by the world arbitration pass after Player requests have had first
	## refusal for the same gameplay tick.
	_cleanup_stale_ownership()
	if not room_runtime_active or not is_instance_valid(requester) or _is_player_requester(requester):
		return false
	if ownership_state != OwnershipState.WORLD or reserved_by != requester:
		return false
	ownership_state = OwnershipState.ENEMY_CLAIMED
	claimed_by = requester
	reserved_by = null
	return true


func _return_player_claim_to_world() -> void:
	ownership_state = OwnershipState.WORLD
	claimed_by = null
	reserved_by = null


func _cleanup_stale_ownership() -> void:
	if ownership_state != OwnershipState.WORLD and not is_instance_valid(claimed_by):
		ownership_state = OwnershipState.WORLD
		claimed_by = null
	if is_instance_valid(reserved_by):
		return
	reserved_by = null


func _is_player_requester(requester: Node) -> bool:
	return is_instance_valid(requester) and requester.is_in_group(&"dream_player")


func _update_thrower_exit_state() -> void:
	if thrower_left_pickup_radius or thrower_instance_id <= 0:
		return
	var thrower_object: Object = instance_from_id(thrower_instance_id)
	var thrower: Node2D = thrower_object as Node2D
	if not is_instance_valid(thrower):
		# A freed thrower cannot participate in the original same-tick pickup
		# race, so the item remains recoverable for surviving actors.
		thrower_left_pickup_radius = true
		return
	var radius := maxf(interaction_radius, 0.0)
	if global_position.distance_squared_to(thrower.global_position) > radius * radius:
		thrower_left_pickup_radius = true


func set_interaction_targeted(targeted: bool) -> void:
	# A pickup can be scanned before its 3D depth bridge is attached.  Do not
	# treat that early no-op as a completed highlight transition; retry once the
	# metadata exists on the same target state.
	if interaction_targeted == targeted and has_meta(&"depth_visual_bridge"):
		return
	interaction_targeted = targeted
	# 接近描边与敌人瞄准共用同一条桥接白描边；只有 E 会拾取的最近对象点亮。
	if not has_meta(&"depth_visual_bridge"):
		return
	var reference: Variant = get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if bridge != null and bridge.has_method("set_target_highlight"):
		bridge.set_target_highlight(targeted)


## 交互提示由顶层 HUD 绘制（见 dream_3d_random_dungeon.gd 的 InteractionPrompt）。
## 这里只提供"是否该显示 + 显示什么 + 世界锚点"，返回值交给 HUD 每帧读取，
## 因此提示始终是不参与 3D 光照/深度的 CanvasItem。
func get_interaction_prompt_state() -> Dictionary:
	if _is_throw_airborne() or not interaction_targeted or weapon_sprite == null or not weapon_sprite.visible:
		return {}
	if linear_velocity.length() >= 36.0:
		return {}
	return {
		"text": "E 交换为%s" % get_weapon_display_name(),
		"position": global_position,
	}


func place_after_swap(drop_position: Vector2, impulse: Vector2) -> void:
	_finish_throw()
	throw_fake_height = 0.0
	throw_fake_vertical_velocity = 0.0
	fake_height = 0.0
	sky_drop_height = 0.0
	sky_drop_delay = 0.0
	sky_drop_vertical_velocity = 0.0
	weapon_sprite.position = sky_drop_base_position
	thrower_instance_id = 0
	throw_pickup_lockout_left = 0.0
	thrower_left_pickup_radius = false
	# `_finish_throw()` intentionally keeps the scoped exception while a
	# throw-height arc is still airborne.  A swapped/settled pickup ends that
	# arc immediately, so restore the normal pickup-only ground policy now.
	_clear_thrown_weapon_collision_policy()
	global_position = drop_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_apply_collision_policy()
	if impulse.length_squared() > 0.0:
		apply_central_impulse(impulse)
		angular_velocity = clampf(impulse.length() * 0.035, 2.0, 12.0) * (-1.0 if impulse.y < 0.0 else 1.0)


func set_thrown(
	initial_velocity: Vector2,
	damage: float,
	force: float,
	thrower_id: int,
	lockout_seconds: float = -1.0
) -> void:
	# Keep any stale pair exceptions from a previous lifecycle out of the new
	# throw, then install the temporary solid profile after the body is marked
	# active.  Ground/LANDED pickups never retain this body collision.
	_clear_thrown_weapon_collision_policy()
	sky_drop_height = 0.0
	sky_drop_delay = 0.0
	sky_drop_vertical_velocity = 0.0
	throw_fake_base_position = weapon_sprite.position if weapon_sprite != null else sky_drop_base_position
	throw_fake_height = maxf(throw_fake_height_peak_pixels, 0.0)
	throw_fake_vertical_velocity = maxf(throw_fake_height_launch_velocity, 0.0)
	fake_height = throw_fake_height
	if weapon_sprite != null:
		weapon_sprite.position = throw_fake_base_position + Vector2(0.0, -throw_fake_height)
	thrown_active = true
	player_in_range = false
	set_interaction_targeted(false)
	_apply_collision_policy()
	throw_damage = maxf(damage, 0.0)
	throw_force = maxf(force, 0.0)
	thrower_instance_id = thrower_id
	thrower_left_pickup_radius = false
	throw_pickup_lockout_left = (
		CONFIG.world_weapon_throw_pickup_lockout
		if lockout_seconds < 0.0
		else maxf(lockout_seconds, 0.0)
	)
	throw_elapsed = 0.0
	thrown_hit_targets.clear()
	throw_break_checked = false
	thrown_collision_exception_refresh_left = 0.0
	linear_damp = CONFIG.world_weapon_throw_linear_damp
	angular_damp = CONFIG.world_weapon_throw_angular_damp
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	sleeping = false
	linear_velocity = initial_velocity.limit_length(CONFIG.maximum_knockback_speed)
	previous_linear_velocity = linear_velocity
	angular_velocity = clampf(linear_velocity.length() * 0.035, 4.0, 18.0)
	_refresh_thrown_weapon_collision_policy()
	_update_pickup_shine_state()


func _finish_throw() -> void:
	# A horizontal body can stop against a wall before its fake-height arc has
	# landed.  Keep pickup-vs-pickup exceptions until the visual flight reaches
	# the floor, while the body itself returns to the pickup-only ground policy.
	if throw_fake_height <= 0.0:
		_clear_thrown_weapon_collision_policy()
	thrown_active = false
	_apply_collision_policy()
	throw_damage = 0.0
	throw_force = 0.0
	throw_elapsed = 0.0
	thrown_hit_targets.clear()
	throw_break_checked = false
	thrown_collision_exception_refresh_left = 0.0
	linear_damp = default_linear_damp
	angular_damp = default_angular_damp
	continuous_cd = default_continuous_cd
	_update_pickup_shine_state()


func _on_physics_body_entered(body: Node) -> void:
	if not thrown_active or body == null:
		return
	# body_entered may be delivered after the solver has already reduced the
	# rigid body's velocity.  Keep the pre-contact velocity so a real high-speed
	# throw still deals its one hit instead of being lost at the contact frame.
	var impact_velocity := linear_velocity
	if impact_velocity.length_squared() < previous_linear_velocity.length_squared():
		impact_velocity = previous_linear_velocity
	var speed := impact_velocity.length()
	if speed < CONFIG.world_weapon_throw_minimum_speed:
		return
	var world := _dream_world()
	# A thrown weapon is also an explicit impact source.  The DoorLeaf remains
	# solid and terminal; only its accepted physical impulse is delegated to the
	# shared Door API.  Firearms pass through this call with zero break chance.
	if body.has_meta(&"physical_door") and bool(body.get_meta(&"physical_door", false)):
		var door_target_id := body.get_instance_id()
		if thrown_hit_targets.has(door_target_id):
			return
		# One thrown weapon gets one impact event per physical door.  This mirrors
		# the Enemy/Furniture de-duplication below and prevents a bouncing leaf
		# from repeatedly applying force during the same throw.
		thrown_hit_targets[door_target_id] = true
		if world != null and world.has_method("resolve_door_impact_from_collision"):
			world.call(
				"resolve_door_impact_from_collision",
				body,
				global_position,
				impact_velocity.normalized(),
				throw_force,
				StringName("thrown_%s" % weapon_id),
				thrower_instance_id
			)
		_handle_melee_throw_impact(speed)
		return
	var target := _resolve_damage_owner(body)
	if not is_instance_valid(target):
		# TileMap walls may be returned directly rather than through a damage
		# owner.  They still count as the first valid high-speed melee impact.
		if _is_world_wall(body):
			_handle_melee_throw_impact(speed)
		return
	if target.get_instance_id() == thrower_instance_id:
		return
	if target.is_in_group(&"world_weapon_pickups"):
		return
	var target_id := target.get_instance_id()
	if thrown_hit_targets.has(target_id):
		return

	var direction := impact_velocity.normalized()
	if direction.length_squared() <= 0.0001:
		return
	thrown_hit_targets[target_id] = true
	var valid_impact := false

	if target.is_in_group(&"dream_enemies"):
		valid_impact = true
		if target.has_method("take_damage"):
			target.take_damage(
				throw_damage,
				global_position,
				throw_force,
				StringName("player_throw_%s" % weapon_id)
			)
		if is_instance_valid(target) and not bool(target.get("dead")):
			if target.has_method("start_knockdown"):
				target.start_knockdown(direction, &"throw", throw_force)
			elif target.has_method("apply_external_knockback"):
				target.apply_external_knockback(direction, throw_force)
	elif target.is_in_group(&"damageable_props"):
		valid_impact = true
		if target.has_method("take_damage"):
			target.take_damage(
				throw_damage,
				direction,
				CONFIG.get_furniture_projectile_force_multiplier(StringName(weapon_id))
			)
		if target.has_method("apply_combat_impulse"):
			target.apply_combat_impulse(direction, throw_force * 0.35)
	elif _is_world_wall(body):
		valid_impact = true

	if valid_impact:
		# Damage/knockback above deliberately happens before this roll.  A
		# broken melee weapon still completes the impact that caused the break.
		_handle_melee_throw_impact(speed)


func _resolve_damage_owner(collider: Node) -> Node:
	if collider.has_method("get_damage_owner"):
		return collider.get_damage_owner()
	return collider


func _is_melee_weapon() -> bool:
	return DREAM_GUN_ATLAS.get_category(weapon_id) == DREAM_GUN_ATLAS.CATEGORY_MELEE


func _is_world_wall(collider: Node) -> bool:
	var current: Node = collider
	for _step in range(8):
		if current == null:
			break
		if current.name in [&"WallLayer", &"DoorBlocker", &"DoorLayer", &"DoorForegroundLayer"]:
			return true
		if current is CollisionObject2D:
			var collision_object := current as CollisionObject2D
			if collision_object.get_collision_layer_value(1) or collision_object.get_collision_layer_value(3):
				return true
		current = current.get_parent()
	return false


func _handle_melee_throw_impact(speed: float) -> void:
	if throw_break_checked or not _is_melee_weapon():
		return
	if speed < CONFIG.world_weapon_throw_minimum_speed:
		return
	throw_break_checked = true
	if randf() < clampf(CONFIG.world_weapon_throw_melee_break_chance, 0.0, 1.0):
		_break_after_throw_impact()


func _break_after_throw_impact() -> void:
	# Remove every gameplay hook before freeing so a queued signal cannot make
	# this weapon damage, collide or be picked up again in the same frame.
	thrown_active = false
	_clear_thrown_weapon_collision_policy()
	throw_damage = 0.0
	throw_force = 0.0
	throw_elapsed = 0.0
	throw_fake_height = 0.0
	throw_fake_vertical_velocity = 0.0
	fake_height = 0.0
	throw_pickup_lockout_left = 0.0
	reserved_by = null
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
	if interaction_collision != null:
		interaction_collision.set_deferred("disabled", true)
	if weapon_sprite != null:
		weapon_sprite.hide()
	_update_pickup_shine_state()
	remove_from_group(&"world_weapon_pickups")
	queue_free()


func _refresh_thrown_weapon_collision_policy() -> void:
	if (not thrown_active and throw_fake_height <= 0.0) or not is_inside_tree():
		return
	var frame := Engine.get_process_frames()
	if frame != _pickup_group_cache_frame:
		_pickup_group_cache_frame = frame
		_pickup_group_cache = get_tree().get_nodes_in_group(&"world_weapon_pickups")
	for pickup_variant in _pickup_group_cache:
		var pickup := pickup_variant as CollisionObject2D
		if pickup == null or pickup == self or not is_instance_valid(pickup):
			continue
		var pickup_id := pickup.get_instance_id()
		# Re-apply instead of trusting the local cache: another pickup can finish
		# its own throw lifecycle and remove a pair exception while this body is
		# still airborne.  The engine treats duplicate registrations as idempotent.
		add_collision_exception_with(pickup)
		thrown_weapon_collision_exceptions[pickup_id] = weakref(pickup)


func _clear_thrown_weapon_collision_policy() -> void:
	if thrown_weapon_collision_exceptions.is_empty():
		return
	for reference_variant in thrown_weapon_collision_exceptions.values():
		if not reference_variant is WeakRef:
			continue
		var pickup := reference_variant.get_ref() as CollisionObject2D
		if is_instance_valid(pickup):
			remove_collision_exception_with(pickup)
	thrown_weapon_collision_exceptions.clear()


func _refresh_visual() -> void:
	var valid := not weapon_id.is_empty()
	weapon_sprite.visible = valid
	if not valid:
		weapon_sprite.texture = null
		# An invalid/deleted save entry is an empty slot, not an invisible
		# pushable rigid body. Keep it out of gameplay physics as well as pickup
		# queries so old IDs cannot block a doorway.
		_apply_collision_policy()
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		freeze = true
		_update_pickup_shine_state()
		return
	_apply_collision_policy()
	freeze = default_freeze
	weapon_sprite.texture = DREAM_GUN_ATLAS.get_icon(weapon_id, skin_index)
	var scale_factor := visual_scale_override
	if scale_factor <= 0.0:
		# World, dropped and thrown visuals use the same canonical scale as the
		# Player's held Sprite; each texture keeps its native silhouette.
		scale_factor = float(CONFIG.held_weapon_world_scale)
	weapon_sprite.scale = Vector2.ONE * scale_factor
	_update_pickup_shine_state()


func _on_interaction_body_entered(body: Node) -> void:
	if room_runtime_active and not _is_throw_airborne() and body.is_in_group(&"dream_player"):
		player_in_range = true


func _on_interaction_body_exited(body: Node) -> void:
	if body.is_in_group(&"dream_player"):
		player_in_range = false
		interaction_targeted = false
