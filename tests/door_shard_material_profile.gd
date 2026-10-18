extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	check(world.regenerate(42001), "Formal floor generated")
	for index in 8: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	paused=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	for metal in [false, true]:
		var poses: Array=[]
		var images: Array=[]
		for retained in [false,true,false]:
			if not retained: PhysicalDoor3D.shard_shader_anchors.clear()
			var door:=PhysicalDoor3D.new()
			door.set_meta(&"office_metal_door",metal)
			door.set_meta(&"test_legacy_door_shard_lifetime",not retained)
			world.add_child(door)
			door.global_position=world.player_depth_bridge.actor_sprite.global_position
			if is_instance_valid(door.door_visual): door.door_visual.visible=false
			var values: Array[float]=[]
			for iteration in 24:
				for frame in 4: await RenderingServer.frame_post_draw
				seed(3320+iteration)
				var started:=Time.get_ticks_usec()
				door._spawn_wood_shards(Vector2.RIGHT)
				await RenderingServer.frame_post_draw
				values.append((Time.get_ticks_usec()-started)/1000.0)
				var shards: Node3D=door.get_node("DoorShards")
				check(shards.get_child_count()==10,"Original ten fragments")
				if iteration==23:
					var pose: Array=[]
					for shard in shards.get_children():
						pose.append([shard.position,shard.rotation,shard.mesh.size,shard.material_override.albedo_color,shard.material_override.specular_mode])
					poses.append(pose)
					images.append(display.world_viewport.get_texture().get_image().get_data())
				shards.free()
				for frame in 4: await process_frame
			values.sort()
			print("DOOR_SHARD_PROFILE ",JSON.stringify({"metal":metal,"retained":retained,"median_ms":values[12],"max_ms":values.back(),"p95_ms":values[22],"samples":24,"gpu":RenderingServer.get_video_adapter_name()}))
			door.free()
			for frame in 4: await process_frame
		check(poses[0]==poses[1] and poses[0]==poses[2],"Identical seeded geometry, color, specular")
		check(images[0]==images[1],"Formal camera original versus retained exact pixels")
		check(images[0]==images[2],"Original repeat exact pixels")
	PhysicalDoor3D.shard_shader_anchors.clear()
	paused=false; display.queue_free()
	for frame in 4: await process_frame
	print("DOOR_SHARD_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
