extends SceneTree

const WORLD := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	if not world.regenerate(41001):
		printerr("Elevator wall visual probe: generation failed")
		quit(1)
		return
	world.player.global_position = world.elevator_floor_door.get_corridor_approach_position_2d()
	for frame in 20:
		await process_frame
	# Reframe with the game's own camera rig; its angle, FOV and scale stay intact.
	world.set_process(false)
	var camera_rig := world.get_node(^"CameraRig") as Node3D
	camera_rig.global_position = world.elevator_floor_door.global_position
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("Elevator wall visual probe: camera image unavailable")
		quit(2)
		return
	var output := "res://tests/elevator_wall_runtime.png"
	var result := image.save_png(output)
	print("Elevator wall visual probe: ", output, " ", image.get_size(), " result=", result)
	world.queue_free()
	await process_frame
	quit(0 if result == OK else 3)
