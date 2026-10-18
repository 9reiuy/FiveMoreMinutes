extends Node2D

## Passive, world-space room-clear guidance marker.  The gameplay world owns
## the source node and its depth bridge; this script only draws a small pixel
## arrow and carries no collision, navigation, or progression authority.

@export var arrow_length_pixels := 64.0
@export var arrow_width_pixels := 26.0
@export var arrow_color := Color.WHITE


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func configure(length_pixels: float, width_pixels: float, color: Color = Color.WHITE) -> void:
	arrow_length_pixels = maxf(length_pixels, 8.0)
	arrow_width_pixels = maxf(width_pixels, 4.0)
	arrow_color = color
	queue_redraw()


func set_room_runtime_active(active: bool) -> void:
	visible = active


func copy_depth_visual_state_to(target: Node2D) -> void:
	if target == null:
		return
	target.set("arrow_length_pixels", arrow_length_pixels)
	target.set("arrow_width_pixels", arrow_width_pixels)
	target.set("arrow_color", arrow_color)
	target.queue_redraw()


func _draw() -> void:
	var half_length := maxf(arrow_length_pixels * 0.5, 4.0)
	var half_width := maxf(arrow_width_pixels * 0.5, 2.0)
	# The arrow points along local +X.  The source root rotates it to the
	# connection's outward direction, so North/South/East/West use one shape.
	var points := PackedVector2Array([
		Vector2(-half_length, -half_width),
		Vector2(0.0, -half_width),
		Vector2(0.0, -half_width * 1.65),
		Vector2(half_length, 0.0),
		Vector2(0.0, half_width * 1.65),
		Vector2(0.0, half_width),
		Vector2(-half_length, half_width),
	])
	draw_colored_polygon(points, arrow_color)
