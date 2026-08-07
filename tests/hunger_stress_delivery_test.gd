extends Node

const CONFIG := preload("res://resources/demo_config.tres")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")
const BEDROOM := preload("res://scenes/bedroom/bedroom.tscn")
const DREAM := preload("res://scenes/dream/dream_world.tscn")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")

var failures: Array[String] = []


func _ready() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "dash", "skill_menu"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_assets()
	await _test_player_animation_hunger_and_hud()
	await _test_phone_purchase_and_bedroom_delivery()
	_test_stress_settlement()
	await _test_stress_difficulty_upgrade_pause_and_escape_layer()
	if failures.is_empty():
		print("HUNGER STRESS DELIVERY TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_configuration_and_assets() -> void:
	_assert(CONFIG.cheap_meal_price == 200 and is_equal_approx(CONFIG.cheap_meal_delivery_seconds, 5.0), "Cheap meal defaults are incorrect")
	_assert(is_equal_approx(CONFIG.hungry_damage_multiplier, 0.5) and CONFIG.hungry_bed_attempts_before_force == 2, "Hunger defaults are incorrect")
	_assert(CONFIG.stress_initial_value == 100 and CONFIG.stress_vision_threshold == 30, "Stress defaults are incorrect")
	_assert(is_equal_approx(CONFIG.stress_spawn_multiplier_below_70, 1.5) and is_equal_approx(CONFIG.stress_spawn_multiplier_below_50, 2.0) and is_equal_approx(CONFIG.stress_spawn_multiplier_below_30, 2.5), "Stress spawn tiers are incorrect")
	for name in ["melatonin", "cheap_meal", "visual_cortex", "brainstem", "hippocampus", "prefrontal"]:
		var texture := load("res://assets/ui/products/%s_icon.png" % name) as Texture2D
		_assert(texture != null and texture.get_size() == Vector2(32, 32), "Missing or incorrectly sized product icon: " + name)
	_assert(ResourceLoader.exists("res://shaders/stress_vision.gdshader"), "Stress vision shader is missing")


func _test_player_animation_hunger_and_hud() -> void:
	var player := PLAYER.instantiate()
	get_tree().root.add_child(player)
	await get_tree().process_frame
	player.configure_weapon("basic", CONFIG, {})
	var frames: SpriteFrames = player.visual.sprite_frames
	_assert(frames.get_frame_texture(&"walk_left", 0) == frames.get_frame_texture(&"walk_right", 0), "Right walk does not reuse the stable side frame")
	var fixed_scale: Vector2 = player.visual.scale
	player._update_direction_animation(Vector2.RIGHT)
	player._update_visual_feedback()
	_assert(player.visual.flip_h and player.visual.scale == fixed_scale, "Right animation changed visual scale or did not mirror")
	player.configure_run_modifiers(true, CONFIG)
	player.critical_chance = 0.0
	_assert(int(player.calculate_player_damage(10.0).damage) == 5 and int(player.calculate_player_damage(1.0).damage) == 1, "Unified hunger damage multiplier or minimum damage failed")
	var charges_before: int = player.dash_charges
	var position_before: Vector2 = player.global_position
	Input.action_press("dash")
	player._physics_process(0.016)
	Input.action_release("dash")
	_assert(not player.dashing and player.dash_charges == charges_before and player.global_position == position_before, "Hungry dash consumed a charge or moved the player")
	player.queue_free()
	await get_tree().process_frame


func _test_phone_purchase_and_bedroom_delivery() -> void:
	var phone := PHONE.instantiate()
	var meta := {
		"balance": 500, "ram": 0, "weekday_index": 0, "permanent_upgrades": {}, "online_messages": [],
		"melatonin_inventory": 0, "cheap_meal_purchased_today": false, "cheap_meal_purchases_today": 0,
		"delivery_state": "NONE", "delivery_seconds_remaining": 0.0
	}
	phone.configure_state(meta)
	get_tree().root.add_child(phone)
	await get_tree().process_frame
	phone._purchase_cheap_meal()
	_assert(meta.balance == 300 and meta.cheap_meal_purchased_today and meta.delivery_state == "DELIVERING", "Cheap meal purchase did not deduct or start delivery")
	phone._purchase_cheap_meal()
	_assert(meta.balance == 300 and int(meta.cheap_meal_purchases_today) == 1, "Cheap meal daily limit accepted a second purchase")
	phone.queue_free()
	await get_tree().process_frame

	var bedroom := BEDROOM.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.cheap_meal_delivery_seconds = 0.02
	fast_config.door_open_close_gap_seconds = 0.01
	bedroom.config = fast_config
	bedroom.persistent_state = {
		"balance": 300, "ram": 0, "weekday_index": 0, "permanent_upgrades": {}, "online_messages": [],
		"melatonin_inventory": 0, "melatonin_bottle_present": false, "food_eaten_today": false,
		"hungry_bed_attempts_today": 0, "stress_value": 100, "is_hungry_run": false,
		"cheap_meal_purchased_today": true, "cheap_meal_purchases_today": 1,
		"delivery_state": "DELIVERING", "delivery_seconds_remaining": 0.02
	}
	get_tree().root.add_child(bedroom)
	await get_tree().create_timer(0.06).timeout
	_assert(bedroom.persistent_state.delivery_state == "WAITING_AT_DOOR", "Delivery did not transition to waiting at the door")
	bedroom._request_door_interaction()
	await get_tree().create_timer(0.04).timeout
	_assert(bedroom.persistent_state.delivery_state == "RECEIVED" and bedroom.confirmation_dialog.visible, "Door collection did not enter received state or show dialogue")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom._on_confirmation_cancelled()
	_assert(bedroom.persistent_state.food_eaten_today and int(bedroom.persistent_state.hungry_bed_attempts_today) == 0, "Collected meal was not eaten or did not reset attempts")

	bedroom.persistent_state.food_eaten_today = false
	bedroom.persistent_state.hungry_bed_attempts_today = 0
	bedroom.input_locked = false
	for expected_attempt in range(2):
		bedroom._request_confirmation("bed")
		_assert(bedroom.confirmation_dialog.prompt_label.text == "吃点什么再睡吧", "First two hungry bed prompts are incorrect")
		bedroom.confirmation_dialog.close_without_signal()
		bedroom._on_confirmation_cancelled()
		_assert(int(bedroom.persistent_state.hungry_bed_attempts_today) == expected_attempt + 1, "Hungry bed attempt was not counted exactly once")
	bedroom._request_confirmation("bed")
	_assert(bedroom.confirmation_dialog.prompt_label.text == "那就这样睡吧", "Third hungry bed prompt is incorrect")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom._begin_sleep(true)
	_assert(int(bedroom.persistent_state.stress_value) == 90 and bool(bedroom.persistent_state.is_hungry_run), "Hungry sleep did not apply one stress penalty")
	bedroom.queue_free()
	await get_tree().process_frame


func _test_stress_settlement() -> void:
	var on_time := {"balance": 0, "ram": 0, "unemployed": false, "stress_value": 80, "normal_attendance_workday_streak": 0, "normal_life_ending_unlocked": false}
	RunSettlement.settle({"wake_minutes": 420.0, "level": 1, "is_sunday": false}, on_time, CONFIG)
	_assert(on_time.stress_value == 90, "On-time attendance did not restore stress")
	var late := {"balance": 0, "ram": 0, "unemployed": false, "stress_value": 80, "normal_attendance_workday_streak": 0, "normal_life_ending_unlocked": false}
	RunSettlement.settle({"wake_minutes": 480.0, "level": 1, "is_sunday": false}, late, CONFIG)
	_assert(late.stress_value == 70, "Late attendance did not reduce stress once")
	var absent := {"balance": 0, "ram": 0, "unemployed": false, "stress_value": 80, "normal_attendance_workday_streak": 0, "normal_life_ending_unlocked": false}
	var settled := RunSettlement.settle({"wake_minutes": 600.0, "level": 1, "is_sunday": false}, absent, CONFIG)
	RunSettlement.settle(settled, absent, CONFIG)
	_assert(absent.stress_value == 50, "Absent stress change was incorrect or settled twice")
	var sunday := {"balance": 0, "ram": 0, "unemployed": false, "stress_value": 80, "normal_attendance_workday_streak": 0, "normal_life_ending_unlocked": false}
	RunSettlement.settle({"wake_minutes": 600.0, "level": 1, "is_sunday": true}, sunday, CONFIG)
	_assert(sunday.stress_value == 80, "Sunday changed stress")


func _test_stress_difficulty_upgrade_pause_and_escape_layer() -> void:
	var dream := DREAM.instantiate()
	var run_config: DemoConfig = CONFIG.duplicate(true)
	run_config.enemy_initial_spawn_interval = 100.0
	run_config.enemy_minimum_spawn_interval = 100.0
	dream.config = run_config
	dream.get_node("DreamClock").config = run_config
	dream.get_node("EnemySpawner").config = run_config
	dream.get_node("UILayer/WakeOverlay").config = run_config
	dream.run_stress_value = 25
	dream.is_hungry_run = true
	get_tree().root.add_child(dream)
	await get_tree().process_frame
	dream.spawner.running = false
	dream.player.set_attacking_enabled(false)
	_assert(is_equal_approx(dream.stress_spawn_multiplier, 2.5) and is_equal_approx(dream.stress_enemy_speed_multiplier, 1.5), "Lowest stress tier multipliers are incorrect")
	_assert(dream.stress_vision_overlay.visible, "Stress below 30 did not enable vision mask")
	dream._on_spawn_requested(Vector2(520, 200), 1.0, 0.0, "basic")
	var enemy: Node = dream.enemy_container.get_child(0)
	_assert(is_equal_approx(enemy.movement_speed_multiplier, 1.5), "Stress movement multiplier was not applied to a new enemy")

	dream._grant_experience(84)
	_assert(get_tree().paused and dream.upgrade_panel.visible and dream.pending_upgrades == 2, "Large experience did not queue upgrades under a real tree pause")
	var pause_menu := PAUSE_MENU.instantiate()
	get_tree().root.add_child(pause_menu)
	pause_menu.open_pause()
	_assert(pause_menu.is_open() and pause_menu.layer > 20 and pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "ESC pause layer cannot appear above upgrade UI")
	pause_menu.close_pause()
	_assert(get_tree().paused and dream.upgrade_panel.visible, "Closing the pause overlay released the upgrade pause")
	pause_menu.queue_free()
	dream.upgrade_panel._choose(0)
	_assert(get_tree().paused and dream.pending_upgrades == 1 and dream.upgrade_panel.visible, "First queued upgrade resumed the world or lost the next choice")
	dream.upgrade_panel._choose(0)
	_assert(not get_tree().paused and dream.pending_upgrades == 0 and not dream.upgrade_panel.visible, "Final queued upgrade did not restore the previous pause state")
	dream.queue_free()
	await get_tree().process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
