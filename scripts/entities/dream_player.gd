extends CharacterBody2D

@export var prop_push_force: float = 250.0

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const HEAL_EFFECT_SCENE := preload("res://scenes/entities/heal_effect.tscn")
const ROLL_SPEED_TRAIL_SCRIPT := preload("res://scripts/entities/roll_speed_trail.gd")
const CONFIG := preload("res://resources/demo_config.tres")
const WEAPON_POSE := preload("res://scripts/dream/dream_weapon_pose.gd")
const WORLD_WEAPON_PICKUP_SCRIPT := preload("res://scripts/dream/world_weapon_pickup.gd")
const TACTICAL_GHOST_PREVIEW_SCRIPT := preload("res://scripts/entities/tactical_ghost_preview.gd")

## DreamPlayer正式角色图集：192x191，6列x6行，每格32x32。
## 第1列为完整组装参考角色；第2列为手部；第3列为左朝向与背面头部；第4列为右朝向头部；第5列为身体；第6列为双腿。
const PLAYER_CHARACTER_ATLAS: Texture2D = preload("res://art/Dream/dream_chr_32x32.png")
const PLAYER_HEAD_LEFT_OPEN_REGION := Rect2(64, 0, 32, 32)
const PLAYER_HEAD_LEFT_BLINK_REGION := Rect2(64, 32, 32, 32)
const PLAYER_HEAD_LEFT_CLOSED_REGION := Rect2(64, 64, 32, 32)
const PLAYER_HEAD_RIGHT_OPEN_REGION := Rect2(96, 0, 32, 32)
const PLAYER_HEAD_RIGHT_BLINK_REGION := Rect2(96, 32, 32, 32)
const PLAYER_HEAD_RIGHT_CLOSED_REGION := Rect2(96, 64, 32, 32)
const PLAYER_HEAD_BACK_REGION := Rect2(64, 128, 32, 32)

const PLAYER_BODY_FRONT_REGION := Rect2(128, 0, 32, 32)
const PLAYER_BODY_BACK_REGION := Rect2(128, 128, 32, 32)

const PLAYER_LEFT_FOOT_FRONT_REGION := Rect2(171, 12, 4, 9)
const PLAYER_RIGHT_FOOT_FRONT_REGION := Rect2(176, 12, 4, 9)
const PLAYER_LEFT_FOOT_BACK_REGION := Rect2(171, 140, 4, 9)
const PLAYER_RIGHT_FOOT_BACK_REGION := Rect2(176, 140, 4, 9)

const PLAYER_LEFT_HAND_REGION := Rect2(37, 16, 5, 4)
const PLAYER_RIGHT_HAND_REGION := Rect2(52, 16, 5, 4)
const UNARMED_FIST_REST_OFFSET := Vector2(0,-3)

## Backward compatibility aliases for existing references
const PLAYER_HEAD_OPEN_REGION := PLAYER_HEAD_LEFT_OPEN_REGION
const PLAYER_HEAD_BLINK_REGION := PLAYER_HEAD_LEFT_BLINK_REGION
const PLAYER_HEAD_CLOSED_REGION := PLAYER_HEAD_LEFT_CLOSED_REGION
const PLAYER_BODY_REGION := PLAYER_BODY_FRONT_REGION
const PLAYER_LEFT_FOOT_REGION := PLAYER_LEFT_FOOT_FRONT_REGION
const PLAYER_RIGHT_FOOT_REGION := PLAYER_RIGHT_FOOT_FRONT_REGION
const AMMO_WEAPON_IDS: Array[String] = ["basic", "shotgun", "assault_rifle"]

signal health_changed(current: float, maximum: float)
signal died
signal dash_state_changed(remaining: float, total: float, active: bool, charges: int, maximum_charges: int)
signal weapon_fired(recoil_multiplier: float)
## Narrow event for the player-driven time controller.  Unlike weapon_fired,
## this is emitted only for a successful firearm attack, after the weapon's
## normal fire authority has spawned its projectile(s).
signal confirmed_projectile_fired
signal skill_state_changed(shielded: bool, dissociation_ready: bool)
signal effective_damage_taken(amount: float)
signal healed(amount: float)
signal revived
signal ammo_changed(current: int, capacity: int, reloading: bool)
signal active_weapon_changed(weapon_id: String)
## Emitted when a weapon is stored in a non-active inventory slot.  The active
## weapon does not change; worlds use this only to refresh slot presentation.
signal weapon_inventory_changed
## Emitted once when a legal airborne knockdown takes the currently held
## weapon out of Player ownership.  World/Dungeon layers own the actual
## WorldWeaponPickup instantiation; the Player only publishes the extracted
## ownership payload.
signal weapon_drop_requested(drop_data: Dictionary)
signal throw_aim_state_changed(active: bool)
## Space Dash preview state.  The gameplay path is resolved once by Player and
## consumed by both the arrow presentation and the committed dash.
signal dash_aim_state_changed(active: bool)
signal dash_path_preview_changed(result: Dictionary)
signal tactical_plan_state_changed(active: bool, stage: int, destination: Vector2, aim_target: Vector2)

enum DashInputState {
	IDLE,
	PENDING,
	AIM,
	TACTICAL_PLAN,
}

## 普通移动速度的唯一正式来源。Tab 角色卡 Speed 已停用：它不再进入移动计算，
## 也不再被任何乘算读取。Roll/翻滚、击退、发射、门撞击各自走独立参数。
const PLAYER_BASE_MOVE_SPEED := 200.0

@export var movement_speed := 136.0
@export var maximum_health := 80.0

@onready var auto_weapon: Node = $AutoWeapon
@onready var shotgun_weapon: Node = $ShotgunWeapon
@onready var lucille_weapon: Node = get_node_or_null("LucilleWeapon")
@onready var books_weapon: Node = get_node_or_null("BooksWeapon")
@onready var assault_rifle_weapon: Node = get_node_or_null("AssaultRifleWeapon")

@onready var visual: Node2D = $CharacterVisual
## Keep the old variable names as aliases so the existing movement code remains one system.
@onready var left_leg: Sprite2D = $CharacterVisual/LeftFoot
@onready var right_leg: Sprite2D = $CharacterVisual/RightFoot
@onready var body_pivot: Node2D = $CharacterVisual/BodyPivot
@onready var body_part: Sprite2D = $CharacterVisual/BodyPivot/Body
@onready var head_part: Sprite2D = $CharacterVisual/BodyPivot/Head
@onready var left_hand_part: Sprite2D = $CharacterVisual/BodyPivot/LeftHand
@onready var right_hand_part: Sprite2D = $CharacterVisual/BodyPivot/RightHand

@onready var heal_overlay: Node2D = $HealOverlay
@onready var shield_visual: ElectricShieldVisual = $ElectricShieldVisual
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var weapon_root: Node2D = $WeaponRoot
@onready var weapon_origin: Marker2D = $WeaponRoot/WeaponOrigin
@onready var projectile_origin: Marker2D = $WeaponRoot/ProjectileOrigin
@onready var aim_origin: Marker2D = $WeaponRoot/AimOrigin
@onready var hand_anchor: Node2D = $WeaponRoot/HandAnchor
@onready var weapon_motion: Node2D = $WeaponRoot/HandAnchor/WeaponMotion
@onready var reload_visual_pivot: Node2D = $WeaponRoot/HandAnchor/WeaponMotion/ReloadVisualPivot
@onready var held_weapon_sprite: Sprite2D = $WeaponRoot/HandAnchor/WeaponMotion/ReloadVisualPivot/HeldWeaponSprite
@onready var lucille_trail: Line2D = $WeaponRoot/HandAnchor/LucilleTrail

@onready var player_hp_bar: PlayerWorldHealthBar = $PlayerHPBar
@onready var weapon_name_label: Label = $WeaponNameLabel

## 3D worlds with a screen-space weapon popup suppress this old world-space
## label; it otherwise enters the pixelated actor capture and doubles the text.
var suppress_local_weapon_name_label := false

var current_health := 80.0
## Persistent TAB-card attributes.  These are applied from the profile at the
## start of a Dream and are kept separate from the temporary card upgrades.
var profile_hp_cells := 4
var movement_enabled := true
var scripted_locomotion_active := false
var scripted_locomotion_direction := Vector2.ZERO
var scripted_locomotion_speed := 0.0
## 与现有枪械 active 开关保持一致；空手拳击也必须尊重菜单/过场禁攻状态。
var attacking_enabled := true
var arena_bounds := Rect2(32, 52, 576, 266)

var invulnerability_left := 0.0
var invulnerability_reason: StringName = &""
var dash_invulnerability_left := 0.0
var dead := false

var selected_weapon_id := "basic"
var ranged_weapon_id := "basic"
var melee_weapon_id := "lucille"
var melee_weapon_skin_index := 0
var active_weapon_category: StringName = DreamGunAtlas.CATEGORY_RANGED
var block_active := false
## RMB hold-to-throw presentation state. Inventory remains untouched until the
## release commits through take_active_weapon_for_throw().
var throw_aim_active := false
## A manual Throw and a forced knock drop can arrive in either callback order
## during one gameplay tick.  Guard the ownership extraction itself so the
## fallback weapon is never extracted as a second pickup in that same tick.
var _weapon_extraction_tick := -1

var dash_enabled := true
var dash_distance := 100.0
var dash_duration := 0.18
var dash_cooldown := 2.0
var dash_invulnerability_seconds := 0.18
var dash_cooldown_left := 0.0
var max_dash_charges := 1
var dash_charges := 1
var dashing := false
var is_diving := false
var dive_bullet_time_active := false
var dive_duration: float = 0.35
var dive_bullet_time_scale: float = 0.2
var dive_airborne_ratio: float = 0.70
var dive_takeoff_angle_degrees: float = 45.0
var dive_peak_height: float = 18.0
var dash_elapsed := 0.0
var active_dash_duration := 0.18
var dash_start := Vector2.ZERO
var dash_end := Vector2.ZERO
var dash_input_state := DashInputState.IDLE
var dash_pending_started_usec := 0
var dash_pending_direction := Vector2.RIGHT
var dash_aim_hold_threshold := 0.16
var dash_aim_active := false
var dash_aim_result: Dictionary = {}
var tactical_dash_enabled: bool = true
var tactical_dash_distance_multiplier: float = 2.0
var tactical_dash_cooldown_seconds: float = 5.0
var tactical_dash_cooldown_left: float = 0.0
var tactical_dash_time_scale: float = 0.05
var tactical_dash_hold_threshold: float = 0.16
var tactical_plan_active: bool = false
var tactical_plan_stage: int = 0
var tactical_destination: Vector2 = Vector2.ZERO
var tactical_has_destination: bool = false
var tactical_aim_target: Vector2 = Vector2.ZERO
var tactical_has_aim_target: bool = false
var tactical_path_result: Dictionary = {}
var is_tactical_dash_executing: bool = false
var tactical_attack_target: Vector2 = Vector2.ZERO
var tactical_preview_overlay: CanvasLayer = null
var dash_path_segments: Array = []
var dash_segment_index := 0
var dash_segment_elapsed := 0.0
var dash_segment_duration := 0.0
var dash_path_total_distance := 0.0
var dash_vault_segment_obstacle: PhysicsBody2D = null
var dash_vault_exceptions: Array[PhysicsBody2D] = []
## One Dash may touch the same Enemy across several physics frames.  Track the
## pure knockback application and the temporary body exceptions separately from
## vault furniture so neither lifecycle can leak into the other.
var dash_knocked_enemy_ids: Dictionary = {}
var dash_enemy_collision_exceptions: Array[PhysicsBody2D] = []

## Dash翻滚视觉。
## 只旋转CharacterVisual，不旋转Player根节点/碰撞体/Camera/WeaponRoot。
var dash_roll_direction := Vector2.RIGHT
var dash_roll_visual_offset := Vector2.ZERO
var roll_trail_distance_since_sample := 0.0
var last_move_direction := Vector2.RIGHT
var last_aim_direction := Vector2.RIGHT


var hurt_invulnerability_seconds := 0.55
var hurt_flash_frequency := 12.0
var hurt_flash_seconds := 0.18
var hurt_shake_pixels := 2.0
var hurt_flash_left := 0.0
var shield_break_left := 0.0
var revive_flash_left := 0.0

var heal_overlay_tween: Tween
var weapon_visual_tween: Tween
var reload_visual_tween: Tween
var runtime_config: DemoConfig = CONFIG
var ammo_states: Dictionary = {}
var runtime_permanent_upgrades: Dictionary = {}
var weapon_name_time_left := 0.0

## 统一挥动攻击的角色视觉动作；所有正式近战武器共用。
var lucille_trail_tween: Tween
var lucille_character_tween: Tween
var melee_trail_width_curve: Curve
var melee_trail_gradient: Gradient
var lucille_character_offset := Vector2.ZERO
var lucille_body_lean_rotation := 0.0
var lucille_attack_direction := Vector2.RIGHT

var sleep_paralysis_still_seconds := 0.0
var sleep_paralysis_heal_per_second := 0.0
var still_elapsed := 0.0
var heal_tick_accumulator := 0.0

var sleep_spindle_interval := 0.0
var sleep_spindle_left := 0.0
var sleep_spindle_max_layers := 1
var has_shield := false

var dissociation_ready := false
var dissociation_revive_health := 30.0
var dissociation_invulnerability_seconds := 3.0

var feedback_audio: AudioStreamPlayer
var visual_home_position := Vector2(0, -18.25)
var character_visual_scale := 1.0
var character_facing_back := false
var character_facing_right := false
var idle_animation_time := 0.0
var walk_animation_time := 0.0
var walk_visual_bounce := 0.0
## 上一次脚步发声时的「步态半步」序号。相位每推进 π 就是一只脚落地，
## 所以该序号变化即代表这一步踩了下去。暂停、冲刺、死亡等分支会把相位
## 清零，那时必须同步清回 -1，否则重新起步会丢掉第一声脚步。
var last_footstep_phase_index := -1
var front_part_textures: Dictionary = {}
var back_part_textures: Dictionary = {}
var player_head_left_frames: Array[Texture2D] = []
var player_head_right_frames: Array[Texture2D] = []
var player_head_back_frame: Texture2D = null
var player_head_frames: Array[Texture2D] = []
var player_head_frame_index := 0
var player_blink_time_left := 2.5
var player_blink_phase_left := 0.0
var player_blink_phase := 0

## 动画始终以dream_player.tscn中保存的位置为基准。
var head_base_position := Vector2.ZERO
var body_base_position := Vector2.ZERO
var left_leg_base_position := Vector2.ZERO
var right_leg_base_position := Vector2.ZERO
var left_hand_base_position := Vector2.ZERO
var right_hand_base_position := Vector2.ZERO
var body_base_rotation := 0.0

## 空手拳击与其它视觉动作共用同一Player主攻击输入。
var punch_active := false
var punch_elapsed := 0.0
var punch_hit_applied := false
var punch_direction := Vector2.RIGHT
var punch_left_hand := true
var next_punch_left_hand := true
var punch_left_hand_offset := Vector2.ZERO
var punch_right_hand_offset := Vector2.ZERO
var punch_body_lean_rotation := 0.0
var punch_cooldown_left := 0.0

## Kick。
var kick_active := false
var kick_elapsed := 0.0
var kick_hit_applied := false
var kick_direction := Vector2.RIGHT
var _kick_shape: RectangleShape2D
var _kick_query: PhysicsShapeQueryParameters2D
var kick_left_foot := true
var next_kick_left_foot := true
var kick_blocked_by_interaction := false

## Kick整个人的视觉运动。
var kick_character_offset := Vector2.ZERO
var kick_body_lean_rotation := 0.0

var last_damage_source: StringName = &""
var run_damage_multiplier := 1.0
var acquired_damage_multiplier := 1.0
var acquired_attack_speed_multiplier := 1.0
var acquired_range_pixels := 0.0
var dash_disabled_by_hunger := false

var critical_chance := 0.10
var critical_damage_multiplier := 1.50
var last_heal_effect_msec := 0

var external_knockback_velocity := Vector2.ZERO
var external_knockback_left := 0.0
var airborne_knockback := false
var airborne_grounded_sliding := false
var knockback_recovery_left := 0.0
var knockback_height := 0.0
var knockback_vertical_velocity := 0.0
var secondary_collision_cooldown_left := 0.0
var airborne_visual_rotation_target := 0.0
var movement_impulse_velocity := Vector2.ZERO
var movement_impulse_left := 0.0
## Locomotion is kept separate from lightweight recoil so the time controller
## never mistakes a knockback/recoil displacement for player activity.
var _time_locomotion_velocity := Vector2.ZERO
var _time_locomotion_speed := 0.0
var pit_recovery_pending := false
var pit_recovery_landing_position := Vector2.ZERO

## Space action arbitration state.  Vault owns movement only after a complete
## forward/landing validation; otherwise the existing dash/roll path remains.
var vault_active := false
var vault_start_position := Vector2.ZERO
var vault_end_position := Vector2.ZERO
var vault_direction := Vector2.RIGHT
var vault_elapsed := 0.0
var vault_duration := 0.28
var vault_obstacle: PhysicsBody2D
var vault_height := 0.0
var vault_visual_rotation := 0.0

const HEAL_EFFECT_THROTTLE_MSEC := 700


func configure_weapon(weapon_id: String, config: DemoConfig, permanent_upgrades: Dictionary = {}) -> void:
	runtime_config = config
	runtime_permanent_upgrades = permanent_upgrades.duplicate(true)
	weapon_id = DreamGunAtlas.sanitize_weapon_id(weapon_id)

	var category := DreamGunAtlas.get_category(weapon_id)

	if weapon_id.is_empty():
		selected_weapon_id = ""
		ranged_weapon_id = ""
		melee_weapon_id = ""
		active_weapon_category = DreamGunAtlas.CATEGORY_RANGED
	elif category == DreamGunAtlas.CATEGORY_MELEE:
		melee_weapon_id = weapon_id
		active_weapon_category = DreamGunAtlas.CATEGORY_MELEE
	else:
		ranged_weapon_id = weapon_id
		active_weapon_category = DreamGunAtlas.CATEGORY_RANGED

	selected_weapon_id = weapon_id
	_ensure_ammo_state(ranged_weapon_id)

	_apply_profile_stats(false)

	auto_weapon.configure_weapon(config, permanent_upgrades)
	shotgun_weapon.configure_weapon(config, permanent_upgrades)

	if lucille_weapon != null:
		lucille_weapon.configure_weapon(config, permanent_upgrades)
	if books_weapon != null:
		books_weapon.configure_weapon(config, permanent_upgrades)
	if assault_rifle_weapon != null:
		assault_rifle_weapon.configure_weapon(config, permanent_upgrades)

	critical_chance = clampf(config.player_base_critical_chance, 0.0, 1.0)
	critical_damage_multiplier = maxf(config.player_critical_damage_multiplier, 1.0)

	_set_weapon_activity(true)

	dash_distance = config.dash_distance
	dash_duration = config.dash_duration
	dash_cooldown = config.dash_cooldown
	dash_invulnerability_seconds = config.dash_invulnerability_seconds
	dash_aim_hold_threshold = maxf(config.dash_aim_hold_threshold, 0.01)
	tactical_dash_enabled = bool(config.get("tactical_dash_enabled")) if config.get("tactical_dash_enabled") != null else true
	var mult: Variant = config.get("tactical_dash_distance_multiplier")
	tactical_dash_distance_multiplier = maxf(float(mult), 1.0) if mult != null else 2.0
	var cd: Variant = config.get("tactical_dash_cooldown_seconds")
	tactical_dash_cooldown_seconds = maxf(float(cd), 0.1) if cd != null else 5.0
	var ts: Variant = config.get("tactical_dash_time_scale")
	tactical_dash_time_scale = clampf(float(ts), 0.001, 1.0) if ts != null else 0.05
	var ht: Variant = config.get("tactical_dash_hold_threshold")
	tactical_dash_hold_threshold = maxf(float(ht), 0.01) if ht != null else 0.16
	var dd: Variant = config.get("dive_duration")
	dive_duration = maxf(float(dd), 0.05) if dd != null else 0.35
	var dts: Variant = config.get("dive_bullet_time_scale")
	dive_bullet_time_scale = clampf(float(dts), 0.001, 1.0) if dts != null else 0.2
	var dar: Variant = config.get("dive_airborne_ratio")
	dive_airborne_ratio = clampf(float(dar), 0.1, 0.95) if dar != null else 0.70
	var dta: Variant = config.get("dive_takeoff_angle_degrees")
	dive_takeoff_angle_degrees = maxf(float(dta), 0.0) if dta != null else 45.0
	var dph: Variant = config.get("dive_peak_height")
	dive_peak_height = maxf(float(dph), 0.0) if dph != null else 18.0

	hurt_invulnerability_seconds = config.hurt_invulnerability_seconds
	hurt_flash_frequency = config.hurt_flash_frequency
	hurt_flash_seconds = config.hurt_flash_seconds
	hurt_shake_pixels = config.hurt_shake_pixels

	character_visual_scale = config.player_visual_scale
	visual.scale = Vector2.ONE * character_visual_scale
	heal_overlay.scale = visual.scale

	shield_visual.configure(config.electric_shield_animation_fps, config.electric_shield_visual_scale)

	visual_home_position = config.player_parts_ground_offset
	visual.position = visual_home_position
	heal_overlay.position = visual_home_position

	body_collision.position = config.player_collision_offset

	var body_shape := body_collision.shape as CircleShape2D
	if body_shape != null:
		body_shape.radius = config.player_collision_radius

	weapon_root.position = config.player_weapon_root_offset

	dissociation_revive_health = config.dissociation_revive_health
	dissociation_invulnerability_seconds = config.dissociation_invulnerability_seconds

	health_changed.emit(current_health, maximum_health)
	player_hp_bar.configure(config, current_health, maximum_health)

	_refresh_held_weapon_visual()
	_emit_ammo_state()


## Applies persistent CharacterCard levels without changing the Player's
## collision size.  A new Dream starts full; upgrades made from the card keep
## the current HP and add only the newly gained capacity.
## The Speed stat was removed from the card: movement is a fixed 200 and no
## speed cell value is read, stored or multiplied into locomotion any more.
func configure_profile_stats(hp_cells: int, preserve_current: bool = false) -> void:
	profile_hp_cells = clampi(
		hp_cells,
		config_default_hp_cells(),
		runtime_config.character_card_max_stat_cells
	)
	_apply_profile_stats(preserve_current)
	health_changed.emit(current_health, maximum_health)
	if is_instance_valid(player_hp_bar):
		player_hp_bar.configure(runtime_config, current_health, maximum_health)


func config_default_hp_cells() -> int:
	return clampi(
		runtime_config.character_card_default_hp_cells,
		1,
		runtime_config.character_card_max_stat_cells
	)


func _apply_profile_stats(preserve_current: bool) -> void:
	if runtime_config == null:
		return
	var old_maximum := maximum_health
	var old_current := current_health
	var permanent_hp_cells := int(runtime_permanent_upgrades.get("hippocampus", 0))
	var total_hp_cells := clampi(
		profile_hp_cells + permanent_hp_cells,
		1,
		runtime_config.character_card_max_stat_cells
	)
	maximum_health = float(total_hp_cells) * runtime_config.character_card_hp_per_cell
	if preserve_current and old_maximum > 0.0:
		current_health = clampf(old_current + maximum_health - old_maximum, 0.0, maximum_health)
	else:
		current_health = maximum_health
	# Profile cards do not multiply movement. Office runs explicitly own their
	# base speed; tutorial/reception retain the existing default. Roll is separate.
	movement_speed = float(runtime_config.get_meta("office_player_move_speed", PLAYER_BASE_MOVE_SPEED))


func get_character_card_hp_cells() -> int:
	if runtime_config == null:
		return profile_hp_cells
	return clampi(
		profile_hp_cells + int(runtime_permanent_upgrades.get("hippocampus", 0)),
		1,
		runtime_config.character_card_max_stat_cells
	)


func get_character_card_attack_value() -> float:
	if selected_weapon_id.is_empty():
		return runtime_config.player_punch_damage
	var weapon := get_active_weapon()
	return float(weapon.get("damage")) if weapon != null else runtime_config.player_punch_damage


## 剧情局内换武器：只改变未来攻击源，已发射Projectile保持独立生命周期。
func equip_weapon(weapon_id: String, config: DemoConfig, permanent_upgrades: Dictionary = {}, skin_index: int = -1) -> void:
	_cancel_punch()
	_cancel_melee_visual()
	_set_weapon_activity(false)

	runtime_config = config
	runtime_permanent_upgrades = permanent_upgrades.duplicate(true)
	weapon_id = DreamGunAtlas.sanitize_weapon_id(weapon_id)
	if weapon_id.is_empty():
		selected_weapon_id = ""
		ranged_weapon_id = ""
		melee_weapon_id = ""
		active_weapon_category = DreamGunAtlas.CATEGORY_RANGED
		_cancel_reload_visual()
		_set_weapon_activity(false)
		_refresh_held_weapon_visual()
		_emit_ammo_state()
		return

	var category := DreamGunAtlas.get_category(weapon_id)

	if category == DreamGunAtlas.CATEGORY_MELEE:
		melee_weapon_id = weapon_id
		if weapon_id == "books" and skin_index >= 0:
			melee_weapon_skin_index = DreamGunAtlas.normalize_skin_index(weapon_id, skin_index)
		active_weapon_category = DreamGunAtlas.CATEGORY_MELEE
	else:
		ranged_weapon_id = weapon_id
		active_weapon_category = DreamGunAtlas.CATEGORY_RANGED

	selected_weapon_id = weapon_id
	_ensure_ammo_state(selected_weapon_id)

	auto_weapon.configure_weapon(config, permanent_upgrades)
	shotgun_weapon.configure_weapon(config, permanent_upgrades)

	if lucille_weapon != null:
		lucille_weapon.configure_weapon(config, permanent_upgrades)
	if books_weapon != null:
		books_weapon.configure_weapon(config, permanent_upgrades)
	if assault_rifle_weapon != null:
		assault_rifle_weapon.configure_weapon(config, permanent_upgrades)

	var weapon := get_active_weapon()

	if acquired_damage_multiplier > 1.0:
		if weapon.has_method("apply_damage_upgrade"):
			weapon.apply_damage_upgrade(acquired_damage_multiplier)
		else:
			weapon.damage *= acquired_damage_multiplier

	if acquired_attack_speed_multiplier > 1.0:
		if weapon.has_method("apply_attack_speed_upgrade"):
			weapon.apply_attack_speed_upgrade(acquired_attack_speed_multiplier)
		else:
			weapon.attack_interval /= acquired_attack_speed_multiplier

	if acquired_range_pixels > 0.0:
		if weapon.has_method("apply_range_upgrade"):
			weapon.apply_range_upgrade(acquired_range_pixels)
		else:
			weapon.attack_range += acquired_range_pixels

	weapon.set("cooldown_left", minf(float(weapon.get("cooldown_left")), 0.25))

	_set_weapon_activity(not dead)
	_refresh_held_weapon_visual()
	_update_held_weapon_aim()
	_emit_ammo_state()
	_show_weapon_name()
	active_weapon_changed.emit(selected_weapon_id)


