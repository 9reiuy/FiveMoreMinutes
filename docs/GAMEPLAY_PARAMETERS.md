# 《Five Minutes More》玩法参数说明

主要玩法参数统一位于 `res://resources/demo_config.tres`，字段定义位于 `res://scripts/data/demo_config.gd`。除特别说明外，修改后需要重新启动游戏，或至少重新进入使用该参数的场景；已经生成的敌人、武器和结算结果不会被追溯修改。

正式 3D Run 例外：`dream_3d_random_dungeon.gd` 使用本局独立配置，基础射速为手枪 4.2、步枪 9、霰弹枪 2.4 发/秒，玩家移速 290、敌人基础移速 150、弹速统一 1500。射速升级和全局射速乘数继续叠加；源资源中的基础间隔不代表 3D Run 最终值。详见 [射速接入记录](fire_rate_reference_2026-10-02.md)。

推荐范围用于调试平衡，并非所有字段的强制钳制范围。过高的生成数量、移动速度或粒子数量可能影响低配置设备性能。

## Dream Employee敌人（唯一正式敌人）

- 正式场景：`res://scenes/entities/employee_enemy.tscn`。
- 素材：`res://art/Dream/enemy/Employee_men_32x32.png`，160×96（5列×3行、每格32×32）分层图集；第一列为拼装校准参考，其余列由运行时拆分使用。
- `employee_global_population_target`：默认`6`，剧情地牢全局Employee目标数量；推荐`3—12`。
- `employee_population_refill_batch`：默认`1`，每次补充数量；推荐`1—2`。
- `employee_population_refill_interval`：默认`3.0s`，人口检查周期；推荐`1—8s`。
- `employee_xp_value`：默认`5`，统一蓝色经验奖励。
- `employee_movement_speed`：默认`38px/s`，中立漫游、逃跑、找武器和追击共用基础速度。
- `employee_weapon_search_interval`：默认`0.55s`；`employee_weapon_pickup_radius`默认`28px`。
- `employee_boss_health_multiplier`：默认`8.0`；Boss只使用Employee美术和统一AI，不再生成Elite Eye。
- 出生状态为`NEUTRAL_WANDER`。只有Player来源有效伤害会永久触发敌对；无武器时逃跑并持续搜索，有武器后按武器基础值攻击，不读取Player卡片或永久升级。
- 当前房间、Start Room和可见活动房间均禁止补怪；系统只在缓存的其它不可见房间逐只补充。
- WorldWeapon使用`reserved_by`避免多个Employee争抢；Employee死亡会把持有武器重新变回可踢、可交换的地面武器。

## Dream画面暗色覆盖

- `res://scenes/dream/dream_world.tscn`不再包含长期`CanvasModulate`/`DreamLighting`暗色覆盖。
- `UILayer/RoomTransitionFade`、死亡CRT和返回主界面过渡继续保留，只在转场期间短暂显示。

## 时间与睡眠

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 梦境开始时间 | `dream_start_minutes` | 240（04:00） | 游戏分钟 | 默认梦境起始时间 | 0—1439 | 每片褪黑素会进一步提前 |
| 梦境闹钟时间（旧字段） | `alarm_start_minutes` | 360（06:00） | 游戏分钟 | 仅保留兼容旧数据；当前房间制剧情不会据此唤醒 | 0—1439 | DreamClock的`alarm_enabled=false`，时间只用于UI/统计 |
| 梦境时间倍率 | `real_seconds_per_game_minute` | 1.0 | 现实秒/游戏分钟 | 梦境时钟推进倍率 | 0.05—10 | 慢动作会同步影响推进 |
| 卧室开始时间 | `bedroom_start_minutes` | 1260（21:00） | 游戏分钟 | 每天卧室阶段的起点 | 0—1439 | 应早于强制睡觉时间 |
| 强制睡觉时间 | `bedroom_force_sleep_minutes` | 1440（00:00） | 游戏分钟 | 到点自动进入睡觉流程 | 1261—2880 | 与卧室时间倍率联动 |
| 卧室时间倍率 | `bedroom_real_seconds_per_game_minute` | 1.0 | 现实秒/游戏分钟 | 卧室时钟推进倍率 | 0.05—10 | 对话暂停时不推进 |
| 剧情正式起床时间（旧字段） | `story_wake_minutes` | 360（06:00） | 游戏分钟 | 保留给旧结算数据兼容，当前Dream不以时间结束 | 0—1439 | 正常醒来唯一入口为击败Boss后的Final Wake Door |
| 工作日起床兼容字段 | `weekday_alarm_minutes` | 360（06:00） | 游戏分钟 | 旧接口兼容值 | 0—1439 | 正式剧情运行读取`story_wake_minutes` |
| 星期日起床兼容字段 | `sunday_alarm_minutes` | 360（06:00） | 游戏分钟 | 旧接口兼容值 | 0—1439 | 星期日仍不发工资、不改变出勤连续数 |
| 每片褪黑素提前时间 | `melatonin_minutes_earlier_per_tablet` | 30 | 游戏分钟/片 | 每服一片提前梦境开始时间 | 0—240 | 乘以本晚完整服用片数 |
| 每晚服用上限 | `melatonin_nightly_use_limit` | 3 | 片 | 每晚最多服用数量 | 1—10 | 库存跨天保存，本晚数量跨天重置 |
| 死亡起床延迟最小值 | `death_wake_delay_min_minutes` | 30 | 游戏分钟 | 梦中死亡后追加起床时间下限 | 0—180 | 不得大于最大值 |
| 死亡起床延迟最大值 | `death_wake_delay_max_minutes` | 90 | 游戏分钟 | 梦中死亡后追加起床时间上限 | 30—360 | 主动醒来不使用该随机延迟 |

## 玩家、冲刺与醒来

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 基础最大生命 | `player_base_maximum_health` | 100 | HP | 未计算海马体强化前的生命 | 1—1000 | 与 `hippocampus_health_per_level` 相加 |
| 基础移动速度 | `player_movement_speed` | 112 | px/s | 梦境玩家移动速度 | 20—500 | 慢动作由引擎时间倍率统一影响 |
| 梦境出生无敌 | `player_spawn_invulnerability_duration` | 3.0 | 梦境秒 | 玩家控制启用后通过统一受伤入口免疫全部伤害 | 0—10 | 暂停时不计时 |
| 受伤无敌时间 | `hurt_invulnerability_seconds` | 0.55 | 秒 | 有效受伤后的无敌时间 | 0.1—2 | 不影响受击视觉持续时间 |
| 冲刺距离 | `dash_distance` | 100 | px | 单次冲刺目标距离 | 20—400 | 受场地边界限制 |
| 冲刺持续时间 | `dash_duration` | 0.18 | 秒 | 完整冲刺所需时间 | 0.05—1 | 与距离共同决定速度 |
| 冲刺冷却 | `dash_cooldown` | 2.0 | 秒 | 单次充能恢复时间 | 0.1—20 | 多充能仍分别恢复 |
| 冲刺无敌时间 | `dash_invulnerability_seconds` | 0.18 | 秒 | 冲刺伤害免疫时间 | 0—1 | 通常不应超过冲刺持续时间太多 |
| Thunder 特效帧数 | `dash_thunder_frame_count` | 8 | 帧 | Thunder.png 实际切帧数（512×256 横向 8 列 64×256，从左到右播放） | 1—16 | 必须显式 play() 完整播放；最后一列近全透明作收尾帧 |
| Thunder 特效帧率 | `dash_thunder_fps` | 24 | FPS | Thunder 序列播放速度 | 4—60 | 与 Dash 位移/冷却/无敌完全解耦，仅控制视觉；动画播完才回收 Effect |
| 基础醒来长按（旧字段） | `base_wake_hold_seconds` | 5.0 | 秒 | 仅用于兼容旧配置，当前Dream不再读取 | 0.5—30 | Hold F Wake已停用 |
| 醒来慢动作倍率（旧字段） | `bullet_time_scale` | 0.20 | 比例 | 仅用于兼容旧配置，当前Dream不再读取 | 0.05—1 | 普通战斗慢动作/暂停逻辑不受影响 |

## 小手枪与光束武器

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 小手枪伤害 | `basic_weapon_damage` | 10 | HP | 单颗子弹伤害 | 1—1000 | 增伤卡作用于运行时数值 |
| 小手枪攻击间隔 | `basic_weapon_attack_interval` | 0.30 | 秒 | 两次实际发射的基础间隔 | 0.05—10 | 前额叶与攻速卡使用除法缩短 |
| 小手枪子弹速度 | `basic_projectile_speed` | 155 | px/s | 原始310 px/s基线的50%；不影响最大射程 | 20—2000 | 不影响最大射程 |
| 小手枪最大射程 | `basic_weapon_range` | 270 | px | 子弹累计飞行销毁距离 | 20—2000 | 枕叶强化增加该值 |

## 霰弹枪

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 单颗伤害 | `shotgun_pellet_damage` | 3 | HP | 每颗独立弹丸伤害 | 1—1000 | 9颗全中理论基础伤害27 |
| 弹丸数量 | `shotgun_pellet_count` | 9 | 颗 | 每轮完整齐射数量 | 1—32 | 数量过大会增加节点和碰撞检查 |
| 攻击间隔 | `shotgun_attack_interval` | 0.8 | 秒 | 两轮齐射间隔 | 0.05—20 | 意识漂移额外生成完整一轮 |
| 扩散角度 | `shotgun_spread_degrees` | 30 | 度 | 相对准星方向的总扇形角 | 0—180 | 每轮重新随机分布 |
| 弹丸速度 | `shotgun_projectile_speed` | 155 | px/s | 原始310 px/s基线的50%；每颗霰弹移动速度 | 20—2000 | 不影响散布角 |
| 最大射程 | `shotgun_max_distance` | 270 | px | 每颗霰弹累计飞行距离 | 20—2000 | 枕叶强化增加该值 |

## 太刀与剑气

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 太刀攻击间隔 | `katana_attack_interval` | 2.0 | 秒 | 近身斩击和剑气共用冷却 | 0.05—20 | 前额叶与攻速卡生效 |
| 近身斩击伤害 | `katana_melee_damage` | 30 | HP | 半径内全部敌人的单次伤害 | 1—5000 | 与剑气在同一攻击触发 |
| 近身斩击范围 | `katana_melee_radius` | 50 | px | 以玩家为圆心的斩击半径 | 5—500 | 枕叶强化增加该值 |
| 剑气伤害 | `katana_wave_damage` | 10 | HP | 穿透剑气对每名敌人的单次伤害 | 1—5000 | 同一道剑气按实例ID去重 |
| 剑气最终速度 | `katana_wave_speed` | 450 | px/s | Ease-In结束后的固定速度 | 20—3000 | 初速由比例参数计算 |
| 剑气最大距离 | `katana_wave_max_distance` | 300 | px | 累计飞行到该距离后销毁 | 200—1000 | 本次保持原值；枕叶强化仍按原规则加成 |
| 剑气宽度 | `katana_wave_width` | 32 | px | 同时控制视觉线段、碰撞形状和命中半径 | 4—200 | 当前为原16px的2倍，沿中心线两侧扩展 |
| 剑气初始速度比例 | `katana_wave_initial_speed_ratio` | 0.35 | 比例 | 刚发射时速度占最终速度的比例 | 0.1—1.0 | 越低起步越慢 |
| 剑气加速时间 | `katana_wave_acceleration_duration` | 0.25 | 秒 | 从初速达到最终速度所需时间 | 0.05—0.8 | 使用游戏时间，会随暂停和慢动作停止/减速 |
| 剑气加速曲线 | `katana_wave_acceleration_curve` | Ease-In | Curve | 控制速度随进度的变化形状 | 保持0—1输出 | 轨迹仍是直线，只改变速度；默认曲线近似二次Ease-In |
| 剑气素材朝向补偿角 | `katana_wave_texture_forward_angle_deg` | 180 | 度 | SP301_04 月牙素材默认尖端朝 -x，最终 rotation = 飞行方向角 + 本补偿角 | -180—180 | 保证视觉尖端/碰撞/运动方向三者一致；换剑气素材时只改本参数 |

## 敌人生成与敌人数值

