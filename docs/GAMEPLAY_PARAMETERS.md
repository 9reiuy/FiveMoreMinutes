# 《Five Minutes More》玩法参数说明

主要玩法参数统一位于 `res://resources/demo_config.tres`，字段定义位于 `res://scripts/data/demo_config.gd`。除特别说明外，修改后需要重新启动游戏，或至少重新进入使用该参数的场景；已经生成的敌人、武器和结算结果不会被追溯修改。

推荐范围用于调试平衡，并非所有字段的强制钳制范围。过高的生成数量、移动速度或粒子数量可能影响低配置设备性能。

## 时间与睡眠

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 梦境开始时间 | `dream_start_minutes` | 240（04:00） | 游戏分钟 | 默认梦境起始时间 | 0—1439 | 每片褪黑素会进一步提前 |
| 梦境闹钟时间 | `alarm_start_minutes` | 360（06:00） | 游戏分钟 | 当前剧情运行配置中的正式起床时间；到点后任意地点可长按F醒来 | 0—1439 | 无尽模式禁用闹钟 |
| 梦境时间倍率 | `real_seconds_per_game_minute` | 1.0 | 现实秒/游戏分钟 | 梦境时钟推进倍率 | 0.05—10 | 慢动作会同步影响推进 |
| 卧室开始时间 | `bedroom_start_minutes` | 1260（21:00） | 游戏分钟 | 每天卧室阶段的起点 | 0—1439 | 应早于强制睡觉时间 |
| 强制睡觉时间 | `bedroom_force_sleep_minutes` | 1440（00:00） | 游戏分钟 | 到点自动进入睡觉流程 | 1261—2880 | 与卧室时间倍率联动 |
| 卧室时间倍率 | `bedroom_real_seconds_per_game_minute` | 1.0 | 现实秒/游戏分钟 | 卧室时钟推进倍率 | 0.05—10 | 对话暂停时不推进 |
| 剧情正式起床时间 | `story_wake_minutes` | 360（06:00） | 游戏分钟 | 所有剧情日统一触发闹钟及任意地点长按F醒来 | 0—1439 | 覆盖旧工作日07:00/周日09:00；不改变考勤阈值 |
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
| 梦境出生无敌 | `player_spawn_invulnerability_duration` | 3.0 | 梦境秒 | 玩家控制启用后通过统一受伤入口免疫全部伤害 | 0—10 | 暂停时不计时；快速睡觉会按梦境模拟速度推进 |
| 受伤无敌时间 | `hurt_invulnerability_seconds` | 0.55 | 秒 | 有效受伤后的无敌时间 | 0.1—2 | 不影响受击视觉持续时间 |
| 冲刺距离 | `dash_distance` | 100 | px | 单次冲刺目标距离 | 20—400 | 受场地边界限制 |
| 冲刺持续时间 | `dash_duration` | 0.18 | 秒 | 完整冲刺所需时间 | 0.05—1 | 与距离共同决定速度 |
| 冲刺冷却 | `dash_cooldown` | 2.0 | 秒 | 单次充能恢复时间 | 0.1—20 | 多充能仍分别恢复 |
| 冲刺无敌时间 | `dash_invulnerability_seconds` | 0.18 | 秒 | 冲刺伤害免疫时间 | 0—1 | 通常不应超过冲刺持续时间太多 |
| Thunder 特效帧数 | `dash_thunder_frame_count` | 8 | 帧 | Thunder.png 实际切帧数（512×256 横向 8 列 64×256，从左到右播放） | 1—16 | 必须显式 play() 完整播放；最后一列近全透明作收尾帧 |
| Thunder 特效帧率 | `dash_thunder_fps` | 24 | FPS | Thunder 序列播放速度 | 4—60 | 与 Dash 位移/冷却/无敌完全解耦，仅控制视觉；动画播完才回收 Effect |
| 基础醒来长按 | `base_wake_hold_seconds` | 5.0 | 秒 | 06:00后任意地点醒来的基础长按时间 | 0.5—30 | 赖床增长会叠加 |
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
| 剑气素材朝向补偿角 | `katana_wave_texture_forward_angle_deg` | 180 | 度 | SP301_04 月牙素材默认尖端朝 -x，最终 rotation = 飞行方向角 + 本补偿角 | -180—180 | 保证视觉尖端/碰撞/运动方向三者一致；换剑气素材时只改本参数 |

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
| 屏幕外生成安全边距 | `enemy_spawn_visibility_margin` | 64 | px | 常规/触手怪必须生成在相机可见矩形外扩该边距的禁区之外 | 0—200 | 可见矩形由 `dream_world.get_camera_visible_world_rect()`（viewport ÷ zoom）计算，不使用固定像素猜测值；宝箱怪死亡分裂等怪物技能不受限 |
| 修正带解锁时间 | `correction_unlock_seconds` | 30 | 本局秒 | 加入随机生成池的经过时间 | 0—600 | 按单局实际经过时间，不看钟点 |
| 订书机解锁时间 | `stapler_unlock_seconds` | 90 | 本局秒 | 加入随机生成池的经过时间 | 0—900 | 90秒前不会出现 |
| 大修正带登场时间 | `large_correction_unlock_seconds` | 180 | 本局秒 | 每局唯一精英触发时间 | 1—1800 | 本次保持不变，不进入普通随机池 |
| 敌人基础生命 | `base_enemy_health` | 18 | HP | 基础怪、修正带、订书机共同基础生命 | 1—10000 | 大修正带再乘生命倍率 |
| 敌人基础接触伤害 | `base_enemy_damage` | 8 | HP | 通用接触伤害 | 0—1000 | 修正带冲刺和订书钉有独立伤害 |
| 敌人基础移动速度 | `base_enemy_movement_speed` | 42 | px/s | 继承基础敌人类的追踪速度 | 0—500 | 快速眼动会乘移动倍率 |
| 怪物死亡层级偏移 | `enemy_death_z_bias` | -1 | 级 | 死亡时施加轻微负 z bias：死亡动画低于存活怪物、仍留在世界层排序内 | -4—0 | 禁止死亡时强制提升 z_index；EnemyContainer 保持 y_sort_enabled，死亡动画仍可见 |
| 修正带蓄力时间 | `correction_charge_seconds` | 0.75 | 秒 | 冲刺前停止并预警的时间 | 0.1—3 | 不影响普通追踪速度 |
| 修正带触发距离 | `correction_trigger_distance` | 150 | px | 开始蓄力的玩家距离 | 20—300 | 与冲刺距离联动 |
| 修正带冲刺距离 | `correction_dash_distance` | 200 | px | 单次冲刺目标距离 | 20—500 | 受场地边界限制 |
| 修正带冲刺伤害 | `correction_dash_damage` | 18 | HP | 冲刺接触伤害 | 0—500 | 每段冲刺最多命中玩家一次 |
| 订书机发射间隔 | `stapler_fire_interval` | 2.0 | 秒 | 两枚订书钉之间的时间 | 0.2—10 | 与接触攻击相互独立 |
| 订书钉伤害 | `staple_damage` | 10 | HP | 投射物命中伤害 | 0—500 | 命中后销毁 |
| 订书钉速度 | `staple_speed` | 170 | px/s | 投射物移动速度 | 20—1500 | 不追踪玩家 |
| 订书钉最大距离 | `staple_max_distance` | 300 | px | 飞行累计距离上限 | 20—1500 | 达到后销毁 |
| 大修正带生命倍率 | `large_correction_health_multiplier` | 10 | 倍 | 相对基础敌人生命的倍率 | 1—50 | 不改变普通修正带生命 |
| 触手怪生命 | `tentacle_max_hp` | 100 | HP | 触手怪固定生命 | 10—1000 | 不随难度成长 |
| 触手怪接触伤害 | `tentacle_contact_damage` | 5 | HP | 靠近触手时按受击冷却结算 | 0—100 | 0.8s 冷却，不每帧扣血 |
| 触手怪生成间隔 | `tentacle_spawn_interval` | 30 | 秒 | 梦境时间体系（跟随 Engine.time_scale，暂停即停） | 5—300 | 不使用真实时间 |
| 触手怪每批最少 | `tentacle_spawn_batch_min` | 1 | 只 | 每次间隔到点随机下限 | 1—10 | 与上限取 min |
| 触手怪每批最多 | `tentacle_spawn_batch_max` | 5 | 只 | 每次间隔到点随机上限 | 1—10 | 实际生成=min(随机, 剩余额度) |
| 触手怪全图上限 | `tentacle_max_alive` | 10 | 只 | 同时存活触手数量上限 | 0—30 | 按 tentacle_enemies 组计数 |
| 触手怪距玩家最小生成距离 | `tentacle_min_spawn_distance_from_player` | 120 | px | 生成点与玩家的安全距离 | 40—400 | 优先相机禁区外（屏幕外），找不到屏外点时退而只满足该距离 |
| 触手怪紫色经验值 | `tentacle_purple_exp_value` | 25 | 经验 | 死亡掉落 1 个紫色经验球 | 1—1000 | 沿用宝箱怪紫色经验数值 |

