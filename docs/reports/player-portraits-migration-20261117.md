# 主人公立绘迁移与接入 · 2026-11-17

用户指定 `C:\Users\Administrator\Desktop\新建文件夹` 的新角色及差分作为后续主人公立绘。已完成7张原文件的英文命名迁移，当前工作树正式对话已接入；未重新导出可执行文件。

## 文件

主目录为 `art/characters/player/portraits/`。原文件保存在 `source/`，只改文件名，SHA256与字节数均核对一致；核对完成后才移除桌面中的对应原文件，没有删除源文件夹或其他文件。原名及校验值保存在 `source/manifest.json`，本机迁移完成凭据为 `.runtime/player_portraits_20261117/migration_receipt.json`。

| 原名 | 迁入位置 | 游戏用图 |
| --- | --- | --- |
| 无表情.png | `source/player_base.png` | 无五官身体底图，参与所有合成 |
| 闭嘴.png | `source/expressions/player_mouth_closed.png` | `player_normal.png` |
| 张嘴.png | `source/expressions/player_mouth_open.png` | `player_mouth_open.png` |
| 闭眼.png | `source/expressions/player_eyes_closed.png` | `player_eyes_closed.png` |
| 猫眼.png | `source/expressions/player_cat_eyes.png` | `player_cat_eyes.png` |
| 难以置信.png | `source/expressions/player_disbelief.png` | `player_disbelief.png` |
| 受伤.png | `source/expressions/player_injured.png` | `player_injured.png` |

原图均为2296×3477，差分只包含五官，不能直接作为完整人物使用。`tools/build_player_portraits.gd` 使用本机Godot的Image叠合，保留原色、原透明度及原始像素，统一去除身体外侧空白，裁切源区域为 `(531,53,1099,3335)`；头发、手和脚均保留。六张结果是1099×3335的完整全身图。`source/.gdignore` 避免原始七张全画布与游戏成品重复加载。

## 游戏接入

- `scripts/ui/dialogue/player_portraits.gd` 提供统一默认图及按需加载的表情状态。
- 共享 `confirmation_dialog.gd` 和场景默认资源均指向新图，旧 `art/Chr/chr*.png` 不再被正式对话入口引用。
- CinematicDialogue改用新图的上半身区域 `(0,0,1099,1752)`，保持170×271显示框、左右站位、听者90%不透明度／压暗／下移、黑幕、文字和进出场时序。
- 后续按用户“只需要切换到状态”要求，已移除正常说话的张嘴／闭嘴循环。对话按 `expression` 选择固定状态，逐字显示与完成时均保持，不自动改回闭嘴；张嘴本身也是可明确指定的固定状态。支持 `normal/mouth_open/eyes_closed/cat_eyes/disbelief/injured`；旧fear/panic及hurt/pain映射见资产README。
- 卧室独白只显示主人公。大厅另一侧起初使用同素材占位，2026-11-18 已换成用户提供的[前台专属立绘](../../art/characters/receptionist/portraits/README.md)。
- 运行时直接取已导入PNG和AtlasTexture，不逐帧拼图、裁像素或生成图片。

## 固定表情状态的后续验证

用户要求取消对话时来回切换立绘后，共享确认框和CinematicDialogue都移除了逐字嘴型帧逻辑；外部大厅控制器的逐字进度只更新文字，不再给立绘分配帧。`mouth_open` 改为按需加载的明确状态，完成一句话时也保持，不自动切回闭嘴。原有进出场、听者压暗下移、选项与文字音效保留。

- 更新后的立绘检查36/36，PID55336，`.runtime/player_portraits_20261117/state_portraits/`；覆盖整句保持、六种状态、明确张嘴、说完保持和下一句切换状态。
- 对话逻辑53/53，PID42872，`.runtime/cinematic_dialogue_20261117/state_dialogue_logic/`；包括大厅原控制器推进文字而不改变立绘。
- 实际Main43/43，PID64432，`.runtime/cinematic_dialogue_20261117/state_dialogue_main/`；卧室与大厅各记录24帧的左右Texture实例ID及可见字符数，立绘在文字推进期间保持同一实例，记录为 `*_portrait_state.json`。已查看两个正式Camera画面。
- 三个测试均为启动前私有静音、Dummy音频、退出0；Main使用正式Forward+路径。没有重跑下面初次资产迁移的全场景性能采样，也不将其当作本轮新测数据。无新增美术或特效资源。

## 初次迁移验证与实际画面

全部测试使用启动前私有静音配置及Dummy音频，不改玩家音量或存档；测试进程已退出。

| 范围 | 结果 | PID／证据 |
| --- | --- | --- |
| 原图迁移 | 7/7 SHA256一致，桌面对应文件剩余0 | `.runtime/player_portraits_20261117/migration_manifest.json`、`migration_receipt.json` |
| 立绘、六表情、共享旧框、新框、嘴型、重开重置 | 33/33 | PID40808，`.runtime/player_portraits_20261117/portrait/` |
| 对话输入、分页、动画、选项、单人／双人 | 53/53 | PID67864，`.runtime/cinematic_dialogue_20261117/portraits_logic/` |
| 正式Main卧室→睡觉选项→大厅五句→抽牌→返回卧室 | 41/41 | PID55276，`.runtime/cinematic_dialogue_20261117/portraits_main/` |
| 独立GameTestLab白盒／正式美术、实际Camera、叠加烟雾、卸载 | 32/32 | PID68716，`.runtime/cinematic_dialogue_20261117/portraits_camera/` |

已人工查看正式Main的 `bedroom_dialogue.png` 和 `reception_dialogue.png`，确认五官叠合、上半身比例、左右翻转、单人隐藏右侧、双人明暗和文字安全区。完整运行画面见上述Main目录；源图和六表情的检查图在 `.runtime/player_portraits_20261117/`。

### 有界成本检查

Forward+／Vulkan，RTX5070Ti，1280×720原生世界、640×360逻辑UI；60帧上限、最小化强制绘制、Dummy音频。仓库、白盒、正式美术分别做未显示→对话→关闭的相同条件A/B/A，每组120帧。白盒与正式美术都保留四个房间、八名敌人及家具；重建和退出清理通过。新图已预先导入，采样为场景就绪后的局部成本，不包括全工程导入或完整启动。

| 采样 | P50 ms | P95 ms | P99 ms | 最大 ms | >20ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 仓库对话 | 16.642 | 17.454 | 17.617 | 17.808 | 0/120 |
| 白盒对话 | 16.631 | 17.362 | 17.505 | 17.855 | 0/120 |
| 正式美术对话 | 16.635 | 17.728 | 18.857 | 18.937 | 0/120 |
| 正式美术＋烟雾＋对话 | 16.651 | 18.240 | 24.364 | 27.147 | 4/150 |

对照原始CSV和全部A/B/A统计在Camera目录，样本不代表全游戏稳定帧率。烟雾叠加样本存在4次20ms以上间隔，本轮未改动烟雾或场景以降低数字。

全工程编辑器导入进程PID60236退出0，六张新PNG均成功导入；扫描同时遇到工程内已有的异常WAV测试夹具（RF64、RIFX、非PCM等），检查脚本因此报告全局导入错误。没有改这些无关文件；后续立绘、对话及两个原生运行测试没有脚本／Shader／资源错误。已有卧室weather锚点警告保留。

本轮只修改立绘资产、统一取图入口、共享默认资源和相应记录／检查。保留共享工作树其他改动，未提交、重置或清理其他内容。正常入口仍为 `tools/preview_screen_wall.cmd`，重开生效。
