extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONFIG := preload("res://resources/demo_config.tres")

signal upgrade_chosen(option: Dictionary)
signal refresh_requested

const REFRESH_RECT := Rect2(246, 310, 148, 34)

var accepting_input := false
var target_level := 2
var options: Array[Dictionary] = []
var hovered_index := -1
var refresh_hovered := false
var refreshes_remaining := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func open(new_level: int, new_options: Array[Dictionary], refresh_count: int = 1) -> void:
	target_level = new_level
	options = new_options
	refreshes_remaining = maxi(0, refresh_count)
	visible = true
	accepting_input = true
	hovered_index = -1
	refresh_hovered = false
	queue_redraw()


func replace_options(new_options: Array[Dictionary]) -> void:
	options = new_options
	hovered_index = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible or not accepting_input:
		return
	if event is InputEventMouseMotion:
		var previous_refresh := refresh_hovered
		var previous_index := hovered_index
		refresh_hovered = REFRESH_RECT.has_point(event.position)
		hovered_index = -1
		for index in mini(options.size(), 3):
			if _card_rect(index).has_point(event.position):
				hovered_index = index
				break
		if (hovered_index >= 0 and hovered_index != previous_index) or (refresh_hovered and not previous_refresh):
			SFX.play_event(&"ui_hover")
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if REFRESH_RECT.has_point(event.position):
			if refreshes_remaining > 0:
				refreshes_remaining -= 1
				SFX.play_event(&"confirm")
				refresh_requested.emit()
			else:
				SFX.play_event(&"forbidden")
			queue_redraw()
			accept_event()
			return
		for index in mini(options.size(), 3):
			if _card_rect(index).has_point(event.position):
				_choose(index)
				accept_event()
				return


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not accepting_input or not event is InputEventKey or not event.pressed:
		return
	var index := -1
	if event.keycode == KEY_1: index = 0
	elif event.keycode == KEY_2: index = 1
	elif event.keycode == KEY_3: index = 2
	if index >= 0 and index < options.size():
		_choose(index)
		get_viewport().set_input_as_handled()


func _choose(index: int) -> void:
	accepting_input = false
	SFX.play_event(&"confirm")
	visible = false
	upgrade_chosen.emit(options[index].duplicate(true))


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.018, 0.03, 0.88))
	var font := PixelFont.get_font()
	draw_string(font, Vector2(0, 67), "梦境正在加深 · 等级 %d" % target_level, HORIZONTAL_ALIGNMENT_CENTER, 640, 21, Color("c3bacb"))
	for index in options.size():
		var option := options[index]
		var base_rect := _card_rect(index)
		var rect: Rect2 = base_rect.grow(3.0) if hovered_index == index else base_rect
		var rarity_color := _rarity_color(str(option.rarity))
		var fill := CONFIG.ui_panel_background_color.lightened(CONFIG.ui_hover_brightness) if hovered_index == index else CONFIG.ui_panel_background_color
		draw_rect(rect, fill)
		draw_rect(rect, CONFIG.ui_border_color if hovered_index == index else rarity_color.darkened(0.25), false, 2.0)
		draw_line(rect.position + Vector2(5, 5), rect.position + Vector2(18, 5), rarity_color, 2.0)
		draw_line(rect.end - Vector2(18, 5), rect.end - Vector2(5, 5), rarity_color, 2.0)
		draw_string(font, Vector2(rect.position.x, rect.position.y + 32), _rarity_name(str(option.rarity)), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, rarity_color)
		draw_string(font, Vector2(rect.position.x + 8, rect.position.y + 70), str(option.name), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 17, Color("d2ccd5"))
		draw_multiline_string(font, Vector2(rect.position.x + 15, rect.position.y + 103), str(option.description), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 30, 12, -1, Color("9ca4ad"))
		draw_string(font, Vector2(rect.position.x, rect.end.y - 18), "点击选择 / 数字 %d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, Color("777986"))
	var refresh_enabled := refreshes_remaining > 0
	var refresh_fill := Color("343947") if refresh_enabled and refresh_hovered else Color("252833")
	var refresh_border := Color("a5b5c4") if refresh_enabled else Color("494b55")
	draw_rect(REFRESH_RECT, refresh_fill)
	draw_rect(REFRESH_RECT, refresh_border, false, 2.0)
	draw_string(font, Vector2(REFRESH_RECT.position.x, REFRESH_RECT.position.y + 22), "刷新    次数：%d" % refreshes_remaining, HORIZONTAL_ALIGNMENT_CENTER, REFRESH_RECT.size.x, 13, Color("d1d5dc") if refresh_enabled else Color("686a72"))


func _card_rect(index: int) -> Rect2:
	var gap := 14.0
	var total_width := CONFIG.ui_card_size.x * 3.0 + gap * 2.0
	var start_x := (640.0 - total_width) * 0.5
	return Rect2(start_x + index * (CONFIG.ui_card_size.x + gap), 102.0, CONFIG.ui_card_size.x, CONFIG.ui_card_size.y)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"purple": return Color("a779c7")
		"gold": return Color("d7b45f")
		_: return Color("668fc3")


func _rarity_name(rarity: String) -> String:
	match rarity:
		"purple": return "紫色"
		"gold": return "金色"
		_: return "蓝色"
