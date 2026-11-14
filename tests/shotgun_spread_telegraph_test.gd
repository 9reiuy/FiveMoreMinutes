extends SceneTree
const RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
var lab: Node
var world: Node
var enemy: EmployeeEnemy
var presenter: Node
var checks := 0
var failures: Array[String] = []
var output := ""
var native := false
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var volleys: Array[Dictionary] = []
var completed_modes := 0


func _initialize() -> void: call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func capture(label: String) -> void:
	if not native: return
	var start := Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Actual Camera " + label)
	events.append({"event": "capture_" + label, "ms": (Time.get_ticks_usec() - start) / 1000.0})
	await frames(5)


func spawn_shooter(at: Vector2) -> EmployeeEnemy:
	var actor: EmployeeEnemy = world._spawn_regular_employee(1, at, &"employee", false, "shotgun")
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.target = world.player
	actor.hostile = true
	actor.can_see_target = true
	actor.has_last_known_target_position = true
	actor.last_known_target_position = world.player.global_position
	actor.last_known_target_velocity = Vector2.ZERO
	actor.last_known_room = 1
	actor.state = EmployeeEnemy.State.ATTACK_PLAYER
	actor.reload_left = 0.0
	actor.pickup_pause_left = 0.0
	actor.attack_cooldown_left = 0.0
	actor.reaction_left = 0.0
	actor._update_weapon_aim()
	return actor


func windup(weapon := "shotgun") -> void:
	enemy.equip_weapon(weapon)
	enemy.reload_left = 0.0
	enemy.pickup_pause_left = 0.0
	enemy.attack_cooldown_left = 0.0
	enemy.burst_shot_count = 0
	enemy.last_known_target_position = world.player.global_position
	enemy.last_known_target_velocity = Vector2.ZERO
	enemy.velocity = Vector2.ZERO
	enemy._update_weapon_aim()
	enemy._begin_ranged_attack_windup()


func actor_bullets(actor: Node) -> Array:
	return get_nodes_in_group(&"active_basic_projectiles").filter(func(p: Node) -> bool: return p.shooter_instance_id == actor.get_instance_id() and not p.is_queued_for_deletion())


func clear_bullets() -> void:
	for p in get_nodes_in_group(&"active_basic_projectiles"): p.queue_free()


func stop_private_audio() -> void:
	var audio: Node = root.get_node("SFXManager")
	for event_id in audio.players.keys(): audio.stop(event_id)
	for voice in audio.world_3d_voices:
		if is_instance_valid(voice): voice.stop()


