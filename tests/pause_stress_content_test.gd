extends Node

const CONFIG := preload("res://resources/demo_config.tres")
const DREAM := preload("res://scenes/dream/dream_world.tscn")
const PROJECTILE := preload("res://scenes/entities/basic_projectile.tscn")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")
const MELATONIN := preload("res://scenes/ui/melatonin_interaction.tscn")
const MAIN_SCRIPT := preload("res://scripts/app/main.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")

var failures: Array[String] = []


func _ready() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "dash", "skill_menu"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_test_stress_rules_and_unlocks()
	await _test_phone_messages_and_melatonin()
	await _test_real_pause_reasons()
	if failures.is_empty():
		print("PAUSE STRESS CONTENT TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)


func _state(stress: int = 0, day_id: int = 0) -> Dictionary:
	return {
		"balance": 200, "ram": 0, "stress_value": stress, "calendar_day_id": day_id,
		"is_unemployed": false, "unemployed": false, "high_stress_consecutive_days": 0,
		"high_stress_checked_day_id": -1, "normal_attendance_workday_streak": 0,
		"normal_life_ending_unlocked": false, "beam_weapon_unlocked": false, "katana_unlocked": false
	}


func _test_stress_rules_and_unlocks() -> void:
	_assert(CONFIG.stress_default == 0 and CONFIG.stress_max == 100, "Stress defaults are not 0/100")
	var early := _state(10)
	RunSettlement.settle({"wake_minutes":330.0, "dream_end_minutes":330.0, "alarm_minutes":420.0, "level":1, "is_sunday":false}, early, CONFIG)
	_assert(early.stress_value == 6, "05:30 against 07:00 did not reduce stress by 4")
	var sunday := _state(10)
	RunSettlement.settle({"wake_minutes":330.0, "dream_end_minutes":330.0, "alarm_minutes":540.0, "level":1, "is_sunday":true}, sunday, CONFIG)
	_assert(sunday.stress_value == 10, "Sunday early wake changed stress")
	var late := _state(0)
	RunSettlement.settle({"wake_minutes":450.0, "dream_end_minutes":450.0, "alarm_minutes":420.0, "level":1, "is_sunday":false}, late, CONFIG)
	_assert(late.stress_value == 10 and late.beam_weapon_unlocked, "Late stress or beam unlock failed")
	var absent := _state(0)
	RunSettlement.settle({"wake_minutes":540.0, "dream_end_minutes":540.0, "alarm_minutes":420.0, "level":1, "is_sunday":false}, absent, CONFIG)
	_assert(absent.stress_value == 30 and absent.katana_unlocked, "Absent stress or katana unlock failed")
	var unemployed := _state(90)
	for day in range(3):
		unemployed.calendar_day_id = day
		RunSettlement.settle({"wake_minutes":540.0, "dream_end_minutes":540.0, "alarm_minutes":540.0, "level":1, "is_sunday":true}, unemployed, CONFIG)
	_assert(unemployed.is_unemployed and unemployed.high_stress_consecutive_days == 3, "Three high-stress days did not trigger unemployment")
	var after_unemployment := RunSettlement.settle({"wake_minutes":420.0, "dream_end_minutes":420.0, "alarm_minutes":420.0, "level":1, "is_sunday":false}, unemployed, CONFIG)
	_assert(after_unemployment.wage == 0, "Unemployed state still paid wages")
	var money := {"balance": 200}
	_assert(STATE_RULES.change_balance(money, -500) == -200 and money.balance == 0, "Balance went below zero or returned wrong actual delta")
	var main = MAIN_SCRIPT.new()
	var day_state := {"calendar_day_id":1, "shotgun_unlocked":false}
	_assert(main._apply_day_based_unlocks(day_state) and day_state.shotgun_unlocked, "Day 2 shotgun unlock failed")
	var weather_state := {"calendar_day_id":4, "weekday_index":4, "daily_weather_day_id":-1, "daily_weather_type":"", "balance":0}
	main._ensure_daily_generated_state(weather_state)
	var first_weather: String = str(weather_state.daily_weather_type)
	main._ensure_daily_generated_state(weather_state)
	_assert(weather_state.daily_weather_type == first_weather and first_weather in CONFIG.weather_types, "Same-day weather rerolled or is invalid")
	_assert(CONFIG.sunday_event_balance_deltas == PackedInt32Array([200, -500, 1000, -300, 0]), "Sunday event amount table is incorrect")
	var sunday_event_state := {"calendar_day_id":6, "weekday_index":6, "balance":200, "daily_weather_day_id":-1, "daily_weather_type":"", "sunday_event_resolved":false, "sunday_event_week_id":-1}
	main._ensure_daily_generated_state(sunday_event_state)
	var event_balance := int(sunday_event_state.balance)
	var event_id := int(sunday_event_state.sunday_event_id)
	main._ensure_daily_generated_state(sunday_event_state)
	_assert(int(sunday_event_state.balance) == event_balance and int(sunday_event_state.sunday_event_id) == event_id, "Same Sunday rerolled or applied its balance twice")
	var legacy := {"balance":100, "ram":0, "melatonin_inventory":0, "weekday_index":2, "permanent_upgrades":{}, "unemployed":true, "online_messages":[{"category":"生活", "text":"最近还好吗？有空记得回个电话。", "is_read":true}]}
	var migrated: Dictionary = main._merge_with_defaults(legacy)
	_assert(migrated.stress_value == 0 and migrated.is_unemployed and migrated.shotgun_unlocked, "Legacy save defaults/unemployment/day unlock migration failed")
	_assert(migrated.online_messages.size() >= 2 and not migrated.quicklink_news_read, "Legacy online state did not preserve messages and append unread news")
	main.free()


func _test_phone_messages_and_melatonin() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/phone_messages.json"))
	var messages: Array = parsed.messages
	_assert(messages[0].category == "项目组长-速联科技控股" and messages[1].category == "妈妈", "Online contact names are incorrect")
	_assert(messages[2].text == "一项发表在《希望财经》上的研究，分析了1993年大崩溃事件下的债务与收入，研究者找到了证据表明，债务可能影响自杀的可能性。", "Quicklink news text changed")
	var phone := PHONE.instantiate()
	phone.configure_state({"balance":0, "ram":3, "weekday_index":0, "permanent_upgrades":{"visual_cortex":2}, "online_messages":messages.duplicate(true)})
	get_tree().root.add_child(phone)
	await get_tree().process_frame
	_assert(phone._somnia_button_label(2, 3) == "RAM不足 需要5", "Somnia insufficient-RAM label hides next price")
	phone._mark_online_messages_read()
	_assert(phone.persistent_state.quicklink_news_read, "Quicklink news read state was not saved")
	phone.queue_free()
	var interaction := MELATONIN.instantiate()
	var fast: DemoConfig = CONFIG.duplicate(true)
	fast.melatonin_hand_reach_seconds = 0.01
	fast.melatonin_pill_throw_seconds = 0.01
	fast.melatonin_consume_pre_swallow_pause = 0.01
	fast.melatonin_consume_hand_approach_seconds = 0.01
	fast.melatonin_consume_end_pause = 0.01
	interaction.config = fast
	get_tree().root.add_child(interaction)
	var state := {"melatonin_inventory":1, "stress_value":10}
	interaction.open(state)
	await get_tree().create_timer(0.03).timeout
	interaction._begin_pill_drop()
	await get_tree().create_timer(0.12).timeout
	_assert(state.melatonin_inventory == 0 and state.stress_value == 5 and interaction.consumed, "Completed melatonin animation did not commit stock/stress exactly once")
	for file in ["right_hand_open", "right_hand_grab", "right_hand_throw"]:
		var texture := load("res://assets/art/first_person/melatonin/%s.png" % file) as Texture2D
		_assert(texture != null and texture.get_size() == Vector2(256,256), "Missing first-person hand frame: " + file)
	interaction.queue_free()


func _test_real_pause_reasons() -> void:
	PauseManager.clear_all()
	var container := Node.new()
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(container)
	var dream := DREAM.instantiate()
	var run_config: DemoConfig = CONFIG.duplicate(true)
	run_config.enemy_initial_spawn_interval = 100.0
	run_config.enemy_minimum_spawn_interval = 100.0
	dream.config = run_config
	dream.get_node("DreamClock").config = run_config
	dream.get_node("EnemySpawner").config = run_config
	dream.get_node("UILayer/WakeOverlay").config = run_config
	dream.run_stress_value = 80
	container.add_child(dream)
	await get_tree().process_frame
	dream._on_spawn_requested(Vector2(520,200), 1.0, 0.0, "basic")
	var projectile := PROJECTILE.instantiate()
	projectile.position = Vector2(150,100)
	projectile.setup(Vector2.RIGHT, 1.0, 1000.0, 100.0)
	dream.add_projectile(projectile)
	await get_tree().process_frame
	var enemy: Node2D = dream.enemy_container.get_child(0) as Node2D
	var enemy_position: Vector2 = enemy.position
	var projectile_position: Vector2 = projectile.position
	var clock_minutes: float = dream.clock.current_minutes
	var spawn_accumulator: float = dream.spawner.accumulator
	PauseManager.request_pause(PauseManager.ESC_MENU)
	await get_tree().create_timer(0.08).timeout
	_assert(enemy.position == enemy_position and projectile.position == projectile_position, "ESC did not pause enemies/projectiles")
	_assert(is_equal_approx(dream.clock.current_minutes, clock_minutes) and is_equal_approx(dream.spawner.accumulator, spawn_accumulator), "ESC did not pause dream clock/spawner")
	PauseManager.release_pause(PauseManager.ESC_MENU)
	dream._grant_experience(20)
	_assert(PauseManager.has_pause_reason(PauseManager.UPGRADE) and get_tree().paused, "Upgrade did not request a real tree pause")
	PauseManager.request_pause(PauseManager.ESC_MENU)
	PauseManager.release_pause(PauseManager.ESC_MENU)
	_assert(get_tree().paused and PauseManager.has_pause_reason(PauseManager.UPGRADE), "Closing ESC released the upgrade pause")
	dream.upgrade_panel._choose(0)
	_assert(not get_tree().paused, "Choosing the final card did not release only the upgrade pause")
	container.queue_free()
	await get_tree().process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
