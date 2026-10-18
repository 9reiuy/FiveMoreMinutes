extends SceneTree

const HELPER_SCRIPT: Script = preload("res://scripts/dream/dream_3d_dialogue_camera.gd")
const CELL_PIXELS := 32.0

var failures: Array[String] = []
var checks := 0
var helper: Node
var player: Node2D
var guide: Node2D
var second_speaker: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("DIALOGUE CAMERA TEST: %s" % message)


func _map_gameplay_to_world(position: Vector2) -> Vector3:
	return Vector3(position.x / CELL_PIXELS, 0.0, position.y / CELL_PIXELS)


func _run() -> void:
	player = Node2D.new()
	player.name = "DreamPlayer"
	player.position = Vector2(0.0, 0.0)
	root.add_child(player)
	guide = Node2D.new()
	guide.name = "Guide"
	guide.position = Vector2(320.0, 0.0)
	root.add_child(guide)
	second_speaker = Node2D.new()
	second_speaker.name = "SecondSpeaker"
	second_speaker.position = Vector2(640.0, 0.0)
	root.add_child(second_speaker)

	helper = HELPER_SCRIPT.new()
	helper.name = "DialogueCameraTestHelper"
	root.add_child(helper)
	helper.call("configure", player, Callable(self, "_map_gameplay_to_world"))

	# CONVERSATION uses the Player/partner midpoint.
	helper.call("begin_dialogue_focus", guide, 0)
	helper.call("advance", 0.0, _map_gameplay_to_world(player.global_position))
	var midpoint := _map_gameplay_to_world(Vector2(160.0, 0.0))
	var conversation_focus: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(conversation_focus.distance_to(midpoint) < 0.01, "conversation focus must use Player/partner midpoint")
	await _frames(60)
	_check(float(helper.call("get_dialogue_weight")) > 0.95, "dialogue entry weight must reach 1")
	# Repeating begin() for the active session must not restart the entry blend.
	var weight_before_repeat_begin := float(helper.call("get_dialogue_weight"))
	helper.call("begin_dialogue_focus", guide, 0)
	_check(absf(float(helper.call("get_dialogue_weight")) - weight_before_repeat_begin) < 0.02, "repeated begin must not restart dialogue weight")

	# A Player line is a valid world speaker in SPEAKER_FOCUS.
	helper.call("begin_dialogue_focus", guide, 1)
	helper.call("set_dialogue_speaker", player)
	helper.call("advance", 0.0, _map_gameplay_to_world(player.global_position))
	await _frames(45)
	var player_focus: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(player_focus.distance_to(Vector3.ZERO) < 0.25, "SPEAKER_FOCUS must resolve player lines to DreamPlayer")

	# A→B is one smooth focus transition while weight stays active.
	helper.call("set_dialogue_speaker", second_speaker)
	var weight_before_switch := float(helper.call("get_dialogue_weight"))
	helper.call("advance", 0.10, _map_gameplay_to_world(player.global_position))
	var focus_during_switch: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(focus_during_switch.x > 0.0 and focus_during_switch.x < 20.0, "speaker switch must not snap to the new target")
	_check(absf(float(helper.call("get_dialogue_weight")) - weight_before_switch) < 0.02, "speaker switch must not restart dialogue weight")
	await _frames(25)
	var settled_focus: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(settled_focus.distance_to(Vector3(20.0, 0.0, 0.0)) < 0.25, "speaker switch must settle on the new speaker")

	# Moving the same Speaker follows continuously without restarting identity
	# transition every frame.
	var transition_active_before_move := bool(helper.get("_focus_transition_active"))
	second_speaker.position = Vector2(704.0, 0.0)
	for _frame in 12:
		helper.call("advance", 1.0 / 60.0, _map_gameplay_to_world(player.global_position))
	_check(not bool(helper.get("_focus_transition_active")) or not transition_active_before_move, "same-speaker movement must not restart the switch transition each frame")
	var moving_focus: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(moving_focus.x > 20.0, "same speaker movement must update the live focus")

	# Unknown/system speakers do not replace the current focus.
	var focus_before_unknown: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	helper.call("set_dialogue_speaker", null)
	helper.call("advance", 0.1, _map_gameplay_to_world(player.global_position))
	var focus_after_unknown: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(focus_after_unknown.distance_to(focus_before_unknown) < 0.5, "null/system speaker must retain current focus")

	# End freezes the exit composition even if the Speaker moves or is freed.
	var exit_focus: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	helper.call("end_dialogue_focus")
	var exit_weight_start := float(helper.call("get_dialogue_weight"))
	second_speaker.position = Vector2(0.0, 640.0)
	second_speaker.queue_free()
	await _frames(8)
	var frozen_focus: Vector3 = helper.call("get_focus_world", Vector3.ZERO)
	_check(frozen_focus.distance_to(exit_focus) < 0.05, "exiting dialogue must use frozen focus")
	_check(float(helper.call("get_dialogue_weight")) < exit_weight_start, "dialogue exit must reduce weight")

	# No-world-speaker begin is a no-op and never falls back to the origin.
	helper.call("clear_dialogue_focus")
	var fallback := Vector3(7.0, 0.0, 9.0)
	helper.call("begin_dialogue_focus", null, 1)
	_check(float(helper.call("get_dialogue_weight")) == 0.0, "null speaker must not activate a camera focus")
	var null_focus: Vector3 = helper.call("get_focus_world", fallback)
	_check(null_focus.distance_to(fallback) < 0.01, "null speaker must use the caller fallback, not world origin")

	# Ending before the first advance must cancel the entry tween rather than
	# allowing a stale callback to raise the weight again.
	var early_helper: Node = HELPER_SCRIPT.new()
	var early_player := Node2D.new()
	var early_speaker := Node2D.new()
	root.add_child(early_player)
	root.add_child(early_speaker)
	root.add_child(early_helper)
	early_helper.call("configure", early_player, Callable(self, "_map_gameplay_to_world"))
	early_helper.call("begin_dialogue_focus", early_speaker, 1)
	early_helper.call("end_dialogue_focus")
	await _frames_for_helper(early_helper, early_player, 40)
	_check(float(early_helper.call("get_dialogue_weight")) == 0.0, "early end must cancel the entry tween")
	early_helper.queue_free()
	early_player.queue_free()
	early_speaker.queue_free()

	print("DIALOGUE_CAMERA_CHECKS ", checks, " failures ", failures.size())
	helper.queue_free()
	player.queue_free()
	guide.queue_free()
	if is_instance_valid(second_speaker):
		second_speaker.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _frame in count:
		if helper != null and is_instance_valid(helper) and player != null and is_instance_valid(player):
			helper.call("advance", 1.0 / 60.0, _map_gameplay_to_world(player.global_position))
		await process_frame


func _frames_for_helper(other_helper: Node, other_player: Node2D, count: int) -> void:
	for _frame in count:
		if other_helper != null and is_instance_valid(other_helper) and other_player != null and is_instance_valid(other_player):
			other_helper.call("advance", 1.0 / 60.0, _map_gameplay_to_world(other_player.global_position))
		await process_frame