## Store a newly acquired weapon in its category without changing the current
## selection.  Automatic pickup uses this path; explicit E swaps continue to
## use equip_weapon() so their established equip-and-select behaviour remains.
func store_weapon_in_category(
	weapon_id: String,
	config: DemoConfig,
	permanent_upgrades: Dictionary = {},
	skin_index: int = -1
) -> bool:
	if dead or config == null:
		return false
	var stored_id := DreamGunAtlas.sanitize_weapon_id(weapon_id)
	if stored_id.is_empty():
		return false
	var category := DreamGunAtlas.get_category(stored_id)
	# The inventory-only API is intentionally race-safe: a second pickup request
	# in the same frame must not overwrite an already occupied category or alter
	# the active selection.  Explicit E swaps use equip_weapon() instead.
	if not get_weapon_in_category(category).is_empty():
		return false
	runtime_config = config
	runtime_permanent_upgrades = permanent_upgrades.duplicate(true)
	if category == DreamGunAtlas.CATEGORY_MELEE:
		melee_weapon_id = stored_id
		if stored_id == "books" and skin_index >= 0:
			melee_weapon_skin_index = DreamGunAtlas.normalize_skin_index(stored_id, skin_index)
	else:
		ranged_weapon_id = stored_id
	_ensure_ammo_state(stored_id)

	# Configure all formal weapon nodes as the normal equip path does.  The
	# active selection and visual activity stay untouched below.
	auto_weapon.configure_weapon(config, permanent_upgrades)
	shotgun_weapon.configure_weapon(config, permanent_upgrades)
	if lucille_weapon != null:
		lucille_weapon.configure_weapon(config, permanent_upgrades)
	if books_weapon != null:
		books_weapon.configure_weapon(config, permanent_upgrades)
	if assault_rifle_weapon != null:
		assault_rifle_weapon.configure_weapon(config, permanent_upgrades)
	var stored_weapon := _get_weapon_node(stored_id)
	if stored_weapon != null:
		if acquired_damage_multiplier > 1.0:
			if stored_weapon.has_method("apply_damage_upgrade"):
				stored_weapon.apply_damage_upgrade(acquired_damage_multiplier)
			else:
				stored_weapon.damage *= acquired_damage_multiplier
		if acquired_attack_speed_multiplier > 1.0:
			if stored_weapon.has_method("apply_attack_speed_upgrade"):
				stored_weapon.apply_attack_speed_upgrade(acquired_attack_speed_multiplier)
			else:
				stored_weapon.attack_interval /= acquired_attack_speed_multiplier
		if acquired_range_pixels > 0.0:
			if stored_weapon.has_method("apply_range_upgrade"):
				stored_weapon.apply_range_upgrade(acquired_range_pixels)
			else:
				stored_weapon.attack_range += acquired_range_pixels
	weapon_inventory_changed.emit()
	return true


func get_weapon_in_category(category: StringName) -> String:
	if category == DreamGunAtlas.CATEGORY_MELEE:
		return melee_weapon_id
	if category == DreamGunAtlas.CATEGORY_FIST:
		return ""
	return ranged_weapon_id


func has_any_weapon() -> bool:
	return not ranged_weapon_id.is_empty() or not melee_weapon_id.is_empty()


func is_throw_aim_active() -> bool:
	return throw_aim_active


func begin_throw_aim() -> bool:
	if (
		dead
		or throw_aim_active
		or selected_weapon_id.is_empty()
		or not movement_enabled
		or dashing
		or airborne_knockback
		or knockback_recovery_left > 0.0
	):
		return false
	throw_aim_active = true
	throw_aim_state_changed.emit(true)
	# RMB is presentation/throw state only. Manual Bullet Time is bound to the
	# dedicated InputMap `bullet_time` (T) and composed independently by the
	# global DreamTimeController.
	return true


func end_throw_aim() -> void:
	if not throw_aim_active:
		return
	throw_aim_active = false
	throw_aim_state_changed.emit(false)


func _cancel_throw_aim() -> void:
	end_throw_aim()


func _commit_throw_aim() -> void:
	if not throw_aim_active:
		return
	# End the presentation-only aim state before mutating inventory so the throw
	# action is handled as an ordinary Player event by the existing time compositor.
	end_throw_aim()
	var throw_data := take_active_weapon_for_throw()
	if not throw_data.is_empty():
		weapon_drop_requested.emit(throw_data)


## Non-mutating profile used by the 3D throw predictor.  It deliberately
## mirrors take_active_weapon_for_throw()'s data calculation; no inventory or
## cooldown state changes until the release commits the actual throw.
func get_active_throw_profile() -> Dictionary:
	if dead or selected_weapon_id.is_empty():
		return {}
	var thrown_weapon_id := selected_weapon_id
	var category: StringName = DreamGunAtlas.get_category(thrown_weapon_id)
	var active_weapon: Node = get_active_weapon()
	var held_visual_scale := runtime_config.held_weapon_world_scale
	var held_visual_position := global_position
	var held_visual_rotation := get_aim_direction().angle()
	if held_weapon_sprite != null:
		held_visual_scale = maxf(absf(held_weapon_sprite.global_scale.x), 0.01)
		held_visual_position = held_weapon_sprite.global_position
		held_visual_rotation = held_weapon_sprite.global_rotation
	var base_damage := 0.0
	if active_weapon != null:
		var damage_value: Variant = active_weapon.get("damage")
		if damage_value != null:
			base_damage = maxf(float(damage_value), 0.0)
	if base_damage <= 0.0:
		match thrown_weapon_id:
			"lucille": base_damage = runtime_config.lucille_damage
			"books": base_damage = runtime_config.books_damage
			_: base_damage = runtime_config.basic_weapon_damage
	var throw_damage := (
		base_damage * 2.0
		if category == DreamGunAtlas.CATEGORY_MELEE
		else 10.0
	)
	var throw_force := runtime_config.world_weapon_throw_force
	var throw_speed := runtime_config.world_weapon_throw_force * runtime_config.world_weapon_throw_speed_multiplier
	if category == DreamGunAtlas.CATEGORY_MELEE:
		throw_force *= runtime_config.world_weapon_throw_melee_force_multiplier
		throw_speed *= runtime_config.world_weapon_throw_melee_force_multiplier
	var direction := get_aim_direction()
	if direction.length_squared() <= 0.0001:
		direction = last_aim_direction
	if direction.length_squared() <= 0.0001:
		direction = last_move_direction
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	return {
		"weapon_id": thrown_weapon_id,
		"category": category,
		"skin_index": get_weapon_skin_index(thrown_weapon_id),
		"damage": throw_damage,
		"force": throw_force,
		"speed": minf(throw_speed, runtime_config.maximum_knockback_speed),
		"visual_scale": held_visual_scale,
		"visual_position": held_visual_position,
		"visual_rotation": held_visual_rotation,
		"direction": direction,
		"fake_height_peak": WORLD_WEAPON_PICKUP_SCRIPT.DEFAULT_THROW_FAKE_HEIGHT_PEAK_PIXELS,
		"fake_height_velocity": WORLD_WEAPON_PICKUP_SCRIPT.DEFAULT_THROW_FAKE_HEIGHT_LAUNCH_VELOCITY,
		"fake_height_gravity": WORLD_WEAPON_PICKUP_SCRIPT.DEFAULT_THROW_FAKE_HEIGHT_GRAVITY,
		"collision_shape_size": WORLD_WEAPON_PICKUP_SCRIPT.THROW_COLLISION_SHAPE_SIZE,
		"collision_mask": 15,
		"max_duration": runtime_config.world_weapon_throw_max_duration,
		"linear_damp": runtime_config.world_weapon_throw_linear_damp,
	}


## Atomically removes only the active slot and returns the data needed by the
## existing WorldWeapon scene to perform a real physical throw.
func take_active_weapon_for_throw() -> Dictionary:
	if dead or selected_weapon_id.is_empty():
		return {}
	if throw_aim_active:
		_cancel_throw_aim()
	var extraction_tick := Engine.get_physics_frames()
	if _weapon_extraction_tick == extraction_tick:
		return {}
	_weapon_extraction_tick = extraction_tick
	_cancel_punch()
	_cancel_melee_visual()

	var thrown_weapon_id := selected_weapon_id
	var category: StringName = DreamGunAtlas.get_category(thrown_weapon_id)
	var active_weapon: Node = get_active_weapon()
	var held_visual_scale := runtime_config.held_weapon_world_scale
	var held_visual_position := global_position
	var held_visual_rotation := get_aim_direction().angle()
	if held_weapon_sprite != null:
		held_visual_scale = maxf(absf(held_weapon_sprite.global_scale.x), 0.01)
		held_visual_position = held_weapon_sprite.global_position
		held_visual_rotation = held_weapon_sprite.global_rotation
	var base_damage := 0.0
	if active_weapon != null:
		var damage_value: Variant = active_weapon.get("damage")
		if damage_value != null:
			base_damage = maxf(float(damage_value), 0.0)
	if base_damage <= 0.0:
		match thrown_weapon_id:
			"lucille": base_damage = runtime_config.lucille_damage
			"books": base_damage = runtime_config.books_damage
			_: base_damage = runtime_config.basic_weapon_damage

	var throw_damage := (
		base_damage * 2.0
		if category == DreamGunAtlas.CATEGORY_MELEE
		else 10.0
	)
	var throw_force := runtime_config.world_weapon_throw_force
	var throw_speed := runtime_config.world_weapon_throw_force * runtime_config.world_weapon_throw_speed_multiplier
	if category == DreamGunAtlas.CATEGORY_MELEE:
		throw_force *= runtime_config.world_weapon_throw_melee_force_multiplier
		throw_speed *= runtime_config.world_weapon_throw_melee_force_multiplier

	var direction := get_aim_direction()
	if direction.length_squared() <= 0.0001:
		direction = last_aim_direction
	if direction.length_squared() <= 0.0001:
		direction = last_move_direction
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	if category == DreamGunAtlas.CATEGORY_MELEE:
		melee_weapon_id = ""
	else:
		ranged_weapon_id = ""

	var fallback_weapon_id := (
		melee_weapon_id
		if category == DreamGunAtlas.CATEGORY_RANGED
		else ranged_weapon_id
	)
	selected_weapon_id = fallback_weapon_id
	active_weapon_category = (
		DreamGunAtlas.get_category(fallback_weapon_id)
		if not fallback_weapon_id.is_empty()
		else category
	)

	_cancel_reload_visual()
	_set_weapon_activity(not dead)
	_refresh_held_weapon_visual()
	_emit_ammo_state()
	if selected_weapon_id.is_empty():
		punch_cooldown_left = 0.0
		weapon_name_label.hide()
		weapon_name_time_left = 0.0
	else:
		_show_weapon_name()
	active_weapon_changed.emit(selected_weapon_id)

	return {
		"weapon_id": thrown_weapon_id,
		"category": category,
		"skin_index": get_weapon_skin_index(thrown_weapon_id),
		"damage": throw_damage,
		"force": throw_force,
		"speed": throw_speed,
		"visual_scale": held_visual_scale,
		"visual_position": held_visual_position,
		"visual_rotation": held_visual_rotation,
		"direction": direction,
	}


func get_weapon_category(weapon_id: String = selected_weapon_id) -> StringName:
	return DreamGunAtlas.get_category(weapon_id)


func get_weapon_skin_index(weapon_id: String = selected_weapon_id) -> int:
	return melee_weapon_skin_index if weapon_id == "books" else 0


func switch_weapon_slot(direction: int = 1) -> bool:
	if dead:
		return false
	_cancel_throw_aim()
	var categories: Array[StringName] = [
		DreamGunAtlas.CATEGORY_RANGED,
		DreamGunAtlas.CATEGORY_MELEE,
		DreamGunAtlas.CATEGORY_FIST,
	]
	var current_index := categories.find(active_weapon_category)
	if current_index < 0:
		current_index = 0
	var step := 1 if direction >= 0 else -1
	var next_index := posmod(current_index + step, categories.size())
	active_weapon_category = categories[next_index]
	selected_weapon_id = get_weapon_in_category(active_weapon_category)
	_cancel_reload_visual()
	_set_weapon_activity(not dead and not selected_weapon_id.is_empty())
	_refresh_held_weapon_visual()
	_emit_ammo_state()
	if selected_weapon_id.is_empty():
		weapon_name_label.hide()
		weapon_name_time_left = 0.0
	else:
		_show_weapon_name()
	active_weapon_changed.emit(selected_weapon_id)
	return true


func configure_run_modifiers(is_hungry_run: bool, config: DemoConfig) -> void:
	run_damage_multiplier = config.hungry_damage_multiplier if is_hungry_run else 1.0
	dash_disabled_by_hunger = is_hungry_run
	set_dash_enabled(not dash_disabled_by_hunger)


func calculate_player_damage(base_damage: float) -> Dictionary:
	var modified_damage := maxf(1.0, base_damage * run_damage_multiplier)
	var is_critical := randf() < critical_chance

	if is_critical:
		modified_damage *= critical_damage_multiplier

	return {
		"damage": maxi(1, roundi(modified_damage)),
		"is_critical": is_critical
	}


func get_effective_attack_range() -> float:
	if selected_weapon_id.is_empty():
		return runtime_config.player_punch_range
	var weapon := get_active_weapon()
	return float(weapon.attack_range)


func is_dash_hunger_disabled() -> bool:
	return dash_disabled_by_hunger


func _ready() -> void:
	# Direct Player instances (tests/tutorial previews) must use the same action
	# authority as Main and both Dream world roots.
	preload("res://scripts/app/game_input_actions.gd").configure()
	add_to_group(&"dream_player")
	_ensure_weapon_switch_input_actions()

	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)

	_setup_character_parts()

	auto_weapon.weapon_fired.connect(_on_weapon_fired)
	shotgun_weapon.weapon_fired.connect(_on_weapon_fired)

	if lucille_weapon != null:
		lucille_weapon.weapon_fired.connect(_on_weapon_fired)
		if lucille_weapon.has_signal("melee_impact"):
			lucille_weapon.melee_impact.connect(_on_melee_impact)
		if lucille_weapon.has_signal("melee_furniture_hit"):
			lucille_weapon.melee_furniture_hit.connect(_on_melee_furniture_hit)

	if books_weapon != null:
		books_weapon.weapon_fired.connect(_on_weapon_fired)
		if books_weapon.has_signal("melee_impact"):
			books_weapon.melee_impact.connect(_on_melee_impact)
		if books_weapon.has_signal("melee_furniture_hit"):
			books_weapon.melee_furniture_hit.connect(_on_melee_furniture_hit)

	if assault_rifle_weapon != null:
		assault_rifle_weapon.weapon_fired.connect(_on_weapon_fired)

	configure_weapon("basic", CONFIG)

	feedback_audio = AudioStreamPlayer.new()
	feedback_audio.bus = &"Characters"
	add_child(feedback_audio)

	tactical_preview_overlay = TACTICAL_GHOST_PREVIEW_SCRIPT.new()
	tactical_preview_overlay.name = "TacticalGhostPreview"
	add_child(tactical_preview_overlay)

	queue_redraw()


func _setup_character_parts() -> void:
	left_leg_base_position = left_leg.position
	right_leg_base_position = right_leg.position
	body_base_position = body_pivot.position
	head_base_position = head_part.position
	left_hand_base_position = left_hand_part.position if left_hand_part != null else Vector2.ZERO
	right_hand_base_position = right_hand_part.position if right_hand_part != null else Vector2.ZERO
	body_base_rotation = body_pivot.rotation

	var head_left_open: AtlasTexture = _make_player_atlas_texture(PLAYER_HEAD_LEFT_OPEN_REGION)
	var head_left_blink: AtlasTexture = _make_player_atlas_texture(PLAYER_HEAD_LEFT_BLINK_REGION)
	var head_left_closed: AtlasTexture = _make_player_atlas_texture(PLAYER_HEAD_LEFT_CLOSED_REGION)

	var head_right_open: AtlasTexture = _make_player_atlas_texture(PLAYER_HEAD_RIGHT_OPEN_REGION)
	var head_right_blink: AtlasTexture = _make_player_atlas_texture(PLAYER_HEAD_RIGHT_BLINK_REGION)
	var head_right_closed: AtlasTexture = _make_player_atlas_texture(PLAYER_HEAD_RIGHT_CLOSED_REGION)

	player_head_back_frame = _make_player_atlas_texture(PLAYER_HEAD_BACK_REGION)

	player_head_left_frames = [head_left_open, head_left_blink, head_left_closed]
	player_head_right_frames = [head_right_open, head_right_blink, head_right_closed]

	player_head_frames.clear()
	player_head_frames.append_array(player_head_left_frames)

	var body_front_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_BODY_FRONT_REGION)
	var body_back_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_BODY_BACK_REGION)

	var left_foot_front_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_LEFT_FOOT_FRONT_REGION)
	var right_foot_front_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_RIGHT_FOOT_FRONT_REGION)
	var left_foot_back_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_LEFT_FOOT_BACK_REGION)
	var right_foot_back_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_RIGHT_FOOT_BACK_REGION)

	var left_hand_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_LEFT_HAND_REGION)
	var right_hand_texture: AtlasTexture = _make_player_atlas_texture(PLAYER_RIGHT_HAND_REGION)

	front_part_textures = {
		"head": head_left_open,
		"body": body_front_texture,
		"left_foot": left_foot_front_texture,
		"right_foot": right_foot_front_texture,
		"left_hand": left_hand_texture,
		"right_hand": right_hand_texture,
	}

	back_part_textures = {
		"head": player_head_back_frame,
		"body": body_back_texture,
		"left_foot": left_foot_back_texture,
		"right_foot": right_foot_back_texture,
		"left_hand": left_hand_texture,
		"right_hand": right_hand_texture,
	}

	for root in [visual, heal_overlay]:
		var parts: Array[Sprite2D] = _get_character_parts(root)

		for part in parts:
			part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			part.centered = false

	_apply_character_part_set(false)
	_set_player_head_frame(0)
	player_blink_time_left = _get_next_blink_delay()
	_sync_heal_part_positions()


func _make_player_atlas_texture(region: Rect2) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = PLAYER_CHARACTER_ATLAS
	texture.region = region
	return texture


func _get_character_parts(root: Node) -> Array[Sprite2D]:
	var parts: Array[Sprite2D] = []

	for part_path in [
		"LeftFoot",
		"RightFoot",
		"BodyPivot/Head",
		"BodyPivot/Body",
		"BodyPivot/LeftHand",
		"BodyPivot/RightHand",
	]:
		var part := root.get_node_or_null(part_path) as Sprite2D

		if part != null:
			parts.append(part)

	return parts


func _apply_character_part_set(use_back: bool) -> void:
	var textures: Dictionary = back_part_textures if use_back else front_part_textures

	for root in [visual, heal_overlay]:
		var root_left := root.get_node("LeftFoot") as Sprite2D
		var root_right := root.get_node("RightFoot") as Sprite2D
		var root_body := root.get_node("BodyPivot/Body") as Sprite2D
		var root_head := root.get_node("BodyPivot/Head") as Sprite2D
		var root_left_hand := root.get_node_or_null("BodyPivot/LeftHand") as Sprite2D
		var root_right_hand := root.get_node_or_null("BodyPivot/RightHand") as Sprite2D

		root_left.texture = textures.get("left_foot") as Texture2D
		root_right.texture = textures.get("right_foot") as Texture2D
		root_body.texture = textures.get("body") as Texture2D
		root_left.visible = true
		root_right.visible = true
		root_body.visible = true
		if use_back:
			root_head.texture = player_head_back_frame
		elif not player_head_frames.is_empty():
			root_head.texture = player_head_frames[clampi(player_head_frame_index, 0, player_head_frames.size() - 1)]
		else:
			root_head.texture = textures.get("head") as Texture2D
		if root_left_hand != null:
			root_left_hand.texture = textures.get("left_hand") as Texture2D
		if root_right_hand != null:
			root_right_hand.texture = textures.get("right_hand") as Texture2D

	_update_hands_visibility()


func _set_part_position(part: Node2D, local_position: Vector2) -> void:
	part.position = local_position


func _sync_heal_part_positions() -> void:
	for part_name in ["LeftFoot", "RightFoot"]:
		var source := visual.get_node(part_name) as Sprite2D
		var overlay := heal_overlay.get_node(part_name) as Sprite2D

		overlay.position = source.position

	var source_pivot := visual.get_node("BodyPivot") as Node2D
	var overlay_pivot := heal_overlay.get_node("BodyPivot") as Node2D

	overlay_pivot.position = source_pivot.position
	overlay_pivot.rotation = source_pivot.rotation

	for part_name in ["Head", "Body"]:
		var source_part := source_pivot.get_node(part_name) as Sprite2D
		var overlay_part := overlay_pivot.get_node(part_name) as Sprite2D

		overlay_part.position = source_part.position

	for part_name in ["LeftHand", "RightHand"]:
		var source_hand := source_pivot.get_node_or_null(part_name) as Sprite2D
		var overlay_hand := overlay_pivot.get_node_or_null(part_name) as Sprite2D
		if source_hand != null and overlay_hand != null:
			overlay_hand.position = source_hand.position
			overlay_hand.visible = source_hand.visible


func _update_hands_visibility() -> void:
	## Armed state is derived from the real selected weapon slot, so Pickup/Throw/Break
	## cannot leave stale hands visible or hidden for a frame.
	var hands_visible := selected_weapon_id.is_empty() and not dead
	for root in [visual, heal_overlay]:
		for part_name in ["BodyPivot/LeftHand", "BodyPivot/RightHand"]:
			var hand := root.get_node_or_null(part_name) as Sprite2D
			if hand != null:
				hand.visible = hands_visible
	_update_unarmed_hand_pose()
	_sync_heal_part_positions()


func _update_unarmed_hand_pose() -> void:
	# Use the original fist pixels, raised into a readable empty-hand guard.
	# Punch displacement remains additive; attack permissions never hide fists.
	var rest := UNARMED_FIST_REST_OFFSET if selected_weapon_id.is_empty() else Vector2.ZERO
	left_hand_part.position = left_hand_base_position+rest+punch_left_hand_offset
	right_hand_part.position = right_hand_base_position+rest+punch_right_hand_offset


func _is_punch_blocked() -> bool:
	return (
		dead
		or dashing
		or airborne_knockback
		or vault_active
		or kick_active
		or not movement_enabled
		or not attacking_enabled
		or external_knockback_left > 0.0
	)


func _cancel_punch() -> void:
	punch_active = false
	punch_elapsed = 0.0
	punch_hit_applied = false
	punch_left_hand_offset = Vector2.ZERO
	punch_right_hand_offset = Vector2.ZERO
	punch_body_lean_rotation = 0.0


func _cancel_melee_visual() -> void:
	if lucille_character_tween != null and lucille_character_tween.is_valid():
		lucille_character_tween.kill()
	if lucille_trail_tween != null and lucille_trail_tween.is_valid():
		lucille_trail_tween.kill()
	lucille_character_tween = null
	lucille_trail_tween = null
	lucille_character_offset = Vector2.ZERO
	lucille_body_lean_rotation = 0.0
	if lucille_trail != null:
		lucille_trail.visible = false
		lucille_trail.clear_points()
		lucille_trail.modulate.a = 1.0


func _start_punch() -> bool:
	if _is_punch_blocked() or not selected_weapon_id.is_empty():
		return false

	punch_active = true
	punch_elapsed = 0.0
	punch_hit_applied = false
	punch_left_hand = next_punch_left_hand
	next_punch_left_hand = not next_punch_left_hand
	punch_direction = get_aim_direction()
	if punch_direction.length_squared() <= 0.0001:
		punch_direction = last_aim_direction
	if punch_direction.length_squared() <= 0.0001:
		punch_direction = Vector2.RIGHT
	punch_direction = punch_direction.normalized()
	punch_cooldown_left = maxf(runtime_config.player_punch_interval, 0.01)

	SFX.play_event(&"melee_swing")
	_request_combat_camera_impulse(&"small", punch_direction)
	return true


func _update_punch(delta: float) -> void:
	punch_cooldown_left = maxf(punch_cooldown_left - delta, 0.0)

	if punch_active:
		if _is_punch_blocked() or not selected_weapon_id.is_empty():
			_cancel_punch()
			return

		punch_elapsed += delta
		var windup := maxf(runtime_config.player_punch_windup_seconds, 0.01)
		var strike := maxf(runtime_config.player_punch_strike_seconds, 0.01)
		var recover := maxf(runtime_config.player_punch_recover_seconds, 0.01)
		var impact_time := windup + strike * 0.5
		if not punch_hit_applied and punch_elapsed >= impact_time:
			punch_hit_applied = true
			if _apply_punch_hits():
				_request_combat_camera_impulse(&"small", punch_direction)

		if punch_elapsed >= windup + strike + recover:
			_cancel_punch()
		return

	if (
		selected_weapon_id.is_empty()
		and punch_cooldown_left <= 0.0
		and should_trigger_weapon_attack()
	):
		_start_punch()



func _props_for_melee() -> Array:
	var world: Node = get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("get_damageable_props_snapshot"):
		return world.call("get_damageable_props_snapshot")
	return get_tree().get_nodes_in_group(&"damageable_props")