## 经验、升级与掉落

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 1级升级需求 | `first_level_experience_requirement` | 20 | 经验 | 1级升2级所需经验 | 1—32767 | 后续等级使用增长底数 |
| 经验增长底数 | `experience_growth_base` | 8 | 底数 | n级升n+1级使用 `8^n` | 2—16 | 最终受阈值上限限制 |
| 单级经验上限 | `experience_requirement_cap` | 32767 | 经验 | 单级升级需求硬上限 | 1—2147483647 | 防止阈值溢出 |
| 修正带掉落数量 | `correction_experience_drop_count` | 2 | 枚 | 正式死亡生成的经验物数量 | 1—16 | 每枚基础值1，击杀只计一次 |
| 订书机掉落数量 | `stapler_experience_drop_count` | 3 | 枚 | 正式死亡生成的经验物数量 | 1—16 | 每枚独立使用拾取逻辑 |
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
| RAM结算规则 | `RunSettlement.calculate_run_ram(final_level)` | `max(最终等级-1,0)` | RAM/局 | 主动醒来和死亡统一按最终等级结算 | 固定规则 | 不再读取累计经验；`settled`标记防止重复结算 |
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

经验与红心视觉已换为 `res://art/icon/EXP/` 序列帧动画（循环、Nearest、按各帧自身尺寸居中绘制防抖）：蓝经验 = `Blue_EXP.png` 5帧（10×9 @ x=0/16/32/48/64），紫经验 = `Purple_EXP.png` 6帧（10×9 @ x=0/16/32/48/64/81，宝箱怪/触手怪等所有正式紫色 EXP 统一复用），红心 = `health.png` 6帧（高13，宽 14/12/10/4/12/14）。EXP 数值、磁吸半径、拾取判定与红心 15HP 回复（拾取后仍播 Heal 角色恢复动画）全部不变，碰撞/拾取半径不跟美术放大。脚本：`res://scripts/entities/xp_gem.gd`、`res://scripts/entities/heart_pickup.gd`。

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

