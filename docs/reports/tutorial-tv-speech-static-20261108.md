# 教程电视以雪花声替换说话音效

已在现有教程关接入用户选定的电视雪花声，停用教程电视原来的逐字提示音。
原入口仍为 `Run_Tutorial.cmd`，重新打开即可试听。

## 当前行为

- 三间教程电视共用一个低音量播放器，复用已接入主菜单的 `screen_wall_static.res`。
  增益为 **−26 dB**，保持原音高，使用现有 **UI → SFX → Master** 控制。
- 对白逐字出现时播放；文字出完后的阅读时间和换句间隔停止。
- “请到这边来”与“到这边来”的循环呼叫跟随现有显示时段，间歇停止。
  电视必须已通电且开屏；“交谈”交互提示保持安静。
- 中断对话、离开电视、死亡、断电、退出教程或移除场景后停止；暂停时与教程一起暂停。
- 只在教程的对白参数中清空 `blip_sound`，没有删除其他角色仍使用的提示音。
  共享对白控制器和全局音效管理器未作本需求外的修改。

素材来源与授权沿用
[`SCREEN_WALL_AUDIO_SOURCES.md`](../../sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md) 中
DiArchangeli 的 **TV Static.wav / CC0 1.0**；没有下载或复制新的声音资源。

## 检查结果

所有自动检查启动前使用独立资料目录的 Master=0，未改变玩家保存音量或系统音量。
两个流程检查使用 Headless/Dummy；音频探针使用原生 **Forward+ / Vulkan / WASAPI**，
窗口最小化，Master 全程静音，按共享 `playable.lock` 串行运行并释放。

| 检查 | 通过/失败 | 实际引擎 PID | 退出码 |
|---|---:|---:|---:|
| 教程对白：静默提示、替换旧音、文字完成、取消/重开、断电/恢复、循环呼叫、暂停、其他角色音效及资源清理 | 30/0 | 90572 | 0 |
| 三间教学室的台词、推进、灯门、跳跃和射击配置等现有流程回归 | 26/0 | 99544 | 0 |
| 新播放器实际混音：低增益、原音高、停止后静音、暂停静音、释放和 Master 保护 | 6/0 | 62812 | 0 |

WASAPI 探针捕获说话段 RMS **−44.07 dBFS**、峰值 **−31.37 dBFS**；停止和暂停后均
达到探针下限 −160 dBFS（静音检查门槛 −90 dBFS）。这验证声音数据与启停，不代表通过
扬声器进行过主观试听。本次没有改动画面，也没有作性能或难度验收。

三轮检查的标准错误均为空。证据位于 `.runtime/tutorial_tv_audio_20261108/`，包括
`dialogue_out.log`、`lesson/validation.json`、`audio_result.json`、启动记录、改动前快照
和最终文件哈希 `validation.json`。

## 修改与整合状态

复用 `E:/GameProjects/FiveMinuteMore`，分支 `wip/linux-migrate-20261018`，
HEAD `3b456f30bbe885d9c90b451bba9ed09af70bb8ec`。已有工作树改动保留，未提交或合并。

- `scripts/story/tutorial_tv_speech_audio.gd`：教程独立的低音量播放器和短淡入淡出。
- `scripts/dream/dream_3d_tutorial_room.gd`：读取原对白/呼叫状态、通电和开屏状态，停用旧逐字音。
- `tests/test_tutorial_dialogue_integration.gd`：扩展现有对白检查。
- `sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md`：增加教程复用与时序说明。
- 本报告；临时音频探针和启动器保存在证据目录。

已接入现有教程入口；最终听感仍由用户在原入口确认。
