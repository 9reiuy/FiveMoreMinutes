# 命中反馈显示池及渲染开销调查（2026-10-07）

## 范围与结论边界

仅复用命中反馈的被动显示载体。真实 CombatFeedbackEffect 仍逐次创建，实例身份、方向、死亡/普通命中类型、颜色、180/160 毫秒寿命及动画推进保持原路径。玩家、敌人、碰撞、伤害和 AI 不进入池。子弹连击特效也不借用这个池。

每层预热 18 个，空闲最多保留 48 个；溢出继续建立载体，不丢弃命中表现。成功跨层随该层销毁，失败回滚恢复原源对象；超过保留上限、旧载体已销毁时重新绑定独立载体。沿用已有显示桥的释放/暂停机制，不建立第二份特效计时。

本次是创建尖峰优化，不能视为持续战斗达成 60 FPS。RTX 5070 Ti 的数据不证明 RTX 3060/RX 6600 性能。

## 为什么不继续做人物或弹丸捕获图集

正式随机楼层，2560×1440 输出、640×360 世界视口，像素化及 Palette 1，预热 10 秒、采样 60 秒，全程静音。仅开启该分类的视口计时，避免大量初始化查询干扰。

- `.runtime/character_capture_render_profile.log`：人物身体 ALWAYS 部分 CPU 中位 0.192 ms；武器与附件合计最新绘制值中位 0.153 ms。首次日志的 `character_attachment` 包含武器与附件，随后分类代码已修正，不假称首次分开测量。DISABLED 类别的计时可能陈旧，不计作持续开销。
- `.runtime/firearm_capture_render_profile.log`：弹丸 ALWAYS CPU 中位 0.165 ms，枪口 ALWAYS 0.129 ms。空闲载体的历史计时不计作实时总量。
- 两次正常交火分别为 2/3 名实际射手、287/395 次敌方开火，P95 28.768/33.384 ms。两次负载不同，不能据此宣称性能变化。
- 世界绘制 CPU 中位分别 5.137/5.578 ms，明显高于这些捕获视口本身；各项 GPU/CPU 时间不是总帧时间，也不直接相加成帧耗时。

## 临时隔离实验

`tests/world_render_contribution_profile.gd` 仅在暂停后的同一场景暂时禁用特性并逐项恢复，不向正式游戏安装关闭阴影或描边的设置。

`.runtime/world_render_contribution_profile.log`，正常/移除家具描边/关闭灯阴影/关闭 Mesh 投影/恢复正常的固定画面中位帧耗时：3.500 / 3.713 / 2.362 / 3.959 / 3.553 ms。家具描边只减少 26 次绘制，未获得正向整体收益，保留。关灯阴影是定位线索，不是可交付优化；单纯降低 Mesh 投影数量亦无收益。暂停场景不能代替动态交火。

## 同源旧—新—旧显示验收

`tests/feedback_capture_reuse_profile.gd` 在同一正式摄像机、同一批 18 个真实源对象上比较旧载体/预热池/旧载体，每组 2 次预热后测 10 次。

- 候选复用：18 个载体创建中位 38.517 → 0.500 → 38.910 ms；`.runtime/feedback_capture_reuse_profile.log`。
- 正式池：37.528 → 0.592 → 38.405 ms；`.runtime/feedback_capture_production_profile.log`。仅计载体创建，不含真实源创建及渲染帧。
- 普通/死亡反馈、八方向覆盖；0 / 0.05 / 0.10 秒共六次画面对照完全一致，退出 0。
- 补充非空画面和捕获断言及像素化/Palette 组合，另行记录结果，不把先前缺少非空断言的日志当作这部分覆盖。

## 技术检查

- `.runtime/feedback_pool_random_floor_lifecycle_test.log`：522 项，0 失败，退出 0。三层清理、失败回滚、60 个反馈溢出恢复及原有弹丸/枪口/弹壳覆盖。
- `.runtime/feedback_pool_dream3d_combat_parity_test.log`：79 项，0 失败，退出 0。
- `.runtime/feedback_pool_projectile_history_trail_test.log`：19 项，0 失败，退出 0。
- `.runtime/feedback_pool_cutout_lifetime_test.log`：11 项，0 失败，退出 0。
- `.runtime/feedback_pool_parse.log`：编辑器解析退出 0，无 Parse Error/SCRIPT ERROR。证书及部分退出资源警告单列，不等同于断言失败。

此前走廊敌人通行的 45 项/7 失败基线未在本轮修复，不宣称全项目回归无失败。

## 补充画面与正常交火结果

- `.runtime/feedback_pool_display_0.log` 至 `_3.log`：像素化开/关 × Palette 开/关，四组全部退出 0。每组旧/新/旧各 18 个捕获均非空；正式摄像机画面确实包含反馈，不是三组均未显示。三个动画时刻的六次对照全部完全一致。
- `.runtime/feedback_pool_normal_combat_ab.log`，旧/新/旧中位 22.051 / 21.286 / 24.014 ms；P95 40.464 / 34.844 / 36.283 ms。敌方开火 396 / 418 / 398 次，玩家 411 / 416 / 412 次，实际敌方射手 3 / 4 / 3 名。总交火量匹配比例门槛通过（396/418 > 0.8），退出 0。
- 每十秒分段交火及死亡进程仍不同：首组前十秒敌方 90 次，新组 46 次，末段新组 96 次、旧组 41/56 次。粗粒度总量门槛通过不表示逐帧负载相同，不能将这些 P95 数字作为精确因果收益百分比，更不能宣称持续 60 FPS。保留本池的依据是同源创建尖峰下降、完全一致的画面及生命周期检查。
- 额外弹道测试第一次误用了不存在的 `tests/otxo_ballistics_regression_test.gd`，`.runtime/feedback_pool_ballistics.log` 退出 1；这是启动路径错误而非通过的测试，正确套件重新运行到 `.runtime/feedback_pool_office_ballistics.log`。
- 正确弹道套件：98 项，0 失败，退出 0。最终解析 `.runtime/feedback_pool_final_parse.log` 退出 0，无 Parse Error/SCRIPT ERROR；本轮范围差异检查退出 0。上述技术断言合计 729 项、0 失败，不包括已知走廊基线，也不等于手工动态画面验收。
