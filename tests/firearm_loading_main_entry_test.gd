extends SceneTree
## Rendered normal Main entry, not a headless FPS assertion.
var checks:=0
var failures:=0
var finished:=false
var start_state: Dictionary={}
var main: Node
var world: Node3D
var shadow_trace_enabled:=false
var previous_draw_usec:=0
var shadow_flow_key:=""
var cab_frames: Array[float]=[]
var cab_started:=0
var cab_movement_start:=Vector2.ZERO
var cab_travel:=0.0
var cab_enemy_state: Array=[]
var cab_skip_samples:=0
var cab_capture_done:=false
var black_capture_done:=false
var last_draw_was_cab:=false
var cab_floor_unchanged:=true
var cab_last_draw:=0
var cab_ended:=0
func shadow_flow_state() -> Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(world.shadow_manager): return {}
	var manager: Node=world.shadow_manager
	var enabled: Array=[]; var nonzero: Array=[]
	for light in manager.active:
		if not is_instance_valid(light): continue
		if light.shadow_enabled: enabled.append(light.get_instance_id())
		if light.shadow_opacity>0.0: nonzero.append(light.get_instance_id())
	enabled.sort(); nonzero.sort()
	return {"paused":paused,"main_transition":main.transition_running,"floor_transition":world.floor_transition_in_progress,"phase":world.transition_phase,"overlay":main.loading_overlay.visible,"exit_cover":root.has_node("FloorExitRenderPreparationCover"),"floor_visible":world.floor_root.visible,"shadow_suspended":manager.suspended,"selected":manager.selected.size(),"enabled":enabled,"nonzero":nonzero}
func on_floor_exit_prepared(report: Dictionary) -> void:
	check(not report.cancelled and report.cover_released and report.pause_restored,"Cross-floor preparation releases cover and pause")
	check(report.get("prewarmed",false) and report.temporary_sources==0,"Exit reuses covered preparation without another heavy warmup")
	print("MAIN_FLOOR_EXIT_PREPARATION ",JSON.stringify(report))
func on_floor_loaded(report: Dictionary) -> void:
	if report.get("rolled_back",false):
		check(report.cancelled and report.cover_released and report.pause_restored,"Rendered failed loading releases cover and pause after rollback")
		return
	check(not report.cancelled and report.cover_released and report.pause_restored,"Black loading releases cover and pause")
	check(report.ready_before_ride and world._next_floor_render_ready,"Floor ready before player can move in cab")
	check(report.render_preparation.temporary_sources==12,"Covered preparation cleans all twelve temporary sources")
	check(world._floor_rollback_stash==null,"Old floor disposed before visible ride")
	print("MAIN_FLOOR_LOADING_PREPARATION ",JSON.stringify(report))
func enemy_snapshot() -> Array:
	var state: Array=[]
	for enemy in world.enemy_root.get_children(): state.append([enemy.global_position,enemy.current_health,enemy.perception_update_left])
	return state
