class_name DemoConfig
extends Resource

## All vertical-slice tuning lives here so later balancing does not touch gameplay code.
@export_group("Player Vision")
## Alpha of the black world overlay outside the combined circle/cone visibility.
@export_range(0.0, 0.8, 0.01) var vision_darkness_alpha: float = 0.52
## Width of the black-alpha falloff at the circle and visibility-polygon edges.
@export_range(0.0, 128.0, 1.0) var vision_edge_softness_px: float = 32.0

@export_group("Dream Clock")
@export var dream_start_minutes: float = 240.0
@export var alarm_start_minutes: float = 360.0
@export var real_seconds_per_game_minute: float = 1.0

@export_group("Enemy Spawning")
@export var enemy_initial_spawn_interval: float = 2.0
@export var enemy_minimum_spawn_interval: float = 0.65
@export_enum("Linear") var enemy_spawn_interval_reduction_mode: String = "Linear"
## 每个生成周期独立尝试批次数量；合法点不足时生成器允许少生成。
@export var maximum_enemies: int = 110
@export var enemy_spawn_count_per_interval: int = 2
## All newly spawned Enemy gameplay actors use this fixed health baseline.
## Difficulty no longer inflates HP; combat tuning remains in damage/AI values.
@export var base_enemy_health: float = 10.0
@export var enemy_health_growth_per_second: float = 0.0
@export var enemy_damage_growth_per_second: float = 0.012
@export var enemy_minimum_spawn_distance: float = 150.0
@export var enemy_spawn_minimum_spacing: float = 30.0
@export var enemy_spawn_position_max_retries: int = 12
## Employee 是正式 Dream 中唯一普通敌人。剧情模式按全地牢人口逐只补充，
## 且只选择非当前、非 Start、当前相机不可见的已生成房间。
@export_range(1, 40, 1) var employee_global_population_target: int = 30
@export_range(1, 3, 1) var employee_population_refill_batch: int = 3
@export_range(0.25, 15.0, 0.25) var employee_population_refill_interval: float = 3.0
@export_range(1, 50, 1) var employee_xp_value: int = 5
@export_range(20.0, 200.0, 1.0) var employee_movement_speed: float = 100.0
@export_range(1.0, 3.0, 0.05) var employee_run_speed_multiplier: float = 1.6

@export_group("Enemy Perception")
## Enemy视觉最大距离。它只负责廉价的候选筛选，不能代替FOV或LOS。
@export_range(64.0, 800.0, 1.0) var employee_vision_range: float = 360.0
## Enemy视觉扇形角度；真正发现Player还必须通过正式Gameplay墙/门LOS。
@export_range(30.0, 360.0, 1.0) var employee_vision_fov_degrees: float = 120.0
## Enemy枪声/破门声听觉半径。
@export_range(100.0, 1500.0, 10.0) var employee_sound_hearing_range: float = 700.0
## 感知检查频率。每个Enemy会以实例ID派生的相位错开检查时刻。
@export_range(0.05, 0.5, 0.01) var employee_vision_update_interval: float = 0.10

@export_range(0.1, 8.0, 0.05) var employee_wander_pause_min: float = 0.35
@export_range(0.1, 8.0, 0.05) var employee_wander_pause_max: float = 0.85
@export_range(0.1, 5.0, 0.05) var employee_weapon_search_interval: float = 0.30
@export_range(12.0, 80.0, 1.0) var employee_weapon_pickup_radius: float = 28.0
@export_range(0.05, 1.0, 0.01) var employee_weapon_pickup_pause: float = 0.12
@export_range(40.0, 300.0, 1.0) var employee_flee_distance: float = 120.0
## AI目标一旦选定会短暂保持；只有持续低位移才触发重规划，避免家具边缘上下震荡。
@export_range(0.1, 2.0, 0.05) var employee_decision_cooldown: float = 0.30
@export_range(0.1, 2.0, 0.05) var employee_steering_commit_time: float = 0.40
@export_range(0.2, 3.0, 0.05) var employee_stuck_detection_seconds: float = 0.55
@export_range(0.1, 16.0, 0.1) var employee_stuck_distance_threshold: float = 2.5
## Neutral employees occasionally leave their current room after several wander points.
@export_range(0.0, 1.0, 0.01) var employee_room_travel_chance: float = 0.18
@export_range(1.0, 20.0, 0.25) var employee_room_travel_cooldown_min: float = 4.0
@export_range(1.0, 30.0, 0.25) var employee_room_travel_cooldown_max: float = 8.0
## A local gunshot keeps neutral employees fleeing long enough to cross an open door.
@export_range(0.5, 12.0, 0.25) var employee_gunshot_flee_duration: float = 5.0
@export_range(0.25, 4.0, 0.25) var employee_gunshot_recovery_duration: float = 1.25
## Neutral惊恐只在进入一次panic决策时Roll一次；持枪者改为调查枪声。
@export_range(0.0, 1.0, 0.01) var employee_panic_counterattack_chance: float = 0.20
@export_range(0.25, 8.0, 0.25) var employee_gunshot_investigate_duration: float = 2.5
@export_range(1.0, 40.0, 1.0) var employee_unarmed_punch_damage: float = 6.0
@export_range(1.0, 40.0, 1.0) var employee_unarmed_kick_damage: float = 10.0
@export_range(12.0, 64.0, 1.0) var employee_unarmed_attack_range: float = 30.0
@export_range(0.15, 1.5, 0.05) var employee_unarmed_attack_interval: float = 0.45
@export_range(0.2, 4.0, 0.05) var employee_attack_strafe_min_seconds: float = 0.55
@export_range(0.2, 4.0, 0.05) var employee_attack_strafe_max_seconds: float = 1.20
## 首次进入敌对状态后仍保留短暂可读反应，不允许同一帧精准开火。
@export_range(0.05, 1.0, 0.01) var employee_reaction_time_min: float = 0.20
@export_range(0.05, 1.0, 0.01) var employee_reaction_time_max: float = 0.40
## 每次正式Attack Action独立扰动间隔，避免同武器敌人整齐齐射。
@export_range(0.0, 0.4, 0.01) var employee_attack_cadence_jitter_ratio: float = 0.12
@export_range(8.0, 96.0, 1.0) var employee_door_approach_distance: float = 34.0
@export_range(4.0, 64.0, 1.0) var employee_door_transit_distance: float = 14.0
@export_range(16.0, 128.0, 1.0) var employee_door_exit_distance: float = 44.0
@export_range(0.0, 1.0, 0.01) var employee_kick_knockdown_chance: float = 0.35
@export_range(0.1, 4.0, 0.05) var employee_knockdown_duration: float = 1.2
@export_range(0.1, 1.5, 0.05) var employee_get_up_duration: float = 0.4
@export_range(20.0, 600.0, 10.0) var employee_knockdown_knockback_force: float = 210.0
@export_range(20.0, 600.0, 10.0) var employee_knockdown_weapon_drop_force: float = 160.0
@export_range(1.01, 3.0, 0.05) var employee_knockdown_weapon_force_multiplier: float = 1.75
@export_range(20.0, 240.0, 5.0) var employee_knockdown_launch_velocity: float = 90.0
@export_range(50.0, 800.0, 10.0) var employee_knockdown_fake_gravity: float = 300.0
## Employee在真正执行一次攻击时才采样误差；这是静止、首发时的总散布角。
@export_range(0.0, 180.0, 1.0) var employee_weapon_spread_degrees: float = 12.0
## Enemy自身或Player高速移动时增加的最大总散布角。
@export_range(0.0, 90.0, 1.0) var employee_movement_spread_degrees: float = 10.0
## 同一连续射击段中，每次Attack Action追加的总散布角。
@export_range(0.0, 30.0, 0.5) var employee_burst_spread_step_degrees: float = 3.0
@export_range(0, 8, 1) var employee_burst_spread_max_steps: int = 3
@export_range(0.1, 2.0, 0.05) var employee_burst_reset_seconds: float = 0.55
## 同一物理帧内多颗霰弹命中同一Employee时只生成一份视觉反馈，伤害仍逐颗结算。
@export_range(0.0, 0.25, 0.005) var projectile_impact_feedback_min_interval: float = 0.04
## Bosses share the same fixed Enemy HP authority for this ruleset.
@export_range(0.5, 20.0, 0.5) var employee_boss_health_multiplier: float = 1.0
## 房间模式中先显示地面预警，再真正实例化敌人。
@export_range(0.1, 3.0, 0.05) var room_spawn_warning_duration: float = 0.9
@export_range(32.0, 256.0, 4.0) var employee_sky_drop_height: float = 96.0
@export_range(50.0, 1200.0, 10.0) var employee_sky_drop_gravity: float = 520.0
## 剧情房间不读取Day数值曲线：所有敌人只在各自基础HP上乘该值，伤害保持基础值。
## 通用剧情敌人/Boss 的生命倍率保持独立；普通 Employee 使用下方专用倍率。
@export_range(1.0, 10.0, 0.1) var story_enemy_health_multiplier: float = 1.0
## 普通 Employee 与其它正式 Enemy 共用 10 HP，不再叠加剧情倍率。
@export_range(1.0, 10.0, 0.1) var story_employee_health_multiplier: float = 1.0
## Room战斗数据：上限仍作为全局Population分配的安全上限；正式房间不再
## 使用按尺寸硬编码的首批敌人数。
@export_range(1, 40, 1) var large_room_enemy_cap: int = 20
@export_range(1, 30, 1) var medium_room_enemy_cap: int = 10
@export_range(1, 20, 1) var small_room_enemy_cap: int = 10
## Phase 7：正式房间人口只由全局Population目标驱动；以下参数把全局人口
## 分配到房间可承载的密度，避免小房间被塞满，同时保留房间节奏差异。
@export_group("Room Density & Pacing")
@export_range(0.1, 2.0, 0.05) var employee_room_density_per_10000_px: float = 1.15
@export_range(0.0, 1.0, 0.05) var employee_room_furniture_capacity_penalty: float = 0.15
@export_range(0.0, 2.0, 0.1) var employee_room_door_capacity_bonus: float = 0.5
@export_range(1, 8, 1) var employee_room_minimum_capacity: int = 2
@export_range(0.1, 5.0, 0.25) var employee_room_breathing_seconds: float = 2.25
@export_range(0.25, 1.5, 0.05) var employee_small_room_density_multiplier: float = 0.75
@export_range(0.25, 1.5, 0.05) var employee_medium_room_density_multiplier: float = 0.9
@export_range(0.25, 1.5, 0.05) var employee_large_room_density_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var employee_ground_weapon_room_chance: float = 0.35
@export var employee_room_pacing_weights: Dictionary = {
	"combat": 0.42,
	"transition": 0.18,
	"ambush": 0.10,
	"furniture_heavy": 0.12,
	"gun_heavy": 0.10,
	"melee_heavy": 0.08,
}
## Deprecated compatibility fields. They are no longer read by Dream RoomManager.
@export_range(1, 20, 1) var large_room_initial_enemy_count: int = 24
@export_range(1, 10, 1) var medium_room_initial_enemy_count: int = 16
@export_range(1, 10, 1) var small_room_initial_enemy_count: int = 12
@export_range(5, 20, 1) var dungeon_room_count: int = 8
@export_range(2, 8, 1) var dungeon_boss_min_depth: int = 4
@export_range(0.0, 1.0, 0.01) var dungeon_loop_connection_chance: float = 0.28
@export_range(0.25, 15.0, 0.25) var dungeon_population_refill_interval: float = 3.0
@export_range(1, 10, 1) var dungeon_population_refill_batch: int = 3
@export_range(32.0, 600.0, 1.0) var dungeon_enemy_follow_door_distance: float = 240.0
@export_range(0, 20, 1) var dungeon_enemy_follow_maximum: int = 6
@export_range(0.0, 2.0, 0.05) var dungeon_enemy_door_follow_delay: float = 0.35
@export_range(1, 8, 1) var large_room_wave_count: int = 2
@export_range(1, 8, 1) var medium_room_wave_count: int = 2
@export_range(1, 8, 1) var small_room_wave_count: int = 2
@export_range(1, 20, 1) var large_room_enemies_per_wave: int = 8
@export_range(1, 10, 1) var medium_room_enemies_per_wave: int = 4
@export_range(1, 8, 1) var small_room_enemies_per_wave: int = 3
## 世界卡片为物理物体；参数只控制交互/阻尼，不复制Upgrade效果。
@export_range(24.0, 96.0, 1.0) var world_card_interaction_radius: float = 50.0
@export_range(1.0, 30.0, 0.5) var world_card_linear_damp: float = 10.0
@export_range(20.0, 240.0, 1.0) var world_card_max_push_speed: float = 90.0
## 屏幕外生成安全边距：常规/触手怪必须生成在相机可见矩形外扩该边距的禁区之外。
@export_range(0.0, 200.0, 4.0) var enemy_spawn_visibility_margin: float = 64.0
@export var enemy_separation_strength: float = 24.0
@export var enemy_separation_radius: float = 30.0
## 压力倍率作用在现有难度曲线之后，但不会突破这个硬下限。
@export_range(0.05, 2.0, 0.05) var stress_absolute_minimum_spawn_interval: float = 0.25
## 正式Dream敌人池只包含Employee。旧敌人资源保留作历史兼容，但不再进入Spawner。
@export var enemy_unlock_days: Dictionary = {
	"employee": 1,
}
@export var enemy_base_spawn_weights: Dictionary = {
	"employee": 1.0,
}
## 每提升一天，沿用旧线性秒成长曲线所对应的秒数，不改写既有HP/伤害调参。
@export_range(1.0, 600.0, 1.0) var difficulty_seconds_per_day: float = 120.0
## Endless Dream HUD uses its own day cycle duration. Keep this explicit
## because the 2D Dream world reads it directly during startup.
@export_range(10.0, 600.0, 1.0) var endless_day_duration: float = 120.0

