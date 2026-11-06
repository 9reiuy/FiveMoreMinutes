# 保留配色的画面层次与像素稳定小样

> 状态更新：小样已获用户认可并接入正式楼层。下文记录的是推广前的小样状态；当前接入及复验见 [正式推广报告](tonal-formal-rollout-20261029.md)。

用户确认保留方案一、二，并同意比较光照/调色层次、减少重复量化、改善移动像素稳定。本次完成独立可交互小样，增强默认不进入正式流程，待实际 Camera 观感确认后推广。

## 实现

- 现有两套色表及 #3536D7 保持。`palette_quantize.gdshader` 新增默认关闭的 `tonal_sample`：距离计算更重视亮度，限制幅度的局部对比处理保留材质边缘，微弱有序扰动改善有限色之间的过渡。血液/预警/火焰等分支仍先于普通映射执行。
- `office_dither_lighting.gdshaderinc` 新增默认关闭的 `office_tonal_sample`，启用时让各灯光保留连续响应，只加入很弱的 12 档量化，以减少每盏灯先量化、最终调色再量化的叠加。未更改光源摆放、强度或材质贴图。
- `pixel_camera_stability.gd` 使用相机投影和 h/v 显示偏移，把固定地面参考点对齐到像素格。每次重算先清除前次偏移，避免累积漂移。正式世界仅在显式 `pixel_stability_sample` 元数据开启时调用，关闭时原流程保持。角色坐标、速度、碰撞及伤害不由该模块改写。
- 透视深度决定不同物体不能全部同时完美贴格；本轮证明的是参考点稳定和显示偏移不写角色权威位置，不宣称所有层次都已消除闪烁。

## 小样入口

Godot 打开 `res://scenes/preview/tonal_stability_preview.tscn`，F6 运行当前场景。F9 切换层次增强，F10 切换像素稳定，F11 切换已有配色一/二。小样初始开启两种增强，正式入口默认关闭。F11 使用现有 SettingsManager，会保存所选配色；其余两个开关仅在小样中生效。

## 验证与限制

Codex 独立执行，无子智能体。工作目录 `E:\GameProjects\FiveMinuteMore`，保留已有修改，未提交。Godot 4.7.1 Compatibility、RTX 5070 Ti；后台最小化窗口，实际 640×360 GPU Camera，隔离用户目录。

- `pixel_camera_stability_sample_test.gd`：80 个相机位置，最大参考点对齐误差约 0.000034 像素，退出 0。
- `tonal_stability_sample.gd`：7 项通过。正式楼层 15 个材质参与对照；两套色表保持；慢镜头参考点最大误差约 0.000068 像素；配对慢走捕获保持相同角色源位置；渲染分辨率保持 640×360。
- `tonal_semantic_sample_test.gd`：14 项通过，覆盖两种配色下的地面血、空中血、红色预警、拾取高光、枪火、火焰和灭火器标记色；开关增强的 GPU 输出一致。
- `tonal_sample_entry_test.gd`：独立小样资源加载/实例化检查通过。

动态图是同一冻结正式楼层中的脚本慢走和镜头路线，40 帧，每帧推进 0.1 秒，按 10FPS 编码为正常速度。它不等于完整手动战斗试玩。本轮没有稳定 60FPS 或完整帧耗时验收；增强增加了最终颜色阶段的邻域采样，正式推广前应补相应开销验证。

GPU 捕获无脚本/着色器错误，冻结场景退出时仍有 2 个 ObjectDB 实例、1 个资源残留诊断，未计为渲染检查失败。单独 `--check-only` 检查场景脚本时因该模式没有注册 SettingsManager 产生编译诊断；改用正常 SceneTree 中的资源加载/实例化确认入口有效。

证据：`.runtime/tonal_stability_20261029/` 的 `gpu.log`、`semantic.log`、`report.json`、两套 `scheme*_comparison.png`、`camera_comparison_normal.gif`、`walk_comparison_normal.gif`。左为原显示，右为小样。只做裁切/拼接/编码，未重绘或合成游戏内容。
