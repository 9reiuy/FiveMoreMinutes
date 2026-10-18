# 重复导出图清理结果 · 2026-10-13

用户要求继续清理后，复查确认 Godot 已退出；重新核对候选文件大小/修改时间，且两张候选与保留图的 SHA-256 完全一致。

- 永久删除 `art/Badroom/button.png`、`art/ui_imported/button_panel.png` 和对应 `.import`：4 文件，68,227 字节。
- 永久删除随后产生的 4 个孤立导入缓存：22,590 字节。
- 合计 8 个文件、90,817 字节，无失败、无残留；无备份，不使用回收站。
- 保留 `art/Badroom/talk.png`、`art/ui_imported/talk_panel.png`，图片原始内容仍存在。
- 静态缺失引用仍为既有 315 条，新增 0；主入口及受保护资源仍存在。未启动游戏回归测试。
- 旧工作树和供应商素材原稿未删除。三处旧工作树仍待具体授权，不宣告整个清理目标完成。

证据：`exact-duplicate-deletion-summary-2026-10-13.json`、`duplicate-cache-deletion-summary-2026-10-13.json`、`verification-2026-10-12.json`。
