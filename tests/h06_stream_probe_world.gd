extends "res://scripts/testing/h06_chapter/chapter_world.gd"
## Read-only timing wrappers around the exact chapter implementation.
var timing_sink: Callable

func note(label: String, started: int, data: Dictionary = {}) -> void:
	if not timing_sink.is_valid(): return
	data["label"]=label
	data["ms"]=(Time.get_ticks_usec()-started)*0.001
	data["process_frame"]=Engine.get_process_frames()
	data["physics_frame"]=Engine.get_physics_frames()
	timing_sink.call(data)

func _plan_region(id: PLAN.Visit) -> BLOCKOUT:
	var started:=Time.get_ticks_usec()
	var area: BLOCKOUT=super._plan_region(id)
	area.preparation_observer=func(data:Dictionary)->void:
		data["process_frame"]=Engine.get_process_frames()
		data["physics_frame"]=Engine.get_physics_frames()
		if timing_sink.is_valid():timing_sink.call(data)
	note("plan_region",started,{"visit":int(id),"steps":area.build_steps.size()})
	return area

func _enter_prepared() -> void:
	var started:=Time.get_ticks_usec()
	var remaining:=prepared.build_steps.size()
	var next_visit:=int(prepared.visit)
	super._enter_prepared()
	note("enter_prepared",started,{"visit":next_visit,"forced_steps":remaining,"unload_queue":unload_queue.size()})

func _retire_room_content() -> void:
	var started:=Time.get_ticks_usec()
	super._retire_room_content()
	note("retire_room_content",started,{"unload_queue":unload_queue.size()})

func _use_region_cells() -> void:
	var started:=Time.get_ticks_usec()
	super._use_region_cells()
	note("use_region_cells",started,{"visit":int(blockout.visit)})

func _populate_west_warehouse_enemies() -> void:
	var started:=Time.get_ticks_usec()
	super._populate_west_warehouse_enemies()
	note("populate_warehouse_enemies",started,{"enemies":enemy_root.get_child_count()})

func _process(delta: float) -> void:
	var started:=Time.get_ticks_usec()
	super._process(delta)
	if Time.get_ticks_usec()-started>2000: note("world_process",started,{"queue":unload_queue.size()})

func _drain_retired_region() -> void:
	if OS.get_environment("H06_NO_UNLOAD")=="1":return
	var started:=Time.get_ticks_usec()
	super._drain_retired_region()
	if Time.get_ticks_usec()-started>500:note("retire_batch",started,{"queue":unload_queue.size()})

func _physics_process(delta: float) -> void:
	var started:=Time.get_ticks_usec()
	super._physics_process(delta)
	if Time.get_ticks_usec()-started>2000: note("world_physics",started)