- 当前唯一正式敌人场景为 `res://scenes/entities/employee_enemy.tscn`；所有正式生成入口统一实例化 `EmployeeEnemy`。
- `enemy_unlock_days` 与 `enemy_base_spawn_weights` 当前只包含 `employee`，旧七怪场景、独立生成器和专属投射物已经删除。
- 剧情房间使用 `story_enemy_health_multiplier`、房间人口上限与预警补充；Enemy AI、跨门、武器拾取、击倒、死亡身体部件与经验掉落继续由现行 Employee 系统处理。
- `difficulty_seconds_per_day` 仅保留给非房间兼容生成曲线；不代表旧怪物按日解锁。
## 经验、升级与掉落

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 1级升级需求 | `first_level_experience_requirement` | 20 | 经验 | 1级升2级所需经验 | 1—32767 | 后续等级使用增长底数 |
| 经验增长底数 | `experience_growth_base` | 8 | 底数 | n级升n+1级使用 `8^n` | 2—16 | 最终受阈值上限限制 |
| 单级经验上限 | `experience_requirement_cap` | 32767 | 经验 | 单级升级需求硬上限 | 1—2147483647 | 防止阈值溢出 |
| 每局老虎机重抽 | `slot_rerolls_per_run` | 1 | 次/Run | 三格锁定、非Jackpot且尚未领取时可重新滚动 | 0—3 | 使用后立即扣除，本Run后续升级不恢复 |
| 蓝卡概率 | `rarity_blue_probability` | 0.88 | 比例 | 蓝色候选抽取权重 | 0—1 | 三种权重共同归一化 |
| 紫卡概率 | `rarity_purple_probability` | 0.10 | 比例 | 紫色候选抽取权重 | 0—1 | 达上限技能会被排除 |
| 金卡概率 | `rarity_gold_probability` | 0.02 | 比例 | 金色候选抽取权重 | 0—1 | 无合法候选时沿用回退规则 |

## 经济与结局

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 初始余额 | `initial_balance` | 1325 | 元 | 新游戏初始现实货币 | 0—2,000,000,000 | 显示统一使用千位分隔符 |
| 每日基础工资 | `daily_base_wage` | 500 | 元 | 正常上班的完整工资 | 0—1,000,000 | 轻微迟到¥400、严重迟到¥250；星期日/旷工/失业为¥0 |
| 正常工资比例 | `wage_ratio_on_time` | 1.0 | 比例 | 07:30前起床工资比例 | 0—2 | 星期日和失业不发工资 |
| 轻微迟到比例 | `wage_ratio_slightly_late` | 0.8 | 比例 | 07:30—07:59工资比例 | 0—2 | 同时清零连续正常出勤数 |
| 严重迟到比例 | `wage_ratio_severely_late` | 0.5 | 比例 | 08:00—08:59工资比例 | 0—2 | 同时清零连续正常出勤数 |
| 旷工工资比例 | `wage_ratio_absent` | 0.0 | 比例 | 09:00后工资比例 | 0—2 | 同时清零连续正常出勤数 |
| 褪黑素价格 | `melatonin_price` | 100 | 元/片 | 速联跑腿购买价格 | 0—1,000,000 | 受库存上限限制 |
| 褪黑素库存上限 | `melatonin_inventory_cap` | 99 | 片 | 跨天库存最大值 | 1—999 | 与每晚上限是不同概念 |
| 每个完成日获得RAM | `ram_per_completed_day` | 1 | RAM/完成日 | 剧情正式完成一天时奖励 | 0—100 | 不读取等级或经验；按`last_ram_settled_story_day_id`防重 |
| 正常生活结局天数 | `normal_life_ending_required_workdays` | 14 | 工作日 | 连续正常上班达到该值触发结局 | 1—365 | 星期日保持计数，迟到/旷工/失业清零 |

## 手机外观相关参数

手机外壳资源为 `res://art/Badroom/Phone.png`，节点为 `BedroomPhone/PhoneShell`。图片保持160×336原始比例、关闭过滤，节点设置为忽略鼠标输入并绘制在运行时内容后方。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 手机宽度 | `phone_panel_width` | 160 | px | 手机UI根节点宽度 | 建议160 | 与Phone.png原始宽度一致 |
| 手机高度 | `phone_panel_height` | 336 | px | 手机UI根节点高度 | 建议336 | 与Phone.png原始高度一致 |
| 手机展开位置 | `phone_expanded_y` | 24 | 屏幕px | 展开后根节点Y坐标 | 0—80 | 24+336刚好落在360px画面底部 |
| 手机收起位置 | `phone_collapsed_y` | 319 | 屏幕px | 收起后只露出顶部的Y坐标 | 280—340 | 保留顶部与摄像头区域 |
| 主页收回热区高度 | `phone_upper_collapse_height` | 166 | px | 旧主页上半部收回点击范围（已被下方比例参数覆盖，仅保留兼容） | 100—169 | 最新规则以 `phone_retract_height_ratio` 为准 |
| 手机收起触发区比例 | `phone_retract_height_ratio` | 0.333333 | 比例 | 收起触发区 = 手机整体高度的顶部 1/3；仅背景空白生效，内容层优先；**交互区视觉完全隐藏**（无 hover 高亮/边框/色块），交互仍有效 | 0.1—1 | 下方 2/3 完全不触发收起；APP 图标/顶栏/列表/滑杆点击绝不收起 |

## 瞄准

所有武器统一调用 `res://scripts/entities/dream_player.gd` 中的 `get_aim_direction()`，当前正式实现读取鼠标世界坐标。准星、武器方向与实际攻击判定共用该方向；项目不再提供自动攻击模式。
### 弹匣与世界手持武器

Pistol、Shotgun、Assault Rifle使用统一弹匣；近战武器不使用弹药。弹量仅保存在`DreamPlayer.ammo_states`当前Run字典中，每个武器ID独立，换武器不会免费补弹，也不会写入跨天存档。Shotgun一次九弹齐射只在攻击入口扣1发。世界武器图标位于`DreamPlayer/WeaponRoot/HandAnchor/WeaponMotion/HeldWeaponSprite`，复用现有Weapon Icon、Nearest过滤；HandAnchor和所有Projectile Origin读取同一个瞄准方向。左向使用`flip_v`防止图标倒置；射击动画只移动`WeaponMotion`，不会推动Player或Camera。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 默认弹匣容量 | `default_weapon_magazine_size` | 12 | 发 | Pistol/Shotgun/Assault Rifle当前Run的独立弹匣容量 | 1—99 | 近战武器不读取 |
| 主动/自动换弹时间 | `weapon_reload_duration` | 0.75 | 秒 | 按R主动换弹或弹量归零自动换弹时，禁止攻击、360°手持武器旋转与补满弹匣的统一时长 | 0.3—5 | 使用游戏时间；进度条、旋转、补弹和禁止射击窗口读取同一参数 |
| 手持武器距离 | `held_weapon_distance` | 11 | px | 武器Icon中心及投射物挂点相对玩家的前向距离 | 4—24 | 不改变武器射程 |
| 世界武器缩放 | `held_weapon_world_scale` | 1.0 | 倍率 | UI Weapon Icon作为世界Sprite时的统一显示倍率 | 0.5—3 | Nearest过滤，建议整数或清晰倍率 |
| 武器后坐距离 | `weapon_recoil_distance` | 4 | px | 枪械图标沿瞄准反方向的局部位移 | 3—6 | 不移动Player Body |
| 后坐退出时间 | `weapon_recoil_kick_seconds` | 0.04 | 秒 | 图标快速退后的时长 | 0.03—0.06 | 新攻击会终止旧Tween |
| 后坐恢复时间 | `weapon_recoil_return_seconds` | 0.09 | 秒 | 图标回到HandAnchor的时长 | 0.06—0.12 | Katana复用作简短回摆 |
| 太刀手持摆角 | `katana_held_swing_degrees` | 18 | 度 | 太刀攻击时的简化Swing视觉 | 5—35 | 不改变近战/剑气判定 |

## 经验掉落层级

层级在 `res://scenes/dream/dream_world.tscn` 中使用容器 `z_index` 固定：背景为0、`PickupContainer`为1、`EnemyContainer`为2、玩家为3、投射物与战斗特效为4、UI使用CanvasLayer 20。经验节点和拾取脚本未改变，只移动其绘制容器，因此吸附、碰撞距离和经验结算规则保持不变。

旧 XP 视觉资源仍保留在 `res://art/icon/EXP/` 与 `res://scripts/entities/xp_gem.gd` 供手动/兼容测试使用；正式 Dream 不再创建、拾取或累计 XP Gem。

## 打击感与集中音效

统一音效入口为 `res://scripts/audio/sfx_manager.gd`。已有导入音效继续使用 `res://sfx/`；`ui_hover`、`dash`、`player_hurt`、`weapon_fire`、`pistol_fire`、`shotgun_fire`、`enemy_kill` 当前由管理器集中生成原创8-bit占位声，不存在每个按钮单独建立管理器的情况。事件分别进入UI、Characters或Weapons总线，替换正式素材时只需改管理器事件映射。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| UI悬停音量 | `sfx_ui_hover_volume_db` | -27 | dB | 首次进入可交互选项时的低频电子提示 | -35—-16 | 离开后再次进入才会重播；与确认音分开 |
| 冲刺音量 | `sfx_dash_volume_db` | -12 | dB | 成功开始冲刺时播放 | -30—0 | 冷却中或被边界阻止时不播放 |
| 玩家受伤音量 | `sfx_player_hurt_volume_db` | -12 | dB | 非致命有效伤害或解离复活反馈 | -30—0 | 正式死亡仍使用独立`death`事件 |
| 通用武器发射音量 | `sfx_weapon_fire_volume_db` | -17 | dB | 太刀的占位挥击声 | -35—0 | 手枪和霰弹枪已使用各自事件 |
| 敌人击杀音量 | `sfx_enemy_kill_volume_db` | -14 | dB | 敌人正式进入死亡流程时播放 | -30—0 | 同一事件复用单播放器，避免叠加爆音 |
| 命中顿帧时长 | `hit_stop_duration` | 0.04 | 秒 | 有效命中产生的极短时间压缩 | 0.03—0.06 | 使用忽略时间倍率的恢复计时器；菜单和醒来长按时不触发 |
| 顿帧最短间隔 | `hit_stop_minimum_interval` | 0.09 | 秒 | 限制高频命中连续顿帧 | 0.05—0.25 | 霰弹多目标命中共享节流 |
| 顿帧时间倍率 | `hit_stop_time_scale` | 0.05 | 比例 | 顿帧期间场景速度 | 0.01—0.2 | UI仍可处理；退出梦境会强制恢复1.0 |
| 敌人受击挤压 | `enemy_hit_scale_amount` | 0.16 | 比例 | 视觉子节点的短促横向拉伸/纵向挤压 | 0.05—0.3 | 不缩放碰撞体，不改变实际移动 |
| 敌人视觉击退 | `enemy_hit_visual_knockback_pixels` | 6 | px | 命中后精灵层的短促反馈 | 0—14 | 与真实物理击退并存，不改变碰撞体大小 |
| 敌人物理击退速度 | `enemy_knockback_strength` | 96 | px/s | 非致死命中时从攻击源向外施加初始速度 | 0—240 | 统一入口`BaseEnemy.apply_knockback()`，墙和关闭门通过move_and_slide阻挡 |
| 敌人物理击退时长 | `enemy_knockback_duration` | 0.14 | 秒 | 真实击退快速衰减后恢复AI的时间 | 0.08—0.2 | 特殊敌人状态机先处理击退再恢复；触手Resistance=1.0，仅保留视觉反馈 |
| 击杀/掉落弹出时间 | `kill_pop_animation_seconds` | 0.24 | 秒 | 解体特效与经验弹出动画时长 | 0.12—0.5 | 只影响视觉，不延后掉落结算 |
| 受伤屏幕闪光强度 | `player_hurt_screen_flash_alpha` | 0.24 | Alpha | 有效受伤时覆盖画面的红色闪光 | 0—0.5 | UI绘制在闪光之上 |
| 受伤屏幕闪光时长 | `player_hurt_screen_flash_seconds` | 0.12 | 秒 | 红色闪光淡出时间 | 0.05—0.35 | 无敌帧闪烁仍由玩家脚本负责 |

UI悬停入口已覆盖主菜单、设置开关、卧室对话选项、升级卡片/刷新、手机应用、主菜单眠网升级按钮、速联跑腿购买按钮与武器选择卡。手机点击仍使用 `phone_operation`，购买成功/失败仍分别使用 `purchase` / `forbidden`，避免同一次点击重复播放确认音。

## Employee像素素材与动画

- 当前唯一正式敌人使用 `res://art/Dream/enemy/Employee_men_32x32.png`；Employee 场景运行时拆分为 `LeftFoot`、`RightFoot`、`Head`、`Body`、`LeftHand`、`RightHand`。头部使用第2列三帧（右侧透明边裁掉），身体使用第3列，脚/手使用第4/5列的实际非透明组件区域。
- 角色内部顺序为 Feet → Head → Body → Hands，WeaponRoot 只在角色内部位于前景；CharacterVisual 与 WeaponRoot 保持同一 Actor YSort 带，家具和门前景仍可正确遮挡。
- 旧 Slime、Flying Eye、Huntress、Mushroom、Mimic、Tentacle 场景及其专属动画配置已经退出正式运行链。
## 像素角色、武器特效与音频质感

