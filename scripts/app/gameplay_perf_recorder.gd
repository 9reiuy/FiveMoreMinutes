extends RefCounted
## Plain-data flight recorder. File formatting/writing never runs in a gameplay
## callback. Whole-session histograms remain complete even if detail logging caps.

const VERSION := 5
const PHASES := ["menu", "gameplay", "loading", "paused", "unfocused", "report"]
const BASE_STAGES := ["smoke_physics", "smoke_rebuild", "smoke_coverage", "smoke_visibility", "smoke_prepare", "smoke_fusion", "smoke_upload", "extinguisher_flight", "fracture_build", "smoke_rebuild_doors", "smoke_rebuild_links", "smoke_rebuild_bfs_mask", "smoke_rebuild_edges", "smoke_rebuild_clouds", "smoke_fusion_snapshot", "smoke_fusion_calculate", "bridge_process", "bridge_physics", "occlusion_process", "occlusion_physics", "blood_process", "enemy_process", "enemy_physics", "player_physics", "fracture_slice", "fracture_nodes", "fracture_crumbs", "fracture_outline", "blood_active_init_process", "blood_active_init_self_process", "blood_active_init_physics", "blood_active_init_self_physics", "blood_active_sim_process", "blood_active_sim_self_process", "blood_active_sim_physics", "blood_active_sim_self_physics", "blood_impact_settle_process", "blood_impact_settle_self_process", "blood_impact_settle_physics", "blood_impact_settle_self_physics", "blood_cpu_submit_process", "blood_cpu_submit_self_process", "blood_cpu_submit_physics", "blood_cpu_submit_self_physics", "death_save_io", "death_audio_ctrl", "death_crt_init", "death_actor_cleanup", "scope_overhead"]
const STAGES := BASE_STAGES+["blood_merge_prepare","blood_merge_frontier","blood_merge_fill","blood_merge_commit","blood_deposit_raster","smoke_disperse","smoke_mask_upload"]
const BASE_COLUMNS := ["process_frame", "end_usec", "frame_ms", "phase", "warmup", "script_span_ms", "physics_span_ms", "physics_steps", "draw_span_ms", "draw_process_frame", "world_render_cpu_ms", "world_render_gpu_ms", "root_render_cpu_ms", "root_render_gpu_ms", "draw_calls", "primitives", "nodes", "bodies_2d", "bodies_3d", "static_ram_bytes", "vram_bytes", "texture_vram_bytes", "pipeline_count", "floor", "floor_token", "room", "seed", "player_x", "player_y", "player_health", "enemies_alive", "corpses", "projectiles", "debris_bursts", "smoke_sources", "smoke_cells", "smoke_cards", "smoke_hidden_enemies", "flying_extinguishers", "burning", "shadow_lights", "reflection_renders", "context_age_ms", "monitor_previous_ms"]
const CHUNK_FRAMES := 120
const MAX_QUEUED_CHUNKS := 8
const MAX_DETAIL_BYTES := 128 * 1024 * 1024
const SPIKE_MS := 20.0
const SEVERE_MS := 33.333333
const EXTRA_COLUMNS := ["engine_process_ms", "engine_physics_ms", "navigation_ms", "time_scale", "blood_stains", "main_draw_calls", "main_objects", "smoke_committed_cards", "system_free_physical_bytes", "system_commit_limit_bytes", "system_physical_total_bytes", "player_alive"]

var active := false
var directory := ""
var start_usec := 0
var columns: Array = BASE_COLUMNS.duplicate()
var stats: Dictionary = {}
var event_counts: Dictionary = {}
var worst_frames: Array[Dictionary] = []
var frames_seen := 0
var dropped_rows := 0
var dropped_events := 0
var detail_limit_bytes := MAX_DETAIL_BYTES
var _rows := PackedFloat64Array()
var _events: Array[Dictionary] = []
var _event_buckets: Dictionary = {}
var _mutex := Mutex.new()
var _ready := Semaphore.new()
var _thread := Thread.new()
var _queue: Array[Dictionary] = []
var _disk_error := ""
var _written_rows := 0
var _written_events := 0
var _capped_rows := 0
var _capped_events := 0
var _alive_column:=-1


