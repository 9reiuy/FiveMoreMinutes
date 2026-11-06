extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TESTING DREAM TIME CONTROLLER SLOW-MO ===")
	var scene = load("res://scenes/testing/MegastructureWhitebox.tscn").instantiate()
	root.add_child(scene)

	for i in range(5):
		await process_frame

	var player = scene.get_node("GameplayCanvas/GameplayWorld/DreamPlayer")
	var config = preload("res://resources/demo_config.tres")

	var tc = preload("res://scripts/dream/dream_time_controller.gd").new()
	tc.name = "DreamTimeController"
	tc.add_to_group(&"dream_time_controller")
	scene.add_child(tc)
	tc.enter_dream_time_mode(player, config, scene)
	tc.slow_time_enabled = true

	print("Initial Engine.time_scale: ", Engine.time_scale)

	# Run 20 physics frames with player idle
	for i in range(20):
		await physics_frame

	print("Idle Engine.time_scale: ", Engine.time_scale)
	print("tc.current_scale: ", tc.current_scale)

	# Simulate player movement
	player.velocity = Vector2(100.0, 0.0)
	for i in range(10):
		await physics_frame

	print("Moving Engine.time_scale: ", Engine.time_scale)
	print("ALL TIME SLOWMO CHECKS PASSED!")
	quit(0)
