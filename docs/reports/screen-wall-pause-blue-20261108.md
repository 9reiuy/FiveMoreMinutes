# 暂停与设置统一蓝色 · 2026-11-08

按用户要求，正式暂停页、暂停进入的设置页以及主菜单进入的设置页，现均使用主菜单中间右侧 TV_04 的同一蓝色基准。文字、条纹滑条、屏幕辉光和电视光源已同步；选中时保留实心色块与背景色文字。

`scripts/ui/screen_wall_colors.gd` 提供共用颜色。主菜单原有的颜色增强公式原样移入该文件，保持原主菜单的颜色计算；暂停和滑条改为引用相同结果。暂停电视的 `base_tint` 同时更新，使每帧屏幕光源不会重新恢复旧色。

修改涉及 `scripts/preview/screen_wall_display.gd`、`scripts/ui/screen_wall_pause_menu.gd`、`screen_wall_pause_view.gd`、`crt_striped_slider.gd` 及上述新颜色文件。原文字内容、字体、字号、布局、滑条几何与拖动行为、选中反色、电视落下回弹和进入设置的扫描动画保持。阴影品质选择器继续隐藏重复的原生文字。

实际渲染验证在 GameTestLab 中串行运行，采用正式试玩已接受的 Compatibility + ANGLE / Direct3D11，1280×720，私有启动前静音配置、Dummy 音频及低优先级。暂停组55项、主菜单组63项，共118项通过／0失败，两个引擎进程均以0退出。覆盖暂停与主菜单两种设置入口、渲染颜色一致性、选中深色文字、条纹滑条拖动、阴影品质单份文字、原有动画、返回与重复打开、16:10窗口适配。已人工检查实际Camera输出的暂停选中、暂停设置及主菜单设置画面。

原始结果和Camera画面保存在 `.runtime/screen_wall_pause_blue_20261108/`，总记录为 `validation.json`。其中 `pause_blue/pause_hover_clean.png`、`pause_blue/pause_settings.png` 和 `menu_blue/settings_shared_television.png` 为本次检查的画面。此轮为颜色及界面功能验证，没有进行性能采集或新增全游戏性能结论。

8个保护文件的前后哈希一致：原试玩启动器与入口、全局限帧脚本、两个暂停材质、暂停选项控制器以及主菜单／暂停电视模型。正式主菜单与全局暂停场景直接使用这些改色脚本，无需另行推广。试玩入口仍为 `tools/preview_screen_wall.cmd`。共享工作区其他已有改动保留，未提交、重置、清理或合并。
