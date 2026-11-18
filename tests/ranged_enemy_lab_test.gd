extends SceneTree

const LAB := preload("res://scenes/testing/RangedEnemyLab.tscn")
const SAMPLE := preload("res://scripts/entities/ranged_employee.gd")
const DT := 1.0 / 60.0
const ANCHOR := Vector2(224, 224)
var bench: Node
var world: Node
var gunner: SAMPLE
var phase := ""
var passed: Array[String] = []
var failed: Array[String] = []
var timings := {}
var measurements: Array = []
var folder := ""
var native := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	var entry := phase + " / " + label
	if ok:
		passed.append(entry)
	else:
		failed.append(entry)
		push_error(entry)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func quiet() -> bool:
	var settings := root.get_node("SettingsManager")
	if settings.get_volume(&"master_volume") != 0 or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true)
		push_error("Private test master volume must be zero")
		quit(2)
		return false
	return true

func capture(label: String) -> void:
	if not native:
		return
	# Let the body and weapon capture viewports publish their updated poses.
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Camera " + label)

func move_player(offset: Vector2, motion := Vector2.ZERO) -> void:
	world.player.global_position = gunner.global_position + offset
	world.player.velocity = motion

func tick() -> void:
	gunner._process_profiled(DT)
	gunner._update_target_perception_clock(DT)
	gunner._update_attack_player(DT)
	gunner._update_weapon_aim()

func until_aim(max_steps := 90) -> int:
	for i in max_steps:
		tick()
		if gunner.ranged_attack_windup_pending:
			return i + 1
	return -1

func fixture(at := ANCHOR, room_id := 1) -> void:
	if world.get_current_room_id() != room_id: world.activate_room(room_id)
	gunner.set_room_runtime_active(true)
	world.set_process(false)
	world.set_physics_process(false)
	gunner.set_physics_process(false)
	gunner.set_process(false)
	world.player.set_physics_process(false)
	gunner.random.seed = 1873
	gunner.global_position = at
	gunner.equip_weapon("assault_rifle")
	gunner.hostile = false
	gunner.can_see_target = false
	gunner.has_last_known_target_position = false
	gunner.turning = false
	gunner.searching = false
	gunner.state = EmployeeEnemy.State.NEUTRAL_WANDER
	gunner.weapon_root.rotation = PI
	gunner.last_facing_direction = Vector2.LEFT
	move_player(Vector2(60, 0))
	gunner._update_visual_target_perception()
	check(not gunner.can_see_target and not gunner.hostile, "neutral rear approach stays hidden")
	move_player(Vector2(-90, 0))
	gunner._update_visual_target_perception()
	check(gunner.can_see_target and gunner.hostile, "front discovery")
	gunner.state = EmployeeEnemy.State.ATTACK_PLAYER
	gunner.reaction_left = 0.0
	gunner.attack_cooldown_left = 0.0
	gunner.pickup_pause_left = 0.0
	world._update_camera_and_actor_projection(10.0)

func check_bursts() -> void:
	check(until_aim() > 0 and is_equal_approx(gunner.ranged_attack_windup_left, 0.70), "first warning 0.70 s")
	var shots: Array[int] = []
	var serial := gunner.ranged_attack_shot_serial
	var start := serial
	var displays := 1
	for i in 185:
		var aiming := gunner.ranged_attack_windup_pending
		tick()
		if gunner.ranged_attack_windup_pending and not aiming:
			displays += 1
		if gunner.ranged_attack_shot_serial != serial:
			serial = gunner.ranged_attack_shot_serial
			shots.append(i + 1)
		if i == 28:
			var view: Dictionary = gunner.get_ranged_telegraph_state()
			check(not view.is_empty() and absf(view.get("progress", 0.0) - 29 * DT / 0.7) < 0.03, "warning intensity follows its full duration")
			check(not world.floor_root.get_node("EnemyAimTelegraph").aim_segment(gunner).is_empty(), "live projected warning")
			if phase == "production-art":
				await capture("first-aim")
		if serial >= start + 6:
			break
	timings[phase + "_shot_ticks_60hz"] = shots
	check(shots.size() == 6 and displays == 2, "two three-shot bursts with exactly two warnings")
	if shots.size() == 6:
		check(shots[0] >= 41 and shots[1] - shots[0] < 11 and shots[2] - shots[1] < 11, "first release and original within-burst cadence")
		var gap := (shots[3] - shots[2]) * DT
		check(absf(gap - SAMPLE.BURST_GAP) < DT, "0.85 s burst gap includes the next warning (%.3f)" % gap)

