extends SceneTree
## GPU-only diagnostic. Real materials and camera; no gameplay is advanced.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	AudioServer.set_bus_mute(0,true)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false
	world.enable_game_start_cab_exit=false
	var display=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false
	root.add_child(display)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	paused=true
	await world.regenerate(41001)
	world._update_camera_and_actor_projection(0.0)
	for frame in range(20): await RenderingServer.frame_post_draw
	if "--prepare-private-meshes" in OS.get_cmdline_user_args():
		print("IMPACT_PREPARATION ",JSON.stringify(await preload("res://scripts/dream/destruction_render_preparation.gd").run(self,world)))
		for frame in range(4): await RenderingServer.frame_post_draw
	if "--prepare-impact-formal" in OS.get_cmdline_user_args():
		var owned: Array[Node]=[]
		for kind in [&"solid",&"metal",&"glass",&"soft"]:
			var impact=preload("res://scripts/dream/firearm_impact_visual_3d.gd").new()
			impact.setup(Vector3.UP,kind); world.add_child(impact)
			impact.global_position=world.get_gameplay_world_position(world.player.global_position+Vector2(32,32),.8)
			impact._emitter.use_fixed_seed=true; impact._emitter.seed=1234
			impact._emitter.restart(); impact._emitter.request_particles_process(.07)
			owned.append(impact)
		for frame in range(3): await RenderingServer.frame_post_draw
		root.get_texture().get_image()
		for node in owned: node.queue_free()
		for frame in range(4): await RenderingServer.frame_post_draw
	if "--prepare-production" in OS.get_cmdline_user_args():
		world.begin_firearm_render_preparation()
		print("IMPACT_PRODUCTION_PREPARATION ",JSON.stringify(await preload("res://scripts/dream/firearm_render_preparation.gd").run(self,world)))
		for frame in range(4): await RenderingServer.frame_post_draw
	var baseline: Image=root.get_texture().get_image()
	var results: Array=[]
	var failures:=0
	for kind in [&"solid",&"metal",&"glass",&"soft"]:
		for iteration in range(3):
			var started:=Time.get_ticks_usec()
			var impact=preload("res://scripts/dream/firearm_impact_visual_3d.gd").new()
			impact.setup(Vector3.UP,kind)
			world.add_child(impact)
			impact.global_position=world.get_gameplay_world_position(world.player.global_position+Vector2(32,32),.8)
			impact._emitter.use_fixed_seed=true; impact._emitter.seed=1234
			impact._emitter.restart()
			impact._emitter.request_particles_process(.07)
			var created:=Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var drawn:=Time.get_ticks_usec()
			var image: Image=root.get_texture().get_image()
			var changed:=image.get_data()!=baseline.get_data()
			if not changed: failures+=1
			results.append({"kind":kind,"iteration":iteration,"create_ms":(created-started)/1000.0,"first_frame_ms":(drawn-created)/1000.0,"pixels_changed":changed})
			impact.queue_free()
			for frame in range(3): await process_frame
	print("IMPACT_FIRST_DRAW ",JSON.stringify({"output":baseline.get_size(),"samples":results,"failures":failures,"scope":"frozen formal random floor; first-render diagnostic, not live FPS"}))
	display.queue_free()
	for frame in range(4): await process_frame
	quit(0 if failures==0 else 1)