五种常规敌人已替换为 Monster 素材包的真实序列帧（AnimatedSprite2D + SpriteFrames，帧数为实测切分）；触手怪使用 Crawling Depths 的 tentacle_sheet.png；精英魔眼（internal_id 仍为 `large_correction_tape`）已换用 Flying Eye 完整动画模型（walk/charge/death 全部接入，共用描边/Hit Flash/死亡序列，HP/伤害/冲刺/EXP 数值不变）。素材目录/帧明细见 `docs/ASSET_INDEX.md`，署名与授权见 `docs/THIRD_PARTY_ASSETS.md`。全部敌人（含精英魔眼）统一接入 EnemyOutlineController 白描边（材质实例独立、宽度统一由 `enemy_outline_width_px`=2.0 集中配置，源纹理像素空间、基于 `TEXTURE_PIXEL_SIZE`，不随节点缩放放大，VisualRoot ×4 不会变成巨描边）、Hit Flash（visual.modulate，与描边材质兼容）与基类死亡序列（停 AI→播 death→动画结束后才掉落/回收）。内部 ID 保留：basic/correction_tape/stapler/alarm_clock/mailbox/tentacle/large_correction_tape，显示名称依次为史莱姆/魔眼/精灵射手/自爆蘑菇/宝箱怪/触手怪/精英魔眼。

| 敌人 | 场景资源 | 移动动画 | 蓄力/攻击动画 | 死亡动画 | 状态同步位置 |
|---|---|---|---|---|---|
| 史莱姆（basic） | `res://scenes/entities/basic_enemy.tscn` | `walk`（6帧循环） | — | `death`（11帧非循环） | `res://scripts/entities/basic_enemy.gd` |
| 魔眼（correction_tape） | `res://scenes/entities/correction_tape_enemy.tscn` | `walk`（8帧循环） | `charge`（8帧循环） | `death`（4帧非循环） | `res://scripts/entities/correction_tape_enemy.gd` |
| 精英魔眼（large_correction_tape，Flying Eye） | `res://scenes/entities/large_correction_tape_enemy.tscn` | `walk`（Flight.png 8帧循环） | `charge`（Attack.png 8帧循环） | `death`（Death.png 4帧非循环） | `res://scripts/entities/large_correction_tape_enemy.gd` |
| 精灵射手（stapler） | `res://scenes/entities/stapler_enemy.tscn` | `walk`（8帧循环） | `attack_prepare`（6帧非循环） | `death`（10帧非循环） | `res://scripts/entities/stapler_enemy.gd` |
| 自爆蘑菇（alarm_clock） | `res://scenes/entities/alarm_clock_enemy.tscn` | `walk`（8帧循环） | `charge`（8帧循环） | `death_delay`（4帧非循环）+ `explode` 单帧 | `res://scripts/entities/alarm_clock_enemy.gd` |
| 宝箱怪（mailbox） | `res://scenes/entities/mailbox_enemy.tscn` | `walk`（6帧循环） | `slam_charge`（5帧循环）/`slam`（9帧非循环） | `death`（6帧非循环） | `res://scripts/entities/mailbox_enemy.gd` |
| 触手怪（tentacle） | `res://scenes/entities/tentacle_enemy.tscn` | `idle`（6帧循环，不移动） | — | 无帧：淡出0.5s | `res://scripts/entities/tentacle_enemy.gd` |

