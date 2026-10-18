extends SceneTree
const SCREEN := preload("res://scripts/ui/phone_settings_screen.gd")
const MODEL := preload("res://scripts/ui/phone_apps_model.gd")
const CONFIG := preload("res://resources/demo_config.tres")
var checks := 0
var failures: Array[String] = []
var screen: Control
var feedback: Array = []

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); push_error(text)
func frames(n: int = 3) -> void:
	for i in n: await process_frame

func _run() -> void:
	if not OS.get_user_data_dir().contains("phone_settings_sample"):
		push_error("Test needs isolated phone_settings_sample profile"); quit(2); return
	var state := {"balance": 100000, "online_messages": [{"id": "a", "category": "主管", "text": "今晚请准时到岗。", "is_read": false}, {"id": "quicklink_news_debt_1993", "text": "速联讯息", "is_read": false}, {"id": "day5_northern_times", "text": "特殊讯息", "is_read": false}]}
	screen = SCREEN.new()
	root.add_child(screen)
	screen.configure_apps(state, null, func(): return {"time": "23:45", "battery": 0.5})
	screen.set_context(&"game")
	screen.feedback_requested.connect(func(action: StringName, pressed: bool): feedback.append([action, pressed]))
	check(screen.get_page_id() == &"home", "Game context opens phone apps, not pause options")
	screen.navigate(&"left"); screen.navigate(&"up")
	check(screen.get_selected_index() == 0, "Top-left navigation clamps")
	screen.navigate(&"right"); screen.navigate(&"right")
	check(screen.get_selected_index() == 1, "Top-right navigation clamps")
	screen.navigate(&"down"); screen.navigate(&"down")
	check(screen.get_selected_index() == 3, "Bottom-right navigation clamps")
	var stationary := InputEventMouseMotion.new()
	stationary.position = screen.get_control_point(&"chat")
	stationary.relative = Vector2.ZERO
	screen._gui_input(stationary)
	check(screen.get_selected_index() == 3, "Stationary projected pointer cannot steal keyboard selection")
	stationary.relative = Vector2(1, 0)
	screen._gui_input(stationary)
	check(screen.get_selected_index() == 0 and feedback.is_empty(), "Real hover selects without pressing physical keys")
	screen.navigate(&"home")
	check(screen.get_page_id() == &"settings", "Q/home opens settings from homepage")
	screen.navigate(&"confirm")
	check(screen.get_page_id() == &"sounds", "Settings first row opens sounds")
	var manager: Node = root.get_node("SettingsManager")
	for key in [&"master_volume", &"music_volume", &"sfx_volume"]:
		manager.set_volume(key, 45)
		screen.navigate(&"right")
		check(manager.get_volume(key) == 50, "Volume row adjusts real manager: " + String(key))
		screen.navigate(&"down")
	check(screen.get_selected_index() == 2, "Last sound row does not wrap")
	_click(screen.get_control_point(&"sfx_volume_min"), true)
	check(manager.get_volume(&"sfx_volume") == 0 and screen.get_interaction_locked(), "Slider press writes exact zero and freezes phone tilt")
	_click(screen.get_control_point(&"sfx_volume_max"), false)
	check(not screen.get_interaction_locked() and feedback.back()[1] == false, "Pointer release clears feedback and interaction lock")
	screen.navigate(&"back"); screen.navigate(&"down"); screen.navigate(&"confirm")
	check(screen.get_page_id() == &"graphics", "Graphics page remains reachable")
	for key in [&"pixelation_enabled", &"palette_enabled"]:
		screen.navigate(&"left"); check(not manager.get_setting(key), "Graphics left selects off: " + String(key))
		screen.navigate(&"right"); check(manager.get_setting(key), "Graphics right selects on: " + String(key))
		screen.navigate(&"down")
	manager.set_setting(&"shadow_quality", "high")
	screen.navigate(&"right")
	check(manager.get_shadow_quality() == "high", "Shadow quality clamps at upper edge")
	screen.set_context(&"game")
	screen.open_app(&"chat")
	await frames()
	check(bool(state.online_messages[0].is_read) and bool(state.online_messages[1].is_read), "Opening messages updates live shared read state")
	check(bool(state.quicklink_news_read) and not bool(state.online_messages[2].is_read), "Existing story-specific read exceptions are preserved")
	var messages: Array = screen.apps_model.get_messages()
	for message in messages:
		if message.id == "day5_northern_times": screen.apps_model.hover_message(message)
	check(bool(state.day5_northern_times_deleted) and bool(state.online_messages[2].is_read), "Special message hover retains original deletion state transition")
	check(screen.apps_model.get_message_category(state.online_messages[2]) == "匿名", "Deleted message reuses authored anonymous attribution")
	var sorted_model := MODEL.new()
	sorted_model.configure({"online_messages": [{"received_day_id": 2, "message_sequence": 3}, {"received_day_id": 1, "message_sequence": 99}, {"received_day_id": 2, "message_sequence": 5}]})
	check(int(sorted_model.get_messages()[0].message_sequence) == 5 and int(sorted_model.get_messages()[2].received_day_id) == 1, "Message order matches day then real message_sequence authority")
	check(screen.apps_model.get_status().time == "23:45", "Status time uses supplied game clock")
	screen.open_app(&"call")
	check(screen.get_page_id() == &"call", "Phone placeholder app is accessible")
	screen.set_context(&"game"); screen.open_app(&"shop")
	var before := int(state.balance)
	for i in 3:
		screen.navigate(&"confirm"); screen.navigate(&"down")
	check(state.balance == before and not state.has("melatonin_inventory"), "All 3D shop entries are read-only without bedroom authority")
	await frames()
	var phone_scene: PackedScene = load("res://scenes/ui/bedroom_phone.tscn")
	var phone: Control = phone_scene.instantiate()
	root.add_child(phone)
	phone.hide()
	phone.configure_state(state)
	var model := MODEL.new()
	model.configure(state, phone)
	var prior := int(state.balance)
	check(model.purchase(0), "Bedroom model delegates purchase")
	check(int(state.balance) == prior - CONFIG.melatonin_price and int(state.melatonin_inventory) == 1, "Original bedroom authority applies actual melatonin price and inventory")
	prior = int(state.balance)
	model.purchase(1)
	check(int(state.balance) == prior - CONFIG.cheap_meal_price and state.delivery_state == "DELIVERING", "Original meal authority applies actual price and delivery")
	prior = int(state.balance)
	model.purchase(2)
	check(int(state.balance) == prior - CONFIG.sunshade_price and bool(state.sunshade_purchased), "Original sunshade authority applies actual price and one-time state")
	prior = int(state.balance)
	model.purchase(2)
	check(int(state.balance) == prior, "Existing authority prevents duplicate sunshade purchase")
	screen.configure_apps(state, phone)
	screen.set_context(&"bedroom"); screen.open_app(&"shop")
	await frames(4)
	var first_card: Control = screen._cards.get_child(0)
	var target := first_card.get_global_rect().get_center()
	prior = int(state.balance)
	await _pointer_button(target, true)
	await _pointer_button(target, false)
	check(int(state.balance) == prior - CONFIG.melatonin_price, "Real GUI card click purchases once without duplicate parent propagation")
	await frames(3)
	first_card = screen._cards.get_child(0)
	var start := first_card.get_global_rect().position + Vector2(35, 35)
	prior = int(state.balance)
	await _pointer_button(start, true)
	for step in range(1, 6):
		var motion := InputEventMouseMotion.new()
		motion.position = start - Vector2(0, step * 12)
		motion.relative = Vector2(0, -12)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await frames(1)
	await _pointer_button(start - Vector2(0, 60), false)
	check(int(state.balance) == prior, "Dragging actual shop content never triggers a purchase on release")
	check(not screen.get_interaction_locked(), "Actual scrolled card release clears tilt freeze")
	phone.queue_free()
	var audio: Node = root.get_node("SFXManager")
	var music: AudioStreamPlayer = audio.music_player
	var old_id: StringName = audio.current_music_id
	var old_owner: int = audio.current_music_owner_id
	var old_stream: AudioStream = music.stream
	var old_paused := music.stream_paused
	var child_count := audio.get_child_count()
	audio.current_music_id = &"battle"; audio.current_music_owner_id = 7654
	music.stream = audio.MUSIC_STREAMS[&"battle"]; music.play(); music.stream_paused = false
	model.toggle_music(self)
	check(music.stream_paused and audio.current_music_owner_id == 7654, "Music pause preserves current scene ownership")
	model.toggle_music(self)
	check(not music.stream_paused and audio.music_player == music and audio.get_child_count() == child_count, "Music resumes same existing player without duplicate AudioPlayers")
	audio.current_music_id = old_id; audio.current_music_owner_id = old_owner
	music.stop(); music.stream = old_stream; music.stream_paused = old_paused
	screen.free()
	await frames()
	for player in root.find_children("*", "AudioStreamPlayer", true, false): player.stop()
	await create_timer(0.15, true, false, true).timeout
	print("PHONE_APPS_UI checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	screen._gui_input(event)

func _pointer_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	root.push_input(event, true)
	await frames(1)
