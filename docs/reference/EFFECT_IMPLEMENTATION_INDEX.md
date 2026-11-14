# FiveMinuteMore 效果实现索引

与工程根目录的术语库配套，供查找当前工程中的实现位置。整理日期为 **2026-11-12**，共 **147 项术语**。接入状态依据当前工作树的场景入口、安装调用、材质组合和开关条件核对。

## 当前状态中的关键区分

- 教程新增“深色半透明提示框”，已接入移动／镜头、翻滚、拾取和丢弃四组阶段提示，正文与本索引使用同一名称。
- 2026-11-12当前输入已解除Shift手动冲刺与T键手动慢动作，空格保留飞扑翻滚；脚本动作和演出时间控制各自保留接口。
- 共享显示默认使用原生窗口分辨率，设置中的“像素化”可以开启640×360的场景像素化。像素原画与最近邻采样是另一组概念。
- 办公材质组合当前包含材质强化、卡通分层、拉丝金属高光与受光边缘光。全局方案一／二、交叉排线、明暗交界抖动和额外家具黑描边属于历史称呼。
- 共享敌人战斗文字当前关闭普通伤害数字，保留“暴击”。12句击杀语在相邻击杀不超过3秒时累计，第4杀起每次有35%概率出现。
- 主菜单、暂停和设置的CRT效果由界面自己管理。办公世界的常驻RGB偏移与暗角属于世界后期。
- 灯管光晕、局部体积薄雾和镜头脏污是三项不同表现。0-1～0-6独立序章已显式接入共享灯具光学组件。
- 正式共享手机与独立手机精修试玩各自有入口；精修候选的参数不能直接当作正式手机参数。
- 红海局部水流有浅层流水模拟，当前血液有自己的飞溅、落地和血泊显示。

## 画面与镜头

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 2.5D 像素表现 | 共用。共用角色与3D关卡 | [dream_3d_actor_depth_bridge.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_actor_depth_bridge.gd)、[ActorDepthBridge3D.tscn](E:/GameProjects/FiveMinuteMore/scenes/dream/3d/ActorDepthBridge3D.tscn) |
| 逐面像素图集 | 共用。已批准办公家具及对应材质 | [office_approved_art.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_approved_art.gd)、[office_style_materials.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_materials.gd) |
| 纹素密度 | 共用。美术尺度约定；不等同于屏幕移动速度 | [AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md)、[demo_config.gd](E:/GameProjects/FiveMinuteMore/scripts/data/demo_config.gd) |
| 最近邻采样 | 共用。像素原画与多数像素材质；部分反射及光学缓冲有专用过滤 | [selective_pixel_preview.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd)、[AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md) |
| 像素化显示 | 可选。设置中的“像素化”；当前默认关闭，开启时使用640×360场景缓冲 | [selective_pixel_preview.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd)、[settings_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/app/settings_manager.gd) |
| 原生分辨率显示 | 共用。当前共享显示默认；逻辑UI仍以640×360排布 | [selective_pixel_preview.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd)、[settings_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/app/settings_manager.gd) |
| RGB 通道偏移 | 共用。共享办公世界后期；独立界面有各自的CRT效果 | [world_camera_finish.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/world_camera_finish.gd)、[world_camera_finish.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/world_camera_finish.gdshader) |
| 暗角 | 共用。共享办公世界后期；当前最大强度0.24 | [world_camera_finish.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/world_camera_finish.gd)、[world_camera_finish.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/world_camera_finish.gdshader) |
| 像素相机稳定 | 条件。共享显示开启像素化和相关层次开关时启用；电话、对话、死亡构图期间有保护 | [pixel_camera_stability.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/pixel_camera_stability.gd)、[selective_pixel_preview.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd) |
| 圆形虹膜转场 | 共用。共享场景遮幕和揭幕；标准模式为圆形 | [pixel_transition.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/pixel_transition.gd)、[pixel_block_transition.gdshader](E:/GameProjects/FiveMinuteMore/shaders/transitions/pixel_block_transition.gdshader) |
| 镜头冲击 | 可选。3D战斗与部分电梯效果；由“屏幕抖动”控制 | [dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd)、[settings_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/app/settings_manager.gd) |