func record_cab_frame(now: int,frame_ms: float) -> void:
	if not is_instance_valid(world): return
	var cab_visible: bool=world.transition_phase==&"CAB_RIDE" and not paused and not root.has_node("ElevatorLoadingCover")
	if not cab_visible:
		if last_draw_was_cab: cab_ended=now
		last_draw_was_cab=false
		var loading_cover: Node=root.get_node_or_null("ElevatorLoadingCover")
		if not black_capture_done and loading_cover!=null and loading_cover.animation_phase==&"hold":
			var picture:=root.get_texture().get_image(); picture.convert(Image.FORMAT_RGBA8)
			var bytes:=picture.get_data(); var black:=true
			for pixel in range(0,bytes.size(),4):
				if bytes[pixel]!=0 or bytes[pixel+1]!=0 or bytes[pixel+2]!=0 or bytes[pixel+3]!=255: black=false; break
			check(black,"Actual output is opaque black during generation")
			var escape:=InputEventAction.new(); escape.action=&"ui_cancel"; escape.pressed=true
			root.push_input(escape)
			check(paused and not main.get_node("PauseMenu").is_open(),"Escape cannot insert a hidden pause menu during black loading")
			escape.pressed=false; root.push_input(escape)
			picture.save_png("res://.runtime/elevator_loading_20261012/black_loading.png")
			black_capture_done=true
		return
	if cab_started==0:
		cab_started=now; cab_movement_start=world.player.global_position
		cab_enemy_state=enemy_snapshot()
		Input.action_press("move_right")
	var elapsed: float=(now-cab_started)/1000000.0
	cab_last_draw=now
	cab_floor_unchanged=cab_floor_unchanged and enemy_snapshot()==cab_enemy_state
	if elapsed>.15: Input.action_release("move_right")
	if elapsed>.2 and elapsed<.35: Input.action_press("move_up")
	else: Input.action_release("move_up")
	cab_travel=maxf(cab_travel,world.player.global_position.distance_to(cab_movement_start))
	if last_draw_was_cab and cab_skip_samples==0: cab_frames.append(frame_ms)
	cab_skip_samples=maxi(cab_skip_samples-1,0)
	last_draw_was_cab=true
	if elapsed>.5 and not cab_capture_done:
		root.get_texture().get_image().save_png("res://.runtime/elevator_loading_20261012/ready_cab_%d.png" % world.floor_index)
		cab_capture_done=true; cab_skip_samples=2
func on_trace_draw() -> void:
	var now:=Time.get_ticks_usec()
	var elapsed_ms: float=(now-previous_draw_usec)/1000.0 if previous_draw_usec>0 else 0.0
	previous_draw_usec=now
	record_cab_frame(now,elapsed_ms)
	var state:=shadow_flow_state()
	if state.is_empty(): return
	var key:=JSON.stringify(state)
	if key!=shadow_flow_key or elapsed_ms>=40.0:
		print("MAIN_SHADOW_FLOW ",JSON.stringify({"frame_ms":elapsed_ms,"state":state,"position":str(world.player.global_position),"camera":str(world.camera_3d.global_position)}))
	shadow_flow_key=key
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func snapshot() -> Dictionary:
	var enemies: Array=[]
	for enemy in world.enemy_root.get_children():
		enemies.append([enemy.global_position,enemy.current_health,enemy.perception_update_left])
	return {"position":world.player.global_position,"ammo":world.player.ammo_states.duplicate(true),"rng":world._content_rng.state,"seconds":world.run_interface.get("seconds"),"enemies":enemies,"sources":world.world_effects_root.get_child_count()}
