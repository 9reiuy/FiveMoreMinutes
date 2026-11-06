extends Node3D

## MegastructureWhitebox
## Dedicated whitebox level for testing movement flow, choke points, and combat sightlines
## using Godot's Forward+ Clustered Lighting.
## Dimensions: 12m x 38m (384px x 1216px).
## Features:
## - Zone 1: Superhot Slow-motion Standoff. Player throws newspaper ("books") (RMB) to disarm
##   the standoff shooter, dodges the incoming slow-motion bullet, and picks up the dropped pistol ("basic").
## - Zone 2: 18m Tactical Corridor. 4.0m wide lane populated by melee enemies ("lucille" bats).
##   Features 3 cyan-lit alcoves with 45° beveled chamfers for smooth bullet dodging.
## - Zone 3: North Barricade Arena. Armored shooter behind cover suppresses the corridor with
##   red laser sightline telegraphs and 3-round bullet bursts. Flanked via 5m side avenues.
## - Visceral Combat Feedback:
##   * Player Vital HUD with dynamic HP bar, ammo indicator, and red damage vignette.
##   * 3D Billboard Health Bars for all enemies showing real-time health, hit-flashing, and death fade.
##   * Floating 3D Damage Numbers popping up on impacts.
##   * Screen shake, hit-stop, blood splatters, and directional hit particles.

const CELL_PIXELS := 32.0
const GAMEPLAY_CAMERA_FOV := 35.0
const SPAWN_2D := Vector2(192.0, 1152.0) # South Ingress (Z: 36m, X: 6m)

const ACTOR_DEPTH_BRIDGE_SCENE: PackedScene = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn")
const EMPLOYEE_ENEMY_SCENE: PackedScene = preload("res://scenes/entities/employee_enemy.tscn")
const CORRIDOR_SHOOTER_SCENE: PackedScene = preload("res://scenes/entities/corridor_end_shooter.tscn")
const WORLD_WEAPON_SCENE: PackedScene = preload("res://scenes/dream/world_weapon_pickup.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/entities/basic_projectile.tscn")
const COMBAT_FEEDBACK_SCENE: PackedScene = preload("res://scenes/entities/combat_feedback_effect.tscn")
const BLACK_BLOOD_EFFECT: Script = preload("res://scripts/entities/black_blood_effect.gd")
const MELEE_CRESCENT_HIT_3D: Script = preload("res://scripts/dream/melee_crescent_hit_3d.gd")
const DREAM_HUD_SCENE: PackedScene = preload("res://scenes/ui/dream_hud.tscn")
const CROSSHAIR_SCENE: PackedScene = preload("res://scenes/ui/crosshair.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")
const DEATH_CRT_SCENE: PackedScene = preload("res://scenes/ui/death_crt_effect.tscn")
const SHELL_EFFECT_SCENE: PackedScene = preload("res://scenes/entities/shell_effect.tscn")
const FIREARM_RULES: Script = preload("res://scripts/dream/dream_firearm_rules.gd")
const WEAPON_VISUALS: Script = preload("res://scripts/data/dream_gun_atlas.gd")
const DREAM_TIME_CONTROLLER_SCRIPT: Script = preload("res://scripts/dream/dream_time_controller.gd")
const INTERACTION_RESOLVER_SCRIPT: Script = preload("res://scripts/dream/dream_interaction_resolver.gd")
const CRISP_FONT: Script = preload("res://scripts/ui/crisp_interaction_font.gd")
const CONFIG: DemoConfig = preload("res://resources/demo_config.tres")
const SFX: Script = preload("res://scripts/audio/sfx_manager.gd")

@onready var gameplay_canvas: CanvasLayer = $GameplayCanvas
@onready var gameplay_world: Node2D = $GameplayCanvas/GameplayWorld
@onready var collision_root: Node2D = $GameplayCanvas/GameplayWorld/GeneratedCollisionRoot
@onready var world_effects_root: Node2D = $GameplayCanvas/GameplayWorld/WorldEffectsRoot
@onready var world_weapon_root: Node2D = $GameplayCanvas/GameplayWorld/WorldWeaponRoot
@onready var enemy_root: Node2D = $GameplayCanvas/GameplayWorld/EnemyRoot
@onready var player: CharacterBody2D = $GameplayCanvas/GameplayWorld/DreamPlayer
@onready var player_depth_bridge: Node3D = $PlayerDepthVisual3D
@onready var actor_depth_viewport: SubViewport = $ActorDepthViewport
@onready var actor_depth_render_root: Node2D = $ActorDepthViewport/ActorDepthRenderRoot
@onready var actor_depth_bridges_root: Node3D = $ActorDepthBridges
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/Camera3D
@onready var laser_beam_3d: CSGBox3D = $TutorialGeometry/Laser_Sightline_Beam
@onready var elevator_trigger: Area2D = $GameplayCanvas/GameplayWorld/ElevatorTrigger

# Official HUD, Crosshair & Damage Numbers Layer
@onready var hud_layer: CanvasLayer = $HUD
@onready var damage_flash_rect: ColorRect = $HUD/DamageFlash
@onready var native_damage_numbers_root: Node2D = $HUD/DamageNumbers
@onready var hud_title: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/Title
@onready var hud_label: Label = $HUD/InfoPanel/MarginContainer/VBoxContainer/GuideText

