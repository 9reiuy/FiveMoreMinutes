extends SceneTree
const METER := preload("res://scenes/ui/liquid_health_meter.tscn")
var output := "res://.runtime/liquid_health_20261113/lab"
var checks: Array[Dictionary] = []
var meter: Control
var lab: Control
var layer: CanvasLayer
var native := false
var timing: Dictionary = {}

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
	if not native: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func connect_meter() -> void:
	var actor: Node = lab.world.player
	# Keep the candidate A/B independent after this UI is installed in the real HUD.
	var installed: Control = lab.world.run_interface.hud.get_node_or_null("LiquidHealthMeter")
	if is_instance_valid(installed) and installed != meter: installed.hide()
	meter.set_motion_source(actor)
	actor.health_changed.connect(meter.set_health)
	meter.set_health(actor.current_health, actor.maximum_health)

func hit(amount: float) -> void:
	var actor: Node = lab.world.player
	actor.invulnerability_left = 0.0
	actor.dash_invulnerability_left = 0.0
	actor.receive_damage(amount)

func await_lab() -> void:
	while lab.busy or not lab.ready_world: await process_frame
	Engine.max_fps = 60
	await frames(8)

func sample(warmup_frames: int = 20, first_event: Callable = Callable()) -> Dictionary:
	await frames(warmup_frames)
	var raw: Array[float] = []
	var draws: Array[int] = []
	var previous := Time.get_ticks_usec()
	if first_event.is_valid(): first_event.call()
	for index in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append(float(now - previous) / 1000.0)
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous = now
	var ordered := raw.duplicate()
	ordered.sort()
	return {"raw_ms": raw, "draw_calls": draws, "p50_ms": ordered[59], "p95_ms": ordered[113], "p99_ms": ordered[118], "max_ms": ordered[-1]}