func on_prepared(report: Dictionary) -> void:
	finished=true
	check(paused,"Gameplay frozen until preparation callback")
	var covered: bool=main.fade.color.a>=.99
	if is_instance_valid(main.transition_director):
		covered=main.transition_director.current_state==TransitionDirector.State.WAITING_FOR_SCENE and float(main.transition_director.material_instance.get_shader_parameter("progress"))>=.99
	check(main.loading_overlay.visible and covered,"Actual loading overlay covers flash")
	check(snapshot()==start_state,"Player, enemy, ammo, RNG, run clock and source count unchanged")
	check(not world.floor_transition_in_progress,"Initial elevator exit deferred until prepared")
	check(not report.get("cancelled",true),"Actual GPU preparation completed")
	if not "--baseline" in OS.get_cmdline_user_args():
		check(report.destruction.viewport_released and report.destruction.states==16,"Normal Main entry prepares destruction rendering")
		check(root.find_children("*","SubViewport",true,false).all(func(viewport: Node)->bool: return not viewport.has_meta(&"destruction_render_preparation")),"No private preparation viewport at control handoff")
	check(int(report.get("temporary_sources",0))==(0 if "--baseline" in OS.get_cmdline_user_args() else 12),"Exact owned temporary sources cleaned (four impacts, projectile, three muzzles, shell, two hits and native smoke)")
	var smoke: Node=world.floor_root.get_node("FootstepSmoke")
	check(smoke.get_child_count()==72 and smoke.puffs.is_empty(),"Loading removes temporary native smoke without consuming pool slots")
	for light in world.night_lighting.muzzle_lights: check(not light.visible and not light.shadow_enabled,"No muzzle pulse retained")
	check(world.projectile_light_assignments.is_empty(),"No temporary projectile light assignment")
	print("MAIN_FIREARM_PREPARATION ",JSON.stringify(report))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	if "--background-gpu" in OS.get_cmdline_user_args():
		process_frame.connect(func()->void:
			if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
		preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	if "--output-1080" in OS.get_cmdline_user_args():
		if not "--background-gpu" in OS.get_cmdline_user_args(): root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1920,1080)
	shadow_trace_enabled="--shadow-flow-trace" in OS.get_cmdline_user_args()
	if shadow_trace_enabled or "--cross-floor-shadow-trace" in OS.get_cmdline_user_args(): RenderingServer.frame_post_draw.connect(on_trace_draw)
	root.add_child(preload("res://tests/support/render_progress_watchdog.gd").new())
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120)
	var started:=Time.get_ticks_usec()
	main._show_dream("basic")
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if world==null and is_instance_valid(main._supported_dream_world):
			world=main._supported_dream_world
			world.persist_profile=false
			world.set_meta(&"test_skip_firearm_render_preparation","--baseline" in OS.get_cmdline_user_args())
			start_state=snapshot()
			world.firearm_render_preparation_finished.connect(on_prepared,CONNECT_ONE_SHOT)
		if world!=null and not main.transition_running: break
	check(finished,"Formal Main invoked preparation")
	check(not paused and not main.transition_running,"Loading returns control and pause state")
	check(world!=null and not world.loading_render_preparation_pending,"No pending load flag")
	print("MAIN_FIREARM_LOADING_MS ",float(Time.get_ticks_usec()-started)/1000.0)
	deadline=Time.get_ticks_msec()+10000
	while is_instance_valid(world) and world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	check(is_instance_valid(world) and not world.floor_transition_in_progress,"Initial elevator exit completes")
	if "--cross-floor-shadow-trace" in OS.get_cmdline_user_args() and is_instance_valid(world):
		var baseline_exit: bool="--baseline-floor-exit" in OS.get_cmdline_user_args()
		world.set_meta(&"test_skip_floor_exit_render_preparation",baseline_exit)
		world.set_meta(&"test_trace_floor_generation","--generation-stage-trace" in OS.get_cmdline_user_args())
		world.set_meta(&"test_sync_floor_capture_prewarm","--sync-floor-pools" in OS.get_cmdline_user_args())
		if not baseline_exit:
			world.floor_exit_render_preparation_finished.connect(on_floor_exit_prepared)
			world.floor_loading_render_preparation_finished.connect(on_floor_loaded)
		world.player.invulnerability_left=999.0
		for expected_floor in [1,2]:
			cab_started=0; cab_last_draw=0; cab_ended=0; cab_travel=0.0; cab_frames.clear(); cab_capture_done=false; cab_floor_unchanged=true
			world.collect_employee_badge()
			world._begin_elevator_entry_transition()
			deadline=Time.get_ticks_msec()+40000
			while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
			Input.action_release("move_right"); Input.action_release("move_up")
			check(world.floor_index==expected_floor and not world.floor_transition_in_progress,"Actual cross-floor transition completes")
			# Movie Maker advances fixed logic steps while input holds use wall
			# time. It is a visual capture, never the movement/performance baseline.
			var movement_minimum: float=5.0 if "--record-movie" in OS.get_cmdline_user_args() else 12.0
			check(cab_frames.size()>30 and cab_travel>movement_minimum,"Real input moves player in ready cab without sticking")
			check(cab_floor_unchanged,"Ready floor AI and physics do not update during cab")
			# The last cab frame remains displayed until the next (black) draw.
			# Last-cab minus first-cab timestamps alone omit that final interval.
			if not "--record-movie" in OS.get_cmdline_user_args():
				check(cab_ended-cab_started>=2990000,"Visible ready cab lasts at least three seconds")
			check(world._cab_suspended_floor_state.is_empty(),"Floor runtime restored after arrival")
			check(world.player_depth_bridge.actor_sprite.is_visible_in_tree(),"Persistent player display remains visible after cab exit")
			cab_frames.sort()
			if not cab_frames.is_empty():
				print("READY_CAB_FRAME_TIME ",JSON.stringify({"floor":expected_floor,"samples":cab_frames.size(),"median_ms":cab_frames[cab_frames.size()/2],"p95_ms":cab_frames[int(cab_frames.size()*.95)],"max_ms":cab_frames.back(),"visible_seconds":(cab_ended-cab_started)/1000000.0,"sample_window_seconds":(cab_last_draw-cab_started)/1000000.0,"movement_distance":cab_travel,"gpu":"RTX 5070 Ti","capture_samples_excluded":2,"movie_recording":"--record-movie" in OS.get_cmdline_user_args()}))
			print("MAIN_SHADOW_CROSS_FLOOR ",JSON.stringify({"floor":world.floor_index,"state":shadow_flow_state()}))
			if "--capture-floor-exit" in OS.get_cmdline_user_args():
				for frame in 8: await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/elevator_loading_20261012/floor_exit_%d.png" % expected_floor)
			if world.floor_index!=expected_floor: break
		if "--force-loading-failure" in OS.get_cmdline_user_args():
			var old_cells: Dictionary=world.floor_cells.duplicate()
			var old_floor: int=world.floor_index
			var old_enemy_count: int=world.enemy_root.get_child_count()
			var old_furniture_count: int=world.furniture_root.get_child_count()
			var marker:=Node2D.new(); world.world_effects_root.add_child(marker)
			var old_attempts: int=world.max_layout_attempts
			world.max_layout_attempts=0
			world.collect_employee_badge(); world._begin_elevator_entry_transition()
			deadline=Time.get_ticks_msec()+20000
			while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
			for frame in 4: await RenderingServer.frame_post_draw
			check(world.floor_index==old_floor and world.floor_cells==old_cells,"Rendered generation failure restores old layout")
			check(is_instance_valid(marker) and marker.get_parent()==world.world_effects_root,"Rendered rollback keeps old floor effects")
			check(world.enemy_root.get_child_count()==old_enemy_count and world.furniture_root.get_child_count()==old_furniture_count,"Rendered rollback does not duplicate/drop enemies or furniture")
			check(not paused and not world.floor_transition_in_progress and world.player.movement_enabled and world.active_transition_cab==null,"Rendered failed loading returns player control without auto-retry")
			world.max_layout_attempts=old_attempts
	if is_instance_valid(world):
		paused=true
		var origin: Vector2=world.player.get_projectile_origin()
		world.player.equip_weapon("assault_rifle",world.config)
		world._update_camera_and_actor_projection(0.0)
		for frame in 4: await RenderingServer.frame_post_draw
		var shot_started:=Time.get_ticks_usec()
		world.player.assault_rifle_weapon._fire(Vector2.RIGHT,false)
		await RenderingServer.frame_post_draw
		print("MAIN_FIREARM_FIRST_SHOT_MS ",float(Time.get_ticks_usec()-shot_started)/1000.0)
		check(world.world_effects_root.get_child_count()>=3,"Actual stock shot still creates its visuals")
	if RenderingServer.frame_post_draw.is_connected(on_trace_draw): RenderingServer.frame_post_draw.disconnect(on_trace_draw)
	paused=false; main.queue_free()
	for frame in 4: await process_frame
	print("MAIN_FIREARM_LOADING_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