配置路径统一为 `res://resources/demo_config.tres`，字段声明位于 `res://scripts/data/demo_config.gd`。下列参数在重新进入梦境后生效；音频总线滤波参数需要重新启动游戏。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 玩家视觉缩放 | `player_visual_scale` | 1.0 | 倍 | Player 与 EmployeeEnemy 共用的 32px→1 gameplay cell 基准视觉倍率 | 0.5—1.5 | 只对CharacterVisual/HealOverlay使用绝对值；3D Bridge 不再追加倍率，不放大碰撞 |
| 玩家碰撞半径 | `player_collision_radius` | 7.5 | px | 配合缩小后的身体核心碰撞 | 5—12 | Collider与视觉同步缩小，不能按透明画布计算 |
| 玩家碰撞偏移 | `player_collision_offset` | `(0,-13)` | px | 将圆形身体碰撞对齐缩小后的躯干 | — | 玩家世界原点仍为脚底附近 |
| 玩家武器根偏移 | `player_weapon_root_offset` | `(0,-18.25)` | px | 统一控制子弹、太刀及瞄准挂点 | — | 不改变任何武器数值 |
| 敌人视觉缩放组 | `slime/flying_eye/huntress/mushroom/mimic/tentacle_visual_scale` | 0.60/0.76/1.02/0.96/1.68/1.0 | 倍 | 各素材统一缩放入口（绝对最终值，运行时不二次乘倍率；自爆蘑菇已基于上一版 0.48 ×2 = 0.96） | 0.02—2 | 只改视觉；碰撞体按身体核心单独适配；精英魔眼使用独立 `large_correction_visual_scale`=1.0；运行时不二次乘倍率 |
| 玩家待机帧率 | `player_idle_animation_fps` | 1 | FPS | 四方向待机动画速度 | 0.5—4 | 当前每个方向使用一帧，为后续增帧保留接口 |
| 玩家行走帧率 | `player_walk_animation_fps` | 8 | FPS | 四方向四帧行走循环速度（每行第2帧起，首帧为该方向静止） | 4—12 | 不改变实际移动速度 |
| 恢复绿色提示时长 | `heal_feedback_seconds` | 0.3 | 秒 | 真实回血时角色身上的绿色 modulate 提示持续时间 | 0.1—1 | 连续回血刷新时长；与 Heal 动画/恢复 SFX 同步触发 |
| 恢复音效音量 | `sfx_heal_volume_db` | -8 | dB | 统一 Heal 入口的恢复音效（程序化升调 blip，Characters 总线） | -30—-6 | 待人工替换 `res://sfx/heal.wav` 时仅需改 STREAMS |
| 枪口闪光时长 | `weapon_muzzle_flash_seconds` | 0.07 | 秒 | 手枪和霰弹枪像素枪口反馈 | 0.03—0.15 | 仅视觉，受暂停与慢动作影响 |
| 命中特效时长 | `weapon_hit_effect_seconds` | 0.14 | 秒 | 非致命命中的像素碎片与闪光 | 0.06—0.3 | 击杀仍使用 `kill_pop_animation_seconds` |
| 子弹拖尾长度 | `projectile_trail_length` | 10 | px | 小手枪与霰弹丸的冷色像素轨迹 | 2—24 | 不改变射程或碰撞判定 |
| 太刀残影时间 | `katana_afterimage_seconds` | 0.20 | 秒 | 挥刀弧线多层残影持续时间 | 0.08—0.4 | 不改变近战范围和剑气规则 |
| 模块化行走周期 | `player_walk_cycles_per_second` | 1.5 | 次/秒 | 控制腿部交替和CharacterVisual上下抖动频率 | 0.5—4 | 由3.0减半；不改变112px/s移动速度，Offset继续取整 |
| 踢击最大后仰 | `kick_body_max_lean_degrees` | 45 | 度 | 踢击发力顶点BodyPivot与HeadPivot的最大反向倾斜 | 0—60 | 由动作进度渐入/渐出，结束恢复Scene保存的基础Rotation |
| 地面武器交互半径 | `world_weapon_interaction_radius` | 34 | px | 靠近Weapon Room地面武器时显示F交换提示 | 16—64 | 交互优先于同键踢击 |
| 旧武器落地点偏移 | `world_weapon_drop_offset` | 28 | px | 交换时尝试把旧武器放到玩家身后或侧后方 | 12—64 | 会检查墙、家具和其它武器碰撞 |
| 旧武器轻推冲量 | `world_weapon_swap_drop_impulse` | 45 | impulse | 交换后旧武器轻微滑向玩家后方 | 0—160 | 低于正式Kick冲量，不造成家具撞击伤害 |
| 地面武器质量 | `world_weapon_mass` | 0.65 | kg(物理相对值) | 世界武器RigidBody2D推动和踢击手感 | 0.1—4 | 属于Props物理层，不可破坏 |
| UI悬停音量 | `sfx_ui_hover_volume_db` | -27 | dB | 老式电子菜单短促反馈音量 | -35—-16 | 音高由 `sfx_ui_hover_tone_hz` 控制 |
| UI悬停音高 | `sfx_ui_hover_tone_hz` | 260 | Hz | 限制悬停提示的基础频率 | 160—480 | 越高越明亮，当前值主动避开刺耳高频 |
| 手枪发射音量 | `sfx_pistol_fire_volume_db` | -20 | dB | 轻、快、机械式8-bit发射声 | -30—-10 | 进入Weapons总线低通 |
| 霰弹枪发射音量 | `sfx_shotgun_fire_volume_db` | -16 | dB | 较厚的低频多层占位发射声 | -26—-8 | 进入Weapons总线低通 |
| 武器低通截止频率 | `sfx_weapon_lowpass_cutoff_hz` | 3400 | Hz | 统一削弱枪械与光束的刺耳高频 | 1800—6000 | 影响Weapons总线，修改后需重启 |

统一视觉主色为 `#517B98`，由 `weapon_effect_primary_color` 控制；辅助色默认 `#9AB6C8`，警告色默认 `#9B4658`。三个颜色均只影响新增占位特效，不改伤害、射程或命中规则。

## 统一音量设置

运行时管理器位于 `res://scripts/app/settings_manager.gd`，玩家设置保存在 `user://game_settings.cfg`。主菜单、手机设置应用和暂停菜单都直接读写这一管理器；修改立即作用于Audio Bus，无需重新启动。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 总音量 | `master_volume` | 100 | % | 控制Master总线，影响全部声音 | 0—100 | 0会静音Master；玩家设置，不在`demo_config.tres`中 |
| 音乐音量 | `music_volume` | 70 | % | 控制Music总线 | 0—100 | Music发送到Master；当前没有改变音乐播放逻辑 |
| 音效音量 | `sfx_volume` | 80 | % | 控制SFX总线及其UI、Weapons、Characters、Environment子总线 | 0—100 | 0会静音全部音效，但不改各事件自身dB配置 |


## 像素UI参数

以下字段位于 `res://resources/demo_config.tres`，重新打开对应界面后生效。全局按钮、面板、滑轨和复选框样式位于 `res://assets/fonts/pixel_theme.tres`。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| UI边框颜色 | `ui_border_color` | `#517B98` | 颜色 | 升级卡片和主要交互边框 | 低饱和冷色 | 与统一主题主色保持一致 |
| UI面板背景 | `ui_panel_background_color` | `#121722` | 颜色 | 卡片和弹窗的深色底色 | 深蓝灰 | 不建议使用高亮或高饱和颜色 |
| 升级卡片尺寸 | `ui_card_size` | `184×190` | px | 三选一卡片的固定尺寸 | 宽160—196，高170—210 | 三张卡片会在640px画面内自动居中 |
| UI悬停亮度 | `ui_hover_brightness` | 0.10 | 比例 | 卡片悬停时的轻微变亮 | 0—0.25 | 不生成白框或圆角现代高亮 |
| 手机应用悬停亮度 | `phone_app_hover_brightness` | 0.12 | 比例 | 手机像素图标与文字的悬停反馈 | 0—0.25 | 鼠标离开后恢复原色 |

## 玩家Sprite稳定性

- Sprite资源：`res://assets/characters/player/pix_chr_atlas.png`（源自 `art/Chr/Pix_chr.png`，4 行×5 列：前/左/后/右 × 5 帧）
- 场景节点：`res://scenes/entities/dream_player.tscn`中的`Visual`
- 帧区域：所有动画帧固定为`26×50 px`（内容 24×48 + 四周 1px 透明 padding，供 1px 描边采样）
- 可见角色高度：所有方向、所有帧内容固定为`48 px`，统一 Canvas 与脚底 Pivot，切换动画不抖
- 缩放参数：`player_visual_scale=0.75`（由上一版1.0一次性调整为75%，用绝对值设置；视觉锚点为`(0,-18.25)`）。
- 身体碰撞：圆形半径 10、中心 `(0,-8)`，贴合身体核心而非整张透明 Canvas
- 武器挂点：`get_weapon_origin()` = 玩家原点 + `(0,-14)`（躯干中心），只影响视觉出生位置
- 行走帧率：`player_walk_animation_fps=7`
- 待机帧率：`player_idle_animation_fps=1`

`walk_right`与`idle_right`复用左向侧身帧并通过`AnimatedSprite2D.flip_h`镜像，避免原右向素材本体尺寸偏小。缩放只在进入梦境配置角色时设置一次；运行时不逐帧改写`scale`。动画只切换固定64×64 Atlas区域，修改缩放倍率后需要重新进入梦境。

## 当天开始快照

快照实现位于 `res://scripts/app/day_start_snapshot.gd`。进入新一天时复制局外状态并写入正常存档；卧室购买、服药和本局梦境状态只修改当日工作副本。通过暂停菜单退出到主菜单时，工作副本被快照覆盖，因此继续游戏回到当天21:00开始状态。设置由独立的SettingsManager永久保存，不参与快照回滚。

## 卧室底边与廉价便当

配置路径统一为 `res://resources/demo_config.tres`，字段声明位于 `res://scripts/data/demo_config.gd`。门口/外卖交互已从屏幕左侧迁移到屏幕底部：交互节点为 `res://scenes/bedroom/bedroom.tscn` 的 `Layout/BottomEdgeInteraction`（脚本 `res://scripts/bedroom/door_interaction.gd`，对白与取餐逻辑不变）；配送状态使用 `NONE`、`DELIVERING`、`WAITING_AT_DOOR`、`RECEIVED` 四个明确值。

交互区域限定在**屏幕底部横带**（640×360 下为 Rect(173.3, 300, 213.3, 60)，中心 x=280px、高60px、宽度保持中间三分之一），左右边界外不触发悬停、点击与光效。光效为**底部真径向半圆白光**（`res://shaders/door_glow_semicircle.gdshader`，由脚本内动态 ColorRect 承载），几何由集中参数控制：水平直径 = 视口宽 × `bottom_glow_width_ratio`（默认 0.59375，640 下宽 380px、半径 190px），高度 = 半径 × `bottom_glow_height_multiplier`（默认 0.631579，即高 120px 的椭圆半光，只向上变化），圆心 x = 视口宽 × `bottom_glow_center_x_ratio`（默认 0.5），底边贴屏幕底；圆心即局部 UV(0.5,1.0)。Shader 由脚本传入 `rect_size` 重建真实像素坐标并按椭圆距离计算 alpha（`vertical_scale` 只拉伸垂直方向距离，水平半径仍为 outer_radius，左右边界处 alpha 仍为 0；ColorRect 无纹理，`TEXTURE_PIXEL_SIZE` 不可用，禁用圆角 Panel/GradientTexture2D 拉伸/白色 PNG 伪装），`alpha = 1 - smoothstep(inner_radius, outer_radius, dist)` 且 dist≥outer 强制为 0（半圆外与上方两角完全透明，不是方块），像素空间距离天然 aspect 正确；峰值 alpha 0.32，距离按 `door_glow_pixel_step_size`=4px 轻微量化出像素风同心环。交互区（BottomEdgeInteraction）不随视觉高度扩大，仍为原底部横带。旧横向分段光条与 `door_glow_width` 配置已删除。

外卖到达（`WAITING_AT_DOOR`）后在底部中央交互区上方同时显示像素字体文字“**有人敲门**”与**朝下往返箭头**（现有像素字体/UI 文字色、水平居中、无气泡框；箭头只做垂直往返，往返距离 `delivery_arrow_bounce_distance_px`=5px、单次往返周期 `delivery_arrow_bounce_duration`=0.65s，偏移逐帧取整为整数像素，无 Blur/旋转/横漂）；等待期间白光不依赖鼠标悬停保持可见（strength 取 max(悬停, 等待) 再乘等待倍率）。不恢复旧包裹/外卖图标。领取后或手机/电脑/弹窗等 Modal UI 打开时文字、箭头与白光同时立即隐藏（状态不丢失，关闭后若仍在门口则重新显示；手机展开完全阻断输入）。敲门音效保留：`DELIVERING → WAITING_AT_DOOR` 转换时播放一次（`bedroom.gd _update_delivery()` 内 `SFX.play_door_knock()`）。

