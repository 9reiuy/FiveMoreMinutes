extends SceneTree

const SFX_SCRIPT := preload("res://scripts/audio/sfx_manager.gd")
const ENEMY_KILL_PATH := "res://sfx/enemy_kill.mp3"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Starting enemy_kill SFX verification...")
	var manager: Node = null
	if root.get_node_or_null("SFXManager") == null:
		manager = SFX_SCRIPT.new()
		manager.name = "SFXManager"
		root.add_child(manager)
	else:
		manager = root.get_node("SFXManager")

	_test_kill_resource(manager)
	_test_kill_playback(manager)

	if manager != null and is_instance_valid(manager):
		manager.queue_free()

	await process_frame

	if failures.is_empty():
		print("TEST_ENEMY_KILL_SFX_PASSED: enemy_kill SFX fully validated.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		printerr("TEST_ENEMY_KILL_SFX_FAILED with " + str(failures.size()) + " failures.")
		quit(1)

func _test_kill_resource(manager: Node) -> void:
	var stream = load(ENEMY_KILL_PATH)
	_assert(stream != null, "Could not load res://sfx/enemy_kill.mp3")
	_assert(stream is AudioStreamMP3, "enemy_kill.mp3 is not AudioStreamMP3: " + str(stream))
	if stream is AudioStreamMP3:
		_assert(stream.get_length() > 2.0, "enemy_kill.mp3 length is unexpectedly short: " + str(stream.get_length()))

	_assert(manager.STREAMS.has(&"enemy_kill"), "SFXManager.STREAMS missing enemy_kill")
	_assert(not manager.GENERATED_EVENTS.has(&"enemy_kill"), "enemy_kill should not be in GENERATED_EVENTS")
	_assert(manager.EVENT_BUSES.get(&"enemy_kill") == &"Characters", "enemy_kill bus should be Characters")
	_assert(abs(manager.EVENT_MIN_INTERVALS.get(&"enemy_kill", 0.0) - 0.04) < 0.001, "enemy_kill min interval should be 0.04")

func _test_kill_playback(manager: Node) -> void:
	_assert(manager.players.has(&"enemy_kill"), "manager.players does not have enemy_kill")
	var player: AudioStreamPlayer = manager.players.get(&"enemy_kill")
	_assert(player != null, "player for enemy_kill is null")

	var played_first: bool = manager.play_event(&"enemy_kill")
	_assert(played_first, "First play_event(&'enemy_kill') should succeed")

	var first_pitch: float = player.pitch_scale
	_assert(first_pitch >= 0.969 and first_pitch <= 1.031, "Pitch scale outside [0.97, 1.03]: " + str(first_pitch))

	# Immediate replay without waiting should be throttled by 0.04s interval
	var played_immediate: bool = manager.play_event(&"enemy_kill")
	_assert(not played_immediate, "Immediate duplicate play_event should be throttled by EVENT_MIN_INTERVALS")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("ASSERTION FAILED: ", message)
