extends Node
## Diagnostic only. Public frame signals delimit phases, not individual native
## functions. Residual before process includes native physics/queries/input/OS.
class EndHook extends Node:
	var probe: Node
	func _process(_delta: float) -> void: probe.process_end=Time.get_ticks_usec()
	func _physics_process(_delta: float) -> void:
		if probe.active and probe.physics_begin>0:
			probe.physics_usec+=Time.get_ticks_usec()-probe.physics_begin
			probe.physics_steps+=1
var active:=false
var rows: Array=[]
var previous_draw:=0
var process_begin:=0
var process_end:=0
var pre_draw:=0
var physics_begin:=0
var physics_usec:=0
var physics_steps:=0
var watched_root: Node
var watched_ids: Dictionary={}
var frame_events: Dictionary={}
var context_provider: Callable
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var end:=EndHook.new(); end.probe=self
	end.process_priority=2147483647; end.process_physics_priority=2147483647
	add_child(end)
	get_tree().process_frame.connect(on_process_begin)
	get_tree().physics_frame.connect(on_physics_begin)
	RenderingServer.frame_pre_draw.connect(on_pre_draw)
	RenderingServer.frame_post_draw.connect(on_post_draw)
	get_tree().node_added.connect(on_node_added)
	get_tree().node_removed.connect(on_node_removed)
func begin() -> void:
	rows.clear(); previous_draw=0; physics_usec=0; physics_steps=0; active=true
	watched_ids.clear(); frame_events.clear()
	if is_instance_valid(watched_root):
		for node in watched_root.find_children("*","Node",true,false): watched_ids[node.get_instance_id()]=true
func _record_event(node: Node,prefix: String) -> void:
	var script: Script=node.get_script()
	var name: String=script.resource_path.get_file() if script!=null else node.get_class()
	var key: String=prefix+name
	frame_events[key]=int(frame_events.get(key,0))+1
func on_node_added(node: Node) -> void:
	if active and is_instance_valid(watched_root) and watched_root.is_ancestor_of(node):
		watched_ids[node.get_instance_id()]=true; _record_event(node,"added:")
func on_node_removed(node: Node) -> void:
	if active and watched_ids.erase(node.get_instance_id()): _record_event(node,"removed:")
func on_process_begin() -> void: process_begin=Time.get_ticks_usec()
func on_physics_begin() -> void: physics_begin=Time.get_ticks_usec()
func on_pre_draw() -> void: pre_draw=Time.get_ticks_usec()
func on_post_draw() -> void:
	var now:=Time.get_ticks_usec()
	if active and previous_draw>0:
		var row: Dictionary={"frame_ms":(now-previous_draw)/1000.0,"physics_callbacks_ms":physics_usec/1000.0,"physics_steps":physics_steps,
			"before_process_residual_ms":(process_begin-previous_draw-physics_usec)/1000.0,
			"process_callbacks_ms":(process_end-process_begin)/1000.0,
			"after_process_before_draw_ms":(pre_draw-process_end)/1000.0,"draw_ms":(now-pre_draw)/1000.0}
		row["events"]=frame_events.duplicate()
		if row.frame_ms>=40.0 and context_provider.is_valid(): row["context"]=context_provider.call()
		rows.append(row)
	previous_draw=now; physics_usec=0; physics_steps=0
	frame_events.clear()
func finish() -> Dictionary:
	active=false
	var results: Dictionary={}
	if rows.is_empty(): return {"frames":0}
	var slow: Array=[]
	var event_totals: Dictionary={}
	var destruction_frames: Array=[]
	for index in rows.size():
		if float(rows[index].frame_ms)>=40.0: slow.append({"sample":index,"phases":rows[index]})
		for event in rows[index].events:
			event_totals[event]=int(event_totals.get(event,0))+int(rows[index].events[event])
		if rows[index].events.has("added:furniture_3d_debris.gd"):
			destruction_frames.append({"sample":index,"phases":rows[index]})
	results["slow_frames"]=slow
	results["events_total"]=event_totals
	results["furniture_destruction_frames"]=destruction_frames
	var over_18_rows: Array = []
	for index in rows.size():
		if float(rows[index].frame_ms) > 18.0:
			over_18_rows.append({"sample": index, "phases": rows[index]})
	over_18_rows.sort_custom(func(a, b): return float(a.phases.frame_ms) > float(b.phases.frame_ms))
	var top_10: Array = []
	for i in mini(10, over_18_rows.size()):
		top_10.append(over_18_rows[i])
	results["top_10_frames"] = top_10
	if not over_18_rows.is_empty():
		var over_18_summary: Dictionary = {"count": over_18_rows.size()}
		for key in ["frame_ms", "physics_callbacks_ms", "before_process_residual_ms", "process_callbacks_ms", "after_process_before_draw_ms", "draw_ms", "physics_steps"]:
			var vals: Array = []
			for item in over_18_rows:
				vals.append(item.phases[key])
			vals.sort()
			over_18_summary[key] = {"median": vals[vals.size() / 2], "p95": vals[floori(vals.size() * 0.95)], "max": vals.back()}
		results["over_18ms_summary"] = over_18_summary
	for key in rows[0]:
		if key in ["events","context"]: continue
		var values: Array=[]
		for row in rows: values.append(row[key])
		values.sort(); results[key]={"median":values[values.size()/2],"p95":values[floori(values.size()*.95)]}
	results["frames"]=rows.size()
	results["semantics"]="signal-delimited phases; medians not additive; residual is not pure physics; draw is CPU elapsed, not GPU duration"
	return results
func _exit_tree() -> void:
	get_tree().process_frame.disconnect(on_process_begin)
	get_tree().physics_frame.disconnect(on_physics_begin)
	RenderingServer.frame_pre_draw.disconnect(on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(on_post_draw)
	get_tree().node_added.disconnect(on_node_added)
	get_tree().node_removed.disconnect(on_node_removed)
