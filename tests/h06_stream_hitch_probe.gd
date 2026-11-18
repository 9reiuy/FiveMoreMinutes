extends "res://tests/h06_hangar_crew_test.gd"
const PROBE := preload("res://tests/h06_stream_probe_world.gd")
const MATERIALS := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
var phase := "boot"
var events: Array[Dictionary]=[]
var raw: Array[Dictionary]=[]
var last_usec:=0
var collecting:=false
var vp:=RID()
var draw_started:=0
var draw_ms:=0.0
var warm_receipts:Array=[]
var source_before:Dictionary={}

func source_hashes() -> Dictionary:
	var result:Dictionary={}
	for filename:String in DirAccess.get_files_at("res://scripts/testing/h06_chapter"):
		if filename.ends_with(".gd") or filename.ends_with(".gdshader"):
			var path:String="res://scripts/testing/h06_chapter/"+filename
			result[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scripts/dream/elevator_render_readiness.gd","res://scripts/dream/dream_3d_random_dungeon.gd","res://scripts/dream/dream_3d_actor_depth_bridge.gd"]:result[path]=FileAccess.get_sha256(path)
	return result

func draw_begin() -> void:draw_started=Time.get_ticks_usec()
func draw_end() -> void:
	if draw_started>0:draw_ms=(Time.get_ticks_usec()-draw_started)*0.001

func timing_event(data: Dictionary) -> void:
	data["phase"]=phase
	data["feet"]=str(world._feet()) if is_instance_valid(world.player) else "none"
	events.append(data)

func frame_tick() -> void:
	var now:=Time.get_ticks_usec()
	if collecting and last_usec>0 and is_instance_valid(world) and is_instance_valid(world.blockout):
		raw.append({"frame":Engine.get_process_frames(),"phase":phase,"ms":(now-last_usec)*0.001,"visit":int(world.blockout.visit),"feet":str(world._feet()),"prepared":int(world.prepared.visit) if world.prepared!=null else -1,"steps":world.prepared.build_steps.size() if world.prepared!=null else 0,"unload_queue":world.unload_queue.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_span_ms":draw_ms,"compile_specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),"compile_mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"compile_canvas":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),"compile_draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"vp_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(vp) if vp.is_valid() else 0.0,"vp_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(vp) if vp.is_valid() else 0.0})
	last_usec=now

func enter(save: int, _crew:=true) -> void:
	collecting=false
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":save})
	world=load(WORLD).instantiate()
	world.set_script(PROBE)
	if OS.get_environment("H06_DEFAULTS")!="1":
		world.set_meta(&"h06_resource_reuse",OS.get_environment("H06_REUSE")=="1")
		world.set_meta(&"h06_streaming_budget",OS.get_environment("H06_STREAM_BUDGET")=="1")
		world.set_meta(&"h06_render_warmup",OS.get_environment("H06_RENDER_WARMUP")=="1")
	world.set_meta(&"h06_warm_capture",evidence.path_join("warm-"+str(save)))
	world.timing_sink=timing_event
	world.generate_on_ready=false
	display=load(PREVIEW).instantiate()
	display.preview_mode=false
	display.world=world
	root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0): AudioServer.set_bus_mute(0,true);quit(2);return
	check(world.regenerate(11011),"native chapter generates")
	world._setup_chapter_session()
	if OS.get_environment("H06_RENDER_WARMUP")=="1":
		var old_mode:int=world.process_mode
		world.process_mode=Node.PROCESS_MODE_DISABLED
		var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
		var nodes_before:=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var receipt:Dictionary=await world.prepare_chapter_streaming()
		receipt["static_memory_before"]=memory_before
		receipt["static_memory_after"]=Performance.get_monitor(Performance.MEMORY_STATIC)
		receipt["nodes_before"]=nodes_before
		receipt["nodes_after"]=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		warm_receipts.append(receipt.duplicate(true))
		world.process_mode=old_mode
		check(receipt.get("ready",false),"loading render warmup completes")
	root.get_node("DreamTimeController").slow_time_enabled=false
	Engine.time_scale=1
	world._spotlight_triggered=true
	if is_instance_valid(world.blockout.mech):world.blockout.play_spotlight_reveal(true)
	vp=display.world_viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp,true)
	await frames(90)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	collecting=true
	last_usec=Time.get_ticks_usec()

