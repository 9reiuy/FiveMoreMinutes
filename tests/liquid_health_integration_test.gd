extends SceneTree
var output := "res://.runtime/liquid_health_20261113/entry"
var checks: Array[Dictionary] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	call_deferred("run")

func frames(count: int = 4) -> void:
	for index in count: await process_frame

func check(ok: bool, description: String) -> void:
	checks.append({"pass": ok, "description": description})
	print("PASS " if ok else "FAIL ", description)

func snapshot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master < 0 or not AudioServer.is_bus_mute(master):
		if master >= 0: AudioServer.set_bus_mute(master, true)
		quit(1); return
	preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(210.0, true, false, true).timeout.connect(func(): push_error("Liquid health entry validation timed out"); quit(2))
	var main: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state["tutorial_completed"] = true
	seed(120)
	main._show_dream("basic")
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world) and not main.transition_running and not main._supported_dream_world.floor_transition_in_progress: break
	var world: Node = main._supported_dream_world
	check(is_instance_valid(world) and world.scene_file_path == "res://scenes/dream/Dream3D_RandomDungeon.tscn", "Normal Main dream entry reaches the production world")
	if not is_instance_valid(world): finish(1); return
	world.persist_profile = false
	var meter: Control = world.run_interface.hud.get_node("LiquidHealthMeter")
	check(meter.get_viewport() == root and meter.visible, "Production health meter draws on the clear root HUD")
	var max_health: float = world.player.maximum_health
	check(meter.current_fill == Vector3.ONE and meter.damage_fill == Vector3.ONE, "Production entry starts with full red liquid without a false white flash")
	await create_timer(2.4, true, false, true).timeout
	check(is_zero_approx(meter.wave_activity), "Production liquid is flat after the elevator entry movement settles")
	var damage_before: float = world.player.current_health
	world.player.invulnerability_left = 0.0
	world.player.dash_invulnerability_left = 0.0
	world.player.receive_damage(20.0)
	check(is_equal_approx(world.player.current_health, damage_before - 20.0) and meter.damage_fill.z > meter.current_fill.z, "Authoritative production damage immediately exposes the white right-hand loss")
	await snapshot("main_damage_white")
	await create_timer(.6, true, false, true).timeout
	check(meter.current_fill == meter.damage_fill, "Production damage contracts to its exact target")
	world.player.heal(1000.0)
	check(meter.current_fill == Vector3.ONE and world.player.maximum_health == max_health, "Production healing restores three segments without changing maximum HP")
	await snapshot("main_full")
	var old_meter_id := meter.get_instance_id()
	main.queue_free()
	await frames(12)
	check(not is_instance_id_valid(old_meter_id), "Leaving Main disposes its health meter")
	var tutorial_lab: Control = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	tutorial_lab.presentation_scene_path = "res://scenes/testing/TutorialMaintenanceDisplay.tscn"
	root.add_child(tutorial_lab)
	await frames(16)
	world = tutorial_lab.presentation.world
	var hint: Control = world.control_hint
	meter = hint.get_parent().get_node_or_null("LiquidHealthMeter")
	check(is_instance_valid(meter), "Tutorial health remains reachable after the clear HUD is promoted to the root")
	if not is_instance_valid(meter): finish(1); return
	check(meter.get_viewport() == root and meter.get_global_rect().end.y <= hint.position.y - 4.0, "Tutorial health and instruction UI occupy separate rows")
	check(meter.current_fill == Vector3.ONE, "Standalone tutorial also binds the actual player's health")
	await snapshot("tutorial_health_and_hint")
	world.player.receive_damage(20.0)
	check(meter.damage_fill.z > meter.current_fill.z, "Tutorial health signal drives the same right-to-left loss")
	await snapshot("tutorial_damage_white")
	Input.action_press(&"move_right")
	await create_timer(.3, true, false, true).timeout
	check(meter.motion_energy > .2, "Tutorial walking drives the shared liquid motion")
	await snapshot("tutorial_walking")
	Input.action_release(&"move_right")
	await create_timer(.10, true, false, true).timeout
	check(absf(meter.liquid_tilt) > .25 or absf(meter._tilt_velocity) > 2.0, "Tutorial stopping retains the stronger liquid inertia")
	await snapshot("tutorial_stopping")
	await create_timer(2.4, true, false, true).timeout
	check(is_zero_approx(meter.wave_activity) and is_zero_approx(meter.liquid_tilt), "Tutorial liquid becomes flat after the stop settles")
	await snapshot("tutorial_resting_flat")
	var tutorial_meter_id := meter.get_instance_id()
	tutorial_lab.queue_free()
	await frames(12)
	check(not is_instance_id_valid(tutorial_meter_id), "Tutorial exit cleans up the meter and motion source")
	finish(1 if checks.any(func(row): return not row.pass) else 0)

func finish(code: int) -> void:
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(), "checks": checks}, "\t"))
	print("LIQUID_HEALTH_ENTRY checks=", checks.size(), " failures=", checks.filter(func(row): return not row.pass).size())
	quit(code)
