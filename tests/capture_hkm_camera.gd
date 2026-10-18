extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Node = SCENE.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.elevator_transition_animated = true
	root.add_child(world)

	for i in 2:
		await process_frame

	world.regenerate(42001)

	# Wait for elevator doors to open and player presentation to sync
	for i in 12:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/capture_hkm_camera_60deg.png")
	print("Screenshot saved to res://tests/capture_hkm_camera_60deg.png")

	world.free()
	for i in 4:
		await process_frame

	quit(0)
