# 下一阶段任务书：教程关空间重建、全局灯光动线、像素家具材质与演出玩法全面升级

**发布日期**：2026-10-29  
**前置交付核查**：针对 [chapter1-art-gameplay-revision-20261029.md](../reports/chapter1-art-gameplay-revision-20261029.md) 及 `.runtime/art_revision_20261029/` 实机证据的审计退回与重构指令  
**适用工程**：`E:\GameProjects\FiveMinuteMore`（Godot 4.7.1，`gl_compatibility`，`640×360` 视口）  
**刚性边界**：继续遵守 [art-direction-20261029.md](art-direction-20261029.md) 中的工程红线（不导入逆向资产、保留 2D 碰撞与伤害权威 + 3D 表现桥接、保留角色精灵与 1px 黑描边、保留卧室既有功能方位与章节状态数据兼容性）。

---

## 一、 前置交付报告核查结论（为什么上一轮视觉与体验不合格）

上一轮交付虽然跑通了功能断言（`29/31/42/100` 项自动化测试通过），但从实机 Camera 证据（`tutorial_guide.png`、`tutorial_range.png`、`workbench_42001_palette1.png`、`bedroom_comparison.png`）来看，**视觉、布局、灯光、贴图与玩法演出均存在严重缺陷，不予通过视觉签收**。经代码与渲染管线逐行排查，具体技术病灶如下：

