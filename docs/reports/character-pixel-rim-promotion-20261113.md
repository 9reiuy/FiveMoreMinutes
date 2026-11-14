# 角色彩色边缘受光：正式推广

2026-11-13，用户在四种光色小样后批准“可以推广”，随后要求确认其他灯光也能照射角色。本轮已接入正式共用角色材质；重新启动游戏后生效。正式入口继续为 `scenes/app/main.tscn`，流程和玩法未改。

## 推广结果

- 玩家、人形敌人及其手持武器自动启用约一源像素宽的内侧受光边缘，使用现有真实灯光颜色、距离／锥角衰减和阴影。
- 逐灯计算后叠加，支持多灯同时照射。没有从灯列表中挑一盏，也没有把小样关闭其他灯光的设置带入正式世界。
- 保留角色原图、八方向、刘海定位／镜像／层级、手臂动作、武器数值、原有投影、近战目标提示、受击闪白和烟雾剪影。家具、血液及非角色载体默认不开启此角色效果。
- 身体与长枪捕获画布尺寸不同，Alpha 联合边缘现按两者实际尺寸换算 UV；初始化时绑定一次，删除角色时释放跨捕获纹理引用。
- 正式路径直接使用共享 Shader，不运行小样的每帧材质发现或 Shader 拼装。独立小样也默认恢复场景原灯，按 L 可随时恢复；1／2／3／0 才进入单灯隔离对照。

## 实际 Camera 证据

- [红蓝两灯同时照射／遮挡红灯后保留蓝灯](../../.runtime/character_rim_promotion_20261113/delivery/multilight_and_occlusion.png)。同姿态实际 Camera，Nearest 三倍局部放大，没有给截图调色。
- [正式 Main 关卡画面](../../.runtime/character_rim_promotion_20261113/native/formal_main.png)。使用正式场景原有灯光，未安装测试灯或小样隔离控制器。
- [八方向与原动作正常速度 A/B](../../.runtime/character_rim_promotion_20261113/delivery/eight_directions_normal.gif)。20fps、每步 0.05 秒的原动作时间轴回放，同姿态对照；同步运行正式刘海更新。原始 PNG 保留在 `animation/motion/`。
- 原小样入口仍为 [Preview_Character_Rim.cmd](../../Preview_Character_Rim.cmd)，用于继续查看原版／新版及单灯隔离，正式入口不依赖此文件。

## 多灯验证

`character_rim_promotion_test.gd` 直接检查正式共享材质，测试时没有安装 A/B Shader 注入器。固定角色、镜头和灯位，用左红灯、右蓝灯分别以及同时照射玩家和敌人，并放入真实阴影遮挡体。

下表为角色区域中新亮边相对同色照明基线的正向 RGB 差值之和，单位是屏幕通道值累计，用于区分光色贡献，不是物理光通量。

| 条件 | 新增 R | 新增 G | 新增 B |
|---|---:|---:|---:|
| 仅红灯 | 110.271 | 2.525 | 1.651 |
| 仅蓝灯 | 2.329 | 11.576 | 111.843 |
| 红蓝同时 | 111.706 | 13.643 | 112.757 |
| 红灯被墙遮挡、蓝灯保持 | 2.329 | 11.576 | 111.843 |
| 两灯全关 | 0 | 0 | 0 |

红蓝贡献同时保留；遮住红灯只消除它的亮边，蓝灯保持。开关角色亮边前后，场景原有 Light3D 的接收掩码没有变化。正式 Main 中保留了多盏可照射角色的原有 RoomLight／RoomFill 与窗外光；光源是否实际影响某个像素，继续取决于范围、朝向及遮挡。

## 检查范围

运行环境：Godot 4.7.1、Forward+／Vulkan、RTX 5070 Ti、640×360 世界视口。自动入口使用启动前准备的私有静音配置，保留音频驱动和逻辑，不改变用户正常游戏音量。

| 项目 | 结果 |
|---|---|
| 原生黑色像素探针 | 6 项断言通过：左右换侧、无光消失、受击／烟雾不重叠、内部覆盖抑制 |
| 原生推广与正式入口 | 28 项断言通过：默认角色／武器启用、不同画布尺寸映射、多灯叠加、单灯遮挡、场景原灯、白盒连通／门侧规则、真实 Main 工厂与默认材质 |
| 动作、定位与生命周期 | 86 项断言通过：八方向原图／Alpha、刘海接点／镜像／层级与 GPU 捕获同步、原近战／翻滚姿态及恢复、真实投影代理、白盒／正式美术重建、旧绑定释放和 Shader 还原 |
| 改动边界 | 正式部分仅修改共用角色显示桥与共用受光 Shader，并新增角色边缘 include；原刘海脚本、图集定位、角色原图、玩家／敌人玩法脚本和灯光管理脚本哈希保持不变 |

