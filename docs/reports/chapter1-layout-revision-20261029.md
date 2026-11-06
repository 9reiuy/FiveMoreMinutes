# 第一章房间布局与教程家具修正

2026-10-29，按用户红／蓝／黄标注执行，Codex本会话直接修改，无子智能体、外部委派、提交或部署。此记录取代首次交付中对应的布局和常驻HUD描述；原完整章流程的89项结果是此前版本的记录，本轮不把它重新算作当前测试。

## 当前修改

- 卧室床移至后侧红区横放，地毯与床同中心、位于床体下。床头柜及药物移到枕侧，床上自己的位置和旋转一起更新。蓝区书桌靠左侧墙，椅子朝向桌面；原台式显示器、支架和独立键盘已从源配方移除，改为有键盘底座、铰链、倾斜上屏的笔记本。
- 黄色前侧区域增加真实门洞、完整门框、门槛、可开关门扇和入口短平台。出生于入口外侧，可实际穿过门洞进房。门扇2D碰撞随3D转动同步，前墙与碰撞均分成两段；入口没有被完整旧墙继续封住。入口外侧目前为短平台，没有新增房间外的关卡或路线。
- 删除游戏HUD顶部计时绘制，内部计时不变。隐藏第一章左上角常驻任务／操作文本，保留电脑、手机及维护等实际界面。卧室只有靠近物件时显示局部交互提示；手机内时间保留。
- 教程上一版直接实例化旧3D家具，漏掉正式楼层运行时的新纹理替换。这次将同一批准家具工厂与逐面纹理的结果保存为`scenes/story/tutorial_props`，17个实例直接显示新版家具。准备区改用沙发、柜、茶几、饮水机；中段和靶区使用正式工位、椅子、柜和档案架。原旧家具场景引用已移除，没有只在旧模型上临时叠图。模型在编辑器也可见。
- 已批准的办公室配色一／二、角色精灵、灯光、其他楼层家具源资产与战斗数值保持复用。没有导入逆向资产。

## 当前验证

Godot4.7.1，Compatibility／RTX5070Ti，640×360；后台最小化GPU用例串行，独立APPDATA，没有动正式存档。

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| 新布局、入口穿行／开关／阻挡、电脑与床头药物可达、移动后床上自己、F叫醒、新版17件教程家具及对应碰撞、移除左上UI及顶部时间 | 30项通过，退出0 | `.runtime/chapter1_layout_revision/gpu.log` |
| 正式Main新游戏→新卧室真实服药→新教程实际移动／冲刺／交流／拾枪／换弹／弹丸击倒 | 11项通过，退出0 | `.runtime/chapter1_layout_revision/tutorial.log` |
| 原创OBJ／图集／材质／导入检查，含新笔记本桌与门 | 3,775项，0失败 | `.runtime/chapter1_20261029/asset_checks.json` |

顶部时间不是只检查字符串或隐藏某一张截图：冻结实际教程画面后，加入正式DreamHUD并设置12:34，逐像素比较顶部区域，确认没有增加计时像素。关门检查使用玩家真正的碰撞圆中心，而非有13px偏移的角色根节点。测试导航使用真实WASD与E／F；新教程检查以实际弹丸伤害完成，没有注入击杀。

最终无脚本错误与断言失败；仍有既有锚点警告及退出时两张6,888字节纹理的RID／RenderingServer销毁诊断，没有声称清零全部引擎诊断。没有重新做整章战斗、全部随机种子或稳定60FPS验收。

主要文件：`scenes/story/chapter_bedroom.tscn`、`scripts/story/chapter_wake_room.gd`、`chapter_panel.gd`、`scripts/ui/dream_hud.gd`、`scenes/story/chapter_tutorial_layout.tscn`、`scenes/story/tutorial_props/*`、`tools/build_tutorial_approved_props.gd`、`tools/chapter1_pixel_asset_recipe.json`、`tools/build_chapter1_pixel_assets.py`。

新笔记本桌180三角面，入口框144、门扇56；其他主要卧室家具未重绘。继续使用32px/m、Nearest、无Mip逐面图集，roughness0.88、metallic/specular0。

复现GPU检查：设置APPDATA和LOCALAPPDATA为工程`.runtime/chapter1_layout_revision/test_appdata`，运行Godot `--path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 640x360 --position -30000,-30000 --script res://tests/chapter1_layout_revision.gd`。教程用`tests/chapter1_play_route.gd -- --tutorial-only`，使用另一隔离目录。两者必须串行。

## 实际Camera画面

- [新卧室与入口](../../.runtime/chapter1_layout_revision/bedroom.png)
- [新版教程家具](../../.runtime/chapter1_layout_revision/tutorial_movement.png)
- [旋转后床上的自己](../../.runtime/chapter1_layout_revision/sleeping_self.png)
- [笔记本电脑交互](../../.runtime/chapter1_layout_revision/laptop_ui.png)
- [实际步行进入房间](../../.runtime/chapter1_layout_revision/entry_walk.gif)

这些是实际游戏Camera的截图／正常速度动图，没有AI重绘。`.runtime`是本地证据，不纳入自动提交。
