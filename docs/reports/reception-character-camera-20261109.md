# 前台 NPC、游戏镜头尺度与沙发朝向修正

2026-11-09。已接入现有正式大厅；视觉由用户继续审阅。本轮为既有大厅修正，不是新关卡或全游戏性能认证。

## 问题与修正

- **NPC**：虽然已使用指定的 `npc1.png`，仍套用了旧 waitress 的 28 像素宽头部裁切和部件偏移。帽子侧边被裁掉，腿与躯干重叠，整体还沿用家具平面的悬空偏移。现在三个眨眼帧都完整取 32×32 头部单元，按原图第一列的完整角色重排躯干、手和脚；脚底归到角色原点，再在大厅专用桥中使用实际脚底接触锚点。NPC 保持和平角色，不加入玩家或敌人战斗组，原图未改。
- **镜头**：旧大厅使用高度 21、45°、40° FOV 的远景，焦点只有 18% 跟随玩家，画面偏向电梯厅。现核对主游戏 `Dream3D_RandomDungeon.tscn` 的 CameraRig 0.8 倍变换后，对齐有效高度 **15.6**、俯角 **60°**、距离约 **18**、FOV **35°**，正常焦点改为玩家加主游戏的瞄准前探。保留大厅自身朝向。乘梯演出仍过渡到原有专用机位，电话和对话继续走已有相机权威。
- **沙发**：模型正面为本地 +Z，原先两张沙发旋转 PI，背向前方茶几。改回 0，座面朝向各自茶几与前厅。位置、尺寸、实体碰撞和材质保持。
- **气泡**：说话锚点随新 NPC 脚底和实际 Camera 朝上方向计算；表情／“交流”交替、接近“交谈”、E 开始原对话与塔罗流程保持。

实际 Camera 测量：五个位置的相机离所在楼面高度均为 15.6，32 个原画像素投影长度为 **31.3746** 游戏像素，Nearest 显示约 32 像素；没有单独放大人物。完整角色轮廓均在原生 640×360 画面范围内。NPC 透明捕获由旧 **27×34** 修正为 **29×37** 有效像素，保留原图造型，三种眨眼状态都不截帽子。

## 本轮验证

证据目录：`.runtime/reception_actor_camera_20261109/`，总结果 `summary.json`。所有批次独立 APPDATA/LOCALAPPDATA，启动前私有 Master=0，显式 Dummy；Forward+ / Vulkan，游戏 640×360、窗口 1280×720、Nearest。GPU 串行持有共享试玩锁，没有关闭用户或其他任务的进程。

| 批次 | PID | 通过项 | 结果与范围 |
| --- | ---: | ---: | --- |
| `camera02` | 8872 | 32 | 正式 Main Camera；从主游戏场景实际实例读取相机变换核对；五处角色尺度、完整轮廓、NPC 原图与脚底、三个眨眼帧、两张沙发和交谈气泡 |
| `input_route01` | 59688 | 24 | 正常方向输入走到柜台，真实 E 交谈、完成对话、塔罗发牌及鼠标选牌，走过台阶和闸机到电梯 |
| `left_journey01` | 52696 | 33 | A3 真实乘梯，演出 Camera，进入正式办公层、连续下一层、恢复卧室与控制 |
| `right_journey01` | 42600 | 24 | B3 真实乘梯，演出 Camera，进入正式办公层并恢复玩家控制 |

最终 **113 项通过**，四个验收进程均退出 0，锁已释放。检查是功能和有限实际画面验证，没有计时或全游戏性能声明。

### 画面

- [柜台与完整 NPC、玩家、交谈气泡](../../.runtime/reception_actor_camera_20261109/camera02/npc_near_talk_ui.png)
- [左侧沙发](../../.runtime/reception_actor_camera_20261109/camera02/waiting_west_ui.png)
- [右侧沙发](../../.runtime/reception_actor_camera_20261109/camera02/waiting_east_ui.png)
- [真实对话](../../.runtime/reception_actor_camera_20261109/input_route01/dialogue.png)
- [A3 乘梯演出](../../.runtime/reception_actor_camera_20261109/left_journey01/elevator_journey.png)
- [B3 乘梯演出](../../.runtime/reception_actor_camera_20261109/right_journey01/elevator_journey.png)

### 保留的早期记录和诊断

`baseline01` / PID26184 为修改前正式 Main 画面和临时主游戏尺度构图研究，退出 0；原 NPC 部件位置与捕获保留。`camera01` / PID39236 退出 1 的五项失败也保留：测试读取 SceneState 的路径／合成变换方法未取到相机，且透明包围框少算最后一行列。修正测试后，`camera02` 从不进树的正式关卡实例读取变换，逐像素合并包围框，32 项通过。没有通过改变产品高度或砍掉原图像素迎合测试。

原有 Control 锚点警告仍在。原始基线和 Camera 批次退出时均有 2 个 ImageTexture/RID 清理诊断；办公层仍输出既有 `OpVectorExtractDynamic is not supported yet`。本轮不把退出码 0 描述成日志全空，相关原始 stdout/stderr 均保留。

## 修改范围

正式源只涉及：

- `scripts/dream/dream_3d_reception_room.gd`
- `scripts/dream/reception_actor_depth_bridge.gd`
- `scripts/dream/reception_waitress_npc.gd`
- `scripts/dream/reception_reference_layout.gd`
- `scenes/dream/Dream3D_ReceptionRoom.tscn`

新增 `tests/reception_character_camera_test.gd` 及本报告，更新项目上下文和 GPU 协调记录。开工快照、散列及本轮差异在证据目录。13 个保护源散列一致，包括共享角色桥、主游戏脚本／场景、NPC 原图、前台家具材质工厂、墙地与地毯 Shader、电梯门、乘梯交接器和项目渲染配置。沿用当前石木材质、两块连续红毯、383 格 T 形大厅与左右共六部电梯，不恢复退役 Shader 效果。未提交、清理或重置共享工作树。
