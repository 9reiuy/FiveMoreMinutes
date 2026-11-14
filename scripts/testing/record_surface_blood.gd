extends SceneTree
const OUTPUT := "res://.runtime/surface_blood_20261113/capture"
var sample: Control
var entry: Control
var timings: Array[Dictionary] = []

func _initialize() -> void:
	root.size = Vector2i(640,360)
	create_timer(100.0,true,false,true).timeout.connect(func(): print("BLOOD_RECORD_TIMEOUT"); quit(3))
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	AudioServer.set_bus_mute(0,true)
	entry = load("res://scenes/testing/BloodSurfaceLab.tscn").instantiate(); root.add_child(entry)
	sample = entry.presentation
	while not sample.ready_world: await process_frame
	var controller := root.get_node_or_null("DreamTimeController")
	if controller != null:
		controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false)
		controller.set_process(true); controller.set_physics_process(false)
	Engine.time_scale = 1.0; Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_key(KEY_2,true); _key(KEY_2,false); await process_frame
	var input_checks := {"preset_key":sample.mode==1}
	var events_before: int = sample.world.accepted_blood_events
	_key(KEY_F,true); _key(KEY_F,false); await process_frame
	input_checks["accepted_hit_key"] = sample.world.accepted_blood_events>events_before
	_key(KEY_N,true); _key(KEY_N,false); await process_frame
	input_checks["dark_key"] = sample.dark
	_key(KEY_N,true); _key(KEY_N,false)
	var previous_position: Vector2 = sample.world.player.global_position
	_key(KEY_D,true); await create_timer(.2,true,false,true).timeout; _key(KEY_D,false)
	input_checks["wasd_moves_player"] = sample.world.player.global_position.distance_to(previous_position)>5.0
	var smoke := FileAccess.open(OUTPUT+"/entry_smoke.json",FileAccess.WRITE)
	smoke.store_string(JSON.stringify(input_checks,"\t")); smoke.close()
	for passed in input_checks.values():
		if not passed: print("BLOOD_ENTRY_INPUT_FAILED ",JSON.stringify(input_checks)); quit(2); return
	sample.world.player.global_position = Vector2(6,6)*32
	sample.world._update_camera_and_actor_projection(0.0)
	sample.world.player.set_physics_process(false)
	sample.hide_hud = true; sample._update_label()
	for i in 12: await process_frame
	for mode in 4:
		sample.set_dark(false); sample.blood.clear_blood(); sample.blood.rng.seed = 813615+mode
		if is_instance_valid(sample.enemy) and sample.enemy.dead: sample._spawn_target()
		sample.set_preset(mode)
		for i in 5: await process_frame
		var path := OUTPUT+"/mode_%d" % mode; DirAccess.make_dir_recursive_absolute(path)
		var frame := 0; var shots := 0
		var start := Time.get_ticks_usec()
		while frame < 69:
			await process_frame
			var elapsed := (Time.get_ticks_usec()-start)/1000000.0
			if shots < 3 and elapsed >= .4+shots*.4:
				sample.hit_target(mode==3 and shots==2); shots += 1
			if elapsed >= 3.2 and not sample.dark: sample.set_dark(true)
			if elapsed >= frame/15.0:
				await RenderingServer.frame_post_draw
				var image: Image = sample.display.world_viewport.get_texture().get_image()
				image.save_png(path+"/%04d.png" % frame)
				timings.append({"mode":mode,"frame":frame,"wall_seconds":elapsed,"time_scale":Engine.time_scale})
				frame += 1
		print("BLOOD_CAPTURE_MODE ",mode," ",JSON.stringify(sample.blood.stats()))
	sample.blood.clear_blood(); sample.set_dark(false)
	for mode in 4:
		if sample.enemy.dead: sample._spawn_target()
		sample.set_preset(mode)
		for i in 4: await process_frame
		sample.hit_target()
		await create_timer(.18,true,false,true).timeout
		sample.hit_target()
		await create_timer(1.0,true,false,true).timeout
	await RenderingServer.frame_post_draw
	sample.display.world_viewport.get_texture().get_image().save_png(OUTPUT+"/overview_lit.png")
	sample.set_dark(true)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	sample.display.world_viewport.get_texture().get_image().save_png(OUTPUT+"/overview_dark.png")
	var file := FileAccess.open(OUTPUT+"/timings.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":15,"source":"actual 640x360 production Camera, no interpolation","rows":timings},"\t")); file.close()
	entry.free()
	for i in 4: await process_frame
	print("BLOOD_CAPTURE_COMPLETE")
	quit(0)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)
