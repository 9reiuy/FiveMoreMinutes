extends SceneTree

const FLOOR_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := FLOOR_SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	root.add_child(world)
	await process_frame
	if not world.regenerate(42001):
		quit(1)
		return
	await world._perform_game_start_cab_exit()
	print("DOOR_PROBE inward=", world.elevator_cab_inward_2d,
		" door=", world.elevator_door_pos_2d,
		" player=", world.player.global_position,
		" approach=", world.elevator_floor_door.get_corridor_approach_position_2d(),
		" orientation=", world.elevator_floor_door.door_orientation)
	for frame in 12:
		await process_frame
	world.room_visibility.set_process(false)
	world.room_visibility.outside_black_gradient.visible = false
	await process_frame
	var before_image: Image = root.get_texture().get_image()
	if before_image != null and not before_image.is_empty():
		print("MASK_WITHOUT_CAPTURE result=", before_image.save_png("res://tests/office_floor_mask_without.png"))
	world.room_visibility.outside_black_gradient.visible = true
	world.room_visibility.set_process(true)
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("MASK_CAPTURE unavailable")
		quit(2)
		return
	print("MASK_CAPTURE: ", image.get_size(), " result=", image.save_png("res://tests/office_floor_mask_visual_probe.png"))
	world.queue_free()
	await process_frame
	quit()
