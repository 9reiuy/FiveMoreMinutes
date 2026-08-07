# Demo 集中配置说明

运行时参数统一保存在 `res://resources/demo_config.tres`，字段、类型与 Inspector 分组定义在 `res://scripts/data/demo_config.gd`。下表是本阶段新增或直接相关的参数；范围是建议调节范围，不是强制钳制范围。

## 导入音效与总线

九个事件音效由全局 `SFXManager` 统一从 `res://sfx/` 播放。管理器运行时建立 `UI`、`Weapons`、`Characters`、`Environment` 四条 Audio Bus，不修改原始 MP3。

| 参数 | 默认值 | 作用 |
|---|---:|---|
| `sfx_forbidden_volume_db` | -10 dB | 禁止选择、余额/RAM不足、强化满级 |
| `sfx_death_volume_db` | -8 dB | 正式致命死亡 |
| `sfx_new_message_volume_db` | -12 dB | 新未读消息批次 |
| `sfx_purchase_volume_db` | -10 dB | 速联跑腿和眠网购买成功 |
| `sfx_laser_volume_db` | -12 dB | 光束实际发射 |
| `sfx_home_door_volume_db` | -10 dB | 开始新一天的回家开门过渡 |
| `sfx_work_volume_db` | -10 dB | 正常上班结算 |
| `sfx_confirm_volume_db` | -14 dB | 普通确认按钮和对话选择 |
| `sfx_experience_volume_db` | -16 dB | 实际拾取经验 |
| `sfx_experience_min_interval` | 0.08 s | 高频拾取音之间的最短间隔 |

## 开始菜单、卧室点击与顶部经验条

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `main_menu_button_spacing` | 12 px | 4–40 px | 开始菜单五个按钮之间的距离 |
| `bedroom_interaction_outline_color` | 白色 | 任意可见颜色 | 卧室鼠标当前指向物体的描边颜色 |
| `bedroom_interaction_outline_width` | 2 px | 1–8 px | 卧室悬停描边宽度 |
| `bedroom_interaction_outline_opacity` | 0.78 | 0–1 | 床和褪黑素轮廓描边的不透明度 |
| `bedroom_show_click_regions` | `false` | 调试时开启 | 显示床和药瓶的点击区域 |
| `experience_bar_height` | 24 px | 12–48 px | 梦境顶部经验条总高度 |
| `experience_bar_margin` | 14 px | 4–40 px | 经验条距离屏幕顶部和两侧的边距 |
| `experience_bar_fill_animation_speed` | 9 | 1–30 | 经验填充追赶目标进度的速度 |
| `experience_bar_near_level_threshold` | 0.8 | 0.5–1 | 经验接近升级时开始脉冲的比例 |

单槽存档路径为 `user://savegame.json`，由 `GameSaveStore` 校验版本和必要字段；无有效文件时不会创建空存档。

## 交互与受伤反馈

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `interaction_outline_color` | 白色 | 任意不透明色 | 最近可交互世界物体的描边颜色 |
| `interaction_outline_width` | 2 px | 1–6 px | 床、药瓶等交互物描边宽度 |
| `hurt_invulnerability_seconds` | 0.55 s | 0.1–2 s | 有效受伤后的无敌时间 |
| `hurt_flash_frequency` | 12 Hz | 4–24 Hz | 无敌期间闪烁频率 |
| `hurt_flash_seconds` | 0.18 s | 0.05–0.5 s | 受伤红色反馈持续时间 |
| `hurt_shake_pixels` | 2 px | 0–6 px | 角色受伤抖动幅度 |

## 死亡与卧室时间

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `death_wake_delay_min_minutes` | 30 min | 0–180 min | 梦中死亡后追加的最小游戏分钟 |
| `death_wake_delay_max_minutes` | 90 min | 最小值–360 min | 梦中死亡后追加的最大游戏分钟（含端点） |
| `bedroom_start_minutes` | 1260（21:00） | 0–1439 | 每天卧室阶段开始时间 |
| `bedroom_force_sleep_minutes` | 1440（00:00） | 开始值之后 | 强制进入睡眠流程的时间 |
| `bedroom_real_seconds_per_game_minute` | 1 s | 0.05–10 s | 卧室中每个游戏分钟对应的现实秒数 |

