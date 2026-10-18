# 按面受光房间预览（替代此前内容删减方案）

入口 `scenes/dream/preview/FaceShadingRoomPreview.tscn`，Godot 打开后 F6。
1：原显示；2：按面受光候选；L：主光方向旋转 90°。全程静音。
旧 QuietRoomArtPreview 入口同样指向修订后的显示协调器。

## 已确认范围

用户不要求真实遮挡投射阴影。本轮采用单方向光的面法线明暗档位，
仅中间受光角度使用屏幕 2×2 棋盘色交替。并非 4×4 Bayer 衰减量化，
不引入新的投影阴影。现有脚底/家具弱接触显示及角色链不在本轮调整范围。
正式楼层与物理、碰撞、武器数值、相机及地图角度不变。

## 内容及纹理

所有房内家具复用原样板 Mesh、子节点变换和附件，不再生成简化方块。
保留原材质的颜色、图集、裁切参数；StandardMaterial 显示面也转换为预览专用变体。
仅对预览材料进行修改，原资源不写回。按表面位置以 32 格/世界单位采样，
纹理图案仍保留原来的多像素色块；这是统一取样栅格，不声称重新绘制了所有旧图集。
纹理像素投影会随面朝向压缩，不能与屏幕输出像素大小混为一谈。
显示复用正式世界视口，Palette/像素化设置仍独立。

## 调研依据与界限

只读查看用户安装的 picoCAD2.exe 内嵌 LÖVE 数据：
src/3d/scene.lua（按面受光与明暗档位）、skrovet/graphics.lua（最近邻与屏幕棋盘）、
src/3d/texture.lua（128×128 图集）、src/modes/export_mode/export_mode.lua（导出画布）。
没有复制软件代码、素材或配色，没有修改安装目录。
官方手册 https://picocad.net/manual/ 确认 UV 映射与逐色明暗映射。
本项目使用独立实现；当前乘色档位仍不是 picoCAD 的逐颜色索引明暗表的精确复刻。

## 验证

tests/quiet_room_art_test.gd 检查原 Mesh/附件保留、物理位置不变、模式切换、
不新增投影阴影、方向统一更新。GPU 日志另行检查 shader compilation，
测试成功不能代替画面或用户验收。
加 -- --capture 输出 .runtime/face_art：四张模式/Palette 对比、两张光照方向及 36 帧移动。
tests/quiet_room_art_media.py 打包为无声 GIF。
设备 NVIDIA RTX 5070 Ti / Godot 4.7.1 Compatibility。
只验收候选小房间，未推广正式全楼层，未进行长时性能验收。

本轮 GPU/Headless 预览检查 257 项通过，正式 Dither 回归 2331 项通过。
GPU 日志无脚本/着色器编译错误；仍存在既有证书、Wacom、shader cache 写入及退出资源警告。
本轮差异空白检查通过（新增文件用 no-index 检查，退出码 1 表示存在新增差异）。
