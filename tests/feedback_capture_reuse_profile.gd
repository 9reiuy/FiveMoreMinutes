extends SceneTree
## Same live source objects across old/reused/old. Display-only diagnostic,
## not production integration and not a sustained combat performance claim.
var failures := 0
func _initialize() -> void: call_deferred("run")
func detach(bridge: Node3D, source: Node2D) -> void:
	if source.tree_exiting.is_connected(bridge._on_source_tree_exiting): source.tree_exiting.disconnect(bridge._on_source_tree_exiting)
	bridge.suspend_projectile()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node=root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(41001): quit(2); return
	for index in 30: await process_frame
	world.player.global_position=world.enemy_root.get_child(0).global_position+Vector2(96,0)
	world.transition_phase=&"IDLE"; world.camera_aim_offset=Vector3.ZERO; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(not "--no-pixelation" in OS.get_cmdline_user_args())
	display.set_palette_enabled(not "--no-palette" in OS.get_cmdline_user_args()); display._process(0.0)
	paused=true
	var sources: Array[Node2D]=[]
	var pool: Node3D=world._get_feedback_capture_pool()
	for index in 18:
		var effect: Node2D=world.COMBAT_FEEDBACK_SCENE.instantiate()
		world.world_effects_root.add_child(effect)
		effect.global_position=world.player.global_position+Vector2((index%6-3)*40,(index/6-1)*40)
		effect.setup(Vector2.RIGHT.rotated(float(index)*TAU/8.0),index%2==0,0.18)
		effect.hide(); sources.append(effect)
	for index in 4: await RenderingServer.frame_post_draw
	var empty_image: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var images: Array[PackedByteArray]=[]
	for group in 3:
		var samples: Array[float]=[]
		for iteration in 12:
			var current: Array[Node3D]=[]
			for effect in sources: effect.elapsed=0.0; effect.show(); effect.queue_redraw()
			var started: int=Time.get_ticks_usec()
			for index in sources.size():
				var bridge: Node3D
				if group==1:
					bridge=pool.acquire(sources[index],world.camera_3d)
				else:
					bridge=world._spawn_depth_bridge(sources[index],[^"."],Vector2(64,64),BaseMaterial3D.BILLBOARD_ENABLED,0.14,0.0,Vector3.ZERO,false)
				current.append(bridge)
			if iteration>=2: samples.append(float(Time.get_ticks_usec()-started)/1000.0)
			await RenderingServer.frame_post_draw
			if iteration==11:
				var visible_capture_count := 0
				for bridge in current:
					if bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(): visible_capture_count+=1
				print("FEEDBACK_NONEMPTY_CAPTURES group=",group," count=",visible_capture_count)
				if visible_capture_count==0: failures+=1
			if iteration==11:
				for elapsed in [0.0,0.05,0.1]:
					for effect in sources: effect.elapsed=elapsed; effect.queue_redraw()
					for bridge in current: bridge._process(0.0)
					await RenderingServer.frame_post_draw
					images.append(display.world_viewport.get_texture().get_image().get_data())
			for index in sources.size():
				detach(current[index],sources[index])
				if group!=1: current[index].queue_free()
				else: pool.release(current[index])
				sources[index].hide()
			for index in 3: await process_frame
		samples.sort()
		print("FEEDBACK_CAPTURE_REUSE ",JSON.stringify({"group":group,"reused":group==1,"effects":18,"creation_only_ms_median":samples[5],"creation_only_ms_max":samples.back(),"frozen_gameplay":true,"gpu":RenderingServer.get_video_adapter_name()}))
	for stage in 3:
		for group in [1,2]:
			var same: bool=images[stage]==images[group*3+stage]
			print("FEEDBACK_CAPTURE_IMAGE stage=",stage," group=",group," same=",same)
			if not same: failures+=1
	for group in 3:
		if images[group*3]==empty_image: failures+=1; push_error("Feedback missing from formal camera image")
	for source in sources: source.queue_free()
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("FEEDBACK_CAPTURE_RESULT failures=",failures)
	quit(1 if failures else 0)
