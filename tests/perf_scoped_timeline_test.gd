extends SceneTree
const MARKERS=preload("res://scripts/app/performance_markers.gd")
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var monitor:Node=root.get_node("PerformanceMonitor")
	expect(monitor.start_recording("user://scoped_timeline_test")==OK,"isolated opt-in recorder starts")
	var owner:=Node.new();root.add_child(owner)
	var phase:="physics" if Engine.is_in_physics_frame() else "process"
	var outer:=MARKERS.scope_begin(owner,"blood_active_sim")
	OS.delay_usec(300)
	var inner:=MARKERS.scope_begin(owner,"blood_active_init")
	OS.delay_usec(300)
	MARKERS.scope_end(owner,inner);MARKERS.scope_end(owner,outer)
	var ms:Dictionary=monitor._stage_ms
	var inclusive:float=ms["blood_active_sim_"+phase]
	var own:float=ms["blood_active_sim_self_"+phase]
	var child:float=ms["blood_active_init_"+phase]
	expect(inclusive>=child and absf(own+child-inclusive)<.002,"self + nested child equals measured inclusive interval")
	expect(MARKERS._scopes.is_empty(),"synchronous nesting leaves no retained owners or open scopes")
	monitor._stage_ms.clear();monitor._stage_calls.clear()
	outer=MARKERS.scope_begin(owner,"blood_active_init")
	inner=MARKERS.scope_begin(owner,"blood_active_init")
	OS.delay_usec(100)
	MARKERS.scope_end(owner,inner);MARKERS.scope_end(owner,outer)
	expect(monitor._stage_calls["blood_active_init_"+phase]==1,"recursive same-family inclusive work counted only at outer scope")
	expect(absf(monitor._stage_ms["blood_active_init_"+phase]-monitor._stage_ms["blood_active_init_self_"+phase])<.002,"recursive same-family self time stays exclusive")
	for i in 300:monitor._note_boundary("fixture",Time.get_ticks_usec())
	for i in 90:monitor.record_render_request("fixture_call",owner.get_instance_id())
	expect(monitor._phase_trace.size()==192 and monitor._render_requests.size()==64,"phase/request histories stay bounded")
	monitor._last_trace_usec=0;monitor._record_phase_trace(Time.get_ticks_usec(),40)
	expect(monitor._traces_written==1,"slow sample captures existing script-visible history")
	monitor._record_phase_trace(Time.get_ticks_usec(),40)
	expect(monitor._traces_written==1,"trace cooldown prevents per-slow-frame deep copy storm")
	expect(monitor.recorder.event_counts.get("script_phase_trace",0)==1,"trace saved as plain data event")
	monitor._traces_written=200;monitor._severe_traces_written=0;monitor._last_severe_trace_usec=0
	monitor._record_phase_trace(Time.get_ticks_usec(),80)
	expect(monitor._traces_written==201 and monitor._severe_traces_written==1,"extreme stalls retain a separate trace budget after ordinary slow-frame cap")
	var samples:Array=[]
	for enabled in [false,true,false]:
		monitor.recording_enabled=enabled
		var started:=Time.get_ticks_usec()
		for i in 2000:
			var token:=MARKERS.scope_begin(owner,"blood_active_sim")
			MARKERS.scope_end(owner,token)
		samples.append((Time.get_ticks_usec()-started)/1000.0)
	monitor.recording_enabled=true
	print("SCOPE_OBSERVER_BENCH calls=2000 disabled/enabled/disabled_ms=",samples)
	monitor.recorder.close("scoped timeline test complete");monitor.recording_enabled=false;owner.free()
	print("SCOPED_TIMELINE checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
