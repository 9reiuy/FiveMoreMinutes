extends Node

const OPENING_SCENE := preload("res://scenes/ui/opening.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const BEDROOM_SCENE := preload("res://scenes/bedroom/bedroom.tscn")
const DREAM_SCENE := preload("res://scenes/dream/dream_world.tscn")
const RESULTS_SCENE := preload("res://scenes/ui/results.tscn")
const WEAPON_SELECTION_SCENE := preload("res://scenes/ui/weapon_selection.tscn")
const ENDLESS_RESULTS_SCENE := preload("res://scenes/ui/endless_results.tscn")
const CONFIG := preload("res://resources/demo_config.tres")
const SAVE_STORE := preload("res://scripts/app/game_save_store.gd")
const DAY_START_SNAPSHOT := preload("res://scripts/app/day_start_snapshot.gd")
const UNLOCK_STORE := preload("res://scripts/app/weapon_unlock_store.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const CURSOR_POINTER: Texture2D = preload("res://art/icon/Computer Systems/1. Pointer.png")
const CURSOR_HAND: Texture2D = preload("res://art/icon/Computer Systems/2. Hand Pointer.png")

@onready var scene_container: Node = $SceneContainer
@onready var fade: ColorRect = $TransitionLayer/Fade
@onready var debug_console = $DebugConsole
@onready var pause_menu: GlobalPauseMenu = $PauseMenu

var current_screen: Node
var last_summary: Dictionary = {}
var persistent_day_state: Dictionary = {}
var day_start_snapshot = DAY_START_SNAPSHOT.new()
var night_state: Dictionary = {"melatonin_count": 0, "is_hungry_run": false, "run_stress_value": 0}
var transition_running := false
var transition_queue: Array = []
var pause_allowed := false
var current_is_endless_mode := false
var endless_weapon_id := "basic"
var cursor_pointer_scaled: Texture2D
var cursor_hand_scaled: Texture2D
const WEEKDAYS := ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 普通UI Cursor由当前12×12实际显示尺寸等比放大3倍；战斗Crosshair是独立节点，不受影响。
	cursor_pointer_scaled = _scaled_cursor(CURSOR_POINTER, 3)
	cursor_hand_scaled = _scaled_cursor(CURSOR_HAND, 3)
	Input.set_custom_mouse_cursor(cursor_pointer_scaled, Input.CURSOR_ARROW, Vector2(6, 6))
	Input.set_custom_mouse_cursor(cursor_hand_scaled, Input.CURSOR_POINTING_HAND, Vector2(15, 6))
	persistent_day_state = _create_initial_state()
	_configure_input_map()
	pause_menu.resume_requested.connect(_resume_from_pause)
	pause_menu.exit_to_main_menu_requested.connect(_exit_to_main_menu_from_pause)
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)
	_show_main_menu()


func _input(event: InputEvent) -> void:
	if not pause_allowed or transition_running or not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	# ESC 优先级：当前画面若有更高优先级窗口（如电脑界面）需要消费 ESC，
	# 先交给它处理，不打开暂停菜单。
	if is_instance_valid(current_screen) and current_screen.has_method("consume_escape") and bool(current_screen.call("consume_escape")):
		get_viewport().set_input_as_handled()
		return
	if pause_menu.is_open():
		pause_menu.handle_escape()
	else:
		_open_pause_menu()
	get_viewport().set_input_as_handled()


func _create_initial_state() -> Dictionary:
	var parsed_messages: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/phone_messages.json"))
	var initial_messages: Array = parsed_messages.get("messages", []).duplicate(true) if parsed_messages is Dictionary else []
	for index in initial_messages.size():
		if initial_messages[index] is Dictionary:
			initial_messages[index].message_sequence = index + 1
	return {
		"balance": CONFIG.initial_balance,
		"ram": 0,
		"melatonin_inventory": 0,
		"melatonin_ever_purchased": false,
		"melatonin_bottle_present": false,
		"sunshade_purchased": false,
		"sunshade_visible": false,
		"unemployed": false,
		"is_unemployed": false,
		"high_stress_consecutive_days": 0,
		"high_stress_checked_day_id": -1,
		"normal_attendance_workday_streak": 0,
		"normal_life_ending_unlocked": false,
		"any_ending_completed": false,
		"grenade_weapon_unlocked": false,
		"consecutive_hungry_days": 0,
		"starvation_ending_unlocked": false,
		"starvation_ending_triggered_day_id": -1,
		"hunger_checked_day_id": -1,
		"weekday_index": 0,
		"calendar_day_id": 0,
		"online_messages": initial_messages,
		"online_message_sequence_next": initial_messages.size() + 1,
		"mom_hunger_message_sent": false,
		"mom_hunger_message_day_id": -1,
		"day3_quicklink_news_sent": false,
		"day3_quicklink_news_day_id": -1,
		"day5_northern_times_sent": false,
		"day5_northern_times_day_id": -1,
		"day5_northern_times_deleted": false,
		"quicklink_news_read": false,
		"room_state": {"condition": "initial"},
		"has_entered_dream": false,
		"stress_value": CONFIG.stress_default,
		"shotgun_unlocked": false,
		"beam_weapon_unlocked": false,
		"katana_unlocked": false,
		"current_weapon_id": "basic",
		"sunday_event_week_id": -1,
		"sunday_event_resolved": false,
		"sunday_event_id": -1,
		"sunday_event_balance_delta": 0,
		"daily_weather_type": "",
		"daily_weather_day_id": -1,
		"cheap_meal_purchased_today": false,
		"cheap_meal_purchases_today": 0,
		"food_eaten_today": false,
		"hungry_bed_attempts_today": 0,
		"delivery_state": "NONE",
		"delivery_seconds_remaining": 0.0,
		"is_hungry_run": false,
		# 电脑当天是否已打开（false -> 息屏素材；新的一天开始时重置，见 _reset_daily_state）。
		"computer_opened_today": false,
		"permanent_upgrades": {
			"visual_cortex": 0,
			"brainstem": 0,
			"hippocampus": 0,
			"prefrontal": 0
		}
	}


func _show_main_menu() -> void:
	PauseManager.clear_all()
	current_is_endless_mode = false
	var menu := MAIN_MENU_SCENE.instantiate()
	menu.has_save = SAVE_STORE.has_valid_save()
	menu.continue_requested.connect(_continue_game)
	menu.new_game_requested.connect(_start_new_game)
	menu.endless_requested.connect(_start_endless_mode)
	menu.quit_requested.connect(_quit_game)
	_set_screen(menu)


func _start_new_game() -> void:
	current_is_endless_mode = false
	persistent_day_state = _create_initial_state()
	# 新开存档继承历史解锁的武器（全局记录），避免已解锁武器被重新锁上。
	UNLOCK_STORE.apply_to(persistent_day_state)
	last_summary.clear()
	night_state = _fresh_night_state()
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)
	_commit_day_start()
	_show_opening()


