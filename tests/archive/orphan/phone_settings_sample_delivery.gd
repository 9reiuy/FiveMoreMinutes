extends "res://tests/nyangeon_vfx_sample_delivery.gd"
const HOST=preload("res://scripts/ui/preview/phone_settings_sample.gd")
var host:CanvasLayer
var pending_action:StringName=&""
var settings:Node
var pauses:Node
var lighting_evidence:Dictionary={}
func shot(label:String)->void:
	await wait(.16);root.get_texture().get_image().save_png(output+"/"+label+".png")
func tap(key:Key)->void:
	var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=true
	root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	await wait(.08)
func click(point:Vector2)->void:
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	await wait(.04)
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await wait(.04)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await wait(.08)
func hit(id:StringName)->void:await click(host.shell.screen_point_to_global(host.screen.get_control_point(id)))
func key_hit(id:StringName)->void:await click(host.shell.key_point_to_global(id))
func drag_volume(id:StringName,start:float,finish:float)->void:
	var low:Vector2=host.screen.get_control_point(StringName(String(id)+"_min"))
	var high:Vector2=host.screen.get_control_point(StringName(String(id)+"_max"))
	var point:Vector2=host.shell.screen_point_to_global(low.lerp(high,start))
	var press:=InputEventMouseButton.new();press.position=point;press.global_position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	root.push_input(press,true);await wait(.06)
	for step in range(1,8):
		var motion:=InputEventMouseMotion.new()
		motion.position=host.shell.screen_point_to_global(low.lerp(high,lerpf(start,finish,float(step)/7)))
		motion.global_position=motion.position;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true);await wait(.04)
	var release:=InputEventMouseButton.new();release.position=host.shell.screen_point_to_global(low.lerp(high,finish))
	release.global_position=release.position;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
	root.push_input(release,true);await wait(.06)
func ready_main()->void:
	var deadline:=Time.get_ticks_msec()+60000
	while main.transition_running and Time.get_ticks_msec()<deadline:await wait(.05)
	await wait(.3)
func wait_shell()->void:
	var deadline:=Time.get_ticks_msec()+6000
	while host.shell.is_animating and Time.get_ticks_msec()<deadline:await wait(.03)
	await wait(.10)
func close_host()->void:
	host.close_sample();await wait_shell()
	check(not host.active and not host.shell.is_open,"Sample close completes without leaving an active phone")
func image_delta(first:Image,second:Image,points:Array[Vector2])->float:
	var scale:Vector2=Vector2(first.get_size())/root.get_visible_rect().size
	var total:=0.0
	for point in points:
		var at:=Vector2i(point*scale)
		if not Rect2i(Vector2i.ZERO,first.get_size()).has_point(at):continue
		var a:=first.get_pixelv(at);var b:=second.get_pixelv(at)
		total+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
	return total/maxi(points.size(),1)*255.0