## 手动瞄准与准星

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `crosshair_cooldown_color` | `#595C66` | 任意颜色 | 武器刚进入冷却时的准星颜色 |
| `crosshair_ready_color` | 白色 | 任意颜色 | 武器可射击时的准星颜色 |
| `crosshair_color_lerp_speed` | 10 | 1–30 | 准星向目标冷却颜色平滑过渡的速度 |
| `crosshair_recoil_pixels` | 5 px | 0–12 px | 基础视觉后坐力距离 |
| `crosshair_recoil_recovery_seconds` | 0.12 s | 0.03–0.5 s | 准星回到鼠标真实位置的时间 |
| `basic_weapon_recoil_multiplier` | 1.0 | 0–3 | 小手枪后坐力倍率 |
| `beam_weapon_recoil_multiplier` | 1.5 | 0–3 | 光束武器后坐力倍率 |

## 修正带怪物

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `correction_trigger_distance` | 50 px | 20–160 px | 停止追踪并开始蓄力的距离 |
| `correction_charge_seconds` | 0.75 s | 0.2–2 s | 冲刺前蓄力时间 |
| `correction_dash_distance` | 150 px | 40–400 px | 单次冲刺目标距离 |
| `correction_dash_speed` | 360 px/s | 100–900 px/s | 冲刺速度 |
| `correction_dash_damage` | 18 | 0–200 | 冲刺接触伤害 |
| `correction_recovery_seconds` | 0.5 s | 0–3 s | 冲刺结束后的恢复时间 |

## 订书机怪物与订书钉

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `stapler_fire_interval` | 2 s | 0.2–10 s | 两次发射之间的时间 |
| `staple_damage` | 10 | 0–200 | 订书钉命中伤害 |
| `staple_speed` | 170 px/s | 20–1000 px/s | 订书钉飞行速度 |
| `staple_max_distance` | 300 px | 20–1500 px | 飞行后自动销毁的最大距离 |
| `staple_collision_radius` | 5 px | 1–30 px | 订书钉碰撞半径 |

## 经济与结算

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `RunSettlement.calculate_run_ram(final_level)` | 等级−1，最低0 | 固定规则 | 本局RAM只按最终等级计算，不再读取累计经验 |
| `initial_balance` | ¥1,325 | 0–2,000,000,000 | 新档局外余额 |
| `daily_base_wage` | ¥500 | 0–1,000,000 | 完整日工资；迟到比例仍由现有倍率计算 |
| `wage_ratio_on_time` | 1.0 | 0–2 | 正常上班工资比例 |
| `wage_ratio_slightly_late` | 0.8 | 0–2 | 轻微迟到工资比例 |
| `wage_ratio_severely_late` | 0.5 | 0–2 | 严重迟到工资比例 |
| `wage_ratio_absent` | 0.0 | 0–2 | 旷工工资比例 |

出勤边界固定为：`<07:30` 正常、`<08:00` 轻微迟到、`<09:00` 严重迟到、其余旷工。失业接口会跳过工资结算。

## 褪黑素与速联跑腿™

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `melatonin_price` | ¥100 | 0–1,000,000 | 单片购买价格 |
| `melatonin_inventory_cap` | 99 | 1–999 | 永久库存上限 |
| `melatonin_shake_window_seconds` | 1.2 s | 0.2–5 s | 统计鼠标往复动作的时间窗口 |
| `melatonin_required_shake_distance` | 260 px | 20–1500 px | 窗口内要求的累计移动距离 |
| `melatonin_required_reversals` | 4 | 1–20 | 要求的水平方向反转次数 |
| `melatonin_bottle_rotation_degrees` | 18° | 0–60° | 晃动时药瓶最大视觉旋转幅度 |
| `melatonin_nightly_use_limit` | 3 | 1–10 | 每晚最大服用片数；达到后只显示阻止提示 |
| `melatonin_minutes_earlier_per_tablet` | 30 分钟 | 0–240 | 每完整服用一片后，本晚梦境开始时间提前的游戏分钟数 |

