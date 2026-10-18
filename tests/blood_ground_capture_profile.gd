extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings: Node = root.get_node("SettingsManager"); var saved: Dictionary=settings.values.duplicate(true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(42001): quit(2); return
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(not "--no-pixelation" in OS.get_cmdline_user_args())
	display.set_palette_enabled(not "--no-palette" in OS.get_cmdline_user_args()); display._process(0.0)
	paused=true
	var pool: Node3D=world._get_blood_ground_capture_pool()
	var sources: Array[BlackBloodEffect] = []
	for index in 24:
		var blood := BlackBloodEffect.new(); world.world_effects_root.add_child(blood)
		blood.add_to_group(&"black_blood_stains"); blood.set_meta(&"blood_floor_visual",true)
		blood.office_pool_core=index>=18; blood.set_surface_context(world,world.current_room_id)
		blood.set_process(false); blood.position=world.player.global_position+Vector2((index%6-3)*24,(index/6-2)*24)
		for cell in [Vector2.ZERO,Vector2(3,2),Vector2(4,0)]:
			blood.ground_pixels.append(cell); blood.ground_pixel_types.append(index%5)
		blood.hide(); sources.append(blood)
	for index in 3: await RenderingServer.frame_post_draw
	var empty: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	var images: Array[PackedByteArray] = []
	for group in 3:
		var samples: Array[float] = []
		for iteration in 12:
			var bridges: Array[Node3D] = []
			for blood in sources: blood.show(); blood.queue_redraw()
			var started := Time.get_ticks_usec()
			for blood in sources:
				var bridge: Node3D
				if group==1: bridge=pool.acquire(blood,world.camera_3d,world.BLOOD_FLOOR_WORLD_Y)
				else:
					var extent := 112 if blood.office_pool_core else 64
					bridge=world._spawn_depth_bridge(blood,[^"."],Vector2(extent,extent),BaseMaterial3D.BILLBOARD_DISABLED,world.BLOOD_FLOOR_WORLD_Y,0.0,Vector3(-PI*.5,0,0),false,true)
				bridges.append(bridge)
			if iteration>=2: samples.append((Time.get_ticks_usec()-started)/1000.0)
			await RenderingServer.frame_post_draw
			if iteration==11:
				var visible_count := 0
				for bridge in bridges:
					if bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(): visible_count+=1
				print("BLOOD_GROUND_NONEMPTY group=",group," count=",visible_count)
				if visible_count!=24: failures+=1
				images.append(display.world_viewport.get_texture().get_image().get_data())
			for index in sources.size():
				var bridge := bridges[index]; var blood := sources[index]
				if blood.tree_exiting.is_connected(bridge._on_source_tree_exiting): blood.tree_exiting.disconnect(bridge._on_source_tree_exiting)
				bridge.suspend_projectile()
				if group==1: pool.release(bridge)
				else: bridge.queue_free()
				blood.hide()
			for index in 3: await process_frame
		samples.sort()
		print("BLOOD_GROUND_CAPTURE group=",group," median_creation_ms=",samples[5]," max_creation_ms=",samples.back())
	if images[0]!=images[1] or images[0]!=images[2]: failures+=1; push_error("Formal camera byte mismatch")
	if images[0]==empty: failures+=1; push_error("Blood not visible in formal camera")
	settings.values=saved; paused=false; display.queue_free()
	for index in 4: await process_frame
	print("BLOOD_GROUND_CAPTURE failures=",failures)
	quit(1 if failures else 0)
