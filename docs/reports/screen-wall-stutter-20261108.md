# 试玩窗口整机卡顿修复 · 2026-11-08

原试玩入口 `tools/preview_screen_wall.cmd` 已改用 ANGLE / Direct3D 11 的 Windows 呈现路径，仍使用 Compatibility 渲染器。用户在该入口实际重开后确认：“整台电脑已恢复流畅”。对应运行 PID 为 98132，正常退出 0。

这是这台电脑、当前试玩入口的修复结果，不是对所有显卡驱动或全游戏性能的认证。

## 最终实现

- `tools/launch_screen_wall.ps1` 启动正式 `scenes/app/main.tscn`，参数为 `--rendering-method gl_compatibility --rendering-driver opengl3_angle --max-fps 60 --disable-vsync`，窗口仍为 1280×720。游戏场景沿用同一进程和驱动。
- 保留 `FrameBudget` 的前台 60 / 后台 30，不改画质、灯光、角色、电视模型或 CRT 效果。
- 启动器每 250 ms 检查自己创建的游戏进程并保持 BelowNormal。实际记录表明，单次设置启动优先级不够：原生进程在启动后会出现 AboveNormal，现由启动器再次纠正。这里不推断具体是哪一层提升了优先级。
- 按项目与资料目录命名的互斥量防止同一试玩入口重复打开；关闭游戏时释放。启动器不枚举或调整其他游戏进程。
- 正常试玩继续使用 `.runtime/screen_wall_play` 的既有玩家资料和音量。诊断参数只接受独立 `.runtime` 目录，拒绝正常主菜单及教程资料目录及其子目录，测试使用预先静音的私有资料。
- `Run_Tutorial.cmd` 的普通启动复用相同的优先级、限帧与防重复保护；它保留原来的 Forward+ 项目默认渲染路径，未冒充完成其 ANGLE 视觉验收。其 Validate / Capture / ColourCheck 分支保留。

ANGLE 的 Windows 实现明确选择 D3D11；同时本机实际启动日志确认使用 NVIDIA RTX 5070 Ti 的 Direct3D11 设备。[Godot 官方实现](https://github.com/godotengine/godot/blob/master/platform/windows/gl_manager_windows_angle.cpp)

## 验证与范围

| 检查 | 结果 | 证据 |
|---|---|---|
| 空白私有项目的 ANGLE 后端准入，无游戏内容，320×180 / 5 FPS / Dummy | PID 43620，退出 0，实际 driver=opengl3_angle | `driver_admission/engine.log`、`camera.png` |
| 实际主菜单与设置 Camera，1280×720 / 30 FPS / Dummy 私有静音 | PID 98320，11 项 / 0 失败，退出 0 | `angle_camera/result.json`、`engine.log`、`main_menu.png`、`settings.png` |
| 普通启动优先级与重复启动保护 | PID 74556，BelowNormal 持续有效，第二次启动未生成新游戏实例，退出 0 | `actual_launcher_result.json` |
| 修复后玩家实际启动 | PID 98132，ANGLE / Direct3D11，BelowNormal，退出 0，用户确认整机流畅 | `accepted_play_launch.json`、`accepted_play_engine.log` |
| 原 UI、模型、角色、主 CRT shader、限帧脚本保护 | 与上一轮 20261108 验证哈希一致 | `validation.json` |

本轮最终 Camera 检查覆盖 12 台电视、已批准角色、设置页下落结束、覆盖时停绘、品质单份文字和 ESC 返回。它没有测整场战斗 P95，也没有声称所有关卡稳定 60 FPS。

## 调查中排除的证据

- 仅降低优先级，以及仅关闭 VSync，用户均反馈未解决，因此不把它们单独列为已验证的根因修复。
- Windows 活动显示路径为约 165 / 60 / 60 Hz；QueryDisplayConfig 返回 DRR 均关闭。用户确认本机显示器直接操作，不使用远程串流。
- 旧教程进程的内部记录可见约 60 次 / 秒的处理与绘制回调，但这不证明最终屏幕每秒展示 60 张新图。
- 系统级 PresentMon ETW 因管理员权限限制未形成有效记录；没有改变用户组或系统权限。
- 已安装 NVIDIA 帧数据示例曾用于短时读取。用户反馈采集期间整机卡顿后，本轮采集全部结束，不再用于后续确认。中途窗口 PID 已改变，旧目标的前台标记无效；OpenGL 的显示字段还出现零值和越界值，因此这些记录不用于宣称实际显示帧率或认定根因。
- 最终用户验证没有运行上述全机帧数据采集器。只切换原入口的呈现后端后用户确认恢复，因此修复结论限定在这条入口和本机表现。

证据位于 `.runtime/screen_wall_stutter_20261108/`。此次未提交、合并、重置或清理共享工作区；其他任务对教程和环境的现有修改保留。
