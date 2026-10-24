# 交互缓存 freed-object 修复 · 2026-10-22

## 依据

用户实际 `godot.log` 指向 `DreamInteractionResolver.update_target` 原第 41 行：`candidate_variant as Node2D`。物品销毁后，候选组快照仍保留旧对象；原代码先进行类型转换、后验证对象有效性，因此验证来不及执行。此问题不来自敌人描边或挥动特效着色器。

修改前，新增的同帧缓存回归测试复现相同 `Trying to cast a freed object` 和原第 41 行调用栈；15 项检查中 5 项失败。

## 修复范围

- 在原始 Variant 转换为 Node2D 前检查对象有效性；跳过等待删除、已脱离场景树或随旧楼层禁用的候选对象。
- 查询可用性与设置高亮后重新检查生命周期，避免回调删除物品后继续访问。临时最近候选若被后续回调销毁，不再通过强类型参数传入。
- `clear_target` 同时清空候选组缓存；重新配置交互时立即使用新组，不沿用上一帧旧列表。
- 正式随机楼层调用方对隔帧暂存的目标先验证、再赋值或访问；失效目标立即触发重选。
- 楼层布局重建、暂存和失败回滚前清空双方交互目标缓存。
- 不改变拾取距离、最近目标优先级、自动收纳、主动换枪、伤害或射速。

## 静音验证

使用 Dummy 音频及 `.runtime` 隔离用户目录，未关闭用户编辑器或正在运行的用户游戏。

| 检查 | 结果 |
| --- | --- |
| `interaction_freed_target_test` | 15 项通过；同帧销毁、等待删除、重配组、旧楼层禁用、回滚恢复、脱树、回调删除、玩家销毁 |
| `interaction_freed_world_test` | 29 项通过；真实武器物品、三层重建、调用方旧缓存、主动换枪、自动收纳、失败回滚 |
| `compact_interaction_prompt_test` | 14 项通过 |
| `test_reception_interaction_range` | 全部通过 |
| `random_floor_lifecycle_test` | 729 项通过 |
| `office_weapon_swap_speed_test` | 180 项通过 |
| 目标文件差异空白检查 | 通过 |

修复后上述运行中未再出现目标 freed-object 报错。个别测试退出仍有既有 ObjectDB / resources 清理警告，接待区仍有既有 UI anchors 警告；未将其混报为本轮修复或零警告。未进行长时间人工游玩验收。
