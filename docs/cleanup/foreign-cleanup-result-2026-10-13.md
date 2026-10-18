# 非游戏软件目录清理结果 · 2026-10-13

用户确认“全都移除”，按上一条询问明确的范围永久删除 Workbuddy 记录、本地 FFmpeg 工具及三处 Python 缓存；旧工作树仍按询问中的排除边界保留。

- 删除 `.workbuddy`、`.runtime/media_tools`、`scripts/audio/__pycache__`；后两项包含此前列出的三处 Python 缓存目录。
- 永久删除 24 个文件、9 个目录，87,821,692 字节（约 83.75 MiB）；错误 0，剩余目标根目录 0。目录仅在确认为空后删除，没有使用递归删除。
- 没有备份，不使用回收站。Workbuddy 历史和本地工具副本本轮不可恢复；Python 缓存可按需要重新生成。
- 保留 `.git`、Codex 管理工作树、Godot 导入数据、游戏设置、源码及原始素材。
- 重新执行元数据扫描，扫描范围内未发现前述 Python 缓存；版本库和工作树不遍历，因此不宣称项目内所有软件相关目录已经清空。
- 未启动游戏或压力测试。正式游戏的运行资源不在这批清单中。

详细证据见 `foreign-delete-2026-10-13.json`、`foreign-deletion-summary-2026-10-13.json` 和更新的 `foreign-directory-audit-2026-10-13.json`。
