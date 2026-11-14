# 0-1 至 0-6 独立 Windows 试玩包

2026-11-11。任务范围：把已制作的六关导出为可在其他电脑运行的独立试玩程序，不发布到外部平台。

## 交付

- `build/FiveMinuteMore_Prologue_0-1_0-6_Windows_x64.zip`：235,629,192 字节（224.71 MiB）。
- SHA-256：`d2455e598e180094a0691097ca3203f7c5a967a267a1ab9246049ebf29383762`。
- 解压目录：`build/Prologue_0-1_0-6_Windows`；启动 `FiveMinuteMore_Prologue.exe`，EXE 和 PCK 同目录。
- 平台：Windows x86_64，Godot 4.7.1 release template，Forward+ / Vulkan。
- 包内附操作说明、引擎/字体/第三方资源许可与逐文件 SHA-256。没有私有测试设置或自动测试入口。

## 实现

`PrologueDemo.tscn` 包装现有六关连通显示与共享玩家。自定义导出特性 `prologue_demo` 选择独立入口及 `FiveMinuteMorePrologue` 设置目录。正式主场景仍为 `scenes/app/main.tscn`；已有共享工作树修改均保留。

独立入口隐藏调试性能面板，支持 Esc 暂停/设置/退出、F5 从 0-1 重开，以及最终台阶演出后的“再玩一次/退出试玩”。所有关卡使用既有清敌门禁、单向区域切换、旧区域卸载及列车流程。当前关闭全屏像素化的默认值照常生效。

资源闭包导出使用单独的 `PrologueWindows` preset。发现并修正 `door_b_grp.tscn` 的旧材质目录引用。首次导出时引擎默认临时目录安全写入失败，生成零字节启动配置；构建工具现使用项目内私有 TMP/TEMP，并逐项验证 PCK 内全部 MD5 和 ECFG 启动配置。

## 验证

证据目录：`.runtime/prologue_export_20261111/`。

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| `validation_headless_04` | 27/27，退出 0 | 真正 Windows release EXE，Dummy 音频；脚本驱动六关连通、车库撞车、仓库增援、站台演出与尾门上车、六车厢、Boss、到站/台阶、完成后重开 |
| `validation_native_01` | 37/37，退出 0 | 同一验证版 release EXE，Forward+/Vulkan，RTX 5070 Ti，1280×720，WASAPI 私有 Master=0；包括 10 张实际 Camera/UI 截图 |
| 最终 PCK | 2405 项 MD5 全通过 | `project.binary` 11226 字节；不含私有 QA 脚本及 `prologue_validation` 特性 |
| 验证版/最终版资源对比 | 2401 项相同 | 仅启动配置和 UID 缓存不同；最终版删除两项私有 QA 资源，没有其他内容差异。见 `export_parity.json` |
| ZIP 解压与清单 | 11 项文件校验通过 | 在含中文和空格的独立目录解压，逐文件核对大小与 SHA-256 |
| `final_unzipped_native` | 启动并退出 0 | 从解压目录运行最终 EXE；Forward+/Vulkan、原生分辨率、独立设置目录；录制/查看真实启动画面，不依赖工程目录 |

原生完整验证记录 2661 帧：P50 16.635 ms、P95 18.090 ms、P99 27.748 ms、最大 1134.817 ms。包含资源构造、加载与截图读回；这是有边界的脚本流程验证，不能推断其他硬件或完整战斗过程的稳定帧率。原始帧和阶段事件保存在 `validation_native_01/frames.csv` 与 `result.json`。

原生完整验证退出时有既有的 7 个 Texture RID 清理警告。最终包提前结束的短录屏在退出时有 ObjectDB/资源仍被引用的清理日志，退出码为 0；录屏用于启动与画面确认，不作为长时稳定性证明。未出现运行中的脚本、着色器或资源加载错误。导出编辑器扫描到项目内不随包分发的异常 WAV 测试样本，会留下其导入错误；这些文件不在最终 PCK 中。

全部自动测试在启动前准备私有静音配置，不改玩家保存设置与系统音量。最终 ZIP 不含测试静音配置。未进行其他电脑的实际硬件验证。

## 重建

1. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_prologue.ps1 -Validation`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/test_prologue_package.ps1 -Name <唯一证据目录名>`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_prologue.ps1`
4. `python tools/package_prologue.py`

默认模板路径在构建脚本参数中，可显式传入匹配的 Godot 4.7.1 Windows release template。原生验证须独占共享渲染锁。
