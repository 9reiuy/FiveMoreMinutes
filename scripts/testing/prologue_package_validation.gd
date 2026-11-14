extends Node
## Runs only in the separate validation-feature export, never the playable ZIP.

const TRAIN := preload("res://scripts/testing/metro_station/train_chapter.gd")
var app: Control
var world: Node3D
var player: CharacterBody2D
var output := ""
var checks := 0
var failures: Array[String] = []
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var optics_evidence: Array[Dictionary] = []
var _previous := 0
var _stage := "boot"


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _previous > 0:
		frames.append({"stage": _stage, "frame_ms": float(now - _previous) / 1000.0})
	_previous = now
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		push_error("Validation mute was lost")
		get_tree().quit(2)


func ticks(count: int) -> void:
	for frame in count: await get_tree().physics_frame


func mark(stage: String) -> void:
	_stage = stage
	events.append({"stage": stage, "usec": Time.get_ticks_usec()})
	print("PROLOGUE_STAGE ", stage)


func pose(at: Vector2) -> void:
	player.global_position = at * 32.0
	player.velocity = Vector2.ZERO
	await ticks(12)


func defeat_all() -> void:
	for enemy in world.enemy_root.get_children():
		if enemy is EmployeeEnemy and not enemy.dead:
			enemy.take_damage(enemy.maximum_health + 100.0, player.global_position, 0.0, &"export_validation")
	await ticks(12)


func hold(direction: Vector2) -> void:
	var basis := Transform2D(player._camera_relative_movement_input(Vector2.RIGHT), player._camera_relative_movement_input(Vector2.DOWN), Vector2.ZERO)
	var screen := basis.affine_inverse().basis_xform(direction.normalized())
	for item in [["move_right", screen.x], ["move_left", -screen.x], ["move_down", screen.y], ["move_up", -screen.y]]:
		if item[1] > .02: Input.action_press(item[0], item[1])
		else: Input.action_release(item[0])


func release() -> void:
	for action in ["move_right", "move_left", "move_up", "move_down"]: Input.action_release(action)


func pointer() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = app.display.content_rect.get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)


func capture(label: String, root_view := false) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport: Viewport = app.get_viewport() if root_view else app.display.world_viewport
	var picture := viewport.get_texture().get_image()
	check(picture != null and picture.save_png(output.path_join(label + ".png")) == OK, "Camera " + label)
	if not root_view:
		await check_optics(label)


func check_optics(label: String) -> void:
	var optics: Node3D = world.get_node_or_null("OfficeLightOptics")
	if optics == null:
		check(false, label + " has the shared production optics")
		return
	var active: Array = optics._slots.filter(func(slot): return slot.root.visible)
	check(optics._authored and optics._slots.size() == 2 and active.size() > 0 and active.size() <= 2,
		label + " binds at most two real luminous fixtures")
	var environment: Environment = world.camera_3d.environment
	check(environment != null and environment.volumetric_fog_enabled and environment.volumetric_fog_density == 0.0,
		label + " uses local native volumetric fog without a global haze")
	var stock := preload("res://scripts/dream/office_light_optics.gd")
	check(active.all(func(slot):
		return (slot.air.material.shader == stock.AIR and slot.tubes[0].material_override.shader == stock.SURFACE
			and slot.tubes[0].material_override.get_shader_parameter("lens_dirt") == stock.DIRT.texture())),
		label + " reuses the production halo, fog shader and camera-fixed dirt mask")
	optics_evidence.append({"stage": _stage, "capture": label, "fixtures": optics._fixtures.size(), "active": active.size()})
	if not OS.get_cmdline_user_args().has("--optics-toggle-review") or label not in ["01_maintenance", "06_empty_tail"]: return
	get_node("/root/PauseManager").request_pause(&"OPTICS_QA")
	await ticks(28)
	await RenderingServer.frame_post_draw
	var baseline: Image = app.display.world_viewport.get_texture().get_image()
	baseline.save_png(output.path_join(label + "_optics_on.png"))
	await get_tree().process_frame
	get_tree().set_meta(&"optics_review_stage", label + " no_dirt")
	for slot in optics._slots:
		for tube in slot.tubes: tube.material_override.set_shader_parameter("reveals_dirt", false)
	await ticks(20)
	await RenderingServer.frame_post_draw
	var no_dirt: Image = app.display.world_viewport.get_texture().get_image()
	no_dirt.save_png(output.path_join(label + "_no_dirt.png"))
	await get_tree().process_frame
	get_tree().set_meta(&"optics_review_stage", label + " no_fog")
	for slot in optics._slots:
		slot.tubes[0].material_override.set_shader_parameter("reveals_dirt", true)
		slot.air.material.set_shader_parameter("density", 0.0)
	await ticks(28)
	await RenderingServer.frame_post_draw
	var no_fog: Image = app.display.world_viewport.get_texture().get_image()
	no_fog.save_png(output.path_join(label + "_no_fog.png"))
	await get_tree().process_frame
	get_tree().set_meta(&"optics_review_stage", label + " disabled")
	optics.enabled = false
	await ticks(24)
	await RenderingServer.frame_post_draw
	var disabled: Image = app.display.world_viewport.get_texture().get_image()
	disabled.save_png(output.path_join(label + "_optics_off.png"))
	await get_tree().process_frame
	get_tree().set_meta(&"optics_review_stage", label + " reenabled")
	optics.enabled = true
	await ticks(24)
	get_node("/root/PauseManager").release_pause(&"OPTICS_QA")
	check(baseline.get_data() != no_dirt.get_data(), label + " dirt changes the actual Camera image")
	check(baseline.get_data() != no_fog.get_data(), label + " fog changes the actual Camera image")
	check(baseline.get_data() != disabled.get_data(), label + " optical effects change the actual Camera image")


