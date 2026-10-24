# 外围楼体遮挡渐变裁切小样

2026-10-20，`E:/GameProjects/FiveMinuteMore`。

## 修正

外围楼完整正常显示，仅在其挡住本楼层视野的重叠区渐变裁开。前一版向外溶解会在本楼外沿留下碎洞，现已撤回。

- 内部距离场：外部切入深度始终为零；邻楼伸进楼层画面的部分，在约 1.5 格宽度内从完整逐渐裁去。
- 固定逻辑像素图案，不逐帧随机刷新；保留原深度缓冲。本楼自身侧立面保持连续，移除上一版角色周围挖洞的附加处理。
- 模型、外围楼数量、窗光、霓虹、房间墙体和家具未改动。距离场每层计算一次，沿用三组城市批次，不增加反射捕获或额外绘制通道。没有据此宣称稳定 60 FPS。

产品修改仅涉及 `scripts/dream/preview/sample_neon_city.gd` 与 `shaders/dream3d/preview/sample_neon_city.gdshader`，使用正式楼层已有公共城市链路。

## 实景

- [同镜头前后对照](../../.runtime/city_visibility_20261020/delivery/comparison.png)：左侧在测试中复现被拒绝的向外溶解（包括本楼侧立面），右侧为修正版本。相同种子、相同冻结画面，无截图内修图。
- [正式入口正常速度走动](../../.runtime/city_visibility_20261020/delivery/walk.gif)。
- [手机镜头正常速度开关](../../.runtime/city_visibility_20261020/delivery/phone_zoom.gif)。

实际 Main，RTX 5070 Ti / GL Compatibility / 1920×1080 / 640×360 逻辑画面，隔离存档、静音、后台最小化。动图按录制帧真实时间间隔制作。

## 验证

- 距离场：**10 项，0 失败，退出码 0**。所有外部格零切入、内部深度单调、深处完全保护、凸角、封闭孔及原分类不变。[日志](../../.runtime/city_visibility_20261020/field.log)
- GPU 边界专项：生产城市材质与受控遮挡面。新旧相比，**12,916 个重叠区像素变化，外侧变化 0 像素**；内部核心清空、重复静帧一致，退出码 0。[日志](../../.runtime/city_visibility_20261020/shader_final.log) / [专项图](../../.runtime/city_visibility_20261020/shader/after.png)。专项图不是正式游戏美术画面。
- 正式 Main：**8 项，0 失败，退出码 0**。外围空隙恢复、冻结画面稳定、三组城市材质、本楼立面规则、实际玩家移动、手机暂停／恢复、窗口最小化。[最终日志](../../.runtime/city_visibility_20261020/final_gpu.log) / [原始记录](../../.runtime/city_visibility_20261020/camera/report.json)。

初始接待区机位没有明显的邻楼内部重叠，早期“硬切与新渐变必须有差别”的检查失败，探索日志保留。正式前后对照证明外围空隙恢复；渐变方向及外侧保留由 GPU 边界专项验证。不宣称已完成四种骨架全流程或战斗性能验收。

隔离运行仍有系统根证书、既有锚点提示和退出时两个纹理 RID / RenderingServer 诊断；本轮没有扩大处理这些既有问题。
