# 墙面、窗光与无人机探照灯修复

日期：2026-11-02。执行：Codex 当前会话本地实现，直接接入 `E:/GameProjects/FiveMinuteMore` 当前工作树；用户随后允许子智能体，增加 `lighting_code_review` 与 `lighting_evidence_review` 两项只读复核，没有并行修改文件、没有向外部 Gemini 服务委派资料、未提交 Git。工作树原有大量未提交改动均保留。本报告接续并修正此前灯光报告，旧报告的画面不代表本次状态。

## 结果与原因

1. **黑墙的主要原因是投影体与可见墙体错位。** 正式墙面已经从 0.5m 减薄至最多 0.25m，但隐藏的实体投影体仍保留旧厚度，可见面陷在遮光体内部。现在投影体采用完整、未剖切的批准墙体网格，厚度、窗洞和转角与可见墙面一致。游戏碰撞仍使用原来的 2D 权威数据，剖切不削弱完整墙体的阻光。
2. **竖直墙面缺少受光。** 保留原房型墙地贴图；正式房间原有弱补光移至室内中段高度、覆盖墙面，在原室内阴影预算中为当前房间保留一个名额，其他房间的反射补光隐藏。遮挡始终完整，只渐变光能；挂起恢复从零光能开始。快速 A-B-A 折返会恢复仍在淡出队列里的光源，不用等待旧迟滞结束。这是用于模拟灯具反射的真实局部 OmniLight，并非计算式 GI，也没有给墙体或家具添加自发光来提亮。
3. **窗户本地光原先被正式阴影模式统一关闭。** 现在每条连续窗带保留一个从室外朝室内投射的真实光源，并经过窗框、完整墙体与家具遮挡。共享方向月光继续保留。当前房间窗光按质量最多启用低 1／默认 2／高 3 盏，房间提交和降低质量时不叠加旧光源；新光源短暂缓入。摄像机隐藏墙面不会开关实际窗光。窗光不额外投射一套玩家身体长阴影，原主光选定的单个人影继续保留。
4. **无人机灯原先只有开火前约半秒点亮，而且未启用阴影。** 现在巡逻时持续开灯、预警加强，平滑恢复巡逻亮度；保持原索敌、开火、伤害与巡逻参数。真实 SpotLight 负责表面受光与阴影；兼容渲染器中的少量空气散射由受深度及现有 LOS 限制的局部网格补充。它不负责涂亮地板，并排除在轮廓捕获和受击材质替换之外。
5. **无人机并非空材质。** 原近乎纯金属材质在低环境反射的夜景中丢失了大部分漫反射底色。正式无人机保留原像素纹理、面板与配色，采用低金属度 0.04、粗糙度 0.86、低高光 0.08；模型实验室的原金属版本不替换。纹理仍为 Nearest。
6. **受光被重复量化。** 原表面着色把每盏灯压成三档；部分已生成墙面还漏掉层次增强标记。现在灯光相加时保留连续衰减，最后一次调色在相邻色阶间做有序抖动。方案一、方案二及 `#3536D7` 的颜色条目保持原值。硬的实体投影边缘与连续的灯光衰减分别处理。
7. 补齐了窗玻璃破碎后保留结构窗框及其遮光体的行为。

实现后的自检返工按五个问题组记录：投影体几何；Shader 与特效捕获；窗光预算及单个人影；反射补光的能量渐入与完整遮挡；快速折返及挂起恢复。子智能体指出的后两组问题已修复并补回归。最终版已接入正式流程，未停留在独立小样。

## SIGNALIS 本地参考核对

只读查看 `E:/Agent/Workbuddy/signalis_re/解包报告.md` 与 `光照布局.csv`。导出资料包含三色环境设置、房间点光／聚光配置、硬阴影标志与无光照贴图索引。CSV 中启用的房间层级灯共 5162 条，包含跨场景和跨状态灯，不代表同时存在于一个房间。

借鉴的是低强度环境基调、局部灯具、房间覆盖和真实遮挡的配合。硬阴影并不要求把灯光衰减压成几档。没有把 Unity 强度直接套进 Godot，也没有把报告里对美术意图的推测当作恢复出的 Shader 源码。未导入任何解包贴图、模型或音频。

## 实机证据

正式入口 `scenes/app/main.tscn`，实际 Compatibility / RTX 5070 Ti GPU Camera；后台最小化窗口。固定地图种子 `1748751541`，同一镜头、原房间、原灯具、原窗户与实际生成的巡逻无人机。没有用临时测试灯替代这些真实来源。

测试将玩家定位到窗内，并设置一次无人机预警状态以观察；后续巡逻和射击使用原逻辑。空气散射的深度／中心 LOS 限长不等于完整体积阴影证明；真正表面照明的遮挡由 SpotLight 阴影承担。

