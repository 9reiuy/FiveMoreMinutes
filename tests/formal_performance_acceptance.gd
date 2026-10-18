extends "res://tests/random_combat_perf.gd"
## Main-entry soak. Test-only invulnerability, relocation and badge collection
## keep a repeatable sample running; enemies, damage, weapons and AI are stock.
var main: Node
var checks := 0
var phase_samples: Dictionary = {"gameplay": [], "transition": [], "cab": []}
var load_reports: Array = []
var exit_reports: Array = []
var transitions_completed := 0
var duration_seconds := 600
var phase_counts: Dictionary = {}
var encounter_loads: Array=[]
var initial_black_start:=0
var initial_black_last:=0
var initial_black_end:=0
var collect_initial_black:=true
var cab_start_usec:=0
var cab_start_position:=Vector2.ZERO
var cab_travel:=0.0
var cab_records: Array=[]
var handoff_frames: Array=[]

func initial_draw() -> void:
	if not collect_initial_black or not is_instance_valid(main): return
	var covered: bool=main.loading_overlay.visible and main.fade.color.a>=0.99
	if is_instance_valid(main.transition_director):
		covered=main.loading_overlay.visible and main.transition_director.current_state==TransitionDirector.State.WAITING_FOR_SCENE and float(main.transition_director.material_instance.get_shader_parameter("progress"))>=0.99
	var now:=Time.get_ticks_usec()
	if covered:
		if initial_black_start==0: initial_black_start=now
		initial_black_last=now
	elif initial_black_start>0 and initial_black_end==0:
		initial_black_end=now

func finish_encounter() -> void:
	var valid: bool=int(shots.player)>=10 and int(shots.enemy)>=10 and shooters.size()>=2
	encounter_loads.append({"floor":world.floor_index,"shots":shots.duplicate(),"enemy_shooters":shooters.size(),"valid":valid})
	check(valid,"Each floor encounter has >=10 shots per side and >=2 enemy shooters")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func loaded(report: Dictionary) -> void:
	load_reports.append(report.duplicate(true))
	if report.get("rolled_back", false): return
	check(not report.get("cancelled",true), "Loading completed")
	check(float(report.get("covered_elapsed_ms", INF)) <= 1500.0, "Regular loading black <= 1500 ms")

func exited(report: Dictionary) -> void:
	exit_reports.append(report.duplicate(true))
	check(float(report.get("covered_elapsed_ms", INF)) <= 150.0, "Exit cover <= 150 ms")

func choose_encounter() -> bool:
	var counts: Dictionary = {}
	var firearms: Dictionary = {}
	for enemy in world.enemy_root.get_children():
		if bool(enemy.get("dead")): continue
		var room_id := int(enemy.get_meta(&"dream_room_id",-1))
		counts[room_id] = int(counts.get(room_id,0)) + 1
		if String(enemy.held_weapon_id) not in ["lucille","books",""]:
			firearms[room_id] = int(firearms.get(room_id,0)) + 1
	var best := -1
	for room_id in counts:
		if best < 0 or int(firearms.get(room_id,0))*100+int(counts[room_id]) > int(firearms.get(best,0))*100+int(counts[best]): best=room_id
	for enemy in world.enemy_root.get_children():
		if int(enemy.get_meta(&"dream_room_id",-1)) != best or bool(enemy.get("dead")): continue
		for offset in [Vector2(96,0),Vector2(-96,0),Vector2(0,96),Vector2(0,-96),Vector2(64,64),Vector2(-64,64)]:
			var target: Vector2=enemy.global_position+offset
			if not world._content_position_is_clear(target,12.0): continue
			world.player.global_position=target
			world.player.invulnerability_left=3600.0
			world.player.equip_weapon("assault_rifle",world.config)
			bounded_route.clear()
			for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(1,-1).normalized()]:
				var clear:=true
				for step in [-32,-16,0,16,32]: clear=clear and world._content_position_is_clear(target+direction*float(step),12.0)
				if clear: bounded_route.assign([target-direction*32.0,target+direction*32.0]); break
			if bounded_route.is_empty(): continue
			var aim: Vector2=Vector2.ZERO
			var wall_found := false
			var nearest := INF
			for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
				var query:=PhysicsRayQueryParameters2D.create(target,target+direction*2048.0,world.WORLD_WALL_LAYER)
				var hit: Dictionary=world.player.get_world_2d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or not hit.collider.has_meta(&"generated_wall_edge"): continue
				var wall_distance: float=target.distance_to(hit.position)
				if wall_distance<nearest: nearest=wall_distance; aim=hit.position+direction*8.0; wall_found=true
			if not wall_found: continue
			world.player.set_meta(&"presentation_pointer_position",func()->Vector2:return world.camera_3d.unproject_position(world.to_global(Vector3(aim.x/32.0,.8,aim.y/32.0))))
			world.player.set_meta(&"force_weapon_attack",true)
			return true
	return false

