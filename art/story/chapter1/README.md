# 第一章原创像素道具

2026-10-29，由当前Codex会话按用户授权为FiveMinuteMore制作。这里的OBJ几何、逐面PNG及Emission蒙版由本工程原创配方生成；没有读取或复制signalis_re的模型、贴图或音频。不要把参考作品的授权或来源写成这些文件的来源。

- 可复现制作：`tools/build_chapter1_pixel_assets.py`，卧室形体配方为`tools/chapter1_pixel_asset_recipe.json`。
- 交付检查：`tools/check_chapter1_pixel_assets.py`；`asset_audit.json`保存各面物理跨度、分配像素、UV岛矩形、图集尺寸和三角面数。
- 1单位=1米；32px/m，每面最少1px，2px挤出留白、POT画布、Nearest、无Mip。
- 新材质roughness0.88，metallic0，specular0。仅LCD和指示灯有Emission，使用乘法蒙版，不给整张图集加白色自发光。
- 地面道具底面中心Y=0。camera_mount背面Z=0；camera_head是支架铰点下的可旋转子部件。
- 主家具104～344三角面，工作台288，摄像头与支架80＋20。地毯作为平面用途为12三角面。
- 保持完整顶面与结构性1px线条，禁止后续随意全铺噪点、烘焙固定投影或改变单件纹素密度。

同日精修：配方区分pillow/duvet/cuff/rug、wardrobe_door/book及worktop/toolbox等部件，生成被口与枕套缝、柜门通风槽、书脊标签、LCD窗口线和工具扣件。摄像头遮光罩与机身分色；几何面数、物理尺度和UV密度不变。屏幕Emission使用局部图案，不点亮整张图集。实机证据与限制见`docs/reports/chapter1-art-gameplay-revision-20261029.md`。

应用位置：`scenes/story/chapter_bedroom.tscn`、`scripts/story/surveillance_camera.gd`和`chapter_run.gd`。教程使用原有已批准道具，不从逆向目录导入替代物。实际Camera画面与流程检查见`docs/reports/chapter1-rollout-20261029.md`。
