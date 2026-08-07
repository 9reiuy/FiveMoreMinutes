# 怪物素材索引（Asset Index）

本表记录每种梦境敌人实际使用的素材目录与序列帧文件。帧数均为对 PNG 横条等分切分后的**实测值**（无头脚本逐张测量，不依赖文件名）。所有敌人为 AnimatedSprite2D + SpriteFrames 真实序列帧；朝向统一用 `flip_h`（朝右为默认），不做上下翻转。

## 敌人 → 素材映射

| 显示名称 | 内部 ID（保留） | 素材目录 | 画布 |
|---|---|---|---|
| 史莱姆 | `basic` | `res://art/Monster/Slime/` | 156×156 |
| 魔眼 | `correction_tape` | `res://art/Monster/Flying eye/` | 150×150 |
| 精灵射手 | `stapler` | `res://art/Monster/Huntress 2/Sprites/Character/` | 100×100 |
| 自爆蘑菇 | `alarm_clock` | `res://art/Monster/Mushroom/` | 150×150 |
| 宝箱怪 | `mailbox` | `res://art/Monster/Mimic/` | 146×146 |
| 触手怪 | `tentacle` | `res://assets/art/dream/crawling_depths/tentacle_sheet.png`（地图装饰已禁用该素材，仅触手怪敌人使用） | 40×64（每帧） |
| 精英魔眼（精英，internal_id 保留 `large_correction_tape`） | `large_correction_tape` | `res://art/Monster/Flying eye/`（与普通魔眼同一素材包，完整动画接入） | 150×150 |

## 动画使用明细

场景内动画名沿用旧名以最小化脚本改动，帧来源标注为素材文件内的实际动画。

| 敌人 | 场景文件 | 移动动画 | 攻击/蓄力动画 | 死亡动画 |
|---|---|---|---|---|
| 史莱姆 | `scenes/entities/basic_enemy.tscn` | `walk` ← Slime/walk.png（6帧） | — | `death` ← Slime/death.png（11帧，非循环） |
| 魔眼 | `scenes/entities/correction_tape_enemy.tscn` | `walk` ← Flight.png（8帧） | `charge` ← Attack.png（8帧，循环） | `death` ← Death.png（4帧，非循环） |
| 精灵射手 | `scenes/entities/stapler_enemy.tscn` | `walk` ← Run.png（8帧） | `attack_prepare` ← Attack.png（6帧，非循环，第 3 帧起发射订书钉，帧号由 `huntress_shoot_projectile_frame` 配置） | `death` ← Death.png（10帧，非循环） |
| 自爆蘑菇 | `scenes/entities/alarm_clock_enemy.tscn` | `walk` ← Run.png（8帧） | `charge` ← Attack.png（8帧，循环） | `death_delay` ← Death.png（4帧，非循环，融入原死亡→爆炸流程），`explode` ← Death.png 末帧单帧 |
| 宝箱怪 | `scenes/entities/mailbox_enemy.tscn` | `walk` ← Mimic/walk.png（6帧） | `slam_charge` ← attack_1.png 第0-4帧（循环），`slam` ← attack_1.png 第5-13帧（非循环） | `death` ← Mimic/death.png（6帧，非循环） |
| 触手怪 | `scenes/entities/tentacle_enemy.tscn` | `idle` ← tentacle_sheet.png（6帧，循环） | —（不移动，仅接触伤害） | 无死亡帧：禁用碰撞后淡出 0.5s |
| 精英魔眼 | `scenes/entities/large_correction_tape_enemy.tscn` | `walk` ← Flying eye/Flight.png（8帧，@9fps） | `charge` ← Flying eye/Attack.png（8帧，循环，@7fps） | `death` ← Flying eye/Death.png（4帧，非循环，@6fps，接入基类死亡序列） |

## 动画帧率配置（`scripts/data/demo_config.gd`）

