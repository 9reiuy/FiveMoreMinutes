extends SceneTree
## Run only in the independent lab. Never force_draw or mutate campaign assets.
const LAB_PATH="res://scenes/testing/GameTestLab.tscn"
const SINK=preload("res://tests/support/lab_probe_sink.gd")
const PERF=preload("res://scripts/app/performance_markers.gd")
const STATS=preload("res://scripts/testing/lab_recorder.gd")
var lab:Control
var world:Node3D
var sink:Node
var out:="res://.runtime/lab_ablation_20261102/"
var batch:="canary"
var results:Array=[]
var failed:Array[String]=[]
var arm:="baseline"
var shots:=0
var own_events:Array=[]
var started:=0
var draw_started:=0
var draw_wall:=0.0
var physics_count:=0
var pose:=Vector2.ZERO
var collecting:=false
var stage_totals:Dictionary={}
var stage_max:Dictionary={}
var stage_counts:Dictionary={}
var intervention_usec:=0
var seed_id:=71432
var pending_effect:=0
var requested_arms:PackedStringArray=[]
var seconds_override:=0.0
var use_formal_prewarm:=false
var preparation:Dictionary={}
var sample_started_unix:=0.0
var suspended_enemies:Array[Dictionary]=[]

func _initialize()->void:call_deferred("run")
func require(ok:bool,label:String)->void:
	if not ok:failed.append(label);push_error("LAB_ABLATION "+label)
func _physics_process(_delta:float)->bool:
	if collecting:physics_count+=1
	return false
func pre_draw()->void:
	draw_started=Time.get_ticks_usec()
	if not is_instance_valid(world):return
	var t:=Time.get_ticks_usec()
	if arm=="smoke_no_draw":
		var smoke:Node3D=world.floor_root.get_node_or_null("FireExtinguisherSystem")
		if smoke!=null:smoke.hide()
	intervention_usec+=Time.get_ticks_usec()-t
func post_draw()->void:draw_wall=(Time.get_ticks_usec()-draw_started)/1000.0
func event(kind:String,data:Dictionary={})->void:
	var item:={"event":kind,"seconds":(Time.get_ticks_usec()-started)/1000000.0,"frame":Engine.get_process_frames(),"data":data}
	own_events.append(item)
func on_shot(_value:float)->void:shots+=1

func setup(name:String,native:bool,enemy_count:int=12,ai:bool=false)->void:
	arm=name
	seed(seed_id)
	lab.mode.select(2 if native else 1)
	lab.enemies.value=enemy_count
	lab.seed_box.value=seed_id
	lab.checks.furniture.set_pressed_no_signal(name!="no_furniture")
	lab.checks.ai.set_pressed_no_signal(ai)
	lab.checks.special.set_pressed_no_signal(name=="special_units")
	for key in ["cutout","shadows","reflections","pixels","palette","tonal","invincible","uncapped"]:
		lab.checks[key].set_pressed_no_signal(not (name=="no_"+key))
	await lab.rebuild()
	require(lab.ready_world,"world generated: "+name)
	world=lab.world
	preparation={}
	suspended_enemies.clear()
	var enemy_index:=0
	for enemy in world.enemy_root.get_children():
		if enemy.get("random") is RandomNumberGenerator:enemy.random.seed=seed_id+enemy_index*101
		if ai:
			suspended_enemies.append({"ref":weakref(enemy),"mode":enemy.process_mode})
			enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy_index+=1
	world.lab_probe_flags={"skip_smoke_disperse":name=="smoke_no_disperse","skip_blood":name=="blood_disabled","skip_muzzle":name=="no_muzzle"}
	if name=="furniture_frozen":
		for prop in world.furniture_root.get_children():
			if prop is RigidBody2D:prop.freeze=true
	var room_id:=1
	if native:
		var counts:Dictionary={}
		for prop in world.furniture_root.get_children():
			var id:int=prop.get_meta(&"dream_room_id",-1)
			counts[id]=int(counts.get(id,0))+1
		var highest:=-1
		for room in world.rooms:
			if String(room.get("archetype",""))!="open_office":continue
			# Room selection must not change when the furniture exclusion is active.
			var score:int=room.get("usable_cells",[]).size()
			if score>highest:highest=score;room_id=int(room.id)
	lab.station.select(room_id);lab.teleport(room_id)
	pose=world.player.global_position
	lab.weapon.select(2);lab.equip()
	lab.panel.hide();lab.hud.hide()
	lab.set_process(false)
	# Keep ammo/reload/animation on the normal clock even with fixed locomotion.
	world.player.set_physics_process(true)
	world.player.movement_enabled=false
	world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	world.player.set_meta(&"presentation_pointer_gate",Callable())
	world.player.weapon_fired.connect(on_shot)
	world.player.invulnerability_left=0.0
	world.player.visual.visible=true
	world.player.visual.modulate=Color.WHITE
	# Seed this formal smoke controller explicitly; do not replace its algorithm.
	var smoke:Node=world.floor_root.get_node_or_null("FireExtinguisherSystem")
	if smoke!=null:smoke.rng.seed=seed_id+77
	require(not world._current_floor_path_adjacency().is_empty(),"production path cache retained")
	var begin:=Time.get_ticks_usec();var frames:=0
	while frames<120 or Time.get_ticks_usec()-begin<2000000:
		world._update_camera_and_actor_projection(0.0)
		await process_frame;frames+=1
	if use_formal_prewarm:
		var saved_flags:Dictionary=world.lab_probe_flags.duplicate()
		world.lab_probe_flags={}
		paused=true
		preparation=await preload("res://scripts/dream/elevator_render_readiness.gd").run(self,world)
		paused=false
		world.lab_probe_flags=saved_flags
		require(preparation.get("ready",false) and preparation.get("render_verified",false),name+" formal render preparation verified")
		for frame in 6:await process_frame
	# Warm scene only; event activation remains inside sample window.

