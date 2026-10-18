extends SceneTree

const TUTORIAL_SCENE := preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)


func _run() -> void:
	print("--- Starting Tutorial Dialogue Integration Tests ---")

	var room: Node3D = TUTORIAL_SCENE.instantiate()
	_check(room != null, "Dream3D_TutorialRoom instantiates cleanly")
	root.add_child(room)

	await process_frame
	await process_frame

	# 1. Component existence verification
	_check(room.get("dialogue_bubble") != null, "dialogue_bubble exists")
	_check(room.get("dialogue_bubble") is DreamDialogueBubble, "dialogue_bubble is DreamDialogueBubble")
	_check(room.get("dialogue_controller") != null, "dialogue_controller exists")
	_check(room.get("dialogue_controller") is DreamDialogueController, "dialogue_controller is DreamDialogueController")
	_check(room.dialogue_bubble.visible == false, "dialogue_bubble is initially hidden")
	_check(room.dialogue_dialog != null and room.dialogue_dialog.visible == false, "fallback dialogue_dialog exists and is hidden")

	# 2. Guide spawn & initial prompt
	_check(room.guide != null, "Tutorial guide exists")
	_check(room.player != null, "Player exists")
	room._spawn_guide_once()
	await room.guide_spawn_completed
	await process_frame
	_check(room.guide.visible == true, "Guide is visible after spawn")

	# Move player near guide to enable interaction
	room.player.global_position = room.guide.global_position + Vector2(24.0, 0.0)
	room.interaction_resolver.update_target()
	room._update_interaction_prompt()
	_check(room.interaction_prompt.visible == true, "Interaction prompt is visible near guide")
	_check(room.interaction_prompt.text == "E 交谈", "Interaction prompt text is 'E 交谈'")

	# 3. Optional dialogue trigger & dynamic speaker tracking
	print("\n--- Testing Optional Guide Dialogue ---")
	room._on_guide_interaction_requested()
	await process_frame
	await process_frame

	_check(room.dialogue_controller.is_active() == true, "Dialogue controller is active after guide interaction")
	_check(room.dialogue_bubble.visible == true, "Dialogue bubble is visible after guide interaction")
	_check(room.dialogue_bubble._current_text == "你能听见我吗？这里是梦的入口。", "Line 1 text matches tutorial_guide_intro")

	# Verify interaction prompt is hidden while talking
	room._update_interaction_prompt()
	_check(room.interaction_prompt.visible == false, "Interaction prompt is hidden while dialogue is active")

	# Verify dynamic speaker tracking updates bubble position
	room._process(0.016)
	_check(room.dialogue_bubble._speaker_hud_pos != Vector2.ZERO, "Speaker HUD position is computed and non-zero")

	# 4. Proximity cancel for optional dialogue
	print("\n--- Testing Proximity Cancel (> 160px) ---")
	room.player.global_position = room.guide.global_position + Vector2(200.0, 0.0)
	room._process(0.016)
	await process_frame

	_check(room.dialogue_controller.is_active() == false, "Dialogue dismissed when player moves > 160px away")

	# 5. Re-trigger optional dialogue and advance lines
	print("\n--- Testing Sequence Advance ---")
	room.player.global_position = room.guide.global_position + Vector2(24.0, 0.0)
	room.interaction_resolver.update_target()
	room._on_guide_interaction_requested()
	await process_frame
	await process_frame

	_check(room.dialogue_controller.is_active() == true, "Optional dialogue restarts cleanly")
	_check(room.dialogue_bubble._current_text == "你能听见我吗？这里是梦的入口。", "Line 1 restarted")

	# Pass 20% interrupt gate so sequence can advance
	room.dialogue_controller._process(room.dialogue_controller.line_total_duration * 0.25)
	room.dialogue_controller.advance_sequence()
	await create_timer(0.15).timeout

	_check(room.dialogue_bubble._current_text == "先用 WASD 走动。靠近可以交互的东西时，按 E。", "Advanced to Line 2")

	# Dismiss before exit test
	room.dialogue_controller.dismiss_if_active()
	await process_frame
	_check(room.dialogue_controller.is_active() == false, "Dialogue dismissed cleanly")

	# 6. Exit sequence test
	print("\n--- Testing Exit Sequence ---")
	var exit_tracker := {"finished": false}
	room.tutorial_finished.connect(func():
		exit_tracker["finished"] = true
	)

	room._begin_exit_sequence()
	await process_frame
	await process_frame

	_check(room.exit_sequence_started == true, "Exit sequence marked as started")
	_check(room.guide.expression == &"panic", "Guide expression changed to panic")
	_check(room.dialogue_controller.is_active() == true, "Dialogue controller active for exit sequence")
	_check(room.dialogue_bubble._current_text == "真没有什么问题吗？", "Exit line 1 matches tutorial_exit_sequence")
	_check(room.player.movement_enabled == false, "Player movement disabled during exit sequence")

	# Advance to exit line 2
	room.dialogue_controller._process(room.dialogue_controller.line_total_duration * 0.25)
	room.dialogue_controller.advance_sequence()
	await create_timer(0.15).timeout

	_check(room.dialogue_bubble._current_text == "那祝你有个好梦", "Exit line 2 matches tutorial_exit_sequence")

	# Finish exit line 2
	room.dialogue_controller._process(room.dialogue_controller.line_total_duration * 0.25)
	room.dialogue_controller.advance_sequence()

	# Wait for smoke burst and tutorial_finished emission
	var exit_wait := 0.0
	while not exit_tracker["finished"] and exit_wait < 5.0:
		await create_timer(0.05).timeout
		exit_wait += 0.05

	_check(exit_tracker["finished"] == true, "tutorial_finished signal emitted after exit sequence")
	_check(room.guide.visible == false, "Guide hidden after exit smoke burst")

	print("\n--- Tutorial Dialogue Integration Test Summary ---")
	if failures.is_empty():
		print("ALL TUTORIAL DIALOGUE INTEGRATION TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("TUTORIAL DIALOGUE INTEGRATION TESTS FAILED: ", failures)
		quit(1)
