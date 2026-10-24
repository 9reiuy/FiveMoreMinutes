# 交互提示线框与 NPC 情绪气泡 · 2026-10-23

## 已完成范围

- 仅“拾取／替换／进入／交流”使用新皮肤：`#396FE2` 细线直角框、轻微错位双线及角部短线，深色底、原有浅色文字，不加按键图标。其他交互文字保留旧皮肤。
- 出现约 0.16 秒，边框展开并轻微回弹，文字淡入；消失时收缩淡出。所有位置按整数像素取整，不缩放中文字形；同一目标跟随不重新播放，切换目标可重新展开。
- 新增独立的 NPC 小气泡，直接用整数像素绘制平静、开心、大笑、生气、难过、惊讶和紧张流汗七种面部表情，不依赖 Unicode 字体或随机轮播。
- NPC 的 `hint_emotion` 为明确的表现状态；前台初始紧张流汗，现有剧情节点映射紧张／难过／惊讶／开心，主动打断可表现生气。其他表情可由 NPC 的明确状态指定。
- NPC 在屏幕内可显示情绪气泡；原靠近判定选中可交谈 NPC 时，其上方出现“交流”。原 E 键与被动/主动交谈规则不变，不自动为被动 NPC 开始对话；菜单、对话、过场、离开范围时按现有优先级隐藏提示，屏外 NPC 不将气泡钉在屏幕边缘。
- 对话正文框、正文动画、回答选项均未修改。用独立 Control 替换接待区的 `NpcHintBubble`，没有修改 `dream_dialogue_bubble.gd` 或 `growing_dialogue_bubble.gd`。

## 验证

单智能体执行；测试串行、Dummy 静音、隔离存档。GPU 使用最小化实际游戏窗口，未关闭用户编辑器。未提交、上传仓库或全工程重导入。

| 检查 | 结果 |
| --- | --- |
| compact_interaction_prompt_test | 14 / 0 失败：动画、重入、拾取/替换分类、正式楼层电梯、暂停及过场清理 |
| emotion_interaction_test | 43 / 0 失败：精确蓝色、回弹、字形不缩放、七种状态、屏外/暂停、接待区交流和正文隔离 |
| passive_npc_dialogue_test | 97 / 0 失败：实际靠近、E 开始、主动/被动规则、正文包裹/定位及原倒计时布局 |
| test_reception_interaction_range | 27 / 0 失败：前台左右与后退靠近、头顶定位、离开范围 |
| dialogue_font_readability_test | 24 / 0 失败 |
| interaction_freed_world_test | 29 / 0 失败 |
| dream_3d_dialogue_camera_test | 15 / 0 失败 |
| emotion_interaction_camera_test | 17 / 0 失败：真实 Main 进入接待区，实际 Camera、七种表情、像素化/Palette 和原色、原 E 键启动正文 |

合计 266 项断言通过。原先测试中“NPC 只显示省略号，不显示交互文字”的过时断言已更新；范围测试同时补上实际窗口尺寸与移动后的摄像机更新，不再把屏外气泡误当可见提示。相关文件差异空白检查通过。

## 画面与动效

实际 Camera 图片：`.runtime/emotion_interaction_20261023/` 下的 `talk_palette.png`、`talk_native.png`、`emotion_neutral/happy/joy/angry/sad/surprised/nervous.png`、`action_拾取/替换/进入.png`、`dialogue_body_unchanged.png`。

静音动效：`.runtime/emotion_interaction_20261023/prompt_motion.mp4`。采用实际游戏摄像机输出、以每步 0.02 秒确定性驱动提示动画，便于观察完整展开/停留/消失，不是帧率测量或连续战斗录屏。表情逐种截图通过设置明确的 NPC 状态验收，不表示游戏会自动轮播。

日志：`.runtime/emotion_interaction_camera.log` 及 `.runtime/<测试名>-emotion.log`。

## 未消除的警告与验证边界

仍有既有 UI anchors、GPU 退出两张 6888 字节纹理/RID、RenderingServer 及部分 headless ObjectDB/资源清理警告，不能把断言通过描述为日志完全干净。未覆盖所有分辨率和长时间游玩；本次实际画面为 1280×720 窗口、现有 640×360 清晰 HUD 管线，未修改全局调色或摄像机。
