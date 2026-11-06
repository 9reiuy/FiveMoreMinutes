# 教程横向连廊与冲刺后速度修复

日期：2026-10-30。执行：Codex 当前会话独立完成；正式工作树 E:\GameProjects\FiveMinuteMore。已接入正式教程，未提交 Git，保留其他已有改动。

## 行为修改

- 修复完成冲刺教学后移动异常缓慢。原因是教程每帧调用禁用冲刺，原 setter 每次都会取消冲刺并清空移动速度与 DreamTime 的移动采样。现在 setter 对相同状态不重复执行，教程只在阶段切换时更新权限。
- 死亡重试按当前教学阶段重新同步冲刺权限、门锁与分区灯光。
- 使用面向连廊的横向镜头：连廊在实际 Camera 中从左至右呈一直线，各教学室朝向镜头。保留原地图与战斗坐标，避免旋转碰撞／子弹逻辑。
- 登记完成才开启冲刺室入口与对应照明；冲刺完成才开启射击室入口与对应照明；射击／手动换弹／击倒测试体全部完成后开启终点门。
- 门顶锁定为红灯、解锁为绿灯。新增灯色语义仅在教程启用，实际 Camera 验证方案一、二中的绿色均可辨认。
- 移除两扇连廊中途检查门及一扇冗余靶场内门。连廊只保留终点门，三间房的入口保留。新增教程专用冲刺落点约束，避免绕过未解锁教学室。
- 终点维持已确认剧情路线：教程 → 卧室立绘 → 睡觉 → 前台。

## 验证

1. `tests/tutorial_dash_permission_regression.gd`：2 项通过。持续重复禁用冲刺并真实按住移动键，测得约 200.000 px/s，配置值 200。
2. `tests/phase_dash_test.gd`：92 项通过；覆盖八方向、距离／碰撞恢复、攻击及跨缺口等现有行为。
3. `tests/tutorial_horizontal_route.gd`：实际 GPU Camera、正式 Main 入口，45 项通过。使用移动、E、Space、R 与攻击输入完成完整教学和出口；含一次真实致死伤害后的重试。截图门状态时临时放置观察位置，行进／冲刺／枪击没有伪造完成条件。

末次 GPU 路线奔跑测量：冲刺教学前 **200.325 px/s**，完成后 **200.236 px/s**（Engine.time_scale=1）。这是短距离实际移动速度验证，不是帧率性能验收。显卡：RTX 5070 Ti，Compatibility。

初轮测试有一个导航检查点直接朝武器台边角行走，绕开桌体后完整路线通过。补查重试时修复了阶段权限重新同步问题，并重新通过完整 GPU 路线。

记录目录：`.runtime/tutorial_horizontal_20261030/`。`result.json`、`camera.log`、`phase_dash.log`、`speed_unit.log` 为验证证据。`tutorial_normal_speed.gif` 按录制时间间隔播放，段落间有剪切，不作为全程连续录像。

观察到的未处理日志：UI 对向锚点尺寸警告，以及测试进程退出阶段的两张纹理释放／RenderingServer 销毁顺序报错。本轮未将这些日志作为已修复事项；教学过程中没有出现脚本解析错误。未开展稳定 60 FPS 验收。

## 主要文件

- `scripts/entities/dream_player.gd`：权限幂等与可选落点约束。
- `scripts/story/chapter_tutorial.gd`：按阶段同步、重试、方向提示。
- `scripts/story/training_gate.gd`：红绿指示灯、真实时间开门。
- `scripts/dream/dream_3d_tutorial_room.gd`：分区灯光与落点约束。
- `scenes/dream/Dream3D_TutorialRoom.tscn`：横向镜头。
- `tools/build_tutorial_facility.py` 与 `scenes/story/chapter_tutorial_layout.tscn`：门布局。
- `shaders/palette_quantize.gdshader` 与 `scripts/dream/preview/selective_pixel_preview.gd`：教程绿灯辨识。