func check_reacquisition() -> void:
	move_player(Vector2(-6, 0), Vector2(210, 0))
	gunner._update_visual_target_perception()
	var last_seen := gunner.last_known_target_position
	move_player(Vector2(55, 0))
	gunner._update_visual_target_perception()
	gunner._update_attack_player(DT)
	check(gunner.searching and gunner.hostile and gunner.state == EmployeeEnemy.State.ATTACK_PLAYER and gunner.lkp_search_time_left > 1.95, "6 px close pass starts full search")
	check(not gunner.can_see_target and gunner.last_known_target_position == last_seen, "hidden movement does not update remembered point")
	var serial := gunner.ranged_attack_shot_serial
	var reached := false
	var turn_max := 0.0
	for i in 105:
		var previous := gunner.look_angle
		tick()
		turn_max = maxf(turn_max, absf(angle_difference(previous, gunner.look_angle)))
		if gunner.ranged_attack_windup_pending:
			reached = true
			timings[phase + "_back_to_warning_s"] = (i + 1) * DT
			break
	check(reached and turn_max <= SAMPLE.TURN_RATE * DT + 0.001, "turns toward the crossing and reacquires at bounded speed")
	check(gunner.ranged_attack_shot_serial == serial and is_equal_approx(gunner.ranged_attack_windup_left, 0.45), "same magazine must re-aim for 0.45 s")
	if not reached:
		return
	while gunner.ranged_attack_windup_left > 0.195:
		tick()
	var locked := gunner.ranged_attack_target_snapshot
	move_player(Vector2(57, 20))
	gunner._update_visual_target_perception()
	tick()
	check(gunner.ranged_attack_target_snapshot.is_equal_approx(locked) and not locked.is_equal_approx(world.player.global_position), "final 0.20 s keep announced direction")
	if phase == "production-art":
		world._update_camera_and_actor_projection(10.0)
		await capture("reacquired-aim")
	for i in 18:
		tick()
		if gunner.ranged_attack_shot_serial > serial:
			break
	check(gunner.ranged_attack_shot_serial == serial + 1, "reacquisition releases one real round")
	var tails: Dictionary = world.floor_root.get_node("EnemyAimTelegraph").shot_tails
	if native:
		check(tails.has(gunner.get_instance_id()) and locked.is_equal_approx(tails[gunner.get_instance_id()].target), "shot release uses the locked warning point")

func check_cover() -> void:
	await check_wall()
	await check_smoke()

func check_wall() -> void:
	# The world supplies its actual opaque wall/door collision mask.
	var mask: int = world.get_vision_occluder_collision_mask()
	var wall := StaticBody2D.new()
	wall.collision_layer = mask
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(6, 120)
	shape.shape = box
	wall.add_child(shape)
	wall.position = gunner.global_position + Vector2(28, 0)
	world.collision_root.add_child(wall)
	await physics_frame
	await physics_frame
	var serial := gunner.ranged_attack_shot_serial
	gunner._try_fire_ranged_attack()
	check(gunner.ranged_attack_shot_serial == serial and not gunner.can_see_target, "solid cover blocks a ready automatic shot between samples")
	wall.free()
	await physics_frame
	await physics_frame
	gunner._update_visual_target_perception()
	var peek := until_aim()
	check(peek > 0 and is_equal_approx(gunner.ranged_attack_windup_left, 0.45), "peeking from cover warns before firing")

