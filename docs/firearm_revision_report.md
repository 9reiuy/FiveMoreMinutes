# 敌我射击、步枪扩散与历史拖尾验收报告

## 完成的改动

- `scripts/dream/dream_firearm_rules.gd` 统一手枪、步枪、霰弹的基础参数读取、散射方向生成及弹丸初始化。玩家保留升级，敌人保留额外瞄准误差与射击节奏扰动。霰弹继续每个扇区随机一颗。
- 玩家步枪总扩散角从 2° 开始，每颗实际生成的弹丸增加 1°，上限 6°。松开扳机以 16°/秒恢复，最大恢复时间 0.25 秒；停用和重新配置重置。额外攻击使用相同扩散，空弹药不会增加扩散；没有移动惩罚。
- 霰弹蓄力彻底删除：计时、状态机、松手补发、玩家动画节点、取消入口及四项专用配置均已移除。现在按下立即射击，按住按原有射速连发。保留普通散射、伤害、弹丸数和每轮一发弹药规则。
- 敌人所有枪械共用的开火前摇提示继续使用共享素材，动画配置改为 `employee_ranged_windup_animation_fps`，与已移除的玩家霰弹蓄力独立。
- 正式 3D 弹丸记录最近 0.06 秒游戏时间内的真实位置；慢动作使用相同游戏时间窗口。最近邻白色纹理保持单个深度载体，命中即停止移动和伤害、移除弹头光晕、退出战斗弹丸组，尾迹在 0.04 秒内淡出。
- 拖尾最多保留 16 个采样点，插值时间边界；视觉半径限制为 112 px。正式 1500 px/s 的完整尾长为 90 px。更快的自定义弹丸可能触及视觉范围上限，碰撞、伤害和速度不受影响。3D 捕获范围扩大为 256×256，动态弹头 UV 保持发光位置正确。

射速、伤害、弹速、射程、弹药及穿透规则均保留现有配置；办公室子弹原有的门穿透行为继续保留。

## 自动化验证

使用 Godot 4.7.1，无图形回归运行。以下 14 组测试最终均退出 0，断言均通过且没有脚本解析错误；既存的引擎和资源提示列于下方：

| 测试 | 结果 |
| --- | --- |
| firearm_shared_rules_test | 231 项，0 失败 |
| player_rifle_spread_test | 156 项，0 失败 |
| shotgun_direct_fire_test | 14 项，0 失败 |
| projectile_history_trail_test | 19 项，0 失败 |
| 3d_firearm_tuning_test | 103 项，0 失败 |
| office_ballistics_test | 98 项，0 失败 |
| office_firearm_integration_test | 15 项，0 失败 |
| firearm_impact_visual_test | 28 项，0 失败 |
| point_blank_wall_door_shot_test | 18 项，0 失败 |
| test_furniture_bullet_penetration | 通过 |
| employee_perception_test | 18 项，0 失败 |
| otxo_enemy_ai_parity_test | 通过 |
| dream3d_combat_parity_test | 79 项，0 失败 |
| otxo_combat_feel_and_camera_test | 通过 |

测试清单与日志路径：`.runtime/firearm_revision_suite.json`。对应日志以 `final_revision_` 开头。

更新了旧测试夹具：关闭会移动测试玩家的电梯入场动画；用新生成的弹丸 ID 计数；为尸体清理设置明确的测试保留时间；用独立且启用碰撞的关闭门验证瞄准遮挡、门受伤和现有子弹穿门规则。未为满足测试改变生产物理规则。

## 实际 Camera3D 画面

`tests/capture_firearm_revision.gd` 在正式 3D 世界、实际灯光与相机下逐步推进真实弹道，并捕获手枪、霰弹、步枪、较小时间步长、斜向射击和墙面命中后的画面。截图位于 `.runtime/firearm_revision_visual/`，渲染日志没有错误。此工具使用确定性时间步长，未进行全场景长时间性能压测。

## 已知验证限制

- 沙箱下无图形运行仍会报告 Windows 证书库读取提示；部分旧测试退出时仍有资源清理提示。
- 原有射击配置测试会输出既存的 `office_dither_lighting::_register_mesh` 延迟调用错误；本次修改前已复现，103 项断言仍通过。
- 额外尝试的旧 `dream3d_integration_test.gd` 假定首个地板节点是 MultiMesh，当前正式地板结构已不满足该假定，于第 24 行中断。该旧测试还包含旧移动速度和门阻弹规则，不计入本次通过的 14 组测试；未改动它。
- 本次只调整射击与拖尾，以及删除玩家霰弹蓄力；房间生成、家具与敌人感知的生产逻辑不在改动范围内。
