# 前台真实地毯照片材质 · 2026-11-08

用户要求直接寻找真实材质。本轮停止使用Caban羊毛面料及其裁片/镜像/灰度重构，改用 **Keith333** 的 [Carpet Texture - Red - Seamless Texture with normalmap](https://opengameart.org/content/carpet-texture-red-seamless-texture-with-normalmap)。作者明确说明源自本人照片，并提供生成的配套法线。这是实拍颜色和配套生成法线，不将其描述为完整测量PBR扫描。

两张2048×2035原图直接绑定到材质，文件与下载散列一致。材质仅施加较深酒红色调、哑光粗糙度与已有折边衬底颜色；不再裁64像素小块或镜像生成纹理。使用Nearest、原图Mipmaps、32像素/米呈现与连续的纹理梯度，保留原640×360像素画面。已保留的连续长毯轮廓及独立等候区不变。

原图、下载散列和署名位于 `art/Dream/ReceptionLobby/keith333_red_carpet/`。许可为 [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)，作者、标题、来源、许可及修改说明同时写入 `data/asset_attributions.txt`。现有导出预设的 `data/*` 会包含该文件，未新增提示UI或修改导出配置。

## 实际验证

| 批次 | PID | 结果 |
| --- | --- | --- |
| `camera01` | 42928 | 18项实际Main/Camera检查通过，退出0 |
| `motion01` | 16180 | 正常输入行走184.08像素，记录13个实际Camera帧，退出0 |

运行值为Forward+ / Vulkan，实际游戏Camera640×360。行走检查读取到完整原图路径、2048×2035尺寸及两张图的Mipmaps，署名文件可读取。检查不构成全游戏性能或自动审美认证。

两个图形进程启动前准备私有Master=0，并明确使用Dummy音频驱动，未改玩家/系统音量；均无ERROR或SCRIPT ERROR，保留现存Control锚点警告。导入批次 `import01`／`import02` 均退出0，但编辑器扫描到了工程中原有WAV测试样例的格式/空资源诊断；未将导入日志记为无错误。随后本次两张照片的加载、Mipmaps及图形运行检查通过。

证据位于 `.runtime/reception_real_carpet_20261108/`，最终截图和散列汇总位于 `final/`。本轮仅修改前台地毯材质、已有Camera检查的素材约定及来源记录；不改灯位、地墙、战斗或乘梯逻辑。后续用户追加的电梯金属和反光另行记录；本报告不声称其已完成。
