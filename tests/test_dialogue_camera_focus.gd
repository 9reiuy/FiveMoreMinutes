extends SceneTree

const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] ", label)
	else:
		failures.append(label)
		printerr("  [FAIL] ", label)

func _run() -> void:
	print("--- Starting Dialogue Camera Focus Verification ---")
	var room: Dream3DReceptionRoom = RECEPTION_SCENE.instantiate() as Dream3DReceptionRoom
	root.add_child(room)

	for i in range(10):
		await process_frame

	# 1. Initial State
	_check(room.dialogue_camera_weight == 0.0, "Initial dialogue_camera_weight is 0.0")
	var initial_rig_pos := room.camera_rig.position

	# 2. Trigger waitress proximity dialogue
	room.player.global_position = Vector2(11.5, 3.85) * 32.0
	room.interaction_resolver.update_target()
	room._handle_waitress_proximity_dialogue()

	_check(room.dialogue_controller != null and room.dialogue_controller.is_active(), "Dialogue controller is active")

	# Wait for camera tween (0.40s)
	if room._dialogue_camera_tween != null and room._dialogue_camera_tween.is_valid():
		await room._dialogue_camera_tween.finished

	_check(is_equal_approx(room.dialogue_camera_weight, 1.0), "dialogue_camera_weight reaches 1.0 after 0.40s (got %f)" % room.dialogue_camera_weight)
	_check(room.camera_rig.position.distance_to(room.DIALOGUE_FOCUS_TARGET_3D) < 0.01, "camera_rig focused on DIALOGUE_FOCUS_TARGET_3D")

	# 3. Test player small steps during dialogue - camera & waitress HUD position remain stationary
	var waitress_hud_pos_1 := room._get_waitress_hud_pos()
	var rig_pos_1 := room.camera_rig.position

	# Move player slightly (30px)
	room.player.global_position += Vector2(20.0, 15.0)
	room._update_camera_and_projection(0.016)

	var waitress_hud_pos_2 := room._get_waitress_hud_pos()
	var rig_pos_2 := room.camera_rig.position

	_check(rig_pos_1.distance_to(rig_pos_2) < 0.001, "camera_rig remains stationary while player takes small steps during dialogue")
	_check(waitress_hud_pos_1.distance_to(waitress_hud_pos_2) < 0.05, "waitress HUD position remains rock-solid stationary on screen (diff: %s)" % [waitress_hud_pos_2 - waitress_hud_pos_1])
	_check(room.player.movement_enabled == true, "player.movement_enabled remains true during dialogue")

	# 4. Player walks away beyond interaction radius (105px)
	room.player.global_position = Vector2(11.5, 12.0) * 32.0
	room.interaction_resolver.update_target()
	room._handle_waitress_proximity_dialogue()

	_check(not room.dialogue_controller.is_active(), "Dialogue dismissed when player walks beyond interaction radius")

	# Wait for return tween (0.45s)
	if room._dialogue_camera_tween != null and room._dialogue_camera_tween.is_valid():
		await room._dialogue_camera_tween.finished

	room._update_camera_and_projection(0.016)

	_check(is_equal_approx(room.dialogue_camera_weight, 0.0), "dialogue_camera_weight returns to 0.0 after dialogue dismiss (got %f)" % room.dialogue_camera_weight)

	var expected_normal_focus := Vector3(room.player.global_position.x / room.CELL_PIXELS, 0.0, room.player.global_position.y / room.CELL_PIXELS) + room.camera_aim_offset
	_check(room.camera_rig.position.distance_to(expected_normal_focus) < 0.05, "camera_rig returns to normal player focus")

	room.queue_free()
	if failures.is_empty():
		print("--- ALL DIALOGUE CAMERA FOCUS TESTS PASSED ---")
		quit(0)
	else:
		printerr("--- DIALOGUE CAMERA FOCUS TESTS FAILED: ", failures)
		quit(1)
