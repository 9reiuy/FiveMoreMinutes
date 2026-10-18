# 非游戏软件目录与缓存核查 · 2026-10-13

本轮没有删除、搬移或修改目录。之前“保留开发工具及管理目录”的边界仍有效，需要明确调整范围后才能清理这类内容。

## 确认存在

| 目录 | 内容 | 结论 |
| --- | --- | --- |
| `.workbuddy` | 2 个软件记录/记忆文件，31,148 字节 | Workbuddy 的资料，不是游戏资源；也不是纯缓存 |
| `.runtime/media_tools` | imageio_ffmpeg Python 包、转换程序及缓存；21 文件，87,727,397 字节 | 外部视频制作工具，不是游戏运行资源；之前作为开发工具保留 |
| `.runtime/media_tools/imageio_ffmpeg/__pycache__` 及其 binaries 子目录中的同名缓存 | 6 个 Python 缓存文件，44,681 字节 | 纯软件缓存 |
| `scripts/audio/__pycache__` | 1 个 Python 缓存文件，63,147 字节 | 纯软件缓存，不是游戏源脚本 |
| `.codex-worktrees`、`.codex-worktrees-real`、`5min more/.codex-worktrees` | corridor、door、pillar 等工作树；其中还存在 repo.git | 可能有未合并工作/仓库，不能按缓存删除 |
| `.codex` | 当前为空 | 开发管理目录，不作为游戏资源 |

## 应区分保留

- `.godot` 是本项目的引擎导入与编辑器数据；不属于无关软件缓存。清掉正在使用的导入缓存可能影响直接运行。
- `.runtime/appdata/Godot` 当前 115 个文件、442,692,269 字节，含导出模板、编辑器配置和 app_userdata，不能整目录当无用缓存删除。
- `.runtime/localappdata/Godot/editor_doc_cache-4.7.res` 是 Godot 文档缓存，3,269,297 字节；可单独讨论是否清理。
- `Godot/app_userdata` 含游戏设置与日志，不是另一款游戏；保留设置。
- `.runtime/kenney_furniture_20260921` 是供应商家具原始包（含许可证），不是软件缓存。
- `.runtime/nyangeon_reference` 是参考调查脚本/日志，不是 Enter-The-Nyangeon 的完整游戏目录。
- `.runtime/face_art` 是预览截图与动画输出，不能称为其他软件缓存。

## 核查范围与限制

已按目录元数据遍历除版本库和工作树之外的项目目录，共检查 23,730 个文件。未跟随符号链接，未读取存档内容，也未扫描/操作 Git 内部及工作树正文。可见管理工作树依旧存在，因此不能声称“目录里已经没有其他软件相关目录”。

当前未发现常见 node_modules、venv、pip/npm、浏览器 Cache/Code Cache/GPUCache 等目录；仅表示本轮所扫范围内未发现这些名称，不表示任何未知软件都不可能有自定义缓存。

后续建议：清理明确 Python 缓存；另行确认是否移除 Workbuddy 历史和本地视频工具。Git/工作树、游戏存档、当前 Godot 导入数据及原稿仍应保留，除非有具体处理方案。详细元数据见 `foreign-directory-audit-2026-10-13.json`。
