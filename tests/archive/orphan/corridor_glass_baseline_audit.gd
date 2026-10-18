extends SceneTree
const WORLD=preload("res://scripts/dream/office_skeleton_world_base.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var results: Array[Dictionary]=[]
	for type in ["A1","B2","C3","V3"]:
		for value in [120,42001,42002]:
			var world=WORLD.new(); world.native_skeleton_type=type
			if not world.generate_layout_only(value): push_error("Generation failed"); world.free(); quit(1); return
			var data: Dictionary=world.skeleton_source
			for door in data.doors:
				if not door.glass: continue
				for segment in data.corridorSegments:
					if String(segment.room) not in [String(door.a),String(door.b)] or segment.w==segment.h: continue
					var transverse: bool=(bool(door.vertical) and int(segment.w)>int(segment.h)) or (not bool(door.vertical) and int(segment.h)>int(segment.w))
					if not transverse: continue
					var line: int=door.line
					var at_end: bool=line in [int(segment.x),int(segment.x)+int(segment.w)] if door.vertical else line in [int(segment.y),int(segment.y)+int(segment.h)]
					var segment_start: int=segment.y if door.vertical else segment.x
					var segment_length: int=segment.h if door.vertical else segment.w
					var overlaps: bool=int(door.start)<segment_start+segment_length and int(door.start)+int(door.width)>segment_start
					if at_end and overlaps: results.append({"type":type,"seed":value,"hall":segment.room,"segment":segment,"door":door})
			world.free()
	print("CORRIDOR_GLASS_BASELINE ",JSON.stringify(results))
	var directory := "res://.runtime/corpse_corridor_revision_20261014"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file:=FileAccess.open(directory+"/glass_baseline.json",FileAccess.WRITE); file.store_string(JSON.stringify(results,"\t")); file.close()
	quit(0)
