# 全关卡统一 Forward+ · 2026-11-08

正式工程 `E:\GameProjects\FiveMinuteMore` 的统一目标是用户明确要求的 **Forward+**。当前工程默认和普通启动入口均使用 Forward+；本机实际驱动为 Vulkan。早期 Compatibility / ANGLE 诊断属于已撤销方向，不作为本报告的最终验收依据。

## 实现

- `project.godot` 明确设置 `forward_plus`，Windows 使用 `vulkan`，原移动平台覆盖也改为 Forward+，禁止自动退回 OpenGL。保留640×360游戏画面、1280×720窗口、Nearest采样及既有像素表现。
- 主游戏、教程、0-1由同一启动器读取工程设置，移除主入口强制 Compatibility / ANGLE 的参数。0-1使用原数据目录，并接入既有进程优先级、限帧及重复启动保护；正常流程仍跳过教程，0-1没有加入正式流程。
- 紫色小样与海岸入口继承工程设置。两份独立历史灯光实验快照的启动器明确使用 Forward+ / Vulkan；渲染器对照工具默认Forward+，只在显式指定时运行其他后端。
- 性能记录读取 `RenderingServer` 的实际渲染器和驱动，避免原来的默认字符串误报。
- 增加真实Camera回归，覆盖主流程及10个当前独立场景。0-1旧测试改为检查近战武器类别，兼容已经存在的扳手／撬棍；不修改敌人装备和战斗数值。

混凝土材质、光源、角色受光材质、教程电视GPU帧复制、共享血迹着色器、主流程脚本和像素显示组件与本次开工备份散列一致，没有为切换渲染器改写这些内容。

## 实际验证

所有最终图形证据在 `.runtime/renderer_unify_20261108/forwardplus/`。引擎无渲染器命令行覆盖，实际日志为 `Vulkan 1.4.351 - Forward+`；测试启动前准备私有APPDATA／LOCALAPPDATA和Master=0，使用Dummy音频，窗口隐藏或最小化，GPU经共享锁串行运行。没有修改系统音量或玩家配置。

| 范围 | 结果 | 证据 |
| --- | --- | --- |
| 主菜单、卧室、接待区、真实乘梯、两层办公关卡、故事宿舍 | 33项通过；换层恢复操作，内部640×360保持 | `campaign01/result.json`，PID37204，退出0 |
| 0-1、教程、GameTestLab、紫色小样、视野小样、办公样板、演示房、夜海岸、红海岸、城市悬崖 | 10个独立场景、81项通过；全部实际Forward+ / Vulkan并输出Camera画面 | `scene-results.json`、各`scene_*/result.json`，全部退出0 |
| 教程原色、三台实时电视、红绿灯照亮角色、无光全黑 | 15项通过；电视使用`gpu_copy`，复制640×360；无光时持枪／空手Camera非黑像素均为0 | `colour01/native-colour.json`，PID35236，退出0 |
| 共享血迹稳定性 | 22项通过；0-1／正式办公层移动时细血点显隐跳变均为0，近处像素与遮挡保持 | `blood01/result.json`，PID100420，退出0 |
| 主游戏／教程／0-1正常启动路径 | 3个入口全部实际Forward+ / Vulkan、BelowNormal、正常退出 | `launcher-results.json`，PID99600／100292／97164，均退出0 |

本次另通过教程26项、共享教程结构49项、0-1战斗45项非图形检查。收尾核对发现并行会话给教程脚本增加了电视语音；差异只涉及音频播放和对话信号，没有改变摄像机、渲染配置或材质。本聊天保留该修改，并补跑当前源的26项教程检查，PID99836退出0。真实Camera截图检查不能替代完整游戏性能认证；本报告不声称全游戏稳定帧率或整机负载已通过。

## 诊断和工作树

主流程保留既有控件锚点警告；Forward+记录中还出现引擎的`OpVectorExtractDynamic is not supported yet`诊断。0-1独立入口退出时有资源清理诊断，实际场景检查和退出码通过。没有把这些日志写成“标准错误为空”，本次未扩展为无关的引擎／资源清理专项。

复用当前 `wip/linux-migrate-20261018` 工作树，未提交；保留用户和其他聊天已有修改。用户随后要求同步项目记忆，已将Forward+固定要求写入 `AGENTS.md` 与 `docs/ai/PROJECT_CONTEXT.md`，旧ANGLE决策明确标为历史。开工备份及散列在 `.runtime/renderer_unify_20261108/before/`、`source-before.json`。最终源核对和验证汇总见该任务目录的 `forwardplus/final/`。

驱动设置与实际驱动核对方式参见[Godot 4.7 ProjectSettings文档](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-rendering-rendering-device-driver-windows)。