func _continue_game() -> void:
	current_is_endless_mode = false
	var loaded := SAVE_STORE.load_game()
	if loaded.is_empty():
		_show_main_menu()
		return
	persistent_day_state = _merge_with_defaults(loaded)
	# 读档同样继承全局解锁的武器（如旧存档缺失新解锁项）。
	UNLOCK_STORE.apply_to(persistent_day_state)
	last_summary.clear()
	night_state = _fresh_night_state()
	persistent_day_state.has_entered_dream = false
	day_start_snapshot.capture(persistent_day_state)
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)
	_show_bedroom(false)


func _merge_with_defaults(loaded: Dictionary) -> Dictionary:
	var defaults := _create_initial_state()
	var had_is_unemployed := loaded.has("is_unemployed")
	var legacy_unemployed := bool(loaded.get("unemployed", false))
	var had_shotgun_unlock := loaded.has("shotgun_unlocked")
	var had_calendar_day_id := loaded.has("calendar_day_id")
	var legacy_weekday_index := int(loaded.get("weekday_index", 0))
	for key in defaults:
		if not loaded.has(key):
			loaded[key] = defaults[key]
	var upgrades: Dictionary = loaded.get("permanent_upgrades", {})
	for id in defaults.permanent_upgrades:
		if not upgrades.has(id):
			upgrades[id] = 0
	loaded.permanent_upgrades = upgrades
	loaded.stress_value = clampi(int(loaded.get("stress_value", CONFIG.stress_default)), 0, CONFIG.stress_max)
	loaded.is_unemployed = bool(loaded.get("is_unemployed", false)) if had_is_unemployed else legacy_unemployed
	loaded.unemployed = loaded.is_unemployed
	loaded.calendar_day_id = maxi(int(loaded.get("calendar_day_id", 0)) if had_calendar_day_id else legacy_weekday_index, 0)
	if not had_shotgun_unlock:
		loaded.shotgun_unlocked = int(loaded.weekday_index) >= 1
	_migrate_online_messages(loaded)
	_ensure_daily_generated_state(loaded)
	return loaded


