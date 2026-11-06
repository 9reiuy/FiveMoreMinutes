extends SceneTree
const OUT="res://.runtime/tonal_formal_20261029"
var checks:=0
var failures:=0
var main: Node
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func frames(n: int=3) -> void:
	for i in n: await process_frame
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(4)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(300,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.max_fps=60
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true); settings.set_setting(&"palette_enabled",true)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state()
	main._show_reception("basic"); await settle()
	var lobby: Node3D=main._supported_dream_world
	check(not main.current_screen.palette_material.get_shader_parameter("tonal_sample"),"Main reception retains its local palette")
	main._show_dream("basic"); await settle()
	var world: Node3D=main._supported_dream_world
	while world.floor_transition_in_progress: await process_frame
	await frames(8)
	var display: Control=main.current_screen
	check(bool(display.palette_material.get_shader_parameter("tonal_sample")),"actual Main floor enables approved tonal processing")
	check(bool(world.get_meta("pixel_stability_enabled",false)),"actual Main floor enables display stabilization")
	var live:=0; var enhanced:=0
	for component in get_nodes_in_group("office_dither_lighting"):
		if component.get_parent()!=world: continue
		for material in component.materials.values():
			live+=1
			if material.get_shader_parameter("office_tonal_sample")==true: enhanced+=1
	check(live>5 and enhanced==live,"all live floor lighting variants inherit approved enhancement")
	for scheme in [1,2]:
		settings.set_setting(&"palette_scheme",scheme); await frames()
		check(int(display.palette_material.get_shader_parameter("palette_scheme"))==scheme,"formal floor keeps palette scheme %d"%scheme)
		await RenderingServer.frame_post_draw
		display.world_viewport.get_texture().get_image().save_png(OUT+"/formal_scheme%d.png"%scheme)
	settings.set_setting(&"pixelation_enabled",false); await frames()
	check(not bool(world.get_meta("pixel_stability_enabled",true)) and world.camera_3d.h_offset==0 and world.camera_3d.v_offset==0,"native rendering clears pixel stabilization offsets")
	settings.set_setting(&"pixelation_enabled",true); await frames()
	check(bool(world.get_meta("pixel_stability_enabled",false)),"pixel rendering restores stabilization")
	var player: Node2D=world.player
	player.invulnerability_left=1000.
	var position_before: Vector2=player.global_position
	Input.action_press("move_right"); await frames(8); Input.action_release("move_right"); await frames()
	check(player.global_position.distance_to(position_before)>1.,"real movement input remains responsive")
	# Physics and SceneTree test continuations can run at different frame phases;
	# compare the current source pose against its explicitly refreshed projection.
	world._update_camera_and_actor_projection(0.)
	var ground:=world.to_global(Vector3(player.global_position.x/32.,0,player.global_position.y/32.))
	var projected: Vector2=world.camera_3d.unproject_position(ground)
	var source_screen: Vector2=world.gameplay_canvas.transform*player.global_position
	check(projected.distance_to(source_screen)<.05,"gameplay canvas follows corrected actual Camera projection")
	main.game_phone.open_phone(); await create_timer(.8).timeout
	check(main.game_phone.is_open() and world.phone_camera_weight>.9,"actual game phone opens and zooms while paused")
	check(world.camera_3d.h_offset==0 and world.camera_3d.v_offset==0,"phone zoom has no quantized camera offset")
	main.game_phone.close_phone(); await create_timer(.8).timeout
	check(not main.game_phone.is_open() and world.phone_camera_weight<.001,"phone closing restores ordinary camera")
	world._update_camera_and_actor_projection(0.)
	check(int(world.get_meta("pixel_stability_floor",-1))==world.get_current_floor_token(),"normal camera uses current floor anchor")
	var old_token: int=world.get_current_floor_token()
	player.global_position=world.elevator_floor_door.get_corridor_approach_position_2d()
	world._begin_elevator_entry_transition()
	while world.floor_transition_in_progress: await process_frame
	await frames(12)
	check(world.get_current_floor_token()!=old_token,"actual elevator produces a new floor generation")
	check(int(world.get_meta("pixel_stability_floor",-1))==world.get_current_floor_token(),"arrival refreshes stabilization anchor for new floor")
	live=0; enhanced=0
	for component in get_nodes_in_group("office_dither_lighting"):
		if component.get_parent()!=world: continue
		for material in component.materials.values():
			live+=1
			if material.get_shader_parameter("office_tonal_sample")==true: enhanced+=1
	check(live>5 and live==enhanced,"new floor material lifecycle retains tonal enhancement")
	check(player.movement_enabled and player.attacking_enabled,"elevator restores gameplay input")
	# Fixed live-entry snapshot. Scheduler/draw submission span is NOT full FPS.
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var spans: Dictionary={}
	for enabled in [false,true]:
		display.set_visual_enhancement(enabled)
		await frames(12)
		var timings: Array[float]=[]
		for i in 40:
			await RenderingServer.frame_pre_draw
			var start:=Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			timings.append((Time.get_ticks_usec()-start)/1000.)
		timings.sort()
		spans[str(enabled)]={"p50_ms":timings[20],"p95_ms":timings[38]}
	display.set_visual_enhancement(true)
	var report={"checks":checks,"failures":failures,"lighting_materials":live,"draw_submission_span":spans,"scope":"Main reception, real floor, real movement, actual game phone and elevator; frozen endpoint rendering span excludes complete frame and is not GPU time/FPS","gpu":RenderingServer.get_video_adapter_name()}
	FileAccess.open(OUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	main.queue_free(); await frames(4)
	print("FINAL ",JSON.stringify(report)); quit(failures)
