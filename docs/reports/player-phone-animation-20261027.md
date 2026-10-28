# 新角色手机动画接入（2026-10-27）

## 角色素材与行为

使用用户新绘制的 `art/Dream/dream_chr_32x32.png`，原图280×250，实际最后一排位于 y=192，不能按“图高减32”取帧。有效角色六帧为 x=0/32/64/96/128/160，第七格 x=192 是半透明蓝色蒙版；其后与底部还有透明画布。

Tab 打开时按前四帧顺序播放（每帧80ms），之后循环第5、6帧（每帧250ms）。关闭时从当前阶段倒放收起，再恢复原站姿；快速关闭不会跳到尚未播放的打开帧。暂停世界时由现有 GamePhone 的实时时钟推进角色演出，不放开移动、攻击、世界计时或AI。场景切换会释放演出、蒙版亮光、暂停和原分支显隐。

角色新整帧替代普通身体/头发/手部/武器分支，保留原脚底世界锚点和角色缩放，退出后恢复各分支原显隐。仍由真实 ActorDepthBridge 捕获和原空间遮挡绘制，没有HUD贴脸或另建角色逻辑。

蓝色格只作为头部局部光蒙版，不参与角色帧循环。将原32×32蒙版映射到真实角色捕获坐标，在角色材质中局部加亮，保持眼睛与原像素明暗。其余角色、家具与世界材质默认不开启此功能。

## 与卧室相同的频闪

将卧室原 `_next_bedroom_chr_glow_alpha` 的算法提取为共享 `screen_glow_flicker.gd`，卧室仍调用同一规则和配置。通常在0.68–0.86范围跳变，少量变化到0.55–0.68或0.86–0.95；间隔沿用配置0.06–0.18秒。只改变局部屏幕亮光，不让整个角色可见性频闪，不使用每帧随机或正弦呼吸代替视频画面的不规则硬切。新角色演出使用独立随机源，不影响战斗和地图随机序列。

原PNG未修改；接入前后 SHA256 均为 `97632E660F4F3E3C30207C9A8F2C3D49F13432EFD3B79D31AB316C8DBAF42783`。

## 验证

实际执行者：Codex独立执行，沿用用户要求不调用子智能体。当前正式工作树 `E:/GameProjects/FiveMinuteMore`，保留原有未提交修改与用户的素材删除；未提交或合并。

Godot4.7.1，RTX5070Ti，Compatibility；独立用户目录 `.runtime/phone_actor_20261027/profile`。测试命令公共参数为 `--path . --audio-driver Dummy --script res://tests/<测试名>`；逻辑测试添加 `--headless`。GPU以屏外窗口启动，由 background_gpu 保持最小化、静音，实际Camera输出1280×720。

| 测试 | 结果 |
| --- | --- |
| player_phone_animation_test.gd | 20项通过，退出码0：帧序、循环、精确蒙版、恢复、原图哈希、局部光、共享卧室规则与随机源隔离 |
| player_phone_camera_delivery.gd | 22项通过，退出码0：真实 Main 中大厅和正式楼层的Tab打开/循环/关闭、暂停中继续演出、WASD不移动角色、材质蒙版实际改变头部GPU像素、切场景清理 |
| player_hand_presentation_test.gd | 174项通过，退出码0：原手持和空手展示回归 |
| phone_tab_full_dungeon_test.gd | 31项通过，退出码0：正式手机原有镜头、计时、购物只读、真实按键隔离、退出恢复、卧室与剧情效果路由 |

以上共247项通过。运行日志与Camera逐帧文件见 `.runtime/phone_actor_20261027/`。首次导入发现一处动态变量类型推断错误，已修正；第一次实景发现退出清理中手部读取已退出的摄像机，已增加生命周期保护，最终GPU复验不再出现这类摄像机错误。图集源已重新导入。

额外尝试旧 `bedroom_art_test.gd` 未完成：它在SceneTree初始化前预加载卧室，导致旧 bedroom_phone.gd 编译时未识别 SettingsManager，随后测试陷入无效Control调用；已终止该测试，保留 bedroom.log，不将其计为通过，也未为使旧测试通过修改卧室业务。实际Main进入卧室的31项手机回归和共享频闪定向检查已通过。

日志仍有既有布局、dummy renderer材质与退出时纹理/RID/资源诊断；没有宣称全工程零错误或稳定帧率。

## 可视化交付

- `delivery/lobby_normal.gif`：大厅真实Tab演出，正常速度，包含打开/循环/关闭。
- `delivery/floor_normal.gif`：正式楼层真实Tab演出，正常速度。
- `delivery/loop_glow_normal.gif`：原像素最近邻放大的两帧循环与局部光跳变，正常速度。
- `delivery/mask_light_comparison.png`：同一正式Camera固定姿态下，仅开关局部光的对照。

改变文件：新增 player_phone_presentation.gd、screen_glow_flicker.gd 与两份定向测试；game_phone.gd接演出生命周期；bedroom.gd改为共享原频闪算法；lit_pixel_carrier.gdshader增加默认关闭的局部蒙版参数；player_hand_presentation.gd增加退出摄像机保护。现有手机布局、按键、暂停、镜头、购买及卧室计时规则保持现行流程。
