extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + label)
	else:
		print("PASS: " + label)

func run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		push_error("TIMEOUT")
		quit(2)
	)

	print("=== Running Wilhelm Scream 2% Easter Egg Tests ===")

	var sfx := preload("res://scripts/audio/sfx_manager.gd")
	var config := preload("res://resources/demo_config.tres")

	# Test 1: Configuration default value is 0.02 (2%)
	check(is_equal_approx(config.wilhelm_scream_easter_egg_chance, 0.02), "Default wilhelm_scream_easter_egg_chance is 0.02 (2%)")

	# Test 2: SFXManager registration and playback
	var manager: Node = root.get_node_or_null("SFXManager")
	var played_events: Array[StringName] = []
	if manager != null:
		manager.connect("sfx_played", func(event_id: StringName) -> void:
			played_events.append(event_id)
		)
	var play_result := sfx.play_wilhelm_scream()
	check(play_result, "SFXManager.play_wilhelm_scream() returns true")
	check(played_events.has(&"wilhelm_scream"), "SFXManager emitted sfx_played for wilhelm_scream")

	# Test 3: Fall sequence with chance = 1.0 (Easter egg triggered)
	var world: Node = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	check(world.regenerate(42001), "Floor regenerates for fall test")

	world.config.wilhelm_scream_easter_egg_chance = 1.0

	var player: Node = world.player
	var fall_controller: Node = world.floor_root.get_node_or_null("ExteriorFalls")
	check(fall_controller != null, "ExteriorFalls controller exists")

	var sfx_events_triggered: Array[StringName] = []
	if manager != null:
		manager.connect("sfx_played", func(event_id: StringName) -> void:
			sfx_events_triggered.append(event_id)
		)

	fall_controller.begin_fall(player)
	check(player.get_meta(&"exterior_falling", false), "Player has exterior_falling meta")
	check(player.get_meta(&"exterior_fall_wilhelm", false), "Player has exterior_fall_wilhelm meta when chance=1.0")
	check(player.has_meta(&"wilhelm_scream_start_msec"), "Player has wilhelm_scream_start_msec meta")
	check(sfx_events_triggered.has(&"wilhelm_scream"), "Wilhelm scream was triggered on begin_fall")

	fall_controller._physics_process(0.55)
	check(player.dead, "Player is marked dead after falling")
	check(player.last_damage_source == &"exterior_fall", "Last damage source is exterior_fall")
	check(not sfx_events_triggered.has(&"death"), "Standard death sound was suppressed for Wilhelm scream")

	# Revive
	player.revive_for_floor_restart("")
	check(not player.dead, "Player revived successfully")
	check(not player.has_meta(&"exterior_falling"), "exterior_falling meta removed on revive")
	check(not player.has_meta(&"exterior_fall_wilhelm"), "exterior_fall_wilhelm meta removed on revive")
	check(not player.has_meta(&"wilhelm_scream_start_msec"), "wilhelm_scream_start_msec meta removed on revive")

	# Test 4: Fall sequence with chance = 0.0 (Standard fall, no Easter egg)
	world.config.wilhelm_scream_easter_egg_chance = 0.0
	fall_controller.falling.clear()
	var sfx_events_normal: Array[StringName] = []
	if manager != null:
		manager.connect("sfx_played", func(event_id: StringName) -> void:
			sfx_events_normal.append(event_id)
		)

	fall_controller.begin_fall(player)
	check(player.get_meta(&"exterior_falling", false), "Player has exterior_falling meta on normal fall")
	check(not player.get_meta(&"exterior_fall_wilhelm", false), "Player does NOT have exterior_fall_wilhelm meta when chance=0.0")
	check(not sfx_events_normal.has(&"wilhelm_scream"), "Wilhelm scream was NOT triggered when chance=0.0")

	fall_controller._physics_process(0.55)
	check(player.dead, "Player is dead after normal fall")
	check(sfx_events_normal.has(&"death"), "Standard death sound was played on normal fall")

	# Restore default config
	world.config.wilhelm_scream_easter_egg_chance = 0.02

	# Clean up
	world.free()
	await process_frame

	print("WILHELM_SCREAM_TEST checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
