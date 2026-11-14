extends SceneTree
var out:="res://.runtime/screen_wall_stutter_20261108/angle_camera/"
var checks:=0
var failures:=0
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count: int) -> void:
	for index in count:await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+label+".png")==OK,"actual Camera "+label)
func run() -> void:
	print("ANGLE_CAMERA_PID=",OS.get_process_id())
	if not OS.get_user_data_dir().contains("angle_camera_private") or not AudioServer.is_bus_mute(0) or AudioServer.get_driver_name()!="Dummy":
		AudioServer.set_bus_mute(0,true);quit(2);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(640,360)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	var menu: Control=load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	check(RenderingServer.get_current_rendering_driver_name()=="opengl3_angle","real ANGLE/D3D11 driver")
	check(RenderingServer.get_current_rendering_method()=="gl_compatibility","Compatibility renderer retained")
	await frames(18)
	check(menu.wall_view.displays.size()==12,"all televisions loaded")
	check(is_instance_valid(menu.wall_view.avatar),"approved posed avatar loaded")
	await capture("main_menu")
	menu._show_settings()
	await frames(18)
	check(menu.settings_television.is_open() and not menu.settings_television.wall_view.entering,"settings and falling motion complete")
	check(menu.wall_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"covered wall stops drawing")
	var quality: OptionButton=menu.settings_television.settings_panel.shadow_quality_option
	check(quality.get_theme_color("font_color").a==0.0,"no duplicate quality text")
	await capture("settings")
	menu.consume_escape()
	await frames(4)
	check(not menu.settings_television.is_open() and menu.wall_view.interaction_enabled,"Escape restores wall interaction")
	check(AudioServer.is_bus_mute(0),"private mute retained")
	var file:=FileAccess.open(out+"result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name(),"scope":"short actual-Camera and UI driver admission at 30 FPS; no system-wide trace or performance certification"},"\t"));file.close()
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	menu.queue_free()
	await frames(4)
	print("ANGLE_CAMERA_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
