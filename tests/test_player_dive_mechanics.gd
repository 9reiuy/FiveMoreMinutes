extends SceneTree

const PLAYER_SCENE := preload("res://scenes/entities/dream_player.tscn")
const TIME_CONTROLLER_SCENE := preload("res://scripts/dream/dream_time_controller.gd")
const CONFIG := preload("res://resources/demo_config.tres")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING PLAYER DIVE MECHANICS TEST (TASK-019) ===")

	# 1. Setup root scene with DreamTimeController and Player
	var root_node := Node2D.new()
	root.add_child(root_node)

	var time_controller := Node.new()
	time_controller.set_script(TIME_CONTROLLER_SCENE)
	root_node.add_child(time_controller)

	var player := PLAYER_SCENE.instantiate()
	root_node.add_child(player)

	for i in range(5):
		await process_frame

	# Ensure player has a weapon selected
	player.selected_weapon_id = "basic"
	player.set_attacking_enabled(true)
	player.dash_charges = player.max_dash_charges
	player.dash_cooldown_left = 0.0

	# ------------------------------------------------------------
	# TEST 1: Configuration properties
	# ------------------------------------------------------------
	print("\n--- TEST 1: Dive Configuration Properties ---")
	check(is_equal_approx(player.dive_duration, 0.35), "player.dive_duration is 0.35 (got %f)" % player.dive_duration)
	check(is_equal_approx(player.dive_bullet_time_scale, 0.2), "player.dive_bullet_time_scale is 0.2 (got %f)" % player.dive_bullet_time_scale)
	check(is_equal_approx(player.dive_airborne_ratio, 0.70), "player.dive_airborne_ratio is 0.70 (got %f)" % player.dive_airborne_ratio)
	check(is_equal_approx(player.dive_takeoff_angle_degrees, 45.0), "player.dive_takeoff_angle_degrees is 45.0 (got %f)" % player.dive_takeoff_angle_degrees)
	check(is_equal_approx(player.dive_peak_height, 18.0), "player.dive_peak_height is 18.0 (got %f)" % player.dive_peak_height)

	# ------------------------------------------------------------
	# TEST 2: Dive Start & Bullet Time Initiation
	# ------------------------------------------------------------
	print("\n--- TEST 2: Dive Start & Bullet Time Initiation ---")
	# Trigger dive to the right
	player.call("_start_dash", Vector2.RIGHT)
	check(player.dashing == true, "Player is dashing after _start_dash")
	check(player.is_diving == true, "Player is_diving is true")
	check(player.dive_bullet_time_active == true, "player.dive_bullet_time_active is true")
	check(is_equal_approx(Engine.time_scale, 0.2), "Engine.time_scale is 0.2 (got %f)" % Engine.time_scale)
	check(player.held_weapon_sprite.visible == true, "Held weapon sprite is visible at dive start")

	# ------------------------------------------------------------
	# TEST 3: Airborne Dive Phase (45 deg angle, peak height, mid-air shooting)
	# ------------------------------------------------------------
	print("\n--- TEST 3: Airborne Dive Phase Mechanics ---")
	# Advance dive to ~35% of total duration (apex of airborne phase, dive_prog = 0.5)
	var mid_dive_time: float = float(player.get("active_dash_duration")) * 0.35
	player.dash_elapsed = mid_dive_time
	# Call _update_dash with small delta to apply state at this progress
	player.call("_update_dash", 0.0)

	check(player.is_dive_airborne() == true, "player.is_dive_airborne() is true during Phase 1")
	check(player.knockback_height > 15.0, "player.knockback_height is near peak (> 15.0, got %f)" % player.knockback_height)
	var expected_angle := deg_to_rad(45.0)
	check(absf(player.visual.rotation - expected_angle) < 0.05, "player.visual.rotation is ~45 deg (got %f rad, expected %f rad)" % [player.visual.rotation, expected_angle])
	check(player.held_weapon_sprite.visible == true, "Held weapon sprite remains visible in mid-air")
	check(is_equal_approx(Engine.time_scale, 0.2), "Engine.time_scale remains 0.2 during airborne phase")

	# Test shooting permission during airborne phase
	player.set_meta(&"force_weapon_attack", true)
	check(player.should_trigger_weapon_attack() == true, "should_trigger_weapon_attack() returns true during airborne dive")

	# ------------------------------------------------------------
	# TEST 4: Landing Roll Phase (touchdown, time restored, weapon hidden, roll rotation)
	# ------------------------------------------------------------
	print("\n--- TEST 4: Landing Roll Phase Mechanics ---")
	# Advance dive past 70% to 85% (mid-roll)
	var roll_time: float = float(player.get("active_dash_duration")) * 0.85
	player.dash_elapsed = roll_time
	player.call("_update_dash", 0.0)

	check(player.is_dive_airborne() == false, "player.is_dive_airborne() is false during Phase 2")
	check(is_equal_approx(player.knockback_height, 0.0), "player.knockback_height is 0.0 during landing roll (got %f)" % player.knockback_height)
	check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is restored to 1.0 on landing (got %f)" % Engine.time_scale)
	check(player.held_weapon_sprite.visible == false, "Held weapon sprite is hidden during landing roll")
	check(player.should_trigger_weapon_attack() == false, "should_trigger_weapon_attack() is false during landing roll even with attack pressed")
	check(player.visual.rotation > expected_angle, "player.visual.rotation has rotated past 45 deg during roll (got %f rad)" % player.visual.rotation)
	player.remove_meta(&"force_weapon_attack")

	# ------------------------------------------------------------
	# TEST 5: Dive Completion & Clean Reset
	# ------------------------------------------------------------
	print("\n--- TEST 5: Dive Completion & Clean Reset ---")
	player.dash_elapsed = player.active_dash_duration
	player.call("_finish_dash_path")

	check(player.dashing == false, "player.dashing is false after finish")
	check(player.is_diving == false, "player.is_diving is false after finish")
	check(is_equal_approx(player.visual.rotation, 0.0), "player.visual.rotation is reset to 0.0 (got %f)" % player.visual.rotation)
	check(is_equal_approx(player.knockback_height, 0.0), "player.knockback_height is 0.0")
	check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	check(player.held_weapon_sprite.visible == true, "Held weapon sprite restored after finish")

	# ------------------------------------------------------------
	# TEST 6: Interruption / cancel_dash Safety
	# ------------------------------------------------------------
	print("\n--- TEST 6: Interruption / cancel_dash Safety ---")
	# Reset dash cooldown and charges for second dive
	player.dash_charges = player.max_dash_charges
	player.dash_cooldown_left = 0.0
	player.call("_start_dash", Vector2.LEFT)
	check(player.dashing == true, "Second dive started")
	check(is_equal_approx(Engine.time_scale, 0.2), "Engine.time_scale is 0.2 on second dive")
	player.dash_elapsed = player.active_dash_duration * 0.4
	player.call("_update_dash", 0.0)
	check(player.knockback_height > 0.0, "Airborne height active before cancel")

	player.cancel_dash()
	check(player.dashing == false, "player.dashing is false after cancel_dash")
	check(player.is_diving == false, "player.is_diving is false after cancel_dash")
	check(is_equal_approx(player.visual.rotation, 0.0), "player.visual.rotation reset to 0.0 after cancel_dash")
	check(is_equal_approx(player.knockback_height, 0.0), "player.knockback_height reset to 0.0 after cancel_dash")
	check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale restored to 1.0 after cancel_dash")

	print("\n==================================================")
	if failures.is_empty():
		print("ALL DIVE MECHANICS TESTS PASSED!")
		quit(0)
	else:
		print("FAILED with %d errors:" % failures.size())
		for f in failures:
			print(" - ", f)
		quit(1)
