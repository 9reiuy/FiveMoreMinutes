# 《Five Minutes More》玩法参数说明

主要玩法参数统一位于 `res://resources/demo_config.tres`，字段定义位于 `res://scripts/data/demo_config.gd`。除特别说明外，修改后需要重新启动游戏，或至少重新进入使用该参数的场景；已经生成的敌人、武器和结算结果不会被追溯修改。

推荐范围用于调试平衡，并非所有字段的强制钳制范围。过高的生成数量、移动速度或粒子数量可能影响低配置设备性能。

## 时间与睡眠

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 梦境开始时间 | `dream_start_minutes` | 240（04:00） | 游戏分钟 | 默认梦境起始时间 | 0—1439 | 每片褪黑素会进一步提前 |
| 梦境闹钟时间 | `alarm_start_minutes` | 420（07:00） | 游戏分钟 | 当前运行配置中的闹钟时间 | 0—1439 | 实际工作日/星期日值见下两项 |
| 梦境时间倍率 | `real_seconds_per_game_minute` | 1.0 | 现实秒/游戏分钟 | 梦境时钟推进倍率 | 0.05—10 | 慢动作会同步影响推进 |
| 卧室开始时间 | `bedroom_start_minutes` | 1260（21:00） | 游戏分钟 | 每天卧室阶段的起点 | 0—1439 | 应早于强制睡觉时间 |
| 强制睡觉时间 | `bedroom_force_sleep_minutes` | 1440（00:00） | 游戏分钟 | 到点自动进入睡觉流程 | 1261—2880 | 与卧室时间倍率联动 |
| 卧室时间倍率 | `bedroom_real_seconds_per_game_minute` | 1.0 | 现实秒/游戏分钟 | 卧室时钟推进倍率 | 0.05—10 | 对话暂停时不推进 |
| 工作日闹钟 | `weekday_alarm_minutes` | 420（07:00） | 游戏分钟 | 星期一至星期六闹钟 | 0—1439 | 出勤判定仍使用起床时间 |
| 星期日闹钟 | `sunday_alarm_minutes` | 540（09:00） | 游戏分钟 | 星期日闹钟 | 0—1439 | 星期日不发工资、不改变出勤连续数 |
| 每片褪黑素提前时间 | `melatonin_minutes_earlier_per_tablet` | 30 | 游戏分钟/片 | 每服一片提前梦境开始时间 | 0—240 | 乘以本晚完整服用片数 |
| 每晚服用上限 | `melatonin_nightly_use_limit` | 3 | 片 | 每晚最多服用数量 | 1—10 | 库存跨天保存，本晚数量跨天重置 |
| 死亡起床延迟最小值 | `death_wake_delay_min_minutes` | 30 | 游戏分钟 | 梦中死亡后追加起床时间下限 | 0—180 | 不得大于最大值 |
| 死亡起床延迟最大值 | `death_wake_delay_max_minutes` | 90 | 游戏分钟 | 梦中死亡后追加起床时间上限 | 30—360 | 主动醒来不使用该随机延迟 |

## 玩家、冲刺与醒来

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 基础最大生命 | `player_base_maximum_health` | 100 | HP | 未计算海马体强化前的生命 | 1—1000 | 与 `hippocampus_health_per_level` 相加 |
| 基础移动速度 | `player_movement_speed` | 112 | px/s | 梦境玩家移动速度 | 20—500 | 慢动作由引擎时间倍率统一影响 |
| 梦境出生无敌 | `player_spawn_invulnerability_duration` | 3.0 | 梦境秒 | 玩家控制启用后通过统一受伤入口免疫全部伤害 | 0—10 | 暂停时不计时；快速睡觉会按梦境模拟速度推进 |
| 受伤无敌时间 | `hurt_invulnerability_seconds` | 0.55 | 秒 | 有效受伤后的无敌时间 | 0.1—2 | 不影响受击视觉持续时间 |
| 冲刺距离 | `dash_distance` | 100 | px | 单次冲刺目标距离 | 20—400 | 受场地边界限制 |
| 冲刺持续时间 | `dash_duration` | 0.18 | 秒 | 完整冲刺所需时间 | 0.05—1 | 与距离共同决定速度 |
| 冲刺冷却 | `dash_cooldown` | 2.0 | 秒 | 单次充能恢复时间 | 0.1—20 | 多充能仍分别恢复 |
| 冲刺无敌时间 | `dash_invulnerability_seconds` | 0.18 | 秒 | 冲刺伤害免疫时间 | 0—1 | 通常不应超过冲刺持续时间太多 |
| 基础醒来长按 | `base_wake_hold_seconds` | 5.0 | 秒 | 7:00后基础醒来长按时间 | 0.5—30 | 赖床增长会叠加 |
| 醒来慢动作倍率 | `bullet_time_scale` | 0.20 | 比例 | 长按醒来时的全局时间倍率 | 0.05—1 | UI与输入使用非缩放时间 |