func _fresh_night_state() -> Dictionary:
	return {
		"melatonin_count": 0,
		"is_hungry_run": false,
		"run_stress_value": clampi(int(persistent_day_state.get("stress_value", CONFIG.stress_default)), 0, CONFIG.stress_max)
	}


func _reset_daily_state() -> void:
	persistent_day_state.cheap_meal_purchased_today = false
	persistent_day_state.cheap_meal_purchases_today = 0
	persistent_day_state.food_eaten_today = false
	persistent_day_state.hungry_bed_attempts_today = 0
	persistent_day_state.delivery_state = "NONE"
	persistent_day_state.delivery_seconds_remaining = 0.0
	persistent_day_state.is_hungry_run = false
	# 新的一天：电脑回到默认息屏状态（computer_opened_today 跨天重置）。
	persistent_day_state.computer_opened_today = false


func _save_progress() -> void:
	# 存档时把当前已解锁的武器同步到全局（跨存档继承）。
	UNLOCK_STORE.sync_from(persistent_day_state)
	SAVE_STORE.save_game(persistent_day_state)


func _commit_day_start() -> void:
	_ensure_daily_generated_state(persistent_day_state)
	persistent_day_state.has_entered_dream = false
	# 记录当天早晨的压力值，供结局后"从卧室重新开始当天"时恢复。
	persistent_day_state.morning_stress_value = int(persistent_day_state.get("stress_value", CONFIG.stress_default))
	day_start_snapshot.capture(persistent_day_state)
	_save_progress()


## 结局触发后，把存档重置为"结局日早晨"（卧室开始）：
## 清空当天行动状态、恢复早晨压力、重新捕获当天开始快照。
## 同时重置结局触发标记，让玩家重新体验当天时（如再次挨饿上床）能再次触发结局。
## 这样主菜单点"继续游戏"时回到结局那一天的卧室，而不是继续当天剩余流程。
func _reset_state_to_bedroom_start() -> void:
	_reset_daily_state()
	persistent_day_state.has_entered_dream = false
	persistent_day_state.stress_value = int(persistent_day_state.get("morning_stress_value", CONFIG.stress_default))
	# 结局触发标记重置：hunger_checked_day_id 记录"当天已检查过挨饿"，
	# 必须清空才能让重新体验当天时再次检查并触发饿死结局。
	persistent_day_state.hunger_checked_day_id = -1
	persistent_day_state.starvation_ending_unlocked = false
	persistent_day_state.starvation_ending_triggered_day_id = -1
	persistent_day_state.normal_life_ending_unlocked = false
	day_start_snapshot.capture(persistent_day_state)


func _restore_day_start_snapshot() -> void:
	persistent_day_state = day_start_snapshot.restore(persistent_day_state)
	last_summary.clear()
	night_state = _fresh_night_state()
	_save_progress()
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)


func _quit_game() -> void:
	get_tree().quit()


func _configure_input_map() -> void:
	# Input is defined in one place so controls can later move to a settings screen.
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("interact", [KEY_F])
	_add_key_action("confirm", [KEY_ENTER, KEY_SPACE])
	_add_key_action("restart_demo", [KEY_R])
	_add_key_action("dash", [KEY_SPACE])
	_add_key_action("skill_menu", [KEY_TAB])
	_add_key_action("toggle_console", [KEY_QUOTELEFT, KEY_F10])


