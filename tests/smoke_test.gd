extends SceneTree

const DREAM_SCENE := preload("res://scenes/dream/dream_world.tscn")
const BEDROOM_SCENE := preload("res://scenes/bedroom/bedroom.tscn")
const OPENING_SCENE := preload("res://scenes/ui/opening.tscn")
const RESULTS_SCENE := preload("res://scenes/ui/results.tscn")
const WEAPON_SELECTION_SCENE := preload("res://scenes/ui/weapon_selection.tscn")
const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const CONFIG_RESOURCE := preload("res://resources/demo_config.tres")

var failures: Array[String] = []


func _initialize() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "confirm", "restart_demo", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_test_default_config_and_formula()
	await _test_mouse_opening()
	await _test_phone_states()
	await _test_weapon_selection()
	await _test_dream_combat_dash_and_alarm()
	await _test_results_sequence()
	await _test_new_day_reset()
	if failures.is_empty():
		print("SMOKE TEST PASSED: spawn curve -> mouse text -> phone apps -> beam -> dash -> leveling -> alarm -> results")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_default_config_and_formula() -> void:
	var dream := DREAM_SCENE.instantiate()
	dream.config = CONFIG_RESOURCE
	_assert(dream.get_experience_requirement(1) == 20, "Level 1 requirement must be 20.")
	_assert(dream.get_experience_requirement(2) == 64, "Level 2 requirement must be 64.")
	_assert(dream.get_experience_requirement(3) == 512, "Level 3 requirement must be 512.")
	_assert(dream.get_experience_requirement(4) == 4096, "Level 4 requirement must be 4096.")
	_assert(dream.get_experience_requirement(5) == 32767, "Level 5 requirement must be capped at 32767.")
	_assert(CONFIG_RESOURCE.enemy_initial_spawn_interval == 2.0, "Initial spawn interval must default to 2 seconds.")
	_assert(CONFIG_RESOURCE.enemy_minimum_spawn_interval == 0.65, "Minimum spawn interval must default to 0.65 seconds.")
	_assert(CONFIG_RESOURCE.beam_damage == 20.0 and CONFIG_RESOURCE.beam_range == 150.0, "Beam defaults do not match the specification.")
	_assert(CONFIG_RESOURCE.dash_distance == 100.0 and CONFIG_RESOURCE.dash_cooldown == 2.0, "Dash defaults do not match the specification.")
	dream.free()


func _test_mouse_opening() -> void:
	var config: DemoConfig = CONFIG_RESOURCE.duplicate(true)
	config.opening_characters_per_second = 5.0
	var opening := OPENING_SCENE.instantiate()
	opening.config = config
	root.add_child(opening)
	await create_timer(0.3).timeout
	_assert(opening.visible_characters > 0 and opening.visible_characters < opening.PARAGRAPHS[0].length(), "Opening did not type a partial first sentence.")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_ENTER
	opening._gui_input(key_event)
	_assert(opening.visible_characters < opening.PARAGRAPHS[0].length(), "Enter incorrectly advanced opening text.")
	var click := _mouse_click(Vector2(320, 180))
	opening._gui_input(click)
	_assert(opening.visible_characters == opening.PARAGRAPHS[0].length(), "Mouse click did not complete the sentence.")
	opening._gui_input(click)
	_assert(opening.paragraph_index == 1, "Second mouse click did not advance exactly one sentence.")
	var state := {"finished": false}
	opening.opening_finished.connect(func() -> void: state.finished = true)
	for index in range(1, opening.PARAGRAPHS.size()):
		opening.visible_characters = opening.PARAGRAPHS[index].length()
		opening._gui_input(click)
	_assert(state.finished, "Opening did not finish through mouse-only progression.")
	opening.queue_free()
	await process_frame


func _test_phone_states() -> void:
	var bedroom := BEDROOM_SCENE.instantiate()
	var phone: Control = bedroom.get_node("PhoneLayer/BedroomPhone")
	var config: DemoConfig = CONFIG_RESOURCE.duplicate(true)
	config.phone_animation_seconds = 0.02
	config.phone_fingerprint_animation_seconds = 0.02
	phone.config = config
	root.add_child(bedroom)
	await process_frame
	phone._gui_input(_mouse_click(Vector2(75, 12)))
	await create_timer(0.06).timeout
	_assert(phone.state == phone.PhoneState.EXPANDED, "Phone did not expand.")
	_assert(phone.screen_state == phone.ScreenState.LOCKED, "Phone did not open on the lock screen.")
	phone._gui_input(_mouse_click(phone.FINGERPRINT_AREA.get_center()))
	await create_timer(0.06).timeout
	_assert(phone.screen_state == phone.ScreenState.HOME, "Fingerprint did not unlock the phone.")
	phone._gui_input(_mouse_click(phone._app_rect(0).get_center()))
	_assert(phone.screen_state == phone.ScreenState.ONLINE and phone.messages.size() >= 2, "ONLINE app or data did not open.")
	phone._gui_input(_mouse_click(phone.BACK_BUTTON.get_center()))
	phone._gui_input(_mouse_click(phone._app_rect(1).get_center()))
	_assert(phone.screen_state == phone.ScreenState.SOMNIA, "SOMNIA NET app did not open.")
	phone._gui_input(_mouse_click(phone.BACK_BUTTON.get_center()))
	phone._gui_input(_mouse_click(phone._app_rect(2).get_center()))
	_assert(phone.screen_state == phone.ScreenState.QUICKLINK and phone.quicklink_items.size() == 2, "QuickLink app or product data did not open.")
	phone._gui_input(_mouse_click(phone.BACK_BUTTON.get_center()))
	phone._gui_input(_mouse_click(phone._app_rect(3).get_center()))
	_assert(phone.screen_state == phone.ScreenState.SETTINGS, "Settings placeholder did not open.")
	phone._gui_input(_mouse_click(phone.COLLAPSE_AREA.get_center()))
	await create_timer(0.06).timeout
	_assert(phone.state == phone.PhoneState.COLLAPSED, "Explicit collapse control did not retract the phone.")
	bedroom.queue_free()
	await process_frame