## 小手枪与光束武器

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 小手枪伤害 | `basic_weapon_damage` | 10 | HP | 单颗子弹伤害 | 1—1000 | 增伤卡作用于运行时数值 |
| 小手枪攻击间隔 | `basic_weapon_attack_interval` | 0.30 | 秒 | 两次实际发射的基础间隔 | 0.05—10 | 前额叶与攻速卡使用除法缩短 |
| 小手枪子弹速度 | `basic_projectile_speed` | 310 | px/s | 小手枪子弹移动速度 | 20—2000 | 不影响最大射程 |
| 小手枪最大射程 | `basic_weapon_range` | 270 | px | 子弹累计飞行销毁距离 | 20—2000 | 枕叶强化增加该值 |
| 光束伤害 | `beam_damage` | 20 | HP | 光束对路径内敌人的单次伤害 | 1—5000 | 同一光束不会多帧重复伤害 |
| 光束攻击间隔 | `beam_attack_interval` | 2.0 | 秒 | 光束发射间隔 | 0.05—20 | 受攻速强化影响 |
| 光束射程 | `beam_range` | 150 | px | 光束直线长度 | 10—1500 | 受枕叶强化影响 |
| 光束宽度 | `beam_width` | 12 | px | 光束视觉和命中宽度 | 1—200 | 会加上敌人自身半径判定 |
| 光束显示时间 | `beam_display_seconds` | 0.15 | 秒 | 光束占位特效持续时间 | 0.02—1 | 只影响显示，不重复结算伤害 |

## 霰弹枪

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 单颗伤害 | `shotgun_pellet_damage` | 3 | HP | 每颗独立弹丸伤害 | 1—1000 | 9颗全中理论基础伤害27 |
| 弹丸数量 | `shotgun_pellet_count` | 9 | 颗 | 每轮完整齐射数量 | 1—32 | 数量过大会增加节点和碰撞检查 |
| 攻击间隔 | `shotgun_attack_interval` | 0.8 | 秒 | 两轮齐射间隔 | 0.05—20 | 意识漂移额外生成完整一轮 |
| 扩散角度 | `shotgun_spread_degrees` | 30 | 度 | 相对准星方向的总扇形角 | 0—180 | 每轮重新随机分布 |
| 弹丸速度 | `shotgun_projectile_speed` | 310 | px/s | 每颗霰弹移动速度 | 20—2000 | 不影响散布角 |
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

## 敌人生成与敌人数值

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 初始刷新间隔 | `enemy_initial_spawn_interval` | 2.0 | 秒 | 梦境开始时生成计时器间隔 | 0.1—10 | 随梦境进度向最小值线性变化 |
| 最小刷新间隔 | `enemy_minimum_spawn_interval` | 0.65 | 秒 | 刷新间隔下限 | 0.05—5 | 本次没有缩短 |
| 每次生成数量 | `enemy_spawn_count_per_interval` | 2 | 只 | 每次计时器触发尝试生成数量 | 1—8 | 原值1的2倍；合法点不足时允许少生成 |
| 场上怪物上限 | `maximum_enemies` | 110 | 只 | 同时存活怪物数量上限 | 10—300 | 原值55的2倍；过高会影响CPU |
| 玩家最小生成距离 | `enemy_minimum_spawn_distance` | 150 | px | 候选点与玩家的安全距离 | 50—400 | 与场地尺寸共同决定成功率 |
| 怪物间最小间距 | `enemy_spawn_minimum_spacing` | 30 | px | 新怪与现有/同批怪物距离 | 0—100 | 防止完全重叠 |
| 生成最大重试 | `enemy_spawn_position_max_retries` | 12 | 次/只 | 单只怪寻找合法位置的次数上限 | 1—50 | 达到上限后放弃该只，防止死循环 |
| 修正带解锁时间 | `correction_unlock_seconds` | 30 | 本局秒 | 加入随机生成池的经过时间 | 0—600 | 按单局实际经过时间，不看钟点 |
| 订书机解锁时间 | `stapler_unlock_seconds` | 90 | 本局秒 | 加入随机生成池的经过时间 | 0—900 | 90秒前不会出现 |
| 大修正带登场时间 | `large_correction_unlock_seconds` | 180 | 本局秒 | 每局唯一精英触发时间 | 1—1800 | 本次保持不变，不进入普通随机池 |
| 敌人基础生命 | `base_enemy_health` | 18 | HP | 基础怪、修正带、订书机共同基础生命 | 1—10000 | 大修正带再乘生命倍率 |
| 敌人基础接触伤害 | `base_enemy_damage` | 8 | HP | 通用接触伤害 | 0—1000 | 修正带冲刺和订书钉有独立伤害 |
| 敌人基础移动速度 | `base_enemy_movement_speed` | 42 | px/s | 继承基础敌人类的追踪速度 | 0—500 | 快速眼动会乘移动倍率 |
| 修正带蓄力时间 | `correction_charge_seconds` | 0.75 | 秒 | 冲刺前停止并预警的时间 | 0.1—3 | 不影响普通追踪速度 |
| 修正带触发距离 | `correction_trigger_distance` | 150 | px | 开始蓄力的玩家距离 | 20—300 | 与冲刺距离联动 |
| 修正带冲刺距离 | `correction_dash_distance` | 200 | px | 单次冲刺目标距离 | 20—500 | 受场地边界限制 |
| 修正带冲刺伤害 | `correction_dash_damage` | 18 | HP | 冲刺接触伤害 | 0—500 | 每段冲刺最多命中玩家一次 |
| 订书机发射间隔 | `stapler_fire_interval` | 2.0 | 秒 | 两枚订书钉之间的时间 | 0.2—10 | 与接触攻击相互独立 |
| 订书钉伤害 | `staple_damage` | 10 | HP | 投射物命中伤害 | 0—500 | 命中后销毁 |
| 订书钉速度 | `staple_speed` | 170 | px/s | 投射物移动速度 | 20—1500 | 不追踪玩家 |
| 订书钉最大距离 | `staple_max_distance` | 300 | px | 飞行累计距离上限 | 20—1500 | 达到后销毁 |
| 大修正带生命倍率 | `large_correction_health_multiplier` | 10 | 倍 | 相对基础敌人生命的倍率 | 1—50 | 不改变普通修正带生命 |