var hud: Control = null
var crosshair: Control = null
var native_damage_number_anchors: Array[Dictionary] = []
var _shell_rng := RandomNumberGenerator.new()

var time_controller: Node = null
var interaction_resolver: DreamInteractionResolver = null
var current_world_weapon_target: Node2D = null
var weapon_interaction_consumed := false
var standoff_enemy: CharacterBody2D = null
var corridor_shooter: CharacterBody2D = null
var level_cleared := false

var damage_flash_alpha := 0.0
var camera_shake_trauma := 0.0
var camera_base_ground_position := Vector3.ZERO
var runtime_config: DemoConfig = null

func _apply_3d_profile() -> void:
	runtime_config = CONFIG.duplicate(true) as DemoConfig
	runtime_config.basic_weapon_attack_interval = 1.0 / 4.2
	runtime_config.assault_rifle_attack_interval = 1.0 / 9.0
	runtime_config.shotgun_attack_interval = 1.0 / 2.4
	runtime_config.basic_projectile_speed = 1500.0
	runtime_config.assault_rifle_projectile_speed = 1500.0
	runtime_config.shotgun_projectile_speed = 1500.0
	runtime_config.player_movement_speed = 290.0
	runtime_config.set_meta("office_player_move_speed", 290.0)
	runtime_config.employee_movement_speed = 150.0
	runtime_config.basic_weapon_range *= (1024.0 / 350.0)
	runtime_config.assault_rifle_range *= (1536.0 / 500.0)
	runtime_config.shotgun_max_distance *= (640.0 / 220.0)

func _enter_tree() -> void:
	add_to_group(&"dream_world")

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _ready() -> void:
	# 1. Setup Formal Input Actions
	preload("res://scripts/app/game_input_actions.gd").configure()

	# 1.1 Apply 3D Firearm & Movement Speed Profile (290px/s player, 150px/s enemy, 1500px/s projectile)
	_apply_3d_profile()

	# 2. Setup Continuous 2D Collisions
	_build_2d_collisions()

	# 3. Setup Player State & Starting Weapon ("books" / Newspaper Roll)
	player.global_position = SPAWN_2D
	player.movement_enabled = true
	player.set_dash_enabled(true)
	player.set_attacking_enabled(true)
	player.configure_weapon("books", runtime_config, {})
	player.configure_profile_stats(4, false)
	player.movement_speed = 290.0 # Formal 3D movement speed
	player.configure_feedback_audio(runtime_config)
	# Initial reaction & dodge margin
	player.has_shield = true
	if player.shield_visual != null:
		player.shield_visual.set_shield_active(true)
	player.invulnerability_left = 1.5
	if player.has_signal("weapon_drop_requested") and not player.weapon_drop_requested.is_connected(_on_player_weapon_drop_requested):
		player.weapon_drop_requested.connect(_on_player_weapon_drop_requested)
	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	# 4. Setup Depth Bridge for Player
	_configure_player_depth_bridge()

	# 5. Initialize CameraRig
	if camera_3d != null:
		camera_3d.current = true
		camera_3d.fov = GAMEPLAY_CAMERA_FOV
	_update_camera_position(1.0)

	# 6. Initialize Superhot Time Controller
	_setup_time_controller()

	# 7. Initialize Weapon Interaction Resolver
	_setup_interaction_resolver()

	# 8. Setup Formal HUD & Crosshair
	_setup_formal_hud()

	# 9. Spawn Standoff Enemy & Pre-fired Slow-motion Bullet (Zone 1)
	_setup_zone1_standoff()

	# 10. Spawn Corridor Melee Patrol Enemies (Zone 2)
	_setup_zone2_corridor_enemies()

	# 11. Spawn End Barricade Armed Shooter (Zone 3)
	_setup_zone3_end_shooter()

	# 12. Setup Elevator Exit Trigger
	_setup_elevator_trigger()