可用条件由 `bedroom.gd can_use_bottom_edge_interaction()` 统一判断：场景输入锁定、手机展开或未完全收回、电脑界面、确认对话框、褪黑素界面任一存在时禁用并隐藏白光，不依赖视觉遮挡阻断输入。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 底边热区高度 | `bottom_edge_interaction_height` | 60 | px | 屏幕底部可悬停与点击的交互条高度 | 16—120 | 交互区中心 x=280px；仅手机完全收回且没有弹窗时可点击 |
| 交互区左边界比例 | `bottom_interaction_horizontal_start_ratio` | 0.270833 | 比例 | 交互区水平起点（视口宽度比例） | 0—1 | 与右边界共同限定中心 x=280px、宽中间三分之一 |
| 交互区右边界比例 | `bottom_interaction_horizontal_end_ratio` | 0.604167 | 比例 | 交互区水平终点（视口宽度比例） | 0—1 | 白光与点击均只在此范围内生效 |
| 门口白光透明度 | `door_glow_opacity` | 0.32 | Alpha | 悬停半圆白光峰值强度 | 0.10—0.60 | 到货时再乘等待倍率；保持低饱和氛围不变成纯白块 |
| 白光淡入时间 | `door_glow_fade_in_seconds` | 0.16 | 秒 | 鼠标进入后的亮起时间 | 0.05—0.5 | 受场景暂停影响 |
| 白光淡出时间 | `door_glow_fade_out_seconds` | 0.24 | 秒 | 鼠标离开后的消退时间 | 0.05—0.8 | 手机展开后立即以该速度淡出 |
| 到货白光倍率 | `door_waiting_glow_multiplier` | 1.55 | 倍 | 便当等待领取时强化门口半圆光 | 1.0—2.5 | 手机打开时文字与光均隐藏，不能领取 |
| 白光像素量化步长 | `door_glow_pixel_step_size` | 4 | px | 半圆光距离量化的同心环宽度 | 0—12 | 0=不量化；不可过强，保持柔和渐变 |
| 半圆白光宽度比例 | `bottom_glow_width_ratio` | 0.59375 | 比例 | 半圆水平直径 = 视口宽 × 本值 | 0.05—1 | 0.59375 即 640 下宽 380px |
| 半圆白光圆心比例 | `bottom_glow_center_x_ratio` | 0.5 | 比例 | 圆心 x = 视口宽 × 本值，底边贴屏幕底 | 0—1 | 0.5 即屏幕底部中央 |
| 半圆白光高度倍率 | `bottom_glow_height_multiplier` | 0.631579 | 倍 | 半圆高度 = 水平半径 × 本值，只向上变化 | 0.1—4 | 0.631579 即半径190px、高120px；交互区不随之变化 |
| 敲门箭头往返距离 | `delivery_arrow_bounce_distance_px` | 5 | px | 朝下箭头垂直往返幅度（整数像素） | 4—6 | 不产生横漂/旋转/Blur |
| 敲门箭头往返周期 | `delivery_arrow_bounce_duration` | 0.65 | 秒 | 单次完整往返时长 | 0.5—0.8 | 领取/Modal 打开时箭头立即隐藏 |
| 廉价便当价格 | `cheap_meal_price` | 200 | 元 | 速联跑腿购买时立即扣除的金额 | 0—10,000 | 使用统一货币格式；余额不足播放禁止音 |
| 配送时间 | `cheap_meal_delivery_seconds` | 5.0 | 秒 | 从购买成功到进入等待领取状态的时间 | 1—60 | 到时只触发一次独立`door_knock`事件 |
| 每日购买上限 | `cheap_meal_daily_purchase_limit` | 1 | 份/日 | 限制廉价便当当天购买数量 | 当前建议1 | 新一天重置购买计数；本阶段不建立食物背包 |
| 敲门音量 | `sfx_door_knock_volume_db` | -13 | dB | 配送完成时的原创8-bit占位敲门声 | -30—0 | Environment Bus；与枪声、UI音分离 |

每日字段 `cheap_meal_purchased_today`、`cheap_meal_purchases_today`、`food_eaten_today`、`hungry_bed_attempts_today`、`delivery_state` 和 `delivery_seconds_remaining` 会进入当天工作副本与快照。新一天重置；退出到主菜单会恢复当天21:00快照，从而撤销未提交的购买、扣款、配送和进食状态。

## 空腹入睡

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 空腹最终伤害倍率 | `hungry_damage_multiplier` | 0.5 | 倍 | 统一作用于全部玩家武器与意识漂移额外攻击 | 0.1—1.0 | 最终伤害最低为1；不改武器面板基础值 |
| 强制入睡前阻止次数 | `hungry_bed_attempts_before_force` | 2 | 次 | 前两次提示买食物，第三次开始允许确认空腹入睡 | 1—5 | 同一对话只计一次，吃饭后归零 |
| 空腹压力增加 | `stress_hungry_sleep_gain` | 10 | 点 | 确认空腹入睡时增加压力值 | 0—100 | 只在正式进入睡眠时应用一次 |

空腹局字段为 `is_hungry_run`。它只在当前梦境使用：`DreamPlayer.calculate_player_damage()`应用统一0.5倍率，`set_dash_enabled()`同时检查空腹禁用标记，因此空格不会移动、播放音效、消耗充能或获得冲刺无敌帧。HUD显示固定尺寸的“SPACE / 空腹”禁用像素按钮。新一天会重置该字段。

## 压力值与梦境难度

压力值 `stress_value` 写入跨天存档，数值越高状态越差。所有变化统一经过 `GameStateRules.change_stress()`，范围钳制为0—100。进入梦境时复制为 `run_stress_value`，当局不实时跳档。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 初始压力值 | `stress_default` | 0 | 点 | 新游戏及旧存档缺字段时的默认值 | 0—100 | 卧室显示`0 / 100` |
| 压力上限 | `stress_max` | 100 | 点 | 所有压力变化的上限 | 建议100 | 下限固定为0 |
| 迟到压力增加 | `stress_late_gain` | 10 | 点/工作日 | 轻微或严重迟到一次性增加 | 0—100 | 两种迟到不叠加 |
| 旷工压力增加 | `stress_absent_gain` | 30 | 点/工作日 | 旷工一次性增加 | 0—100 | 正常上班不改变压力 |
| 吃饭压力减少 | `stress_food_reduction` | 10 | 点/份 | 食用完成时减少压力 | 0—100 | 购买、送达和开门本身不结算 |
| 褪黑素压力减少 | `stress_melatonin_reduction` | 5 | 点/片 | 完整动画、库存扣除时同步减少压力 | 0—30 | 取消或中断不结算 |
| 提前醒来分界 | `early_wake_stress_start_before_alarm_minutes` | 30 | 分钟 | 闹钟前30分钟为压力不变分界 | 0—180 | 严格早于分界才计算；星期日不结算 |
| 提前醒来分段 | `early_wake_stress_block_minutes` | 30 | 分钟 | 早于分界后按完整分段计算 | 1—180 | 余下不足一段不计算 |
| 每段增加 | `early_wake_stress_gain_per_block` | 2 | 点 | 每个完整30分钟增加压力 | 0—20 | 以当前06:00剧情闹钟为基准 |
| 单局提前醒来上限 | `early_wake_stress_max_gain` | 10 | 点 | 限制单局最多增压 | 0—100 | 死亡使用原始`dream_end_minutes`计算，死亡延迟只影响最终起床时间 |
| 刷新阈值 | `stress_threshold_spawn` | 30 | 点 | 压力高于30启用1.5倍刷新 | 1—99 | 0—30保持1.0倍 |
| 移速阈值 | `stress_threshold_speed` | 50 | 点 | 压力高于50启用2.0倍刷新和1.5倍移速 | 1—99 | 与快速眼动倍率乘算 |
| 视野阈值 | `stress_threshold_vision` | 70 | 点 | 压力高于70启用2.5倍刷新、1.5倍移速及视野限制 | 1—99 | 档位互斥，只使用最高档 |
| 高于30刷新倍率 | `stress_spawn_multiplier_over_30` | 1.5 | 倍 | 当前刷新间隔除以倍率 | 1.0—3.0 | 不改变每批数量和场上上限 |
| 高于50刷新倍率 | `stress_spawn_multiplier_over_50` | 2.0 | 倍 | 当前刷新间隔除以倍率 | 1.0—4.0 | 仍受绝对最小间隔限制 |
| 高于70刷新倍率 | `stress_spawn_multiplier_over_70` | 2.5 | 倍 | 最高压力档刷新倍率 | 1.0—5.0 | 仍受绝对最小间隔限制 |
| 高于50敌人移速 | `stress_enemy_speed_multiplier_over_50` | 1.5 | 倍 | 基础追踪和冲刺移动倍率 | 1.0—3.0 | 不加速投射物 |
| 高于70敌人移速 | `stress_enemy_speed_multiplier_over_70` | 1.5 | 倍 | 最高压力档移动倍率 | 1.0—4.0 | 与快速眼动倍率乘算 |
| 绝对最小刷新间隔 | `stress_absolute_minimum_spawn_interval` | 0.25 | 秒 | 压力倍率计算后的硬下限 | 0.1—1.0 | 防止0秒或无限生成 |
| 梦境环境色 | `dream_ambient_color` | `#26313F` | 颜色 | CanvasModulate对世界地图、敌人、弹丸和掉落物的基础暗化 | 深灰蓝、避免纯黑 | HUD位于独立CanvasLayer，不受影响 |
| SoftGlow参考半径 | `player_light_radius` | 104 | 世界px | 历史字段名；只作为XP/Heart绘制光晕的尺寸参考 | 48—240 | 不创建或控制任何Light2D |
| SoftGlow参考颜色 | `player_light_color` | `#E7F0F8` | 颜色 | 历史字段名；只作为非照明绘制光晕的冷色参考 | 接近白色 | 不会照亮墙、地面或其它Sprite |
| 失业压力阈值 | `stress_unemployment_threshold` | 90 | 点 | 每日结算后达到该值计为一个高压力日 | 1—100 | 星期日也计数，同一天只检查一次 |
| 失业连续天数 | `stress_unemployment_required_days` | 3 | 日历日 | 连续达到阈值后永久失业 | 1—14 | 失业后所有出勤工资为0并清除正常出勤连胜 |

梦境只保留 `DreamWorld/DreamLighting/CanvasModulate` 的全局冷色调，它不是局部光源。Player、Enemy、Projectile、XP、Heart和Weapon Drop均不含运行时`Light2D/PointLight2D`。`SoftGlow`仍可绘制不影响周围场景的低成本圆形光晕；高压力仅影响刷怪与敌人数值，不再改变视野灯半径。

## 对话立绘统一描边与冷蓝滤镜

所有正式对话立绘共用 `ConfirmationDialog/Portrait/CharacterArt`，材质使用 `res://shaders/sprite_alpha_outline.gdshader`。`dialogue_portrait_outline_color=#346DB3`、`dialogue_portrait_outline_width_px=2.0`；`dialogue_portrait_filter_color=#8DB9D8`、`dialogue_portrait_filter_strength=0.18`只给主体做轻度冷蓝调和，不覆盖描边。运行时按完整2560×1440画布到640×360显示比例换算描边采样宽度。`chr.png`与两张Talk纹理只替换同一节点的Texture，不改变Position、Anchor、Offset、Scale或Material。说话帧由逐字Reveal驱动：第1—2个可见字符使用Talk A，第3—4个使用Talk B，以此循环；空白和控制字符不计数，句末或跳过立即恢复`chr.png`。当前三张源PNG的角色下缘贴到画布底边，因此Portrait启用`outline_inner_at_texture_edge`：普通透明区域仍向外描边，纹理边界处以同宽内描边补偿，不修改源PNG、不缩放或移动构图。

## 战斗辨识与升级老虎机

