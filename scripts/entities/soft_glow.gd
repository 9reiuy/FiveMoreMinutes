class_name SoftGlow
extends Node2D

const CONFIG := preload("res://resources/demo_config.tres")

## 低成本世界光晕：正式敌人、弹丸和掉落物共用一个Additive/Unshaded
## Material，不创建大量PointLight2D或独立GradientTexture。
@export_enum("projectile", "pickup", "enemy") var profile := "projectile"
@export var glow_color := Color("6fa8c4")
@export_range(0.0, 0.5, 0.01) var glow_alpha := 0.16
@export_range(0.0, 128.0, 1.0) var glow_radius := 9.0
var environment_glow_color := Color("e7f0f8")
var environment_glow_alpha := 0.0
var environment_glow_radius := 0.0

static var _shared_additive_material: CanvasItemMaterial


func _ready() -> void:
	show_behind_parent = true
	if _shared_additive_material == null:
		_shared_additive_material = CanvasItemMaterial.new()
		_shared_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_additive_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _shared_additive_material
	if profile == "pickup":
		configure(glow_color if glow_color != Color("6fa8c4") else CONFIG.pickup_glow_color, CONFIG.pickup_glow_alpha, CONFIG.pickup_glow_radius)
	elif profile == "enemy":
		configure(CONFIG.player_light_color, 0.0, 0.0)
	else:
		configure(CONFIG.projectile_glow_color, CONFIG.projectile_glow_alpha, CONFIG.projectile_glow_radius)
	queue_redraw()


func configure(color: Color, alpha: float, radius: float) -> void:
	glow_color = color
	glow_alpha = alpha
	glow_radius = radius
	queue_redraw()


func configure_environment(color: Color, alpha: float, radius: float) -> void:
	environment_glow_color = color
	environment_glow_alpha = clampf(alpha, 0.0, 0.5)
	environment_glow_radius = maxf(radius, 0.0)
	queue_redraw()


func _draw() -> void:
	if environment_glow_alpha > 0.0 and environment_glow_radius > 0.0:
		draw_circle(Vector2.ZERO, environment_glow_radius, Color(environment_glow_color, environment_glow_alpha * 0.10), true, -1.0, false)
		draw_circle(Vector2.ZERO, environment_glow_radius * 0.72, Color(environment_glow_color, environment_glow_alpha * 0.18), true, -1.0, false)
		draw_circle(Vector2.ZERO, environment_glow_radius * 0.42, Color(environment_glow_color, environment_glow_alpha * 0.28), true, -1.0, false)
	if glow_alpha > 0.0 and glow_radius > 0.0:
		draw_circle(Vector2.ZERO, glow_radius, Color(glow_color, glow_alpha * 0.22), true, -1.0, false)
		draw_circle(Vector2.ZERO, glow_radius * 0.66, Color(glow_color, glow_alpha * 0.42), true, -1.0, false)
		draw_circle(Vector2.ZERO, glow_radius * 0.34, Color(glow_color, glow_alpha * 0.72), true, -1.0, false)
