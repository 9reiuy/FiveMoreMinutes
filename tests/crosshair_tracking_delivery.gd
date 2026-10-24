extends "res://tests/phone_tab_delivery.gd"
var crosshair:Control
var draw_count:=0
var samples:Array=[]
func pointer_sample(point:Vector2,label:String)->void:
	var before:=draw_count
	move(point);await wait(.20);await shot(label)
	var cursor:Vector2=crosshair._world_to_ui(world.player.get_constrained_aim_position())
	samples.append({"label":label,"input":point,"drawn_at":cursor,"draws":draw_count-before,"color":crosshair.current_color,"recoil":crosshair.recoil_rotation})
	check(draw_count>before,"Stable ready crosshair actually redraws after pointer moves: "+label)
	check(cursor.distance_to(point)<2.0,"Actual HUD crosshair tracks the input point: "+label)
func run()->void:
	var isolated:=ProjectSettings.globalize_path("res://.runtime/").replace("\\","/").simplify_path()+"/"
	if not OS.get_user_data_dir().replace("\\","/").simplify_path().begins_with(isolated):quit(2);return
	output="res://.runtime/crosshair_errors_20261020/camera"
	preload("res://tests/support/background_gpu.gd").start(self)
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.tutorial_completed=true
	seed(120);main._show_dream("basic");await ready_main()
	world=main._supported_dream_world
	var deadline:=Time.get_ticks_msec()+45000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline:await wait(.05)
	check(not world.floor_transition_in_progress,"Formal Main generated floor completes its entrance")
	world.player.dash_invulnerability_left=3600.0
	crosshair=world.run_interface.crosshair;phone=main.game_phone
	crosshair.draw.connect(func()->void:draw_count+=1)
	# Enter the already-ready visual state directly so a slow world clock cannot
	# let colour interpolation mask a missing pointer redraw in this regression.
	crosshair.current_color=world.config.crosshair_ready_color
	await wait(.30)
	check(world.player.get_weapon_cooldown_progress()>=.999,"Pointer regression starts with a fully ready, idle weapon")
	begin("ready_pointer")
	for index in 6:
		await pointer_sample(Vector2(180+index*48,112+index%2*90),"point_%d"%index)
	finish()
	check(samples.all(func(sample:Dictionary)->bool:return sample.color.is_equal_approx(world.config.crosshair_ready_color) and is_zero_approx(sample.recoil)),"Pointer tracking remains independent of colour interpolation or recoil")
	begin("phone_resume");await tap(KEY_TAB);await settled()
	check(phone.active and paused,"Actual phone still pauses the formal floor")
	await tap(KEY_TAB);await settled()
	check(not phone.is_open() and not paused,"Closing phone restores gameplay")
	await pointer_sample(Vector2(440,118),"after_phone_right")
	await pointer_sample(Vector2(205,218),"after_phone_left");finish()
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"GPU verification stayed minimized and unfocused")
	var report:={"checks":checks,"failures":failures,"clips":clips,"samples":samples,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Actual Main full floor, idle ready weapon with stable color/recoil, pointer moves and phone close resume"}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CROSSHAIR_TRACKING_GPU checks=",checks," failures=",failures.size())
	main.free();quit(1 if not failures.is_empty() else 0)
