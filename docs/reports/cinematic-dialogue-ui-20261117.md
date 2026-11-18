# 双侧立绘对话 UI · 立绘卧室与大厅

按用户“暂时先替换立绘房间和大厅对话”的指令，当前样式已接入 `scenes/bedroom/bedroom.tscn` 和 `scenes/dream/Dream3D_ReceptionRoom.tscn`。原正常入口 `tools/preview_screen_wall.cmd` 直接加载 Main。`Run_Dialogue_UI.cmd` 继续作为独立样式参考。主人公默认立绘及表情见[立绘迁移记录](player-portraits-migration-20261117.md)。2026-11-18 起，大厅右侧使用用户提供的[前台专属立绘](../../art/characters/receptionist/portraits/README.md)。单人场景只显示左侧。

## 本轮视觉

- 单人时仅左侧角色，保持原色和正常高度。双人时两侧均可见，未说话的一侧保留 90% 不透明度、亮度 43%，下移 29 个逻辑单位；换人时交换强调状态。按用户最新要求，立绘只按表情状态选图，不随逐字显示切换嘴型。
- 两侧立绘向内收，左右各留约 70 个窗口像素的边距（1280×720 时）。
- 对话时场景整体增加 38% 黑色遮罩。遮罩位于立绘背后，文字保持明亮。
- 上方黑幕向中心下垂，下方黑幕向中心拱起。根据用户纠正，弧度已从初版正确方向的 66／70 经 44／44 再减为 22／22 个逻辑单位；保持弧边所在区域的平均位置，最新起伏只有上一版一半。按最新反馈收紧底部黑幕：从上一版向下回收 8 个逻辑单位（1280×720 时约 16 像素），缩小文字上方的黑色留边。两行文字的完整横向范围保持纯黑，弧度、立绘及网点过渡宽度保持。
- 半调点靠近黑幕较大，向外缩成细点，主要用圆点半径表现过渡。网点过渡带从 66 缩为 48 个逻辑单位，渐变及弧形保持；没有用同尺寸圆点的透明度代替尺寸变化。
- 底部无边框、横排两行文字。保留原对话的分页、逐字、选项、禁用选项、会话信号；增加淡入淡出及说话方位置过渡。

### 参与者显示

默认按单人处理，卧室自言自语、睡觉确认和普通系统提示只显示左侧。只有双人上下文或同段对白存在两位实际说话者时，才启用右侧；system／narrator 不算第二位角色。可通过 `two_person_dialogue` 指定场景或单句上下文，单句显式 false 优先。大厅前台交谈明确有玩家和 NPC 两位参与者，即使只有前台有台词，也显示两侧。单人时隐藏的右侧不参与移入移出，切回单人会清除先前的双人状态。

### 入场与退出时序

上下黑幕从画面外分别移入，两侧角色从左右屏幕外滑到已确认的位置；使用 0.32 秒 Cubic EaseOut。入场期间文字和常规选项隐藏，卧室逐字逻辑等待入场结束，大厅原控制器的逐字、音效和倒计时都保持零；到位后才开始。动画不受玩法慢动作倍率拖慢。

同一段 NPC 交谈换句时保留已到位的界面，不重复滑入。结束交谈先隐藏文字，再让上下黑幕及角色向原方向收回。原弧度、网点范围、立绘最终位置与黑底文字安全区保持。

点击、E、Enter 推进；F5 重播；1 仓库，2 白盒，3 同布局正式美术。独立预览不播放背景音乐，不写正式存档与设置。启动器防止重复运行，持续保持低进程优先级，并沿用全游戏前台 60／后台 30 的帧数预算；渲染配置仍来自 project.godot。

### 右侧选项

现有对话选项在字幕上方右侧竖排。选项就绪后整组从屏幕右外滑入，用时 0.25 秒。条带的右端用圆形半调过渡，点径越靠外越小。选中行显示亮边和左侧箭头。实机验证了鼠标点击和原对话动作，方向键跳过禁用项，滑动到位后才接受选中。独立预览第三句可试三个选项。

`cinematic_choice_list.gd` 管理布局、入场和按钮装饰，`dialogue_choice_halftone.gdshader` 绘制条带与网点。选项动作由原对话控制器处理。实际 Camera 白盒与正式美术对照见 `.runtime/cinematic_dialogue_20261117/side_choices_laboratory/`，正式入口的卧室「睡觉／再等等」与大厅回归见 `side_choices_formal_main/`。

### 对话中断

2026-11-19 用户确认推广。正式游戏的卧室与大厅共用红色「闭嘴」选项。它在台词显示完前从右侧滑入，鼠标按下即停止逐字播放并关闭整段对话。已显示的字从原位散开、翻转下落，在约半秒内淡出。大厅中断后恢复操作，可重新交谈。大厅的对白完成标记和抽牌状态由原流程更新。

独立测试覆盖了首次和重复点选、散落字的位置、鼠标恢复及快速重开，逻辑 65 项、实际 Camera 51 项通过。正式 Main 的 59 项检查通过，验证了卧室中断后可以重新确认入睡、大厅中断后可重听五段对白再抽牌。证据位于 `interrupt_full_logic/`、`interrupt_camera/` 和 `interrupt_formal_main/`，实景对比见 `interrupt_camera/interrupt_comparison_2.png`。

