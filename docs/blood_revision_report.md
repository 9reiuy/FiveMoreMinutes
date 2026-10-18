# 血液表现与运行成本优化

## 完成的行为

- 办公室死亡血泊使用固定 1px 格逐步填充，不再整体放大血点；保留不规则轮廓和稀疏边缘溅点。增长仍持续 1.5 秒，先快后慢，像素颗粒大小保持一致。
- 附近已经落定的地面血迹按世界位置栅格对齐、合并及去重；接触处仅填补受地面与遮挡检查约束的单像素孔洞。墙面、门面、不同房间/楼层/世界和仍在飞行或增长的效果不参与合并。
- 合并复用已有呈现节点，必要时将捕获扩大到 224×224，并释放被吸收的源和呈现节点。索引使用弱引用及局部空间分桶；换楼层清空，电梯失败恢复后重建。
- 正式尸体落地后启动一次跟随渗血，以碰撞根节点的地面位置生成血点，不使用精灵的假高度。按真实游戏时间减弱，每帧最多两次脉冲，同时活动数量遵守原配置的 12 个上限。
- 现有独立残肢路径支持最多三次地面小滴血，每帧最多一次；没有新增碎尸触发路径。出血源失效、换楼层或停用时终止。
- 保留现有橙色血液、命中飞溅、墙门血迹、最近邻采样和真实 3D 遮挡。此前分析将代码名 BlackBloodEffect 误当成实际黑色，运行画面已确认并纠正。

## 性能边界

每个合并块上限 8192 个像素格；超出像素或捕获范围时保留独立血迹，不删除战斗痕迹。增长捕获最多 30Hz，内容没有变化时不重复刷新，落定后停止逐帧处理。血迹继续在本层永久保留，换层清除。

生成时对已证明安全的 16px 区块共享地面和凸包遮挡检查；凸包覆盖从源到区块的全部路径，包含角点射线之间的薄墙。受遮挡的边缘区块退回逐像素检查。配合径向分桶及剔除必定落在轮廓外的候选格，降低同步生成成本。

实际 GPU Camera 固定种子场景初版三次生成耗时 34.448 / 35.184 / 34.351ms；最终复测三次为 9.168 / 9.086 / 8.794ms。中位数从 34.448ms 降为 9.086ms，约降低 74%。这是本机固定场景的单次生成测量，不代表多敌人同时死亡时的最坏帧耗时或整体帧率提升。

本次实现局部像素生长与血迹融合，没有引入完整流体压力、速度场求解，也没有加入踩血脚印或屏幕血液覆盖。

## 验收

使用 Godot 4.7.1。血液验证覆盖逐格增长、被动呈现副本、去重与捕获边界、薄墙、跨房间排除、持久与换层清理、失败恢复、正式死亡落地接入、跟随移动、衰减和源数量限制。另回归了此前敌我射击、步枪扩散、霰弹即时开火和历史拖尾。

| 测试 | 结果 |
| --- | --- |
| blood_effect_otxo_test | 通过 |
| blood_pool_merge_test | 通过，包含实际薄墙碰撞 |
| blood_revision_integration_test | 24 项，0 失败 |
| corpse_follow_bleed_test | 通过 |
| corpse_follow_world_test | 23 项，0 失败 |
| office_blood_impact_test | 17 项，0 失败 |
| office_blood_cross_room_test | 11 项，0 失败 |
| corpse_floor_contact_test | 通过 |
| test_enemy_corpse_presentation | 通过 |
| firearm_shared_rules_test | 231 项，0 失败 |
| player_rifle_spread_test | 156 项，0 失败 |
| projectile_history_trail_test | 19 项，0 失败 |
| shotgun_direct_fire_test | 14 项，0 失败 |
| 3d_firearm_tuning_test | 103 项，0 失败 |
| firearm_impact_visual_test | 28 项，0 失败 |

GPU 验证包括血迹生命周期、尸体地面接触、血液颜色与正式 Camera 下的动态过程截图。飞溅、逐格增长、相邻血泊合并、家具遮挡和落定后静止均已检查。最终演示中一次命中与两个相距 `(8,4)` 像素的血泊原本产生三个地面源，落定合并后保留两个源，满足局部合并的像素及捕获预算。

环境提示仍存在：受限环境证书读取提示、绘图板配置读取提示；Headless 尸体测试会产生 dummy renderer material 提示，部分测试退出时有 BGM/资源引用提示。此前 3d_firearm_tuning 的 office_dither_lighting 延迟注册错误仍存在，断言通过。相关日志保留在 `.runtime/blood_revision_*`、`.runtime/blood_regression_*`，不将退出码通过表述为全工程日志无错误。

## 运行画面

正式游戏 Camera，现有调色与最近邻像素采样开启：

![命中飞溅](<E:/Agent/5MinuteMore/5min more/.runtime/blood_revision_impact.png>)

![血泊初始状态](<E:/Agent/5MinuteMore/5min more/.runtime/blood_revision_pool_initial.png>)

![血泊生长中](<E:/Agent/5MinuteMore/5min more/.runtime/blood_revision_pool_mid.png>)

![相邻血泊最终融合](<E:/Agent/5MinuteMore/5min more/.runtime/blood_revision_merge_final.png>)
