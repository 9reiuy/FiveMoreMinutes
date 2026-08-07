extends Node2D

## 07:00 唤醒床视觉：位于世界层（z_index 高于地面 TileMap、低于 HUD），
## 位置由 dream_world 设为地图世界中心（或最近合法地面），不使用旧固定坐标。
## 只负责绘制，交互/结束逻辑仍由 dream_world 原唤醒流程处理。

var interaction_radius := 40.0


func _draw() -> void:
	# 与旧床绘制保持一致的造型：床体 + 枕头 + 交互范围提示圈。
	draw_rect(Rect2(-42, -22, 84, 49), Color("59505e"))
	draw_rect(Rect2(-34, -31, 33, 15), Color("989098"))
	draw_circle(Vector2.ZERO, interaction_radius, Color(0.6, 0.48, 0.55, 0.09))