## 经验、升级与掉落

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 1级升级需求 | `first_level_experience_requirement` | 20 | 经验 | 1级升2级所需经验 | 1—32767 | 后续等级使用增长底数 |
| 经验增长底数 | `experience_growth_base` | 8 | 底数 | n级升n+1级使用 `8^n` | 2—16 | 最终受阈值上限限制 |
| 单级经验上限 | `experience_requirement_cap` | 32767 | 经验 | 单级升级需求硬上限 | 1—2147483647 | 防止阈值溢出 |
| 修正带掉落数量 | `correction_experience_drop_count` | 2 | 枚 | 正式死亡生成的经验物数量 | 1—16 | 每枚基础值1，击杀只计一次 |
| 订书机掉落数量 | `stapler_experience_drop_count` | 3 | 枚 | 正式死亡生成的经验物数量 | 1—16 | 每枚独立使用拾取逻辑 |
| 每次升级刷新数 | `upgrade_refreshes_per_level` | 1 | 次 | 每个独立三选一界面可刷新次数 | 0—3 | 下一次升级重新恢复 |
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
| RAM结算规则 | `RunSettlement.calculate_run_ram(final_level)` | `max(最终等级-1,0)` | RAM/局 | 主动醒来和死亡统一按最终等级结算 | 固定规则 | 不再读取累计经验；`settled`标记防止重复结算 |
| 正常生活结局天数 | `normal_life_ending_required_workdays` | 14 | 工作日 | 连续正常上班达到该值触发结局 | 1—365 | 星期日保持计数，迟到/旷工/失业清零 |

## 手机外观相关参数

手机外壳资源为 `res://art/Phone.png`，节点为 `BedroomPhone/PhoneShell`。图片保持160×336原始比例、关闭过滤，节点设置为忽略鼠标输入并绘制在运行时内容后方。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 手机宽度 | `phone_panel_width` | 160 | px | 手机UI根节点宽度 | 建议160 | 与Phone.png原始宽度一致 |
| 手机高度 | `phone_panel_height` | 336 | px | 手机UI根节点高度 | 建议336 | 与Phone.png原始高度一致 |
| 手机展开位置 | `phone_expanded_y` | 24 | 屏幕px | 展开后根节点Y坐标 | 0—80 | 24+336刚好落在360px画面底部 |
| 手机收起位置 | `phone_collapsed_y` | 319 | 屏幕px | 收起后只露出顶部的Y坐标 | 280—340 | 保留顶部与摄像头区域 |
| 主页收回热区高度 | `phone_upper_collapse_height` | 166 | px | 主页上半部收回点击范围 | 100—169 | 应小于应用网格起始Y=170，避免误触应用 |

## 梦游模式与瞄准

梦游模式开关由主菜单、手机设置应用和暂停菜单共同读取，保存字段为 `sleepwalk_mode`，设置文件为 `user://game_settings.cfg`。它与游戏进度存档分开保存，因此覆盖新游戏或回滚当天快照不会重置该偏好。默认关闭；修改开关后立即同步全部设置入口，并在下一次进入梦境时生效。

所有武器统一调用 `res://scripts/entities/dream_player.gd` 中的 `get_aim_direction()`。开启时，该接口选择玩家中心到有效存活敌人中心距离最近的目标；目标死亡或离场后自动切换。没有目标时保留最近一次有效方向。升级、Tab和暂停期间场景树暂停，不刷新目标。关闭时仍使用鼠标坐标，准星颜色、冷却与后坐力表现不变。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 首次默认梦游模式 | `sleepwalk_mode_default` | `false` | 布尔 | 没有设置文件时的初始状态 | `false` / `true` | 现有设置文件优先；修改配置后需删除旧设置或手动切换 |
| 自动瞄准搜索半径 | `auto_aim_search_radius` | 900 | px | 最近目标搜索上限 | 300—1500 | `0`表示无限；应覆盖所需战斗视野 |
| 自动瞄准刷新间隔 | `auto_aim_refresh_interval` | 0.08 | 秒 | 重新比较最近目标的频率 | 0.02—0.3 | 越低响应越快，但遍历敌人更频繁 |

