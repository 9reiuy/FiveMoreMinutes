extends SceneTree

const MAIN_PATH := "res://scenes/app/main.tscn"
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var main = load(MAIN_PATH).instantiate()
	root.add_child(main)
	await process_frame
	main.persistent_day_state = main._create_initial_state()
	# Avoid writing a synthetic hunger-day update to the user's save.
	main.persistent_day_state.hunger_checked_day_id = main.persistent_day_state.calendar_day_id
	check(not main.should_enter_tutorial(main.persistent_day_state), "fresh save skips tutorial")
	check(not main.should_enter_tutorial({"calendar_day_id": 0, "tutorial_completed": true}), "completed save skips tutorial")
	check(not main.should_enter_tutorial({"calendar_day_id": 3, "tutorial_completed": false}), "later day skips tutorial")
	main._start_story_dream()
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not main.transition_running and is_instance_valid(main.current_screen):
			var candidate: Node = main.current_screen
			var candidate_world: Node = candidate.get("world") if candidate.has_method("set_selective_enabled") else candidate
			if is_instance_valid(candidate_world) and candidate_world.scene_file_path == "res://scenes/dream/Dream3D_ReceptionRoom.tscn":
				break
	var screen: Node = main.current_screen
	var world: Node = screen.get("world") if screen.has_method("set_selective_enabled") else screen
	check(is_instance_valid(world) and world.scene_file_path == "res://scenes/dream/Dream3D_ReceptionRoom.tscn", "real story entry retains reception")
	check(not bool(main.persistent_day_state.tutorial_completed), "skip does not mark tutorial completed")
	check(ResourceLoader.exists("res://scenes/dream/Dream3D_TutorialRoom.tscn"), "tutorial resource retained")
	var config = load("res://resources/demo_config.tres")
	check(config.game_version_text == "V0.5.0", "menu configuration is 0.5.0")
	check(config.save_compatibility_version == "V0.4.7", "release bump keeps existing save compatibility")
	check(main.persistent_day_state.save_version == config.save_compatibility_version, "save uses compatibility marker, not display release")
	check(FileAccess.get_file_as_string("res://data/announcement.txt").begins_with("当前版本-V0.5.0"), "announcement starts with 0.5.0")
	main.queue_free()
	await process_frame
	await process_frame
	print("RELEASE 0.5.0 checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
