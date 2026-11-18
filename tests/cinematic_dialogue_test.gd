extends SceneTree

const SCENE := preload("res://scenes/ui/dialogue/cinematic_dialogue.tscn")
const PRESENTER := preload("res://scripts/ui/dialogue/cinematic_dialogue.gd")
var output := "res://.runtime/cinematic_dialogue_20261117/logic"
var checks: Array[Dictionary] = []
var started := 0
var ended := 0
var dialogue: PRESENTER


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	run.call_deferred()


func check(value: bool, description: String) -> void:
	checks.append({"pass": value, "description": description})
	print("PASS " if value else "FAIL ", description)


func frames(count: int = 3) -> void:
	for _i in count: await process_frame


func tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		check(false, "Private muted settings must exist before entry")
		finish(); return
	root.content_scale_size = Vector2i(640, 360)
	dialogue = SCENE.instantiate()
	dialogue.use_side_choices = true
	root.add_child(dialogue)
	dialogue.session_started.connect(func(): started += 1)
	dialogue.session_ended.connect(func(): ended += 1)
	await frames()
	await dialogue.open_data({"lines": [
		{"speaker": "left", "text": "先在这里停一下。\n等我确认前面的通道。", "blip": false},
		{"speaker": "right", "text": "好，我在这里等你。", "blip": false}
	]})
	check(dialogue.visible and started == 1 and not dialogue.animating, "Inherited dialogue session opens once and completes its entrance")
	check(is_equal_approx(dialogue.portrait.modulate.a, 1.0) and is_equal_approx(dialogue.dialogue_panel.modulate.a, 1.0), "Portrait and text entrance reach full visible alpha")
	check(dialogue.active_side == &"left" and dialogue.character_art.modulate == Color.WHITE, "Left speaker uses the unfiltered original portrait")
	check(dialogue.right_art.visible, "Two distinct speaking participants enable the right portrait")
	check(is_equal_approx(dialogue.right_art.modulate.a, 0.9) and dialogue.right_art.modulate.r < 0.5, "Right listener keeps 90 percent opacity and darkens")
	check(dialogue.right_art.position.y - dialogue.character_art.position.y >= 28.0, "Right listener sits visibly lower than the speaking portrait")
	check(dialogue.character_art.position.x >= 30.0 and dialogue.right_art.get_rect().end.x <= 610.0, "Both portraits retain visible insets from the screen edges")
	check(dialogue.background.color.a > 0.3 and dialogue.background.get_index() < dialogue.portrait.get_index(), "Whole scene is dimmed behind the portrait layer")
	check(dialogue.veil.get_index() > dialogue.portrait.get_index() and dialogue.veil.get_index() < dialogue.dialogue_panel.get_index(), "Arc and halftone veil fades portrait bottoms without covering dialogue text")
	check(dialogue.dialogue_panel.get_script() == null and dialogue.prompt_label.get_theme_font_size(&"font_size") == 12, "Dialogue has no legacy frame and uses the readable native-size font")
	dialogue._complete_typewriter()
	check(dialogue.prompt_label.get_line_count() == 2 and dialogue.prompt_label.visible_characters == -1, "Explicit two-line dialogue remains readable after reveal completion")
	dialogue._on_cancelled()
	await create_timer(0.21).timeout
	check(dialogue.active_side == &"right" and dialogue.right_art.modulate == Color.WHITE, "Next line transfers speaker emphasis to the right portrait")
	check(dialogue.character_art.position.y > dialogue.right_art.position.y and is_equal_approx(dialogue.character_art.modulate.a, 0.9), "Left portrait becomes the lowered listener when the speaker changes")
	dialogue._begin_typewriter("测试说话帧", {"speaker": "right", "two_person_dialogue": true, "text": "测试说话帧", "blip": false, "typewriter_speed": 10.0})
	dialogue._reveal_next_character()
	check((dialogue.right_art.texture as AtlasTexture).atlas == dialogue.PORTRAIT_IDLE and (dialogue.character_art.texture as AtlasTexture).atlas == dialogue.PORTRAIT_IDLE, "Revealing letters preserves both characters' selected portraits")
	dialogue._complete_typewriter()
	check((dialogue.right_art.texture as AtlasTexture).atlas == dialogue.PORTRAIT_IDLE, "Completing a line preserves the active portrait state")
	dialogue._on_cancelled()
	await create_timer(0.26).timeout
	check(not dialogue.visible and ended == 1, "Final advance closes the UI and emits one session end")
	await dialogue.open_data({"lines": [{"text": "选择下一步。", "typewriter_speed": 0.0, "choices": [
		{"text": "继续", "enabled": false}, {"text": "返回", "action_id": "close", "next": "close"}]}]})
	check(dialogue.buttons.visible and dialogue.choice_buttons[0].disabled and not dialogue.choice_buttons[1].disabled, "Existing choice enablement survives the new presentation")
	var start_pos := dialogue.buttons.position
	check(start_pos.x >= 640.0 and not dialogue.side_choice_list.interactive, "Side choices begin beyond the right edge with their hitboxes locked")
	dialogue._on_choice_pressed(1)
	check(dialogue.visible and ended == 1, "A choice cannot dispatch while its row is sliding")
	await create_timer(0.09).timeout
	check(dialogue.buttons.position.x < start_pos.x and dialogue.buttons.position.y == start_pos.y,
		"Choice entrance travels left without changing height")
	await create_timer(0.21).timeout
	check(dialogue.side_choice_list.interactive and dialogue.buttons.get_global_rect().end.x <= 640.0
		and dialogue.buttons.get_global_rect().end.y < dialogue.prompt_label.get_global_rect().position.y,
		"Side choices settle above the unchanged subtitle area with working hitboxes")
	dialogue._on_choice_pressed(0)
	check(dialogue.visible, "Disabled choice cannot close the dialogue")
	dialogue._on_choice_pressed(1)
	await create_timer(0.26).timeout
	check(not dialogue.visible and ended == 2, "Enabled choice retains the original close behavior")
	var long_text := "这是一段用于检查长对话的文字，需要在固定宽度内自动换行，并且不能超出画面底部。".repeat(5)
	await dialogue.open_data({"lines": [{"text": long_text, "blip": false, "completion_action_id": "close", "choices": [{"text": "完成", "next": "close"}]}]})
	check(dialogue.dialogue_lines.size() > 1, "Long narrative is paginated before typewriter playback")
	var page_text := ""
	var pages_fit := true
	for index in dialogue.dialogue_lines.size():
		dialogue.dialogue_line_index = index
		dialogue._show_current_line()
		dialogue._complete_typewriter()
		await frames(1)
		page_text += dialogue.full_prompt_text
		pages_fit = pages_fit and dialogue.prompt_label.get_line_count() <= 2 and dialogue.prompt_label.get_global_rect().end.y <= 353.0
		if index < dialogue.dialogue_lines.size() - 1:
			pages_fit = pages_fit and dialogue.current_choices.is_empty() and not dialogue.current_line.has("completion_action_id")
	check(page_text == long_text and pages_fit, "All long-text characters survive pagination; completion and choices stay on the final page")
	dialogue.close_without_signal()
	check(not dialogue.visible and ended == 3 and dialogue.current_line.is_empty(), "Immediate close clears narrative and session state")
	await dialogue.open_data({"lines": [{"speaker": "right", "portrait": "hidden", "text": "这里只显示文字。", "typewriter_speed": 0.0}]})
	check(not dialogue.portrait.visible and dialogue.prompt_label.text == "这里只显示文字。", "Portrait-hidden lines retain the same centered text region")
	dialogue.close_without_signal()
	await dialogue.open_data({"lines": [{"speaker": "left", "text": "重新开始。", "typewriter_speed": 0.0}]})
	check(dialogue.portrait.visible and dialogue.active_side == &"left" and dialogue.right_art.position.y > dialogue.character_art.position.y, "Reopening resets speaker, listener and visibility without stale animation")
	check(not dialogue.right_art.visible and dialogue.character_art.modulate == Color.WHITE, "A new monologue clears the prior right portrait and keeps the sole speaker bright")
	await tap(&"ui_accept")
	await create_timer(0.26).timeout
	check(not dialogue.visible, "Enter input advances and closes a finished narrative line")
	await dialogue.open_data({"lines": [
		{"speaker": "left", "text": "第一句。", "typewriter_speed": 0.0},
		{"speaker": "right", "text": "第二句。", "typewriter_speed": 0.0}
	]})
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = dialogue.input_blocker.get_global_rect().get_center()
	mouse.global_position = mouse.position
	mouse.pressed = true
	var motion := InputEventMouseMotion.new()
	motion.position = mouse.position
	motion.global_position = mouse.position
	root.push_input(motion, true)
	await frames(2)
	root.push_input(mouse, true)
	await frames(3)
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = dialogue.input_blocker.get_global_rect().get_center()
	mouse.global_position = mouse.position
	root.push_input(mouse, true)
	await frames(3)
	check(dialogue.dialogue_line_index == 1 and dialogue.active_side == &"right", "A real left click through the input blocker advances to the right speaker")
	dialogue.close_without_signal()
	await dialogue.open_data({"lines": [{"text": "键盘选择。", "typewriter_speed": 0.0, "choices": [
		{"text": "不可用", "enabled": false}, {"text": "返回", "next": "close", "action_id": "close"}]}]})
	await create_timer(0.29).timeout
	await tap(&"ui_down")
	check(dialogue.choice_option_group.get_active_index() == 1, "Keyboard choice navigation skips disabled options")
	await tap(&"ui_accept")
	await create_timer(0.26).timeout
	check(not dialogue.visible, "Keyboard confirmation activates the selected enabled option")
	var id := dialogue.get_instance_id()
	dialogue.queue_free()
	await frames()
	check(not is_instance_id_valid(id), "Leaving the UI releases the dialogue and its speaker tweens")
	await test_local_interrupt()
	await test_external_controller()
	await test_participant_visibility()
	finish()