func _configure_player_depth_bridge() -> void:
	if player_depth_bridge == null or player == null:
		return
	player_depth_bridge.configure(
		player,
		actor_depth_viewport,
		actor_depth_render_root,
		gameplay_canvas,
		[NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot"), NodePath("PlayerHPBar"), NodePath("ElectricShieldVisual"), NodePath("HealOverlay")]
	)
	player_depth_bridge.set_world_camera(camera_3d)
	player.set_meta(&"depth_visual_bridge", weakref(player_depth_bridge))

func _spawn_actor_depth_bridge(source: Node2D, requested_paths: Array, height: float = 0.70710678, depth: float = -0.70710678) -> Node3D:
	if source == null or actor_depth_bridges_root == null or ACTOR_DEPTH_BRIDGE_SCENE == null:
		return null
	var bridge := ACTOR_DEPTH_BRIDGE_SCENE.instantiate() as Node3D
	actor_depth_bridges_root.add_child(bridge)
	bridge.set_world_camera(camera_3d)
	var vp := bridge.get_node_or_null("ActorDepthViewport") as SubViewport
	var rr := bridge.get_node_or_null("ActorDepthViewport/ActorDepthRenderRoot") as Node2D
	var paths: Array[NodePath] = []
	for p in requested_paths:
		if p is NodePath:
			paths.append(p)
		elif p is String:
			paths.append(NodePath(p))
	bridge.configure(source, vp, rr, gameplay_canvas, paths, height, depth)
	source.set_meta(&"depth_visual_bridge", weakref(bridge))
	source.tree_exiting.connect(func():
		if is_instance_valid(bridge):
			bridge.queue_free()
	)
	return bridge

func _setup_time_controller() -> void:
	time_controller = DREAM_TIME_CONTROLLER_SCRIPT.new()
	time_controller.name = "DreamTimeController"
	time_controller.add_to_group(&"dream_time_controller")
	add_child(time_controller)
	time_controller.enter_dream_time_mode(player, runtime_config, self)
	time_controller.set_slow_time_enabled(true)
	# Force initial time scale to start at 0.05 immediately with zero high-speed jump!
	time_controller.base_player_activity_scale = 0.05
	time_controller.current_scale = 0.05
	time_controller.resolved_time_scale = 0.05
	Engine.time_scale = 0.05

func _setup_interaction_resolver() -> void:
	interaction_resolver = INTERACTION_RESOLVER_SCRIPT.new()
	interaction_resolver.name = "DreamInteractionResolver"
	add_child(interaction_resolver)
	interaction_resolver.configure(player, [&"world_weapon_pickups"])

func _setup_zone1_standoff() -> void:
	# Standoff enemy positioned 6m ahead of spawn (Z: 30m, Y: 960px)
	standoff_enemy = EMPLOYEE_ENEMY_SCENE.instantiate() as CharacterBody2D
	standoff_enemy.global_position = Vector2(192.0, 960.0)
	enemy_root.add_child(standoff_enemy)
	standoff_enemy.configure(
		player,
		runtime_config.base_enemy_health,
		0.0,
		Rect2(0, 0, 384, 1216),
		runtime_config.enemy_separation_strength,
		runtime_config.enemy_separation_radius,
		runtime_config
	)
	standoff_enemy.set_room_bounds(Rect2(0, 0, 384, 1216))
	standoff_enemy.set_meta(&"dream_room_id", 0)
	standoff_enemy.equip_weapon("basic")
	standoff_enemy.hostile = true
	standoff_enemy.set_room_runtime_active(true)
	standoff_enemy.set_meta(&"standoff_locked", true)
	standoff_enemy.last_facing_direction = Vector2.DOWN
	if standoff_enemy.character_visual != null:
		standoff_enemy._apply_live_facing(Vector2.DOWN)
	standoff_enemy.weapon_drop_requested.connect(_on_enemy_weapon_drop_requested.bind(standoff_enemy))
	_spawn_actor_depth_bridge(standoff_enemy, [NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot")])

	# Pre-fired bullet suspended in slow motion midway with ample reaction distance (Y: 1008, Player: 1152)
	# Trajectory has generous lateral margin (aimed slightly left, X: 184 -> 188) to give ample dodge margin!
	var bullet := PROJECTILE_SCENE.instantiate() as Node2D
	bullet.global_position = Vector2(184.0, 1008.0)
	world_effects_root.add_child(bullet)
	var bullet_dir := (Vector2(188.0, 1152.0) - Vector2(184.0, 1008.0)).normalized()
	FIREARM_RULES.setup_projectile(
		bullet,
		bullet_dir,
		15.0,    # damage
		500.0,   # distance
		220.0,   # speed
		&"enemy",
		standoff_enemy,
		&"basic"
	)
	add_projectile(bullet, standoff_enemy)

func _setup_zone2_corridor_enemies() -> void:
	# 3 Melee Enemies with bats/clubs stationed along the 18m corridor
	var corridor_ys := [780.0, 600.0, 420.0]
	for y_pos in corridor_ys:
		var enemy := EMPLOYEE_ENEMY_SCENE.instantiate() as CharacterBody2D
		enemy.global_position = Vector2(192.0, y_pos)
		enemy_root.add_child(enemy)
		enemy.configure(
			player,
			runtime_config.base_enemy_health,
			0.0,
			Rect2(0, 0, 384, 1216),
			runtime_config.enemy_separation_strength,
			runtime_config.enemy_separation_radius,
			runtime_config
		)
		enemy.set_room_bounds(Rect2(0, 0, 384, 1216))
		enemy.set_meta(&"dream_room_id", 0)
		enemy.equip_weapon("lucille")
		enemy.set_room_runtime_active(true)
		enemy.last_facing_direction = Vector2.DOWN
		if enemy.character_visual != null:
			enemy._apply_live_facing(Vector2.DOWN)
		enemy.weapon_drop_requested.connect(_on_enemy_weapon_drop_requested.bind(enemy))
		_spawn_actor_depth_bridge(enemy, [NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot")])

func _setup_zone3_end_shooter() -> void:
	# Armed shooter stationed behind Cover_Shooter_Barricade in Zone 3
	corridor_shooter = CORRIDOR_SHOOTER_SCENE.instantiate() as CharacterBody2D
	corridor_shooter.global_position = Vector2(192.0, 150.0)
	enemy_root.add_child(corridor_shooter)
	corridor_shooter.configure(
		player,
		runtime_config.base_enemy_health * 2.0,
		0.0,
		Rect2(0, 0, 384, 1216),
		runtime_config.enemy_separation_strength,
		runtime_config.enemy_separation_radius,
		runtime_config
	)
	corridor_shooter.set_room_bounds(Rect2(0, 0, 384, 1216))
	corridor_shooter.set_meta(&"dream_room_id", 0)
	corridor_shooter.set_room_runtime_active(true)
	corridor_shooter.equip_weapon("basic")
	corridor_shooter.set_laser_beam_node(laser_beam_3d)
	corridor_shooter.weapon_drop_requested.connect(_on_enemy_weapon_drop_requested.bind(corridor_shooter))
	_spawn_actor_depth_bridge(corridor_shooter, [NodePath("Shadow"), NodePath("CharacterVisual"), NodePath("WeaponRoot")])

func _setup_elevator_trigger() -> void:
	if elevator_trigger != null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		shape.shape = circle
		elevator_trigger.add_child(shape)
		elevator_trigger.body_entered.connect(_on_elevator_entered)

func _setup_formal_hud() -> void:
	hud = DREAM_HUD_SCENE.instantiate()
	hud_layer.add_child(hud)
	player.health_changed.connect(hud.set_health)
	player.dash_state_changed.connect(hud.set_dash_state)
	player.skill_state_changed.connect(hud.set_skill_state)
	player.active_weapon_changed.connect(_on_player_active_weapon_changed)
	if player.has_signal("weapon_inventory_changed"):
		player.weapon_inventory_changed.connect(_on_player_weapon_inventory_changed)

	hud.set_health(player.current_health, player.maximum_health)
	hud.set_dash_state(
		float(player.get("dash_cooldown_left")),
		float(player.get("dash_cooldown")),
		bool(player.get("dashing")),
		int(player.get("dash_charges")),
		int(player.get("max_dash_charges"))
	)
	hud.set_weapon_state(
		str(player.get("ranged_weapon_id")),
		str(player.get("melee_weapon_id")),
		str(player.get("selected_weapon_id")),
		StringName(str(player.get("active_weapon_category")))
	)

	crosshair = CROSSHAIR_SCENE.instantiate()
	hud_layer.add_child(crosshair)
	crosshair.configure(player)

	if hud_title != null:
		hud_title.text = "【SUPERHOT 战术渗透 · 慢动作与投掷缴械】"
	if hud_label != null:
		hud_label.add_theme_font_override(&"font", CRISP_FONT.get_font())
		hud_label.add_theme_font_size_override(&"font_size", 11)
		hud_label.text = "WASD: 移动 | Space: 冲刺翻滚 | LMB: 射击/近战 | RMB: 投掷武器 | F: 踢击
① [RMB] 投掷报纸击倒面前枪手，缴落其手枪，规避慢动作子弹！
② 走近掉落手枪自动拾取，迎击长廊中巡逻警觉的近战敌人！
③ 敌人具备完整视线索敌与冲锋攻击，利用 3 处避弹壁龛掩护
④ 左右 5 米宽主廊侧翼包抄尽头压制枪手，撤离电梯过关
[R] 重置关卡 | [ESC] 退出"

func _on_player_health_changed(current: float, maximum: float) -> void:
	if hud != null and hud.has_method("set_health"):
		hud.set_health(current, maximum)
	damage_flash_alpha = 0.45
	request_camera_impulse(&"heavy", -player.get_aim_direction())
	SFX.play_event(&"player_hurt")

func _on_player_active_weapon_changed(weapon_id: String, category: StringName) -> void:
	if hud != null and hud.has_method("set_weapon_state"):
		hud.set_weapon_state(
			str(player.get("ranged_weapon_id")),
			str(player.get("melee_weapon_id")),
			weapon_id,
			category
		)

func _on_player_weapon_inventory_changed() -> void:
	if hud != null and hud.has_method("set_weapon_state"):
		hud.set_weapon_state(
			str(player.get("ranged_weapon_id")),
			str(player.get("melee_weapon_id")),
			str(player.get("selected_weapon_id")),
			StringName(str(player.get("active_weapon_category")))
		)

func _on_player_died() -> void:
	if hud_title != null:
		hud_title.text = "【宿主生命体征归零 / EMERGENCY REBOOT】"
		hud_title.modulate = Color(1.0, 0.25, 0.25, 1.0)
	if hud_label != null:
		hud_label.text = "★ 任务失败！宿主生命体征归零。\n按 [R] 重新挑战本关 | [ESC] 退出"
	damage_flash_alpha = 0.65
	if time_controller != null and time_controller.has_method("request_hit_stop"):
		time_controller.request_hit_stop(0.02, 1.5, 0.05)
	var crt := DEATH_CRT_SCENE.instantiate() as DeathCrtEffect
	add_child(crt)
	crt.play(CONFIG.death_crt_effect_seconds)

func _build_2d_collisions() -> void:
	for child in collision_root.get_children():
		child.queue_free()

	# 1. Continuous West Wall Polygon (Zone 1 funnel -> Corridor -> Alcoves -> Zone 3)
	var west_poly = PackedVector2Array([
		Vector2(-32, -32),
		Vector2(0, 0),
		Vector2(0, 256),
		Vector2(128, 320),
		Vector2(128, 384),
		Vector2(80, 416),
		Vector2(80, 448),
		Vector2(128, 480),
		Vector2(128, 704),
		Vector2(80, 736),
		Vector2(80, 768),
		Vector2(128, 800),
		Vector2(128, 896),
		Vector2(0, 960),
		Vector2(0, 1216),
		Vector2(-32, 1248)
	])
	_add_polygon_collider(west_poly, "West_Wall_Continuous")

	# 2. Continuous East Wall Polygon (Zone 1 funnel -> Corridor -> Alcove -> Zone 3)
	var east_poly = PackedVector2Array([
		Vector2(416, -32),
		Vector2(384, 0),
		Vector2(384, 256),
		Vector2(256, 320),
		Vector2(256, 544),
		Vector2(304, 576),
		Vector2(304, 608),
		Vector2(256, 640),
		Vector2(256, 896),
		Vector2(384, 960),
		Vector2(384, 1216),
		Vector2(416, 1248)
	])
	_add_polygon_collider(east_poly, "East_Wall_Continuous")

	# 3. Outer Boundaries
	_add_box_collider(Rect2(0, -16, 384, 16), "Wall_North")
	_add_box_collider(Rect2(0, 1216, 384, 16), "Wall_South")

	# 4. Zone 1 Side Counters
	_add_box_collider(Rect2(0, 1008, 24, 64), "Side_Counter_West")
	_add_box_collider(Rect2(360, 1008, 24, 64), "Side_Counter_East")

	# 5. Zone 3 Shooter Barricade (X: 168~216, Y: 184~200) - 5m flanking clearance!
	_add_box_collider(Rect2(168, 184, 48, 16), "Cover_Shooter_Barricade")
	_add_box_collider(Rect2(32, 128, 48, 32), "Cover_Cargo_West")
	_add_box_collider(Rect2(304, 128, 48, 32), "Cover_Cargo_East")

func _add_polygon_collider(poly: PackedVector2Array, c_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = c_name
	body.collision_layer = 4 # WORLD_WALL_LAYER
	body.collision_mask = 0
	var col := CollisionPolygon2D.new()
	col.polygon = poly
	body.add_child(col)
	collision_root.add_child(body)

func _add_box_collider(rect: Rect2, c_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = c_name
	body.collision_layer = 4 # WORLD_WALL_LAYER
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	collision_root.add_child(body)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(standoff_enemy) and bool(standoff_enemy.get_meta(&"standoff_locked", false)):
		var st: Variant = standoff_enemy.get("state")
		var is_down: bool = bool(standoff_enemy.get("dead")) or standoff_enemy.current_health < 9.9 or (st is int and int(st) >= 9)
		if is_down:
			standoff_enemy.set_meta(&"standoff_locked", false)
		else:
			standoff_enemy.global_position = Vector2(192.0, 960.0)
			standoff_enemy.velocity = Vector2.ZERO
			standoff_enemy.last_facing_direction = Vector2.DOWN

func _process(delta: float) -> void:
	_update_camera_position(delta)
	_update_world_weapon_interaction()
	_update_feedback_fx(delta)
	_update_native_damage_number_projections()

	if Input.is_key_pressed(KEY_R):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	if Input.is_key_pressed(KEY_ESCAPE):
		Engine.time_scale = 1.0
		get_tree().quit()

func _update_camera_position(delta: float) -> void:
	if player == null or camera_rig == null:
		return
	var gp: Vector2 = player.global_position
	var ground_pos := Vector3(gp.x / CELL_PIXELS, 0.0, gp.y / CELL_PIXELS)
	if delta >= 1.0:
		camera_base_ground_position = ground_pos
	else:
		camera_base_ground_position = camera_base_ground_position.lerp(ground_pos, 12.0 * delta)

	# Apply Camera Shake Trauma
	var shake_offset := Vector3.ZERO
	if camera_shake_trauma > 0.0:
		var trauma_p := camera_shake_trauma * camera_shake_trauma
		shake_offset = Vector3(
			randf_range(-0.45, 0.45) * trauma_p,
			0.0,
			randf_range(-0.45, 0.45) * trauma_p
		)
		camera_shake_trauma = maxf(0.0, camera_shake_trauma - 4.5 * delta)

	camera_rig.global_position = camera_base_ground_position + shake_offset

	if camera_3d != null and gameplay_canvas != null:
		var screen_position := camera_3d.unproject_position(camera_base_ground_position)
		gameplay_canvas.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, screen_position - gp)

func _update_feedback_fx(delta: float) -> void:
	if damage_flash_rect != null and damage_flash_alpha > 0.0:
		damage_flash_alpha = maxf(0.0, damage_flash_alpha - 3.2 * delta)
		damage_flash_rect.color = Color(0.9, 0.1, 0.1, damage_flash_alpha)

func _update_world_weapon_interaction() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not Input.is_action_pressed("pickup_weapon"):
		weapon_interaction_consumed = false

	var nearest: Node2D = null
	if interaction_resolver != null:
		nearest = interaction_resolver.update_target()
	current_world_weapon_target = nearest
	if nearest == null:
		return

	# Automatic pickup if player is empty-handed!
	var empty_handed := (
		bool(player.call("is_empty_handed"))
		if player.has_method("is_empty_handed")
		else String(player.get("selected_weapon_id")).is_empty()
	)
	if empty_handed:
		_swap_world_weapon(nearest)
		return

	# Explicit pickup via E key
	if Input.is_action_just_pressed("pickup_weapon") and not weapon_interaction_consumed:
		weapon_interaction_consumed = true
		_swap_world_weapon(nearest)

func _swap_world_weapon(pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup) or not player.has_method("equip_weapon"):
		return
	var new_weapon_id := String(pickup.get("weapon_id"))
	if new_weapon_id.is_empty():
		return
	var skin_index := int(pickup.get("skin_index"))
	var old_weapon_id := String(player.get("selected_weapon_id"))
	player.call("equip_weapon", new_weapon_id, runtime_config, {}, skin_index)
	SFX.play_weapon_pickup()
	_update_player_vital_ui()

	if old_weapon_id.is_empty() or old_weapon_id == new_weapon_id:
		pickup.queue_free()
		current_world_weapon_target = null
		return

	# Swap old weapon back into world
	pickup.set("weapon_id", old_weapon_id)
	pickup.set("skin_index", 0)
	var drop_dir: Vector2 = -player.last_move_direction.normalized() if player.last_move_direction.length_squared() > 0.001 else Vector2.LEFT
	if pickup.has_method("place_after_swap"):
		pickup.call_deferred("place_after_swap", player.global_position + drop_dir * 16.0, drop_dir * 12.0)

func _on_player_weapon_drop_requested(drop_data: Dictionary) -> void:
	if world_weapon_root == null or drop_data.is_empty():
		return
	var weapon_id := String(drop_data.get("weapon_id", ""))
	var direction: Vector2 = drop_data.get("direction", Vector2.RIGHT)
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	var pickup := WORLD_WEAPON_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	pickup.set("weapon_id", weapon_id)
	pickup.set("skin_index", WEAPON_VISUALS.normalize_skin_index(weapon_id, int(drop_data.get("skin_index", 0))))
	pickup.set("interaction_radius", CONFIG.world_weapon_interaction_radius)
	pickup.set("mass", WEAPON_VISUALS.get_world_mass(weapon_id))
	pickup.rotation = float(drop_data.get("visual_rotation", direction.angle()))
	world_weapon_root.add_child(pickup)
	pickup.global_position = player.global_position + direction * 16.0

	var forced_drop := bool(drop_data.get("forced_drop", false))
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
				direction * float(drop_data.get("speed", 950.0)),
				float(drop_data.get("damage", 25.0)),
				float(drop_data.get("force", CONFIG.world_weapon_throw_force)),
				player.get_instance_id(),
				CONFIG.world_weapon_throw_pickup_lockout
			)
		SFX.play_weapon_throw()

	_spawn_actor_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])
	_update_player_vital_ui()

func _on_enemy_weapon_drop_requested(weapon_id: String, at_position: Vector2, impulse: Vector2, skin_index: int, _enemy: Node) -> void:
	if Engine.is_in_physics_frame():
		_commit_enemy_weapon_drop.call_deferred(weapon_id, at_position, impulse, skin_index)
	else:
		_commit_enemy_weapon_drop(weapon_id, at_position, impulse, skin_index)

func _commit_enemy_weapon_drop(weapon_id: String, at_position: Vector2, impulse: Vector2, skin_index: int) -> void:
	if world_weapon_root == null or weapon_id.is_empty():
		return
	var pickup := WORLD_WEAPON_SCENE.instantiate() as Node2D
	if pickup == null:
		return
	world_weapon_root.add_child(pickup)
	pickup.set("weapon_id", weapon_id)
	pickup.set("skin_index", WEAPON_VISUALS.normalize_skin_index(weapon_id, skin_index))
	pickup.set("interaction_radius", CONFIG.world_weapon_interaction_radius)
	pickup.set("mass", WEAPON_VISUALS.get_world_mass(weapon_id))
	pickup.global_position = at_position
	if pickup.has_method("place_after_swap"):
		pickup.call_deferred("place_after_swap", at_position, impulse)
	_spawn_actor_depth_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])

func _on_elevator_entered(body: Node2D) -> void:
	if body != player or level_cleared:
		return
	level_cleared = true
	if hud_title != null:
		hud_title.text = "【任务完成 / LEVEL CLEARED!】"
		hud_title.modulate = Color(0.2, 1.0, 0.4, 1.0)
	if hud_label != null:
		hud_label.text = "★ 成功完成 Superhot 式投掷缴械、走廊突进与侧翼包抄！
★ 所有敌人生命值、受击闪白、死亡血条与击杀动效验证通过！
[R] 重新体验本关 | [ESC] 退出测试"

func _update_player_vital_ui() -> void:
	if hud == null or player == null:
		return
	if hud.has_method("set_health"):
		hud.set_health(player.current_health, player.maximum_health)
	if hud.has_method("set_weapon_state"):
		hud.set_weapon_state(
			str(player.get("ranged_weapon_id")),
			str(player.get("melee_weapon_id")),
			str(player.get("selected_weapon_id")),
			StringName(str(player.get("active_weapon_category")))
		)

# =========================================================================
# WORLD INTERFACE CONTRACT & COMBAT FEEDBACK
# =========================================================================

func _spawn_native_damage_number(
	world_anchor: Vector2,
	enemy_id: int,
	is_critical: bool,
	amount: int = 0,
	screen_offset: Vector2 = Vector2.ZERO
) -> Node2D:
	if native_damage_numbers_root == null or not is_instance_valid(native_damage_numbers_root) or DAMAGE_NUMBER_SCENE == null:
		return null
	var holder := Node2D.new()
	holder.name = "DamageNumberAnchor"
	holder.z_index = 10
	holder.set_meta(&"damage_owner_id", enemy_id)
	native_damage_numbers_root.add_child(holder)
	var number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D
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
	number.position = Vector2.ZERO
	number.finished.connect(_on_native_damage_number_finished.bind(holder), CONNECT_ONE_SHOT)
	return number

func _on_native_damage_number_finished(holder: Node2D) -> void:
	if holder == null or not is_instance_valid(holder):
		return
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
			var screen_pos := camera_3d.unproject_position(world_position)
			if player != null and player.has_method("get_presentation_hud_position"):
				holder.position = player.get_presentation_hud_position(screen_pos) + screen_offset
			else:
				holder.position = screen_pos + screen_offset
			holder.visible = true
		else:
			holder.visible = false

func add_projectile(projectile: Node2D, _source_actor: Node2D = null) -> void:
	if projectile == null or world_effects_root == null:
		return
	if projectile.has_method("enable_office_ballistics"):
		projectile.call("enable_office_ballistics")
	if not projectile.is_in_group(&"dream_projectiles"):
		projectile.add_to_group(&"dream_projectiles")
	if projectile.get_parent() == null:
		world_effects_root.add_child(projectile)
	_spawn_actor_depth_bridge(projectile, [NodePath("BulletSprite")], 0.65)

func spawn_weapon_muzzle(_point: Vector2, _direction: Vector2, _kind: StringName, _source: Node2D = null) -> void:
	request_camera_impulse(&"small", Vector2.ZERO)

func spawn_shell_ejection(at_position: Vector2, direction: Vector2, weapon_id: StringName = &"") -> void:
	if SHELL_EFFECT_SCENE == null or world_effects_root == null or not WEAPON_VISUALS.ejects_shell(String(weapon_id)):
		return
	var effect := SHELL_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	world_effects_root.add_child(effect)
	effect.global_position = at_position - direction.normalized() * 3.0
	if effect.has_method("setup"):
		effect.call("setup", WEAPON_VISUALS.get_shell(String(weapon_id)), direction, _shell_rng, CONFIG.shell_effect_lifetime, CONFIG.shell_effect_fake_gravity)
	_spawn_actor_depth_bridge(effect, [NodePath("ShellSprite")], 0.1, 0.0)

func spawn_combat_feedback(at_position: Vector2, direction: Vector2 = Vector2.ZERO, is_kill: bool = false, _is_blood: bool = true, target: Node = null) -> void:
	if world_effects_root == null or COMBAT_FEEDBACK_SCENE == null:
		return
	var effect := COMBAT_FEEDBACK_SCENE.instantiate() as Node2D
	if effect != null:
		world_effects_root.add_child(effect)
		effect.global_position = at_position
		if effect.has_method("setup"):
			effect.call("setup", direction, is_kill, 0.22 if is_kill else 0.16)
		_spawn_actor_depth_bridge(effect, [NodePath(".")], 0.5)

	var enemy_id := target.get_instance_id() if is_instance_valid(target) else 0
	var offset: Vector2 = target.call("get_damage_number_offset") if is_instance_valid(target) and target.has_method("get_damage_number_offset") else Vector2(0.0, -28.0)
	var damage_val := 25 if is_kill else 15
	_spawn_native_damage_number(at_position, enemy_id, is_kill, damage_val, offset)
	request_combat_impact(320.0 if is_kill else 180.0, direction, &"impact")

func spawn_melee_hit_feedback(target: Node, direction: Vector2) -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera_3d):
		return
	var target_2d := target as Node2D
	var hit_pos := target_2d.global_position if target_2d != null else Vector2.ZERO
	var anchor := Vector3(hit_pos.x / CELL_PIXELS, 0.65, hit_pos.y / CELL_PIXELS)
	var normal := Vector3(camera_3d.global_basis.z.x, 0.0, camera_3d.global_basis.z.z).normalized()
	var plane := {"origin": anchor, "normal": normal}
	var a := camera_3d.unproject_position(anchor)
	var b := camera_3d.unproject_position(anchor + Vector3(direction.x, 0.0, direction.y))
	var screen_dir := (b - a).normalized()

	var effect: Node = MELEE_CRESCENT_HIT_3D.new()
	add_child(effect)
	if effect.has_method("setup"):
		effect.call("setup", camera_3d, anchor, screen_dir, plane)

	var enemy_id := target.get_instance_id() if is_instance_valid(target) else 0
	var offset: Vector2 = target.call("get_damage_number_offset") if target.has_method("get_damage_number_offset") else Vector2(0.0, -28.0)
	_spawn_native_damage_number(hit_pos, enemy_id, false, 25, offset)
	request_combat_impact(400.0, direction, &"melee")

