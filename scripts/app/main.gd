extends Node

const OPENING_SCENE := preload("res://scenes/ui/opening.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const BEDROOM_SCENE := preload("res://scenes/bedroom/bedroom.tscn")
const TUTORIAL_SCENE := preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
# Temporary release gate: keep the tutorial and save flag intact for restoration.
const STORY_TUTORIAL_ENABLED := false
const RECEPTION_SCENE := preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
const DREAM_SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const SELECTIVE_PIXEL_SCENE := preload("res://scenes/dream/preview/SelectivePixelPreview.tscn")
const RESULTS_SCENE := preload("res://scenes/ui/results.tscn")
const CONFIG := preload("res://resources/demo_config.tres")
const SAVE_STORE := preload("res://scripts/app/game_save_store.gd")
const DAY_START_SNAPSHOT := preload("res://scripts/app/day_start_snapshot.gd")
const UNLOCK_STORE := preload("res://scripts/app/weapon_unlock_store.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const CURSOR_POINTER: Texture2D = preload("res://art/icon/Computer Systems/1. Pointer.png")
const CURSOR_HAND: Texture2D = preload("res://art/icon/Computer Systems/2. Hand Pointer.png")
const RETURN_TO_MENU_FADE_HALF_DURATION := 0.20
const GAME_PHONE_SCRIPT := preload("res://scripts/ui/game_phone.gd")

@onready var scene_container: Node = $SceneContainer
@onready var fade: ColorRect = $TransitionLayer/Fade
@onready var transition_director: TransitionDirector = $TransitionLayer/TransitionDirector if has_node("TransitionLayer/TransitionDirector") else null
@onready var debug_console = $DebugConsole
@onready var pause_menu: GlobalPauseMenu = $PauseMenu
@onready var loading_overlay = $LoadingOverlay
@onready var palette_overlay: ColorRect = $FinalPaletteLayer/PaletteOverlay

var current_screen: Node
var _supported_dream_world: Node3D
var game_phone: Node
var last_summary: Dictionary = {}
var persistent_day_state: Dictionary = {}
var day_start_snapshot = DAY_START_SNAPSHOT.new()
var night_state: Dictionary = {
	"melatonin_count": 0,
	"is_hungry_run": false,
	"run_stress_value": 0,
	"has_tarot_card": false,
	"selected_tarot_card_id": &"",
	"selected_tarot_reversed": false
}
var transition_running := false
var transition_queue: Array = []
var pause_allowed := false
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
	_configure_palette()
	if transition_director == null and has_node("TransitionLayer"):
		if $TransitionLayer.has_node("TransitionDirector"):
			transition_director = $TransitionLayer.get_node("TransitionDirector") as TransitionDirector
		else:
			transition_director = TransitionDirector.new()
			transition_director.name = "TransitionDirector"
			$TransitionLayer.add_child(transition_director)
	persistent_day_state = _create_initial_state()
	_configure_input_map()
	pause_menu.resume_requested.connect(_resume_from_pause)
	pause_menu.exit_to_main_menu_requested.connect(_exit_to_main_menu_from_pause)
	game_phone = GAME_PHONE_SCRIPT.new()
	game_phone.name = "GamePhone"
	add_child(game_phone)
	game_phone.call("configure", self)
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)
	if not debug_console.dream_jump_requested.is_connected(_on_debug_dream_jump_requested):
		debug_console.dream_jump_requested.connect(_on_debug_dream_jump_requested)
	_show_main_menu()


func _configure_palette() -> void:
	# Settings persist globally, but Palette belongs only to the Dream world.
	_apply_palette_enabled(SettingsManager.get_palette_enabled())
	var callback := Callable(self, "_on_palette_setting_changed")
	if not SettingsManager.setting_changed.is_connected(callback):
		SettingsManager.setting_changed.connect(callback)


func _on_palette_setting_changed(setting_name: StringName, value: Variant) -> void:
	if setting_name == &"palette_enabled":
		_apply_palette_enabled(bool(value))
	elif setting_name == &"palette_scheme":
		_apply_palette_scheme(int(value))
	elif setting_name == &"pixelation_enabled" and _active_pixelation_screen() != null:
		_active_pixelation_screen().call("set_selective_enabled", bool(value))
		_apply_palette_enabled(SettingsManager.get_palette_enabled())


func _apply_palette_enabled(enabled: bool) -> void:
	if palette_overlay != null:
		palette_overlay.hide()
		var palette_material := palette_overlay.material as ShaderMaterial
		if palette_material != null:
			palette_material.set_shader_parameter(&"palette_enabled", false)
	var pixel_screen := _active_pixelation_screen()
	if pixel_screen != null:
		pixel_screen.call("set_palette_enabled", enabled)


func _apply_palette_scheme(scheme: int) -> void:
	if palette_overlay == null:
		return
	var palette_material := palette_overlay.material as ShaderMaterial
	if palette_material == null or palette_material.get_shader_parameter(&"palette_scheme") == null:
		return
	palette_material.set_shader_parameter(&"palette_scheme", scheme)


func _input(event: InputEvent) -> void:
	# The shared phone also quarantines held input across its closing edge.
	# Let it see releases while closed, before gameplay or the old pause menu.
	if is_instance_valid(game_phone) and bool(game_phone.call("handle_event", event)):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_action_pressed("toggle_phone") and not event.echo:
		if not transition_running and is_instance_valid(game_phone) and bool(game_phone.call("can_open")):
			game_phone.call("open_phone")
			get_viewport().set_input_as_handled()
		return
	if transition_running or not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	# ESC 优先级：当前画面若有更高优先级窗口（如电脑界面）需要消费 ESC，
	# 先交给它处理，不打开暂停菜单。
	if is_instance_valid(current_screen) and current_screen.has_method("consume_escape") and bool(current_screen.call("consume_escape")):
		get_viewport().set_input_as_handled()
		return
	if not pause_allowed:
		return
	if pause_menu.is_open():
		pause_menu.handle_escape()
	else:
		_open_pause_menu()
	get_viewport().set_input_as_handled()


func _create_initial_state() -> Dictionary:
	var initial_messages: Array = TextContent.get_initial_phone_messages()
	for index in initial_messages.size():
		if initial_messages[index] is Dictionary:
			initial_messages[index].message_sequence = index + 1
	return {
		"save_version": CONFIG.save_compatibility_version,
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
		"consecutive_hungry_days": 0,
		"starvation_ending_unlocked": false,
		"starvation_ending_triggered_day_id": -1,
		"hunger_checked_day_id": -1,
		"weekday_index": 0,
		"calendar_day_id": 0,
		"completed_story_days": 0,
		"last_ram_settled_story_day_id": -1,
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
		"tutorial_completed": false,
		"stress_value": CONFIG.stress_default,
		"shotgun_unlocked": false,
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
		# Persistent character-card stats.  These live in the same save dictionary
		# as the rest of the profile so a new Dream does not reset them.
		"character_hp_cells": CONFIG.character_card_default_hp_cells,
		# character_speed_cells 不再写入新存档：Speed 属性已删除，移动固定 200。
		# 旧存档若仍带该字段，会被安静忽略，不影响读取。
		"current_dream_layer": 1,
		"dream_layer_reached": 1,
		"defeated_boss_ids": [],
		# 电脑当天是否已打开（false -> 息屏素材；新的一天开始时重置，见 _reset_daily_state）。
		"computer_opened_today": false,
		"permanent_upgrades": {
			"visual_cortex": 0,
			"hippocampus": 0,
			"prefrontal": 0
		}
	}


func _show_main_menu(with_transition: bool = false) -> void:
	PauseManager.clear_all()
	var saved_state := _load_current_version_progress()
	if not saved_state.is_empty():
		persistent_day_state = _merge_with_defaults(saved_state)
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)
	var menu := MAIN_MENU_SCENE.instantiate()
	menu.has_save = SAVE_STORE.has_valid_save()
	menu.configure_progression(persistent_day_state)
	menu.continue_requested.connect(_continue_game)
	menu.new_game_requested.connect(_start_new_game)
	menu.global_progress_changed.connect(_on_global_progress_changed)
	menu.quit_requested.connect(_quit_game)
	if with_transition and is_instance_valid(current_screen):
		# 0.20s fade-out + 0.20s fade-in = 0.40s total return transition.
		_transition_to(menu, RETURN_TO_MENU_FADE_HALF_DURATION)
	else:
		_set_screen(menu)


