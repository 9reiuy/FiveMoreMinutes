class_name EmployeeEnemy
extends CharacterBody2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONFIG := preload("res://resources/demo_config.tres")
const OUTLINE_CONTROLLER := preload("res://scripts/entities/enemy_outline_controller.gd")
const WORLD_HEALTH_BAR := preload("res://scripts/ui/player_world_health_bar.gd")
const DREAM_GUN_ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")
const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
const BODY_PART_SCENE: PackedScene = preload("res://scenes/entities/enemy_body_part.tscn")
const CORPSE_CONTACT := preload("res://scripts/entities/corpse_contact_motion.gd")
const WEAPON_POSE := preload("res://scripts/dream/dream_weapon_pose.gd")
const RANGED_WINDUP_TEXTURE: Texture2D = preload("res://art/Effects/shot.png")
const CHARGE_VISUAL_SCRIPT: Script = preload("res://scripts/dream/dream_charge_visual.gd")
const CHARGE_SEMANTIC_SHADER: Shader = preload("res://shaders/charge_semantic.gdshader")

## Employee_men_32x32.png is a 5-column, 3-row atlas.  Column one is the
## assembled reference only; runtime visuals use the separated cells below.
const EMPLOYEE_CHARACTER_ATLAS: Texture2D = preload("res://art/Dream/enemy/Employee_men_32x32.png")
## Waitress reuses the same separated-part layout and the same gameplay/AI
## script; only the authored visual atlas and default loadout differ.
const WAITRESS_CHARACTER_ATLAS: Texture2D = preload("res://art/Dream/enemy/waitress.png")
## The head cells carry four transparent columns on the right.  Cropping those
## columns also removes the two stray edge pixels that are not present in the
## column-one assembled reference, keeping the idle composite pixel-aligned.
const EMPLOYEE_HEAD_OPEN_REGION: Rect2 = Rect2(32, 0, 28, 32)
const EMPLOYEE_HEAD_BLINK_REGION: Rect2 = Rect2(32, 32, 28, 32)
const EMPLOYEE_HEAD_CLOSED_REGION: Rect2 = Rect2(32, 64, 28, 32)
const EMPLOYEE_BODY_REGION: Rect2 = Rect2(64, 0, 32, 32)
## The opaque foot components are at x=12..15 and x=17..20 in column four.
const EMPLOYEE_LEFT_FOOT_REGION: Rect2 = Rect2(108, 12, 4, 9)
const EMPLOYEE_RIGHT_FOOT_REGION: Rect2 = Rect2(113, 12, 4, 9)
## The opaque hand components are at x=6..10 and x=21..25 in column five.
const EMPLOYEE_LEFT_HAND_REGION: Rect2 = Rect2(134, 15, 5, 4)
const EMPLOYEE_RIGHT_HAND_REGION: Rect2 = Rect2(149, 15, 5, 4)

const EMOJI_NEUTRAL := preload("res://art/icon/emoji/Emoji_Face_Neutral.png")
const EMOJI_HIT := preload("res://art/icon/emoji/Emoji_Face_Surprised_Shocked.png")
const EMOJI_FLEE := preload("res://art/icon/emoji/Emoji_Face_Sad_Frown.png")
const EMOJI_ATTACK := preload("res://art/icon/emoji/Emoji_Face_Angry_Anger.png")
const EMOJI_KNOCKED_DOWN := preload("res://art/icon/emoji/Emoji_Face_Sleeping_Tired.png")

## Emitted for death/room lifecycle consumers.  The legacy reward count is
## retained in the signal signature for old scene/test compatibility, but the
## formal runtime no longer consumes it as an XP reward.
signal defeated(
	at_position: Vector2,
	experience_drop_count: int
)

signal weapon_drop_requested(
	weapon_id: String,
	at_position: Vector2,
	impulse: Vector2,
	skin_index: int
)

enum State {
	NEUTRAL_WANDER,
	ALERT,
	SEEK_WEAPON,
	FLEE,
	INVESTIGATE_GUNSHOT,
	ATTACK_PLAYER,
	MOVE_TO_DOOR,
	ROOM_TRANSIT,
	KNOCKED_DOWN,
	GETTING_UP
}

@export var movement_speed := 100.0
## Legacy serialized compatibility field.  XP is no longer part of the formal
## enemy runtime; existing listeners may still receive the historical value.
@export var experience_drop_count := 1

@onready var character_visual: Node2D = $CharacterVisual
@onready var left_leg: Sprite2D = $CharacterVisual/LeftFoot
@onready var right_leg: Sprite2D = $CharacterVisual/RightFoot
@onready var body_pivot: Node2D = $CharacterVisual/BodyPivot
@onready var head: Sprite2D = $CharacterVisual/BodyPivot/Head
@onready var body: Sprite2D = $CharacterVisual/BodyPivot/Body
@onready var left_hand: Sprite2D = $CharacterVisual/BodyPivot/LeftHand
@onready var right_hand: Sprite2D = $CharacterVisual/BodyPivot/RightHand

@onready var weapon_root: Node2D = $WeaponRoot
@onready var weapon_motion: Node2D = $WeaponRoot/WeaponMotion
@onready var melee_trail: Line2D = $WeaponRoot/MeleeTrail
@onready var reload_visual_pivot: Node2D = $WeaponRoot/WeaponMotion/ReloadVisualPivot
@onready var held_weapon_sprite: Sprite2D = $WeaponRoot/WeaponMotion/ReloadVisualPivot/HeldWeaponSprite
@onready var projectile_origin: Marker2D = $WeaponRoot/WeaponMotion/ProjectileOrigin

@onready var shadow: Sprite2D = $Shadow
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var emoji_sprite: Sprite2D = $EmojiAnchor/EmojiSprite

var ranged_charge_visual: AnimatedSprite2D
var ranged_charge_visual_frame_count: int = 1

var target: Node2D

## All enemies in OTXO-style CQB use formal visual perception (120° FOV & LOS).
var uses_visual_perception: bool = true
var lkp_search_time_left: float = 0.0
var door_kick_cooldown_left: float = 0.0

## Formal target-awareness state. Bosses populate this through the sampled
## perception layer; ordinary Employees populate the same cache through their
## direct room-awareness path. Combat consumers therefore keep one data flow.
var can_see_target: bool = false
var has_last_known_target_position: bool = false
var last_known_target_position := Vector2.ZERO
var last_known_target_velocity := Vector2.ZERO
var last_known_room: int = -1
var perception_update_left: float = 0.0
var last_facing_direction := Vector2.RIGHT
## A ranged enemy may briefly fire through an open doorway, but must then
## commit to physically following a discovered target into the next room.
var cross_room_engage_elapsed := 0.0
const CROSS_ROOM_ENGAGE_SECONDS := 0.65

var arena_bounds := Rect2(
	96,
	40,
	448,
	280
)
## Full room rectangle used as a safety boundary. arena_bounds remains the
## tighter wander/spawn region; this boundary also covers normal movement and
## offscreen room simulation without blocking the legal door transit state.
var room_bounds := arena_bounds

var current_health := 10.0
var maximum_health := 10.0
var contact_damage := 0.0

var dead := false
var hostile := false
var boss_variant := false

var state := State.NEUTRAL_WANDER

var held_weapon_id := ""
var held_weapon_skin_index := 0
@export var enemy_archetype: StringName = &"employee"
var feedback_config: DemoConfig

var movement_speed_multiplier := 1.0

var knockback_velocity := Vector2.ZERO
var knockback_left := 0.0

var wander_target := Vector2.ZERO
var authored_patrol_route: Array[Vector2] = []
var authored_patrol_index := 0
var wander_wait_left := 0.0
var neutral_room_travel_cooldown_left: float = 0.0
var gunshot_flee_left: float = 0.0
var gunshot_recovery_left: float = 0.0
var gunshot_threat_position := Vector2.ZERO
var gunshot_source_room_id := -1
var gunshot_investigate_left: float = 0.0
## One panic event gets one counterattack roll.  It is reset only after the
## employee leaves panic or a later, distinct room event begins.
var panic_decision_room_id := -1
var panic_counterattack_active := false

var unarmed_attack_active := false
var unarmed_attack_elapsed: float = 0.0
var unarmed_attack_hit_applied := false
var unarmed_attack_kind: StringName = &""
var next_punch_left := true
var unarmed_attack_left := true

var search_left := 0.0
var pickup_pause_left := 0.0
var attack_cooldown_left := 0.0
## Ranged weapons have an explicit per-shot stationary windup.  This is kept
## separate from pickup_pause_left so melee and empty-hand attacks remain
## immediate and a cancelled windup never consumes a shot/cooldown.
var ranged_attack_windup_left: float = 0.0
var ranged_attack_windup_pending: bool = false
var ranged_attack_target_snapshot := Vector2.ZERO
## Automatic firearms keep one windup for a continuous attack session; the
## normal per-weapon cooldown controls subsequent bullets.
var ranged_attack_session_active: bool = false
var ranged_attack_session_weapon_id: String = ""
var reaction_left := 0.0
var burst_reset_left := 0.0
var burst_shot_count := 0

var weapon_target: WorldWeaponPickup
var weapon_target_room_id := -1
## Set while the world has queued this Enemy's soft pickup request.  The
## actual inventory transfer is committed by the world arbitration pass so a
## Player E interaction in the same tick always wins deterministically.
var weapon_pickup_request_pending := false

var route_target_room_id := -1
var route_direction: StringName = &""
var route_approach_point := Vector2.ZERO
var route_transit_point := Vector2.ZERO
var door_hold_time_left: float = 0.0
var door_hold_active: bool = false
var route_exit_point := Vector2.ZERO
## A Room->Corridor->Room connection can span multiple gameplay cells.  The
## transit state follows these authored ground waypoints instead of jumping
## from the first door socket directly to the destination room.
var route_exit_waypoints: Array[Vector2] = []
var route_exit_waypoint_index := 0
var transit_exiting := false
## A grant is required before an Enemy may enter ROOM_TRANSIT.  Merely reaching
## the approach point never opens or crosses a physical door.
var door_transit_granted := false
var door_transit_id := -1
## MOVE_TO_DOOR/ROOM_TRANSIT保留开始寻路时的步行或奔跑意图。
## Neutral跨房走路，Hostile/Flee/Seek Weapon跨房奔跑。
var route_run_mode := false

var room_runtime_active := true
var room_preview_visible := false
var player_vision_visible := true

## Encounter enemies enter from above without becoming invisible ground colliders.
## Gameplay global_position remains the authored floor position; only the formal
## fake-height visual carrier moves until the landing frame restores interaction.
var sky_drop_active := false
var sky_drop_delay_left := 0.0
var sky_drop_height := 0.0
var sky_drop_vertical_velocity := 0.0
var sky_drop_gravity := 520.0
var sky_drop_saved_collision_layer := 0
var sky_drop_saved_collision_mask := 0
var sky_drop_saved_body_disabled := false
var sky_drop_saved_hurtbox_disabled := false
var sky_drop_saved_hurtbox_monitorable := true

var decision_cooldown_left := 0.0
var _last_hands_visible: int = -1
var steering_commit_left := 0.0
var steering_waypoint := Vector2.ZERO

var separation_strength := 24.0
var separation_radius := 30.0
var separation_query_left := 0.0
var cached_separation_velocity := Vector2.ZERO
## Reused across separation ticks so crowded rooms do not allocate a new
## CircleShape2D + PhysicsShapeQueryParameters2D every 0.16s per enemy.
var _separation_shape: CircleShape2D
var _separation_query: PhysicsShapeQueryParameters2D
var _los_query: PhysicsRayQueryParameters2D

var strafe_sign := 1.0
var strafe_time_left := 0.0

var stuck_elapsed := 0.0
var stuck_anchor := Vector2.ZERO
## True only when the current ATTACK_PLAYER tick has an actual reposition/chase
## intent.  A ranged windup or an intentional in-range firing pause must not be
## mistaken for a doorway stall.
var attack_movement_intent := false

var previous_room_id := -1

var current_ammo := 0
var magazine_capacity := 0
var reload_left := 0.0
var reload_visual_tween: Tween

var walk_phase := 0.0
var facing_back := false
var enemy_head_frames: Array[Texture2D] = []
var enemy_head_frame_index := 0
var enemy_blink_time_left := 3.0
var enemy_blink_phase_left := 0.0
var enemy_blink_phase := 0

## Short visual-only melee swing state.  Damage and hit timing remain in the
## existing Enemy combat pipeline; this state only drives the new parts.
var melee_visual_active := false
var melee_visual_elapsed: float = 0.0
var melee_visual_duration: float = 0.24
var melee_visual_weapon_id: String = ""
var melee_visual_direction := Vector2.RIGHT

# ============================================================
# 步行动画
# ============================================================

# CharacterBody2D / CollisionShape2D / Shadow保持真实地面位置。
# 只有视觉和WeaponRoot进行上下蹦跳。
const WALK_BOUNCE_HEIGHT := 2.0
const WALK_BODY_BOB_HEIGHT := 0.45

var weapon_root_base_position := Vector2.ZERO

var hit_flash_left := 0.0
var hit_scale_left := 0.0
var last_body_impact_sfx_msec := -1000000
var last_environment_impact_sfx_msec := -1000000

var auto_aim_locked := false

var outline_controller: EnemyOutlineController
var health_bar: PlayerWorldHealthBar

var random := RandomNumberGenerator.new()

var visual_tween: Tween
var knockdown_visual_tween: Tween

var knockdown_left := 0.0
var knockdown_rotation_target := 0.0

var state_before_knockdown := State.NEUTRAL_WANDER
var observed_state := State.NEUTRAL_WANDER

var emoji_time_left := 0.0
var emoji_priority := 0
var neutral_emoji_cooldown := 0.0

var last_hit_feedback_msec := -100000

var base_visual_scale := Vector2.ONE

var left_leg_base_position := Vector2.ZERO
var right_leg_base_position := Vector2.ZERO
var body_pivot_base_position := Vector2.ZERO
var head_base_position := Vector2.ZERO
var body_base_position := Vector2.ZERO
var left_hand_base_position := Vector2.ZERO
var right_hand_base_position := Vector2.ZERO
var character_visual_base_position := Vector2.ZERO

# ============================================================
# 击倒 / 击飞物理
# ============================================================

var knockdown_height: float = 0.0
var knockdown_vertical_velocity: float = 0.0

var knockdown_airborne: bool = false
var knockdown_inertia_active: bool = false
var knockdown_settled: bool = false

const KNOCKDOWN_FORCE_TO_HORIZONTAL_SPEED := 0.25
const KNOCKDOWN_MIN_HORIZONTAL_SPEED := 70.0
const KNOCKDOWN_MAX_HORIZONTAL_SPEED := 320.0

const KNOCKDOWN_FORCE_TO_VERTICAL_SPEED := 0.12
const KNOCKDOWN_MIN_VERTICAL_SPEED := 60.0
const KNOCKDOWN_MAX_VERTICAL_SPEED := 155.0

const KNOCKDOWN_GRAVITY := 420.0

const KNOCKDOWN_AIR_DRAG := 55.0
const KNOCKDOWN_GROUND_DRAG := 180.0

const KNOCKDOWN_WALL_BOUNCE_RETENTION := 0.68
# ============================================================
# 击退 / 击飞时的房间边界
#
# 门洞在正常状态必须保持可通行。
# 只有正在被击退 / 击飞的Enemy才临时受此边界限制，
# 防止从门洞被打出当前房间。
# ============================================================

const KNOCKBACK_ROOM_BOUNDARY_MARGIN := 10.0
# ============================================================
# 被击飞敌人撞其他敌人
# ============================================================

const KNOCKDOWN_ENEMY_IMPACT_MIN_SPEED := 70.0
const KNOCKDOWN_ENEMY_TRANSFER_RETENTION := 0.72
const KNOCKDOWN_ENEMY_SOURCE_RETENTION := 0.58
const KNOCKDOWN_ENEMY_COLLISION_COOLDOWN := 0.18

var enemy_body_collision_cooldown_left := 0.0

const KNOCKDOWN_GROUND_VERTICAL_RETENTION := 0.48
const KNOCKDOWN_GROUND_HORIZONTAL_RETENTION := 0.74
const KNOCKDOWN_MIN_BOUNCE_VERTICAL_SPEED := 18.0
const KNOCKDOWN_SETTLE_HORIZONTAL_SPEED := 14.0
const KNOCKDOWN_ROTATION_SPEED := 4.25

var secondary_collision_cooldown_left := 0.0

## 最近一次有效伤害的死亡冲击，死亡时由四个完整身体部件继承。
var death_burst_direction := Vector2.RIGHT
var death_burst_force := 160.0
var death_burst_source: StringName = &"fallback"
var death_presentation_left := 0.0
var death_vertical_speed := 0.0
var death_ground_velocity := Vector2.ZERO
var death_dismember := false
var death_landed := false
## Immediate impact blood and the delayed death plasma are separate events.
## The former must never suppress the latter.
var impact_blood_spawned := false
var death_plasma_spawned := false
var death_pool_spawned := false
var death_origin_gameplay_position := Vector2.ZERO
var death_origin_room_id: int = -1
var corpse_bleed_spawned := false
var corpse_linger_duration := 15.0
var corpse_darken_duration := 3.0
var corpse_target_brightness := 0.5
var corpse_elapsed_time := 0.0

# ============================================================
# 暴力迪吧风格布偶物理 (Madness Combat Ragdoll Wobble & Physics)
# ============================================================
var ragdoll_active := false
var corpse_spin := 0.0
var _corpse_motion_query: PhysicsShapeQueryParameters2D
var corpse_contact: Area2D
var ragdoll_left_hand_pos := Vector2.ZERO
var ragdoll_left_hand_vel := Vector2.ZERO
var ragdoll_left_hand_rot := 0.0
var ragdoll_left_hand_rot_vel := 0.0

var ragdoll_right_hand_pos := Vector2.ZERO
var ragdoll_right_hand_vel := Vector2.ZERO
var ragdoll_right_hand_rot := 0.0
var ragdoll_right_hand_rot_vel := 0.0

var ragdoll_head_pos := Vector2.ZERO
var ragdoll_head_vel := Vector2.ZERO
var ragdoll_head_rot := 0.0
var ragdoll_head_rot_vel := 0.0

var ragdoll_left_foot_pos := Vector2.ZERO
var ragdoll_left_foot_vel := Vector2.ZERO
var ragdoll_left_foot_rot := 0.0
var ragdoll_left_foot_rot_vel := 0.0

var ragdoll_right_foot_pos := Vector2.ZERO
var ragdoll_right_foot_vel := Vector2.ZERO
var ragdoll_right_foot_rot := 0.0
var ragdoll_right_foot_rot_vel := 0.0

var ragdoll_body_pivot_pos := Vector2.ZERO
var ragdoll_body_pivot_vel := Vector2.ZERO
var ragdoll_body_pivot_rot := 0.0
var ragdoll_body_pivot_rot_vel := 0.0

# ============================================================
# 流血拖痕
# ============================================================

var bleeding_trail_left: float = 0.0
var bleeding_trail_interval_left: float = 0.0
var bleeding_trail_last_position := Vector2.ZERO

const BLEEDING_TRAIL_DURATION := 15.0
const BLEEDING_TRAIL_DISTANCE := 4.0
const BLEEDING_TRAIL_MIN_INTERVAL := 0.10


func _ready() -> void:
	random.randomize()
	_schedule_perception_update()

	_setup_character_parts()
	# Player and Employee share the same authored visual scale.  This is applied
	# only to CharacterVisual; the CharacterBody2D and all gameplay colliders stay
	# at their existing dimensions.
	base_visual_scale = Vector2.ONE * float(CONFIG.player_visual_scale)
	character_visual.scale = base_visual_scale

	left_leg_base_position = left_leg.position
	right_leg_base_position = right_leg.position
	body_pivot_base_position = body_pivot.position
	head_base_position = head.position
	body_base_position = body.position
	left_hand_base_position = left_hand.position
	right_hand_base_position = right_hand.position

	character_visual_base_position = character_visual.position
	weapon_root_base_position = weapon_root.position

	_setup_health_bar()

	outline_controller = OUTLINE_CONTROLLER.new()
	outline_controller.name = "EnemyOutlineController"

	add_child(outline_controller)

	outline_controller.configure_many([
		left_leg,
		right_leg,
		head,
		body,
		left_hand,
		right_hand
	])

	_set_back_facing(false)
	_set_enemy_head_frame(0)
	enemy_blink_time_left = _get_next_enemy_blink_delay()

	held_weapon_sprite.hide()
	left_hand.show()
	right_hand.show()
	emoji_sprite.hide()

	neutral_emoji_cooldown = random.randf_range(
		4.0,
		8.0
	)
	neutral_room_travel_cooldown_left = random.randf_range(
		2.0,
		5.0
	)

	wander_target = global_position
	stuck_anchor = global_position


func _make_employee_atlas_texture(region: Rect2) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = WAITRESS_CHARACTER_ATLAS if enemy_archetype == &"waitress" else EMPLOYEE_CHARACTER_ATLAS
	texture.region = region
	return texture


func configure_archetype(archetype: StringName) -> void:
	## Archetype changes are visual/loadout configuration only.  All movement,
	## perception, damage and death authority remains EmployeeEnemy.
	enemy_archetype = &"waitress" if archetype == &"waitress" else &"employee"
	if is_node_ready():
		_setup_character_parts()
		_set_enemy_head_frame(0)


func _setup_character_parts() -> void:
	## Keep all alignment in unscaled local coordinates.  The atlas regions
	## below are derived from the opaque pixels in the 32px cells; the scene
	## positions then line them up with column-one's assembled reference.
	var head_open: AtlasTexture = _make_employee_atlas_texture(
		EMPLOYEE_HEAD_OPEN_REGION
	)
	var head_blink: AtlasTexture = _make_employee_atlas_texture(
		EMPLOYEE_HEAD_BLINK_REGION
	)
	var head_closed: AtlasTexture = _make_employee_atlas_texture(
		EMPLOYEE_HEAD_CLOSED_REGION
	)
	enemy_head_frames.clear()
	enemy_head_frames.append(head_open)
	enemy_head_frames.append(head_blink)
	enemy_head_frames.append(head_closed)

	head.texture = head_open
	body.texture = _make_employee_atlas_texture(EMPLOYEE_BODY_REGION)
	left_leg.texture = _make_employee_atlas_texture(EMPLOYEE_LEFT_FOOT_REGION)
	right_leg.texture = _make_employee_atlas_texture(EMPLOYEE_RIGHT_FOOT_REGION)
	left_hand.texture = _make_employee_atlas_texture(EMPLOYEE_LEFT_HAND_REGION)
	right_hand.texture = _make_employee_atlas_texture(EMPLOYEE_RIGHT_HAND_REGION)

	for part in [left_leg, right_leg, head, body, left_hand, right_hand]:
		part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		part.centered = false


func _set_enemy_head_frame(frame_index: int) -> void:
	if enemy_head_frames.is_empty():
		return
	if dead:
		# Death owns the face state.  Facing/animation updates must never reopen
		# the eyes while the corpse presentation is still on screen.
		frame_index = 2
	enemy_head_frame_index = clampi(
		frame_index,
		0,
		enemy_head_frames.size() - 1
	)
	head.texture = enemy_head_frames[enemy_head_frame_index]


func _get_next_enemy_blink_delay() -> float:
	return random.randf_range(2.0, 6.0)


func _update_enemy_blink(delta: float) -> void:
	if dead:
		enemy_blink_phase = 0
		enemy_blink_phase_left = 0.0
		_set_enemy_head_frame(2)
		enemy_blink_time_left = maxf(enemy_blink_time_left, 0.25)
		return
	var blink_blocked: bool = (
		state in [State.KNOCKED_DOWN, State.GETTING_UP]
		or not character_visual.visible
	)
	if blink_blocked:
		enemy_blink_phase = 0
		enemy_blink_phase_left = 0.0
		_set_enemy_head_frame(0)
		enemy_blink_time_left = maxf(enemy_blink_time_left, 0.25)
		return

	if enemy_blink_phase == 0:
		enemy_blink_time_left = maxf(enemy_blink_time_left - delta, 0.0)
		if enemy_blink_time_left > 0.0:
			return
		enemy_blink_phase = 1
		enemy_blink_phase_left = 0.06
		_set_enemy_head_frame(1)
		return

	enemy_blink_phase_left = maxf(enemy_blink_phase_left - delta, 0.0)
	if enemy_blink_phase_left > 0.0:
		return

	if enemy_blink_phase == 1:
		enemy_blink_phase = 2
		enemy_blink_phase_left = 0.06
		_set_enemy_head_frame(2)
	else:
		enemy_blink_phase = 0
		_set_enemy_head_frame(0)
		enemy_blink_time_left = _get_next_enemy_blink_delay()


