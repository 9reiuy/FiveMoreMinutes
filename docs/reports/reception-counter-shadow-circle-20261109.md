# 前台台面圆形暗斑修正

2026-11-09。用户截图中的圆圈已在正式 Main Camera 复现并修正。此次为大厅既有光影缺陷修复；没有更换材质或改动布局。

## 原因与最终修改

圆圈来自前台顶灯的异常自阴影。关闭该灯的投影，台面恢复正常；关闭法线、SSAO 或改用原生材质不能解决。独立关闭各台面自身的投影也能清除对应暗斑，说明台面被错误地当成了自身的遮挡面。

最终只在 `scripts/dream/reception_reference_layout.gd` 为四盏大堂顶灯启用 **`shadow_reverse_cull_face=true`**，以闭合家具的背面生成投影。原来的 `shadow_bias=0.5`、`shadow_normal_bias=1.2` 保留，55° 灯锥、亮度、灯位、范围、遮挡层和投影开关保持。没有通过关闭阴影、增加补光或改浅石材贴图掩盖问题。

此次也检查了调小偏移的方案。它虽能配合反向剔除消掉圆斑，但会在立柱引入新的条纹，因此没有采用。正式版本仅修正投影面的方向。

## 实际 Camera 验证

原始证据在 `.runtime/reception_counter_circle_20261109/`，总结果为 `summary.json`。所有图形批次串行持有共享锁，启动前准备私有 APPDATA/LOCALAPPDATA 的 Master=0 配置，显式 Dummy；Forward+ / Vulkan，640×360 游戏、1280×720 窗口、Nearest。玩家配置与系统音量未改。

| 最终批次 | PID | 检查 | 结果 |
| --- | ---: | ---: | --- |
| `final02` | 64600 | 12 | 同 Camera 旧配置复现、修正／旧配置／修正恢复、实际地面投影与四盏顶灯状态 |
| `camera02` | 53916 | 32 | 角色显示尺度、完整轮廓、NPC 原图与眨眼、交谈气泡、两侧沙发及多位置 Camera |

**44 项通过**，两个最终进程退出 0。最终正常材质的柜台、前厅、电梯厅及立柱画面已检查；本轮包装进程正常结束并归还锁。结束复核时，锁已有其他使用者占用，本轮不再启动图形任务。没有性能认证声明。

专项像素证据：

- 相同 Camera 的 24 个台面采样点中，旧设置有 12 个异常暗点，修正后为 0；相对关闭顶灯投影的对照，平均亮度损失从 0.29909 降到 0.000117。
- 修正→旧配置→修正后的台面区域像素差为 0。
- 在空地临时加入闭合测试物体，只切换该物体的投影，物体轮廓外地面有 425 个像素变化，证明正常家具投影仍在。测试物体未进入正式场景。

### 最终画面

- [修正后的台面](../../.runtime/reception_counter_circle_20261109/final02/fixed_ui.png)
- [同 Camera 复现旧圆斑](../../.runtime/reception_counter_circle_20261109/final02/legacy_reproduced_ui.png)
- [修正后的电梯厅与立柱](../../.runtime/reception_counter_circle_20261109/final02/upper_hall_ui.png)
- [实际地面投影测试](../../.runtime/reception_counter_circle_20261109/final02/caster_on.png)

## 早期记录与范围

`diagnosis01` / PID32420 为逐灯、法线及后处理隔离；`bias01` / PID62584 为偏移和台面投影隔离；`face01` / PID63684 为投影面向、原生材质及原生影子代理对照。均退出 0，原始图和设置保留。

`final01` / PID68068 的 12 项及 `camera01` / PID57980 的 32 项也技术通过，但使用了较小偏移；实际 Camera 的立柱条纹不符合要求，不能把这一版当作视觉验收。已恢复原偏移，并以上面的 `final02` / `camera02` 为最终配置。既有 Control 锚点警告和 ImageTexture/RID 退出清理诊断保留在原始日志，不声称日志为空。

正式源只改 `reception_reference_layout.gd`；新增 `tests/reception_counter_shadow_test.gd`、本报告并更新项目上下文／GPU 协调记录。12 个保护源散列一致，包括家具材质工厂及 Shader、角色桥／原图拼接、玩家、相机场景、地毯 Shader、当前办公层着色推广和项目配置。原石木材质、柜台 0.78 高度、低前景墙沿、角色地毯接触、正常交谈、640×360 及 Forward+ 均保留。未重置、清理或提交共享工作树。
