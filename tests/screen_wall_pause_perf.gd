extends SceneTree
const OUT:="res://.runtime/screen_wall_pause_20261107/"
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	print("PAUSE_PERF_PID=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	if not OS.get_user_data_dir().contains("pause_") or AudioServer.get_driver_name()!="WASAPI" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(640,360)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	var budget:=root.get_node("FrameBudget")
	var lab: Control=load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path="res://scenes/preview/screen_wall_pause_lab.tscn"
	root.add_child(lab)
	lab.presentation.open_on_boot=false
	var deadline:=Time.get_ticks_msec()+24000
	while not lab.presentation.booted and Time.get_ticks_msec()<deadline: await process_frame
	if not lab.presentation.booted:
		quit(2)
		return
	var menu: CanvasLayer=lab.presentation.main.pause_menu
	var legacy: CanvasLayer=load("res://tests/fixtures/screen_wall_pause_legacy.tscn").instantiate()
	lab.presentation.main.add_child(legacy)
	root.get_node("PauseManager").request_pause(&"ESC_MENU")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(menu.wall_viewport.get_viewport_rid(),true)
	var opening: Array=[]
	var reports: Array=[]
	for row in [["legacy_60_A",false,true],["crt_60_B",true,true],["legacy_60_A2",false,true],["crt_30",true,false],["legacy_30",false,false]]:
		menu.close_pause()
		legacy.close_pause()
		budget.apply_window_focus(row[2])
		var active: CanvasLayer=menu if row[1] else legacy
		var began:=Time.get_ticks_usec()
		active.open_pause()
		var cpu_ms:=(Time.get_ticks_usec()-began)/1000.0
		var previous:=began
		var first_frames: Array=[]
		for index in 8:
			await process_frame
			var now:=Time.get_ticks_usec()
			first_frames.append((now-previous)/1000.0)
			previous=now
		opening.append({"case":row[0],"open_cpu_ms":cpu_ms,"first_8_frame_ms":first_frames})
		await create_timer(1.0,true).timeout
		budget.apply_window_focus(row[2])
		await create_timer(0.2,true).timeout
		var raw: Array=[]
		began=Time.get_ticks_usec()
		previous=began
		var last_hover:=-1
		while Time.get_ticks_usec()-began<4000000:
			var hover_index:=int((Time.get_ticks_usec()-began)/700000)%3
			if row[1] and hover_index!=last_hover:
				menu.option_group.activate_option(menu.action_buttons[[&"resume",&"settings",&"exit_to_menu"][hover_index]],true)
				last_hover=hover_index
			await process_frame
			var now:=Time.get_ticks_usec()
			raw.append({"frame_ms":(now-previous)/1000.0,"root_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"pause_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(menu.wall_viewport.get_viewport_rid()) if row[1] else 0.0})
			previous=now
		var stats:={}
		for metric in ["frame_ms","root_gpu_ms","pause_gpu_ms"]:
			var values: Array=raw.map(func(v):return v[metric])
			values.sort()
			stats[metric]={"p50":values[values.size()/2],"p95":values[floori(values.size()*0.95)],"p99":values[floori(values.size()*0.99)],"max":values.back()}
		reports.append({"case":row[0],"limit":Engine.max_fps,"stats":stats,"raw":raw})
		print("PAUSE_PERF_CASE ",row[0]," ",stats)
	menu.close_pause()
	legacy.close_pause()
	var result:={"pid":OS.get_process_id(),"gpu":RenderingServer.get_video_adapter_name(),"audio":AudioServer.get_driver_name(),"conditions":"same process and paused gameplay scene, 1280x720, VSync, WASAPI/private mute; legacy/CRT/legacy 60 FPS then 30 FPS pair; 1s warmup and 4s measured per case; native offscreen window, no forced draw or capture","startup_preparation_complete":menu.television_warmed,"startup_preparation_wall_ms":menu.warmup_msec,"opening":opening,"cases":reports,"closed_pause_draw_disabled":menu.wall_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED}
	var file:=FileAccess.open(OUT+"matched_perf.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	lab.queue_free()
	await process_frame
	await process_frame
	quit(0)
