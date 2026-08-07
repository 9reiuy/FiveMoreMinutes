class_name DemoConfig
extends Resource

## All vertical-slice tuning lives here so later balancing does not touch gameplay code.
@export_group("Dream Clock")
@export var dream_start_minutes: float = 240.0
@export var alarm_start_minutes: float = 420.0
@export var real_seconds_per_game_minute: float = 1.0

@export_group("Enemy Spawning")
@export var enemy_initial_spawn_interval: float = 2.0
@export var enemy_minimum_spawn_interval: float = 0.65
@export_enum("Linear") var enemy_spawn_interval_reduction_mode: String = "Linear"
## 每个生成周期独立尝试批次数量；合法点不足时生成器允许少生成。
@export var maximum_enemies: int = 110
@export var enemy_spawn_count_per_interval: int = 2
@export var base_enemy_health: float = 18.0
@export var base_enemy_damage: float = 8.0
@export var base_enemy_movement_speed: float = 42.0
@export var enemy_health_growth_per_second: float = 0.018
@export var enemy_damage_growth_per_second: float = 0.012
@export var enemy_minimum_spawn_distance: float = 150.0
@export var enemy_spawn_minimum_spacing: float = 30.0
@export var enemy_spawn_position_max_retries: int = 12
## 屏幕外生成安全边距：常规/触手怪必须生成在相机可见矩形外扩该边距的禁区之外。
@export_range(0.0, 200.0, 4.0) var enemy_spawn_visibility_margin: float = 64.0
@export var enemy_separation_strength: float = 24.0
@export var enemy_separation_radius: float = 30.0
## 压力倍率作用在现有难度曲线之后，但不会突破这个硬下限。
@export_range(0.05, 2.0, 0.05) var stress_absolute_minimum_spawn_interval: float = 0.25
@export var correction_unlock_seconds: float = 30.0
@export var stapler_unlock_seconds: float = 90.0
@export var large_correction_unlock_seconds: float = 180.0
@export var alarm_enemy_unlock_time: float = 120.0
@export var mailbox_enemy_unlock_time: float = 180.0

@export_group("Interaction Highlight")
@export var interaction_outline_color: Color = Color.WHITE
@export var interaction_outline_width: float = 2.0

@export_group("Player Damage Feedback")
## Spawn protection uses the same central player damage gate as hurt and dash invulnerability.
@export_range(0.0, 10.0, 0.1) var player_spawn_invulnerability_duration: float = 3.0
@export var hurt_invulnerability_seconds: float = 0.55
@export var hurt_flash_frequency: float = 12.0
@export var hurt_flash_seconds: float = 0.18
@export var hurt_shake_pixels: float = 2.0
@export_range(0.0, 1.0, 0.01) var player_hurt_screen_flash_alpha: float = 0.24
@export_range(0.01, 0.5, 0.01) var player_hurt_screen_flash_seconds: float = 0.12

@export_group("Alarm Visuals")
@export_range(0.0, 0.75, 0.01) var alarm_screen_brightness_alpha: float = 0.30
@export_range(0.0, 120.0, 1.0) var alarm_eyelid_max_height: float = 42.0
@export_range(0.1, 180.0, 0.1) var alarm_visual_ramp_seconds: float = 45.0

@export_group("Wake Up")
@export var base_wake_hold_seconds: float = 5.0
@export var extra_hold_every_seconds: float = 10.0
@export var extra_hold_seconds: float = 2.0
@export var wake_progress_regress_per_second: float = 2.0
@export_range(0.05, 1.0, 0.05) var bullet_time_scale: float = 0.20
@export var wake_interaction_radius: float = 58.0

@export_group("Progression")
@export var first_level_experience_requirement: int = 20
@export var experience_growth_base: int = 8
@export var experience_requirement_cap: int = 32767
@export var damage_upgrade_multiplier: float = 1.5

@export_group("Pixel Art and Effects")
## 玩家图集缩放：0.75 = 视觉与身体碰撞缩到 75%（只在 VisualRoot 一处应用，
## 禁止根节点与 Sprite 重复缩放）。
@export_range(0.25, 4.0, 0.05) var player_sprite_scale: float = 0.75
@export_range(0.5, 8.0, 0.5) var player_idle_animation_fps: float = 1.0
@export_range(2.0, 16.0, 0.5) var player_walk_animation_fps: float = 7.0
@export_range(0.02, 0.3, 0.01) var weapon_muzzle_flash_seconds: float = 0.07
@export_range(0.04, 0.5, 0.01) var weapon_hit_effect_seconds: float = 0.14
@export_range(2.0, 32.0, 1.0) var projectile_trail_length: float = 10.0
@export_range(0.05, 0.6, 0.01) var beam_charge_seconds: float = 0.18
@export_range(0.05, 0.6, 0.01) var katana_afterimage_seconds: float = 0.20
@export var weapon_effect_primary_color: Color = Color("517b98")
@export var weapon_effect_secondary_color: Color = Color("9ab6c8")
@export var weapon_effect_warning_color: Color = Color("9b4658")

