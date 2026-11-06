extends SceneTree
var output := "res://.runtime/coast_spatial_lighting_20261030/walk"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	var city_sample := "--city" in OS.get_cmdline_user_args()
	if city_sample: output="res://.runtime/coast_city_cliff_20261030/walk"
	DirAccess.make_dir_recursive_absolute(output)
	var display: Control = load("res://scenes/preview/night_coast_city_cliff_display.tscn").instantiate() if city_sample else load("res://scripts/story/chapter_coast.gd").new()
	root.add_child(display)
	var coast: Node3D = display.coast
	for i in 5: await process_frame
	coast.clock=9.; coast._update_light()
	var frames: Array=[]
	var started:=Time.get_ticks_msec(); var previous:=started-100
	Input.action_press("move_up")
	while Time.get_ticks_msec()-started<12000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_msec()
		if now-previous<60: continue
		previous=now
		display.view.get_texture().get_image().save_png(output+"/frame_%04d.png"%frames.size())
		frames.append({"time_ms":now-started,"coast_clock":coast.clock,"z":coast.player_position.z,"moon_visibility":coast.moon_visibility})
	Input.action_release("move_up")
	FileAccess.open(output+"/timing.json",FileAccess.WRITE).store_string(JSON.stringify(frames,"\t"))
	print("COAST_LIGHTING_WALK ",JSON.stringify({"frames":frames.size(),"wall_clock_ms":Time.get_ticks_msec()-started,"last":frames.back(),"scope":"normal speed actual Camera, real movement input"}))
	if city_sample:
		output="res://.runtime/coast_city_cliff_20261030/signal"
		DirAccess.make_dir_recursive_absolute(output)
		for i in 1800:
			var time: float=i*.02
			if coast.visibility_at(time)<.001 and coast.visibility_at(time+1.5)<.025:
				coast.clock=time; break
		coast.atmosphere.configure_city_signal("S"); coast._update_light()
		frames=[]; started=Time.get_ticks_msec(); previous=started-100
		while Time.get_ticks_msec()-started<3000:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_msec()
			if now-previous<60: continue
			previous=now
			display.view.get_texture().get_image().save_png(output+"/frame_%04d.png"%frames.size())
			frames.append({"time_ms":now-started,"coast_clock":coast.clock,"signal_phase":coast.atmosphere.signal_elapsed,"moon_visibility":coast.moon_visibility})
		FileAccess.open(output+"/timing.json",FileAccess.WRITE).store_string(JSON.stringify(frames,"\t"))
		print("COAST_ROOF_SIGNAL ",JSON.stringify({"frames":frames.size(),"wall_clock_ms":Time.get_ticks_msec()-started,"last":frames.back(),"scope":"normal speed real roof lights"}))
	display.queue_free()
	for i in 6: await process_frame
	quit()