## 经验掉落层级

层级在 `res://scenes/dream/dream_world.tscn` 中使用容器 `z_index` 固定：背景为0、`PickupContainer`为1、`EnemyContainer`为2、玩家为3、投射物与战斗特效为4、UI使用CanvasLayer 20。经验节点和拾取脚本未改变，只移动其绘制容器，因此吸附、碰撞距离和经验结算规则保持不变。

## 打击感与集中音效

统一音效入口为 `res://scripts/audio/sfx_manager.gd`。已有导入音效继续使用 `res://sfx/`；`ui_hover`、`dash`、`player_hurt`、`weapon_fire`、`pistol_fire`、`shotgun_fire`、`enemy_kill` 当前由管理器集中生成原创8-bit占位声，不存在每个按钮单独建立管理器的情况。事件分别进入UI、Characters或Weapons总线，替换正式素材时只需改管理器事件映射。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| UI悬停音量 | `sfx_ui_hover_volume_db` | -27 | dB | 首次进入可交互选项时的低频电子提示 | -35—-16 | 离开后再次进入才会重播；与确认音分开 |
| 冲刺音量 | `sfx_dash_volume_db` | -12 | dB | 成功开始冲刺时播放 | -30—0 | 冷却中或被边界阻止时不播放 |
| 玩家受伤音量 | `sfx_player_hurt_volume_db` | -12 | dB | 非致命有效伤害或解离复活反馈 | -30—0 | 正式死亡仍使用独立`death`事件 |
| 通用武器发射音量 | `sfx_weapon_fire_volume_db` | -17 | dB | 太刀的占位挥击声 | -35—0 | 手枪、霰弹枪和光束已使用各自事件 |
| 敌人击杀音量 | `sfx_enemy_kill_volume_db` | -14 | dB | 敌人正式进入死亡流程时播放 | -30—0 | 同一事件复用单播放器，避免叠加爆音 |
| 命中顿帧时长 | `hit_stop_duration` | 0.04 | 秒 | 有效命中产生的极短时间压缩 | 0.03—0.06 | 使用忽略时间倍率的恢复计时器；菜单和醒来长按时不触发 |
| 顿帧最短间隔 | `hit_stop_minimum_interval` | 0.09 | 秒 | 限制高频命中连续顿帧 | 0.05—0.25 | 霰弹与光束多目标命中共享节流 |
| 顿帧时间倍率 | `hit_stop_time_scale` | 0.05 | 比例 | 顿帧期间场景速度 | 0.01—0.2 | UI仍可处理；退出梦境会强制恢复1.0 |
| 敌人受击挤压 | `enemy_hit_scale_amount` | 0.16 | 比例 | 视觉子节点的短促横向拉伸/纵向挤压 | 0.05—0.3 | 不缩放碰撞体，不改变实际移动 |
| 敌人视觉击退 | `enemy_hit_visual_knockback_pixels` | 6 | px | 命中后仅移动精灵的反向反馈 | 0—14 | 不改变角色物理坐标 |
| 击杀/掉落弹出时间 | `kill_pop_animation_seconds` | 0.24 | 秒 | 解体特效与经验弹出动画时长 | 0.12—0.5 | 只影响视觉，不延后掉落结算 |
| 受伤屏幕闪光强度 | `player_hurt_screen_flash_alpha` | 0.24 | Alpha | 有效受伤时覆盖画面的红色闪光 | 0—0.5 | UI绘制在闪光之上 |
| 受伤屏幕闪光时长 | `player_hurt_screen_flash_seconds` | 0.12 | 秒 | 红色闪光淡出时间 | 0.05—0.35 | 无敌帧闪烁仍由玩家脚本负责 |

UI悬停入口已覆盖主菜单、设置开关、卧室对话选项、升级卡片/刷新、手机应用、眠网升级按钮、速联跑腿购买按钮与武器选择卡。手机点击仍使用 `phone_operation`，购买成功/失败仍分别使用 `purchase` / `forbidden`，避免同一次点击重复播放确认音。

## 敌人像素素材与动画

四种敌人共享项目内原创占位图集 `res://assets/art/enemies/generated/enemy_sprite_atlas.png`，没有引入第三方素材。每个敌人场景通过自己的 `SpriteFrames` 子资源切分对应行，关闭过滤并只缩放视觉节点；碰撞体和AI状态机保持原结构。

| 敌人 | 场景资源 | 移动动画 | 蓄力/攻击动画 | 状态同步位置 |
|---|---|---|---|---|
| 基础敌人 | `res://scenes/entities/basic_enemy.tscn` | `move_down/left/right/up`（各2帧） | — | `res://scripts/entities/basic_enemy.gd` |
| 修正带 | `res://scenes/entities/correction_tape_enemy.tscn` | `walk`（2帧循环） | `charge`（2帧循环） | `res://scripts/entities/correction_tape_enemy.gd` |
| 大体型修正带 | `res://scenes/entities/large_correction_tape_enemy.tscn` | `walk`（2帧循环） | `charge`（2帧循环） | `res://scripts/entities/large_correction_tape_enemy.gd` |
| 订书机 | `res://scenes/entities/stapler_enemy.tscn` | `walk`（2帧循环） | `attack_prepare`（2帧非循环） | `res://scripts/entities/stapler_enemy.gd` |

