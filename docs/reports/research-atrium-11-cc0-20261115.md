# 1-1 研究中庭：CC0 模块与现有关卡风格

## 当前结果

独立入口为工程根目录 `Run_1-1.cmd`，通过 `ResearchAtriumTestLab.tscn` 启动；没有接入正式主线或 0-6，也没有导出游戏包。

按用户最后的更正，H06 位于一层地面 0 米，中央是通高的方形空间，没有机甲高台。右侧走廊转入上侧走廊，左侧是通透玻璃，右侧是连续实体墙。主墙各使用一整段导入模块，墙与玻璃顶部统一为 7.8 米。底部大平台通过四根支撑柱承托走廊；两处浅坡累计下降 0.8 米，终点仍在上层。逻辑可行走区域 102 格，32 游戏像素／米。

没有新增墙上文字或 HUD。角色、输入、武器、受击、死亡和像素角色受光继续使用正式实现。H06 目前是展示模型，尚无新增的机甲战斗逻辑。

## 对照 0-1 至 0-6

本轮检查了当前源码，未修改这些关卡：

| 关卡 | 现有表面与照明做法 |
| --- | --- |
| 0-1 | `maintenance_concrete.gdshader`；32 格表面颗粒、凹点、接缝、局部冷灯；`maintenance_environment.gd` |
| 0-2 | 同一混凝土／环境体系；`parking_concrete_floor.gdshader` 区分车道与停车区 |
| 0-3 | `storage_floor.gdshader` 与共用混凝土、局部灯光 |
| 0-4 | `transit_surfaces.gdshader` 的面板、灰缝、磨损与粗糙度；共用灯光环境 |
| 0-5 | 导入站台模型、同一 transit 表面、墙顶封黑、真实局部照明与 fixture optics |
| 0-6 | 既有列车模型保留 PBR 贴图；`train_reference_art.gd` / `train_surface_wear.gd`；共用环境和只作用于角色／物件的微弱补光 |

1-1 现在直接复用 0-1/0-2 的混凝土底层、0-4/0-5 的面板／地面材质、相同的局部灯光与 optics、墙顶封黑及标准镜头尺度。环境不再使用常亮方向补光；保留与 0-6 相同类别、只作用于角色／物件的补光。使用冷白局部灯，未恢复全局调色板、交叉排线或噪声后处理。

初版单独制作的白盒几何、灰白照片表面 shader 已退出运行代码；备份留在 `.runtime/research_atrium_20261115/rejected_prototype_backup`。下载的 Poly Haven 贴图保留为未启用候选，不再承担当前场景材质。

## 素材来源

- 建筑：Quaternius [Modular Sci-Fi Megakit](https://quaternius.com/packs/modularscifimegakit.html)，作者 [itch.io 免费 Standard 包](https://quaternius.itch.io/modular-sci-fi-megakit)。原包及包内 `License_Standard.txt` 均核实为 CC0 1.0；未使用付费 Pro/Source。原包 SHA256：`6fae60cf5189e44dff0bd91097f094a765acc6d57d64a85a0cc0dd56e03035e3`。
- 场景使用现成墙板、地板、坡道、结构柱、灯具与玻璃表面，通过变换摆放，不制作新的可见基本体。单独玻璃为作者 `WallWindow_Straight` 的原始 `M_Glass` 表面，两个三角形原样提取。`art/Dream/CC0/QuaterniusSciFiStandard` 保留许可、来源、清单及格式转换记录。
- H06：沿用 `ArtExperiments/Crawler_H06_20261114/exports/crawler_h06.glb`，项目副本为 `art/Dream/H06/crawler_h06.glb`。两者 SHA256 均为 `4d9a252a60aa4b005f339e6a2d1b284de38bd7744ac30ef2e6ef7169bbe6f1fa`。原模型、动画及来源工程未修改，使用既有 Deployment 抬升姿态。

## 当前验证与边界

- 布局检查 7/7：L 形连通、入口终点、无多余两翼、连续浅坡与累计 0.8 米下降。
- Forward+ / Vulkan 原生运行检查 31/31：CC0 几何来源、一层机甲、四根支撑、整墙等高、左玻璃、共用 shader、实际导入坡面与脚底高度、正式角色全程走通、玻璃侧防坠落、开枪、死亡、真实 F5 重开、无重复模型及静音保持。PID 60032，退出 0，标准错误为空。
- 实际游戏 Camera：`.runtime/research_atrium_20261115/shared-style-game-camera-20261114-175204/`；正常视角为 `walk_7.0_4.0.png` 等文件。`00_overview_camera.png` 是同一 Camera 的总览构图，仅用于核对结构，不冒充正常游玩镜头。
- 真实启动器诊断：PID 3360，退出 0，实际 Vulkan / Forward+，使用独立诊断存档及静音 Dummy 音频。证据为 `.runtime/research_atrium_20261115/launcher-smoke/`。

材质 A/B/A 短测在相同几何、机甲、镜头、种子、灯数、1280×720、60 帧上限、私有静音 WASAPI 条件下进行；B 仅替换中性材质，不删几何／灯光。各自预热至少 2 秒及 120 帧后采样 360 帧，各有 12 次正式开枪。

| 样本 | P50 ms | P95 ms | P99 ms | 最大 ms | 超过 20 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| A1 当前共享材质 | 16.658 | 17.206 | 17.549 | 35.445 | 1 |
| B 中性材质 | 16.642 | 17.325 | 17.991 | 19.121 | 0 |
| A2 当前共享材质 | 16.664 | 17.268 | 17.790 | 18.057 | 0 |

原始 CSV、配置与 JSON 位于 `.runtime/research_atrium_20261115/shared-style-material-perf-20261114-175548/`，PID 41460，退出 0，标准错误为空。数据是相邻主循环墙钟间隔，并非纯 GPU 时间。A1 的单帧尖峰保留，未据此归因，也不将本次短测视为全游戏稳定 60 FPS 认证。画面最终仍待用户复核。

工作区保留原有大量未提交改动；本轮没有重置、清理、提交或合并。`project.godot` 与任务前备份逐字节一致。公共启动器仅增加 `level11` 和独立存档入口，旧入口配置保持。