func _sync_enemy_hands_visibility() -> void:
	var hands_visible: bool = held_weapon_id.is_empty() or dead
	var vis_i := 1 if hands_visible else 0
	if vis_i == _last_hands_visible:
		return
	_last_hands_visible = vis_i
	left_hand.visible = hands_visible
	right_hand.visible = hands_visible


func configure(
	new_target: Node2D,
	health: float,
	_damage: float,
	bounds: Rect2,
	new_separation_strength: float,
	new_separation_radius: float,
	config: DemoConfig = null
) -> void:
	target = new_target
	feedback_config = config
	# configure() is also the ordinary-enemy initialization path.  Boss setup
	# calls configure_boss(true) immediately afterwards and opts back in.
	boss_variant = false
	uses_visual_perception = true
	can_see_target = false
	has_last_known_target_position = false
	last_known_target_position = Vector2.ZERO
	last_known_target_velocity = Vector2.ZERO
	last_known_room = -1
	cross_room_engage_elapsed = 0.0
	_schedule_perception_update()

	maximum_health = maxf(
		health,
		1.0
	)

	current_health = maximum_health
	impact_blood_spawned = false
	death_plasma_spawned = false
	death_pool_spawned = false
	death_origin_gameplay_position = Vector2.ZERO
	death_origin_room_id = -1
	corpse_bleed_spawned = false
	corpse_elapsed_time = 0.0
	modulate = Color.WHITE

	arena_bounds = bounds

	movement_speed = (
		config.employee_movement_speed
		if config != null
		else movement_speed
	)
	if config != null:
		base_visual_scale = Vector2.ONE * float(config.player_visual_scale)
		character_visual.scale = base_visual_scale

	separation_strength = maxf(
		new_separation_strength,
		0.0
	)

	separation_radius = maxf(
		new_separation_radius,
		1.0
	)

	separation_query_left = random.randf_range(
		0.0,
		0.16
	)

	if health_bar != null and config != null:
		health_bar.configure_values(
			minf(
				config.enemy_hp_bar_width,
				20.0
			),
			config.enemy_hp_bar_height,
			Vector2(0, 7),
			current_health,
			maximum_health
		)


func configure_boss(enabled: bool) -> void:
	boss_variant = enabled
	uses_visual_perception = enabled
	# Boss behavior/health remains distinct, but all EmployeeEnemy instances use
	# the same authored CharacterVisual scale as the Player.  Do not let a boss
	# setup call introduce a second visual-size baseline.
	character_visual.scale = base_visual_scale

	hostile = true
	_begin_hostile_reaction()
	state = State.ALERT


func _can_use_flee_behavior() -> bool:
	# EmployeeEnemy is shared by ordinary civilians and the Boss.  Keep the
	# FLEE implementation for the latter, but make ordinary employees unable to
	# enter or remain in that state.
	return boss_variant


func _process(delta: float) -> void:
	if dead:
		_cancel_ranged_attack_windup()
		_update_death_presentation(delta, false)
		return
	if sky_drop_active:
		_cancel_ranged_attack_windup()
		_update_sky_drop(delta)
		return
	attack_cooldown_left = maxf(
		0.0,
		attack_cooldown_left - delta
	)

	reaction_left = maxf(
		0.0,
		reaction_left - delta
	)

	burst_reset_left = maxf(
		0.0,
		burst_reset_left - delta
	)

	if burst_reset_left <= 0.0:
		burst_shot_count = 0

	search_left = maxf(
		0.0,
		search_left - delta
	)

	pickup_pause_left = maxf(
		0.0,
		pickup_pause_left - delta
	)

	decision_cooldown_left = maxf(
		0.0,
		decision_cooldown_left - delta
	)

	neutral_room_travel_cooldown_left = maxf(
		0.0,
		neutral_room_travel_cooldown_left - delta
	)
	gunshot_flee_left = maxf(
		0.0,
		gunshot_flee_left - delta
	)
	gunshot_recovery_left = maxf(
		0.0,
		gunshot_recovery_left - delta
	)
	# The existing investigation window measures searching, not time spent
	# opening/traversing a real door toward the recorded sound position.
	if not state in [State.MOVE_TO_DOOR, State.ROOM_TRANSIT]:
		gunshot_investigate_left = maxf(0.0, gunshot_investigate_left - delta)

	steering_commit_left = maxf(
		0.0,
		steering_commit_left - delta
	)

	strafe_time_left = maxf(
		0.0,
		strafe_time_left - delta
	)

	secondary_collision_cooldown_left = maxf(
		0.0,
		secondary_collision_cooldown_left - delta
	)

	enemy_body_collision_cooldown_left = maxf(
		0.0,
		enemy_body_collision_cooldown_left - delta
	)

	_update_reload(delta)
	_update_knockdown_state(delta)
	_update_unarmed_counterattack(delta)

	hit_flash_left = maxf(
		0.0,
		hit_flash_left - delta
	)

	hit_scale_left = maxf(
		0.0,
		hit_scale_left - delta
	)

	if outline_controller != null:
		var duration := (
			feedback_config.enemy_hit_flash_seconds
			if feedback_config != null
			else 0.08
		)

		outline_controller.set_flash(
			hit_flash_left
			/ maxf(
				duration,
				0.001
			)
		)

	# Crowd CPU: blink/emoji/aim presentation can share alternate frames when
	# many employees are active; locomotion/AI stay on physics.
	var visual_tick := ((Engine.get_process_frames() + get_instance_id()) & 1) == 0
	_update_human_animation(delta)
	if visual_tick:
		_update_enemy_blink(delta)
		_update_emoji(delta)
		_update_state_emoji()
		_update_weapon_aim()
	_update_bleeding_trail(delta)


func _start_bleeding_trail() -> void:
	if dead:
		return

	bleeding_trail_left = BLEEDING_TRAIL_DURATION
	bleeding_trail_interval_left = 0.0
	bleeding_trail_last_position = global_position


func _update_bleeding_trail(delta: float) -> void:
	if dead or bleeding_trail_left <= 0.0:
		return

	bleeding_trail_left = maxf(
		0.0,
		bleeding_trail_left - delta
	)

	bleeding_trail_interval_left = maxf(
		0.0,
		bleeding_trail_interval_left - delta
	)

	if bleeding_trail_left <= 0.0:
		return

	var moved_distance: float = global_position.distance_to(
		bleeding_trail_last_position
	)

	if moved_distance < BLEEDING_TRAIL_DISTANCE:
		return

	if bleeding_trail_interval_left > 0.0:
		return

	var world := _get_world()

	if (
		world != null
		and world.has_method("spawn_blood_trail")
	):
		world.spawn_blood_trail(
			global_position,
			int(get_meta(&"dream_room_id", -1))
		)

	bleeding_trail_last_position = global_position
	bleeding_trail_interval_left = BLEEDING_TRAIL_MIN_INTERVAL


func _physics_process(delta: float) -> void:
	if dead:
		_update_death_motion(delta)
		return
	if sky_drop_active:
		velocity = Vector2.ZERO
		return

	# Knockback/knockdown is an authoritative physical state and must keep
	# running even when the Player target is freed (for example during a scene
	# teardown) or temporarily unavailable.  Target validity only gates the
	# perception/AI branch below; it must never short-circuit recovery.
	var target_valid := is_instance_valid(target)
	if target_valid:
		_update_target_perception_clock(delta)

	# ============================================================
	# 普通击退 / 真正击飞惯性
	#
	# 门洞在正常状态下是开放的，
	# 但击退状态绝不允许Enemy被推出当前房间。
	# ============================================================

	if _process_knockback(delta):
		move_and_slide()

		if get_slide_collision_count() > 0:
			_handle_knockback_collisions()

		# 即使门洞没有真实碰撞体，
		# 击退中的Enemy也会被当前房间arena_bounds拦住。
		_constrain_knockback_to_room_bounds()

		return

	# With no valid target there is no target-dependent AI to advance.  The
	# physical branch above has already handled active knockback and the _process
	# callback continues the visual knockdown timer/get-up tween.
	if not target_valid:
		_cancel_ranged_attack_windup()
		velocity = Vector2.ZERO
		return
	if state != State.ATTACK_PLAYER and ranged_attack_session_active:
		# Leaving the attack intent ends an automatic weapon's continuous fire
		# session.  A later attack intent must earn a fresh windup.
		_cancel_ranged_attack_windup()

	if not ranged_attack_windup_pending:
		_update_local_separation(delta)

	match state:
		State.NEUTRAL_WANDER:
			_update_neutral_wander(delta)

		State.ALERT:
			_choose_hostile_action()

		State.SEEK_WEAPON:
			_update_seek_weapon()

		State.FLEE:
			_update_flee()

		State.INVESTIGATE_GUNSHOT:
			_update_investigate_gunshot()

		State.ATTACK_PLAYER:
			_update_attack_player(delta)

		State.MOVE_TO_DOOR:
			_update_move_to_door()

		State.ROOM_TRANSIT:
			_update_room_transit()

		State.KNOCKED_DOWN, State.GETTING_UP:
			velocity = Vector2.ZERO

	# Windup owns the final movement composition for the whole pending attack;
	# separation/navigation code must not be able to reintroduce a slide after
	# the initial zeroing above.
	if ranged_attack_windup_pending and not _is_otxo_mode():
		velocity = Vector2.ZERO

	move_and_slide()
	_constrain_position_to_room_bounds()

	# In OTXO, enemies push or kick doors to pass through.
	door_kick_cooldown_left = maxf(door_kick_cooldown_left - delta, 0.0)
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider != null and collider.is_in_group(&"physical_doors"):
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
				var is_boss: bool = door_node.get("is_boss_door") == true
				if not is_locked and not is_destroyed and not is_boss:
					var push_dir: Vector2 = -collision.get_normal()
					if push_dir.length_squared() > 0.001:
						var leaf_idx: int = int(collider.get("leaf_index")) if collider.get("leaf_index") != null else -1
						var contact_point := Vector3(global_position.x / 32.0, 1.5, global_position.y / 32.0)
						var push_dir_3d := Vector3(push_dir.x, 0.0, push_dir.y).normalized()
						if door_kick_cooldown_left <= 0.0 and (hostile or state in [State.ATTACK_PLAYER, State.MOVE_TO_DOOR]):
							door_kick_cooldown_left = 0.6
							door_node.call("apply_door_impact", &"kick", contact_point, push_dir_3d, 450.0, &"", leaf_idx)
						else:
							door_node.call("apply_door_impact", &"enemy_push", contact_point, push_dir_3d, 220.0, &"", leaf_idx)
						break

	_update_stuck_detection(delta)


func _perception_update_interval() -> float:
	return clampf(
		_cfg("employee_vision_update_interval", 0.16),
		0.05,
		0.5
	)


func _schedule_perception_update() -> void:
	# Give each Enemy a stable phase so a crowded room does not raycast all
	# perception candidates on the same physics frame.
	var interval := _perception_update_interval()
	var phase_slot := int(_steering_identity() % 17)
	perception_update_left = interval * float(phase_slot) / 17.0


func _steering_identity() -> int:
	# A/B fixtures may replay the first generated instance's identity, because
	# allocator order is not seeded. Ordinary gameplay retains its exact ID rule.
	return int(get_meta(&"test_steering_identity", get_instance_id()))


func _update_target_perception_clock(delta: float) -> void:
	if not uses_visual_perception:
		_update_direct_target_awareness()
		return
	perception_update_left -= delta
	if perception_update_left > 0.0:
		return
	_update_visual_target_perception()
	perception_update_left = _perception_update_interval()


func _update_direct_target_awareness() -> void:
	## Ordinary Employees do not have visual discovery constraints.  While their
	## room simulation is active, the valid Player target is an authoritative
	## gameplay fact: cache its current ground position and room for the normal
	## chase/attack pipeline.  This path deliberately performs no FOV or LOS
	## query; projectile collision remains authoritative in the projectile world.
	if (
		dead
		or not room_runtime_active
		or state in [State.KNOCKED_DOWN, State.GETTING_UP]
		or not is_instance_valid(target)
		or target.get("dead") == true
	):
		can_see_target = false
		has_last_known_target_position = false
		return

	var candidate_position: Vector2 = target.global_position
	if not candidate_position.is_finite():
		can_see_target = false
		has_last_known_target_position = false
		return

	var room_id := last_known_room
	var player_room := -1
	var world := _get_world()
	if world != null and world.has_method("get_current_room_id"):
		player_room = int(world.call("get_current_room_id"))
		room_id = player_room
	var my_room := int(get_meta(&"dream_room_id", -1))
	if my_room >= 0 and player_room >= 0 and my_room != player_room:
		var openly_connected := false
		if world != null and world.has_method("are_rooms_openly_connected"):
			openly_connected = bool(world.call("are_rooms_openly_connected", my_room, player_room))
		if not openly_connected:
			if not hostile or state in [State.NEUTRAL_WANDER, State.ALERT]:
				can_see_target = false
				return
	_remember_target_position(candidate_position, room_id)
	can_see_target = true

	# Direct room awareness is also the ordinary Employee's discovery event.
	# Do not disturb an already active flee/attack/route state; only promote a
	# neutral actor once so the existing hostile decision pipeline takes over.
	if not hostile:
		hostile = true
		_begin_hostile_reaction()
		state = State.ALERT


func _update_visual_target_perception() -> void:
	# Keep this guard even for direct/internal callers (debug fixtures and older
	# integrations may invoke the named method explicitly). Ordinary Employees
	# must never fall through to the FOV/LOS ray implementation.
	if not uses_visual_perception:
		_update_direct_target_awareness()
		return
	if (
		dead
		or not is_instance_valid(target)
		or state in [State.KNOCKED_DOWN, State.GETTING_UP]
	):
		can_see_target = false
		return
	if target.get("dead") == true:
		can_see_target = false
		return

	# This is the only normal gameplay path allowed to sample the Player's
	# live position.  Every combat consumer below reads the cached result.
	var candidate_position: Vector2 = target.global_position
	var candidate_velocity := Vector2.ZERO
	if target is CharacterBody2D:
		candidate_velocity = (target as CharacterBody2D).velocity
	var offset := candidate_position - global_position
	var distance := offset.length()
	var visible := distance <= _cfg("employee_vision_range", 320.0)

	if visible and distance > 0.001:
		var facing := _get_gameplay_facing_direction()
		var half_fov := deg_to_rad(
			_cfg("employee_vision_fov_degrees", 140.0) * 0.5
		)
		visible = facing.dot(offset / distance) >= cos(half_fov)

	if visible:
		visible = _has_target_line_of_sight(candidate_position)

	var was_visible := can_see_target
	can_see_target = visible
	if not visible:
		return

	var room_id := last_known_room
	var world := _get_world()
	if world != null and world.has_method("get_current_room_id"):
		# This room lookup is part of the same bounded perception sample as the
		# candidate position; hostile chase never calls it continuously.
		room_id = int(world.call("get_current_room_id"))
	_remember_target_position(candidate_position, room_id, candidate_velocity)

	if not was_visible and not hostile:
		# Visual discovery is the only new neutral->hostile path.  Existing
		# damage, boss, and panic events remain immediate event-driven awareness.
		hostile = true
		panic_counterattack_active = false
		_begin_hostile_reaction()
		state = State.ALERT


func _has_target_line_of_sight(candidate_position: Vector2) -> bool:
	var world := _get_world()
	# The project-wide fallback is the authoritative wall/door bit (bit value 4).
	# Never include Player, Enemy, Furniture or the actor-only air-wall bits in a
	# perception ray; the world adapter may provide its dynamic wall/door mask.
	var mask := 4
	if world != null and world.has_method("get_vision_occluder_collision_mask"):
		mask = int(world.call("get_vision_occluder_collision_mask"))
	if mask <= 0:
		return false

	var space_state := get_world_2d().direct_space_state
	if _los_query == null:
		_los_query = PhysicsRayQueryParameters2D.new()
		_los_query.collide_with_bodies = true
		_los_query.collide_with_areas = false
	_los_query.from = global_position
	_los_query.to = candidate_position
	_los_query.collision_mask = mask
	var excludes: Array[RID] = []
	if self is CollisionObject2D:
		excludes.append(get_rid())
	_los_query.exclude = excludes

	for _i in range(5):
		var hit := space_state.intersect_ray(_los_query)
		if hit.is_empty():
			return true
		var collider: Object = hit.get("collider", null)
		if collider is Node and (collider.is_in_group(&"glass_windows") or collider.is_in_group(&"breakable_glass_windows")):
			excludes.append(hit.get("rid"))
			_los_query.exclude = excludes
			continue
		return false
	return false


func _get_gameplay_facing_direction() -> Vector2:
	var direction := last_facing_direction
	if melee_visual_active and melee_visual_direction.length_squared() > 0.001:
		direction = melee_visual_direction.normalized()
	elif held_weapon_id != "" and weapon_root != null:
		direction = Vector2.RIGHT.rotated(weapon_root.rotation)
	elif velocity.length_squared() > 0.001:
		direction = velocity.normalized()
	elif character_visual != null and absf(character_visual.scale.x) > 0.001:
		direction = Vector2.LEFT if character_visual.scale.x < 0.0 else Vector2.RIGHT
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	last_facing_direction = direction.normalized()
	return last_facing_direction


func _remember_target_position(
	position: Vector2,
	room_id: int = -1,
	velocity_snapshot: Vector2 = Vector2.ZERO
) -> void:
	if not position.is_finite():
		return
	last_known_target_position = position
	last_known_target_velocity = velocity_snapshot if velocity_snapshot.is_finite() else Vector2.ZERO
	has_last_known_target_position = true
	if room_id >= 0:
		last_known_room = room_id


func _has_known_target() -> bool:
	return has_last_known_target_position and last_known_target_position.is_finite()


func _get_known_target_position() -> Vector2:
	return last_known_target_position if _has_known_target() else global_position


func set_room_bounds(bounds: Rect2) -> void:
	room_bounds = bounds
	arena_bounds = bounds


func _uses_continuous_ground_collision() -> bool:
	var world := _get_world()
	if world == null or not world.has_method("sync_employee_ground_region"):
		return false
	# In the continuous building the swept wall/door collision is authoritative.
	# Room metadata may follow movement; it must never pull an actor back.
	if state != State.ROOM_TRANSIT:
		world.call("sync_employee_ground_region", self)
	return true


func constrain_to_room_bounds() -> void:
	_constrain_position_to_room_bounds()


func _constrain_position_to_room_bounds() -> void:
	if _uses_continuous_ground_collision():
		return
	if dead or state == State.ROOM_TRANSIT or room_bounds.size.x <= 1.0 or room_bounds.size.y <= 1.0:
		return
	var safe_bounds := room_bounds.grow(-4.0)
	var corrected := global_position
	var normal := Vector2.ZERO
	if corrected.x < safe_bounds.position.x:
		corrected.x = safe_bounds.position.x
		normal.x = 1.0
	elif corrected.x > safe_bounds.end.x:
		corrected.x = safe_bounds.end.x
		normal.x = -1.0
	if corrected.y < safe_bounds.position.y:
		corrected.y = safe_bounds.position.y
		normal.y = 1.0
	elif corrected.y > safe_bounds.end.y:
		corrected.y = safe_bounds.end.y
		normal.y = -1.0
	if normal == Vector2.ZERO:
		return
	global_position = corrected
	if velocity.dot(normal) < 0.0:
		velocity = velocity.bounce(normal) * KNOCKDOWN_WALL_BOUNCE_RETENTION
	if knockback_velocity.dot(normal) < 0.0:
		knockback_velocity = knockback_velocity.bounce(normal) * KNOCKDOWN_WALL_BOUNCE_RETENTION

func _update_neutral_wander(delta: float) -> void:
	if global_position.distance_to(wander_target) <= 8.0:
		velocity = _with_local_separation(
			Vector2.ZERO
		)

		wander_wait_left -= delta

		if wander_wait_left <= 0.0:
			if authored_patrol_route.is_empty() and _try_begin_neutral_room_travel():
				return
			wander_target = _request_wander_target()

			wander_wait_left = random.randf_range(
				_cfg(
					"employee_wander_pause_min",
					0.35
				),
				_cfg(
					"employee_wander_pause_max",
					0.85
				)
			)

		return

	velocity = _steer_toward(
		wander_target
	)


func _try_begin_neutral_room_travel() -> bool:
	if neutral_room_travel_cooldown_left > 0.0 or gunshot_recovery_left > 0.0:
		return false
	if random.randf() > _cfg("employee_room_travel_chance", 0.18):
		return false
	var world := _get_world()
	if world == null or not world.has_method("get_employee_roam_route"):
		return false
	var route: Dictionary = world.get_employee_roam_route(self)
	if route.is_empty():
		return false
	var target_room := int(route.get("room_id", -1))
	var direction := StringName(route.get("direction", &""))
	if target_room < 0 or direction.is_empty():
		return false
	_begin_route_to_room(target_room, direction)
	if state != State.MOVE_TO_DOOR:
		return false
	neutral_room_travel_cooldown_left = random.randf_range(
		_cfg("employee_room_travel_cooldown_min", 4.0),
		_cfg("employee_room_travel_cooldown_max", 8.0)
	)
	return true


func set_authored_patrol_route(waypoints: Array[Vector2]) -> void:
	authored_patrol_route = waypoints.duplicate()
	authored_patrol_index = 0
	if not authored_patrol_route.is_empty() and state == State.NEUTRAL_WANDER:
		wander_target = _request_wander_target()


func _request_wander_target() -> Vector2:
	if not authored_patrol_route.is_empty():
		var waypoint := authored_patrol_route[authored_patrol_index % authored_patrol_route.size()]
		authored_patrol_index += 1
		return waypoint
	var world := _get_world()

	if (
		world != null
		and world.has_method("get_employee_wander_target")
	):
		return world.get_employee_wander_target(self)

	return Vector2(
		random.randf_range(
			arena_bounds.position.x,
			arena_bounds.end.x
		),
		random.randf_range(
			arena_bounds.position.y,
			arena_bounds.end.y
		)
	)


func _choose_hostile_action() -> void:
	if decision_cooldown_left > 0.0:
		# Keep an unarmed ordinary Employee in a bounded search retry instead of
		# oscillating ALERT <-> SEEK_WEAPON every physics frame.
		velocity = Vector2.ZERO
		return
	if not held_weapon_id.is_empty():
		_release_weapon_reservation()
		state = State.ATTACK_PLAYER
		return

	if _refresh_weapon_plan():
		return

	if _can_use_flee_behavior():
		state = State.FLEE
		show_emoji(
			&"flee",
			1.1,
			3
		)
		return

	# Ordinary employees never flee.  With no weapon plan available they remain
	# in the existing weapon-search path and can retry when a pickup appears.
	gunshot_flee_left = 0.0
	state = State.SEEK_WEAPON
	search_left = maxf(search_left, _cfg("employee_weapon_search_interval", 0.30))
	decision_cooldown_left = maxf(decision_cooldown_left, search_left)


func _begin_hostile_reaction() -> void:
	var minimum := _cfg(
		"employee_reaction_time_min",
		0.20
	)
	var maximum := maxf(
		minimum,
		_cfg(
			"employee_reaction_time_max",
			0.40
		)
	)
	reaction_left = random.randf_range(
		minimum,
		maximum
	)
	# Reaction与现有攻击冷却共用门槛，确保首次交火绝不在同一帧发生。
	attack_cooldown_left = maxf(
		attack_cooldown_left,
		reaction_left
	)


func _update_seek_weapon() -> void:
	if not _weapon_target_is_valid():
		_release_weapon_reservation()
		state = State.ALERT
		return

	var my_room := int(
		get_meta(
			&"dream_room_id",
			-1
		)
	)

	if weapon_target_room_id != my_room:
		var world := _get_world()
		var openly_connected := false
		if world != null and world.has_method("are_rooms_openly_connected"):
			openly_connected = bool(world.call("are_rooms_openly_connected", my_room, weapon_target_room_id))
		if not openly_connected:
			_begin_route_to_room(
				weapon_target_room_id
			)
			return

	if (
		global_position.distance_to(
			weapon_target.global_position
		)
		<= _cfg(
			"employee_weapon_pickup_radius",
			28.0
		)
	):
		_collect_weapon(
			weapon_target
		)
		return

	velocity = _steer_toward(
		weapon_target.global_position
	)