func apply_workload(kind:String,t:float)->void:
	var firing:=kind in ["shoot","shoot_smoke","smoke_no_draw","smoke_no_disperse","no_muzzle","furniture_frozen","combat","special_units"]
	world.player.set_meta(&"force_weapon_attack",firing)
	if kind in ["smoke","shoot_smoke","smoke_no_draw","smoke_no_disperse"] and pending_effect==0 and t>=1.0:
		var smoke:Node=world.floor_root.get_node("FireExtinguisherSystem")
		var point:Vector2=pose+Vector2.RIGHT*64.0
		smoke.discharge(point);pending_effect+=1;event("discharge",{"point":str(point)})
	if kind in ["blood","blood_disabled"] and pending_effect<36 and t>=.5+pending_effect*.2:
		var point:Vector2=pose+Vector2(28+sin(pending_effect)*24,-40+cos(pending_effect)*24)
		var begin:=Time.get_ticks_usec()
		world.spawn_black_blood(point,Vector2.RIGHT.rotated(pending_effect*.33),pending_effect%9==0,-1)
		event("blood_input",{"index":pending_effect,"cpu_ms":(Time.get_ticks_usec()-begin)/1000.0});pending_effect+=1
	if kind in ["break","door_break"] and pending_effect<4 and t>=1.0+pending_effect*1.0:
		var target:Node3D=null
		for root_node in ([world.door_root] if kind=="door_break" else [world.wall_root,world.door_root]):
			for node in root_node.get_children():
				if not node.has_method("take_damage"):continue
				if node.get("is_shattered")==true or node.get("is_broken")==true:continue
				target=node;break
			if target!=null:break
		if target!=null:
			var label:=String(target.name);var begin:=Time.get_ticks_usec()
			target.take_damage(10000.0,Vector2.RIGHT)
			event("break_input",{"target":label,"cpu_ms":(Time.get_ticks_usec()-begin)/1000.0})
		pending_effect+=1
	if kind=="fire" and pending_effect==0 and t>=1.0:
		var burning:Node=world.floor_root.get_node("BurningEffects")
		var ignited:=0
		for prop in world.furniture_root.get_children():
			if prop.global_position.distance_to(pose)<240 and burning.ignite(prop):ignited+=1
			if ignited>=3:break
		event("fire_input",{"count":ignited});pending_effect+=1

