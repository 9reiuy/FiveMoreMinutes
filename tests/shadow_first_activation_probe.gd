extends SceneTree
## Frozen formal floor; isolates first activation without changing gameplay.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	AudioServer.set_bus_mute(0,true)
	print("SHADOW_PROBE_CACHE_ENABLED ",ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled"))
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display); paused=true
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	world.regenerate(41001)
	world.player.global_position=Vector2(800,1416)
	world._update_camera_and_actor_projection(0.0)
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.has_method("_process"): bridge._process(0.0)
	if "--prepare-shadow-receivers" in OS.get_cmdline_user_args():
		print("SHADOW_RECEIVER_PREPARATION ",JSON.stringify(await preload("res://tests/support/shadow_receiver_preparation_probe.gd").run(self,world)))
	var manager: Node=world.shadow_manager
	manager.selected.clear(); manager.active.clear()
	for light in manager.candidates: light.shadow_enabled=false; light.shadow_opacity=0.0
	manager.prepare_loading_selection()
	var targets: Array=manager.selected.duplicate()
	for light in targets: light.shadow_enabled=false
	var prepared_light_count := 1 if "--prepare-one-formal-shadow" in OS.get_cmdline_user_args() else 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prepare-formal-shadow-count="):
			prepared_light_count=clampi(int(argument.trim_prefix("--prepare-formal-shadow-count=")),0,targets.size())
	if prepared_light_count>0:
		var preparation_started:=Time.get_ticks_usec()
		for index in prepared_light_count:
			targets[index].shadow_enabled=true; targets[index].shadow_opacity=1.0
		for frame in 2: await RenderingServer.frame_post_draw
		for index in prepared_light_count:
			targets[index].shadow_enabled=false; targets[index].shadow_opacity=0.0
		print("FORMAL_SHADOW_PREPARATION ",JSON.stringify({"elapsed_ms":(Time.get_ticks_usec()-preparation_started)/1000.0,"lights":prepared_light_count}))
	for frame in range(20): await RenderingServer.frame_post_draw
	var unshadowed: Image=root.get_texture().get_image()
	var results: Array=[]
	var reference: PackedByteArray
	var failures:=0
	if targets.size()!=4: failures+=1
	for iteration in range(3):
		for light in targets: light.shadow_enabled=false; light.shadow_opacity=0.0
		for frame in range(4): await RenderingServer.frame_post_draw
		var before:=Time.get_ticks_usec()
		for light in targets: light.shadow_enabled=true; light.shadow_opacity=1.0
		await RenderingServer.frame_post_draw
		var elapsed: float=(Time.get_ticks_usec()-before)/1000.0
		var image: Image=root.get_texture().get_image()
		var pixels:=image.get_data()
		var visible:=pixels!=unshadowed.get_data()
		if not visible: failures+=1
		if iteration==0:
			reference=pixels
			image.save_png("res://.runtime/shadow_first_activation.png" if bool(ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled")) else "res://.runtime/shadow_first_activation_no_cache.png")
		else:
			if pixels!=reference: failures+=1
		results.append({"iteration":iteration,"activation_frame_ms":elapsed,"shadow_pixels_changed":visible,"same_shadow_pixels":pixels==reference})
	print("SHADOW_FIRST_ACTIVATION ",JSON.stringify({"output":unshadowed.get_size(),"target_lights":targets.size(),"samples":results,"failures":failures,"scope":"frozen formal C3 camera, not sustained FPS"}))
	display.queue_free()
	for frame in range(4): await process_frame
	quit(0 if failures==0 else 1)