func _init() -> void:
	for stage in STAGES:
		columns.append(stage + "_ms")
		columns.append(stage + "_calls")
	columns.append_array(EXTRA_COLUMNS)
	_alive_column=columns.find("player_alive")


func begin(base_dir: String, metadata: Dictionary = {}) -> Error:
	if active:
		return ERR_ALREADY_IN_USE
	start_usec = Time.get_ticks_usec()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	directory = base_dir.path_join("%s_%d_%d" % [stamp, OS.get_process_id(), start_usec])
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		return error
	var info := metadata.duplicate(true)
	info.memory_fields={"system_free_physical_bytes":"OS free: available physical RAM","system_commit_limit_bytes":"Windows commit limit, NOT free RAM","system_physical_total_bytes":"usable physical RAM"}
	info.viewport_native_frame_id_supported=false
	info.script_phase_trace={"boundary_limit":192,"request_limit":64,"max_regular_events":200,"max_severe_events":64,"regular_cooldown_ms":50,"severe_cooldown_ms":5,"coverage":"alive gameplay script-visible callbacks and known project calls only; not full native physics or actual draw list"}
	info.stage_semantics={"blood_scopes":"inclusive and self wall time, split by process/physics; never sum parents and children","fracture_outline":"nested inside fracture_nodes, not additive","scope_overhead":"partial marker bookkeeping measurement, not complete observer cost","timeline":"script-visible boundaries only; no native physics/GPU completion claim"}
	info.alive_rule="gameplay only; include death event frame; reopen after revival/new player; retain separate death hold"
	info.stage_semantics["merge_substeps"]="blood_merge_prepare/frontier/fill/commit are nested inside blood_impact_settle; deposit_raster is nested inside initialization or simulation; CPU wall time, not additive to parents"
	info.stage_semantics["smoke_shots"]="smoke_disperse is bullet-path clearing CPU time; smoke_mask_upload is CPU submission wall time, not GPU execution; may be nested inside rebuild/upload"
	info.merge({"version": VERSION, "started_local": Time.get_datetime_string_from_system(), "start_usec": start_usec, "pid": OS.get_process_id(), "columns": columns, "phases": PHASES, "detail_limit_bytes": detail_limit_bytes, "timing_notes": ["frame_ms is wall time between late process samples, not GPU time", "script/physics spans bracket scene callbacks, not native server costs", "draw span is frame_pre_draw to frame_post_draw, not pure GPU time", "viewport metrics describe a previously completed render and may lag", "root and world render timings must not be added", "group counts are sampled at 4 Hz; context_age_ms reports staleness", "warmup is tagged, never removed from gameplay statistics", "zero pipeline counters in Compatibility do not rule out driver compilation", "events are correlations, not proven root causes", "histogram percentiles round upward to 0.1 ms"]}, true)
	active = true
	var thread_error := _thread.start(_write_loop.bind(info))
	if thread_error != OK:
		active = false
		return thread_error
	return OK


func record_event(kind: String, data: Dictionary = {}, frame: int = -1) -> void:
	if not active:
		return
	var at := Time.get_ticks_usec()
	var bucket: Dictionary = _event_buckets.get(kind, {})
	if bucket.is_empty():
		bucket = {"kind": kind, "count": 0, "first_usec": at, "last_usec": at, "first_frame": frame, "last_frame": frame, "examples": []}
	bucket.count += 1
	bucket.last_usec = at
	bucket.last_frame = frame
	# All callers pass plain scalar/array dictionaries, never Nodes or Resources.
	if bucket.examples.size() < 4:
		bucket.examples.append(data.duplicate(true))
	_event_buckets[kind] = bucket
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1


