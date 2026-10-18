class_name TextContent
extends RefCounted

## Read-only narrative data index. Gameplay code asks for stable IDs; this class
## loads UTF-8 JSON under res://data and never writes back to those files.

const DIALOGUE_FILES := [
	"res://data/dialogue/bedroom.json",
	"res://data/dialogue/hallway.json",
	"res://data/dialogue/computer.json",
	"res://data/dialogue/phone.json",
	"res://data/dialogue/dream.json",
	"res://data/dialogue/tutorial.json",
	"res://data/dialogue/boss.json",
	"res://data/dialogue/common.json",
]
const TEXT_EVENT_FILES := [
	"res://data/text_events/opening.json",
	"res://data/text_events/endings.json",
	"res://data/text_events/nightmare.json",
	"res://data/text_events/story_events.json",
]

## Narrative data can request only these symbolic actions. No method name or
## arbitrary GDScript expression is ever evaluated from JSON.
const ALLOWED_ACTION_IDS := {
	"close": true,
	"begin_sleep": true,
	"begin_hungry_sleep": true,
	"open_quicklink": true,
	"defer_food_purchase": true,
	"take_melatonin": true,
	"finish_delivery_meal": true,
	"start_tarot": true,
	"skip_tarot": true,
}

static var _loaded := false
static var _dialogues: Dictionary = {}
static var _text_events: Dictionary = {}
static var _roots_by_file: Dictionary = {}
static var _source_by_id: Dictionary = {}


static func reload() -> void:
	_loaded = false
	_dialogues.clear()
	_text_events.clear()
	_roots_by_file.clear()
	_source_by_id.clear()
	_ensure_loaded()