@export_group("Weapons")
## 玩家和武器基础数值统一由本资源提供，场景脚本只维护运行时强化结果。
@export var player_base_maximum_health: float = 100.0
@export var player_movement_speed: float = 112.0
@export var basic_weapon_damage: float = 10.0
@export var basic_weapon_attack_interval: float = 0.30
@export var basic_weapon_range: float = 270.0
@export var basic_projectile_speed: float = 310.0
@export var beam_damage: float = 20.0
@export var beam_attack_interval: float = 2.0
@export var beam_range: float = 150.0
@export var beam_width: float = 12.0
@export var beam_display_seconds: float = 0.15
@export var shotgun_pellet_count: int = 9
@export var shotgun_pellet_damage: float = 3.0
@export var shotgun_attack_interval: float = 0.8
@export var shotgun_spread_degrees: float = 30.0
@export var shotgun_projectile_speed: float = 310.0
@export var shotgun_max_distance: float = 270.0
@export var shotgun_recoil_multiplier: float = 1.8
@export var katana_attack_interval: float = 2.0
@export var katana_melee_damage: float = 30.0
@export var katana_melee_radius: float = 50.0
@export var katana_wave_damage: float = 10.0
@export var katana_wave_speed: float = 450.0
@export var katana_wave_max_distance: float = 300.0
## 宽度同时驱动视觉线段、碰撞形状与手动扫掠命中半径。
@export var katana_wave_width: float = 32.0
## Curve只改变沿固定直线方向的速度进度，并使用受暂停/慢动作影响的游戏时间。
@export_range(0.1, 1.0, 0.01) var katana_wave_initial_speed_ratio: float = 0.35
@export_range(0.05, 0.8, 0.01) var katana_wave_acceleration_duration: float = 0.25
@export var katana_wave_acceleration_curve: Curve
## SP301_04 月牙素材自身默认朝向（尖端朝 -x）与飞行方向（+x）的补偿角：
## 最终 rotation = aim_direction.angle() + deg_to_rad(本值)，使视觉尖端/碰撞/运动三者一致。
@export_range(-180.0, 180.0, 1.0) var katana_wave_texture_forward_angle_deg: float = 180.0
## 榴弹出生点沿瞄准方向偏移的像素数，保证出生在当前玩家碰撞体外侧。
@export_range(0.0, 64.0, 1.0) var grenade_spawn_offset_px: float = 14.0
@export var grenade_attack_interval: float = 3.0
@export var grenade_projectile_speed: float = 300.0
@export var grenade_explosion_radius: float = 150.0
## Visual radius is independent from damage radius so presentation cannot alter gameplay.
@export var grenade_explosion_visual_radius: float = 150.0
@export var grenade_enemy_damage: float = 30.0
@export var grenade_player_self_damage: float = 10.0

@export_group("Critical Hits")
@export_range(0.0, 1.0, 0.01) var player_base_critical_chance: float = 0.10
@export_range(1.0, 5.0, 0.05) var player_critical_damage_multiplier: float = 1.50

@export_group("Dash")
@export var dash_distance: float = 100.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 2.0
@export var dash_invulnerability_seconds: float = 0.18

@export_group("Aim")
## 梦游模式是玩家设置；此字段仅提供首次启动时的默认值。
@export var sleepwalk_mode_default: bool = false
## 0表示不限制搜索半径；默认值覆盖完整梦境场地。
@export_range(0.0, 4000.0, 10.0) var auto_aim_search_radius: float = 900.0
@export_range(0.02, 1.0, 0.01) var auto_aim_refresh_interval: float = 0.08
@export var crosshair_cooldown_color: Color = Color(0.35, 0.36, 0.4, 1.0)
@export var crosshair_ready_color: Color = Color.WHITE
@export var crosshair_color_lerp_speed: float = 10.0
@export var crosshair_recoil_pixels: float = 5.0
@export var crosshair_recoil_recovery_seconds: float = 0.12
@export var basic_weapon_recoil_multiplier: float = 1.0
@export var beam_weapon_recoil_multiplier: float = 1.5

