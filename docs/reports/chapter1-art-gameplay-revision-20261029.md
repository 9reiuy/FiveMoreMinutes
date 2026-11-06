# 第一章美术、卧室与教程修改交付

2026-10-29。依据用户“开始执行”与[已核对任务书](../plans/task_spec_art_and_gameplay_revision.md)实施。由Codex在当前会话独立完成，没有外发任务、使用子智能体、提交、合并或部署。工作树为`E:\GameProjects\FiveMinuteMore`，分支`wip/linux-migrate-20261018`；保留既有未提交工作。

## 实施结果

### 教程：先把教学目标和可见空间对齐

- 引导者移到登记台侧边，并以同一2D碰撞权威保留停步空间；交谈提示移离双方头部、减弱厚描边。靠近引导者已有交谈提示时，不再叠一条同义教学框。
- 中央柜移到侧翼。两个弹药储物柜使用真正的批准柜体，删去错误的第三个盆栽弹药箱与盆栽垃圾桶实例。现为14件批准家具实例，加原创维护台；并非回到旧版家具。
- 保留三功能区，顶灯改为三处；登记与武器区有局部功能光。教学说明跟随当前情境出现在玩家附近，不恢复顶部计时和左上角常驻栏。
- 靶位和武器台在场景中预先可见。靶位有编辑器预览，运行时切换到真实员工精灵/受击对象；训练目标在对话前不接收伤害，对话后恢复真实碰撞与伤害路径，没有第二套战斗模拟。
- 移动教学检查抵达前方区域；冲刺教学要求在该阶段从灯带南侧实际冲过并结束。提前冲刺、普通步行过线均不能算完成；到北侧后给回到起始侧的提示。
- 训练手枪初始2/12。首次手动装填前禁用该教学角色的自动空仓换弹；按R并完成实际装填后恢复原规则。教学借用武器暂不允许投掷，避免教程没有掉枪接管者时把枪丢失；正式楼层的投掷与自动换弹保持原规则。
- 击倒目标后先留出弹丸消散时间，再触发一次既有掌声与短促“校准通过”，之后开放出口；演出等待与命令淡入淡出遵守暂停。实际音频听感本轮没有验收，Dummy驱动下只验证事件调用。

### 原创资产：补功能结构，不加随机噪点

生成器与配方增加枕头、被面、被口、地毯、柜门、书脊、工具箱及作业台面等语义。被口折边、枕套缝、柜门通风槽、书脊颜色/标签、工具扣件、LCD窗口与行结构均从配方重建。摄像头保留原创轮廓，罩体与机身分色，安装点改向室内，避免机身藏在墙后。

保持12项原创资产原有物理尺度和三角面数；32px/m、2px外扩、Nearest、无Mip与新增家具roughness0.88保持。没有修改批准办公室工厂、既有反射方案或角色原画，没有导入逆向文件。非发光部分不因LCD精修而整张自发光。

### 卧室：指定布局不变

床仍在标注后侧、地毯仍在床下，书桌与笔记本仍在左侧，真实入口仍在前侧。补有限玄关包围与底座，让门外平台有建筑支撑；前侧低墙保留剖开视野。窗户增加可编辑百叶和克制背光；调整地面值域、环境光与桌面光，不做全屏提亮。

床上自己保留原精灵黑边与裁被关系，增加极轻呼吸。一次F后重复操作被锁定，镜头缓慢推进，床上自己切换到原画已有的睁眼表情，随后推进章节；没有增加第二次F门槛。保存失败可恢复可操作状态，重复F不能多推进日期。

### 电脑与红海：记录原始线索，玩家自行翻译

匿名档案窗口内新增“观测笔记”和“电码对照”页，提供A–Z、0–9参考表及可保存的个人译文。笔记未观测时为空，观察后只显示原始空间点划，不自动填答案或解开文件。第一章完整密钥验证仍未开放，后续双结局未在本轮制作。

第一章仍采用既有海天线空间光点；没有改成开关闪烁或重做批准的红海。新增观测记录使用向后兼容的扩展字段：`observation_version=1`及`observations`；旧`ch1_S`线索可幂等补成原始记录，保留已填写译文。原`chapter_one.version=1`不变，旧非故事模式存档不被自动转入新章。

红海观测完成后出现局部E返回提示；存档提交失败会恢复可重试状态。休息层维护台同样有靠近后的局部提示，不再依赖已隐藏的左上栏。

## 实际Camera证据

- [卧室前后对照：左旧、右新](../../.runtime/art_revision_20261029/bedroom_comparison.png)，保留同一基础构图。
- [当前卧室/入口](../../.runtime/art_revision_20261029/layout/bedroom.png)、[床上自己](../../.runtime/art_revision_20261029/layout/sleeping_self.png)。
- [教程登记区](../../.runtime/art_revision_20261029/tutorial_guide.png)、[靶区](../../.runtime/art_revision_20261029/tutorial_range.png)。
- [空笔记](../../.runtime/art_revision_20261029/notebook_empty.png)、[已有记录与玩家译文](../../.runtime/art_revision_20261029/notebook_observed.png)、[电码表](../../.runtime/art_revision_20261029/morse_table.png)。
- [冲刺正常速度记录](../../.runtime/art_revision_20261029/dash.gif)、[实弹教学记录](../../.runtime/art_revision_20261029/range.gif)、[唤醒演出记录](../../.runtime/art_revision_20261029/wake.gif)。
- [维护台方案一](../../.runtime/art_revision_20261029/workbench_42001_palette1.png)、[另一房型方案二](../../.runtime/art_revision_20261029/workbench_27391_palette2.png)、[卧室方案二](../../.runtime/art_revision_20261029/bedroom_palette2.png)。

