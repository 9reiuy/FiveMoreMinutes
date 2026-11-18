# Player portraits

本文件夹是主人公对话立绘的统一入口。使用用户提供的身体底图及六张表情差分，保留原色和原始透明度。

| 游戏可用图片 | 表情 |
| --- | --- |
| `player_normal.png` | 默认／闭嘴 |
| `player_mouth_open.png` | 张嘴状态 |
| `player_eyes_closed.png` | 闭眼 |
| `player_cat_eyes.png` | 猫眼 |
| `player_disbelief.png` | 难以置信 |
| `player_injured.png` | 受伤 |

`source/player_base.png` 对应原来的“无表情.png”，本身没有五官；六张原始透明差分位于 `source/expressions/`。原文件只改英文名称，SHA256 及原名记录在 `source/manifest.json`。`source/.gdignore` 防止身体及透明差分重复进入游戏纹理内存。

完整立绘由 `tools/build_player_portraits.gd` 在构建时叠合，统一移除空白画布，输出 1099×3335 的全身图片。所有图片使用相同裁切，不分别按各自表情包围盒缩放。对话使用 `scripts/ui/dialogue/player_portraits.gd` 的上半身区域 `(0, 0, 1099, 1752)`，不改变既有立绘显示框；全身图保留供以后使用。运行时不拼图、不扫描像素。

对话行使用 `expression` 选择上述英文表情名（去掉 `player_` 和 `.png`）。普通对话使用 `normal`。立绘只随表情状态切换，逐字显示和文字显示完成时均保持当前状态，不循环张嘴／闭嘴；`mouth_open` 也只作为明确指定的张嘴状态。未配置的表情回退到 `normal`。旧 `fear/panic` 对应 `disbelief`，`hurt/pain` 对应 `injured`。

重新生成：在工程根目录以本机 Godot 执行 `--headless --path . --script res://tools/build_player_portraits.gd`，然后导入生成的六张 PNG。原始文件无需调整位置或画布。
