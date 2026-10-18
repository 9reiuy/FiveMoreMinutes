extends SceneTree
func _initialize() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)]}
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false; root.add_child(display)
	if not world.regenerate(41001): quit(1); return
	for frame in 30: await process_frame
	world.player.set_process(false); world.player.set_physics_process(false)
	for enemy in world.enemy_root.get_children(): enemy.set_process(false); enemy.set_physics_process(false)
	world.set_process(false); world.set_physics_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var props: Array=[]
	for node in world.find_children("*","RigidBody2D",true,false):
		if node.get_script()==preload("res://scenes/dream/rooms/chair_01.gd"): props.append(node)
	for candidate in [false,true,false]:
		for prop in props:
			prop.set_meta(&"test_skip_unchanged_furniture_velocity",candidate)
			if not prop.freeze: prop.sleeping=false
		var started:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-started<2000000: await RenderingServer.frame_post_draw
		var intervals: Array=[]; var active: Array=[]; var physics_max: Array=[]
		started=Time.get_ticks_usec(); var previous:=started
		while Time.get_ticks_usec()-started<8000000:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec(); intervals.append((now-previous)/1000.0); previous=now
			active.append(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
			physics_max.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		print("FURNITURE_SLEEP_IDLE_PERF ",JSON.stringify({"candidate":candidate,"props":props.size(),"frames":intervals.size(),"frame_ms":stats(intervals),"active_2d":stats(active),"physics_one_second_max_ms":stats(physics_max),"actor_logic_frozen":true,"native_physics_active":true,"gpu":RenderingServer.get_video_adapter_name()}))
	display.queue_free()
	for frame in 4: await process_frame
	quit(0)
