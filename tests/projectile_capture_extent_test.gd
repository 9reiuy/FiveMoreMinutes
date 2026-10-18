extends SceneTree
## Same live slots/RIDs and authoritative projectile state; only capture extent varies.
var checks := 0
var failures := 0
var world: Node3D
var display: Control
var bullets: Array[Node2D] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func resize_slots(size: int) -> void:
	for bullet in bullets:
		var bridge: Node3D = bullet.get_meta(&"depth_visual_bridge").get_ref()
		bridge.render_viewport.size = Vector2i(size,size)
		bridge.viewport_offset = Vector2(size,size)*0.5
		bridge._process(0.0)
func draw() -> Image:
	for index in 3: await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings := root.get_node("SettingsManager"); var saved: Dictionary = settings.values.duplicate(true)
	world = load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(120),"Sample generation")
	for index in 30: await process_frame
	for room in world.rooms:
		if String(room.get("sample_key","")) == "office": world.player.global_position=Vector2(room.grid_rect.get_center())*32.0; break
	world.transition_phase=&"IDLE"; world.camera_aim_offset=Vector3.ZERO
	world._update_camera_and_actor_projection(0.0); world.room_visibility._update_outside_mask()
	paused=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	for index in 18:
		var bullet: Node2D=load("res://scenes/entities/basic_projectile.tscn").instantiate()
		bullet.process_mode=Node.PROCESS_MODE_DISABLED
		bullet.position=world.player.get_projectile_origin()+Vector2(index%6-3,index/6-1)*40.0
		bullet.setup(Vector2.from_angle(index*TAU/18.0),1.0)
		world.add_projectile(bullet,world.player); bullets.append(bullet)
	# Exercise the full radial bound, turns and consumed terminal trails, not
	# only the usual straight 90px history. Keep the same depth plane throughout.
	for phase in 3:
		for index in bullets.size():
			var bullet := bullets[index]
			bullet._trail_clock=.06; bullet._trail_history.clear()
			if phase>0:
				for sample in 16:
					var angle: float=bullet.rotation + float(sample)*.1
					var offset := Vector2.from_angle(angle)*float(16-sample)*9.0
					bullet._trail_history.append({"position":bullet.global_position-offset,"time":float(sample)*.004})
			bullet.consumed=phase==2; bullet._update_office_tracer()
		for pixelation in [false,true]:
			for palette in [false,true]:
				display.set_selective_enabled(pixelation); display.set_palette_enabled(palette); display._process(0.0)
				var images: Array[Image]=[]
				for size in [512,256,512]: resize_slots(size); images.append(await draw())
				check(images[0].get_data()==images[1].get_data(),"Capture extent pixels phase%d pixel%d palette%d"%[phase,int(pixelation),int(palette)])
				check(images[0].get_data()==images[2].get_data(),"Old repeat pixels phase%d"%phase)
				if phase==1 and pixelation and palette: images[1].save_png("res://.runtime/furniture_face_review/capture_extent_256.png")
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	for bullet in bullets: bullet.consumed=false; bullet._update_office_tracer()
	for size in [512,256,512]:
		resize_slots(size); await draw()
		var started := Time.get_ticks_usec(); var previous := started; var samples: Array[float]=[]
		while Time.get_ticks_usec()-started < 12000000:
			for bullet in bullets: bullet.get_meta(&"depth_visual_bridge").get_ref()._process(0.0)
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if now-started>=2000000: samples.append(float(now-previous)/1000.0)
			previous=now
		samples.sort()
		print("CAPTURE_EXTENT_FRAME ",JSON.stringify({"size":size,"bullets":bullets.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"gpu":RenderingServer.get_video_adapter_name()}))
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("CAPTURE_EXTENT_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