func test_local_interrupt() -> void:
	var view: PRESENTER = SCENE.instantiate()
	root.add_child(view)
	view.set_process(false)
	var actions: Array[StringName] = []
	var cancellations: Array[bool] = []
	view.action_requested.connect(func(action: StringName): actions.append(action))
	view.cancelled.connect(func(): cancellations.append(true))
	var script_data := {"lines": [
		{"text": "前面的门已经打开了。\n请继续往前走。", "typewriter_speed": 0.4, "blip": false,
			"choices": [{"text": "睡觉", "action_id": "begin_sleep"}]},
		{"text": "这句不应出现。"},
	]}
	await view.open_data(script_data)
	view._process(5.5)
	var stop := view.side_choice_list.interrupt_button
	check(stop.is_visible_in_tree() and stop.text == "闭嘴" and not view.buttons.is_visible_in_tree(),
		"Typing exposes only the dedicated interrupt choice")
	var prefix := view.prompt_label.text.substr(0, view.prompt_label.visible_characters).replace("\n", "")
	var origin := view.prompt_label.get_global_transform() * view.prompt_label.get_character_bounds(0).position
	stop.pressed.emit()
	var scatter := view._interrupt_fragments
	var copies := ""
	if is_instance_valid(scatter):
		for glyph: Label in scatter.get_children():
			copies += glyph.text
	check(is_instance_valid(scatter) and copies == prefix and (scatter.get_child(0) as Label).global_position.is_equal_approx(origin),
		"Interrupt detaches the visible prefix from its actual label positions")
	check(not view.typewriter_active and not stop.is_visible_in_tree() and is_zero_approx(view.dialogue_panel.modulate.a),
		"Interrupt stops typing and removes the original text and choices immediately")
	await create_timer(0.24).timeout
	check(not view.visible and view.dialogue_line_index == 0 and actions.is_empty() and cancellations.size() == 1,
		"Interrupt closes the whole dialogue without dispatching a listed action")
	view.open_data(script_data)
	check(view.is_dialogue_entering() and view._interrupt_fragments == null and (not is_instance_valid(scatter) or scatter.is_queued_for_deletion()),
		"A quick reopen clears the previous letters before entering")
	stop.pressed.emit()
	await create_timer(0.24).timeout
	check(not view.visible and view._interrupt_fragments == null and cancellations.size() == 2,
		"Interrupt during entrance closes without creating unrevealed letters")
	view.queue_free()
	await frames()


