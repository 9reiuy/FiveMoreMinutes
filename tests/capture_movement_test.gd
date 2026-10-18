extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var preview = PREVIEW_SCENE.instantiate()
	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate()
	preview.preview_mode = false
	preview.world = room
	root.add_child(preview)

	for i in range(25):
		await process_frame

	# Player stands in front of desk center
	room.player.global_position = Vector2(11.5, 3.85) * 32.0
	room.interaction_resolver.update_target()
	room._on_waitress_interaction_requested()

	for i in range(25):
		await process_frame

	# Player walks left by 48px
	room.player.global_position += Vector2(-48.0, 0.0)
	room._update_camera_and_projection(0.016)
	room._process(0.016)
	for i in range(15):
		await process_frame

	var img_left = root.get_texture().get_image()
	if img_left != null:
		img_left.save_png("res://tests/move_left_test.png")
		print("Saved move_left_test.png")

	# Player walks down by 48px
	room.player.global_position = Vector2(11.5, 3.85) * 32.0 + Vector2(0.0, 48.0)
	room._update_camera_and_projection(0.016)
	room._process(0.016)
	for i in range(15):
		await process_frame

	var img_down = root.get_texture().get_image()
	if img_down != null:
		img_down.save_png("res://tests/move_down_test.png")
		print("Saved move_down_test.png")

	preview.queue_free()
	quit()
