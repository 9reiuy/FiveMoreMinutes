extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var parent := Node2D.new()
	root.add_child(parent)
	var target := BlackBloodEffect.new()
	var source := BlackBloodEffect.new()
	parent.add_child(target)
	parent.add_child(source)
	target.set_process(false)
	source.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41001
	for trial in 1200:
		parent.position = Vector2(rng.randf_range(-10000, 10000), rng.randf_range(-10000, 10000))
		parent.rotation = rng.randf_range(-PI, PI)
		parent.scale = Vector2(rng.randf_range(0.2, 3), rng.randf_range(0.2, 3))
		for effect in [target, source]:
			effect.position = Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500))
			effect.rotation = rng.randf_range(-PI, PI)
			effect.scale = Vector2(rng.randf_range(0.2, 3), rng.randf_range(0.2, 3))
			effect.skew = rng.randf_range(-0.4, 0.4)
		source.ground_visual_scale = rng.randf_range(0.2, 3)
		source.ground_pixels.clear()
		source.ground_pixel_types.clear()
		for i in 24:
			source.ground_pixels.append(Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80)))
			# WALL_DRIP makes rasterization return empty immediately. Keep it in
			# the explicit rejection case below, not all 1200 transform trials.
			source.ground_pixel_types.append([0, 1, 3, 4][i % 4])
		_compare(target, source, "transformed_%d" % trial)
	# Near rounding boundaries and large world translations.
	parent.transform = Transform2D.IDENTITY
	target.transform = Transform2D.IDENTITY
	source.transform = Transform2D.IDENTITY
	source.ground_visual_scale = 1.0
	for base in [0.0, 1000.0, 100000.0]:
		for offset in [0.49999, 0.5, 0.50001, -0.49999, -0.5, -0.50001]:
			target.position = Vector2(base, base)
			source.position = target.position + Vector2(offset, offset)
			_compare(target, source, "boundary")
	source.ground_pixel_types[0] = BlackBloodEffect.StampType.WALL_DRIP
	_compare(target, source, "wall_drip")
	_check(target._ground_cells_in_target(source).is_empty(), "Wall stains remain excluded")
	source.ground_pixels.clear()
	source.ground_pixel_types.clear()
	parent.transform = Transform2D.IDENTITY
	target.position = Vector2(1000, 1000)
	source.position = Vector2(1010, 1020)
	for y in range(-20, 20):
		for x in range(-20, 20):
			source.ground_pixels.append(Vector2(x, y))
			source.ground_pixel_types.append(BlackBloodEffect.StampType.CORE_SPLAT)
	for legacy in [true, false, true]:
		target.set_meta(&"test_uncached_ground_transforms", legacy)
		var timings: Array[float] = []
		for i in 120:
			var start := Time.get_ticks_usec()
			var cells := target._ground_cells_in_target(source)
			var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
			if i >= 20:
				timings.append(elapsed)
			if i == 20:
				_check(not cells.is_empty(), "Benchmark has actual blood cells")
		timings.sort()
		print("BLOOD_TRANSFORM_PERF ", JSON.stringify({"legacy": legacy, "median_ms": timings[50], "p95_ms": timings[95], "stamps": source.ground_pixels.size()}))
	if "--frame-perf" in OS.get_cmdline_user_args():
		await _frame_perf(target, source)
	print("BLOOD_TRANSFORM_RESULT checks=%d failures=%d" % [checks, failures])
	parent.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _compare(target: BlackBloodEffect, source: BlackBloodEffect, label: String) -> void:
	target.set_meta(&"test_uncached_ground_transforms", true)
	var old := target._ground_cells_in_target(source)
	target.set_meta(&"test_uncached_ground_transforms", false)
	var current := target._ground_cells_in_target(source)
	_check(old == current, label)

func _frame_perf(target: BlackBloodEffect, source: BlackBloodEffect) -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	DisplayServer.window_set_size(Vector2i(2560, 1440))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world: Node3D = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	_check(world.regenerate(120), "Generate fixed render fixture")
	for i in 30:
		await process_frame
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	display._process(0.0)
	world.room_visibility._update_outside_mask()
	paused = true
	for legacy in [true, false, true]:
		target.set_meta(&"test_uncached_ground_transforms", legacy)
		var warm_until := Time.get_ticks_usec() + 2000000
		while Time.get_ticks_usec() < warm_until:
			target._ground_cells_in_target(source)
			await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		var until := Time.get_ticks_usec() + 10000000
		var previous := Time.get_ticks_usec()
		while Time.get_ticks_usec() < until:
			target._ground_cells_in_target(source)
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			previous = now
		samples.sort()
		print("BLOOD_TRANSFORM_FRAME_PERF ", JSON.stringify({"legacy": legacy, "median_ms": samples[samples.size()/2], "p95_ms": samples[floori(samples.size()*0.95)], "samples": samples.size(), "rasterizations_per_frame": 1, "stamps": source.ground_pixels.size(), "frozen_gameplay": true, "seconds": 10, "warmup_seconds": 2, "gpu": RenderingServer.get_video_adapter_name()}))
	paused = false
	display.queue_free()
	for i in 4:
		await process_frame
