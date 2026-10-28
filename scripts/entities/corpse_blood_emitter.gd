class_name CorpseBloodEmitter
extends Node2D
const PERF_TRACE=preload("res://scripts/app/performance_markers.gd")

## A short-lived scheduler for corpse bleed pulses.  It deliberately owns no
## Sprite, shader, bridge or droplet simulation: every visible pulse is routed
## through the world's existing BlackBloodEffect API.

var blood_world: Node = null
var origin_gameplay_position := Vector2.ZERO
var bleed_direction := Vector2.RIGHT
var room_id: int = -1
var intensity: float = 1.0
var duration_left: float = 0.0
var pulse_interval: float = 0.22
var pulse_elapsed: float = 0.0
var decay: float = 0.78
var pulse_index: int = 0
var active: bool = false
var cleanup_queued: bool = false
var floor_token: int = -1
var follow_source: WeakRef
var follows_source := false
const MAX_PULSES_PER_FRAME := 2
@export_group("Corpse Drag Marks")
@export_range(2.0, 32.0, 0.5) var drag_spacing_pixels := 8.0
@export_range(2.0, 32.0, 0.5) var drag_stroke_pixels := 12.0
@export_range(1.0, 24.0, 0.5) var drag_width_pixels := 24.0
@export_range(8.0, 128.0, 1.0) var drag_teleport_threshold_pixels := 48.0
@export_range(1, 4, 1) var drag_max_segments_per_frame := 2
@export_range(1, 64, 1) var drag_max_segments_per_corpse := 24
@export_range(0.1, 30.0, 0.1) var drag_follow_max_seconds := 15.0
var _drag_previous_position := Vector2.ZERO
var _drag_previous_source_position := Vector2.ZERO
var _drag_distance_since_mark := 0.0
var _drag_pending_start := Vector2.ZERO
var _drag_pending_direction := Vector2.ZERO
var _drag_moving := false
var _drag_segments := 0
var _drag_duration_left := 0.0
var _follow_room_initialized := false
var _initial_intensity := 1.0
var _initial_interval := 0.22
var _bleed_elapsed := 0.0


func refresh_floor_token() -> void:
	if is_instance_valid(blood_world) and blood_world.has_method("get_current_floor_token"):
		floor_token = int(blood_world.call("get_current_floor_token"))


func _ready() -> void:
	add_to_group(&"corpse_blood_emitters")


func configure(
	world: Node,
	origin: Vector2,
	source_room_id: int,
	direction: Vector2,
	initial_intensity: float,
	duration: float,
	interval: float,
	decay_factor: float,
	source: Node2D = null
) -> void:
	blood_world = world
	follows_source = source != null
	follow_source = weakref(source) if source != null else null
	refresh_floor_token()
	if source != null and source.has_method("get_corpse_blood_ground_position"):
		origin = source.call("get_corpse_blood_ground_position")
	origin_gameplay_position = origin
	global_position = origin
	_drag_previous_position = origin
	_drag_previous_source_position = source.global_position if source != null else origin
	_drag_distance_since_mark = 0.0
	_drag_pending_start = origin
	_drag_pending_direction = Vector2.ZERO
	_drag_moving = false
	_drag_segments = 0
	_drag_duration_left = drag_follow_max_seconds if follows_source and world != null and world.has_method("spawn_corpse_drag_trail") else 0.0
	_follow_room_initialized = false
	room_id = source_room_id
	bleed_direction = (
		direction.normalized()
		if direction.length_squared() > 0.001
		else Vector2.RIGHT
	)
	intensity = clampf(initial_intensity, 0.35, 1.5)
	_initial_intensity = intensity
	_initial_interval = maxf(interval, 0.05)
	_bleed_elapsed = 0.0
	duration_left = maxf(duration, 0.0)
	pulse_interval = maxf(interval, 0.05)
	pulse_elapsed = 0.0
	decay = clampf(decay_factor, 0.5, 0.99)
	pulse_index = 0
	active = (duration_left > 0.0 or _drag_duration_left > 0.0) and is_instance_valid(blood_world)
	cleanup_queued = false
	if active and duration_left > 0.0:
		_emit_pulse()
		pulse_index += 1
		# The initial pulse is immediate; schedule the next one at the authored
		# interval instead of emitting a duplicate on the very next frame.
		pulse_elapsed = pulse_interval


