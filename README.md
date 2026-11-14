# FiveMinuteMore

正在开发中的 Godot 俯视角动作游戏。本仓库是持续维护的游戏工程，包含代码、场景、美术、实际使用的音效和验证工具。

## 当前版本

| 分支 | 用途 |
|---|---|
| [`wip/linux-migrate-20261018`](https://github.com/9reiuy/FiveMoreMinutes/tree/wip/linux-migrate-20261018) | 当前开发版本，日常开发与同步从这里继续 |
| [`main`](https://github.com/9reiuy/FiveMoreMinutes/tree/main) | 保留的 v0.4.7 历史版本，代码停留在 2026 年 8 月 |

仓库默认分支指向当前开发版本。开发分支名称保留自早期迁移任务；当前 Windows 工程也使用这条分支。

## 运行

1. 使用 Godot 4.7 打开根目录的 `project.godot`，等待资源导入完成。
2. 按 F5 运行正式入口 `scenes/app/main.tscn`。
3. Windows 也可使用现有的 `tools/preview_screen_wall.cmd` 启动正式游戏。

统一使用 Forward+，当前 Windows 驱动为 Vulkan；内部游戏画面为 640×360，普通窗口为 1280×720。

## 工程目录

| 目录 | 内容 |
|---|---|
| `scenes/` | 正式入口、角色、关卡、界面和独立预览场景 |
| `scripts/` | 游戏逻辑、角色、战斗、表现与界面 |
| `shaders/` | 场景、角色、特效与界面着色器 |
| `art/`、`assets/`、`resources/` | 游戏美术和资源 |
| `sfx/` | 游戏音效及来源记录 |
| `data/` | 对话、配置与素材署名 |
| `tests/`、`tools/` | 验证、采集和启动工具 |
| `docs/` | 项目上下文、设计、测试说明与历史报告 |

## 开发资料

- [项目协作与美术规范](AGENTS.md)
- [当前项目上下文](docs/ai/PROJECT_CONTEXT.md)
- [独立测试场说明](docs/testing/TEST_LAB.md)
- [游戏效果术语库](GLOSSARY.md)
- [素材来源与署名](data/asset_attributions.txt)

`.godot/`、`.runtime/`、导出产物、凭据和本地原始音效库不纳入版本控制。报告中的 `.runtime/` 链接指向开发机本地证据，不随仓库克隆下载。各项素材的来源和署名记录随工程保留。