魔眼的 `charge` 与实际蓄力时间同时开始并结束。精灵射手冷却到点后**立即停止移动（velocity=0，`huntress_attack_stop_before_shot` 门控）并原地完整播放 attack_prepare 序列**，动画帧号 ≥ `huntress_shoot_projectile_frame`（默认3，即弓弦释放帧）时生成箭矢；动画播完恢复 walk 移动，周期到点未触发则兜底发射，发射间隔与判定不变；进入攻击时锁定 `attack_target_position`，目标失效时用锁定位置兜底方向。精英魔眼移动/死亡帧率与普通魔眼共用 `flying_eye_move_fps`/`flying_eye_death_fps`。自爆蘑菇的死亡帧融入原“死亡→延迟→爆炸”流程，爆炸机制不变；宝箱怪分裂机制保持（仍分裂为修正带场景，现为魔眼视觉）。触手怪生成器位于 `res://scripts/dream/tentacle_spawner.gd`，由 `dream_world.tscn` 的 `TentacleSpawner` 节点承载。

敌人体型放大（只改视觉与必要碰撞，不改任何战斗数值）：五种 Monster 敌人最终视觉尺寸为旧版的 **×4**（史莱姆/魔眼/精灵射手/自爆蘑菇/宝箱怪），触手怪单独 **×2**；放大只发生一次（配置保存绝对最终 scale，运行时不二次乘倍率），素材保持 Nearest 过滤、无 Mipmaps，不重采样。碰撞体按新视觉“身体核心”单独适配（不机械×4，弓/翅膀/触角/透明区不计入）：史莱姆 r18@(0,10)、魔眼 r13@原点（不含翅膀）、精灵射手 r14@(0,6)（不含弓）、自爆蘑菇 r11@(0,4)（爆炸半径仍用原配置）、宝箱怪 r46@(0,10)、触手怪 r13@(0,-6) 固定不随触须摆动。伤害数字锚点由基类 `get_damage_number_offset()` 按帧高×视觉缩放自动上移；EXP 仍从敌人锚点附近掉落；描边/Hit Flash/自动瞄准不受影响。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 史莱姆移动帧率 | `slime_move_fps` | 7 | FPS | 史莱姆 walk 速度 | 2—15 | 修改后重新进入梦境 |
| 史莱姆死亡帧率 | `slime_death_fps` | 9 | FPS | 史莱姆 death 速度 | 2—15 | 死亡序列结束后才掉落 |
| 魔眼移动帧率 | `flying_eye_move_fps` | 9 | FPS | 魔眼 walk 速度 | 2—15 | 与 AI 移动速度无关 |
| 魔眼死亡帧率 | `flying_eye_death_fps` | 6 | FPS | 魔眼 death 速度 | 2—15 | 非循环播完回收 |
| 精灵射手移动帧率 | `huntress_move_fps` | 10 | FPS | 精灵射手 walk 速度 | 2—20 | 与发射周期无关 |
| 精灵射手射击帧率 | `huntress_shoot_fps` | 12 | FPS | attack_prepare 速度 | 2—24 | 与发射帧门槛联动 |
| 精灵射手死亡帧率 | `huntress_death_fps` | 8 | FPS | 精灵射手 death 速度 | 2—20 | 非循环播完回收 |
| 自爆蘑菇移动帧率 | `mushroom_move_fps` | 8 | FPS | walk 与 charge 速度 | 2—15 | 不影响自爆计时 |
| 自爆蘑菇死亡帧率 | `mushroom_death_fps` | 4 | FPS | death_delay 速度 | 1—12 | 播完后仍按原延迟爆炸 |
| 宝箱怪移动帧率 | `mimic_move_fps` | 6 | FPS | walk/slam_charge/slam 速度 | 2—15 | 与砸击判定无关 |
| 宝箱怪死亡帧率 | `mimic_death_fps` | 7 | FPS | 宝箱怪 death 速度 | 2—15 | 动画结束后才掉落/分裂 |
| 触手怪待机帧率 | `tentacle_idle_fps` | 3 | FPS | 触手 idle 速度 | 1—10 | 环境型缓慢摆动 |
| 发射帧门槛 | `huntress_shoot_projectile_frame` | 3 | 帧号 | attack_prepare 达到该帧发射订书钉 | 0—5 | 不得超过动画末帧 |
| 修正带蓄力帧率 | `correction_charge_animation_fps` | 8 | FPS | 魔眼 charge 速度 | 2—16 | 动画循环，实际结束由蓄力计时控制 |
| 精英魔眼移动/死亡帧率 | `flying_eye_move_fps` / `flying_eye_death_fps` | 9 / 6 | FPS | 精英魔眼（换 Flying Eye 后）walk/death 速度，与普通魔眼共用 | 2—16 | `large_correction_enemy_walk_animation_fps` 已不再被精英读取 |
| 精英魔眼蓄力帧率 | `large_correction_charge_animation_fps` | 7 | FPS | 精英 charge 速度 | 2—16 | 动画循环，实际结束由蓄力计时控制 |
| 射手攻击前停步 | `huntress_attack_stop_before_shot` | `true` | 布尔 | 进入攻击序列立即 velocity=0 并暂停寻路，动画播完才恢复 | true/false | 关闭后退化为可移动射击（不推荐） |
| 订书机前摇窗口 | `stapler_attack_windup_seconds` | 0.35 | 秒 | （已废弃，保留避免旧资源报错）旧预警窗口 | — | 新实现改为冷却到点直接进入完整攻击序列 |

