extends SceneTree
const RECORDER=preload("res://scripts/app/gameplay_perf_recorder.gd")
const MARKERS=preload("res://scripts/app/performance_markers.gd")
const SMOKE_FIXTURE=preload("res://tests/fire_extinguisher_test.gd")
var checks:=0
var failures:Array[String]=[]

class World extends Node3D:
	var floor_transition_in_progress:=false
	var loading_render_preparation_pending:=false
	var elevator_transition_in_progress:=false
	var floor_root:Node3D
	var player:Node2D
	var current_room_id:=3
	var floor_index:=1
	var active_seed:=123
	var shadow_manager:Node3D
	func get_current_floor_token()->int:return 7

class Player extends Node2D:
	signal effective_damage_taken(amount:float)
	signal died
	signal revived
	signal active_weapon_changed(id:String)
	signal dash_state_changed(remaining:float,total:float,active:bool,charges:int,maximum:int)
	var current_health:=80.0
	var dead:=false

func expect(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func _initialize()->void:call_deferred("run")

func make_row(recorder,ms:float,phase:=1,warmup:=false)->PackedFloat64Array:
	var row:=PackedFloat64Array()
	row.resize(recorder.columns.size());row.fill(0)
	row[0]=recorder.frames_seen+1;row[1]=Time.get_ticks_usec()
	row[2]=ms;row[3]=phase;row[4]=int(warmup)
	row[recorder.columns.find("player_alive")]=1 if phase==1 else 0
	row[25]=3
	return row

func json_file(path:String)->Dictionary:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func run()->void:
	# None of these checks launches Main, AI, a GPU scene or a reproduction.
	var session=RECORDER.new()
	expect(session.begin("user://perf_recorder_tests",{"test":true})==OK,"start isolated writer")
	expect(session.columns.size()==168,"v5 schema includes bullet dispersal and mask submission stages")
	for i in 60:session.record_event("projectile_added",{"index":i},10)
	session.record_event("extinguisher_broken",{"source":1},10)
	for i in 6505:
		session.record_frame(make_row(session,1200.0 if i==0 else 10.0,1,i<20))
	session.record_frame(make_row(session,5000.0,2))
	session.record_frame(make_row(session,9000.0,3))
	var gameplay:Dictionary=session.stat_summary("gameplay")
	expect(gameplay.count==6505,"whole-session histogram survives >6000 frames")
	expect(gameplay.max_ms==1200.0,"early >1s gameplay hitch remains a gameplay peak")
	expect(gameplay.over_20==1,"no loading/pause contamination in gameplay spike count")
	expect(session.stat_summary("warmup").count==20,"warmup tagged separately")
	expect(session.stat_summary("steady").count==6485,"steady statistics retain all later gameplay frames")
	expect(gameplay.p99_ms==10.0,"percentile from entire gameplay histogram")
	expect(session.stat_summary("alive_gameplay").count==6505,"alive gameplay is separately accumulated")
	expect(session.stat_summary("loading").max_ms==5000.0,"explicit loading retained separately")
	expect(session.stat_summary("paused").max_ms==9000.0,"pause retained separately")
	expect(session.event_counts.projectile_added==60,"high-frequency event total not truncated by examples")
	expect(session.worst_frames.size()==1 and session.worst_frames[0].frame_ms==1200,"worst-frame history retains early peak")
	session.record_event("tail_event",{"test":true},6508)
	session.close("test checkpoint")
	expect(not session.active and not session._thread.is_alive(),"normal close joins writer and releases thread")
	var summary:=json_file(session.directory.path_join("summary.json"))
	expect(summary.get("frames_seen",0)==6507,"final summary includes every sampled frame")
	expect(summary.get("events",{}).get("tail_event",0)==1,"event after final frame is saved on exit")
	expect(FileAccess.get_file_as_string(session.directory.path_join("report.txt"))=="test checkpoint","per-session text report written")
	var metadata:=json_file(session.directory.path_join("metadata.json"))
	expect(metadata.get("columns",[]).size()==168 and metadata.get("phases",[]).size()==6 and metadata.get("version")==5,"machine-readable v5 schema saved")
	expect(metadata.get("timing_notes",[]).size()>=9,"timing limitations saved alongside data")
	var frames:=FileAccess.open(session.directory.path_join("frames.csv"),FileAccess.READ)
	expect(frames.get_csv_line().size()==168,"CSV header matches full schema")
	var saved_rows:=0
	var widths_valid:=true
	while not frames.eof_reached():
		var line:=frames.get_csv_line()
		if line.size()==1 and line[0].is_empty():continue
		widths_valid=widths_valid and line.size()==168
		saved_rows+=1
	frames.close()
	expect(widths_valid and saved_rows>0,"all emitted CSV rows match schema")
	var status:Dictionary=session.writer_status()
	expect(saved_rows+int(status.dropped_rows)+int(status.capped_rows)==6507,"saved/dropped/capped rows exactly account for session")
	var event_file:=FileAccess.open(session.directory.path_join("events.jsonl"),FileAccess.READ)
	var found_projectiles:=false
	while not event_file.eof_reached():
		var line:=event_file.get_line()
		if line.is_empty():continue
		var entry:Dictionary=JSON.parse_string(line)
		if entry.kind=="projectile_added":
			found_projectiles=true
			expect(entry.count==60 and entry.examples.size()==4,"events aggregate count with bounded examples")
	event_file.close()
	expect(found_projectiles,"event timeline written")
	var other=RECORDER.new()
	expect(other.begin("user://perf_recorder_tests")==OK,"start second run")
	expect(other.directory!=session.directory,"second run does not overwrite first")
	other.detail_limit_bytes=1
	other.record_frame(make_row(other,100))
	other.close("capped test")
	expect(other.writer_status().capped_rows==1,"detail capacity cap is explicit, not silent")
	expect(json_file(other.directory.path_join("summary.json")).stats.gameplay.max_ms==100,"summary stays complete after detail cap")
	var fractional=RECORDER.new()
	fractional._add_stat("gameplay",16.701)
	expect(fractional.stat_summary("gameplay").p99_ms==16.8,"quantiles round upward, never hide budget breach")
	var queue=RECORDER.new()
	queue.active=true
	for i in 12:
		queue._rows=make_row(queue,10)
		queue._submit()
	expect(queue._queue.size()==queue.MAX_QUEUED_CHUNKS,"slow-writer queue is bounded")
	expect(queue.dropped_rows==4,"slow-writer lost rows explicitly counted")
	queue.active=false
	var monitor:Node=root.get_node_or_null("PerformanceMonitor")
	if monitor==null:
		push_error("monitor autoload failed to parse")
		quit(1)
		return
	expect(not monitor.is_recording(),"script tests do not record automatically")
	var world:=World.new()
	world.floor_root=Node3D.new();world.add_child(world.floor_root)
	world.player=Player.new();world.add_child(world.player)
	root.add_child(world)
	monitor._focused=true
	monitor.is_report_open=false
	expect(not monitor._is_loading_frame(1200.0,world),">1s frame is not falsely classified as loading")
	world.floor_transition_in_progress=true
	expect(monitor._is_loading_frame(10.0,world),"transition flag classifies loading independently of duration")
	world.floor_transition_in_progress=false
	paused=true
	expect(monitor._phase_for(world)=="paused","pause phase")
	paused=false
	monitor._focused=false
	expect(monitor._phase_for(world)=="unfocused","focus-loss phase")
	monitor._focused=true
	monitor.is_report_open=true
	expect(monitor._phase_for(world)=="report","F4 work isolated from gameplay statistics")
	monitor.is_report_open=false
	monitor.reset_session_data()
	expect(monitor.start_recording("user://perf_recorder_integration")==OK,"real F3 monitor starts isolated recording")
	world.add_to_group(&"dream_world")
	monitor._bind_world(world)
	monitor.set_process(false)
	monitor.set_physics_process(false)
	monitor.prev_frame_usec=Time.get_ticks_usec()-1200000
	monitor._process_start_usec=Time.get_ticks_usec()
	monitor._process(1.2)
	expect(monitor.recorder.stat_summary("gameplay").max_ms>=1200.0,"real monitor retains long gameplay interval")
	var before:int=monitor.recorder.frames_seen
	monitor.current_mode=monitor.DisplayMode.DETAILED
	monitor.cycle_display_mode()
	expect(monitor.current_mode==monitor.DisplayMode.HIDDEN and monitor.is_recording(),"hiding F3 never stops recorder")
	world.player.effective_damage_taken.emit(5.0)
	MARKERS.event(world,"extinguisher_broken",{"source":2})
	MARKERS.event(world,"projectile_added",{"player_shot":false})
	MARKERS.end(world,"smoke_rebuild",Time.get_ticks_usec()-1000)
	monitor.prev_frame_usec=Time.get_ticks_usec()-40000
	monitor._process_start_usec=Time.get_ticks_usec()
	monitor._physics_steps=8
	monitor._physics_accum_ms=7.0
	monitor._process(0.04)
	expect(monitor.recorder.frames_seen==before+1,"hidden HUD continues frame logging")
	expect(monitor.last_breakdown.physics_steps==8,"catch-up steps retained")
	expect(monitor.recorder.event_counts.get("player_hit",0)==1,"player damage signal on timeline")
	expect(monitor.recorder.event_counts.get("extinguisher_broken",0)==1,"extinguisher event marker on timeline")
	expect(monitor.recorder.event_counts.get("projectile_added",0)==1,"combat marker on timeline")
	expect(monitor._stage_ms.is_empty(),"stage measurements consumed once per sample")
	var life_before:int=monitor.recorder.stat_summary("alive_gameplay").count
	world.player.dead=true;world.player.died.emit()
	monitor.prev_frame_usec=Time.get_ticks_usec()-33000;monitor._process_start_usec=Time.get_ticks_usec();monitor._process(.033)
	expect(monitor.recorder.stat_summary("alive_gameplay").count==life_before+1,"lethal frame is included in alive gameplay")
	var fatal_frame:=Engine.get_process_frames()
	while Engine.get_process_frames()==fatal_frame:await process_frame
	monitor.prev_frame_usec=Time.get_ticks_usec()-10000;monitor._process_start_usec=Time.get_ticks_usec();monitor._process(.01)
	expect(monitor.recorder.stat_summary("dead_gameplay").count==1,"later death hold is excluded from alive statistics")
	world.player.dead=false;world.player.revived.emit()
	monitor.prev_frame_usec=Time.get_ticks_usec()-10000;monitor._process_start_usec=Time.get_ticks_usec();monitor._process(.01)
	expect(monitor.recorder.stat_summary("alive_gameplay").count==life_before+2,"revival begins another alive interval")
	expect(monitor.recorder.event_counts.get("player_revived",0)==1,"revival event recorded")
	var sys_free:float=monitor._context.get("system_free_physical_bytes",-1)
	var sys_total:float=monitor._context.get("system_physical_total_bytes",-1)
	expect(sys_free>=0 and sys_free<=sys_total,"free physical memory fits physical total")
	var directory:String=monitor.recorder.directory
	monitor.open_report_dialog()
	expect(monitor.is_report_open,"F4 opens report")
	expect(FileAccess.file_exists("user://perf_run_report.txt"),"legacy F4 report copy retained")
	expect(monitor.generate_report_text().contains("超过1秒不会自动排除为加载"),"report states honest loading rule")
	monitor.close_report_dialog()
	monitor.reset_session_data()
	expect(monitor.recorder.directory!=directory,"reset preserves previous run rather than deleting data")
	expect(FileAccess.file_exists(directory.path_join("summary.json")),"reset saved previous session")
	var smoke_world:=SMOKE_FIXTURE.World.new()
	root.add_child(smoke_world)
	for y in 4:
		for x in 4:
			smoke_world.floor_cells[Vector2i(x,y)]="room"
			smoke_world.room_cells[Vector2i(x,y)]=0
	var smoke:Node=SMOKE_FIXTURE.SYSTEM.install(smoke_world)
	smoke.set_physics_process(false)
	for mounted in smoke_world.key_root.get_children():mounted.set_physics_process(false)
	var tank:Node=SMOKE_FIXTURE.TANK.new()
	tank.world=smoke_world;tank.controller=smoke;tank.position=Vector2(32,32)
	smoke_world.key_root.add_child(tank);tank.set_physics_process(false)
	tank.take_damage(100,Vector2.RIGHT)
	tank._physics_process(1.0/60.0)
	smoke._physics_process(1.0/60.0)
	smoke.flush_presentation(true)
	smoke._physics_process(1.0/60.0)
	smoke.disperse_segment(Vector2(32,32),Vector2(96,32))
	for stage in ["smoke_physics","smoke_rebuild","smoke_coverage","smoke_visibility","smoke_prepare","smoke_fusion","smoke_upload","extinguisher_flight","smoke_disperse","smoke_mask_upload"]:
		expect(int(monitor._stage_calls.get(stage,0))>0,"actual extinguisher stage recorded: "+stage)
	expect(monitor.recorder.event_counts.get("smoke_dispersed",0)>0,"only actual bullet clearing emits smoke intersection event")
	expect(monitor.recorder.event_counts.get("extinguisher_broken",0)==1,"actual cylinder break emits exactly one diagnostic event")
	expect(smoke.sources.size()==1 and tank.broken,"diagnostics leave real discharge and flight rules unchanged")
	smoke_world.queue_free()
	var freed:=Node2D.new()
	world.player=freed
	freed.free()
	monitor._bind_world(world)
	expect(true,"freed player reference is not cast or dereferenced")
	monitor._autosave_report()
	monitor._autosave_report()
	expect(not monitor.recorder._thread.is_alive(),"repeated exit notification closes writer only once")
	world.queue_free()
	await process_frame
	for script in ["res://scripts/dream/dream_3d_random_dungeon.gd","res://scripts/dream/destruction_floor_debris.gd","res://scripts/dream/furniture_3d_debris.gd","res://scripts/dream/elemental_particles_3d.gd","res://scripts/entities/dream_player.gd"]:
		expect(load(script)!=null,"instrumented source parses: "+script)
	print("GAMEPLAY_PERF_RECORDER checks=%d failed=%d paths=%s"%[checks,failures.size(),session.directory])
	for failure in failures:printerr(failure)
	quit(0 if failures.is_empty() else 1)