@export_group("Interaction Highlight")
@export var interaction_outline_color: Color = Color.WHITE
@export var interaction_outline_width: float = 2.0

@export_group("Player Damage Feedback")
## Spawn protection uses the same central player damage gate as hurt and dash invulnerability.
@export_range(0.0, 10.0, 0.1) var player_spawn_invulnerability_duration: float = 3.0
@export var hurt_invulnerability_seconds: float = 0.55
## Launch/knockdown keeps the gameplay body solid.  Damage stays gated through
## the short recovery pose, then for this additional grace period.
@export_range(0.0, 3.0, 0.05) var player_knockback_recovery_seconds: float = 0.18
@export_range(0.0, 3.0, 0.05) var player_post_getup_invulnerability_seconds: float = 0.80
@export var hurt_flash_frequency: float = 12.0
@export var hurt_flash_seconds: float = 0.18
@export var hurt_shake_pixels: float = 2.0
@export_range(0.0, 1.0, 0.01) var player_hurt_screen_flash_alpha: float = 0.24
@export_range(0.01, 0.5, 0.01) var player_hurt_screen_flash_seconds: float = 0.12

@export_group("Dialogue Portrait")
## 统一立绘节点使用 Alpha-aware Shader；运行时把屏幕像素宽度换算到源纹理像素。
@export var dialogue_portrait_outline_color: Color = Color("346db3")
@export_range(0.5, 8.0, 0.5) var dialogue_portrait_outline_width_px: float = 2.0
## 轻度冷蓝调和只影响角色主体，不改变2px描边颜色。
@export var dialogue_portrait_filter_color: Color = Color("8db9d8")
@export_range(0.0, 0.6, 0.01) var dialogue_portrait_filter_strength: float = 0.18

@export_group("Dream Visual Glow (No Light2D)")
## CanvasModulate仅做全局色调；以下半径/颜色只供SoftGlow绘制，不创建局部Light2D。
@export var dream_ambient_color: Color = Color("26313f")
@export_range(48.0, 240.0, 1.0) var player_light_radius: float = 104.0
@export var player_light_color: Color = Color("e7f0f8")
@export_range(0.01, 0.5, 0.01) var pickup_light_radius_multiplier: float = 0.10
@export_range(0.0, 0.5, 0.01) var enemy_environment_glow_alpha: float = 0.12
@export_range(0.0, 0.5, 0.01) var pickup_environment_glow_alpha: float = 0.14

@export_group("3D Visual Glow")
## A tiny visibility floor for the pixel carriers of Player and Enemy.  This
## is material emission only: it never creates a Light3D or illuminates the
## floor/world.  Both actor types use the same configured value.
@export_range(0.0, 0.25, 0.005) var character_self_emission_strength: float = 0.10
## Multiplier applied to 3D diffuse lighting on character pixel carriers (Player & Enemies).
## Lowers the direct light brightness illuminating the character without changing the cast shadow.
@export_range(0.0, 2.0, 0.05) var character_light_scale: float = 0.50
## Projectile heads remain on the unshaded carrier; this value only controls
## the small local halo added around the single procedural tracer head.
@export_range(0.0, 1.0, 0.05) var projectile_visual_glow_strength: float = 0.65
## Projectile carriers also receive a small unshaded material emission so the
## bullet head remains as readable as the Player/Enemy pixel carriers.  This is
## presentation-only and never illuminates the world.
@export_range(0.0, 2.0, 0.05) var projectile_self_emission_strength: float = 0.85
## Small, presentation-only 3D lights around active characters/projectiles.
## These never replace the authored room, window, or flashlight lighting.
@export var character_local_light_enabled: bool = false
@export_range(0.0, 1.0, 0.01) var character_local_light_energy: float = 0.18
@export_range(0.10, 3.0, 0.05) var character_local_light_range: float = 1.25
@export_range(0.0, 2.0, 0.01) var character_local_light_attenuation: float = 1.0
@export var character_local_light_color: Color = Color("dceeff")
@export var projectile_local_light_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var projectile_local_light_energy: float = 0.08
@export_range(0.05, 2.0, 0.05) var projectile_local_light_range: float = 0.55
@export_range(0.0, 2.0, 0.01) var projectile_local_light_attenuation: float = 1.0
@export var projectile_local_light_color: Color = Color("ffffff")
@export_range(1, 32, 1) var projectile_local_light_pool_size: int = 8
## 弹丸被墙体/家具遮挡时的 Occlusion Cutout（半调半透挖洞）表现配置。
@export var projectile_occlusion_cutout_enabled: bool = true
@export_range(0.05, 1.0, 0.01) var projectile_occlusion_cutout_radius: float = 0.20
## Ground pickups use a local material sweep.  The shader is presentation-only
## and is disabled while the pickup is airborne, claimed, hidden, or removed.
@export var world_weapon_shine_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var world_weapon_shine_strength: float = 0.55
@export_range(0.01, 0.35, 0.01) var world_weapon_shine_width: float = 0.10
@export_range(0.5, 8.0, 0.1) var world_weapon_shine_period: float = 3.2

@export_group("3D Window Lights")
## Window fixtures cast cool-toned nocturnal city light with crisp shadows through window apertures.
## The dungeon passes topology-derived normals to each wall.
@export var window_light_enabled: bool = true
@export_range(0.0, 5.0, 0.05) var window_light_energy: float = 2.2
@export_range(1.0, 24.0, 0.1) var window_light_range: float = 6.5
@export_range(20.0, 120.0, 1.0) var window_light_angle: float = 50.0
@export_range(0.0, 4.0, 0.01) var window_light_attenuation: float = 1.3
@export var window_light_color: Color = Color(0.52, 0.76, 1.0, 1.0)
@export_range(0.0, 0.5, 0.01) var window_light_inset: float = 0.12

@export_group("Alarm Visuals")
@export_range(0.0, 0.75, 0.01) var alarm_screen_brightness_alpha: float = 0.30
@export_range(0.0, 120.0, 1.0) var alarm_eyelid_max_height: float = 42.0
@export_range(0.1, 180.0, 0.1) var alarm_visual_ramp_seconds: float = 45.0

@export_group("Wake Up")
@export var base_wake_hold_seconds: float = 5.0
@export var extra_hold_every_seconds: float = 10.0
@export var extra_hold_seconds: float = 2.0
@export var wake_progress_regress_per_second: float = 2.0

@export_group("Superhot Dream Time")
## Player-driven time is intentionally separate from the legacy bullet-time
## tuning above.  The controller resolves these values using a real-time clock.
@export_range(0.001, 1.0, 0.001) var superhot_min_time_scale: float = 0.005
@export_range(0.05, 1.0, 0.01) var superhot_max_time_scale: float = 1.0
@export_range(0.005, 0.5, 0.005) var superhot_resume_tau: float = 0.035
@export_range(0.005, 0.5, 0.005) var superhot_slowdown_tau: float = 0.075
@export_range(0.01, 0.25, 0.01) var superhot_shot_pulse_seconds: float = 0.05
@export_range(0.01, 0.5, 0.01) var superhot_movement_wake_grace_seconds: float = 0.12
## Movement activity remains active briefly after WASD is released.  This is
## deliberately separate from the edge-triggered wake grace above so the
## slowdown curve itself stays unchanged.
@export_range(0.05, 0.5, 0.01) var superhot_movement_release_grace_seconds: float = 0.20
@export_range(0.0, 0.3, 0.01) var superhot_movement_deadzone: float = 0.05

@export_group("Player Movement Actions")
## Legacy hold-preview timing; the current Space action triggers phase dash
## immediately on press and does not enter this preview.
@export_range(0.08, 0.30, 0.01) var dash_aim_hold_threshold: float = 0.16
## Vault trigger distance is measured from the Player to the nearest point on
## a vaultable Furniture CollisionShape2D, never to its visual/center point.
@export_range(32.0, 120.0, 1.0) var vault_trigger_radius_px: float = 80.0
## Roll speed trails are presentation-only samples taken from actual gameplay
## displacement.  They never alter dash distance, duration, or collision.
@export_range(4.0, 40.0, 1.0) var roll_trail_sample_distance: float = 14.0
@export_range(0.04, 0.6, 0.01) var roll_trail_lifetime: float = 0.26
@export_range(0.0, 1.0, 0.02) var roll_trail_stretch: float = 0.12
@export_range(0.0, 1.0, 0.05) var roll_trail_start_alpha: float = 0.85

@export_group("Superhot Gameplay Audio")
## World SFX use a compressed time curve rather than following Engine.time_scale
## directly.  This keeps frozen-time impacts audible instead of stretching them
## into unusable subsonic tails.
@export_range(0.05, 1.0, 0.01) var gameplay_sfx_min_pitch: float = 0.35
@export_range(0.5, 1.5, 0.01) var gameplay_sfx_max_pitch: float = 1.0
@export_range(0.1, 2.0, 0.05) var gameplay_sfx_curve_exponent: float = 0.5
@export_range(0.005, 0.5, 0.005) var gameplay_sfx_resume_tau: float = 0.045
@export_range(0.005, 0.5, 0.005) var gameplay_sfx_slowdown_tau: float = 0.09
@export_range(500.0, 8000.0, 100.0) var gameplay_sfx_lowpass_min_hz: float = 2500.0
@export_range(8000.0, 22000.0, 100.0) var gameplay_sfx_lowpass_max_hz: float = 20000.0
@export_range(4.0, 128.0, 1.0) var gameplay_sfx_3d_max_distance: float = 64.0
@export_range(0.1, 32.0, 0.5) var gameplay_sfx_3d_unit_size: float = 10.0
@export_range(1.0, 32.0, 1.0) var gameplay_sfx_3d_voice_count: int = 12

