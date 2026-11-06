extends CanvasLayer
## Native HUD-only arrows. No gameplay, physics or duplicated world ownership.
const WAIT_SECONDS := 30.0
const ARROW_TEXTURE := preload("res://art/Dream/icon/Arrow.png")
const ARROW_FRAME_SIZE := 48.0
const ENEMY_FRAME := 0
const OBJECTIVE_FRAME := 1
# Frame 2 is reserved for a future use.
const MIN_ARROW_SIZE := 18.0
const MAX_ARROW_SIZE := 36.0
const NEAR_DISTANCE := 6.0
const FAR_DISTANCE := 36.0
const PIXELS_PER_WORLD_UNIT := 32.0
# Reserve the whole rotated frame, including its transparent margin.
const EDGE_INSET := 29.0

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
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


static func arrow_size(distance_world_units: float) -> float:
	var progress := clampf((distance_world_units - NEAR_DISTANCE) / (FAR_DISTANCE - NEAR_DISTANCE), 0.0, 1.0)
	return lerpf(MAX_ARROW_SIZE, MIN_ARROW_SIZE, progress)


static func arrow_frame(kind: StringName) -> int:
	return ENEMY_FRAME if kind == &"enemy" else OBJECTIVE_FRAME


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
				# Drone muzzle helpers are also Node2Ds, but are not enemies.
				if enemy is Node2D and enemy.is_in_group(&"dream_enemies") and not enemy.is_queued_for_deletion() and enemy.get("dead") != true:
					var bottom := 0.75 if enemy.has_meta(&"exterior_flying") else 0.0
					var top := 2.15 if enemy.has_meta(&"exterior_flying") else 1.8
					_add_target(enemy.global_position, &"enemy", enemy.get_instance_id(), bottom, top, 0.4, camera, player)
	elif mode == &"badge":
		_add_target(badge.global_position, &"badge", badge.get_instance_id(), 0.0, 0.6, 0.3, camera, player)
	elif mode == &"elevator":
		_add_target(world.get("elevator_door_pos_2d"), &"elevator", 0, 0.0, 2.6, 0.9, camera, player)
	if not states.is_empty():
		_stack_states(_display_rect(camera, player))
	canvas.queue_redraw()
	return states


func _hud(point: Vector2, player: Node) -> Vector2:
	return player.call("get_presentation_hud_position", point) if player.has_method("get_presentation_hud_position") else point


func _display_rect(camera: Camera3D, player: Node) -> Rect2:
	var first := _hud(Vector2.ZERO, player)
	return Rect2(first, _hud(camera.get_viewport().get_visible_rect().size, player) - first)


static func edge_position(target: Vector2, rect: Rect2) -> Vector2:
	var center := rect.get_center()
	var direction := target - center
	if direction.length_squared() < 0.0001:
		return center
	var half := rect.size * 0.5
	var factor := minf(half.x / maxf(absf(direction.x), 0.0001), half.y / maxf(absf(direction.y), 0.0001))
	return center + direction * factor


func _target_on_screen(mapped: Vector3, bottom: float, top: float, radius: float, camera: Camera3D, player: Node, rect: Rect2) -> bool:
	# Hide the marker as soon as any of the target's projected body reaches the
	# actual game display, including when its centre is still outside the view.
	var center := world.to_global(mapped + Vector3.UP * ((bottom + top) * 0.5))
	if camera.is_position_in_frustum(center) and rect.has_point(_hud(camera.unproject_position(center), player)):
		return true
	var first := true
	var bounds := Rect2()
	var camera_inverse := camera.get_camera_transform().affine_inverse()
	for x in [-radius, radius]:
		for y in [bottom, top]:
			for z in [-radius, radius]:
				var corner := world.to_global(mapped + Vector3(x, y, z))
				var depth := -(camera_inverse * corner).z
				if depth < camera.near or depth > camera.far:
					continue
				var projected := _hud(camera.unproject_position(corner), player)
				if first:
					bounds = Rect2(projected, Vector2.ZERO)
					first = false
				else:
					bounds = bounds.expand(projected)
	return not first and rect.intersects(bounds, true)


