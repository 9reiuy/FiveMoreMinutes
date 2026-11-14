# 城市外景正式推广与楼体收口修正

2026-11-09，沿用20261108任务编号。正式入口为 `scenes/app/main.tscn`。已将批准的DepthShape03外景接到正式办公楼层，并完成用户追加的顶部缺口、灰白横条明度与摄像机遮挡恢复修正。

最后一次实际Main运行：`MainEntry03`，PID63672，2026-11-09 01:34:22–01:35:01，退出0，62/62检查通过，SCRIPT/SHADER/ERROR计数0。控件锚点警告与引擎既有 `OpVectorExtractDynamic`诊断仍保留。工作分支`wip/linux-migrate-20261018`，HEAD`3b456f30bbe885d9c90b451bba9ed09af70bb8ec`保持；没有提交、合并、重置或清理共享工作树。

## 正式覆盖及修改

唯一原有运行文件改动是 `scripts/dream/office_approved_art.gd:6` 的CITY预加载，改为 `res://scripts/dream/city/depth_shape_city.gd`。保留正式Main→接待区→真实电梯→随机办公层及下一层原流程；办公层仍只创建一套城市。教程、0-1和没有城市的室内不强加外景。

新增可分发文件共11份：

| 路径 | 用途 |
| --- | --- |
| `scripts/dream/city/depth_shape_city.gd` | 正式楼层适配、有限位置回退、地图缓存、上沿封口及原裁切标记联动 |
| `scripts/dream/city/depth_shape_source.gd` | 批准源的外景构建与材质实现；资源路径改为res，去除依赖缺失旧库的死分支；任意墙长沿用现有源模块拼接 |
| `shaders/dream3d/city/city_depth_shape.gdshader` | 批准的城市Shader，共享空气的广告锚点随当前地图更新 |
| `shaders/dream3d/city/own_depth_shape.gdshader` | 自身外皮，增加用户要求的局部夜间明度修正 |
| `shaders/dream3d/city/city_air_field.glsl` | 统一空气计算的作者源；运行程序使用相同函数正文 |
| `art/Dream/CityDepthShape/source_city_bank.res` | 已批准的周边楼宇、原广告及必要纹理 |
| `art/Dream/CityDepthShape/own_facade_bank.res` | 已批准的自身楼体组件与原材质纹理，原字节不变 |
| `art/Dream/CityDepthShape/reference_layout.res` | 批准参考布局及六块广告的固定安装记录 |
| `art/Dream/CityDepthShape/rigid_modules.res` | 五组已检查宿主/广告与自身106的物理安装依据 |
| `art/Dream/CityDepthShape/upper_seam_profiles.tres` | 21个源组件的133个顶部轮廓点，仅用于下述封口 |
| `art/Dream/CityDepthShape/SOURCES.md` | Suraj99、KitBash3D来源、许可和派生说明 |

五个资源均经实际运行的ResourceLoader检查，外部依赖为[]。正式代码没有从`.runtime`、Downloads、临时目录或本机绝对路径加载。试验工具和证据仍在`.runtime/city_formal_promotion_20261108`，不参与正常游戏运行。

`interior_void_geometry.gd`及`units/special_unit_spawner.gd`仍只使用旧CITY的拓扑辅助函数；独立`FurnitureTextureReview.tscn`保留原预览路径。这些不是正式办公层重复绘制旧城市的入口。

## 形体、随机性和两处圈注

周边普通楼宇的宽深比采用0.48、0.66、1、1.95、2.5等比例族及小幅扰动，独立改变占地、高度和四向朝向。近、中、远区保持不同高度与疏密。随机性随地图种子固定，行走时不会重新随机、漂移或改变外轮廓。参考源分支同时核对种子和真实墙段签名，不能仅凭seed42001把固定坐标强贴到其他楼层。

广告宿主和广告作为刚性整体移动、转向，保持原源比例、支脚支撑、材质、UV与原安装关系。根据实际楼层净距和各广告真实法线选择位置；常规墙段没有单视口投影fit时，仅作有限外包轮廓位置回退，继续检查真实楼层和相邻宿主包围盒。该回退只证明物理安放，明确没有宣称六块广告在一个Camera画面中全部可读。地图缓存最多4份，保存规划数据；不保存节点，也不逐帧重新搜索完整三角形。

