extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")
const DREAM := preload("res://scenes/dream/dream_world.tscn")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const LARGE := preload("res://scenes/entities/large_correction_tape_enemy.tscn")
const CORRECTION := preload("res://scenes/entities/correction_tape_enemy.tscn")
const RESULTS := preload("res://scenes/ui/results.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "confirm", "restart_demo", "dash", "skill_menu"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_test_config_and_week_rules()
	await _test_phone_grid_and_permanent_store()
	await _test_permanent_runtime_effects()
	await _test_upgrade_mouse_and_tab_menu()
	await _test_enemy_unlocks_elite_and_reward()
	_test_upgrade_catalog()
	await _test_player_run_skills()
	await _test_drift_and_rapid_eye()
	await _test_sunday_results()
	if failures.is_empty():
		print("STAGE 2 TEST PASSED: phone grid -> weekdays -> permanent upgrades -> timed enemies -> elite -> rarity cards -> six run skills")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_config_and_week_rules() -> void:
	_assert(CONFIG.correction_unlock_seconds == 60.0 and CONFIG.stapler_unlock_seconds == 120.0, "Enemy unlock defaults are incorrect")
	_assert(CONFIG.large_correction_unlock_seconds == 180.0, "Elite unlock default is not 180 seconds")
	_assert(CONFIG.correction_trigger_distance == 150.0 and CONFIG.correction_dash_distance == 200.0, "Correction tape defaults are incorrect")
	_assert(CONFIG.permanent_upgrade_prices == PackedInt32Array([1, 3, 5, 8, 10]), "Permanent upgrade price curve is incorrect")
	var meta := {"balance": 1325, "ram": 0, "unemployed": false}
	var result := RunSettlement.settle({"wake_minutes": 700.0, "total_experience": 100, "is_sunday": true}, meta, CONFIG)
	_assert(result.attendance_status == "休息日" and result.wage == 0 and meta.balance == 1325, "Sunday incorrectly applied attendance or wages")
	_assert(result.run_ram == 1 and meta.ram == 1, "Sunday did not settle RAM")


func _test_phone_grid_and_permanent_store() -> void:
	var phone := PHONE.instantiate()
	var phone_config: DemoConfig = CONFIG.duplicate(true)
	phone_config.phone_animation_seconds = 0.01
	phone_config.phone_fingerprint_animation_seconds = 0.01
	phone.config = phone_config
	var meta := {
		"balance": 1325, "ram": 108, "weekday_index": 0,
		"melatonin_inventory": 0,
		"permanent_upgrades": {"visual_cortex":0, "brainstem":0, "hippocampus":0, "prefrontal":0}
	}
	phone.configure_state(meta)
	root.add_child(phone)
	await process_frame
	_assert(phone.size == Vector2(150, 270), "Phone did not restore its original 150x270 size")
	_assert(phone._app_rect(3).end.y <= phone.size.y and phone._app_rect(0).position.y >= phone.config.phone_upper_collapse_height, "The 2x2 application grid is not confined to the lower half")
	_assert(phone.APP_NAMES.size() == 4 and phone.APP_NAMES[0][0] == "在线！™" and phone.APP_NAMES[1][0] == "眠网™", "Application names are incomplete")
	phone.set_bedroom_time(1265.0)
	_assert(phone.bedroom_time_minutes == 1265.0, "Phone did not accept the bedroom clock source")
	phone._gui_input(_mouse_click(Vector2(75, 12)))
	await create_timer(0.2).timeout
	_assert(phone.state == phone.PhoneState.EXPANDED, "Phone did not finish its expand animation")
	phone.state = phone.PhoneState.EXPANDED
	phone.interaction_locked = false
	phone.screen_state = phone.ScreenState.HOME
	phone._gui_input(_mouse_click(phone._app_rect(0).get_center()))
	_assert(phone.screen_state == phone.ScreenState.ONLINE, "Phone app did not open from the 2x2 grid")
	phone._gui_input(_mouse_click(phone.BACK_BUTTON.get_center()))
	phone._gui_input(_mouse_click(Vector2(75, 78)))
	await create_timer(0.2).timeout
	_assert(phone.state == phone.PhoneState.COLLAPSED, "Phone upper half did not collapse the expanded phone")
	for id in phone.UPGRADE_IDS:
		for _level in 5:
			phone._purchase_permanent_upgrade(id)
	_assert(meta.ram == 0, "Four max-level permanent upgrades did not cost 27 RAM each")
	for id in phone.UPGRADE_IDS:
		_assert(int(meta.permanent_upgrades[id]) == 5, "A permanent upgrade did not reach level 5")
	phone._purchase_permanent_upgrade("visual_cortex")
	_assert(meta.ram == 0 and int(meta.permanent_upgrades.visual_cortex) == 5, "Maxed permanent upgrade accepted another purchase")
	phone.queue_free()
	await process_frame


func _test_upgrade_mouse_and_tab_menu() -> void:
	var dream := DREAM.instantiate()
	root.add_child(dream)
	await process_frame
	dream.spawner.running = false
	dream._on_experience_collected(20)
	_assert(dream.upgrade_panel.visible and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not dream.crosshair.visible, "Upgrade did not enter menu mouse mode")
	var motion := InputEventMouseMotion.new()
	motion.position = dream.upgrade_panel.CARD_RECTS[0].get_center()
	dream.upgrade_panel._gui_input(motion)
	_assert(dream.upgrade_panel.hovered_index == 0, "Upgrade card did not respond to mouse hover")
	dream.upgrade_panel._gui_input(_mouse_click(dream.upgrade_panel.CARD_RECTS[0].get_center()))
	await process_frame
	_assert(not dream.upgrade_panel.visible and not paused and dream.crosshair.visible, "Upgrade selection did not restore dream input")
	dream.skill_levels = {"range_boost":1}
	dream.player.apply_range_upgrade(CONFIG.normal_range_upgrade_pixels)
	var event := InputEventAction.new()
	event.action = "skill_menu"
	event.pressed = true
	dream._unhandled_input(event)
	_assert(dream.skills_menu.visible and paused and dream.skills_menu.cards.size() == 1, "Tab menu did not open with an acquired skill")
	var range_row: Dictionary = dream.skills_menu.stats[3]
	_assert(str(range_row.cards) != "+0px", "Tab menu did not separate card stat contribution")
	dream.skills_menu._unhandled_input(event)
	await process_frame
	_assert(not dream.skills_menu.visible and not paused and dream.crosshair.visible, "Tab menu did not close and restore aiming")
	dream.queue_free()
	await process_frame


func _test_permanent_runtime_effects() -> void:
	var dream := DREAM.instantiate()
	dream.permanent_upgrades = {"visual_cortex":5, "brainstem":5, "hippocampus":5, "prefrontal":5}
	root.add_child(dream)
	await process_frame
	dream.spawner.running = false
	_assert(dream.player.maximum_health == 200.0 and dream.player.current_health == 200.0, "Hippocampus did not grant full upgraded starting health")
	_assert(dream.player.auto_weapon.attack_range == CONFIG.basic_weapon_range + 250.0, "Visual cortex did not increase basic range")
	_assert(dream.player.beam_weapon.attack_range == CONFIG.beam_range + 250.0, "Visual cortex did not increase beam range")
	_assert(is_equal_approx(dream.player.beam_weapon.attack_interval, 1.0), "Prefrontal level 5 did not produce a 1.0 second beam interval")
	dream._on_experience_collected(5)
	_assert(dream.experience == 10 and dream.total_experience_earned == 10, "Brainstem level 5 did not double accumulated experience")
	dream.queue_free()
	await process_frame


func _test_enemy_unlocks_elite_and_reward() -> void:
	var dream := DREAM.instantiate()
	var config: DemoConfig = CONFIG.duplicate(true)
	config.large_correction_unlock_seconds = 0.04
	config.enemy_initial_spawn_interval = 100.0
	config.enemy_minimum_spawn_interval = 100.0
	dream.config = config
	dream.get_node("DreamClock").config = config
	dream.get_node("EnemySpawner").config = config
	dream.get_node("UILayer/WakeOverlay").config = config
	root.add_child(dream)
	await process_frame
	dream.player.set_attacking_enabled(false)
	dream.spawner.set_run_elapsed(59.9)
	_assert(dream.spawner.get_unlocked_enemy_types() == ["basic"], "Correction tape unlocked before 60 seconds")
	dream.spawner.set_run_elapsed(60.0)
	_assert(dream.spawner.get_unlocked_enemy_types().has("correction") and not dream.spawner.get_unlocked_enemy_types().has("stapler"), "Correction unlock boundary failed")
	dream.spawner.set_run_elapsed(120.0)
	_assert(dream.spawner.get_unlocked_enemy_types().has("stapler"), "Stapler unlock boundary failed")
	await create_timer(0.09).timeout
	var elite: Node = dream.enemy_container.get_node_or_null("LargeCorrectionTapeEnemy")
	_assert(elite != null and dream.elite_spawned, "Large correction tape did not force-spawn once")
	if elite != null:
		_assert(elite.current_health == config.base_enemy_health * config.large_correction_health_multiplier, "Elite health is not 10x the normal correction health")
		elite.take_damage(99999.0)
		await process_frame
		_assert(dream.experience == 10, "Elite reward was not half of the current level requirement")
	var count_before: int = dream.enemy_container.get_children().filter(func(node): return node.name.begins_with("LargeCorrectionTapeEnemy")).size()
	dream.run_elapsed_seconds = 999.0
	await process_frame
	var count_after: int = dream.enemy_container.get_children().filter(func(node): return node.name.begins_with("LargeCorrectionTapeEnemy")).size()
	_assert(count_before == count_after, "Elite spawned more than once")

	var triple := LARGE.instantiate()
	config.large_correction_charge_seconds = 0.01
	config.large_correction_dash_distance = 2.0
	config.large_correction_dash_speed = 1000.0
	config.large_correction_dash_interval = 0.01
	config.large_correction_recovery_seconds = 0.3
	triple.configure(dream.player, 999.0, 0.0, dream.ARENA_BOUNDS, 0.0, 1.0)
	triple.configure_special(config)
	triple.position = dream.player.position + Vector2(40, 0)
	dream.enemy_container.add_child(triple)
	await create_timer(0.16).timeout
	_assert(triple.completed_dashes == 3, "Large correction tape did not complete three dashes")
	dream.player.position = Vector2(590, 300)
	await create_timer(0.32).timeout
	_assert(triple.state == triple.State.TRACKING, "Large correction tape did not return to tracking after recovery")

	var correction := CORRECTION.instantiate()
	config.correction_charge_seconds = 0.01
	config.correction_dash_distance = 2.0
	config.correction_dash_speed = 1000.0
	config.correction_recovery_seconds = 0.02
	config.correction_dash_max_seconds = 0.05
	correction.configure(dream.player, 999.0, 0.0, dream.ARENA_BOUNDS, 0.0, 1.0, config)
	correction.configure_special(config)
	correction.position = dream.player.position + Vector2(-40, 0)
	dream.enemy_container.add_child(correction)
	await create_timer(0.04).timeout
	dream.player.position = Vector2(40, 70)
	await create_timer(0.06).timeout
	_assert(correction.state == correction.State.TRACKING, "Normal correction tape did not return to tracking after its dash")
	var state_before: int = correction.state
	correction.take_damage(1.0, dream.player.position)
	await process_frame
	_assert(correction.hit_flash_left > 0.0 and correction.state == state_before, "Enemy hit feedback did not play or altered the AI state")
	dream.queue_free()
	await process_frame


func _test_upgrade_catalog() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7451
	_assert(CONFIG.rarity_blue_probability == 0.88 and CONFIG.rarity_purple_probability == 0.10 and CONFIG.rarity_gold_probability == 0.02, "Rarity configuration changed")
	var options := UpgradeCatalog.generate_options(CONFIG, {}, random, 3)
	var families: Dictionary = {}
	for option in options:
		families[option.family] = true
	_assert(options.size() == 3 and families.size() == 3, "Upgrade draw did not return three different skill families")
	var capped := {"sleep_paralysis":3, "sleep_spindle":3, "hypnic_jerk":2, "consciousness_drift":2, "rapid_eye":1, "dissociation":1}
	for option in UpgradeCatalog.generate_options(CONFIG, capped, random, 3):
		_assert(not capped.has(option.family), "A capped or replaced skill remained in the draw pool")


func _test_player_run_skills() -> void:
	var player := PLAYER.instantiate()
	root.add_child(player)
	await process_frame
	player.configure_weapon("basic", CONFIG)
	player.configure_feedback_audio(CONFIG)
	player.current_health = 50.0
	player.configure_sleep_paralysis(0.01, 5.0)
	player.still_elapsed = 0.02
	player.heal_tick_accumulator = 0.99
	player._update_sleep_paralysis(0.02, Vector2.ZERO)
	_assert(player.current_health == 55.0, "Sleep paralysis did not heal after the configured stillness")
	player.configure_sleep_spindle(0.02)
	player._update_sleep_spindle(0.03)
	_assert(player.has_shield, "Sleep spindle did not create a shield")
	var hp: float = player.current_health
	player.receive_damage(999.0)
	_assert(player.current_health == hp and not player.has_shield, "Sleep spindle did not block exactly one hit")
	player.add_dash_charge_capacity(CONFIG)
	player.add_dash_charge_capacity(CONFIG)
	player.add_dash_charge_capacity(CONFIG)
	_assert(player.max_dash_charges == 3 and player.dash_charges == 3, "Hypnic jerk exceeded or failed to reach three dash charges")
	player.enable_dissociation(CONFIG)
	player.invulnerability_left = 0.0
	player.current_health = 5.0
	player.receive_damage(100.0)
	_assert(not player.dead and player.current_health == 30.0 and not player.dissociation_ready, "Dissociation did not prevent the first fatal hit")
	player.invulnerability_left = 0.0
	player.receive_damage(100.0)
	_assert(player.dead, "Dissociation prevented more than one death")
	player.queue_free()
	await process_frame


func _test_drift_and_rapid_eye() -> void:
	var dream := DREAM.instantiate()
	var config: DemoConfig = CONFIG.duplicate(true)
	config.consciousness_drift_extra_delay = 0.01
	config.rapid_eye_duration_seconds = 0.05
	config.hurt_invulnerability_seconds = 0.01
	dream.config = config
	dream.get_node("DreamClock").config = config
	dream.get_node("EnemySpawner").config = config
	dream.get_node("UILayer/WakeOverlay").config = config
	root.add_child(dream)
	await process_frame
	dream.spawner.running = false
	dream.player.auto_weapon.cooldown_left = 999.0
	dream.player.configure_consciousness_drift(2, config)
	dream.player.auto_weapon._fire(Vector2.RIGHT, true)
	await create_timer(0.04).timeout
	_assert(dream.projectile_container.get_child_count() == 2, "Consciousness drift did not produce exactly one non-recursive extra attack")
	dream.skill_levels.rapid_eye = 1
	dream._on_spawn_requested(Vector2(500, 200), 1.0, 0.0, "basic")
	var enemy: Node = dream.enemy_container.get_child(0)
	dream.player.receive_damage(1.0)
	_assert(is_equal_approx(enemy.movement_speed_multiplier, config.rapid_eye_slow_multiplier), "Rapid eye did not slow an existing enemy")
	dream._on_spawn_requested(Vector2(500, 250), 1.0, 0.0, "basic")
	_assert(is_equal_approx(dream.enemy_container.get_child(1).movement_speed_multiplier, config.rapid_eye_slow_multiplier), "Rapid eye did not slow a newly spawned enemy")
	await create_timer(0.09).timeout
	_assert(is_equal_approx(enemy.movement_speed_multiplier, 1.0), "Rapid eye did not restore original movement speed")
	dream.queue_free()
	await process_frame


func _test_sunday_results() -> void:
	var results := RESULTS.instantiate()
	results.summary = {"attendance_status":"休息日", "wake_time":"09:00", "wage":0, "wage_ratio":0.0}
	root.add_child(results)
	await process_frame
	_assert(results.paragraphs == ["今天是休息日，我需要找点有意义的事情做。"], "Sunday reality text is incorrect")
	results.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event