商品展示数据位于 `res://resources/quicklink_items.json`。`res://resources/phone_shop.json` 保留为空，以明确梦境商店当前没有购买内容。

## 既有核心参数

敌人生成、敌人上限、基础生命/伤害、7:00后成长、梦境时钟、醒来长按、慢动作、升级公式、两种武器、闪避、逐字速度/音效和手机位置也继续集中在同一资源中。其中 `base_wake_hold_seconds` 默认5秒，`bullet_time_scale` 默认0.20，梦境默认04:00开始、07:00响铃。

## 本阶段：敌人解锁与大体型修正带

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `correction_unlock_seconds` | 30 s | 0–600 s | 普通修正带加入随机池的单局经过时间 |
| `stapler_unlock_seconds` | 90 s | 0–900 s | 订书机加入随机池的单局经过时间 |
| `large_correction_unlock_seconds` | 180 s | 1–1800 s | 大体型修正带每局唯一一次强制生成时间 |
| `correction_trigger_distance` | 150 px | 20–300 px | 普通修正带开始蓄力的距离 |
| `correction_charge_seconds` | 0.75 s | 0.1–3 s | 普通修正带原地蓄力时间 |
| `correction_dash_distance` | 200 px | 20–500 px | 普通修正带冲刺距离 |
| `large_correction_health_multiplier` | 10 | 1–50 | 精英相对普通修正带的生命倍率 |
| `large_correction_size_multiplier` | 1.8 | 1–4 | 精英视觉与碰撞体尺寸倍率 |
| `large_correction_trigger_distance` | 150 px | 20–400 px | 精英开始攻击序列的距离 |
| `large_correction_charge_seconds` | 0.75 s | 0.1–3 s | 三连冲刺前唯一一次完整蓄力 |
| `large_correction_dash_distance` | 200 px | 20–600 px | 精英每段冲刺距离 |
| `large_correction_dash_speed` | 360 px/s | 50–1200 px/s | 精英冲刺速度 |
| `large_correction_dash_damage` | 24 | 0–500 | 精英每段冲刺接触伤害 |
| `large_correction_dash_count` | 3 | 1–8 | 每轮连续冲刺次数 |
| `large_correction_dash_interval` | 0.2 s | 0.05–2 s | 连续冲刺之间的方向预告停顿 |
| `large_correction_recovery_seconds` | 0.5 s | 0–5 s | 三连冲刺后的恢复时间 |
| `large_correction_experience_ratio` | 0.5 | 0–5 | 击败奖励相对当前升级需求的比例 |

## 本阶段：星期与闹钟

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `weekday_alarm_minutes` | 420（07:00） | 0–1439 | 星期一至星期六的梦境闹钟时间 |
| `sunday_alarm_minutes` | 540（09:00） | 0–1439 | 星期日梦境闹钟时间 |

星期索引保存在局外状态：0为星期一、6为星期日。手机锁屏不维护独立计时器，而是直接显示卧室的 `current_minutes`。

## 本阶段：眠网™永久强化

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `permanent_upgrade_prices` | `[1,3,5,8,10]` | 每项0–32767 | 每项强化从1级到5级的RAM价格 |
| `permanent_upgrade_max_level` | 5 | 1–20 | 每项永久强化等级上限 |
| `visual_cortex_range_per_level` | 50 px | 0–500 px | 枕叶视觉皮层每级攻击范围增量 |
| `brainstem_experience_per_level` | 0.2 | 0–2 | 脑干每级经验倍率增量 |
| `hippocampus_health_per_level` | 20 | 0–1000 | 海马体每级初始最大生命增量 |
| `prefrontal_attack_speed_per_level` | 0.2 | 0–5 | 前额叶每级攻击速度倍率增量；最终间隔使用除法 |