修正带的 `charge` 与实际 `correction_charge_seconds` / `large_correction_charge_seconds` 同时开始并结束，同时加入后缩、抖动、收紧危险圈和冲刺方向线。订书机在每个原有2秒发射周期末段进入 `attack_prepare`，到原发射时刻才生成订书钉，因此没有改变攻击间隔或判定。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 基础敌人移动帧率 | `basic_enemy_walk_animation_fps` | 5 | FPS | 基础敌人walk速度 | 2—12 | 修改后重新进入梦境 |
| 修正带移动帧率 | `correction_enemy_walk_animation_fps` | 5 | FPS | 普通修正带walk速度 | 2—12 | 与AI移动速度无关 |
| 大修正带移动帧率 | `large_correction_enemy_walk_animation_fps` | 4 | FPS | 大型修正带walk速度 | 2—10 | 与大小倍率无关 |
| 订书机移动帧率 | `stapler_enemy_walk_animation_fps` | 4 | FPS | 订书机walk速度 | 2—10 | 与发射周期无关 |
| 修正带蓄力帧率 | `correction_charge_animation_fps` | 8 | FPS | 普通修正带charge速度 | 2—16 | 动画循环，实际结束由蓄力计时控制 |
| 大修正带蓄力帧率 | `large_correction_charge_animation_fps` | 7 | FPS | 大型修正带charge速度 | 2—16 | 动画循环，实际结束由蓄力计时控制 |
| 订书机攻击帧率 | `stapler_attack_animation_fps` | 8 | FPS | `attack_prepare`开合速度 | 2—16 | 不改变实际发射时刻 |
| 订书机前摇窗口 | `stapler_attack_windup_seconds` | 0.35 | 秒 | 每次发射前切入预警动画的时间 | 0.15—0.8 | 自动限制为攻击间隔的80%以内 |

## 像素角色、武器特效与音频质感

配置路径统一为 `res://resources/demo_config.tres`，字段声明位于 `res://scripts/data/demo_config.gd`。下列参数在重新进入梦境后生效；音频总线滤波参数需要重新启动游戏。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 玩家像素缩放 | `player_sprite_scale` | 1 | 倍 | 玩家图集的整数缩放 | 1—4 | 使用整数值，关联像素吸附与碰撞体视觉对齐 |
| 基础敌人像素缩放 | `basic_enemy_sprite_scale` | 1 | 倍 | 四方向基础敌人图集缩放 | 1—4 | 只改视觉，不改碰撞半径 |
| 玩家待机帧率 | `player_idle_animation_fps` | 1 | FPS | 四方向待机动画速度 | 0.5—4 | 当前每个方向使用一帧，为后续增帧保留接口 |
| 玩家行走帧率 | `player_walk_animation_fps` | 7 | FPS | 四方向四帧行走循环速度 | 4—12 | 不改变实际移动速度 |
| 枪口闪光时长 | `weapon_muzzle_flash_seconds` | 0.07 | 秒 | 手枪和霰弹枪像素枪口反馈 | 0.03—0.15 | 仅视觉，受暂停与慢动作影响 |
| 命中特效时长 | `weapon_hit_effect_seconds` | 0.14 | 秒 | 非致命命中的像素碎片与闪光 | 0.06—0.3 | 击杀仍使用 `kill_pop_animation_seconds` |
| 子弹拖尾长度 | `projectile_trail_length` | 10 | px | 小手枪与霰弹丸的冷色像素轨迹 | 2—24 | 不改变射程或碰撞判定 |
| 光束蓄力时间 | `beam_charge_seconds` | 0.18 | 秒 | 冷却结束前显示收束像素环 | 0.05—0.4 | 不改变光束攻击间隔和实际发射时刻 |
| 太刀残影时间 | `katana_afterimage_seconds` | 0.20 | 秒 | 挥刀弧线多层残影持续时间 | 0.08—0.4 | 不改变近战范围和剑气规则 |
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
| 梦游模式 | `sleepwalk_mode` | `false` | 布尔 | 进入梦境时自动寻找最近敌人 | `false/true` | 与三条音量设置保存在同一ConfigFile中 |

旧版 `user://game_settings.json` 只在首次迁移时读取梦游模式，之后不再作为活动设置存档。

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

- Sprite资源：`res://assets/characters/player/player_sprite_atlas.png`
- 场景节点：`res://scenes/entities/dream_player.tscn`中的`Visual`
- 帧区域：所有动画帧固定为`64×64 px`
- 可见角色高度：所有方向、所有帧固定为`48 px`
- 脚底线：每帧固定在单元格`y=58`
- 缩放参数：`player_sprite_scale=1`
- 行走帧率：`player_walk_animation_fps=7`
- 待机帧率：`player_idle_animation_fps=1`

`walk_right`与`idle_right`复用左向侧身帧并通过`AnimatedSprite2D.flip_h`镜像，避免原右向素材本体尺寸偏小。缩放只在进入梦境配置角色时设置一次；运行时不逐帧改写`scale`。动画只切换固定64×64 Atlas区域，修改缩放倍率后需要重新进入梦境。