func lighting_probe()->void:
	var world:Node3D=main.get("_supported_dream_world")
	var bridge:Node=host.environment_bridge
	check(is_instance_valid(world) and bridge.get_diagnostics().source_type=="source_3d","Phone illumination binds the actual Main 3D world")
	if not is_instance_valid(world):return
	host.screen.set_context(&"settings")
	while host.screen.get_selected_index()!=0:host.screen.navigate(&"up")
	host.screen.navigate(&"confirm")
	var light:=OmniLight3D.new();light.name="PhoneValidationLight"
	light.light_energy=2.2;light.omni_range=4;light.light_specular=1.0;light.shadow_enabled=false
	world.add_child(light)
	var anchor:Vector3=world.get_gameplay_world_position(world.player.global_position,1.05)+world.camera_3d.global_basis.z*.35
	light.global_position=anchor+Vector3(-.65,.5,.8)
	begin("scene_lighting")
	light.light_color=Color("ffb35e");bridge.request_capture();await wait(1.4)
	await shot("lighting_warm");var warm:=root.get_texture().get_image()
	lighting_evidence["warm"]=bridge.get_diagnostics()
	light.light_color=Color("6eaeff");bridge.request_capture();await wait(.9)
	await shot("lighting_cool");var cool:=root.get_texture().get_image()
	lighting_evidence["cool"]=bridge.get_diagnostics()
	for index in bridge._faces.size():
		bridge._faces[index].get_texture().get_image().save_png(output+"/environment_face_%d.png"%index)
	var samples:Array[Vector2]=[]
	var panel:=host.shell._stage.find_child("SilverUpperShell",true,false) as MeshInstance3D
	for index in 20:
		var local:=Vector3(-.83,lerpf(-1.15,1.15,float(index)/19.0),.076)
		var point:Vector2=host.shell._view.position+host.shell._camera.unproject_position(panel.to_global(local))/host.shell.RENDER_SCALE
		samples.append(host.shell.get_global_transform_with_canvas()*point)
	lighting_evidence["body_warm_cool_mean_rgb_delta_255"]=image_delta(warm,cool,samples)
	check(lighting_evidence.body_warm_cool_mean_rgb_delta_255>.5,"Actual warm and cool world lights change the phone shell pixels")
	# The default upright glass faces the dark open ceiling. Tilt the real lid
	# toward the furnished room to demonstrate directional environment reflection.
	var original_lid_angle:float=host.shell._lid.rotation.x
	var motion:Tween=host.shell.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(host.shell._lid,"rotation:x",.52,.35)
	await wait(.5);await shot("glass_with");var reflected:=root.get_texture().get_image()
	lighting_evidence["glass_comparison_lid_angle_radians"]=.52
	bridge.set_reflection_enabled(false);await shot("glass_without");var without:=root.get_texture().get_image()
	samples.clear()
	for y in range(156,195,4):
		for x in range(15,133,5):samples.append(host.shell.screen_point_to_global(Vector2(x,y)))
	lighting_evidence["glass_enabled_disabled_mean_rgb_delta_255"]=image_delta(reflected,without,samples)
	check(lighting_evidence.glass_enabled_disabled_mean_rgb_delta_255>.05,"Captured scene reflection changes otherwise blank LCD pixels")
	bridge.set_reflection_enabled(true)
	check(bridge.get_diagnostics().capture_count>0 and bridge.get_diagnostics().capture_ready,"Six actual environment faces finish rendering on the GPU")
	host.shell._lid.rotation.x=original_lid_angle
	light.free();bridge.request_capture();await wait(.3)
	host.screen.set_context(&"pause");finish()
