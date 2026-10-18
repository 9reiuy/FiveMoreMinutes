extends SceneTree

const TUTORIAL_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
const CELL_PIXELS := 32.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Running In-Game Tutorial Broken Door Capture ---")
	var tutorial := TUTORIAL_SCENE.instantiate()
	root.add_child(tutorial)

	for _i in 15:
		await process_frame

	var door := tutorial.door_root.get_child(0) as PhysicalDoor3D
	var player = tutorial.player
	var camera_rig: Node3D = tutorial.get_node(^"CameraRig")

	# Position player and camera close to the exit door
	var door_ground := Vector2(door.global_position.x, door.global_position.z) * CELL_PIXELS
	player.global_position = door_ground + Vector2(0.0, 96.0)
	camera_rig.global_position = door.global_position + Vector3(0.0, 0.0, 3.0)

	for _i in 10:
		await process_frame

	# Shatter the door
	door.shatter(Vector2(0, -1))

	# Wait for animation and particle shards to settle
	for _i in 30:
		await process_frame

	var broken_img := root.get_viewport().get_texture().get_image()
	if broken_img != null and not broken_img.is_empty():
		broken_img.save_png("res://tests/ingame_broken_door_fixed.png")
		print("Saved in-game broken door screenshot: res://tests/ingame_broken_door_fixed.png")

	tutorial.queue_free()
	await process_frame
	quit(0)
