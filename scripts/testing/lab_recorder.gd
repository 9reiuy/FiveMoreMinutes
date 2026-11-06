extends RefCounted
## Bounded, no per-frame disk writes. Intervals are wall time, not GPU time.
const MAX_FRAMES := 72000
var active := false
var rows: Array[Array] = []
var events: Array[Dictionary] = []
var metadata: Dictionary = {}
var start_usec := 0
var previous_usec := 0
var draw_start_usec := 0
var draw_ms := 0.0
var physics_steps := 0
var output_dir := ""
var last_error := ""

func begin(config: Dictionary) -> void:
	metadata = config.duplicate(true)
	metadata["schema"] = 1
	metadata["measurement"] = "Adjacent process-frame wall intervals; pre/post-draw CPU wall interval, NOT GPU execution. Viewport GPU/CPU queries are delayed and cannot attribute an individual spike. Setup, screenshots and disk export are outside the sampled window."
	rows.clear(); events.clear(); physics_steps=0; draw_ms=0
	start_usec = Time.get_ticks_usec(); previous_usec = 0; active=true

func mark(kind: String, details: Dictionary = {}) -> void:
	if active and events.size() < 4096:
		events.append({"kind":kind,"seconds":(Time.get_ticks_usec()-start_usec)/1000000.0,"engine_frame":Engine.get_process_frames(),"details":details.duplicate(true)})

func frame(world: Node3D) -> void:
	if not active or not is_instance_valid(world): return
	var now := Time.get_ticks_usec()
	if previous_usec != 0 and rows.size() < MAX_FRAMES:
		var vp := world.get_viewport()
		rows.append([Engine.get_process_frames(),(now-start_usec)/1000000.0,(now-previous_usec)/1000.0,draw_ms,physics_steps,
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()),
			float(world.lab_cutout_usec)/1000.0,int(world.player.dead),int(world.current_room_id)])
	previous_usec=now; physics_steps=0; world.lab_cutout_usec=0

static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate(); sorted.sort()
	var total := 0.0; var over_budget := 0; var over20 := 0
	for v in sorted: total+=float(v); over_budget+=int(v>1000.0/60.0); over20+=int(v>20.0)
	return {"frames":sorted.size(),"mean_ms":total/sorted.size(),"p50_ms":sorted[ceili(sorted.size()*.5)-1],"p95_ms":sorted[ceili(sorted.size()*.95)-1],"p99_ms":sorted[ceili(sorted.size()*.99)-1],"max_ms":sorted.back(),"over_16_667":over_budget,"over_20":over20}

func summary() -> Dictionary:
	var values: Array=[]; var alive: Array=[]
	for row in rows:
		values.append(row[2])
		if int(row[9])==0: alive.append(row[2])
	return {"all_sampled":stats(values),"alive_sampled":stats(alive),"bounded_buffer_full":rows.size()>=MAX_FRAMES}

static func unique_directory(base: String, prefix: String) -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":","-")
	var path := base.path_join("%s_%s_%d" % [prefix,stamp,Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(path)!=OK: return ""
	return path

func finish(base: String, reason: String = "completed") -> String:
	active=false
	output_dir=unique_directory(base,"run")
	if output_dir.is_empty(): last_error="无法创建输出目录"; return ""
	var csv := FileAccess.open(output_dir.path_join("frames.csv"),FileAccess.WRITE)
	if csv==null: last_error="无法写入帧记录"; return ""
	csv.store_csv_line(PackedStringArray(["engine_frame","elapsed_s","frame_wall_ms","previous_draw_wall_ms","physics_steps","draw_calls_delayed","world_cpu_ms_delayed","world_gpu_ms_delayed","cutout_cpu_ms","dead","room"]))
	for row in rows:
		var fields:=PackedStringArray()
		for value in row: fields.append(str(value))
		csv.store_csv_line(fields)
	csv.close()
	var report := summary()
	report.merge({"metadata":metadata,"reason":reason,"events":events})
	var json := FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	if json==null: last_error="无法写入报告"; return ""
	json.store_string(JSON.stringify(report,"\t")); json.close()
	var readable := FileAccess.open(output_dir.path_join("RESULT.txt"),FileAccess.WRITE)
	if readable!=null:
		readable.store_string("FiveMinuteMore 独立测试场\n%s\n\n%s\n\n注意：这是指定测试场景的结果，不等于全游戏通过 60 FPS 验收。比较 A/B 时保持种子、房间、敌人数量、负载、分辨率、限帧方式一致。统计不删除采样期间的尖峰。\n" % [JSON.stringify(metadata,"\t"),JSON.stringify(report.get("alive_sampled",{}),"\t")])
		readable.close()
	return output_dir