func _process(delta: float) -> void:
	var started:=PERF_TRACE.begin(self)
	var scope:=PERF_TRACE.scope_begin(self,"blood_active_sim")
	_process_profiled(delta)
	PERF_TRACE.scope_end(self,scope)
	PERF_TRACE.end(self,"blood_process",started)

func _process_profiled(delta:float)->void:
	if not active:
		return
	if not is_instance_valid(blood_world) or blood_world.is_queued_for_deletion():
		stop_and_free()
		return
	if floor_token >= 0 and int(blood_world.call("get_current_floor_token")) != floor_token:
		stop_and_free()
		return
	if floor_token < 0 and blood_world.has_method("get_current_room_id"):
		if int(blood_world.call("get_current_room_id")) != room_id:
			# Corpse bleed must not continue in a room that is no longer active.
			stop_and_free()
			return
	if not _refresh_follow_position():
		stop_and_free()
		return
	if follows_source:
		var source: Node2D = follow_source.get_ref()
		var remaining: Variant = source.get("death_presentation_left")
		if remaining is float or remaining is int:
			if float(remaining) <= 0.0:
				stop_and_free()
				return

	_bleed_elapsed += maxf(delta, 0.0)
	intensity = _initial_intensity * pow(decay, _bleed_elapsed / _initial_interval)
	_update_drag_marks()
	_drag_duration_left -= maxf(delta, 0.0)
	duration_left -= maxf(delta, 0.0)
	pulse_elapsed -= maxf(delta, 0.0)
	var frame_pulses := 0
	while pulse_elapsed <= 0.0 and duration_left > 0.0 and frame_pulses < MAX_PULSES_PER_FRAME:
		_emit_pulse()
		frame_pulses += 1
		pulse_index += 1
		# Later pulses spread farther apart and become shorter, producing a
		# visible burst-to-seep transition without a second particle system.
		pulse_interval = maxf(0.08, pulse_interval * 1.08)
		pulse_elapsed += pulse_interval
	# A stalled frame must not replay a whole trail at the latest source position.
	if pulse_elapsed <= 0.0:
		pulse_elapsed = pulse_interval
	if duration_left <= 0.0 and (_drag_duration_left <= 0.0 or not follows_source or _drag_segments >= drag_max_segments_per_corpse):
		stop_and_free()


func _update_drag_marks() -> void:
	var current := origin_gameplay_position
	var start := _drag_previous_position
	_drag_previous_position = current
	if not follows_source or _drag_duration_left <= 0.0 or not blood_world.has_method("spawn_corpse_drag_trail") or _drag_segments >= drag_max_segments_per_corpse:
		return
	var source: Node2D = follow_source.get_ref() if follow_source != null else null
	if is_instance_valid(source):
		var physical_motion := source.global_position.distance_squared_to(_drag_previous_source_position) > 0.00000001
		_drag_previous_source_position = source.global_position
		if not physical_motion:
			# Camera projection and settling limbs can change the visual contact
			# while the collision root is still. Flush the old tail, never draw
			# a new trail solely because the camera moved.
			current = start
	var movement := current - start
	var distance := movement.length()
	if distance > drag_teleport_threshold_pixels:
		# A scene relocation/rollback is not physical dragging; restart sampling.
		_drag_distance_since_mark = 0.0
		_drag_pending_start = current
		_drag_pending_direction = Vector2.ZERO
		_drag_moving = false
		return
	if distance <= 0.0001:
		# Commit the last partial stroke on the first stationary frame.
		# Later stationary frames must remain completely passive.
		if _drag_distance_since_mark > 0.001:
			_emit_drag_segment(_drag_pending_start, current)
		_drag_distance_since_mark = 0.0
		_drag_pending_start = current
		_drag_pending_direction = Vector2.ZERO
		_drag_moving = false
		return
	var spacing := maxf(minf(drag_spacing_pixels,drag_stroke_pixels), 2.0)
	var direction := movement / distance
	var emitted := 0
	# Preserve corners of the real path. Flush an accumulated straight run
	# before a turn, rather than drawing a chord across the corner.
	if _drag_distance_since_mark>0.001 and _drag_pending_direction.dot(direction)<0.96:
		_emit_drag_segment(_drag_pending_start,start)
		emitted+=1
		_drag_distance_since_mark=0.0
		_drag_pending_start=start
	var consumed := 0.0
	if not _drag_moving:
		# Contact begins with the real first displacement, not an 8px wait.
		consumed = minf(distance, spacing)
		_emit_drag_segment(start, start + direction * consumed)
		emitted += 1
		_drag_pending_start = start + direction * consumed
		_drag_distance_since_mark = 0.0
	_drag_moving = true
	while consumed<distance-0.0001 and emitted<drag_max_segments_per_frame and _drag_segments<drag_max_segments_per_corpse:
		if _drag_distance_since_mark<=0.0001:
			_drag_pending_start=start+direction*consumed
			_drag_pending_direction=direction
		var step := minf(distance-consumed,spacing-_drag_distance_since_mark)
		consumed+=step
		_drag_distance_since_mark+=step
		if _drag_distance_since_mark>=spacing-0.0001:
			_emit_drag_segment(_drag_pending_start,start+direction*consumed)
			emitted+=1
			_drag_distance_since_mark=0.0
			_drag_pending_start=start+direction*consumed
	# Budget-dropped movement must not be replayed at a later stationary point.
	if consumed<distance-0.0001:
		_drag_distance_since_mark=0.0
		_drag_pending_start=current
		_drag_pending_direction=Vector2.ZERO


