@tool
extends SceneTree

func _init() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	print("--- Starting DreamDialogueBubble Unit Tests (TASK-019-D) ---")
	
	var scene_res: Resource = load("res://scenes/ui/dialogue/dream_dialogue_bubble.tscn")
	assert(scene_res != null, "Scene resource failed to load")
	
	var bubble: DreamDialogueBubble = scene_res.instantiate() as DreamDialogueBubble
	assert(bubble != null, "Failed to instantiate DreamDialogueBubble")
	root.add_child(bubble)
	
	# Wait one frame for ready to complete
	await process_frame
	
	# Verify texture filters
	assert(bubble.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Bubble texture_filter must be NEAREST")
	assert(bubble.background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Background texture_filter must be NEAREST")
	assert(bubble.speaker_arrow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "SpeakerArrow texture_filter must be NEAREST")
	assert(bubble.dialogue_label.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "DialogueLabel texture_filter must be NEAREST")
	
	# Verify arrow size (dark base arrow is 19x12) and blue arrow inset presence
	assert(bubble.speaker_arrow.size == Vector2(19.0, 12.0), "Speaker arrow size must be 19x12")
	assert(bubble.arrow_fill_clip != null, "ArrowFillClip must exist")
	assert(bubble.arrow_fill_inset != null, "ArrowFillInset must exist")
	
	# Test get_dialogue_label()
	assert(bubble.get_dialogue_label() == bubble.dialogue_label, "get_dialogue_label() failed")
	
	# -------------------------------------------------------------------------
	# Test 1: Short text sizing and Dual Anchor (Speaker Bubble + Player Options)
	# -------------------------------------------------------------------------
	print("\n[Test 1] Short text sizing and Dual Anchor layout (TASK-019-D)...")
	var test_speaker_pos: Vector2 = Vector2(320.0, 200.0)
	bubble.show_dialogue("你好！", test_speaker_pos, ["我知道了", "再见"], "闭嘴")
	print("Short text bubble size: ", bubble.size)
	assert(bubble.size.x >= 160.0 and bubble.size.x <= 340.0, "Bubble width out of range")
	assert(bubble.size.y >= 48.0, "Bubble height below min 48")
	
	# Verify screen clamping
	print("Bubble position: ", bubble.position)
	assert(bubble.position.x >= 10.0 and bubble.position.x <= 640.0 - 10.0 - bubble.size.x, "Bubble X not clamped")
	assert(bubble.position.y >= 10.0 and bubble.position.y <= 360.0 - 10.0 - bubble.size.y, "Bubble Y not clamped")
	
	# Verify Speaker Arrow position and clamping
	print("Speaker arrow position: ", bubble.speaker_arrow.position)
	assert(bubble.speaker_arrow.position.x >= 16.0, "Speaker arrow X below 16.0")
	assert(bubble.speaker_arrow.position.x <= bubble.size.x - 16.0 - bubble.speaker_arrow.size.x, "Speaker arrow X exceeds right clamp")
	assert(bubble.speaker_arrow.position.y == bubble.size.y - 1.0, "Speaker arrow Y not along bottom edge")
	
	# Verify Bubble Anchor: positioned HEAD_CLEARANCE (28px) above speaker
	var actual_bubble_bottom_y: float = bubble.position.y + bubble.size.y
	var expected_bubble_bottom_y: float = test_speaker_pos.y - 28.0
	assert(is_equal_approx(actual_bubble_bottom_y, expected_bubble_bottom_y), "Bubble bottom must be exactly 28px above speaker (HEAD_CLEARANCE)")
	print("PASS: Bubble anchor confirmed (28px head clearance above speaker)")
	
	# Verify Dual Anchor: Player-Side Option Anchor
	var test_player_pos: Vector2 = Vector2(200.0, 250.0)
	bubble.set_player_hud_position(test_player_pos)
	var expected_opt_x: float = test_player_pos.x + 28.0
	var expected_opt_y: float = test_player_pos.y - 16.0
	assert(is_equal_approx(bubble.options_container.position.x, expected_opt_x), "Options X must be 28px to the right of player")
	assert(is_equal_approx(bubble.options_container.position.y, expected_opt_y), "Options Y must be player.y - 16px")
	print("PASS: Player-side options anchor confirmed (right of player)")
	
	# Verify Option Flipping when player is near the right edge of screen
	var right_edge_player_pos: Vector2 = Vector2(600.0, 250.0)
	bubble.set_player_hud_position(right_edge_player_pos)
	var expected_flipped_x: float = right_edge_player_pos.x - 28.0 - bubble.options_container.size.x
	assert(is_equal_approx(bubble.options_container.position.x, expected_flipped_x), "Options X must flip to the left of player when at right edge")
	print("PASS: Player-side options flip to left when near right screen edge")
	
	# Reset player position
	bubble.set_player_hud_position(test_player_pos)
	
	# -------------------------------------------------------------------------
	# Test 2: Countdown Bar & Arrow Inset: starts 100% full, disappears LEFT to RIGHT
	# -------------------------------------------------------------------------
	print("\n[Test 2] Countdown Bar & Arrow Inset (100% full -> disappears left-to-right)...")
	var inner_w: float = bubble.progress_bar_container.size.x
	
	# Progress 0.0: 100% full blue bar
	bubble.set_typing_progress(0.0, 0)
	assert(bubble.progress_fill_clip.position.x == 0.0, "Fill clip pos X must be 0 at progress 0.0")
	assert(is_equal_approx(bubble.progress_fill_clip.size.x, inner_w), "Fill bar width must be 100% full at progress 0.0")
	assert(bubble.progress_fill_bar.position.x == 0.0, "Fill bar texture offset must be 0 at progress 0.0")
	assert(bubble.progress_track.size.x == inner_w, "Track must span entire strip width")
	assert(bubble.arrow_fill_clip.visible == true, "Arrow blue inset must be visible at progress 0.0")
	assert(is_equal_approx(bubble.arrow_fill_clip.size.x, 15.0), "Arrow inset must be 15px full at progress 0.0")
	
	# Progress 0.5: Wipes left 50%, leaves right 50%
	bubble.set_typing_progress(0.5, 5)
	var expected_cut_x: float = round(inner_w * 0.5)
	var expected_rem_w: float = round(inner_w - expected_cut_x)
	assert(is_equal_approx(bubble.progress_fill_clip.position.x, expected_cut_x), "Fill clip cut_x must be at 50% at progress 0.5")
	assert(is_equal_approx(bubble.progress_fill_clip.size.x, expected_rem_w), "Fill clip width must be remaining 50% at progress 0.5")
	assert(is_equal_approx(bubble.progress_fill_bar.position.x, -expected_cut_x), "Fill bar texture must be offset by -cut_x")
	
	# Progress 1.0: Completely wiped out
	bubble.set_typing_progress(1.0, 10)
	assert(bubble.progress_fill_clip.size.x == 0.0 or not bubble.progress_fill_clip.visible, "Fill bar width must be 0 at progress 1.0")
	assert(bubble.arrow_fill_clip.size.x == 0.0 or not bubble.arrow_fill_clip.visible, "Arrow blue inset must be wiped out at progress 1.0")
	print("PASS: Left-to-right disappearing wipe confirmed for strip and arrow inset")
	
	# -------------------------------------------------------------------------
	# Test 3: Interrupt Button Signal & Mode Check (progress_ratio <= 0.20)
	# -------------------------------------------------------------------------
	print("\n[Test 3] Interrupt Mode (progress_ratio <= 0.20)...")
	bubble.show_dialogue("打断测试", test_speaker_pos, ["选项1", "选项2"], "闭嘴")
	bubble.set_typing_progress(0.10, 2)
	assert(bubble.interrupt_container.visible, "Interrupt container should be visible")
	assert(not bubble.normal_options_container.visible or bubble.normal_options_container.modulate.a == 0.0, "Normal options should be hidden")
	
	# Test interrupt button signal
	var test_state := {"interrupt": false, "option": -1}
	var interrupt_handler := func() -> void: test_state["interrupt"] = true
	bubble.interrupt_pressed.connect(interrupt_handler)
	bubble._on_interrupt_pressed()
	assert(test_state["interrupt"] == true, "interrupt_pressed signal did not emit")
	bubble.interrupt_pressed.disconnect(interrupt_handler)
	print("PASS: Interrupt button signal verified")
	
	# -------------------------------------------------------------------------
	# Test 4: Transition to Normal Options Mode (progress_ratio > 0.20)
	# -------------------------------------------------------------------------
	print("\n[Test 4] Transition to Normal Options Mode (progress_ratio > 0.20)...")
	bubble.set_typing_progress(0.25, 4)
	# Wait for 0.08s container fade + 0.14s entrance tween
	var timer: SceneTreeTimer = create_timer(0.25)
	await timer.timeout
	
	assert(not bubble.interrupt_container.visible, "Interrupt container should be hidden after transition")
	assert(bubble.normal_options_container.visible, "Normal options container should be visible")
	assert(bubble.normal_options_container.modulate.a > 0.9, "Normal options should be fully opaque")
	
	# Test option button signal
	var option_handler := func(idx: int) -> void: test_state["option"] = idx
	bubble.option_pressed.connect(option_handler)
	bubble._on_option_button_pressed(1)
	assert(test_state["option"] == 1, "option_pressed signal did not emit expected index")
	bubble.option_pressed.disconnect(option_handler)
	print("PASS: Normal options transition and button signal verified")
	
	# -------------------------------------------------------------------------
	# Test 5: Option Entrance Animations (TASK-019-D)
	# -------------------------------------------------------------------------
	print("\n[Test 5] Option Entrance Animations (TASK-019-D)...")
	var bubble_anim: DreamDialogueBubble = scene_res.instantiate() as DreamDialogueBubble
	root.add_child(bubble_anim)
	await process_frame
	
	# Red Interrupt Option entrance animation:
	# Starts at offset.x = +10.0, scale = (0.94, 0.94), modulate.a = 0.0
	bubble_anim.show_dialogue("入场动效测试", Vector2(320.0, 200.0), ["选项A", "选项B"], "打断")
	var int_btn: DreamDialogueBubble.DreamOptionButton = bubble_anim._interrupt_button
	assert(int_btn != null, "Interrupt button must exist")
	# Check initial entrance animation properties
	assert(int_btn.position.x > 0.0, "Interrupt entrance must start offset to right (+10px)")
	assert(int_btn.scale == Vector2.ONE, "Interrupt entrance keeps native glyph scale")
	
	# Wait for 0.10s entrance tween to complete
	var anim_timer: SceneTreeTimer = create_timer(0.15)
	await anim_timer.timeout
	assert(is_equal_approx(int_btn.position.x, 0.0), "Interrupt button position.x must end at 0.0")
	assert(is_equal_approx(int_btn.scale.x, 1.0) and is_equal_approx(int_btn.scale.y, 1.0), "Interrupt button scale must end at Vector2.ONE")
	assert(is_equal_approx(int_btn.modulate.a, 1.0), "Interrupt button modulate.a must end at 1.0")
	print("PASS: Red Interrupt option entrance animation verified (0.10s, +10px, native glyph scale)")
	
	# Normal Options entrance animation:
	# Starts at offset.x = +14.0, native scale, modulate.a = 0.0, staggered by 0.03s
	bubble_anim.transition_to_normal_options()
	var normal_btn0: DreamDialogueBubble.DreamOptionButton = bubble_anim.normal_options_container.get_child(0) as DreamDialogueBubble.DreamOptionButton
	var normal_btn1: DreamDialogueBubble.DreamOptionButton = bubble_anim.normal_options_container.get_child(1) as DreamDialogueBubble.DreamOptionButton
	assert(normal_btn0 != null and normal_btn1 != null, "Normal option buttons must exist")
	
	# Initially after transition starts, button 0 starts offset
	assert(normal_btn0.position.x > 0.0, "Normal option entrance must start offset to right (+14px)")
	assert(normal_btn0.scale == Vector2.ONE, "Normal option entrance keeps native glyph scale")
	
	# Wait for normal options entrance tween to complete (0.14s + 0.03s stagger)
	var anim_timer2: SceneTreeTimer = create_timer(0.25)
	await anim_timer2.timeout
	assert(is_equal_approx(normal_btn0.position.x, 0.0), "Normal button 0 position.x must end at 0.0")
	assert(is_equal_approx(normal_btn0.scale.x, 1.0), "Normal button 0 scale must end at Vector2.ONE")
	assert(is_equal_approx(normal_btn0.modulate.a, 1.0), "Normal button 0 alpha must end at 1.0")
	assert(is_equal_approx(normal_btn0.modulate.r, 0.5), "Normal button 0 idle RGB must be 50%")
	assert(is_equal_approx(normal_btn1.position.x, 0.0), "Normal button 1 position.x must end at 0.0")
	assert(is_equal_approx(normal_btn1.scale.x, 1.0), "Normal button 1 scale must end at Vector2.ONE")
	assert(is_equal_approx(normal_btn1.modulate.a, 1.0), "Normal button 1 alpha must end at 1.0")
	print("PASS: Normal options entrance animation verified (0.14s, +14px, native glyph scale, 0.03s stagger)")
	
	bubble_anim.queue_free()
	
	# -------------------------------------------------------------------------
	# Test 6: Long multiline text adaptive growth & Screen clamping
	# -------------------------------------------------------------------------
	print("\n[Test 6] Long multiline text adaptive growth...")
	var long_text: String = "这是一段很长很长的测试对话内容，必须超过单行三白像素的限制，从而触发自动换行并使气泡高度在垂直方向自适应增长。"
	bubble.show_dialogue(long_text, Vector2(50.0, 50.0), ["选项A", "选项B"])
	print("Long text bubble size: ", bubble.size)
	assert(bubble.size.x == 340.0, "Long text bubble width should be max width 340")
	assert(bubble.size.y > 48.0, "Long text bubble height should grow vertically beyond 48")
	
	# Screen clamp on edge position
	assert(bubble.position.x >= 10.0, "Bubble X clamp failed on left edge")
	assert(bubble.position.y >= 10.0, "Bubble Y clamp failed on top edge")
	print("PASS: Adaptive multiline size and edge clamping verified")
	
	# -------------------------------------------------------------------------
	# Test 7: End-to-end integration with DreamDialogueController
	# -------------------------------------------------------------------------
	print("\n[Test 7] Integration with DreamDialogueController...")
	var controller: DreamDialogueController = DreamDialogueController.new()
	root.add_child(controller)
	
	var controller_state := {"interrupted": false, "finished": false}
	controller.dialogue_interrupted.connect(func() -> void: controller_state["interrupted"] = true)
	
	controller.dialogue_finished.connect(func(interrupted: bool, action_id: Variant) -> void:
		controller_state["finished"] = true
		print("Controller finished: interrupted=", interrupted, " action_id=", action_id)
	)
	
	controller.start_dialogue(bubble, "通过控制器测试对话流程", [{"text": "好", "action_id": "ok"}], Vector2(300.0, 200.0))
	assert(controller.is_active(), "Controller should be active")
	assert(controller.can_interrupt(), "Controller should be in interrupt state initially")
	
	# Simulate trigger_interrupt
	controller.trigger_interrupt()
	assert(controller_state["interrupted"] == true, "Controller interrupt failed")
	
	# Wait for interrupt dismiss
	var dismiss_timer: SceneTreeTimer = create_timer(0.7)
	await dismiss_timer.timeout
	assert(controller_state["finished"] == true, "Controller finished event not received")
	
	controller.queue_free()
	print("PASS: Controller interrupt flow verified")
	
	# -------------------------------------------------------------------------
	# Test 8: Normal option selection through DreamDialogueController
	# -------------------------------------------------------------------------
	print("\n[Test 8] Normal option selection through DreamDialogueController...")
	var bubble2: DreamDialogueBubble = scene_res.instantiate() as DreamDialogueBubble
	root.add_child(bubble2)
	await process_frame
	
	var controller2: DreamDialogueController = DreamDialogueController.new()
	root.add_child(controller2)
	
	var test_state2 := {"interrupted": true, "choice_action": null}
	controller2.dialogue_finished.connect(func(interrupted: bool, action_id: Variant) -> void:
		test_state2["interrupted"] = interrupted
		test_state2["choice_action"] = action_id
		print("Controller2 finished: interrupted=", interrupted, " action_id=", action_id)
	)
	
	controller2.start_dialogue(bubble2, "请做出你的选择", [{"text": "接受挑战", "action_id": "accept"}], Vector2(320.0, 240.0))
	# Advance countdown to finished (progress = 1.0)
	controller2.typed_chars = controller2.total_chars
	controller2.progress = 1.0
	controller2.state = DreamDialogueController.State.WAITING_INPUT
	bubble2.set_typing_progress(1.0, controller2.total_chars)
	
	var wait_tween: SceneTreeTimer = create_timer(0.25)
	await wait_tween.timeout
	
	# Select option 0
	bubble2.option_pressed.emit(0)
	
	assert(test_state2["interrupted"] == false, "Dialogue should not be interrupted")
	assert(str(test_state2["choice_action"]) == "accept", "Action ID should be 'accept'")
	
	controller2.queue_free()
	bubble2.queue_free()
	print("PASS: Controller normal option flow verified")
	
	# -------------------------------------------------------------------------
	# Test 9: Button styling and hover feedback verification (BUG-1)
	# -------------------------------------------------------------------------
	print("\n[Test 9] Button styling and hover feedback (BUG-1)...")
	var bubble3: DreamDialogueBubble = scene_res.instantiate() as DreamDialogueBubble
	root.add_child(bubble3)
	await process_frame
	bubble3.show_dialogue("测试按钮样式", Vector2(320.0, 200.0), [{"text": "普通选项", "action_id": "normal"}], "打断")
	
	# Wait for interrupt entrance animation to finish
	var wait_int_anim: SceneTreeTimer = create_timer(0.15)
	await wait_int_anim.timeout
	
	# Test interrupt button styles
	var int_btn3: DreamDialogueBubble.DreamOptionButton = bubble3._interrupt_button
	assert(int_btn3 != null, "Interrupt button must exist")
	assert(int_btn3.flat == false, "Interrupt button flat must be false (BUG-1 fix)")
	assert(int_btn3.is_interrupt == true, "Interrupt button is_interrupt flag must be true")
	assert(int_btn3.border_color == Color("#F80709"), "Interrupt border must be #F80709")
	assert(int_btn3.get_theme_color(&"font_color") == Color("#F80709"), "Interrupt text must be #F80709")
	assert(int_btn3.has_theme_stylebox_override(&"normal"), "Interrupt button must have StyleBoxTexture normal override")
	
	# Hover interrupt button
	int_btn3._on_mouse_entered()
	assert(int_btn3.border_color == Color("#F80709"), "Interrupt button must maintain red border on hover")
	assert(int_btn3.modulate.r > 1.0, "Interrupt button should have subtle brightness feedback on hover")
	assert(int_btn3.border_color != Color("#8090BD"), "Interrupt button must NEVER turn #8090BD")
	int_btn3._on_mouse_exited()
	assert(int_btn3.border_color == Color("#F80709"), "Interrupt button must remain red on exit")
	
	# Transition to normal options and wait for entrance tween to complete
	bubble3.transition_to_normal_options()
	var wait_norm_anim: SceneTreeTimer = create_timer(0.25)
	await wait_norm_anim.timeout
	
	var normal_btn: DreamDialogueBubble.DreamOptionButton = bubble3.normal_options_container.get_child(0) as DreamDialogueBubble.DreamOptionButton
	assert(normal_btn != null, "Normal option button must exist")
	assert(normal_btn.flat == false, "Normal button flat must be false (BUG-1 fix)")
	assert(normal_btn.is_interrupt == false, "Normal button is_interrupt must be false")
	assert(is_equal_approx(normal_btn.modulate.r, 0.5) and is_equal_approx(normal_btn.modulate.a, 1.0), "Normal button idle brightness must be 50% with alpha 1.0")
	assert(normal_btn.border_color.a == 0.0, "Normal button idle border must be transparent")
	assert(normal_btn.has_theme_stylebox_override(&"normal"), "Normal button must have StyleBoxTexture normal override")
	
	# Hover normal button
	normal_btn._on_mouse_entered()
	assert(is_equal_approx(normal_btn.modulate.r, 1.0), "Normal button hover brightness must be 100%")
	assert(normal_btn.border_color == Color("#8090BD"), "Normal button hover border must be #8090BD")
	normal_btn._on_mouse_exited()
	assert(is_equal_approx(normal_btn.modulate.r, 0.5), "Normal button exit brightness must be 50%")
	assert(normal_btn.border_color.a == 0.0, "Normal button exit border must be transparent")
	
	bubble3.queue_free()
	print("PASS: Button styling and hover feedback verified")
	
	# -------------------------------------------------------------------------
	# Test 10: Bubble Pinning & Dynamic NPC Head Pinning Arrow Tracking
	# -------------------------------------------------------------------------
	print("\n[Test 10] Bubble Pinning & Arrow Tracking Edge Cases...")
	var bubble4: DreamDialogueBubble = scene_res.instantiate() as DreamDialogueBubble
	root.add_child(bubble4)
	await process_frame
	
	# Case A: Center position (320.0, 220.0)
	var center_speaker: Vector2 = Vector2(320.0, 220.0)
	bubble4.show_dialogue("头部对齐测试", center_speaker, ["选项1"])
	var b_w: float = bubble4.size.x
	var b_h: float = bubble4.size.y
	var arrow_w: float = bubble4.speaker_arrow.size.x
	
	# Verify bubble Y: bottom edge is exactly 28px above speaker
	assert(is_equal_approx(bubble4.position.y + b_h, center_speaker.y - 28.0), "Bubble bottom must be HEAD_CLEARANCE (28px) above speaker")
	# Verify bubble X is centered over speaker
	assert(is_equal_approx(bubble4.position.x, center_speaker.x - (b_w * 0.5)), "Bubble X must be centered over speaker")
	# Arrow center matches speaker X (within 0.5px due to integer pixel rounding)
	var arrow_screen_center_x: float = bubble4.position.x + bubble4.speaker_arrow.position.x + (arrow_w * 0.5)
	assert(absf(arrow_screen_center_x - center_speaker.x) <= 1.0, "Center: Arrow tip must point directly at speaker X")
	print("PASS: Case A (Center): Arrow dead center above speaker")
	
	# Case B: Left edge clamping - speaker near left screen edge (x = 50)
	# Desired X: 50 - 80 = -30, clamped to SCREEN_MARGIN (10.0)
	var left_speaker: Vector2 = Vector2(50.0, 200.0)
	bubble4.set_speaker_hud_position(left_speaker)
	assert(is_equal_approx(bubble4.position.x, 10.0), "Left edge: Bubble X must clamp to SCREEN_MARGIN 10.0")
	var arrow_left_center: float = bubble4.position.x + bubble4.speaker_arrow.position.x + (arrow_w * 0.5)
	assert(absf(arrow_left_center - left_speaker.x) <= 1.0, "Left edge: Arrow tip must track speaker X even when bubble is clamped")
	print("PASS: Case B (Left edge): Arrow tip strictly tracks speaker head X despite bubble body clamp")
	
	# Case C: Right edge clamping - speaker near right screen edge (x = 600)
	# Desired X: 600 - 80 = 520, clamped to 640 - 10 - b_w = 470.0
	var right_speaker: Vector2 = Vector2(600.0, 200.0)
	bubble4.set_speaker_hud_position(right_speaker)
	var max_bubble_x: float = 640.0 - 10.0 - b_w
	assert(is_equal_approx(bubble4.position.x, max_bubble_x), "Right edge: Bubble X must clamp to right screen margin")
	var arrow_right_center: float = bubble4.position.x + bubble4.speaker_arrow.position.x + (arrow_w * 0.5)
	assert(absf(arrow_right_center - right_speaker.x) <= 1.0, "Right edge: Arrow tip must track speaker X even when bubble is clamped")
	print("PASS: Case C (Right edge): Arrow tip strictly tracks speaker head X despite bubble body clamp")
	
	# Case D: Extreme left off-screen - arrow clamped to inner minimum (16.0)
	var extreme_left: Vector2 = Vector2(-100.0, 200.0)
	bubble4.set_speaker_hud_position(extreme_left)
	assert(is_equal_approx(bubble4.speaker_arrow.position.x, 16.0), "Extreme left: Arrow X clamped to 16.0")
	print("PASS: Case D: Extreme left arrow clamp to 16.0 verified")
	
	# Case E: Extreme right off-screen - arrow clamped to inner maximum (size.x - 16.0 - arrow_w)
	var extreme_right: Vector2 = Vector2(1000.0, 200.0)
	bubble4.set_speaker_hud_position(extreme_right)
	var max_arrow_x: float = b_w - 16.0 - arrow_w
	assert(is_equal_approx(bubble4.speaker_arrow.position.x, max_arrow_x), "Extreme right: Arrow X clamped to inner max")
	print("PASS: Case E: Extreme right arrow clamp to inner max verified")
	
	# Case F: Screen margin vertical clamping (top edge)
	var top_speaker: Vector2 = Vector2(320.0, 30.0)
	bubble4.set_speaker_hud_position(top_speaker)
	assert(is_equal_approx(bubble4.position.y, 10.0), "Top edge: Bubble Y must clamp to SCREEN_MARGIN 10.0")
	print("PASS: Case F: Screen margin vertical clamping verified")
	
	bubble4.queue_free()
	
	print("\n>>> ALL TESTS PASSED SUCCESSFULLY! <<<")
	quit()
