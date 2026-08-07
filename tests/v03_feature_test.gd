extends Node

const CONFIG := preload("res://resources/demo_config.tres")
const RULES := preload("res://scripts/app/game_state_rules.gd")
const SETTLEMENT := preload("res://scripts/app/run_settlement.gd")

var failures: Array[String] = []


func _ready() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_test_early_wake_and_rest_day()
	await _test_combat_and_scenes()
	_test_configuration_and_sources()
	if failures.is_empty():
		print("V03_FEATURE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_early_wake_and_rest_day() -> void:
	_expect(RULES.calculate_early_wake_stress_gain(390.0, 420.0, false, CONFIG) == 0, "6:30 must not add stress")
	_expect(RULES.calculate_early_wake_stress_gain(360.0, 420.0, false, CONFIG) == 2, "6:00 must add 2 stress")
	_expect(RULES.calculate_early_wake_stress_gain(330.0, 420.0, false, CONFIG) == 4, "5:30 must add 4 stress")
	_expect(RULES.calculate_early_wake_stress_gain(240.0, 420.0, false, CONFIG) == 10, "early stress must cap at 10")
	_expect(RULES.calculate_early_wake_stress_gain(240.0, 540.0, true, CONFIG) == 0, "rest day must not add early-wake stress")
	var meta := {"ram":0,"balance":100,"stress_value":0,"calendar_day_id":5,"normal_attendance_workday_streak":0}
	var rest := SETTLEMENT.settle({"level":2,"wake_minutes":800.0,"dream_end_minutes":500.0,"alarm_minutes":540.0,"is_sunday":true}, meta, CONFIG)
	_expect(rest.attendance_status == "休息日" and rest.wage == 0, "Sunday settlement must skip attendance and wage")


func _test_combat_and_scenes() -> void:
	var player = preload("res://scenes/entities/dream_player.tscn").instantiate()
	add_child(player)
	player.configure_weapon("basic", CONFIG, {})
	player.configure_run_modifiers(false, CONFIG)
	player.critical_chance = 1.0
	var critical: Dictionary = player.calculate_player_damage(10.0)
	_expect(critical.damage == 15 and critical.is_critical, "critical damage must be 1.5x and marked")
	player.configure_aim(true, CONFIG)
	var enemy = preload("res://scenes/entities/basic_enemy.tscn").instantiate()
	add_child(enemy)
	enemy.global_position = player.global_position + Vector2(500, 0)
	player.call("_refresh_auto_aim_target")
	var constrained: Vector2 = player.get_constrained_aim_position()
	_expect(player.global_position.distance_to(constrained) <= player.get_effective_attack_range() + 0.1, "sleepwalk crosshair exceeded weapon range")
	_expect(enemy.auto_aim_locked, "auto-aim target outline was not enabled")
	var spawner = preload("res://scripts/dream/enemy_spawner.gd").new()
	spawner.config = CONFIG
	spawner.run_elapsed_seconds = 180.0
	var pool: Array[String] = spawner.get_unlocked_enemy_types()
	_expect("alarm_clock" in pool and "mailbox" in pool, "new enemies did not unlock at configured elapsed time")
	for path in ["res://scenes/entities/grenade_projectile.tscn", "res://scenes/entities/alarm_clock_enemy.tscn", "res://scenes/entities/mailbox_enemy.tscn", "res://scenes/ui/damage_number.tscn"]:
		var instance = load(path).instantiate()
		add_child(instance)
		_expect(is_instance_valid(instance), "could not instantiate " + path)
		instance.queue_free()
	var bedroom = preload("res://scenes/bedroom/bedroom.tscn").instantiate()
	_expect(bedroom.get_node("Layout/WeatherBackLayer") is Control, "weather layer is not full-screen Control")
	bedroom.persistent_state = {"stress_value":0,"daily_weather_type":"rain","online_messages":[]}
	add_child(bedroom)
	await get_tree().process_frame
	bedroom.queue_free()
	var menu = preload("res://scenes/ui/main_menu.tscn").instantiate()
	_expect(menu.has_node("FooterLink/Text"), "main menu footer link missing")
	add_child(menu)
	await get_tree().process_frame
	menu.queue_free()
	var results = preload("res://scenes/ui/results.tscn").instantiate()
	results.summary = {"attendance_status":"正常上班","dream_end_minutes":389.0,"alarm_minutes":420.0,"is_sunday":false}
	add_child(results)
	await get_tree().process_frame
	_expect(results.paragraphs == ["闹钟还没响", "今天又是一场噩梦"], "strict pre-6:30 result text mismatch")
	results.queue_free()
	var world = preload("res://scenes/dream/dream_world.tscn").instantiate()
	world.selected_weapon_id = "grenade"
	add_child(world)
	await get_tree().process_frame
	_expect(world.get_node("DamageNumberPool").get_child_count() == 32, "damage-number pool was not initialized")
	world.queue_free()
	await get_tree().process_frame
	player.queue_free()
	enemy.queue_free()


func _test_configuration_and_sources() -> void:
	_expect(CONFIG.grenade_attack_interval == 3.0 and CONFIG.grenade_explosion_radius == 150.0, "grenade defaults mismatch")
	_expect(CONFIG.alarm_enemy_unlock_time == 120.0 and CONFIG.mailbox_enemy_unlock_time == 180.0, "enemy unlock defaults mismatch")
	_expect(CONFIG.starvation_ending_required_days == 4, "starvation ending day count mismatch")
	var main_source := FileAccess.get_file_as_string("res://scripts/app/main.gd")
	_expect(main_source.contains("starvation_ending_unlocked") and main_source.contains("grenade_weapon_unlocked"), "save defaults for ending/grenade missing")
	var console_source := FileAccess.get_file_as_string("res://scripts/ui/debug_console.gd")
	_expect(console_source.contains("to_upper()") and console_source.contains("UNLOCK") and console_source.contains("MONEY"), "debug command normalization or commands missing")
	for path in ["res://assets/art/first_person/melatonin/female_right_hand_throw.png", "res://assets/art/first_person/melatonin/female_left_palm_open.png", "res://assets/enemies/alarm_clock/move.png", "res://assets/enemies/mailbox/move.png"]:
		_expect(ResourceLoader.exists(path), "generated temporary asset missing: " + path)