func test_external_controller() -> void:
	var view: PRESENTER = SCENE.instantiate()
	view.use_side_choices = true
	view.externally_driven = true
	view.default_speaker_side = "right"
	view.two_person_dialogue = true
	root.add_child(view)
	var controller := preload("res://scripts/ui/dialogue/dream_dialogue_controller.gd").new()
	root.add_child(controller)
	controller.set_process(false)
	controller.start_dialogue_sequence(view, ["第一段对话，需要由原控制器逐字显示。", "第二段对话。"], func(): return Vector2(320, 120), {"compact_dialogue": true, "countdown_extra": 4.0}, func(): return Vector2(320, 240))
	controller._process(controller.typewriter_speed * 4.5)
	check(view.externally_driven and not view.is_processing() and controller.current_bubble == view, "Reception keeps the existing controller as its only typing and countdown authority")
	check(controller.typed_chars == 0 and is_zero_approx(controller.elapsed) and view.prompt_label.visible_characters == 0, "Typing, blips and countdown remain at zero during entrance")
	check(view.is_dialogue_entering() and view.character_art.get_rect().end.x < 0.0 and view.right_art.position.x > 640.0 and is_zero_approx(view.dialogue_panel.modulate.a), "Entrance starts with portraits off both sides and dialogue text hidden")
	await tap(&"pickup_weapon")
	check(controller._sequence_index == 0, "Advance input cannot skip a line before the UI finishes entering")
	await create_timer(view.entrance_seconds + 0.03).timeout
	check(not view.is_dialogue_entering() and is_equal_approx(view._presentation_progress, 1.0) and view.character_art.position.x == view.LEFT_REST.x and view.right_art.position.x == view.RIGHT_REST.x, "Matte and both portraits arrive before the dialogue clock starts")
	controller._process(controller.typewriter_speed * 4.5)
	check(view.prompt_label.visible_characters == 4 and not view.typewriter_active and view.active_side == &"right" and (view.right_art.texture as AtlasTexture).atlas == view.PORTRAIT_IDLE, "External progress reveals the right speaker's letters without cycling their portrait")
	await create_timer(0.12).timeout
	check(view.prompt_label.visible_characters == 4, "UI entrance and elapsed real time do not advance a second typewriter")
	await tap(&"pickup_weapon")
	await create_timer(0.15).timeout
	check(controller._sequence_index == 1 and view.prompt_label.text == "第二段对话。", "E advances the existing sequence through the new fullscreen view")
	check(not view.is_dialogue_entering() and view._presentation_progress == 1.0, "The next line reuses the settled presentation without replaying its entrance")
	controller._process(controller.line_total_duration + 0.01)
	await create_timer(0.2).timeout
	check(not controller.is_active() and not view.visible, "Original countdown completion closes the new presentation")
	check(is_zero_approx(view._presentation_progress) and view.character_art.get_rect().end.x < 0.0 and view.right_art.position.x > 640.0 and is_zero_approx(view.dialogue_panel.modulate.a), "Exit retracts the matte and both portraits with text hidden before the black backing leaves")
	controller.start_dialogue(view, "选择下一步。", [{"text": "返回", "action_id": "close"}], Vector2.ZERO, {"typewriter_speed": 0.0})
	await create_timer(view.entrance_seconds + 0.03).timeout
	controller._process(controller.line_total_duration * 0.25)
	await create_timer(0.29).timeout
	check(view.buttons.visible and view.side_choice_list.interactive, "Controller's normal-options state exposes the animated side choices")
	var picked: Array[int] = []
	var internal_actions: Array[StringName] = []
	controller.dialogue_option_selected.connect(func(index: int, _data: Dictionary): picked.append(index))
	view.action_requested.connect(func(action: StringName): internal_actions.append(action))
	view._on_choice_pressed(0)
	await create_timer(0.2).timeout
	check(picked == [0] and internal_actions.is_empty() and not controller.is_active(), "Option selection dispatches once through the external controller without duplicate actions")
	controller.start_dialogue(view, "旧句子。", [], Vector2.ZERO, {"compact_dialogue": true})
	view.dismiss(0.1)
	controller.start_dialogue(view, "新的句子。", [], Vector2.ZERO, {"compact_dialogue": true})
	await create_timer(view.entrance_seconds + 0.03).timeout
	check(view.visible and view.prompt_label.text == "新的句子。", "Restarting during a fade cancels the obsolete dismissal")
	var long_text := "这是一段需要自动分页的较长对话，所有文字仍然由同一个控制器计数。".repeat(5)
	controller.start_dialogue(view, long_text, [], Vector2.ZERO, {"compact_dialogue": true})
	await create_timer(view.entrance_seconds + 0.03).timeout
	view.set_typing_progress(0.5, long_text.length())
	check(view.dialogue_lines.size() > 1 and view.dialogue_line_index == view.dialogue_lines.size() - 1 and view.prompt_label.visible_characters == view.full_prompt_text.length(), "Long external dialogue pages fit the existing text area without truncating its final page")
	view.close_without_signal()
	await view.open_data({"lines": [{"text": "旧文案保留。", "font_size": 18, "typewriter_speed": 0.0}]})
	check(view.prompt_label.get_theme_font_size(&"font_size") == 12, "Legacy 18px metadata adopts the approved 12px layout without changing story data")
	controller.dismiss_if_active()
	view.close_without_signal()
	controller.start_dialogue(view, "中途关闭。", [], Vector2.ZERO, {"compact_dialogue": true})
	controller.dismiss_if_active()
	await create_timer(0.2).timeout
	check(not view.visible and not view.is_dialogue_entering(), "Canceling during entrance leaves no active motion or waiting dialogue clock")
	controller.start_dialogue_sequence(view, ["请等我把这一句说完。", "这句不应出现。"], Callable(), {"compact_dialogue": true})
	await create_timer(view.entrance_seconds + 0.03).timeout
	controller._process(controller.typewriter_speed * 5.5)
	check(controller.state == controller.State.NORMAL_OPTIONS and controller.can_interrupt(),
		"Cinematic dialogue can interrupt while typing in the normal controller state")
	controller.advance_sequence()
	view.side_choice_list.interrupt_button.pressed.emit()
	check(not controller.is_active() and not controller._is_in_sequence and is_instance_valid(view._interrupt_fragments),
		"Interrupt aborts the pending next line immediately")
	controller.start_dialogue_sequence(view, ["重新开始。", "仍需等待。"], Callable(), {"compact_dialogue": true})
	await create_timer(view.entrance_seconds + 0.04).timeout
	check(controller.is_active() and controller._sequence_index == 0 and view.prompt_label.text == "重新开始。",
		"An obsolete line transition cannot advance a restarted conversation")
	var view_id := view.get_instance_id()
	controller.queue_free()
	view.queue_free()
	await frames()
	check(not is_instance_id_valid(view_id), "External controller and presentation release cleanly after repeated use")