@export_group("Progression")
@export var first_level_experience_requirement: int = 20
@export var experience_growth_base: int = 8
@export var experience_requirement_cap: int = 32767
@export var damage_upgrade_multiplier: float = 1.5

@export_group("Character Card")
## TAB角色卡的可分段属性。第1格就是当前默认游戏手感，不额外放大基础速度。
@export_range(1, 10, 1) var character_card_max_stat_cells: int = 10
@export_range(1.0, 100.0, 1.0) var character_card_hp_per_cell: float = 20.0
@export_range(0.0, 1.0, 0.01) var character_card_speed_bonus_per_cell: float = 0.20
@export_range(1, 10, 1) var character_card_default_hp_cells: int = 4
@export_range(1, 10, 1) var character_card_default_speed_cells: int = 1
@export_range(0.15, 1.0, 0.01) var character_card_enter_seconds: float = 0.42
@export_range(0.15, 1.0, 0.01) var character_card_exit_seconds: float = 0.32

@export_group("Pixel Art and Effects")
## Pix_chr只在Visual/HealOverlay使用稳定绝对缩放；不得在进场时累乘。
## Standard 32x32 Dream actors map to one gameplay cell in the 3D bridge.
## This is the single visual-scale authority for Player and EmployeeEnemy;
## the bridge keeps its fixed 1/32 pixel-to-world conversion and does not add
## another actor multiplier.
@export_range(0.25, 4.0, 0.05) var player_visual_scale: float = 1.0
@export var player_visual_offset: Vector2 = Vector2(0.0, -18.25)
## dream_chr_32x32.png为32px分层图集；以下位置均以脚底(0,0)为视觉基准。
@export var player_parts_ground_offset: Vector2 = Vector2.ZERO
@export_range(1.0, 4.0, 0.1) var player_idle_breath_period: float = 1.8
@export_range(0.0, 4.0, 1.0) var player_idle_body_breath_pixels: float = 1.0
@export_range(0.0, 4.0, 1.0) var player_idle_head_breath_pixels: float = 2.0
@export_range(1.0, 12.0, 0.5) var player_blink_interval_min: float = 2.0
@export_range(1.0, 12.0, 0.5) var player_blink_interval_max: float = 6.0
@export_range(0.02, 0.20, 0.01) var player_blink_frame_seconds: float = 0.06
@export_range(0.0, 5.0, 1.0) var player_walk_leg_swing_pixels: float = 2.0
@export_range(0.0, 4.0, 1.0) var player_walk_leg_lift_pixels: float = 2.0
@export_range(0.5, 8.0, 0.1) var player_walk_cycles_per_second: float = 2.2
@export_range(0.0, 4.0, 1.0) var player_walk_body_bob_pixels: float = 2.0
@export_range(0.0, 5.0, 1.0) var player_walk_visual_bounce_pixels: float = 3.0
## 每几个「步态半步」播放一次脚步。1 = 每只脚落地都响，满速约 4.4 步/秒；
## 2 = 只在每整周期的一只脚落地时响，约 2.2 步/秒，听感更舒缓；数值越大越稀疏。
@export_range(1, 4, 1) var player_footstep_step_interval: int = 1
@export_range(1.0, 32.0, 0.5) var player_collision_radius: float = 7.5
@export var player_collision_offset: Vector2 = Vector2(0.0, -13.0)
@export var player_weapon_root_offset: Vector2 = Vector2(0.0, -18.25)
@export_range(0.5, 8.0, 0.5) var player_idle_animation_fps: float = 1.0
@export_range(2.0, 16.0, 0.5) var player_walk_animation_fps: float = 8.0
@export_range(0.1, 1.0, 0.05) var heal_feedback_seconds: float = 0.3
## 只有经验/回复等拾取物保留低成本提示光晕；所有Projectile均为普通像素Sprite。
@export var pickup_glow_color: Color = Color("77b8cf")
@export_range(0.0, 0.5, 0.01) var pickup_glow_alpha: float = 0.18
@export_range(2.0, 24.0, 1.0) var pickup_glow_radius: float = 10.0
@export_range(0.0, 0.5, 0.01) var xp_glow_alpha: float = 0.30
@export_range(2.0, 12.0, 0.5) var xp_glow_radius: float = 5.0
@export_range(0.0, 0.5, 0.01) var heart_glow_alpha: float = 0.30
@export_range(2.0, 12.0, 0.5) var heart_glow_radius: float = 5.0
@export_range(32.0, 180.0, 1.0) var pickup_magnet_radius: float = 92.0
@export_range(2.0, 12.0, 0.5) var pickup_lift_height: float = 7.0
@export_range(0.04, 0.4, 0.01) var pickup_lift_duration: float = 0.12
@export_range(0.08, 0.8, 0.01) var pickup_suction_duration: float = 0.28
@export var pickup_suction_curve: Curve
@export_range(4.0, 24.0, 1.0) var pickup_snap_distance: float = 12.0
@export_range(1.0, 60.0, 1.0) var electric_shield_animation_fps: float = 30.0
@export_range(0.05, 1.0, 0.01) var electric_shield_visual_scale: float = 0.18
@export_range(20.0, 100.0, 1.0) var player_hp_bar_width: float = 30.0
@export_range(2.0, 10.0, 1.0) var player_hp_bar_height: float = 5.0
@export var player_hp_bar_offset: Vector2 = Vector2(0.0, 7.0)
@export_range(0.25, 8.0, 0.05) var player_hp_bar_visible_duration: float = 2.5
@export_range(8.0, 20.0, 1.0) var enemy_hp_bar_width: float = 20.0
@export_range(2.0, 6.0, 1.0) var enemy_hp_bar_height: float = 3.0
@export_range(0.0, 12.0, 1.0) var enemy_hp_bar_bottom_margin: float = 2.0
@export_range(0.25, 8.0, 0.05) var enemy_hp_bar_visible_duration: float = 2.5
@export_range(0.02, 0.3, 0.01) var weapon_muzzle_flash_seconds: float = 0.07
@export_range(0.04, 0.5, 0.01) var weapon_hit_effect_seconds: float = 0.14
@export_range(2.0, 32.0, 1.0) var projectile_trail_length: float = 10.0
@export var weapon_effect_primary_color: Color = Color("ff9d32")
@export var weapon_effect_secondary_color: Color = Color("ffd07a")
@export var weapon_effect_warning_color: Color = Color("d86b24")

@export_group("Player Control")
## 玩家和武器基础数值统一由本资源提供，场景脚本只维护运行时强化结果。
@export var player_base_maximum_health: float = 80.0
## Player移动手感：较高的目标速度配合独立加/减速，避免按键松开后滑行。
@export_range(20.0, 320.0, 1.0) var player_movement_speed: float = 204.0
@export_range(100.0, 2400.0, 25.0) var player_movement_acceleration: float = 900.0
@export_range(100.0, 3000.0, 25.0) var player_movement_deceleration: float = 1200.0
@export_group("Weapons")
## Weapon data stores seconds-per-shot/attack.  Keep the global multiplier at
## one so each weapon uses its original authored cadence; upgrades remain the
## only runtime source of an intentional speed change.
@export_range(0.1, 2.0, 0.025) var weapon_fire_rate_multiplier: float = 1.0
@export var basic_weapon_damage: float = 10.0
@export var basic_weapon_attack_interval: float = 0.30
@export var basic_weapon_range: float = 350.0
## Firearm projectile speed is the original 310 px/s baseline reduced by 50%.
@export var basic_projectile_speed: float = 550.0
@export_range(0.25, 1.0, 0.05) var basic_projectile_visual_scale: float = 0.75
@export_range(1, 99, 1) var basic_magazine_size: int = 15
@export var basic_recoil_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var projectile_penetration_chance: float = 0.10
@export_range(0, 1, 1) var projectile_max_penetrations: int = 1
@export_group("Assault Rifle")
## 低于手枪单发伤害，但以高射速维持压制；普通 Employee 约三发失去战斗能力。
@export var assault_rifle_damage: float = 6.0
@export var assault_rifle_attack_interval: float = 0.15
@export var assault_rifle_range: float = 500.0
## Original authored assault-rifle projectile speed: 360 px/s; this pass uses
## the requested 50% projectile-speed reduction.
@export var assault_rifle_projectile_speed: float = 550.0
@export_range(0.25, 1.0, 0.05) var assault_rifle_projectile_visual_scale: float = 0.60
@export_range(1, 99, 1) var assault_rifle_magazine_size: int = 30
@export var assault_rifle_recoil_multiplier: float = 0.8
@export_group("")
@export var shotgun_pellet_count: int = 9
## 近距离一轮霰弹应明显高于手枪；9 颗弹丸合计最高 36 伤害。
@export var shotgun_pellet_damage: float = 4.0
@export var shotgun_attack_interval: float = 0.8
@export var shotgun_spread_degrees: float = 30.0
## Original authored shotgun projectile speed: 310 px/s; this pass uses 50%.
@export var shotgun_projectile_speed: float = 550.0
@export var shotgun_max_distance: float = 220.0
@export var shotgun_recoil_multiplier: float = 1.8
@export var lucille_damage: float = 30.0
@export var lucille_attack_range: float = 30.0
@export_range(1.0, 180.0, 1.0) var lucille_attack_arc_degrees: float = 120.0
@export var lucille_attack_interval: float = 0.6
## Books使用与Lucille相同的统一近战挥击管线，保留独立的轻武器参数。
@export var books_damage: float = 5.0
@export var books_attack_range: float = 30.0
@export_range(1.0, 180.0, 1.0) var books_attack_arc_degrees: float = 120.0
@export_range(0.1, 3.0, 0.05) var books_attack_interval: float = 0.8
@export_range(0.1, 3.0, 0.05) var books_knockback_multiplier: float = 0.75

## Player-only reach. Enemy melee retains the original shared weapon values.
@export var player_lucille_attack_range: float = 80.0
@export_range(1.0, 180.0, 1.0) var player_lucille_attack_arc_degrees: float = 160.0
@export var player_books_attack_range: float = 80.0
@export_range(1.0, 180.0, 1.0) var player_books_attack_arc_degrees: float = 150.0


