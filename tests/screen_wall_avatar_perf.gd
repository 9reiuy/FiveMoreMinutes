extends SceneTree
## Matched menu comparison, without forced draws or screenshots.
const OUT := "res://.runtime/screen_wall_avatar_20261107/"
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("AVATAR_PERF_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "WASAPI" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	var budget := root.get_node("FrameBudget")
	if not budget.enabled:
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-30000,-30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var reports: Array = []
	for with_avatar in [false,true]:
		for focused in [true,false]:
			var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
			lab.presentation_scene_path = "res://scenes/preview/screen_wall_avatar_candidate.tscn"
			root.add_child(lab)
			var wall: Node3D = lab.presentation.wall_view
			# Keep placement and screen lighting identical, isolating the model.
			wall.avatar.visible = with_avatar
			budget.apply_window_focus(focused)
			RenderingServer.viewport_set_measure_render_time(wall.get_viewport().get_viewport_rid(),true)
			await create_timer(1.0).timeout
			# Let the native window's initial focus-loss event settle before
			# simulating either measured focus budget on the offscreen window.
			budget.apply_window_focus(focused)
			await create_timer(0.2).timeout
			var expected_limit := 60 if focused else 30
			if Engine.max_fps != expected_limit:
				quit(2)
				return
			var began := Time.get_ticks_usec()
			var previous := began
			var raw: Array = []
			var next_move := 0
			while Time.get_ticks_usec() - began < 4000000:
				if int((Time.get_ticks_usec() - began) / 1000000.0) >= next_move:
					var display: Node3D = wall.displays[[0,6,5,8][mini(next_move,3)]]
					var point: Vector2 = wall.camera.unproject_position(display.chassis.to_global(Vector3(0,0,0.04)))
					var event := InputEventMouseMotion.new()
					event.position = root.get_final_transform() * (point * 0.5)
					event.global_position = event.position
					Input.parse_input_event(event)
					next_move += 1
				await process_frame
				var now := Time.get_ticks_usec()
				if Engine.max_fps != expected_limit:
					quit(2)
					return
				raw.append({"frame_ms":(now-previous)/1000.0,
					"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(wall.get_viewport().get_viewport_rid()),
					"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(wall.get_viewport().get_viewport_rid())})
				previous = now
			var stats := {}
			for metric in ["frame_ms","gpu_ms","render_cpu_ms"]:
				var values: Array = raw.map(func(row): return row[metric])
				values.sort()
				stats[metric] = {"p50":values[values.size()/2],"p95":values[floori(values.size()*0.95)],"p99":values[floori(values.size()*0.99)],"max":values.back()}
			var label := ("avatar" if with_avatar else "hidden") + ("_60" if focused else "_30")
			reports.append({"case":label,"limit":Engine.max_fps,"stats":stats,"raw":raw})
			print("AVATAR_PERF_CASE ",label," ",stats)
			lab.queue_free()
			await process_frame
	var file := FileAccess.open(OUT + "matched_perf.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"gpu":RenderingServer.get_video_adapter_name(),"audio":AudioServer.get_driver_name(),"conditions":"same process; identical 1280x720 scene/camera/lighting, model hidden or visible, real WASAPI/private prelaunch mute, VSync on, native offscreen window; 1s warmup/4s measured; no screenshot/forced draw","cases":reports},"\t"))
	file.close()
	quit(0)
