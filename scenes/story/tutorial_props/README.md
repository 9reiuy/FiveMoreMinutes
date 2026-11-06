# 教程使用正式楼层已批准家具

此目录由`tools/build_tutorial_approved_props.gd`从正式工程的`OfficeFurnitureCatalog.make_visual_for_style(kind,"approved_room")`和`furniture_face_textures.gd`生成。使用同一模型、32px/m逐面重排和稳定变体，不引用旧`art/Dream/3d_props`家具。

场景保存完整几何、逐面纹理和原着色器引用，Godot的3D编辑视图可以直接看到并移动这些实例。这里没有运行时隐藏旧家具再补一层贴图的依赖；正式家具将来更新时，重新执行生成器同步即可，不修改正式已批准的源资产。

当前种类：沙发、柜、档案架、工位、椅子、盆栽、茶几、饮水机。碰撞及路线由`chapter_tutorial_layout.tscn`的solid_size元数据负责，角色和训练交互仍用现有2D权威。
