extends SceneTree
## GPU rendering diagnostic: same formal camera and seed, frozen gameplay.
## Not a live-combat FPS claim. Warm 10s; measure 60s per art configuration.
var world: Node3D
var display: Control
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func sample(seconds: float, record: bool) -> Dictionary:
	var samples: Array[float]=[]
	var calls: Array[int]=[]
	var before := Time.get_ticks_usec()
	var deadline := before+roundi(seconds*1000000.0)
	while Time.get_ticks_usec()<deadline:
		await process_frame
		var now := Time.get_ticks_usec()
		if record:
			samples.append((now-before)/1000.0)
			calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		before=now
	samples.sort(); calls.sort()
	if samples.is_empty(): return {}
	return {"median_ms":samples[samples.size()/2],"p95_ms":samples[floori((samples.size()-1)*.95)],"frames":samples.size(),"draw_calls_median":calls[calls.size()/2]}
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1920,1080)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.enable_game_start_cab_exit=false; world.persist_profile=false
	world.native_skeleton_type="A1"
	display=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false
	root.add_child(display)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	var reports: Array=[]
	for approved in [false,true]:
		paused=false
		world.approved_sample_art_enabled=approved
		if not world.regenerate(42001): quit(1); return
		world.transition_phase=&"IDLE"
		world.player.invulnerability_left=10000
		await frames(25)
		for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
		paused=true
		await sample(10.0,false)
		var report := await sample(60.0,true)
		report["approved_art"]=approved
		report["scope"]="Frozen formal A1 seed42001, 1920x1080 output, pixelation+Palette1; no AI/combat measurement"
		report["gpu"]=RenderingServer.get_video_adapter_name()
		if approved:
			var art=world.office_art_root.get_node("ApprovedOfficeArt")
			report["city_lights"]=art.city.window_lights.size()
			report["buildings"]=art.city.buildings
		print("APPROVED_ART_PERF ",JSON.stringify(report))
		reports.append(report)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/approved_art_capture/perf_"+str(approved)+".png")
	var file:=FileAccess.open("res://.runtime/approved_art_perf.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"  ")); file.close()
	paused=false; display.queue_free(); await frames(5)
	quit()