- 普通弹丸、霰弹弹丸和剑气不再使用PointLight2D、SoftGlow、Emission或Halo；弹丸视觉为普通像素Sprite/单层贴图。
- `pickup_glow_alpha=0.18`、`pickup_glow_radius=10px`：Heart等通用拾取物光晕，仍受梦境环境压暗。
- `xp_glow_alpha=0.30`、`xp_glow_radius=5px`：EXP局部光晕的透明度与半径（直径约10px）；蓝色与紫色EXP使用各自的稀有度颜色，不使用`PointLight2D`。
- `electric_shield_animation_fps=30`、`electric_shield_visual_scale=0.18`：意识固化电气护盾60帧循环的帧率与独立视觉节点缩放，不影响护盾挡伤机制。
- 老虎机CRT使用`res://shaders/upgrade_slot_crt.gdshader`的`barrel_distortion=0.075`，仅扭曲最终视觉采样，卡片、重抽按钮与描述区仍使用未扭曲的Control坐标接收输入。
- `player_hp_bar_width=30px`、`player_hp_bar_height=5px`、`player_hp_bar_visible_duration=2.5秒`：玩家世界血条只在实际受伤后出现，回血只刷新已显示填充；玩家Sprite尺寸不受影响。
- `enemy_hp_bar_width=20px`、`enemy_hp_bar_height=3px`、`enemy_hp_bar_bottom_margin=2px`、`enemy_hp_bar_visible_duration=2.5秒`：敌人出生时隐藏，非致死实际伤害后在碰撞核心下缘显示；死亡立即隐藏。所有敌人复用同一轻量World Bar脚本，无独立Timer、CanvasLayer或Shader。
- `dialogue_text_blip_volume_db=-25dB`、`dialogue_text_blip_frequency_hz=420Hz`、`dialogue_text_blip_duration=0.045秒`：每个可见字符由SFX单播放器重触发原创短音。
- 升级老虎机每次打开从`upgrade_reel_start_speeds=(84,92,78)px/s`开始，使用原有`upgrade_reel_acceleration_curve`的Quadratic Ease-In在`upgrade_reel_acceleration_duration=1.35秒`内加速到`upgrade_reel_max_speeds=(440,472,416)px/s`，之后保持上限。两组速度均为上一版实际值的2倍；锁定仍由`upgrade_slot_lock_deceleration=0.16秒`短暂Ease-Out并吸附完整Cell。
- 每跨过一个完整Cell触发原创程序化`slot_tick`（45ms、`sfx_slot_tick_volume_db=-28dB`、`sfx_slot_tick_min_interval=0.025秒`），走UI/SFX总线，单播放器重触发避免三列叠音爆音。锁定格子的名称和描述直接读取同一个Upgrade/Weapon字典。
- CRT覆盖`UpgradePanel/CRTOverlay`（Y=94—316），参数为Scanline `0.10`、Noise `0.025`、Vignette `0.14`；Reel高度调整为174px，Hover描述矩形Y=282—306完整包含在Overlay安全区，并与底边保留10px，因此屏幕上只保留参与Barrel Distortion的一份可读描述。Overlay忽略鼠标，Shader不改变Control输入坐标，暂停期间仍由GPU时间更新。
- 剧情模式武器分离为解锁资格和当前装备：存档字段`current_weapon_id`默认`basic`并跨天/死亡保留。本局`used_weapon_reward_ids`在开始时加入初始武器，真正选择并装备新武器后再加入；这些武器随后从本局老虎机池排除。仅滚到、锁定或Reroll不会加入，下一局重新初始化。
- 原`chest`房间类型已由`weapon`正式替代，模板为`res://scenes/dream/rooms/room_weapon_01.tscn`。`WeaponSpawn_01=(272,180)`、`WeaponSpawn_02=(368,180)`各生成一件不同的`WorldWeaponPickup`；它们是Props层的不可破坏RigidBody2D，可推、可踢但不具备家具高速撞击伤害。靠近时F优先交换，当前武器写回同一地面节点，因此另一个武器不会消失；RoomManager缓存房间实例，武器ID、物理位置与交换结果在本局重入时保持。
- 剧情老虎机/宝箱卡片只保存在当前`DreamWorld.skill_levels`，只在当前Dream内累计并参与Max过滤；Dream结束后随场景释放，下一次Story Dream从空字典开始。旧档的`story_upgrade_levels`仅用于安全迁移后删除，不再恢复或写回。眠网RAM升级仍由`persistent_day_state.permanent_upgrades`永久保存。
- 升级面板Root以`y=390`为离屏位置，`upgrade_panel_enter_seconds=0.42秒`Ease-Out滑入；领取后保留`upgrade_reward_confirm_seconds=0.20秒`反馈，再以`upgrade_panel_exit_seconds=0.32秒`Ease-In滑出，完全离屏后才恢复战斗。面板底层使用程序化16束低透明度旋转放射光，普通状态为冷蓝，Passive三同Jackpot切换蓝/紫/青/粉/黄低频彩色状态；CRT仍只覆盖主体屏幕并位于放射光上层。

## 电脑21点

- 场景：`res://scenes/ui/blackjack_app.tscn`，作为`ComputerOverlay/BlackjackApp`子页面；没有第二套电脑、时间或货币管理器。
- 权威货币：剧情存档`persistent_state.balance`。下注开始时一次性扣除并立刻锁定Round，余额不足/重复Deal均不会扣款；结算由`round_settled`保证一次。
- 筹码：`blackjack_chip_values=[10,50,100,500]`；余额不足的筹码不可点。普通胜利返还2倍Stake（净赢1:1），Push返还Stake，输牌不返还，Natural按`blackjack_natural_payout_ratio=1.5`净赢3:2。
- 庄家在`blackjack_dealer_stand_value=17`或以上停牌，包含Soft 17；A自动按1/11最佳值，J/Q/K为10。
- 时间来源：`Bedroom.current_minutes`每帧同时传入`BedroomPhone.set_bedroom_time()`和`ComputerOverlay.set_bedroom_time()`；手机、电脑顶栏、电脑任务栏及21点期间始终显示同一24小时制时间。

## 暂停、失业与武器解锁

统一暂停管理器为 `res://scripts/app/pause_manager.gd`，自动加载名称为`PauseManager`。`UPGRADE`、`ESC_MENU`、`DIALOGUE`与`MODAL_ANIMATION`等原因独立持有；关闭界面只能释放自己的原因。战斗容器为`PROCESS_MODE_PAUSABLE`，升级UI为`PROCESS_MODE_WHEN_PAUSED`，暂停菜单为`PROCESS_MODE_ALWAYS`。

- 小手枪默认解锁。
- `shotgun_unlocked`：第2天永久解锁。
- `katana_unlocked`：第一次旷工后永久解锁。
- `high_stress_consecutive_days`、`high_stress_checked_day_id`和`is_unemployed`跨天保存；连续3个日历日压力达到90触发失业。

## 星期日事件与余额规则

星期日事件概率与余额变化由`sunday_event_probabilities`和`sunday_event_balance_deltas`配置；玩家可见文字位于`res://data/text_events/story_events.json`的`sunday_event_0`至`sunday_event_4`。当前依次为5%义工`+¥200`、5%大餐`-¥500`、5%外包`+¥1,000`、5%感冒`-¥300`、80%无事发生。每周只使用一次累计概率随机，并保存事件周ID、事件ID和实际余额变化。

所有现实货币变化使用 `GameStateRules.change_balance()`；余额最低为0。余额200遇到-500时实际变化为-200，结果为0；商品购买仍在扣款前检查余额，不允许透支购买。

## 卧室天气

天气脚本位于 `res://scripts/bedroom/bedroom_weather.gd`，节点为 `Bedroom/Layout/WeatherBackLayer`。最新且唯一有效的层级为 `BackgroundColor → WeatherBackLayer → BedroomBackground → 家具/交互 → UI`；天气全屏生成、忽略鼠标，并只通过背景图的透明区域显示。`weather_types`和`weather_probabilities`默认包含雨、雷、大风、星空和乌云，各20%；`weather_opacity=0.20`、`weather_animation_speed=1.0`。`daily_weather_type`和`daily_weather_day_id`保证同一天重新加载不重新随机；天气环境音由唯一的 Environment 播放器送入 SFX 总线。

## 在线消息与褪黑素动画

在线消息模板位于 `res://data/dialogue/phone.json`。“生活”迁移为“妈妈”，“工作”迁移为“项目组长-速联科技控股”，新频道“速联快讯”使用`quicklink_news_read`保存已读状态，旧存档迁移只追加缺失消息。

第一人称褪黑素脚本为 `res://scripts/ui/melatonin_interaction.gd`，原创可替换占位帧位于 `res://assets/art/first_person/melatonin/`。右手伸向药瓶、握瓶摇晃、瓶口甩药和吞服结束后，才一次性执行库存-1、本晚片数+1、压力-5；梦境开始时间仍由最终片数每片提前30分钟。ESC暂停会暂停手、Tween、非真实时间Timer和环境音频进度。

## 商品像素图标

商品图标位于 `res://assets/ui/products/`；`brainstem_icon.png` 作为旧存档/资源兼容素材保留，但不再出现在正式永久升级目录。全部为32×32透明PNG，通过项目全局最近邻过滤显示，不包含第三方素材。
# V0.3 新增参数

本节参数统一位于 `res://resources/demo_config.tres`，字段定义位于 `res://scripts/data/demo_config.gd`。修改 `.tres` 后重新进入相关场景即可生效；已经开始的梦境不会热重载配置。

## 提前醒来压力

- `early_wake_stress_start_before_alarm_minutes`：默认 `30` 分钟。闹钟前的免增压分界；严格早于该分界才开始按完整区块计算。
- `early_wake_stress_block_minutes`：默认 `30` 分钟。每个完整提前区块的长度。
- `early_wake_stress_gain_per_block`：默认 `2` 点。每个完整区块增加的压力。
- `early_wake_stress_max_gain`：默认 `10` 点。单局提前醒来最多增加的压力。
- 关联：使用梦境真正结束时间，不使用死亡后的现实起床延迟；休息日固定不增加。

## 玩家暴击

- `player_base_critical_chance`：默认 `0.10`，比例，推荐 `0—1`。每个有效玩家命中独立判定暴击。
- `player_critical_damage_multiplier`：默认 `1.50`，倍率，推荐 `1—3`。在空腹倍率等修正之后乘算，统一四舍五入且最低伤害为 `1`。

## 闹钟怪

- 生成池ID为`alarm_clock`，由`enemy_unlock_days`在Day 3解锁；不再读取局内经过秒数。
- `alarm_enemy_max_hp`：默认 `10` 点；基础生命。
- `alarm_enemy_contact_damage`：默认 `0` 点；接触玩家不造成伤害。
- `alarm_enemy_explosion_radius`：默认 `50.0 px`；预警、连锁和爆炸判定半径。
- `alarm_enemy_explosion_damage`：默认 `30` 点；对玩家及其他怪物的固定伤害，不触发玩家暴击。
- `alarm_enemy_death_delay`：默认 `1.0` 秒；被击杀后到爆炸的延迟。
- `alarm_enemy_blue_exp_value`：默认 `5` 经验；只生成一枚蓝色经验。

## 邮箱怪

- 生成池ID为`mailbox`，由`enemy_unlock_days`在Day 4解锁；不再读取局内经过秒数。
- `mailbox_enemy_max_hp`：默认 `100` 点。
- `mailbox_enemy_attack_trigger_distance`：默认 `50.0 px`；开始震地前摇的距离。
- `mailbox_enemy_slam_angle`：默认 `30.0` 度；扇形总角度。
- `mailbox_enemy_slam_range`：默认 `200.0 px`；震地最远距离。
- `mailbox_enemy_slam_damage`：默认 `30` 点；一次震地对玩家的伤害。
- `mailbox_enemy_slam_windup`：默认 `0.8` 秒；锁定方向后的前摇。
- `mailbox_enemy_attack_cooldown`：默认 `2.5` 秒。
- `mailbox_enemy_split_count`：默认 `3` 只；死亡后有限次数寻找位置生成普通修正带。
- `mailbox_enemy_purple_exp_value`：默认 `25` 经验；自身只生成一枚紫色经验。

## 饥饿结局

- `starvation_ending_required_days`：默认 `4` 天，推荐 `2—14`。每日正式确认睡觉时检查一次；当天真正吃过食物会将连续天数清零。

## 主菜单版本与社区链接

- `game_version_text`：默认 `V0.4.7`。唯一玩家可见当前版本字段；主菜单底栏拆为两个独立 Label：版本号（Hover 变亮、点击打开全屏公告）与群号（点击保留原有群链接），整体居中、互不重叠；`main_menu.tscn`、导出预设与公告首行均同步。
- `community_group_text`：默认 `游戏存活进度群:833796070`。
- `community_group_url`：默认 `https://qm.qq.com/q/Mq3wuCuZQ6`；点击群号后交由系统浏览器打开。
- 公告不再进入主菜单自动弹出；点击版本号调用 `AnnouncementWindow.show_announcement()` 打开全屏公告（`#0E140D` 同主菜单背景、正文 ScrollContainer 滚动、底部中央关闭按钮），内容仍来自 `res://data/announcement.txt`。