@export_group("Correction Tape Enemy")
@export var correction_trigger_distance: float = 150.0
@export var correction_charge_seconds: float = 0.75
@export var correction_dash_distance: float = 200.0
@export var correction_dash_speed: float = 360.0
@export var correction_dash_damage: float = 18.0
@export var correction_recovery_seconds: float = 0.5
@export var correction_dash_max_seconds: float = 1.25

@export_group("Large Correction Tape Enemy")
@export var large_correction_health_multiplier: float = 10.0
@export var large_correction_size_multiplier: float = 1.8
@export var large_correction_trigger_distance: float = 150.0
@export var large_correction_charge_seconds: float = 0.75
@export var large_correction_dash_distance: float = 200.0
@export var large_correction_dash_speed: float = 360.0
@export var large_correction_dash_damage: float = 24.0
@export var large_correction_dash_count: int = 3
@export var large_correction_dash_interval: float = 0.2
@export var large_correction_recovery_seconds: float = 0.5
@export var large_correction_experience_ratio: float = 0.5
## 精英魔眼（internal_id 仍为 large_correction_tape）换用 Flying Eye 视觉后的统一缩放，
## 与普通魔眼共用描边/Hit Flash/死亡序列，数值（HP/伤害/冲刺）不变。
@export_range(0.02, 2.0, 0.01) var large_correction_visual_scale: float = 1.0

@export_group("Enemy Outline")
## 敌人被锁定/选中时的白描边宽度（源纹理像素空间，基于 TEXTURE_PIXEL_SIZE，
## 不随节点缩放放大；VisualRoot ×4 时屏幕实际观感仍为细描边）。
@export_range(0.5, 8.0, 0.5) var enemy_outline_width_px: float = 2.0

@export_group("Enemy Hit Feedback")
@export var enemy_hit_flash_color: Color = Color(1.8, 1.8, 1.8, 1.0)
@export var enemy_hit_flash_seconds: float = 0.08
@export var enemy_hit_scale_seconds: float = 0.12
@export_range(0.0, 0.5, 0.01) var enemy_hit_scale_amount: float = 0.16
@export_range(0.0, 24.0, 0.5) var enemy_hit_visual_knockback_pixels: float = 6.0
@export_range(0.01, 0.12, 0.005) var hit_stop_duration: float = 0.04
@export_range(0.01, 0.5, 0.01) var hit_stop_minimum_interval: float = 0.09
@export_range(0.01, 1.0, 0.01) var hit_stop_time_scale: float = 0.05
@export_range(0.05, 1.0, 0.01) var kill_pop_animation_seconds: float = 0.24

@export_group("Enemy Animation")
## 敌人视觉身份已替换为 Monster 素材；内部 ID 仍为 correction_tape/stapler/alarm_clock/mailbox。
@export_range(1.0, 24.0, 0.5) var slime_move_fps: float = 7.0
@export_range(1.0, 24.0, 0.5) var slime_death_fps: float = 9.0
@export_range(1.0, 24.0, 0.5) var flying_eye_move_fps: float = 9.0
@export_range(1.0, 24.0, 0.5) var flying_eye_death_fps: float = 6.0
@export_range(1.0, 24.0, 0.5) var huntress_move_fps: float = 10.0
@export_range(1.0, 24.0, 0.5) var huntress_shoot_fps: float = 12.0
@export_range(1.0, 24.0, 0.5) var huntress_death_fps: float = 8.0
@export_range(1.0, 24.0, 0.5) var mushroom_move_fps: float = 8.0
@export_range(1.0, 24.0, 0.5) var mushroom_death_fps: float = 4.0
@export_range(1.0, 24.0, 0.5) var mimic_move_fps: float = 6.0
@export_range(1.0, 24.0, 0.5) var mimic_death_fps: float = 7.0
@export_range(1.0, 24.0, 0.5) var tentacle_idle_fps: float = 3.0
@export_range(1.0, 20.0, 0.5) var large_correction_enemy_walk_animation_fps: float = 4.0
@export_range(1.0, 24.0, 0.5) var correction_charge_animation_fps: float = 8.0
@export_range(1.0, 24.0, 0.5) var large_correction_charge_animation_fps: float = 7.0
@export_range(0.1, 1.0, 0.01) var stapler_attack_windup_seconds: float = 0.35

