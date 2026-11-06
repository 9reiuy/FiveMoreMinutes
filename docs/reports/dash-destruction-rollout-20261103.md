# 冲刺破坏及残留结构修复

正式工程：`E:/GameProjects/FiveMinuteMore`。本轮由 Codex 当前会话与本地 Codex 子智能体直接开发；没有将项目资料委派给外部服务，没有提交 Git。

## 最终行为

- 空格冲刺只破坏身体**实际经过**的实体墙、玻璃和 PhysicalDoor 门板；落点预测、取消和未走到的路径不提前破坏。普通锁门和带 Boss 标记的物理门同样可破坏；独立电梯及过层控制器保留自身流程。
- 墙和门使用原有房间／门板材质生成碎块，附短暂扬尘。碎屑没有新增物理阻挡；墙体效果约 2.1 秒内回收，并随楼层暂停、回滚和清理。
- 玻璃破碎后整个对应格的 frame_root 一起隐藏，包含顶部 WindowHeader、轨道、立柱及影子副本；外窗所属父墙的结构和 WindowLight 同步隐藏。之后的剖切刷新不会复活框。
- 墙上装饰在生产创建时记录支撑边和楼层归属，支撑墙删除时清理完整挂件。覆盖随机墙牌、白板、消防盒、native 装饰牌、壁灯及灯光、章节监控、配电柜与挂墙灭火器。保留靠墙落地家具、地毯，以及已经飞离墙面的灭火器。
- 删除墙体实际碰撞、上半身隐形挡墙及旧批处理影子；缺口同步更新房间路由、寻路、听声和战斗房激活。只更新破口附近的墙角和影子，保留原房间贴图。
- 冲刺连续检查脚点及身体范围的地板支撑：到达地图边缘、坑或黑色虚空前缩短路径，不能越过虚空落到另一块地板。换层不继承旧缺口；失败回滚保留原楼层状态。

## 正式入口实机证据

使用 Godot 4.7.1、Compatibility、RTX 5070 Ti、独立测试存档，通过正式 Main 进入固定种子楼层。原生测试窗口最小化，保留实际 GPU 与游戏 Camera；输入为真实 InputEventKey 空格和移动输入。

- 最终运行：**31/31 通过，退出码 0**。
- 依次覆盖实体墙、真实生产墙牌、物理门、玻璃顶部框、虚空边界及实际电梯换层。
- 测试同时观察冲刺状态信号和画面帧，避免一个慢绘制帧包含全部短冲刺物理步时漏记开始状态。
- 动图使用实际截图时间间隔，无慢放；录制读回会影响帧间隔，不能用于证明性能。

[四组实景动图](E:/GameProjects/FiveMinuteMore/.runtime/shared_wall_dash_20261102/destruction_review.gif) · [前后截图](E:/GameProjects/FiveMinuteMore/.runtime/shared_wall_dash_20261102/before_after_review.png) · [最终断言结果](E:/GameProjects/FiveMinuteMore/.runtime/shared_wall_dash_20261102/all_rules_result.json) · [运行日志](E:/GameProjects/FiveMinuteMore/.runtime/shared_wall_dash_20261102/delivery.log)

## 定向回归

| 检查 | 通过 |
| --- | ---: |
| 正式 Main + 实际空格 + Camera + 换层 | 31/31 |
| 生产门／玻璃及真实冲刺段 | 28/28 |
| 实际生产挂件、落地家具保留、回滚重绑 | 38/38 |
| 墙体服务、路由、去重、换层及回滚 | 41/41 |
| 玻璃路径、碰撞与房间连接 | 45/45 |
| A1／B2／C3／V3 局部墙角与影子对照 | 32/32 |
| 地板边界、斜角、窄虚空及动态失地 | 66/66 |
| 既有相位冲刺 | 92/92 |
| WASD 与相位冲刺输入 | 91/91 |
| 碎墙效果结构、暂停、资源准备及回收 | 24/24 |
| 零水平位移碎屑及原生墙碰撞 | 15/15 |
| 既有玻璃缓存 | 10/10 |
| 既有门铰链／剖切 | 22/22 |

这些断言有重叠，不将数量相加作为独立覆盖率。逻辑回归使用 headless、GL Compatibility、Dummy 音频；视觉证据来自上面的实际 GPU 运行。

本轮录制还发现环境碎屑在水平速度归零、仍有竖直速度时提交零长射线的 normalize 警告，已修复并通过 15 项专项检查。最终 GPU 运行不再出现该警告，运行中无 GDScript 错误。退出时仍有两张各 6888 字节 ImageTexture 的资源清理提示，以及界面锚点警告；未宣称全部引擎告警清零。

## 性能边界

局部墙体提交 CPU 计时约 7–9ms，测量包含碎块构建、挂件清理、碰撞／拓扑及局部几何更新。此数值不是整帧或 GPU 时间。

首次跨房冲刺仍观察到明显停顿：在不进行截图读回的 100 帧窗口，对照**关闭全部破墙功能**仍记录最大帧间隔 2260.264ms，并确认真实空格开始、到达相同目标房、没有破坏。关闭相位视觉但保留破墙的诊断也记录 1877.026ms。这些实验没有定位最终原因，不能据此把停顿完全归因于碎块、阴影批次或单一着色器。

因此本次功能检查通过，**尚未通过稳定 60 FPS 或首次跨房无停顿验收**。未关闭用户软件进行测速，未改变地图、家具或敌人数量来制造通过结果。

## 主要实现与复跑

- `scripts/entities/player_phase_dash.gd`：实际身体路径提交与连续地板支撑。
- `scripts/dream/shared_wall_breach.gd`、`dream_3d_random_dungeon.gd`、`office_skeleton_world_base.gd`：世界提交、碰撞／拓扑及生命周期。
- `scripts/dream/dash_door_break.gd`、`physical_door_3d.gd`、`destruction_floor_debris.gd`：门扫掠、材质碎块与扬尘。
- `scripts/dream/breakable_glass_window_3d.gd`：玻璃整格窗框回收。
- `scripts/dream/wall_attachments.gd` 及各生产装饰创建路径：真实支撑关系。
- `scripts/dream/shared_wall_break_effect.gd`、`office_wall_cutaway.gd`、`wall_shadow_batches.gd`：墙体效果、局部转角与投影。

正式 GPU 复跑脚本：`tests/all_wall_glass_dash_camera_test.gd`。在独立 APPDATA 下运行：

```powershell
& 'E:/Godot/Godot_v4.7.1-stable_win64_console.exe' --path 'E:/GameProjects/FiveMinuteMore' --script tests/all_wall_glass_dash_camera_test.gd
```

协作分工：`shared_wall_topology_review` 负责世界提交、局部几何、挂件和路由；`dash_wall_integration_review` 负责门／玻璃、碎块扬尘及边界／碎屑回归；其余只读审查用于核对创建路径和停顿诊断；父会话集中审核、实际 Camera 复验并制作交付。