func travel(destination: Vector2, label: String, speed:=3.6) -> void:
	phase=label
	for i in 600:
		var offset: Vector2=destination-world._feet()
		if offset.length()<0.15:break
		world.player.set_scripted_locomotion(offset.normalized(),minf(speed,offset.length()*25)*32)
		await physics_frame
	world.player.clear_scripted_locomotion()
	check(world._feet().distance_to(destination)<0.3,"walk reaches "+label)

func finish_zone(label: String) -> void:
	phase=label+"/settling"
	await frames(90)
	collecting=false
	await photograph(label)

func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():quit(3))
	source_before=source_hashes()
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	preload("res://tests/support/background_gpu.gd").start(self)
	MATERIALS.procedural_cache_enabled=OS.get_environment("H06_REUSE")=="1"
	process_frame.connect(frame_tick)
	RenderingServer.frame_pre_draw.connect(draw_begin)
	RenderingServer.frame_post_draw.connect(draw_end)
	await enter(CHAPTER.Save.ENTRANCE)
	world._place_feet(Vector2(-6.05,-7.1))
	await travel(Vector2(-6.05,-13.2),"upper-room-entry")
	await travel(Vector2(-5.50,-18.5),"upper-room-inside")
	await travel(Vector2(-5.50,-25.7),"upper-room-to-west")
	await finish_zone("01-upper-room")
	await unload()
	phase="return-setup"
	await enter(CHAPTER.Save.GUARD)
	world.stage=CHAPTER.Stage.RETURN
	world.wave=""
	world.warehouse_cleared={"guard":true,"inspection":true,"archive":true,"pump":true}
	for unit in world.warehouse_squads.values():
		for actor:EmployeeEnemy in unit:actor.set_room_runtime_active(false)
	world.blockout.set_gate("pump",false)
	world._set_lower(true)
	world._place_feet(Vector2(-17.8,8.0))
	await travel(Vector2(-8.8,8.0),"west-to-return-hangar")
	await finish_zone("02-return-hangar")
	collecting=true
	last_usec=Time.get_ticks_usec()
	world.blockout.set_gate("cargo_access",false)
	await travel(Vector2(0.5,10.2),"return-hangar-to-cargo")
	await travel(Vector2(0.5,16.4),"enter-1-3-freight")
	await finish_zone("03-enter-freight")
	await unload()
	var summary:Dictionary={}
	for label in ["upper-room-entry","upper-room-inside","upper-room-to-west","west-to-return-hangar","return-hangar-to-cargo","enter-1-3-freight"]:
		var values:Array=[]
		for row in raw:
			if row.phase==label:values.append(row.ms)
		values.sort()
		if not values.is_empty():summary[label]={"frames":values.size(),"p50":values[int(values.size()*0.5)],"p95":values[int(values.size()*0.95)],"p99":values[mini(values.size()-1,int(values.size()*0.99))],"max":values[-1],"over_25":values.filter(func(x):return x>25).size()}
	check(source_before==source_hashes(),"chapter and shared runtime sources stay unchanged during measurement")
	FileAccess.open(evidence.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"events":events,"frames":raw,"summary":summary,"warm_receipts":warm_receipts,"source_hashes":source_before,"production_defaults":OS.get_environment("H06_DEFAULTS")=="1","renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_STREAM_PROFILE ",JSON.stringify(summary))
	quit(0 if checks.all(func(row:Dictionary)->bool:return row.pass) else 1)
