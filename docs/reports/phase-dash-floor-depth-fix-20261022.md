# 残影被部分地格覆盖修复

## 原因与改动

正式批准地板使用 `office_low_pixel` 衍生材质，其中写入 ALPHA=1，进入后绘制阶段。原残影、拖尾采用 `depth_draw_never`，没有留下深度；地板随后会重新覆盖这些像素。已用正式地板材质复现“普通不透明地板可见、批准地板消失”的对照，不将此前发现的约20px位置同步偏差当成本问题的定论。

仅将人物残影和地面拖尾着色器改为 `depth_draw_opaque`。继续启用深度测试；透明轮廓、覆盖率消散的空白像素仍使用discard，不写入深度。未关闭地板、墙、门、家具遮挡，未增加视口或改变调色板、声音、攻击和位移规则。

## 验证

- `phase_dash_depth_test`：RTX5070Ti／Compatibility实际GPU，9项检查通过。使用正式地板材质复现旧问题并验证修复；包含前方不透明墙、后绘制实心遮挡物、精灵透明洞、完全消散、地面拖尾。透明洞后方的后绘制物体仍可见，排除矩形深度遮挡。
- GPU证据：`.runtime/phase_dash_20261022/depth_fix/case_*.png` 与 `ribbon.png`。
- 正式入口正常Space输入、冲刺逻辑及调色设置回归结果见同目录上层 `depth_fix_live.log`、`depth_fix_phase_dash_test.log`、`depth_fix_phase_dash_world_test.log` 和 `depth_fix_test_palette_settings_full.log`。
- 全程Dummy音频／静音、隔离测试用户目录，单实例执行，未提交或推送。

本轮针对已复现的地板后绘覆盖，不扩大为所有显示问题均已修复。尚未覆盖每个随机种子与全部遮挡角度；此前发现的显示桥采样位置偏差未在本轮修改。GPU进程退出的纹理释放诊断也不属于本轮修复范围。
