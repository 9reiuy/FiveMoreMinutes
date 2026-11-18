# 叉车开动、Shift 加速与手刹音效接入

用户已选定三条试听并授权接入。现有可驾驶叉车的共用控制器已接线，正常关卡及测试场创建的可驾驶叉车使用同一实现。

## 当前行为

- 开动：实际移动车辆后播放所选电机起步声，再循环运转段；音高随车速轻微变化。停车后短淡出。
- Shift 加速：实际向前加速时播放所选电动齿轮箱升转速片段，长度 0.75 秒；冷却中重复按键或键盘回响不会叠放。手刹取消加速时同步淡出。
- 手刹：行驶中拉手刹后循环所选轮胎刹擦段，松开或速度降至停车范围即停止。静止时同时按油门和手刹不发出行驶或漂移声。
- 单车固定三个 3D 播放器，跟随车身移动。下车、停用、恢复停车状态、死亡或销毁会清理声音；暂停随场景暂停，卸载后释放。
- 电机、加速和手刹的增益分别为 **−28 / −24 / −26 dB**；低速电机与手刹会再降低一些。
  声音接入现有 Environment → WorldSFX → SFX 总线，遵循玩家音效设置与原有慢动作音高。

实测修正了近距离音源放大：使用保留空间定位的 `ATTENUATION_DISABLED` 配合 32 米 `max_distance` 线性衰减，避免驾驶员靠近音源后抵消低音量设置。
该组合的行为见 [Godot AudioStreamPlayer3D 文档](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html)。

## 素材处理与署名

三条均来自用户已试听的公开 HQ MP3，不是另行下载的原始 WAV。

| 用途 | 原素材 / 作者 | 制作 |
|---|---|---|
| 开动 | Electric motor engine start stop / kentspublicdomain，CC0 | 保留前段启动，运转段交叉淡化循环 |
| 加速 | Engine Rev.wav / PieTheAnimator45，CC BY 4.0 | 截取 3.9–6.9 秒，保持音高压缩至 0.75 秒 |
| 手刹 | tire_skid_02 / loganzsound，CC0 | 裁去静音尾部，制作 0.405 秒循环，运行音高 0.88 |

统一转为单声道 48 kHz PCM，移除直流偏置，峰值整理至 −3 dBFS；资源以独立 `.res` 保存，无运行时网络或临时目录依赖。
原链接、源文件散列和必要修改说明登记于 `sfx/forklift/SOURCES.json`、`ATTRIBUTION.txt` 及 `docs/THIRD_PARTY_ASSETS.md`。
CC BY 4.0 的 PieTheAnimator45 署名与许可链接已保留。

## 验证结果

最终原生 **Forward+ / Vulkan / WASAPI** 检查 **32 项通过，0 项失败**，实际引擎 PID **59244**，退出码 0，标准错误为空。
检查从现有关卡的实际叉车进入，覆盖开动、物理 Shift 按键、冷却/回响去重、手刹优先、松手停止、带驾驶员换父节点、暂停/恢复、下车、停用、销毁和卸载。
前置 Headless 状态检查 24/0；最终原生检查覆盖这些状态并加入实际音频数据捕获和近距离音量检查。

私有音效音量 100%、Master=0，独立测试总线送入原 Environment，总线捕获发生在静音 Master 之前：

| 状态 | RMS dBFS | 峰值 dBFS |
|---|---:|---:|
| 低速开动 | −49.81 | −39.44 |
| Shift 加速，含电机声 | −48.69 | −37.42 |
| 手刹，含电机声 | −44.88 | −34.96 |
| 停车、暂停、下车后 | −160.00 | −160.00 |

这些是本次真实驾驶场景的混音取样，不是扬声器主观试听或性能承诺。初轮原生近距离增益失败记录保留在证据目录 `native/`，修正后的最终记录为 `native_final/`。
所有自动运行均在启动前写入私有静音配置；未修改玩家保存音量或 Windows 音量。实机验证串行使用共享锁，结束后已释放。

## 修改范围

- `scripts/dream/props/forklift_drive_audio.gd`：三声部的音量、音高、淡入淡出及清理。
- `scripts/dream/props/drivable_forklift.gd`：读取既有车辆状态并同步声音。
- `sfx/forklift/`：三条资源、来源和署名。
- `tests/forklift_audio_test.gd`：复用原有关卡测试入口进行实际车辆及混音验证。
- `docs/THIRD_PARTY_ASSETS.md` 与本报告。

加速度、速度、刹车、漂移、碰撞、血量及相机规则没有改动。8 份保护源的散列保持一致，包括渲染配置、全局声音管理、玩家设置、叉车模型、碰撞响应和关卡搭建逻辑。

复用 `E:/GameProjects/FiveMinuteMore`，分支 `wip/linux-migrate-20261018`，HEAD `41cd7e452edf9a21a9ffb95f4c5489ee5abb3b81`。
原有未提交改动保留，未提交或合并。本轮证据位于 `.runtime/forklift_audio_20261117/validation.json`、`native_final/result.json` 与运行日志。