每项从0升至5级分别消耗1、3、5、8、10 RAM，即每项总计27 RAM。四项等级存放在局外 `permanent_upgrades` 字典中。

## 本阶段：三选一与局内技能

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `rarity_blue_probability` | 0.88 | 0–1 | 单张卡蓝色权重 |
| `rarity_purple_probability` | 0.10 | 0–1 | 单张卡紫色权重 |
| `rarity_gold_probability` | 0.02 | 0–1 | 单张卡金色权重 |
| `rarity_reroll_attempts` | 10 | 1–100 | 当前稀有度无候选时最大重新抽取次数 |
| `normal_attack_speed_upgrade_multiplier` | 1.15 | 1–5 | 蓝色普通攻击速度升级倍率 |
| `normal_range_upgrade_pixels` | 35 px | 0–500 px | 蓝色普通攻击范围升级增量 |
| `normal_upgrade_max_level` | 99 | 1–999 | 三项普通蓝色升级各自的获取上限 |
| `sleep_paralysis_blue_still_seconds` | 10 s | 0.1–120 s | 蓝色睡眠瘫痪触发静止时间 |
| `sleep_paralysis_blue_heal_per_second` | 5 | 0–1000 | 蓝色版本每秒治疗 |
| `sleep_paralysis_purple_still_seconds` | 8 s | 0.1–120 s | 紫色版本触发静止时间 |
| `sleep_paralysis_purple_heal_per_second` | 10 | 0–1000 | 紫色版本每秒治疗 |
| `sleep_paralysis_gold_still_seconds` | 8 s | 0.1–120 s | 金色版本触发静止时间 |
| `sleep_paralysis_gold_heal_per_second` | 15 | 0–1000 | 金色版本每秒治疗 |
| `sleep_spindle_blue_interval` | 30 s | 0.1–600 s | 蓝色睡眠纺锤产盾周期 |
| `sleep_spindle_purple_interval` | 20 s | 0.1–600 s | 紫色睡眠纺锤产盾周期 |
| `sleep_spindle_gold_interval` | 10 s | 0.1–600 s | 金色睡眠纺锤产盾周期 |
| `sleep_spindle_max_layers` | 1 | 固定1 | 睡眠纺锤最大护盾层数；本阶段禁止多层 |
| `hypnic_jerk_max_bonus_charges` | 2 | 0–10 | 入睡抽动本局最多获取次数 |
| `dash_max_charges` | 3 | 1–10 | 冲刺充能硬上限 |
| `consciousness_drift_chance_per_level` | 0.5 | 0–1 | 意识漂移每级额外攻击概率 |
| `consciousness_drift_extra_delay` | 0.08 s | 0–1 s | 原攻击与额外攻击之间的延迟 |
| `consciousness_drift_max_level` | 2 | 固定2 | 意识漂移本局获取上限 |
| `rapid_eye_slow_multiplier` | 0.7 | 0–1 | 快速眼动生效时怪物移动速度倍率 |
| `rapid_eye_duration_seconds` | 5 s | 0.1–120 s | 快速眼动持续时间 |
| `rapid_eye_max_acquisitions` | 1 | 固定1 | 快速眼动本局获取上限 |
| `dissociation_revive_health` | 30 | 1–10000 | 意识解离触发后的生命值 |
| `dissociation_invulnerability_seconds` | 3 s | 0–30 s | 意识解离触发后的无敌时间 |
| `dissociation_max_acquisitions` | 1 | 固定1 | 意识解离本局获取上限 |

普通蓝色增伤继续使用既有 `damage_upgrade_multiplier=1.5`。技能定义与抽取约束集中在 `res://scripts/data/upgrade_catalog.gd`，运行时状态每局新建，不写入局外数据。

