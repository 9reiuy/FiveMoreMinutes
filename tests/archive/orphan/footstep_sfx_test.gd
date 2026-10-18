extends SceneTree

## Footstep SFX coverage: the concrete random group, the gait-phase mapping and
## the actual trigger path the player drives.
##
## The gait contract this test locks down: one footfall per π of walk phase, so
## a full TAU cycle contains exactly two steps.  Everything else (speed-relative
## density, stopping when the phase resets) follows from that.

const SFX_SCRIPT := preload("res://scripts/audio/sfx_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/entities/dream_player.gd")

const EXPECTED_CLIP_PATHS := [
	"res://sfx/footsteps/concrete/footstep_concrete_000.ogg",
	"res://sfx/footsteps/concrete/footstep_concrete_001.ogg",
	"res://sfx/footsteps/concrete/footstep_concrete_002.ogg",
	"res://sfx/footsteps/concrete/footstep_concrete_003.ogg",
	"res://sfx/footsteps/concrete/footstep_concrete_004.ogg",
]

## Expected step counts for a ten-cycle phase sweep, including the step that
## fires at the very start of the walk.  Ten cycles is a common multiple of both
## intervals, so the arithmetic stays exact.
const EXPECTED_STEPS_OVER_TEN_CYCLES := {1: 21, 2: 11}

var failures: Array[String] = []
var played_events: Array[StringName] = []


func _initialize() -> void:
	if root.get_node_or_null("SFXManager") == null:
		var manager := SFX_SCRIPT.new()
		manager.name = "SFXManager"
		root.add_child(manager)
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node("SFXManager")
	manager.sfx_played.connect(_on_sfx_played)
	_test_group_registration(manager)
	_test_clips_are_distinct(manager)
	_test_play_emits_event(manager)
	_test_gait_phase_mapping()
	_test_gait_step_count()
	await _test_player_instance_drives_group(manager)
	manager.queue_free()
	await process_frame
	if failures.is_empty():
		print("FOOTSTEP SFX TEST PASSED: random group -> gait phase -> player trigger")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _on_sfx_played(event_id: StringName) -> void:
	played_events.append(event_id)


func _test_group_registration(manager: Node) -> void:
	_assert(manager.players.has(&"footstep"), "Missing managed player: footstep")
	var player: AudioStreamPlayer = manager.players.get(&"footstep") as AudioStreamPlayer
	if player == null:
		return
	_assert(player.bus == &"Characters", "Footstep must ride the Characters bus")
	_assert(absf(player.volume_db - -18.0) < 0.01, "Footstep trim drifted from -18 dB")
	# A 4.4 steps/second gait outruns a single voice, so the tail of one footfall
	# must be allowed to overlap the next.
	_assert(player.max_polyphony >= 4, "Footstep needs polyphony for overlapping steps")
	var randomizer: AudioStreamRandomizer = player.stream as AudioStreamRandomizer
	_assert(randomizer != null, "Footstep stream must be an AudioStreamRandomizer group")
	if randomizer == null:
		return
	_assert(
		randomizer.streams_count == EXPECTED_CLIP_PATHS.size(),
		"Expected %d clips in the group, found %d" % [
			EXPECTED_CLIP_PATHS.size(), randomizer.streams_count
		]
	)
	_assert(
		randomizer.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS,
		"Footstep group must pick clips in random order without immediate repeats"
	)
	_assert(
		absf(randomizer.random_pitch - 1.05) < 0.001,
		"Footstep group must carry the ±5%% pitch jitter, got %f" % randomizer.random_pitch
	)
	var registered_paths: Array = []
	for index in range(randomizer.streams_count):
		var clip: AudioStream = randomizer.get_stream(index)
		_assert(clip != null, "Footstep clip %d is empty" % index)
		if clip != null:
			registered_paths.append(clip.resource_path)
	for expected_path in EXPECTED_CLIP_PATHS:
		_assert(
			registered_paths.has(expected_path),
			"Footstep group is missing clip: " + expected_path
		)


func _test_clips_are_distinct(manager: Node) -> void:
	# "Random order" is worthless if the group is five copies of one recording.
	var player: AudioStreamPlayer = manager.players.get(&"footstep") as AudioStreamPlayer
	var randomizer: AudioStreamRandomizer = player.stream as AudioStreamRandomizer if player != null else null
	if randomizer == null:
		return
	var seen: Array = []
	for index in range(randomizer.streams_count):
		var clip: AudioStream = randomizer.get_stream(index)
		if clip == null:
			continue
		_assert(
			not seen.has(clip.resource_path),
			"Footstep group repeats the same recording: " + clip.resource_path
		)
		seen.append(clip.resource_path)


func _test_play_emits_event(manager: Node) -> void:
	played_events.clear()
	var played: bool = manager.play(&"footstep")
	_assert(played, "Playing the footstep group should report success")
	_assert(
		played_events.has(&"footstep"),
		"Playing the footstep group must emit sfx_played for observers"
	)
	manager.stop(&"footstep")


