extends SceneTree
var failures:=0
var bridges: Array[Node]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var world: Node3D=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	world.set_meta(&"test_legacy_shell_atlas",true)
	if not world.regenerate(120): quit(1); return
	for index in 30: await process_frame
	for room in world.rooms:
		if String(room.get("sample_key",""))=="office": world.player.global_position=Vector2(room.grid_rect.get_center())*32.0; break
	world.camera_aim_offset=Vector3.ZERO; world.transition_phase=&"IDLE"
	world._update_camera_and_actor_projection(0.0); world.room_visibility._update_outside_mask()
	paused=true
	for node in world.find_children("*","CanvasItem",true,false):
		var material := node.material as ShaderMaterial
		if material!=null and material.shader!=null and "uniform bool shine_enabled" in material.shader.code: material.set_shader_parameter("shine_enabled",false)
	await RenderingServer.frame_post_draw
	var empty := root.get_texture().get_image().get_data()
	var effects: Array[Node2D]=[]
	for index in 36:
		var offset:=Vector2.ZERO if "--overlap" in OS.get_cmdline_user_args() else Vector2(index%6,index/6)*24.0
		world.spawn_shell_ejection(world.player.global_position+offset,Vector2.RIGHT.rotated(index*TAU/8.0),[&"basic",&"assault_rifle",&"shotgun"][index%3])
		var source: Node2D=world.world_effects_root.get_children().back()
		if not source is DreamShellEffect: push_error("Fixture did not spawn a real casing"); quit(1); return
		effects.append(source)
		var reference: WeakRef=source.get_meta(&"depth_visual_bridge")
		bridges.append(reference.get_ref())
	var candidate: Node=load("res://tests/shell_capture_atlas_candidate.gd").new()
	# The shared capture is a child of the formal world viewport, just like
	# individual captures. A root-viewport sibling renders too late for the
	# world's first frame and can falsely appear faster by hiding all casings.
	world.actor_depth_bridges_root.add_child(candidate)
	# Fresh images at birth, mid-flight and settled. Geometry/state is shared;
	# switching only reparents passive captures, never sources.
	for stage in 3:
		if stage>0:
			for step in (12 if stage==1 else 48):
				for source in effects: source._process(1.0/60.0)
		var images: Array[PackedByteArray]=[]
		for shared in [false,true,false]:
			if shared: candidate.enable(bridges)
			if shared: candidate.sync()
			else:
				for bridge in bridges: bridge._process(0.0)
			await RenderingServer.frame_post_draw
			if shared:
				candidate.atlas.get_texture().get_image().save_png("res://.runtime/furniture_face_review/shell_atlas_capture_%d.png"%stage)
			images.append(root.get_texture().get_image().get_data())
			root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/shell_atlas_%d_%d.png"%[stage,images.size()])
			if shared: root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/shell_atlas_%d.png"%stage)
			if shared: candidate.restore()
		if images[0]==empty: failures+=1; push_error("Shell comparison has no visible shells")
		if images[0]!=images[1] or images[0]!=images[2]: failures+=1; push_error("Atlas changes camera pixels stage %d"%stage)
	for shared in ([] if "--image-only" in OS.get_cmdline_user_args() else [false,true,false]):
		if shared: candidate.enable(bridges)
		var samples: Array[float]=[]
		var start:=Time.get_ticks_usec(); var previous:=start
		while Time.get_ticks_usec()-start<12000000:
			if shared: candidate.sync()
			else:
				for bridge in bridges: bridge._process(0.0)
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if now-start>=2000000: samples.append(float(now-previous)/1000.0)
			previous=now
		samples.sort()
		print("SHELL_ATLAS_FRAME ",JSON.stringify({"shared":shared,"shells":bridges.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"warmup_seconds":2,"sample_seconds":10,"frozen_gameplay":true}))
		if shared: candidate.restore()
	print("SHELL_ATLAS_RESULT failures=",failures)
	candidate.queue_free(); paused=false; display.queue_free()
	for index in 4: await process_frame
	quit(1 if failures else 0)
