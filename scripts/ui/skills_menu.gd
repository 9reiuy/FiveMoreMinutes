extends Control

signal close_requested

@onready var skill_list: VBoxContainer = $Margin/Columns/SkillsPanel/Content/Body/SkillScroll/SkillList
@onready var attribute_list: VBoxContainer = $Margin/Columns/AttributesPanel/Content/Body/AttributeScroll/AttributeList

var cards: Array[Dictionary] = []
var stats: Array[Dictionary] = []
var states: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(new_cards: Array[Dictionary], new_stats: Array[Dictionary], new_states: Dictionary) -> void:
	cards = new_cards
	stats = new_stats
	states = new_states
	_rebuild_skill_list()
	_rebuild_attribute_list()
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("skill_menu"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _rebuild_skill_list() -> void:
	_clear_container(skill_list)
	if cards.is_empty():
		skill_list.add_child(_make_label("尚未获取卡片技能", 12, Color("70737e")))
		return
	for card in cards:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		var title := str(card.get("name", "技能"))
		if int(card.get("level", 1)) > 1:
			title += " ×%d" % int(card.level)
		block.add_child(_make_label(title, 13, Color("c3c0c8")))
		block.add_child(_make_label(str(card.get("rarity_name", "")), 10, _rarity_color(str(card.get("rarity", "blue")))))
		block.add_child(_make_wrapped_label(str(card.get("effect", "")), 10, Color("858c98")))
		skill_list.add_child(block)
		skill_list.add_child(HSeparator.new())


func _rebuild_attribute_list() -> void:
	_clear_container(attribute_list)
	for stat in stats:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 3)
		block.add_child(_make_label(str(stat.get("name", "属性")), 13, Color("c9c4ce")))
		var values := GridContainer.new()
		values.columns = 2
		values.add_theme_constant_override("h_separation", 18)
		values.add_theme_constant_override("v_separation", 2)
		_add_stat_value(values, "基础", stat.get("base", 0), Color("747985"))
		_add_stat_value(values, "永久", stat.get("permanent", 0), Color("7f8898"))
		_add_stat_value(values, "卡片", stat.get("cards", 0), Color("96859f"))
		_add_stat_value(values, "最终", stat.get("final", 0), Color("d0cbd2"))
		block.add_child(values)
		attribute_list.add_child(block)
		attribute_list.add_child(HSeparator.new())
	attribute_list.add_child(_make_label("一次性护盾：" + ("已准备" if states.get("shield", false) else "未准备"), 11, Color("8ebad0")))
	attribute_list.add_child(_make_label("致命伤复活：" + ("可用" if states.get("revive", false) else "不可用"), 11, Color("d7b45f")))
	attribute_list.add_child(_make_label("受伤减速：" + ("已解锁" if states.get("rapid_eye", false) else "未解锁"), 11, Color("a78bc0")))


func _add_stat_value(grid: GridContainer, name: String, value: Variant, color: Color) -> void:
	grid.add_child(_make_label(name, 10, color))
	grid.add_child(_make_label(str(value), 11, Color("c7c4cb")))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_wrapped_label(text: String, font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _rarity_color(rarity: String) -> Color:
	if rarity == "gold": return Color("d7b45f")
	if rarity == "purple": return Color("a779c7")
	return Color("668fc3")
