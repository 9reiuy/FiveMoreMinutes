# 叉车撞敌近战命中特效

2026-11-17，已接入当前共享敌人受伤路径和现有叉车关卡。

## 实现

- `scripts/entities/employee_enemy.gd`：将 `player_vehicle_impact` 加入现有月牙近战命中特效的受伤来源。只有实际扣血才生成，在致命受伤的死亡处理前生成一次。
- 复用 `spawn_melee_hit_feedback` 和 `melee_crescent_hit_3d.gd`，沿用敌人深度平面、楼层高度、生命周期与清理。方向使用已有撞击方向。
- 未改叉车伤害、击退、最低撞击速度、每个敌人0.75秒冷却或喷血逻辑。

## 验证

`tests/forklift_melee_feedback_test.gd`：Forward+ / Vulkan，1280×720原生显示，WASAPI音频路径，启动前私有静音配置并在重载后检查。PID 59800，退出码0，66项检查全部通过，引擎日志无ERROR/WARNING。

白盒和正式美术测试场均通过真实扫掠碰撞验证正撞、倒车、致命撞击；拒绝的伤害不生成特效，冷却内不重复生成，特效到期和场景重建后清理正常。随后通过当前1-2关卡入口的正撞、致命撞击和关卡卸载检查。未录制视频。

已查看实际Camera截图，敌人受撞位置可见现有白色近战命中特效：

- `.runtime/forklift_melee_feedback_20261117/production-art-forward.png`
- `.runtime/forklift_melee_feedback_20261117/chapter-forward.png`

原始日志、检查明细、进程退出记录及各撞击截图位于 `.runtime/forklift_melee_feedback_20261117/`。短窗口计时包含截图回读和保存，不能作为性能对照或全游戏性能认证。

工作区保留原有未提交与未跟踪改动；本轮仅修改上述共享敌人脚本，并新增本测试与本记录。没有提交或清理工作树。
