extends Node2D

var direction := Vector2.RIGHT
var effect_kind: StringName = &"pistol"
var lifetime := 0.07
var initial_lifetime := 0.07
var primary := Color("517b98")
var secondary := Color("9ab6c8")


func setup(new_direction: Vector2, new_kind: StringName, duration: float, primary_color: Color, secondary_color: Color) -> void:
	direction = new_direction.normalized()
	effect_kind = new_kind
	lifetime = maxf(duration, 0.01)
	initial_lifetime = lifetime
	primary = primary_color
	secondary = secondary_color
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0)
	var c1 := Color(primary, alpha)
	var c2 := Color(secondary, alpha * 0.8)
	match effect_kind:
		&"shotgun":
			for angle in [-0.28, -0.14, 0.0, 0.14, 0.28]:
				draw_line(Vector2(4, 0), Vector2.RIGHT.rotated(angle) * 22.0, c1, 2.0)
			for point in [Vector2(14, -7), Vector2(19, 3), Vector2(12, 8)]:
				draw_rect(Rect2(point, Vector2(3, 3)), c2)
		&"beam_charge":
			var progress := 1.0 - alpha
			var radius := lerpf(16.0, 3.0, progress)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, c1, 2.0)
			draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), c2)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(12, -5), Vector2(20, 0), Vector2(12, 5)]), c1)
			draw_line(Vector2(8, 0), Vector2(24, 0), c2, 2.0)