图1顶部问题：原源外皮有斜面和外挑，原来的窄收口未覆盖完整顶部轮廓。新增一批合并的封口，从真实楼层边缘连接到源组件上沿轮廓，范围为Y=-0.24至-0.06米，最大外伸2.189米，仍在既有2.561米自身外皮界限内。封口没有碰撞、灯光或额外后处理通道；原组件库、原主外皮数组及广告安装位置不重建。

图2明度问题：`PlacementTrace04/views.json`通过实际Camera射线核对，偏白横条包含原ID9混凝土，另有ID7收边，并非全部是金属。正式自身Shader把不发光ConcreteA/B的夜间表面响应降为原系数的0.42；钢材17/50的夜间响应也局部下调，保留原纹理/原色和冷色环境层次。未改变室内灯、断电、全局曝光、紫色旧调色板状态或真实玻璃。

用户追加的摄像机裁切沿用原RoomVisibility地板/射线快照、软保留和已有`hidden_tower_tag`。相机进入单栋宿主时，对应楼体、附着广告与辉光同步裁切，离开后恢复，不隐藏全部城市。修正host=-1的自身106辉光被误判隐藏的问题。相对批准源，仅增加封口一批及按宿主分组辉光的一批，没有新灯或新后处理链。

## 最小准入和实际主入口

| 用例 | 结果与范围 |
| --- | --- |
| ModuleAdmission02 | 退出0/errors0；五组原刚性宿主广告证据；自身106支撑覆盖0.999497，载体不相交 |
| PlanAdmission04 | 退出0/errors0；A1/B2/C3/V3真实轮廓，471/499/493/478栋，全部6广告；宽深比中位1.862/1.930/1.913/1.888；封口25/52/44/45段 |
| MainSeedRegression01 | 退出0/errors0；真实失败的第二层种子3205237841单例回归，六牌及空间界限通过 |
| PlacementViews05 | 退出0/errors0；同3个可达窗边实际Camera，完整上沿与明度修正已由顾问逐图视觉准入 |
| FormalPair03 | 独立正式代码同条件旧/新对照，退出0/errors0；108家具、8敌人；约449/451px真实移动，30/32次开枪，血液、家具伤害、旧根释放及设置重载后私有静音通过 |
| MainEntry03 | 真实Main菜单、卧室、接待区、真实乘梯和两层办公区，62项通过，退出0/errors0 |

最终Main第一层seed1969325978、A1、524栋、6广告、宽深比中位1.886，库存171家具/25敌人/273玻璃；第二层seed4106116437、A1、477栋、6广告、中位1.917，库存112家具/20敌人/310玻璃。两个楼层各38个外景Mesh载体、1个外景SubViewport。第二次真实电梯释放旧城市/渲染根，下一层使用自己的种子与拓扑缓存键。内外Camera姿态一致，原裁切射线快照一致，内部640×360不变。

行走段在真实可达、碰撞通畅的边界上正常行走，无段内传送。五个实际Camera帧的隐藏宿主依次为0、-1、0、0、0，实际拍到了裁切和恢复；自身106辉光保持正确。同期敌人攻击的瞬时色差/闪光属于原战斗效果，原样保留，未把它归为城市瑕疵或静态无战斗画面。

全部运行保持Forward+/Vulkan、1280×720窗口、640×360世界、Nearest、现有原色。自动测试启动前使用私有Master=0/WASAPI，设置重载后复核，未改系统或玩家设置。最终03的10个被测运行源散列在Main全程前后相同。基线11个原正式文件中，只有CITY预加载文件变化，其余10个逐字节相同。

## 耗时证据及限制