func _apply_punch_hits() -> bool:
	var origin := global_position
	var radius := maxf(runtime_config.player_punch_range, 1.0)
	var half_arc := deg_to_rad(runtime_config.player_punch_arc_degrees * 0.5)
	var world: Node = get_tree().get_first_node_in_group(&"dream_world")
	var hit_something := false
	var hit_furniture := false
	var handled: Dictionary = {}

	for enemy_variant in get_tree().get_nodes_in_group(&"dream_enemies"):
		var enemy := enemy_variant as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.get("dead") == true:
			continue
		var to_enemy := origin.direction_to(enemy.global_position)
		if to_enemy.length_squared() <= 0.0001 or absf(punch_direction.angle_to(to_enemy)) > half_arc:
			continue
		var distance := origin.distance_to(enemy.global_position)
		if enemy.has_method("distance_to_hurtbox"):
			distance = float(enemy.distance_to_hurtbox(origin))
		if distance > radius:
			continue
		if (
			world != null
			and world.has_method("is_room_projectile_path_clear")
			and not bool(world.is_room_projectile_path_clear(origin, enemy.global_position))
		):
			continue
		var enemy_id := enemy.get_instance_id()
		if handled.has(enemy_id):
			continue
		handled[enemy_id] = true
		if world != null and world.has_method("resolve_player_hit"):
			var result: Dictionary = world.resolve_player_hit(
				enemy,
				runtime_config.player_punch_damage,
				origin,
				&"player_punch"
			)
			if not result.is_empty():
				hit_something = true

	for prop_variant in _props_for_melee():
		var prop := prop_variant as Node2D
		if prop == null or not is_instance_valid(prop) or prop.get("destroyed") == true:
			continue
		var to_prop := origin.direction_to(prop.global_position)
		if to_prop.length_squared() <= 0.0001 or absf(punch_direction.angle_to(to_prop)) > half_arc:
			continue
		if origin.distance_to(prop.global_position) > radius:
			continue
		if (
			world != null
			and world.has_method("is_room_projectile_path_clear")
			and not bool(world.is_room_projectile_path_clear(origin, prop.global_position))
		):
			continue
		var prop_id := prop.get_instance_id()
		if handled.has(prop_id) or not prop.has_method("take_damage"):
			continue
		handled[prop_id] = true
		prop.take_damage(runtime_config.player_punch_damage, punch_direction, 1.0)
		hit_something = true
		hit_furniture = true
		SFX.play_melee_furniture_hit()
	if hit_furniture:
		apply_movement_impulse(
			-punch_direction,
			runtime_config.player_melee_furniture_recoil,
			0.12
		)

	# A punch is an explicit attack event, so it may give a nearby physical door
	# only a small impulse.  The door resolver owns latch/lock checks and keeps
	# this separate from the ordinary body collision path.
	if world != null and world.has_method("apply_door_impact_near"):
		var door_force := runtime_config.player_punch_damage * 12.0
		if bool(world.call("apply_door_impact_near", origin, punch_direction, radius, door_force, &"punch", get_instance_id())):
			hit_something = true

	return hit_something


func _update_punch_visual() -> void:
	if not punch_active:
		punch_left_hand_offset = Vector2.ZERO
		punch_right_hand_offset = Vector2.ZERO
		punch_body_lean_rotation = 0.0
		return

	var windup := maxf(runtime_config.player_punch_windup_seconds, 0.01)
	var strike := maxf(runtime_config.player_punch_strike_seconds, 0.01)
	var recover := maxf(runtime_config.player_punch_recover_seconds, 0.01)
	var total := windup + strike + recover
	var local_forward := punch_direction
	if visual.scale.x < 0.0:
		local_forward.x = -local_forward.x
	if local_forward.length_squared() <= 0.0001:
		local_forward = Vector2.LEFT
	local_forward = local_forward.normalized()

	var progress := clampf(punch_elapsed / maxf(total, 0.001), 0.0, 1.0)
	var windup_end := windup / total
	var strike_end := (windup + strike) / total
	var reach := 8.0
	var active_hand_offset := Vector2.ZERO
	if progress < windup_end:
		var t := sin(clampf(progress / windup_end, 0.0, 1.0) * PI * 0.5)
		active_hand_offset = -local_forward * reach * t * 0.45
		punch_body_lean_rotation = _get_lucille_lean_sign(punch_direction) * deg_to_rad(5.0) * t
	elif progress < strike_end:
		var t := 1.0 - pow(1.0 - clampf((progress - windup_end) / maxf(strike_end - windup_end, 0.001), 0.0, 1.0), 2.0)
		active_hand_offset = (-local_forward * reach * 0.45).lerp(local_forward * reach, t)
		punch_body_lean_rotation = lerpf(
			_get_lucille_lean_sign(punch_direction) * deg_to_rad(5.0),
			-_get_lucille_lean_sign(punch_direction) * deg_to_rad(3.0),
			t
		)
	else:
		var t := 1.0 - pow(1.0 - clampf((progress - strike_end) / maxf(1.0 - strike_end, 0.001), 0.0, 1.0), 2.0)
		active_hand_offset = (local_forward * reach).lerp(Vector2.ZERO, t)
		punch_body_lean_rotation = lerpf(-_get_lucille_lean_sign(punch_direction) * deg_to_rad(3.0), 0.0, t)

	if punch_left_hand:
		punch_left_hand_offset = active_hand_offset
		punch_right_hand_offset = Vector2.ZERO
	else:
		punch_left_hand_offset = Vector2.ZERO
		punch_right_hand_offset = active_hand_offset


func _set_player_head_frame(frame_index: int) -> void:
	if character_facing_back:
		for root in [visual, heal_overlay]:
			var head := root.get_node_or_null("BodyPivot/Head") as Sprite2D
			if head != null:
				head.texture = player_head_back_frame
		return

	if player_head_frames.is_empty():
		return
	player_head_frame_index = clampi(frame_index, 0, player_head_frames.size() - 1)
	for root in [visual, heal_overlay]:
		var head := root.get_node_or_null("BodyPivot/Head") as Sprite2D
		if head != null:
			head.texture = player_head_frames[player_head_frame_index]


func _get_next_blink_delay() -> float:
	return randf_range(
		runtime_config.player_blink_interval_min,
		runtime_config.player_blink_interval_max
	)


func _update_player_blink(delta: float) -> void:
	var blocked := dead or dashing or airborne_knockback or kick_active or character_facing_back
	if blocked:
		if player_blink_phase != 0 or player_head_frame_index != 0:
			player_blink_phase = 0
			player_blink_phase_left = 0.0
			_set_player_head_frame(0)
		player_blink_time_left = maxf(player_blink_time_left, 0.25)
		return

	if player_blink_phase == 0:
		player_blink_time_left -= delta
		if player_blink_time_left > 0.0:
			return
		player_blink_phase = 1
		player_blink_phase_left = maxf(runtime_config.player_blink_frame_seconds, 0.02)
		_set_player_head_frame(1)
		return

	player_blink_phase_left -= delta
	if player_blink_phase_left > 0.0:
		return

	if player_blink_phase == 1:
		player_blink_phase = 2
		player_blink_phase_left = maxf(runtime_config.player_blink_frame_seconds, 0.02)
		_set_player_head_frame(2)
	else:
		player_blink_phase = 0
		_set_player_head_frame(0)
		player_blink_time_left = _get_next_blink_delay()


func configure_feedback_audio(config: DemoConfig) -> void:
	feedback_audio.stream = TextBlipFactory.create(config)
	feedback_audio.volume_db = -14.0


## Resolve the active 3D camera's screen axes at the Player's current point
## onto the gameplay ground plane.  Sampling rays (rather than only camera yaw)
## also prevents perspective drift when the Player is off screen-center.
## Only 3D Dream roots use this adapter; the legacy 2D Dream keeps its raw
## movement axes.  The result is still a normal gameplay-space Vector2, so
## locomotion, dash and kick share one direction authority.
func _camera_relative_movement_input(screen_input: Vector2) -> Vector2:
	if screen_input.length_squared() <= 0.0001:
		return Vector2.ZERO
	var world := get_tree().get_first_node_in_group(&"dream_world") as Node3D
	if world == null:
		return screen_input
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return screen_input
	var ground_origin := world.to_global(Vector3(global_position.x / 32.0, 0.0, global_position.y / 32.0))
	var screen_origin := camera.unproject_position(ground_origin)
	var plane := Plane(world.global_basis.y.normalized(), world.global_position)
	var right_screen := screen_origin + Vector2(64.0, 0.0)
	var up_screen := screen_origin + Vector2(0.0, -64.0)
	var right_hit: Variant = plane.intersects_ray(
		camera.project_ray_origin(right_screen), camera.project_ray_normal(right_screen)
	)
	var up_hit: Variant = plane.intersects_ray(
		camera.project_ray_origin(up_screen), camera.project_ray_normal(up_screen)
	)
	if not right_hit is Vector3 or not up_hit is Vector3:
		return screen_input
	var right_map := world.global_basis.inverse() * ((right_hit as Vector3) - ground_origin)
	var up_map := world.global_basis.inverse() * ((up_hit as Vector3) - ground_origin)
	var right_direction := Vector2(right_map.x, right_map.z)
	var up_direction := Vector2(up_map.x, up_map.z)
	if right_direction.length_squared() <= 0.0001 or up_direction.length_squared() <= 0.0001:
		return screen_input
	var map_direction := right_direction.normalized() * screen_input.x - up_direction.normalized() * screen_input.y
	return map_direction.normalized() * screen_input.length()


func _read_gameplay_movement_input() -> Vector2:
	return _camera_relative_movement_input(
		Input.get_vector("move_left", "move_right", "move_up", "move_down")
	)


func _physics_process(delta: float) -> void:
	# This sample is rebuilt only by the normal locomotion branch below.  Any
	# airborne, dash, recovery or dead frame therefore contributes zero to the
	# player-driven time activity signal.
	_time_locomotion_speed = 0.0
	block_active = (
		not dead
		and InputMap.has_action("block")
		and Input.is_action_pressed("block")
	)
	invulnerability_left = maxf(0.0, invulnerability_left - delta)

	if invulnerability_left <= 0.0:
		invulnerability_reason = &""

	dash_invulnerability_left = maxf(0.0, dash_invulnerability_left - delta)
	hurt_flash_left = maxf(0.0, hurt_flash_left - delta)
	shield_break_left = maxf(0.0, shield_break_left - delta)
	revive_flash_left = maxf(0.0, revive_flash_left - delta)
	secondary_collision_cooldown_left = maxf(0.0, secondary_collision_cooldown_left - delta)

	_update_dash_recharge(delta)
	_update_ammo(delta)
	_update_weapon_name(delta)
	_update_player_blink(delta)
	_update_punch(delta)

	if not dead and Input.is_action_just_pressed("weapon_next"):
		switch_weapon_slot(1)
	elif not dead and Input.is_action_just_pressed("weapon_previous"):
		switch_weapon_slot(-1)

	if not dead and Input.is_action_just_pressed("reload_weapon"):
		request_reload()

	var kick_pressed: bool = Input.is_action_just_pressed("kick")
	var throw_action_down: bool = (
		InputMap.has_action("throw_weapon")
		and Input.is_action_pressed("throw_weapon")
	)
	var throw_pressed: bool = (
		InputMap.has_action("throw_weapon")
		and Input.is_action_just_pressed("throw_weapon")
	)
	var throw_released: bool = (
		InputMap.has_action("throw_weapon")
		and Input.is_action_just_released("throw_weapon")
	)
	# RMB is a hold-to-aim action.  The inventory is not mutated on press; only
	# release commits the same formal extraction used by knockdown drops.
	if throw_aim_active:
		if (
			dead
			or selected_weapon_id.is_empty()
			or not movement_enabled
			or dashing
			or vault_active
			or airborne_knockback
			or knockback_recovery_left > 0.0
		):
			_cancel_throw_aim()
		elif throw_released or not throw_action_down:
			_commit_throw_aim()
	elif (
		throw_pressed
		and not dead
		and movement_enabled
		and not dashing
		and not vault_active
		and not airborne_knockback
		and knockback_recovery_left <= 0.0
		and not selected_weapon_id.is_empty()
		and not tactical_plan_active
	):
		begin_throw_aim()

	if (
		not dead
		and movement_enabled
		and not dashing
		and not airborne_knockback
		and knockback_recovery_left <= 0.0
		and kick_pressed
	):
		var facing_input := _read_gameplay_movement_input()

		if facing_input.length_squared() > 0.0001:
			last_move_direction = facing_input.normalized()

		# F is reserved for Kick while the Player is unarmed.  Check the actual
		# selected slot rather than a stale category left after throwing the last
		# weapon, so Fist+F remains reliable after a throw as well.
		if kick_pressed and selected_weapon_id.is_empty():
			start_kick()

	_update_kick(delta)
	_update_held_weapon_aim()

	# Read locomotion once for both normal movement and Space tap direction.
	# DASH_PENDING deliberately keeps this path live; only DASH_AIM owns movement.
	var input_vector := Vector2.ZERO
	if scripted_locomotion_active:
		input_vector = scripted_locomotion_direction
	elif movement_enabled:
		input_vector = _read_gameplay_movement_input()
	if input_vector.length_squared() > 0.0001:
		last_move_direction = input_vector.normalized()
	if (
		movement_enabled
		and dash_input_state == DashInputState.IDLE
		and Input.is_action_just_pressed("dash")
		and _presentation_pointer_input_allowed()
	):
		_begin_dash_pending(input_vector)

	# Tactical Planning Mode (Hold Space with tactical CD ready)
	if dash_input_state == DashInputState.TACTICAL_PLAN or tactical_plan_active:
		if (
			dead
			or not movement_enabled
			or not dash_enabled
			or dashing
			or vault_active
			or airborne_knockback
			or knockback_recovery_left > 0.0
			or external_knockback_left > 0.0
			or throw_aim_active
		):
			_cancel_tactical_plan()
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (InputMap.has_action("throw_weapon") and Input.is_action_just_pressed("throw_weapon")):
			_cancel_tactical_plan()
			return
		_update_tactical_plan()
		if Input.is_action_just_released("dash"):
			if not tactical_has_destination:
				_cancel_tactical_plan()
			else:
				_execute_tactical_plan()
			return
		return

	# A held Space becomes mouse-directed DASH_AIM only after the real-time hold
	# threshold.  Its preview is read-only; release commits the cached path.
	if dash_input_state == DashInputState.AIM or dash_aim_active:
		if (
			dead
			or not movement_enabled
			or not dash_enabled
			or dashing
			or vault_active
			or airborne_knockback
			or knockback_recovery_left > 0.0
			or external_knockback_left > 0.0
			or throw_aim_active
		):
			_cancel_dash_aim()
			return
		_update_dash_aim()
		if Input.is_action_just_released("dash"):
			var committed_path := dash_aim_result.duplicate(true)
			_cancel_dash_aim()
			_commit_dash_path(committed_path)
		return

	# During the short tap/hold arbitration window WASD remains fully active.
	# A release commits the direction captured on press without ever enabling
	# DashAim, so a quick tap cannot flash the ground-arrow presentation.
	if dash_input_state == DashInputState.PENDING:
		if not can_start_dash_aim() and not can_start_tactical_plan():
			_cancel_dash_input()
		elif Input.is_action_just_released("dash"):
			var hold_thresh := (tactical_dash_hold_threshold if tactical_dash_enabled else dash_aim_hold_threshold)
			if _dash_pending_elapsed_seconds() < hold_thresh:
				var tap_direction := dash_pending_direction
				_reset_dash_input_state()
				_start_dash_legacy(tap_direction)
			else:
				if tactical_dash_enabled and can_start_tactical_plan():
					_cancel_dash_input()
				elif can_start_dash_aim():
					var tap_direction := dash_pending_direction
					_reset_dash_input_state()
					_start_dash_legacy(tap_direction)
				else:
					_cancel_dash_input()
			return
		elif not Input.is_action_pressed("dash"):
			# Focus loss or a consumed release must not leave a stale pending input.
			_cancel_dash_input()
		elif _dash_pending_elapsed_seconds() >= (tactical_dash_hold_threshold if tactical_dash_enabled else dash_aim_hold_threshold):
			if tactical_dash_enabled and can_start_tactical_plan():
				_begin_tactical_plan()
				return
			elif not tactical_dash_enabled and can_start_dash_aim():
				_begin_dash_aim()
				if dash_aim_active:
					return

	queue_redraw()
	_update_visual_feedback()

	if dead:
		velocity = Vector2.ZERO
		_time_locomotion_velocity = Vector2.ZERO
		_update_direction_animation(Vector2.ZERO, delta)
		return

	if airborne_knockback:
		_time_locomotion_velocity = Vector2.ZERO
		velocity = external_knockback_velocity
		move_and_slide()

		_handle_airborne_collisions()

		var drag_multiplier := (
			1.0
			if airborne_grounded_sliding
			else runtime_config.player_knockback_air_drag_multiplier
		)
		external_knockback_velocity = external_knockback_velocity.move_toward(
			Vector2.ZERO,
			runtime_config.character_knockback_drag * drag_multiplier * delta
		)

		if not airborne_grounded_sliding:
			knockback_height += knockback_vertical_velocity * delta
			knockback_vertical_velocity -= runtime_config.character_knockback_fake_gravity * delta

			var max_height := maxf(
				runtime_config.character_knockback_vertical_velocity
				* runtime_config.character_knockback_vertical_velocity
				/ (2.0 * maxf(runtime_config.character_knockback_fake_gravity, 1.0)),
				1.0
			)

			visual.rotation = airborne_visual_rotation_target * clampf(knockback_height / max_height, 0.0, 1.0)
			heal_overlay.rotation = visual.rotation

			if knockback_height <= 0.0 and knockback_vertical_velocity < 0.0:
				var landing_speed := absf(knockback_vertical_velocity)
				knockback_height = 0.0
				external_knockback_velocity *= runtime_config.player_knockback_ground_horizontal_retention
				var rebound_speed := landing_speed * runtime_config.player_knockback_ground_vertical_retention
				_request_combat_camera_impulse(&"small", external_knockback_velocity)
				if rebound_speed >= runtime_config.player_knockback_minimum_bounce_velocity:
					knockback_vertical_velocity = rebound_speed
				else:
					knockback_vertical_velocity = 0.0
					airborne_grounded_sliding = true
		else:
			knockback_height = 0.0
			knockback_vertical_velocity = 0.0
			visual.rotation = move_toward(visual.rotation, 0.0, TAU * delta)
			heal_overlay.rotation = visual.rotation
			if external_knockback_velocity.length() <= runtime_config.player_knockback_settle_speed:
				_finish_airborne_knockback()

		_update_direction_animation(Vector2.ZERO, delta)
		return

	if knockback_recovery_left > 0.0:
		knockback_recovery_left = maxf(0.0, knockback_recovery_left - delta)
		_time_locomotion_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		_update_direction_animation(Vector2.ZERO, delta)
		if knockback_recovery_left <= 0.0:
			_set_weapon_activity(not dead)
		return

	if vault_active:
		_time_locomotion_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		_update_vault(delta)
		return

	if dashing:
		_time_locomotion_velocity = Vector2.ZERO
		_reset_stillness()
		_update_direction_animation(dash_end - dash_start, delta)
		_update_dash(delta)
		_emit_dash_state()
		return

	_update_sleep_spindle(delta)

	var position_before := global_position
	var movement_speed_multiplier := 0.5 if block_active else 1.0
	var effective_speed := scripted_locomotion_speed if scripted_locomotion_active else (movement_speed * movement_speed_multiplier)
	var desired_velocity: Vector2 = (
		input_vector.normalized() * effective_speed
		if input_vector.length_squared() > 0.0001
		else Vector2.ZERO
	)
	var response_rate: float = (
		maxf(runtime_config.player_movement_acceleration, 1.0)
		if desired_velocity.length_squared() > 0.0001
		else maxf(runtime_config.player_movement_deceleration, 1.0)
	)
	_time_locomotion_velocity = _time_locomotion_velocity.move_toward(
		desired_velocity,
		response_rate * delta
	)
	velocity = _time_locomotion_velocity
	var impulse_velocity_before := Vector2.ZERO
	if movement_impulse_left > 0.0:
		impulse_velocity_before = movement_impulse_velocity
		velocity += movement_impulse_velocity
		movement_impulse_left = maxf(movement_impulse_left - delta, 0.0)
		movement_impulse_velocity = movement_impulse_velocity.move_toward(Vector2.ZERO, 620.0 * delta)
	else:
		movement_impulse_velocity = Vector2.ZERO
	if desired_velocity == Vector2.ZERO and _time_locomotion_velocity.length_squared() < 1.0:
		_time_locomotion_velocity = Vector2.ZERO
		velocity = impulse_velocity_before

	# 动画方向取实际响应后的速度；松开按键的短暂减速仍保持自然步态，
	# 但不会让输入方向出现额外的Aim/转向延迟。
	_update_direction_animation(
		velocity if velocity.length_squared() > 0.0001 else input_vector,
		delta
	)
	move_and_slide()

	# Use post-collision gameplay displacement, subtracting only the explicit
	# lightweight impulse applied by this frame.  The resulting component is the
	# formal locomotion sample consumed by DreamTimeController; it never uses a
	# real-time delta and cannot be driven by airborne/knockback state.
	if delta > 0.000001:
		var actual_step := global_position - position_before
		var locomotion_step := actual_step - impulse_velocity_before * delta
		if desired_velocity.length_squared() > 0.0001:
			var locomotion_direction := desired_velocity.normalized()
			var signed_speed := locomotion_step.dot(locomotion_direction) / delta
			_time_locomotion_velocity = locomotion_direction * clampf(
				maxf(signed_speed, 0.0),
				0.0,
				maxf(movement_speed, 1.0)
			)
		else:
			# Convert displacement back to a gameplay-speed sample before clamping;
			# limiting the displacement itself would mix pixel/frame and pixel/second.
			_time_locomotion_velocity = (locomotion_step / delta).limit_length(maxf(movement_speed, 1.0))
	_time_locomotion_speed = _time_locomotion_velocity.length()

	_push_rigid_props(input_vector)
	_update_sleep_paralysis(delta, global_position - position_before)
	_emit_dash_state()


func _push_rigid_props(input_direction: Vector2) -> void:
	if input_direction.length_squared() <= 0.001:
		return

	var normalized_input := input_direction.normalized()

	for i: int in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)

		if collision == null:
			continue

		var collider := collision.get_collider()

		if collider != null and collider.is_in_group(&"physical_doors"):
			var push_direction := -collision.get_normal()
			if push_direction.length_squared() > 0.001 and normalized_input.dot(push_direction.normalized()) > 0.1:
				var door_node: Node = null
				if collider.get("door_owner") is Node:
					door_node = collider.get("door_owner") as Node
				elif collider.has_meta(&"physical_door_node"):
					var d_ref = collider.get_meta(&"physical_door_node")
					door_node = d_ref.get_ref() if d_ref is WeakRef else d_ref
				elif collider.has_method("apply_door_impact"):
					door_node = collider

				if door_node != null and door_node.has_method("apply_door_impact"):
					var is_locked: bool = door_node.get("locked") == true
					var is_destroyed: bool = door_node.get("is_destroyed") == true
					if not is_locked and not is_destroyed:
						var leaf_idx: int = int(collider.get("leaf_index")) if collider.get("leaf_index") != null else -1
						var contact_point := Vector3(global_position.x / 32.0, 1.5, global_position.y / 32.0)
						var push_dir_3d := Vector3(push_direction.x, 0.0, push_direction.y).normalized()
						door_node.call("apply_door_impact", &"player_push", contact_point, push_dir_3d, 260.0, &"", leaf_idx)
			continue

		if not collider is RigidBody2D:
			continue

		var body := collider as RigidBody2D

		if not body.is_in_group("pushable_prop"):
			continue

		var push_direction := -collision.get_normal()

		if push_direction.length_squared() <= 0.001:
			continue

		push_direction = push_direction.normalized()

		var push_alignment := normalized_input.dot(push_direction)

		if push_alignment <= 0.1:
			continue

		if body.has_method(&"apply_player_push"):
			body.call(
				&"apply_player_push",
				push_direction,
				prop_push_force,
				push_alignment,
				collision.get_position()
			)
		else:
			body.apply_central_force(
				push_direction
				* prop_push_force
				* push_alignment
			)


## F踢击使用角色面朝/最后移动方向，不读取鼠标瞄准方向。
func start_kick() -> bool:
	if dead or dashing or vault_active or kick_active or kick_blocked_by_interaction:
		return false
	_cancel_punch()

	# Kick优先：取消近战身体动作，避免两个位移叠加。
	_cancel_melee_visual()

	kick_character_offset = Vector2.ZERO
	kick_body_lean_rotation = 0.0

	kick_direction = (
		last_move_direction.normalized()
		if last_move_direction.length_squared() > 0.0001
		else Vector2.RIGHT
	)

	kick_left_foot = next_kick_left_foot
	next_kick_left_foot = not next_kick_left_foot
	kick_active = true
	kick_elapsed = 0.0
	kick_hit_applied = false

	_request_combat_camera_impulse(&"medium", kick_direction)
	_reset_stillness()

	return true


func set_kick_interaction_blocked(blocked: bool) -> void:
	kick_blocked_by_interaction = blocked


func _update_kick(delta: float) -> void:
	if not kick_active:
		return

	kick_elapsed += delta

	var duration := maxf(runtime_config.kick_animation_duration, 0.01)
	var progress := clampf(kick_elapsed / duration, 0.0, 1.0)

	## 仍然保持原本38%的正式命中时机。
	if not kick_hit_applied and progress >= 0.38:
		kick_hit_applied = true
		_apply_kick_hits()

	if progress >= 1.0:
		kick_active = false
		kick_elapsed = 0.0
		kick_hit_applied = false
		kick_character_offset = Vector2.ZERO
		kick_body_lean_rotation = 0.0


