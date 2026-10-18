extends Node2D
class_name EmployeeBadgeMarker

## A lightweight world marker for the floor's Employee Badge.  The marker is
## presentation-only: it never changes the pickup's gameplay position, does
## not collide, and is safe to capture through the existing depth bridge.

var bob_time: float = 0.0
var fake_height: float = 52.0


func _ready() -> void:
	set_meta(&"depth_visual_unshaded", true)
	set_meta(&"depth_visual_camera_plane", true)
	queue_redraw()


func _process(delta: float) -> void:
	bob_time += maxf(delta, 0.0)
	fake_height = 52.0 + sin(bob_time * 4.2) * 7.0
	queue_redraw()


func copy_depth_visual_state_to(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set("bob_time", bob_time)
	target.set("fake_height", fake_height)
	target.modulate = modulate
	target.self_modulate = self_modulate
	target.scale = scale
	target.queue_redraw()


func _draw() -> void:
	# Compact pixel arrow, kept deliberately separate from the retired room-exit
	# arrows.  The marker points at the badge directly below it.
	var white := Color(0.96, 0.98, 1.0, 1.0)
	var shade := Color(0.32, 0.42, 0.54, 1.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 12.0),
			Vector2(-7.0, 4.0),
			Vector2(-3.0, 4.0),
			Vector2(-3.0, -7.0),
			Vector2(3.0, -7.0),
			Vector2(3.0, 4.0),
			Vector2(7.0, 4.0),
		]),
		white
	)
	draw_rect(Rect2(-4.0, -9.0, 8.0, 2.0), shade)