设备为日志实际记录的NVIDIA GeForce RTX5070Ti，Godot4.7.1/a13da4feb，Forward+/Vulkan。以下百分位使用线性插值`(n-1)*q`，严格比较`>80ms`。按原始`Window.has_focus()`记录，早期FormalPair03两组全部focused=false；最终MainEntry03的927行全部focused=true，43个无读回移动间隔也全部true。两者焦点条件不同，不能直接横比为性能收益；约1秒观察也不能认证稳定60帧。

| 样本 | 间隔数 | P50 / P95 / P99 / max，ms | 严格>80 |
| --- | ---: | --- | ---: |
| FormalPair03旧城真实移动交战 | 134 | 33.146 / 37.435 / 58.142 / 91.510 | 1 |
| FormalPair03早期新城真实移动交战 | 212 | 20.787 / 25.952 / 27.241 / 31.954 | 0 |
| MainEntry03最终源无读回移动，约1秒 | 43 | 22.781 / 27.460 / 30.249 / 32.048 | 0 |
| MainEntry03全流程，所有阶段保留 | 927 | 16.879 / 31.931 / 227.661 / 5452.344 | 23 |

FormalPair03是单次旧→新、相同seed42001和负载的有界对照，早于最后的安放/封口/局部材质修正，不能冒充最终源A/B，也不能据此断言普遍性能收益。最终03另有对应源的短无读回观察，但仅约1秒，不能认证全游戏60帧。

最终927间隔中23个>80完整保留：Main初始阶段2、卧室阶段1、接待区/首层准备阶段10、第一层取图阶段1、含读回边界段2、第二次电梯/换层阶段6、第二层取图阶段1。命名为`camera_reception`的粗阶段也包含等待和首层准备，不能凭阶段名归因到单一渲染操作。含五次读回的约2.4秒段与纯移动耗时分开，不以取图耗时冒充稳定帧率。原配对首显旧4034.025/新4124.922ms、卸载旧169.431/新158.079ms也未删除。

失败记录不覆盖：MainEntry01缺第二层两广告；MainEntry02功能全部通过、引擎退出0，但严格守卫记录3条退出Texture诊断。定位为私有子测试遗漏父测试原有的两个自定义光标释放；03仅补回这两句清理后退出错误为0。没有为此改正式玩法或渲染退出逻辑。此前解析/配置/不全广告用例同样保留，不计为通过结果。

## 证据及回滚

证据根：`E:\GameProjects\FiveMinuteMore\.runtime\city_formal_promotion_20261108`。

- `final_facts.json`：最终源散列、基线保护、精确统计、全部23个>80事件、两层库存和裁切事件。
- `evidence/MainEntry03/main_entry.json`、`run.json`、`frames_raw.json`、`native_walk.json`及原始stdout/stderr：实际Main、62项结果、PID/退出、全帧与边界帧。
- `evidence/MainEntry03/office_floor_1_city_0.png`至`2.png`、`office_floor_2_city_0.png`和`boundary_walk_00.png`至`04.png`：真实Camera证据。
- `evidence/PlacementViews05/after_view_0.png`至`2.png`：对应本轮两处圈注的同机位修正。
- `evidence/FormalPair03`：同条件旧/新原始配对，适用上文明确的早期候选范围。
- `baseline/hashes.json`及逐文件基线副本：已有正式源保护记录。

回滚正式接线只需将`office_approved_art.gd`的CITY预加载恢复为`res://scripts/dream/preview/sample_neon_city.gd`，不要还原其他共享脏文件。新增资源可保留为未引用状态，不需要删除或清理工程。

原独立小样的冻结FD99候选、D1F68EF5选择器、BW10回滚及`Run_PERF009_Candidate.cmd`保持；没有新建试玩入口，没有重跑原840physics缓存。普通游戏仍使用既有`tools/preview_screen_wall.cmd`，其调用`launch_screen_wall.ps1`默认main模式进入正式`scenes/app/main.tscn`。顾问已独立读取最终日志及三张第一层、一张第二层、实际裁切/恢复Camera，并结合相同正式源的MainEntry02亮字实拍，最终视觉准入通过。最终功能、图形日志及有界耗时已通过；用户最终美术接受与全游戏长期性能不由本次短检查替代。
