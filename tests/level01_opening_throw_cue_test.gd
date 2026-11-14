extends SceneTree
var output := ""
var display: Control
var world: Node
var checks: Dictionary = {}
var starts: Array[Dictionary] = []
var audio_starts: Array = []
var speed_samples: Array[float] = []


func _initialize() -> void:
	call_deferred("run")


func observe(node: Node) -> void:
	if node.has_signal(&"cue_presented"):
		node.cue_presented.connect(on_cue_started)


func on_cue_started(message: String) -> void:
	starts.append({"message":message, "speed":Engine.time_scale,
		"genuine_prefired":is_instance_valid(world.opening_projectile) and bool(world.opening_projectile.get_meta(&"whitebox_prefired",false)),
		"projectile":world.opening_projectile.get_instance_id() if is_instance_valid(world.opening_projectile) else 0,
		"audio_count":audio_starts.size(), "audio_pitch":root.get_node("SFXManager").players[&"fullscreen_cue"].pitch_scale,
		"audio_playing":root.get_node("SFXManager").players[&"fullscreen_cue"].playing})


func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	if output.is_empty(): output = OS.get_cmdline_user_args()[1]
	create_timer(90.0,true,false,true).timeout.connect(func():finish(9))
	if not quiet():
		finish(8)
		return
	root.get_node("SettingsManager").settings_loaded.connect(func():
		if not quiet():finish(8))
	node_added.connect(observe)
	root.get_node("SFXManager").sfx_played.connect(func(event: StringName):
		if event == &"fullscreen_cue": audio_starts.append(Time.get_ticks_usec()))
	display = load("res://scenes/testing/MegastructureWhiteboxDisplay.tscn").instantiate()
	root.add_child(display)
	world = display.world
	var time: Node = root.get_node("DreamTimeController")
	var shot: Node2D = world.opening_projectile
	var native_direction: Vector2 = shot.direction
	shot.direction = -native_direction
	await frames(5)
	checks["correct_level_and_real_shot"] = world.get_meta(&"level_id")=="0-1" and shot.shooter_instance_id==world.opening_enemy.get_instance_id() and shot.get_meta(&"whitebox_prefired",false)
	checks["no_prompt_for_away_flying_bullet"] = starts.is_empty() and world.run_interface.player_cue==null and not world.opening_throw_cue_shown
	checks["rejected_away_flying_bullet_stays_silent"] = audio_starts.is_empty()
	shot.direction = native_direction
	for index in 10:
		await process_frame
		if not starts.is_empty():break
	var cue: CanvasLayer = world.run_interface.player_cue
	checks["automatic_incoming_throw_message"] = starts.size()==1 and starts[0].message=="扔出去" and starts[0].genuine_prefired
	checks["hud_ready_and_white"] = is_instance_valid(cue) and cue.custom_viewport==root and cue.ink_color==Color.WHITE and cue.glow_color==Color.WHITE
	checks["only_success_consumes_trigger"] = world.opening_throw_cue_shown
	var sound: AudioStreamPlayer = root.get_node("SFXManager").players[&"fullscreen_cue"]
	checks["opening_uses_selected_second_segment"] = sound.stream.resource_path == "res://sfx/fullscreen_cue/portal_second.res" and sound.bus == &"UI" and sound.max_polyphony == 1
	checks["one_sound_at_visible_text_start"] = audio_starts.size() == 1 and starts[0].audio_count == 1 and starts[0].audio_playing and is_equal_approx(starts[0].audio_pitch,1.0)
	var before_travel: float = shot.traveled
	for index in 8:
		world._try_opening_throw_cue()
		await physics_frame
		speed_samples.append(Engine.time_scale)
	checks["single_trigger_despite_repeated_updates"] = starts.size()==1
	checks["real_projectile_keeps_moving"] = is_instance_valid(shot) and shot.traveled>before_travel
	checks["opening_and_cue_do_not_multiply"] = speed_samples.all(func(value: float)->bool:return is_equal_approx(value,.05)) and time.tactical_planning_active
	world.opening_enemy.take_damage(world.opening_enemy.maximum_health,world.player.global_position,0.0,&"cue_validation")
	await frames(2)
	checks["first_kill_cancels_card_and_restores_speed_immediately"] = world.opening_complete and not cue.active and is_equal_approx(Engine.time_scale,1.0)
	if cue.active:await cue.cue_finished
	await frames(3)
	checks["first_kill_restores_normal_after_card"] = not cue.cover.visible and not time.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale,1.0)
	await frames(8)
	checks["finished_opening_does_not_replay"] = starts.size()==1
	checks["actual_restart_succeeds"] = world.restart_current_floor_after_death()
	for index in 8:
		await process_frame
		if starts.size()>=2:break
	checks["restart_rearms_once_with_new_bullet"] = starts.size()==2 and starts[1].message=="扔出去" and starts[1].projectile!=starts[0].projectile and world.opening_throw_cue_shown
	if cue.active:await cue.cue_finished
	await frames(3)
	checks["natural_card_end_preserves_original_opening_005"] = not time.is_fullscreen_cue_time_active() and time.tactical_planning_active and is_equal_approx(Engine.time_scale,.05)
	await frames(10)
	checks["no_duplicate_after_natural_completion"] = starts.size()==2
	world.restart_current_floor_after_death()
	for index in 8:
		await process_frame
		if starts.size()>=3:break
	checks["third_entry_has_one_request"] = starts.size()==3 and is_equal_approx(Engine.time_scale,.05)
	checks["restarts_replay_exactly_once_at_original_pitch"] = audio_starts.size() == 3 and starts.all(func(event: Dictionary)->bool:return event.audio_playing and is_equal_approx(event.audio_pitch,1.0)) and starts[2].audio_count == 3
	var cue_id := cue.get_instance_id()
	display.free()
	await frames(3)
	checks["exit_cleans_prompt_and_time"] = not is_instance_id_valid(cue_id) and not time.is_fullscreen_cue_time_active() and is_equal_approx(Engine.time_scale,1.0)
	var lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	while not lab.ready_world:await process_frame
	lab.panel.hide()
	await frames(3)
	checks["other_levels_remain_without_automatic_cues"] = lab.world.run_interface.player_cue==null and starts.size()==3
	lab.free()
	await frames(2)
	finish(1 if false in checks.values() else 0)


func frames(count: int) -> void:
	for index in count:await process_frame


func quiet() -> bool:
	var master := AudioServer.get_bus_index(&"Master")
	if AudioServer.is_bus_mute(master):return true
	AudioServer.set_bus_mute(master,true)
	push_error("0-1 cue validation requires private mute before scene entry")
	return false


func finish(code: int) -> void:
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"starts":starts,"audio_starts":audio_starts,"speeds":speed_samples,"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name()},"\t"))
	print("LEVEL01_THROW_CUE ",checks)
	quit(code)