## 本阶段：武器、掉落、刷新与正常生活结局

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `basic_weapon_attack_interval` | 0.30 s | 0.05–10 s | 小手枪两次有效发射之间的基础间隔 |
| `shotgun_pellet_count` | 9 | 1–32 | 霰弹枪每轮完整齐射的弹丸数 |
| `shotgun_pellet_damage` | 3 | 0–1000 | 每颗霰弹的基础伤害 |
| `shotgun_attack_interval` | 0.8 s | 0.05–20 s | 霰弹枪基础攻击间隔 |
| `shotgun_spread_degrees` | 30° | 0–180° | 一轮霰弹相对准星方向的总扩散角 |
| `shotgun_projectile_speed` | 310 px/s | 20–2000 px/s | 霰弹弹丸飞行速度 |
| `shotgun_max_distance` | 270 px | 20–2000 px | 霰弹弹丸最大飞行距离 |
| `shotgun_recoil_multiplier` | 1.8 | 0–5 | 霰弹枪相对基础准星后坐力的倍率 |
| `katana_attack_interval` | 2.0 s | 0.05–20 s | 太刀完整攻击（斩击与剑气共用）的间隔 |
| `katana_melee_damage` | 30 | 0–5000 | 太刀近身范围斩击伤害 |
| `katana_melee_radius` | 50 px | 1–500 px | 太刀以玩家为圆心的近身斩击半径 |
| `katana_wave_damage` | 10 | 0–5000 | 每道剑气对每名敌人的单次伤害 |
| `katana_wave_speed` | 450 px/s | 20–3000 px/s | 剑气移动速度 |
| `katana_wave_max_distance` | 300 px | 200–1000 px | 剑气最大飞行距离；本次保持原值 |
| `katana_wave_width` | 32 px | 4–200 px | 剑气视觉与碰撞宽度，为原16px的2倍 |
| `katana_wave_initial_speed_ratio` | 0.35 | 0.1–1 | 剑气初始速度相对450px/s最终速度的比例 |
| `katana_wave_acceleration_duration` | 0.25 s | 0.05–0.8 s | Ease-In加速持续时间 |
| `katana_wave_acceleration_curve` | Ease-In | Curve输出0–1 | 只控制直线剑气的速度变化形状 |
| `correction_experience_drop_count` | 2 | 1–16 | 普通修正带正式死亡后生成的经验物数量 |
| `stapler_experience_drop_count` | 3 | 1–16 | 订书机正式死亡后生成的经验物数量 |
| `upgrade_refreshes_per_level` | 1 | 0–3 | 每个独立升级三选一界面的刷新次数 |
| `normal_life_ending_required_workdays` | 14 | 1–365 | 触发正常生活结局所需的连续正常出勤工作日 |

出勤计数字段为 `normal_attendance_workday_streak`，结局解锁字段为 `normal_life_ending_unlocked`；二者保存在现有单槽存档状态中，旧存档加载时由默认状态补齐。

## 本阶段：褪黑素抓取与摇晃

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `melatonin_shake_window_seconds` | 1.2 s | 0.2–10 s | 一组连续有效摇晃的时间窗口 |
| `melatonin_required_shake_distance` | 260 px | 10–3000 px | 成功前要求的总水平移动距离 |
| `melatonin_required_reversals` | 4 | 1–30 | 兼容既有规则的最低反转次数 |
| `melatonin_shake_segment_min_distance` | 24 px | 1–300 px | 单段方向移动可计为有效摇晃的最低距离 |
| `melatonin_required_shakes` | 4 | 1–30 | 成功倒出药片所需有效摇晃次数 |
| `sfx_bottle_shake_volume_db` | -12 dB | -60–6 dB | 导入的摇晃药瓶音效音量 |
| `sfx_bottle_shake_min_interval` | 0.10 s | 0.02–1 s | 两次有效摇晃音效之间的最短间隔 |

