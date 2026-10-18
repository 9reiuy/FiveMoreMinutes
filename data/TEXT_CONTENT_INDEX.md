# 剧情文本编辑索引

本目录中的 JSON 均为 UTF-8，只在游戏启动后读取；游戏不会自动改写这些文件。修改后重新运行游戏即可生效。

| 文件 | 内容 |
|---|---|
| `dialogue/bedroom.json` | 卧室人物、床、褪黑素与取餐对白及选择项 |
| `dialogue/hallway.json` | 走廊与门口对白 |
| `dialogue/computer.json` | 电脑内的剧情/记事本文字 |
| `dialogue/phone.json` | 在线！™消息模板与手机剧情反馈 |
| `dialogue/dream.json` | 梦境提示与特殊房间对白 |
| `dialogue/boss.json` | Boss相关对白预留入口 |
| `dialogue/common.json` | 动态通知与缺失内容的安全回退 |
| `text_events/opening.json` | 开场逐字演出 |
| `text_events/endings.json` | 正式结局逐字演出 |
| `text_events/nightmare.json` | 提前死亡的噩梦文字 |
| `text_events/story_events.json` | 醒来、失业、解锁和星期日事件文字 |

## 常用字段

- 改一句话：修改对应 `line` 的 `text`。
- 调逐字速度：修改 `typewriter_speed`，单位为“秒/字”；越小越快。
- 调整停顿：修改 `pre_delay` / `post_delay`，单位为秒。
- 改颜色与字号：修改 `text_color` / `font_size`。
- 改对齐和位置：修改 `alignment` / `position`。
- 改淡入淡出：修改 `fade_in` / `fade_out`。
- 改点击/自动继续：修改 `wait_for_input` / `auto_continue`。
- 改逐字声音：修改 `blip`。
- 改选择项：编辑 `choices` 数组；顺序就是显示顺序。
- 连接下一段对白：选择项的 `next` 填稳定 Dialogue ID，关闭则填 `close`。
- 执行玩法动作：只使用已登记的 `action_id`，不能填写脚本函数或代码。

## 数据约束

每个 Dialogue / Text Event 必须有唯一且稳定的 `id`，并至少有一条 `lines`。选项动作只允许代码白名单中的符号。格式、ID或引用错误会以 `[DIALOGUE DATA ERROR]` 输出文件、ID、行号和原因，并显示安全回退文本，不会执行任意代码。
