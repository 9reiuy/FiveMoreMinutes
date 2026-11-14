# 大厅原材质上的使用痕迹

2026-11-09。当前工作树 `wip/linux-migrate-20261018`，基线 HEAD `3b456f30bbe885d9c90b451bba9ed09af70bb8ec`。保留共享工作树，未提交。

用户授权改进前台表现后进一步明确：问题在于墙地过于干净，应在原贴图上增加参考图那样的使用痕迹。参考图用于局部划痕、边缘磨耗、积灰和污渍，不用于替换大堂的石材／木饰面。中途更换 Metro 砖及灰泥的方案已撤销，相关模块已移除，12份新候选文件已逐文件核验后移到 `.runtime/reception_material_depth_20261109/rejected_surface_sources/`；没有改动 Metro 工程。

## 当前效果和范围

- 地板继续使用 GreyMatteTiles01，维持原来的4×10米映射与砖缝。原石材上增加少量断续擦痕、板面色泽差、墙边／柜脚积灰和通行区域的光泽变化，积灰沿原图已有接缝增强。
- 墙面继续使用 NaturalStone01；适度显露原有细纹，墙脚与局部低处出现不均匀的污痕、积灰和少量竖向擦脏。高低地面分别计算墙脚高度，包含上方抬高的电梯厅。
- 前台和茶几继续使用原石、胡桃木和 Metal012，少量表面擦伤、局部边缘磨损改变颜色和粗糙度。磨损贴在物体上，没有添加全屏噪声、交叉排线、明暗交界抖动或黑描边。
- 前台石台面增加闭合小倒角，仍为0.78米顶高、0.16米厚；原平面范围和四面碰撞保持。底部后退形成踢脚，台面下增加窄金属收口。
- 灯光保持四盏有真实投影的顶灯，原55度灯锥、反向投影剔除及0.5／1.2投影偏移不改；前台偏暖、后厅偏冷中性，降低统一补光和高光的主导程度。两侧等候区各增加一盏小暖色墙面洗光灯，不新增投影灯。
- 玩家和NPC脚下复用现有 `shadow.png` 作小接触阴影；不代替家具／墙体的真实投影。保持角色原画和主游戏32像素尺度。

640×360、Nearest、32采样／米、Forward+／Vulkan、原色及红毯保持。T形布局、六部电梯、NPC位置、沙发朝向、0.18米前景可见墙高和现有交互保持。装饰塔罗牌及桌垫仍不生成，剧情发牌系统保留。

## 实际游戏 Camera

最终正式Main机位：

![前台](../../.runtime/reception_material_depth_20261109/final_camera02/counter_ui.png)

![等候区](../../.runtime/reception_material_depth_20261109/final_camera02/waiting_west_ui.png)

原分辨率图片与同机位开关证据位于 `.runtime/reception_material_depth_20261109/wear04/`。`*_without_wear.png` 仅关闭磨损层，保持同一套原图、灯光和几何；不等于整轮修改前的场景。整轮修改前证据为 `baseline01/`。局部变化强度按正常游戏镜头审查；图像没有锐化、降噪或生成式重绘。

![同机位局部对照，仅最近邻放大](../../.runtime/reception_material_depth_20261109/wear_detail_comparison.png)

## 验证

所有图形进程串行使用共享文件锁；启动前准备私有Master=0配置，并显式使用Dummy音频。未更改用户音量或停止其他进程。

| 验证 | 批次 / PID | 结果 |
| --- | --- | --- |
| 原图绑定／三机位磨损开关与恢复／接触阴影／无灯全黑 | wear04 / 43652 | 18项通过，退出0 |
| 圆形台面自阴影与真实地面投影 | shadow02 / 63708 | 12项通过，退出0 |
| 普通走动、E交谈、剧情发牌／选牌、经过台阶闸机到电梯 | route01 / 52784 | 26项通过，退出0 |
| 主菜单／卧室／大厅、B3实际乘梯、首层办公区控制恢复 | journey01 / 68840 | 24项通过，退出0 |
| 最终Main五机位、主游戏Camera参数、完整角色／NPC、六门布局 | final_camera02 / 34512 | 32项通过，退出0 |

共112项有界检查。三处磨损开／关／恢复的表面ROI复原差为0；实际地面投影仍有423个对照变化像素，台面24个取样点没有圆形自阴影暗点；关闭灯光后地面采样最大RGB为0。小接触阴影改变脚底附近24个像素。19张原图与已有来源清单SHA-256全部一致。

13份保护源保持基线散列，包含大厅场景／权威逻辑、NPC、玩家、共享角色桥、办公材质及家具生成器、乘梯交接、渲染配置、红毯和电梯门。保护复核为 `protection-review.json`，原图核对为 `original-images-check.json`。本轮最终代码未修改这些源；不是用回滚共享工作树获取一致性。

抬高区域道具按各自地面高度计算墙脚，实际乘梯和最终五机位检查覆盖该状态。最后一轮加强少量擦痕的对比后，重做磨损开关、圆斑与投影、五机位Camera检查；路线与交互实现未再修改。最后源文件散列记录在 `source-final.json`。

基线已有的Control锚点警告和退出阶段ImageTexture／RID清理诊断仍存在；本轮无新增脚本或着色器编译错误。Camera核对、功能检查和性能认证分别记录：本轮没有整局性能认证，也不把技术检查等同于用户视觉认可。

自有最终引擎进程已退出，包装器已归还持有的锁句柄；没有本轮待运行批次，用户试玩优先。

## 运行文件

修改：`reception_reference_layout.gd`、`reception_furniture_materials.gd`、`reception_actor_depth_bridge.gd`、`reception_lobby_surface.gdshader`、`reception_furniture_pbr.gdshader`。

新增：`reception_stone_edges.gd`、`reception_wear.gdshaderinc`、`reception_contact_shadow.gdshader`。新增回归用例 `tests/reception_surface_wear_camera_test.gd`。

沿用正式入口 `scenes/app/main.tscn` 中的大厅；没有新增试玩入口或修改其他关卡的材质。