func validate(mode: int) -> void:
	world = lab.world
	world.activate_room(1)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(145, 224)
	world.set_process(false)
	enemy = spawn_shooter(Vector2(224, 224))
	presenter = world.floor_root.get_node("EnemyAimTelegraph")
	world._update_camera_and_actor_projection(10.0)
	await frames(8)
	check(enemy.get_ranged_telegraph_state().is_empty(), "No shotgun warning before windup")
	windup()
	check(enemy.ranged_attack_windup_pending, "Production shotgun begins existing half-second windup")
	var parameters := RULES.parameters(enemy.feedback_config, &"shotgun")
	var initial: Dictionary = presenter.aim_segment(enemy)
	var expected: float = parameters.spread_degrees + enemy._get_current_weapon_spread_degrees()
	check(is_equal_approx(initial.spread_degrees, expected), "Warning contains pellet spread plus shared aim error")
	check(initial.start.is_equal_approx(enemy.get_projectile_origin()), "Cone starts at the actual clamped gameplay muzzle")
	var snapshot: Dictionary = world._weapon_visual_snapshot(enemy, initial.start)
	check(Vector3(initial.center_world).is_equal_approx(snapshot.world_origin), "Cone uses the same 3D muzzle snapshot as live bullets")
	var rng_state := enemy.random.state
	presenter.aim_segment(enemy)
	presenter._process(0.0)
	check(enemy.random.state == rng_state, "Warning never samples or advances shot randomness")
	var start_points: Array[Vector2] = []
	for progress in [0.0, .5, 1.0]:
		enemy.ranged_attack_windup_left = .5 * (1.0 - progress)
		presenter._process(0.0)
		var lines: Array = presenter.prepared_lines.filter(func(line: Dictionary) -> bool: return line.id == enemy.get_instance_id())
		check(lines.size() == 1, "One shotgun warning per actor")
		if lines.is_empty(): quit(1); return
		var area: Dictionary = lines[0]
		check(area.has("shotgun_spread") and area.profile.z == 0.0 and is_equal_approx(area.profile.x, expected), "Shotgun keeps the full cone through charge %.1f" % progress)
		var bounded := true
		var same := true
		var axis: Vector2 = (initial.target - initial.start).normalized()
		for i in area.fan_rays.size():
			var ray: Dictionary = area.fan_rays[i]
			var offset: Vector2 = presenter._gameplay_displacement(area.projection, ray.point)
			bounded = bounded and offset.length() <= float(parameters.range) + .01
			if offset.length_squared() > .01:
				bounded = bounded and absf(rad_to_deg(axis.angle_to(offset))) <= expected * .5 + .01
			if progress == 0.0: start_points.append(ray.point)
			else: same = same and Vector2(ray.point).is_equal_approx(start_points[i])
		check(bounded and same, "Warning rays respect physical cone/range and do not collapse")
		await capture("mode_%d_shotgun_%03d" % [mode, roundi(progress * 100)])
	var tuned: DemoConfig = enemy.feedback_config.duplicate(true)
	tuned.shotgun_spread_degrees += 9.0
	enemy.feedback_config = tuned
	check(is_equal_approx(presenter.aim_segment(enemy).spread_degrees, expected + 9.0), "Changing authored pellet spread changes the warning by the same amount")
	enemy.feedback_config = world.config
	enemy.last_known_target_velocity = Vector2.RIGHT * world.config.player_movement_speed
	check(presenter.aim_segment(enemy).spread_degrees > expected, "Warning also covers movement-induced aim error")
	enemy.last_known_target_velocity = Vector2.ZERO
	# A real production volley, including the pre-shot aim-error envelope.
	var warning: Dictionary = presenter.aim_segment(enemy)
	var axis: Vector2 = (warning.target - warning.start).normalized()
	enemy.random.seed = 1973
	var serial := enemy.ranged_attack_shot_serial
	enemy._update_ranged_attack_windup(.51)
	var bullets := actor_bullets(enemy)
	check(bullets.size() == int(parameters.pellets) and enemy.ranged_attack_shot_serial == serial + 1, "Accepted enemy shot spawns the authored pellet count once")
	var angles: Array[float] = []
	for p in bullets:
		p.set_physics_process(false)
		var angle := rad_to_deg(axis.angle_to(p.direction))
		angles.append(angle)
		check(absf(angle) <= float(warning.spread_degrees) * .5 + .001, "Actual pellet stays inside the warned envelope")
	volleys.append({"mode": mode, "source": "enemy", "warning_degrees": warning.spread_degrees, "pellet_degrees": angles.duplicate()})
	check(is_equal_approx(enemy.ranged_attack_shot_spread_degrees, warning.spread_degrees), "Accepted shot freezes its envelope before the burst counter changes")
	presenter._process(0.0)
	check(presenter.prepared_tails.size() == 1 and presenter.prepared_tails[0].has("shotgun_spread") and is_equal_approx(presenter.prepared_tails[0].profile.x, warning.spread_degrees), "Accepted-shot tail remains a cone, not a center line")
	clear_bullets()
	await frames(15)
	presenter._process(0.0)
	check(presenter.prepared_lines.is_empty() and presenter.prepared_tails.is_empty(), "Shotgun warning and tail expire without lingering")
	windup()
	enemy.reload_left = 1.0
	presenter._process(0.0)
	check(presenter.prepared_lines.is_empty(), "Reload hides the shotgun warning")
	enemy.reload_left = 0.0
	windup()
	enemy.set_meta(&"smoke_hidden_from_player", true)
	check(presenter.aim_segment(enemy).is_empty(), "Smoke does not expose a shotgun enemy")
	enemy.remove_meta(&"smoke_hidden_from_player")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 100)
	collider.shape = rectangle
	wall.add_child(collider)
	world.enemy_root.add_child(wall)
	wall.global_position = Vector2(185, 224)
	await physics_frame
	check(presenter.aim_segment(enemy).is_empty(), "Solid wall hides the warning")
	wall.queue_free()
	await frames(2)
	windup("assault_rifle")
	presenter._process(0.0)
	var rifle: Dictionary = presenter.prepared_lines[0]
	check(not rifle.has("shotgun_spread") and rifle.profile.z > 0.0, "Other ranged weapons retain their original aim core")
	await capture("mode_%d_rifle_unchanged" % mode)
	enemy._cancel_ranged_attack_windup()
	enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	enemy.global_position = Vector2(224, 100)
	# Use the real player ShotgunWeapon, not a diagram or replacement shooter.
	world.player.global_position = Vector2(224, 224)
	world.player.equip_weapon("shotgun", world.config, {})
	world.player.set_meta(&"aim_direction_override", Vector2.RIGHT)
	world.player._update_held_weapon_aim()
	world._update_camera_and_actor_projection(10.0)
	seed(4631)
	check(world.player.shotgun_weapon._fire_once(), "Real player shotgun fires immediately")
	bullets = actor_bullets(world.player)
	var player_parameters := RULES.parameters(world.config, &"shotgun")
	check(bullets.size() == int(player_parameters.pellets), "Real player keeps authored pellet count")
	angles.clear()
	for p in bullets:
		angles.append(rad_to_deg(Vector2(p.direction).angle()))
		check(absf(angles[-1]) <= float(player_parameters.spread_degrees) * .5 + .001, "Real player pellet respects authored spread")
	volleys.append({"mode": mode, "source": "player", "pellet_degrees": angles.duplicate()})
	for i in 5: await physics_frame
	await capture("mode_%d_player_volley" % mode)
	clear_bullets()
	await frames(10)
	check(not enemy.melee_attack_windup_pending, "Shotgun changes do not start melee warnings")
	# Leave one stable live warning for the next lifecycle/load sample.
	world.player.global_position = Vector2(224, 188)
	enemy.global_position = Vector2(224, 224)
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	windup()
	world._update_camera_and_actor_projection(10.0)
	completed_modes += 1


