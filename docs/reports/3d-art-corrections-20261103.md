# 大厅、卧室、红海海崖纠正记录

> 后续更新：大厅已重做为右入左出的紧凑场景，卧室按用户红蓝标注重新摆放。当前布局见 [最新布局记录](compact-lobby-bedroom-markup-20261103.md)。


2026-11-03。按用户本轮三项反馈完成；本记录替代上一轮报告中这三个场景的布局与海崖颜色结论。正式入口为 `scenes/app/main.tscn`，原有 2D 卧室只作为参考。

[打开实机审阅页](../../.runtime/art_corrections_20261103/review.html)。图片来自正式游戏 Camera，使用隔离存档；没有改动用户存档。

## 改动

- **大厅：** 地毯后方原来是六个开放闸机，北墙另有两扇不能使用的装饰电梯门。已全部移除，封闭多余墙口和南侧旧入口走廊。保留一部可交互电梯，地毯主道连接电梯，侧支线连接塔罗台。玩家出生在大厅内部。
- **卧室：** 对照 `art/Badroom/bedroom_background.png`、`bedroom_bed.png`、`bedroom_desk.png` 及对应 2D 场景。床头靠北窗，电脑桌椅在左侧，地毯完整覆盖床的占地，柜子移至床正前方的南侧并朝向室内。移除床头灯模型的底座、灯杆、灯罩和光源，保留药瓶。同步交互点、碰撞和睡眠人物朝向；移动挡住窗户的墙柱和百叶。
- **海崖：** 更换为灰赭色岩面；通过真实三角面法线、疏落裂隙、岩层和 32 px/m 的细颗粒消除柔软圆滑感。月光下偏暖灰，遮月后保留褐色。海水维持原有红色及遮月变化。地形顶点和行走高度网格未改动。

## 实机验证

Godot 4.7.1 Compatibility，RTX 5070 Ti，1280×720，独立测试存档，游戏窗口在后台最小化并持续真实绘制。

| 范围 | 结果 | 证据 |
|---|---|---|
| 大厅普通行走、真实 E 对话、鼠标选牌、前往唯一电梯 | 16 项通过 | `reception_route/result.json` |
| 卧室进出、门扇碰撞、电脑、药物、床边 F 唤醒、模型间距 | 33 项通过 | `bedroom_route/result.json` |
| 红海行走贴地、明暗 Camera、信号观察与读档恢复 | 10 项通过 | `coast/result.json` |
| 电梯真实 E 进入、生成失败回退、重试进入正式楼层 | 24 项通过；记录 73 帧 | `reception_journey/report.json` |
| 独立 OBJ/贴图/材质审计 | 5920 项通过 | `asset_checks.json` |

以上证据路径均相对于 `.runtime/art_corrections_20261103/`。合计 83 项运行验证通过，零失败。额外的初次 Camera 巡检有 1 项月相检查；其海崖图片属于中间版本，最终海崖请看 `coast/`。

运行时模型包围盒确认：窗户最低点 1.3906 m，高于床头最高点 1.269 m；窗户与柜子、墙柱、通风百叶不相交。柜子最南端 4.175 m，内墙面 4.43 m，留有 0.255 m 间距；柜子也避开了进门通道。

从实际 Camera 投影采样的 12 个海崖点：月光下平均 RGB 为 `(0.322, 0.303, 0.297)`；遮月后为 `(0.204, 0.157, 0.125)`。这是局部可读性证据，不是全场照明或性能结论。

沿用旧入口的测试已更新电梯与卧室坐标；6 个相关脚本通过引擎语法检查。完整旧章节测试没有重新运行，本轮运行范围如上。测试退出时仍有此前出现的两项贴图 RID / ImageTexture 释放日志，部分场景另有 ObjectDB、资源退出和 UI 锚点警告；没有发现本轮新增的脚本或着色器编译错误。本轮不声称全游戏稳定 60 FPS。

## 文件与工作区

- 大厅：`scripts/dream/dream_3d_reception_room.gd`、`scripts/dream/tarot_reception_dressing.gd`。
- 卧室：`scenes/story/chapter_bedroom.tscn`、`tools/chapter1_pixel_asset_recipe.json`、床头柜生成资产及 `asset_audit.json`。资产审计中只有 `bedroom_nightstand` 条目发生语义变化。
- 海崖：`shaders/preview/coast_cliff_rock.gdshader`、`scenes/preview/night_coast_city_cliff_sample.tscn`、`tools/build_coast_city_cliff_sample.gd`。
- 可重跑的专项测试：`tests/art_revision_reception_test.gd`、`tests/art_correction_bedroom_test.gd`、`tests/art_correction_coast_test.gd`；旧测试中的布局假设同步更新。

当前分支 `wip/linux-migrate-20261018`，本轮开始的 HEAD 为 `b5d286d8491701ac433826aa26b1d75d32f88c75`。修改保留在共享工作区，未提交。开始前状态、涉及文件快照、最终文件摘要及本轮差异保存在 `.runtime/art_corrections_20261103/`；保留其他任务的已有修改。