@export_group("Enemy Visual Scale")
## 统一 visual_scale：不同画布尺寸的序列帧统一缩放到最终游戏内体型，碰撞体单独适配不随缩放变化。
## 本组保存的是绝对最终缩放（已包含 ×4 放大：旧值 0.15/0.19/0.34/0.12/0.42；触手怪 ×2：0.5→1.0），
## 运行时代码直接使用该值，不再二次乘倍率。
@export_range(0.02, 2.0, 0.01) var slime_visual_scale: float = 0.60
@export_range(0.02, 2.0, 0.01) var flying_eye_visual_scale: float = 0.76
@export_range(0.02, 2.0, 0.01) var huntress_visual_scale: float = 1.02
@export_range(0.02, 2.0, 0.01) var mushroom_visual_scale: float = 0.96
@export_range(0.02, 2.0, 0.01) var mimic_visual_scale: float = 1.68
@export_range(0.02, 2.0, 0.01) var tentacle_visual_scale: float = 1.0

@export_group("Stapler Enemy")
@export var stapler_fire_interval: float = 2.0
@export var staple_damage: float = 10.0
@export var staple_speed: float = 170.0
@export var staple_max_distance: float = 300.0
@export var staple_collision_radius: float = 5.0

@export_group("Alarm Clock Enemy")
@export var alarm_enemy_max_hp: float = 10.0
@export var alarm_enemy_contact_damage: float = 0.0
@export var alarm_enemy_movement_speed: float = 72.0
@export var alarm_enemy_trigger_distance: float = 52.0
@export var alarm_enemy_charge_seconds: float = 0.65
@export var alarm_enemy_explosion_radius: float = 50.0
@export var alarm_enemy_explosion_damage: float = 30.0
@export var alarm_enemy_death_delay: float = 1.0
@export var alarm_enemy_chain_delay: float = 0.10
@export var alarm_enemy_blue_exp_value: int = 5

@export_group("Mailbox Enemy")
@export var mailbox_enemy_max_hp: float = 100.0
@export var mailbox_enemy_contact_damage: float = 8.0
@export var mailbox_enemy_movement_speed: float = 28.0
@export var mailbox_enemy_attack_trigger_distance: float = 50.0
@export var mailbox_enemy_slam_angle: float = 30.0
@export var mailbox_enemy_slam_range: float = 200.0
@export var mailbox_enemy_slam_damage: float = 30.0
@export var mailbox_enemy_slam_windup: float = 0.8
@export var mailbox_enemy_attack_cooldown: float = 2.5
@export var mailbox_enemy_split_count: int = 3
@export var mailbox_enemy_purple_exp_value: int = 25

@export_group("Tentacle Enemy")
## 触手怪：不移动的环境型可破坏怪物，使用 Crawling Depths Tentacle 素材。
@export var tentacle_max_hp: float = 100.0
@export var tentacle_contact_damage: float = 5.0
@export var tentacle_spawn_interval: float = 30.0
@export_range(1, 10, 1) var tentacle_spawn_batch_min: int = 1
@export_range(1, 10, 1) var tentacle_spawn_batch_max: int = 5
@export_range(0, 30, 1) var tentacle_max_alive: int = 10
@export var tentacle_min_spawn_distance_from_player: float = 120.0
## 死亡掉落 1 个紫色经验球，数值沿用现有紫色经验球配置（mailbox_enemy_purple_exp_value）。
@export var tentacle_purple_exp_value: int = 25
## 触手怪死亡额外掉落的红心拾取后回复的生命值。
@export_range(1.0, 100.0, 1.0) var heart_pickup_heal_amount: float = 15.0

@export_group("Huntress Attack")
## 精灵射手（Legacy internal ID: stapler）投射物绑定到 shoot 动画的指定帧。
@export_range(0, 5, 1) var huntress_shoot_projectile_frame: int = 3
## 进入攻击状态立即 velocity=0 并暂停寻路/追踪，攻击动画完整播完才恢复移动。
@export var huntress_attack_stop_before_shot: bool = true

@export_group("Opening Text")
@export_range(1.0, 120.0, 1.0) var opening_characters_per_second: float = 22.0
@export_range(-60.0, 0.0, 1.0) var opening_text_sound_volume_db: float = -22.0
@export_range(1, 10, 1) var opening_text_sound_every_characters: int = 2
@export_range(100.0, 3000.0, 10.0) var opening_text_sound_frequency_hz: float = 760.0
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
@export var game_version_text: String = "版本号V0.4.1"
@export var community_group_text: String = "游戏存活进度群:833796070"
@export var community_group_url: String = "https://qm.qq.com/q/Mq3wuCuZQ6"

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
@export_range(50.0, 600.0, 1.0) var stress_vision_max_radius: float = 300.0
@export_range(0.0, 1.0, 0.01) var stress_vision_darkness: float = 0.94
@export_range(0.05, 1.0, 0.01) var stress_vision_edge_softness_ratio: float = 0.28
@export_range(1, 100, 1) var stress_unemployment_threshold: int = 90
@export_range(1, 14, 1) var stress_unemployment_required_days: int = 3