func test_participant_visibility() -> void:
	var view: PRESENTER = SCENE.instantiate()
	root.add_child(view)
	await view.open_data({"lines": [
		{"speaker": "player", "text": "独白。", "typewriter_speed": 0.0},
		{"speaker": "system", "text": "系统提示。", "typewriter_speed": 0.0}
	]})
	check(not view.right_art.visible and view.character_art.visible and view.active_side == &"left", "A player's monologue and system narration do not invent a second participant")
	view.close_without_signal()
	await view.open_data({"lines": [{"speaker": "right", "text": "只有一个说话的人。", "typewriter_speed": 0.0}]})
	check(not view.right_art.visible and view.active_side == &"left" and view.character_art.modulate == Color.WHITE, "A sole speaker is presented on the left even when their identifier is right")
	view.close_without_signal()
	await view.open_data({"lines": [{"speaker": "right", "text": "与另一位角色交谈。", "two_person_dialogue": true, "typewriter_speed": 0.0}]})
	check(view.right_art.visible and view.active_side == &"right", "Explicit two-person context includes a silent listener even when only one character has dialogue")
	view.close_without_signal()
	view.two_person_dialogue = true
	await view.open_data({"lines": [{"speaker": "player", "text": "临时独白。", "two_person_dialogue": false, "typewriter_speed": 0.0}]})
	check(not view.right_art.visible and view.active_side == &"left", "An explicit monologue overrides a view normally used for two-person conversations")
	view.close_without_signal()
	view.queue_free()
	await frames()


func finish() -> void:
	var failures := checks.filter(func(row: Dictionary): return not row.pass).size()
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"pid": OS.get_process_id(), "audio": AudioServer.get_driver_name(), "checks": checks, "failures": failures}, "\t"))
	print("CINEMATIC_DIALOGUE checks=", checks.size(), " failures=", failures)
	quit(1 if failures else 0)