## 本阶段：手机、菜单、敌人反馈与服药演出

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `phone_panel_width` | 160 px | 建议160 | 与Phone.png原始宽度一致 |
| `phone_panel_height` | 336 px | 建议336 | 与Phone.png原始高度一致 |
| `phone_expanded_y` | 24 px | 0–80 px | 手机展开位置 |
| `phone_collapsed_y` | 319 px | 270–345 px | 仅露出摄像头区域的收起位置 |
| `phone_app_hover_brightness` | 0.12 | 0–0.5 | App 悬停时图标和名称的统一变亮幅度，不绘制白框 |
| `sfx_phone_unlock_volume_db` | -10 dB | -60–6 dB | 指纹成功解锁手机时的音效音量 |
| `sfx_phone_operation_volume_db` | -16 dB | -60–6 dB | 普通手机 App、返回和页面操作的音效音量 |
| `phone_animation_seconds` | 0.35 s | 0.05–2 s | 展开和收回动画时间 |
| `phone_upper_collapse_height` | 166 px | 100–169 px | 主页上半部收回热区；应用从170px开始 |
| `tab_menu_pauses_tree` | `true` | 建议保持`true` | Tab菜单是否使用场景树暂停方式 |
| `correction_dash_max_seconds` | 1.25 s | 0.1–5 s | 普通和大体型修正带单段冲刺的超时保险 |
| `enemy_hit_flash_color` | 1.8倍白色 | 1–3倍亮度 | 所有敌人有效受击时的调制颜色 |
| `enemy_hit_flash_seconds` | 0.08 s | 0.02–0.3 s | 敌人闪白持续时间 |
| `enemy_hit_scale_seconds` | 0.12 s | 0.02–0.5 s | 敌人挤压缩放恢复时间 |
| `enemy_hit_scale_amount` | 0.08 | 0–0.25 | 受击挤压的最大比例 |
| `melatonin_consume_hand_approach_seconds` | 0.65 s | 0.1–3 s | 左手与药丸靠近镜头的时间 |
| `melatonin_consume_hand_max_scale` | 2.2 | 1–4 | 第一人称左手最大缩放倍率 |
| `melatonin_consume_vignette_alpha` | 0.48 | 0–0.9 | 服药动作末段暗角强度 |
| `melatonin_consume_pre_swallow_pause` | 0.18 s | 0–2 s | 药片落入手中后、抬手前的停顿 |
| `melatonin_consume_end_pause` | 0.3 s | 0–2 s | 吞咽确认后返回卧室前的停顿 |
| `melatonin_swallow_sound_volume_db` | -16 dB | -60–0 dB | 临时8-bit吞咽确认音量 |

Tab菜单内容由当前单局技能状态和角色/武器运行时数值即时生成，不维护第二套属性数据。手机应用位置使用统一2列×2行网格公式，主页上半区不包含应用点击区。

## 本阶段：手机排版、确认对话、门音效与调试控制台

| 参数 | 默认值 | 推荐范围 | 作用 |
|---|---:|---:|---|
| `phone_app_chinese_title_font_size` | 13 px | 8–24 px | 手机应用页中文主标题字号 |
| `phone_app_english_title_font_size` | 8 px | 6–18 px | 手机应用页英文副标题字号 |
| `phone_app_content_margin` | 12 px | 4–24 px | 应用正文区左右留白 |
| `online_message_spacing` | 8 px | 2–20 px | ONLINE消息块之间的垂直间距 |
| `online_unread_dot_size` | 4 px | 2–10 px | ONLINE未读红点半径 |
| `online_unread_dot_offset` | `(2, 0)` | 依图标调整 | 未读红点相对 ONLINE 图标右上角的偏移 |
| `dialog_animation_seconds` | 0.22 s | 0.05–1 s | 卧室确认对话头像入场动画时间 |
| `dialog_portrait_appearance_position` | `(16, 90)` | 屏幕内坐标 | 心理恐怖对话半身立绘的最终位置 |
| `door_open_close_gap_seconds` | 0.45 s | 0–3 s | 开门后至关门的过渡间隔 |
| `console_panel_size` | `(520, 210)` | 320×140–620×340 | Debug控制台面板尺寸 |
| `console_font_size` | 14 px | 8–28 px | Debug控制台输出与输入字号 |

ONLINE消息的 `is_read` 位于 `res://resources/phone_messages.json`，运行后复制到局外状态；手机主页和锁屏仍直接使用卧室唯一时间源。Debug控制台只在调试构建启用。
