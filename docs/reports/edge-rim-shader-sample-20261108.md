# 像素结构描边与受光边缘光小样

后续：用户要求将各项效果全部拆开比较，当前统一入口与动态剖切适配见 [各项着色效果独立比较](shader-effects-comparison-20261108.md)。本报告与旧运行源保留为历史独立样板。

2026-11-08。用户授权执行推荐的两项着色效果。本轮在已认可的第二版材质上制作独立候选；先前的三段卡通着色样板保持原状，没有叠加进来，也没有修改正式入口。

试玩：[preview_edge_rim.cmd](../../tools/preview_edge_rim.cmd)。默认同时开启两项效果，T切换组合与已认可材质，F5单独切换结构描边，F6单独切换受光边缘光；1／2／3定位铁柜、塑料机壳、木桌，WASD正常移动。各模式始终保留已认可材质。

## 实现与边界

候选目录 `.runtime/edge_rim_20261108/candidate/`。实际场景为GameTestLab的生产布局／正式美术模式，保留原Camera、灯光、阴影、反射与玩法。2049个活材质、2005个MeshInstance3D进入候选，复用21个Shader变体。角色精灵、既有角色描边、血液、玻璃、特效和UI的专用材质不进入替换范围。

结构线直接沿模型的锐边／开放边生成，在640×360世界像素上约一像素宽。先按世界坐标匹配三角形邻边，排除共面对角线及匹配的共面拼接边，再用重心坐标与屏幕导数求线宽。线画在原表面内侧，不扩大倒置外壳，不改变碰撞，也不依赖透明墙体无法提供的屏幕法线缓冲。原Shader里的剖切与遮挡discard仍先执行。

边缘光使用同一结构边界掩码、视角掠射因子，以及逐灯LIGHT_COLOR／ATTENUATION和法线受光量；保留实际阴影。只改变逐灯响应，不写EMISSION、不增加Light3D。窄亮边绕过结构暗线的相互抵消，仍随场景灯光改变。原明暗交界像素网点沿原函数保留，没有增加全屏网点或RGB调色板。

为读取重心坐标，候选运行节点临时换用带CUSTOM0数据的三角形展开副本，面顺序、顶点位置、颜色和UV不变，UV2保留；不是新增外壳或移动原模型。原Mesh资源不编辑，关闭效果即恢复原资源身份。法线经过Godot打包往返，当前最大向量误差约0.0001073；顶点及UV误差为0。使用压缩后的三分量辅助varying，避免超过现有家具Shader的32项上限。

参考实现机制：[Godot ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)、[空间Shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[屏幕读取与透明几何限制](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)。新增代码在本工程本地编写，没有直接引入第三方Shader包。

## 实际验证

- `camera04/`：原生Forward+／Vulkan、私有Master=0／WASAPI、640×360世界画面。25项检查通过，PID38000退出0并释放共享锁。
- 包括组合／分别开关、关闭后逐像素恢复、角色Shader与玩法状态不变、碰撞资源／变换／启用状态不变、原明暗交界网点保留、三种实际家具定位、关闭全部直接光后的边缘光逐像素不增亮、组合效果暗处无新增发光、UI像素不变、还原／全新绑定一致、静止Camera无自发闪烁、实际走动与镜头跟随、真实T／F5／F6键事件。
- `geometry02/`：6项无窗口几何检查通过。两个相邻三角化四边形只保留六段外周，内部两条对角线与一条拼接边排除；UV2及原Mesh数组保留，Mesh／Shader身份可恢复，PrimitiveMesh和ArrayMesh均可使用。这些几何检查不替代实景视觉验收。
- `entry01/`：交付脚本原生启动，PID18472，输出 `EDGE_RIM_SAMPLE_READY materials=2049`，21个Shader变体完成加载，退出0并释放锁，日志无脚本／Shader错误。
- 自动入口启动前准备私有静音设置，并在设置重载时核对。正常试玩使用独立玩家目录，首次复制玩家设置；自动静音仅用于诊断，不写原玩家设置或Windows音量。
- `source_manifest.json`与`protected_source_check.json`：26份已认可材质、原卡通候选及正式来源文件的SHA256不变。未提交、未整合正式入口。

Camera首轮较细的版本保存在 `camera03/`。根据实际画面加强了约一像素边界与亮边，再运行最终 `camera04/`。前期解析／原生失败目录保留：字符串摘要API、PrimitiveMesh API以及过多varying均已修正。`geometry01/`还发现单行Shader的include末尾缺换行；最终补齐换行，`geometry02/`和`entry01/`复核通过。该末尾换行是camera04后唯一运行源修正，不改变其生产Shader的受光计算。原生检查没有复用失败结果。

## 画面证据

`delivery/edge_rim_comparison.gif`在同Camera／同灯光下切换“已认可材质”和“材质＋描边＋边缘光”；上方整房，下方同机位家具局部，仅加标签、裁切与Nearest整数倍放大，两帧共用GIF色表且没有误差扩散。无压缩原帧为 `accepted.png`与`combined.png`；`four_modes.png`分别列出四种状态。

`walk_normal.gif`来自实际Camera连续行走抽帧，24帧，按实际记录时间安排播放时长，不是慢放。没有用头部／编辑器视图代替游戏画面；稳定性检查通过不等于用户已认可最终风格。

## 有限开销记录

冻结同一Camera，保留相同灯光／阴影／反射、已认可材质和WASAPI静音。每档预热90帧，关闭／开启／再关闭各采样3秒，计时区间不截图或写盘。下面是相邻主循环的墙钟间隔，不是GPU执行时间。

| 状态 | 帧数 | P50 | P95 | P99 | 最大值 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 关闭A | 1170 | 2.525ms | 2.973ms | 3.210ms | 3.436ms |
| 开启B | 1137 | 2.605ms | 3.068ms | 3.325ms | 3.699ms |
| 关闭A复测 | 1172 | 2.526ms | 2.970ms | 3.197ms | 3.908ms |

本次P95差约0.095～0.098ms，只代表该固定视图。原始逐帧值在 `camera04/result.json`，没有把首用几何准备／Shader编译纳入稳态窗口，也没有覆盖敌群战斗、破坏后新建模型或全部随机楼层。当前仍是独立小样；不宣称全游戏稳定60FPS，也不将静止无闪烁扩大为所有动态边缘都已验收。