func _test_weapon_selection() -> void:
	var selection := WEAPON_SELECTION_SCENE.instantiate()
	root.add_child(selection)
	await process_frame
	var state := {"weapon": ""}
	selection.weapon_selected.connect(func(id: String) -> void: state.weapon = id)
	selection._gui_input(_mouse_click(selection.BEAM_CARD.get_center()))
	_assert(state.weapon == "beam", "Mouse card selection did not choose the beam weapon.")
	selection.queue_free()
	await process_frame


func _test_dream_combat_dash_and_alarm() -> void:
	var config: DemoConfig = CONFIG_RESOURCE.duplicate(true)
	config.dream_start_minutes = 419.8
	config.alarm_start_minutes = 420.0
	config.real_seconds_per_game_minute = 0.05
	config.enemy_initial_spawn_interval = 2.0
	config.enemy_minimum_spawn_interval = 0.65
	config.base_enemy_health = 20.0
	config.base_enemy_damage = 0.0
	config.enemy_separation_strength = 28.0
	config.beam_attack_interval = 0.12
	config.beam_display_seconds = 0.08
	config.dash_duration = 0.10
	config.dash_cooldown = 2.0
	config.base_wake_hold_seconds = 0.20
	config.extra_hold_every_seconds = 100.0
	config.extra_hold_seconds = 0.0

	var dream := DREAM_SCENE.instantiate()
	dream.config = config
	dream.selected_weapon_id = "beam"
	dream.get_node("DreamClock").config = config
	dream.get_node("EnemySpawner").config = config
	dream.get_node("UILayer/WakeOverlay").config = config
	root.add_child(dream)
	await process_frame
	dream.spawner.running = false

	# Linear interval is calculated from the configured start time, including alternate starts.
	dream.spawner.set_dream_time(config.dream_start_minutes)
	_assert(is_equal_approx(dream.spawner.get_current_spawn_interval(), 2.0), "Spawn interval at dream start is not 2 seconds.")
	dream.spawner.set_dream_time((config.dream_start_minutes + config.alarm_start_minutes) * 0.5)
	_assert(is_equal_approx(dream.spawner.get_current_spawn_interval(), 1.325), "Spawn interval is not linearly interpolated at midpoint.")
	dream.spawner.set_dream_time(430.0)
	_assert(is_equal_approx(dream.spawner.get_current_spawn_interval(), 0.65), "Spawn interval dropped below or did not reach the configured minimum.")

	# Three stationary enemies on one line must all be hit by one beam emission.
	for offset in [45.0, 90.0, 135.0]:
		dream._on_spawn_requested(dream.player.position + Vector2(offset, 0), 1.0, 0.0)
	for enemy in get_nodes_in_group("dream_enemies"):
		enemy.movement_speed = 0.0
	dream.player.beam_weapon._fire_beam(Vector2.RIGHT)
	await create_timer(0.12).timeout
	_assert(dream.kills >= 3, "One beam did not damage all enemies along its path.")
	_assert(dream.player.selected_weapon_id == "beam", "Dream did not retain the selected initial weapon.")

	# Dash uses the last valid direction, grants immunity, and remains inside bounds.
	dream.player.position = Vector2(320, 190)
	dream.player.last_move_direction = Vector2.RIGHT
	var health_before: float = dream.player.current_health
	Input.action_release("dash")
	await physics_frame
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	_assert(dream.player.dashing, "Space did not start a dash.")
	dream.player.receive_damage(50.0)
	_assert(dream.player.current_health == health_before, "Player took damage during dash immunity.")
	await create_timer(0.18).timeout
	_assert(not dream.player.dashing, "Dash did not finish.")
	_assert(absf(dream.player.position.x - 420.0) < 2.0, "Dash did not travel the configured 100 pixels.")
	_assert(dream.player.dash_cooldown_left > 0.0 and dream.hud.dash_total == 2.0, "Dash cooldown or HUD state was not updated.")
	dream.player.position = Vector2(dream.ARENA_BOUNDS.end.x - 10.0, 190)
	dream.player.dash_cooldown_left = 0.0
	await physics_frame
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	await create_timer(0.08).timeout
	_assert(dream.player.position.x <= dream.ARENA_BOUNDS.end.x, "Dash crossed the arena boundary.")

	# Soft separation resolves an exact overlap without explosive velocity.
	dream.player.set_attacking_enabled(false)
	dream._on_spawn_requested(Vector2(200, 150), 1.0, 0.0)
	dream._on_spawn_requested(Vector2(200, 150), 1.0, 0.0)
	var overlap_enemies := get_nodes_in_group("dream_enemies")
	if overlap_enemies.size() >= 2:
		var a: Node2D = overlap_enemies[-1]
		var b: Node2D = overlap_enemies[-2]
		await create_timer(0.25).timeout
		_assert(a.global_position.distance_to(b.global_position) > 1.0, "Enemy soft separation did not resolve overlap.")

	# Large XP keeps its remainder and queues all upgrade choices for the selected beam.
	var grant: int = 601 - dream.experience
	dream._on_experience_collected(grant)
	_assert(dream.level == 4 and dream.experience == 5 and dream.pending_upgrades == 3, "Large XP did not produce three levels with five XP remaining.")
	var beam_damage_before: float = dream.player.beam_weapon.damage
	for _upgrade in range(3):
		dream._on_upgrade_chosen({"id":"damage_boost", "family":"damage_boost", "rarity":"blue", "name":"test", "description":"test", "max_level":99})
	_assert(dream.player.beam_weapon.damage > beam_damage_before, "Existing damage upgrade did not affect the selected beam weapon.")

	var alarm_deadline := Time.get_ticks_msec() + 2000
	while dream.phase != dream.RunPhase.ALARM and Time.get_ticks_msec() < alarm_deadline:
		await process_frame
	_assert(dream.phase == dream.RunPhase.ALARM, "Clock did not enter alarm phase.")
	var finish := {"received": false}
	dream.dream_finished.connect(func(_summary: Dictionary) -> void: finish.received = true)
	dream.player.position = dream.WAKE_POINT
	Input.action_press("interact")
	var wake_deadline := Time.get_ticks_msec() + 3500
	while not finish.received and Time.get_ticks_msec() < wake_deadline:
		await process_frame
	Input.action_release("interact")
	_assert(finish.received and is_equal_approx(Engine.time_scale, 1.0), "Wake completion failed or left slow motion active.")
	dream.queue_free()
	paused = false
	Engine.time_scale = 1.0
	await process_frame


