# 墙顶锯齿、移动闪烁与贴墙全黑修复

启动入口仍为 [Run_Purple_Sample.cmd](../../Run_Purple_Sample.cmd)。[实际 Camera 前后对照和行走逐帧检查](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/review.html)。修复仅接入独立小样。

## 原因与修改

1. 原始玩家的脚底根节点在移动碰撞中心下方 13 个地图像素。向地图南侧、即画面右下方贴墙时，身体正确停在墙外，脚底坐标却可能进入可见墙体。原视野光源使用脚底坐标，造成整房间被墙内表面挡住。现在从原有 `CollisionShape2D` 的真实中心发出视野，GPU 遮挡与稀疏对象视线共用这一位置；不改碰撞尺寸、移动规则或角色贴图。
2. 原遮挡图保存每个角度像素的径向距离。接收点使用的实际方向与这个像素中心略有不同，斜看墙面时会误把墙自身判成遮挡。固定 0.018 世界单位的偏移还会让墙顶边缘出现零碎漏白。现在由 GPU 选择最近的实际三角形，并记录该面的方向及平面距离；接收点直接判断是否在这个平面之后。
3. 极薄墙体斜角轮廓会落到采样像素之间，最近邻单点可能读到空白。接收端检查四个相邻角度像素，做保守的二值覆盖，并保持平面比较。法线编码先量化到浮点目标可精确保存的值，避免编码边界的微小误差重新引入闪动。没有历史帧混合或人物叠层。

四邻域覆盖会使极远、极薄遮挡轮廓最多保守扩张约一个阴影纹素，仍保留清晰的二值边缘。它不放大主游戏画面，也不提高角色或环境的分辨率。

修改文件：`scripts/preview/woo_visibility_shadow.gd`、`scripts/preview/woo_shadow_materials.gd`、`shaders/preview/hellkind_sample/vision_depth.gdshader`。测试与诊断入口同步新平面编码。本次没有改半调描边、窗光补光、美术调色板或正式游戏源码。

## 实机与几何验证

Godot 4.7.1 / Forward+ / RTX 5070 Ti，世界 640×360，实际游戏 Camera。美术侧先完成窗光补光工作并退出 Godot，本会话随后串行测试。两套最终功能检查均零错误日志，302 个受审计共享源文件在各自运行期间没有变化。

| 验证项目 | 修复前 | 修复后 |
|---|---:|---:|
| 25,920 次斜角墙面采样中的错误遮黑 | 12 | 0 |
| 同组采样中的墙顶漏白 | 13 | 0 |
| 实际可见性未变化时的黑白跳变 | 33 | 0 |
| 向右下贴墙能否看见本房间 | 否 | 是 |
| 四个贴墙方向检查 | 3 个正确 | 4 个正确 |

专项检查 **17/17**：包括 L 形墙四向判定、窗洞与窗台、清空几何、接收材质实际 GPU 运算、四向原生碰撞贴墙及真实按键滑墙。滑墙检查中角色实际移动 12.54 个地图像素，12 个取样帧均保持本房间可见。早期诊断脚本曾错误地把玩家移出物理空间，该次日志单独保留，未计入通过结果。

合并回归 **70/70**：四房间 768 个采样与独立源三角形判定一致，保留真实门旋转、破墙、走路、风格与分辨率开关、重建和退出。可见橙血新增 746 个像素；墙后 1,151 个新增橙血像素未泄漏。破墙后本次视野更新 CPU 为 1.214 ms，这不是整帧或 GPU 耗时。

- [修复前数据](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/baseline/result.json)
- [最终专项数据](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/fixed/result.json) · [专项日志](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/Functional-20261104-044635.stdout.txt)
- [合并回归数据](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/result.json) · [回归日志](../../.runtime/hellkind_purple_sample_20261103/combined_art_visibility/Functional-20261104-044730.stdout.txt)

![修复后的墙顶与墙角](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/fixed/contact_3_on.png)

## 性能范围

此前独立小样的稳定 60 帧门槛仍未通过。本次功能修复不能替代性能验收。美术会话同期加入了最多三个带阴影的窗外补光，与此前合并版的照明负载不同，不能直接把前后帧耗时变化归因于这次遮挡修复。

<!-- SURFACE_PERFORMANCE -->

当前修复版本的四阶段压力记录（`20261104-151654`）如下。帧时间保留全部尖峰，关闭限帧测量余量；没有在采样窗口内截图或写文件。

| 负载 | 帧数 | P50 ms | P95 ms | P99 ms | 最大 ms | 超过 16.667 ms |
|---|---:|---:|---:|---:|---:|---:|
| 静止 | 1644 | 3.569 | 4.705 | 5.498 | 7.318 | 0 |
| 四房间移动 | 3268 | 4.792 | 6.942 | 8.397 | 53.092 | 3 |
| 开门 | 1646 | 4.757 | 6.526 | 8.034 | 11.878 | 0 |
| 混合战斗 | 1279 | 14.089 | 22.119 | 32.077 | 200.748 | 282 |

压力路径仍复现既有的 `indexing did not unpair geometries from light` 清理报错，故这是一份未通过的诊断记录；普通功能检查与退出的日志为空。不能把上述峰值归为这次平面比较的单独开销，也不能用功能通过代替 60 帧结论。

[压力原始统计与逐帧数据索引](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/performance/summary.json) · [压力日志](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/Performance-20261104-151654.stdout.txt) · [压力错误日志](../../.runtime/hellkind_purple_sample_20261103/visibility_surface_revision/Performance-20261104-151654.stderr.txt)

复现命令：`tools/validate_woo_shadow_sample.ps1 -Profile Surface`。合并回归用 `-Profile Combined`；`-Profile Surface -Mode Performance` 单独保存当前修复版本的压力测试原始数据。
