# 主界面电视雪花声音效

已按用户选择，将 DiArchangeli 的 **TV Static.wav** 接到正式主界面电视的雪花状态。
雪花出现时低音量播放，结束时停止；多台电视重叠时共享一个连续播放器，音量不累加。
原试玩入口仍为 `tools/preview_screen_wall.cmd`，重新打开即可试听。

## 实现与素材

- 显示控制器在更新实际着色器状态后报告雪花是否可见，覆盖悬停花屏、随机整屏雪花，
  以及菜单文字闪现时真正出现的雪花脉冲。普通 CRT 细颗粒和彩条不触发持续雪花声。
- 主菜单拥有一个 UI 播放器，单独衰减 **−26 dB**，沿用 **UI → SFX → Master** 音量链。
  首尾使用 12 ms 防爆音过渡；最后一台电视结束雪花时停止播放器。
- 打开设置页时立即暂停隐藏电视墙的雪花声；关闭后按恢复画面重新同步。
  电视断电会移除相应雪花状态，新游戏、继续游戏和离开菜单都会清理播放器。
- 已有 Quasi Drone 环境音、Neon Breathe 悬停音和 CRT 关机音保持各自的播放逻辑与音量。
  本次没有改动雪花画面、随机广播时间、配色或暂停界面的音效。

来源 <https://freesound.org/people/DiArchangeli/sounds/116395/>，**CC0 1.0**。
下载的是网站公开 HQ MP3 版本；从中截取 4.000–8.000 秒，解码为 48 kHz 双声道
16-bit PCM，首尾各 2 ms 防爆音淡化，保存为可循环的自包含资源
`sfx/preview/screen_wall_static.res`（768,468 字节）。原始 WAV 需要网站登录，本次未使用。
具体下载地址、哈希与重建方法见
[`SCREEN_WALL_AUDIO_SOURCES.md`](../../sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md)。

## 验证结果

Godot 4.7.1 / Compatibility / ANGLE D3D11 / RTX 5070 Ti，1280×720 原生窗口最小化。
启动前准备独立测试资料和主音量 0；真实音频检查保持 WASAPI 混音，Master 全程静音。
普通玩家设置与 Windows 总音量未改变。

| 检查 | 通过/失败 | 实际引擎 PID | 退出码 |
|---|---:|---:|---:|
| 雪花状态、悬停/随机广播、重叠电视、彩条排除、设置页、快速切换、断电与清理；真实 WASAPI 数据采集及实际 Camera | 29/0 | 99808 | 0 |
| 正式入口、新游戏、私有存档、继续进入 3D、暂停、两次返回菜单、环境音与雪花播放器数量和清理；Dummy 音频 | 44/0 | 91120 | 0 |

受控雪花用例在 UI 总线捕获的 RMS 为 **−43.86 dBFS**、峰值 **−32.26 dBFS**；
图像雪花结束后，静音检查的读数达到探针下限 −160 dBFS（门槛 −90 dBFS）。
采集隔离了雪花音，不包含原有悬停反馈；正常交互中的悬停音仍独立播放。
这些是静音状态下的数据和流程检查，主观听感由用户在原入口确认。

雪花专项错误日志为空。正式流程保留一条场景锚点尺寸警告，没有音频解析或播放错误。
初次测试脚本的类型标注和冻结显示节点的关机推进已修正，预检日志保留；上表为完成
全部检查后的结果。本次未作全工程或性能验收。

证据目录 `.runtime/screen_wall_static_20261108/`：`static_result.json`、
`formal/formal_result.json`、`hover_snow.png`、`static_recipe.json`、原始日志和
`validation.json` 的最终文件哈希。

## 工作树与修改文件

复用 `E:/GameProjects/FiveMinuteMore`，分支 `wip/linux-migrate-20261018`，
HEAD `3b456f30bbe885d9c90b451bba9ed09af70bb8ec`；已有改动保留，未提交或合并。

- `scripts/preview/screen_wall_display.gd`：可见雪花状态通知。
- `scripts/ui/screen_wall_main_menu.gd`：单播放器、低音量、设置页同步及清理。
- `sfx/preview/screen_wall_static.res`、`sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md`：音效和来源说明。
- `tools/encode_screen_wall_static_audio.gd`：运行资源重建。
- `tests/screen_wall_static_audio_test.gd`、`tests/screen_wall_main_entry_test.gd`：同步与正式流程检查。
- 本报告；改动前快照和临时启动器保存在上述证据目录。