func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _show_opening() -> void:
	last_summary.clear()
	var opening := OPENING_SCENE.instantiate()
	opening.opening_finished.connect(_show_bedroom.bind(false))
	_transition_to(opening)


func _show_bedroom(after_dream: bool = false) -> void:
	var bedroom := BEDROOM_SCENE.instantiate()
	bedroom.sleep_requested.connect(_start_story_dream)
	bedroom.save_requested.connect(_save_progress)
	bedroom.story_weapon_changed.connect(_on_story_weapon_equipped)
	bedroom.after_dream = after_dream
	bedroom.summary = last_summary.duplicate(true)
	bedroom.persistent_state = persistent_day_state
	bedroom.weekday_name = _get_weekday_name()
	_transition_to(bedroom)


func _start_story_dream(melatonin_count: int = 0, is_hungry_run: bool = false) -> void:
	if _register_hunger_sleep_for_day():
		_show_starvation_ending()
		return
	night_state.melatonin_count = clampi(melatonin_count, 0, CONFIG.melatonin_nightly_use_limit)
	night_state.is_hungry_run = is_hungry_run
	night_state.run_stress_value = clampi(int(persistent_day_state.get("stress_value", CONFIG.stress_default)), 0, CONFIG.stress_max)
	persistent_day_state.is_hungry_run = is_hungry_run
	persistent_day_state.has_entered_dream = true
	_show_dream(_validated_story_weapon_id())


func _show_dream(weapon_id: String) -> void:
	current_is_endless_mode = false
	var dream := DREAM_SCENE.instantiate()
	var story_weapon_ids: Array[String] = _get_available_weapon_ids(_story_weapon_unlock_state())
	dream.configure_run_weapon_state(weapon_id, story_weapon_ids, false)
	var run_config: DemoConfig = CONFIG.duplicate(true)
	# The result belongs to the morning after this bedroom night.
	var is_sunday := (int(persistent_day_state.get("weekday_index", 0)) + 1) % WEEKDAYS.size() == 6
	run_config.alarm_start_minutes = CONFIG.story_wake_minutes
	run_config.dream_start_minutes = _dream_start_minutes_for_melatonin_count(int(night_state.get("melatonin_count", 0)))
	dream.config = run_config
	dream.get_node("DreamClock").config = run_config
	dream.get_node("EnemySpawner").config = run_config
	dream.get_node("UILayer/WakeOverlay").config = run_config
	dream.permanent_upgrades = persistent_day_state.get("permanent_upgrades", {}).duplicate(true)
	dream.is_sunday = is_sunday
	dream.is_hungry_run = bool(night_state.get("is_hungry_run", false))
	dream.run_stress_value = int(night_state.get("run_stress_value", CONFIG.stress_default))
	dream.sleepwalk_mode = SettingsManager.get_sleepwalk_mode()
	dream.weapon_equipped.connect(_on_story_weapon_equipped)
	dream.dream_finished.connect(_show_results)
	var sunshade_active := bool(persistent_day_state.get("sunshade_purchased", false)) and bool(persistent_day_state.get("sunshade_visible", true))
	dream.get_node("UILayer/WakeOverlay").update_sunshade(sunshade_active)
	_transition_to(dream, 0.65)


func _start_endless_mode() -> void:
	current_is_endless_mode = true
	var selection := WEAPON_SELECTION_SCENE.instantiate()
	selection.unlock_state = {"shotgun": true, "beam": true, "katana": true, "grenade": true}
	selection.weapon_selected.connect(_show_endless_dream)
	_transition_to(selection)