@export_range(2, 16, 1) var lucille_trail_max_points: int = 12
@export_range(0.02, 0.4, 0.01) var lucille_trail_fade_seconds: float = 0.12
@export_range(0.10, 0.24, 0.01) var lucille_trail_lifetime: float = 0.18
## 近战挥击拖尾的总弧线半径（HandAnchor局部像素）；Books使用更紧凑的半径。
@export_range(8.0, 48.0, 1.0) var lucille_trail_radius: float = 26.0
@export_range(8.0, 48.0, 1.0) var books_trail_radius: float = 19.0
## 宽弧拖尾的最大宽度；Line2D width_curve 会让尾端逐渐变窄。
@export_range(2.0, 24.0, 1.0) var lucille_trail_width: float = 10.0
@export_range(2.0, 24.0, 1.0) var books_trail_width: float = 7.0
## 视觉第4阶段的命中时刻；必须早于一次近战攻击间隔。
@export_range(0.04, 0.20, 0.01) var melee_swing_impact_delay: float = 0.12
## 当前Run内的弹丸武器共用同一默认弹匣规格；每把武器各自保存剩余弹量。
@export_range(1, 99, 1) var default_weapon_magazine_size: int = 12
@export_range(0.1, 10.0, 0.05) var weapon_reload_duration: float = 0.75
@export_range(8.0, 64.0, 1.0) var crosshair_reload_bar_width: float = 24.0
@export_range(2.0, 8.0, 1.0) var crosshair_reload_bar_height: float = 3.0
@export var crosshair_reload_bar_offset: Vector2 = Vector2(-12.0, 13.0)
## HandAnchor只控制世界武器视觉/发射挂点，不改变Player Body或武器数值。
@export var held_weapon_distance: float = 11.0
@export var held_weapon_world_scale: float = 1.0
@export var weapon_recoil_distance: float = 4.0
@export_range(0.01, 0.2, 0.01) var weapon_recoil_kick_seconds: float = 0.04
@export_range(0.01, 0.3, 0.01) var weapon_recoil_return_seconds: float = 0.09
## Physical movement recoil is a small external impulse, separate from visual
## weapon kick and from airborne knockback. Values are per shot velocity units.
@export_range(0.0, 120.0, 1.0) var player_default_firearm_recoil: float = 0.0
@export_range(0.0, 160.0, 1.0) var player_assault_rifle_recoil: float = 20.0
@export_range(0.0, 220.0, 1.0) var player_shotgun_recoil: float = 44.0
@export_range(0.0, 100.0, 1.0) var player_melee_furniture_recoil: float = 22.0

@export_group("Employee ranged attack")
@export_range(0.05, 2.0, 0.05) var employee_ranged_attack_windup: float = 0.8
@export_range(1.0, 30.0, 0.5) var employee_ranged_windup_animation_fps: float = 12.0

@export_group("Player Kick")
## 踢击是身体动作，不读取武器伤害、暴击或卡片倍率。
@export var kick_damage: float = 10.0
@export_range(12.0, 72.0, 1.0) var kick_range: float = 34.0
@export_range(12.0, 64.0, 1.0) var kick_width: float = 28.0
@export_range(0.15, 0.8, 0.01) var kick_animation_duration: float = 0.28
@export_range(1.0, 24.0, 1.0) var kick_leg_extension_pixels: float = 12.0
@export_range(0.0, 8.0, 0.5) var kick_body_lean_pixels: float = 3.0
@export_range(0.0, 60.0, 1.0) var kick_body_max_lean_degrees: float = 45.0

@export_group("Player Unarmed Punch")
## 空手使用Primary Attack时的轻量近战参数；不属于可拾取Weapon。
@export_range(0.5, 10.0, 0.5) var player_punch_damage: float = 2.0
@export_range(8.0, 60.0, 1.0) var player_punch_range: float = 30.0
@export_range(0.10, 0.80, 0.01) var player_punch_interval: float = 0.30
@export_range(0.01, 0.20, 0.01) var player_punch_windup_seconds: float = 0.04
@export_range(0.02, 0.20, 0.01) var player_punch_strike_seconds: float = 0.05
@export_range(0.02, 0.30, 0.01) var player_punch_recover_seconds: float = 0.12
@export_range(1.0, 120.0, 1.0) var player_punch_arc_degrees: float = 70.0

@export_group("Combat Knockback")
## 统一击退基准K。枪械=K，Kick=K×2，Lucille=Kick×2。
@export_range(20.0, 800.0, 10.0) var gun_knockback_force: float = 300.0
@export_range(1.0, 6.0, 0.1) var kick_knockback_multiplier: float = 2.0
@export_range(1.0, 6.0, 0.1) var lucille_knockback_multiplier: float = 2.0
@export_range(100.0, 3000.0, 25.0) var maximum_knockback_speed: float = 1200.0
@export_range(100.0, 3000.0, 25.0) var character_knockback_drag: float = 900.0
@export_range(0.0, 0.95, 0.05) var character_knockback_bounce_retention: float = 0.35
@export_range(20.0, 400.0, 5.0) var character_knockback_vertical_velocity: float = 115.0
@export_range(50.0, 1200.0, 10.0) var character_knockback_fake_gravity: float = 280.0
## Player使用与Employee相同的“残余速度决定反弹”思路，但保留更克制的落地手感。
@export_range(0.0, 1.0, 0.05) var player_knockback_air_drag_multiplier: float = 0.35
@export_range(0.0, 0.95, 0.05) var player_knockback_ground_vertical_retention: float = 0.30
@export_range(0.0, 0.95, 0.05) var player_knockback_ground_horizontal_retention: float = 0.65
@export_range(1.0, 100.0, 1.0) var player_knockback_minimum_bounce_velocity: float = 30.0
@export_range(1.0, 100.0, 1.0) var player_knockback_settle_speed: float = 22.0
@export_range(0.0, 100.0, 1.0) var secondary_collision_damage: float = 8.0
@export_range(0.05, 2.0, 0.05) var secondary_collision_cooldown: float = 0.35
## 0 = 血迹在本场 Dream 内永久保留（不按时间/数量清理）；正值 = 全局预算上限。
@export_range(0, 160, 1) var black_blood_max_stains: int = 0

@export_group("Blood Intensity")
@export_range(0.35, 1.8, 0.05) var blood_pistol_intensity: float = 0.82
@export_range(0.35, 1.8, 0.05) var blood_automatic_intensity: float = 0.68
@export_range(0.35, 1.8, 0.05) var blood_shotgun_intensity: float = 1.45
@export_range(0.35, 1.8, 0.05) var blood_kick_intensity: float = 0.90
@export_range(0.35, 1.8, 0.05) var blood_lucille_intensity: float = 1.55
@export_range(0.35, 1.8, 0.05) var blood_furniture_intensity: float = 1.05

@export_group("Death Blood")
## Death Burst remains one BlackBloodEffect, with these multipliers applied
## only to its droplet count, initial velocity and angular spread.
@export_range(0.35, 3.0, 0.05) var death_burst_intensity: float = 1.8
@export_range(0.25, 3.0, 0.05) var death_burst_droplet_multiplier: float = 1.5
@export_range(0.25, 3.0, 0.05) var death_burst_speed_multiplier: float = 1.35
@export_range(0.25, 3.0, 0.05) var death_burst_spread_multiplier: float = 1.25
@export_range(0.1, 6.0, 0.05) var corpse_bleed_duration: float = 2.2
@export_range(0.05, 1.0, 0.01) var corpse_bleed_initial_interval: float = 0.22
@export_range(0.5, 0.99, 0.01) var corpse_bleed_decay: float = 0.78
@export_range(0.0, 2.0, 0.05) var death_pool_growth_duration: float = 0.45
@export_range(0.1, 2.0, 0.05) var death_pool_min_scale: float = 0.35
@export_range(0.1, 2.0, 0.05) var death_pool_max_scale: float = 1.0
@export_range(1, 64, 1) var max_active_corpse_blood_emitters: int = 12

@export_group("Corpse Presentation")
## 敌人死亡后尸体在地面停留时长（秒），默认约15秒。
@export_range(1.0, 60.0, 0.5) var corpse_linger_duration: float = 15.0
## 尸体在地面明度降低过渡时间（秒），默认3秒。
@export_range(0.5, 10.0, 0.1) var corpse_darken_duration: float = 3.0
## 尸体明度降低的目标比例，0.5即50%。
@export_range(0.0, 1.0, 0.05) var corpse_darken_target_brightness: float = 0.5
## 致死受力转换为整具尸体的初始水平速度；不改变存活时的击退或伤害。
@export_range(0.1, 1.5, 0.05) var corpse_impulse_transfer: float = 0.75
@export_range(0.0, 1.0, 0.05) var corpse_inherited_velocity_ratio: float = 0.35
@export_range(60.0, 600.0, 10.0) var corpse_max_launch_speed: float = 360.0
@export_range(0.0, 300.0, 10.0) var corpse_air_drag: float = 40.0
@export_range(50.0, 800.0, 10.0) var corpse_ground_drag: float = 320.0
@export_range(0.0, 0.5, 0.02) var corpse_wall_restitution: float = 0.18
@export_range(0.0, 1.0, 0.05) var corpse_wall_slide_retention: float = 0.65

@export_group("Top Wall Head Clearance")
## 角色视觉是与屏幕平行的斜牌：头部会向镜头远侧前伸约等于其像素高度的距离。
## 因此在顶墙（房间靠地图上方一侧）的房间内生成一条只作用于 Actor 的空气墙，
## 让脚锚点永远停在头部不会越过墙平面的位置。子弹、血滴射线与视线都不使用
## 该层，行为完全不变。0 表示关闭该空气墙。
# Keep the actor-only head-clearance band inside the near half of a gameplay
# cell.  A deeper band overlaps the Player's centred body capsule at an
# otherwise valid neighbouring floor cell and becomes an invisible traversal
# blocker, especially at macro-room boundaries.
@export_range(0.0, 128.0, 1.0) var top_wall_air_wall_depth_px: float = 8.0

@export_group("World Weapon Pickup")
@export_range(16.0, 64.0, 1.0) var world_weapon_interaction_radius: float = 34.0
@export_range(12.0, 64.0, 1.0) var world_weapon_drop_offset: float = 28.0
@export_range(0.0, 160.0, 5.0) var world_weapon_swap_drop_impulse: float = 45.0
@export_range(0.1, 4.0, 0.05) var world_weapon_mass: float = 0.65
## Player右键抛掷沿用WorldWeapon真实RigidBody；速度/伤害仅由此处调节。
@export_range(40.0, 1200.0, 10.0) var world_weapon_throw_force: float = 460.0
@export_range(0.1, 2.0, 0.05) var world_weapon_throw_melee_force_multiplier: float = 1.15
## Throw移动速度与命中冲击力分离；该倍率只影响武器飞行速度。
@export_range(1.0, 3.0, 0.05) var world_weapon_throw_speed_multiplier: float = 2.1
## 普通地面武器保持场景阻尼，Throw阶段使用较低阻尼保留高速动量。
@export_range(0.0, 5.0, 0.05) var world_weapon_throw_linear_damp: float = 0.8
@export_range(0.0, 10.0, 0.1) var world_weapon_throw_angular_damp: float = 1.5
@export_range(0.5, 6.0, 0.1) var world_weapon_throw_max_duration: float = 2.8
@export_range(20.0, 300.0, 5.0) var world_weapon_throw_minimum_speed: float = 72.0
@export_range(0.1, 1.5, 0.05) var world_weapon_throw_pickup_lockout: float = 0.45
## A melee weapon gets one break roll after its first valid high-speed throw
## impact.  Firearms never use this chance.
@export_range(0.0, 1.0, 0.01) var world_weapon_throw_melee_break_chance: float = 0.50

@export_group("Shell Ejection")
@export_range(8, 96, 1) var shell_effect_max_visible: int = 48
@export_range(0.5, 5.0, 0.1) var shell_effect_lifetime: float = 2.2
@export_range(50.0, 600.0, 10.0) var shell_effect_fake_gravity: float = 180.0