func sample(name:String,index:int,seconds:float,kind:String="idle")->void:
	if seconds_override>0:seconds=seconds_override
	shots=0;own_events.clear();pending_effect=0;stage_totals.clear();stage_max.clear();stage_counts.clear()
	var rows:Array=[];var wall_values:Array=[];var draw_values:Array=[];var calls:Array=[];var gpu:Array=[];var cutout:Array=[]
	sink.begin_window();world.lab_cutout_usec=0;physics_count=0;intervention_usec=0
	started=Time.get_ticks_usec()
	sample_started_unix=Time.get_unix_time_from_system()
	for saved in suspended_enemies:
		var enemy:Node=saved.ref.get_ref()
		if is_instance_valid(enemy):enemy.process_mode=int(saved.mode)
	suspended_enemies.clear()
	var previous:=started;var previous_frame:=Engine.get_process_frames()
	collecting=true
	while Time.get_ticks_usec()-started<seconds*1000000:
		await process_frame
		var now:=Time.get_ticks_usec();var t:float=(now-started)/1000000.0
		var frame_ms:float=(now-previous)/1000.0
		var stages:Dictionary=sink.pop_frame()
		for stage in stages.ms:
			stage_totals[stage]=float(stage_totals.get(stage,0))+float(stages.ms[stage])
			stage_max[stage]=maxf(float(stage_max.get(stage,0)),float(stages.ms[stage]))
			stage_counts[stage]=int(stage_counts.get(stage,0))+int(stages.calls[stage])
		var vp:Viewport=world.get_viewport()
		var draws:int=vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var gpu_ms:float=RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		var cpu_ms:float=RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
		var smoke:Node=world.floor_root.get_node("FireExtinguisherSystem")
		var row:=[previous_frame,Engine.get_process_frames(),t,frame_ms,draw_wall,physics_count,draws,cpu_ms,gpu_ms,world.lab_cutout_usec/1000.0,stages.ms.get("smoke_physics",0),stages.ms.get("smoke_disperse",0),stages.ms.get("smoke_fusion_calculate",0),stages.ms.get("blood_impact_settle_self_process",0),stages.ms.get("bridge_process",0),stages.ms.get("fracture_build",0),int(stages.sink_usec)/1000.0,smoke.cells.size(),smoke.puffs.size(),shots]
		rows.append(row);wall_values.append(frame_ms);draw_values.append(draw_wall);calls.append(draws);gpu.append(gpu_ms);cutout.append(world.lab_cutout_usec/1000.0)
		world.lab_cutout_usec=0;physics_count=0;previous=now;previous_frame=Engine.get_process_frames()
		if batch=="render":
			world.player.global_position=pose+Vector2(sin(t*2.0)*8.0,cos(t*2.0)*6.0)
		apply_workload(kind,t)
	collecting=false;sink.active=false
	world.player.set_meta(&"force_weapon_attack",false)
	var artifact:="%s_%02d_%s"%[batch,index,name]
	var path:=out.path_join(artifact+".csv")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["span_start_frame","span_end_frame","elapsed_s","frame_wall_ms","draw_wall_ms","physics_steps","draws_delayed","world_cpu_ms_delayed","world_gpu_ms_delayed","cutout_ms","smoke_physics_ms","smoke_disperse_ms","smoke_fusion_calculate_ms","blood_settle_self_process_ms","bridge_process_ms","fracture_build_ms","sink_methods_ms","smoke_cells","smoke_puffs","shots"]))
	for row in rows:
		var fields:=PackedStringArray()
		for value in row:fields.append(str(value))
		file.store_csv_line(fields)
	file.close()
	var result:={"name":name,"kind":kind,"index":index,"seconds":seconds,"frame":STATS.stats(wall_values),"draw_wall":STATS.stats(draw_values),"draw_calls":STATS.stats(calls),"gpu_delayed":STATS.stats(gpu),"cutout":STATS.stats(cutout),"stage_total_ms":stage_totals.duplicate(),"stage_max_ms":stage_max.duplicate(),"stage_calls":stage_counts.duplicate(),"event_counts":sink.event_counts.duplicate(),"events":sink.events.duplicate(true),"inputs":own_events.duplicate(true),"shots":shots,"intervention_usec":intervention_usec,"config":lab.configuration(),"signature":world.get_layout_signature(),"raw":path}
	result["sample_started_unix"]=sample_started_unix
	result["sample_finished_unix"]=sample_started_unix+float(wall_values.reduce(func(a,b):return a+b,0.0))/1000.0
	result["preparation"]=preparation.duplicate(true)
	result.config["duration_s"]=seconds
	result.config["workload"]=kind
	results.append(result)
	var report:=FileAccess.open(out.path_join(artifact+".json"),FileAccess.WRITE);report.store_string(JSON.stringify(result,"\t"));report.close()
	print("LAB_ARM ",artifact," ",JSON.stringify(result.frame)," shots=",shots," events=",JSON.stringify(result.event_counts))
	if kind in ["shoot","shoot_smoke","smoke_no_draw","smoke_no_disperse","no_muzzle"]:require(shots>=5,artifact+" actually shot")
	if kind in ["shoot_smoke","smoke_no_draw"]:require(int(sink.event_counts.get("smoke_dispersed",0))>0,artifact+" bullets cleared smoke")
	if kind=="smoke_no_disperse":require(int(sink.event_counts.get("smoke_dispersed",0))==0,artifact+" disperse exclusion worked")
	if kind=="blood":require(float(stage_totals.get("blood_active_init_process",0))>0,artifact+" real blood created")
	if kind=="blood_disabled":require(float(stage_totals.get("blood_active_init_process",0))==0,artifact+" blood excluded")
	if kind in ["break","door_break"]:require(own_events.size()>0,artifact+" targets broken")
	if kind=="fire":require(own_events.size()>0 and own_events[0].data.get("count",0)>0,artifact+" furniture ignited")
	# Readback AFTER all timing and file export. Never included in a measurement.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(artifact+".png"))

