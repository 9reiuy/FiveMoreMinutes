extends SceneTree
var OUT:="res://.runtime/screen_wall_pause_20261107/"
var failures:=0
var checks:=0
var main: Node
var pause: CanvasLayer
var motion: Array=[]
var hover_pixels: Dictionary={}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			OUT=argument.trim_prefix("--output-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count: int) -> void:
	for index in count: await process_frame
func shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	check(picture.save_png(OUT+label+".png")==OK,"Camera "+label)
	return picture
func white_pixels(picture: Image,content_rect: Rect2) -> int:
	var projected:=Rect2(root.get_final_transform()*pause.content_screen_position(content_rect.position),Vector2.ZERO)
	for corner in [Vector2(content_rect.end.x,content_rect.position.y),content_rect.end,Vector2(content_rect.position.x,content_rect.end.y)]:
		projected=projected.expand(root.get_final_transform()*pause.content_screen_position(corner))
	var area:=Rect2i(projected.grow(2.0)).intersection(Rect2i(Vector2i.ZERO,picture.get_size()))
	var count:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var pixel:=picture.get_pixel(x,y)
			if pixel.v>0.45 and pixel.s<0.18: count+=1
	return count
func key(code: Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=down
		Input.parse_input_event(event)
		await frames(2)
func pointer(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	Input.parse_input_event(event)
func click(point: Vector2) -> void:
	pointer(point)
	await frames(3)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=root.get_final_transform()*point
		event.global_position=event.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		Input.parse_input_event(event)
		await frames(2)
func choose(id: StringName,wait_frames:=16) -> void:
	await click(pause.option_screen_position(id))
	await frames(wait_frames)
func widget_click(widget: Control) -> void:
	await click(pause.content_screen_position(widget.get_global_rect().get_center()))
	await frames(12)
func slider_drag(slider: HSlider) -> void:
	var start: Vector2=pause.content_screen_position(slider.get_global_rect().position+Vector2(slider.size.x*0.18,slider.size.y*0.5))
	pointer(start)
	await frames(3)
	var event:=InputEventMouseButton.new()
	event.position=root.get_final_transform()*start
	event.global_position=event.position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	for fraction in [0.30,0.48,0.66]:
		var at: Vector2=pause.content_screen_position(slider.get_global_rect().position+Vector2(slider.size.x*fraction,slider.size.y*0.5))
		pointer(at)
		await frames(3)
	event=event.duplicate()
	event.position=root.get_final_transform()*pause.content_screen_position(slider.get_global_rect().position+Vector2(slider.size.x*0.66,slider.size.y*0.5))
	event.global_position=event.position
	event.pressed=false
	Input.parse_input_event(event)
	await frames(12)
func run() -> void:
	print("PAUSE_LAB_PID=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	if not OS.get_user_data_dir().contains("pause_") or AudioServer.get_driver_name()!="Dummy" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(640,360)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	var lab: Control=load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path="res://scenes/preview/screen_wall_pause_lab.tscn"
	root.add_child(lab)
	var deadline:=Time.get_ticks_msec()+24000
	while not lab.presentation.booted and Time.get_ticks_msec()<deadline: await process_frame
	if not lab.presentation.booted:
		check(false,"lab boots actual gameplay")
		quit(1)
		return
	main=lab.presentation.main
	pause=main.pause_menu
	await frames(35)
	check(paused and pause.is_open(),"actual gameplay remains paused")
	check(pause.wall_view.find_children("*","OmniLight3D",true,false).size()==1,"one CRT and its existing screen light")
	var shared_blue:=preload("res://scripts/ui/screen_wall_colors.gd").primary()
	check(pause.wall_view.terminal.base_tint.is_equal_approx(shared_blue),"pause uses the main menu blue")
	check(pause.wall_view.terminal.spill_light.light_color.is_equal_approx(shared_blue),"the CRT light keeps the same blue after processing")
	check(pause.wall_viewport.size==Vector2i(1280,720),"CRT retains native output resolution")
	check(pause.settings_panel.get_viewport()==pause.content_viewport and pause.menu_buttons.get_viewport()==pause.content_viewport,"pause and settings controls are physically rendered inside the television texture")
	check(pause.wall_view.hover_audio.volume_db==-9.0 and pause.wall_view.hover_audio.max_polyphony==1,"hover cue retains main-menu gain and one voice")
	check(pause.wall_view.screen_to_content(Vector2(-50,-50)).x < -1000,"outside the CRT glass cannot click UI")
	for id in [&"resume",&"settings",&"exit_to_menu"]:
		var native: Vector2=pause.action_buttons[id].get_global_rect().get_center()
		var point: Vector2=pause.option_screen_position(id)/pause.root.size*Vector2(pause.wall_viewport.size)
		var back: Vector2=pause.wall_view.screen_to_content(point)*Vector2(pause.CONTENT_SIZE)
		check(back.distance_to(native)<0.75,"curved glass input mapping "+String(id))
	var picture:=await shot("pause_idle")
	check(picture.get_pixel(5,5).r<0.01 and picture.get_pixel(1270,700).b<0.01,"the outer backdrop is black")
	main._resume_from_pause()
	await frames(4)
	main._open_pause_menu()
	var began:=Time.get_ticks_msec()
	for index in 30:
		await process_frame
		motion.append({"ms":Time.get_ticks_msec()-began,"y":pause.wall_view.terminal.chassis.position.y})
		if index in [2,5,8,12]: await shot("pause_drop_%02d"%index)
	var ys: Array=motion.map(func(row):return row.y)
	check(ys.min()<pause.wall_view.REST_Y-0.10,"television drops past its resting position")
	var minimum:=ys.find(ys.min())
	var rebound:=false
	for index in range(minimum+1,ys.size()): rebound=rebound or ys[index]>ys[minimum]+0.10
	check(rebound and not pause.wall_view.entering and absf(ys.back()-pause.wall_view.REST_Y)<0.001,"drop curve pulls up and settles at screen center")
	for id in [&"resume",&"settings",&"exit_to_menu"]:
		pointer(pause.option_screen_position(id))
		await frames(5)
		check(is_zero_approx(pause.wall_view.terminal.noise_amount),"no hover snow burst for "+String(id))
	await shot("pause_hover_clean")
	await frames(30)
	await click(pause.option_screen_position(&"settings"))
	for index in 15:
		if pause.settings_open: break
		await process_frame
	check(pause.settings_open and paused,"settings opens without resuming gameplay")
	check(pause.wall_view.scanning,"only entering settings starts the top-down CRT scan")
	await shot("settings_scan")
	await frames(20)
	check(not pause.wall_view.scanning,"the fast scan completes")
	check(pause.settings_panel.get_viewport()==pause.content_viewport,"settings controls move with the live GPU content buffer")
	var quality: OptionButton=pause.settings_panel.shadow_quality_option
	check(quality.get_theme_color("font_color").a==0.0 and quality.get_theme_color("font_hover_color").a==0.0,"shadow quality hides the duplicate stock text")
	var caption: Control=quality.get_node("NierCycleCaption")
	check(caption.get_child_count()==3 and caption.get_node("Value").text==quality.get_item_text(quality.selected),"shadow quality has one bracketed value caption")
	var original_quality:=quality.selected
	for step in 3:
		var native_at:=quality.get_global_rect().position+Vector2(quality.size.x*0.8,quality.size.y*0.5)
		await click(pause.content_screen_position(native_at))
		await frames(6)
		check(quality.get_theme_color("font_color").a==0.0 and caption.get_node("Value").text==quality.get_item_text(quality.selected),"quality cycling keeps a single visible caption "+str(step))
	check(quality.selected==original_quality,"quality cycle restores its original setting")
	var music: HSlider=pause.settings_panel.music_slider
	check(music.get_node_or_null("CRTStripedTrack")!=null,"the reference striped slider renderer is present")
	await slider_drag(music)
	check(music.value>55.0 and music.value<77.0,"striped slider still changes through the curved glass")
	check(pause.settings_panel.music_desc.get_theme_color("font_color")==Color.BLACK,"selected text uses the screen background colour")
	check(AudioServer.is_bus_mute(0),"changing private music volume retains master mute")
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	var settings_picture:=await shot("pause_settings")
	pause.content_viewport.get_texture().get_image().save_png(OUT+"settings_native.png")
	var blue_outliers:=0
	var blue_samples:=0
	for y in range(100,620,2):
		for x in range(280,1000,2):
			var pixel:=settings_picture.get_pixel(x,y)
			if pixel.v<0.25: continue
			blue_samples+=1
			var hue_error:=absf(pixel.h-shared_blue.h)
			if pixel.s>0.18 and minf(hue_error,1.0-hue_error)>0.03: blue_outliers+=1
	check(blue_samples>100 and blue_outliers==0,"rendered settings stay blue with neutral hover highlights")
	hover_pixels.slider=white_pixels(settings_picture,music.get_global_rect())
	hover_pixels.value=white_pixels(settings_picture,pause.settings_panel.music_value.get_global_rect())
	check(hover_pixels.slider>8 and hover_pixels.value>8,"Camera shows the hovered I-beam and percentage in white")
	pointer(pause.content_screen_position(Vector2(460,330)))
	await frames(6)
	var cleared_picture:=await shot("settings_hover_leave")
	hover_pixels.slider_after_leave=white_pixels(cleared_picture,music.get_global_rect())
	check(hover_pixels.slider_after_leave==0,"the I-beam returns to blue when the mouse leaves")
	var checkbox: CheckBox=pause.settings_panel.pixelation_check
	pointer(pause.content_screen_position(checkbox.get_global_rect().get_center()))
	await frames(6)
	var checkbox_picture:=await shot("settings_checkbox_hover")
	hover_pixels.checkbox=white_pixels(checkbox_picture,checkbox.get_global_rect())
	check(checkbox.is_hovered() and hover_pixels.checkbox>12,"Camera shows the hovered checkbox outline in white")
	check(pause.settings_panel.pixelation_desc.get_theme_color("font_color")==Color.BLACK,"checkbox row keeps its selected dark text")
	var left_bracket: Label=caption.get_node("LeftBracket")
	pointer(pause.content_screen_position(left_bracket.get_global_rect().get_center()))
	await frames(2)
	# Move within the control after entering it, as a real pointer does.
	pointer(pause.content_screen_position(left_bracket.get_global_rect().get_center()+Vector2(1,0)))
	await frames(6)
	var cycle_picture:=await shot("settings_cycle_hover")
	hover_pixels.cycle_left=white_pixels(cycle_picture,left_bracket.get_global_rect())
	hover_pixels.cycle_right=white_pixels(cycle_picture,caption.get_node("RightBracket").get_global_rect())
	print("CYCLE_HOVER hovered=",quality.is_hovered()," side=",quality.get_meta(&"nier_cycle_hover_side",0)," colour=",left_bracket.get_theme_color("font_color")," pixels=",hover_pixels.cycle_left)
	check(hover_pixels.cycle_left>2 and hover_pixels.cycle_right==0,"Camera shows only the hovered cycle arrow in white")
	music.value=0.0
	if "--capture-only" in OS.get_cmdline_user_args():
		Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
		lab.queue_free()
		await frames(5)
		quit(0)
		return
	await widget_click(pause.settings_panel.assistance_button)
	check(pause.settings_panel.assistance_open,"settings widgets inside the curved screen remain clickable")
	await shot("pause_assistance")
	var old_vault: bool=pause.settings_panel.auto_vault_check.button_pressed
	await widget_click(pause.settings_panel.auto_vault_check)
	check(pause.settings_panel.auto_vault_check.button_pressed!=old_vault,"embedded checkbox changes the actual setting")
	await widget_click(pause.settings_panel.auto_vault_check)
	var laughter_check: CheckBox = pause.settings_panel.canned_laughter_check
	var original_laughter := laughter_check.button_pressed
	await widget_click(laughter_check)
	var settings := root.get_node("SettingsManager")
	check(laughter_check.button_pressed != original_laughter and settings.get_setting(&"canned_laughter_enabled") == laughter_check.button_pressed, "CRT checkbox toggles canned laughter in shared settings")
	await shot("pause_canned_laughter")
	await widget_click(pause.settings_panel.canned_laughter_desc)
	check(laughter_check.button_pressed == original_laughter, "Selecting the laughter label restores the checkbox")
	await key(KEY_ESCAPE)
	await frames(16)
	check(pause.is_open() and not pause.settings_open and paused and not pause.wall_view.scanning,"Escape returns to pause without the settings scan")
	await key(KEY_ESCAPE)
	await frames(5)
	check(not pause.is_open() and not paused,"Escape resumes gameplay")
	check(pause.wall_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and pause.content_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and pause.spare_content_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"closed pause stops all three render targets")
	for index in 3:
		main._open_pause_menu()
		await frames(25)
		await choose(&"resume")
		check(not pause.is_open() and not paused,"resume works after reopen "+str(index))
	var manager:=root.get_node("PauseManager")
	manager.request_pause(manager.DIALOGUE)
	main._open_pause_menu()
	await frames(25)
	await choose(&"resume")
	check(paused and manager.has_pause_reason(manager.DIALOGUE) and not pause.is_open(),"resume releases only the ESC pause reason")
	manager.release_pause(manager.DIALOGUE)
	main._open_pause_menu()
	await frames(25)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await frames(18)
	check(pause.settings_open,"keyboard reaches embedded settings")
	await key(KEY_ESCAPE)
	await frames(16)
	root.size=Vector2i(1280,800)
	await frames(15)
	check(pause.wall_viewport.size==Vector2i(1280,720),"16:10 window retains the 16:9 CRT layout")
	await choose(&"settings")
	check(pause.settings_open,"letterboxed pointer opens embedded settings")
	await key(KEY_ESCAPE)
	await frames(16)
	await choose(&"exit_to_menu")
	await frames(50)
	check(main.current_screen.scene_file_path=="res://scenes/ui/main_menu.tscn" and not paused,"return restores the actual main menu")
	main.current_screen._show_settings()
	pause = main.current_screen.settings_television
	await frames(35)
	await widget_click(pause.settings_panel.assistance_button)
	check(pause.settings_panel.canned_laughter_check.is_visible_in_tree() and pause.settings_panel.canned_laughter_check.button_pressed == original_laughter, "Main menu CRT shows the shared laughter toggle")
	await shot("main_canned_laughter")
	check(AudioServer.is_bus_mute(0),"private mute survives settings and transitions")
	var file:=FileAccess.open(OUT+"lab_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"drop_motion":motion,"hover_white_pixels":hover_pixels,"scope":"independent GameTestLab actual gameplay/CRT pause, not whole-game certification"},"\t"))
	file.close()
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	lab.queue_free()
	await frames(5)
	print("PAUSE_LAB_RESULT checks=",checks," failures=",failures," exit=",1 if failures else 0)
	quit(1 if failures else 0)
