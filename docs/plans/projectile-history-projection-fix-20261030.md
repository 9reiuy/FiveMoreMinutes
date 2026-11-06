# 子弹历史轨迹与教程投影修复（2026-10-30）

本次由 Codex 在当前正式工作树独立执行；未委派、未提交，也未修改参考游戏。范围为此前已授权的拖尾方向修复及教程开火链路，未调整武器伤害、速度、射程和碰撞规则。

## Enter-The-Nyangeon 的实际实现

只读查看 `C:/Users/Administrator/Desktop/临时/Enter-The-Nyangeon-main`：

- `scenes/line.gd:25` 起，每次物理更新向 Line2D 追加 `p1.position`，达到 `life_timer` 阈值后移除最旧点。它记录经过的位置，不读取摄像机或瞄准方向来生成一条假尾巴。
- `scenes/line.tscn` 设置 `top_level=true`，避免线条继承弹丸的旋转；曲线控制宽度，连接与端点为圆角。
- `script/player_bullet.gd:64` 将两条线的 `life_timer` 设为 4。注意 `>=4` 即移除首点，因此常态保留 3 个点，不能将其误写为严格 4 点或固定 0.066 秒寿命。
- `scenes/bullet/aris_bullet.tscn:29` 起为双层线，示例宽度 12 / 7。没有将这些宽度或资源直接照搬到当前镜头。
- 空闲时停用物理处理并清空点列表；复用时重新初始化。

## 当前工程的原因与修复

工程原本已有 0.06 秒、最多 16 个带时间戳的真实位置记录。问题在显示转换与教程注册，不应误称为本次才首次实现历史记录。

教程原先直接把地图 XY 轨迹放入朝向 Camera 的平面，缺少正式场景的枪口世界位置快照；同时 128×128 捕获配用了 (64,96) 锚点，头部偏离捕获中心，径向拖尾空间也不足。正式场景原来通过整体旋转修正朝向，仍不能准确保持透视缩短与历史拐点。

现在共享 `dream_3d_actor_depth_bridge.gd::project_projectile_history` 将每个历史点映射到开火时冻结的枪口世界原点，再分别投影到当前 Camera。每个点的射线与弹头所在的摄像机平面求交，转换为捕获像素。视觉子节点抵消弹丸根旋转，避免对已投影轨迹二次旋转。

镜头变换时重新投影显示，不推进历史时间、不修改存储点、不重新读取射手瞄准方向。依旧使用一份弹丸碰撞权威、一个弹头/轨迹纹理和同一个深度载体；不是新增伤害实体或两个分离弹头。

教程补齐枪口快照、桥接注册、512×512 居中捕获，并对枪火使用同一枪口。正常连射发现教程缺少 `spawn_shell_ejection`，会使步枪开火函数中断；已接入现有弹壳与被动捕获池。

## 验证与证据

证据目录：`.runtime/projectile_history_projection_20261030/`。

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| 旧教程注册重现 | 21 项中 10 项方向投影失败，最大误差 48.81px | 以测试开关复现旧捕获尺寸、锚点与缺失枪口注册；与新版使用相同 alpha 判据 |
| 新教程实际 GPU Camera | 21 / 0 失败，最大误差 0.75px | 八方向、移动/旋转镜头、弯折历史；读取真正 SubViewport 的可见像素，再经 Sprite3D 投影核对 |
| 正式楼层实际 GPU Camera | 21 / 0 失败，最大误差 0.76px | 经 main 进入正式关卡、实际捕获池；前半玩家、后半敌人枪口来源 |
| 历史/碰撞回归 | 19 / 0 失败 | 时间截断、慢动作、转弯、扫掠命中一次、阻挡后端点、40ms 终端消退 |
| 正常实射 | 4 / 0 失败 | 手枪/步枪/霰弹枪，20 次确认开火事件，命中教程测试体，移动镜头与侧向射击，阻挡后轨迹清理 |

命令（按顺序单独运行 GPU 项）：

```text
Godot --path . --script res://tests/projectile_camera_history_test.gd
Godot --path . --script res://tests/projectile_camera_history_test.gd -- --formal
Godot --headless --path . --script res://tests/projectile_history_trail_test.gd
Godot --path . --script res://tests/projectile_trail_live_sample.gd
```

旧注册重现：第一条命令附加 `-- --legacy`，预期非零退出及上述 10 个失败。测试使用隔离 APPDATA，不覆盖玩家存档。

八方向/弯折为固定弹丸历史的显示回归，不冒充正常实射。正常实射另录：`actual_fire_normal.gif`，实际 Camera 正常速度；`actual_fire_crop_normal.gif` 是同一录制的局部最近邻放大 2 倍，仍为正常速度。175 帧采样的时间跨度 6137ms，GIF 累计 6170ms（含最后一帧约 34ms）。采用累计时间边界舍入，避免将每个 33ms 都压成 30ms 而加快播放。

GPU 为 RTX 5070 Ti，后台最小化实际绘制。本次不以录屏采样声称达成稳定 60 FPS，也没有复跑整章故事与四种骨架的全部回归。

运行期这三类武器的缺失接口报错已消除。测试进程退出控制台仍出现基线已有的两份纹理清理错误（各 6888 bytes、RenderingServer 已退出）；功能检查通过不表示该退出清理问题已修复。部分 Control 的原有锚点警告也仍存在。
