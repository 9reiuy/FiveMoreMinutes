# 无人机与送餐机器人描边偏移修复

日期：2026-11-02。Codex 在当前工作树实现；`outline_projection_review` 子智能体只读核对投影数学及最终修改，没有并行编辑或外发工程资料。一次生产代码修复后，投影和实景检查通过；测试脚本曾修正一处类型声明。未提交 Git，原工作树其它改动保留。

## 原因与修改

两类单位共用 `scripts/dream/units/special_unit_outline.gd`。整机轮廓通过裁剪相机拍成 mask，再贴回游戏世界。

- 正式显示使用 h/v 相机偏移稳定像素。旧算法使用不包含这些显示偏移的 `global_transform`，同时又调用包含偏移的投影接口；偏移被错误混入近裁剪面的 frustum offset，导致捕获轮廓与模型脱开。
- `frame_pre_draw` 回调里更新捕获相机、回贴平面和复制几何后，没有立即向渲染器提交变换，存在新投影参数配旧变换的同步缺口。
- 现在统一使用 `get_camera_transform()`；复制相机自身 h/v 清零，避免重复计算；捕获相机、回贴平面及复制网格赋值后立即 `force_update_transform()`。
- 原灰／白描边颜色、宽度、贴图、模型、光照、战斗与碰撞不修改，上一轮 `unit_visual_fx` 排除继续保留。

**归因勘误：CameraRig 的 0.8 缩放不是独立原因。** Camera3D 默认去除自身 basis 缩放。h/v 为零的缩放控制组，旧算法最大误差约 0.0116 像素；不能声称仅父级缩放会导致轮廓缩向画面中心。修复针对有效相机位姿不一致及变换提交时序。API 行为可对照 [Camera3D](https://github.com/godotengine/godot/blob/master/scene/3d/camera_3d.cpp) 与 [Node3D](https://github.com/godotengine/godot/blob/master/scene/3d/node_3d.cpp)；本机数值与 GPU 实测为本次验收依据。

## 验证结果

### 投影组合：120 组通过

`tests/special_unit_outline_projection_test.gd` 使用正式场景原 CameraRig 和两类原模型，覆盖 640×360／960×540、父 rig 1.0／0.8、h/v 零及正负偏移、中心及四周位置、模型转角。逐顶点计算“源几何投影→裁剪捕获→回贴平面→真实相机”的屏幕误差。

- 修复前控制组合最大误差：147.055 渲染像素；这是含人工正负 h/v 的控制组合，不是正式游戏中固定发生的偏移量。
- 修复后最大误差：0.0201 渲染像素，低于 0.05 验收阈值。

### 正式 Main GPU：16 项通过

`tests/special_unit_outline_camera_review.gd` 从 `scenes/app/main.tscn` 进入正式楼层，固定种子 1748751541，使用实际生成的无人机和机器人。真实 GPU / Compatibility / RTX 5070 Ti，后台最小化。

独立参考视口将实际模型几何绘成红 mask，将现有轮廓捕获纹理按真实回贴平面绘成绿 mask；匹配时为黄色，脱开时出现红／绿分离。比较的是实际栅格化结果，并非只断言复制节点坐标相同。

| 静态实景样本 | 修复前重心偏差 | 修复后重心偏差 |
|---|---:|---:|
| 无人机 | 12.230 px | 0.025 px |
| 机器人 | 43.328 px | 0.012 px |

8 个静止／移动／转向抽样各做两项检查，共 16/16 通过。最大重心误差 0.091 px；所有样本超出一像素邻域容差的 mask 像素比例为 0。

无人机片段使用原巡逻逻辑；机器人片段在测试中控制原 2D 单位位置和朝向，以验证移动与转向时的轮廓跟随，不能当作机器人自然寻路测试。每类 45 帧，动图按图像采集文件的实际写入间隔抽帧播放，包含测量带来的间隔，不用于性能评估。

### 实体功能回归：47 项通过

`tests/special_units_hotel_robot_drone_test.gd` 验证生成、伤害代理、枪口／弹道、开火、受击及死亡移除。没有修改这些玩法参数。

## 画面与日志

- [前后局部对照](../../.runtime/unit_outline_alignment_20261102/outline_compare.png)：分别以实际源几何重心裁取局部，2 倍 Nearest 放大；前后 Camera 位置有轻微差异，不冒充逐像素同帧 A/B。
- [无人机动态跟随](../../.runtime/unit_outline_alignment_20261102/drone_outline_motion.gif)
- [机器人动态跟随](../../.runtime/unit_outline_alignment_20261102/robot_outline_motion.gif)
- [投影组合数据](../../.runtime/unit_outline_alignment_20261102/projection_after.json)
- [GPU 栅格测量](../../.runtime/unit_outline_alignment_20261102/camera_after.json)
- [GPU 测试日志](../../.runtime/unit_outline_alignment_20261102/camera_after.log)
- [功能回归日志](../../.runtime/unit_outline_alignment_20261102/special_units.log)

运行方式：`Godot_v4.7.1-stable_win64_console.exe --path . --script <测试路径>`；仅投影组合及实体逻辑测试加 `--headless`。APPDATA 均隔离在本次 `.runtime` 目录。

本轮仍观察到测试退出时的纹理／资源释放告警，详见 `camera_after_console.log` 与 `special_units_console.log`，没有宣称所有引擎告警清零。没有做全战斗路线稳定 60 FPS 验收；本次结论仅覆盖轮廓对齐和上述功能回归。