## 像素角色、武器特效与音频质感

配置路径统一为 `res://resources/demo_config.tres`，字段声明位于 `res://scripts/data/demo_config.gd`。下列参数在重新进入梦境后生效；音频总线滤波参数需要重新启动游戏。

| 显示名称 | 实际变量名 | 默认值 | 单位 | 作用 | 推荐范围 | 关联与注意事项 |
|---|---|---:|---|---|---|---|
| 玩家视觉缩放 | `player_visual_scale` | 0.75 | 倍 | 战斗角色视觉为上一版1.0的75% | 0.5—1.5 | 只对Visual/HealOverlay使用绝对值，不累乘；Camera和PlayerLight半径不随之缩放 |
| 玩家碰撞半径 | `player_collision_radius` | 7.5 | px | 配合缩小后的身体核心碰撞 | 5—12 | Collider与视觉同步缩小，不能按透明画布计算 |
| 玩家碰撞偏移 | `player_collision_offset` | `(0,-13)` | px | 将圆形身体碰撞对齐缩小后的躯干 | — | 玩家世界原点仍为脚底附近 |
| 玩家武器根偏移 | `player_weapon_root_offset` | `(0,-18.25)` | px | 统一控制子弹、榴弹、太刀及瞄准挂点 | — | 不改变任何武器数值 |
| 玩家描边宽度 | `player_outline_width_px` | 1.0 | px | 玩家 1px Alpha 描边（sprite_alpha_outline shader，基于 TEXTURE_PIXEL_SIZE） | 0.5—8 | 1:1 显示时 1 源像素 ≈ 1 视觉像素；重建图集每帧四周预留至少1px透明边界防裁切 |
| 敌人视觉缩放组 | `slime/flying_eye/huntress/mushroom/mimic/tentacle_visual_scale` | 0.60/0.76/1.02/0.96/1.68/1.0 | 倍 | 各素材统一缩放入口（绝对最终值，运行时不二次乘倍率；自爆蘑菇已基于上一版 0.48 ×2 = 0.96） | 0.02—2 | 只改视觉；碰撞体按身体核心单独适配；精英魔眼使用独立 `large_correction_visual_scale`=1.0；运行时不二次乘倍率 |
| 玩家待机帧率 | `player_idle_animation_fps` | 1 | FPS | 四方向待机动画速度 | 0.5—4 | 当前每个方向使用一帧，为后续增帧保留接口 |
| 玩家行走帧率 | `player_walk_animation_fps` | 8 | FPS | 四方向四帧行走循环速度（每行第2帧起，首帧为该方向静止） | 4—12 | 不改变实际移动速度 |
| 恢复绿色提示时长 | `heal_feedback_seconds` | 0.3 | 秒 | 真实回血时角色身上的绿色 modulate 提示持续时间 | 0.1—1 | 连续回血刷新时长；与 Heal 动画/恢复 SFX 同步触发 |
| 恢复音效音量 | `sfx_heal_volume_db` | -8 | dB | 统一 Heal 入口的恢复音效（程序化升调 blip，Characters 总线） | -30—-6 | 待人工替换 `res://sfx/heal.wav` 时仅需改 STREAMS |
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
| 玩家光照半径 | `player_light_radius` | 104 | 世界px | 玩家周围柔和可视亮区半径，约设计短边360px的29% | 72—144 | PlayerLight为玩家子节点，移动和Dash自动同步 |
| 玩家光照能量 | `player_light_energy` | 1.15 | 倍率 | PointLight2D中心亮度 | 0.7—1.8 | 过高会冲淡冷色梦境美术 |
| 玩家光照颜色 | `player_light_color` | `#E7F0F8` | 颜色 | 略偏冷的照明色，不作为强烈染色滤镜 | 接近白色 | 与环境色共同决定近处可读性 |
| 玩家光照衰减 | `player_light_falloff` | 0.32 | 纹理比例 | 程序化径向渐变中较亮中心区结束位置 | 0.15—0.55 | 边缘始终平滑衰减至透明 |
| 高压力光照半径倍率 | `stress_light_radius_multiplier` | 0.72 | 倍率 | 压力高于视野阈值时缩小同一PlayerLight | 0.5—1.0 | 旧黑色圆孔遮罩已停用，避免双重压暗 |
| 失业压力阈值 | `stress_unemployment_threshold` | 90 | 点 | 每日结算后达到该值计为一个高压力日 | 1—100 | 星期日也计数，同一天只检查一次 |
| 失业连续天数 | `stress_unemployment_required_days` | 3 | 日历日 | 连续达到阈值后永久失业 | 1—14 | 失业后所有出勤工资为0并清除正常出勤连胜 |