## 材质、反射与阴影

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 材质强化 | 共用。已接入正式办公材质组合 | [office_style_materials.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_materials.gd)、[office_surface_style.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_surface_style.gd) |
| 卡通分层 | 共用。正式办公材质组合 | [office_style_composition.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_composition.gd)、[office_style_toon.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_style_toon.gdshaderinc) |
| 拉丝金属高光 | 共用。正式材质组合中的金属类表面 | [office_style_composition.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_composition.gd)、[office_style_brushed.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_style_brushed.gdshaderinc) |
| 受光边缘光 | 共用。正式办公材质组合；亮度依赖受光 | [office_style_rim.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_rim.gd)、[office_style_composition.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_composition.gd) |
| 法线细节 | 场景。已配置法线的家具、金属表面和电梯板件 | [office_style_materials.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_materials.gd)、[elevator_reference_art.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elevator_reference_art.gd) |
| 高粗糙度哑光 | 共用。办公家具、电梯及对应场景材质 | [office_style_materials.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_style_materials.gd)、[elevator_reference_art.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elevator_reference_art.gd) |
| 地面磨砂亮斑 | 共用。已配置反光的地板；强度依房型及材质变化 | [floor_reflections.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/floor_reflections.gd)、[floor_reflection_surface.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/floor_reflection_surface.gdshaderinc) |
| 地面模糊倒影 | 共用。办公共享地面反射；部分独立关卡采用自己的反射方案 | [floor_reflections.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/floor_reflections.gd)、[floor_reflection_surface.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/floor_reflection_surface.gdshaderinc) |
| 屏幕空间反射 | 场景。维修区等使用独立环境配置的场景 | [maintenance_environment.gd](E:/GameProjects/FiveMinuteMore/scripts/testing/maintenance_environment.gd) |
| 屏幕空间环境遮蔽 | 场景。维修区独立环境配置 | [maintenance_environment.gd](E:/GameProjects/FiveMinuteMore/scripts/testing/maintenance_environment.gd) |
| 自发光 | 共用。按材质配置；血迹与信号灯各有自己的发光逻辑 | [blood_lit_carrier_common.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/blood_lit_carrier_common.gdshaderinc)、[office_light_optics.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_light_optics.gd) |
| 真实动态投影 | 共用。共享3D灯光、角色影子及阴影品质设置 | [office_shadow_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_shadow_manager.gd)、[actor_volume_shadow.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/actor_volume_shadow.gd) |
| 接触阴影 | 共用。相应办公或接待区材质 | [office_contact_shadow.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_contact_shadow.gdshader)、[reception_contact_shadow.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/reception_contact_shadow.gdshader) |
| 家具柔和补光 | 共用。办公房间局部补光；跟随原有电路与遮挡条件 | [office_furniture_bounce.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_furniture_bounce.gd) |
| 窗外投光 | 场景。有外窗并接入对应光源的办公房间 | [office_shadow_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_shadow_manager.gd)、[office_night_ceiling.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_night_ceiling.gd) |
| 人物受光 | 共用。共用角色3D显示 | [dream_3d_actor_depth_bridge.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_actor_depth_bridge.gd)、[lit_pixel_carrier.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/lit_pixel_carrier.gdshader) |

## 光晕、空气与天气

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 灯管光晕 | 共用。共享办公灯具及已接入光效的0-1～0-6独立序章 | [office_light_optics.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_light_optics.gd)、[office_fixture_optics.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_fixture_optics.gdshader) |
| 局部体积薄雾 | 共用。对应灯具的局部雾体；按场景接入 | [office_light_optics.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_light_optics.gd)、[office_fixture_fog.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_fixture_fog.gdshader) |
| 镜头脏污亮斑 | 共用。共享灯具光学效果；使用已有减量后的确定性污渍遮罩 | [office_lens_dirt_mask.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_lens_dirt_mask.gd)、[office_fixture_optics.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_fixture_optics.gdshader) |
| 泛光 | 场景。红海等配置了环境Glow的场景；灯管光晕有独立实现 | [night_coast_city_cliff_sample.tscn](E:/GameProjects/FiveMinuteMore/scenes/preview/night_coast_city_cliff_sample.tscn) |
| 空气浮尘 | 共用。共用战斗场景的楼层浮尘组件 | [sample_indoor_dust.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/sample_indoor_dust.gd)、[indoor_pixel_dust.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/preview/indoor_pixel_dust.gdshader) |
| 手电筒光锥 | 条件。具备对应夜间照明功能的3D关卡；L键 | [dream_night_lighting.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_night_lighting.gd)、[game_input_actions.gd](E:/GameProjects/FiveMinuteMore/scripts/app/game_input_actions.gd) |
| 无人机探照灯 | 场景。楼外巡逻无人机 | [exterior_patrol_drone_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/exterior_patrol_drone_3d.gd)、[patrol_light_scattering.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/patrol_light_scattering.gdshader) |
| 屏幕照脸频闪 | 共用。卧室与角色玩手机表现 | [screen_glow_flicker.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/screen_glow_flicker.gd)、[player_phone_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/player_phone_presentation.gd) |
| 卧室天气覆盖 | 场景。卧室立绘场景，按天气类型选择 | [bedroom_weather.gd](E:/GameProjects/FiveMinuteMore/scripts/bedroom/bedroom_weather.gd)、[bedroom.gd](E:/GameProjects/FiveMinuteMore/scripts/bedroom/bedroom.gd) |
| 雷电闪光 | 场景。卧室雷雨天气 | [bedroom_weather.gd](E:/GameProjects/FiveMinuteMore/scripts/bedroom/bedroom_weather.gd) |

