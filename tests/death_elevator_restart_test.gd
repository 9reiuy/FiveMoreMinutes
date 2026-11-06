extends SceneTree
## Real Main, real R input, unchanged current floor, and rejected readiness.
var main:Node
var world:Node
var checks:=0
var failures:Array[String]=[]
var phases:Dictionary={}
var advances:=0
var capture_pending:=false
var captured:=false
var output:="res://.runtime/death_elevator_restart_20261102"
var watched:=false

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:int=2)->void:
	for i in n:await process_frame
func watch()->void:
	if not is_instance_valid(world):return
	var phase:String=world.transition_phase
	phases[phase]=true
	if phase=="PREPARING_FLOOR":
		if world.player.movement_enabled or world.player.attacking_enabled or world.elevator_floor_door.doors_open:
			check(false,"No movement, attacks or open door while preparing")
	if phase=="EXITING" and not world.is_loading_render_ready():check(false,"No exit without current receipt")
	var cover:Node=root.get_node_or_null("ElevatorLoadingCover")
	if is_instance_valid(cover) and cover.animation_phase==&"cab_loading" and not captured:
		captured=true;capture_pending=true
func capture()->void:
	if capture_pending:
		capture_pending=false
		root.get_texture().get_image().save_png(output+"/retry_cab.png")
func press_r()->void:
	var event:=InputEventKey.new();event.keycode=KEY_R;event.physical_keycode=KEY_R;event.pressed=true
	world.get_viewport().push_input(event)
	event.pressed=false;world.get_viewport().push_input(event)
func die()->void:
	world.player.invulnerability_left=0.0
	world.player.dash_invulnerability_left=0.0
	world.player.receive_damage(99999.0)
	await frames()
	check(world.player.dead,"Actual lethal damage reaches death state")
func reject(receipt:Dictionary)->void:
	receipt.ready=false;receipt.cancelled=true
func run()->void:
	create_timer(180,true,false,true).timeout.connect(func():push_error("Death retry watchdog");quit(2))
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	AudioServer.set_bus_mute(0,true);Engine.max_fps=60
	var native:=DisplayServer.get_name()!="headless"
	if native:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_position(Vector2i(-30000,-30000))
		RenderingServer.frame_post_draw.connect(capture)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main)
	while main.transition_running:await process_frame
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.erase("chapter_one")
	var chapter_mode:bool="--chapter" in OS.get_cmdline_user_args()
	if chapter_mode:
		var chapter:Dictionary=preload("res://scripts/story/chapter_one_state.gd").create()
		chapter.stage="ASCENT";chapter.floor=2;chapter.build="damage"
		main.persistent_day_state.chapter_one=chapter
	main._show_dream("basic")
	while main.transition_running:await process_frame
	world=main._supported_dream_world
	if not is_instance_valid(world):push_error("Main did not create a gameplay world");quit(2);return
	while world.floor_transition_in_progress:await process_frame
	await frames(3)
	check(world.is_loading_render_ready(),"Main begins with prepared floor")
	world.persist_profile=false
	for node in world.enemy_root.get_children():node.process_mode=Node.PROCESS_MODE_DISABLED
	var floor_before:int=world.floor_index
	var seed_before:int=world.active_seed
	var weapon_before:String=world.player.selected_weapon_id
	var damage_before:float=world.player.acquired_damage_multiplier
	var cells_before:Dictionary=world.floor_cells.duplicate()
	world.elevator_floor_transition_completed.connect(func(_floor:int):advances+=1)
	process_frame.connect(watch)
	await die()
	press_r()
	var token:int=world.transition_generation_token
	press_r()
	check(world.transition_generation_token==token and world.run_interface.restart_in_progress,"Repeated R starts only one restart")
	while world.run_interface.restart_in_progress:await process_frame
	check(not world.player.dead and world.player.current_health==world.player.maximum_health,"Retry revives player")
	check(world.floor_index==floor_before and world.active_seed==seed_before and world.floor_cells==cells_before,"Retry preserves floor, seed and layout")
	check(world.player.selected_weapon_id==weapon_before,"Retry preserves equipped weapon")
	if chapter_mode:
		check(main.chapter_one.state.floor==2 and main.chapter_one.state.build=="damage" and world.floor_index==2,"Chapter rest floor and build remain unchanged")
		check(is_equal_approx(world.player.acquired_damage_multiplier,damage_before),"Retry does not duplicate chapter damage bonuses")
	check(advances==0,"Retry never emits floor advancement")
	check(world.is_loading_render_ready(),"Fresh current-floor readiness receipt is required")
	check(world.player_has_left_elevator_cab and world.player.movement_enabled and world.player.attacking_enabled,"Ready then normal door exit restores input")
	check(world.player.global_position.distance_to(world.elevator_floor_door.get_corridor_approach_position_2d())<12.0,"Scripted exit reaches usable landing rather than timing out in the doorway")
	check(world.active_transition_cab==null and world._floor_rollback_stash==null and not paused and not root.has_node("ElevatorLoadingCover"),"No cab, stash, pause or loading overlay leak")
	check(phases.has("CAB_RIDE") and phases.has("PREPARING_FLOOR") and phases.has("EXITING"),"Retry follows cab, preparation and exit phases")
	var receipt:Dictionary=world.last_firearm_render_preparation.duplicate(true)
	if native:
		check(receipt.render_verified and receipt.world_readback_bytes>0,"Native retry really submits rendering")
		check(captured,"Actual cab Camera appears during preparation")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/retry_arrived.png")
	await die()
	world.firearm_render_preparation_finished.connect(reject,CONNECT_ONE_SHOT)
	press_r()
	while world.run_interface.restart_in_progress:await process_frame
	check(world.player.dead and not world.player.movement_enabled and not world.player.attacking_enabled,"Failed preparation cannot resume play")
	check(world.floor_cells==cells_before and world.floor_index==floor_before,"Failed preparation restores original floor")
	check(is_instance_valid(world.run_interface.death_label) and world.run_interface.death_label.text.contains("重试"),"Failure exposes retry prompt")
	check(not paused and world.active_transition_cab==null and not root.has_node("ElevatorLoadingCover"),"Failure releases cover and pause")
	press_r()
	while world.run_interface.restart_in_progress:await process_frame
	check(not world.player.dead and world.is_loading_render_ready() and advances==0,"R works again after rejected preparation")
	var result:Dictionary={"checks":checks,"failures":failures,"native":native,"phases":phases,"receipt":receipt}
	var file:=FileAccess.open(output+"/"+("chapter_" if chapter_mode else "")+("gpu.json" if native else "logic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("DEATH_ELEVATOR_RESTART ",JSON.stringify(result))
	process_frame.disconnect(watch)
	if native:RenderingServer.frame_post_draw.disconnect(capture)
	main.free();await frames();quit(0 if failures.is_empty() else 1)
