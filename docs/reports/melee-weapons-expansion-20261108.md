# 六件近战武器接入

2026-11-08，已接入正式工程 E:/GameProjects/FiveMinuteMore。保留现有共享工作树；未提交、重置、清理或调用外部 AI CLI。

## 素材与独立身份

| 原素材 | 名称 | weapon_id |
|---|---|---|
| Weapons/6.png | 木板 | melee_plank |
| Weapons/11.png | 弯管 | melee_pipe |
| Weapons/21.png | 管钳 | melee_pipe_wrench |
| Weapons/22.png | 扳手 | melee_wrench |
| Weapons/23.png | 撬棍 | melee_crowbar |
| Weapons/43.png | 砍刀 | melee_machete |

直接使用用户指定的原 PNG，未重画、缩放保存或改色。各武器独立注册名称、拾取和掉落身份，并进入现有武器池与奖励候选。

## 当前行为

六件武器复用露西尔的现有攻击节点、距离、伤害、攻击弧度、击退、击倒、间隔、起手／挥动／收手与格挡；玩家和敌人分别沿用各自原有露西尔参数。伤害事件沿用原露西尔语义，保留现有血液和命中反馈。视觉仍是同样的双手叠握、持握角度和肩部位置；针对每张图的留白与握柄设置实际像素锚点，避免手落在透明区。

敌人初始随机池排除露西尔；房间原定的露西尔岗位在描述生成和实际生成入口被确定性替换为新六件武器，不额外消耗布局随机流。玩家露西尔保留，原世界拾取规则不变。此处禁用的是初始配装，不是新增禁止敌人拾取玩家丢出的露西尔规则。

近战准心、范围高亮、弹药 UI、格挡、背包分类、投掷数据、升级奖励和浏览器名称同步接入。浏览器按已解锁项紧凑显示，增加滚轮和滚动条，让新增条目能被选择。

## 验证

- 564 项专门检查通过：实际武器参数与露西尔逐项相同，真实物理墙阻止挥击，命中范围／去重和伤害语义一致；四种人形敌人的手部和距离正确；八方向握柄接触落在原图实体像素上；投掷保留独立 ID；旧配装替换稳定并覆盖全部六件武器。
- 原有手臂 174 项、扫击 57 项、换枪／运行配置 180 项回归通过，合计 975 项。
- 白盒实机 59 项、正式美术实机 60 项通过。真实输入挥击，真实拾取、命中伤害与击倒、敌人掉落、暂停和重建清理通过；未产生枪械子弹。
- 正式源码实机 71 项通过，包括实际 scenes/app/main.tscn 主菜单进入关卡，六件武器均可装备，旧露西尔生成请求被替换。最终原始记录位于 formal_camera01。
- 后台启动前准备私有静音配置，设置重载持续核对 Master=0；原生渲染使用 WASAPI，纯规则检查使用 Dummy。GPU 测试串行持有共用 playable.lock，记录 PID 与释放结果，不修改玩家音量。

## 有界开销

Godot 4.7.1 / Forward+ / Vulkan，RTX 5070 Ti；窗口 1280×720、世界 Camera 640×360。相同正式美术测试场、六名冻结 AI 的人形、真实玩家挥击与六次装备刷新，保留灯光、阴影、反射、像素显示和原生音频路径。原版六次都使用露西尔，新版依次使用新六件武器；先预热各贴图与共用扫击，采样 12 个真实秒，采样期间不截帧读回。

| 帧耗时 | 原版 | 本版 |
|---|---:|---:|
| P50 | 2.352 ms | 2.510 ms |
| P95 | 3.804 ms | 4.498 ms |
| P99 | 4.423 ms | 5.846 ms |
| 最大 | 5.789 ms | 9.146 ms |

两版 SubViewport 数均为 258；均无超过 80 ms 的采样。P95 增加约 0.69 ms。本记录仅是指定装备切换／挥击负载的局部对照，不是全游戏帧率认证；首次加载和完整战斗没有被这组暖机采样覆盖。原始帧数组保留在 perf_before01、perf_after01/result.json。

## 实机证据

![六件近战武器正常速度](../../.runtime/melee_expansion_20261108/delivery/melee_variants_normal_speed.gif)

六格动图来自分别录制的实际 Camera 局部，最近邻放大 3 倍，按原始时间戳以 50 ms 间隔取样，不加速挥击。完整原图 actual_camera.png、六格静图和原始 PNG 均保留；正式入口另见 formal_camera01/formal_game_entry.png。继续使用既有正式游戏入口，没有新增启动器。

## 修改文件

- `scripts/data/dream_gun_atlas.gd`
- `scripts/entities/dream_player.gd`
- `scripts/entities/employee_enemy.gd`
- `scripts/entities/humanoid_hand_pose.gd`
- `scripts/entities/player_hand_presentation.gd`
- `scripts/entities/enemy_hand_presentation.gd`
- `scripts/dream/lucille_weapon.gd`
- `scripts/dream/dream_3d_random_dungeon.gd`
- `scripts/dream/combat_defense.gd`
- `scripts/dream/dream_3d_target_highlight.gd`
- `scripts/dream/world_weapon_pickup.gd`
- `scripts/ui/crosshair.gd`
- `scripts/ui/dream_browser_app.gd`
- `scripts/data/upgrade_catalog.gd`

发布前对 14 个正式源文件逐个核对本任务开始时的 SHA256，再写入已通过独立测试场的候选；最终哈希保留在 published.json。中间 logic01 的透明像素断言未反转测试采样坐标、whitebox01 使用了不存在的测试字段，属于测试脚本问题，均保留并修正；最终通过目录为上文指定的记录。