## V0.3 音频、天气与交互

以下字段定义于 `res://scripts/data/demo_config.gd`，实际默认值保存在 `res://resources/demo_config.tres`。除音量滑轨即时生效外，修改后建议重新进入对应场景。

### 音乐与天气环境音

- `music_fade_duration`：默认 `0.5` 秒，推荐 `0—2`。控制卧室/战斗音乐切换及离场淡出；Music Bus。
- `ambience_fade_duration`：默认 `0.5` 秒，推荐 `0—2`。控制天气环境音切换；Environment → SFX Bus。
- 卧室完整/短版：`res://sfx/卧室背景音乐.mp3`、`res://sfx/卧室背景音乐短.mp3`。
- 战斗完整/短版：`res://sfx/游戏中战斗音乐.mp3`、`res://sfx/游戏中战斗音乐短.mp3`。
- 天气映射：`rain → 雨天.mp3`、`thunder → 雨天打雷.mp3`、`wind → 大风.mp3`、`stars/overcast → 普通晚上.mp3`。打雷天气不叠加普通雨声。
- `敲门.mp3` 为非循环 Environment SFX，仅在配送从 `DELIVERING` 进入 `WAITING_AT_DOOR` 时播放一次。

### 天气图层

最新顺序为 `BackgroundColor → WeatherBackLayer → BedroomBackground → BedroomBed → BedroomDesk → MelatoninBottle → 交互/UI`。`Bedroom/Layout/WeatherBackLayer` 使用全屏锚点、`MOUSE_FILTER_IGNORE`，不再使用窗户 Mask。天气禁止移到背景图上方；当前 `bedroom_background.png` 含透明像素，可从这些区域看到天气。`weather_opacity` 默认 `0.20`，推荐 `0.05—0.35`；色调基准为 `#517B98`。

### 褪黑素鼠标摇晃

- `melatonin_shake_distance_required`：默认 `260 px`，推荐 `100—800`；按住左键期间累计的有效鼠标移动距离。
- `melatonin_shake_velocity_threshold`：默认 `180 px/s`，推荐 `50—800`；低于该速度的微小移动不计入摇晃。
- `melatonin_shake_direction_changes_required`：默认 `4` 次，推荐 `2—10`；达到水平有效行程后的左右反转次数。
- 松开左键会暂停但保留本次进度；库存、服用次数、压力和梦境提前时间只在完整吞服动画结束后提交。

### 噩梦文字条件

- `early_nightmare_death_cutoff_minutes`：默认 `360` 游戏分钟，即 `06:00`，推荐 `0—1439`。
- 仅工作日、仅“梦中倒下”、且原始死亡时间严格早于该值时显示“闹钟还没响 / 今天又是一场噩梦”。`06:00` 整、主动醒来和星期日均不触发；该参数不改变提前醒来压力规则。

### 在线！消息日期与定时消息

- 每条消息保存 `received_day_id` 与唯一递增的 `message_sequence`，先按日期降序、再按序号降序排列；新消息始终显示在最上方并滚动到顶部。旧存档缺失字段时只迁移一次。
- 连续未进食达到 3 天：妈妈消息，字段 `mom_hunger_message_sent`、`mom_hunger_message_day_id`。
- 游戏第 3 天（`calendar_day_id + 1 >= 3`）：速联快讯，字段 `day3_quicklink_news_sent`、`day3_quicklink_news_day_id`。
- 游戏第 5 天（`calendar_day_id + 1 >= 5`）：北方时报，字段 `day5_northern_times_sent`、`day5_northern_times_day_id`、`day5_northern_times_deleted`。点击后永久显示灰色删除提示，但保留联系人和日期。
- 手机正式 App 共用 `res://resources/themes/phone_pixel_scrollbar.tres`。`online_scrollbar_width=5 px`保留为基础值，运行时 VScrollBar 的视觉宽度和鼠标命中宽度统一取其50%（当前2.5 px）；ONLINE、QUICKLINK与设置继续支持滚轮、轨道/滑块操作，内容拖动阈值为`phone_scroll_drag_threshold=6 px`。手机主页仍为2×2 Grid，第四格留空；眠网已迁移至主菜单。设置中的Master/Music/SFX音量滑轨已恢复128 px宽，与本条滚动条调整无关。

- 卧室电脑的记事本、21点与梦境浏览器共用`res://scripts/ui/computer_window_shell.gd`绘制的窗口壳。21点与浏览器支持最小化、电脑屏幕内最大化/还原及关闭；21点牌局数据仍保留在原`BlackjackApp`实例中，窗口状态变化不退款也不重复扣款。

- 梦境浏览器位于`res://scenes/ui/dream_browser_app.tscn`，只展示剧情存档现有解锁标记允许的武器。选择后通过主流程既有`_on_story_weapon_equipped()`更新`current_weapon_id`、当天快照与存档。

- 卧室饱腹提示只绘制胃/碗像素图标，不再常驻显示“吃饱了”；鼠标悬停图标时显示同文案的小型蓝色Tooltip，权威状态仍为`food_eaten_today`。

### 主菜单眠网与全局强化

手机不再包含SOMNIA NET入口。主菜单节点`MenuContent/ButtonList/Somnia`打开独立页面`Overlay/Panel/Content/GlobalUpgradePanel`，场景为`res://scenes/ui/global_upgrade_panel.tscn`。升级目录与购买规则由`res://scripts/data/permanent_upgrade_catalog.gd`统一提供，继续读取旧存档的`persistent_day_state.permanent_upgrades`与全局`ram`字段；不迁移或重置旧等级。剧情创建DreamWorld时把永久升级字典传入玩家战斗初始化；老虎机/宝箱卡片只属于当前Dream，不写跨天存档。

## 升级音乐与在线布局

以下参数同样位于 `res://resources/demo_config.tres`；设置值保存到 `user://game_settings.cfg`，主菜单和手机设置读取同一字段。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 升级音乐降低值 | `upgrade_music_duck_db` | -6.0 | dB | 升级三选一显示期间平滑降低当前Music播放器 | -24—0 | 使用命名原因`UPGRADE_UI`，不会与ESC重复累计，也不覆盖Music Bus滑轨 |
| 升级音乐过渡 | `upgrade_music_duck_fade_duration` | 0.15 | 秒 | 进入和退出升级界面的音量渐变时间 | 0—1 | 音乐保持原播放位置，天气与UI音效不受影响 |
| 在线滚动条宽度 | `online_scrollbar_width` | 5 | UI px | 在线消息列表像素滚动条宽度 | 3—8 | 与右侧安全边距共同占用内容宽度 |
| 在线消息右侧边距 | `online_message_right_safe_margin` | 10 | UI px | 保证日期、联系人和正文不被滚动条覆盖 | 4—20 | 内容宽度会自动扣除滚动条宽度和本边距 |

## 褪黑素握瓶节点与结算时机

第一人称右手层级为 `MelatoninInteraction/RightHand/HandSprite`、`BottleSprite` 与 `BottleMouthMarker`。桌面瓶保持可见直到实际按住并握瓶；同一帧切换到随右手移动的握瓶合成帧，松开鼠标也不会退回空手帧。药丸起点读取 `BottleMouthMarker.global_position`，翻转时锚点随右手旋转。现有握瓶、摇晃、翻转图片包含手指遮挡关系，因此由专用 `BottleSprite` 承载合成帧，避免重复绘制药瓶或出现前后层级错误。

## 连续未进食短信安全规则

每日正式睡觉时按“更新当日计数 → 第3天发送妈妈提醒 → 第4天判定饥饿结局 → 保存”处理。同一天由 `hunger_checked_day_id` 防止重复累计。妈妈提醒严格在 `consecutive_hungry_days == 3` 且 `mom_hunger_message_sent == false` 时加入；消息安全入口位于 `res://scripts/app/main.gd` 的 `_add_online_message()`，会验证ID和正文、按消息ID防重复、补齐 `received_day_id`、分配 `message_sequence`、设置未读并只更新数据层。手机未实例化时不会访问UI节点。旧存档缺少 `mom_hunger_message_sent`、`mom_hunger_message_day_id` 或消息序号时，分别迁移为 `false`、`-1` 和一次性递增序号。

## 卧室电脑交互、息屏与电脑界面

电脑素材为 2560×1440 共享画布，与床、遮光帘等家具一样挂在 `Bedroom/Layout/ArtRoot`（缩放 0.25）下。

- 亮屏素材：`res://art/Badroom/bedroom_computer_light.png`（对应需求中的 `computer`）。
- 息屏素材：`res://art/Badroom/bedroom_computer_dark.png`（对应需求中的 `computer_dark`），两素材 Alpha 轮廓一致，仅屏幕明暗不同。
- 电脑精灵节点：`Bedroom/Layout/ArtRoot/BedroomComputer`（Sprite2D，`centered=false`）。
- 点击区域：`Bedroom/Layout/ComputerClickArea`（Area2D + CollisionPolygon2D，视口坐标约 (18,145)-(127,208)，略宽于素材不透明边界）。
- 描边：复用现有 `res://shaders/sprite_alpha_outline.gdshader`，电脑使用独立 ShaderMaterial（`resource_local_to_scene`），宽度与床同为 `bedroom_interaction_outline_width / ArtRoot缩放`，沿 Alpha 边缘生成，无矩形框。
- 高亮与点击判定沿用卧室统一流程（`_update_mouse_highlight()` 多边形检测 + `_is_opaque_at()` 逐像素 Alpha 检测），透明区域不可点。
- 电脑界面场景：`res://scenes/ui/computer_overlay.tscn`，脚本 `res://scripts/ui/computer_overlay.gd`，实例挂在 `Bedroom/ComputerLayer`（CanvasLayer layer=12，高于手机 PhoneLayer=10）。界面为纯 `_draw()` 绘制的 Y2K/旧电脑像素桌面（壁纸、顶栏、任务栏、图标、假窗口），仅右上角关闭按钮有功能；打开时全屏 `mouse_filter=STOP` 阻断卧室交互，ESC 由 `bedroom.gd consume_escape()` 优先关闭。
- 当天状态字段：`persistent_state.computer_opened_today`（bool）。`false` 显示 `computer_dark`，当天第一次打开后置 `true` 并切换亮屏素材；`res://scripts/app/main.gd` 的 `_reset_daily_state()` 在新的一天重置为 `false`。素材切换与灯光同步的唯一入口为 `bedroom.gd _sync_computer_visual()`。

## 手机新消息震动提示与震动音效

震动逻辑位于 `res://scripts/ui/bedroom_phone.gd` 的 `_play_new_message_vibrate()`，由 `_notify_unread_batch_once()` 在播放 `new_message` 提示音后触发。去重沿用现有未读批次签名机制（`online_notified_batch_signature`）：同一批未读消息只提示一次，因此每天新的一天开始收到新消息时只震动一次，重复开关手机、读消息、切换App、重新进入卧室不会重复震动。所有震动坐标基于 `_ready` 记录的 `phone_rest_position`（不基于当前 position 累计加减），结束后准确恢复原位。音效与视觉同步：每轮震动开始时播放一次 `phone_buzz` 事件（UI Bus → SFX 总线），共两轮短促低频“嗡嗡”。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 震动幅度 | `phone_vibration_offset_px` | 3.0 | px | 手机左右抖动的单边位移 | 1—6 | 0 等于关闭视觉震动 |
| 单步时长 | `phone_vibration_step_duration` | 0.05 | 秒 | 每次方向变化的间隔（左→右→左→右→中 5步/轮） | 0.04—0.06 | 总时长 = 步长×5×轮数 + 轮间停顿×(轮数-1) |
| 轮间停顿 | `phone_vibration_pause_duration` | 0.10 | 秒 | 两轮震动之间的短暂停顿 | 0.08—0.12 | 默认2轮总时长约0.6秒 |
| 震动轮数 | `phone_vibration_rounds` | 2 | 轮 | bzz-bzz 两段振动的轮数 | 1—4 | 每轮同步播放一次 buzz 音效 |
| 震动音效音量 | `sfx_phone_buzz_volume_db` | -18.0 | dB | buzz 音效在 SFX 总线内的相对音量 | -30—0 | 受主 SFX 滑轨控制 |

**临时音效说明**：当前 buzz 为 `sfx_manager.gd _fill_phone_buzz()` 程序化生成的占位音频（约145Hz方波 + 26Hz tremolo，两段短包络 burst，8-bit/11025Hz），明确非最终美术音频；后续提供 `res://sfx/手机震动.wav` 并加入 `IMPORTED_SFX_EVENTS` 即可替换，无需修改逻辑。旧参数 `phone_new_message_vibrate_amplitude / cycles / seconds` 已废弃保留，不再被震动逻辑使用。

## 卧室像素风动态光照与动态暗角

