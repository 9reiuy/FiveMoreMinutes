# 电视墙主菜单推广确认 · 2026-11-08

用户本轮确认“可以推广”，统一蓝色与随机信号切换已确认为正式主菜单默认效果。当前正式入口已经绑定同一套已验证实现，本轮核对并登记该基线，无需重新改写显示逻辑。

正式运行链为 `project.godot` 的 `scenes/app/main.tscn`，经 `scripts/app/main.gd` 加载 `scenes/ui/main_menu.tscn` 和 `screen_wall_main_menu.gd`；屏幕控制器为 `scripts/preview/screen_wall_display.gd`，材质为 `shaders/ui/screen_wall_crt.gdshader`。正式实现不依赖 `.runtime` 内的候选文件。Windows 导出预设采用 `all_resources`，其排除项不排除正式引用的电视墙、字体、角色或材质资源。

接受范围为：TV_04 统一蓝色、各屏独立随机频闪、人物画面完整隐去并露出选项、装饰屏雪花／彩条，以及原有眼睛跟踪、悬停输入和逐台关机。暂停与设置保持原清晰磷光样式。

原试玩入口仍是 `tools/preview_screen_wall.cmd`。沿用已解决本机卡顿的 ANGLE / Direct3D11、低优先级、防重复启动和60／30限帧；本轮未更改全局渲染配置、其他独立关卡或游戏数值。

推广核对时，实现哈希与 `.runtime/screen_wall_signal_20261108/validation.json` 一致；正式入口、菜单绑定及相关控制器也没有在最近一次实际运行回归后发生修改。沿用该轮150项功能检查、9项菜单性能条件检查及实际Camera证据，其中正式App生命周期为39项／0失败。故本轮没有重复运行GPU测试或全机采集，也没有新增性能认证结论。

当前确认快照保存在 `.runtime/screen_wall_signal_20261108/promotion/accepted.json`。这次只补充推广状态与项目上下文，未提交、合并、重置或清理共享工作区，现有其他任务修改保留。
