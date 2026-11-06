# 角色八向图集接入与刘海连接修正 · 2026-10-30

执行：Codex 当前会话直接实现，未委派、未外发工程。工作树：`E:/GameProjects/FiveMinuteMore`，保留既有未提交修改，未提交 Git。

## 已接入

- 使用用户本次更新的 `art/Dream/dream_chr_32x32.png`，原图保持 280×250，不重绘、不缩放。将头和上身作为同一切片，旧 Body 节点保留接口但隐藏并清空运行时纹理，避免重复身体。
- 左、左下、正面、右下、右：前三行的第 3–7 列，三种眼睛帧；左上、背面、右上：第 5 行第 4–6 列，使用固定后脑图。
- 双手：第 2 列第 1 行；刘海：第 2 列第 2 行的 `(46,43,4,11)`；前腿：第 2 列第 3 行；后腿：第 2 列第 5 行。
- 八向朝向按实际 Camera 中的屏幕方向选择；战斗瞄准、碰撞与枪口 Marker 仍沿原有逻辑。
- 教程引导者和红海行走角色同步处理共用图集的旧切片。红海仅改角色及其朝向投影；不推广尚待确认的海崖城市样板。
- 导入为无损纹理、无 Mipmap，显示保持 Nearest。

## 用户指出的刘海连接点

早期实机裁图中左下连接点沿用了旧图集坐标，确实偏右、偏低。以第 1 列拼好的形态为准修正：

- 合体上身原点为 BodyPivot 下的 `(-16,-17)`，与参考拼图的头顶及衣摆对齐。
- 左下刘海根节点从 `(22,17)` 改为 `(20,14)`；右下从 `(10,17)` 改为 `(12,14)`，保留镜像方向。
- 左下刘海在拼图中的实际左上角为 `(19,13)`，根部 3 行像素与作者拼好的参考逐像素吻合。
- 保留原 4×11 像素、连续三段弯曲、回弹及高于衣服的图层；只在左下／右下显示独立刘海，其余六向使用图中固定头发。
- 脚及空手基准横向回调 1 像素，按作者拼图接合。持枪握持仍由现有握把系统处理。

## 手机保持

第 7 行的六格动作与蓝色光照蒙版不改。通过实际 Main → 前台 → Tab 开启／收起，验证暂停、镜头、原循环帧、身体隐藏与关闭恢复。原 PNG SHA256 及第 7 行 RGBA SHA256 均与本轮修改前完全一致，见 `.runtime/player_eight_facing_20261030/delivery_checks.json`。

## 验证

1. `tests/test_character_atlas_and_facing.gd`：36 / 0 失败。
2. `tests/player_side_bangs_curve_test.gd`：27 / 0 失败。
3. `tests/player_side_bangs_test.gd`：24 / 0 失败。
4. `tests/player_phone_animation_test.gd`：20 / 0 失败。
5. `tests/player_eight_facing_camera_test.gd`：实际 GPU（RTX 5070 Ti）、正式 Main 教程 Camera／前台手机／红海：97 / 0 失败。

合计 204 项断言通过。Camera 用正式运行场景，行走展示在固定清晰位置驱动真实角色步态与转向，供检查拼接，并非路线通关或性能测试。手机使用真实 Tab 输入与正式暂停／恢复入口。

中途修正了两项验证脚本问题：海岸开场眨眼使期望帧不一致；参考拼图对刘海最末端黑像素有 1 像素差异，根部校准应比较连接处而非强求整条逐像素相同。最终全部通过。测试退出阶段有现存资源释放提示和 Control 锚点警告；未将其计为运行场景已消除全部引擎警告。

## 实机证据

目录 `.runtime/player_eight_facing_20261030/`：

- `fringe_attachment_fixed.png`：作者拼好图与修正后左右下实际角色捕获对照。
- `camera/eight_views_camera.png`：八向实际世界 Camera 裁图，Nearest 放大。
- `walking_eight_views.gif`：正常速度，128 帧，约 6.01 秒；含局部放大，时间取实际采样间隔。
- `phone_normal.gif`：正式 Tab 开合，62 帧，约 3.00 秒。
- `camera/armed.png`、`camera/coast.png`：持枪及红海共用角色运行画面。
- `camera/result.json`：GPU 与断言结果；四项独立测试日志同目录。

## 主要实现文件

`scripts/data/player_character_atlas.gd` 统一切片／朝向／根部坐标；`dream_player.gd` 使用八向合体上身；`player_side_bangs.gd` 两个下斜向的连续刘海；`coast_walker.gd` 与 `night_coast.gd` 处理海岸角色；对应玩家、引导者和海岸场景保存新切片；`dream_3d_actor_depth_bridge.gd` 受击定位兼容合体上身；`character_card.gd` 避免预览重新显示旧 Body。