func _on_global_progress_changed() -> void:
	_save_progress()
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)


func _start_new_game() -> void:
	persistent_day_state = _create_initial_state()
	# 新开存档继承历史解锁的武器（全局记录），避免已解锁武器被重新锁上。
	UNLOCK_STORE.apply_to(persistent_day_state)
	last_summary.clear()
	night_state = _fresh_night_state()
	debug_console.configure(persistent_day_state, _on_debug_ram_changed)
	_commit_day_start()
	_show_opening()


func _continue_game() -> void:
	var loaded := _load_current_version_progress()
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
	var had_tutorial_completed := loaded.has("tutorial_completed")
	var legacy_weekday_index := int(loaded.get("weekday_index", 0))
	for key in defaults:
		if not loaded.has(key):
			loaded[key] = defaults[key]
	var upgrades: Dictionary = loaded.get("permanent_upgrades", {})
	for id in defaults.permanent_upgrades:
		if not upgrades.has(id):
			upgrades[id] = 0
	loaded.permanent_upgrades = upgrades
	# v0.4.7曾短暂保存Story局内卡片；最新规则为每个Dream重置，迁移时丢弃该旧字段。
	loaded.erase("story_upgrade_levels")
	loaded.stress_value = clampi(int(loaded.get("stress_value", CONFIG.stress_default)), 0, CONFIG.stress_max)
	loaded.is_unemployed = bool(loaded.get("is_unemployed", false)) if had_is_unemployed else legacy_unemployed
	loaded.unemployed = loaded.is_unemployed
	loaded.calendar_day_id = maxi(int(loaded.get("calendar_day_id", 0)) if had_calendar_day_id else legacy_weekday_index, 0)
	# Older saves never had onboarding state.  A profile already beyond Day 1
	# must not be sent backwards into the one-time tutorial.
	if not had_tutorial_completed:
		loaded.tutorial_completed = int(loaded.calendar_day_id) > 0
	if not had_shotgun_unlock:
		loaded.shotgun_unlocked = int(loaded.weekday_index) >= 1
	_migrate_online_messages(loaded)
	_ensure_daily_generated_state(loaded)
	return loaded


