extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	print("DEBRIS_STAGE start")
	AudioServer.set_bus_mute(0,true)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	print("DEBRIS_STAGE display_ready")
	if not world.regenerate(42001): quit(2); return
	print("DEBRIS_STAGE generated")
	for index in 20: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(false); display._process(0.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	paused=true
	print("DEBRIS_STAGE spawn")
	var bridges: Array = []
	for index in 84:
		var source: Node2D = world.ENVIRONMENT_DEBRIS_SCENE.instantiate()
		world.ground_debris_root.add_child(source); source.monitoring=false; source.set_physics_process(false)
		source.global_position = world.player.global_position + Vector2((index%12-6)*26,(index/12-3)*26)
		source.sprite.frame = index%42; source.sprite.rotation = (index%4)*PI*.5
		bridges.append(world._spawn_depth_bridge(source,[^"Sprite2D"],Vector2(64,64),BaseMaterial3D.BILLBOARD_DISABLED,.02,0.0,Vector3(-PI/2,0,0),true))
	print("DEBRIS_STAGE spawned")
	for index in 5: await RenderingServer.frame_post_draw
	print("DEBRIS_STAGE first_draw")
	for index in [0,4,8]:
		var bridge: Node = bridges[index]
		var capture: Image = bridge.render_viewport.get_texture().get_image()
		var atlas: Image = bridge.source_actor.sprite.texture.get_image()
		var frame: int = bridge.source_actor.sprite.frame
		var rows: Array = []
		for y in 32:
			for x in 32:
				var a := atlas.get_pixel((frame%7)*32+x,(frame/7)*32+y)
				if a.a > .8 and rows.size()<6:
					rows.append({"atlas":a,"capture":capture.get_pixel(48+x,48+y)})
		print("DEBRIS_COLOR_SAMPLES ",JSON.stringify({"frame":frame,"samples":rows}))
	var candidate: Node3D = (preload("res://tests/environment_debris_shared_texture_candidate.gd") if "--shared-texture" in OS.get_cmdline_user_args() else preload("res://tests/environment_debris_atlas_candidate.gd")).new()
	world.actor_depth_bridges_root.add_child(candidate); candidate.build(bridges)
	print("DEBRIS_STAGE candidate_built")
	var images: Array[Image] = []
	for enabled in [false,true,false]:
		candidate.set_enabled(enabled)
		for index in 5: await RenderingServer.frame_post_draw
		images.append(display.world_viewport.get_texture().get_image())
		images.back().save_png("res://.runtime/furniture_face_review/debris_direct_%d.png"%(images.size()-1))
	var different := 0; var repeat_difference := 0
	var before := images[0].get_data(); var after := images[1].get_data(); var repeated := images[2].get_data()
	for index in range(0,before.size(),4):
		if before.slice(index,index+4)!=after.slice(index,index+4): different+=1
		if before.slice(index,index+4)!=repeated.slice(index,index+4): repeat_difference+=1
	print("DEBRIS_DIRECT_PIXELS ",JSON.stringify({"candidate_different":different,"original_repeat_different":repeat_difference,"objects":84}))
	if different>0 or repeat_difference>0: failures+=1; push_error("Direct atlas does not preserve Camera pixels")
	for enabled in ([] if "--image-only" in OS.get_cmdline_user_args() else [false,true,false]):
		candidate.set_enabled(enabled)
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec()-start<2000000: await RenderingServer.frame_post_draw
		var frames: Array=[]; var draws: Array=[]
		start=Time.get_ticks_usec(); var previous:=start
		while Time.get_ticks_usec()-start<8000000:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		frames.sort(); draws.sort()
		print("DEBRIS_DIRECT_FRAME ",JSON.stringify({"candidate":enabled,"median_ms":frames[frames.size()/2],"p95_ms":frames[floori(frames.size()*.95)],"draw_calls":draws[draws.size()/2],"frozen_gameplay":true}))
	candidate.set_enabled(false); candidate.queue_free(); paused=false; display.queue_free()
	for index in 4: await process_frame
	print("DEBRIS_DIRECT_RESULT failures=",failures)
	quit(1 if failures else 0)
