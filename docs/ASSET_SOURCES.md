# 素材来源与授权

## 缝合像素字体（Fusion Pixel Font）

- 项目路径：`res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf`
- 上游项目：https://github.com/TakWolf/fusion-pixel-font
- 发布版本：`2026.07.20`
- 发布包：`fusion-pixel-font-12px-proportional-ttf-v2026.07.20.zip`
- 授权：SIL Open Font License 1.1
- 授权文件：`res://assets/fonts/fusion_pixel/OFL.txt`
- 用途：开场、角色对话、结算、手机以及常规UI的统一中文像素字体。

## 本次生成的原创占位像素素材

- 玩家图集（当前运行）：`res://assets/characters/player/pix_chr_atlas.png`（140×200、单元 28×50、4 行×5 帧；每行第 1 帧=该方向静止，第 2—5 帧=走路步态；行向 row0=前/row1=左/row2=后/row3=右）。
- 来源：以用户自有并更新的美术 `res://art/Chr/Pix_chr.png`（1429×1254）为源，项目内脚本程序化归一重建（统一 Canvas、水平居中+底线对齐、最近邻缩放到 48px 内容高、每帧四周 1px 透明 padding 供 1px 描边采样），未使用外部生成工具或第三方素材。
- 旧 `player_sprite_atlas.png` 为早期占位，已不被运行场景引用。
- 基础敌人方向图集：`res://assets/enemies/basic/basic_enemy_directional_atlas.png`
- 来源：OpenAI ImageGen，根据项目自有 `res://art/Chr/chr.png` 与既有敌人占位图集生成并整理。
- 用途：开发阶段角色和基础敌人的四方向动画占位资源。
- 说明：没有引用网页素材或未知版权第三方图片。

## 程序化音效占位

- 恢复音效 `&"heal"`：`sfx_manager.gd _create_placeholder_stream()` 程序化生成的升调正向 blip（0.16s，420→880Hz），走 Characters 总线，音量 `sfx_heal_volume_db`。
- 说明：项目 `res://sfx/` 内暂无现成 heal/回复类音效文件，按工单规则不擅自下载版权不明素材，先以程序化占位并保留资源槽；后续人工替换为 `res://sfx/heal.wav` 时仅需将其移入 STREAMS 并删除 GENERATED_EVENTS 条目。

## 手机应用像素图标

- `res://assets/ui/icons/online_icon.png`
- `res://assets/ui/icons/somnia_icon.png`
- `res://assets/ui/icons/delivery_icon.png`
- `res://assets/ui/icons/settings_icon.png`
- 来源：项目内程序化绘制的原创占位图标（System.Drawing 按 16×16 像素地图逐像素绘制后 2× 最近邻放大为 32×32 透明 PNG），四张共用同一画布/边距/像素密度。
- 风格基准：速联跑腿（delivery，卡其纸箱 + 钢蓝风翼 + 琥珀胶带 + 红色订单标签）为母版；统一受限调色板（深轮廓 #1a202e / 钢蓝 #5b83a8 / 深板 #22344a / 亮色 #dfe9f2 / 琥珀 #d9a441 / 卡其 #b89a5f / 冷蓝 #9fc0e8），Y2K 旧手机感。
- 图案语义：ONLINE = 像素聊天气泡 + 琥珀状态点；SOMNIA = 冷色新月 + 星点；设置 = 钢蓝像素齿轮。
- 说明：四张图标均位于项目内部，不引用网页路径或第三方素材。

## 第一人称褪黑素右手占位帧

- `res://assets/art/first_person/melatonin/right_hand_open.png`
- `res://assets/art/first_person/melatonin/right_hand_grab.png`
- `res://assets/art/first_person/melatonin/right_hand_throw.png`
- 来源：OpenAI ImageGen生成的项目原创占位素材，经纯色背景移除、独立药丸分离和最近邻缩放整理为`256×256 px`透明PNG。
- 风格：低饱和冷蓝、第一人称像素心理恐怖；明确采用右手姿势。
- 用途：伸手、握瓶摇晃和从瓶口甩药三个可替换动画阶段。
- 说明：属于开发阶段占位美术，不是最终角色手部资源；没有使用第三方或授权不明素材。
# V0.3 临时原创像素素材

以下素材由本项目本次开发过程中使用 OpenAI 内置图像生成工具生成，再通过纯色键控移除背景并按固定画布切分。它们是可替换的临时原创占位美术，不是最终美术：

- `res://assets/art/first_person/melatonin/female_right_hand_open.png`
- `res://assets/art/first_person/melatonin/female_right_hand_grab.png`
- `res://assets/art/first_person/melatonin/female_right_hand_shake.png`
- `res://assets/art/first_person/melatonin/female_right_hand_throw.png`
- `res://assets/art/first_person/melatonin/female_left_palm_open.png`
- `res://assets/enemies/alarm_clock/*.png`
- `res://assets/enemies/mailbox/*.png`

生成约束：冷灰蓝心理恐怖像素风、无文字水印、无第三方版权素材；透明 PNG、最近邻显示。后续最终美术必须维持相同画布尺寸和基准点，避免动画中体型跳变。