光照节点统一位于 `Bedroom/Layout/BedroomLighting`，只影响主画布；手机、对话、公告、电脑界面等 UI 均在更高 CanvasLayer，不受光照影响。

**窗户光照已废弃**：`WindowLight`、窗户光贴图/Shader/Tween、`CurtainLightOccluder` 及其专用 Occluder/Light Mask 已全部删除；`bedroom_window_light_energy` / `bedroom_window_light_color` 等配置字段同步移除。遮阳帘保留 Sprite、开关状态、鼠标交互与白色 Alpha 描边，但不再影响任何光源；卧室光照不再随遮阳帘、时间或天气产生窗户光。

**重要**：本项目 gl_compatibility 渲染环境下，PointLight2D 的 `Add` 混合模式会把照射区渲染成黑色（实测异常）。电脑光源必须保持 `blend_mode = Mix`（代码 `_setup_lighting()` 每次进入卧室强制设置，防止回归）。

当前卧室唯一动态光源为电脑屏幕光：

- `CanvasModulate`：卧室基础环境色调，颜色由 `bedroom_ambient_modulate_color` 控制。
- `ComputerScreenLight`（PointLight2D，路径 `Bedroom/Layout/BedroomLighting/ComputerScreenLight`）：电脑屏幕冷色发光，贴图 `res://art/lighting/screen_light.png`，位置约 (64,168)（屏幕区域而非机身中心），`blend_mode=Mix`、`color=(0.62,0.86,0.95)`、`texture_scale=3.2`、`item_cull_mask=2`。`visible` 与 `computer_opened_today` 同步：息屏（`computer_dark`）关闭、亮屏（`computer`）开启。灯光状态更新入口为 `bedroom.gd _sync_computer_visual()`。
- 电脑光强度 = `bedroom_computer_light_energy × computer_light_energy_multiplier`，倍率只在 `bedroom.gd _setup_lighting()` **一处**乘算（禁止配置与运行时双重叠加）：1.15 × 2.0 = 2.3，即当前实际亮度为原版的 2 倍。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 卧室环境色调 | `bedroom_ambient_modulate_color` | `(0.82, 0.84, 0.92)` | 颜色 | CanvasModulate 基础亮度与色温 | 0.6—1.0 灰蓝区间 | 过低会让整个卧室过暗 |
| 电脑屏幕光基础强度 | `bedroom_computer_light_energy` | 1.15 | 能量 | ComputerScreenLight 基础亮度 | 0—3 | 仅亮屏状态可见；最终再乘下方倍率 |
| 电脑光增强倍率 | `computer_light_energy_multiplier` | 2.0 | 倍 | 电脑屏幕光全局增强倍率 | 0.5—4 | 只在 `_setup_lighting()` 一处乘算 |
| 电脑屏幕光颜色 | `bedroom_computer_light_color` | `(0.62, 0.86, 0.95)` | 颜色 | 冷蓝/青白屏幕发光 | 冷色区间 | 只照亮电脑附近小范围 |

### 21:00→00:00 动态像素暗角

暗角 Shader 位于 `res://shaders/bedroom_vignette.gdshader`，承载节点为 `Bedroom/Layout/VignetteLayer`（全屏 ColorRect、`mouse_filter=IGNORE`、位于卧室世界内，z_index 高于光照层但低于所有 CanvasLayer UI，因此压力值、手机、对话、电脑界面、ESC菜单、公告、设置均不受影响）。Shader 将 UV 按 `pixel_size` 块取整并按 `bands` 分段量化 alpha，边缘暗中间透明，颜色为深蓝黑 `#101722` 附近，非纯黑。

强度计算位于 `bedroom.gd` 的 `_update_vignette()` / `_vignette_progress()`（每帧以卧室游戏时间驱动，非现实时间）：`progress = max((当前分钟 - start) / (end - start), 0)`（不设上限，Debug 超过 00:00 时继续增长），跨午夜（00:00=1440>21:00=1260）通过 +1440 归一处理不会反向；最终 `strength = max((min_strength + progress²) × vignette_intensity_multiplier, 0)`（Ease-In）。**强度不设任何人为上限**：旧 `bedroom_vignette_max_strength`/`bedroom_vignette_safe_max` 配置与 GDScript Clamp 已删除，Shader 内也不 clamp strength；超过 1.0 的 alpha 由 GPU 渲染自然限制。示例（min=0.10、倍率=2.0）：21:00→0.20，22:00→0.42，23:00→1.09，00:00→2.20。正常流程 00:00 仍按现有规则强制睡觉。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 暗角开始时间 | `bedroom_vignette_start_minutes` | 1260 | 游戏分钟 | 21:00，暗角最弱 | — | 使用卧室游戏时间 |
| 暗角结束时间 | `bedroom_vignette_end_minutes` | 1440 | 游戏分钟 | 00:00（强制睡觉），progress=1 | — | 按当晚分钟归一，跨午夜不反向；超过后 progress 继续增长 |
| 暗角最低强度 | `bedroom_vignette_min_strength` | 0.10 | 比例 | 21:00 时的基础暗角 | 0—0.3 | 不建议完全为0 |
| 暗角强度倍率 | `vignette_intensity_multiplier` | 2.0 | 倍 | 暗角视觉强度整体倍率 | 0.5—4 | 只在 `_update_vignette()` 一处乘算；乘后不再封顶 |

## 压力值表情图标

卧室左上角压力UI（`scripts/ui/bedroom_status_hud.gd`）绘制一个随压力值变化的像素表情，每帧随 `set_stress()` 实时刷新（非仅进入卧室时刷新一次）。分档阈值集中配置：`stress <= stress_face_happy_max` 显示开心，`stress < stress_face_sweat_min` 显示一般，其余显示流汗。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 开心上限 | `stress_face_happy_max` | 30 | 点 | 压力 ≤ 该值显示开心表情 | 0—100 | 默认 0—30 开心 |
| 流汗下限 | `stress_face_sweat_min` | 70 | 点 | 压力 ≥ 该值显示流汗表情 | 0—100 | 默认 70—100 流汗，中间为一般 |

表情资源：`res://assets/art/ui/stress/stress_happy.png`、`stress_normal.png`、`stress_sweat.png`，三张 16×16 画布尺寸与脸部位置一致，沿用压力UI调色板，Nearest 过滤。**当前为程序生成的像素占位图，需人工替换为最终美术**（同名覆盖即可，无需改逻辑）。

## 梦境地图（Crawling Depths）

梦境战斗地图已用第三方素材 **Crawling Depths**（作者 pingupollas，https://pingupollas.itch.io/crawling-depths）重做，16×16 俯视像素恐怖 Tileset。署名与许可详情见 `docs/THIRD_PARTY_ASSETS.md`；素材仅作为游戏内美术使用，不重新分发素材包本身。

地图结构（世界 1040×480 px = 65×30 tile）：

- TileSet：`res://assets/art/dream/crawling_depths/crawling_depths_tileset.tres`（tile_size 16×16，无 Margin/Separation；源0=tiles.png 地面20种变体，源1=cliff.png 墙砖7种变体带全格物理碰撞，源2=cracks.png 裂纹8种覆盖层）。贴图全局 Nearest 过滤、无 Mipmaps（`project.godot default_texture_filter=0`）。
- 节点：`res://scenes/dream/dream_world.tscn` 的 `DreamMap`（脚本 `res://scripts/dream/dream_map_builder.gd`，固定种子 `MAP_SEED=20260807` 运行时填充）下含 `GroundLayer`/`TilePatchLayer`/`WallLayer`（TileMapLayer）与 `Decorations`（Node2D）。外圈一环墙砖（真实碰撞，碰撞层 8）。
- 地表构成：**可走内区 63×28=1764 格全部以 Cracks（源2，8种变体）为主体铺底，约占90%以上**；Tiles（源0）仅作为被裂纹吞噬后残存的人工地面碎片，总预算为内区格数的 10%（176格）且只以小片零星分布：Patch 形状为 2×2（35%）/3×2（25%）/单块（20%）/不规则3格（20%），任意两格 Tiles 之间保持 5×5 邻域隔离，禁止大面积连续/棋盘/对半分布。**Tentacle 地图装饰占比 = 0**：旧动画装饰列表中的 tentacle_sheet 条目已删除，TileMap 不随机摆放任何触手，地图更加空旷压抑，也不用 Tiles 填补；触手素材唯一允许的用途是触手怪敌人（`TentacleSpawner` 每30秒生成 1～5 只、全图上限10）。装饰含雕像/瓮/脉络柱/书坛与慢速动画（眼/嘴/脉络/浮石/小眼，2—4 FPS）；装饰纯视觉，不参与战斗碰撞、不造成伤害；场景树暂停（升级卡片/ESC等）时动画自动停止。
- 可探索区域：`ARENA_BOUNDS = Rect2(24, 24, 992, 432)`（`dream_world.gd`），面积 992×432≈428,544 px²，约为旧地图 580×258=149,640 px² 的 **2.86 倍**；按墙内地板 1008×448=451,584 px² 计为 **3.02 倍**（目标 `dream_map_area_multiplier=3.0`，长宽各约√3≈1.73 倍保持长宽比）。
- 玩家出生在地图中心 (520, 240)，附近半径约 140 px 内不放置装饰；玩家 `collision_mask=8` 与墙砖物理层碰撞，移动/冲刺另受 `arena_bounds` Clamp 双重约束。
- 相机：`Player/DreamCamera`（Camera2D）作为玩家子节点平滑跟随，`zoom=(1,1)`、`position_smoothing_speed=8`。剧情Room不再把Camera limits锁到单房矩形，切房只重置平滑位置并继续跟随同一个Player；UI仍在CanvasLayer中不受世界滚动影响。
- **剧情醒来规则（已更新）**：06:00与梦境时间不再触发醒来，任意位置长按F和Wake Bed均停用；只有击败Boss并进入Final Wake Door才正常完成Dream。
- 刷怪/经验/敌人边界全部由 `ARENA_BOUNDS` 传参驱动（刷怪用 `grow(-14)`），仍维持屏幕外围绕玩家生成原则；**地图扩大不改变敌人生成速度、数量、HP、移速等任何数值**。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 梦境地图面积倍率 | `dream_map_area_multiplier` | 3.0 | 倍 | 目标可探索面积相对旧地图的倍率 | 1—9 | 记录本次扩大目标；地图已按该值建成 |
| TileSet 基础Tile尺寸 | `dream_tileset_base_tile_size` | 16 | px | Crawling Depths 素材的 tile 尺寸 | 固定16 | 与 TileSet 实际切分一致 |

## V0.4.1 可靠性修复

- **太刀剑气必中生成**：`katana_weapon.gd perform_katana_attack()` 为原子攻击事件（近战判定 + 1 道剑气同步执行），`katana_attack_sequence_id` / `wave_spawned_for_sequence` 序号 guard 保证每个攻击周期恰好 1 道，不依赖 animation_finished、近战是否命中或场上是否有敌人；零方向回退 `last_aim_direction` → 玩家默认面朝。偶发无剑气的实际根因是 `sword_wave.gd` 残留旧小地图 `ARENA_BOUNDS = Rect2(30, 54, 580, 258)`，玩家处于新地图右/下部时剑气出生即越界被释放，已同步为 `Rect2(24, 24, 992, 432)`。剑气伤害/速度/距离/宽度/Ease-In/暴击等数值均未改动。
- **版本号统一**：当前版本 `V0.4.1`，唯一配置字段 `game_version_text`（demo_config.gd 默认值与 demo_config.tres 均为 `版本号V0.4.1`），主菜单 tscn 编辑器默认文本同步；脚本/场景/资源中无其它玩家可见旧版本残留（公告文本中的历史更新日志条目不属于当前版本显示）。

## V0.4.5 玩家美术重建与主菜单公告改版

