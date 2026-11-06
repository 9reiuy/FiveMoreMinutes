# TASK-022-A：样板确认后的工程建议

2026-11-03，北京时间。阶段：调查与建议；本轮交付目标图和规则，以下改造尚未实施。

[样板对照](review.html) · [视觉规则草案](visual-rules.md) · [用户任务书](task-022-a-brief.txt)

## 当前链路与建议

| 已核对的入口 | 当前行为及影响 | 建议的试点改造 |
| --- | --- | --- |
| [家具面贴图](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/furniture_face_textures.gd)、[家具装配](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/furniture_texture_review.gd) | 按实际面尺寸以 32 px／世界单位重排 UV，并从源图取主色；已有接缝、纸张、标签和稳定变体。源图的大面积浅色会进入重绘贴图，最终仍可能呈现亮白家具 | 优先为工作站、文件柜、椅子定义成组的顶／前／侧面配色，重画面板分区和局部破损；复用现有确定性变体与缓存。先做表面设计，再评估受光响应 |
| [墙面与桌面装配](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/sample_wall_and_desktop_review.gd) | 有独立墙贴图缓存、门窗处理与生产模式；剖面墙和门窗显隐已有职责 | 在原有顶盖／正面／侧面上设计清晰块面和少量结构线，继续使用现有剖面、遮挡和门窗逻辑 |
| [地面装配](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/sample_floor_texture_review.gd) | 正式楼层有自己的受光响应、纹理缓存及真实房间边界；已有地面提亮和高亮柔和压缩 | 保留拼接方向和受光层次，为局部磨损、静区及半调配置稳定纹理遮罩；先在一个房间验证尺度与走道可读性 |
| [材质受光组件](E:/GameProjects/FiveMinuteMore/scripts/dream/office_dither_lighting.gd)、[表面受光 include](E:/GameProjects/FiveMinuteMore/shaders/dream3d/office_dither_lighting.gdshaderinc) | 组件会处理晚创建材质；`office_dither_response()` 当前主动保持连续，避免逐灯分档形成相交环纹 | 局部半调优先使用烘焙纹理／遮罩；确需随光变化时，在指定环境材质中使用稳定坐标与局部覆盖率。保持连续照明，避免恢复逐灯硬分档 |
| [世界显示](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd)、[最终调色](E:/GameProjects/FiveMinuteMore/shaders/palette_quantize.gdshader) | 世界在低分辨率视口中渲染，HUD 保留在根画布。调色覆盖合成后的世界；血液、预警、拾取和枪口已有专用颜色分支 | 保留调色与专用颜色分支；把印刷处理限定在环境表面。试点阶段逐像素核对 UI／文字与角色区域，避免环境变化扩大到人物 |
| [人物显示桥](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_actor_depth_bridge.gd) | 2D 角色源经捕获视口进入深度正确的 3D 载体，角色仍处于世界最终调色范围内；这与“角色完全绕过后处理”不同 | 继续复用原角色、武器和碰撞权威。先通过环境材质限定范围来保护人物，新增人物合成通道需由试点证据说明必要性 |
| [正式精简布光](E:/GameProjects/FiveMinuteMore/scripts/dream/office_sparse_lighting.gd)、[正式世界](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_random_dungeon.gd) | 当前 `sparse_lighting_enabled` 默认开启，属于已接入的布光配置；现有房间灯生成也仍保留 | 本任务试点使用当前正式默认值，记录开关与相机配置。风格对照只切换美术候选，以便识别表面设计带来的变化 |

角色源捕获视口与 HUD 的独立性应分别核对。当前人物仍会进入世界调色，直接在最终调色后撒点可能影响角色；局部环境材质是本次建议的首选入口。

## 建议执行顺序

1. **确认目标图。** 先确认家具压白程度、黑块分配、局部半调强度；补充图1／图2后再核对参考贴近度。
2. **小范围资产规范。** 从工作站、椅子、文件柜三类建立一套顶／前／侧面样本及有限磨损变体。面板与标签贴在既有网格上，保留原模型、碰撞和交互边界。
3. **一个房间试点。** 在独立测试场的正式美术模式先处理普通办公室，并覆盖相邻开放区域和一段走廊。保留可切换原版，维持同一 Camera、分辨率、布光、种子与内容量。
4. **实机验收。** 观察正常移动、冲刺、射击、破坏、烟雾、血液、提示、暂停与换房。先确认图形感和可读性，再讨论推广；前台、大堂等在其后按功能区域适配。

半调的首版可全部来自贴图和遮罩，以减少运行时改造。磨损按已有资产身份／种子稳定选取；缓存键加入风格版本，避免切换试点时混用旧贴图。动态投影继续交给现有灯光流程。

## 试点的通过依据

- 同机位能看清家具的三向块面和面板结构；大块亮白减少，原本可走的地面仍易判断。
- 原有角色与敌人轮廓、武器、血色、准星、文字和交互提示可快速辨识；半调只出现在指定环境区域。
- 移动与转向时点阵稳定，避免闪烁、摩尔纹或重新出现环状光照分档。
- 快速进入／离开房间、重建和退出后，材质／纹理恢复正确，不累积缓存或额外处理组件。
- 性能用同负载的实际 Camera 分别记录静止、首次及重复交战、烟雾／破坏组合、换房生命周期，保留原始帧及 P50／P95／P99／最大值。目标图不能证明运行性能；此前精简布光接入前的报告仅作历史背景。

本轮未更改正式代码或资产，未推广至全场景，未提交或合并。当前共享工作树已有大量其他任务修改，已保留。