func _flush_events() -> void:
	for event in _event_buckets.values():
		_events.append(event)
	_event_buckets.clear()


func record_frame(row: PackedFloat64Array) -> void:
	if not active or row.size() != columns.size():
		return
	_flush_events()
	_rows.append_array(row)
	frames_seen += 1
	var phase: String = PHASES[clampi(int(row[3]), 0, PHASES.size() - 1)]
	_add_stat("all", row[2])
	_add_stat(phase, row[2])
	if phase == "gameplay":
		_add_stat("warmup" if row[4] > 0 else "steady", row[2])
		if _alive_column>=0 and row[_alive_column]>0:
			_add_stat("alive_gameplay",row[2])
			_add_stat("alive_warmup" if row[4]>0 else "alive_steady",row[2])
		else:
			_add_stat("dead_gameplay",row[2])
		if row[2] > SPIKE_MS:
			var entry := {"frame": int(row[0]), "end_usec": int(row[1]), "frame_ms": row[2], "room": int(row[25]), "floor": int(row[23]), "script_ms": row[5], "physics_ms": row[6], "physics_steps": int(row[7]), "draw_span_ms": row[8], "draw_frame": int(row[9]), "draw_calls": int(row[14]), "smoke_sources": int(row[34]), "smoke_cards": int(row[36])}
			if worst_frames.size() < 40 or row[2] > float(worst_frames.back().frame_ms):
				worst_frames.append(entry)
				worst_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.frame_ms > b.frame_ms)
				if worst_frames.size() > 40:
					worst_frames.resize(40)
	if _rows.size() >= columns.size() * CHUNK_FRAMES:
		_submit()


func _add_stat(key: String, ms: float) -> void:
	if not stats.has(key):
		stats[key] = {"count": 0, "sum_ms": 0.0, "max_ms": 0.0, "over_16_7": 0, "over_20": 0, "over_33_3": 0, "over_50": 0, "over_100": 0, "histogram": {}}
	var stat: Dictionary = stats[key]
	stat.count += 1
	stat.sum_ms += ms
	stat.max_ms = maxf(stat.max_ms, ms)
	if ms > 16.7: stat.over_16_7 += 1
	if ms > SPIKE_MS: stat.over_20 += 1
	if ms > SEVERE_MS: stat.over_33_3 += 1
	if ms > 50.0: stat.over_50 += 1
	if ms > 100.0: stat.over_100 += 1
	var bin := ceili(maxf(0.0, ms) * 10.0)
	stat.histogram[bin] = int(stat.histogram.get(bin, 0)) + 1


func stat_summary(key: String) -> Dictionary:
	var source: Dictionary = stats.get(key, {})
	if source.is_empty():
		return {"count": 0}
	var result := source.duplicate()
	result.erase("histogram")
	result.avg_ms = float(source.sum_ms) / int(source.count)
	result.avg_fps = 1000.0 / maxf(result.avg_ms, 0.001)
	var bins: Array = source.histogram.keys()
	bins.sort()
	for percentile in [50, 95, 99]:
		var rank := maxi(1, ceili(int(source.count) * percentile / 100.0))
		var cumulative := 0
		for bin in bins:
			cumulative += int(source.histogram[bin])
			if cumulative >= rank:
				result["p%d_ms" % percentile] = float(bin) / 10.0
				break
	return result


func snapshot() -> Dictionary:
	var phases := {}
	for key in stats:
		phases[key] = stat_summary(key)
	return {"version": VERSION, "directory": ProjectSettings.globalize_path(directory), "start_usec": start_usec, "end_usec": Time.get_ticks_usec(), "frames_seen": frames_seen, "stats": phases, "events": event_counts.duplicate(), "worst_gameplay_frames": worst_frames.duplicate(true), "writer": writer_status()}