- [修复前后：左前、右后](../../.runtime/window_drone_lighting_20261102/wall_window_compare.png)
- [无人机巡逻／照射／开火：正常速度动图](../../.runtime/window_drone_lighting_20261102/drone_searchlight_normal.gif)，90 帧，依据实际捕获时间播放约 4.6 秒。
- [只有外部光](../../.runtime/window_drone_lighting_20261102/final_exterior_only.png)
- [关闭局部窗光、保留共享月光](../../.runtime/window_drone_lighting_20261102/final_moon_only.png)
- [封住原窗洞后的实际遮挡](../../.runtime/window_drone_lighting_20261102/final_windows_blocked.png)
- [所有实际光源关闭后的环境底光](../../.runtime/window_drone_lighting_20261102/final_ambient_only.png)
- [无人机灯关](../../.runtime/window_drone_lighting_20261102/final_drone_off.png)／[开](../../.runtime/window_drone_lighting_20261102/final_drone_on.png)
- [另一正式办公房型](../../.runtime/window_drone_lighting_20261102/final_office.png)
- [测量结果](../../.runtime/window_drone_lighting_20261102/final_audit.json)

单独切换局部窗光有 7105 个隔点采样发生可读亮度变化。用原墙的实心变体临时封住实际窗洞，35 个无家具遮挡地面采样的平均亮度从 0.178 降为 0.127；测试后恢复原窗洞。无人机灯单独开关产生 1586 个亮度变化采样。采样阈值与固定镜头均可在测试脚本中复现；这些数字不是帧率或全游戏美术评分。

## 验证

命令统一为 `Godot_v4.7.1-stable_win64_console.exe --path . --script <测试路径>`，逻辑测试额外使用 `--headless`；GPU 测试串行，使用独立 APPDATA。日志均在 `.runtime/window_drone_lighting_20261102/`。

| 测试 | 结果 | 日志 |
|---|---|---|
| `tests/window_drone_lighting_review.gd` | 15/15：正式窗光、真实封窗遮挡、全楼墙体投影几何、实际无人机投射、补光名额与完整遮挡、质量上限及电梯隐藏 | `final.log` |
| `tests/room_bounce_lifecycle_test.gd` | 8/8：实际楼层快速 A-B-A 折返、选择间隔内返回、阴影淡出中返回、显式隐藏与挂起恢复 | `bounce_lifecycle.log` |
| `tests/dynamic_architecture_shadow_test.gd` | 28/28：墙体、门、窗框、家具阻光与剖切不破坏投影体 | `architecture.log` |
| `tests/window_sunlight_parity_test.gd` | 通过：原窗洞与本地外部光契约 | `window_contract.log` |
| `tests/special_units_hotel_robot_drone_test.gd` | 47/47：生成、机器人直接开火、枪口／弹道、伤害代理、受击和死亡清理等；不是无人机自然索敌全流程测试 | `special_units.log` |
| `tests/test_ordered_room_lighting.gd` | 4 类布局通过，0 失败 | `ordered_lighting.log` |
| `tests/actual_lamps_and_coast_promotion_test.gd` | 16/16：教程分区灯照地／照墙、正式灯具、正式红海入口与密码记录 | `actual_fixture_regression.log` |
| `tests/tonal_formal_integration.gd` | 18/18：正式入口、两套配色、移动、手机暂停与镜头恢复、实际电梯换层及新楼层材质 | `formal_entry_elevator.log` |
| `tests/tonal_semantic_sample_test.gd` | 14/14：两套配色下血液、警示、拾取及枪火保留色 | `palette_semantics.log` |
| `tests/office_shadow_integration_test.gd` | 47 项中 44 通过、3 项家具描边断言不匹配；不计作全套通过 | `office_shadow_integration.log` |

## 尚未解决及验收范围

- 上述广泛集成测试的 3 个家具描边断言分别为 139/376、214/602、142/388。其余阴影预算与悬停恢复检查通过。本轮未据此扩改整套家具资产或将这项失败隐藏。
- 原有 GPU 测试退出时仍报告两个 6888 字节纹理释放问题及 RenderingServer 析构告警，见 `final_console.log`、`formal_entry_console.log`；这些发生在引擎主日志结束之后，不能只根据主日志宣称无报错。headless 的多楼层测试还出现 dummy renderer 材质告警。没有宣称工程全部报错清零。
- 录屏和图像回读不是性能测试。正式流程回归的 draw-submission 时间也不是完整帧时间；本轮没有完成密集战斗的稳定 60 FPS 验收。新增窗光有明确上限，无人机仍沿用每层最多 2 台的原规则。
- 同镜头前后对照、来源开关、封窗阻光与正式换层已验证；未把整个第一章从教程到 Boss 全流程重新通关。

## 主要修改位置

`scripts/dream/wall_segment_3d.gd`、`office_shadow_manager.gd`、`dream_3d_ceiling_lighting.gd`、`breakable_glass_window_3d.gd`、`preview/sample_wall_and_desktop_review.gd`；`scripts/entities/exterior_patrol_drone_3d.gd`；`scripts/dream/units/drone_model_builder.gd`、`special_unit_outline.gd`、`special_unit_hit_flash.gd`；`scripts/data/demo_config.gd`；`shaders/dream3d/office_dither_lighting.gdshaderinc`、`drone_metal_pixel.gdshader`、新增 `patrol_light_scattering.gdshader`；`shaders/palette_quantize.gdshader` 以及相应验证脚本。
