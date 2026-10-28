class_name GamePerformanceMonitor
extends CanvasLayer

## F3 changes only the HUD. Recording is independent of HUD visibility.
## F4 checkpoints a unique session; the old text path remains a convenience copy.
enum DisplayMode { HIDDEN, MINI, DETAILED }
const THEME_PIXEL := preload("res://assets/fonts/pixel_theme.tres")
const RECORDER := preload("res://scripts/app/gameplay_perf_recorder.gd")
const REPORT_PATH := "user://perf_run_report.txt"
const RUNS_PATH := "user://performance_runs"
const SPIKE_THRESHOLD_MS := 20.0
const SEVERE_SPIKE_MS := 33.333333
const WARMUP_WINDOW_SEC := 2.5
const CONTEXT_INTERVAL_USEC := 250000
const HUD_INTERVAL_USEC := 250000

var current_mode: DisplayMode = DisplayMode.MINI
var is_report_open := false
var recorder = RECORDER.new()
var recording_enabled := false
var recording_error := ""
var session_start_usec := 0
var total_frames := 0
# Compatibility samples are bounded; reports use the whole-session histogram.
var frame_times_sample: Array[float] = []
var steady_frame_times: Array[float] = []
var spike_records: Array[Dictionary] = []
var cause_frequencies: Dictionary = {}
var peak_ram_bytes := 0
var peak_vram_bytes := 0
var peak_texture_vram_bytes := 0
var peak_draw_calls := 0
var peak_primitives := 0
var peak_node_count := 0
var peak_bodies_count := 0
var peak_pipeline_compiles := 0
var prev_frame_usec := 0
var prev_node_count := 0
var prev_pipeline_compiles := 0
var prev_bodies_count := 0
var prev_room_id := -999
var recent_spike_text := ""
var recent_spike_timer := 0.0
var loading_frames := 0
var loading_ms_total := 0.0
var last_load_end_usec := 0
var warmup_spikes := 0
var last_breakdown: Dictionary = {}
var _process_start_usec := 0
var _physics_start_usec := 0
var _physics_accum_ms := 0.0
var _physics_steps := 0
var _timed_viewports: Dictionary = {}
var _root_render_times := Vector2(-1, -1)
var _main_draw_calls := -1
var _main_objects := -1
var _draw_started_usec := 0
var _draw_span_ms := -1.0
var _draw_frame := -1
var _monitor_previous_ms := 0.0
var _context_usec := -CONTEXT_INTERVAL_USEC
var _hud_usec := -HUD_INTERVAL_USEC
var _context: Dictionary = {}
var _world_ref: WeakRef
var _player_ref: WeakRef
var _previous_phase := "menu"
var _focused := true
var _generation_frame := -1
var _stage_ms: Dictionary = {}
var _stage_calls: Dictionary = {}
var _last_dash_active := false
var _player_death_frame:=-1
var _closed := false
var _phase_trace:Array[Dictionary]=[]
var _render_requests:Array[Dictionary]=[]
var _last_trace_usec:=0
var _traces_written:=0
var _severe_traces_written:=0
var _last_severe_trace_usec:=0

class FrameProbe extends Node:
	var monitor: Node
	func _process(_delta: float) -> void:
		monitor._process_start_usec = Time.get_ticks_usec()
		monitor._note_boundary("node_process_begin",monitor._process_start_usec)
	func _physics_process(_delta: float) -> void:
		monitor._physics_start_usec = Time.get_ticks_usec()
		monitor._physics_steps += 1
		monitor._note_boundary("node_physics_begin",monitor._physics_start_usec)

var hud_root: Control
var mini_bar: PanelContainer
var mini_label: RichTextLabel
var mini_spike_badge: Label
var detailed_panel: PanelContainer
var detail_fps_label: RichTextLabel
var detail_time_label: Label
var detail_mem_label: Label
var detail_render_label: Label
var detail_physics_label: Label
var detail_spikes_label: Label
var report_dialog: PanelContainer
var report_scroll: ScrollContainer
var report_text_label: Label
var report_export_button: Button
var report_reset_button: Button
var report_close_button: Button
var report_status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 250
	process_priority = 1000000
	process_physics_priority = 1000000
	var script_run := false
	for arg in OS.get_cmdline_args():
		if arg in ["--script", "-s"]:
			script_run = true
	recording_enabled = not script_run
	if script_run: current_mode = DisplayMode.HIDDEN
	if "--perf-record" in OS.get_cmdline_user_args(): recording_enabled = true
	session_start_usec = Time.get_ticks_usec()
	prev_frame_usec = session_start_usec
	var probe := FrameProbe.new()
	probe.name = "FrameProbe"
	probe.monitor = self
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.process_priority = -1000000
	probe.process_physics_priority = -1000000
	add_child(probe)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_build_ui()
	_update_display_mode()
	if recording_enabled: start_recording()
	print("[PerformanceMonitor] F3: HUD | F4: save session | recording=", is_recording())


