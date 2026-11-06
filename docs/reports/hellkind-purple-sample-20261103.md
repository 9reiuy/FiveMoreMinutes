# 独立美术与三维视野合并小样

双击工程根目录 [Run_Purple_Sample.cmd](../../Run_Purple_Sample.cmd) 启动。现在与玩家视野光源小样共用同一配置，默认第 5 档、调色板开、像素化开、三维墙体视野遮挡开。第 5 档开启场景半调和调色板时，室内、玩家和敌人的身体共用 `#191D2E` 暗色和 `#FFE1E8` 亮色。玩家暖金描边和脚下扩散沿用各自的颜色。完整游戏镜头为 640×360，人物本体约 32–33 像素。按 2、4、5 对照美术档位，调色板和像素化可分别开关，切换档位保留这两个选择。F11 对照场景半调，F5 对照室内灯，F9 对照遮挡，F2 换房，F1 显示说明，F3 查看性能面板。[本次合并验证](combined-art-visibility-20261104.md)。

默认阵容为四名员工、四名女服务员、一台送餐机器人和两台外墙巡逻无人机。女服务员沿用员工的半调与描边；机器人和无人机用受光明暗驱动机身方点，保留整机细描边、屏幕和警示色。F12 跳到巡逻无人机附近的室内窗边，F7 切换敌人行动。此轮是小样美术验证；下方历史性能表使用的是此前的阵容。[室内敌人实拍](../../.runtime/hellkind_purple_sample_20261103/enemy_art_review/01_robot.png) · [巡逻无人机实拍](../../.runtime/hellkind_purple_sample_20261103/enemy_art_review/04_drone.png) · [运行检查](../../.runtime/hellkind_purple_sample_20261103/enemy_art_review/verification.json)

默认照明由环境底光、固定方向的室外主光和背光侧的城市反光组成。两束方向光使用同一套建筑屋顶、窗洞和家具遮挡。实际窗洞的尺寸、朝向和遮挡决定地面投影。[窗光前后对照](../../.runtime/hellkind_purple_sample_20261103/exterior_light_display_revision/window_comparison.png) · [另一侧窗户](../../.runtime/hellkind_purple_sample_20261103/exterior_light_display_revision/01_directional_default.png)

第 5 档沿用家具和门框细线。木板接缝沿房间方向拉长，端头错开，石材与地砖保留各自的接缝。靠窗保留原方向光，窗外宽角度补光经实际窗洞向两侧与室内展开，外沿以逐渐变稀的有序方点过渡。补光使用窗框和家具的实体阴影，随房间切换最多启用三个原有窗光光源。木板缝随局部明暗反色。F5 的室内灯对照使用原明暗曲线。下方的历史性能表测量的是第 4 档。[修改前](../../.runtime/hellkind_purple_sample_20261103/window_scatter_review/proof_before.png) · [同机位实拍](../../.runtime/hellkind_purple_sample_20261103/window_scatter_review/proof_after.png) · [640×360 实拍](../../.runtime/hellkind_purple_sample_20261103/window_scatter_review/proof_after_640.png)

接缝只绘制在有铺装类型的地面上。独立地毯沿用原有材质和窗光半调。小样的两束室外光接入玩家已有的立体投影，玩家和敌人在窗光内的影子随角色位置变化。[地毯与角色投影实拍](../../.runtime/hellkind_purple_sample_20261103/rug_and_actor_cast_shadows/comparison.png)

第 5 档的室外楼体使用细线轮廓。室内以深蓝灰与浅粉两色的方点密度表达亮暗。[室内调色板实拍](../../.runtime/hellkind_purple_sample_20261103/indoor_pink_palette/02_palette_on.png)

[实际镜头开关对照、移动截图和性能表](../../.runtime/hellkind_purple_sample_20261103/woo_visibility_review.html)。

## 遮挡怎样实现

Woo Woo 的原包 `www/data.json` 和 `scripts/c3runtime.js` 中，ShadowLight 从当前范围内的墙和门取得轮廓，沿离开玩家的方向投影；`objectsVisible` 另外用实际视线判定对象显隐。这是视野遮挡，和把主镜头拉近是两件事。

