# 第一章、新教程与新增美术交付记录

后续布局与UI已按用户标注修正，当前状态见[房间布局与教程家具修正](chapter1-layout-revision-20261029.md)。下文89项等结果保留首次流程交付的历史范围，不能代替修正版验证。

2026-10-29。工程 `E:\GameProjects\FiveMinuteMore`，正式入口 `scenes/app/main.tscn`。实际开发、测试与返工均由本会话 Codex 完成，未使用子智能体或外部模型。用户明确选择当前会话直接开发，取代本任务的默认外部委派规则。工作树分支 `wip/linux-migrate-20261018`，基线HEAD `b5d286d8491701ac433826aa26b1d75d32f88c75`；未提交、合并、部署或清理用户改动。

## 进入方式与已实现范围

从主菜单选择**新游戏**进入第一章。旧存档继续旧生活模式，不自动转换或覆盖；测试全部使用工程 `.runtime` 下的隔离用户目录，没有动用户正式存档。

正式路线：开场→独立俯视卧室电脑／服药→入睡→重排教程→前台气泡与占卜→两层正式办公室肃清→安全休息层一次构筑→第一章宿主Boss→真实轿厢返房→走到床边躺下→既有红海→遮月窗口观察第一段信号S（三个点）→回房按F叫醒自己→第一章完成。后续章节、正式完整密钥和双结局尚未制作。

- 卧室是独立可编辑3D场景，不使用旧卧室背景。角色仍用原2D分件精灵及ActorDepthBridge3D；床缩至约1.48×2.20米，枕头上的自己以原像素角色贴合床面，被子遮住肩身。
- 教程复用本工程现有床、柜、桌椅、储物与墙地素材，形成准备区、移动区和射击区。前墙降低，隐藏原透视挤压的英文地面教学字。实际观察移动、Space冲刺、E交流与拾枪、开火、R换弹、击倒训练对象后才允许离开。
- 电脑与服药界面打开时隐藏常驻提示和旧手机小入口。Tab打开实体手机时暂停并沿用既有手机动作、频闪和镜头；手机时间正确显示21:00，重新连接被显示包装器移动后的真实后端。
- 第一章新卧室购物明确显示“本章暂不开放购物”，防止配送未迁移时收款却无法领取。聊天、音乐和设置可用，旧生活卧室购买与配送保留。
- 办公室沿用原生骨架、房间贴图、家具变体、门、墙根剖切与外围楼群；两套办公室配色、层次增强与显示侧像素稳定保留。第一章清理检查包含室内员工和送餐机器人，窗外巡逻不作为必清目标。
- 休息层不生成员工、机器人或攻击无人机；工作台有真实像素网格与碰撞，不再用浮空“工作台”Label3D。构筑选择会暂停，收益只应用一次，楼层重试不重复叠加。
- Boss复用原尺寸员工Boss原画和既有战斗行为，半血切换步枪并留出1.25秒准备。本次没有新Boss原画，也没有放大32px精灵。
- 首次进梯失败可以回到仍可操作的前台重试；Boss返程保留可移动轿厢。楼层种子按正式派生规则恢复，继续游戏不另换一张地图。
- 红海直接复用已批准场景，只加第一章信号与进出适配、隐藏调试HUD。保留红水、白浪、风机、单塔吊、雾和世界月亮。观察线索、继续恢复和重复F均做幂等检查；叫醒与日历推进在同次存档提交中完成。

## 新增美术与规范

正式规范见 [美术方向与七条标准](../plans/art-direction-20261029.md)。新增模型与图集放在 `art/story/chapter1`，原创生成配方为 `tools/chapter1_pixel_asset_recipe.json` 和 `tools/build_chapter1_pixel_assets.py`，独立交付检查为 `tools/check_chapter1_pixel_assets.py`。没有将signalis_re的OBJ、PNG、音频复制进工程；用户zip里的Agent、hooks和规则也未安装。

| 原创资产 | 三角面数 | 图集尺寸 |
| --- | ---: | --- |
| 床 | 344 | 256×512 |
| 床头柜 | 180 | 256×128 |
| 书桌 | 256 | 256×256 |
| 椅子 | 104 | 256×128 |
| 衣柜 | 104 | 256×512 |
| 书架 | 104 | 256×256 |
| 地毯 | 12 | 256×128 |
| 摄像头头部＋三角支架 | 80＋20 | 256×64／256×32 |
| 维护工作台 | 288 | 256×256 |

以上统计使用三角面，地毯按平面用途例外，不凑面数。逐面跨度采用round(世界边长×32)、最少1像素；岛外2px挤出、二次幂画布、Nearest、无Mip，roughness0.88、metallic0、specular0。局部Emission使用乘法蒙版，避免整张图集被白色自发光抹平。地面资产底面Y=0，摄像头支架背面Z=0，头部以转动铰点为局部轴。纹理以整洁块面、结构缝和少量边缘磨损为主，不铺随机噪点。最终specular归零后再次通过15项GPU场景检查，完整流程逻辑没有再改动。

既有批准的建筑swatch和显示侧防闪烁采样继续复用；没有为新资产的无Mip规则反改原OfficePixelMaterials的已批准缩小级别。新增逐面图集的导入设置逐件检查。

参考统计勘误：只读扫描1,787张PNG，长边至少1K为193张（10.8%），并非73张／4.1%。不能由尺寸统计推出“95%正式室内资产”分类比例或原作精确32px/m。32px/m作为本工程规范执行。证据：`.runtime/chapter1_20261029/reference_texture_stats.json`。

## 检查结果与实际证据