## 当天开始快照

快照实现位于 `res://scripts/app/day_start_snapshot.gd`。进入新一天时复制局外状态并写入正常存档；卧室购买、服药和本局梦境状态只修改当日工作副本。通过暂停菜单退出到主菜单时，工作副本被快照覆盖，因此继续游戏回到当天21:00开始状态。设置由独立的SettingsManager永久保存，不参与快照回滚。

## 卧室门口与廉价便当

配置路径统一为 `res://resources/demo_config.tres`，字段声明位于 `res://scripts/data/demo_config.gd`。门口交互节点为 `res://scenes/bedroom/bedroom.tscn` 的 `Layout/DoorInteraction`；配送状态使用 `NONE`、`DELIVERING`、`WAITING_AT_DOOR`、`RECEIVED` 四个明确值。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 门口热区宽度 | `door_interaction_width_ratio` | 0.12 | 屏幕宽度比例 | 屏幕左侧可悬停与点击的门口区域 | 0.10—0.15 | 仅手机完全收回且没有弹窗时可点击 |
| 门口白光宽度 | `door_glow_width` | 92 | px | 左边缘向画面内部延伸的低分辨率分段渐变 | 48—140 | 不改变实际点击宽度 |
| 门口白光透明度 | `door_glow_opacity` | 0.32 | Alpha | 普通悬停白光强度 | 0.10—0.60 | 到货时再乘等待倍率 |
| 白光淡入时间 | `door_glow_fade_in_seconds` | 0.16 | 秒 | 鼠标进入后的亮起时间 | 0.05—0.5 | 受场景暂停影响 |
| 白光淡出时间 | `door_glow_fade_out_seconds` | 0.24 | 秒 | 鼠标离开后的消退时间 | 0.05—0.8 | 手机展开后立即以该速度淡出 |
| 到货白光倍率 | `door_waiting_glow_multiplier` | 1.55 | 倍 | 便当等待领取时强化门口反馈 | 1.0—2.5 | 像素包裹提示可在手机打开时保留，但不能领取 |
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
| 每段增加 | `early_wake_stress_gain_per_block` | 2 | 点 | 每个完整30分钟增加压力 | 0—20 | 07:00闹钟、05:30结束梦境为+4 |
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
| 最高视野半径 | `stress_vision_max_radius` | 300 | px | 高压力视野半径上限 | 100—500 | 实际半径为`min(最终武器有效范围,300)`，不再设置150px下限 |
| 视野黑暗强度 | `stress_vision_darkness` | 0.94 | Alpha | 远处遮罩的不透明度 | 0.7—1.0 | UI与准星位于更高CanvasLayer，不受遮挡 |
| 视野边缘柔和度 | `stress_vision_edge_softness_ratio` | 0.28 | 半径比例 | 圆形视野边缘的平滑过渡宽度 | 0.1—0.6 | 仅改变视觉，不拦截输入或碰撞 |
| 失业压力阈值 | `stress_unemployment_threshold` | 90 | 点 | 每日结算后达到该值计为一个高压力日 | 1—100 | 星期日也计数，同一天只检查一次 |
| 失业连续天数 | `stress_unemployment_required_days` | 3 | 日历日 | 连续达到阈值后永久失业 | 1—14 | 失业后所有出勤工资为0并清除正常出勤连胜 |

视野遮罩位于 `res://shaders/stress_vision.gdshader`，场景节点为 `DreamWorld/StressVisionLayer/StressVisionOverlay`。小手枪、霰弹枪和光束使用最终射程；太刀取近身范围与剑气范围较大值，再应用300px上限。

## 暂停、失业与武器解锁

统一暂停管理器为 `res://scripts/app/pause_manager.gd`，自动加载名称为`PauseManager`。`UPGRADE`、`ESC_MENU`、`DIALOGUE`与`MODAL_ANIMATION`等原因独立持有；关闭界面只能释放自己的原因。战斗容器为`PROCESS_MODE_PAUSABLE`，升级UI为`PROCESS_MODE_WHEN_PAUSED`，暂停菜单为`PROCESS_MODE_ALWAYS`。

- 小手枪默认解锁。
- `shotgun_unlocked`：第2天永久解锁。
- `beam_weapon_unlocked`：第一次轻微或严重迟到后永久解锁。
- `katana_unlocked`：第一次旷工后永久解锁。
- `high_stress_consecutive_days`、`high_stress_checked_day_id`和`is_unemployed`跨天保存；连续3个日历日压力达到90触发失业。

## 星期日事件与余额规则

星期日事件由`sunday_event_probabilities`、`sunday_event_texts`和`sunday_event_balance_deltas`集中配置，当前依次为5%义工`+¥200`、5%大餐`-¥500`、5%外包`+¥1,000`、5%感冒`-¥300`、80%无事发生。每周只使用一次累计概率随机，并保存事件周ID、事件ID和实际余额变化。

