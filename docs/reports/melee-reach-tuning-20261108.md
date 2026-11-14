# 近战名称、范围与视觉调整 · 2026-11-08

已接入正式工程 E:/GameProjects/FiveMinuteMore。保留原武器图片、握持、伤害、攻速和持久化 ID。

| 武器 | 当前名称 | 玩家基础攻击距离 | 敌人原判定距离的比例 | 视觉比例 |
| --- | --- | ---: | ---: | ---: |
| melee_plank | 铁棍（原木板） | 80 | 100% | 100% |
| melee_machete | 铁棒（原砍刀） | 80 | 100% | 100% |
| melee_pipe / melee_pipe_wrench / melee_wrench / melee_crowbar | 弯管 / 管钳 / 扳手 / 撬棍 | 56（原80） | 70% | 70% |
| books | Books | 40（原80） | 50% | 50% |
| lucille | 露西尔 | 80 | 100% | 100% |

比例集中于 dream_gun_atlas.gd，玩家、敌人、攻击弧光、挥击拖尾、命中白光一致使用。距离加成也先加入原基础值再乘比例。冲刺命中白光保留原尺寸，不受手持 Books 影响。

Books 的实机测试曾发现：距离缩短后敌人的旧停步间距大于攻击距离。现已同步收紧短武器的期望间距，并保留身体碰撞下限；实际 AI 已能靠近并命中，伤害未改。

## 验证与证据

- 独立测试工程：.runtime/melee_reach_20261108/project。
- 规则386项、手臂回归174项、挥击57项、命中70项，共687项通过。
- GameTestLab 正式美术47项、白盒47项、正式工程来源47项通过；覆盖实际 Camera、攻击判定与视觉参数、真实 Books AI 命中、重建清理及私有静音。
- 实际 Camera 对照：.runtime/melee_reach_20261108/delivery/range_comparison.png；原图位于 before_art 与 formal_art。
- 原始失败记录保留：after_art 的 Books 停步缺陷已在 after_art02 修复；sweep_regression01 中 Books 旧范围断言已随新规则更新。
- 9个发布源文件的变更前后 SHA-256 分别在 baseline.json、published.json。后续投掷阴影修复独立登记。

## 有限负载性能对照

同一六个人形敌人、同一六把武器、实际玩家近战输入；Forward+ / RTX5070Ti、1280×720窗口、640×360世界画面、原灯光/阴影/反射/像素设置、WASAPI私有静音。预热后采样12秒，采样期间无截图回读。

| 条件 | 帧数 | P50 ms | P95 ms | P99 ms | 最大 ms | 超80ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 原范围 | 4195 | 2.693 | 4.566 | 6.091 | 12.866 | 0 |
| 新范围 | 4956 | 2.354 | 3.622 | 4.275 | 5.607 | 0 |

两个条件均为258个 SubViewport。该数据仅覆盖这组预热后的固定负载，不能作为全游戏稳定帧率认证，也不将较低耗时归因为本改动。原始帧数据保留在 perf_before01/result.raw.json、perf_after01/result.raw.json；result.json 的模板说明修正不影响数值。

所有自动测试进程均使用独立静音配置并已退出；玩家保存音量未修改。
