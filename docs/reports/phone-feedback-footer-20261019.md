# 手机按键、底部选择和背景修正

日期：2026-10-19。按用户本轮澄清实施：底部原有软键可选择，不增加第三排应用；取消的是打开手机时的全屏压暗。

## 实际结果

- 首页仍为原 2×2，底部位置不变。内容下方按 S 可选原“设置／返回”，原底栏内出现选择框；A／D 切换、W 回内容、E／Enter 确认。原 Q、鼠标、右键和 Esc 保留。
- 各页原软键同样可聚焦。滑杆在内容区仍左右调节；长消息和购物先滚动到底，再继续向下才进入软键。返回页面恢复触发前焦点，静止鼠标不抢走键盘选择。
- 圆盘方向倾斜由 0.095 加强到 0.16 rad，下压由 0.018 到 0.031 world；中心下压 0.038，软键 0.033。按住保持，松开约 6% 轻回弹；快速点按至少保留 120ms 可见按压，逻辑操作不延迟。关盖时继续完成按压反馈，完全关闭后归零。
- 手机遮罩着色 alpha 改为 0，保留透明输入屏障。没有改变世界灯光、相机、房间尺寸或场景外黑色区域。

## 真实输入通路修复

首次实际 GPU 检查发现，原机身虽然把正确坐标转发到屏幕，鼠标 motion 却没有进入 UI。原因是屏幕贴在 3D 模型上，缺少非 SubViewportContainer 场景必须手动提供的进入／离开通知。已在真实 LCD 进入／离开、拖动及关闭时同步通知；不是直接调用 UI 来绕过真实通路。[Godot Viewport 官方说明](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-notify-mouse-entered)。

修复前同一个完整通路专项确实失败，修复后通过；GPU 证据记录屏幕收到 motion=(30,219)，焦点 footer/home。鼠标点击、悬停、拖动和物理按键仍各走原逻辑入口。

## 验收证据

| 检查 | 本轮结果 |
|---|---|
| `tests/phone_footer_navigation_test.gd` | 54 项通过，包含完整机身投影 → 屏幕视口 → 底部 UI 的真实转发 |
| 原 `tests/phone_apps_ui_test.gd` | 38 项通过，设置、消息、购物和音乐业务保持 |
| 机身无窗口定量专项 | 21 项通过，含瞬时点按、按住、回弹、关盖、暂停与低时间倍率 |
| `tests/phone_feedback_delivery.gd` | 实际 Main + GPU，19 项通过，卧室／大厅正式入口 |
| `tests/phone_tab_full_dungeon_test.gd` | 本轮真实 GPU 完整生成楼层 31 项通过，16 房间／12 敌人；包含物理按住跨收起不误射、松开恢复、计时／镜头及场景中断 |

以上本轮合计 163 项检查通过。完整楼层证据在 `.runtime/phone_feedback_20261019/full_floor/results.json` 和 `full_floor.log`，使用真实 Input 单例事件，不以 UI 直接调用替代玩法输入隔离。

原应用测试只更新两条旧边缘断言：向下抵达底栏后，内容索引仍保留而焦点已进入 footer；没有删除业务断言。

GPU 为 RTX 5070 Ti，GL Compatibility，1920×1080 输出、640×360 逻辑画面。窗口始终后台最小化、无焦点。实际长按 depth≈0.031、yaw≈0.16；瞬时点按在真实提交帧中峰值约 0.991。快速点按量测时暂缓 PNG 编码并缓存真实帧，避免把截图编码耗时误计为按键未显示。

同一暂停镜头临时恢复旧 40% 遮罩作对照，再返回正式透明遮罩；采样背景区域总亮度从约 37.38 恢复为约 58.19。此值仅证明移除遮罩，没有调高世界灯光。卧室原时间推进、3D 原暂停与镜头恢复均检查通过。

## 可视化

目录 `.runtime/phone_feedback_20261019/delivery/`：

- `footer_selection.png`：原位置选中设置／返回，两张均为实际 Camera。
- `footer_navigation.gif`：WASD 与鼠标导航，正常速度。
- `button_feedback.gif`：实体圆盘、中心和两侧键的按压／回弹，正常速度局部裁切。
- `brightness_comparison.png`：同镜头恢复旧遮罩与当前透明遮罩对照。

原始 PNG、时间记录和断言为 `.runtime/phone_feedback_20261019/camera/report.json`；机身定量结果为 `shell_checks/results.json`。图片只裁切、最近邻缩放及添加说明文字；GIF 保留原始时间间隔，没有重绘或慢放。

## 日志边界

功能断言通过不代表引擎日志零诊断。本机仍有系统证书读取错误、既有场景锚点警告，以及退出时 2 个各 6888-byte 的纹理残留／RenderingServer teardown 诊断。本轮未扩展到系统证书或旧光标资源的修复。