static func get_dialogue(dialogue_id: StringName, replacements: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	var key := str(dialogue_id)
	var entry: Variant = _dialogues.get(key)
	if not entry is Dictionary:
		_data_error("<dialogue index>", key, -1, "dialogue id does not exist")
		entry = _dialogues.get("common_missing_dialogue", _fallback_entry(key, "……"))
	var normalized: Dictionary = entry.duplicate(true)
	normalized["lines"] = _pick_entry_lines(normalized)
	return _replace_tokens(normalized, replacements)


## random 条目：每次读取从 lines 中随机抽取一条，作为本次对话的唯一行。
## 非 random 条目保持原有顺序播放，行为不变。
static func _pick_entry_lines(entry: Dictionary) -> Array:
	var lines: Array = entry.get("lines", [])
	if bool(entry.get("random", false)) and lines.size() > 1:
		return [lines[randi() % lines.size()]]
	return lines


static func get_text_event(event_id: StringName, replacements: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	var key := str(event_id)
	var entry: Variant = _text_events.get(key)
	if not entry is Dictionary:
		_data_error("<text event index>", key, -1, "text event id does not exist")
		entry = _text_events.get("common_missing_event", _fallback_entry(key, "……"))
	return _replace_tokens(entry.duplicate(true), replacements)


static func get_event_lines(event_id: StringName, replacements: Dictionary = {}) -> Array:
	return get_text_event(event_id, replacements).get("lines", []).duplicate(true)


static func get_phone_message_templates() -> Array:
	_ensure_loaded()
	var root: Variant = _roots_by_file.get("res://data/dialogue/phone.json", {})
	return root.get("messages", []).duplicate(true) if root is Dictionary else []


static func get_initial_phone_messages() -> Array:
	var initial_messages: Array = []
	for message in get_phone_message_templates():
		if message is Dictionary and bool(message.get("initial", false)):
			initial_messages.append(message.duplicate(true))
	return initial_messages


static func get_phone_message(message_id: StringName) -> Dictionary:
	for message in get_phone_message_templates():
		if message is Dictionary and str(message.get("id", "")) == str(message_id):
			return message.duplicate(true)
	_data_error("res://data/dialogue/phone.json", str(message_id), -1, "phone message id does not exist")
	return {}


static func is_action_allowed(action_id: StringName) -> bool:
	return str(action_id).is_empty() or ALLOWED_ACTION_IDS.has(str(action_id))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for path in DIALOGUE_FILES:
		_load_file(path, "dialogues", _dialogues)
	for path in TEXT_EVENT_FILES:
		_load_file(path, "events", _text_events)
	_validate_links()


static func _load_file(path: String, collection_key: String, target: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		_data_error(path, "", -1, "file does not exist")
		return
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		_data_error(path, "", json.get_error_line(), json.get_error_message())
		return
	var root: Variant = json.data
	if not root is Dictionary:
		_data_error(path, "", -1, "root must be an object")
		return
	_roots_by_file[path] = root
	var entries: Variant = root.get(collection_key, [])
	if not entries is Array:
		_data_error(path, "", -1, "'%s' must be an array" % collection_key)
		return
	for entry_index in entries.size():
		var entry: Variant = entries[entry_index]
		if not entry is Dictionary:
			_data_error(path, "", entry_index, "entry must be an object")
			continue
		var entry_id := str(entry.get("id", "")).strip_edges()
		if entry_id.is_empty():
			_data_error(path, "", entry_index, "entry is missing id")
			continue
		if target.has(entry_id):
			_data_error(path, entry_id, entry_index, "duplicate id")
			continue
		var normalized: Dictionary = entry.duplicate(true)
		if not normalized.has("lines") and normalized.has("text"):
			normalized.lines = [{"text": str(normalized.text)}]
		if not normalized.get("lines", []) is Array or normalized.get("lines", []).is_empty():
			_data_error(path, entry_id, entry_index, "entry requires a non-empty lines array")
			continue
		_validate_entry_lines(path, entry_id, normalized.lines)
		target[entry_id] = normalized
		_source_by_id[entry_id] = path


static func _validate_entry_lines(path: String, entry_id: String, lines: Array) -> void:
	for line_index in lines.size():
		var line: Variant = lines[line_index]
		if not line is Dictionary:
			_data_error(path, entry_id, line_index, "line must be an object")
			continue
		if not line.has("text"):
			_data_error(path, entry_id, line_index, "line is missing text")
		var choices: Variant = line.get("choices", [])
		if not choices is Array:
			_data_error(path, entry_id, line_index, "choices must be an array")
			continue
		for choice_index in choices.size():
			var choice: Variant = choices[choice_index]
			if not choice is Dictionary or str(choice.get("text", "")).is_empty():
				_data_error(path, entry_id, line_index, "choice %d is missing text" % choice_index)
				continue
			var action_id := StringName(str(choice.get("action_id", "")))
			if not is_action_allowed(action_id):
				_data_error(path, entry_id, line_index, "choice %d uses blocked action_id '%s'" % [choice_index, action_id])
	var completion_action := StringName(str(_line_or_empty(lines.back()).get("completion_action_id", "")))
	if not is_action_allowed(completion_action):
		_data_error(path, entry_id, lines.size() - 1, "blocked completion_action_id '%s'" % completion_action)


static func _validate_links() -> void:
	for entry_id in _dialogues:
		var entry: Dictionary = _dialogues[entry_id]
		for line_index in entry.lines.size():
			var line: Dictionary = _line_or_empty(entry.lines[line_index])
			for choice in line.get("choices", []):
				if not choice is Dictionary:
					continue
				var next_id := str(choice.get("next", "close"))
				if next_id != "close" and not next_id.is_empty() and not _dialogues.has(next_id):
					_data_error(str(_source_by_id.get(entry_id, "<unknown>")), entry_id, line_index, "next id '%s' does not exist" % next_id)


static func _replace_tokens(value: Variant, replacements: Dictionary) -> Variant:
	if value is String:
		var result: String = str(value)
		for key in replacements:
			result = result.replace("{%s}" % str(key), str(replacements[key]))
		return result
	if value is Array:
		for index in value.size():
			value[index] = _replace_tokens(value[index], replacements)
		return value
	if value is Dictionary:
		for key in value.keys():
			value[key] = _replace_tokens(value[key], replacements)
		return value
	return value


static func _line_or_empty(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _fallback_entry(entry_id: String, text: String) -> Dictionary:
	return {
		"id": entry_id,
		"lines": [{
			"speaker": "system",
			"text": text,
			"typewriter_speed": 0.04,
			"text_color": "#FFFFFF",
			"blip": false,
			"wait_for_input": true,
		}],
	}


static func _data_error(path: String, entry_id: String, line: int, reason: String) -> void:
	push_error("[DIALOGUE DATA ERROR]\nfile: %s\nid: %s\nline: %s\nreason: %s" % [path, entry_id, str(line) if line >= 0 else "-", reason])
