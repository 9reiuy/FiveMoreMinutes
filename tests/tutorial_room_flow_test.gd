extends Node

const MAIN_SCRIPT: Script = preload("res://scripts/app/main.gd")
const TUTORIAL_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TUTORIAL TEST: %s" % message)


func _run() -> void:
	# The test drives dialogue instantly, so disable its MP3 player before any
	# synthetic confirm presses; otherwise the audio decoder can still be alive
	# when this short-lived headless process exits.
	var sfx_manager := get_node_or_null("/root/SFXManager")
	if sfx_manager != null:
		var registered_players: Dictionary = sfx_manager.get("players")
		var confirm_player := registered_players.get(&"confirm") as AudioStreamPlayer
		if confirm_player != null:
			confirm_player.stream = null

	_check(not MAIN_SCRIPT.should_enter_tutorial({"calendar_day_id": 0, "tutorial_completed": false}), "fresh Day 1 must skip temporarily disabled tutorial")
	_check(not MAIN_SCRIPT.should_enter_tutorial({"calendar_day_id": 0, "tutorial_completed": true}), "completed Day 1 must skip tutorial")
	_check(not MAIN_SCRIPT.should_enter_tutorial({"calendar_day_id": 1, "tutorial_completed": false}), "Day 2+ must skip tutorial before instantiation")

	var main_node: Node = MAIN_SCRIPT.new()
	var initial: Dictionary = main_node.call("_create_initial_state")
	_check(not bool(initial.get("tutorial_completed", true)), "new saves must default tutorial_completed=false")
	var legacy := initial.duplicate(true)
	legacy.erase("tutorial_completed")
	legacy.calendar_day_id = 3
	legacy.weekday_index = 3
	var migrated: Dictionary = main_node.call("_merge_with_defaults", legacy)
	_check(bool(migrated.get("tutorial_completed", false)), "legacy saves after Day 1 must migrate as completed")
	main_node.free()

	var intro := TextContent.get_dialogue(&"tutorial_guide_intro")
	var exit_dialogue := TextContent.get_dialogue(&"tutorial_exit_sequence")
	_check(intro.get("lines", []).size() >= 1, "optional guide dialogue must exist")
	_check(exit_dialogue.get("lines", []).size() == 2, "exit sequence must contain the two required lines")
	_check(str(exit_dialogue.lines[0].text) == "真没有什么问题吗？", "first exit line mismatch")
	_check(str(exit_dialogue.lines[1].text) == "那祝你有个好梦", "second exit line mismatch")

	var tutorial: Node = TUTORIAL_SCENE.instantiate()
	tutorial.call("configure_tutorial", "basic", initial)
	get_tree().root.add_child(tutorial)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	_check(tutorial.floor_cells.size() == 22 * 48, "fixed room floor must contain 1056 authored cells")
	_check(tutorial.floor_root.get_child_count() <= 36, "fixed floor should use the existing batched renderer")
	_check(tutorial.wall_root.get_child_count() == 138, "fixed room wall perimeter is incomplete")
	_check(tutorial.door_root.get_child_count() == 1, "tutorial must have exactly one exit DoorLeaf")
	_check(tutorial.player.global_position.distance_to(Vector2(336.0, -16.0)) >= 1296.0, "Spawn -> Door travel distance must be at least 1296px")
	_check(tutorial.guide_spawn_trigger.position.y > tutorial.guide.global_position.y, "Guide trigger must be before the Guide along the travel axis")
	_check(tutorial.guide.global_position.y > tutorial.exit_trigger.position.y, "Guide must be before the exit trigger along the travel axis")
	_check(tutorial.tutorial_ceiling_lights != null and tutorial.tutorial_ceiling_lights.get_child_count() == 2, "tutorial must have exactly two authored ceiling lights")
	if tutorial.tutorial_ceiling_lights != null:
		var light_positions: Array[float] = []
		for holder in tutorial.tutorial_ceiling_lights.get_children():
			light_positions.append(float(holder.position.z))
			_check(holder.get_node_or_null("RoomLight") is SpotLight3D, "tutorial ceiling light must use the formal SpotLight3D")
			_check(is_equal_approx(float(holder.position.x), 10.5), "tutorial ceiling light must be room-centered")
		light_positions.sort()
		_check(light_positions.size() == 2 and light_positions[0] > 10.0 and light_positions[1] < 34.0, "tutorial ceiling lights must be separated along the room axis")
	_check(tutorial.dialogue_dialog.prompt_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "dialogue Prompt must use smart word wrapping")
	_check(tutorial.dialogue_dialog.prompt_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "dialogue Prompt must stay inside the finite content width")
	_check(tutorial.get_node_or_null("GeneratedBuildingRoot") == null, "tutorial must not instantiate the random BSP root")
	_check(tutorial.get_tree().get_nodes_in_group(&"dream_enemies").is_empty(), "tutorial must not spawn enemies")
	_check(not tutorial.guide.is_in_group(&"dream_player"), "guide must not be a second DreamPlayer actor")
	_check(tutorial.guide.get_node_or_null("AutoWeapon") == null, "guide visual must not carry Player gameplay weapons")

	tutorial.guide.visible = true
	tutorial.guide_spawned = true
	tutorial.player.global_position = tutorial.guide.global_position + Vector2(20, 0)
	var selected: Node2D = tutorial.interaction_resolver.update_target()
	_check(selected == tutorial.guide, "shared E resolver must select nearby Guide")
	_check(tutorial.guide.interaction_targeted, "selected Guide must receive outline state")
	tutorial.player.global_position = tutorial.guide.global_position + Vector2(200, 0)
	tutorial.interaction_resolver.update_target()
	_check(tutorial.interaction_resolver.current_target == null, "Guide outline must clear outside interaction range")

	var exit_state := {"finished": false}
	tutorial.connect("tutorial_finished", func() -> void: exit_state.finished = true)
	tutorial.call("_begin_exit_sequence")
	await _wait_for_dialogue_ready(tutorial.dialogue_dialog)
	tutorial.dialogue_dialog.call("_on_cancelled")
	tutorial.dialogue_dialog.call("_on_cancelled")
	await get_tree().process_frame
	tutorial.dialogue_dialog.call("_on_cancelled")
	tutorial.dialogue_dialog.call("_on_cancelled")
	for _frame in 180:
		if bool(exit_state.finished):
			break
		await get_tree().process_frame
	_check(bool(exit_state.finished), "exit dialogue/smoke sequence did not finish")
	_check(not tutorial.guide.visible, "Guide must disappear inside the final smoke burst")
	_check(tutorial.exit_sequence_started, "exit sequence must be one-shot guarded")

	tutorial.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	if sfx_manager != null:
		sfx_manager.call("stop", &"confirm")
		sfx_manager.call("stop", &"text_blip")
	await get_tree().process_frame
	if failures.is_empty():
		print("TUTORIAL_ROOM_FLOW_TEST: PASS")
		get_tree().quit(0)
	else:
		print("TUTORIAL_ROOM_FLOW_TEST: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _wait_for_dialogue_ready(dialogue: Control) -> void:
	for _frame in 90:
		if dialogue.visible and not bool(dialogue.get("animating")):
			return
		await get_tree().process_frame
	_check(false, "dialogue did not become ready")