图像均来自Godot实际Camera，没有AI重绘。测试录像中的定位准备有明确设置坐标，不能宣称整段人工游玩；实际移动、交互、射击、换弹与章节提交均走现有系统。GIF按实际截图间隔重建并取10ms时间粒度，时间记录见`media_timing.json`；没有把慢放标成正常速度。

## 验证记录

平台：Godot4.7.1、Compatibility、RTX5070Ti、640×360。GPU用例串行、最小化、隔离APPDATA/LOCALAPPDATA；没有修改正式存档或关闭用户进程。以下均为本轮结果，不引用旧报告充当通过数。

| 检查 | 当前结果 | 证据 |
| --- | --- | --- |
| 新教程约束、笔记输入/实际磁盘回读、F幂等、暂停提示 | 29项通过、0失败、退出0 | `delivery_art.log` |
| 门口实际步行、开关碰撞、电脑/药物/床可达、14件批准家具、隐藏HUD | 31项通过、0失败、退出0 | `layout.log` |
| 章节状态、旧线索迁移、保存失败回滚及一天只推进一次 | 42项通过、0失败、退出0 | `state_final.log` |
| 原创OBJ、UV、图集、采样与材质 | 3,775项、0失败 | `asset_checks.json` |
| 三个固定种子维护台与两套配色 | 种子42001/27391/78643均地图有效、休息层安全；六张实际画面复核，提示在维护台附近 | `visual_probe.json`、`delivery_visual.log` |
| Main新游戏到第一章完成 | 100项通过、0失败、退出0，包含真实战斗、换层失败回滚、休息层重试、红海读档及单次F | `clean_route.log` |

### 发现并处理的问题

开发检查中修正了一个动态返回值的类型标注、提前冲刺被计入后续教学的条件，以及首次手动换弹后仍禁用自动装填导致连续射击耗尽的问题。定向复验已通过这些反例。

首次全章用例在返房前已有80项通过；返房后自动驾驶直接斜切门洞到床边未到达，不能作为全章通过。补上穿过门洞、再转向床边的实际步行路点后，从同一真实检查点继续完成红海与F流程9项，退出0；随后重新从新游戏跑完整链路100项通过、0失败、退出0。不同种子的房间/敌人数会改变断言数量。没有改碰撞为穿墙，也没有将角色传送到床边隐藏这个失败。

多房型画面曾出现维护台提示落到画面边缘的现象。现已统一走世界现有的坐标转换入口并重新检查，六张画面的提示均落在维护台附近；没有通过隔离实验将当次现象归因于单一因素。后续投影复核与材质检查分开记录。

### 检查命令

分别把APPDATA/LOCALAPPDATA指向工程`.runtime/art_revision_20261029/`下独立目录。GPU用例串行，命令基础为：

```powershell
& 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 640x360 --position -30000,-30000 --script res://tests/chapter1_art_revision.gd
```

同样运行`tests/chapter1_layout_revision.gd`与`tests/chapter1_play_route.gd`；状态测试用`--headless --script res://tests/chapter1_state_test.gd`，资产测试用项目Python执行`tools/check_chapter1_pixel_assets.py`。本地多种子画面脚本在`.runtime/art_revision_20261029/visual_probe.gd`。

### 已知限制

- 本轮是功能与画面检查，没有稳定60FPS或新增GPU开销基准。不能把后台固定60帧上限、动画截图或P95推成全程性能合格。
- 仍有既有Control锚点警告；退出时可见2张纹理的RID泄漏/RenderingServer销毁诊断。完整红海退出还可见对象/资源释放提示，不宣称引擎诊断清零。状态测试主动注入的保存失败日志属于预期负例。
- 音频事件有调用验证，静音测试不证明掌声的音量与听感合格。
- 新视觉提供实际画面供用户判断，不将作者自检写成用户已验收。旧办公室资产批量翻修、新Boss原画、完整密码和双结局继续按任务书另行推进。

## 文件与整合状态

- 教程：`scripts/story/chapter_tutorial.gd`、`scripts/dream/dream_3d_tutorial_room.gd`、`scenes/story/chapter_tutorial_layout.tscn`。
- 局部提示/安全演出：`scripts/story/context_hint.gd`、`chapter_panel.gd`、`chapter_run.gd`；共享角色仅增加教程实例元数据控制的换弹/借枪限制，默认正式行为不变。
- 卧室：`scenes/story/chapter_bedroom.tscn`、`chapter_wake_room.gd`、`shaders/story/sleeping_self.gdshader`。
- 笔记/章节：`chapter_archive.gd`、`chapter_one_state.gd`、`chapter_one.gd`、`chapter_coast.gd`、`scripts/ui/computer_overlay.gd`。
- 原创图集：`tools/build_chapter1_pixel_assets.py`、`tools/chapter1_pixel_asset_recipe.json`、`art/story/chapter1/*`及来源README。
- 验证：`tests/chapter1_art_revision.gd`、`chapter1_layout_revision.gd`、`chapter1_state_test.gd`、`chapter1_play_route.gd`。

上述实现接入正式Main故事模式；工程原有脏工作树保持，没有自动提交。`.runtime`为本地忽略证据目录，迁移工程时需另行携带。