func _show_endless_dream(weapon_id: String) -> void:
	current_is_endless_mode = true
	# Endless武器仅存在本次Run；不读取或写入剧情current_weapon_id/DaySnapshot。
	var available_endless: Array[String] = ["basic", "beam", "shotgun", "katana", "grenade"]
	endless_weapon_id = weapon_id if weapon_id in available_endless else "basic"
	var dream := DREAM_SCENE.instantiate()
	dream.configure_run_weapon_state(endless_weapon_id, available_endless, true)
	var run_config: DemoConfig = CONFIG.duplicate(true)
	dream.config = run_config
	dream.get_node("DreamClock").config = run_config
	dream.get_node("EnemySpawner").config = run_config
	dream.get_node("UILayer/WakeOverlay").config = run_config
	dream.permanent_upgrades = persistent_day_state.get("permanent_upgrades", {}).duplicate(true)
	dream.is_sunday = false
	dream.is_hungry_run = false
	dream.run_stress_value = CONFIG.stress_default
	dream.sleepwalk_mode = SettingsManager.get_sleepwalk_mode()
	dream.dream_finished.connect(_show_endless_results)
	var sunshade_active := bool(persistent_day_state.get("sunshade_purchased", false)) and bool(persistent_day_state.get("sunshade_visible", true))
	dream.get_node("UILayer/WakeOverlay").update_sunshade(sunshade_active)
	_transition_to(dream, 0.45)


func _show_endless_results(summary: Dictionary) -> void:
	var results := ENDLESS_RESULTS_SCENE.instantiate()
	results.summary = summary.duplicate(true)
	results.restart_requested.connect(_show_endless_dream.bind(endless_weapon_id))
	results.main_menu_requested.connect(_show_main_menu)
	_transition_to(results)


func _show_results(summary: Dictionary) -> void:
	last_summary = RunSettlement.settle(summary.duplicate(true), persistent_day_state, CONFIG)
	day_start_snapshot.capture(persistent_day_state)
	_save_progress()
	if bool(last_summary.get("normal_life_ending_triggered", false)):
		_show_normal_life_ending()
		return
	var results := RESULTS_SCENE.instantiate()
	results.summary = last_summary.duplicate(true)
	results.new_day_requested.connect(_start_new_day)
	_transition_to(results)


func _show_normal_life_ending() -> void:
	# 结局后回到"结局日早晨"：继续游戏时从卧室开始重新体验当天。
	_reset_state_to_bedroom_start()
	persistent_day_state.any_ending_completed = true
	persistent_day_state.grenade_weapon_unlocked = true
	_save_progress()
	var ending := OPENING_SCENE.instantiate()
	ending.ending_mode = true
	ending.return_to_menu_requested.connect(_return_from_ending_to_main_menu)
	_transition_to(ending)


func _register_hunger_sleep_for_day() -> bool:
	var day_id := int(persistent_day_state.get("calendar_day_id", 0))
	if int(persistent_day_state.get("hunger_checked_day_id", -1)) != day_id:
		persistent_day_state.hunger_checked_day_id = day_id
		if bool(persistent_day_state.get("food_eaten_today", false)):
			persistent_day_state.consecutive_hungry_days = 0
		else:
			persistent_day_state.consecutive_hungry_days = int(persistent_day_state.get("consecutive_hungry_days", 0)) + 1
		_ensure_timed_online_messages(persistent_day_state)
		_save_progress()
	return not bool(persistent_day_state.get("starvation_ending_unlocked", false)) and int(persistent_day_state.get("consecutive_hungry_days", 0)) >= CONFIG.starvation_ending_required_days


func _show_starvation_ending() -> void:
	persistent_day_state.starvation_ending_unlocked = true
	persistent_day_state.starvation_ending_triggered_day_id = int(persistent_day_state.get("calendar_day_id", 0))
	persistent_day_state.any_ending_completed = true
	persistent_day_state.grenade_weapon_unlocked = true
	# 记录完成后重置为"结局日早晨"（会清掉上面的触发标记），
	# 让继续游戏后重新体验当天时可再次触发饿死结局。
	_reset_state_to_bedroom_start()
	_save_progress()
	var ending := OPENING_SCENE.instantiate()
	ending.ending_mode = true
	if ending.has_method("setup_paragraphs"):
		ending.setup_paragraphs(["你饿死了", "永远不会醒来了。"])
	else:
		ending.ending_paragraphs = ["你饿死了", "永远不会醒来了。"]
	# "你饿死了"以红色大字 + 轻微抖动醒目显示。
	ending.dramatic_text = "你饿死了"
	ending.return_to_menu_requested.connect(_return_from_ending_to_main_menu)
	_transition_to(ending)