- **Pix_chr 重建**：最新源 `res://art/Chr/Pix_chr.png` 实测 1429×1254、4 行×5 列；重建图集 `res://assets/characters/player/pix_chr_atlas.png` = 160×216、单元32×54；所有帧固定画布与脚底基准。运行时`player_visual_scale=0.75`，Nearest显示且不对动画帧逐帧缩放。
- **动画结构**：`idle_<dir>` = 该行 frame0（停止时保留最后朝向首帧）；`walk_<dir>` = 该行 frame1—4 循环，`player_walk_animation_fps` 7→8（移动速度 112px/s 不变，一个 4 帧步态周期 0.5s ≈ 56px）。斜向仍用主轴稳定判定（abs(x)>abs(y)），motion=0 时回退 `last_move_direction`，不疯切方向。
- **脚底锚点**：玩家世界位置保持不变；视觉中心`(0,-18.25)`、Collider圆`r7.5 @ (0,-13)`、WeaponRoot`(0,-18.25)`。DreamPlayer不再挂载局部Light2D。
- **统一恢复反馈**：`dream_player.heal()` 与解离复活均调用 `_apply_heal_feedback()`：恢复 SFX（`&"heal"`，程序化升调 blip，Characters 总线，`sfx_heal_volume_db=-8`）+ 角色绿色 modulate 提示 `heal_feedback_seconds=0.3`（刷新式、不创建 Material/Tween，受伤闪红/复活闪金优先级更高）+ 现有 Heal/Frames 动画（700ms 节流）。满血不触发（heal() guard）。
- **手机收起区**：顶部 1/3 交互区视觉完全隐藏（删除 hover 白色 0.05 矩形），`_phone_action_at`/`_retract_area_rect` 判定与内容优先规则不变。
- **公告**：进入主菜单不再自动弹；底栏版本号 Label（Hover 变亮 `#8FB4B5`、点击）调用 `show_announcement()`；公告全屏（anchors full rect、z_index 5、`#0E140D` 背景阻止底层点击、正文 ScrollContainer 滚动、底部中央关闭按钮）；群号 Label 独立点击区保留 shell_open。
- **版本号**：`game_version_text`、demo_config.tres、main_menu.tscn、export_presets 文件版本、公告首行全部同步 V0.4.5。

## V0.4.7 升级稳定性与拾取反馈

- **Typed Array**：剧情升级武器奖励池由`_slot_weapon_ids_for_mode()`显式返回`Array[String]`，不再将三元表达式产生的普通`Array`赋给typed array。
- **CRT范围**：`UpgradePanel/CRTOverlay`覆盖三列Reel与Hover Description安全区，Description只保留参与曲变的一份；Reroll仍位于Overlay外并保持原交互。
- **拾取物**：EXP与Heart复用`res://scripts/entities/pickup_attraction.gd`，按“抬升Ease-Out → 二次Bezier Ease-In吸入”移动，终点每帧跟随玩家。

## 卧室床上角色手绘发光

床上角色主体与发光图均为 2560×1440 透明画布，共用 `Layout/ArtRoot/BedroomChrRoot` 的位置与 0.25 倍统一缩放。发光层使用 `res://resources/materials/bedroom_chr_glow_material.tres` 的 Add 混合，仅叠加素材自身的手绘亮部，不参与点击、碰撞或悬停描边。亮度由低频 `GlowFlickerTimer` 按随机间隔直接硬切，模拟手机视频画面变化；不使用Tween、插值或逐帧随机。对话开始时停止计时并隐藏，结束后重新随机普通亮度并启动。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 启用角色发光 | `bedroom_chr_glow_enabled` | true | 开关 | 控制床上角色发光层 | true/false | 关闭后主体仍正常显示 |
| 发光颜色 | `bedroom_chr_glow_color` | `#DCEEFF` | 色值 | 冷灰蓝手绘光颜色 | 低饱和冷色 | 与 Add 材质共同作用 |
| 普通亮度下限 | `bedroom_chr_glow_alpha_normal_min` | 0.68 | 比例 | 大部分视频画面的最低亮度 | 0.55—0.90 | 与普通亮度上限自动排序 |
| 普通亮度上限 | `bedroom_chr_glow_alpha_normal_max` | 0.86 | 比例 | 大部分视频画面的最高亮度 | 0.60—0.95 | 普通变化围绕当前值小幅硬切 |
| 暗场亮度下限 | `bedroom_chr_glow_alpha_dark_min` | 0.55 | 比例 | 视频切到暗画面时的最低亮度 | 0.50—0.70 | 永远不会降到完全透明 |
| 暗场亮度上限 | `bedroom_chr_glow_alpha_dark_max` | 0.68 | 比例 | 视频切到暗画面时的最高亮度 | 0.55—0.75 | 与下限自动排序 |
| 亮场亮度下限 | `bedroom_chr_glow_alpha_bright_min` | 0.86 | 比例 | 视频切到明亮画面时的最低亮度 | 0.75—0.95 | 仅强切换时使用 |
| 亮场亮度上限 | `bedroom_chr_glow_alpha_bright_max` | 0.95 | 比例 | 短暂高亮峰值 | 0.85—1.0 | 不会长期停留在峰值 |
| 最短变化间隔 | `bedroom_chr_glow_interval_min` | 0.06 | 秒 | 两次硬切之间的最短间隔 | 0.05—0.20 | 不低于0.05秒，不逐帧随机 |
| 最长变化间隔 | `bedroom_chr_glow_interval_max` | 0.18 | 秒 | 两次硬切之间的最长间隔 | 0.08—0.40 | 每次重新随机间隔 |
| 大幅变化概率 | `bedroom_chr_glow_big_change_chance` | 0.15 | 比例 | 切到明显亮场或暗场的概率 | 0.05—0.30 | 普通变化维持相近亮度节奏 |

## V0.4.7 梦境角色零件动画与可回溯地牢

`res://art/Dream/dream_chr_32x32.png`为当前玩家正式角色图集（128×96，4列×3行，每格32×32）。第一格作为拼装校准参考，`dream_player.gd`运行时使用Head/Blink、Body、左右手脚的AtlasTexture切片；脚底为CharacterVisual局部原点，Idle只移动Body/Head，Walk两腿使用相差PI的正弦相位；左右只翻转CharacterVisual，不影响碰撞或HeldWeapon。旧角色零件资源已移出运行项目。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 地牢房间数 | `dungeon_room_count` | 8 | 间 | 每个Story Dream一次性生成的Graph节点数 | 5—20 | 同一Run内固定，不随回房重掷 |
| Boss最小深度 | `dungeon_boss_min_depth` | 4 | 边 | Boss与Starting Room之间保证的最小主链长度 | 2—8 | 生成后用BFS验证可达 |
| Loop连接概率 | `dungeon_loop_connection_chance` | 0.28 | 比例 | 邻接房间额外建立双向连接的概率 | 0—0.6 | 每房最多保留一个Final Door空位，禁止自连/单向门 |
| 人口补充间隔 | `dungeon_population_refill_interval` | 3.0 | 秒 | 当前普通战斗房低于目标人口时尝试补怪的间隔 | 0.5—15 | Chest/Boss不使用 |
| 单次补充数量 | `dungeon_population_refill_batch` | 3 | 只 | 每次预警批次最多补充数量 | 1—10 | 仍受Target、Cap和合法生成点限制 |
| 敌人跟门距离（旧兼容） | `dungeon_enemy_follow_door_distance` | 240 | px | 仅保留资源兼容，新的房间级追击不按离门距离批量筛选 | 不建议修改 | 触手仍不跨房 |
| 跨房追击上限（旧兼容） | `dungeon_enemy_follow_maximum` | 6 | 只 | 仅保留资源兼容；新逻辑保留原实例并自行走向BFS下一跳门 | 不建议修改 | 不再执行整批搬运 |
| 同门转移间隔 | `dungeon_enemy_door_follow_delay` | 0.35 | 秒 | 同一连接门连续放行两只追击者的最短间隔 | 0.1—2 | Enemy逐只从对应门进入，HP与运行状态不重建 |
| 大房初始/目标人口 | `large_room_initial_enemy_count` | 16 | 只 | 首次直接生成并持续维持的数量 | 10—20 | Cap=`large_room_enemy_cap`=20 |
| 中房初始/目标人口 | `medium_room_initial_enemy_count` | 10 | 只 | 首次直接生成并持续维持的数量 | 10 | Cap=`medium_room_enemy_cap`=10 |
| 小房初始/目标人口 | `small_room_initial_enemy_count` | 10 | 只 | 首次直接生成并持续维持的数量 | 10 | Cap=`small_room_enemy_cap`=10 |

正常通关只由Boss死亡后开启的Final Wake Door触发。06:00 Alarm、任意位置Hold F、Wake Bed均不再接入剧情Dream流程；DreamClock与EXP/Level/Card/Weapon继续运行。玩家HP归零仍走“梦中倒下”噩梦结算，不会被视为正常醒来。

## V0.4.7 梦境预制Room、远镜头、换弹UI与GUNS图集

- `Player/DreamCamera`由`zoom=(2,2)`改为`zoom=(1,1)`并以速度8平滑跟随；640×360基础视口的可见世界尺寸由320×180扩大为640×360，两个轴的范围均为原来的2倍。HUD位于`UILayer` CanvasLayer，不随世界镜头缩放。
- 剧情Camera limits使用足够大的世界边界，Room切换后仍保留同一个Player子Camera并调用`reset_smoothing()`；不会再固定在Room center。
- Story弹丸不再读取`player.arena_bounds`做越界销毁。`DreamWorld.is_room_projectile_path_clear()`只Ray查询真实墙体Body：手工Office TileSet的Physics layer 1，以及旧模板Wall/DoorBlocker的layer 3；Entrance Area不参与查询，因此门触发器不会挡弹丸。
- 手工Office模板的`DoorLayer`在运行时只保留视觉、关闭Tile物理；`DreamRoomTemplate.configure_connections()`仅对Graph实际连通方向临时挖开相应`WallLayer`入口格。该修改只作用运行时实例，不会保存覆盖Editor中手绘的原始墙图；未连接方向继续由原WallLayer阻挡。缓存Room离开后会关闭其Ground/Wall/TilePatch Tile物理，返回时再恢复，避免不可见旧房墙叠在当前房间形成空气墙。
- `EnemyContainer`随当前Room进入同一个`YSortRoot`。Enemy先加入容器再调用`configure()`，保证`@onready Visual`已经就绪；Story Tentacle继续固定100HP、每房最多2只。
- 所有可破坏家具复用`res://shaders/sprite_alpha_outline.gdshader`的`flash_amount`，每实例创建独立ShaderMaterial，只作用`Sprite2D`，默认0.08秒恢复；Shadow不使用该材质。
- 家具材质碎片从击碎后0.8秒开始，按每块随机0.03—0.08秒的累计间隔逐块`queue_free()`；切换房间时会立即清理该Room尚未结束的临时碎片。
- 正式房间链为`DreamWorld/RoomManager/RoomTemplateContainer/<room prefab>`；模板中的TileMap、Decorations与Collision全部序列化在各自`.tscn`中，RoomManager不会覆盖人工地图美术。
- 玩家零件不再挂载`res://shaders/sprite_alpha_outline.gdshader`。绘制顺序为Legs → Head → Body → Hands（同一 Actor YSort 带，按节点顺序绘制，身体覆盖头部）；敌人及交互物描边系统不变。
- Walk时`CharacterVisual`额外产生最多1px的整体上跳，Body/Head原有1px步态起伏继续保留；位移只作用视觉根节点，不作用Player世界坐标、Collider、WeaponRoot或Camera。
- `UILayer/Crosshair`在弹药状态`reloading=true`时，读取`reload_left`与`weapon_reload_duration`绘制24×3px进度条；以当前鼠标瞄准点屏幕位置为锚，完成后自动隐藏，弹药数字继续保留。
- `res://art/Dream/GUNS.png`实测192×288，透明投影确认4列×9行，每格48×32。第1/3列为Logo，第2/4列为世界手持图；统一切分接口为`res://scripts/data/dream_gun_atlas.gd`。

| 武器 | UI Logo Rect2 | 手持 Rect2 |
|---|---|---|
| 小手枪 | `(0,0,48,32)` | `(48,0,48,32)` |
| 霰弹枪 | `(0,256,48,32)` | `(48,256,48,32)` |
| 光束武器 | `(96,192,48,32)` | `(144,192,48,32)` |

太刀继续使用独立太刀素材。GUNS手持列基准方向已对应局部+X，世界手持Sprite使用`flip_h=false`；再由HandAnchor旋转和左半平面`flip_v`保持枪口与实际射击方向一致。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 |
|---|---|---:|---|---|
| Walk整体蹦跳 | `player_walk_visual_bounce_pixels` | 1 | px | 移动时CharacterVisual的统一垂直起伏 |
| 换弹条宽度 | `crosshair_reload_bar_width` | 24 | px | 准星旁换弹进度条宽度 |
| 换弹条高度 | `crosshair_reload_bar_height` | 3 | px | 准星旁换弹进度条高度 |
| 换弹条偏移 | `crosshair_reload_bar_offset` | `(-12,13)` | px | 避开准星中心的屏幕局部偏移 |
| 家具受击闪白 | `hit_flash_duration` | 0.08 | 秒 | 通用Breakable Prop本体白闪恢复时间；每实例独立材质 |
| 碎片开始消失延迟 | `debris_disappear_start_delay` | 0.8 | 秒 | 从家具击碎发生起，到第一块材质碎片消失的延迟 |
| 碎片逐块间隔 | `debris_piece_interval_min/max` | 0.03 / 0.08 | 秒 | 后续碎片按随机累计间隔逐块回收，不永久堆积 |
