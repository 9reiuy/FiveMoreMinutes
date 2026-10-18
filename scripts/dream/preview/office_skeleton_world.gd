extends "res://scripts/dream/office_skeleton_world_base.gd"
## The independent preview keeps its reviewed JSON bank. Formal gameplay uses native generation.
func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--skeleton-layout="): layout_file=argument.trim_prefix("--skeleton-layout=")
		elif argument.begins_with("--skeleton-type="): skeleton_type=argument.trim_prefix("--skeleton-type=")
		elif argument.begins_with("--skeleton-seed="): seed=int(argument.trim_prefix("--skeleton-seed="))
	super._ready()

func _get_skeleton_source() -> Dictionary:
	var value := 1001+posmod(active_seed-1001,10)
	var path := layout_file if not layout_file.is_empty() else "res://data/office_skeleton_preview/%s-%d.json" % [skeleton_type,value]
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
