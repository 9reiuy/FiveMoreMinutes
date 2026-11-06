extends Node
## Diagnostic only; no capped recorder and no per-frame disk I/O.
var active := true
var stages: Dictionary = {}
var calls: Dictionary = {}
var rows: Array[Dictionary] = []

func is_recording() -> bool: return active
func record_event(_kind: String, _data: Dictionary = {}) -> void: pass
func record_render_request(_kind: String, _id: int) -> void: pass
func record_stage(stage: String, milliseconds: float) -> void:
	stages[stage] = float(stages.get(stage, 0.0)) + milliseconds
	calls[stage] = int(calls.get(stage, 0)) + 1
func sample() -> void:
	rows.append({"frame": Engine.get_process_frames(), "stages": stages.duplicate(), "calls": calls.duplicate()})
	stages.clear()
	calls.clear()
func finish(path: String) -> void:
	active = false
	var keys: Array = []
	for row in rows:
		for stage in row.stages:
			if not keys.has(stage): keys.append(stage)
	keys.sort()
	var file := FileAccess.open(path.path_join("native_stages.csv"), FileAccess.WRITE)
	var header := PackedStringArray(["engine_frame"])
	for stage in keys: header.append(stage + "_ms"); header.append(stage + "_calls")
	file.store_csv_line(header)
	for row in rows:
		var fields := PackedStringArray([str(row.frame)])
		for stage in keys: fields.append(str(row.stages.get(stage, 0))); fields.append(str(row.calls.get(stage, 0)))
		file.store_csv_line(fields)
	file.close()
