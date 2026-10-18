extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[TEST] Starting Tarot Audio Pipeline tests...")
	var success := true

	success = test_streams_registration() and success
	success = test_event_buses_and_intervals() and success
	success = test_sfx_manager_instance_and_playback() and success

	if success:
		print("[TEST] ALL TAROT AUDIO TESTS PASSED!")
		quit(0)
	else:
		push_error("[TEST] SOME TAROT AUDIO TESTS FAILED!")
		quit(1)


func test_streams_registration() -> bool:
	print("--- Testing SFXManager.STREAMS Registration ---")
	var sfx_script = load("res://scripts/audio/sfx_manager.gd")
	assert(sfx_script != null, "SFXManager script must load")

	var streams = sfx_script.STREAMS
	assert(streams is Dictionary, "STREAMS must be a Dictionary")

	var expected_keys := [&"tarot_shuffle", &"tarot_deal", &"tarot_flip", &"tarot_select"]
	for key in expected_keys:
		assert(streams.has(key), "STREAMS must contain %s" % key)
		var stream = streams[key]
		assert(stream != null, "Stream for %s must not be null" % key)
		assert(stream is AudioStreamWAV, "Stream for %s must be AudioStreamWAV" % key)
		var wav := stream as AudioStreamWAV
		assert(wav.get_length() > 0.0, "Stream length for %s must be > 0 (got %f)" % [key, wav.get_length()])
		print("  [OK] %s: loaded successfully, duration = %.3fs" % [key, wav.get_length()])

	print("[PASS] SFXManager.STREAMS registration test passed.")
	return true


func test_event_buses_and_intervals() -> bool:
	print("--- Testing EVENT_BUSES and EVENT_MIN_INTERVALS ---")
	var sfx_script = load("res://scripts/audio/sfx_manager.gd")
	var buses = sfx_script.EVENT_BUSES
	var intervals = sfx_script.EVENT_MIN_INTERVALS

	var expected_intervals := {
		&"tarot_shuffle": 0.2,
		&"tarot_deal": 0.05,
		&"tarot_flip": 0.05,
		&"tarot_select": 0.2,
	}

	for key in expected_intervals.keys():
		assert(buses.has(key), "EVENT_BUSES must contain %s" % key)
		assert(buses[key] == &"UI", "EVENT_BUSES[%s] must be &\"UI\" (got %s)" % [key, buses[key]])
		assert(intervals.has(key), "EVENT_MIN_INTERVALS must contain %s" % key)
		var expected_val: float = expected_intervals[key]
		assert(abs(float(intervals[key]) - expected_val) < 0.001, "EVENT_MIN_INTERVALS[%s] should be %f (got %f)" % [key, expected_val, intervals[key]])
		print("  [OK] %s: Bus = %s, Interval = %.2fs" % [key, buses[key], intervals[key]])

	print("[PASS] EVENT_BUSES and EVENT_MIN_INTERVALS test passed.")
	return true


func test_sfx_manager_instance_and_playback() -> bool:
	print("--- Testing SFXManager Runtime Instance & Playback ---")
	var sfx_script = load("res://scripts/audio/sfx_manager.gd")
	var manager: Node = sfx_script.new()
	manager.name = "SFXManager"
	root.add_child(manager)

	# Verify players were created for tarot events
	var expected_keys := [&"tarot_shuffle", &"tarot_deal", &"tarot_flip", &"tarot_select"]
	for key in expected_keys:
		assert(manager.players.has(key), "manager.players must have %s" % key)
		var player: AudioStreamPlayer = manager.players[key]
		assert(player != null, "player for %s must not be null" % key)
		assert(player.bus == &"UI", "player bus for %s must be UI" % key)

	# Verify pitch randomization on tarot_flip
	var pitches: Array[float] = []
	for i in range(10):
		# Reset interval tracking for test
		manager.last_event_play_msec.erase(&"tarot_flip")
		var played = manager.play(&"tarot_flip")
		assert(played, "play(&\"tarot_flip\") should return true")
		var player: AudioStreamPlayer = manager.players[&"tarot_flip"]
		var p := player.pitch_scale
		assert(p >= 0.959 and p <= 1.041, "tarot_flip pitch_scale %f must be within [0.96, 1.04]" % p)
		pitches.append(p)

	# Check that pitches varied
	var min_p = pitches.min()
	var max_p = pitches.max()
	assert(max_p > min_p, "tarot_flip pitches must vary over multiple calls")
	print("  [OK] tarot_flip pitch randomization verified: range [%.4f, %.4f]" % [min_p, max_p])

	# Test other tarot events play cleanly
	for key in [&"tarot_shuffle", &"tarot_deal", &"tarot_select"]:
		manager.last_event_play_msec.erase(key)
		var played = manager.play(key)
		assert(played, "play(%s) should return true" % key)
		print("  [OK] played event: %s" % key)

	manager.queue_free()
	print("[PASS] SFXManager runtime instance & playback test passed.")
	return true