func _apply_kick_hits() -> void:
	if _kick_query == null:
		_kick_shape = RectangleShape2D.new()
		_kick_query = PhysicsShapeQueryParameters2D.new()
		_kick_query.shape = _kick_shape
		_kick_query.collide_with_bodies = true
		_kick_query.collide_with_areas = false
		_kick_query.collision_mask = 2 | 8

	_kick_shape.size = Vector2(
		runtime_config.kick_range,
		runtime_config.kick_width
	)

	_kick_query.exclude = [get_rid()]

	var center := global_position + kick_direction * (
		runtime_config.kick_range * 0.5 + 6.0
	)

	_kick_query.transform = Transform2D(
		kick_direction.angle(),
		center
	)

	var hits := get_world_2d().direct_space_state.intersect_shape(
		_kick_query,
		32
	)
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("apply_door_impact_near"):
		# Kick uses the current formal knockback force and is intentionally much
		# stronger than the E push and unarmed punch paths.
		world.call(
			"apply_door_impact_near",
			global_position,
			kick_direction,
			runtime_config.kick_range,
			runtime_config.get_kick_knockback_force(),
			&"kick",
			get_instance_id()
		)

	var handled: Dictionary = {}

	for hit in hits:
		var target_node := hit.get("collider") as Node

		if target_node == null or handled.has(target_node.get_instance_id()):
			continue

		handled[target_node.get_instance_id()] = true

		if target_node.is_in_group("dream_enemies") and target_node.has_method("take_damage"):
			target_node.set_meta(&"last_damage_source", &"kick")

			if target_node.has_method("start_knockdown"):
				target_node.take_damage(
					runtime_config.kick_damage,
					global_position,
					1.0,
					&"kick"
				)
			else:
				target_node.take_damage(
					runtime_config.kick_damage,
					global_position
				)

		elif target_node is RigidBody2D and target_node.is_in_group("pushable_prop"):
			if (
				world != null
				and world.has_method("is_room_projectile_path_clear")
				and not bool(world.is_room_projectile_path_clear(global_position, (target_node as Node2D).global_position))
			):
				continue
			if target_node.has_method(&"apply_player_kick_impulse"):
				target_node.call(
					&"apply_player_kick_impulse",
					kick_direction,
					runtime_config.get_kick_knockback_force(),
					global_position
				)
			elif target_node.has_method("apply_combat_impulse"):
				target_node.apply_combat_impulse(
					kick_direction,
					runtime_config.get_kick_knockback_force()
				)
			else:
				(target_node as RigidBody2D).apply_central_impulse(
					kick_direction * runtime_config.get_kick_knockback_force()
				)


## 把步态相位换算成「半步序号」：相位每 π 恰好是一只脚从抬起回到地面。
## step_interval 允许把多步并作一声，从而在不改动画节奏的前提下稀疏化脚步。
static func footstep_phase_index(phase: float, step_interval: int) -> int:
	return int(phase / (PI * float(maxi(step_interval, 1))))


## 脚步挂在腿部动画的落地时刻上，而不是另开一个定时器：半步序号变化就是
## 该响一声的时刻。由此角色加速时脚步自动变密、停下时自动停止，且与画面
## 上脚的落点同步。
func _play_footsteps_for_gait() -> void:
	var phase_index := footstep_phase_index(
		walk_animation_time,
		runtime_config.player_footstep_step_interval
	)
	if phase_index == last_footstep_phase_index:
		return
	last_footstep_phase_index = phase_index
	SFX.play_event(&"footstep")


func _update_direction_animation(motion: Vector2, delta: float) -> void:
	if visual == null:
		return

	## Scene中保存的Pivot transform是唯一基准。
	body_pivot.rotation = body_base_rotation

	var moving := motion.length_squared() > 0.0001
	var direction := motion.normalized() if moving else last_move_direction

	# 角色朝向由瞄准方向（Mouse Aim Direction）驱动
	var aim_dir := get_aim_direction()
	if aim_dir.length_squared() <= 0.0001:
		aim_dir = direction

	# 上方 90° 扇区（[-135°, -45°]）：背向模式
	var facing_back := aim_dir.y < 0.0 and absf(aim_dir.y) >= absf(aim_dir.x)
	var facing_right := aim_dir.x >= 0.0

	var facing_changed := (facing_back != character_facing_back) or (facing_right != character_facing_right)

	if facing_changed:
		character_facing_back = facing_back
		character_facing_right = facing_right

		var target_head_frames := player_head_right_frames if character_facing_right else player_head_left_frames
		player_head_frames.clear()
		player_head_frames.append_array(target_head_frames)

		_apply_character_part_set(character_facing_back)
		_refresh_held_weapon_depth()

	# 角色视觉缩放：不再水平镜像翻转，左右朝向均直接使用专属切片
	visual.scale = Vector2(
		character_visual_scale,
		character_visual_scale
	)

	heal_overlay.scale = visual.scale
	_update_punch_visual()

	var suppress_idle_motion := dead or dashing or airborne_knockback or kick_active
	if moving and not suppress_idle_motion:
		idle_animation_time = 0.0

		var speed_ratio := clampf(
			velocity.length()
			/ maxf(movement_speed, 1.0),
			0.25,
			1.5
		)

		walk_animation_time += (
			delta
			* TAU
			* runtime_config.player_walk_cycles_per_second
			* speed_ratio
		)

		_play_footsteps_for_gait()

		var left_phase := sin(walk_animation_time)
		var right_phase := sin(walk_animation_time + PI)

		_set_part_position(
			left_leg,
			left_leg_base_position + Vector2(
				roundf(
					left_phase
					* runtime_config.player_walk_leg_swing_pixels
				),
				-roundf(
					maxf(left_phase, 0.0)
					* runtime_config.player_walk_leg_lift_pixels
				)
			)
		)

		_set_part_position(
			right_leg,
			right_leg_base_position + Vector2(
				roundf(
					right_phase
					* runtime_config.player_walk_leg_swing_pixels
				),
				-roundf(
					maxf(right_phase, 0.0)
					* runtime_config.player_walk_leg_lift_pixels
				)
			)
		)

		var bob := roundf(
			absf(sin(walk_animation_time))
			* runtime_config.player_walk_body_bob_pixels
		)

		walk_visual_bounce = -roundf(
			absf(sin(walk_animation_time))
			* runtime_config.player_walk_visual_bounce_pixels
		)

		_set_part_position(
			body_pivot,
			body_base_position + Vector2(0, -bob)
		)

		_set_part_position(
			head_part,
			head_base_position
		)

	elif suppress_idle_motion:
		## Launch / Roll / Kick视觉优先于Walk Bob与Idle Breathing；
		## 真正的地面位移和CharacterVisual假高度仍由各自系统处理。
		walk_animation_time = 0.0
		walk_visual_bounce = 0.0
		last_footstep_phase_index = -1
		_set_part_position(left_leg, left_leg_base_position)
		_set_part_position(right_leg, right_leg_base_position)
		_set_part_position(body_pivot, body_base_position)
		_set_part_position(head_part, head_base_position)

	else:
		walk_animation_time = 0.0
		walk_visual_bounce = 0.0
		last_footstep_phase_index = -1

		idle_animation_time = fmod(
			idle_animation_time + delta,
			maxf(
				runtime_config.player_idle_breath_period,
				0.1
			)
		)

		var breath_phase := (
			1.0
			- cos(
				TAU
				* idle_animation_time
				/ maxf(
					runtime_config.player_idle_breath_period,
					0.1
				)
			)
		) * 0.5

		_set_part_position(
			left_leg,
			left_leg_base_position
		)

		_set_part_position(
			right_leg,
			right_leg_base_position
		)

		var body_breath := roundf(
			breath_phase
			* runtime_config.player_idle_body_breath_pixels
		)

		var head_breath := roundf(
			breath_phase
			* runtime_config.player_idle_head_breath_pixels
		)

		_set_part_position(
			body_pivot,
			body_base_position + Vector2(
				0,
				-body_breath
			)
		)

		_set_part_position(
			head_part,
			head_base_position + Vector2(
				0,
				body_breath - head_breath
			)
		)

	_update_hands_visibility()

	## Kick本身处理腿和BodyPivot。
	_apply_kick_visual_offsets()

	## Kick优先；只有没有Kick时才叠加其它上半身动作。
	if not kick_active:
		body_pivot.rotation += lucille_body_lean_rotation
		body_pivot.rotation += punch_body_lean_rotation

	_sync_heal_part_positions()


## 新Kick动画：
## 快速起跳后撤 → 身体后仰 → 猛踢前扑 → 收腿回位。
func _apply_kick_visual_offsets() -> void:
	if not kick_active:
		kick_character_offset = Vector2.ZERO
		kick_body_lean_rotation = 0.0
		return

	var duration := maxf(
		runtime_config.kick_animation_duration,
		0.01
	)

	var progress := clampf(
		kick_elapsed / duration,
		0.0,
		1.0
	)

	## 第一阶段：25%时到达后撤蓄力峰值。
	## 第二阶段：55%时到达踢击最远点。
	var windup_end := 0.25
	var strike_end := 0.55

	## 复用原本Kick配置，不新增配置字段。
	var back_distance := runtime_config.kick_body_lean_pixels
	var forward_distance := runtime_config.kick_body_lean_pixels * 1.5

	## 起跳高度从腿伸展幅度自动派生。
	var hop_height := maxf(
		runtime_config.kick_leg_extension_pixels * 0.22,
		3.0
	)

	var back_offset := (
		-kick_direction
		* back_distance
	)

	back_offset.y -= hop_height

	var forward_offset := (
		kick_direction
		* forward_distance
	)

	## 踢到最远处仍然稍微离地。
	forward_offset.y -= hop_height * 0.30

	var maximum_lean := deg_to_rad(
		runtime_config.kick_body_max_lean_degrees
	)

	maximum_lean *= _get_kick_lean_sign(
		kick_direction
	)

	var leg_extension := 0.0

	if progress < windup_end:
		## --------------------------
		## 第一阶段
		## 快速起跳 + 后撤 + 后仰
		## --------------------------
		var t := clampf(
			progress / windup_end,
			0.0,
			1.0
		)

		var eased := sin(
			t * PI * 0.5
		)

		kick_character_offset = Vector2.ZERO.lerp(
			back_offset,
			eased
		)

		kick_body_lean_rotation = (
			maximum_lean
			* eased
		)

		## 蓄力时腿稍微往回缩。
		leg_extension = lerpf(
			0.0,
			-0.15,
			eased
		)

	elif progress < strike_end:
		## --------------------------
		## 第二阶段
		## 从后仰位置猛地向前踢
		## --------------------------
		var t := clampf(
			(progress - windup_end)
			/ maxf(
				strike_end - windup_end,
				0.001
			),
			0.0,
			1.0
		)

		var eased := 1.0 - pow(
			1.0 - t,
			2.0
		)

		kick_character_offset = back_offset.lerp(
			forward_offset,
			eased
		)

		## 后仰 → 中心 → 略微前压。
		kick_body_lean_rotation = lerpf(
			maximum_lean,
			-maximum_lean * 0.22,
			eased
		)

		## 腿从收缩迅速伸到最大。
		leg_extension = lerpf(
			-0.15,
			1.0,
			eased
		)

	else:
		## --------------------------
		## 第三阶段
		## 收腿 + 落地 + 回原位
		## --------------------------
		var t := clampf(
			(progress - strike_end)
			/ maxf(
				1.0 - strike_end,
				0.001
			),
			0.0,
			1.0
		)

		var eased := 1.0 - pow(
			1.0 - t,
			2.0
		)

		kick_character_offset = forward_offset.lerp(
			Vector2.ZERO,
			eased
		)

		kick_body_lean_rotation = lerpf(
			-maximum_lean * 0.22,
			0.0,
			eased
		)

		leg_extension = lerpf(
			1.0,
			0.0,
			eased
		)

	## --------------------------
	## 腿本身的四方向移动
	## --------------------------
	var local_direction := kick_direction

	## 源角色素材水平朝左。
	## 向右时CharacterVisual自身已经镜像，
	## 因此水平Kick继续统一使用局部LEFT。
	if absf(kick_direction.x) > absf(kick_direction.y):
		local_direction = Vector2.LEFT

	var leg_offset := (
		local_direction
		* runtime_config.kick_leg_extension_pixels
		* leg_extension
	)

	## 踢出的过程中腿稍微抬高。
	leg_offset.y -= (
		maxf(
			leg_extension,
			0.0
		)
		* 2.0
	)

	## 只移动当前主动脚，另一只脚保持支撑基准；每次Kick交替左右脚。
	var kicking_leg: Sprite2D = left_leg if kick_left_foot else right_leg
	var kicking_leg_base: Vector2 = left_leg_base_position if kick_left_foot else right_leg_base_position
	var support_leg: Sprite2D = right_leg if kick_left_foot else left_leg
	var support_leg_base: Vector2 = right_leg_base_position if kick_left_foot else left_leg_base_position
	_set_part_position(support_leg, support_leg_base)
	_set_part_position(
		kicking_leg,
		kicking_leg_base + leg_offset
	)

	## Head是BodyPivot子节点。
	## 所以这里只旋转Pivot一次，整个上半身一起后仰/前压。
	body_pivot.rotation = (
		body_base_rotation
		+ kick_body_lean_rotation
	)


func _get_kick_lean_sign(direction: Vector2) -> float:
	if absf(direction.x) >= absf(direction.y):
		return -1.0 if direction.x > 0.0 else 1.0

	## 俯视上下方向用相反侧倾表示后仰。
	return 1.0 if direction.y > 0.0 else -1.0


func _update_visual_feedback() -> void:
	if visual == null:
		return

	# Dash的无敌帧不参与角色闪烁。
	# 只有受伤/出生等普通无敌状态才播放闪烁。
	var visible_invulnerability: float = invulnerability_left

	var flash_frequency := (
		3.0
		if invulnerability_reason == &"dream_spawn"
		else hurt_flash_frequency
	)

	visual.visible = (
		visible_invulnerability <= 0.0
		or fmod(
			visible_invulnerability * flash_frequency,
			2.0
		) < 1.0
	)

	visual.modulate = (
		Color("e66f6b")
		if hurt_flash_left > 0.0
		else Color.WHITE
	)

	if revive_flash_left > 0.0:
		visual.modulate = Color("e2c56e")

	visual.modulate.a = (
		0.72
		if visible_invulnerability > 0.0
		else 1.0
	)

	var shake := (
		Vector2(
			sin(hurt_flash_left * 90.0),
			cos(hurt_flash_left * 73.0)
		)
		* hurt_shake_pixels
		if hurt_flash_left > 0.0
		else Vector2.ZERO
	)

	## 角色视觉：
	## 基础位置
	## + 走路弹跳
	## + 击飞高度
	## + Lucille动作
	## + Kick动作
	## + 受伤震动。
	visual.position = (
		visual_home_position
		+ Vector2(
			0.0,
			(0.0 if airborne_knockback else walk_visual_bounce) - knockback_height
		)
		+ lucille_character_offset
		+ kick_character_offset
		+ dash_roll_visual_offset
		+ shake
	)

	heal_overlay.position = visual.position

	## WeaponRoot必须跟随角色攻击动作一起运动。
	weapon_root.position = (
		runtime_config.player_weapon_root_offset
		+ lucille_character_offset
		+ kick_character_offset
		+ Vector2(
			0.0,
			-knockback_height
		)
	)

	heal_overlay.visible = visual.visible


func _update_dash_recharge(delta: float) -> void:
	if tactical_dash_cooldown_left > 0.0:
		tactical_dash_cooldown_left = maxf(0.0, tactical_dash_cooldown_left - delta)

	if dash_charges >= max_dash_charges:
		dash_cooldown_left = 0.0
		return

	dash_cooldown_left = maxf(
		0.0,
		dash_cooldown_left - delta
	)

	if dash_cooldown_left <= 0.0:
		dash_charges += 1

		if dash_charges < max_dash_charges:
			dash_cooldown_left = dash_cooldown


func is_empty_handed() -> bool:
	## Empty/Fist is represented by the selected equipped weapon, not by the
	## inventory contents.  Worlds use this for the only automatic-equip case.
	return selected_weapon_id.is_empty()


func is_dash_aim_active() -> bool:
	return dash_aim_active


func get_dash_path_result() -> Dictionary:
	return dash_aim_result.duplicate(true)


func can_start_dash_aim() -> bool:
	if (
		dead
		or not movement_enabled
		or not dash_enabled
		or dash_charges <= 0
		or dash_cooldown_left > 0.0
		or dashing
		or vault_active
		or airborne_knockback
		or knockback_recovery_left > 0.0
		or external_knockback_left > 0.0
		or throw_aim_active
		or punch_active
		or kick_active
	):
		return false
	for weapon_variant in [lucille_weapon, books_weapon]:
		var melee_weapon: Node = weapon_variant as Node
		if melee_weapon != null and bool(melee_weapon.get("melee_action_active")):
			return false
	return true


func _begin_dash_pending(input_direction: Vector2) -> void:
	if not can_start_dash_aim() and not can_start_tactical_plan():
		return
	var direction := input_direction.normalized()
	if direction.length_squared() <= 0.0001:
		# When standing still, prioritize vaulting if facing or aiming at vaultable furniture
		var aim_dir := get_aim_direction().normalized()
		var move_dir := last_move_direction.normalized()
		var chosen_dir := Vector2.ZERO
		if aim_dir.length_squared() > 0.0001:
			var test_path := resolve_dash_path(aim_dir)
			for seg in test_path.get("segments", []):
				if seg.get("kind") == &"vault":
					chosen_dir = aim_dir
					break
		if chosen_dir.is_zero_approx() and move_dir.length_squared() > 0.0001:
			var test_path2 := resolve_dash_path(move_dir)
			for seg in test_path2.get("segments", []):
				if seg.get("kind") == &"vault":
					chosen_dir = move_dir
					break
		if chosen_dir.is_zero_approx():
			if move_dir.length_squared() > 0.0001:
				chosen_dir = move_dir
			elif aim_dir.length_squared() > 0.0001:
				chosen_dir = aim_dir
			else:
				chosen_dir = Vector2.RIGHT
		direction = chosen_dir
	dash_input_state = DashInputState.PENDING
	dash_pending_started_usec = Time.get_ticks_usec()
	# Tap Dash preserves the legacy press-time movement intent even though WASD
	# remains responsive throughout the short pending window.
	dash_pending_direction = direction


func _dash_pending_elapsed_seconds() -> float:
	if dash_input_state != DashInputState.PENDING or dash_pending_started_usec <= 0:
		return 0.0
	return maxf(
		float(Time.get_ticks_usec() - dash_pending_started_usec) / 1000000.0,
		0.0
	)


func _reset_dash_input_state() -> void:
	dash_input_state = DashInputState.IDLE
	dash_pending_started_usec = 0
	dash_pending_direction = Vector2.RIGHT


func _cancel_dash_input() -> void:
	_reset_dash_input_state()
	_cancel_dash_aim()
	_cancel_tactical_plan()


func _begin_dash_aim() -> void:
	if not can_start_dash_aim():
		_cancel_dash_input()
		return
	dash_input_state = DashInputState.AIM
	dash_pending_started_usec = 0
	dash_aim_active = true
	dash_aim_result = resolve_dash_path(get_aim_direction())
	dash_aim_state_changed.emit(true)
	dash_path_preview_changed.emit(dash_aim_result.duplicate(true))


func _update_dash_aim() -> void:
	if not dash_aim_active:
		return
	dash_aim_result = resolve_dash_path(get_aim_direction())
	dash_path_preview_changed.emit(dash_aim_result.duplicate(true))


func _cancel_dash_aim() -> void:
	_reset_dash_input_state()
	if not dash_aim_active and dash_aim_result.is_empty():
		return
	dash_aim_active = false
	dash_aim_result.clear()
	dash_aim_state_changed.emit(false)
	dash_path_preview_changed.emit({})


func _unhandled_input(event: InputEvent) -> void:
	if not tactical_plan_active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_tactical_plan_click()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_tactical_plan()
			get_viewport().set_input_as_handled()


func can_start_tactical_plan() -> bool:
	if (
		dead
		or not movement_enabled
		or not dash_enabled
		or not tactical_dash_enabled
		or tactical_dash_cooldown_left > 0.0
		or dashing
		or vault_active
		or airborne_knockback
		or knockback_recovery_left > 0.0
		or external_knockback_left > 0.0
		or throw_aim_active
		or punch_active
		or kick_active
	):
		return false
	for weapon_variant in [lucille_weapon, books_weapon]:
		var melee_weapon: Node = weapon_variant as Node
		if melee_weapon != null and bool(melee_weapon.get("melee_action_active")):
			return false
	return true


func _begin_tactical_plan() -> void:
	if not can_start_tactical_plan():
		_cancel_dash_input()
		return
	dash_input_state = DashInputState.TACTICAL_PLAN
	dash_pending_started_usec = 0
	tactical_plan_active = true
	tactical_plan_stage = 0
	tactical_has_destination = false
	tactical_has_aim_target = false
	tactical_destination = global_position
	tactical_aim_target = global_position

	var mouse_pos := get_constrained_aim_position()
	tactical_path_result = resolve_tactical_dash_path(mouse_pos)
	tactical_destination = tactical_path_result.get("end", global_position)
	tactical_aim_target = mouse_pos

	var time_controller := _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("begin_tactical_planning"):
		time_controller.call("begin_tactical_planning", tactical_dash_time_scale)

	if tactical_preview_overlay != null:
		tactical_preview_overlay.start_preview(visual, dash_distance * tactical_dash_distance_multiplier)
		tactical_preview_overlay.update_destination(tactical_path_result, false)
		tactical_preview_overlay.update_aim(tactical_aim_target, false)

	SFX.play_event(&"dash")
	tactical_plan_state_changed.emit(true, 0, tactical_destination, tactical_aim_target)


func _get_dream_time_controller() -> Node:
	var tc := get_tree().get_first_node_in_group(&"dream_time_controller")
	if tc != null:
		return tc
	var root := get_tree().root
	if root != null:
		var direct := root.get_node_or_null("DreamTimeController")
		if direct != null:
			return direct
		return root.find_child("DreamTimeController", true, false)
	return null


func _begin_dive_bullet_time() -> void:
	dive_bullet_time_active = true
	var tc := _get_dream_time_controller()
	if tc != null and tc.has_method("begin_dive_time"):
		tc.call("begin_dive_time", dive_bullet_time_scale)
	else:
		Engine.time_scale = dive_bullet_time_scale


func _end_dive_bullet_time() -> void:
	if not dive_bullet_time_active:
		return
	dive_bullet_time_active = false
	var tc := _get_dream_time_controller()
	if tc != null and tc.has_method("end_dive_time"):
		tc.call("end_dive_time")
	else:
		Engine.time_scale = 1.0


func is_dive_airborne() -> bool:
	if not dashing or not is_diving:
		return false
	var overall_progress := clampf(dash_elapsed / maxf(active_dash_duration, 0.001), 0.0, 1.0)
	return overall_progress < dive_airborne_ratio


func _update_tactical_plan() -> void:
	if not tactical_plan_active:
		return
	var mouse_pos := get_constrained_aim_position()
	if tactical_plan_stage == 0:
		tactical_path_result = resolve_tactical_dash_path(mouse_pos)
		tactical_destination = tactical_path_result.get("end", global_position)
		tactical_aim_target = mouse_pos
		if tactical_preview_overlay != null:
			tactical_preview_overlay.update_destination(tactical_path_result, false)
			# Also pass aim so the shooting-direction arrow follows the cursor
			tactical_preview_overlay.update_aim(tactical_aim_target, false)
	elif tactical_plan_stage == 1:
		if not tactical_has_aim_target:
			tactical_aim_target = mouse_pos
		if tactical_preview_overlay != null:
			tactical_preview_overlay.update_aim(tactical_aim_target, tactical_has_aim_target)

	tactical_plan_state_changed.emit(true, tactical_plan_stage, tactical_destination, tactical_aim_target)


func _handle_tactical_plan_click() -> void:
	if not tactical_plan_active:
		return
	var mouse_world := get_constrained_aim_position()
	if tactical_plan_stage == 0:
		plan_tactical_destination(mouse_world)
	elif tactical_plan_stage == 1:
		plan_tactical_aim(mouse_world)


func plan_tactical_destination(target_pos: Vector2) -> bool:
	if not tactical_plan_active:
		return false
	tactical_path_result = resolve_tactical_dash_path(target_pos)
	if not bool(tactical_path_result.get("valid", false)):
		return false
	tactical_destination = tactical_path_result.get("end", global_position)
	tactical_has_destination = true
	tactical_plan_stage = 1
	tactical_aim_target = target_pos
	tactical_has_aim_target = false
	if tactical_preview_overlay != null:
		tactical_preview_overlay.update_destination(tactical_path_result, true)
		tactical_preview_overlay.update_aim(tactical_aim_target, false)
	tactical_plan_state_changed.emit(true, 1, tactical_destination, tactical_aim_target)
	SFX.play_event(&"confirm")
	return true


func plan_tactical_aim(target_pos: Vector2) -> void:
	if not tactical_plan_active:
		return
	tactical_aim_target = target_pos
	tactical_has_aim_target = true
	if tactical_preview_overlay != null:
		tactical_preview_overlay.update_aim(tactical_aim_target, true)
	tactical_plan_state_changed.emit(true, tactical_plan_stage, tactical_destination, tactical_aim_target)
	SFX.play_event(&"confirm")


func _cancel_tactical_plan() -> void:
	if not tactical_plan_active and dash_input_state != DashInputState.TACTICAL_PLAN:
		return
	tactical_plan_active = false
	tactical_has_destination = false
	tactical_has_aim_target = false
	tactical_plan_stage = 0
	tactical_path_result.clear()
	_reset_dash_input_state()

	if tactical_preview_overlay != null:
		tactical_preview_overlay.end_preview()

	var time_controller := _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("end_tactical_planning"):
		time_controller.call("end_tactical_planning")

	tactical_dash_cooldown_left = 0.0
	tactical_plan_state_changed.emit(false, 0, Vector2.ZERO, Vector2.ZERO)


func _execute_tactical_plan() -> void:
	if not tactical_plan_active or not tactical_has_destination:
		_cancel_tactical_plan()
		return

	var path_to_run := tactical_path_result.duplicate(true)
	var final_aim := tactical_aim_target
	if not tactical_has_aim_target:
		final_aim = get_constrained_aim_position()

	if tactical_preview_overlay != null:
		tactical_preview_overlay.end_preview()

	var time_controller := _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("end_tactical_planning"):
		time_controller.call("end_tactical_planning")

	tactical_plan_active = false
	tactical_has_destination = false
	tactical_has_aim_target = false
	tactical_plan_stage = 0
	_reset_dash_input_state()

	tactical_dash_cooldown_left = tactical_dash_cooldown_seconds
	is_tactical_dash_executing = true
	tactical_attack_target = final_aim

	var segments_variant: Variant = path_to_run.get("segments", [])
	if segments_variant is Array and not segments_variant.is_empty():
		_commit_dash_path(path_to_run)
	else:
		is_tactical_dash_executing = false
		tactical_attack_target = Vector2.ZERO


