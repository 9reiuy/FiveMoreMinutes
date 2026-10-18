extends SceneTree

const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var room := RECEPTION_SCENE.instantiate()
	root.add_child(room)

	# Let initial frames settle
	for frame in 30:
		await process_frame

	var camera_rig := room.get_node(^"CameraRig") as Node3D

	# 1. Capture Overview from player position in corridor
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var img_corridor := root.get_texture().get_image()
	if img_corridor != null and not img_corridor.is_empty():
		img_corridor.save_png("res://tests/reception_corridor_view.png")
		print("Saved corridor screenshot: res://tests/reception_corridor_view.png")

	# 1b. Capture Main Hall Center Overview (Elevator on left, Desk & Waitress on right)
	room.set_process(false)
	camera_rig.global_position = Vector3(8.0, 0.0, 4.5)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var img_overview := root.get_texture().get_image()
	if img_overview != null and not img_overview.is_empty():
		img_overview.save_png("res://tests/reception_room_overview.png")
		print("Saved main hall overview screenshot: res://tests/reception_room_overview.png")

	# 2. Capture Reception Desk & Waitress close-up
	room.set_process(false)
	camera_rig.global_position = Vector3(11.5, 0.0, 2.8)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var img_desk := root.get_texture().get_image()
	if img_desk != null and not img_desk.is_empty():
		img_desk.save_png("res://tests/reception_desk_closeup.png")
		print("Saved desk closeup screenshot: res://tests/reception_desk_closeup.png")

	# 3. Capture Elevator close-up
	camera_rig.global_position = Vector3(3.5, 0.0, -0.5)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var img_elevator := root.get_texture().get_image()
	if img_elevator != null and not img_elevator.is_empty():
		img_elevator.save_png("res://tests/reception_elevator_closeup.png")
		print("Saved elevator closeup screenshot: res://tests/reception_elevator_closeup.png")

	room.queue_free()
	await process_frame
	quit(0)
