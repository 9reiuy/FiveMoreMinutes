extends "res://tests/forklift_combat_test.gd"
## Candidate admission before live integration; actual-camera follow-up afterwards.
const CANDIDATE := preload("res://tests/support/forklift_boost_candidate.gd")
var integrated := false

func verify_audio() -> void:
	var settings := root.get_node("SettingsManager")
	if settings.get_volume(&"master_volume") != 0 or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		push_error("Private muted settings were not preserved")
		quit(2)

func wind() -> Node3D:
	return lift.visual.get_node_or_null("BoostWind")

func fixture(at: Vector2, enabled: bool) -> void:
	if is_instance_valid(lift):
		lift.set_active(false)
		lift.visual.queue_free()
		lift.queue_free()
		await frames(3)
	var model := MODEL.new()
	model.position = Vector3(at.x, 0.0, at.y)
	world.add_child(model)
	var controller: Script = VEHICLE if integrated or not enabled else CANDIDATE
	lift = controller.new()
	lift.configure(world, model)
	lift.floor_support = func(p: Vector2) -> bool: return Rect2(0.5, 14.5, 13.0, 9.0).has_point(p)
	world.collision_root.add_child(lift)
	lift.set_active(true)
	place_feet(at + Vector2(-0.13, 1.2))
	await frames(4)
	check(lift.board(world.player), "fixture boards")
	verify_audio()

func quantiles(raw: Array[float]) -> Dictionary:
	var sorted := raw.duplicate()
	sorted.sort()
	return {"frames_ms": raw, "p50_ms": sorted[ceili(sorted.size() * 0.5) - 1],
		"p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "p99_ms": sorted[ceili(sorted.size() * 0.99) - 1],
		"max_ms": sorted[-1], "over_80_ms": raw.filter(func(ms: float) -> bool: return ms > 80.0).size()}

func measure(label: String, at: Vector2) -> void:
	var raw: Array[float] = []
	var stamp := Time.get_ticks_usec()
	for frame in 180:
		if frame % 16 == 0:
			park(at)
			lift.speed = lift.FORWARD_SPEED
			lift.boost_recharge = 0.0
			Input.action_press("move_up")
			lift.start_boost()
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append((now - stamp) * 0.001)
		stamp = now
	Input.action_release("move_up")
	park(at)
	var result := quantiles(raw)
	result.label = label
	result.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	metrics.append(result)
	print("WIND_SAMPLE ", label, " p95=", result.p95_ms, " p99=", result.p99_ms, " max=", result.max_ms)

func validate_wind(label: String, at: Vector2) -> void:
	var effect := wind()
	check(is_instance_valid(effect) and effect.get_parent() == lift.visual, label + " wind is owned by the original vehicle visual")
	var live_materials := true
	for index in effect.layers.size():
		var mesh: MeshInstance3D = effect.layers[index]
		live_materials = live_materials and mesh.material_override == effect.materials[index] and mesh.material_override.shader.code.contains("uniform sampler2D wind_mask")
	check(live_materials, label + " boarding and reflection wrapping preserve the live transparent material")
	check(effect.find_children("*", "CollisionObject3D", true, false).is_empty()
		and effect.find_children("*", "Light3D", true, false).is_empty(), label + " effect adds no collisions or lights")
	park(at)
	await frames(3)
	check(not effect.visible, label + " stationary forklift has no wind")
	Input.action_press("move_up")
	await frames(12)
	check(not effect.visible, label + " normal acceleration has no boost wind")
	for heading in [0.0, PI * 0.5, PI, -PI * 0.5]:
		park(at, heading)
		lift.speed = lift.FORWARD_SPEED
		lift.boost_recharge = 0.0
		Input.action_press("move_up")
		check(lift.start_boost(), label + " Shift boost accepts a fresh press")
		await frames(8)
		check(effect.is_visible_in_tree() and float(effect.strength) > 0.25, label + " moving boost exposes flow lines")
		check(effect.global_basis.x.normalized().dot(lift.visual.global_basis.x.normalized()) > 0.999,
			label + " shell follows body heading")
		lift.set_physics_process(false)
		await capture(label + "-heading-%d" % roundi(rad_to_deg(heading)))
		lift.set_physics_process(true)
		Input.action_release("move_up")
		lift.boost_left = 0.0
		await frames(10)
		check(not effect.visible, label + " released boost fades out")
	var original_physics: Node2D = lift.get_parent()
	var original_visual: Node3D = lift.visual.get_parent()
	var region_physics := Node2D.new()
	var region_visual := Node3D.new()
	world.collision_root.add_child(region_physics)
	world.add_child(region_visual)
	lift.transfer_to(region_physics, region_visual)
	check(wind() == effect and is_instance_valid(lift.driver), label + " live region transfer preserves the same vehicle-owned wind")
	lift.transfer_to(original_physics, original_visual)
	region_physics.queue_free()
	region_visual.queue_free()
	park(at)
	lift.speed = lift.FORWARD_SPEED
	lift.boost_recharge = 0.0
	Input.action_press("move_up")
	lift.start_boost()
	await frames(8)
	Input.action_press("roll")
	await frames(10)
	check(lift.boost_left == 0.0 and not effect.visible, label + " handbrake cancels the wind")
	park(at)
	var wall := block(Rect2(at + Vector2(2.6, -2.0), Vector2(0.2, 4.0)))
	await frames(3)
	lift.speed = lift.FORWARD_SPEED
	lift.boost_recharge = 0.0
	Input.action_press("move_up")
	lift.start_boost()
	var collided := false
	for i in 30:
		await physics_frame
		if lift.get_slide_collision_count() > 0:
			collided = true
			break
	await frames(10)
	check(collided and lift.boost_left == 0.0 and not effect.visible, label + " actual wall impact cancels boost wind")
	wall.queue_free()
	park(at)
	lift.speed = lift.FORWARD_SPEED
	lift.boost_recharge = 0.0
	Input.action_press("move_up")
	lift.start_boost()
	await frames(6)
	lift.reset_motion()
	check(not effect.visible and float(effect.strength) == 0.0, label + " reset clears the wind immediately")
	Input.action_release("move_up")
	check(lift.try_exit() and not effect.visible, label + " dismount leaves no wind")
	lift.set_active(false)
	check(not effect.visible and lift.driver == null, label + " deactivation clears wind and driver")
	verify_audio()

