extends Node
## Native BaseMaterial3D/implicit Sprite3D presentation fallback.
const PIXELS_PER_CELL := 32.0
const STRUCTURAL_NAMES: Array[StringName] = [
	&"WallMesh", &"DoorVisual", &"LeftDoorMesh", &"RightDoorMesh",
	&"ArchitecturalCutSurface", &"ShadowCasterMesh", &"WindowGlassVisual",
]
const EXCLUDED_BRANCHES: Array[StringName] = [
	&"ThrowTrajectoryVisual", &"PlayerDepthVisual3D", &"PlayerPhysicsProxy3D",
]
class PrimitiveState extends RefCounted:
	var visual: VisualInstance3D
	var base_visible := true
	var last_applied := true
	var los_visible := true
	var render_only := false
	var base_layers := 1
	var last_layers := 1
	var reflected := false
	var probe_visible := false
	var probe_revision := -1
	var probe_transform := Transform3D()
	var callback: Callable

var world: Node3D
var field: Object
var enabled := false
var managed_count := 0
var hidden_count := 0
var rays_last_update := 0
var scans := 0
var visibility_changes := 0
var last_update_usec := 0
var _pending_candidates: Dictionary = {}
var _needs_initial_scan := true
var _records: Dictionary[int, PrimitiveState] = {}
var _writing_visibility := false
var _updating := false
var _reflection_dirty := false

func configure(owner_world: Node3D, visibility_field: Object) -> void:
	restore()
	world = owner_world
	field = visibility_field
	world.get_tree().node_added.connect(_node_added)
	set_enabled(true)

func set_enabled(value: bool) -> void:
	if not value:
		enabled = false
		_release_all()
		return
	enabled = is_instance_valid(world) and is_instance_valid(field) and field.has_method("is_point_visible")
	_needs_initial_scan = true
	if enabled: update_now()

func _node_added(node: Node) -> void:
	if is_instance_valid(world) and world.is_ancestor_of(node) and (node is MeshInstance3D or node is Label3D or node is Sprite3D):
		_pending_candidates[node.get_instance_id()] = weakref(node)

func update_now() -> void:
	var started := Time.get_ticks_usec()
	if not enabled or _updating: return
	if not is_instance_valid(world) or not is_instance_valid(field) or not world.is_inside_tree() or world.is_queued_for_deletion():
		restore()
		return
	_updating = true
	_reflection_dirty = false
	if _needs_initial_scan:
		_refresh_candidates()
		_needs_initial_scan = false
	for reference: WeakRef in _pending_candidates.values():
		var candidate := reference.get_ref() as VisualInstance3D
		if is_instance_valid(candidate) and _eligible(candidate) and not _records.has(candidate.get_instance_id()): _register(candidate)
	_pending_candidates.clear()
	rays_last_update = 0
	hidden_count = 0
	var inverse := world.global_transform.affine_inverse()
	var camera: Camera3D = world.camera_3d
	var camera_rect := camera.get_viewport().get_visible_rect().grow(96.0)
	var reflection := world.get_node_or_null(^"FloorReflections")
	var reflected_camera: Camera3D = reflection.camera if reflection != null else null
	var reflected_rect := reflected_camera.get_viewport().get_visible_rect().grow(32.0) if reflected_camera != null else Rect2()
	var revision: int = field.visibility_revision
	for id in _records.keys():
		var record: PrimitiveState = _records[id]
		var visual := record.visual
		if not is_instance_valid(visual) or visual.is_queued_for_deletion() or not visual.is_inside_tree() or not world.is_ancestor_of(visual) or (visual is MeshInstance3D and not _base_materials_only(visual)):
			_release_record(id)
			continue
		if visual.visible != record.last_applied: record.base_visible = visual.visible
		if record.render_only:
			if visual.layers != record.last_layers: record.base_layers = visual.layers
		else: record.base_layers = visual.layers
		record.reflected = reflected_camera != null and (record.base_layers & reflected_camera.cull_mask) != 0
		if not record.base_visible:
			_apply(record, false)
			continue
		var parent := visual.get_parent_node_3d()
		if parent != null and not parent.is_visible_in_tree():
			_apply(record, false)
			continue
		var offscreen := camera.is_position_behind(visual.global_position) or not camera_rect.has_point(camera.unproject_position(visual.global_position))
		if offscreen and (not record.reflected or reflected_camera.is_position_behind(visual.global_position) or not reflected_rect.has_point(reflected_camera.unproject_position(visual.global_position))):
			_apply(record, false)
			continue
		var transform := visual.global_transform
		if record.probe_revision != revision or record.probe_transform != transform:
			record.probe_visible = _any_point_visible(visual, inverse)
			record.probe_revision = revision
			record.probe_transform = transform
		record.los_visible = record.probe_visible
		if not record.los_visible: hidden_count += 1
		_apply(record, record.base_visible and record.los_visible)
	managed_count = _records.size()
	_updating = false
	if _reflection_dirty: _refresh_reflection()
	last_update_usec = Time.get_ticks_usec() - started

func _refresh_candidates() -> void:
	scans += 1
	var candidates: Array[Node] = world.find_children("*", "MeshInstance3D", true, false)
	candidates.append_array(world.find_children("*", "Label3D", true, false))
	candidates.append_array(world.find_children("*", "Sprite3D", true, false))
	for node in candidates:
		var visual := node as VisualInstance3D
		if _eligible(visual) and not _records.has(visual.get_instance_id()): _register(visual)

