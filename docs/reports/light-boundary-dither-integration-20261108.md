# 明暗交界像素抖动正式接入

2026-11-08。用户已认可加大反差的2×2像素小样，并明确要求推广至正式游戏，保持仅在明暗交界生成网点。

## 最终行为

共享3D材质在逐灯受光计算中处理真实 `ATTENUATION`。仅当灯光衰减／阴影存在足够的屏幕梯度时，将有序网点混入过渡；梯度阈值保持小样的0.0025～0.020，采用4×4 Bayer阈值、每格2×2游戏像素、衰减步距0.5。零光照返回零，均匀受光保持连续值。检测不读取贴图或最终画面颜色，不会因贴图接缝而铺网点。

新增 `shaders/dream3d/light_boundary_dither.gdshaderinc`，13份现有办公环境／墙地／家具／角色及血液受光Shader引用它。`scripts/dream/office_dither_lighting.gd` 的运行时材质变体和 `scripts/dream/floor_reflections.gd` 的局部高光路径使用同一函数。保持原材质对象的参数、纹理、法线、自发光、真实灯光与阴影设置，不增加全图后处理或额外光源；角色和武器动画、碰撞、战斗数值均未修改。

正式默认启用。新建房间、动态载体和换层重新创建的材质从同一Shader默认值读取，无需在试玩后手动打开。保留Forward+/Vulkan、640×360世界画面及1280×720窗口。`project.godot`、`world_semantic_decode.gdshader`、`selective_pixel_preview.gd` 与旧 `office_dither_lighting.gdshaderinc` 的散列均保持修改前一致；未恢复全局调色板。红海独立Shader和菜单／手机专用材质不因此增加网点。

## 当前验证

后台GPU进程均使用私有WASAPI静音配置与共享渲染锁，记录PID，退出码为0且均已退出、释放锁。

| 验证 | 结果 | 原始证据 |
| --- | --- | --- |
| 接入前独立候选OFF／ON／OFF负载对照 | 10项通过；保留实际开火、组合特效及原始帧耗时 | `.runtime/whpu_dither_review_20261108/promotion_gate01/` |
| 正式材质Camera与已知光场对照 | 19项通过；635个实际材质默认与小样一致，重建及清理正常 | `.runtime/whpu_dither_review_20261108/formal_camera02/` |
| 正式入口完整回归 | 37项通过；主菜单→立绘卧室→前台→真实电梯→首层→再次乘梯→第二层，另检查俯视卧室 | `.runtime/whpu_dither_review_20261108/formal_entry01/` |

固定光场的GPU对照证明：纯黑区域完全不增亮；均匀受光的两种不同材质颜色及其硬边逐像素不变；只有变化的光场出现网点。关闭再开启后冻结的正式Camera像素完全恢复。正式640×360样本中超过2/255变化的像素为6539个，约2.84%；该比例只适用于此图，不是所有场景的覆盖上限。窗口外层UI的像素对照不变，正常走动与Camera跟随通过。

首轮材质测试有两项默认值检查失败：Godot对未显式设置的材质参数返回空值，测试未读取Shader默认值。改为优先读取材质值、空值时查询渲染器默认值，确认635个材质均为 `[true, 2.0, 2.0]`。生产参数未为此更改；修正后19项全通过。对应官方接口说明：[RenderingServer.shader_get_parameter_default](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-shader-get-parameter-default)。首次失败证据保留在 `formal_camera01/`。

## 性能范围

以下为同一生产美术测试场、固定种子、4名不启用AI的敌人、原灯光／阴影／反射、640×360、无限帧、原生WASAPI私有静音。每轮3秒冻结画面，随后6秒实际MP5开火及血迹／烟雾／燃烧触发；不在计时区间截图或写盘。帧耗时是相邻主循环墙钟间隔，**不是GPU执行时间**。

| 状态 | 静态P50/P95/P99/峰值 ms | 组合P50/P95/P99/峰值 ms | 组合帧数／>20ms帧数 |
| --- | --- | --- | --- |
| 关闭A | 1.429 / 2.152 / 2.611 / 13.685 | 7.329 / 17.173 / 45.640 / 800.311 | 520 / 12 |
| 开启B | 1.351 / 2.066 / 2.207 / 2.643 | 7.740 / 16.891 / 27.108 / 40.152 | 670 / 20 |
| 关闭A复测 | 1.363 / 2.119 / 2.226 / 2.708 | 6.866 / 14.974 / 21.056 / 89.298 | 770 / 16 |

受控静态P95未增加。组合P95在两次关闭结果的范围内，但场景状态和首次资源使用并非逐帧确定性回放，三次实际射击分别60／75／76次；不能把开启B较低的峰值解释为效果改善了性能。关闭基线仍出现首次资源／运行时峰值，保留所有慢帧；未为其指定未经验证的根因。旧版单次155.632ms峰值在本次开启窗口未复现，本次不能解释其来源，也不能据此声称全游戏稳定60FPS。当前证据支持这套效果未造成明显的边际帧耗时退化。

## 文件与复查

接入前快照：`.runtime/whpu_dither_review_20261108/promotion/before/`。正式实现及测试文件SHA256：`promotion/integration_manifest.json`。复用现有脏工作树及其改动，无提交、重置、清理或外部代理调用。

自动检查为 `tests/light_boundary_dither_camera_test.gd`、`tests/light_boundary_formal_entry_test.gd`，已知光场使用 `tests/fixtures/light_boundary_field.gdshader`。原生证据通过既有私有运行器串行运行：

```powershell
& '.runtime\whpu_dither_review_20261108\support\run.ps1' -Label formal_camera02 -Script res://tests/light_boundary_dither_camera_test.gd -Formal
& '.runtime\whpu_dither_review_20261108\support\run.ps1' -Label formal_entry01 -Script res://tests/light_boundary_formal_entry_test.gd -Formal
```

标签目录不可重复使用；复测请换用新标签。正式试玩仍从现有 `scenes/app/main.tscn` 或主游戏正常启动器进入，不需要研究小样入口。已经运行的游戏需重新启动以加载新Shader。
