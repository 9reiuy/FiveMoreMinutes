extends "res://tests/phone_tab_delivery.gd"

func run()->void:
	if not OS.get_user_data_dir().contains("phone_feedback_20261019"):
		push_error("Use an isolated phone_feedback_20261019 profile");quit(2);return
	output="res://.runtime/phone_feedback_20261019/camera"
	preload("res://tests/support/background_gpu.gd").start(self)
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	main.persistent_day_state=main._create_initial_state();main._show_bedroom(false);await ready_main()
	phone=main.game_phone;await tap(KEY_TAB);await settled()
	check(phone.active and phone.backdrop.color.a==0,"Actual bedroom phone opens without screen dimming")
	begin("footer_navigation")
	await tap(KEY_S);await tap(KEY_S);await shot("footer_settings")
	check(phone.screen.get_focus_region()==&"footer" and phone.screen.get_focused_softkey()==&"home","S reaches original bottom-left Settings softkey")
	await tap(KEY_D);await shot("footer_back")
	check(phone.screen.get_focused_softkey()==&"back","D moves the bottom selection frame to Return")
	await tap(KEY_W)
	check(phone.screen.get_focus_region()==&"content" and phone.screen.get_selected_index()==3,"W returns to the existing shopping app without changing 2x2 layout")
	await tap(KEY_A);await tap(KEY_S);await tap(KEY_E);await shot("settings_page")
	check(phone.screen.get_page_id()==&"settings","E activates the selected bottom-left Settings button")
	await tap(KEY_S);await tap(KEY_S);await tap(KEY_D);await shot("inner_footer_back")
	check(phone.screen.get_focus_region()==&"footer" and phone.screen.get_focused_softkey()==&"back","Settings page also exposes its original footer to WASD")
	await tap(KEY_E)
	check(phone.screen.get_page_id()==&"home","E on inner footer Return goes back one level")
	# A stationary cursor must not take focus from keyboard navigation.
	await hit(&"chat");await back()
	var motions:Array=[]
	phone.screen.gui_input.connect(func(event:InputEvent)->void:
		if event is InputEventMouseMotion:motions.append({"position":event.position,"relative":event.relative,"mask":event.button_mask}))
	var footer_point:Vector2=phone.shell.screen_point_to_global(phone.screen.get_control_point(&"settings"))
	move(footer_point);await wait(.3)
	evidence["footer_hover"]={"global_point":footer_point,"mapped_now":phone.shell._screen_at(footer_point),"ui_motions":motions.duplicate(),"last_mapped_point":phone.shell._last_screen_point,"focus":phone.screen.get_focus_region(),"selected_softkey":phone.screen.get_focused_softkey()}
	check(phone.screen.get_focus_region()==&"footer" and phone.screen.get_focused_softkey()==&"home","Real mouse hover selects the same bottom-left softkey")
	await shot("mouse_footer");finish()
	begin("button_feedback")
	key(KEY_D);await wait(.18);await shot("dpad_held")
	var held:Dictionary=phone.shell.get_feedback_state();evidence["held"]=held
	check(float(held.dpad_depth)>.002 and float(held.dpad_depth)<.015 and absf(held.dpad_rotation.y)>.02 and absf(held.dpad_rotation.y)<.07,"Held D produces the requested shallow, close-fit directional depression")
	key(KEY_D,false)
	var rebound:Array=[]
	for index in 10:
		await wait(.025);rebound.append(phone.shell.get_feedback_state().amounts.get(&"right",0.0))
	evidence["right_release_samples"]=rebound
	check(float(phone.shell.get_feedback_state().amounts.get(&"right",1.0))<.06,"Disc returns to rest after release")
	# Complete an instant tap before the next submitted frame.
	# Sample actual submitted frames without PNG encoding inside the 120ms pulse.
	var old_clip:=clip;clip=""
	var quick_images:Array[Image]=[];var quick_records:Array=[];var peak:=0.0;var quick:Dictionary={}
	key(KEY_A);key(KEY_A,false)
	var until:=Time.get_ticks_usec()+250000
	while Time.get_ticks_usec()<until:
		await RenderingServer.frame_post_draw
		var state:Dictionary=phone.shell.get_feedback_state()
		if float(state.amounts.get(&"left",0.0))>peak:peak=float(state.amounts.left);quick=state
		var now:=Time.get_ticks_usec()
		quick_images.append(root.get_texture().get_image())
		quick_records.append({"file":"quick_%04d.png"%quick_records.size(),"seconds":float(now-started)/1000000.0})
	for i in quick_images.size():quick_images[i].save_png(output+"/"+quick_records[i].file)
	clips[old_clip].append_array(quick_records);clip=old_clip
	evidence["quick_tap"]=quick;evidence["quick_tap_peak"]=peak
	check(peak>.20,"Instant key tap has a visible downstroke in actual submitted frames")
	if not quick_images.is_empty():quick_images[0].save_png(output+"/quick_tap.png")
	await wait(.45)
	key(KEY_Q);await wait(.08);await shot("left_softkey")
	check(float(phone.shell.get_feedback_state().soft_depths.get(&"home",0.0))>.002 and float(phone.shell.get_feedback_state().soft_depths.get(&"home",0.0))<.015,"Q depresses the close-fit physical left softkey")
	key(KEY_Q,false);await wait(.30)
	key(KEY_E);await wait(.08);await shot("centre_button")
	check(float(phone.shell.get_feedback_state().center_depth)>.002 and float(phone.shell.get_feedback_state().center_depth)<.015,"E depresses the close-fit physical centre button")
	key(KEY_E,false);await wait(.30)
	var returning:=InputEventMouseButton.new();returning.button_index=MOUSE_BUTTON_RIGHT;returning.pressed=true;returning.position=Vector2(430,270)
	root.push_input(returning,true);await wait(.08);await shot("right_softkey")
	check(float(phone.shell.get_feedback_state().soft_depths.get(&"back",0.0))>.002 and float(phone.shell.get_feedback_state().soft_depths.get(&"back",0.0))<.015,"Right click depresses the close-fit physical Return button")
	returning=returning.duplicate();returning.pressed=false;root.push_input(returning,true);await wait(.30)
	await back();await wait(.30);finish()
	await tap(KEY_TAB);await settled()
	check(not phone.is_open() and not paused,"Bedroom closing restores original interactions")
	main._show_reception("basic");await ready_main()
	var world:Node3D=main._supported_dream_world
	begin("undimmed_camera");await tap(KEY_TAB);await settled()
	check(paused and phone.active and phone.backdrop.color.a==0,"Reception opens and zooms without dimming the scene")
	# Same paused camera and lighting; briefly restore the previous overlay solely
	# for a direct comparison, then return to the actual shipping transparent one.
	phone.backdrop.color=Color(.012,.022,.04,.40);await shot("previous_dim")
	var old_image:Image=root.get_texture().get_image()
	phone.backdrop.color=Color(0,0,0,0);await shot("current_undimmed")
	var new_image:Image=root.get_texture().get_image()
	var old_light:=0.0;var new_light:=0.0
	for y in range(180,650,35):
		for x in range(850,1850,45):
			old_light+=old_image.get_pixel(x,y).get_luminance();new_light+=new_image.get_pixel(x,y).get_luminance()
	evidence["background_luminance"]={"previous_overlay":old_light,"transparent_overlay":new_light,"same_camera":true}
	check(new_light>old_light*1.35,"Actual background pixels recover their original scene brightness")
	await tap(KEY_S);await tap(KEY_S);await shot("reception_footer");await tap(KEY_TAB);await settled();finish()
	check(not phone.is_open() and not paused and world.phone_camera_weight==0,"Reception close restores camera and gameplay")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"GPU delivery stayed minimized and unfocused")
	var report:={"checks":checks,"failures":failures,"clips":clips,"evidence":evidence,"scope":"Actual Main bedroom/reception: existing-footer focus, physical feedback and removing the phone dim overlay","gpu":RenderingServer.get_video_adapter_name()}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PHONE_FEEDBACK_GPU ",checks," checks ",failures.size()," failures")
	main.free();quit(1 if not failures.is_empty() else 0)