func uses_pixel_combat_vfx() -> bool:
	return true

func spawn_black_blood(blood_origin: Vector2, direction: Vector2, is_death: bool = false, _room_id: int = -1, _intensity: float = 1.0) -> bool:
	if world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return false
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood != null:
		blood.global_position = blood_origin
		world_effects_root.add_child(blood)
		_spawn_actor_depth_bridge(blood, [NodePath(".")], 0.02, 0.0)
		if is_death:
			for i in range(2):
				var extra := BLACK_BLOOD_EFFECT.new() as Node2D
				extra.global_position = blood_origin + direction.rotated(randf_range(-0.6, 0.6)) * randf_range(6.0, 20.0)
				world_effects_root.add_child(extra)
				_spawn_actor_depth_bridge(extra, [NodePath(".")], 0.02, 0.0)
	return true

func spawn_blood_trail(at_position: Vector2, _room_or_velocity: Variant = null) -> void:
	if world_effects_root == null or BLACK_BLOOD_EFFECT == null:
		return
	var blood := BLACK_BLOOD_EFFECT.new() as Node2D
	if blood != null:
		blood.global_position = at_position
		world_effects_root.add_child(blood)
		_spawn_actor_depth_bridge(blood, [NodePath(".")], 0.02, 0.0)

func request_combat_impact(force: float, direction: Vector2, _source: StringName = &"") -> void:
	var strength: StringName = &"small"
	if force >= 300.0:
		strength = &"heavy"
	elif force >= 150.0:
		strength = &"medium"
	request_hit_stop(strength)
	request_camera_impulse(strength, direction)

