extends "res://tests/forklift_melee_feedback_test.gd"
## Observe the live time authority; do not disable its compositor to pass a test.

class StopProbe extends Node:
	var clock: Node
	var token := 0
	var samples: Array[Dictionary] = []
	func _physics_process(_delta: float) -> void:
		sample("physics")
	func _process(_delta: float) -> void:
		sample("render")
	func sample(phase: String) -> void:
		if clock.hitstop_active and int(clock._hitstop_token) > token:
			samples.append({"phase": phase, "token": clock._hitstop_token,
				"scale": Engine.time_scale, "remaining": clock.hitstop_remaining_real,
				"real_usec": Time.get_ticks_usec()})

var stop_probe: StopProbe
var stop_observations: Array[Dictionary] = []


func begin_stop_probe() -> void:
	var clock := root.get_node("DreamTimeController")
	check(clock.mode_enabled and clock.lifecycle_enabled and clock.is_processing(),
		"live time compositor is active for the current world")
	clock.reset_hit_stop()
	stop_probe = StopProbe.new()
	stop_probe.clock = clock
	stop_probe.token = clock._hitstop_token
	stop_probe.process_priority = 100000
	stop_probe.process_physics_priority = 100000
	root.add_child(stop_probe)


func finish_stop_probe(label: String, duration: float, expected_tokens := 1) -> void:
	var seen := stop_probe.samples
	var tokens: Dictionary = {}
	var best_remaining := 0.0
	var actual_scale := 1.0
	for sample in seen:
		tokens[sample.token] = true
		best_remaining = maxf(best_remaining, sample.remaining)
		actual_scale = minf(actual_scale, sample.scale)
	check(not seen.is_empty() and is_equal_approx(actual_scale, 0.05),
		label + " actual Engine time scale reaches 0.05")
	check(tokens.size() == expected_tokens, label + " publishes one stop without stacking")
	check(is_equal_approx(best_remaining, duration), label + " uses the configured stop duration")
	check(not stop_probe.clock.hitstop_active and is_equal_approx(Engine.time_scale, 1.0),
		label + " real-time expiry restores normal gameplay time")
	stop_observations.append({"label": label, "duration": duration, "samples": seen.duplicate(true)})
	stop_probe.queue_free()
	stop_probe = null


func begin_trace() -> void:
	super.begin_trace()
	begin_stop_probe()


func end_trace(label: String) -> void:
	super.end_trace(label)
	# These forward fixtures accelerate to 10.5m/s before contact; reverse
	# stays at 4.8m/s. Check the resulting heavy/medium tier, not initial speed.
	finish_stop_probe(label, 0.04 if label.ends_with("reverse") else 0.07)
	metrics[-1]["hitstop"] = stop_observations[-1]


func ram(label: String, at: Vector2, yaw: float, lethal := false, reverse := false) -> void:
	await super.ram(label, at, yaw, lethal, reverse)
	if label == "production-art-lethal":
		await melee_cases(at)


func melee_cases(at: Vector2) -> void:
	await clear_attackers()
	lift.set_active(false)
	var player: Node2D = world.player
	place_feet(at)
	player.set_physics_process(false)
	player.set_meta(&"presentation_pointer_position", func() -> Vector2:
		return world.camera_3d.unproject_position(world.get_gameplay_world_position(player.global_position + Vector2.RIGHT * 180.0, 0.0)))
	for kind in ["lucille", "books"]:
		for lethal in [false, true]:
			await clear_attackers()
			player.equip_weapon(kind, world.config, {})
			var weapon: Node = player.get_active_weapon()
			weapon.cancel_swing()
			weapon.cooldown_left = 0.0
			var targets: Array[EmployeeEnemy] = []
			for angle in ([-0.15, 0.0, 0.15] if lethal else [0.0]):
				var enemy: EmployeeEnemy = world._spawn_regular_employee(0, player.global_position + Vector2(48.0, 0.0).rotated(angle), &"employee", false, "")
				enemy.set_room_runtime_active(true)
				enemy.set_physics_process(false)
				enemy.sky_drop_active = false
				enemy.maximum_health = 1000.0
				enemy.current_health = 1.0 if lethal else 1000.0
				targets.append(enemy)
			await frames(3)
			var before: float = targets[0].current_health
			begin_stop_probe()
			weapon._perform_swing(false)
			for i in 90:
				await physics_frame
				if targets.all(func(enemy: EmployeeEnemy) -> bool: return enemy.current_health < before):
					break
			var label: String = String(kind) + ("-lethal" if lethal else "-nonlethal")
			check(targets.all(func(enemy: EmployeeEnemy) -> bool: return enemy.current_health < before and (enemy.dead if lethal else not enemy.dead)),
				label + " actual weapon sweep hits every real enemy")
			await create_timer(0.20, true, false, true).timeout
			finish_stop_probe(label, 0.04 if kind == "lucille" else 0.02)
			weapon.cancel_swing()
			verify_audio()
	await clear_attackers()
	var weapon: Node = player.get_active_weapon()
	begin_stop_probe()
	weapon._perform_swing(false)
	await create_timer(0.5, true, false, true).timeout
	check(stop_probe.samples.is_empty(), "empty melee sweep does not freeze gameplay")
	stop_probe.queue_free()
	stop_probe = null
	weapon.cancel_swing()
	player.equip_weapon("", world.config, {})
	for source in ["punch", "kick"]:
		await clear_attackers()
		var enemy: EmployeeEnemy = world._spawn_regular_employee(0, player.global_position + Vector2(24.0, 0.0), &"employee", false, "")
		enemy.set_room_runtime_active(true)
		enemy.set_physics_process(false)
		enemy.sky_drop_active = false
		enemy.global_position += player.global_position + Vector2(24.0, 0.0) - enemy.body_collision.global_position
		enemy.maximum_health = 1000.0
		enemy.current_health = 1000.0
		await frames(3)
		begin_stop_probe()
		if source == "punch":
			player.punch_direction = Vector2.RIGHT
			player._apply_punch_hits()
		else:
			player.kick_direction = Vector2.RIGHT
			player._apply_kick_hits()
		stop_probe.sample("accepted-hit")
		check(enemy.current_health < 1000.0, source + " real melee hit is accepted")
		await create_timer(0.20, true, false, true).timeout
		finish_stop_probe(source, 0.02)
	player.set_physics_process(true)
	player.remove_meta(&"presentation_pointer_position")
	FileAccess.open(evidence.path_join("melee_hitstop.json"), FileAccess.WRITE).store_string(JSON.stringify(stop_observations, "\t"))