func _test_results_sequence() -> void:
	var results := RESULTS_SCENE.instantiate()
	results.summary = {"wake_time": "08:12", "kills": 8, "level": 3, "late": true, "attendance_status": "严重迟到"}
	root.add_child(results)
	await process_frame
	_assert(results.paragraphs[0] == "闹钟已经响了很久。", "Late result selected the wrong text branch.")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_ENTER
	results._gui_input(key_event)
	_assert(results.paragraph_index == 0, "Enter incorrectly advanced result text.")
	var click := _mouse_click(Vector2(320, 180))
	for index in range(results.paragraphs.size()):
		results.visible_characters = results.paragraphs[index].length()
		results._gui_input(click)
	_assert(results.showing_summary and results.start_button.visible, "Result text did not reveal the new-day button.")
	var state := {"new_day": false}
	results.new_day_requested.connect(func() -> void: state.new_day = true)
	results.start_button.pressed.emit()
	_assert(state.new_day, "Start New Day button did not emit its mouse-button action.")
	results.queue_free()
	await process_frame
	var early_results := RESULTS_SCENE.instantiate()
	early_results.summary = {"wake_time": "07:00", "kills": 0, "level": 1, "late": false}
	root.add_child(early_results)
	await process_frame
	_assert(early_results.paragraphs[0] == "闹钟停了。" and early_results.paragraphs[-1] == "去上班了。", "On-time result branch is not preserved.")
	early_results.queue_free()
	await process_frame


func _test_new_day_reset() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.last_summary = {"wake_time": "07:12", "kills": 99, "level": 8}
	main.persistent_day_state.ram = 9
	main.persistent_day_state.balance = 1600
	main.persistent_day_state.permanent_upgrades.visual_cortex = 2
	Engine.time_scale = 0.4
	main._start_new_day()
	await create_timer(0.9, true, false, true).timeout
	_assert(main.last_summary.is_empty(), "Starting a new day did not clear temporary run summary data.")
	_assert(is_equal_approx(Engine.time_scale, 1.0), "Starting a new day did not restore normal time scale.")
	_assert(int(main.persistent_day_state.weekday_index) == 1, "Starting a new day did not advance Monday to Tuesday.")
	_assert(int(main.persistent_day_state.ram) == 9 and int(main.persistent_day_state.balance) == 1600 and int(main.persistent_day_state.permanent_upgrades.visual_cortex) == 2, "New day did not preserve meta currencies or permanent upgrades.")
	_assert(is_instance_valid(main.current_screen) and main.current_screen.name == "Bedroom", "Starting a new day did not return to the bedroom.")
	if is_instance_valid(main.current_screen):
		_assert(not main.current_screen.after_dream, "New-day bedroom retained the previous run presentation state.")
	main.queue_free()
	await process_frame


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
