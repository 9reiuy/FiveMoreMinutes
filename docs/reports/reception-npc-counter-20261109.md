# NPC 靠近前柜台与桌面塔罗摆设移除

2026-11-09，已接入现有大厅。

- npc1 从 `(7.2,16.2)` 调整到 `(7.2,16.9)`，向前柜台移动 0.7 格，站在员工空间内。实际 Camera 已检查与柜台的间距及脚底显示。
- 大厅不再生成三张台面装饰卡牌，并移除其摆放垫；台灯保持原位。仅修改当前大厅专用派生布局，原共享美术生成器保持。
- 角色原图、镜头、0.78 高柜台、材质、投影修正和地毯接触保持。原交谈、剧情发牌与选牌流程验证通过。

证据目录：`.runtime/reception_npc_counter_20261109/`，汇总为 `summary.json`。

| 批次 | PID | 检查 | 结果 |
| --- | ---: | ---: | --- |
| `camera01` | 67248 | 32 | 正式 Main Camera、NPC 原图／眨眼／脚底、交谈气泡及多位置角色显示，通过 |
| `input_route01` | 68352 | 26 | 正常走动到柜台、真实 E 交谈、剧情发牌与鼠标选牌、台阶闸机到电梯，通过 |

共 **58 项通过**，两个进程退出 0，包装器已归还所持共享锁，本轮无待运行图形批次。启动前私有 Master=0 配置，显式 Dummy；Forward+ / Vulkan，640×360 游戏、1280×720 窗口、Nearest。既有 Control 锚点和 ImageTexture/RID 退出诊断保留在原始日志，没有性能认证声明。

正式源仅调整 `dream_3d_reception_room.gd` 的 NPC 位置及 `reception_reference_layout.gd` 的台面摆设。既有 `reception_floor_visibility_test.gd` 的摆设预期同步更新，该套本轮未另行运行。9 份保护源散列一致，包括共享布局基类、角色桥／NPC 拼接、家具材质与 Shader、地毯 Shader、相机场景、玩家及项目配置。未提交、重置或清理共享工作树。

[最终柜台与 NPC 实机画面](../../.runtime/reception_npc_counter_20261109/camera01/npc_near_talk_ui.png)
