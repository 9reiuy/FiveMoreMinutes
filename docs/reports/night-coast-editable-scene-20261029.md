# Night Coast 可编辑场景交付

## 结果

`scenes/preview/night_coast.tscn` 从仅有根节点的运行时生成器，改为保存 393 个子节点的真实场景。网格、材质及纹理写入 `resources/preview/night_coast/`，总计 209 个资源、约 2.27 MB。节点全部归属场景根，可在 Godot 3D 视图选取并保存；运行时不再创建替代几何体。

海岸控制器绑定现有地形、水面、角色、天空、摄像机与灯光。岸边物件位置及缩放用于重建水流障碍和浪花遮挡；山坡装饰的位置用于行走避障。风机保留摆放与叶片初始角度，月亮读取保存的世界标记，云量使用保存的月光能量为基准。摄像机保留 FOV 与构图偏移，并通过三个可见标记控制从高机位到海平线的过程。

地形高度现在读取保存网格的实际三角面，不再只根据生成公式放置角色。各实例独立持有动态材质与流水纹理。

## 用户操作

编辑 `res://scenes/preview/night_coast.tscn`，选中节点按 F 聚焦，Ctrl+S 保存。试玩继续运行 `night_coast_display.tscn` 或原启动脚本，以获得固定 640×360 像素显示。详细节点表和范围见 [编辑说明](../night_coast_editing.md)。

这次没有增加地形雕刻笔刷。地形需保持规则高度网格拓扑及直立；海岸边界、可走路线与固定 24×20 米近岸流动区域仍有独立参数规则，任意替换整个地形需要同步配置，不能宣称支持通用模型自动识别海岸。

## 当前验证

实际执行者：Codex 独立完成，无子智能体。工程 `E:\GameProjects\FiveMinuteMore`，分支 `wip/linux-migrate-20261018`，基线 `f1e9702f`；已有无关修改保留，未提交或合并。

Godot 4.7.1 Compatibility，RTX 5070 Ti。测试使用隔离 APPDATA/LOCALAPPDATA、后台最小化原生窗口与真实 640×360 GPU Camera。

| 检查 | 结果 |
| --- | --- |
| `tests/night_coast_editable_scene_test.gd` | 27 项通过，退出码 0。覆盖加入场景树前已有几何、场景归属、修改后保存/释放/重载、运行不重置节点、水流与泡沫读取移动物件、山坡碰撞、风机、月亮、镜头、材质、暂停、实例隔离。 |
| `tests/night_coast_camera_delivery.gd` | 54 项通过，退出码 0。覆盖正式独立显示入口、像素显示、海浪/岸边泡沫、左右风机/灰描边、月亮世界投影、云遮月、连续远灯、攀登和镜头、暂停、鼠标注水、水量守恒。 |
| 迁移前后实际 Camera | 平均每像素最大 RGB 通道差 0.00136（0～1 范围），主要有角色贴合保存网格后的微小高度差与渲染差异。没有宣称逐像素完全一致。 |
| 编辑器导入 | 退出码 0；未发现本轮脚本解析错误。全工程扫描触发已有第三方依赖的测试 WAV/OBJ 导入诊断，不能称全工程日志无错误。定向 GPU 两套测试无脚本/着色器错误。 |

命令入口：

```powershell
$env:APPDATA = 'E:\GameProjects\FiveMinuteMore\.runtime\night_coast_editable_20261029\appdata'
$env:LOCALAPPDATA = 'E:\GameProjects\FiveMinuteMore\.runtime\night_coast_editable_20261029\localappdata'
& 'E:\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'E:\GameProjects\FiveMinuteMore' --rendering-method gl_compatibility --audio-driver Dummy --resolution 32x32 --position '-30000,-30000' --script res://tests/night_coast_editable_scene_test.gd
# 第二套替换为 res://tests/night_coast_camera_delivery.gd
```

性能范围：本轮用于验证可编辑性及表现回归，未做稳定 60 FPS 验收。原回归仍记录模拟与纹理上传 CPU 用时，不能当作 GPU/整帧耗时。

修复记录：迁移工具首次保存前遇到自动生成节点名不同，修正节点定位后成功保存；测试环境首次启动因默认用户目录访问崩溃，改为工作区内隔离目录后正常。首次可编辑性测试及完整 Camera 回归均通过，后续移除失效生成逻辑、整理镜头坐标后定向 27 项再次通过。

## 证据

`.runtime/night_coast_editable_20261029/`：

- `editable.log`、`editable_report.json`：可编辑性测试。
- `regression.log`、`regression/report.json`：54 项 Camera 回归。
- `before.png`、`after.png`、`migration_comparison.png`：实际 GPU 前后画面。
- `edited_fixture.tscn`、`edited_camera.png`：修改后保存重载的测试副本，不覆盖正式布局。
- `editable_coast_walk_normal.gif`：18 秒正常速度实际 Camera 走动，10 FPS 编码。

改动已直接接入本工作树中的独立海岸入口，办公楼和正式游戏入口未改动。
