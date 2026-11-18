extends "res://tests/forklift_revision_test.gd"
## Live AI attacks, occupied-cab presentation and real swept vehicle contacts.
var trace_callback: Callable
var trace_times: Array[float] = []
var trace_stamp := 0


func begin_trace() -> void:
	trace_times.clear()
	trace_stamp = Time.get_ticks_usec()
	trace_callback = func() -> void:
		var now := Time.get_ticks_usec()
		trace_times.append((now - trace_stamp) * 0.001)
		trace_stamp = now
	process_frame.connect(trace_callback)


func end_trace(label: String) -> void:
	process_frame.disconnect(trace_callback)
	var sorted := trace_times.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return
	metrics.append({"label": label, "frames_ms": trace_times.duplicate(),
		"p50_ms": sorted[ceili(sorted.size() * 0.50) - 1],
		"p95_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_ms": sorted[ceili(sorted.size() * 0.99) - 1], "max_ms": sorted[-1],
		"frames_over_16_667_ms": trace_times.filter(func(ms: float) -> bool: return ms > 16.667).size()})


func spawn_attacker(at: Vector2, weapon: String) -> EmployeeEnemy:
	var enemy: EmployeeEnemy = world._spawn_regular_employee(0, at * 32.0, &"employee", false, weapon)
	enemy.equip_weapon(weapon)
	enemy.set_room_bounds(Rect2(Vector2(0.5, 14.5) * 32.0, Vector2(13.0, 9.0) * 32.0))
	enemy.set_room_runtime_active(true)
	return enemy


func clear_attackers() -> void:
	for node in world.enemy_root.get_children():
		node.queue_free()
	for node in world.world_effects_root.get_children():
		if node.is_in_group(&"dream_projectiles"):
			node.queue_free()
	await frames(3)
	lift.hp = 300.0
	lift.smoking = false


func check_seat(label: String) -> void:
	var feet: Vector2 = world.player.body_collision.global_position
	var displayed: Vector3 = world.to_local(world.player_depth_bridge._character_ground())
	var seat := lift._seat_position()
	check(feet.distance_to(seat) < 0.05
		and Vector2(displayed.x, displayed.z).distance_to(seat / 32.0) < 0.002,
		label + " physical and displayed driver remain at the seat center")


func validate_ai(label: String, at: Vector2) -> void:
	park(at)
	begin_trace()
	var rifle := spawn_attacker(at + Vector2(-4.0, 0.0), "assault_rifle")
	await frames(4)
	var aim := rifle._sample_combat_target_position()
	check(lift.is_combat_target_for(rifle), label + " occupied vehicle is the driver's combat target")
	check(world.is_furniture_shot_path_clear(rifle.get_projectile_origin(), aim, rifle),
		label + " the target vehicle does not cancel its own incoming shots")
	var wall := block(Rect2(at + Vector2(-2.0, -1.5), Vector2(0.15, 3.0)))
	wall.collision_layer = world.WORLD_WALL_LAYER | 4
	await frames(2)
	check(not world.is_furniture_shot_path_clear(rifle.get_projectile_origin(), aim, rifle)
		and not rifle._has_target_line_of_sight(aim), label + " a separate wall still blocks sight and firing")
	wall.queue_free()
	await frames(3)
	for i in 300:
		if lift.hp < 300.0:
			break
		await physics_frame
	check(rifle.hostile and lift.hp < 300.0 and not lift.destroyed,
		label + " live ranged AI discovers and damages the occupied vehicle")
	print("AI_RANGED ", label, " hp=", lift.hp, " state=", rifle.state, " ammo=", rifle.current_ammo)
	rifle.set_physics_process(false)
	await frames(4)
	end_trace(label + "-first-ranged-attack")
	await capture(label + "-ranged-attacks-vehicle")
	check(lift.try_exit(), label + " driver can dismount after incoming fire")
	place_feet(at + Vector2(2.7, 0.0))
	await frames(3)
	check(not lift.is_combat_target_for(rifle)
		and not world.is_furniture_shot_path_clear(rifle.get_projectile_origin(), world.player.global_position, rifle),
		label + " empty forklift remains cover rather than an automatic enemy target")
	place_feet(at + Vector2(-0.13, 1.2))
	check(lift.board(world.player), label + " driver can board again")
	await clear_attackers()
	begin_trace()
	var melee := spawn_attacker(at + Vector2(0.0, 2.5), "lucille")
	var winding_frames := 0
	var swing_frames := 0
	var maximum_cooldown := 0.0
	for i in 360:
		if lift.hp < 300.0:
			break
		await physics_frame
		winding_frames += int(melee.melee_attack_windup_pending)
		swing_frames += int(melee.melee_visual_active)
		maximum_cooldown = maxf(maximum_cooldown, melee.attack_cooldown_left)
	check(melee.hostile and lift.hp < 300.0 and not lift.destroyed,
		label + " live melee AI approaches the perimeter and damages the vehicle")
	print("AI_MELEE ", label, " hp=", lift.hp, " state=", melee.state,
		" range=", melee.global_position.distance_to(melee._get_known_target_position()),
		" reach=", melee._melee_hit_range(melee.held_weapon_id), " charge_frames=", winding_frames,
		" swing_frames=", swing_frames, " cooldown=", maximum_cooldown, " can_charge=", melee._can_continue_melee_windup())
	await frames(4)
	end_trace(label + "-first-melee-attack")
	await capture(label + "-melee-attacks-vehicle")
	await clear_attackers()


