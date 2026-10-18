extends SceneTree
## Diagnostic only: split real display removal from new debris drawing.
func _initialize() -> void: call_deferred("run")
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"max":values.back()}
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=true; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(41001): quit(1); return
	world.player.global_position=Vector2(800,1536)
	for frame in 30: await process_frame
	world.transition_phase=&"IDLE"; world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	paused=true; Engine.max_fps=0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if "--prewarm-world-destruction" in OS.get_cmdline_user_args():
		print("WORLD_DESTRUCTION_WARM ",JSON.stringify(await preload("res://tests/support/destruction_world_warm_probe.gd").run(self,world)))
	var sources:=Node2D.new(); root.add_child(sources)
	var location:=Vector3(25,0,48)
	for kind in ["workstation","chair","cabinet","server","sofa","table"]:
		for action in ["spawn_only","remove_only","combined"]:
			var cpu: Array[float]=[]; var draw: Array[float]=[]
			for iteration in 8:
				var source:=Node2D.new(); sources.add_child(source)
				source.position=Vector2(location.x,location.z)*32.0
				source.set_meta(&"office_visual_style", "approved_office")
				source.set_meta(&"office_furniture_kind",kind)
				var visual: Furniture3DVisual=world._spawn_furniture_presentation(source)
				if visual.visual_instance==null: push_error("Missing real furniture visual: "+kind); quit(1); return
				for frame in 8: await RenderingServer.frame_post_draw
				var started:=Time.get_ticks_usec()
				var debris: Node3D
				if action!="remove_only":
					debris=Furniture3DDebris.new(); debris.position=visual.position+Vector3(0,.2,0)
					debris.set_meta(&"test_debris_seed",4300+iteration)
					world.actor_depth_bridges_root.add_child(debris); debris._setup(null,6,Vector3.RIGHT)
				if action!="spawn_only": visual.queue_free()
				cpu.append((Time.get_ticks_usec()-started)/1000.0)
				await RenderingServer.frame_post_draw
				draw.append((Time.get_ticks_usec()-started)/1000.0)
				if is_instance_valid(visual): visual.queue_free()
				if is_instance_valid(debris): debris.queue_free()
				source.queue_free()
				for frame in 4: await process_frame
			print("FURNITURE_TRANSITION ",JSON.stringify({"kind":kind,"action":action,"samples":8,"cpu_ms":stats(cpu),"first_draw_ms":stats(draw)}))
	print("FURNITURE_TRANSITION_GPU ",RenderingServer.get_video_adapter_name())
	paused=false; sources.queue_free(); display.queue_free()
	for frame in 4: await process_frame
	quit(0)