所有现实货币变化使用 `GameStateRules.change_balance()`；余额最低为0。余额200遇到-500时实际变化为-200，结果为0；商品购买仍在扣款前检查余额，不允许透支购买。

## 卧室天气

天气脚本位于 `res://scripts/bedroom/bedroom_weather.gd`，节点为 `Bedroom/Layout/WeatherBackLayer`。最新且唯一有效的层级为 `BackgroundColor → WeatherBackLayer → BedroomBackground → 家具/交互 → UI`；天气全屏生成、忽略鼠标，并只通过背景图的透明区域显示。`weather_types`和`weather_probabilities`默认包含雨、雷、大风、星空和乌云，各20%；`weather_opacity=0.20`、`weather_animation_speed=1.0`。`daily_weather_type`和`daily_weather_day_id`保证同一天重新加载不重新随机；天气环境音由唯一的 Environment 播放器送入 SFX 总线。

## 在线消息与褪黑素动画

在线消息数据位于 `res://resources/phone_messages.json`。“生活”迁移为“妈妈”，“工作”迁移为“项目组长-速联科技控股”，新频道“速联快讯”使用`quicklink_news_read`保存已读状态，旧存档迁移只追加缺失消息。

第一人称褪黑素脚本为 `res://scripts/ui/melatonin_interaction.gd`，原创可替换占位帧位于 `res://assets/art/first_person/melatonin/`。右手伸向药瓶、握瓶摇晃、瓶口甩药和吞服结束后，才一次性执行库存-1、本晚片数+1、压力-5；梦境开始时间仍由最终片数每片提前30分钟。ESC暂停会暂停手、Tween、非真实时间Timer和环境音频进度。

## 商品像素图标

六个原创商品图标位于 `res://assets/ui/products/`：`melatonin_icon.png`、`cheap_meal_icon.png`、`visual_cortex_icon.png`、`brainstem_icon.png`、`hippocampus_icon.png`、`prefrontal_icon.png`。全部为32×32透明PNG，通过项目全局最近邻过滤显示，不包含第三方素材。
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

## 榴弹

- `grenade_attack_interval`：默认 `3.0` 秒，推荐 `0.5—10`。投掷间隔。
- `grenade_projectile_speed`：默认 `300.0 px/s`，推荐 `100—800`。投掷物飞行速度。
- `grenade_explosion_radius`：默认 `150.0 px`，当前规则固定为150。敌人/玩家实际判定半径；视觉由 `grenade_explosion_visual_radius` 单独控制。
- `grenade_enemy_damage`：默认 `30` 点，推荐 `1—300`。对每个敌人的基础伤害，各目标独立暴击。
- `grenade_player_self_damage`：默认 `10` 点，推荐 `0—100`。对玩家固定自伤，不暴击并遵守无敌帧。

## 闹钟怪

- `alarm_enemy_unlock_time`：默认 `120.0` 秒；本局经过此时间后进入普通生成池。
- `alarm_enemy_max_hp`：默认 `10` 点；基础生命。
- `alarm_enemy_contact_damage`：默认 `0` 点；接触玩家不造成伤害。
- `alarm_enemy_explosion_radius`：默认 `50.0 px`；预警、连锁和爆炸判定半径。
- `alarm_enemy_explosion_damage`：默认 `30` 点；对玩家及其他怪物的固定伤害，不触发玩家暴击。
- `alarm_enemy_death_delay`：默认 `1.0` 秒；被击杀后到爆炸的延迟。
- `alarm_enemy_blue_exp_value`：默认 `5` 经验；只生成一枚蓝色经验。

## 邮箱怪

- `mailbox_enemy_unlock_time`：默认 `180.0` 秒；解锁生成池的本局经过时间。
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

- `game_version_text`：默认 `版本号V0.3`。
- `community_group_text`：默认 `游戏存活进度群:833796070`。
- `community_group_url`：默认 `https://qm.qq.com/q/Mq3wuCuZQ6`；点击底部文字后交由系统浏览器打开。

## V0.3 音频、天气、交互与无尽模式

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

### 榴弹视觉半径

- `grenade_explosion_radius`：默认 `150 px`，实际敌人伤害与玩家自伤判定半径。
- `grenade_explosion_visual_radius`：默认 `150 px`，推荐 `100—160`，仅控制圆环、闪光和烟雾最外缘。本版固定视觉节点缩放为 `1`，避免视觉被二次放大。

### 闹钟怪与邮箱怪动画

- `alarm_enemy_visual_scale`：默认 `0.32`，推荐 `0.20—0.50`；小体型闹钟怪统一视觉缩放。
- `alarm_enemy_walk_fps`：默认 `6` FPS，推荐 `3—10`；四帧 `walk` 循环速度。
- `mailbox_enemy_walk_fps`：默认 `4` FPS，推荐 `2—8`；四帧重型 `walk` 循环速度。
- 两套步行帧分别位于 `res://assets/enemies/alarm_clock/walk_0.png` 至 `walk_3.png`、`res://assets/enemies/mailbox/walk_0.png` 至 `walk_3.png`，固定画布与脚底基准。

### 噩梦文字条件

