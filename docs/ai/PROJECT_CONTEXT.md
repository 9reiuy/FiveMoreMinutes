# FiveMinuteMore 项目长期上下文

核实日期：2026-10-26。正式目录 `E:\GameProjects\FiveMinuteMore`。先读根目录 `AGENTS.md`；任务调度细节见 [WORKFLOW.md](WORKFLOW.md)。本文是可追溯的项目记忆，不是所有历史聊天、功能完成度或运行状态的保证。

## 信息等级与更新方式

- **当前事实**：本次实际读取的代码、配置、Git 状态；存在代码不等于已通过当前运行验收。
- **用户要求**：2026-10-26 本次完整指令，记作 U1；对冲突的旧调度要求具有优先效力。
- **已确认历史决策**：项目报告/计划记录用户批准，且与当前入口或代码交叉核对；历史测试只保留其原始范围。
- **设计意向/待核实**：用户重新提出但缺少完整实施证据，或只找到接口/资源，不能写成已交付。
- **过时/被替代**：保留原因和新来源，不能恢复成默认方案。以后仅增量更新已变化的条目、日期和来源，不覆盖用户有效内容。

## 游戏定位、循环与叙事

| 信息 | 状态与依据 |
| --- | --- |
| 单机 PC、卧室现实生活与梦境战斗相互影响；睡眠、压力、生活状态、结算和次日构成循环 | 早期用户会话 H1 有原始设想；当前 `scripts/app/main.gd` 的 `_start_story_dream`、`_show_dream`、`_show_results`、`_start_new_day` 与 `run_settlement.gd` 有现实/梦境状态路由。具体规则需读当前配置，不能直接沿用旧数值 |
| 荒诞职场、企业文化讽刺和黑色幽默；高强度战斗体验参考 Hotline Miami | U1 明确重申的产品方向。`data/text_events/opening.json` 有失眠、次日上班的叙事；办公楼、Employee 和神经质前台对话与该方向相符。不能据此宣称全部世界观、剧情或关卡已完成 |
| 原始“2D 心理恐怖 Survivor Roguelite / 自动攻击 / 7:00 继续赖床” | H1 的早期用户提案，不是当前全部玩法。正式工程现为 3D 办公楼显示、手动战斗与共享 2D 权威；旧 2D Dream 已退役，`GAMEPLAY_PARAMETERS.md` 标有旧 Hold F Wake 字段不再读取 |
| 明亮、复古的职场流行摇滚 BGM | U1 的历史设计意向；本次未从抽查历史原文确认其完整批准/落地过程，也未试听音源。不可仅凭文件名认定曲风全部达标 |
| 连杀的掌声、罐头笑声反馈 | 当前源码存在 `canned_laughter`、`audience_applause`、`golf_clap`，`SFXManager.trigger_multi_kill_reaction` 经 `dream_3d_run_interface.gd` 接入；属源码核实，非本次听觉试玩验收 |
| 战斗结束停音乐、回到安静环境 | U1 的方向。当前有 `finish_combat_music` / `apply_combat_finish` 及正式楼层调用，但本次未逐分支试听，不能宣称每种结束/异常路径都满足该体验 |

参考作品用于设计语言和机制启发，不复制其数值作为本项目平衡真值。未被任务明确包含的伤害、射速、弹速、地图和美术保持原样。

## 当前工程架构

来源：`project.godot`、下列实际源码和现有交付报告；本次未启动 Godot。

