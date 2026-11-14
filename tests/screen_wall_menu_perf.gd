extends SceneTree
## Matched native-window UI comparison before promoting the candidate scene.
const OUT := "res://.runtime/screen_wall_menu_promotion_20261107/"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("MENU_PERF_PID=", OS.get_process_id(), " audio=", AudioServer.get_driver_name())
	if AudioServer.get_driver_name() != "WASAPI" or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-30000, -30000))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var budget := root.get_node("FrameBudget")
	if not budget.enabled:
		quit(2)
		return
	var reports: Array = []
	for candidate in [false, true]:
		for focused in [true, false]:
			var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
			lab.presentation_scene_path = "res://scenes/preview/screen_wall_menu_candidate.tscn" if candidate else "res://tests/fixtures/screen_wall_menu_legacy.tscn"
			root.add_child(lab)
			budget.apply_window_focus(focused)
			RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
			if candidate:
				RenderingServer.viewport_set_measure_render_time(lab.presentation.wall_viewport.get_viewport_rid(), true)
			await create_timer(1.0).timeout
			var began := Time.get_ticks_usec()
			var previous := began
			var records: Array = []
			var next_move := 0
			while Time.get_ticks_usec() - began < 4000000:
				if int((Time.get_ticks_usec() - began) / 1000000.0) >= next_move:
					var point := Vector2(160 + next_move * 90, 130)
					if candidate:
						var wall: Node3D = lab.presentation.wall_view
						var display: Node3D = wall.displays[[0, 6, 5, 8][mini(next_move, 3)]]
						point = wall.camera.unproject_position(display.chassis.to_global(Vector3(0, 0, 0.04))) * 0.5
					var event := InputEventMouseMotion.new()
					event.position = root.get_final_transform() * point
					event.global_position = event.position
					Input.parse_input_event(event)
					next_move += 1
				await process_frame
				var now := Time.get_ticks_usec()
				records.append({"at_usec": now, "frame_ms": (now - previous) / 1000.0,
					"root_render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
					"root_render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
					"wall_render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(lab.presentation.wall_viewport.get_viewport_rid()) if candidate else 0.0})
				previous = now
			var stats := {}
			for metric in ["frame_ms", "root_render_cpu_ms", "root_render_gpu_ms", "wall_render_gpu_ms"]:
				var values: Array = records.map(func(row): return row[metric])
				values.sort()
				stats[metric] = {"p50": values[values.size() / 2], "p95": values[floori(values.size() * 0.95)],
					"p99": values[floori(values.size() * 0.99)], "max": values.back()}
			var case_name := ("candidate" if candidate else "legacy") + ("_60" if focused else "_30")
			reports.append({"case": case_name, "limit": Engine.max_fps, "stats": stats, "raw": records})
			print("MENU_PERF_CASE ", case_name, " limit=", Engine.max_fps, " frame_ms=", stats.frame_ms)
			lab.queue_free()
			await process_frame
	var file := FileAccess.open(OUT + "matched_menu_perf.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid": OS.get_process_id(), "audio": AudioServer.get_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "cases": reports,
		"conditions": "same process, private prelaunch mute, WASAPI, native offscreen 1280x720 window, VSync on, 1s warmup + 4s recorded per case; UI scope only"}, "\t"))
	file.close()
	quit(0)
