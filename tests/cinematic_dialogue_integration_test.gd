extends SceneTree

const PRESENTATION := preload("res://scripts/ui/dialogue/cinematic_dialogue.gd")
var output := "res://.runtime/cinematic_dialogue_20261117/integration"
var checks: Array[Dictionary] = []
var main: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks.append({"pass": ok, "description": description})
	print("PASS " if ok else "FAIL ", description)


func frames(count: int = 4) -> void:
	for _i in count: await process_frame


func tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await frames(2)


func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(event)
	await frames(2)


func click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await frames(2)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames(2)
	event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)
	await frames(2)


func snapshot(name: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Saved actual Main Camera " + name)


func record_portrait_state(view: PRESENTATION, tag: String) -> void:
	var left := view.character_art.texture
	var right := view.right_art.texture
	var stable := true
	var records: Array[Dictionary] = []
	for _i in 24:
		await process_frame
		stable = stable and view.character_art.texture == left and view.right_art.texture == right
		records.append({"frame": Engine.get_process_frames(), "visible_characters": view.prompt_label.visible_characters, "left_texture": view.character_art.texture.get_instance_id(), "right_texture": view.right_art.texture.get_instance_id()})
	FileAccess.open(output.path_join(tag + "_portrait_state.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	check(stable and view.visible, tag + " preserves both selected portraits while real dialogue text advances")


func record_motion(view: PRESENTATION, tag: String, controller: Node = null) -> void:
	var records: Array[Dictionary] = []
	var pictures: Array[Image] = []
	var started := Time.get_ticks_msec()
	var previous := -100
	while view.visible and view.is_dialogue_entering() and Time.get_ticks_msec() - started < 1000:
		await process_frame
		var elapsed := Time.get_ticks_msec() - started
		if elapsed - previous < 35: continue
		await RenderingServer.frame_post_draw
		previous = elapsed
		records.append({"time_ms": Time.get_ticks_msec() - started, "entering": view.is_dialogue_entering(), "progress": view._presentation_progress, "left_x": view.character_art.position.x, "right_x": view.right_art.position.x, "right_visible": view.right_art.is_visible_in_tree(), "text_alpha": view.dialogue_panel.modulate.a, "visible_characters": view.prompt_label.visible_characters, "clock": controller.elapsed if controller != null else 0.0, "typed": controller.typed_chars if controller != null else 0})
		pictures.append(root.get_texture().get_image())
	await frames(3)
	pictures.append(root.get_texture().get_image())
	var text_waited := true
	var clock_waited := true
	for row in records:
		if row.entering:
			text_waited = text_waited and is_zero_approx(float(row.text_alpha)) and int(row.visible_characters) == 0
			clock_waited = clock_waited and is_zero_approx(float(row.clock)) and int(row.typed) == 0
	check(records.size() >= 3 and float(records[0].left_x) < view.LEFT_REST.x - 4.0 and (not view.right_art.visible or float(records[0].right_x) > view.RIGHT_REST.x + 4.0), tag + " moves only the portraits participating in this conversation")
	check(text_waited and clock_waited, tag + " keeps text and its clock stopped throughout entrance")
	check(not view.is_dialogue_entering() and view._presentation_progress == 1.0 and view.dialogue_panel.modulate.a == 1.0, tag + " settles the matte and portraits before revealing dialogue")
	for index in pictures.size(): pictures[index].save_png(output.path_join("%s_%02d.png" % [tag, index]))
	FileAccess.open(output.path_join(tag + ".json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))


func wait_scene(path: String, world: bool = false) -> Node:
	var until := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < until:
		await process_frame
		var node: Node = main._supported_dream_world if world else main.current_screen
		if is_instance_valid(node) and node.scene_file_path == path and not main.transition_running: return node
	check(false, "Timed out opening " + path)
	return null


func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	if not AudioServer.is_bus_mute(0) or AudioServer.get_driver_name() != "Dummy":
		AudioServer.set_bus_mute(0, true)
		check(false, "Private pre-entry muted settings and Dummy audio required"); finish(); return
	if DisplayServer.get_name() == "headless":
		check(false, "Integration needs the actual renderer"); finish(); return
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	Engine.max_fps = 60
	create_timer(180.0, true, false, true).timeout.connect(func(): push_error("Main dialogue integration timed out"); quit(2))
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	main.persistent_day_state = main._create_initial_state()
	main.chapter_one.start_new()
	main.chapter_one.state.stage = "EVENING"
	main.day_start_snapshot.capture(main.persistent_day_state)
	main._show_bedroom(false)
	var bedroom: Node = await wait_scene("res://scenes/bedroom/bedroom.tscn")
	if bedroom == null: finish(); return
	var dialog: PRESENTATION = bedroom.confirmation_dialog
	check(dialog != null and not dialog.externally_driven, "Formal Main bedroom uses the approved narrative UI with its original confirmation controller")
	dialog.close_without_signal()
	await snapshot("bedroom_baseline")
	bedroom._request_confirmation("bedroom_chr")
	await record_motion(dialog, "bedroom_entrance")
	check(dialog.visible and not dialog.animating and dialog.current_line.get("speaker") == "player", "Existing bedroom character interaction opens the new dialogue without changing speaker metadata")
	check(dialog.full_prompt_text == "这是我" or dialog.full_prompt_text.begins_with("你好，"), "Original randomized bedroom text and computer-name replacement survive")
	check(dialog.prompt_label.get_theme_font_size(&"font_size") == 12 and bedroom.bedroom_chr_dialogue_hidden, "Approved font geometry and original bedroom character hiding are applied together")
	check(not dialog.right_art.visible and dialog.character_art.visible and dialog.active_side == &"left", "Bedroom self-talk has exactly one visible speaking portrait")
	await record_portrait_state(dialog, "bedroom")
	dialog._complete_typewriter()
	await snapshot("bedroom_dialogue")
	for _i in range(8):
		if not dialog.visible: break
		dialog._complete_typewriter()
		await escape()
		await create_timer(0.25).timeout
	check(not dialog.visible and not bedroom.bedroom_chr_dialogue_hidden and bedroom.bedroom_chr_interaction_enabled, "ESC closes bedroom dialogue and restores the room's character interaction")
	check(not main.pause_menu.is_open() and not paused, "Bedroom dialogue ESC is consumed before Main opens the pause menu")
	bedroom.persistent_state.food_eaten_today = true
	var original_mouse_mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	dialog.set_process(false)
	bedroom._request_confirmation("bed")
	await create_timer(dialog.entrance_seconds + 0.03).timeout
	dialog._process(0.10)
	check(dialog.side_choice_list.interrupt_button.is_visible_in_tree() and dialog.prompt_label.visible_characters == 2,
		"Formal bedroom exposes the red choice before the bedtime sentence finishes")
	await click(dialog.side_choice_list.interrupt_button)
	check(is_instance_valid(dialog._interrupt_fragments) and dialog._interrupt_fragments.get_child_count() == 2,
		"Formal mouse click detaches the two visible bedtime characters")
	await create_timer(0.25).timeout
	check(not dialog.visible and main.current_screen == bedroom and not bedroom.input_locked
		and DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_HIDDEN,
		"Interrupt closes bedtime without executing Sleep and restores the room and cursor")
	dialog.set_process(true)
	bedroom._request_confirmation("bed")
	await create_timer(dialog.entrance_seconds + 0.03).timeout
	dialog._complete_typewriter()
	check(dialog.use_side_choices and dialog.buttons.position.x >= 640.0 and not dialog.side_choice_list.interactive,
		"Formal bedtime choices start beyond the right edge before accepting input")
	check(DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_VISIBLE,
		"The formal dialogue shows the native pointer even if gameplay hid it")
	await create_timer(dialog.side_choice_list.SLIDE_SECONDS + 0.05).timeout
	check(dialog.current_choices.size() == 2 and dialog.choice_buttons[0].text == "睡觉" and dialog.choice_buttons[1].text == "再等等", "Existing bedtime confirmation keeps its choices and action routing")
	check(dialog.side_choice_list.interactive and dialog.choice_buttons[0].get_global_rect().position.x > 400.0,
		"The real buttons finish their slide on the right side of the bedroom view")
	check(not dialog.right_art.visible, "A single-person bedtime prompt does not add a right-hand character")
	await snapshot("bedroom_choices")
	await click(dialog.choice_buttons[1])
	await create_timer(0.3).timeout
	check(not dialog.visible and main.current_screen == bedroom and not bedroom.input_locked, "Clicking the existing cancel option closes the new UI without entering sleep")
	check(DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_HIDDEN,
		"Canceling restores the previous mouse mode")
	Input.mouse_mode = original_mouse_mode
	bedroom._request_confirmation("bed")
	await create_timer(dialog.entrance_seconds + 0.03).timeout
	dialog._complete_typewriter()
	await create_timer(dialog.side_choice_list.SLIDE_SECONDS + 0.05).timeout
	var old_dialog := dialog.get_instance_id()
	await click(dialog.choice_buttons[0])
	var reception: Node = await wait_scene("res://scenes/dream/Dream3D_ReceptionRoom.tscn", true)
	if reception == null: finish(); return
	check(main.chapter_one.state.stage == "RECEPTION", "Clicking Sleep dispatches the original action and enters reception through the existing chapter flow")
	check(not is_instance_id_valid(old_dialog), "Leaving bedroom during dialogue disposes its portrait and veil")
	var view: PRESENTATION = reception.dialogue_bubble
	check(view != null and view.externally_driven and view.default_speaker_side == "right", "Formal reception uses the same UI with the existing NPC dialogue clock")
	check(reception.npc_hint_bubble.get_script().resource_path.ends_with("reception_npc_hint_bubble.gd"), "NPC proximity emotion/hint bubble keeps its separate original view")
	check(RenderingServer.get_current_rendering_method() == "forward_plus", "Formal entry retains Forward+ and the native world renderer")
	reception.player.set_physics_process(false)
	reception.player.global_position = reception.RECEPTION_DESK_POS_2D + Vector2(0, 45)
	await frames(25)
	check(reception.interaction_resolver.current_target == reception.waitress_npc and not reception.dialogue_controller.is_active(), "Passive NPC still waits for the real E interaction")
	var controller: DreamDialogueController = reception.dialogue_controller
	await tap(&"pickup_weapon")
	await record_motion(view, "reception_entrance", controller)
	check(controller.is_active() and controller._sequence_lines.size() == 5 and view.visible, "E opens the original five-part reception conversation in the new UI")
	check(view.two_person_dialogue and view.right_art.visible and view.character_art.visible, "Reception explicitly includes the player and NPC as two conversation participants")
	check(view.active_side == &"right" and view.character_art.modulate.r < view.right_art.modulate.r and view.character_art.position.y > view.right_art.position.y, "Reception's NPC side speaks while the player side lowers and darkens")
	check((view.right_art.texture as AtlasTexture).atlas.resource_path.get_file() == "receptionist_talking.png"
		and (view.character_art.texture as AtlasTexture).atlas == view.PORTRAIT_IDLE,
		"The real reception view loads the new talking receptionist beside the original player portrait")
	await record_portrait_state(view, "reception")
	controller._process(controller.typewriter_duration)
	await snapshot("reception_dialogue")
	await tap(&"pickup_weapon")
	await create_timer(0.2).timeout
	check(controller._sequence_index == 1 and reception.waitress_npc.hint_emotion == "sad", "E advances the existing sequence and authored emotion beats")
	check(not view.is_dialogue_entering() and view._presentation_progress == 1.0, "Reception retains its settled UI while the next sentence starts")
	check((view.right_art.texture as AtlasTexture).atlas.resource_path.get_file() == "receptionist_normal.png", "The second authored line selects the receptionist's normal expression")
	controller._process(controller.typewriter_duration)
	await snapshot("reception_normal")
	await tap(&"pickup_weapon")
	await create_timer(0.2).timeout
	check(controller._sequence_index == 2 and (view.right_art.texture as AtlasTexture).atlas.resource_path.get_file() == "receptionist_nervous.png", "The third authored line selects the receptionist's nervous expression")
	await record_portrait_state(view, "reception_nervous")
	controller._process(controller.typewriter_duration)
	await snapshot("reception_nervous")
	await escape()
	await create_timer(0.5).timeout
	check(not controller.is_active() and not view.visible and reception.dialogue_camera_weight < 0.01 and reception.player.movement_enabled, "ESC closes reception dialogue and restores its camera and movement")
	check(not main.pause_menu.is_open() and not paused and not reception.tarot_overlay.visible, "Reception dialogue ESC does not open pause or draw cards")
	reception.set_meta(&"chapter_dialogue_heard", false)
	var cards_were_selected: bool = reception.tarot_visit_state.selected
	await tap(&"pickup_weapon")
	await create_timer(view.entrance_seconds + 0.16).timeout
	check(controller.can_interrupt() and view.side_choice_list.interrupt_button.is_visible_in_tree(),
		"Formal reception offers the same interrupt during the NPC's line")
	await click(view.side_choice_list.interrupt_button)
	check(not controller.is_active() and controller._sequence_index == 0 and is_instance_valid(view._interrupt_fragments),
		"Reception mouse interruption ends the five-line conversation on the spot")
	await create_timer(0.5).timeout
	check(not view.visible and reception.player.movement_enabled and reception.dialogue_camera_weight < 0.01
		and not bool(reception.get_meta(&"chapter_dialogue_heard", false))
		and reception.tarot_visit_state.selected == cards_were_selected and not reception.tarot_overlay.visible,
		"Interrupt restores reception interaction without advancing dialogue or card progression")
	# Replay the real five-line sequence before the separate card interaction.
	await tap(&"pickup_weapon")
	await create_timer(view.entrance_seconds + 0.04).timeout
	await click(view.input_blocker)
	await create_timer(0.2).timeout
	check(controller._sequence_index == 1, "A real background mouse click still advances the existing reception controller")
	for _i in range(4):
		await tap(&"pickup_weapon")
		await create_timer(0.2).timeout
	check(not controller.is_active() and bool(reception.get_meta(&"chapter_dialogue_heard", false)) and not reception.tarot_overlay.visible, "Finishing all five lines retains chapter completion without automatically opening cards")
	await tap(&"pickup_weapon")
	await create_timer(0.4).timeout
	check(reception.tarot_overlay.visible and reception.tarot_visit_state.hand_generated and reception.tarot_visit_state.hand.size() == 3, "A separate E interaction still opens the existing three-card selection")
	await snapshot("reception_cards")
	var old_view := view.get_instance_id()
	main._show_bedroom(false)
	bedroom = await wait_scene("res://scenes/bedroom/bedroom.tscn")
	check(bedroom != null and not is_instance_id_valid(old_view), "Returning to bedroom releases the reception dialogue and its detached HUD canvas")
	if bedroom != null:
		bedroom.confirmation_dialog.close_without_signal()
		bedroom._request_confirmation("bedroom_chr")
		await create_timer(0.3).timeout
		check(bedroom.confirmation_dialog.visible, "Bedroom dialogue remains usable after a reception round trip")
		check(not bedroom.confirmation_dialog.right_art.visible, "Returning from a two-person reception conversation restores single-person bedroom dialogue")
	main.queue_free()
	await frames(12)
	check(not paused and not is_instance_valid(main), "Leaving Main releases dialogue state without residual global pause")
	finish()


func finish() -> void:
	var failures := checks.filter(func(row: Dictionary): return not row.pass).size()
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(), "checks": checks, "failures": failures, "scope": "Actual Main bedroom and reception, original interaction/actions/controller, native Camera, muted Dummy audio. This is scoped integration coverage, not whole-game performance certification."}, "\t"))
	print("CINEMATIC_INTEGRATION checks=", checks.size(), " failures=", failures)
	quit(1 if failures else 0)