| 层 | 入口与职责 |
| --- | --- |
| 引擎/语言 | 项目声明 Godot 4.7，主要为 GDScript；历史测试多用 Godot 4.7.1 Compatibility。`tools/run_regression_suite.ps1` 的默认控制台路径目前存在，文件名不是本次引擎运行验证 |
| 正式入口 | `scenes/app/main.tscn` → `scripts/app/main.gd`；开场/主菜单、卧室、接待大厅、正式随机楼层、结算由 Main 路由 |
| 正式 3D Run | `scenes/dream/Dream3D_RandomDungeon.tscn` / `scripts/dream/dream_3d_random_dungeon.gd`（Node3D）；每次新 Run 新种子，3D 配置副本可覆盖 demo_config 基值 |
| 显示与战斗权威 | `dream_player.gd` 是 CharacterBody2D；`dream_3d_actor_depth_bridge.gd` 是被动 3D 显示桥，一个 2D owner、一个深度显示载体，不复制移动、伤害、计时器或碰撞权威。不能把所有 Node2D 当作旧关卡删除 |
| 配置/持久状态 | `resources/demo_config.tres`、`scripts/data/demo_config.gd`；`game_state_rules.gd`、`game_save_store.gd`、`day_start_snapshot.gd`、`run_settlement.gd` 分担状态、存档、日初回滚和结算 |
| Autoload | SettingsManager、DreamDisplayBootstrap、SFXManager、PauseManager、DreamTimeController、PerformanceMonitor，来源为 `project.godot` |
| UI/手机/对话 | `scripts/ui/`；`game_phone.gd`、`phone_apps_model.gd`、`phone_settings_screen.gd`、`flip_phone_shell.gd`；公共对话控制器和气泡位于 `scripts/ui/dialogue/` |
| 战斗与环境 | `scripts/entities/` 的玩家/Employee/投射物/尸体；`scripts/dream/` 的枪械规则、生成、家具/门窗、显示桥、灭火器、烟雾、灯光及楼层生命周期 |
| 数据与内容 | `data/dialogue/`、`data/text_events/`、`scripts/data/` 的卡牌/升级目录；`art/`、`assets/`、`sfx/` 为共享资产，不能只凭静态未引用清理 |
| 测试/工具 | `tests/*.gd`；`tools/regression_manifest_20261013.json` 和 `run_regression_suite.ps1` 区分 Headless/GPU/跳过项。Python、PowerShell、Node 工具辅助离线分析 |

正式默认 `STORY_TUTORIAL_ENABLED=false`，正常故事流程跳过教程；教程资源仍保留。不能恢复旧 2D Dream 作为 3D 配置失败的回退。

## 已确认的视觉与交互决策

1. **空间美术**：根 `AGENTS.md` 的十条准则原文保留：真实低模、32px/单位世界尺度、Nearest、完整顶/侧/背、真实动态灯光、高粗糙低反射、局部 Palette、人物像素公告板、家具功能分区和清晰动线、实际游戏 Camera 动态结果为最终标准。
2. **已批准办公楼美术**：`OFFICE_APPROVED_ART_INTEGRATION_2026_10_12.md` 记录已接入正式四骨架生成；不能把样板坐标伪装成随机内容或改变地图身份。样板素材、门窗、家具、绿植和夜景已有复用路径；报告的冻结渲染数字不等于交火 FPS。
3. **主菜单/暂停 UI**：当前 `main_menu.gd`、`pause_menu.gd`、`pixel_option_group.gd` 有 NieR 风格列表：蓝色 `#396FE2`、实心选中/反色文字、奶油色选中文字和约 0.20s 转场。这是这些界面的当前实现，不授权将全部 UI 重做为统一新风格。
4. **银白实体手机**：正式 Tab 手机的已确认 Q1–Q13 方案和交付在 `docs/plans/phone-tab-integration-20261018.md`、`docs/reports/phone-tab-integration-20261018.md`。同一部左侧手机、四宫格讯息/电话/音乐/购物、浅蓝灰背景、12px 中文像素字、真实实体键反馈、轻摆、动态投影点击。3D 打开时暂停战斗/计时并拉近角色；卧室时间/配送继续；开始界面和原 Esc 暂停入口保留。
5. **手机数据边界**：讯息读取真实存档；电话为说明占位；音乐控制已有 SFXManager，不能另建独立音频权威。正式楼层购物只读，卧室使用原扣款/库存/配送后端；环境反射是低清近似与 2D 回退，不是精确光追。
6. **对话**：`passive-npc-dialogue-delivery-20261015.md` 及其修正报告记录前台被动靠近“…”、E 开始五段台词、文字逐字生长气泡、头部锚点和屏幕约束；不自动弹全文、不出现旧选项、不在该对话中抽牌。旧塔罗大厅方案中“前台抽牌”的行为不能覆盖这个后续修订；独立卡牌系统仍保留。
7. **角色/刘海**：`side-bangs-rollout-20261020.md` 记录用户认可样板后要求推广；当前 `player_side_bangs.gd` 默认启用连续曲线，保留原 4×11 像素、固定发根、11px 弧长、延迟段和旧整片回退。相对置顶仅解决衣服遮挡，仍服从世界/家具遮挡。不能重绘原图或仅靠几何断言宣称无接缝。
8. **后处理与清晰 UI**：`player-hurt-world-anchor-postpalette-20261023.md` 记录受伤反馈按世界锚点、RGB/暗角位于 Palette 后，HUD/准星/交互文字/菜单保持独立清晰；不要让全屏效果污染清晰 UI。
9. **商店/卡牌/立绘完整规范**：已恢复上述手机购物边界、卡牌系统存在和人物像素表现；未恢复所有商店、卡牌详情和角色立绘的完整最终设计批准链。不能根据探索图或旧计划补造统一规范。

