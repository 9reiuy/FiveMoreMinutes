extends Node
## Opt-in existing PERF markers route here via their WeakRef, not a replacement
## of the production autoload. No frame-time disk IO, tree scan or new profiler.
var active:=false
var stage_ms:Dictionary={}
var stage_calls:Dictionary={}
var events:Array[Dictionary]=[]
var event_counts:Dictionary={}
var method_overhead_usec:=0
var started:=0
func is_recording()->bool: return active
func begin_window()->void:
	stage_ms.clear();stage_calls.clear();events.clear();event_counts.clear();method_overhead_usec=0;started=Time.get_ticks_usec();active=true
func record_stage(stage:String,milliseconds:float)->void:
	var begin:=Time.get_ticks_usec()
	stage_ms[stage]=float(stage_ms.get(stage,0.0))+milliseconds
	stage_calls[stage]=int(stage_calls.get(stage,0))+1
	method_overhead_usec+=Time.get_ticks_usec()-begin
func record_event(kind:String,details:Dictionary={})->void:
	var begin:=Time.get_ticks_usec()
	event_counts[kind]=int(event_counts.get(kind,0))+1
	if events.size()<4096:events.append({"event":kind,"seconds":(begin-started)/1000000.0,"frame":Engine.get_process_frames(),"details":details.duplicate(true)})
	method_overhead_usec+=Time.get_ticks_usec()-begin
func record_render_request(kind:String,_node_id:int)->void:
	record_stage("capture_request_"+kind,0.0)
func pop_frame()->Dictionary:
	var result:={"ms":stage_ms,"calls":stage_calls,"sink_usec":method_overhead_usec}
	stage_ms={};stage_calls={};method_overhead_usec=0
	return result