Godot4.7.1，Compatibility，RTX5070Ti，640×360。GPU用例串行、后台最小化并强制提交实际渲染帧；音频Dummy。没有关闭用户程序。检查条目数不等于独立人工游玩次数。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 第一章阶段规则、重复事件、旧档边界、写盘失败回滚、叫醒与日历同次提交 | 39／39，退出0 | `.runtime/chapter1_20261029/state.log` |
| 正式Main新游戏完整路线 | 89／89，退出0 | `.runtime/chapter1_20261029/route_final.log` |
| 新卧室后端与21:00、电脑遮挡、教程门槛、实景工作台、睡眠角色与海岸 | 15／15，退出0 | `.runtime/chapter1_20261029/smoke.log` |
| 原手机界面／应用回归，含原购买和配送、消息、音乐、音量与画面控制 | 38／38，退出0 | `.runtime/chapter1_20261029/phone_apps.log` |
| 对实际OBJ、PNG、材质及导入设置的独立检查 | 3,477项，0失败，退出0 | `.runtime/chapter1_20261029/asset_checks.json` |

完整路线包含真实抓药瓶、鼠标来回摇晃、吞药与扣库存；真实移动、冲刺、拾枪、弹丸伤害和换弹；真实抽牌、掉落卡拾取、构筑选择、Boss、往返电梯；一次故意注入的首次生成失败与重试；调用正式楼层重试入口并检查种子、Build和安全性；红海实际遮月窗口与退出／继续；F推进一天且不能重复计数。`shots=10`仅统计教程的confirmed_projectile_fired，不是整章射击总数。

**自动游玩范围**：导航时会将角色定位到房间和交互点，并给予测试免伤；击杀使用正式枪械与子弹，不注入伤害、不手改房间为CLEARED。遇到跨房间剩余敌人会再次清扫。因此这是功能与流程验证，不是人工一命通关、平衡或难度验收。场景烟测会显式设置阶段展示各个画面，不冒充顺序通关证据。

主要复现命令（PowerShell，工程根目录；GPU用例须串行）：

```powershell
$godot = 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe'
$env:APPDATA = Join-Path (Get-Location) '.runtime/chapter1_20261029/route_appdata'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 640x360 --position '-30000,-30000' --script res://tests/chapter1_play_route.gd --log-file .runtime/chapter1_20261029/route_final.log
& $godot --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 640x360 --position '-30000,-30000' --script res://tests/chapter1_smoke_test.gd --log-file .runtime/chapter1_20261029/smoke.log
& $godot --headless --path . --script res://tests/chapter1_state_test.gd --log-file .runtime/chapter1_20261029/state.log
```

手机旧应用回归使用 `tests/phone_apps_ui_test.gd`，APPDATA目录名须包含`phone_settings_sample`。Python检查使用本机已验证的Pillow运行时，执行`tools/check_chapter1_pixel_assets.py`。

实景画面全部来自上述Main实际Camera，没有AI重绘。四宫格只拼贴截图，动图按实际捕获时间间隔编码，没有人工补帧或慢放：

- [实景总览](../../.runtime/chapter1_20261029/chapter1_overview.png)
- [卧室走动，正常速度](../../.runtime/chapter1_20261029/chapter1_bedroom.gif)
- [教程射击／换弹片段，正常速度](../../.runtime/chapter1_20261029/chapter1_training.gif)
- [进梯片段，正常速度](../../.runtime/chapter1_20261029/chapter1_enter_cab.gif)
- [遮月后的信号，正常速度](../../.runtime/chapter1_20261029/chapter1_coast_signal.gif)
- [工作台实际Camera](../../.runtime/chapter1_20261029/workbench.png)、[监控实际Camera](../../.runtime/chapter1_20261029/surveillance.png)、[新卧室实体手机](../../.runtime/chapter1_20261029/bedroom_phone.png)

`.runtime`是本地证据目录，未纳入提交。源场景、资产、配方、检查脚本和本文保留在工程内。

动图记录完整流程通过时的运行画面；其后仅把新增家具材质Specular显式归零。总览、电脑、床上自己、工作台、监控和手机静态图已用最后15项GPU检查的画面更新，不把较早动图冒充最后材质版本。

## 修复范围与保留问题

开发期间多轮定向修复，未使用外部Agent：新房间取代旧背景贴角色；床体／睡眠姿态与明暗层次；图集Emission模式和三件资产轴心；教程攻击权威与真实弹丸／反馈入口；异步进梯与ready时序；前台失败重试；跨房间击退后的肃清状态；有限关卡的真实电梯卡兜底；室内机器人清理和安全层特殊单位限制；恢复种子；重复构筑；手机后端、时钟、界面遮挡。测试驱动自身的过早断言、失效对象捕获、特殊敌人类型和跨房间补扫也分别修正；历史失败日志不作为最终通过证据。

最终GPU日志无GDScript运行错误和断言失败，但仍有已有界面锚点警告、完整战斗路线中一次environment_debris归一化警告，以及退出时两张各6,888字节纹理的RID／RenderingServer销毁诊断。故不声明“Godot全部报错清零”。另外旧`phone_melatonin_currency_test.gd`仍期待已取消的指纹解锁和不存在的BOTTLE_GRAB_RECT，执行失败；未为迎合过时断言恢复旧交互，本次用当前38项手机应用检查和真实服药路线验证相关功能。

尚未做稳定60FPS、全部随机种子、最终听感、人工难度及长时间游玩验收。保留已批准美术的旧资产批量翻修、后续章节、新Boss原画、完整档案密钥与终局，均不在本次已完成范围。