@export_group("Sunday Events")
@export var sunday_event_probabilities: PackedFloat32Array = PackedFloat32Array([0.05, 0.05, 0.05, 0.05, 0.80])
@export var sunday_event_texts: PackedStringArray = PackedStringArray(["出去帮做义工了", "吃了一顿大餐", "做了其他公司的外包", "感冒了...", "今天什么也没做"])
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
@export_range(-60.0, 6.0, 1.0) var sfx_laser_volume_db: float = -18.0
@export_range(-60.0, 6.0, 1.0) var sfx_home_door_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_work_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_confirm_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_experience_volume_db: float = -16.0
@export_range(0.02, 1.0, 0.01) var sfx_experience_min_interval: float = 0.08
@export_range(-60.0, 6.0, 1.0) var sfx_phone_unlock_volume_db: float = -10.0
@export_range(-60.0, 6.0, 1.0) var sfx_phone_operation_volume_db: float = -16.0
@export_range(-60.0, 6.0, 1.0) var sfx_bottle_shake_volume_db: float = -12.0
@export_range(0.02, 1.0, 0.01) var sfx_bottle_shake_min_interval: float = 0.10
## 下列事件使用集中生成的原创8-bit占位声，可随时在SFXManager中替换为导入资源。
@export_range(-60.0, 6.0, 1.0) var sfx_ui_hover_volume_db: float = -27.0
@export_range(80.0, 1000.0, 10.0) var sfx_ui_hover_tone_hz: float = 260.0
@export_range(-60.0, 6.0, 1.0) var sfx_dash_volume_db: float = -12.0
@export_range(-60.0, 6.0, 1.0) var sfx_player_hurt_volume_db: float = -12.0
@export_range(-60.0, 6.0, 1.0) var sfx_weapon_fire_volume_db: float = -17.0
@export_range(-60.0, 6.0, 1.0) var sfx_pistol_fire_volume_db: float = -20.0
@export_range(-60.0, 6.0, 1.0) var sfx_shotgun_fire_volume_db: float = -16.0
@export_range(400.0, 10000.0, 50.0) var sfx_weapon_lowpass_cutoff_hz: float = 3400.0
@export_range(-60.0, 6.0, 1.0) var sfx_enemy_kill_volume_db: float = -14.0
@export_range(-60.0, 6.0, 1.0) var sfx_door_knock_volume_db: float = -13.0
@export_range(-60.0, 6.0, 1.0) var sfx_thunder_volume_db: float = -18.0
## 临时程序化 buzz 占位音量（待人工替换 res://sfx/手机震动.wav）。
@export_range(-60.0, 6.0, 1.0) var sfx_phone_buzz_volume_db: float = -18.0

@export_group("Pause Menus")
@export var tab_menu_pauses_tree: bool = true

@export_group("Game Settings")
@export var fast_sleep_default_enabled: bool = true
@export_range(1.0, 3.0, 0.1) var fast_sleep_game_speed_multiplier: float = 1.5

@export_group("Bedroom Time")
@export var bedroom_start_minutes: float = 1260.0
@export var bedroom_force_sleep_minutes: float = 1440.0
@export var bedroom_real_seconds_per_game_minute: float = 1.0

@export_group("Week")
@export var weekday_alarm_minutes: float = 420.0
@export var sunday_alarm_minutes: float = 540.0

@export_group("Death Wake Delay")
@export var death_wake_delay_min_minutes: int = 30
@export var death_wake_delay_max_minutes: int = 90

@export_group("Death CRT Effect")
## 角色死亡时老电视关机动画的总时长（秒）。
@export_range(0.2, 2.0, 0.05) var death_crt_effect_seconds: float = 0.7

@export_group("Economy")
@export var initial_balance: int = 1325
@export var daily_base_wage: int = 500
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
@export var brainstem_experience_per_level: float = 0.2
@export var hippocampus_health_per_level: float = 20.0
@export var prefrontal_attack_speed_per_level: float = 0.2

@export_group("Upgrade Rarity")
@export var rarity_blue_probability: float = 0.88
@export var rarity_purple_probability: float = 0.10
@export var rarity_gold_probability: float = 0.02
@export var rarity_reroll_attempts: int = 10
@export_range(0, 3, 1) var upgrade_refreshes_per_level: int = 1

@export_group("Drops")
@export_range(1, 16, 1) var correction_experience_drop_count: int = 2
@export_range(1, 16, 1) var stapler_experience_drop_count: int = 3

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
