# 机器敌人表现与花盆翻越 · 2026-10-23

## 本轮结果

- 无人机先旋转坠落约 0.65 秒，再爆炸并冒烟；送餐机器人倾倒约 0.42 秒后爆炸。动画使用原来的完整模型，死亡即停止攻击与玩法碰撞。像素闪光、12 个火星、8 团上升烟雾均属于原楼层，烟雾约 1.8 秒后清理。爆炸不造成伤害。
- 两种机器敌人接入现有红线显示：先淡细，再变深变粗，使用实际枪口位置。送餐机器人左右枪交替，预瞄线对应即将发射的枪口。
- 机器人增加单侧枪口闪光、枪管回缩和轻微机身后坐；无人机增加机身反冲，并修复手动开火时闪光时间不推进、后坐力不恢复的问题。
- 普通自动武器与送餐机器人每弹匣只在首发前摇结束时提示一次“叮”；连续射击不重复，换弹后重新前摇。无人机保持既有每弹匣预警节奏，同样不在后续每发重复提示。普通枪声保留。
- 花盆接入“自动跳跃”辅助功能；关闭设置则不自动翻越。不修改花盆模型尺寸、弹道高度、子弹穿透规则或空格冲刺。
- 移除机器模型各个零件的反向外壳描边，改为整个模型的像素轮廓捕获。默认灰色，玩家瞄准／近战范围内白色，不模糊画面。屏外停用捕获；跨层暂存停止，回滚后恢复同步。
- 保留原模型、100 HP、武器伤害、弹速、射程及原有生成位置／数量规则。

## 验证

单智能体执行，未提交或上传仓库。测试串行、Dummy 静音、独立测试存档；实际 GPU 窗口最小化，未关闭用户编辑器。

| 本轮运行的检查 | 结果 |
| --- | --- |
| unit_presentation_rules_test | 37 / 0 失败；整轮提示、红线接口、花盆实际翻越、后坐力恢复、原模型死亡、无爆炸碰撞伤害、烟雾生命周期、跨层失败回滚及成功清理、描边重挂接 |
| special_units_formal_camera_test | 43 / 0 失败；实际 Main 正式随机入口，RTX 5070 Ti；确认真实绘制两类单位红线、像素化／Palette 与原色画面、左右真实枪口、枪口闪光、倾倒／坠落／爆炸／烟雾分阶段画面 |
| combat_defense_power_test | 71 / 0 失败；更新原先“自动武器每发叮”的过时断言 |
| game_assistance_test | 35 / 0 失败 |
| special_units_hotel_robot_drone_test | 49 / 0 失败；死亡后立即删模型的旧断言改为转交楼层死亡特效 |
| special_units_formal_parry_test | 128 / 0 失败 |
| random_floor_lifecycle_test | 729 / 0 失败 |
| office_low_cover_projectile_test | 187 / 0 失败 |
| phase_dash_world_test | 22 / 0 失败 |
| exterior_destruction_test | 49 / 0 失败 |

合计 1350 项断言通过。相关脚本随场景载入解析通过；未进行高负载的全工程重导入。已检查本轮涉及的已跟踪文件差异，无空白错误。

画面：`.runtime/special_units_20261023/` 下的 `robot_palette.png`、`robot_aim_early/late.png`、`robot_muzzle.png`、`robot_death_tumble/burst/smoke.png`、`drone_aim.png`、`drone_muzzle.png`、`drone_death_tumble/burst/smoke.png`。死亡截图采用确定性的分阶段驱动，属于实际游戏 Camera 输出，不是连续录屏或性能证据。

主日志：`.runtime/unit_presentation_rules-final.log`、`.runtime/unit_fx_camera_final.log`；其他为 `.runtime/<测试名>-unitfx.log`。

## 未消除的日志与边界

- 实际 GPU 退出仍报原有两张 6888 字节纹理／RID 及 RenderingServer 清理警告，还有 UI anchors 警告；不能把退出码 0 说成日志完全干净。
- 部分 headless 测试仍有 dummy renderer 的 material=null 与退出 ObjectDB／资源警告。game_assistance_test 还出现暂停界面脚本 VBoxContainer 与 Control 类型不匹配的既有错误，断言本身为 35/0；此问题不属于本轮机器敌人修改，未改动暂停界面。
- 一次较长实战截图中无人机已被战斗打伤，原“截图后 HP 必须仍等于 100”的断言失败；改为检查最大 HP=100 且仍存活，出生满血由独立正式生成回归验证。另一轮新增红线断言发现测试仍设为已激活弹匣，补齐新弹匣前摇状态后，最终 GPU 43/0。未为通过截图而改动伤害或战斗规则。
- 未覆盖所有种子、长时间游戏与所有窗口尺寸；未做本轮帧耗时对比，也不宣称稳定 60 FPS。提示音只验证触发次数，测试静音，未进行主观听感验收。
