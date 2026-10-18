class_name TarotDrawResult
extends RefCounted

var card_def: TarotCardDefinition
var is_reversed: bool = false


func _init(p_card_def: TarotCardDefinition = null, p_is_reversed: bool = false) -> void:
	card_def = p_card_def
	is_reversed = p_is_reversed


func get_id() -> StringName:
	return card_def.id if card_def != null else &""


func get_display_name_zh() -> String:
	return card_def.display_name_zh if card_def != null else ""


func get_orientation_name_zh() -> String:
	return "逆位" if is_reversed else "正位"


func get_full_title_zh() -> String:
	return "%s · %s" % [get_display_name_zh(), get_orientation_name_zh()]


func to_dictionary() -> Dictionary:
	return {
		"card_id": get_id(),
		"is_reversed": is_reversed,
		"arcana_index": card_def.arcana_index if card_def != null else -1,
	}
