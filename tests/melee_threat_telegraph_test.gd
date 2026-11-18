extends SceneTree
## Same rules/layout in the independent lab's whitebox and production-art modes.
var lab: Node
var world: Node
var enemy: EmployeeEnemy
var telegraph: Node
var checks := 0
var failures: Array[String] = []
var output := ""
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var native := false


func _initialize() -> void: call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func event(label: String, start: int) -> void:
	events.append({"event": label, "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0})


func capture(label: String) -> void:
	if not native: return
	var start := Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Actual Camera " + label)
	event("capture_" + label, start)
	await frames(3) # Readback frames are excluded from the steady samples.


func stage(at: Vector2, weapon: String = "lucille") -> EmployeeEnemy:
	var actor: EmployeeEnemy = world._spawn_regular_employee(1, at, &"employee", false, weapon)
	# Production replaces Lucille spawn requests with shorter variants; this
	# controlled load explicitly equips the requested weapon after spawning.
	actor.equip_weapon(weapon)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.target = world.player
	actor.can_see_target = true
	actor.hostile = true
	actor.has_last_known_target_position = true
	actor.last_known_target_position = world.player.global_position
	actor.state = EmployeeEnemy.State.ATTACK_PLAYER
	actor.attack_cooldown_left = 0.0
	actor.reaction_left = 0.0
	actor.reload_left = 0.0
	actor.pickup_pause_left = 0.0
	actor._update_weapon_aim()
	return actor


func owned_warning_count() -> int:
	return telegraph.prepared_lines.filter(func(line: Dictionary) -> bool: return line.id == enemy.get_instance_id()).size()


func charge(weapon: String = "lucille") -> void:
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	enemy.can_see_target = true
	enemy.has_last_known_target_position = true
	enemy.equip_weapon(weapon)
	enemy.attack_cooldown_left = 0.0
	enemy.reaction_left = 0.0
	enemy.unarmed_attack_active = false
	enemy.panic_counterattack_active = weapon.is_empty()
	var reach: float = world.config.employee_unarmed_attack_range if weapon.is_empty() else enemy._melee_hit_range(weapon)
	world.player.global_position = enemy.global_position + Vector2.LEFT * minf(34.0, reach - 2.0)
	enemy.last_known_target_position = world.player.global_position
	enemy._update_weapon_aim()
	enemy._update_attack_player(0.0)


func validate_rules(mode: int) -> void:
	world = lab.world
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(145, 224)
	world.player.current_health = 10000.0
	world.player.maximum_health = 10000.0
	world.activate_room(1)
	world._update_camera_and_actor_projection(10.0)
	enemy = stage(Vector2(224, 224))
	telegraph = world.floor_root.get_node_or_null("EnemyAimTelegraph")
	check(telegraph != null, "Shared warning presenter installed, mode %d" % mode)
	if telegraph == null: quit(1); return
	await frames(5)
	check(owned_warning_count() == 0 and enemy.get_melee_telegraph_state().is_empty(), "Chasing/ready melee enemy has no persistent warning")
	enemy._update_attack_player(0.0)
	check(not enemy.melee_attack_windup_pending, "No melee charge outside actual attack reach")
	charge()
	check(enemy.melee_attack_windup_pending and is_equal_approx(enemy.melee_attack_windup_left, .3), "Entering attack reach starts a separate 0.3 second windup")
	await frames(2)
	check(owned_warning_count() == 1, "Exactly one warning during melee charge")
	var area: Dictionary = telegraph.melee_area(enemy)
	check(not area.is_empty() and area.fan_rays.size() == 17, "Melee reuses the shared projected fan")
	check(area.profile.z == 0.0 and telegraph.prepared_tails.is_empty(), "Melee has no center aim line or shot tail")
	check(telegraph.aim_segment(enemy).is_empty(), "Melee stays outside the firearm telegraph path")
	var variants: Array[String] = ["lucille", "books"]
	variants.append_array(DreamGunAtlas.LUCILLE_VARIANT_IDS)
	for id in variants:
		charge(id)
		var state: Dictionary = enemy.get_melee_telegraph_state()
		var base: float = world.config.books_attack_range if id == "books" else world.config.lucille_attack_range
		check(not state.is_empty() and is_equal_approx(state.radius, (base + 14.0) * DreamGunAtlas.get_melee_range_multiplier(id)), "Complete current weapon reach: " + id)
	charge()
	world._update_camera_and_actor_projection(10.0)
	await frames(8)
	world.set_process(false) # Hold the real Camera for matched charge images.
	var outline: Array = telegraph.melee_area(enemy).fan_rays.duplicate(true)
	for progress in [0.0, .5, 1.0]:
		enemy.melee_attack_windup_left = .3 * (1.0 - progress)
		var sampled: Dictionary = telegraph.melee_area(enemy)
		check(is_equal_approx(sampled.melee_progress, progress), "Fill follows actual preattack clock: %.2f" % progress)
		var fixed: bool = sampled.fan_rays.size() == outline.size()
		for i in outline.size():
			fixed = fixed and sampled.fan_rays[i].point.is_equal_approx(outline[i].point)
		check(fixed, "Complete perimeter remains fixed at progress %.2f" % progress)
		await capture("mode_%d_charge_%03d" % [mode, roundi(progress * 100)])
	world.set_process(true)
	check(is_zero_approx(telegraph.melee_fill_alpha(.2, 0.0)) and telegraph.melee_fill_alpha(.2, .5) > telegraph.melee_fill_alpha(.8, .5), "Fill starts empty and spreads from center to perimeter")
	check(telegraph.melee_fill_alpha(.95, 1.0) > 0.0 and is_zero_approx(telegraph.melee_fill_alpha(1.0, 1.0)), "At release fill reaches the full range and feathers out at the perimeter")
	# Fixed perimeter must not shrink when the target happens to be closer.
	charge()
	var long_area: Dictionary = telegraph.melee_area(enemy)
	enemy.melee_attack_target_snapshot = enemy.global_position + Vector2.LEFT * 5.0
	var short_area: Dictionary = telegraph.melee_area(enemy)
	check(long_area.to.is_equal_approx(short_area.to), "Full range is independent of target distance")
	for field in [&"dead", &"burning_panic", &"sky_drop_active"]:
		charge()
		enemy.set(field, true)
		enemy._update_melee_attack_windup(0.0)
		check(not enemy.melee_attack_windup_pending and enemy.get_melee_telegraph_state().is_empty(), "Charge cancels while " + String(field))
		enemy.set(field, false)
	for state in [EmployeeEnemy.State.NEUTRAL_WANDER, EmployeeEnemy.State.KNOCKED_DOWN, EmployeeEnemy.State.GETTING_UP]:
		charge()
		enemy.state = state
		enemy._update_melee_attack_windup(0.0)
		check(not enemy.melee_attack_windup_pending, "Charge cancels in non-attack state %d" % state)
	charge()
	enemy.can_see_target = false
	enemy._update_melee_attack_windup(0.0)
	check(enemy.get_melee_telegraph_state().is_empty() and not enemy.melee_attack_windup_pending, "Lost sight cancels both warning and queued hit")
	charge()
	enemy.knockback_left = .1
	enemy._update_melee_attack_windup(0.0)
	check(not enemy.melee_attack_windup_pending, "Knockback interrupts the queued swing")
	enemy.knockback_left = 0.0
	charge()
	enemy.set_room_runtime_active(false)
	check(not enemy.melee_attack_windup_pending and enemy.get_melee_telegraph_state().is_empty(), "Region deactivation clears queued melee attack")
	enemy.set_room_runtime_active(true)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	charge()
	enemy.set_meta(&"smoke_hidden_from_player", true)
	check(telegraph.melee_area(enemy).is_empty(), "Smoke does not reveal a hidden charging enemy")
	enemy.remove_meta(&"smoke_hidden_from_player")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 100)
	shape.shape = rectangle
	wall.add_child(shape)
	world.enemy_root.add_child(wall)
	wall.global_position = enemy.global_position + Vector2.LEFT * 17.0
	await physics_frame
	check(telegraph.melee_area(enemy).is_empty(), "Solid wall hides the charging warning")
	wall.queue_free()
	await frames(2)
	enemy.equip_weapon("assault_rifle")
	check(not enemy.melee_attack_windup_pending, "Weapon replacement cancels the old melee charge")
	enemy.attack_cooldown_left = 0.0
	enemy._begin_ranged_attack_windup()
	await frames(2)
	var firearm: Array = telegraph.prepared_lines.filter(func(line: Dictionary) -> bool: return line.id == enemy.get_instance_id())
	check(firearm.size() == 1 and not firearm[0].has("melee_progress") and firearm[0].profile.z > 0.0, "Ranged warning retains its existing center line")
	var serial := enemy.ranged_attack_shot_serial
	enemy._update_ranged_attack_windup(.51)
	check(enemy.ranged_attack_shot_serial == serial + 1, "Original ranged windup still fires once")
	for projectile in get_nodes_in_group(&"dream_projectiles"): projectile.queue_free()
	# Execute actual melee authority: no damage before .3, one hit at .3,
	# no persistent warning during the original recovery cooldown.
	lab.checks.invincible.button_pressed = false
	lab.apply_options()
	world.player.set_physics_process(false)
	for id in ["lucille", "books"]:
		charge(id)
		world.player.invulnerability_left = 0.0
		var health: float = world.player.current_health
		enemy._update_melee_attack_windup(.299)
		check(world.player.current_health == health and enemy.melee_attack_windup_pending, "No early damage before 0.3s: " + id)
		enemy._update_melee_attack_windup(.001)
		check(world.player.current_health < health and not enemy.melee_attack_windup_pending and enemy.get_melee_telegraph_state().is_empty(), "At 0.3s swing hits once and warning hides: " + id)
		health = world.player.current_health
		enemy._update_melee_attack_windup(.3)
		enemy._update_attack_player(.001)
		check(world.player.current_health == health and enemy.get_melee_telegraph_state().is_empty() and enemy.attack_cooldown_left > 0.0, "Recovery does not repeat a hit or keep warning visible: " + id)
		for within_arc in [true, false]:
			charge(id)
			var angle := deg_to_rad(-58.0 if within_arc else -75.0)
			world.player.global_position = enemy.global_position + Vector2.LEFT.rotated(angle) * (enemy._melee_hit_range(id) - 1.0)
			enemy.last_known_target_position = world.player.global_position
			world.player.invulnerability_left = 0.0
			health = world.player.current_health
			enemy._update_melee_attack_windup(.3)
			check((world.player.current_health < health) == within_arc, "Charged damage matches the displayed sector: %s inside_arc=%s" % [id, within_arc])
		charge(id)
		var locked: Vector2 = enemy.melee_attack_target_snapshot
		world.player.global_position = enemy.global_position + Vector2.RIGHT * 100.0
		enemy.last_known_target_position = world.player.global_position
		check(enemy.get_melee_telegraph_state().target == locked, "Committed attack direction stays fixed during dodge")
		world.player.invulnerability_left = 0.0
		health = world.player.current_health
		enemy._update_melee_attack_windup(.3)
		check(world.player.current_health == health and enemy.melee_visual_active, "Dodging the complete range avoids damage but swing still plays: " + id)
	charge("")
	check(not enemy.get_melee_telegraph_state().is_empty(), "Unarmed melee also earns a preattack warning")
	enemy._update_melee_attack_windup(.299)
	check(not enemy.unarmed_attack_active, "Unarmed counterattack cannot begin early")
	enemy._update_melee_attack_windup(.001)
	check(enemy.unarmed_attack_active and enemy.get_melee_telegraph_state().is_empty(), "Unarmed attack animation starts after the same 0.3s charge")
	enemy.unarmed_attack_active = false
	lab.checks.invincible.button_pressed = true
	lab.apply_options()
	charge()
	world._update_camera_and_actor_projection(10.0)
	if mode == 1:
		world.camera_rig.rotation.y = -PI * .25
		world._update_camera_and_actor_projection(10.0)
		await frames(5)
		check(not telegraph.melee_area(enemy).fan_rays.is_empty(), "Range follows rotated gameplay camera")
		await capture("production_rotated_fan")
	telegraph.visible = false
	await frames(2)
	check(telegraph.prepared_lines.is_empty() and not telegraph.layer.visible, "Transition hides the warning layer")
	telegraph.visible = true
	await frames(2)
	check(owned_warning_count() == 1, "Active charging enemy returns without duplicate warnings")


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
	if not lab.ready_world: check(false, "Independent lab loads"); quit(1); return
	event("first_load", start)
	lab.enemies.value = 0
	for mode in [0, 1]:
		var old_layer: WeakRef = weakref(lab.world.floor_root.get_node("EnemyAimTelegraph").layer)
		lab.mode.select(mode)
		start = Time.get_ticks_usec()
		await lab.rebuild()
		event("rebuild_mode_%d" % mode, start)
		await frames(2)
		check(old_layer.get_ref() == null, "Rebuild removes the previous floor's warning layer")
		check(lab.ready_world and lab.world.rendered_edge_failures == 0, "Lab layout/collision contracts, mode %d" % mode)
		lab.hud.hide()
		lab.panel.hide()
		Engine.max_fps = 60
		await validate_rules(mode)
	if native:
		check(RenderingServer.get_current_rendering_method() == "forward_plus", "Native Camera uses Forward+")
		check(world.camera_3d.get_viewport().get_visible_rect().size == Vector2(1280, 720), "Current native resolution is preserved")
		world.set_process(false) # Fixed Camera and AI policy for matched load.
		world.player.global_position = Vector2(224, 188)
		enemy.last_known_target_position = world.player.global_position
		enemy._cancel_melee_attack_windup()
		enemy._begin_melee_attack_windup()
		for i in 7:
			var actor := stage(world.player.global_position + Vector2.from_angle(TAU * i / 7.0) * 34.0, "lucille")
			actor._begin_melee_attack_windup()
		world._update_camera_and_actor_projection(10.0)
		Engine.max_fps = 0
		await frames(2)
		check(telegraph.prepared_lines.size() == 8, "Matched load includes eight active melee warning areas")
		telegraph.visible = false
		await sample("hidden_before")
		telegraph.visible = true
		await sample("eight_melee_areas")
		await capture("eight_melee_areas")
		telegraph.visible = false
		await sample("hidden_after")
	var weak_layer: WeakRef = weakref(telegraph.layer)
	lab.free()
	world = null
	enemy = null
	telegraph = null
	lab = null
	await frames(8)
	check(weak_layer.get_ref() == null and get_nodes_in_group(&"enemy_threat_huds").is_empty(), "Final unload leaves no warning layer or callbacks")
	var timing := {}
	for phase in ["hidden_before", "eight_melee_areas", "hidden_after"]:
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
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "native": native,
		"renderer": RenderingServer.get_current_rendering_method(), "events": events, "timing": timing,
		"scope": "Independent lab whitebox + production art, 0.3s preattack/damage/cancellation and fixed full-range perimeter; native timings cover eight frozen charging actors, uncapped, private WASAPI Master=0, no readback during steady samples; not whole-game performance."}, "\t"))
	report.close()
	print("MELEE_THREAT_RESULT ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
