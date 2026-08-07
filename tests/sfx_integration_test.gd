extends SceneTree

const CONFIG := preload("res://resources/demo_config.tres")
const PHONE := preload("res://scenes/ui/bedroom_phone.tscn")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const DREAM := preload("res://scenes/dream/dream_world.tscn")
const RESULTS := preload("res://scenes/ui/results.tscn")
const DIALOG := preload("res://scenes/ui/confirmation_dialog.tscn")
const SFX_SCRIPT := preload("res://scripts/audio/sfx_manager.gd")

const EXPECTED_PATHS := {
	&"forbidden": "res://sfx/禁止选择音效.mp3",
	&"death": "res://sfx/角色死亡音.mp3",
	&"new_message": "res://sfx/手机新讯息.mp3",
	&"purchase": "res://sfx/购买音效.mp3",
	&"laser": "res://sfx/激光武器音效.mp3",
	&"home_door": "res://sfx/回家开门音效.mp3",
	&"work": "res://sfx/上班音效.mp3",
	&"confirm": "res://sfx/确定按钮音效.mp3",
	&"experience": "res://sfx/获取经验值的音效.mp3"
}

var failures: Array[String] = []
var counts: Dictionary = {}


func _initialize() -> void:
	if root.get_node_or_null("SFXManager") == null:
		var manager := SFX_SCRIPT.new()
		manager.name = "SFXManager"
		root.add_child(manager)
	for action in ["move_left", "move_right", "move_up", "move_down", "dash", "interact", "skill_menu"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_run")


func _run() -> void:
	_manager().sfx_played.connect(_on_sfx_played)
	_test_manager_resources_and_buses()
	await _test_phone_message_and_purchase_events()
	await _test_character_weapon_and_experience_events()
	await _test_results_and_confirmation_events()
	for event_id in EXPECTED_PATHS:
		_manager().stop(event_id)
	_manager().queue_free()
	await process_frame
	if failures.is_empty():
		print("SFX INTEGRATION TEST PASSED: manager -> buses -> UI -> character -> weapon -> environment")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_manager_resources_and_buses() -> void:
	for event_id in EXPECTED_PATHS:
		_assert(_manager().players.has(event_id), "Missing managed SFX player: " + str(event_id))
		if _manager().players.has(event_id):
			var player: AudioStreamPlayer = _manager().players[event_id]
			_assert(player.stream != null and player.stream.resource_path == EXPECTED_PATHS[event_id], "Wrong stream mapping: " + str(event_id))
	for bus_name in ["UI", "Weapons", "Characters", "Environment"]:
		_assert(AudioServer.get_bus_index(bus_name) >= 0, "Missing audio bus: " + bus_name)


func _test_phone_message_and_purchase_events() -> void:
	var phone := PHONE.instantiate()
	root.add_child(phone)
	await process_frame
	var meta := {
		"balance": 200,
		"ram": 0,
		"melatonin_inventory": 0,
		"permanent_upgrades": {"visual_cortex": 0, "brainstem": 0, "hippocampus": 0, "prefrontal": 0},
		"online_messages": [{"category": "测试", "text": "新消息", "is_read": false}]
	}
	phone.configure_state(meta)
	_assert(_count(&"new_message") == 1, "New unread message batch did not play exactly once")
	phone.configure_state(meta)
	phone._open_app("online")
	_assert(_count(&"new_message") == 1, "Opening/reconfiguring ONLINE replayed the same message batch")
	phone._purchase_melatonin()
	_assert(_count(&"purchase") == 1 and meta.melatonin_inventory == 1, "Successful QuickLink purchase did not play purchase SFX once")
	meta.balance = 0
	phone._purchase_melatonin()
	phone._purchase_permanent_upgrade("visual_cortex")
	_assert(_count(&"forbidden") == 2, "Failed balance/RAM actions did not use forbidden SFX")
	phone.queue_free()
	await process_frame


func _test_character_weapon_and_experience_events() -> void:
	var revived_player := PLAYER.instantiate()
	root.add_child(revived_player)
	await process_frame
	revived_player.enable_dissociation(CONFIG)
	revived_player.receive_damage(9999.0)
	_assert(_count(&"death") == 0 and not revived_player.dead, "Dissociation incorrectly played death SFX")
	revived_player.beam_weapon._fire_beam(Vector2.RIGHT)
	_assert(_count(&"laser") == 1, "Actual beam emission did not play laser SFX")
	var dead_player := PLAYER.instantiate()
	root.add_child(dead_player)
	await process_frame
	dead_player.receive_damage(9999.0)
	_assert(_count(&"death") == 1 and dead_player.dead, "Formal lethal death did not play death SFX once")
	var dream := DREAM.instantiate()
	root.add_child(dream)
	await process_frame
	dream._on_experience_collected(1)
	dream._on_experience_collected(1)
	_assert(_count(&"experience") == 1 and dream.experience == 2, "Experience pickup rate limit or reward application failed")
	dream.queue_free()
	revived_player.queue_free()
	dead_player.queue_free()
	await process_frame


func _test_results_and_confirmation_events() -> void:
	var results := RESULTS.instantiate()
	var fast_config: DemoConfig = CONFIG.duplicate(true)
	fast_config.door_open_close_gap_seconds = 0.0
	results.config = fast_config
	results.summary = {"attendance_status": "正常上班"}
	root.add_child(results)
	await process_frame
	results._play_work_if_applicable()
	results._play_work_if_applicable()
	_assert(_count(&"work") == 1, "Normal-work SFX did not play exactly once")
	results._on_start_new_day()
	_assert(_count(&"home_door") == 1, "New-day transition did not play home-door SFX once")
	await create_timer(0.35).timeout
	var late_results := RESULTS.instantiate()
	late_results.summary = {"attendance_status": "严重迟到"}
	root.add_child(late_results)
	await process_frame
	late_results._play_work_if_applicable()
	_assert(_count(&"work") == 1, "Late result incorrectly played normal-work SFX")
	var dialog := DIALOG.instantiate()
	root.add_child(dialog)
	await process_frame
	dialog.open("确认？", "确认", "返回")
	dialog.animating = false
	dialog._on_confirmed()
	_assert(_count(&"confirm") == 1, "Ordinary dialog confirmation did not play confirm SFX")
	results.queue_free()
	late_results.queue_free()
	dialog.queue_free()
	await process_frame


func _on_sfx_played(event_id: StringName) -> void:
	counts[event_id] = _count(event_id) + 1


func _manager() -> Node:
	return root.get_node("SFXManager")


func _count(event_id: StringName) -> int:
	return int(counts.get(event_id, 0))


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
