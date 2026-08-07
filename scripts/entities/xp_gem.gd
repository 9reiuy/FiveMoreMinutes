extends Node2D

const CONFIG := preload("res://resources/demo_config.tres")

signal collected(amount: int)

@export var value := 1
var target: Node2D
var consumed := false
var pop_elapsed := 0.0
var draw_offset := Vector2.ZERO
var gem_color := Color("7b9aa0")


func _ready() -> void:
	scale = Vector2.ONE * 0.35


func configure(new_value: int, rarity: String = "normal") -> void:
	value = maxi(1, new_value)
	gem_color = Color("8c68a5") if rarity == "purple" else (Color("6e9fc5") if rarity == "blue" else Color("7b9aa0"))


func _process(delta: float) -> void:
	pop_elapsed = minf(pop_elapsed + delta, CONFIG.kill_pop_animation_seconds)
	var pop_progress := clampf(pop_elapsed / maxf(CONFIG.kill_pop_animation_seconds, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - pop_progress, 3.0)
	scale = Vector2.ONE * lerpf(0.35, 1.0, eased)
	draw_offset.y = -sin(pop_progress * PI) * 9.0
	queue_redraw()
	if consumed or not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < 92.0:
		global_position = global_position.move_toward(target.global_position, 145.0 * delta)
	if global_position.distance_to(target.global_position) < 15.0:
		consumed = true
		collected.emit(value)
		queue_free()


func _draw() -> void:
	var points := PackedVector2Array([draw_offset + Vector2(0, -6), draw_offset + Vector2(5, 0), draw_offset + Vector2(0, 7), draw_offset + Vector2(-5, 0)])
	draw_colored_polygon(points, gem_color)
	draw_circle(draw_offset, 8.0, Color(gem_color, 0.30), false, 1.0)
