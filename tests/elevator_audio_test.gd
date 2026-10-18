extends SceneTree

## Elevator audio coverage: arrival chime, floor-badge cue, and the ride bed.
##
## Covers the three things that are easy to get wrong here:
##   1. the arrival cue replaced a placeholder stack (home_door + phone_unlock),
##      so the test asserts the old events are gone and not merely layered;
##   2. the ride bed is a seamless loop on an autoload-owned player, so looping
##      must be configured on the stream and the player must be releasable from
##      every transition exit (arrival, rollback, scene teardown);
##   3. `elevator_rumble_active` used to be declared-but-never-assigned dead
##      code, so the shake flag and the audio bed are asserted to move together.

const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const SFX_SCRIPT := preload("res://scripts/audio/sfx_manager.gd")

const TRANSITION_FLOOR_SEED := 41001
const TRANSITION_BUDGET_MS := 30000

var checks: int = 0
var failures: Array[String] = []
var played_events: Array[StringName] = []


func _initialize() -> void:
	# `--script` SceneTree runs do not install autoloads, so the manager is
	# mounted by hand.  Naming it "SFXManager" keeps the static entry points
	# (SFX.play_event / play_elevator_rumble) resolving correctly.
	if root.get_node_or_null("SFXManager") == null:
		var manager := SFX_SCRIPT.new()
		manager.name = "SFXManager"
		root.add_child(manager)
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures.append(label)
		print("[FAIL] ", label)


func frames(count: int) -> void:
	for _i in count:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _on_sfx_played(event_id: StringName) -> void:
	played_events.append(event_id)


func _manager() -> Node:
	return root.get_node("SFXManager")


