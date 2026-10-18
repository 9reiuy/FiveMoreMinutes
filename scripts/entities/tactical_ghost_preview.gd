class_name TacticalGhostPreview
extends CanvasLayer
var _cached_dream_world: Node

## Tactical Planning Visual Preview Overlay
## Renders:
## 1. 2x semi-transparent tactical dash range circle (perspective-projected in 3D)
## 2. Dynamic marching-ants path (Katana ZERO dual-color alternating flicker)
## 3. Holographic player ghost silhouette at planned landing destination
## 4. Bright red aim direction line from destination toward cursor (always shown)
##
## Architected as a CanvasLayer (layer 15) so it is NEVER hidden by the 3D dungeon's
## hidden GameplayCanvas, yet stays cleanly underneath HUD and PauseMenu (layer 20+).

const KATANA_TRAIL_SHADER: Shader = preload("res://shaders/katana_zero_trail.gdshader")

# Marching-ants segment dimensions
const ANT_SEG_LEN: float = 6.0   # colored block length in px
const ANT_GAP_LEN: float = 3.0   # gap between blocks in px
const ANT_WIDTH: float = 2.0
const ANT_FLASH_RATE: float = 0.06  # phase toggle interval in seconds

var max_range: float = 200.0
var destination: Vector2 = Vector2.ZERO
var aim_target: Vector2 = Vector2.ZERO
var is_destination_confirmed: bool = false
var is_aim_confirmed: bool = false
var path_segments: Array = []

var player: CharacterBody2D = null
var ghost_container: Node2D = null
var _draw_control: Control = null
var _time_accum: float = 0.0
## 0 or 1 – controls which color is "leading" in the marching ants
var _ant_phase: int = 0
var _ant_phase_timer: float = 0.0


class TacticalDrawCanvas extends Control:
	var overlay: TacticalGhostPreview = null

	func _draw() -> void:
		if overlay != null:
			overlay._render_draw(self)



func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world


func _ready() -> void:
	layer = 15
	visible = false

	_draw_control = TacticalDrawCanvas.new()
	_draw_control.name = "OverlayDrawControl"
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_draw_control as TacticalDrawCanvas).overlay = self
	add_child(_draw_control)

	ghost_container = Node2D.new()
	ghost_container.name = "GhostContainer"
	_draw_control.add_child(ghost_container)

	if player == null and get_parent() is CharacterBody2D:
		player = get_parent() as CharacterBody2D


func _process(delta: float) -> void:
	if not visible:
		return
	_time_accum += delta
	# Advance marching-ants phase timer
	_ant_phase_timer += delta
	if _ant_phase_timer >= ANT_FLASH_RATE:
		_ant_phase_timer = fmod(_ant_phase_timer, ANT_FLASH_RATE)
		_ant_phase = 1 - _ant_phase

	_update_ghost_transform()
	queue_redraw()


func queue_redraw() -> void:
	if _draw_control != null and is_instance_valid(_draw_control):
		_draw_control.queue_redraw()


func start_preview(source_visual: Node2D, range_radius: float) -> void:
	if player == null and get_parent() is CharacterBody2D:
		player = get_parent() as CharacterBody2D

	var origin: Vector2 = player.global_position if (player != null and is_instance_valid(player)) else Vector2.ZERO
	max_range = maxf(range_radius, 10.0)
	is_destination_confirmed = false
	is_aim_confirmed = false
	destination = origin
	aim_target = origin
	path_segments.clear()
	_time_accum = 0.0
	_ant_phase = 0
	_ant_phase_timer = 0.0

	_rebuild_ghost_visual(source_visual)
	_update_ghost_transform()

	visible = true
	queue_redraw()


func update_destination(path_result: Dictionary, confirmed: bool) -> void:
	is_destination_confirmed = confirmed
	var fallback_origin: Vector2 = player.global_position if (player != null and is_instance_valid(player)) else Vector2.ZERO
	destination = path_result.get("end", fallback_origin)
	var segs: Variant = path_result.get("segments", [])
	if segs is Array:
		path_segments = segs
	else:
		path_segments = []

	_update_ghost_transform()
	queue_redraw()


func update_aim(target_pos: Vector2, confirmed: bool) -> void:
	aim_target = target_pos
	is_aim_confirmed = confirmed
	_update_ghost_transform()
	queue_redraw()


func end_preview() -> void:
	visible = false
	path_segments.clear()
	is_destination_confirmed = false
	is_aim_confirmed = false
	if ghost_container != null:
		for child in ghost_container.get_children():
			child.queue_free()
	queue_redraw()


