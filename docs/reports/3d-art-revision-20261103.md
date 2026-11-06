**五大 3D 场景美术整改与实机验收 — 2026-11-03**

> 后续更新：大厅已重做为右入左出的紧凑场景，卧室按用户红蓝标注重新摆放。当前布局见 [最新布局记录](compact-lobby-bedroom-markup-20261103.md)。


> 更新：大厅、卧室布局与海崖颜色已按后续反馈纠正，当前结果见 [三处场景纠正记录](3d-art-corrections-20261103.md)。本页保留上一轮记录。


本轮依据 2026-11-02 的专项任务书，完成接待厅、教程、3D 卧室、办公/休息层与红海海崖修改。已核对任务书的 19 张对比图；参考图仅用于分析，没有导入《SIGNALIS》资源。未修改日常 2D 立绘卧室。

用户随后要求删除 CLI 调度条款。[AGENTS.md](E:/GameProjects/FiveMinuteMore/AGENTS.md) 已改为当前 Codex 独立分析、实现、测试、修复与验收；旧工作流中的外部调度规则明确失效。十条美术准则与旧 2D Dream 退役边界保留，文本核对通过。

[打开六组实机前后对比与动态片段](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/review.html) · [原始对照图](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/comparison.png) · [教程真实输入动态片段](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/tutorial_motion.gif)

| 模块 | 已落地内容 | 实机验证 |
| --- | --- | --- |
| 3D-ART-01 接待与塔罗 | 局部深灰石材地面；清除造成黑块观感的悬空灯壳；中央盆栽撤走，仅留 3 处边缘盆栽；暗红主通路与冷蓝电梯导引；琥珀聚光、暗红背景壁龛、绒垫、3 张原创程序化牌面及铜灯 | 实际行走穿过大厅到前台与电梯；E 对话、第二次 E 抽牌、鼠标选牌保存；电梯失败回退和重试到正式楼层均通过 |
| 3D-ART-02 教程 | 未开灯靶场的目标、拾取物及 3D 显示桥按区域同步隐藏；冷钢顶盖 `#6E7D92`、45° 门柱护套与门槛；隐藏俯视镜头中的白色灯管网格，保留实际灯光；弱暗红待机角灯 | 完整注册、冲刺、死亡重试、拾枪、开火、手动换弹、击杀及出口流程通过；解锁前目标及桥隐藏、解锁与重试后恢复；门头红绿状态在两种调色下可见 |
| 3D-ART-03 3D 卧室 | 四面明度调整为 `1.20 / 1.00 / 0.78 / 0.55`；浅米白枕被、深枪铁床架、暗胡桃木桌面与书架；保留局部材质色；北/西工业肋柱、百叶及东南洗漱台/镜柜；原布局不变 | 入口开关与碰撞、电脑、床头药品、床边及 F 醒来交互全部通过；新洗漱台已纳入既有家具碰撞构建；独立导出资产检查通过 |
| 3D-ART-04 办公/休息层 | 地面专属受光预算及微反射限幅；窗外主色改为冷蓝灰，约 3/101 的亮窗分配暖色；稳定选取约 1/4 工位，仅屏幕显示区域微弱自发光；维护台沿用当前已有的合法靠墙工位 | 维护台真实 E 打开、改装保存及恢复输入通过；抽样 20 个工位中 5 个待机屏幕，UV 遮罩和最终材质保持有效；正式楼层灯光开关仍改变 29,670 个采样像素 |
| 3D-ART-05 红海海崖 | 前景岩体改为 `#120910–#2B131D` 附近的深紫褐阶梯色；局部岩层及稀疏像素高光；强化月面与遮月状态区别；几何、行走高度与信号时序不变 | 正式章节进入海崖，明月/遮月 Camera 图、屋顶信号观察、线索保存及继续游戏恢复通过 |

顶盖使用局部受光材质：剖切截面位于保留的完整墙体阴影内部，因此只让该人工截面忽略阴影接收；真实墙体的遮光几何继续保留。办公地面只调整地面材质，没有压暗角色描边、UI、武器火光或窗户。

当前维护台在本轮开始前已经通过 `maintenance_site` 选择合法的北/西墙工位，并带有地垫和工作灯；本轮验证并保留该实现。家具生成器原来已有 `1.22 / 1.00 / 0.78 / 0.56` 四面分级，本轮调整数值并修正语义配色，未将其误记为从无到有的新功能。

