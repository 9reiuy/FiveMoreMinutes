# 环境色硬边像素阴影：独立预览

> 历史第一版记录，已被同日的色阶＋有序点阵预览替代。当前说明见 `dither_shadow_preview_2026-10-02.md`；旧性能数字和按键名称不代表当前版本。

## 范围

入口：`res://scenes/dream/preview/PixelShadowPreview.tscn`。
固定已验收样板、种子 42001，默认静音；正式入口、正式材质、战斗数值不改。
按 1 原效果、2 原生硬阴影、3 像素硬阴影；方括号调网格（默认每世界单位 32 格）。正常移动、瞄准和射击仍使用原玩法。

## 机制

复制环境 OfficePixelSurface 材质，保留纹理、原色、粗糙度和裁切参数。像素模式只把光照采样位置沿接收面切向量化到固定世界网格，再写入 LIGHT_VERTEX，不移动真实几何或命中面。
硬边模式使用原生 HARD 阴影过滤；预览内光源尺寸和模糊归零，绕过原光照轮廓噪声。没有把 ATTENUATION 二值化，因此仍保留距离衰减、多灯叠加与环境色。
人物、武器、玻璃、描边、接触暗部及 UI 不替换材质；人物体积仍使用既有动态投影代理。没有新增世界视口或脚底黑影。
退出恢复原材质、光源和全局过滤设置。新生成的门/家具每 0.25 秒扫描接入；这只是预览，正式接入应改用创建/销毁注册。

依据：[Godot Spatial shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[RenderingServer](https://docs.godotengine.org/en/4.4/classes/class_renderingserver.html)。Compatibility 的 LIGHT_VERTEX 路径已由实际 OpenGL 运行编译确认。

## 本轮检查

- 静音 Headless 隔离、颜色不变、材质副本和模式切换：501 项通过。
- 实际 Compatibility 1920×1080 运行：生成原效果/硬边/像素硬边同状态截图，以及四次移动和手电方向截图；无脚本或 shader 编译错误。
- 已查看正式机位截图：家具投影为硬边，环境色保留，未用白屏或黑色覆盖模拟阴影。
- RTX 5070 Ti，冻结同一状态，每模式预热 2 秒、采样 3 秒：原效果中位数/P95 3.731/4.531 ms；硬边 3.726/4.497 ms；像素硬边 3.681/4.475 ms。三者 1108 绘制调用。仅短时静态对照，不能视为多人交火或中档设备的性能验收。
- 输出：`.runtime/pixel_shadow/mode_0.png` 至 `mode_2.png`、`moving_0.png` 至 `moving_3.png`、`results.json`。

## 未完成与已知限制

未完成：长时间动态片段、多角度连续运动、Palette 各组合、破坏/跨层生命周期及完整交火性能。当前截图不是最终美术验收。
这是世界空间网格，斜面投影后的格子并非始终屏幕轴对齐；不宣称复刻参考图轮廓。场景多个光源叠加仍可能有多层阴影，这是实际照明，不强制固定阴影图案。
只有 OfficePixelSurface 接收材质进入实验；其他材质保持现状，正式扩展前需要逐类验证。
运行环境出现证书权限、shader 磁盘缓存写入错误和退出资源残留警告；最初默认 user 日志路径权限导致引擎崩溃，改用工作区日志后目标运行成功。完整资源残留基线尚未排查，不计为已通过。

可复现：Godot 使用 `--audio-driver Dummy --log-file .runtime/preview.log` 打开独立场景，或执行 `tests/pixel_shadow_preview_test.gd` / `tests/pixel_shadow_preview_capture.gd`。
