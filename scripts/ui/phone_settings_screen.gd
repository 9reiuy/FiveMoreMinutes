class_name PhoneSettingsScreen
extends Control

signal close_requested
signal action_requested(action: StringName)
signal page_changed(page: StringName)
signal profile_changed
signal feedback_requested(action: StringName, pressed: bool)
signal interaction_lock_changed(locked: bool)
signal story_effect_requested(effect: StringName)

const FONT := preload("res://assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const APPS := preload("res://scripts/ui/phone_apps_model.gd")
const DRAG_SCROLL := preload("res://scripts/ui/phone_drag_scroll.gd")
const SCREEN_SIZE := Vector2(148, 230)
const CONTENT_RECT := Rect2(5, 30, 138, 174)
const FOOTER_HEIGHT := 21.0
const INK := Color("22394b")
const MUTED := Color("63798b")
const HIGHLIGHT := Color("a3c6dd")
const QUALITIES := ["low", "standard", "high"]
const QUALITY_LABELS := ["低", "默认", "高"]
const HOME_APPS := [&"chat", &"call", &"music", &"shop"]
var apps_model := APPS.new()
var _context: StringName = &"game"
var _page: StringName = &"home"
var _history: Array[StringName] = []
var _selections: Dictionary = {}
var _manager: Node
var _saved := false
var _drag_setting: StringName = &""
var _pointer_down := false
var _feedback: StringName = &""
var _locked := false
var _scroll_lock_until := 0
var _scroll: ScrollContainer
var _cards: VBoxContainer
var _card_press := -1
var _poll_left := 0.0
var _content_signature := 0
var _note := ""
var _focus_region: StringName = &"content"
var _focused_softkey: StringName = &"home"
var _focus_memory: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = SCREEN_SIZE
	if is_equal_approx(anchor_left, anchor_right) and is_equal_approx(anchor_top, anchor_bottom):
		size = SCREEN_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	_manager = get_tree().root.get_node_or_null("SettingsManager")
	if _manager != null:
		_manager.connect("setting_changed", _on_setting_changed)
	apps_model.profile_changed.connect(_on_profile_changed)
	apps_model.story_effect_requested.connect(func(effect: StringName): story_effect_requested.emit(effect))
	_scroll = DRAG_SCROLL.new()
	_scroll.position = CONTENT_RECT.position
	_scroll.size = CONTENT_RECT.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 3
	add_child(_scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 5)
	_scroll.add_child(_cards)
	_refresh_content()

func configure_apps(profile: Dictionary, bedroom_phone: Control = null, clock_provider: Callable = Callable()) -> void:
	apps_model.configure(profile, bedroom_phone, clock_provider)
	_refresh_content()
	queue_redraw()

func set_context(context: StringName) -> void:
	_context = context
	_history.clear()
	_focus_memory.clear()
	_focus_region = &"content"
	_focused_softkey = &"home"
	_page = &"settings" if context == &"settings" else &"home"
	_note = ""
	cancel_interaction()
	_refresh_content()
	page_changed.emit(_page)
	queue_redraw()

func get_page_id() -> StringName: return _page
func get_selected_index() -> int: return int(_selections.get(_page, 0))
func get_page_content_rect() -> Rect2: return CONTENT_RECT
func get_interaction_locked() -> bool: return _locked
func get_focus_region() -> StringName: return _focus_region
func get_focused_softkey() -> StringName: return _focused_softkey

func get_softkey_rect(action: StringName) -> Rect2:
	return Rect2(3 if action == &"home" else 77, 210, 68, 19)

func open_app(id: StringName) -> void:
	if id in HOME_APPS or id == &"settings":
		_push_page(id)

func set_bedroom_pages(_chat: Control, _shop: Control) -> void:
	# Legacy review API retained; production apps use 12px data presentation.
	pass

func _set_locked(value: bool) -> void:
	if _locked != value:
		_locked = value
		interaction_lock_changed.emit(value)

func _press_feedback(action: StringName) -> void:
	if _feedback == action: return
	if not _feedback.is_empty(): feedback_requested.emit(_feedback, false)
	_feedback = action
	if not action.is_empty(): feedback_requested.emit(action, true)

func cancel_interaction() -> void:
	_pointer_down = false
	_drag_setting = &""
	_card_press = -1
	_scroll_lock_until = 0
	_press_feedback(&"")
	_set_locked(false)

func _rows() -> Array:
	match _page:
		&"settings": return [[&"sounds", "声音"], [&"graphics", "画面"], [&"assistance", "游戏辅助功能"]]
		&"assistance": return [[&"auto_vault_enabled", "自动跳跃"], [&"screen_shake_enabled", "屏幕抖动"]]
		&"sounds": return [[&"master_volume", "总音量"], [&"music_volume", "音乐"], [&"sfx_volume", "音效"]]
		&"graphics": return [[&"pixelation_enabled", "像素化"], [&"palette_enabled", "配色滤镜"], [&"shadow_quality", "阴影品质"]]
		&"music": return [[&"playback", "播放 / 暂停"], [&"music_volume", "音乐音量"]]
	return []

func _row_rect(index: int) -> Rect2:
	if _page == &"sounds": return Rect2(5, 39 + index * 45, 138, 39)
	if _page == &"music": return Rect2(5, 79 + index * 51, 138, 43)
	return Rect2(5, 40 + index * 43, 138, 37)

func _slider_rect(index: int) -> Rect2:
	return Rect2(13, 65 + index * 45, 122, 7) if _page == &"sounds" else Rect2(13, 158, 122, 7)

func _app_rect(index: int) -> Rect2:
	return Rect2(9 + (index % 2) * 67, 43 + (index / 2) * 73, 63, 65)

func get_control_point(id: StringName) -> Vector2:
	if id == &"back": return Vector2(119, 219)
	if id in [&"confirm", &"soft_left"]: return Vector2(30, 219)
	if _page == &"home":
		if id == &"settings": return Vector2(30, 219)
		var index := HOME_APPS.find(id)
		if index >= 0: return _app_rect(index).get_center()
	var rows := _rows()
	for index in rows.size():
		var key := StringName(rows[index][0])
		var has_slider := _page == &"sounds" or (_page == &"music" and index == 1)
		if id == key: return _slider_rect(index).get_center() if has_slider else _row_rect(index).get_center()
		if has_slider and id == StringName(String(key) + "_min"): return _slider_rect(index).position + Vector2(0, 3)
		if has_slider and id == StringName(String(key) + "_max"): return _slider_rect(index).end - Vector2(0, 3)
	return Vector2(-1, -1)

func navigate(action: StringName) -> void:
	if action == &"back":
		cancel_interaction()
		if _history.is_empty(): close_requested.emit()
		else:
			_page = _history.pop_back()
			var restored: Dictionary = _focus_memory.get(_page, {})
			_focus_region = restored.get("region", &"content")
			_focused_softkey = restored.get("softkey", &"home")
			_refresh_content()
			page_changed.emit(_page)
	elif action in [&"home", &"soft_left"]:
		_activate_softkey(&"home")
	elif action == &"confirm":
		if _focus_region == &"footer": _activate_softkey(_focused_softkey)
		else: _activate_selection()
	elif action in [&"up", &"down", &"left", &"right"]:
		if _focus_region == &"footer":
			if action == &"left": _focused_softkey = &"home"
			elif action == &"right": _focused_softkey = &"back"
			elif action == &"up":
				_focus_region = &"content"
				if _page == &"home": _selections[_page] = 2 if _focused_softkey == &"home" else 3
				elif _page != &"chat": _selections[_page] = maxi(0, (3 if _page == &"shop" else _rows().size()) - 1)
		elif _page == &"home":
			var old := get_selected_index()
			var col := old % 2
			var row := old / 2
			if action == &"left": col = maxi(0, col - 1)
			if action == &"right": col = mini(1, col + 1)
			if action == &"up": row = maxi(0, row - 1)
			if action == &"down":
				if row == 1: _enter_footer(&"home" if col == 0 else &"back")
				else: row = 1
			_selections[_page] = row * 2 + col
		elif _page == &"chat":
			if action == &"up": _scroll.scroll_vertical -= 28
			elif action == &"down":
				if _can_scroll_down(): _scroll.scroll_vertical += 28
				else: _enter_footer(&"home")
		elif action in [&"up", &"down"]:
			var count := 3 if _page == &"shop" else _rows().size()
			if action == &"down" and (count == 0 or get_selected_index() >= count - 1):
				if _page == &"shop" and _can_scroll_down(): _scroll.scroll_vertical += 28
				else: _enter_footer(&"home")
			else:
				_selections[_page] = clampi(get_selected_index() + (-1 if action == &"up" else 1), 0, maxi(count - 1, 0))
				if _page == &"shop" and _cards.get_child_count() > get_selected_index(): _scroll.ensure_control_visible(_cards.get_child(get_selected_index()))
		else: _adjust_selection(-1 if action == &"left" else 1)
	_refresh_card_selection()
	queue_redraw()

func _enter_footer(action: StringName) -> void:
	_focus_region = &"footer"
	_focused_softkey = action

func _can_scroll_down() -> bool:
	if not is_instance_valid(_scroll) or not _scroll.visible: return false
	var bar := _scroll.get_v_scroll_bar()
	return float(_scroll.scroll_vertical) < maxf(0.0, bar.max_value - bar.page) - 0.5

func _activate_softkey(action: StringName) -> void:
	if action == &"back": navigate(&"back")
	elif _page == &"home": _push_page(&"settings")
	elif _page == &"chat": _scroll.scroll_vertical += 28
	else: _activate_selection()

func _push_page(page: StringName) -> void:
	_focus_memory[_page] = {"region": _focus_region, "softkey": _focused_softkey}
	_history.append(_page)
	_page = page
	_focus_region = &"content"
	_focused_softkey = &"home"
	_note = ""
	if page == &"chat": apps_model.open_messages()
	_refresh_content()
	page_changed.emit(page)
	queue_redraw()

func _activate_selection() -> void:
	if _page == &"home": _push_page(HOME_APPS[get_selected_index()])
	elif _page == &"shop":
		_note = "" if apps_model.purchase(get_selected_index()) else "请回卧室购买"
		_refresh_content()
	elif _page == &"music" and get_selected_index() == 0: apps_model.toggle_music(get_tree())
	elif _page in [&"graphics",&"assistance"]:
		var key := StringName(_rows()[get_selected_index()][0])
		if key == &"shadow_quality": _adjust_selection(1)
		else: _manager.set_setting(key, not bool(_get_setting(key, true)))
	elif _page == &"settings": _push_page(StringName(_rows()[get_selected_index()][0]))

func _get_setting(key: StringName, fallback: Variant) -> Variant:
	return _manager.get_setting(key, fallback) if is_instance_valid(_manager) else fallback

func _adjust_selection(direction: int) -> void:
	if not is_instance_valid(_manager): return
	var rows := _rows()
	if rows.is_empty(): return
	var key := StringName(rows[get_selected_index()][0])
	if _page == &"sounds" or (_page == &"music" and key == &"music_volume"):
		_manager.set_volume(key, clampi(int(_get_setting(key, 100)) + direction * 5, 0, 100))
	elif _page in [&"graphics",&"assistance"]:
		if key == &"shadow_quality":
			var current := maxi(0, QUALITIES.find(String(_get_setting(key, "standard"))))
			_manager.set_setting(key, QUALITIES[clampi(current + direction, 0, 2)])
		else: _manager.set_setting(key, direction > 0)

func _set_slider_from_point(index: int, point: Vector2) -> void:
	var rect := _slider_rect(index)
	_manager.set_volume(StringName(_rows()[index][0]), clampf((point.x - rect.position.x) / rect.size.x, 0, 1) * 100)

func _on_setting_changed(_key: StringName, _value: Variant) -> void:
	_saved = true
	queue_redraw()

func _on_profile_changed() -> void:
	profile_changed.emit()
	_refresh_content()
	queue_redraw()

func _new_label(text: String, colour: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _refresh_content() -> void:
	if not is_instance_valid(_cards): return
	var saved_scroll := _scroll.scroll_vertical
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_scroll.visible = _page in [&"chat", &"shop"]
	if _page == &"chat":
		var messages := apps_model.get_messages()
		if messages.is_empty(): _cards.add_child(_new_label("暂无讯息"))
		for index in messages.size():
			var message: Dictionary = messages[index]
			var card := _new_card(index)
			var body: VBoxContainer = card.get_child(0)
			var days_ago := int(apps_model.profile.get("calendar_day_id", 0)) - int(message.get("received_day_id", 0))
			body.add_child(_new_label(apps_model.get_message_category(message) + (" · 今天" if days_ago <= 0 else " · %d天前" % days_ago), MUTED))
			body.add_child(_new_label(apps_model.get_message_text(message), MUTED if days_ago > 0 or bool(apps_model.profile.get("day5_northern_times_deleted", false)) and str(message.get("id", "")) == "day5_northern_times" else INK))
	elif _page == &"shop":
		var products := apps_model.get_products()
		for index in products.size():
			var product: Dictionary = products[index]
			var card := _new_card(index)
			var body: VBoxContainer = card.get_child(0)
			body.add_child(_new_label(product.title + "  " + str(product.price)))
			body.add_child(_new_label(product.description, MUTED))
			body.add_child(_new_label(product.status, MUTED))
			body.add_child(_new_label("购买" if apps_model.can_purchase() else "回卧室购买"))
	_scroll.set_deferred("scroll_vertical", saved_scroll)
	_refresh_card_selection()

func _new_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 128
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	_cards.add_child(card)
	card.gui_input.connect(_card_input.bind(index))
	return card

func _refresh_card_selection() -> void:
	if not is_instance_valid(_cards): return
	for index in _cards.get_child_count():
		var card := _cards.get_child(index) as PanelContainer
		if card == null: continue
		var style := StyleBoxFlat.new()
		style.bg_color = HIGHLIGHT if _focus_region == &"content" and _page == &"shop" and index == get_selected_index() else Color("e3ebf0")
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)

func _card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared() > 0.001 and event.button_mask == 0:
		_focus_region = &"content"
		_selections[_page] = index
		if _page == &"chat":
			var messages := apps_model.get_messages()
			if index < messages.size(): apps_model.hover_message(messages[index])
		_refresh_card_selection()
	queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_focus_region = &"content"
			_card_press = index
			_selections[_page] = index
			_pointer_down = true
			_set_locked(true)
			_press_feedback(&"confirm")
		else:
			var activate: bool = _card_press == index and not bool(_scroll.should_suppress_click())
			cancel_interaction()
			if activate and _page == &"shop": _activate_selection()
		_refresh_card_selection()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not _drag_setting.is_empty():
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_set_slider_from_point(get_selected_index(), event.position)
				if absf(event.relative.x) > 0.01: _press_feedback(&"right" if event.relative.x > 0 else &"left")
			else: cancel_interaction()
			accept_event()
		elif event.relative.length_squared() > 0.001 and event.button_mask == 0:
			if event.position.y >= SCREEN_SIZE.y - FOOTER_HEIGHT:
				_enter_footer(&"home" if event.position.x < 74 else &"back")
			elif _page == &"home":
				for index in 4:
					if _app_rect(index).has_point(event.position):
						_focus_region = &"content"
						_selections[_page] = index
			else:
				for index in _rows().size():
					if _row_rect(index).has_point(event.position):
						_focus_region = &"content"
						_selections[_page] = index
			_refresh_card_selection()
			queue_redraw()
		return
	if event is InputEventPanGesture:
		_scroll_lock_until = Time.get_ticks_msec() + 150
		_set_locked(true)
		return
	if not event is InputEventMouseButton: return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_lock_until = Time.get_ticks_msec() + 150
		_set_locked(true)
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	accept_event()
	if not event.pressed:
		cancel_interaction()
		return
	_pointer_down = true
	_set_locked(true)
	if event.position.y >= SCREEN_SIZE.y - FOOTER_HEIGHT:
		var action: StringName = &"home" if event.position.x < 74 else &"back"
		_enter_footer(action)
		_press_feedback(action)
		navigate(action)
		return
	if _page == &"home":
		for index in 4:
			if _app_rect(index).has_point(event.position):
				_focus_region = &"content"
				_selections[_page] = index
				_press_feedback(&"confirm")
				_activate_selection()
				return
	for index in _rows().size():
		if not _row_rect(index).has_point(event.position): continue
		_focus_region = &"content"
		_selections[_page] = index
		var slider := _page == &"sounds" or (_page == &"music" and index == 1)
		if slider:
			if _slider_rect(index).grow(3).has_point(event.position):
				_drag_setting = StringName(_rows()[index][0])
				_press_feedback(&"right" if event.position.x > _slider_rect(index).get_center().x else &"left")
				_set_slider_from_point(index, event.position)
		else:
			_press_feedback(&"confirm")
			_activate_selection()
		queue_redraw()
		return

func _process(delta: float) -> void:
	if _locked and not _pointer_down and Time.get_ticks_msec() > _scroll_lock_until: _set_locked(false)
	_poll_left -= delta
	if _poll_left <= 0:
		_poll_left = 0.3
		var signature := hash([apps_model.profile.get("balance"), apps_model.profile.get("delivery_state"), apps_model.profile.get("melatonin_inventory"), apps_model.profile.get("cheap_meal_purchases_today"), apps_model.profile.get("sunshade_purchased")])
		if signature != _content_signature and not _locked:
			_content_signature = signature
			if _page == &"shop": _refresh_content()
		queue_redraw()

func _text(position: Vector2, value: String, colour: Color = INK, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(FONT, position, value, alignment, width, 12, colour)

func _draw_home_icon(rect: Rect2, index: int) -> void:
	var p := rect.position + Vector2(20, 10)
	var c := Color("527b98")
	match index:
		0:
			draw_rect(Rect2(p, Vector2(25, 18)), c, false, 2)
			draw_line(p + Vector2(4, 18), p + Vector2(4, 23), c, 2)
			draw_line(p + Vector2(4, 23), p + Vector2(11, 18), c, 2)
			for y in [6, 11]: draw_line(p + Vector2(5, y), p + Vector2(20, y), c, 1)
		1:
			draw_polyline(PackedVector2Array([p + Vector2(4, 1), p + Vector2(0, 6), p + Vector2(5, 15), p + Vector2(16, 23), p + Vector2(23, 18), p + Vector2(16, 12), p + Vector2(12, 15), p + Vector2(7, 8), p + Vector2(10, 5), p + Vector2(4, 1)]), c, 3)
		2:
			draw_line(p + Vector2(9, 20), p + Vector2(9, 3), c, 2)
			draw_line(p + Vector2(22, 17), p + Vector2(22, 0), c, 2)
			draw_line(p + Vector2(9, 3), p + Vector2(22, 0), c, 3)
			draw_rect(Rect2(p + Vector2(3, 18), Vector2(7, 5)), c)
			draw_rect(Rect2(p + Vector2(16, 15), Vector2(7, 5)), c)
		3:
			draw_rect(Rect2(p + Vector2(2, 7), Vector2(23, 18)), c, false, 2)
			draw_polyline(PackedVector2Array([p + Vector2(7, 7), p + Vector2(7, 1), p + Vector2(19, 1), p + Vector2(19, 7)]), c, 2)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("d6e3ec"))
	if _page == &"home":
		draw_colored_polygon(PackedVector2Array([Vector2(0, 64), Vector2(148, 118), Vector2(148, 184), Vector2(0, 130)]), Color("c2d5e3"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 165), Vector2(148, 108), Vector2(148, 148), Vector2(0, 206)]), Color("e5edf2"))
	var titles := {&"home": "手机", &"settings": "设置", &"sounds": "声音", &"graphics": "画面", &"assistance": "游戏辅助功能", &"chat": "讯息", &"call": "电话", &"music": "音乐", &"shop": "购物"}
	_text(Vector2(6, 18), String(titles.get(_page, "手机")))
	var status: Dictionary = apps_model.get_status()
	_text(Vector2(87, 18), str(status.time), MUTED, 43, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(134, 8, 10, 7), MUTED, false, 1)
	draw_rect(Rect2(136, 10, clampf(float(status.battery), 0, 1) * 6, 3), MUTED)
	draw_line(Vector2(5, 26), Vector2(143, 26), Color("b0c6d6"), 1)
	if _page == &"home":
		for index in 4:
			var rect := _app_rect(index)
			if _focus_region == &"content" and get_selected_index() == index:
				draw_rect(rect, HIGHLIGHT)
				draw_rect(rect.grow(-0.5), Color("7b9fb7"), false, 1)
			_draw_home_icon(rect, index)
			_text(rect.position + Vector2(17, 52), ["讯息", "电话", "音乐", "购物"][index])
			if index == 0 and apps_model.get_unread_count() > 0: _text(rect.position + Vector2(45, 13), str(apps_model.get_unread_count()), Color("a24b44"))
	elif _page == &"call":
		_text(Vector2(17, 84), "暂无通话")
		_text(Vector2(17, 108), "电话尚未开放", MUTED)
	elif _page == &"music":
		var info: Dictionary = apps_model.get_music_info(get_tree())
		_text(Vector2(10, 54), str(info.title), INK, 128)
		_text(Vector2(10, 70), "当前背景音乐", MUTED)
	for index in _rows().size():
		var row := _row_rect(index)
		var key := StringName(_rows()[index][0])
		if _focus_region == &"content" and get_selected_index() == index: draw_rect(row, HIGHLIGHT)
		_text(row.position + Vector2(8, 16), String(_rows()[index][1]))
		if _page == &"sounds" or (_page == &"music" and index == 1):
			var percent := clampi(int(_get_setting(key, 100)), 0, 100)
			_text(row.position + Vector2(89, 16), str(percent), MUTED, 40, HORIZONTAL_ALIGNMENT_RIGHT)
			var slider := _slider_rect(index)
			draw_rect(slider, Color("aec3d2"))
			draw_rect(Rect2(slider.position, Vector2(slider.size.x * percent / 100.0, slider.size.y)), Color("5b89a8"))
			draw_rect(Rect2(slider.position + Vector2(roundf(slider.size.x * percent / 100.0) - 1, -2), Vector2(3, 11)), INK)
		elif _page in [&"graphics",&"assistance"]:
			var value: String = QUALITY_LABELS[maxi(0, QUALITIES.find(String(_get_setting(key, "standard"))))] if key == &"shadow_quality" else "开" if bool(_get_setting(key, true)) else "关"
			_text(row.position + Vector2(86, 16), value, MUTED, 43, HORIZONTAL_ALIGNMENT_RIGHT)
		elif _page == &"music" and index == 0:
			var info: Dictionary = apps_model.get_music_info(get_tree())
			_text(row.position + Vector2(8, 34), "暂停" if not bool(info.paused) else "播放", MUTED)
	if _page == &"shop": _text(Vector2(5, 205), _note if not _note.is_empty() else apps_model.get_balance_text(), MUTED, 138)
	elif _saved and _page in [&"settings", &"sounds", &"graphics", &"assistance"]: _text(Vector2(101, 205), "已保存", MUTED)
	draw_rect(Rect2(0, 209, 148, 21), Color("b9cfde"))
	if _focus_region == &"footer":
		var selected_footer := get_softkey_rect(_focused_softkey)
		draw_rect(selected_footer, HIGHLIGHT)
		draw_rect(selected_footer.grow(-0.5), Color("527b98"), false, 1)
	var left := "设置" if _page == &"home" else "购买" if _page == &"shop" and apps_model.can_purchase() else "只读" if _page == &"shop" else "翻阅" if _page == &"chat" else "选择"
	_text(Vector2(8, 224), left)
	_text(Vector2(112, 224), "返回")
