extends SceneTree

var checks := 0
var failures := 0
var bullets: Array[Node2D] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func bridge(shot: Node2D) -> Node3D:
	return shot.get_meta(&"depth_visual_bridge").get_ref()

func update_steps(legacy: bool, terminal: bool = false, steps: int = 2) -> void:
	for i in bullets.size():
		var shot := bullets[i]
		shot.set_meta(&"test_legacy_tracer_steps", legacy)
		shot.consumed = terminal
		for step in steps:
			shot._trail_clock = 0.06 + float(step)*0.005
			shot._trail_history.clear()
			for j in 5:
				var offset := Vector2.from_angle(shot.rotation + float(j%2)*0.12)*float(4-j)*22.5
				shot._trail_history.append({"position":shot.global_position-offset,"time":shot._trail_clock-0.06+float(j)*0.015})
			shot._request_office_tracer_update()
		bridge(shot)._process(0.0)

func draw() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	world = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	check(world.regenerate(120), "Generate same camera fixture")
	for i in 30:
		await process_frame
	for room in world.rooms:
		if String(room.get("sample_key","")) == "office":
			world.player.global_position = Vector2(room.grid_rect.get_center())*32.0
			break
	world.camera_aim_offset = Vector3.ZERO
	world._update_camera_and_actor_projection(0.0)
	world.room_visibility._update_outside_mask()
	paused = true
	for i in 18:
		var shot: Node2D = load("res://scenes/entities/basic_projectile.tscn").instantiate()
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		shot.position = world.player.get_projectile_origin()+Vector2(i%6-3,i/6-1)*40.0
		shot.setup(Vector2.from_angle(float(i)*TAU/18.0),1.0)
		world.add_projectile(shot,world.player)
		bullets.append(shot)
	for steps in [1,2,4]:
		for terminal in [false,true]:
			update_steps(true, terminal, steps)
			var expected: Array = []
			for shot in bullets:
				var sprite: Sprite2D = shot.get_node("BulletSprite")
				expected.append([sprite.texture.get_image().get_data(),sprite.position,sprite.material.get_shader_parameter(&"head_uv")])
			update_steps(false, terminal, steps)
			for i in bullets.size():
				var shot := bullets[i]
				var sprite: Sprite2D = shot.get_node("BulletSprite")
				check(expected[i]==[sprite.texture.get_image().get_data(),sprite.position,sprite.material.get_shader_parameter(&"head_uv")],"Exact latest capture, steps%d terminal%d bullet%d"%[steps,int(terminal),i])
				check(not shot._office_tracer_update_pending, "Bridge consumes pending work before sync")
	for pixelation in [false,true]:
		for palette in [false,true]:
			display.set_selective_enabled(pixelation)
			display.set_palette_enabled(palette)
			display._process(0.0)
			var images: Array[Image] = []
			for legacy in [true,false,true]:
				update_steps(legacy)
				images.append(await draw())
			check(images[0].get_data()==images[1].get_data() and images[0].get_data()==images[2].get_data(),"First displayed pixels match pixel%d palette%d"%[int(pixelation),int(palette)])
	# Later same-frame request must not be swallowed by an earlier flush.
	var shot := bullets[0]
	shot.set_meta(&"test_legacy_tracer_steps", false)
	shot._trail_clock += 0.001
	shot._request_office_tracer_update()
	check(shot._office_tracer_update_pending,"Late request queues fresh work")
	bridge(shot)._process(0.0)
	check(not shot._office_tracer_update_pending,"Late request is consumed")
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	display._process(0.0)
	if "--frame-perf" in OS.get_cmdline_user_args():
		for legacy in [true,false,true]:
			var start := Time.get_ticks_usec()
			var previous := start
			var samples: Array[float] = []
			while Time.get_ticks_usec()-start < 12000000:
				update_steps(legacy)
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				if now-start>=2000000:
					samples.append(float(now-previous)/1000.0)
				previous = now
			samples.sort()
			print("TRACER_STEP_FRAME_PERF ",JSON.stringify({"legacy":legacy,"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*0.95)],"bullets":18,"steps_per_frame":2,"seconds":10,"warmup_seconds":2,"frozen_gameplay":true,"gpu":RenderingServer.get_video_adapter_name()}))
	settings.values = saved
	paused = false
	display.queue_free()
	for i in 4:
		await process_frame
	print("TRACER_STEP_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
