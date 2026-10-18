extends SceneTree

const TUTORIAL_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TUTORIAL DIRECT FLOW TEST: %s" % message)


func _run() -> void:
	await _run_guide_dialogue_path()
	await _run_skip_dialogue_path()
	if failures.is_empty():
		print("TUTORIAL_ROOM_DIRECT_FLOW_TEST: PASS")
		quit(0)
	else:
		print("TUTORIAL_ROOM_DIRECT_FLOW_TEST: FAIL (%d)" % failures.size())
		quit(1)


func _new_tutorial() -> Node:
	var tutorial := TUTORIAL_SCENE.instantiate()
	root.add_child(tutorial)
	await process_frame
	await physics_frame
	await process_frame
	return tutorial


func _run_guide_dialogue_path() -> void:
	var tutorial: Node = await _new_tutorial()
	tutorial.call("_on_guide_spawn_trigger_entered", tutorial.player)
	await _wait_for_guide(tutorial)
	_check(tutorial.guide_spawned and tutorial.guide.visible, "Guide appears after the Guide trigger")
	tutorial.player.global_position = tutorial.guide.global_position + Vector2(20.0, 0.0)
	var selected: Node2D = tutorial.interaction_resolver.update_target()
	_check(selected == tutorial.guide, "Guide remains interactable at the new layout position")
	tutorial.call("_run_optional_guide_dialogue")
	await process_frame
	_check(int(tutorial.dialogue_camera.get("focus_mode")) == 0, "Guide interaction must use CONVERSATION focus")
	_check(bool(tutorial.dialogue_camera.call("is_dialogue_active")), "Guide interaction must activate the dialogue camera")
	await _drive_dialogue_to_close(tutorial, 300)
	_check(not tutorial.dialogue_bubble.visible, "Guide dialogue closes with Continue")
	var finished := {"value": false}
	tutorial.tutorial_finished.connect(func() -> void: finished.value = true)
	tutorial.call("_begin_exit_sequence")
	await _drive_dialogue_to_close(tutorial, 240)
	await _wait_for_flag(finished, 120)
	_check(bool(finished.value), "exit sequence finishes after the Guide dialogue path")
	_check(not tutorial.guide.visible, "Guide disappears in the exit smoke on the dialogue path")
	tutorial.free()


func _run_skip_dialogue_path() -> void:
	var tutorial: Node = await _new_tutorial()
	var finished := {"value": false}
	tutorial.tutorial_finished.connect(func() -> void: finished.value = true)
	tutorial.call("_begin_exit_sequence")
	await _wait_for_dialogue(tutorial, 120)
	var guide_focus := Vector3(tutorial.guide.global_position.x / 32.0, 0.0, tutorial.guide.global_position.y / 32.0)
	_check(int(tutorial.dialogue_camera.get("focus_mode")) == 1, "automatic Exit dialogue must use SPEAKER_FOCUS")
	await process_frame
	var exit_focus: Vector3 = tutorial.dialogue_camera.call("get_focus_world", Vector3.ZERO)
	_check(exit_focus.distance_to(guide_focus) < 0.5, "automatic Exit dialogue must focus the Guide even without Player E interaction")
	await _drive_dialogue_to_close(tutorial, 240)
	await _wait_for_flag(finished, 120)
	_check(bool(finished.value), "exit sequence finishes when Guide dialogue is skipped")
	_check(not tutorial.guide.visible, "Guide disappears in the exit smoke on the skip path")
	tutorial.free()


func _wait_for_guide(tutorial: Node) -> void:
	for _frame in 120:
		if tutorial.guide.visible:
			return
		await process_frame
	_check(false, "Guide did not appear after the trigger")


func _drive_dialogue_to_close(tutorial: Node, max_frames: int) -> void:
	for _frame in max_frames:
		var bubble_vis: bool = tutorial.get("dialogue_bubble") != null and tutorial.dialogue_bubble.visible
		var dialog_vis: bool = tutorial.get("dialogue_dialog") != null and tutorial.dialogue_dialog.visible
		if not bubble_vis and not dialog_vis:
			return
		if tutorial.get("dialogue_controller") != null and tutorial.dialogue_controller.is_active():
			tutorial.dialogue_controller.dismiss_if_active()
		elif tutorial.get("dialogue_dialog") != null and tutorial.dialogue_dialog.visible:
			if not bool(tutorial.dialogue_dialog.get("animating")):
				tutorial.dialogue_dialog.call("_on_cancelled")
		await process_frame
	_check(false, "dialogue did not close through its Continue path")


func _wait_for_dialogue(tutorial: Node, max_frames: int) -> void:
	for _frame in max_frames:
		var bubble_vis: bool = tutorial.get("dialogue_bubble") != null and tutorial.dialogue_bubble.visible
		var dialog_vis: bool = tutorial.get("dialogue_dialog") != null and tutorial.dialogue_dialog.visible
		if bubble_vis or dialog_vis:
			return
		await process_frame
	_check(false, "dialogue did not open")


func _wait_for_flag(state: Dictionary, max_frames: int) -> void:
	for _frame in max_frames:
		if bool(state.get("value", false)):
			return
		await process_frame
	_check(false, "tutorial completion signal did not arrive")