| 配置项 | 默认值 | 作用 |
|---|---|---|
| `slime_move_fps` / `slime_death_fps` | 7 / 9 | 史莱姆 walk / death |
| `flying_eye_move_fps` / `flying_eye_death_fps` | 9 / 6 | 魔眼 walk / death |
| `huntress_move_fps` / `huntress_shoot_fps` / `huntress_death_fps` | 10 / 12 / 8 | 精灵射手 walk / attack_prepare / death |
| `mushroom_move_fps` / `mushroom_death_fps` | 8 / 4 | 自爆蘑菇 walk+charge / death_delay |
| `mimic_move_fps` / `mimic_death_fps` | 6 / 7 | 宝箱怪 walk+slam_charge+slam / death |
| `tentacle_idle_fps` | 3 | 触手怪 idle |
| `huntress_shoot_projectile_frame` | 3 | 精灵射手攻击序列中发射箭矢的帧门槛（弓弦释放帧），攻击前由 `huntress_attack_stop_before_shot` 停步 |
| `flying_eye_move_fps` / `flying_eye_death_fps` | 9 / 6 | 精英魔眼换 Flying Eye 后与普通魔眼共用 walk/death 帧率 |

视觉缩放统一走配置（不逐帧改 scale，保存绝对最终值，运行时不二次乘倍率）：`slime_visual_scale=0.60`、`flying_eye_visual_scale=0.76`、`huntress_visual_scale=1.02`、`mushroom_visual_scale=0.96`（基于上一版 0.48 ×2，只乘一次）、`mimic_visual_scale=1.68`、`tentacle_visual_scale=1.0`（触手怪单独 ×2，旧 0.5）；精英魔眼使用独立 `large_correction_visual_scale=1.0`（Flying Eye 素材原始尺寸，碰撞体 CircleShape2D r14）。素材保持 Nearest 过滤、无 Mipmaps，不重采样原 PNG。

碰撞体按放大后新视觉的“身体核心”单独适配（不机械×4，弓/翅膀/触角/透明区不计入，均为固定 CircleShape2D）：史莱姆 r18@(0,10)、魔眼 r13@原点、精灵射手 r14@(0,6)、自爆蘑菇 r11@(0,4)（爆炸半径不随 Sprite 放大）、宝箱怪 r46@(0,10)、触手怪 r13@(0,-6)（不随触须摆动）、精英魔眼 r14@原点。伤害数字锚点由 `basic_enemy.gd get_damage_number_offset()` 按帧高×视觉缩放自动计算；EXP 从敌人锚点附近掉落；自动瞄准/描边仍贴合 Sprite Alpha。

拾取物视觉（非敌人）：经验/红心使用 `res://art/icon/EXP/` 序列帧（循环、Nearest、按帧居中防抖）：`Blue_EXP.png` 5帧（10×9 @ x=0/16/32/48/64）、`Purple_EXP.png` 6帧（10×9 @ x=0/16/32/48/64/81，所有正式紫色 EXP 统一复用）、`health.png` 6帧变宽红心（高13，宽 14/12/10/4/12/14）；`Red_EXP.png` 为红色宝石非红心，未使用。拾取数值/磁吸/碰撞半径不变。

## 素材包内未使用的序列帧（用途无法确定，未接入）

- Slime：idle.png（14帧）、attack.png（19帧）、hurt.png（3帧）
- Flying eye：Take Hit.png（4帧）
- Huntress 2：Idle.png（10帧）、Get Hit.png（3帧）、Fall.png（2帧）、Jump.png（2帧）、Arrow Move.png、Static.png
- Mushroom：Idle.png（4帧）、Attack.png 已用于 charge；Take Hit.png（4帧）
- Mimic：Idle_closed.png、idle_open.png（各单帧）、opening.png（6帧）、idle_transformed.png（9帧）、transform.png（7帧）、attack_2.png（13帧）、hurt.png（3帧）
- 未映射的整包目录：`art/Monster/Bat/`、`art/Monster/Goblin/`、`art/Monster/Rat/`、`art/Monster/Skeleton/`