推广确认后，通过原启动器的私有静音诊断启动正式 Main。实际运行使用 Forward+ / Vulkan，正常退出，启动记录在 `interrupt_promotion_main/`。

## 实现入口

- `scenes/ui/dialogue/cinematic_dialogue.tscn`
- `scripts/ui/dialogue/cinematic_dialogue.gd`：继承现有 `BedroomConfirmationDialog`，只提供可选择的叙事呈现。
- `shaders/ui/cinematic_dialogue_veil.gdshader`：单层弧形渐变和尺寸渐变的交错圆点。
- `scenes/testing/CinematicDialogueLab.tscn` / `CinematicDialoguePreview.tscn`
- `scripts/testing/cinematic_dialogue_preview.gd`
- `tools/preview_cinematic_dialogue.ps1`

正式接入涵盖卧室和大厅。卧室沿用确认控制器、动作白名单、文案和随机替换；大厅沿用 `DreamDialogueController` 的五段文本、唯一逐字／倒计时时钟、情绪、镜头和后续抽牌。大厅新呈现通过 `externally_driven` 接收进度，不自行推进；文字固定按获准 12px 布局显示，旧 JSON 中 18px 样式不改原文件。ESC 优先关闭对话，不直接打开全局暂停。大厅提示／情绪小气泡、教程及其他世界气泡保持原入口。

原 `confirmation_dialog.gd/.tscn` 基类、Main、文案数据、原画与渲染配置均未改动。`DreamDialogueController` 为新呈现提供入场等待、换句时保持界面和台词中断处理。原逐字和倒计时参数继续由现有控制器管理。保护散列已核对。共享工作区已有改动保留，未提交或合并。

## 验证与证据

- 功能和输入：`tests/cinematic_dialogue_test.gd`，53 项通过。覆盖单人、双人推断、叙述者排除、单独 right 说话者回归左侧、显式双人含静默听者、显式独白覆盖、双人切单人清理，以及原动效、分页和控制器回归。证据 `participants_logic_final/`，PID 56484，退出 0。
- 原控制器兼容：`tests/test_dream_dialogue_controller.gd`，原 10 组场景通过；覆盖原打断、选择、超时、序列、双锚点与离开。证据 `motion_legacy_controller/`，PID 46128，退出 0。
- 上一轮双人动效的独立实际 Camera：`tests/cinematic_dialogue_camera_test.gd --external-view`，32 项通过；白盒和同布局正式美术保留四区、8 敌人、家具，包含烟雾、重建、释放，确认移出后的上下黑幕在画面外。证据 `motion_external_gate/`，PID 55080，退出 0。
- 参与者显隐的正式 Main 回归：`tests/cinematic_dialogue_integration_test.gd`，41 项通过。实际卧室独白和睡觉选项无右侧立绘；前台双人交谈保留两侧，回到卧室恢复单人。逐帧 JSON 确认单人整个入场期间右侧均不可见，双人入场均可见；原打字等待、睡觉／取消、E／鼠标／ESC、五段对白、抽牌及场景清理继续通过。证据 `participants_main_final/`，PID 62156，退出 0。
- 自动检查在启动前准备私有静音配置并使用 Dummy 音频；实际 Camera 为 Forward+ / Vulkan、1280×720 原生世界、640×360 逻辑 UI，最小化窗口强制真实 GPU 绘制，限 60 帧。未改用户音量，未关闭用户进程。
- 未出现脚本或着色器错误。现有卧室天气和场景构造的 Control 锚点警告保留在日志，未扩大修复范围。

有限 A/B/A 墙钟帧间隔，单位 ms；正式美术每窗 120 帧，烟雾组合 150 帧，原始 CSV 在独立 Camera 证据目录。场景、敌人、家具、分辨率、限帧和音频条件一致。下表为入场完成后的呈现窗口，不是动画首次触发峰值认证。

| 正式美术窗口 | P50 | P95 | P99 | 最大 | 超 20ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| A / 打开前 | 16.614 | 17.805 | 18.385 | 18.670 | 0 |
| B / 外部控制器＋新对话 | 16.620 | 17.302 | 17.863 | 17.907 | 0 |
| A / 关闭后 | 16.655 | 17.469 | 17.781 | 17.907 | 0 |
| 烟雾＋新对话 | 16.569 | 20.662 | 25.303 | 29.024 | 9 |

烟雾组合仍有峰值；此为有界接入验证，不是整局稳定 60 FPS 认证，不能把最小化强制绘制及 Dummy 音频结果当作前台真实音频路径的整局性能。动效记录含 GPU 读回，不用于性能结论。本次参与者显隐修复不修改着色器和计时控制器，未重跑表中的性能窗口；该表保留为上一轮双人版本的有界参考。

证据根目录：`.runtime/cinematic_dialogue_20261117/`。

参与者显隐实景位于 `participants_main_final/`，包括 `bedroom_dialogue.png`、`bedroom_choices.png`、`reception_dialogue.png`、`reception_cards.png`。移入过程与时钟记录见 `bedroom_entrance_*.png/.json` 和 `reception_entrance_*.png/.json`，合成演示见 `dialogue_entrance.gif`。独立样式参考仍在 `camera_fitted_bottom_black_final/`。
