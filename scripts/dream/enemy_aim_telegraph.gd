extends Node
## Floor-owned presenter; one immutable sample per actor and frame.
const FIREARM_RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
const SHOT_TAIL_SECONDS := 0.125
const TARGET_OVERHANG_PIXELS := 30.0
const FAN_TIMES := [0.0, .10, .226, .301, .401, .576, .78, 1.0]
# Full aperture in degrees, fill alpha, core alpha, soft edge alpha.
const FAN_CURVE := [
	Vector4(12.5, .11, .62, .20), Vector4(12.0, .16, .65, .27),
	Vector4(10.5, .25, .73, .40), Vector4(8.5, .30, .76, .44),
	Vector4(6.0, .29, .80, .42), Vector4(5.0, .25, .83, .38),
	Vector4(2.4, .22, .86, .31), Vector4(0.0, .18, .89, .23),
]
const FAN_INTERVALS := 16
const EDGE_LANES := [-1.0, -.36, 0.0, .36, 1.0]
const EDGE_COVERAGE := [0.0, .46, 1.0, .46, 0.0]
const PIXEL_CORE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 raster_pixel = vec2(1.0);
varying vec2 raster_position;

void vertex() {
	raster_position = VERTEX / raster_pixel;
}

void fragment() {
	vec2 step_x = dFdx(UV) / dFdx(raster_position.x);
	vec2 step_y = dFdy(UV) / dFdy(raster_position.y);
	vec2 snap = floor(raster_position) + vec2(0.5) - raster_position;
	vec2 sample_uv = UV + step_x * snap.x + step_y * snap.y;
	float half_cell = max(abs(step_x.x), abs(step_y.x)) * 0.5;
	if (sample_uv.x < -half_cell || sample_uv.x >= half_cell || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		discard;
	}
}
"""
static var edge_indices := _make_edge_indices()
var world: Node
var layer: CanvasLayer
var visible := true:
	set(value):
		visible=value
		if is_instance_valid(layer): layer.visible=value
var surface: Control
var pixel_core: Control
var core_pixel_size := Vector2.ONE
var flashes: Array[Dictionary]=[]
var prepared_lines: Array[Dictionary]=[]
var prepared_tails: Array[Dictionary] = []
var smoothed_points: Dictionary={}
var shot_tails: Dictionary = {}
var last_drawn_enemy_ids: Array[int]=[]

func _ready() -> void:
	process_priority=100
	layer=CanvasLayer.new()
	layer.name="CombatThreatHUD"
	layer.layer=40
	layer.set_meta(&"threat_world_id",world.get_instance_id())
	add_child(layer)
	layer.add_to_group(&"enemy_threat_huds")
	_claim_layer()
	surface=Control.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.clip_contents=true
	layer.add_child(surface)
	surface.draw.connect(draw_lines)
	pixel_core = Control.new()
	pixel_core.name = "PixelCore"
	pixel_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = PIXEL_CORE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	pixel_core.material = material
	surface.add_child(pixel_core)
	pixel_core.draw.connect(_draw_pixel_cores)

func _claim_layer() -> void:
	if not is_inside_tree() or not is_instance_valid(world) or world.floor_root!=get_parent(): return
	for other in get_tree().get_nodes_in_group(&"enemy_threat_huds"):
		if other!=layer and other.get_meta(&"threat_world_id",0)==world.get_instance_id(): other.visible=false

static func line_style(progress: float) -> Dictionary:
	var amount:=clampf(progress,0,1)
	return {"width":lerpf(1.0,3.5,amount),"color":Color(1,.5,.5,.28).lerp(Color(.68,.015,.025,.98),amount)}

static func employee_line_style(progress: float) -> Vector4:
	var amount := clampf(progress, 0.0, 1.0)
	for i in range(1, FAN_TIMES.size()):
		if amount <= FAN_TIMES[i]:
			var weight: float = inverse_lerp(FAN_TIMES[i - 1], FAN_TIMES[i], amount)
			return FAN_CURVE[i - 1].lerp(FAN_CURVE[i], weight)
	return FAN_CURVE[-1]

static func _make_edge_indices() -> PackedInt32Array:
	var indices := PackedInt32Array()
	var lanes := EDGE_LANES.size()
	for row in 3:
		for i in lanes - 1:
			var a := row * lanes + i
			indices.append_array(PackedInt32Array([a, a + lanes, a + 1, a + 1, a + lanes, a + lanes + 1]))
	return indices

static func _shot_range(enemy: EmployeeEnemy) -> float:
	var parameters := FIREARM_RULES.parameters(enemy.feedback_config, StringName(enemy.held_weapon_id))
	return maxf(0.0, float(parameters.range))

func record_employee_shot(enemy: EmployeeEnemy, _muzzle_world: Vector3) -> void:
	# Called synchronously only by the accepted shot, while the committed
	# aim target is still available. An empty mag, cancel or repeat shot
	# never creates a tail.
	if _can_draw() and enemy.ranged_attack_fire_locked and enemy._is_otxo_mode() and _tail_source_visible(enemy):
		shot_tails[enemy.get_instance_id()] = {
			"origin": _employee_warning_center(enemy),
			"start": enemy.global_position, "target": enemy.ranged_attack_target_snapshot,
			"range": _shot_range(enemy),
			"weapon": enemy.held_weapon_id, "actor_id": enemy.target.get_instance_id(),
		}

func _process(delta: float) -> void:
	var real_delta:=delta/maxf(Engine.time_scale,.001)
	for flash in flashes: flash.left-=real_delta
	flashes=flashes.filter(func(f: Dictionary) -> bool: return f.left>0)
	prepared_lines.clear()
	prepared_tails.clear()
	surface.queue_redraw()
	pixel_core.queue_redraw()
	if not _can_draw():
		shot_tails.clear()
		smoothed_points.clear()
		return
	var size: Vector2=world.camera_3d.get_viewport().get_visible_rect().size
	surface.position=world.player.get_presentation_hud_position(Vector2.ZERO)
	surface.size=world.player.get_presentation_hud_position(size)-surface.position
	var grid := size * minf(1.0, 640.0 / size.x)
	var raster_pixel := surface.size / grid
	if not raster_pixel.is_equal_approx(core_pixel_size):
		core_pixel_size = raster_pixel
		pixel_core.material.set_shader_parameter("raster_pixel", core_pixel_size)
	var seen: Dictionary={}
	for enemy in world.enemy_root.get_children():
		var id: int=enemy.get_instance_id()
		if seen.has(id): continue
		var segment:=aim_segment(enemy)
		if segment.is_empty():
			if shot_tails.has(id) and _tail_source_visible(enemy) \
				and shot_tails[id].weapon == enemy.held_weapon_id \
				and shot_tails[id].actor_id == enemy.target.get_instance_id():
				_append_tail(id)
				smoothed_points.erase(id)
				seen[id] = true
			continue
		seen[id]=true
		shot_tails.erase(id)
		if segment.has("shot_range"):
			prepared_lines.append(_long_alert(id, segment.start, segment.center_world, segment.target,
				segment.shot_range, employee_line_style(segment.progress), 1.0))
			continue
		var start_world: Vector3 = world.get_gameplay_world_position(segment.start, 0.75)
		var snapshot: Dictionary = world._weapon_visual_snapshot(enemy, segment.start)
		if not snapshot.is_empty():
			start_world = snapshot.world_origin
		var previous: Dictionary = smoothed_points.get(id, {})
		var difference: Vector2 = segment.end - segment.start
		var end_world: Vector3 = start_world + world.global_basis * Vector3(difference.x, 0.0, difference.y) / 32.0
		if previous.has("start") and Vector3(previous.start).distance_squared_to(start_world) < 16.0:
			var weight := 1.0 - exp(-50.0 * real_delta)
			start_world = Vector3(previous.start).lerp(start_world, weight)
			end_world = Vector3(previous.end).lerp(end_world, weight)
		smoothed_points[id] = {"start": start_world, "end": end_world}
		var line := {"id":id,"from":screen_point(start_world),"to":screen_point(end_world)}
		line.style = line_style(segment.progress)
		prepared_lines.append(line)
	for id in smoothed_points.keys():
		if not seen.has(id): smoothed_points.erase(id)
	for id in shot_tails.keys():
		if not seen.has(id): shot_tails.erase(id)

func _tail_source_visible(enemy: EmployeeEnemy) -> bool:
	return not enemy.dead and enemy.state == EmployeeEnemy.State.ATTACK_PLAYER and enemy.can_see_target \
		and enemy.reload_left <= 0.0 and enemy.pickup_pause_left <= 0.0 and is_instance_valid(enemy.target) \
		and not enemy._smoke_blocks_target() and _source_not_smoke_hidden(enemy) \
		and wall_end(world.player.global_position, enemy.global_position).distance_to(enemy.global_position) <= .5

func _append_tail(id: int) -> void:
	var tail: Dictionary = shot_tails[id]
	var clock: SceneTreeTimer = tail.get("clock")
	if clock == null:
		# Start on the first drawable sample. Godot advances this clock
		# with the unscaled frame step, even if hit-stop changes this frame's scale.
		clock = get_tree().create_timer(SHOT_TAIL_SECONDS, false, false, true)
		tail.clock = clock
	if clock.time_left <= 0.0:
		shot_tails.erase(id)
		return
	prepared_tails.append(_long_alert(id, tail.start, tail.origin, tail.target, tail.range,
		FAN_CURVE[-1], clock.time_left / SHOT_TAIL_SECONDS))

func _long_alert(id: int, gameplay_start: Vector2, body_center: Vector3, target: Vector2,
		shot_range: float, profile: Vector4, life: float) -> Dictionary:
	var start := screen_point(body_center)
	var rays: Array[Dictionary] = []
	var line := {"id": id, "from": start, "to": start, "profile": profile,
		"height": _body_height(body_center), "tail": life, "fan_rays": rays}
	var delta := target - gameplay_start
	if shot_range <= 0.0 or delta.is_zero_approx() or surface.size.x <= 0.0 or surface.size.y <= 0.0:
		return line
	var camera: Camera3D = world.camera_3d
	var basis: Basis = world.global_basis
	var projection := {"camera": camera, "to_viewport": camera.get_viewport().get_visible_rect().size / surface.size,
		"basis": basis, "to_map": basis.inverse(), "plane": Plane(basis.y.normalized(), body_center),
		"origin": body_center, "gameplay_start": gameplay_start}
	# Extend beyond the tracked point in the logical pixel grid, then
	# clip each ray on the gameplay plane from the stable body anchor.
	var target_pixels := (_project_displacement(projection, delta) - start) / core_pixel_size
	if target_pixels.is_zero_approx():
		return line
	var radius := target_pixels.length() + TARGET_OVERHANG_PIXELS
	var direction := target_pixels.normalized()
	var center := _display_ray(projection, start, direction * radius * core_pixel_size, shot_range)
	line.to = center.point
	line.center = center
	line.projection = projection
	var half_angle := deg_to_rad(profile.x * 0.5)
	if radius * sin(half_angle) >= 0.5:
		for i in FAN_INTERVALS + 1:
			var angle := lerpf(-half_angle, half_angle, float(i) / FAN_INTERVALS)
			var end_offset := direction.rotated(angle) * radius * core_pixel_size
			rays.append(center if i == FAN_INTERVALS / 2 else _display_ray(projection, start, end_offset, shot_range))
	return line

func _display_ray(projection: Dictionary, start: Vector2, end_offset: Vector2, shot_range: float) -> Dictionary:
	var direction := end_offset.normalized()
	var bounds := Rect2(Vector2.ZERO, surface.size).grow(4.0 * core_pixel_size.x)
	var x := bounds.end.x if direction.x > 0.0 else bounds.position.x
	var y := bounds.end.y if direction.y > 0.0 else bounds.position.y
	var reach_x := (x - start.x) / direction.x if absf(direction.x) > 0.00001 else INF
	var reach_y := (y - start.y) / direction.y if absf(direction.y) > 0.00001 else INF
	var reach := minf(end_offset.length(), minf(reach_x, reach_y))
	if reach <= 0.0 or direction.is_zero_approx():
		return {"point": start, "wall": RID(), "distance": 0.0}
	var offset := _gameplay_displacement(projection, start + direction * reach).limit_length(shot_range)
	if offset.is_zero_approx():
		return {"point": start, "wall": RID(), "distance": 0.0}
	var gameplay_start: Vector2 = projection.gameplay_start
	var trace := _wall_trace(gameplay_start, gameplay_start + offset)
	var displacement: Vector2 = trace.position - gameplay_start
	return {"point": _project_displacement(projection, displacement), "wall": trace.wall, "distance": displacement.length()}


func _gameplay_displacement(projection: Dictionary, point: Vector2) -> Vector2:
	var camera: Camera3D = projection.camera
	var viewport_point: Vector2 = point * projection.to_viewport
	var plane: Plane = projection.plane
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(viewport_point), camera.project_ray_normal(viewport_point))
	if hit == null:
		return Vector2.ZERO
	var displacement: Vector3 = projection.to_map * (hit - projection.origin)
	return Vector2(displacement.x, displacement.z) * 32.0

func _project_displacement(projection: Dictionary, displacement: Vector2) -> Vector2:
	var point: Vector3 = projection.origin + projection.basis * Vector3(displacement.x, 0.0, displacement.y) / 32.0
	return screen_point(point)

func _clip_display_point(projection: Dictionary, point: Vector2, distance: float) -> Vector2:
	var displacement := _gameplay_displacement(projection, point)
	if displacement.length_squared() <= distance * distance:
		return point
	return _project_displacement(projection, displacement.limit_length(distance))

func _body_height(at: Vector3) -> float:
	var camera: Camera3D = world.camera_3d
	return maxf(1.0, screen_point(at).distance_to(screen_point(at + camera.global_basis.y * 1.10)))

func _can_draw() -> bool:
	return visible and can_process() and is_instance_valid(world) and world.floor_root==get_parent() and is_instance_valid(world.player) and not world.player.dead and not world.floor_transition_in_progress and world.transition_phase==&"IDLE"

func screen_point(point: Vector3) -> Vector2:
	return world.player.get_presentation_hud_position(world.camera_3d.unproject_position(point))-surface.position

func wall_end(start: Vector2,end: Vector2) -> Vector2:
	return _wall_trace(start, end).position

func _wall_trace(start: Vector2, end: Vector2) -> Dictionary:
	var query:=PhysicsRayQueryParameters2D.create(start,end,1|4)
	var exclusions: Array[RID]=[world.player.get_rid()]
	for i in 12:
		query.exclude=exclusions
		var hit: Dictionary=world.player.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return {"position": end, "wall": RID()}
		var collider: Node=hit.get("collider")
		if collider != null and (collider.is_in_group(&"glass_windows") or collider.is_in_group(&"breakable_glass_windows")):
			exclusions.append(collider.get_rid()); continue
		return {"position": hit.position, "wall": hit.rid}
	return {"position": start, "wall": RID()}

func aim_segment(enemy: Node) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.has_method("get_ranged_telegraph_state"): return {}
	if not _source_not_smoke_hidden(enemy): return {}
	var state: Dictionary=enemy.get_ranged_telegraph_state()
	if state.is_empty(): return {}
	# Outside patrols see through the opening from the forward sensor/weapon.
	# The drawing still starts at the airframe and respects every wall ray.
	var sight_start: Vector2 = state.get("sight_start", enemy.global_position)
	if wall_end(world.player.global_position, sight_start).distance_to(sight_start) > 0.5:
		return {}
	var start: Vector2 = state.start if state.has("start") else enemy.projectile_origin.global_position
	var shot_range: float = state.get("shot_range", -1.0)
	var center_world: Vector3
	if enemy is EmployeeEnemy and enemy._is_otxo_mode():
		start = enemy.global_position
		shot_range = _shot_range(enemy)
		center_world = _employee_warning_center(enemy)
	elif shot_range >= 0.0:
		center_world = state.center_world
	var segment := {"start": start, "end": state.target, "target": state.target, "progress": state.progress}
	if shot_range >= 0.0:
		segment.shot_range = shot_range
		segment.center_world = center_world
	else:
		segment.end = wall_end(start, state.target)
	return segment

func _employee_warning_center(enemy: EmployeeEnemy) -> Vector3:
	# The standing body pivot is authored in billboard pixels. Its rest
	# position stays centered when the held weapon or pose animates.
	var ground: Vector3 = world.get_gameplay_world_position(enemy.body_collision.global_position, 0.0)
	var rise := -enemy.body_pivot_base_position.y * absf(enemy.base_visual_scale.y) / 32.0
	return ground + world.camera_3d.global_basis.y.normalized() * rise


func _source_not_smoke_hidden(enemy: Node2D) -> bool:
	if enemy.get_meta(&"smoke_hidden_from_player", false): return false
	if world.has_method("is_smoke_sight_blocked") and world.is_smoke_sight_blocked(world.player.global_position, enemy.global_position): return false
	return true

func draw_lines() -> void:
	last_drawn_enemy_ids.clear()
	if not _can_draw(): return
	for line in prepared_lines:
		last_drawn_enemy_ids.append(line.id)
		if line.has("profile"):
			_draw_long_fan(line)
		else:
			surface.draw_line(line.from,line.to,line.style.color,line.style.width,true)
	for tail in prepared_tails:
		last_drawn_enemy_ids.append(tail.id)
	for flash in flashes:
		var center:=screen_point(world.get_gameplay_world_position(flash.point,.75))
		surface.draw_arc(center,9.0*(1.0-float(flash.left)/.12),0,TAU,12,Color(1,.9,.65),2,false)
		surface.draw_line(center-Vector2(8,0),center+Vector2(8,0),Color.WHITE,1,false)

func _draw_long_fan(line: Dictionary) -> void:
	var rays: Array[Dictionary] = line.fan_rays
	if rays.is_empty():
		return
	var start: Vector2 = line.from
	var profile: Vector4 = line.profile
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in rays.size() - 1:
		var first: Vector2 = rays[i].point - start
		var second: Vector2 = rays[i + 1].point - start
		var reach := minf(first.length(), second.length())
		if rays[i].wall != rays[i + 1].wall and absf(first.length() - second.length()) > 6.0 + reach * .07:
			# Only this narrow slice straddles a discontinuity. Clip it
			# conservatively without shortening the clear part of the fan.
			first = first.normalized() * reach
			second = second.normalized() * reach
		var offset := vertices.size()
		vertices.append_array(PackedVector2Array([start, start + first, start + second]))
		colors.append_array(PackedColorArray([Color(.96, .19, .15, profile.y),
			Color(.96, .24, .19, profile.y * .79), Color(.96, .24, .19, profile.y * .79)]))
		indices.append_array(PackedInt32Array([offset, offset + 1, offset + 2]))
	RenderingServer.canvas_item_add_triangle_array(surface.get_canvas_item(), indices, vertices, colors, PackedVector2Array())
	var width := core_pixel_size.x * 3.4
	var spread := maxf(start.distance_to(rays[0].point), start.distance_to(rays[-1].point)) * sin(deg_to_rad(profile.x * .5))
	var edge_alpha := profile.w * clampf(spread / width, 0.0, 1.0)
	_draw_soft_edge(line.projection, start, rays[0], width, edge_alpha)
	_draw_soft_edge(line.projection, start, rays[-1], width, edge_alpha)

func _draw_soft_edge(projection: Dictionary, start: Vector2, ray: Dictionary, width: float, alpha: float) -> void:
	var axis: Vector2 = ray.point - start
	var length := axis.length()
	if length < 1.0:
		return
	var edge_start := minf(.18, width / length)
	var vertices := _soft_edge_vertices(projection, start, ray, width, edge_start)
	var colors := PackedColorArray()
	for strength in [0.0, 1.0, 1.0, 0.0]:
		for coverage in EDGE_COVERAGE:
			colors.append(Color(.98, .22, .14, alpha * strength * coverage))
	RenderingServer.canvas_item_add_triangle_array(surface.get_canvas_item(), edge_indices, vertices, colors, PackedVector2Array())

func _soft_edge_vertices(projection: Dictionary, start: Vector2, ray: Dictionary, width: float, edge_start: float) -> PackedVector2Array:
	var axis: Vector2 = ray.point - start
	var normal := axis.normalized().orthogonal()
	var vertices := PackedVector2Array()
	for progress in [0.0, edge_start, 1.0 - edge_start, 1.0]:
		for lane in EDGE_LANES:
			var point: Vector2 = start + axis * progress + normal * width * lane
			vertices.append(_clip_display_point(projection, point, ray.distance))
	return vertices

func _draw_pixel_cores() -> void:
	if not _can_draw():
		return
	for line in prepared_lines:
		if line.has("profile"):
			_draw_pixel_core(line)
	for line in prepared_tails:
		_draw_pixel_core(line)

func _draw_pixel_core(line: Dictionary) -> void:
	var start: Vector2 = line.from / core_pixel_size
	var finish: Vector2 = line.to / core_pixel_size
	var axis := finish - start
	var length := axis.length()
	if length < 1.0:
		return
	var unit := axis / length
	var normal := unit.orthogonal()
	var vertices := _pixel_core_vertices(line, start, finish, unit, normal)
	var uv := PackedVector2Array()
	for point in vertices:
		var offset := point / core_pixel_size - start
		uv.append(Vector2(offset.dot(normal), offset.dot(unit) / length))
	var ink := Color(.94, .105, .10, float(line.profile.z) * float(line.tail))
	var colors := PackedColorArray([ink, ink, ink, ink])
	RenderingServer.canvas_item_add_triangle_array(pixel_core.get_canvas_item(), PackedInt32Array([0, 1, 2, 0, 2, 3]), vertices, colors, uv)

func _pixel_core_vertices(line: Dictionary, start: Vector2, finish: Vector2, unit: Vector2, normal: Vector2) -> PackedVector2Array:
	var edge := normal * 1.5
	var vertices := PackedVector2Array()
	for corner: Vector2 in [start - unit - edge, start - unit + edge, finish + unit + edge, finish + unit - edge]:
		vertices.append(_clip_display_point(line.projection, corner * core_pixel_size, line.center.distance))
	return vertices

func _notification(what: int) -> void:
	if what==NOTIFICATION_DISABLED: visible=false
	elif what==NOTIFICATION_ENABLED:
		visible=true
		_claim_layer()
	elif what==NOTIFICATION_PREDELETE and is_instance_valid(layer): layer.queue_free()