func run() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master < 0 or not AudioServer.is_bus_mute(master):
		if master >= 0: AudioServer.set_bus_mute(master, true)
		quit(1); return
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(210.0, true, false, true).timeout.connect(func(): push_error("Liquid health validation timed out"); quit(2))
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	root.add_child(lab)
	lab.checks.uncapped.button_pressed = false
	lab.checks.invincible.button_pressed = false
	await await_lab()
	lab.panel.hide()
	check(lab.world.lab_whitebox and lab.world.rooms.size() == 4, "Candidate starts in the independent four-room whitebox")
	var first_max: float = lab.world.player.maximum_health
	layer = CanvasLayer.new()
	layer.layer = 40
	root.add_child(layer)
	meter = METER.instantiate()
	layer.add_child(meter)
	connect_meter()
	check(meter.current_fill == Vector3.ONE and meter.damage_fill == Vector3.ONE, "Initial health fills exactly three cells without a damage flash")
	check(meter.position == Vector2(20, 20) and meter.size == Vector2(82, 16) and meter.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Meter matches the compact reference size and inset while ignoring pointer input")
	check(is_zero_approx(meter.wave_activity) and is_zero_approx(meter.liquid_tilt), "Stationary initial liquid has no waves or tilt")
	await snapshot("whitebox_full")
	var before: float = lab.world.player.current_health
	hit(20.0)
	var after: float = lab.world.player.current_health
	check(is_equal_approx(before - after, 20.0), "UI does not change the player's authoritative damage amount")
	check(is_equal_approx(meter.current_fill.x + meter.current_fill.y + meter.current_fill.z, 3.0 * after / first_max), "Real health_changed updates fractional thirds immediately")
	check(meter.damage_fill.z > meter.current_fill.z and meter.damage_fill.x == meter.current_fill.x, "Only the lost portion turns white immediately")
	var initial_loss: Vector3 = meter.damage_fill
	await snapshot("whitebox_damage_white")
	await create_timer(.20, true, false, true).timeout
	check(meter.damage_fill.z < initial_loss.z and meter.damage_fill.z > meter.current_fill.z, "White damage liquid contracts toward the real remaining health")
	await snapshot("whitebox_damage_shrink")
	await create_timer(.35, true, false, true).timeout
	check(meter.damage_fill.is_equal_approx(meter.current_fill), "White loss finishes draining")
	var position_before: Vector2 = lab.world.player.global_position
	var back_phase_before: float = meter._phase
	var front_phase_before: float = meter._foreground_phase
	Input.action_press(&"move_right")
	await create_timer(.30, true, false, true).timeout
	check(lab.world.player.global_position.distance_to(position_before) > 8.0 and meter.motion_energy > .2, "Real WASD movement drives liquid motion")
	check(wrapf(meter._phase - back_phase_before, -PI, PI) > .05 and wrapf(meter._foreground_phase - front_phase_before, -PI, PI) < -.05, "The two surfaces travel in independent directions and speeds")
	check(lab.world.floor_cells.has(lab.world._cell_for_gameplay_position(lab.world.player.global_position)), "Walking with the new UI retains floor collision authority")
	await snapshot("whitebox_walking")
	Input.action_release(&"move_right")
	await create_timer(.10, true, false, true).timeout
	check(absf(meter.liquid_tilt) > .25 or absf(meter._tilt_velocity) > 2.0, "Stopping leaves a visible inertial liquid response")
	await snapshot("whitebox_stopping")
	var moving_energy: float = meter.motion_energy
	await create_timer(.60, true, false, true).timeout
	check(meter.motion_energy < moving_energy * .25, "Liquid sway settles after movement stops")
	await create_timer(1.8, true, false, true).timeout
	check(is_zero_approx(meter.wave_activity) and is_zero_approx(meter.liquid_tilt), "Stopped liquid settles to an exactly flat surface")
	var settled_phase: float = meter._phase
	await create_timer(.15, true, false, true).timeout
	check(meter._phase == settled_phase, "Resting liquid does not keep flowing")
	await snapshot("whitebox_resting_flat")
	hit(5.0)
	hit(5.0)
	check(meter.damage_fill.z >= meter.current_fill.z, "Consecutive hits retain the outstanding white loss")
	lab.world.player.heal(1000.0)
	check(meter.current_fill == Vector3.ONE and meter.damage_fill == Vector3.ONE, "Healing cancels stale damage loss and refills the cells")
	meter.set_health(first_max * .25, first_max)
	await create_timer(.20, true, false, true).timeout
	var trail: Vector3 = meter.damage_fill
	check((trail.z <= 0.0 or is_equal_approx(trail.y, 1.0)) and (trail.y <= 0.0 or is_equal_approx(trail.x, 1.0)), "A large hit shrinks one continuous white front from right to left across all three segments")
	await snapshot("whitebox_cross_segment_loss")
	meter.set_health(45.0, 90.0)
	check(meter.current_fill == Vector3(1, .5, 0) and meter.damage_fill == meter.current_fill, "Changed maximum health stays normalized to three cells without false damage")
	meter.set_health(0.0, 90.0)
	await create_timer(.55, true, false, true).timeout
	check(meter.current_fill == Vector3.ZERO and meter.damage_fill == Vector3.ZERO, "Zero health empties all three liquid segments")
	await snapshot("whitebox_empty")
	meter.set_health(lab.world.player.current_health, lab.world.player.maximum_health)
	var paused_phase: float = meter._phase
	paused = true
	await create_timer(.15, true, false, true).timeout
	check(meter._phase == paused_phase, "Pause freezes the liquid animation")
	paused = false
	var old_actor: int = lab.world.player.get_instance_id()
	lab.mode.select(1)
	await lab.rebuild()
	await await_lab()
	check(not is_instance_id_valid(old_actor) and not lab.world.lab_whitebox, "Production-art rebuild releases the old gameplay actor")
	connect_meter()
	lab.panel.hide()
	check(meter.current_fill == Vector3.ONE and meter.damage_fill == Vector3.ONE, "Rebinding after reset starts full without inherited damage")
	check(lab.world.player.maximum_health == first_max, "Maximum HP is unchanged by the three-cell presentation")
	await snapshot("production_full")
	if native:
		lab.world.set_process(false)
		lab.world.player.set_physics_process(false)
		var camera_before: Transform3D = lab.world.camera_3d.global_transform
		meter.hide()
		timing.hidden_before = await sample()
		meter.show()
		timing.visible = await sample()
		meter.hide()
		timing.hidden_after = await sample()
		check(camera_before == lab.world.camera_3d.global_transform, "Matched UI A/B/A uses identical camera, art and actor load")
		meter.show()
		lab.world.set_process(true)
		lab.world.player.set_physics_process(true)
		var shots_before: int = lab.shot_count
		timing.combined = await sample(0, func():
			lab.automation = true
			lab.world.player.movement_enabled = false
			lab.world.player.set_meta(&"aim_direction_override", Vector2.RIGHT)
			lab.world.player.set_meta(&"force_weapon_attack", true)
			hit(20.0)
			lab.trigger("smoke")
		)
		lab.world.player.remove_meta(&"force_weapon_attack")
		lab.world.player.remove_meta(&"aim_direction_override")
		lab.automation = false
		check(lab.shot_count > shots_before and lab.event_history.has("smoke"), "Combined sample actually includes firing, smoke and health damage")
		await snapshot("production_combined")
	var meter_id := meter.get_instance_id()
	layer.queue_free()
	lab.queue_free()
	await frames(12)
	check(not is_instance_id_valid(meter_id), "Meter and weak motion binding clean up on leaving the world")
	var result := {"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(), "native": native, "checks": checks, "timing": timing, "scope": "Independent whitebox and production-art HUD gate; 120-frame matched samples and combined load, not a whole-game FPS certification."}
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	var failed := checks.filter(func(row): return not row.pass).size()
	print("LIQUID_HEALTH checks=", checks.size(), " failures=", failed)
	quit(1 if failed else 0)