## 角色动作与移动

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 八向分件角色 | 共用。当前玩家八向原画及共用玩家场景；敌人使用自己的朝向原画 | [player_character_atlas.gd](E:/GameProjects/FiveMinuteMore/scripts/data/player_character_atlas.gd)、[dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd) |
| 连续曲线刘海 | 共用。共用玩家分件刘海 | [player_side_bangs.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/player_side_bangs.gd) |
| 环形手臂握持 | 共用。玩家及使用同一手部表现的人形敌人 | [humanoid_hand_pose.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/humanoid_hand_pose.gd)、[enemy_hand_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/enemy_hand_presentation.gd) |
| 交替挥击连招 | 共用。共用近战武器 | [lucille_weapon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/lucille_weapon.gd)、[player_hand_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/player_hand_presentation.gd) |
| 飞扑翻滚 | 共用。当前空格闪避动作 | [player_phase_dash.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/player_phase_dash.gd)、[player_dive_roll_pose.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/player_dive_roll_pose.gd) |
| 疾速残影 | 条件。接入对应残影的冲刺或翻滚阶段 | [roll_speed_trail.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/roll_speed_trail.gd)、[dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd) |
| 自动翻越 | 可选。辅助功能“自动跳跃”及对应低矮道具 | [dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd)、[settings_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/app/settings_manager.gd) |
| 玩手机姿态 | 共用。3D场景Tab手机 | [player_phone_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/player_phone_presentation.gd)、[game_phone.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/game_phone.gd) |
| 脚步烟雾 | 共用。共用玩家与人形敌人脚步烟雾；按实际移动触发 | [nyangeon_footstep_smoke.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/nyangeon_footstep_smoke.gd)、[combat_vfx.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/combat_vfx.gd) |

