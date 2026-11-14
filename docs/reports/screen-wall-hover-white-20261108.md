# 恢复电视设置白色悬停高亮 · 2026-11-08

滑杆、百分比数值、复选框外框及阴影品质左右箭头的白色悬停高亮已恢复。默认配色仍取主菜单蓝色；滑条轨道和条纹保持蓝色，选中行继续采用蓝色实心填充与深色文字。文字、布局、滑条几何、反色和既有动画保持。

上一轮统一染色把内容纹理中的白色交互高亮也重新染蓝，且自绘滑杆未保留白色游标。`screen_wall_pause_crt.gdshader` 现仅从内容纹理中识别明确的中性亮色，并让这部分白色通过CRT处理；普通文字、底色、玻璃反光和背景噪点继续沿用蓝色。`screen_wall_colors.gd` 恢复白色悬停色，`crt_striped_slider.gd` 将其用于I形游标，轨道和斜纹不变。

实际嵌入视口的OptionButton能触发鼠标进入，却未向原有 `gui_input` 回调提供鼠标移动事件，导致阴影品质箭头仍不能高亮。`screen_wall_pause_menu.gd` 使用已有弯曲屏幕坐标映射刷新箭头悬停颜色，离开或换页时清除；不改变按钮选择、点击、音量或切页行为。

最终验证为GameTestLab实际游戏暂停界面63项通过、0失败，引擎PID 75524、退出0。采用Compatibility + ANGLE / Direct3D11，1280×720，启动前私有静音配置、Dummy音频、低优先级，逐次运行；没有全机帧采集或新增性能认证。检查覆盖原暂停／设置行为，以及Camera中的白色滑杆和百分比、移开恢复蓝色、复选框白色边框、单侧箭头白色、选中深色文字。实际渲染画面已经人工检查。先前箭头未触发的两次结果和定位探针保留在证据目录，不作为通过结果。

证据位于 `.runtime/screen_wall_hover_white_20261108/`：最终原始结果为 `pause_hover_verified/lab_result.json`，总快照为 `validation.json`。实际Camera画面包括 `pause_settings.png`、`settings_hover_leave.png`、`settings_checkbox_hover.png`、`settings_cycle_hover.png`。测试文件为 `tests/screen_wall_pause_test.gd`。

主菜单屏幕控制器、电视模型、全局限帧、原试玩启动器、通用设置与选项控制器、辉光材质等10个保护文件的前后哈希一致。正式暂停和主菜单设置共用修正后的电视界面。唯一试玩入口仍为 `tools/preview_screen_wall.cmd`，不更改已解决整机卡顿的启动方式。其他已有工作区改动保留，未提交、合并、重置或清理。
