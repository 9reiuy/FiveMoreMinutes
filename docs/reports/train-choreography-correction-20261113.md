# 0-6 爆炸退场与敌方出场修正

本轮只修改 0-6 编排及其验证脚本。沿用已接入的 CC0 气体爆炸、原列车模型、Forward+、1280×720 实际游戏画面和原试玩入口；未导出游戏版本。

## 最终行为

- 每次只在退役车厢与前一节仍在运行的车厢连接处引爆一次，最后一节使用其后连接处。取消车厢内部三个爆点。
- 断开的车厢保持原高度、横向位置和朝向，直接使用隧道场景的行进距离向后移动。烟火及其声音一起随场景退后；慢动作、暂停和减速不再与另一个退场时钟错位。移出镜头后清理，最远保留 129 米退场距离。
- 进入第三节车厢时记录玩家实际纵向位置，以说话者所在窗口对齐该位置。敌车完成靠近、说话者与玩家并列后，才拉近对话镜头。之后继续沿用敌车以 2.1 米/秒相对超车、在首节车厢对齐的规则。
- 提前击败 Boss 时，该角色由本关保留到敌车分岔离场，避免通用遗体计时清理后无法执行到站编排。未修改生命、伤害、20 秒车厢销毁期限或到站镜头角度。

## 当前验证

两项原生 Vulkan / Forward+ 检查共 **58 项通过，0 项失败**，最终两次运行 stderr 均为空。

| 检查 | 结果 | 原始证据 |
| --- | --- | --- |
| 连接处单爆点、车厢固定高度与朝向、烟火跟随场景、镜头外清理、死亡与重开 | 23 / 23 | `.runtime/train_choreography_fix_20261113/coupling-20261113-144719/validation.json` |
| 第三节触发、玩家侧面入场、对话与翻滚、超车及碰撞同步、真实 20 秒期限、真实输入穿越车厢、提前击败 Boss 后仍能分岔到站、重复进入与死亡重开 | 35 / 35 | `.runtime/train_choreography_fix_20261113/choreography-20261113-150731/result.json` |

本轮推进检查同时修正了测试驾驶器：翻滚及武器配置后应按实际行走碰撞圆心对准窄连廊，持续换算屏幕方向输入，不能只按精灵原点一直向右。实际推进未用传送越过后续车厢。先前失败运行保留在同目录，未覆盖成成功记录。

录像为 0-6 实际游戏 Camera，保持原行驶角度和镜头参数；为了看清远处尾车，取景中心临时对准退役车厢，按正式场景距离确定性推进。读取截图不计为性能采样。并列入场截图来自正常推进镜头。以上为本机本次改动的验证，非全游戏性能认证或用户美术验收。

## 查看与试玩

- 爆炸及向后退场录像：`.runtime/train_choreography_fix_20261113/0-6_coupling_retirement.mp4`
- 并列入场实际画面：`.runtime/train_choreography_fix_20261113/choreography-20261113-150731/01b_parallel_arrival.png`
- 到站实际画面：`.runtime/train_choreography_fix_20261113/choreography-20261113-150731/04_front_car_arrival.png`
- 原试玩入口：`Run_0-6.cmd`

正式改动：`scripts/testing/metro_station/train_chapter.gd`、`scripts/testing/metro_station/train_derailment.gd`；验证脚本：`tests/train_chase_derailment_test.gd`、`tests/explosion_level06_integration_test.gd`。本轮前的文件副本位于 `.runtime/train_choreography_fix_20261113/baseline/`。
