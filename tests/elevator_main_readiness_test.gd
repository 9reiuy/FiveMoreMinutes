extends SceneTree
var main:Node
var failures:Array[String]=[]
var checks:=0
var capture_count:=0
var last_phase:=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=4)->void:
	for frame in n:await process_frame
func settle()->void:
	while main.transition_running:await process_frame
	await frames()
func enter(source:Node)->void:
	source.player.global_position=source.elevator_floor_door.get_corridor_approach_position_2d()
	source.player.set_meta(&"aim_direction_override",Vector2.UP)
	await frames(8)
	source._update_camera_and_projection(0.0)
	Input.action_press("pickup_weapon");await frames(2);Input.action_release("pickup_weapon")
	while is_instance_valid(source) and (source.elevator_transition_in_progress or main.transition_running):await process_frame
func watch()->void:
	if not is_instance_valid(main):return
	var active:Node=main._supported_dream_world
	if not is_instance_valid(active):return
	var phase:="reception"
	if active.has_method("is_loading_render_ready"):
		phase=String(active.transition_phase)
		if phase=="EXITING" and not active.is_loading_render_ready():check(false,"Main exit never precedes readiness")
	elif active.entry_ride_started_usec>0:phase="loading_cab"
	if phase!=last_phase and DisplayServer.get_name()!="headless":
		last_phase=phase;capture_count+=1
		root.get_texture().get_image().save_png("res://.runtime/main_%02d_%s.png"%[capture_count,phase])
func run()->void:
	create_timer(180,true,false,true).timeout.connect(func():push_error("Main test watchdog");quit(2))
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):quit(2);return
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_position(Vector2i(-30000,-30000))
	AudioServer.set_bus_mute(0,true);Engine.max_fps=60
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await settle()
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one")
	main._show_reception("basic");await settle()
	var source:Node=main._supported_dream_world
	main.set_meta(&"test_fail_reception_generation",true)
	await enter(source)
	check(main._supported_dream_world==source and source.player.movement_enabled and not source.elevator_transition_in_progress,"Main E entry failure restores usable reception")
	check(source.entry_cab==null and not paused,"Failure releases cab and pause")
	main.remove_meta(&"test_fail_reception_generation")
	process_frame.connect(watch)
	await enter(source);await settle()
	var world:Node=main._supported_dream_world
	check(world!=source and world.has_method("is_loading_render_ready"),"Main actual E retry reaches prepared floor")
	while world.floor_transition_in_progress:await process_frame
	check(world.is_loading_render_ready(),"Main retains current rendered receipt")
	check(world.last_firearm_render_preparation.render_verified,"Main native prewarm actually rendered")
	check(world.player.movement_enabled and world.player.attacking_enabled and world.player_has_left_elevator_cab,"Main arrival restores input")
	var journey:Dictionary=main.get_meta(&"last_reception_journey",{})
	check(journey.get("fixed_ride_seconds",-1)==0.0 and journey.get("render_ready",false),"No fixed duration on reception route")
	check(not main.loading_overlay.visible and not paused,"No stuck fullscreen loading or pause")
	check(world.get_world_3d()!=root.world_3d,"Reception staging remains isolated")
	process_frame.disconnect(watch)
	var result:Dictionary={"checks":checks,"failures":failures,"journey":journey,"preparation":world.last_firearm_render_preparation}
	var file:=FileAccess.open("res://.runtime/main_readiness.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ELEVATOR_MAIN_READINESS ",JSON.stringify(result))
	main.free();await frames();quit(0 if failures.is_empty() else 1)
