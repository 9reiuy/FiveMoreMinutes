extends SceneTree
## Frozen formal GPU scene: attribute CPU work, not total FPS acceptance.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(41001): quit(1); return
	world.player.global_position=Vector2(800,1536); world.player.invulnerability_left=999
	for frame in 30: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	paused=true
	for frame in 8: await RenderingServer.frame_post_draw
	var characters: Array=[]
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get_script()==preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd") and bridge.character_projection:
			characters.append(bridge)
	if characters.is_empty(): push_error("No formal actor workload"); quit(1); return
	for operation in ["full","tree","snapshot","planes","volume","full_repeat"]:
		var samples: Array[float]=[]
		for sample in 24:
			var started:=Time.get_ticks_usec()
			for iteration in 10:
				for bridge in characters:
					match operation:
						"full","full_repeat": bridge._process(0.0)
						"tree":
							for index in bridge.source_roots.size(): bridge._sync_node(bridge.source_roots[index],bridge.clone_roots[index])
						"snapshot": bridge._weapon_visual_snapshot_synced(bridge.source_actor.global_position,world.camera_3d)
						"planes": bridge._sync_character_planes(world.camera_3d,bridge._source_fake_height_pixels())
						"volume": bridge._sync_volume_shadow(world.camera_3d,bridge._source_fake_height_pixels())
			samples.append((Time.get_ticks_usec()-started)/10000.0)
			await RenderingServer.frame_post_draw
			samples.sort()
		print("ACTOR_CAPTURE_COST ",JSON.stringify({"operation":operation,"actors":characters.size(),"median_ms":samples[12],"p95_ms":samples[22],"samples":24,"gpu":RenderingServer.get_video_adapter_name()}))
	paused=false; display.queue_free()
	for frame in 4: await process_frame
	quit(0)
