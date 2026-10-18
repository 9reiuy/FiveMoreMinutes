extends SceneTree
## Frozen formal world CPU synchronization diagnostic; not an FPS benchmark.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false
	world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world
	display.preview_mode=false
	root.add_child(display)
	world.regenerate(120)
	for index in 30: await process_frame
	var dressing: Node=world.get_node("SampleWallAndDesktopReview")
	dressing.refresh_assets()
	var window: Node3D=dressing.windows[0].wall.get_ref()
	var origin:=Vector2(window.position.x,window.position.z)*32.0
	for offset in [window.window_inward_normal*80.0,Vector2(0,80),Vector2(0,-80),Vector2(80,0),Vector2(-80,0)]:
		if world._content_position_is_clear(origin+offset,12.0): world.player.global_position=origin+offset; break
	world.camera_aim_offset=Vector3.ZERO
	world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	for index in 4: await process_frame
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.night_lighting.set_process(false)
	paused=true
	var bridges: Array[Node3D]=[]
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("configured")==true and bridge.get("character_projection")==true:
			bridges.append(bridge)
	var samples: Array[float]=[]
	var sync_samples: Array[float]=[]
	for index in 120:
		var started:=Time.get_ticks_usec()
		for bridge in bridges: bridge._process(0.0)
		if index>=20: samples.append(float(Time.get_ticks_usec()-started)/1000.0)
		started=Time.get_ticks_usec()
		for bridge in bridges:
			for item in bridge.source_roots.size(): bridge._sync_node(bridge.source_roots[item],bridge.clone_roots[item])
		if index>=20: sync_samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	samples.sort(); sync_samples.sort()
	print("CAPTURE_SYNC_BENCH ",JSON.stringify({"characters":bridges.size(),"samples":samples.size(),"process_median_ms":samples[50],"sync_median_ms":sync_samples[50],"process_p95_ms":samples[95]}))
	var failures := 0
	var images: Array[Image]=[]
	for legacy in [true,false,true]:
		world.set_meta(&"test_legacy_muzzle_capture",legacy)
		var muzzle_samples: Array[float]=[]
		for iteration in 12:
			var previous: Array=world.world_effects_root.get_children()
			var actor_position: Vector2=world.player.global_position
			var started:=Time.get_ticks_usec()
			for index in 6:
				# Separate actual formal muzzle snapshots, not merely the supplied
				# 2D point: the bridge deliberately resolves the held grip itself.
				world.player.global_position=actor_position+Vector2(index%3,index/3)*64.0-Vector2(64,32)
				world.spawn_weapon_muzzle(world.player.get_projectile_origin(),Vector2.from_angle(index*TAU/6),[&"pistol",&"assault_rifle",&"shotgun"][index%3],world.player)
			world.player.global_position=actor_position
			if iteration>=2: muzzle_samples.append(float(Time.get_ticks_usec()-started)/1000.0)
			await RenderingServer.frame_post_draw
			if iteration==11:
				for age in [0.0,0.05,0.12]:
					for effect in world.world_effects_root.get_children():
						if previous.has(effect): continue
						effect.lifetime=effect.initial_lifetime-age
						var bridge: Node3D=effect.get_meta(&"depth_visual_bridge").get_ref()
						bridge._process(0.0)
					for index in 4: await process_frame
					await RenderingServer.frame_post_draw
					var image:=root.get_texture().get_image()
					image.save_png("res://.runtime/furniture_face_review/muzzle_pool_"+str(images.size())+".png")
					images.append(image)
			for effect in world.world_effects_root.get_children():
				if not previous.has(effect): effect.queue_free()
			for index in 3: await process_frame
		muzzle_samples.sort()
		print("MUZZLE_CREATE_BENCH ",JSON.stringify({"legacy":legacy,"count":6,"samples":10,"median_ms":muzzle_samples[5],"max_ms":muzzle_samples.back()}))
	world.remove_meta(&"test_legacy_muzzle_capture")
	for index in 3:
		if images[index].get_data()!=images[index+3].get_data(): failures+=1; push_error("Muzzle pooled phase differs "+str(index))
		if images[index].get_data()!=images[index+6].get_data(): failures+=1; push_error("Muzzle comparison background changes "+str(index))
	var pool: Node3D=world._get_muzzle_capture_pool()
	if pool.created!=12 or pool.idle.size()!=12: failures+=1; push_error("Muzzle slots not reused")
	if not pool.idle.all(func(bridge: Node3D)->bool: return not bridge.is_processing() and not bridge.actor_sprite.visible and bridge.render_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED):
		failures+=1; push_error("Idle muzzle captures update")
	var previous: Array=world.world_effects_root.get_children()
	for index in 40: world.spawn_weapon_muzzle(world.player.get_projectile_origin(),Vector2.RIGHT,&"pistol",world.player)
	var effects: Array=world.world_effects_root.get_children().filter(func(node: Node)->bool: return not previous.has(node))
	if effects.size()!=40 or not effects.all(func(effect: Node2D)->bool: return effect.get_meta(&"depth_visual_bridge").get_ref().source_actor==effect):
		failures+=1; push_error("Muzzle overflow drops or aliases sources")
	for effect in effects: effect.queue_free()
	for index in 4: await process_frame
	if pool.idle.size()!=32: failures+=1; push_error("Muzzle idle retention not bounded")
	print("MUZZLE_POOL_RESULT checks=10 failures=",failures)
	paused=false
	display.queue_free()
	for index in 4: await process_frame
	quit(1 if failures>0 else 0)
