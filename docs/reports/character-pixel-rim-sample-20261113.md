# 像素角色边缘受光：独立实景小样

2026-11-13。状态更新：用户已认可彩光小样并批准推广，现已接入正式共用角色材质，见[正式推广、多灯验证与新开销记录](character-pixel-rim-promotion-20261113.md)。以下保留小样阶段记录，旧性能结论不代表正式接法；小样现默认恢复场景原灯，L 可恢复，1/2/3/0 才进入隔离测试。

### 同日刘海录制勘误

用户指出刘海接点错误，核查确认是本次录制器遗漏更新：冻结玩家同时停掉了子节点 `SideBangs` 的物理回调，录制器手动切换了头部朝向，却没有调用正式的 `step_actor()`，所以刘海仍使用旧朝向的接点、镜像与前后层级。此前“源纹理 A/B 相同”只证明 Shader 未改纹理，不能证明录制姿态符合正式角色；本次补上逐朝向定位和 GPU 捕获同步检查。

现在录制器按相同的 0.05 秒姿态时间步运行原有刘海更新后再捕获。没有修改 `player_side_bangs.gd`、`player_character_atlas.gd`、角色原画或正式定位参数。重录通过 74 项断言，十二个抽查时点覆盖八朝向的接点、前后层级、镜像与实际 GPU 捕获一致性。[检查记录](../../.runtime/character_rim_20261113/bangs_correction/result.json)，[进程结果](../../.runtime/character_rim_20261113/bangs_correction/process_result.json)。

[旧录制／同步修正八方向对照](../../.runtime/character_rim_20261113/delivery/bangs_alignment_corrected.png)。下方正常速度动图链接已换为修正版。原录制关键帧保留在 `.runtime/character_rim_20261113/bangs_correction/before/`。本次仅重录视觉证据，以下原有功能及性能记录保留其原采样范围，没有重跑或改写密集性能结果。

## 交付

- 唯一试玩入口：[Preview_Character_Rim.cmd](../../Preview_Character_Rim.cmd)。复用 GameTestLab，独立私有试玩配置。
- [实际 Camera 全景前后对照](../../.runtime/character_rim_20261113/delivery/camera_comparison.png)。左原版，右小样。
- [八方向正常速度对照（刘海同步修正版）](../../.runtime/character_rim_20261113/delivery/walk_eight_directions_bangs_fixed_1x.gif)。左原版，右小样；相同姿态，20fps 时间轴，Nearest 三倍局部放大。前四秒展示八方向，末两秒切换右侧／背后灯光。由真实游戏 Camera PNG 编码，保留源帧。
- [静态局部对照](../../.runtime/character_rim_20261113/delivery/detail_comparison.png)。

操作：T 原版／新版；1 左光、2 右光、3 背光、0 关灯；B 实体挡光墙；WASD 移动、鼠标瞄准、空格使用现有翻滚；F1 白盒／正式美术；F5 重建。

## 本轮实现

角色身体与手持武器沿用原有捕获纹理、参考深度、真实场景灯光及阴影。只在原图不透明像素的内侧提取约一源像素宽的边缘；朝光边缘随光源方向、颜色、距离和阴影响应，暗面继续保持原有着色。

新增项写入逐灯高光，不增加恒定自发光、外扩轮廓、角色追随灯或全局 Bloom。轮廓响应强度 1.8，宽度一源像素，背光包裹权重 0.4；实际游戏像素宽度随原镜头透视变化。身体与武器互相读取 Alpha 覆盖，抑制手臂／枪械重叠处的内部亮缝。受击闪白、烟雾剪影及既有近战目标高亮出现时，新亮边让位。

运行时在原有、角色独占的材质上切换 Shader 资源，保持材质身份及持续更新的角色参数；关闭或清理恢复原 Shader。没有改动正式角色原画、玩家／敌人控制脚本、正式材质、战斗数值和正式入口。

本小样使用当前正式 Camera、地板墙面、办公家具、角色及现有投影。为了明确判断左右光和遮挡，样例单独关闭既有灯的接收掩码，使用同一盏可控制的真实点光；A/B 两侧共享该条件。正式稀疏灯光策略会隐藏未登记灯，因此只在此独立测试世界停用该筛选策略。背景既有灯具自发光及镜头效果保留。此控制照明不推广到正式房间。

## 检查结果

实际运行均为 Godot 4.7.1、Forward+／Vulkan、NVIDIA RTX 5070 Ti，640×360 世界视口。后台进程在启动前准备私有静音配置，扩展测试确认主总线静音；正常游戏音量未修改。

| 检查 | 结果与证据 |
|---|---|
| 黑色原画左／右受光 | 原位 256×256 GPU 探针通过，左光仅左侧增加、右光仅右侧增加；关灯候选与基线逐字节相同 |
| 烟雾、受击、分件接合 | GPU 探针额外三项通过：烟雾和白闪无重复亮边，其他分件覆盖的边缘不发亮 |
| 实景左右光、逆光 | 玩家与人形敌人、身体与武器四个材质正确绑定；三个方位均可见响应 |
| 实体遮挡 | 使用真实阴影的挡光墙，新增亮边差异从左光 110 像素降至 0 像素（见噪声阈值说明） |
| 关灯、还原 | 新增项消失；完整场景含体积雾的时间重建噪声，关灯最大差异 1/255、恢复最大差异 2/255。实景统计使用 3.1/255 阈值，未宣称整幅画逐字节相同 |
| 八方向原画 | 120 组同姿态 A/B；十二个抽查时点的角色源捕获纹理／Alpha 逐字节相同；原画没有重绘或变形 |
| 动作与清理 | 调用既有近战、翻滚及收招姿态，材质身份和投影代理保留；白盒重建、正式美术重建、旧世界绑定释放、原 Shader 精确恢复通过 |