func _return_from_ending_to_main_menu() -> void:
	Engine.time_scale = 1.0
	last_summary.clear()
	night_state = _fresh_night_state()
	_show_main_menu()


func _start_new_day() -> void:
	# Future cross-day data can be retained separately; all current run state is discarded.
	Engine.time_scale = 1.0
	last_summary.clear()
	persistent_day_state.calendar_day_id = int(persistent_day_state.get("calendar_day_id", 0)) + 1
	persistent_day_state.weekday_index = int(persistent_day_state.calendar_day_id) % WEEKDAYS.size()
	_reset_daily_state()
	_apply_day_based_unlocks(persistent_day_state)
	night_state = _fresh_night_state()
	_commit_day_start()
	_show_bedroom(false)


func _get_weekday_name() -> String:
	return WEEKDAYS[int(persistent_day_state.get("weekday_index", 0)) % WEEKDAYS.size()]


func _dream_start_minutes_for_melatonin_count(count: int) -> float:
	var tablets := clampi(count, 0, CONFIG.melatonin_nightly_use_limit)
	return maxf(0.0, CONFIG.dream_start_minutes - tablets * CONFIG.melatonin_minutes_earlier_per_tablet)


func _on_debug_ram_changed() -> void:
	_save_progress()
	if not is_instance_valid(current_screen):
		return
	if current_screen.scene_file_path == "res://scenes/ui/weapon_selection.tscn":
		current_screen.unlock_state = {
			"shotgun": bool(persistent_day_state.get("shotgun_unlocked", false)),
			"beam": bool(persistent_day_state.get("beam_weapon_unlocked", false)),
			"katana": bool(persistent_day_state.get("katana_unlocked", false)),
			"grenade": bool(persistent_day_state.get("grenade_weapon_unlocked", false))
		}
		current_screen.queue_redraw()
	var active_phone := current_screen.get_node_or_null("PhoneLayer/BedroomPhone")
	if active_phone != null:
		active_phone.call("configure_state", persistent_day_state)


func _set_screen(next_screen: Node) -> void:
	if is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = next_screen
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	scene_container.add_child(current_screen)
	pause_allowed = current_screen.scene_file_path != "res://scenes/ui/main_menu.tscn"


func _open_pause_menu() -> void:
	PauseManager.request_pause(PauseManager.ESC_MENU)
	pause_menu.open_pause()


func _resume_from_pause() -> void:
	pause_menu.close_pause()
	PauseManager.release_pause(PauseManager.ESC_MENU)


func _exit_to_main_menu_from_pause() -> void:
	pause_menu.close_pause()
	PauseManager.clear_all()
	Engine.time_scale = 1.0
	if not current_is_endless_mode:
		_restore_day_start_snapshot()
	_show_main_menu()


func _migrate_online_messages(state: Dictionary) -> void:
	var templates_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/phone_messages.json"))
	var templates: Array = templates_variant.get("messages", []) if templates_variant is Dictionary else []
	var existing: Array = state.get("online_messages", [])
	var current_day_id := int(state.get("calendar_day_id", 0))
	var next_sequence := maxi(1, int(state.get("online_message_sequence_next", 1)))
	for index in existing.size():
		var old_message: Variant = existing[index]
		if not old_message is Dictionary:
			continue
		if not old_message.has("received_day_id"):
			# One-time safe migration: preserve deterministic order instead of resetting every load.
			old_message.received_day_id = maxi(0, current_day_id - (existing.size() - 1 - index))
		if not old_message.has("message_sequence") or int(old_message.get("message_sequence", 0)) <= 0:
			old_message.message_sequence = next_sequence
			next_sequence += 1
		else:
			next_sequence = maxi(next_sequence, int(old_message.message_sequence) + 1)
		if not old_message.has("is_read"):
			old_message.is_read = false
	for message in existing:
		if not message is Dictionary:
			continue
		if str(message.get("category", "")) == "生活":
			message.category = "妈妈"
		elif str(message.get("category", "")) == "工作":
			message.category = "项目组长-速联科技控股"
	var has_news := false
	for message in existing:
		if message is Dictionary and str(message.get("id", "")) == "quicklink_news_debt_1993":
			has_news = true
			state.quicklink_news_read = bool(message.get("is_read", false))
	if not has_news:
		for template in templates:
			if template is Dictionary and str(template.get("id", "")) == "quicklink_news_debt_1993":
				var added_template: Dictionary = template.duplicate(true)
				added_template.message_sequence = next_sequence
				next_sequence += 1
				existing.append(added_template)
				state.quicklink_news_read = false
				break
	state.online_messages = existing
	state.online_message_sequence_next = next_sequence


