class_name TarotCardCatalog
extends RefCounted

const DEFAULT_CARD_BACK_PATH: String = "res://art/ui/tarot/card_back.png"

const CARD_DATA: Array[Dictionary] = [
	{
		"index": 0,
		"id": &"the_fool",
		"display_name_zh": "愚者",
		"display_name_en": "The Fool",
		"texture_path": "res://art/ui/tarot/the_fool.png",
	},
	{
		"index": 1,
		"id": &"the_magician",
		"display_name_zh": "魔术师",
		"display_name_en": "The Magician",
		"texture_path": "res://art/ui/tarot/the_magician.png",
	},
	{
		"index": 2,
		"id": &"the_high_priestess",
		"display_name_zh": "女祭司",
		"display_name_en": "The High Priestess",
		"texture_path": "res://art/ui/tarot/the_high_priestess.png",
	},
	{
		"index": 3,
		"id": &"the_empress",
		"display_name_zh": "皇后",
		"display_name_en": "The Empress",
		"texture_path": "res://art/ui/tarot/the_empress.png",
	},
	{
		"index": 4,
		"id": &"the_emperor",
		"display_name_zh": "皇帝",
		"display_name_en": "The Emperor",
		"texture_path": "res://art/ui/tarot/the_emperor.png",
	},
	{
		"index": 5,
		"id": &"the_hierophant",
		"display_name_zh": "教皇",
		"display_name_en": "The Hierophant",
		"texture_path": "res://art/ui/tarot/the_hierophant.png",
	},
	{
		"index": 6,
		"id": &"the_lovers",
		"display_name_zh": "恋人",
		"display_name_en": "The Lovers",
		"texture_path": "res://art/ui/tarot/the_lovers.png",
	},
	{
		"index": 7,
		"id": &"the_chariot",
		"display_name_zh": "战车",
		"display_name_en": "The Chariot",
		"texture_path": "res://art/ui/tarot/the_chariot.png",
	},
	{
		"index": 8,
		"id": &"strength",
		"display_name_zh": "力量",
		"display_name_en": "Strength",
		"texture_path": "res://art/ui/tarot/strength.png",
	},
	{
		"index": 9,
		"id": &"the_hermit",
		"display_name_zh": "隐士",
		"display_name_en": "The Hermit",
		"texture_path": "res://art/ui/tarot/the_hermit.png",
	},
	{
		"index": 10,
		"id": &"wheel_of_fortune",
		"display_name_zh": "命运之轮",
		"display_name_en": "Wheel of Fortune",
		"texture_path": "res://art/ui/tarot/wheel_of_fortune.png",
	},
	{
		"index": 11,
		"id": &"justice",
		"display_name_zh": "正义",
		"display_name_en": "Justice",
		"texture_path": "res://art/ui/tarot/justice.png",
	},
	{
		"index": 12,
		"id": &"the_hanged_man",
		"display_name_zh": "倒吊人",
		"display_name_en": "The Hanged Man",
		"texture_path": "res://art/ui/tarot/the_hanged_man.png",
	},
	{
		"index": 13,
		"id": &"death",
		"display_name_zh": "死神",
		"display_name_en": "Death",
		"texture_path": "res://art/ui/tarot/death.png",
	},
	{
		"index": 14,
		"id": &"temperance",
		"display_name_zh": "节制",
		"display_name_en": "Temperance",
		"texture_path": "res://art/ui/tarot/temperance.png",
	},
	{
		"index": 15,
		"id": &"the_devil",
		"display_name_zh": "恶魔",
		"display_name_en": "The Devil",
		"texture_path": "res://art/ui/tarot/the_devil.png",
	},
	{
		"index": 16,
		"id": &"the_tower",
		"display_name_zh": "高塔",
		"display_name_en": "The Tower",
		"texture_path": "res://art/ui/tarot/the_tower.png",
	},
	{
		"index": 17,
		"id": &"the_star",
		"display_name_zh": "星星",
		"display_name_en": "The Star",
		"texture_path": "res://art/ui/tarot/the_star.png",
	},
	{
		"index": 18,
		"id": &"the_moon",
		"display_name_zh": "月亮",
		"display_name_en": "The Moon",
		"texture_path": "res://art/ui/tarot/the_moon.png",
	},
	{
		"index": 19,
		"id": &"the_sun",
		"display_name_zh": "太阳",
		"display_name_en": "The Sun",
		"texture_path": "res://art/ui/tarot/the_sun.png",
	},
	{
		"index": 20,
		"id": &"judgement",
		"display_name_zh": "审判",
		"display_name_en": "Judgement",
		"texture_path": "res://art/ui/tarot/judgement.png",
	},
	{
		"index": 21,
		"id": &"the_world",
		"display_name_zh": "世界",
		"display_name_en": "The World",
		"texture_path": "res://art/ui/tarot/the_world.png",
	},
]

static var _cards_cache: Array[TarotCardDefinition] = []
static var _cards_by_id: Dictionary = {}
static var _cards_by_index: Dictionary = {}
static var _back_texture: Texture2D = null


static func _ensure_initialized() -> void:
	if not _cards_cache.is_empty():
		return

	if ResourceLoader.exists(DEFAULT_CARD_BACK_PATH):
		_back_texture = load(DEFAULT_CARD_BACK_PATH) as Texture2D

	for data in CARD_DATA:
		var def := TarotCardDefinition.new()
		def.id = data["id"]
		def.arcana_index = data["index"]
		def.display_name_zh = data["display_name_zh"]
		def.display_name_en = data["display_name_en"]
		var tex_path: String = data["texture_path"]
		if ResourceLoader.exists(tex_path):
			def.front_texture = load(tex_path) as Texture2D
		def.back_texture = _back_texture
		_cards_cache.append(def)
		_cards_by_id[def.id] = def
		_cards_by_index[def.arcana_index] = def


static func get_card(id: StringName) -> TarotCardDefinition:
	_ensure_initialized()
	return _cards_by_id.get(StringName(id), null)


static func get_card_by_index(index: int) -> TarotCardDefinition:
	_ensure_initialized()
	return _cards_by_index.get(index, null)


static func get_all_cards() -> Array[TarotCardDefinition]:
	_ensure_initialized()
	return _cards_cache.duplicate()


static func get_card_back_texture() -> Texture2D:
	_ensure_initialized()
	return _back_texture