func _update_flee() -> void:
	if not _can_use_flee_behavior():
		# Defensive recovery for stale saves/queued transitions: ordinary
		# employees must never execute the flee route even if an older state was
		# already serialized before this capability split.
		gunshot_flee_left = 0.0
		gunshot_source_room_id = -1
		panic_decision_room_id = -1
		panic_counterattack_active = false
		velocity = Vector2.ZERO
		if not held_weapon_id.is_empty():
			state = State.ATTACK_PLAYER
		elif hostile:
			state = State.SEEK_WEAPON
			search_left = maxf(search_left, _cfg("employee_weapon_search_interval", 0.30))
		else:
			state = State.NEUTRAL_WANDER
		return
	# A local gunshot is a room threat, not an aggro event.  Resolve an authored
	# connected door first; only use an in-room escape point when no door exists.
	if gunshot_flee_left > 0.0 and not hostile:
		var threat_world := _get_world()
		if (
			decision_cooldown_left <= 0.0
			and threat_world != null
			and threat_world.has_method("get_employee_flee_route")
		):
			var flee_route: Dictionary = threat_world.get_employee_flee_route(
				self,
				previous_room_id,
				gunshot_threat_position
			)
			if not flee_route.is_empty():
				decision_cooldown_left = _cfg("employee_decision_cooldown", 0.42)
				_begin_route_to_room(
					int(flee_route.get("room_id", -1)),
					StringName(flee_route.get("direction", &""))
				)
				if state == State.MOVE_TO_DOOR:
					return
		var away := gunshot_threat_position.direction_to(global_position)
		if away.length_squared() <= 0.001:
			away = Vector2.RIGHT
		var escape_target := global_position + away.normalized() * _cfg("employee_flee_distance", 120.0)
		if threat_world != null and threat_world.has_method("get_employee_escape_target"):
			escape_target = threat_world.get_employee_escape_target(self, away)
		velocity = _steer_toward(escape_target)
		return
	if not hostile and gunshot_source_room_id >= 0 and gunshot_flee_left <= 0.0:
		gunshot_source_room_id = -1
		panic_decision_room_id = -1
		panic_counterattack_active = false
		state = State.NEUTRAL_WANDER
		wander_target = _request_wander_target()
		wander_wait_left = 0.4
		velocity = Vector2.ZERO
		return

	if search_left <= 0.0:
		search_left = _cfg(
			"employee_weapon_search_interval",
			0.30
		)

		if _refresh_weapon_plan():
			return

	var world := _get_world()

	if (
		decision_cooldown_left <= 0.0
		and world != null
		and world.has_method("get_employee_flee_route")
	):
		var flee_route: Dictionary = (
			world.get_employee_flee_route(
				self,
				previous_room_id
			)
		)

		if not flee_route.is_empty():
			decision_cooldown_left = _cfg(
				"employee_decision_cooldown",
				0.42
			)

			_begin_route_to_room(
				int(
					flee_route.get(
						"room_id",
						-1
					)
				),
				StringName(
					flee_route.get(
						"direction",
						&""
					)
				)
			)

			return

	var away := _get_known_target_position().direction_to(
		global_position
	)

	if away.length_squared() < 0.001:
		away = Vector2.RIGHT

	velocity = _steer_toward(
		global_position
		+ away.normalized()
		* _cfg(
			"employee_flee_distance",
			120.0
		)
	)


func _update_investigate_gunshot() -> void:
	# Armed neutral employees investigate the recorded sound position without
	# receiving a combat target.  Detection/hostile logic remains the only way
	# they learn the Player's exact position.
	if held_weapon_id.is_empty() or gunshot_investigate_left <= 0.0:
		gunshot_investigate_left = 0.0
		gunshot_source_room_id = -1
		panic_decision_room_id = -1
		state = State.NEUTRAL_WANDER
		wander_target = _request_wander_target()
		wander_wait_left = 0.35
		velocity = Vector2.ZERO
		return
	var my_room := int(get_meta(&"dream_room_id", -1))
	if gunshot_source_room_id >= 0 and gunshot_source_room_id != my_room:
		var world := _get_world()
		var openly_connected := false
		if world != null and world.has_method("are_rooms_openly_connected"):
			openly_connected = bool(world.call("are_rooms_openly_connected", my_room, gunshot_source_room_id))
		if not openly_connected:
			_begin_route_to_room(gunshot_source_room_id)
			return
	if global_position.distance_to(gunshot_threat_position) <= 16.0:
		gunshot_investigate_left = 0.0
		gunshot_source_room_id = -1
		panic_decision_room_id = -1
		state = State.NEUTRAL_WANDER
		wander_target = _request_wander_target()
		wander_wait_left = 0.35
		velocity = Vector2.ZERO
		return
	velocity = _steer_toward(gunshot_threat_position)


func _body_collision_radius(body: Node2D) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null or shape_node.disabled:
		return 0.0
	var bounds := shape_node.shape.get_rect()
	var shape_scale := shape_node.global_scale
	return maxf(
		bounds.size.x * absf(shape_scale.x),
		bounds.size.y * absf(shape_scale.y)
	) * 0.5


func _minimum_player_center_distance() -> float:
	# The existing body layers are the hard anti-overlap fallback.  Keep combat
	# steering outside that contact radius so two 32px character visuals do not
	# spend the fight pressed together while still remaining inside melee reach.
	var physical_contact := _body_collision_radius(self) + _body_collision_radius(target) + 2.0
	return maxf(physical_contact, separation_radius)


func _update_attack_player(delta: float) -> void:
	attack_movement_intent = false
	if ranged_attack_windup_pending and not _is_otxo_mode():
		_update_ranged_attack_windup(delta)
		return
	# A hostile Enemy may only consume the last position published by the
	# perception layer.  If no position is known yet (for example a boss spawned
	# behind a wall), it must wait for a valid visual sample.
	if not _has_known_target():
		velocity = Vector2.ZERO
		return

	var target_position := _get_known_target_position()
	var my_room := int(get_meta(&"dream_room_id", -1))
	if ranged_attack_session_active and (
		ranged_attack_session_weapon_id != held_weapon_id
		or not _weapon_requires_ranged_windup()
	):
		_cancel_ranged_attack_windup()
	var distance_to_target := global_position.distance_to(target_position)
	var target_in_another_room := last_known_room >= 0 and my_room >= 0 and last_known_room != my_room
	if target_in_another_room:
		var world := _get_world()
		var openly_connected := false
		if world != null and world.has_method("are_rooms_openly_connected"):
			openly_connected = bool(world.call("are_rooms_openly_connected", my_room, last_known_room))
		if not openly_connected:
			# Preserve a short ranged response through an open doorway, then enter it.
			# The destination remains the room captured by perception, never a fresh
			# query of the Player's position after line of sight is lost.
			var can_engage_cross_room := can_see_target and not held_weapon_id.is_empty() and distance_to_target <= _weapon_max_range()
			if can_engage_cross_room:
				cross_room_engage_elapsed += delta
			if not can_engage_cross_room or cross_room_engage_elapsed >= CROSS_ROOM_ENGAGE_SECONDS:
				_cancel_ranged_attack_windup()
				_begin_route_to_room(last_known_room)
				return
		else:
			cross_room_engage_elapsed = 0.0
	else:
		cross_room_engage_elapsed = 0.0

	if not can_see_target:
		_cancel_ranged_attack_windup()
		# Lost LOS: search only the remembered ground position.  Do not fire or
		# perform melee damage until a later perception sample reacquires Player.
		if global_position.distance_to(target_position) > 10.0:
			attack_movement_intent = true
			velocity = _steer_toward(target_position)
			lkp_search_time_left = 2.0
		else:
			velocity = Vector2.ZERO
			lkp_search_time_left -= delta
			if lkp_search_time_left > 0.0:
				var sweep_angle := sin(lkp_search_time_left * PI * 2.0) * deg_to_rad(45.0)
				last_facing_direction = (target_position - global_position).normalized().rotated(sweep_angle)
				if last_facing_direction.length_squared() < 0.01:
					last_facing_direction = Vector2.RIGHT.rotated(sweep_angle)
				_set_back_facing(last_facing_direction.y < -0.2)
				if character_visual != null:
					character_visual.scale.x = absf(base_visual_scale.x) * (-1.0 if last_facing_direction.x < -0.2 else 1.0)
			else:
				lkp_search_time_left = 0.0
				has_last_known_target_position = false
				hostile = false
				state = State.NEUTRAL_WANDER
				wander_target = _request_wander_target()
				wander_wait_left = 1.0
		return

	if held_weapon_id.is_empty():
		_cancel_ranged_attack_windup()
		if not panic_counterattack_active or not is_instance_valid(target):
			state = State.ALERT
			velocity = Vector2.ZERO
			return
		var unarmed_range := _cfg("employee_unarmed_attack_range", 30.0)
		var distance_to_player := global_position.distance_to(target_position)
		if distance_to_player > unarmed_range:
			attack_movement_intent = true
			velocity = _steer_toward(target_position)
			return
		velocity = Vector2.ZERO
		if attack_cooldown_left <= 0.0 and reaction_left <= 0.0 and not unarmed_attack_active:
			_start_unarmed_counterattack()
		return

	var distance := distance_to_target
	if ranged_attack_session_active and distance > _weapon_max_range():
		_cancel_ranged_attack_windup()

	var desired_range := _weapon_desired_range()
	var shot_world := _get_world()
	if held_weapon_id not in ["lucille", "books"] and shot_world != null and shot_world.has_method("is_furniture_shot_path_clear"):
		if not shot_world.call("is_furniture_shot_path_clear", get_projectile_origin(), target_position, self):
			_cancel_ranged_attack_windup()
			attack_movement_intent = true
			velocity = _steer_toward(target_position)
			return

	if strafe_time_left <= 0.0:
		strafe_sign = (
			-1.0
			if random.randi() % 2 == 0
			else 1.0
		)

		strafe_time_left = random.randf_range(
			_cfg(
				"employee_attack_strafe_min_seconds",
				0.55
			),
			_cfg(
				"employee_attack_strafe_max_seconds",
				1.20
			)
		)

	var toward := global_position.direction_to(
		target_position
	)

	var tangent := toward.orthogonal() * strafe_sign

	var move_direction := tangent

	if _weapon_is_melee():
		# Melee pressure stops at the existing separation perimeter.  The previous
		# branch kept a 65% inward component even inside attack range, continuously
		# driving the Enemy into the Player body until only the tiny foot colliders
		# separated their centres.
		var minimum_center_distance := _minimum_player_center_distance()
		var melee_hold_range := minf(
			maxf(desired_range, minimum_center_distance),
			maxf(_weapon_max_range() - 2.0, minimum_center_distance)
		)
		var melee_engage_range := maxf(
			melee_hold_range,
			_weapon_max_range() * 0.90
		)
		if distance > melee_engage_range:
			move_direction = (
				toward
				+ tangent * 0.12
			).normalized()
		elif distance < minimum_center_distance:
			move_direction = (
				-toward
				+ tangent * 0.15
			).normalized()
		else:
			var melee_radial_correction := clampf(
				(distance - melee_hold_range) / maxf(melee_hold_range, 1.0),
				-0.25,
				0.25
			)
			move_direction = (tangent + toward * melee_radial_correction).normalized()

	elif _is_otxo_mode() and (reload_left > 0.0 or current_ammo <= 0) and not _weapon_is_melee():
		# OTXO Tactical Action: Retreat & create distance while reloading
		steering_commit_left = 0.0
		move_direction = (-toward * 0.85 + tangent * 0.40).normalized()

	elif distance > desired_range * 1.15:
		move_direction = (
			toward
			+ tangent * 0.25
		).normalized()

	elif (
		distance < desired_range * 0.55
	):
		move_direction = (
			-toward
			+ tangent * 0.3
		).normalized()

	else:
		var radial_correction := clampf(
			(
				distance - desired_range
			)
			/ maxf(
				desired_range,
				1.0
			),
			-0.35,
			0.35
		)

		move_direction = (
			tangent
			+ toward * radial_correction
		).normalized()

	var attack_destination := global_position + move_direction * maxf(desired_range, 48.0)
	attack_movement_intent = attack_destination.distance_to(global_position) > 8.0
	velocity = _steer_toward(attack_destination)

	if (
		attack_cooldown_left <= 0.0
		and reaction_left <= 0.0
		and reload_left <= 0.0
		and pickup_pause_left <= 0.0
		and distance <= _weapon_max_range()
	):
		if not _is_otxo_mode() and _weapon_requires_ranged_windup():
			if not ranged_attack_session_active:
				_begin_ranged_attack_windup()
				return
			# Automatic firearms stay in the same attack session after the
			# first windup; their ordinary cooldown governs each next shot.
			_fire_held_weapon()
			if not DREAM_GUN_ATLAS.is_automatic_weapon(held_weapon_id):
				ranged_attack_session_active = false
			return
		_cancel_ranged_attack_windup()
		_fire_held_weapon()


func _weapon_requires_ranged_windup() -> bool:
	# The current registry classifies every weapon that spawns projectiles as a
	# firearm.  Keep this query in one place so a future ranged category can be
	# added without spreading weapon-id checks through the windup state.
	return not held_weapon_id.is_empty() and DREAM_GUN_ATLAS.has_firearm(held_weapon_id)


func _begin_ranged_attack_windup() -> void:
	if (
		dead
		or ranged_attack_windup_pending
		or attack_cooldown_left > 0.0
		or not _weapon_requires_ranged_windup()
	):
		return
	ranged_attack_windup_pending = true
	ranged_attack_session_active = true
	var default_windup: float = 0.25 if held_weapon_id == "assault_rifle" else (0.35 if held_weapon_id == "shotgun" else 0.20)
	ranged_attack_windup_left = clampf(_cfg("employee_ranged_attack_windup", default_windup), 0.0, 5.0)
	ranged_attack_target_snapshot = _get_known_target_position()
	velocity = Vector2.ZERO
	_show_ranged_charge_visual()


func _update_ranged_attack_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	if (
		dead
		or state != State.ATTACK_PLAYER
		or not is_instance_valid(target)
		or not can_see_target
		or not _has_known_target()
		or not _weapon_requires_ranged_windup()
		or reload_left > 0.0
		or pickup_pause_left > 0.0
	):
		_cancel_ranged_attack_windup()
		return
	var target_position: Vector2 = _get_known_target_position()
	if global_position.distance_to(target_position) > _weapon_max_range():
		_cancel_ranged_attack_windup()
		return
	ranged_attack_target_snapshot = target_position
	ranged_attack_windup_left = maxf(ranged_attack_windup_left - delta, 0.0)
	if ranged_attack_windup_left > 0.0:
		return
	ranged_attack_windup_pending = false
	ranged_attack_target_snapshot = Vector2.ZERO
	_hide_ranged_charge_visual()
	_fire_held_weapon()
	if not DREAM_GUN_ATLAS.is_automatic_weapon(ranged_attack_session_weapon_id):
		ranged_attack_session_active = false
		ranged_attack_session_weapon_id = ""


func _cancel_ranged_attack_windup() -> void:
	ranged_attack_windup_left = 0.0
	ranged_attack_windup_pending = false
	ranged_attack_target_snapshot = Vector2.ZERO
	ranged_attack_session_active = false
	ranged_attack_session_weapon_id = ""
	_hide_ranged_charge_visual()


func _ensure_ranged_charge_visual() -> void:
	if ranged_charge_visual != null and is_instance_valid(ranged_charge_visual):
		return
	ranged_charge_visual = get_node_or_null(
		"WeaponRoot/WeaponMotion/RangedChargeVisual"
	) as AnimatedSprite2D
	if ranged_charge_visual == null:
		ranged_charge_visual = AnimatedSprite2D.new()
		ranged_charge_visual.name = "RangedChargeVisual"
		ranged_charge_visual.position = Vector2(11.0, 0.0)
		ranged_charge_visual.z_index = 2
		ranged_charge_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		weapon_motion.add_child(ranged_charge_visual)
	if ranged_charge_visual == null or not is_instance_valid(ranged_charge_visual):
		return
	ranged_charge_visual_frame_count = int(CHARGE_VISUAL_SCRIPT.call(
		"configure",
		ranged_charge_visual,
		RANGED_WINDUP_TEXTURE,
		_cfg("employee_ranged_windup_animation_fps", 12.0),
		Color(1.0, 0.12, 0.08, 1.0),
		false
	))
	# Keep the 2D source itself on the same reserved semantic path as the 3D
	# auxiliary carrier.  This matters for the legacy 2D Dream, where no
	# Sprite3D bridge exists to replace the final Palette pass.
	var charge_semantic_material := ShaderMaterial.new()
	charge_semantic_material.shader = CHARGE_SEMANTIC_SHADER
	charge_semantic_material.set_shader_parameter(
		&"semantic_color",
		Color(1.0, 0.0, 0.0, 1.0)
	)
	ranged_charge_visual.material = charge_semantic_material
	ranged_charge_visual.set_meta(&"depth_visual_unlit", true)
	# The enemy windup is a presentation semantic, not an ordinary red sprite:
	# the 3D auxiliary bridge and the final palette pass both use this marker to
	# keep the charge colour independent from room lighting and palette lookup.
	ranged_charge_visual.set_meta(&"depth_visual_charge_semantic", true)
	_ensure_unlit_ranged_charge_bridge()


func _ensure_unlit_ranged_charge_bridge() -> void:
	var world := _get_world()
	if (
		world != null
		and world.has_method("ensure_unlit_actor_visual_bridge")
		and ranged_charge_visual != null
	):
		world.call(
			"ensure_unlit_actor_visual_bridge",
			self,
			NodePath("WeaponRoot/WeaponMotion/RangedChargeVisual")
		)


func _show_ranged_charge_visual() -> void:
	_ensure_ranged_charge_visual()
	if ranged_charge_visual == null or not is_instance_valid(ranged_charge_visual):
		return
	ranged_charge_visual.animation = &"charge"
	ranged_charge_visual.frame = 0
	ranged_charge_visual.speed_scale = 1.0
	ranged_charge_visual.play()
	ranged_charge_visual.show()
	_ensure_unlit_ranged_charge_bridge()


func _hide_ranged_charge_visual() -> void:
	if ranged_charge_visual == null or not is_instance_valid(ranged_charge_visual):
		return
	ranged_charge_visual.stop()
	ranged_charge_visual.animation = &"charge"
	ranged_charge_visual.frame = 0
	ranged_charge_visual.hide()


func _start_unarmed_counterattack() -> void:
	if dead or not panic_counterattack_active or held_weapon_id != "":
		return
	unarmed_attack_active = true
	unarmed_attack_elapsed = 0.0
	unarmed_attack_hit_applied = false
	# Punch is the common response; Kick remains an occasional stronger
	# counterattack and uses the existing Player knockback entry point.
	unarmed_attack_kind = &"employee_punch" if random.randf() < 0.70 else &"employee_kick"
	unarmed_attack_left = next_punch_left
	next_punch_left = not next_punch_left
	attack_cooldown_left = maxf(
		attack_cooldown_left,
		_cfg("employee_unarmed_attack_interval", 0.45)
	)
	SFX.play_event(&"melee_swing")
	show_emoji(&"attack", 0.45, 2)


func _update_unarmed_counterattack(delta: float) -> void:
	if not unarmed_attack_active:
		return
	if (
		dead
		or not panic_counterattack_active
		or not is_instance_valid(target)
		or not can_see_target
		or not _has_known_target()
	):
		unarmed_attack_active = false
		unarmed_attack_elapsed = 0.0
		unarmed_attack_kind = &""
		return
	unarmed_attack_elapsed += delta
	var duration := 0.24
	var impact_time := 0.10
	if not unarmed_attack_hit_applied and unarmed_attack_elapsed >= impact_time:
		unarmed_attack_hit_applied = true
		var attack_range := _cfg("employee_unarmed_attack_range", 30.0)
		var target_position := _get_known_target_position()
		if global_position.distance_to(target_position) <= attack_range:
			var amount_property: StringName = (
				&"employee_unarmed_kick_damage"
				if unarmed_attack_kind == &"employee_kick"
				else &"employee_unarmed_punch_damage"
			)
			var amount := _cfg(
				amount_property,
				10.0 if unarmed_attack_kind == &"employee_kick" else 6.0
			)
			var health_before: float = INF
			if target.get("current_health") != null:
				health_before = float(target.get("current_health"))
			if target.has_method("receive_damage"):
				target.receive_damage(amount, unarmed_attack_kind, global_position)
			if unarmed_attack_kind == &"employee_kick" and target.has_method("apply_external_knockback"):
				var kick_direction := global_position.direction_to(target_position)
				if kick_direction.length_squared() > 0.001:
					target.apply_external_knockback(kick_direction, _cfg("enemy_knockback_strength", 96.0) * 1.15)
			if is_instance_valid(target) and target.get("current_health") != null and float(target.get("current_health")) < health_before:
				# This branch damages the Player, so the enemy-hit clip is not the
				# right semantic cue.  Keep the existing player hurt event here.
				SFX.play_event(&"player_hurt")
	if unarmed_attack_elapsed >= duration:
		unarmed_attack_active = false
		unarmed_attack_elapsed = 0.0
		unarmed_attack_hit_applied = false
		unarmed_attack_kind = &""


func _begin_route_to_room(
	room_id: int,
	preferred_direction: StringName = &""
) -> void:
	var following_known_target := hostile and room_id == last_known_room and _has_known_target()
	var route_world := _get_world()
	if route_world != null and route_world.has_method("release_employee_door_transit"):
		route_world.call("release_employee_door_transit", self)
	door_transit_granted = false
	door_transit_id = -1
	if room_id < 0:
		route_run_mode = false
		state = State.ALERT
		return

	route_target_room_id = room_id

	var world := _get_world()

	var plan: Dictionary = (
		world.get_employee_door_plan(
			self,
			room_id,
			preferred_direction
		)
		if (
			world != null
			and world.has_method(
				"get_employee_door_plan"
			)
		)
		else {}
	)

	if plan.is_empty():
		route_run_mode = false
		state = State.ALERT
		return
	route_target_room_id = int(plan.get("target_room_id", room_id))
	# 记录发起这次跨房的行为类型，避免Neutral旅行被误加速，
	# 也避免Hostile/Flee/Seek Weapon在门洞中突然退回走路速度。
	route_run_mode = (
		hostile
		or gunshot_flee_left > 0.0
		or state in [State.ALERT, State.SEEK_WEAPON, State.FLEE, State.INVESTIGATE_GUNSHOT, State.ATTACK_PLAYER]
	)

	route_direction = StringName(
		plan.get(
			"direction",
			&""
		)
	)

	route_approach_point = Vector2(
		plan.get(
			"approach",
			global_position
		)
	)

	route_transit_point = Vector2(
		plan.get(
			"transit",
			route_approach_point
		)
	)
	route_exit_waypoints.clear()
	route_exit_waypoint_index = 0
	door_transit_id = int(plan.get("door_id", -1))

	transit_exiting = false

	if _is_otxo_mode() and not held_weapon_id.is_empty() and not _weapon_is_melee() and hostile and not following_known_target:
		door_hold_time_left = random.randf_range(1.5, 2.8)
		door_hold_active = true
	else:
		door_hold_time_left = 0.0
		door_hold_active = false

	decision_cooldown_left = _cfg(
		"employee_decision_cooldown",
		0.42
	)

	state = State.MOVE_TO_DOOR