func release_input() -> void:
	for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
	if is_instance_valid(world.player): world.player.remove_meta(&"force_weapon_attack")

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Requires actual GPU output"); quit(2); return
	AudioServer.set_bus_mute(0,true)
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	else: root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--duration="): duration_seconds=maxi(1,int(argument.trim_prefix("--duration=")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir.path_join("camera")))
	root.add_child(preload("res://tests/support/render_progress_watchdog.gd").new())
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	RenderingServer.frame_post_draw.connect(initial_draw)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120)
	var initial_start := Time.get_ticks_usec()
	main._show_dream("basic")
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if world==null and is_instance_valid(main._supported_dream_world):
			world=main._supported_dream_world; world.persist_profile=false
		if world!=null and not main.transition_running: break
	var initial_ms := float(Time.get_ticks_usec()-initial_start)/1000.0
	print("FORMAL_INITIAL_LOADING_MS ",initial_ms)
	collect_initial_black=false
	RenderingServer.frame_post_draw.disconnect(initial_draw)
	var initial_black_ms:=float(initial_black_end-initial_black_start)/1000.0
	check(initial_black_start>0 and initial_black_end>initial_black_start,"Observed initial fully covered draw interval")
	check(initial_black_ms<=2000.0,"Initial black loading <= 2000 ms")
	check(world!=null and not main.transition_running,"Main entry completed")
	if world==null: quit(1); return
	deadline=Time.get_ticks_msec()+15000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	world.floor_loading_render_preparation_finished.connect(loaded)
	world.floor_exit_render_preparation_finished.connect(exited)
	world.world_effects_root.child_entered_tree.connect(count_projectile)
	check(choose_encounter(),"Initial natural enemy encounter found")
	var start := Time.get_ticks_usec()
	var previous := start
	var next_transition := float(duration_seconds)/4.0
	var last_floor: int=world.floor_index
	var distance := 0.0
	var previous_position: Vector2=world.player.global_position
	var previous_phase:=""
	var encounter_open:=true
	while float(Time.get_ticks_usec()-start)/1000000.0<float(duration_seconds):
		var seconds := float(Time.get_ticks_usec()-start)/1000000.0
		if not world.floor_transition_in_progress:
			if world.floor_index!=last_floor:
				transitions_completed+=1; last_floor=world.floor_index
				check(choose_encounter(),"Natural encounter on new floor")
				shots={"player":0,"enemy":0}; shooters.clear(); encounter_open=true
				previous_position=world.player.global_position; previous_phase=""
				if not world.world_effects_root.child_entered_tree.is_connected(count_projectile): world.world_effects_root.child_entered_tree.connect(count_projectile)
			if transitions_completed<3 and seconds>=next_transition:
				finish_encounter(); encounter_open=false
				release_input(); world.collect_employee_badge(); world._begin_elevator_entry_transition()
				next_transition+=float(duration_seconds)/4.0
			else: drive(seconds)
		else:
			release_input()
			if cab_start_usec>0 and world.transition_phase==&"CAB_RIDE" and not paused:
				var cab_seconds:=float(Time.get_ticks_usec()-cab_start_usec)/1000000.0
				if cab_seconds<0.15: Input.action_press("move_right")
				elif cab_seconds>=0.2 and cab_seconds<0.35: Input.action_press("move_up")
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var phase := "gameplay"
		if world.floor_transition_in_progress:
			phase="cab" if world.transition_phase==&"CAB_RIDE" and not paused and not root.has_node("ElevatorLoadingCover") else "transition"
		if phase=="cab":
			if cab_start_usec==0: cab_start_usec=now; cab_start_position=world.player.global_position; cab_travel=0.0
			cab_travel=maxf(cab_travel,cab_start_position.distance_to(world.player.global_position))
		elif cab_start_usec>0:
			var visible_seconds:=float(now-cab_start_usec)/1000000.0
			cab_records.append({"visible_seconds":visible_seconds,"travel":cab_travel})
			check(visible_seconds>=2.99,"Cab visible at least three seconds")
			check(cab_travel>=12.0,"Real input moves player in cab")
			cab_start_usec=0
		# Black loading has separate time targets, exclude it from frame budgets.
		var eligible: bool=not paused and not root.has_node("FloorExitRenderPreparationCover") and not root.has_node("ElevatorLoadingCover")
		var same_phase: bool=previous_phase==phase
		if eligible and previous_phase==phase:
			phase_samples[phase].append(float(now-previous)/1000.0)
		elif eligible:
			var boundary_ms:=float(now-previous)/1000.0
			handoff_frames.append({"elapsed_ms":boundary_ms,"from":previous_phase,"to":phase,"floor":world.floor_index,"seconds":float(now-start)/1000000.0,"semantics":"display interval at phase/cover handoff; separate from steady phase budget"})
			check(boundary_ms<=33.3,"Visible phase handoff <= 33.3 ms")
		previous_phase=phase if eligible else ""
		phase_counts[String(world.transition_phase)]=int(phase_counts.get(String(world.transition_phase),0))+1
		previous=now
		if eligible and same_phase and phase=="gameplay": distance+=previous_position.distance_to(world.player.global_position)
		previous_position=world.player.global_position
	release_input()
	if encounter_open: finish_encounter()
	check(duration_seconds>=600,"Full soak duration >= 600 seconds")
	check(transitions_completed>=3,"At least three full transitions")
	root.get_texture().get_image().save_png(artifact_dir.path_join("camera/formal_soak.png"))
	var budgets: Dictionary={}
	for phase in phase_samples:
		var samples: Array=phase_samples[phase]
		var good:=0
		for value in samples:
			if float(value)<=18.0: good+=1
		samples.sort()
		var ratio:=float(good)/maxi(samples.size(),1)
		var maximum: float=samples.back() if not samples.is_empty() else INF
		budgets[phase]={"frames":samples.size(),"ratio_le18ms":ratio,"max_ms":maximum}
		check(ratio>=0.99 and maximum<=33.3,"Frame budget "+phase)
	# Pause is measured outside the continuous sample.
	main._open_pause_menu(); await process_frame
	check(paused and main.pause_menu.is_open(),"Pause opens")
	var stopped_position: Vector2=world.player.global_position
	for frame in 8: await process_frame
	check(world.player.global_position==stopped_position,"Pause freezes player")
	main._resume_from_pause(); await process_frame
	check(not paused and not main.pause_menu.is_open(),"Resume restores control")
	var old_cells: Dictionary=world.floor_cells.duplicate(true)
	var old_floor: int=world.floor_index
	var old_attempts: int=world.max_layout_attempts
	world.max_layout_attempts=0; world.collect_employee_badge(); world._begin_elevator_entry_transition()
	deadline=Time.get_ticks_msec()+30000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	check(world.floor_index==old_floor and world.floor_cells==old_cells and not paused and world.player.movement_enabled,"Forced generation failure rolls back and restores control")
	world.max_layout_attempts=old_attempts
	var world_ref: WeakRef = weakref(world)
	main._open_pause_menu(); main._exit_to_main_menu_from_pause()
	deadline=Time.get_ticks_msec()+15000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	for frame in 4: await process_frame
	check(not paused and not is_instance_valid(world_ref.get_ref()),"Exit releases world and pause")
	var result: Dictionary={"checks":checks,"failures":failures,"seconds":duration_seconds,"transitions":transitions_completed,"main_transition_total_ms":initial_ms,"initial_black_ms":initial_black_ms,"initial_black_last_draw_usec":initial_black_last,"loads":load_reports,"exits":exit_reports,"budgets":budgets,"encounters":encounter_loads,"cab_records":cab_records,"gameplay_distance_excluding_encounter_relocations":distance,"phase_boundary_frames":handoff_frames,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"medium_hardware_status":"pending physical machine","fixture_assists":["invulnerability","encounter relocation","badge collection","fixed firing aim"]}
	print("FORMAL_PERFORMANCE_ACCEPTANCE ",JSON.stringify(result))
	var output: FileAccess=FileAccess.open(artifact_dir.path_join("formal_acceptance.json"),FileAccess.WRITE)
	if output!=null: output.store_string(JSON.stringify(result,"\t"))
	main.queue_free(); await process_frame
	quit(1 if failures>0 else 0)