func start_recording(base_dir: String = RUNS_PATH) -> Error:
	if recorder.active: return ERR_ALREADY_IN_USE
	_phase_trace.clear();_render_requests.clear();_last_trace_usec=0;_traces_written=0;_severe_traces_written=0;_last_severe_trace_usec=0
	recording_enabled = true
	var metadata := {"engine": Engine.get_version_info(), "project_version": ProjectSettings.get_setting("application/config/version", ""), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"), "display": DisplayServer.get_name(), "os": OS.get_name(), "resolution": [get_viewport().size.x, get_viewport().size.y], "max_fps": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second, "monitor_sha256": get_script().source_code.sha256_text()}
	var settings := get_node_or_null("/root/SettingsManager")
	if RenderingServer.has_method("get_video_adapter_name"):
		metadata.gpu = RenderingServer.call("get_video_adapter_name")
	if is_instance_valid(settings):
		metadata.render_settings = {}
		for key in [&"pixelation_enabled", &"palette_enabled", &"palette_scheme", &"shadow_quality"]:
			metadata.render_settings[String(key)] = settings.get_setting(key)
		_connect_once(settings, &"setting_changed", _on_setting_changed)
	var error: Error = recorder.begin(base_dir, metadata)
	if error != OK:
		recording_error = error_string(error)
		recording_enabled = false
	else:
		print("[PerformanceMonitor] Session directory: ", ProjectSettings.globalize_path(recorder.directory))
		record_event("recording_started")
	return error


func is_recording() -> bool:
	return recording_enabled and recorder.active


func record_event(kind: String, details: Dictionary = {}) -> void:
	if is_recording(): recorder.record_event(kind, details, Engine.get_process_frames())


func record_stage(stage: String, milliseconds: float) -> void:
	if not is_recording(): return
	_stage_ms[stage] = float(_stage_ms.get(stage, 0.0)) + milliseconds
	_stage_calls[stage] = int(_stage_calls.get(stage, 0)) + 1

func _note_boundary(kind:String,at:int)->void:
	if not is_recording():return
	_phase_trace.append({"kind":kind,"usec":at,"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames()})
	if _phase_trace.size()>192:_phase_trace.pop_front()

func record_render_request(kind:String,node_id:int)->void:
	if not is_recording():return
	# Project calls only, not a native viewport-drawn or first-visible census.
	_render_requests.append({"kind":kind,"node_id":node_id,"usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames()})
	if _render_requests.size()>64:_render_requests.pop_front()

func _record_phase_trace(at:int,frame_ms:float)->void:
	if not is_recording() or frame_ms<=20.0:return
	var severe:=frame_ms>=50.0 or _draw_span_ms>=30.0
	if severe:
		if _severe_traces_written>=64 or at-_last_severe_trace_usec<5000:return
		_severe_traces_written+=1;_last_severe_trace_usec=at
	else:
		if _traces_written-_severe_traces_written>=200 or at-_last_trace_usec<50000:return
	_last_trace_usec=at;_traces_written+=1
	record_event("script_phase_trace",{"sample_frame":Engine.get_process_frames(),"sample_usec":at,"frame_ms":frame_ms,"boundaries":_phase_trace.duplicate(true),"project_calls_only":_render_requests.duplicate(true),"resource_count":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"native_physics_coverage":false,"native_draw_list_available":false})


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.keycode == KEY_F3:
		cycle_display_mode()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F4:
		toggle_report_dialog()
		get_viewport().set_input_as_handled()
	elif is_report_open and event.keycode == KEY_ESCAPE:
		close_report_dialog()
		get_viewport().set_input_as_handled()


func cycle_display_mode() -> void:
	match current_mode:
		DisplayMode.HIDDEN: current_mode = DisplayMode.MINI
		DisplayMode.MINI: current_mode = DisplayMode.DETAILED
		DisplayMode.DETAILED: current_mode = DisplayMode.HIDDEN
	_update_display_mode()


func toggle_report_dialog() -> void:
	if is_report_open: close_report_dialog()
	else: open_report_dialog()


func open_report_dialog() -> void:
	is_report_open = true
	record_event("report_opened")
	report_text_label.text = generate_report_text()
	report_dialog.visible = true
	var saved := export_report_to_file()
	report_status_label.text = "本局记录：" + ProjectSettings.globalize_path(recorder.directory) if recorder.active else saved


func close_report_dialog() -> void:
	is_report_open = false
	report_dialog.visible = false
	record_event("report_closed")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		record_event("focus_lost")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		record_event("focus_gained")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave_report()


func _exit_tree() -> void:
	_autosave_report()


func _autosave_report() -> void:
	if _closed: return
	_closed = true
	if recorder.active:
		record_event("normal_exit")
		recorder.close(generate_report_text(), _report_extras())


func reset_session_data() -> void:
	var was_recording: bool = recorder.active
	var base_dir: String = recorder.directory.get_base_dir() if was_recording else RUNS_PATH
	if was_recording: recorder.close(generate_report_text(), _report_extras())
	recorder = RECORDER.new()
	session_start_usec = Time.get_ticks_usec()
	prev_frame_usec = session_start_usec
	total_frames = 0
	frame_times_sample.clear()
	steady_frame_times.clear()
	spike_records.clear()
	cause_frequencies.clear()
	loading_frames = 0
	loading_ms_total = 0.0
	last_load_end_usec = 0
	warmup_spikes = 0
	prev_room_id = -999
	prev_node_count = 0
	prev_pipeline_compiles = 0
	prev_bodies_count = 0
	peak_ram_bytes = 0
	peak_vram_bytes = 0
	peak_texture_vram_bytes = 0
	peak_draw_calls = 0
	peak_primitives = 0
	peak_node_count = 0
	peak_bodies_count = 0
	peak_pipeline_compiles = 0
	recent_spike_text = ""
	recent_spike_timer = 0.0
	_stage_ms.clear()
	_stage_calls.clear()
	_physics_accum_ms = 0.0
	_physics_steps = 0
	_context_usec = -CONTEXT_INTERVAL_USEC
	_previous_phase = "menu"
	_player_death_frame=-1
	_closed = false
	if was_recording: start_recording(base_dir)
	if is_report_open: report_text_label.text = generate_report_text()


func _physics_process(_delta: float) -> void:
	_note_boundary("node_physics_end",Time.get_ticks_usec())
	if _physics_start_usec > 0:
		_physics_accum_ms += (Time.get_ticks_usec() - _physics_start_usec) / 1000.0


func _on_pre_draw() -> void:
	_draw_started_usec = Time.get_ticks_usec()
	_draw_frame = Engine.get_process_frames()
	_note_boundary("viewport_updates_begin",_draw_started_usec)


func _on_post_draw() -> void:
	_note_boundary("viewport_updates_end",Time.get_ticks_usec())
	if _draw_started_usec > 0:
		_draw_span_ms = (Time.get_ticks_usec() - _draw_started_usec) / 1000.0
	_draw_started_usec = 0


func _viewport_times(viewport: Viewport) -> Vector2:
	if DisplayServer.get_name() == "headless": return Vector2(-1, -1)
	var rid := viewport.get_viewport_rid()
	if not _timed_viewports.has(rid):
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_timed_viewports[rid] = true
	return Vector2(RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid))


func _render_times() -> Vector2:
	_root_render_times = _viewport_times(get_tree().root)
	_main_draw_calls = -1
	_main_objects = -1
	var display := get_tree().get_first_node_in_group(&"dream_display")
	if is_instance_valid(display):
		var viewport: Variant = display.get("world_viewport")
		if is_instance_valid(viewport) and viewport is Viewport:
			var rid: RID = viewport.get_viewport_rid()
			_main_draw_calls = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			_main_objects = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
			return _viewport_times(viewport)
	return Vector2(-1, -1)


func _phase_for(world: Node, main: Node = null) -> String:
	# Duration alone is NEVER evidence of loading: >1-second gameplay hitches stay.
	if not _focused: return "unfocused"
	if is_report_open: return "report"
	if is_instance_valid(main) and main.get("transition_running") == true: return "loading"
	if is_instance_valid(world) and (world.get("floor_transition_in_progress") == true or world.get("loading_render_preparation_pending") == true or world.get("elevator_transition_in_progress") == true): return "loading"
	if _generation_frame == Engine.get_process_frames(): return "loading"
	if get_tree().paused: return "paused"
	return "gameplay" if is_instance_valid(world) else "menu"


func _is_loading_frame(_frame_ms: float, world: Node) -> bool:
	return _phase_for(world, get_tree().current_scene) == "loading"


func _connect_once(target: Node, signal_name: StringName, callback: Callable) -> void:
	if is_instance_valid(target) and target.has_signal(signal_name) and not target.is_connected(signal_name, callback):
		target.connect(signal_name, callback)


func _bind_world(world: Node) -> void:
	var previous: Node = _world_ref.get_ref() if _world_ref != null else null
	if previous != world:
		_world_ref = weakref(world) if is_instance_valid(world) else null
		_context_usec = -CONTEXT_INTERVAL_USEC
		record_event("world_changed", {"present": is_instance_valid(world)})
		if is_instance_valid(world):
			_connect_once(world, &"generation_progress", _on_generation_progress)
			_connect_once(world, &"elevator_floor_transition_completed", _event_value.bind("floor_entered"))
			_connect_once(world, &"weapon_equipped", _event_value.bind("weapon_equipped"))
			_connect_once(world, &"dream_finished", _event_value.bind("run_finished"))
	var player_value: Variant = world.get("player") if is_instance_valid(world) else null
	var player: Node = player_value if is_instance_valid(player_value) else null
	var old_player: Node = _player_ref.get_ref() if _player_ref != null else null
	if is_instance_valid(player) and player != old_player:
		_player_ref = weakref(player)
		_player_death_frame=-1
		_connect_once(player, &"effective_damage_taken", _event_value.bind("player_hit"))
		_connect_once(player, &"died", _on_player_died)
		_connect_once(player, &"revived", _on_player_revived)
		_connect_once(player, &"active_weapon_changed", _event_value.bind("player_weapon_changed"))
		_connect_once(player, &"dash_state_changed", _on_dash_state)


func _event_value(value: Variant, kind: String) -> void:
	if value is Dictionary:
		var fields := {}
		for key in value:
			if value[key] is String or value[key] is StringName or value[key] is int or value[key] is float or value[key] is bool:
				fields[String(key)] = value[key]
			if fields.size() >= 12: break
		record_event(kind, {"result": fields})
	else:
		record_event(kind, {"value": value})


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key in [&"pixelation_enabled", &"palette_enabled", &"palette_scheme", &"shadow_quality"]:
		record_event("render_setting_changed", {"key": String(key), "value": value})


func _event_empty(kind: String) -> void:
	record_event(kind)

func _on_player_died()->void:
	_player_death_frame=Engine.get_process_frames()
	record_event("player_died")

func _on_player_revived()->void:
	_player_death_frame=-1
	record_event("player_revived")

func _player_is_alive(player:Variant)->bool:
	return is_instance_valid(player) and (player.get("dead")!=true or _player_death_frame==Engine.get_process_frames())


func _on_generation_progress(ratio: float, message: String) -> void:
	_generation_frame = Engine.get_process_frames()
	record_event("generation_progress", {"ratio": ratio, "stage": message})


func _on_dash_state(_remaining: float, _total: float, active: bool, _charges: int, _maximum: int) -> void:
	if active != _last_dash_active:
		record_event("dash_started" if active else "dash_ended")
	_last_dash_active = active


func _sample_context(world: Node, now: int) -> void:
	if now - _context_usec < CONTEXT_INTERVAL_USEC: return
	_context_usec = now
	_context = {"enemies_alive": 0, "corpses": 0, "projectiles": 0, "debris_bursts": 0, "flying_extinguishers": 0, "shadow_lights": 0, "blood_stains": 0}
	if OS.has_method("get_memory_info"):
		var memory: Dictionary = OS.call("get_memory_info")
		_context.system_free_physical_bytes=memory.get("free",-1)
		_context.system_commit_limit_bytes=memory.get("available",-1)
		_context.system_physical_total_bytes=memory.get("physical",-1)
	if not is_instance_valid(world): return
	for enemy in get_tree().get_nodes_in_group(&"dream_enemies"):
		if not world.is_ancestor_of(enemy): continue
		if enemy.get("dead") == true: _context.corpses += 1
		elif enemy.can_process(): _context.enemies_alive += 1
	for projectile in get_tree().get_nodes_in_group(&"active_basic_projectiles"):
		if world.is_ancestor_of(projectile): _context.projectiles += 1
	for group in [&"persistent_destruction_debris", &"perf_furniture_debris"]:
		for debris in get_tree().get_nodes_in_group(group):
			if world.is_ancestor_of(debris): _context.debris_bursts += 1
	for tank in get_tree().get_nodes_in_group(&"fire_extinguishers"):
		if world.is_ancestor_of(tank) and tank.get("flying") == true: _context.flying_extinguishers += 1
	for stain in get_tree().get_nodes_in_group(&"black_blood_stains"):
		if world.is_ancestor_of(stain): _context.blood_stains += 1
	var shadows: Variant = world.get("shadow_manager")
	if is_instance_valid(shadows):
		var lights: Variant = shadows.get("active")
		if lights is Dictionary:
			for light in lights:
				if is_instance_valid(light) and light.shadow_enabled and light.is_visible_in_tree(): _context.shadow_lights += 1


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_note_boundary("node_process_sample",started)
	var frame_ms := maxf(0.001, (started - prev_frame_usec) / 1000.0)
	prev_frame_usec = started
	var script_ms := (started - _process_start_usec) / 1000.0 if _process_start_usec > 0 else 0.0
	var physics_ms := _physics_accum_ms
	var steps := _physics_steps
	_physics_accum_ms = 0.0
	_physics_steps = 0
	var times := _render_times()
	var world := get_tree().get_first_node_in_group(&"dream_world")
	_bind_world(world)
	var state := _phase_for(world, get_tree().current_scene)
	# Cover the interval straddling the end of loading/pause/focus loss as such.
	var phase := _previous_phase if _previous_phase in ["loading", "paused", "unfocused", "report"] else state
	if state != _previous_phase: record_event("phase_changed", {"from": _previous_phase, "to": state})
	_previous_phase = state
	if phase == "loading":
		loading_frames += 1
		loading_ms_total += frame_ms
		last_load_end_usec = started
	var warmup := phase == "gameplay" and last_load_end_usec > 0 and started - last_load_end_usec < int(WARMUP_WINDOW_SEC * 1000000)
	last_breakdown = {"frame": frame_ms, "script": script_ms, "physics": physics_ms, "render_cpu": times.x, "gpu": times.y, "draw_span": _draw_span_ms, "draw_frame": _draw_frame, "physics_steps": steps, "phase": phase}
	total_frames += 1
	if frame_times_sample.size() < 6000: frame_times_sample.append(frame_ms)
	else: frame_times_sample[total_frames % 6000] = frame_ms
	if phase == "gameplay" and not warmup:
		if steady_frame_times.size() < 6000: steady_frame_times.append(frame_ms)
		else: steady_frame_times[total_frames % 6000] = frame_ms
	var ram := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var vram := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var texture := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var bodies_2d := int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	var bodies_3d := int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	var compiles := 0
	for counter in [Performance.PIPELINE_COMPILATIONS_SPECIALIZATION, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_DRAW]:
		compiles += int(Performance.get_monitor(counter))
	peak_ram_bytes = maxi(peak_ram_bytes, ram)
	peak_vram_bytes = maxi(peak_vram_bytes, vram)
	peak_texture_vram_bytes = maxi(peak_texture_vram_bytes, texture)
	peak_draw_calls = maxi(peak_draw_calls, draws)
	peak_primitives = maxi(peak_primitives, primitives)
	peak_node_count = maxi(peak_node_count, nodes)
	peak_bodies_count = maxi(peak_bodies_count, bodies_2d + bodies_3d)
	peak_pipeline_compiles = maxi(peak_pipeline_compiles, compiles)
	var room := int(world.get("current_room_id")) if is_instance_valid(world) and world.get("current_room_id") != null else -1
	if room != prev_room_id:
		record_event("room_changed", {"from": prev_room_id, "to": room})
	prev_room_id = room
	_sample_context(world, started)
	var row := PackedFloat64Array()
	row.resize(recorder.columns.size())
	row.fill(-1.0)
	var base := [Engine.get_process_frames(), started, frame_ms, RECORDER.PHASES.find(phase), int(warmup), script_ms, physics_ms, steps, _draw_span_ms, _draw_frame, times.x, times.y, _root_render_times.x, _root_render_times.y, draws, primitives, nodes, bodies_2d, bodies_3d, ram, vram, texture, compiles]
	for i in base.size(): row[i] = base[i]
	if is_instance_valid(world):
		row[23] = float(world.get("floor_index")) if world.get("floor_index") != null else -1
		row[24] = float(world.call("get_current_floor_token")) if world.has_method("get_current_floor_token") else -1
		row[25] = room
		row[26] = float(world.get("active_seed")) if world.get("active_seed") != null else -1
		var player: Variant = world.get("player")
		if is_instance_valid(player) and player is Node2D:
			row[27] = player.global_position.x
			row[28] = player.global_position.y
			var health: Variant = player.get("health")
			if health == null: health = player.get("current_health")
			row[29] = float(health) if health != null else -1
		var floor_root: Variant = world.get("floor_root")
		if is_instance_valid(floor_root):
			var smoke: Node = floor_root.get_node_or_null("FireExtinguisherSystem")
			if is_instance_valid(smoke):
				row[34] = smoke.get("sources").size()
				row[35] = smoke.get("cells").size()
				row[36] = smoke.get("clouds").size() + smoke.get("fringe_clouds").size() + smoke.get("puffs").size()
				row[37] = smoke.get("hidden_enemies").size()
			else:
				for i in range(34, 38): row[i] = 0
			var burn: Node = floor_root.get_node_or_null("BurningEffects")
			row[39] = burn.get("burning").size() if is_instance_valid(burn) else 0
		var reflection := world.get_node_or_null("FloorReflections")
		row[41] = float(reflection.get("renders")) if is_instance_valid(reflection) else 0
	for pair in [[30, "enemies_alive"], [31, "corpses"], [32, "projectiles"], [33, "debris_bursts"], [38, "flying_extinguishers"], [40, "shadow_lights"]]:
		row[pair[0]] = _context.get(pair[1], 0)
	row[42] = (started - _context_usec) / 1000.0
	row[43] = _monitor_previous_ms
	for i in RECORDER.STAGES.size():
		var stage: String = RECORDER.STAGES[i]
		row[44 + i * 2] = _stage_ms.get(stage, 0.0)
		row[45 + i * 2] = _stage_calls.get(stage, 0)
	var extra := 44 + RECORDER.STAGES.size() * 2
	row[extra] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	row[extra + 1] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	row[extra + 2] = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	row[extra + 3] = Engine.time_scale
	row[extra + 4] = _context.get("blood_stains", 0)
	row[extra + 5] = _main_draw_calls
	row[extra + 6] = _main_objects
	var smoke_for_count: Node = world.get("floor_root").get_node_or_null("FireExtinguisherSystem") if is_instance_valid(world) and is_instance_valid(world.get("floor_root")) else null
	var smoke_banks: Array = smoke_for_count.get("banks") if is_instance_valid(smoke_for_count) else []
	row[extra + 7] = smoke_banks[0].visible_instance_count if not smoke_banks.is_empty() else 0
	row[extra + 8] = _context.get("system_free_physical_bytes", -1)
	row[extra + 9] = _context.get("system_commit_limit_bytes", -1)
	row[extra + 10] = _context.get("system_physical_total_bytes", -1)
	var life_player:Variant=world.get("player") if is_instance_valid(world) else null
	row[extra + 11] = int(_player_is_alive(life_player))
	_stage_ms.clear()
	_stage_calls.clear()
	if is_recording(): recorder.record_frame(row)
	if phase=="gameplay" and _player_is_alive(life_player):_record_phase_trace(started,frame_ms)
	if phase == "gameplay" and frame_ms > SPIKE_THRESHOLD_MS:
		var clue := "待分析"
		if script_ms >= 10.0 or physics_ms >= 10.0: clue = "脚本/物理区间偏长"
		if _draw_span_ms >= 12.0: clue += "；绘制区间偏长"
		var record := {"time": "%.3fs" % ((started - session_start_usec) / 1000000.0), "frame_ms": frame_ms, "fps": 1000.0 / frame_ms, "category": clue, "cause": clue, "room": room, "nodes": nodes, "draw_calls": draws}
		spike_records.append(record)
		if spike_records.size() > 300: spike_records.pop_front()
		if warmup: warmup_spikes += 1
		recent_spike_text = "峰值 %.1fms｜房间 %d｜%s" % [frame_ms, room, clue]
		recent_spike_timer = 3.0
	recent_spike_timer = maxf(0, recent_spike_timer - delta)
	if recent_spike_timer <= 0: recent_spike_text = ""
	if started - _hud_usec >= HUD_INTERVAL_USEC:
		_hud_usec = started
		var fps := float(Performance.get_monitor(Performance.TIME_FPS))
		if current_mode == DisplayMode.MINI: _update_mini_ui(fps, frame_ms, ram, texture, draws)
		elif current_mode == DisplayMode.DETAILED: _update_detailed_ui(fps, frame_ms, script_ms, physics_ms, 0, ram, peak_ram_bytes, vram, texture, nodes, 0, 0, draws, primitives, bodies_2d + bodies_3d, compiles)
	_monitor_previous_ms = (Time.get_ticks_usec() - started) / 1000.0
	if is_recording(): recorder._add_stat("monitor_cost", _monitor_previous_ms)


func _update_mini_ui(fps: float, frame_ms: float, ram: int, texture: int, draws: int) -> void:
	var color := "#59d982" if fps >= 55 else "#e6a83a"
	var stat: Dictionary = recorder.stats.get("gameplay", {}) if is_recording() else {}
	mini_label.text = "[F3] %.0f FPS | %.1fms | DC %d | 峰值 %d次 | %s" % [fps, frame_ms, draws, int(stat.get("over_20", 0)), "记录中" if is_recording() else "未记录"]
	mini_spike_badge.visible = not recent_spike_text.is_empty()
	mini_spike_badge.text = recent_spike_text
	mini_label.add_theme_color_override("default_color", Color(color))


func _update_detailed_ui(fps: float, frame_ms: float, script_ms: float, physics_ms: float, _nav: float, ram: int, ram_max: int, vram: int, texture: int, nodes: int, _objects: int, _orphans: int, draws: int, primitives: int, bodies: int, compiles: int) -> void:
	detail_fps_label.text = "%.1f FPS | %.2f ms | %s" % [fps, frame_ms, str(last_breakdown.get("phase", ""))]
	detail_time_label.text = "脚本区间 %.2fms | 物理回调 %.2fms (%d步)\n绘制区间 %.2fms | 上次世界CPU/GPU %.2f / %.2fms" % [script_ms, physics_ms, int(last_breakdown.get("physics_steps", 0)), float(last_breakdown.get("draw_span", -1)), float(last_breakdown.get("render_cpu", -1)), float(last_breakdown.get("gpu", -1))]
	detail_mem_label.text = "引擎静态内存 %.0fM / 峰值 %.0fM\n显存 %.0fM | 纹理 %.0fM" % [ram / 1048576.0, ram_max / 1048576.0, vram / 1048576.0, texture / 1048576.0]
	detail_render_label.text = "DC %d | 图元 %d | 编译计数 %d\n计数为0不能排除驱动首用停顿" % [draws, primitives, compiles]
	detail_physics_label.text = "节点 %d | 活动物理对象 %d\n烟雾阶段与游戏事件详见整局日志" % [nodes, bodies]
	var stat: Dictionary = recorder.stats.get("gameplay", {}) if is_recording() else {}
	var status: Dictionary = recorder.writer_status()
	detail_spikes_label.text = "游玩 >20ms：%d帧 | >33.3ms：%d帧\n%s\n记录器上一帧 %.3fms | F4 保存\n%s" % [int(stat.get("over_20", 0)), int(stat.get("over_33_3", 0)), recent_spike_text, _monitor_previous_ms, str(status.error)]


func _frame_stats(samples: Array[float]) -> Dictionary:
	var result := {"count": samples.size(), "avg_fps": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "over_budget_pct": 0.0}
	if samples.is_empty(): return result
	var sorted := samples.duplicate()
	sorted.sort()
	var sum := 0.0
	var over := 0
	for value in sorted:
		sum += value
		if value > 16.7: over += 1
	result.avg_fps = 1000.0 / maxf(sum / sorted.size(), 0.001)
	result.p95 = sorted[clampi(ceili(sorted.size() * 0.95) - 1, 0, sorted.size() - 1)]
	result.p99 = sorted[clampi(ceili(sorted.size() * 0.99) - 1, 0, sorted.size() - 1)]
	result.max = sorted.back()
	result.over_budget_pct = over * 100.0 / sorted.size()
	return result


func _report_extras() -> Dictionary:
	return {"script_trace_status":{"written":_traces_written,"severe_written":_severe_traces_written,"regular_budget_reached":_traces_written-_severe_traces_written>=200,"severe_budget_reached":_severe_traces_written>=64},"resource_peaks": {"static_ram_bytes": peak_ram_bytes, "vram_bytes": peak_vram_bytes, "texture_vram_bytes": peak_texture_vram_bytes, "draw_calls": peak_draw_calls, "primitives": peak_primitives, "nodes": peak_node_count, "active_bodies": peak_bodies_count}}


func generate_report_text() -> String:
	var report := "五分钟后｜整局性能与事件记录\n\n一、整局运行概况\n"
	report += "记录目录：" + ProjectSettings.globalize_path(recorder.directory) + "\n"
	report += "隐藏 F3 不停止记录；F4/正常退出保存。时间单位 ms。百分位向上取整到 0.1ms。\n"
	for pair in [["alive_gameplay", "存活游玩（含死亡当帧，支持复活/重开）"], ["alive_steady", "存活稳态游玩"], ["gameplay", "全部游玩标签（含死亡后停留）"], ["dead_gameplay", "死亡后停留"], ["steady", "预热后游玩"], ["warmup", "加载后2.5秒游玩"], ["loading", "加载"], ["paused", "暂停"], ["unfocused", "失焦/切出"], ["report", "查看/保存报告"], ["menu", "菜单/非关卡"]]:
		var stat: Dictionary = recorder.stat_summary(pair[0])
		if int(stat.get("count", 0)) == 0: continue
		report += "%s：%d帧 | 平均 %.2fms | P50 %.1f | P95 %.1f | P99 %.1f | 最高 %.2f | >16.7ms %.2f%% | >20ms %d帧 | >33.3ms %d帧\n" % [pair[1], stat.count, stat.avg_ms, stat.p50_ms, stat.p95_ms, stat.p99_ms, stat.max_ms, stat.over_16_7 * 100.0 / stat.count, stat.over_20, stat.over_33_3]
	report += "\n二、什么资源占用最大（仅实测峰值，不据此认定瓶颈）\n"
	report += "引擎静态内存 %.1fMB | 显存 %.1fMB | 纹理 %.1fMB | DC %d | 节点 %d | 活动物理 %d\n" % [peak_ram_bytes / 1048576.0, peak_vram_bytes / 1048576.0, peak_texture_vram_bytes / 1048576.0, peak_draw_calls, peak_node_count, peak_bodies_count]
	report += "\n三、为什么导致卡顿延迟（待结合时间线分析，不自动断言根因）\n"
	report += "events.jsonl：开火、受伤、击杀、破坏、消防器、换房、切层等事件；高频事件按采样间隔聚合并保留起止时刻。\n"
	report += "frames.csv：每个采样间隔的帧耗时、补步数、脚本/绘制区间、烟雾各阶段耗时、负载数量及玩家位置。\n"
	report += "draw_span 属上一轮绘制，使用 draw_process_frame 关联；视口 CPU/GPU 也可能滞后一帧或更多。二者不是同一口径，不相加。\n"
	report += "高 DC、节点增加、编译计数为0，均不能单独证明或排除原因。超过1秒不会自动排除为加载。\n"
	report += "smoke_physics 包含其内部阶段，smoke_coverage 包含本次视线更新；这些区间不可重复相加。\n"
	report += "v2内存：system_free_physical_bytes为实时可用物理内存；commit_limit另列，不能当作空闲RAM。\n"
	report += "分组数量每0.25秒更新，烟雾卡片数为候选数量，不等于实际提交实例；事件与峰值同时发生不代表因果。\n"
	report += "事件总数：" + JSON.stringify(recorder.event_counts) + "\n"
	report += "\n四、整局最严重游玩峰值（不是仅最近100秒）\n"
	for frame in recorder.worst_frames:
		report += "第%d帧 / %.3fs：%.2fms | 楼层%d 房间%d | 脚本 %.2f 物理 %.2f (%d步) | 上次绘制 %.2f (帧%d) | DC%d | 烟源%d 卡片候选%d\n" % [frame.frame, (int(frame.end_usec) - recorder.start_usec) / 1000000.0, frame.frame_ms, frame.floor, frame.room, frame.script_ms, frame.physics_ms, frame.physics_steps, frame.draw_span_ms, frame.draw_frame, frame.draw_calls, frame.smoke_sources, frame.smoke_cards]
	var cost: Dictionary = recorder.stat_summary("monitor_cost")
	if int(cost.get("count", 0)) > 0:
		report += "\n记录器自身：平均 %.3fms / P99 %.1fms / 最大 %.3fms（不含后台写盘线程的CPU占用）。\n" % [cost.avg_ms, cost.p99_ms, cost.max_ms]
	report += "写盘状态：" + JSON.stringify(recorder.writer_status()) + "\n"
	report += "明细达到容量上限/磁盘异常会明确报告；整局计数与峰值仍保留。强制结束进程可能丢失最后一批数据。\n"
	if not recording_error.is_empty(): report += "启动记录失败：" + recording_error + "\n"
	return report


func export_report_to_file() -> String:
	var content := generate_report_text()
	if recorder.active: recorder.checkpoint(content, _report_extras())
	# This legacy copy is written only on explicit F4/export, not during gameplay.
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(content)
	file.close()
	return ProjectSettings.globalize_path(REPORT_PATH)


func _update_display_mode() -> void:
	hud_root.visible = current_mode != DisplayMode.HIDDEN
	mini_bar.visible = current_mode == DisplayMode.MINI
	detailed_panel.visible = current_mode == DisplayMode.DETAILED


# --- 动态构建 UI 控件 ---
func _build_ui() -> void:
	hud_root = Control.new()
	hud_root.name = "PerfHUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	
	# 1. 迷你胶囊条 (Mini Bar - 右上角)
	mini_bar = PanelContainer.new()
	mini_bar.name = "MiniBar"
	mini_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_bar.anchor_left = 1.0
	mini_bar.anchor_right = 1.0
	mini_bar.offset_left = -460.0
	mini_bar.offset_top = 8.0
	mini_bar.offset_right = -8.0
	mini_bar.offset_bottom = 38.0
	
	var mini_style := StyleBoxFlat.new()
	mini_style.bg_color = Color(0.02, 0.03, 0.05, 0.82)
	mini_style.border_color = Color(0.25, 0.45, 0.65, 0.7)
	mini_style.set_border_width_all(1)
	mini_style.set_corner_radius_all(3)
	mini_style.content_margin_left = 8
	mini_style.content_margin_right = 8
	mini_style.content_margin_top = 4
	mini_style.content_margin_bottom = 4
	mini_bar.add_theme_stylebox_override("panel", mini_style)
	
	var mini_vbox := VBoxContainer.new()
	mini_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_bar.add_child(mini_vbox)
	
	mini_label = RichTextLabel.new()
	mini_label.name = "MiniLabel"
	mini_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_label.bbcode_enabled = true
	mini_label.fit_content = true
	mini_label.scroll_active = false
	mini_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	mini_label.add_theme_font_size_override("normal_font_size", 12)
	mini_label.add_theme_color_override("default_color", Color(0.88, 0.92, 0.96, 1.0))
	mini_vbox.add_child(mini_label)
	
	mini_spike_badge = Label.new()
	mini_spike_badge.name = "MiniSpikeBadge"
	mini_spike_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_spike_badge.visible = false
	mini_spike_badge.add_theme_font_size_override("font_size", 11)
	mini_spike_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	mini_vbox.add_child(mini_spike_badge)
	
	hud_root.add_child(mini_bar)
	
	# 2. 详细监控面板 (Detailed Panel - 右上角)
	detailed_panel = PanelContainer.new()
	detailed_panel.name = "DetailedPanel"
	detailed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detailed_panel.anchor_left = 1.0
	detailed_panel.anchor_right = 1.0
	detailed_panel.offset_left = -380.0
	detailed_panel.offset_top = 8.0
	detailed_panel.offset_right = -8.0
	detailed_panel.offset_bottom = 360.0
	
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.015, 0.02, 0.035, 0.92)
	detail_style.border_color = Color(0.3, 0.55, 0.8, 0.85)
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(4)
	detail_style.content_margin_left = 12
	detail_style.content_margin_right = 12
	detail_style.content_margin_top = 10
	detail_style.content_margin_bottom = 10
	detailed_panel.add_theme_stylebox_override("panel", detail_style)
	
	var d_vbox := VBoxContainer.new()
	d_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_vbox.add_theme_constant_override("separation", 6)
	detailed_panel.add_child(d_vbox)
	
	var d_title := Label.new()
	d_title.text = "📊 游戏实时资源与性能监控 [F3切模式|F4报告]"
	d_title.add_theme_font_size_override("font_size", 13)
	d_title.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0, 1.0))
	d_vbox.add_child(d_title)
	
	detail_fps_label = RichTextLabel.new()
	detail_fps_label.name = "DetailFPSLabel"
	detail_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_fps_label.bbcode_enabled = true
	detail_fps_label.fit_content = true
	detail_fps_label.scroll_active = false
	detail_fps_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_fps_label.add_theme_font_size_override("normal_font_size", 12)
	detail_fps_label.add_theme_color_override("default_color", Color(0.88, 0.92, 0.96, 1.0))
	d_vbox.add_child(detail_fps_label)
	detail_time_label = _create_stat_label(d_vbox)
	detail_mem_label = _create_stat_label(d_vbox)
	detail_render_label = _create_stat_label(d_vbox)
	detail_physics_label = _create_stat_label(d_vbox)
	detail_spikes_label = _create_stat_label(d_vbox)
	detail_spikes_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35, 1.0))
	
	hud_root.add_child(detailed_panel)
	
	# 3. 诊断报告弹窗 (Report Modal - 居中)
	report_dialog = PanelContainer.new()
	report_dialog.name = "ReportDialog"
	report_dialog.visible = false
	report_dialog.anchor_left = 0.5
	report_dialog.anchor_top = 0.5
	report_dialog.anchor_right = 0.5
	report_dialog.anchor_bottom = 0.5
	report_dialog.offset_left = -340.0
	report_dialog.offset_top = -230.0
	report_dialog.offset_right = 340.0
	report_dialog.offset_bottom = 230.0
	
	var rep_style := StyleBoxFlat.new()
	rep_style.bg_color = Color(0.02, 0.03, 0.05, 0.96)
	rep_style.border_color = Color(0.35, 0.65, 0.95, 0.9)
	rep_style.set_border_width_all(2)
	rep_style.set_corner_radius_all(6)
	rep_style.content_margin_left = 16
	rep_style.content_margin_right = 16
	rep_style.content_margin_top = 14
	rep_style.content_margin_bottom = 14
	report_dialog.add_theme_stylebox_override("panel", rep_style)
	
	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 8)
	report_dialog.add_child(r_vbox)
	
	var rep_title := Label.new()
	rep_title.text = "🎮 本局游戏性能与卡顿深度诊断报告"
	rep_title.add_theme_font_size_override("font_size", 16)
	rep_title.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0, 1.0))
	r_vbox.add_child(rep_title)
	
	report_scroll = ScrollContainer.new()
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_vbox.add_child(report_scroll)
	
	report_text_label = Label.new()
	report_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_text_label.add_theme_font_size_override("font_size", 12)
	report_text_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	report_scroll.add_child(report_text_label)
	
	report_status_label = Label.new()
	report_status_label.add_theme_font_size_override("font_size", 11)
	report_status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6, 1.0))
	r_vbox.add_child(report_status_label)
	
	var r_buttons := HBoxContainer.new()
	r_buttons.add_theme_constant_override("separation", 12)
	r_buttons.alignment = BoxContainer.ALIGNMENT_END
	r_vbox.add_child(r_buttons)
	
	report_export_button = Button.new()
	report_export_button.text = " 导出报告文本 (user://perf_run_report.txt) "
	report_export_button.pressed.connect(func():
		var out_p := export_report_to_file()
		report_status_label.text = "已导出至: " + out_p
	)
	r_buttons.add_child(report_export_button)
	
	report_reset_button = Button.new()
	report_reset_button.text = " 保存本局并开始新记录 "
	report_reset_button.pressed.connect(func():
		reset_session_data()
		report_status_label.text = "上一局已保留，开始新记录"
	)
	r_buttons.add_child(report_reset_button)
	
	report_close_button = Button.new()
	report_close_button.text = " 关闭 (Esc / F4) "
	report_close_button.pressed.connect(close_report_dialog)
	r_buttons.add_child(report_close_button)
	
	hud_root.add_child(report_dialog)


func _create_stat_label(parent: Control) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 1.0))
	parent.add_child(l)
	return l
