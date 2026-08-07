class_name BedroomDoorInteraction
extends Node2D

## 门口/外卖底部交互：实际可点击区域为屏幕底部横带（get_interaction_rect，中心 x=280px、高60px）。
## 视觉为底部半圆渐变白光（shaders/door_glow_semicircle.gdshader），水平直径 =
## 视口宽 × bottom_glow_width_ratio（0.59375 即 640 下宽 380px），
## 高度 = 水平半径 × bottom_glow_height_multiplier（0.631579 即高 120px），
## 圆心 x = 视口宽 × bottom_glow_center_x_ratio，底边贴屏幕底。
## 鼠标悬停淡入；外卖等待（WAITING_AT_DOOR）且无 Modal UI 时白光保持可见，
## 并显示像素字体文字“有人敲门”+ 朝下往返箭头（整数像素往返，无 Blur/旋转/横漂）。

const GLOW_SHADER := preload("res://shaders/door_glow_semicircle.gdshader")

@export var config: DemoConfig

var interactable := false
var hovered := false
var delivery_waiting := false
var glow_alpha := 0.0
var waiting_alpha := 0.0
var elapsed := 0.0
var glow_rect: ColorRect
var glow_material: ShaderMaterial


func _ready() -> void:
	glow_material = ShaderMaterial.new()
	glow_material.shader = GLOW_SHADER
	glow_rect = ColorRect.new()
	glow_rect.material = glow_material
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_rect)


func set_state(can_interact: bool, is_hovered: bool, is_waiting: bool) -> void:
	interactable = can_interact
	hovered = is_hovered and can_interact
	delivery_waiting = is_waiting
	queue_redraw()


func get_interaction_rect(viewport_size: Vector2 = Vector2(640, 360)) -> Rect2:
	# BottomEdgeInteraction：交互区为屏幕底部横带，高度由 config.bottom_edge_interaction_height
	# 集中配置（当前 60px），水平范围由 bottom_interaction_horizontal_start/end_ratio
	# 配置（当前中心 x=280px，宽度保持中间三分之一）。
	var height := minf(config.bottom_edge_interaction_height, viewport_size.y)
	var left := viewport_size.x * clampf(config.bottom_interaction_horizontal_start_ratio, 0.0, 1.0)
	var right := viewport_size.x * clampf(config.bottom_interaction_horizontal_end_ratio, 0.0, 1.0)
	if right <= left:
		right = left + 1.0
	return Rect2(left, viewport_size.y - height, right - left, height)


func _process(delta: float) -> void:
	elapsed += delta
	var target := 1.0 if hovered else 0.0
	var seconds := config.door_glow_fade_in_seconds if target > glow_alpha else config.door_glow_fade_out_seconds
	glow_alpha = move_toward(glow_alpha, target, delta / maxf(seconds, 0.001))
	# 有人敲门且可交互（无 Modal UI）时白光/文字/箭头保持可见，不依赖鼠标悬停；
	# Modal 打开（interactable=false）或领取后随淡出隐藏。
	var waiting_target := 1.0 if delivery_waiting and interactable else 0.0
	var waiting_seconds := config.door_glow_fade_in_seconds if waiting_target > waiting_alpha else config.door_glow_fade_out_seconds
	waiting_alpha = move_toward(waiting_alpha, waiting_target, delta / maxf(waiting_seconds, 0.001))
	_update_glow()
	queue_redraw()


## 半圆白光：ColorRect 覆盖 视口宽 × bottom_glow_width_ratio、向上延伸
## 半径 × bottom_glow_height_multiplier 的高度，圆心即半圆底部中央（局部 UV (0.5,1.0)）。
## Shader 按椭圆距离计算径向渐变（vertical_scale 拉伸垂直方向），左右边界处
## alpha 仍为 0，水平分布与未放大时完全一致；半圆外 alpha=0，交互区不随视觉扩大。
## 强度 = 峰值 alpha × max(悬停, 等待)，外卖等待时再乘等待倍率。
func _update_glow() -> void:
	if glow_rect == null or glow_material == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(640, 360)
	var width := viewport_size.x * clampf(config.bottom_glow_width_ratio, 0.05, 1.0)
	var center_x := viewport_size.x * clampf(config.bottom_glow_center_x_ratio, 0.0, 1.0)
	var radius := width * 0.5
	var height_multiplier := clampf(config.bottom_glow_height_multiplier, 0.1, 4.0)
	var height := radius * height_multiplier
	glow_rect.position = Vector2(center_x - radius, viewport_size.y - height)
	glow_rect.size = Vector2(width, height)
	var strength := 0.0
	if interactable:
		strength = config.door_glow_opacity * maxf(glow_alpha, waiting_alpha)
		if delivery_waiting:
			strength *= config.door_waiting_glow_multiplier
	glow_material.set_shader_parameter("strength", strength)
	glow_material.set_shader_parameter("rect_size", glow_rect.size)
	glow_material.set_shader_parameter("inner_radius", 0.0)
	glow_material.set_shader_parameter("outer_radius", radius)
	glow_material.set_shader_parameter("vertical_scale", height_multiplier)
	glow_material.set_shader_parameter("pixel_step_size", config.door_glow_pixel_step_size)


func _draw() -> void:
	# “有人敲门”+ 朝下箭头只在 WAITING_AT_DOOR 且可交互（无手机/电脑/弹窗等 Modal UI）时显示；
	# 领取后或 Modal UI 打开时随 set_state 立即隐藏，状态本身不受影响。
	if not (delivery_waiting and interactable):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(640, 360)
	var interaction_rect := get_interaction_rect(viewport_size)
	var center_x := interaction_rect.position.x + interaction_rect.size.x * 0.5
	var font := PixelFont.get_font()
	var text := "有人敲门"
	var font_size := 10
	var color := Color(0.82, 0.91, 0.96, 0.92)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_baseline_y := interaction_rect.position.y - 18.0
	draw_string(font, Vector2(center_x - text_width * 0.5, text_baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	# 朝下箭头：文字下方、交互区上方，只做垂直往返（整数像素，无旋转/横漂/Blur）。
	var bounce_distance := clampf(config.delivery_arrow_bounce_distance_px, 1.0, 12.0)
	var bounce_duration := maxf(config.delivery_arrow_bounce_duration, 0.1)
	var bounce := float(roundi(abs(sin(elapsed * PI / bounce_duration)) * bounce_distance))
	var arrow_origin := Vector2(center_x, text_baseline_y + 4.0 + bounce)
	var arrow := PackedVector2Array([
		arrow_origin + Vector2(0, 9), arrow_origin + Vector2(-4, 4), arrow_origin + Vector2(-1, 4),
		arrow_origin + Vector2(-1, 0), arrow_origin + Vector2(1, 0), arrow_origin + Vector2(1, 4),
		arrow_origin + Vector2(4, 4),
	])
	draw_colored_polygon(arrow, color)