func _update_move_to_door() -> void:
	var world := _get_world()

	if (
		world == null
		or route_direction.is_empty()
	):
		state = State.ALERT
		return

	if _is_otxo_mode() and door_hold_active and door_hold_time_left > 0.0 and not held_weapon_id.is_empty() and not _weapon_is_melee():
		var target_pos := _get_known_target_position()
		var distance_to_target := global_position.distance_to(target_pos) if target_pos != Vector2.ZERO else INF
		if can_see_target and is_instance_valid(target) and distance_to_target <= _weapon_max_range():
			door_hold_active = false
			door_hold_time_left = 0.0
			state = State.ATTACK_PLAYER
			return

		var distance_to_staging := global_position.distance_to(route_approach_point)
		if distance_to_staging <= 20.0:
			var p_delta: float = get_physics_process_delta_time()
			door_hold_time_left = maxf(door_hold_time_left - p_delta, 0.0)
			var door_dir := (route_transit_point - global_position).normalized()
			if door_dir.length_squared() > 0.01:
				last_facing_direction = door_dir
				_set_back_facing(last_facing_direction.y < -0.2)
				if character_visual != null:
					character_visual.scale.x = absf(base_visual_scale.x) * (-1.0 if last_facing_direction.x < -0.2 else 1.0)
			velocity = Vector2.ZERO
			if door_hold_time_left <= 0.0:
				door_hold_active = false
			return

	if (
		global_position.distance_to(
			route_approach_point
		)
		<= 7.0
	):
		# Reaching the staging point only queues a request.  The centralized world
		# registry grants one holder per doorway; waiters stay here with zero
		# velocity until their turn so bodies never push a door open implicitly.
		if not door_transit_granted:
			if world.has_method("request_employee_door_transit"):
				door_transit_granted = (world.call(
					"request_employee_door_transit",
					self,
					route_target_room_id,
					route_direction,
					door_transit_id
				) == true)
			if not door_transit_granted:
				velocity = Vector2.ZERO
				return
		state = State.ROOM_TRANSIT
		transit_exiting = false
		return

	velocity = _steer_toward(
		route_approach_point,
		false
	)


func _update_room_transit() -> void:
	if not transit_exiting and door_transit_granted:
		var passage_world := _get_world()
		if passage_world != null and passage_world.has_method("prepare_employee_door_passage"):
			if not bool(passage_world.call("prepare_employee_door_passage", door_transit_id, route_approach_point)):
				velocity = Vector2.ZERO
				return
	var destination := route_transit_point
	if transit_exiting:
		if route_exit_waypoint_index < route_exit_waypoints.size():
			destination = route_exit_waypoints[route_exit_waypoint_index]
		else:
			destination = route_exit_point

	if global_position.distance_to(destination) > 5.0:
		velocity = (
			global_position.direction_to(
				destination
			)
			* _get_current_move_speed()
		)

		return

	velocity = Vector2.ZERO

	if transit_exiting:
		if route_exit_waypoint_index < route_exit_waypoints.size():
			route_exit_waypoint_index += 1
			if route_exit_waypoint_index < route_exit_waypoints.size():
				return
			route_exit_waypoints.clear()
		route_exit_waypoint_index = 0
		on_room_transit_finished()
		return

	var world := _get_world()

	if world == null:
		state = State.ALERT
		return

	world.transfer_employee_through_door(
		self,
		route_direction,
		route_target_room_id
	)


## 只有Employee自己进入合法ROOM_TRANSIT后，DreamWorld才允许修改room_id。
## 受击/击飞会清掉该状态，避免被动位移误触发跨房。
func can_transfer_through_door(direction: StringName, target_room_id: int) -> bool:
	var world := _get_world()
	var my_room := int(get_meta(&"dream_room_id", -1))
	var openly_connected := false
	if world != null and world.has_method("are_rooms_openly_connected"):
		openly_connected = bool(world.call("are_rooms_openly_connected", my_room, target_room_id))
	return (
		not dead
		and state == State.ROOM_TRANSIT
		and not knockdown_inertia_active
		and knockback_left <= 0.0
		and route_direction == direction
		and route_target_room_id == target_room_id
		and not transit_exiting
		and (door_transit_granted or openly_connected)
		and (
			openly_connected
			or world == null
			or not world.has_method("employee_has_door_transit_grant")
			or world.call("employee_has_door_transit_grant", self, door_transit_id) == true
		)
	)


func is_door_push_intent_active() -> bool:
	# Only an explicit AI room-transit plan may ask the 3D proxy to press a
	# doorway.  Neutral wandering, combat contact and knockback never open doors
	# merely because the body happens to touch one.
	return (
		not dead
		and not knockdown_inertia_active
		and knockback_left <= 0.0
		and state == State.ROOM_TRANSIT
		and door_transit_granted
		and not route_direction.is_empty()
	)


func is_combat_displacement_active() -> bool:
	return (
		knockdown_inertia_active
		or knockback_left > 0.0
		or state in [State.KNOCKED_DOWN, State.GETTING_UP]
	)


func _cancel_room_transit_for_combat() -> void:
	var world := _get_world()
	if world != null and world.has_method("release_employee_door_transit"):
		world.call("release_employee_door_transit", self)
	door_transit_granted = false
	door_transit_id = -1
	door_hold_active = false
	door_hold_time_left = 0.0
	if state in [State.MOVE_TO_DOOR, State.ROOM_TRANSIT]:
		state = State.ALERT if hostile else State.NEUTRAL_WANDER
		transit_exiting = false
		route_target_room_id = -1
		route_direction = &""
		route_approach_point = Vector2.ZERO
		route_transit_point = Vector2.ZERO
		route_exit_point = Vector2.ZERO
		route_exit_waypoints.clear()
		route_exit_waypoint_index = 0
		route_run_mode = false
		velocity = Vector2.ZERO
	# 离屏追踪也是一种主动过门计划；受击后必须取消，不能等击退结束再继续转移。
	set_meta(&"pending_room_follow", false)
	remove_meta(&"pending_room_follow_destination")
	remove_meta(&"pending_room_follow_departure")
	remove_meta(&"offscreen_follower_avoid_waypoint")


func begin_room_exit(
	exit_point: Vector2,
	waypoints: Array[Vector2] = []
) -> void:
	if not door_transit_granted:
		return
	route_exit_point = exit_point
	route_exit_waypoints.clear()
	for waypoint in waypoints:
		route_exit_waypoints.append(waypoint)
	route_exit_waypoint_index = 0
	transit_exiting = true
	state = State.ROOM_TRANSIT


func on_room_transit_finished() -> void:
	route_run_mode = false
	route_exit_waypoints.clear()
	route_exit_waypoint_index = 0
	var world := _get_world()
	if world != null and world.has_method("finish_employee_room_transit"):
		world.finish_employee_room_transit(self)
	door_transit_granted = false
	door_transit_id = -1
	if (
		_weapon_target_is_valid()
		and int(
			get_meta(
				&"dream_room_id",
				-1
			)
		) == weapon_target_room_id
	):
		state = State.SEEK_WEAPON

	elif not hostile and gunshot_investigate_left > 0.0 and not held_weapon_id.is_empty():
		state = State.INVESTIGATE_GUNSHOT

	elif not held_weapon_id.is_empty() and hostile:
		state = State.ATTACK_PLAYER

	elif not hostile:
		# Neutral roaming resumes after a short post-travel pause.  Do not route
		# through ALERT, which is the hostile weapon-search state.
		gunshot_recovery_left = _cfg("employee_gunshot_recovery_duration", 1.25)
		gunshot_flee_left = 0.0
		gunshot_investigate_left = 0.0
		gunshot_source_room_id = -1
		panic_decision_room_id = -1
		panic_counterattack_active = false
		wander_target = global_position
		wander_wait_left = gunshot_recovery_left
		state = State.NEUTRAL_WANDER

	else:
		state = State.ALERT


func on_room_gunshot(world_position: Vector2, source_room_id: int) -> void:
	if dead or hostile or state in [State.KNOCKED_DOWN, State.GETTING_UP, State.ROOM_TRANSIT]:
		return
	var my_room := int(get_meta(&"dream_room_id", -1))
	var hearing_world := _get_world()
	var heard := my_room == source_room_id
	if not heard and hearing_world != null and hearing_world.has_method("can_employee_hear_gunshot"):
		heard = hearing_world.can_employee_hear_gunshot(self, source_room_id)
	var max_sound_dist: float = _cfg("employee_sound_hearing_range", 700.0)
	if global_position.distance_to(world_position) > max_sound_dist:
		heard = false
	if source_room_id < 0 or not heard:
		return
	if state == State.MOVE_TO_DOOR:
		_cancel_room_transit_for_combat()
	gunshot_threat_position = world_position
	gunshot_source_room_id = source_room_id
	gunshot_recovery_left = 0.0
	wander_wait_left = 0.0
	decision_cooldown_left = 0.0
	# Repeated shots refresh the active response but never re-roll the panic
	# decision.  A new roll becomes available only after this response ends.
	if panic_decision_room_id == source_room_id and state in [State.FLEE, State.INVESTIGATE_GUNSHOT, State.ATTACK_PLAYER]:
		if state == State.FLEE and _can_use_flee_behavior():
			gunshot_flee_left = maxf(gunshot_flee_left, _cfg("employee_gunshot_flee_duration", 5.0))
		elif state == State.FLEE:
			# A pre-existing ordinary FLEE state is migrated immediately to the
			# normal weapon-search path.
			gunshot_flee_left = 0.0
			state = State.SEEK_WEAPON
		elif state == State.INVESTIGATE_GUNSHOT:
			gunshot_investigate_left = maxf(gunshot_investigate_left, _cfg("employee_gunshot_investigate_duration", 2.5))
		return
	panic_decision_room_id = source_room_id
	if not held_weapon_id.is_empty():
		# Armed civilians investigate the actual sound position.  This is not an
		# aggro transition and never substitutes the Player's exact position.
		gunshot_flee_left = 0.0
		gunshot_investigate_left = _cfg("employee_gunshot_investigate_duration", 2.5)
		state = State.INVESTIGATE_GUNSHOT
		show_emoji(&"attack", 0.8, 2)
		return
	# Unarmed civilians make one panic decision: 20% counterattack, otherwise
	# stay in the ordinary weapon-search path.  Only Bosses retain flee panic.
	if random.randf() < clampf(_cfg("employee_panic_counterattack_chance", 0.20), 0.0, 1.0):
		# A panic counterattack starts from the recorded gunshot position only.
		# It does not reveal or sample the Player's live transform.
		_remember_target_position(world_position, source_room_id)
		panic_counterattack_active = true
		hostile = true
		gunshot_flee_left = 0.0
		_begin_hostile_reaction()
		state = State.ATTACK_PLAYER
		show_emoji(&"attack", 1.1, 3)
		return
	panic_counterattack_active = false
	gunshot_flee_left = 0.0
	if _can_use_flee_behavior():
		gunshot_flee_left = _cfg("employee_gunshot_flee_duration", 5.0)
		state = State.FLEE
		show_emoji(&"flee", 1.1, 3)
	else:
		state = State.SEEK_WEAPON
		search_left = maxf(search_left, _cfg("employee_weapon_search_interval", 0.30))


func collect_reserved_weapon_offscreen() -> bool:
	if not _weapon_target_is_valid():
		return false

	_collect_weapon(
		weapon_target,
		false
	)

	return true


func on_offscreen_room_arrived() -> void:
	if _refresh_weapon_plan():
		return

	var world := _get_world()

	if (
		_can_use_flee_behavior()
		and
		hostile
		and held_weapon_id.is_empty()
		and world != null
		and world.has_method(
			"queue_employee_flee_offscreen"
		)
	):
		world.queue_employee_flee_offscreen(
			self,
			previous_room_id
		)


func _refresh_weapon_plan() -> bool:
	var world := _get_world()

	if (
		world == null
		or not world.has_method(
			"claim_employee_world_weapon"
		)
	):
		return false

	var result: Dictionary = (
		world.claim_employee_world_weapon(
			self
		)
	)

	if result.is_empty():
		return false

	weapon_target = (
		result.get("pickup")
		as WorldWeaponPickup
	)
	weapon_pickup_request_pending = false

	weapon_target_room_id = int(
		result.get(
			"room_id",
			-1
		)
	)

	state = State.SEEK_WEAPON

	return is_instance_valid(
		weapon_target
	)


## Room activation hook.  A newly landed encounter weapon should be considered
## on the next AI decision window, without teleporting ownership or interrupting
## a critical attack/door/recovery state.  The world still arbitrates the soft
## reservation and gives an explicit Player pickup priority.
func prioritize_weapon_search() -> bool:
	if (
		dead
		or not room_runtime_active
		or not held_weapon_id.is_empty()
		or state in [State.KNOCKED_DOWN, State.GETTING_UP, State.ROOM_TRANSIT, State.MOVE_TO_DOOR, State.ATTACK_PLAYER]
	):
		return false
	if _weapon_target_is_valid():
		state = State.SEEK_WEAPON
		return true
	return _refresh_weapon_plan()


func _weapon_target_is_valid() -> bool:
	return (
		is_instance_valid(weapon_target)
		and weapon_target.is_inside_tree()
		and weapon_target.is_available_for(self)
	)


func _collect_weapon(
	pickup: WorldWeaponPickup,
	allow_arbitration: bool = true
) -> void:
	# In the live world, an Enemy only submits a soft request here.  The World
	# commits one winner after the Player interaction pass; this keeps explicit
	# Player E ownership independent of SceneTree callback order.  Off-screen
	# simulation and the world's commit callback pass false to perform the
	# already-authorized inventory transfer exactly once.
	if allow_arbitration:
		var world := _get_world()
		if world != null and world.has_method("request_enemy_world_weapon_pickup"):
			if world.call("request_enemy_world_weapon_pickup", self, pickup) == true:
				weapon_pickup_request_pending = true
			return
	if (
		not is_instance_valid(pickup)
		or not pickup.is_available_for(self)
	):
		weapon_pickup_request_pending = false
		state = State.ALERT
		return

	var new_weapon_id := pickup.weapon_id
	var new_skin_index := pickup.skin_index

	pickup.release_reservation(self)
	pickup.queue_free()

	weapon_target = null
	weapon_target_room_id = -1
	weapon_pickup_request_pending = false

	equip_weapon(new_weapon_id, new_skin_index)
	SFX.play_weapon_pickup()

	pickup_pause_left = _cfg(
		"employee_weapon_pickup_pause",
		0.12
	)
	pickup_pause_left *= random.randf_range(
		0.88,
		1.12
	)
	attack_cooldown_left = maxf(
		attack_cooldown_left,
		pickup_pause_left
	)

	state = State.ATTACK_PLAYER

	show_emoji(
		&"attack",
		1.0,
		2
	)


## Called only by DreamWorld after it has committed this Enemy's deterministic
## pickup request.  Keeping the public handoff here prevents callers from
## duplicating inventory/equip logic or bypassing WorldWeaponPickup ownership.
func commit_reserved_world_weapon(pickup: WorldWeaponPickup) -> void:
	weapon_pickup_request_pending = false
	_collect_weapon(pickup, false)


func equip_weapon(
	weapon_id: String,
	skin_index: int = -1
) -> void:
	_cancel_ranged_attack_windup()
	weapon_id = DREAM_GUN_ATLAS.sanitize_weapon_id(weapon_id)
	if weapon_id.is_empty():
		held_weapon_id = ""
		held_weapon_skin_index = 0
		current_ammo = 0
		magazine_capacity = 0
		reload_left = 0.0
		_finish_reload_visual()
		held_weapon_sprite.texture = null
		weapon_root.hide()
		_sync_enemy_hands_visibility()
		return

	held_weapon_id = weapon_id
	if weapon_id == "books" and skin_index >= 0:
		held_weapon_skin_index = DREAM_GUN_ATLAS.normalize_skin_index(weapon_id, skin_index)
	elif weapon_id != "books":
		held_weapon_skin_index = 0

	held_weapon_sprite.texture = (
		DREAM_GUN_ATLAS.get_held(
			weapon_id,
			held_weapon_skin_index
		)
	)

	held_weapon_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	held_weapon_sprite.position = Vector2(
		_cfg(
			"held_weapon_distance",
			11.0
		),
		0.0
	)

	held_weapon_sprite.show()
	_sync_enemy_hands_visibility()

	magazine_capacity = (
		int(
			_cfg(
				"assault_rifle_magazine_size",
				30.0
			)
		)
		if weapon_id == "assault_rifle"
		else (
			int(
				_cfg(
					"default_weapon_magazine_size",
					12.0
				)
			)
			if _weapon_uses_ammo(weapon_id)
			else 0
		)
	)

	current_ammo = magazine_capacity
	reload_left = 0.0

	_finish_reload_visual()


func _weapon_is_melee(
	weapon_id: String = held_weapon_id
) -> bool:
	return weapon_id in [
		"lucille",
		"books"
	]


func _set_attack_cooldown(base_interval: float) -> void:
	var jitter_ratio := clampf(
		_cfg(
			"employee_attack_cadence_jitter_ratio",
			0.12
		),
		0.0,
		0.4
	)
	attack_cooldown_left = maxf(
		0.03,
		base_interval * random.randf_range(
			1.0 - jitter_ratio,
			1.0 + jitter_ratio
		)
	)


func _set_weapon_attack_cooldown(base_interval: float) -> void:
	## Held weapon data is stored as seconds-per-shot.  Apply the same global
	## cadence multiplier as Player weapons; unarmed attacks stay unchanged.
	var rate_multiplier := maxf(_cfg("weapon_fire_rate_multiplier", 1.0), 0.001)
	_set_attack_cooldown(maxf(base_interval, 0.001) / rate_multiplier)


func _get_current_weapon_spread_degrees() -> float:
	var spread := _cfg(
		"employee_weapon_spread_degrees",
		12.0
	)
	var movement_ratio := clampf(
		velocity.length()
		/ maxf(
			_get_current_move_speed(),
			1.0
		),
		0.0,
		1.0
	)
	# Target motion is part of the last perception snapshot.  Do not read the
	# live Player velocity here: hostile weapon spread must not become a hidden
	# information channel after LOS is lost.
	movement_ratio = maxf(
		movement_ratio,
		clampf(
			last_known_target_velocity.length()
			/ maxf(
				_cfg(
					"player_movement_speed",
					120.0
				),
				1.0
			),
			0.0,
			1.0
		)
	)
	spread += (
		_cfg(
			"employee_movement_spread_degrees",
			10.0
		)
		* movement_ratio
	)
	spread += (
		_cfg(
			"employee_burst_spread_step_degrees",
			3.0
		)
		* float(burst_shot_count)
	)
	return clampf(
		spread,
		0.0,
		60.0
	)


func _play_enemy_gunshot() -> void:
	## 3D Random Dream supplies the authoritative gameplay→world adapter.  The
	## muzzle is still the formal 2D WeaponPose origin; SFX only consumes its
	## mapped presentation position and never writes gameplay transforms.
	var world := _get_world()
	if world != null and world.has_method("get_gameplay_world_position"):
		var muzzle_position := get_projectile_origin()
		var world_position_variant: Variant = world.call(
			"get_gameplay_world_position",
			muzzle_position
		)
		if world_position_variant is Vector3 and SFX.play_world_sfx_3d(
			&"gunshot",
			world_position_variant as Vector3
		):
			return
	# Legacy 2D Dream has no 3D world adapter, so retain its global voice.
	SFX.play_event(&"gunshot")


func _fire_held_weapon() -> void:
	# A successful or defensive fire path always owns the end of the visual
	# windup.  The pending flag is cleared by the caller before this function so
	# one cooldown can produce at most one shot.
	_hide_ranged_charge_visual()
	if (
		pickup_pause_left > 0.0
		or reload_left > 0.0
		or not is_instance_valid(target)
		or not can_see_target
		or not _has_known_target()
	):
		return

	if not _consume_ammo_for_attack():
		return

	var aim_direction := global_position.direction_to(
		_get_known_target_position()
	)

	var direction := (
		aim_direction
		if held_weapon_id in [
			"lucille",
			"books"
		]
		else FIREARM_RULES.directions(aim_direction, 1, _get_current_weapon_spread_degrees(), random)[0]
	)
	# One event per firearm attack (not per shotgun pellet).  Neutral employees
	# in this same room react to the room threat; the shooter itself is hostile.
	if DREAM_GUN_ATLAS.has_firearm(held_weapon_id):
		var world := _get_world()
		if world != null and world.has_method("notify_gunshot"):
			world.notify_gunshot(global_position, int(get_meta(&"dream_room_id", -1)))

	match held_weapon_id:
		"basic", "shotgun", "assault_rifle":
			var weapon_kind := StringName(held_weapon_id)
			var parameters := FIREARM_RULES.parameters(feedback_config, weapon_kind)
			_set_weapon_attack_cooldown(float(parameters.interval))
			for shot_direction in FIREARM_RULES.directions(direction, int(parameters.pellets), float(parameters.spread_degrees), random):
				_spawn_bullet(shot_direction, float(parameters.damage), float(parameters.range), float(parameters.speed), weapon_kind)
			_play_enemy_gunshot()
		"lucille":
			_set_weapon_attack_cooldown(_cfg(
				"lucille_attack_interval",
				0.6
			))

			_fire_lucille(direction)

		"books":
			_set_weapon_attack_cooldown(_cfg(
				"books_attack_interval",
				0.8
			))

			_fire_books(direction)

	if _weapon_is_melee():
		burst_shot_count = 0
		burst_reset_left = 0.0
	else:
		burst_shot_count = mini(
			burst_shot_count + 1,
			int(
				_cfg(
					"employee_burst_spread_max_steps",
					3.0
				)
			)
		)
		burst_reset_left = _cfg(
			"employee_burst_reset_seconds",
			0.55
		)

	var world := _get_world()

	if (
		held_weapon_id in [
			"basic",
			"shotgun",
			"assault_rifle"
		]
		and world != null
		and world.has_method(
			"spawn_weapon_muzzle"
		)
	):
		world.spawn_weapon_muzzle(
			get_projectile_origin(),
			direction,
			StringName(
				held_weapon_id
			),
			self
		)

	if (
		DREAM_GUN_ATLAS.ejects_shell(
			held_weapon_id
		)
		and world != null
		and world.has_method(
			"spawn_shell_ejection"
		)
	):
		world.spawn_shell_ejection(
			get_projectile_origin(),
			direction,
			StringName(
				held_weapon_id
			)
		)

	_play_weapon_recoil()


func _weapon_uses_ammo(
	weapon_id: String = held_weapon_id
) -> bool:
	return weapon_id in [
		"basic",
		"shotgun",
		"assault_rifle"
	]


func _consume_ammo_for_attack() -> bool:
	if not _weapon_uses_ammo():
		return true

	if reload_left > 0.0:
		return false

	if current_ammo <= 0:
		_start_reload()
		return false

	current_ammo -= 1

	if current_ammo <= 0:
		_start_reload()

	return true


func _start_reload() -> void:
	if (
		not _weapon_uses_ammo()
		or reload_left > 0.0
	):
		return

	reload_left = maxf(
		_cfg(
			"weapon_reload_duration",
			0.75
		),
		0.1
	)

	_begin_reload_visual(
		reload_left
	)
	SFX.play_weapon_reload()


func _update_reload(delta: float) -> void:
	if reload_left <= 0.0:
		return

	reload_left = maxf(
		0.0,
		reload_left - delta
	)

	if reload_left <= 0.0:
		current_ammo = magazine_capacity
		_finish_reload_visual()


func _begin_reload_visual(
	duration: float
) -> void:
	_finish_reload_visual()

	reload_visual_pivot.rotation = 0.0

	reload_visual_tween = create_tween()

	reload_visual_tween.tween_property(
		reload_visual_pivot,
		"rotation",
		TAU,
		duration
	).set_trans(
		Tween.TRANS_LINEAR
	)


func _finish_reload_visual() -> void:
	if (
		reload_visual_tween != null
		and reload_visual_tween.is_valid()
	):
		reload_visual_tween.kill()

	reload_visual_tween = null

	if reload_visual_pivot != null:
		reload_visual_pivot.rotation = 0.0


func get_projectile_origin() -> Vector2:
	if not is_inside_tree() or projectile_origin == null:
		return global_position
	var nominal_pos: Vector2 = projectile_origin.global_position
	var start_pos: Vector2 = global_position
	var space_state := get_world_2d().direct_space_state if get_world_2d() != null else null
	if space_state == null:
		return nominal_pos
	var segment := nominal_pos - start_pos
	if segment.length_squared() <= 0.01:
		return nominal_pos
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


func _spawn_bullet(
	direction: Vector2,
	damage: float,
	max_distance: float,
	speed: float,
	weapon_id: StringName = &"basic"
) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()

	projectile.global_position = get_projectile_origin()

	FIREARM_RULES.setup_projectile(
		projectile,
		direction,
		damage,
		max_distance,
		speed,
		&"enemy",
		self,
		weapon_id
	)

	var world := _get_world()
	if world != null and world.has_method("add_projectile"):
		world.add_projectile(projectile, self)
	else:
		projectile.queue_free()


func _fire_lucille(direction: Vector2) -> void:
	_fire_melee_swing(direction, "lucille")


func _fire_books(direction: Vector2) -> void:
	_fire_melee_swing(direction, "books")