func sample(label: String) -> void:
	await frames(30)
	var previous := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append({"phase": label, "frame": i, "ms": (now - previous) / 1000.0})
		previous = now


func run() -> void:
	create_timer(180, true, false, true).timeout.connect(func() -> void: quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="): output = arg.trim_prefix("--artifact-dir=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		quit(2); return
	var diag := root.get_node_or_null("_DroneGameDiag")
	if diag != null: diag.free()
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	var start := Time.get_ticks_usec()
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	await frames(2)
	while lab.busy: await process_frame
	if not lab.ready_world: check(false, "Lab initial load"); quit(1); return
	events.append({"event": "first_load", "ms": (Time.get_ticks_usec() - start) / 1000.0})
	lab.enemies.value = 0
	lab.checks.pixels.button_pressed = false
	for mode in [0, 1]:
		var old_layer: WeakRef = weakref(lab.world.floor_root.get_node("EnemyAimTelegraph").layer)
		lab.mode.select(mode)
		start = Time.get_ticks_usec()
		await lab.rebuild()
		events.append({"event": "rebuild_mode_%d" % mode, "ms": (Time.get_ticks_usec() - start) / 1000.0})
		await frames(2)
		check(old_layer.get_ref() == null and lab.ready_world and lab.world.rendered_edge_failures == 0, "Rebuild clears old HUD and preserves lab collision contracts")
		lab.hud.hide()
		lab.panel.hide()
		Engine.max_fps = 60
		await validate(mode)
	check(completed_modes == 2, "Both complete validation routes reached cleanup")
	if native:
		check(RenderingServer.get_current_rendering_method() == "forward_plus" and world.camera_3d.get_viewport().get_visible_rect().size == Vector2(1280, 720), "Native Forward+ and current resolution preserved")
		for i in 7:
			var actor := spawn_shooter(world.player.global_position + Vector2.from_angle(TAU * i / 7.0) * 34.0)
			actor._begin_ranged_attack_windup()
		world._update_camera_and_actor_projection(10.0)
		presenter._process(0.0)
		check(presenter.prepared_lines.size() == 8, "Matched load has eight shotgun warning cones")
		stop_private_audio()
		# The live-volley check above can leave hit/graze feedback and muzzle
		# smoke alive. Let those finish before isolating warning-only cost.
		var settle_start := Time.get_ticks_usec()
		var clock: Node = world.player._get_dream_time_controller()
		clock.clear_reaction_time()
		clock.reset_hit_stop()
		clock.end_tactical_planning()
		clock.set_slow_time_enabled(false)
		await create_timer(2.0, true, false, true).timeout
		var smoke: Node = world.floor_root.get_node_or_null("MuzzleSmoke")
		check(is_equal_approx(Engine.time_scale, 1.0) and (smoke == null or smoke.puffs.is_empty()), "Warning-only timing starts at normal speed after muzzle smoke expires")
		events.append({"event": "transient_settle_before_timing", "ms": (Time.get_ticks_usec() - settle_start) / 1000.0})
		Engine.max_fps = 0
		presenter.visible = false
		await sample("hidden_before")
		presenter.visible = true
		await sample("eight_shotgun_cones")
		await capture("eight_shotgun_cones")
		presenter.visible = false
		await sample("hidden_after")
	var old: WeakRef = weakref(presenter.layer)
	# Stop this private test's still-playing cue/gunshot voices before teardown.
	stop_private_audio()
	lab.free()
	lab = null
	world = null
	enemy = null
	presenter = null
	await frames(8)
	await create_timer(.15, true, false, true).timeout
	check(old.get_ref() == null and get_nodes_in_group(&"enemy_threat_huds").is_empty(), "Final unload leaves no threat HUD")
	var timing := {}
	for phase in ["hidden_before", "eight_shotgun_cones", "hidden_after"]:
		var values: Array[float] = []
		for row in samples:
			if row.phase == phase: values.append(row.ms)
		if values.is_empty(): continue
		values.sort()
		timing[phase] = {"frames": values.size(), "p50_ms": values[59], "p95_ms": values[113], "p99_ms": values[118], "max_ms": values[-1]}
	var csv := FileAccess.open(output.path_join("frames.csv"), FileAccess.WRITE)
	csv.store_line("phase,frame,ms")
	for row in samples: csv.store_csv_line([row.phase, row.frame, row.ms])
	csv.close()
	var report := FileAccess.open(output.path_join("validation.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "native": native, "renderer": RenderingServer.get_current_rendering_method(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(), "volleys": volleys, "events": events, "timing": timing,
		"scope": "GameTestLab whitebox and production art; real player/enemy volleys and warning geometry; uncapped native matched samples use eight frozen windups, private WASAPI Master=0 with voices stopped before timing, no readback in sample windows; not whole-game performance."}, "\t"))
	report.close()
	print("SHOTGUN_WARNING_RESULT ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
