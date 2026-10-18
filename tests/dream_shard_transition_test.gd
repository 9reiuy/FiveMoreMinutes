extends Node

## Automated test for TASK-020-B Dream Shard Transition System

const TransitionDirector = preload("res://scripts/ui/transition_director.gd")

var tests_passed := 0
var tests_failed := 0


func _ready() -> void:
	print("--- BEGIN DREAM SHARD TRANSITION TEST ---")
	await _run_all_tests()
	print("--- TEST SUMMARY: %d PASSED, %d FAILED ---" % [tests_passed, tests_failed])
	if tests_failed == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % message)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s" % message)


func _run_all_tests() -> void:
	test_shader_and_masks_loading()
	await test_transition_director_lifecycle()
	await test_transition_reentrancy_protection()


func test_shader_and_masks_loading() -> void:
	print("\nTest 1: Shader & Mask Asset Verification")
	var shader = load("res://shaders/transitions/dream_shard_transition.gdshader")
	assert_true(shader != null, "Shader dream_shard_transition.gdshader loaded successfully")

	var mask_keys = ["edge_fracture", "shattered_memory", "diagonal_tear"]
	for key in mask_keys:
		var path = "res://assets/transitions/masks/mask_%s.png" % key
		var tex: Texture2D = load(path)
		assert_true(tex != null, "Mask texture loaded: %s" % key)
		if tex != null:
			assert_true(tex.get_width() == 640 and tex.get_height() == 360, "Mask %s dimension is 640x360" % key)


func test_transition_director_lifecycle() -> void:
	print("\nTest 2: TransitionDirector State Machine Lifecycle")
	var director = TransitionDirector.new()
	add_child(director)
	await get_tree().process_frame

	assert_true(director.current_state == TransitionDirector.State.IDLE, "Initial state is IDLE")
	assert_true(not director.is_transition_running(), "is_transition_running() is false when IDLE")

	var results := {
		"callback_executed": false,
		"covered_signal_received": false,
		"finished_signal_received": false
	}

	director.transition_covered.connect(func():
		results["covered_signal_received"] = true
		assert_true(director.current_state == TransitionDirector.State.WAITING_FOR_SCENE, "State is WAITING_FOR_SCENE when covered")
	)

	director.transition_finished.connect(func():
		results["finished_signal_received"] = true
	)

	var scene_callback = func():
		results["callback_executed"] = true
		assert_true(results["covered_signal_received"], "Scene callback executed AFTER transition_covered signal")

	# Play transition with short durations for fast test execution
	var ok = await director.play_transition("edge_fracture", scene_callback, 0.08, 0.08)
	assert_true(ok, "play_transition() returned true")
	assert_true(results["callback_executed"], "Scene callback was successfully executed")
	assert_true(results["covered_signal_received"], "transition_covered signal was emitted")
	assert_true(results["finished_signal_received"], "transition_finished signal was emitted")
	assert_true(director.current_state == TransitionDirector.State.IDLE, "Final state returned to IDLE")

	director.queue_free()


func test_transition_reentrancy_protection() -> void:
	print("\nTest 3: Anti-reentrancy & Duplicate Request Protection")
	var director = TransitionDirector.new()
	add_child(director)
	await get_tree().process_frame

	var slow_callback = func():
		return get_tree().create_timer(0.1).timeout

	var bg_runner = func():
		await director.play_transition("shattered_memory", slow_callback, 0.1, 0.1)
	bg_runner.call()
	await get_tree().process_frame

	# Second transition request should immediately be rejected
	var duplicate_ok: bool = await director.play_transition("diagonal_tear", Callable(), 0.1, 0.1)
	assert_true(not duplicate_ok, "Duplicate transition request was properly rejected while busy")

	# Wait for first transition to finish
	await director.transition_finished
	assert_true(director.current_state == TransitionDirector.State.IDLE, "State returned to IDLE after first transition finished")

	director.queue_free()