func _execute_tactical_attack(target_pos: Vector2) -> void:
	var aim_dir := global_position.direction_to(target_pos)
	if aim_dir.length_squared() <= 0.0001:
		aim_dir = last_aim_direction
	if aim_dir.length_squared() <= 0.0001:
		aim_dir = Vector2.RIGHT
	aim_dir = aim_dir.normalized()
	last_aim_direction = aim_dir

	var active_weapon := get_active_weapon()
	var category := DreamGunAtlas.get_category(selected_weapon_id)

	if selected_weapon_id.is_empty():
		_start_punch()
		return

	if category == DreamGunAtlas.CATEGORY_MELEE:
		if active_weapon != null and active_weapon.has_method("_perform_swing"):
			active_weapon.set("cooldown_left", active_weapon.get("attack_interval"))
			active_weapon.call("_perform_swing", true)
		return

	if DreamGunAtlas.has_firearm(selected_weapon_id) or category == DreamGunAtlas.CATEGORY_RANGED:
		var uses_ammo := weapon_uses_ammo(selected_weapon_id)
		var current_ammo := 1
		if uses_ammo:
			current_ammo = int(ammo_states.get(selected_weapon_id, {}).get("current", 0))

		if current_ammo > 0:
			if not uses_ammo or try_consume_ammo_for_attack():
				if active_weapon != null:
					if active_weapon.has_method("_fire_once"):
						active_weapon.call("_fire_full_volley", aim_dir, true, false)
						active_weapon.set("cooldown_left", active_weapon.get("attack_interval"))
						active_weapon.weapon_fired.emit(active_weapon.get("recoil_multiplier"))
					elif active_weapon.has_method("_fire"):
						active_weapon.call("_fire", aim_dir, true)
						active_weapon.set("cooldown_left", active_weapon.get("attack_interval"))
						active_weapon.weapon_fired.emit(active_weapon.get("recoil_multiplier"))
		else:
			# 0 ammo: throw the empty firearm towards target!
			var throw_data := take_active_weapon_for_throw()
			if not throw_data.is_empty():
				throw_data["direction"] = aim_dir
				weapon_drop_requested.emit(throw_data)


func resolve_tactical_dash_path(target_position: Vector2) -> Dictionary:
	var max_dist := dash_distance * tactical_dash_distance_multiplier
	var diff := target_position - global_position
	var target_dist := diff.length()
	var dash_direction := diff.normalized() if target_dist > 0.0001 else last_aim_direction.normalized()
	if dash_direction.length_squared() <= 0.0001:
		dash_direction = Vector2.RIGHT

	var total_allowed := minf(target_dist, max_dist)
	var start := global_position
	var current := start
	var remaining := maxf(total_allowed, 0.0)
	var travelled := 0.0
	var segments: Array = []
	var vault_targets: Array = []
	var ignored_bodies: Array = []
	var blocked := false
	var vault_count := 0
	var step_size := 3.0

	while remaining > 0.5 and vault_count <= 4:
		var segment_start := current
		var previous := current
		var sample_distance := step_size
		var segment_finished := false
		var vault_accepted := false
		while sample_distance <= remaining + 0.001:
			var sample := current + dash_direction * sample_distance
			if not _dash_floor_position_valid(sample):
				blocked = true
				segment_finished = true
				break
			var hits := _dash_path_blocking_collisions_at(sample, ignored_bodies)
			if not hits.is_empty():
				var collider: Node = _dash_collision_owner(hits[0].get("collider") as Node)
				var landing := _dash_find_vault_landing(current, dash_direction, collider as PhysicsBody2D)
				if landing.is_finite() and current.distance_to(landing) <= remaining + 0.5:
					segments.append({"start": current, "end": landing, "kind": &"vault", "obstacle": collider})
					vault_targets.append(collider)
					travelled += current.distance_to(landing)
					remaining = maxf(0.0, total_allowed - travelled)
					current = landing
					ignored_bodies.append(collider)
					vault_count += 1
					vault_accepted = true
					segment_finished = true
					break
				blocked = true
				segment_finished = true
				break
			previous = sample
			sample_distance += step_size

		if vault_accepted:
			continue
		if not segment_finished:
			var end_position := current + dash_direction * remaining
			if _dash_floor_position_valid(end_position):
				segments.append({"start": current, "end": end_position, "kind": &"move"})
				travelled += current.distance_to(end_position)
				current = end_position
			else:
				blocked = true
			remaining = 0.0
			break
		if blocked:
			var legal_end := previous
			if legal_end.distance_to(segment_start) > 0.5:
				segments.append({"start": segment_start, "end": legal_end, "kind": &"move"})
				travelled += segment_start.distance_to(legal_end)
				current = legal_end
			remaining = 0.0
			break

	return {
		"valid": travelled > 0.5 and not segments.is_empty(),
		"blocked": blocked,
		"start": start,
		"direction": dash_direction,
		"end": current,
		"distance": travelled,
		"max_distance": max_dist,
		"segments": segments,
		"vault_targets": vault_targets,
	}


func _dash_floor_position_valid(position: Vector2) -> bool:
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world == null or not world.has_method("_cell_for_gameplay_position"):
		return true
	var floors: Variant = world.get("floor_cells")
	if not floors is Dictionary:
		return true
	var cell: Variant = world.call("_cell_for_gameplay_position", position)
	if not floors.has(cell):
		return false
	var pits: Variant = world.get("pit_cells")
	return not (pits is Dictionary and pits.has(cell))


func _dash_shape_collisions_at(position: Vector2, ignored_bodies: Array = []) -> Array:
	if body_collision == null or body_collision.shape == null or not is_inside_tree():
		return []
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision.shape
	var local_offset := body_collision.global_position - global_position
	query.transform = Transform2D(
		body_collision.global_rotation,
		position + local_offset
	)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclusions: Array[RID] = [get_rid()]
	for body_variant in ignored_bodies:
		var body := body_variant as CollisionObject2D
		if body != null and is_instance_valid(body):
			exclusions.append(body.get_rid())
	query.exclude = exclusions
	return get_world_2d().direct_space_state.intersect_shape(query, 16)


func _dash_collision_owner(collider: Node) -> Node:
	var cursor := collider
	while cursor != null:
		if cursor is PhysicsBody2D:
			return cursor
		cursor = cursor.get_parent()
	return collider


func _dash_is_enemy_body(obstacle: Node) -> bool:
	if obstacle == null or not is_instance_valid(obstacle) or not obstacle is PhysicsBody2D:
		return false
	if not obstacle.is_in_group(&"dream_enemies"):
		return false
	if obstacle.get("dead") == true:
		return false
	var runtime_active: Variant = obstacle.get("room_runtime_active")
	return runtime_active == null or runtime_active == true


func _dash_is_smashable_obstacle(obstacle: Node) -> bool:
	if obstacle == null or not is_instance_valid(obstacle):
		return false
	# Intact floor-to-ceiling glass is a real blocker. Breaking it is separate
	# from the furniture vault route; broken glass removes its own collision.
	if obstacle.is_in_group(&"glass_windows"):
		return false
	if obstacle.is_in_group(&"physical_doors"):
		var door: Node = obstacle.get("door_owner")
		if door == null and obstacle.has_meta(&"physical_door_node"):
			var wr: Variant = obstacle.get_meta(&"physical_door_node")
			if wr is WeakRef:
				door = wr.get_ref()
		if door != null and is_instance_valid(door):
			if bool(door.get("is_boss_door")) or bool(door.get("locked")) or bool(door.get("is_destroyed")):
				return false
			return true
		if obstacle.has_meta(&"physical_door") and bool(obstacle.get_meta(&"physical_door")):
			return true
	return false


func _dash_path_blocking_collisions_at(position: Vector2, ignored_bodies: Array) -> Array:
	var blocking: Array = []
	for hit_variant in _dash_shape_collisions_at(position, ignored_bodies):
		var hit: Dictionary = hit_variant
		var owner := _dash_collision_owner(hit.get("collider") as Node)
		if _dash_is_enemy_body(owner):
			# Enemy bodies are dynamic shove targets, not static path blockers.  The
			# committed Dash performs the same swept contact and applies knockback.
			if not ignored_bodies.has(owner):
				ignored_bodies.append(owner)
			continue
		if _dash_is_smashable_obstacle(owner):
			if not ignored_bodies.has(owner):
				ignored_bodies.append(owner)
			var door: Node = owner.get("door_owner") if owner != null else null
			if door != null and door.get("_collision_bodies") is Array:
				for leaf_body in door._collision_bodies:
					if leaf_body != null and not ignored_bodies.has(leaf_body):
						ignored_bodies.append(leaf_body)
			continue
		blocking.append(hit)
	return blocking


func _dash_is_vaultable_obstacle(obstacle: Node) -> bool:
	if obstacle == null or not is_instance_valid(obstacle):
		return false
	if obstacle is PhysicsBody2D and obstacle.has_method("is_window_vault_target"):
		return obstacle.call("is_window_vault_target") == true
	if not obstacle is PhysicsBody2D or not obstacle.is_in_group(&"pushable_prop"):
		return false
	# Some pushable/damageable props predate the explicit vault metadata.  Their
	# `get()` result is null, and `bool(null)` is an invalid GDScript call; only
	# an explicit true value opts a prop into vaulting.
	var vaultable_value: Variant = obstacle.get("vaultable")
	var destroyed_value: Variant = obstacle.get("destroyed")
	if vaultable_value != true or destroyed_value == true:
		return false
	var body := obstacle as PhysicsBody2D
	return body != null and body.visible and body.is_inside_tree()


func _is_dash_landing_valid_from(start: Vector2, landing: Vector2, obstacle: PhysicsBody2D) -> bool:
	if not _dash_floor_position_valid(landing):
		return false
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null:
		if not _is_vault_path_topology_valid(start, landing, world):
			return false
		# Window traversal is checked by the same shape sweep below, excluding
		# only the chosen sill; the projectile route intentionally blocks glass.
		if not obstacle.has_method("is_window_vault_target") and world.has_method("is_room_projectile_path_clear") and not bool(world.call("is_room_projectile_path_clear", start, landing)):
			return false
	var distance := start.distance_to(landing)
	var samples := maxi(2, ceili(distance / 8.0))
	var ignored: Array = [obstacle]
	for sample_index in range(samples + 1):
		var progress := float(sample_index) / float(samples)
		var sample := start.lerp(landing, progress)
		if not _dash_floor_position_valid(sample):
			return false
		if not _dash_path_blocking_collisions_at(sample, ignored).is_empty():
			return false
	return true


func _dash_find_vault_landing(origin: Vector2, direction: Vector2, obstacle: PhysicsBody2D) -> Vector2:
	if not _dash_is_vaultable_obstacle(obstacle):
		return Vector2.INF
	var shape_node := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return Vector2.INF
	var nearest := _vault_nearest_point_on_shape(shape_node, origin)
	var trigger_radius := maxf(float(runtime_config.get("vault_trigger_radius_px")), 1.0)
	var dist_to_nearest := origin.distance_to(nearest)
	if dist_to_nearest > trigger_radius:
		return Vector2.INF
	var player_radius := 10.0
	var player_shape := body_collision.shape as CircleShape2D if body_collision != null else null
	if player_shape != null:
		player_radius = maxf(player_shape.radius, 1.0)
	var toward := origin.direction_to(nearest)
	# Only reject if player is clearly separated from obstacle and heading away
	if dist_to_nearest > (player_radius + 4.0) and toward.length_squared() > 0.0001 and direction.dot(toward) <= 0.0:
		return Vector2.INF
	var support := _vault_support_point(shape_node, direction)
	var candidates: Array[Vector2] = [
		support + direction * (player_radius + 6.0),
		support + direction * (player_radius + 2.0),
		support + direction * (player_radius + 10.0)
	]
	for candidate in candidates:
		if _is_dash_landing_valid_from(origin, candidate, obstacle):
			return candidate
	return Vector2.INF


func resolve_dash_path(direction: Vector2) -> Dictionary:
	var result: Dictionary = {
		"valid": false,
		"blocked": false,
		"start": global_position,
		"direction": Vector2.RIGHT,
		"end": global_position,
		"distance": 0.0,
		"segments": [],
		"vault_targets": []
	}
	if not can_start_dash_aim() and not dash_aim_active:
		return result
	var dash_direction := direction.normalized() if direction.length_squared() > 0.0001 else last_aim_direction.normalized()
	if dash_direction.length_squared() <= 0.0001:
		dash_direction = Vector2.RIGHT
	result["direction"] = dash_direction
	var start := global_position
	var current := start
	var remaining := maxf(dash_distance, 0.0)
	var travelled := 0.0
	var segments: Array = []
	var vault_targets: Array = []
	var ignored_bodies: Array = []
	var blocked := false
	var vault_count := 0
	var step_size := 3.0

	while remaining > 0.5 and vault_count <= 4:
		var segment_start := current
		var previous := current
		var sample_distance := step_size
		var segment_finished := false
		var vault_accepted := false
		while sample_distance <= remaining + 0.001:
			var sample := current + dash_direction * sample_distance
			if not _dash_floor_position_valid(sample):
				blocked = true
				segment_finished = true
				break
			var hits := _dash_path_blocking_collisions_at(sample, ignored_bodies)
			if not hits.is_empty():
				var collider: Node = _dash_collision_owner(hits[0].get("collider") as Node)
				var landing := _dash_find_vault_landing(current, dash_direction, collider as PhysicsBody2D)
				if landing.is_finite() and current.distance_to(landing) <= remaining + 0.5:
					segments.append({"start": current, "end": landing, "kind": &"vault", "obstacle": collider})
					vault_targets.append(collider)
					travelled += current.distance_to(landing)
					remaining = maxf(0.0, dash_distance - travelled)
					current = landing
					ignored_bodies.append(collider)
					vault_count += 1
					vault_accepted = true
					segment_finished = true
					break
				blocked = true
				segment_finished = true
				break
			previous = sample
			sample_distance += step_size

		if vault_accepted:
			continue
		if not segment_finished:
			var end_position := current + dash_direction * remaining
			if _dash_floor_position_valid(end_position):
				segments.append({"start": current, "end": end_position, "kind": &"move"})
				travelled += current.distance_to(end_position)
				current = end_position
			else:
				blocked = true
			remaining = 0.0
			break
		if blocked:
			var legal_end := previous
			if legal_end.distance_to(segment_start) > 0.5:
				segments.append({"start": segment_start, "end": legal_end, "kind": &"move"})
				travelled += segment_start.distance_to(legal_end)
				current = legal_end
			remaining = 0.0
			break

	result["end"] = current
	result["distance"] = travelled
	result["segments"] = segments
	result["vault_targets"] = vault_targets
	result["blocked"] = blocked
	result["valid"] = travelled > 0.5 and not segments.is_empty()
	return result


func _try_start_vault(direction: Vector2) -> bool:
	if (
		dead
		or dashing
		or airborne_knockback
		or knockback_recovery_left > 0.0
		or external_knockback_left > 0.0
		or punch_active
		or kick_active
		or throw_aim_active
		or not attacking_enabled
		or not movement_enabled
	):
		return false
	# Vault is an intentional movement action.  With no current WASD intent,
	# Space keeps its normal Roll meaning instead of guessing a furniture face.
	if direction.length_squared() <= 0.0001:
		return false
	for weapon_variant in [lucille_weapon, books_weapon]:
		var melee_weapon: Node = weapon_variant as Node
		if melee_weapon != null and bool(melee_weapon.get("melee_action_active")):
			return false
	# Space is the existing `dash` action.  The current input vector is the
	# player's explicit vault intent; actual velocity is intentionally ignored
	# so a player pressed against a prop can still vault into it.
	var input_direction: Vector2 = direction.normalized()
	var player_radius: float = 10.0
	var player_shape: CircleShape2D = body_collision.shape as CircleShape2D if body_collision != null else null
	if player_shape != null:
		player_radius = maxf(player_shape.radius, 1.0)
	var trigger_radius: float = maxf(
		float(runtime_config.get("vault_trigger_radius_px")),
		1.0
	)
	var best_obstacle: PhysicsBody2D = null
	var best_landing: Vector2 = Vector2.ZERO
	var best_direction: Vector2 = Vector2.RIGHT
	var best_score: float = INF
	for candidate_variant in _props_for_melee():
		var candidate_node: Node = candidate_variant as Node
		var obstacle: PhysicsBody2D = candidate_node as PhysicsBody2D
		if obstacle == null or not is_instance_valid(obstacle) or obstacle == self:
			continue
		# `vaultable` is explicit furniture gameplay metadata.  Requiring the
		# pushable group prevents an unrelated damageable actor from stealing the
		# Space action, and keeps high props opt-out by default.
		var vaultable_value: Variant = obstacle.get("vaultable")
		var destroyed_value: Variant = obstacle.get("destroyed")
		if (
			not obstacle.is_in_group(&"pushable_prop")
			or vaultable_value != true
			or destroyed_value == true
		):
			continue
		if not obstacle.visible or not obstacle.is_inside_tree():
			continue
		var shape_node: CollisionShape2D = obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		var nearest_point: Vector2 = _vault_nearest_point_on_shape(shape_node, global_position)
		var collider_distance: float = global_position.distance_to(nearest_point)
		if collider_distance > trigger_radius:
			continue
		var toward_furniture: Vector2 = global_position.direction_to(nearest_point)
		if toward_furniture.length_squared() <= 0.0001:
			# An already-overlapping body has no useful nearest-point direction;
			# the explicit input still supplies the intended crossing direction.
			toward_furniture = input_direction
		if input_direction.dot(toward_furniture) <= 0.0:
			continue

		# Put the landing point beyond the far support face of the actual collider,
		# rather than at a fixed centre-distance.  Both small clearance candidates
		# still pass the complete swept collision/topology test.
		var support_point: Vector2 = _vault_support_point(shape_node, input_direction)
		var landing_candidates: Array[Vector2] = [
			support_point + input_direction * (player_radius + 6.0),
			support_point + input_direction * (player_radius + 2.0)
		]
		var landing: Vector2 = Vector2.ZERO
		var landing_valid: bool = false
		for landing_candidate_variant in landing_candidates:
			var landing_candidate: Vector2 = landing_candidate_variant
			if _is_vault_landing_valid(landing_candidate, obstacle):
				landing = landing_candidate
				landing_valid = true
				break
		if not landing_valid:
			continue
		var candidate_score: float = collider_distance
		if candidate_score < best_score:
			best_score = candidate_score
			best_obstacle = obstacle
			best_landing = landing
			best_direction = input_direction
	if best_obstacle == null:
		return false
	_cancel_punch()
	_cancel_melee_visual()
	_set_weapon_activity(false)
	vault_obstacle = best_obstacle
	add_collision_exception_with(vault_obstacle)
	vault_start_position = global_position
	vault_end_position = best_landing
	vault_direction = best_direction
	vault_elapsed = 0.0
	vault_duration = 0.28
	vault_height = 0.0
	vault_visual_rotation = 0.0
	vault_active = true
	return true


func _vault_nearest_point_on_shape(shape_node: CollisionShape2D, world_point: Vector2) -> Vector2:
	var shape: Shape2D = shape_node.shape
	var local_point: Vector2 = shape_node.to_local(world_point)
	if shape is RectangleShape2D:
		var half_size: Vector2 = (shape as RectangleShape2D).size * 0.5
		local_point.x = clampf(local_point.x, -half_size.x, half_size.x)
		local_point.y = clampf(local_point.y, -half_size.y, half_size.y)
	elif shape is CircleShape2D:
		var radius: float = maxf((shape as CircleShape2D).radius, 0.0)
		if local_point.length_squared() > radius * radius and local_point.length_squared() > 0.0001:
			local_point = local_point.normalized() * radius
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		var radius_capsule: float = maxf(capsule.radius, 0.0)
		var half_segment: float = maxf(capsule.height * 0.5 - radius_capsule, 0.0)
		var segment_point := Vector2(0.0, clampf(local_point.y, -half_segment, half_segment))
		var radial := local_point - segment_point
		if radial.length_squared() > radius_capsule * radius_capsule and radial.length_squared() > 0.0001:
			local_point = segment_point + radial.normalized() * radius_capsule
	else:
		return shape_node.global_position
	return shape_node.to_global(local_point)


func _vault_support_point(shape_node: CollisionShape2D, direction: Vector2) -> Vector2:
	var shape: Shape2D = shape_node.shape
	var travel_direction: Vector2 = direction.normalized()
	if travel_direction.length_squared() <= 0.0001:
		return shape_node.global_position
	var local_direction: Vector2 = (
		shape_node.to_local(shape_node.global_position + travel_direction)
		- shape_node.to_local(shape_node.global_position)
	).normalized()
	if local_direction.length_squared() <= 0.0001:
		return shape_node.global_position
	if shape is RectangleShape2D:
		var half_size: Vector2 = (shape as RectangleShape2D).size * 0.5
		var local_origin: Vector2 = shape_node.to_local(global_position)
		var tx := INF
		if local_direction.x > 0.0001:
			tx = (half_size.x - local_origin.x) / local_direction.x
		elif local_direction.x < -0.0001:
			tx = (-half_size.x - local_origin.x) / local_direction.x

		var ty := INF
		if local_direction.y > 0.0001:
			ty = (half_size.y - local_origin.y) / local_direction.y
		elif local_direction.y < -0.0001:
			ty = (-half_size.y - local_origin.y) / local_direction.y

		var t := INF
		if tx > 0.0 and ty > 0.0:
			t = minf(tx, ty)
		elif tx > 0.0:
			t = tx
		elif ty > 0.0:
			t = ty

		var exit_point: Vector2
		if t != INF and t > 0.0:
			exit_point = local_origin + local_direction * t
			exit_point.x = clampf(exit_point.x, -half_size.x, half_size.x)
			exit_point.y = clampf(exit_point.y, -half_size.y, half_size.y)
		else:
			exit_point = Vector2(
				signf(local_direction.x) * half_size.x if absf(local_direction.x) > 0.0001 else clampf(local_origin.x, -half_size.x, half_size.x),
				signf(local_direction.y) * half_size.y if absf(local_direction.y) > 0.0001 else clampf(local_origin.y, -half_size.y, half_size.y)
			)
		return shape_node.to_global(exit_point)
	elif shape is CircleShape2D:
		return shape_node.to_global(local_direction * maxf((shape as CircleShape2D).radius, 0.0))
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		var radius_capsule: float = maxf(capsule.radius, 0.0)
		var half_segment: float = maxf(capsule.height * 0.5 - radius_capsule, 0.0)
		var cap_center := Vector2(0.0, signf(local_direction.y) * half_segment)
		return shape_node.to_global(cap_center + local_direction * radius_capsule)
	return shape_node.global_position


func _is_vault_landing_valid(landing: Vector2, obstacle: PhysicsBody2D) -> bool:
	var world: Node = get_tree().get_first_node_in_group(&"dream_world")
	if world != null:
		var floors: Variant = world.get("floor_cells")
		if floors is Dictionary and world.has_method("_cell_for_gameplay_position"):
			var landing_cell: Variant = world.call("_cell_for_gameplay_position", landing)
			if not floors.has(landing_cell):
				return false
			var pits: Variant = world.get("pit_cells")
			if pits is Dictionary and pits.has(landing_cell):
				return false
			if not _is_vault_path_topology_valid(global_position, landing, world):
				return false
		if world.has_method("is_room_projectile_path_clear") and not bool(world.call("is_room_projectile_path_clear", global_position, landing)):
			return false
	add_collision_exception_with(obstacle)
	var blocked: bool = test_move(global_transform, landing - global_position, null, 0.0, true)
	remove_collision_exception_with(obstacle)
	return not blocked


func _is_vault_path_topology_valid(start: Vector2, landing: Vector2, world: Node) -> bool:
	if not world.has_method("_cell_for_gameplay_position"):
		return true
	var floors: Variant = world.get("floor_cells")
	var pits: Variant = world.get("pit_cells")
	if not (floors is Dictionary):
		return true
	var distance: float = start.distance_to(landing)
	var sample_count: int = maxi(2, ceili(distance / 12.0))
	for sample_index in range(sample_count + 1):
		var progress: float = float(sample_index) / float(sample_count)
		var sample_position: Vector2 = start.lerp(landing, progress)
		var sample_cell: Variant = world.call("_cell_for_gameplay_position", sample_position)
		if not floors.has(sample_cell):
			return false
		if pits is Dictionary and pits.has(sample_cell):
			return false
	return true


func _update_vault(delta: float) -> void:
	vault_elapsed += delta
	var progress: float = clampf(vault_elapsed / maxf(vault_duration, 0.01), 0.0, 1.0)
	var target: Vector2 = vault_start_position.lerp(vault_end_position, progress)
	var motion: Vector2 = target - global_position
	if motion.length_squared() > 0.0001:
		var collision: KinematicCollision2D = move_and_collide(motion)
		if collision != null:
			_finish_vault()
			return
	velocity = Vector2.ZERO
	knockback_height = sin(progress * PI) * 16.0
	vault_height = knockback_height
	vault_visual_rotation = deg_to_rad(45.0) * sin(progress * PI)
	_update_direction_animation(vault_direction, delta)
	_apply_vault_visual_state()
	visual.rotation = vault_visual_rotation
	heal_overlay.rotation = vault_visual_rotation
	if progress >= 1.0:
		_finish_vault()


func _apply_vault_visual_state() -> void:
	if visual == null:
		return
	# Vault owns only this visual/fake-height layer.  The Player root and all
	# gameplay collision remain on the authored 2D path.
	visual.position = (
		visual_home_position
		+ Vector2(0.0, -knockback_height)
		+ lucille_character_offset
		+ kick_character_offset
		+ dash_roll_visual_offset
	)
	heal_overlay.position = visual.position
	weapon_root.position = (
		runtime_config.player_weapon_root_offset
		+ lucille_character_offset
		+ kick_character_offset
		+ Vector2(0.0, -knockback_height)
	)


