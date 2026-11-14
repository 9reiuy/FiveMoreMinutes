extends SceneTree
## Test the formal HUD entry point through the existing isolated whitebox.
var checks: Dictionary = {}
var output := ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	if output.is_empty(): output = OS.get_cmdline_user_args()[1]
	create_timer(95.0, true, false, true).timeout.connect(func(): finish(9))
	if not quiet():
		finish(8)
		return
	root.get_node("SettingsManager").settings_loaded.connect(func():
		if not quiet(): finish(8))
	var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	while not lab.ready_world:
		await process_frame
	lab.checks.uncapped.button_pressed = false
	lab.panel.hide()
	lab.hud.hide()
	await frames(4)
	var runtime: Node = lab.world.run_interface
	var time: Node = root.get_node("DreamTimeController")
	checks["uses_real_whitebox_and_formal_adapter"] = lab.world.lab_whitebox and runtime.get_script().resource_path == "res://scripts/dream/dream_3d_run_interface.gd"
	checks["default_is_dormant"] = runtime.player_cue == null and not time.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale, 1.0)
	checks["empty_request_has_no_side_effect"] = not runtime.play_player_cue("  ") and runtime.player_cue == null
	checks["explicit_formal_call_works"] = runtime.play_player_cue("背后")
	var cue: CanvasLayer = runtime.player_cue
	checks["native_root_hud_target"] = is_instance_valid(cue) and cue.custom_viewport == root and cue.get_parent() == lab.world.ui_layer.get_parent()
	checks["approved_white_colours"] = cue.ink_color == Color.WHITE and cue.glow_color == Color.WHITE
	checks["immediate_fixed_005"] = is_equal_approx(Engine.time_scale, 0.05)
	await cue.cue_finished
	checks["normal_completion_restores"] = not cue.cover.visible and not time.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale, 1.0)
	checks["repeated_call_reuses_single_layer"] = runtime.play_player_cue("保持") and cue == runtime.player_cue
	runtime.play_player_cue("移动")
	checks["repeated_calls_do_not_multiply"] = is_equal_approx(Engine.time_scale, 0.05)
	runtime.cancel_player_cue()
	checks["public_cancel_releases_speed"] = not cue.active and is_equal_approx(Engine.time_scale, 1.0)
	paused = true
	checks["pause_rejects_formal_call"] = not runtime.play_player_cue("背后")
	paused = false
	runtime.play_player_cue("危险")
	paused = true
	await frames(2)
	checks["pause_cancels_live_layer"] = not cue.active and not cue.cover.visible and not time.is_fullscreen_cue_time_active()
	paused = false
	await frames(2)
	checks["resume_does_not_replay"] = not cue.active and is_equal_approx(Engine.time_scale, 1.0)
	runtime.play_player_cue("撤离")
	lab.world.floor_transition_in_progress = true
	await frames(2)
	checks["loading_cancels_and_rejects"] = not cue.active and not runtime.play_player_cue("背后") and not time.is_fullscreen_cue_time_active()
	lab.world.floor_transition_in_progress = false
	runtime.play_player_cue("背后")
	var old_cue_id := cue.get_instance_id()
	var old_world_id: int = lab.world.get_instance_id()
	await lab.rebuild()
	lab.panel.hide()
	lab.hud.hide()
	await frames(4)
	checks["rebuild_disposes_promoted_overlay"] = not is_instance_id_valid(old_cue_id) and not is_instance_id_valid(old_world_id)
	runtime = lab.world.run_interface
	checks["new_floor_still_dormant"] = runtime.player_cue == null and is_equal_approx(Engine.time_scale, 1.0) and not time.is_fullscreen_cue_time_active()
	lab.world.player.dead = true
	checks["dead_player_rejects_without_allocating"] = not runtime.play_player_cue("背后") and runtime.player_cue == null
	lab.world.player.dead = false
	runtime.play_player_cue("背后")
	var final_cue_id: int = runtime.player_cue.get_instance_id()
	lab.free()
	await frames(3)
	checks["exit_releases_root_hud_and_time"] = not is_instance_id_valid(final_cue_id) and not time.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale, 1.0)
	finish(1 if false in checks.values() else 0)


func frames(count: int) -> void:
	for index in count:
		await process_frame


func quiet() -> bool:
	var master := AudioServer.get_bus_index(&"Master")
	if AudioServer.is_bus_mute(master):
		return true
	AudioServer.set_bus_mute(master, true)
	push_error("Formal cue tests require a pre-muted private profile.")
	return false


func finish(code: int) -> void:
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks, "audio":AudioServer.get_driver_name(), "pid":OS.get_process_id()}, "\t"))
	print("FORMAL_CUE_API ", checks)
	quit(code)
