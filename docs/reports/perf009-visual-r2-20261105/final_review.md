# 5MinMore 本轮统一验收：室内灯光、阴影与断电

2026-11-06，Asia/Hong_Kong。最终候选：R3 C7。

本轮修复已交付到原来的独立小样。顾问复核了实际游戏 Camera、断复电、原始帧时和原入口启动记录；没有接入正式游戏。

**唯一试玩入口：[Run_PERF009_Candidate.cmd](E:/GameProjects/FiveMinuteMore/Run_PERF009_Candidate.cmd)**

## 完成情况

| 问题 | 本轮结果 |
| --- | --- |
| 阴影像黑沙、桌椅和柜子下成黑团 | 去除旧光照边缘噪声，调整原生软阴影；保留家具主投影，增加受墙、门、屋顶遮挡的弱补光。三处实机画面中阴影内可见地板纹理，明显颗粒和纯黑团已改善。 |
| 房间外的墙被照亮 | 分开开灯验证：房内主灯和补光都受实墙遮挡，门窗开口正常透光；截图附近的外侧亮墙在当前候选中主要由相邻区域光源照亮，不能把全部外侧受光都判成漏光。 |
| 断电后家具下有灰斑 | 原接触影叠加固定灰色，黑地面会被反向抬亮；已改为只压暗地面。断电不再留下反亮灰块。 |
| 人物、敌人和杂物发黑或偏白 | 人物捕获颜色按实测正确转换；普通敌人与无人机使用实际实体显隐差分验证。暗处保留原像素轮廓，未全体改成自发光。地上枪械和破坏碎片在实机中可见。 |
| 断电后房屋仍亮 | 按 E 与射击破坏电箱都已通过。主灯与补光从 20+20 盏变为 0，复电恢复；保留合理夜间窗光和独立战斗效果。 |
| 类似摩尔纹、移动波纹 | 已复核 40 张移动及 6 张停止阶段主画面与原始倒影。当前代表场景未再见此前明显沙粒波纹；停止时相机仍有微量收敛，不声称全图逐像素静止或所有房间所有角度都已覆盖。 |
| 原入口、静音和退出恢复 | 原 CMD 文件不变，选中新候选；私有音量为 0，正常音频后端保留。走动、4 发实际开火、Space 冲刺、F4、F8 通过，正常退出且无引擎错误。 |

本轮没有尚在制作的分支。渲染管线已交付，顾问完成上述范围的独立验收。

## 实际画面

以下为未修改的原始 640×360 Camera PNG。通电、断电与复电的相机变换已核对一致；人物动作和战斗状态可能随真实运行变化。旧候选图片只用于同一区域的视觉参考，不冒充完全相同机位的逐像素比较。

办公区通电：桌椅与柜子仍有投影，阴影内保留地纹。

![办公区通电](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11/office_on_main.png)

办公区同机位断电：家具下不再反亮，人物保留定位轮廓。

![办公区断电](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11/office_off_main.png)

会议室通电：桌底暗部与墙面受光。

![会议室通电](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11/meeting_wall_on_main.png)

接待区通电：柜后大黑块已减轻。

![接待区通电](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11/reception_corner_on_main.png)

外侧墙面归因：[只开会议室主灯](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11/meeting_only_primary_walls_main.png)、[只开相邻区域灯](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11/meeting_adjacent_sources_main.png)。

完整原图与动态帧：[最终视觉记录目录](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/PlaySessions/R3_C7_final11)。

## 性能结果与代价

按用户最新的“大部分情况下不超过 80ms”验收。截图与帧时分开测试，未删除地图、家具、敌人或实际 AI/物理。测试保留 15 个房间、104 件家具、13 个实际敌人根节点；走完 83/83 个路点、3 个区域、840 个战斗物理步。倒影仍每次绘制更新。

| 指标 | 返修前 B3 历史记录 | 本次 C7 |
| --- | ---: | ---: |
| 可见帧数 | 1,989 | 1,360 |
| 平均帧率 | 56.79 FPS | **39.18 FPS** |
| P50 帧时 | 17.031ms | 23.685ms |
| P95 帧时 | 22.628ms | **40.042ms** |
| P99 帧时 | 28.660ms | 50.413ms |
| 最慢帧 | 43.775ms | **142.721ms** |
| 严格超过 80ms | 0 | **2** |

本次 **1,358/1,360 帧，即 99.85%，不超过 80ms**，符合当前门槛。两次长帧是原生移动中的 142.721ms 和通电战斗中的 91.945ms；不是只发生在加载阶段，也没有从统计中排除。

C7 的真实遮挡补光增加了渲染工作量，当前帧率比 B3 历史记录低。这两次记录使用相同测试路线和真实运行，AI 行为与机器状态并非逐帧相同，因此不把差值当成单一因素的严格因果结论。**此版本不是稳定 60 FPS。** 本轮只做了一次最终计时，没有为追旧 60 帧标准反复筛选结果。

启动至交还控制约 **20 秒**，这段有加载遮罩，单独报告，不混入可见游戏帧时。性能记录为引擎绘制间隔，不能等同于系统实际屏幕呈现时间。

F4 保留严格 `>80ms` 的长帧计数和导出；导出操作本身也会被记录。建议先用本版确认桌底、柜后、墙角及断电的实际观感，再决定是否另开进一步降低渲染成本的任务。

## 交付核验与范围

- C7 清单 SHA256：`04827E2A97429CED7562FFA5D32247D5377715CB5BDEB1AEE548E61E6AA95159`。
- 原入口通过实际 Windows PowerShell 5 启动；测试没有替用户关闭其他进程。
- 17 项临时补丁退出后恢复；237 个受保护源、75 份旧收据哈希均核对一致。旧失败记录保留。
- 本轮没有全面验证旧的偶发彩条、连续 F10 重启时的碎片预热异常，不能把这两项标为已关闭。短时间代表路线不等于全游戏、所有随机楼层的长期性能认证。

证据：[顾问最终源与入口核验](E:/GameProjects/FiveMinuteMore/docs/reports/perf009-visual-r2-20261105/advisor_r3_final_audit.json)、[顾问独立帧时复算](E:/GameProjects/FiveMinuteMore/docs/reports/perf009-visual-r2-20261105/r3_final_timing_review.json)、[渲染管线交付包](E:/GameProjects/FiveMinuteMore/.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105/visual_r3_20261106/C7_delivery.json)。
