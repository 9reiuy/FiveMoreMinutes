# 翻盖手机设置可操作小样

> 历史版本记录：下文对应平面绘制机身的竖长屏版本。用户随后否决机身与参考视频的相似度，现已制作实体 3D 小样，见 `phone-settings-3d-sample-20261018.md`；本记录的截图与检查结果不能作为新版 3D 机身验收证据。

当前阶段：可操作小样完成，已按用户追加反馈把上屏改为竖长方形；正式入口尚未替换，等待外观确认后再推广。

## 当前外观与操作

- 灰白翻盖机，画面右侧略微倾斜，上屏蓝紫色，沿用中文像素字体。
- 根据追加反馈，上屏从 148×170 改为 **148×230**，机身从 180×320 延长为约 **180×380**。字体和机身宽度未拉伸。
- 在 640×360 界面中定位约 `(444,14)`，完整屏幕及方向／确认／返回键保留在画面内；数字键区自然超出下边缘。
- 提起与展开约 0.39 秒，合拢与收回约 0.44 秒。动画期间阻断屏幕和实体按键输入，暂停时动画仍正常运行。
- 鼠标点击和滑杆拖动、方向键／WASD、E／Enter、Esc，以及七个可点击实体键使用同一套页面逻辑。
- 六项现有设置分为声音和画面两页，真实绑定 SettingsManager，立即生效、自动保存并显示“已保存”。
- 主菜单设置、卧室应用主页和暂停主页均可预览；各自直接进入相应首页，翻开不要求指纹。

手机机身由原生 UI 绘制与真实 Control 组成，屏幕内容不是截图。没有采用所搜索的第三方手机模型；继续复用工程现有字体、音效及聊天购物组件。

## 可操作入口

启动文件：`E:/GameProjects/FiveMinuteMore/Phone Settings Sample.cmd`。

该文件由用户主动打开时才启动窗口；自动录制均在后台最小化执行。它将 APPDATA／LOCALAPPDATA 定位到工程 `.runtime/phone_settings_sample_playable/profile`，小样设置与存档不写入正式玩家配置。左上角预览按钮可以切换主菜单设置、卧室手机和游戏暂停，或重新打开手机。预览按钮不是拟定的正式手机界面的一部分。

真实入口场景：`scenes/ui/preview/PhoneSettingsSample.tscn`。启动文件中的 Godot 路径已核实存在；场景本身经过真实 Main 入口回归，未自动打开前台窗口。

## 实景交付

目录：`E:/GameProjects/FiveMinuteMore/.runtime/phone_settings_sample_20261018/`。

- `delivery/tall_screen_compare.png`：上一版偏方上屏与新版竖长屏的实际 GPU 画面对照。
- `delivery/phone_pages.png`：声音、画面、真实中文聊天和购物四页。
- `delivery/open_settings.gif`：提起展开、鼠标及实体键操作，约 3.13 秒，正常速度。
- `delivery/bedroom_pause.gif`：真实聊天滚动、实际购买、暂停及返回，约 6.27 秒，正常速度。
- `camera_tall/`：最终原始 1920×1080 GPU 截图、逐帧时间戳与结果；UI 基准为 640×360，设备 RTX 5070 Ti，GL Compatibility。

交付图片只作裁切、最近邻缩放及说明文字；GIF 使用录制的墙钟时间，不把慢放标成正常速度。完整录制日志为 `gpu_tall.log`。

## 小样功能验证

| 验证 | 结果 | 证据 |
|---|---|---|
| 手机组件、设置持久化／双向同步、音量上下界、鼠标、七键、长屏布局、分页、开合输入门控 | 130 项，0 失败，退出码 0 | `.runtime/phone_settings_sample_test/results.json` |
| 独立小样场景→实际 Main→卧室／大厅暂停／主菜单设置，真实页面挂载、场景切换清理、单手机及暂停原因隔离 | 41 项，0 失败，退出码 0 | `.runtime/phone_settings_sample_launcher_test/results.json` |
| 后台实际 GPU、倾斜屏幕真实点击、键盘、实体键、声音和画面设置、聊天滚动、购买余额／库存、卧室时间、关闭恢复及其他暂停原因保留 | 24 项，0 失败，退出码 0 | `camera_tall/report.json` |

小样的聊天和购物临时挂载现有卧室的真实 `OnlineScroll` 与 `QuicklinkScroll`，保留 `MessageList`、`QuicklinkContent.phone` 和原购买权威；关闭时还原父节点、尺寸与可见状态。没有重写聊天消息、价格、容量或余额规则。卧室日常手机不暂停计时，暂停模式只释放小样自身持有的原因。

专项验证不等于正式入口已经接入，也不代表已完成所有游戏回归或性能验收。

## 额外共享回归及未通过项

字体、像素化设置和配色设置三套共享回归通过，证据为 `shared_regression/results.json`。

旧 `phone_melatonin_currency_test` 未通过，不能计入成功：

- 原脚本在 SceneTree 初始化前预加载依赖，导致找不到 SettingsManager；仅将测试中的场景加载延后到启动后，未改变断言或产品行为。
- 默认 Headless 运行有 9 条断言失败、2 次运行时错误。
- 相同断言固定 60 FPS 重跑后，5 条手机解锁／主页／音效时序检查通过；仍有 4 条失败和 2 次运行时错误。
- 两条摇瓶断言相关测试访问已不存在的 `BOTTLE_GRAB_RECT`；另两条源码检查仍要求旧文件直接包含格式化调用，而当前调用在 `quicklink_content.gd`。本次没有扩大范围去修改这些旧断言或旧产品实现。
- 该旧测试未引用本次新机身、页面组件或小样入口。证据：`.runtime/phone_melatonin_currency_test.log`、`.runtime/phone_melatonin_currency_test_fixed60.log`。共享回归最初的启动失败另存 `shared_regression/phone_melatonin_currency_test/stderr.log`。

最终 GPU 录制无脚本／着色器编译错误。旧场景锚点警告、系统证书读取错误及退出时两张纹理的 RID 释放诊断仍出现；新小样机身、页面和宿主自身的布局警告已经修复。

## 尚未推广的内容

正式主菜单、正式卧室手机及全局暂停入口保持现状。认可新版比例和外观后，再统一接入正式入口，并完成消息／外卖状态、所有退出与返回链路、完整键鼠输入阻断及相关回归。原武器真实阴影补齐仍是另一项尚未完成的工作，本次没有修改其生产代码。