func _base_materials_only(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0 or mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return false
	if mesh.material_override != null: return mesh.material_override is BaseMaterial3D
	for surface in mesh.mesh.get_surface_count():
		if not mesh.get_active_material(surface) is BaseMaterial3D: return false
	return true

func _eligible(visual: VisualInstance3D) -> bool:
	if not is_instance_valid(visual) or visual.is_queued_for_deletion(): return false
	if visual is MeshInstance3D:
		if not _base_materials_only(visual): return false
	elif visual is Sprite3D:
		if visual.material_override != null or visual.texture == null: return false
	elif not visual is Label3D: return false
	if visual.name in STRUCTURAL_NAMES or String(visual.name).begins_with("FloorBatch_"): return false
	var cursor: Node = visual
	while cursor != null and cursor != world:
		if cursor.name in EXCLUDED_BRANCHES or cursor.is_in_group(&"dream_player"): return false
		var script := cursor.get_script() as Script
		if script != null and script.resource_path in ["res://scripts/dream/dream_3d_actor_depth_bridge.gd", "res://scripts/dream/blood_airborne_carrier_3d.gd"]: return false
		if cursor is MultiMeshInstance3D or cursor is GPUParticles3D: return false
		if cursor.has_meta(&"source_actor"):
			var source: Variant = cursor.get_meta(&"source_actor")
			if source is WeakRef: source = source.get_ref()
			if source is Node and is_instance_valid(source) and source.is_in_group(&"dream_player"): return false
		cursor = cursor.get_parent()
	return cursor == world

func _any_point_visible(visual: VisualInstance3D, inverse: Transform3D) -> bool:
	if visual is Label3D or visual is Sprite3D:
		var point: Vector3 = inverse * visual.global_position
		rays_last_update += 1
		return field.is_point_visible(Vector2(point.x, point.z) * PIXELS_PER_CELL, 0.0)
	var mesh := visual as MeshInstance3D
	var bounds := mesh.get_aabb()
	var to_map := inverse * mesh.global_transform
	var center: Vector3 = to_map * bounds.get_center()
	var samples := PackedVector2Array([Vector2(center.x, center.z) * PIXELS_PER_CELL])
	for index in 8:
		var corner: Vector3 = to_map * bounds.get_endpoint(index)
		var point := Vector2(corner.x, corner.z) * PIXELS_PER_CELL
		var duplicate := false
		for previous in samples:
			if previous.distance_squared_to(point) < 0.0001:
				duplicate = true
				break
		if not duplicate: samples.append(point)
	for point in samples:
		rays_last_update += 1
		if field.is_point_visible(point, 0.0): return true
	return false

func _register(visual: VisualInstance3D) -> void:
	var id := visual.get_instance_id()
	var record := PrimitiveState.new()
	record.visual = visual
	record.base_visible = visual.visible
	record.last_applied = visual.visible
	record.render_only = visual is Sprite3D
	record.base_layers = visual.layers
	record.last_layers = visual.layers
	var reflection := world.get_node_or_null(^"FloorReflections")
	record.reflected = reflection != null and (visual.layers & reflection.camera.cull_mask) != 0
	record.callback = _on_visibility_changed.bind(id)
	_records[id] = record
	visual.visibility_changed.connect(record.callback)

func _on_visibility_changed(id: int) -> void:
	if _writing_visibility: return
	var record: PrimitiveState = _records.get(id)
	if record == null or not is_instance_valid(record.visual): return
	if record.visual.visible != record.last_applied:
		record.base_visible = record.visual.visible
		record.last_applied = record.visual.visible

func _apply(record: PrimitiveState, value: bool) -> bool:
	var visual := record.visual
	if not is_instance_valid(visual): return false
	if record.render_only:
		# Invisible native pool slots keep their real layers for preparation and
		# reuse. Only a live, occluded sprite needs its render layers removed.
		var layers := record.base_layers if value or not visual.visible else 0
		record.last_layers = layers
		if visual.layers == layers: return false
		visual.layers = layers
	else:
		record.last_applied = value
		if visual.visible == value: return false
		_writing_visibility = true
		visual.visible = value
		_writing_visibility = false
	_reflection_dirty = _reflection_dirty or record.reflected
	visibility_changes += 1
	return true

func _release_record(id: int) -> bool:
	var record: PrimitiveState = _records[id]
	_records.erase(id)
	var visual := record.visual
	if not is_instance_valid(visual): return false
	if visual.visibility_changed.is_connected(record.callback): visual.visibility_changed.disconnect(record.callback)
	if record.render_only:
		if visual.layers == record.last_layers: visual.layers = record.base_layers
		return false
	if visual.visible != record.last_applied: return false
	return _apply(record, record.base_visible)

func _release_all() -> void:
	var changed := false
	for id in _records.keys(): changed = _release_record(id) or changed
	managed_count = 0
	hidden_count = 0
	rays_last_update = 0
	if changed: _refresh_reflection()

func _refresh_reflection() -> void:
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion(): return
	var reflection := world.get_node_or_null(^"FloorReflections")
	if reflection == null or reflection.restored or not reflection.enabled: return
	reflection.last_render_usec = 0
	reflection._before_draw()

func restore() -> void:
	if is_instance_valid(world) and world.get_tree() != null and world.get_tree().node_added.is_connected(_node_added):
		world.get_tree().node_added.disconnect(_node_added)
	enabled = false
	_release_all()
	_pending_candidates.clear()
	world = null
	field = null

func _exit_tree() -> void:
	restore()
