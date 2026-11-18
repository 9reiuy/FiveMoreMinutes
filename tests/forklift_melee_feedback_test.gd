extends "res://tests/forklift_combat_test.gd"
## Real swept rams reuse accepted-hit ink in both lab modes and the chapter.


func verify_audio() -> void:
	var settings := root.get_node("SettingsManager")
	if settings.get_volume(&"master_volume") != 0 or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		push_error("Private muted settings were not preserved")
		quit(2)


func hits() -> Array[Node]:
	return get_nodes_in_group(&"melee_crescent_hits")


func ram(label: String, at: Vector2, yaw: float, lethal := false, reverse := false) -> void:
	await clear_attackers()
	park(at, yaw)
	var travel := Vector2.RIGHT.rotated(yaw) * (-1.0 if reverse else 1.0)
	var target := at + travel * 3.4
	var enemy: EmployeeEnemy = world._spawn_regular_employee(0, target * 32.0, &"employee", false, "")
	enemy.set_room_runtime_active(true)
	enemy.set_physics_process(false)
	enemy.global_position += target * 32.0 - enemy.get_node("CollisionShape2D").global_position
	enemy.maximum_health = 1000.0
	enemy.current_health = 10.0 if lethal else 1000.0
	await frames(3)
	var health_before := enemy.current_health
	check(hits().is_empty(), label + " has no ink before contact")
	begin_trace()
	lift.speed = -lift.REVERSE_SPEED if reverse else 8.0
	Input.action_press("move_down" if reverse else "move_up")
	for i in 100:
		await physics_frame
		if enemy.current_health < health_before:
			break
	Input.action_release("move_down" if reverse else "move_up")
	lift.reset_motion()
	check(enemy.current_health < health_before and enemy.impact_blood_spawned,
		label + " actual swept impact retains damage and blood")
	check(enemy.dead if lethal else enemy.knockback_velocity.dot(travel) > 100.0,
		label + " retains lethal damage or directional knockback")
	var effects := hits()
	check(effects.size() == 1, label + " emits exactly one melee hit")
	if effects.size() == 1:
		var effect: Node3D = effects[0]
		check(effect.get_parent() == world.floor_root and effect.global_position.y > lift.floor_height,
			label + " ink belongs to the floor at the enemy's height")
		if native:
			await frames(2)
			if is_instance_valid(effect):
				effect.set_process(false)
				await capture(label)
				effect.set_process(true)
	var health_after := enemy.current_health
	await frames(3)
	lift._hit_enemies(8.0, lift.global_position - travel * 16.0)
	check(enemy.current_health == health_after and hits().size() <= 1,
		label + " lingering contact cannot repeat damage or ink during cooldown")
	await create_timer(0.35).timeout
	check(hits().is_empty(), label + " ink expires normally after impact")
	end_trace(label)
	verify_audio()


func run() -> void:
	create_timer(180, true, false, true).timeout.connect(func(): quit(3))
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
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
		if lab.ready_world:
			break
	check(lab.ready_world, "independent lab loads")
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = true
	for mode in [0, 1]:
		lab.mode.select(mode)
		await lab.rebuild()
		verify_audio()
		lab.panel.hide()
		lab.set_process(false)
		world = lab.world
		var at := Vector2(7.0, 19.0)
		var model := MODEL.new()
		model.position = Vector3(at.x, 0.0, at.y)
		world.add_child(model)
		lift = VEHICLE.new()
		lift.configure(world, model)
		lift.floor_support = func(p: Vector2) -> bool: return Rect2(0.5, 14.5, 13.0, 9.0).has_point(p)
		world.collision_root.add_child(lift)
		lift.set_active(true)
		place_feet(at + Vector2(-0.13, 1.2))
		await frames(4)
		check(lift.board(world.player), "lab forklift boards in mode %d" % mode)
		var label := "whitebox" if mode == 0 else "production-art"
		await ram(label + "-forward", at, 0.0)
		await ram(label + "-reverse", at, 0.0, false, true)
		await ram(label + "-lethal", at, 0.0, true)
		await clear_attackers()
		park(at)
		var dormant: EmployeeEnemy = world._spawn_regular_employee(0, (at + Vector2(3.4, 0.0)) * 32.0, &"employee", false, "")
		dormant.set_physics_process(false)
		dormant.sky_drop_active = true
		var health_before := dormant.current_health
		dormant.take_damage(80.0, lift.global_position, 512.0, &"player_vehicle_impact")
		check(dormant.current_health == health_before and hits().is_empty(), label + " rejected damage emits no ink")
		var old_floor: WeakRef = weakref(world.floor_root)
		await lab.rebuild()
		check(not is_instance_valid(old_floor.get_ref()) and hits().is_empty(), label + " rebuild clears effect ownership")
	lab.queue_free()
	await frames(3)
	await enter_chapter(CHAPTER.Save.CALIBRATED)
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, 0.0))
	await frames(3)
	check(lift.board(world.player), "actual chapter entrance forklift boards")
	await ram("chapter-forward", PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
	await ram("chapter-lethal", PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING, true)
	current_scene.queue_free()
	await frames(4)
	check(hits().is_empty(), "chapter unload leaves no impact ink")
	FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"pid": OS.get_process_id(), "checks": checks, "failures": failures, "metrics": metrics,
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"scope": "Forward, reverse, lethal and rejected vehicle damage in both lab modes; real chapter forward/lethal impacts and cleanup. Native resolution; short collision windows, not whole-game certification."
	}, "\t"))
	print("FORKLIFT_MELEE_FEEDBACK checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
