extends "res://tests/random_combat_perf.gd"
## Existing 60-second workload and budget, with background focus protection.
var visual_frames:Array=[]
var previous_capture:=0
func _initialize()->void:
	process_frame.connect(func()->void:
		if DisplayServer.get_name()!="headless" and DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	super._initialize()
	if "--without-floor-reflections" in OS.get_cmdline_user_args():
		node_added.connect(func(node:Node)->void:
			if node.get_script()==preload("res://scripts/dream/office_skeleton_world_base.gd"):
				node.set_meta(&"test_floor_reflections_disabled",true))
func drive(seconds:float)->void:
	super.drive(seconds)
	# Only in the first warmup window; no screenshot readback in the measured
	# sixty seconds. Parent resets seconds at measurement start, but count is full.
	if visual_frames.size()>=24 or seconds<1.0 or seconds>3.5: return
	var now:=Time.get_ticks_usec()
	if now-previous_capture<80000: return
	previous_capture=now
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir+"/warmup"))
	var name:="frame_%03d.png"%visual_frames.size()
	root.get_texture().get_image().save_png(artifact_dir+"/warmup/"+name)
	visual_frames.append({"file":name,"seconds":seconds})
	var file:=FileAccess.open(artifact_dir+"/warmup/frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(visual_frames,"\t")); file.close()
