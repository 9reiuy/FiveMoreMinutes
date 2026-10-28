# 前台乘梯与提示文字（2026-10-27）

用户通过 Q1–Q4 确认启动：换弹和武器名使用受击文字同款字体、描边、网点阴影与入场弹出；固定触发时世界位置，镜头变化仍投影，换弹结束消失，武器名保持原时长。所有轿厢修复已有手臂姿态。前台 E 触发真实走路入梯、关门、至少三秒可移动轿厢、准备完成才到站出梯；这条正式入口不再全屏黑色加载。失败恢复原前台并允许重试。

执行：Codex 独立实现。已检查固定 Antigravity CLI 的帮助、模型和 Agent 查询：未登录，未调用任何开发模型；未启用其他 AI。保留本轮前已存在的 dirty 文件。正式工作树 E:/GameProjects/FiveMinuteMore，基线 f1e9702f70f108510729e75637809d1d86cb088b，分支 wip/linux-migrate-20261018。

复用：ComicPixelText、IndependentElevatorCab3D、现有 scripted locomotion、现有分批生成和渲染预热、SelectivePixelPreview 显示与坐标映射。目标世界在独立 World3D 中冻结准备，原前台轿厢保持可操作；提交现有显示实例，不复制角色逻辑或手臂资产。

边界：战斗数值、武器库存、地图生成规则、配色及已批准电梯资产保持现行规则；本轮替换前台进入游戏的加载展示。后台运行正式入口、故障注入重试、连续换层与回滚；实景动图保留正常时间节奏，不作为稳定 FPS 结论。GPU 测试串行，独立用户目录，窗口后台/屏外静音。

文件契约：main.gd 与 reception_elevator_journey.gd 负责入口事务；dream_3d_reception_room.gd 负责真实进梯/轿厢/返回；selective_pixel_preview.gd 负责准备状态及渲染隔离；world_status_word.gd 与 RandomDungeon 的提示入口负责文字；dream_player.gd 和 player_hand_presentation.gd 修复手臂；两份现有预热脚本允许已冻结的私有准备世界。增加定向测试和报告，保留无关工作。
