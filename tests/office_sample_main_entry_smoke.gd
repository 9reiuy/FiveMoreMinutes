extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for frame in 3:
		await process_frame
	var main_scene: PackedScene = load("res://scenes/app/main.tscn")
	if main_scene == null:
		quit(1)
		return
	var main = main_scene.instantiate()
	root.add_child(main)
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state["tutorial_completed"] = true
	seed(120)
	var expected_seed := randi()
	seed(120)
	main._show_dream("basic")
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if main._active_pixelation_screen() != null and not main.transition_running:
			break
	var wrapper: Node = main._active_pixelation_screen()
	var world: Node = wrapper.get("world") if wrapper != null else null
	var passed: bool = is_instance_valid(world) and world.scene_file_path == "res://scenes/dream/Dream3D_RandomDungeon.tscn" and int(world.seed) == expected_seed and not bool(world.use_authored_office_sample) and String(world.floor_shape) in ["rectangle", "l", "t", "cross", "convex"] and is_instance_valid(world.elevator_floor_door) and is_instance_valid(world.elevator_approach_trigger) and not world.rooms.is_empty() and is_instance_valid(world.player)
	print("RANDOM MAIN ENTRY passed=", passed, " expected_seed=", expected_seed, " actual_seed=", world.seed if is_instance_valid(world) else -1, " floor_shape=", world.floor_shape if is_instance_valid(world) else "none")
	if passed and not DisplayServer.get_name() == "headless":
		main._apply_palette_enabled(false)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/main_entry_palette_off.png"))
		main._apply_palette_enabled(true)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.runtime/main_entry_palette1.png"))
	main.queue_free()
	await process_frame
	quit(0 if passed else 1)