func run()->void:
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	settings=root.get_node("SettingsManager");pauses=root.get_node("PauseManager")
	settings.values=settings.defaults.duplicate(true);settings._apply_all_audio()
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await ready_main()
	main.current_screen._show_settings();await shot("menu_before")
	main.current_screen.consume_escape();await wait(.2)
	host=HOST.new();root.add_child(host)
	host.action_requested.connect(func(action:StringName)->void:pending_action=action)
	begin("menu_open");host.show_sample(&"settings");await wait_shell();finish()
	check(host.shell.is_open and not host.shell.is_animating,"New phone completes its native open animation")
	var device_view:=host.shell.get_node("RenderedPhone") as TextureRect
	var padding:float=host.shell.RENDER_PADDING
	check(device_view.size.is_equal_approx(host.shell.size+Vector2(padding*2,0)) and device_view.position.is_equal_approx(Vector2(-padding,0)),"Supersampled phone uses explicit logical dimensions and transparent hinge overscan")
	await shot("menu_after")
	begin("settings_input")
	await hit(&"sounds")
	check(host.screen.get_page_id()==&"sounds","Real mouse click enters sound settings on the tilted screen")
	await hit(&"music_volume_max")
	check(settings.get_volume(&"music_volume")==100,"Real pointer reaches slider maximum through transformed phone")
	await tap(KEY_LEFT)
	check(settings.get_volume(&"music_volume")==95,"Keyboard left adjusts the same live music setting")
	await key_hit(&"right")
	check(settings.get_volume(&"music_volume")==100,"Physical right key adjusts the same setting")
	await shot("sound_settings")
	await drag_volume(&"master_volume",.2,.65)
	check(settings.get_volume(&"master_volume")==65,"Real pointer drag adjusts the compact first slider")
	check(settings.get_volume(&"music_volume")==100 and settings.get_volume(&"sfx_volume")==80,"Compact slider drag does not alter neighbouring rows")
	await shot("sound_drag")
	await tap(KEY_ESCAPE);await hit(&"graphics")
	check(host.screen.get_page_id()==&"graphics","Esc returns within phone and mouse enters graphics")
	var old_pixel:bool=settings.get_setting(&"pixelation_enabled")
	await hit(&"pixelation_enabled")
	check(bool(settings.get_setting(&"pixelation_enabled"))!=old_pixel,"Actual pixelation toggle writes through SettingsManager")
	await hit(&"pixelation_enabled")
	await hit(&"shadow_quality");await shot("graphics_settings")
	check(FileAccess.file_exists("user://game_settings.cfg"),"Phone settings use the existing persisted config")
	finish()
	begin("phone_close");await close_host();finish()
	main.persistent_day_state=main._create_initial_state();main._show_bedroom(false);await ready_main()
	var bedroom:Node=main.current_screen
	var phone:Control=bedroom.phone
	phone.state=phone.PhoneState.EXPANDED;phone.position.y=phone.config.phone_expanded_y
	phone.screen_state=phone.ScreenState.HOME;phone._sync_content_visibility()
	await shot("bedroom_before")
	phone.state=phone.PhoneState.COLLAPSED;phone.position.y=phone.config.phone_collapsed_y
	begin("bedroom_pages");host.show_sample(&"bedroom",phone);await wait_shell()
	check(not paused,"Ordinary bedroom phone preserves running bedroom time")
	var before_time:float=bedroom.current_minutes;await wait(.35)
	check(bedroom.current_minutes>before_time,"Bedroom clock advances while reading the new phone")
	await shot("bedroom_home")
	await hit(&"chat")
	check(phone.message_list.get_child_count()>1 and phone.online_scroll.is_visible_in_tree(),"Chat page hosts real existing message controls")
	await shot("chat_page");var scroll_before:int=phone.online_scroll.scroll_vertical
	await tap(KEY_DOWN);await tap(KEY_DOWN)
	check(phone.online_scroll.scroll_vertical>scroll_before,"Keyboard scrolls actual Chinese chat list")
	await shot("chat_scrolled")
	await tap(KEY_ESCAPE);await hit(&"shop")
	check(phone.quicklink_content.phone==phone and phone.quicklink_scroll.is_visible_in_tree(),"Shop page retains original purchase authority")
	await shot("shop_page")
	var balance:int=phone.persistent_state.balance
	var inventory:int=phone.persistent_state.melatonin_inventory
	await tap(KEY_E)
	check(int(phone.persistent_state.melatonin_inventory)==inventory+1 and int(phone.persistent_state.balance)==balance-phone.config.melatonin_price,"Physical-confirm route buys through actual balance and inventory rules")
	await shot("shop_purchase");await tap(KEY_DOWN);await shot("shop_scrolled")
	await tap(KEY_ESCAPE);finish()
	await close_host()
	check(phone.online_scroll.get_parent()==phone.screen_clip and phone.quicklink_scroll.get_parent()==phone.screen_clip,"Closing review restores the original bedroom controls")
	check(phone.visible,"Closing review restores original phone visibility")
	main._show_reception("basic");await ready_main()
	# Interior sample beside an existing tall planter, beyond the open entrance.
	var reception:Node3D=main.get("_supported_dream_world")
	reception.player.global_position=Vector2(16.85,14.0)*32
	await wait(.6)
	main._open_pause_menu();await shot("pause_before");main._resume_from_pause()
	begin("pause_flow");host.show_sample(&"pause");await wait_shell()
	check(paused and pauses.has_pause_reason(host.PAUSE_REASON),"Pause-context phone uses its own pause reason")
	await shot("pause_after")
	await lighting_probe()
	await tap(KEY_DOWN);await tap(KEY_ENTER);await shot("pause_settings")
	await tap(KEY_ESCAPE)
	check(host.screen.get_page_id()==&"pause" and paused,"Esc returns to pause home without unpausing the world")
	await tap(KEY_UP);await tap(KEY_ENTER);await wait_shell();finish()
	check(pending_action==&"resume" and not paused,"Resume closes the phone and releases only its own reason")
	pauses.request_pause(&"PHONE_SAMPLE_OTHER")
	host.show_sample(&"pause");await wait_shell();await close_host()
	check(paused and pauses.has_pause_reason(&"PHONE_SAMPLE_OTHER"),"Closing phone preserves another system's pause")
	pauses.release_pause(&"PHONE_SAMPLE_OTHER")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"Actual Main GPU review stayed minimized")
	var report:={"checks":checks,"failures":failures,"clips":clips,"lighting_evidence":lighting_evidence,"gpu":RenderingServer.get_video_adapter_name(),"logical_ui":"640x360","output":"1920x1080","scope":"Opt-in playable UI sample on actual Main menu, bedroom and hall background. Old phone controls reparented temporarily for real chat/shop. Production entrypoints not replaced; whole integration awaits visual approval."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PHONE_SETTINGS_SAMPLE_GPU ",checks," checks ",failures.size()," failures")
	host.free();main.free();quit(1 if failures.size() else 0)
