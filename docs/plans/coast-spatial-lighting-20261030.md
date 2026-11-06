# 红海空间光照调整（2026-10-30）

本次由 Codex 在正式工作树独立完成，范围为当前红海。用户要求保留复古像素材质，通过冷色环境光、局部暖光／警示光、柔和间接光、克制 Bloom 和体积光加强真实 3D 空间感。

保留海水回退后的着色器、波浪、模拟、天空及沙滩配色、角色原画。未修改正式办公楼灯光；这些美术原则可用于后续场景，但不代表已全局改造。

## 实现

- 地形、礁石继续使用原有像素材质和 32px/m 网格。减少沙滩均匀自发光，由真实月光、阴影和冷色补光塑造坡面；沿用现有层次增强分支，减轻三档明暗的硬切。
- 维持低位月亮的世界方向，加强月光投影，保留云遮月控制；冷色天光和低强度方向补光连接暗部。
- 岸边两处小型实体工作灯，含真正 SpotLight3D、局部投影和柔和 OmniLight3D 补光。灯具位于中央行走路径外，可整体移动。
- 吊塔驾驶舱暖光与红色警示光提供远处重点，警示光仅轻微连续呼吸，不做闪烁开关。
- 使用原生 Compatibility Glow，强度 0.08、阈值 0.98、全屏 Bloom 底量为 0。实际关闭对照验证有贡献，而不是仅设置参数。
- 两个小范围空气散射体使用 12 步射线积分，并读取当前 Camera 深度限制到不透明表面之前。它是局部体积散射模拟，不是贴在屏幕上的亮圆或整屏雾层。
- 新灯具、光源和散射边界共用场景时间、暂停及云遮月状态。全部保存在 `night_coast.tscn`，运行时不重建地形或替换布局。

## 实现边界

当前为 Compatibility 渲染器。[Godot 渲染器功能表](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)确认其支持 Glow、深度纹理和普通阴影，不支持原生体积雾及 SDFGI。本次间接光使用艺术布置的真实补光近似，不声称动态 GI；局部散射不读取完整光源阴影图，也不是多次散射解算。

Compatibility Glow 的可用参数与其他渲染器不同，见[官方 Environment 文档](https://docs.godotengine.org/en/stable/classes/class_environment.html)。深度重建依据[官方后处理说明](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)，针对 OpenGL 的 NDC 范围处理。

海水保持原有 unshaded 着色路径，本次没有新增工作灯在水面的实时反射。主要空间光照增强作用于地形、礁石与设施。

## 验证

实际 RTX 5070 Ti / Godot 4.7.1 Compatibility、640×360 章节 Camera，后台最小化录制，未关闭用户软件。证据目录：`.runtime/coast_spatial_lighting_20261030/`。

| 检查 | 结果 |
| --- | --- |
| `tests/coast_spatial_lighting_test.gd` | 13 项通过：暖光落地、真实几何投影、Glow、局部空气散射、遮月、三点章节信号、暂停及保存节点归属 |
| `tests/night_coast_editable_scene_test.gd` | 26 项通过：440 个已保存节点、3D 编辑保存重开、移动设施后水流障碍、相互独立实例等 |
| 海水回退核对 | `night_coast_water.gdshader` 与本轮修改前一致，无差异 |
| 正常速度走动 | 实际移动输入，162 帧采样，墙钟跨度 11954ms；GIF 12020ms，包含最后一帧约 67ms |

关闭单项后的真实像素差异证明它们参与了渲染：月光阴影约 104960 像素，局部暖光约 49916 像素，局部空气散射约 5159 像素。Glow 全画面最大通道平均变化 0.00629，局部散射平均变化 0.000321；这些数值只衡量画面差异，不是性能结果。

录屏保存会产生额外开销，本轮没有稳定 60 FPS 或纯 GPU 耗时结论。没有复跑全部章节战斗。

交付：`lighting_comparison.png` 为同时间、同 Camera 的前后对照；`walking_normal.gif` 为实际章节 Camera 正常速度走动；`after/covered.png` 展示遮月读信号状态。
