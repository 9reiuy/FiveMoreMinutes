extends SceneTree

const CAB := preload("res://scripts/dream/independent_elevator_cab_3d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_root := Node3D.new()
	floor_root.rotation.y = -PI / 4.0
	root.add_child(floor_root)
	var gameplay := Node2D.new()
	root.add_child(gameplay)
	var cab: IndependentElevatorCab3D = CAB.new()
	cab.position = Vector3(0.0, 0.0, -100.0)
	floor_root.add_child(cab)
	cab.global_rotation = Vector3.ZERO
	cab.setup_gameplay_boundaries(gameplay, Vector2(0.0, -3200.0))
	var failures := 0
	if absf(cab.global_rotation.y) > 0.001:
		failures += 1
	var tests := [Vector2.ZERO, Vector2(50.0, 0.0), Vector2(-50.0, 0.0), Vector2(0.0, -35.0), Vector2(0.0, 35.0)]
	for local_2d in tests:
		var gameplay_point := cab.boundary_root_2d.to_global(local_2d)
		var projected := floor_root.to_global(Vector3(gameplay_point.x / 32.0, 0.0, gameplay_point.y / 32.0))
		var expected := cab.to_global(Vector3(local_2d.x / 32.0, 0.0, local_2d.y / 32.0))
		if projected.distance_to(expected) > 0.001:
			failures += 1
	if cab.get_player_initial_position_2d().distance_to(cab.boundary_root_2d.to_global(Vector2(0.0, 22.0))) > 0.001:
		failures += 1
	if cab.get_door_threshold_2d().distance_to(cab.boundary_root_2d.to_global(Vector2(0.0, 28.0))) > 0.001:
		failures += 1
	print("CAB_ORIENTATION failures=", failures)
	floor_root.queue_free()
	gameplay.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
