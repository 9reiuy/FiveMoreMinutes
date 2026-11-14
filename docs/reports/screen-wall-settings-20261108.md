# 电视设置页统一与文字重叠修复 · 2026-11-08

已接入正式入口 `scenes/app/main.tscn`，继续使用原试玩入口 `tools/preview_screen_wall.cmd`。

## 本次修改

- 修复“阴影品质”的重复文字：自定义 `〈 数值 〉` 下方的原生 OptionButton 文字被统一颜色函数重新显示。电视页着色现在跳过 OptionButton，原生悬停按下及轮廓文字也保持透明，仅显示自定义数值。
- 暂停页“继续游戏 / 设置 / 返回主菜单”悬停保留声音、选中框和背景色文字，取消白色雪花突发。显像管的日常微弱颗粒继续保留。
- 主菜单设置复用暂停页的单台电视、黑底、辉光、条纹滑条和快速下落回弹动画，直接打开设置内容。返回按钮标为“返回主菜单 / ESC”；游戏中保持“返回暂停界面 / ESC”。
- 主菜单设置打开时暂停背后的电视墙更新，关闭时恢复原有更新模式；不会暂停主菜单场景或触发全局游戏暂停。

实现集中在 `scripts/ui/screen_wall_main_menu.gd`、`screen_wall_pause_menu.gd`、`screen_wall_pause_view.gd`，以及 `scripts/ui/settings_panel.gd` 的两个文字透明状态。电视墙模型、角色姿势、主菜单屏幕着色器及音频资产未涉及此次修改。

## 验证

Godot 4.7.1 / Compatibility / RTX 5070 Ti / 原生 1280×720。测试在启动前准备私有静音配置，使用 Dummy 音频驱动；不修改正常玩家音量或 Windows 总音量。最小化测试窗口通过引擎实际 GPU 绘制采集 Camera 画面。

| 检查 | 结果 | 引擎 PID |
|---|---|---:|
| 暂停与设置 GameTestLab：三个悬停项、品质三次循环、实际拖条、进入设置扫描、重复打开、16:10 黑边输入 | 53 项 / 0 失败 | 88296 |
| 主菜单 GameTestLab：共用电视、下落回弹、返回按钮、ESC、背后停绘恢复、确认框及场景重载 | 61 项 / 0 失败 | 98340 |
| 正式入口：新游戏、私有保存、继续进入 3D、暂停返回、角色恢复、前台 60 / 后台 30 | 28 项 / 0 失败 | 62416 |

三轮无脚本错误。暂停与正式流程仍记录现有的 Control 对向锚点提示，以及 Compatibility 不支持 SSR 的环境提示；主菜单检查 stderr 为空。

本轮检查覆盖功能、生命周期与实际画面。强制绘制的检查数据不作为性能测量；没有重做或扩大 2026-11-07 的短时性能结论，也不声称全游戏性能认证。

证据目录：`.runtime/screen_wall_settings_20261108/`。

- 主菜单内的设置 Camera：`menu/settings_shared_television.png`
- 游戏暂停内的设置 Camera：`pause/pause_settings.png`
- 暂停无悬停雪花 Camera：`pause/pause_hover_clean.png`
- 结构结果：`menu/lab_result.json`、`pause/lab_result.json`、`formal/formal_result.json`
- 日志：`menu_final_*`、`pause_final_*`、`formal_final_*`
- 汇总及源文件 SHA-256：`validation.json`

本次未提交、合并或清理共享工作区；其他任务的未提交修改保留。
