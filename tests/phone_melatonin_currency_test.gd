extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const FORMAT := preload("res://scripts/ui/display_format.gd")

# SceneTree scripts compile before autoload names are registered. Load dependent
# scenes only after startup, as the actual Main entrypoint does.
var PHONE: PackedScene
var BEDROOM: PackedScene
var MELATONIN: PackedScene
var MAIN_SCRIPT: GDScript

var failures: Array[String] = []
var event_counts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	PHONE = load("res://scenes/ui/bedroom_phone.tscn")
	BEDROOM = load("res://scenes/bedroom/bedroom.tscn")
	MELATONIN = load("res://scenes/ui/melatonin_interaction.tscn")
	MAIN_SCRIPT = load("res://scripts/app/main.gd")
	var manager := root.get_node_or_null("SFXManager")
	_assert(manager != null, "SFXManager autoload is missing")
	if manager != null:
		manager.sfx_played.connect(_on_sfx_played)
		for event_id in [&"phone_unlock", &"phone_operation", &"bottle_shake"]:
			_assert(manager.players.has(event_id), "Missing SFX event: %s" % event_id)
	_test_config_and_files()
	await _test_phone()
	await _test_bottle_shake()
	await _test_melatonin_dialogue_limit()
	_test_dream_start_and_currency()
	_test_visible_text_and_shared_formatter()
	if failures.is_empty():
		print("PHONE / MELATONIN / CURRENCY TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_config_and_files() -> void:
	for path in [
		"res://sfx/手机解锁音效.mp3",
		"res://sfx/手机操作按键.mp3",
		"res://sfx/摇晃药瓶.mp3"
	]:
		_assert(FileAccess.file_exists(path), "Missing imported source file: " + path)
	_assert(CONFIG.melatonin_nightly_use_limit == 3, "Nightly melatonin limit is not 3")
	_assert(is_equal_approx(CONFIG.melatonin_minutes_earlier_per_tablet, 30.0), "Per-tablet dream offset is not 30 minutes")
	_assert(CONFIG.sfx_bottle_shake_min_interval > 0.0, "Bottle shake cooldown is not configured")


func _test_phone() -> void:
	var phone := PHONE.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.phone_fingerprint_animation_seconds = 0.01
	phone.config = fast_config
	root.add_child(phone)
	await process_frame
	phone.configure_state({"balance": 12500, "ram": 0, "weekday_index": 0, "permanent_upgrades": {}, "online_messages": []})
	phone.state = phone.PhoneState.EXPANDED
	phone.screen_state = phone.ScreenState.LOCKED
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = phone.FINGERPRINT_AREA.get_center()
	phone._gui_input(click)
	phone._gui_input(click)
	await create_timer(0.05).timeout
	_assert(_count(&"phone_unlock") == 1, "Fingerprint unlock sound did not play exactly once")
	_assert(phone.screen_state == phone.ScreenState.HOME, "Fingerprint unlock did not reach the home screen")
	var motion := InputEventMouseMotion.new()
	motion.position = phone._app_rect(0).get_center()
	phone._gui_input(motion)
	_assert(phone.hovered_app_index == 0, "App hover feedback was not selected")
	click.position = phone._app_rect(0).get_center()
	phone._gui_input(click)
	_assert(_count(&"phone_operation") == 1 and phone.screen_state == phone.ScreenState.ONLINE, "App click did not play one operation sound")
	click.position = phone.BACK_BUTTON.get_center()
	phone._gui_input(click)
	_assert(_count(&"phone_operation") == 2 and phone.screen_state == phone.ScreenState.HOME, "Back did not play one operation sound")
	phone.queue_free()
	await process_frame


func _test_bottle_shake() -> void:
	var interaction := MELATONIN.instantiate()
	var shake_config: DemoConfig = CONFIG.duplicate(true)
	shake_config.melatonin_shake_segment_min_distance = 2.0
	shake_config.melatonin_required_shakes = 99
	shake_config.melatonin_required_reversals = 99
	interaction.config = shake_config
	root.add_child(interaction)
	await process_frame
	var state := {"melatonin_inventory": 1}
	interaction.open(state)
	_simulate_reversal(interaction)
	_assert(_count(&"bottle_shake") == 1, "Valid held reversal did not play the bottle sound")
	interaction.force_cancel()
	await create_timer(CONFIG.sfx_bottle_shake_min_interval + 0.02).timeout
	state.melatonin_inventory = 0
	interaction.open(state)
	_simulate_reversal(interaction)
	_assert(_count(&"bottle_shake") == 1, "Empty bottle played the shake sound")
	interaction.force_cancel()
	interaction.queue_free()
	await process_frame


func _simulate_reversal(interaction: Control) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = interaction.BOTTLE_GRAB_RECT.get_center()
	interaction._gui_input(press)
	var right := InputEventMouseMotion.new()
	right.relative = Vector2(12, 0)
	interaction._gui_input(right)
	var left := InputEventMouseMotion.new()
	left.relative = Vector2(-12, 0)
	interaction._gui_input(left)


func _test_melatonin_dialogue_limit() -> void:
	var bedroom := BEDROOM.instantiate()
	bedroom.persistent_state = {
		"balance": 1325,
		"ram": 0,
		"weekday_index": 0,
		"permanent_upgrades": {},
		"online_messages": [],
		"melatonin_inventory": 4,
		"melatonin_bottle_present": true
	}
	root.add_child(bedroom)
	await process_frame
	bedroom._request_confirmation("bottle")
	_assert(bedroom.confirmation_dialog.prompt_label.text == "要吃药吗？", "First tablet prompt is incorrect")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom.melatonin_used_count = 1
	bedroom._request_confirmation("bottle")
	_assert(bedroom.confirmation_dialog.prompt_label.text == "还要再吃吗？", "Repeat tablet prompt is incorrect")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom.melatonin_used_count = 2
	bedroom._on_melatonin_completed()
	_assert(bedroom.melatonin_used_count == 3, "Third completed consume did not reach the nightly limit")
	bedroom._request_confirmation("bottle")
	_assert(bedroom.confirmation_dialog.message_only and not bedroom.confirmation_dialog.buttons.visible, "Limit prompt still exposes a consume choice")
	_assert(bedroom.confirmation_dialog.prompt_label.text == "已经够多了。", "Nightly limit prompt is incorrect")
	bedroom.confirmation_dialog.close_without_signal()
	bedroom._open_melatonin()
	_assert(not bedroom.melatonin_ui.visible and int(bedroom.persistent_state.melatonin_inventory) == 4, "Fourth tablet flow was not blocked")
	bedroom.queue_free()
	await process_frame


func _test_dream_start_and_currency() -> void:
	var main: Node = MAIN_SCRIPT.new()
	var expected := [240.0, 210.0, 180.0, 150.0]
	for count in 4:
		_assert(is_equal_approx(main._dream_start_minutes_for_melatonin_count(count), expected[count]), "Dream start is wrong for %d tablet(s)" % count)
	main.free()
	_assert(FORMAT.format_currency(999) == "¥999", "Currency formatting failed for 999")
	_assert(FORMAT.format_currency(1000) == "¥1,000", "Currency formatting failed for 1,000")
	_assert(FORMAT.format_currency(12500) == "¥12,500", "Currency formatting failed for 12,500")
	_assert(FORMAT.format_currency(-1000) == "-¥1,000", "Negative debug currency formatting is incorrect")


func _test_visible_text_and_shared_formatter() -> void:
	for path in ["res://scripts/bedroom/bedroom.gd", "res://scripts/ui/bedroom_phone.gd", "res://scripts/ui/results.gd"]:
		var source := FileAccess.get_file_as_string(path)
		_assert(not source.contains("BALANCE"), "Visible BALANCE remains in " + path)
		_assert(source.contains("FORMAT.format_currency"), "Shared formatter is not used by " + path)
	var phone_source := FileAccess.get_file_as_string("res://scripts/ui/bedroom_phone.gd")
	_assert(not phone_source.contains("draw_rect(rect, Color(0.18, 0.19, 0.23, 0.34), false"), "App white rectangle highlight is still drawn")


func _on_sfx_played(event_id: StringName) -> void:
	event_counts[event_id] = _count(event_id) + 1


func _count(event_id: StringName) -> int:
	return int(event_counts.get(event_id, 0))


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
