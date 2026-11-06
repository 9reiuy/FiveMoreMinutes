extends Node
## Gate existing native presentation only; the authoritative actor is untouched.
const ACTOR_BRIDGE_PATH := "res://scripts/dream/dream_3d_actor_depth_bridge.gd"
const AIRBORNE_BLOOD_PATH := "res://scripts/dream/blood_airborne_carrier_3d.gd"
const FURNITURE_VISUAL_PATH := "res://scripts/dream/furniture_3d_visual.gd"

class CarrierState extends RefCounted:
	var carrier: Node3D
	var source: Node2D
	var viewport: SubViewport
	var passive_capture := false
	var capture_paused := false
	var process_mode := 0
	var viewport_mode := 0
	var base_visible := true
	var last_applied := true
	var los_visible := true
	var probe_visible := false
	var probe_revision := -1
	var probe_position := Vector2(INF, INF)
	var callback: Callable
	var seen_frame := -1

var world: Node3D
var field: Object
var enabled := false
var include_furniture := false
var prop_sample_offsets := PackedVector2Array()
var managed_count := 0
var hidden_count := 0
var visibility_changes := 0
var reflection_refreshes := 0
var last_update_usec := 0
var last_reflection_usec := 0
var paused_captures := 0
var _records: Dictionary[int, CarrierState] = {}
var _writing_visibility := false
var _updating := false
var _frame := 0

func configure(owner_world: Node3D, visibility_field: Object) -> void:
	restore()
	world = owner_world
	field = visibility_field
	enabled = is_instance_valid(world) and is_instance_valid(field) and field.has_method("is_point_visible")
	if enabled: update_now()

func update_now() -> void:
	var started := Time.get_ticks_usec()
	if not enabled or _updating: return
	if not is_instance_valid(world) or not is_instance_valid(field):
		restore()
		return
	_updating = true
	_frame += 1
	hidden_count = 0
	var reflected_actor_changed := false
	var root := world.get_node_or_null(^"ActorDepthBridges")
	var revision: int = field.visibility_revision
	# Pools reuse a carrier without node_added. A generation stamp avoids
	# allocating a new set of bookkeeping dictionaries on every draw.
	if is_instance_valid(root):
		for child in root.get_children():
			if not child is Node3D or child.is_queued_for_deletion(): continue
			var carrier := child as Node3D
			var id := carrier.get_instance_id()
			var record: CarrierState = _records.get(id)
			var source: Node2D = carrier.source_actor if record != null and record.passive_capture else _source_for(carrier)
			if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree() or source.is_in_group(&"dream_player"): continue
			if record != null and record.source != source:
				_release_record(id)
				record = null
			if record == null: record = _register(carrier, source)
			record.seen_frame = _frame
			if carrier.visible != record.last_applied: record.base_visible = carrier.visible
			var active := source.visible
			if record.passive_capture: active = active and bool(carrier.room_presentation_active)
			var position := source.global_position
			if active and (record.probe_revision != revision or record.probe_position != position):
				record.probe_visible = _source_visible(source, position)
				record.probe_revision = revision
				record.probe_position = position
			record.los_visible = active and record.probe_visible
			if not record.los_visible: hidden_count += 1
			if _apply(record, record.base_visible and record.los_visible) and (source.is_in_group(&"dream_enemies") or source.is_in_group(&"damageable_props")):
				reflected_actor_changed = true
	for id in _records.keys():
		if _records[id].seen_frame != _frame: _release_record(id)
	managed_count = _records.size()
	_updating = false
	if reflected_actor_changed: _refresh_reflection()
	last_update_usec = Time.get_ticks_usec() - started

func _script_path(node: Node) -> String:
	var script := node.get_script() as Script
	return script.resource_path if script != null else ""

func _source_for(carrier: Node3D) -> Node2D:
	match _script_path(carrier):
		ACTOR_BRIDGE_PATH:
			return carrier.source_actor as Node2D if carrier.configured else null
		AIRBORNE_BLOOD_PATH:
			if not carrier.configured or carrier.cleanup_queued: return null
			var reference := carrier.source_effect_ref as WeakRef
			return reference.get_ref() as Node2D if reference != null else null
		FURNITURE_VISUAL_PATH:
			if include_furniture: return carrier.source_actor as Node2D
	return null

