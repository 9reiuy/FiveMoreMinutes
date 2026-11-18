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

## 叉车驾驶音效（2026-11-17）

| 用途 / 资源 | 原素材与作者 | 来源 | 许可 |
|---|---|---|---|
| 开动及行驶 `sfx/forklift/motor.res` | Electric motor engine start stop — kentspublicdomain | https://freesound.org/people/kentspublicdomain/sounds/476943/ | CC0 1.0 |
| Shift 加速 `sfx/forklift/boost.res` | Engine Rev.wav — PieTheAnimator45 | https://freesound.org/people/PieTheAnimator45/sounds/608652/ | CC BY 4.0，必须保留作者、来源、许可及修改说明 |
| 手刹漂移 `sfx/forklift/skid.res` | tire_skid_02 — loganzsound | https://freesound.org/people/loganzsound/sounds/774265/ | CC0 1.0 |

三条均由用户选定的公开 HQ MP3 试听制作；运行时使用工程内独立音频资源，不读取下载目录或网络。
修改包含单声道 48 kHz 转换、裁切、短交叉淡化与电平调整；加速录音截取 3.9–6.9 秒并保持音高压缩至 0.75 秒。
完整来源、下载散列与署名见 `sfx/forklift/SOURCES.json` 和 `sfx/forklift/ATTRIBUTION.txt`。

发行时保留以下署名及链接：

```text
"Engine Rev.wav" by PieTheAnimator45 (Freesound), CC BY 4.0.
https://freesound.org/people/PieTheAnimator45/sounds/608652/
https://creativecommons.org/licenses/by/4.0/
Adapted for FiveMinuteMore: cropped, time compressed, faded and level adjusted.
```

## 爆炸、集装箱与六足机器人音效（2026-11-18）

| 用途 / 资源 | 原素材与作者 | 原始来源 |
|---|---|---|
| 爆炸 `sfx/combat_machinery/explosion.res` | Explosion, Short, Impact, Break gravel, reverb — julianmateo_ | https://freesound.org/people/julianmateo_/sounds/522696/ |
| 集装箱落地 `sfx/combat_machinery/container_impact.res` | Metal Impact Container 1 1.wav — Sheyvan / Philipp Grzemba | https://freesound.org/people/Sheyvan/sounds/569409/ |
| 六足落脚 `sfx/combat_machinery/crawler_step.res` | Big robot footstep — AudioPapkin | https://freesound.org/people/AudioPapkin/sounds/813056/ |
| 六足关节 `sfx/combat_machinery/crawler_mechanism.res` | Sound Design Elements-Robot mechanism-001 — AudioPapkin | https://freesound.org/people/AudioPapkin/sounds/813060/ |

四条均为 **CC0 1.0**，允许免费商用与修改，无强制署名要求。用户已确认选用。
由公开 HQ MP3 试听转为单声道 48 kHz PCM，去除直流偏置、整理峰值和淡化边缘；爆炸与落脚去掉前置等待，关节声制作短交叉淡化循环。
来源、下载散列、具体裁切位置和制作说明保存在 `sfx/combat_machinery/SOURCES.json` 与 `ATTRIBUTION.txt`。

## H06 关卡音效与快步（2026-11-19）

已选用 A–I 的钢板、吊具、斜轨平台、护盾、扫射和检修盖音效。平台运行段经过交叉淡化，随平台运动循环。

H06 当前的两条短脚步来自 Artem_Zaitsev 的 [Heavy Robot Footsteps](https://freesound.org/people/Artem_Zaitsev/sounds/837389/)，各保留 112 毫秒。

全部采用 CC0 1.0。作者、源页、下载散列及裁切位置见 [SOURCES.json](../sfx/h06/SOURCES.json)。
