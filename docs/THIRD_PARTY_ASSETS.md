# 第三方素材清单（Third-Party Assets）

本项目引入的第三方素材按许可要求在此统一登记。使用时必须保留作者署名与来源链接；禁止将素材包本身作为资源包再次销售或重新分发。

## Pixel Art Top Down - Basic

| 项目 | 内容 |
|---|---|
| 素材名称 | Pixel Art Top Down - Basic v1.2.3 |
| 作者 | Cainos |
| 正式来源 | https://cainos.itch.io/pixel-art-top-down-basic |
| 素材类型 | 32×32 Top-down 像素地面、墙体、结构与场景道具 |
| 项目内用途 | 剧情梦境大/中/小房间的地面、墙体、门洞与装饰 |
| 正式剧情房间路径 | `res://art/Dream/Texture/` |
| 旧导入副本（保留兼容） | `res://art/Dream/Cainos Pixel Art Top Down Basic/Texture/` |

### 许可摘要

- 允许用于免费及商业项目，也允许按项目需要修改。
- 作者署名不是强制要求，但作者表示欢迎署名；本项目仍保留本条记录。
- 禁止将素材包本身重新分发或转售。
- 剧情房间运行时只从 `res://art/Dream/Texture/` 读取地面、墙、结构和带阴影道具图集；旧导入副本不删除，以免历史场景丢失引用。

### 署名文本（Credits 使用）

```text
Pixel Art Top Down - Basic v1.2.3
Graphics by Cainos
https://cainos.itch.io/pixel-art-top-down-basic
```

## Crawling Depths

| 项目 | 内容 |
|---|---|
| 素材名称 | Crawling Depths |
| 作者 | pingupollas |
| 来源页面 | https://pingupollas.itch.io/crawling-depths |
| 作者主页 | https://pingupollas.itch.io/ |
| 素材类型 | 16×16 Top-down 像素恐怖 / 克苏鲁风 Tilemap / Tileset |
| 项目内用途 | Dream 连续地牢的地面、裂纹、墙体与环境装饰；正式场景直接使用本目录的 `crawling_depths_tileset.tres` |
| 项目内资源路径 | `res://assets/art/dream/crawling_depths/`（tiles.png、cliff.png、cracks.png、eye_sheet.png、mouth_sheet.png、tentacle_sheet.png、vein_sheet.png、floating_rock_sheet.png、little_eyes_sheet.png、statue_a/b/c.png、urn_1/2.png、vein_column_short/tall.png、book_altar.png） |
| TileSet 资源 | `res://assets/art/dream/crawling_depths/crawling_depths_tileset.tres`（16×16 切分，无 Margin/Separation，Nearest 过滤、无 Mipmaps） |

### 许可摘要

- **允许**：个人项目使用、商业项目使用、对素材进行修改。
- **必须**：给作者署名，署名中包含作者名 `pingupollas`，并附作者的 Itch.io 页面链接。
- **禁止**：将素材包本身作为资源包再次销售；将素材包本身重新分发。

### 署名文本（Credits 使用）

```text
Crawling Depths
Graphics by pingupollas
https://pingupollas.itch.io/

Asset:
https://pingupollas.itch.io/crawling-depths
```

### 使用位置

- 旧程序化大地图：`res://scenes/dream/dream_world.tscn` 的 `DreamMap` 节点组（填充脚本 `res://scripts/dream/dream_map_builder.gd`；正式剧情Room模式隐藏该节点）。
- `tentacle_sheet.png` 当前没有正式敌人场景引用，作为第三方素材包内容保留。
- 运行时代码只引用 `res://` 项目内路径，不引用任何网络 URL 或本机下载目录。

## Monster 怪物素材包（Slime / Flying eye / Mushroom / Mimic）

| 项目 | 内容 |
|---|---|
| 素材名称 | 通用像素怪物素材包（Slime、Flying eye、Mushroom、Mimic 等） |
| 作者 | 素材包内未附带署名文件 |
| 素材类型 | 横条等分序列帧 PNG（156²/150²/146² 画布） |
| 项目内用途 | 史莱姆（basic）、魔眼（correction_tape）、自爆蘑菇（alarm_clock）、宝箱怪（mailbox）的移动/攻击/死亡动画 |
| 项目内资源路径 | `res://art/Monster/Slime/`、`res://art/Monster/Flying eye/`、`res://art/Monster/Mushroom/`、`res://art/Monster/Mimic/` |

### 许可说明

- 该素材包目录内**未附带任何授权文件**，为用户直接提供并要求用于本项目怪物替换。
- 若后续对外发布，需要向素材提供方补充确认授权条款并在此登记。

## Huntress 2（精灵射手）

| 项目 | 内容 |
|---|---|
| 素材名称 | Huntress 2 |
| 素材类型 | 100² 横条等分序列帧 PNG（角色动作 + 箭矢） |
| 项目内用途 | 精灵射手（内部 ID 保留 stapler）的移动/射击/死亡动画 |
| 项目内资源路径 | `res://art/Monster/Huntress 2/Sprites/Character/` |

### 许可摘要

- 素材包内 `License.txt` 实测为 **CC-0（公共领域）**，无需署名即可商用与修改。
- 为稳妥起见仍在本文档登记来源：`res://art/Monster/Huntress 2/License.txt`。