当前合并小样采用三维视野光源：整层完整墙体合成一个静态遮挡网格，玩家眼高处向六个方向记录最近的遮挡表面，所有材质共用同一张深度图。主镜头剖墙不会削矮这份遮挡几何，墙体正背面、侧面、顶部、窗台和洞口都参与。走动只更新光源，开门只更新门叶，破墙才更新静态网格。人物、家具和已有特效按同一份光学几何的稀疏视线显隐；原有碰撞、AI 和战斗来源节点保持原样。不增加人物覆盖层，也不累积上一帧画面。实现说明见[玩家视野光源](player-visibility-light-20261104.md)。

完整窗玻璃可透视，仍保留物理碰撞。门使用真实实体网格和旋转姿态，玻璃孔洞透视，门框与实体面遮挡；开门或破墙会更新实际可见范围。启动期间在加载遮罩下准备原有网格、脚步、武器、血液和烟雾的绘制资源，临时血液载体不会登记或留下污渍。

独立启动器使用 Forward+，以减少原 Compatibility 路径的首次绘制停顿。正式工程渲染器设置不变。Forward+ 的 3D 色彩编码经小样后处理识别，橙血保持原色。参见 [Godot 的管线编译说明](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html)。

## 旧二维遮挡版本的实际 Camera 功能记录

Godot 4.7.1、RTX 5070 Ti，实际 1280×720 窗口，原生世界 640×360。135/135 项通过，最终功能日志无错误。人物投影量到约 33 像素，保留完整脚部轮廓。检查覆盖同位开关、GPU 遮挡图与独立物理视线对照、眼前墙门表面、透明窗、真实门开合、破墙、家具和人物显隐、行走、换房、重建与退出。

实际可见血迹检出 624 个橙色像素；关闭遮挡时，测得 1157 个确实在墙后的新增橙血像素，打开遮挡后未漏出。源血液规则、AI 和碰撞的检查均通过。[原始功能报告](../../.runtime/hellkind_purple_sample_20261103/revision_woo_polygon/validation/report.json)。

## 旧第 4 档二维遮挡版本的性能记录

**未通过 60 FPS 门槛**

| 负载 | 帧数 | P50 ms | P95 ms | P99 ms | 最大 ms | 超预算帧 |
|---|---:|---:|---:|---:|---:|---:|
| 遮挡开：静止 | 2426 | 2.325 | 3.347 | 3.870 | 5.596 | 0 |
| 遮挡开：移动与四房间 | 6297 | 2.419 | 3.539 | 4.145 | 27.748 | 2 |
| 遮挡开：真实门开合 | 2474 | 3.072 | 4.421 | 6.038 | 9.249 | 0 |
| 关闭遮挡：混合战斗 | 2488 | 7.300 | 11.953 | 16.240 | 27.439 | 22 |
| 遮挡开：混合战斗 | 2386 | 7.157 | 15.412 | 21.085 | 36.350 | 88 |

详见 [完整性能记录](../../.runtime/hellkind_purple_sample_20261103/revision_woo_polygon/performance/qualification.json) 与对照页。门槛为每个采样间隔不超过 16.667 毫秒。保留全部尖峰，首个效果仍纳入采样；截图、文件导出和正常加载准备在窗口外。同负载使用原地图、家具、八名敌人、阴影、反射和实际 Camera。关闭遮挡的战斗对照使用原材质，仍采用相同加载准备和烟雾缓存。

采集未限帧的相邻游戏帧墙钟时间；记录器不逐帧同步读取 GPU 计时，不把墙钟时间当作纯 GPU 时间。只覆盖本机独立四房间场景。后台游戏退出之前的并发记录、开启额外诊断的记录、独立绘制线程试验，均不作为验收成绩。

复测：`powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_woo_polygon_sample.ps1 -Mode Performance -Renderer forward_plus`。功能复测将 `Performance` 换成 `Functional`。性能脚本遇到其他已知游戏或 Godot 测试会停止预检，不会结束这些程序。

八个正式与共用源文件前后 SHA-256 一致，见 [源文件核对](../../.runtime/hellkind_purple_sample_20261103/revision_woo_polygon/production_after.json)。保留共享工作树现有改动，未提交或合并。