func _emit_drag_segment(start: Vector2, finish: Vector2) -> void:
	if start.distance_squared_to(finish)<0.0001 or _drag_segments>=drag_max_segments_per_corpse: return
	var retained_blood := _initial_intensity*lerpf(1.0,0.35,clampf(_bleed_elapsed/maxf(drag_follow_max_seconds,0.1),0.0,1.0))
	blood_world.call("spawn_corpse_drag_trail",start,finish,room_id,retained_blood,drag_width_pixels)
	_drag_segments+=1


func _emit_pulse() -> void:
	var scope:=PERF_TRACE.scope_begin(self,"blood_active_init")
	_emit_pulse_profiled()
	PERF_TRACE.scope_end(self,scope)

func _emit_pulse_profiled()->void:
	if blood_world == null or not is_instance_valid(blood_world):
		return
	if not blood_world.has_method("spawn_blood_trail"):
		return
	if not _refresh_follow_position():
		return
	# The shared trail API has a minimum visible stamp size. Once the source
	# falls below that size, skip progressively more pulses rather than pinning
	# every late pulse to the same minimum amount of blood.
	if intensity < 0.35:
		var thinning_stride := maxi(2, ceili(0.35 / maxf(intensity, 0.01)))
		if pulse_index % thinning_stride != 0:
			return
	var pulse_direction := bleed_direction
	if pulse_index >= 3:
		# The first pulses retain the death direction; later seepage fans out
		# locally instead of behaving like another gunshot.
		var fan_angle := sin(float(pulse_index) * 1.6180339) * 0.9
		pulse_direction = bleed_direction.rotated(fan_angle)
	var local_offset := Vector2.ZERO if follows_source else bleed_direction * minf(float(pulse_index) * 1.25, 8.0)
	var pulse_position := origin_gameplay_position + local_offset
	var pulse_intensity := clampf(intensity, 0.35, 1.5)
	if pulse_index < 3 and blood_world.has_method("spawn_corpse_blood_pulse"):
		# Corpse seepage is strictly ground-level; never emit airborne spray from a corpse.
		blood_world.call(
			"spawn_corpse_blood_pulse",
			pulse_position,
			room_id,
			pulse_direction,
			pulse_intensity,
			0
		)
	else:
		blood_world.call(
			"spawn_blood_trail",
			pulse_position,
			room_id,
			pulse_direction,
			pulse_intensity
		)


func _refresh_follow_position() -> bool:
	if not follows_source:
		return true
	var source := follow_source.get_ref() as Node2D if follow_source != null else null
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		return false
	# A prone projected body may be far from its collision root. The actor
	# resolves its visible torso onto the floor without moving gameplay.
	var point := source.global_position
	if source.has_method("get_corpse_blood_ground_position"):
		point = source.call("get_corpse_blood_ground_position")
	var moved := origin_gameplay_position != point
	origin_gameplay_position = point
	global_position = origin_gameplay_position
	if (moved or not _follow_room_initialized) and blood_world.has_method("resolve_environment_debris_room_id"):
		room_id = int(blood_world.call("resolve_environment_debris_room_id", origin_gameplay_position, room_id))
		set_meta(&"dream_room_id", room_id)
	_follow_room_initialized = true
	return room_id >= 0


func set_room_runtime_active(active_room: bool) -> void:
	if not active_room:
		stop_and_free()


func stop_and_free() -> void:
	if cleanup_queued:
		return
	cleanup_queued = true
	active = false
	set_process(false)
	if is_inside_tree():
		call_deferred("queue_free")


