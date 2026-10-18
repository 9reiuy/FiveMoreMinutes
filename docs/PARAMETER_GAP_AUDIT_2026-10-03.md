# 玩法参数缺口审计（2026-10-03，只读审计）

> 本次为**只读审计**，未修改任何 `.gd` / `.tscn` / `.tres`。
> 按 `AGENTS.md`「严禁直接动手」要求，任何落地修改需先走访谈对齐（Grill-Me）后执行。
> 工具：`tools/param_gap_audit.py`（只读扫描）、产物 `tools/param_gap_audit.json`。

审计范围：427 个 `.gd` 文件；中央配置 `scripts/data/demo_config.gd`（778 个字段）+ `resources/demo_config.tres`（仅 43 行）。

---

## 结论速览（按严重度）

| 级别 | 问题 | 影响 |
|---|---|---|
| **P0** | 文档 `GAMEPLAY_PARAMETERS.md` 与代码默认值**系统性漂移** | 照文档调参等于调错值 |
| **P1** | 3D Run 用 `const` 硬编码并**反向覆写**配置，`demo_config.tres` 对它无效 | 改配置不改 3D 手感 |
| **P2** | 玩家 dive / roll 机动参数未进入中央配置 | 手感调不了 |
| **P3** | 3D 子系统（门/家具/墙/代理）几何与物理常量散落各脚本 | 3D 场景批量调参困难 |
| **P4** | 若干**分类缺失**（Boss 战斗、敌人伤害/弹速/精度） | 平衡无抓手 |
| **P5** | UI / 特效 / 塔罗等分散常量 | 细节微调要改代码 |

---

## P0 · 文档与代码漂移（最需要立刻确认）

`resources/demo_config.tres` **只有 43 行**，仅保存少量覆写；绝大多数参数实际取 `demo_config.gd` 的默认值。
但文档中记录的数值与 `.gd` 默认值不一致：

| 参数 | 文档记载 | `demo_config.gd` 实际默认 | `.tres` 是否覆写 |
|---|---:|---:|---|
| `player_movement_speed` | 112 | **204** | 否 |
| `employee_movement_speed` | 38 | **100** | 否 |
| `basic_projectile_speed` | 155 | **550** | 否 |
| `basic_weapon_range` | 270 | **350** | 否 |
| `shotgun_pellet_damage` | 3 | **4** | 否 |
| `employee_boss_health_multiplier` | 8.0 | **1.0** | 否 |

补充核实：全仓库对 `player_movement_speed` / `employee_movement_speed` / `basic_projectile_speed` 的**运行时赋值只出现在 3D Run 里**（见 P1），没有任何代码把它们设成文档中的 112 / 38 / 155。
→ 需要确认：**以文档为准（回去改 `.gd` 默认值）还是以代码为准（更新文档）**。

另有一处疑似不一致：文档写玩家碰撞半径 `player_collision_radius = 7.5`，但 `dream_player.gd` 里有 `player_radius = 10.0`。

---

## P1 · 3D Run 绕过中央配置

`scripts/dream/dream_3d_random_dungeon.gd`：

```gdscript
const PISTOL_FIRE_RATE_3D  := 4.2
const RIFLE_FIRE_RATE_3D   := 9.0
const SHOTGUN_FIRE_RATE_3D := 2.4
const FIREARM_PROJECTILE_SPEED_3D := 1500.0
...
config.basic_projectile_speed    = FIREARM_PROJECTILE_SPEED_3D   # 1500
config.player_movement_speed     = 290.0                          # 覆写配置
config.set_meta("office_player_move_speed", 290.0)
config.employee_movement_speed   = 150.0                          # 覆写配置
```

**后果**：
- 这 6 个值是 `const`（编译期常量），改 `demo_config.tres` **完全不影响** 3D Run。
- 而且它在运行时**反向覆写**了配置对象，因此 3D Run 内 `player_movement_speed` 恒为 290、`employee_movement_speed` 恒为 150、`basic_projectile_speed` 恒为 1500。
- 另有 `effective_global_enemy_cap = 32` 也在该脚本内。

**建议**：把这 6 个值提升为 `demo_config.gd` 字段（如 `run3d_pistol_fire_rate` 等），3D Run 改为读取配置，`const` 仅作兜底。

---

## P2 · 玩家机动参数未集中（`scripts/entities/dream_player.gd`）

| 参数 | 值 | 说明 |
|---|---:|---|
| `dive_duration` | 0.35 | 翻滚/扑跃时长 |
| `dive_peak_height` | 18.0 | 扑跃峰值高度 |
| `dive_takeoff_angle_degrees` | 45.0 | 起跳角 |
| `dive_bullet_time_scale` | 0.2 | 扑跃期间时间倍率 |
| `hop_height` | 4.0 | 弹跳高度 |
| `player_radius` | 10.0 | 玩家半径（与配置 7.5 疑似冲突） |

