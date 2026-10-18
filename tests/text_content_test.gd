extends SceneTree

const DIALOG_SCENE := preload("res://scenes/ui/confirmation_dialog.tscn")
const OPENING_SCENE := preload("res://scenes/ui/opening.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TextContent.reload()
	_test_required_data()
	_test_editable_presentation()
	_test_safe_actions()
	_test_no_formal_inline_copy()
	await _test_dialogue_scene()
	await _test_opening_scene()
	if failures.is_empty():
		print("TEXT CONTENT TEST PASSED")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_required_data() -> void:
	for dialogue_id in [&"bedroom_self", &"bed_ready_sleep", &"hallway_no_one", &"computer_readme", &"dream_wake_prompt", &"boss_placeholder"]:
		var entry := TextContent.get_dialogue(dialogue_id)
		_assert(str(entry.get("id", "")) == str(dialogue_id), "missing dialogue %s" % dialogue_id)
	for event_id in [&"opening_first_night", &"ending_normal_life", &"ending_starvation", &"nightmare_early_death", &"wake_normal"]:
		var event := TextContent.get_text_event(event_id)
		_assert(str(event.get("id", "")) == str(event_id), "missing text event %s" % event_id)
	_assert(TextContent.get_phone_message_templates().size() >= 6, "phone message templates were not migrated")
	_assert(TextContent.get_initial_phone_messages().size() == 3, "only starting conversations may exist in a new game")


func _test_editable_presentation() -> void:
	var opening_line: Dictionary = TextContent.get_event_lines(&"opening_first_night")[0]
	for field in ["text", "typewriter_speed", "pre_delay", "post_delay", "fade_in", "fade_out", "wait_for_input", "auto_continue", "text_color", "font_size", "alignment", "position", "blip"]:
		_assert(opening_line.has(field), "opening line missing editable field %s" % field)
	var sleep_line: Dictionary = TextContent.get_dialogue(&"bed_ready_sleep").lines[0]
	_assert(sleep_line.get("choices", []).size() == 2, "sleep choices are not data-driven")
	_assert(str(sleep_line.choices[0].action_id) == "begin_sleep", "sleep action id mismatch")


func _test_safe_actions() -> void:
	_assert(TextContent.is_action_allowed(&"begin_sleep"), "registered action was rejected")
	_assert(not TextContent.is_action_allowed(&"queue_free"), "arbitrary method name was accepted")
	_assert(not TextContent.is_action_allowed(&"get_tree().quit()"), "arbitrary expression was accepted")


func _test_no_formal_inline_copy() -> void:
	var bedroom_script := FileAccess.get_file_as_string("res://scripts/bedroom/bedroom.gd")
	var opening_script := FileAccess.get_file_as_string("res://scripts/ui/opening.gd")
	var result_script := FileAccess.get_file_as_string("res://scripts/ui/results.gd")
	for text in ["这是我", "门外没有人", "要睡觉了吗？", "已经够多了。"]:
		_assert(not bedroom_script.contains(text), "Bedroom still hardcodes formal text: %s" % text)
	_assert(not opening_script.contains("你已经连续三天没有睡好。"), "Opening still hardcodes its body")
	_assert(not result_script.contains("今天又是一场噩梦"), "Nightmare still hardcodes its body")


func _test_dialogue_scene() -> void:
	var dialog := DIALOG_SCENE.instantiate()
	root.add_child(dialog)
	await process_frame
	dialog.open_dialogue(&"bed_ready_sleep")
	await process_frame
	_assert(dialog.full_prompt_text == "要睡觉了吗？", "Dialogue did not resolve ID text")
	_assert(dialog.current_choices.size() == 2, "Dialogue did not build choices from data")
	_assert(is_equal_approx(float(dialog.current_line.get("typewriter_speed", 0.0)), 0.04), "Dialogue per-line speed was not loaded")
	dialog.close_without_signal()
	await process_frame
	dialog.open_data({"id": "three_choices", "lines": [{"text": "test", "typewriter_speed": 0.0, "choices": [
		{"text": "one", "action_id": "close", "next": "close"},
		{"text": "two", "action_id": "close", "next": "close"},
		{"text": "three", "action_id": "close", "next": "close"},
	]}]})
	await process_frame
	_assert(dialog.current_choices.size() == 3 and dialog.choice_buttons.size() >= 3, "Dialogue did not support editable choice count")
	dialog.close_without_signal()
	dialog.queue_free()
	await process_frame


func _test_opening_scene() -> void:
	var opening := OPENING_SCENE.instantiate()
	opening.text_event_id = &"opening_first_night"
	root.add_child(opening)
	await process_frame
	_assert(opening.paragraphs.size() == 4, "Opening did not load four editable lines")
	_assert(opening.paragraphs[0] == "星期一。", "Opening first line mismatch")
	_assert(is_equal_approx(float(opening.current_line.get("typewriter_speed", 0.0)), 0.05), "Opening per-line speed missing")
	opening.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