func _finish_vault() -> void:
	if vault_obstacle != null and is_instance_valid(vault_obstacle):
		remove_collision_exception_with(vault_obstacle)
	vault_obstacle = null
	vault_active = false
	vault_elapsed = 0.0
	vault_height = 0.0
	knockback_height = 0.0
	vault_visual_rotation = 0.0
	visual.rotation = 0.0
	heal_overlay.rotation = 0.0
	_apply_vault_visual_state()
	velocity = Vector2.ZERO
	if is_inside_tree():
		_set_weapon_activity(not dead)


func _cancel_vault() -> void:
	if not vault_active and vault_obstacle == null:
		return
	_finish_vault()


func _start_dash(direction: Vector2) -> void:
	var dir := direction.normalized()
	if dir.length_squared() <= 0.0001:
		var aim_dir := get_aim_direction().normalized()
		var move_dir := last_move_direction.normalized()
		var chosen_dir := Vector2.ZERO
		if aim_dir.length_squared() > 0.0001:
			var test_path := resolve_dash_path(aim_dir)
			for seg in test_path.get("segments", []):
				if seg.get("kind") == &"vault":
					chosen_dir = aim_dir
					break
		if chosen_dir.is_zero_approx() and move_dir.length_squared() > 0.0001:
			var test_path2 := resolve_dash_path(move_dir)
			for seg in test_path2.get("segments", []):
				if seg.get("kind") == &"vault":
					chosen_dir = move_dir
					break
		if chosen_dir.is_zero_approx():
			if move_dir.length_squared() > 0.0001:
				chosen_dir = move_dir
			elif aim_dir.length_squared() > 0.0001:
				chosen_dir = aim_dir
			else:
				chosen_dir = Vector2.RIGHT
		dir = chosen_dir
	var resolved := resolve_dash_path(dir)
	if bool(resolved.get("valid", false)):
		_commit_dash_path(resolved)


func _commit_dash_path(result: Dictionary) -> bool:
	if (
		result.is_empty()
		or not bool(result.get("valid", false))
		or (not is_tactical_dash_executing and not can_start_dash_aim())
	):
		return false
	var segments_variant: Variant = result.get("segments", [])
	if not segments_variant is Array or segments_variant.is_empty():
		return false
	var normalized_segments: Array = []
	for segment_variant in segments_variant:
		if not segment_variant is Dictionary:
			continue
		var segment: Dictionary = segment_variant
		var segment_start: Variant = segment.get("start", global_position)
		var segment_end: Variant = segment.get("end", segment_start)
		if not segment_start is Vector2 or not segment_end is Vector2:
			continue
		if segment_start.distance_to(segment_end) <= 0.5:
			continue
		normalized_segments.append(segment)
	if normalized_segments.is_empty():
		return false
	_start_dash_from_segments(normalized_segments, result)
	return true


func _start_dash_from_segments(segments: Array, result: Dictionary) -> void:
	_cancel_punch()
	_clear_dash_enemy_contacts()
	_time_locomotion_velocity = Vector2.ZERO
	_time_locomotion_speed = 0.0
	var normalized_direction: Vector2 = result.get("direction", last_aim_direction)
	if normalized_direction.length_squared() <= 0.0001:
		normalized_direction = Vector2.RIGHT
	else:
		normalized_direction = normalized_direction.normalized()

	dash_path_segments = segments.duplicate(true)
	dash_segment_index = 0
	dash_segment_elapsed = 0.0
	dash_vault_segment_obstacle = null
	dash_start = dash_path_segments[0].get("start", global_position)
	dash_end = result.get("end", dash_path_segments[dash_path_segments.size() - 1].get("end", dash_start))
	dash_path_total_distance = 0.0
	for segment_variant in dash_path_segments:
		var segment: Dictionary = segment_variant
		dash_path_total_distance += segment.get("start", dash_start).distance_to(segment.get("end", dash_start))

	var actual_distance := dash_path_total_distance

	if actual_distance < 0.01:
		return

	active_dash_duration = maxf(
		0.02,
		dive_duration
		* actual_distance
		/ maxf(
			dash_distance,
			0.001
		)
	)

	dash_elapsed = 0.0
	if not is_tactical_dash_executing:
		dash_charges -= 1

		if dash_cooldown_left <= 0.0:
			dash_cooldown_left = dash_cooldown

	dashing = true
	is_diving = true
	_begin_dive_bullet_time()

	dash_invulnerability_left = maxf(
		active_dash_duration,
		dash_invulnerability_seconds
	)

	## ------------------------------------------------------------
	## 飞扑视觉初始化
	## ------------------------------------------------------------

	dash_roll_direction = normalized_direction
	dash_roll_visual_offset = Vector2.ZERO

	## 每次飞扑都从正方向开始，避免上一次中断留下旋转。
	visual.rotation = 0.0
	heal_overlay.rotation = 0.0

	## 飞扑滞空期间保持手持武器可见并可瞄准射击。
	if held_weapon_sprite != null:
		held_weapon_sprite.visible = (
			not dead
			and not selected_weapon_id.is_empty()
			and external_knockback_left <= 0.0
		)

	## Roll uses its own short-lived directional visual samples.  The old
	## Thunder/DashEffect remains available for legacy callers but is no longer
	## part of the Player Roll path.
	roll_trail_distance_since_sample = 0.0
	RollSpeedTrail.reset_counter()
	_spawn_roll_speed_trail(
		dash_start - normalized_direction * 4.0
	)

	_request_combat_camera_impulse(&"small", normalized_direction)
	SFX.play_event(&"dash")

	_reset_stillness()


func _start_dash_legacy(direction: Vector2) -> void:
	# Kept for compatibility with older scene callers; all current Space input
	# enters through resolve_dash_path() and _commit_dash_path().
	_start_dash(direction)


func _spawn_roll_speed_trail(sample_position: Vector2) -> void:
	if vault_active or visual == null or not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	var effect := ROLL_SPEED_TRAIL_SCRIPT.new() as Node2D
	if effect == null:
		return
	parent.add_child(effect)
	# Register the presentation policy before the depth bridge is created.  This
	# prevents the local white ghost from being classified as a lit actor during
	# the bridge's initial capture.
	effect.set_meta(&"depth_visual_unshaded", true)
	effect.call(
		"setup",
		visual,
		sample_position,
		dash_roll_direction,
		float(runtime_config.get("roll_trail_stretch")),
		float(runtime_config.get("roll_trail_start_alpha")),
		float(runtime_config.get("roll_trail_lifetime"))
	)
	# In 3D Dream the gameplay effect remains a Node2D while the scene root is
	# the sole authority that mirrors Node2D visuals into the depth layer.  A
	# path of `.` captures only this lightweight visual root, not DreamPlayer.
	var bridge_owner: Node = parent
	while bridge_owner != null:
		if bridge_owner.has_method("register_depth_visual"):
			bridge_owner.call("register_depth_visual", effect, [NodePath(".")])
			break
		bridge_owner = bridge_owner.get_parent()


func _record_roll_trail_motion(from_position: Vector2, to_position: Vector2) -> void:
	if vault_active:
		return
	var travel: Vector2 = to_position - from_position
	var remaining_distance: float = travel.length()
	if remaining_distance <= 0.0001:
		return
	var travel_direction: Vector2 = travel / remaining_distance
	var sample_distance: float = maxf(
		float(runtime_config.get("roll_trail_sample_distance")),
		1.0
	)
	var cursor: Vector2 = from_position
	var distance_to_next_sample: float = maxf(
		sample_distance - roll_trail_distance_since_sample,
		0.001
	)
	while remaining_distance >= distance_to_next_sample:
		cursor += travel_direction * distance_to_next_sample
		_spawn_roll_speed_trail(cursor - dash_roll_direction * 4.0)
		remaining_distance -= distance_to_next_sample
		distance_to_next_sample = sample_distance
	roll_trail_distance_since_sample = remaining_distance

func _update_dash_roll_visual(progress: float, entry_angle: float = 0.0) -> void:
	if visual == null:
		return

	var safe_progress: float = clampf(
		progress,
		0.0,
		1.0
	)

	# ------------------------------------------------------------
	# 翻滚旋转方向
	# ------------------------------------------------------------
	var roll_sign: float = 1.0

	if absf(dash_roll_direction.x) >= absf(dash_roll_direction.y):
		roll_sign = (
			1.0
			if dash_roll_direction.x >= 0.0
			else -1.0
		)
	else:
		roll_sign = (
			1.0
			if dash_roll_direction.y >= 0.0
			else -1.0
		)

	var roll_angle: float
	if not is_zero_approx(entry_angle):
		roll_angle = lerpf(entry_angle, TAU * roll_sign, safe_progress)
	else:
		roll_angle = (
			TAU
			* safe_progress
			* roll_sign
		)

	# Keep the canonical visual scale throughout the roll.  The apparent lift is
	# expressed by rotation and the existing visual offset, never by scaling the
	# CharacterVisual (which would make the player appear to grow/shrink).
	var horizontal_sign := -1.0 if visual.scale.x < 0.0 else 1.0
	visual.scale = Vector2(horizontal_sign * character_visual_scale, character_visual_scale)
	heal_overlay.scale = visual.scale

	# ------------------------------------------------------------
	# 旋转中心从脚底补偿到身体中央
	# ------------------------------------------------------------
	var roll_pivot_local: Vector2 = Vector2(
		0.0,
		-16.0
	)

	var base_scaled_pivot: Vector2 = Vector2(
		roll_pivot_local.x * visual.scale.x,
		roll_pivot_local.y * character_visual_scale
	)

	var current_scaled_pivot: Vector2 = Vector2(
		roll_pivot_local.x * visual.scale.x,
		roll_pivot_local.y * character_visual_scale
	)

	var pivot_compensation: Vector2 = (
		base_scaled_pivot
		- current_scaled_pivot.rotated(
			roll_angle
		)
	)

	# ------------------------------------------------------------
	# 翻滚时轻微离地
	# ------------------------------------------------------------
	var hop_height: float = 4.0

	var hop_offset: Vector2 = Vector2(
		0.0,
		-sin(
			safe_progress * PI
		) * hop_height
	)

	var previous_roll_offset: Vector2 = (
		dash_roll_visual_offset
	)

	dash_roll_visual_offset = (
		pivot_compensation
		+ hop_offset
	)

	# _update_visual_feedback()本帧之前已经执行，
	# 所以立即补上这一帧的位移差值。
	var offset_delta: Vector2 = (
		dash_roll_visual_offset
		- previous_roll_offset
	)

	visual.position += offset_delta
	heal_overlay.position = visual.position

	# 最后应用旋转。
	visual.rotation = roll_angle
	heal_overlay.rotation = roll_angle

func _finish_dash_roll_visual() -> void:
	dash_roll_visual_offset = Vector2.ZERO
	roll_trail_distance_since_sample = 0.0

	if visual != null:
		visual.rotation = 0.0

		## 保留当前左右镜像，只恢复Y轴大小。
		var horizontal_sign := (
			-1.0
			if visual.scale.x < 0.0
			else 1.0
		)

		visual.scale = Vector2(
			horizontal_sign * character_visual_scale,
			character_visual_scale
		)

	if heal_overlay != null:
		heal_overlay.rotation = 0.0
		heal_overlay.scale = visual.scale
		heal_overlay.position = visual.position

	## Dash结束后恢复手持武器。
	if held_weapon_sprite != null:
		held_weapon_sprite.visible = (
			not dead
			and not selected_weapon_id.is_empty()
			and external_knockback_left <= 0.0
		)
	_update_hands_visibility()

func _update_dash_legacy(delta: float) -> void:
	dash_elapsed += delta

	var progress: float = clampf(
		dash_elapsed / maxf(active_dash_duration, 0.001),
		0.0,
		1.0
	)

	var target_position: Vector2 = dash_start.lerp(
		dash_end,
		progress
	)

	var dash_motion: Vector2 = (
		target_position
		- global_position
	)
	var position_before_dash_step: Vector2 = global_position

	if dash_motion.length_squared() > 0.0001:
		var collision: KinematicCollision2D = move_and_collide(
			dash_motion
		)

		if collision != null:
			_record_roll_trail_motion(position_before_dash_step, global_position)
			dashing = false
			dash_invulnerability_left = 0.0
			velocity = Vector2.ZERO
			dash_end = global_position

			_finish_dash_roll_visual()
			return

	velocity = Vector2.ZERO

	# Dash位移过程中同步播放360°翻滚视觉。
	_update_dash_roll_visual(progress)
	_record_roll_trail_motion(position_before_dash_step, global_position)

	if progress >= 1.0:
		dashing = false
		velocity = Vector2.ZERO

		_finish_dash_roll_visual()


func _begin_dash_segment(segment: Dictionary) -> void:
	dash_segment_elapsed = 0.0
	var segment_start: Vector2 = segment.get("start", global_position)
	var segment_end: Vector2 = segment.get("end", segment_start)
	var segment_distance := segment_start.distance_to(segment_end)
	dash_segment_duration = maxf(
		0.01,
		active_dash_duration * segment_distance / maxf(dash_path_total_distance, 0.001)
	)
	dash_vault_segment_obstacle = null
	if StringName(segment.get("kind", &"move")) == &"vault":
		var obstacle := segment.get("obstacle") as PhysicsBody2D
		if obstacle != null and is_instance_valid(obstacle):
			dash_vault_segment_obstacle = obstacle
			add_collision_exception_with(obstacle)
			dash_vault_exceptions.append(obstacle)


func _clear_dash_enemy_contacts() -> void:
	for enemy in dash_enemy_collision_exceptions:
		if enemy == null or not is_instance_valid(enemy):
			continue
		remove_collision_exception_with(enemy)
		enemy.remove_collision_exception_with(self)
	dash_enemy_collision_exceptions.clear()
	dash_knocked_enemy_ids.clear()


func _apply_dash_enemy_knockback(from_position: Vector2, to_position: Vector2) -> void:
	if not is_inside_tree():
		return
	var world := get_tree().get_first_node_in_group(&"dream_world")
	var motion := to_position - from_position
	var distance := motion.length()
	if distance <= 0.001:
		return
	var sample_count := maxi(1, ceili(distance / 4.0))
	for sample_index in range(sample_count + 1):
		var sample := from_position.lerp(to_position, float(sample_index) / float(sample_count))
		for hit_variant in _dash_shape_collisions_at(sample):
			var hit: Dictionary = hit_variant
			var collider_node := hit.get("collider") as Node
			if collider_node != null and is_instance_valid(collider_node):
				if collider_node.is_in_group(&"glass_windows"):
					if collider_node.has_method("take_damage"):
						collider_node.call("take_damage", 10.0, dash_roll_direction, 1.0)
				elif collider_node.is_in_group(&"physical_doors"):
					if collider_node is PhysicsBody2D and not dash_vault_exceptions.has(collider_node):
						if world != null and world.has_method("resolve_door_impact_from_collision"):
							world.call("resolve_door_impact_from_collision", collider_node, sample, dash_roll_direction, 260.0, &"dash", get_instance_id())
						add_collision_exception_with(collider_node)
						dash_vault_exceptions.append(collider_node)
			var enemy := _dash_collision_owner(collider_node) as PhysicsBody2D
			if not _dash_is_enemy_body(enemy):
				continue
			var enemy_id := enemy.get_instance_id()
			if dash_knocked_enemy_ids.has(enemy_id):
				continue
			dash_knocked_enemy_ids[enemy_id] = true
			# The temporary two-way exception exists only for this Dash.  It lets
			# the already-resolved path continue while the Enemy's authoritative
			# knockback state moves it out of the lane; walls/doors/furniture remain
			# normal blockers.
			add_collision_exception_with(enemy)
			enemy.add_collision_exception_with(self)
			dash_enemy_collision_exceptions.append(enemy)
			if enemy.has_method("apply_knockback"):
				var strength_variant: Variant = runtime_config.get(&"furniture_impact_enemy_knockback")
				var strength := 180.0 if strength_variant == null else maxf(float(strength_variant), 0.0)
				var direction := dash_roll_direction.normalized()
				if direction.length_squared() <= 0.001:
					direction = from_position.direction_to(enemy.global_position)
				if direction.length_squared() <= 0.001:
					direction = Vector2.RIGHT
				enemy.call("apply_knockback", direction, strength)


func _finish_dash_path() -> void:
	_end_dive_bullet_time()
	is_diving = false
	knockback_height = 0.0
	vault_height = 0.0
	_clear_dash_enemy_contacts()
	for obstacle in dash_vault_exceptions:
		if obstacle != null and is_instance_valid(obstacle):
			remove_collision_exception_with(obstacle)
	dash_vault_exceptions.clear()
	dash_vault_segment_obstacle = null
	dash_path_segments.clear()
	dash_segment_index = 0
	dash_segment_elapsed = 0.0
	dash_segment_duration = 0.0
	dash_path_total_distance = 0.0
	dashing = false
	dash_invulnerability_left = 0.0
	velocity = Vector2.ZERO
	_finish_dash_roll_visual()

	if is_tactical_dash_executing:
		is_tactical_dash_executing = false
		var target := tactical_attack_target
		tactical_attack_target = Vector2.ZERO
		_execute_tactical_attack(target)


func _update_dash(delta: float) -> void:
	if dash_path_segments.is_empty() or dash_segment_index >= dash_path_segments.size():
		_finish_dash_path()
		return
	dash_elapsed += delta
	var segment: Dictionary = dash_path_segments[dash_segment_index]
	if dash_segment_duration <= 0.0:
		_begin_dash_segment(segment)
	dash_segment_elapsed += delta
	var progress := clampf(dash_segment_elapsed / maxf(dash_segment_duration, 0.001), 0.0, 1.0)
	var segment_start: Vector2 = segment.get("start", global_position)
	var segment_end: Vector2 = segment.get("end", segment_start)
	var is_vault_segment := StringName(segment.get("kind", &"move")) == &"vault"
	var target_position := segment_start.lerp(segment_end, progress)
	var position_before := global_position
	var motion := target_position - global_position
	if motion.length_squared() > 0.0001:
		_apply_dash_enemy_knockback(global_position, target_position)
		var collision := move_and_collide(motion)
		if collision != null:
			# The resolver and preview remain the authority for the intended end,
			# but a late physics change can still stop this frame. Publish the
			# actual contact point rather than leaving a stale endpoint behind.
			dash_end = global_position
			_finish_dash_path()
			return
	velocity = Vector2.ZERO
	if is_vault_segment:
		if is_instance_valid(dash_vault_segment_obstacle) and dash_vault_segment_obstacle.has_method("commit_vault_contact"):
			dash_vault_segment_obstacle.call("commit_vault_contact", position_before, global_position)
		var vault_arc := sin(progress * PI)
		knockback_height = vault_arc * 16.0
		vault_height = knockback_height
		vault_visual_rotation = deg_to_rad(45.0) * vault_arc
		_apply_vault_visual_state()
		visual.rotation = vault_visual_rotation
		heal_overlay.rotation = vault_visual_rotation
	else:
		var overall_progress := clampf(dash_elapsed / maxf(active_dash_duration, 0.001), 0.0, 1.0)
		var dive_sign: float = 1.0
		if absf(dash_roll_direction.x) >= absf(dash_roll_direction.y):
			dive_sign = 1.0 if dash_roll_direction.x >= 0.0 else -1.0
		else:
			dive_sign = 1.0 if dash_roll_direction.y >= 0.0 else -1.0
		var target_dive_angle := deg_to_rad(dive_takeoff_angle_degrees) * dive_sign

		if overall_progress < dive_airborne_ratio:
			# ------------------------------------------------------------
			# 阶段 1：飞扑滞空（空中抛物线、45度起跳姿势、开火允许、0.2x子弹时间）
			# ------------------------------------------------------------
			if not dive_bullet_time_active:
				_begin_dive_bullet_time()
			var dive_prog := clampf(overall_progress / maxf(dive_airborne_ratio, 0.001), 0.0, 1.0)
			knockback_height = sin(dive_prog * PI) * dive_peak_height
			vault_height = knockback_height
			var current_dive_angle := lerpf(0.0, target_dive_angle, minf(dive_prog * 4.0, 1.0))
			visual.rotation = current_dive_angle
			heal_overlay.rotation = current_dive_angle
			_apply_vault_visual_state()
			if held_weapon_sprite != null:
				held_weapon_sprite.visible = (
					not dead
					and not selected_weapon_id.is_empty()
					and external_knockback_left <= 0.0
				)
		else:
			# ------------------------------------------------------------
			# 阶段 2：落地接翻滚（触地恢复1.0x时间、收起武器、完成地面翻滚收招）
			# ------------------------------------------------------------
			if dive_bullet_time_active:
				_end_dive_bullet_time()
			knockback_height = 0.0
			vault_height = 0.0
			if held_weapon_sprite != null:
				held_weapon_sprite.visible = false
			var roll_prog := clampf((overall_progress - dive_airborne_ratio) / maxf(1.0 - dive_airborne_ratio, 0.001), 0.0, 1.0)
			_update_dash_roll_visual(roll_prog, target_dive_angle)
	_record_roll_trail_motion(position_before, global_position)

	dash_segment_elapsed = minf(dash_segment_elapsed, dash_segment_duration)
	if progress >= 1.0:
		if dash_vault_segment_obstacle != null and is_instance_valid(dash_vault_segment_obstacle):
			remove_collision_exception_with(dash_vault_segment_obstacle)
			dash_vault_exceptions.erase(dash_vault_segment_obstacle)
		dash_vault_segment_obstacle = null
		knockback_height = 0.0
		vault_height = 0.0
		vault_visual_rotation = 0.0
		dash_segment_index += 1
		dash_segment_elapsed = 0.0
		dash_segment_duration = 0.0
		if dash_segment_index >= dash_path_segments.size():
			_finish_dash_path()


func cancel_dash() -> void:
	_end_dive_bullet_time()
	is_diving = false
	knockback_height = 0.0
	vault_height = 0.0
	_cancel_tactical_plan()
	_cancel_dash_aim()
	is_tactical_dash_executing = false
	tactical_attack_target = Vector2.ZERO
	_finish_dash_path()
	dashing = false
	dash_invulnerability_left = 0.0
	dash_elapsed = active_dash_duration
	dash_start = global_position
	dash_end = global_position
	dash_roll_direction = last_move_direction
	dash_roll_visual_offset = Vector2.ZERO
	velocity = Vector2.ZERO
	_time_locomotion_velocity = Vector2.ZERO
	_time_locomotion_speed = 0.0

	_finish_dash_roll_visual()
	_emit_dash_state()

func set_dash_enabled(enabled: bool) -> void:
	dash_enabled = (
		enabled
		and not dead
		and not dash_disabled_by_hunger
	)

	if not dash_enabled:
		cancel_dash()


func add_dash_charge_capacity(config: DemoConfig) -> void:
	if max_dash_charges >= config.dash_max_charges:
		return

	max_dash_charges += 1

	dash_charges = mini(
		max_dash_charges,
		dash_charges + 1
	)

	_emit_dash_state()


func _emit_dash_state() -> void:
	dash_state_changed.emit(
		dash_cooldown_left,
		dash_cooldown,
		dashing,
		dash_charges,
		max_dash_charges
	)


## 击飞恢复周期保护：从第一次合法 Knock 进入 Airborne 开始，到完全站起
## 并走完既有 post-getup 保护为止。该谓词同时约束 Damage 与 Knock/Launch
## 重入，避免"无敌了但仍能被再次 launch"的半修复状态。
func _is_knock_recovery_protected() -> bool:
	return (
		dead
		or airborne_knockback
		or knockback_recovery_left > 0.0
		or (invulnerability_left > 0.0 and invulnerability_reason == &"knockdown_recovery")
	)


func receive_damage(
	amount: float,
	damage_source: StringName = &"enemy_contact",
	source_position: Vector2 = Vector2.INF,
	source_direction: Vector2 = Vector2.ZERO
) -> void:
	if (
		dead
		or dashing
		or _is_knock_recovery_protected()
		or dash_invulnerability_left > 0.0
		or invulnerability_left > 0.0
	):
		return
	_cancel_vault()
	var incoming_direction := source_direction.normalized()
	if incoming_direction.length_squared() <= 0.001 and source_position.is_finite():
		incoming_direction = global_position.direction_to(source_position)
	if (
		block_active
		and incoming_direction.length_squared() > 0.001
		and get_aim_direction().normalized().dot(incoming_direction) >= 0.0
	):
		# Block only covers the player's facing half-plane.  A missing source
		# vector never grants broad immunity, and attacks from behind still land.
		return

	last_damage_source = damage_source

	if has_shield:
		has_shield = false
		shield_visual.set_shield_active(false)
		shield_break_left = 0.45

		_play_feedback()

		skill_state_changed.emit(
			has_shield,
			dissociation_ready
		)

		queue_redraw()
		return

	var health_before := current_health
	var next_health := maxf(
		0.0,
		current_health - amount
	)

	if next_health <= 0.0 and dissociation_ready:
		dissociation_ready = false

		current_health = minf(
			maximum_health,
			dissociation_revive_health
		)

		var actual_damage := maxf(
			0.0,
			health_before - current_health
		)

		invulnerability_left = maxf(
			invulnerability_left,
			dissociation_invulnerability_seconds
		)

		invulnerability_reason = &"dissociation"
		revive_flash_left = 0.9

		_apply_heal_feedback()
		_play_feedback()

		health_changed.emit(
			current_health,
			maximum_health
		)

		effective_damage_taken.emit(
			actual_damage
		)

		if actual_damage > 0.0:
			var hurt_dir: Vector2 = Vector2.ZERO
			if source_direction.length_squared() > 0.001:
				hurt_dir = source_direction.normalized()
			elif source_position.is_finite() and global_position.distance_squared_to(source_position) > 0.001:
				hurt_dir = (global_position - source_position).normalized()
			else:
				hurt_dir = -get_aim_direction().normalized()
			if hurt_dir.length_squared() <= 0.001:
				hurt_dir = Vector2.DOWN
			_request_combat_camera_impulse(&"heavy", hurt_dir)

		player_hp_bar.show_after_damage(
			current_health,
			maximum_health,
			CONFIG.player_hp_bar_visible_duration
		)

		skill_state_changed.emit(
			has_shield,
			dissociation_ready
		)

		revived.emit()

		SFX.play_event(
			&"player_hurt"
		)

		queue_redraw()
		return

	current_health = next_health

	var actual_damage := maxf(
		0.0,
		health_before - current_health
	)

	invulnerability_left = hurt_invulnerability_seconds
	invulnerability_reason = &"hurt"
	hurt_flash_left = hurt_flash_seconds

	health_changed.emit(
		current_health,
		maximum_health
	)

	effective_damage_taken.emit(
		actual_damage
	)

	if actual_damage > 0.0:
		var hurt_dir: Vector2 = Vector2.ZERO
		if source_direction.length_squared() > 0.001:
			hurt_dir = source_direction.normalized()
		elif source_position.is_finite() and global_position.distance_squared_to(source_position) > 0.001:
			hurt_dir = (global_position - source_position).normalized()
		else:
			hurt_dir = -get_aim_direction().normalized()
		if hurt_dir.length_squared() <= 0.001:
			hurt_dir = Vector2.DOWN

		var hurt_level: StringName = &"medium"
		var health_ratio := current_health / maxf(maximum_health, 1.0)
		if actual_damage >= 25.0 or health_ratio <= 0.35 or current_health <= 0.0:
			hurt_level = &"heavy"

		_request_combat_camera_impulse(hurt_level, hurt_dir)

	player_hp_bar.show_after_damage(
		current_health,
		maximum_health,
		CONFIG.player_hp_bar_visible_duration
	)

	queue_redraw()

	if current_health <= 0.0:
		dead = true
		knockback_recovery_left = 0.0

		cancel_dash()
		_cancel_all_reloads()

		invulnerability_left = 0.0
		_set_weapon_activity(false)

		SFX.play_event(&"death")
		died.emit()

	else:
		SFX.play_event(
			&"player_hurt"
		)


