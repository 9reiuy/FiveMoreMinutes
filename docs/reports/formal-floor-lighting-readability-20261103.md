# 正式关卡亮度与地面光圈整改

2026-11-03。按用户“开始执行”及追加的地面环状光晕整改要求完成，修改已在当前正式工程工作树中生效，未提交或合并。

## 最终行为

- 正式楼层地板原色响应从 `0.35` 恢复到 `0.50`，重新接受已有的微弱环境光；逐灯硬限幅改为高亮区柔和压缩，保留中间调和受光渐变。
- 正式楼层家具主体接受已有环境光，背光面恢复结构。现有房间灯和投影继续塑造明暗，不新增灯具、阴影灯或渲染通道。
- 正式世界调色使用连续明度坐标在原色板之间插值，避免最近颜色切换和有序抖动形成同心环纹。最近邻纹理、角色像素轮廓与真实阴影保持。第二套方案的四个参考色采用连续的色彩权重，避免中性光照突然跳入强调色。
- 血液、敌人红色预警、拾取闪光、枪口及特效标记仍走原有专用颜色分支。大厅、教程、独立美术样板使用原有默认分支。

[实机前后对照](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/review.html)。所有房间图来自正式 Main 入口、第 2 层、种子 42001 的实际游戏 Camera；相机位置受控，未使用编辑器或外部渲染代替。

## 验证

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 正式维护区、办公区、会议室、档案室 × 调色设置 1/2 | 8 组实机量测；地面平均显示亮度提高约 60%–79%；最终最高 RGB 0.631，超过 0.68 的取样为零 | [Camera 量测](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/after_smooth/analysis.json) |
| 渐变、专用颜色、参考色、静态稳定性 | 44/44；受控灰阶渐变相邻像素最大亮度跳变从 0.061–0.097 降至 0.0042 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/ramp_test/result.json) |
| 地面上限、维护台真实 E 交互及选择保存、待机屏幕 | 25/25 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/regression/floor_final_result.json) |
| 房间补光切换、快速 A→B→A、暂停恢复 | 8/8 | [日志](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/regression/bounce.log) |

地面统计取前后两次黑／白地面标记的共同区域并内缩 2 像素，排除家具、角色、UI 和随机散落物。数字是显示 RGB 加权统计，不是物理照度，也不证明所有随机地图或战斗瞬态都有相同上限。两个调色方案在这些中性地面取样上结果相同，额外参考色另由专门测试覆盖。

环纹测试使用实际后处理 shader 的受控灰阶渐变；正式游戏画面另行复核。没有对截图进行去环纹或提亮修图。

## 性能边界

正式接入前，在独立测试场的正式美术模式做了六轮 8 秒原型对照，保留 8 个敌人、AI、家具、霰弹枪、灭火器及烟雾，记录首次触发与重建退出。暖机后原效果 A3 / 材质候选 B3 的 P50 为 13.284 / 13.573 ms，P95 为 23.663 / 24.966 ms，P99 为 38.236 / 39.774 ms，峰值为 52.456 / 53.354 ms。两个进程的首次负载都出现约 1.15 秒的既有停顿。

这些原型记录位于 [lab](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/lab/result.json) 和 [lab_repeat](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/lab_repeat/result.json)，每轮目录保留 `frames.csv` 和 `report.json`。各轮采用同种子、配置和输入策略，实时 AI/物理与实际发射次数并非逐帧相同；为隔离运行时材质原型，所有对照都冻结了相同的周期性材质刷新。

前期短测期间收到另一会话正在并行编译诊断引擎的通知，因此上述原型成绩仅作参考。后续复核还发现测试场未自动安装正式家具受光组件，已补齐并重新完成四轮独立副本对照：正常材质刷新开启，静止场景合并 P50 为旧版 6.884 / 新版 6.885 ms；两版实际交战均有超过 16.667 ms 的帧。另以同一份冻结交战画面隔离渲染开销，完整数据及归因边界见 [最终实现的性能复核](E:/GameProjects/FiveMinuteMore/docs/reports/formal-floor-lighting-performance-20261103.md)。本报告不宣称整局稳定 60 FPS 或性能提升。未关闭用户程序。

## 文件与现有工作树

生产修改仅涉及 [地面材质](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/sample_floor_texture_review.gd)、[家具受光](E:/GameProjects/FiveMinuteMore/scripts/dream/office_dither_lighting.gd)、[正式显示配置](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/selective_pixel_preview.gd)、[调色 shader](E:/GameProjects/FiveMinuteMore/shaders/palette_quantize.gdshader)。新增 [渐变与颜色回归](E:/GameProjects/FiveMinuteMore/tests/formal_light_ramp_test.gd) 及本报告。

原工作树已有大量其他未提交改动，全部保留。本轮按开工时文件副本生成 [独立差异](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/changes.patch) 和 [源文件哈希](E:/GameProjects/FiveMinuteMore/.runtime/lighting_revision_20261103/source_manifest.json)，不把原有改动算入本次整改。

退出日志仍有原有的纹理 RID／ImageTexture 释放提示、UI 锚点警告；无窗口补光测试仍有 ObjectDB／资源释放提示。各测试退出码及断言通过，不把这些已存在提示描述为已修复。
