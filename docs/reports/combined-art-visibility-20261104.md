# 美术与三维视野合并小样

后续墙顶锯齿、移动闪黑白和贴墙全黑已在独立小样修复，见[修复与最新验证](visibility-surface-fix-20261104.md)。下方保留本次初始合并记录。

统一启动入口：[Run_Purple_Sample.cmd](../../Run_Purple_Sample.cmd)。原 [Run_Visibility_Light_Sample.cmd](../../Run_Visibility_Light_Sample.cmd) 是兼容入口，两者使用同一份配置。此合并仅在独立小样中完成，正式游戏入口和渲染器设置未改动。

默认第 5 档、调色板开、640×360 开、三维墙体遮挡开。使用美术对话最新确认的室内暗色 `#191D2E` 和亮色 `#FFE1E8`；室外保留 `#05060A` 暗底与 `#9CAAD1` 细线。2／4 档保留原来的蓝紫和浓紫效果。原有角色在完整游戏镜头内约 32–33 个逻辑像素，橙血保持独立颜色。

![合并后的真实游戏镜头与操作栏](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/entry.png)

保留家具与门框细线、按铺装类型绘制的地板接缝、无接缝的独立地毯、室外主光和城市反光、实际窗洞投影及投影范围内的方点衰减、玩家和敌人投影。视野使用整层完整墙体的统一三维深度遮挡，门用当前实体网格，不改变这些美术和照明算法。

调色板与像素化是独立开关，切换 2／4／5 档保留选择。第 4 档标签改为“浓紫硬调”，实际分辨率由状态栏显示，避免关闭像素化后按钮仍宣称 640×360。F9 对照视野，F2 换房，F5 对照室内灯，F11 对照场景半调，F1 展开操作说明。

## 合并范围与协作复核

已与“5MinMore美术”会话核对并接收最终配色和美术文件；其完成实机配色检查后停止修改及 GPU 测试，本会话串行进行合并验证。美术会话只读复核了入口继承关系和本次实拍，未发现阻塞合并的美术或入口冲突。

- `scripts/preview/hellkind_purple_sample.gd`：统一三维视野、最新美术和默认开关；风格切换不重置分辨率选择。
- `scripts/preview/visibility_light_sample.gd`：保留兼容入口，去掉单独覆盖档位的逻辑。
- `tests/combined_art_visibility_test.gd`：从主入口默认配置执行实际 Camera 功能检查；复用独立三角形判定和原生门、血迹、破墙测试夹具。
- `tests/combined_art_visibility_performance_test.gd`：在合并版默认灯光和美术下采集相同移动、开门及原生混合战斗工作负载。
- `tools/validate_woo_shadow_sample.ps1`：新增 `-Profile Combined`，保留原三维视野基线入口和输出目录。
- 性能脚本的退出改用帧末释放；这没有解决既有的灯光资源清理报错，见下文。

本次未重写美术对话的配色、半调、玻璃、接触阴影、角色或灯光文件。旧美术测试 `tests/hellkind_purple_sample_test.gd` 仍包含已移除档位及旧默认值，仅属历史套件，不作为这次合并的验收入口。两份旧说明已同步当前启动方式，并将旧性能数据标明为历史基线。

## 实际 Camera 功能结果

Godot 4.7.1 / Forward+ / RTX 5070 Ti。功能运行 `20261104-041641`：**70 项通过，0 失败，运行错误日志为空，302 个受审计共享源文件在运行期间无变化**。

- 主入口无需测试脚本覆盖配置，直接进入第 5 档、640×360、最新调色板和三维视野。
- 四房间、三个高度共 768 个样本，GPU 遮挡与独立源三角形视线判定一致。
- 四个房间的实际像素均检出已确认的 `#191D2E` 与 `#FFE1E8`。
- 原生可见血迹增加 746 个橙色像素。墙后新增的 1,151 个血迹像素全部被遮住，泄漏为 0；没有被重新填成室内浅粉或深蓝灰。
- 验证了真实门旋转、真实破墙、输入驱动行走、四房间切换、两种分辨率、三种美术档位、独立开关、重建和退出。
- 破墙后可视范围更新 CPU 为 1.422 ms，仅指视野更新，不是整帧或 GPU 耗时。

[功能结果](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/result.json) · [功能日志](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/Functional-20261104-041641.stdout.txt) · [源文件审计](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/Functional-20261104-041641.audit.json)

[房间视野开启](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/room_1_on.png) · [同机位关闭](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/room_1_off.png) · [原生分辨率对照](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/native_resolution.png) · [浓紫档](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/style_4.png) · [墙后橙血被遮挡](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/behind_wall_blood_volume.png)

## 帧耗时诊断与未完成项

**稳定 60 帧未通过。** 以下是合并版、640×360、最新半调配色、原生内容的实机记录。关闭垂直同步和帧率上限测量余量；采样中没有截图、磁盘导出或删除尖峰。数据是相邻帧的实际时间间隔，不是 GPU 专项计时。

延迟释放退出后的复测 `20261104-042106`：

| 负载 | 帧数 | P50 ms | P95 ms | P99 ms | 最大 ms | 超过 16.667 ms |
|---|---:|---:|---:|---:|---:|---:|
| 静止 | 2456 | 2.335 | 3.064 | 3.506 | 4.354 | 0 |
| 四房间移动 | 5895 | 2.573 | 3.742 | 4.297 | 43.189 | 2 |
| 开门 | 2599 | 2.998 | 4.025 | 4.706 | 5.772 | 0 |
| 混合战斗 | 2162 | 8.187 | 14.522 | 20.381 | 38.387 | 49 |

首次合并测量的混合战斗峰值为 143.001 ms，记录仍保留；不能用复测较低的峰值宣称已经稳定。两次性能运行都触发了既有的 `indexing did not unpair geometries from light` 清理报错。帧末释放仍会复现，说明不是仅把即时释放改为延迟释放就能解决。功能检查中的普通重建与退出无报错，但压力路径还没有通过。因此性能表属于诊断证据，不能作为干净的 60 帧验收，也不能推广为正式全游戏结果。

[复测原始统计](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/performance/summary.json) · [首次统计](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/performance/before_deferred_cleanup.json) · [复测错误日志](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/Performance-20261104-042106.stderr.txt)

美术对话提到的窗光直边沿用原来的实际窗洞投影和范围内方点衰减，本次合并没有重新设计其边缘。继续由美术方向单独调整，避免在合并中擅改已确认的光照范围。

验证命令：`tools/validate_woo_shadow_sample.ps1 -Profile Combined -Mode Functional`，性能诊断使用 `-Mode Performance`。两者均不修改正式存档，运行期间不关闭用户进程。