func revive_for_floor_restart(
	fallback_weapon_id: String,
	config: DemoConfig = runtime_config,
	permanent_upgrades: Dictionary = runtime_permanent_upgrades
) -> void:
	dead = false
	movement_enabled = true
	attacking_enabled = true
	cancel_dash()
	_cancel_all_reloads()
	_cancel_punch()
	_cancel_melee_visual()
	_cancel_throw_aim()
	velocity = Vector2.ZERO
	movement_impulse_velocity = Vector2.ZERO
	movement_impulse_left = 0.0
	external_knockback_left = 0.0
	knockback_recovery_left = 0.0
	airborne_knockback = false
	invulnerability_left = 0.0
	dash_invulnerability_left = 0.0
	hurt_flash_left = 0.0
	dash_cooldown_left = 0.0
	dash_charges = max_dash_charges
	dashing = false
	set_dash_enabled(not dash_disabled_by_hunger)
	if ranged_weapon_id.is_empty() and melee_weapon_id.is_empty() and not fallback_weapon_id.is_empty():
		configure_weapon(fallback_weapon_id, config, permanent_upgrades)
	else:
		ammo_states.clear()
		if not ranged_weapon_id.is_empty():
			_ensure_ammo_state(ranged_weapon_id)
		if selected_weapon_id.is_empty():
			if not ranged_weapon_id.is_empty():
				selected_weapon_id = ranged_weapon_id
				active_weapon_category = DreamGunAtlas.CATEGORY_RANGED
			elif not melee_weapon_id.is_empty():
				selected_weapon_id = melee_weapon_id
				active_weapon_category = DreamGunAtlas.CATEGORY_MELEE
	_apply_profile_stats(false)
	current_health = maximum_health
	_set_weapon_activity(not selected_weapon_id.is_empty())
	_refresh_held_weapon_visual()
	_update_hands_visibility()
	health_changed.emit(current_health, maximum_health)
	dash_state_changed.emit(dash_cooldown_left, dash_cooldown, dashing, dash_charges, max_dash_charges)
	_emit_ammo_state()
	if is_instance_valid(player_hp_bar) and runtime_config != null:
		player_hp_bar.configure(runtime_config, current_health, maximum_health)
	queue_redraw()



func apply_external_knockback(
	_direction: Vector2,
	_strength: float
) -> void:
	# OTXO Parity: Player has rock-solid footing and is completely immune to
	# knockback, knockdown, airborne ragdoll, and forced weapon drops.
	return


func apply_movement_impulse(direction: Vector2, strength: float, duration: float = 0.10) -> void:
	if dead or direction.length_squared() <= 0.001 or strength <= 0.0:
		return
	# Lightweight recoil layer: it composes with locomotion and never enters the
	# airborne/knockdown state or extracts the held weapon.
	movement_impulse_velocity += direction.normalized() * strength
	movement_impulse_left = maxf(movement_impulse_left, duration)


func start_airborne_knockback(
	direction: Vector2,
	strength: float,
	vertical_velocity: float = -1.0,
	preserve_weapon: bool = false,
	bypass_recovery: bool = false
) -> void:
	# Only pit recovery is allowed to move the player vertically out of pits.
	if not pit_recovery_pending:
		return
	_cancel_vault()
	var knock_direction := direction.normalized()
	# The first accepted launch is the ownership boundary for the held weapon.
	# Extract before changing the physical state so a same-tick manual Throw and
	# knockdown can never create two copies: the second extraction sees an empty
	# selected slot and is a no-op.  The world decides how to instantiate the
	# returned payload (forced drop uses a small local impulse, not Throw speed).
	if not preserve_weapon:
		var forced_drop := take_active_weapon_for_throw()
		if not forced_drop.is_empty():
			var drop_impulse := knock_direction * clampf(
				float(runtime_config.world_weapon_swap_drop_impulse) * 0.65,
				12.0,
				80.0
			)
			forced_drop["forced_drop"] = true
			forced_drop["drop_impulse"] = drop_impulse
			weapon_drop_requested.emit(forced_drop)
	var impact_world := get_tree().get_first_node_in_group(&"dream_world")
	if impact_world != null and impact_world.has_method("request_combat_impact"):
		impact_world.call("request_combat_impact", strength, direction, &"player_knockback")

	_cancel_punch()
	_time_locomotion_velocity = Vector2.ZERO
	_time_locomotion_speed = 0.0
	cancel_dash()

	kick_active = false
	kick_character_offset = Vector2.ZERO
	kick_body_lean_rotation = 0.0

	## Airborne优先于Lucille。
	_cancel_melee_visual()

	airborne_knockback = true
	airborne_grounded_sliding = false
	knockback_recovery_left = 0.0

	external_knockback_velocity = (
		knock_direction
		* minf(
			strength,
			runtime_config.maximum_knockback_speed
		)
	)
	# Publish the accepted impulse immediately as the CharacterBody velocity as
	# well as the dedicated airborne accumulator.  This keeps direct callers and
	# diagnostics consistent even before the next physics tick copies the
	# accumulator into velocity.
	velocity = external_knockback_velocity

	var fall_sign := (
		signf(direction.x)
		if absf(direction.x) >= absf(direction.y)
		else signf(direction.y)
	)

	airborne_visual_rotation_target = (
		deg_to_rad(72.0)
		* (
			fall_sign
			if not is_zero_approx(fall_sign)
			else 1.0
		)
	)

	knockback_height = 0.0

	knockback_vertical_velocity = (
		vertical_velocity
		if vertical_velocity > 0.0
		else runtime_config.character_knockback_vertical_velocity
	)

	external_knockback_left = (
		knockback_vertical_velocity
		* 2.0
		/ maxf(
			runtime_config.character_knockback_fake_gravity,
			1.0
		)
	)

	secondary_collision_cooldown_left = maxf(
		secondary_collision_cooldown_left,
		runtime_config.secondary_collision_cooldown
	)

	_set_weapon_activity(false)


func _finish_airborne_knockback() -> void:
	airborne_knockback = false
	airborne_grounded_sliding = false
	knockback_recovery_left = maxf(runtime_config.player_knockback_recovery_seconds, 0.0)
	external_knockback_velocity = Vector2.ZERO
	external_knockback_left = 0.0
	knockback_height = 0.0
	knockback_vertical_velocity = 0.0
	velocity = Vector2.ZERO
	_time_locomotion_velocity = Vector2.ZERO
	_time_locomotion_speed = 0.0
	if pit_recovery_pending:
		# A pit recovery is a single landing resolution, not a per-frame clamp.
		# The flight still uses the normal airborne/fake-height pipeline above.
		global_position = pit_recovery_landing_position
		pit_recovery_pending = false
	visual.rotation = 0.0
	heal_overlay.rotation = 0.0
	start_invulnerability(
		knockback_recovery_left + runtime_config.player_post_getup_invulnerability_seconds,
		&"knockdown_recovery"
	)
	if knockback_recovery_left <= 0.0:
		_set_weapon_activity(not dead)


func start_pit_recovery(landing_position: Vector2, launch_direction: Vector2 = Vector2.UP) -> bool:
	if dead or landing_position == Vector2.INF:
		return false
	pit_recovery_landing_position = landing_position
	pit_recovery_pending = true
	# Pit recovery is an authored escape impulse and therefore intentionally
	# bypasses the ordinary post-hit recovery gate while preserving inventory.
	start_airborne_knockback(
		launch_direction if launch_direction.length_squared() > 0.001 else Vector2.UP,
		maxf(runtime_config.character_knockback_vertical_velocity * 0.65, 140.0),
		maxf(runtime_config.character_knockback_vertical_velocity * 0.82, 170.0),
		true,
		true
	)
	return airborne_knockback


func _handle_airborne_collisions() -> void:
	var combined_normal := Vector2.ZERO
	var hit_pushable_prop := false

	for index in range(
		get_slide_collision_count()
	):
		var collision := get_slide_collision(
			index
		)

		if collision == null:
			continue

		var normal := collision.get_normal().normalized()
		var collider := collision.get_collider()

		if (
			collider is RigidBody2D
			and (collider as RigidBody2D).is_in_group(
				&"pushable_prop"
			)
		):
			(collider as RigidBody2D).apply_central_impulse(
				-normal
				* external_knockback_velocity.length()
				* 0.55
			)
			hit_pushable_prop = true

		combined_normal += normal

		if secondary_collision_cooldown_left <= 0.0:
			secondary_collision_cooldown_left = (
				runtime_config.secondary_collision_cooldown
			)

			_apply_secondary_collision_damage(
				runtime_config.secondary_collision_damage
			)

	if combined_normal.length_squared() > 0.001:
		SFX.play_event(&"furniture_impact" if hit_pushable_prop else &"wall_impact")
		external_knockback_velocity = (
			external_knockback_velocity.bounce(
				combined_normal.normalized()
			)
			* runtime_config.character_knockback_bounce_retention
		)


func _apply_secondary_collision_damage(amount: float) -> void:
	# 击飞恢复周期内（Airborne/Down/GetUp/站起后保护）撞墙不再扣 HP；
	# 墙体反弹/音效等表现不受影响（只拒绝伤害结算）。
	if dead or amount <= 0.0 or _is_knock_recovery_protected():
		return

	invulnerability_left = 0.0
	dash_invulnerability_left = 0.0

	receive_damage(
		amount,
		&"secondary_collision"
	)


func start_invulnerability(
	duration: float,
	reason: StringName = &"external"
) -> void:
	var safe_duration := maxf(
		duration,
		0.0
	)

	if safe_duration <= 0.0:
		return

	if safe_duration >= invulnerability_left:
		invulnerability_reason = reason
		invulnerability_left = maxf(
			invulnerability_left,
			safe_duration
		)

	_update_visual_feedback()


func heal(amount: float) -> void:
	if (
		dead
		or amount <= 0.0
		or current_health >= maximum_health
	):
		return

	var health_before := current_health

	current_health = minf(
		maximum_health,
		current_health + amount
	)

	var actual_heal := maxf(
		0.0,
		current_health - health_before
	)

	if actual_heal <= 0.0:
		return

	health_changed.emit(
		current_health,
		maximum_health
	)

	player_hp_bar.show_after_damage(
		current_health,
		maximum_health,
		CONFIG.player_hp_bar_visible_duration
	)

	healed.emit(
		actual_heal
	)

	_apply_heal_feedback()
	_play_heal_effect()


func _apply_heal_feedback() -> void:
	SFX.play_event(
		&"heal"
	)

	if (
		heal_overlay_tween != null
		and heal_overlay_tween.is_valid()
	):
		heal_overlay_tween.kill()

	heal_overlay.modulate = Color(
		0.36,
		1.0,
		0.45,
		0.72
	)

	heal_overlay_tween = create_tween()

	heal_overlay_tween.tween_property(
		heal_overlay,
		"modulate:a",
		0.0,
		CONFIG.heal_feedback_seconds
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


func _play_heal_effect() -> void:
	var now_msec := Time.get_ticks_msec()

	if (
		last_heal_effect_msec > 0
		and now_msec - last_heal_effect_msec
		< HEAL_EFFECT_THROTTLE_MSEC
	):
		return

	last_heal_effect_msec = now_msec

	var effect := HEAL_EFFECT_SCENE.instantiate()

	effect.position = visual_home_position

	add_child(
		effect
	)


func configure_sleep_paralysis(
	still_seconds: float,
	heal_per_second: float
) -> void:
	sleep_paralysis_still_seconds = still_seconds
	sleep_paralysis_heal_per_second = heal_per_second

	_reset_stillness()


func _update_sleep_paralysis(
	delta: float,
	effective_motion: Vector2
) -> void:
	if sleep_paralysis_still_seconds <= 0.0:
		return

	if effective_motion.length_squared() > 0.0001:
		_reset_stillness()
		return

	still_elapsed += delta

	if still_elapsed < sleep_paralysis_still_seconds:
		return

	heal_tick_accumulator += delta

	while heal_tick_accumulator >= 1.0:
		heal_tick_accumulator -= 1.0

		heal(
			sleep_paralysis_heal_per_second
		)


func _reset_stillness() -> void:
	still_elapsed = 0.0
	heal_tick_accumulator = 0.0


func configure_sleep_spindle(
	interval: float,
	maximum_layers: int = 1
) -> void:
	sleep_spindle_interval = interval
	sleep_spindle_left = interval
	sleep_spindle_max_layers = maxi(
		1,
		maximum_layers
	)


func _update_sleep_spindle(delta: float) -> void:
	if sleep_spindle_interval <= 0.0:
		return

	sleep_spindle_left -= delta

	if sleep_spindle_left <= 0.0:
		sleep_spindle_left = sleep_spindle_interval

		if (
			sleep_spindle_max_layers > 0
			and not has_shield
		):
			has_shield = true
			shield_visual.set_shield_active(true)

			skill_state_changed.emit(
				has_shield,
				dissociation_ready
			)


func configure_consciousness_drift(
	level: int,
	config: DemoConfig
) -> void:
	var chance := clampf(
		level
		* config.consciousness_drift_chance_per_level,
		0.0,
		1.0
	)

	auto_weapon.set_extra_attack(
		chance,
		config.consciousness_drift_extra_delay
	)

	shotgun_weapon.set_extra_attack(
		chance,
		config.consciousness_drift_extra_delay
	)

	if lucille_weapon != null:
		lucille_weapon.set_extra_attack(
			chance,
			config.consciousness_drift_extra_delay
		)

	if books_weapon != null:
		books_weapon.set_extra_attack(
			chance,
			config.consciousness_drift_extra_delay
		)

	if assault_rifle_weapon != null:
		assault_rifle_weapon.set_extra_attack(
			chance,
			config.consciousness_drift_extra_delay
		)


func enable_dissociation(config: DemoConfig) -> void:
	dissociation_ready = true
	dissociation_revive_health = config.dissociation_revive_health
	dissociation_invulnerability_seconds = config.dissociation_invulnerability_seconds

	skill_state_changed.emit(
		has_shield,
		dissociation_ready
	)


func _play_feedback() -> void:
	if feedback_audio.stream != null:
		feedback_audio.stop()
		feedback_audio.play()


func set_attacking_enabled(enabled: bool) -> void:
	attacking_enabled = enabled
	_set_weapon_activity(
		enabled and not dead
	)
	# Cabin disables attacks, not the empty-handed body's presentation.
	_update_hands_visibility()


func set_scripted_locomotion(direction: Vector2, speed: float = 110.0) -> void:
	scripted_locomotion_active = true
	scripted_locomotion_direction = direction.normalized()
	scripted_locomotion_speed = speed


func clear_scripted_locomotion() -> void:
	scripted_locomotion_active = false
	scripted_locomotion_direction = Vector2.ZERO
	scripted_locomotion_speed = 0.0
	velocity = Vector2.ZERO
	_time_locomotion_velocity = Vector2.ZERO


func _set_weapon_activity(enabled: bool) -> void:
	enabled = (
		enabled
		and attacking_enabled
		and external_knockback_left <= 0.0
	)
	if not enabled:
		_cancel_throw_aim()

	auto_weapon.active = enabled and selected_weapon_id == "basic"
	shotgun_weapon.active = enabled and selected_weapon_id == "shotgun"

	if lucille_weapon != null:
		lucille_weapon.active = enabled and selected_weapon_id == "lucille"

	if books_weapon != null:
		books_weapon.active = enabled and selected_weapon_id == "books"

	if assault_rifle_weapon != null:
		assault_rifle_weapon.active = enabled and selected_weapon_id == "assault_rifle"

	if held_weapon_sprite != null:
		held_weapon_sprite.visible = enabled and not selected_weapon_id.is_empty()


## 剧情Dream始终使用鼠标左键手动攻击（飞扑空中可射击，落地翻滚期间禁止射击）。
func should_trigger_weapon_attack() -> bool:
	if not _presentation_pointer_input_allowed():
		return false
	if dashing and not is_dive_airborne():
		return false
	return (
		not dead
		and attacking_enabled
		and external_knockback_left <= 0.0
		and not kick_active
		and not tactical_plan_active
		and (
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or (InputMap.has_action("attack") and Input.is_action_pressed("attack"))
			or bool(get_meta(&"force_weapon_attack", false))
		)
	)


func _presentation_pointer_input_allowed() -> bool:
	# Optional presentation adapter (e.g. an integer-letterboxed preview).
	# Normal gameplay supplies no gate and retains its existing input rules.
	var gate: Variant = get_meta(&"presentation_pointer_gate", Callable())
	return not (gate is Callable and gate.is_valid()) or bool(gate.call())


func get_presentation_pointer_position() -> Vector2:
	var provider: Callable = get_meta(&"presentation_pointer_position", Callable())
	return provider.call() if provider.is_valid() else get_viewport().get_mouse_position()


## Convert a Camera3D viewport pixel to the clear HUD's logical canvas.
func get_presentation_hud_position(world_viewport_position: Vector2) -> Vector2:
	var converter: Callable = get_meta(&"presentation_world_to_hud", Callable())
	return converter.call(world_viewport_position) if converter.is_valid() else world_viewport_position


func weapon_uses_ammo(
	weapon_id: String = selected_weapon_id
) -> bool:
	return AMMO_WEAPON_IDS.has(
		weapon_id
	)


func try_consume_ammo_for_attack() -> bool:
	if not weapon_uses_ammo():
		return true

	_ensure_ammo_state(
		selected_weapon_id
	)

	var state: Dictionary = ammo_states[
		selected_weapon_id
	]

	if float(state.get("reload_left", 0.0)) > 0.0:
		return false

	var current := int(
		state.get(
			"current",
			0
		)
	)

	if current <= 0:
		_start_reload(
			selected_weapon_id
		)

		return false

	state.current = current - 1

	ammo_states[
		selected_weapon_id
	] = state

	if int(state.current) <= 0:
		_start_reload(
			selected_weapon_id
		)

	else:
		_emit_ammo_state()

	return true


func request_reload() -> bool:
	if dead or not weapon_uses_ammo():
		return false

	return _start_reload(
		selected_weapon_id
	)


func get_ammo_status() -> Dictionary:
	if not weapon_uses_ammo():
		return {
			"uses_ammo": false,
			"current": 0,
			"capacity": 0,
			"reloading": false,
			"reload_left": 0.0
		}

	_ensure_ammo_state(
		selected_weapon_id
	)

	var state: Dictionary = ammo_states[
		selected_weapon_id
	]

	return {
		"uses_ammo": true,
		"current": int(
			state.get(
				"current",
				_get_magazine_capacity(
					selected_weapon_id
				)
			)
		),
		"capacity": _get_magazine_capacity(
			selected_weapon_id
		),
		"reloading": float(
			state.get(
				"reload_left",
				0.0
			)
		) > 0.0,
		"reload_left": float(
			state.get(
				"reload_left",
				0.0
			)
		),
	}


## Weapon scripts call this immediately before the formal consume attempt so a
## dry-fire cue is emitted only for an actually empty magazine.  Reloading and
## non-ammo/melee weapons deliberately return false, keeping trigger cadence
## and the single reload authority unchanged.
func is_weapon_empty_for_attack() -> bool:
	var status := get_ammo_status()
	return (
		bool(status.get("uses_ammo", false))
		and int(status.get("current", 0)) <= 0
		and not bool(status.get("reloading", false))
	)


func _ensure_ammo_state(weapon_id: String) -> void:
	if (
		not weapon_uses_ammo(weapon_id)
		or ammo_states.has(weapon_id)
	):
		return

	ammo_states[weapon_id] = {
		"current": _get_magazine_capacity(
			weapon_id
		),
		"reload_left": 0.0,
	}


func _start_reload(weapon_id: String) -> bool:
	_ensure_ammo_state(
		weapon_id
	)

	if not ammo_states.has(weapon_id):
		return false

	var state: Dictionary = ammo_states[
		weapon_id
	]

	if float(state.get("reload_left", 0.0)) > 0.0:
		return false
	var magazine_capacity := _get_magazine_capacity(weapon_id)
	if int(state.get("current", magazine_capacity)) >= magazine_capacity:
		return false

	state.reload_left = maxf(
		runtime_config.weapon_reload_duration,
		0.1
	)

	ammo_states[weapon_id] = state

	if weapon_id == selected_weapon_id:
		_begin_reload_visual(
			float(state.reload_left)
		)

		_emit_ammo_state()
		SFX.play_weapon_reload()

	return true


func _update_ammo(delta: float) -> void:
	for weapon_id_variant in ammo_states.keys():
		var weapon_id := str(
			weapon_id_variant
		)

		var state: Dictionary = ammo_states[
			weapon_id
		]

		var reload_left := float(
			state.get(
				"reload_left",
				0.0
			)
		)

		if reload_left <= 0.0:
			continue

		reload_left = maxf(
			0.0,
			reload_left - delta
		)

		state.reload_left = reload_left

		if reload_left <= 0.0:
			state.current = _get_magazine_capacity(
				weapon_id
			)

		ammo_states[
			weapon_id
		] = state

		if (
			weapon_id == selected_weapon_id
			and reload_left <= 0.0
		):
			_finish_reload_visual()
			_emit_ammo_state()


func _begin_reload_visual(duration: float) -> void:
	_cancel_reload_visual()

	if (
		weapon_visual_tween != null
		and weapon_visual_tween.is_valid()
	):
		weapon_visual_tween.kill()

	weapon_motion.position = Vector2.ZERO
	weapon_motion.rotation = 0.0
	reload_visual_pivot.rotation = 0.0

	reload_visual_tween = create_tween()

	reload_visual_tween.tween_method(
		_set_reload_visual_rotation,
		0.0,
		TAU,
		maxf(
			duration,
			0.01
		)
	).set_trans(
		Tween.TRANS_LINEAR
	)

	reload_visual_tween.tween_callback(
		_finish_reload_visual
	)


func _set_reload_visual_rotation(value: float) -> void:
	reload_visual_pivot.rotation = value


func _finish_reload_visual() -> void:
	reload_visual_pivot.rotation = 0.0
	reload_visual_tween = null


func _cancel_reload_visual() -> void:
	if (
		reload_visual_tween != null
		and reload_visual_tween.is_valid()
	):
		reload_visual_tween.kill()

	reload_visual_tween = null

	if reload_visual_pivot != null:
		reload_visual_pivot.rotation = 0.0


func _cancel_all_reloads() -> void:
	for weapon_id_variant in ammo_states.keys():
		var weapon_id := str(
			weapon_id_variant
		)

		var state: Dictionary = ammo_states[
			weapon_id
		]

		state.reload_left = 0.0

		ammo_states[
			weapon_id
		] = state

	_cancel_reload_visual()


func _emit_ammo_state() -> void:
	var status := get_ammo_status()

	ammo_changed.emit(
		int(status.current),
		int(status.capacity),
		status.reloading == true
	)


func _refresh_held_weapon_visual() -> void:
	if held_weapon_sprite == null:
		return

	held_weapon_sprite.texture = DreamGunAtlas.get_held(
		selected_weapon_id,
		get_weapon_skin_index(selected_weapon_id)
	)

	held_weapon_sprite.scale = Vector2.ONE * runtime_config.held_weapon_world_scale

	held_weapon_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	held_weapon_sprite.position = Vector2(
		runtime_config.held_weapon_distance,
		0.0
	)

	held_weapon_sprite.flip_h = false
	held_weapon_sprite.visible = not dead and not selected_weapon_id.is_empty()

	_update_hands_visibility()
	_refresh_held_weapon_depth()
	_sync_reload_visual_to_selected_weapon()


func _sync_reload_visual_to_selected_weapon() -> void:
	_cancel_reload_visual()

	if (
		not weapon_uses_ammo()
		or not ammo_states.has(
			selected_weapon_id
		)
	):
		return

	var reload_left := float(
		(
			ammo_states[
				selected_weapon_id
			]
			as Dictionary
		).get(
			"reload_left",
			0.0
		)
	)

	if reload_left > 0.0:
		_begin_reload_visual(
			reload_left
		)


func _refresh_held_weapon_depth() -> void:
	if (
		held_weapon_sprite == null
		or weapon_root == null
	):
		return

	## WeaponRoot remains inside the actor's world-sorted band.
	## When facing back, weapon draws behind character parts (z_index = -1).
	## Otherwise it draws in front of character parts (z_index = 0).
	if character_facing_back:
		weapon_root.z_index = -1
	else:
		weapon_root.z_index = 0
	held_weapon_sprite.z_index = 0
	weapon_root.show_behind_parent = false


func _update_held_weapon_aim() -> void:
	_update_held_weapon_aim_at(get_presentation_pointer_position())


func _update_held_weapon_aim_at(mouse_screen: Vector2) -> void:
	if hand_anchor == null:
		return
	# The formal 3D muzzle depends on the held pose, while the held pose depends
	# on aim. Resolve once with the previous muzzle, then once with this frame's
	# muzzle. This avoids a one-frame aim lag when crossing the actor or turning.
	for iteration in 2:
		var direction := _aim_direction_at(mouse_screen)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		var pose: Dictionary = WEAPON_POSE.solve(
			direction,
			maxf(runtime_config.held_weapon_distance + 3.0, 12.0),
			maxf(runtime_config.held_weapon_distance * 0.82, 8.0),
			runtime_config.held_weapon_distance
		)
		var resolved_direction: Vector2 = pose.get("aim_direction", direction)
		hand_anchor.position = pose.get("orbit_offset", Vector2.ZERO)
		hand_anchor.rotation = resolved_direction.angle()
		held_weapon_sprite.flip_v = resolved_direction.x < 0.0

		var orbit_offset: Vector2 = pose.get("orbit_offset", Vector2.ZERO)
		var muzzle_local: Vector2 = pose.get("muzzle_local", Vector2(runtime_config.held_weapon_distance, 0.0))
		var origin_offset := orbit_offset + muzzle_local.rotated(resolved_direction.angle())
		weapon_origin.position = origin_offset
		projectile_origin.position = origin_offset


func _on_weapon_fired(multiplier: float) -> void:
	var camera_level: StringName = &"small"
	var is_melee := DreamGunAtlas.get_category(selected_weapon_id) == DreamGunAtlas.CATEGORY_MELEE
	var is_firearm := DreamGunAtlas.has_firearm(selected_weapon_id)
	if not is_melee and selected_weapon_id == "shotgun":
		camera_level = &"heavy"
	elif is_melee:
		# 挥击开始只给很轻的动作感；真正的重反馈在Impact信号到达时触发。
		camera_level = &"small"
	_request_combat_camera_impulse(camera_level, get_aim_direction())
	_apply_firearm_recoil(multiplier)

	weapon_fired.emit(
		multiplier
	)
	if is_firearm:
		confirmed_projectile_fired.emit()

	if (
		weapon_visual_tween != null
		and weapon_visual_tween.is_valid()
	):
		weapon_visual_tween.kill()

	weapon_motion.position = Vector2.ZERO
	weapon_motion.rotation = 0.0

	if DreamGunAtlas.get_category(selected_weapon_id) == DreamGunAtlas.CATEGORY_MELEE:
		_play_melee_swing_visual()
		# All formal melee weapons share the same character swing response; the
		# weapon node supplies each weapon's own damage/range/cooldown data.
		_play_melee_character_visual()

	else:
		weapon_visual_tween = create_tween()

		var recoil := (
			-runtime_config.weapon_recoil_distance
			* maxf(
				multiplier,
				0.1
			)
		)

		weapon_visual_tween.tween_property(
			weapon_motion,
			"position:x",
			recoil,
			runtime_config.weapon_recoil_kick_seconds
		)

		weapon_visual_tween.tween_property(
			weapon_motion,
			"position:x",
			0.0,
			runtime_config.weapon_recoil_return_seconds
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_OUT
		)


func _on_melee_impact(hit_something: bool) -> void:
	if not hit_something or dead:
		return
	var level: StringName = &"medium"
	if selected_weapon_id == "lucille":
		level = &"heavy"
	_request_combat_camera_impulse(level, lucille_attack_direction)


func _on_melee_furniture_hit(direction: Vector2) -> void:
	if dead or runtime_config == null or direction.length_squared() <= 0.001:
		return
	apply_movement_impulse(
		-direction.normalized(),
		runtime_config.player_melee_furniture_recoil,
		0.12
	)


func _apply_firearm_recoil(multiplier: float) -> void:
	if runtime_config == null or selected_weapon_id.is_empty():
		return
	var weapon_name := StringName(selected_weapon_id)
	var recoil := 0.0
	var impulse_level: StringName = &"small"
	match weapon_name:
		&"shotgun":
			recoil = runtime_config.player_shotgun_recoil
			impulse_level = &"heavy"
		&"assault_rifle":
			recoil = runtime_config.player_assault_rifle_recoil
			impulse_level = &"medium"
		&"lucille":
			impulse_level = &"heavy"
		_:
			recoil = runtime_config.player_default_firearm_recoil
			impulse_level = &"small"
	var direction := get_aim_direction()
	if direction.length_squared() <= 0.001:
		return
	if recoil > 0.0:
		apply_movement_impulse(-direction.normalized(), recoil * maxf(multiplier, 0.5))
	_request_combat_camera_impulse(impulse_level, -direction.normalized())


func _request_combat_camera_impulse(level: StringName, direction: Vector2) -> void:
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("request_camera_impulse"):
		world.request_camera_impulse(level, direction)


func _play_melee_swing_visual() -> void:
	if (
		lucille_trail_tween != null
		and lucille_trail_tween.is_valid()
	):
		lucille_trail_tween.kill()

	lucille_trail.clear_points()
	lucille_trail.visible = true
	lucille_trail.modulate.a = 1.0
	_configure_melee_trail_profile()

	# 六个视觉阶段约对应参考GIF的 6×40ms：起手、加速、主挥击、Impact、
	# Follow Through、收尾。轨迹由同一个Tween驱动，避免并行动画抢Transform。
	var total_duration: float = maxf(
		runtime_config.lucille_character_windup_seconds
		+ runtime_config.lucille_character_strike_seconds
		+ runtime_config.lucille_character_recover_seconds,
		0.01
	)
	total_duration /= maxf(acquired_attack_speed_multiplier, 1.0)
	_set_melee_swing_progress(0.0)
	weapon_visual_tween = create_tween()
	weapon_visual_tween.tween_method(
		_set_melee_swing_progress,
		0.0,
		1.0,
		total_duration
	).set_trans(Tween.TRANS_LINEAR)
	weapon_visual_tween.tween_callback(_finish_melee_swing_visual)

	lucille_trail_tween = create_tween()
	var trail_lifetime: float = clampf(
		runtime_config.lucille_trail_lifetime
		/ maxf(acquired_attack_speed_multiplier, 1.0),
		0.10,
		total_duration
	)
	var fade_seconds: float = clampf(
		runtime_config.lucille_trail_fade_seconds
		/ maxf(acquired_attack_speed_multiplier, 1.0),
		0.02,
		trail_lifetime
	)
	lucille_trail_tween.tween_interval(
		maxf(trail_lifetime - fade_seconds, 0.0)
	)
	lucille_trail_tween.tween_property(
		lucille_trail,
		"modulate:a",
		0.0,
		fade_seconds
	)

	lucille_trail_tween.tween_callback(
		_hide_lucille_trail
	)


func _configure_melee_trail_profile() -> void:
	if lucille_trail == null:
		return
	var is_books := selected_weapon_id == "books"
	lucille_trail.width = (
		runtime_config.books_trail_width
		if is_books
		else runtime_config.lucille_trail_width
	)
	lucille_trail.default_color = Color.WHITE
	lucille_trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lucille_trail.antialiased = false
	# Curve使尾端细、靠近当前武器的一端厚，仍保持像素边缘而不是发光。
	if melee_trail_width_curve == null:
		melee_trail_width_curve = Curve.new()
		melee_trail_width_curve.min_value = 0.0
		melee_trail_width_curve.max_value = 1.0
		melee_trail_width_curve.add_point(Vector2(0.0, 0.12))
		melee_trail_width_curve.add_point(Vector2(0.32, 0.36))
		melee_trail_width_curve.add_point(Vector2(0.72, 0.78))
		melee_trail_width_curve.add_point(Vector2(1.0, 1.0))
	lucille_trail.width_curve = melee_trail_width_curve
	# 仅改变白色轨迹的Alpha，不引入颜色、Glow或额外光源。
	if melee_trail_gradient == null:
		melee_trail_gradient = Gradient.new()
		melee_trail_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.10))
		melee_trail_gradient.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
		melee_trail_gradient.add_point(0.52, Color(1.0, 1.0, 1.0, 0.62))
	lucille_trail.gradient = melee_trail_gradient


