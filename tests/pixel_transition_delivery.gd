extends SceneTree
const DIRECTOR=preload("res://scripts/ui/transition_director.gd")
var main: Node
var world: Node
var output:="res://.runtime/pixel_transitions_20261016/camera"
var checks:=0
var failures: Array=[]
var clips: Dictionary={}
var timings: Dictionary={}
var sizes: Array=[]
var clip:=""
var clip_started:=0
var last_capture:=0
var capture_index:=0
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--artifact-dir="): output=arg.trim_prefix("--artifact-dir=")
	node_added.connect(func(node: Node)->void:
		if node.get_script()!=null and String(node.get_script().resource_path)=="res://scripts/dream/office_skeleton_world_base.gd": node.persist_profile=false)
	call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func capture(force:bool=false)->void:
	if clip.is_empty(): return
	var now:=Time.get_ticks_usec()
	var interval:=90000
	if main.transition_running and main.transition_director.current_state==DIRECTOR.State.WAITING_FOR_SCENE: interval=250000
	var loading: Node=root.get_node_or_null("ElevatorLoadingCover")
	if loading!=null and loading.animation_phase==&"hold": interval=250000
	if not force and now-last_capture<interval: return
	var picture: Image=root.get_texture().get_image()
	if picture.get_size()!=Vector2i(1920,1080):
		sizes.append({"clip":clip,"size":picture.get_size()}); root.size=Vector2i(1920,1080); return
	var file:="%s_%03d.png"%[clip,capture_index]; capture_index+=1
	picture.save_png(output+"/"+file)
	clips[clip].append({"file":file,"seconds":(now-clip_started)/1000000.0})
	last_capture=now
func begin(label:String)->void:
	clip=label; clips[clip]=[]; clip_started=Time.get_ticks_usec(); last_capture=0
func frames(count:int)->void:
	for i in count: await RenderingServer.frame_post_draw; capture()
func wait_transition()->void:
	var deadline:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await frames(1)
	check(not main.transition_running,"Scene transition finishes and releases its queue")
	await frames(6); capture(true)
	timings[clip]=(Time.get_ticks_usec()-clip_started)/1000.0; clip=""
func run()->void:
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	await frames(12)
	# Visual A/B changes the overlay shader only. Both views use real Main
	# entry points and current readiness fences; no legacy timing claim.
	main.transition_director.material_instance.shader=DIRECTOR.SHARD_SHADER
	begin("before"); capture(true); main._show_bedroom(); await wait_transition()
	main._show_main_menu(false); await frames(6)
	main.transition_director.material_instance.shader=preload("res://scripts/ui/pixel_transition.gd").SHADER
	begin("after"); capture(true); main._show_bedroom(); await wait_transition()
	check(main.scene_container.process_mode==Node.PROCESS_MODE_PAUSABLE,"Bedroom resumes after reveal")
	begin("reception"); capture(true); main._show_reception("basic"); await wait_transition()
	begin("game_entry"); capture(true); main._show_dream("basic"); await wait_transition()
	world=main._supported_dream_world
	check(is_instance_valid(world),"Actual reception-to-floor entry remains valid")
	if is_instance_valid(world):
		var deadline:=Time.get_ticks_msec()+10000
		while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await frames(1)
		check(not world.floor_transition_in_progress,"Initial floor-door exit finishes")
		for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
		world.player.invulnerability_left=0; world.player.invulnerability_reason=&""; world.player.hurt_flash_left=0; world.player.revive_flash_left=0
		world.floor_loading_render_preparation_finished.connect(func(report:Dictionary)->void: timings["elevator_loading"]=report)
		world.floor_exit_render_preparation_finished.connect(func(report:Dictionary)->void: timings["elevator_exit"]=report)
		begin("elevator"); capture(true)
		var old_floor: int=world.floor_index
		world.collect_employee_badge(); world._begin_elevator_entry_transition()
		deadline=Time.get_ticks_msec()+60000
		var cab_started:=0; var cab_ms:=0.0; var cab_moved:=0.0; var cab_origin:=Vector2.ZERO
		while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline:
			if world.transition_phase==&"CAB_RIDE" and not paused and not root.has_node("ElevatorLoadingCover"):
				if cab_started==0: cab_started=Time.get_ticks_usec(); cab_origin=world.player.global_position
				cab_ms=(Time.get_ticks_usec()-cab_started)/1000.0
				if cab_ms<150: Input.action_press("move_right")
				else: Input.action_release("move_right")
				cab_moved=maxf(cab_moved,world.player.global_position.distance_to(cab_origin))
			world.player.invulnerability_left=0; world.player.invulnerability_reason=&""; world.player.hurt_flash_left=0; world.player.revive_flash_left=0
			await frames(1)
		Input.action_release("move_right"); await frames(6); capture(true)
		timings["cab_visible_ms"]=cab_ms; timings["cab_movement"]=cab_moved
		check(world.floor_index==old_floor+1 and not world.floor_transition_in_progress,"Real elevator transition reaches the next floor")
		check(cab_ms>=2950 and cab_moved>5,"At least three seconds of ready visible cab includes ordinary movement")
		check(not paused and world.player.movement_enabled and not root.has_node("ElevatorLoadingCover"),"Arrival restores movement and pause without a leftover cover")
		clip=""
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"clips":clips,"timings":timings,"output_size_events":sizes,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"scope":"Actual Main menu, bedroom, reception, formal loading and one real elevator ride. Before/after compares old triangle shader and new pixel shader with current timing and readiness in both. Captures use unscaled real timestamps; loading waits are preserved. AI paused before elevator, no invulnerability flashing. Capture overhead included; no live FPS claim."},"\t")); file.close()
	print("PIXEL_TRANSITION_DELIVERY ",JSON.stringify({"checks":checks,"failures":failures,"clips":clips.size()}))
	main.free(); quit(1 if failures.size() else 0)
