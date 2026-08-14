class_name DayStartSnapshot
extends RefCounted

var state: Dictionary = {}


func capture(source_state: Dictionary) -> void:
	state = source_state.duplicate(true)
	state.has_entered_dream = false


func restore(fallback_state: Dictionary = {}) -> Dictionary:
	var restored := state.duplicate(true) if not state.is_empty() else fallback_state.duplicate(true)
	restored.has_entered_dream = false
	return restored


func is_empty() -> bool:
	return state.is_empty()


## 少数明确属于剧情持久进度的字段（如当前武器）可在局中同步，
## 避免“退出到主菜单”恢复当天快照时把它误回滚。
func set_persistent_value(key: StringName, value: Variant) -> void:
	if not state.is_empty():
		state[key] = value
