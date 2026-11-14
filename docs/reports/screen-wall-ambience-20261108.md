# 主界面 Quasi Drone 环境音

用户选定第三个候选 Quasi Drone，要求使用完整音频并保持很小的音量。
已接入当前正式电视墙主界面 `scenes/ui/main_menu.tscn`，正常试玩仍使用
`tools/preview_screen_wall.cmd`。重新打开原入口即可试听。

## 素材与播放

- 使用用户提供的原始 WAV：`840934__bassimat__quasi-drone-a-low-frequency-ambient-drone-soundscape.wav`。
  作者 bassimat，来源 <https://freesound.org/people/bassimat/sounds/840934/>，CC0 1.0。
- 完整时长 **607.988 秒（10 分 07.988 秒）**，48 kHz 双声道；未截成短片段，
  未改变音高和速度。运行资源为 Vorbis quality 5，`sfx/preview/screen_wall_ambience.res`
  自带全部压缩音频，大小 7,346,288 字节，不依赖 Downloads 或 `.runtime` 文件。
- 原始 WAV 保留在用户提供的位置。运行副本只在首尾各增加 10 ms 防爆音淡化，
  完整时间轴不变，整段循环。
- 单独播放器固定衰减 **−30 dB**（振幅约为原来的 3.16%），通过现有 **SFX → Master**
  音量控制；不改变普通玩家的保存音量或 Windows 总音量。
- 进入菜单时 2 秒淡入；菜单设置页打开时继续播放。新游戏和继续游戏均在电视关机
  演出时以 1.2 秒淡出，离开菜单后停止并释放。返回菜单时只创建一个播放器，不叠音。
- 单曲平均电平约 −14.3 dBFS；播放器衰减后约 −44.3 dBFS，默认 80% 音效总线还会
  进一步降低。现有悬停、关机音的平均电平约 −34.6 dBFS，保持更清楚的菜单反馈。

完整来源、原始/压缩文件哈希及重建方法见
[`SCREEN_WALL_AUDIO_SOURCES.md`](../../sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md)。

## 验证

Godot 4.7.1；所有检查启动前写入独立资料目录的主音量 0，音频探针全程保持 Master
静音。主观听感由用户在原入口确认。

| 检查 | 通过/失败 | 实际引擎 PID | 退出码 |
|---|---:|---:|---:|
| 正式入口：菜单、设置、曲尾循环、淡入淡出、新游戏、私有保存、继续进入 3D、两次返回菜单及单播放器清理；Compatibility GPU，Dummy 音频 | 39/0 | 73396 | 0 |
| 实际 WASAPI 混音：完整资源解码、低音量信号采集、音效音量控制及 Master 静音；原生窗口最小化 | 4/0 | 24588 | 0 |

WASAPI 在音效总线 100%、环境音播放器 −30 dB、Master 静音的条件下捕获 43,520 帧：
RMS **−44.06 dBFS**、峰值 **−35.23 dBFS**。这验证实际音频数据能解码并按低增益输出，
不代表系统扬声器的实际响度测量。完整曲尾由 seek 到 607.9 秒后的实际循环验证；
测试覆盖播放衔接，未做全段主观试听。

正式流程日志记录了场景锚点尺寸、Compatibility 不支持 SSR 的警告；音频探针错误日志
为空，音频资源与新增控制器没有解析错误。本次不扩展为全工程或性能验收。

两次测试启动预检按安全条件退出，均保留记录：一次是旧 PowerShell 对中文配置目录的
编码导致未加载私有静音设置；一次是 `--headless` 将音频驱动强制成 Dummy。
前者使用 Dummy 且守卫立即静音退出，后者在检查驱动后退出。修正测试启动方式后才
取得上表的正式通过结果。

证据目录：`.runtime/screen_wall_ambience_20261108/`，包括 `ambience_recipe.json`、
`formal/formal_result.json`、`formal/formal_menu.png`、`audio_result.json`、原始日志与
`validation.json` 的最终文件哈希。

## 修改范围

复用正式工作树 `E:/GameProjects/FiveMinuteMore`，分支 `wip/linux-migrate-20261018`，
HEAD `3b456f30bbe885d9c90b451bba9ed09af70bb8ec`。已有改动保留，未提交或合并。

- `scripts/ui/screen_wall_main_menu.gd`：主菜单自有的单播放器、低增益和生命周期淡化。
- `sfx/preview/screen_wall_ambience.res`：完整可循环运行资源。
- `sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md`：来源、授权、哈希、音量与重建说明。
- `tools/build_screen_wall_ambience.py`、`tools/encode_screen_wall_ambience.gd`：素材重建工具。
- `tests/screen_wall_main_entry_test.gd`：现有正式流程增加完整音轨与声音生命周期检查。
- 本报告；临时启动器、音频探针与数据保存在上述证据目录。

已正式接线；最终主观音量是否合适仍以用户在原入口试听为准。