梦境基础照明由 `DreamWorld/DreamLighting/CanvasModulate` 和玩家子节点 `DreamWorld/Player/PlayerLight` 组成。PlayerLight使用运行时生成的256×256径向`GradientTexture2D`，全场只有这一盏主要动态光源；旧`StressVisionOverlay`圆孔遮罩不再实例化。高压力通过`stress_light_radius_multiplier`收缩同一光源，不与第二层黑幕叠加。

## 对话立绘统一描边与冷蓝滤镜

所有正式对话立绘共用 `ConfirmationDialog/Portrait/CharacterArt`，材质使用 `res://shaders/sprite_alpha_outline.gdshader`。`dialogue_portrait_outline_color=#346DB3`、`dialogue_portrait_outline_width_px=2.0`；`dialogue_portrait_filter_color=#8DB9D8`、`dialogue_portrait_filter_strength=0.18`只给主体做轻度冷蓝调和，不覆盖描边。运行时按完整2560×1440画布到640×360显示比例换算描边采样宽度。`chr.png`与两张Talk纹理只替换同一节点的Texture，不改变Position、Anchor、Offset、Scale或Material。说话帧由逐字Reveal驱动：第1—2个可见字符使用Talk A，第3—4个使用Talk B，以此循环；空白和控制字符不计数，句末或跳过立即恢复`chr.png`。当前三张源PNG的角色下缘贴到画布底边，因此Portrait启用`outline_inner_at_texture_edge`：普通透明区域仍向外描边，纹理边界处以同宽内描边补偿，不修改源PNG、不缩放或移动构图。

## 战斗辨识与升级老虎机

