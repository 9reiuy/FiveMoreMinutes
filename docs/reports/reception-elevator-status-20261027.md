# 前台乘梯、手臂与提示文字交付（2026-10-27）

## 实际结果

前台 E 进入现在由真实 scripted locomotion 驱动走路，穿过门洞进入复用的 IndependentElevatorCab3D 后关门。镜头切入可移动的真实轿厢，冻结准备目标楼层，至少提供三秒额外可操作乘梯时间，然后混合真实画面衔接到站开门、走出和恢复战斗。这条入口未调用全屏黑色加载页。目标楼层在独立 World3D 准备，UI 隐藏，提交原显示实例；不复制玩家逻辑。

失败会释放未完成的楼层，恢复原前台角色位置、镜头、几何、NPC、声音、时间与输入；电梯信号不再 one-shot，因此可以真实按 E 重试。正常故事的种子、武器配置和地图生成逻辑仍由原 Main 和生成器负责。首次分批生成补齐原同步生成具备的玩家房间身份、安全位置和 room_visibility 初始化。

换弹和切换武器名复用 ComicPixelText（受击文字同一像素字体、描边、网点投影、入场弹出）。文字只在事件发生时采样世界锚点，之后仅重新投影，角色走开不会带走文字。换弹持续到真实 reload_left 结束；武器名沿用 1 秒时长和原淡出。字形入场只播放一次，长时间换弹不会循环弹跳。

手臂缺失来自“攻击关闭 → 隐藏武器与握持手，但装备状态又隐藏空手手臂”。现在收起武器时显示已有空手姿态，恢复攻击后回到原握持姿态；不更换库存，不增建电梯专用角色。

## 测试与证据

运行器：E:/Godot/Godot_v4.7.1-stable_win64_console.exe，Godot 4.7.1，RTX 5070 Ti / Compatibility。每条均使用 `--path . --audio-driver Dummy --script res://tests/<文件>` 和独立 `.runtime/reception_journey_20261027/profile`。GPU 测试串行，正式入口录制启动于屏外32×32窗口并由 background_gpu 保持最小化，实际 Camera 输出1280×720。

| 测试 | 模式与结果 | 日志 |
| --- | --- | --- |
| player_hand_presentation_test.gd | Headless，174 项通过，退出码0 | hands.log |
| player_hurt_presentation_test.gd | Headless，57 项通过，退出码0 | hurt.log |
| reception_journey_delivery.gd | GPU，24 项通过，退出码0；真实 E、失败重试、可移动轿厢、正式到站、文字锚点与生命周期 | gpu.log、report.json |
| test_elevator_animation_flow.gd | GPU，failures=0，退出码0；后续换层手臂、暂停、到站、失败恢复旧楼层 | floor_flow.log |

合计前三项255条检查通过，另有连续换层回归。前台测得准备完成后的可见可操作时间约3.004秒；后续换层回归的暂停约193ms、记录可见阶段约3206ms。故障回归主动将生成尝试次数设0，日志中布局失败属于预期故障注入。

实景进行了五次迭代运行：第一轮发现UI视口设置与测试换弹状态问题，之后依次修正门面遮挡、目标楼层未揭示、共享3D世界泄漏角色，以及首次分批生成缺少房间可见性初始化。最后一次24项全部通过；没有只用断言替代画面审查。

证据统一位于 `E:/GameProjects/FiveMinuteMore/.runtime/reception_journey_20261027/`：

- `delivery/journey_normal.gif`：正常速度完整流程，按真实截图时间戳回放，未删掉生成等待。
- `delivery/journey_contact.png`：前台、走入、可移动轿厢、正式楼层四阶段。
- `delivery/cab_hands.png`：实际轿厢手臂画面。
- `delivery/status_words.png`：武器名称、换弹文字。
- `report.json`：检查、逐帧文件与时间、乘梯时间和GPU记录。

## 实际限制

本轮未完成稳定60FPS或中档设备验收。最后一次录制约20.41秒，截图之间最长间隔约5.33秒（包含读取/保存截图、资源构建及首用渲染）；它不是纯帧耗时指标，不能用本次数据断言不卡顿或达成原加载性能目标。已完成的是可见轿厢承载等待、功能及画面衔接，后续性能仍需正式采样。

最终日志无脚本解析/断言失败；仍有已知布局警告和退出时纹理/RID/ObjectDB资源诊断，未宣称清空全部Godot错误。

## 执行与整合

实际执行者为Codex，未调用子智能体。核实的Antigravity CLI未登录，未获得可用模型列表，未调用AI开发请求或替换计费渠道。正式工作树 `E:/GameProjects/FiveMinuteMore`，分支 `wip/linux-migrate-20261018`，基线 `f1e9702f70f108510729e75637809d1d86cb088b`。改动已写入当前工作树，未提交、未合并、未清理其他工作树。

本轮涉及 main.gd、reception_elevator_journey.gd、dream_3d_reception_room.gd、dream_3d_random_dungeon.gd、selective_pixel_preview.gd、world_status_word.gd、dream_player.gd、player_hand_presentation.gd，两份既有渲染预热脚本（仅扩展冻结条件），三份定向测试及计划/报告。原工作树包含的其他改动保留；完整文件差异不等于本轮独占改动。