@export_group("Furniture Impact")
## Weapon hits use the shared gun force as their base, but furniture needs a
## separate visual hierarchy: pistol small, a full shotgun volley obvious,
## Kick high, and Lucille very high. Shotgun is expressed per pellet so a
## complete nine-pellet volley lands at roughly 1.8x the gun base instead of
## incorrectly applying nine full pistol impulses.
@export_range(0.0, 2.0, 0.05) var furniture_pistol_force_multiplier: float = 0.35
@export_range(0.0, 2.0, 0.05) var furniture_assault_rifle_force_multiplier: float = 0.20
@export_range(0.0, 1.0, 0.01) var furniture_shotgun_pellet_force_multiplier: float = 0.20
@export_range(0.0, 2.0, 0.05) var furniture_hitscan_force_multiplier: float = 0.75
## 高速家具撞击是独立伤害源，不经过武器或Enemy接触伤害倍率。
@export var furniture_impact_damage: float = 20.0
## 房间实例化/重新激活后的短暂保护只屏蔽错误的出生冲击伤害，不关闭物理碰撞。
@export_range(0.0, 1.0, 0.01) var furniture_impact_spawn_grace: float = 0.25
@export_range(20.0, 500.0, 5.0) var furniture_impact_minimum_speed: float = 100.0
@export_range(0.05, 2.0, 0.05) var furniture_impact_target_cooldown: float = 0.45
@export_range(0.1, 1.0, 0.05) var furniture_impact_velocity_retention: float = 0.72
@export_range(0.1, 1.0, 0.05) var furniture_velocity_retention_after_character_hit: float = 0.72
@export_range(0.0, 0.95, 0.05) var furniture_wall_bounce_retention: float = 0.45
@export_range(0.0, 0.95, 0.05) var furniture_prop_bounce_retention: float = 0.55
@export_range(0.0, 2.0, 0.05) var furniture_prop_impulse_multiplier: float = 0.65
@export_range(20.0, 600.0, 10.0) var furniture_impact_enemy_knockback: float = 180.0
@export_range(0.5, 3.0, 0.05) var furniture_impact_knockdown_force_multiplier: float = 1.5

@export_group("Furniture Size Behavior")
## Shared response multipliers.  Furniture scenes select a size category; these
## values keep push/kick/combat tuning centralized instead of per-scene.
@export_range(0.0, 3.0, 0.05) var furniture_small_push_response: float = 1.25
@export_range(0.0, 3.0, 0.05) var furniture_medium_push_response: float = 1.0
@export_range(0.0, 3.0, 0.05) var furniture_large_push_response: float = 0.65
@export_range(0.0, 3.0, 0.05) var furniture_small_kick_response: float = 1.25
@export_range(0.0, 3.0, 0.05) var furniture_medium_kick_response: float = 0.80
@export_range(0.0, 3.0, 0.05) var furniture_large_kick_response: float = 0.0
@export_range(0.0, 3.0, 0.05) var furniture_small_combat_impulse_response: float = 1.10
@export_range(0.0, 3.0, 0.05) var furniture_medium_combat_impulse_response: float = 0.85
@export_range(0.0, 3.0, 0.05) var furniture_large_combat_impulse_response: float = 0.35

## Books只从指定可破坏家具的最终销毁事件中稀有掉落，不进入普通武器池。
@export_range(0.0, 1.0, 0.01) var books_drop_chance_cabinet: float = 0.22
@export_range(0.0, 1.0, 0.01) var books_drop_chance_table: float = 0.12
@export_range(0.0, 1.0, 0.01) var books_drop_chance_trash_can: float = 0.08

@export_group("Environment Debris")
## Environment debris uses the existing 32px Office icon atlas.  The room
## area determines the ambient count and these bounds keep density tunable.
@export_range(0, 32, 1) var environment_debris_ambient_min_per_room: int = 2
@export_range(0, 64, 1) var environment_debris_ambient_max_per_room: int = 10
@export_range(1024.0, 50000.0, 256.0) var environment_debris_area_per_item: float = 12000.0
@export_range(4, 160, 1) var environment_debris_max_per_room: int = 64
@export_range(16.0, 160.0, 1.0) var environment_debris_door_clearance: float = 48.0
@export_range(16.0, 160.0, 1.0) var environment_debris_spawn_clearance: float = 56.0
@export_range(20.0, 400.0, 5.0) var environment_debris_hit_spray_speed: float = 82.0
@export_range(20.0, 500.0, 5.0) var environment_debris_destroy_spray_speed: float = 135.0
@export_range(20.0, 600.0, 10.0) var environment_debris_spray_speed_variance: float = 35.0
@export_range(0.0, 180.0, 1.0) var environment_debris_spray_spread_degrees: float = 36.0
@export_range(0.0, 500.0, 10.0) var environment_debris_spray_up_velocity: float = 42.0
@export_range(0.0, 1200.0, 10.0) var environment_debris_spray_gravity: float = 240.0
@export_range(0.0, 1600.0, 10.0) var environment_debris_spray_drag: float = 420.0
@export_range(0.05, 0.5, 0.01) var environment_debris_break_duration: float = 0.12
@export_group("Critical Hits")
@export_range(0.0, 1.0, 0.01) var player_base_critical_chance: float = 0.10
@export_range(1.0, 5.0, 0.05) var player_critical_damage_multiplier: float = 1.50

@export_group("Dash")
## Space 按下立即朝鼠标穿墙冲刺；落地以单次胶囊结算，直接击杀刷新。
@export_range(32.0, 240.0, 1.0) var dash_distance: float = 168.0
@export_range(0.06, 0.5, 0.01) var dash_duration: float = 0.14
@export_range(0.2, 5.0, 0.05) var dash_cooldown: float = 0.8
@export_range(4.0, 48.0, 1.0) var phase_dash_attack_radius: float = 16.0
@export var dash_invulnerability_seconds: float = 0.18
## Thunder.png 实际切帧数（512×256 横向 8 列 64×256，从左到右播放）。
@export_range(1, 16, 1) var dash_thunder_frame_count: int = 8
## Thunder 序列帧播放 FPS：与 Dash 位移/冷却/无敌完全解耦，仅控制视觉。
@export_range(4.0, 60.0, 1.0) var dash_thunder_fps: float = 24.0

@export_group("Dive")
## 旧飞扑兼容参数；正式 Space 输入不再进入飞扑。
@export_range(0.15, 0.8, 0.01) var dive_duration: float = 0.35
@export_range(0.05, 1.0, 0.05) var dive_bullet_time_scale: float = 0.2
@export_range(0.4, 0.9, 0.05) var dive_airborne_ratio: float = 0.70
@export_range(15.0, 75.0, 1.0) var dive_takeoff_angle_degrees: float = 45.0
@export_range(8.0, 36.0, 1.0) var dive_peak_height: float = 18.0

@export_group("Tactical Planning Dash")
## 旧预演兼容参数；正式 Space 使用按下即触发的穿墙冲刺。
@export var tactical_dash_enabled: bool = false
@export_range(1.5, 4.0, 0.1) var tactical_dash_distance_multiplier: float = 2.0
@export_range(1.0, 15.0, 0.5) var tactical_dash_cooldown_seconds: float = 5.0
@export_range(0.01, 0.5, 0.01) var tactical_dash_time_scale: float = 0.05
@export_range(0.08, 0.50, 0.01) var tactical_dash_hold_threshold: float = 0.16

@export_group("Map Generation")
## 地图生成算法："otxo_mansion" 为迈阿密热线/OTXO连体紧凑大楼；"macro_corridor" 为原版独立走廊地牢
@export_enum("otxo_mansion", "macro_corridor") var map_generator_type: String = "otxo_mansion"
## OTXO连体大楼目标房间数（推荐 14~18 间）
@export_range(6, 24, 1) var otxo_mansion_room_count: int = 16
## 室内可击碎玻璃窗生成概率 (0.0~1.0)
@export_range(0.0, 1.0, 0.05) var otxo_mansion_glass_chance: float = 0.35
## 连通回路率加成 (增加套房之间的互通门)
@export_range(0.0, 1.0, 0.05) var otxo_mansion_loop_ratio: float = 0.45

@export_group("Aim")
## 0表示不限制搜索半径；默认值覆盖完整梦境场地。
@export var crosshair_cooldown_color: Color = Color(0.35, 0.36, 0.4, 1.0)
@export var crosshair_ready_color: Color = Color.WHITE
@export var crosshair_color_lerp_speed: float = 10.0
@export var crosshair_recoil_pixels: float = 5.0
@export var crosshair_recoil_recovery_seconds: float = 0.12
@export_range(0.0, 180.0, 1.0) var crosshair_recoil_angle_degrees: float = 45.0
@export var basic_weapon_recoil_multiplier: float = 1.0

@export_group("Dream Camera")

## Player在镜头中央允许活动的区域。
@export_range(0.0, 160.0, 1.0) var camera_dead_zone_x: float = 28.0
@export_range(0.0, 120.0, 1.0) var camera_dead_zone_y: float = 18.0

## 准星能够把镜头拉向四周的最大距离。
@export_range(0.0, 400.0, 1.0) var camera_aim_max_offset_x: float = 160.0
@export_range(0.0, 300.0, 1.0) var camera_aim_max_offset_y: float = 100.0

## 鼠标/目标距离达到这个值以后，准星镜头偏移达到最大值。
@export_range(32.0, 1200.0, 1.0) var camera_aim_distance_for_max_offset: float = 340.0

## Player超出中央区域后，Camera追上来的速度。
@export_range(1.0, 30.0, 0.5) var camera_follow_smoothing: float = 10.0

## Camera跟随准星的速度。
@export_range(1.0, 30.0, 0.5) var camera_aim_smoothing: float = 8.5

@export_group("Enemy Outline")
## 敌人被锁定/选中时的白描边宽度（源纹理像素空间，基于 TEXTURE_PIXEL_SIZE，
## 不随节点缩放放大；VisualRoot ×4 时屏幕实际观感仍为细描边）。
@export_range(0.5, 8.0, 0.5) var enemy_outline_width_px: float = 2.0
@export_group("Enemy Hit Feedback")
@export var enemy_hit_flash_color: Color = Color(1.8, 1.8, 1.8, 1.0)
@export var enemy_hit_flash_seconds: float = 0.06
@export var enemy_hit_scale_seconds: float = 0.12
@export_range(0.0, 0.5, 0.01) var enemy_hit_scale_amount: float = 0.16
## 真实物理击退使用move_and_slide并快速线性衰减；特殊敌人可覆写Resistance。
@export_range(0.0, 400.0, 1.0) var enemy_knockback_strength: float = 96.0
@export_range(0.0, 1.0, 0.01) var employee_dismember_chance: float = 0.30
@export_range(0.02, 0.5, 0.01) var enemy_knockback_duration: float = 0.14
@export_group("Combat Response")
## A real resolved knockback force is normalized against this value before it
## selects hit-stop and camera response.  Weapon names are not a second tuning
## table; callers without force data may still use the legacy tier API.
@export_range(1.0, 2400.0, 1.0) var combat_impact_reference_knockback: float = 600.0
@export_range(0.1, 3.0, 0.05) var combat_impact_max_normalized: float = 1.5
## HitStop分级：由实际冲击归一化后选择。
@export_range(0.005, 0.08, 0.005) var hit_stop_duration: float = 0.02
@export_range(0.005, 0.08, 0.005) var hit_stop_medium_duration: float = 0.04
@export_range(0.005, 0.08, 0.005) var hit_stop_heavy_duration: float = 0.07
@export_range(0.01, 0.5, 0.01) var hit_stop_minimum_interval: float = 0.06
@export_range(0.01, 1.0, 0.01) var hit_stop_time_scale: float = 0.05
## Camera冲击仅影响World相机，不暂停UI或输入。
@export_range(0.0, 32.0, 0.5) var camera_small_impulse: float = 2.0
@export_range(0.0, 32.0, 0.5) var camera_medium_impulse: float = 4.5
@export_range(0.0, 32.0, 0.5) var camera_heavy_impulse: float = 8.0
@export_range(0.03, 0.4, 0.01) var camera_impulse_duration: float = 0.12
@export_range(1.0, 80.0, 1.0) var camera_shake_frequency: float = 28.0
@export_range(0.05, 1.0, 0.01) var kill_pop_animation_seconds: float = 0.24