func _ensure_daily_generated_state(state: Dictionary) -> void:
	var day_id := int(state.get("calendar_day_id", 0))
	if int(state.get("daily_weather_day_id", -1)) != day_id or str(state.get("daily_weather_type", "")).is_empty():
		state.daily_weather_type = CONFIG.weather_types[_weighted_index(CONFIG.weather_probabilities)]
		state.daily_weather_day_id = day_id
	if int(state.get("weekday_index", 0)) == 6:
		_resolve_sunday_event(state)
	_ensure_timed_online_messages(state)


func _ensure_timed_online_messages(state: Dictionary) -> void:
	var day_id := int(state.get("calendar_day_id", 0))
	var game_day_number := day_id + 1
	if int(state.get("consecutive_hungry_days", 0)) == 3 and not bool(state.get("mom_hunger_message_sent", false)):
		_add_online_message(state, {
			"id": "mom_hunger_day3",
			"category": "妈妈",
			"text": "你一个人在外面上班有没有好好吃饭啊，记得吃饭。",
			"received_day_id": day_id,
			"is_read": false
		})
		state.mom_hunger_message_sent = true
		state.mom_hunger_message_day_id = day_id
	if game_day_number >= 3 and not bool(state.get("day3_quicklink_news_sent", false)):
		_add_online_message(state, {
			"id": "day3_quicklink_news",
			"category": "速联快讯",
			"text": "速联科技股价连续两天大涨！50万股民迎利好，净利润暴涨325%",
			"received_day_id": day_id,
			"is_read": false
		})
		state.day3_quicklink_news_sent = true
		state.day3_quicklink_news_day_id = day_id
	if game_day_number >= 5 and not bool(state.get("day5_northern_times_sent", false)):
		_add_online_message(state, {
			"id": "day5_northern_times",
			"category": "北方时报",
			"text": "速联科技裁员2万、连关多厂后速联科技上半季度仍然亏损。",
			"received_day_id": day_id,
			"is_read": false
		})
		state.day5_northern_times_sent = true
		state.day5_northern_times_day_id = day_id


func _add_online_message(state: Dictionary, message: Dictionary) -> bool:
	var existing: Array = state.get("online_messages", [])
	var message_id := str(message.get("id", "")).strip_edges()
	if message_id.is_empty() or str(message.get("text", "")).strip_edges().is_empty():
		push_error("ONLINE message rejected: missing id or text")
		return false
	for entry in existing:
		if entry is Dictionary and str(entry.get("id", "")) == message_id:
			return false
	var normalized := message.duplicate(true)
	normalized.id = message_id
	normalized.received_day_id = int(normalized.get("received_day_id", state.get("calendar_day_id", 0)))
	normalized.message_sequence = maxi(1, int(state.get("online_message_sequence_next", 1)))
	normalized.is_read = bool(normalized.get("is_read", false))
	state.online_message_sequence_next = int(normalized.message_sequence) + 1
	existing.append(normalized)
	state.online_messages = existing
	_refresh_online_phone_if_available(state)
	return true


func _refresh_online_phone_if_available(state: Dictionary) -> void:
	if not is_instance_valid(current_screen):
		return
	var phone := current_screen.get_node_or_null("PhoneLayer/BedroomPhone")
	if phone != null and phone.has_method("configure_state"):
		phone.configure_state(state)