func _fire_melee_swing(direction: Vector2, weapon_id: String) -> void:
	if not can_see_target or not _has_known_target():
		return
	var range_property: StringName = &"lucille_attack_range"
	var damage_property: StringName = &"lucille_damage"
	if weapon_id == "books":
		range_property = &"books_attack_range"
		damage_property = &"books_damage"
	var reach := _cfg(range_property, 20.0) + 14.0

	var target_position := _get_known_target_position()
	var melee_origin: Vector2 = projectile_origin.global_position
	if melee_origin.distance_to(target_position) > reach:
		return
	_start_enemy_melee_visual(direction, weapon_id)
	SFX.play_event(&"melee_swing")

	var health_before := float(
		target.get(
			"current_health"
		)
	)

	target.receive_damage(
		_cfg(damage_property, 30.0),
		StringName("employee_%s" % weapon_id),
		global_position
	)

	if (
		float(
			target.get(
				"current_health"
			)
		) < health_before
		and target.has_method(
			"apply_external_knockback"
		)
	):
		var force := feedback_config.get_lucille_knockback_force() if feedback_config != null else 1200.0
		if weapon_id == "books" and feedback_config != null:
			force *= feedback_config.books_knockback_multiplier

		target.apply_external_knockback(
			direction,
			force
		)
func _start_enemy_melee_visual(direction: Vector2, weapon_id: String) -> void:
	if dead:
		return
	melee_visual_active = true
	melee_visual_elapsed = 0.0
	melee_visual_duration = 0.24
	melee_visual_weapon_id = weapon_id
	melee_trail.clear_points()
	melee_trail.modulate = Color.WHITE
	melee_trail.show()
	melee_visual_direction = (
		direction.normalized()
		if direction.length_squared() > 0.001
		else Vector2.RIGHT
	)


func _update_enemy_melee_visual(delta: float, movement_blocked: bool) -> void:
	if not melee_visual_active:
		return
	if dead or movement_blocked:
		melee_visual_active = false
		melee_visual_elapsed = 0.0
		melee_visual_weapon_id = ""
		weapon_motion.rotation = 0.0
		body_pivot.rotation = 0.0
		melee_trail.visible = false
		melee_trail.clear_points()
		return

	melee_visual_elapsed += delta
	var progress: float = clampf(
		melee_visual_elapsed / maxf(melee_visual_duration, 0.001),
		0.0,
		1.0
	)
	var stage_value: float = progress * 6.0
	var stage_index: int = clampi(int(stage_value), 0, 5)
	var stage_t: float = clampf(
		stage_value - float(stage_index),
		0.0,
		1.0
	)
	var eased: float = stage_t * stage_t if stage_index == 0 else 1.0 - pow(1.0 - stage_t, 2.0)
	var angle_degrees: float
	match stage_index:
		0:
			angle_degrees = lerpf(-108.0, -96.0, eased)
		1:
			angle_degrees = lerpf(-96.0, -60.0, eased)
		2:
			angle_degrees = lerpf(-60.0, 20.0, eased)
		3:
			angle_degrees = lerpf(20.0, 104.0, eased)
		4:
			angle_degrees = lerpf(104.0, 72.0, eased)
		_:
			angle_degrees = lerpf(72.0, 0.0, eased)
	weapon_motion.rotation = deg_to_rad(angle_degrees)
	var lean_sign: float = (
		-1.0
		if melee_visual_direction.x >= 0.0
		else 1.0
	)
	body_pivot.rotation = sin(progress * PI) * deg_to_rad(5.0) * lean_sign
	var trail_radius: float = (
		_cfg("books_trail_radius", 28.0)
		if melee_visual_weapon_id == "books"
		else _cfg("lucille_trail_radius", 42.0)
	)
	melee_trail.add_point(
		Vector2(trail_radius, 0.0).rotated(weapon_motion.rotation)
		+ weapon_motion.position
	)
	while melee_trail.get_point_count() > 8:
		melee_trail.remove_point(0)
	melee_trail.modulate.a = 1.0 - progress

	if progress >= 1.0:
		melee_visual_active = false
		melee_visual_elapsed = 0.0
		melee_visual_weapon_id = ""
		weapon_motion.rotation = 0.0
		body_pivot.rotation = 0.0
		melee_trail.visible = false
		melee_trail.clear_points()


func _play_weapon_recoil() -> void:
	if (
		visual_tween != null
		and visual_tween.is_valid()
	):
		visual_tween.kill()

	weapon_motion.position = Vector2.ZERO
	weapon_motion.rotation = 0.0

	visual_tween = create_tween()

	if held_weapon_id in [
		"lucille",
		"books"
	]:
		visual_tween.tween_property(
			weapon_motion,
			"rotation",
			deg_to_rad(65.0),
			0.04
		)

		visual_tween.tween_property(
			weapon_motion,
			"rotation",
			0.0,
			0.09
		)

	else:
		visual_tween.tween_property(
			weapon_motion,
			"position:x",
			-4.0,
			0.04
		)

		visual_tween.tween_property(
			weapon_motion,
			"position:x",
			0.0,
			0.09
		)


func _update_weapon_aim() -> void:
	if held_weapon_id.is_empty():
		weapon_root.hide()
		_sync_enemy_hands_visibility()
		return

	weapon_root.show()
	## WeaponRoot is a sibling of CharacterVisual, so give it the explicit
	## foreground layer used by the rest of the actor visual.  This keeps a
	## held weapon readable without changing any collision or aim geometry.
	## Keep the weapon in the actor's Y-sort band; world furniture and Door
	## foreground must still be able to occlude it.
	weapon_root.z_index = 0
	weapon_root.show_behind_parent = false
	_sync_enemy_hands_visibility()

	# Keep a held weapon visible even during the short frames where the target is
	# unavailable (for example while a room simulation is being refreshed).  The
	# old implementation hid WeaponRoot in that case, leaving an armed Employee
	# with both the weapon and hands invisible.  Aim falls back to actual motion
	# and finally to the current horizontal facing; no gameplay state changes.
	var direction := Vector2.RIGHT
	if state == State.INVESTIGATE_GUNSHOT and gunshot_threat_position.length_squared() > 0.001:
		# Investigation points at the recorded sound position only.  The neutral
		# employee must not visually/implicitly acquire the Player through walls.
		direction = global_position.direction_to(gunshot_threat_position)
	elif hostile and _has_known_target():
		direction = global_position.direction_to(_get_known_target_position())
	elif velocity.length_squared() > 0.001:
		direction = velocity.normalized()
	elif character_visual.scale.x < 0.0:
		direction = Vector2.LEFT
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	last_facing_direction = direction.normalized()

	weapon_root.rotation = direction.angle()
	var pose: Dictionary = WEAPON_POSE.solve(
		direction,
		maxf(_cfg("held_weapon_distance", 11.0) + 3.0, 12.0),
		maxf(_cfg("held_weapon_distance", 11.0) * 0.82, 8.0),
		_cfg("held_weapon_distance", 11.0)
	)
	weapon_root.position = weapon_root_base_position + pose.get("orbit_offset", Vector2.ZERO)
	projectile_origin.position = pose.get("muzzle_local", Vector2(_cfg("held_weapon_distance", 11.0), 0.0))

	weapon_root.show_behind_parent = false

	held_weapon_sprite.flip_v = (
		direction.x < 0.0
	)


# ============================================================
# 统一受击方向
# ============================================================

func _resolve_hit_direction(
	hit_origin: Vector2,
	damage_source: StringName
) -> Vector2:
	# 玩家造成的枪弹攻击不再使用Projectile当前碰撞点。
	# 子弹有可能已经进入敌人碰撞体内部甚至越过中心，
	# 使用碰撞点会导致击退方向突然反向。
	#
	# 普通玩家枪弹统一使用：
	#
	# Player -> Enemy
	var is_thrown_weapon := String(damage_source).begins_with("player_throw")
	if (
		((_is_player_projectile_source(damage_source)
			and not is_thrown_weapon)
			or damage_source in [&"kick", &"lucille", &"books"])
		and _has_known_target()
	):
		var player_direction := (
			_get_known_target_position().direction_to(
				global_position
			)
		)

		if player_direction.length_squared() > 0.001:
			return player_direction.normalized()

	# Enemy Friendly Fire和其它来源继续使用真实hit_origin。
	if (
		is_finite(hit_origin.x)
		and is_finite(hit_origin.y)
	):
		var hit_direction := (
			hit_origin.direction_to(
				global_position
			)
		)

		if hit_direction.length_squared() > 0.001:
			return hit_direction.normalized()

	# 最终Fallback。
	if _has_known_target():
		var fallback_direction := (
			_get_known_target_position().direction_to(
				global_position
			)
		)

		if fallback_direction.length_squared() > 0.001:
			return fallback_direction.normalized()

	return Vector2.RIGHT


func _is_player_projectile_source(source: StringName) -> bool:
	var source_text := String(source)
	return (
		source_text.begins_with("player_projectile")
		or source_text.begins_with("player_throw")
	)


func _is_player_awareness_source(source: StringName) -> bool:
	return (
		_is_player_projectile_source(source)
		or String(source).begins_with("player_melee")
		or source in [
			&"kick",
			&"lucille",
			&"books",
			&"player_punch"
		]
	)


func _remember_player_damage_awareness() -> void:
	if not is_instance_valid(target):
		return
	# Damage is an event-time awareness source.  This is deliberately the only
	# non-perception combat path that samples the live target position.
	var position: Vector2 = target.global_position
	var room_id := last_known_room
	var world := _get_world()
	if world != null and world.has_method("get_current_room_id"):
		room_id = int(world.call("get_current_room_id"))
	_remember_target_position(position, room_id)


func _is_enemy_projectile_source(source: StringName) -> bool:
	return source == &"enemy_projectile" or String(source).begins_with("enemy_projectile_")


func _is_gun_damage_source(source: StringName) -> bool:
	return _is_player_projectile_source(source) or _is_enemy_projectile_source(source)


func _should_spawn_directional_blood(source: StringName) -> bool:
	return _is_gun_damage_source(source) or source in [
		&"kick",
		&"lucille",
		&"books",
		&"player_punch",
		&"employee_lucille",
		&"employee_books",
		&"furniture_impact",
		&"secondary_collision"
	]


func _blood_intensity_for_source(source: StringName) -> float:
	var source_text := String(source).to_lower()
	if source == &"lucille" or source == &"employee_lucille":
		return _cfg("blood_lucille_intensity", 1.55)
	if source == &"books" or source == &"employee_books":
		return _cfg("blood_pistol_intensity", 0.82)
	if source == &"kick":
		return _cfg("blood_kick_intensity", 0.90)
	if source == &"furniture_impact":
		return _cfg("blood_furniture_intensity", 1.05)
	if source == &"secondary_collision":
		return _cfg("blood_pistol_intensity", 0.75)
	if source == &"player_punch":
		return _cfg("blood_pistol_intensity", 0.82) * 0.5
	if source_text.contains("shotgun"):
		return _cfg("blood_shotgun_intensity", 1.45)
	if source_text.contains("assault_rifle") or source_text.contains("rifle") or source_text.contains("automatic"):
		return _cfg("blood_automatic_intensity", 0.68)
	if _is_gun_damage_source(source):
		return _cfg("blood_pistol_intensity", 0.82)
	return 1.0


func take_damage(
	amount: float,
	hit_origin: Vector2 = Vector2.INF,
	_knockback_force: float = 1.0,
	damage_source: StringName = &"player_projectile"
) -> void:
	if (
		dead
		or amount <= 0.0
		or not is_damage_runtime_active()
	):
		return

	var before := current_health

	current_health = maxf(
		0.0,
		current_health - amount
	)

	var actual := before - current_health
	if actual > 0.0:
		if not room_runtime_active:
			set_room_runtime_active(true)
			hostile = true
			state = State.ALERT
			var world := _get_world()
			var r_id: Variant = get_meta(&"dream_room_id", -1)
			if world != null and r_id is int and int(r_id) >= 0 and world.has_method("wake_room_enemies"):
				world.call("wake_room_enemies", int(r_id), hit_origin)
		if _is_player_awareness_source(damage_source):
			# A direct hit is allowed to make the Enemy hostile immediately, but it
			# records only this event's known Player position.  It does not grant a
			# permanent live-position channel through walls.
			_remember_player_damage_awareness()
		if damage_source in [&"kick", &"player_punch"]:
			SFX.play_melee_enemy_hit()
		elif not _is_gun_damage_source(damage_source):
			# Projectile callers emit the dedicated bullet-hit event only after
			# their collision resolver accepts the Enemy target.  Keep this legacy
			# impact cue for non-projectile damage sources without double-playing.
			SFX.play_event(&"enemy_hit")

	# ========================================================
	# 所有后续击退、喷血、击倒统一使用这一方向。
	# ========================================================

	var direction: Vector2 = _resolve_hit_direction(
		hit_origin,
		damage_source
	)
	_cancel_room_transit_for_combat()
	_remember_death_burst(
		direction,
		_resolve_death_burst_force(_knockback_force, damage_source),
		damage_source
	)

	var world := _get_world()

	# ============================================================
	# 中弹喷血
	# ============================================================

	if (
		actual > 0.0
		and world != null
		and _should_spawn_directional_blood(damage_source)
		and world.has_method(
			"spawn_black_blood"
		)
	):
		# Preserve the projectile/melee collision point when one is supplied;
		# only legacy callers without a finite hit origin fall back to the
		# enemy edge.  The 3D bridge uses this point for floor/wall placement.
		var blood_origin := (
			hit_origin
			if hit_origin != Vector2.INF and hit_origin.is_finite() and hit_origin.distance_to(global_position) <= 24.0
			else global_position + direction * 8.0
		)
		# Every accepted hit, including lethal melee, gets one synchronous impact
		# spray.  Death Burst/Corpse Bleed are separate later events and are never
		# suppressed by this bookkeeping flag.
		var spawn_result: Variant = world.call(
			"spawn_black_blood",
			blood_origin,
			direction,
			current_health <= 0.0,
			int(get_meta(&"dream_room_id", -1)),
			_blood_intensity_for_source(damage_source)
		)
		if not (spawn_result is bool) or spawn_result == true:
			impact_blood_spawned = true
	# Emit one accepted formal gun hit before the lethal early
	# return, so nonlethal and lethal hits share the same presentation event.
	var sample_gun_hit: bool=world!=null and world.has_method("uses_pixel_combat_vfx") and bool(world.uses_pixel_combat_vfx()) and _is_gun_damage_source(damage_source)
	if sample_gun_hit and (current_health<=0.0 or Time.get_ticks_msec()-last_hit_feedback_msec>=int(float(_cfg("projectile_impact_feedback_min_interval",.04))*1000)):
		last_hit_feedback_msec=Time.get_ticks_msec()
		world.spawn_combat_feedback(global_position,direction,current_health<=0.0,true,self)

	# ============================================================
	# 活着时持续流血
	# ============================================================

	if (
		actual > 0.0
		and current_health > 0.0
	):
		_start_bleeding_trail()

	# ============================================================
	# 死亡
	# ============================================================

	if current_health <= 0.0:
		bleeding_trail_left = 0.0
		bleeding_trail_interval_left = 0.0
		# The living-hit path below is intentionally skipped once health reaches
		# zero, so publish the same force-derived feedback before death takes over.
		# This keeps lethal hits on the authoritative knockback scale too.
		if actual > 0.0 and world != null and world.has_method("request_combat_impact"):
			world.request_combat_impact(
				_resolve_death_burst_force(_knockback_force, damage_source),
				direction,
				damage_source
			)

		if damage_source == &"lucille":
			var lethal_force := (
				(
					feedback_config.get_lucille_knockback_force()
					if feedback_config != null
					else 1200.0
				)
				* _cfg(
					"employee_knockdown_weapon_force_multiplier",
					1.75
				)
			)

			_drop_held_weapon(
				direction.rotated(
					random.randf_range(
						-0.2,
						0.2
					)
				) * lethal_force
			)

		_die()
		return

	if (
		health_bar != null
		and feedback_config != null
	):
		health_bar.show_after_damage(
			current_health,
			maximum_health,
			feedback_config.enemy_hp_bar_visible_duration
		)

	hit_flash_left = (
		feedback_config.enemy_hit_flash_seconds
		if feedback_config != null
		else 0.08
	)

	hit_scale_left = (
		feedback_config.enemy_hit_scale_seconds
		if feedback_config != null
		else 0.12
	)

	show_emoji(
		&"hit",
		0.9,
		4
	)

	var hit_force := (
		_knockback_force
		if _knockback_force > 1.01
		else (
			feedback_config.gun_knockback_force
			if (
				feedback_config != null
				and _is_gun_damage_source(damage_source)
			)
			else (
				feedback_config.enemy_knockback_strength
				if feedback_config != null
				else 96.0
			)
		)
	)
	if damage_source == &"books" and _knockback_force <= 1.01:
		hit_force = (
			feedback_config.get_lucille_knockback_force() * feedback_config.books_knockback_multiplier
			if feedback_config != null
			else 72.0
		)

	apply_knockback(
		direction,
		hit_force
	)

	var now_msec := Time.get_ticks_msec()

	var feedback_interval_msec := int(
		_cfg(
			"projectile_impact_feedback_min_interval",
			0.04
		) * 1000.0
	)

	if (
		world != null
		and not sample_gun_hit
		and now_msec - last_hit_feedback_msec
		>= feedback_interval_msec
	):
		last_hit_feedback_msec = now_msec

		world.spawn_combat_feedback(
			global_position,
			direction,
			false
		)

		if world.has_method("request_combat_impact"):
			world.request_combat_impact(hit_force, direction, damage_source)
		else:
			# Formal 2D worlds without the normalized impact entry retain their
			# single, throttled fallback instead of duplicating weapon-specific
			# feedback in every caller.
			var hit_stop_level: StringName = &"small"
			if hit_force >= 900.0:
				hit_stop_level = &"heavy"
			elif hit_force >= 360.0:
				hit_stop_level = &"medium"
			world.request_hit_stop(hit_stop_level)

	if actual > 0.0 and not hostile:
		if _is_player_awareness_source(damage_source):
			hostile = true
			_begin_hostile_reaction()
			state = State.ALERT

		else:
			var away: Vector2 = direction

			wander_target = Vector2(
				clampf(
					global_position.x
						+ away.x * 64.0,
					arena_bounds.position.x,
					arena_bounds.end.x
				),
				clampf(
					global_position.y
						+ away.y * 64.0,
					arena_bounds.position.y,
					arena_bounds.end.y
				)
			)

			wander_wait_left = 0.0
			state = State.NEUTRAL_WANDER

	# ============================================================
	# 正式击倒
	# ============================================================

	if (
		damage_source == &"kick"
		and random.randf()
		<= _cfg(
			"employee_kick_knockdown_chance",
			0.35
		)
	):
		start_knockdown(
			direction,
			&"kick",
			(
				feedback_config.get_kick_knockback_force()
				if feedback_config != null
				else 600.0
			)
		)

	elif damage_source == &"lucille":
		start_knockdown(
			direction,
			&"lucille",
			(
				feedback_config.get_lucille_knockback_force()
				if feedback_config != null
				else 1200.0
			)
		)


func start_knockdown(
	direction: Vector2,
	source: StringName = &"impact",
	force_override: float = -1.0,
	launch_velocity_override: float = -1.0
) -> void:
	if (
		dead
		or not is_damage_runtime_active()
	):
		return
	_cancel_ranged_attack_windup()

	# A living enemy owns one recovery episode at a time.  Follow-up damage may
	# still reduce HP and apply ordinary knockback through take_damage(), but a
	# Door/furniture/secondary impact must not restart the full timer, reset the
	# airborne state, or kill an in-progress get-up tween.  A future explicit
	# heavy-finisher rule can opt in here without making ordinary contact
	# permanently refresh KNOCKED_DOWN.
	if state in [State.KNOCKED_DOWN, State.GETTING_UP]:
		return

	var knock_direction: Vector2 = (
		direction.normalized()
		if direction.length_squared() > 0.001
		else Vector2.RIGHT
	)
	_cancel_room_transit_for_combat()

	if state not in [
		State.KNOCKED_DOWN,
		State.GETTING_UP
	]:
		state_before_knockdown = state

	state = State.KNOCKED_DOWN
	# A knockdown has higher visual/combat priority than a pending panic punch or
	# kick.  Cancel its hit window so an enemy cannot keep striking while airborne.
	unarmed_attack_active = false
	unarmed_attack_elapsed = 0.0
	unarmed_attack_hit_applied = false
	unarmed_attack_kind = &""

	knockdown_left = _cfg(
		"employee_knockdown_duration",
		1.2
	)

	velocity = Vector2.ZERO
	steering_commit_left = 0.0

	decision_cooldown_left = _cfg(
		"employee_decision_cooldown",
		0.42
	)

	_release_weapon_reservation()

	# 步行动画可能正处于蹦跳最高点。
	# 击倒开始前先恢复视觉基准位置，
	# 再由击飞假高度系统接管。
	character_visual.position = character_visual_base_position
	weapon_root.position = weapon_root_base_position

	var ground_force: float = (
		force_override
		if force_override > 0.0
		else _cfg(
			"employee_knockdown_knockback_force",
			210.0
		)
	)
	# 直接触发的击倒入口（例如家具/调试调用）也必须成为死亡拆解的最后冲击来源。
	_remember_death_burst(knock_direction, ground_force, source)

	var weapon_force: float = (
		ground_force
		* _cfg(
			"employee_knockdown_weapon_force_multiplier",
			1.75
		)
	)

	_drop_held_weapon(
		knock_direction.rotated(
			random.randf_range(
				-0.25,
				0.25
			)
		) * weapon_force
	)

	if (
		knockdown_visual_tween != null
		and knockdown_visual_tween.is_valid()
	):
		knockdown_visual_tween.kill()

	knockdown_visual_tween = null

	var fall_sign: float = (
		signf(knock_direction.x)
		if (
			absf(knock_direction.x)
			>= absf(knock_direction.y)
		)
		else signf(knock_direction.y)
	)

	if is_zero_approx(fall_sign):
		fall_sign = 1.0

	knockdown_rotation_target = (
		PI * 0.5
		* fall_sign
	)

	_start_knockdown_inertia(
		knock_direction,
		ground_force,
		launch_velocity_override
	)

	secondary_collision_cooldown_left = 0.0

	show_emoji(
		&"knockdown",
		1.0,
		5
	)

	if source in [
		&"kick",
		&"lucille"
	]:
		if not hostile:
			_begin_hostile_reaction()
		hostile = true


func _start_knockdown_inertia(
	direction: Vector2,
	force: float,
	launch_velocity_override: float = -1.0
) -> void:
	var safe_direction: Vector2 = (
		direction.normalized()
		if direction.length_squared() > 0.001
		else Vector2.RIGHT
	)

	var horizontal_speed: float = clampf(
		force
		* KNOCKDOWN_FORCE_TO_HORIZONTAL_SPEED,
		KNOCKDOWN_MIN_HORIZONTAL_SPEED,
		KNOCKDOWN_MAX_HORIZONTAL_SPEED
	)

	knockback_velocity = (
		safe_direction
		* horizontal_speed
	)

	var vertical_speed: float

	if launch_velocity_override > 0.0:
		vertical_speed = launch_velocity_override

	else:
		vertical_speed = clampf(
			force
			* KNOCKDOWN_FORCE_TO_VERTICAL_SPEED,
			KNOCKDOWN_MIN_VERTICAL_SPEED,
			KNOCKDOWN_MAX_VERTICAL_SPEED
		)

	knockdown_height = 0.0
	knockdown_vertical_velocity = vertical_speed

	knockdown_airborne = true
	knockdown_inertia_active = true
	knockdown_settled = false

	character_visual.position = (
		character_visual_base_position
	)

	knockback_left = 0.0