func check_smoke() -> void:
	var smoke: Node = world.floor_root.get_node("FireExtinguisherSystem")
	var midpoint := gunner.global_position.lerp(world.player.global_position, 0.5)
	smoke.discharge(midpoint)
	for i in 120:
		smoke.advance(DT, false)
		if smoke.blocks_sight(gunner.global_position, world.player.global_position):
			break
	check(smoke.blocks_sight(gunner.global_position, world.player.global_position), "discharged extinguisher places visible smoke across the sightline")
	tick()
	check(not gunner.ranged_attack_windup_pending and not gunner.can_see_target and gunner.get_ranged_telegraph_state().is_empty(), "smoke cancels an aim in progress")
	var remembered := gunner.last_known_target_position
	for i in 125:
		tick()
	check(not gunner.hostile and not gunner.has_last_known_target_position and gunner.last_known_target_position == remembered, "full two seconds behind smoke end contact")
	smoke.advance(smoke.DURATION + 1.0, false)
	check(not smoke.blocks_sight(gunner.global_position, world.player.global_position), "extinguisher dissipates before the roll trial")

func check_equipment() -> void:
	fixture()
	gunner.current_ammo = 1
	var serial := gunner.ranged_attack_shot_serial
	for i in 80:
		tick()
		if gunner.ranged_attack_shot_serial != serial:
			break
	check(gunner.ranged_attack_shot_serial == serial + 1 and gunner.reload_left > 0 and gunner.get_ranged_telegraph_state().is_empty(), "last round fires once and reload clears the warning")
	check(until_aim(180) > 0 and gunner.current_ammo == gunner.magazine_capacity and is_equal_approx(gunner.ranged_attack_windup_left, 0.70), "fresh magazine earns the full first warning")
	gunner.equip_weapon("shotgun")
	check(not gunner.ranged_attack_windup_pending and until_aim(180) > 0 and gunner.get_ranged_telegraph_state().get("spread_degrees", 0.0) > 0.0, "weapon swap resets the rifle and preserves the shotgun warning cone")
	gunner.equip_weapon("mp5")
	var mp5_start := gunner.ranged_attack_shot_serial
	var warnings := 0
	for i in 110:
		var was_aiming := gunner.ranged_attack_windup_pending
		tick()
		if not was_aiming and gunner.ranged_attack_windup_pending:
			warnings += 1
		if gunner.ranged_attack_shot_serial - mp5_start >= 4:
			break
	check(gunner.ranged_attack_shot_serial - mp5_start == 4 and warnings == 1, "MP5 continues through its fourth round after a single warning")