func _resolve_sunday_event(state: Dictionary) -> void:
	var week_id := floori(float(int(state.get("calendar_day_id", 0))) / 7.0)
	if bool(state.get("sunday_event_resolved", false)) and int(state.get("sunday_event_week_id", -1)) == week_id:
		return
	var event_id := _weighted_index(CONFIG.sunday_event_probabilities)
	var requested_delta := int(CONFIG.sunday_event_balance_deltas[event_id])
	var actual_delta := STATE_RULES.change_balance(state, requested_delta)
	state.sunday_event_week_id = week_id
	state.sunday_event_resolved = true
	state.sunday_event_id = event_id
	state.sunday_event_balance_delta = actual_delta
	var formatted_delta := FORMAT.format_currency(actual_delta)
	if actual_delta > 0:
		formatted_delta = "+" + formatted_delta
	state.pending_sunday_notice = "%s\n余额变化：%s" % [CONFIG.sunday_event_texts[event_id], formatted_delta]


func _weighted_index(weights: PackedFloat32Array) -> int:
	var roll := randf()
	var cumulative := 0.0
	for index in weights.size():
		cumulative += maxf(weights[index], 0.0)
		if roll <= cumulative:
			return index
	return maxi(weights.size() - 1, 0)


func _apply_day_based_unlocks(state: Dictionary) -> bool:
	if int(state.get("calendar_day_id", 0)) < 1 or bool(state.get("shotgun_unlocked", false)):
		return false
	state.shotgun_unlocked = true
	state.pending_unlock_notice = "霰弹枪已永久解锁。"
	return true


func _transition_to(next_screen: Node, duration: float = 0.35) -> void:
	if transition_running:
		# 转场进行中时排队而非丢弃新画面：旧实现会直接 queue_free 新场景，
		# 可能静默丢掉武器选择界面导致睡觉后无任何 UI 可交互。
		transition_queue.append({"screen": next_screen, "duration": duration})
		return
	await _run_transition(next_screen, duration)
	while not transition_queue.is_empty():
		var next: Dictionary = transition_queue.pop_front()
		await _run_transition(next["screen"], float(next["duration"]))


func _run_transition(next_screen: Node, duration: float) -> void:
	transition_running = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, duration)
	await tween.finished
	_set_screen(next_screen)
	var reveal := create_tween()
	reveal.tween_property(fade, "color:a", 0.0, duration)
	await reveal.finished
	transition_running = false


func _get_available_weapon_ids(unlock_state: Dictionary) -> Array[String]:
	var pool: Array[String] = ["basic"]
	for weapon_id in ["beam", "shotgun", "katana", "grenade"]:
		if bool(unlock_state.get(weapon_id, false)):
			pool.append(weapon_id)
	return pool


func _story_weapon_unlock_state() -> Dictionary:
	return {
		"shotgun": bool(persistent_day_state.get("shotgun_unlocked", false)),
		"beam": bool(persistent_day_state.get("beam_weapon_unlocked", false)),
		"katana": bool(persistent_day_state.get("katana_unlocked", false)),
		"grenade": bool(persistent_day_state.get("grenade_weapon_unlocked", false))
	}


func _validated_story_weapon_id() -> String:
	var current := str(persistent_day_state.get("current_weapon_id", "basic"))
	if current in _get_available_weapon_ids(_story_weapon_unlock_state()):
		return current
	persistent_day_state.current_weapon_id = "basic"
	return "basic"


func _on_story_weapon_equipped(weapon_id: String) -> void:
	if current_is_endless_mode or not weapon_id in _get_available_weapon_ids(_story_weapon_unlock_state()):
		return
	persistent_day_state.current_weapon_id = weapon_id
	day_start_snapshot.set_persistent_value(&"current_weapon_id", weapon_id)
	_save_progress()


func _scaled_cursor(source: Texture2D, multiplier: int) -> Texture2D:
	var image := source.get_image()
	image.resize(image.get_width() * multiplier, image.get_height() * multiplier, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
