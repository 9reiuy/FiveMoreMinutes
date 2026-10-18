# 配置字段「孤儿」审计（2026-10-03，只读）

> 承接 `PARAMETER_GAP_AUDIT_2026-10-03.md`。本次同样**只读**，未修改任何代码 / 数值 / 资源。
> 工具：`tools/param_usage_audit.py`，产物 `tools/param_usage_audit.json`。

## 方法与范围（一个关键坑）

统计「哪些配置字段在活代码里从未被引用」时，**必须先排除陈旧副本**，否则会严重误判：

- `.codex-worktrees/`、`.codex-worktrees-real/`（旧 git worktree 副本）
- 嵌套重复目录 `5min more/5min more`、`5min more-backup`
- `.godot/`、`build/`、`tmp/` 等

第一轮扫描没排除这些，结果 `dungeon_room_count` 显示「7 处引用」、`vision_darkness_alpha` 显示「35 处引用」——**全部来自陈旧 worktree**，活代码里其实是 0。排除后才得到真实结果。

## 核心结论

`demo_config.gd` 共 **778 个字段**，其中 **140 个（约 18%）在活代码（`scripts/`、`scenes/`、`tests/`）中零引用**。

根因：随 `AGENTS.md` 声明的「**旧 2D Dream 已退役**」，消费这些字段的脚本已被移除，但字段与文档都留了下来。核实：

| 已退役/缺失 | 活代码现状 |
|---|---|
| `scripts/dream/dream_world.gd` | **不存在**（仅在旧 worktree 里有） |
| `scripts/dream/dream_room_manager.gd` | **不存在**（仅在旧 worktree 里有） |
| mailbox 敌人 | 只剩 `assets/enemies/mailbox` 美术目录，**无脚本** |
| alarm 敌人 | **无脚本** |
| 仍活着 | `employee_enemy.gd`、`dream_3d_random_dungeon.gd`、`scripts/dream/tarot/*` |

## 孤儿字段分组（140 个 / 45 组，列主要组）

| 组 | 数量 | 代表字段（默认值） |
|---|---:|---|
| `enemy_*` | 15 | `enemy_initial_spawn_interval 2.0`、`enemy_minimum_spawn_interval 0.65`、`enemy_spawn_count_per_interval 2`、`enemy_health_growth_per_second 0.0`、`enemy_damage_growth_per_second 0.012`、`enemy_spawn_minimum_spacing 30`、`enemy_spawn_position_max_retries 12`、`enemy_spawn_visibility_margin 64`、`enemy_unlock_days`、`enemy_base_spawn_weights`、`enemy_environment_glow_alpha 0.12` |
| `employee_*` | 12 | `employee_xp_value 5`、`employee_knockdown_weapon_drop_force 160`、`employee_knockdown_launch_velocity 90`、`employee_room_density_per_10000_px 1.15`、`employee_room_furniture_capacity_penalty 0.15`、`employee_room_door_capacity_bonus 0.5`、`employee_room_minimum_capacity 2`、`employee_*_room_density_multiplier`、`employee_ground_weapon_room_chance 0.35`、`employee_room_pacing_weights` |
| `stress_*` | 9 | `stress_threshold_spawn 30`、`stress_threshold_speed 50`、`stress_threshold_vision 70`、`stress_spawn_multiplier_over_30/50/70`、`stress_enemy_speed_multiplier_over_50/70`、`stress_absolute_minimum_spawn_interval 0.25` |
| `dungeon_*` | 8 | `dungeon_room_count 8`、`dungeon_boss_min_depth 4`、`dungeon_loop_connection_chance 0.28`、`dungeon_population_refill_interval 3.0`、`dungeon_population_refill_batch 3`、`dungeon_enemy_follow_door_distance 240`、`dungeon_enemy_follow_maximum 6`、`dungeon_enemy_door_follow_delay 0.35` |
| `camera_*` | 6 | `camera_dead_zone_x 28`、`camera_dead_zone_y 18`、`camera_follow_smoothing 10`、`camera_small/medium/heavy_impulse 2.0/4.5/8.0` |
| `main_*` | 6 | `main_menu_hover_offset 4`、`main_menu_hover_scale 1.04`、`main_menu_selection_tween_duration 0.18` 等 |
| `world_*` | 5 | `world_card_interaction_radius 50`、`world_card_linear_damp 10`、`world_card_max_push_speed 90`、`world_weapon_drop_offset 28`、`world_weapon_mass 0.65` |
| `player_*` | 5 | **`player_base_maximum_health 80`**、`player_spawn_invulnerability_duration 3`、`player_visual_offset`、`player_idle_animation_fps 1`、`player_walk_animation_fps 8` |
| `furniture_*` | 5 | `furniture_pistol/assault_rifle/shotgun_pellet/hitscan_force_multiplier`、`furniture_impact_velocity_retention 0.72` |
| `phone_*` | 5 | 折叠高度、滚动条宽、新消息震动参数 |
| `large_/medium_/small_room_*` | 12 | 各房型 `enemy_cap`、`initial_enemy_count`、`wave_count`、`enemies_per_wave` |
| 其余 22 组 | 52 | `ui_*`、`experience_*`、`dream_*`、`alarm_*`、`basic_*`、`death_*`、`vision_*`、`interaction_*`、`character_*`、`heart_*`、`crosshair_*`、`upgrade_*`、`kick_*`、`lucille_*`、`bedroom_*`、`melatonin_*` 等 |

