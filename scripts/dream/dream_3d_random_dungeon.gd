extends Node3D

signal dream_finished(summary: Dictionary)
signal profile_changed(profile: Dictionary)
signal weapon_equipped(weapon_id: String)
signal generation_progress(ratio: float, message: String)
signal elevator_floor_transition_completed(new_floor_index: int)
signal firearm_render_preparation_finished(report: Dictionary)
signal floor_exit_render_preparation_finished(report: Dictionary)
signal floor_loading_render_preparation_finished(report: Dictionary)

var room_visibility: Node
var target_highlight: Node
var run_interface: Node
var night_lighting: Node3D
@export var dynamic_shadows_enabled := true
var shadow_manager: Node3D
## Main sets this before attachment: the initial elevator must wait until
## first-use graphics have rendered behind the loading overlay.
var loading_render_preparation_pending := false
var last_firearm_render_preparation: Dictionary = {}
## 最顶层 HUD 画布（layer 20）。交互提示画在这里：作为 CanvasItem 它不参与
## 3D 光照、不接受阴影、不参与深度测试，因此永远清晰可见、永远置顶。
var ui_layer: CanvasLayer
var interaction_prompt: Label
const COMPACT_PROMPT = preload("res://scripts/ui/compact_interaction_prompt.gd")
var elevator_prompt_active := false
## Screen-space feedback for the currently equipped weapon.  The Player's
## legacy 2D label is hidden with GameplayCanvas in this 3D presentation, so
## this one follows the authoritative Player ground point through the active
## Camera3D without becoming a second gameplay/UI authority.
var weapon_name_popup: Label
var weapon_name_popup_time_left := 0.0
var weapon_name_popup_last_id := ""
var weapon_name_popup_last_usec := -1000000000
var _player_reloading := false
var objective_guidance: CanvasLayer
const WEAPON_NAME_POPUP_DURATION := 1.0
const WEAPON_NAME_POPUP_FADE_DURATION := 0.20
const WEAPON_NAME_POPUP_SIZE := Vector2(180.0, 22.0)
const WEAPON_NAME_POPUP_OFFSET := Vector2(-90.0, -52.0)
var interaction_resolver: DreamInteractionResolver
## 交互提示相对世界锚点的屏幕偏移，沿用原 2D Label 的 offset。
const INTERACTION_PROMPT_OFFSET := Vector2(-64.0, -32.0)
const INTERACTION_PROMPT_SIZE := Vector2(128.0, 18.0)
const CRISP_INTERACTION_FONT: Script = preload("res://scripts/ui/crisp_interaction_font.gd")

@export var persist_profile := true
@export var dream_layer_id: int = 1
var permanent_upgrades: Dictionary = {}
var profile_state: Dictionary = {}
var difficulty_day := 1
var is_sunday := false
var is_hungry_run := false
var run_stress_value := 0
var campaign_run := false
var configured_weapon_id := "basic"
var configured_weapon_ids: Array[String] = []

## Random 3D building presentation of the formal Dream gameplay.
##
## The macro layer first creates a sparse Room Graph, places independent rooms
## on a macro grid, and routes separate corridor floor cells between them.  The
## existing gameplay-cell maps remain authoritative for floor, wall, door,
## collision and path queries; the 2D gameplay actors are only presented in 3D.

const FLOOR_TILE_SCENE: PackedScene = preload("res://scenes/dream/3d/Floortile3D.tscn")
const FLOOR_MATERIAL: Material = preload("res://materials/dream3d/interiors_a_floor_material.tres")
const WALL_SCENE: PackedScene = preload("res://scenes/dream/3d/WallStraight3D.tscn")
const THEME_SCRIPT: Script = preload("res://scripts/dream/dream_room_environment_theme.gd")
const DOOR_SCENE: PackedScene = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
const EMPLOYEE_SCENE: PackedScene = preload("res://scenes/entities/employee_enemy.tscn")
const EMPLOYEE_CONFIG: DemoConfig = preload("res://resources/demo_config.tres")
var config: DemoConfig = EMPLOYEE_CONFIG
var _3d_firearm_profile_applied := false
# OTXO-informed design targets, not claimed slot-to-gun reverse mappings.
const PISTOL_FIRE_RATE_3D := 4.2
const RIFLE_FIRE_RATE_3D := 9.0
const SHOTGUN_FIRE_RATE_3D := 2.4
const FIREARM_PROJECTILE_SPEED_3D := 1500.0
const PISTOL_RANGE_SCALE_3D := 1024.0 / 350.0
const RIFLE_RANGE_SCALE_3D := 1536.0 / 500.0
const SHOTGUN_RANGE_SCALE_3D := 640.0 / 220.0
const BLACK_BLOOD_EFFECT: Script = preload("res://scripts/entities/black_blood_effect.gd")
const CORPSE_BLOOD_EMITTER: Script = preload("res://scripts/entities/corpse_blood_emitter.gd")
const BLOOD_AIRBORNE_CARRIER: Script = preload("res://scripts/dream/blood_airborne_carrier_3d.gd")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const WEAPON_VISUALS := preload("res://scripts/data/dream_gun_atlas.gd")
const ACTOR_DEPTH_BRIDGE_SCENE: PackedScene = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const PROJECTILE_CAPTURE_POOL = preload("res://scripts/dream/projectile_capture_pool.gd")
const MUZZLE_CAPTURE_POOL = preload("res://scripts/dream/muzzle_capture_pool.gd")
const SHELL_CAPTURE_POOL = preload("res://scripts/dream/shell_capture_pool.gd")
const FEEDBACK_CAPTURE_POOL = preload("res://scripts/dream/feedback_capture_pool.gd")
const BLOOD_GROUND_CAPTURE_POOL = preload("res://scripts/dream/blood_ground_capture_pool.gd")
const FLOOR_OBJECT_CAPTURE_POOL = preload("res://scripts/dream/floor_object_capture_pool.gd")
## Fallback muzzle/projectile presentation plane.  When an ActorDepthBridge is
## available, the live 2D muzzle is projected onto that actor's existing visual
## plane instead; these values are only for legacy/non-actor effects.
const PROJECTILE_MUZZLE_VISUAL_HEIGHT := 0.12
const PROJECTILE_MUZZLE_DEPTH_OFFSET := 0.0
const ACTOR_PROXY_SCRIPT: Script = preload("res://scripts/dream/player_physics_proxy_3d.gd")
const DIALOGUE_CAMERA_SCRIPT: Script = preload("res://scripts/dream/dream_3d_dialogue_camera.gd")
const MACRO_ROOM_GRAPH_SCRIPT: Script = preload("res://scripts/dream/dream_macro_room_graph.gd")
const OTXO_MANSION_GENERATOR_SCRIPT: Script = preload("res://scripts/dream/dream_otxo_mansion_generator.gd")
const OFFICE_SAMPLE_SCRIPT: Script = preload("res://scripts/dream/office_sample_floor.gd")
const OFFICE_LEVEL_PACK_SCRIPT: Script = preload("res://scripts/dream/office_level_pack_generator.gd")
@export var use_authored_office_sample := false
@export var approved_sample_art_enabled := false
const OFFICE_V2_GENERATOR_SCRIPT: Script = preload("res://scripts/dream/dream_office_v2_generator.gd")
const OTXO_ROOM_LAYOUT_PLANNER_SCRIPT: Script = preload("res://scripts/dream/otxo_room_layout_planner.gd")
@export var enhanced_room_dressing := true
const BREAKABLE_GLASS_WINDOW_SCRIPT: Script = preload("res://scripts/dream/breakable_glass_window_3d.gd")
const BOSS_KEY_SCENE: PackedScene = preload("res://scenes/dream/3d/BossKeyPickup.tscn")
## The legacy BossKey scene is deliberately reused as the pickup carrier for
## the new floor badge.  Its path/UID stay stable while the runtime metadata
## and prompt use Employee Badge semantics.
const EMPLOYEE_BADGE_SCENE: PackedScene = BOSS_KEY_SCENE
const ENVIRONMENT_DEBRIS_SCENE: PackedScene = preload("res://scenes/entities/environment_debris.tscn")
const WORLD_WEAPON_SCENE: PackedScene = preload("res://scenes/dream/world_weapon_pickup.tscn")
const WORLD_WEAPON_PICKUP_SCRIPT: Script = preload("res://scripts/dream/world_weapon_pickup.gd")
const THROW_TRAJECTORY_SCRIPT: Script = preload("res://scripts/dream/dream_throw_trajectory.gd")
const EXIT_ARROW_SCRIPT: Script = preload("res://scripts/dream/dream_exit_arrow.gd")
const BADGE_MARKER_SCRIPT: Script = preload("res://scripts/dream/employee_badge_marker.gd")
const DASH_AIM_PRESENTATION_SCRIPT: Script = preload("res://scripts/dream/dream_dash_aim_presentation.gd")
const SHELL_EFFECT_SCENE: PackedScene = preload("res://scenes/entities/shell_effect.tscn")
const MUZZLE_EFFECT_SCENE: PackedScene = preload("res://scenes/entities/weapon_muzzle_effect.tscn")
const FIREARM_IMPACT_SCENE: PackedScene = preload("res://scenes/dream/3d/FirearmImpactVisual3D.tscn")
const MAX_ACTIVE_FIREARM_IMPACT_VISUALS := 24
const COMBAT_FEEDBACK_SCENE: PackedScene = preload("res://scenes/entities/combat_feedback_effect.tscn")
const PROJECTILE_SEQUENCE_SCENE: PackedScene = preload("res://scenes/entities/projectile_sequence_effect.tscn")
const RUN_SETTLEMENT := preload("res://scripts/app/run_settlement.gd")
const FURNITURE_SCENE_PATHS: Array[String] = [
	"res://scenes/dream/props/desk.tscn",
	"res://scenes/dream/props/filing_cabinet_01.tscn",
	"res://scenes/dream/props/small_table_01.tscn",
	"res://scenes/dream/props/storage_cabinet_01.tscn",
	"res://scenes/dream/props/trash_can_01.tscn",
	"res://scenes/dream/props/wardrobe_01.tscn",
	"res://scenes/dream/props/fridge_01.tscn",
	"res://scenes/dream/props/bed_01.tscn",
	"res://scenes/dream/props/parcel_box_01.tscn",
	"res://scenes/dream/props/sticker_parcel_box_01.tscn",
	"res://scenes/dream/props/side_table_01.tscn",
	"res://scenes/dream/props/chair_02.tscn",
	"res://scenes/dream/props/floor_lamp_01.tscn",
	"res://scenes/dream/props/office_chair_01.tscn",
	"res://scenes/dream/props/chair.tscn",
]

const FURNITURE_3D_VISUAL_SCRIPT := preload("res://scripts/dream/furniture_3d_visual.gd")
const FURNITURE_3D_VISUAL_MAP: Dictionary = {
	"parcel_box_01": {
		"scene": preload("res://scenes/dream/3d/props/parcel_box_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_parcel_box_01.png")
	},
	"trash_can_01": {
		"scene": preload("res://scenes/dream/3d/props/trash_can_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_trash_can_01.png")
	},
	"small_table_01": {
		"scene": preload("res://scenes/dream/3d/props/small_table_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_small_table_01.png")
	},
	"filing_cabinet_01": {
		"scene": preload("res://scenes/dream/3d/props/filing_cabinet_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_filing_cabinet_01.png")
	},
	"sticker_parcel_box_01": {
		"scene": preload("res://scenes/dream/3d/props/sticker_parcel_box_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_sticker_parcel_box_01.png")
	},
	"storage_cabinet_01": {
		"scene": preload("res://scenes/dream/3d/props/storage_cabinet_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_storage_cabinet_01.png")
	},
	"wardrobe_01": {
		"scene": preload("res://scenes/dream/3d/props/wardrobe_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_wardrobe_01.png")
	},
	"fridge_01": {
		"scene": preload("res://scenes/dream/3d/props/fridge_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_fridge_01.png")
	},
	"side_table_01": {
		"scene": preload("res://scenes/dream/3d/props/side_table_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_side_table_01.png")
	},
	"desk": {
		"scene": preload("res://scenes/dream/3d/props/desk_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_desk.png")
	},
	"chair_02": {
		"scene": preload("res://scenes/dream/3d/props/chair_02_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_chair_02.png")
	},
	"floor_lamp_01": {
		"scene": preload("res://scenes/dream/3d/props/floor_lamp_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_floor_lamp_01.png")
	},
	"bed_01": {
		"scene": preload("res://scenes/dream/3d/props/bed_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_bed_01.png")
	},
	"office_chair_01": {
		"scene": preload("res://scenes/dream/3d/props/office_chair_01_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_office_chair_01.png")
	},
	"chair": {
		"scene": preload("res://scenes/dream/3d/props/chair_visual_3d.tscn"),
		"texture": preload("res://art/Dream/3d_props/tex_chair.png")
	},
}

const ARCHETYPE_FURNITURE_MAP: Dictionary = {
	"conference_large": ["res://scenes/dream/props/desk.tscn", "res://scenes/dream/props/chair_02.tscn", "res://scenes/dream/props/office_chair_01.tscn"],
	"meeting_small": ["res://scenes/dream/props/small_table_01.tscn", "res://scenes/dream/props/chair_02.tscn"],
	"manager": ["res://scenes/dream/props/desk.tscn", "res://scenes/dream/props/office_chair_01.tscn", "res://scenes/dream/props/wardrobe_01.tscn"],
	"small_office": ["res://scenes/dream/props/desk.tscn", "res://scenes/dream/props/office_chair_01.tscn"],
	"archive": ["res://scenes/dream/props/storage_cabinet_01.tscn", "res://scenes/dream/props/filing_cabinet_01.tscn"],
	"server": ["res://scenes/dream/props/storage_cabinet_01.tscn", "res://scenes/dream/props/filing_cabinet_01.tscn"],
	"pantry": ["res://scenes/dream/props/fridge_01.tscn", "res://scenes/dream/props/small_table_01.tscn", "res://scenes/dream/props/trash_can_01.tscn"],
	"restroom": ["res://scenes/dream/props/wardrobe_01.tscn", "res://scenes/dream/props/trash_can_01.tscn"],
	"printing": ["res://scenes/dream/props/storage_cabinet_01.tscn", "res://scenes/dream/props/side_table_01.tscn"],
	"lobby": [
		"res://scenes/dream/props/chair_02.tscn",
		"res://scenes/dream/props/side_table_01.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
	],
	"open_office": [
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/filing_cabinet_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
		"res://scenes/dream/props/chair.tscn",
	],
	"reception": [
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/chair_02.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
		"res://scenes/dream/props/small_table_01.tscn",
	],
	"conference": [
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/small_table_01.tscn",
		"res://scenes/dream/props/chair_02.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/filing_cabinet_01.tscn",
	],
	"lounge": [
		"res://scenes/dream/props/small_table_01.tscn",
		"res://scenes/dream/props/side_table_01.tscn",
		"res://scenes/dream/props/chair_02.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/fridge_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
	],
	"executive": [
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/wardrobe_01.tscn",
		"res://scenes/dream/props/storage_cabinet_01.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/side_table_01.tscn",
	],
	"storage": [
		"res://scenes/dream/props/parcel_box_01.tscn",
		"res://scenes/dream/props/sticker_parcel_box_01.tscn",
		"res://scenes/dream/props/storage_cabinet_01.tscn",
		"res://scenes/dream/props/filing_cabinet_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
	],
	"security": [
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/office_chair_01.tscn",
		"res://scenes/dream/props/filing_cabinet_01.tscn",
		"res://scenes/dream/props/storage_cabinet_01.tscn",
		"res://scenes/dream/props/trash_can_01.tscn",
	],
	"penthouse": [
		"res://scenes/dream/props/desk.tscn",
		"res://scenes/dream/props/wardrobe_01.tscn",
		"res://scenes/dream/props/bed_01.tscn",
		"res://scenes/dream/props/floor_lamp_01.tscn",
		"res://scenes/dream/props/small_table_01.tscn",
		"res://scenes/dream/props/side_table_01.tscn",
		"res://scenes/dream/props/chair_02.tscn",
	],
}

## Encounter content is resolved per room on first activation.  Bumping this
## version intentionally establishes a new deterministic encounter baseline
## without changing the Dungeon layout RNG stream.
const ENCOUNTER_GENERATION_VERSION := 1
const ENCOUNTER_SEED_SALT := 0x6D2B79F5
const FLOOR_SEED_SALT := 0x4F1BBCDC
const BADGE_CARRIER_SALT := 0x7A3D21E9

const CELL_PIXELS := 32.0
## Floor presentation epsilon shared by the static Ground Blood bridge and the
## dynamic airborne carrier.  The floor itself remains at the formal y=0
## surface; this tiny lift prevents z-fighting without changing gameplay.
const BLOOD_FLOOR_WORLD_Y := 0.02
## Office-only impact profile: an immediate broad floor splash and a short,
## fast droplet flight. The old 2D Dream keeps BlackBloodEffect defaults.
const OFFICE_BLOOD_IMPACT_MIN_INTENSITY := 1.7
const OFFICE_BLOOD_IMPACT_INTENSITY_SCALE := 1.45
const OFFICE_BLOOD_IMPACT_SPEED_SCALE := 1.45
const OFFICE_BLOOD_IMPACT_SPREAD_SCALE := 1.55
const OFFICE_BLOOD_AIRBORNE_SECONDS := 0.12
const OFFICE_BLOOD_POOL_GROWTH_SECONDS := 0.55
# Deposit window: initial splash within 132ms, followed by small local seepage.
# The start scale remains a compatibility parameter for the former reveal.
const OFFICE_BLOOD_POOL_START_SCALE := 1.05
const OFFICE_BLOOD_POOL_END_SCALE := 2.05
const INVALID_DOOR_COORDINATE := -1000000000
const INVALID_PILLAR_CELL := Vector2i(2147483647, 2147483647)
const WORLD_WALL_LAYER := 4
## Shared screen-space cutout slots. Slot 0 is reserved for Player whenever
## the Player is genuinely occluded; the remaining slots are nearest enemies and projectiles.
const OCCLUSION_CUTOUT_SLOT_COUNT := 8
# The formal Player root is the foot baseline while its circular body shape is
# offset upward by 13 px.  A thin edge collider therefore lets the visible feet
# cross the near wall before the body shape reports contact.  Give generated
# wall edges a conservative depth envelope so the complete 2D actor stays on
# the walkable side without changing the Player's own collision shape.
const WALL_COLLISION_THICKNESS := 16.0
# Actor-only air-wall layer for top-wall head clearance (bit value 32). Actors
# (Player/Enemy masks) include it; projectiles, blood rays, vision and doors
# never do, so only foot traffic stops short of the far wall.
const ACTOR_AIR_WALL_LAYER := 1 << 5
const NORMAL_WALL_HEIGHT := 1.0
const TALL_WALL_HEIGHT := 2.6
const WALL_THICKNESS := 0.5
## All generated 3D doors now span the same four-cell throat as the
## corridor.  Keep the corridor width and doorway width as separate values so
## future layouts can narrow a connection deliberately without reintroducing
## the old inclusive/off-by-one opening bug.
const DEFAULT_ROOM_DOOR_OPENING_CELLS := 4
const DEFAULT_CORRIDOR_DOOR_OPENING_CELLS := 4
const DOOR_OPENING_CELLS := DEFAULT_ROOM_DOOR_OPENING_CELLS
# The physical slab owns the complete tall-wall opening. There is deliberately
# no lintel/upper wall segment above a doorway.
const DOOR_HEIGHT := 2.2
const PLAYER_PROXY_3D_LAYER := 16
## Window visuals are selected from long, continuous exterior wall runs.  The
## spacing is deterministic (no per-edge random noise) and remains a visual
## presentation choice; the generated 2D wall edge is never removed.
const WINDOW_MIN_RUN_LENGTH := 6
const WINDOW_EDGE_SPACING := 5
## Keep the authored camera angle/follow rig intact while presenting the
## gameplay view at twice the previous proximity.  Dialogue zoom is applied
## on top of this authoritative base, never by rereading the modified size.
const GAMEPLAY_CAMERA_SIZE_MULTIPLIER := 0.5
## Perspective keeps the existing top-down rig and uses a narrow field of view
## to retain the accepted pixel-art framing without changing world sprite size.
const GAMEPLAY_CAMERA_FOV := 35.0
const PHONE_CAMERA := preload("res://scripts/dream/phone_camera_presentation.gd")
const DIALOGUE_CONVERSATION_MODE := 0
const DIALOGUE_SPEAKER_FOCUS_MODE := 1
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

@export_category("Building footprint")
@export var seed: int = 1337
@export_range(60, 120, 1) var min_building_width: int = 60
@export_range(60, 120, 1) var max_building_width: int = 90
@export_range(44, 90, 1) var min_building_height: int = 44
@export_range(44, 90, 1) var max_building_height: int = 70
@export var generation_bounds: Rect2i = Rect2i(-96, -76, 192, 152)

@export_category("BSP partition")
@export_range(4, 24, 1) var room_count: int = 12
@export_range(10, 40, 1) var min_room_width: int = 10
@export_range(10, 40, 1) var min_room_height: int = 10
@export_range(0.0, 1.0, 0.01) var subdivide_probability: float = 0.60
@export_range(1, 6, 1) var max_partition_depth: int = 4
## Gameplay corridor cross-section.  Keep this separate from the doorway throat
## even though the current formal 3D layout uses four cells for both.
@export_range(2, 8, 1) var corridor_width: int = 4
@export_range(2, 8, 1) var door_corner_clearance: int = 3
@export_range(2, 8, 1) var door_to_door_clearance: int = 3
@export_range(1, 100, 1) var max_layout_attempts: int = 40
@export_category("Macro room graph")
## The macro graph replaces BSP as the authoritative room placement layer.
## Small-room minimums above remain unchanged; these bounds only control the
## variation of graph-node rooms and the empty space between them.
## Centres remain far enough apart for the 22-cell large-room tier, while the
## resulting straight corridors are shorter than the former 26-cell layout.
@export_range(14, 36, 1) var macro_room_pitch: int = 24
@export_range(10, 24, 1) var macro_room_max_width: int = 16
@export_range(10, 24, 1) var macro_room_max_height: int = 16
@export_range(10, 24, 1) var medium_room_min_width: int = 16
@export_range(10, 24, 1) var medium_room_min_height: int = 16
@export_range(10, 28, 1) var medium_room_max_width: int = 20
@export_range(10, 28, 1) var medium_room_max_height: int = 20
@export_range(10, 28, 1) var large_room_min_width: int = 20
@export_range(10, 28, 1) var large_room_min_height: int = 20
@export_range(10, 30, 1) var large_room_max_width: int = 22
@export_range(10, 30, 1) var large_room_max_height: int = 22
@export_range(0.0, 1.0, 0.01) var small_room_weight: float = 0.45
@export_range(0.0, 1.0, 0.01) var medium_room_weight: float = 0.35
@export_range(0.0, 1.0, 0.01) var large_room_weight: float = 0.20
@export_range(0.0, 1.0, 0.01) var macro_square_weight: float = 0.22
@export_range(0.0, 1.0, 0.01) var macro_rectangle_weight: float = 0.26
@export_range(0.0, 1.0, 0.01) var macro_irregular_weight: float = 0.21
@export_range(0.0, 1.0, 0.01) var macro_stepped_weight: float = 0.15
@export_range(0.0, 1.0, 0.01) var macro_hollow_weight: float = 0.16
@export_range(0, 4, 1) var macro_max_loops: int = 2
@export_range(0.0, 1.0, 0.01) var macro_l_corridor_chance: float = 0.24
@export_category("Large space topology (small BSP limits unchanged)")
@export var rectangle_large_weight := 0.34
@export var irregular_large_weight := 0.33
@export var courtyard_large_weight := 0.33
@export var additional_door_chance := 0.55

@export_category("Boss selection")
@export_range(5, 30, 1) var boss_min_width: int = 8
@export_range(5, 30, 1) var boss_min_height: int = 8

@export_category("Runtime")
@export var generate_on_ready: bool = true
@export var show_debug_markers: bool = false
@export var log_layout_summary: bool = false
@export var disable_player_combat: bool = true
## The logical graph is generated once, but room presentation/content is built
## lazily for the current room.  This avoids constructing every room's meshes,
## lights and encounter actors during the initial loading spike.
@export var lazy_room_presentation: bool = true
@export_category("Random content")
@export var spawn_content: bool = false
@export_range(0.0, 0.08, 0.001) var furniture_density: float = 0.024
@export_range(0, 8, 1) var min_furniture_per_room: int = 0
@export_range(0, 12, 1) var max_furniture_per_room: int = 8
@export_range(0.0, 0.05, 0.001) var enemy_density: float = 0.007
@export_range(0, 6, 1) var min_enemies_per_room: int = 0
@export_range(0, 32, 1) var max_enemies_per_room: int = 12
@export_range(0, 64, 1) var global_enemy_cap: int = 32
var effective_global_enemy_cap: int = 32
## Reuse the formal Dream population cadence/target from DemoConfig; this
## timer only adapts that lifecycle to the continuous Random3D world.
## Legacy opt-in only.  Formal Random Dream rooms use a one-shot encounter
## descriptor and never replenish ordinary enemies after generation.
@export var enable_enemy_population_refill := false
@export_range(0.0, 1.0, 0.01) var key_spawn_clearance: float = 28.0
@export_range(0.0, 1.0, 0.01) var content_wall_clearance: float = 18.0
@export_range(1, 8, 1) var key_min_width: int = 7
@export_range(1, 8, 1) var key_min_height: int = 7
@export_range(1, 8, 1) var boss_candidate_min_width: int = 8
@export_range(1, 8, 1) var boss_candidate_min_height: int = 8
@export_category("Wall and door geometry")
@export_range(0.5, 12.0, 0.1) var wall_height: float = TALL_WALL_HEIGHT
@export_range(0.02, 2.0, 0.01) var wall_thickness: float = WALL_THICKNESS
# Legacy/editor fallback only.  Generated 3D doors derive their width from the
# topology opening cell count via `_door_width_for_edge()`.
@export_range(0.5, 12.0, 0.01) var door_width: float = 4.0
@export_range(0.5, 12.0, 0.05) var door_height: float = DOOR_HEIGHT
@export_range(1, 32, 1) var minimum_door_boundary_length: int = 7
@export_category("Physical door interaction")
@export_range(16.0, 96.0, 1.0) var door_interaction_range_pixels: float = 52.0
@export_range(20.0, 1200.0, 10.0) var door_push_force: float = 260.0
@export_range(20.0, 1600.0, 10.0) var door_kick_force: float = 700.0

@onready var generated_root: Node3D = $GeneratedBuildingRoot
@onready var floor_root: Node3D = $GeneratedBuildingRoot/FloorRoot
@onready var office_art_root: Node3D = get_node_or_null("GeneratedBuildingRoot/OfficeArtRoot")
@onready var wall_root: Node3D = $GeneratedBuildingRoot/WallRoot
@onready var door_root: Node3D = $GeneratedBuildingRoot/DoorRoot
@onready var debug_root: Node3D = $GeneratedBuildingRoot/DebugRoot
@onready var wake_exit_root: Node3D = $GeneratedBuildingRoot/WakeExitRoot
@onready var ceiling_light_root: Node3D = $GeneratedBuildingRoot/CeilingLightRoot
@onready var gameplay_world: Node2D = $GameplayCanvas/GameplayWorld
@onready var collision_root: Node2D = $GameplayCanvas/GameplayWorld/GeneratedCollisionRoot
@onready var furniture_root: Node2D = $GameplayCanvas/GameplayWorld/FurnitureRoot
@onready var enemy_root: Node2D = $GameplayCanvas/GameplayWorld/EnemyRoot
@onready var key_root: Node2D = $GameplayCanvas/GameplayWorld/KeyRoot
@onready var world_weapon_root: Node2D = $GameplayCanvas/GameplayWorld/WorldWeaponRoot
@onready var pickup_root: Node2D = $GameplayCanvas/GameplayWorld/PickupRoot
@onready var ground_debris_root: Node2D = $GameplayCanvas/GameplayWorld/GroundDebrisRoot
@onready var world_effects_root: Node2D = $GameplayCanvas/GameplayWorld/WorldEffectsRoot
@onready var player: CharacterBody2D = $GameplayCanvas/GameplayWorld/DreamPlayer
@onready var gameplay_canvas: CanvasLayer = $GameplayCanvas
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/Camera3D
var audio_listener_3d: AudioListener3D
@onready var actor_depth_viewport: SubViewport = $ActorDepthViewport
@onready var actor_depth_render_root: Node2D = $ActorDepthViewport/ActorDepthRenderRoot
@onready var player_depth_bridge: Node3D = $PlayerDepthVisual3D
@onready var player_physics_proxy: AnimatableBody3D = $PlayerPhysicsProxy3D
@onready var actor_depth_bridges_root: Node3D = $ActorDepthBridges
@onready var actor_physics_proxies_root: Node3D = $ActorPhysicsProxies

var building_rect: Rect2i
var rooms: Array[Dictionary] = []
var partitions: Array[Dictionary] = []
var corridors: Array[Dictionary] = []
var connections: Array[Dictionary] = []
## Macro topology is kept separately from the existing gameplay-cell maps.  A
## room id identifies only a combat room; corridor cells intentionally resolve
## to -1 and are never folded into a neighbouring room.
var macro_graph: Dictionary = {}
var room_states: Dictionary = {}
var corridor_states: Dictionary = {}
## Per-room encounter plans.  `enemy_spawns`/`drop_spawns` stay empty until the
## room is first activated, then remain cached for the rest of the run.
var room_encounters: Dictionary = {}
var room_layout_plans: Dictionary = {}
var room_ambient_spawned: Dictionary = {}
## Ambient debris requested while a physics signal is flushing queries.  Area2D
## instances must be added after the callback returns, otherwise Godot rejects
## their initial monitoring/shape registration.
var room_ambient_spawn_pending: Dictionary = {}
var floor_cells: Dictionary = {}
## Logical floor remains available to graph/path validators.  This filtered
## map is the 3D presentation source: room floors plus endpoint stubs, never
## the old room-to-room corridor slab.
var presentation_floor_cells: Dictionary = {}
var room_cells: Dictionary = {}
var corridor_cells: Dictionary = {}
## Cells removed from walkable topology and rendered as recessed hazards.
var pit_cells: Dictionary = {}
## Procedural interior obstacles are explicit pillar footprints.  The room
## membership maps intentionally retain these cells; only walkable topology
## removes them.  Wall edges are derived from these footprints below.
var pillar_footprints: Array = []
var pillar_cells: Dictionary = {}
## Defensive/rendering cache derived from pillar_footprints.  No random wall
## edge is accepted as a procedural obstacle source of truth.
var internal_wall_edges: Dictionary = {}
var pit_root: Node3D
var last_safe_floor_position := Vector2.ZERO
var _pit_player_handled := false
var _pit_enemy_handled: Dictionary = {}
var wall_edges: Dictionary = {}
var window_wall_edges: Dictionary = {}
var glass_wall_edges: Dictionary = {}
var door_edges: Dictionary = {}
var door_opening_edges: Dictionary = {}
var edge_states: Dictionary = {}
var spawn_room_id: int = -1
var boss_room_id: int = -1
var key_room_id: int = -1
var boss_distances: Dictionary = {}
var key_distances: Dictionary = {}
var spawn_cell: Vector2i = Vector2i.ZERO
var main_entrance: Dictionary = {}
var key_pickup: Node2D
var has_boss_key := false
var boss_door_id := -1
var boss_door_edge_key := ""
var boss_door_node: PhysicalDoor3D
var boss_enemy: EmployeeEnemy
var boss_defeated := false
var wake_exit_trigger: Area2D
var wake_exit_visual: Node3D
## TASK-014 floor progression. `floor_index` is run-local and intentionally
## separate from `dream_layer_id`, which retains campaign/save semantics.
var floor_index: int = 0
var base_floor_seed: int = 1337
var has_floor_badge := false
var badge_carrier_room_id: int = -1
var badge_carrier_spawn_index: int = -1
var badge_drop_committed := false
var badge_drop_pending := false
var floor_badge_pickup: Node2D
var badge_marker: Node2D
const ElevatorFloorDoor3D = preload("res://scripts/dream/elevator_floor_door_3d.gd")
const IndependentElevatorCab3D = preload("res://scripts/dream/independent_elevator_cab_3d.gd")

var elevator_floor_door: ElevatorFloorDoor3D
var active_transition_cab: IndependentElevatorCab3D
var transition_generation_token: int = 0
var transition_phase: StringName = &"IDLE"
const ELEVATOR_VISIBLE_RIDE_SECONDS := 3.0
var _cab_suspended_floor_state: Array[Dictionary] = []
var _next_floor_render_ready := false

var _floor_rollback_stash: Node = null
var _stashed_rooms: Array = []
var _stashed_floor_cells: Dictionary = {}
var _stashed_room_cells: Dictionary = {}
var _stashed_corridor_cells: Dictionary = {}
var _stashed_door_edges: Dictionary = {}
var _stashed_macro_graph: Dictionary = {}
var _stashed_floor_index: int = 0
var _stashed_runtime_state: Dictionary = {}
var _stashed_physics_state: Array[Dictionary] = []

func get_current_floor_token() -> int:
	return _layout_generation

# One ownership contract for immediate regeneration and staged transitions.
func _floor_owned_roots() -> Array:
	return [floor_root, wall_root, door_root, debug_root, wake_exit_root,
		ceiling_light_root, collision_root, furniture_root, enemy_root, key_root,
		world_weapon_root, pickup_root, ground_debris_root, world_effects_root,
		actor_depth_bridges_root, actor_physics_proxies_root, native_damage_numbers_root, office_art_root]


func _is_persistent_floor_child(node: Node) -> bool:
	if node.has_meta(&"source_actor") and node.get_meta(&"source_actor") == player:
		return true
	if node.has_meta(&"persistent_player_display"):
		return true
	return false


func _freeze_stashed_physics(node: Node) -> void:
	_stashed_physics_state.append({"reference": weakref(node), "process_mode": node.process_mode})
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionObject2D or node is CollisionObject3D:
		var record := {"reference": weakref(node), "layer": node.collision_layer, "mask": node.collision_mask}
		if node is RigidBody2D or node is RigidBody3D:
			record["freeze"] = node.freeze
			node.freeze = true
		_stashed_physics_state.append(record)
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_freeze_stashed_physics(child)

var elevator_anchor_cell := Vector2i.ZERO
var elevator_room_id := -1
var floor_shape: StringName = &"rectangle"
var elevator_edge_key := ""
var elevator_trigger: Area2D
var elevator_visual: Node3D
var elevator_sliding_door_root: Node3D
var elevator_left_door: MeshInstance3D
var elevator_right_door: MeshInstance3D
var elevator_door_collider: StaticBody2D
var elevator_door_shape: CollisionShape2D
var elevator_approach_trigger: Area2D
var elevator_indicator_label: Label3D
var elevator_doors_open := true
var elevator_sliding_tween: Tween
var elevator_state: StringName = &"LOCKED"
var player_has_left_elevator_cab := false
@export var enable_game_start_cab_exit := true
var floor_transition_in_progress := false
var elevator_door_pos_2d := Vector2.ZERO
var elevator_cab_inward_2d := Vector2.UP
var elevator_transition_animated := true
var elevator_rumble_active := false
var elevator_rumble_time := 0.0
var elevator_rumble_intensity := 0.0
## Room transitions keep the logical graph and runtime nodes alive, while the
## presentation/physics gate exposes only the current room and its exit stubs.
var current_room_id := -1
var transition_in_progress := false
## A transition trigger is an Area2D signal.  The actual room swap must wait
## until that physics query flush has completed; otherwise freeing/adding walls,
## doors or debris can mutate the physics space from inside `body_entered`.
var transition_commit_pending := false
var transition_guard_until_msec := 0
var transition_guard_connection_id := -1
var transition_root: Node3D
var transition_trigger_root: Node2D
var transition_stub_floor_cells: Dictionary = {}
var transition_stubs: Array[Dictionary] = []
var transition_stub_wall_keys: Dictionary = {}
const TRANSITION_STUB_LENGTH_CELLS := 3
const TRANSITION_TRIGGER_DEPTH_CELLS := 0.55
const TRANSITION_GRADIENT_SHADER: Shader = preload("res://shaders/dream3d/transition_corridor_gradient.gdshader")
var run_finished := false
var start_to_boss_blocked_before_key := false
var furniture_count := 0
var enemy_count := 0
var _content_rng := RandomNumberGenerator.new()
var _corpse_blood_emitter_serial: int = 0
## Owned emitters for this world; avoids get_nodes_in_group on each spawn.
var _owned_corpse_blood_emitters: Array = []
## All black blood stains (floor/wall/door) for budget without group alloc.
var _owned_black_blood_stains: Array = []
const BLOOD_MERGE_BUCKET_PIXELS := 128.0
const BLOOD_MERGE_CAPTURE_EXTENT := 112.0
var _settled_blood_buckets: Dictionary = {}
## Monotonic token used by deferred room-drop timers.  Regenerating the same
## world node must invalidate callbacks from the previous layout before they
## can instantiate stale content into a new room graph.
var _layout_generation := 0
var _next_door_id: int = 0
var active_seed: int = 0
var last_validation_report: Dictionary = {}
var camera_impulse_offset := Vector3.ZERO
var camera_shake_amplitude := 0.0
var camera_shake_elapsed := 0.0
var camera_shake_duration := 0.0
var camera_aim_offset := Vector3.ZERO
var dialogue_camera: Node
var authoritative_camera_size := 0.0
var authoritative_camera_fov := GAMEPLAY_CAMERA_FOV
var phone_camera_weight := 0.0
var _phone_camera_refresh_only := false
var dialogue_speaker_registry: Dictionary = {}
var _unknown_dialogue_speakers: Dictionary = {}
## Cached actor visual bounds used by the wall cutout.  Values are computed only
## when an actor is spawned or its CharacterVisual baseline changes; the per
## frame cutout update reads the cached local center/radius only.
var _occlusion_bounds_cache: Dictionary = {}
var _cutout_query_snapshot_active := false
var _cutout_query_walls: Array = []
var _cutout_wall_centres: Dictionary = {}
var _cutout_wall_positions := PackedVector3Array()
var _cutout_wall_bins: Dictionary = {}
var _cutout_wall_edges: Array[Dictionary] = []
var _cutout_wall_heights := PackedFloat32Array()
var _cutout_wall_meshes: Array = []
var _static_cutout_walls: Array = []
var _static_cutout_wall_positions := PackedVector3Array()
var _static_cutout_wall_bins: Dictionary = {}
var _static_cutout_wall_edges: Array[Dictionary] = []
var _static_cutout_wall_heights := PackedFloat32Array()
var _static_cutout_wall_meshes: Array = []
var _static_cutout_door_candidates: Array[VisualInstance3D] = []
var _last_door_root_child_count: int = -1
var _cached_furniture_bridges: Array = []
var _last_bridges_child_count: int = -1
var _last_furniture_art_child_count: int = -1
var _last_furniture_2d_child_count: int = -1
var _last_cutout_viewport_size: Vector2 = Vector2.ZERO
var _last_cutout_slots: Array[Vector4] = []
var _cached_enemy_cutout_slots := PackedVector4Array()
var _cached_enemy_cutout_dists := PackedFloat32Array()
var _cutout_work_slots := PackedVector4Array()
var _cutout_work_dists := PackedFloat32Array()
var _cutout_sort_indices: Array[int] = []
var _furniture_near_indices: Array = []
var _furniture_near_seen: Dictionary = {}
var _cutout_slots_scratch: Array[Vector4] = []
var _furniture_scan_roots: Array[Node] = []
var _furniture_rebuild_seen: Dictionary = {}
var _cutout_slot_result: Dictionary = {}
var _cached_projectile_cutout_nodes: Array = []
var _cached_projectile_cutout_frame: int = -1

## World position of whatever broke the sightline during the last query, plus
## whether it is valid. Cutout slots project THIS point instead of the actor:
## under a top-down camera a tall piece of furniture projects well above the
## actor, so a hole centred on the actor would land on the floor beside it.
var _occluder_hit_position: Vector3 = Vector3.ZERO
var _has_occluder_hit: bool = false

## Cached furniture meshes for the screen-space occlusion test. Rebuilding this
## every query frame walked all ~1200 meshes three times per frame and made the
## game stutter badly, so the list is refreshed only when floor content changes
## (plus a slow safety refresh). Per-actor queries use XZ corridor bins so they
## never scan the full mesh list.
var _cutout_furniture_meshes: Array = []
var _cutout_furniture_meshes_frame: int = -1
var _cutout_furniture_meshes_dirty := true
var _active_firearm_impact_count := 0
var _cutout_furniture_query_frame: int = -1
var _cached_damageable_props: Array = []
var _cached_damageable_props_frame: int = -1
var _cached_dream_enemies: Array = []
var _cached_dream_enemies_frame: int = -1
var _debris_point_query: PhysicsPointQueryParameters2D
var _blood_batch_point_query: PhysicsPointQueryParameters2D
var _player_exclude_rids: Array[RID] = []
var _employee_exclude_rids: Array[RID] = []
var _throw_aim_cleared := true
var _dash_aim_cleared := true
var _cutout_furniture_mesh_centers := PackedVector3Array()
var _cutout_furniture_mesh_bins: Dictionary = {}
## Per-frame screen-rect cache keyed by MeshInstance3D instance_id.
var _cutout_furniture_screen_rect_frame: int = -1
var _cutout_furniture_screen_rects: Dictionary = {}

const FURNITURE_MESH_REFRESH_FRAMES := 120
const FURNITURE_MESH_CENTER_REFRESH_FRAMES := 6
const FURNITURE_MESH_BIN_SIZE := 4.0
## World-XZ radius around the actor used to gather candidate furniture meshes.
## Covering pieces sit near the actor under the gameplay camera; a tight
## camera->actor corridor alone missed side-adjacent cabinets.
const FURNITURE_MESH_NEAR_RADIUS := 5.0
var _cutout_query_furniture: Array = []
var _cutout_furniture_visuals: Array[VisualInstance3D] = []
var _cutout_furniture_positions := PackedVector3Array()
var _cutout_query_doors: Array[VisualInstance3D] = []
var _cutout_query_aabbs: Dictionary = {}
var weapon_interaction_consumed_until_release := false
var current_world_weapon_target: Node2D
var throw_trajectory_visual: Node3D
var dash_aim_presentation: Node2D
var _throw_prediction_cache: Dictionary = {}
var _throw_prediction_cache_frame := -1
## Enemy pickup requests are collected as soft reservations and committed only
## after the Player interaction pass for the same gameplay tick.  This removes
## SceneTree callback ordering from the Player-vs-Enemy ownership race.
var pending_enemy_pickup_requests: Dictionary = {}
var _pickup_request_serial := 0

## One logical transit holder per physical doorway.  An Enemy must own this
## short-lived grant before ROOM_TRANSIT; waiting agents remain at the authored
## approach point and never open/push a door by ordinary body contact.
var door_transit_registry: Dictionary = {}
var _door_transit_serial := 0
var _open_connected_rooms_cache: Dictionary = {}
var _open_boundary_edges_cache: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var damage_totals: Dictionary = {}
## Damage feedback is UI information, not 3D geometry.  Each entry stores the
## world-space hit anchor independently from the Enemy so the number remains at
## the impact location while the target keeps moving.
var native_damage_number_anchors: Array[Dictionary] = []
var native_damage_numbers_root: Node2D
var enemy_population_refill_left := 0.0
var enemy_population_breathing_left: Dictionary = {}
var reserved_content_cells: Dictionary = {}
var _employee_clear_shape: CircleShape2D
var _employee_clear_query: PhysicsShapeQueryParameters2D
var _placement_clear_shape: CircleShape2D
var _placement_clear_query: PhysicsShapeQueryParameters2D
var _room_path_clear_query: PhysicsRayQueryParameters2D
var _furniture_shot_path_query: PhysicsRayQueryParameters2D
var _employee_nav_ray: PhysicsRayQueryParameters2D
var _debris_spray_ray: PhysicsRayQueryParameters2D
var _door_proximity_ray: PhysicsRayQueryParameters2D
var _throw_prediction_shape: RectangleShape2D
var _throw_prediction_query: PhysicsShapeQueryParameters2D
var _furniture_footprint_shape: RectangleShape2D
var _furniture_footprint_query: PhysicsShapeQueryParameters2D
var employee_path_cache: Dictionary = {}
var _floor_path_cache_enabled := false
var _floor_path_adjacency: Dictionary = {}
var _floor_path_floor_keys: Array = []
var _floor_path_wall_keys: Array = []
var _floor_path_wall_membership: Dictionary = {}
var _floor_path_goal_searches: Dictionary = {}
var _floor_path_goal_order: Array[Vector2i] = []
## Bounded presentation-only pool for tiny projectile illumination. Gameplay
## projectiles never depend on a free light slot; overflow remains unshaded.
var projectile_local_light_pool: Array[OmniLight3D] = []
var projectile_light_slot_owner_ids: Array[int] = []
var projectile_light_assignments: Dictionary = {}

## Temporary startup profiling (Stage 2A/2D).  It is opt-in through the
## DREAM_STARTUP_PROFILE environment variable so normal runs keep the exact
## pre-profiling behavior and log volume.  This block is intentionally scoped
## to measurement; it must not become a permanent gameplay dependency.
var _startup_profile_enabled := false
var _startup_profile_ready_started_usec: int = 0
var _startup_profile_ready_total_ms := 0.0
var _startup_profile_generation_started_usec: int = 0
var _startup_profile_totals: Dictionary = {}
var _startup_profile_counts: Dictionary = {}
var _startup_profile_run_index := 0


func _startup_profile_clock_usec() -> int:
	return Time.get_ticks_usec()


func _startup_profile_begin_generation() -> void:
	if not _startup_profile_enabled:
		return
	_startup_profile_run_index += 1
	_startup_profile_generation_started_usec = _startup_profile_clock_usec()
	_startup_profile_totals.clear()
	_startup_profile_counts.clear()


func _startup_profile_record_time(key: String, started_usec: int) -> void:
	if not _startup_profile_enabled or started_usec <= 0:
		return
	var elapsed_ms := float(_startup_profile_clock_usec() - started_usec) / 1000.0
	_startup_profile_totals[key] = float(_startup_profile_totals.get(key, 0.0)) + elapsed_ms


func _startup_profile_increment(key: String, amount: int = 1) -> void:
	if not _startup_profile_enabled:
		return
	_startup_profile_counts[key] = int(_startup_profile_counts.get(key, 0)) + amount


func _startup_profile_count_nodes(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var total := 1
	for child in root.get_children():
		if child is Node:
			total += _startup_profile_count_nodes(child)
	return total


func _startup_profile_count_class(root: Node, target_class_name: String) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var total := 1 if root.is_class(target_class_name) else 0
	for child in root.get_children():
		if child is Node:
			total += _startup_profile_count_class(child, target_class_name)
	return total


func _startup_profile_emit(label: String) -> void:
	if not _startup_profile_enabled:
		return
	var node_counts := {
		"scene_tree_nodes": _startup_profile_count_nodes(self),
		"generated_nodes": _startup_profile_count_nodes(generated_root),
		"floor_nodes": floor_root.get_child_count() if floor_root != null else 0,
		"wall_nodes": wall_root.get_child_count() if wall_root != null else 0,
		"door_nodes": door_root.get_child_count() if door_root != null else 0,
		"ceiling_light_holders": ceiling_light_root.get_child_count() if ceiling_light_root != null else 0,
		"actor_bridges": actor_depth_bridges_root.get_child_count() if actor_depth_bridges_root != null else 0,
		"actor_physics_proxies": actor_physics_proxies_root.get_child_count() if actor_physics_proxies_root != null else 0,
		"lights": _startup_profile_count_class(self, "Light3D"),
		"sub_viewports": _startup_profile_count_class(self, "SubViewport"),
		"mesh_instances": _startup_profile_count_class(self, "MeshInstance3D"),
	}
	var report := {
		"label": label,
		"run": _startup_profile_run_index,
		"seed": active_seed,
		"ready_ms": _startup_profile_ready_total_ms,
		"phases_ms": _startup_profile_totals.duplicate(true),
		"counters": _startup_profile_counts.duplicate(true),
		"nodes": node_counts,
		"rooms": rooms.size(),
		"connections": connections.size(),
		"corridors": corridors.size(),
		"logical_floor": floor_cells.size(),
		"presentation_floor": presentation_floor_cells.size(),
		"walls": wall_edges.size(),
		"internal_walls": internal_wall_edges.size(),
		"pit_cells": pit_cells.size(),
		"current_room": current_room_id,
	}
	print("[StartupPerf] %s" % JSON.stringify(report))


func _startup_profile_record_macro_generation(profile: Dictionary) -> void:
	if not _startup_profile_enabled:
		return
	_startup_profile_increment("macro_generate_calls")
	_startup_profile_increment("macro_attempts_total", int(profile.get("attempts", 0)))
	_startup_profile_increment("macro_graph_empty", int(profile.get("macro_graph_empty", 0)))
	_startup_profile_increment("macro_layout_empty", int(profile.get("cell_layout_empty", 0)))
	_startup_profile_increment("macro_validation_rejects", int(profile.get("validation_rejects", 0)))
	if bool(profile.get("success", false)):
		_startup_profile_increment("macro_successes")
	else:
		_startup_profile_increment("macro_failures")


func configure_run_weapon_state(weapon_id: String, available_weapon_ids: Array[String]) -> void:
	configured_weapon_id = WEAPON_VISUALS.sanitize_weapon_id(weapon_id)
	configured_weapon_ids.clear()
	for candidate in available_weapon_ids:
		var sanitized_candidate := WEAPON_VISUALS.sanitize_weapon_id(candidate)
		if not sanitized_candidate.is_empty() and not sanitized_candidate in configured_weapon_ids:
			configured_weapon_ids.append(sanitized_candidate)


func _apply_3d_firearm_profile(source: DemoConfig) -> void:
	# Campaign/shared resources retain their source values; retired 2D is not restored.
	# A 3D world owns one deep copy for its whole run, including later floors.
	if _3d_firearm_profile_applied and source == config:
		return
	var baseline: DemoConfig = source if source != null else EMPLOYEE_CONFIG
	config = baseline.duplicate(true) as DemoConfig
	config.basic_weapon_attack_interval = 1.0 / PISTOL_FIRE_RATE_3D
	config.assault_rifle_attack_interval = 1.0 / RIFLE_FIRE_RATE_3D
	config.shotgun_attack_interval = 1.0 / SHOTGUN_FIRE_RATE_3D
	config.basic_projectile_speed = FIREARM_PROJECTILE_SPEED_3D
	config.assault_rifle_projectile_speed = FIREARM_PROJECTILE_SPEED_3D
	config.shotgun_projectile_speed = FIREARM_PROJECTILE_SPEED_3D
	config.player_movement_speed = 290.0
	config.set_meta("office_player_move_speed", 290.0)
	config.employee_movement_speed = 150.0
	config.basic_weapon_range *= PISTOL_RANGE_SCALE_3D
	config.assault_rifle_range *= RIFLE_RANGE_SCALE_3D
	config.shotgun_max_distance *= SHOTGUN_RANGE_SCALE_3D
	_3d_firearm_profile_applied = true


func configure_campaign_run(
	weapon_id: String,
	available_weapon_ids: Array[String],
	run_config: DemoConfig,
	profile: Dictionary,
	day: int,
	sunday: bool,
	hungry: bool,
	stress: int
) -> void:
	campaign_run = true
	floor_index = 0
	base_floor_seed = seed
	has_floor_badge = false
	configure_run_weapon_state(weapon_id, available_weapon_ids)
	_apply_3d_firearm_profile(run_config)
	profile_state = profile
	permanent_upgrades = profile.get("permanent_upgrades", {}).duplicate(true)
	difficulty_day = maxi(1, day)
	is_sunday = sunday
	is_hungry_run = hungry
	run_stress_value = stress
	dream_layer_id = maxi(1, int(profile.get("current_dream_layer", profile.get("dream_layer_reached", 1))))


func _ready() -> void:
	base_floor_seed = seed
	_apply_3d_firearm_profile(config)
	_startup_profile_enabled = OS.get_environment("DREAM_STARTUP_PROFILE") == "1"
	if _startup_profile_enabled:
		_startup_profile_ready_started_usec = _startup_profile_clock_usec()
	# Directly launched Dream scenes must receive the same canonical bindings as
	# the Main scene.  The helper is idempotent, so this does not duplicate events
	# when Main already configured the InputMap.
	preload("res://scripts/app/game_input_actions.gd").configure()
	add_to_group(&"dream_world")
	if camera_3d != null:
		# Capture the scene-authored size before any dialogue modifier is applied;
		# never use an already modified value as the next base size.
		authoritative_camera_size = camera_3d.size
		# The 3D gameplay scene is perspective.  Keep projection/angle as the
		# scene authority and only establish a low-FOV framing baseline here.
		camera_3d.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_3d.fov = GAMEPLAY_CAMERA_FOV
		authoritative_camera_fov = camera_3d.fov
	dialogue_camera = DIALOGUE_CAMERA_SCRIPT.new()
	dialogue_camera.name = "DialogueCameraModifier"
	camera_rig.add_child(dialogue_camera)
	dialogue_camera.call("configure", player, Callable(self, "_map_gameplay_to_world"))
	_setup_3d_audio_listener()
	if player != null and is_instance_valid(player):
		dialogue_speaker_registry[&"player"] = weakref(player)
		_cache_actor_occlusion_bounds(player)
	ground_debris_root.add_to_group(&"ground_debris_root")
	furniture_root.add_to_group(&"furniture_root")
	_content_rng.seed = int(seed) ^ 0x5EED5EED
	if disable_player_combat and player.has_method("set_attacking_enabled"):
		player.call("set_attacking_enabled", false)
	if player_depth_bridge != null and player_depth_bridge.has_method("configure"):
		player_depth_bridge.set("volume_shadow_enabled", dynamic_shadows_enabled)
		# Gameplay remains a real CharacterBody2D.  Only its presentation is
		# routed through the depth-capable 3D bridge in this prototype.
		player_depth_bridge.call("configure", player, actor_depth_viewport, actor_depth_render_root, gameplay_canvas)
		player_depth_bridge.call("set_world_camera", camera_3d)
		# The Player bridge is an authored scene node rather than one created by
		# _spawn_depth_bridge(), so register the same weak lookup metadata used by
		# dynamically spawned actors.  Projectile presentation can then derive its
		# plane from the real held-weapon capture instead of falling back to a flat
		# height that is visibly below the gun in the perspective camera.
		player.set_meta(&"depth_visual_bridge", weakref(player_depth_bridge))
	if player != null and player.has_signal("weapon_fired") and not player.weapon_fired.is_connected(_on_player_weapon_fired):
		player.weapon_fired.connect(_on_player_weapon_fired)
	if player != null and player.has_signal("weapon_drop_requested"):
		var player_drop_handler := Callable(self, "_on_player_weapon_drop_requested")
		if not player.weapon_drop_requested.is_connected(player_drop_handler):
			player.weapon_drop_requested.connect(player_drop_handler)
	if player != null:
		player.set("selected_weapon_id", configured_weapon_id)
		player.configure_weapon(configured_weapon_id, config, permanent_upgrades)
		# configure_weapon applies the authoritative visual scale after the world
		# node's _ready ran. Refresh the cached cutout bounds once at that
		# lifecycle boundary instead of recursively scanning every frame.
		_cache_actor_occlusion_bounds(player)
	_enter_dream_time_mode()
	night_lighting = preload("res://scripts/dream/dream_night_lighting.gd").new()
	night_lighting.name = "NightLighting"
	add_child(night_lighting)
	night_lighting.configure(self)
	night_lighting.set_managed_shadows(dynamic_shadows_enabled)
	if dynamic_shadows_enabled:
		shadow_manager = preload("res://scripts/dream/office_shadow_manager.gd").new()
		shadow_manager.name = "OfficeShadowManager"
		add_child(shadow_manager)
		shadow_manager.configure(self)
	_configure_projectile_local_light_pool()
	# Keep the static KeyLight on the same explicit cull mask as the dynamic
	# ceiling/muzzle lights: world visuals, Player receiver and Player shadow
	# proxy.  The flashlight uses its narrower mask in dream_night_lighting.gd.
	var key_light := get_node_or_null("Lighting/KeyLight") as DirectionalLight3D
	if key_light != null:
		key_light.light_cull_mask = night_lighting.WORLD_LIGHT_CULL_MASK
		# The generated room/corridor lights own the presentation shadows.  A
		# second map-wide directional shadow projects the wall silhouette across
		# the floor as hard cross-shaped bands in Compatibility, even at the
		# small baseline energy used by this scene.  Keep the gentle key fill but
		# remove only its shadow presentation; gameplay collision/LOS is 2D.
		key_light.shadow_enabled = false
	if player_depth_bridge != null:
		# The visible player carrier receives scene lighting on its own layer;
		# its separate SHADOWS_ONLY proxy is placed on PLAYER_SHADOW_LAYER so the
		# flashlight can exclude only that proxy and avoid self-shadow.
		var player_sprite := player_depth_bridge.get("actor_sprite") as Sprite3D
		if player_sprite != null:
			player_sprite.layers = night_lighting.PLAYER_VISUAL_LAYER
			player_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var player_shadow_proxy := player_depth_bridge.get("shadow_proxy") as Sprite3D
		if player_shadow_proxy != null:
			player_shadow_proxy.layers = night_lighting.PLAYER_SHADOW_LAYER
			player_shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The standalone random building is still a real combat scene.  Reuse the
	# existing global music manager so this scene never creates a second player.
	SFX.play_battle_music(false, get_instance_id())
	if player_physics_proxy != null:
		player_physics_proxy.set_meta(&"prototype_only", true)
	if generate_on_ready:
		regenerate(seed)
	_setup_dash_aim_presentation()
	var ui := CanvasLayer.new()
	ui.name = "GameplayUI"
	ui.layer = 20
	add_child(ui)
	var damage_numbers_root := Node2D.new()
	damage_numbers_root.name = "DamageNumbers"
	damage_numbers_root.z_index = 10
	ui.add_child(damage_numbers_root)
	native_damage_numbers_root = damage_numbers_root
	ui_layer = ui
	var crosshair := preload("res://scenes/ui/crosshair.tscn").instantiate()
	ui.add_child(crosshair)
	crosshair.configure(player)
	# Interaction prompt lives in the topmost CanvasLayer, so it never becomes a
	# 3D carrier: no night lighting, no flashlight, no muzzle flash, no depth
	# occlusion. The world only supplies the anchor; HUD draws the text.
	interaction_prompt = COMPACT_PROMPT.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.visible = false
	interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_prompt.theme = load("res://assets/fonts/pixel_theme.tres")
	interaction_prompt.add_theme_color_override("font_color", Color(0.83, 0.93, 0.96, 1))
	interaction_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 1))
	interaction_prompt.add_theme_constant_override("outline_size", 2)
	interaction_prompt.add_theme_font_override(&"font", CRISP_INTERACTION_FONT.get_font())
	interaction_prompt.add_theme_font_size_override("font_size", 12)
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.size = INTERACTION_PROMPT_SIZE
	ui.add_child(interaction_prompt)
	weapon_name_popup = Label.new()
	weapon_name_popup.name = "WeaponNamePopup"
	weapon_name_popup.visible = false
	weapon_name_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_name_popup.theme = load("res://assets/fonts/pixel_theme.tres")
	weapon_name_popup.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	weapon_name_popup.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
	weapon_name_popup.add_theme_constant_override("outline_size", 2)
	weapon_name_popup.add_theme_font_override(&"font", CRISP_INTERACTION_FONT.get_font())
	weapon_name_popup.add_theme_font_size_override("font_size", 12)
	weapon_name_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_name_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_name_popup.size = WEAPON_NAME_POPUP_SIZE
	weapon_name_popup.z_index = 20
	ui.add_child(weapon_name_popup)
	if player != null and is_instance_valid(player):
		player.suppress_local_weapon_name_label = true
		player.weapon_name_label.hide()
		var active_weapon_callback := Callable(self, "_on_player_active_weapon_changed_for_popup")
		if player.has_signal(&"active_weapon_changed") and not player.is_connected(&"active_weapon_changed", active_weapon_callback):
			player.connect(&"active_weapon_changed", active_weapon_callback)
		var ammo_callback := Callable(self, "_on_player_ammo_changed_for_popup")
		if player.has_signal(&"ammo_changed") and not player.is_connected(&"ammo_changed", ammo_callback):
			player.connect(&"ammo_changed", ammo_callback)
	interaction_resolver = preload("res://scripts/dream/dream_interaction_resolver.gd").new()
	interaction_resolver.name = "DreamInteractionResolver"
	add_child(interaction_resolver)
	interaction_resolver.configure(player, [&"world_weapon_pickups", &"employee_badge_pickup"])
	run_interface = preload("res://scripts/dream/dream_3d_run_interface.gd").new()
	add_child(run_interface)
	run_interface.configure(self, ui, crosshair)
	_configure_dungeon_minimap()
	if disable_player_combat:
		player.set_attacking_enabled(false)
	target_highlight = preload("res://scripts/dream/dream_3d_target_highlight.gd").new()
	add_child(target_highlight)
	target_highlight.configure(self)
	throw_trajectory_visual = THROW_TRAJECTORY_SCRIPT.new()
	throw_trajectory_visual.name = "ThrowTrajectoryVisual"
	add_child(throw_trajectory_visual)

	# Runtime settings can also be changed from the pause menu.
	objective_guidance = preload("res://scripts/dream/office_objective_guidance.gd").new()
	add_child(objective_guidance)
	objective_guidance.configure(self)
	var settings_node := get_tree().root.get_node_or_null("SettingsManager")
	if settings_node != null:
		if not settings_node.setting_changed.is_connected(_on_settings_changed):
			settings_node.setting_changed.connect(_on_settings_changed)
		if shadow_manager != null:
			shadow_manager.set_quality(String(settings_node.get_setting(&"shadow_quality", "standard")))
	if _startup_profile_enabled:
		_startup_profile_ready_total_ms = float(_startup_profile_clock_usec() - _startup_profile_ready_started_usec) / 1000.0
		_startup_profile_emit("ready")


func _exit_tree() -> void:
	if has_meta(&"display_reparenting"):
		return
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("clear_dialogue_focus")
	for index in range(OCCLUSION_CUTOUT_SLOT_COUNT):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % index, Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", Vector2.ONE)
	_occlusion_bounds_cache.clear()
	_clear_projectile_local_light_pool()
	_exit_dream_time_mode()
	# This scene owns only the battle request it made in _ready.  Release that
	# ownership when a standalone prototype run ends; the global manager remains
	# responsible for the actual AudioStreamPlayer and any other scene's music.
	SFX.stop_music(0.12, get_instance_id())
	# The ride bed lives on the SFXManager autoload, which outlives this scene.
	# If the dungeon is torn down mid-ride (back to a menu, restart), the loop
	# would otherwise keep playing forever with no owner left to stop it.
	# Clearing the shake flag here also stops it leaking into the next instance.
	# The 0.15s release roughly matches the music fade above.
	_set_elevator_ride_rumbling(false, 0.15)


func get_vision_occluder_collision_mask() -> int:
	# Generated walls and PhysicalDoor3D's synchronized 2D leaf blocker both
	# use this authoritative world-wall layer. Furniture and actors are not LOS
	# occluders in the formal Dream rules.
	return WORLD_WALL_LAYER


func _process(delta: float) -> void:
	_cleanup_door_transit_registry()
	_update_camera_and_actor_projection(_get_presentation_delta(delta))
	# During the independent ride only the player/cab are live. The ready
	# floor must not run AI, floor interaction or full-floor occlusion scans.
	if transition_phase == &"CAB_RIDE":
		_update_weapon_name_popup(_get_presentation_delta(delta))
		return
	if is_instance_valid(objective_guidance):
		objective_guidance.update(_get_presentation_delta(delta))
	_update_projectile_local_lights()
	_update_occlusion_cutouts()
	_update_throw_aim_presentation()
	_update_dash_aim_presentation()
	_update_native_damage_number_projections()
	_update_weapon_name_popup(_get_presentation_delta(delta))
	_update_player_weapon_throw()
	_update_world_weapon_interaction()
	_resolve_pending_enemy_pickup_requests()
	_update_interaction_prompt()
	_update_player_door_interaction()
	_process_pit_contacts()
	_update_otxo_room_tracking()


func _update_otxo_room_tracking() -> void:
	if not _is_otxo_mansion() or player == null or not is_instance_valid(player):
		return
	var player_cell := _cell_for_gameplay_position(player.global_position)
	var p_room := int(room_cells.get(player_cell, -1))
	if p_room >= 0 and p_room != current_room_id:
		set_current_room_id(p_room)
		activate_room(p_room)


func _setup_3d_audio_listener() -> void:
	if camera_rig != null and is_instance_valid(camera_rig):
		var existing := camera_rig.get_node_or_null("AudioListener3D") as AudioListener3D
		if existing == null:
			audio_listener_3d = AudioListener3D.new()
			audio_listener_3d.name = "AudioListener3D"
			camera_rig.add_child(audio_listener_3d)
			audio_listener_3d.make_current()
		else:
			audio_listener_3d = existing
			audio_listener_3d.make_current()
	var vp := get_viewport()
	if vp != null:
		vp.audio_listener_enable_3d = true


func _setup_dash_aim_presentation() -> void:
	if dash_aim_presentation != null and is_instance_valid(dash_aim_presentation):
		return
	if DASH_AIM_PRESENTATION_SCRIPT == null or world_effects_root == null:
		return
	dash_aim_presentation = DASH_AIM_PRESENTATION_SCRIPT.new() as Node2D
	if dash_aim_presentation == null:
		return
	dash_aim_presentation.name = "DashAimPresentation"
	dash_aim_presentation.z_index = 40
	dash_aim_presentation.set_meta(&"depth_visual_unshaded", true)
	world_effects_root.add_child(dash_aim_presentation)
	# Dash markers are floor graphics, not upright actor sprites.  Give this
	# presentation its own ground-plane bridge so the path is drawn on the map
	# surface at the resolved gameplay coordinates rather than on the Player's
	# vertical visual plane.
	_spawn_depth_bridge(
		dash_aim_presentation,
		[NodePath(".")],
		Vector2(128.0, 128.0),
		BaseMaterial3D.BILLBOARD_DISABLED,
		0.025,
		0.0,
		Vector3(-PI * 0.5, 0.0, 0.0),
		true,
		false
	)
	dash_aim_presentation.call("clear")


func _update_dash_aim_presentation() -> void:
	if dash_aim_presentation == null or not is_instance_valid(dash_aim_presentation):
		_setup_dash_aim_presentation()
	if dash_aim_presentation == null or not is_instance_valid(dash_aim_presentation):
		return
	if (
		player != null
		and is_instance_valid(player)
		and player.has_method("is_dash_aim_active")
		and bool(player.call("is_dash_aim_active"))
		and player.has_method("get_dash_path_result")
	):
		_dash_aim_cleared = false
		dash_aim_presentation.global_position = player.global_position
		dash_aim_presentation.call("set_path", player.call("get_dash_path_result"))
	elif not _dash_aim_cleared:
		dash_aim_presentation.call("clear")
		_dash_aim_cleared = true


func _configure_dungeon_minimap() -> void:
	pass


func _update_dungeon_minimap_room_state(_room_id: int) -> void:
	pass


func _update_dungeon_minimap_corridor_state(_corridor_id: int) -> void:
	pass


func _update_dungeon_minimap_player() -> void:
	pass


## 交互提示：世界只提供"当前可交互对象 + 锚点"，文字画在最顶层 HUD 上。
## 世界跟踪（unproject_position）+ 屏幕渲染，因此不受夜灯、手电、枪口火光
## 影响，也不会被墙、角色、家具、门等 3D 物体遮挡。
func _update_interaction_prompt() -> void:
	if interaction_prompt == null or not is_instance_valid(interaction_prompt):
		return
	if floor_transition_in_progress or transition_phase != &"IDLE" or get_tree().paused or not player.movement_enabled:
		interaction_prompt.dismiss(true)
		return
	var state: Dictionary = {}
	var target := current_world_weapon_target
	if target != null and is_instance_valid(target) and target.has_method("get_interaction_prompt_state"):
		state = target.call("get_interaction_prompt_state")
	if state.is_empty() or camera_3d == null:
		if elevator_prompt_active and camera_3d != null:
			var entry_point := to_global(_map_gameplay_to_world(Vector2(elevator_anchor_cell) * CELL_PIXELS))
			interaction_prompt.present("进入", player.get_presentation_hud_position(camera_3d.unproject_position(entry_point)) + INTERACTION_PROMPT_OFFSET, -1)
		else:
			interaction_prompt.dismiss()
		return
	var anchor: Vector2 = state.get("position", Vector2.ZERO)
	var world_position := to_global(_map_gameplay_to_world(anchor))
	interaction_prompt.present(COMPACT_PROMPT.pickup_verb(target, player), player.get_presentation_hud_position(camera_3d.unproject_position(world_position)) + INTERACTION_PROMPT_OFFSET, target.get_instance_id())


func _on_player_active_weapon_changed_for_popup(weapon_id: String) -> void:
	_player_reloading = is_instance_valid(player) and bool(player.get_ammo_status().get("reloading", false))
	if _player_reloading:
		_show_reload_status_popup()
		return
	if weapon_id.is_empty():
		_hide_weapon_name_popup()
		return
	_show_weapon_name_popup(weapon_id)


func _on_player_ammo_changed_for_popup(_current: int, _capacity: int, reloading: bool) -> void:
	if reloading:
		_show_reload_status_popup()
	elif _player_reloading:
		_hide_weapon_name_popup()
	_player_reloading = reloading


func _show_reload_status_popup() -> void:
	if not is_instance_valid(weapon_name_popup):
		return
	weapon_name_popup.text = "正在换弹"
	weapon_name_popup_time_left = 0.0
	weapon_name_popup_last_id = ""
	weapon_name_popup.modulate = Color.WHITE
	weapon_name_popup.visible = true


func _show_weapon_name_popup(weapon_id: String) -> void:
	if weapon_name_popup == null or not is_instance_valid(weapon_name_popup):
		return
	if _player_reloading:
		_show_reload_status_popup()
		return
	var display_id := DreamGunAtlas.sanitize_weapon_id(weapon_id)
	if display_id.is_empty():
		return
	var now_usec := Time.get_ticks_usec()
	if display_id == weapon_name_popup_last_id and now_usec - weapon_name_popup_last_usec < 80000:
		weapon_name_popup_time_left = maxf(weapon_name_popup_time_left, WEAPON_NAME_POPUP_DURATION)
		return
	weapon_name_popup_last_id = display_id
	weapon_name_popup_last_usec = now_usec
	weapon_name_popup.text = DreamGunAtlas.get_display_name(display_id)
	weapon_name_popup_time_left = WEAPON_NAME_POPUP_DURATION
	weapon_name_popup.modulate = Color.WHITE
	weapon_name_popup.visible = true


func _hide_weapon_name_popup() -> void:
	weapon_name_popup_time_left = 0.0
	if weapon_name_popup != null and is_instance_valid(weapon_name_popup) and weapon_name_popup.visible:
		weapon_name_popup.visible = false


func _update_weapon_name_popup(real_delta: float) -> void:
	if weapon_name_popup == null or not is_instance_valid(weapon_name_popup):
		return
	if _player_reloading:
		if not is_instance_valid(player) or player.dead or camera_3d == null or not bool(player.get_ammo_status().get("reloading", false)):
			_player_reloading = false
			_hide_weapon_name_popup()
			return
		_show_reload_status_popup()
		var reload_anchor := get_gameplay_world_position(_player_ground_anchor_position(), 1.15)
		weapon_name_popup.position = (player.get_presentation_hud_position(camera_3d.unproject_position(reload_anchor)) + WEAPON_NAME_POPUP_OFFSET).round()
		return
	if weapon_name_popup_time_left <= 0.0 or player == null or not is_instance_valid(player) or camera_3d == null:
		_hide_weapon_name_popup()
		return
	weapon_name_popup_time_left = maxf(0.0, weapon_name_popup_time_left - maxf(real_delta, 0.0))
	if weapon_name_popup_time_left <= 0.0:
		_hide_weapon_name_popup()
		return
	var anchor := get_gameplay_world_position(_player_ground_anchor_position(), 1.15)
	weapon_name_popup.position = (player.get_presentation_hud_position(camera_3d.unproject_position(anchor)) + WEAPON_NAME_POPUP_OFFSET).round()
	var fade_start := WEAPON_NAME_POPUP_FADE_DURATION
	var alpha := 1.0 if weapon_name_popup_time_left > fade_start else weapon_name_popup_time_left / fade_start
	weapon_name_popup.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	weapon_name_popup.visible = true


func _update_player_door_interaction() -> void:
	if (
		player == null
		or not is_instance_valid(player)
		or player.get("dead") == true
		or weapon_interaction_consumed_until_release
		or not Input.is_action_just_pressed("pickup_weapon")
	):
		return
	# The preceding pickup resolver already consumed E for its one legal target.
	# A thrown/reserved/unavailable pickup must not independently veto a door.
	weapon_interaction_consumed_until_release = request_player_door_push()


func _update_world_weapon_interaction() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not Input.is_action_pressed("pickup_weapon"):
		weapon_interaction_consumed_until_release = false
	# Highlight can lag one frame when E is not held; keep snappy on press.
	var refresh_target := (
		interaction_resolver == null
		or Input.is_action_pressed("pickup_weapon")
		or Input.is_action_just_pressed("pickup_weapon")
		or (Engine.get_process_frames() & 1) == 0
	)
	var nearest: Node2D = current_world_weapon_target
	if refresh_target and interaction_resolver != null:
		nearest = interaction_resolver.update_target()
	current_world_weapon_target = nearest
	if nearest == null:
		return
	if nearest.is_in_group(&"employee_badge_pickup"):
		# The badge wins only as the nearest candidate; E collects it instead of
		# swapping the held weapon.  Elevator unlock stays inside collect().
		if Input.is_action_just_pressed("pickup_weapon") and not weapon_interaction_consumed_until_release:
			weapon_interaction_consumed_until_release = true
			nearest.call("collect")
		return
	var pickup_category: StringName = &""
	var category_slot_empty := false
	if nearest != null:
		var nearest_weapon_id := String(nearest.get("weapon_id"))
		pickup_category = WEAPON_VISUALS.get_category(nearest_weapon_id)
		if player.has_method("get_weapon_in_category"):
			category_slot_empty = String(player.call("get_weapon_in_category", pickup_category)).is_empty()
		else:
			category_slot_empty = String(player.get("selected_weapon_id")).is_empty()
	if category_slot_empty:
		# Empty-hand is the selected weapon state.  Auto-pickup may equip only in
		# that state; holding any melee/ranged weapon must preserve the current
		# selection and use inventory-only storage.
		var empty_handed := (
			bool(player.call("is_empty_handed"))
			if player.has_method("is_empty_handed")
			else String(player.get("selected_weapon_id")).is_empty()
		)
		if empty_handed:
			_swap_world_weapon(nearest)
			return
		# Automatic pickup fills an empty category without changing the active
		# selection when a weapon is already held.  An explicit E press keeps the
		# established swap/equip path for an occupied-category swap.
		if Input.is_action_just_pressed("pickup_weapon"):
			weapon_interaction_consumed_until_release = true
			_swap_world_weapon(nearest)
		else:
			_store_world_weapon(nearest)
	elif Input.is_action_just_pressed("pickup_weapon") and not weapon_interaction_consumed_until_release:
		weapon_interaction_consumed_until_release = true
		_swap_world_weapon(nearest)


func _update_player_weapon_throw() -> void:
	# DreamPlayer emits weapon_drop_requested for the unified RMB interaction.
	# The old world polling path stays inert to avoid a duplicate throw/block.
	return


func _update_throw_aim_presentation() -> void:
	if throw_trajectory_visual == null or not is_instance_valid(throw_trajectory_visual):
		return
	if (
		player != null
		and is_instance_valid(player)
		and player.has_method("is_throw_aim_active")
		and bool(player.call("is_throw_aim_active"))
	):
		_throw_aim_cleared = false
		var prediction := get_throw_aim_prediction()
		throw_trajectory_visual.call(
			"set_points",
			prediction.get("points", []),
			prediction.get("impact_world", Vector3.ZERO)
		)
	elif not _throw_aim_cleared:
		throw_trajectory_visual.call("clear_points")
		_throw_aim_cleared = true


func get_throw_aim_prediction() -> Dictionary:
	## Predict the real pickup's horizontal body and fake-height arc using the
	## same exported throw profile.  This is read-only and cached once per
	## physics frame so target highlighting and the visual dots share a query.
	var frame := Engine.get_physics_frames()
	if frame == _throw_prediction_cache_frame:
		return _throw_prediction_cache
	_throw_prediction_cache_frame = frame
	var result: Dictionary = {
		"points": [],
		"target": null,
		"enemy_target": null,
		"furniture_target": null,
		"blocker": null,
		"impact_position": Vector2.ZERO,
		"impact_world": Vector3.ZERO,
	}
	if (
		player == null
		or not is_instance_valid(player)
		or not player.has_method("is_throw_aim_active")
		or not bool(player.call("is_throw_aim_active"))
		or not player.has_method("get_active_throw_profile")
		or not player.is_inside_tree()
	):
		_throw_prediction_cache = result
		return result
	var profile: Dictionary = player.call("get_active_throw_profile")
	if profile.is_empty():
		_throw_prediction_cache = result
		return result
	var direction: Vector2 = profile.get("direction", Vector2.RIGHT)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var rotation := direction.angle()
	var spawn_position: Vector2 = profile.get("visual_position", player.global_position)
	# WorldWeaponPickup's authored sprite is offset -7px from its body and its
	# collision shape is offset -4px.  Starting at the same body centre keeps
	# the prediction aligned with the committed pickup without mutating Player.
	spawn_position += Vector2(0.0, 3.0).rotated(rotation)
	var position := spawn_position
	var speed := maxf(float(profile.get("speed", 0.0)), 0.0)
	if speed <= 0.0:
		_throw_prediction_cache = result
		return result
	var velocity := direction * speed
	var fake_height := maxf(float(profile.get("fake_height_peak", 0.0)), 0.0)
	var vertical_velocity := maxf(float(profile.get("fake_height_velocity", 0.0)), 0.0)
	var gravity := maxf(float(profile.get("fake_height_gravity", 0.0)), 0.0)
	var max_duration := maxf(float(profile.get("max_duration", 0.8)), 0.05)
	var linear_damp := maxf(float(profile.get("linear_damp", 0.0)), 0.0)
	if _throw_prediction_query == null:
		_throw_prediction_shape = RectangleShape2D.new()
		_throw_prediction_query = PhysicsShapeQueryParameters2D.new()
		_throw_prediction_query.shape = _throw_prediction_shape
		_throw_prediction_query.collide_with_bodies = true
		_throw_prediction_query.collide_with_areas = true
	var shape_size: Vector2 = profile.get("collision_shape_size", Vector2(26.0, 12.0))
	_throw_prediction_shape.size = shape_size
	_throw_prediction_query.collision_mask = int(profile.get("collision_mask", 15))
	if _player_exclude_rids.is_empty():
		_player_exclude_rids.append(player.get_rid())
	else:
		_player_exclude_rids[0] = player.get_rid()
	_throw_prediction_query.exclude = _player_exclude_rids
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var dt := 1.0 / 60.0
	var steps := maxi(1, ceili(max_duration / dt))
	var points: Array[Vector3] = []
	for step_index in range(steps):
		position += velocity * dt
		# RigidBody2D's linear damping approaches zero exponentially. This
		# reciprocal form matches the engine's stable damping rather than using a
		# second arbitrary speed multiplier.
		velocity /= 1.0 + linear_damp * dt
		fake_height = maxf(0.0, fake_height + vertical_velocity * dt)
		vertical_velocity -= gravity * dt
		if step_index % 2 == 0:
			points.append(_map_throw_prediction_point(position, fake_height))
		_throw_prediction_query.transform = Transform2D(rotation, position)
		var hits: Array[Dictionary] = space.intersect_shape(_throw_prediction_query, 16)
		var hit_result := _resolve_throw_prediction_hits(hits)
		if not hit_result.is_empty():
			result["target"] = hit_result.get("target")
			result["enemy_target"] = hit_result.get("enemy_target")
			result["furniture_target"] = hit_result.get("furniture_target")
			result["blocker"] = hit_result.get("blocker")
			result["impact_position"] = position
			result["impact_world"] = _map_throw_prediction_point(position, fake_height)
			break
	result["points"] = points
	_throw_prediction_cache = result
	return result


func _map_throw_prediction_point(position: Vector2, fake_height: float) -> Vector3:
	return Vector3(
		position.x / CELL_PIXELS,
		0.45 + maxf(fake_height, 0.0) / CELL_PIXELS,
		position.y / CELL_PIXELS
	)


func _resolve_throw_prediction_hits(hits: Array[Dictionary]) -> Dictionary:
	var target: Node
	var enemy_target: Node
	var furniture_target: Node
	var blocker: Node
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider == null or not is_instance_valid(collider):
			continue
		var owner := _resolve_throw_prediction_owner(collider)
		if owner == null or not is_instance_valid(owner):
			continue
		if owner == player or owner.is_in_group(&"world_weapon_pickups") or owner.is_in_group(&"employee_badge_pickup"):
			continue
		if owner.is_in_group(&"dream_enemies"):
			var is_dead: bool = (owner.get("dead") == true)
			if not is_dead and target == null:
				target = owner
				enemy_target = owner
			continue
		if owner.is_in_group(&"damageable_props"):
			var is_destroyed: bool = (owner.get("destroyed") == true or owner.get("is_destroyed") == true)
			if not is_destroyed and target == null:
				target = owner
				furniture_target = owner
			continue
		if _is_throw_prediction_world_blocker(collider):
			blocker = owner
			break
	if blocker != null:
		return {"blocker": blocker}
	if target != null:
		return {
			"target": target,
			"enemy_target": enemy_target,
			"furniture_target": furniture_target,
			"blocker": target,
		}
	return {}


func _resolve_throw_prediction_owner(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_method("get_damage_owner"):
		var damage_owner: Variant = collider.call("get_damage_owner")
		if damage_owner is Node:
			return damage_owner
	var cursor: Node = collider
	for _step in range(8):
		if cursor == null:
			break
		if cursor.has_meta(&"physical_door") or cursor.is_in_group(&"dream_enemies") or cursor.is_in_group(&"damageable_props"):
			return cursor
		cursor = cursor.get_parent()
	return collider


func _is_throw_prediction_world_blocker(collider: Node) -> bool:
	var cursor: Node = collider
	for _step in range(8):
		if cursor == null:
			break
		if cursor.has_meta(&"physical_door") and bool(cursor.get_meta(&"physical_door", false)):
			return true
		if cursor.name in [&"WallLayer", &"DoorBlocker", &"DoorLayer", &"DoorForegroundLayer"]:
			return true
		if cursor is CollisionObject2D:
			var collision_object := cursor as CollisionObject2D
			if collision_object.get_collision_layer_value(1) or collision_object.get_collision_layer_value(3):
				return true
		cursor = cursor.get_parent()
	return false


func _on_player_weapon_drop_requested(drop_data: Dictionary) -> void:
	## Player owns only the inventory extraction.  This world callback reuses the
	## same pickup initializer as an active throw.  Only knockdown/death payloads
	## carry forced_drop; a manual RMB throw must retain the high-speed state and
	## original-thrower pickup lockout.
	_spawn_player_weapon_into_world(
		drop_data,
		bool(drop_data.get("forced_drop", false))
	)


func _spawn_player_weapon_into_world(drop_data: Dictionary, forced_drop: bool) -> void:
	if world_weapon_root == null or drop_data.is_empty():
		return
	var weapon_id := String(drop_data.get("weapon_id", ""))
	if not _is_pickup_weapon_id_allowed(weapon_id):
		return
	var direction: Vector2 = drop_data.get("direction", Vector2.RIGHT)
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var pickup := WORLD_WEAPON_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	pickup.set("weapon_id", weapon_id)
	pickup.set("skin_index", WEAPON_VISUALS.normalize_skin_index(weapon_id, int(drop_data.get("skin_index", 0))))
	pickup.set("visual_scale_override", maxf(float(drop_data.get("visual_scale", -1.0)), -1.0))
	pickup.set("interaction_radius", EMPLOYEE_CONFIG.world_weapon_interaction_radius)
	pickup.set("mass", WEAPON_VISUALS.get_world_mass(weapon_id))
	pickup.rotation = float(drop_data.get("visual_rotation", direction.angle()))
	world_weapon_root.add_child(pickup)
	var visual_position: Vector2 = drop_data.get("visual_position", player.global_position + direction * 12.0)
	var weapon_sprite := pickup.get_node_or_null("WeaponSprite") as Sprite2D
	pickup.global_position = visual_position - weapon_sprite.position.rotated(pickup.global_rotation) if weapon_sprite != null else visual_position
	pickup.set_meta(&"dream_room_id", get_current_room_id())
	if forced_drop:
		var impulse: Vector2 = drop_data.get("drop_impulse", direction * 24.0)
		if pickup.has_method("place_after_swap"):
			pickup.call_deferred("place_after_swap", pickup.global_position, impulse)
	else:
		if pickup.has_method("add_collision_exception_with"):
			pickup.call("add_collision_exception_with", player)
		if pickup.has_method("set_thrown"):
			pickup.call(
				"set_thrown",
				direction * float(drop_data.get("speed", 900.0)),
				float(drop_data.get("damage", 10.0)),
				float(drop_data.get("force", EMPLOYEE_CONFIG.world_weapon_throw_force)),
				player.get_instance_id(),
				EMPLOYEE_CONFIG.world_weapon_throw_pickup_lockout
			)
		# No dedicated throw recording is present in the supplied pack; keep the
		# event at the real Thrown commit so a future matching asset can plug in
		# without moving the gameplay hook.
		SFX.play_weapon_throw()
	_spawn_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])


func _swap_world_weapon(pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup) or not player.has_method("equip_weapon"):
		return
	# Explicit Player E is the authoritative ownership commit.  This atomically
	# overrides an Enemy's soft reservation and makes the result independent of
	# which callback happened to run first this tick.
	if pickup.has_method("request_player_pickup"):
		if not bool(pickup.call("request_player_pickup", player)):
			return
	elif pickup.has_method("is_available_for") and not bool(pickup.call("is_available_for", player)):
		return
	# A Player commit supersedes every queued Enemy soft request for this node.
	# Cancel before recycling the pickup as the old weapon; otherwise an Enemy
	# request from the same tick could consume the recycled item at the Player's
	# old position.
	cancel_enemy_world_weapon_pickup(null, pickup)
	var new_weapon_id := String(pickup.get("weapon_id"))
	if not _is_pickup_weapon_id_allowed(new_weapon_id):
		if pickup.has_method("release_reservation"):
			pickup.call("release_reservation", player)
		return
	var category := WEAPON_VISUALS.get_category(new_weapon_id)
	var old_weapon_id := String(player.call("get_weapon_in_category", category)) if player.has_method("get_weapon_in_category") else ""
	if old_weapon_id == new_weapon_id:
		if pickup.has_method("release_reservation"):
			pickup.call("release_reservation", player)
		return
	var old_skin := int(player.call("get_weapon_skin_index", old_weapon_id)) if player.has_method("get_weapon_skin_index") and not old_weapon_id.is_empty() else 0
	var upgrades: Dictionary = {}
	var upgrades_variant: Variant = player.get("runtime_permanent_upgrades")
	if upgrades_variant is Dictionary:
		upgrades = upgrades_variant.duplicate(true)
	player.call("equip_weapon", new_weapon_id, config, upgrades, int(pickup.get("skin_index")))
	SFX.play_weapon_pickup()
	weapon_equipped.emit(new_weapon_id)
	if old_weapon_id.is_empty():
		pickup.queue_free()
		current_world_weapon_target = null
		return
	if pickup.has_method("release_reservation"):
		# The node is recycled as the old weapon after the swap; return it to
		# WORLD ownership before publishing that new item to Enemy AI.
		pickup.call("release_reservation", player)
	if pickup.has_method("set_weapon_id"):
		pickup.call("set_weapon_id", old_weapon_id, old_skin)
	pickup.set("mass", WEAPON_VISUALS.get_world_mass(old_weapon_id))
	var drop_direction: Vector2 = -player.last_move_direction.normalized() if player.last_move_direction.length_squared() > 0.001 else Vector2.LEFT
	var drop_position := _find_safe_world_weapon_drop_position(pickup)
	pickup.call_deferred("place_after_swap", drop_position, drop_direction * 10.0)


func _store_world_weapon(pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup) or player == null:
		return
	if not player.has_method("store_weapon_in_category"):
		return
	if pickup.has_method("request_player_pickup"):
		if not bool(pickup.call("request_player_pickup", player)):
			return
	elif pickup.has_method("is_available_for") and not bool(pickup.call("is_available_for", player)):
		return
	cancel_enemy_world_weapon_pickup(null, pickup)
	var weapon_id := String(pickup.get("weapon_id"))
	if not _is_pickup_weapon_id_allowed(weapon_id):
		if pickup.has_method("release_reservation"):
			pickup.call("release_reservation", player)
		return
	var category := WEAPON_VISUALS.get_category(weapon_id)
	var current_id := String(player.call("get_weapon_in_category", category)) if player.has_method("get_weapon_in_category") else ""
	if not current_id.is_empty():
		if pickup.has_method("release_reservation"):
			pickup.call("release_reservation", player)
		return
	var upgrades: Dictionary = {}
	var upgrades_variant: Variant = player.get("runtime_permanent_upgrades")
	if upgrades_variant is Dictionary:
		upgrades = upgrades_variant.duplicate(true)
	var stored := bool(player.call("store_weapon_in_category", weapon_id, config, upgrades, int(pickup.get("skin_index"))))
	if not stored:
		if pickup.has_method("release_reservation"):
			pickup.call("release_reservation", player)
		return
	SFX.play_weapon_pickup()
	weapon_equipped.emit(String(player.get("selected_weapon_id")))
	pickup.queue_free()
	current_world_weapon_target = null


func request_enemy_world_weapon_pickup(employee: EmployeeEnemy, pickup: Node2D) -> bool:
	## Queue an Enemy's valid pickup request for the end-of-tick arbitration
	## pass.  The request is a soft reservation only; Player E is resolved first.
	if (
		employee == null
		or not is_instance_valid(employee)
		or pickup == null
		or not is_instance_valid(pickup)
		or not pickup.is_in_group(&"world_weapon_pickups")
	):
		return false
	if pickup.has_method("request_enemy_pickup"):
		if not bool(pickup.call("request_enemy_pickup", employee)):
			return false
	elif pickup.has_method("try_reserve") and not bool(pickup.call("try_reserve", employee)):
		return false
	var key := pickup.get_instance_id()
	var requests: Array = pending_enemy_pickup_requests.get(key, [])
	for request_variant in requests:
		var request: Dictionary = request_variant
		var existing := request.get("employee") as EmployeeEnemy
		if existing == employee:
			return true
	_pickup_request_serial += 1
	requests.append({
		"employee": employee,
		"serial": _pickup_request_serial,
		"employee_id": employee.get_instance_id(),
	})
	pending_enemy_pickup_requests[key] = requests
	return true



func cancel_enemy_world_weapon_pickup(employee: EmployeeEnemy = null, pickup: Node2D = null) -> void:
	if employee == null and pickup == null:
		return
	var employee_id := employee.get_instance_id() if is_instance_valid(employee) else -1
	for pickup_key_variant in pending_enemy_pickup_requests.keys():
		var pickup_id := int(pickup_key_variant)
		if pickup != null and is_instance_valid(pickup) and pickup_id != pickup.get_instance_id():
			continue
		var requests: Array = pending_enemy_pickup_requests.get(pickup_id, [])
		var kept: Array = []
		for request_variant in requests:
			var request: Dictionary = request_variant
			if employee_id >= 0 and int(request.get("employee_id", -1)) != employee_id:
				kept.append(request)
		if kept.is_empty():
			pending_enemy_pickup_requests.erase(pickup_id)
		else:
			pending_enemy_pickup_requests[pickup_id] = kept


func _resolve_pending_enemy_pickup_requests() -> void:
	if pending_enemy_pickup_requests.is_empty():
		return
	var pickup_ids: Array = pending_enemy_pickup_requests.keys()
	pickup_ids.sort()
	for pickup_id_variant in pickup_ids:
		var pickup_id := int(pickup_id_variant)
		var pickup := instance_from_id(pickup_id) as Node2D
		var requests: Array = pending_enemy_pickup_requests.get(pickup_id, [])
		pending_enemy_pickup_requests.erase(pickup_id)
		if pickup == null or not is_instance_valid(pickup):
			continue
		requests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_serial := int(a.get("serial", 0))
			var b_serial := int(b.get("serial", 0))
			return a_serial < b_serial if a_serial != b_serial else int(a.get("employee_id", 0)) < int(b.get("employee_id", 0))
		)
		var committed := false
		for request_variant in requests:
			var request: Dictionary = request_variant
			var employee := request.get("employee") as EmployeeEnemy
			if employee == null or not is_instance_valid(employee) or employee.get("dead"):
				continue
			var radius_variant: Variant = pickup.get("interaction_radius")
			var radius := 34.0 if radius_variant == null else float(radius_variant)
			if employee.global_position.distance_squared_to(pickup.global_position) > radius * radius:
				continue
			var owns_pickup := (
				bool(pickup.call("commit_enemy_pickup", employee))
				if pickup.has_method("commit_enemy_pickup")
				else true
			)
			if not owns_pickup:
				continue
			if employee.has_method("commit_reserved_world_weapon"):
				employee.call("commit_reserved_world_weapon", pickup)
			else:
				employee.call("_collect_weapon", pickup, false)
			committed = true
			break
		var ownership_variant: Variant = pickup.get("ownership_state")
		var ownership_state := (
			WorldWeaponPickup.OwnershipState.WORLD
			if ownership_variant == null
			else int(ownership_variant)
		)
		if (
			not committed
			and pickup.has_method("release_reservation")
			and ownership_state == WorldWeaponPickup.OwnershipState.WORLD
		):
			pickup.call("release_reservation")


func _find_safe_world_weapon_drop_position(pickup: Node2D) -> Vector2:
	var origin: Vector2 = player.global_position + Vector2.LEFT * 16.0 if player != null else pickup.global_position
	var candidates := [origin, player.global_position + Vector2.RIGHT * 20.0, player.global_position + Vector2.UP * 20.0, player.global_position + Vector2.DOWN * 20.0]
	for candidate in candidates:
		if _content_position_is_clear(candidate, 8.0, false):
			return candidate
	return pickup.global_position


func regenerate(requested_seed: int = seed) -> bool:
	# Standalone/debug runs may call regenerate(seed) directly instead of the
	# campaign configurator.  Treat that first seed as the run's stable base so
	# later Elevator floors remain deterministic as well.
	if floor_index <= 0 and not campaign_run:
		base_floor_seed = requested_seed
	_startup_profile_begin_generation()
	generation_progress.emit(0.10, "生成宅邸空间拓扑...")
	var regenerate_started_usec := _startup_profile_generation_started_usec
	var phase_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_clear_generated_building()
	_startup_profile_record_time("clear_generated_building_ms", phase_started_usec)
	camera_aim_offset = Vector3.ZERO
	if not generate_layout_only(requested_seed):
		_startup_profile_record_time("regenerate_total_ms", regenerate_started_usec)
		_startup_profile_emit("regenerate_failed")
		push_error(
			"Dream3D building layout failed after %d attempts (seed %d)."
			% [max_layout_attempts, requested_seed]
		)
		return false
	generation_progress.emit(0.35, "构建走廊与房间结构...")
	# Keep the full corridor cells in the logical graph for deterministic room
	# selection/path diagnostics, but derive the physical presentation as two
	# independent straight stubs before any visual builders run.
	current_room_id = spawn_room_id
	phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_prepare_transition_stub_metadata()
	_startup_profile_record_time("prepare_transition_stub_metadata_ms", phase_started_usec)
	phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_rebuild_active_room_presentation()
	_startup_profile_record_time("active_room_presentation_ms", phase_started_usec)
	generation_progress.emit(0.60, "构建3D墙体与门窗...")
	phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_validate_rendered_edge_nodes()
	_startup_profile_record_time("validate_rendered_edges_ms", phase_started_usec)
	phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_place_player()
	_startup_profile_record_time("place_player_ms", phase_started_usec)
	if spawn_content:
		phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_spawn_random_content()
		_startup_profile_record_time("spawn_random_content_ms", phase_started_usec)
	_spawn_elevator()
	generation_progress.emit(0.88, "预加载实体与场景设施...")
	# Room clear remains a gameplay state; the former door/corridor arrow
	# presentation is retired for Random3D.  Elevator/badge markers are the only
	# progression guidance now.
	enemy_population_refill_left = _enemy_population_interval()
	last_validation_report.merge(get_content_validation_report(), true)
	phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_update_camera_and_actor_projection()
	_startup_profile_record_time("camera_projection_ms", phase_started_usec)
	_get_projectile_capture_pool().prewarm(camera_3d)
	_get_muzzle_capture_pool().prewarm(camera_3d)
	_get_shell_capture_pool().prewarm(camera_3d)
	_get_feedback_capture_pool().prewarm(camera_3d)
	_get_blood_ground_capture_pool().prewarm(camera_3d,BLOOD_FLOOR_WORLD_Y)
	_get_floor_object_capture_pool().prewarm(camera_3d,dynamic_shadows_enabled)
	_floor_path_cache_enabled = true
	_current_floor_path_adjacency()
	if room_visibility == null:
		room_visibility = preload("res://scripts/dream/dream_3d_room_visibility.gd").new()
		add_child(room_visibility)
	phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	room_visibility.configure(self)
	_prepare_approved_office_art()
	_prepare_wall_shadow_batches()
	_startup_profile_record_time("room_visibility_ms", phase_started_usec)
	_configure_dungeon_minimap()
	preload("res://scripts/dream/combat_vfx.gd").install(self)
	preload("res://scripts/dream/floor_reflections.gd").install(self)
	if not dynamic_shadows_enabled and is_instance_valid(player) and player.has_node("Shadow"):
		_spawn_depth_bridge(player, [^"Shadow"], Vector2(64, 64), BaseMaterial3D.BILLBOARD_DISABLED, 0.015, 0.0, Vector3(-PI / 2.0, 0, 0))
	# 灯光与投影体全部就位之后再打层：捕获相机要靠这些位把"灯"和"投影体"
	# 收进 capture，同时把主世界的可见几何挡在外面。
	if floor_transition_in_progress:
		_set_building_exterior_visible(false)
	else:
		_set_building_exterior_visible(true)
	_startup_profile_record_time("regenerate_total_ms", regenerate_started_usec)
	_startup_profile_emit("regenerate")
	generation_progress.emit(1.0, "神经同步完成")
	if is_instance_valid(objective_guidance):
		objective_guidance.reset_floor()
	if not loading_render_preparation_pending and enable_game_start_cab_exit and floor_index == 0 and not player_has_left_elevator_cab and elevator_floor_door != null and player != null:
		call_deferred("_perform_game_start_cab_exit")
	return true


func _prepare_approved_office_art() -> void:
	if not approved_sample_art_enabled or use_authored_office_sample or not is_instance_valid(office_art_root):
		return
	if office_art_root.get_child_count()>0:
		return
	var art: Node3D = preload("res://scripts/dream/office_approved_art.gd").new()
	art.name = "ApprovedOfficeArt"
	art.world = self
	office_art_root.add_child(art)


func _prepare_wall_shadow_batches() -> void:
	if bool(get_meta(&"test_legacy_wall_shadow_batches", false)):
		return
	if not dynamic_shadows_enabled or wall_root == null or not is_instance_valid(wall_root):
		return
	var existing := wall_root.get_node_or_null("WallShadowBatches")
	if existing != null and is_instance_valid(existing):
		existing.free()
	var batches := preload("res://scripts/dream/wall_shadow_batches.gd").new()
	batches.build(wall_root)
	_prepare_wall_cutout_cache()


func _prepare_wall_cutout_cache() -> void:
	_static_cutout_walls.clear()
	_static_cutout_wall_positions.clear()
	_static_cutout_wall_bins.clear()
	_static_cutout_wall_edges.clear()
	_static_cutout_wall_heights.clear()
	_static_cutout_wall_meshes.clear()
	if not is_instance_valid(wall_root):
		return
	var all_walls := wall_root.get_children()
	for wall in all_walls:
		if wall.name == &"WallShadowBatches":
			continue
		_static_cutout_walls.append(wall)
		var pos: Vector3 = wall.global_position if wall is Node3D else Vector3(INF, INF, INF)
		_static_cutout_wall_positions.append(pos)
		var wall_mesh := wall.get_node_or_null("WallMesh") as VisualInstance3D
		# Soft ALPHA cutout does not need exclusive layer 8; keep default lighting layer.
		_static_cutout_wall_meshes.append(wall_mesh)
		var edge: Dictionary = wall.get_meta(&"edge", {})
		_static_cutout_wall_edges.append(edge)
		var h: float = float(wall.get("wall_height")) if wall.get("wall_height") != null else wall_height
		_static_cutout_wall_heights.append(h)
		if pos.x != INF:
			var bin_key := Vector2i(int(floor(pos.x / 4.0)), int(floor(pos.z / 4.0)))
			if not _static_cutout_wall_bins.has(bin_key):
				_static_cutout_wall_bins[bin_key] = []
			_static_cutout_wall_bins[bin_key].append(_static_cutout_walls.size() - 1)


func begin_firearm_render_preparation() -> bool:
	if bool(get_meta(&"test_skip_firearm_render_preparation",false)):
		return false
	if is_instance_valid(shadow_manager): shadow_manager.prepare_loading_selection()
	return true


func complete_firearm_render_preparation(report: Dictionary) -> void:
	last_firearm_render_preparation=report
	firearm_render_preparation_finished.emit(last_firearm_render_preparation)


func finish_loading_render_preparation() -> void:
	if not loading_render_preparation_pending: return
	loading_render_preparation_pending=false
	if enable_game_start_cab_exit and floor_index==0 and not player_has_left_elevator_cab and elevator_floor_door!=null and player!=null:
		call_deferred("_perform_game_start_cab_exit")


## Pure data entry used by deterministic headless tests.
func generate_layout_only(requested_seed: int) -> bool:
	active_seed = requested_seed
	_rng.seed = requested_seed
	var layout_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	for layout_attempt in range(max_layout_attempts):
		_startup_profile_increment("outer_layout_attempts")
		_reset_layout_data()
		if not _generate_building_layout():
			_startup_profile_increment("outer_layout_failures")
			continue
		var validation_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
		last_validation_report = _validate_layout()
		_startup_profile_record_time("validate_layout_ms", validation_started_usec)
		if bool(last_validation_report.get("valid", false)):
			last_validation_report["layout_attempt"] = layout_attempt + 1
			last_validation_report["seed"] = requested_seed
			_startup_profile_record_time("generate_layout_only_ms", layout_started_usec)
			return true
		_startup_profile_increment("outer_validation_failures")
	last_validation_report = {"valid": false, "seed": requested_seed, "reason": "layout_attempts_exhausted"}
	_startup_profile_record_time("generate_layout_only_ms", layout_started_usec)
	return false


func get_validation_report() -> Dictionary:
	return last_validation_report.duplicate(true)


func get_layout_signature() -> String:
	var parts: Array[String] = []
	parts.append("B:%d,%d,%d,%d" % [building_rect.position.x, building_rect.position.y, building_rect.size.x, building_rect.size.y])
	for room in rooms:
		var rect: Rect2i = room["grid_rect"]
		parts.append("R%d:%d,%d,%d,%d" % [room["id"], rect.position.x, rect.position.y, rect.size.x, rect.size.y])
		parts.append("SHAPE:%s:%s:%s:M%s" % [room.get("size_class", &"small"), room.get("shape", &"rectangle"), room.get("macro_coord", Vector2i.ZERO), room.get("center_cell", Vector2i.ZERO)])
	for partition in partitions:
		# Diagnostics cover both split partitions and footprint metadata. Keep
		# every actual field in deterministic key order, without assuming BSP.
		var partition_keys := partition.keys()
		partition_keys.sort()
		var values: Array[String] = []
		for key in partition_keys: values.append("%s=%s" % [key,str(partition[key])])
		parts.append("P:" + ";".join(values))
	for connection in connections:
		parts.append("E%d-%d:%d:%s:%s" % [connection["a"], connection["b"], connection["length"], _edge_key_from_door(connection["door_a"]), _edge_key_from_door(connection["door_b"])])
	parts.append("C:%d,%d" % [corridor_cells.size(), connections.size()])
	for corridor in corridors:
		parts.append("COR%d:%d-%d:%d" % [int(corridor.get("id", -1)), int(corridor.get("room_a", -1)), int(corridor.get("room_b", -1)), corridor.get("cells", []).size()])
	parts.append("M:SEALED:S%d:%d,%d:K%d:B%d:D%d" % [spawn_room_id, spawn_cell.x, spawn_cell.y, key_room_id, boss_room_id, boss_door_id])
	return "|".join(parts)


func get_room_center_cell(room_id: int) -> Vector2i:
	if room_id < 0 or room_id >= rooms.size():
		return Vector2i.ZERO
	return rooms[room_id]["center_cell"]


func get_player_root_position_for_cell(cell: Vector2i) -> Vector2:
	var collision_offset := Vector2.ZERO
	if player != null:
		var body_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if body_collision != null:
			collision_offset = body_collision.position
	return Vector2(cell.x, cell.y) * CELL_PIXELS - collision_offset


func find_floor_path(start: Vector2i, finish: Vector2i, ignore_boss_lock: bool = true) -> Array[Vector2i]:
	var path_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("find_floor_path_calls")
	var empty_result: Array[Vector2i] = []
	if not floor_cells.has(start) or not floor_cells.has(finish):
		_startup_profile_record_time("find_floor_path_ms", path_started_usec)
		_startup_profile_increment("find_floor_path_failures")
		return empty_result
	var came_from: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var legacy_query := bool(get_meta(&"test_legacy_floor_path",false))
	var adjacency := _current_floor_path_adjacency() if not legacy_query else {}
	var use_adjacency := not adjacency.is_empty()
	if use_adjacency and not bool(get_meta(&"test_legacy_goal_search",false)):
		var shared_path := _find_floor_path_to_shared_goal(start,finish,adjacency)
		_startup_profile_record_time("find_floor_path_ms", path_started_usec)
		_startup_profile_increment("find_floor_path_failures" if shared_path.is_empty() else "find_floor_path_successes")
		return shared_path
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue.pop_front() if legacy_query else queue[head]
		if not legacy_query: head+=1
		if current == finish:
			break
		if use_adjacency:
			for neighbor in adjacency[current]:
				if not came_from.has(neighbor):
					came_from[neighbor] = current; queue.append(neighbor)
		else:
			for direction in CARDINAL_DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if floor_cells.has(neighbor) and not came_from.has(neighbor) and _can_cross_floor_edge(current, neighbor, ignore_boss_lock):
					came_from[neighbor] = current
					queue.append(neighbor)
	if not came_from.has(finish):
		_startup_profile_record_time("find_floor_path_ms", path_started_usec)
		_startup_profile_increment("find_floor_path_failures")
		return empty_result
	var reversed_path: Array[Vector2i] = [finish]
	var cursor := finish
	while cursor != start:
		cursor = came_from[cursor]
		reversed_path.append(cursor)
	reversed_path.reverse()
	_startup_profile_record_time("find_floor_path_ms", path_started_usec)
	_startup_profile_increment("find_floor_path_successes")
	return reversed_path


func _current_floor_path_adjacency() -> Dictionary:
	# Only the formal implementation has this wall-membership edge contract.
	# Derived scenes may override it (locks, different connections): keep their
	# original query rather than guessing which extra state must invalidate it.
	if not _floor_path_cache_enabled or get_script().resource_path not in ["res://scripts/dream/dream_3d_random_dungeon.gd","res://scripts/dream/office_skeleton_world_base.gd"]: return {}
	# Native key-array equality is exact, not a hash or a time-based guess.
	# Detect even same-size replacements or in-place glass/wall changes.
	var floors := floor_cells.keys()
	var walls := wall_edges.keys()
	if floors==_floor_path_floor_keys and walls==_floor_path_wall_keys: return _floor_path_adjacency
	_floor_path_goal_searches.clear()
	_floor_path_goal_order.clear()
	if floors==_floor_path_floor_keys and not _floor_path_adjacency.is_empty():
		# Destruction changes edges, not the floor. Recompute just their two
		# endpoints, retaining cardinal ordering; never rebuild the whole floor
		# in the first AI query after breaking a pane.
		var affected: Dictionary = {}
		for key in _floor_path_wall_keys:
			if not wall_edges.has(key): _mark_floor_path_edge_cells(String(key),affected)
		for key in walls:
			if not _floor_path_wall_membership.has(key): _mark_floor_path_edge_cells(String(key),affected)
		for cell in affected:
			if floor_cells.has(cell): _floor_path_adjacency[cell] = _floor_path_cell_neighbors(cell)
		_floor_path_wall_keys = walls
		_floor_path_wall_membership.clear()
		for key in walls: _floor_path_wall_membership[key] = true
		return _floor_path_adjacency
	_floor_path_floor_keys = floors; _floor_path_wall_keys = walls
	_floor_path_wall_membership.clear()
	for key in walls: _floor_path_wall_membership[key] = true
	_floor_path_adjacency.clear()
	for cell in floors:
		_floor_path_adjacency[cell] = _floor_path_cell_neighbors(cell)
	return _floor_path_adjacency


func _find_floor_path_to_shared_goal(start: Vector2i, finish: Vector2i, adjacency: Dictionary) -> Array[Vector2i]:
	# Formal edges are undirected. Reverse BFS supplies exact distances; choosing
	# the first cardinal neighbor with distance d-1 reconstructs the same
	# lexicographically first shortest path as the original forward BFS.
	# Expand only until this start is discovered; later callers resume the same
	# frontier instead of searching the entire floor again. Four goals bound
	# retained data; topology changes invalidate all frontiers immediately.
	if not _floor_path_goal_searches.has(finish):
		if _floor_path_goal_order.size()>=4:
			_floor_path_goal_searches.erase(_floor_path_goal_order.pop_front())
		_floor_path_goal_searches[finish] = {"distances":{finish:0},"queue":[finish],"head":0}
	_floor_path_goal_order.erase(finish)
	_floor_path_goal_order.append(finish)
	var search: Dictionary = _floor_path_goal_searches[finish]
	var distances: Dictionary = search.distances
	var queue: Array = search.queue
	var head: int = search.head
	while not distances.has(start) and head<queue.size():
		var current: Vector2i = queue[head]
		head+=1
		var next_distance: int = int(distances[current])+1
		for neighbor in adjacency[current]:
			if not distances.has(neighbor):
				distances[neighbor] = next_distance
				queue.append(neighbor)
	search.head = head
	var path: Array[Vector2i] = []
	if not distances.has(start): return path
	var cursor := start
	path.append(cursor)
	while cursor!=finish:
		var next_distance: int = int(distances[cursor])-1
		for neighbor in adjacency[cursor]:
			if int(distances.get(neighbor,-1))==next_distance:
				cursor = neighbor
				path.append(cursor)
				break
	return path


func _floor_path_cell_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell+direction
		if floor_cells.has(neighbor) and _can_cross_floor_edge(cell,neighbor,true): neighbors.append(neighbor)
	return neighbors


func _mark_floor_path_edge_cells(key: String, affected: Dictionary) -> void:
	var parts := key.split(":")
	if parts.size()!=3: return # Non-geometric keys cannot match an edge query.
	var cell := Vector2i(int(parts[1]),int(parts[2]))
	if key!=_edge_key({"axis":parts[0],"x":cell.x,"y":cell.y}): return
	if parts[0] not in ["V","H"]: return
	affected[cell] = true
	affected[cell+(Vector2i.LEFT if parts[0]=="V" else Vector2i.UP)] = true


func _reset_layout_data() -> void:
	_floor_path_cache_enabled = false
	_floor_path_adjacency.clear(); _floor_path_floor_keys.clear(); _floor_path_wall_keys.clear()
	_floor_path_wall_membership.clear()
	_floor_path_goal_searches.clear(); _floor_path_goal_order.clear()
	building_rect = Rect2i()
	rooms.clear()
	partitions.clear()
	corridors.clear()
	connections.clear()
	macro_graph.clear()
	room_states.clear()
	corridor_states.clear()
	room_encounters.clear()
	room_layout_plans.clear()
	room_ambient_spawned.clear()
	room_ambient_spawn_pending.clear()
	floor_cells.clear()
	presentation_floor_cells.clear()
	room_cells.clear()
	corridor_cells.clear()
	pit_cells.clear()
	pillar_footprints.clear()
	pillar_cells.clear()
	internal_wall_edges.clear()
	wall_edges.clear()
	window_wall_edges.clear()
	glass_wall_edges.clear()
	door_edges.clear()
	door_opening_edges.clear()
	edge_states.clear()
	spawn_room_id = -1
	boss_room_id = -1
	key_room_id = -1
	boss_distances.clear()
	key_distances.clear()
	spawn_cell = Vector2i.ZERO
	main_entrance.clear()
	_next_door_id = 0
	door_transit_registry.clear()
	_door_transit_serial = 0
	_open_connected_rooms_cache.clear()
	_open_boundary_edges_cache.clear()
	boss_door_id = -1
	boss_door_edge_key = ""
	boss_door_node = null
	boss_enemy = null
	boss_defeated = false
	wake_exit_trigger = null
	wake_exit_visual = null
	floor_badge_pickup = null
	badge_marker = null
	elevator_anchor_cell = Vector2i.ZERO
	elevator_room_id = -1
	floor_shape = &"rectangle"
	elevator_edge_key = ""
	elevator_trigger = null
	elevator_visual = null
	elevator_sliding_door_root = null
	elevator_left_door = null
	elevator_right_door = null
	elevator_door_collider = null
	elevator_door_shape = null
	elevator_approach_trigger = null
	elevator_indicator_label = null
	elevator_door_pos_2d = Vector2.ZERO
	elevator_cab_inward_2d = Vector2.UP
	if not floor_transition_in_progress:
		elevator_doors_open = true
		player_has_left_elevator_cab = false
		floor_transition_in_progress = false
	else:
		elevator_doors_open = false
		player_has_left_elevator_cab = false
	if elevator_sliding_tween != null and elevator_sliding_tween.is_valid():
		elevator_sliding_tween.kill()
	elevator_sliding_tween = null
	elevator_state = &"LOCKED"
	badge_drop_committed = false
	badge_drop_pending = false
	run_finished = false
	start_to_boss_blocked_before_key = false
	key_pickup = null
	# `has_floor_badge` is consumed only after a successful floor commit.  Keep
	# it across the internal regenerate call so a failed layout retry cannot
	# silently discard the player's badge.
	has_boss_key = false
	furniture_count = 0
	enemy_count = 0
	effective_global_enemy_cap = maxi(global_enemy_cap, 0)
	enemy_population_refill_left = 0.0
	enemy_population_breathing_left.clear()
	reserved_content_cells.clear()
	employee_path_cache.clear()
	last_safe_floor_position = Vector2.ZERO
	_pit_player_handled = false
	_pit_enemy_handled.clear()


func _is_otxo_mansion() -> bool:
	return config != null and String(config.get("map_generator_type")) == "otxo_mansion"


func _generate_building_layout() -> bool:
	var generated: Dictionary = {}
	if _is_otxo_mansion():
		var otxo_options := {
			"floor_index": floor_index,
			"otxo_mansion_room_count": int(config.otxo_mansion_room_count) if config != null else 16,
			"otxo_mansion_glass_chance": float(config.otxo_mansion_glass_chance) if config != null else 0.35,
			"otxo_mansion_loop_ratio": float(config.otxo_mansion_loop_ratio) if config != null else 0.45,
			"building_width": 64,
			"building_height": 48,
		}
		var otxo_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
		var generator: Script = OFFICE_SAMPLE_SCRIPT if use_authored_office_sample else OFFICE_LEVEL_PACK_SCRIPT
		generated = generator.call("generate", _rng, otxo_options)
		_startup_profile_record_time("otxo_mansion_generate_ms", otxo_started_usec)
		lazy_room_presentation = false
	else:
		lazy_room_presentation = false
		var options := {
			"room_count": room_count,
			"min_room_width": min_room_width,
			"min_room_height": min_room_height,
			"macro_room_max_width": macro_room_max_width,
			"macro_room_max_height": macro_room_max_height,
			"medium_room_min_width": medium_room_min_width,
			"medium_room_min_height": medium_room_min_height,
			"medium_room_max_width": medium_room_max_width,
			"medium_room_max_height": medium_room_max_height,
			"large_room_min_width": large_room_min_width,
			"large_room_min_height": large_room_min_height,
			"large_room_max_width": large_room_max_width,
			"large_room_max_height": large_room_max_height,
			"small_room_weight": small_room_weight,
			"medium_room_weight": medium_room_weight,
			"large_room_weight": large_room_weight,
			"macro_pitch": macro_room_pitch,
			"corridor_width": corridor_width,
			# Keep corridor and doorway values independent in the generated metadata;
			# the current approved layout uses a four-cell corridor and four-cell door.
			"door_opening_cells": DEFAULT_ROOM_DOOR_OPENING_CELLS,
			"door_corner_clearance": door_corner_clearance,
			"macro_max_loops": macro_max_loops,
			"macro_square_weight": macro_square_weight,
			"macro_rectangle_weight": macro_rectangle_weight,
			"macro_irregular_weight": macro_irregular_weight,
			"macro_stepped_weight": macro_stepped_weight,
			"macro_hollow_weight": macro_hollow_weight,
			"rectangle_large_weight": rectangle_large_weight,
			"irregular_large_weight": irregular_large_weight,
			"courtyard_large_weight": courtyard_large_weight,
			"generation_bounds": generation_bounds,
			"max_attempts": max_layout_attempts,
			"macro_l_corridor_chance": macro_l_corridor_chance,
		}
		if _startup_profile_enabled:
			options["startup_profile_sink"] = Callable(self, "_startup_profile_record_macro_generation")
		var macro_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
		generated = MACRO_ROOM_GRAPH_SCRIPT.call("generate", _rng, options)
		_startup_profile_record_time("macro_graph_generate_ms", macro_started_usec)

	if generated.is_empty():
		return false
	building_rect = generated.get("building_rect", Rect2i())
	floor_shape = StringName(generated.get("floor_shape", &"rectangle"))
	rooms.assign(generated.get("rooms", []))
	for room in rooms:
		room["office_visual_style"] = preload("res://scripts/dream/dream_room_environment_theme.gd").style_for_room(room)
	partitions.assign(generated.get("partitions", []))
	corridors.assign(generated.get("corridors", []))
	connections.assign(generated.get("connections", []))
	floor_cells = generated.get("floor_cells", {}).duplicate(true)
	room_cells = generated.get("room_cells", {}).duplicate(true)
	corridor_cells = generated.get("corridor_cells", {}).duplicate(true)
	wall_edges = generated.get("wall_edges", {}).duplicate(true)
	door_edges = generated.get("door_edges", {}).duplicate(true)
	door_opening_edges = generated.get("door_opening_edges", {}).duplicate(true)
	glass_wall_edges = generated.get("glass_wall_edges", {}).duplicate(true)
	edge_states = generated.get("edge_states", {}).duplicate(true)
	macro_graph = generated.get("macro_graph", {}).duplicate(true)
	spawn_room_id = int(generated.get("spawn_room_id", -1))
	spawn_cell = generated.get("spawn_cell", Vector2i.ZERO)
	main_entrance = generated.get("main_entrance", {}).duplicate(true)
	_next_door_id = int(generated.get("next_door_id", door_edges.size()))
	room_states.clear()
	room_encounters.clear()
	room_layout_plans.clear()
	corridor_states.clear()
	for room in rooms:
		var room_id := int(room.get("id", -1))
		room_states[room_id] = room.get("state", &"UNSEEN")
		room_encounters[room_id] = {
			"enemy_spawns": [],
			"drop_spawns": [],
			"activated": false,
			"completed": false,
		}
	for corridor in corridors:
		corridor["state"] = &"UNSEEN"
		corridor["revealed"] = false
		corridor_states[int(corridor.get("id", -1))] = &"UNSEEN"
	if spawn_room_id < 0 or not _room_graph_is_connected():
		return false
	# 3D Random Dungeon no longer assigns a Boss/Key room.  Keep the legacy
	# fields at -1 for compatibility with old diagnostics, while every generated
	# room remains ordinary content and floor progression is owned by Elevator.
	_choose_key_and_boss_rooms()
	if not _is_otxo_mansion():
		var obstacles_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_generate_room_obstacles()
		_startup_profile_record_time("generate_room_obstacles_ms", obstacles_started_usec)
	_reserve_content_routes()
	# The floor exit is derived from the final walkable topology before any
	# presentation builders run.  A failed anchor invalidates this layout attempt
	# and lets the existing bounded generator retry deterministically.
	return _choose_elevator_anchor()


## Adds optional hazards/cover only after the macro graph has selected its
## Start/Key/Boss rooms.  The same floor-cell topology remains authoritative;
## accepted edits are committed only when every doorway in the affected room
## still belongs to one connected walkable component.
func _generate_room_obstacles() -> void:
	pit_cells.clear()
	pillar_footprints.clear()
	pillar_cells.clear()
	internal_wall_edges.clear()
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id < 0 or room_id == spawn_room_id:
			continue
		var size_class := StringName(room.get("size_class", &"small"))
		if size_class == &"small":
			continue
		var usable: Array = room.get("usable_cells", [])
		if usable.size() < 30 or _rng.randf() > (0.72 if size_class == &"large" else 0.48):
			continue
		var pit_attempts := 1 if size_class == &"medium" else (1 + (1 if _rng.randf() < 0.35 else 0))
		for _attempt in range(pit_attempts):
			var region := _pick_pit_region(room)
			if region.is_empty():
				_startup_profile_increment("pit_empty_candidates")
				continue
			_startup_profile_increment("pit_candidates")
			var accepted := true
			for cell_variant in region:
				var cell: Vector2i = cell_variant
				if not floor_cells.has(cell) or int(room_cells.get(cell, -1)) != room_id:
					accepted = false
					break
			if not accepted:
				_startup_profile_increment("pit_rejected_candidates")
				continue
			for cell_variant in region:
				var cell: Vector2i = cell_variant
				pit_cells[cell] = room_id
				floor_cells.erase(cell)
				room_cells.erase(cell)
			room["shape_cells"] = _array_without_cells(room.get("shape_cells", []), region)
			room["usable_cells"] = _array_without_cells(room.get("usable_cells", []), region)
			_rebuild_wall_edge_topology()
			if not _room_door_connectivity_valid(room_id):
				for cell_variant in region:
					var cell: Vector2i = cell_variant
					pit_cells.erase(cell)
					floor_cells[cell] = &"room"
					room_cells[cell] = room_id
					room["shape_cells"].append(cell)
					room["usable_cells"].append(cell)
				_rebuild_wall_edge_topology()
				_startup_profile_increment("pit_rollbacks")
			else:
				_startup_profile_increment("pit_accepts")
		# Reserve each room's existing door-to-center spine before placing cover.
		# This makes the pillar exclusion independent from the later content pass.
		_reserve_content_routes()
		# Interior procedural cover is deliberately limited to explicit 1x1
		# pillar footprints.  Do not synthesize random wall runs and attempt to
		# infer their shape after the fact: a footprint is the source of truth.
		var pillar_attempts := 1 if size_class == &"medium" else 2
		for _attempt in range(pillar_attempts):
			var pillar_cell := _pick_pillar_cell(room)
			if pillar_cell == INVALID_PILLAR_CELL:
				_startup_profile_increment("pillar_empty_candidates")
				break
			_startup_profile_increment("pillar_candidates")
			var footprint: Array[Vector2i] = [pillar_cell]
			var previous_usable: Array = room.get("usable_cells", []).duplicate()
			var previous_floor_value: Variant = floor_cells.get(pillar_cell, &"room")
			pillar_footprints.append(footprint)
			pillar_cells[pillar_cell] = room_id
			# Keep room_cells/shape_cells as structural membership.  A pillar is
			# an obstacle inside its room, not a hole outside the room identity.
			floor_cells.erase(pillar_cell)
			room["usable_cells"] = _array_without_cells(previous_usable, footprint)
			_rebuild_wall_edge_topology()
			if not _room_door_connectivity_valid(room_id):
				pillar_footprints.pop_back()
				pillar_cells.erase(pillar_cell)
				floor_cells[pillar_cell] = previous_floor_value
				room["usable_cells"] = previous_usable
				_rebuild_wall_edge_topology()
				_startup_profile_increment("pillar_rollbacks")
			else:
				_startup_profile_increment("pillar_accepts")


func _pick_pillar_cell(room: Dictionary) -> Vector2i:
	var room_id := int(room.get("id", -1))
	var candidates: Array = room.get("usable_cells", []).duplicate()
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var swap_value: Variant = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = swap_value
	for cell_variant in candidates:
		var cell: Vector2i = cell_variant
		if not floor_cells.has(cell) or int(room_cells.get(cell, -1)) != room_id:
			continue
		if pit_cells.has(cell) or pillar_cells.has(cell):
			continue
		if cell == spawn_cell or reserved_content_cells.has(cell):
			continue
		if _cell_near_room_outer_wall(room, cell, 2) or _cell_near_room_door(room, cell, 3.5):
			continue
		# Require a complete walkable ring around the footprint.  This keeps
		# every derived perimeter edge supported and prevents a pillar touching
		# an outer wall, pit, corridor, or another pillar.
		var ring_valid := true
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if (
				not floor_cells.has(neighbor)
				or int(room_cells.get(neighbor, -1)) != room_id
				or pit_cells.has(neighbor)
				or pillar_cells.has(neighbor)
				or reserved_content_cells.has(neighbor)
			):
				ring_valid = false
				break
		if not ring_valid:
			continue
		# A one-cell moat around the pillar also keeps diagonal actor routes
		# and door swing envelopes from being pinched.
		var neighborhood_valid := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nearby := cell + Vector2i(dx, dy)
				if nearby == cell:
					continue
				if pillar_cells.has(nearby) or pit_cells.has(nearby):
					neighborhood_valid = false
				if _cell_near_room_door(room, nearby, 2.5):
					neighborhood_valid = false
			if not neighborhood_valid:
				break
		if neighborhood_valid:
			return cell
	return INVALID_PILLAR_CELL


func _pick_pit_region(room: Dictionary) -> Array[Vector2i]:
	var shape_cells: Array = room.get("shape_cells", [])
	if shape_cells.is_empty():
		return []
	var region_size := Vector2i(2, 2)
	if _rng.randf() < 0.35:
		region_size = Vector2i(3, 2) if _rng.randf() < 0.5 else Vector2i(2, 3)
	var shuffled := shape_cells.duplicate()
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var swap_value = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = swap_value
	for origin_variant in shuffled:
		var origin: Vector2i = origin_variant
		var region: Array[Vector2i] = []
		for y in range(region_size.y):
			for x in range(region_size.x):
				region.append(origin + Vector2i(x, y))
		var valid := true
		var representative: Vector2i = room.get("center_cell", Vector2i.ZERO)
		for cell in region:
			if (
				cell == representative
				or not shape_cells.has(cell)
				or _cell_near_room_door(room, cell, 3.0)
				or _cell_near_room_outer_wall(room, cell, 2)
			):
				valid = false
				break
		if valid:
			return region
	return []


func _cell_near_room_outer_wall(room: Dictionary, cell: Vector2i, margin_cells: int = 2) -> bool:
	var rect: Rect2i = room.get("grid_rect", Rect2i())
	var margin := maxi(1, margin_cells)
	return (
		cell.x - rect.position.x < margin
		or rect.end.x - 1 - cell.x < margin
		or cell.y - rect.position.y < margin
		or rect.end.y - 1 - cell.y < margin
	)


func _cell_near_room_door(room: Dictionary, cell: Vector2i, distance_cells: float) -> bool:
	var room_id := int(room.get("id", -1))
	for connection_variant in connections:
		var connection: Dictionary = connection_variant
		for side in ["door_a", "door_b"]:
			var door_data: Dictionary = connection.get(side, {})
			if int(door_data.get("room_id", -1)) != room_id:
				continue
			var inside: Vector2i = door_data.get("inside_cell", cell)
			if Vector2(cell).distance_to(Vector2(inside)) < distance_cells:
				return true
	return false


func _array_without_cells(source: Array, removed: Array) -> Array:
	var result: Array = []
	for value in source:
		if not removed.has(value):
			result.append(value)
	return result


func _rebuild_wall_edge_topology() -> void:
	var authored_open_edges: Dictionary = {}
	for old_key_variant in edge_states.keys():
		var old_key: String = old_key_variant
		if String(edge_states[old_key]) == "OPEN":
			authored_open_edges[old_key] = true
	wall_edges.clear()
	edge_states.clear()
	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if floor_cells.has(neighbor):
				continue
			var edge := _edge_from_cell_direction(cell, direction)
			var key := _edge_key(edge)
			if door_edges.has(key):
				edge_states[key] = &"DOOR"
			elif door_opening_edges.has(key):
				edge_states[key] = &"DOOR_OPENING"
			else:
				edge_states[key] = &"WALL"
				wall_edges[key] = edge
	for key_variant in door_opening_edges.keys():
		var opening_key: String = key_variant
		if not edge_states.has(opening_key):
			edge_states[opening_key] = &"DOOR_OPENING"
	for key_variant in door_edges.keys():
		var door_key: String = key_variant
		if not edge_states.has(door_key):
			edge_states[door_key] = &"DOOR"
	for open_key_variant in authored_open_edges.keys():
		var open_key: String = open_key_variant
		wall_edges.erase(open_key)
		edge_states[open_key] = &"OPEN"
	# Re-derive procedural interior edges from the explicit pillar footprints.
	# Legacy/random edge fragments are never restored as an obstacle source.
	_derive_pillar_internal_wall_edges()
	_sanitize_internal_wall_edges()
	# Restore accepted internal walls after rebuilding boundaries.
	for key_variant in internal_wall_edges.keys():
		var key: String = key_variant
		var edge: Dictionary = internal_wall_edges[key]
		wall_edges[key] = edge
		edge_states[key] = &"WALL"


func _collect_pillar_wall_edges() -> Dictionary:
	var derived: Dictionary = {}
	for pillar_id in range(pillar_footprints.size()):
		var footprint_variant: Variant = pillar_footprints[pillar_id]
		if not footprint_variant is Array:
			continue
		var footprint: Array = footprint_variant
		# This pass intentionally supports the approved first version only:
		# one gameplay cell surrounded by four derived edges.
		if footprint.size() != 1:
			continue
		var cell_variant: Variant = footprint[0]
		if not cell_variant is Vector2i:
			continue
		var cell: Vector2i = cell_variant
		if floor_cells.has(cell) or not pillar_cells.has(cell):
			continue
		var perimeter: Dictionary = {}
		var valid := true
		for direction in CARDINAL_DIRECTIONS:
			var edge := _edge_from_cell_direction(cell, direction)
			var edge_key := _edge_key(edge)
			if door_edges.has(edge_key) or door_opening_edges.has(edge_key) or not wall_edges.has(edge_key):
				valid = false
				break
			edge["pillar_id"] = pillar_id
			edge["pillar_edge"] = true
			edge["protected_internal"] = true
			perimeter[edge_key] = edge
		if not valid:
			continue
		for key_variant in perimeter.keys():
			var perimeter_key: String = key_variant
			if derived.has(perimeter_key):
				valid = false
				break
		if not valid:
			continue
		for key_variant in perimeter.keys():
			var result_key: String = key_variant
			derived[result_key] = perimeter[result_key]
	return derived


func _derive_pillar_internal_wall_edges() -> void:
	internal_wall_edges = _collect_pillar_wall_edges()


func _sanitize_internal_wall_edges() -> void:
	# `pillar_footprints` is the only accepted source of internal wall edges.
	# Recompute rather than trusting stale metadata so a rebuild can never revive
	# a single dangling edge, an L wall, or a legacy random component.
	var expected := _collect_pillar_wall_edges()
	var kept: Dictionary = {}
	for key_variant in expected.keys():
		var key: String = key_variant
		if wall_edges.has(key):
			kept[key] = expected[key]
	internal_wall_edges = kept


func _room_door_connectivity_valid(room_id: int) -> bool:
	var connectivity_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("connectivity_validation_calls")
	var accesses: Array[Vector2i] = []
	for connection_variant in connections:
		var connection: Dictionary = connection_variant
		for side in ["door_a", "door_b"]:
			var door_data: Dictionary = connection.get(side, {})
			if int(door_data.get("room_id", -1)) == room_id:
				var inside: Vector2i = door_data.get("inside_cell", Vector2i.ZERO)
				if not floor_cells.has(inside):
					_startup_profile_record_time("connectivity_validation_ms", connectivity_started_usec)
					_startup_profile_increment("connectivity_validation_failures")
					return false
				accesses.append(inside)
	if accesses.is_empty():
		_startup_profile_record_time("connectivity_validation_ms", connectivity_started_usec)
		_startup_profile_increment("connectivity_validation_failures")
		return false
	# A one-door room still needs a real walkable interior; checking only
	# door-to-door pairs would incorrectly accept a pit that isolates the whole
	# room behind its sole entrance.  Validate every remaining room cell against
	# the first doorway, so irregular/hollow rooms use their actual topology.
	var anchor := accesses[0]
	# Every query below uses the same floor topology and the same edge policy as
	# `find_floor_path()`.  Build that reachable set once, then answer each room
	# cell query by membership.  This preserves the per-candidate validation
	# boundary while avoiding thousands of identical breadth-first searches.
	var reachable: Dictionary = _floor_distances(anchor, true)
	for cell_variant in room_cells.keys():
		var cell: Vector2i = cell_variant
		if int(room_cells.get(cell, -1)) != room_id:
			continue
		# Structural room membership intentionally includes pillar cells.  They
		# are obstacles inside the room, not a disconnected room identity; only
		# walkable floor cells participate in this path validation.
		if not floor_cells.has(cell):
			continue
		if not reachable.has(cell):
			_startup_profile_record_time("connectivity_validation_ms", connectivity_started_usec)
			_startup_profile_increment("connectivity_validation_failures")
			return false
	_startup_profile_record_time("connectivity_validation_ms", connectivity_started_usec)
	_startup_profile_increment("connectivity_validation_successes")
	return true


func _build_pit_visuals() -> void:
	if pit_root != null and is_instance_valid(pit_root):
		pit_root.queue_free()
		pit_root = null
	if pit_cells.is_empty() or generated_root == null:
		return
	pit_root = Node3D.new()
	pit_root.name = "PitVisualRoot"
	generated_root.add_child(pit_root)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.004, 0.005, 0.009, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.96, 0.96)
	for cell_variant in pit_cells.keys():
		var cell: Vector2i = cell_variant
		if lazy_room_presentation and int(room_cells.get(cell, -1)) != current_room_id:
			continue
		var tile := MeshInstance3D.new()
		tile.name = "Pit_%d_%d" % [cell.x, cell.y]
		tile.mesh = mesh
		tile.material_override = material
		tile.position = Vector3(cell.x, -0.035, cell.y)
		tile.rotation_degrees.x = -90.0
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pit_root.add_child(tile)


func _generate_building_footprint() -> bool:
	var width := _rng.randi_range(min_building_width, max_building_width)
	var height := _rng.randi_range(min_building_height, max_building_height)
	var min_x := generation_bounds.position.x
	var min_y := generation_bounds.position.y
	var max_x := generation_bounds.end.x - width
	var max_y := generation_bounds.end.y - height
	if max_x < min_x or max_y < min_y:
		return false
	building_rect = Rect2i(Vector2i(_rng.randi_range(min_x, max_x), _rng.randi_range(min_y, max_y)), Vector2i(width, height))
	return true


func _partition_building() -> bool:
	var leaf_rects: Array[Rect2i] = [building_rect]
	var leaf_depths: Array[int] = [0]
	var guard := 0
	while leaf_rects.size() < room_count and guard < room_count * 12:
		guard += 1
		var candidates: Array[int] = []
		for index in range(leaf_rects.size()):
			if leaf_depths[index] < max_partition_depth and not _split_rect(leaf_rects[index]).is_empty():
				candidates.append(index)
		if candidates.is_empty():
			return false
		# Prefer a large splittable region so the exact room target cannot be
		# stranded by consuming all of the small leaves too early. Randomly
		# choose among similarly large candidates to keep varied layouts.
		var largest_area := 0
		for candidate_index in candidates:
			largest_area = maxi(largest_area, leaf_rects[candidate_index].get_area())
		var preferred_candidates: Array[int] = []
		for candidate_index in candidates:
			if leaf_rects[candidate_index].get_area() * 4 >= largest_area * 3:
				preferred_candidates.append(candidate_index)
		var selected_index: int = preferred_candidates[_rng.randi_range(0, preferred_candidates.size() - 1)]
		var split_data: Dictionary = _split_rect(leaf_rects[selected_index])
		if split_data.is_empty():
			return false
		var child_depth: int = leaf_depths[selected_index] + 1
		leaf_rects.remove_at(selected_index)
		leaf_depths.remove_at(selected_index)
		leaf_rects.append(split_data["first_rect"])
		leaf_rects.append(split_data["second_rect"])
		leaf_depths.append(child_depth)
		leaf_depths.append(child_depth)
		partitions.append({
			"id": partitions.size(),
			"depth": child_depth,
			"axis": split_data["axis"],
			"cut": split_data["cut"],
			"span_start": split_data["span_start"],
			"span_end": split_data["span_end"],
			"first_rect": split_data["first_rect"],
			"second_rect": split_data["second_rect"],
		})
	return leaf_rects.size() == room_count


func _split_rect(rect: Rect2i) -> Dictionary:
	var can_split_vertical := rect.size.x >= min_room_width * 2
	var can_split_horizontal := rect.size.y >= min_room_height * 2
	if not can_split_vertical and not can_split_horizontal:
		return {}
	var split_vertical := false
	if can_split_vertical and not can_split_horizontal:
		split_vertical = true
	elif can_split_horizontal and not can_split_vertical:
		split_vertical = false
	elif rect.size.x > rect.size.y * 1.2:
		split_vertical = true
	elif rect.size.y > rect.size.x * 1.2:
		split_vertical = false
	else:
		split_vertical = _rng.randi_range(0, 1) == 0

	if split_vertical:
		var min_cut := rect.position.x + min_room_width
		var max_cut := rect.end.x - min_room_width
		if min_cut > max_cut:
			return {}
		var cut_x := _rng.randi_range(min_cut, max_cut)
		return {
			"axis": "V", "cut": cut_x, "span_start": rect.position.y, "span_end": rect.end.y,
			"first_rect": Rect2i(rect.position, Vector2i(cut_x - rect.position.x, rect.size.y)),
			"second_rect": Rect2i(Vector2i(cut_x, rect.position.y), Vector2i(rect.end.x - cut_x, rect.size.y)),
		}
	var min_cut_y := rect.position.y + min_room_height
	var max_cut_y := rect.end.y - min_room_height
	if min_cut_y > max_cut_y:
		return {}
	var cut_y := _rng.randi_range(min_cut_y, max_cut_y)
	return {
		"axis": "H", "cut": cut_y, "span_start": rect.position.x, "span_end": rect.end.x,
		"first_rect": Rect2i(rect.position, Vector2i(rect.size.x, cut_y - rect.position.y)),
		"second_rect": Rect2i(Vector2i(rect.position.x, cut_y), Vector2i(rect.size.x, rect.end.y - cut_y)),
	}


func _build_room_data() -> void:
	# Replay the BSP splits to recover final leaf rectangles in deterministic
	# order.  A leaf is any current rectangle that has not been split again.
	var candidates: Array[Rect2i] = [building_rect]
	for partition in partitions:
		var first_rect: Rect2i = partition["first_rect"]
		var second_rect: Rect2i = partition["second_rect"]
		var parent_rect := Rect2i()
		for candidate in candidates:
			if candidate.encloses(first_rect) and candidate.encloses(second_rect):
				parent_rect = candidate
				break
		if parent_rect.size == Vector2i.ZERO:
			continue
		candidates.erase(parent_rect)
		candidates.append(first_rect)
		candidates.append(second_rect)

	for room_id in range(candidates.size()):
		var rect: Rect2i = candidates[room_id]
		var center := Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		rooms.append({"id": room_id, "grid_rect": rect, "center_cell": center, "connections": [], "room_type": &"normal"})
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				room_cells[cell] = room_id
				floor_cells[cell] = &"building"


func _build_internal_corridors() -> void:
	if building_rect.size == Vector2i.ZERO:
		return
	var corridor_width_cells: int = maxi(2, corridor_width)
	var start_offset: int = -int(floori(float(corridor_width_cells) / 2.0))
	var make_horizontal := _rng.randi_range(0, 1) == 0
	var main_cells: Dictionary = {}
	if make_horizontal:
		var center_y := building_rect.position.y + building_rect.size.y / 2
		for offset in range(corridor_width_cells):
			var y: int = center_y + start_offset + offset
			if y < building_rect.position.y or y >= building_rect.end.y:
				continue
			for x in range(building_rect.position.x, building_rect.end.x):
				main_cells[Vector2i(x, y)] = true
	else:
		var center_x := building_rect.position.x + building_rect.size.x / 2
		for offset in range(corridor_width_cells):
			var x: int = center_x + start_offset + offset
			if x < building_rect.position.x or x >= building_rect.end.x:
				continue
			for y in range(building_rect.position.y, building_rect.end.y):
				main_cells[Vector2i(x, y)] = true
	for cell_variant in main_cells.keys():
		corridor_cells[cell_variant] = true

	if _rng.randf() < subdivide_probability:
		if make_horizontal:
			var branch_x := building_rect.position.x + building_rect.size.x / 2
			for offset in range(corridor_width_cells):
				var x: int = branch_x + start_offset + offset
				if x < building_rect.position.x or x >= building_rect.end.x:
					continue
				for y in range(building_rect.position.y, building_rect.end.y):
					corridor_cells[Vector2i(x, y)] = true
		else:
			var branch_y := building_rect.position.y + building_rect.size.y / 2
			for offset in range(corridor_width_cells):
				var y: int = branch_y + start_offset + offset
				if y < building_rect.position.y or y >= building_rect.end.y:
					continue
				for x in range(building_rect.position.x, building_rect.end.x):
					corridor_cells[Vector2i(x, y)] = true
	for cell_variant in corridor_cells.keys():
		floor_cells[cell_variant] = &"corridor"
	corridors.append({"id": 0, "kind": &"main", "cells": corridor_cells.duplicate()})


func _build_topology() -> bool:
	wall_edges.clear()
	door_edges.clear()
	door_opening_edges.clear()
	edge_states.clear()
	connections.clear()
	for room in rooms:
		room["connections"] = []
	for partition in partitions:
		if not _build_partition_topology(partition):
			return false
	if not _choose_main_entrance():
		return false
	_build_outer_wall_topology()
	return true


func _build_partition_topology(partition: Dictionary, requested_coordinate: int = INVALID_DOOR_COORDINATE, additional: bool = false) -> bool:
	var axis: String = partition["axis"]
	var cut: int = partition["cut"]
	var span_start: int = partition["span_start"]
	var span_end: int = partition["span_end"]
	var door_coordinate: int = requested_coordinate if additional else _partition_open_coordinate(partition)
	if door_coordinate == INVALID_DOOR_COORDINATE:
		return false
	# 注册前最终 invariant gate：防止任何调用路径绕过 candidate 过滤
	# 放进一个跨 room-pair 边界的 opening（正常路径下恒过，纯防御）。
	if not _is_full_door_opening_valid(partition, door_coordinate):
		return false
	var opening_end := door_coordinate + DOOR_OPENING_CELLS
	for coordinate in range(span_start, span_start if additional else span_end):
		var edge: Dictionary
		if axis == "V":
			edge = {"axis": "V", "x": cut, "y": coordinate}
		else:
			edge = {"axis": "H", "x": coordinate, "y": cut}
		var key := _edge_key(edge)
		if coordinate >= door_coordinate and coordinate < opening_end:
			edge_states[key] = &"DOOR" if coordinate == door_coordinate else &"DOOR_OPENING"
		else:
			edge_states[key] = &"WALL"
			wall_edges[key] = edge

	var door_edge: Dictionary
	var first_inside: Vector2i
	var second_inside: Vector2i
	if axis == "V":
		door_edge = {"axis": "V", "x": cut, "y": door_coordinate}
		first_inside = Vector2i(cut - 1, door_coordinate)
		second_inside = Vector2i(cut, door_coordinate)
	else:
		door_edge = {"axis": "H", "x": door_coordinate, "y": cut}
		first_inside = Vector2i(door_coordinate, cut - 1)
		second_inside = Vector2i(door_coordinate, cut)
	var first_room := int(room_cells.get(first_inside, -1))
	var second_room := int(room_cells.get(second_inside, -1))
	if first_room < 0 or second_room < 0 or first_room == second_room:
		return false
	var outward_a := Vector2i(1, 0) if axis == "V" else Vector2i(0, 1)
	var outward_b := -outward_a
	var door_a := _make_door_data(first_inside, outward_a, first_room)
	var door_b := _make_door_data(second_inside, outward_b, second_room)
	var connection_id := connections.size()
	var door_id := _next_door_id
	_next_door_id += 1
	connections.append({"id": connection_id, "door_id": door_id, "a": first_room, "b": second_room, "length": _room_center_manhattan(first_room, second_room), "door_a": door_a, "door_b": door_b, "partition_id": partition["id"]})
	_add_room_connection(first_room, second_room)
	_add_room_connection(second_room, first_room)
	door_edge["connection_id"] = connection_id
	door_edge["door_id"] = door_id
	door_edge["region_a_id"] = first_room
	door_edge["region_b_id"] = second_room
	door_edge["partition_id"] = partition["id"]
	door_edge["kind"] = &"internal"
	door_edge["door_direction"] = axis
	door_edge["hinge_side"] = _hinge_side_for_edge(door_edge)
	door_edge["shared_boundary_length"] = span_end - span_start
	door_edge["opening_cells"] = DOOR_OPENING_CELLS
	door_edge["opening_start"] = door_coordinate
	door_edge["opening_end"] = opening_end
	door_edge["wall_edge"] = door_edge.duplicate(true)
	door_edge["door_position"] = _door_root_world_position(door_edge)
	edge_states[_edge_key(door_edge)] = &"DOOR"
	door_edges[_edge_key(door_edge)] = door_edge
	for opening_coordinate in range(door_coordinate, opening_end):
		var opening_edge := door_edge.duplicate(true)
		if axis == "V":
			opening_edge["y"] = opening_coordinate
		else:
			opening_edge["x"] = opening_coordinate
		door_opening_edges[_edge_key(opening_edge)] = door_edge
		wall_edges.erase(_edge_key(opening_edge))
		edge_states[_edge_key(opening_edge)] = &"DOOR" if opening_coordinate == door_coordinate else &"DOOR_OPENING"
	return true


func _add_optional_room_doors() -> void:
	# Ordinary rooms have no degree cap. Preserve the chosen terminal leaf while
	# adding loops between OTHER distinct regions on real shared boundaries.
	var protected_boss := boss_room_id
	for partition in partitions:
		if _rng.randf() > additional_door_chance:
			continue
		var candidates: Array[int] = []
		for coordinate in range(int(partition.span_start) + door_corner_clearance, int(partition.span_end) - DOOR_OPENING_CELLS - door_corner_clearance + 1):
			# 与 Primary 门共用同一套完整 opening 合法性（两侧 floor + 跨格 A/B pair）。
			if not _is_full_door_opening_valid(partition, coordinate):
				continue
			var first_edge := {"axis": partition.axis, "x": int(partition.cut) if partition.axis == "V" else coordinate, "y": coordinate if partition.axis == "V" else int(partition.cut)}
			var sides := _edge_side_cells(first_edge)
			var a := int(room_cells.get(sides[0], -1))
			var b := int(room_cells.get(sides[1], -1))
			var valid := a >= 0 and b >= 0 and a != b and a != protected_boss and b != protected_boss and _find_door_edge_between(a, b).is_empty()
			if valid:
				for offset in DOOR_OPENING_CELLS:
					var edge := {"axis": partition.axis, "x": int(partition.cut) if partition.axis == "V" else coordinate + offset, "y": coordinate + offset if partition.axis == "V" else int(partition.cut)}
					if not _door_candidate_is_clear(partition, coordinate + offset, edge):
						valid = false
						break
					# Keep the same swing envelope away from any newly carved core.
					for side in _edge_side_cells(edge):
						for dy in range(-2, 3):
							for dx in range(-2, 3):
								if not floor_cells.has(side + Vector2i(dx, dy)):
									valid = false
			if valid:
				candidates.append(coordinate)
		if not candidates.is_empty():
			_build_partition_topology(partition, candidates[_rng.randi_range(0, candidates.size()-1)], true)


func _reserve_content_routes() -> void:
	reserved_content_cells.clear()
	# Reserve three-cell-wide connected spines from every authored connection
	# socket to the room's legal representative.  A macro connection has two
	# sockets (one on each room side), even when only the first socket owns the
	# physical DoorLeaf; both mouths must remain clear for traversal and drops.
	for room in rooms:
		var center: Vector2i = room.center_cell
		var sockets: Array[Vector2i] = []
		for connection_variant in connections:
			var connection: Dictionary = connection_variant
			for side_key in [&"door_a", &"door_b"]:
				var side: Dictionary = connection.get(side_key, {})
				if int(side.get("room_id", -1)) != int(room.id):
					continue
				var inside_cell: Vector2i = side.get("inside_cell", Vector2i.ZERO)
				if not sockets.has(inside_cell):
					sockets.append(inside_cell)
		# Compatibility for legacy layouts without connection socket metadata.
		if sockets.is_empty():
			for edge in door_edges.values():
				for side in _edge_side_cells(edge):
					if int(room_cells.get(side, -1)) == int(room.id) and not sockets.has(side):
						sockets.append(side)
		for socket in sockets:
			if not floor_cells.has(socket):
				continue
			for cell in find_floor_path(center, socket, true):
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var reserved := cell + Vector2i(dx, dy)
						if floor_cells.has(reserved):
							reserved_content_cells[reserved] = true


func _partition_open_coordinate(partition: Dictionary) -> int:
	var start: int = partition["span_start"]
	var end: int = partition["span_end"]
	if end - start < minimum_door_boundary_length:
		return INVALID_DOOR_COORDINATE
	var center: int = (start + end - 1) / 2
	var minimum := start + door_corner_clearance
	var maximum := end - DOOR_OPENING_CELLS - door_corner_clearance
	if minimum > maximum:
		return INVALID_DOOR_COORDINATE
	var valid_candidates: Array[int] = []
	var corridor_candidates: Array[int] = []
	for coordinate in range(minimum, maximum + 1):
		var candidate_clear := true
		var touches_corridor := false
		for opening_offset in range(DOOR_OPENING_CELLS):
			var coordinate_value: int = coordinate + opening_offset
			var edge: Dictionary
			if String(partition["axis"]) == "V":
				edge = {"axis": "V", "x": partition["cut"], "y": coordinate_value}
			else:
				edge = {"axis": "H", "x": coordinate_value, "y": partition["cut"]}
			if not _door_candidate_is_clear(partition, coordinate_value, edge):
				candidate_clear = false
				break
			touches_corridor = touches_corridor or _edge_touches_corridor(edge)
		if candidate_clear and not _is_full_door_opening_valid(partition, coordinate):
			candidate_clear = false
		if not candidate_clear:
			continue
		valid_candidates.append(coordinate)
		if touches_corridor:
			corridor_candidates.append(coordinate)
	if valid_candidates.is_empty():
		return INVALID_DOOR_COORDINATE
	var candidates := corridor_candidates if not corridor_candidates.is_empty() else valid_candidates
	var best: int = candidates[0]
	var best_distance: int = absi(best * 2 + DOOR_OPENING_CELLS - 1 - center * 2)
	for candidate in candidates:
		var distance: int = absi(int(candidate) * 2 + DOOR_OPENING_CELLS - 1 - center * 2)
		if distance < best_distance:
			best = int(candidate)
			best_distance = distance
	return best


## 完整 opening 合法性（Primary / Optional / Boss 门共用的唯一规则）：
## DOOR_OPENING_CELLS 的每一格两侧都必须存在 floor、分属两个不同 region，
## 且整个 opening 保持完全相同且方向一致的 A/B room pair。任何一格不满足
## （例如 T/十字交汇跨在 opening 第二格上）即整扇门非法。
func _is_full_door_opening_valid(partition: Dictionary, coordinate: int) -> bool:
	var axis := String(partition["axis"])
	var cut := int(partition["cut"])
	var expected_a := -1
	var expected_b := -1
	for offset in range(DOOR_OPENING_CELLS):
		var opening_coordinate := coordinate + offset
		var edge: Dictionary
		if axis == "V":
			edge = {"axis": "V", "x": cut, "y": opening_coordinate}
		else:
			edge = {"axis": "H", "x": opening_coordinate, "y": cut}
		var sides := _edge_side_cells(edge)
		if sides.size() < 2:
			return false
		var room_a := int(room_cells.get(sides[0], -1))
		var room_b := int(room_cells.get(sides[1], -1))
		if room_a < 0 or room_b < 0 or room_a == room_b:
			return false
		if not floor_cells.has(sides[0]) or not floor_cells.has(sides[1]):
			return false
		if offset == 0:
			expected_a = room_a
			expected_b = room_b
		elif room_a != expected_a or room_b != expected_b:
			return false
	return true


func _door_candidate_is_clear(partition: Dictionary, coordinate: int, edge: Dictionary) -> bool:
	# End clearance keeps the frame away from both corners of its own boundary.
	var start: int = partition["span_start"]
	var end: int = partition["span_end"]
	if end - start < minimum_door_boundary_length:
		return false
	if coordinate - start < door_corner_clearance or end - 1 - coordinate < door_corner_clearance:
		return false

	# A perpendicular partition crossing is a T/cross junction.  Do not put a
	# door frame within the same clearance band as that junction.
	for other in partitions:
		if int(other["id"]) == int(partition["id"]):
			continue
		var other_axis: String = other["axis"]
		var axis: String = partition["axis"]
		if axis == other_axis:
			continue
		var junction_coordinate := INVALID_DOOR_COORDINATE
		if axis == "V":
			var crossing_y: int = other["cut"]
			if crossing_y >= start and crossing_y < end and int(partition["cut"]) >= int(other["span_start"]) and int(partition["cut"]) <= int(other["span_end"]):
				junction_coordinate = crossing_y
		else:
			var crossing_x: int = other["cut"]
			if crossing_x >= start and crossing_x < end and int(partition["cut"]) >= int(other["span_start"]) and int(partition["cut"]) <= int(other["span_end"]):
				junction_coordinate = crossing_x
		if junction_coordinate != INVALID_DOOR_COORDINATE and absi(coordinate - junction_coordinate) < door_corner_clearance:
			return false

	# Keep doors on a common physical boundary separated.  The edge key check
	# below rejects exact duplicates; this rejects near-duplicates.
	for existing_variant in door_edges.values():
		var existing: Dictionary = existing_variant
		if String(existing.get("axis", "")) != String(edge["axis"]):
			continue
		if String(edge["axis"]) == "V" and int(existing["x"]) != int(edge["x"]):
			continue
		if String(edge["axis"]) == "H" and int(existing["y"]) != int(edge["y"]):
			continue
		var existing_coordinate: int = int(existing["y"]) if String(edge["axis"]) == "V" else int(existing["x"])
		if absi(existing_coordinate - coordinate) < door_to_door_clearance:
			return false
	return true


func _edge_touches_corridor(edge: Dictionary) -> bool:
	var axis: String = String(edge.get("axis", ""))
	if axis.is_empty():
		return false
	if axis == "V":
		var y: int = int(edge.get("y", 0))
		var x: int = int(edge.get("x", 0))
		return corridor_cells.has(Vector2i(x - 1, y)) or corridor_cells.has(Vector2i(x, y))
	var x_h: int = int(edge.get("x", 0))
	var y_h: int = int(edge.get("y", 0))
	return corridor_cells.has(Vector2i(x_h, y_h - 1)) or corridor_cells.has(Vector2i(x_h, y_h))


func _edge_touches_elevator(edge: Dictionary) -> bool:
	if elevator_room_id < 0:
		return false
	var sides := _edge_side_cells(edge)
	for side in sides:
		if int(room_cells.get(side, -1)) == elevator_room_id:
			return true
	return false


func _elevator_sliding_door_edge() -> Dictionary:
	if _has_elevator_reception():
		return rooms[elevator_room_id].get("elevator_facade_edge", {})
	for edge_variant in door_edges.values():
		var edge: Dictionary = edge_variant
		if bool(edge.get("is_elevator_sliding_door", false)):
			return edge
	return {}


func _has_elevator_reception() -> bool:
	return elevator_room_id >= 0 and elevator_room_id < rooms.size() and bool(rooms[elevator_room_id].get("elevator_reception", false))


func _room_allows_furniture(room_id: int) -> bool:
	return room_id >= 0 and room_id < rooms.size() and (bool(rooms[room_id].get("elevator_reception", false)) or not _is_elevator_or_corridor_room(room_id))


func _edge_on_elevator_door_wall(edge: Dictionary) -> bool:
	# Only the doorway's own partition is visible. The separate elevator cab
	# must not acquire a floor-level shell from the other elevator-room edges.
	if not _edge_touches_elevator(edge):
		return false
	var door_edge := _elevator_sliding_door_edge()
	if door_edge.is_empty() or String(edge.get("axis", "")) != String(door_edge.get("axis", "")):
		return false
	if String(edge.get("axis", "")) == "H":
		return int(edge.get("y", 0)) == int(door_edge.get("y", 0))
	return int(edge.get("x", 0)) == int(door_edge.get("x", 0))


func _is_interior_open_office_edge(edge: Dictionary) -> bool:
	var sides := _edge_side_cells(edge)
	if sides.size() < 2:
		return false
	if not floor_cells.has(sides[0]) or not floor_cells.has(sides[1]):
		return false
	var has_office := false
	var has_corridor := false
	for side in sides:
		var room_id: int = int(room_cells.get(side, -1))
		if room_id >= 0 and room_id < rooms.size():
			var room: Dictionary = rooms[room_id]
			if String(room.get("archetype", "")) == "open_office" or String(room.get("sample_key", "")) == "office":
				has_office = true
			if String(room.get("archetype", "")) == "corridor":
				has_corridor = true
	return has_office if use_authored_office_sample else has_office and has_corridor


func _choose_main_entrance() -> bool:
	var side_options: Array[String] = ["S", "W", "E"]
	# Try each permitted exterior side in a deterministic shuffled order.  A
	# short wall must fail the attempt rather than silently relaxing clearance.
	var start_index := _rng.randi_range(0, side_options.size() - 1)
	for side_offset in range(side_options.size()):
		var side: String = side_options[(start_index + side_offset) % side_options.size()]
		var tangent_min: int
		var tangent_max: int
		var tangent: int
		var edge: Dictionary
		var inside: Vector2i
		var inward: Vector2i
		var outward: Vector2i
		if side == "S":
			tangent_min = building_rect.position.x + door_corner_clearance
			tangent_max = building_rect.end.x - DOOR_OPENING_CELLS - door_corner_clearance
			if tangent_min > tangent_max:
				continue
			tangent = _rng.randi_range(tangent_min, tangent_max)
			edge = {"axis": "H", "x": tangent, "y": building_rect.end.y}
			inside = Vector2i(tangent, building_rect.end.y - 1)
			inward = Vector2i(0, -1)
			outward = Vector2i(0, 1)
		elif side == "W":
			tangent_min = building_rect.position.y + door_corner_clearance
			tangent_max = building_rect.end.y - DOOR_OPENING_CELLS - door_corner_clearance
			if tangent_min > tangent_max:
				continue
			tangent = _rng.randi_range(tangent_min, tangent_max)
			edge = {"axis": "V", "x": building_rect.position.x, "y": tangent}
			inside = Vector2i(building_rect.position.x + 1, tangent)
			inward = Vector2i(1, 0)
			outward = Vector2i(-1, 0)
		else:
			tangent_min = building_rect.position.y + door_corner_clearance
			tangent_max = building_rect.end.y - DOOR_OPENING_CELLS - door_corner_clearance
			if tangent_min > tangent_max:
				continue
			tangent = _rng.randi_range(tangent_min, tangent_max)
			edge = {"axis": "V", "x": building_rect.end.x, "y": tangent}
			inside = Vector2i(building_rect.end.x - 1, tangent)
			inward = Vector2i(-1, 0)
			outward = Vector2i(1, 0)
		var candidate_spawn := inside + inward * 2
		if not floor_cells.has(candidate_spawn):
			candidate_spawn = inside
		var candidate_room_id := int(room_cells.get(candidate_spawn, -1))
		if candidate_room_id < 0:
			continue
		spawn_cell = candidate_spawn
		spawn_room_id = candidate_room_id
		# Start is now a sealed interior spawn.  Preserve the deterministic side
		# selection only as spawn metadata; do not reserve an exterior Door edge.
		# _build_outer_wall_topology() therefore restores a continuous outer wall.
		main_entrance = {
			"side": side,
			"inside_cell": inside,
			"spawn_cell": candidate_spawn,
			"outward": outward,
			"inward": inward,
			"sealed": true,
		}
		rooms[spawn_room_id]["room_type"] = &"spawn"
		return true
	return false


func _build_outer_wall_topology() -> void:
	for x in range(building_rect.position.x, building_rect.end.x):
		var north := {"axis": "H", "x": x, "y": building_rect.position.y}
		var south := {"axis": "H", "x": x, "y": building_rect.end.y}
		_register_outer_edge(north)
		_register_outer_edge(south)
	for y in range(building_rect.position.y, building_rect.end.y):
		var west := {"axis": "V", "x": building_rect.position.x, "y": y}
		var east := {"axis": "V", "x": building_rect.end.x, "y": y}
		_register_outer_edge(west)
		_register_outer_edge(east)


func _register_outer_edge(edge: Dictionary) -> void:
	var key := _edge_key(edge)
	if _is_main_opening(edge):
		var main_edge: Dictionary = main_entrance["edge"]
		var coordinate := int(edge["x"]) if String(edge["axis"]) == "H" else int(edge["y"])
		var main_coordinate := int(main_edge["x"]) if String(edge["axis"]) == "H" else int(main_edge["y"])
		if coordinate == main_coordinate:
			edge_states[key] = &"DOOR"
			door_edges[key] = main_entrance["door_edge"]
		else:
			edge_states[key] = &"DOOR_OPENING"
			door_opening_edges[key] = main_entrance["door_edge"]
		return
	edge_states[key] = &"WALL"
	wall_edges[key] = edge


func _is_main_opening(edge: Dictionary) -> bool:
	if main_entrance.is_empty() or not main_entrance.has("edge"):
		return false
	var main_edge: Dictionary = main_entrance["edge"]
	if String(edge["axis"]) != String(main_edge["axis"]):
		return false
	if String(edge["axis"]) == "H" and int(edge["y"]) != int(main_edge["y"]):
		return false
	if String(edge["axis"]) == "V" and int(edge["x"]) != int(main_edge["x"]):
		return false
	var coordinate := int(edge["x"]) if String(edge["axis"]) == "H" else int(edge["y"])
	var main_coordinate := int(main_edge["x"]) if String(edge["axis"]) == "H" else int(main_edge["y"])
	var opening_coordinates: Array = main_entrance.get("opening_coordinates", [main_coordinate])
	return coordinate in opening_coordinates


func _choose_boss_room_by_floor_distance() -> void:
	var distances := _floor_distances(spawn_cell, true)
	boss_distances.clear()
	var best_distance := -1.0
	var best_room := -1
	for room_id in range(rooms.size()):
		if room_id == spawn_room_id:
			continue
		var rect: Rect2i = rooms[room_id]["grid_rect"]
		var center: Vector2i = rooms[room_id]["center_cell"]
		if rect.size.x < boss_min_width or rect.size.y < boss_min_height or not distances.has(center):
			continue
		var distance := float(distances[center])
		boss_distances[room_id] = distance
		if distance > best_distance:
			best_distance = distance
			best_room = room_id
	if best_room < 0:
		for room_id in range(rooms.size()):
			if room_id == spawn_room_id:
				continue
			var center_fallback: Vector2i = rooms[room_id]["center_cell"]
			if not distances.has(center_fallback):
				continue
			var fallback_distance := float(distances[center_fallback])
			boss_distances[room_id] = fallback_distance
			if fallback_distance > best_distance:
				best_distance = fallback_distance
				best_room = room_id
	boss_room_id = best_room
	if boss_room_id >= 0:
		rooms[boss_room_id]["room_type"] = &"boss"


func _floor_distances(start: Vector2i, ignore_boss_lock: bool = true) -> Dictionary:
	var flood_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("floor_flood_fill_calls")
	var distances: Dictionary = {}
	if not floor_cells.has(start):
		_startup_profile_record_time("floor_flood_fill_ms", flood_started_usec)
		_startup_profile_increment("floor_flood_fill_failures")
		return distances
	distances[start] = 0
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = distances[current]
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not floor_cells.has(neighbor) or distances.has(neighbor) or not _can_cross_floor_edge(current, neighbor, ignore_boss_lock):
				continue
			distances[neighbor] = current_distance + 1
			queue.append(neighbor)
	_startup_profile_record_time("floor_flood_fill_ms", flood_started_usec)
	_startup_profile_increment("floor_flood_fill_successes")
	return distances


func _is_boss_door_edge_key(key: String) -> bool:
	if boss_door_id < 0:
		return false
	if door_edges.has(key):
		return int(door_edges[key].get("door_id", -1)) == boss_door_id
	if door_opening_edges.has(key):
		var opening: Dictionary = door_opening_edges[key]
		if int(opening.get("door_id", -1)) == boss_door_id:
			return true
	# The corridor and current four-cell doorway share the same throat.  At the
	# open Room-B threshold, any remaining boundary segment must still be part of
	# the locked Boss barrier so a cell beside the double-door opening cannot
	# bypass the lock.  Only edges whose two sides are exactly Boss-room floor and
	# this connection's corridor are included.
	var key_parts := key.split(":")
	if key_parts.size() == 3 and key_parts[0] in ["H", "V"]:
		var parsed_edge := {"axis": key_parts[0], "x": int(key_parts[1]), "y": int(key_parts[2])}
		var sides := _edge_side_cells(parsed_edge)
		if sides.size() == 2:
			var side_a_room := int(room_cells.get(sides[0], -1))
			var side_b_room := int(room_cells.get(sides[1], -1))
			var boss_corridor_pair := (
				(side_a_room == boss_room_id and corridor_cells.has(sides[1]))
				or (side_b_room == boss_room_id and corridor_cells.has(sides[0]))
			)
			if boss_corridor_pair:
				return true
	# A macro Room→Corridor connection has one logical double-door at the authored
	# room threshold and an intentionally open threshold at the other side.  The
	# open side is valid for ordinary travel, but a locked Boss connection must
	# block both thresholds in the gameplay pathfinder; otherwise the player can
	# enter from the Boss side and bypass the lock without touching the leaves.
	# Keep this derived from authored door sockets so no broad corridor rectangle
	# is accidentally locked.
	for connection_variant in connections:
		var connection: Dictionary = connection_variant
		if int(connection.get("door_id", -1)) != boss_door_id:
			continue
		var opening_cells := maxi(1, int(connection.get("door_a", {}).get("opening_cells", DOOR_OPENING_CELLS)))
		for side_key in ["door_a", "door_b"]:
			var side: Dictionary = connection.get(side_key, {})
			if side.is_empty():
				continue
			var inside: Vector2i = side.get("inside_cell", Vector2i.ZERO)
			var outward: Vector2i = side.get("outward", Vector2i.ZERO)
			var tangent := Vector2i(0, 1) if outward.x != 0 else Vector2i(1, 0)
			for offset in range(opening_cells):
				if _edge_key(_edge_from_cell_direction(inside + tangent * offset, outward)) == key:
					return true
	return false


func _choose_key_and_boss_rooms() -> void:
	# Compatibility hook retained for older diagnostics.  Random3D no longer has
	# a key room, Boss room, or locked Boss door; every non-start node is normal
	# content and floor progression is handled by the Elevator/Badege chain.
	for room in rooms:
		var r_type := StringName(room.get("room_type", &""))
		if r_type in [&"elevator_lobby", &"corridor", &"reception", &"main_lobby", &"large_office", &"small_office"]:
			continue
		room["room_type"] = &"start" if int(room.get("id", -1)) == spawn_room_id else &"normal"
	key_room_id = -1
	boss_room_id = -1
	boss_door_id = -1
	boss_door_edge_key = ""
	boss_distances.clear()
	key_distances.clear()
	start_to_boss_blocked_before_key = false


func _choose_elevator_anchor() -> bool:
	"""Choose a deterministic, reachable top-center floor cell for the lift.

	The logical floor map is the only authority here.  The visual/collision wall
	opening is derived from the selected cell later, so a camera transform or a
	room-local random position can never place the elevator outside the building.
	"""
	elevator_anchor_cell = Vector2i.ZERO
	elevator_room_id = -1
	elevator_edge_key = ""
	if floor_cells.is_empty() or spawn_room_id < 0 or not floor_cells.has(spawn_cell):
		return false
	if _is_otxo_mansion():
		for room in rooms:
			if StringName(room.get("room_type", &"")) == &"elevator_lobby":
				elevator_room_id = int(room.get("id", -1))
				elevator_anchor_cell = spawn_cell
				elevator_edge_key = ""
				if floor_cells.has(elevator_anchor_cell):
					return true
	var top_row := 2147483647
	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		if pit_cells.has(cell) or pillar_cells.has(cell):
			continue
		top_row = mini(top_row, cell.y)
	if top_row == 2147483647:
		return false
	var center_x := building_rect.position.x + int(round(float(building_rect.size.x) * 0.5))
	var max_radius := maxi(building_rect.size.x, building_rect.size.y)
	var reachable := _floor_distances(spawn_cell, true)
	for radius in range(max_radius + 1):
		var offsets: Array[int] = []
		if radius == 0:
			offsets.append(0)
		else:
			offsets.append(-radius)
			offsets.append(radius)
		for offset in offsets:
			var candidate := Vector2i(center_x + offset, top_row)
			if (
				not floor_cells.has(candidate)
				or pit_cells.has(candidate)
				or pillar_cells.has(candidate)
				or not reachable.has(candidate)
			):
				continue
			var room_id := int(room_cells.get(candidate, -1))
			if room_id < 0:
				continue
			var edge := _edge_from_cell_direction(candidate, Vector2i.UP)
			var edge_key := _edge_key(edge)
			# Only an authored solid exterior wall may be opened.  Never replace a
			# door, glass partition, or already-open edge with the elevator anchor.
			if StringName(edge_states.get(edge_key, &"")) != &"WALL" or not wall_edges.has(edge_key):
				continue
			elevator_anchor_cell = candidate
			elevator_room_id = room_id
			elevator_edge_key = edge_key
			# Remove exactly the selected outer wall segment from both visual and
			# physics builders.  The logical floor remains unchanged.
			wall_edges.erase(edge_key)
			edge_states[edge_key] = &"OPEN"
			return true
	return false


func _validate_layout() -> Dictionary:
	var floor_report := _validate_floor_connectivity()
	var graph_connected := _room_graph_is_connected()
	# Floor progression requires at least one real Employee that can carry the
	# badge. Derive this from the same deterministic encounter rules used later,
	# without consuming any layout or content RNG stream.
	var badge_candidate_valid := _has_badge_carrier_candidate()
	var all_sizes_valid := true
	for room in rooms:
		var rect: Rect2i = room["grid_rect"]
		if rect.size.x < min_room_width or rect.size.y < min_room_height:
			all_sizes_valid = false
			break
	# Boss/Key role validation is intentionally retired for Random3D.  The room
	# graph still validates its real topology; the Elevator anchor is the sole
	# floor progression gate and is checked after obstacle generation.
	var boss_valid := boss_room_id < 0
	var key_valid := key_room_id < 0
	var door_sides_valid := _validate_door_sides()
	var edge_state_valid := _validate_edge_states()
	var door_topology := _validate_door_topology()
	var corridor_opening_report := _validate_corridor_openings()
	var has_branch := false
	for room in rooms:
		if _get_room_degree(int(room["id"])) >= 3:
			has_branch = true
			break
	var start_spawn_valid := spawn_room_id >= 0 and floor_cells.has(spawn_cell) and (_is_otxo_mansion() or bool(main_entrance.get("sealed", false)))
	var valid: bool
	if _is_otxo_mansion():
		valid = building_rect.size.x >= 18 and building_rect.size.y >= 14 and rooms.size() >= 8 and graph_connected and bool(floor_report["all_floor_reachable"]) and bool(floor_report["all_room_centers_reachable"]) and start_spawn_valid and boss_valid and key_valid and badge_candidate_valid
	else:
		valid = building_rect.size.x >= min_building_width and building_rect.size.y >= min_building_height and rooms.size() == room_count and all_sizes_valid and graph_connected and bool(floor_report["all_floor_reachable"]) and bool(floor_report["all_room_centers_reachable"]) and door_sides_valid and edge_state_valid and bool(door_topology["valid"]) and bool(corridor_opening_report["valid"]) and start_spawn_valid and boss_valid and key_valid and badge_candidate_valid
	return {
		"valid": valid,
		"building_rect": building_rect,
		"building_width": building_rect.size.x,
		"building_height": building_rect.size.y,
		"wall_height": wall_height,
		"wall_thickness": wall_thickness,
		"door_width": door_width,
		"door_height": door_height,
		"dynamic_wall_height": false,
		"room_count": rooms.size(),
		"partition_count": partitions.size(),
		"max_partition_depth": max_partition_depth,
		"connection_count": connections.size(),
		"loop_count": connections.size() - maxi(0, rooms.size() - 1),
		"corridor_count": corridors.size(),
		"corridor_cell_count": corridor_cells.size(),
		"has_branch": has_branch,
		"graph_connected": graph_connected,
		"all_floor_reachable": floor_report["all_floor_reachable"],
		"all_room_centers_reachable": floor_report["all_room_centers_reachable"],
		"reachable_floor_count": floor_report["reachable_floor_count"],
		"floor_count": floor_cells.size(),
		"pit_count": pit_cells.size(),
		"internal_wall_count": internal_wall_edges.size(),
		"door_sides_valid": door_sides_valid,
		"edge_state_valid": edge_state_valid,
		"door_topology_valid": door_topology["valid"],
		"corridor_opening_valid": corridor_opening_report["valid"],
		"corridor_opening_violations": corridor_opening_report["violations"],
		"door_count": door_topology["door_count"],
		"internal_door_count": door_topology["internal_door_count"],
		"main_door_count": door_topology["main_door_count"],
		"duplicate_door_ids": door_topology["duplicate_door_ids"],
		"shared_door_violations": door_topology["shared_door_violations"],
		"multi_region_doors": door_topology["multi_region_doors"],
		"duplicate_region_pairs": door_topology["duplicate_region_pairs"],
		"invalid_door_boundary_lengths": door_topology["invalid_boundary_lengths"],
		"invalid_door_hinges": door_topology["invalid_hinges"],
		"door_swing_clearance_failures": door_topology["swing_clearance_failures"],
		"missing_door_side_floor": door_topology["missing_side_floor"],
		"door_corner_clearance_failures": door_topology["corner_clearance_failures"],
		"door_to_door_clearance_failures": door_topology["door_to_door_clearance_failures"],
		"main_entrance_valid": start_spawn_valid,
		"elevator_candidate_valid": elevator_room_id >= 0 and floor_cells.has(elevator_anchor_cell),
		"elevator_room_id": elevator_room_id,
		"elevator_anchor_cell": elevator_anchor_cell,
		"badge_candidate_valid": badge_candidate_valid,
		"start_outer_wall_sealed": start_spawn_valid and int(door_topology["main_door_count"]) == 0,
		"main_entrance": main_entrance.duplicate(true),
		"spawn_room_id": spawn_room_id,
		"spawn_cell": spawn_cell,
		"key_room_id": key_room_id,
		"key_distances": key_distances.duplicate(true),
		"key_valid": key_valid,
		"boss_room_id": boss_room_id,
		"boss_distance": boss_distances.get(boss_room_id, -1.0),
		"boss_door_id": boss_door_id,
		"boss_entry_count": _get_room_degree(boss_room_id),
		"boss_single_entry": _get_room_degree(boss_room_id) == 1,
		"boss_valid": boss_valid,
	}


func _validate_door_sides() -> bool:
	for connection in connections:
		var door_a: Dictionary = connection["door_a"]
		var door_b: Dictionary = connection["door_b"]
		if not floor_cells.has(door_a["inside_cell"]) or not floor_cells.has(door_b["inside_cell"]):
			return false
	return true


func _validate_edge_states() -> bool:
	# Every boundary segment has exactly one logical state.  OPEN segments and
	# the extra cells covered by a widened door intentionally have neither a
	# wall nor an additional Door node.
	for key_variant in edge_states.keys():
		var key: String = key_variant
		var state: String = String(edge_states[key])
		var has_wall := wall_edges.has(key)
		var has_door := door_edges.has(key)
		if state == "OPEN" and (has_wall or has_door):
			return false
		if state == "WALL" and (not has_wall or has_door):
			return false
		if state == "DOOR" and (has_wall or not has_door):
			return false
		if state == "DOOR_OPENING" and (has_wall or has_door or not door_opening_edges.has(key)):
			return false
	return not edge_states.is_empty()


func _validate_door_topology() -> Dictionary:
	var duplicate_door_ids := 0
	var shared_door_violations := 0
	var multi_region_doors := 0
	var duplicate_region_pairs := 0
	var invalid_boundary_lengths := 0
	var invalid_hinges := 0
	var swing_clearance_failures := 0
	var missing_side_floor := 0
	var corner_clearance_failures := 0
	var door_to_door_clearance_failures := 0
	var invalid_full_opening_side_floor := 0
	var invalid_opening_region_pair := 0
	var door_on_actual_junction := 0
	var door_overlapping_wall := 0
	var internal_door_count := 0
	var main_door_count := 0
	var seen_door_ids: Dictionary = {}
	var seen_connection_ids: Dictionary = {}
	var seen_region_pairs: Dictionary = {}
	var seen_edge_keys: Dictionary = {}
	for key_variant in door_edges.keys():
		var key: String = key_variant
		var edge: Dictionary = door_edges[key]
		var door_id := int(edge.get("door_id", -1))
		if door_id < 0 or seen_door_ids.has(door_id):
			duplicate_door_ids += 1
		else:
			seen_door_ids[door_id] = key
		var kind := String(edge.get("kind", "internal"))
		var region_a := int(edge.get("region_a_id", -1))
		var region_b := int(edge.get("region_b_id", -1))
		if seen_edge_keys.has(key):
			shared_door_violations += 1
		seen_edge_keys[key] = true
		var hinge := String(edge.get("hinge_side", ""))
		if hinge != "left" and hinge != "right":
			invalid_hinges += 1
		var boundary_length := int(edge.get("shared_boundary_length", 0))
		if boundary_length < minimum_door_boundary_length:
			invalid_boundary_lengths += 1
		if not edge.has("wall_edge") or not edge.has("door_position"):
			shared_door_violations += 1
		if not _door_swing_clearance_valid(edge):
			swing_clearance_failures += 1
		if kind == "main":
			main_door_count += 1
			if region_a < 0 or region_b != -1:
				multi_region_doors += 1
		else:
			internal_door_count += 1
			if region_a < 0 or region_b < 0 or region_a == region_b or region_a >= rooms.size() or region_b >= rooms.size():
				multi_region_doors += 1
			else:
				var region_pair := "%d:%d" % [mini(region_a, region_b), maxi(region_a, region_b)]
				if seen_region_pairs.has(region_pair):
					duplicate_region_pairs += 1
				seen_region_pairs[region_pair] = true
			var connection_id := int(edge.get("connection_id", -1))
			if connection_id < 0 or connection_id >= connections.size():
				shared_door_violations += 1
			else:
				if seen_connection_ids.has(connection_id):
					shared_door_violations += 1
				seen_connection_ids[connection_id] = true
				var connection: Dictionary = connections[connection_id]
				if int(connection.get("door_id", -1)) != door_id or int(connection.get("a", -1)) != region_a or int(connection.get("b", -1)) != region_b:
					shared_door_violations += 1
		var side_cells := _edge_side_cells(edge)
		if kind == "main":
			var main_inside: Vector2i = main_entrance.get("inside_cell", Vector2i.ZERO)
			if not floor_cells.has(main_inside):
				missing_side_floor += 1
		else:
			if side_cells.size() < 2 or not floor_cells.has(side_cells[0]) or not floor_cells.has(side_cells[1]):
				missing_side_floor += 1
			if kind == "room_corridor":
				# Macro graph doors intentionally sit at a Room -> Corridor
				# threshold, so the historical BSP partition audit does not apply.
				# The macro generator has already checked the slot against the
				# room boundary and corner clearance; validate that contract here.
				if not bool(edge.get("corner_clearance_valid", false)):
					corner_clearance_failures += 1
			else:
				var partition := _partition_for_id(int(edge.get("partition_id", -1)))
				if partition.is_empty() or not _door_clearance_without_existing_doors(partition, edge):
					corner_clearance_failures += 1
			# Authoritative full-opening audit：完全从当前 room_cells / floor_cells /
			# wall_edges 重算，不信任 door metadata，也不复用 candidate 函数。
			# （历史缺陷：generator 与 validator 共用同一带边界缺陷的公式，坏门
			# 同时骗过两者——354/1000 seeds validator blind。）
			var audit_axis := String(edge["door_direction"])
			var audit_cut := int(edge["x"]) if audit_axis == "V" else int(edge["y"])
			var audit_opening_cells := maxi(1, int(edge.get("opening_cells", DOOR_OPENING_CELLS)))
			for opening_offset in range(audit_opening_cells):
				var opening_coordinate := int(edge.get("opening_start", -1)) + opening_offset
				var opening_key := "%s:%d:%d" % [audit_axis, audit_cut, opening_coordinate]
				if wall_edges.has(opening_key):
					door_overlapping_wall += 1
				var opening_edge: Dictionary
				if audit_axis == "V":
					opening_edge = {"axis": "V", "x": audit_cut, "y": opening_coordinate}
				else:
					opening_edge = {"axis": "H", "x": opening_coordinate, "y": audit_cut}
				var opening_sides := _edge_side_cells(opening_edge)
				if opening_sides.size() < 2 or not floor_cells.has(opening_sides[0]) or not floor_cells.has(opening_sides[1]):
					invalid_full_opening_side_floor += 1
					continue
				var actual_a := int(room_cells.get(opening_sides[0], -1))
				var actual_b := int(room_cells.get(opening_sides[1], -1))
				if kind == "room_corridor":
					var boundary_room_id := int(edge.get("boundary_room_id", region_a))
					var room_side_ok := actual_a == boundary_room_id or actual_b == boundary_room_id
					var corridor_side_ok := corridor_cells.has(opening_sides[0]) or corridor_cells.has(opening_sides[1])
					if not room_side_ok or not corridor_side_ok:
						invalid_opening_region_pair += 1
				else:
					if actual_a != region_a or actual_b != region_b:
						invalid_opening_region_pair += 1
					# BSP doors must not sit at an actual T/cross junction.
					var perpendicular_axis := "H" if audit_axis == "V" else "V"
					for side_cell in opening_sides:
						var junction_key := "%s:%d:%d" % [
							perpendicular_axis,
							int(side_cell.x) if perpendicular_axis == "H" else int(side_cell.y),
							int(side_cell.y) if perpendicular_axis == "H" else int(side_cell.x),
						]
						if wall_edges.has(junction_key):
							door_on_actual_junction += 1
	# Every internal connection must have exactly one registered Door.  The
	# dictionary key enforces physical-edge uniqueness; this catches metadata
	# or connection references that bypass that invariant.
	if seen_connection_ids.size() != connections.size():
		shared_door_violations += connections.size() - seen_connection_ids.size()
	if main_door_count != 0:
		shared_door_violations += 1
	var door_values: Array[Dictionary] = []
	for edge_variant in door_edges.values():
		door_values.append(edge_variant)
	for first_index in range(door_values.size()):
		var first: Dictionary = door_values[first_index]
		for second_index in range(first_index + 1, door_values.size()):
			var second: Dictionary = door_values[second_index]
			if String(first.get("axis", "")) != String(second.get("axis", "")):
				continue
			if String(first.get("axis", "")) == "V" and int(first.get("x", 0)) != int(second.get("x", 0)):
				continue
			if String(first.get("axis", "")) == "H" and int(first.get("y", 0)) != int(second.get("y", 0)):
				continue
			var first_coordinate := int(first.get("y", 0)) if String(first.get("axis", "")) == "V" else int(first.get("x", 0))
			var second_coordinate := int(second.get("y", 0)) if String(second.get("axis", "")) == "V" else int(second.get("x", 0))
			if absi(first_coordinate - second_coordinate) < door_to_door_clearance:
				door_to_door_clearance_failures += 1
	var valid := duplicate_door_ids == 0 and shared_door_violations == 0 and multi_region_doors == 0 and duplicate_region_pairs == 0 and invalid_boundary_lengths == 0 and invalid_hinges == 0 and swing_clearance_failures == 0 and missing_side_floor == 0 and corner_clearance_failures == 0 and door_to_door_clearance_failures == 0 and invalid_full_opening_side_floor == 0 and invalid_opening_region_pair == 0 and door_on_actual_junction == 0 and door_overlapping_wall == 0
	return {
		"valid": valid,
		"door_count": door_edges.size(),
		"internal_door_count": internal_door_count,
		"main_door_count": main_door_count,
		"duplicate_door_ids": duplicate_door_ids,
		"shared_door_violations": shared_door_violations,
		"multi_region_doors": multi_region_doors,
		"duplicate_region_pairs": duplicate_region_pairs,
		"invalid_boundary_lengths": invalid_boundary_lengths,
		"invalid_hinges": invalid_hinges,
		"swing_clearance_failures": swing_clearance_failures,
		"missing_side_floor": missing_side_floor,
		"corner_clearance_failures": corner_clearance_failures,
		"door_to_door_clearance_failures": door_to_door_clearance_failures,
		"invalid_full_opening_side_floor": invalid_full_opening_side_floor,
		"invalid_opening_region_pair": invalid_opening_region_pair,
		"door_on_actual_junction": door_on_actual_junction,
		"door_overlapping_wall": door_overlapping_wall,
	}


func _validate_corridor_openings() -> Dictionary:
	## Corridor connections are the only doors whose width follows the corridor
	## cross-section.  Ordinary/Boss/legacy BSP doors keep DOOR_OPENING_CELLS;
	## this audit therefore skips connections without an authored corridor id.
	var violations: int = 0
	var expected_corridor_width: int = maxi(2, corridor_width)
	var expected_opening_cells: int = DEFAULT_ROOM_DOOR_OPENING_CELLS
	var expected_shoulder_cells: int = maxi(0, int((expected_corridor_width - expected_opening_cells) / 2))
	for corridor_variant in corridors:
		var corridor: Dictionary = corridor_variant
		var corridor_id := int(corridor.get("id", -1))
		var width_cells: int = maxi(1, int(corridor.get("width_cells", corridor.get("width", corridor_width))))
		if width_cells != expected_corridor_width:
			violations += 1
		if String(corridor.get("kind", "")) != "straight":
			violations += 1
		var corridor_direction: Vector2i = corridor.get("direction", Vector2i.ZERO)
		if not _corridor_cells_form_straight_band(corridor.get("cells", []), corridor_direction, width_cells):
			violations += 1
		for connection_variant in connections:
			var connection: Dictionary = connection_variant
			if int(connection.get("corridor_id", -1)) != corridor_id:
				continue
			if int(connection.get("corridor_width_cells", width_cells)) != expected_corridor_width:
				violations += 1
			if int(connection.get("door_throat_width_cells", expected_opening_cells)) != expected_opening_cells:
				violations += 1
			for side_key in [&"door_a", &"door_b"]:
				var door_data: Dictionary = connection.get(side_key, {})
				if int(door_data.get("opening_cells", expected_opening_cells)) != expected_opening_cells:
					violations += 1
				if int(door_data.get("corridor_width_cells", expected_corridor_width)) != expected_corridor_width:
					violations += 1
				if int(door_data.get("shoulder_cells_each_side", expected_shoulder_cells)) != expected_shoulder_cells:
					violations += 1
				if not _corridor_profile_valid(door_data, expected_opening_cells):
					violations += 1
	for edge_variant in door_edges.values():
		var edge: Dictionary = edge_variant
		if String(edge.get("kind", "")) != "room_corridor":
			continue
		var corridor_id := int(edge.get("corridor_id", -1))
		if corridor_id < 0 or corridor_id >= corridors.size():
			violations += 1
			continue
		var corridor: Dictionary = corridors[corridor_id]
		var width_cells: int = maxi(1, int(corridor.get("width_cells", corridor.get("width", corridor_width))))
		if width_cells != expected_corridor_width:
			violations += 1
		if int(edge.get("opening_cells", expected_opening_cells)) != expected_opening_cells:
			violations += 1
		var opening_start := int(edge.get("opening_start", 0))
		var opening_end := int(edge.get("opening_end", 0))
		if not edge.has("opening_start") or not edge.has("opening_end") or opening_end != opening_start + expected_opening_cells:
			violations += 1
		if int(edge.get("corridor_width_cells", expected_corridor_width)) != expected_corridor_width:
			violations += 1
		if int(edge.get("shoulder_cells_each_side", expected_shoulder_cells)) != expected_shoulder_cells:
			violations += 1
		if not _corridor_profile_valid(edge, expected_opening_cells):
			violations += 1
	return {
		"valid": violations == 0,
		"violations": violations,
	}


func _corridor_cells_form_straight_band(cells_variant: Variant, direction: Vector2i, width_cells: int) -> bool:
	if not cells_variant is Array or cells_variant.is_empty() or width_cells < 1:
		return false
	if direction.x == 0 and direction.y == 0:
		return false
	if direction.x != 0 and direction.y != 0:
		return false
	var cells: Array = cells_variant
	var tangent_values: Dictionary = {}
	var normal_values: Dictionary = {}
	var min_tangent := 2147483647
	var max_tangent := -2147483647
	var min_normal := 2147483647
	var max_normal := -2147483647
	for cell_variant in cells:
		if not cell_variant is Vector2i:
			return false
		var cell: Vector2i = cell_variant
		var tangent := cell.y if direction.x != 0 else cell.x
		var normal := cell.x if direction.x != 0 else cell.y
		tangent_values[tangent] = true
		normal_values[normal] = true
		min_tangent = mini(min_tangent, tangent)
		max_tangent = maxi(max_tangent, tangent)
		min_normal = mini(min_normal, normal)
		max_normal = maxi(max_normal, normal)
	if max_tangent - min_tangent + 1 != width_cells:
		return false
	for tangent in range(min_tangent, max_tangent + 1):
		if not tangent_values.has(tangent):
			return false
	for normal in range(min_normal, max_normal + 1):
		if not normal_values.has(normal):
			return false
		for tangent in range(min_tangent, max_tangent + 1):
			var expected := Vector2i(normal, tangent) if direction.x != 0 else Vector2i(tangent, normal)
			if not cells.has(expected):
				return false
	return cells.size() == (max_normal - min_normal + 1) * width_cells


func _corridor_profile_valid(data: Dictionary, expected_width: int) -> bool:
	var opening_variant: Variant = data.get("opening_profile", [])
	var terminal_variant: Variant = data.get("terminal_profile", [])
	var normal_variant: Variant = data.get("opening_normal", Vector2i.ZERO)
	var tangent_variant: Variant = data.get("opening_tangent", Vector2i.ZERO)
	if not opening_variant is Array or not terminal_variant is Array:
		return false
	if not normal_variant is Vector2i or not tangent_variant is Vector2i:
		return false
	var opening: Array = opening_variant
	var terminal: Array = terminal_variant
	var normal: Vector2i = normal_variant
	var tangent: Vector2i = tangent_variant
	if opening.size() != expected_width or terminal.size() != expected_width:
		return false
	if normal == Vector2i.ZERO or tangent != _tangent_vector_for_opening(normal):
		return false
	if data.has("opening_start_cell") and opening[0] != data.get("opening_start_cell"):
		return false
	if data.has("opening_end_cell") and opening[opening.size() - 1] != data.get("opening_end_cell"):
		return false
	for index in range(expected_width):
		var opening_cell_variant: Variant = opening[index]
		var terminal_cell_variant: Variant = terminal[index]
		if not opening_cell_variant is Vector2i or not terminal_cell_variant is Vector2i:
			return false
		var opening_cell: Vector2i = opening_cell_variant
		var terminal_cell: Vector2i = terminal_cell_variant
		if terminal_cell != opening_cell + normal:
			return false
		if index > 0:
			var previous_variant: Variant = opening[index - 1]
			if not previous_variant is Vector2i:
				return false
			var previous_cell: Vector2i = previous_variant
			if opening_cell != previous_cell + tangent:
				return false
		if not corridor_cells.has(terminal_cell):
			return false
	return true


func _tangent_vector_for_opening(normal: Vector2i) -> Vector2i:
	return Vector2i(0, 1) if normal.x != 0 else Vector2i(1, 0)


func _partition_for_id(partition_id: int) -> Dictionary:
	for partition in partitions:
		if int(partition.get("id", -1)) == partition_id:
			return partition
	return {}


func _edge_side_cells(edge: Dictionary) -> Array[Vector2i]:
	if String(edge.get("axis", "")) == "H":
		return [Vector2i(int(edge.get("x", 0)), int(edge.get("y", 0)) - 1), Vector2i(int(edge.get("x", 0)), int(edge.get("y", 0)))]
	return [Vector2i(int(edge.get("x", 0)) - 1, int(edge.get("y", 0))), Vector2i(int(edge.get("x", 0)), int(edge.get("y", 0)))]


func _door_clearance_without_existing_doors(partition: Dictionary, edge: Dictionary) -> bool:
	var coordinate := int(edge["y"]) if String(edge["axis"]) == "V" else int(edge["x"])
	var start: int = partition["span_start"]
	var end: int = partition["span_end"]
	var opening_cells := int(edge.get("opening_cells", DOOR_OPENING_CELLS))
	for opening_offset in range(opening_cells):
		var opening_coordinate := coordinate + opening_offset
		if opening_coordinate - start < door_corner_clearance or end - 1 - opening_coordinate < door_corner_clearance:
			return false
		for other in partitions:
			if int(other["id"]) == int(partition["id"]) or String(other["axis"]) == String(partition["axis"]):
				continue
			var junction_coordinate := INVALID_DOOR_COORDINATE
			if String(partition["axis"]) == "V":
				var crossing_y: int = other["cut"]
				if crossing_y >= start and crossing_y < end and int(partition["cut"]) >= int(other["span_start"]) and int(partition["cut"]) <= int(other["span_end"]):
					junction_coordinate = crossing_y
			else:
				var crossing_x: int = other["cut"]
				if crossing_x >= start and crossing_x < end and int(partition["cut"]) >= int(other["span_start"]) and int(partition["cut"]) <= int(other["span_end"]):
					junction_coordinate = crossing_x
			if junction_coordinate != INVALID_DOOR_COORDINATE and absi(opening_coordinate - junction_coordinate) < door_corner_clearance:
				return false
	return true


func _door_swing_clearance_valid(edge: Dictionary) -> bool:
	# The physical leaf can only swing into a real floor side.  The topology
	# validator already rejects corner/T-junction candidates; this final check
	# keeps both sides of the hinge opening populated before a Door is built.
	if String(edge.get("kind", "")) == "main":
		return floor_cells.has(main_entrance.get("inside_cell", Vector2i.ZERO))
	var side_cells := _edge_side_cells(edge)
	return side_cells.size() == 2 and floor_cells.has(side_cells[0]) and floor_cells.has(side_cells[1])


func _room_graph_is_connected() -> bool:
	if rooms.is_empty():
		return false
	var visited: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor_variant in rooms[current]["connections"]:
			var neighbor: int = neighbor_variant
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return visited.size() == rooms.size()


func _validate_floor_connectivity() -> Dictionary:
	var floor_validation_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("floor_connectivity_validation_calls")
	if spawn_room_id < 0 or not floor_cells.has(spawn_cell):
		_startup_profile_record_time("floor_connectivity_validation_ms", floor_validation_started_usec)
		_startup_profile_increment("floor_connectivity_validation_failures")
		return {"all_floor_reachable": false, "all_room_centers_reachable": false, "reachable_floor_count": 0}
	var visited := _floor_distances(spawn_cell)
	var centers_reachable := true
	for room in rooms:
		if not visited.has(room["center_cell"]):
			centers_reachable = false
			break
	_startup_profile_record_time("floor_connectivity_validation_ms", floor_validation_started_usec)
	_startup_profile_increment("floor_connectivity_validation_successes")
	return {"all_floor_reachable": visited.size() == floor_cells.size(), "all_room_centers_reachable": centers_reachable, "reachable_floor_count": visited.size()}


func _get_room_degree(room_id: int) -> int:
	if room_id < 0 or room_id >= rooms.size():
		return 0
	return rooms[room_id]["connections"].size()


func _add_room_connection(room_id: int, other_room_id: int) -> void:
	var links: Array = rooms[room_id]["connections"]
	if not links.has(other_room_id):
		links.append(other_room_id)
	rooms[room_id]["connections"] = links


func _room_center_manhattan(room_a: int, room_b: int) -> int:
	var center_a: Vector2i = rooms[room_a]["center_cell"]
	var center_b: Vector2i = rooms[room_b]["center_cell"]
	return abs(center_a.x - center_b.x) + abs(center_a.y - center_b.y)


func _get_rooms_within_hops(start_room_id: int, max_hops: int = 2) -> Dictionary:
	var result := {}
	if start_room_id < 0 or start_room_id >= rooms.size():
		return result
	result[start_room_id] = 0
	var queue: Array[int] = [start_room_id]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		var cur_dist: int = int(result[cur])
		if cur_dist >= max_hops:
			continue
		for neighbor_variant in rooms[cur].get("connections", []):
			var neighbor: int = neighbor_variant
			if not result.has(neighbor):
				result[neighbor] = cur_dist + 1
				queue.append(neighbor)
	return result


func _can_cross_floor_edge(from_cell: Vector2i, to_cell: Vector2i, ignore_boss_lock: bool = true) -> bool:
	var direction := to_cell - from_cell
	if direction not in CARDINAL_DIRECTIONS:
		return false
	var edge_key := _edge_key(_edge_from_cell_direction(from_cell, direction))
	if wall_edges.has(edge_key):
		return false
	# Random3D no longer has a locked Boss doorway.  Keep the argument for old
	# path-query callers, but every generated floor edge is traversable unless a
	# real wall occupies it.
	return true


func _clear_generated_building() -> void:
	preload("res://scripts/dream/floor_reflections.gd").uninstall(self)
	elevator_prompt_active = false
	if is_instance_valid(interaction_prompt):
		interaction_prompt.dismiss(true)
	_settled_blood_buckets.clear()
	_owned_corpse_blood_emitters.clear()
	_owned_black_blood_stains.clear()
	if is_instance_valid(shadow_manager):
		shadow_manager.clear_floor()
	_layout_generation += 1
	for projectile in gameplay_world.get_children():
		if projectile.is_in_group(&"dream_projectiles"):
			projectile.free()
	room_ambient_spawn_pending.clear()
	if room_visibility != null and is_instance_valid(room_visibility) and room_visibility.has_method("clear_layout"):
		room_visibility.call("clear_layout")
	# Transition visuals live below generated_root rather than one of the gameplay
	# roots.  Free them explicitly so a regenerate cannot leave old gradients or
	# deferred trigger callbacks attached to the next layout.
	if transition_root != null and is_instance_valid(transition_root):
		transition_root.free()
	transition_root = null
	camera_impulse_offset = Vector3.ZERO
	camera_shake_amplitude = 0.0
	camera_shake_elapsed = 0.0
	camera_shake_duration = 0.0
	damage_totals.clear()
	pending_enemy_pickup_requests.clear()
	_pickup_request_serial = 0
	door_transit_registry.clear()
	_door_transit_serial = 0
	_open_connected_rooms_cache.clear()
	_open_boundary_edges_cache.clear()
	for record in native_damage_number_anchors:
		var holder := record.get("holder") as Node2D
		if holder != null and is_instance_valid(holder):
			holder.queue_free()
	native_damage_number_anchors.clear()
	_set_building_exterior_vertical_offset(0.0)
	for root in [office_art_root, floor_root, wall_root, door_root, debug_root, wake_exit_root, ceiling_light_root, collision_root, furniture_root, enemy_root, key_root, world_weapon_root, pickup_root, ground_debris_root, world_effects_root, actor_depth_bridges_root, actor_physics_proxies_root]:
		if root == null:
			continue
		for child in root.get_children():
			child.free()
	_occlusion_bounds_cache.clear()
	_static_cutout_walls.clear()
	_static_cutout_wall_positions.clear()
	_static_cutout_wall_bins.clear()
	_static_cutout_wall_edges.clear()
	_static_cutout_wall_heights.clear()
	_static_cutout_wall_meshes.clear()
	_static_cutout_door_candidates.clear()
	_last_door_root_child_count = -1
	_cached_furniture_bridges.clear()
	_last_bridges_child_count = -1
	_last_furniture_art_child_count = -1
	_last_furniture_2d_child_count = -1
	_cutout_furniture_meshes.clear()
	_cutout_furniture_mesh_centers.clear()
	_cutout_furniture_mesh_bins.clear()
	_cutout_furniture_meshes_dirty = true
	_cutout_furniture_meshes_frame = -1
	_active_firearm_impact_count = 0
	_cached_damageable_props.clear()
	_cached_damageable_props_frame = -1
	_cached_dream_enemies.clear()
	_cached_dream_enemies_frame = -1
	_cached_enemy_cutout_slots.clear()
	_cached_enemy_cutout_dists.clear()
	_cutout_work_slots.clear()
	_cutout_work_dists.clear()
	_cutout_furniture_screen_rects.clear()
	_cutout_furniture_screen_rect_frame = -1
	_last_cutout_viewport_size = Vector2.ZERO
	_last_cutout_slots.clear()
	transition_root = null
	transition_trigger_root = null
	transition_stub_floor_cells.clear()
	transition_stubs.clear()
	transition_stub_wall_keys.clear()
	current_room_id = -1
	transition_in_progress = false
	transition_commit_pending = false
	transition_guard_until_msec = 0
	transition_guard_connection_id = -1
	if player != null and is_instance_valid(player):
		_cache_actor_occlusion_bounds(player)
	if pit_root != null and is_instance_valid(pit_root):
		pit_root.free()
	pit_root = null
	if ceiling_light_root != null and ceiling_light_root.has_method("clear_lights"):
		ceiling_light_root.call("clear_lights")
	key_pickup = null
	boss_door_node = null
	floor_badge_pickup = null
	badge_marker = null
	badge_drop_committed = false
	badge_drop_pending = false
	elevator_trigger = null
	elevator_visual = null
	elevator_floor_door = null
	elevator_state = &"LOCKED"
	floor_transition_in_progress = false
	furniture_count = 0
	enemy_count = 0
	enemy_population_refill_left = 0.0
	enemy_population_breathing_left.clear()


func _build_floor() -> void:
	# Floor Visual Batching（Phase 2A）：逐格 FloorTile 表现改为按相位分组的
	# MultiMesh；floor_cells 等逻辑数据不变，外观（UV 相位/材质/光照）逐格一致。
	preload("res://scripts/dream/dream_3d_floor_batch_renderer.gd").build(self)
	for room in rooms:
		if not bool(room.get("authored_sample", false)):
			var fixtures: Node3D = preload("res://scripts/dream/office_random_room_decor.gd").build(room, _get_room_doors(int(room.id)), wall_edges, wall_thickness, edge_states, enhanced_room_dressing)
			floor_root.add_child(fixtures)
			continue
		if lazy_room_presentation and int(room.id) != current_room_id:
			continue
		var low_pixel = preload("res://scripts/dream/office_low_pixel_art.gd")
		var detail_art = low_pixel if String(room.sample_key) == "office" and low_pixel.enabled else preload("res://scripts/dream/office_detail_art.gd")
		var details: MeshInstance3D = detail_art.room_decorations(OFFICE_SAMPLE_SCRIPT.decoration_specs(String(room.sample_key)), Vector2(room.grid_rect.position))
		if details != null:
			details.name = "AuthoredOfficeDecorations_%d" % int(room.id)
			details.set_meta(&"dream_room_id", int(room.id))
			floor_root.add_child(details)
		var room_art = preload("res://scripts/dream/office_room_low_pixel_art.gd")
		if String(room.sample_key) != "office" and room_art.enabled:
			var fixtures: Node3D = room_art.room_fixtures(String(room.sample_key), Vector2(room.grid_rect.position))
			if fixtures != null:
				fixtures.set_meta(&"dream_room_id", int(room.id))
				floor_root.add_child(fixtures)


func _clear_active_room_presentation() -> void:
	"""Free static presentation for the previous room before loading another.

	The gameplay graph and long-lived actor nodes remain in memory.  Only the
	room-local floor/wall/door/light/pit/trigger meshes are rebuilt, keeping the
	initial scene and every room transition bounded by one room's geometry.
	"""
	for root in [floor_root, wall_root, door_root, debug_root, collision_root]:
		if root == null:
			continue
		for child in root.get_children():
			child.free()
	if pit_root != null and is_instance_valid(pit_root):
		pit_root.free()
	pit_root = null
	if transition_root != null and is_instance_valid(transition_root):
		transition_root.free()
	transition_root = null
	transition_trigger_root = null
	transition_stub_wall_keys.clear()
	boss_door_node = null


func _refresh_active_presentation_cells() -> void:
	"""Select only the current room and its outgoing stub floor cells."""
	presentation_floor_cells.clear()
	transition_stub_floor_cells.clear()
	if current_room_id < 0:
		return
	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		if int(room_cells.get(cell, -1)) == current_room_id and not corridor_cells.has(cell):
			presentation_floor_cells[cell] = floor_cells[cell]
	for stub_variant in transition_stubs:
		if not stub_variant is Dictionary:
			continue
		var stub: Dictionary = stub_variant
		if int(stub.get("source_room_id", -1)) != current_room_id:
			continue
		for cell_variant in stub.get("stub_cells", []):
			if not cell_variant is Vector2i:
				continue
			var cell: Vector2i = cell_variant
			transition_stub_floor_cells[cell] = &"transition_stub"
			presentation_floor_cells[cell] = &"transition_stub"


func _ensure_presentation_room_layout_plans() -> void:
	if not _is_otxo_mansion():
		if not lazy_room_presentation:
			for r_idx in range(rooms.size()):
				if not room_layout_plans.has(r_idx):
					_plan_otxo_room_layout(r_idx)
		elif current_room_id >= 0 and not room_layout_plans.has(current_room_id):
			_plan_otxo_room_layout(current_room_id)
		return
	if not lazy_room_presentation:
		for r_idx in range(rooms.size()):
			if not room_layout_plans.has(r_idx):
				_plan_otxo_room_layout(r_idx)
	elif current_room_id >= 0:
		var pres_rooms := _get_rooms_within_hops(current_room_id, 2)
		for r_id in pres_rooms.keys():
			var r_int := int(r_id)
			if not room_layout_plans.has(r_int):
				_plan_otxo_room_layout(r_int)


func _rebuild_active_room_presentation() -> void:
	"""Build the bounded visual/collision slice for current_room_id."""
	_ensure_presentation_room_layout_plans()
	if not lazy_room_presentation:
		# Full-map presentation already owns every room. A transition must not
		# append another identical floor/wall/window-light set: overlapping sets
		# exhaust the receiver light budget and hide new local fixtures. Layout
		# regeneration clears these roots before reaching this builder again.
		# Keep existing door state and wall visibility references intact as well.
		if floor_root.get_child_count() > 0:
			return
		# `_prepare_transition_stub_metadata()` also fills the lazy presentation
		# dictionaries for the active-room path.  Clear them here so opting out of
		# lazy presentation really restores the historical full-map builders.
		presentation_floor_cells.clear()
		transition_stub_floor_cells.clear()
		var non_lazy_phase_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_floor()
		_startup_profile_record_time("presentation_floor_ms", non_lazy_phase_started_usec)
		non_lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_pit_visuals()
		_startup_profile_record_time("presentation_pit_ms", non_lazy_phase_started_usec)
		non_lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_walls()
		_startup_profile_record_time("presentation_walls_ms", non_lazy_phase_started_usec)
		non_lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_doors()
		_startup_profile_record_time("presentation_doors_ms", non_lazy_phase_started_usec)
		non_lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_transition_stub_visuals()
		_startup_profile_record_time("presentation_stubs_ms", non_lazy_phase_started_usec)
		non_lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_ceiling_lights()
		_startup_profile_record_time("presentation_lights_ms", non_lazy_phase_started_usec)
		if show_debug_markers:
			non_lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
			_build_debug_markers()
			_startup_profile_record_time("presentation_debug_markers_ms", non_lazy_phase_started_usec)
		return
	_clear_active_room_presentation()
	_refresh_active_presentation_cells()
	var lazy_phase_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_floor()
	_startup_profile_record_time("presentation_floor_ms", lazy_phase_started_usec)
	lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_pit_visuals()
	_startup_profile_record_time("presentation_pit_ms", lazy_phase_started_usec)
	lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_walls()
	_startup_profile_record_time("presentation_walls_ms", lazy_phase_started_usec)
	lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_doors()
	_startup_profile_record_time("presentation_doors_ms", lazy_phase_started_usec)
	lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_transition_stub_visuals()
	_startup_profile_record_time("presentation_stubs_ms", lazy_phase_started_usec)
	lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_ceiling_lights()
	_startup_profile_record_time("presentation_lights_ms", lazy_phase_started_usec)
	if show_debug_markers:
		lazy_phase_started_usec = _startup_profile_clock_usec() if _startup_profile_enabled else 0
		_build_debug_markers()
		_startup_profile_record_time("presentation_debug_markers_ms", lazy_phase_started_usec)
	_validate_rendered_edge_nodes()
	if room_visibility != null and is_instance_valid(room_visibility) and room_visibility.has_method("refresh_active_presentation"):
		room_visibility.call("refresh_active_presentation")


func _prepare_transition_stub_metadata() -> void:
	"""Derive two independent presentation stubs from each graph connection.

	The graph's corridor cells remain logical metadata for deterministic room
	selection and legacy path diagnostics.  They are not used as the rendered
	continuous floor.  Each side gets a short straight profile and an endpoint
	trigger; the two room presentations therefore remain separate until the
	explicit transition commits.
	"""
	presentation_floor_cells.clear()
	transition_stub_floor_cells.clear()
	transition_stubs.clear()
	transition_stub_wall_keys.clear()
	for corridor_variant in corridors:
		var corridor: Dictionary = corridor_variant
		var corridor_id := int(corridor.get("id", -1))
		var connection := _connection_between_rooms(int(corridor.get("room_a", -1)), int(corridor.get("room_b", -1)))
		if corridor_id < 0 or connection.is_empty():
			continue
		var direction: Vector2i = corridor.get("direction", Vector2i.ZERO)
		var span_cells := _corridor_span_cells(corridor, direction)
		# Leave at least one empty logical cell between the two endpoint regions
		# whenever the authored gap permits it. Very tight gaps still receive a
		# one-cell stub and rely on the explicit transition trigger.
		var max_stub_length := maxi(1, int(floor(float(maxi(span_cells - 1, 1)) * 0.5)))
		var stub_length := mini(TRANSITION_STUB_LENGTH_CELLS, max_stub_length)
		var presentation_cells: Array[Vector2i] = []
		for side_key in [&"a", &"b"]:
			var door_key := &"door_a" if side_key == &"a" else &"door_b"
			var door_data: Dictionary = connection.get(door_key, {})
			var source_room := int(connection.get("a", -1)) if side_key == &"a" else int(connection.get("b", -1))
			var target_room := int(connection.get("b", -1)) if side_key == &"a" else int(connection.get("a", -1))
			var profile: Array = door_data.get("opening_profile", [])
			var outward: Vector2i = door_data.get("outward", Vector2i.ZERO)
			if profile.is_empty() or outward == Vector2i.ZERO:
				continue
			var stub_cells: Array[Vector2i] = []
			for step in range(1, stub_length + 1):
				var step_blocked := false
				var step_cells: Array[Vector2i] = []
				for profile_cell_variant in profile:
					var profile_cell: Vector2i = profile_cell_variant
					var candidate := profile_cell + outward * step
					# A target room/foreign room is a hard endpoint. Do not paint a
					# stub through its structural membership.
					if room_cells.has(candidate) and int(room_cells.get(candidate, -1)) != source_room:
						step_blocked = true
						break
					if room_cells.has(candidate):
						continue
					if not step_cells.has(candidate):
						step_cells.append(candidate)
				if step_blocked:
					break
				for candidate in step_cells:
					stub_cells.append(candidate)
					if not presentation_cells.has(candidate):
						presentation_cells.append(candidate)
					transition_stub_floor_cells[candidate] = &"transition_stub"
			var profile_center := _profile_center_gameplay(profile)
			# `stub_cells.size()` is width * depth and must not be used as a world
			# distance. Put the trigger near the dark endpoint of the finite stub,
			# leaving a small margin before its open presentation endpoint.
			var trigger_depth := maxf(float(stub_length) - 0.55, 0.35)
			var trigger_position := profile_center + Vector2(outward) * trigger_depth
			transition_stubs.append({
				"connection_id": int(connection.get("id", -1)),
				"corridor_id": corridor_id,
				"source_room_id": source_room,
				"target_room_id": target_room,
				"door_id": int(connection.get("door_id", -1)),
				"profile": profile.duplicate(),
				"outward": outward,
				"stub_cells": stub_cells,
				"stub_length_cells": stub_length,
				"trigger_position": trigger_position * CELL_PIXELS,
				"side": side_key,
			})
		corridor["presentation_cells"] = presentation_cells
		corridor["stub_length_cells"] = stub_length
	_refresh_active_presentation_cells()


func _corridor_span_cells(corridor: Dictionary, direction: Vector2i) -> int:
	var cells: Array = corridor.get("cells", [])
	if cells.is_empty() or direction == Vector2i.ZERO:
		return 1
	var min_normal := 2147483647
	var max_normal := -2147483647
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		var normal := cell.x if direction.x != 0 else cell.y
		min_normal = mini(min_normal, normal)
		max_normal = maxi(max_normal, normal)
	return maxi(1, max_normal - min_normal + 1)


func _profile_center_gameplay(profile: Array) -> Vector2:
	if profile.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	var count := 0
	for cell_variant in profile:
		if not cell_variant is Vector2i:
			continue
		total += Vector2(cell_variant)
		count += 1
	return total / float(maxi(count, 1))


func _build_transition_stub_visuals() -> void:
	if generated_root == null or collision_root == null:
		return
	transition_root = Node3D.new()
	transition_root.name = "RoomTransitionStubs"
	generated_root.add_child(transition_root)
	transition_trigger_root = Node2D.new()
	transition_trigger_root.name = "RoomTransitionTriggers"
	collision_root.add_child(transition_trigger_root)
	var cell_world_size := _cell_world_size()
	for index in range(transition_stubs.size()):
		var stub: Dictionary = transition_stubs[index]
		if lazy_room_presentation and int(stub.get("source_room_id", -1)) != current_room_id:
			continue
		var outward: Vector2i = stub.get("outward", Vector2i.ZERO)
		var profile: Array = stub.get("profile", [])
		var stub_length := maxi(1, int(stub.get("stub_length_cells", 1)))
		var profile_center := _profile_center_gameplay(profile)
		var center_gameplay := profile_center + Vector2(outward) * float(stub_length) * 0.5
		var gradient := MeshInstance3D.new()
		gradient.name = "TransitionGradient_%d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2(float(profile.size()) * cell_world_size, float(stub_length) * cell_world_size)
		gradient.mesh = plane
		gradient.position = _map_gameplay_to_world(center_gameplay * CELL_PIXELS)
		gradient.position.y = 0.045
		gradient.rotation.y = atan2(float(outward.x), float(outward.y))
		gradient.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gradient.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var gradient_material := ShaderMaterial.new()
		gradient_material.shader = TRANSITION_GRADIENT_SHADER
		gradient_material.set_shader_parameter("black_color", Color(0.0, 0.0, 0.0, 1.0))
		gradient.material_override = gradient_material
		gradient.set_meta(&"room_transition_gradient", true)
		gradient.set_meta(&"connection_id", int(stub.get("connection_id", -1)))
		gradient.set_meta(&"source_room_id", int(stub.get("source_room_id", -1)))
		gradient.set_meta(&"target_room_id", int(stub.get("target_room_id", -1)))
		transition_root.add_child(gradient)
		_build_transition_stub_boundary_walls(stub, index)

		var trigger := Area2D.new()
		trigger.name = "TransitionTrigger_%d" % index
		trigger.position = stub.get("trigger_position", Vector2.ZERO)
		trigger.rotation = Vector2(outward).angle()
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		trigger.monitoring = false
		trigger.monitorable = false
		for key in [&"connection_id", &"corridor_id", &"source_room_id", &"target_room_id", &"door_id", &"side"]:
			trigger.set_meta(key, stub.get(key, -1))
		trigger.set_meta(&"transition_trigger", true)
		var trigger_shape := CollisionShape2D.new()
		var trigger_rect := RectangleShape2D.new()
		trigger_rect.size = Vector2(
			TRANSITION_TRIGGER_DEPTH_CELLS * CELL_PIXELS,
			maxf(float(profile.size() * CELL_PIXELS - 4), 8.0)
		)
		trigger_shape.shape = trigger_rect
		trigger.add_child(trigger_shape)
		transition_trigger_root.add_child(trigger)
		trigger.body_entered.connect(_on_room_transition_body_entered.bind(trigger))

	_set_transition_runtime_active()


func _build_transition_stub_boundary_walls(stub: Dictionary, stub_index: int) -> void:
	"""Build the side walls for one finite presentation stub.

	The logical corridor remains in the graph, but its old continuous wall run is
	not rendered. These derived side edges keep the stub sides bounded while its
	endpoint stays open for the explicit transition trigger. They are
	presentation/collision edges only; the original 2D room topology is untouched.
	"""
	if wall_root == null or collision_root == null:
		return
	var stub_cells: Array = stub.get("stub_cells", [])
	if stub_cells.is_empty():
		return
	var stub_set: Dictionary = {}
	for cell_variant in stub_cells:
		if cell_variant is Vector2i:
			stub_set[cell_variant] = true
	var outward: Vector2i = stub.get("outward", Vector2i.ZERO)
	var connection_id := int(stub.get("connection_id", -1))
	var side := String(stub.get("side", ""))
	var local_edges: Dictionary = {}
	for cell_variant in stub_cells:
		if not cell_variant is Vector2i:
			continue
		var cell: Vector2i = cell_variant
		for direction in CARDINAL_DIRECTIONS:
			var neighbor := cell + direction
			if stub_set.has(neighbor):
				continue
			# The room-facing opening and the outward endpoint are deliberately open.
			# Side edges remain bounded, while the trigger owns the room transition.
			if direction == outward:
				continue
			if room_cells.has(neighbor) and int(room_cells.get(neighbor, -1)) == int(stub.get("source_room_id", -1)):
				continue
			var edge: Dictionary = wall_edges.get(_edge_key(_edge_from_cell_direction(cell, direction)), _edge_from_cell_direction(cell, direction)) as Dictionary
			var edge_key := _edge_key(edge)
			if edge_key.is_empty() or door_edges.has(edge_key) or door_opening_edges.has(edge_key) or local_edges.has(edge_key) or transition_stub_wall_keys.has(edge_key):
				continue
			local_edges[edge_key] = edge
	for edge_key_variant in local_edges.keys():
		var edge_key: String = edge_key_variant
		var edge: Dictionary = local_edges[edge_key]
		transition_stub_wall_keys[edge_key] = true
		var wall := WALL_SCENE.instantiate() as Node3D
		if wall == null:
			continue
		wall.name = "TransitionWall_%d_%s_%s" % [connection_id, side, edge_key.replace(":", "_")]
		wall.position = _edge_world_position(edge)
		if String(edge.get("axis", "")) == "V":
			wall.rotation.y = PI * 0.5
		wall.set_meta(&"edge", edge.duplicate(true))
		wall.set_meta(&"edge_key", edge_key)
		wall.set_meta(&"transition_stub_wall", true)
		wall.set_meta(&"connection_id", connection_id)
		wall.set_meta(&"source_room_id", int(stub.get("source_room_id", -1)))
		wall.set_meta(&"target_room_id", int(stub.get("target_room_id", -1)))
		wall.call("configure_wall", wall_height, wall_thickness)
		wall_root.add_child(wall)
		_build_wall_collision(edge, edge_key)


func _set_transition_runtime_active() -> void:
	# Presentation gradients follow the same source-room authority as the
	# triggers.  Hidden destination stubs therefore cannot float over a fogged
	# room while the player is still on the other side of the connection.
	if transition_root != null and is_instance_valid(transition_root):
		for visual in transition_root.get_children():
			if not visual.has_meta(&"room_transition_gradient"):
				continue
			var visual_source_room := int(visual.get_meta(&"source_room_id", -1))
			visual.visible = visual_source_room == current_room_id and not transition_in_progress
	if transition_trigger_root == null:
		return
	var now_msec := Time.get_ticks_msec()
	for child in transition_trigger_root.get_children():
		var trigger := child as Area2D
		if trigger == null or not trigger.has_meta(&"transition_trigger"):
			continue
		var source_room := int(trigger.get_meta(&"source_room_id", -1))
		var door_id := int(trigger.get_meta(&"door_id", -1))
		var active := source_room == current_room_id and not transition_in_progress
		if door_id == boss_door_id and is_boss_door_locked():
			active = false
		trigger.set_deferred("monitoring", active)
		trigger.set_deferred("monitorable", active)


func _on_room_transition_body_entered(body: Node, trigger: Area2D) -> void:
	if body != player or trigger == null or not is_instance_valid(trigger):
		return
	if transition_in_progress or Time.get_ticks_msec() < transition_guard_until_msec:
		return
	var source_room := int(trigger.get_meta(&"source_room_id", -1))
	var target_room := int(trigger.get_meta(&"target_room_id", -1))
	var connection_id := int(trigger.get_meta(&"connection_id", -1))
	if source_room != current_room_id:
		return
	if transition_commit_pending:
		return
	# Do not rebuild/free physics-backed presentation from inside the Area2D
	# callback.  The callback runs while Godot is flushing queries; defer the
	# entire logical commit so walls, doors, triggers and debris are changed only
	# after the physics step has finished.
	transition_commit_pending = true
	call_deferred("_commit_room_transition_deferred", source_room, target_room, connection_id, _layout_generation)


func _commit_room_transition_deferred(source_room: int, target_room: int, connection_id: int, generation_token: int) -> void:
	transition_commit_pending = false
	if generation_token != _layout_generation:
		return
	_commit_room_transition(source_room, target_room, connection_id)


func _find_room_transition_entry(connection: Dictionary, target_room: int) -> Vector2:
	var target_door := _connection_door_for_room(connection, target_room)
	if target_door.is_empty():
		return Vector2.INF
	var inside: Vector2i = target_door.get("inside_cell", Vector2i.ZERO)
	var outward: Vector2i = target_door.get("outward", Vector2i.ZERO)
	if outward == Vector2i.ZERO:
		return Vector2.INF
	var tangent: Vector2i = target_door.get("opening_tangent", Vector2i.ZERO)
	if tangent == Vector2i.ZERO:
		tangent = Vector2i(0, 1) if outward.x != 0 else Vector2i(1, 0)
	var profile: Array = target_door.get("opening_profile", [])
	var candidates: Array[Vector2i] = []
	for depth in range(2, 7):
		for tangent_offset in range(-1, 2):
			var candidate := inside - outward * depth + tangent * tangent_offset
			if (
				floor_cells.has(candidate)
				and int(room_cells.get(candidate, -1)) == target_room
				and not pit_cells.has(candidate)
				and not pillar_cells.has(candidate)
			):
				if profile.is_empty() or profile.has(inside + tangent * tangent_offset) or tangent_offset == 0:
					candidates.append(candidate)
	if candidates.is_empty():
		return Vector2.INF
	return get_player_root_position_for_cell(candidates[0])


func _clear_room_transition_transients() -> void:
	# Projectiles and short combat effects have no durable room snapshot. End
	# them at the commit boundary so an attack from A cannot affect room B.
	for node in get_tree().get_nodes_in_group(&"dream_projectiles"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group(&"dream_transient_effects"):
		if is_instance_valid(node):
			node.queue_free()


func _commit_room_transition(source_room: int, target_room: int, connection_id: int) -> bool:
	if (
		transition_in_progress
		or source_room != current_room_id
		or target_room < 0
		or target_room >= rooms.size()
		or connection_id < 0
	):
		return false
	var connection := _connection_between_rooms(source_room, target_room)
	if connection.is_empty() or int(connection.get("id", -1)) != connection_id:
		return false
	if int(connection.get("door_id", -1)) == boss_door_id and is_boss_door_locked():
		return false
	var target_position := _find_room_transition_entry(connection, target_room)
	if not target_position.is_finite():
		return false
	transition_in_progress = true
	transition_guard_connection_id = connection_id
	transition_guard_until_msec = Time.get_ticks_msec() + 120
	var previous_movement_enabled := true
	var previous_attacking_enabled := true
	if player != null and is_instance_valid(player):
		previous_movement_enabled = bool(player.get("movement_enabled"))
		previous_attacking_enabled = bool(player.get("attacking_enabled"))
		# A room transition is a hard gameplay-position boundary.  Stop any
		# in-flight Dash/Aim before writing the target-room entry so the next
		# physics frame cannot continue applying the old room's cached path.
		if player.has_method("cancel_dash"):
			player.call("cancel_dash")
		player.set("movement_enabled", false)
		player.set("velocity", Vector2.ZERO)
		if player.has_method("set_attacking_enabled"):
			player.call("set_attacking_enabled", false)
		player.set("global_position", target_position)
		player.set_meta(&"dream_room_id", target_room)
		last_safe_floor_position = target_position
	_clear_room_transition_transients()
	set_current_room_id(target_room)
	# Swap the bounded presentation slice only after the logical room commit. The
	# old room's static meshes/colliders are freed; long-lived gameplay actors keep
	# their state behind the room runtime gate.
	_rebuild_active_room_presentation()
	# Explicit graph activation is the only cross-room lifecycle authority.  It
	# reveals the target room, starts its encounter once, and keeps the minimap and
	# fog state on the same connection metadata as the trigger.
	activate_room(target_room)
	# A transition is a hard camera boundary, not a long world-space pan.
	camera_aim_offset = Vector3.ZERO
	camera_impulse_offset = Vector3.ZERO
	camera_shake_amplitude = 0.0
	camera_shake_elapsed = 0.0
	camera_shake_duration = 0.0
	_update_camera_and_actor_projection(0.0)
	call_deferred("_finish_room_transition", previous_movement_enabled, previous_attacking_enabled)
	return true


func _finish_room_transition(previous_movement_enabled: bool, previous_attacking_enabled: bool) -> void:
	if player != null and is_instance_valid(player):
		player.set("movement_enabled", previous_movement_enabled)
		if player.has_method("set_attacking_enabled"):
			player.call("set_attacking_enabled", previous_attacking_enabled)
	transition_in_progress = false
	_set_transition_runtime_active()
	_set_elevator_runtime_active()


func set_current_room_id(room_id: int) -> void:
	if room_id < 0 or room_id >= rooms.size():
		return
	current_room_id = room_id
	_set_active_presentation_room(room_id)
	if room_visibility != null and is_instance_valid(room_visibility) and room_visibility.has_method("set_current_presentation_room"):
		room_visibility.call("set_current_presentation_room", room_id, -1)
	_set_elevator_runtime_active()


func _set_active_presentation_room(active_room_id: int) -> void:
	for room_variant in rooms:
		var room_id := int((room_variant as Dictionary).get("id", -1))
		if room_id >= 0:
			_set_room_content_active(room_id, true)
	_set_transition_runtime_active()
	_set_elevator_runtime_active()


func _build_ceiling_lights() -> void:
	if ceiling_light_root != null and ceiling_light_root.has_method("build_for_world") and ceiling_light_root.get_child_count() == 0:
		ceiling_light_root.set("managed_shadows", dynamic_shadows_enabled)
		ceiling_light_root.call("build_for_world", self)
		if is_instance_valid(shadow_manager):
			shadow_manager.rebuild_floor()


func _edge_in_active_presentation(edge: Dictionary) -> bool:
	if not lazy_room_presentation or current_room_id < 0:
		return true
	if edge.is_empty():
		return false
	var side_cells := _edge_side_cells(edge)
	for cell_variant in side_cells:
		if not cell_variant is Vector2i:
			continue
		var cell: Vector2i = cell_variant
		if int(room_cells.get(cell, -1)) == current_room_id:
			return true
		if transition_stub_floor_cells.has(cell):
			return true
	return false


func _on_settings_changed(setting_name: StringName, value: Variant) -> void:
	if setting_name == &"shadow_quality" and is_instance_valid(shadow_manager):
		shadow_manager.set_quality(String(value))


func _build_walls() -> void:
	window_wall_edges = _select_window_wall_edges()
	for key_variant in wall_edges.keys():
		var key: String = key_variant
		if door_opening_edges.has(key):
			continue
		var edge: Dictionary = wall_edges[key]
		if not _edge_in_active_presentation(edge):
			continue
		if _is_interior_open_office_edge(edge):
			continue
		if _edge_touches_elevator(edge) and not _has_elevator_reception():
			# Keep the actual wall plane beside the sliding-door opening. The
			# elevator-room edges elsewhere remain visually absent, so this does
			# not recreate an in-floor elevator cab.
			if _edge_on_elevator_door_wall(edge):
				_build_wall_visual(edge, key)
			_build_wall_collision(edge, key)
			continue
		# Corridor cells remain logical graph data, but their old continuous
		# boundary is not a physical presentation wall in the transition layout.
		# Boss/door edges are still handled by _build_doors().
		if use_authored_office_sample and _edge_touches_corridor(edge) and not door_edges.has(key):
			continue
		if glass_wall_edges.has(key) or edge_states.get(key) == &"GLASS_WINDOW":
			_build_glass_window(edge, key)
			continue
		_build_wall_visual(edge, key)
		_build_wall_collision(edge, key)
	# A pillar cap belongs to the complete footprint, not to each perimeter
	# edge.  Building it after the wall loop guarantees one cap per pillar and
	# avoids overlapping duplicate meshes/Z-fighting.
	_build_pillar_top_caps()


func _build_glass_window(edge: Dictionary, key: String) -> void:
	var glass_window: Node3D = BREAKABLE_GLASS_WINDOW_SCRIPT.new()
	glass_window.name = "Wall_%s" % key.replace(":", "_")
	glass_window.position = _edge_world_position(edge)
	glass_window.set_meta(&"edge", edge.duplicate(true))
	wall_root.add_child(glass_window)
	glass_window.call("configure_window", edge, key, wall_height, wall_thickness, collision_root)
	if glass_window.has_signal("window_shattered"):
		glass_window.connect("window_shattered", Callable(self, "_on_glass_window_shattered"))


func _on_glass_window_shattered(window: Node3D) -> void:
	if window == null or not is_instance_valid(window):
		return
	var edge_data: Dictionary = window.get("edge_data") if window.get("edge_data") != null else {}
	var edge_key: String = String(window.get("edge_key"))
	if edge_data.is_empty():
		return
	wall_edges.erase(edge_key)
	glass_wall_edges.erase(edge_key)
	edge_states[edge_key] = &"OPEN"
	if internal_wall_edges.has(edge_key):
		internal_wall_edges.erase(edge_key)
	var window_gameplay_pos := Vector2(window.position.x, window.position.z) * CELL_PIXELS
	var side_cells := _edge_side_cells(edge_data)
	if side_cells.size() == 2:
		var room_a := int(room_cells.get(side_cells[0], -1))
		var room_b := int(room_cells.get(side_cells[1], -1))
		if room_visibility != null and is_instance_valid(room_visibility) and room_visibility.has_method("reveal_room"):
			if room_a >= 0 and room_a == current_room_id and room_b >= 0:
				room_visibility.call("reveal_room", room_b)
			elif room_b >= 0 and room_b == current_room_id and room_a >= 0:
				room_visibility.call("reveal_room", room_a)
		if room_a >= 0 and room_a == current_room_id and room_b >= 0:
			wake_room_enemies(room_b, window_gameplay_pos)
		elif room_b >= 0 and room_b == current_room_id and room_a >= 0:
			wake_room_enemies(room_a, window_gameplay_pos)
	notify_gunshot(window_gameplay_pos)


func wake_room_enemies(room_id: int, alert_pos: Vector2 = Vector2.ZERO) -> void:
	if room_id < 0 or room_id >= rooms.size():
		return
	if enemy_root != null:
		for child in enemy_root.get_children():
			if int(child.get_meta(&"dream_room_id", -1)) != room_id:
				continue
			if child is EmployeeEnemy:
				child.call("set_room_runtime_active", true)
				child.set("hostile", true)
				if child.get("state") != null:
					child.set("state", 1) # State.ALERT
				if alert_pos != Vector2.ZERO and child.has_method("on_room_gunshot"):
					child.call("on_room_gunshot", alert_pos, room_id)
	if actor_depth_bridges_root != null:
		for bridge_variant in actor_depth_bridges_root.get_children():
			var bridge := bridge_variant as Node
			if bridge != null and int(bridge.get_meta(&"dream_room_id", -1)) == room_id:
				if bridge.has_method("set_room_presentation_active"):
					bridge.call("set_room_presentation_active", true)


## Procedural pillars are explicit footprints.  Keep this helper as the single
## cap-facing view of that data; never infer a pillar by scanning wall edges.
func _find_closed_pillar_footprints() -> Array:
	var footprints: Array = []
	for footprint_variant in pillar_footprints:
		if not footprint_variant is Array or footprint_variant.is_empty():
			continue
		var footprint: Array[Vector2i] = []
		for cell_variant in footprint_variant:
			if cell_variant is Vector2i:
				footprint.append(cell_variant)
		if footprint.size() != footprint_variant.size() or footprint.size() != 1:
			continue
		var cell: Vector2i = footprint[0]
		if lazy_room_presentation and int(room_cells.get(cell, -1)) != current_room_id:
			continue
		if floor_cells.has(cell) or not pillar_cells.has(cell):
			continue
		var complete := true
		for direction in CARDINAL_DIRECTIONS:
			if not internal_wall_edges.has(_edge_key(_edge_from_cell_direction(cell, direction))):
				complete = false
				break
		if complete:
			footprints.append(footprint)
	return footprints


func _build_pillar_top_caps() -> void:
	if wall_root == null or pillar_footprints.is_empty():
		return
	var footprints := _find_closed_pillar_footprints()
	if footprints.is_empty():
		return
	var cell_size := _cell_world_size()
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color.BLACK
	cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	for footprint_index in range(footprints.size()):
		var footprint: Array = footprints[footprint_index]
		var min_cell: Vector2i = footprint[0]
		var max_cell: Vector2i = footprint[0]
		for cell in footprint:
			min_cell.x = mini(min_cell.x, cell.x)
			min_cell.y = mini(min_cell.y, cell.y)
			max_cell.x = maxi(max_cell.x, cell.x)
			max_cell.y = maxi(max_cell.y, cell.y)
		var footprint_size := Vector2i(max_cell.x - min_cell.x + 1, max_cell.y - min_cell.y + 1)
		# Floor cells are centred at their integer grid coordinate.  Using
		# `size * 0.5` here shifts a 1x1 cap by half a cell; subtract one before
		# taking the half extent so the cap is centred on the actual footprint.
		var center_cells := Vector2(min_cell) + Vector2(
			float(footprint_size.x - 1),
			float(footprint_size.y - 1)
		) * 0.5
		var center_world := _map_gameplay_to_world(center_cells * CELL_PIXELS)
		var cap := MeshInstance3D.new()
		cap.name = "PillarTopCap_%d" % footprint_index
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(
			float(footprint_size.x) * cell_size,
			0.02,
			float(footprint_size.y) * cell_size
		)
		cap.mesh = cap_mesh
		cap.material_override = cap_material
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cap.position = Vector3(center_world.x, wall_height + 0.01, center_world.z)
		cap.set_meta(&"pillar_top_cap", true)
		wall_root.add_child(cap)


func _build_doors() -> void:
	# The authored floor's open corridor links have no architectural door.
	# Decorative jambs left isolated posts in the open-office sightline.
	for key_variant in door_edges.keys():
		var key: String = key_variant
		var edge: Dictionary = door_edges[key]
		if not _edge_in_active_presentation(edge):
			continue
		var is_boss := int(edge.get("door_id", -1)) == boss_door_id
		# In classic macro corridor mode, ordinary entries are openings without doors.
		# In OTXO mansion mode, all suite doorways have physical breakable doors!
		if not _is_otxo_mansion() and not is_boss:
			continue
		if bool(edge.get("is_elevator_sliding_door", false)) or String(edge.get("door_style", "")) == "open":
			continue
		var door := DOOR_SCENE.instantiate() as PhysicalDoor3D
		door.name = "Door_%s" % key.replace(":", "_")
		door.position = _door_root_world_position(edge)
		if String(edge["axis"]) == "V":
			door.rotation.y = PI * 0.5
		door.set_meta(&"connection_id", edge.get("connection_id", -1))
		door.set_meta(&"door_id", edge.get("door_id", -1))
		door.set_meta(&"region_a_id", edge.get("region_a_id", -1))
		door.set_meta(&"region_b_id", edge.get("region_b_id", -1))
		door.set_meta(&"partition_id", edge.get("partition_id", -1))
		door.set_meta(&"kind", edge.get("kind", &"internal"))
		door.set_meta(&"door_edge", edge.duplicate(true))
		door.set_meta(&"door_direction", edge.get("door_direction", edge.get("axis", "")))
		door.set_meta(&"hinge_side", edge.get("hinge_side", "left"))
		door.set_meta(&"wall_edge", edge.duplicate(true))
		var door_tint := Color(.72, .64, .53)
		for room_key in ["region_a_id", "region_b_id"]:
			var material_room_id := int(edge.get(room_key, -1))
			if material_room_id >= 0 and material_room_id < rooms.size() and String(rooms[material_room_id].get("archetype", "")) in ["server", "archive", "storage"]:
				door_tint = Color(.49, .54, .57)
			if material_room_id >= 0 and material_room_id < rooms.size() and String(rooms[material_room_id].get("office_visual_style", "")) == "approved_office":
				door.set_meta(&"office_pixel_sample", true)
		door.set_meta(&"surface_tint", door_tint)
		if enhanced_room_dressing and not use_authored_office_sample:
			door.set_meta(&"office_metal_door",true)
			door.set_meta(&"surface_tint",Color(.49,.58,.62))
			for room_key in ["region_a_id","region_b_id"]:
				var room_id := int(edge.get(room_key,-1))
				if room_id>=0 and room_id<rooms.size() and String(rooms[room_id].get("archetype","")) in ["manager","executive","small_office","conference","conference_large","meeting_small"]:
					door.set_meta(&"office_observation_window",true)
		# Door leaf height is independent of the structural wall above it.
		var effective_door_height := door_height
		var effective_door_width := _door_width_for_edge(edge)
		door.set_meta(&"opening_world_width", effective_door_width)
		door.configure(effective_door_width, effective_door_height, wall_thickness * 0.5, edge.get("hinge_side", "left"), int(edge.get("door_id", -1)), StringName(edge.get("door_style", "double")))
		door.is_boss_door = is_boss
		door_root.add_child(door)
		# Open above the leaf: no architectural lintel over room doors.
		door.configure_gameplay_collision(collision_root, CELL_PIXELS, WORLD_WALL_LAYER)
		if is_boss:
			boss_door_node = door
			var boss_locked := not has_boss_key
			door.set_meta(&"boss_locked", boss_locked)
			door.set_locked(boss_locked)
		else:
			door.set_locked(false)
			door.door_shattered.connect(_on_physical_door_shattered.bind(edge, key))


func _build_office_pixel_opening_frames() -> void:
	# Retained for older scene comparisons, but not part of the live authored
	# floor: an open link has neither a leaf nor a freestanding post.
	if not use_authored_office_sample or not preload("res://scripts/dream/office_low_pixel_art.gd").enabled:
		return
	var built: Dictionary = {}
	var candidates: Array = door_edges.values() + door_opening_edges.values()
	for edge: Dictionary in candidates:
		if not _edge_in_active_presentation(edge) or String(edge.get("door_style", "")) != "open":
			continue
		# Opening fragments may omit room IDs, so also use the actual adjacent
		# floor cells. No decorative jamb may reappear at an open-office entry.
		var office := _is_interior_open_office_edge(edge)
		for room_key in ["region_a_id", "region_b_id"]:
			var room_id := int(edge.get(room_key, -1))
			if room_id >= 0 and room_id < rooms.size() and String(rooms[room_id].get("sample_key", "")) == "office":
				office = true
		var identity := int(edge.get("connection_id", -1))
		if office or identity < 0 or built.has(identity):
			continue
		built[identity] = true
		var frame := preload("res://scripts/dream/office_low_pixel_frame.gd").new()
		frame.name = "OfficeOpeningFrame_%d" % identity
		frame.position = _door_root_world_position(edge)
		if String(edge.get("axis", "")) == "V":
			frame.rotation.y = PI * .5
		frame.set_meta(&"door_edge", edge.duplicate(true))
		frame.configure(_door_width_for_edge(edge), door_height, wall_thickness * .5)
		floor_root.add_child(frame)
		frame.set_architectural_cutaway(false, wall_height)


func _on_physical_door_shattered(_door: Node, edge: Dictionary, _key: String) -> void:
	if not _is_otxo_mansion():
		return
	var axis: String = edge.get("axis", "H")
	var x: int = edge.get("x", 0)
	var y: int = edge.get("y", 0)
	var c1 := Vector2i(x - 1, y) if axis == "V" else Vector2i(x, y - 1)
	var c2 := Vector2i(x, y) if axis == "V" else Vector2i(x, y)
	var r1: int = room_cells.get(c1, -1)
	var r2: int = room_cells.get(c2, -1)
	if r1 >= 0 and room_states.get(r1, &"UNSEEN") != &"UNSEEN" and r2 >= 0 and room_states.get(r2, &"UNSEEN") == &"UNSEEN":
		reveal_room(r2)
	elif r2 >= 0 and room_states.get(r2, &"UNSEEN") != &"UNSEEN" and r1 >= 0 and room_states.get(r1, &"UNSEEN") == &"UNSEEN":
		reveal_room(r1)
	var door_gameplay_pos := _edge_gameplay_position(edge)
	notify_gunshot(door_gameplay_pos)


func _door_opening_cells_for_edge(edge: Dictionary) -> int:
	# Door throat width is independent from corridor cross-section even though
	# the current approved 3D layout uses four cells for both. Legacy authored
	# edges may still provide their own opening metadata.
	return maxi(1, int(edge.get("opening_cells", DOOR_OPENING_CELLS)))


func _cell_world_size() -> float:
	# The authoritative mapping is the existing gameplay-pixel → 3D-world
	# conversion, not a second door-specific scale constant.
	var origin := _map_gameplay_to_world(Vector2.ZERO)
	var one_cell := _map_gameplay_to_world(Vector2(CELL_PIXELS, 0.0))
	return maxf(origin.distance_to(one_cell), 0.001)


func _door_width_for_edge(edge: Dictionary) -> float:
	# Every generated 3D doorway uses the formal cell-to-world mapping.  The
	# editor `door_width` export remains only a legacy fallback for hand-authored
	# edges without topology metadata.
	if edge.has("opening_cells") or edge.has("connection_id") or edge.has("corridor_id"):
		return float(_door_opening_cells_for_edge(edge)) * _cell_world_size()
	return maxf(door_width, 0.1)


func _validate_rendered_edge_nodes() -> void:
	if wall_root == null or door_root == null:
		return
	for key_variant in edge_states.keys():
		var key: String = key_variant
		var wall_name := "Wall_%s" % key.replace(":", "_")
		var door_name := "Door_%s" % key.replace(":", "_")
		var has_wall := wall_root.get_node_or_null(wall_name) != null
		var has_door := door_root.get_node_or_null(door_name) != null
		var state := String(edge_states[key])
		var edge: Dictionary = door_edges.get(key, wall_edges.get(key, door_opening_edges.get(key, {})))
		if not _edge_in_active_presentation(edge):
			continue
		var requires_physical_door := (int(edge.get("door_id", -1)) == boss_door_id) or (_is_otxo_mansion() and not bool(edge.get("is_elevator_sliding_door", false)) and String(edge.get("door_style", "")) != "open")
		var boundary_hidden := not door_edges.has(key) and (
			(_edge_touches_elevator(edge) and not _has_elevator_reception() and not _edge_on_elevator_door_wall(edge))
			or (use_authored_office_sample and _edge_touches_corridor(edge) and not _edge_touches_elevator(edge))
		)
		var valid := (
			(state == "OPEN" and not has_wall and not has_door)
			or (state == "WALL" and ((boundary_hidden and not has_wall and not has_door) or (not boundary_hidden and has_wall and not has_door)))
			or (state == "DOOR" and not has_wall and has_door == requires_physical_door)
			or (state == "DOOR_OPENING" and not has_wall and not has_door and door_opening_edges.has(key))
			or (state == "GLASS_WINDOW" and has_wall and not has_door)
		)
		if not valid:
			push_error("Edge visual mismatch key=%s expected=%s wall=%s door=%s" % [key, state, has_wall, has_door])


func _build_wall_visual(edge: Dictionary, key: String) -> void:
	if _is_interior_open_office_edge(edge):
		return
	var wall_visual_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	var wall := WALL_SCENE.instantiate() as Node3D
	wall.name = "Wall_%s" % key.replace(":", "_")
	wall.position = _edge_world_position(edge)
	if String(edge["axis"]) == "V":
		wall.rotation.y = PI * 0.5
	wall.set_meta(&"edge", edge.duplicate(true))
	wall.set_meta(&"edge_key", key)
	wall.set_meta(&"window_variant", window_wall_edges.has(key))
	if window_wall_edges.has(key):
		var run_data: Dictionary = window_wall_edges[key]
		wall.set_meta(&"window_left_post", bool(run_data.get("first", false)))
		wall.set_meta(&"window_right_post", bool(run_data.get("last", false)))
		wall.set_meta(&"window_pane_span", int(run_data.get("pane_span", 0)))
		wall.set_meta(&"window_pane_offset", float(run_data.get("pane_offset", 0.0)))
	wall.set_meta(&"shadow_outward_local_sign", _wall_shadow_outward_local_sign(edge))
	wall.call("configure_wall", wall_height, _architectural_wall_thickness(edge))
	var side_cells := _edge_side_cells(edge)
	var mat_pos: Material = null
	var mat_neg: Material = null
	if side_cells.size() == 2:
		var r_neg := int(room_cells.get(side_cells[0], -1))
		var r_pos := int(room_cells.get(side_cells[1], -1))
		var arch_neg := String(rooms[r_neg].get("archetype", "")) if r_neg >= 0 and r_neg < rooms.size() else ""
		var arch_pos := String(rooms[r_pos].get("archetype", "")) if r_pos >= 0 and r_pos < rooms.size() else ""
		mat_pos = THEME_SCRIPT.get_sample_wall_material(rooms[r_pos]) if r_pos >= 0 and r_pos < rooms.size() else THEME_SCRIPT.get_wall_material(arch_pos)
		mat_neg = THEME_SCRIPT.get_sample_wall_material(rooms[r_neg]) if r_neg >= 0 and r_neg < rooms.size() else THEME_SCRIPT.get_wall_material(arch_neg)
	if wall.has_method("set_wall_materials"):
		wall.call("set_wall_materials", mat_pos, mat_neg)
	wall_root.add_child(wall)
	if window_wall_edges.has(key):
		if wall.has_method("set_window_variant"):
			wall.call("set_window_variant", true)
		if wall.has_method("set_window_inward_normal"):
			var run_data: Dictionary = window_wall_edges[key]
			# The floor-side cell is the topology authority for the light's
			# direction.  The wall adapter only consumes this normal and never
			# guesses which side is inside the room.
			wall.call(
				"set_window_inward_normal",
				_window_inward_normal(edge),
				bool(config.window_light_enabled) and bool(run_data.get("light", false)),
				float(config.window_light_energy),
				float(config.window_light_range),
				float(config.window_light_angle),
				float(config.window_light_attenuation),
				config.window_light_color,
				float(config.window_light_inset)
			)
	_startup_profile_record_time("wall_visual_ms", wall_visual_started_usec)
	_startup_profile_increment("wall_visual_calls")


func _window_inward_normal(edge: Dictionary) -> Vector2:
	## Return the normal from the selected exterior wall toward its one live
	## floor-side cell.  `_is_window_boundary_edge()` guarantees one such cell;
	## retaining the defensive fallback keeps malformed/authored edges dark
	## rather than aiming a light at an arbitrary world direction.
	var side_cells := _edge_side_cells(edge)
	if side_cells.size() != 2:
		return Vector2.ZERO
	var floor_cell := INVALID_PILLAR_CELL
	var outside_cell := INVALID_PILLAR_CELL
	for cell in side_cells:
		if floor_cells.has(cell) and not pit_cells.has(cell) and not pillar_cells.has(cell):
			if floor_cell != INVALID_PILLAR_CELL:
				return Vector2.ZERO
			floor_cell = cell
		else:
			outside_cell = cell
	if floor_cell == INVALID_PILLAR_CELL or outside_cell == INVALID_PILLAR_CELL:
		return Vector2.ZERO
	return Vector2(floor_cell - outside_cell).normalized()


## Select window presentation from continuous exterior wall runs.  A wall edge
## is eligible only when exactly one of its two sides is a live walkable floor
## cell; internal walls, pillars, pits and door shoulders are excluded.  The
## returned keys are deterministic for a given topology and never affect the
## generated collision/LOS edge.
func _select_window_wall_edges() -> Dictionary:
	var selected: Dictionary = {}
	var excluded: Dictionary = {}
	for key_variant in internal_wall_edges.keys():
		excluded[String(key_variant)] = true
	for source in [door_edges, door_opening_edges]:
		var edge_map: Dictionary = source
		for edge_variant in edge_map.values():
			var edge: Dictionary = edge_variant
			var axis := String(edge.get("axis", ""))
			if axis != "H" and axis != "V":
				continue
			var x := int(edge.get("x", 0))
			var y := int(edge.get("y", 0))
			# Keep a two-edge shoulder around every logical opening.  This avoids
			# a pane immediately beside the door and also covers a door edge that
			# is not itself present in wall_edges.
			for delta in range(-2, 3):
				var neighbor_key := ("H:%d:%d" % [x + delta, y]) if axis == "H" else ("V:%d:%d" % [x, y + delta])
				excluded[neighbor_key] = true
	for key_variant in wall_edges.keys():
		var key: String = key_variant
		if excluded.has(key) or door_edges.has(key) or door_opening_edges.has(key):
			continue
		var edge: Dictionary = wall_edges[key]
		if not _edge_in_active_presentation(edge):
			continue
		if not _is_window_boundary_edge(edge):
			continue
		var axis := String(edge.get("axis", ""))
		var line := int(edge.get("y", 0)) if axis == "H" else int(edge.get("x", 0))
		var tangent := int(edge.get("x", 0)) if axis == "H" else int(edge.get("y", 0))
		# A combined pane cannot straddle two independently revealed rooms:
		# keep the same facade and room authority in one run.
		var sides := _edge_side_cells(edge)
		var inside_cell: Vector2i = sides[0] if floor_cells.has(sides[0]) else sides[1]
		var room_id := int(room_cells.get(inside_cell, -1))
		var corridor_id := int(corridor_cells.get(inside_cell, -1))
		var group_key := "%s:%d:%d:%d" % [axis, line, room_id, corridor_id]
		if not selected.has(group_key):
			selected[group_key] = {"coords": [], "keys": {}}
		var group: Dictionary = selected[group_key]
		var coords: Array = group["coords"]
		coords.append(tangent)
		group["keys"][tangent] = key
		group["coords"] = coords
	# Reuse `selected` only as a temporary grouped map; output keys are stored in
	# a separate dictionary so a wall key can never collide with a group key.
	var output: Dictionary = {}
	for group_variant in selected.values():
		var group: Dictionary = group_variant
		var coords: Array = group.get("coords", [])
		coords.sort()
		var run: Array[String] = []
		var previous := 0
		var has_previous := false
		for coord_variant in coords:
			var coord := int(coord_variant)
			if has_previous and coord != previous + 1:
				_mark_window_run(run, output)
				run = []
			run.append(String(group["keys"][coord]))
			previous = coord
			has_previous = true
		_mark_window_run(run, output)
	return output


func _is_window_boundary_edge(edge: Dictionary) -> bool:
	# A perpendicular edge at either endpoint is a corner/T junction.  Keep a
	# window out of that junction even when the parallel run itself is long
	# enough to pass the spacing test below.
	if _window_edge_near_corner(edge):
		return false
	var side_cells := _edge_side_cells(edge)
	if side_cells.size() != 2:
		return false
	var floor_count := 0
	for cell in side_cells:
		if pillar_cells.has(cell) or pit_cells.has(cell):
			return false
		if floor_cells.has(cell):
			floor_count += 1
	return floor_count == 1


func _window_edge_near_corner(edge: Dictionary) -> bool:
	var axis := String(edge.get("axis", ""))
	var x := int(edge.get("x", 0))
	var y := int(edge.get("y", 0))
	if axis == "H":
		return wall_edges.has("V:%d:%d" % [x, y]) or wall_edges.has("V:%d:%d" % [x + 1, y])
	if axis == "V":
		return wall_edges.has("H:%d:%d" % [x, y]) or wall_edges.has("H:%d:%d" % [x, y + 1])
	return true


func _mark_window_run(run: Array[String], output: Dictionary) -> void:
	if run.size() < WINDOW_MIN_RUN_LENGTH:
		return
	# Keep the corner shoulders, then treat the remaining contiguous segments
	# as a single glazed opening: end posts only, one centered light source.
	for index in range(2, run.size() - 2):
		var edge_key := run[index]
		var pane_span := run.size() - 4 if index == 2 else 0
		var pane_offset := float(pane_span - 1) * (0.5 if edge_key.begins_with("H:") else -0.5) if pane_span > 0 else 0.0
		output[edge_key] = {
			"first": index == 2,
			"last": index == run.size() - 3,
			"light": index == int(run.size() / 2),
			"pane_span": pane_span,
			"pane_offset": pane_offset,
		}


func _wall_shadow_outward_local_sign(edge: Dictionary) -> float:
	# Pick a unique walkable side for room/pillar boundary walls.  The local +Z
	# axis maps to world +Z for horizontal edges and world +X for vertical edges;
	# sign therefore moves the caster toward the non-floor side.  A wall with
	# walkable cells on both sides has no authoritative outward side and keeps
	# the old coincident placement rather than guessing a direction.
	var cells := _edge_side_cells(edge)
	if cells.size() != 2:
		return 0.0
	var floor_side := -1
	for side in 2:
		var cell: Vector2i = cells[side]
		if not floor_cells.has(cell) or pit_cells.has(cell):
			continue
		if floor_side >= 0:
			return 0.0
		floor_side = side
	if floor_side < 0:
		# Some authored edges are not in floor_cells during the first build but
		# still have room membership; use that only when it is unambiguous.
		for side in 2:
			if not room_cells.has(cells[side]):
				continue
			if floor_side >= 0:
				return 0.0
			floor_side = side
	if floor_side < 0:
		return 0.0
	var outward := Vector2(cells[1 - floor_side] - cells[floor_side])
	var local_component := outward.y if String(edge.get("axis", "H")) == "H" else outward.x
	return signf(float(local_component))


func _architectural_wall_thickness(_edge: Dictionary) -> float:
	# One logical floor cell is one world unit. Both interior/exterior walls
	# use the same architectural footprint, including their physics mirrors.
	return wall_thickness


func _build_wall_collision(edge: Dictionary, key: String) -> void:
	if _is_interior_open_office_edge(edge):
		return
	var wall_collision_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	var wall_body := StaticBody2D.new()
	wall_body.name = "WallCollision_%s" % key.replace(":", "_")
	wall_body.collision_layer = WORLD_WALL_LAYER
	wall_body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var physical_thickness := _architectural_wall_thickness(edge) * CELL_PIXELS
	if String(edge["axis"]) == "H":
		shape.size = Vector2(CELL_PIXELS, physical_thickness)
	else:
		shape.size = Vector2(physical_thickness, CELL_PIXELS)
	collision.shape = shape
	wall_body.position = _edge_gameplay_position(edge)
	wall_body.add_child(collision)
	wall_body.set_meta(&"generated_wall_edge", key)
	collision_root.add_child(wall_body)
	_build_top_wall_air_wall(edge, key)
	_startup_profile_record_time("wall_collision_ms", wall_collision_started_usec)
	_startup_profile_increment("wall_collision_calls")


## The actor billboard is screen-parallel: a character's head extends roughly
## its pixel height beyond the foot anchor toward the far side of the map.
## For a TOP wall (the room side whose inward direction faces the camera) an
## invisible air-wall band keeps the foot anchor out of the zone where the
## head would cross the wall plane, without moving or clamping the actor.
## Bullets, blood rays, vision queries and doors never use this layer, and
## door openings receive no air wall, so traversal and wall blood are intact.
func _build_top_wall_air_wall(edge: Dictionary, key: String) -> void:
	var depth: float = EMPLOYEE_CONFIG.top_wall_air_wall_depth_px
	if depth <= 1.0 or camera_3d == null:
		return
	var toward_camera := Vector2(camera_3d.global_basis.z.x, camera_3d.global_basis.z.z).normalized()
	var cells := _edge_side_cells(edge)
	for i in 2:
		var room_id := int(room_cells.get(cells[i], -1))
		if room_id < 0:
			continue
		var outward := Vector2(cells[1 - i] - cells[i]).normalized()
		if outward.dot(toward_camera) > -0.5:
			# 该侧房间的外侧朝向相机（近墙/侧墙），只有背向相机的一侧才是顶墙。
			continue
		var air_body := StaticBody2D.new()
		air_body.name = "AirWall_%s" % key.replace(":", "_")
		air_body.collision_layer = ACTOR_AIR_WALL_LAYER
		air_body.collision_mask = 0
		var air_collision := CollisionShape2D.new()
		var air_shape := RectangleShape2D.new()
		if String(edge["axis"]) == "H":
			air_shape.size = Vector2(CELL_PIXELS, depth)
		else:
			air_shape.size = Vector2(depth, CELL_PIXELS)
		air_collision.shape = air_shape
		air_body.position = _edge_gameplay_position(edge) + (-outward) * depth * 0.5
		air_body.add_child(air_collision)
		air_body.set_meta(&"generated_air_wall_edge", key)
		air_body.set_meta(&"generated_air_wall_room", room_id)
		collision_root.add_child(air_body)
		return


func _place_player() -> void:
	if player == null or not floor_cells.has(spawn_cell):
		return
	var target_pos := get_player_root_position_for_cell(spawn_cell)
	player.position = target_pos
	player.global_position = target_pos
	if player is CollisionObject2D:
		PhysicsServer2D.body_set_state(player.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, target_pos))
	player.set_meta(&"dream_room_id", spawn_room_id)
	player.velocity = Vector2.ZERO
	last_safe_floor_position = player.global_position
	_pit_player_handled = false


func _build_debug_markers() -> void:
	if not show_debug_markers:
		return
	if lazy_room_presentation:
		_add_debug_marker("ROOM", current_room_id, Color(0.55, 1.0, 0.65, 1.0))
	else:
		_add_debug_marker("START", spawn_room_id, Color(0.55, 1.0, 0.65, 1.0))
		_add_debug_marker("KEY", key_room_id, Color(1.0, 0.86, 0.28, 1.0))
		_add_debug_marker("BOSS", boss_room_id, Color(1.0, 0.35, 0.4, 1.0))


func _add_debug_marker(text: String, room_id: int, color: Color) -> void:
	if room_id < 0 or room_id >= rooms.size():
		return
	var marker := Label3D.new()
	var center: Vector2i = rooms[room_id]["center_cell"]
	marker.name = "%sMarker" % text.capitalize()
	marker.text = text
	marker.modulate = color
	marker.font_size = 32
	marker.pixel_size = 0.012
	marker.outline_size = 6
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.position = Vector3(center.x, 0.12, center.y)
	debug_root.add_child(marker)


func _cell_for_gameplay_position(at_position: Vector2) -> Vector2i:
	return Vector2i(roundi(at_position.x / CELL_PIXELS), roundi(at_position.y / CELL_PIXELS))


func _nearest_safe_floor_world_position(from_cell: Vector2i) -> Vector2:
	if floor_cells.is_empty():
		return Vector2.ZERO
	var best_cell := spawn_cell
	var best_distance := INF
	for cell_variant in floor_cells.keys():
		var cell: Vector2i = cell_variant
		if pit_cells.has(cell):
			continue
		var distance := Vector2(cell).distance_squared_to(Vector2(from_cell))
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return Vector2(best_cell) * CELL_PIXELS


func _process_pit_contacts() -> void:
	if pit_cells.is_empty():
		if player != null and is_instance_valid(player) and floor_cells.has(_cell_for_gameplay_position(player.global_position)):
			last_safe_floor_position = player.global_position
		return
	if player != null and is_instance_valid(player) and not bool(player.get("dead")):
		var player_cell := _cell_for_gameplay_position(player.global_position)
		if pit_cells.has(player_cell):
			if not _pit_player_handled:
				_pit_player_handled = true
				var landing := last_safe_floor_position
				if not floor_cells.has(_cell_for_gameplay_position(landing)):
					landing = _nearest_safe_floor_world_position(player_cell)
				var launch_direction := Vector2(player.global_position.direction_to(landing))
				if launch_direction.length_squared() <= 0.001:
					launch_direction = Vector2.UP
				if player.has_method("start_pit_recovery"):
					player.call("start_pit_recovery", landing, launch_direction)
		elif floor_cells.has(player_cell) and not bool(player.get("airborne_knockback")):
			last_safe_floor_position = player.global_position
			_pit_player_handled = false
	if enemy_root != null:
		for enemy_variant in enemy_root.get_children():
			var employee := enemy_variant as EmployeeEnemy
			if employee == null or not is_instance_valid(employee) or bool(employee.get("dead")):
				continue
			var enemy_cell := _cell_for_gameplay_position(employee.global_position)
			if not pit_cells.has(enemy_cell) or _pit_enemy_handled.has(employee.get_instance_id()):
				continue
			_pit_enemy_handled[employee.get_instance_id()] = true
			if employee.has_method("force_pit_death"):
				employee.call("force_pit_death", employee.global_position)
	for prop_variant in get_damageable_props_snapshot():
		var prop := prop_variant as Node2D
		if prop == null or not is_instance_valid(prop) or prop.get("destroyed") == true or prop.get("is_destroyed") == true:
			continue
		if not pit_cells.has(_cell_for_gameplay_position(prop.global_position)):
			continue
		if prop.has_method("destroy"):
			prop.call("destroy")
		else:
			prop.queue_free()


func _update_occlusion_cutouts() -> void:
	if not bool(get_meta(&"test_legacy_occlusion_query",false)):
		_begin_cutout_query_snapshot()
	# The manager is the only Actor -> Cutout authority. Slots contain a
	# normalized screen-space centre and a pixel radius, not a world X/Z circle;
	# this keeps the window round under the perspective camera. Slots are
	# visual-only; all 2D colliders, projectile blocking and LOS remain intact.
	# Player is always considered first so an enemy cannot evict the Player's
	# cutout when the fixed slot budget is exhausted.
	_cutout_slots_scratch.clear()
	var slots: Array[Vector4] = _cutout_slots_scratch
	if camera_3d != null and is_instance_valid(camera_3d):
		var viewport := camera_3d.get_viewport()
		if viewport != null:
			var vp_size := viewport.get_visible_rect().size
			if vp_size != _last_cutout_viewport_size:
				_last_cutout_viewport_size = vp_size
				RenderingServer.global_shader_parameter_set(
					"occlusion_viewport_size",
					vp_size
				)
	var cam_vp_rect := Rect2()
	var has_cam_vp := false
	if camera_3d != null and is_instance_valid(camera_3d):
		var vp := camera_3d.get_viewport()
		if vp != null:
			cam_vp_rect = vp.get_visible_rect().grow(100.0)
			has_cam_vp = true
	var player_occluded := false
	if player != null and is_instance_valid(player) and player.get("dead") != true:
		var player_cutout: Dictionary = _get_actor_cutout_slot(player)
		if not player_cutout.is_empty():
			var player_world: Vector3 = player_cutout.get("world", Vector3.ZERO)
			var player_radius: float = float(player_cutout.get("radius", 0.24))
			var player_wall_door := _actor_is_occluded_by_wall_or_door(player_world)
			# early_exit: only need covered/not; hole aims at visual centre, not overlap.
			var player_furn_covered := _furniture_screen_overlap(player_world, player_radius, true) != null
			if player_wall_door or player_furn_covered:
				var player_slot: Vector4 = _project_occlusion_cutout(
					player_world,
					player_radius
				)
				if player_slot.w > 0.5:
					slots.append(player_slot)
					player_occluded = true
	var refresh_enemy_cutouts := (Engine.get_process_frames() & 1) == 0
	if refresh_enemy_cutouts and enemy_root != null:
		_cached_enemy_cutout_slots.clear()
		_cached_enemy_cutout_dists.clear()
		for enemy_variant in enemy_root.get_children():
			if enemy_variant == null or not is_instance_valid(enemy_variant):
				continue
			var enemy := enemy_variant as EmployeeEnemy
			if enemy == null or bool(enemy.get("dead")):
				continue
			var cutout: Dictionary = _get_actor_cutout_slot(enemy)
			if cutout.is_empty():
				continue
			var enemy_world: Vector3 = cutout.get("world", Vector3.ZERO)
			if camera_3d != null:
				if camera_3d.is_position_behind(enemy_world):
					continue
				var screen_pos := camera_3d.unproject_position(enemy_world)
				if has_cam_vp and not cam_vp_rect.has_point(screen_pos):
					continue
			var enemy_radius: float = float(cutout.get("radius", 0.24))
			var enemy_wall_door := _actor_is_occluded_by_wall_or_door(enemy_world)
			var enemy_furn_covered := _furniture_screen_overlap(enemy_world, enemy_radius, true) != null
			if not enemy_wall_door and not enemy_furn_covered:
				continue
			var enemy_slot: Vector4 = _project_occlusion_cutout(
				enemy_world,
				enemy_radius
			)
			if enemy_slot.w <= 0.5:
				continue
			_cached_enemy_cutout_slots.append(enemy_slot)
			_cached_enemy_cutout_dists.append(
				camera_3d.global_position.distance_squared_to(enemy_world) if camera_3d != null else 0.0
			)
	# Working packed lists: copy enemy cache then append projectiles (no Dictionary temps).
	_cutout_work_slots.clear()
	_cutout_work_dists.clear()
	_cutout_work_slots.append_array(_cached_enemy_cutout_slots)
	_cutout_work_dists.append_array(_cached_enemy_cutout_dists)
	var effective_config: DemoConfig = config if config != null else EMPLOYEE_CONFIG
	var candidate_slot_limit: int = OCCLUSION_CUTOUT_SLOT_COUNT - (1 if player_occluded else 0)
	var proj_cutout_enabled := bool(effective_config.get("projectile_occlusion_cutout_enabled")) if effective_config != null and effective_config.get("projectile_occlusion_cutout_enabled") != null else true
	if proj_cutout_enabled:
		var default_proj_radius := float(effective_config.get("projectile_occlusion_cutout_radius")) if effective_config != null and effective_config.get("projectile_occlusion_cutout_radius") != null else 0.20
		var proj_frame := Engine.get_process_frames()
		if proj_frame - _cached_projectile_cutout_frame >= 2 or _cached_projectile_cutout_nodes.is_empty():
			_cached_projectile_cutout_frame = proj_frame
			_cached_projectile_cutout_nodes = get_tree().get_nodes_in_group(&"dream_projectiles")
		for projectile_node in _cached_projectile_cutout_nodes:
			if projectile_node == null or not is_instance_valid(projectile_node):
				continue
			var projectile := projectile_node as Node2D
			if projectile == null or not projectile.is_inside_tree() or projectile.is_queued_for_deletion():
				continue
			if bool(projectile.get("consumed")):
				continue
			var proj_cutout: Dictionary = _get_projectile_cutout_slot(projectile, default_proj_radius)
			if proj_cutout.is_empty():
				continue
			var proj_world: Vector3 = proj_cutout.get("world", Vector3.ZERO)
			if camera_3d != null:
				if camera_3d.is_position_behind(proj_world):
					continue
				var screen_pos := camera_3d.unproject_position(proj_world)
				if has_cam_vp and not cam_vp_rect.has_point(screen_pos):
					continue
			var proj_radius: float = float(proj_cutout.get("radius", default_proj_radius))
			var proj_wall_door := _actor_is_occluded_by_wall_or_door(proj_world)
			var proj_furn_covered := _furniture_screen_overlap(proj_world, proj_radius, true) != null
			if not proj_wall_door and not proj_furn_covered:
				continue
			var proj_slot: Vector4 = _project_occlusion_cutout(
				proj_world,
				proj_radius
			)
			if proj_slot.w <= 0.5:
				continue
			_cutout_work_slots.append(proj_slot)
			_cutout_work_dists.append(
				camera_3d.global_position.distance_squared_to(proj_world) if camera_3d != null else 0.0
			)
	_cutout_sort_indices.clear()
	for cand_i in _cutout_work_slots.size():
		_cutout_sort_indices.append(cand_i)
	_cutout_sort_indices.sort_custom(_sort_occlusion_candidate_indices)
	var slots_used := 0
	for cand_i in _cutout_sort_indices:
		if slots_used >= candidate_slot_limit or slots.size() >= OCCLUSION_CUTOUT_SLOT_COUNT:
			break
		var candidate_slot: Vector4 = _cutout_work_slots[cand_i]
		if candidate_slot.w > 0.5:
			slots.append(candidate_slot)
			slots_used += 1
	# Keep the explicit limit in the data flow so a future slot expansion cannot
	# accidentally consume a Player slot or reintroduce an unbounded array.
	if candidate_slot_limit < 0:
		candidate_slot_limit = 0
	while slots.size() < OCCLUSION_CUTOUT_SLOT_COUNT:
		slots.append(Vector4.ZERO)
	var force_set_slots := has_meta(&"test_cutout_slots")
	if force_set_slots:
		set_meta(&"test_cutout_slots", slots.duplicate())
	if _last_cutout_slots.size() != OCCLUSION_CUTOUT_SLOT_COUNT:
		_last_cutout_slots.resize(OCCLUSION_CUTOUT_SLOT_COUNT)
		for index in range(OCCLUSION_CUTOUT_SLOT_COUNT):
			_last_cutout_slots[index] = Vector4(-1.0, -1.0, -1.0, -1.0)
	for index in range(OCCLUSION_CUTOUT_SLOT_COUNT):
		var slot_val := slots[index]
		if force_set_slots or _last_cutout_slots[index] != slot_val:
			_last_cutout_slots[index] = slot_val
			RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % index, slot_val)
	_end_cutout_query_snapshot()

func _begin_cutout_query_snapshot() -> void:
	# One synchronous query batch only. No stale floor/door/furniture state is
	# retained between frames, and gameplay LOS/collision never uses this cache.
	_cutout_query_snapshot_active = true
	var legacy_wall_scan := bool(get_meta(&"test_legacy_wall_scan", false))
	if legacy_wall_scan:
		_cutout_query_walls.clear()
		_cutout_wall_centres.clear()
		_cutout_wall_positions.clear()
		if is_instance_valid(wall_root):
			var all_walls := wall_root.get_children()
			for wall in all_walls:
				if wall.name == &"WallShadowBatches":
					continue
				_cutout_query_walls.append(wall)
				if wall is Node3D:
					_cutout_wall_centres[wall.get_instance_id()] = wall.global_position
	else:
		if _static_cutout_walls.is_empty():
			_prepare_wall_cutout_cache()
		_cutout_query_walls = _static_cutout_walls
		_cutout_wall_positions = _static_cutout_wall_positions
		_cutout_wall_bins = _static_cutout_wall_bins
		_cutout_wall_edges = _static_cutout_wall_edges
		_cutout_wall_heights = _static_cutout_wall_heights
		_cutout_wall_meshes = _static_cutout_wall_meshes
	_cutout_query_doors.clear()
	_cutout_query_aabbs.clear()
	var numeric_furniture_scan := not bool(get_meta(&"test_legacy_furniture_scan", false))
	if is_instance_valid(actor_depth_bridges_root):
		if numeric_furniture_scan:
			var current_child_count := actor_depth_bridges_root.get_child_count()
			if current_child_count != _last_bridges_child_count:
				_last_bridges_child_count = current_child_count
				# Projectiles/shells/blood change this count constantly. Furniture
				# bridges register themselves at spawn; here only prune freed
				# entries — never rescan the whole bridge root per shot.
				var write_index := 0
				for bridge_variant in _cached_furniture_bridges:
					if not is_instance_valid(bridge_variant) or bridge_variant.is_queued_for_deletion():
						continue
					var source_value: Variant = bridge_variant.get("source_actor")
					if not is_instance_valid(source_value):
						source_value = bridge_variant.get_meta(&"source_actor", null)
					if not is_instance_valid(source_value):
						continue
					var source := source_value as Node2D
					if source == null or not source.is_in_group(&"damageable_props") or source.is_queued_for_deletion():
						continue
					_cached_furniture_bridges[write_index] = bridge_variant
					write_index += 1
				_cached_furniture_bridges.resize(write_index)
				_cutout_furniture_query_frame = -1  # force query rebuild after prune
			# Dirty mesh cache only when furniture art / 2D furniture population changes.
			var art_count := office_art_root.get_child_count() if is_instance_valid(office_art_root) else 0
			var furn2d_count := furniture_root.get_child_count() if is_instance_valid(furniture_root) else 0
			if art_count != _last_furniture_art_child_count or furn2d_count != _last_furniture_2d_child_count:
				_last_furniture_art_child_count = art_count
				_last_furniture_2d_child_count = furn2d_count
				_cutout_furniture_meshes_dirty = true
			var frame_now := Engine.get_process_frames()
			var rebuild_furniture_query := (
				_cutout_furniture_query_frame < 0
				or frame_now - _cutout_furniture_query_frame >= 2
				or _cutout_query_furniture.is_empty()
				or bool(get_meta(&"test_legacy_furniture_query_every_frame", false))
			)
			if rebuild_furniture_query:
				_cutout_furniture_query_frame = frame_now
				_cutout_query_furniture.clear()
				_cutout_furniture_visuals.clear()
				_cutout_furniture_positions.clear()
				for bridge_variant in _cached_furniture_bridges:
					if not is_instance_valid(bridge_variant): continue
					var bridge := bridge_variant as Node
					if bridge == null or bridge.is_queued_for_deletion(): continue
					var source_value2: Variant = bridge.get("source_actor")
					if not is_instance_valid(source_value2):
						source_value2 = bridge.get_meta(&"source_actor", null)
					if not is_instance_valid(source_value2): continue
					var source2 := source_value2 as Node2D
					if not is_instance_valid(source2) or source2.is_queued_for_deletion() or not source2.is_in_group(&"damageable_props"): continue
					_cutout_query_furniture.append(bridge)
					var visual_value: Variant = bridge.get("actor_sprite")
					var visual := visual_value as VisualInstance3D if is_instance_valid(visual_value) else null
					_cutout_furniture_visuals.append(visual)
					_cutout_furniture_positions.append(visual.global_position if is_instance_valid(visual) else Vector3(INF, INF, INF))
			else:
				# Off frames: keep membership, refresh poses for moving furniture.
				for index in _cutout_furniture_visuals.size():
					var visual2: Variant = _cutout_furniture_visuals[index]
					if visual2 is VisualInstance3D and is_instance_valid(visual2):
						_cutout_furniture_positions[index] = (visual2 as VisualInstance3D).global_position
		else:
			_cutout_query_furniture.clear()
			_cutout_furniture_visuals.clear()
			_cutout_furniture_positions.clear()
			for bridge in actor_depth_bridges_root.get_children():
				if bridge.is_queued_for_deletion(): continue
				# Immediate source deletion can precede its passive carrier's deferred
				# cleanup. Validate the raw value before any typed cast of a freed object.
				var source_value: Variant=bridge.get("source_actor")
				if not is_instance_valid(source_value): continue
				var source := source_value as Node2D
				if is_instance_valid(source) and source.is_in_group(&"damageable_props"):
					if source.is_queued_for_deletion(): continue
					_cutout_query_furniture.append(bridge)

	if is_instance_valid(door_root):
		if numeric_furniture_scan and not legacy_wall_scan:
			var door_child_count := door_root.get_child_count()
			if door_child_count != _last_door_root_child_count:
				_last_door_root_child_count = door_child_count
				_static_cutout_door_candidates.clear()
				_collect_static_cutout_door_candidates(door_root)
			for visual in _static_cutout_door_candidates:
				if is_instance_valid(visual) and visual.visible:
					_cutout_query_doors.append(visual)
		else:
			_collect_cutout_door_visuals(door_root)

func _collect_static_cutout_door_candidates(node: Node) -> void:
	for child in node.get_children():
		if child is VisualInstance3D and not child.name.contains("ShadowCaster"):
			_static_cutout_door_candidates.append(child)
		_collect_static_cutout_door_candidates(child)

func _collect_cutout_door_visuals(node: Node) -> void:
	for child in node.get_children():
		if child is VisualInstance3D and child.visible and not child.name.contains("ShadowCaster"):
			_cutout_query_doors.append(child)
		_collect_cutout_door_visuals(child)

func _end_cutout_query_snapshot() -> void:
	_cutout_query_snapshot_active = false
	_cutout_query_walls.clear()
	_cutout_wall_centres.clear()
	_cutout_wall_positions.clear()
	_cutout_wall_bins.clear()
	_cutout_wall_edges.clear()
	_cutout_wall_heights.clear()
	_cutout_wall_meshes.clear()
	_cutout_query_furniture.clear()
	_cutout_furniture_visuals.clear()
	_cutout_furniture_positions.clear()
	_cutout_query_doors.clear()
	_cutout_query_aabbs.clear()


func _get_projectile_cutout_slot(projectile: Node2D, default_radius: float = 0.20) -> Dictionary:
	if projectile == null or not is_instance_valid(projectile) or not projectile.is_inside_tree() or projectile.is_queued_for_deletion():
		_cutout_slot_result.clear()
		return _cutout_slot_result
	var world_pos := Vector3.ZERO
	if projectile.has_meta(&"depth_visual_bridge"):
		var bridge_ref: Variant = projectile.get_meta(&"depth_visual_bridge")
		var bridge: Node3D = bridge_ref.get_ref() if bridge_ref is WeakRef else null
		if bridge != null and is_instance_valid(bridge):
			var sprite: Sprite3D = bridge.get(&"actor_sprite") as Sprite3D
			if sprite != null and is_instance_valid(sprite):
				world_pos = sprite.global_position
	if world_pos == Vector3.ZERO:
		world_pos = to_global(Vector3(
			projectile.global_position.x / CELL_PIXELS,
			PROJECTILE_MUZZLE_VISUAL_HEIGHT,
			projectile.global_position.y / CELL_PIXELS
		))
	_cutout_slot_result.clear()
	_cutout_slot_result["world"] = world_pos
	_cutout_slot_result["radius"] = default_radius
	return _cutout_slot_result


func _sort_occlusion_candidate_indices(a: int, b: int) -> bool:
	return _cutout_work_dists[a] < _cutout_work_dists[b]


func _get_actor_cutout_slot(actor: Node2D) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		_cutout_slot_result.clear()
		return _cutout_slot_result
	var instance_id := actor.get_instance_id()
	if not _occlusion_bounds_cache.has(instance_id):
		_cache_actor_occlusion_bounds(actor)
	var cached: Dictionary = _occlusion_bounds_cache.get(instance_id, {})
	if cached.is_empty():
		_cutout_slot_result.clear()
		return _cutout_slot_result
	var visual_root_var: Variant = cached.get("visual_root", null)
	var visual_root: Node2D = visual_root_var as Node2D if is_instance_valid(visual_root_var) else null
	if visual_root != null and visual_root != actor:
		var cached_scale: Vector2 = cached.get("visual_root_scale", visual_root.scale)
		if not visual_root.scale.is_equal_approx(cached_scale):
			# Facing/roll/configuration can mirror or resize the carrier. Rebuild
			# only on that visual-structure change; normal frames stay O(1).
			_cache_actor_occlusion_bounds(actor)
			cached = _occlusion_bounds_cache.get(instance_id, {})
			visual_root_var = cached.get("visual_root", null)
			visual_root = visual_root_var as Node2D if is_instance_valid(visual_root_var) else null
	var local_center: Vector2 = cached.get("local_center", Vector2.ZERO)
	if visual_root != null and visual_root != actor:
		local_center += visual_root.position - cached.get("visual_root_position", Vector2.ZERO)
	var center_global := actor.global_transform * local_center
	# Align the hole with the on-screen visual carrier (center_height + depth_offset),
	# not a hardcoded mid-torso Y. Projectiles already use actor_sprite.global_position.
	return _actor_cutout_world_from_visual(
		actor, center_global, float(cached.get("radius", 0.24))
	)




## World-space centre + radius for an actor cutout. Prefer the live depth-bridge
## sprite (same plane the player sees). Fallback matches configure() defaults:
## actor_center_height=0.707..., actor_center_depth_offset=-0.707...
##
## Radius must cover the on-screen Sprite3D quad. The 2D CharacterVisual bounds
## / CELL_PIXELS underestimates that billboard (≈0.9 world → ~30px while the
## sprite is ~126px tall), so a hole aimed at the visual centre would only dig
## near the head and leave the body sealed by furniture.
const ACTOR_CUTOUT_RADIUS_HEIGHT_SCALE := 1.0

func _actor_cutout_world_from_visual(actor: Node2D, center_global: Vector2, bounds_radius: float) -> Dictionary:
	var world := to_global(Vector3(
		center_global.x / CELL_PIXELS,
		0.70710678,
		center_global.y / CELL_PIXELS - 0.70710678
	))
	var radius := maxf(bounds_radius, 0.24)
	if actor.has_meta(&"depth_visual_bridge"):
		var bridge_ref: Variant = actor.get_meta(&"depth_visual_bridge")
		var bridge: Node3D = bridge_ref.get_ref() if bridge_ref is WeakRef else null
		if bridge != null and is_instance_valid(bridge):
			var sprite: Sprite3D = bridge.get(&"actor_sprite") as Sprite3D
			if sprite != null and is_instance_valid(sprite):
				world = sprite.global_position
				var tex: Texture2D = sprite.texture
				if tex != null:
					var half_w := sprite.pixel_size * float(tex.get_width()) * 0.5
					var half_h := sprite.pixel_size * float(tex.get_height()) * 0.5
					# Half the billboard height (+ small rim pad): covers the body and a
					# sliver of floor at the feet without hollowing out large furniture.
					# (Half-diagonal was ~93 vp-px, judged too large by the user.)
					radius = maxf(radius, half_h * ACTOR_CUTOUT_RADIUS_HEIGHT_SCALE + 0.04)
			else:
				var height := 0.70710678
				var depth := -0.70710678
				var height_variant: Variant = bridge.get(&"actor_center_height")
				var depth_variant: Variant = bridge.get(&"actor_center_depth_offset")
				if height_variant is float or height_variant is int:
					height = float(height_variant)
				if depth_variant is float or depth_variant is int:
					depth = float(depth_variant)
				world = to_global(Vector3(
					center_global.x / CELL_PIXELS,
					height,
					center_global.y / CELL_PIXELS + depth
				))
	_cutout_slot_result.clear()
	_cutout_slot_result["world"] = world
	_cutout_slot_result["radius"] = radius
	return _cutout_slot_result

func _project_occlusion_cutout(world_center: Vector3, world_radius: float, screen_override: Variant = null) -> Vector4:
	if camera_3d == null or not is_instance_valid(camera_3d):
		return Vector4.ZERO
	var viewport := camera_3d.get_viewport()
	if viewport == null:
		return Vector4.ZERO
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return Vector4.ZERO
	if camera_3d.is_position_behind(world_center):
		return Vector4.ZERO
	var center_screen: Vector2 = camera_3d.unproject_position(world_center)
	# A partially hidden actor keeps its screen centre outside the blocker, so the
	# hole has to be aimed at the overlap instead of at the actor itself.
	if screen_override is Vector2:
		center_screen = screen_override
	var radius_world: float = maxf(world_radius, 0.01)
	var camera_right: Vector3 = camera_3d.global_transform.basis.x.normalized()
	var camera_up: Vector3 = camera_3d.global_transform.basis.y.normalized()
	var horizontal_edge: Vector2 = camera_3d.unproject_position(world_center + camera_right * radius_world)
	var vertical_edge: Vector2 = camera_3d.unproject_position(world_center + camera_up * radius_world)
	# A screen-space circle needs the larger projected extent so it covers the
	# complete cached visual bounds in both screen axes, including perspective.
	var radius_px: float = maxf(center_screen.distance_to(horizontal_edge), center_screen.distance_to(vertical_edge)) + 2.0
	radius_px = maxf(radius_px, 2.0)
	# Off-screen actors need no global slot. Keep a small margin so a cutout at
	# the edge can still reveal the visible part of a sprite.
	if not Rect2(Vector2.ZERO, viewport_size).grow(radius_px).has_point(center_screen):
		return Vector4.ZERO
	return Vector4(
		center_screen.x / viewport_size.x,
		center_screen.y / viewport_size.y,
		radius_px,
		1.0
	)


## Screen-space overlap between the actor and the piece of furniture covering it.
## Returns the centre of that overlap in viewport pixels, or null when nothing
## overlaps. A partially hidden actor keeps its own screen centre clear of the
## blocker, which is why aiming the hole at the actor missed the furniture.
func _actor_screen_overlap(actor_world: Vector3, actor_world_radius: float) -> Variant:
	return _furniture_screen_overlap(actor_world, actor_world_radius, false)


func _sphere_screen_rect(world_center: Vector3, world_radius: float) -> Rect2:
	if camera_3d == null or camera_3d.is_position_behind(world_center):
		return Rect2()
	var centre := camera_3d.unproject_position(world_center)
	var radius_world: float = maxf(world_radius, 0.01)
	var right := camera_3d.global_transform.basis.x.normalized()
	var up := camera_3d.global_transform.basis.y.normalized()
	var edge_x := camera_3d.unproject_position(world_center + right * radius_world)
	var edge_y := camera_3d.unproject_position(world_center + up * radius_world)
	var radius_px: float = maxf(maxf(centre.distance_to(edge_x), centre.distance_to(edge_y)), 6.0)
	return Rect2(centre - Vector2(radius_px, radius_px), Vector2(radius_px, radius_px) * 2.0)


## Projected screen rect of a world AABB, or null when any corner is behind the
## camera (the projection would be meaningless).
func _aabb_screen_rect(world_aabb: AABB) -> Variant:
	if camera_3d == null:
		return null
	var min_screen := Vector2(INF, INF)
	var max_screen := Vector2(-INF, -INF)
	# Bit-walk 8 corners; avoid allocating [x0,x1]/[y0,y1]/[z0,z1] Arrays per call.
	var x0 := world_aabb.position.x
	var x1 := world_aabb.end.x
	var y0 := world_aabb.position.y
	var y1 := world_aabb.end.y
	var z0 := world_aabb.position.z
	var z1 := world_aabb.end.z
	for corner_i in 8:
		var corner := Vector3(
			x1 if (corner_i & 1) != 0 else x0,
			y1 if (corner_i & 2) != 0 else y0,
			z1 if (corner_i & 4) != 0 else z0
		)
		if camera_3d.is_position_behind(corner):
			return null
		var projected := camera_3d.unproject_position(corner)
		min_screen = Vector2(minf(min_screen.x, projected.x), minf(min_screen.y, projected.y))
		max_screen = Vector2(maxf(max_screen.x, projected.x), maxf(max_screen.y, projected.y))
	return Rect2(min_screen, max_screen - min_screen)


func _cache_actor_occlusion_bounds(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var visual_root := actor.get_node_or_null("CharacterVisual") as Node2D
	if visual_root == null:
		visual_root = actor
	var actor_inverse := actor.global_transform.affine_inverse()
	var points: Array[Vector2] = []
	_collect_sprite_bounds(visual_root, actor_inverse, points)
	if points.is_empty():
		_occlusion_bounds_cache[actor.get_instance_id()] = {
			"visual_root": visual_root,
			"local_center": Vector2.ZERO,
			"visual_root_position": visual_root.position,
			"visual_root_scale": visual_root.scale,
			"radius": 0.24,
		}
		return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var radius := 0.5 * sqrt(bounds.size.x * bounds.size.x + bounds.size.y * bounds.size.y) / CELL_PIXELS + 0.06
	_occlusion_bounds_cache[actor.get_instance_id()] = {
		"visual_root": visual_root,
		"local_center": bounds.get_center(),
		"visual_root_position": visual_root.position,
		"visual_root_scale": visual_root.scale,
		"radius": maxf(radius, 0.24),
	}


func _collect_sprite_bounds(node: Node, actor_inverse: Transform2D, points: Array[Vector2]) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and sprite.visible:
			var rect := sprite.get_rect()
			for corner in [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(0.0, rect.size.y), rect.end]:
				points.append(actor_inverse * (sprite.global_transform * corner))
	for child in node.get_children():
		_collect_sprite_bounds(child, actor_inverse, points)


func invalidate_actor_occlusion_bounds(actor: Node2D) -> void:
	if actor != null and is_instance_valid(actor):
		_occlusion_bounds_cache.erase(actor.get_instance_id())


func _actor_is_occluded_by_wall_or_door(actor_world: Vector3) -> bool:
	if camera_3d == null or not is_instance_valid(camera_3d):
		return false
	var camera_world := camera_3d.global_position
	var ray := actor_world - camera_world
	if ray.length_squared() < 0.0001:
		return false
	if _segment_hits_wall_visual(camera_world, actor_world, ray):
		return true
	if door_root != null and _segment_hits_visual_tree(camera_world, actor_world, door_root):
		return true
	return false


func _actor_is_occluded_by_occluder(actor_world: Vector3) -> bool:
	_has_occluder_hit = false
	if _actor_is_occluded_by_wall_or_door(actor_world):
		# A wall stands behind the actor on screen, so the actor's own screen
		# position already lands on the wall face.
		return true
	return _screen_covered_by_furniture(actor_world)


## Furniture occlusion is a SCREEN-space question: what matters is whether the
## piece actually covers the actor's pixel, not whether some horizontal ray
## happens to cross it.
##
## It must test the furniture's REAL 3D MESH, not the depth-bridge sprite. The
## bridge sprite is the captured 2D projection of the item and measures only
## ~18x12 px on screen - far too small to cover an actor - while the 3D mesh is
## what the player actually sees blocking them.
func _screen_covered_by_furniture(actor_world: Vector3) -> bool:
	return _furniture_screen_overlap(actor_world, 0.24, true) != null


## Shared furniture screen test. When early_exit is true, returns the first
## overlapping centre (boolean covered). When false, returns the largest-area
## overlap centre used to aim the cutout hole. null means no furniture covers
## the actor. Corridor bins + per-frame screen-rect cache keep this far below
## the previous O(actors x all furniture meshes) cost.
func _furniture_screen_overlap(actor_world: Vector3, actor_world_radius: float, early_exit: bool) -> Variant:
	if camera_3d == null or camera_3d.is_position_behind(actor_world):
		return null
	var actor_rect := _sphere_screen_rect(actor_world, actor_world_radius)
	if actor_rect.size.x <= 0.0 or actor_rect.size.y <= 0.0:
		return null
	var actor_distance := camera_3d.global_position.distance_squared_to(actor_world)
	_ensure_furniture_mesh_cache()
	var indices: Array
	if bool(get_meta(&"test_legacy_furniture_screen_scan", false)):
		indices = []
		indices.resize(_cutout_furniture_meshes.size())
		for i in _cutout_furniture_meshes.size():
			indices[i] = i
	else:
		indices = _furniture_mesh_indices_near(camera_3d.global_position, actor_world)
	var best: Variant = null
	var best_area := 0.0
	var min_overlap := 0.5 if early_exit else 1.0
	for index in indices:
		if index < 0 or index >= _cutout_furniture_meshes.size():
			continue
		var node: Variant = _cutout_furniture_meshes[index]
		if not is_instance_valid(node):
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree():
			continue
		if mesh_instance.mesh == null:
			continue
		var centre: Vector3 = _cutout_furniture_mesh_centers[index] if index < _cutout_furniture_mesh_centers.size() else mesh_instance.global_position
		if camera_3d.global_position.distance_squared_to(centre) >= actor_distance:
			continue
		var rect_variant: Variant = _furniture_mesh_screen_rect(mesh_instance)
		if not (rect_variant is Rect2):
			continue
		var overlap: Rect2 = actor_rect.intersection(rect_variant as Rect2)
		if overlap.size.x <= min_overlap or overlap.size.y <= min_overlap:
			continue
		if early_exit:
			return overlap.get_center()
		var area := overlap.size.x * overlap.size.y
		if area > best_area:
			best_area = area
			best = overlap.get_center()
	return best


func _furniture_mesh_screen_rect(mesh_instance: MeshInstance3D) -> Variant:
	var skip_cache := bool(get_meta(&"test_legacy_furniture_screen_scan", false))
	var frame := Engine.get_process_frames()
	if not skip_cache:
		if frame != _cutout_furniture_screen_rect_frame:
			_cutout_furniture_screen_rect_frame = frame
			_cutout_furniture_screen_rects.clear()
		var id := mesh_instance.get_instance_id()
		if _cutout_furniture_screen_rects.has(id):
			return _cutout_furniture_screen_rects[id]
	var local_aabb: AABB = mesh_instance.get_aabb()
	if local_aabb.size.length_squared() <= 0.000001:
		if not skip_cache:
			_cutout_furniture_screen_rects[mesh_instance.get_instance_id()] = null
		return null
	var world_aabb := _world_aabb_for_visual(local_aabb, mesh_instance.global_transform)
	var rect_variant: Variant = _aabb_screen_rect(world_aabb)
	if not skip_cache:
		_cutout_furniture_screen_rects[mesh_instance.get_instance_id()] = rect_variant
	return rect_variant


func _ensure_furniture_mesh_cache() -> void:
	var frame := Engine.get_process_frames()
	if (
		not _cutout_furniture_meshes_dirty
		and not _cutout_furniture_meshes.is_empty()
		and frame == _cutout_furniture_meshes_frame
	):
		return
	var need_rebuild := (
		_cutout_furniture_meshes_dirty
		or _cutout_furniture_meshes.is_empty()
		or frame % FURNITURE_MESH_REFRESH_FRAMES == 0
	)
	# Centre/bin refresh used to run every process frame (~600 mesh global_position
	# reads). Static office furniture rarely moves; refresh on rebuild or every
	# FURNITURE_MESH_CENTER_REFRESH_FRAMES instead.
	var need_centers := need_rebuild or (
		frame % FURNITURE_MESH_CENTER_REFRESH_FRAMES == 0
		and frame != _cutout_furniture_meshes_frame
	)
	_cutout_furniture_meshes_frame = frame
	if need_rebuild:
		_rebuild_furniture_mesh_cache()
	elif need_centers:
		_refresh_furniture_mesh_centers_and_bins()


func _furniture_meshes() -> Array:
	_ensure_furniture_mesh_cache()
	return _cutout_furniture_meshes


func _rebuild_furniture_mesh_cache() -> void:
	_cutout_furniture_meshes.clear()
	_cutout_furniture_mesh_centers.clear()
	_cutout_furniture_mesh_bins.clear()
	# Scope the mesh scan to furniture art / known furniture bridges. A whole-tree
	# find_children("*", MeshInstance3D) was ~10–18ms on crowded floors and ran
	# whenever any depth bridge (projectile/shell) was added.
	_furniture_scan_roots.clear()
	if is_instance_valid(office_art_root):
		_furniture_scan_roots.append(office_art_root)
	for bridge_variant in _cached_furniture_bridges:
		if is_instance_valid(bridge_variant):
			_furniture_scan_roots.append(bridge_variant)
	if _furniture_scan_roots.is_empty() and is_instance_valid(furniture_root):
		# Fallback: rare floors without office art still need a mesh list.
		for node in find_children("*", "MeshInstance3D", true, false):
			if _mesh_belongs_to_furniture(node):
				_cutout_furniture_meshes.append(node)
	else:
		_furniture_rebuild_seen.clear()
		for root_node in _furniture_scan_roots:
			for node in root_node.find_children("*", "MeshInstance3D", true, false):
				var id := node.get_instance_id()
				if _furniture_rebuild_seen.has(id):
					continue
				if _mesh_belongs_to_furniture(node):
					_furniture_rebuild_seen[id] = true
					_cutout_furniture_meshes.append(node)
	_cutout_furniture_meshes_dirty = false
	_refresh_furniture_mesh_centers_and_bins()


func _refresh_furniture_mesh_centers_and_bins() -> void:
	_cutout_furniture_mesh_centers.resize(_cutout_furniture_meshes.size())
	_cutout_furniture_mesh_bins.clear()
	for index in _cutout_furniture_meshes.size():
		var node: Variant = _cutout_furniture_meshes[index]
		var centre := Vector3(INF, INF, INF)
		if is_instance_valid(node):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance != null:
				centre = mesh_instance.global_position
		_cutout_furniture_mesh_centers[index] = centre
		if centre.x == INF:
			continue
		var bin_key := Vector2i(
			int(floor(centre.x / FURNITURE_MESH_BIN_SIZE)),
			int(floor(centre.z / FURNITURE_MESH_BIN_SIZE))
		)
		if not _cutout_furniture_mesh_bins.has(bin_key):
			_cutout_furniture_mesh_bins[bin_key] = []
		_cutout_furniture_mesh_bins[bin_key].append(index)


## Mesh indices near the actor in XZ, plus anything along the camera->actor
## corridor. The near-radius catch covers side-adjacent furniture the corridor
## alone would miss; bins keep the gather cheap vs scanning all meshes.
func _furniture_mesh_indices_near(camera_world: Vector3, actor_world: Vector3) -> Array:
	_ensure_furniture_mesh_cache()
	var radius := FURNITURE_MESH_NEAR_RADIUS
	# Union of actor disc and camera->actor corridor (expanded by radius).
	var min_x := minf(camera_world.x, actor_world.x) - radius
	var max_x := maxf(camera_world.x, actor_world.x) + radius
	var min_z := minf(camera_world.z, actor_world.z) - radius
	var max_z := maxf(camera_world.z, actor_world.z) + radius
	var min_bx := int(floor(min_x / FURNITURE_MESH_BIN_SIZE))
	var max_bx := int(floor(max_x / FURNITURE_MESH_BIN_SIZE))
	var min_bz := int(floor(min_z / FURNITURE_MESH_BIN_SIZE))
	var max_bz := int(floor(max_z / FURNITURE_MESH_BIN_SIZE))
	_furniture_near_indices.clear()
	_furniture_near_seen.clear()
	var radius_sq := radius * radius
	for bz in range(min_bz, max_bz + 1):
		for bx in range(min_bx, max_bx + 1):
			var bin_indices: Array = _cutout_furniture_mesh_bins.get(Vector2i(bx, bz), [])
			for index in bin_indices:
				if _furniture_near_seen.has(index):
					continue
				if index < 0 or index >= _cutout_furniture_mesh_centers.size():
					continue
				var centre := _cutout_furniture_mesh_centers[index]
				if centre.x < min_x or centre.x > max_x or centre.z < min_z or centre.z > max_z:
					continue
				# Keep meshes near the actor, or anywhere in the corridor strip
				# between camera and actor (covering pieces that sit forward).
				var dx := centre.x - actor_world.x
				var dz := centre.z - actor_world.z
				var near_actor := (dx * dx + dz * dz) <= radius_sq
				var in_corridor := (
					centre.x >= minf(camera_world.x, actor_world.x) - 1.5
					and centre.x <= maxf(camera_world.x, actor_world.x) + 1.5
					and centre.z >= minf(camera_world.z, actor_world.z) - 1.5
					and centre.z <= maxf(camera_world.z, actor_world.z) + 1.5
				)
				if not near_actor and not in_corridor:
					continue
				_furniture_near_seen[index] = true
				_furniture_near_indices.append(index)
	return _furniture_near_indices


## A mesh counts as furniture when one of its ancestors carries the marker set by
## office_low_pixel_art.make_visual(), or owns a damageable_props source actor.
func _mesh_belongs_to_furniture(mesh: Node) -> bool:
	var cursor: Node = mesh
	while cursor != null:
		if cursor.has_meta(&"occlusion_cutout_occluder"):
			return bool(cursor.get_meta(&"occlusion_cutout_occluder"))
		var source: Variant = cursor.get("source_actor")
		if source is Node2D:
			return (source as Node2D).is_in_group(&"damageable_props")
		cursor = cursor.get_parent()
	return false


## True when the projected box contains the point. Corners behind the camera make
## the projection meaningless, so that box is rejected outright.
func _aabb_covers_screen_point(world_aabb: AABB, screen_point: Vector2) -> bool:
	var min_screen := Vector2(INF, INF)
	var max_screen := Vector2(-INF, -INF)
	var x0 := world_aabb.position.x
	var x1 := world_aabb.end.x
	var y0 := world_aabb.position.y
	var y1 := world_aabb.end.y
	var z0 := world_aabb.position.z
	var z1 := world_aabb.end.z
	for corner_i in 8:
		var corner := Vector3(
			x1 if (corner_i & 1) != 0 else x0,
			y1 if (corner_i & 2) != 0 else y0,
			z1 if (corner_i & 4) != 0 else z0
		)
		if camera_3d.is_position_behind(corner):
			return false
		var projected := camera_3d.unproject_position(corner)
		min_screen = Vector2(minf(min_screen.x, projected.x), minf(min_screen.y, projected.y))
		max_screen = Vector2(maxf(max_screen.x, projected.x), maxf(max_screen.y, projected.y))
	var rect := Rect2(min_screen, max_screen - min_screen)
	return rect.grow(2.0).has_point(screen_point)


## Preferred anchor for a cutout slot: the occluder when one was found.
func _cutout_anchor(fallback: Vector3) -> Vector3:
	return _occluder_hit_position if _has_occluder_hit else fallback


func _segment_hits_wall_visual(camera_world: Vector3, actor_world: Vector3, ray: Vector3) -> bool:
	if wall_root == null:
		return false
	var min_x := minf(camera_world.x, actor_world.x) - 0.7
	var max_x := maxf(camera_world.x, actor_world.x) + 0.7
	var min_z := minf(camera_world.z, actor_world.z) - 0.7
	var max_z := maxf(camera_world.z, actor_world.z) + 0.7
	var walls: Array = _cutout_query_walls if _cutout_query_snapshot_active else wall_root.get_children()
	var legacy_wall_scan := not _cutout_query_snapshot_active or bool(get_meta(&"test_legacy_wall_scan", false))
	if legacy_wall_scan:
		for index in walls.size():
			var wall := walls[index] as Node3D
			if wall == null or not is_instance_valid(wall) or wall.name == &"WallShadowBatches": continue
			var wall_center: Vector3 = _cutout_wall_centres[wall.get_instance_id()] if _cutout_query_snapshot_active else wall.global_position
			if wall_center.x < min_x or wall_center.x > max_x or wall_center.z < min_z or wall_center.z > max_z: continue
			var wall_mesh := wall.get_node_or_null("WallMesh") as VisualInstance3D
			if wall_mesh != null and not wall_mesh.visible: continue
			var edge: Dictionary = wall.get_meta(&"edge", {})
			if edge.is_empty(): continue
			var t := -1.0
			if String(edge.get("axis", "")) == "H":
				if absf(ray.z) < 0.0001: continue
				t = (wall_center.z - camera_world.z) / ray.z
				var x_at := camera_world.x + ray.x * t
				if t > 0.02 and t < 0.98 and absf(x_at - wall_center.x) <= 0.56: return true
			else:
				if absf(ray.x) < 0.0001: continue
				t = (wall_center.x - camera_world.x) / ray.x
				var z_at := camera_world.z + ray.z * t
				if t > 0.02 and t < 0.98 and absf(z_at - wall_center.z) <= 0.56: return true
		return false

	var min_bx := int(floor(min_x / 4.0))
	var max_bx := int(floor(max_x / 4.0))
	var min_bz := int(floor(min_z / 4.0))
	var max_bz := int(floor(max_z / 4.0))

	for bz in range(min_bz, max_bz + 1):
		for bx in range(min_bx, max_bx + 1):
			var bin_indices: Array = _cutout_wall_bins.get(Vector2i(bx, bz), [])
			for index in bin_indices:
				var wall_center := _cutout_wall_positions[index]
				if wall_center.x < min_x or wall_center.x > max_x or wall_center.z < min_z or wall_center.z > max_z:
					continue
				var wall_mesh: VisualInstance3D = _cutout_wall_meshes[index]
				if wall_mesh != null and not wall_mesh.visible:
					continue
				var edge: Dictionary = _cutout_wall_edges[index]
				if edge.is_empty():
					continue
				var t := -1.0
				if String(edge.get("axis", "")) == "H":
					if absf(ray.z) < 0.0001:
						continue
					t = (wall_center.z - camera_world.z) / ray.z
					var x_at := camera_world.x + ray.x * t
					if t > 0.02 and t < 0.98 and absf(x_at - wall_center.x) <= 0.56:
						return true
				else:
					if absf(ray.x) < 0.0001:
						continue
					t = (wall_center.x - camera_world.x) / ray.x
					var z_at := camera_world.z + ray.z * t
					if t > 0.02 and t < 0.98 and absf(z_at - wall_center.z) <= 0.56:
						return true
	return false


func _segment_hits_furniture_visual(camera_world: Vector3, actor_world: Vector3) -> bool:
	return _find_furniture_occluder(camera_world, actor_world) != null


## Returns the furniture visual that breaks the sightline, or null. The callers
## that only need a yes/no answer use _segment_hits_furniture_visual above; the
## cutout anchor needs the actual node so it can project the hole onto it.
func _find_furniture_occluder(camera_world: Vector3, actor_world: Vector3) -> VisualInstance3D:
	if actor_depth_bridges_root == null:
		return null
	var min_x := minf(camera_world.x, actor_world.x) - 1.2
	var max_x := maxf(camera_world.x, actor_world.x) + 1.2
	var min_z := minf(camera_world.z, actor_world.z) - 1.2
	var max_z := maxf(camera_world.z, actor_world.z) + 1.2
	var bridges: Array = _cutout_query_furniture if _cutout_query_snapshot_active else actor_depth_bridges_root.get_children()
	var numeric_scan := _cutout_query_snapshot_active and not bool(get_meta(&"test_legacy_furniture_scan", false))
	for index in bridges.size():
		if numeric_scan:
			# Current synchronous batch only, just like the wall positions. No
			# cross-frame state survives furniture movement or floor rollback.
			var centre := _cutout_furniture_positions[index]
			if centre.x < min_x or centre.x > max_x or centre.z < min_z or centre.z > max_z:
				continue
		var bridge_variant: Variant = bridges[index]
		var bridge := bridge_variant as Node
		if bridge == null or not is_instance_valid(bridge):
			continue
		var visual := _cutout_furniture_visuals[index] if numeric_scan else bridge.get("actor_sprite") as VisualInstance3D
		if visual == null or not is_instance_valid(visual) or not visual.visible:
			continue
		var pos: Vector3 = visual.global_position
		if pos.x < min_x or pos.x > max_x or pos.z < min_z or pos.z > max_z:
			continue
		var source := bridge.get("source_actor") as Node2D
		if source == null or not is_instance_valid(source) or not source.is_in_group(&"damageable_props"):
			continue
		if _segment_intersects_visual_aabb(camera_world, actor_world, visual):
			return visual
	return null


func _segment_hits_visual_tree(from: Vector3, to: Vector3, root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	if _cutout_query_snapshot_active and root == door_root:
		var min_x := minf(from.x, to.x) - 1.2
		var max_x := maxf(from.x, to.x) + 1.2
		var min_z := minf(from.z, to.z) - 1.2
		var max_z := maxf(from.z, to.z) + 1.2
		for visual in _cutout_query_doors:
			if is_instance_valid(visual):
				var pos := visual.global_position
				if pos.x < min_x or pos.x > max_x or pos.z < min_z or pos.z > max_z:
					continue
				if _segment_intersects_visual_aabb(from, to, visual):
					return true
		return false
	for child in root.get_children():
		var visual := child as VisualInstance3D
		if visual != null and is_instance_valid(visual) and visual.visible and not child.name.contains("ShadowCaster"):
			if _segment_intersects_visual_aabb(from, to, visual):
				return true
		if _segment_hits_visual_tree(from, to, child):
			return true
	return false


func _segment_intersects_visual_aabb(
	from: Vector3,
	to: Vector3,
	visual: VisualInstance3D,
	ignore_height: bool = true
) -> bool:
	var id := visual.get_instance_id()
	if _cutout_query_snapshot_active and _cutout_query_aabbs.has(id):
		return _segment_intersects_aabb(from, to, _cutout_query_aabbs[id], ignore_height)
	var local_aabb: AABB = visual.get_aabb()
	# Sprite3D/quad visuals intentionally have zero thickness on their facing
	# axis. Reject only an actually empty bounds, then inflate the world box so
	# the camera segment can intersect the visual plane.
	if local_aabb.size.length_squared() <= 0.000001:
		return false
	var world_aabb := _world_aabb_for_visual(local_aabb, visual.global_transform)
	var grown := world_aabb.grow(0.03)
	if _cutout_query_snapshot_active: _cutout_query_aabbs[id] = grown
	return _segment_intersects_aabb(from, to, grown, ignore_height)


func _world_aabb_for_visual(local_aabb: AABB, transform: Transform3D) -> AABB:
	var world_aabb := AABB()
	var initialized := false
	var x0 := local_aabb.position.x
	var x1 := local_aabb.end.x
	var y0 := local_aabb.position.y
	var y1 := local_aabb.end.y
	var z0 := local_aabb.position.z
	var z1 := local_aabb.end.z
	for corner_i in 8:
		var point := transform * Vector3(
			x1 if (corner_i & 1) != 0 else x0,
			y1 if (corner_i & 2) != 0 else y0,
			z1 if (corner_i & 4) != 0 else z0
		)
		if not initialized:
			world_aabb = AABB(point, Vector3.ZERO)
			initialized = true
		else:
			world_aabb = world_aabb.expand(point)
	return world_aabb


func _segment_intersects_aabb(
	from: Vector3,
	to: Vector3,
	aabb: AABB,
	ignore_height: bool = false
) -> bool:
	var direction := to - from
	var t_min := 0.0
	var t_max := 1.0
	# Top-down screen-space occlusion.  The cutout must follow what the camera
	# actually draws over the actor, so with ignore_height the test uses only the
	# ground footprint (X/Z) of the box and drops the Y axis.  A steep gameplay
	# camera (measured y=15.6, pitch -60 deg) sends the 3D segment far above a
	# 3.0-high wall top, so a height-aware slab test reported "not blocked" for
	# essentially every real case and the cutout never fired.
	var axes: Array = [0, 2] if ignore_height else [0, 1, 2]
	for axis_value in axes:
		var axis: int = axis_value
		var origin_component: float = from[axis]
		var direction_component: float = direction[axis]
		var minimum: float = aabb.position[axis]
		var maximum: float = aabb.end[axis]
		if absf(direction_component) < 0.000001:
			if origin_component < minimum or origin_component > maximum:
				return false
			continue
		var inverse_direction := 1.0 / direction_component
		var near_t := (minimum - origin_component) * inverse_direction
		var far_t := (maximum - origin_component) * inverse_direction
		if near_t > far_t:
			var swap_t := near_t
			near_t = far_t
			far_t = swap_t
		t_min = maxf(t_min, near_t)
		t_max = minf(t_max, far_t)
		if t_min > t_max:
			return false
	return t_max > 0.02 and t_min < 0.98


func _update_camera_and_actor_projection(delta: float = 0.0) -> void:
	if player == null or camera_rig == null or camera_3d == null or gameplay_canvas == null:
		return
	# Follow the formal Player root, which is the visual foot/ground baseline.
	# CollisionShape2D is intentionally offset upward inside DreamPlayer; using
	# its center here shifts the camera and the depth bridge by that offset and
	# makes the character appear to float near walls.
	var gameplay_position := _player_ground_anchor_position()
	var ground_position := Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)
	if dialogue_camera != null and is_instance_valid(dialogue_camera) and not _phone_camera_refresh_only:
		dialogue_camera.call("advance", delta, ground_position)
	if delta > 0.0 and camera_impulse_offset.length_squared() > 0.000001:
		camera_impulse_offset = camera_impulse_offset.move_toward(Vector3.ZERO, delta * 5.5)
	var shake_offset := Vector3.ZERO
	if delta > 0.0 and camera_shake_elapsed < camera_shake_duration:
		camera_shake_elapsed += delta
		var progress := clampf(camera_shake_elapsed / maxf(camera_shake_duration, 0.001), 0.0, 1.0)
		var envelope := (1.0 - progress) * (1.0 - progress)
		var phase := camera_shake_elapsed * config.camera_shake_frequency * TAU
		shake_offset = Vector3(sin(phase), 0.0, cos(phase * 1.37)) * camera_shake_amplitude * envelope
	elif delta > 0.0 and camera_shake_duration > 0.0:
		camera_shake_amplitude = 0.0
		camera_shake_duration = 0.0
	if phone_camera_weight <= 0.0 and not _phone_camera_refresh_only:
		camera_aim_offset = _update_camera_aim_offset(gameplay_position, delta)
	var normal_focus := ground_position + camera_aim_offset * (1.0 - phone_camera_weight)
	var dialogue_focus := ground_position
	var dialogue_weight := 0.0
	var dialogue_zoom := 0.80
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		var focus_variant: Variant = dialogue_camera.call("get_focus_world", ground_position)
		if focus_variant is Vector3:
			dialogue_focus = focus_variant
		dialogue_weight = clampf(float(dialogue_camera.call("get_dialogue_weight")), 0.0, 1.0)
		dialogue_zoom = clampf(float(dialogue_camera.get("dialogue_zoom_factor")), 0.1, 1.0)
	# Look-ahead is part of normal_focus and therefore fades exactly once through
	# the composition lerp.  Do not scale it separately by (1 - weight).
	var composed_focus := normal_focus.lerp(dialogue_focus, dialogue_weight)
	var zoom: float = lerpf(1.0, dialogue_zoom, dialogue_weight) * PHONE_CAMERA.zoom_factor(phone_camera_weight)
	var phone_fov: float = authoritative_camera_fov * zoom
	var phone_size: float = authoritative_camera_size * GAMEPLAY_CAMERA_SIZE_MULTIPLIER * zoom
	composed_focus += PHONE_CAMERA.focus_offset(camera_3d, phone_camera_weight, phone_fov, phone_size)
	if transition_phase == &"CAB_RIDE" and active_transition_cab != null and is_instance_valid(active_transition_cab):
		composed_focus = to_local(active_transition_cab.get_camera_focus_world())
		camera_impulse_offset = Vector3.ZERO
		shake_offset = Vector3.ZERO
	var elevator_rumble_offset := Vector3.ZERO
	if elevator_rumble_active:
		elevator_rumble_time += delta
		var freq := 38.0
		var vert := sin(elevator_rumble_time * freq) * 0.024 * elevator_rumble_intensity
		var horiz := cos(elevator_rumble_time * freq * 0.65) * 0.008 * elevator_rumble_intensity
		elevator_rumble_offset = Vector3(horiz, vert, 0.0)
	camera_rig.position = composed_focus + camera_impulse_offset + shake_offset + elevator_rumble_offset
	if camera_3d.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera_3d.fov = phone_fov
	else:
		camera_3d.size = phone_size
	var screen_position := camera_3d.unproject_position(to_global(ground_position))
	gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, screen_position - gameplay_position)


func set_phone_camera_weight(weight: float) -> void:
	phone_camera_weight = clampf(weight, 0.0, 1.0)


func refresh_phone_camera_presentation(_delta: float = 0.0) -> void:
	_phone_camera_refresh_only = true
	_update_camera_and_actor_projection(0.0)
	_phone_camera_refresh_only = false


func _map_gameplay_to_world(gameplay_position: Vector2) -> Vector3:
	return Vector3(gameplay_position.x / CELL_PIXELS, 0.0, gameplay_position.y / CELL_PIXELS)


## Public adapter for positional WorldSFX and other presentation-only systems.
## Gameplay remains a Node2D authority; callers provide a gameplay-space point
## and this scene applies the same X/Z mapping used by every depth bridge.
func get_gameplay_world_position(gameplay_position: Vector2, height: float = 0.65) -> Vector3:
	var mapped := _map_gameplay_to_world(gameplay_position)
	mapped.y = height
	return to_global(mapped)


func _get_dream_time_controller() -> Node:
	var root := get_tree().root
	if root == null:
		return null
	return root.get_node_or_null("DreamTimeController") as Node


func _enter_dream_time_mode() -> void:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("enter_dream_time_mode"):
		time_controller.call("enter_dream_time_mode", player, config, self)


func _exit_dream_time_mode() -> void:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("exit_dream_time_mode"):
		time_controller.call("exit_dream_time_mode", self)


func _get_presentation_delta(fallback: float) -> float:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("get_real_delta"):
		return maxf(float(time_controller.call("get_real_delta")), 0.0)
	return fallback


func begin_dialogue_focus(speaker: Node2D = null, mode: int = DIALOGUE_CONVERSATION_MODE) -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("begin_dialogue_focus", speaker, mode)


func set_dialogue_speaker(speaker: Node2D = null, mode_override: int = -1) -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("set_dialogue_speaker", speaker, mode_override)


func end_dialogue_focus() -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("end_dialogue_focus")


func clear_dialogue_focus() -> void:
	if dialogue_camera != null and is_instance_valid(dialogue_camera):
		dialogue_camera.call("clear_dialogue_focus")


func register_dialogue_speaker(speaker_id: StringName, speaker: Node2D) -> void:
	if speaker_id == &"" or speaker == null or not is_instance_valid(speaker):
		return
	dialogue_speaker_registry[speaker_id] = weakref(speaker)


func unregister_dialogue_speaker(speaker_id: StringName) -> void:
	dialogue_speaker_registry.erase(speaker_id)


func resolve_dialogue_speaker(speaker_id: StringName) -> Node2D:
	if speaker_id == &"system" or speaker_id == &"narrator" or speaker_id == &"":
		return null
	var stored: Variant = dialogue_speaker_registry.get(speaker_id)
	if stored is WeakRef:
		var weak_speaker: Variant = stored.get_ref()
		if weak_speaker is Node2D and is_instance_valid(weak_speaker):
			return weak_speaker
		dialogue_speaker_registry.erase(speaker_id)
		return null
	if stored is Node2D and is_instance_valid(stored):
		return stored
	return null


func set_dialogue_speaker_id(speaker_id: StringName, mode_override: int = -1) -> void:
	var speaker := resolve_dialogue_speaker(speaker_id)
	if speaker == null:
		if speaker_id != &"system" and speaker_id != &"narrator" and speaker_id != &"" and not _unknown_dialogue_speakers.has(speaker_id):
			_unknown_dialogue_speakers[speaker_id] = true
			push_warning("3D Random Dream dialogue speaker '%s' could not be resolved; keeping current focus." % String(speaker_id))
		return
	set_dialogue_speaker(speaker, mode_override)


## Restores the old 2D DreamWorld crosshair look-ahead (dream_world.gd
## _get_camera_target_aim_offset) on the fixed 3D camera. Direction comes from
## the shared 3D ground aim point, never the raw screen delta, so the offset is
## identical across window sizes. Magnitude, distance ramp and smoothing reuse
## the legacy camera_aim_* DemoConfig parameters, converted px -> world cells.
## Rotation and projection are never touched by the look-ahead helper; the
## active camera's perspective FOV (or orthographic size fallback) is composed
## only by _update_camera_and_actor_projection().
func _update_camera_aim_offset(ground: Vector2, delta: float) -> Vector3:
	if delta <= 0.0:
		return camera_aim_offset
	return compute_camera_aim_offset(ground, get_gameplay_aim_position(), delta)


## Pure look-ahead math (exposed for deterministic tests): the legacy 2D
## per-axis offset formula driven by the 3D ground aim point.
func compute_camera_aim_offset(ground: Vector2, aim_point: Vector2, delta: float) -> Vector3:
	var aim_delta := aim_point - ground
	var aim_direction: Vector2 = (
		aim_delta.normalized()
		if aim_delta.length_squared() > 1.0
		else (player.last_aim_direction if player != null else Vector2.RIGHT)
	)
	var active_cfg = config if config != null else EMPLOYEE_CONFIG
	var maximum_distance := maxf(active_cfg.camera_aim_distance_for_max_offset, 1.0)
	var aim_strength := clampf(aim_delta.length() / maximum_distance, 0.0, 1.0)
	var target_pixels := Vector2(
		aim_direction.x * active_cfg.camera_aim_max_offset_x,
		aim_direction.y * active_cfg.camera_aim_max_offset_y
	) * aim_strength
	var aim_alpha := 1.0 - exp(-maxf(active_cfg.camera_aim_smoothing, 0.01) * delta)
	return camera_aim_offset.lerp(Vector3(target_pixels.x / CELL_PIXELS, 0.0, target_pixels.y / CELL_PIXELS), aim_alpha)


func request_camera_impulse(level: StringName = &"small", direction: Vector2 = Vector2.ZERO) -> void:
	"""Apply a short position-only camera kick without changing the fixed camera."""
	var normalized_strength := 0.30
	match level:
		&"medium": normalized_strength = 0.72
		&"heavy": normalized_strength = 1.20
		_: pass
	request_camera_impulse_strength(normalized_strength, direction)


func request_camera_impulse_strength(normalized_strength: float, direction: Vector2 = Vector2.ZERO) -> void:
	var active_cfg = config if config != null else EMPLOYEE_CONFIG
	var max_norm: float = active_cfg.combat_impact_max_normalized if active_cfg != null else 1.5
	var clamped := clampf(normalized_strength, 0.0, max_norm)
	var magnitude := lerpf(0.15, 0.60, clamped / maxf(max_norm, 0.001))
	var kick := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var perpendicular := Vector2(-kick.y, kick.x)
	var jitter := _content_rng.randf_range(-0.35, 0.35) if _content_rng != null else 0.0
	var offset_2d := kick * magnitude + perpendicular * magnitude * jitter
	camera_impulse_offset += Vector3(offset_2d.x, 0.0, offset_2d.y)
	camera_impulse_offset.x = clampf(camera_impulse_offset.x, -0.75, 0.75)
	camera_impulse_offset.z = clampf(camera_impulse_offset.z, -0.75, 0.75)
	camera_shake_amplitude = maxf(camera_shake_amplitude, magnitude * 0.90)
	var imp_dur: float = active_cfg.camera_impulse_duration if active_cfg != null else 0.12
	camera_shake_duration = maxf(camera_shake_duration, imp_dur * lerpf(0.65, 1.35, clamped / maxf(max_norm, 0.001)))
	camera_shake_elapsed = 0.0


func request_combat_impact(knockback_force: float, direction: Vector2, _source: StringName = &"") -> void:
	var normalized := clampf(
		maxf(knockback_force, 0.0) / maxf(config.combat_impact_reference_knockback, 1.0),
		0.0,
		config.combat_impact_max_normalized
	)
	var tier: StringName = &"small"
	if normalized >= 0.90:
		tier = &"heavy"
	elif normalized >= 0.40:
		tier = &"medium"
	request_hit_stop(tier)
	request_camera_impulse_strength(normalized, direction)


func _player_ground_anchor_position() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return player.global_position


func _edge_from_cell_direction(cell: Vector2i, direction: Vector2i) -> Dictionary:
	if direction == Vector2i(0, -1):
		return {"axis": "H", "x": cell.x, "y": cell.y}
	if direction == Vector2i(0, 1):
		return {"axis": "H", "x": cell.x, "y": cell.y + 1}
	if direction == Vector2i(-1, 0):
		return {"axis": "V", "x": cell.x, "y": cell.y}
	return {"axis": "V", "x": cell.x + 1, "y": cell.y}


func _make_door_data(inside_cell: Vector2i, outward: Vector2i, room_id: int) -> Dictionary:
	return {"inside_cell": inside_cell, "outside_cell": inside_cell + outward, "outward": outward, "room_id": room_id}


func _edge_key_from_door(door: Dictionary) -> String:
	return _edge_key(_edge_from_cell_direction(door["inside_cell"], door["outward"]))


func _edge_key(edge: Dictionary) -> String:
	if edge.is_empty():
		return "none"
	return "%s:%d:%d" % [edge["axis"], edge["x"], edge["y"]]


func _hinge_side_for_edge(edge: Dictionary) -> String:
	# Deterministic per physical edge so the same seed always has the same
	# hinge orientation, without consuming layout RNG during rendering.
	var coordinate := int(edge.get("x", 0)) + int(edge.get("y", 0))
	return "left" if posmod(coordinate, 2) == 0 else "right"


func _edge_world_position(edge: Dictionary) -> Vector3:
	if String(edge["axis"]) == "H":
		return Vector3(float(edge["x"]), 0.0, float(edge["y"]) - 0.5)
	return Vector3(float(edge["x"]) - 0.5, 0.0, float(edge["y"]))


func _door_opening_center_world_position(edge: Dictionary) -> Vector3:
	# Generated macro connections carry the complete discrete opening profile.
	# Use that profile as the positional authority so even-width (four-cell)
	# doors cannot drift by one cell when an ambiguous anchor is reused.
	var profile_variant: Variant = edge.get("opening_profile", [])
	var normal_variant: Variant = edge.get("opening_normal", Vector2i.ZERO)
	if profile_variant is Array and normal_variant is Vector2i:
		var profile: Array = profile_variant
		var normal: Vector2i = normal_variant
		if not profile.is_empty() and normal != Vector2i.ZERO:
			var accumulated := Vector3.ZERO
			var valid_count: int = 0
			for cell_variant in profile:
				if not cell_variant is Vector2i:
					continue
				var profile_cell: Vector2i = cell_variant
				var profile_edge: Dictionary = _edge_from_cell_direction(profile_cell, normal)
				accumulated += _edge_world_position(profile_edge)
				valid_count += 1
			if valid_count > 0:
				return accumulated / float(valid_count)
	var center := _edge_world_position(edge)
	var opening_cells := float(edge.get("opening_cells", DOOR_OPENING_CELLS))
	var tangent_offset := (opening_cells - 1.0) * 0.5
	if String(edge["axis"]) == "H":
		center.x += tangent_offset
	else:
		center.z += tangent_offset
	return center


func _door_root_world_position(edge: Dictionary) -> Vector3:
	# Root is the opening centre; hinge side only changes door-local transforms.
	return _door_opening_center_world_position(edge)


func _edge_gameplay_position(edge: Dictionary) -> Vector2:
	var world_position := _edge_world_position(edge)
	return Vector2(world_position.x, world_position.z) * CELL_PIXELS


# -----------------------------------------------------------------------------
# Runtime content bridge
# -----------------------------------------------------------------------------

func _spawn_random_content() -> void:
	var content_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("spawn_random_content_calls")
	if furniture_root != null:
		furniture_root.add_to_group(&"furniture_root")
	if ground_debris_root != null:
		ground_debris_root.add_to_group(&"ground_debris_root")
	_content_rng.seed = int(active_seed) ^ 0x51A7C0DE
	# Build encounter descriptions first. Their room-local RNG keeps exact
	# placements independent of room visit order during full-floor spawning.
	var plan_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_build_room_encounter_plans()
	_startup_profile_record_time("build_room_encounter_plans_ms", plan_started_usec)
	# Materialize each room exactly once. Room-local RNG still makes placement
	# independent of visit order, while distant actors and drops stay live.
	var full_content_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_spawn_ambient_debris()
	_spawn_room_furniture(-1)
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id >= 0 and room_id != spawn_room_id and _is_combat_room(room):
			_spawn_room_encounter(room_id)
	_startup_profile_record_time("spawn_non_lazy_content_ms", full_content_started_usec)
	_startup_profile_record_time("spawn_random_content_total_ms", content_started_usec)


func _is_elevator_or_corridor_room(room_id: int) -> bool:
	if room_id < 0 or room_id >= rooms.size():
		return false
	if room_id == elevator_room_id or room_id == spawn_room_id:
		return true
	var room: Dictionary = rooms[room_id]
	var r_type: StringName = StringName(room.get("room_type", &""))
	var arch: String = String(room.get("archetype", ""))
	if r_type in [&"elevator_lobby", &"corridor", &"spawn", &"start"]:
		return true
	if arch in ["elevator_lobby", "corridor", "spawn", "start"]:
		return true
	return false


func _is_combat_room(room: Dictionary) -> bool:
	var r_id: int = int(room.get("id", -1))
	if r_id >= 0 and _is_elevator_or_corridor_room(r_id):
		return false
	if room.has("combat_room"):
		return bool(room.get("combat_room", false))
	if room.has("encounter_type"):
		return StringName(room.get("encounter_type", &"")) == &"combat"
	var room_type: StringName = room.get("room_type", &"normal")
	return room_type in [&"normal", &"key", &"large_office", &"small_office"] and room_type not in [&"spawn", &"start", &"boss", &"empty", &"transition", &"elevator_lobby", &"corridor", &"reception", &"main_lobby"]


func _room_enemy_minimum(room: Dictionary) -> int:
	if _is_otxo_mansion():
		match String(room.get("archetype", "")):
			"open_office": return 3
			"conference_large", "archive", "server": return 2
			"pantry", "restroom", "printing", "reception", "corridor": return 0
			_: return 1
	match StringName(room.get("size_class", &"small")):
		&"large":
			return 12
		&"medium":
			return 6
		_:
			return 3


func _effective_room_enemy_max(room: Dictionary) -> int:
	if _is_otxo_mansion():
		match String(room.get("archetype", "")):
			"open_office": return 3
			"conference_large", "archive", "server": return 2
			"pantry", "restroom", "lounge", "printing": return 1
			"reception", "corridor": return 0
			_: return 2
	return maxi(max_enemies_per_room, _room_enemy_minimum(room))


func _stable_u32_mix(value: int) -> int:
	# Keep the seed protocol explicit and platform-independent.  Every operation
	# is reduced to an unsigned 32-bit value, while the multipliers stay within
	# the signed 64-bit product range used by Godot's integer implementation.
	var mixed := value & 0xFFFFFFFF
	mixed = (mixed ^ (mixed >> 16)) & 0xFFFFFFFF
	mixed = (mixed * 0x045D9F3B) & 0xFFFFFFFF
	mixed = (mixed ^ (mixed >> 16)) & 0xFFFFFFFF
	mixed = (mixed * 0x045D9F3B) & 0xFFFFFFFF
	mixed = (mixed ^ (mixed >> 16)) & 0xFFFFFFFF
	return mixed


func _derive_room_encounter_seed(room_id: int) -> int:
	# Room ids are assigned by the deterministic macro graph and remain stable
	# for a given Dungeon seed.  Do not use object ids, Dictionary hashes, or the
	# mutable global _content_rng state here.
	var room_component := ((room_id + 1) * 0x9E3779B9) & 0xFFFFFFFF
	var version_component := (ENCOUNTER_GENERATION_VERSION * 0x27D4EB2D) & 0xFFFFFFFF
	var mixed := (int(active_seed) & 0xFFFFFFFF) ^ ENCOUNTER_SEED_SALT ^ room_component ^ version_component
	return maxi(_stable_u32_mix(mixed), 1)


func _room_drop_base_count(room: Dictionary) -> int:
	return clampi(3 + int(room.get("usable_cells", []).size() / 180), 3, 6)


func _procedural_drop_entries(
	room_id: int,
	room: Dictionary,
	occupied: Array[Vector2],
	encounter_rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var combat_room := _is_combat_room(room)
	var is_otxo := _is_otxo_mansion()
	var base_count := _room_drop_base_count(room)
	var base_types: Array[StringName] = []
	for drop_index in range(base_count):
		var is_weapon := false if is_otxo else (combat_room and (drop_index == 0 or (drop_index > 1 and encounter_rng.randf() < 0.5)))
		base_types.append(&"weapon" if is_weapon else &"furniture")
	# Duplicate each formal base item, so Weapon and Furniture counts each double
	# independently rather than merely doubling one mixed total budget.
	for base_index in range(base_types.size()):
		for copy_index in range(2):
			var drop_position := _descriptor_room_position(room_id, 12.0, occupied, encounter_rng)
			if drop_position == Vector2.INF:
				return result
			occupied.append(drop_position)
			var sequence_index := base_index * 2 + copy_index
			if base_types[base_index] == &"weapon":
				var weapon_pool: Array[String] = []
				for candidate in WEAPON_VISUALS.get_weapon_ids():
					if candidate != "books":
						weapon_pool.append(candidate)
				result.append({
					"type": &"weapon",
					"weapon_id": weapon_pool[encounter_rng.randi_range(0, weapon_pool.size() - 1)],
					"skin_index": 0,
					"ground_position": drop_position,
					"drop_height": encounter_rng.randf_range(72.0, 112.0),
					"delay": 0.10 + float(sequence_index) * 0.14,
				})
			else:
				result.append({
					"type": &"furniture",
					"scene_path": FURNITURE_SCENE_PATHS[encounter_rng.randi_range(0, FURNITURE_SCENE_PATHS.size() - 1)],
					"ground_position": drop_position,
					"drop_height": encounter_rng.randf_range(72.0, 112.0),
					"delay": 0.10 + float(sequence_index) * 0.14,
				})
	return result


func _has_badge_carrier_candidate() -> bool:
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		if room_id < 0 or room_id == spawn_room_id or not _is_combat_room(room):
			continue
		var planned_enemy_count := 0
		if _is_otxo_mansion():
			var encounter_rng := RandomNumberGenerator.new()
			encounter_rng.seed = _derive_room_encounter_seed(room_id)
			planned_enemy_count = encounter_rng.randi_range(
				_room_enemy_minimum(room),
				_effective_room_enemy_max(room)
			)
		else:
			planned_enemy_count = clampi(
				maxi(
					roundi(float(room.get("usable_cells", []).size()) * enemy_density),
					_room_enemy_minimum(room)
				),
				_room_enemy_minimum(room),
				_effective_room_enemy_max(room)
			)
		if planned_enemy_count > 0:
			return true
	return false


func _build_room_encounter_plans() -> void:
	if _count_activated_encounters() > 0:
		return
	room_encounters.clear()
	room_layout_plans.clear()
	badge_carrier_room_id = -1
	badge_carrier_spawn_index = -1
	badge_drop_committed = false
	badge_drop_pending = false
	var initial_enemy_budget := 0
	for room_variant in rooms:
		var budget_room: Dictionary = room_variant
		if _is_combat_room(budget_room) and int(budget_room.get("id", -1)) != spawn_room_id:
			initial_enemy_budget += _effective_room_enemy_max(budget_room)
	effective_global_enemy_cap = maxi(global_enemy_cap, initial_enemy_budget)
	initial_enemy_budget = maxi(initial_enemy_budget, 0)
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		var eligible_for_encounter := room_id >= 0 and room_id != spawn_room_id and not _is_elevator_or_corridor_room(room_id)
		var planned_enemies := 0
		var planned_drops := 0
		if eligible_for_encounter:
			var combat_room := _is_combat_room(room)
			if _is_otxo_mansion():
				var enc_rng := RandomNumberGenerator.new()
				enc_rng.seed = _derive_room_encounter_seed(room_id)
				planned_enemies = enc_rng.randi_range(_room_enemy_minimum(room), _effective_room_enemy_max(room)) if combat_room else 0
			else:
				planned_enemies = clampi(
					maxi(roundi(float(room.get("usable_cells", []).size()) * enemy_density), _room_enemy_minimum(room)) if combat_room else 0,
					_room_enemy_minimum(room) if combat_room else 0,
					_effective_room_enemy_max(room) if combat_room else 0
				)
			planned_drops = (_room_drop_base_count(room) * 2) if combat_room else 0
		if bool(room.get("authored_sample", false)):
			planned_enemies = preload("res://scripts/dream/office_sample_floor.gd").enemy_specs(String(room.sample_key)).size()
			planned_drops = 0
		room_encounters[room_id] = {
			"encounter_generation_version": ENCOUNTER_GENERATION_VERSION,
			"encounter_seed": _derive_room_encounter_seed(room_id),
			"planned_enemy_count": planned_enemies,
			"planned_drop_count": planned_drops,
			"resolution_state": &"UNRESOLVED",
			"resolved": false,
			"enemy_spawns": [],
			"drop_spawns": [],
			"activated": false,
			"completed": false,
			"spawned_enemy_ids": [],
		}
	_select_badge_carrier_slot()


func _derive_badge_carrier_seed() -> int:
	var floor_component := ((floor_index + 1) * 0x9E3779B9) & 0xFFFFFFFF
	var mixed := (int(base_floor_seed) & 0xFFFFFFFF) ^ FLOOR_SEED_SALT ^ BADGE_CARRIER_SALT ^ floor_component
	return maxi(_stable_u32_mix(mixed), 1)


func _derive_enemy_equip_seed(room_id: int, entry_index: int) -> int:
	var floor_component := ((floor_index + 1) * 0x9E3779B9) & 0xFFFFFFFF
	var mixed := (
		(int(base_floor_seed) & 0xFFFFFFFF)
		^ FLOOR_SEED_SALT
		^ floor_component
		^ (int(room_id * 80537) & 0xFFFFFFFF)
		^ (int(entry_index * 13337) & 0xFFFFFFFF)
	)
	return maxi(_stable_u32_mix(mixed), 1)


func _employee_weapon_pool() -> Array[String]:
	var pool: Array[String] = []
	for candidate in WEAPON_VISUALS.get_weapon_ids():
		if candidate != "books" and _is_pickup_weapon_id_allowed(candidate):
			pool.append(candidate)
	if pool.is_empty():
		pool.append("basic")
	return pool


func _select_badge_carrier_slot() -> void:
	"""Select one planned Employee without consuming encounter RNG streams."""
	badge_carrier_room_id = -1
	badge_carrier_spawn_index = -1
	var candidates: Array[Vector2i] = []
	var heavy_candidates: Array[Vector2i] = []
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_id := int(room.get("id", -1))
		var r_type := StringName(room.get("room_type", &""))
		if room_id < 0 or room_id == spawn_room_id or r_type in [&"elevator_lobby", &"corridor", &"reception", &"main_lobby"] or room_id == elevator_room_id or not _is_combat_room(room):
			continue
		var encounter_variant: Variant = room_encounters.get(room_id, {})
		var planned := int((encounter_variant as Dictionary).get("planned_enemy_count", 0)) if encounter_variant is Dictionary else 0
		var is_heavy: bool = String(room.get("planned_role", "")) == "heavy_guard"
		for spawn_index in range(maxi(planned, 0)):
			var c := Vector2i(room_id, spawn_index)
			candidates.append(c)
			if is_heavy:
				heavy_candidates.append(c)
	var pool := heavy_candidates if not heavy_candidates.is_empty() else candidates
	if pool.is_empty():
		return
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	var carrier_rng := RandomNumberGenerator.new()
	carrier_rng.seed = _derive_badge_carrier_seed()
	var selected := pool[carrier_rng.randi_range(0, pool.size() - 1)]
	badge_carrier_room_id = selected.x
	badge_carrier_spawn_index = selected.y


## Compatibility name for tools that used the old private helper.  It now builds
## only lightweight plans; detailed entries are resolved per room on activation.
func _build_room_encounter_descriptors() -> void:
	_build_room_encounter_plans()


func _descriptor_room_position(
	room_id: int,
	radius: float,
	occupied: Array[Vector2],
	encounter_rng: RandomNumberGenerator
) -> Vector2:
	if room_id < 0 or room_id >= rooms.size():
		return Vector2.INF
	var clearance := maxf(content_wall_clearance, radius + 8.0)
	var bounds := _room_bounds_pixels(room_id, clearance)
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		bounds = _room_bounds_pixels(room_id, maxf(8.0, radius))
	var candidates: Array[Vector2] = []
	var usable: Array = rooms[room_id].get("usable_cells", [])
	for cell_variant in usable:
		var cell: Vector2i = cell_variant
		if reserved_content_cells.has(cell):
			continue
		var candidate := Vector2(cell) * CELL_PIXELS
		if bounds.size.x > 1.0 and bounds.size.y > 1.0 and not bounds.has_point(candidate):
			continue
		if not floor_cells.has(cell) or int(room_cells.get(cell, -1)) != room_id:
			continue
		if _position_near_any_door(candidate, maxf(24.0, radius + 8.0)):
			continue
		var too_close := false
		for other in occupied:
			if candidate.distance_to(other) < radius + 22.0:
				too_close = true
				break
		if too_close:
			continue
		candidates.append(candidate)
	if candidates.is_empty():
		for cell_variant in usable:
			var cell: Vector2i = cell_variant
			if (
				not floor_cells.has(cell)
				or int(room_cells.get(cell, -1)) != room_id
				or corridor_cells.has(cell)
			):
				continue
			var candidate := Vector2(cell) * CELL_PIXELS
			if bounds.size.x > 1.0 and bounds.size.y > 1.0 and not bounds.has_point(candidate):
				continue
			var too_close := false
			for other in occupied:
				if candidate.distance_to(other) < radius + 16.0:
					too_close = true
					break
			if not too_close:
				candidates.append(candidate)
	if candidates.is_empty():
		return Vector2.INF
	return candidates[encounter_rng.randi_range(0, candidates.size() - 1)]


func _resolve_room_encounter_descriptor(room_id: int) -> bool:
	if room_id < 0 or room_id >= rooms.size():
		return false
	var encounter: Dictionary = room_encounters.get(room_id, {})
	# `generate_layout_only()` intentionally remains a pure layout entry point and
	# does not build content plans.  Direct callers that activate a generated
	# world still get the same plan authority as the normal regenerate path.
	if encounter.is_empty() or not encounter.has("encounter_seed"):
		# Never rebuild the plan table after an encounter has already been
		# activated; that would erase its cached lifecycle state.
		if _count_activated_encounters() > 0:
			return false
		_build_room_encounter_plans()
		encounter = room_encounters.get(room_id, {})
	if encounter.is_empty():
		return false
	if bool(encounter.get("resolved", false)):
		return true
	var resolve_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("encounter_resolve_calls")
	var encounter_rng := RandomNumberGenerator.new()
	var fallback_seed := _derive_room_encounter_seed(room_id)
	encounter_rng.seed = maxi(int(encounter.get("encounter_seed", fallback_seed)), 1)
	var enemy_entries: Array[Dictionary] = []
	var drop_entries: Array[Dictionary] = []
	var room: Dictionary = rooms[room_id]
	var eligible_for_encounter := room_id != spawn_room_id and room_id != boss_room_id
	if eligible_for_encounter:
		var planned_enemies := maxi(int(encounter.get("planned_enemy_count", 0)), 0)
		var occupied: Array[Vector2] = []
		var is_otxo := _is_otxo_mansion()
		var plan: Dictionary = _plan_otxo_room_layout(room_id) if is_otxo else {}

		if is_otxo and bool(plan.get("success", false)):
			var planned_spawns: Array = plan.get("enemy_spawns", [])
			for i in range(mini(planned_enemies, planned_spawns.size())):
				var sp: Dictionary = planned_spawns[i]
				var pos: Vector2 = sp.get("ground_position", Vector2.ZERO)
				var enemy_type: StringName = sp.get("type", &"employee")
				enemy_entries.append(sp.duplicate(true))
				occupied.append(pos)
			if enemy_entries.size() < planned_enemies:
				for _extra in range(planned_enemies - enemy_entries.size()):
					var enemy_position := _descriptor_room_position(room_id, 10.0, occupied, encounter_rng)
					if enemy_position == Vector2.INF:
						break
					var enemy_type: StringName = &"waitress" if encounter_rng.randf() < 0.35 else &"employee"
					enemy_entries.append({"type": enemy_type, "ground_position": enemy_position})
					occupied.append(enemy_position)

			var planned_drops: Array = plan.get("drop_spawns", [])
			if not planned_drops.is_empty() and not _is_otxo_mansion():
				var weapon_pool: Array[String] = []
				for candidate in WEAPON_VISUALS.get_weapon_ids():
					if candidate != "books":
						weapon_pool.append(candidate)
				if weapon_pool.is_empty():
					weapon_pool.append("basic")
				for i in range(planned_drops.size()):
					var dr: Dictionary = planned_drops[i]
					var drop_pos: Vector2 = dr.get("ground_position", Vector2.ZERO)
					occupied.append(drop_pos)
					drop_entries.append({
						"type": &"weapon",
						"weapon_id": weapon_pool[encounter_rng.randi_range(0, weapon_pool.size() - 1)],
						"skin_index": 0,
						"ground_position": drop_pos,
						"drop_height": 0.0,
						"delay": 0.0,
					})
			elif not bool(room.get("office_combat_layout", false)):
				drop_entries = _procedural_drop_entries(room_id, room, occupied, encounter_rng)
		else:
			for _index in range(planned_enemies):
				var enemy_position := _descriptor_room_position(room_id, 10.0, occupied, encounter_rng)
				if enemy_position == Vector2.INF:
					break
				var enemy_type: StringName = &"waitress" if encounter_rng.randf() < 0.35 else &"employee"
				enemy_entries.append({"type": enemy_type, "ground_position": enemy_position})
				occupied.append(enemy_position)
			drop_entries = _procedural_drop_entries(room_id, room, occupied, encounter_rng)
	if _is_otxo_mansion() and String(room.get("archetype", "")) == "corridor":
		drop_entries.clear()
	for entry_index in range(enemy_entries.size()):
		var entry: Dictionary = enemy_entries[entry_index]
		if _is_otxo_mansion():
			var archetype := String(room.get("archetype", ""))
			if archetype == "corridor":
				var corridor_route := _office_corridor_patrol_route(room)
				if not corridor_route.is_empty():
					entry["ground_position"] = corridor_route[0]
					entry["patrol_route"] = corridor_route
			if not bool(room.get("authored_sample", false)):
				entry["initial_facing"] = _office_initial_facing(room_id, entry.get("ground_position", Vector2.ZERO))
			if archetype == "open_office" and entry_index == 0 and not bool(room.get("authored_sample", false)):
				entry["patrol_route"] = _office_patrol_route(room, entry.get("ground_position", Vector2.ZERO))
			# The room plan owns loadout roles.  Archive and server security are
			# ordinary armed employees, not a new heavy-stat archetype.
			entry["type"] = &"employee"
			if archetype == "corridor" or (archetype == "open_office" and entry_index == 0):
				entry["weapon_id"] = "lucille"
			elif archetype in ["pantry", "restroom"]:
				entry["weapon_id"] = "books"
			else:
				var role_rng := RandomNumberGenerator.new()
				role_rng.seed = _derive_enemy_equip_seed(room_id, entry_index)
				var firearms: Array[String] = []
				for candidate in _employee_weapon_pool():
					if WEAPON_VISUALS.has_firearm(candidate):
						firearms.append(candidate)
				entry["weapon_id"] = firearms[role_rng.randi_range(0, firearms.size() - 1)] if not firearms.is_empty() else "basic"
		entry["badge_carrier"] = room_id == badge_carrier_room_id and entry_index == badge_carrier_spawn_index
		var etype: StringName = StringName(entry.get("type", &"employee"))
		if not entry.has("weapon_id") or String(entry.get("weapon_id", "")).is_empty():
			if etype == &"waitress":
				entry["weapon_id"] = "books"
				entry["skin_index"] = 0
			elif _is_otxo_mansion():
				var equip_rng := RandomNumberGenerator.new()
				equip_rng.seed = _derive_enemy_equip_seed(room_id, entry_index)
				var pool := _employee_weapon_pool()
				entry["weapon_id"] = pool[equip_rng.randi_range(0, pool.size() - 1)]
				entry["skin_index"] = 0
		enemy_entries[entry_index] = entry
	encounter["enemy_spawns"] = enemy_entries
	encounter["drop_spawns"] = drop_entries
	encounter["resolved_enemy_count"] = enemy_entries.size()
	encounter["resolved_drop_count"] = drop_entries.size()
	encounter["resolution_state"] = &"RESOLVED"
	encounter["resolved"] = true
	room_encounters[room_id] = encounter
	_startup_profile_increment("encounter_resolved_rooms")
	_startup_profile_record_time("resolve_room_encounter_ms", resolve_started_usec)
	_startup_profile_record_time("resolve_room_encounter_room_%d_ms" % room_id, resolve_started_usec)
	if _startup_profile_enabled:
		# Resolution happens after the initial startup report for most rooms.  Emit
		# a profiler snapshot at this boundary so first-entry cost remains
		# observable without adding a gameplay dependency.
		_startup_profile_emit("encounter_resolve_room_%d" % room_id)
	return true


func _office_patrol_route(room: Dictionary, origin: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var rect: Rect2i = room.get("grid_rect", Rect2i())
	if rect.size.x < 8 or rect.size.y < 5:
		return route
	var middle_y := clampf(origin.y, float(rect.position.y + 2) * CELL_PIXELS, float(rect.end.y - 2) * CELL_PIXELS)
	route.append(Vector2(float(rect.position.x + 2) * CELL_PIXELS, middle_y))
	route.append(Vector2(float(rect.end.x - 2) * CELL_PIXELS, middle_y))
	return route


func _office_corridor_patrol_route(room: Dictionary) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var rect: Rect2i = room.get("grid_rect", Rect2i())
	if rect.size.x < 14:
		return route
	var left_x := rect.position.x + 2
	var right_x := rect.end.x - 3
	var lift_x := elevator_anchor_cell.x
	if absi(lift_x - left_x) > absi(right_x - lift_x):
		right_x = mini(right_x, lift_x - 6)
	else:
		left_x = maxi(left_x, lift_x + 6)
	if right_x - left_x < 4:
		return route
	var y := float(rect.position.y + 1) * CELL_PIXELS
	route.append(Vector2(float(left_x) * CELL_PIXELS, y))
	route.append(Vector2(float(right_x) * CELL_PIXELS, y))
	return route


func _office_initial_facing(room_id: int, origin: Vector2) -> Vector2:
	for connection_variant in connections:
		var connection: Dictionary = connection_variant
		if int(connection.get("a", -1)) != room_id and int(connection.get("b", -1)) != room_id:
			continue
		var door_position := _edge_gameplay_position(connection.get("door_edge", {}))
		var direction := origin.direction_to(door_position)
		if direction.length_squared() > 0.01:
			return direction
	return Vector2.DOWN


func activate_room(room_id: int) -> bool:
	if room_id < 0 or room_id >= rooms.size():
		return false
	# Room activation is committed by an explicit transition trigger.  Keeping
	# this guard here also makes direct callers (initial spawn/tests) establish
	# the same presentation/physics gate without reviving coordinate-driven
	# cross-room switching.
	if current_room_id != room_id:
		set_current_room_id(room_id)
		# Explicit transition commits normally rebuild before calling activate_room.
		# Keep direct callers (editor tools and deterministic probes) correct too:
		# changing the active room must materialize its bounded presentation rather
		# than merely toggling the runtime gate on the old room.
		if lazy_room_presentation:
			_rebuild_active_room_presentation()
	# Exploration is not an instantiation boundary; all room content exists.
	if room_visibility != null and is_instance_valid(room_visibility) and room_visibility.has_method("reveal_room"):
		room_visibility.call("reveal_room", room_id)
	# Corridor visibility is a direct graph property of the active room, not of
	# the transient room/corridor boundary the player currently occupies.  Keep
	# this assertion outside the first-activation branch so returning to an
	# already explored room restores every attached corridor as well.
	_reveal_connected_corridors_for_room(room_id)
	var previous_state: StringName = room_states.get(room_id, &"UNSEEN")
	if previous_state == &"UNSEEN":
		# A room activation reveals only the corridors directly attached to that
		# room.  This is deliberately a one-hop graph operation: neighbouring room
		# covers remain hidden until the player actually enters them, while the
		# corridor presentation, fog cover and minimap all consume this same state.
		room_states[room_id] = &"ACTIVE"
		rooms[room_id]["state"] = &"ACTIVE"
		rooms[room_id]["revealed"] = true
		rooms[room_id]["activated"] = true
		_spawn_room_encounter(room_id)
	else:
		_set_room_content_active(room_id, true)
	if _count_room_enemies(room_id) <= 0 and room_id != spawn_room_id and room_id != boss_room_id and _is_combat_room(rooms[room_id]):
		mark_room_cleared(room_id)
	# Completed rooms may be re-entered after their original clear event.  Reuse
	# the persisted Room state to restore every legal exit arrow without creating
	# duplicate presentation nodes.
	_update_dungeon_minimap_room_state(room_id)
	return true


func reveal_room(room_id: int) -> void:
	if room_id < 0 or room_id >= rooms.size():
		return
	rooms[room_id]["revealed"] = true
	if room_states.get(room_id, &"UNSEEN") == &"UNSEEN":
		room_states[room_id] = &"UNSEEN"
	_update_dungeon_minimap_room_state(room_id)


func reveal_corridor(corridor_id: int, source_room_id: int = -1) -> void:
	if corridor_id < 0:
		return
	if corridor_states.has(corridor_id):
		corridor_states[corridor_id] = &"REVEALED"
		for corridor_variant in corridors:
			var corridor: Dictionary = corridor_variant
			if int(corridor.get("id", -1)) == corridor_id:
				corridor["state"] = &"REVEALED"
				corridor["revealed"] = true
				break
	if room_visibility != null and is_instance_valid(room_visibility) and room_visibility.has_method("reveal_corridor"):
		room_visibility.call("reveal_corridor", corridor_id, source_room_id)
	_update_dungeon_minimap_corridor_state(corridor_id)


func _reveal_connected_corridors_for_room(room_id: int) -> void:
	if room_id < 0:
		return
	for connection_variant in connections:
		if not (connection_variant is Dictionary):
			continue
		var connection: Dictionary = connection_variant
		var a_id := int(connection.get("a", -1))
		var b_id := int(connection.get("b", -1))
		if a_id != room_id and b_id != room_id:
			continue
		var corridor_id := int(connection.get("corridor_id", -1))
		if corridor_id >= 0:
			# Reveal only the endpoint stub that belongs to this room; the opposite
			# endpoint stays isolated until that room is entered.
			reveal_corridor(corridor_id, room_id)


func get_room_state(room_id: int) -> StringName:
	return room_states.get(room_id, &"UNSEEN") as StringName


func is_room_revealed(room_id: int) -> bool:
	return bool(rooms[room_id].get("revealed", false)) if room_id >= 0 and room_id < rooms.size() else false


func mark_room_cleared(room_id: int) -> void:
	# The entrance room is a safe staging area rather than a combat encounter.
	# Keep it ACTIVE for the lifetime of the run even when its empty descriptor
	# is activated during visibility setup; otherwise the initial reveal would
	# immediately turn the player's starting room into CLEARED.
	if room_id < 0 or room_id >= rooms.size() or room_id == boss_room_id or room_id == spawn_room_id:
		return
	if _get_alive_employee_count_in_room(room_id) > 0:
		return
	room_states[room_id] = &"CLEARED"
	rooms[room_id]["state"] = &"CLEARED"
	rooms[room_id]["cleared"] = true
	_update_dungeon_minimap_room_state(room_id)
	var encounter: Dictionary = room_encounters.get(room_id, {})
	if not encounter.is_empty():
		encounter["completed"] = true
		encounter["resolution_state"] = &"COMPLETED"
		room_encounters[room_id] = encounter


func _room_clear_arrow_exists(room_id: int, connection_id: int = -1) -> bool:
	if world_effects_root == null:
		return false
	for child in world_effects_root.get_children():
		if not child.has_meta(&"room_clear_arrow") or not bool(child.get_meta(&"room_clear_arrow", false)):
			continue
		if child.is_queued_for_deletion():
			continue
		if int(child.get_meta(&"dream_room_id", -1)) != room_id:
			continue
		if connection_id >= 0 and int(child.get_meta(&"connection_id", -1)) != connection_id:
			continue
		return true
	return false


func _clear_room_clear_arrows(room_id: int = -1, connection_id: int = -1) -> void:
	if world_effects_root == null:
		return
	for child in world_effects_root.get_children():
		if not child.has_meta(&"room_clear_arrow") or not bool(child.get_meta(&"room_clear_arrow", false)):
			continue
		if room_id >= 0 and int(child.get_meta(&"dream_room_id", -1)) != room_id:
			continue
		if connection_id >= 0 and int(child.get_meta(&"connection_id", -1)) != connection_id:
			continue
		child.queue_free()


func _ensure_room_clear_arrows(room_id: int) -> void:
	# Kept as a compatibility hook for tools that call the old helper.  Room
	# clear is still recorded above, but Random3D no longer creates per-door exit
	# arrows; the Elevator and Employee Badge are the only progression markers.
	_clear_room_clear_arrows(room_id)


func _spawn_room_encounter(room_id: int) -> void:
	if not spawn_content:
		_set_room_content_active(room_id, true)
		return
	if not _resolve_room_encounter_descriptor(room_id):
		_set_room_content_active(room_id, true)
		return
	var encounter: Dictionary = room_encounters.get(room_id, {})
	if encounter.is_empty() or bool(encounter.get("activated", false)):
		_set_room_content_active(room_id, true)
		return
	encounter["activated"] = true
	encounter["resolution_state"] = &"ACTIVATED"
	room_encounters[room_id] = encounter
	var generation_token := _layout_generation
	var spawned_enemies: Array = []
	for entry_variant in encounter.get("enemy_spawns", []):
		var entry: Dictionary = entry_variant
		if enemy_count >= effective_global_enemy_cap:
			break
		var enemy_type: StringName = StringName(entry.get("type", &"employee"))
		var is_badge_carrier := bool(entry.get("badge_carrier", false))
		var weapon_id: String = String(entry.get("weapon_id", ""))
		var skin_index: int = int(entry.get("skin_index", 0))
		var employee := _spawn_regular_employee(room_id, entry.get("ground_position", Vector2.ZERO), enemy_type, is_badge_carrier, weapon_id, skin_index)
		if employee == null:
			continue
		var patrol_route: Array[Vector2] = []
		for waypoint in entry.get("patrol_route", []):
			patrol_route.append(Vector2(waypoint))
		if not patrol_route.is_empty():
			employee.set_authored_patrol_route(patrol_route)
		var initial_facing: Vector2 = entry.get("initial_facing", Vector2.ZERO)
		if initial_facing.length_squared() > 0.01:
			employee.last_facing_direction = initial_facing.normalized()
		employee.set_room_runtime_active(true)
		spawned_enemies.append(employee.get_instance_id())
	encounter["spawned_enemy_ids"] = spawned_enemies
	room_encounters[room_id] = encounter
	_set_room_content_active(room_id, true)
	for entry_variant in encounter.get("drop_spawns", []):
		var drop: Dictionary = entry_variant
		var delay := maxf(float(drop.get("delay", 0.0)), 0.0)
		if _is_otxo_mansion() or delay <= 0.0:
			_spawn_room_drop(room_id, drop, generation_token)
		else:
			get_tree().create_timer(delay).timeout.connect(_spawn_room_drop.bind(room_id, drop, generation_token), CONNECT_ONE_SHOT)
	if spawned_enemies.is_empty():
		mark_room_cleared(room_id)


func _spawn_room_drop(room_id: int, drop: Dictionary, generation_token: int = -1) -> void:
	if not is_inside_tree() or room_id < 0 or room_id >= rooms.size():
		return
	if generation_token >= 0 and generation_token != _layout_generation:
		return
	var ground_position: Vector2 = drop.get("ground_position", Vector2.ZERO)
	if not _is_valid_room_content_position(ground_position, room_id):
		return
	if StringName(drop.get("type", &"")) == &"weapon":
		if world_weapon_root == null or WORLD_WEAPON_SCENE == null:
			return
		var pickup := WORLD_WEAPON_SCENE.instantiate() as Node2D
		if pickup == null:
			return
		pickup.position = ground_position
		pickup.global_position = ground_position
		world_weapon_root.add_child(pickup)
		if pickup is CollisionObject2D:
			PhysicsServer2D.body_set_state(pickup.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, ground_position))
		var weapon_id := String(drop.get("weapon_id", "basic"))
		var skin_index := int(drop.get("skin_index", 0))
		if pickup.has_method("set_weapon_id"):
			pickup.call("set_weapon_id", weapon_id, skin_index)
		else:
			pickup.set("weapon_id", weapon_id)
			pickup.set("skin_index", skin_index)
		pickup.set("interaction_radius", EMPLOYEE_CONFIG.world_weapon_interaction_radius)
		pickup.set("mass", WEAPON_VISUALS.get_world_mass(weapon_id))
		pickup.set_meta(&"dream_room_id", room_id)
		pickup.set_meta(&"content_kind", &"encounter_weapon_drop")
		if not _is_otxo_mansion() and pickup.has_method("start_sky_drop"):
			pickup.call("start_sky_drop", float(drop.get("drop_height", 96.0)))
		_spawn_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])
		if pickup.has_method("set_room_runtime_active"):
			pickup.call("set_room_runtime_active", _is_otxo_mansion() or room_id == current_room_id)
		_notify_room_weapon_available(room_id)
	else:
		var scene_path := String(drop.get("scene_path", ""))
		var furniture_scene := load(scene_path) as PackedScene
		if furniture_root == null or furniture_scene == null:
			return
		var furniture := furniture_scene.instantiate() as Node2D
		if furniture == null:
			return
		furniture.position = ground_position
		furniture.global_position = ground_position
		furniture_root.add_child(furniture)
		if furniture is CollisionObject2D:
			PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, ground_position))
			if furniture is RigidBody2D:
				PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
				PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		furniture.set_meta(&"dream_room_id", room_id)
		furniture.set_meta(&"content_kind", &"encounter_furniture_drop")
		if furniture.has_method("reset_spawn_physics"):
			furniture.call("reset_spawn_physics")
		if not _is_otxo_mansion() and furniture.has_method("start_sky_drop"):
			furniture.call("start_sky_drop", float(drop.get("drop_height", 96.0)))
		furniture_count += 1
		_spawn_furniture_presentation(furniture)
		if furniture.has_method("set_room_runtime_active"):
			furniture.call("set_room_runtime_active", _is_otxo_mansion() or room_id == current_room_id)


func _notify_room_weapon_available(room_id: int) -> void:
	if enemy_root == null:
		return
	for enemy_variant in enemy_root.get_children():
		var employee := enemy_variant as EmployeeEnemy
		if employee == null or not is_instance_valid(employee):
			continue
		if int(employee.get_meta(&"dream_room_id", -1)) != room_id:
			continue
		if employee.has_method("prioritize_weapon_search"):
			employee.call("prioritize_weapon_search")


func _is_valid_room_content_position(at_position: Vector2, room_id: int) -> bool:
	var cell := Vector2i(roundi(at_position.x / CELL_PIXELS), roundi(at_position.y / CELL_PIXELS))
	return int(room_cells.get(cell, -1)) == room_id and floor_cells.has(cell) and not corridor_cells.has(cell)


func _set_room_content_active(room_id: int, active: bool) -> void:
	if room_id < 0:
		return
	# Discovery no longer suspends offscreen rooms on a complete 3D floor.
	active = true
	var is_otxo := _is_otxo_mansion()
	var roots: Array[Node] = [furniture_root, enemy_root, key_root, world_weapon_root, pickup_root, ground_debris_root, world_effects_root]
	for root in roots:
		if root == null:
			continue
		for child in root.get_children():
			if int(child.get_meta(&"dream_room_id", -1)) != room_id:
				continue
			if child is EmployeeEnemy:
				child.call("set_room_runtime_active", active)
				if not active:
					child.call("set_room_preview_visible", true)
					child.call("set_player_vision_visible", true)
			elif child.has_method("set_room_runtime_active"):
				if is_otxo and root == furniture_root:
					child.call("set_room_runtime_active", true)
				else:
					child.call("set_room_runtime_active", active)
			else:
				var canvas := child as CanvasItem
				if canvas != null:
					if is_otxo and root == furniture_root:
						canvas.visible = true
					else:
						canvas.visible = active
				if child is Area2D:
					child.set_deferred("monitoring", active)
					child.set_deferred("monitorable", active)
	# Depth bridges are presentation children of a separate root.  A static
	# furniture bridge may already have frozen an empty capture while its room
	# was dormant, so room activation explicitly wakes only this room's bridges
	# after the gameplay source has become visible.  Deactivation also hides the
	# frozen Sprite3D; otherwise the bridge would keep its last frame while its
	# source is asleep and no longer ticks to observe source.visible.
	if actor_depth_bridges_root != null:
		for bridge_variant in actor_depth_bridges_root.get_children():
			var bridge := bridge_variant as Node
			if bridge == null or int(bridge.get_meta(&"dream_room_id", -1)) != room_id:
				continue
			if bridge.has_method("set_room_presentation_active"):
				bridge.call("set_room_presentation_active", active)
			elif active and bridge.has_method("request_capture_refresh"):
				bridge.call("request_capture_refresh")
	# Light holders are toggled by RoomVisibility, which owns the reveal/fog
	# state.


func _refresh_room_static_visuals(room_id: int) -> void:
	if room_id < 0 or actor_depth_bridges_root == null:
		return
	for bridge_variant in actor_depth_bridges_root.get_children():
		var bridge := bridge_variant as Node
		if bridge == null or int(bridge.get_meta(&"dream_room_id", -1)) != room_id:
			continue
		if bridge.has_method("set_room_presentation_active"):
			bridge.call("set_room_presentation_active", true)
		elif bridge.has_method("request_capture_refresh"):
			bridge.call("request_capture_refresh")


func _spawn_room_boss() -> void:
	if boss_room_id < 0 or enemy_root == null or EMPLOYEE_SCENE == null:
		return
	if lazy_room_presentation and current_room_id != boss_room_id:
		return
	if boss_enemy != null and is_instance_valid(boss_enemy):
		return
	var avoid: Array[Vector2] = []
	if player != null:
		avoid.append(player.global_position)
	var position := _random_room_position(boss_room_id, 18.0, avoid, true)
	if position == Vector2.ZERO:
		position = Vector2(rooms[boss_room_id]["center_cell"]) * CELL_PIXELS
	var elite := EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	if elite == null:
		return
	enemy_root.add_child(elite)
	elite.global_position = position
	elite.set_meta(&"dream_room_id", boss_room_id)
	elite.set_meta(&"content_kind", &"boss")
	elite.set_meta(&"enemy_type", "boss")
	var boss_health := config.base_enemy_health * config.employee_boss_health_multiplier * config.story_enemy_health_multiplier
	elite.configure(
		player,
		boss_health,
		0.0,
		_room_bounds_pixels(boss_room_id, 10.0),
		config.enemy_separation_strength,
		config.enemy_separation_radius,
		config
	)
	elite.set_room_bounds(_room_bounds_pixels(boss_room_id, 2.0))
	elite.configure_boss(true)
	elite.equip_weapon("basic")
	elite.defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
	var drop_handler := _on_employee_weapon_drop_requested.bind(elite)
	if elite.has_signal("weapon_drop_requested") and not elite.weapon_drop_requested.is_connected(drop_handler):
		elite.weapon_drop_requested.connect(drop_handler)
	boss_enemy = elite
	enemy_count += 1
	_spawn_depth_bridge(elite, [NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot")])
	_spawn_actor_physics_proxy(elite, true)
	_cache_actor_occlusion_bounds(elite)
	# Boss content is persistent but dormant until the Player enters its room.
	# Activation later only toggles this actor; it never re-instantiates or resets it.
	if elite.has_method("set_room_runtime_active"):
		elite.call("set_room_runtime_active", false)


func _spawn_wake_exit() -> void:
	if boss_room_id < 0 or key_root == null or wake_exit_root == null:
		return
	if lazy_room_presentation and current_room_id != boss_room_id:
		return
	if wake_exit_trigger != null and is_instance_valid(wake_exit_trigger):
		return
	var avoid: Array[Vector2] = []
	if boss_enemy != null and is_instance_valid(boss_enemy):
		avoid.append(boss_enemy.global_position)
	var position := _random_room_position(boss_room_id, 14.0, avoid, true)
	if position == Vector2.ZERO:
		position = Vector2(rooms[boss_room_id]["center_cell"]) * CELL_PIXELS
	wake_exit_trigger = Area2D.new()
	wake_exit_trigger.name = "BossWakeExit"
	wake_exit_trigger.position = position
	wake_exit_trigger.collision_layer = 0
	wake_exit_trigger.collision_mask = 1
	wake_exit_trigger.monitoring = false
	wake_exit_trigger.monitorable = false
	wake_exit_trigger.set_meta(&"dream_room_id", boss_room_id)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape
	wake_exit_trigger.add_child(collision)
	key_root.add_child(wake_exit_trigger)
	wake_exit_trigger.body_entered.connect(_on_wake_exit_body_entered)

	wake_exit_visual = Node3D.new()
	wake_exit_visual.name = "BossWakeExitVisual"
	wake_exit_visual.position = Vector3(position.x / CELL_PIXELS, 0.04, position.y / CELL_PIXELS)
	var marker := Label3D.new()
	marker.text = "WAKE EXIT"
	marker.modulate = Color(0.72, 0.94, 1.0, 1.0)
	marker.font_size = 26
	marker.pixel_size = 0.009
	marker.outline_size = 5
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = false
	marker.position.y = 0.18
	wake_exit_visual.add_child(marker)
	# Own root, never DoorRoot: door code iterates DoorRoot children as doors.
	wake_exit_root.add_child(wake_exit_visual)
	wake_exit_visual.visible = false


func _spawn_spawn_room_furniture() -> void:
	# Deprecated: _spawn_room_furniture() generates all rooms including spawn room.
	pass


func _on_boss_defeated(at_position: Vector2, _legacy_drop_count: int = 1) -> void:
	if boss_defeated:
		return
	_on_enemy_defeated(at_position)
	boss_defeated = true
	_activate_wake_exit()
	last_validation_report["boss_defeated"] = true
	last_validation_report["wake_exit_active"] = true


func _activate_wake_exit() -> void:
	if wake_exit_trigger != null and is_instance_valid(wake_exit_trigger):
		wake_exit_trigger.monitorable = true
		wake_exit_trigger.monitoring = true
	if wake_exit_visual != null and is_instance_valid(wake_exit_visual):
		wake_exit_visual.visible = true


func _on_wake_exit_body_entered(body: Node) -> void:
	if body == player and boss_defeated:
		_complete_wake()


func _complete_wake() -> void:
	if run_finished or not boss_defeated:
		return
	run_finished = true
	reset_hit_stop()
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	if run_interface != null and run_interface.has_method("complete_boss_layer"):
		run_interface.call("complete_boss_layer", dream_layer_id)
	dream_finished.emit(_build_run_summary("主动醒来"))


func complete_death_run() -> bool:
	if not campaign_run or run_finished:
		return false
	run_finished = true
	reset_hit_stop()
	player.movement_enabled = false
	player.set_attacking_enabled(false)
	player.set_dash_enabled(false)
	dream_finished.emit(_build_run_summary("梦中倒下"))
	return true


func restart_current_floor_after_death() -> bool:
	reset_hit_stop()
	run_finished = false
	boss_defeated = false
	has_floor_badge = false
	has_boss_key = false
	badge_drop_committed = false
	badge_drop_pending = false
	floor_transition_in_progress = false
	transition_phase = &"IDLE"
	if is_instance_valid(player) and player.has_method("revive_for_floor_restart"):
		player.call("revive_for_floor_restart", String(player.get("selected_weapon_id")), config, permanent_upgrades)
	var saved_cab_exit := enable_game_start_cab_exit
	enable_game_start_cab_exit = false
	var target_seed := active_seed if active_seed != 0 else seed
	var ok := regenerate(target_seed)
	enable_game_start_cab_exit = saved_cab_exit
	player_has_left_elevator_cab = true
	if is_instance_valid(elevator_floor_door):
		elevator_floor_door.update_state(ElevatorFloorDoor3D.State.LOCKED)
		elevator_floor_door.update_indicator(floor_index)
	if is_instance_valid(player):
		player.set("movement_enabled", true)
		if player.has_method("set_dash_enabled"):
			player.call("set_dash_enabled", not bool(player.get("dash_disabled_by_hunger")))
		if player.has_method("set_attacking_enabled"):
			player.call("set_attacking_enabled", true)
	_update_camera_and_actor_projection()
	return ok



func _build_run_summary(reason: String) -> Dictionary:
	var elapsed := float(run_interface.get("seconds")) if run_interface != null else 0.0
	var dream_end_minutes := config.dream_start_minutes + elapsed / maxf(config.real_seconds_per_game_minute, 0.001)
	var wake_minutes := dream_end_minutes
	if reason == "梦中倒下":
		wake_minutes += float(_content_rng.randi_range(
			config.death_wake_delay_min_minutes,
			config.death_wake_delay_max_minutes
		))
	return {
		"wake_time": RUN_SETTLEMENT.format_time(wake_minutes),
		"wake_minutes": wake_minutes,
		"dream_end_minutes": dream_end_minutes,
		"alarm_minutes": config.alarm_start_minutes,
		"kills": int(run_interface.get("kills")) if run_interface != null else 0,
		"late": not is_sunday and RUN_SETTLEMENT.attendance_for_minutes(wake_minutes) != "正常出勤",
		"reason": reason,
		"is_sunday": is_sunday,
		"survival_seconds": elapsed,
		"difficulty_day": difficulty_day,
		"dream_layer": dream_layer_id,
		"floor_index": floor_index,
		"boss_defeated": boss_defeated,
	}


func _derive_floor_seed(index: int) -> int:
	if index <= 0:
		return base_floor_seed
	var floor_component := ((index + 1) * 0x9E3779B9) & 0xFFFFFFFF
	return maxi(_stable_u32_mix((int(base_floor_seed) & 0xFFFFFFFF) ^ FLOOR_SEED_SALT ^ floor_component), 1)


func _spawn_elevator() -> bool:
	if elevator_room_id < 0 or key_root == null or wake_exit_root == null:
		return false
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		_set_elevator_runtime_active()
		return true

	# The same opening edge defines the facade centre, wall plane and width.
	var sliding_door_edge := _elevator_sliding_door_edge()

	var door_pos_3d := Vector3.ZERO
	var door_pos_2d := Vector2.ZERO
	if not sliding_door_edge.is_empty():
		door_pos_3d = _door_root_world_position(sliding_door_edge)
		door_pos_2d = Vector2(door_pos_3d.x, door_pos_3d.z) * CELL_PIXELS
	else:
		if _is_otxo_mansion():
			return false
		door_pos_2d = Vector2(elevator_anchor_cell.x, elevator_anchor_cell.y + 2) * CELL_PIXELS
		door_pos_3d = _map_gameplay_to_world(door_pos_2d)
	elevator_door_pos_2d = door_pos_2d
	var cab_pos_2d := Vector2(elevator_anchor_cell) * CELL_PIXELS
	var inward_2d := (cab_pos_2d - door_pos_2d).normalized()
	if sliding_door_edge.has("elevator_cab_inward"):
		inward_2d = Vector2(sliding_door_edge.elevator_cab_inward)
	if String(sliding_door_edge.get("axis", "H")) == "H":
		inward_2d = Vector2(0.0, signf(inward_2d.y))
	else:
		inward_2d = Vector2(signf(inward_2d.x), 0.0)
	elevator_cab_inward_2d = inward_2d

	var inward_world := global_basis * Vector3(inward_2d.x, 0.0, inward_2d.y)
	var camera_back := camera_3d.global_basis.z
	camera_back.y = 0.0
	var orientation: int = 0 if inward_world.dot(camera_back) < 0.0 else 1
	elevator_floor_door = ElevatorFloorDoor3D.new(orientation, floor_index)
	elevator_floor_door.position = door_pos_3d
	wake_exit_root.add_child(elevator_floor_door)
	elevator_floor_door.configure_entrance(inward_2d, camera_3d)
	if not sliding_door_edge.is_empty():
		elevator_floor_door.configure_opening(_door_width_for_edge(sliding_door_edge), wall_thickness)

	# Compatibility hooks for legacy references
	elevator_sliding_door_root = elevator_floor_door.sliding_door_root
	elevator_left_door = elevator_floor_door.left_door_mesh
	elevator_right_door = elevator_floor_door.right_door_mesh
	elevator_indicator_label = elevator_floor_door.indicator_label

	# 2D Collision and Approach Trigger
	var col_parent: Node = collision_root if collision_root != null else key_root
	elevator_floor_door.setup_gameplay_2d(col_parent, key_root, door_pos_2d)
	elevator_door_collider = elevator_floor_door.door_collider_2d
	elevator_door_shape = elevator_floor_door.door_shape_2d
	elevator_approach_trigger = elevator_floor_door.approach_trigger_2d

	elevator_floor_door.approach_entered.connect(_on_elevator_approach_entered)
	elevator_floor_door.approach_exited.connect(_on_elevator_approach_exited)

	elevator_state = &"UNLOCKED" if has_floor_badge else &"LOCKED"
	_set_elevator_runtime_active()
	return true


func _open_elevator_doors() -> void:
	elevator_doors_open = true
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		elevator_floor_door.open_doors(0.45)


func _close_elevator_doors() -> void:
	elevator_doors_open = false
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		elevator_floor_door.close_doors(0.45)


func _set_elevator_runtime_active() -> void:
	if elevator_state != &"TRANSITIONING":
		elevator_state = &"UNLOCKED" if has_floor_badge else &"LOCKED"
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		elevator_floor_door.visible = true
		if elevator_state == &"UNLOCKED":
			elevator_floor_door.update_state(ElevatorFloorDoor3D.State.UNLOCKED)
		elif elevator_state == &"LOCKED":
			elevator_floor_door.update_state(ElevatorFloorDoor3D.State.LOCKED)
		elevator_floor_door.update_indicator(floor_index)


func _set_building_exterior_visible(p_visible: bool) -> void:
	if is_instance_valid(office_art_root): office_art_root.visible=p_visible
	if is_instance_valid(shadow_manager):
		shadow_manager.set_suspended(not p_visible)
	if is_instance_valid(night_lighting) and dynamic_shadows_enabled:
		night_lighting.set_shadow_transition_paused(not p_visible)
	if wall_root != null and is_instance_valid(wall_root):
		wall_root.visible = p_visible
	if floor_root != null and is_instance_valid(floor_root):
		floor_root.visible = p_visible
	if door_root != null and is_instance_valid(door_root):
		door_root.visible = p_visible
	if ceiling_light_root != null and is_instance_valid(ceiling_light_root):
		ceiling_light_root.visible = p_visible
	if furniture_root != null and is_instance_valid(furniture_root):
		furniture_root.visible = p_visible
	if enemy_root != null and is_instance_valid(enemy_root):
		enemy_root.visible = p_visible
	if world_weapon_root != null and is_instance_valid(world_weapon_root):
		world_weapon_root.visible = p_visible
	if pickup_root != null and is_instance_valid(pickup_root):
		pickup_root.visible = p_visible
	if ground_debris_root != null and is_instance_valid(ground_debris_root):
		ground_debris_root.visible = p_visible
	if world_effects_root != null and is_instance_valid(world_effects_root):
		world_effects_root.visible = p_visible
	if debug_root != null and is_instance_valid(debug_root):
		debug_root.visible = p_visible


func _set_building_exterior_vertical_offset(offset_y: float) -> void:
	if floor_root != null and is_instance_valid(floor_root):
		floor_root.position.y = offset_y
	if wall_root != null and is_instance_valid(wall_root):
		wall_root.position.y = offset_y
	if door_root != null and is_instance_valid(door_root):
		door_root.position.y = offset_y
	if ceiling_light_root != null and is_instance_valid(ceiling_light_root):
		ceiling_light_root.position.y = offset_y
	if actor_depth_bridges_root != null and is_instance_valid(actor_depth_bridges_root):
		actor_depth_bridges_root.position.y = offset_y


func _elevator_depth_from_door(gameplay_position: Vector2) -> float:
	return (gameplay_position - elevator_door_pos_2d).dot(elevator_cab_inward_2d)


func _on_elevator_approach_entered(body: Node) -> void:
	if body != player or floor_transition_in_progress or transition_phase != &"IDLE":
		return
	elevator_prompt_active = true
	if has_floor_badge:
		_begin_elevator_entry_transition()
	else:
		if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
			elevator_floor_door.update_state(ElevatorFloorDoor3D.State.LOCKED)
		_update_interaction_prompt()


func _on_elevator_approach_exited(body: Node) -> void:
	if body != player:
		return
	elevator_prompt_active = false
	_update_interaction_prompt()


func _on_elevator_body_exited(body: Node) -> void:
	pass


func _on_elevator_body_entered(body: Node) -> void:
	pass


func _play_elevator_arrival_chime() -> void:
	# Formal floor-arrival cue.  This replaces the former placeholder stack of
	# home_door + phone_unlock, which were two unrelated sounds layered to fake
	# a chime.  Resource: sfx/elevator_candidates/ding_classic_dingdong.wav
	if SFX != null:
		SFX.play_event(&"elevator_ding")


## Drives the elevator ride ambience and the camera rumble as a single unit.
##
## `elevator_rumble_active` / `elevator_rumble_intensity` were declared and read
## by the camera composition but never assigned anywhere in the project, so the
## shake was dead code.  Funnelling both through one helper is what guarantees
## the audio bed and the shake can never disagree about whether a ride is live.
## `fade_out` below zero means "use the ride's normal arrival fade".  Scene
## teardown passes a shorter value so the bed clears roughly in step with the
## music release in _exit_tree instead of droning on after the music is gone.
func _set_elevator_ride_rumbling(active: bool, fade_out: float = -1.0) -> void:
	if active:
		# Restart the shake phase so every ride feels identical.
		elevator_rumble_time = 0.0
		elevator_rumble_intensity = 1.0
	else:
		elevator_rumble_intensity = 0.0
	elevator_rumble_active = active
	if SFX == null:
		return
	if active:
		SFX.play_elevator_rumble()
	elif fade_out >= 0.0:
		SFX.stop_elevator_rumble(fade_out)
	else:
		SFX.stop_elevator_rumble()


func _scripted_walk_player_to(target_pos: Vector2, speed: float = 110.0, timeout: float = 2.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	var elapsed := 0.0
	while is_instance_valid(player) and player.global_position.distance_to(target_pos) > 6.0 and elapsed < timeout:
		var dir := (target_pos - player.global_position).normalized()
		if player.has_method("set_scripted_locomotion"):
			player.call("set_scripted_locomotion", dir, speed)
		await get_tree().physics_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(player):
		if player.has_method("clear_scripted_locomotion"):
			player.call("clear_scripted_locomotion")
		player.global_position = target_pos
		_update_camera_and_actor_projection()


func _begin_elevator_entry_transition() -> void:
	if floor_transition_in_progress or transition_phase != &"IDLE":
		return
	floor_transition_in_progress = true
	elevator_state = &"TRANSITIONING"
	transition_phase = &"ENTERING"
	transition_generation_token += 1
	var token := transition_generation_token

	if interaction_prompt != null and is_instance_valid(interaction_prompt):
		interaction_prompt.dismiss(true)
	elevator_prompt_active = false

	# 1. Stop dash and lock player manual controls
	if player != null and is_instance_valid(player):
		player.cancel_dash()
		player.set("movement_enabled", false)
		if player.has_method("set_attacking_enabled"):
			player.call("set_attacking_enabled", false)

	# 2. Open floor sliding doors
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		await elevator_floor_door.open_doors(0.40)
	else:
		await get_tree().create_timer(0.40).timeout

	if token != transition_generation_token or not is_inside_tree():
		return

	# 3. Walk player naturally into doorway threshold
	var target_threshold := elevator_door_pos_2d
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		target_threshold = elevator_floor_door.get_doorway_threshold_position_2d()

	await _scripted_walk_player_to(target_threshold, 110.0, 1.8)

	if token != transition_generation_token or not is_inside_tree():
		return

	# 4. Close floor sliding doors smoothly behind player
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		await elevator_floor_door.close_doors(0.40)
	else:
		await get_tree().create_timer(0.40).timeout

	if token != transition_generation_token or not is_inside_tree():
		return

	# Phase 2: FULL OCCLUSION MOMENT!
	_transition_to_independent_cab(token)


func _transition_to_independent_cab(token: int) -> void:
	if token != transition_generation_token or not is_inside_tree():
		return
	transition_phase = &"LOADING"
	_next_floor_render_ready = false
	var report: Dictionary = await preload("res://scripts/dream/elevator_loading_cover.gd").run(get_tree(),self,_load_floor_behind_cover.bind(token),token)
	if token != transition_generation_token or not is_inside_tree(): return
	if bool(report.get("rolled_back",false)):
		floor_transition_in_progress=false
		transition_phase=&"IDLE"
	floor_loading_render_preparation_finished.emit(report)
	if bool(report.get("cancelled",true)): return
	# Count only the ready, visible ride; a pause/menu does not consume it.
	var ride_elapsed := 0.0
	var last_tick := Time.get_ticks_usec()
	var previously_paused := get_tree().paused
	while ride_elapsed < ELEVATOR_VISIBLE_RIDE_SECONDS:
		await get_tree().process_frame
		if token != transition_generation_token or not is_inside_tree(): return
		var now := Time.get_ticks_usec()
		var currently_paused := get_tree().paused
		# Do not count a pre-creation frame delta, slow-motion game time, or
		# the pause/resume boundary interval as visible controllable ride time.
		if not previously_paused and not currently_paused:
			ride_elapsed += (now-last_tick)/1000000.0
		last_tick = now
		previously_paused = currently_paused
	if token != transition_generation_token or not is_inside_tree(): return
	_commit_staged_transition_exit(token)


func _load_floor_behind_cover(token: int) -> Dictionary:
	if token != transition_generation_token or not is_inside_tree(): return {"cancelled":true}
	# Ride bed starts on entering the cab and stops on arrival -- see
	# _commit_staged_transition_exit.  The other EXITING entry point,
	# _perform_game_start_cab_exit, deliberately does NOT start it: the player
	# already begins inside the cab, so there is no ride to score.
	_set_elevator_ride_rumbling(true)

	# Hide current floor exterior
	_set_building_exterior_visible(false)

	# Instantiate independent cab at dedicated offset
	var cab_world_pos := Vector3(0.0, 0.0, -100.0)
	active_transition_cab = IndependentElevatorCab3D.new(floor_index)
	active_transition_cab.set_managed_shadows(dynamic_shadows_enabled)
	active_transition_cab.position = cab_world_pos
	add_child(active_transition_cab)
	# The floor root is rotated 45 degrees, but the independent ride cab is a
	# fixed screen-facing space. Keep its world axes upright after parenting it.
	active_transition_cab.global_rotation = Vector3.ZERO

	var cab_gameplay_pos := Vector2(0.0, -3200.0)
	active_transition_cab.setup_gameplay_boundaries(gameplay_canvas.get_node("GameplayWorld"), cab_gameplay_pos)

	# Position player inside cab
	if player != null and is_instance_valid(player):
		player.global_position = active_transition_cab.get_player_initial_position_2d()
		player.set("movement_enabled", false)
		if player.has_method("set_dash_enabled"):
			player.set("dash_enabled", false)

	# Camera focuses on cab center
	camera_aim_offset = Vector3.ZERO
	_update_camera_and_actor_projection()

	# Generation and first-use rendering happen exclusively under the cover.
	var old_floor_idx := floor_index
	var next_floor_idx := floor_index + 1
	var next_seed := _derive_floor_seed(next_floor_idx)

	# Run staged generation behind the already submitted black output.
	var stage_ok := await _regenerate_staged(next_seed, next_floor_idx, token, true)

	if token != transition_generation_token or not is_inside_tree():
		return {"cancelled":true}

	if not stage_ok:
		await _rollback_failed_transition(token, old_floor_idx)
		_sync_transition_render_pose()
		floor_transition_in_progress=true # Retain the input boundary through rollback reveal.
		return {"cancelled":true,"rolled_back":true}

	# Submit the new floor at its actual exit receiver/camera without destroying
	# the cab. Keep the old floor stash until preparation succeeds.
	active_transition_cab.visible = false
	transition_phase = &"PREPARING_FLOOR"
	_set_building_exterior_visible(true)
	player.global_position = elevator_floor_door.get_doorway_threshold_position_2d()
	_sync_transition_render_pose()
	var preparation: Dictionary = {"cancelled":false,"skipped":"headless"}
	if DisplayServer.get_name() != "headless" and not bool(get_meta(&"test_skip_floor_exit_render_preparation",false)):
		var pools: Dictionary = await preload("res://scripts/dream/floor_exit_render_preparation.gd").prepare_pools(get_tree(),self,get_current_floor_token(),token)
		if bool(pools.get("cancelled",true)): return {"cancelled":true}
		_sync_transition_render_pose()
		begin_firearm_render_preparation()
		preparation = await preload("res://scripts/dream/firearm_render_preparation.gd").run(get_tree(),self)
		preparation["capture_pools"] = pools
	if token != transition_generation_token or not is_inside_tree(): return {"cancelled":true}
	if bool(preparation.get("cancelled",false)):
		await _rollback_failed_transition(token,old_floor_idx)
		_sync_transition_render_pose()
		floor_transition_in_progress=true
		return {"cancelled":true,"rolled_back":true}
	_clear_floor_stash()
	_set_building_exterior_visible(false)
	_set_floor_runtime_suspended_for_cab(true)
	active_transition_cab.visible = true
	active_transition_cab.update_indicator(next_floor_idx)
	player.global_position = active_transition_cab.get_player_initial_position_2d()
	transition_phase = &"CAB_RIDE"
	_sync_transition_render_pose()
	if DisplayServer.get_name() != "headless":
		# Flush queued old-floor deletion, cab materials, player capture and the
		# final mask before unpausing/showing the movable cab.
		for frame in 4: await RenderingServer.frame_post_draw
		if token != transition_generation_token or not is_inside_tree(): return {"cancelled":true}
		get_viewport().get_texture().get_image()
	_next_floor_render_ready = true
	player.set("movement_enabled",true)
	return {"cancelled":false,"render_preparation":preparation,"ready_before_ride":true}


func _sync_transition_render_pose() -> void:
	_update_camera_and_actor_projection()
	if is_instance_valid(player_depth_bridge): player_depth_bridge._process(0.0)
	if is_instance_valid(room_visibility): room_visibility._update_outside_mask()
	for index in OCCLUSION_CUTOUT_SLOT_COUNT:
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % index,Vector4.ZERO)


func _set_floor_runtime_suspended_for_cab(suspended: bool) -> void:
	if suspended:
		if not _cab_suspended_floor_state.is_empty(): return
		for floor_owner in _floor_owned_roots() + [transition_root,pit_root]:
			if not is_instance_valid(floor_owner): continue
			for child in floor_owner.get_children():
				if not _is_persistent_floor_child(child): _suspend_cab_floor_node(child)
	else:
		for record in _cab_suspended_floor_state:
			var node: Node = record.reference.get_ref()
			if not is_instance_valid(node): continue
			node.process_mode = record.mode
			if record.has("layer"):
				node.collision_layer = record.layer
				node.collision_mask = record.mask
			if record.has("freeze"): node.freeze = record.freeze
			if record.has("visible"): node.visible = record.visible
		_cab_suspended_floor_state.clear()


func _suspend_cab_floor_node(node: Node) -> void:
	var record := {"reference":weakref(node),"mode":node.process_mode}
	if node is CollisionObject2D or node is CollisionObject3D:
		record["layer"] = node.collision_layer
		record["mask"] = node.collision_mask
		node.collision_layer = 0
		node.collision_mask = 0
	if node is RigidBody2D or node is RigidBody3D:
		record["freeze"] = node.freeze
		node.freeze = true
	if node is Node3D:
		record["visible"] = node.visible
		node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_cab_suspended_floor_state.append(record)
	for child in node.get_children(): _suspend_cab_floor_node(child)


func _commit_staged_transition_exit(token: int) -> void:
	if token != transition_generation_token or not is_inside_tree():
		return
	transition_phase = &"EXITING"

	# 1. Lock player movement in cab
	if player != null and is_instance_valid(player):
		player.set("movement_enabled", false)

	# 2. End the ride bed, then play the arrival chime.  The fade-out and the
	#    cue intentionally overlap so the bed recedes beneath the chime.
	_set_elevator_ride_rumbling(false)
	_play_elevator_arrival_chime()
	if bool(get_meta(&"test_skip_floor_exit_render_preparation",false)):
		_prepare_floor_exit_scene(token)
	else:
		var report: Dictionary=await preload("res://scripts/dream/floor_exit_render_preparation.gd").run(get_tree(),self,_prepare_floor_exit_scene.bind(token),token,not _next_floor_render_ready)
		floor_exit_render_preparation_finished.emit(report)
		if bool(report.get("cancelled",true)): return
	if token != transition_generation_token or not is_inside_tree(): return

	await get_tree().create_timer(0.08).timeout

	# 5. Open new floor doors
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		await elevator_floor_door.open_doors(0.40)

	# 6. Walk player naturally out of elevator into corridor safe landing zone
	var exit_landing := Vector2.ZERO
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		exit_landing = elevator_floor_door.get_corridor_approach_position_2d()
	else:
		exit_landing = player.global_position + Vector2.DOWN * 48.0

	await _scripted_walk_player_to(exit_landing, 110.0, 1.8)

	# 7. Close doors smoothly behind player and lock
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		await elevator_floor_door.close_doors(0.40)
		elevator_floor_door.update_state(ElevatorFloorDoor3D.State.LOCKED)

	# Consume badge
	has_floor_badge = false

	# Restore all player controls
	if player != null and is_instance_valid(player):
		player.set("movement_enabled", true)
		if player.has_method("set_dash_enabled"):
			player.set("dash_enabled", true)
		if player.has_method("set_attacking_enabled"):
			player.call("set_attacking_enabled", true)

	floor_transition_in_progress = false
	elevator_state = &"LOCKED"
	transition_phase = &"IDLE"
	player_has_left_elevator_cab = true

	if is_instance_valid(objective_guidance):
		objective_guidance.reset_floor()
	elevator_floor_transition_completed.emit(floor_index)


func _prepare_floor_exit_scene(token: int) -> bool:
	if token != transition_generation_token or not is_inside_tree(): return false
	_set_floor_runtime_suspended_for_cab(false)

	# 3. Clean up and unload cab during occlusion (floor scene NEVER displays cab!)
	if active_transition_cab != null and is_instance_valid(active_transition_cab):
		active_transition_cab.cleanup_gameplay()
		active_transition_cab.queue_free()
		active_transition_cab = null

	# 4. Make new floor visible and position player behind closed door
	_set_building_exterior_visible(true)
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		elevator_floor_door.update_indicator(floor_index)
		if player != null and is_instance_valid(player):
			player.global_position = elevator_floor_door.get_doorway_threshold_position_2d()
			_sync_transition_render_pose()

	return true


func _commit_floor_transition(generation_token: int = 0) -> void:
	_begin_elevator_entry_transition()


func _stash_current_floor_for_rollback() -> void:
	preload("res://scripts/dream/floor_reflections.gd").uninstall(self)
	var smoke: Node=floor_root.get_node_or_null("FootstepSmoke")
	if smoke!=null: smoke.clear()
	if is_instance_valid(shadow_manager):
		shadow_manager.clear_floor()
	_clear_floor_stash()
	_floor_rollback_stash = Node.new()
	_floor_rollback_stash.name = "FloorRollbackStash"
	_floor_rollback_stash.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_floor_rollback_stash)
	_stashed_runtime_state.clear()
	for property in ["active_seed", "building_rect", "rooms", "partitions", "corridors", "connections", "macro_graph",
		"room_states", "corridor_states", "room_encounters", "room_layout_plans", "room_ambient_spawned",
		"floor_cells", "presentation_floor_cells", "room_cells", "corridor_cells", "pit_cells",
		"pillar_footprints", "pillar_cells", "internal_wall_edges", "wall_edges", "window_wall_edges",
		"glass_wall_edges", "door_edges", "door_opening_edges", "edge_states", "spawn_room_id",
		"boss_room_id", "key_room_id", "spawn_cell", "main_entrance", "current_room_id",
		"floor_shape", "elevator_room_id", "elevator_anchor_cell", "elevator_edge_key",
		"elevator_floor_door", "elevator_approach_trigger", "elevator_door_pos_2d", "elevator_cab_inward_2d",
		"floor_badge_pickup", "badge_marker", "badge_drop_committed", "badge_drop_pending",
		"furniture_count", "enemy_count", "reserved_content_cells", "room_ambient_spawn_pending",
		"boss_distances", "key_distances", "effective_global_enemy_cap", "enemy_population_refill_left",
		"enemy_population_breathing_left", "transition_root", "pit_root"]:
		var value: Variant = get(property)
		_stashed_runtime_state[property] = value.duplicate(true) if value is Array or value is Dictionary else value
	# Invalidate delayed drops/debris before any staged layout can expose roots.
	_layout_generation += 1
	room_ambient_spawn_pending.clear()

	_stashed_rooms = rooms.duplicate(true)
	_stashed_floor_cells = floor_cells.duplicate(true)
	_stashed_room_cells = room_cells.duplicate(true)
	_stashed_corridor_cells = corridor_cells.duplicate(true)
	_stashed_door_edges = door_edges.duplicate(true)
	_stashed_macro_graph = macro_graph.duplicate(true)
	_stashed_floor_index = floor_index
	# Older callers used GameplayWorld directly; adopt those bullets as well.
	for child in gameplay_world.get_children():
		if child.is_in_group(&"dream_projectiles"):
			child.reparent(world_effects_root)

	var roots_to_stash := _floor_owned_roots()
	for r in roots_to_stash:
		if r == null: continue
		var bucket: Node = Node3D.new() if r is Node3D else Node2D.new()
		bucket.name = "Bucket_" + r.name
		if bucket is Node3D:
			bucket.visible = false
		elif bucket is CanvasItem:
			bucket.visible = false
		_floor_rollback_stash.add_child(bucket)
		for child in r.get_children():
			if _is_persistent_floor_child(child):
				continue
			_freeze_stashed_physics(child)
			child.reparent(bucket)
	for extra in [transition_root, pit_root]:
		if is_instance_valid(extra) and extra.get_parent() == generated_root:
			extra.set_meta(&"rollback_parent", generated_root)
			_freeze_stashed_physics(extra)
			extra.reparent(_floor_rollback_stash)
			extra.visible = false
	transition_root = null
	pit_root = null


func _clear_floor_stash() -> void:
	if _floor_rollback_stash != null and is_instance_valid(_floor_rollback_stash):
		_floor_rollback_stash.queue_free()
		_floor_rollback_stash = null
	_stashed_rooms.clear()
	_stashed_floor_cells.clear()
	_stashed_room_cells.clear()
	_stashed_corridor_cells.clear()
	_stashed_door_edges.clear()
	_stashed_macro_graph.clear()
	_stashed_runtime_state.clear()
	_stashed_physics_state.clear()


func _rollback_failed_transition(token: int, old_floor_idx: int) -> void:
	if token != transition_generation_token or not is_inside_tree():
		return
	# The ride was aborted before arrival, so the bed and the shake must be
	# cleared here as well -- otherwise a failed floor generation leaves both
	# running forever.
	_set_elevator_ride_rumbling(false)
	floor_index = old_floor_idx

	# Reject callbacks from the aborted new floor too.
	preload("res://scripts/dream/floor_reflections.gd").uninstall(self)
	_layout_generation += 1
	var roots_to_clear := _floor_owned_roots()
	for r in roots_to_clear:
		if r == null: continue
		for child in r.get_children():
			if not _is_persistent_floor_child(child):
				child.free()
	for extra in [transition_root, pit_root]:
		if is_instance_valid(extra):
			extra.free()

	if _floor_rollback_stash != null and is_instance_valid(_floor_rollback_stash):
		for bucket in _floor_rollback_stash.get_children():
			if bucket.has_meta(&"rollback_parent"):
				bucket.reparent(bucket.get_meta(&"rollback_parent"))
				bucket.visible = true
				continue
			var target_root_name := String(bucket.name).replace("Bucket_", "")
			var target_root: Node = null
			for r in roots_to_clear:
				if r != null and r.name == target_root_name:
					target_root = r
					break
			if target_root != null:
				for child in bucket.get_children():
					child.reparent(target_root)
		_floor_rollback_stash.queue_free()
		_floor_rollback_stash = null

	rooms = _stashed_rooms
	floor_cells = _stashed_floor_cells
	room_cells = _stashed_room_cells
	corridor_cells = _stashed_corridor_cells
	door_edges = _stashed_door_edges
	macro_graph = _stashed_macro_graph
	for property in _stashed_runtime_state:
		set(property, _stashed_runtime_state[property])
	for record in _stashed_physics_state:
		var node: Node = record.reference.get_ref()
		if not is_instance_valid(node):
			continue
		if record.has("process_mode"):
			node.process_mode = record.process_mode
			if node.has_method("refresh_floor_token"):
				node.refresh_floor_token()
			continue
		node.collision_layer = record.layer
		node.collision_mask = record.mask
		if record.has("freeze"):
			node.freeze = record.freeze
	_stashed_physics_state.clear()
	_stashed_runtime_state.clear()
	_rebuild_settled_blood_registry()
	_floor_path_cache_enabled = true
	_current_floor_path_adjacency()
	var restored_pool := actor_depth_bridges_root.get_node_or_null(^"ProjectileCapturePool") as Node3D
	if restored_pool != null:
		for effect in world_effects_root.get_children():
			if effect is Node2D and effect.is_in_group(&"dream_projectiles"):
				restored_pool.restore_binding(effect, camera_3d)
	var restored_muzzle_pool := actor_depth_bridges_root.get_node_or_null(^"MuzzleCapturePool") as Node3D
	if restored_muzzle_pool != null:
		for effect in world_effects_root.get_children():
			if effect is Node2D:
				restored_muzzle_pool.restore_binding(effect,camera_3d)
	var restored_shell_pool := actor_depth_bridges_root.get_node_or_null(^"ShellCapturePool") as Node3D
	if restored_shell_pool != null:
		for effect in world_effects_root.get_children():
			if effect is Node2D:
				restored_shell_pool.restore_binding(effect,camera_3d)
	var restored_feedback_pool := actor_depth_bridges_root.get_node_or_null(^"FeedbackCapturePool") as Node3D
	if restored_feedback_pool != null:
		for effect in world_effects_root.get_children():
			if effect is Node2D:
				restored_feedback_pool.restore_binding(effect,camera_3d)
	var restored_blood_pool := actor_depth_bridges_root.get_node_or_null(^"BloodGroundCapturePool") as Node3D
	if restored_blood_pool != null:
		for effect in world_effects_root.get_children():
			if effect is Node2D:
				restored_blood_pool.restore_binding(effect,camera_3d,BLOOD_FLOOR_WORLD_Y)
	var restored_object_pool := actor_depth_bridges_root.get_node_or_null(^"FloorObjectCapturePool") as Node3D
	if restored_object_pool!=null:
		for source_root in [world_weapon_root,ground_debris_root]:
			for effect in source_root.get_children():
				if effect is Node2D: restored_object_pool.restore_binding(effect,camera_3d,dynamic_shadows_enabled)
	# New-floor geometry was freed above. Rebind the visible-wall query cache
	# to restored instances before gameplay/occlusion processing resumes.
	_prepare_wall_cutout_cache()
	if is_instance_valid(room_visibility):
		var restored_room_id := current_room_id
		room_visibility.configure(self)
		current_room_id = restored_room_id
		room_visibility.current_room_id = restored_room_id
		if restored_room_id >= 0:
			room_visibility.reveal_room(restored_room_id)
	_configure_dungeon_minimap()
	if is_instance_valid(shadow_manager):
		shadow_manager.rebuild_floor()

	_set_building_exterior_visible(true)

	if active_transition_cab != null and is_instance_valid(active_transition_cab):
		# A covered rollback is paused; do not wait on an invisible cab tween.
		if not get_tree().paused: await active_transition_cab.open_cab_doors(0.40)
		if player != null and is_instance_valid(player):
			# Restore outside the auto-entry trigger, otherwise an unconsumed
			# badge immediately starts another failed load and locks control again.
			player.global_position = elevator_floor_door.get_corridor_approach_position_2d() - elevator_floor_door.get_inward_2d() * 1.5 * CELL_PIXELS if is_instance_valid(elevator_floor_door) else elevator_door_pos_2d
			player.set("movement_enabled", true)
			if player.has_method("set_dash_enabled"):
				player.set("dash_enabled", true)
			if player.has_method("set_attacking_enabled"):
				player.call("set_attacking_enabled", true)
		active_transition_cab.cleanup_gameplay()
		active_transition_cab.queue_free()
		active_transition_cab = null

	floor_transition_in_progress = false
	elevator_state = &"READY" if has_floor_badge else &"LOCKED"
	transition_phase = &"IDLE"
	player_has_left_elevator_cab = true
	preload("res://scripts/dream/floor_reflections.gd").install(self)


func _regenerate_staged(requested_seed: int, target_floor: int, token: int,retain_rollback: bool=false) -> bool:
	var trace_stages: bool=bool(get_meta(&"test_trace_floor_generation",false))
	var stage_started: int=Time.get_ticks_usec() if trace_stages else 0
	_stash_current_floor_for_rollback()
	floor_index = target_floor
	_reset_layout_data()
	camera_aim_offset = Vector3.ZERO
	if trace_stages: _trace_floor_generation_stage("stash_reset",stage_started)

	# Frame 1: Topology / Layout
	await get_tree().process_frame
	if token != transition_generation_token or not is_inside_tree():
		return false
	if trace_stages: stage_started=Time.get_ticks_usec()
	if not generate_layout_only(requested_seed):
		push_error("Dream3D staged building layout failed after max attempts.")
		return false
	if trace_stages: _trace_floor_generation_stage("layout",stage_started)

	# Frame 2: Rooms & Stubs presentation
	await get_tree().process_frame
	if token != transition_generation_token or not is_inside_tree():
		return false
	current_room_id = spawn_room_id
	if trace_stages: stage_started=Time.get_ticks_usec()
	_prepare_transition_stub_metadata()
	_rebuild_active_room_presentation()
	if trace_stages: _trace_floor_generation_stage("presentation",stage_started)

	# Frame 3: Edge validation
	await get_tree().process_frame
	if token != transition_generation_token or not is_inside_tree():
		return false
	if trace_stages: stage_started=Time.get_ticks_usec()
	_validate_rendered_edge_nodes()
	if trace_stages: _trace_floor_generation_stage("edge_validation",stage_started)

	# Frame 4: Content Spawning (Furniture & Enemies)
	await get_tree().process_frame
	if token != transition_generation_token or not is_inside_tree():
		return false
	if trace_stages: stage_started=Time.get_ticks_usec()
	if spawn_content:
		_spawn_random_content()
	if trace_stages: _trace_floor_generation_stage("content",stage_started)

	# Frame 5: Spawn new Elevator Floor Door
	await get_tree().process_frame
	if token != transition_generation_token or not is_inside_tree():
		return false
	elevator_floor_door = null
	if trace_stages: stage_started=Time.get_ticks_usec()
	_spawn_elevator()
	if trace_stages: _trace_floor_generation_stage("elevator",stage_started)

	# Frame 6: Visibility & Minimap
	await get_tree().process_frame
	if token != transition_generation_token or not is_inside_tree():
		return false
	if trace_stages: stage_started=Time.get_ticks_usec()
	var final_stage_started: int=stage_started
	enemy_population_refill_left = _enemy_population_interval()
	# The rendered transition prepares pools under the loading cover, before
	# the visible ride. Headless/custom staged callers retain synchronous warmup.
	var covered_pool_warmup: bool=DisplayServer.get_name()!="headless" and is_instance_valid(active_transition_cab) and not bool(get_meta(&"test_skip_floor_exit_render_preparation",false)) and not bool(get_meta(&"test_sync_floor_capture_prewarm",false))
	if not covered_pool_warmup:
		_get_projectile_capture_pool().prewarm(camera_3d)
		_get_muzzle_capture_pool().prewarm(camera_3d)
		_get_shell_capture_pool().prewarm(camera_3d)
		_get_feedback_capture_pool().prewarm(camera_3d)
		_get_blood_ground_capture_pool().prewarm(camera_3d,BLOOD_FLOOR_WORLD_Y)
		_get_floor_object_capture_pool().prewarm(camera_3d,dynamic_shadows_enabled)
	if trace_stages:
		_trace_floor_generation_stage("capture_pools",stage_started)
		stage_started=Time.get_ticks_usec()
	_floor_path_cache_enabled = true
	_current_floor_path_adjacency()
	if trace_stages:
		_trace_floor_generation_stage("path_adjacency",stage_started)
		stage_started=Time.get_ticks_usec()
	if room_visibility != null and is_instance_valid(room_visibility):
		room_visibility.configure(self)
	if trace_stages:
		_trace_floor_generation_stage("room_visibility",stage_started)
		stage_started=Time.get_ticks_usec()
	_prepare_approved_office_art()
	_prepare_wall_shadow_batches()
	if trace_stages:
		_trace_floor_generation_stage("approved_art",stage_started)
		stage_started=Time.get_ticks_usec()
	_configure_dungeon_minimap()
	if trace_stages:
		_trace_floor_generation_stage("visibility_minimap",stage_started)
		stage_started=Time.get_ticks_usec()
	preload("res://scripts/dream/combat_vfx.gd").install(self)

	_set_building_exterior_visible(false)
	preload("res://scripts/dream/floor_reflections.gd").install(self)
	if not retain_rollback: _clear_floor_stash()
	if trace_stages:
		_trace_floor_generation_stage("exterior_stash_cleanup",stage_started)
		_trace_floor_generation_stage("pools_visibility_cleanup",final_stage_started)
	return true

func _trace_floor_generation_stage(stage: String,started: int) -> void:
	print("FLOOR_GENERATION_STAGE ",JSON.stringify({"floor":floor_index,"stage":stage,"cpu_ms":(Time.get_ticks_usec()-started)/1000.0}))


func _perform_game_start_cab_exit() -> void:
	if elevator_floor_door == null or not is_instance_valid(elevator_floor_door):
		return
	if player == null or not is_instance_valid(player):
		return
	floor_transition_in_progress = true
	transition_phase = &"EXITING"
	player.cancel_dash()
	player.set("movement_enabled", false)
	if player.has_method("set_attacking_enabled"):
		player.call("set_attacking_enabled", false)

	# Place player at threshold behind closed floor door (no cab in floor scene)
	player.global_position = elevator_floor_door.get_doorway_threshold_position_2d()
	_update_camera_and_actor_projection()

	await get_tree().create_timer(0.25).timeout
	_play_elevator_arrival_chime()
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		elevator_floor_door.update_indicator(0)
		await elevator_floor_door.open_doors(0.40)

	# Walk player out into corridor with natural walking animation
	var landing := elevator_floor_door.get_corridor_approach_position_2d()
	await _scripted_walk_player_to(landing, 110.0, 1.8)

	# Close doors behind player and lock
	if elevator_floor_door != null and is_instance_valid(elevator_floor_door):
		await elevator_floor_door.close_doors(0.40)
		elevator_floor_door.update_state(ElevatorFloorDoor3D.State.LOCKED)

	# Enable player controls
	if player != null and is_instance_valid(player):
		player.set("movement_enabled", true)
		if player.has_method("set_dash_enabled"):
			player.set("dash_enabled", true)
		if player.has_method("set_attacking_enabled"):
			player.call("set_attacking_enabled", true)
	floor_transition_in_progress = false
	transition_phase = &"IDLE"
	player_has_left_elevator_cab = true


func _spawn_ambient_debris() -> void:
	if ground_debris_root == null or ENVIRONMENT_DEBRIS_SCENE == null:
		return
	for room in rooms:
		_spawn_ambient_debris_for_room(int(room.get("id", -1)))


func _schedule_ambient_debris_for_room(room_id: int) -> void:
	if room_id < 0 or room_id >= rooms.size() or ground_debris_root == null or ENVIRONMENT_DEBRIS_SCENE == null:
		return
	if bool(room_ambient_spawned.get(room_id, false)) or bool(room_ambient_spawn_pending.get(room_id, false)):
		return
	room_ambient_spawn_pending[room_id] = true
	var generation_token := _layout_generation
	call_deferred("_spawn_ambient_debris_for_room_deferred", room_id, generation_token)


func _spawn_ambient_debris_for_room_deferred(room_id: int, generation_token: int) -> void:
	if generation_token != _layout_generation or not is_inside_tree():
		return
	room_ambient_spawn_pending.erase(room_id)
	# A fast second transition can make the request stale before the deferred
	# callback runs.  Do not instantiate debris into a room that is no longer
	# the active presentation slice.
	if lazy_room_presentation and room_id != current_room_id:
		return
	_spawn_ambient_debris_for_room(room_id)


func _spawn_ambient_debris_for_room(room_id: int) -> void:
	if room_id < 0 or room_id >= rooms.size() or ground_debris_root == null or ENVIRONMENT_DEBRIS_SCENE == null:
		return
	if bool(room_ambient_spawned.get(room_id, false)):
		return
	room_ambient_spawned[room_id] = true
	var room: Dictionary = rooms[room_id]
	var desired := clampi(
		roundi(float(room.get("usable_cells", []).size()) * CELL_PIXELS * CELL_PIXELS / maxf(config.environment_debris_area_per_item, 1.0)),
		config.environment_debris_ambient_min_per_room,
		config.environment_debris_ambient_max_per_room
	)
	var placed: Array[Vector2] = []
	if key_pickup != null and is_instance_valid(key_pickup) and int(key_pickup.get_meta(&"dream_room_id", -1)) == room_id:
		placed.append(key_pickup.global_position)
	for _index in range(desired):
		var position := _random_room_position(room_id, 6.0, placed)
		if position == Vector2.ZERO:
			break
		if player != null and position.distance_to(player.global_position) < config.environment_debris_spawn_clearance:
			continue
		if _position_near_any_door(position, config.environment_debris_door_clearance):
			continue
		if spawn_environment_debris(position, room_id, 1) <= 0:
			continue
		placed.append(position)


func _room_bounds_pixels(room_id: int, inset: float = 18.0) -> Rect2:
	if room_id < 0 or room_id >= rooms.size():
		return Rect2()
	var rect: Rect2i = rooms[room_id]["grid_rect"]
	var bounds := Rect2(
		(Vector2(rect.position) - Vector2.ONE * 0.5) * CELL_PIXELS,
		Vector2(rect.size.x, rect.size.y) * CELL_PIXELS,
	)
	return bounds.grow(-inset)


func _room_id_at_position(at_position: Vector2) -> int:
	var cell := Vector2i(roundi(at_position.x / CELL_PIXELS), roundi(at_position.y / CELL_PIXELS))
	# A pit is non-walkable floor, but it still belongs to the room that owns
	# the hazard.  Keeping this room identity stable prevents a brief pit fall
	# from firing a false room transition or changing wall visibility authority.
	if pit_cells.has(cell):
		return int(pit_cells[cell])
	return int(room_cells.get(cell, -1))


func get_corridor_id_at_position(at_position: Vector2 = Vector2.INF) -> int:
	var sample := at_position
	if sample == Vector2.INF:
		sample = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	var cell := Vector2i(roundi(sample.x / CELL_PIXELS), roundi(sample.y / CELL_PIXELS))
	return int(corridor_cells.get(cell, -1))


func get_current_room_id() -> int:
	if current_room_id >= 0:
		return current_room_id
	return _room_id_at_position(player.global_position) if player != null else spawn_room_id


func get_room_id_for_node(node: Node) -> int:
	var cursor := node
	while cursor != null:
		if cursor.has_meta(&"dream_room_id"):
			return int(cursor.get_meta(&"dream_room_id", -1))
		cursor = cursor.get_parent()
	return _room_id_at_position((node as Node2D).global_position) if node is Node2D else -1


func _find_door_edge_between(room_a: int, room_b: int) -> Dictionary:
	for edge_variant in door_edges.values():
		var edge: Dictionary = edge_variant
		var edge_a := int(edge.get("region_a_id", -1))
		var edge_b := int(edge.get("region_b_id", -1))
		if (edge_a == room_a and edge_b == room_b) or (edge_a == room_b and edge_b == room_a):
			return edge
	return {}


func are_rooms_openly_connected(room_a: int, room_b: int) -> bool:
	if room_a == room_b:
		return true
	if room_a < 0 or room_b < 0 or room_a >= rooms.size() or room_b >= rooms.size():
		return false
	var cache_key := "%d_%d" % [mini(room_a, room_b), maxi(room_a, room_b)]
	if _open_connected_rooms_cache.has(cache_key):
		return bool(_open_connected_rooms_cache[cache_key])

	var is_open := false
	var connection := _connection_between_rooms(room_a, room_b)
	if not connection.is_empty():
		var door_style := String(connection.get("door_style", ""))
		if door_style == "open":
			is_open = true

	if not is_open:
		var room_a_data: Dictionary = rooms[room_a]
		var room_b_data: Dictionary = rooms[room_b]
		var arch_a := String(room_a_data.get("archetype", ""))
		var arch_b := String(room_b_data.get("archetype", ""))
		var sample_a := String(room_a_data.get("sample_key", ""))
		var sample_b := String(room_b_data.get("sample_key", ""))
		var is_open_arch := (
			arch_a in ["open_office", "lounge"]
			or arch_b in ["open_office", "lounge"]
			or sample_a in ["office", "lounge"]
			or sample_b in ["office", "lounge"]
		)
		if is_open_arch and not _get_open_boundary_edges_between(room_a, room_b).is_empty():
			is_open = true

	_open_connected_rooms_cache[cache_key] = is_open
	return is_open


func _get_open_boundary_edges_between(room_a: int, room_b: int) -> Array[Dictionary]:
	var cache_key := "%d_%d" % [mini(room_a, room_b), maxi(room_a, room_b)]
	if _open_boundary_edges_cache.has(cache_key):
		var cached_edges: Array[Dictionary] = []
		cached_edges.assign(_open_boundary_edges_cache[cache_key])
		return cached_edges

	var result: Array[Dictionary] = []
	for edge_key_variant in edge_states.keys():
		var edge_key: String = edge_key_variant
		var state: StringName = StringName(edge_states[edge_key])
		if state != &"OPEN" and not door_edges.has(edge_key):
			continue
		var edge: Dictionary = {}
		if door_edges.has(edge_key):
			edge = door_edges[edge_key]
		elif door_opening_edges.has(edge_key):
			edge = door_opening_edges[edge_key]
		else:
			var parts := edge_key.split(":")
			if parts.size() == 3:
				edge = {
					"axis": parts[0],
					"x": int(parts[1]),
					"y": int(parts[2]),
				}
		if edge.is_empty():
			continue
		var sides := _edge_side_cells(edge)
		if sides.size() < 2:
			continue
		var r0 := int(room_cells.get(sides[0], -1))
		var r1 := int(room_cells.get(sides[1], -1))
		if (r0 == room_a and r1 == room_b) or (r0 == room_b and r1 == room_a):
			result.append(edge)

	_open_boundary_edges_cache[cache_key] = result
	return result


func _boundary_edge_center_pixels(edge: Dictionary) -> Vector2:
	if edge.has("opening_cells") or edge.has("opening_profile") or int(edge.get("door_id", -1)) >= 0:
		return _door_center_pixels(edge)
	return _edge_gameplay_position(edge)


func _connection_between_rooms(room_a: int, room_b: int) -> Dictionary:
	"""Return the authored graph connection for a pair of Room nodes."""
	for connection_variant in connections:
		var connection: Dictionary = connection_variant
		var a := int(connection.get("a", -1))
		var b := int(connection.get("b", -1))
		if (a == room_a and b == room_b) or (a == room_b and b == room_a):
			return connection
	return {}


func _connection_door_for_room(connection: Dictionary, room_id: int) -> Dictionary:
	if int(connection.get("a", -1)) == room_id:
		return connection.get("door_a", {}) as Dictionary
	if int(connection.get("b", -1)) == room_id:
		return connection.get("door_b", {}) as Dictionary
	return {}


func _get_room_doors(room_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for conn_variant in connections:
		var conn: Dictionary = conn_variant
		var a := int(conn.get("a", -1))
		var b := int(conn.get("b", -1))
		if a == room_id or b == room_id:
			var door := _connection_door_for_room(conn, room_id)
			if not door.is_empty():
				result.append(door)
	return result


func _plan_otxo_room_layout(room_id: int) -> Dictionary:
	if room_id < 0 or room_id >= rooms.size():
		return {}
	if room_layout_plans.has(room_id):
		return room_layout_plans[room_id]
	var room: Dictionary = rooms[room_id]
	var r_type: StringName = StringName(room.get("room_type", &""))
	var arch: String = String(room.get("archetype", ""))
	if not _room_allows_furniture(room_id):
		var empty_plan := {
			"success": true,
			"furniture_placements": [],
			"enemy_placements": [],
			"drop_placements": [],
		}
		room_layout_plans[room_id] = empty_plan
		return empty_plan
	var doors := _get_room_doors(room_id)
	if bool(room.get("authored_sample", false)):
		var sample_plan: Dictionary = preload("res://scripts/dream/office_sample_floor.gd").plan(room, doors)
		room_layout_plans[room_id] = sample_plan
		return sample_plan
	var room_bounds_px := _room_bounds_pixels(room_id, 18.0)
	var room_seed := _derive_room_encounter_seed(room_id)
	var archetype: String = String(room.get("archetype", ""))
	var scene_paths: Array = ARCHETYPE_FURNITURE_MAP.get(archetype, FURNITURE_SCENE_PATHS)
	var room_scenes: Array[PackedScene] = []
	for p in scene_paths:
		var sc := load(p) as PackedScene
		if sc != null:
			room_scenes.append(sc)
	if room_scenes.is_empty():
		for p in FURNITURE_SCENE_PATHS:
			var sc := load(p) as PackedScene
			if sc != null:
				room_scenes.append(sc)

	var desired: int = 0 if not _room_allows_furniture(room_id) else clampi(roundi(float(room.get("usable_cells", []).size()) * furniture_density * 1.8), 3, 6)
	var planned_enemies := 0
	var planned_drops := 0
	if room_encounters.has(room_id):
		planned_enemies = int(room_encounters[room_id].get("planned_enemy_count", 0))
		planned_drops = int(room_encounters[room_id].get("planned_drop_count", 0))
	elif room_id != spawn_room_id and room_id != boss_room_id and _is_combat_room(room):
		var min_e := _room_enemy_minimum(room)
		var max_e := _effective_room_enemy_max(room)
		var temp_rng := RandomNumberGenerator.new()
		temp_rng.seed = room_seed
		planned_enemies = temp_rng.randi_range(min_e, max_e)
		planned_drops = _room_drop_base_count(room) * 2

	var plan: Dictionary = OTXO_ROOM_LAYOUT_PLANNER_SCRIPT.call(
		"plan_room_layout",
		room_id,
		room,
		doors,
		room_scenes,
		desired,
		planned_enemies,
		planned_drops,
		room_seed,
		room_bounds_px,
		CELL_PIXELS
	)
	room_layout_plans[room_id] = plan
	return plan


func _room_step_vector(room_a: int, room_b: int) -> Vector2i:
	if room_a >= 0 and room_b >= 0 and room_a < rooms.size() and room_b < rooms.size():
		var macro_a: Vector2i = rooms[room_a].get("macro_coord", Vector2i.ZERO)
		var macro_b: Vector2i = rooms[room_b].get("macro_coord", Vector2i.ZERO)
		var macro_delta := macro_b - macro_a
		if absi(macro_delta.x) + absi(macro_delta.y) == 1:
			return macro_delta
		var centre_delta: Vector2i = rooms[room_b].get("center_cell", Vector2i.ZERO) - rooms[room_a].get("center_cell", Vector2i.ZERO)
		if absi(centre_delta.x) >= absi(centre_delta.y):
			return Vector2i(signi(centre_delta.x), 0)
		return Vector2i(0, signi(centre_delta.y))
	return Vector2i.ZERO


func _direction_name_from_step(step: Vector2i) -> StringName:
	if step.x > 0:
		return &"right"
	if step.x < 0:
		return &"left"
	if step.y > 0:
		return &"bottom"
	if step.y < 0:
		return &"top"
	return &""


func get_employee_corridor_transit_points(from_room: int, target_room_id: int) -> Array[Vector2]:
	"""Build a collision-safe ground path through the authored corridor.

	The existing Enemy state machine still owns the transit animation and door
	arbitration.  This helper only supplies deterministic 2D waypoints so a
	Room->Corridor->Room edge is traversed continuously rather than treating
	the two rooms as if they shared a wall.
	"""
	var empty: Array[Vector2] = []
	var connection := _connection_between_rooms(from_room, target_room_id)
	if connection.is_empty():
		return empty
	var from_door := _connection_door_for_room(connection, from_room)
	var target_door := _connection_door_for_room(connection, target_room_id)
	if from_door.is_empty() or target_door.is_empty():
		return empty
	var corridor_id := int(connection.get("corridor_id", -1))
	if corridor_id < 0 or corridor_id >= corridors.size():
		# Legacy direct room-to-room layouts need only the target socket.
		var direct_inside: Vector2i = target_door.get("inside_cell", Vector2i.ZERO)
		var direct_step := _room_step_vector(from_room, target_room_id)
		var direct_exit := Vector2(direct_inside) * CELL_PIXELS + Vector2(direct_step) * EMPLOYEE_CONFIG.employee_door_exit_distance
		return [direct_exit]

	var corridor_set: Dictionary = {}
	for cell_variant in corridors[corridor_id].get("cells", []):
		var cell: Vector2i = cell_variant
		corridor_set[cell] = true
	var start_cell: Vector2i = from_door.get("outside_cell", Vector2i.ZERO)
	var finish_cell: Vector2i = target_door.get("outside_cell", Vector2i.ZERO)
	if not corridor_set.has(start_cell) or not corridor_set.has(finish_cell):
		return empty
	var came_from: Dictionary = {start_cell: start_cell}
	var queue: Array[Vector2i] = [start_cell]
	var queue_index := 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		if current == finish_cell:
			break
		for direction in CARDINAL_DIRECTIONS:
			var next_cell: Vector2i = current + direction
			if not corridor_set.has(next_cell) or came_from.has(next_cell):
				continue
			came_from[next_cell] = current
			queue.append(next_cell)
	if not came_from.has(finish_cell):
		return empty
	var path_cells: Array[Vector2i] = [finish_cell]
	var cursor := finish_cell
	while cursor != start_cell:
		cursor = came_from[cursor]
		path_cells.append(cursor)
	path_cells.reverse()
	var points: Array[Vector2] = []
	for cell in path_cells:
		points.append(Vector2(cell) * CELL_PIXELS)
	# Cross the open far Room->Corridor threshold and settle well inside the
	# destination room.  The door's graph direction is the authoritative inward
	# direction; no room-center teleport is involved.
	var destination_inside: Vector2i = target_door.get("inside_cell", Vector2i.ZERO)
	var step := _room_step_vector(from_room, target_room_id)
	points.append(Vector2(destination_inside) * CELL_PIXELS)
	points.append(Vector2(destination_inside) * CELL_PIXELS + Vector2(step) * EMPLOYEE_CONFIG.employee_door_exit_distance)
	return points


func _direction_between_rooms(room_a: int, room_b: int) -> StringName:
	if room_a < 0 or room_b < 0 or room_a >= rooms.size() or room_b >= rooms.size():
		return &""
	var delta: Vector2i = rooms[room_b]["center_cell"] - rooms[room_a]["center_cell"]
	if absi(delta.x) >= absi(delta.y):
		return &"right" if delta.x > 0 else &"left"
	return &"bottom" if delta.y > 0 else &"top"


func _door_center_pixels(edge: Dictionary) -> Vector2:
	var center := _door_opening_center_world_position(edge)
	return Vector2(center.x, center.z) * CELL_PIXELS


func _find_physical_door_by_id(requested_door_id: int) -> PhysicalDoor3D:
	if door_root == null or requested_door_id < 0:
		return null
	for child in door_root.get_children():
		var door := child as PhysicalDoor3D
		if door != null and is_instance_valid(door) and int(door.get_meta(&"door_id", -1)) == requested_door_id:
			return door
	return null


func prepare_employee_door_passage(requested_door_id: int, actor_position: Vector2) -> bool:
	var door := _find_physical_door_by_id(requested_door_id)
	if door == null:
		return true
	return door.prepare_enemy_passage(actor_position)


func _door_impact_position_3d(door: PhysicalDoor3D, impact_position_pixels: Vector2) -> Vector3:
	var point := door.get_closest_leaf_point_2d(impact_position_pixels)
	return to_global(Vector3(point.x / CELL_PIXELS, door_height * 0.5, point.y / CELL_PIXELS))


func _iter_physical_doors_near(origin: Vector2, direction: Vector2, radius_pixels: float) -> Array[PhysicalDoor3D]:
	# DoorRoot holds doors and nothing else; the cast is the filter, so a stray
	# child can never reach door-only geometry again.
	var result: Array[PhysicalDoor3D] = []
	if door_root == null:
		return result
	var has_direction := direction.length_squared() > 0.0001
	var normalized_direction := direction.normalized() if has_direction else Vector2.RIGHT
	for child in door_root.get_children():
		var door := child as PhysicalDoor3D
		if door == null or not is_instance_valid(door):
			continue
		var center := door.get_closest_leaf_point_2d(origin)
		var to_door := origin.direction_to(center)
		var distance := origin.distance_to(center)
		if distance > radius_pixels:
			continue
		if has_direction and distance > 0.001 and absf(normalized_direction.angle_to(to_door)) > deg_to_rad(75.0):
			continue
		if _door_proximity_ray == null:
			_door_proximity_ray = PhysicsRayQueryParameters2D.new()
			_door_proximity_ray.collision_mask = WORLD_WALL_LAYER | 8
			_door_proximity_ray.collide_with_bodies = true
			_door_proximity_ray.collide_with_areas = false
		_door_proximity_ray.from = origin
		_door_proximity_ray.to = center
		var hit := player.get_world_2d().direct_space_state.intersect_ray(_door_proximity_ray)
		if not hit.is_empty():
			var blocker: Node = hit.get("collider")
			if int(blocker.get_meta(&"generated_door_id", -1)) != int(door.get_meta(&"door_id", -2)):
				continue
		result.append(door)
	result.sort_custom(func(a: PhysicalDoor3D, b: PhysicalDoor3D) -> bool:
		return origin.distance_squared_to(a.get_closest_leaf_point_2d(origin)) < origin.distance_squared_to(b.get_closest_leaf_point_2d(origin))
	)
	return result


## Explicit player interaction.  Proximity only selects a target; it never
## applies force by itself.  E is routed here after the existing weapon pickup
## resolver has had first refusal on the same input.
func request_player_door_push() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	# E selects the nearest doorway in the interaction envelope; the physical
	# impulse direction is then always derived from Player -> Door, independent
	# of where the mouse is aiming.
	var candidates := _iter_physical_doors_near(player.global_position, Vector2.ZERO, door_interaction_range_pixels)
	if candidates.is_empty():
		return false
	var door := candidates[0]
	var center := door.get_closest_leaf_point_2d(player.global_position)
	return apply_door_impact_to_node(door, center, player.global_position.direction_to(center), door_push_force, &"player_push")


func _get_player_aim_or_move_position() -> Vector2:
	if player == null:
		return Vector2.ZERO
	if player.has_method("get_constrained_aim_position"):
		var aim_variant: Variant = player.call("get_constrained_aim_position")
		if aim_variant is Vector2:
			return aim_variant
	return player.global_position + player.last_move_direction


## Shared attack path for Punch, Kick, and all melee swings.  It returns true
## only when one nearby DoorLeaf accepted the one impact for this attack.
func apply_door_impact_near(origin: Vector2, direction: Vector2, radius_pixels: float, gameplay_force: float, impact_source: StringName, instigator_id: int = 0) -> bool:
	var candidates := _iter_physical_doors_near(origin, direction, radius_pixels)
	if candidates.is_empty():
		return false
	var door := candidates[0]
	var center := door.get_closest_leaf_point_2d(origin)
	return apply_door_impact_to_node(door, center, origin.direction_to(center), gameplay_force, impact_source, -1, instigator_id)


func apply_door_impact_to_node(door: PhysicalDoor3D, impact_position_pixels: Vector2, impact_direction_pixels: Vector2, gameplay_force: float, impact_source: StringName, leaf_index: int = -1, instigator_id: int = 0) -> bool:
	if door == null or not is_instance_valid(door):
		return false
	var impact_position := _door_impact_position_3d(door, impact_position_pixels)
	var impact_direction := global_basis * Vector3(impact_direction_pixels.x, 0.0, impact_direction_pixels.y)
	return door.apply_door_impact(impact_source, impact_position, impact_direction, gameplay_force, impact_source, leaf_index, instigator_id)


## Called by a projectile or thrown body after the 2D collision query identifies
## the mirrored DoorLeaf.  The door stays terminal for that source even when
## locked; the locked door simply rejects the impact and remains solid.
func resolve_door_impact_from_collision(collider: Node, impact_position_pixels: Vector2, impact_direction: Vector2, gameplay_force: float, impact_source: StringName, instigator_id: int = 0) -> bool:
	if collider == null or not collider.has_meta(&"physical_door") or not bool(collider.get_meta(&"physical_door", false)):
		return false
	var door_id := int(collider.get_meta(&"generated_door_id", -1))
	var door := _find_physical_door_by_id(door_id)
	var leaf_index := int(collider.get_meta(&"generated_door_leaf_index", -1))
	return apply_door_impact_to_node(door, impact_position_pixels, impact_direction, gameplay_force, impact_source, leaf_index, instigator_id)


func _position_near_any_door(at_position: Vector2, clearance: float = 48.0) -> bool:
	for edge_variant in door_edges.values():
		if at_position.distance_to(_door_center_pixels(edge_variant)) < clearance:
			return true
	return false


func _content_position_is_clear(at_position: Vector2, radius: float, avoid_doors: bool = true) -> bool:
	var cell := Vector2i(roundi(at_position.x / CELL_PIXELS), roundi(at_position.y / CELL_PIXELS))
	if not floor_cells.has(cell):
		return false
	if not building_rect.has_point(cell):
		return false
	if avoid_doors and _position_near_any_door(at_position, maxf(36.0, radius * 2.0)):
		return false
	# Generated furniture may not yet have reached the physics server this frame.
	# Reserve its actual authored collider, not just a guessed center radius.
	if furniture_root != null:
		for prop in furniture_root.get_children():
			if prop.has_method(&"get_gameplay_footprint_half_extents"):
				var footprint: Variant = prop.call(&"get_gameplay_footprint_half_extents")
				if footprint is Vector2:
					var footprint_collision := prop.get_node_or_null("CollisionShape2D") as CollisionShape2D
					var footprint_center: Vector2 = footprint_collision.global_position if footprint_collision != null else prop.global_position
					var footprint_half := footprint as Vector2
					var delta: Vector2 = at_position - footprint_center
					if absf(delta.x) <= footprint_half.x + radius and absf(delta.y) <= footprint_half.y + radius:
						return false
			else:
				var collider := prop.get_node_or_null("CollisionShape2D") as CollisionShape2D
				if collider != null and collider.shape != null:
					if collider.shape.get_rect().grow(radius).has_point(collider.to_local(at_position)):
						return false
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player != null and player.is_inside_tree() else null
	if space == null:
		return true
	if _placement_clear_query == null:
		_placement_clear_shape = CircleShape2D.new()
		_placement_clear_query = PhysicsShapeQueryParameters2D.new()
		_placement_clear_query.shape = _placement_clear_shape
		_placement_clear_query.collide_with_bodies = true
		_placement_clear_query.collide_with_areas = true
	_placement_clear_shape.radius = maxf(radius, 1.0)
	_placement_clear_query.transform = Transform2D(0.0, at_position)
	_placement_clear_query.collision_mask = WORLD_WALL_LAYER | 8 | 2 | 4
	return space.intersect_shape(_placement_clear_query, 16).is_empty()


## Final furniture placement guard.  The first candidate pass intentionally
## uses a cheap radius, but the instantiated scene is authoritative: re-check
## its scaled ground collider before accepting it so a large bed/cabinet can
## never overlap a wall, door opening, or an already placed prop.
func _furniture_placement_is_clear(furniture: Node2D, room_id: int) -> bool:
	if furniture == null or not is_instance_valid(furniture):
		return false
	if not _room_allows_furniture(room_id):
		return false
	if furniture.has_meta(&"office_furniture_kind"):
		var catalog = preload("res://scripts/dream/office_furniture_catalog.gd")
		var actual_rect: Rect2 = OTXO_ROOM_LAYOUT_PLANNER_SCRIPT._office_rotated_rect(catalog.footprint(String(furniture.get_meta(&"office_furniture_kind"))), furniture.rotation)
		actual_rect.position += furniture.position
		if not _room_bounds_pixels(room_id, 8.0).encloses(actual_rect):
			return false
		for reservation in OTXO_ROOM_LAYOUT_PLANNER_SCRIPT.get_doorway_reservation_rects(_get_room_doors(room_id), CELL_PIXELS):
			if actual_rect.intersects(reservation):
				return false
		for existing in furniture_root.get_children():
			if int(existing.get_meta(&"dream_room_id", -1)) != room_id or not existing.has_meta(&"office_furniture_kind"):
				continue
			var other_rect: Rect2 = OTXO_ROOM_LAYOUT_PLANNER_SCRIPT._office_rotated_rect(catalog.footprint(String(existing.get_meta(&"office_furniture_kind"))), existing.rotation)
			other_rect.position += existing.position
			if actual_rect.grow(-0.5).intersects(other_rect.grow(-0.5)):
				return false
		return true
	var footprint_center := furniture.global_position
	if furniture.has_method(&"get_gameplay_footprint_center"):
		var center_variant: Variant = furniture.call(&"get_gameplay_footprint_center")
		if center_variant is Vector2:
			footprint_center = center_variant
	var cell := Vector2i(roundi(footprint_center.x / CELL_PIXELS), roundi(footprint_center.y / CELL_PIXELS))
	var cell_room_id := int(room_cells.get(cell, -1))
	if _is_elevator_or_corridor_room(cell_room_id):
		return false
	if corridor_cells.has(cell):
		return false
	if elevator_anchor_cell != Vector2i.ZERO and footprint_center.distance_to(Vector2(elevator_anchor_cell) * CELL_PIXELS) < 180.0:
		return false
	if elevator_door_pos_2d != Vector2.ZERO and footprint_center.distance_to(elevator_door_pos_2d) < 180.0:
		return false
	# Ban any furniture within 120px of doors connecting to the corridor or elevator
	for edge_variant in door_edges.values():
		var edge: Dictionary = edge_variant
		var ra := int(edge.get("region_a_id", -1))
		var rb := int(edge.get("region_b_id", -1))
		if _is_elevator_or_corridor_room(ra) or _is_elevator_or_corridor_room(rb):
			if footprint_center.distance_to(_door_center_pixels(edge)) < 120.0:
				return false
	if not furniture.has_method(&"get_gameplay_footprint_half_extents"):
		return true
	var footprint_variant: Variant = furniture.call(&"get_gameplay_footprint_half_extents")
	if not footprint_variant is Vector2:
		return true
	var footprint_half := footprint_variant as Vector2
	var clearance := maxf(footprint_half.x, footprint_half.y)
	var bounds := _room_bounds_pixels(room_id, maxf(content_wall_clearance, clearance + 8.0))
	if bounds.size.x <= 1.0 or not bounds.has_point(footprint_center):
		return false
	if _position_near_any_door(footprint_center, maxf(36.0, clearance * 2.0 + 8.0)):
		return false
	if furniture_root != null:
		for prop in furniture_root.get_children():
			if prop == furniture or not prop.has_method(&"get_gameplay_footprint_half_extents"):
				continue
			var other_variant: Variant = prop.call(&"get_gameplay_footprint_half_extents")
			if not other_variant is Vector2:
				continue
			var other_half := other_variant as Vector2
			var other_center: Vector2 = prop.global_position
			if prop.has_method(&"get_gameplay_footprint_center"):
				var other_center_variant: Variant = prop.call(&"get_gameplay_footprint_center")
				if other_center_variant is Vector2:
					other_center = other_center_variant
			var delta: Vector2 = footprint_center - other_center
			if absf(delta.x) < footprint_half.x + other_half.x + 6.0 and absf(delta.y) < footprint_half.y + other_half.y + 6.0:
				return false
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player != null and player.is_inside_tree() else null
	if space == null:
		return true
	if _furniture_footprint_query == null:
		_furniture_footprint_shape = RectangleShape2D.new()
		_furniture_footprint_query = PhysicsShapeQueryParameters2D.new()
		_furniture_footprint_query.shape = _furniture_footprint_shape
		_furniture_footprint_query.collide_with_bodies = true
		_furniture_footprint_query.collide_with_areas = true
	_furniture_footprint_shape.size = footprint_half * 2.0
	_furniture_footprint_query.transform = Transform2D(0.0, footprint_center)
	_furniture_footprint_query.collision_mask = WORLD_WALL_LAYER | 8 | 2 | 4
	var excluded: Array[RID] = []
	if furniture is CollisionObject2D:
		excluded.append((furniture as CollisionObject2D).get_rid())
	var hurtbox := furniture.get_node_or_null("Hurtbox") as Area2D
	if hurtbox != null:
		excluded.append(hurtbox.get_rid())
	_furniture_footprint_query.exclude = excluded
	return space.intersect_shape(_furniture_footprint_query, 16).is_empty()


func _random_room_position(room_id: int, radius: float, extra_avoid: Array[Vector2] = [], reserve_passage: bool = false) -> Vector2:
	var bounds := _room_bounds_pixels(room_id, maxf(content_wall_clearance, radius + 8.0))
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return Vector2.ZERO
	var usable: Array = rooms[room_id].get("usable_cells", [])
	if usable.is_empty():
		return Vector2.ZERO
	for _attempt in range(96):
		var cell: Vector2i = usable[_content_rng.randi_range(0, usable.size()-1)]
		if reserve_passage and reserved_content_cells.has(cell):
			continue
		var candidate := Vector2(cell) * CELL_PIXELS + Vector2(_content_rng.randf_range(-6,6), _content_rng.randf_range(-6,6))
		if not bounds.has_point(candidate):
			continue
		if not _content_position_is_clear(candidate, radius):
			continue
		var rejected := false
		for other in extra_avoid:
			if candidate.distance_to(other) < radius + 22.0:
				rejected = true
				break
		if not rejected:
			return candidate
	return Vector2.ZERO



func _register_furniture_cutout_bridge(bridge: Node) -> void:
	if bridge == null or not is_instance_valid(bridge):
		return
	var source_value: Variant = bridge.get("source_actor")
	if not is_instance_valid(source_value):
		source_value = bridge.get_meta(&"source_actor", null)
	if not is_instance_valid(source_value):
		return
	var source := source_value as Node2D
	if source == null or not source.is_in_group(&"damageable_props") or source.is_queued_for_deletion():
		return
	_cached_furniture_bridges.append(bridge)


func _spawn_furniture_presentation(furniture: Node2D) -> Node3D:
	if furniture == null or not is_instance_valid(furniture) or actor_depth_bridges_root == null:
		return null
	if furniture.has_meta(&"office_furniture_kind"):
		var office_visual: Node3D = FURNITURE_3D_VISUAL_SCRIPT.new()
		actor_depth_bridges_root.add_child(office_visual)
		office_visual.set_meta(&"dream_room_id", furniture.get_meta(&"dream_room_id", -1))
		office_visual.set_meta(&"source_actor", furniture)
		office_visual.call("configure", furniture, null, null, String(furniture.get_meta(&"office_furniture_kind")))
		if enhanced_room_dressing and not use_authored_office_sample:
			var dressing: Node3D = preload("res://scripts/dream/office_extra_dressing.gd").furniture(String(furniture.get_meta(&"office_furniture_kind")))
			if dressing != null:
				office_visual.visual_instance.add_child(dressing)
		_register_furniture_cutout_bridge(office_visual)
		return office_visual

	var key := ""
	if furniture.scene_file_path != "":
		key = furniture.scene_file_path.get_file().get_basename().to_lower()
	if key == "" and furniture.name != "":
		key = String(furniture.name).to_lower()

	if key != "" and FURNITURE_3D_VISUAL_MAP.has(key):
		var data: Dictionary = FURNITURE_3D_VISUAL_MAP[key]
		var visual: Node3D = FURNITURE_3D_VISUAL_SCRIPT.new()
		actor_depth_bridges_root.add_child(visual)
		visual.set_meta(&"dream_room_id", furniture.get_meta(&"dream_room_id", -1))
		visual.set_meta(&"source_actor", furniture)
		visual.call("configure", furniture, data.get("scene"), data.get("texture"))
		_register_furniture_cutout_bridge(visual)
		return visual

	for map_key in FURNITURE_3D_VISUAL_MAP:
		if key.contains(map_key):
			var data: Dictionary = FURNITURE_3D_VISUAL_MAP[map_key]
			var visual: Node3D = FURNITURE_3D_VISUAL_SCRIPT.new()
			actor_depth_bridges_root.add_child(visual)
			visual.set_meta(&"dream_room_id", furniture.get_meta(&"dream_room_id", -1))
			visual.set_meta(&"source_actor", furniture)
			visual.call("configure", furniture, data.get("scene"), data.get("texture"))
			_register_furniture_cutout_bridge(visual)
			return visual

	var fallback_bridge := _spawn_depth_bridge(furniture, [NodePath("Shadow"), NodePath("Sprite2D")])
	if fallback_bridge != null and fallback_bridge.has_method("enable_furniture_capture_outline"):
		fallback_bridge.call("enable_furniture_capture_outline")
	return fallback_bridge


func _spawn_depth_bridge(
	source: Node2D,
	requested_paths: Variant,
	requested_viewport_offset: Vector2 = Vector2(64.0, 96.0),
	requested_billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED,
	requested_center_height: float = 0.70710678,
	requested_depth_offset: float = -0.70710678,
	requested_plane_rotation: Vector3 = Vector3.ZERO,
	requested_disable_clone_processing: bool = false,
	requested_force_lit: bool = false,
	requested_follow_source_rotation: bool = false,
	requested_register_source_meta: bool = true
) -> Node3D:
	var bridge_started_usec := _startup_profile_clock_usec() if _startup_profile_enabled else 0
	_startup_profile_increment("spawn_depth_bridge_calls")
	if source == null or actor_depth_bridges_root == null or ACTOR_DEPTH_BRIDGE_SCENE == null:
		_startup_profile_record_time("spawn_depth_bridge_ms", bridge_started_usec)
		_startup_profile_increment("spawn_depth_bridge_failures")
		return null
	# Call sites historically pass array literals, whose runtime type is plain
	# Array even when every element is a NodePath.  Normalize at this boundary so
	# the bridge API cannot reject a valid visual-path list with a typed-array
	# mismatch (and keep strings accepted for older callers).
	var capture_paths: Array[NodePath] = []
	var requested_path_list: Array = []
	if requested_paths is Array:
		requested_path_list = requested_paths
	for path_variant in requested_path_list:
		if path_variant is NodePath:
			capture_paths.append(path_variant)
		elif path_variant is String:
			capture_paths.append(NodePath(path_variant))
	if capture_paths.size() > 1 and capture_paths.has(^"Shadow"):
		capture_paths.erase(^"Shadow")
		if not (dynamic_shadows_enabled and (source.is_in_group(&"dream_player") or source.is_in_group(&"dream_enemies"))):
			_spawn_depth_bridge(source, [^"Shadow"], Vector2(64, 64), BaseMaterial3D.BILLBOARD_DISABLED, 0.015, 0.0, Vector3(-PI / 2.0, 0, 0))
	var pooled_kind := &""
	if capture_paths==[^"Sprite2D"] and source.get_script()==preload("res://scripts/entities/environment_debris.gd") and not source.has_node(^"Shadow") and requested_viewport_offset==Vector2(64,64) and requested_billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and requested_center_height==0.02 and requested_depth_offset==0.0 and requested_plane_rotation==Vector3(-PI/2,0,0):
		pooled_kind=&"debris"
	elif source.get_script()==WORLD_WEAPON_PICKUP_SCRIPT and source.has_node(^"Shadow"):
		if capture_paths==[^"WeaponSprite"] and requested_viewport_offset==Vector2(64,96) and requested_billboard_mode==BaseMaterial3D.BILLBOARD_ENABLED and requested_center_height==0.70710678 and requested_depth_offset==-0.70710678 and requested_plane_rotation==Vector3.ZERO: pooled_kind=&"weapon"
		elif capture_paths==[^"Shadow"] and requested_viewport_offset==Vector2(64,64) and requested_billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and requested_center_height==0.015 and requested_depth_offset==0.0 and requested_plane_rotation==Vector3(-PI/2,0,0): pooled_kind=&"shadow"
	if pooled_kind!=&"" and not requested_force_lit and not requested_follow_source_rotation and not bool(get_meta(&"test_legacy_floor_object_capture",false)):
		if gameplay_canvas!=null: gameplay_canvas.visible=false
		var reused: Node3D=_get_floor_object_capture_pool().acquire(source,pooled_kind,camera_3d,dynamic_shadows_enabled,requested_register_source_meta)
		_startup_profile_record_time("spawn_depth_bridge_ms",bridge_started_usec)
		_startup_profile_increment("spawn_depth_bridge_successes")
		return reused
	var bridge := ACTOR_DEPTH_BRIDGE_SCENE.instantiate() as Node3D
	if bridge == null:
		_startup_profile_record_time("spawn_depth_bridge_ms", bridge_started_usec)
		_startup_profile_increment("spawn_depth_bridge_failures")
		return null
	actor_depth_bridges_root.add_child(bridge)
	bridge.set_meta(&"source_actor", source)
	bridge.set("volume_shadow_enabled", dynamic_shadows_enabled)
	# Set the formal camera before the first bridge capture.  Projectile and
	# muzzle carriers use an explicit camera-facing plane, so their initial
	# transform cannot depend on the order in which _process() runs.
	bridge.call("set_world_camera", camera_3d)
	var viewport := bridge.get_node_or_null("ActorDepthViewport") as SubViewport
	var render_root := bridge.get_node_or_null("ActorDepthViewport/ActorDepthRenderRoot") as Node2D
	if viewport == null or render_root == null or not bridge.has_method("configure"):
		bridge.queue_free()
		_startup_profile_record_time("spawn_depth_bridge_ms", bridge_started_usec)
		_startup_profile_increment("spawn_depth_bridge_failures")
		return null
	if requested_viewport_offset.x >= 96.0:
		viewport.size = Vector2i(requested_viewport_offset * 2.0)
	bridge.call(
		"configure",
		source,
		viewport,
		render_root,
		gameplay_canvas,
		capture_paths,
		requested_center_height,
		requested_depth_offset,
		requested_viewport_offset,
		requested_billboard_mode,
		requested_plane_rotation,
		requested_disable_clone_processing,
		requested_force_lit,
		requested_follow_source_rotation
	)
	# Keep room ownership on the presentation bridge as well as the gameplay
	# source.  Room activation can then wake only the affected furniture
	# captures instead of refreshing every static bridge in the dungeon.
	if source.has_meta(&"dream_room_id"):
		bridge.set_meta(&"dream_room_id", int(source.get_meta(&"dream_room_id", -1)))
	if source.has_meta(&"content_kind"):
		bridge.set_meta(&"content_kind", source.get_meta(&"content_kind"))
	# bridge 的 2D capture 走 SubViewport，自身所在 Viewport 拿不到正式 3D 相机；
	# 显式把正式 World Camera 交给桥，供 on-screen / projection 判断使用。
	bridge.call("set_world_camera", camera_3d)
	# 后生成的投影体也要登记，否则它不会投进 capture。
	if requested_register_source_meta and not (capture_paths.size() == 1 and capture_paths[0] == ^"Shadow"):
		source.set_meta(&"depth_visual_bridge", weakref(bridge))
	if source.is_in_group(&"damageable_props"):
		_register_furniture_cutout_bridge(bridge)
	_startup_profile_record_time("spawn_depth_bridge_ms", bridge_started_usec)
	_startup_profile_increment("spawn_depth_bridge_successes")
	return bridge


## Builds a small, independent unlit carrier for a visual-only effect such as
## ranged enemy windup. The actor's normal lit bridge deliberately skips children
## tagged `depth_visual_unlit`; keeping this bridge local avoids changing the
## main actor bridge contract or its shadow proxy.
func ensure_unlit_actor_visual_bridge(source: Node2D, source_path: NodePath) -> Node3D:
	if source == null or not is_instance_valid(source):
		return null
	var stored: Variant = null
	if source.has_meta(&"unlit_charge_depth_bridge"):
		stored = source.get_meta(&"unlit_charge_depth_bridge")
	if stored is WeakRef:
		var existing: Variant = stored.get_ref()
		if existing is Node3D and is_instance_valid(existing):
			return existing
	if source.get_node_or_null(source_path) == null:
		return null
	var bridge := _spawn_depth_bridge(
		source,
		[source_path],
		Vector2(64.0, 96.0),
		BaseMaterial3D.BILLBOARD_ENABLED,
		0.70710678,
		-0.70710678,
		Vector3.ZERO,
		true,
		false,
		false,
		false
	)
	if bridge != null and is_instance_valid(bridge):
		source.set_meta(&"unlit_charge_depth_bridge", weakref(bridge))
	return bridge


## Public bridge entry for short-lived formal 2D effects (for example enemy
## body parts).  Gameplay owners remain the source of truth; this only routes
## their current visual into the already-created depth viewport.
func register_depth_visual(source: Node2D, paths: Array = [NodePath("Sprite2D")]) -> Node3D:
	if source == null:
		return null
	var normalized_paths: Array[NodePath] = []
	for path_variant in paths:
		if path_variant is NodePath:
			normalized_paths.append(path_variant)
		elif path_variant is String:
			normalized_paths.append(NodePath(path_variant))
	if normalized_paths.is_empty():
		normalized_paths.append(NodePath("Sprite2D"))
	return _spawn_depth_bridge(source, normalized_paths)


func _spawn_actor_physics_proxy(source: Node2D, push_doors: bool = true) -> AnimatableBody3D:
	if source == null or actor_physics_proxies_root == null:
		return null
	var proxy := AnimatableBody3D.new()
	proxy.name = "%sDoorProxy" % source.name
	# Intent adapter only. Passive 3D contact must never unlatch/push a door.
	proxy.collision_layer = 0
	proxy.collision_mask = 0
	proxy.sync_to_physics = true
	proxy.set_script(ACTOR_PROXY_SCRIPT)
	actor_physics_proxies_root.add_child(proxy)
	proxy.set_meta(&"source_actor", source)
	proxy.set("push_doors", push_doors)
	proxy.set("source_path", proxy.get_path_to(source))
	source.tree_exiting.connect(proxy.queue_free, CONNECT_ONE_SHOT)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.0, 0.6)
	shape_node.shape = shape
	proxy.add_child(shape_node)
	return proxy


## Screen -> fixed Camera3D ground ray -> existing 2D gameplay coordinates.
func get_gameplay_aim_position() -> Vector2:
	var mouse: Vector2 = player.get_presentation_pointer_position()
	var origin := camera_3d.project_ray_origin(mouse)
	var direction := camera_3d.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if point is Vector3:
		var map_point := to_local(point)
		return Vector2(map_point.x, map_point.z) * CELL_PIXELS
	return player.global_position + player.last_aim_direction * 100.0


func _spawn_boss_key() -> void:
	if key_room_id < 0 or key_root == null or BOSS_KEY_SCENE == null:
		return
	if lazy_room_presentation and current_room_id != key_room_id:
		return
	if has_boss_key or (key_pickup != null and is_instance_valid(key_pickup)):
		return
	var center := Vector2(rooms[key_room_id]["center_cell"]) * CELL_PIXELS + Vector2(CELL_PIXELS * 0.5, CELL_PIXELS * 0.5)
	var position := _random_room_position(key_room_id, 8.0, [player.global_position if player != null else Vector2.ZERO])
	if position == Vector2.ZERO:
		position = center
	var key := BOSS_KEY_SCENE.instantiate() as Node2D
	if key == null:
		return
	key_root.add_child(key)
	key.global_position = position
	key.set_meta(&"dream_room_id", key_room_id)
	key.set_meta(&"content_kind", &"boss_key")
	if key.has_method("configure"):
		key.call("configure", self, key_room_id)
	key_pickup = key
	_spawn_depth_bridge(key, [NodePath("KeyVisual")])


func _spawn_employee_badge(
	at_position: Vector2,
	source_room_id: int = -1,
	generation_token: int = -1
) -> void:
	# Death signals are emitted from the physics/death path.  The deferred call
	# keeps Area2D creation and bridge registration outside the physics query
	# flush, and the generation token prevents an old floor from leaking a badge
	# into a newly regenerated one.
	if generation_token >= 0 and generation_token != _layout_generation:
		return
	if key_root == null or EMPLOYEE_BADGE_SCENE == null or has_floor_badge:
		badge_drop_pending = false
		return
	if floor_badge_pickup != null and is_instance_valid(floor_badge_pickup):
		badge_drop_pending = false
		return
	var room_id := source_room_id if source_room_id >= 0 else _room_id_at_position(at_position)
	if room_id < 0 or room_id >= rooms.size():
		badge_drop_pending = false
		return
	if not at_position.is_finite():
		at_position = Vector2(rooms[room_id].get("center_cell", Vector2i.ZERO)) * CELL_PIXELS
	var badge := EMPLOYEE_BADGE_SCENE.instantiate() as Node2D
	if badge == null:
		badge_drop_pending = false
		return
	badge.name = "EmployeeBadgePickup"
	badge.global_position = at_position
	badge.set_meta(&"dream_room_id", room_id)
	badge.set_meta(&"content_kind", &"employee_badge")
	badge.set_meta(&"employee_badge", true)
	key_root.add_child(badge)
	# Area2D pickup physics remains intentionally passive; the shared E resolver
	# owns collection and the badge does not become a solid world obstacle.
	badge.global_position = at_position
	if badge.has_method("configure"):
		badge.call("configure", self, room_id)
	_spawn_depth_bridge(badge, [NodePath("KeyVisual")])
	floor_badge_pickup = badge
	badge_drop_pending = false
	badge_drop_committed = true

	if badge_marker != null and is_instance_valid(badge_marker):
		badge_marker.queue_free()
		badge_marker = null
	_set_room_content_active(room_id, room_id == current_room_id)
	last_validation_report["badge_pickup_spawned"] = true
	last_validation_report["badge_marker_spawned"] = badge_marker != null and is_instance_valid(badge_marker)


func _on_badge_carrier_defeated(at_position: Vector2, _legacy_drop_count: int, employee: Node) -> void:
	if badge_drop_committed or badge_drop_pending or has_floor_badge:
		return
	if employee == null or not is_instance_valid(employee) or not bool(employee.get_meta(&"employee_badge_carrier", false)):
		return
	badge_drop_pending = true
	var drop_position := at_position
	var cached_position: Variant = employee.get("death_origin_gameplay_position")
	if cached_position is Vector2 and (cached_position as Vector2).is_finite():
		drop_position = cached_position
	var room_id := int(employee.get_meta(&"dream_room_id", -1))
	var cached_room: Variant = employee.get("death_origin_room_id")
	if room_id < 0 and cached_room is int:
		room_id = int(cached_room)
	call_deferred("_spawn_employee_badge", drop_position, room_id, _layout_generation)


func _spawn_room_furniture(room_filter: int = -1) -> void:
	if furniture_root == null or FURNITURE_SCENE_PATHS.is_empty():
		return
	var furniture_scenes: Array[PackedScene] = []
	for scene_path in FURNITURE_SCENE_PATHS:
		var loaded := load(scene_path) as PackedScene
		if loaded != null:
			furniture_scenes.append(loaded)
	if furniture_scenes.is_empty():
		return
	var is_otxo := _is_otxo_mansion()
	for room in rooms:
		var room_id := int(room["id"])
		if room_filter >= 0 and room_id != room_filter:
			continue
		if room_filter >= 0 and furniture_root != null:
			var room_already_spawned := false
			for existing_variant in furniture_root.get_children():
				var existing := existing_variant as Node2D
				if existing != null and int(existing.get_meta(&"dream_room_id", -1)) == room_id:
					room_already_spawned = true
					break
			if room_already_spawned:
				continue
		if room_id == boss_room_id:
			continue
		if not _room_allows_furniture(room_id):
			continue
		var rect: Rect2i = room["grid_rect"]
		var desired: int
		if is_otxo:
			var base_desired := clampi(roundi(float(room.usable_cells.size()) * furniture_density * 1.8), 3, 6)
			desired = base_desired
		else:
			var base_desired := clampi(roundi(float(room.usable_cells.size()) * furniture_density), min_furniture_per_room, max_furniture_per_room)
			desired = base_desired * 2

		var room_scenes: Array[PackedScene] = []
		if is_otxo:
			var archetype: String = String(room.get("archetype", ""))
			var scene_paths: Array = ARCHETYPE_FURNITURE_MAP.get(archetype, FURNITURE_SCENE_PATHS)
			for p in scene_paths:
				var sc := load(p) as PackedScene
				if sc != null:
					room_scenes.append(sc)
		if room_scenes.is_empty():
			room_scenes = furniture_scenes

		if is_otxo:
			var plan := _plan_otxo_room_layout(room_id)
			if bool(plan.get("success", false)):
				for item in plan.get("furniture_placements", []):
					var furniture_scene: PackedScene = item.get("scene", null)
					if furniture_scene == null and item.has("scene_path"):
						furniture_scene = load(String(item["scene_path"])) as PackedScene
					if furniture_scene == null:
						continue
					var position: Vector2 = item.get("position", Vector2.ZERO)
					var furniture := furniture_scene.instantiate() as Node2D
					if furniture == null:
						continue
					furniture.position = position
					furniture.global_position = position
					if item.has("office_kind"):
						preload("res://scripts/dream/office_furniture_catalog.gd").configure(furniture, String(item.office_kind))
					furniture.rotation = float(item.get("rotation", 0.0))
					if not _furniture_placement_is_clear(furniture, room_id):
						furniture.free()
						continue
					furniture_root.add_child(furniture)
					if furniture is CollisionObject2D:
						PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(furniture.rotation, position))
						if furniture is RigidBody2D:
							PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
							PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
					furniture.set_meta(&"dream_room_id", room_id)
					furniture.set_meta(&"office_art_review", String(room.get("sample_key", "")) in OFFICE_SAMPLE_SCRIPT.ART_REVIEW_ROOMS)
					furniture.set_meta(&"office_pixel_sample", bool(room.get("authored_sample", false)) and String(room.get("sample_key", "")) == "office")
					furniture.set_meta(&"office_visual_style", &"approved_office" if String(room.get("archetype", "")) == "open_office" else &"approved_room")
					furniture.set_meta(&"content_kind", &"furniture")
					if furniture.has_method("set_room_runtime_active"):
						furniture.call("set_room_runtime_active", true)
					if furniture.has_method("reset_spawn_physics"):
						furniture.call("reset_spawn_physics")
					furniture_count += 1
					_spawn_furniture_presentation(furniture)
				continue
			if bool(room.get("office_combat_layout", false)):
				push_error("Office combat template rejected for room %d; legacy random furniture fallback is disabled." % room_id)
				continue

		var placed: Array[Vector2] = []
		if room_id == spawn_room_id:
			placed.append(Vector2(spawn_cell) * CELL_PIXELS)
		# Keep the required key pickup readable when the key room also receives
		# furniture.  The physics space is not guaranteed to have flushed newly
		# added Areas in this same frame, so reserve the key explicitly.
		if key_pickup != null and is_instance_valid(key_pickup) and int(key_pickup.get_meta(&"dream_room_id", -1)) == room_id:
			placed.append(key_pickup.global_position)
		var room_spawned := 0
		for _index in range(desired * 4):
			if room_spawned >= desired:
				break
			var position := _random_room_position(room_id, 18.0, placed, true)
			if position == Vector2.ZERO:
				position = _random_room_position(room_id, 14.0, placed, true)
			if position == Vector2.ZERO:
				break
			var furniture_scene: PackedScene = room_scenes[_content_rng.randi_range(0, room_scenes.size() - 1)]
			var furniture := furniture_scene.instantiate() as Node2D
			if furniture == null:
				continue
			furniture.position = position
			furniture.global_position = position
			furniture_root.add_child(furniture)
			if furniture is CollisionObject2D:
				PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
				if furniture is RigidBody2D:
					PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
					PhysicsServer2D.body_set_state(furniture.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
			var collider := furniture.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if not _furniture_placement_is_clear(furniture, room_id):
				furniture.free()
				continue
			if room_id == spawn_room_id and position.distance_to(Vector2(spawn_cell) * CELL_PIXELS) < 40.0:
				furniture.free()
				continue
			var blocks_route := false
			if furniture.has_method(&"get_gameplay_footprint_half_extents"):
				var footprint: Variant = furniture.call(&"get_gameplay_footprint_half_extents")
				if footprint is Vector2:
					var footprint_center: Vector2 = collider.global_position if collider != null else furniture.global_position
					var footprint_half := footprint as Vector2
					for cell in reserved_content_cells:
						var cell_position := Vector2(cell) * CELL_PIXELS
						var delta: Vector2 = cell_position - footprint_center
						if absf(delta.x) <= footprint_half.x + 10.0 and absf(delta.y) <= footprint_half.y + 10.0:
							blocks_route = true
							break
			elif collider != null and collider.shape != null:
				for cell in reserved_content_cells:
					if collider.shape.get_rect().grow(10.0).has_point(collider.to_local(Vector2(cell)*CELL_PIXELS)):
						blocks_route = true
						break
			if blocks_route:
				furniture.free()
				continue
			furniture.set_meta(&"dream_room_id", room_id)
			furniture.set_meta(&"content_kind", &"furniture")
			if is_otxo and furniture.has_method("set_room_runtime_active"):
				furniture.call("set_room_runtime_active", true)
			if furniture.has_method("reset_spawn_physics"):
				furniture.call("reset_spawn_physics")
			placed.append(position)
			furniture_count += 1
			room_spawned += 1
			_spawn_furniture_presentation(furniture)


func _spawn_regular_employee(room_id: int, position: Vector2, enemy_type: StringName = &"employee", badge_carrier: bool = false, weapon_id: String = "", skin_index: int = 0) -> EmployeeEnemy:
	if enemy_root == null or EMPLOYEE_SCENE == null:
		return null
	var employee := EMPLOYEE_SCENE.instantiate() as EmployeeEnemy
	if employee == null:
		return null
	employee.position = position
	employee.global_position = position
	enemy_root.add_child(employee)
	if employee is CollisionObject2D:
		PhysicsServer2D.body_set_state(employee.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, position))
	if employee.has_method("configure_archetype"):
		employee.call("configure_archetype", enemy_type)
	employee.set_meta(&"dream_room_id", room_id)
	employee.set_meta(&"content_kind", &"employee_enemy")
	employee.set_meta(&"enemy_type", enemy_type)
	employee.set_meta(&"employee_badge_carrier", badge_carrier)
	if employee.has_method("configure"):
		employee.call("configure", player, config.base_enemy_health, 0.0, _room_bounds_pixels(room_id, 10.0), config.enemy_separation_strength, config.enemy_separation_radius, config)
	if employee.has_method("set_room_bounds"):
		employee.call("set_room_bounds", _room_bounds_pixels(room_id, 2.0))
	if enemy_type == &"waitress" and employee.has_method("equip_weapon"):
		# Waitress is authored with the formal Books weapon.  This does not add a
		# second AI or weapon implementation and the Books pickup remains valid.
		employee.call("equip_weapon", "books", 0)
	elif employee.has_method("equip_weapon"):
		if weapon_id.is_empty() and _is_otxo_mansion():
			var pool := _employee_weapon_pool()
			var equip_rng := RandomNumberGenerator.new()
			equip_rng.seed = _derive_enemy_equip_seed(room_id, enemy_count)
			weapon_id = pool[equip_rng.randi_range(0, pool.size() - 1)]
		if not weapon_id.is_empty():
			employee.call("equip_weapon", weapon_id, skin_index)
	if employee.has_signal("defeated") and not employee.defeated.is_connected(_on_enemy_defeated):
		employee.defeated.connect(_on_enemy_defeated)
	if badge_carrier and employee.has_signal("defeated"):
		var badge_handler := _on_badge_carrier_defeated.bind(employee)
		if not employee.defeated.is_connected(badge_handler):
			employee.defeated.connect(badge_handler, CONNECT_ONE_SHOT)
	if employee.has_signal("weapon_drop_requested"):
		var drop_handler := _on_employee_weapon_drop_requested.bind(employee)
		if not employee.weapon_drop_requested.is_connected(drop_handler):
			employee.weapon_drop_requested.connect(drop_handler)
	enemy_count += 1
	_spawn_depth_bridge(employee, [NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot")])
	_spawn_actor_physics_proxy(employee, true)
	_cache_actor_occlusion_bounds(employee)
	if not _is_otxo_mansion() and employee.has_method("start_sky_drop"):
		employee.call("start_sky_drop")
	return employee


func _spawn_room_enemies() -> void:
	if enemy_root == null or EMPLOYEE_SCENE == null:
		return
	for room in rooms:
		if enemy_count >= effective_global_enemy_cap:
			break
		var room_id := int(room["id"])
		if room_id == spawn_room_id or room_id == boss_room_id or not _is_combat_room(room):
			continue
		var desired := clampi(
			maxi(roundi(float(room.usable_cells.size()) * enemy_density), _room_enemy_minimum(room)),
			_room_enemy_minimum(room),
			_effective_room_enemy_max(room)
		)
		var placed: Array[Vector2] = []
		# Reserve already spawned content explicitly instead of relying only on a
		# physics query before the first physics flush.
		if key_pickup != null and is_instance_valid(key_pickup) and int(key_pickup.get_meta(&"dream_room_id", -1)) == room_id:
			placed.append(key_pickup.global_position)
		if furniture_root != null:
			for furniture_variant in furniture_root.get_children():
				var furniture := furniture_variant as Node2D
				if furniture != null and int(furniture.get_meta(&"dream_room_id", -1)) == room_id:
					placed.append(furniture.global_position)
		for _index in range(desired):
			if enemy_count >= effective_global_enemy_cap:
				break
			var position := _random_room_position(room_id, 10.0, placed)
			if position == Vector2.ZERO:
				break
			var employee := _spawn_regular_employee(
				room_id,
				position,
				&"employee",
				room_id == badge_carrier_room_id and _index == badge_carrier_spawn_index
			)
			if employee == null:
				continue
			placed.append(position)


func _enemy_population_interval() -> float:
	if config == null:
		return 3.0
	return maxf(float(config.employee_population_refill_interval), 0.25)


func _enemy_population_target() -> int:
	if config == null:
		return maxi(0, global_enemy_cap)
	return mini(
		int(config.employee_global_population_target),
		mini(global_enemy_cap, int(config.maximum_enemies))
	)


func _get_alive_employee_count() -> int:
	if enemy_root == null:
		return 0
	var alive := 0
	for enemy_variant in enemy_root.get_children():
		var employee := enemy_variant as EmployeeEnemy
		# Boss is a one-shot progression actor, not part of the formal global
		# Employee population target.  Counting it here would make a lethal hit
		# appear fully replenished and would suppress the regular refill tick.
		if (
			employee != null
			and is_instance_valid(employee)
			and employee.get("dead") != true
			and employee.get_meta(&"content_kind", &"employee_enemy") != &"boss"
		):
			alive += 1
	return alive


func _get_alive_employee_count_in_room(room_id: int) -> int:
	if enemy_root == null:
		return 0
	var alive := 0
	for enemy_variant in enemy_root.get_children():
		var employee := enemy_variant as EmployeeEnemy
		if (
			employee != null
			and is_instance_valid(employee)
			and employee.get("dead") != true
			and employee.get_meta(&"content_kind", &"employee_enemy") != &"boss"
			and int(employee.get_meta(&"dream_room_id", -1)) == room_id
		):
			alive += 1
	return alive


func _count_room_enemies(room_id: int) -> int:
	"""Count every live enemy in a room, including the separately tagged Boss."""
	if enemy_root == null:
		return 0
	var alive := 0
	for enemy_variant in enemy_root.get_children():
		var employee := enemy_variant as EmployeeEnemy
		if (
			employee != null
			and is_instance_valid(employee)
			and employee.get("dead") != true
			and int(employee.get_meta(&"dream_room_id", -1)) == room_id
		):
			alive += 1
	return alive


func _is_population_position_visible(position: Vector2) -> bool:
	if camera_3d == null or not is_instance_valid(camera_3d):
		return false
	var world_position := to_global(_map_gameplay_to_world(position))
	if camera_3d.is_position_behind(world_position):
		return false
	return get_viewport().get_visible_rect().grow(96.0).has_point(camera_3d.unproject_position(world_position))


func _population_candidate_rooms() -> Array[int]:
	var candidates: Array[int] = []
	var current_room := get_current_room_id()
	for room in rooms:
		var room_id := int(room.get("id", -1))
		var room_type: StringName = room.get("room_type", &"normal")
		if (
			room_id < 0
			or room_id == spawn_room_id
			or room_id == boss_room_id
			or room_id == current_room
			or room_type in [&"spawn", &"start", &"boss", &"elevator_lobby", &"corridor", &"reception", &"main_lobby"]
			or not _is_combat_room(room)
		):
			continue
		if float(enemy_population_breathing_left.get(room_id, 0.0)) > 0.0:
			continue
		if _get_alive_employee_count_in_room(room_id) >= max_enemies_per_room:
			continue
		var center := Vector2(room.get("center_cell", Vector2i.ZERO)) * CELL_PIXELS
		if _is_population_position_visible(center):
			continue
		candidates.append(room_id)
	return candidates


func _find_population_spawn_position(room_id: int) -> Vector2:
	var avoid: Array[Vector2] = []
	if player != null and is_instance_valid(player):
		avoid.append(player.global_position)
	if enemy_root != null:
		for enemy_variant in enemy_root.get_children():
			var employee := enemy_variant as EmployeeEnemy
			if employee != null and is_instance_valid(employee) and employee.get("dead") != true:
				if int(employee.get_meta(&"dream_room_id", -1)) == room_id:
					avoid.append(employee.global_position)
	for _attempt in range(32):
		var candidate := _random_room_position(room_id, 10.0, avoid, true)
		if candidate == Vector2.ZERO:
			continue
		if player != null and is_instance_valid(player):
			var minimum_distance := maxf(float(config.enemy_minimum_spawn_distance), 96.0)
			if candidate.distance_to(player.global_position) < minimum_distance:
				continue
		if _is_population_position_visible(candidate):
			continue
		return candidate
	return Vector2.ZERO


func _choose_population_room() -> int:
	var candidates := _population_candidate_rooms()
	if candidates.is_empty():
		return -1
	var selected := -1
	var best_score := -INF
	for room_id in candidates:
		var deficit := max_enemies_per_room - _get_alive_employee_count_in_room(room_id)
		var score := float(deficit) + _content_rng.randf_range(0.0, 0.75)
		if score > best_score:
			best_score = score
			selected = room_id
	return selected


func _spawn_population_enemy() -> bool:
	var room_id := _choose_population_room()
	if room_id < 0:
		return false
	var position := _find_population_spawn_position(room_id)
	if position == Vector2.ZERO:
		return false
	var spawned := _spawn_regular_employee(room_id, position)
	if spawned == null:
		return false
	if config != null:
		enemy_population_breathing_left[room_id] = maxf(
			float(config.employee_room_breathing_seconds),
			0.0
		)
	return true


func _update_enemy_population(delta: float) -> void:
	# Production Random Dream encounters are one-shot per room.  Keep the legacy
	# helper for old diagnostics/API compatibility, but never replenish enemies
	# after an encounter has been activated or cleared.
	return
	#if false:
	if not enable_enemy_population_refill or not spawn_content or enemy_root == null or rooms.is_empty():
		return
	for room_id_variant in enemy_population_breathing_left.keys():
		var room_id := int(room_id_variant)
		enemy_population_breathing_left[room_id] = maxf(
			0.0,
			float(enemy_population_breathing_left[room_id]) - delta
		)
	enemy_population_refill_left = maxf(enemy_population_refill_left - delta, 0.0)
	if enemy_population_refill_left > 0.0:
		return
	enemy_population_refill_left = _enemy_population_interval()
	var target := _enemy_population_target()
	var alive := _get_alive_employee_count()
	if target <= 0 or alive >= target:
		return
	var missing := target - alive
	var batch_limit := maxi(1, int(config.employee_population_refill_batch)) if config != null else 1
	var batch_max := mini(batch_limit, missing)
	var batch := _content_rng.randi_range(1, batch_max) if batch_max > 0 else 0
	for _index in range(batch):
		if _get_alive_employee_count() >= target:
			break
		if not _spawn_population_enemy():
			break
	#endif


func _on_player_weapon_fired(_recoil_multiplier: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var weapon_id := String(player.get("selected_weapon_id"))
	if not WEAPON_VISUALS.has_firearm(weapon_id):
		return
	notify_gunshot(player.global_position, get_current_room_id())


func _is_pickup_weapon_id_allowed(weapon_id: String) -> bool:
	return WEAPON_VISUALS.has_weapon(weapon_id)


func _on_employee_weapon_drop_requested(
	weapon_id: String,
	at_position: Vector2,
	impulse: Vector2,
	skin_index: int,
	employee: Node
) -> void:
	if not _is_pickup_weapon_id_allowed(weapon_id) or world_weapon_root == null:
		return
	var pickup := WORLD_WEAPON_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	world_weapon_root.add_child(pickup)
	if pickup.has_method("set_weapon_id"):
		pickup.call("set_weapon_id", weapon_id, skin_index)
	else:
		pickup.set("weapon_id", weapon_id)
		pickup.set("skin_index", WEAPON_VISUALS.normalize_skin_index(weapon_id, skin_index))
	pickup.set("interaction_radius", EMPLOYEE_CONFIG.world_weapon_interaction_radius)
	pickup.set("mass", WEAPON_VISUALS.get_world_mass(weapon_id))
	var room_id := get_room_id_for_node(employee) if employee != null else _room_id_at_position(at_position)
	var drop_from_pit := pit_cells.has(_cell_for_gameplay_position(at_position))
	if drop_from_pit:
		# A pit is not a pickup surface. Resolve the held weapon to the nearest
		# authored floor cell, then let the pickup's existing fake-height landing
		# presentation make it visibly spring out of the hole.
		at_position = _nearest_safe_floor_world_position(_cell_for_gameplay_position(at_position))
		if employee != null:
			room_id = int(employee.get_meta(&"dream_room_id", room_id))
	pickup.set_meta(&"dream_room_id", room_id)
	var drop_direction := impulse.normalized() if impulse.length_squared() > 0.001 else Vector2.RIGHT
	# Pit recovery resolves the gameplay body directly onto a safe floor cell;
	# keep that authoritative landing point instead of applying a second
	# horizontal impulse that could throw the pickup back over the pit.
	pickup.global_position = at_position if drop_from_pit else (
		at_position + drop_direction * 12.0 + drop_direction.orthogonal() * _content_rng.randf_range(-4.0, 4.0)
	)
	if drop_from_pit and pickup.has_method("start_sky_drop"):
		pickup.call("start_sky_drop", 84.0)
	if not drop_from_pit and impulse.length_squared() > 0.0 and pickup.has_method("place_after_swap"):
		pickup.call_deferred("place_after_swap", pickup.global_position, impulse)
	_spawn_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])


func _spawn_native_damage_number(
	world_anchor: Vector2,
	enemy_id: int,
	is_critical: bool,
	amount: int = 0,
	screen_offset: Vector2 = Vector2.ZERO
) -> Node2D:
	if native_damage_numbers_root == null or not is_instance_valid(native_damage_numbers_root):
		return null
	var holder := Node2D.new()
	holder.name = "DamageNumberAnchor"
	holder.z_index = 10
	holder.set_meta(&"damage_owner_id", enemy_id)
	native_damage_numbers_root.add_child(holder)
	var number := preload("res://scenes/ui/damage_number.tscn").instantiate() as Node2D
	if number == null:
		holder.queue_free()
		return null
	holder.add_child(number)
	native_damage_number_anchors.append({
		"holder": holder,
		"world_position": world_anchor,
		"screen_offset": screen_offset,
	})
	if is_critical:
		number.call("activate", Vector2.ZERO)
	else:
		number.call("activate_total", Vector2.ZERO, amount)
	# DamageNumber.activate* writes global_position for the old world-space
	# carrier.  Reset only the child local position; the holder owns the native
	# screen projection while the child keeps its original rise/fade animation.
	number.position = Vector2.ZERO
	number.finished.connect(_on_native_damage_number_finished.bind(holder), CONNECT_ONE_SHOT)
	return number


func _on_native_damage_number_finished(holder: Node2D) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var owner_id := int(holder.get_meta(&"damage_owner_id", -1))
	var number := holder.get_node_or_null("DamageNumber") as Node2D
	var existing: Variant = damage_totals.get(owner_id)
	if existing is WeakRef and existing.get_ref() == number:
		damage_totals.erase(owner_id)
	for index in range(native_damage_number_anchors.size() - 1, -1, -1):
		var record: Dictionary = native_damage_number_anchors[index]
		if record.get("holder") == holder:
			native_damage_number_anchors.remove_at(index)
			break
	holder.queue_free()


func _update_native_damage_number_projections() -> void:
	if camera_3d == null or not is_instance_valid(camera_3d):
		return
	for index in range(native_damage_number_anchors.size() - 1, -1, -1):
		var record: Dictionary = native_damage_number_anchors[index]
		var holder := record.get("holder") as Node2D
		if holder == null or not is_instance_valid(holder):
			native_damage_number_anchors.remove_at(index)
			continue
		var anchor: Vector2 = record.get("world_position", Vector2.ZERO)
		var world_position := Vector3(
			anchor.x / CELL_PIXELS,
			0.05,
			anchor.y / CELL_PIXELS
		)
		var visible_on_screen := not camera_3d.is_position_behind(world_position)
		if visible_on_screen:
			var screen_offset: Vector2 = record.get("screen_offset", Vector2.ZERO)
			holder.position = player.get_presentation_hud_position(camera_3d.unproject_position(world_position)) + screen_offset
			holder.visible = true
		else:
			holder.visible = false


func _on_enemy_defeated(at_position: Vector2, _legacy_drop_count: int = 1) -> void:
	var kill_dir := (at_position - player.global_position).normalized() if (player != null and is_instance_valid(player) and player.global_position.distance_squared_to(at_position) > 0.01) else Vector2.RIGHT
	request_camera_impulse(&"heavy", kill_dir)
	var defeated_room_id := _room_id_at_position(at_position)
	if defeated_room_id < 0 and enemy_root != null:
		# Death signals are emitted after the source has already been moved by its
		# final impact; prefer the authored home room when the cell is a corridor.
		for enemy_variant in enemy_root.get_children():
			var enemy := enemy_variant as EmployeeEnemy
			if enemy != null and is_instance_valid(enemy) and enemy.get("dead") == true and enemy.global_position.distance_to(at_position) < 1.0:
				defeated_room_id = int(enemy.get_meta(&"dream_room_id", -1))
				break
	if run_interface != null:
		run_interface.record_kill()
	# Clearing is a Room-state transition, not an XP-pickup side effect.  Schedule
	# it before any optional reward early-return so headless runs, custom reward
	# pools and teardown cannot leave an otherwise empty combat room ACTIVE.
	if defeated_room_id >= 0:
		call_deferred("mark_room_cleared", defeated_room_id)


func collect_boss_key(_key: Node) -> void:
	if has_boss_key:
		return
	has_boss_key = true
	if boss_door_node != null and is_instance_valid(boss_door_node):
		boss_door_node.set_locked(false)
		boss_door_node.set_meta(&"boss_locked", false)
	if key_pickup != null and is_instance_valid(key_pickup):
		key_pickup.queue_free()
	key_pickup = null
	_set_transition_runtime_active()
	last_validation_report["has_boss_key"] = true
	last_validation_report["boss_door_unlocked"] = true


func collect_employee_badge(badge: Node = null) -> void:
	if has_floor_badge:
		return
	has_floor_badge = true
	var pickup := badge if badge != null and is_instance_valid(badge) else floor_badge_pickup
	if pickup != null and is_instance_valid(pickup):
		pickup.queue_free()
	floor_badge_pickup = null
	if badge_marker != null and is_instance_valid(badge_marker):
		badge_marker.queue_free()
	badge_marker = null
	elevator_state = &"UNLOCKED"
	_set_elevator_runtime_active()
	# Acquiring the floor badge plays the airy long-tail cue.  This function is
	# the only place `has_floor_badge` becomes true, and it returns early above,
	# so the cue fires exactly once per floor.
	if SFX != null:
		SFX.play_event(&"elevator_badge")
	last_validation_report["has_floor_badge"] = true
	last_validation_report["badge_pickup_spawned"] = false
	last_validation_report["badge_marker_spawned"] = false


func is_boss_door_locked() -> bool:
	if boss_door_node != null and is_instance_valid(boss_door_node):
		return boss_door_node.is_locked()
	# Lazy presentation may not have instantiated the Boss door yet.  The key
	# state remains the logical lock authority until the Boss room is loaded.
	return boss_door_id >= 0 and not has_boss_key


func get_content_validation_report() -> Dictionary:
	return {
		"furniture_count": furniture_count,
		"enemy_count": enemy_count,
		"alive_enemy_count": _get_alive_employee_count(),
		"enemy_population_target": _enemy_population_target(),
		"enemy_population_refill_interval": _enemy_population_interval(),
		"enemy_population_refill_enabled": false,
		"continuous_refill_disabled": true,
		"room_states": room_states.duplicate(true),
		"revealed_room_count": _count_revealed_rooms(),
		"active_room_count": _count_room_states(&"ACTIVE"),
		"cleared_room_count": _count_room_states(&"CLEARED"),
		"encounter_descriptor_count": room_encounters.size(),
		"encounter_plan_count": room_encounters.size(),
		"planned_enemy_count": _sum_encounter_field("planned_enemy_count"),
		"planned_drop_count": _sum_encounter_field("planned_drop_count"),
		"resolved_encounter_count": _count_resolved_encounters(),
		"unresolved_encounter_count": maxi(room_encounters.size() - _count_resolved_encounters(), 0),
		"activated_encounter_count": _count_activated_encounters(),
		"ambient_debris_count": ground_debris_root.get_child_count() if ground_debris_root != null else 0,
		"key_room_id": key_room_id,
		"boss_room_id": boss_room_id,
		"boss_door_id": boss_door_id,
		"boss_entry_count": _get_room_degree(boss_room_id),
		"boss_single_entry": _get_room_degree(boss_room_id) == 1,
		"has_boss_key": has_boss_key,
		"boss_door_locked": is_boss_door_locked(),
		"boss_spawned": boss_enemy != null and is_instance_valid(boss_enemy),
		"boss_defeated": boss_defeated,
		"wake_exit_spawned": wake_exit_trigger != null and is_instance_valid(wake_exit_trigger),
		"wake_exit_active": boss_defeated and wake_exit_trigger != null and wake_exit_trigger.monitoring,
		"floor_index": floor_index,
		"floor_seed": active_seed,
		"elevator_room_id": elevator_room_id,
		"elevator_anchor_cell": elevator_anchor_cell,
		"elevator_state": elevator_state,
		"elevator_spawned": elevator_trigger != null and is_instance_valid(elevator_trigger),
		"has_floor_badge": has_floor_badge,
		"badge_carrier_room_id": badge_carrier_room_id,
		"badge_carrier_spawn_index": badge_carrier_spawn_index,
		"badge_drop_committed": badge_drop_committed,
		"badge_pickup_spawned": floor_badge_pickup != null and is_instance_valid(floor_badge_pickup),
		"badge_marker_spawned": badge_marker != null and is_instance_valid(badge_marker),
		"start_to_key_reachable": not find_floor_path(spawn_cell, rooms[key_room_id]["center_cell"], false).is_empty() if key_room_id >= 0 else false,
		"start_to_boss_blocked_before_key": start_to_boss_blocked_before_key,
		"start_to_boss_reachable_now": not find_floor_path(spawn_cell, rooms[boss_room_id]["center_cell"], false).is_empty() if boss_room_id >= 0 else false,
	}


func _count_revealed_rooms() -> int:
	var count := 0
	for room in rooms:
		if bool(room.get("revealed", false)):
			count += 1
	return count


func _count_room_states(state: StringName) -> int:
	var count := 0
	for value in room_states.values():
		if StringName(value) == state:
			count += 1
	return count


func _count_activated_encounters() -> int:
	var count := 0
	for value in room_encounters.values():
		if bool(value.get("activated", false)):
			count += 1
	return count


func _count_resolved_encounters() -> int:
	var count := 0
	for value in room_encounters.values():
		if bool(value.get("resolved", false)):
			count += 1
	return count


func _sum_encounter_field(field: String) -> int:
	var total := 0
	for value in room_encounters.values():
		total += maxi(int(value.get(field, 0)), 0)
	return total


func get_employee_wander_target(employee: EmployeeEnemy) -> Vector2:
	if employee == null:
		return Vector2.ZERO
	var room_id := int(employee.get_meta(&"dream_room_id", -1))
	var target_position := _random_room_position(room_id, 8.0, [player.global_position if player != null else Vector2.ZERO])
	return employee.global_position if target_position == Vector2.ZERO else target_position


func get_employee_navigation_target(employee: EmployeeEnemy, destination: Vector2) -> Vector2:
	# Keep the formal state machine; only route around concave floor boundaries.
	if _employee_nav_ray == null:
		_employee_nav_ray = PhysicsRayQueryParameters2D.new()
		_employee_nav_ray.collision_mask = WORLD_WALL_LAYER
		_employee_nav_ray.collide_with_bodies = true
		_employee_nav_ray.collide_with_areas = false
	_employee_nav_ray.from = employee.global_position
	_employee_nav_ray.to = destination
	if employee.get_world_2d().direct_space_state.intersect_ray(_employee_nav_ray).is_empty():
		return destination
	var start := Vector2i((employee.global_position / CELL_PIXELS).round())
	var finish := Vector2i((destination / CELL_PIXELS).round())
	var id := employee.get_instance_id()
	var now := Time.get_ticks_msec()
	var cached: Dictionary = employee_path_cache.get(id, {})
	if cached.get("start") != start or cached.get("finish") != finish or now - int(cached.get("time", 0)) > 700:
		cached = {"start": start, "finish": finish, "time": now, "path": find_floor_path(start, finish, false)}
		employee_path_cache[id] = cached
	var path: Array = cached.path
	return Vector2(path[1])*CELL_PIXELS if path.size() > 1 else destination


func get_employee_escape_target(employee: EmployeeEnemy, away_direction: Vector2) -> Vector2:
	if employee == null:
		return Vector2.ZERO
	var room_id := int(employee.get_meta(&"dream_room_id", -1))
	var bounds := _room_bounds_pixels(room_id, 12.0)
	var candidate := employee.global_position + away_direction.normalized() * 96.0
	candidate.x = clampf(candidate.x, bounds.position.x, bounds.end.x)
	candidate.y = clampf(candidate.y, bounds.position.y, bounds.end.y)
	return candidate if _content_position_is_clear(candidate, 8.0, false) else employee.global_position


func is_employee_position_clear(candidate: Vector2, employee: EmployeeEnemy) -> bool:
	if employee == null:
		return false
	var room_id := int(employee.get_meta(&"dream_room_id", -1))
	var candidate_room := _room_id_at_position(candidate)
	if candidate_room < 0:
		return false
	if candidate_room != room_id and not are_rooms_openly_connected(room_id, candidate_room):
		return false
	if _employee_clear_shape == null:
		_employee_clear_shape = CircleShape2D.new()
		_employee_clear_shape.radius = 8.0
		_employee_clear_query = PhysicsShapeQueryParameters2D.new()
		_employee_clear_query.shape = _employee_clear_shape
		_employee_clear_query.collide_with_bodies = true
		_employee_clear_query.collide_with_areas = false
	_employee_clear_query.transform = Transform2D(0.0, candidate)
	_employee_clear_query.collision_mask = WORLD_WALL_LAYER | 8
	if _employee_exclude_rids.is_empty():
		_employee_exclude_rids.append(employee.get_rid())
	else:
		_employee_exclude_rids[0] = employee.get_rid()
	_employee_clear_query.exclude = _employee_exclude_rids
	var space := employee.get_world_2d().direct_space_state if employee.is_inside_tree() else (player.get_world_2d().direct_space_state if player != null and player.is_inside_tree() else null)
	if space == null:
		return true
	return space.intersect_shape(_employee_clear_query, 8).is_empty()


func get_employee_roam_route(employee: EmployeeEnemy) -> Dictionary:
	if employee == null:
		return {}
	var room_id := int(employee.get_meta(&"dream_room_id", -1))
	if room_id < 0 or room_id >= rooms.size():
		return {}
	var choices: Array[Dictionary] = []
	for neighbor_variant in rooms[room_id].get("connections", []):
		var neighbor := int(neighbor_variant)
		if neighbor == employee.previous_room_id:
			continue
		var openly_connected := are_rooms_openly_connected(room_id, neighbor)
		var edge := _find_door_edge_between(room_id, neighbor)
		if not openly_connected:
			if edge.is_empty() or (int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked()):
				continue
		else:
			if not edge.is_empty() and int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked():
				continue
		choices.append({"room_id": neighbor, "direction": _direction_between_rooms(room_id, neighbor)})
	if choices.is_empty():
		return {}
	return choices[_content_rng.randi_range(0, choices.size() - 1)]


## -------------------------------------------------------------------------
## Enemy doorway arbitration
##
## A doorway is a shared gameplay resource, not a trigger.  MOVE_TO_DOOR
## agents queue at the authored approach point; exactly one agent receives a
## short-lived grant and only that holder may enter ROOM_TRANSIT.  The queue is
## deterministic (request serial, then instance id) with an opposite-side
## preference after release so a crowd cannot starve one side of a door.
## -------------------------------------------------------------------------

func request_employee_door_transit(
	employee: EmployeeEnemy,
	target_room_id: int,
	direction: StringName = &"",
	requested_door_id: int = -1
) -> bool:
	if (
		employee == null
		or not is_instance_valid(employee)
		or bool(employee.get("dead"))
		or employee.is_combat_displacement_active()
	):
		return false
	var from_room := int(employee.get_meta(&"dream_room_id", -1))
	if from_room < 0 or target_room_id < 0 or from_room >= rooms.size() or target_room_id >= rooms.size():
		return false
	if are_rooms_openly_connected(from_room, target_room_id):
		employee.set("door_transit_granted", true)
		employee.set("door_transit_id", requested_door_id)
		return true
	var edge := _find_door_edge_between(from_room, target_room_id)
	if edge.is_empty() or (int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked()):
		return false
	var door_id := int(edge.get("door_id", -1))
	if requested_door_id >= 0 and requested_door_id != door_id:
		return false
	if not direction.is_empty():
		var expected_direction := _direction_between_rooms(from_room, target_room_id)
		if expected_direction != direction:
			return false
	var side := 0 if int(edge.get("region_a_id", -1)) == from_room else 1
	var entry: Dictionary = door_transit_registry.get(door_id, {})
	if entry.is_empty():
		entry = {
			"door_id": door_id,
			"holder_id": -1,
			"holder": null,
			"holder_side": -1,
			"holder_target_room_id": -1,
			"last_side": -1,
			"queue": [],
		}
	else:
		_cleanup_door_entry_queue(entry, door_id)
	var holder := entry.get("holder") as EmployeeEnemy
	if holder != null and is_instance_valid(holder) and int(entry.get("holder_id", -1)) == holder.get_instance_id():
		if holder == employee:
			door_transit_registry[door_id] = entry
			return true
		_enqueue_door_request(entry, employee, from_room, target_room_id, side)
		door_transit_registry[door_id] = entry
		return false
	# No current holder: append this request and let the deterministic selector
	# choose it (or an opposite-side waiter already queued ahead of it).
	_enqueue_door_request(entry, employee, from_room, target_room_id, side)
	door_transit_registry[door_id] = entry
	_grant_next_door_transit(door_id)
	entry = door_transit_registry.get(door_id, entry)
	return int(entry.get("holder_id", -1)) == employee.get_instance_id()


func employee_has_door_transit_grant(employee: EmployeeEnemy, expected_door_id: int = -1) -> bool:
	if employee == null or not is_instance_valid(employee):
		return false
	var from_room := int(employee.get_meta(&"dream_room_id", -1))
	var target_room := int(employee.get("route_target_room_id"))
	if from_room >= 0 and target_room >= 0 and are_rooms_openly_connected(from_room, target_room):
		return true
	if bool(employee.get("door_transit_granted")) and (expected_door_id < 0 or int(employee.get("door_transit_id")) == expected_door_id):
		if from_room >= 0 and (target_room < 0 or are_rooms_openly_connected(from_room, target_room)):
			return true
	for entry_variant in door_transit_registry.values():
		var entry: Dictionary = entry_variant
		if int(entry.get("holder_id", -1)) != employee.get_instance_id():
			continue
		if expected_door_id >= 0 and int(entry.get("door_id", -1)) != expected_door_id:
			return false
		return true
	return false


func release_employee_door_transit(employee: EmployeeEnemy) -> void:
	if employee == null:
		return
	var employee_id := employee.get_instance_id() if is_instance_valid(employee) else -1
	for door_key_variant in door_transit_registry.keys():
		var door_id := int(door_key_variant)
		var entry: Dictionary = door_transit_registry.get(door_id, {})
		var changed := false
		if int(entry.get("holder_id", -1)) == employee_id:
			# Clear the mirrored grant before selecting the next waiter.  This
			# prevents a stale holder from passing can_transfer_through_door()
			# during the same frame that the registry is released (for example
			# when a route is cancelled by combat or a room transfer finishes).
			if is_instance_valid(employee):
				employee.set("door_transit_granted", false)
				employee.set("door_transit_id", -1)
			entry["last_side"] = int(entry.get("holder_side", -1))
			entry["holder_id"] = -1
			entry["holder"] = null
			entry["holder_side"] = -1
			entry["holder_target_room_id"] = -1
			changed = true
		var queue: Array = entry.get("queue", [])
		var kept: Array = []
		for request_variant in queue:
			var request: Dictionary = request_variant
			var queued_employee := request.get("employee") as EmployeeEnemy
			if queued_employee == employee:
				changed = true
				continue
			kept.append(request)
		entry["queue"] = kept
		if changed:
			door_transit_registry[door_id] = entry
			_grant_next_door_transit(door_id)


func _enqueue_door_request(
	entry: Dictionary,
	employee: EmployeeEnemy,
	from_room: int,
	target_room_id: int,
	side: int
) -> void:
	var queue: Array = entry.get("queue", [])
	for request_variant in queue:
		var request: Dictionary = request_variant
		if request.get("employee") == employee:
			return
	_door_transit_serial += 1
	queue.append({
		"employee": employee,
		"employee_id": employee.get_instance_id(),
		"serial": _door_transit_serial,
		"door_id": int(entry.get("door_id", -1)),
		"from_room": from_room,
		"target_room_id": target_room_id,
		"side": side,
	})
	entry["queue"] = queue


func _cleanup_door_entry_queue(entry: Dictionary, door_id: int) -> void:
	var queue: Array = entry.get("queue", [])
	var kept: Array = []
	for request_variant in queue:
		var request: Dictionary = request_variant
		var queued_employee := request.get("employee") as EmployeeEnemy
		if (
			queued_employee == null
			or not is_instance_valid(queued_employee)
			or bool(queued_employee.get("dead"))
			or queued_employee.is_combat_displacement_active()
			or int(queued_employee.get("state")) != EmployeeEnemy.State.MOVE_TO_DOOR
			or int(queued_employee.get("route_target_room_id")) != int(request.get("target_room_id", -2))
			or int(queued_employee.get("door_transit_id")) not in [-1, door_id]
			or int(request.get("door_id", door_id)) != door_id
		):
			continue
		kept.append(request)
	kept.sort_custom(_door_request_before)
	entry["queue"] = kept


func _door_request_before(a: Dictionary, b: Dictionary) -> bool:
	var a_serial := int(a.get("serial", 0))
	var b_serial := int(b.get("serial", 0))
	if a_serial != b_serial:
		return a_serial < b_serial
	return int(a.get("employee_id", 0)) < int(b.get("employee_id", 0))


func _grant_next_door_transit(door_id: int) -> void:
	var entry: Dictionary = door_transit_registry.get(door_id, {})
	if entry.is_empty():
		return
	var current_holder := entry.get("holder") as EmployeeEnemy
	if (
		current_holder != null
		and is_instance_valid(current_holder)
		and int(entry.get("holder_id", -1)) == current_holder.get_instance_id()
	):
		return
	_cleanup_door_entry_queue(entry, door_id)
	var queue: Array = entry.get("queue", [])
	if queue.is_empty():
		entry["holder_id"] = -1
		entry["holder"] = null
		entry["holder_side"] = -1
		entry["holder_target_room_id"] = -1
		door_transit_registry[door_id] = entry
		return
	var last_side := int(entry.get("last_side", -1))
	var selected_index := 0
	if last_side >= 0:
		for index in range(queue.size()):
			var candidate: Dictionary = queue[index]
			if int(candidate.get("side", -1)) != last_side:
				selected_index = index
				break
	var selected: Dictionary = queue[selected_index]
	queue.remove_at(selected_index)
	entry["queue"] = queue
	var next_employee := selected.get("employee") as EmployeeEnemy
	if next_employee == null or not is_instance_valid(next_employee):
		door_transit_registry[door_id] = entry
		_grant_next_door_transit(door_id)
		return
	entry["holder_id"] = next_employee.get_instance_id()
	entry["holder"] = next_employee
	entry["holder_side"] = int(selected.get("side", -1))
	entry["holder_target_room_id"] = int(selected.get("target_room_id", -1))
	door_transit_registry[door_id] = entry
	# This is the only place that grants an Enemy the right to enter the door.
	next_employee.set("door_transit_granted", true)
	next_employee.set("door_transit_id", door_id)


func _cleanup_door_transit_registry() -> void:
	for door_key_variant in door_transit_registry.keys():
		var door_id := int(door_key_variant)
		var entry: Dictionary = door_transit_registry.get(door_id, {})
		var holder := entry.get("holder") as EmployeeEnemy
		if (
			holder != null
			and is_instance_valid(holder)
			and not bool(holder.get("dead"))
			and not holder.is_combat_displacement_active()
			and int(entry.get("holder_id", -1)) == holder.get_instance_id()
			and holder.get("door_transit_id") == door_id
			and int(holder.get("route_target_room_id")) == int(entry.get("holder_target_room_id", -1))
		):
			_cleanup_door_entry_queue(entry, door_id)
			door_transit_registry[door_id] = entry
			continue
		if holder != null and is_instance_valid(holder):
			holder.set("door_transit_granted", false)
			holder.set("door_transit_id", -1)
		entry["last_side"] = int(entry.get("holder_side", -1))
		entry["holder_id"] = -1
		entry["holder"] = null
		entry["holder_side"] = -1
		entry["holder_target_room_id"] = -1
		_cleanup_door_entry_queue(entry, door_id)
		door_transit_registry[door_id] = entry
		_grant_next_door_transit(door_id)


func get_employee_door_plan(employee: EmployeeEnemy, target_room_id: int, preferred_direction: StringName = &"") -> Dictionary:
	if employee == null:
		return {}
	var from_room := int(employee.get_meta(&"dream_room_id", -1))
	if from_room < 0 or from_room >= rooms.size() or target_room_id < 0 or target_room_id >= rooms.size():
		return {}
	target_room_id = _next_route_room(from_room, target_room_id)
	if target_room_id < 0:
		return {}
	if are_rooms_openly_connected(from_room, target_room_id):
		var open_edges := _get_open_boundary_edges_between(from_room, target_room_id)
		var best_edge: Dictionary = {}
		if not open_edges.is_empty():
			var best_distance := INF
			var emp_pos := employee.global_position
			for cand_edge in open_edges:
				var pos := _boundary_edge_center_pixels(cand_edge)
				var dist := emp_pos.distance_squared_to(pos)
				if dist < best_distance:
					best_distance = dist
					best_edge = cand_edge
		if best_edge.is_empty():
			best_edge = _find_door_edge_between(from_room, target_room_id)

		var connection := _connection_between_rooms(from_room, target_room_id)
		var direction := preferred_direction
		var step := Vector2i.ZERO
		if not best_edge.is_empty():
			var sides := _edge_side_cells(best_edge)
			if sides.size() >= 2:
				var from_first := int(room_cells.get(sides[0], -1)) == from_room
				step = sides[1] - sides[0] if from_first else sides[0] - sides[1]
		if step == Vector2i.ZERO:
			step = _room_step_vector(from_room, target_room_id)
		if direction.is_empty():
			direction = _direction_name_from_step(step)
		if direction.is_empty():
			direction = _direction_between_rooms(from_room, target_room_id)
		var inward := Vector2.ZERO
		match direction:
			&"right": inward = Vector2.RIGHT
			&"left": inward = Vector2.LEFT
			&"bottom": inward = Vector2.DOWN
			&"top": inward = Vector2.UP
		var socket := Vector2.ZERO
		if not best_edge.is_empty():
			socket = _boundary_edge_center_pixels(best_edge)
		elif from_room < rooms.size() and target_room_id < rooms.size():
			var center_a: Vector2 = Vector2(rooms[from_room].get("center_cell", Vector2i.ZERO)) * CELL_PIXELS
			var center_b: Vector2 = Vector2(rooms[target_room_id].get("center_cell", Vector2i.ZERO)) * CELL_PIXELS
			socket = (center_a + center_b) * 0.5

		return {
			"target_room_id": target_room_id,
			"door_id": int(best_edge.get("door_id", -1)) if not best_edge.is_empty() else -1,
			"door_edge_key": _edge_key(best_edge) if not best_edge.is_empty() else "",
			"direction": direction,
			"approach": socket - inward * EMPLOYEE_CONFIG.employee_door_approach_distance,
			"transit": socket + inward * EMPLOYEE_CONFIG.employee_door_transit_distance,
			"corridor_id": int(connection.get("corridor_id", -1)),
		}

	var edge := _find_door_edge_between(from_room, target_room_id)
	if edge.is_empty() or (int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked()):
		return {}
	var connection := _connection_between_rooms(from_room, target_room_id)
	var from_door := _connection_door_for_room(connection, from_room)
	var step := Vector2i.ZERO
	if not from_door.is_empty():
		step = from_door.get("outward", Vector2i.ZERO)
	if step == Vector2i.ZERO:
		var sides := _edge_side_cells(edge)
		var from_first := int(room_cells.get(sides[0], -1)) == from_room
		step = sides[1] - sides[0] if from_first else sides[0] - sides[1]
	var direction: StringName = _direction_name_from_step(step)
	if direction.is_empty():
		return {}
	if not preferred_direction.is_empty() and preferred_direction == direction:
		direction = preferred_direction
	var inward := Vector2.ZERO
	match direction:
		&"right": inward = Vector2.RIGHT
		&"left": inward = Vector2.LEFT
		&"bottom": inward = Vector2.DOWN
		&"top": inward = Vector2.UP
	var socket := _door_center_pixels(edge)
	return {
		"target_room_id": target_room_id,
		"door_id": int(edge.get("door_id", -1)),
		"door_edge_key": _edge_key(edge),
		"direction": direction,
		"approach": socket - inward * EMPLOYEE_CONFIG.employee_door_approach_distance,
		"transit": socket + inward * EMPLOYEE_CONFIG.employee_door_transit_distance,
		"corridor_id": int(connection.get("corridor_id", -1)),
	}


func _next_route_room(from_room: int, destination: int) -> int:
	# Walk the existing graph; the formal Employee state machine handles each
	# physical door in turn. Locked boss edges are never treated as shortcuts.
	var queue: Array[int] = [from_room]
	var first_hop := {from_room: -1}
	var index := 0
	while index < queue.size():
		var room_id := queue[index]
		index += 1
		for neighbor_variant in rooms[room_id].get("connections", []):
			var neighbor := int(neighbor_variant)
			if first_hop.has(neighbor):
				continue
			var edge := _find_door_edge_between(room_id, neighbor)
			if edge.is_empty() or (int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked()):
				continue
			first_hop[neighbor] = neighbor if room_id == from_room else first_hop[room_id]
			if neighbor == destination:
				return int(first_hop[neighbor])
			queue.append(neighbor)
	return -1


func can_employee_hear_gunshot(employee: EmployeeEnemy, source_room_id: int) -> bool:
	var from_room := int(employee.get_meta(&"dream_room_id", -1))
	if from_room == source_room_id:
		return true
	if employee.held_weapon_id.is_empty() or from_room < 0 or from_room >= rooms.size():
		return false
	# Only an adjacent, connected sound source is heard; no global Player lock.
	return rooms[from_room].get("connections", []).has(source_room_id) and _next_route_room(from_room, source_room_id) == source_room_id


func get_employee_door_step(employee: EmployeeEnemy, target_room_id: int) -> Dictionary:
	var plan := get_employee_door_plan(employee, target_room_id)
	return {"direction": plan.get("direction", &""), "position": plan.get("approach", Vector2.ZERO)} if not plan.is_empty() else {}


func get_employee_flee_route(employee: EmployeeEnemy, avoid_room_id: int = -1, _threat_position: Vector2 = Vector2.ZERO) -> Dictionary:
	if employee == null:
		return {}
	var room_id := int(employee.get_meta(&"dream_room_id", -1))
	if room_id < 0 or room_id >= rooms.size():
		return {}
	var best: Dictionary = {}
	var best_score := -INF
	for neighbor_variant in rooms[room_id].get("connections", []):
		var neighbor := int(neighbor_variant)
		var openly_connected := are_rooms_openly_connected(room_id, neighbor)
		var edge := _find_door_edge_between(room_id, neighbor)
		if not openly_connected:
			if edge.is_empty() or (int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked()):
				continue
		else:
			if not edge.is_empty() and int(edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked():
				continue
		var score := _room_center_manhattan(room_id, neighbor) + _content_rng.randf_range(-10.0, 10.0)
		if neighbor == avoid_room_id:
			score -= 1000.0
		if score > best_score:
			best_score = score
			best = {"room_id": neighbor, "direction": _direction_between_rooms(room_id, neighbor)}
	return best


func transfer_employee_through_door(employee: EmployeeEnemy, direction: StringName, target_room_id: int) -> void:
	if employee == null or not is_instance_valid(employee):
		return
	if not employee.can_transfer_through_door(direction, target_room_id):
		return
	var from_room := int(employee.get_meta(&"dream_room_id", -1))
	var openly_connected := are_rooms_openly_connected(from_room, target_room_id)
	var expected_edge := _find_door_edge_between(from_room, target_room_id)
	if not openly_connected:
		if (
			expected_edge.is_empty()
			or not employee_has_door_transit_grant(employee, int(expected_edge.get("door_id", -1)))
		):
			return
	if from_room < 0 or from_room >= rooms.size() or target_room_id < 0 or target_room_id >= rooms.size():
		employee.on_room_transit_finished()
		return
	var expected := int(rooms[from_room].get("connections", []).find(target_room_id)) if from_room >= 0 else -1
	if expected < 0 or (int(expected_edge.get("door_id", -1)) == boss_door_id and is_boss_door_locked()):
		employee.on_room_transit_finished()
		return
	employee.previous_room_id = from_room
	employee.set_meta(&"dream_room_id", target_room_id)
	employee.set_room_bounds(_room_bounds_pixels(target_room_id, 2.0))
	var connection := _connection_between_rooms(from_room, target_room_id)
	var target_door := _connection_door_for_room(connection, target_room_id)
	var step := _room_step_vector(from_room, target_room_id)
	var destination_inside: Vector2i = target_door.get("inside_cell", Vector2i.ZERO)
	var fallback_exit := Vector2(destination_inside) * CELL_PIXELS + Vector2(step) * EMPLOYEE_CONFIG.employee_door_exit_distance
	if openly_connected and employee.route_transit_point != Vector2.ZERO:
		fallback_exit = employee.route_transit_point + Vector2(step) * EMPLOYEE_CONFIG.employee_door_exit_distance
	var transit_points := get_employee_corridor_transit_points(from_room, target_room_id)
	if transit_points.is_empty():
		transit_points = [fallback_exit]
	employee.begin_room_exit(fallback_exit, transit_points)


func finish_employee_room_transit(_employee: EmployeeEnemy) -> void:
	# The continuous 2D gameplay world has no separate room scene to swap.  The
	# Employee has already crossed the authored door plane; release the doorway
	# only now, after the exit threshold, so another Enemy cannot enter through
	# the still-overlapping leaf.
	release_employee_door_transit(_employee)


func sync_employee_ground_region(employee: EmployeeEnemy) -> void:
	# Metadata only: do not reparent, initialize navigation, or assign position.
	var region := _room_id_at_position(employee.global_position)
	if region >= 0 and region != int(employee.get_meta(&"dream_room_id", -1)):
		employee.set_meta(&"dream_room_id", region)
		employee.set_room_bounds(_room_bounds_pixels(region, 2.0))


func notify_gunshot(world_position: Vector2, source_room_id: int = -1) -> void:
	var room_id := source_room_id if source_room_id >= 0 else _room_id_at_position(world_position)
	if enemy_root == null:
		return
	for child in enemy_root.get_children():
		if child.has_method("on_room_gunshot"):
			child.call("on_room_gunshot", world_position, room_id)


func queue_employee_flee_offscreen(_employee: EmployeeEnemy, _avoid_room_id: int = -1) -> void:
	if _employee == null or not is_instance_valid(_employee):
		return
	# FLEE is a Boss-only capability.  Keep this legacy world entry point for
	# Boss routing, but never let an ordinary Employee queue an offscreen flee.
	if not bool(_employee.get("boss_variant")):
		return
	var route := get_employee_flee_route(_employee, _avoid_room_id)
	if route.is_empty():
		return
	_employee._begin_route_to_room(int(route.get("room_id", -1)), StringName(route.get("direction", &"")))


func claim_employee_world_weapon(_employee: EmployeeEnemy) -> Dictionary:
	if _employee == null or not is_instance_valid(_employee) or world_weapon_root == null:
		return {}
	var employee_room := int(_employee.get_meta(&"dream_room_id", get_current_room_id()))
	var best: Node2D
	var best_distance := INF
	for pickup_variant in world_weapon_root.get_children():
		var pickup := pickup_variant as Node2D
		if pickup == null or not is_instance_valid(pickup):
			continue
		if int(pickup.get_meta(&"dream_room_id", -1)) != employee_room:
			continue
		var weapon_id := String(pickup.get("weapon_id"))
		if not _is_pickup_weapon_id_allowed(weapon_id):
			continue
		if pickup.has_method("is_available_for") and not bool(pickup.call("is_available_for", _employee)):
			continue
		var distance := _employee.global_position.distance_squared_to(pickup.global_position)
		if distance < best_distance:
			best_distance = distance
			best = pickup
	if best == null:
		return {}
	if not request_enemy_world_weapon_pickup(_employee, best):
		return {}
	return {"pickup": best, "room_id": employee_room}


func get_room_debris_root(_room_id: int = -1) -> Node2D:
	return ground_debris_root


func resolve_environment_debris_room_id(at_position: Vector2, fallback_room_id: int = -1) -> int:
	var resolved := _room_id_at_position(at_position)
	return resolved if resolved >= 0 else fallback_room_id


func is_environment_debris_position_allowed(at_position: Vector2, room_id: int = -1, source_prop: Node2D = null) -> bool:
	var resolved := resolve_environment_debris_room_id(at_position, room_id)
	var cell := Vector2i(roundi(at_position.x / CELL_PIXELS), roundi(at_position.y / CELL_PIXELS))
	if resolved < 0 or not floor_cells.has(cell):
		return false
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state if player != null and player.is_inside_tree() else null
	if space == null:
		return true
	if _debris_point_query == null:
		_debris_point_query = PhysicsPointQueryParameters2D.new()
		_debris_point_query.collision_mask = WORLD_WALL_LAYER | 8
		_debris_point_query.collide_with_bodies = true
		_debris_point_query.collide_with_areas = false
	_debris_point_query.position = at_position
	for hit_variant in space.intersect_point(_debris_point_query, 16):
		var collider := (hit_variant as Dictionary).get("collider") as Node
		if collider == null or collider == source_prop or collider.is_in_group(&"environment_debris") or collider.is_in_group(&"world_weapon_pickups"):
			continue
		return false
	return true


func _ensure_environment_debris_capacity(room_id: int) -> bool:
	var debris_nodes: Array[Node] = []
	for node in ground_debris_root.get_children():
		if node.is_in_group(&"environment_debris") and not node.is_queued_for_deletion() and int(node.get("room_id")) == room_id:
			debris_nodes.append(node)
	if debris_nodes.size() < config.environment_debris_max_per_room:
		return true
	# Same policy as formal 2D: recycle the oldest settled debris, never blood,
	# detached body parts or airborne spray. Tree order is creation order.
	for node in debris_nodes:
		if bool(node.get("settled")):
			node.hide()
			node.queue_free()
			return true
	return false


func _environment_debris_spray_origin(origin: Vector2, direction: Vector2, room_id: int, source_prop: Node2D) -> Vector2:
	# Start just outside the source collider; do not leave paper hidden inside
	# a wide cabinet when its brief spray settles. Sweep prevents wall teleport.
	var distance := 10.0
	if is_instance_valid(source_prop):
		if source_prop.has_method(&"get_gameplay_footprint_half_extents"):
			var footprint: Variant = source_prop.call(&"get_gameplay_footprint_half_extents")
			if footprint is Vector2:
				var collider := source_prop.get_node_or_null("CollisionShape2D") as CollisionShape2D
				var center := collider.global_position if collider != null else source_prop.global_position
				var half := footprint as Vector2
				distance = maxf(
					distance,
					(center - origin).dot(direction)
					+ half.x * absf(direction.x)
					+ half.y * absf(direction.y)
					+ 6.0
				)
		else:
			var collider := source_prop.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collider != null and collider.shape != null:
				var rect := collider.shape.get_rect()
				for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
					distance = maxf(distance, (collider.to_global(corner) - origin).dot(direction) + 6.0)
	var candidate := origin + direction * distance
	if _debris_spray_ray == null:
		_debris_spray_ray = PhysicsRayQueryParameters2D.new()
		_debris_spray_ray.collision_mask = WORLD_WALL_LAYER
		_debris_spray_ray.collide_with_bodies = true
		_debris_spray_ray.collide_with_areas = false
	_debris_spray_ray.from = origin
	_debris_spray_ray.to = candidate
	if not player.get_world_2d().direct_space_state.intersect_ray(_debris_spray_ray).is_empty():
		return Vector2.INF
	return candidate if is_environment_debris_position_allowed(candidate, room_id) else Vector2.INF


func spawn_environment_debris(world_position: Vector2, source_room_id: int = -1, count: int = 1, spray_direction: Vector2 = Vector2.ZERO, spray_strength: float = 0.0, source_prop: Node2D = null) -> int:
	if ground_debris_root == null or ENVIRONMENT_DEBRIS_SCENE == null or count <= 0:
		return 0
	var room_id := resolve_environment_debris_room_id(world_position, source_room_id)
	if room_id < 0:
		return 0
	var spawned := 0
	for _index in range(count):
		var direction := spray_direction.normalized() if spray_direction.length_squared() > 0.001 else Vector2.RIGHT
		var position := world_position
		var velocity := Vector2.ZERO
		var up_velocity := 0.0
		if spray_strength > 0.0:
			var spread := deg_to_rad(config.environment_debris_spray_spread_degrees)
			direction = direction.rotated(_content_rng.randf_range(-spread, spread))
			position = _environment_debris_spray_origin(world_position, direction, room_id, source_prop)
			velocity = direction * maxf(12.0, spray_strength + _content_rng.randf_range(-config.environment_debris_spray_speed_variance, config.environment_debris_spray_speed_variance))
			up_velocity = _content_rng.randf_range(config.environment_debris_spray_up_velocity * 0.65, config.environment_debris_spray_up_velocity)
		if not position.is_finite() or not is_environment_debris_position_allowed(position, room_id):
			continue
		if not _ensure_environment_debris_capacity(room_id):
			break
		var debris := ENVIRONMENT_DEBRIS_SCENE.instantiate() as Node2D
		ground_debris_root.add_child(debris)
		debris.call("setup", _content_rng.randi_range(0, 41), self, room_id, position, velocity, up_velocity)
		_spawn_depth_bridge(
			debris,
			[NodePath("Sprite2D")],
			Vector2(64.0, 64.0),
			BaseMaterial3D.BILLBOARD_DISABLED,
			0.02,
			0.0,
			Vector3(-PI * 0.5, 0.0, 0.0),
			true
		)
		spawned += 1
	return spawned


func spawn_furniture_damage_debris(prop: Node2D, hit_direction: Vector2) -> int:
	return spawn_environment_debris(prop.global_position, get_room_id_for_node(prop), _content_rng.randi_range(0, 1), hit_direction, config.environment_debris_hit_spray_speed, prop) if prop != null else 0


func spawn_furniture_destroy_debris(prop: Node2D, hit_direction: Vector2) -> int:
	return spawn_environment_debris(prop.global_position, get_room_id_for_node(prop), _content_rng.randi_range(0, 3), hit_direction, config.environment_debris_destroy_spray_speed, prop) if prop != null else 0


func reassign_environment_debris_room(_debris: Node2D) -> void:
	if _debris == null or not is_instance_valid(_debris):
		return
	var fallback := int(_debris.get("room_id"))
	var room_id := resolve_environment_debris_room_id(_debris.global_position, fallback)
	if room_id >= 0:
		_debris.set("room_id", room_id)
		_debris.set_meta(&"dream_room_id", room_id)


func try_transfer_furniture_through_door(_prop: Node2D) -> bool:
	if _prop == null or not is_instance_valid(_prop) or _prop.get("destroyed") == true or _prop.get("is_destroyed") == true:
		return false
	var body := _prop as RigidBody2D
	if body == null or body.linear_velocity.length_squared() < 36.0:
		return false
	var source_room := get_room_id_for_node(_prop)
	if source_room < 0 or source_room >= rooms.size():
		return false
	for neighbor_variant in rooms[source_room].get("connections", []):
		var neighbor := int(neighbor_variant)
		var edge := _find_door_edge_between(source_room, neighbor)
		if edge.is_empty():
			continue
		var socket := _door_center_pixels(edge)
		var sides := _edge_side_cells(edge)
		var from_first := int(room_cells.get(sides[0], -1)) == source_room
		var outward_direction := Vector2(sides[1] - sides[0] if from_first else sides[0] - sides[1])
		if outward_direction.length_squared() < 0.001 or body.linear_velocity.dot(outward_direction) <= 0.0:
			continue
		var to_prop := _prop.global_position - socket
		var tangent := Vector2(-outward_direction.y, outward_direction.x)
		if absf(to_prop.dot(tangent)) > door_width * CELL_PIXELS * 0.5 + 10.0:
			continue
		if to_prop.dot(outward_direction) < 8.0:
			continue
		# Continuous-world furniture stays under one gameplay root; only its
		# authoritative room ownership changes after crossing the actual socket.
		if _room_id_at_position(_prop.global_position) == neighbor:
			_prop.set_meta(&"dream_room_id", neighbor)
			return true
	return false


func try_drop_books_from_furniture(_prop: Node2D, category: StringName) -> void:
	if _prop == null or not is_instance_valid(_prop) or world_weapon_root == null:
		return
	var chance := 0.0
	match category:
		&"cabinet": chance = EMPLOYEE_CONFIG.books_drop_chance_cabinet
		&"table": chance = EMPLOYEE_CONFIG.books_drop_chance_table
		&"trash_can": chance = EMPLOYEE_CONFIG.books_drop_chance_trash_can
		_: return
	if _content_rng.randf() > clampf(chance, 0.0, 1.0):
		return
	var pickup := WORLD_WEAPON_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	world_weapon_root.add_child(pickup)
	var skin := _content_rng.randi_range(0, maxi(WEAPON_VISUALS.get_skin_count("books") - 1, 0))
	if pickup.has_method("set_weapon_id"):
		pickup.call("set_weapon_id", "books", skin)
	else:
		pickup.set("weapon_id", "books")
		pickup.set("skin_index", skin)
	pickup.set("interaction_radius", EMPLOYEE_CONFIG.world_weapon_interaction_radius)
	pickup.set("mass", WEAPON_VISUALS.get_world_mass("books"))
	var room_id := get_room_id_for_node(_prop)
	pickup.set_meta(&"dream_room_id", room_id)
	var drop_direction := Vector2.RIGHT.rotated(_content_rng.randf_range(-PI, PI))
	var desired := _prop.global_position + drop_direction * 12.0
	pickup.global_position = desired if is_environment_debris_position_allowed(desired, room_id, _prop) else _prop.global_position
	if pickup.has_method("place_after_swap"):
		pickup.call_deferred("place_after_swap", pickup.global_position, drop_direction * 10.0)
	_spawn_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])


func _room_inward_vector(direction: StringName) -> Vector2:
	match direction:
		&"right": return Vector2.RIGHT
		&"left": return Vector2.LEFT
		&"bottom": return Vector2.DOWN
		&"top": return Vector2.UP
	return Vector2.ZERO



func _register_black_blood_stain(blood: Node) -> void:
	if blood == null or not is_instance_valid(blood):
		return
	blood.add_to_group(&"black_blood_stains")
	_owned_black_blood_stains.append(blood)


func _enforce_3d_blood_limit() -> bool:
	# black_blood_max_stains <= 0：血迹在本场 Dream 内永久保留，不做数量驱逐。
	# 正值时保留原有的全局预算语义（逐出最旧一株，纯性能保护）。
	var configured := int(EMPLOYEE_CONFIG.black_blood_max_stains)
	if configured <= 0:
		return true
	var maximum := maxi(configured, 1)
	# Compact owned list (floor/wall/door stains share one budget).
	var write := 0
	for i in range(_owned_black_blood_stains.size()):
		var stain := _owned_black_blood_stains[i] as Node
		if stain == null or not is_instance_valid(stain) or stain.is_queued_for_deletion():
			continue
		_owned_black_blood_stains[write] = stain
		write += 1
	_owned_black_blood_stains.resize(write)
	if write < maximum:
		return true
	var oldest := _owned_black_blood_stains[0] as Node
	if is_instance_valid(oldest):
		oldest.queue_free()
		return true
	return false


func _add_3d_blood_effect(blood: Node2D, room_id: int, floor_visual: bool = true) -> Node2D:
	if blood == null or world_effects_root == null:
		return null
	if not _enforce_3d_blood_limit():
		return null
	_register_black_blood_stain(blood)
	blood.set_meta(&"dream_room_id", room_id)
	blood.set_meta(&"blood_floor_visual", floor_visual)
	blood.set_meta(&"blood_floor_token", _layout_generation)
	world_effects_root.add_child(blood)
	if blood.has_method("set_surface_context"):
		blood.call("set_surface_context", self, room_id)
	if floor_visual:
		if blood.get_script()==BLACK_BLOOD_EFFECT and not bool(get_meta(&"test_legacy_blood_ground_capture",false)):
			_get_blood_ground_capture_pool().acquire(blood,camera_3d,BLOOD_FLOOR_WORLD_Y)
			return blood
		# Final death-pool rim reaches roughly 97 gameplay pixels; leave room
		# for the largest stamp so it does not disappear at the capture edge.
		var capture_extent := 112.0 if bool(blood.get("office_pool_core")) or int(blood.get_meta(&"blood_ground_capture_extent",64))>=96 else 64.0
		_spawn_depth_bridge(
			blood,
			[NodePath(".")],
			Vector2(capture_extent, capture_extent),
			BaseMaterial3D.BILLBOARD_DISABLED,
			BLOOD_FLOOR_WORLD_Y,
			0.0,
			Vector3(-PI * 0.5, 0.0, 0.0),
			false,
			true
		)
	return blood


func _blood_merge_bucket(blood: Node2D) -> Vector3i:
	return Vector3i(int(blood.get_meta(&"dream_room_id", -1)),
		floori(blood.global_position.x / BLOOD_MERGE_BUCKET_PIXELS),
		floori(blood.global_position.y / BLOOD_MERGE_BUCKET_PIXELS))


## A failed elevator transition restores the old floor nodes under a fresh
## generation token. Rebuild weak ownership without changing their pixels.
func _rebuild_settled_blood_registry() -> void:
	_settled_blood_buckets.clear()
	if not is_instance_valid(world_effects_root):
		return
	for child in world_effects_root.get_children():
		if not child is BlackBloodEffect or not bool(child.get_meta(&"blood_floor_visual", false)) or child.is_queued_for_deletion():
			continue
		child.set_meta(&"blood_floor_token", _layout_generation)
		child.set_meta(&"blood_merge_registered", child.is_visual_settled())
		if child.is_visual_settled():
			var key := _blood_merge_bucket(child)
			var bucket: Array = _settled_blood_buckets.get(key, [])
			bucket.append(weakref(child))
			_settled_blood_buckets[key] = bucket


## Settled floor marks share a bounded capture. Wall/door marks and active
## droplets retain their own authority; nothing is evicted to hide the cost.
func _on_blood_effect_settled(reference: WeakRef) -> void:
	var blood := reference.get_ref() as Node2D if reference != null else null
	if not is_instance_valid(blood) or blood.is_queued_for_deletion():
		return
	if blood.get_parent() != world_effects_root or not bool(blood.get_meta(&"blood_floor_visual", false)):
		return
	if int(blood.get_meta(&"blood_floor_token", -1)) != _layout_generation:
		return
	if not blood.has_method("can_absorb_ground_effect") or not blood.call("is_visual_settled"):
		return
	if bool(blood.get_meta(&"blood_merge_registered", false)):
		return
	var bucket := _blood_merge_bucket(blood)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := bucket + Vector3i(0, dx, dy)
			var live: Array[WeakRef] = []
			for ref_variant in _settled_blood_buckets.get(key, []):
				var target := (ref_variant as WeakRef).get_ref() as Node2D
				if not is_instance_valid(target) or target.is_queued_for_deletion():
					continue
				live.append(ref_variant)
				if bool(get_meta(&"test_legacy_ground_merge", false)):
					target.set_meta(&"test_legacy_ground_merge",true)
					if target == blood or not bool(target.call("can_absorb_ground_effect", blood, BLOOD_MERGE_CAPTURE_EXTENT - 4.0)): continue
				# absorb performs the same eligibility/108px bounds checks itself.
				# A preliminary can_absorb used to rasterize both sources again,
				# followed by another check and rasterization inside absorb.
				if target == blood or not bool(target.call("absorb_ground_effect", blood, BLOOD_MERGE_CAPTURE_EXTENT - 4.0)):
					continue
				var bridge_ref: Variant = target.get_meta(&"depth_visual_bridge") if target.has_meta(&"depth_visual_bridge") else null
				var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
				if is_instance_valid(bridge):
					bridge.call("resize_blood_ground_capture", BLOOD_MERGE_CAPTURE_EXTENT)
					bridge.call("request_capture_refresh")
				_settled_blood_buckets[key] = live
				blood.queue_free()
				return
			_settled_blood_buckets[key] = live
	var own_bucket: Array = _settled_blood_buckets.get(bucket, [])
	own_bucket.append(weakref(blood))
	_settled_blood_buckets[bucket] = own_bucket
	blood.set_meta(&"blood_merge_registered", true)


## Setup needs a live physics world before wall raycasts can be made. Refresh
## the passive capture after setup, then compact settled floor marks once.
func _refresh_3d_blood_effect_after_setup(blood: Node2D, attach_airborne: bool = false) -> void:
	if blood == null or not is_instance_valid(blood):
		return
	if blood.has_method("notify_visual_setup_complete"):
		blood.call("notify_visual_setup_complete")
	var bridge_variant: Variant = blood.get_meta(&"depth_visual_bridge") if blood.has_meta(&"depth_visual_bridge") else null
	var bridge: Node = bridge_variant.get_ref() if bridge_variant is WeakRef else null
	if bridge != null and is_instance_valid(bridge) and bridge.has_method("request_capture_refresh"):
		bridge.call("request_capture_refresh")
	if attach_airborne:
		_attach_airborne_blood_carrier(blood)
	if blood.has_method("is_visual_settled") and blood.call("is_visual_settled"):
		call_deferred("_on_blood_effect_settled", weakref(blood))


func _attach_airborne_blood_carrier(blood: Node2D) -> void:
	if BLOOD_AIRBORNE_CARRIER == null or actor_depth_bridges_root == null:
		return
	if blood == null or not is_instance_valid(blood) or not blood.has_method("get_airborne_visual_snapshot"):
		return
	# Keep the one-carrier-per-effect invariant even if a setup refresh is
	# requested more than once during a presentation rebuild.
	var existing_ref: Variant = blood.get_meta(&"blood_airborne_carrier") if blood.has_meta(&"blood_airborne_carrier") else null
	if existing_ref is WeakRef:
		var existing_variant: Variant = existing_ref.get_ref()
		if existing_variant is Node3D and is_instance_valid(existing_variant) and not existing_variant.is_queued_for_deletion():
			if existing_variant.has_method("sync_from_effect"):
				existing_variant.call("sync_from_effect", blood)
			return
	var snapshot_variant: Variant = blood.call("get_airborne_visual_snapshot")
	if not snapshot_variant is Array:
		return
	var snapshot: Array = snapshot_variant
	if snapshot.is_empty():
		return
	var carrier := BLOOD_AIRBORNE_CARRIER.new() as Node3D
	if carrier == null:
		return
	var room_id := int(blood.get_meta(&"dream_room_id", current_room_id))
	carrier.name = "BloodAirborneCarrier_%d" % blood.get_instance_id()
	carrier.add_to_group(&"blood_airborne_carriers")
	carrier.set_meta(&"dream_room_id", room_id)
	actor_depth_bridges_root.add_child(carrier)
	carrier.call(
		"configure",
		blood,
		self,
		room_id,
		camera_3d,
		CELL_PIXELS,
		BLOOD_FLOOR_WORLD_Y
	)
	if blood.has_method("bind_airborne_visual_sink"):
		blood.call("bind_airborne_visual_sink", carrier)
	blood.set_meta(&"blood_airborne_carrier", weakref(carrier))
	if carrier.has_method("sync_from_effect"):
		carrier.call("sync_from_effect", blood)


func spawn_blood_trail(
	at_position: Vector2,
	source_room_id: int = -1,
	direction: Vector2 = Vector2.ZERO,
	intensity: float = 1.0,
	airborne_count: int = 0
) -> void:
	var room_id := resolve_environment_debris_room_id(at_position, source_room_id)
	if room_id < 0 or world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return
	if not _is_blood_ground_allowed(at_position):
		return
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood == null:
		return
	blood.global_position = at_position
	# The 3D effect checks the full generated floor and actual wall colliders
	# through set_surface_context; a source-room rectangle would cut open doors.
	# Add the live effect before setup so its existing wall-ray logic has a
	# physics world and the 3D surface callback available during spray creation.
	if _add_3d_blood_effect(blood, room_id) == null:
		blood.free()
		return
	if blood.has_method("setup_trail"):
		blood.call("setup_trail", _content_rng, WORLD_WALL_LAYER, intensity, direction, airborne_count)
	_refresh_3d_blood_effect_after_setup(blood, airborne_count > 0)


## Uses the existing floor stain budget, passive capture pool and settled
## merge lifecycle. No trail is drawn for a teleport or an invalid floor start.
func spawn_corpse_drag_trail(
	world_start: Vector2,
	world_end: Vector2,
	source_room_id: int = -1,
	intensity: float = 1.0,
	width_pixels: float = 4.0
) -> bool:
	var distance := world_start.distance_to(world_end)
	if distance < 0.001 or distance > 48.0 or not _is_blood_ground_allowed(world_start):
		return false
	var room_id := resolve_environment_debris_room_id(world_start, source_room_id)
	if room_id < 0 or world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return false
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	blood.global_position = world_start
	if _add_3d_blood_effect(blood, room_id) == null:
		blood.free()
		return false
	# New cosmetic marks must not consume the existing gameplay/content stream.
	var smear_rng := RandomNumberGenerator.new()
	smear_rng.state = _content_rng.state
	blood.call("setup_drag_smear", smear_rng, WORLD_WALL_LAYER, world_start, world_end, intensity, width_pixels)
	_refresh_3d_blood_effect_after_setup(blood, false)
	return true


func spawn_black_blood(
	at_position: Vector2,
	direction: Vector2 = Vector2.ZERO,
	lethal: bool = false,
	source_room_id: int = -1,
	intensity: float = 1.0,
	droplet_multiplier: float = 1.0,
	speed_multiplier: float = 1.0,
	spread_multiplier: float = 1.0
) -> bool:
	var room_id := resolve_environment_debris_room_id(at_position, source_room_id)
	if room_id < 0 or world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return false
	if not _is_blood_ground_allowed(at_position):
		return false
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood == null:
		return false
	blood.global_position = at_position
	# Keep this unbounded by room; the full-floor validator clips actual void.
	if lethal: blood.set_meta(&"blood_ground_capture_extent",112)
	# The source must already be inside the gameplay world while setup performs
	# its real 2D wall sweep; otherwise wall hits would be skipped as off-tree.
	# A configured stain budget or a scene teardown can reject the presentation
	# node.  Report that failure to lethal-hit callers so they do not suppress
	# the existing delayed fallback when no blood was actually added.
	var added_blood := _add_3d_blood_effect(blood, room_id)
	if added_blood == null:
		blood.free()
		return false
	if blood.has_method("setup"):
		blood.set("office_impact_blot", true)
		blood.set("settle_seconds", OFFICE_BLOOD_AIRBORNE_SECONDS)
		blood.call(
			"setup",
			direction,
			lethal,
			_content_rng,
			WORLD_WALL_LAYER,
			maxf(intensity * OFFICE_BLOOD_IMPACT_INTENSITY_SCALE, OFFICE_BLOOD_IMPACT_MIN_INTENSITY),
			droplet_multiplier,
			maxf(speed_multiplier, OFFICE_BLOOD_IMPACT_SPEED_SCALE),
			maxf(spread_multiplier, OFFICE_BLOOD_IMPACT_SPREAD_SCALE)
		)
	_refresh_3d_blood_effect_after_setup(blood, true)
	return true


func spawn_death_blood_pool(
	at_position: Vector2,
	source_room_id: int = -1,
	intensity: float = 1.0,
	dismember: bool = false,
	direction: Vector2 = Vector2.ZERO
) -> void:
	var room_id := resolve_environment_debris_room_id(at_position, source_room_id)
	if room_id < 0 or world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return
	if not _is_blood_ground_allowed(at_position):
		return
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood == null:
		return
	blood.global_position = at_position
	blood.set("office_pool_core", true)
	# Sample the final expanded position against walls/floor once, so growth
	# cannot visibly cross a closed door or the outer building edge.
	blood.set("ground_sampling_scale", OFFICE_BLOOD_POOL_END_SCALE)
	if _add_3d_blood_effect(blood, room_id) == null:
		blood.free()
		return
	if blood.has_method("setup_death_pool"):
		blood.call(
			"setup_death_pool",
			_content_rng,
			WORLD_WALL_LAYER,
			maxf(intensity, OFFICE_BLOOD_IMPACT_MIN_INTENSITY) * (1.25 if dismember else 1.0),
			OFFICE_BLOOD_POOL_GROWTH_SECONDS,
			OFFICE_BLOOD_POOL_START_SCALE,
			OFFICE_BLOOD_POOL_END_SCALE,
			direction
		)
	_refresh_3d_blood_effect_after_setup(blood, false)


func spawn_death_blood_burst(
	at_position: Vector2,
	source_room_id: int = -1,
	direction: Vector2 = Vector2.RIGHT,
	dismember: bool = false
) -> void:
	# Death Burst uses one parameterized BlackBloodEffect rather than repeatedly
	# spawning ordinary hit effects.  Its semantic carrier remains unchanged.
	var burst_intensity := float(EMPLOYEE_CONFIG.get(&"death_burst_intensity"))
	if dismember:
		burst_intensity *= 1.25
	spawn_black_blood(
		at_position,
		direction,
		true,
		source_room_id,
		burst_intensity,
		float(EMPLOYEE_CONFIG.get(&"death_burst_droplet_multiplier")),
		float(EMPLOYEE_CONFIG.get(&"death_burst_speed_multiplier")),
		float(EMPLOYEE_CONFIG.get(&"death_burst_spread_multiplier"))
	)


## Corpse bleed's early pulses reuse the same BlackBloodEffect simulation but
## request a couple of low airborne droplets.  Later emitter pulses continue
## using the existing ground-only trail API.
func spawn_corpse_blood_pulse(
	at_position: Vector2,
	source_room_id: int = -1,
	direction: Vector2 = Vector2.RIGHT,
	intensity: float = 1.0,
	airborne_count: int = 0
) -> bool:
	spawn_blood_trail(at_position, source_room_id, direction, intensity, airborne_count)
	return true


func _enforce_corpse_blood_emitter_limit() -> void:
	var maximum := maxi(int(EMPLOYEE_CONFIG.get(&"max_active_corpse_blood_emitters")), 1)
	var owned_count := 0
	var oldest: Node = null
	var oldest_serial := INF
	var write := 0
	for i in range(_owned_corpse_blood_emitters.size()):
		var emitter := _owned_corpse_blood_emitters[i] as Node
		if emitter == null or not is_instance_valid(emitter) or emitter.is_queued_for_deletion():
			continue
		_owned_corpse_blood_emitters[write] = emitter
		write += 1
		var active_state: Variant = emitter.get(&"active")
		if active_state is bool and not bool(active_state):
			continue
		owned_count += 1
		var serial := int(emitter.get_meta(&"corpse_blood_spawn_serial", 0))
		if serial < oldest_serial:
			oldest_serial = serial
			oldest = emitter
	_owned_corpse_blood_emitters.resize(write)
	if owned_count >= maximum and oldest != null:
		if oldest.has_method("stop_and_free"):
			oldest.call("stop_and_free")
		else:
			oldest.call_deferred("queue_free")



func spawn_corpse_blood_emitter(
	at_position: Vector2,
	source_room_id: int = -1,
	direction: Vector2 = Vector2.RIGHT,
	intensity: float = 1.0,
	source: Node2D = null
) -> bool:
	var room_id := source_room_id if source_room_id >= 0 else current_room_id
	if room_id < 0 or CORPSE_BLOOD_EMITTER == null:
		return false
	if not _is_blood_ground_allowed(at_position):
		return false
	_enforce_corpse_blood_emitter_limit()
	var emitter := CORPSE_BLOOD_EMITTER.new() as Node2D
	if emitter == null or world_effects_root == null:
		return false
	_corpse_blood_emitter_serial += 1
	emitter.set_meta(&"dream_room_id", room_id)
	emitter.set_meta(&"blood_world_instance_id", get_instance_id())
	emitter.set_meta(&"corpse_blood_spawn_serial", _corpse_blood_emitter_serial)
	world_effects_root.add_child(emitter)
	emitter.call(
		"configure",
		self,
		at_position,
		room_id,
		direction,
		intensity,
		float(EMPLOYEE_CONFIG.get(&"corpse_bleed_duration")),
		float(EMPLOYEE_CONFIG.get(&"corpse_bleed_initial_interval")),
		float(EMPLOYEE_CONFIG.get(&"corpse_bleed_decay")),
		source
	)
	_owned_corpse_blood_emitters.append(emitter)
	return true


## Pure footprint test for the blood solver's short-lived block cache. Wall
## coverage is checked separately with a swept convex shape by the effect.
func _is_blood_ground_block_allowed(bounds: Rect2) -> bool:
	var first := Vector2i(roundi(bounds.position.x / CELL_PIXELS), roundi(bounds.position.y / CELL_PIXELS))
	var last := Vector2i(roundi(bounds.end.x / CELL_PIXELS), roundi(bounds.end.y / CELL_PIXELS))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if not floor_cells.has(Vector2i(x, y)):
				return false
	return true


func _begin_blood_ground_query_batch() -> Dictionary:
	if bool(get_meta(&"test_legacy_blood_queries",false)) or not is_instance_valid(player): return {}
	if _blood_batch_point_query == null:
		_blood_batch_point_query = PhysicsPointQueryParameters2D.new()
		_blood_batch_point_query.collision_mask = WORLD_WALL_LAYER
	return {&"floor":floor_cells,&"cell_size":CELL_PIXELS,&"point":_blood_batch_point_query,
		&"point_space":player.get_world_2d().direct_space_state}


var _reusable_blood_point_query: PhysicsPointQueryParameters2D

func _is_blood_ground_allowed(point: Vector2) -> bool:
	# Furniture impacts can bleed ON occupied floor. Furniture is not void.
	if not floor_cells.has(Vector2i(roundi(point.x/CELL_PIXELS), roundi(point.y/CELL_PIXELS))):
		return false
	if _reusable_blood_point_query == null:
		_reusable_blood_point_query = PhysicsPointQueryParameters2D.new()
		_reusable_blood_point_query.collision_mask = WORLD_WALL_LAYER
	_reusable_blood_point_query.position = point
	return player.get_world_2d().direct_space_state.intersect_point(_reusable_blood_point_query, 1).is_empty()


func spawn_wall_blood_from_hit(
	hit_position: Vector2,
	wall_normal: Vector2,
	source_room_id: int = -1,
	source_effect: BlackBloodEffect = null,
	impact_speed: float = -1.0
) -> Node2D:
	var room_id := resolve_environment_debris_room_id(hit_position, source_room_id)
	if room_id < 0 or world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return null
	var normal := wall_normal.normalized() if wall_normal.length_squared() > 0.001 else Vector2.RIGHT
	# Keep the 2D source just in front of the collision line.  The bridge below
	# places its texture on the matching vertical 3D wall plane.
	# The 2D wall blocker is intentionally thicker than the visual wall.
	# Recover the exact edge centre before placing a stain on its real face.
	var surface := hit_position
	var closest_distance := INF
	var matched_wall: Node3D = null
	var tangent := Vector2(-normal.y, normal.x)
	if _static_cutout_walls.is_empty() and is_instance_valid(wall_root):
		_prepare_wall_cutout_cache()
	if not _static_cutout_wall_bins.is_empty():
		var hit_world := to_global(Vector3(hit_position.x / CELL_PIXELS, 0.0, hit_position.y / CELL_PIXELS))
		var min_bx := int(floor((hit_world.x - 1.0) / 4.0))
		var max_bx := int(floor((hit_world.x + 1.0) / 4.0))
		var min_bz := int(floor((hit_world.z - 1.0) / 4.0))
		var max_bz := int(floor((hit_world.z + 1.0) / 4.0))
		for bz in range(min_bz, max_bz + 1):
			for bx in range(min_bx, max_bx + 1):
				var bin_indices: Array = _static_cutout_wall_bins.get(Vector2i(bx, bz), [])
				for idx in bin_indices:
					var wall := _static_cutout_walls[idx] as Node3D
					if wall == null or not is_instance_valid(wall):
						continue
					var edge: Dictionary = _static_cutout_wall_edges[idx]
					var axis := String(edge.get("axis", ""))
					if (axis == "H" and absf(normal.y) < 0.5) or (axis == "V" and absf(normal.x) < 0.5):
						continue
					var wall_local := to_local(_static_cutout_wall_positions[idx])
					var centre := Vector2(wall_local.x, wall_local.z) * CELL_PIXELS
					if absf((hit_position - centre).dot(tangent)) > CELL_PIXELS * 0.6:
						continue
					var distance := absf((hit_position - centre).dot(normal))
					if distance < closest_distance and distance < CELL_PIXELS * 0.6:
						closest_distance = distance
						matched_wall = wall
						surface = hit_position - normal * (hit_position - centre).dot(normal) + normal * (wall_thickness * CELL_PIXELS * 0.5 + 0.05)
	if matched_wall == null:
		for wall in wall_root.get_children():
			var edge: Dictionary = wall.get_meta(&"edge", {})
			# At a corner the perpendicular wall can be closer to the hit point,
			# but is never the surface whose collision normal was returned.
			if (String(edge.get("axis","")) == "H" and absf(normal.y) < 0.5) or (String(edge.get("axis","")) == "V" and absf(normal.x) < 0.5):
				continue
			var wall_local := to_local(wall.global_position)
			var centre := Vector2(wall_local.x, wall_local.z) * CELL_PIXELS
			if absf((hit_position - centre).dot(tangent)) > CELL_PIXELS * 0.6:
				continue
			var distance := absf((hit_position - centre).dot(normal))
			if distance < closest_distance and distance < CELL_PIXELS * 0.6:
				closest_distance = distance
				matched_wall = wall
				surface = hit_position - normal * (hit_position - centre).dot(normal) + normal * (wall_thickness * CELL_PIXELS * 0.5 + 0.05)
	if matched_wall == null:
		# Never leave a vertical stain floating in a doorway or on empty floor.
		return null
	# 同一面墙的后续血滴全部累加进源效果在墙上的已有血迹，
	# 形成真实的喷溅分布，而不是每滴血各生成一个固定圆斑。
	var edge_key := String(matched_wall.get_meta(&"edge_key", ""))
	if source_effect != null:
		var existing: BlackBloodEffect = source_effect.wall_stain_for_key(edge_key)
		if existing != null:
			existing.append_wall_impact(hit_position, normal, impact_speed, _content_rng)
			return existing
		if not source_effect.can_register_wall_stain(edge_key):
			return null
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood == null:
		return null
	blood.global_position = surface
	if blood.has_method("setup_wall_stain"):
		blood.call("setup_wall_stain", normal, _content_rng, impact_speed)
	# setup_wall_stain rotates its 2D drawing for the old WallLayer.  The 3D
	# plane itself carries that normal, so keep the captured stain axes stable.
	blood.rotation = 0.0
	if not _enforce_3d_blood_limit():
		blood.free()
		return null
	_register_black_blood_stain(blood)
	world_effects_root.add_child(blood)
	blood.set_meta(&"blood_wall_edge_key", edge_key)
	blood.set_meta(&"dream_room_id", room_id)
	if source_effect != null:
		source_effect.register_wall_stain(edge_key, blood)
	var wall_yaw := atan2(normal.x, normal.y)
	var stain_height := clampf(wall_height * 0.45, 0.25, 6.0)
	var stain_rot := Vector3(0.0, wall_yaw, 0.0)
	blood.set_meta(&"blood_surface_height", stain_height)
	blood.set_meta(&"blood_surface_rotation", stain_rot)
	blood.set_meta(&"blood_surface_follow", false)
	if not bool(get_meta(&"test_legacy_blood_ground_capture", false)):
		_get_blood_ground_capture_pool().acquire_surface(blood, camera_3d, stain_height, stain_rot, false)
	else:
		_spawn_depth_bridge(
			blood,
			[NodePath(".")],
			Vector2(64.0, 64.0),
			BaseMaterial3D.BILLBOARD_DISABLED,
			stain_height,
			0.0,
			stain_rot,
			false,
			true
		)
	return blood


func is_blood_door_collider(collider: Object) -> bool:
	return collider is Node and (collider as Node).has_meta(&"physical_door")


## Blood that reaches a physical door paints the swinging leaf itself: the
## stain is parented to the door's synced 2D collision body, so it travels and
## rotates with the door. The depth bridge follows the source rotation so the
## 3D plane stays on the leaf's current face. A hit door never lets a droplet
## through to a false floor stain behind it.
func spawn_door_blood_from_hit(
	hit_position: Vector2,
	wall_normal: Vector2,
	door_body: Node2D,
	source_effect: BlackBloodEffect = null,
	impact_speed: float = -1.0
) -> Node2D:
	if door_body == null or not is_instance_valid(door_body) or BLACK_BLOOD_EFFECT == null:
		return null
	var normal := wall_normal.normalized() if wall_normal.length_squared() > 0.001 else Vector2.RIGHT
	var door_key := "door_%d" % door_body.get_instance_id()
	if source_effect != null:
		var existing: BlackBloodEffect = source_effect.wall_stain_for_key(door_key)
		if existing != null:
			existing.append_wall_impact(hit_position, normal, impact_speed, _content_rng)
			return existing
		if not source_effect.can_register_wall_stain(door_key):
			return null
	if not _enforce_3d_blood_limit():
		return null
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood == null:
		return null
	blood.name = "DoorBloodEffect"
	door_body.add_child(blood)
	# The synced leaf blocker is thin; sit the stain just on the struck face.
	blood.global_position = hit_position - normal * 1.0
	if blood.has_method("setup_wall_stain"):
		blood.call("setup_wall_stain", normal, _content_rng, impact_speed)
	# Keep the 2D normal rotation so the stain rides the leaf; the bridge's
	# follow-source-rotation mode derives the vertical plane yaw per frame.
	_register_black_blood_stain(blood)
	if source_effect != null:
		source_effect.register_wall_stain(door_key, blood)
	blood.set_meta(&"blood_surface_height", 0.9)
	blood.set_meta(&"blood_surface_rotation", Vector3.ZERO)
	blood.set_meta(&"blood_surface_follow", true)
	if not bool(get_meta(&"test_legacy_blood_ground_capture", false)):
		_get_blood_ground_capture_pool().acquire_surface(blood, camera_3d, 0.9, Vector3.ZERO, true)
	else:
		_spawn_depth_bridge(
			blood,
			[NodePath(".")],
			Vector2(64.0, 64.0),
			BaseMaterial3D.BILLBOARD_DISABLED,
			0.9,
			0.0,
			Vector3.ZERO,
			false,
			true,
			true
		)
	return blood


func is_wall_blood_surface_collider(collider: Node) -> bool:
	if collider == null:
		return false
	# Fixed wall stains must bind to actual wall faces, not a moving DoorLeaf.
	# A future door stain must explicitly follow the rigid leaf's local frame.
	return collider.has_meta(&"generated_wall_edge")


## Resolve the live 2D shooter recorded by BasicProjectile without retaining a
## Node reference in the projectile.  The resulting bridge plane is a
## presentation anchor only; gameplay remains entirely in the 2D owner.
func _projectile_shooter(projectile: Node2D) -> Node2D:
	if projectile == null or not is_instance_valid(projectile):
		return null
	var shooter_id_variant: Variant = projectile.get(&"shooter_instance_id")
	if shooter_id_variant is int or shooter_id_variant is float:
		var shooter_id := int(shooter_id_variant)
		if shooter_id > 0 and is_instance_id_valid(shooter_id):
			return instance_from_id(shooter_id) as Node2D
	return null


## Resolve the formal 2D muzzle through the held weapon's reference space.
## The bridge owns the projection; gameplay Aim and damage remain unchanged.
func _weapon_visual_snapshot(source_actor: Node2D, gameplay_position: Vector2) -> Dictionary:
	if has_meta(&"test_shot_snapshot_count"):
		set_meta(&"test_shot_snapshot_count", int(get_meta(&"test_shot_snapshot_count")) + 1)
	if not is_instance_valid(source_actor) or not source_actor.has_meta(&"depth_visual_bridge"):
		return {}
	var reference: Variant = source_actor.get_meta(&"depth_visual_bridge")
	var bridge: Node = reference.get_ref() if reference is WeakRef else null
	if is_instance_valid(bridge) and bridge.has_method("get_weapon_visual_snapshot"):
		return bridge.call("get_weapon_visual_snapshot", gameplay_position)
	return {}


func _capture_shot_visual_origin(effect: Node2D, source_actor: Node2D, resolved_snapshot: Variant = null) -> void:
	var snapshot: Dictionary = _weapon_visual_snapshot(source_actor, effect.global_position) if resolved_snapshot == null else resolved_snapshot
	if snapshot.is_empty():
		return
	# Value snapshot, never a live shooter dependency after firing.
	effect.set_meta(&"shot_visual_origin", snapshot["world_origin"])
	effect.set_meta(&"shot_gameplay_origin", snapshot["gameplay_origin"])


func _actor_muzzle_visual_plane(source_actor: Node2D, muzzle_position: Vector2, resolved_snapshot: Variant = null) -> Vector2:
	var snapshot: Dictionary = _weapon_visual_snapshot(source_actor, muzzle_position) if resolved_snapshot == null else resolved_snapshot
	if not snapshot.is_empty():
		var point: Vector3 = snapshot["world_origin"]
		var map_point := to_local(point)
		return Vector2(map_point.y, map_point.z - muzzle_position.y / CELL_PIXELS)
	var fallback := Vector2(PROJECTILE_MUZZLE_VISUAL_HEIGHT, PROJECTILE_MUZZLE_DEPTH_OFFSET)
	if source_actor == null or not is_instance_valid(source_actor):
		return fallback
	# Prefer the live bridge, but keep a deterministic actor-plane fallback for
	# the short interval in which a projectile can be registered before its
	# dynamically-created bridge metadata is visible.  Formal actors use the
	# same authored capture offset in that fallback; non-actor effects retain the
	# explicit flat fallback below.
	var actor_anchor := to_global(Vector3(
		source_actor.global_position.x / CELL_PIXELS,
		0.70710678,
		source_actor.global_position.y / CELL_PIXELS - 0.70710678
	))
	var camera_basis := Basis.IDENTITY
	var actor_sprite: Sprite3D = null
	var source_bridge: Node3D = null
	if source_actor.has_meta(&"depth_visual_bridge"):
		var bridge_variant: Variant = source_actor.get_meta(&"depth_visual_bridge")
		var bridge: Node3D = bridge_variant.get_ref() if bridge_variant is WeakRef else null
		if bridge != null and is_instance_valid(bridge):
			source_bridge = bridge
			actor_sprite = bridge.get(&"actor_sprite") as Sprite3D
	if actor_sprite != null and is_instance_valid(actor_sprite):
		actor_anchor = actor_sprite.global_position
		# The bridge is processed independently from the gameplay actor.  Its
		# cached X/Z can therefore lag one frame while the player is moving; keep
		# the presentation height from the bridge (including fake-height/contact
		# lift) but derive the current ground coordinates from the authoritative
		# 2D actor and the bridge's own depth baseline.
		var anchor_in_map := to_local(actor_anchor)
		anchor_in_map.x = source_actor.global_position.x / CELL_PIXELS
		var depth_offset_variant: Variant = source_bridge.get(&"actor_center_depth_offset")
		var depth_offset := -0.70710678
		if depth_offset_variant is float or depth_offset_variant is int:
			depth_offset = float(depth_offset_variant)
		anchor_in_map.z = source_actor.global_position.y / CELL_PIXELS + depth_offset
		actor_anchor = to_global(anchor_in_map)
		camera_basis = actor_sprite.global_basis.orthonormalized()
	else:
		# Only formal Player/Enemy actors have the upright ActorDepthBridge
		# baseline.  Effects/pickups without a bridge still use the explicit
		# legacy flat fallback rather than inheriting a character height.
		if not source_actor.is_in_group(&"dream_player") and not source_actor.is_in_group(&"dream_enemies"):
			return fallback
	if camera_3d != null and is_instance_valid(camera_3d):
		camera_basis = camera_3d.global_basis.orthonormalized()
	var local_2d := muzzle_position - source_actor.global_position
	# The authored ActorDepthBridge does not place the gameplay pivot at the
	# SubViewport centre: it captures the actor into `viewport_offset` and then
	# presents that texture centred on the Sprite3D.  Convert the muzzle through
	# that exact capture coordinate, otherwise a muzzle above the gameplay pivot
	# is lifted by the full 2D distance a second time (the visible bullet then
	# appears far above the held weapon in the perspective camera).
	var capture_local := local_2d
	if source_bridge != null and is_instance_valid(source_bridge):
		var bridge_offset_variant: Variant = source_bridge.get(&"viewport_offset")
		var bridge_offset := Vector2.ZERO
		if bridge_offset_variant is Vector2:
			bridge_offset = bridge_offset_variant
		var bridge_viewport := source_bridge.get(&"render_viewport") as SubViewport
		var viewport_center := Vector2(64.0, 64.0)
		if bridge_viewport != null and is_instance_valid(bridge_viewport):
			viewport_center = Vector2(bridge_viewport.size) * 0.5
		capture_local += bridge_offset - viewport_center
	else:
		# Player/Enemy bridges use the authored 128x128 capture with an offset of
		# (64,96).  If a projectile is registered in the same frame as an actor's
		# bridge, retain that exact default mapping instead of falling back to the
		# old world-flat height.  This keeps the first frame continuous as well.
		if source_actor.is_in_group(&"dream_player") or source_actor.is_in_group(&"dream_enemies"):
			capture_local += Vector2(0.0, 32.0)
	# A positive capture Y points down. Sprite3D local +Y points up, hence the
	# negative sign when lifting the muzzle within the actor's camera plane.
	var visual_lift := camera_basis * Vector3(capture_local.x / CELL_PIXELS, -capture_local.y / CELL_PIXELS, 0.0)
	var muzzle_in_map := to_local(actor_anchor + visual_lift)
	return Vector2(muzzle_in_map.y, muzzle_in_map.z - muzzle_position.y / CELL_PIXELS)


func _projectile_visual_plane(projectile: Node2D) -> Vector2:
	return _actor_muzzle_visual_plane(_projectile_shooter(projectile), projectile.global_position)


func uses_pixel_combat_vfx()->bool:
	# A diagnostic override supports controlled A/B; normal formal worlds use
	# the approved style without a preview installer or saved-setting migration.
	return bool(get_meta(&"pixel_combat_vfx_enabled",true))

func spawn_weapon_muzzle(at_position: Vector2, direction: Vector2, effect_kind: StringName, source_actor: Node2D = null) -> void:
	# One shot snapshot is shared by the flash, its depth carrier and the pooled
	# light. Never infer a separate 3D height from the gameplay muzzle position.
	var snapshot := _weapon_visual_snapshot(source_actor, at_position)
	var muzzle_plane := _actor_muzzle_visual_plane(source_actor, at_position) if snapshot.is_empty() else Vector2.ZERO
	var muzzle_world := get_gameplay_world_position(at_position, muzzle_plane.x)
	if not snapshot.is_empty():
		muzzle_world = snapshot["world_origin"]
		var map_point := to_local(muzzle_world)
		muzzle_plane = Vector2(map_point.y, map_point.z - at_position.y / CELL_PIXELS)
	if is_instance_valid(night_lighting):
		if night_lighting.has_method("flash_muzzle_world"):
			night_lighting.call("flash_muzzle_world", muzzle_world, effect_kind)
		else:
			night_lighting.flash_muzzle(at_position, effect_kind)
	if MUZZLE_EFFECT_SCENE == null or world_effects_root == null:
		return
	var effect := MUZZLE_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	world_effects_root.add_child(effect)
	# The source retains its gameplay angle; only its passive 3D capture is
	# reoriented through the current camera, just like the projectile tracer.
	effect.set_meta(&"depth_visual_camera_plane", true)
	effect.set_meta(&"shot_gameplay_direction", direction.normalized())
	effect.global_position = at_position
	if not snapshot.is_empty():
		effect.set_meta(&"shot_visual_origin", muzzle_world)
		effect.set_meta(&"shot_gameplay_origin", at_position)
	else:
		_capture_shot_visual_origin(effect, source_actor)
	var duration := EMPLOYEE_CONFIG.weapon_muzzle_flash_seconds
	if effect.has_method("setup"):
		effect.call("setup", direction, effect_kind, duration, EMPLOYEE_CONFIG.weapon_effect_primary_color, EMPLOYEE_CONFIG.weapon_effect_secondary_color)
	if effect.has_method("enable_office_3d_style"):
		effect.call("enable_office_3d_style")
	if uses_pixel_combat_vfx():
		effect.enable_nyangeon_style()
	# Unknown callers without an actor snapshot keep their original flat path.
	if snapshot.is_empty() or bool(get_meta(&"test_legacy_muzzle_capture",false)):
		_spawn_depth_bridge(effect,[^"."],Vector2(64,64),BaseMaterial3D.BILLBOARD_ENABLED,muzzle_plane.x,muzzle_plane.y,Vector3.ZERO,false)
	else:
		_get_muzzle_capture_pool().acquire(effect,camera_3d,muzzle_plane.x,muzzle_plane.y)


func spawn_firearm_impact_visual(hit_position: Vector2, hit_normal: Vector2, collider: Node, shot_height_pixels: float) -> void:
	# The formal 2D swept hit alone decides whether an impact happened. These
	# short-lived 3D pixels never collide, damage, or affect line of sight.
	if collider == null or floor_root == null or FIREARM_IMPACT_SCENE == null:
		return
	var target := collider.call("get_damage_owner") as Node if collider.has_method("get_damage_owner") else collider
	if target == null or target.is_in_group(&"dream_enemies") or target.is_in_group(&"dream_player"):
		return
	if _active_firearm_impact_count >= MAX_ACTIVE_FIREARM_IMPACT_VISUALS:
		return
	var surface_kind: StringName = &"solid"
	if target.is_in_group(&"glass_windows") or collider.is_in_group(&"glass_windows"):
		surface_kind = &"glass"
	elif collider.has_meta(&"physical_door") or target.has_meta(&"physical_door"):
		surface_kind = &"metal"
	elif target.is_in_group(&"damageable_props"):
		var furniture_kind := String(target.get_meta(&"office_furniture_kind", ""))
		if furniture_kind in ["cabinet", "cabinet_open", "shelf", "server", "copier", "fridge", "bin"]:
			surface_kind = &"metal"
		elif furniture_kind in ["chair", "sofa", "plant", "box"]:
			surface_kind = &"soft"
	var normal_2d := hit_normal.normalized() if hit_normal.length_squared() > 0.0001 else Vector2.UP
	var normal_world := (global_basis * Vector3(normal_2d.x, 0.0, normal_2d.y)).normalized()
	var height := shot_height_pixels / CELL_PIXELS if shot_height_pixels > 0.0 else 0.65
	var effect := FIREARM_IMPACT_SCENE.instantiate() as Node3D
	if effect == null:
		return
	floor_root.add_child(effect)
	effect.add_to_group(&"firearm_impact_visuals")
	_active_firearm_impact_count += 1
	effect.tree_exiting.connect(_on_firearm_impact_exiting, Object.CONNECT_ONE_SHOT)
	effect.global_basis = Basis.IDENTITY
	effect.global_position = get_gameplay_world_position(hit_position, height) + normal_world * 0.015
	if effect.has_method("setup"):
		effect.call("setup", normal_world, surface_kind)


func _on_firearm_impact_exiting() -> void:
	_active_firearm_impact_count = maxi(_active_firearm_impact_count - 1, 0)


func spawn_combat_feedback(at_position: Vector2, direction: Vector2 = Vector2.ZERO, is_kill: bool = false, sample_gun_hit: bool = false, hit_actor: Node2D = null) -> void:
	if COMBAT_FEEDBACK_SCENE == null or world_effects_root == null:
		return
	var effect := COMBAT_FEEDBACK_SCENE.instantiate() as Node2D
	if effect == null:
		return
	world_effects_root.add_child(effect)
	effect.global_position = at_position
	if effect.has_method("setup"):
		effect.call("setup", direction, is_kill, EMPLOYEE_CONFIG.kill_pop_animation_seconds if is_kill else EMPLOYEE_CONFIG.weapon_hit_effect_seconds, EMPLOYEE_CONFIG.weapon_effect_primary_color, EMPLOYEE_CONFIG.weapon_effect_secondary_color, EMPLOYEE_CONFIG.weapon_effect_warning_color)
	if sample_gun_hit and uses_pixel_combat_vfx():
		effect.enable_nyangeon_style()
		effect.set_meta(&"feedback_height",.65)
		if is_instance_valid(hit_actor):
			var reference: Variant=hit_actor.get_meta(&"depth_visual_bridge") if hit_actor.has_meta(&"depth_visual_bridge") else null
			var actor_bridge: Node=reference.get_ref() if reference is WeakRef else null
			if is_instance_valid(actor_bridge) and actor_bridge.has_method("get_hit_feedback_world_position"):
				effect.set_meta(&"depth_visual_camera_plane",true)
				effect.set_meta(&"shot_visual_origin",actor_bridge.get_hit_feedback_world_position())
				effect.set_meta(&"shot_gameplay_origin",at_position)
				var plane: Dictionary=actor_bridge.get_hit_feedback_depth_plane()
				if not plane.is_empty():
					effect.set_meta(&"hit_reference_plane_origin",plane.origin)
					effect.set_meta(&"hit_reference_plane_normal",plane.normal)
	if bool(get_meta(&"test_legacy_feedback_capture",false)):
		_spawn_depth_bridge(effect, [NodePath(".")], Vector2(64.0, 64.0), BaseMaterial3D.BILLBOARD_ENABLED, 0.14, 0.0, Vector3.ZERO, false)
	else:
		_get_feedback_capture_pool().acquire(effect,camera_3d)


func spawn_bullet_sequence(at_position: Vector2, direction: Vector2) -> void:
	if PROJECTILE_SEQUENCE_SCENE == null or world_effects_root == null:
		return
	var effect := PROJECTILE_SEQUENCE_SCENE.instantiate() as Node2D
	if effect == null:
		return
	world_effects_root.add_child(effect)
	effect.global_position = at_position
	if effect.has_method("setup"):
		effect.call("setup", direction)
	_spawn_depth_bridge(effect, [NodePath(".")], Vector2(64.0, 64.0), BaseMaterial3D.BILLBOARD_ENABLED, 0.14, 0.0, Vector3.ZERO, false)


func request_hit_stop(kind: StringName = &"") -> void:
	if get_tree().paused:
		return
	var duration := float(EMPLOYEE_CONFIG.hit_stop_duration)
	match kind:
		&"medium": duration = float(EMPLOYEE_CONFIG.hit_stop_medium_duration)
		&"heavy": duration = float(EMPLOYEE_CONFIG.hit_stop_heavy_duration)
		_: pass
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("request_hit_stop"):
		time_controller.call(
			"request_hit_stop",
			float(EMPLOYEE_CONFIG.hit_stop_time_scale),
			duration,
			float(EMPLOYEE_CONFIG.hit_stop_minimum_interval)
		)


func reset_hit_stop() -> void:
	var time_controller: Node = _get_dream_time_controller()
	if time_controller != null and time_controller.has_method("reset_hit_stop"):
		time_controller.call("reset_hit_stop")


func _configure_projectile_local_light_pool() -> void:
	_clear_projectile_local_light_pool()
	if config == null or not bool(config.get(&"projectile_local_light_enabled")):
		return
	var configured_size_variant: Variant = config.get(&"projectile_local_light_pool_size")
	var pool_size := 8 if configured_size_variant == null else clampi(int(configured_size_variant), 1, 32)
	var energy_variant: Variant = config.get(&"projectile_local_light_energy")
	var range_variant: Variant = config.get(&"projectile_local_light_range")
	var attenuation_variant: Variant = config.get(&"projectile_local_light_attenuation")
	var color_variant: Variant = config.get(&"projectile_local_light_color")
	var energy := 0.08 if energy_variant == null else clampf(float(energy_variant), 0.0, 1.0)
	var light_range := 0.55 if range_variant == null else clampf(float(range_variant), 0.05, 2.0)
	var attenuation := 1.0 if attenuation_variant == null else clampf(float(attenuation_variant), 0.0, 2.0)
	var light_color := Color.WHITE
	if color_variant is Color:
		light_color = color_variant
	for index in range(pool_size):
		var light := OmniLight3D.new()
		light.name = "ProjectileLocalLight%d" % index
		light.omni_range = light_range
		light.omni_attenuation = attenuation
		light.light_energy = energy
		light.light_color = light_color
		light.light_specular = 0.0
		light.light_cull_mask = 1 | 2 | 8  # + furniture cutout layer
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		projectile_local_light_pool.append(light)
		projectile_light_slot_owner_ids.append(0)


func _clear_projectile_local_light_pool() -> void:
	for light in projectile_local_light_pool:
		if is_instance_valid(light):
			light.visible = false
			light.queue_free()
	projectile_local_light_pool.clear()
	projectile_light_slot_owner_ids.clear()
	projectile_light_assignments.clear()


func _release_projectile_local_light(projectile_id: int) -> void:
	var slot_variant: Variant = projectile_light_assignments.get(projectile_id, -1)
	var slot := int(slot_variant)
	if slot >= 0 and slot < projectile_local_light_pool.size():
		projectile_local_light_pool[slot].visible = false
		projectile_light_slot_owner_ids[slot] = 0
	projectile_light_assignments.erase(projectile_id)


func _register_projectile_local_light(projectile: Node2D) -> void:
	if projectile == null or not is_instance_valid(projectile) or projectile_local_light_pool.is_empty():
		return
	var projectile_id := projectile.get_instance_id()
	if projectile_light_assignments.has(projectile_id):
		return
	var free_slot := -1
	for index in range(projectile_light_slot_owner_ids.size()):
		if projectile_light_slot_owner_ids[index] <= 0:
			free_slot = index
			break
	if free_slot < 0:
		# A full pool is an intentional visual-only overflow. The projectile
		# remains fully functional without a local light.
		return
	projectile_light_slot_owner_ids[free_slot] = projectile_id
	projectile_light_assignments[projectile_id] = free_slot
	projectile_local_light_pool[free_slot].visible = false


func _update_projectile_local_lights() -> void:
	if projectile_light_assignments.is_empty():
		return
	var assignment_ids: Array = projectile_light_assignments.keys()
	for id_variant in assignment_ids:
		var projectile_id := int(id_variant)
		var projectile := instance_from_id(projectile_id) as Node2D
		if (
			projectile == null
			or not is_instance_valid(projectile)
			or projectile.is_queued_for_deletion()
			or not projectile.is_inside_tree()
			or not projectile.is_in_group(&"dream_projectiles")
			or not projectile.visible
			or not _is_population_position_visible(projectile.global_position)
		):
			_release_projectile_local_light(projectile_id)
			continue
		var slot := int(projectile_light_assignments.get(projectile_id, -1))
		if slot < 0 or slot >= projectile_local_light_pool.size():
			_release_projectile_local_light(projectile_id)
			continue
		var light := projectile_local_light_pool[slot]
		light.global_position = to_global(_map_gameplay_to_world(projectile.global_position) + Vector3.UP * 0.18)
		light.visible = true


func _get_projectile_capture_pool() -> Node3D:
	var pool := actor_depth_bridges_root.get_node_or_null(^"ProjectileCapturePool") as Node3D
	if pool == null:
		pool = PROJECTILE_CAPTURE_POOL.new()
		pool.name = "ProjectileCapturePool"
		actor_depth_bridges_root.add_child(pool)
	return pool

func _get_muzzle_capture_pool() -> Node3D:
	var pool := actor_depth_bridges_root.get_node_or_null(^"MuzzleCapturePool") as Node3D
	if pool == null:
		pool = MUZZLE_CAPTURE_POOL.new()
		pool.name = "MuzzleCapturePool"
		actor_depth_bridges_root.add_child(pool)
	return pool

func _get_feedback_capture_pool() -> Node3D:
	var pool := actor_depth_bridges_root.get_node_or_null(^"FeedbackCapturePool") as Node3D
	if pool==null:
		pool=FEEDBACK_CAPTURE_POOL.new()
		pool.name="FeedbackCapturePool"
		actor_depth_bridges_root.add_child(pool)
	return pool

func _get_blood_ground_capture_pool() -> Node3D:
	var pool := actor_depth_bridges_root.get_node_or_null(^"BloodGroundCapturePool") as Node3D
	if pool==null:
		pool=BLOOD_GROUND_CAPTURE_POOL.new(); pool.name="BloodGroundCapturePool"
		actor_depth_bridges_root.add_child(pool)
	return pool

func _get_floor_object_capture_pool() -> Node3D:
	var pool := actor_depth_bridges_root.get_node_or_null(^"FloorObjectCapturePool") as Node3D
	if pool==null:
		pool=FLOOR_OBJECT_CAPTURE_POOL.new(); pool.name="FloorObjectCapturePool"
		actor_depth_bridges_root.add_child(pool)
	return pool

func add_projectile(projectile: Node2D, source_actor: Node2D = null) -> void:
	if projectile != null and gameplay_world != null:
		if projectile.has_method("enable_office_ballistics"):
			projectile.call("enable_office_ballistics")
		if not projectile.is_in_group(&"dream_projectiles"):
			projectile.add_to_group(&"dream_projectiles")
		if projectile.get_parent() == null:
			world_effects_root.add_child(projectile)
		# Keep the real Node2D projectile as the only gameplay bullet, but route
		# its single contiguous BulletSprite tracer through the same depth-tested
		# 3D carrier used by Player and Enemy visuals.  The head and rear gradient
		# are one texture, so they cannot acquire separate 3D depth/vertical
		# transforms.  The bridge self-cleans when the projectile despawns.
		# Prefer the explicit shooter supplied by the weapon call.  The projectile
		# still stores its instance ID as a fallback for older callers, but the
		# direct reference removes any timing/metadata race at the spawn frame.
		var visual_source := source_actor if source_actor != null and is_instance_valid(source_actor) else _projectile_shooter(projectile)
		# Resolve exactly once at this shot, not once for its origin and again for
		# its plane. Each resolution synchronizes the entire character bridge.
		# No cross-frame cache: movement, equipment and camera changes stay live.
		var projectile_plane: Vector2
		if bool(get_meta(&"test_legacy_shot_snapshot", false)):
			_capture_shot_visual_origin(projectile, visual_source)
			projectile_plane = _actor_muzzle_visual_plane(visual_source, projectile.global_position)
		else:
			var snapshot := _weapon_visual_snapshot(visual_source, projectile.global_position)
			_capture_shot_visual_origin(projectile, visual_source, snapshot)
			projectile_plane = _actor_muzzle_visual_plane(visual_source, projectile.global_position, snapshot)
		projectile.set_meta(&"shot_height_pixels", projectile_plane.x * CELL_PIXELS)
		# Same capture geometry, texture/shader and formal origin, allocated while
		# loading rather than on every pellet of a multiplayer volley.
		if bool(get_meta(&"test_legacy_projectile_capture", false)):
			_spawn_depth_bridge(projectile, [^"BulletSprite"], Vector2(256,256), BaseMaterial3D.BILLBOARD_ENABLED, projectile_plane.x, projectile_plane.y)
		else:
			_get_projectile_capture_pool().acquire(projectile, camera_3d, projectile_plane.x, projectile_plane.y)
		_register_projectile_local_light(projectile)


func add_weapon_effect(effect: Node2D) -> void:
	if effect != null and gameplay_world != null:
		if not effect.is_in_group(&"dream_transient_effects"):
			effect.add_to_group(&"dream_transient_effects")
		if effect.get_parent() == null:
			world_effects_root.add_child(effect) if world_effects_root != null else gameplay_world.add_child(effect)
		_spawn_depth_bridge(effect, [NodePath(".")], Vector2(64.0, 64.0), BaseMaterial3D.BILLBOARD_ENABLED, 0.16, 0.0, Vector3.ZERO, false)


func is_furniture_shot_path_clear(from_position: Vector2, to_position: Vector2, source_actor: Node2D) -> bool:
	if source_actor == null or not source_actor.is_inside_tree():
		return false
	var height_pixels := NAN
	var excluded: Array[RID] = []
	if source_actor is CollisionObject2D:
		excluded.append(source_actor.get_rid())
	var space_state := source_actor.get_world_2d().direct_space_state
	if _furniture_shot_path_query == null:
		_furniture_shot_path_query = PhysicsRayQueryParameters2D.new()
		_furniture_shot_path_query.collision_mask = WORLD_WALL_LAYER | 4 | 8
		_furniture_shot_path_query.hit_from_inside = true
		_furniture_shot_path_query.collide_with_bodies = true
	_furniture_shot_path_query.from = from_position
	_furniture_shot_path_query.to = to_position
	for _attempt in range(32):
		_furniture_shot_path_query.exclude = excluded
		var hit := space_state.intersect_ray(_furniture_shot_path_query)
		if hit.is_empty():
			return true
		var collider := hit.get("collider") as Node2D
		if collider == null or not collider.is_in_group(&"damageable_props"):
			return false
		if is_nan(height_pixels):
			height_pixels = _actor_muzzle_visual_plane(source_actor, from_position).x * CELL_PIXELS
		if not preload("res://scripts/dream/office_furniture_catalog.gd").shot_hit(collider, from_position, to_position, height_pixels).is_empty():
			return false
		if collider is CollisionObject2D:
			excluded.append(collider.get_rid())
		else:
			return false
	return false


func is_room_projectile_path_clear(from_position: Vector2, to_position: Vector2) -> bool:
	if player == null or not player.is_inside_tree():
		return true
	var space := player.get_world_2d().direct_space_state
	var excluded: Array[RID] = []
	if _room_path_clear_query == null:
		_room_path_clear_query = PhysicsRayQueryParameters2D.new()
		_room_path_clear_query.collision_mask = WORLD_WALL_LAYER | 4 | 8
		_room_path_clear_query.collide_with_bodies = true
		_room_path_clear_query.collide_with_areas = false
	_room_path_clear_query.from = from_position
	_room_path_clear_query.to = to_position
	for _i in range(8):
		_room_path_clear_query.exclude = excluded
		var hit := space.intersect_ray(_room_path_clear_query)
		if hit.is_empty():
			return true
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.is_in_group(&"damageable_props"):
			var allows_pass := false
			if collider.has_method("get_size_category"):
				var cat: int = int(collider.call("get_size_category"))
				if cat == 1 or cat == 2:
					allows_pass = true
			elif collider.has_method("is_vaultable") and bool(collider.call("is_vaultable")):
				allows_pass = true
			elif collider.get("vaultable") == true:
				allows_pass = true
			if allows_pass:
				if collider is CollisionObject2D:
					excluded.append((collider as CollisionObject2D).get_rid())
					continue
		return false
	return true


func resolve_player_hit(enemy: Node, base_damage: float, hit_origin: Vector2, damage_source: StringName = &"player_projectile") -> Dictionary:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("dead") == true:
		return {}
	if enemy.has_method("is_damage_runtime_active") and not bool(enemy.is_damage_runtime_active()):
		return {}
	var resolved_damage := base_damage
	var damage_result: Dictionary = {}
	if player != null and player.has_method("calculate_player_damage"):
		var calculated_variant: Variant = player.call("calculate_player_damage", base_damage)
		if calculated_variant is Dictionary:
			damage_result = calculated_variant
			resolved_damage = float(damage_result.get("damage", base_damage))
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", resolved_damage, hit_origin, 1.0, damage_source)
	# Keep impact audio at the authoritative accepted-hit boundary.  This is
	# shared by every 3D projectile path and avoids a visual/bridge callback
	# swallowing or delaying the feedback.
	var source_text := String(damage_source)
	if source_text.begins_with("player_projectile"):
		SFX.play_bullet_enemy_hit()
	elif damage_source in [&"lucille", &"books"]:
		SFX.play_melee_enemy_hit()
	if damage_result.is_empty():
		damage_result = {"damage": resolved_damage}
	damage_result["source"] = damage_source
	return damage_result


func _show_damage_feedback(_enemy: Node2D, _result: Dictionary, _damage_anchor: Vector2) -> void:
	# 3D Dream keeps accepted-hit gameplay/audio, but has no damage/critical text.
	pass


func resolve_enemy_projectile_hit(enemy: Node, raw_damage: float, hit_origin: Vector2, shooter_instance_id: int = 0, weapon_id: StringName = &"basic") -> Dictionary:
	if enemy == null or not is_instance_valid(enemy) or enemy.get_instance_id() == shooter_instance_id or enemy.get("dead") == true:
		return {}
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", raw_damage, hit_origin, 1.0, StringName("enemy_projectile_%s" % String(weapon_id)))
	return {"damage": raw_damage, "weapon_id": weapon_id}




func get_damageable_props_snapshot() -> Array:
	var frame := Engine.get_process_frames()
	if frame == _cached_damageable_props_frame and not _cached_damageable_props.is_empty():
		return _cached_damageable_props
	# Reuse for a couple of frames — pit checks and melee sweeps share this list.
	if frame - _cached_damageable_props_frame <= 2 and not _cached_damageable_props.is_empty():
		return _cached_damageable_props
	_cached_damageable_props_frame = frame
	_cached_damageable_props = get_tree().get_nodes_in_group(&"damageable_props")
	return _cached_damageable_props


func get_dream_enemies_snapshot() -> Array:
	var frame := Engine.get_process_frames()
	if frame == _cached_dream_enemies_frame and not _cached_dream_enemies.is_empty():
		return _cached_dream_enemies
	if frame - _cached_dream_enemies_frame <= 2 and not _cached_dream_enemies.is_empty():
		return _cached_dream_enemies
	_cached_dream_enemies_frame = frame
	_cached_dream_enemies = get_tree().get_nodes_in_group(&"dream_enemies")
	return _cached_dream_enemies


func damage_furniture_along_segment(origin: Vector2, endpoint: Vector2, width: float, amount: float, hit_direction: Vector2, source_actor: Node = null, hit_registry: Dictionary = {}) -> void:
	var handled := hit_registry
	for prop_variant in get_damageable_props_snapshot():
		var prop := prop_variant as Node2D
		if prop == null or prop == source_actor or prop.get("destroyed") == true:
			continue
		if handled.has(prop.get_instance_id()) or not is_room_projectile_path_clear(origin, prop.global_position):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(prop.global_position, origin, endpoint)
		if closest.distance_to(prop.global_position) > width * 0.5 + 14.0:
			continue
		handled[prop.get_instance_id()] = true
		if prop.has_method("take_damage"):
			prop.call("take_damage", amount, hit_direction, 1.0)


func damage_furniture_in_radius(center: Vector2, radius: float, amount: float, source_actor: Node = null) -> void:
	for prop_variant in get_damageable_props_snapshot():
		var prop := prop_variant as Node2D
		if prop == null or prop == source_actor or prop.get("destroyed") == true:
			continue
		if center.distance_to(prop.global_position) <= radius and prop.has_method("take_damage"):
			prop.call("take_damage", amount, center.direction_to(prop.global_position), 1.0)


func spawn_shell_ejection(at_position: Vector2, direction: Vector2, weapon_id: StringName = &"") -> void:
	if SHELL_EFFECT_SCENE == null or world_effects_root == null or not WEAPON_VISUALS.ejects_shell(String(weapon_id)):
		return
	var effect := SHELL_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	world_effects_root.add_child(effect)
	effect.global_position = at_position - direction.normalized() * 3.0
	if effect.has_method("setup"):
		effect.call("setup", WEAPON_VISUALS.get_shell(String(weapon_id)), direction, _content_rng, EMPLOYEE_CONFIG.shell_effect_lifetime, EMPLOYEE_CONFIG.shell_effect_fake_gravity)
	# A spent casing lying on the floor is a world object: lit by the night
	# ambient, brightened by the flashlight and muzzle pulses, occluded by
	# walls. Its gameplay motion is untouched.
	if bool(get_meta(&"test_legacy_shell_capture",false)):
		_spawn_depth_bridge(effect, [NodePath("ShellSprite")], Vector2(64.0, 64.0), BaseMaterial3D.BILLBOARD_ENABLED, 0.1, 0.0, Vector3.ZERO, true, true)
	else:
		_get_shell_capture_pool().acquire(effect,camera_3d)

func _get_shell_capture_pool() -> Node3D:
	var pool:=actor_depth_bridges_root.get_node_or_null(^"ShellCapturePool") as Node3D
	if pool==null:
		pool=SHELL_CAPTURE_POOL.new()
		pool.name="ShellCapturePool"
		actor_depth_bridges_root.add_child(pool)
	return pool