### 1. 教程关（`tutorial_guide.png` / `tutorial_range.png`）：空旷如仓库、地面死黑、两侧墙爆亮、背景发紫发亮
1. **致命的顶灯自遮挡 Bug（导致地面死黑、两侧墙爆亮）**：
   - 在 [dream_3d_tutorial_room.gd](../../scripts/dream/dream_3d_tutorial_room.gd#L258-L270) 中，`CeilingFixture_%d` 灯具盒（`BoxMesh`，尺寸 `2.8 × 0.08 × 0.42`，位置 `y = 2.86`，底面在 `y = 2.82`）**未关闭阴影投射（默认 `cast_shadow = ON`）**；而 `CeilingSpot_%d`（`SpotLight3D`）被放置在 `pos + Vector3(0, -0.02, 0)` 即 `y = 2.84`（**嵌在不透明灯具盒内部**），且 [dream_night_lighting.gd](../../scripts/dream/dream_night_lighting.gd#L101) 开启了 `spot.shadow_enabled = true`。
   - 结果：顶灯向下的主光锥被自身的 `BoxMesh` 底面完全挡死，在地面投下覆盖全场的巨型黑影；光线只能从 `0.04m` 厚的灯盒侧面窄缝平射出去，把左右两侧 `3m` 高的实心墙上半截照得惨白刺眼。
2. **14m × 26m（364m²）单体大仓库 + 0° 正向隧道视角**：
   - [Dream3D_TutorialRoom.tscn](../../scenes/dream/Dream3D_TutorialRoom.tscn) 采用 `0°` 透视俯冲视角（Camera 在 `(0, 12, 12)`，`fov = 40`），且未像正式地牢 [Dream3D_RandomDungeon.tscn](../../scenes/dream/Dream3D_RandomDungeon.tscn#L21) 那样旋转 `45°` 构筑等轴测剖面空间。
   - 整个教程关是一个 `14 × 26` 的巨型长方体盒子，仅靠 4 块无贴图纯色 `BoxMesh` 矮挡板（`Divider18Left/Right`、`Divider10Left/Right`）假装分区，中间 70% 地面空无一物。
   - 左右两侧墙（`WestWall`、`EastWall`）未启用剖墙（`set_cutaway_mode` 仅对 `SouthWall` 调用），导致两堵 3 米高墙像隧道一样夹在画面两侧。
3. **墙外背景颜色过亮（蓝紫色死区）**：
   - 教程关墙外没有任何建筑底座/外立面遮罩，且 `Environment_tutorial` 的雾效与环境光（`fog_light_color = Color(0.30, 0.34, 0.43)`、`ambient_light_color = Color(0.20, 0.23, 0.29)`）叠加后处理调色板量化后，把画面左上角、右上角墙外的虚空染成了刺眼的亮蓝紫色（`#3b426b`），彻底破坏压抑暗场氛围。

### 2. 关卡灯光与动线设计（`workbench_42001_palette1.png`）：死白圆形光斑、毫无空间动线与功能锚定
1. **地面中央过曝死白圆斑**：
   - 在 [dream_3d_ceiling_lighting.gd](../../scripts/dream/dream_3d_ceiling_lighting.gd#L84-L115) 与 [Dream3D_RandomDungeon.tscn](../../scenes/dream/Dream3D_RandomDungeon.tscn) 中，`Environment_dungeon` 的 `ambient_light_energy = 0.38` 偏高，叠加房间中央向下的 `SpotLight3D`（`spot_attenuation = 0.20`、`spot_angle_attenuation = 0.15`）和 `RoomFillLight`，把浅色地面中心直接照成一团巨大的死白圆斑，吞没了玩家脚底、准星和交互提示，而房间四周既无窗户冷光切入，也无重点交互物的局部导视光。
2. **关键交互物与家具随机乱放，缺乏动线设计（Flow & Circulation）**：
   - 在 [chapter_run.gd](../../scripts/story/chapter_run.gd#L114-L120) 中，休息层（3F）维护台直接调用 `world._random_room_position(world.spawn_room_id, 40., avoid, true)` 扔在房间半中间，不靠墙、无电源线缆/地垫/工具架配套、无专用工位顶灯，像凭空掉在地上的积木。
   - 监控摄像头（[chapter_run.gd](../../scripts/story/chapter_run.gd#L76-L80)）盲目硬编码在 `bounds.position + (1.0, 2.1, 0.15)`，完全不检测该处是否有门洞、窗户或高柜。
   - 战斗房间的家具缺乏**掩体群组（Cover Clusters）、视线漏斗（Sightline Funnels）与迂回环线（Flanking Loops）**，动线松散无节奏。

### 3. 家具与环境贴图（`bedroom_comparison.png` / `tools/build_chapter1_pixel_assets.py`）：单色填色 + 1px 直线框，像劣质塑料积木
1. **程序化贴图生成器退化为“纯色块 + 1px 矩形框”**：
   - 查看 [build_chapter1_pixel_assets.py](../../tools/build_chapter1_pixel_assets.py#L88-L136)，所有 12 件资产的每个面仅用单一纯色填充（`Image.new('RGB', (w, h), color)`），顶面与侧面的明度差仅有 `6%`（`factor = 1.06 if n[1] > .65 else 1.0`），再用 `ImageDraw.rectangle` / `line` 画 1px 直线条充当“结构”。
   - **完全没有像素美术应有的体块明暗阶梯（Top / Front / Side 至少 3 阶分离）、内凹阴影（抽屉缝、书架内腔、柜门百叶深槽）、高光倒角（Bevel）、织物褶皱过渡与金属控制面板细节**。
2. **家具与地面/墙面明度糊成一团**：
   - 卧室与办公室中，家具明度（`0.30–0.45`）与地面（`0.39–0.47`）、墙面（`0.38–0.48`）几乎处于同一灰阶区间，导致床、书桌、衣柜、工作台全部融进灰蓝色背景里，体积感极差。

### 4. 演出与玩法反馈（`chapter_panel.gd` / `chapter_tutorial.gd` / `chapter_run.gd`）：生硬简陋
1. **全屏大红框打断节奏**：[chapter_panel.gd](../../scripts/story/chapter_panel.gd#L38-L41) 的 `command()` 每次触发（“答案在上层”、“肃清阻碍”、“校准通过”）都直接生成一个 `640×360` 的纯红 `ColorRect("a51c30")` 糊满全屏并锁死玩家移动，极其粗糙。
2. **教程木桩靶毫无机械/受击反馈**：[chapter_tutorial.gd](../../scripts/story/chapter_tutorial.gd#L82) 每帧强制 `range_dummy.set_physics_process(false)`，靶子既无靶道底座/受击闪白抖动/护甲条反馈，也没有射击工位的弹药/校准状态指示。
3. **休息层与 Boss 战缺乏演出张力**：休息层只是弹窗三选一；4F Boss（`报废宿主 01`）仅在半血时换一把步枪，缺少 Boss 房封锁灯光切换（琥珀/警报红墙灯）、阶段预警演出与场地掩体破坏/压迫感。

---

## 二、 下一阶段具体执行任务（TASK-01 ~ TASK-05）

### TASK-01（P0）：教程关空间架构、等轴视角与暗场背景彻底重做

**目标**：废除“14×26 空旷大仓库 + 0° 隧道视角 + 亮紫背景 + 纯色矮挡板”，将教程关重做为**紧凑、有真实建筑隔断与门洞、45° 等轴测剖面视角、墙外纯黑消光**的三段式地下校准设施。

#### 1. 视角、剖墙与墙外暗场消光（必改）
- **文件**：[Dream3D_TutorialRoom.tscn](../../scenes/dream/Dream3D_TutorialRoom.tscn)、[dream_3d_tutorial_room.gd](../../scripts/dream/dream_3d_tutorial_room.gd)、[dream_night_lighting.gd](../../scripts/dream/dream_night_lighting.gd)
- **镜头与旋转对齐正式关卡**：
  - 将教程关 3D 容器或相机角度改为与正式关卡一致的 **等轴测三面体构图**（建筑旋转 `30°~45°` 或等价斜向相机轴向，`fov = 35°`，平滑跟随玩家 `position_smoothing`），严禁再用固定不动的 `(0, 12, 12)` 0° 隧道俯冲镜头试图一眼塞下 26 米长的走廊。
  - **修复顶灯自遮挡 Bug**：所有 `CeilingFixture_*` / 灯具网格必须显式设置 `cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF`，且 `SpotLight3D` 位置必须位于灯具底面以下至少 `0.06m`（例如灯具在 `y = 2.88`，光源在 `y = 2.78`），彻底消除灯盒遮挡地面造成的全黑死影。
  - **墙外纯黑背景与建筑底座包边**：
    - 将 `Environment_tutorial` 的 `background_mode` 设为 `BG_COLOR`，`background_color = Color(0.008, 0.010, 0.016)`；大幅降低或关闭会把墙外虚空染亮的全局雾（`fog_enabled = false` 或仅对室内几何体生效），确保墙体以外的背景区域呈现**深邃纯正的冷黑暗场（明度 < 0.03）**，绝不允许再出现亮蓝紫色三角区。
    - 为前景/右侧遮挡视线的墙体启用 `set_cutaway_mode(..., true)`，保留低矮剖面墙基（配深色顶面封边条 Wall Cap），仅让北墙/西墙保持全高受光。

#### 2. 空间布局重做：从 364m² 空仓库改为“三室两门”紧凑序列（总面积缩减约 55%）
- **文件**：[chapter_tutorial_layout.tscn](../../scenes/story/chapter_tutorial_layout.tscn)、[dream_3d_tutorial_room.gd](../../scripts/dream/dream_3d_tutorial_room.gd)、[chapter_tutorial.gd](../../scripts/story/chapter_tutorial.gd)
- 删除原有的 `14 × 26` 单一大框及 `Divider18*`、`Divider10*`、`RouteMark*` 等纯色 `BoxMesh` 占位块，改为 **3 个尺寸紧凑、有真实内墙（带门框/玻璃观察窗）分隔的独立功能空间**：
  1. **Zone A — 报到与神经校准登记室（南区，约 `8m × 6.5m`）**：
     - 玩家出生在南侧入口缓冲垫上；左侧为档案柜与长椅等候区，右侧为 L 型登记服务台（配台灯、终端机、地面导引地毯），引导者站在登记台内侧偏旁预留交互位。
     - 北侧为第一道隔断内墙与通道门洞（未完成移动抵达/登记前，门旁指示灯为琥珀色，引导视线向北）。
  2. **Zone B — 机动冲刺测试走廊（中区，约 `5.5m × 7.5m`）**：
     - 窄长型测试通道，两侧墙面布置工业管道/储物柜与观察窗，消除多余空地。
     - 地面不再摆灰白色 `BoxMesh` 块，而是做成**嵌入式发光警戒地槽（起始待机黄线 + 脉冲能量跨栏带 + 北端达成感应区）**。玩家在南段黄线就位后，地面脉冲灯带亮起，冲刺越过即触发地面感应灯由琥珀变青绿。
  3. **Zone C — 封闭式实弹靶场（北区，约 `9m × 8m`）**：
     - 由南侧射击准备区（配枪械领用台、弹药柜、射击档位隔板/射击胸墙）与北侧受弹靶道区组成。
     - 玩家站在射击胸墙后方（有低矮掩体台面分隔玩家与靶场深处，杜绝“玩家直接走到靶子脸上贴脸站桩”的荒谬布局），向北侧靶道内的训练目标射击与换弹；东侧或北侧设校准通过后的重型气密出口门（配门楣状态灯：红 = 锁定，青绿 = 解锁开启）。

---

### TASK-02（P0）：全局与房间灯光重构（消除死白光斑，建立冷暖明暗层次）

**目标**：彻底解决 `workbench_42001_palette1.png` 中地面中心死白过曝、四角死灰无层次的问题，建立具有复古冷峻工业感的三层灯光体系。

- **文件**：[dream_3d_ceiling_lighting.gd](../../scripts/dream/dream_3d_ceiling_lighting.gd)、[Dream3D_RandomDungeon.tscn](../../scenes/dream/Dream3D_RandomDungeon.tscn)、[dream_night_lighting.gd](../../scripts/dream/dream_night_lighting.gd)、[chapter_wake_room.gd](../../scripts/story/chapter_wake_room.gd)
1. **压低全局底光，杜绝材质叠加过曝**：
   - 将 `Environment_dungeon` 的 `ambient_light_energy` 从 `0.38` 下调至 `0.15 ~ 0.18`（颜色偏深冷蓝灰 `Color(0.18, 0.22, 0.30)`），让未受光角落自然沉入深色阴影。
   - 移除或大幅削弱每个房间额外叠加的 `RoomFillLight`（`OmniLight3D` 能量上限 `<= 0.18`），避免 `SpotLight3D + OmniLight3D + 高 Ambient` 三重叠加把浅色地砖洗白。
2. **修正顶灯衰减曲线与地面最大亮度（硬性指标）**：
   - 在 [dream_3d_ceiling_lighting.gd](../../scripts/dream/dream_3d_ceiling_lighting.gd#L96-L102) 中，将 `SpotLight3D` 的 `spot_attenuation` 从 `0.20` 调回合理物理过渡（`0.65 ~ 0.95`），`spot_angle_attenuation` 调至 `0.45 ~ 0.65`，主光能量控制在 `0.85 ~ 1.25`。
   - **量化验收标准**：任何房间地面中心受光最亮处的采样 RGB 均值不得超过 `0.68`（严禁出现 `> 0.80` 的死白圆斑），且地面像素砖缝/地毯纹理在灯下必须清晰可辨。
3. **建立“主环境冷光 + 窗户月光/霓虹切光 + 关键交互点暖/青导视光”三层布光**：
   - **窗户定向冷光**：外墙带百叶窗的区域，向室内投射低角度冷青蓝色切光（与室内顶灯形成冷暖/明暗切割）。
   - **关键点功能导视光（Task Lighting）**：
     - 电梯门 / 出口门：门楣上方配置琥珀色（锁定）或青绿色（可通行）局部壁灯。
     - 休息层维护台：上方必须挂载专用暖白/琥珀工位吊灯（`SpotLight3D` 聚焦台面）+ 示波器微弱青色荧光。
     - 监控摄像头：镜头旁带微弱红色工作指示点，并在其朝向地面投射淡淡的扇形警戒冷光，让玩家无需贴脸就能感知监控区域。

---

### TASK-03（P0）：关卡动线设计、掩体群组与关键交互物空间锚定

**目标**：告别“空房间随机撒点”，让每个房间的家具布置服务于**寻路导视、视线遮挡与交火走位**。

- **文件**：[chapter_run.gd](../../scripts/story/chapter_run.gd)、`scripts/dream/` 下房间家具生成与布局脚本
1. **休息层（3F）维护台禁止随机抛洒，改为专属靠墙维护工位（Maintenance Bay）**：
   - 修改 [chapter_run.gd](../../scripts/story/chapter_run.gd#L114-L120) 的 `_build_terminal()`：严禁再使用 `_random_room_position` 把维护台扔在房间中央。
   - 必须选取房间北墙或西墙（非剖面高墙、避开门洞与窗户至少 `1.5m`）构建**完整维护工位组合**：
     - 主维护台靠墙摆放，朝向室内；
     - 两侧搭配落地储物柜/工具柜、地面深色防静电橡胶垫、墙面线槽/配电盒装饰与专用工位顶灯；
     - 玩家走入防静电地垫区域即可自然触发清晰交互。
2. **监控摄像头合法墙位锚定**：
   - 修改 [chapter_run.gd](../../scripts/story/chapter_run.gd#L76-L80)，摄像头安装位置必须经过墙面合法性检测（必须在实心高墙内侧、避开门框/窗户/高大书架，高度 `2.2m`，支架贴墙，机身朝向房间主通道中心）。
3. **战斗层（1F / 2F / 4F）动线与掩体群组重构**：
   - **主通道净空保证**：连接各房间门洞的轴线走廊或室内主干道保持 `2.2m` 清晰可辨的通行导视线（可用地面长条地毯或地砖拼花深浅色带引导玩家视线）。
   - **成组家具模块（Cluster Templates）替代单件散落**：
     - 办公区采用“L 型双工位 + 低矮隔板”、“中央会议桌 + 对称环绕路线”、“双排档案架走廊（形成天然侧翼绕后环线）”；
     - 确保玩家进入交火房间后，门内 `2.5m` 处必有第一处半高掩体（办公桌/低柜），不会开门即暴露在毫无掩体的空旷场地中央。

---

### TASK-04（P1）：像素家具与环境贴图深度重绘（告别单色线框积木）

**目标**：全面重写 [build_chapter1_pixel_assets.py](../../tools/build_chapter1_pixel_assets.py) 的贴图合成逻辑与 [office_pixel_materials.gd](../../scripts/dream/office_pixel_materials.gd) 的材质明度关系，在不改变 12 件资产物理包围盒与 `32px/m` 规格的前提下，让家具拥有**真正的复古像素体积感、材质肌理与明暗对比**。

- **文件**：[build_chapter1_pixel_assets.py](../../tools/build_chapter1_pixel_assets.py)、[office_pixel_materials.gd](../../scripts/dream/office_pixel_materials.gd)、[chapter_wake_room.gd](../../scripts/story/chapter_wake_room.gd)
1. **强制拉开“顶面 / 正面 / 侧面 / 底阴”四级固有色明度阶梯**：
   - 废除 [build_chapter1_pixel_assets.py](../../tools/build_chapter1_pixel_assets.py#L91) 中 `factor = 1.06 if n[1] > .65 else 1.0` 的扁平填色！
   - 烘焙进贴图的基础固有色必须按法线方向建立明确体积阶梯：
     - **顶面（Top，`ny > 0.6`）**：基准色 `× 1.22`（并带有 1px 亮边倒角高光 `× 1.32` 与内圈微暗过渡）；
     - **正面（Front，`nz > 0.5` 或主朝向面）**：基准色 `× 1.00`（带顶部台面投下的 `2~3px` 投影带 `× 0.72`）；
     - **侧面（Side，`abs(nx) > 0.5`）**：基准色 `× 0.78`；
     - **内腔 / 底部踢脚线（Recess / Plinth）**：基准色 `× 0.52 ~ 0.62`。
2. **逐资产补齐像素材质细节（禁止只画 1px 单纯矩形框）**：
   - **床（`bed`）**：枕头具有弧形蓬松明暗阶梯（中心亮、四周暗、床头压痕阴影）；被面做出横向织物折光条带与被口雙层反折阴影；床架木框与金属床腿分色明确。
   - **书桌（`desk`）与床头柜（`nightstand`）**：桌面设为暖胡桃木或深色耐磨层压板（带木纹/板材像素肌理与前缘高光），桌腿与抽屉柜体用深冷灰/浅灰对比色；抽屉面板上方画 `1px` 内凹暗线、下方画 `1px` 受光边，拉手有高光像素点。
   - **衣柜（`wardrobe`）与书架（`shelf`）**：书架搁板内部必须填充深色背板阴影（`× 0.48`），其上排列高低错落、宽窄不一、含 4~5 种低饱和复古色系的书脊与档案盒（带白色标签贴）；衣柜门板做出双层内嵌框线、百叶明暗凹凸与立柱阴影。
   - **维护台（`workbench`）**：台面区分深色防刮橡胶作业垫（带网格暗纹）、金属包边、左侧红色工具箱（带多层抽屉与金属搭扣高光）、右侧双联仪表机箱（深陷的暗色示波器/LCD 屏幕窗口、刻度网格、实体旋钮与状态指示灯）。
3. **拉开家具与地面/墙面的明度反差**：
   - 调整卧室与办公室地面/墙面基准色与家具配色的明度差，确保**家具主受光面与所处地面的明度差 `>= 0.16`**，并保留脚底接触阴影（Contact Shadow），杜绝家具融进地板。

---

### TASK-05（P1）：演出、UI 呈现与核心玩法体验打磨

**目标**：消除全屏红框打断、死板木桩与单调交互，提升教程、战斗、休息层与 Boss 战的沉浸式演出与操作爽快感。

- **文件**：[chapter_panel.gd](../../scripts/story/chapter_panel.gd)、[chapter_tutorial.gd](../../scripts/story/chapter_tutorial.gd)、[chapter_run.gd](../../scripts/story/chapter_run.gd)、[chapter_wake_room.gd](../../scripts/story/chapter_wake_room.gd)
1. **重构 `chapter_panel.gd` 的 `command()` 演出（废除全屏纯红 `ColorRect` 遮挡）**：
   - 将 `command(text)` 改为 **带 CRT 扫描线/微弱色差抖动的横向战术指令横幅（高度约 `56~68px`，位于屏幕中上方，上下带细金属/故障警戒线与左端系统代号前缀如 `[VLNK::DIRECTIVE]`）**，背景半透明深暗红/黑底，伴随短促指令音效；
   - 非阻塞或仅极短停顿（`<= 0.35s`），不再用一整块不透明红布糊满 `640×360` 屏幕并长时间剥夺玩家控制。
2. **教程关实弹靶场与冲刺机关玩法反馈升级**：
   - **训练目标（`range_dummy`）反应强化**：对话解锁实弹射击后，靶场灯光切换为战斗测试模式；每次命中目标时，触发明显的**受击闪白、像素火花、水平受击后仰抖动与靶位顶部命中计数/护甲衰减条反馈**；击破瞬间有靶标倒伏/断电演出。
   - **换弹教学直观化**：在射击台旁或准星旁同步显示清晰的弹药槽状态变化（`2/12 -> 0/12 [按 R 装填] -> 12/12`）。
3. **休息层（3F）与 Boss 层（4F）演出强化**：
   - **休息层维护台 UI**：打开维护台时，不再是简陋的灰框按钮，而是呈现带有设备自检参数与改装模块图标/数值对比的工业终端界面，选择升级后伴有角色脚下脉冲光环与音效反馈。
   - **4F Boss（`报废宿主 01`）场地与阶段演出**：
     - 首次进入 Boss 房时，门禁锁死，房间顶灯闪烁并切换为**低压琥珀/警报红边缘照明**；
     - Boss 血量降至 50% 切换突击步枪阶段时，触发短暂的过载脉冲特效、警告提示与走位压迫，而非静默换枪。

---

## 三、 验收与交付要求（Definition of Done）

1. **实机截图硬性对比证据（必须由 Godot 实际 Camera 在 `640×360` 渲染输出）**：
   - `tutorial_zone1_registration.png`（报到室：45° 等轴视角、墙外纯黑背景、顶灯无自遮挡黑影、登记台与引导者层次分明）；
   - `tutorial_zone2_dash_corridor.png`（冲刺走廊：紧凑通道、发光感应地槽）；
   - `tutorial_zone3_shooting_range.png`（实弹靶场：射击胸墙掩体、靶道、命中/换弹反馈）；
   - `dungeon_lighting_comparison.png` & `rest_floor_workbench_bay.png`（证明地面死白光斑已消除，地面最亮处 RGB 均值 `<= 0.68`，且休息层维护台已锚定为靠墙完整工位）；
   - `furniture_closeup_sheet.png` & `bedroom_overhaul.png`（展示重绘后的像素家具顶/正/侧面明暗阶梯、书架内腔书籍、维护台仪表与被褥褶皱，证明不再是单色线框积木）。
2. **自动化回归与资产检查**：
   - 保持 `tools/check_chapter1_pixel_assets.py`、`tests/chapter1_state_test.gd`、`tests/chapter1_art_revision.gd`、`tests/chapter1_layout_revision.gd`、`tests/chapter1_play_route.gd` 全部 `0` 失败通过，并补充针对新三室教程坐标、顶灯无阴影自遮挡、地面最高亮度上限及维护台靠墙锚定的断言。