func run() -> void:
	create_timer(180, true, false, true).timeout.connect(func(): quit(3))
	# Live integration is the normal entry. Admission is only for the saved
	# pre-promotion controller snapshot; its raw results are kept in .runtime.
	integrated = "--admission" not in OS.get_cmdline_user_args()
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	var settings := root.get_node("SettingsManager")
	settings._load_settings()
	settings._apply_all_audio()
	verify_audio()
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world: break
	check(lab.ready_world, "independent lab loads")
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = true
	for mode in ([] if "--combined-only" in OS.get_cmdline_user_args() else [0, 1]):
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		var at := Vector2(7.0, 19.0)
		var label := "whitebox" if mode == 0 else "production-art"
		if not integrated:
			for enabled in [false, true, false]:
				await fixture(at, enabled)
				await measure(label + ("-wind" if enabled else "-baseline"), at)
		await fixture(at, true)
		await validate_wind(label, at)
		var old: WeakRef = weakref(wind())
		await lab.rebuild()
		check(not is_instance_valid(old.get_ref()), label + " rebuild frees wind with the model")
	if not integrated:
		lab.mode.select(1)
		lab.enemies.value = 8
		lab.checks.furniture.button_pressed = true
		lab.checks.ai.button_pressed = true
		for enabled in [false, true, false]:
			await lab.rebuild()
			verify_audio()
			lab.panel.hide()
			lab.set_process(false)
			world = lab.world
			await fixture(Vector2(7.0, 19.0), enabled)
			lift.max_hp = 100000.0
			lift.hp = 100000.0
			await frames(90)
			await measure("combined-" + ("wind" if enabled else "baseline"), Vector2(7.0, 19.0))
			metrics[-1].enemy_count = world.enemy_root.get_child_count()
			metrics[-1].furniture_count = world.furniture_root.get_child_count()
			check(lift.hp > 0.0 and (not enabled or is_instance_valid(wind())), "combined load keeps the vehicle and effect alive")
	if integrated:
		lab.queue_free()
		await frames(3)
		await enter_chapter(CHAPTER.Save.CALIBRATED)
		place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, 0.0))
		await frames(3)
		check(lift.board(world.player), "actual chapter entrance forklift boards")
		park(PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
		lift.speed = lift.FORWARD_SPEED
		lift.boost_recharge = 0.0
		Input.action_press("move_up")
		await key(KEY_SHIFT)
		await key(KEY_SHIFT, false)
		await frames(4)
		check(wind().is_visible_in_tree(), "actual chapter Shift input shows the wind")
		lift.set_physics_process(false)
		await capture("chapter-boost")
		lift.set_physics_process(true)
		park(PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
		var old: WeakRef = weakref(wind())
		current_scene.queue_free()
		await frames(4)
		check(not is_instance_valid(old.get_ref()), "actual chapter unload clears wind")
	verify_audio()
	FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"checks": checks, "failures": failures, "metrics": metrics, "pid": OS.get_process_id(),
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"integrated": integrated, "scope": "Two independent lab modes, real driving/boost input, first-use and A/B/A short windows without camera readback; four headings, reset and rebuild. Controlled clear lane, not whole-game certification."
	}, "\t"))
	print("FORKLIFT_BOOST_WIND checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
