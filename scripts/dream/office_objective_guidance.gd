extends CanvasLayer
## Native HUD-only arrows. No gameplay, physics or duplicated world ownership.
const WAIT_SECONDS := 30.0
var world: Node3D
var elapsed := 0.0
var states: Array[Dictionary] = []
var canvas: Control

func configure(owner_world: Node3D) -> void:
	world = owner_world
	layer = 24
	name = "OfficeObjectiveGuidance"
	canvas = Control.new()
	canvas.name = "Arrows"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_arrows)
	reset_floor()

func reset_floor() -> void:
	elapsed = 0.0
	states.clear()
	if is_instance_valid(canvas):
		canvas.queue_redraw()

static func choose_mode(seconds: float, owns_badge: bool, dropped: bool, suspended: bool) -> StringName:
	if suspended:
		return &"hidden"
	if owns_badge:
		return &"elevator"
	if dropped:
		return &"badge"
	return &"enemy" if seconds >= WAIT_SECONDS else &"hidden"

func update(delta: float) -> Array[Dictionary]:
	states.clear()
	if not is_instance_valid(world) or not is_instance_valid(canvas):
		return states
	var player: Node2D = world.get("player")
	var camera: Camera3D = world.get("camera_3d")
	var suspended := not is_instance_valid(player) or not is_instance_valid(camera) or get_tree().paused
	if not suspended:
		suspended = bool(world.get("floor_transition_in_progress")) or String(world.get("transition_phase")) != "IDLE" or not bool(player.get("movement_enabled")) or bool(player.get("dead"))
	if not suspended:
		elapsed += maxf(delta, 0.0)
	var badge: Node2D = world.get("floor_badge_pickup")
	var mode := choose_mode(elapsed, bool(world.get("has_floor_badge")), is_instance_valid(badge) and not badge.is_queued_for_deletion(), suspended)
	if mode == &"enemy":
		var enemies: Node = world.get("enemy_root")
		if is_instance_valid(enemies):
			for enemy in enemies.get_children():
				if enemy is Node2D and not enemy.is_queued_for_deletion() and enemy.get("dead") != true:
					_add_target(enemy.global_position, &"enemy", enemy.get_instance_id(), 1.6, camera, player)
	elif mode == &"badge":
		_add_target(badge.global_position, &"badge", badge.get_instance_id(), 0.3, camera, player)
	elif mode == &"elevator":
		_add_target(world.get("elevator_door_pos_2d"), &"elevator", 0, 1.3, camera, player)
	_stack_states(_display_rect(camera, player))
	canvas.queue_redraw()
	return states

func _hud(point: Vector2, player: Node) -> Vector2:
	return player.call("get_presentation_hud_position", point) if player.has_method("get_presentation_hud_position") else point

func _display_rect(camera: Camera3D, player: Node) -> Rect2:
	var first := _hud(Vector2.ZERO, player)
	return Rect2(first, _hud(camera.get_viewport().get_visible_rect().size, player) - first)

func _logical_pixel_scale() -> float:
	if not is_instance_valid(canvas) or not canvas.is_inside_tree():
		return 1.0
	return maxf(0.01, canvas.get_viewport().get_final_transform().get_scale().x)

static func edge_position(target: Vector2, rect: Rect2) -> Vector2:
	var center := rect.get_center()
	var direction := target - center
	if direction.length_squared() < 0.0001:
		return center
	var half := rect.size * 0.5
	var factor := minf(half.x / maxf(absf(direction.x), 0.0001), half.y / maxf(absf(direction.y), 0.0001))
	return center + direction * factor

func _add_target(position_2d: Vector2, kind: StringName, id: int, height: float, camera: Camera3D, player: Node) -> void:
	var mapped: Vector3 = world.call("_map_gameplay_to_world", position_2d)
	var position_3d := world.to_global(mapped + Vector3.UP * height)
	var screen := _hud(camera.unproject_position(position_3d), player)
	var rect := _display_rect(camera, player)
	var inset := rect.grow(-24.0 / _logical_pixel_scale())
	var on_screen := rect.has_point(screen) and not camera.is_position_behind(position_3d)
	if camera.is_position_behind(position_3d):
		screen = rect.get_center() * 2.0 - screen
	var anchor := screen - Vector2(0, 9) if on_screen else edge_position(screen, inset)
	states.append({"kind": kind, "id": id, "position": anchor.round(), "direction": Vector2.DOWN if on_screen else (screen - rect.get_center()).normalized(), "on_screen": on_screen})

func _stack_states(rect: Rect2) -> void:
	# Keep every target. Edge collisions spread tangentially first, then form
	# a second inward lane only when the available edge is already occupied.
	for i in range(states.size()):
		var base: Vector2 = states[i].position
		var tangent := Vector2.RIGHT
		if absf(base.x - rect.position.x) < 30 or absf(base.x - rect.end.x) < 30:
			tangent = Vector2.DOWN
		for attempt in range(states.size() * 4 + 1):
			var overlaps := false
			for j in range(i):
				if Vector2(states[i].position).distance_to(states[j].position) < 13.0:
					overlaps = true
					break
			if not overlaps:
				break
			var p := base
			if states[i].on_screen:
				p += Vector2(14, -14) * float(attempt + 1)
			else:
				var offset := float((attempt / 2) + 1) * (14.0 if attempt % 2 == 0 else -14.0)
				p += tangent * offset
				p.x = clampf(p.x, rect.position.x + 24.0 / _logical_pixel_scale(), rect.end.x - 24.0 / _logical_pixel_scale())
				p.y = clampf(p.y, rect.position.y + 24.0 / _logical_pixel_scale(), rect.end.y - 24.0 / _logical_pixel_scale())
				if attempt >= states.size() * 2:
					p += (rect.get_center() - base).normalized() * 14.0 * float(1 + (attempt - states.size() * 2) / 2)
			states[i].position = p.round()

func _draw_arrows() -> void:
	for state in states:
		var p: Vector2 = state.position
		var direction: Vector2 = state.direction
		var side := direction.orthogonal()
		var points := PackedVector2Array([p + direction * 6, p - direction * 4 + side * 4, p - direction * 2, p - direction * 4 - side * 4])
		var color := Color("EF5350") if state.kind == &"enemy" else (Color("FFD166") if state.kind == &"badge" else Color("57DCE8"))
		if state.kind == &"elevator":
			points.append(points[0])
			canvas.draw_polyline(points, Color.BLACK, 3.0)
			canvas.draw_polyline(points, color, 1.0)
		else:
			canvas.draw_colored_polygon(points, color)
			var border := points.duplicate()
			border.append(border[0])
			canvas.draw_polyline(border, Color.BLACK, 1.0)
		if state.kind != &"enemy":
			var icon := Rect2(p - direction * 14 - Vector2(4, 3), Vector2(8, 6))
			canvas.draw_rect(icon, Color.BLACK)
			canvas.draw_rect(icon.grow(-1), color, false, 1.0)
			if state.kind == &"elevator":
				canvas.draw_line(icon.get_center() - Vector2(0, 2), icon.get_center() + Vector2(0, 2), color)