func _add_target(position_2d: Vector2, kind: StringName, id: int, bottom: float, top: float, radius: float, camera: Camera3D, player: Node2D) -> void:
	var mapped: Vector3 = world.call("_map_gameplay_to_world", position_2d)
	var position_3d := world.to_global(mapped + Vector3.UP * ((bottom + top) * 0.5))
	var rect := _display_rect(camera, player)
	if _target_on_screen(mapped, bottom, top, radius, camera, player, rect):
		return
	var screen := _hud(camera.unproject_position(position_3d), player)
	if camera.is_position_behind(position_3d):
		screen = rect.get_center() * 2.0 - screen
	if screen.distance_squared_to(rect.get_center()) < 0.0001:
		# A target directly along the view axis can be outside the near/far clip
		# while projecting to the centre; still place its marker on an edge.
		var player_mapped: Vector3 = world.call("_map_gameplay_to_world", player.global_position)
		var delta := world.global_transform.basis * (mapped - player_mapped)
		var basis := camera.get_camera_transform().basis
		var projected_delta := Vector2(delta.dot(basis.x), -delta.dot(basis.y))
		if projected_delta.length_squared() < 0.0001:
			projected_delta = Vector2.UP
		screen = rect.get_center() + projected_delta.normalized() * rect.size.length()
	var anchor := edge_position(screen, rect.grow(-EDGE_INSET))
	var distance := position_2d.distance_to(player.global_position) / PIXELS_PER_WORLD_UNIT
	states.append({
		"kind": kind, "id": id, "position": anchor.round(), "target_screen": screen,
		"direction": (screen - anchor).normalized(), "size": arrow_size(distance),
		"distance": distance, "on_screen": false,
	})


static func _arrow_radius(state: Dictionary) -> float:
	# The non-transparent part is 35x34 inside a 48x48 frame. This circular
	# bound remains valid as the image turns and leaves a small gap.
	return float(state.get("size", MAX_ARROW_SIZE)) * 0.51 + 1.0


func _stack_states(rect: Rect2) -> void:
	# Spread crowded edge markers along the edge, then use inward lanes. Every
	# target is retained; overlap is only unavoidable if the screen is full.
	var safe := rect.grow(-EDGE_INSET)
	var step := MAX_ARROW_SIZE * 1.1
	# A grid limits each collision check to nearby arrows, even with a full floor
	# of enemies aiming at the same edge.
	var occupied: Dictionary = {}
	for i in range(states.size()):
		var base: Vector2 = states[i].position
		var horizontal := minf(absf(base.y - safe.position.y), absf(base.y - safe.end.y)) <= minf(absf(base.x - safe.position.x), absf(base.x - safe.end.x))
		var tangent := Vector2.RIGHT if horizontal else Vector2.DOWN
		var inward := Vector2(0.0, 1.0 if base.y < safe.get_center().y else -1.0) if horizontal else Vector2(1.0 if base.x < safe.get_center().x else -1.0, 0.0)
		var placed := false
		var offsets := ceili((safe.size.x if horizontal else safe.size.y) / step)
		for lane in range(mini(states.size(), 8)):
			for attempt in range(offsets * 2 + 1):
				var offset := 0.0 if attempt == 0 else float((attempt + 1) / 2) * (1.0 if attempt % 2 == 1 else -1.0)
				var candidate := (base + tangent * offset * step + inward * float(lane) * step).round()
				if not safe.grow(0.5).has_point(candidate):
					continue
				var cell := Vector2i(floori(candidate.x / step), floori(candidate.y / step))
				var overlaps := false
				for x in range(-1, 2):
					for y in range(-1, 2):
						var nearby: Array = occupied.get(cell + Vector2i(x, y), [])
						for j: int in nearby:
							var separation := _arrow_radius(states[i]) + _arrow_radius(states[j])
							if candidate.distance_squared_to(states[j].position) < separation * separation:
								overlaps = true
								break
						if overlaps:
							break
					if overlaps:
						break
				if not overlaps:
					states[i].position = candidate
					placed = true
					break
			if placed:
				break
		var position: Vector2 = states[i].position
		var cell := Vector2i(floori(position.x / step), floori(position.y / step))
		if not occupied.has(cell):
			occupied[cell] = []
		occupied[cell].append(i)
		if states[i].has("target_screen"):
			states[i].direction = (Vector2(states[i].target_screen) - Vector2(states[i].position)).normalized()


func _draw_arrows() -> void:
	for state in states:
		var size := float(state.size)
		var direction: Vector2 = state.direction
		# Every source frame points left; rotate it toward the target.
		canvas.draw_set_transform(state.position, direction.angle() - PI)
		canvas.draw_texture_rect_region(
			ARROW_TEXTURE,
			Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size),
			Rect2(float(arrow_frame(state.kind)) * ARROW_FRAME_SIZE, 0.0, ARROW_FRAME_SIZE, ARROW_FRAME_SIZE)
		)
	canvas.draw_set_transform(Vector2.ZERO)