func check_live_roll(at := ANCHOR, room_id := 1, camera_label := "", clear_melee := false) -> void:
	# Fresh encounter and real engine frames, including AI, projectiles and player motion.
	if world.get_current_room_id() != room_id: world.activate_room(room_id)
	gunner.set_room_runtime_active(true)
	gunner.global_position = at
	gunner.random.seed = 1873
	world.player.movement_enabled = true
	var lateral_offset: float = world.player.runtime_config.phase_dash_attack_radius + gunner.get_hurt_radius() + 20.0 if clear_melee else 16.0
	move_player(Vector2(-65, lateral_offset))
	gunner.weapon_root.rotation = PI
	gunner.last_facing_direction = Vector2.LEFT
	gunner.turning = false
	gunner.perception_update_left = 0.0
	gunner.set_process(true)
	gunner.set_physics_process(true)
	for i in 100:
		await physics_frame
		if gunner.ranged_attack_windup_pending:
			break
	check(gunner.ranged_attack_windup_pending, "live opponent begins aiming")
	var before := gunner.ranged_attack_shot_serial
	if clear_melee:
		# Windup follows the guard's approach. Measure the passing lane from
		# where the guard actually stopped moving to raise the pistol.
		move_player(Vector2(-65, lateral_offset))
	var start_offset: Vector2 = world.player.global_position - gunner.global_position
	var closest := start_offset.length()
	var start_x: float = world.player.global_position.x
	check(world.player.try_start_phase_dash(Vector2.RIGHT, true), "actual player dive-roll accepted")
	var saw_search := false
	var saw_reaim := false
	var crossed := false
	var shot_before_reaim := false
	var elapsed_frames := 0
	for i in 115:
		await physics_frame
		elapsed_frames = i + 1
		closest = minf(closest, world.player.global_position.distance_to(gunner.global_position))
		crossed = crossed or world.player.global_position.x > gunner.global_position.x + 12
		saw_search = saw_search or gunner.searching
		if saw_search and gunner.ranged_attack_windup_pending and is_equal_approx(gunner.ranged_warning_seconds, 0.45):
			saw_reaim = true
			break
		if gunner.ranged_attack_shot_serial != before:
			shot_before_reaim = true
	timings[phase + "_roll_travel_x"] = world.player.global_position.x - start_x
	timings[phase + "_roll"] = {"crossed": crossed, "searched": saw_search, "new_warning": saw_reaim, "early_shot": shot_before_reaim, "physics_frames": elapsed_frames, "guard_alive": not gunner.dead, "roll_hits": world.player.phase_dash.last_result.get("hits", 0), "starting_offset": str(start_offset), "closest_approach": closest}
	check(crossed and saw_search and saw_reaim and not shot_before_reaim, "playable roll crosses the gunner, interrupts fire and earns a new warning")
	if native and not camera_label.is_empty() and saw_reaim:
		for i in 14:
			await physics_frame
			if gunner.get_ranged_telegraph_state().get("progress", 0.0) > 0.36: break
		await capture(camera_label)
	gunner.set_room_runtime_active(false)
	check(gunner.get_ranged_telegraph_state().is_empty() and not gunner.ranged_attack_windup_pending and not gunner.turning, "room deactivation cancels both aim and turning")

func validate(mode: int) -> void:
	phase = "whitebox" if mode == 0 else "production-art"
	bench.mode.select(mode)
	await bench.rebuild()
	world = bench.world
	if not quiet(): return
	bench.hud.hide()
	check(world.range_gunner is SAMPLE and world.enemy_root.get_child_count() == 1, "one sample gunner through the normal spawn pipeline")
	gunner = world.range_gunner
	fixture()
	await check_bursts()
	await check_reacquisition()
	await check_cover()
	check_equipment()
	var old: WeakRef = weakref(gunner)
	await bench.rebuild()
	check(old.get_ref() == null, "rebuild releases the old opponent")
	world = bench.world
	gunner = world.range_gunner
	await check_live_roll(ANCHOR, 1, "live-roll-reaim" if mode == 1 else "")