func run()->void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		push_error("Requires native GPU and isolated APPDATA");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--batch="):batch=arg.trim_prefix("--batch=")
		if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
		if arg.begins_with("--arms="):requested_arms=arg.trim_prefix("--arms=").split(",")
		if arg.begins_with("--seconds="):seconds_override=float(arg.trim_prefix("--seconds="))
		if arg=="--formal-prewarm":use_formal_prewarm=true
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900,true,false,true).timeout.connect(func():push_error("Ablation watchdog");quit(2))
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720));DisplayServer.window_set_position(Vector2i(-30000,-30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var settings:Node=root.get_node("SettingsManager")
	settings.values["shadow_quality"]="high";settings.values["palette_scheme"]=1
	lab=load(LAB_PATH).instantiate();root.add_child(lab)
	while lab.busy or not lab.ready_world:await process_frame
	sink=SINK.new();root.add_child(sink);PERF._reference=weakref(sink)
	RenderingServer.frame_pre_draw.connect(pre_draw);RenderingServer.frame_post_draw.connect(post_draw)
	if batch=="render":
		var arms:=["baseline","no_shadows","baseline","no_reflections","baseline","no_cutout","baseline","no_palette","baseline","no_tonal","baseline","no_pixels","baseline","no_furniture","baseline","no_enemies","baseline"]
		if not requested_arms.is_empty():arms=Array(requested_arms)
		for i in arms.size():
			await setup(arms[i],true,0 if arms[i]=="no_enemies" else 12)
			await sample(arms[i],i,8.0)
	elif batch=="events":
		var arms:=["idle","shoot","idle","no_muzzle","shoot","smoke","shoot_smoke","smoke_no_disperse","shoot_smoke","smoke_no_draw","shoot_smoke","blood","blood_disabled","blood","break","break","fire","fire"]
		if not requested_arms.is_empty():arms=Array(requested_arms)
		for i in arms.size():
			await setup(arms[i],false,0)
			await sample(arms[i],i,10.0,arms[i])
	elif batch=="combat":
		var arms:=["combat","no_furniture","combat","furniture_frozen","combat","ai_off","combat","special_units","combat"]
		if not requested_arms.is_empty():arms=Array(requested_arms)
		for i in arms.size():
			await setup(arms[i],true,12,arms[i]!="ai_off")
			await sample(arms[i],i,12.0,"special_units" if arms[i]=="special_units" else "combat")
	else:
		await setup("shoot_smoke",false,0)
		await sample("shoot_smoke",0,7.0,"shoot_smoke")
	var file:=FileAccess.open(out.path_join(batch+"_summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"batch":batch,"failures":failed,"results":results,"scope":"Native lab A/B/A. Scoped exclusions, not visual-equivalent optimizations. Frames are aligned process-frame intervals. Marker parents/children overlap; do not add them. Viewport queries delayed. Setup and image/disk IO outside samples. In-process rebuild is not cold driver-cache reset."},"\t"));file.close()
	RenderingServer.frame_pre_draw.disconnect(pre_draw);RenderingServer.frame_post_draw.disconnect(post_draw)
	PERF._reference=null;lab.free();sink.free();await process_frame
	quit(0 if failed.is_empty() else 1)