@export_group("Opening Text")
@export_range(1.0, 120.0, 1.0) var opening_characters_per_second: float = 22.0
@export_range(-60.0, 0.0, 1.0) var opening_text_sound_volume_db: float = -22.0
@export_range(1, 10, 1) var opening_text_sound_every_characters: int = 2
@export_range(100.0, 3000.0, 10.0) var opening_text_sound_frequency_hz: float = 760.0
@export_range(-60.0, 0.0, 1.0) var dialogue_text_blip_volume_db: float = -25.0
@export_range(120.0, 1200.0, 10.0) var dialogue_text_blip_frequency_hz: float = 420.0
@export_range(0.02, 0.08, 0.005) var dialogue_text_blip_duration: float = 0.045
@export_range(1.0, 120.0, 1.0) var results_characters_per_second: float = 22.0

@export_group("Bedroom Phone")
@export var phone_panel_width: float = 160.0
@export var phone_panel_height: float = 336.0
@export var phone_position_x: float = 20.0
@export var phone_collapsed_y: float = 319.0
@export var phone_expanded_y: float = 24.0
@export_range(0.05, 2.0, 0.05) var phone_animation_seconds: float = 0.35
@export_range(0.05, 2.0, 0.05) var phone_fingerprint_animation_seconds: float = 0.55
@export var phone_lock_on_bedroom_entry: bool = true
@export var phone_upper_collapse_height: float = 166.0
## 手机收起触发区 = 手机整体高度的顶部比例（最新规则覆盖“全背景可收”）：
## 只有顶部 1/3 的背景空白可收起，下方 2/3 完全不触发。
@export_range(0.1, 1.0, 0.01) var phone_retract_height_ratio: float = 0.333333
@export_range(8, 24, 1) var phone_app_chinese_title_font_size: int = 13
@export_range(6, 18, 1) var phone_app_english_title_font_size: int = 8
@export_range(4.0, 24.0, 1.0) var phone_app_content_margin: float = 12.0
@export_range(2.0, 20.0, 1.0) var online_message_spacing: float = 8.0
@export_range(2.0, 10.0, 0.5) var online_unread_dot_size: float = 4.0
@export var online_unread_dot_offset: Vector2 = Vector2(2.0, 0.0)
@export_range(0.0, 0.5, 0.01) var phone_app_hover_brightness: float = 0.12
@export_range(1.0, 24.0, 1.0) var phone_scroll_drag_threshold: float = 6.0
@export_range(3.0, 8.0, 1.0) var phone_scrollbar_width: float = 5.0
@export_range(3.0, 8.0, 1.0) var online_scrollbar_width: float = 5.0
@export_range(4.0, 20.0, 1.0) var online_message_right_safe_margin: float = 10.0

@export_group("Bedroom Confirmation Dialog")
@export_range(0.05, 1.0, 0.05) var dialog_animation_seconds: float = 0.22
@export var dialog_portrait_appearance_position: Vector2 = Vector2(16.0, 90.0)

@export_group("New Day Door Audio")
@export_range(0.0, 3.0, 0.05) var door_open_close_gap_seconds: float = 0.45

@export_group("Debug Console")
@export var console_panel_size: Vector2 = Vector2(520.0, 210.0)
@export_range(8, 28, 1) var console_font_size: int = 14

@export_group("Main Menu")
@export_range(4, 40, 1) var main_menu_button_spacing: int = 12
@export_range(0.0, 12.0, 0.5) var main_menu_hover_offset: float = 4.0
@export_range(1.0, 1.2, 0.01) var main_menu_hover_scale: float = 1.04
@export var main_menu_selection_padding: Vector2 = Vector2(16.0, 8.0)
@export_range(0.08, 0.4, 0.01) var main_menu_selection_tween_duration: float = 0.18
@export var main_menu_selection_fill_color: Color = Color(0.055, 0.12, 0.13, 0.58)
@export var main_menu_selection_border_color: Color = Color(0.216, 0.298, 0.302, 0.92)
@export var game_version_text: String = "V0.5.0"
# Release labels do not invalidate otherwise-compatible progression saves.
@export var save_compatibility_version: String = "V0.4.7"
@export var community_group_text: String = "游戏存活进度群:833796070"
@export var community_group_url: String = "https://qm.qq.com/q/Mq3wuCuZQ6"

@export_group("Pixel Options")
## 普通文本Action共用：每个Option Group只绘制一个共享选框和一个像素三角。
@export_range(1.0, 1.2, 0.01) var option_hover_scale: float = 1.04
@export var option_frame_padding: Vector2 = Vector2(14.0, 6.0)
@export_range(5.0, 8.0, 1.0) var option_triangle_size: float = 6.0
@export_range(6.0, 10.0, 1.0) var option_triangle_text_gap: float = 8.0
@export_range(2.0, 4.0, 0.5) var option_triangle_animation_amplitude: float = 3.0
@export_range(0.45, 0.8, 0.05) var option_triangle_animation_period: float = 0.60
@export_range(0.08, 0.4, 0.01) var option_hover_tween_duration: float = 0.12
@export var option_frame_fill_color: Color = Color(0.223529, 0.435294, 0.886275, 1.0)
@export var option_triangle_color: Color = Color(0.223529, 0.435294, 0.886275, 1.0)

@export_group("Pixel UI")
@export var ui_border_color: Color = Color("517b98")
@export var ui_panel_background_color: Color = Color("121722")
@export var ui_card_size: Vector2 = Vector2(184.0, 190.0)
@export_range(0.0, 0.5, 0.01) var ui_hover_brightness: float = 0.10

@export_group("Bedroom Mouse Interaction")
@export var bedroom_interaction_outline_color: Color = Color.WHITE
@export_range(1.0, 8.0, 0.5) var bedroom_interaction_outline_width: float = 2.0
@export_range(0.0, 1.0, 0.01) var bedroom_interaction_outline_opacity: float = 0.78
@export var bedroom_show_click_regions: bool = false

@export_group("Bedroom Computer")
## 电脑素材：亮屏 res://art/Badroom/bedroom_computer_light.png，息屏 res://art/Badroom/bedroom_computer_dark.png。
## 电脑界面场景：res://scenes/ui/computer_overlay.tscn（脚本 scripts/ui/computer_overlay.gd）。
## 当天状态字段：persistent_state.computer_opened_today（新的一天开始时重置为 false）。

@export_group("Phone New Message Notification")
## 以下三个旧震动参数已废弃（保留避免存档/资源报错），新实现使用下方 Phone Vibration 组。
@export_range(0.0, 8.0, 0.5) var phone_new_message_vibrate_amplitude: float = 3.0
@export_range(1, 6, 1) var phone_new_message_vibrate_cycles: int = 3
@export_range(0.2, 2.0, 0.05) var phone_new_message_vibrate_seconds: float = 0.75

@export_group("Phone Vibration")
## 快速短促“嗡嗡”震动（bedroom_phone.gd _play_new_message_vibrate）：
## 每轮 左→右→左→右→中，共 phone_vibration_rounds 轮，轮间停顿 pause_duration。
## 所有坐标基于 phone_rest_position 计算，震动后精确归位。
@export_range(1.0, 6.0, 0.5) var phone_vibration_offset_px: float = 3.0
@export_range(0.02, 0.2, 0.005) var phone_vibration_step_duration: float = 0.05
@export_range(0.0, 0.5, 0.01) var phone_vibration_pause_duration: float = 0.10
@export_range(1, 4, 1) var phone_vibration_rounds: int = 2

@export_group("Bedroom Lighting")
## 卧室基础环境光（CanvasModulate）：整体压暗并偏冷色，光源会把局部照亮。
## 节点路径：卧室场景 Layout/BedroomLighting/{CanvasModulate, ComputerScreenLight}。
## 窗户光照系统（WindowLight / CurtainLightOccluder / 时间驱动窗光）已彻底废弃删除，
## 卧室唯一的动态光源是电脑屏幕光；遮阳帘不再影响任何光照。
## 重要：点光必须使用 Mix 混合（Add 混合在本渲染环境会把照射区渲染成黑色）。
@export var bedroom_ambient_modulate_color: Color = Color(0.82, 0.84, 0.92)
## 电脑屏幕发光：冷蓝/青白，只照亮电脑附近小范围；仅亮屏状态可见
## （由 bedroom.gd _sync_computer_visual 控制开关）。
@export_range(0.0, 3.0, 0.05) var bedroom_computer_light_energy: float = 1.15
@export var bedroom_computer_light_color: Color = Color(0.62, 0.86, 0.95)
## 电脑光整体增强倍率：最终 energy = bedroom_computer_light_energy × 本倍率，
## 只在 _setup_lighting 一处乘算，不在其它位置重复叠加。
@export_range(0.5, 4.0, 0.1) var computer_light_energy_multiplier: float = 2.0

@export_group("Bedroom Vignette")
## 21:00→00:00 动态像素暗角（shaders/bedroom_vignette.gdshader，bedroom.gd _update_vignette）：
## 用卧室游戏时间驱动，Ease-In 曲线，只覆盖卧室主画布，不影响手机/HUD/弹窗 UI。
## 1260 = 21:00，1440 = 00:00（强制睡觉时间）；跨午夜按夜间分钟归一化。
## 强度不设置任何人为上限（旧 bedroom_vignette_max_strength / bedroom_vignette_safe_max 已删除）：
## final = (min_strength + progress²) × 倍率，progress 允许超过 1（Debug 超时继续增长），由 GPU 自然限制输出。
@export var bedroom_vignette_start_minutes: float = 1260.0
@export var bedroom_vignette_end_minutes: float = 1440.0
@export_range(0.0, 1.0, 0.01) var bedroom_vignette_min_strength: float = 0.10
## 暗角整体强度倍率：final = (min + progress²) × 倍率；只在 _update_vignette 一处乘算。
@export_range(0.5, 4.0, 0.1) var vignette_intensity_multiplier: float = 2.0

@export_group("Bedroom Door")
## BottomEdgeInteraction：底部交互横带高度（原左侧白光已移到底部）。
@export_range(16.0, 120.0, 1.0) var bottom_edge_interaction_height: float = 60.0
## 底部交互的水平范围：交互区中心 x = 280px（视口 640），宽度保持中间三分之一。
@export_range(0.0, 1.0, 0.0001) var bottom_interaction_horizontal_start_ratio: float = 0.270833
@export_range(0.0, 1.0, 0.0001) var bottom_interaction_horizontal_end_ratio: float = 0.604167
@export_range(0.0, 1.0, 0.01) var door_glow_opacity: float = 0.32
@export_range(0.02, 2.0, 0.01) var door_glow_fade_in_seconds: float = 0.16
@export_range(0.02, 2.0, 0.01) var door_glow_fade_out_seconds: float = 0.24
@export_range(1.0, 3.0, 0.05) var door_waiting_glow_multiplier: float = 1.55
## 半圆白光的像素风距离量化步长（像素）：同心环宽度，<=0 不量化；不可过强。
@export_range(0.0, 12.0, 1.0) var door_glow_pixel_step_size: float = 4.0
## 半圆白光几何：水平直径 = 视口宽 × width_ratio，圆心 x = 视口宽 × center_x_ratio，
## 底边贴屏幕底；0.59375 即视口 640 下宽 380px，圆心仍在屏幕水平中央。
@export_range(0.05, 1.0, 0.0001) var bottom_glow_width_ratio: float = 0.59375
@export_range(0.0, 1.0, 0.0001) var bottom_glow_center_x_ratio: float = 0.5
## 半圆光效高度 = 水平半径 × 本倍率；只向上变化，水平宽度由 width_ratio 单独控制。
## 0.631579 即视口 640 下半径 190px、高度 120px 的椭圆半光。
@export_range(0.1, 4.0, 0.0001) var bottom_glow_height_multiplier: float = 0.631579
## 有人敲门时底部朝下箭头的往返位移（整数像素）与单次往返周期。
@export_range(1.0, 12.0, 1.0) var delivery_arrow_bounce_distance_px: float = 5.0
@export_range(0.2, 2.0, 0.05) var delivery_arrow_bounce_duration: float = 0.65

