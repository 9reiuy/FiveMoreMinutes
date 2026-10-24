extends "res://tests/sample_indoor_dust_camera_test.gd"
func output_directory() -> String: return "res://.runtime/indoor_dust_formal_20261023"
func prepare_world() -> void:
	var main: Node=load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main); cleanup_root=main
	while main.transition_running: await process_frame
	main.persistent_day_state=main._create_initial_state(); main._show_dream("basic")
	while main.transition_running: await process_frame
	world=main._supported_dream_world
	while world.floor_transition_in_progress or world.transition_phase!=&"IDLE": await process_frame
	display=world.get_parent().get_parent().get_parent()
	check(world.floor_root.has_node("IndoorDust"),"Actual Main to formal Dream3D entry installs approved indoor dust")
