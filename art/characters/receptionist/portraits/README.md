# 前台立绘

| 游戏用图 | 表情 | 原始差分 |
| --- | --- | --- |
| `receptionist_normal.png` | 正常 | `source/expressions/receptionist_normal.png` |
| `receptionist_talking.png` | 说话 | `source/expressions/receptionist_talking.png` |
| `receptionist_nervous.png` | 闭眼紧张 | `source/expressions/receptionist_nervous.png` |

身体底图在 `source/receptionist_base.png`。原始底图和差分都以原画尺寸保存在 `source/`，原名及 SHA256 见 `source/manifest.json`。

`tools/build_receptionist_portraits.gd` 将对应面部差分叠到底图上，按同一区域去掉外侧空白，生成 555×1796 的完整全身游戏用图。对话用 `scenes/ui/dialogue/receptionist_dialogue.tscn` 取上半身，三张图共用裁切区域。修改原图后，可从工程根目录用 Godot 运行 `--headless --path . --script res://tools/build_receptionist_portraits.gd`，再导入输出的 PNG。

大厅台词用 `expression` 指定 `normal`、`talking` 或 `nervous`。整句保持该表情，换到不同状态的台词时更新。默认状态为 `normal`。
