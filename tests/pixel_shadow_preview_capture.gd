extends SceneTree
const PREVIEW = preload("res://scenes/dream/preview/PixelShadowPreview.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var preview := PREVIEW.instantiate()
	root.add_child(preview)
	await create_timer(3.0).timeout
	# Freeze one identical gameplay state for all three visual comparisons.
	preview.world.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("res://.runtime/pixel_shadow")
	var results := {"gpu": RenderingServer.get_video_adapter_name(), "resolution": "1920x1080", "samples": []}
	var images: Array[Image] = []
	for mode in [0, 1, 2]:
		preview.mode = mode
		preview._refresh()
		await create_timer(2.0).timeout
		var frames: Array[float] = []
		var draws: Array[float] = []
		var previous := Time.get_ticks_usec()
		var until := previous + 3000000
		while Time.get_ticks_usec() < until:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append(float(now - previous) / 1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			previous = now
		frames.sort()
		draws.sort()
		await RenderingServer.frame_post_draw
		var captured := root.get_texture().get_image()
		captured.save_png("res://.runtime/pixel_shadow/mode_%d.png" % mode)
		images.append(captured)
		results.samples.append({"mode": mode, "median_ms": frames[frames.size()/2], "p95_ms": frames[int(frames.size()*0.95)], "draw_calls": draws[draws.size()/2], "materials": preview.copies.size()})
	# Ignore status text and HUD. Require actual world pixels to change.
	var changed := 0
	var sampled := 0
	for y in range(240, 990, 4):
		for x in range(240, 1680, 4):
			var a := images[0].get_pixel(x, y)
			var b := images[2].get_pixel(x, y)
			if maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))) > 0.015:
				changed += 1
			sampled += 1
	results["world_changed_fraction"] = float(changed) / sampled
	if changed < sampled * 0.05:
		push_error("Shading comparison has insufficient visible world difference")
		quit(2)
		return
	print("PIXEL_SHADOW_RESULTS ", JSON.stringify(results))
	var file := FileAccess.open("res://.runtime/pixel_shadow/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	preview.world.process_mode = Node.PROCESS_MODE_INHERIT
	preview.world.night_lighting.set_flashlight_enabled(true)
	for index in 4:
		var action: String = ["move_right", "move_down", "move_left", "move_up"][index]
		root.warp_mouse(Vector2(960, 540) + Vector2.from_angle(index * PI / 2.0) * 300.0)
		Input.action_press(action)
		await create_timer(0.5).timeout
		Input.action_release(action)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/pixel_shadow/moving_%d.png" % index)
	preview.queue_free()
	await process_frame
	quit()