func _update_knockdown_state(
	delta: float
) -> void:
	if state != State.KNOCKED_DOWN:
		return

	if not knockdown_settled:
		character_visual.rotation = move_toward(
			character_visual.rotation,
			knockdown_rotation_target,
			KNOCKDOWN_ROTATION_SPEED * delta
		)

		if knockdown_airborne:
			knockdown_height += (
				knockdown_vertical_velocity
				* delta
			)

			knockdown_vertical_velocity -= (
				KNOCKDOWN_GRAVITY
				* delta
			)

			if (
				knockdown_height <= 0.0
				and knockdown_vertical_velocity < 0.0
			):
				var impact_vertical_speed: float = absf(
					knockdown_vertical_velocity
				)

				knockdown_height = 0.0

				knockback_velocity *= (
					KNOCKDOWN_GROUND_HORIZONTAL_RETENTION
				)

				var rebound_vertical_speed: float = (
					impact_vertical_speed
					* KNOCKDOWN_GROUND_VERTICAL_RETENTION
				)

				if (
					rebound_vertical_speed
					>= KNOCKDOWN_MIN_BOUNCE_VERTICAL_SPEED
				):
					knockdown_vertical_velocity = (
						rebound_vertical_speed
					)

					knockdown_airborne = true

				else:
					knockdown_vertical_velocity = 0.0
					knockdown_airborne = false

		else:
			knockdown_height = 0.0
			knockdown_vertical_velocity = 0.0

		character_visual.position = (
			character_visual_base_position
			+ Vector2(
				0.0,
				-knockdown_height
			)
		)

		if (
			not knockdown_airborne
			and knockback_velocity.length()
			<= KNOCKDOWN_SETTLE_HORIZONTAL_SPEED
		):
			knockback_velocity = Vector2.ZERO
			velocity = Vector2.ZERO

			knockdown_inertia_active = false
			knockdown_settled = true

			knockdown_height = 0.0
			knockdown_vertical_velocity = 0.0

			character_visual.position = (
				character_visual_base_position
			)

			character_visual.rotation = (
				knockdown_rotation_target
			)

		return

	character_visual.position = (
		character_visual_base_position
	)

	character_visual.rotation = (
		knockdown_rotation_target
	)

	knockdown_left = maxf(
		0.0,
		knockdown_left - delta
	)

	if knockdown_left <= 0.0:
		_start_getting_up()


func _start_getting_up() -> void:
	if (
		dead
		or state == State.GETTING_UP
	):
		return

	state = State.GETTING_UP
	velocity = Vector2.ZERO

	knockback_velocity = Vector2.ZERO
	knockback_left = 0.0

	knockdown_inertia_active = false
	knockdown_airborne = false
	knockdown_height = 0.0
	knockdown_vertical_velocity = 0.0

	character_visual.position = (
		character_visual_base_position
	)

	weapon_root.position = (
		weapon_root_base_position
	)

	if (
		knockdown_visual_tween != null
		and knockdown_visual_tween.is_valid()
	):
		knockdown_visual_tween.kill()

	knockdown_visual_tween = create_tween()

	knockdown_visual_tween.tween_property(
		character_visual,
		"rotation",
		0.0,
		_cfg(
			"employee_get_up_duration",
			0.4
		)
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)

	knockdown_visual_tween.tween_callback(
		_finish_getting_up
	)


func _finish_getting_up() -> void:
	if dead:
		return

	character_visual.rotation = 0.0

	character_visual.position = (
		character_visual_base_position
	)

	weapon_root.position = (
		weapon_root_base_position
	)

	knockdown_visual_tween = null

	knockdown_height = 0.0
	knockdown_vertical_velocity = 0.0
	knockdown_airborne = false
	knockdown_inertia_active = false
	knockdown_settled = false

	state = (
		State.ALERT
		if hostile
		else State.NEUTRAL_WANDER
	)

	if (
		not hostile
		and state_before_knockdown
		== State.NEUTRAL_WANDER
	):
		wander_target = global_position
		wander_wait_left = 0.0

	if not room_runtime_active:
		set_process(false)
		set_physics_process(false)


func _drop_held_weapon(
	impulse: Vector2
) -> void:
	_cancel_ranged_attack_windup()
	if held_weapon_id.is_empty():
		return

	var dropped_weapon_id := held_weapon_id

	held_weapon_id = ""

	current_ammo = 0
	reload_left = 0.0

	_finish_reload_visual()

	held_weapon_sprite.hide()
	weapon_root.hide()
	_sync_enemy_hands_visibility()

	weapon_drop_requested.emit(
		dropped_weapon_id,
		global_position,
		impulse,
		held_weapon_skin_index
	)


func force_pit_death(pit_position: Vector2 = Vector2.INF) -> void:
	if dead:
		return
	set_meta(&"pit_death", true)
	var escape_direction := death_burst_direction
	if pit_position != Vector2.INF and pit_position.is_finite():
		escape_direction = global_position.direction_to(pit_position + Vector2(1.0, -1.0))
	if escape_direction.length_squared() <= 0.001:
		escape_direction = Vector2.UP
	_remember_death_burst(escape_direction, maxf(death_burst_force, 180.0), &"pit")
	if current_health > 0.0:
		current_health = 0.0
	_die()


func _die() -> void:
	if dead:
		return
	_cancel_ranged_attack_windup()

	# A lethal hit can arrive before this frame's normal slide/bounds pass.
	# Sanitize the ground root before spawning blood or detached sprites so a
	# wall-corner death cannot seed effects from an already-outside position.
	_sanitize_death_position()
	# The delayed plasma belongs to the death commit position, not to a later
	# presentation frame after knockback/slide has moved the gameplay actor.
	death_origin_gameplay_position = global_position
	death_origin_room_id = int(get_meta(&"dream_room_id", -1))
	if death_burst_direction.length_squared() <= 0.001:
		death_burst_direction = Vector2.RIGHT
	death_burst_direction = death_burst_direction.normalized()
	death_plasma_spawned = false
	death_pool_spawned = false
	corpse_bleed_spawned = false
	corpse_elapsed_time = 0.0
	modulate = Color.WHITE

	var death_fake_height := (
		maxf(knockdown_height, 0.0)
		if knockdown_inertia_active or knockdown_airborne
		else 0.0
	)
	var inherited_death_velocity := (velocity + knockback_velocity) * float(_cfg(&"corpse_inherited_velocity_ratio",0.35))

	dead = true
	# Lock the authored closed-eye frame before any death movement, blood,
	# dismemberment or facing callback can run.
	_set_enemy_head_frame(2)
	velocity = Vector2.ZERO

	knockback_velocity = Vector2.ZERO
	knockback_left = 0.0

	knockdown_inertia_active = false
	knockdown_airborne = false
	knockdown_settled = true

	bleeding_trail_left = 0.0
	bleeding_trail_interval_left = 0.0

	var world := _get_world()

	set_process(false)
	set_physics_process(false)

	if (
		knockdown_visual_tween != null
		and knockdown_visual_tween.is_valid()
	):
		knockdown_visual_tween.kill()

	knockdown_visual_tween = null

	if visual_tween != null and visual_tween.is_valid():
		visual_tween.kill()
	visual_tween = null
	if weapon_motion != null and is_instance_valid(weapon_motion):
		weapon_motion.position = Vector2.ZERO
		weapon_motion.rotation = 0.0

	room_runtime_active = false

	_release_weapon_reservation()

	if health_bar != null:
		health_bar.hide_immediately()

	set_auto_aim_locked(false)

	var final_drop_impulse := Vector2.ZERO
	if get_meta(&"pit_death", false) == true:
		final_drop_impulse = death_burst_direction * maxf(death_burst_force, 180.0)
	_drop_held_weapon(final_drop_impulse)

	_finish_reload_visual()
	_disable_damage_and_collision()
	# Ordinary deaths use one roll for the complete body.  The remaining 70%
	# still execute the same death/blood/drop/reward pipeline without detached
	# parts; any explicit special finisher can remain separate if introduced.
	var should_dismember := random.randf() < clampf(
		_cfg("employee_dismember_chance", 0.30),
		0.0,
		1.0
	)
	# Keep the same split character for the short death launch/landing. The
	# one dismember roll changes only its final presentation, never rewards.
	death_dismember = should_dismember
	var is_pit_death: bool = bool(get_meta(&"pit_death", false))
	if is_pit_death:
		corpse_linger_duration = 1.05
	else:
		corpse_linger_duration = maxf(float(_cfg(&"corpse_linger_duration", 15.0)), 1.0)
	corpse_darken_duration = maxf(float(_cfg(&"corpse_darken_duration", 3.0)), 0.1)
	corpse_target_brightness = clampf(float(_cfg(&"corpse_darken_target_brightness", 0.5)), 0.0, 1.0)
	death_presentation_left = corpse_linger_duration
	corpse_elapsed_time = 0.0
	modulate = Color.WHITE
	# Lethal blow impulse slides corpse along floor and initiates ragdoll sway.
	death_ground_velocity = (death_burst_direction * death_burst_force * float(_cfg(&"corpse_impulse_transfer",0.75)) + inherited_death_velocity).limit_length(float(_cfg(&"corpse_max_launch_speed",360.0)))
	death_vertical_speed = clampf(death_burst_force * 0.16, 40.0, 110.0)
	knockdown_height = death_fake_height
	death_landed = false
	character_visual.show()
	emoji_sprite.hide()
	weapon_root.hide()
	_sync_enemy_hands_visibility()
	left_hand.show()
	right_hand.show()

	_init_ragdoll_physics()
	corpse_contact = Area2D.new()
	corpse_contact.name = "CorpseContact"
	corpse_contact.set_script(CORPSE_CONTACT)
	add_child(corpse_contact)

	SFX.play_event(
		&"enemy_kill"
	)

	defeated.emit(
		global_position,
		experience_drop_count
	)

	set_process(true)
	set_physics_process(true)


func _update_death_presentation(delta: float, simulate_motion: bool = true) -> void:
	if death_presentation_left <= 0.0:
		return
	death_presentation_left -= delta
	corpse_elapsed_time += delta
	# Production motion runs only in fixed physics ticks. The explicit default
	# supports existing deterministic tests that manually step presentation.
	if simulate_motion: _update_death_motion(delta)
	_update_corpse_visual_pose(delta)


func _update_death_motion(delta: float) -> void:
	if not dead or death_presentation_left<=0.0 or delta<=0.0: return

	# 1. Slide and bounce physics while airborne or moving
	if not death_landed or death_ground_velocity.length_squared() > 0.01 or knockdown_height > 0.0:
		var next_position := global_position + death_ground_velocity * delta
		if _corpse_motion_query==null:
			_corpse_motion_query=PhysicsShapeQueryParameters2D.new()
			var footprint := CircleShape2D.new(); footprint.radius=7.0
			_corpse_motion_query.shape=footprint
			_corpse_motion_query.collision_mask=4|8
		var sweep := _corpse_motion_query
		sweep.transform = Transform2D(0.0,global_position)
		sweep.motion = next_position-global_position
		sweep.collision_mask = 4 | 8 # Walls, door leaves and furniture; never player.
		var travel := get_world_2d().direct_space_state.cast_motion(sweep)
		if travel[0] < 1.0:
			next_position = global_position+sweep.motion*travel[0]
			# Resolve the contact normal at the unsafe end of the real sweep.
			sweep.transform=Transform2D(0.0,global_position+sweep.motion*travel[1])
			sweep.motion=Vector2.ZERO
			var contact := get_world_2d().direct_space_state.get_rest_info(sweep)
			var normal: Vector2=contact.get("normal",Vector2.ZERO)
			if normal.length_squared()>0.001 and death_ground_velocity.dot(normal)<0.0:
				var normal_speed := death_ground_velocity.dot(normal)
				death_ground_velocity=(death_ground_velocity-normal*normal_speed)*float(_cfg(&"corpse_wall_slide_retention",0.65))-normal*normal_speed*float(_cfg(&"corpse_wall_restitution",0.18))
			else: death_ground_velocity=Vector2.ZERO
		var floor_world := _get_world()
		if floor_world != null and floor_world.has_method("_is_blood_ground_allowed") and not floor_world.call("_is_blood_ground_allowed",next_position):
			next_position = global_position
			death_ground_velocity = Vector2.ZERO
		global_position = next_position
		_sanitize_death_position()
		var drag := float(_cfg(&"corpse_ground_drag",320.0)) if death_landed else float(_cfg(&"corpse_air_drag",40.0))
		death_ground_velocity=death_ground_velocity.move_toward(Vector2.ZERO,drag*delta)
		death_vertical_speed -= KNOCKDOWN_GRAVITY * delta
		knockdown_height = maxf(0.0, knockdown_height + death_vertical_speed * delta)
		character_visual.position = character_visual_base_position + Vector2(0, -knockdown_height)
		if not death_landed:
			character_visual.rotation = lerpf(character_visual.rotation, signf(death_burst_direction.x + 0.001) * PI * 0.5, minf(1, delta * 10.0))
		if knockdown_height <= 0.0 and not death_landed:
			death_landed = true
			death_vertical_speed = 0.0
			_spawn_cached_death_blood_pool()
			_start_corpse_follow_bleed()
			# Ground impact secondary shock on ragdoll limbs
			var impact_bounce := clampf(death_burst_force / 220.0, 0.7, 1.8)
			ragdoll_head_vel += Vector2(random.randf_range(-15.0, 15.0), -32.0) * impact_bounce
			ragdoll_head_rot_vel += random.randf_range(-6.0, 6.0) * impact_bounce
			ragdoll_left_hand_vel += Vector2(-22.0, -24.0) * impact_bounce
			ragdoll_left_hand_rot_vel += random.randf_range(-10.0, 10.0) * impact_bounce
			ragdoll_right_hand_vel += Vector2(22.0, -24.0) * impact_bounce
			ragdoll_right_hand_rot_vel += random.randf_range(-10.0, 10.0) * impact_bounce
			ragdoll_left_foot_vel += Vector2(-15.0, -18.0) * impact_bounce
			ragdoll_right_foot_vel += Vector2(15.0, -18.0) * impact_bounce
	character_visual.rotation += corpse_spin*delta
	corpse_spin=move_toward(corpse_spin,0.0,4.0*delta)
	if death_landed and death_ground_velocity.length_squared()<0.01 and absf(corpse_spin)<0.001:
		death_ground_velocity=Vector2.ZERO
		set_physics_process(false)

func _update_corpse_visual_pose(delta: float) -> void:
	# 2. Step ragdoll until settled; sleep once resting on floor to save CPU
	if ragdoll_active:
		_step_ragdoll_physics(delta)
		if death_landed and death_ground_velocity.length_squared() < 0.01:
			if (
				ragdoll_head_vel.length_squared() < 0.2
				and ragdoll_left_hand_vel.length_squared() < 0.2
				and ragdoll_right_hand_vel.length_squared() < 0.2
				and ragdoll_left_foot_vel.length_squared() < 0.2
				and ragdoll_right_foot_vel.length_squared() < 0.2
				and ragdoll_body_pivot_vel.length_squared() < 0.2
				and absf(ragdoll_head_rot_vel) < 0.05
				and absf(ragdoll_left_hand_rot_vel) < 0.05
				and absf(ragdoll_right_hand_rot_vel) < 0.05
				and absf(ragdoll_left_foot_rot_vel) < 0.05
				and absf(ragdoll_right_foot_rot_vel) < 0.05
				and absf(ragdoll_body_pivot_rot_vel) < 0.05
				and absf(corpse_spin) < 0.05
			):
				ragdoll_active = false

	# 3. Brightness reduction: smoothly decrease brightness to 50% within 3 seconds
	var darken_progress := clampf(corpse_elapsed_time / corpse_darken_duration, 0.0, 1.0)
	var current_brightness := lerpf(1.0, corpse_target_brightness, darken_progress)

	# 4. Smooth alpha fade-out at the end of the linger window (final 0.5s)
	var current_alpha := 1.0
	var fade_window := 0.5 if corpse_linger_duration > 1.5 else 0.25
	if death_presentation_left < fade_window:
		current_alpha = maxf(0.0, death_presentation_left / fade_window)

	modulate = Color(current_brightness, current_brightness, current_brightness, current_alpha)

	# 5. Despawn corpse after presentation time expires (~15s)
	if death_presentation_left <= 0.0:
		# A high fake-height death can still be airborne when the authored
		# presentation timer ends. Guarantee one ground pool at the cached death
		# origin rather than losing it when the Enemy root is released.
		_spawn_cached_death_blood_pool()
		death_plasma_spawned = true
		corpse_bleed_spawned = true
		queue_free()


func receive_corpse_contact(impulse: Vector2) -> void:
	if not dead or not death_landed or death_presentation_left <= 0.0: return
	set_physics_process(true)
	death_ground_velocity = (death_ground_velocity+impulse).limit_length(240.0)
	var local := impulse.rotated(-character_visual.rotation)
	ragdoll_active = true
	ragdoll_head_vel += local*0.4
	ragdoll_left_hand_vel += local*0.7
	ragdoll_right_hand_vel += local*0.65
	ragdoll_left_foot_vel += local*0.3
	ragdoll_right_foot_vel += local*0.35
	ragdoll_head_rot_vel += local.x*0.035
	ragdoll_left_hand_rot_vel += local.x*0.07
	ragdoll_right_hand_rot_vel -= local.x*0.06
	corpse_spin = clampf(corpse_spin+local.x*0.012,-2.0,2.0)


func _init_ragdoll_physics() -> void:
	ragdoll_active = true
	ragdoll_left_hand_pos = Vector2.ZERO
	ragdoll_right_hand_pos = Vector2.ZERO
	ragdoll_head_pos = Vector2.ZERO
	ragdoll_left_foot_pos = Vector2.ZERO
	ragdoll_right_foot_pos = Vector2.ZERO
	ragdoll_body_pivot_pos = Vector2.ZERO
	ragdoll_left_hand_rot = 0.0
	ragdoll_right_hand_rot = 0.0
	ragdoll_head_rot = 0.0
	ragdoll_left_foot_rot = 0.0
	ragdoll_right_foot_rot = 0.0
	ragdoll_body_pivot_rot = 0.0

	var force_ratio: float = clampf(death_burst_force / 180.0, 0.7, 2.2)
	var facing_sign: float = signf(character_visual.scale.x) if absf(character_visual.scale.x) > 0.001 else 1.0
	var local_impulse: Vector2 = Vector2(death_burst_direction.x * facing_sign, death_burst_direction.y) * (55.0 * force_ratio)

	# Head impulse: whip back & tilt
	ragdoll_head_vel = local_impulse * 0.85 + Vector2(0.0, -16.0 * force_ratio)
	ragdoll_head_rot_vel = -signf(local_impulse.x) * (14.0 * force_ratio) + random.randf_range(-2.5, 2.5)

	# Hands impulse: fling outward & back with tumbling
	ragdoll_left_hand_vel = local_impulse * 1.25 + Vector2(-48.0, -28.0) * force_ratio
	ragdoll_left_hand_rot_vel = random.randf_range(-20.0, -10.0) * force_ratio
	ragdoll_right_hand_vel = local_impulse * 1.25 + Vector2(48.0, -28.0) * force_ratio
	ragdoll_right_hand_rot_vel = random.randf_range(10.0, 20.0) * force_ratio

	# Feet impulse: drag / trail behind body
	ragdoll_left_foot_vel = local_impulse * 0.5 + Vector2(-22.0, 14.0) * force_ratio
	ragdoll_left_foot_rot_vel = random.randf_range(-8.0, 8.0) * force_ratio
	ragdoll_right_foot_vel = local_impulse * 0.5 + Vector2(22.0, 14.0) * force_ratio
	ragdoll_right_foot_rot_vel = random.randf_range(-8.0, 8.0) * force_ratio

	# Torso slight recoil
	ragdoll_body_pivot_vel = local_impulse * 0.3
	ragdoll_body_pivot_rot_vel = signf(local_impulse.x) * (5.5 * force_ratio)


func _step_ragdoll_part(
	pos: Vector2,
	vel: Vector2,
	rot: float,
	rot_vel: float,
	dt: float,
	max_distance: float,
	stiffness: float,
	damping: float,
	rot_stiffness: float,
	rot_damping: float
) -> Array:
	if death_landed:
		# Keep the anatomical anchor attached but let the joint relax at its
		# actual landing angle: no spring pulling a dead limb back to standing.
		max_distance = minf(max_distance,4.0)
		rot_stiffness = 0.0
		rot_damping = 4.0
	var acc := -stiffness * pos - damping * vel
	vel += acc * dt
	pos += vel * dt
	if max_distance > 0.0 and pos.length() > max_distance:
		pos = pos.limit_length(max_distance)
		if pos.dot(vel) > 0.0:
			vel -= pos.normalized() * pos.normalized().dot(vel)

	var rot_acc := -rot_stiffness * rot - rot_damping * rot_vel
	rot_vel += rot_acc * dt
	rot += rot_vel * dt
	rot = clampf(rot, -2.35, 2.35)

	return [pos, vel, rot, rot_vel]


func _step_ragdoll_physics(delta: float) -> void:
	var remaining := delta
	var step := minf(remaining, 0.016)
	while remaining > 0.0001:
		var dt := minf(remaining, step)
		remaining -= dt

		var head_res := _step_ragdoll_part(
			ragdoll_head_pos, ragdoll_head_vel, ragdoll_head_rot, ragdoll_head_rot_vel,
			dt, 9.0, 180.0, 13.0, 200.0, 14.0
		)
		ragdoll_head_pos = head_res[0]
		ragdoll_head_vel = head_res[1]
		ragdoll_head_rot = head_res[2]
		ragdoll_head_rot_vel = head_res[3]

		var lh_res := _step_ragdoll_part(
			ragdoll_left_hand_pos, ragdoll_left_hand_vel, ragdoll_left_hand_rot, ragdoll_left_hand_rot_vel,
			dt, 16.0, 175.0, 11.5, 190.0, 13.0
		)
		ragdoll_left_hand_pos = lh_res[0]
		ragdoll_left_hand_vel = lh_res[1]
		ragdoll_left_hand_rot = lh_res[2]
		ragdoll_left_hand_rot_vel = lh_res[3]

		var rh_res := _step_ragdoll_part(
			ragdoll_right_hand_pos, ragdoll_right_hand_vel, ragdoll_right_hand_rot, ragdoll_right_hand_rot_vel,
			dt, 16.0, 175.0, 11.5, 190.0, 13.0
		)
		ragdoll_right_hand_pos = rh_res[0]
		ragdoll_right_hand_vel = rh_res[1]
		ragdoll_right_hand_rot = rh_res[2]
		ragdoll_right_hand_rot_vel = rh_res[3]

		var lf_res := _step_ragdoll_part(
			ragdoll_left_foot_pos, ragdoll_left_foot_vel, ragdoll_left_foot_rot, ragdoll_left_foot_rot_vel,
			dt, 11.0, 210.0, 14.0, 190.0, 15.0
		)
		ragdoll_left_foot_pos = lf_res[0]
		ragdoll_left_foot_vel = lf_res[1]
		ragdoll_left_foot_rot = lf_res[2]
		ragdoll_left_foot_rot_vel = lf_res[3]

		var rf_res := _step_ragdoll_part(
			ragdoll_right_foot_pos, ragdoll_right_foot_vel, ragdoll_right_foot_rot, ragdoll_right_foot_rot_vel,
			dt, 11.0, 210.0, 14.0, 190.0, 15.0
		)
		ragdoll_right_foot_pos = rf_res[0]
		ragdoll_right_foot_vel = rf_res[1]
		ragdoll_right_foot_rot = rf_res[2]
		ragdoll_right_foot_rot_vel = rf_res[3]

		var bp_res := _step_ragdoll_part(
			ragdoll_body_pivot_pos, ragdoll_body_pivot_vel, ragdoll_body_pivot_rot, ragdoll_body_pivot_rot_vel,
			dt, 5.0, 240.0, 18.0, 230.0, 18.0
		)
		ragdoll_body_pivot_pos = bp_res[0]
		ragdoll_body_pivot_vel = bp_res[1]
		ragdoll_body_pivot_rot = bp_res[2]
		ragdoll_body_pivot_rot_vel = bp_res[3]

	if death_landed:
		ragdoll_head_rot = clampf(ragdoll_head_rot,-0.85,0.85)
		ragdoll_left_hand_rot = clampf(ragdoll_left_hand_rot,-1.6,1.6)
		ragdoll_right_hand_rot = clampf(ragdoll_right_hand_rot,-1.6,1.6)
		ragdoll_left_foot_rot = clampf(ragdoll_left_foot_rot,-1.1,1.1)
		ragdoll_right_foot_rot = clampf(ragdoll_right_foot_rot,-1.1,1.1)
		ragdoll_body_pivot_rot = clampf(ragdoll_body_pivot_rot,-0.5,0.5)
	_apply_ragdoll_transforms()


