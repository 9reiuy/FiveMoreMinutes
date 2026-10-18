extends SceneTree
## Actual first-use constructors in the formal world, with gameplay paused.
## Each mode needs a separate process to avoid another mode warming its shaders.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var mode:="full"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
	if mode not in ["full","projectile","light","muzzle_only","shell"]: quit(2); return
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(41001): quit(2); return
	for frame in 40: await process_frame
	world.transition_phase=&"IDLE"
	world.player.equip_weapon("assault_rifle",world.config)
	world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0; paused=true
	for frame in 8: await RenderingServer.frame_post_draw
	if "--prime-muzzle-light" in OS.get_cmdline_user_args() or "--prime-shot-visuals" in OS.get_cmdline_user_args():
		var before: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
		var rng_state: int=world._content_rng.state
		var source_count: int=world.world_effects_root.get_child_count()
		var result: Dictionary=await preload("res://scripts/dream/firearm_render_preparation.gd").run(self,world,"--prime-shot-visuals" in OS.get_cmdline_user_args())
		for frame in 4: await RenderingServer.frame_post_draw
		var after: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
		result["restored_pixels_equal"]=before==after
		result["rng_restored"]=world._content_rng.state==rng_state
		result["sources_restored"]=world.world_effects_root.get_child_count()==source_count
		print("MUZZLE_LIGHT_FIRST_USE_PREP ",JSON.stringify(result))
		if before!=after or not result.rng_restored or not result.sources_restored: quit(1); return
	var rows: Array=[]
	for repeat in 3:
		seed(54001)
		var retained: Dictionary={}
		for node in world.world_effects_root.get_children(): retained[node.get_instance_id()]=true
		var origin: Vector2=world.player.get_projectile_origin()
		var started:=Time.get_ticks_usec()
		if mode=="full": world.player.assault_rifle_weapon._fire(Vector2.RIGHT,false)
		elif mode=="projectile":
			var projectile: Node2D=preload("res://scenes/entities/basic_projectile.tscn").instantiate()
			preload("res://scripts/dream/dream_firearm_rules.gd").setup_projectile(projectile,Vector2.RIGHT,3.0,1024.0,1500.0,&"player",world.player,&"assault_rifle")
			projectile.global_position=origin; world.add_projectile(projectile,world.player)
		elif mode=="light": world.night_lighting.flash_muzzle_world(world.player_depth_bridge.actor_sprite.global_position,&"assault_rifle")
		elif mode=="muzzle_only":
			world.night_lighting.shadow_transition_paused=true
			world.spawn_weapon_muzzle(origin,Vector2.RIGHT,&"assault_rifle",world.player)
			world.night_lighting.shadow_transition_paused=false
		elif mode=="shell": world.spawn_shell_ejection(origin,Vector2.RIGHT,&"assault_rifle")
		var setup_ms:=float(Time.get_ticks_usec()-started)/1000.0
		await RenderingServer.frame_post_draw
		var birth_ms:=float(Time.get_ticks_usec()-started)/1000.0
		var previous:=Time.get_ticks_usec(); var subsequent_max:=0.0
		for frame in 8:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec(); subsequent_max=maxf(subsequent_max,float(now-previous)/1000.0); previous=now
		var new_count:=0
		for node in world.world_effects_root.get_children():
			if not retained.has(node.get_instance_id()): new_count+=1; node.queue_free()
		world.night_lighting._process(.1)
		rows.append({"setup_ms":setup_ms,"birth_draw_ms":birth_ms,"subsequent_max_ms":subsequent_max,"new_sources":new_count})
		for frame in 8: await process_frame
	print("FIREARM_FIRST_USE_RESULT ",JSON.stringify({"mode":mode,"rows":rows,"gpu":RenderingServer.get_video_adapter_name(),"gameplay_paused":true,"semantics":"fixed-world first-use draw; not live FPS or normal loading time"}))
	paused=false; display.queue_free()
	for frame in 4: await process_frame
	quit()
