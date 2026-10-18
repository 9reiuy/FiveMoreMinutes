extends "res://tests/nyangeon_vfx_sample_delivery.gd"
var phone:Node
var evidence:Dictionary={}
func key(code:Key,pressed:bool=true)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	root.push_input(event,true)
func tap(code:Key)->void:
	key(code);await wait(.07);key(code,false);await wait(.10)
func move(point:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=Vector2(8,2)
	root.push_input(event,true)
func click(point:Vector2,button:MouseButton=MOUSE_BUTTON_LEFT)->void:
	move(point);await wait(.08)
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=true
	root.push_input(event,true);await wait(.12)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await wait(.12)
func hit(id:StringName)->void:
	# Freeze the pose at press time; hover may move it a fraction first.
	move(phone.shell.screen_point_to_global(phone.screen.get_control_point(id)));await wait(.18)
	await click(phone.shell.screen_point_to_global(phone.screen.get_control_point(id)))
func shot(label:String)->void:
	await wait(.12);root.get_texture().get_image().save_png(output+"/"+label+".png")
func ready_main()->void:
	var until:=Time.get_ticks_msec()+60000
	while main.transition_running and Time.get_ticks_msec()<until:await wait(.05)
	await wait(.4)
func settled()->void:
	var until:=Time.get_ticks_msec()+8000
	while phone.shell.is_animating and Time.get_ticks_msec()<until:await wait(.03)
	await wait(.45)
func back()->void:await click(Vector2(430,270),MOUSE_BUTTON_RIGHT)
func drag_volume()->void:
	var low:Vector2=phone.screen.get_control_point(&"master_volume_min")
	var high:Vector2=phone.screen.get_control_point(&"master_volume_max")
	move(phone.shell.screen_point_to_global(low.lerp(high,.25)));await wait(.2)
	var event:=InputEventMouseButton.new();event.position=phone.shell.screen_point_to_global(low.lerp(high,.25));event.global_position=event.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await wait(.1)
	var pose:Vector3=phone.shell.get_feedback_state().pointer_rotation
	for index in range(1,8):
		var motion:=InputEventMouseMotion.new();motion.position=phone.shell.screen_point_to_global(low.lerp(high,lerpf(.25,.7,float(index)/7)))
		motion.global_position=motion.position;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(6,0)
		root.push_input(motion,true);await wait(.04)
	check(phone.shell.get_feedback_state().pointer_rotation.is_equal_approx(pose),"Slider drag freezes the phone pose")
	event=event.duplicate();event.position=phone.shell.screen_point_to_global(low.lerp(high,.7));event.global_position=event.position;event.pressed=false
	root.push_input(event,true);await wait(.15)
func sample_phone_performance(label:String)->void:
	var samples:Array=[];var last:=Time.get_ticks_usec()
	for index in 90:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if index>=30:samples.append(float(now-last)/1000.0)
		last=now
	samples.sort()
	evidence[label]={"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"scope":"Paused/open-phone or idle scene; no PNG readback; not combat FPS"}
func run()->void:
	if not OS.get_user_data_dir().contains("phone_tab_20261018"):
		push_error("Use an isolated phone_tab_20261018 APPDATA profile for this delivery test");quit(2);return
	output="res://.runtime/phone_tab_20261018/camera_release"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):output=arg.trim_prefix("--artifact-dir=")
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	phone=main.game_phone
	await tap(KEY_TAB)
	check(not phone.is_open(),"Main-menu Tab does not open a phone")
	main.current_screen._show_settings();await shot("main_menu_settings")
	check(main.current_screen.get_node_or_null("SettingsOverlay")!=null or not phone.is_open(),"Main menu retains the original settings UI")
	main.current_screen.consume_escape()
	main.persistent_day_state=main._create_initial_state();main._show_bedroom(false);await ready_main()
	var bedroom:Node=main.current_screen
	begin("bedroom_tab");await tap(KEY_TAB);await settled()
	check(phone.active and phone.screen.get_page_id()==&"home","Actual bedroom Tab opens the four-app phone")
	check(not paused,"Bedroom phone keeps the world clock running")
	var minutes:float=bedroom.current_minutes;await wait(.25)
	check(bedroom.current_minutes>minutes,"Bedroom time advances while phone is open")
	await shot("home_bedroom")
	await hit(&"chat");await shot("messages")
	check(phone.screen.get_page_id()==&"chat","Mouse hover and click open real messages")
	await tap(KEY_S);await shot("messages_scrolled");await back()
	check(phone.screen.get_page_id()==&"home","Right button returns one level")
	key(KEY_D);await wait(.20);await shot("dpad_right")
	evidence["dpad_held"]=phone.shell.get_feedback_state()
	check(phone.shell.get_feedback_state().amounts.get(&"right",0.0)>.5,"Held D visually presses and tilts the directional disc")
	key(KEY_D,false);await wait(.22)
	check(phone.shell.get_feedback_state().amounts.get(&"right",0.0)<.05,"Directional disc returns on key release")
	await tap(KEY_E);await shot("telephone")
	check(phone.screen.get_page_id()==&"call","Telephone app clearly opens its placeholder page")
	await back();await hit(&"music");await shot("music")
	var audio:Node=root.get_node("SFXManager");var owner:int=audio.current_music_owner_id
	var old_paused:bool=audio.music_player.stream_paused
	await tap(KEY_E)
	check(audio.music_player.stream_paused!=old_paused,"Music app toggles the existing BGM player")
	check(audio.current_music_owner_id==owner,"Music controls preserve current scene audio ownership")
	await tap(KEY_E);await back();await hit(&"shop");await shot("shop_bedroom")
	var balance:int=main.persistent_day_state.balance;var count:int=main.persistent_day_state.melatonin_inventory
	await tap(KEY_E)
	check(main.persistent_day_state.melatonin_inventory==count+1 and main.persistent_day_state.balance<balance,"Bedroom shop purchases through the actual backend")
	await shot("shop_purchased");await back();await tap(KEY_Q);await shot("settings")
	check(phone.screen.get_page_id()==&"settings","Q left softkey opens settings from home")
	await hit(&"sounds");await shot("sounds");await drag_volume()
	check(root.get_node("SettingsManager").get_volume(&"master_volume")==70,"Actual tilted-screen drag sets master volume to 70")
	await back();await hit(&"graphics");await shot("graphics")
	await tap(KEY_TAB);await settled();finish()
	check(not phone.is_open(),"Tab closes directly from a nested settings page")
	check(not bedroom.phone.blocks_bedroom_interaction(),"Bedroom interactions recover after closing")
	main._show_reception("basic");await ready_main()
	var world:Node3D=main._supported_dream_world
	var base_fov:float=world.camera_3d.fov
	await sample_phone_performance("hall_closed_performance")
	await shot("camera_before")
	begin("camera_tab");await tap(KEY_TAB);await settled()
	evidence["camera_zoom"]={"before":base_fov,"after":world.camera_3d.fov,"authority":world.authoritative_camera_fov,"weight":phone._camera_weight,"world_weight":world.phone_camera_weight,"projection":world.camera_3d.projection}
	check(paused and phone.active,"Actual reception Tab pauses gameplay and opens phone")
	check(is_equal_approx(world.camera_3d.fov,base_fov/1.4),"Formal camera authority zooms in by the approved factor")
	var head:Vector3=world.get_gameplay_world_position(world.player.global_position,.65)
	var projected:Vector2=world.camera_3d.unproject_position(head)/world.camera_3d.get_viewport().get_visible_rect().size
	evidence["camera_player_uv"]=projected
	check(projected.x>.58 and projected.x<.80,"Character is framed right of the left-hand phone")
	await shot("home_reception")
	finish();await sample_phone_performance("hall_phone_performance");begin("pointer_and_return")
	move(Vector2(620,25));await wait(.4);await shot("pointer_right")
	var right_pose:Vector3=phone.shell.get_feedback_state().pointer_rotation
	move(Vector2(20,335));await wait(.4);await shot("pointer_left")
	check(not phone.shell.get_feedback_state().pointer_rotation.is_equal_approx(right_pose),"Actual mouse movement changes the small phone viewing angle")
	var special:={"id":"day5_northern_times","text":"测试讯息","is_read":false}
	main.persistent_day_state.online_messages.append(special)
	phone.screen.apps_model.hover_message(special);await wait(.10)
	check(phone.canvas.get_node_or_null("PhoneMessageGlitch")!=null,"Existing special-message visual effect is rendered above the shared phone")
	await wait(.45)
	check(phone.canvas.get_node_or_null("PhoneMessageGlitch")==null,"Message visual effect cleans itself while the world is paused")
	await hit(&"shop");await shot("shop_readonly")
	balance=main.persistent_day_state.balance;count=main.persistent_day_state.melatonin_inventory
	await tap(KEY_E)
	check(main.persistent_day_state.balance==balance and main.persistent_day_state.melatonin_inventory==count,"3D shopping cannot charge or purchase")
	await back();await hit(&"chat");await shot("messages_reception")
	await tap(KEY_TAB);await settled();await shot("camera_restored");finish()
	check(not paused and not phone.is_open(),"Closing phone resumes the original gameplay pause state")
	check(is_equal_approx(world.camera_3d.fov,base_fov),"Closing restores the original FOV")
	begin("camera_repeat");await tap(KEY_TAB);await settled();await wait(.35);await tap(KEY_TAB);await settled();finish()
	await tap(KEY_ESCAPE)
	check(main.pause_menu.is_open() and not phone.is_open(),"Esc without phone still uses the old pause menu")
	await shot("old_pause");await tap(KEY_ESCAPE)
	var pauses:Node=root.get_node("PauseManager");pauses.request_pause(&"PHONE_TAB_OTHER")
	await tap(KEY_TAB);await settled();await tap(KEY_TAB);await settled()
	check(paused and pauses.has_pause_reason(&"PHONE_TAB_OTHER"),"Phone close does not release another pause owner")
	pauses.release_pause(&"PHONE_TAB_OTHER")
	pauses.request_pause(&"DIALOGUE");await tap(KEY_TAB)
	check(not phone.is_open(),"Tab respects the existing dialogue modal owner")
	pauses.release_pause(&"DIALOGUE")
	check(phone.environment_bridge==null,"Closed phone releases its environment capture component")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"All actual entrypoint GPU testing stayed minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"evidence":evidence,"gpu":RenderingServer.get_video_adapter_name(),"output":"1920x1080","ui":"640x360","scope":"Actual Main Tab entrypoint: bedroom/reception, native settings/pause retained; formal dungeon exercised separately."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PHONE_TAB_GPU ",checks," checks ",failures.size()," failures")
	main.free();quit(1 if not failures.is_empty() else 0)
