extends SceneTree

class CountedBlood extends BlackBloodEffect:
	var draw_count := 0
	func _draw() -> void:
		draw_count += 1
		super._draw()

var checks := 0
var failures := 0
var source: BlackBloodEffect
var targets: Array[CountedBlood] = []
var viewports: Array[SubViewport] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func draw() -> void:
	for i in 2:
		await RenderingServer.frame_post_draw

func compare(label: String) -> void:
	for i in 2:
		source.set_meta(&"test_legacy_ground_redraw",i==0)
		source.copy_depth_visual_state_to(targets[i])
	await draw()
	check(viewports[0].get_texture().get_image().get_data()==viewports[1].get_texture().get_image().get_data(),label)

func run() -> void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	source = BlackBloodEffect.new()
	root.add_child(source)
	source.set_process(false)
	source.hide()
	for i in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256,256)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var target := CountedBlood.new()
		target.process_mode = Node.PROCESS_MODE_DISABLED
		target.set_depth_replica(true)
		target.set_meta(&"blood_ground_only_capture",true)
		target.position = Vector2(128,128)
		viewport.add_child(target)
		targets.append(target)
	for y in range(-20,20):
		for x in range(-20,20):
			source.ground_pixels.append(Vector2(x,y))
			source.ground_pixel_types.append(BlackBloodEffect.StampType.CORE_SPLAT)
	await compare("Initial payload")
	var old_count := targets[0].draw_count
	var new_count := targets[1].draw_count
	for i in 8:
		await compare("Unchanged payload %d"%i)
	check(targets[0].draw_count==old_count+8 and targets[1].draw_count==new_count,"Only legacy redraws unchanged ground")
	for phase in 12:
		match phase:
			0: source.ground_pixels[0] = Vector2(-45,-45)
			1: source.ground_pixel_types[1] = BlackBloodEffect.StampType.PIXEL_CELL
			2: source.ground_visual_scale = 1.3
			3: source.office_pool_core = true
			4:
				source.ground_bounds_enabled = true
				source.ground_bounds_local = Rect2(-16,-16,32,32)
			5: source.ground_bounds_local = Rect2(-10,-10,20,20)
			6:
				source.pool_growth_active = true
				for target in targets:
					target._pool_growth_cells.append(Vector2.ZERO)
			7: source.pool_growth_elapsed = 0.03
			8: source.pool_growth_duration = 0.1
			9: source.self_modulate.a = 0.5
			10:
				source.airborne_pixels.append({"position":Vector2.ZERO,"height":5.0,"velocity":Vector2.RIGHT*100,"vertical":20.0})
			11:
				source.ground_pixels.clear()
				source.ground_pixel_types.clear()
		await compare("Mutation %d"%phase)
		check(targets[1].airborne_pixels.is_empty(),"Ground capture never restores airborne ghost")
	# Stationary ground with changing airborne simulation remains a valid no-redraw.
	source.pool_growth_active = false
	source.self_modulate.a = 1.0
	source.ground_bounds_enabled = false
	source.ground_visual_scale = 1.0
	for y in range(-20,20):
		for x in range(-20,20):
			source.ground_pixels.append(Vector2(x,y))
			source.ground_pixel_types.append(BlackBloodEffect.StampType.CORE_SPLAT)
	await compare("Reset pressure payload")
	if "--frame-perf" in OS.get_cmdline_user_args():
		for legacy in [true,false,true]:
			source.set_meta(&"test_legacy_ground_redraw",legacy)
			var start := Time.get_ticks_usec()
			var previous := start
			var samples: Array[float] = []
			while Time.get_ticks_usec()-start < 12000000:
				source.copy_depth_visual_state_to(targets[1])
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				if now-start>=2000000:
					samples.append(float(now-previous)/1000.0)
				previous = now
			samples.sort()
			print("GROUND_REDRAW_FRAME_PERF ",JSON.stringify({"legacy":legacy,"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*0.95)],"stamps":1600,"copies_per_frame":1,"draws":targets[1].draw_count,"gpu":RenderingServer.get_video_adapter_name()}))
	for viewport in viewports:
		viewport.queue_free()
	source.queue_free()
	await process_frame
	if "--formal-frame-perf" in OS.get_cmdline_user_args() or "--formal-pixels" in OS.get_cmdline_user_args():
		await formal_frame_perf()
	print("GROUND_REDRAW_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)

func formal_frame_perf() -> void:
	var settings := root.get_node("SettingsManager")
	var saved: Dictionary = settings.values.duplicate(true)
	var world: Node3D = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	check(world.regenerate(120),"Generate formal camera fixture")
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
	var bloods: Array[BlackBloodEffect] = []
	var bridges: Array[Node3D] = []
	for i in 4:
		var blood := BlackBloodEffect.new()
		blood.position = world.player.global_position+Vector2(i%2-1,i/2-1)*70.0
		blood.process_mode = Node.PROCESS_MODE_DISABLED
		world._add_3d_blood_effect(blood,1,true)
		for y in range(-20,20):
			for x in range(-20,20):
				blood.ground_pixels.append(Vector2(x,y))
				blood.ground_pixel_types.append(BlackBloodEffect.StampType.CORE_SPLAT)
		bloods.append(blood)
		bridges.append(blood.get_meta(&"depth_visual_bridge").get_ref())
	for pixelation in [false,true]:
		for palette in [false,true]:
			display.set_selective_enabled(pixelation)
			display.set_palette_enabled(palette)
			display._process(0.0)
			var images: Array[Image] = []
			for legacy in [true,false,true]:
				for i in bloods.size():
					bloods[i].set_meta(&"test_legacy_ground_redraw",legacy)
					bridges[i]._process(0.0)
				await draw()
				images.append(root.get_texture().get_image())
				if not legacy and pixelation and not palette:
					images.back().save_png("res://.runtime/furniture_face_review/blood_ground_redraw_new.png")
			check(images[0].get_data()==images[1].get_data() and images[0].get_data()==images[2].get_data(),"Formal camera pixel%d palette%d"%[int(pixelation),int(palette)])
	for bridge in bridges:
		var capture: Image = bridge.render_viewport.get_texture().get_image()
		check(capture.get_pixelv(Vector2i(bridge.viewport_offset)).a>0.5,"Capture comparison contains actual blood")
		var projected: Vector2 = world.camera_3d.unproject_position(bridge.actor_sprite.global_position)
		check(world.camera_3d.get_viewport().get_visible_rect().has_point(projected) and not world.camera_3d.is_position_behind(bridge.actor_sprite.global_position),"Blood fixture is inside the formal camera")
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	display._process(0.0)
	for legacy in [true,false,true]:
		for blood in bloods:
			blood.set_meta(&"test_legacy_ground_redraw",legacy)
		var start := Time.get_ticks_usec()
		var previous := start
		var samples: Array[float] = []
		var duration := 0 if "--formal-pixels" in OS.get_cmdline_user_args() else 12000000
		while Time.get_ticks_usec()-start < duration:
			for bridge in bridges:
				bridge._process(0.0)
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if now-start>=2000000:
				samples.append(float(now-previous)/1000.0)
			previous = now
		if samples.is_empty():
			continue
		samples.sort()
		print("GROUND_REDRAW_FORMAL_FRAME ",JSON.stringify({"legacy":legacy,"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*0.95)],"stamps_per_effect":1600,"effects":4,"syncs_per_frame":1,"frozen_gameplay":true,"seconds":10,"warmup_seconds":2,"output":root.get_texture().get_size(),"gpu":RenderingServer.get_video_adapter_name()}))
	paused = false
	settings.values = saved
	display.queue_free()
	for i in 4:
		await process_frame