- `early_nightmare_death_cutoff_minutes`：默认 `360` 游戏分钟，即 `06:00`，推荐 `0—1439`。
- 仅工作日、仅“梦中倒下”、且原始死亡时间严格早于该值时显示“闹钟还没响 / 今天又是一场噩梦”。`06:00` 整、主动醒来和星期日均不触发；该参数不改变提前醒来压力规则。

### 在线！消息日期与定时消息

- 每条消息保存 `received_day_id` 与唯一递增的 `message_sequence`，先按日期降序、再按序号降序排列；新消息始终显示在最上方并滚动到顶部。旧存档缺失字段时只迁移一次。
- 连续未进食达到 3 天：妈妈消息，字段 `mom_hunger_message_sent`、`mom_hunger_message_day_id`。
- 游戏第 3 天（`calendar_day_id + 1 >= 3`）：速联快讯，字段 `day3_quicklink_news_sent`、`day3_quicklink_news_day_id`。
- 游戏第 5 天（`calendar_day_id + 1 >= 5`）：北方时报，字段 `day5_northern_times_sent`、`day5_northern_times_day_id`、`day5_northern_times_deleted`。点击后永久显示灰色删除提示，但保留联系人和日期。
- 在线列表使用 `res://resources/themes/phone_pixel_scrollbar.tres`，支持滚轮、触控板和超过 `phone_scroll_drag_threshold=6 px` 后的左键拖动；拖动结束会抑制误点击。`online_scrollbar_width=5 px`，`online_message_right_safe_margin=10 px`，正文和日期共同避让滚动条。

### 无尽模式

主菜单“无尽模式”直接进入全武器临时可选的武器选择与梦境，不写入普通存档解锁。`is_endless_mode=true` 时关闭闹钟触发、工资/RAM/出勤/日期推进和普通结算；刷新间隔维持绝对下限与同屏上限，敌人数值随生存秒数继续增长。死亡后进入独立的 `res://scenes/ui/endless_results.tscn`，只显示生存时间和最终等级，可直接重开或返回主菜单。

## 快速睡觉、升级音乐与在线布局

以下参数同样位于 `res://resources/demo_config.tres`；设置值保存到 `user://game_settings.cfg`，主菜单和手机设置读取同一字段。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 快速睡觉默认状态 | `fast_sleep_default_enabled` | `true` | 布尔 | 旧设置文件无字段时默认开启 | true/false | 设置字段为`fast_sleep_enabled`，修改后下次进入梦境生效 |
| 快速睡觉梦境倍率 | `fast_sleep_game_speed_multiplier` | 1.5 | 倍 | 加速玩家、武器、敌人、投射物、刷怪、梦境时钟和状态计时 | 1.0—3.0 | 普通与无尽梦境均生效；暂停UI时临时恢复1.0，音频不变调，离场强制恢复1.0 |
| 升级音乐降低值 | `upgrade_music_duck_db` | -6.0 | dB | 升级三选一显示期间平滑降低当前Music播放器 | -24—0 | 使用命名原因`UPGRADE_UI`，不会与ESC重复累计，也不覆盖Music Bus滑轨 |
| 升级音乐过渡 | `upgrade_music_duck_fade_duration` | 0.15 | 秒 | 进入和退出升级界面的音量渐变时间 | 0—1 | 音乐保持原播放位置，天气与UI音效不受影响 |
| 在线滚动条宽度 | `online_scrollbar_width` | 5 | UI px | 在线消息列表像素滚动条宽度 | 3—8 | 与右侧安全边距共同占用内容宽度 |
| 在线消息右侧边距 | `online_message_right_safe_margin` | 10 | UI px | 保证日期、联系人和正文不被滚动条覆盖 | 4—20 | 内容宽度会自动扣除滚动条宽度和本边距 |

## 褪黑素握瓶节点与结算时机

第一人称右手层级为 `MelatoninInteraction/RightHand/HandSprite`、`BottleSprite` 与 `BottleMouthMarker`。桌面瓶保持可见直到实际按住并握瓶；同一帧切换到随右手移动的握瓶合成帧，松开鼠标也不会退回空手帧。药丸起点读取 `BottleMouthMarker.global_position`，翻转时锚点随右手旋转。现有握瓶、摇晃、翻转图片包含手指遮挡关系，因此由专用 `BottleSprite` 承载合成帧，避免重复绘制药瓶或出现前后层级错误。

## 连续未进食短信安全规则

每日正式睡觉时按“更新当日计数 → 第3天发送妈妈提醒 → 第4天判定饥饿结局 → 保存”处理。同一天由 `hunger_checked_day_id` 防止重复累计。妈妈提醒严格在 `consecutive_hungry_days == 3` 且 `mom_hunger_message_sent == false` 时加入；消息安全入口位于 `res://scripts/app/main.gd` 的 `_add_online_message()`，会验证ID和正文、按消息ID防重复、补齐 `received_day_id`、分配 `message_sequence`、设置未读并只更新数据层。手机未实例化时不会访问UI节点。旧存档缺少 `mom_hunger_message_sent`、`mom_hunger_message_day_id` 或消息序号时，分别迁移为 `false`、`-1` 和一次性递增序号。