func _apply_ragdoll_transforms() -> void:
	const HEAD_PIVOT := Vector2(14.0, 26.0)
	head.rotation = ragdoll_head_rot
	head.position = head_base_position + HEAD_PIVOT + ragdoll_head_pos - HEAD_PIVOT.rotated(ragdoll_head_rot)

	const HAND_PIVOT := Vector2(2.5, 2.0)
	left_hand.rotation = ragdoll_left_hand_rot
	left_hand.position = left_hand_base_position + HAND_PIVOT + ragdoll_left_hand_pos - HAND_PIVOT.rotated(ragdoll_left_hand_rot)

	right_hand.rotation = ragdoll_right_hand_rot
	right_hand.position = right_hand_base_position + HAND_PIVOT + ragdoll_right_hand_pos - HAND_PIVOT.rotated(ragdoll_right_hand_rot)

	const FOOT_PIVOT := Vector2(2.0, 2.0)
	left_leg.rotation = ragdoll_left_foot_rot
	left_leg.position = left_leg_base_position + FOOT_PIVOT + ragdoll_left_foot_pos - FOOT_PIVOT.rotated(ragdoll_left_foot_rot)

	right_leg.rotation = ragdoll_right_foot_rot
	right_leg.position = right_leg_base_position + FOOT_PIVOT + ragdoll_right_foot_pos - FOOT_PIVOT.rotated(ragdoll_right_foot_rot)

	body_pivot.position = body_pivot_base_position + ragdoll_body_pivot_pos
	body_pivot.rotation = ragdoll_body_pivot_rot


func _spawn_cached_death_blood_pool() -> void:
	if death_pool_spawned:
		return
	var world := _get_world()
	if world == null or not world.has_method("spawn_death_blood_pool"):
		return
	death_pool_spawned = true
	world.call(
		"spawn_death_blood_pool",
		death_origin_gameplay_position,
		death_origin_room_id,
		_blood_intensity_for_source(death_burst_source),
		death_dismember,
		death_burst_direction
	)


func _start_corpse_follow_bleed() -> void:
	if corpse_bleed_spawned or not death_landed or bool(get_meta(&"pit_death", false)):
		return
	var world := _get_world()
	if world == null or not world.has_method("spawn_corpse_blood_emitter"):
		return
	corpse_bleed_spawned = bool(world.call(
		"spawn_corpse_blood_emitter", global_position, death_origin_room_id,
		death_burst_direction, _blood_intensity_for_source(death_burst_source), self
	))


func get_corpse_blood_ground_position() -> Vector2:
	var reference: Variant = get_meta(&"depth_visual_bridge", null)
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if death_landed and is_instance_valid(bridge) and bridge.has_method("get_corpse_blood_ground_position"):
		return bridge.call("get_corpse_blood_ground_position")
	return global_position


## Start a normal encounter enemy above its real floor cell.  This is a visual
## arrival only: no 2D gameplay position, room id or navigation target moves.
func start_sky_drop(height_pixels: float = -1.0, delay: float = 0.0) -> void:
	if dead or sky_drop_active:
		return
	_cancel_ranged_attack_windup()
	sky_drop_active = true
	sky_drop_delay_left = maxf(delay, 0.0)
	sky_drop_height = maxf(
		height_pixels if height_pixels > 0.0 else _cfg(&"employee_sky_drop_height", 96.0),
		0.0
	)
	sky_drop_vertical_velocity = 0.0
	sky_drop_gravity = maxf(_cfg(&"employee_sky_drop_gravity", 520.0), 1.0)
	sky_drop_saved_collision_layer = collision_layer
	sky_drop_saved_collision_mask = collision_mask
	sky_drop_saved_body_disabled = body_collision != null and body_collision.disabled
	sky_drop_saved_hurtbox_disabled = hurtbox_collision != null and hurtbox_collision.disabled
	sky_drop_saved_hurtbox_monitorable = hurtbox != null and hurtbox.monitorable
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	knockback_left = 0.0
	state = State.NEUTRAL_WANDER
	character_visual.position = character_visual_base_position + Vector2(0.0, -sky_drop_height)
	weapon_root.position = weapon_root_base_position
	weapon_root.hide()
	_disable_sky_drop_collision()


func _update_sky_drop(delta: float) -> void:
	if not sky_drop_active:
		return
	if sky_drop_delay_left > 0.0:
		sky_drop_delay_left = maxf(sky_drop_delay_left - delta, 0.0)
		return
	sky_drop_height += sky_drop_vertical_velocity * delta
	sky_drop_vertical_velocity -= sky_drop_gravity * delta
	if sky_drop_height > 0.0:
		character_visual.position = character_visual_base_position + Vector2(0.0, -sky_drop_height)
		return
	sky_drop_height = 0.0
	sky_drop_vertical_velocity = 0.0
	sky_drop_active = false
	character_visual.position = character_visual_base_position
	weapon_root.position = weapon_root_base_position
	if not held_weapon_id.is_empty():
		weapon_root.show()
	_restore_sky_drop_collision()
	state = State.ALERT if hostile else State.NEUTRAL_WANDER
	decision_cooldown_left = 0.0


func _disable_sky_drop_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	if body_collision != null:
		body_collision.set_deferred("disabled", true)
	if hurtbox_collision != null:
		hurtbox_collision.set_deferred("disabled", true)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)


func _restore_sky_drop_collision() -> void:
	if not room_runtime_active:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = sky_drop_saved_collision_layer
		collision_mask = sky_drop_saved_collision_mask
	if body_collision != null:
		body_collision.set_deferred("disabled", sky_drop_saved_body_disabled or not room_runtime_active)
	if hurtbox_collision != null:
		hurtbox_collision.set_deferred("disabled", sky_drop_saved_hurtbox_disabled or not room_runtime_active)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", sky_drop_saved_hurtbox_monitorable and room_runtime_active)


func set_room_runtime_active(
	active: bool
) -> void:
	if dead:
		return
	if not active:
		_cancel_ranged_attack_windup()

	room_runtime_active = active
	if active:
		room_preview_visible = false
	_apply_player_vision_visibility()

	# Room simulation may pause ordinary AI while the Player is elsewhere, but
	# an alive knockdown must still be able to settle, count down, and finish its
	# get-up tween. Keep only that physical recovery path ticking while inactive;
	# once it reaches standing, _finish_getting_up() disables processing again.
	var recovery_active := (
		sky_drop_active
		or
		state in [State.KNOCKED_DOWN, State.GETTING_UP]
		or knockdown_inertia_active
		or knockdown_airborne
	)
	set_process(active or recovery_active)
	set_physics_process(active or recovery_active)

	collision_layer = (
		int(
			get_meta(
				&"room_original_collision_layer",
				2
			)
		)
		if active
		else 0
	)

	collision_mask = (
		int(
			get_meta(
				&"room_original_collision_mask",
				47
			)
		)
		if active
		else 0
	)

	if body_collision != null:
		body_collision.set_deferred(
			"disabled",
			not active
		)

	var is_otxo := _is_otxo_mode()
	if hurtbox_collision != null:
		hurtbox_collision.set_deferred(
			"disabled",
			false if is_otxo else not active
		)
	if hurtbox != null:
		# 视觉隐藏与受击资格分离：一跳邻房仍需能被真实弹道/近战命中。
		# OTXO 模式下远处冻结敌人保留受击资格。
		hurtbox.set_deferred("monitorable", true if is_otxo else active)
	if sky_drop_active:
		_disable_sky_drop_collision()

	if active:
		remove_from_group(
			&"dormant_room_enemy"
		)
	else:
		add_to_group(
			&"dormant_room_enemy"
		)


func is_damage_runtime_active() -> bool:
	if dead or sky_drop_active:
		return false
	if room_runtime_active and not is_in_group(&"dormant_room_enemy"):
		return true
	if _is_otxo_mode():
		return true
	return false


func set_player_vision_visible(value: bool) -> void:
	player_vision_visible = value
	_apply_player_vision_visibility()


func set_room_preview_visible(value: bool) -> void:
	room_preview_visible = value
	_apply_player_vision_visibility()


func _apply_player_vision_visibility() -> void:
	if dead:
		visible = death_presentation_left > 0.0 and player_vision_visible
	else:
		visible = (_is_otxo_mode() or room_runtime_active or room_preview_visible) and player_vision_visible


func _disable_damage_and_collision() -> void:
	collision_layer = 0
	collision_mask = 0

	if body_collision != null:
		body_collision.set_deferred(
			"disabled",
			true
		)

	if hurtbox_collision != null:
		hurtbox_collision.set_deferred(
			"disabled",
			true
		)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)


func _spawn_detached_body_parts(initial_fake_height: float = 0.0) -> void:
	var debris_root := _find_room_debris_root()

	if debris_root == null:
		return
	var direction := death_burst_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var force := maxf(death_burst_force, 32.0)
	# 四个零件保持同一主要受力方向，只做轻微的部件级散射。
	_spawn_detached_body_part(body, debris_root, direction, force * 0.78, force * 0.10, 0.35, initial_fake_height)
	_spawn_detached_body_part(head, debris_root, direction.rotated(random.randf_range(-0.12, 0.12)), force * 0.92, force * 0.23, 2.6, initial_fake_height)
	_spawn_detached_body_part(left_leg, debris_root, direction.rotated(-0.16 + random.randf_range(-0.06, 0.06)), force * 0.86, force * 0.15, -3.1, initial_fake_height)
	_spawn_detached_body_part(right_leg, debris_root, direction.rotated(0.16 + random.randf_range(-0.06, 0.06)), force * 0.86, force * 0.15, 3.1, initial_fake_height)


func _spawn_detached_body_part(
	source_sprite: Sprite2D,
	debris_root: Node2D,
	direction: Vector2,
	horizontal_force: float,
	vertical_force: float,
	spin: float,
	initial_fake_height: float = 0.0
) -> void:
	if source_sprite == null or not is_instance_valid(source_sprite) or source_sprite.texture == null:
		return
	var part := BODY_PART_SCENE.instantiate() as EnemyBodyPart
	if part == null:
		return
	debris_root.add_child(part)
	var continuous := _uses_continuous_ground_collision()
	if not continuous:
		part.set_room_bounds(arena_bounds.grow(-4.0))
	part.setup_from_sprite(
		source_sprite,
		direction.normalized() * horizontal_force,
		maxf(vertical_force, 22.0),
		spin + random.randf_range(-0.7, 0.7),
		initial_fake_height
	)
	# setup_from_sprite copies the visual world position, while the detached
	# CharacterBody2D must start from a legal ground point.  The body-part scene
	# performs the same small room-boundary correction on its first physics tick;
	# doing it here also prevents a one-frame wall leak at spawn time.
	part.constrain_to_room_bounds()
	if continuous:
		# Anatomical offsets belong to the visual, not to a new ground collider.
		# In particular a rotated head offset must not spawn a body outside a wall.
		part.global_position = global_position
	# In the 3D random-building prototype this remains the formal 2D death
	# fragment, but its Sprite2D must also be routed through the shared depth
	# bridge so detached parts are visible in the same world as the live enemy.
	var world := _get_world()
	if world != null and world.has_method("register_depth_visual"):
		var visual_paths: Array[NodePath] = [NodePath("Sprite2D")]
		world.call("register_depth_visual", part, visual_paths)
	if world != null:
		part.configure_ground_bleed(world, death_origin_room_id)


func _sanitize_death_position() -> void:
	if _uses_continuous_ground_collision():
		return
	# A genuine Room Transit owns its crossing and must not be pulled back to the
	# source room by a generic death clamp.
	if state == State.ROOM_TRANSIT:
		return
	var bounds := room_bounds
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		bounds = arena_bounds
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	var safe_bounds := bounds.grow(-4.0)
	if safe_bounds.size.x <= 1.0 or safe_bounds.size.y <= 1.0:
		return
	var corrected := Vector2(
		clampf(global_position.x, safe_bounds.position.x, safe_bounds.end.x),
		clampf(global_position.y, safe_bounds.position.y, safe_bounds.end.y)
	)
	if corrected.is_equal_approx(global_position):
		return
	global_position = corrected
	# The cached death burst remains unchanged; only the dead root's transient
	# motion is cleared because detached parts receive the cached impulse later.
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO


func _resolve_death_burst_force(requested_force: float, damage_source: StringName) -> float:
	if requested_force > 1.01:
		return requested_force
	if feedback_config != null:
		if _is_gun_damage_source(damage_source):
			return feedback_config.gun_knockback_force
		match damage_source:
			&"lucille": return feedback_config.get_lucille_knockback_force()
			&"books": return feedback_config.get_lucille_knockback_force() * feedback_config.books_knockback_multiplier
			&"kick": return feedback_config.get_kick_knockback_force()
			&"furniture_impact", &"secondary_collision": return feedback_config.furniture_impact_enemy_knockback
			_: return feedback_config.enemy_knockback_strength
	return 160.0


func _remember_death_burst(direction: Vector2, force: float, source: StringName = &"fallback") -> void:
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.001:
		safe_direction = Vector2.RIGHT
	death_burst_direction = safe_direction
	death_burst_force = maxf(force, 32.0)
	death_burst_source = source


func _find_room_debris_root() -> Node2D:
	var world := _get_world()

	if (
		world != null
		and world.has_method(
			"get_room_debris_root"
		)
	):
		var room_root := (
			world.get_room_debris_root(
				int(
					get_meta(
						&"dream_room_id",
						-1
					)
				)
			)
			as Node2D
		)

		if room_root != null:
			return room_root

	var ancestor := get_parent()

	while ancestor != null:
		var local_root := (
			ancestor.get_node_or_null(
				"GroundDebrisRoot"
			)
			as Node2D
		)

		if local_root != null:
			return local_root

		ancestor = ancestor.get_parent()

	return (
		get_tree().get_first_node_in_group(
			&"ground_debris_root"
		)
		as Node2D
	)


func apply_knockback(
	direction: Vector2,
	strength: float
) -> void:
	if direction.length_squared() <= 0.001:
		return
	_cancel_room_transit_for_combat()

	if (
		state == State.KNOCKED_DOWN
		and knockdown_inertia_active
	):
		return

	knockback_velocity = (
		direction.normalized()
		* minf(
			strength,
			_cfg(
				"maximum_knockback_speed",
				1200.0
			)
		)
	)

	knockback_left = (
		feedback_config.enemy_knockback_duration
		if feedback_config != null
		else 0.14
	)


func _process_knockback(
	delta: float
) -> bool:
	if knockdown_inertia_active:
		velocity = knockback_velocity

		var drag: float = (
			KNOCKDOWN_AIR_DRAG
			if knockdown_airborne
			else KNOCKDOWN_GROUND_DRAG
		)

		knockback_velocity = (
			knockback_velocity.move_toward(
				Vector2.ZERO,
				drag * delta
			)
		)

		return true

	if knockback_left <= 0.0:
		knockback_left = 0.0
		knockback_velocity = Vector2.ZERO
		return false

	velocity = knockback_velocity

	knockback_left = maxf(
		0.0,
		knockback_left - delta
	)

	knockback_velocity = (
		knockback_velocity.move_toward(
			Vector2.ZERO,
			_cfg(
				"character_knockback_drag",
				900.0
			) * delta
		)
	)

	if knockback_left <= 0.0:
		knockback_velocity = Vector2.ZERO

	return true

func _constrain_knockback_to_room_bounds() -> void:
	if _uses_continuous_ground_collision():
		return
	if dead:
		return

	# ROOM_TRANSIT是真正允许跨房间的状态。
	# 保险起见绝对不对它做边界限制。
	if state == State.ROOM_TRANSIT:
		return

	var safe_bounds: Rect2 = arena_bounds.grow(
		-KNOCKBACK_ROOM_BOUNDARY_MARGIN
	)

	# 避免异常的小Bounds。
	if (
		safe_bounds.size.x <= 1.0
		or safe_bounds.size.y <= 1.0
	):
		return

	var corrected_position: Vector2 = global_position

	var hit_left := false
	var hit_right := false
	var hit_top := false
	var hit_bottom := false

	# ========================================================
	# X边界
	# ========================================================

	if corrected_position.x < safe_bounds.position.x:
		corrected_position.x = safe_bounds.position.x
		hit_left = true

	elif corrected_position.x > safe_bounds.end.x:
		corrected_position.x = safe_bounds.end.x
		hit_right = true

	# ========================================================
	# Y边界
	# ========================================================

	if corrected_position.y < safe_bounds.position.y:
		corrected_position.y = safe_bounds.position.y
		hit_top = true

	elif corrected_position.y > safe_bounds.end.y:
		corrected_position.y = safe_bounds.end.y
		hit_bottom = true

	# 没越界就什么都不做。
	if (
		not hit_left
		and not hit_right
		and not hit_top
		and not hit_bottom
	):
		return

	global_position = corrected_position

	# ========================================================
	# 像撞墙一样反弹
	#
	# 只反转正在朝房间外运动的对应分量，
	# 避免已经往房间内部移动时再次翻转。
	# ========================================================

	if hit_left and knockback_velocity.x < 0.0:
		knockback_velocity.x = (
			-knockback_velocity.x
			* KNOCKDOWN_WALL_BOUNCE_RETENTION
		)

	elif hit_right and knockback_velocity.x > 0.0:
		knockback_velocity.x = (
			-knockback_velocity.x
			* KNOCKDOWN_WALL_BOUNCE_RETENTION
		)

	if hit_top and knockback_velocity.y < 0.0:
		knockback_velocity.y = (
			-knockback_velocity.y
			* KNOCKDOWN_WALL_BOUNCE_RETENTION
		)

	elif hit_bottom and knockback_velocity.y > 0.0:
		knockback_velocity.y = (
			-knockback_velocity.y
			* KNOCKDOWN_WALL_BOUNCE_RETENTION
		)

	velocity = knockback_velocity

func _receive_flying_enemy_impact(
	impact_direction: Vector2,
	impact_speed: float,
	source_position: Vector2
) -> void:
	if dead or not is_damage_runtime_active():
		return

	if impact_speed < KNOCKDOWN_ENEMY_IMPACT_MIN_SPEED:
		return

	var direction: Vector2 = (
		impact_direction.normalized()
		if impact_direction.length_squared() > 0.001
		else source_position.direction_to(global_position)
	)

	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	var base_damage: float = _cfg(
		"secondary_collision_damage",
		8.0
	)

	var damage_multiplier: float = remap(
		clampf(
			impact_speed,
			KNOCKDOWN_ENEMY_IMPACT_MIN_SPEED,
			KNOCKDOWN_MAX_HORIZONTAL_SPEED
		),
		KNOCKDOWN_ENEMY_IMPACT_MIN_SPEED,
		KNOCKDOWN_MAX_HORIZONTAL_SPEED,
		0.75,
		1.75
	)

	var collision_damage: float = (
		base_damage
		* damage_multiplier
	)

	var transfer_force: float = (
		impact_speed
		* KNOCKDOWN_ENEMY_TRANSFER_RETENTION
		/ maxf(
			KNOCKDOWN_FORCE_TO_HORIZONTAL_SPEED,
			0.001
		)
	)

	transfer_force = clampf(
		transfer_force,
		210.0,
		1200.0
	)

	if has_method("_remember_death_burst"):
		call(
			"_remember_death_burst",
			direction,
			transfer_force,
			&"secondary_collision"
		)

	_apply_secondary_collision_damage(
		collision_damage,
		direction,
		transfer_force
	)

	if dead:
		return

	start_knockdown(
		direction,
		&"enemy_collision",
		transfer_force
	)


func _handle_knockback_collisions() -> void:
	if get_slide_collision_count() <= 0:
		return

	var impact_velocity: Vector2 = knockback_velocity
	var impact_speed: float = impact_velocity.length()

	if impact_speed <= 0.001:
		return

	var impact_direction: Vector2 = (
		impact_velocity.normalized()
	)

	var environment_normal_sum := Vector2.ZERO
	var hit_environment := false
	var hit_enemy := false
	var hit_pushable_prop := false

	for index in range(
		get_slide_collision_count()
	):
		var collision := get_slide_collision(
			index
		)

		if collision == null:
			continue

		var normal: Vector2 = (
			collision.get_normal().normalized()
		)

		var collider := collision.get_collider()

		if impact_velocity.dot(normal) >= 0.0:
			continue

		if collider is EmployeeEnemy:
			var other := collider as EmployeeEnemy

			if (
				other == self
				or other.dead
				or not other.is_damage_runtime_active()
			):
				continue

			if (
				enemy_body_collision_cooldown_left > 0.0
				or other.enemy_body_collision_cooldown_left > 0.0
			):
				continue

			if (
				impact_speed
				< KNOCKDOWN_ENEMY_IMPACT_MIN_SPEED
			):
				continue

			enemy_body_collision_cooldown_left = (
				KNOCKDOWN_ENEMY_COLLISION_COOLDOWN
			)

			other.enemy_body_collision_cooldown_left = (
				KNOCKDOWN_ENEMY_COLLISION_COOLDOWN
			)

			other._receive_flying_enemy_impact(
				impact_direction,
				impact_speed,
				global_position
			)

			hit_enemy = true

			knockback_velocity *= (
				KNOCKDOWN_ENEMY_SOURCE_RETENTION
			)

			continue

		if (
			collider is RigidBody2D
			and (
				collider as RigidBody2D
			).is_in_group(
				&"pushable_prop"
			)
		):
			var prop := collider as RigidBody2D
			var external_impulse := impact_speed * _cfg(
				"furniture_prop_impulse_multiplier",
				0.65
			)
			if prop.has_method(&"apply_external_impulse"):
				prop.call(&"apply_external_impulse", -normal, external_impulse)
			else:
				prop.apply_central_impulse(-normal * external_impulse)

			environment_normal_sum += normal
			hit_environment = true
			hit_pushable_prop = true
			continue

			environment_normal_sum += normal
		hit_environment = true

	if hit_enemy:
		var body_impact_now_msec := Time.get_ticks_msec()
		if body_impact_now_msec - last_body_impact_sfx_msec >= 80:
			last_body_impact_sfx_msec = body_impact_now_msec
			SFX.play_event(&"body_impact")

	if hit_environment:
		var minimum_damage_speed: float = 80.0

		if (
			impact_speed >= minimum_damage_speed
			and secondary_collision_cooldown_left <= 0.0
		):
			secondary_collision_cooldown_left = _cfg(
				"secondary_collision_cooldown",
				0.35
			)

			var base_damage: float = _cfg(
				"secondary_collision_damage",
				8.0
			)

			var damage_multiplier: float = remap(
				clampf(
					impact_speed,
					80.0,
					KNOCKDOWN_MAX_HORIZONTAL_SPEED
				),
				80.0,
				KNOCKDOWN_MAX_HORIZONTAL_SPEED,
				1.0,
				2.0
			)

			_apply_secondary_collision_damage(
				base_damage * damage_multiplier,
				impact_direction,
				impact_speed
			)

			if dead:
				return

	if (
		hit_environment
		and environment_normal_sum.length_squared() > 0.001
	):
		var impact_now_msec := Time.get_ticks_msec()
		if impact_now_msec - last_environment_impact_sfx_msec >= 100:
			last_environment_impact_sfx_msec = impact_now_msec
			SFX.play_event(&"furniture_impact" if hit_pushable_prop else &"wall_impact")
		var collision_normal: Vector2 = (
			environment_normal_sum.normalized()
		)

		if (
			knockback_velocity.dot(
				collision_normal
			) < 0.0
		):
			var retention: float = (
				KNOCKDOWN_WALL_BOUNCE_RETENTION
				if knockdown_inertia_active
				else _cfg(
					"character_knockback_bounce_retention",
					0.35
				)
			)

			knockback_velocity = (
				knockback_velocity.bounce(
					collision_normal
				)
				* retention
			)

	if (
		hit_enemy
		and knockback_velocity.length()
		< KNOCKDOWN_SETTLE_HORIZONTAL_SPEED
	):
		knockback_velocity = Vector2.ZERO