func _finish_melee_swing_visual() -> void:
	weapon_motion.rotation = 0.0
	weapon_motion.position = Vector2.ZERO


func _set_melee_swing_progress(progress: float) -> void:
	var normalized: float = clampf(progress, 0.0, 1.0)
	var stage_value: float = normalized * 6.0
	var stage_index: int = clampi(int(stage_value), 0, 5)
	var local_t: float = clampf(
		stage_value - float(stage_index),
		0.0,
		1.0
	)
	var eased_t: float = local_t
	if stage_index == 0:
		eased_t = local_t * local_t
	elif stage_index >= 1 and stage_index <= 3:
		# 中段快速加速，并把最大挥击速度集中在Impact附近。
		eased_t = 1.0 - pow(1.0 - local_t, 2.0)
	else:
		eased_t = 1.0 - pow(1.0 - local_t, 2.0)

	var angle_degrees: float
	match stage_index:
		0: angle_degrees = lerpf(-108.0, -96.0, eased_t)
		1: angle_degrees = lerpf(-96.0, -60.0, eased_t)
		2: angle_degrees = lerpf(-60.0, 20.0, eased_t)
		3: angle_degrees = lerpf(20.0, 104.0, eased_t)
		4: angle_degrees = lerpf(104.0, 72.0, eased_t)
		_: angle_degrees = lerpf(72.0, 0.0, eased_t)
	_set_melee_swing_angle(deg_to_rad(angle_degrees))


func _play_melee_character_visual() -> void:
	## Kick正在进行时不允许挥动攻击角色位移叠加。
	if kick_active:
		return

	if (
		lucille_character_tween != null
		and lucille_character_tween.is_valid()
	):
		lucille_character_tween.kill()

	lucille_character_offset = Vector2.ZERO
	lucille_body_lean_rotation = 0.0

	lucille_attack_direction = get_aim_direction()

	if lucille_attack_direction.length_squared() <= 0.001:
		lucille_attack_direction = last_aim_direction

	if lucille_attack_direction.length_squared() <= 0.001:
		lucille_attack_direction = Vector2.RIGHT

	lucille_attack_direction = lucille_attack_direction.normalized()

	var windup_seconds := maxf(
		runtime_config.lucille_character_windup_seconds,
		0.01
	)

	var strike_seconds := maxf(
		runtime_config.lucille_character_strike_seconds,
		0.01
	)

	var recover_seconds := maxf(
		runtime_config.lucille_character_recover_seconds,
		0.01
	)

	var total_duration := (
		windup_seconds
		+ strike_seconds
		+ recover_seconds
	)
	total_duration /= maxf(acquired_attack_speed_multiplier, 1.0)

	lucille_character_tween = create_tween()

	lucille_character_tween.tween_method(
		_set_lucille_character_animation_progress,
		0.0,
		1.0,
		total_duration
	).set_trans(
		Tween.TRANS_LINEAR
	)

	lucille_character_tween.tween_callback(
		_finish_lucille_character_visual
	)


func _set_lucille_character_animation_progress(progress: float) -> void:
	var windup_seconds := maxf(
		runtime_config.lucille_character_windup_seconds,
		0.01
	)

	var strike_seconds := maxf(
		runtime_config.lucille_character_strike_seconds,
		0.01
	)

	var recover_seconds := maxf(
		runtime_config.lucille_character_recover_seconds,
		0.01
	)

	var total_seconds := maxf(
		windup_seconds
		+ strike_seconds
		+ recover_seconds,
		0.001
	)

	var windup_end := (
		windup_seconds
		/ total_seconds
	)

	var strike_end := (
		(windup_seconds + strike_seconds)
		/ total_seconds
	)

	var windup_offset := (
		-lucille_attack_direction
		* runtime_config.lucille_character_back_pixels
	)

	windup_offset.y -= (
		runtime_config.lucille_character_hop_pixels
	)

	var strike_offset := (
		lucille_attack_direction
		* runtime_config.lucille_character_forward_pixels
	)

	strike_offset.y -= (
		runtime_config.lucille_character_hop_pixels
		* 0.35
	)

	var lean_sign := _get_lucille_lean_sign(
		lucille_attack_direction
	)

	var maximum_back_lean := (
		deg_to_rad(
			runtime_config.lucille_character_back_lean_degrees
		)
		* lean_sign
	)

	if progress < windup_end:
		var t := clampf(
			progress / maxf(
				windup_end,
				0.001
			),
			0.0,
			1.0
		)

		var eased := sin(
			t * PI * 0.5
		)

		lucille_character_offset = Vector2.ZERO.lerp(
			windup_offset,
			eased
		)

		lucille_body_lean_rotation = (
			maximum_back_lean
			* eased
		)

	elif progress < strike_end:
		var t := clampf(
			(progress - windup_end)
			/ maxf(
				strike_end - windup_end,
				0.001
			),
			0.0,
			1.0
		)

		var eased := 1.0 - pow(
			1.0 - t,
			2.0
		)

		lucille_character_offset = windup_offset.lerp(
			strike_offset,
			eased
		)

		lucille_body_lean_rotation = lerpf(
			maximum_back_lean,
			-maximum_back_lean * 0.28,
			eased
		)

	else:
		var t := clampf(
			(progress - strike_end)
			/ maxf(
				1.0 - strike_end,
				0.001
			),
			0.0,
			1.0
		)

		var eased := 1.0 - pow(
			1.0 - t,
			2.0
		)

		lucille_character_offset = strike_offset.lerp(
			Vector2.ZERO,
			eased
		)

		lucille_body_lean_rotation = lerpf(
			-maximum_back_lean * 0.28,
			0.0,
			eased
		)


func _get_lucille_lean_sign(direction: Vector2) -> float:
	if absf(direction.x) >= absf(direction.y):
		return -1.0 if direction.x > 0.0 else 1.0

	return 1.0 if direction.y > 0.0 else -1.0


func _finish_lucille_character_visual() -> void:
	lucille_character_offset = Vector2.ZERO
	lucille_body_lean_rotation = 0.0
	lucille_character_tween = null


func _set_melee_swing_angle(angle: float) -> void:
	weapon_motion.rotation = angle

	var arc_radius: float = (
		runtime_config.books_trail_radius
		if selected_weapon_id == "books"
		else runtime_config.lucille_trail_radius
	)
	var tip := Vector2(
		arc_radius,
		0.0
	).rotated(
		angle
	)

	lucille_trail.add_point(
		tip
	)

	while (
		lucille_trail.get_point_count()
		> runtime_config.lucille_trail_max_points
	):
		lucille_trail.remove_point(
			0
		)


func _hide_lucille_trail() -> void:
	lucille_trail.visible = false
	lucille_trail.clear_points()
	lucille_trail.modulate.a = 1.0
	lucille_trail_tween = null


func _ensure_weapon_switch_input_actions() -> void:
	var actions := {
		"weapon_next": MOUSE_BUTTON_WHEEL_UP,
		"weapon_previous": MOUSE_BUTTON_WHEEL_DOWN
	}

	for action_name in actions:
		if not InputMap.has_action(
			action_name
		):
			InputMap.add_action(
				action_name
			)

		var already_bound := false

		for event in InputMap.action_get_events(
			action_name
		):
			if (
				event is InputEventMouseButton
				and event.button_index
				== actions[action_name]
			):
				already_bound = true
				break

		if not already_bound:
			var mouse_event := InputEventMouseButton.new()

			mouse_event.button_index = actions[
				action_name
			]

			InputMap.action_add_event(
				action_name,
				mouse_event
			)


func _show_weapon_name() -> void:
	weapon_name_label.text = DreamGunAtlas.get_display_name(selected_weapon_id)

	weapon_name_label.visible = not suppress_local_weapon_name_label
	weapon_name_time_left = 1.1


func _update_weapon_name(delta: float) -> void:
	# Native 3D worlds retain reload status independently of the short pickup
	# popup lifetime. Random3D suppresses this local label and owns its HUD copy.
	if get_tree().get_first_node_in_group(&"dream_world") is Node3D:
		var reloading := bool(get_ammo_status().get("reloading", false))
		if reloading and not dead:
			weapon_name_label.text = "正在换弹"
			weapon_name_label.visible = not suppress_local_weapon_name_label
			weapon_name_time_left = 0.0
			return
		if weapon_name_label.text == "正在换弹":
			weapon_name_label.visible = false
			weapon_name_label.text = ""
	if weapon_name_time_left <= 0.0:
		return

	weapon_name_time_left = maxf(
		0.0,
		weapon_name_time_left - delta
	)

	if weapon_name_time_left <= 0.0:
		weapon_name_label.visible = false


func get_active_weapon() -> Node:
	match selected_weapon_id:
		"assault_rifle":
			return assault_rifle_weapon

		"shotgun":
			return shotgun_weapon

		"lucille":
			return lucille_weapon

		"books":
			return books_weapon

		_:
			return auto_weapon


func _get_weapon_node(weapon_id: String) -> Node:
	match weapon_id:
		"assault_rifle":
			return assault_rifle_weapon
		"shotgun":
			return shotgun_weapon
		"lucille":
			return lucille_weapon
		"books":
			return books_weapon
		"basic":
			return auto_weapon
		_:
			return null


func _get_magazine_capacity(weapon_id: String) -> int:
	if weapon_id == "assault_rifle":
		return maxi(
			1,
			runtime_config.assault_rifle_magazine_size
		)

	return maxi(
		1,
		runtime_config.default_weapon_magazine_size
	)


func get_weapon_origin() -> Vector2:
	return weapon_origin.global_position


func get_projectile_origin() -> Vector2:
	if not is_inside_tree() or projectile_origin == null:
		return global_position
	var nominal_pos: Vector2 = projectile_origin.global_position
	var start_pos: Vector2 = aim_origin.global_position if aim_origin != null else global_position
	var space_state := get_world_2d().direct_space_state if get_world_2d() != null else null
	if space_state == null:
		return nominal_pos
	var segment := nominal_pos - start_pos
	if segment.length_squared() <= 0.01:
		return nominal_pos
	# Check world geometry (1), walls/doors (4), and props (8)
	var mask: int = 1 | 4 | 8
	var query := PhysicsRayQueryParameters2D.create(start_pos, nominal_pos, mask, [get_rid()])
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = true
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector2 = hit.get("position", nominal_pos)
		var dir := segment.normalized()
		var pull_back_dist: float = minf(1.5, start_pos.distance_to(hit_pos) * 0.5)
		return hit_pos - dir * pull_back_dist
	return nominal_pos


func get_aim_origin() -> Vector2:
	return aim_origin.global_position


func get_time_locomotion_speed() -> float:
	## Activity source for DreamTimeController.  This is the post-collision
	## gameplay locomotion component only; recoil, knockback and dash branches
	## explicitly reset it to zero.
	return maxf(_time_locomotion_speed, 0.0)


func is_time_activity_active() -> bool:
	## SUPERHOT samples formal gameplay actions only. Restored WASD locomotion
	## is a real gameplay activity; DashAim itself remains preview-only.
	if dead:
		return false
	# Throw aim is presentation-only while RMB is held. It is deliberately not
	# treated as locomotion activity; the separate T action owns manual time.
	if throw_aim_active:
		return false
	# Space hold preview owns the Player's position and suppresses WASD
	# locomotion.  Raw movement keys held during this state must not wake time.
	if dash_input_state == DashInputState.AIM or dash_aim_active:
		return false
	if dashing or vault_active or airborne_knockback or knockback_recovery_left > 0.0:
		return true
	if external_knockback_left > 0.0 or punch_active or kick_active:
		return true
	if movement_enabled and Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.0001:
		return true
	for weapon in [lucille_weapon, books_weapon]:
		if weapon != null and bool(weapon.get("melee_action_active")):
			return true
	# Holding the formal firearm attack input is a continuous firing activity.
	# This keeps automatic weapons on normal time between shots instead of
	# letting the short confirmed-shot pulse slow the next cadence interval.
	if (
		not selected_weapon_id.is_empty()
		and DreamGunAtlas.has_firearm(selected_weapon_id)
		and should_trigger_weapon_attack()
	):
		return true
	return false


func get_aim_direction() -> Vector2:
	return _aim_direction_at(get_presentation_pointer_position())


func _aim_direction_at(mouse_screen: Vector2) -> Vector2:
	if has_meta(&"aim_direction_override"):
		var override_val: Variant = get_meta(&"aim_direction_override")
		if override_val is Vector2 and (override_val as Vector2).length_squared() > 0.0001:
			last_aim_direction = (override_val as Vector2).normalized()
			return last_aim_direction
	var camera_direction := _camera_muzzle_aim_direction_at(mouse_screen)
	if camera_direction.length_squared() > 0.0001:
		last_aim_direction = camera_direction.normalized()
		return last_aim_direction
	var direction := get_aim_origin().direction_to(
		get_constrained_aim_position()
	)

	if direction.length_squared() > 0.0001:
		last_aim_direction = direction

	return last_aim_direction


## The 3D gun, flash and first projectile frame share a formal muzzle snapshot.
## Intersect the camera ray with that muzzle's horizontal reference plane, then
## convert the shot vector back into the unchanged 2D gameplay coordinates.
## Legacy 2D Dream never enters this adapter.
func _camera_muzzle_aim_direction() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	return _camera_muzzle_aim_direction_at(get_presentation_pointer_position())


func _camera_muzzle_aim_direction_at(mouse: Vector2) -> Vector2:
	if not is_inside_tree() or projectile_origin == null:
		return Vector2.ZERO
	var world := get_tree().get_first_node_in_group(&"dream_world") as Node3D
	if world == null:
		return Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2.ZERO
	var bridge_ref: Variant = get_meta(&"depth_visual_bridge") if has_meta(&"depth_visual_bridge") else null
	var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
	if bridge == null or not is_instance_valid(bridge) or not bridge.has_method("get_weapon_visual_snapshot"):
		return Vector2.ZERO
	var snapshot: Dictionary = bridge.call("get_weapon_visual_snapshot", projectile_origin.global_position)
	if not snapshot.has("world_origin"):
		return Vector2.ZERO
	var muzzle_world: Vector3 = snapshot["world_origin"]
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var muzzle_plane := Plane(world.global_basis.y.normalized(), muzzle_world)
	var target_variant: Variant = muzzle_plane.intersects_ray(ray_origin, ray_direction)
	if not target_variant is Vector3:
		return Vector2.ZERO
	var delta_local := world.to_local(target_variant as Vector3) - world.to_local(muzzle_world)
	var direction := Vector2(delta_local.x, delta_local.z)
	# Inside the muzzle's projected screen pixel the ray has no stable heading.
	# Keep the last valid direction instead of snapping to an arbitrary axis.
	return direction.normalized() if direction.length_squared() > 0.0001 else last_aim_direction

func get_constrained_aim_position() -> Vector2:
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("get_gameplay_aim_position"):
		return world.call("get_gameplay_aim_position")
	return get_global_mouse_position()


func _exit_tree() -> void:
	_cancel_tactical_plan()
	_cancel_throw_aim()
	_cancel_dash_aim()
	cancel_dash()
	_cancel_reload_visual()
	_cancel_vault()

	if (
		lucille_character_tween != null
		and lucille_character_tween.is_valid()
	):
		lucille_character_tween.kill()

	if (
		lucille_trail_tween != null
		and lucille_trail_tween.is_valid()
	):
		lucille_trail_tween.kill()



func get_weapon_cooldown_progress() -> float:
	if selected_weapon_id.is_empty():
		return clampf(
			1.0
			- punch_cooldown_left
			/ maxf(runtime_config.player_punch_interval, 0.001),
			0.0,
			1.0
		)

	var weapon := get_active_weapon()
	if weapon == null:
		return 1.0
	if weapon.has_method("get_cooldown_progress"):
		return clampf(float(weapon.get_cooldown_progress()), 0.0, 1.0)
	return 1.0


func can_current_weapon_fire_for_target() -> bool:
	## Read-only firing eligibility used by target presentation.  Do not consume
	## ammo or mutate cooldown state here: the actual weapon attack remains the
	## sole authority for firing.
	if (
		dead
		or not attacking_enabled
		or external_knockback_left > 0.0
		or dashing
		or airborne_knockback
		or knockback_recovery_left > 0.0
		or punch_active
		or kick_active
	):
		return false
	if selected_weapon_id.is_empty():
		return punch_cooldown_left <= 0.0
	var weapon := get_active_weapon()
	if weapon == null or not bool(weapon.get("active")):
		return false
	if weapon.has_method("get_cooldown_progress") and float(weapon.get_cooldown_progress()) < 0.999:
		return false
	if weapon_uses_ammo(selected_weapon_id):
		var state: Dictionary = ammo_states.get(selected_weapon_id, {})
		if float(state.get("reload_left", 0.0)) > 0.0:
			return false
		if int(state.get("current", 0)) <= 0:
			return false
	return true


func apply_damage_upgrade(multiplier: float) -> void:
	acquired_damage_multiplier *= multiplier

	var weapon := get_active_weapon()

	if weapon.has_method(
		"apply_damage_upgrade"
	):
		weapon.apply_damage_upgrade(
			multiplier
		)

	else:
		weapon.damage *= multiplier


func apply_attack_speed_upgrade(multiplier: float) -> void:
	acquired_attack_speed_multiplier *= multiplier

	var weapon := get_active_weapon()

	if weapon.has_method(
		"apply_attack_speed_upgrade"
	):
		weapon.apply_attack_speed_upgrade(
			multiplier
		)

	else:
		weapon.attack_interval /= maxf(
			multiplier,
			0.01
		)


func apply_range_upgrade(pixels: float) -> void:
	acquired_range_pixels += pixels

	var weapon := get_active_weapon()

	if weapon.has_method(
		"apply_range_upgrade"
	):
		weapon.apply_range_upgrade(
			pixels
		)

	else:
		weapon.attack_range += pixels


func _draw() -> void:
	if shield_break_left > 0.0:
		for angle in range(
			0,
			360,
			45
		):
			draw_line(
				Vector2.RIGHT.rotated(
					deg_to_rad(angle)
				) * 15,
				Vector2.RIGHT.rotated(
					deg_to_rad(angle)
				) * 27,
				Color("b4d5e6"),
				2
			)

	if revive_flash_left > 0.0:
		draw_circle(
			Vector2.ZERO,
			28
			+ sin(
				revive_flash_left
				* 20.0
			) * 4,
			Color("e8c969"),
			false,
			3
		)
