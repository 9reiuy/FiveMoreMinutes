extends Node2D
class_name DreamDashAimPresentation

## Passive Dash path presentation.  DreamPlayer owns the path query; this
## node only receives a result and draws pooled-looking arrow marks.  It never
## performs physics queries or changes gameplay state.

var arrow_spacing_pixels := 24.0
var arrow_length_pixels := 12.0
var arrow_width_pixels := 5.0
var arrow_color := Color(1.0, 1.0, 1.0, 0.86)
var arrow_points: Array = []
var active := false


func set_path(result: Dictionary) -> void:
	arrow_points.clear()
	active = bool(result.get("valid", false))
	if not active:
		visible = false
		queue_redraw()
		return
	var segments_variant: Variant = result.get("segments", [])
	if not segments_variant is Array:
		active = false
		visible = false
		queue_redraw()
		return
	for segment_variant in segments_variant:
		if not segment_variant is Dictionary:
			continue
		var segment: Dictionary = segment_variant
		var start: Variant = segment.get("start", Vector2.ZERO)
		var end: Variant = segment.get("end", start)
		if not start is Vector2 or not end is Vector2:
			continue
		var travel: Vector2 = end - start
		var distance: float = travel.length()
		if distance <= 1.0:
			continue
		var direction: Vector2 = travel / distance
		var cursor: Vector2 = start + direction * minf(arrow_spacing_pixels * 0.5, distance * 0.5)
		while cursor.distance_to(start) < distance:
			# Draw coordinates are local to this moving source node.  The source
			# itself is placed at the Player's gameplay origin so its 3D bridge has
			# the same world anchor as the preview.
			arrow_points.append({"position": cursor - global_position, "direction": direction})
			cursor += direction * arrow_spacing_pixels
	visible = active and not arrow_points.is_empty()
	queue_redraw()


func clear() -> void:
	arrow_points.clear()
	active = false
	visible = false
	queue_redraw()


func copy_depth_visual_state_to(target: Node2D) -> void:
	if target == null:
		return
	if target.get_script() != get_script():
		target.set_script(get_script())
	target.arrow_spacing_pixels = arrow_spacing_pixels
	target.arrow_length_pixels = arrow_length_pixels
	target.arrow_width_pixels = arrow_width_pixels
	target.arrow_color = arrow_color
	target.arrow_points = arrow_points.duplicate(true)
	target.active = active
	target.visible = visible
	target.queue_redraw()


func _draw() -> void:
	if not active:
		return
	for point_variant in arrow_points:
		if not point_variant is Dictionary:
			continue
		var point: Dictionary = point_variant
		var position: Vector2 = point.get("position", Vector2.ZERO)
		var direction: Vector2 = point.get("direction", Vector2.RIGHT)
		if direction.length_squared() <= 0.0001:
			continue
		var angle: float = direction.angle()
		var half_width: float = arrow_width_pixels * 0.5
		var polygon: PackedVector2Array = PackedVector2Array([
			Vector2(-arrow_length_pixels * 0.5, -half_width),
			Vector2(arrow_length_pixels * 0.5, -half_width),
			Vector2(arrow_length_pixels * 0.5, -arrow_width_pixels),
			Vector2(arrow_length_pixels, 0.0),
			Vector2(arrow_length_pixels * 0.5, arrow_width_pixels),
			Vector2(arrow_length_pixels * 0.5, half_width),
			Vector2(-arrow_length_pixels * 0.5, half_width),
		])
		draw_set_transform(position, angle, Vector2.ONE)
		draw_colored_polygon(polygon, arrow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