@export_group("Dream Map")
## 梦境战斗地图（Crawling Depths 16×16 Tileset，docs/THIRD_PARTY_ASSETS.md 署名）。
## 可探索面积目标 = 旧竞技场（580×258）× dream_map_area_multiplier，
## 长宽各 ×sqrt(倍率) 保持长宽比；实际网格按 Tile 整数取整（见 dream_map_builder.gd）。
@export_range(1.0, 9.0, 0.1) var dream_map_area_multiplier: float = 3.0
@export_range(8, 64, 1) var dream_tileset_base_tile_size: int = 16

@export_group("Cheap Meal Delivery")
@export var cheap_meal_price: int = 200
@export_range(0.1, 120.0, 0.1) var cheap_meal_delivery_seconds: float = 5.0
@export_range(1, 10, 1) var cheap_meal_daily_purchase_limit: int = 1

@export_group("Bedroom Sunshade")
@export var sunshade_price: int = 1000
## 环境音音量降幅（遮阳帘放下时）。1.0 = 不降，0.5 = 降 50%。
@export_range(0.0, 1.0, 0.01) var sunshade_ambient_volume_multiplier: float = 0.5
## 遮阳帘放下 → 唤醒时白色曝光额外压低的乘数（0 = 完全抑制）。
@export_range(0.0, 1.0, 0.01) var sunshade_alarm_brightness_multiplier: float = 0.0

@export_group("Hunger")
@export_range(0.05, 1.0, 0.05) var hungry_damage_multiplier: float = 0.5
@export_range(1, 10, 1) var hungry_bed_attempts_before_force: int = 2
@export_range(0, 10000, 1) var hungry_bed_direct_sleep_balance_threshold: int = 200
@export_range(1, 30, 1) var starvation_ending_required_days: int = 4

@export_group("Stress")
@export_range(0, 100, 1) var stress_default: int = 0
@export_range(1, 100, 1) var stress_max: int = 100
@export var stress_hungry_sleep_gain: int = 10
@export var stress_late_gain: int = 10
@export var stress_absent_gain: int = 30
@export var stress_food_reduction: int = 10
@export var stress_melatonin_reduction: int = 5
@export_range(0, 180, 1) var early_wake_stress_start_before_alarm_minutes: int = 30
@export_range(1, 180, 1) var early_wake_stress_block_minutes: int = 30
@export_range(0, 20, 1) var early_wake_stress_gain_per_block: int = 2
@export_range(0, 100, 1) var early_wake_stress_max_gain: int = 10
@export_range(1, 99, 1) var stress_threshold_spawn: int = 30
@export_range(1, 99, 1) var stress_threshold_speed: int = 50
@export_range(1, 99, 1) var stress_threshold_vision: int = 70
## 压力三档像素表情阈值（bedroom_status_hud.gd update_stress_face）：
## <= happy_max 开心；< sweat_min 一般；>= sweat_min 流汗。
@export_range(0, 99, 1) var stress_face_happy_max: int = 30
@export_range(1, 100, 1) var stress_face_sweat_min: int = 70
@export_range(1.0, 5.0, 0.1) var stress_spawn_multiplier_over_30: float = 1.5
@export_range(1.0, 5.0, 0.1) var stress_spawn_multiplier_over_50: float = 2.0
@export_range(1.0, 5.0, 0.1) var stress_spawn_multiplier_over_70: float = 2.5
@export_range(1.0, 4.0, 0.1) var stress_enemy_speed_multiplier_over_50: float = 1.5
@export_range(1.0, 4.0, 0.1) var stress_enemy_speed_multiplier_over_70: float = 1.5
@export_range(1, 100, 1) var stress_unemployment_threshold: int = 90
@export_range(1, 14, 1) var stress_unemployment_required_days: int = 3

@export_group("Sunday Events")
@export var sunday_event_probabilities: PackedFloat32Array = PackedFloat32Array([0.05, 0.05, 0.05, 0.05, 0.80])
@export var sunday_event_balance_deltas: PackedInt32Array = PackedInt32Array([200, -500, 1000, -300, 0])

@export_group("Bedroom Weather")
@export var weather_types: PackedStringArray = PackedStringArray(["rain", "thunder", "wind", "stars", "overcast"])
@export var weather_probabilities: PackedFloat32Array = PackedFloat32Array([0.2, 0.2, 0.2, 0.2, 0.2])
@export_range(1.0, 30.0, 0.5) var weather_thunder_min_interval: float = 6.0
@export_range(1.0, 60.0, 0.5) var weather_thunder_max_interval: float = 14.0
@export_range(0.0, 1.0, 0.01) var weather_opacity: float = 0.50
@export_range(0.1, 8.0, 0.1) var weather_animation_speed: float = 1.0
## Total rain streak particles across all parallax layers.
@export_range(20, 300, 10) var weather_rain_particle_count: int = 90
## Opacity of the bottom atmospheric fog gradient.
@export_range(0.0, 1.0, 0.01) var weather_fog_opacity: float = 0.32
## How strongly each weather type tints the full-screen overlay.
@export_range(0.0, 1.0, 0.01) var weather_tint_intensity: float = 0.35
## Number of rain splash marks that pulse at the bottom edge.
@export_range(0, 40, 1) var weather_splash_count: int = 14
## 是否播放雷声环境音效（闪电视觉不受影响）。
@export var weather_thunder_sfx_enabled: bool = false
## Opacity multiplier for the foreground rain overlay (close-to-camera layer).
@export_range(0.0, 1.0, 0.01) var weather_foreground_rain_opacity: float = 0.30

@export_group("Audio Transitions")
@export_range(0.0, 3.0, 0.05) var music_fade_duration: float = 0.5
@export_range(0.0, 3.0, 0.05) var ambience_fade_duration: float = 0.5
@export_range(-24.0, 0.0, 0.5) var upgrade_music_duck_db: float = -6.0
@export_range(0.0, 1.0, 0.01) var upgrade_music_duck_fade_duration: float = 0.15
## 暂停时背景音乐的低通截止频率（越低越朦胧、越像隔着墙听）。
@export_range(200.0, 4000.0, 50.0) var music_muffled_cutoff_hz: float = 700.0
## 暂停/恢复时低通效果的渐变时长（暂停中仍会渐变）。
@export_range(0.0, 1.5, 0.05) var music_muffled_fade_seconds: float = 0.5
## 关卡结束战斗音乐收尾样式: "both"(黑胶断电+爵士鼓收尾), "rimshot"(直接切断+爵士鼓收尾), "tape_stop"(0.3秒磁带停转入死寂)
@export_enum("both", "rimshot", "tape_stop") var combat_finish_style: String = "both"
## 音乐基准输出衰减（dB），默认 -6.0dB，避免音乐压过枪炮与战斗打击。
@export_range(-24.0, 0.0, 0.5) var music_baseline_volume_db: float = -6.0
## 战斗交火动态闪避深度（dB），开火/击中时压低战斗音乐音量（默认 -7.0dB）。
@export_range(-24.0, 0.0, 0.5) var combat_duck_db: float = -7.0
## 战斗交火动态闪避持续 Hold 时间（秒），连续交火会自动刷新该窗口。
@export_range(0.1, 3.0, 0.05) var combat_duck_hold_duration: float = 0.8
## 战斗交火动态闪避释放渐变恢复时间（秒）。
@export_range(0.05, 1.5, 0.05) var combat_duck_release_duration: float = 0.5
## 玩家死亡时磁带停转时长（秒）。
@export_range(0.1, 1.5, 0.05) var player_death_tape_stop_seconds: float = 0.4

@export_group("Experience Bar")
@export_range(12.0, 48.0, 1.0) var experience_bar_height: float = 24.0
@export_range(4.0, 40.0, 1.0) var experience_bar_margin: float = 14.0
@export_range(1.0, 30.0, 0.5) var experience_bar_fill_animation_speed: float = 9.0
@export_range(0.5, 1.0, 0.01) var experience_bar_near_level_threshold: float = 0.8

@export_group("Imported SFX")
@export_range(-60.0, 6.0, 1.0) var sfx_forbidden_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_death_volume_db: float = -8.0
@export_range(-60.0, 6.0, 1.0) var sfx_new_message_volume_db: float = -12.0
@export_range(-60.0, 6.0, 1.0) var sfx_purchase_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_home_door_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_work_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_confirm_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_experience_volume_db: float = -16.0
@export_range(0.02, 1.0, 0.01) var sfx_experience_min_interval: float = 0.08
@export_range(-60.0, 6.0, 1.0) var sfx_phone_unlock_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_phone_operation_volume_db: float = -16.0
@export_range(-60.0, 6.0, 1.0) var sfx_bottle_shake_volume_db: float = -12.0
@export_range(0.02, 1.0, 0.01) var sfx_bottle_shake_min_interval: float = 0.10
@export_range(-60.0, 6.0, 1.0) var sfx_canned_laughter_volume_db: float = -6.0
@export_range(-60.0, 6.0, 1.0) var sfx_audience_applause_volume_db: float = -6.0
@export_range(-60.0, 6.0, 1.0) var sfx_golf_clap_volume_db: float = -6.0
@export_range(-60.0, 6.0, 1.0) var sfx_rimshot_volume_db: float = -4.0
## 下列事件使用集中生成的原创8-bit占位声，可随时在SFXManager中替换为导入资源。
@export_range(-60.0, 6.0, 1.0) var sfx_ui_hover_volume_db: float = -27.0
@export_range(80.0, 1000.0, 10.0) var sfx_ui_hover_tone_hz: float = 260.0
@export_range(-60.0, 6.0, 1.0) var sfx_dash_volume_db: float = -12.0
@export_range(-60.0, 6.0, 1.0) var sfx_player_hurt_volume_db: float = -12.0
@export_range(-60.0, 6.0, 1.0) var sfx_heal_volume_db: float = -8.0
@export_range(-60.0, 6.0, 1.0) var sfx_weapon_fire_volume_db: float = -17.0
@export_range(-60.0, 6.0, 1.0) var sfx_weapon_reload_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_weapon_pickup_volume_db: float = -12.0
@export_range(-60.0, 6.0, 1.0) var sfx_weapon_throw_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_weapon_dry_fire_volume_db: float = -16.0
@export_range(-60.0, 6.0, 1.0) var sfx_pistol_fire_volume_db: float = -20.0
@export_range(-60.0, 6.0, 1.0) var sfx_shotgun_fire_volume_db: float = -16.0
@export_range(400.0, 10000.0, 50.0) var sfx_weapon_lowpass_cutoff_hz: float = 3400.0
@export_range(-60.0, 6.0, 1.0) var sfx_enemy_kill_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_enemy_hit_volume_db: float = -20.0
## 近战命中敌人的专用音量；与通用 enemy_hit 反馈分开，避免战斗命中过轻。
@export_range(-60.0, 6.0, 1.0) var sfx_melee_hit_enemy_volume_db: float = -14.0
## 弹丸命中敌人的专用音量；与通用 enemy_hit 反馈分开。
@export_range(-60.0, 6.0, 1.0) var sfx_bullet_hit_enemy_volume_db: float = -14.0
## 近战命中家具的专用音量；与通用 furniture_impact 反馈分开。
@export_range(-60.0, 6.0, 1.0) var sfx_melee_hit_furniture_volume_db: float = -11.0
@export_range(-60.0, 6.0, 1.0) var sfx_body_impact_volume_db: float = -20.0
@export_range(-60.0, 6.0, 1.0) var sfx_wall_impact_volume_db: float = -18.0
@export_range(-60.0, 6.0, 1.0) var sfx_furniture_impact_volume_db: float = -17.0
@export_range(-60.0, 6.0, 1.0) var sfx_melee_swing_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_door_knock_volume_db: float = -13.0
@export_range(-60.0, 6.0, 1.0) var sfx_thunder_volume_db: float = -18.0
## 临时程序化 buzz 占位音量（待人工替换 res://sfx/手机震动.wav）。
@export_range(-60.0, 6.0, 1.0) var sfx_phone_buzz_volume_db: float = -18.0

