# 正常游戏有伤害却看不到挥击：实际根因与修复

## 根因

用户确认：球棍左键能造成伤害，但无挥击显示。检查运行进程，确认用户通过当前 `E:/GameProjects/FiveMinuteMore` 的实际Main启动，不是旧导出包。

在不冻结世界、不直接调用 `_perform_swing()` 的正常输入测试中复现。输入、伤害时钟、节点可见性、材质原对象的透明度/扫角、裁切距离均在更新，但实际mesh绑定的材质已经不是动画所更新的对象。

`floor_reflections.gd` 会异步处理新加入的Mesh。挥击没有声明动态材质归属，被误当静态素材复制；副本保留初始透明度0。脚本继续写原材质，屏幕绘制副本，因此不显示。暂停世界的旧交付同时停了反射组件的pending处理，绕过真实冲突；此前的受控画面及可见像素检查不能证明正常游戏已修复。这是此前验收遗漏。

诊断中临时关闭深度或裁切、替换原材质为纯色都没有作用，因为屏幕根本没有使用被修改的原对象。正式修复没有保留这些诊断改法。

## 修复

- 挥击材质标记 `runtime_uniform_owner=true`。
- 地板反射识别该明确契约，像角色等动态材质一样原地适配shader，不替换ShaderMaterial实例；动画继续驱动真正用于绘制的资源。
- 保留反射、墙/门/高柜阻挡、显示图层、像素化/Palette及80距离。不增加逐帧强制重绑、置顶、禁用深度或另一条伤害时钟。
- 静态资源仍隔离复制，清理时仍恢复原shader。未提交/上传。

## 验证

1. 新增 `melee_reflection_material_test.gd`，13项通过。验证动态材质身份、0→1→0透明度、扫角、shader反射适配、静态副本策略、共享shader不被污染及退出恢复。
2. `melee_sweep_test` 57项、`melee_sweep_world_test` 24项、`melee_presentation_test` 229项通过：80边界、伤害/攻速、门/柜、三次重建、刘海和握持高度回归。
3. 新增 `melee_live_input_test.gd`，通过真实鼠标左键事件进入正式Player输入判断，不手动推进武器、角色显示桥或攻击快照。实际Main、随机办公室，世界、AI、物理、时间控制和反射保持运行；主摄像机输出。所有观测到的活动快照均为 `material_mismatches=0`；球棍正常转动，渲染前/后采样确认显示。仅测试角色搬到生成办公区空地并增加生命值以避免采样途中死亡。
4. 实机PNG：`.runtime/melee_sweep_20261021/live_camera_fixed/actual_left_click.png`；详细状态：`live_input_fixed.json`；日志：`live_input_fixed.log`。RTX5070Ti，Compatibility，1280×720。原始图，不是生成图片或冻结快照的重演。
5. 既有正式地板反射回归 `floor_reflection_rollout_test.gd`：1605项、0失败，退出0；四种骨架、重复安装/清理、材质和作用范围保持。

全部测试静音、隔离存档、串行；保留用户Godot编辑器。退出仍有已有纹理/RenderingServer/ObjectDB资源提示，未宣称修复。截图读回会影响采样帧耗时，不据此报告实战FPS。