- `projectile_glow_alpha=0.16`、`projectile_glow_radius=9px`：弹丸共享低成本绘制光晕；不使用PointLight2D。
- `pickup_glow_alpha=0.18`、`pickup_glow_radius=10px`：Heart等通用拾取物光晕，仍受梦境环境压暗。
- `xp_glow_alpha=0.30`、`xp_glow_radius=5px`：EXP局部光晕的透明度与半径（直径约10px）；蓝色与紫色EXP使用各自的稀有度颜色，不使用`PointLight2D`。
- `electric_shield_animation_fps=30`、`electric_shield_visual_scale=0.18`：意识固化电气护盾60帧循环的帧率与独立视觉节点缩放，不影响护盾挡伤机制。
- 老虎机CRT使用`res://shaders/upgrade_slot_crt.gdshader`的`barrel_distortion=0.075`，仅扭曲最终视觉采样，卡片、重抽按钮与描述区仍使用未扭曲的Control坐标接收输入。
- `player_hp_bar_width=50px`、`player_hp_bar_height=5px`、`player_hp_bar_visible_duration=2.5秒`：血条只在实际受伤后出现，回血只刷新已显示填充。
- `dialogue_text_blip_volume_db=-25dB`、`dialogue_text_blip_frequency_hz=420Hz`、`dialogue_text_blip_duration=0.045秒`：每个可见字符由SFX单播放器重触发原创短音。
- 升级老虎机每次打开从`upgrade_reel_start_speeds=(84,92,78)px/s`开始，使用原有`upgrade_reel_acceleration_curve`的Quadratic Ease-In在`upgrade_reel_acceleration_duration=1.35秒`内加速到`upgrade_reel_max_speeds=(440,472,416)px/s`，之后保持上限。两组速度均为上一版实际值的2倍；锁定仍由`upgrade_slot_lock_deceleration=0.16秒`短暂Ease-Out并吸附完整Cell。
- 每跨过一个完整Cell触发原创程序化`slot_tick`（45ms、`sfx_slot_tick_volume_db=-28dB`、`sfx_slot_tick_min_interval=0.025秒`），走UI/SFX总线，单播放器重触发避免三列叠音爆音。锁定格子的名称和描述直接读取同一个Upgrade/Weapon字典。
- CRT仅覆盖`UpgradePanel/CRTOverlay`，参数为Scanline `0.10`、Noise `0.025`、Vignette `0.14`；Overlay忽略鼠标，Shader不改变Control输入坐标，暂停期间仍由GPU时间更新。
- 剧情模式武器分离为解锁资格和当前装备：存档字段`current_weapon_id`默认`basic`并跨天/死亡保留。本局`used_weapon_reward_ids`在开始时加入初始武器，真正选择并装备新武器后再加入；这些武器随后从本局老虎机池排除。仅滚到、锁定或Reroll不会加入，下一局重新初始化。无尽模式通过强类型`configure_run_weapon_state()`接收本局选择与全武器池，不写剧情字段。
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
- `grenade_spawn_offset_px`：默认 `14` px，推荐 `0—64`。榴弹出生点沿瞄准方向的偏移，保证出生在当前玩家碰撞体外侧；目标仍为攻击瞬间鼠标世界坐标快照，飞行不追踪鼠标。榴弹本体为纯 Node2D 无碰撞体，不会因触碰玩家提前爆炸，玩家自伤只来自爆炸 AoE（Dodge/出生无敌仍可阻挡）。飞行越界判定使用扩图后的 `ARENA_BOUNDS = Rect2(24, 24, 992, 432)`（旧小地图尺寸是脚底爆炸根因，已修正）。目标与出生点重合时方向回退最近一次有效瞄准方向（`last_aim_direction`），再兑底玩家默认面朝，绝不取消投掷；每次正式攻击必创建 1 枚投射物，链路断裂时 push_error 明确报错。

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

- `game_version_text`：默认 `V0.4.7`。唯一玩家可见当前版本字段；主菜单底栏拆为两个独立 Label：版本号（Hover 变亮、点击打开全屏公告）与群号（点击保留原有群链接），整体居中、互不重叠；`main_menu.tscn`、导出预设与公告首行均同步。
- `community_group_text`：默认 `游戏存活进度群:833796070`。
- `community_group_url`：默认 `https://qm.qq.com/q/Mq3wuCuZQ6`；点击群号后交由系统浏览器打开。
- 公告不再进入主菜单自动弹出；点击版本号调用 `AnnouncementWindow.show_announcement()` 打开全屏公告（`#0E140D` 同主菜单背景、正文 ScrollContainer 滚动、底部中央关闭按钮），内容仍来自 `res://data/announcement.txt`。

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

### 自爆蘑菇与宝箱怪动画

- 旧字段 `alarm_enemy_visual_scale`、`alarm_enemy_walk_fps`、`mailbox_enemy_walk_fps` 已删除，由 Monster 素材统一配置组接管：自爆蘑菇（原闹钟怪）用 `mushroom_move_fps`/`mushroom_death_fps`/`mushroom_visual_scale`，宝箱怪（原邮箱怪）用 `mimic_move_fps`/`mimic_death_fps`/`mimic_visual_scale`。
- 新素材为 `res://art/Monster/Mushroom/` 与 `res://art/Monster/Mimic/` 的横条等分序列帧（帧明细见 `docs/ASSET_INDEX.md`），旧的 `assets/enemies/alarm_clock/`、`assets/enemies/mailbox/` 单帧贴图不再被敌人场景引用。

### 噩梦文字条件

- `early_nightmare_death_cutoff_minutes`：默认 `360` 游戏分钟，即 `06:00`，推荐 `0—1439`。
- 仅工作日、仅“梦中倒下”、且原始死亡时间严格早于该值时显示“闹钟还没响 / 今天又是一场噩梦”。`06:00` 整、主动醒来和星期日均不触发；该参数不改变提前醒来压力规则。

### 在线！消息日期与定时消息

