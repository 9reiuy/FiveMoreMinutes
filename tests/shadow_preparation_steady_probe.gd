extends SceneTree
## Same paused formal world: determine whether receiver preparation itself
## raises steady render cost. Not a live-combat FPS acceptance benchmark.
var failures:=0
func _initialize() -> void: call_deferred("run")
func measure(label: String,display: Control,reference: PackedByteArray) -> void:
	var values: Array=[]
	var started:=Time.get_ticks_usec()
	var previous:=started
	while Time.get_ticks_usec()-started<5000000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		values.append((now-previous)/1000.0); previous=now
	values.sort()
	var image: Image=display.world_viewport.get_texture().get_image()
	var parity:=image.get_data()==reference
	if not parity: failures+=1
	print("SHADOW_PREPARATION_STEADY ",JSON.stringify({"label":label,"frames":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[floori(values.size()*.95)],"max_ms":values.back(),"same_world_pixels":parity,"gpu":RenderingServer.get_video_adapter_name(),"actual_output":root.get_texture().get_image().get_size(),"world_viewport":display.world_viewport.size,"scope":"same frozen formal world; not live FPS"}))
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	AudioServer.set_bus_mute(0,true)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display); paused=true
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	if not world.regenerate(41001): quit(1); return
	world.player.global_position=Vector2(800,1416)
	world._update_camera_and_actor_projection(0.0)
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.has_method("_process"): bridge._process(0.0)
	world.shadow_manager.prepare_loading_selection()
	for light in world.shadow_manager.active: light.shadow_opacity=1.0
	await preload("res://scripts/dream/firearm_render_preparation.gd").run(self,world)
	for frame in 100: await RenderingServer.frame_post_draw
	var reference: PackedByteArray=display.world_viewport.get_texture().get_image().get_data()
	await measure("before",display,reference)
	print("STEADY_RECEIVER_PREPARATION ",JSON.stringify(await preload("res://tests/support/shadow_receiver_preparation_probe.gd").run(self,world)))
	for frame in 100: await RenderingServer.frame_post_draw
	await measure("after",display,reference)
	var size: int=display.world_viewport.positional_shadow_atlas_size
	display.world_viewport.positional_shadow_atlas_size=0
	display.world_viewport.positional_shadow_atlas_size=size
	for frame in 100: await RenderingServer.frame_post_draw
	await measure("after_atlas_reset",display,reference)
	display.queue_free()
	for frame in 4: await process_frame
	print("SHADOW_PREPARATION_STEADY_RESULT failures=",failures)
	quit(0 if failures==0 else 1)
