class_name SoftGlow
extends Node2D

const CONFIG := preload("res://resources/demo_config.tres")

## 低成本世界光晕：只绘制少量半透明像素圆，不参与实时照明，
## 可安全用于大量弹丸/掉落物，且仍会受到梦境CanvasModulate影响。
@export_enum("projectile", "pickup") var profile := "projectile"
@export var glow_color := Color("6fa8c4")
@export_range(0.0, 0.5, 0.01) var glow_alpha := 0.16
@export_range(2.0, 24.0, 1.0) var glow_radius := 9.0


func _ready() -> void:
	show_behind_parent = true
	if profile == "pickup":
		configure(glow_color if glow_color != Color("6fa8c4") else CONFIG.pickup_glow_color, CONFIG.pickup_glow_alpha, CONFIG.pickup_glow_radius)
	else:
		configure(CONFIG.projectile_glow_color, CONFIG.projectile_glow_alpha, CONFIG.projectile_glow_radius)
	queue_redraw()


func configure(color: Color, alpha: float, radius: float) -> void:
	glow_color = color
	glow_alpha = alpha
	glow_radius = radius
	queue_redraw()


func _draw() -> void:
	if glow_alpha <= 0.0 or glow_radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, glow_radius, Color(glow_color, glow_alpha * 0.22), true, -1.0, false)
	draw_circle(Vector2.ZERO, glow_radius * 0.66, Color(glow_color, glow_alpha * 0.42), true, -1.0, false)
	draw_circle(Vector2.ZERO, glow_radius * 0.34, Color(glow_color, glow_alpha * 0.72), true, -1.0, false)