## 三个值得单独说的个案

### 1. 玩家最大生命值：配置字段完全没用上
- `demo_config.gd:396` `player_base_maximum_health = 80.0` → **零引用**。
- 实际来源：`dream_player.gd:85` `@export var maximum_health := 80.0`（实例级 export），
  且运行时被**角色卡系统覆盖**：`maximum_health = float(total_hp_cells) * runtime_config.character_card_hp_per_cell`（`dream_player.gd:488`）。
- → 想调玩家血量，改 `player_base_maximum_health` **无效**；要改卡片的 `character_card_hp_per_cell` 或实例上的 `maximum_health`。

### 2. 压力档位（文档里的 0 / 30 / 50 / 70）没有接线
- 压力系统仍活着（`scripts/app/main.gd`、`game_state_rules.gd`、`run_settlement.gd`），但只用到 6 个字段：
  `stress_default`、`stress_max`、`stress_absent_gain`、`stress_late_gain`、`stress_unemployment_threshold`、`stress_unemployment_required_days`。
- 文档那张「压力阶段」表对应的 `stress_threshold_spawn/speed/vision` 与各档倍率**均未被读取**。

### 3. 地牢与相机：一半接线一半断
- `dungeon_*` 8 个全孤儿 —— 当前 3D Run 走的是 `dream_3d_random_dungeon.gd` 自己的 const（见上一份审计 P1）。
- 相机只有 `camera_aim_smoothing` 活着（`dream_3d_random_dungeon.gd:6064`），其余 `camera_follow_smoothing`／死区／三档 impulse 全部孤儿。

## 与上一份审计的关系

这份解释了上一份的 **P0 文档漂移**：`GAMEPLAY_PARAMETERS.md` 里大量条目描述的是**已退役系统**（旧 2D Dream 地牢、旧敌人刷新、mailbox/alarm 敌人、旧房型波次、旧相机跟随）。这些条目对应的字段还在 `demo_config.gd` 里，docs 也还写着，所以「文档看起来很全」，但改了没有效果。

## 建议的处置方向（仅建议，本次未执行）

把 140 个孤儿字段三分类，逐类确认后再动：

1. **确认废弃 → 从 `demo_config.gd` 与文档移除**（旧 2D Dream、mailbox/alarm、旧房型波次、`dungeon_*` 等）。
2. **应该接线但未接线 → 补接线**（如 `player_base_maximum_health`、`stress_*` 档位、`furniture_*_force_multiplier`）。
3. **仍有价值但暂无消费方 → 文档标注 `deprecated / 待接线`**，避免误调。

> 按 `AGENTS.md`：以上任何删除 / 接线 / 改值都属于改动，需先完成访谈对齐并拿到「方案确认，开始执行」。
> **本次审计未修改任何数值或代码。**
