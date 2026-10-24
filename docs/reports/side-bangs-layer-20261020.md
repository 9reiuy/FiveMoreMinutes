# 刘海服装遮挡修正（2026-10-20）

Head 与 Body 原本同层；Head 的刘海子节点先于衣服绘制。将 CharacterVisual 和 HealOverlay 的 SideBangs 都调整到相对 z_index=1，位于角色服装之上。角色整体世界排序、墙体和家具的遮挡保持原流程。

原贴图、连续曲线和摆动参数不变；连续曲线仍为小样开关，未默认推广。

验证：原摆动 24 项、连续曲线与层级 27 项、正式 Main GPU Camera 10 项，全部通过，各自退出码 0。实景全程后台最小化，同一曲线、同一受控走停转向动作，仅比较 z=0 与 z=1。30Hz 动作回放不作为实测游戏帧率。

运行日志仍有既有证书库、布局及退出纹理资源诊断，未宣称全部 Godot 报错清空。

证据位于 `.runtime/bangs_layer_20261020/`：`curve.log`、`original.log`、`gpu.log`、`camera/report.json`；`delivery/head_normal.gif` 为正常速度，`head_slow_2x.gif` 为 2 倍慢放，`camera_normal.gif` 为完整游戏 Camera 对照。
