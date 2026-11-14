extends SceneTree
## Isolate the Main shutdown warning with the pre-feature shared Shader code.
func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(100.0,true,false,true).timeout.connect(func(): quit(2))
	Engine.max_fps=60
	var original_code:=FileAccess.get_file_as_string("res://.runtime/character_rim_promotion_20261113/before/lit_pixel_carrier.gdshader.txt")
	if original_code.is_empty(): quit(2); return
	var shared: Shader=load("res://shaders/dream3d/lit_pixel_carrier.gdshader")
	shared.code=original_code # This process only; no file modification.
	var controller:=root.get_node("DreamTimeController")
	controller.end_tactical_planning(); controller.clear_reaction_time(); controller.set_slow_time_enabled(false); Engine.time_scale=1.0
	var main: Node=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(70)
	main.persistent_day_state=main._create_initial_state(); main._show_dream("basic")
	for i in 1800:
		if not main.transition_running and is_instance_valid(main._supported_dream_world) and not main._supported_dream_world.floor_transition_in_progress: break
		await frames(1)
	print("RIM_LEGACY_MAIN_SHUTDOWN ",JSON.stringify({"legacy_shader":not shared.code.contains("actor_pixel_rim"),"world_loaded":is_instance_valid(main._supported_dream_world),"muted":AudioServer.is_bus_mute(0)}))
	main.free(); await frames(30); quit(0)