这些都是核心手感数值，却不在中央配置中。

---

## P3 · 3D 子系统散落的几何 / 物理常量

| 脚本 | 常量 |
|---|---|
| `physical_door_3d.gd` | `door_width 4.0`、`door_height 3.0`、`door_mass 1.0`、`door_max_angle_degrees 100`、`door_open_collision_angle_degrees 35`、`latch_closed_angle_degrees 2`、`latch_velocity_threshold 0.12`、`door_min_impact_impulse 0.01`、`door_max_impact_impulse 24`、`door_max_accumulated_impulse 32`、`door_force_to_impulse 0.05`、`DEFAULT_WORLD_SCALE 32` |
| `props/reception_desk_3d.gd` | `DESK_WIDTH 3.4`、`DESK_HEIGHT 1.05`、`DESK_DEPTH 1.1`、`TOP_CAP_*`、`PLINTH_HEIGHT 0.10`、`INNER_DESK_HEIGHT 0.75`、`cap_thickness 0.05` |
| `wall_segment_3d.gd` | `wall_height 3.0` |
| `player_physics_proxy_3d.gd` | `world_scale 32`、`proxy_height 0.5` |
| `otxo_room_layout_planner.gd` | `DOOR_RESERVATION_DEPTH_CELLS 2`、`DOOR_RESERVATION_MARGIN_PIXELS 14` |
| `breakable_glass_window_3d.gd` | `FLOOR_TRACK_HEIGHT 0.06`、`structural_height 2.6`、`max_health` |
| `furniture_3d_debris.gd` | `FADE_TIME 0.4`、`LIFETIME 0.5 / 1.6` |

说明：门的一部分是 `@export`（可在场景实例里改），但**没有集中入口**，批量调整要逐个场景改。

---

## P4 · 缺失的参数分类

检索 `demo_config.gd` 后，以下重要分类**没有参数或覆盖极弱**：

- **Boss 战斗数值**：只有 `employee_boss_health_multiplier`、`dungeon_boss_min_depth`。
  缺：Boss 攻击伤害、攻击间隔/前摇、阶段切换、技能数值。
- **敌人伤害**：只有 `enemy_damage_growth_per_second = 0.012`（按秒成长）。
  缺：敌人基础接触伤害、攻击前摇、攻击冷却（相关值散在 `employee_enemy.gd`：`minimum_damage_speed 80`、`melee_visual_duration 0.24`）。
- **敌人投射物速度**：配置中无敌人弹速（只有玩家的 `basic_projectile_speed` 与 3D 的 1500）。
- **敌人瞄准 / 精度**：无 accuracy、aim error、预判等参数。

---

## P5 · 其它分散常量（微调需改代码）

- 对话：`DEFAULT_TYPEWRITER_SPEED 0.035`、`DEFAULT_COUNTDOWN_EXTRA 4.0`、`DEFAULT_INTERRUPT_THRESHOLD 0.2`、`line_total_duration 4.0`；气泡 `MAX_BUBBLE_WIDTH 340`、`OPTION_HEIGHT 32`、四边 margin、`SCREEN_MARGIN 10`。
- 塔罗：`TAROT_REVERSED_PROBABILITY 0.5`、`CARD_WIDTH 153`、`CARD_HEIGHT 237`。
- 血液特效 `black_blood_effect.gd`：`lifetime_seconds 15`、`pool_min/max_scale`、`pool_growth_duration`、`settle_seconds 0.22`、`spray_angle_limit 0.22`。
- 尸体流血 `corpse_blood_emitter.gd`：`pulse_interval 0.22`。
- 弹道拖尾 `projectile_red_trail.gd`：`trail_length 12`、`trail_width 3`。
- 椅子（可破坏家具）`scenes/dream/rooms/chair_01.gd`：`max_hp 20`、`bullet_knockback 90`、`shatter_speed_min/max 45/100`。
- 世界武器 `world_weapon_pickup.gd`：`visual_scale_override -1`。

---

## 建议的落地顺序（待确认后执行）

1. **先定 P0 的是非**：文档 112/38/155/270/3/8.0 与代码 204/100/550/350/4/1.0 哪个是期望值 → 统一（建议把期望值写进 `.tres` 显式固化，文档同步）。
2. **P1**：3D Run 的 6 个 `const` 提升为配置字段，改为读配置。
3. **P2**：玩家 dive/roll 6 个参数进 `demo_config.gd`。
4. **P3**：3D 门/家具/墙常量进配置（或至少提供一个 `run3d_*` 分组）。
5. **P4**：补 Boss 战斗、敌人伤害/弹速/精度参数。
6. **P5**：视需要逐步收编 UI/特效常量。

> 以上任何一项涉及改代码/改资源，按 `AGENTS.md` 需先完成访谈对齐并得到「方案确认，开始执行」后再动手。本次审计未做任何修改。
