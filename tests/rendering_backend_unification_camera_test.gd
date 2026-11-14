extends SceneTree
## Real Camera admission for the project-selected backend, without CLI overrides.
## Use --case=campaign or an independent scene key below. No player save is used.
const SCENES := {
	"level01":"res://scenes/testing/MegastructureWhiteboxDisplay.tscn",
	"tutorial":"res://scenes/testing/TutorialMaintenanceDisplay.tscn",
	"lab":"res://scenes/testing/GameTestLab.tscn",
	"purple":"res://scenes/preview/hellkind_purple_sample.tscn",
	"visibility":"res://scenes/preview/visibility_light_sample.tscn",
	"office_sample":"res://scenes/dream/Dream3D_OfficeSample.tscn",
	"demo":"res://scenes/dream/Dream3D_DemoRoom.tscn",
	"coast":"res://scenes/preview/night_coast_display.tscn",
	"red_coast":"res://scenes/preview/red_coast.tscn",
	"cliff":"res://scenes/preview/night_coast_city_cliff_display.tscn"
}
var out := "user://renderer_unification"
var case_name := "campaign"
var checks: Array[Dictionary] = []
var photos: Array[Dictionary] = []
var app: Node
var receiver: Node
var cab_photo := false
var selected_lobby_door_index := -1
var stop_after_first_office := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
		if argument.begins_with("--case="):case_name=argument.trim_prefix("--case=")
	call_deferred("run")

func frames(count: int=6) -> void:
	for index in count:await process_frame

func check(ok: bool, label: String) -> bool:
	checks.append({"pass":ok,"description":label})
	print("PASS " if ok else "FAIL ",label)
	return ok

func backend(label: String) -> void:
	check(RenderingServer.get_current_rendering_method()=="forward_plus",label+" uses the required Forward+ renderer")
	if OS.get_name()=="Windows":
		check(RenderingServer.get_current_rendering_driver_name()=="vulkan",label+" uses the project-selected Vulkan driver")

func photo(label: String) -> void:
	await frames(8);await RenderingServer.frame_post_draw
	var picture: Image=root.get_texture().get_image()
	var lit := 0
	for y in range(0,picture.get_height(),4):
		for x in range(0,picture.get_width(),4):
			var color := picture.get_pixel(x,y)
			if maxf(color.r,maxf(color.g,color.b))>.025:lit+=1
	check(lit>30,label+" actual Camera renders a nonempty picture")
	picture.save_png(out.path_join(label+".png"))
	photos.append({"label":label,"size":str(picture.get_size()),"lit_samples":lit})
	backend(label)

func settle() -> bool:
	var deadline := Time.get_ticks_msec()+45000
	await frames(8)
	while app.transition_running and Time.get_ticks_msec()<deadline:await process_frame
	return check(not app.transition_running,"Main scene transition finishes")

func observe_cab() -> void:
	if cab_photo or not is_instance_valid(receiver) or not is_instance_valid(receiver.entry_cab):return
	var cab: Node=receiver.entry_cab
	if not is_instance_valid(cab.reference_art) or not cab.reference_art.active:return
	if cab.reference_art.distance<.6:return
	root.get_texture().get_image().save_png(out.path_join("elevator_journey.png"))
	cab_photo=true