func _fresh_night_state() -> Dictionary:
	return {
		"melatonin_count": 0,
		"is_hungry_run": false,
		"run_stress_value": clampi(int(persistent_day_state.get("stress_value", CONFIG.stress_default)), 0, CONFIG.stress_max),
		"has_tarot_card": false,
		"selected_tarot_card_id": &"",
		"selected_tarot_reversed": false
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
	persistent_day_state.save_version = CONFIG.save_compatibility_version
	# 存档时把当前已解锁的武器同步到全局（跨存档继承）。
	UNLOCK_STORE.sync_from(persistent_day_state)
	SAVE_STORE.save_game(persistent_day_state)


func _load_current_version_progress() -> Dictionary:
	var loaded := SAVE_STORE.load_game()
	if loaded.is_empty():
		return {}
	if str(loaded.get("save_version", "")) == CONFIG.save_compatibility_version:
		return loaded
	# 版本变化只清理游戏进度：主存档与跨存档武器解锁都属于Progression；
	# SettingsManager的user://game_settings.cfg完全独立，不在这里触碰。
	SAVE_STORE.clear_game()
	UNLOCK_STORE.clear_all()
	var fresh := _create_initial_state()
	SAVE_STORE.save_game(fresh)
	return fresh


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
	preload("res://scripts/app/game_input_actions.gd").configure()


func _show_opening() -> void:
	last_summary.clear()
	var opening := OPENING_SCENE.instantiate()
	opening.text_event_id = &"opening_first_night"
	opening.opening_finished.connect(_show_bedroom.bind(false))
	_transition_to(opening)


func _show_bedroom(after_dream: bool = false) -> void:
	var bedroom := BEDROOM_SCENE.instantiate()
	bedroom.phone_open_requested.connect(_open_game_phone_from_bedroom)
	bedroom.phone_close_requested.connect(_close_game_phone_from_bedroom)
	bedroom.phone_story_effect_requested.connect(_play_game_phone_story_effect)
	bedroom.sleep_requested.connect(_start_story_dream)
	bedroom.save_requested.connect(_save_progress)
	bedroom.story_weapon_changed.connect(_on_story_weapon_equipped)
	bedroom.after_dream = after_dream
	bedroom.summary = last_summary.duplicate(true)
	bedroom.persistent_state = persistent_day_state
	bedroom.weekday_name = _get_weekday_name()
	_transition_to(bedroom)


func _open_game_phone_from_bedroom(page: StringName = &"home") -> void:
	if not is_instance_valid(game_phone) or not bool(game_phone.call("can_open")):
		return
	game_phone.call("open_phone")
	if page != &"home":
		var screen := game_phone.get("screen") as Control
		if is_instance_valid(screen) and screen.has_method("open_app"):
			screen.call("open_app", page)


func _close_game_phone_from_bedroom() -> void:
	if is_instance_valid(game_phone) and bool(game_phone.call("is_open")):
		game_phone.call("close_phone", true)


func _play_game_phone_story_effect(effect: StringName) -> void:
	if is_instance_valid(game_phone) and bool(game_phone.call("is_open")) and game_phone.has_method("play_story_effect"):
		game_phone.call("play_story_effect", effect)


func _start_story_dream(melatonin_count: int = 0, is_hungry_run: bool = false) -> void:
	if _register_hunger_sleep_for_day():
		_show_starvation_ending()
		return
	night_state.melatonin_count = clampi(melatonin_count, 0, CONFIG.melatonin_nightly_use_limit)
	night_state.is_hungry_run = is_hungry_run
	night_state.run_stress_value = clampi(int(persistent_day_state.get("stress_value", CONFIG.stress_default)), 0, CONFIG.stress_max)
	persistent_day_state.is_hungry_run = is_hungry_run
	persistent_day_state.has_entered_dream = true
	var weapon_id := _validated_story_weapon_id()
	if should_enter_tutorial(persistent_day_state):
		_show_tutorial(weapon_id)
	else:
		_show_reception(weapon_id)


static func should_enter_tutorial(state: Dictionary) -> bool:
	return STORY_TUTORIAL_ENABLED and int(state.get("calendar_day_id", 0)) == 0 and not bool(state.get("tutorial_completed", false))


func _show_tutorial(weapon_id: String) -> void:
	var tutorial := TUTORIAL_SCENE.instantiate()
	if tutorial.has_method("configure_tutorial"):
		tutorial.call("configure_tutorial", weapon_id, persistent_day_state)
	tutorial.connect("tutorial_finished", Callable(self, "_on_tutorial_finished").bind(weapon_id), CONNECT_ONE_SHOT)
	_transition_to(tutorial, 0.65)


func _on_tutorial_finished(weapon_id: String) -> void:
	if bool(persistent_day_state.get("tutorial_completed", false)):
		return
	# Completion is committed only after the authored exit sequence.  Mirror the
	# value into the same-day snapshot so pause/menu recovery cannot replay it.
	persistent_day_state.tutorial_completed = true
	day_start_snapshot.set_persistent_value(&"tutorial_completed", true)
	_save_progress()
	_show_reception(weapon_id)


func _show_reception(weapon_id: String) -> void:
	var reception := RECEPTION_SCENE.instantiate()
	if reception.has_method("configure_reception"):
		reception.call("configure_reception", weapon_id, persistent_day_state, night_state)
	# Keep the connection alive when a failed preparation returns to this lobby.
	reception.connect("elevator_entered", Callable(self, "_on_reception_elevator_entered").bind(weapon_id))
	if reception.has_signal("weapon_equipped"):
		reception.connect("weapon_equipped", Callable(self, "_on_story_weapon_equipped"))
	_transition_to(reception)


func _on_reception_elevator_entered(weapon_id: String) -> void:
	_show_dream(weapon_id, true)


func _show_dream(weapon_id: String, from_reception: bool = false) -> void:
	var dream := DREAM_SCENE.instantiate()
	dream.set_meta(&"reception_elevator_journey", from_reception)
	# Every dream entry is a brand-new run: a fresh seed gives each day (and any
	# same-day re-entry) a newly generated building. Tests keep seeding explicitly.
	dream.seed = randi()
	var story_weapon_ids: Array[String] = _get_available_weapon_ids(_story_weapon_unlock_state())
	var run_config: DemoConfig = CONFIG.duplicate(true)
	# The result belongs to the morning after this bedroom night.
	var is_sunday := (int(persistent_day_state.get("weekday_index", 0)) + 1) % WEEKDAYS.size() == 6
	run_config.alarm_start_minutes = CONFIG.story_wake_minutes
	run_config.dream_start_minutes = _dream_start_minutes_for_melatonin_count(int(night_state.get("melatonin_count", 0)))
	var has_tarot_card := bool(night_state.get("has_tarot_card", false))
	var selected_tarot_card_id := StringName(night_state.get("selected_tarot_card_id", &""))
	var selected_tarot_reversed := bool(night_state.get("selected_tarot_reversed", false))
	if "has_tarot_card" in dream:
		dream.set("has_tarot_card", has_tarot_card)
	if "selected_tarot_card_id" in dream:
		dream.set("selected_tarot_card_id", selected_tarot_card_id)
	if "selected_tarot_reversed" in dream:
		dream.set("selected_tarot_reversed", selected_tarot_reversed)
	if "night_state" in dream:
		dream.set("night_state", night_state.duplicate(true))
	dream.set_meta("has_tarot_card", has_tarot_card)
	dream.set_meta("selected_tarot_card_id", selected_tarot_card_id)
	dream.set_meta("selected_tarot_reversed", selected_tarot_reversed)
	dream.set_meta("night_state", night_state.duplicate(true))
	if dream.has_method("configure_campaign_run"):
		dream.configure_campaign_run(
			weapon_id,
			story_weapon_ids,
			run_config,
			persistent_day_state,
			maxi(1, int(persistent_day_state.get("calendar_day_id", 0)) + 1),
			is_sunday,
			bool(night_state.get("is_hungry_run", false)),
			int(night_state.get("run_stress_value", CONFIG.stress_default))
		)
		dream.weapon_equipped.connect(_on_story_weapon_equipped)
		dream.profile_changed.connect(_on_dream_profile_changed)
		dream.dream_finished.connect(_show_results)
		_transition_to_dream(dream)
		return
	# Legacy 2D Dream is retired; do not fall back to its node contract.
	push_error("The 3D Dream scene must implement configure_campaign_run")
	dream.free()


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
	_save_progress()
	var ending := OPENING_SCENE.instantiate()
	ending.ending_mode = true
	ending.text_event_id = &"ending_normal_life"
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
	# 记录完成后重置为"结局日早晨"（会清掉上面的触发标记），
	# 让继续游戏后重新体验当天时可再次触发饿死结局。
	_reset_state_to_bedroom_start()
	_save_progress()
	var ending := OPENING_SCENE.instantiate()
	ending.ending_mode = true
	ending.text_event_id = &"ending_starvation"
	ending.return_to_menu_requested.connect(_return_from_ending_to_main_menu)
	_transition_to(ending)


func _return_from_ending_to_main_menu() -> void:
	_reset_dream_time()
	last_summary.clear()
	night_state = _fresh_night_state()
	_show_main_menu(true)


func _start_new_day() -> void:
	# Future cross-day data can be retained separately; all current run state is discarded.
	_reset_dream_time()
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
	var active_phone := current_screen.get_node_or_null("PhoneLayer/BedroomPhone")
	if active_phone != null:
		active_phone.call("configure_state", persistent_day_state)


func _on_debug_dream_jump_requested(weapon_id: String) -> void:
	var saved_state := _load_current_version_progress()
	if not saved_state.is_empty():
		persistent_day_state = _merge_with_defaults(saved_state)
		UNLOCK_STORE.apply_to(persistent_day_state)
	var chosen_weapon := weapon_id.strip_edges().to_lower()
	if chosen_weapon.is_empty():
		chosen_weapon = _validated_story_weapon_id()
	if chosen_weapon.is_empty():
		chosen_weapon = "basic"
	if is_instance_valid(game_phone):
		game_phone.call("abort")
	PauseManager.clear_all()
	_show_dream(chosen_weapon)


func _reset_dream_time() -> void:
	var time_controller: Node = get_tree().root.get_node_or_null("DreamTimeController") as Node
	if time_controller != null and time_controller.has_method("exit_dream_time_mode"):
		time_controller.call("exit_dream_time_mode")


func _set_screen(next_screen: Node) -> void:
	if is_instance_valid(game_phone):
		game_phone.call("abort")
	if is_instance_valid(current_screen):
		current_screen.queue_free()
	_supported_dream_world = null
	if _is_supported_dream_world(next_screen):
		_supported_dream_world = next_screen as Node3D
		var pixel_screen := SELECTIVE_PIXEL_SCENE.instantiate()
		pixel_screen.set(&"preview_mode", false)
		pixel_screen.set(&"initial_selective_enabled", bool(SettingsManager.get_setting(&"pixelation_enabled", true)))
		pixel_screen.set(&"palette_enabled", SettingsManager.get_palette_enabled())
		pixel_screen.set(&"world", next_screen)
		current_screen = pixel_screen
	else:
		current_screen = next_screen
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	scene_container.add_child(current_screen)
	pause_allowed = current_screen.scene_file_path != "res://scenes/ui/main_menu.tscn"
	_apply_palette_enabled(SettingsManager.get_palette_enabled())


func _active_pixelation_screen() -> Node:
	if is_instance_valid(current_screen) and is_instance_valid(_supported_dream_world) and current_screen.scene_file_path == SELECTIVE_PIXEL_SCENE.resource_path and current_screen.get("world") == _supported_dream_world:
		return current_screen
	return null


func _is_supported_dream_world(screen: Node) -> bool:
	return screen is Node3D and screen.scene_file_path in [TUTORIAL_SCENE.resource_path, DREAM_SCENE.resource_path, RECEPTION_SCENE.resource_path]


func _open_pause_menu() -> void:
	PauseManager.request_pause(PauseManager.ESC_MENU)
	pause_menu.open_pause()


func _resume_from_pause() -> void:
	pause_menu.close_pause()
	PauseManager.release_pause(PauseManager.ESC_MENU)


func _exit_to_main_menu_from_pause() -> void:
	pause_menu.close_pause()
	PauseManager.clear_all()
	_reset_dream_time()
	_restore_day_start_snapshot()
	_show_main_menu(true)


func _migrate_online_messages(state: Dictionary) -> void:
	var templates: Array = TextContent.get_phone_message_templates()
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
		_add_online_message(state, _phone_message_for_day(&"mom_hunger_day3", day_id))
		state.mom_hunger_message_sent = true
		state.mom_hunger_message_day_id = day_id
	if game_day_number >= 3 and not bool(state.get("day3_quicklink_news_sent", false)):
		_add_online_message(state, _phone_message_for_day(&"day3_quicklink_news", day_id))
		state.day3_quicklink_news_sent = true
		state.day3_quicklink_news_day_id = day_id
	if game_day_number >= 5 and not bool(state.get("day5_northern_times_sent", false)):
		_add_online_message(state, _phone_message_for_day(&"day5_northern_times", day_id))
		state.day5_northern_times_sent = true
		state.day5_northern_times_day_id = day_id


func _phone_message_for_day(message_id: StringName, day_id: int) -> Dictionary:
	var message := TextContent.get_phone_message(message_id)
	message.received_day_id = day_id
	message.is_read = false
	return message


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
	var sunday_event := TextContent.get_text_event(StringName("sunday_event_%d" % event_id), {"balance_delta": formatted_delta})
	state.pending_sunday_notice = str(sunday_event.get("lines", [{}])[0].get("text", ""))


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
	state.pending_unlock_notice = str(TextContent.get_text_event(&"shotgun_unlock_bedroom_notice").get("lines", [{}])[0].get("text", ""))
	return true


func _transition_to(next_screen: Node,duration: float=0.25)->void:
	await _enqueue_transition(next_screen,duration,false)

func _transition_to_dream(dream: Node,duration: float=0.25)->void:
	await _enqueue_transition(dream,duration,true)

func _enqueue_transition(screen: Node,duration: float,is_dream: bool)->void:
	if is_instance_valid(game_phone):
		game_phone.call("abort")
	transition_queue.append({"screen":screen,"duration":duration,"is_dream":is_dream})
	if transition_running: return
	transition_running=true
	while not transition_queue.is_empty():
		var next: Dictionary=transition_queue.pop_front()
		if not is_instance_valid(next.screen): continue
		if bool(next.is_dream): await _run_dream_transition(next.screen,float(next.duration))
		else: await _run_transition(next.screen,float(next.duration))
	transition_running=false

func _run_transition(next_screen: Node,duration: float)->void:
	var previous_mode:=scene_container.process_mode
	scene_container.process_mode=Node.PROCESS_MODE_DISABLED
	if transition_director!=null:
		await transition_director.cover("pixel_blocks",duration)
	else:
		fade.mouse_filter=Control.MOUSE_FILTER_STOP
		var cover:=create_tween()
		cover.tween_property(fade,"color:a",1.0,duration)
		await cover.finished
	_set_screen(next_screen)
	scene_container.process_mode=previous_mode
	await preload("res://scripts/ui/pixel_transition.gd").present(get_tree(),2)
	scene_container.process_mode=Node.PROCESS_MODE_DISABLED
	if transition_director!=null:
		await transition_director.reveal(duration*1.2)
	else:
		var reveal:=create_tween()
		reveal.tween_property(fade,"color:a",0.0,duration*1.2)
		await reveal.finished
		fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_container.process_mode=previous_mode


func _run_dream_transition(dream: Node, duration: float) -> void:
	if dream.get_meta(&"reception_elevator_journey", false) and is_instance_valid(_supported_dream_world) and _supported_dream_world.has_method("rollback_elevator_entry"):
		await preload("res://scripts/app/reception_elevator_journey.gd").run(self, dream)
		return
	var previous_mode:=scene_container.process_mode
	scene_container.process_mode=Node.PROCESS_MODE_DISABLED
	if transition_director != null:
		await transition_director.cover("pixel_blocks", duration)
	else:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween := create_tween()
		tween.tween_property(fade, "color:a", 1.0, duration)
		await tween.finished

	if loading_overlay != null:
		loading_overlay.show_loading("正在构建梦境宅邸...")
		if dream.has_signal("generation_progress"):
			dream.generation_progress.connect(func(ratio: float, msg: String):
				if loading_overlay != null:
					loading_overlay.set_progress(ratio, msg)
			)
		await preload("res://scripts/ui/pixel_transition.gd").present(get_tree(),2)

	scene_container.process_mode=previous_mode
	var prepare_rendering: bool=dream.has_method("begin_firearm_render_preparation")
	var was_paused:=get_tree().paused
	if prepare_rendering:
		dream.set("loading_render_preparation_pending",true)
		get_tree().paused=true
	_set_screen(dream)
	if prepare_rendering:
		for frame in 2: await get_tree().process_frame
		if is_instance_valid(dream) and dream.is_inside_tree():
			if loading_overlay!=null: loading_overlay.set_progress(0.98,"正在准备战斗光效...")
			var preparation: Dictionary={"skipped":"diagnostic_baseline","cancelled":false,"temporary_sources":0}
			if bool(dream.call("begin_firearm_render_preparation")):
				# The coroutine belongs to a RefCounted worker, not a scene that
				# may be removed during loading. Never resume on a freed Dream.
				preparation=await preload("res://scripts/dream/firearm_render_preparation.gd").run(get_tree(),dream)
			if is_instance_valid(dream) and dream.is_inside_tree(): dream.call("complete_firearm_render_preparation",preparation)
		get_tree().paused=was_paused
		if is_instance_valid(dream) and dream.is_inside_tree(): dream.call("finish_loading_render_preparation")

	if loading_overlay != null:
		loading_overlay.set_progress(1.0, "神经同步完成")
		await preload("res://scripts/ui/pixel_transition.gd").present(get_tree())
		await loading_overlay.hide_loading()

	if transition_director != null:
		await transition_director.reveal(duration * 1.2)
	else:
		var reveal := create_tween()
		reveal.tween_property(fade, "color:a", 0.0, duration * 1.2)
		await reveal.finished
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _get_available_weapon_ids(unlock_state: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for weapon_id in DreamGunAtlas.get_weapon_ids():
		if weapon_id == "shotgun" and not bool(unlock_state.get(weapon_id, false)):
			continue
		pool.append(weapon_id)
	return pool


func _story_weapon_unlock_state() -> Dictionary:
	return {
		"shotgun": bool(persistent_day_state.get("shotgun_unlocked", false))
	}


func _validated_story_weapon_id() -> String:
	var current := str(persistent_day_state.get("current_weapon_id", "basic"))
	if DreamGunAtlas.has_weapon(current) and current in _get_available_weapon_ids(_story_weapon_unlock_state()):
		return current
	# A deleted/unknown weapon from an old save is intentionally empty-handed,
	# never silently converted into the basic gun.
	persistent_day_state.current_weapon_id = ""
	return ""


func _on_story_weapon_equipped(weapon_id: String) -> void:
	if not weapon_id in _get_available_weapon_ids(_story_weapon_unlock_state()):
		return
	persistent_day_state.current_weapon_id = weapon_id
	day_start_snapshot.set_persistent_value(&"current_weapon_id", weapon_id)
	_save_progress()


func _on_dream_profile_changed(_profile: Dictionary) -> void:
	# profile_state is the persistent_day_state dictionary, so saving here keeps
	# persistent character and weapon state across runs without a second store.
	_save_progress()


func _scaled_cursor(source: Texture2D, multiplier: int) -> Texture2D:
	var image := source.get_image()
	image.resize(image.get_width() * multiplier, image.get_height() * multiplier, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