本轮 6 项探针断言、8 项原生实景断言、39 项扩展断言通过。39 项包含重复方向／尺寸断言，不等于 39 个独立玩法用例。未进行整章流程、死亡／手机完整流程、AI 交战和所有房型的推广回归。

## 开销记录与推广边界

### 不同光色追加验证

同日追加实际 Camera 测试：固定姿态、灯位、强度 3.5 和阴影，仅将测试灯切换为白、红、蓝、暖黄。四种光色均可驱动新增亮边，三种彩光的新增 RGB 确认分别由红、蓝、暖黄色主导；实现直接使用真实逐灯 `LIGHT_COLOR`，不是固定白色描边。此前动图仅展示了冷白测试灯。

[四种真实光色对照](../../.runtime/character_rim_20261113/delivery/light_color_comparison.png)，[原始 Camera 与测量结果](../../.runtime/character_rim_20261113/colors/result.json)，[进程结果（exit 0）](../../.runtime/character_rim_20261113/colors/process_result.json)。原版／候选在每一种光色下分别捕获，比较同色照明下的新增边缘，排除背景及原有漫反射变化。仅新增 `tests/character_rim_color_test.gd` 与取证文件，未改正式或小样着色器。本结果不包含多灯混合的专项验收。

### 原有密集角色性能记录

同一测试进程中，12／24 个角色（含玩家），原版→候选→候选→原版，每块四秒，每块前预热七十帧。相同 Camera、灯光、阴影、反射、家具、分辨率及私有静音条件。角色保持可见并调用既有步态更新，未运行交战 AI。关闭限帧与 VSync；DisplayServer 在各块记录 focused=true。采样窗口内不截图、不写磁盘；所有尖峰保留。

下表合并各状态的两个采样块，单位为毫秒，数值为相邻 process frame 的墙钟间隔，不能当作 GPU 独占耗时。

| 角色数 | 状态 | 帧数 | P50 | P95 | P99 | 最大 |
|---:|---|---:|---:|---:|---:|---:|
| 12 | 原版 | 801 | 9.918 | 11.159 | 11.932 | 12.680 |
| 12 | 小样 | 780 | 10.136 | 11.662 | 12.946 | 17.724 |
| 24 | 原版 | 606 | 13.124 | 14.823 | 15.828 | 17.041 |
| 24 | 小样 | 476 | 15.644 | 22.117 | 32.031 | 91.961 |

12 人短采样的 P95 增加约 0.50ms。24 人小样明显变慢，P95 增加约 7.29ms，且有 91.961ms 峰值。延迟视口 GPU 计数未出现同等幅度变化，不能据此认定峰值根因；需进一步区分材质／跨捕获纹理依赖、脚本与渲染提交。没有通过稳定 60FPS 或全游戏性能验收，本次不进入正式流程。

## 文件与原始证据

实现仅新增：

- `shaders/preview/character_pixel_rim.gdshaderinc`
- `scripts/testing/character_rim_effect.gd`
- `scripts/testing/character_rim_sample.gd`
- `scenes/testing/CharacterRimPreview.tscn`、`CharacterRimLab.tscn`
- `tests/character_rim_light_probe.gd`、`character_rim_sample_test.gd`、`character_rim_extended_test.gd`
- `Preview_Character_Rim.cmd`、`tools/preview_character_rim.ps1`
- `tools/encode_character_rim_evidence.py` 与本报告。

原始数据：

- [探针结果](../../.runtime/character_rim_20261113/probe/result.json)、[原生实景结果](../../.runtime/character_rim_20261113/native/result.json)
- [扩展检查与各块性能](../../.runtime/character_rim_20261113/extended/result.json)、[合并统计](../../.runtime/character_rim_20261113/extended/aggregate.json)
- 同目录 `12_*_*.csv`、`24_*_*.csv` 为逐帧原始记录；`motion/` 保留 240 张原始实际 Camera PNG。
- [原生测试进程结果](../../.runtime/character_rim_20261113/native_process_result.json)、[探针进程结果](../../.runtime/character_rim_20261113/probe_process_result.json)、[扩展测试进程结果](../../.runtime/character_rim_20261113/extended_process_result.json)，最终均 exit 0。

早期 `diagnostic.log` 属于定位灯被隐藏时的失败诊断，不作为最终通过证据。既有 dirty 工作区保留，未调用 Antigravity、未提交或清理其他任务文件。

后续优先解决密集角色开销，再等待用户确认小样外观并按正式灯光与完整场景验证。脸颊、头发分束及衣褶内部曲面仍是后续辅助法线工作，本轮没有伪造这些细节。