func validate_driving(label: String, at: Vector2) -> void:
	check(is_equal_approx(lift.FORWARD_SPEED, 10.5) and is_equal_approx(lift.REVERSE_SPEED, 4.8)
		and is_equal_approx(lift.BOOST_SPEED, 18.0), label + " driving and boost speed limits are tripled")
	for direction in ["move_left", "move_right"]:
		park(at)
		Input.action_press("move_up")
		Input.action_press(direction)
		await frames(12)
		check_seat(label + " " + direction)
		Input.action_release(direction)
		Input.action_release("move_up")
	park(at)
	for index in 4:
		park(at, index * PI * 0.5)
		await frames(6)
		check_seat(label + " heading %d" % index)
		check(lift.visual.body_mesh_instance.get_active_material(0) is StandardMaterial3D,
			label + " canopy stays opaque at heading %d" % index)
		await capture(label + "-centered-heading-%d" % index)
	check(MODEL.CAB_CEILING_Y > 2.1 and MODEL.CANOPY_TOP_Y > MODEL.CAB_CEILING_Y,
		label + " raised canopy leaves the seated player under the roof")
	park(at)
	var enemy := spawn_attacker(at + Vector2(3.4, 0.0), "basic")
	enemy.set_physics_process(false)
	enemy.global_position += (at + Vector2(3.4, 0.0)) * 32.0 - enemy.get_node("CollisionShape2D").global_position
	enemy.maximum_health = 1000.0
	enemy.current_health = 1000.0
	await frames(3)
	begin_trace()
	lift.speed = lift.FORWARD_SPEED
	Input.action_press("move_up")
	for i in 60:
		if enemy.current_health < 1000.0:
			break
		await physics_frame
	Input.action_release("move_up")
	check(enemy.current_health < 1000.0 and enemy.knockback_velocity.length() > 100.0,
		label + " a real forward contact damages and knocks the enemy away")
	var after_hit := enemy.current_health
	lift.speed = 0.0
	await frames(3)
	check(enemy.current_health == after_hit, label + " stationary contact does not repeatedly grind damage")
	end_trace(label + "-first-vehicle-impact")
	enemy.set_physics_process(true)
	await frames(4)
	await capture(label + "-ramming-impact")
	await clear_attackers()
	park(at)
	var wall := block(Rect2(at + Vector2(4.5, -2.5), Vector2(0.25, 5.0)))
	await frames(3)
	lift.speed = lift.BOOST_SPEED
	lift.boost_left = lift.BOOST_DURATION
	Input.action_press("move_up")
	await frames(24)
	Input.action_release("move_up")
	check(lift.global_position.x / 32.0 + MODEL.FORK_TIP_X <= at.x + 4.58,
		label + " maximum-speed swept collision stops the forks at a real wall")
	wall.queue_free()
	park(at)


func run() -> void:
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	lab = load(LAB).instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 1200:
		await process_frame
		if lab.ready_world:
			break
	check(lab.ready_world, "independent combat lab loads")
	verify_audio()
	lab.enemies.value = 0
	lab.checks.furniture.button_pressed = false
	lab.checks.ai.button_pressed = true
	lab.checks.invincible.button_pressed = false
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
		world.collision_root.add_child(lift)
		lift.set_active(true)
		place_feet(at + Vector2(-0.13, 1.2))
		await frames(4)
		check(lift.board(world.player), "board combat fixture %d" % mode)
		await validate_ai("whitebox" if mode == 0 else "production-art", at)
		await validate_driving("whitebox" if mode == 0 else "production-art", at)
		await sample("whitebox-driving" if mode == 0 else "production-art-driving", true)
		check(lift.try_exit(), "end fixture on foot %d" % mode)
		var old: WeakRef = weakref(lift)
		await lab.rebuild()
		verify_audio()
		check(not is_instance_valid(old.get_ref()), "rebuild cleans up combat vehicle %d" % mode)
	lab.queue_free()
	await frames(3)
	await enter_chapter(CHAPTER.Save.CALIBRATED)
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2, 0.0))
	await frames(3)
	check(lift.board(world.player), "normal 1-2 entry vehicle still boards")
	check_seat("normal chapter camera")
	await frames(8)
	await capture("chapter-raised-canopy")
	check_follow_camera("1-2 normal camera")
	var chapter_enemy: EmployeeEnemy = world._spawn_regular_employee(0,
		(PLAN.FORKLIFT_START + Vector2(-2.2, 0.0)) * 32.0, &"employee", false, "assault_rifle")
	chapter_enemy.set_room_bounds(Rect2(Vector2(-12.3, -36.8) * 32.0, Vector2(15.6, 12.5) * 32.0))
	chapter_enemy.set_room_runtime_active(true)
	for i in 240:
		if lift.hp < 300.0:
			break
		await physics_frame
	check(chapter_enemy.hostile and lift.hp < 300.0 and not lift.destroyed,
		"live 1-2 enemy attacks and damages the occupied entrance vehicle")
	await capture("chapter-enemy-attacks-vehicle")
	current_scene.queue_free()
	await frames(4)
	var report := {"checks": checks, "failures": failures, "metrics": metrics,
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"pid": OS.get_process_id(), "scope": "Live ranged/melee AI, real vehicle impacts, centered cab and raised canopy in whitebox plus production-art lab, then actual chapter entrance. Short uncapped samples are not full-game certification."}
	var file := FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("FORKLIFT_COMBAT checks=", checks.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
