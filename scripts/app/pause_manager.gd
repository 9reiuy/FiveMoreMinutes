extends Node

signal pause_state_changed(paused: bool)

## 全局暂停只由原因集合决定。任何界面都只能释放自己持有的原因。
const UPGRADE: StringName = &"UPGRADE"
const ESC_MENU: StringName = &"ESC_MENU"
const DIALOGUE: StringName = &"DIALOGUE"
const MODAL_ANIMATION: StringName = &"MODAL_ANIMATION"
const SKILLS_MENU: StringName = &"SKILLS_MENU"

var pause_reasons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_pause_state()


func request_pause(reason: StringName) -> void:
	if reason.is_empty():
		return
	pause_reasons[reason] = true
	refresh_pause_state()


func release_pause(reason: StringName) -> void:
	pause_reasons.erase(reason)
	refresh_pause_state()


func has_pause_reason(reason: StringName) -> bool:
	return pause_reasons.has(reason)


func clear_all() -> void:
	pause_reasons.clear()
	refresh_pause_state()


func refresh_pause_state() -> void:
	if get_tree() != null:
		var should_pause := not pause_reasons.is_empty()
		var changed := get_tree().paused != should_pause
		get_tree().paused = should_pause
		if changed:
			pause_state_changed.emit(should_pause)
