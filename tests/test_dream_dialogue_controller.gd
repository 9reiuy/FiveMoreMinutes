extends SceneTree

# Mock bubble for controller testing
class MockBubble extends Control:
	signal interrupt_pressed
	signal option_pressed(index: int)

	var label: Label
	var progress_history: Array[float] = []
	var chars_history: Array[int] = []
	var transitioned_to_normal: bool = false
	var dismissed: bool = false
	var shown_text: String = ""
	var speaker_hud_pos: Vector2 = Vector2.ZERO
	var player_hud_pos: Vector2 = Vector2.ZERO

	func _init() -> void:
		label = Label.new()
		label.name = "DialogueLabel"
		label.text = ""
		add_child(label)

	func show_dialogue(text: String, _pos: Vector2, _choices: Array, _interrupt_text: String = "...") -> void:
		shown_text = text
		label.text = text
		label.visible = true
		transitioned_to_normal = false
		dismissed = false

	func set_speaker_hud_position(pos: Vector2) -> void:
		speaker_hud_pos = pos

	func set_player_hud_position(pos: Vector2) -> void:
		player_hud_pos = pos

	func get_dialogue_label() -> Label:
		return label

	func set_typing_progress(p: float, c: int) -> void:
		progress_history.append(p)
		chars_history.append(c)

	func transition_to_normal_options() -> void:
		transitioned_to_normal = true

	func dismiss(_fade: float = 0.15) -> void:
		dismissed = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Starting DreamDialogueController Tests (TASK-019-B/C) ---")

	var ControllerScript = load("res://scripts/ui/dialogue/dream_dialogue_controller.gd")
	if ControllerScript == null:
		push_error("Failed to load DreamDialogueController script")
		quit(1)
		return

	# --- Test 1: Single Clock Authority & 20% Gate Transition ---
	print("Test 1: Single Clock Authority & 20% Gate Transition...")
	var controller = ControllerScript.new()
	root.add_child(controller)

	var bubble1 = MockBubble.new()
	root.add_child(bubble1)
	await process_frame
	await process_frame

	var choices = [
		{"text": "Option A", "action_id": &"opt_a"},
		{"text": "Option B", "action_id": &"opt_b"}
	]
	var text1 = "0123456789" # 10 characters
	# typewriter_speed = 0.05 -> typewriter_duration = 10 * 0.05 = 0.5s
	# line_total_duration = 0.5 + 4.0 = 4.5s
	# 20% gate = 4.5 * 0.20 = 0.90s
	controller.start_dialogue(bubble1, text1, choices, Vector2(100, 100), {"typewriter_speed": 0.05})

	if controller.state != controller.State.TYPING_INTERRUPT:
		push_error("Expected TYPING_INTERRUPT state at start, got %d" % controller.state)
		quit(1)
		return
	if not is_equal_approx(controller.typewriter_duration, 0.5):
		push_error("Expected typewriter_duration 0.5, got %f" % controller.typewriter_duration)
		quit(1)
		return
	if not is_equal_approx(controller.line_total_duration, 4.5):
		push_error("Expected line_total_duration 4.5, got %f" % controller.line_total_duration)
		quit(1)
		return
	if not is_equal_approx(controller.progress_ratio, 0.0):
		push_error("Expected progress_ratio 0.0 at start, got %f" % controller.progress_ratio)
		quit(1)
		return
	if not is_equal_approx(controller.remaining_ratio, 1.0):
		push_error("Expected remaining_ratio 1.0 at start, got %f" % controller.remaining_ratio)
		quit(1)
		return
	if bubble1.progress_history.is_empty() or not is_equal_approx(bubble1.progress_history[0], 0.0):
		push_error("Expected bubble initial progress to be 0.0 (left-to-right)")
		quit(1)
		return

	# Step 0.25s (halfway through typing): 5 chars revealed, elapsed_ratio = 0.25 / 4.5 = 0.0555 <= 0.20
	controller._process(0.25)
	if controller.typed_chars != 5:
		push_error("Expected 5 typed chars at 0.25s, got %d" % controller.typed_chars)
		quit(1)
		return
	if controller.state != controller.State.TYPING_INTERRUPT:
		push_error("Expected state to remain TYPING_INTERRUPT at 0.25s (elapsed_ratio <= 0.20)")
		quit(1)
		return

	# Step another 0.25s (elapsed = 0.50s): all 10 chars revealed, but elapsed_ratio = 0.50 / 4.5 = 0.111 <= 0.20
	controller._process(0.25)
	if controller.typed_chars != 10:
		push_error("Expected all 10 chars typed at 0.50s, got %d" % controller.typed_chars)
		quit(1)
		return
	if controller.state != controller.State.TYPING_INTERRUPT:
		push_error("Expected state to STILL be TYPING_INTERRUPT at 0.50s (0.111 <= 0.20 gate)")
		quit(1)
		return
	if bubble1.transitioned_to_normal:
		push_error("Bubble should not have transitioned to normal options before 20% gate")
		quit(1)
		return

	# Step another 0.41s (elapsed = 0.91s > 0.90s, elapsed_ratio = 0.91 / 4.5 = 0.2022 > 0.20)
	controller._process(0.41)
	if controller.state != controller.State.NORMAL_OPTIONS:
		push_error("Expected state transition to NORMAL_OPTIONS after 20% gate, got %d" % controller.state)
		quit(1)
		return
	if not bubble1.transitioned_to_normal:
		push_error("Bubble transition_to_normal_options was not called after 20% gate")
		quit(1)
		return

	# --- Test 2: Normal Option Selection ---
	print("Test 2: Normal Option Selection...")
	var results := {
		"option_selected_fired": false,
		"finished_fired": false,
		"finished_action": &"",
		"finished_interrupted": true
	}

	controller.dialogue_option_selected.connect(func(idx: int, data: Dictionary):
		results["option_selected_fired"] = true
		if idx != 1 or StringName(data.get("action_id", &"")) != &"opt_b":
			push_error("Unexpected option_selected payload")
	)
	controller.dialogue_finished.connect(func(interrupted: bool, action_id: Variant):
		results["finished_fired"] = true
		results["finished_interrupted"] = interrupted
		results["finished_action"] = StringName(action_id)
	)

	bubble1.option_pressed.emit(1)
	if not results["option_selected_fired"]:
		push_error("dialogue_option_selected signal was not emitted")
		quit(1)
		return
	if not results["finished_fired"] or results["finished_interrupted"] != false or results["finished_action"] != &"opt_b":
		push_error("dialogue_finished signal was not emitted properly for normal option")
		quit(1)
		return
	if not bubble1.dismissed:
		push_error("Bubble dismiss was not called on option selection")
		quit(1)
		return
	if controller.state != controller.State.CLOSED:
		push_error("Expected CLOSED state after option selection, got %d" % controller.state)
		quit(1)
		return

	bubble1.queue_free()
	controller.queue_free()
	await process_frame

	# --- Test 3: Selection While Typing in Long Text Scenario ---
	print("Test 3: Selection While Typing in Long Text Scenario...")
	var controller_long = ControllerScript.new()
	root.add_child(controller_long)
	var bubble_long = MockBubble.new()
	root.add_child(bubble_long)
	await process_frame

	# 100 chars, typewriter_speed = 0.05 -> typewriter_duration = 5.0s, line_total = 9.0s.
	# 20% gate = 9.0 * 0.20 = 1.80s.
	var long_text = "A".repeat(100)
	controller_long.start_dialogue(bubble_long, long_text, choices, Vector2(50, 50), {"typewriter_speed": 0.05})

	# Step to 1.85s: elapsed_ratio = 1.85 / 9.0 = 0.2055 > 0.20 -> NORMAL_OPTIONS!
	# typed_chars = int(1.85 / 0.05) = 37 < 100! Typewriter is STILL typing!
	controller_long._process(1.85)
	if controller_long.state != controller_long.State.NORMAL_OPTIONS:
		push_error("Expected NORMAL_OPTIONS at 1.85s for long text, got %d" % controller_long.state)
		quit(1)
		return
	if controller_long.typed_chars >= 100:
		push_error("Typewriter should still be actively typing, typed_chars = %d" % controller_long.typed_chars)
		quit(1)
		return
	if not controller_long.is_typing():
		push_error("is_typing() should return true while elapsed < typewriter_duration")
		quit(1)
		return

	# Player selects option while typing is in progress
	var opt_res := {"selected": false}
	controller_long.dialogue_option_selected.connect(func(_idx: int, _d: Dictionary): opt_res["selected"] = true)
	bubble_long.option_pressed.emit(0)
	if not opt_res["selected"] or controller_long.state != controller_long.State.CLOSED:
		push_error("Failed to select option while typewriter was still typing")
		quit(1)
		return

	bubble_long.queue_free()
	controller_long.queue_free()
	await process_frame

	# --- Test 4: Interrupt Handling & FX Spawn ---
	print("Test 4: Interrupt Handling & FX Spawn...")
	var controller2 = ControllerScript.new()
	root.add_child(controller2)

	var bubble2 = MockBubble.new()
	root.add_child(bubble2)
	await process_frame
	await process_frame

	var interrupt_results := {
		"interrupted_signal_fired": false,
		"finished_interrupt_fired": false
	}
	controller2.dialogue_interrupted.connect(func():
		interrupt_results["interrupted_signal_fired"] = true
	)
	controller2.dialogue_finished.connect(func(interrupted: bool, action_id: Variant):
		if interrupted and StringName(action_id) == &"interrupt":
			interrupt_results["finished_interrupt_fired"] = true
	)

	controller2.start_dialogue(bubble2, "Interruption Test", choices, Vector2(200, 200), {"typewriter_speed": 0.05})
	controller2._process(0.10)

	# Trigger interrupt
	controller2.trigger_interrupt()
	if controller2.state != controller2.State.INTERRUPTED:
		push_error("Expected INTERRUPTED state, got %d" % controller2.state)
		quit(1)
		return
	if bubble2.label.visible != false:
		push_error("Source label was not hidden upon interrupt")
		quit(1)
		return
	if not interrupt_results["interrupted_signal_fired"]:
		push_error("dialogue_interrupted signal not emitted")
		quit(1)
		return

	# Verify FX was spawned in tree
	var fx_node = root.get_node_or_null("DreamDialogueGlyphFallFX")
	if fx_node == null:
		push_error("DreamDialogueGlyphFallFX was not spawned in tree")
		quit(1)
		return

	# Wait for 0.5s interrupt completion
	await create_timer(0.55).timeout

	if not interrupt_results["finished_interrupt_fired"]:
		push_error("dialogue_finished(true, 'interrupt') was not emitted within timeout")
		quit(1)
		return
	if not bubble2.dismissed:
		push_error("Bubble was not dismissed after interrupt")
		quit(1)
		return

	bubble2.queue_free()
	controller2.queue_free()
	await process_frame

	# --- Test 5: Single Line Countdown Expiration (Timeout) ---
	print("Test 5: Single Line Countdown Expiration (Timeout)...")
	var controller_timeout = ControllerScript.new()
	root.add_child(controller_timeout)
	var bubble_timeout = MockBubble.new()
	root.add_child(bubble_timeout)
	await process_frame

	var timeout_results := {
		"finished": false,
		"action": null
	}
	controller_timeout.dialogue_finished.connect(func(interrupted: bool, act: Variant):
		if not interrupted:
			timeout_results["finished"] = true
			timeout_results["action"] = act
	)

	# 10 chars, speed 0.05 -> duration 4.5s
	controller_timeout.start_dialogue(bubble_timeout, "Timeout 10", [], Vector2.ZERO, {"typewriter_speed": 0.05})
	# Advance 5.0s to exceed 4.5s
	controller_timeout._process(5.0)

	if not timeout_results["finished"]:
		push_error("dialogue_finished was not emitted on countdown timeout")
		quit(1)
		return
	if StringName(timeout_results["action"]) != &"timeout":
		push_error("Expected timeout action_id, got %s" % str(timeout_results["action"]))
		quit(1)
		return
	if not bubble_timeout.dismissed:
		push_error("Bubble was not dismissed on timeout")
		quit(1)
		return

	bubble_timeout.queue_free()
	controller_timeout.queue_free()
	await process_frame

	# --- Test 6: Multi-Line Sequential Dialogue Support ---
	print("Test 6: Multi-Line Sequential Dialogue Support...")
	var controller_seq = ControllerScript.new()
	root.add_child(controller_seq)
	var bubble_seq = MockBubble.new()
	root.add_child(bubble_seq)
	await process_frame

	var seq_lines = [
		{"text": "Line 1: Welcome to the dream."},
		{"text": "Line 2: Take this weapon."},
		{"text": "Line 3: Enter the elevator."}
	]
	var lines_started: Array[int] = []
	var seq_results := {"finished": false}

	controller_seq.dialogue_line_started.connect(func(idx: int, _data: Dictionary):
		lines_started.append(idx)
	)
	controller_seq.dialogue_sequence_finished.connect(func():
		seq_results["finished"] = true
	)

	var hud_pos_calls := 0
	var pos_getter := func() -> Vector2:
		hud_pos_calls += 1
		return Vector2(300, 400)

	controller_seq.start_dialogue_sequence(bubble_seq, seq_lines, pos_getter, {"typewriter_speed": 0.02})

	if lines_started.size() != 1 or lines_started[0] != 0:
		push_error("Line 0 should have started")
		quit(1)
		return
	if bubble_seq.shown_text != "Line 1: Welcome to the dream.":
		push_error("Line 0 text mismatch")
		quit(1)
		return

	# Advance past 20% gate on line 0
	controller_seq._process(controller_seq.line_total_duration * 0.25)
	if controller_seq.state != controller_seq.State.NORMAL_OPTIONS:
		push_error("Expected NORMAL_OPTIONS for line 0")
		quit(1)
		return

	# Player presses E / advance_sequence to advance to line 1
	controller_seq.advance_sequence()
	# Wait for 0.10s line transition
	await create_timer(0.15).timeout

	if lines_started.size() != 2 or lines_started[1] != 1:
		push_error("Line 1 should have started after advance, lines_started=%s" % str(lines_started))
		quit(1)
		return
	if bubble_seq.shown_text != "Line 2: Take this weapon.":
		push_error("Line 1 text mismatch")
		quit(1)
		return

	# On Line 1, let countdown expire (remaining_ratio == 0) to test auto-advance
	controller_seq._process(controller_seq.line_total_duration + 0.1)
	await create_timer(0.15).timeout

	if lines_started.size() != 3 or lines_started[2] != 2:
		push_error("Line 2 should have auto-started after timeout, lines_started=%s" % str(lines_started))
		quit(1)
		return
	if bubble_seq.shown_text != "Line 3: Enter the elevator.":
		push_error("Line 2 text mismatch")
		quit(1)
		return

	# Advance past Line 2 (the final line)
	controller_seq._process(controller_seq.line_total_duration * 0.25)
	controller_seq.advance_sequence()
	await create_timer(0.15).timeout

	if not seq_results["finished"]:
		push_error("dialogue_sequence_finished was not emitted at sequence end")
		quit(1)
		return
	if not bubble_seq.dismissed:
		push_error("Bubble was not dismissed at sequence end")
		quit(1)
		return

	bubble_seq.queue_free()
	controller_seq.queue_free()
	await process_frame

	# --- Test 7: Interrupt Sequence Early Termination ---
	print("Test 7: Interrupt Sequence Early Termination...")
	var controller_seq_int = ControllerScript.new()
	root.add_child(controller_seq_int)
	var bubble_seq_int = MockBubble.new()
	root.add_child(bubble_seq_int)
	await process_frame

	var int_seq_lines_started: Array[int] = []
	var int_seq_results := {
		"finished": false,
		"received": false
	}

	controller_seq_int.dialogue_line_started.connect(func(idx: int, _data: Dictionary):
		int_seq_lines_started.append(idx)
	)
	controller_seq_int.dialogue_sequence_finished.connect(func():
		int_seq_results["finished"] = true
	)
	controller_seq_int.dialogue_finished.connect(func(interrupted: bool, act: Variant):
		if interrupted and StringName(act) == &"interrupt":
			int_seq_results["received"] = true
	)

	controller_seq_int.start_dialogue_sequence(bubble_seq_int, seq_lines, Callable(), {"typewriter_speed": 0.05})
	# Interrupt on Line 0 during interrupt window
	controller_seq_int.trigger_interrupt()

	await create_timer(0.55).timeout

	if not int_seq_results["received"]:
		push_error("Interrupt signal not received for sequence interruption")
		quit(1)
		return
	if int_seq_results["finished"]:
		push_error("dialogue_sequence_finished should NOT be emitted on interrupt")
		quit(1)
		return
	if int_seq_lines_started.size() != 1:
		push_error("Sequence should have halted immediately on interrupt without starting further lines")
		quit(1)
		return

	bubble_seq_int.queue_free()
	controller_seq_int.queue_free()
	await process_frame

	# --- Test 8: Proximity Exit (dismiss_if_active) ---
	print("Test 8: Proximity Exit...")
	var controller3 = ControllerScript.new()
	root.add_child(controller3)
	var bubble3 = MockBubble.new()
	root.add_child(bubble3)
	await process_frame

	controller3.start_dialogue(bubble3, "Walking away", choices, Vector2(50, 50))
	if not controller3.is_active():
		push_error("Controller should be active")
		quit(1)
		return

	controller3.dismiss_if_active()
	if controller3.state != controller3.State.IDLE:
		push_error("Expected IDLE after dismiss_if_active, got %d" % controller3.state)
		quit(1)
		return
	if not bubble3.dismissed:
		push_error("Bubble should be dismissed on dismiss_if_active")
		quit(1)
		return

	bubble3.queue_free()
	controller3.queue_free()
	await process_frame

	# --- Test 9: Empty Text Instant Handling ---
	print("Test 9: Empty Text Instant Handling...")
	var controller4 = ControllerScript.new()
	root.add_child(controller4)
	var bubble4 = MockBubble.new()
	root.add_child(bubble4)
	await process_frame

	controller4.start_dialogue(bubble4, "", choices, Vector2.ZERO)
	if controller4.state != controller4.State.NORMAL_OPTIONS or not bubble4.transitioned_to_normal:
		push_error("Empty text should immediately transition to NORMAL_OPTIONS")
		quit(1)
		return

	bubble4.queue_free()
	controller4.queue_free()
	await process_frame

	# --- Test 10: Dual Anchor Pipeline (Speaker & Player Positions) ---
	print("Test 10: Dual Anchor Pipeline Verification...")
	var controller5 = ControllerScript.new()
	root.add_child(controller5)
	var bubble5 = MockBubble.new()
	root.add_child(bubble5)
	await process_frame

	var speaker_pos := Vector2(250.0, 150.0)
	var player_pos := Vector2(120.0, 200.0)
	controller5.start_dialogue(bubble5, "Dual Anchor Test", choices, speaker_pos, {}, player_pos)

	if controller5.current_speaker_hud_pos != speaker_pos:
		push_error("Expected speaker_hud_pos to match %s, got %s" % [speaker_pos, controller5.current_speaker_hud_pos])
		quit(1)
		return
	if controller5.current_player_hud_pos != player_pos:
		push_error("Expected player_hud_pos to match %s, got %s" % [player_pos, controller5.current_player_hud_pos])
		quit(1)
		return
	if bubble5.player_hud_pos != player_pos:
		push_error("Expected bubble.player_hud_pos to match %s, got %s" % [player_pos, bubble5.player_hud_pos])
		quit(1)
		return

	# Update player position dynamically via controller
	var updated_player_pos := Vector2(135.0, 210.0)
	controller5.set_player_hud_position(updated_player_pos)
	if bubble5.player_hud_pos != updated_player_pos:
		push_error("Expected bubble.player_hud_pos to update to %s" % updated_player_pos)
		quit(1)
		return

	controller5.dismiss_if_active()
	bubble5.queue_free()
	controller5.queue_free()
	await process_frame

	print("\n>>> ALL DREAM DIALOGUE CONTROLLER TESTS (TASK-019-C) PASSED! <<<")
	quit(0)