这些是功能断言，不等同于全部章节或所有战斗组合回归。近战／翻滚检查覆盖原姿态回调和恢复，没有宣称通关或完整死亡／手机流程全部验收。

## 多人开销

原小样每帧查找／绑定材质的方式已移除。正式桥在创建角色时绑定共享材质和跨捕获参数一次，不增加灯或捕获视口。测试 A/B 助手用按材质与显示桥缓存的查找；性能窗口内完全关闭小样发现回路，两侧条件相同。

本次使用同一测试场、实际阴影／反射／正式美术和单盏受控灯。分别放置 12／24 个角色，全部角色原点在镜头视锥内，调用原有步态更新，不驱动交战 AI。每个数量按原版→开启→开启→原版各四秒，每块前预热一百帧。基线是从共享 Shader 中移除本功能代码的版本，开启侧为正式共用代码。VSync 和限帧关闭；各块 focused=true；采样中不截图和写磁盘，所有峰值保留。

合并各状态的两块原始记录，单位毫秒，均为相邻 process frame 墙钟间隔：

| 角色数 | 状态 | 帧数 | P50 | P95 | P99 | 最大 |
|---:|---|---:|---:|---:|---:|---:|
| 12 | 基线 | 1460 | 5.315 | 6.539 | 7.599 | 13.045 |
| 12 | 开启 | 1483 | 5.297 | 6.173 | 6.741 | 7.729 |
| 24 | 基线 | 1096 | 7.196 | 8.418 | 9.415 | 10.790 |
| 24 | 开启 | 1045 | 7.491 | 9.055 | 11.358 | 14.977 |

24 人本次 P95 增加约 0.64ms。12 人的较低 P95 不能解释为开启效果会加速，短采样含系统波动。本轮受控测试没有重现旧小样的 91.961ms 峰值；这不构成多灯密集交战、整章或全游戏稳定 60FPS 认证。多灯功能另以实际双灯和正式 Main 检查，没有把单灯性能结果冒充多灯性能结果。

## 退出告警与对照

功能测试进程最终 exit 0，动作与测试场检查无脚本／Shader 编译错误。正式 Main 测试退出时仍记录两个 ImageTexture 释放阶段的 `RenderingServer::get_singleton() is null`、四个 Texture RID 以及控件锚点告警。

额外用本轮修改前保存的共享 Shader 代码运行真实 Main，在同样加载／释放步骤下复现了相同退出告警（`legacy_shader=true`、`world_loaded=true`、exit 0）。本轮保留此证据，没有把退出日志称为零告警，也没有扩大修改原有 Main／UI 退出代码。[旧 Shader 对照日志](../../.runtime/character_rim_promotion_20261113/legacy_cleanup.stderr.log)。

## 文件与原始数据

正式实现：

- `shaders/dream3d/character_pixel_rim.gdshaderinc`
- `shaders/dream3d/lit_pixel_carrier.gdshader`
- `scripts/dream/dream_3d_actor_depth_bridge.gd`

预览／验证：`scripts/testing/character_rim_effect.gd`、`character_rim_sample.gd`，`tests/character_rim_promotion_test.gd`、`character_rim_promotion_perf_test.gd`、`character_rim_legacy_cleanup_test.gd`，及原扩展测试的推广输出选项。`AGENTS.md` 已记录正式边界。

原始证据根目录：`.runtime/character_rim_promotion_20261113/`。

- [多灯与正式入口结果](../../.runtime/character_rim_promotion_20261113/native/result.json)、[动作及定位结果](../../.runtime/character_rim_promotion_20261113/animation/result.json)
- [逐块性能](../../.runtime/character_rim_promotion_20261113/perf/result.json)、[合并统计](../../.runtime/character_rim_promotion_20261113/perf/aggregate.json)，同目录 CSV 保留逐帧墙钟、延迟 CPU／GPU 视口计数和 draw calls。
- `probe_process.json`、`native_process.json`、`actions_process.json`、`perf_process.json`、`legacy_cleanup_process.json` 均记录自建进程 PID 和最终 exit 0。
- `before_manifest.json`／`source_parity.json` 保留本轮前后文件核对；共享 dirty 工作区未重置、未清理、未提交，未调用 Antigravity 或外部执行者。