func request_hit_stop(strength: StringName = &"small") -> void:
	if time_controller != null and time_controller.has_method("request_hit_stop"):
		var duration := 0.06
		if strength == &"medium":
			duration = 0.10
		elif strength == &"heavy":
			duration = 0.18
		time_controller.request_hit_stop(0.04, duration, 0.04)

func request_camera_impulse(level: Variant = null, _direction: Vector2 = Vector2.ZERO) -> void:
	var trauma_add := 0.35
	if level == &"medium":
		trauma_add = 0.55
	elif level == &"heavy":
		trauma_add = 0.85
	camera_shake_trauma = clampf(camera_shake_trauma + trauma_add, 0.0, 1.0)

func get_current_room_id() -> int:
	return 0

func are_rooms_openly_connected(_a: int, _b: int) -> bool:
	return true

func sync_employee_ground_region(_employee: Node) -> bool:
	return true

func get_vision_occluder_collision_mask() -> int:
	return 4 # WORLD_WALL_LAYER

func is_furniture_shot_path_clear(_from_pos: Vector2, _to_pos: Vector2, _source: Node2D) -> bool:
	return true

func get_dream_enemies_snapshot() -> Array:
	if enemy_root == null:
		return []
	return enemy_root.get_children()

func get_damageable_props_snapshot() -> Array:
	return []

