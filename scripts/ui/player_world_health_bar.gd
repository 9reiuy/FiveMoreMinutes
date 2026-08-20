class_name PlayerWorldHealthBar
extends Node2D

var current_health := 1.0
var maximum_health := 1.0
var visible_left := 0.0
var bar_width := 50.0
var bar_height := 5.0


func _ready() -> void:
	visible = false
	set_process(false)


func configure(config: DemoConfig, current: float, maximum: float) -> void:
	configure_values(config.player_hp_bar_width, config.player_hp_bar_height, config.player_hp_bar_offset, current, maximum)


## 玩家和敌人共用同一轻量World Bar；节点只做CanvasItem绘制，不创建Timer或独立CanvasLayer。
func configure_values(width: float, height: float, offset: Vector2, current: float, maximum: float) -> void:
	bar_width = maxf(width, 2.0)
	bar_height = maxf(height, 2.0)
	position = offset
	update_health(current, maximum)


func show_after_damage(current: float, maximum: float, duration: float) -> void:
	update_health(current, maximum)
	visible_left = maxf(duration, 0.0)
	visible = visible_left > 0.0
	set_process(visible)


func update_health(current: float, maximum: float) -> void:
	current_health = maxf(current, 0.0)
	maximum_health = maxf(maximum, 1.0)
	queue_redraw()


func hide_immediately() -> void:
	visible_left = 0.0
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	visible_left = maxf(0.0, visible_left - delta)
	if visible_left <= 0.0:
		visible = false
		set_process(false)


func _draw() -> void:
	var rect := Rect2(-bar_width * 0.5, 0.0, bar_width, bar_height)
	draw_rect(rect, Color("080c12"))
	draw_rect(rect.grow(-1.0), Color("242d35"))
	var inner_width := (bar_width - 2.0) * clampf(current_health / maximum_health, 0.0, 1.0)
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2(inner_width, bar_height - 2.0)), Color("8f3f4d"))