@export_group("Pause Menus")
@export var tab_menu_pauses_tree: bool = true

@export_group("Bedroom Time")
@export var bedroom_start_minutes: float = 1260.0
@export var bedroom_force_sleep_minutes: float = 1440.0
@export var bedroom_real_seconds_per_game_minute: float = 1.0

@export_group("Week")
## 剧情模式每天统一06:00起床；出勤/工资阈值仍由RunSettlement单独维护。
@export var story_wake_minutes: float = 360.0
@export var weekday_alarm_minutes: float = 360.0
@export var sunday_alarm_minutes: float = 360.0

@export_group("Death Wake Delay")
@export var death_wake_delay_min_minutes: int = 30
@export var death_wake_delay_max_minutes: int = 90

@export_group("Death CRT Effect")
## 角色死亡时报错与关机动画的总时长（秒）。
@export_range(0.2, 5.0, 0.05) var death_crt_effect_seconds: float = 2.45
## 角色坠亡时触发威廉尖叫彩蛋的概率（默认 2% = 0.02）。
@export_range(0.0, 1.0, 0.01) var wilhelm_scream_easter_egg_chance: float = 0.02

@export_group("Economy")
@export var initial_balance: int = 1325
@export var daily_base_wage: int = 500
@export_range(0, 100, 1) var ram_per_completed_day: int = 1
@export var wage_ratio_on_time: float = 1.0
@export var wage_ratio_slightly_late: float = 0.8
@export var wage_ratio_severely_late: float = 0.5
@export var wage_ratio_absent: float = 0.0

@export_group("Melatonin")
@export var melatonin_price: int = 100
@export var melatonin_inventory_cap: int = 99
@export var melatonin_shake_window_seconds: float = 1.2
@export var melatonin_required_shake_distance: float = 260.0
@export var melatonin_required_reversals: int = 4
@export var melatonin_shake_segment_min_distance: float = 24.0
@export var melatonin_required_shakes: int = 4
## Manual mouse-shake thresholds. Progress is counted only while left mouse is held.
@export_range(20.0, 2000.0, 10.0) var melatonin_shake_distance_required: float = 260.0
@export_range(10.0, 4000.0, 10.0) var melatonin_shake_velocity_threshold: float = 180.0
@export_range(1, 20, 1) var melatonin_shake_direction_changes_required: int = 4
@export var melatonin_bottle_rotation_degrees: float = 18.0
@export var melatonin_nightly_use_limit: int = 3
@export_range(0.0, 240.0, 1.0) var melatonin_minutes_earlier_per_tablet: float = 30.0
@export var melatonin_consume_hand_approach_seconds: float = 0.65
@export var melatonin_hand_reach_seconds: float = 0.45
@export var melatonin_pill_throw_seconds: float = 0.42
@export var melatonin_consume_hand_max_scale: float = 2.2
@export var melatonin_consume_vignette_alpha: float = 0.48
@export var melatonin_consume_pre_swallow_pause: float = 0.18
@export var melatonin_consume_end_pause: float = 0.3
@export var melatonin_swallow_sound_volume_db: float = -16.0

@export_group("Permanent Upgrades")
@export var permanent_upgrade_prices: PackedInt32Array = PackedInt32Array([1, 3, 5, 8, 10])
@export var permanent_upgrade_max_level: int = 5
@export var visual_cortex_range_per_level: float = 50.0
@export var hippocampus_health_per_level: float = 20.0
@export var prefrontal_attack_speed_per_level: float = 0.2

@export_group("Upgrade Rarity")
@export var rarity_blue_probability: float = 0.88
@export var rarity_purple_probability: float = 0.10
@export var rarity_gold_probability: float = 0.02
@export var rarity_reroll_attempts: int = 10
## 三列每次打开都从起始速度按同一条Ease-In曲线加速至各自上限。
@export var upgrade_reel_start_speeds: Vector3 = Vector3(84.0, 92.0, 78.0)
@export var upgrade_reel_max_speeds: Vector3 = Vector3(440.0, 472.0, 416.0)
@export_range(0.1, 4.0, 0.05) var upgrade_reel_acceleration_duration: float = 1.35
@export var upgrade_reel_acceleration_curve: Curve
@export_range(0.05, 0.5, 0.01) var upgrade_slot_lock_deceleration: float = 0.16
@export_range(0.2, 2.0, 0.05) var upgrade_jackpot_feedback_seconds: float = 0.7
@export_range(-60.0, 0.0, 1.0) var sfx_slot_tick_volume_db: float = -28.0
@export_range(0.0, 0.2, 0.005) var sfx_slot_tick_min_interval: float = 0.025
## Soft mechanical watch click for option hover (menus / settings rows / controls).
@export_range(-60.0, 0.0, 1.0) var sfx_watch_tick_volume_db: float = -8.0
@export_range(0.0, 0.2, 0.005) var sfx_watch_tick_min_interval: float = 0.03
## Early (pre-soften) brighter watch click for volume slider drag (~1.7kHz, not slot_tick).
@export_range(-60.0, 0.0, 1.0) var sfx_watch_tick_early_volume_db: float = -8.0
@export_range(0.0, 0.2, 0.005) var sfx_watch_tick_early_min_interval: float = 0.03
@export_range(0.0, 1.0, 0.01) var upgrade_crt_scanline_strength: float = 0.10
@export_range(0.0, 1.0, 0.01) var upgrade_crt_noise_strength: float = 0.025
@export_range(0.0, 1.0, 0.01) var upgrade_crt_vignette_strength: float = 0.14
@export_range(0.2, 1.0, 0.05) var upgrade_panel_enter_seconds: float = 0.42
@export_range(0.15, 0.8, 0.05) var upgrade_panel_exit_seconds: float = 0.32
@export_range(0.1, 0.4, 0.05) var upgrade_reward_confirm_seconds: float = 0.20
@export_range(0, 3, 1) var slot_rerolls_per_run: int = 1

@export_group("Computer Blackjack")
@export var blackjack_chip_values: PackedInt32Array = PackedInt32Array([10, 50, 100, 500])
@export_range(1, 1000, 1) var blackjack_dealer_stand_value: int = 17
@export_range(1.0, 3.0, 0.5) var blackjack_natural_payout_ratio: float = 1.5

@export_group("Endings")
@export_range(1, 365, 1) var normal_life_ending_required_workdays: int = 14
## Strict workday death cutoff. 360 minutes equals 06:00.
@export_range(0, 1439, 1) var early_nightmare_death_cutoff_minutes: int = 360

@export_group("Run Skills")
@export var normal_upgrade_max_level: int = 99
@export var normal_attack_speed_upgrade_multiplier: float = 1.15
@export var normal_range_upgrade_pixels: float = 35.0
@export var sleep_paralysis_blue_still_seconds: float = 10.0
@export var sleep_paralysis_blue_heal_per_second: float = 5.0
@export var sleep_paralysis_purple_still_seconds: float = 8.0
@export var sleep_paralysis_purple_heal_per_second: float = 10.0
@export var sleep_paralysis_gold_still_seconds: float = 8.0
@export var sleep_paralysis_gold_heal_per_second: float = 15.0
@export var sleep_spindle_blue_interval: float = 30.0
@export var sleep_spindle_purple_interval: float = 20.0
@export var sleep_spindle_gold_interval: float = 10.0
@export var sleep_spindle_max_layers: int = 1
@export var hypnic_jerk_max_bonus_charges: int = 2
@export var dash_max_charges: int = 3
@export var consciousness_drift_chance_per_level: float = 0.5
@export var consciousness_drift_extra_delay: float = 0.08
@export var consciousness_drift_max_level: int = 2
@export var rapid_eye_slow_multiplier: float = 0.7
@export var rapid_eye_duration_seconds: float = 5.0
@export var rapid_eye_max_acquisitions: int = 1
@export var dissociation_revive_health: float = 30.0
@export var dissociation_invulnerability_seconds: float = 3.0
@export var dissociation_max_acquisitions: int = 1
@export_group("Bedroom Character Glow")
@export var bedroom_chr_glow_enabled: bool = true
@export var bedroom_chr_glow_color: Color = Color("dceeff")
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_alpha_normal_min: float = 0.68
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_alpha_normal_max: float = 0.86
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_alpha_dark_min: float = 0.55
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_alpha_dark_max: float = 0.68
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_alpha_bright_min: float = 0.86
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_alpha_bright_max: float = 0.95
@export_range(0.05, 1.0, 0.01) var bedroom_chr_glow_interval_min: float = 0.06
@export_range(0.05, 1.0, 0.01) var bedroom_chr_glow_interval_max: float = 0.18
@export_range(0.0, 1.0, 0.01) var bedroom_chr_glow_big_change_chance: float = 0.15

@export_range(0.0, 20.0, 0.5)
var lucille_character_hop_pixels: float = 5.0
@export_range(0.0, 20.0, 0.5)
var lucille_character_back_pixels: float = 3.0
@export_range(0.0, 20.0, 0.5)
var lucille_character_forward_pixels: float = 6.0
@export_range(0.0, 45.0, 1.0)
var lucille_character_back_lean_degrees: float = 16.0
@export_range(0.02, 0.20, 0.01)
var lucille_character_windup_seconds: float = 0.04
@export_range(0.02, 0.20, 0.01)
var lucille_character_strike_seconds: float = 0.10
@export_range(0.02, 0.30, 0.01)
var lucille_character_recover_seconds: float = 0.10

func get_kick_knockback_force() -> float:
	return gun_knockback_force * kick_knockback_multiplier


func get_lucille_knockback_force() -> float:
	return get_kick_knockback_force() * lucille_knockback_multiplier


func get_furniture_projectile_force_multiplier(weapon_id: StringName) -> float:
	match weapon_id:
		&"shotgun":
			return furniture_shotgun_pellet_force_multiplier
		&"assault_rifle":
			return furniture_assault_rifle_force_multiplier
		_:
			return furniture_pistol_force_multiplier


func weapon_interval_for_rate(base_interval: float) -> float:
	## Convert the authored seconds-per-shot value through the neutral global
	## cadence multiplier.  The default value is one, preserving the original
	## weapon fire rate while leaving this hook available for intentional tuning.
	return maxf(base_interval, 0.001) / maxf(weapon_fire_rate_multiplier, 0.001)
