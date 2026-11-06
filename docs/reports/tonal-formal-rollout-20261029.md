# 画面层次与像素稳定：正式流程接入

日期：2026-10-29。用户已认可同场景小样并授权接入正式流程。Codex 独立执行，工作树为 `E:\GameProjects\FiveMinuteMore`，未创建子智能体、未提交，保留其他已有修改。

## 正式行为

- 正式楼层默认启用已认可的层次增强：连续灯光响应、亮度优先的有限色映射、受限局部对比和微弱有序抖动。方案一、二的色表保持，方案二的 `#3536D7` 保留。血液、预警、拾取、枪火、火焰等专用色分支保留。
- 正常游戏镜头启用显示侧像素对齐，不修改角色坐标、碰撞、速度或战斗规则。关闭像素化、手机拉近、对话镜头和乘梯期间释放对齐偏移；回到普通镜头后恢复。新楼层重新选择地面参考点，避免延用旧楼层锚点。
- 接待大厅保留局部配色，不套用这次楼层调色。独立夜潮海岸没有接入。
- 修复正式接入发现的两个问题：换层完成后误清除新楼层材质缓存；压缩角色贴图直接裁切导致手机亮光蒙版提取失败。现在保留新楼层有效材质，先解压图像再提取原画蒙版。

主要实现：`selective_pixel_preview.gd`、`office_dither_lighting.gd`、`dream_3d_random_dungeon.gd`、`pixel_camera_stability.gd`、`player_phone_presentation.gd`。沿用已批准小样的两个着色器，不更换贴图、色表或灯光布局。

## 正式入口复验

Godot 4.7.1 Compatibility，RTX 5070 Ti；窗口后台最小化，独立用户数据目录。由 `scenes/app/main.tscn` 实例启动，通过 Main 的接待区／进入楼层接口进入正式世界，再执行真实移动输入、游戏手机开合和实际楼层乘梯换层。首次进入使用 Main 接口触发，不等同于人工从大厅步行按 E 的全流程操作。

| 验证 | 结果 |
| --- | --- |
| `tests/tonal_formal_integration.gd` | 18 项通过，0 失败；正式入口、两套配色、开关像素化、移动投影、手机镜头恢复、实际乘梯换层及输入恢复 |
| `tests/player_phone_animation_test.gd` | 20 项通过，0 失败；保留原画亮光蒙版的精确字节检查 |
| `tests/tonal_semantic_sample_test.gd` | 14 项 GPU 对照通过，0 失败；两套方案下 7 类专用标记色保持 |
| `tests/pixel_camera_stability_sample_test.gd` | 80 个相机位置，最大参考点对齐误差约 0.000034 像素，通过 |

最终换层后的 463 个有效灯光材质均保留增强状态。所有上述测试进程退出码为 0。集成首轮发现的问题集中修复后复验通过。

运行方式：设置独立 `APPDATA` 和 `LOCALAPPDATA`，从工程目录运行 Godot，参数 `--path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 32x32 --position -30000,-30000 --script res://tests/tonal_formal_integration.gd --log-file .runtime/tonal_formal_20261029/integration.log`。测试助手负责后台最小化和持续 GPU 绘制；世界画面仍为 640×360。

## 开销与限制

在实际 Main 换层后的固定场景中，暂停世界更新，分别关闭／开启增强，各预热 12 帧、采样 40 次 `frame_pre_draw` 至 `frame_post_draw` 的跨度：

| 状态 | P50 | P95 |
| --- | --- | --- |
| 关闭增强 | 3.265 ms | 5.008 ms |
| 开启增强 | 3.318 ms | 4.839 ms |

这是短时绘制提交与调度跨度，**不是 GPU 时间、完整帧耗时或 FPS**，不能据此宣称稳定 60 FPS，也不能把两组差值当作精确成本。需要完整战斗性能结论时仍须单独测试。透视场景的不同深度无法同时完美贴格，对齐验证针对选定地面参考点。

最终功能及画面测试无脚本／着色器失败。Main 运行仍有既有 Control 锚点提示；退出阶段进程输出有两个 GL 纹理 RID 残留和 RenderingServer 清理诊断，本轮没有将其计为功能检查失败，也没有宣称全部退出诊断已清除。

## 实际画面与证据

- 正式 Main 摄像机截图：`.runtime/tonal_formal_20261029/formal_scheme1.png`、`formal_scheme2.png`。截图来自世界显示视口，包含最终调色，不包含外层 HUD。
- 正式流程记录：同目录 `integration.log`、`phone_unit.log`、`semantic.log`、`report.json`。
- 用户认可的动态对照：`.runtime/tonal_stability_20261029/walk_comparison_normal.gif` 和 `camera_comparison_normal.gif`，正常速度，左旧右新。这些是已认可的小样录像，不冒充本轮正式入口录像。

![正式楼层：方案一](../../.runtime/tonal_formal_20261029/formal_scheme1.png)

![正式楼层：方案二](../../.runtime/tonal_formal_20261029/formal_scheme2.png)