func performance_windows(tracking_only := false) -> void:
	phase = "tracking" if tracking_only else "combined"
	bench.mode.select(1)
	bench.enemies.value = 8
	bench.checks.ai.button_pressed = true
	bench.checks.furniture.button_pressed = true
	for candidate in [false, true, false]:
		bench.use_new_aim = candidate
		await bench.rebuild()
		if not quiet(): return
		world = bench.world
		bench.hud.hide()
		# Same equipment, positions, facing, and seed across all three runs.
		var center: Vector2 = world.station_position(1)
		world.player.global_position = center
		if tracking_only: world.player.set_physics_process(false)
		world.player.lab_ignore_damage = true
		world.activate_room(1)
		var count := 0
		var group: Array[EmployeeEnemy] = []
		for actor: EmployeeEnemy in world.enemy_root.get_children():
			if count == 0:
				check((actor is SAMPLE) == candidate and (candidate or is_equal_approx(actor.ranged_warning_seconds, 0.5)), "expected gunner implementation in the comparison")
			actor.random.seed = 1873 + count
			actor.set_meta(&"test_steering_identity", count + 1)
			# Crossfire still registers hits and recoil. Keep both windows at
			# eight survivors instead of benchmarking a room emptied by gunfire.
			actor.maximum_health = 10000.0
			actor.current_health = actor.maximum_health
			actor.equip_weapon("assault_rifle")
			var point: Vector2 = world.player.global_position + Vector2.from_angle(TAU * count / 8.0) * 85.0
			actor.global_position = point
			world.sync_employee_ground_region(actor)
			actor.set_room_runtime_active(true)
			actor.weapon_root.rotation = point.direction_to(world.player.global_position).angle()
			if tracking_only: actor.attack_cooldown_left = 90.0
			group.append(actor)
			count += 1
		await frames(90)
		var serials: Array[int] = []
		var sights: Array[bool] = []
		var sight_changes := 0
		var furniture_before: int = world.furniture_root.get_child_count()
		var alive_before := 0
		for actor in group:
			serials.append(actor.ranged_attack_shot_serial)
			sights.append(actor.can_see_target)
			if not actor.dead and actor.room_runtime_active: alive_before += 1
		var shots := 0
		var events := []
		var raw := []
		var stamp := Time.get_ticks_usec()
		for frame in 180:
			if tracking_only:
				var angle := TAU * frame / 90.0
				world.player.global_position = center + Vector2(100 * sin(angle), 18 * sin(2.0 * angle))
			await process_frame
			var now := Time.get_ticks_usec()
			raw.append((now - stamp) * 0.001)
			stamp = now
			for i in group.size():
				if sights[i] != group[i].can_see_target:
					sight_changes += 1
					sights[i] = group[i].can_see_target
				var serial := group[i].ranged_attack_shot_serial
				if serial != serials[i]:
					var fired := serial - serials[i]
					shots += fired
					events.append({"frame":frame + 1, "gunner":i + 1, "shots":fired})
					serials[i] = serial
		var alive_after := 0
		for actor in group:
			if not actor.dead and actor.room_runtime_active: alive_after += 1
		var row := preload("res://scripts/testing/lab_recorder.gd").stats(raw)
		row.merge({"candidate": candidate, "raw_ms": raw, "events": events, "enemies": count, "alive_before": alive_before, "alive_after": alive_after, "furniture_before": furniture_before, "furniture": world.furniture_root.get_child_count(), "sight_changes": sight_changes, "new_shots": shots})
		measurements.append(row)
		check(count == 8 and alive_before == 8 and alive_after == 8 and row.furniture > 0, "eight active opponents and furnished room over the measured window")
		if tracking_only:
			check(shots == 0 and sight_changes > 0 and row.furniture == furniture_before, "tracking control covers sight changes without combat events")
		else:
			check(shots > 0, "rifles fired during the window")

func run() -> void:
	folder = OS.get_environment("RANGED_LAB_EVIDENCE")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("user://ranged_enemy_lab_test")
	DirAccess.make_dir_recursive_absolute(folder)
	create_timer(240.0, true, false, true).timeout.connect(func(): quit(3))
	native = DisplayServer.get_name() != "headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
	var settings := root.get_node("SettingsManager")
	settings._load_settings()
	settings._apply_all_audio()
	if not quiet(): return
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.max_fps = 60
	bench = LAB.instantiate()
	root.add_child(bench)
	current_scene = bench
	while not bench.ready_world:
		await process_frame
	check(bench.world.range_gunner is SAMPLE and not bench.panel.visible, "playable entry starts ready")
	var started_aiming := false
	for i in 150:
		await physics_frame
		if bench.world.range_gunner.ranged_attack_windup_pending:
			started_aiming = true
			break
	check(started_aiming, "untouched playable spawn starts a real warning")
	if "--tracking-only" in OS.get_cmdline_user_args():
		await performance_windows(true)
	else:
		await validate(0)
		await validate(1)
		if native and "--functional-only" not in OS.get_cmdline_user_args():
			await performance_windows()
	if not quiet(): return
	var result := {"passed": passed, "failed": failed, "timings": timings, "windows": measurements, "configuration": bench.configuration(), "renderer": RenderingServer.get_current_rendering_method(), "driver": AudioServer.get_driver_name(), "pid": OS.get_process_id()}
	FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("RANGED_ENEMY_LAB passed=", passed.size(), " failed=", failed.size())
	quit(0 if failed.is_empty() else 1)