func _run() -> void:
	print("==================================================")
	print("=== ELEVATOR AUDIO TEST SUITE ===")
	print("==================================================")

	var manager := _manager()
	manager.sfx_played.connect(_on_sfx_played)

	_test_registry_and_resources(manager)
	await _test_rumble_loop_configuration(manager)
	await _test_rumble_start_stop(manager)
	await _test_badge_cue_and_idempotence(manager)
	await _test_arrival_cue_replaces_placeholder(manager)
	await _test_full_transition_audio(manager)

	print("")
	print("==================================================")
	print("checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("RESULT: ALL ELEVATOR AUDIO CHECKS PASSED")
	else:
		print("RESULT: FAILURES")
		for entry in failures:
			print("  - ", entry)
	print("==================================================")
	# Let queued frees settle so the run does not report leaked instances that
	# are merely still pending.
	await frames(4)
	quit(failures.size())


# ------------------------------------------------------------------------------
# Registry: events exist, on the intended buses, at the intended levels.
# ------------------------------------------------------------------------------
func _test_registry_and_resources(manager: Node) -> void:
	print("\n--- Registry & resources ---")
	var players: Dictionary = manager.players

	check(players.has(&"elevator_ding"), "elevator_ding event is registered")
	check(players.has(&"elevator_badge"), "elevator_badge event is registered")

	if players.has(&"elevator_ding"):
		var ding: AudioStreamPlayer = players[&"elevator_ding"]
		check(ding.stream != null, "elevator_ding has a stream")
		# The arrival cue fires mid-transition, so it must not sit behind the
		# WorldSFX time-scale/low-pass chain (Environment routes there).
		check(ding.bus == &"SFX", "elevator_ding rides the raw SFX bus")
		check(is_equal_approx(ding.volume_db, -11.0), "elevator_ding is trimmed to -11 dB")
		if ding.stream != null:
			var length := ding.stream.get_length()
			check(length > 1.40 and length < 1.60,
				"elevator_ding is the ~1.5s classic descending chime (got %.3fs)" % length)

	if players.has(&"elevator_badge"):
		var badge: AudioStreamPlayer = players[&"elevator_badge"]
		check(badge.stream != null, "elevator_badge has a stream")
		check(badge.bus == &"UI", "elevator_badge follows the acquisition-cue bus (UI)")
		check(is_equal_approx(badge.volume_db, -13.0), "elevator_badge is trimmed to -13 dB")
		if badge.stream != null:
			var length := badge.stream.get_length()
			check(length > 2.60 and length < 2.90,
				"elevator_badge is the ~2.75s airy gong (got %.3fs)" % length)

	check(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus exists")
	check(AudioServer.get_bus_index(&"UI") >= 0, "UI bus exists")


# ------------------------------------------------------------------------------
# The ride bed must actually be a loop.  `_set_loop` previously ignored WAV
# entirely, which left every imported WAV stuck one-shot.
# ------------------------------------------------------------------------------
func _test_rumble_loop_configuration(manager: Node) -> void:
	print("\n--- Ride bed loop configuration ---")
	var player: AudioStreamPlayer = manager.elevator_rumble_player
	check(player != null, "elevator rumble player was created in _ready")
	if player == null:
		return

	check(player.bus == &"SFX", "elevator rumble rides the raw SFX bus")
	check(player.stream != null, "elevator rumble stream is loaded")
	if player.stream == null:
		return

	var wav := player.stream as AudioStreamWAV
	check(wav != null, "elevator rumble stream is an AudioStreamWAV")
	if wav == null:
		return

	check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"elevator rumble WAV is set to LOOP_FORWARD")
	check(wav.loop_begin == 0, "elevator rumble loop begins at sample 0")

	var length := wav.get_length()
	check(length > 3.90 and length < 4.10,
		"elevator rumble is the ~4.0s power-station loop (got %.3fs)" % length)


# ------------------------------------------------------------------------------
# Start/stop behaviour, including the idempotence guarantee.
# ------------------------------------------------------------------------------
func _test_rumble_start_stop(manager: Node) -> void:
	print("\n--- Ride bed start / stop / fade ---")
	var player: AudioStreamPlayer = manager.elevator_rumble_player
	if player == null:
		return

	check(not manager.is_elevator_rumble_active(), "ride bed is silent before any ride")

	SFX_SCRIPT.play_elevator_rumble(0.05)
	await frames(2)
	check(player.playing, "ride bed plays after play_elevator_rumble")
	await wait(0.25)
	check(is_equal_approx(player.volume_db, SFX_SCRIPT.ELEVATOR_RUMBLE_DB),
		"ride bed settles at the authored level (%.1f dB)" % player.volume_db)

	# Idempotence: a second call must not restart the clip, because restarting a
	# loop is an audible click.
	var before := player.volume_db
	SFX_SCRIPT.play_elevator_rumble(0.05)
	await frames(2)
	check(player.playing, "ride bed keeps playing across a repeated start")
	await wait(0.25)
	check(is_equal_approx(player.volume_db, before),
		"repeated start re-asserts the level instead of jumping")

	SFX_SCRIPT.stop_elevator_rumble(0.05)
	await wait(0.30)
	check(not player.playing, "ride bed stops after stop_elevator_rumble")

	# Stopping again must be harmless: every abort path calls it unconditionally.
	SFX_SCRIPT.stop_elevator_rumble(0.05)
	await frames(2)
	check(not player.playing, "repeated stop is harmless")


# ------------------------------------------------------------------------------
# Floor-badge acquisition cue: fires once, then never again for the same floor.
# ------------------------------------------------------------------------------
func _test_badge_cue_and_idempotence(manager: Node) -> void:
	print("\n--- Floor badge cue ---")
	var world = await _make_world()
	if world == null:
		return

	check(not world.has_floor_badge, "fresh world starts without a floor badge")

	played_events.clear()
	world.collect_employee_badge()
	await frames(2)
	check(world.has_floor_badge, "collect_employee_badge sets has_floor_badge")
	check(played_events.has(&"elevator_badge"),
		"acquiring the badge plays the airy gong cue")
	check(world.elevator_state == &"UNLOCKED", "badge acquisition still unlocks the elevator")

	played_events.clear()
	world.collect_employee_badge()
	await frames(2)
	check(not played_events.has(&"elevator_badge"),
		"a second collect on the same floor stays silent")

	world.queue_free()
	await frames(2)


# ------------------------------------------------------------------------------
# The arrival cue must be the new chime, not the old layered placeholder.
# ------------------------------------------------------------------------------
func _test_arrival_cue_replaces_placeholder(manager: Node) -> void:
	print("\n--- Arrival cue ---")
	var world = await _make_world()
	if world == null:
		return

	played_events.clear()
	world._play_elevator_arrival_chime()
	await frames(2)

	check(played_events.has(&"elevator_ding"), "arrival plays the elevator_ding cue")
	check(not played_events.has(&"home_door"),
		"arrival no longer borrows home_door")
	check(not played_events.has(&"phone_unlock"),
		"arrival no longer borrows phone_unlock")
	check(played_events.size() == 1,
		"arrival is a single cue, not a layered stack (got %d events)" % played_events.size())

	world.queue_free()
	await frames(2)


# ------------------------------------------------------------------------------
# End-to-end: a real floor transition must run the ride bed across CAB_RIDE and
# release it on arrival, with the shake flag moving in lockstep.
# ------------------------------------------------------------------------------
func _test_full_transition_audio(manager: Node) -> void:
	print("\n--- Full transition: ride bed + shake + arrival cue ---")
	var world = await _make_world()
	if world == null:
		return

	if not world.regenerate(TRANSITION_FLOOR_SEED):
		check(false, "world regenerated for the transition test")
		world.queue_free()
		return
	await frames(4)

	var player: AudioStreamPlayer = manager.elevator_rumble_player
	check(not world.elevator_rumble_active,
		"shake is idle before the ride starts")

	# Grant the badge so the elevator is usable, then drive the real transition.
	world.has_floor_badge = true
	played_events.clear()
	world._begin_elevator_entry_transition()

	var saw_ride_phase := false
	var saw_rumble_during_ride := false
	var saw_shake_during_ride := false
	var rumble_active_while_idle := false
	var started := Time.get_ticks_msec()

	while world.floor_transition_in_progress and Time.get_ticks_msec() - started < TRANSITION_BUDGET_MS:
		if world.transition_phase == &"CAB_RIDE":
			saw_ride_phase = true
			if manager.is_elevator_rumble_active():
				saw_rumble_during_ride = true
			if world.elevator_rumble_active and world.elevator_rumble_intensity > 0.0:
				saw_shake_during_ride = true
		elif world.transition_phase == &"IDLE" or world.transition_phase == &"ENTERING":
			if manager.is_elevator_rumble_active():
				rumble_active_while_idle = true
		await create_timer(0.02).timeout

	var elapsed := Time.get_ticks_msec() - started
	check(saw_ride_phase, "transition reached the CAB_RIDE phase")
	check(saw_rumble_during_ride, "ride bed plays while the cab is riding")
	check(saw_shake_during_ride,
		"camera shake flag is live while the cab is riding (was dead code)")
	check(not rumble_active_while_idle,
		"ride bed never runs before the cab starts moving")

	# Arrival: the cue fires and both the bed and the shake are released.
	await wait(0.60)
	check(not world.elevator_rumble_active,
		"shake flag is cleared once the ride arrives")
	check(not manager.is_elevator_rumble_active(),
		"ride bed is released once the ride arrives")
	check(played_events.has(&"elevator_ding"),
		"floor arrival played the elevator ding")
	check(not played_events.has(&"home_door"),
		"floor arrival did not replay the old placeholder")
	check(world.floor_index == 1,
		"transition committed to the next floor (floor_index=%d)" % world.floor_index)
	print("      transition took %.0f ms" % elapsed)

	# Teardown must not leave the autoload bed running.
	world._set_elevator_ride_rumbling(true)
	await frames(2)
	check(manager.is_elevator_rumble_active(), "bed is live before scene teardown")
	world.queue_free()
	# Longer than the 0.15s teardown release in _exit_tree, so this asserts that
	# the release actually ran rather than that it is still fading.
	await wait(0.60)
	check(not manager.is_elevator_rumble_active(),
		"scene teardown releases the autoload-owned ride bed")


## Untyped on purpose: these helpers poke at script-only members of the dungeon
## (has_floor_badge, transition_phase, ...) which do not exist on the native
## Node base, so the value is kept fully dynamic.
func _make_world():
	var world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(2)
	return world