**验证结果与范围**

所有运行测试使用正式 `scenes/app/main.tscn` 路由、Godot 4.7.1 Compatibility、RTX 5070 Ti 的实际 Camera。测试窗口在后台，不抢焦点；测试存档与设置使用独立目录。

| 验证项 | 结果 | 证据 |
| --- | --- | --- |
| 接待真实行走、对话、塔罗选择 | 16 / 16 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/reception_route/result.json) |
| 教程完整输入流程及目标显隐 | 48 / 48 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/tutorial_route/result.json) |
| 卧室真实交互动线 | 25 / 25 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/bedroom_route/result.json) |
| 地面 Camera 量测、维护台、待机屏幕 | 25 / 25 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/floor_review/result.json) |
| 真实灯光与海崖章节信号 | 16 / 16 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/lighting_coast/result.json) |
| 电梯失败回退、重试与正常入层 | 24 / 24 | [记录](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/reception_journey/report.json) |
| 五场景最终 Camera 采集、海崖双状态 | 1 / 1 | [结果](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/final_verified/result.json) |
| OBJ / UV / 像素密度 / 边缘扩展 / 材质独立检查 | 6072 / 6072 | [检查记录](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/asset_checks.json) |

地面量测是维护层的三个视点 × 调色设置 1/2，共六幅最终合成画面。用地面材质黑/白差分筛除家具、墙、角色与 UI，再将取样边界内缩 2 像素；以 8 位显示 RGB 归一化值统计，单幅最高值为 **0.541176**，超过 `0.68` 的取样为 **0**。这不等同于所有地图、所有视角或瞬态战斗灯光的数学上限证明，也不是 60 FPS 性能验收。

初次仅限制 `DIFFUSE_LIGHT` 仍出现白色过曝；Compatibility 的多灯叠加使该量并非最终像素总和。已据实际 Camera 结果改为地面专属的逐灯预算、材质响应与反射限制，复测通过。对比截图使用固定游玩位置，但镜头跟随/对话状态存在细微构图差别，不作逐像素配准比较。动态 GIF 保留片段内的采样时间，省略段间未记录等待。

日志仍存在本轮之前已有的 UI 锚点提示、退出时纹理 RID / ImageTexture 资源告警；整项目导入还会扫描到不受支持的 WAV 测试样本。目标资产已实际导入并显示，最终运行没有新增的脚本解析或着色器编译错误。未把这些日志描述为“全工程零错误”。

**修改与整合状态**

工作分支 `wip/linux-migrate-20261018`，HEAD `b5d286d8491701ac433826aa26b1d75d32f88c75`。本轮保留原有未提交内容，以及其他任务同时修改的门、玻璃、墙面附件等文件；没有重置、清理、提交、合并或部署。

[本轮文件与 SHA-256 清单、并行变化记录](E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/final_audit.json)。本轮开始前的相关文件快照保存在 `E:/GameProjects/FiveMinuteMore/.runtime/art_revision_20261102/baseline/`；原始 CLI 受阻尝试保留为历史记录，已由用户授权当前 Codex 直接执行。

主要源文件：[接待房间](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_reception_room.gd)、[塔罗布景](E:/GameProjects/FiveMinuteMore/scripts/dream/tarot_reception_dressing.gd)、[教程房间](E:/GameProjects/FiveMinuteMore/scripts/dream/dream_3d_tutorial_room.gd)、[教程控制](E:/GameProjects/FiveMinuteMore/scripts/story/chapter_tutorial.gd)、[门框](E:/GameProjects/FiveMinuteMore/scripts/story/training_gate.gd)、[卧室场景](E:/GameProjects/FiveMinuteMore/scenes/story/chapter_bedroom.tscn)、[家具生成器](E:/GameProjects/FiveMinuteMore/tools/build_chapter1_pixel_assets.py)、[地面](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/sample_floor_texture_review.gd)、[待机屏幕](E:/GameProjects/FiveMinuteMore/scripts/dream/preview/furniture_texture_review.gd)、[窗外城市](E:/GameProjects/FiveMinuteMore/shaders/dream3d/preview/sample_neon_city.gdshader)、[海崖材质](E:/GameProjects/FiveMinuteMore/shaders/preview/night_coast_sand.gdshader)。