func campaign() -> void:
	app=load("res://scenes/app/main.tscn").instantiate();root.add_child(app);current_scene=app
	await frames(30)
	app._show_main_menu(false)
	if not await settle():return
	await photo("main_menu")
	app.persistent_day_state=app._create_initial_state()
	app.persistent_day_state.erase("chapter_one")
	app._show_bedroom(false)
	if not await settle():return
	await photo("bedroom")
	app._show_reception("basic")
	if not await settle():return
	receiver=app._supported_dream_world
	if not check(is_instance_valid(receiver) and receiver.scene_file_path.ends_with("Dream3D_ReceptionRoom.tscn"),"Main loads the production reception"):return
	await photo("reception")
	var landing: Node=receiver.elevator_floor_door if selected_lobby_door_index<0 else receiver.elevator_doors[selected_lobby_door_index]
	receiver.player.global_position=landing.get_corridor_approach_position_2d()
	receiver.player.set_meta(&"aim_direction_override",landing.get_inward_2d())
	receiver._update_camera_and_projection(0.0)
	await frames(8)
	RenderingServer.frame_post_draw.connect(observe_cab)
	Input.action_press("pickup_weapon");await frames(2);Input.action_release("pickup_weapon")
	var deadline := Time.get_ticks_msec()+65000
	while Time.get_ticks_msec()<deadline:
		if not is_instance_valid(receiver) or app._supported_dream_world!=receiver:break
		await process_frame
	if not await settle():return
	var world: Node=app._supported_dream_world
	if not check(is_instance_valid(world) and world!=receiver and world.has_method("is_loading_render_ready"),"Real elevator interaction reaches the production office"):return
	# The first floor can be prepared synchronously. Start the control deadline
	# after loading rather than consuming it while resources are being built.
	deadline=Time.get_ticks_msec()+65000
	while (world.floor_transition_in_progress or not world.player.movement_enabled or not world.player.attacking_enabled) and Time.get_ticks_msec()<deadline:await process_frame
	RenderingServer.frame_post_draw.disconnect(observe_cab)
	check(cab_photo,"Real elevator Camera is drawn during the journey")
	if not check(not world.floor_transition_in_progress and world.player.movement_enabled and world.player.attacking_enabled,"Office arrival returns player control"):return
	await photo("office_floor_1")
	check(app.current_screen.world_viewport.size==Vector2i(640,360),"Production gameplay retains 640x360 pixel resolution")
	if stop_after_first_office:return
	world.has_floor_badge=true
	world.player.global_position=world.elevator_floor_door.get_corridor_approach_position_2d()
	world.floor_transition_in_progress=true;world.transition_generation_token+=1
	world.player.movement_enabled=false;world.player.attacking_enabled=false;world.player.dash_enabled=false
	await world._transition_to_independent_cab(world.transition_generation_token)
	deadline=Time.get_ticks_msec()+65000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline:await process_frame
	check(world.floor_index==1 and world.active_transition_cab==null and world.player.movement_enabled,"Second floor returns control after the shared elevator")
	await photo("office_floor_2")
	app.chapter_one.start_new();app.chapter_one.state.stage="BED";app.chapter_one.show_room(false)
	if not await settle():return
	await photo("chapter_bedroom")
	check(not app.STORY_TUTORIAL_ENABLED,"Normal campaign still skips the standalone tutorial")

func independent() -> void:
	if not check(SCENES.has(case_name),"Known independent level"):return
	var scene: Node=load(SCENES[case_name]).instantiate();root.add_child(scene);current_scene=scene
	if case_name in ["lab","purple","visibility"]:
		var deadline := Time.get_ticks_msec()+120000
		await frames(4)
		while (not scene.ready_world or scene.busy) and Time.get_ticks_msec()<deadline:await process_frame
		check(scene.ready_world and not scene.busy,"Independent sample finishes loading its playable world")
		if case_name in ["purple","visibility"]:
			while not scene.sample_ready and Time.get_ticks_msec()<deadline:await process_frame
			check(scene.sample_ready,"Independent lighting and visibility presentation finishes loading")
	await frames(24);await photo(case_name)
	var world: Node=scene.get("world") if scene is Control else scene
	if is_instance_valid(world) and is_instance_valid(world.get("camera_3d")):
		check(world.camera_3d.get_viewport().get_camera_3d()==world.camera_3d,"Level uses its real current game Camera")

func run() -> void:
	await process_frame
	var master := AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	preload("res://tests/support/background_gpu.gd").start(self)
	backend("Engine startup")
	if case_name=="campaign":await campaign()
	else:await independent()
	check(AudioServer.is_bus_mute(master),"Private test audio stays muted")
	var failures := checks.filter(func(row):return not row.pass).size()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"case":case_name,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name(),"audio":AudioServer.get_driver_name(),"checks":checks,"failures":failures,"photos":photos},"\t"))
	print("RENDERER_UNIFICATION checks=",checks.size()," failures=",failures)
	if is_instance_valid(app):
		Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	if is_instance_valid(current_scene):current_scene.queue_free()
	preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0)
	await frames(8);quit(1 if failures else 0)