## 历史决策与不应重复的方案

| 决策/失败 | 有效范围与来源 |
| --- | --- |
| 永久退役旧 2D Dream，保留共享 2D 战斗、角色/武器、主菜单/卧室/3D 教程等 | `docs/legacy_2d_retirement.md`、当前 Main 和根 AGENTS；不得恢复旧入口或按目录名批量删资产 |
| 银白手机先样板、GPU Camera 审阅后正式推广 | H2 摘要记录样板当时未替换入口；后来的 phone-tab 计划及交付已经正式接入。不能把旧“等待推广”当成当前待办 |
| 连续曲线刘海代替有裁切感的分段效果 | 当前源码 + side-bangs 三份报告；共享顶点不等于切线连续，验收需找实际 render_root，不是只看源 Node2D |
| 橙色血液和 1px 像素增长等已确认表现不得随优化删减 | `firearm_revision_report.md`、`blood_revision_report.md` 与 H3；BlackBloodEffect 类名不表示实际应改成黑色 |
| 阴影合批、共享角色捕获大图集、角色阴影 MultiMesh 没有稳定耗时收益，不接入 | `REJECTED_SHADOW_BATCH_AND_BODY_ATLAS.md`；降低 draw call 不自动等于真实收益 |
| 相同家具 transform setter 省略、血迹若干微优化候选被回退 | `REJECTED_FURNITURE_TRANSFORM_GUARD.md`、`PERFORMANCE_REJECTED_BLOOD_CANDIDATES.md`；局部/冻结小收益或 P95 变差，不值得重加维护复杂度 |
| 手机不替换主菜单及 Esc 暂停界面、不重复购买/配送或 BGM 后端 | phone-tab 已确认方案替代早期扩大范围方案 |
| 烟雾旧时长/描边描述不能直接恢复 | 2026-10-23 初始报告后有 `extinguisher-smoke-12s-20261024.md` 和 `extinguisher-center-fusion-20261024.md` 后续修订，且相关源码当前仍有未提交改动；修改前读最新代码和报告，不抄旧参数 |

## 当前状态与未解决项（本次快照）

- HEAD `f1e9702f70f108510729e75637809d1d86cb088b`，分支 `wip/linux-migrate-20261018`；是 2026-10-26 的读取结果，不是未来保证。已有 16 个 tracked 修改和 18 个未跟踪文件需保留，包括性能记录器、烟雾/灭火器、血液、角色/敌人等，不能误算成本次改动。
- 当前有正式工作树和两个 detached 测试 Worktree：`E:\GameProjects\AIWorkspaces\parallel_dev_test_20261026\antigravity`、`...\codebuddy`。本次重新核对两树 HEAD 相同，各保留3个独立工具/测试/说明文件，哈希符合其最终报告；未整合到正式工作树。
- 并行历史测试证据 P1：Antigravity 16/16、CodeBuddy 17/17，各一次返工；主管3轮=规划1+集中验收2，执行期额外唤醒0。该口径是 AionUi turn_start，不是底层 API 请求/Token，也没有可推算的节省百分比。本次只读取证据，没有重跑开发测试。
- 测试基线工作树扫描曾报2处缺失脚本（hotel_robot_weapons.gd、drone_weapon_fire.gd）；本次再次检查磁盘状态仍缺失。它们是已记录的基线问题，本次不修复或静默删掉引用。
- 稳定 60 FPS 尚无完整达标证据。`performance-heartbeat-20261023.md` 明确存在峰值卡顿；冻结 Camera、旧变换诊断路径或单场景均不能替代正式 Main、交火、换层与中端显卡验收。
- `docs/PERFORMANCE_RECORDING.md` 描述当前未提交的性能记录功能；draw_span 是 CPU 绘制区间而非纯 GPU 时间；warmup、加载/暂停/失焦/报告、存活/死亡停留需分开，不把相关事件当成根因，不叠加嵌套父子阶段。
- 旧 2D 退役报告保留教程布局3项失败、退出资源诊断等历史限制；这些不是本次复现，既不宣称仍必现，也不宣称已修复。证书、Wacom、dummy renderer 等与脚本解析/断言失败分开报告。
- 四位 Agent 当前注册 online/队列 idle，只说明本次工具返回的连接状态；额度、权限弹窗和下一次模型调用仍可能失败。现有 Team/config 能力没有可用强制 Agent/model 锁接口。

