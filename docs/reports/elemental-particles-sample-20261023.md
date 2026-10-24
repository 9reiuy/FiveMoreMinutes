# 可复用火焰、爆炸、烟雾样板

范围：新增系统和独立样板，不接入 Main、随机楼层或现有枪口/跑步/死亡特效。不下载外部素材，无新增素材授权依赖。视觉由程序粒子及阶梯轮廓 shader 组成，不是复制参考游戏资源。

## 使用

Godot 打开 `scenes/dream/preview/ElementalParticlesSample.tscn`，F6 运行当前场景。1 无风，2 左风，3 右风，空格爆炸，R 重置。中间每四秒自动爆炸一次；左边持续火，右边烟团。样板在自身进程使用 640×360 viewport 缩放，不保存或改变正式游戏设置。

系统为 `scripts/dream/elemental_particles_3d.gd`，实例化并加入楼层节点。位置、风向都用该节点的局部世界单位，不是屏幕像素。

```gdscript
const EFFECTS = preload("res://scripts/dream/elemental_particles_3d.gd")
var effects = EFFECTS.new()
add_child(effects)
var fire_id = effects.emit_fire(Vector3(0, 0.1, 0))
effects.set_wind(Vector3(1.8, 0, 0))
effects.explode(Vector3(2, 0.2, 0), 1.0)
effects.emit_smoke(Vector3(-2, 0.1, 0), 12)
effects.stop_fire(fire_id)
effects.clear()
```

`emit_fire(at, radius=0.20, duration=-1)` 返回停止句柄，-1 持续。停止后已有粒子自然消失。不执行伤害、蔓延、物理碰撞、音效或相机震动，后续游戏规则另行接入。

## 动态和整体描边

火团从固定点连续生成，黄白→黄→橙→红、上升收缩；烟团扩大消散，火星独立运动。风持续改变已存在粒子的速度，不是倾斜整张动画。

三组 MultiMesh 绘制火、烟、火星，另三组绘制外扩轮廓。全部轮廓先画，全部填色后画：填色覆盖重叠内部的轮廓，只留下合并外沿。轮廓不写深度，填色写深度，两者都检查场景深度。ALPHA=1 用于进入可排序通道，不是半透明淡出；衰减使用像素覆盖。

GPU 对照两个不同深度的火团及两个烟团：开启轮廓后已有填色内部差异 0，外沿新增 376 像素；加前景实心遮挡块后内部/遮挡像素差异仍为 0，外沿新增 295 像素。这不代表正式游戏全部透明墙/玻璃组合已验收。正交相机描边约一逻辑像素，透视相机暂用世界尺寸兜底。

## 预算与测试

上限：384 粒子、8 火源、4 个无阴影局部光。持续发射预留 96 槽供爆炸，超额丢弃，不无限分配。超长帧最多模拟 0.2 秒，属于视觉降级保护。局部光用于持续火焰，暂没有独立爆炸闪光灯。

- `elemental_particles_test.gd`：生命周期、预算、双向风、活粒子转向、清理和爆炸保留容量。
- `elemental_union_outline_test.gd`：4 项 GPU 整体轮廓及遮挡检查通过。
- `elemental_particles_camera_test.gd`：真实样板 Camera3D 的无风/左右风截图与 24 帧运动图已输出并查看，非外部软件渲染。
- RTX 5070 Ti / Compatibility，8 火源＋爆炸，150 样本：step CPU 中位约 0.573 ms、P95 0.858 ms；整个简易样板 viewport GPU 中位约 0.044 ms、P95 0.087 ms。最小化 force_draw，非正式战斗、非增量 GPU 成本，不证明全设备峰值 60 FPS。
- 压测结束 280 活粒子，累计 2715 次发射被预算丢弃：高负载降低密度，而非维持全部数量。

产出：`.runtime/elemental_particles_20261023/`。未替换正式效果，未提交或上传。
