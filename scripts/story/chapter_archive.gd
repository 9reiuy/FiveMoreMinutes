extends Control
## Raw observations and a reference table; never solves the archive for the player.
signal changed
const FONT = preload("res://scripts/ui/crisp_interaction_font.gd")
const RULES = preload("res://scripts/story/chapter_one_state.gd")
const MORSE = ["A .-","B -...","C -.-.","D -..","E .","F ..-.","G --.","H ....","I ..","J .---","K -.-","L .-..","M --","N -.","O ---","P .--.","Q --.-","R .-.","S ...","T -","U ..-","V ...-","W .--","X -..-","Y -.--","Z --..","0 -----","1 .----","2 ..---","3 ...--","4 ....-","5 .....","6 -....","7 --...","8 ---..","9 ----."]
var profile: Dictionary
var input: LineEdit
var feedback: Label
var notebook: VBoxContainer
var tabs: TabContainer
func configure(state: Dictionary) -> void:
	profile = state
	if profile.get("chapter_one") is Dictionary: RULES.ensure_observations(profile.chapter_one)
func _ready() -> void:
	var background := StyleBoxFlat.new(); background.bg_color = Color("192331")
	add_theme_stylebox_override("panel", background)
	tabs = TabContainer.new(); add_child(tabs); tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.add_theme_stylebox_override("panel", background)
	for kind in ["tab_selected", "tab_unselected", "tab_hovered"]:
		var tab_skin:=StyleBoxFlat.new(); tab_skin.bg_color=Color("53647c") if kind=="tab_selected" else Color("27354a")
		tab_skin.border_color=Color("71849d"); tab_skin.set_border_width_all(1)
		tab_skin.content_margin_left=8; tab_skin.content_margin_right=8; tab_skin.content_margin_top=4; tab_skin.content_margin_bottom=4
		tabs.add_theme_stylebox_override(kind,tab_skin)
	for key in ["font_selected_color","font_unselected_color","font_hovered_color"]: tabs.add_theme_color_override(key,Color("d6e0e6"))
	tabs.add_theme_font_override("font", FONT.get_font()); tabs.add_theme_font_size_override("font_size", 12)
	var archive := _page("加密档案")
	_text(archive, "anonymous.7z  //  发件人：未知")
	_text(archive, "文件已加密。完整密钥仍未知。")
	input = LineEdit.new(); input.placeholder_text = "密钥"; input.max_length = 32; input.secret = true
	input.text_submitted.connect(func(_value): verify()); archive.add_child(input); _font(input)
	var button := Button.new(); button.text = "尝试解密"; button.pressed.connect(verify); archive.add_child(button); _font(button)
	feedback = _text(archive, "")
	notebook = _page("观测笔记")
	_refresh_notes()
	var reference := _page("电码对照")
	_text(reference, "短光点为 .    长光带为 -\n按空间顺序抄录；字母之间留空格。")
	var grid := GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 15); reference.add_child(grid)
	for entry in MORSE: _text(grid, entry)
	visibility_changed.connect(func():
		if visible and is_instance_valid(notebook): _refresh_notes())
func _font(item: Control) -> void:
	item.add_theme_font_override("font", FONT.get_font()); item.add_theme_font_size_override("font_size", 12)
	item.add_theme_color_override("font_color", Color("d6e0e6"))
func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.name = title; tabs.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10); scroll.add_child(box)
	return box
func _text(parent: Node, text: String) -> Label:
	var label := Label.new(); label.text = text; _font(label); parent.add_child(label)
	return label
func _refresh_notes() -> void:
	for child in notebook.get_children(): notebook.remove_child(child); child.queue_free()
	var story: Dictionary = profile.get("chapter_one", {})
	RULES.ensure_observations(story)
	if story.get("observations", []).is_empty():
		_text(notebook, "尚无观测记录。\n先观察，才能留下笔记。"); return
	for record in story.observations:
		_text(notebook, "第%d夜 · 海天线光点\n原始记录：%s\n这是空间排列；译文由你填写。" % [int(record.chapter), str(record.symbols)])
		var translation := LineEdit.new(); translation.placeholder_text = "我的译文（不会自动解密）"
		translation.max_length = 32; translation.text = str(record.get("translation", "")); _font(translation); notebook.add_child(translation)
		translation.text_changed.connect(func(value: String):
			record.translation = value; changed.emit())
func verify() -> bool:
	feedback.text = "无法解密。完整密钥尚未集齐。"
	return false