func _test_gait_phase_mapping() -> void:
	_assert(PLAYER_SCRIPT.footstep_phase_index(0.0, 1) == 0, "Phase 0 should map to step index 0")
	_assert(PLAYER_SCRIPT.footstep_phase_index(PI * 0.99, 1) == 0, "Phase below π should stay on index 0")
	_assert(PLAYER_SCRIPT.footstep_phase_index(PI, 1) == 1, "Phase π should advance to step index 1")
	_assert(PLAYER_SCRIPT.footstep_phase_index(PI * 1.99, 1) == 1, "Phase below 2π should stay on index 1")
	_assert(PLAYER_SCRIPT.footstep_phase_index(PI * 2.0, 1) == 2, "Phase 2π should advance to step index 2")
	# A larger interval folds several steps into one: the index then only moves
	# once per whole gait cycle.
	_assert(PLAYER_SCRIPT.footstep_phase_index(TAU - 0.01, 2) == 0, "Interval 2 should hold index 0 for a full cycle")
	_assert(PLAYER_SCRIPT.footstep_phase_index(TAU, 2) == 1, "Interval 2 should advance once per cycle")
	# Defensive clamp: a zero or negative interval must behave like 1 rather
	# than dividing by zero.
	_assert(PLAYER_SCRIPT.footstep_phase_index(PI, 0) == 1, "Interval 0 should clamp to 1")
	_assert(PLAYER_SCRIPT.footstep_phase_index(PI, -3) == 1, "Negative interval should clamp to 1")


func _test_gait_step_count() -> void:
	# Sweep the walk phase over ten cycles and count how often a step would fire.
	# Sampling far finer than π proves no index is skipped between frames.
	var cycles := 10
	var samples := 4000
	var phase_step := (TAU * cycles) / float(samples)
	for interval in EXPECTED_STEPS_OVER_TEN_CYCLES:
		var phase := 0.0
		var last_index := -1
		var step_count := 0
		for _sample in range(samples + 1):
			var index: int = PLAYER_SCRIPT.footstep_phase_index(phase, interval)
			if index != last_index:
				last_index = index
				step_count += 1
			phase += phase_step
		var expected: int = EXPECTED_STEPS_OVER_TEN_CYCLES[interval]
		_assert(
			step_count == expected,
			"Interval %d over %d cycles: expected %d steps, got %d" % [
				interval, cycles, expected, step_count
			]
		)


func _test_player_instance_drives_group(manager: Node) -> void:
	# End to end: a real DreamPlayer instance must actually reach the random
	# group.  The mapping tests above prove the arithmetic; this proves the
	# wiring, including that a step only fires once per landing.
	var scene: PackedScene = load("res://scenes/entities/dream_player.tscn")
	_assert(scene != null, "Could not load dream_player.tscn")
	if scene == null:
		return
	var player: Node = scene.instantiate()
	if player == null:
		_assert(false, "Could not instantiate dream_player.tscn")
		return
	root.add_child(player)
	await process_frame

	played_events.clear()
	# Mid-stride: the phase has not yet crossed π, so no foot has landed.
	player.set("walk_animation_time", PI * 0.9)
	player.set("last_footstep_phase_index", 0)
	player.call("_play_footsteps_for_gait")
	_assert(played_events.is_empty(), "A footstep fired mid-stride, before the foot landed")

	# Crossing π is exactly one foot landing.
	player.set("walk_animation_time", PI * 1.05)
	player.call("_play_footsteps_for_gait")
	_assert(played_events.has(&"footstep"), "Crossing π must fire exactly one footstep")
	var fired_after_first_step: int = played_events.size()
	_assert(fired_after_first_step == 1, "Expected one footstep after one landing, got %d" % fired_after_first_step)

	# Still the same step: holding this phase must not re-trigger.
	player.set("walk_animation_time", PI * 1.2)
	player.call("_play_footsteps_for_gait")
	_assert(
		played_events.size() == fired_after_first_step,
		"A single landing fired more than once"
	)

	# The reset path is what makes walking resume correctly after a stop.  Two
	# landings inside the 0.10s anti-machine-gun floor are deliberately folded
	# into one, so real wall-clock time has to pass before a second sound is
	# due.  A frame await is not enough here: this SceneTree harness has no
	# frame clock driving SceneTreeTimer, but OS.delay_msec is real time.
	OS.delay_msec(120)
	player.set("last_footstep_phase_index", -1)
	player.set("walk_animation_time", PI * 2.05)
	player.call("_play_footsteps_for_gait")
	_assert(
		played_events.size() == fired_after_first_step + 1,
		"The next landing after a phase reset did not fire"
	)
	_assert(
		int(player.get("last_footstep_phase_index")) == 2,
		"The reset path must re-arm the step index"
	)

	player.queue_free()
