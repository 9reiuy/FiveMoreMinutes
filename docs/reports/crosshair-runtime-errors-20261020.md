# 准心停更与 Godot 运行时报错修复

日期：2026-10-20。项目：`E:/GameProjects/FiveMinuteMore`。

## 结果

修复准心在武器完全就绪时停留在旧位置，以及真实用户日志里的物理查询回调创建拾取物／尸体形状、强转已释放血液对象的问题。保持准心外观、后坐力、瞄准坐标换算、伤害、掉枪参数及尸体寿命。

原始日志来自 `%APPDATA%/Godot/app_userdata/Five Minutes More改版/logs/godot.log`，读取时修改时间为 2026-10-20 13:00:38。副本：[user_godot.log](../../.runtime/crosshair_errors_20261020/user_godot.log)。没有修改用户存档。

## 根因与处理

- `scripts/ui/crosshair.gd`：重绘条件只检查颜色和后坐力。两者稳定后，绘制缓存不再更新，鼠标位置、弹药和换弹进度被遗漏。现将实际 HUD 瞄准位置和显示用弹药状态纳入重绘判断；完全静止时仍避免重复绘制。
- `scripts/dream/dream_3d_random_dungeon.gd`：投掷武器在真实碰撞回调内击杀敌人，死亡掉枪同步新增物理对象，触发 `Can't change this state while flushing queries`。现在事件发生时保存位置、房间与随机偏移，物理阶段结束后提交，并拒绝属于旧楼层的提交。普通非物理回调掉枪仍同步完成，坑洞回收坐标及冲量规则保持。
- `scripts/entities/corpse_contact_motion.gd`：同一死亡链路在活动物理空间设置传感器及添加形状。现在传感器加入场景前配置被动属性，延后添加胶囊形状；尸体接触节点仍立即可用。
- 出血对象池原先在有效性检查前进行 `as Node`，触发 `Trying to cast a freed object`。现先检查原始对象是否存活，再转换。

## 验证证据

| 验证 | 旧版 | 修复后 |
| --- | --- | --- |
| 准心实际 draw 信号、位置／映射／弹药／换弹变化 | 20 项中 8 失败 | 20 项，0 失败 |
| 真实 Area 碰撞回调创建尸体传感器 | 7 项中 1 失败，出现物理锁错误 | 7 项，0 失败 |
| 真实投掷刚体碰撞→敌人死亡→掉枪 | 10 项中 1 失败，出现原日志物理锁错误 | 10 项，0 失败 |
| 物理回调内换层后拒绝过期掉枪 | — | 4 项，0 失败 |
| 已释放出血对象池清理 | 4 项均失败，出现强转错误 | 4 项，0 失败 |
| 原有尸体碰撞／滑动回归 | — | 22 项，0 失败 |
| 原有 Employee Ragdoll Death 回归 | — | 全部通过 |
| 实际 Main 正式入口 GPU 验证 | — | 22 项，0 失败；退出码 0 |

GPU 验证使用 RTX 5070 Ti、GL Compatibility、1920×1080、实际生成楼层与原游戏 Camera，后台窗口运行，使用隔离测试存档。六个鼠标采样点均在白色就绪态、零后坐力下验证重绘，避免靠颜色渐变掩盖旧问题；打开手机暂停、关闭手机恢复后继续验证两个方向的鼠标跟随。未将本次录制作为性能基准。

- [准心跟随正常速度动图](../../.runtime/crosshair_errors_20261020/delivery/ready_pointer.gif)
- [手机开关后继续跟随正常速度动图](../../.runtime/crosshair_errors_20261020/delivery/phone_resume.gif)
- [GPU 采样与完整断言结果](../../.runtime/crosshair_errors_20261020/camera/report.json)
- [准心红绿日志目录](../../.runtime/crosshair_pointer_refresh_20261020)
- [实际投掷及出血对象红绿日志目录](../../.runtime/runtime_error_fix_20261020)
- [尸体传感器、原有接触回归及 GPU 日志目录](../../.runtime/crosshair_errors_20261020)

## 剩余诊断与范围

不能将本次结果描述成 Godot 全部日志清零：隔离测试环境仍报告系统根证书存储读取错误；正式 GPU 退出时仍有两个纹理 RID 泄漏及 RenderingServer 退出诊断，场景仍有既有锚点提示，原尸体接触测试也有退出资源提示。本轮三个已复现的运行时错误在对应修复后测试中不再出现。上述剩余项不在此次准心与死亡回调修复中扩展处理，保留原日志供后续定位。
