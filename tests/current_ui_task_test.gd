extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")
const DIALOG := preload("res://scenes/ui/confirmation_dialog.tscn")
const SKILLS := preload("res://scenes/ui/skills_menu.tscn")
const RESULTS := preload("res://scenes/ui/results.tscn")
const CONSOLE := preload("res://scenes/ui/debug_console.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	for action in ["skill_menu", "toggle_console"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	await _test_phone_time_unread_and_scroll()
	await _test_confirmation_and_attribute_layout()
	await _test_result_sequence_and_console()
	_test_visible_result_fields()
	if failures.is_empty():
		print("CURRENT UI TASK TEST PASSED: phone -> dialog -> scroll layout -> results -> debug console")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_phone_time_unread_and_scroll() -> void:
	var phone := PHONE.instantiate()
	var meta := {"balance": 1325, "ram": 0, "weekday_index": 0, "permanent_upgrades": {}}
	root.add_child(phone)
	await process_frame
	phone.configure_state(meta)
	phone.set_bedroom_time(1505.0)
	_assert(phone.bedroom_time_minutes == 1505.0 and RunSettlement.format_time(phone.bedroom_time_minutes) == "01:05", "Phone is not using the wrapped bedroom clock source")
	_assert(phone._has_unread_online_messages(), "Initial ONLINE messages are not unread")
	phone._open_app("online")
	await process_frame
	_assert(not phone._has_unread_online_messages(), "Opening ONLINE did not clear unread state")
	_assert(phone.online_scroll.visible and phone.message_list.get_child_count() >= 3, "ONLINE scroll content was not built")
	phone.queue_free()
	await process_frame


func _test_confirmation_and_attribute_layout() -> void:
	var dialog := DIALOG.instantiate()
	root.add_child(dialog)
	await process_frame
	dialog.open("要吃药吗？", "吃", "不吃", false)
	_assert(dialog.visible and dialog.confirm_button.disabled, "Out-of-stock melatonin confirmation is not disabled")
	dialog.close_without_signal()
	dialog.queue_free()
	var menu := SKILLS.instantiate()
	root.add_child(menu)
	await process_frame
	var stats: Array[Dictionary] = []
	for index in 20:
		stats.append({"name": "属性%d" % index, "base": index, "permanent": 1, "cards": 2, "final": index + 3})
	var empty_cards: Array[Dictionary] = []
	menu.open(empty_cards, stats, {"shield": false, "revive": false, "rapid_eye": false})
	await process_frame
	await process_frame
	var scroll: ScrollContainer = menu.get_node("Margin/Columns/AttributesPanel/Content/Body/AttributeScroll")
	_assert(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Attribute list did not become scrollable")
	menu.queue_free()
	await process_frame


func _test_result_sequence_and_console() -> void:
	var results := RESULTS.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.door_open_close_gap_seconds = 0.0
	results.config = fast_config
	root.add_child(results)
	await process_frame
	results.showing_summary = true
	results.start_button.visible = true
	var signal_state := {"emitted": false}
	results.new_day_requested.connect(func(): signal_state.emitted = true)
	results._on_start_new_day()
	await create_timer(0.4).timeout
	_assert(signal_state.emitted and results.new_day_sequence_running and results.start_button.disabled, "New-day door sequence did not finish exactly once")
	results.queue_free()
	var console := CONSOLE.instantiate()
	root.add_child(console)
	await process_frame
	var meta := {"ram": 0}
	console.configure(meta, Callable())
	console._execute_command("  rammax ")
	_assert(meta.ram == 999 and console.output_label.text == "RAM SET TO 999", "RAMMAX command failed")
	console._execute_command("NOPE")
	_assert(console.output_label.text == "UNKNOWN COMMAND", "Unknown console command response failed")
	console.queue_free()
	await process_frame


func _test_visible_result_fields() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/results.gd")
	for required in ["醒来时间", "本局 RAM", "工资", "余额"]:
		_assert(source.contains(required), "Missing result field: " + required)
	for removed in ["击败 / 等级", "本局累计经验", "RAM 转换 1%", "第一晚结束"]:
		_assert(not source.contains(removed), "Removed result field is still visible: " + removed)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