func _source_visible(source: Node2D, ground: Vector2) -> bool:
	# The gameplay CanvasLayer is hidden by the existing 3D presentation.
	if field.is_point_visible(ground, 0.0): return true
	if source.is_in_group(&"dream_enemies") or not source.is_in_group(&"damageable_props"): return false
	for offset in prop_sample_offsets:
		if field.is_point_visible(source.to_global(offset), 0.0): return true
	return false

func _register(carrier: Node3D, source: Node2D) -> CarrierState:
	var id := carrier.get_instance_id()
	var record := CarrierState.new()
	record.carrier = carrier
	record.source = source
	record.base_visible = carrier.visible
	record.last_applied = carrier.visible
	record.passive_capture = _script_path(carrier) == ACTOR_BRIDGE_PATH
	if record.passive_capture: record.viewport = carrier.render_viewport
	record.callback = _on_visibility_changed.bind(id)
	_records[id] = record
	carrier.visibility_changed.connect(record.callback)
	return record

func _on_visibility_changed(id: int) -> void:
	if _writing_visibility: return
	var record: CarrierState = _records.get(id)
	if record == null or not is_instance_valid(record.carrier): return
	if record.carrier.visible != record.last_applied:
		record.base_visible = record.carrier.visible
		record.last_applied = record.carrier.visible

func _apply(record: CarrierState, value: bool, allow_capture_pause := true) -> bool:
	var carrier := record.carrier
	if not is_instance_valid(carrier): return false
	if allow_capture_pause and not value and record.passive_capture:
		if is_instance_valid(record.viewport):
			if not record.capture_paused:
				record.capture_paused = true
				record.process_mode = carrier.process_mode
				record.viewport_mode = record.viewport.render_target_update_mode
				paused_captures += 1
			if carrier.process_mode != Node.PROCESS_MODE_DISABLED: carrier.process_mode = Node.PROCESS_MODE_DISABLED
			if record.viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED: record.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else: _resume_capture(record, value)
	record.last_applied = value
	if carrier.visible == value: return false
	_writing_visibility = true
	carrier.visible = value
	_writing_visibility = false
	visibility_changes += 1
	return true

func _resume_capture(record: CarrierState, refresh: bool) -> void:
	if not record.capture_paused: return
	record.capture_paused = false
	var carrier := record.carrier
	if not is_instance_valid(carrier): return
	carrier.process_mode = record.process_mode
	if is_instance_valid(record.viewport): record.viewport.render_target_update_mode = record.viewport_mode
	if refresh and is_instance_valid(record.source) and not record.source.is_queued_for_deletion():
		# Refresh the current native pose once; no historical frame is retained.
		var had_meta := carrier.has_meta(&"test_legacy_character_sync_every_frame")
		var old_meta: Variant = carrier.get_meta(&"test_legacy_character_sync_every_frame", false)
		carrier.set_meta(&"test_legacy_character_sync_every_frame", true)
		carrier._process(0.0)
		if had_meta: carrier.set_meta(&"test_legacy_character_sync_every_frame", old_meta)
		else: carrier.remove_meta(&"test_legacy_character_sync_every_frame")

func _release_record(id: int) -> bool:
	var record: CarrierState = _records[id]
	_records.erase(id)
	var carrier := record.carrier
	if not is_instance_valid(carrier): return false
	if carrier.visibility_changed.is_connected(record.callback): carrier.visibility_changed.disconnect(record.callback)
	if carrier.visible != record.last_applied:
		_resume_capture(record, false)
		return false
	return _apply(record, record.base_visible, false)

func _refresh_reflection() -> void:
	var started := Time.get_ticks_usec()
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion(): return
	var reflections := world.get_node_or_null(^"FloorReflections")
	if reflections == null or reflections.restored or not reflections.enabled: return
	reflections.last_render_usec = 0
	reflections._before_draw()
	reflection_refreshes += 1
	last_reflection_usec = Time.get_ticks_usec() - started

func restore() -> void:
	enabled = false
	var changed := false
	for id in _records.keys(): changed = _release_record(id) or changed
	managed_count = 0
	hidden_count = 0
	if changed: _refresh_reflection()
	world = null
	field = null

func _exit_tree() -> void:
	restore()
