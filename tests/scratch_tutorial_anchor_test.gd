extends SceneTree

const TUTORIAL_SCENE := preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var room = TUTORIAL_SCENE.instantiate()
	root.add_child(room)
	for i in range(10):
		await process_frame

	print("--- Tutorial Room Check ---")
	print("Guide: ", room.guide)
	print("Player: ", room.player)
	room._run_optional_guide_dialogue()
	for i in range(5):
		await process_frame
	
	print("Bubble visible: ", room.dialogue_bubble.visible)
	print("Bubble position: ", room.dialogue_bubble.position)
	print("Options position: ", room.dialogue_bubble.options_container.position)

	# Move player
	room.player.global_position += Vector2(50, 0)
	room._update_camera_and_projection(0.016)
	room._process(0.016)
	for i in range(5):
		await process_frame

	print("After player move:")
	print("Bubble position: ", room.dialogue_bubble.position)
	print("Options position: ", room.dialogue_bubble.options_container.position)

	room.queue_free()
	quit()
