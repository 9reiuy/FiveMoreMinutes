extends SceneTree
## Real formal Main, native rendering, isolated userdata provided by runner.
## This is entry/lifecycle regression evidence, not a stable-60-FPS benchmark.
const WORLD=preload("res://scripts/dream/office_skeleton_world_base.gd")
var world:Node3D
var directory:=""
var checks:=0
var failures:Array=[]
var floor_loading_report:Dictionary={}

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)

func added(node:Node)->void:
	if node.get_script()==WORLD:
		world=node;world.seed=2824175271;world.base_floor_seed=2824175271;world.persist_profile=false
		world.floor_loading_render_preparation_finished.connect(func(report:Dictionary)->void:floor_loading_report=report.duplicate(true))

func _initialize()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):directory=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")

func inspect_preparation(report:Dictionary,token:int,label:String)->void:
	check(not report.is_empty() and not report.get("cancelled",false),label+" preparation completed")
	var destruction:Dictionary=report.get("destruction",{})
	check(destruction.get("viewport_released",false),label+" private viewport released")
	check(destruction.get("states",0)==16,label+" existing 16 light states retained")
	var warm:Dictionary=destruction.get("room_firstuse",{})
	check(warm.get("floor_token",-1)==token,label+" samples belong to current floor")
	check(int(warm.get("shader_families",0))>0 and warm.get("flat_found",false),label+" actual room-entry families collected")
	check(int(destruction.get("material_families",0))>=7,label+" original material preparation retained")

func run()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var initial_native:=Engine.get_frames_drawn()
	var settings:Node=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true);settings.set_palette_enabled(true);settings.set_palette_scheme(1);settings.set_setting(&"shadow_quality","high")
	node_added.connect(added)
	var main:Node=load("res://scenes/app/main.tscn").instantiate();root.add_child(main)
	for frame in 4:await process_frame
	main._show_dream("assault_rifle")
	while main.transition_running:await process_frame
	check(is_instance_valid(world) and is_instance_valid(world.player),"formal Main world and player created")
	if not is_instance_valid(world):main.free();quit(1);return
	while not world.player_has_left_elevator_cab:await process_frame
	check(not paused,"normal Main resumes gameplay after loading")
	var first:Dictionary=world.last_firearm_render_preparation.duplicate(true)
	inspect_preparation(first,world.get_current_floor_token(),"first floor")
	check(first.destruction.room_firstuse.shader_families==5,"seeded first floor covers the five measured custom shader families")
	check(first.destruction.material_families==13,"seeded first floor adds six to original seven, not a broad 55-family warmup")
	check(world.shadow_manager.quality==&"high","high shadow quality retained")
	world.player.current_health=100000.0
	for room:Dictionary in world.rooms:
		if int(room.id)!=world.spawn_room_id and int(room.id)!=world.boss_room_id and world._is_combat_room(room):
			world.player.global_position=Vector2(room.center_cell)*32.0;world.player.velocity=Vector2.ZERO
			check(world.activate_room(int(room.id)),"normal room activation remains available")
			world._update_camera_and_actor_projection();break
	for frame in 25:await process_frame
	check(Engine.get_frames_drawn()>initial_native+20,"native render loop advances without force_draw")
	root.get_texture().get_image().save_png(directory.path_join("formal_camera.png"))
	var floor_before:int=world.floor_index
	world.has_floor_badge=true;world.player.global_position=Vector2(world.elevator_anchor_cell)*32.0
	world._begin_elevator_entry_transition()
	var began:=Time.get_ticks_usec()
	while (world.floor_index==floor_before or world.floor_transition_in_progress) and Time.get_ticks_usec()-began<25000000:await process_frame
	check(world.floor_index==floor_before+1 and not world.floor_transition_in_progress,"real elevator completes next floor")
	# The persistent last_firearm report is the Main-entry report. The cab
	# preparation has its own authoritative completion signal and payload.
	check(floor_loading_report.get("ready_before_ride",false) and not floor_loading_report.get("cancelled",true),"new floor is prepared before visible cab ride")
	var second:Dictionary=floor_loading_report.get("render_preparation",{})
	inspect_preparation(second,world.get_current_floor_token(),"next floor")
	check(not paused,"next floor resumes gameplay")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"first":first,"second":second,"floor_before":floor_before,"floor_after":world.floor_index,"native_drawn_delta":Engine.get_frames_drawn()-initial_native,"scope":"formal Main and real elevator lifecycle, high shadows/palette1/pixelation, native off-screen window; no FPS acceptance claim"}
	var file:=FileAccess.open(directory.path_join("main_entry.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ROOM_FIRSTUSE_MAIN checks=",checks," failures=",failures," floors=",floor_before,"->",world.floor_index)
	node_added.disconnect(added);main.free();await process_frame;quit(0 if failures.is_empty() else 1)