- 每条消息保存 `received_day_id` 与唯一递增的 `message_sequence`，先按日期降序、再按序号降序排列；新消息始终显示在最上方并滚动到顶部。旧存档缺失字段时只迁移一次。
- 连续未进食达到 3 天：妈妈消息，字段 `mom_hunger_message_sent`、`mom_hunger_message_day_id`。
- 游戏第 3 天（`calendar_day_id + 1 >= 3`）：速联快讯，字段 `day3_quicklink_news_sent`、`day3_quicklink_news_day_id`。
- 游戏第 5 天（`calendar_day_id + 1 >= 5`）：北方时报，字段 `day5_northern_times_sent`、`day5_northern_times_day_id`、`day5_northern_times_deleted`。点击后永久显示灰色删除提示，但保留联系人和日期。
- 手机正式 App 共用 `res://resources/themes/phone_pixel_scrollbar.tres`。`online_scrollbar_width=5 px`保留为基础值，运行时 VScrollBar 的视觉宽度和鼠标命中宽度统一取其50%（当前2.5 px）；ONLINE、眠网、QUICKLINK与设置继续支持滚轮、轨道/滑块操作，内容拖动阈值为`phone_scroll_drag_threshold=6 px`。设置中的Master/Music/SFX音量滑轨已恢复128 px宽，与本条滚动条调整无关。

- 卧室电脑的记事本、21点与梦境浏览器共用`res://scripts/ui/computer_window_shell.gd`绘制的窗口壳。21点与浏览器支持最小化、电脑屏幕内最大化/还原及关闭；21点牌局数据仍保留在原`BlackjackApp`实例中，窗口状态变化不退款也不重复扣款。

- 梦境浏览器位于`res://scenes/ui/dream_browser_app.tscn`，只展示剧情存档现有解锁标记允许的武器。选择后通过主流程既有`_on_story_weapon_equipped()`更新`current_weapon_id`、当天快照与存档；无尽模式的本局武器状态不读取该选择。

- 卧室饱腹提示只绘制胃/碗像素图标，不再常驻显示“吃饱了”；鼠标悬停图标时显示同文案的小型蓝色Tooltip，权威状态仍为`food_eaten_today`。

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
- 相机：`Player/DreamCamera`（Camera2D），`limit_left/top/right/bottom = 0/0/1040/480`，带位置平滑；不会拍到地图外空白。瞄准使用 `get_global_mouse_position()` 自动兼容相机；压力视野 Shader 的玩家屏幕坐标改用 `get_global_transform_with_canvas().origin`。手动准星（`scripts/ui/crosshair.gd`）位于 CanvasLayer 屏幕坐标系，每帧按 `(世界瞄准点 - 相机屏幕中心) × zoom + 视口/2` 换算，精确跟随鼠标世界位置，不随 WASD/玩家/相机漂移；后坐力仅是屏幕局部视觉偏移，不改变瞄准目标；梦游模式仍隐藏准星。
- **06:00任意地点醒来**：剧情闹钟触发后不生成或寻找梦境床；玩家在当前位置长按F进入慢动作并累计醒来进度。05:59尚不可用，06:00起开放；无尽模式禁用该流程。
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
- **脚底锚点**：玩家世界位置保持不变；视觉中心`(0,-18.25)`、Collider圆`r7.5 @ (0,-13)`、WeaponRoot`(0,-18.25)`。PlayerLight仍直接挂在DreamPlayer根节点，中心位于玩家世界位置，光照半径保持原值。
- **统一恢复反馈**：`dream_player.heal()` 与解离复活均调用 `_apply_heal_feedback()`：恢复 SFX（`&"heal"`，程序化升调 blip，Characters 总线，`sfx_heal_volume_db=-8`）+ 角色绿色 modulate 提示 `heal_feedback_seconds=0.3`（刷新式、不创建 Material/Tween，受伤闪红/复活闪金优先级更高）+ 现有 Heal/Frames 动画（700ms 节流）。满血不触发（heal() guard）。
- **手机收起区**：顶部 1/3 交互区视觉完全隐藏（删除 hover 白色 0.05 矩形），`_phone_action_at`/`_retract_area_rect` 判定与内容优先规则不变。
- **公告**：进入主菜单不再自动弹；底栏版本号 Label（Hover 变亮 `#8FB4B5`、点击）调用 `show_announcement()`；公告全屏（anchors full rect、z_index 5、`#0E140D` 背景阻止底层点击、正文 ScrollContainer 滚动、底部中央关闭按钮）；群号 Label 独立点击区保留 shell_open。
- **版本号**：`game_version_text`、demo_config.tres、main_menu.tscn、export_presets 文件版本、公告首行全部同步 V0.4.5。

## V0.4.7 升级稳定性与拾取反馈

- **Typed Array**：剧情升级武器奖励池由`_slot_weapon_ids_for_mode()`显式返回`Array[String]`，不再将三元表达式产生的普通`Array`赋给typed array。
- **CRT范围**：`UpgradePanel/CRTOverlay`只覆盖三列Reel主体，不覆盖下方Description与Reroll区域。
- **拾取物**：EXP与Heart复用`res://scripts/entities/pickup_attraction.gd`，按“抬升Ease-Out → 二次Bezier Ease-In吸入”移动，终点每帧跟随玩家。
