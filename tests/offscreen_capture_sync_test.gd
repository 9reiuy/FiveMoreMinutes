extends SceneTree
var failures:=0
var checks:=0
var bridges: Array[Node]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func sync(legacy: bool) -> void:
	for bridge in bridges:
		bridge.set_meta(&"test_legacy_offscreen_capture_sync",legacy)
		bridge._process(0.0)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var settings:=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(120),"Generate fixture")
	for index in 30: await process_frame
	bridges.append(world.player_depth_bridge)
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("character_projection")==true: bridges.append(bridge)
	var centre:=Vector2.ZERO
	for room in world.rooms:
		if String(room.get("sample_key",""))=="office": centre=Vector2(room.grid_rect.get_center())*32.0; break
	for index in bridges.size():
		bridges[index].source_actor.global_position=centre+Vector2(index%4-2,index/4-2)*48.0
		bridges[index].set_meta(&"test_capture_sync_skipped",false)
	world.camera_aim_offset=Vector3.ZERO; world.transition_phase=&"IDLE"
	world._update_camera_and_actor_projection(0.0); world.room_visibility._update_outside_mask()
	paused=true
	sync(false)
	check(bridges.all(func(b: Node)->bool:return world.camera_3d.get_viewport().get_visible_rect().has_point(world.camera_3d.unproject_position(b.actor_sprite.global_position))),"Comparison subjects actually inside camera, not only the margin")
	var homes: Array[Vector2]=[]
	for bridge in bridges: homes.append(bridge.source_actor.global_position)
	for phase in 8:
		var images: Array[Image]=[]
		for legacy in [true,false,true]:
			for index in bridges.size():
				bridges[index].source_actor.global_position=homes[index]
				bridges[index].source_actor.get_node("WeaponRoot").rotation=0.0
				sync(true)
			for index in bridges.size():
				bridges[index].source_actor.global_position=homes[index]+Vector2(4000,0)
				bridges[index].source_actor.get_node("WeaponRoot").rotation=float(phase)*TAU/8.0
				sync(legacy)
			check(legacy or bridges.all(func(b: Node)->bool:return b.get_meta(&"test_capture_sync_skipped")),"Far actors skip captures phase%d"%phase)
			for index in bridges.size(): bridges[index].source_actor.global_position=homes[index]
			sync(legacy)
			check(bridges.all(func(b: Node)->bool:return not b.get_meta(&"test_capture_sync_skipped")),"First reentry fully syncs phase%d"%phase)
			await RenderingServer.frame_post_draw
			images.append(root.get_texture().get_image())
		check(images[0].get_data()==images[1].get_data(),"Reentry pixels direction%d"%phase)
		check(images[0].get_data()==images[2].get_data(),"Old repeat pixels direction%d"%phase)
		if phase==0:
			images[0].save_png("res://.runtime/furniture_face_review/offscreen_first_frame_old.png")
			images[1].save_png("res://.runtime/furniture_face_review/offscreen_first_frame_new.png")
	for index in bridges.size(): bridges[index].source_actor.global_position=homes[index]+Vector2(4000,0)
	var body: Node2D=world.player.get_node("CharacterVisual")
	body.rotation=1.0; sync(false)
	check(not world.player_depth_bridge.get_meta(&"test_capture_sync_skipped"),"Rotated character keeps full contact sync")
	body.rotation=0.0
	var enemy: Node2D=bridges[1].source_actor
	enemy.dead=true
	sync(false)
	check(not bridges[1].get_meta(&"test_capture_sync_skipped"),"Offscreen dead enemy keeps fresh contact pixels")
	enemy.dead=false
	var player_bridge: Node3D=world.player_depth_bridge
	world.player.global_position=homes[0]
	sync(false)
	var view_rect: Rect2=world.camera_3d.get_viewport().get_visible_rect()
	var base_screen: Vector2=world.camera_3d.unproject_position(player_bridge.actor_sprite.global_position)
	var local_right: Vector3=player_bridge.get_parent_node_3d().global_basis.inverse()*world.camera_3d.global_basis.x
	var step:=Vector2(local_right.x,local_right.z)*32.0
	world.player.global_position=homes[0]+step
	sync(false)
	var step_pixels: float=world.camera_3d.unproject_position(player_bridge.actor_sprite.global_position).x-base_screen.x
	check(absf(step_pixels)>0.01,"Usable formal screen-axis mapping")
	for margin in [159.0,161.0]:
		world.player.global_position=homes[0]+step*((view_rect.end.x+margin-base_screen.x)/step_pixels)
		sync(false)
		var measured: Vector2=world.camera_3d.unproject_position(player_bridge.actor_sprite.global_position)
		check(absf(measured.x-(view_rect.end.x+margin))<0.1,"Boundary fixture is at exact requested pixel")
		check(bool(player_bridge.get_meta(&"test_capture_sync_skipped"))==(margin>160.0),"Exact existing 160px capture margin")
	for index in bridges.size(): bridges[index].source_actor.global_position=homes[index]
	for pixelation in [false,true]:
		for palette in [false,true]:
			display.set_selective_enabled(pixelation); display.set_palette_enabled(palette); display._process(0.0)
			var images: Array[Image]=[]
			for legacy in [true,false,true]:
				for index in bridges.size(): bridges[index].source_actor.global_position=homes[index]+Vector2(4000,0)
				sync(legacy)
				for index in bridges.size(): bridges[index].source_actor.global_position=homes[index]
				sync(legacy)
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image())
			check(images[0].get_data()==images[1].get_data(),"First reentry frame pixel%d palette%d"%[int(pixelation),int(palette)])
			check(images[0].get_data()==images[2].get_data(),"First reentry old repeat pixel%d palette%d"%[int(pixelation),int(palette)])
	for index in bridges.size(): bridges[index].source_actor.global_position=homes[index]+Vector2(4000,0)
	if "--frame-perf" in OS.get_cmdline_user_args():
		for legacy in [true,false,true]:
			var start:=Time.get_ticks_usec(); var previous:=start
			var samples: Array[float]=[]
			while Time.get_ticks_usec()-start<12000000:
				sync(legacy); await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				if now-start>=2000000: samples.append(float(now-previous)/1000.0)
				previous=now
			samples.sort()
			print("OFFSCREEN_FRAME_PERF ",JSON.stringify({"legacy":legacy,"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"characters":bridges.size(),"frozen_gameplay":true,"seconds":10,"warmup_seconds":2}))
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("OFFSCREEN_CAPTURE_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
