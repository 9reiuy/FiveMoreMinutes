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
