extends Node

const MAIN_SCENE := preload("res://scenes/app/main.tscn")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run_test")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] ", label)
	else:
		failures.append(label)
		printerr("  [FAIL] ", label)

func _run_test() -> void:
	print("\n--- RUNNING MAIN TRANSITION INTEGRATION TEST ---")
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(main.transition_director != null, "TransitionDirector is wired to main.gd")
	_check(main.transition_director is TransitionDirector, "transition_director has correct type")
	_check(main.transition_director.current_state == TransitionDirector.State.IDLE, "Initial state is IDLE")

	print("\nTesting scene transition via TransitionDirector:")
	var dummy_screen := Control.new()
	dummy_screen.name = "DummyScreen"
	var t_start := Time.get_ticks_msec()
	await main._transition_to(dummy_screen, 0.15)
	var elapsed := Time.get_ticks_msec() - t_start

	_check(main.current_screen == dummy_screen, "Dummy screen swapped in as current_screen")
	_check(main.transition_director.current_state == TransitionDirector.State.IDLE, "Director returned to IDLE after transition")
	_check(not main.transition_running, "main.transition_running reset to false")
	_check(elapsed >= 200, "Transition took at least cover + reveal duration (took %d ms)" % elapsed)

	print("\n--- TEST FINISHED ---")
	if failures.is_empty():
		print("ALL 7 INTEGRATION CHECKS PASSED!\n")
		get_tree().quit(0)
	else:
		printerr("FAILED CHECKS: ", failures)
		get_tree().quit(1)