func _get_dream_time_controller() -> Node:
	return time_controller

# =========================================================================
# COMBAT RESOLUTION & HIT ARBITRATION (FORMAL CONTRACT)
# =========================================================================

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
	var source_text := String(damage_source)
	if source_text.begins_with("player_projectile"):
		SFX.play_bullet_enemy_hit()
	elif damage_source in [&"lucille", &"books"]:
		SFX.play_melee_enemy_hit()
	if damage_result.is_empty():
		damage_result = {"damage": resolved_damage}
	damage_result["source"] = damage_source
	return damage_result

func resolve_enemy_projectile_hit(enemy: Node, raw_damage: float, hit_origin: Vector2, shooter_instance_id: int = 0, weapon_id: StringName = &"basic") -> Dictionary:
	if enemy == null or not is_instance_valid(enemy) or enemy.get_instance_id() == shooter_instance_id or enemy.get("dead") == true:
		return {}
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", raw_damage, hit_origin, 1.0, StringName("enemy_projectile_%s" % String(weapon_id)))
	return {"damage": raw_damage, "weapon_id": weapon_id}

func resolve_phase_dash_attack(start: Vector2, end: Vector2, radius: float, damage: float, source: StringName, handled: Variant = null, _feedback: bool = true) -> Dictionary:
	return preload("res://scripts/dream/phase_dash_combat.gd").resolve(self, player, start, end, radius, damage, source, handled)

