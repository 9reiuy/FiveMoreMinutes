class_name TarotCardDefinition
extends Resource

@export var id: StringName = &""
@export var arcana_index: int = 0
@export var display_name_zh: String = ""
@export var display_name_en: String = ""
@export var front_texture: Texture2D
@export var back_texture: Texture2D
@export var effect_id: StringName = &""
@export var upright_description: String = ""
@export var reversed_description: String = ""


func _init(
	p_id: StringName = &"",
	p_arcana_index: int = 0,
	p_display_name_zh: String = "",
	p_display_name_en: String = "",
	p_front_texture: Texture2D = null,
	p_back_texture: Texture2D = null,
	p_effect_id: StringName = &"",
	p_upright_description: String = "",
	p_reversed_description: String = ""
) -> void:
	id = p_id
	arcana_index = p_arcana_index
	display_name_zh = p_display_name_zh
	display_name_en = p_display_name_en
	front_texture = p_front_texture
	back_texture = p_back_texture
	effect_id = p_effect_id
	upright_description = p_upright_description
	reversed_description = p_reversed_description
