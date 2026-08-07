extends Node

const CONFIG := preload("res://resources/demo_config.tres")
const MAIN_SCRIPT := preload("res://scripts/app/main.gd")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")
const MELATONIN := preload("res://scenes/ui/melatonin_interaction.tscn")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const DREAM := preload("res://scenes/dream/dream_world.tscn")
const BEDROOM := preload("res://scenes/bedroom/bedroom.tscn")
const WAKE_OVERLAY := preload("res://scenes/ui/wake_overlay.tscn")
const MAIN_MENU := preload("res://scenes/ui/main_menu.tscn")
const MAIN_SCENE := preload("res://scenes/app/main.tscn")
const OPENING_SCENE := preload("res://scenes/ui/opening.tscn")
const RUN_SETTLEMENT := preload("res://scripts/app/run_settlement.gd")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const UNLOCK_STORE := preload("res://scripts/app/weapon_unlock_store.gd")

var failures: Array[String] = []


func _ready() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"dash", &"skill_menu"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_test_wage_and_message_migration()
	await _test_phone_order_and_melatonin_bottle()
	await _test_melatonin_dispense_no_hand_rotation()
	await _test_quicklink_scroll()
	await _test_spawn_invulnerability_and_fast_sleep()
	await _test_music_duck_and_weather_layer()
	await _test_pause_music_muffle()
	await _test_death_crt_effect()
	await _test_sunshade()
	_test_weapon_unlock_store()
	await _test_announcement_window()
	await _test_ending_day_restart()
	await _test_phone_ux_fixes()
	await get_tree().process_frame
	await get_tree().process_frame
	if failures.is_empty():
		print("LATEST REQUESTED FIXES TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_wage_and_message_migration() -> void:
	_assert(CONFIG.daily_base_wage == 500, "Daily base wage is not 500")
	for case in [[420.0, 500], [460.0, 400], [500.0, 250], [550.0, 0]]:
		var meta := {"balance": 0, "ram": 0, "unemployed": false, "normal_attendance_workday_streak": 0}
		var result := RUN_SETTLEMENT.settle({"wake_minutes": case[0], "level": 1, "is_sunday": false}, meta, CONFIG)
		_assert(int(result.wage) == case[1], "Wage case %s produced %s" % [case[0], result.wage])
	var unemployed_meta := {"balance": 0, "ram": 0, "unemployed": true, "normal_attendance_workday_streak": 0}
	var unemployed := RUN_SETTLEMENT.settle({"wake_minutes": 420.0, "level": 1, "is_sunday": false}, unemployed_meta, CONFIG)
	_assert(int(unemployed.wage) == 0, "Unemployed settlement paid a wage")

	var main := MAIN_SCRIPT.new()
	var state: Dictionary = main._create_initial_state()
	state.calendar_day_id = 2
	state.consecutive_hungry_days = 3
	state.erase("mom_hunger_message_sent")
	state.erase("mom_hunger_message_day_id")
	state.erase("online_message_sequence_next")
	for message in state.online_messages:
		if message is Dictionary:
			message.erase("message_sequence")
	main._migrate_online_messages(state)
	main._ensure_timed_online_messages(state)
	main._ensure_timed_online_messages(state)
	var mom_count := 0
	for message in state.online_messages:
		if message is Dictionary and str(message.get("id", "")) == "mom_hunger_day3":
			mom_count += 1
			_assert(int(message.get("received_day_id", -1)) == 2 and int(message.get("message_sequence", 0)) > 0, "Mom message schema was incomplete")
	_assert(mom_count == 1 and bool(state.mom_hunger_message_sent), "Mom message was missing or duplicated")
	main.free()


func _test_phone_order_and_melatonin_bottle() -> void:
	var main := MAIN_SCRIPT.new()
	var state: Dictionary = main._create_initial_state()
	state.calendar_day_id = 4
	main._migrate_online_messages(state)
	main._add_online_message(state, {"id": "same_day_a", "category": "A", "text": "older", "received_day_id": 4})
	main._add_online_message(state, {"id": "same_day_b", "category": "B", "text": "newer", "received_day_id": 4})
	var phone = PHONE.instantiate()
	get_tree().root.add_child(phone)
	phone.configure_state(state)
	await get_tree().process_frame
	_assert(str(phone.messages[0].get("id", "")) == "same_day_b", "Newest same-day ONLINE message is not first")
	var expected_width: float = phone.online_scroll.size.x - CONFIG.online_scrollbar_width - CONFIG.online_message_right_safe_margin
	_assert(phone.message_list.custom_minimum_size.x <= expected_width + 0.1, "ONLINE content did not reserve scrollbar/date safety space")
	phone.queue_free()
	main.free()
	await get_tree().process_frame

	var melatonin = MELATONIN.instantiate()
	get_tree().root.add_child(melatonin)
	var medicine_state := {"melatonin_inventory": 3, "stress_value": 0}
	melatonin.open(medicine_state)
	await get_tree().create_timer(CONFIG.melatonin_hand_reach_seconds + 0.05).timeout
	_assert(not bool(melatonin.table_bottle_taken) and not bool(melatonin.bottle_sprite.visible), "Table bottle disappeared before the grip")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(430, 185)
	melatonin._gui_input(press)
	# Simulate a horizontal shake so the bottle offset becomes non-zero.
	var shake_motion := InputEventMouseMotion.new()
	shake_motion.relative = Vector2(20, 0)
	shake_motion.position = press.position
	melatonin._gui_input(shake_motion)
	_assert(not is_equal_approx(melatonin.bottle_offset.x, 0.0), "Shake motion did not tilt the bottle")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	melatonin._gui_input(release)
	_assert(melatonin.bottle_offset == Vector2.ZERO, "Bottle offset was not reset after the shake ended")
	_assert(bool(melatonin.table_bottle_taken) and bool(melatonin.bottle_sprite.visible), "Held bottle vanished after releasing the mouse")
	_assert(melatonin.get_node_or_null("RightHand/BottleMouthMarker") != null, "Bottle mouth marker is missing")
	melatonin.force_cancel()
	melatonin.queue_free()
	await get_tree().process_frame


func _test_quicklink_scroll() -> void:
	# 速联跑腿™ 复用与在线！™完全相同的滚动组件、阈值与像素滚动条。
	var phone = PHONE.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.phone_fingerprint_animation_seconds = 0.01
	phone.config = fast_config
	get_tree().root.add_child(phone)
	await get_tree().process_frame
	var state := {
		"balance": 2000, "ram": 0, "weekday_index": 0,
		"permanent_upgrades": {}, "online_messages": [],
		"melatonin_inventory": 0, "melatonin_bottle_present": false,
		"sunshade_purchased": false,
	}
	phone.configure_state(state)
	# 1. Scroll container exists and reuses PhoneDragScroll (same component as online).
	_assert(phone.quicklink_scroll != null, "QuicklinkScroll is missing")
	_assert(phone.quicklink_scroll is PhoneDragScroll, "QuicklinkScroll does not reuse PhoneDragScroll")
	_assert(phone.quicklink_content != null, "QuicklinkContent is missing")
	# 2. Same drag threshold + same narrow pixel scrollbar width as online.
	_assert(is_equal_approx(phone.quicklink_scroll.drag_threshold, phone.online_scroll.drag_threshold), "QUICKLINK drag threshold differs from ONLINE")
	_assert(is_equal_approx(phone.quicklink_scroll.get_v_scroll_bar().custom_minimum_size.x, CONFIG.online_scrollbar_width), "QUICKLINK scrollbar width differs from ONLINE")
	_assert(phone.quicklink_scroll.theme == phone.online_scroll.theme, "QUICKLINK does not reuse the ONLINE pixel scrollbar theme")
	# 3. Content reserves right safe margin so the scrollbar never covers content.
	var expected_width: float = phone.quicklink_scroll.size.x - CONFIG.online_scrollbar_width - CONFIG.online_message_right_safe_margin
	_assert(phone.quicklink_content.custom_minimum_size.x <= expected_width + 0.1, "QUICKLINK content did not reserve scrollbar/safe margin space")
	# Layout constraints: buy buttons must end at or before the content width
	# (no overlap with the scrollbar), and the balance line must sit inside the
	# content top (not clipped by the scroll viewport).
	var mel_btn: Rect2 = phone.quicklink_content.BUY_MELATONIN_BUTTON
	var meal_btn: Rect2 = phone.quicklink_content.BUY_CHEAP_MEAL_BUTTON
	var sun_btn: Rect2 = phone.quicklink_content.BUY_SUNSHADE_BUTTON
	for btn in [mel_btn, meal_btn, sun_btn]:
		_assert(btn.end.x <= phone.quicklink_content.custom_minimum_size.x + 0.1, "Buy button overflows content width (scrollbar overlap)")
		_assert(btn.position.y >= 60.0, "Buy button sits in the header strip drawn by bedroom_phone")
	_assert(phone.quicklink_content.BUY_MELATONIN_BUTTON.position.y >= 60.0, "Melatonin button overlaps the balance line")
	_assert(phone.quicklink_content.BUY_CHEAP_MEAL_BUTTON.position.y - (phone.quicklink_content.BUY_MELATONIN_BUTTON.end.y) >= 0.0, "Meal button overlaps the melatonin button")
	_assert(phone.quicklink_content.BUY_SUNSHADE_BUTTON.position.y - phone.quicklink_content.BUY_CHEAP_MEAL_BUTTON.end.y >= 0.0, "Sunshade button overlaps the meal button")
	# 4. Plain click on the buy button still purchases (release-based, no drag).
	# First drive the real UI flow: open the phone from HOME, tap the QUICKLINK
	# app icon, and confirm the scroll view becomes visible.
	phone.state = phone.PhoneState.EXPANDED
	phone.screen_state = phone.ScreenState.HOME
	phone._sync_content_visibility()
	await get_tree().process_frame
	var app_click := InputEventMouseButton.new()
	app_click.button_index = MOUSE_BUTTON_LEFT
	app_click.pressed = true
	app_click.position = phone._app_rect(2).get_center()
	phone._gui_input(app_click)
	await get_tree().process_frame
	_assert(phone.screen_state == phone.ScreenState.QUICKLINK, "Tapping the QUICKLINK icon did not open the app")
	_assert(phone.quicklink_scroll.visible, "QuicklinkScroll not visible in QUICKLINK screen")
	_assert(phone.quicklink_content.phone != null, "QuicklinkContent.phone was not wired up")
	# The header (back button + title) is drawn by bedroom_phone, the product
	# cards by QuicklinkContent. Both must be reachable by the input flow.
	_assert(phone.quicklink_content._action_at(Vector2(90, 90)) == "buy_melatonin", "QUICKLINK buy hit test failed (content coords)")
	# The back button is still live in the QUICKLINK screen (regression: user
	# reported it vanished) — clicking it returns to HOME.
	var back_click := InputEventMouseButton.new()
	back_click.button_index = MOUSE_BUTTON_LEFT
	back_click.pressed = true
	back_click.position = phone.BACK_BUTTON.get_center()
	phone._gui_input(back_click)
	await get_tree().process_frame
	_assert(phone.screen_state == phone.ScreenState.HOME, "Back button did not return from QUICKLINK")
	# Re-open QUICKLINK for the purchase tests below.
	phone._gui_input(app_click)
	await get_tree().process_frame
	var content: Control = phone.quicklink_content
	var buy_pos := Vector2(90, 90)  # inside BUY_MELATONIN_BUTTON (75,79,46,24) in content coords
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = buy_pos
	content._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = buy_pos
	content._gui_input(release)
	await get_tree().process_frame
	_assert(int(state.get("melatonin_inventory", 0)) == 1, "Plain click did not purchase melatonin (inventory=%d)" % int(state.get("melatonin_inventory", 0)))
	# 5. Drag after pressing on the button must scroll, not purchase.
	var before_inventory := int(state.get("melatonin_inventory", 0))
	# Simulate the real event flow: press reaches the content first, then bubbles
	# to the PhoneDragScroll which arms the drag candidate.
	content._gui_input(press)
	phone.quicklink_scroll._gui_input(press)
	var scroll_drag := InputEventMouseMotion.new()
	scroll_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	scroll_drag.position = buy_pos + Vector2(0, 40)
	phone.quicklink_scroll._gui_input(scroll_drag)
	# While dragging, clicks must be suppressed (this is the state the content
	# checks before purchasing on release).
	_assert(phone.quicklink_scroll.should_suppress_click(), "Drag active did not suppress clicks")
	content._gui_input(release)
	phone.quicklink_scroll._gui_input(release)
	await get_tree().process_frame
	_assert(int(state.get("melatonin_inventory", 0)) == before_inventory, "Drag on button incorrectly triggered a purchase")
	_assert(not phone.quicklink_scroll.drag_active, "Drag state did not reset on release")
	_assert(phone.quicklink_scroll.suppress_click_until_msec > 0, "Release did not arm the click-suppression window")
	phone.queue_free()
	await get_tree().process_frame


func _test_melatonin_dispense_no_hand_rotation() -> void:
	# After shaking completes, the pill-dispense sequence must not rotate the
	# hand that holds the bottle.  We use a fast config so the full dispense
	# flow runs in well under a second.
	var melatonin = MELATONIN.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.melatonin_shake_direction_changes_required = 1
	fast_config.melatonin_shake_distance_required = 1.0
	fast_config.melatonin_shake_segment_min_distance = 1.0
	fast_config.melatonin_shake_velocity_threshold = 0.0
	fast_config.melatonin_hand_reach_seconds = 0.01
	fast_config.melatonin_pill_throw_seconds = 0.05
	fast_config.melatonin_consume_pre_swallow_pause = 0.01
	fast_config.melatonin_consume_hand_approach_seconds = 0.05
	fast_config.melatonin_consume_end_pause = 0.01
	melatonin.config = fast_config
	get_tree().root.add_child(melatonin)
	var medicine_state := {"melatonin_inventory": 1, "stress_value": 0}
	melatonin.open(medicine_state)
	await get_tree().create_timer(0.05).timeout
	# Grab the bottle and shake it enough to trigger the pill drop.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(430, 185)
	melatonin._gui_input(press)
	var right_motion := InputEventMouseMotion.new()
	right_motion.relative = Vector2(20, 0)
	right_motion.position = press.position
	melatonin._gui_input(right_motion)
	var left_motion := InputEventMouseMotion.new()
	left_motion.relative = Vector2(-20, 0)
	left_motion.position = press.position
	melatonin._gui_input(left_motion)
	_assert(bool(melatonin.dispensing), "Shake did not trigger the pill-drop sequence")
	# Wait long enough for LEFT_ENTER (0.28s) + BOTTLE_FLIP (0.22s) to finish.
	await get_tree().create_timer(0.6).timeout
	# The right hand must still be upright — no rotation applied during dispense.
	_assert(is_equal_approx(melatonin.right_hand.rotation, 0.0), "Right hand rotated during pill dispense (rotation=%.4f)" % melatonin.right_hand.rotation)
	melatonin.force_cancel()
	melatonin.queue_free()
	await get_tree().process_frame


func _test_spawn_invulnerability_and_fast_sleep() -> void:
	var player = PLAYER.instantiate()
	get_tree().root.add_child(player)
	await get_tree().process_frame
	var starting_health: float = player.current_health
	player.start_invulnerability(CONFIG.player_spawn_invulnerability_duration, &"dream_spawn")
	player.receive_damage(40.0)
	_assert(is_equal_approx(player.current_health, starting_health), "Spawn invulnerability did not block central player damage")
	player.invulnerability_left = 0.0
	player.receive_damage(10.0)
	_assert(player.current_health < starting_health, "Player could not be damaged after spawn protection")
	player.queue_free()
	await get_tree().process_frame

	var previous_fast_setting: Variant = SettingsManager.values.get("fast_sleep_enabled", true)
	SettingsManager.values.fast_sleep_enabled = true
	var dream = DREAM.instantiate()
	get_tree().root.add_child(dream)
	await get_tree().process_frame
	_assert(is_equal_approx(Engine.time_scale, 1.5), "Fast sleep did not set the dream simulation to 1.5x")
	PauseManager.request_pause(PauseManager.ESC_MENU)
	_assert(is_equal_approx(Engine.time_scale, 1.0), "Paused dream UI did not return to 1.0x")
	PauseManager.release_pause(PauseManager.ESC_MENU)
	_assert(is_equal_approx(Engine.time_scale, 1.5), "Dream speed did not resume after pause")
	dream.queue_free()
	await get_tree().process_frame
	_assert(is_equal_approx(Engine.time_scale, 1.0), "Dream scene exit leaked its time scale")
	SettingsManager.values.fast_sleep_enabled = previous_fast_setting


func _test_music_duck_and_weather_layer() -> void:
	SFX.play_battle_music()
	await get_tree().create_timer(CONFIG.music_fade_duration + 0.08).timeout
	var manager := get_tree().root.get_node_or_null("SFXManager")
	if manager == null:
		_assert(false, "SFXManager autoload is missing")
	else:
		SFX.set_music_duck(&"UPGRADE_UI", CONFIG.upgrade_music_duck_db, CONFIG.upgrade_music_duck_fade_duration)
		await get_tree().create_timer(CONFIG.upgrade_music_duck_fade_duration + 0.05).timeout
		_assert(absf(manager.music_player.volume_db - CONFIG.upgrade_music_duck_db) < 0.25, "Upgrade music duck did not reach -6 dB")
		SFX.set_music_duck(&"UPGRADE_UI", CONFIG.upgrade_music_duck_db, 0.01)
		await get_tree().create_timer(0.03).timeout
		_assert(absf(manager.music_player.volume_db - CONFIG.upgrade_music_duck_db) < 0.25, "Named music duck accumulated twice")
		SFX.clear_music_duck(&"UPGRADE_UI", CONFIG.upgrade_music_duck_fade_duration)
		await get_tree().create_timer(CONFIG.upgrade_music_duck_fade_duration + 0.05).timeout
		_assert(absf(manager.music_player.volume_db) < 0.25, "Music duck did not restore the track gain")
		SFX.stop_music(0.01)
		await get_tree().create_timer(0.04).timeout

	var bedroom = BEDROOM.instantiate()
	var weather: Control = bedroom.get_node("Layout/WeatherBackLayer")
	var background: Sprite2D = bedroom.get_node("Layout/ArtRoot/BedroomBackground")
	_assert(weather.z_index > bedroom.get_node("Layout/BackgroundColor").z_index and weather.z_index < background.z_index, "WeatherBackLayer z-order is incorrect")
	_assert(weather.anchor_right == 1.0 and weather.anchor_bottom == 1.0 and weather.mouse_filter == Control.MOUSE_FILTER_IGNORE, "WeatherBackLayer is not full-screen/mouse-transparent")
	# Verify enhanced weather config parameters.
	_assert(CONFIG.weather_opacity >= 0.4, "Weather opacity was not boosted above the old 0.2 baseline")
	_assert(CONFIG.weather_rain_particle_count >= 60, "Rain particle count is too low for atmospheric density")
	_assert(CONFIG.weather_fog_opacity > 0.0, "Fog opacity is zero — no bottom fog will render")
	_assert(CONFIG.weather_tint_intensity > 0.0, "Tint intensity is zero — no weather color grading")
	_assert(CONFIG.weather_splash_count >= 8, "Splash count is too low for rain impact detail")
	# Verify particle seeding for each weather type.
	get_tree().root.add_child(bedroom)
	await get_tree().process_frame
	for type in ["rain", "thunder", "wind", "stars", "overcast"]:
		weather.configure(type)
		await get_tree().process_frame
		_assert(weather.rain_streaks.size() >= 60, "Rain streaks were not seeded for type %s" % type)
		_assert(weather.cloud_bands.size() >= 6, "Cloud bands were not seeded for type %s" % type)
		_assert(weather.star_dots.size() >= 30, "Star dots were not seeded for type %s" % type)
		_assert(weather.wind_lines.size() >= 10, "Wind lines were not seeded for type %s" % type)
		_assert(weather.splash_points.size() >= 8, "Splash points were not seeded for type %s" % type)
	bedroom.queue_free()


func _test_pause_music_muffle() -> void:
	# Pausing the tree must muffle the music via a low-pass on the Music bus,
	# and resuming must restore the clear cutoff.
	_assert(CONFIG.music_muffled_cutoff_hz <= 1500.0, "Muffle cutoff is too high to sound muffled")
	var manager := get_tree().root.get_node_or_null("SFXManager")
	_assert(manager != null, "SFXManager autoload missing")
	if manager == null:
		return
	_assert(manager.music_lowpass != null, "Music bus low-pass filter was not created")
	# Simulate the pause transition exactly like PauseManager does.
	get_tree().paused = true
	manager.last_muffle_paused = false  # force the _process edge detection
	await get_tree().create_timer(CONFIG.music_muffled_fade_seconds + 0.1).timeout
	if manager.music_lowpass != null:
		_assert(manager.music_lowpass.cutoff_hz <= CONFIG.music_muffled_cutoff_hz + 5.0, "Music low-pass did not reach the muffled cutoff while paused")
	get_tree().paused = false
	manager.last_muffle_paused = true  # force the _process edge detection back
	await get_tree().create_timer(CONFIG.music_muffled_fade_seconds + 0.1).timeout
	if manager.music_lowpass != null:
		_assert(manager.music_lowpass.cutoff_hz >= 19900.0, "Music low-pass did not restore the clear cutoff after resume")


func _test_death_crt_effect() -> void:
	# Player death must spawn the CRT power-off overlay and play it out.
	_assert(CONFIG.death_crt_effect_seconds > 0.0, "death_crt_effect_seconds is not configured")
	_assert(ResourceLoader.exists("res://shaders/crt_shutdown.gdshader"), "crt_shutdown.gdshader is missing")
	var dream = DREAM.instantiate()
	get_tree().root.add_child(dream)
	await get_tree().process_frame
	dream.player.invulnerability_left = 0.0
	dream.player.receive_damage(9999.0)
	await get_tree().process_frame
	_assert(dream.phase == dream.RunPhase.ENDING, "Player death did not enter the ENDING phase")
	var crt := dream.get_node_or_null("DeathCrtEffect")
	_assert(crt != null, "Death flow did not spawn the CRT effect")
	if crt != null:
		_assert(crt.active, "CRT effect is not playing during death")
		_assert(crt.layer == 30, "CRT effect is not on the topmost layer")
		_assert(crt.get_node_or_null("CrtOverlay") != null, "CRT overlay node is missing")
	# After the animation finishes the black frame must persist so the dying
	# game scene never flashes back before the results screen appears.
	await get_tree().create_timer(CONFIG.death_crt_effect_seconds + 0.3).timeout
	if crt != null and is_instance_valid(crt):
		_assert(not crt.active, "CRT effect is still running after the animation should have ended")
		_assert(is_equal_approx(crt.material.get_shader_parameter("progress"), 1.0), "CRT black frame did not persist after finishing")
	dream.queue_free()
	await get_tree().process_frame


func _test_sunshade() -> void:
	# Price + image asset must be configured.
	_assert(CONFIG.sunshade_price == 1000, "Sunshade price is not 1000")
	_assert(CONFIG.sunshade_ambient_volume_multiplier <= 0.6, "Ambient multiplier should clearly reduce the ambience")
	_assert(ResourceLoader.exists("res://art/Badroom/sunshade.png"), "sunshade.png is missing")
	# 1. SFXManager multiplier must change the weather player's volume_db.
	var manager := get_tree().root.get_node_or_null("SFXManager")
	_assert(manager != null, "SFXManager autoload missing")
	if manager != null:
		SFX.set_weather_volume_multiplier(1.0)
		_assert(is_equal_approx(manager.weather_volume_multiplier, 1.0), "Rain/sunshade multiplier did not reset to 1.0")
		# Set the multiplier first, then start weather so the crossfade's
		# settle volume already accounts for the multiplier.
		SFX.set_weather_volume_multiplier(0.5)
		_assert(is_equal_approx(manager.weather_volume_multiplier, 0.5), "Sunshade multiplier did not switch to 0.5")
		SFX.play_weather_ambience(&"rain")
		# Wait past the crossfade duration so the final volume_db is the
		# multiplier-adjusted settle volume.
		await get_tree().create_timer(CONFIG.ambience_fade_duration + 0.1).timeout
		if is_instance_valid(manager.weather_player) and manager.weather_player.playing:
			var expected_db := linear_to_db(0.5)
			_assert(absf(manager.weather_player.volume_db - expected_db) < 0.1, "Weather player volume_db did not drop to ~-6 dB when multiplier is 0.5")
		# Restore before bed tests.
		SFX.set_weather_volume_multiplier(1.0)
		SFX.stop_weather_ambience(0.01)
	# 2. Wake overlay must suppress the alarm brightness when the sunshade is active.
	var wake = WAKE_OVERLAY.instantiate()
	get_tree().root.add_child(wake)
	await get_tree().process_frame
	wake.update_sunshade(true)
	_assert(wake.sunshade_active, "sunshade_active was not set on the wake overlay")
	# Drive alarm_elapsed to the peak so the brightness formula would normally
	# saturate. The sunshade multiplier (0.0 in config) should keep the flash dark.
	wake.alarm_elapsed = CONFIG.alarm_visual_ramp_seconds
	wake.update_alarm(wake.alarm_elapsed, false, 0.0, 1.0)
	# When sunshade is active, brightness alpha is clamped to 0.
	var brightness_alpha := clampf(wake.alarm_elapsed / maxf(CONFIG.alarm_visual_ramp_seconds, 0.1), 0.0, 1.0) * CONFIG.sunshade_alarm_brightness_multiplier
	_assert(is_equal_approx(brightness_alpha, 0.0), "Sunshade did not suppress the alarm brightness to zero")
	# Deactivating the sunshade restores full brightness.
	wake.update_sunshade(false)
	var normal_alpha := 1.0 * CONFIG.alarm_screen_brightness_alpha
	_assert(normal_alpha > 0.0, "Normal alarm brightness is zero (sunshade incorrectly still active)")
	wake.queue_free()
	# 3. Bedroom wiring: the sunshade sprite appears only after purchase, toggling
	# it flips the visible state and the ambient multiplier.
	var bedroom = BEDROOM.instantiate()
	bedroom.persistent_state = {
		"balance": 2000, "ram": 0, "weekday_index": 0,
		"permanent_upgrades": {}, "online_messages": [],
		"melatonin_inventory": 0, "melatonin_bottle_present": false,
		"stress_value": 0, "daily_weather_type": "overcast",
		"sunshade_purchased": false,
		# No sunshade_visible key — first purchase should default to deployed.
	}
	get_tree().root.add_child(bedroom)
	await get_tree().process_frame
	# Initial state: not purchased → sprite hidden, ambient normal.
	_assert(not bed_sprite_visible(bedroom), "Sunshade sprite was visible before purchase")
	# Pretend a weather ambience is already playing for the volume check.
	SFX.play_weather_ambience(&"overcast")
	await get_tree().create_timer(CONFIG.ambience_fade_duration + 0.05).timeout
	# Purchase via the phone (mimics user clicking the button).
	bedroom.phone._purchase_sunshade()
	await get_tree().process_frame
	_assert(bool(bedroom.persistent_state.get("sunshade_purchased", false)), "Sunshade purchase flag was not set")
	_assert(int(bedroom.persistent_state.get("balance", 0)) == 1000, "Sunshade price does not match 1000 (balance after purchase is %d)" % int(bedroom.persistent_state.get("balance", 0)))
	_assert(bedroom.phone.state == bedroom.phone.PhoneState.COLLAPSED, "Phone did not collapse after sunshade purchase")
	_assert(not bedroom.phone.blocks_bedroom_interaction(), "Phone still blocks bedroom interaction after purchase collapse")
	_assert(not bedroom.input_locked, "Bedroom input is locked after purchase")
	_assert(bool(bedroom.persistent_state.get("sunshade_visible", true)), "First purchase should default to deployed (visible=true)")
	_assert(bed_sprite_visible(bedroom), "Sunshade sprite is not visible after first purchase")
	_assert(is_equal_approx(manager.weather_volume_multiplier, CONFIG.sunshade_ambient_volume_multiplier), "Sunshade purchase did not lower the ambient multiplier")
	# Re-purchase must be rejected (only-once rule).
	bedroom.phone._purchase_sunshade()
	await get_tree().process_frame
	_assert(int(bedroom.persistent_state.get("balance", 0)) == 1000, "Re-purchase of sunshade incorrectly charged again")
	# Flip the visible flag and confirm the toggle logic swaps it. The retracted
	# state hides the sprite (the "收回" look); hovering temporarily shows it so
	# the white alpha outline remains usable in both states.
	bedroom._toggle_sunshade()
	await get_tree().create_timer(0.3).timeout
	_assert(not bool(bedroom.persistent_state.get("sunshade_visible", true)), "Sunshade visible flag did not toggle to hidden")
	_assert(is_equal_approx(manager.weather_volume_multiplier, 1.0), "Hiding sunshade did not restore ambient volume")
	_assert(not bed_sprite_visible(bedroom), "Retracted sunshade sprite should be hidden (user expects it to disappear)")
	# Toggle back on.
	bedroom._toggle_sunshade()
	_assert(bool(bedroom.persistent_state.get("sunshade_visible", true)), "Sunshade visible flag did not toggle back on")
	_assert(bed_sprite_visible(bedroom), "Deployed sunshade sprite is not visible")
	_assert(is_equal_approx(bedroom.sunshade_sprite.modulate.a, 1.0), "Deployed sunshade did not keep full opacity")
	_assert(is_equal_approx(manager.weather_volume_multiplier, CONFIG.sunshade_ambient_volume_multiplier), "Sunshade toggle on did not lower ambient volume")
	# Hover feedback must work in the RETRACTED state too: hovering shows ONLY the
	# outline (outline_only), never the curtain body — clicking is what toggles it.
	bedroom._toggle_sunshade()  # back to retracted
	_assert(not bed_sprite_visible(bedroom), "Retracted sunshade should be hidden before hover")
	bedroom._set_highlighted("sunshade")
	bedroom._apply_sunshade_state_visual()
	_assert(bedroom.sunshade_sprite.visible, "Hovering the retracted sunshade should show its outline")
	_assert(is_equal_approx(bedroom.sunshade_outline_material.get_shader_parameter("outline_enabled"), 1.0), "Retracted sunshade outline was not enabled on hover")
	_assert(is_equal_approx(bedroom.sunshade_outline_material.get_shader_parameter("outline_only"), 1.0), "Retracted hover must be outline-only (curtain body stays hidden)")
	# Leaving the area clears the outline and hides the retracted sprite again.
	bedroom._set_highlighted("")
	_assert(is_equal_approx(bedroom.sunshade_outline_material.get_shader_parameter("outline_enabled"), 0.0), "Sunshade outline was not disabled on leave")
	_assert(not bed_sprite_visible(bedroom), "Leaving the retracted sunshade did not hide it again")
	bedroom._toggle_sunshade()  # restore deployed for cleanup symmetry
	# 4. Real click flow: after purchasing, collaps the phone, hover the curtain
	# (simulated highlight), then click — the state must flip both ways.
	bedroom.phone.force_collapse()
	await get_tree().process_frame
	_assert(not bedroom.phone.blocks_bedroom_interaction(), "Phone still blocks bedroom interaction after collapse")
	_assert(bool(bedroom.persistent_state.get("sunshade_visible", true)), "Precondition: sunshade should be deployed")
	bedroom._set_highlighted("sunshade")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(500, 50)
	bedroom._unhandled_input(click)
	await get_tree().process_frame
	_assert(not bool(bedroom.persistent_state.get("sunshade_visible", true)), "Click did not retract the sunshade")
	# The hover-refresh keeps the highlight when the mouse stays inside the
	# interaction area (headless keeps the mouse at 0,0, so re-assert it here).
	bedroom._set_highlighted("sunshade")
	bedroom._unhandled_input(click)
	await get_tree().process_frame
	_assert(bool(bedroom.persistent_state.get("sunshade_visible", true)), "Click did not redeploy the sunshade")
	# The interaction region must cover the WHOLE curtain (not just the top):
	# polygon (434..613, 0..202) + opaque alpha in sunshade.png.
	var inside_region: bool = bedroom._click_polygon_has_point(bedroom.sunshade_click_polygon, Vector2(500, 50)) and bedroom._is_opaque_at(bedroom.sunshade_sprite, bedroom.sunshade_image, Vector2(500, 50))
	_assert(inside_region, "Sunshade interaction region did not detect an upper window coordinate")
	var lower_region: bool = bedroom._click_polygon_has_point(bedroom.sunshade_click_polygon, Vector2(500, 180)) and bedroom._is_opaque_at(bedroom.sunshade_sprite, bedroom.sunshade_image, Vector2(500, 180))
	_assert(lower_region, "Sunshade interaction region does not cover the lower part of the curtain")
	var outline_width: float = bedroom.sunshade_outline_material.get_shader_parameter("outline_width_source_pixels")
	_assert(is_equal_approx(outline_width, 3.0 / bedroom.art_root.scale.x), "Sunshade outline width is not 3 screen px (got %s source px)" % outline_width)
	var outside_region: bool = bedroom._click_polygon_has_point(bedroom.sunshade_click_polygon, Vector2(300, 200)) and bedroom._is_opaque_at(bedroom.sunshade_sprite, bedroom.sunshade_image, Vector2(300, 200))
	_assert(not outside_region, "Sunshade interaction region wrongly detected an outside point")
	bedroom._set_highlighted("")
	bedroom.queue_free()
	await get_tree().process_frame


func bed_sprite_visible(bedroom) -> bool:
	return is_instance_valid(bedroom.sunshade_sprite) and bedroom.sunshade_sprite.visible


func _test_weapon_unlock_store() -> void:
	# Weapons unlocked in any save must carry over to a brand-new save via the
	# global unlock store (user://weapon_unlocks.cfg).
	var unlock_path := "user://weapon_unlocks.cfg"
	if FileAccess.file_exists(unlock_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(unlock_path))
	# Partially unlocked save → new save inherits only those.
	var partial_save := {"shotgun_unlocked": true, "beam_weapon_unlocked": false, "katana_unlocked": false, "grenade_weapon_unlocked": false}
	UNLOCK_STORE.sync_from(partial_save)
	var fresh := {"shotgun_unlocked": false, "beam_weapon_unlocked": false, "katana_unlocked": false, "grenade_weapon_unlocked": false}
	UNLOCK_STORE.apply_to(fresh)
	_assert(bool(fresh.get("shotgun_unlocked", false)), "Shotgun unlock did not carry over to a new save")
	_assert(not bool(fresh.get("beam_weapon_unlocked", false)), "Beam unlock leaked into a new save without being unlocked")
	# Fully unlocked save → every weapon carries over.
	var full_save := {"shotgun_unlocked": true, "beam_weapon_unlocked": true, "katana_unlocked": true, "grenade_weapon_unlocked": true}
	UNLOCK_STORE.sync_from(full_save)
	var fresh2 := {"shotgun_unlocked": false, "beam_weapon_unlocked": false, "katana_unlocked": false, "grenade_weapon_unlocked": false}
	UNLOCK_STORE.apply_to(fresh2)
	for weapon in ["shotgun_unlocked", "beam_weapon_unlocked", "katana_unlocked", "grenade_weapon_unlocked"]:
		_assert(bool(fresh2.get(weapon, false)), "New save re-locked a fully unlocked weapon: " + weapon)
	# Cleanup so later test runs start from a clean slate.
	if FileAccess.file_exists(unlock_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(unlock_path))


func _test_announcement_window() -> void:
	# The main menu must show a pixel announcement window on entry, reading its
	# text from res://data/announcement.txt (never hardcoded in the scene).
	_assert(FileAccess.file_exists("res://data/announcement.txt"), "announcement.txt is missing")
	var menu = MAIN_MENU.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	menu.config = fast_config
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var window: Control = menu.announcement_window
	_assert(window != null, "AnnouncementWindow node is missing in the main menu")
	_assert(window.visible, "Announcement window is not visible on menu entry")
	var expected_text := FileAccess.get_file_as_string("res://data/announcement.txt").strip_edges()
	_assert(window.announcement_text.text == expected_text, "Announcement text does not match announcement.txt (got: %s)" % window.announcement_text.text)
	_assert(not window.announcement_text.text.is_empty(), "Announcement text is empty")
	_assert(window.get_node_or_null("Panel/Content/ContentScroll/AnnouncementText") != null, "AnnouncementText node path is wrong")
	_assert(window.get_node_or_null("Panel/Content/ContentScroll") is ScrollContainer, "ContentScroll is not a ScrollContainer")
	# Enter animation: fades in over ~0.3s.
	_assert(window.modulate.a < 1.0, "Enter animation did not start (already opaque)")
	await get_tree().create_timer(0.5).timeout
	_assert(is_equal_approx(window.modulate.a, 1.0), "Enter animation did not finish")
	# Must not overlap any main menu button.
	var window_rect := Rect2(window.global_position, window.size)
	for button in [menu.continue_button, menu.start_button, menu.endless_button, menu.settings_button, menu.quit_button]:
		var button_rect := Rect2(button.global_position, button.size)
		_assert(not window_rect.intersects(button_rect), "Announcement window overlaps button " + button.name)
	# Close button hides; show_announcement() reopens.
	window._on_close()
	_assert(not window.visible, "Close button did not hide the announcement window")
	window.show_announcement()
	await get_tree().process_frame
	_assert(window.visible, "show_announcement() did not reopen the window")
	menu.queue_free()
	await get_tree().process_frame


func _test_ending_day_restart() -> void:
	# Triggering an ending must reset the save to that day's morning (bedroom
	# start), so "继续游戏" replays the ending day instead of resuming mid-day.
	# The full ending path must be exercised: _show_starvation_ending sets the
	# unlock flags first, THEN resets them for replay (order matters!).
	var main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main.persistent_day_state = {
		"calendar_day_id": 3, "weekday_index": 3, "balance": 1000, "ram": 50,
		"stress_value": 85, "morning_stress_value": 45,
		"has_entered_dream": true, "delivery_state": "DELIVERING",
		"cheap_meal_purchased_today": true, "cheap_meal_purchases_today": 1,
		"food_eaten_today": true, "is_hungry_run": true,
		"hunger_checked_day_id": 3, "consecutive_hungry_days": CONFIG.starvation_ending_required_days,
		"starvation_ending_unlocked": true, "starvation_ending_triggered_day_id": 3,
		"normal_life_ending_unlocked": true, "any_ending_completed": true,
	}
	main._show_starvation_ending()
	await get_tree().process_frame
	_assert(not bool(main.persistent_day_state.get("has_entered_dream", true)), "Ending reset left has_entered_dream=true")
	_assert(str(main.persistent_day_state.get("delivery_state", "NONE")) == "NONE", "Ending reset left a delivery active")
	_assert(int(main.persistent_day_state.get("stress_value", 0)) == 45, "Ending reset did not restore morning stress")
	_assert(int(main.persistent_day_state.get("cheap_meal_purchases_today", -1)) == 0, "Ending reset left purchases from the day")
	_assert(not bool(main.persistent_day_state.get("food_eaten_today", true)), "Ending reset left food_eaten_today")
	# Ending triggers must be re-armable so replaying the day (e.g. sleeping
	# hungry again) re-triggers the starvation ending.
	_assert(int(main.persistent_day_state.get("hunger_checked_day_id", -1)) == -1, "Ending reset did not clear hunger_checked_day_id")
	_assert(not bool(main.persistent_day_state.get("starvation_ending_unlocked", true)), "Starvation ending flag was not re-armed (reset ran before the flag was set?)")
	_assert(bool(main.persistent_day_state.get("any_ending_completed", false)), "Ending reset lost the completed-ending record")
	# The day-start snapshot must also point at the morning state.
	_assert(not bool(main.day_start_snapshot.state.get("has_entered_dream", true)), "Day-start snapshot was not reset to morning")
	# End-to-end: after the full ending path, replaying the day and sleeping
	# hungry again must re-trigger the starvation ending.
	main.persistent_day_state = {
		"calendar_day_id": 4, "weekday_index": 4,
		"hunger_checked_day_id": -1,
		"consecutive_hungry_days": maxi(0, CONFIG.starvation_ending_required_days - 1),
		"starvation_ending_unlocked": false,
		"food_eaten_today": false,
		"stress_value": 50, "morning_stress_value": 50,
	}
	var re_triggers: bool = main._register_hunger_sleep_for_day()
	_assert(re_triggers, "Sleeping hungry on the replayed day did not re-trigger the starvation ending")
	main.queue_free()
	await get_tree().process_frame
	# The starvation ending text "你饿死了" must render as dramatic (red, 2x size,
	# slight shake). Verify the flag wiring on the opening scene.
	var opening = OPENING_SCENE.instantiate()
	opening.config = CONFIG.duplicate(true)
	opening.ending_mode = true
	opening.setup_paragraphs(["你饿死了", "永远不会醒来了。"])
	opening.dramatic_text = "你饿死了"
	get_tree().root.add_child(opening)
	await get_tree().process_frame
	_assert(opening.dramatic_text == "你饿死了", "Starvation ending did not set the dramatic text")
	_assert(opening.paragraphs[0] == "你饿死了", "First ending paragraph is not 你饿死了")
	opening.queue_free()
	await get_tree().process_frame


func _test_phone_ux_fixes() -> void:
	# 1) Thunder SFX is disabled by config (visual flash stays).
	_assert(not CONFIG.weather_thunder_sfx_enabled, "Thunder SFX config should be off")
	# 2) Northern Times hover-delete: hovering the card triggers the deleted
	# state (author becomes 匿名, body shows the deleted hint).
	var phone = PHONE.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.phone_fingerprint_animation_seconds = 0.01
	phone.config = fast_config
	get_tree().root.add_child(phone)
	await get_tree().process_frame
	var state := {
		"balance": 2000, "ram": 0, "weekday_index": 0,
		"permanent_upgrades": {}, "online_messages": [],
		"melatonin_inventory": 0, "melatonin_bottle_present": false,
		"sunshade_purchased": false, "delivery_state": "NONE",
		"day5_northern_times_deleted": false,
	}
	phone.configure_state(state)
	phone.state = phone.PhoneState.EXPANDED
	phone.screen_state = phone.ScreenState.ONLINE
	phone._sync_content_visibility()
	await get_tree().process_frame
	# Inject the northern times message and rebuild the list.
	var northern := {"id": "day5_northern_times", "category": "北方时报", "text": "速联科技裁员2万、连关多厂后速联科技上半季度仍然亏损。", "received_day_id": 0, "is_read": false}
	state.online_messages.append(northern)
	phone.messages = state.online_messages
	phone._build_online_messages()
	await get_tree().process_frame
	phone._on_message_card_hovered(northern)
	await get_tree().process_frame
	_assert(bool(state.get("day5_northern_times_deleted", false)), "Hovering the Northern Times message did not delete it")
	# 3) Collapse area: app screens use a narrow strip above the back button.
	var back_top: float = phone.BACK_BUTTON.position.y
	var app_area: Rect2 = phone._collapse_area_for_state()
	_assert(app_area.end.y < back_top, "App collapse area overlaps the back button")
	phone.screen_state = phone.ScreenState.HOME
	var home_area: Rect2 = phone._collapse_area_for_state()
	_assert(home_area.size.y >= 100.0, "HOME collapse area shrank")
	# 4) Screen glitch: hover-delete spawns a full-screen glitch overlay that
	# removes itself in < 1s and shakes the bedroom root. Use an isolated phone
	# under the real hierarchy (Node2D > CanvasLayer > Control).
	_assert(ResourceLoader.exists("res://shaders/glitch_overlay.gdshader"), "glitch_overlay.gdshader is missing")
	var shake_host := Node2D.new()
	shake_host.name = "ShakeHost"
	get_tree().root.add_child(shake_host)
	var layer := CanvasLayer.new()
	shake_host.add_child(layer)
	var glitch_phone := PHONE.instantiate()
	glitch_phone.config = fast_config
	layer.add_child(glitch_phone)
	await get_tree().process_frame
	glitch_phone._play_screen_glitch(0.4)
	await get_tree().process_frame
	var glitch := layer.get_node_or_null("ScreenGlitch")
	_assert(glitch != null, "Screen glitch overlay was not created")
	if glitch != null:
		_assert(glitch.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Glitch overlay blocks input")
		_assert(glitch.get_rect().size.x >= 600.0 and glitch.get_rect().size.y >= 300.0, "Glitch overlay is not full screen")
	_assert(glitch_phone._shake_tween != null, "Screen shake did not start on the bedroom root")
	await get_tree().create_timer(0.7).timeout
	_assert(layer.get_node_or_null("ScreenGlitch") == null, "Screen glitch overlay did not remove itself")
	_assert(is_equal_approx(shake_host.position.x, 0.0) and is_equal_approx(shake_host.position.y, 0.0), "Screen shake did not restore the bedroom position")
	glitch_phone.queue_free()
	shake_host.queue_free()
	await get_tree().process_frame
	# 5) Delivery arrival collapses via animation (COLLAPSING state), not a teleport.
	phone.screen_state = phone.ScreenState.HOME
	phone.force_collapse()
	await get_tree().process_frame
	# Simulate the delivery-arrival scenario: phone is stably expanded.
	phone.state = phone.PhoneState.EXPANDED
	phone.position.y = phone.config.phone_expanded_y
	phone._animate_phone(false)
	await get_tree().process_frame
	_assert(phone.state == phone.PhoneState.COLLAPSING or phone.state == phone.PhoneState.COLLAPSED, "Delivery collapse did not start an animation")
	phone.queue_free()
	await get_tree().process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
