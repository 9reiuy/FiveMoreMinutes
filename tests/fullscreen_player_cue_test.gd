extends SceneTree
## Run with private muted APPDATA. The graphical probe is kept separate.
var checks: Dictionary = {}
var result: Dictionary = {}
var events: Array = []
var visible_times: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func(): quit(9))
	if not quiet():
		quit(8)
		return
	root.get_node("SettingsManager").settings_loaded.connect(func():
		if not quiet(): quit(8))
	# Load after autoload initialization: the real presentation wrapper reads
	# SettingsManager while compiling its scene dependencies.
	var sample: Control = load("res://scenes/testing/FullscreenCueSample.tscn").instantiate()
	sample.whitebox = true
	sample.autoplay = false
	root.add_child(sample)
	while not sample.ready_sample:
		await process_frame
	var cue: CanvasLayer = sample.cue
	var player: Node = sample.lab.world.player
	var time_controller: Node = root.get_node("DreamTimeController")
	root.get_node("SettingsManager")._load_settings()
	root.get_node("SettingsManager")._apply_all_audio()
	root.get_node("SettingsManager").settings_loaded.emit()
	checks["settings_reload_remains_muted"] = quiet()
	cue.cue_finished.connect(func(text: String, completed: bool): events.append([text, completed]))
	cue.cue_presented.connect(func(text: String): visible_times[text] = Time.get_ticks_usec())
	checks["whitebox_uses_real_world"] = sample.lab.world.lab_whitebox and sample.lab.world.rooms.size() == 4
	checks["idle_has_no_overlay_or_processing"] = not cue.active and not cue.cover.visible and not cue.is_processing()
	checks["chinese_glyphs_available"] = cue.title_font.has_char("背".unicode_at(0)) and cue.title_font.has_char("后".unicode_at(0))
	checks["empty_rejected"] = not cue.play_cue("  \n  ") and not cue.active
	var movement_before: bool = player.movement_enabled
	var paused_before := paused
	var scale_before := Engine.time_scale
	var started := Time.get_ticks_usec()
	checks["can_trigger"] = cue.play_cue("背后")
	checks["cut_is_immediate"] = cue.active and cue.cover.visible and cue.cover.modulate.a == 1.0
	checks["no_input_interception"] = cue.cover.mouse_filter == Control.MOUSE_FILTER_IGNORE and not cue.is_processing_input()
	checks["input_and_pause_not_changed"] = player.movement_enabled == movement_before and paused == paused_before
	checks["immediate_absolute_005x"] = is_equal_approx(Engine.time_scale, 0.05) and is_equal_approx(time_controller.get_resolved_time_scale(), 0.05)
	checks["title_is_large_and_centered"] = cue.ink._font_size >= 150 and cue.title.pivot_offset.is_equal_approx(cue.cover.size * 0.5)
	var before_move: Vector2 = player.global_position
	Input.action_press("move_right")
	for index in 8:
		await physics_frame
	Input.action_release("move_right")
	var moved: float = Vector2(player.global_position).distance_to(before_move)
	result["movement_under_card"] = {"distance":moved, "velocity":str(player.velocity), "physics_steps":8}
	checks["actual_movement_continues_under_card"] = moved > 0.0001
	checks["movement_does_not_wake_cue_speed"] = is_equal_approx(Engine.time_scale, 0.05)
	await cue.cue_finished
	var duration_ms := (Time.get_ticks_usec() - int(visible_times["背后"])) / 1000.0
	result["first_request_to_visible_ms"] = (int(visible_times["背后"])-started)/1000.0
	result["default_duration_ms"] = duration_ms
	checks["short_wallclock_duration"] = duration_ms >= 440.0 and duration_ms < 650.0
	checks["finished_removes_vignette_and_title"] = not cue.active and not cue.cover.visible and not cue.is_processing()
	checks["end_restores_underlying_speed"] = is_equal_approx(Engine.time_scale, scale_before) and not time_controller.is_fullscreen_cue_time_active()
	checks["completion_emitted_once"] = events == [["背后", true]]
	cue.play_cue("保持")
	cue.play_cue("移动")
	checks["replacement_cancels_old_card"] = events.back() == ["保持", false] and cue.current_message == "移动"
	checks["retrigger_does_not_multiply_speed"] = is_equal_approx(Engine.time_scale, 0.05)
	checks["replacement_does_not_stack_layers"] = sample.find_children("FullscreenPlayerCue", "CanvasLayer", true, false).size() == 1
	cue.cancel()
	cue.cancel()
	checks["cancel_idempotent"] = events.count(["移动", false]) == 1 and not cue.cover.visible
	time_controller.begin_tactical_planning(0.1)
	started = Time.get_ticks_usec()
	cue.play_cue("危险", 0.2)
	await cue.cue_finished
	var slow_ms := (Time.get_ticks_usec() - int(visible_times["危险"])) / 1000.0
	checks["card_uses_real_time_and_restores_other_slow_motion"] = slow_ms >= 190.0 and slow_ms < 400.0 and is_equal_approx(Engine.time_scale, 0.1)
	time_controller.end_tactical_planning()
	time_controller.begin_tactical_planning(0.01)
	cue.play_cue("背后")
	checks["slower_existing_mode_is_overridden_to_exact_005"] = is_equal_approx(Engine.time_scale, 0.05)
	time_controller.notify_confirmed_shot()
	time_controller.begin_dive_time(0.2)
	checks["shots_and_dive_cannot_replace_cue_speed"] = is_equal_approx(Engine.time_scale, 0.05)
	var other_owner := Node.new()
	root.add_child(other_owner)
	time_controller.request_fullscreen_cue_time(other_owner)
	time_controller.request_fullscreen_cue_time(other_owner)
	cue.cancel()
	checks["owners_are_idempotent_and_do_not_stack"] = is_equal_approx(Engine.time_scale, 0.05) and time_controller.has_fullscreen_cue_time(other_owner)
	time_controller.release_fullscreen_cue_time(other_owner)
	checks["last_owner_release_restores_current_policy"] = is_equal_approx(Engine.time_scale, 0.01)
	other_owner.free()
	time_controller.end_tactical_planning()
	time_controller.end_dive_time()
	var orphan_owner := Node.new()
	root.add_child(orphan_owner)
	time_controller.request_fullscreen_cue_time(orphan_owner)
	orphan_owner.free()
	await process_frame
	await process_frame
	checks["freed_owner_does_not_leave_slow_motion"] = not time_controller.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale, 1.0)
	var disposable: CanvasLayer = load("res://scenes/ui/fullscreen_player_cue.tscn").instantiate()
	root.add_child(disposable)
	disposable.play_cue("危险")
	disposable.free()
	checks["freeing_visible_card_releases_speed_immediately"] = not time_controller.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale, 1.0)
	time_controller.reset_hit_stop()
	checks["real_reaction_time_api_available"] = time_controller.begin_reaction_time(&"parry")
	cue.play_cue("危险")
	checks["reaction_cannot_unscale_combat_actions_during_card"] = is_equal_approx(player.combat_action_delta(0.001), 0.001) and not time_controller.is_reaction_time_active()
	checks["real_hitstop_api_available"] = time_controller.request_hit_stop(0.001, 0.6, 0.0)
	var overlapping_scales: Array[float] = []
	for index in 12:
		await process_frame
		overlapping_scales.append(Engine.time_scale)
	checks["reaction_and_hitstop_never_multiply_or_override_005"] = overlapping_scales.all(func(value: float) -> bool: return is_equal_approx(value, 0.05))
	result["overlapping_effect_scales"] = overlapping_scales
	cue.cancel()
	checks["release_restores_live_hitstop_policy"] = is_equal_approx(Engine.time_scale, 0.001)
	time_controller.reset_hit_stop()
	time_controller.clear_reaction_time()
	await process_frame
	await process_frame
	cue.play_cue("撤离")
	paused = true
	await process_frame
	await process_frame
	checks["pause_cancels_card"] = not cue.active and not cue.cover.visible
	checks["pause_cleans_time_owner"] = not time_controller.is_fullscreen_cue_time_active()
	checks["paused_trigger_rejected"] = not cue.play_cue("背后")
	paused = false
	cue.play_cue("保持\n移动")
	checks["multiline_fits"] = cue.ink._lines.size() == 2 and cue.ink._font_size < 100
	cue.cancel()
	cue.play_cue("背后")
	await sample.lab.rebuild()
	await process_frame
	await process_frame
	checks["reset_retains_one_idle_overlay"] = not cue.active and not cue.cover.visible and sample.find_children("FullscreenPlayerCue", "CanvasLayer", true, false).size() == 1
	checks["reset_cannot_inherit_cue_speed"] = not time_controller.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale, 1.0)
	var reset_player: Node = sample.lab.world.player
	reset_player.dead = true
	checks["dead_player_rejects_card_instead_of_showing_at_wrong_speed"] = not cue.play_cue("背后") and not cue.cover.visible and not time_controller.is_fullscreen_cue_time_active()
	reset_player.dead = false
	var cue_id := cue.get_instance_id()
	var world_id: int = sample.lab.world.get_instance_id()
	sample.free()
	await process_frame
	checks["exit_disposes_effect_and_world"] = not is_instance_id_valid(cue_id) and not is_instance_id_valid(world_id)
	result.merge({"checks": checks, "events": events, "slow_duration_ms": slow_ms,
		"audio": AudioServer.get_driver_name(), "pid": OS.get_process_id()})
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var target := args[0].trim_prefix("--artifact-dir=")
		var file := FileAccess.open(target.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	print("FULLSCREEN_CUE_CHECKS ", checks)
	quit(1 if false in checks.values() else 0)


func quiet() -> bool:
	var master := AudioServer.get_bus_index(&"Master")
	if AudioServer.is_bus_mute(master):
		return true
	AudioServer.set_bus_mute(master, true)
	push_error("Fullscreen cue automation requires a pre-muted private profile.")
	return false