## 用户工作习惯

- 先读项目、当前状态和已有方案，再问缺少的关键信息；不要把可以调查的问题抛回用户。原始会话 H2 2026-10-13 明确纠正了这一点。
- 历史重要方案用过交互式问题卡；仅当澄清确实必要时使用。明确“暂不实现”与明确“开始执行/推广”是不同授权边界，不能擅自扩范围，也不要已授权后反复询问。
- 优先复用现有状态、显示桥、输入和音频权威，不另搭重复系统。核心视觉可以 Codex 定目标、执行者写代码、Codex 必要时验收，并非所有视觉代码都由 Codex 写。
- 视觉交付须真实游戏 Camera，性能报告须说明硬件、入口、分辨率、负载、预热、样本和局限；不靠外部静止视口、Headless 或历史数字代替。
- 测试窗口隐藏/最小化、静音、隔离用户数据，GPU 测试串行；不抢用户主屏。断言、退出码、解析错误、引擎警告分别记录。
- 最新低频主管机制以 U1 和 WORKFLOW 为准：一次必要规划、按收益拆分、成员自主修复、一次终报、集中验收，无普通进度轮询。

## 恢复来源与未恢复范围

| ID | 实际读取来源与可靠性 |
| --- | --- |
| U1 | 2026-10-26 本次用户完整指令；最新团队架构、低频主管、指定 Agent 和产品方向要求 |
| H1 | 本机 Codex 会话 `019fc2b3-f55f-7f53-ba42-e9e8aa5db547`，2026-08-02，旧路径 E:\Agent\5MinuteMore\5min more。通过只读 state_5.sqlite 定位，仅读 user 消息定向提取；原始提案“卧室→梦境→闹钟→现实变化”可读。旧自动战斗/2D 范围已被当前工程替代 |
| H2 | 会话 `01a13323-580c-7452-a440-99a3a0f3413f` 的本机 JSONL（前64MiB定向阅读）及记忆摘要 `2026-10-13T02-41-56-Katx-silver_phone_sample_and_side_bangs_rollout.md`；结合项目 phone/side-bangs/性能报告。恢复了先调查、正式入口/Camera、样板确认和刘海推广等决策。未声称读完212MB会话 |
| H3 | 记忆摘要 `2026-10-02T15-35-47-MUnv-otxo_shooting_and_blood_effects_optimization.md`，会话ID `01a0fd41-df7a-7cb2-9f02-d99600b1dd11`；索引指向的 archived JSONL 当前不存在，因此只用摘要线索与现存 firearm/blood 报告核对，不当作已读原始聊天 |
| H4 | 本机项目会话 `01a04dd3-43f1-7103-b9f3-5af577e4fd99` 可读取，但本轮主题提取未找出可用于补充长期产品/视觉决策的信息；不补造结论 |
| P1 | 本机 `E:\GameProjects\AIWorkspaces\parallel_dev_test_20261026\reports\` 下 codex_invocations.json、worker_dispatch_trace.log、scope_integrity.json、team_tasks.json 及两位开发者最终报告；当前 Git/哈希已重新核对，历史性能/调用结论与当前状态分开 |

本次仅读取明确项目路径或已知项目会话ID的本机记录，未扫描无关聊天、未读取凭证、未同步云端历史。只读 SQLite/JSONL 是本机文件取证，不是官方跨产品会话恢复 API；不是“全部 Codex App/CLI 聊天已找回”。历史摘要的一个旧文件名已变化，原始 OTXO 归档路径有缺失。未找到的 BGM 风格批准链、全部立绘/商店/卡牌最终稿及原始完整世界观继续标记待核实。

记忆持久性来自这三份项目文档和助手入口规则，不承诺每个新会话自动具备全部历史。新任务前核对实际工程和最新用户要求，只读取相关条目即可。