func run(owner: Control) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		get_tree().quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	if output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	app = owner
	world = app.world
	player = world.player
	player.dash_invulnerability_left = 600.0
	check(not OS.has_feature("editor") and not OS.is_debug_build(), "The actual Windows release template is running")
	check(OS.has_feature("prologue_demo") and app.scene_file_path == "res://scenes/standalone/PrologueDemo.tscn", "The exported main scene is the independent six-level chapter")
	check(not app.display.selective_enabled, "The packaged game defaults to native resolution")
	check(RenderingServer.get_current_rendering_method() == "forward_plus", "The package keeps Forward+")
	mark("0-1")
	await ticks(12)
	check(player.selected_weapon_id == "books" and is_instance_valid(world.opening_projectile), "0-1 starts with the poster and the first enemy's existing shot")
	await capture("01_maintenance")
	app.pause_menu.open_pause()
	get_node("/root/PauseManager").request_pause(app.PAUSE_REASON)
	check(get_tree().paused and app.pause_menu.is_open(), "The independent pause menu pauses gameplay")
	app._resume()
	check(not get_tree().paused, "Continue restores gameplay")
	await defeat_all()
	await pose(Vector2(41.36, 5.50))
	check(world.garage_visible, "0-1 joins 0-2")
	mark("0-2")
	var garage := Vector2(world.GARAGE_OFFSET)
	await pose(garage + Vector2(2.5, 16.5))
	await pose(garage + Vector2(2.5, 14.5))
	for frame in 700:
		if world.van_ambush.stage == world.VAN_AMBUSH.Stage.COMPLETE: break
		await get_tree().physics_frame
	check(world.van_ambush.stage == world.VAN_AMBUSH.Stage.COMPLETE, "The garage van enters, crashes and completes disembarking")
	await capture("02_garage")
	await defeat_all()
	await pose(Vector2(world.STORAGE_OFFSET) + Vector2(.92, .5))
	check(world.garage_exit_reached, "0-2 joins 0-3")
	mark("0-3")
	await ticks(15)
	await pose(Vector2(world.STORAGE_OFFSET) + Vector2(8.2, 2.8))
	check(world._storage_exit_wave_started and world._pending_guards.is_empty(), "Stockroom entry deploys its reinforcement wave")
	await capture("03_stockroom")
	await defeat_all()
	await pose(Vector2(world.TRANSIT_OFFSET) + Vector2(6.93, 13.51))
	check(world.storage_finished, "0-3 joins 0-4")
	mark("0-4")
	await ticks(15)
	await capture("04_concourse")
	await defeat_all()
	var metro_origin := Vector2(world.METRO_OFFSET)
	await pose(metro_origin + Vector2(-.5, 21.36))
	await pose(metro_origin + Vector2(-.5, 19.0))
	check(world.transit_finished, "0-4 joins 0-5")
	mark("0-5")
	var service = world._metro
	var photographed := false
	for frame in 520:
		if service.departure.beat == service.DEPARTURE.Beat.SPEAK and not photographed:
			photographed = true
			await ticks(18)
			await capture("05_station_speech")
		if service.departure.beat == service.DEPARTURE.Beat.DONE: break
		await get_tree().physics_frame
	check(photographed and service.departure.beat == service.DEPARTURE.Beat.DONE, "The packaged station speech and passenger cinematic complete")
	await defeat_all()
	for frame in 3400:
		if service._tail_threshold.is_finite(): break
		await get_tree().physics_frame
	check(service._tail_threshold.is_finite(), "After the enemies are cleared a second train opens its tail door")
	if not service._tail_threshold.is_finite():
		finish()
		return
	player.configure_weapon("assault_rifle", world.config, {})
	var player_id := player.get_instance_id()
	await pose(metro_origin + Vector2(service._tail_threshold.x, 3.12))
	hold(Vector2.UP)
	for frame in 260:
		if world._train != null: break
		await get_tree().physics_frame
	release()
	for frame in 150:
		if world._train != null and not world._train_transfer: break
		await get_tree().physics_frame
	check(world._train != null and player.get_instance_id() == player_id, "Boarding 0-5's rear door carries the same player into 0-6")
	if world._train == null:
		finish()
		return
	mark("0-6")
	var chapter: TRAIN = world._train
	check(chapter.crews[0].is_empty() and chapter.crews.size() == 6, "The last car is empty and all six original cars are present")
	await capture("06_empty_tail")
	for index in range(1, TRAIN.CONSIST.CAR_COUNT):
		await pose(Vector2(TRAIN.ART.OFFSET) + Vector2(TRAIN.CONSIST.joint(index - 1) - 1.1, 0.0))
		for frame in 100:
			if chapter.active_car >= index: break
			await get_tree().physics_frame
		check(chapter.active_car == index and chapter.art.player_train.car_gates[index - 1].fraction >= 1.0,
			"Original gangway opens to carriage %d" % (index + 1))
		for enemy: EmployeeEnemy in chapter.crews[index]:
			if not enemy.dead: enemy.take_damage(enemy.maximum_health + 100.0, player.global_position, 0.0, &"export_validation")
		await ticks(12)
	await pose(Vector2(TRAIN.ART.OFFSET) + Vector2(TRAIN.BOSS_START_X - 1.4, .46))
	for frame in 650:
		if chapter.phase == TRAIN.Phase.BOSS: break
		await get_tree().physics_frame
	check(chapter.phase == TRAIN.Phase.BOSS and is_instance_valid(chapter.boss), "The opposing train and company employee dialogue lead to the boss duel")
	if not is_instance_valid(chapter.boss):
		finish()
		return
	pointer()
	await get_tree().process_frame
	hold(Vector2.LEFT)
	Input.action_press("roll")
	await ticks(2)
	Input.action_release("roll")
	for frame in 110:
		if not is_instance_valid(chapter._slow_owner): break
		await get_tree().physics_frame
	release()
	check(is_equal_approx(Engine.time_scale, 1.0), "Space roll releases the boss opening slow motion")
	await capture("07_parallel_boss")
	chapter.boss.take_damage(chapter.boss.maximum_health + 100.0, player.global_position, 0.0, &"export_validation")
	for frame in 1600:
		if chapter.phase == TRAIN.Phase.PLATFORM: break
		await get_tree().physics_frame
	check(chapter.phase == TRAIN.Phase.PLATFORM and chapter._platform_gate.collision.disabled,
		"The opposing train branches away and the player's train arrives with its door open")
	await capture("08_arrival")
	await pose(Vector2(TRAIN.ART.OFFSET) + Vector2(chapter._dock_shift + TRAIN.ART.STAIR_X, TRAIN.ART.STAIR_BASE + .2))
	for frame in 350:
		if app.completion_panel.visible: break
		await get_tree().physics_frame
	check(app.completion_panel.visible and get_tree().paused, "Ascending the final stairs reaches the independent completion screen")
	await capture("09_completion", true)
	var old_id := app.get_instance_id()
	app._restart()
	await ticks(35)
	app = get_tree().current_scene
	world = app.world
	player = world.player
	check(app.get_instance_id() != old_id and world._train == null and not world.garage_visible
		and player.selected_weapon_id == "books" and not get_tree().paused, "Play again reloads a fresh 0-1 after completion")
	await capture("10_restart")
	finish()


func finish() -> void:
	var csv := FileAccess.open(output.path_join("frames.csv"), FileAccess.WRITE)
	csv.store_csv_line(["stage", "frame_ms"])
	var times: Array[float] = []
	for frame in frames:
		csv.store_csv_line([frame.stage, str(frame.frame_ms)])
		times.append(frame.frame_ms)
	times.sort()
	var statistics := {}
	if not times.is_empty():
		for percentile in [.5, .95, .99, 1.0]: statistics[str(percentile)] = times[clampi(ceili(times.size() * percentile) - 1, 0, times.size() - 1)]
	var report := {"checks": checks, "failures": failures, "events": events, "pid": OS.get_process_id(),
		"scope": "release-template scripted six-level traversal; includes loading and screenshot readback; not a gameplay FPS certification",
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "audio": AudioServer.get_driver_name(),
		"frames": times.size(), "frame_ms_percentiles": statistics, "window": get_window().size,
		"user_data": OS.get_user_data_dir(), "optics": optics_evidence}
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("PROLOGUE_PACKAGE checks=", checks, " failures=", failures, " frames=", times.size())
	get_tree().quit(0 if failures.is_empty() else 1)