## 射击与命中反馈

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 枪口爆闪 | 共用。玩家、人形敌人与对应机械武器 | [weapon_muzzle_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/weapon_muzzle_effect.gd)、[burning_effects.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/burning_effects.gd) |
| 枪口余烟 | 共用。对应枪械的枪口效果 | [muzzle_smoke.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/muzzle_smoke.gd)、[weapon_muzzle_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/weapon_muzzle_effect.gd) |
| 枪火局部照明 | 条件。已配置局部射击光源的武器与场景 | [dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd)、[elemental_particles_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elemental_particles_3d.gd) |
| 射击后坐力 | 共用。共享枪械规则；手枪、步枪／冲锋枪与霰弹枪各有力度 | [dream_firearm_rules.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_firearm_rules.gd)、[employee_enemy.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/employee_enemy.gd) |
| 历史轨迹弹尾 | 共用。共享正式弹丸 | [basic_projectile.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/basic_projectile.gd)、[dream_3d_actor_depth_bridge.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_actor_depth_bridge.gd) |
| 视野边界弹丸回收 | 共用。接入相机边界的共享枪械弹丸 | [basic_projectile.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/basic_projectile.gd)、[dream_firearm_rules.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_firearm_rules.gd) |
| 敌人开火预警 | 共用。共享敌人瞄准预警与机械敌人预警 | [enemy_aim_telegraph.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/enemy_aim_telegraph.gd)、[exterior_patrol_drone_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/exterior_patrol_drone_3d.gd) |
| 命中白光 | 共用。对应枪击命中表现 | [combat_feedback_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/combat_feedback_effect.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |
| 星状冲击与像素碎片 | 共用。像素战斗命中特效 | [combat_feedback_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/combat_feedback_effect.gd)、[nyangeon_vfx_shapes.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/nyangeon_vfx_shapes.gd) |
| 受击闪白 | 共用。人形敌人和接入受击闪白的机械敌人 | [employee_enemy.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/employee_enemy.gd)、[special_unit_hit_flash.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/units/special_unit_hit_flash.gd) |
| 命中顿帧 | 共用。共享时间控制与命中反馈 | [dream_time_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_time_controller.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |
| 反弹子弹 | 条件。已接入弹丸反弹的玩家动作 | [basic_projectile.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/basic_projectile.gd)、[dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd) |
| 飞扑慢动作 | 条件。满足飞扑时间条件时 | [dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd)、[dream_time_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_time_controller.gd) |
| 反应慢动作 | 条件。对应格挡／近失事件 | [dream_time_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_time_controller.gd)、[basic_projectile.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/basic_projectile.gd) |
| 弹壳抛出 | 共用。接入抛壳的玩家与人形敌人枪械 | [shell_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/shell_effect.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |
| 弹丸自发光 | 共用。正式弹丸的自发光显示材质 | [basic_projectile.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/basic_projectile.gd)、[projectile_visual_glow.gdshader](E:/GameProjects/FiveMinuteMore/shaders/projectile_visual_glow.gdshader) |
| 受击画面冲击 | 共用。受伤表现；办公世界后期统一合成，畸变受屏幕抖动设置控制 | [player_hurt_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/player_hurt_presentation.gd)、[player_hurt_shock.gdshader](E:/GameProjects/FiveMinuteMore/shaders/player_hurt_shock.gdshader) |

## 近战、破坏与死亡

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 近战可命中扇区 | 共用。共享近战武器与空手攻击 | [lucille_weapon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/lucille_weapon.gd)、[dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd) |
| 可攻击目标高亮 | 共用。近战可达敌人；投掷预测还有自己的目标选择 | [dream_3d_target_highlight.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_target_highlight.gd)、[pixel_target_outline.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/pixel_target_outline.gdshader) |
| 挥击弧光 | 共用。接入共享挥击表现的近战武器 | [melee_sweep_visual_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/melee_sweep_visual_3d.gd)、[melee_pixel_sweep.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/melee_pixel_sweep.gdshader) |
| 月牙命中弧 | 共用。玩家近战命中及对应教程命中 | [melee_crescent_hit_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/melee_crescent_hit_3d.gd)、[melee_crescent_hit.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/melee_crescent_hit.gdshader) |
| 墙体破口与碎屑 | 条件。冲刺路径上的可破坏墙段；实际地板边界限制通行 | [shared_wall_breach.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/shared_wall_breach.gd)、[shared_wall_break_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/shared_wall_break_effect.gd) |
| 门体破坏 | 条件。可破坏门；特殊保护门按自身规则处理 | [dash_door_break.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dash_door_break.gd)、[physical_door_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/physical_door_3d.gd) |
| 玻璃破碎 | 条件。可破坏外窗、玻璃隔断及冲刺玻璃路径 | [dash_glass_break.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dash_glass_break.gd)、[breakable_glass_window_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/breakable_glass_window_3d.gd) |
| 燃烧火焰 | 条件。燃烧控制器及对应机械、环境事件 | [burning_effects.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/burning_effects.gd)、[elemental_particles_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elemental_particles_3d.gd) |
| 爆炸冲击波 | 条件。接入元素特效的爆炸与机械死亡 | [elemental_particles_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elemental_particles_3d.gd)、[unit_death_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/units/unit_death_effect.gd) |
| 灭火器喷雾 | 条件。可交互／可受击灭火器 | [fire_extinguisher_system.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/fire_extinguisher_system.gd)、[extinguisher_smoke.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/extinguisher_smoke.gdshader) |
| 分件死亡布娃娃 | 共用。玩家死亡与人形敌人尸体 | [player_death_ragdoll.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/player_death_ragdoll.gd)、[corpse_ragdoll_joint.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/corpse_ragdoll_joint.gd) |
| 武器散落 | 共用。共用武器掉落与角色死亡 | [world_weapon_pickup.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/world_weapon_pickup.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |
| 死亡慢放与镜头推近 | 共用。玩家死亡流程 | [dream_3d_run_interface.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_run_interface.gd)、[dream_time_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_time_controller.gd) |
| CRT 死亡关机 | 共用。玩家死亡界面 | [death_crt_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/death_crt_effect.gd)、[crt_shutdown.gdshader](E:/GameProjects/FiveMinuteMore/shaders/crt_shutdown.gdshader) |
| 投掷轨迹预览 | 共用。共用武器投掷瞄准 | [dream_throw_trajectory.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_throw_trajectory.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |

## 血液与漫画文字

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 空中血滴与飞溅 | 共用。共用血液效果 | [black_blood_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/black_blood_effect.gd)、[blood_airborne_carrier_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/blood_airborne_carrier_3d.gd) |
| 地面血斑与血泊 | 共用。共用地面血迹显示 | [black_blood_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/black_blood_effect.gd)、[blood_ground_capture_pool.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/blood_ground_capture_pool.gd) |
| 尸体渗血与拖痕 | 共用。对应尸体与血液发射器 | [corpse_blood_emitter.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/corpse_blood_emitter.gd)、[employee_enemy.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/employee_enemy.gd) |
| 血迹可见发光 | 共用。共用地面及空中血液材质 | [blood_lit_carrier_common.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/blood_lit_carrier_common.gdshaderinc)、[blood_airborne_semantic.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/blood_airborne_semantic.gdshader) |
| 受伤漫画字 | 共用。玩家受击表现 | [player_hurt_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/player_hurt_presentation.gd)、[comic_pixel_text.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/comic_pixel_text.gd) |
| 暴击漫画字 | 共用。当前敌人战斗文字系统 | [enemy_combat_text.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/enemy_combat_text.gd)、[comic_critical_fill.gdshader](E:/GameProjects/FiveMinuteMore/shaders/comic_critical_fill.gdshader) |
| 连杀评语 | 共用。当前共享击杀词库12句；以2026-11-12代码为准 | [enemy_combat_text.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/enemy_combat_text.gd)、[combat-feedback-train-clearance-20261111.md](E:/GameProjects/FiveMinuteMore/docs/reports/combat-feedback-train-clearance-20261111.md) |
| 漫画字网点阴影 | 共用。受伤词、暴击与共用漫画文字；独立于环境着色 | [comic_pixel_text.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/comic_pixel_text.gd)、[player_hurt_word_halftone.gdshader](E:/GameProjects/FiveMinuteMore/shaders/player_hurt_word_halftone.gdshader) |
| 世界位置固定文字 | 共用。对应受击、击杀与状态提示 | [enemy_combat_text.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/enemy_combat_text.gd)、[world_status_word.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/world_status_word.gd) |
| 换弹与武器名提示 | 共用。共用世界状态提示；如“正在换弹”和武器名称 | [world_status_word.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/world_status_word.gd)、[dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd) |
| 受伤漫画星星 | 共用。共用玩家受伤表现 | [player_hurt_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/player_hurt_presentation.gd) |

## 建筑、遮挡与空间

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| U 形墙根剖切 | 共用。接入正式办公室墙体剖切的墙段 | [office_wall_cutaway.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_wall_cutaway.gd)、[office_wall_cutaway_geometry.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_wall_cutaway_geometry.gd) |
| 剖面收口 | 共用。建筑切面与墙体交接 | [architecture_slice_cap.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/architecture_slice_cap.gd)、[architecture_slice_cap.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dream3d/architecture_slice_cap.gdshader) |
| 遮挡物局部渐隐 | 共用。接入遮挡处理的家具、建筑或场景物 | [authored_occlusion_cutout.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/authored_occlusion_cutout.gd)、[occlusion_cutout.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/occlusion_cutout.gdshaderinc) |
| 外围楼群软裁切 | 共用。当前办公室外围城市与房间可见性规则 | [depth_shape_city.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/city/depth_shape_city.gd)、[dream_3d_room_visibility.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_room_visibility.gd) |
| 城市纵深层次 | 共用。正式办公室窗外城市 | [depth_shape_city.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/city/depth_shape_city.gd)、[depth_shape_source.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/city/depth_shape_source.gd) |
| 广告牌辉光 | 场景。正式窗外城市中的广告部件 | [depth_shape_city.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/city/depth_shape_city.gd) |
| 门顶通行指示灯 | 场景。教程房间门与对应训练关卡 | [training_gate.gd](E:/GameProjects/FiveMinuteMore/scripts/story/training_gate.gd)、[chapter_tutorial.gd](E:/GameProjects/FiveMinuteMore/scripts/story/chapter_tutorial.gd) |

## 界面与场景演出

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| CRT 屏幕质感 | 场景。主菜单电视墙与暂停／设置屏幕；强度和表现由各自界面控制 | [screen_wall_crt.gdshader](E:/GameProjects/FiveMinuteMore/shaders/ui/screen_wall_crt.gdshader)、[screen_wall_pause_crt.gdshader](E:/GameProjects/FiveMinuteMore/shaders/ui/screen_wall_pause_crt.gdshader) |
| 电视墙信号切换 | 场景。正式电视墙主菜单；暂停／设置使用自己的显示规则 | [screen_wall_main_menu.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/screen_wall_main_menu.gd)、[screen_wall_review.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/screen_wall_review.gd) |
| 屏幕眼睛跟随 | 场景。电视墙人物表现 | [screen_wall_avatar.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/screen_wall_avatar.gd)、[screen_wall_review.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/screen_wall_review.gd) |
| 选中反色 | 场景。当前电视墙菜单、暂停及设置选项 | [pixel_option_group.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/pixel_option_group.gd)、[settings_panel.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/settings_panel.gd) |
| 白色悬停高亮 | 场景。已接入的主菜单设置与暂停设置控件 | [settings_panel.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/settings_panel.gd)、[screen_wall_pause_crt.gdshader](E:/GameProjects/FiveMinuteMore/shaders/ui/screen_wall_pause_crt.gdshader) |
| 条纹音量滑杆 | 场景。CRT设置页 | [crt_striped_slider.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/crt_striped_slider.gd) |
| 翻盖手机开合 | 共用。正式共享手机 | [flip_phone_shell.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/flip_phone_shell.gd)、[game_phone.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/game_phone.gd) |
| 手机鼠标轻摆 | 共用。正式手机为轻微跟随；独立精修样例有自己的转角参数 | [flip_phone_shell.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/flip_phone_shell.gd)、[game_phone.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/game_phone.gd) |
| 手机环境受光与反射 | 共用。正式手机环境桥接；3D场景使用局部映射光，卧室有后备环境 | [phone_environment_bridge.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/phone_environment_bridge.gd)、[phone_lcd_surface.gdshader](E:/GameProjects/FiveMinuteMore/shaders/ui/phone_lcd_surface.gdshader) |
| 实体按键压下与回弹 | 共用。手机鼠标、WASD／方向键、确认与返回操作 | [flip_phone_shell.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/flip_phone_shell.gd)、[game_phone.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/game_phone.gd) |
| 手机镜头推近 | 共用。接入手机镜头的3D场景 | [phone_camera_presentation.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/phone_camera_presentation.gd)、[game_phone.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/game_phone.gd) |
| 电梯连续乘行 | 场景。接入共用轿厢的进场与换层流程 | [independent_elevator_cab_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/independent_elevator_cab_3d.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |
| 电梯箭头脉冲 | 场景。当前共用参考电梯内饰 | [elevator_reference_art.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elevator_reference_art.gd)、[independent_elevator_cab_3d.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/independent_elevator_cab_3d.gd) |
| 电梯井外光掠过 | 场景。参考电梯乘行照明 | [elevator_reference_art.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/elevator_reference_art.gd) |
| 塔罗翻牌 | 场景。前台塔罗界面及对应章节 | [tarot_card_view.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/tarot/tarot_card_view.gd)、[tarot_overlay.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/tarot/tarot_overlay.gd) |
| 红底系统命令 | 场景。章节流程显式触发；以章节入口和进度为准 | [chapter_run.gd](E:/GameProjects/FiveMinuteMore/scripts/story/chapter_run.gd)、[chapter_panel.gd](E:/GameProjects/FiveMinuteMore/scripts/story/chapter_panel.gd) |
| 全屏短提示卡 | 条件。共享接口及独立提示样例；正式入口需要显式请求 | [fullscreen_player_cue.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/fullscreen_player_cue.gd)、[dream_3d_run_interface.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_run_interface.gd) |
| 对话框渐显与渐隐 | 共用。使用成长式对话框的角色交谈 | [growing_dialogue_bubble.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/dialogue/growing_dialogue_bubble.gd)、[dream_dialogue_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/dialogue/dream_dialogue_controller.gd) |
| 简短交互提示 | 共用。共享世界交互及对应章节 | [compact_interaction_prompt.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/compact_interaction_prompt.gd)、[context_hint.gd](E:/GameProjects/FiveMinuteMore/scripts/story/context_hint.gd) |
| 列车运行与交会 | 场景。0-6独立列车关卡 | [train_chapter.gd](E:/GameProjects/FiveMinuteMore/scripts/testing/metro_station/train_chapter.gd)、[train_chapter_consist.gd](E:/GameProjects/FiveMinuteMore/scripts/testing/metro_station/train_chapter_consist.gd) |
| 回血序列帧 | 条件。接入角色治疗表现的恢复行为 | [heal_effect.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/heal_effect.gd)、[dream_player.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/dream_player.gd) |
| 冷却进度环 | 场景。对应HUD的冲刺／闪避冷却图标，按该入口HUD显示配置呈现 | [dash_cooldown_icon.gdshader](E:/GameProjects/FiveMinuteMore/shaders/dash_cooldown_icon.gdshader)、[dream_hud.tscn](E:/GameProjects/FiveMinuteMore/scenes/ui/dream_hud.tscn) |
| 武器准心与开火回弹 | 共用。共享战斗准心 | [crosshair.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/crosshair.gd) |
| 深色半透明提示框 | 场景。已接入教程阶段引导；移动／鼠标镜头、空格翻滚、E拾取、右键丢弃四组提示，各组首次出现约3秒 | [tutorial_control_hint.gd](E:/GameProjects/FiveMinuteMore/scripts/ui/tutorial_control_hint.gd)、[tutorial_control_hint.gdshader](E:/GameProjects/FiveMinuteMore/shaders/ui/tutorial_control_hint.gdshader)、[chapter_tutorial.gd](E:/GameProjects/FiveMinuteMore/scripts/story/chapter_tutorial.gd) |
| 列车定时脱轨 | 场景。当前0-6列车关新增演出；按实际时间推进，每20秒处理下一节车厢 | [train_derailment.gd](E:/GameProjects/FiveMinuteMore/scripts/testing/metro_station/train_derailment.gd)、[train_chapter.gd](E:/GameProjects/FiveMinuteMore/scripts/testing/metro_station/train_chapter.gd) |

## 声音反馈

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 连杀观众反应 | 共用。共享连杀声音；声音计数与击杀评语的概率门槛分别处理 | [sfx_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/audio/sfx_manager.gd)、[dream_3d_run_interface.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_run_interface.gd) |
| 音乐侧链压低 | 共用。连杀反应与其他具有独立压低原因的声音流程 | [sfx_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/audio/sfx_manager.gd) |
| 三维位置音效 | 共用。接入世界位置播放的脚步、武器或环境事件 | [sfx_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/audio/sfx_manager.gd) |
| 慢动作音频变化 | 共用。共享世界音效时间通道 | [sfx_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/audio/sfx_manager.gd)、[dream_time_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_time_controller.gd) |
| 战斗结束音乐收尾 | 条件。房间／Boss战斗结束音乐钩子 | [sfx_manager.gd](E:/GameProjects/FiveMinuteMore/scripts/audio/sfx_manager.gd)、[dream_3d_random_dungeon.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) |

## 红海与海岸氛围

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 多向海浪涟漪 | 场景。当前红海海面与中近景波浪 | [coast_near_surf.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_near_surf.gd)、[night_coast_water.gdshader](E:/GameProjects/FiveMinuteMore/shaders/preview/night_coast_water.gdshader) |
| 拍岸白浪 | 场景。红海岸线与对应近岸模拟 | [coast_surface_foam.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_surface_foam.gd)、[coast_near_surf.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_near_surf.gd) |
| 浅层流水模拟 | 场景。红海局部水域和流水研究；血迹使用自己的血滴与地面显示系统 | [surface_flow.gd](E:/GameProjects/FiveMinuteMore/scripts/simulation/surface_flow.gd)、[coast_near_surf.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_near_surf.gd) |
| 水面月光反射带 | 场景。红海水面 | [night_coast_water.gdshader](E:/GameProjects/FiveMinuteMore/shaders/preview/night_coast_water.gdshader)、[night_coast.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/night_coast.gd) |
| 云遮月联动 | 场景。红海天空、水面、远景灯光的联动 | [night_coast.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/night_coast.gd)、[coast_atmosphere.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_atmosphere.gd) |
| 世界固定月亮 | 场景。当前红海世界月亮节点 | [night_coast.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/night_coast.gd)、[night_coast_city_cliff_sample.tscn](E:/GameProjects/FiveMinuteMore/scenes/preview/night_coast_city_cliff_sample.tscn) |
| 海天线散焦光点 | 场景。配置海天线光点的红海变体 | [coast_atmosphere.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_atmosphere.gd)、[coast_horizon_signal.gdshader](E:/GameProjects/FiveMinuteMore/shaders/preview/coast_horizon_signal.gdshader) |
| 摩斯灯光信号 | 场景。红海按场景配置选择空间点划、计时闪烁或章节消息 | [coast_morse_sequence.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_morse_sequence.gd)、[coast_atmosphere.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_atmosphere.gd) |
| 海面雾带 | 场景。红海海上氛围 | [coast_fog_ribbon.gdshader](E:/GameProjects/FiveMinuteMore/shaders/preview/coast_fog_ribbon.gdshader)、[coast_atmosphere.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/coast_atmosphere.gd) |
| 海岸灰色轮廓线 | 场景。接入对应材质的海岸道具与风机 | [coast_grey_outline.gdshader](E:/GameProjects/FiveMinuteMore/shaders/preview/coast_grey_outline.gdshader)、[coast_turbine_outline.gdshader](E:/GameProjects/FiveMinuteMore/shaders/preview/coast_turbine_outline.gdshader) |
| 海岸镜头揭示 | 场景。红海海岸角色跟随镜头 | [night_coast.gd](E:/GameProjects/FiveMinuteMore/scripts/preview/night_coast.gd) |

## 独立样例与历史称呼

| 术语 | 状态与接入范围 | 主要位置 |
| --- | --- | --- |
| 快速冲刺 | 历史。2026-11-12当前输入已解除Shift手动冲刺；运行时动作接口仍供脚本使用 | [player_phase_dash.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/player_phase_dash.gd)、[game_input_actions.gd](E:/GameProjects/FiveMinuteMore/scripts/app/game_input_actions.gd) |
| 手动子弹时间 | 历史。2026-11-12当前输入已解除T键手动慢动作；脚本时间接口保留 | [dream_time_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_time_controller.gd)、[game_input_actions.gd](E:/GameProjects/FiveMinuteMore/scripts/app/game_input_actions.gd) |
| 手机精修光照样例 | 样例。独立精修候选；当前入口与正式手机分别核对 | [preview_phone_polish.cmd](E:/GameProjects/FiveMinuteMore/tools/preview_phone_polish.cmd)、[phone-polish-20261108.md](E:/GameProjects/FiveMinuteMore/docs/reports/phone-polish-20261108.md) |
| 全局调色板方案 | 历史。普通场景全局调色板已退役，当前以资源原色与场景光照呈现 | [AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md)、[selective_pixel_preview.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd) |
| 明暗交界抖动 | 历史。当前办公材质组合已移除；海水图案、遮挡渐隐与漫画字网点各有独立用途 | [AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md)、[office_dither_lighting.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_dither_lighting.gdshaderinc) |
| 交叉排线 | 历史。已按用户要求从当前正式材质组合移除 | [AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md) |
| 家具结构外描边 | 历史。正式家具的额外外扩黑轮廓已移除；材质边缘光和场景投影另有作用 | [AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md)、[office_surface_style.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/office_surface_style.gd) |
| 人物常驻描边 | 历史。当前人形战斗使用条件性目标高亮；人物原画自带的像素黑边属于原画 | [enemy_outline_controller.gd](E:/GameProjects/FiveMinuteMore/scripts/entities/enemy_outline_controller.gd)、[dream_3d_target_highlight.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_target_highlight.gd) |
| 普通伤害数字 | 历史。2026-11-11共享战斗文字已关闭普通数值；当前暴击词与概率连杀评语各自运行 | [enemy_combat_text.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/enemy_combat_text.gd)、[combat-feedback-train-clearance-20261111.md](E:/GameProjects/FiveMinuteMore/docs/reports/combat-feedback-train-clearance-20261111.md) |
| 旧明暗层次增强 | 历史。当前着色包含文件中的office_tonal_sample仅声明；显示开关还联动像素稳定，材质效果按现有组合分别命名 | [selective_pixel_preview.gd](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd)、[office_dither_lighting.gdshaderinc](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_dither_lighting.gdshaderinc) |


