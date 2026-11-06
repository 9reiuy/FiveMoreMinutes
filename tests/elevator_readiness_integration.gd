extends SceneTree
const WORLD=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var checks:=0
var failures:Array[String]=[]
var phases:Dictionary={}
var world:Node3D
var done:=false
var reports:Array=[]
var output_dir:="res://.runtime/elevator_readiness_validation"
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func frame_watch()->void:
	if not is_instance_valid(world):return
	var phase:String=world.transition_phase
	if not phases.has(phase):phases[phase]=Time.get_ticks_msec()
	if phase=="PREPARING_FLOOR" and not world.is_loading_render_ready():
		if world.elevator_floor_door.doors_open or world.player.movement_enabled:
			check(false,"Door/control cannot release during preparation")
func start_entry()->void:
	await world._perform_game_start_cab_exit();done=true
func reject_receipt(report:Dictionary)->void:
	# Test a failed render result after successful generation, not a timed skip.
	report["ready"]=false;report["cancelled"]=true
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output_dir=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	create_timer(180,true,false,true).timeout.connect(func():push_error("Test watchdog");quit(2))
	AudioServer.set_bus_mute(0,true)
	var native:=DisplayServer.get_name()!="headless"
	if native:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_position(Vector2i(-30000,-30000))
	Engine.max_fps=60
	world=WORLD.instantiate();world.generate_on_ready=false;world.spawn_content=native;world.persist_profile=false;world.enable_game_start_cab_exit=false
	var display:Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world;display.preview_mode=false;root.add_child(display)
	check(world.regenerate(41001),"Initial floor generated")
	# Do not simulate combat during this lifecycle test.
	for node in world.enemy_root.get_children():node.process_mode=Node.PROCESS_MODE_DISABLED
	process_frame.connect(frame_watch)
	check(not world.finish_loading_render_preparation(),"Cannot finish loading without a receipt")
	start_entry()
	while not done:await process_frame
	check(world.is_loading_render_ready(),"Direct-scene startup prepares before exit")
	check(world.player_has_left_elevator_cab and world.player.movement_enabled and world.player.attacking_enabled,"Startup releases all gameplay controls")
	check(not paused and not root.has_node("ElevatorLoadingCover"),"Startup releases cover and pause")
	reports.append(world.last_firearm_render_preparation.duplicate(true))
	if native:
		await RenderingServer.frame_post_draw
		display.world_viewport.get_texture().get_image().save_png(output_dir+"/arrival_first.png")
	world.has_floor_badge=true
	world.player.global_position=world.elevator_floor_door.get_corridor_approach_position_2d()
	world.floor_transition_in_progress=true
	world.transition_generation_token+=1
	world.player.movement_enabled=false;world.player.attacking_enabled=false;world.player.dash_enabled=false
	var token:int=world.transition_generation_token
	check(not world.is_loading_render_ready(),"Previous journey receipt cannot release next floor")
	# Real staged generation/loading/exit, without test skip flags.
	await world._transition_to_independent_cab(token)
	while world.floor_transition_in_progress:await process_frame
	check(world.floor_index==1 and world.is_loading_render_ready(),"Second floor has its own completed receipt")
	check(world.active_transition_cab==null and world._floor_rollback_stash==null,"No cab or stale floor remains")
	check(world.player.movement_enabled and world.player.attacking_enabled and world.player.dash_enabled,"Next-floor controls restored")
	check(not world.has_floor_badge and world.player_has_left_elevator_cab,"Badge consumed only on completed arrival")
	check(not phases.has("CAB_RIDE"),"No mandatory post-load ride phase")
	check(not paused and not root.has_node("ElevatorLoadingCover"),"Next-floor cover and pause released")
	reports.append(world.last_firearm_render_preparation.duplicate(true))
	if native:
		await RenderingServer.frame_post_draw
		display.world_viewport.get_texture().get_image().save_png(output_dir+"/arrival_second.png")
		for report:Dictionary in reports:
			check(report.render_verified and report.world_readback_bytes>0 and report.capture_pools.batches>0,"Real GPU and pools complete on every floor")
	var old_cells:Dictionary=world.floor_cells.duplicate()
	world.has_floor_badge=true;world.floor_transition_in_progress=true;world.transition_generation_token+=1
	world.player.movement_enabled=false;world.player.attacking_enabled=false
	world.firearm_render_preparation_finished.connect(reject_receipt,CONNECT_ONE_SHOT)
	await world._transition_to_independent_cab(world.transition_generation_token)
	check(world.floor_index==1 and world.floor_cells==old_cells,"Failed render receipt restores previous floor")
	check(world.has_floor_badge and world.player.movement_enabled and not world.floor_transition_in_progress,"Preparation failure keeps badge and permits retry")
	check(not paused and not root.has_node("ElevatorLoadingCover") and world.active_transition_cab==null,"Preparation failure releases cover/cab/pause")
	var output:Dictionary={"checks":checks,"failures":failures,"phases":phases,"reports":reports,"native_rendering":native}
	var file:=FileAccess.open(output_dir+"/elevator_integration_%s.json"%("gpu" if native else "logic"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"));file.close()
	print("ELEVATOR_READINESS_INTEGRATION ",JSON.stringify(output))
	process_frame.disconnect(frame_watch)
	display.free();await process_frame
	quit(0 if failures.is_empty() else 1)