func checkpoint(report: String, extra: Dictionary = {}) -> void:
	if not active:
		return
	var summary := snapshot()
	summary.merge(extra, true)
	_submit({"summary": summary, "report": report}, true)


func close(report: String = "", extra: Dictionary = {}) -> void:
	if not active:
		return
	checkpoint(report, extra)
	_submit({"finish": true}, true)
	active = false
	if _thread.is_started():
		_thread.wait_to_finish()


func writer_status() -> Dictionary:
	_mutex.lock()
	var result := {"error": _disk_error, "written_rows": _written_rows, "written_events": _written_events, "capped_rows": _capped_rows, "capped_events": _capped_events, "queued_chunks": _queue.size(), "dropped_rows": dropped_rows, "dropped_events": dropped_events}
	_mutex.unlock()
	return result


func _submit(extra: Dictionary = {}, force := false) -> void:
	_flush_events()
	var chunk := {"rows": _rows, "events": _events}
	chunk.merge(extra)
	_rows = PackedFloat64Array()
	_events = []
	_mutex.lock()
	if _queue.size() >= MAX_QUEUED_CHUNKS and not force:
		dropped_rows += chunk.rows.size() / columns.size()
		dropped_events += chunk.events.size()
		_mutex.unlock()
		return
	_queue.append(chunk)
	_mutex.unlock()
	_ready.post()


func _set_error(message: String) -> void:
	_mutex.lock()
	_disk_error = message
	_mutex.unlock()


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_error("Cannot write " + path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _write_loop(metadata: Dictionary) -> void:
	_write_json(directory.path_join("metadata.json"), metadata)
	var frames := FileAccess.open(directory.path_join("frames.csv"), FileAccess.WRITE)
	var events := FileAccess.open(directory.path_join("events.jsonl"), FileAccess.WRITE)
	if frames == null or events == null:
		_set_error("Cannot open frame/event logs: " + error_string(FileAccess.get_open_error()))
	if frames != null:
		frames.store_line(",".join(columns))
	var chunks_written := 0
	while true:
		_ready.wait()
		_mutex.lock()
		var chunk: Dictionary = _queue.pop_front()
		_mutex.unlock()
		var rows: PackedFloat64Array = chunk.rows
		var written := 0
		var capped := 0
		for offset in range(0, rows.size(), columns.size()):
			if frames == null or frames.get_position() >= detail_limit_bytes:
				capped += 1
				continue
			var fields := PackedStringArray()
			fields.resize(columns.size())
			for col in columns.size():
				fields[col] = String.num(rows[offset + col], 6)
			frames.store_line(",".join(fields))
			written += 1
		var events_written := 0
		for event in chunk.events:
			if events != null and events.get_position() < detail_limit_bytes:
				events.store_line(JSON.stringify(event))
				events_written += 1
		_mutex.lock()
		_written_rows += written
		_written_events += events_written
		_capped_rows += capped
		_capped_events += chunk.events.size() - events_written
		_mutex.unlock()
		chunks_written += 1
		if chunk.has("summary"):
			var summary: Dictionary = chunk.summary
			summary.writer = writer_status()
			_write_json(directory.path_join("summary.json"), summary)
			var report_file := FileAccess.open(directory.path_join("report.txt"), FileAccess.WRITE)
			if report_file != null:
				report_file.store_string(chunk.report)
				report_file.close()
			else:
				_set_error("Cannot write report.txt")
		if chunks_written % 3 == 0 or chunk.has("summary") or chunk.has("finish"):
			if frames != null: frames.flush()
			if events != null: events.flush()
		if frames != null and frames.get_error() != OK:
			_set_error("Frame log I/O: " + error_string(frames.get_error()))
		if events != null and events.get_error() != OK:
			_set_error("Event log I/O: " + error_string(events.get_error()))
		if chunk.get("finish", false):
			break
	if frames != null: frames.close()
	if events != null: events.close()