func _world_to_screen(gameplay_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp != null:
		# Check for 3D Camera (perspective dungeon presentation)
		var world := _dream_world() if get_tree() != null else null
		var cam3d := world.get("camera_3d") as Camera3D if world != null else vp.get_camera_3d()
		if cam3d == null and get_tree() != null:
			cam3d = get_tree().root.find_child("Camera3D", true, false) as Camera3D
		if cam3d != null and cam3d.current:
			return _camera_to_hud(cam3d.unproject_position(_gameplay_world_position(gameplay_pos, 0.0)))

		# Check for 2D Camera
		var cam2d := vp.get_camera_2d()
		if cam2d == null and get_tree() != null:
			cam2d = get_tree().root.find_child("DreamCamera", true, false) as Camera2D
		if cam2d != null:
			var cam_center := cam2d.get_screen_center_position()
			var vp_size := vp.get_visible_rect().size
			return (gameplay_pos - cam_center) * cam2d.zoom + vp_size * 0.5

	return gameplay_pos


func _camera_to_hud(viewport_position: Vector2) -> Vector2:
	if player != null and is_instance_valid(player) and player.has_method("get_presentation_hud_position"):
		return player.call("get_presentation_hud_position", viewport_position)
	return viewport_position


func _gameplay_world_position(gameplay_pos: Vector2, height: float) -> Vector3:
	# The 3D dungeon owns the rotated map transform. Never interpret gameplay
	# X/Z as global coordinates: the preview must use the same mapping as the
	# actual dash path, player depth bridge and final landing point.
	var world := _dream_world() as Node3D if get_tree() != null else null
	if world != null and world.has_method("get_gameplay_world_position"):
		return world.call("get_gameplay_world_position", gameplay_pos, height)
	return Vector3(gameplay_pos.x / 32.0, height, gameplay_pos.y / 32.0)


func _update_ghost_transform() -> void:
	if ghost_container == null:
		return
	var dest_screen := _world_to_screen(destination)
	ghost_container.position = dest_screen

	var vp := get_viewport()
	var world := _dream_world() if get_tree() != null else null
	var cam3d: Camera3D = world.get("camera_3d") as Camera3D if world != null else (vp.get_camera_3d() if vp != null else null)
	if cam3d == null and get_tree() != null:
		cam3d = get_tree().root.find_child("Camera3D", true, false) as Camera3D

	var scale_val := 1.0
	if cam3d != null and cam3d.current:
		var ground_pt := _gameplay_world_position(destination, 0.0)
		var head_pt := _gameplay_world_position(destination, 1.0)
		var foot_screen := _camera_to_hud(cam3d.unproject_position(ground_pt))
		var head_screen := _camera_to_hud(cam3d.unproject_position(head_pt))
		var h_px := (foot_screen - head_screen).length()
		scale_val = clampf(h_px / 32.0, 0.3, 3.0)
	elif vp != null and vp.get_camera_2d() != null:
		scale_val = vp.get_camera_2d().zoom.x

	var aim_diff := _world_to_screen(aim_target) - dest_screen
	var flip := -1.0 if aim_diff.x < -0.05 else 1.0
	ghost_container.scale = Vector2(flip * scale_val, scale_val)


func _rebuild_ghost_visual(source_visual: Node2D) -> void:
	if ghost_container == null:
		return
	for child in ghost_container.get_children():
		child.queue_free()

	if source_visual == null or not is_instance_valid(source_visual):
		return

	var snapshot := Node2D.new()
	snapshot.name = "Snapshot"
	snapshot.rotation = source_visual.rotation
	snapshot.scale = source_visual.scale
	snapshot.modulate = Color(0.0, 0.95, 1.0, 0.85)
	ghost_container.add_child(snapshot)

	_copy_sprites_recursive(source_visual, snapshot)


func _copy_sprites_recursive(source: Node, target: Node2D) -> void:
	for child_variant in source.get_children():
		var child: Node = child_variant as Node
		if child == null or not child is Node2D or not child.visible:
			continue
		if child is Sprite2D:
			var src_sp: Sprite2D = child as Sprite2D
			var sp := Sprite2D.new()
			sp.name = src_sp.name
			sp.texture = src_sp.texture
			sp.texture_filter = src_sp.texture_filter
			sp.region_enabled = src_sp.region_enabled
			sp.region_rect = src_sp.region_rect
			sp.hframes = src_sp.hframes
			sp.vframes = src_sp.vframes
			sp.frame = src_sp.frame
			sp.flip_h = src_sp.flip_h
			sp.flip_v = src_sp.flip_v
			sp.offset = src_sp.offset
			sp.centered = src_sp.centered
			sp.position = src_sp.position
			sp.rotation = src_sp.rotation
			sp.scale = src_sp.scale
			sp.z_index = src_sp.z_index

			var mat := ShaderMaterial.new()
			mat.shader = KATANA_TRAIL_SHADER
			mat.set_shader_parameter("primary_color", Color(0.0, 0.95, 1.0, 0.95))
			mat.set_shader_parameter("secondary_color", Color(1.0, 0.08, 0.62, 0.85))
			mat.set_shader_parameter("split_pixels", 2.2)
			mat.set_shader_parameter("scanline_strength", 0.35)
			mat.set_shader_parameter("core_brightness", 1.4)
			sp.material = mat

			target.add_child(sp)
		elif child.get_child_count() > 0:
			var sub_container := Node2D.new()
			sub_container.position = child.position
			sub_container.rotation = child.rotation
			sub_container.scale = child.scale
			target.add_child(sub_container)
			_copy_sprites_recursive(child, sub_container)


## Draw a marching-ants dashed line between two screen-space points.
## Alternates between bright red and white blocks in Katana ZERO style.
func _draw_marching_ants(ci: CanvasItem, p_from: Vector2, p_to: Vector2) -> void:
	var diff: Vector2 = p_to - p_from
	var total_len: float = diff.length()
	if total_len < 0.5:
		return
	var dir: Vector2 = diff / total_len
	var pitch: float = ANT_SEG_LEN + ANT_GAP_LEN
	# Colors: Katana ZERO bright red and pure white
	var col_a: Color = Color(1.0, 0.12, 0.25, 1.0)   # #FF1F40 bright red
	var col_b: Color = Color(1.0, 1.0, 1.0, 1.0)     # white
	# Scroll offset: moves at 80 px/s so segments appear to flow
	var scroll: float = fmod(_time_accum * 80.0, pitch)
	var pos: float = -scroll
	var seg_index: int = 0
	while pos < total_len:
		var seg_start: float = maxf(pos, 0.0)
		var seg_end: float = minf(pos + ANT_SEG_LEN, total_len)
		if seg_end > seg_start + 0.1:
			var use_a: bool = (seg_index % 2 == _ant_phase)
			ci.draw_line(p_from + dir * seg_start, p_from + dir * seg_end,
					col_a if use_a else col_b, ANT_WIDTH)
		pos += pitch
		seg_index += 1


func _render_draw(ci: CanvasItem) -> void:
	if not visible:
		return

	var center_gameplay: Vector2 = player.global_position if (player != null and is_instance_valid(player)) else destination

	# 1. 2倍战术范围圆环 (在地面空间采样，再投影到屏幕，保证3D透视下贴合地面)
	var ring_points := PackedVector2Array()
	var sample_count := 64
	for i in range(sample_count):
		var angle := i * (TAU / float(sample_count))
		var p_gameplay := center_gameplay + Vector2(cos(angle), sin(angle)) * max_range
		ring_points.append(_world_to_screen(p_gameplay))
	if not ring_points.is_empty():
		ring_points.append(ring_points[0])

	var range_color := Color(0.12, 0.72, 1.0, 0.45)
	var fill_color := Color(0.05, 0.35, 0.75, 0.04)
	if ring_points.size() > 2:
		ci.draw_colored_polygon(ring_points, fill_color)
		ci.draw_polyline(ring_points, range_color, 1.5, true)

	# 刻度标记（上下左右四方位微小十字线）
	var tick_dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for d in tick_dirs:
		var p1 := _world_to_screen(center_gameplay + d * (max_range - 6.0))
		var p2 := _world_to_screen(center_gameplay + d * (max_range + 6.0))
		ci.draw_line(p1, p2, Color(0.2, 0.85, 1.0, 0.80), 1.5)

	var dest_screen := _world_to_screen(destination)
	var player_screen := _world_to_screen(center_gameplay)

	# 2. 预测折线轨迹 —— 武士零红白蚂蚁线
	if path_segments.is_empty():
		# Fallback: draw line from player to destination
		if (dest_screen - player_screen).length_squared() > 16.0:
			_draw_marching_ants(ci, player_screen, dest_screen)
	else:
		for segment_variant in path_segments:
			if not segment_variant is Dictionary:
				continue
			var segment: Dictionary = segment_variant
			var p1_gameplay: Vector2 = segment.get("start", center_gameplay)
			var p2_gameplay: Vector2 = segment.get("end", destination)
			var p1_scr := _world_to_screen(p1_gameplay)
			var p2_scr := _world_to_screen(p2_gameplay)
			var kind: StringName = StringName(segment.get("kind", &"move"))
			if kind == &"vault":
				# 翻越低矮家具段：金黄虚线
				ci.draw_dashed_line(p1_scr, p2_scr, Color(1.0, 0.85, 0.22, 0.95), 2.5, 4.0)
			else:
				# 高速冲刺段：武士零红白交替蚂蚁线
				_draw_marching_ants(ci, p1_scr, p2_scr)

	# 3. 规划落点标记
	if not is_destination_confirmed:
		# Step 0 动态落点准心
		var pulse := 8.5 + sin(_time_accum * 12.0) * 2.0
		ci.draw_arc(dest_screen, pulse, 0.0, TAU, 32, Color(0.0, 0.95, 1.0, 0.85), 1.5)
		ci.draw_circle(dest_screen, 3.0, Color(0.0, 0.95, 1.0, 0.9))
		ci.draw_line(dest_screen - Vector2(12, 0), dest_screen + Vector2(12, 0), Color(0.0, 0.95, 1.0, 0.6), 1.0)
		ci.draw_line(dest_screen - Vector2(0, 12), dest_screen + Vector2(0, 12), Color(0.0, 0.95, 1.0, 0.6), 1.0)
	else:
		# Step 1 已锁定落点：金黄锁定光环
		ci.draw_arc(dest_screen, 10.5, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 0.95), 2.0)
		ci.draw_circle(dest_screen, 3.5, Color(1.0, 0.85, 0.2, 1.0))

	# 4. 射击方向线 —— 始终显示，从落点指向 aim_target
	var aim_screen := _world_to_screen(aim_target)
	var aim_diff := aim_screen - dest_screen
	var aim_dir := aim_diff.normalized() if aim_diff.length_squared() > 1.0 else Vector2.RIGHT

	if not is_destination_confirmed:
		# Step 0: 短箭头从当前落点指向鼠标方向，表达"冲到这里会向这个方向射击"
		var arrow_len := 44.0
		var arrow_end := dest_screen + aim_dir * arrow_len
		var col_arrow := Color(1.0, 0.12, 0.22, 0.90)
		ci.draw_line(dest_screen, arrow_end, col_arrow, 2.0)
		# 箭头尖
		ci.draw_line(arrow_end, arrow_end + aim_dir.rotated(deg_to_rad(145.0)) * 8.0, col_arrow, 2.0)
		ci.draw_line(arrow_end, arrow_end + aim_dir.rotated(deg_to_rad(-145.0)) * 8.0, col_arrow, 2.0)
	else:
		# Step 1: 从锁定落点射出一条亮红实线延伸至准星
		var laser_len := maxf(aim_diff.length(), 60.0)
		var laser_end := dest_screen + aim_dir * laser_len
		# 发光底层（宽且半透明）
		ci.draw_line(dest_screen, laser_end, Color(1.0, 0.08, 0.2, 0.30), 5.0)
		# 主线（高亮鲜红）
		ci.draw_line(dest_screen, laser_end, Color(1.0, 0.05, 0.18, 1.0), 2.0)

		# 瞄准点准星
		var xhair_col := Color(1.0, 0.85, 0.2, 0.98) if is_aim_confirmed else Color(1.0, 0.2, 0.3, 0.92)
		ci.draw_arc(aim_screen, 7.5, 0.0, TAU, 20, xhair_col, 1.5)
		ci.draw_line(aim_screen - Vector2(11, 0), aim_screen - Vector2(4, 0), xhair_col, 1.5)
		ci.draw_line(aim_screen + Vector2(4, 0), aim_screen + Vector2(11, 0), xhair_col, 1.5)
		ci.draw_line(aim_screen - Vector2(0, 11), aim_screen - Vector2(0, 4), xhair_col, 1.5)
		ci.draw_line(aim_screen + Vector2(0, 4), aim_screen + Vector2(0, 11), xhair_col, 1.5)

		if is_aim_confirmed:
			var diamond := PackedVector2Array([
				aim_screen + Vector2(0, -11),
				aim_screen + Vector2(11, 0),
				aim_screen + Vector2(0, 11),
				aim_screen + Vector2(-11, 0),
				aim_screen + Vector2(0, -11)
			])
			ci.draw_polyline(diamond, Color(1.0, 0.85, 0.2, 0.98), 1.5)