func _apply_secondary_collision_damage(
	amount: float,
	burst_direction: Vector2 = Vector2.ZERO,
	burst_force: float = -1.0
) -> void:
	if dead or amount <= 0.0:
		return
	var secondary_direction := burst_direction.normalized()
	if secondary_direction.length_squared() <= 0.001:
		secondary_direction = knockback_velocity.normalized()
	if secondary_direction.length_squared() <= 0.001:
		secondary_direction = Vector2.RIGHT
	_remember_death_burst(
		secondary_direction,
		maxf(
			burst_force if burst_force > 0.0 else knockback_velocity.length(),
			_cfg("secondary_collision_damage", 8.0)
		),
		&"secondary_collision"
	)

	var before := current_health

	current_health = maxf(
		0.0,
		current_health - amount
	)

	var actual := before - current_health

	if actual <= 0.0:
		return
	SFX.play_event(&"enemy_hit")

	if current_health <= 0.0:
		var lethal_world := _get_world()
		if lethal_world != null and lethal_world.has_method("spawn_black_blood"):
			var secondary_blood_result: Variant = lethal_world.call(
				"spawn_black_blood",
				global_position,
				secondary_direction,
				true,
				int(get_meta(&"dream_room_id", -1)),
				_blood_intensity_for_source(&"secondary_collision")
			)
			if not (secondary_blood_result is bool) or secondary_blood_result == true:
				impact_blood_spawned = true
		_die()
		return

	_start_bleeding_trail()

	if health_bar != null and feedback_config != null:
		health_bar.show_after_damage(
			current_health,
			maximum_health,
			feedback_config.enemy_hp_bar_visible_duration
		)

	hit_flash_left = (
		feedback_config.enemy_hit_flash_seconds
		if feedback_config != null
		else 0.08
	)

	hit_scale_left = (
		feedback_config.enemy_hit_scale_seconds
		if feedback_config != null
		else 0.12
	)

	show_emoji(
		&"hit",
		0.6,
		4
	)

	var world := _get_world()

	if world != null:
		if world.has_method("spawn_black_blood"):
			var blood_direction := knockback_velocity.normalized()

			if blood_direction.length_squared() <= 0.001:
				blood_direction = Vector2.RIGHT

			world.spawn_black_blood(
				global_position,
				blood_direction,
				false,
				int(get_meta(&"dream_room_id", -1)),
				_blood_intensity_for_source(&"secondary_collision")
			)

		if world.has_method("request_hit_stop"):
			world.request_hit_stop(&"heavy")


func _uses_run_speed() -> bool:
	match state:
		State.SEEK_WEAPON, State.FLEE, State.INVESTIGATE_GUNSHOT, State.ATTACK_PLAYER:
			return true
		State.ALERT:
			return hostile
		State.MOVE_TO_DOOR, State.ROOM_TRANSIT:
			return route_run_mode
		_:
			return false


func _get_current_move_speed() -> float:
	var speed_multiplier := 1.0
	if _uses_run_speed():
		speed_multiplier = _cfg("employee_run_speed_multiplier", 1.5)
	return movement_speed * movement_speed_multiplier * speed_multiplier


func _steer_toward(
	destination: Vector2,
	use_artificial_avoidance: bool = true
) -> Vector2:
	var navigation_world := _get_world()
	if navigation_world != null and navigation_world.has_method("get_employee_navigation_target"):
		destination = navigation_world.call("get_employee_navigation_target", self, destination)
	var speed_value := _get_current_move_speed()

	if (
		steering_commit_left > 0.0
		and global_position.distance_to(
			steering_waypoint
		) > 5.0
	):
		return _with_local_separation(
			global_position.direction_to(
				steering_waypoint
			) * speed_value
		)

	var direct := global_position.direction_to(
		destination
	)

	if direct.length_squared() <= 0.001:
		return Vector2.ZERO

	var world := _get_world()

	if (
		use_artificial_avoidance
		and world != null
		and world.has_method(
			"is_employee_position_clear"
		)
	):
		var probe := (
			global_position
			+ direct * 20.0
		)

		if not world.is_employee_position_clear(
			probe,
			self
		):
			# Preserve the pathfinder's destination and solve only this local wall
			# contact.  Forward-left/right and side candidates are checked against
			# the authoritative room-floor/wall query; no global position is ever
			# clamped or teleported.
			var candidate_angles := [
				deg_to_rad(-42.0),
				deg_to_rad(42.0),
				deg_to_rad(-82.0),
				deg_to_rad(82.0),
			]
			if _steering_identity() % 2 == 0:
				candidate_angles.reverse()
			var chosen := Vector2.ZERO
			var best_score := -INF
			for angle in candidate_angles:
				var candidate_direction := direct.rotated(float(angle)).normalized()
				var candidate_point := global_position + candidate_direction * 30.0
				if not world.is_employee_position_clear(candidate_point, self):
					continue
				var score := candidate_direction.dot(direct)
				if score > best_score:
					best_score = score
					chosen = candidate_direction
			if chosen == Vector2.ZERO:
				chosen = -direct

			steering_waypoint = global_position + chosen * 30.0

			steering_commit_left = _cfg(
				"employee_steering_commit_time",
				0.40
			)

			return _with_local_separation(
				global_position.direction_to(
					steering_waypoint
				) * speed_value
			)

	return _with_local_separation(
		direct * speed_value
	)


func _update_local_separation(
	delta: float
) -> void:
	if (
		state in [
			State.MOVE_TO_DOOR,
			State.ROOM_TRANSIT,
			State.KNOCKED_DOWN,
			State.GETTING_UP
		]
		or not room_runtime_active
		or (state == State.NEUTRAL_WANDER and is_instance_valid(target) and global_position.distance_squared_to(target.global_position) > 250000.0)
	):
		cached_separation_velocity = Vector2.ZERO
		return

	separation_query_left -= delta

	if separation_query_left > 0.0:
		return

	separation_query_left = 0.28

	if _separation_shape == null:
		_separation_shape = CircleShape2D.new()
		_separation_query = PhysicsShapeQueryParameters2D.new()
		_separation_query.shape = _separation_shape
		_separation_query.collide_with_bodies = true
		_separation_query.collide_with_areas = false
	_separation_shape.radius = separation_radius
	_separation_query.transform = Transform2D(0.0, global_position)
	# Player layer 1 participates in separation even while its damage gate is
	# invulnerable.  This is physical occupancy only; no damage or teleport is
	# introduced here.
	_separation_query.collision_mask = 1 | 2
	_separation_query.exclude = [get_rid()]

	var separation := Vector2.ZERO

	for result in get_world_2d().direct_space_state.intersect_shape(
		_separation_query,
		8
	):
		var other_body := result.get("collider") as Node2D
		if other_body == null:
			continue
		var other := other_body as EmployeeEnemy
		if other != null and (other.dead or not other.room_runtime_active):
			continue
		if other == null and other_body != target:
			continue

		var away := (
			global_position
			- other_body.global_position
		)

		var distance := away.length()

		if distance <= 0.001:
			away = (
				Vector2.LEFT
				if _steering_identity()
				< int(other_body.get_meta(&"test_steering_identity",other_body.get_instance_id()))
				else Vector2.RIGHT
			)

			distance = 0.0

		separation += (
			away.normalized()
			* (
				1.0
				- clampf(
					distance
						/ separation_radius,
					0.0,
					1.0
				)
			)
		)

	cached_separation_velocity = (
		separation.normalized()
		* separation_strength
		if separation.length_squared() > 0.001
		else Vector2.ZERO
	)


func _with_local_separation(
	desired_velocity: Vector2
) -> Vector2:
	if (
		state in [
			State.MOVE_TO_DOOR,
			State.ROOM_TRANSIT,
			State.KNOCKED_DOWN,
			State.GETTING_UP
		]
		or cached_separation_velocity.length_squared()
		<= 0.001
	):
		return desired_velocity

	if desired_velocity.length_squared() <= 0.001:
		return cached_separation_velocity

	return (
		desired_velocity
		+ cached_separation_velocity
	).normalized() * desired_velocity.length()


func _update_stuck_detection(
	delta: float
) -> void:
	if (
		dead
		or state not in [
			State.NEUTRAL_WANDER,
			State.SEEK_WEAPON,
			State.FLEE,
			State.INVESTIGATE_GUNSHOT,
			State.MOVE_TO_DOOR,
			State.ATTACK_PLAYER
		]
	):
		stuck_elapsed = 0.0
		stuck_anchor = global_position
		return
	# Attack can legitimately hold still while charging or firing from a valid
	# range.  Only accumulate the shared stuck timer when this tick requested a
	# real chase/reposition move.
	if state == State.ATTACK_PLAYER and (ranged_attack_windup_pending or not attack_movement_intent):
		stuck_elapsed = 0.0
		stuck_anchor = global_position
		return
	if state == State.NEUTRAL_WANDER and global_position.distance_to(wander_target) <= 8.0:
		stuck_elapsed = 0.0
		stuck_anchor = global_position
		return

	stuck_elapsed += delta

	if (
		stuck_elapsed
		< _cfg(
			"employee_stuck_detection_seconds",
			0.55
		)
	):
		return

	var moved := global_position.distance_to(
		stuck_anchor
	)

	stuck_elapsed = 0.0
	stuck_anchor = global_position

	if (
		moved
		>= _cfg(
			"employee_stuck_distance_threshold",
			2.5
		)
	):
		return

	steering_commit_left = 0.0
	decision_cooldown_left = 0.0

	if state == State.MOVE_TO_DOOR:
		# Abandon a blocked approach rather than repeatedly steering into the
		# same frame/corner. Bosses may choose another flee door; ordinary
		# employees fall back to attack or weapon search instead.
		if _can_use_flee_behavior() and (hostile or gunshot_flee_left > 0.0):
			state = State.FLEE
		elif hostile and not held_weapon_id.is_empty():
			state = State.ATTACK_PLAYER
		elif hostile:
			state = State.SEEK_WEAPON
		else:
			state = State.NEUTRAL_WANDER
		route_target_room_id = -1
		route_direction = &""
		wander_target = _request_wander_target()
		wander_wait_left = 0.35

	elif state == State.ATTACK_PLAYER:
		# A doorway/corner can make the locally chosen attack point unreachable
		# even though the target is still valid.  Re-evaluate a short legal flank
		# point first, then use the existing room route when the target is across a
		# door.  No position or collision layer is modified here.
		_recover_attack_stuck()

	elif state == State.NEUTRAL_WANDER:
		steering_waypoint = global_position
		wander_target = _request_wander_target()
		wander_wait_left = 0.25
	elif (
		state == State.SEEK_WEAPON
		and not _weapon_target_is_valid()
	):
		state = State.ALERT

	elif state == State.FLEE:
		# Let the next update choose a fresh connected door/fallback target.
		decision_cooldown_left = 0.0
		steering_waypoint = global_position

	elif state == State.INVESTIGATE_GUNSHOT:
		# A blocked investigation should abandon the sound target rather than
		# repeatedly push into a wall or corner.
		gunshot_investigate_left = 0.0
		gunshot_source_room_id = -1
		panic_decision_room_id = -1
		state = State.NEUTRAL_WANDER
		wander_target = _request_wander_target()
		wander_wait_left = 0.25


func _recover_attack_stuck() -> void:
	steering_commit_left = 0.0
	decision_cooldown_left = 0.0
	strafe_time_left = 0.0
	var target_position := _get_known_target_position()
	var toward := global_position.direction_to(target_position)
	if toward.length_squared() <= 0.001:
		return
	var world := _get_world()
	var candidate_directions: Array[Vector2] = [
		toward.rotated(PI * 0.5),
		toward.rotated(-PI * 0.5),
		toward.rotated(PI * 0.75),
		toward.rotated(-PI * 0.75),
		-toward,
	]
	if _steering_identity() % 2 == 0:
		candidate_directions.reverse()
	if world != null and world.has_method("is_employee_position_clear"):
		for candidate in candidate_directions:
			var point := global_position + candidate.normalized() * 30.0
			if not world.is_employee_position_clear(point, self):
				continue
			steering_waypoint = point
			steering_commit_left = _cfg("employee_steering_commit_time", 0.40)
			return
	var my_room := int(get_meta("dream_room_id", -1))
	if last_known_room >= 0 and last_known_room != my_room:
		var openly_connected := false
		if world != null and world.has_method("are_rooms_openly_connected"):
			openly_connected = bool(world.call("are_rooms_openly_connected", my_room, last_known_room))
		if not openly_connected:
			_begin_route_to_room(last_known_room)
			return
	# Same-room fallback: keep the combat state but commit a fresh wander point
	# so the next attack update does not repeat the identical doorway probe.
	var fallback := _request_wander_target()
	if fallback != Vector2.ZERO and fallback.distance_to(global_position) > 8.0:
		steering_waypoint = fallback
		steering_commit_left = _cfg("employee_steering_commit_time", 0.40)
	else:
		steering_waypoint = global_position


# ============================================================
# 人物动画
#
# 正常移动时：
# CharacterVisual整体上下蹦跳。
# 双腿继续交替。
# WeaponRoot同步上下移动。
#
# CharacterBody2D、CollisionShape2D、Shadow完全不动。
#
# 击倒 / 起身时不修改CharacterVisual.position，
# 让击飞假高度系统独占控制。
# ============================================================

func _update_human_animation(
	delta: float
) -> void:
	var movement_blocked: bool = (
		sky_drop_active
		or
		state in [
			State.KNOCKED_DOWN,
			State.GETTING_UP
		]
		or knockdown_inertia_active
	)

	var moving: bool = (
		velocity.length_squared() > 4.0
		and not dead
		and not movement_blocked
	)
	_sync_enemy_hands_visibility()
	body_pivot.rotation = 0.0

	if moving:
		var walk_cycles_per_second := _cfg(
			"player_walk_cycles_per_second",
			1.5
		)
		if _uses_run_speed():
			walk_cycles_per_second *= _cfg(
				"employee_run_speed_multiplier",
				1.5
			)
		walk_phase = fmod(
			walk_phase
			+ delta
			* walk_cycles_per_second
			* TAU,
			TAU
		)

	else:
		walk_phase = move_toward(
			walk_phase,
			0.0,
			delta * 8.0
		)

	# ========================================================
	# 双腿交替
	# ========================================================

	var stride: float = (
		sin(walk_phase) * 2.0
		if moving
		else 0.0
	)

	left_leg.position = (
		left_leg_base_position
		+ Vector2(
			0.0,
			stride
		)
	)

	right_leg.position = (
		right_leg_base_position
		+ Vector2(
			0.0,
			-stride
		)
	)

	# ========================================================
	# 整体走路蹦跳
	#
	# abs(sin)使左右脚交替时各产生一次蹦跳。
	# ========================================================

	var walk_bounce: float = 0.0

	if moving:
		walk_bounce = (
			-absf(
				sin(walk_phase)
			)
			* WALK_BOUNCE_HEIGHT
		)

	if not movement_blocked:
		character_visual.position = (
			character_visual_base_position
			+ Vector2(
				0.0,
				walk_bounce
			)
		)

		weapon_root.position = (
			weapon_root_base_position
			+ Vector2(
				0.0,
				walk_bounce
			)
		)
		body_pivot.position = body_pivot_base_position

	# ========================================================
	# 身体内部轻微Bob
	# ========================================================

	var body_bob: float = 0.0

	if moving:
		body_bob = (
			-absf(
				sin(walk_phase)
			)
			* WALK_BODY_BOB_HEIGHT
		)

	elif not movement_blocked:
		body_bob = (
			sin(
				Time.get_ticks_msec()
				* 0.0018
			)
			* 0.35
		)

	if not movement_blocked:
		head.position = (
			head_base_position
			+ Vector2(
				0.0,
				body_bob
			)
		)

		body.position = (
			body_base_position
			+ Vector2(
				0.0,
				body_bob
			)
		)
	else:
		head.position = head_base_position
		body.position = body_base_position
		body_pivot.position = body_pivot_base_position

	left_hand.position = left_hand_base_position
	right_hand.position = right_hand_base_position
	_update_enemy_melee_visual(delta, movement_blocked)
	_update_enemy_unarmed_visual(movement_blocked)

	# ========================================================
	# 朝向
	# ========================================================

	var motion := velocity

	if motion.length_squared() > 0.1:
		last_facing_direction = motion.normalized()
		_set_back_facing(
			motion.y < -0.2
		)

	var horizontal_sign: float = (
		-1.0
		if motion.x < -0.2
		else 1.0
	)

	character_visual.scale.x = (
		absf(
			base_visual_scale.x
		)
		* horizontal_sign
	)

	# Character size is fixed during normal hit/attack/movement feedback.  Every
	# EmployeeEnemy, including the boss behavior variant, uses the shared Player
	# visual-scale baseline; no per-frame hit scaling can accumulate or leave the
	# actor at a different size.
	character_visual.scale.y = absf(base_visual_scale.y)


func _update_enemy_unarmed_visual(movement_blocked: bool) -> void:
	if not unarmed_attack_active or movement_blocked or dead or not held_weapon_id.is_empty():
		return
	var progress := clampf(unarmed_attack_elapsed / 0.24, 0.0, 1.0)
	var strike := sin(progress * PI)
	var direction := _get_gameplay_facing_direction()
	if _has_known_target():
		direction = global_position.direction_to(_get_known_target_position())
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	last_facing_direction = direction.normalized()
	var local_direction := Vector2(signf(direction.x), 0.0)
	if local_direction.x == 0.0:
		local_direction = Vector2.RIGHT
	if unarmed_attack_kind == &"employee_punch":
		var hand_offset := local_direction * (10.0 * strike)
		if unarmed_attack_left:
			left_hand.position = left_hand_base_position + hand_offset
			right_hand.position = right_hand_base_position - local_direction * (2.0 * strike)
		else:
			right_hand.position = right_hand_base_position + hand_offset
			left_hand.position = left_hand_base_position - local_direction * (2.0 * strike)
		body_pivot.rotation = -local_direction.x * deg_to_rad(4.0) * strike
		return
	# Kick only drives the active foot; the support foot remains at its base.
	var foot_offset := local_direction * (8.0 * strike) + Vector2(0.0, -2.0 * strike)
	if unarmed_attack_left:
		left_leg.position = left_leg_base_position + foot_offset
	else:
		right_leg.position = right_leg_base_position + foot_offset
	body_pivot.rotation = local_direction.x * deg_to_rad(3.0) * strike


func _set_back_facing(
	back: bool
) -> void:
	facing_back = back
	## The new atlas supplies one canonical direction only.  Horizontal facing
	## is still mirrored by CharacterVisual.scale.x; looking upward therefore
	## reuses the same pixel parts instead of referencing the removed old atlas.
	_set_enemy_head_frame(enemy_head_frame_index)


func show_emoji(
	emoji_type: StringName,
	duration: float,
	priority: int
) -> void:
	if (
		emoji_sprite == null
		or (
			emoji_sprite.visible
			and priority < emoji_priority
		)
	):
		return

	match emoji_type:
		&"neutral":
			emoji_sprite.texture = EMOJI_NEUTRAL

		&"hit":
			emoji_sprite.texture = EMOJI_HIT

		&"flee":
			emoji_sprite.texture = EMOJI_FLEE

		&"attack":
			emoji_sprite.texture = EMOJI_ATTACK

		&"knockdown":
			emoji_sprite.texture = EMOJI_KNOCKED_DOWN

		_:
			return

	emoji_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	emoji_sprite.visible = true

	emoji_time_left = maxf(
		duration,
		0.05
	)

	emoji_priority = priority


func _update_emoji(
	delta: float
) -> void:
	if emoji_sprite.visible:
		emoji_time_left = maxf(
			0.0,
			emoji_time_left - delta
		)

		if emoji_time_left <= 0.0:
			emoji_sprite.hide()
			emoji_priority = 0

	if (
		state != State.NEUTRAL_WANDER
		or emoji_sprite.visible
	):
		return

	neutral_emoji_cooldown -= delta

	if neutral_emoji_cooldown <= 0.0:
		show_emoji(
			&"neutral",
			random.randf_range(
				0.8,
				1.5
			),
			1
		)

		neutral_emoji_cooldown = random.randf_range(
			6.0,
			12.0
		)


func _update_state_emoji() -> void:
	if state == observed_state:
		return

	observed_state = state

	match state:
		State.FLEE:
			show_emoji(
				&"flee",
				1.1,
				3
			)

		State.ATTACK_PLAYER:
			show_emoji(
				&"attack",
				1.0,
				2
			)

		State.KNOCKED_DOWN:
			show_emoji(
				&"knockdown",
				minf(
					_cfg(
						"employee_knockdown_duration",
						1.2
					),
					1.0
				),
				5
			)


func _setup_health_bar() -> void:
	health_bar = WORLD_HEALTH_BAR.new()
	health_bar.name = "EnemyHPBar"
	health_bar.z_index = 20

	add_child(
		health_bar
	)

	health_bar.configure_values(
		20.0,
		3.0,
		Vector2(0, 7),
		current_health,
		maximum_health
	)


func get_damage_number_offset() -> Vector2:
	return Vector2(
		0,
		-48.0
		* character_visual.scale.y
	)


func get_hurt_radius() -> float:
	return (
		10.0
		* absf(
			character_visual.scale.x
		)
	)


func distance_to_hurtbox(
	world_point: Vector2
) -> float:
	return maxf(
		0.0,
		global_position.distance_to(
			world_point
		)
		- get_hurt_radius()
	)


func set_movement_speed_multiplier(
	multiplier: float
) -> void:
	movement_speed_multiplier = maxf(
		0.0,
		multiplier
	)


func set_auto_aim_locked(
	locked: bool
) -> void:
	auto_aim_locked = locked

	if outline_controller != null:
		outline_controller.set_locked(
			locked
		)


func is_hostile() -> bool:
	return hostile


func _release_weapon_reservation() -> void:
	var world := _get_world()
	# A pickup can be freed by the world (for example after a Player swap)
	# before this Enemy's next AI tick releases its soft reservation.  Passing a
	# stale Object reference through a typed method call raises before the world
	# can remove the request.  Keep the employee filter, but only pass a live
	# pickup reference when one still exists; the world can then cancel all
	# requests belonging to this employee.
	var live_weapon_target: Node2D = null
	if is_instance_valid(weapon_target):
		live_weapon_target = weapon_target
	if world != null and world.has_method("cancel_enemy_world_weapon_pickup"):
		world.call("cancel_enemy_world_weapon_pickup", self, live_weapon_target)
	if is_instance_valid(
		weapon_target
	):
		weapon_target.release_reservation(
			self
		)

	weapon_target = null
	weapon_target_room_id = -1
	weapon_pickup_request_pending = false


func _weapon_desired_range() -> float:
	match held_weapon_id:
		"lucille":
			return 30.0

		"books":
			return 30.0

		"shotgun":
			return 140.0

		"assault_rifle":
			return 380.0

	return 250.0


func _weapon_max_range() -> float:
	match held_weapon_id:
		"lucille":
			return (
				_cfg(
					"lucille_attack_range",
					30.0
				)
				+ 14.0
			)

		"books":
			return (
				_cfg(
					"books_attack_range",
					30.0
				)
				+ 14.0
			)

		"shotgun":
			return _cfg(
				"shotgun_max_distance",
				220.0
			)

		"assault_rifle":
			return _cfg(
				"assault_rifle_range",
				500.0
			)

	return _cfg(
		"basic_weapon_range",
		350.0
	)


func _is_otxo_mode() -> bool:
	if has_meta(&"otxo_mode"):
		return get_meta(&"otxo_mode") == true
	var world := _get_world()
	if world != null:
		if world.has_method("_is_otxo_mansion"):
			return world.call("_is_otxo_mansion") == true
		var config_obj = world.get("config")
		if config_obj != null and "map_generator_type" in config_obj:
			return config_obj.map_generator_type == "otxo_mansion"
	var cfg: DemoConfig = feedback_config
	if cfg == null and ResourceLoader.exists("res://resources/demo_config.tres"):
		cfg = preload("res://resources/demo_config.tres")
	if cfg != null and "map_generator_type" in cfg:
		return cfg.map_generator_type == "otxo_mansion"
	return true


func _get_world() -> Node:
	return get_tree().get_first_node_in_group(
		&"dream_world"
	)


func _exit_tree() -> void:
	# Release world-owned soft reservations before this Enemy leaves the tree.
	# The World also has a lazy stale-entry sweep, but doing the handoff here
	# prevents a freed holder/requester from occupying a doorway or pickup until
	# the next gameplay tick.
	var world := _get_world()
	if world != null and world.has_method("release_employee_door_transit"):
		world.call("release_employee_door_transit", self)
	_release_weapon_reservation()
	door_transit_granted = false
	door_transit_id = -1
	for tween in [
		reload_visual_tween,
		visual_tween,
		knockdown_visual_tween
	]:
		if (
			tween != null
			and tween.is_valid()
		):
			tween.kill()


func _cfg(
	property_name: StringName,
	fallback: float
) -> float:
	if feedback_config == null:
		return fallback

	var val: Variant = feedback_config.get(property_name)
	if val == null:
		return fallback

	return float(val)
