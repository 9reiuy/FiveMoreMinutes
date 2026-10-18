# 共享家具物理脚本（旧 2D 关卡已退役）

旧 2D Dream 的入口、房间模板及专用资源已移除，不再维护或扩展。
此目录保留 `chair_01.gd`、`hurtbox.gd`，它们仍被正式 3D 家具使用，不能删除。
3D 新手教程暂时保留，正常入口继续跳过教程并保留接待区。

以下为已退役模板的历史说明，不代表当前运行入口：

这些房间是可在 Godot 2D Editor 中直接编辑的正式地图模板：

- `room_start_01.tscn`：人工起始房，也是 Office 风格、TileSet、门和家具层级的标准。
- `room_large_01.tscn`：大房间，`448×352px`。
- `room_medium_01.tscn`：中房间，`320×256px`。
- `room_small_01.tscn`：小房间，`256×224px`。
- `room_boss_01.tscn`：Boss 大房间，中央保留 Boss 安全区。

## 编辑节点

- `GroundLayer`：手工地面 TileMapLayer。
- `WallLayer`：手工墙体 TileMapLayer，物理碰撞来自 TileSet。
- `DoorLayer`：运行时只显示本局实际激活的门；使用 `room_start_01` 的人工门图块组合。
- `DoorLayer/Entrances/*Sockets`：每个方向三个合法门锚点，可在 Editor 中按网格手工移动。
- `DoorLayer/Entrances/ActiveEntrances`：运行时真实 Area2D 入口容器，不要手工放永久 Trigger。
- `FurnitureSpawnArea`：随机家具候选 Marker2D；可手工增删或移动。
- `YSortRoot/PropsRoot`：固定家具和运行时随机家具容器。
- `GroundDebrisRoot`：本房间家具破坏碎片容器。
- `BossSpawn`：仅 Boss 房存在，随机家具会避开其安全半径。

所有正式 Office 房间的 `GroundLayer`、`WallLayer`、`DoorLayer` 使用：

`res://assets/Tilesets/tileset_dream.tres`

`RoomManager`只生成房间图、一次性选择 Socket、激活门、实例化一次随机家具并缓存房间状态；不会清空或重画手工的 Ground/Wall，也不会在重新进入时重新随机。
