extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")
const GLITCH_SHADER := preload("res://shaders/glitch_overlay.gdshader")
# 手机时间区域背景壁纸：只在锁屏/主页时间块内 cover 裁剪绘制，不超出手机屏幕区。

enum PhoneState { COLLAPSED, EXPANDING, EXPANDED, COLLAPSING }
enum ScreenState { LOCKED, HOME, ONLINE, QUICKLINK, SETTINGS }

signal balance_changed
signal state_changed

const FINGERPRINT_AREA := Rect2(54, 220, 52, 52)
const BACK_BUTTON := Rect2(14, 40, 48, 22)
# Phone.png（160×336）的屏幕可显示区（手机局部坐标，逐像素实测屏幕暗区）：
# 顶栏/图标/消息等一切内容不得超出它；底部内容不再被手机外壳遮住。
const SCREEN_RECT := Rect2(6, 20, 148, 305)
# 收起判定基于手机背景层：纵向覆盖整个手机背景（最顶到最底），
# 但只响应“背景空白处”点击——内容层（APP 图标/顶栏/滚动列表/滑杆等）
# 优先响应，点内容绝不收起。APP 顶栏色带（返回按钮所在行）。
const APP_TOP_BAR := Rect2(6, 32, 148, 44)
# APP 内容安全区：顶部在顶栏下方，底边停在屏幕实际底边上方一小段。
const APP_CONTENT_TOP := 76.0
const APP_CONTENT_BOTTOM_MARGIN := 4.0
# 滚动列表末尾的底部 padding，保证最后一条内容能完整滚到可见区域。
const ONLINE_BOTTOM_PADDING := 12.0
const SETTINGS_MASTER_SLIDER := Rect2(16, 92, 128, 22)
const SETTINGS_MUSIC_SLIDER := Rect2(16, 137, 128, 22)
const SETTINGS_SFX_SLIDER := Rect2(16, 182, 128, 22)
const SETTINGS_SLEEPWALK := Rect2(16, 222, 128, 26)
const SETTINGS_FAST_SLEEP := Rect2(16, 254, 128, 26)
const APP_IDS := ["online", "quicklink", "settings"]
const APP_NAMES := [
	["在线！™", "ONLINE!™"],
	["速联跑腿™", "QUICKLINK™"],
	["设置", "SETTINGS"]
]
const APP_ICONS := [
	preload("res://assets/ui/icons/online_icon.png"),
	preload("res://assets/ui/icons/delivery_icon.png"),
	preload("res://assets/ui/icons/settings_icon.png")
]

@export var config: DemoConfig

var state := PhoneState.COLLAPSED
var screen_state := ScreenState.LOCKED
var interaction_locked := false
var fingerprint_progress := 0.0
var messages: Array = []
var quicklink_items: Array = []
var persistent_state: Dictionary = {}
var purchase_locked := false
var _shake_tween: Tween
# 新消息震动提示专用 tween（与 glitch 屏幕震动 _shake_tween 互不影响）。
var _vibrate_tween: Tween
var balance_flash_left := 0.0
var last_battery_ratio := -1.0
var bedroom_time_minutes := 1260.0
var movement_tween: Tween
var hovered_app_index := -1
var hovered_phone_action := ""
var phone_option_triangle_elapsed := 0.0
# 手机静止基准位置：所有震动坐标都基于它计算，不基于当前 position 累计加减，
# 保证震动结束后准确恢复原位，不会越震越偏。
var phone_rest_position := Vector2.ZERO
var page_drag_candidate := false
var page_drag_active := false
var page_drag_start_y := 0.0
var page_drag_last_y := 0.0
@onready var screen_clip: Control = $ScreenClip
@onready var app_grid: GridContainer = $ScreenClip/AppGrid
@onready var online_scroll: PhoneDragScroll = $ScreenClip/OnlineScroll
@onready var content_safe_margin: MarginContainer = $ScreenClip/OnlineScroll/ContentSafeMargin
@onready var message_list: VBoxContainer = $ScreenClip/OnlineScroll/ContentSafeMargin/MessageList
@onready var quicklink_scroll: PhoneDragScroll = $ScreenClip/QuicklinkScroll
@onready var quicklink_content: Control = $ScreenClip/QuicklinkScroll/QuicklinkContent
@onready var settings_scrollbar: VScrollBar = $ScreenClip/SettingsScrollBar


func _ready() -> void:
	size = Vector2(config.phone_panel_width, config.phone_panel_height)
	position = Vector2(config.phone_position_x, config.phone_collapsed_y)
	var content_margin := config.phone_app_content_margin
	# APP 可视区严格处于手机真实屏幕内部：顶部在顶栏下方，
	# 底边停在屏幕实际底边上方，滚动到底不会被手机外壳挡住。
	var app_content_height := SCREEN_RECT.end.y - APP_CONTENT_BOTTOM_MARGIN - APP_CONTENT_TOP
	var slim_scrollbar_width := config.online_scrollbar_width * 0.5
	# 滚动列表是 ScreenClip 的子节点，坐标需换算到裁剪容器局部空间。
	online_scroll.position = Vector2(content_margin, APP_CONTENT_TOP) - screen_clip.position
	online_scroll.size = Vector2(size.x - content_margin * 2.0, app_content_height)
	content_safe_margin.add_theme_constant_override("margin_right", int(config.online_message_right_safe_margin))
	message_list.custom_minimum_size.x = online_scroll.size.x - config.online_scrollbar_width - config.online_message_right_safe_margin
	online_scroll.drag_threshold = config.phone_scroll_drag_threshold
	online_scroll.get_v_scroll_bar().custom_minimum_size.x = slim_scrollbar_width
	# 速联跑腿™复用与在线！™完全相同的拖动滚动组件、阈值与像素滚动条。
	var quicklink_horizontal_margin := 8.0
	quicklink_scroll.position = Vector2(quicklink_horizontal_margin, APP_CONTENT_TOP) - screen_clip.position
	quicklink_scroll.size = Vector2(size.x - quicklink_horizontal_margin * 2.0, app_content_height)
	quicklink_scroll.drag_threshold = config.phone_scroll_drag_threshold
	quicklink_scroll.get_v_scroll_bar().custom_minimum_size.x = slim_scrollbar_width
	# 商品内容宽度预留滚动条 + 右侧安全边距，避免被滚动条遮挡。
	quicklink_content.custom_minimum_size.x = quicklink_scroll.size.x - slim_scrollbar_width - config.online_message_right_safe_margin
	quicklink_content.custom_minimum_size.y = 313.0
	quicklink_content.phone = self
	settings_scrollbar.position = Vector2(SCREEN_RECT.end.x - slim_scrollbar_width, APP_CONTENT_TOP) - screen_clip.position
	settings_scrollbar.size = Vector2(slim_scrollbar_width, app_content_height)
	settings_scrollbar.custom_minimum_size.x = slim_scrollbar_width
	settings_scrollbar.value_changed.connect(_on_phone_page_scrolled)
	settings_scrollbar.max_value = 286.0
	settings_scrollbar.page = app_content_height
	screen_state = ScreenState.LOCKED if config.phone_lock_on_bedroom_entry else ScreenState.HOME
	phone_rest_position = Vector2(config.phone_position_x, config.phone_collapsed_y)
	messages = _load_array("res://resources/phone_messages.json", "messages")
	quicklink_items = _load_array("res://resources/quicklink_items.json", "items")
	mouse_exited.connect(_clear_app_hover)
	SettingsManager.setting_changed.connect(_on_setting_changed)
	if not persistent_state.is_empty():
		configure_state(persistent_state)
	_sync_content_visibility()
	queue_redraw()


func configure_state(meta: Dictionary) -> void:
	persistent_state = meta
	if not persistent_state.has("online_messages"):
		var message_templates := messages if not messages.is_empty() else _load_array("res://resources/phone_messages.json", "messages")
		persistent_state.online_messages = message_templates.duplicate(true)
	_merge_online_templates()
	_migrate_online_message_schema()
	messages = persistent_state.online_messages
	if not persistent_state.has("cheap_meal_purchased_today"):
		persistent_state.cheap_meal_purchased_today = false
	if not persistent_state.has("cheap_meal_purchases_today"):
		persistent_state.cheap_meal_purchases_today = 1 if bool(persistent_state.cheap_meal_purchased_today) else 0
	if not persistent_state.has("delivery_state"):
		persistent_state.delivery_state = "NONE"
	if not persistent_state.has("delivery_seconds_remaining"):
		persistent_state.delivery_seconds_remaining = 0.0
	_build_online_messages()
	_notify_unread_batch_once()
	queue_redraw()


func set_bedroom_time(total_minutes: float) -> void:
	bedroom_time_minutes = total_minutes
	if screen_state == ScreenState.LOCKED or screen_state == ScreenState.HOME:
		queue_redraw()


func _process(delta: float) -> void:
	if not hovered_phone_action.is_empty():
		phone_option_triangle_elapsed += delta
		queue_redraw()
	var battery_ratio := _get_battery_ratio()
	if not is_equal_approx(battery_ratio, last_battery_ratio):
		last_battery_ratio = battery_ratio
		queue_redraw()
	if balance_flash_left > 0.0:
		balance_flash_left = maxf(0.0, balance_flash_left - delta)
		queue_redraw()
		if is_instance_valid(quicklink_content):
			quicklink_content.queue_redraw()


func _clear_app_hover() -> void:
	hovered_app_index = -1
	hovered_phone_action = ""
	phone_option_triangle_elapsed = 0.0
	queue_redraw()


func force_collapse() -> void:
	if movement_tween != null and movement_tween.is_valid():
		movement_tween.kill()
	position.y = config.phone_collapsed_y
	state = PhoneState.COLLAPSED
	interaction_locked = false


func blocks_bedroom_interaction() -> bool:
	return state != PhoneState.COLLAPSED


func is_fully_collapsed() -> bool:
	return state == PhoneState.COLLAPSED and is_equal_approx(position.y, config.phone_collapsed_y)


func open_quicklink_from_bedroom() -> void:
	if interaction_locked:
		return
	screen_state = ScreenState.QUICKLINK
	_sync_content_visibility()
	queue_redraw()
	if state == PhoneState.COLLAPSED:
		_animate_phone(true)


func _gui_input(event: InputEvent) -> void:
	if state == PhoneState.EXPANDED and screen_state == ScreenState.SETTINGS:
		var page_scrollbar := settings_scrollbar
		var content_rect := Rect2(6, APP_CONTENT_TOP, 148, SCREEN_RECT.end.y - APP_CONTENT_BOTTOM_MARGIN - APP_CONTENT_TOP)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and content_rect.has_point(event.position):
			if event.pressed:
				# Slider、开关和升级按钮仍走原点击逻辑；只有正文空白区启动拖动滚动。
				if not _phone_action_at(event.position).is_empty():
					page_drag_candidate = false
				else:
					page_drag_candidate = true
					page_drag_active = false
					page_drag_start_y = event.position.y
					page_drag_last_y = event.position.y
				if not page_drag_candidate:
					# 不消费正式控件的按下事件。
					pass
				else:
					accept_event()
					return
			else:
				if page_drag_candidate and not page_drag_active:
					_activate_scrolled_page_point(event.position)
				page_drag_candidate = false
				page_drag_active = false
				accept_event()
				return
		if event is InputEventMouseMotion and page_drag_candidate and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not page_drag_active and absf(event.position.y - page_drag_start_y) >= config.phone_scroll_drag_threshold:
				page_drag_active = true
			if page_drag_active:
				page_scrollbar.value += page_drag_last_y - event.position.y
				page_drag_last_y = event.position.y
				accept_event()
				return
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			page_scrollbar.value += -18.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 18.0
			accept_event()
			return
		if event is InputEventPanGesture:
			page_scrollbar.value += event.delta.y * 28.0
			accept_event()
			return
	if event is InputEventMouseMotion:
		if state == PhoneState.EXPANDED and screen_state == ScreenState.SETTINGS and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_phone_setting(event.position)
			accept_event()
			return
		var next_hovered := -1
		if state == PhoneState.EXPANDED and screen_state == ScreenState.HOME and not interaction_locked:
			for index in APP_IDS.size():
				if _app_rect(index).has_point(event.position):
					next_hovered = index
					break
		var next_action := _phone_action_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if next_hovered >= 0 or not next_action.is_empty() else Control.CURSOR_ARROW
		if not next_action.is_empty() and next_action != hovered_phone_action:
			SFX.play_event(&"ui_hover")
		if next_action != hovered_phone_action:
			hovered_phone_action = next_action
			phone_option_triangle_elapsed = 0.0
			queue_redraw()
		if next_hovered != hovered_app_index:
			hovered_app_index = next_hovered
			queue_redraw()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	accept_event()
	if interaction_locked:
		return
	if state == PhoneState.COLLAPSED:
		_animate_phone(true)
		return
	if state != PhoneState.EXPANDED:
		return
	# 点击手机背景空白处收回手机：判定纵向覆盖整个手机背景，
	# 但内容层（图标/顶栏/列表/滑杆）优先，点内容不会误收起；
	# 收起时非主页先返回主界面。
	if _phone_action_at(event.position) == "collapse":
		SFX.play_event(&"phone_operation")
		if screen_state != ScreenState.HOME:
			screen_state = ScreenState.HOME
			_sync_content_visibility()
		_animate_phone(false)
		return
	match screen_state:
		ScreenState.LOCKED:
			if FINGERPRINT_AREA.has_point(event.position):
				_unlock_with_fingerprint()
		ScreenState.HOME:
			for index in APP_IDS.size():
				if _app_rect(index).has_point(event.position):
					SFX.play_event(&"phone_operation")
					_open_app(APP_IDS[index])
					break
		ScreenState.ONLINE, ScreenState.QUICKLINK, ScreenState.SETTINGS:
			if BACK_BUTTON.has_point(event.position):
				SFX.play_event(&"phone_operation")
				screen_state = ScreenState.HOME
				_sync_content_visibility()
				queue_redraw()
			elif screen_state == ScreenState.SETTINGS:
				SFX.play_event(&"phone_operation")
				_update_phone_setting(event.position)


func _open_app(id: String) -> void:
	match id:
		"online":
			screen_state = ScreenState.ONLINE
			_mark_online_messages_read()
		"quicklink": screen_state = ScreenState.QUICKLINK
		"settings": screen_state = ScreenState.SETTINGS
	_sync_content_visibility()
	queue_redraw()


func _sync_content_visibility() -> void:
	if not is_node_ready():
		return
	app_grid.visible = screen_state == ScreenState.HOME
	online_scroll.visible = screen_state == ScreenState.ONLINE
	quicklink_scroll.visible = screen_state == ScreenState.QUICKLINK
	settings_scrollbar.visible = screen_state == ScreenState.SETTINGS
	if quicklink_scroll.visible:
		quicklink_content.queue_redraw()


func _has_unread_online_messages() -> bool:
	for message in messages:
		if message is Dictionary and not bool(message.get("is_read", false)):
			return true
	return false


func _mark_online_messages_read() -> void:
	var changed := false
	for message in messages:
		if message is Dictionary:
			if str(message.get("id", "")) == "day5_northern_times" and not bool(message.get("is_read", false)):
				continue
			changed = changed or not bool(message.get("is_read", false))
			message.is_read = true
			if str(message.get("id", "")) == "quicklink_news_debt_1993":
				persistent_state.quicklink_news_read = true
	if not persistent_state.is_empty():
		persistent_state.online_messages = messages
	_build_online_messages()
	if changed:
		state_changed.emit()


func _notify_unread_batch_once() -> void:
	var unread_batch: Array = []
	for message in messages:
		if message is Dictionary and not bool(message.get("is_read", false)):
			unread_batch.append({"category": message.get("category", ""), "text": message.get("text", "")})
	if unread_batch.is_empty():
		return
	var signature := JSON.stringify(unread_batch)
	if str(persistent_state.get("online_notified_batch_signature", "")) == signature:
		return
	# 签名去重保证：每天新消息首次到达时只提示一次（震动+提示音），
	# 反复打开/关闭手机或重新进入卧室不会重复震动；玩家读完后批次为空也不再提示。
	persistent_state.online_notified_batch_signature = signature
	SFX.play_event(&"new_message")
	_play_new_message_vibrate()
	state_changed.emit()


## 新消息震动提示：快速短促的“嗡嗡”感——每轮 左→右→左→右→中，
## 每步约 config.phone_vibration_step_duration 秒，两轮之间停顿
## config.phone_vibration_pause_duration 秒；总振幅仅
## config.phone_vibration_offset_px 个像素，结束后精确归位。
## 只动 position.x，展开动画只动 position.y；展开/收起不重复触发（签名去重）。
func _play_new_message_vibrate() -> void:
	if _vibrate_tween != null and _vibrate_tween.is_valid():
		_vibrate_tween.kill()
	SFX.play_event(&"phone_buzz")
	var home_x := phone_rest_position.x
	var amplitude := config.phone_vibration_offset_px
	var step := maxf(config.phone_vibration_step_duration, 0.01)
	var rounds := maxi(1, int(config.phone_vibration_rounds))
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	for round in rounds:
		tween.tween_property(self, "position:x", home_x - amplitude, step)
		tween.tween_property(self, "position:x", home_x + amplitude, step)
		tween.tween_property(self, "position:x", home_x - amplitude, step)
		tween.tween_property(self, "position:x", home_x + amplitude, step)
		tween.tween_property(self, "position:x", home_x, step)
		if round < rounds - 1:
			tween.tween_interval(maxf(config.phone_vibration_pause_duration, 0.0))
	_vibrate_tween = tween


func _build_online_messages() -> void:
	if not is_node_ready():
		return
	content_safe_margin.add_theme_constant_override("margin_right", int(config.online_message_right_safe_margin))
	messages.sort_custom(_is_message_newer)
	persistent_state.online_messages = messages
	for child in message_list.get_children():
		message_list.remove_child(child)
		child.queue_free()
	message_list.add_theme_constant_override("separation", int(config.online_message_spacing))
	var content_width := maxf(64.0, online_scroll.size.x - config.online_scrollbar_width - config.online_message_right_safe_margin)
	message_list.custom_minimum_size.x = content_width
	for message in messages:
		if not message is Dictionary:
			continue
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = content_width
		card.add_theme_constant_override("separation", 4)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.gui_input.connect(_on_message_card_input.bind(message))
		card.mouse_entered.connect(_on_message_card_hovered.bind(message))
		var header := HBoxContainer.new()
		header.custom_minimum_size.x = content_width
		var deleted := str(message.get("id", "")) == "day5_northern_times" and bool(persistent_state.get("day5_northern_times_deleted", false))
		# 非当前游戏日收到的消息整体显示为清晰的中灰色（发送者/日期/正文），
		# 已删除消息继续保持现有删除态样式，优先级高于历史灰。
		var history_gray := not deleted and int(message.get("received_day_id", 0)) < int(persistent_state.get("calendar_day_id", 0))
		var category := Label.new()
		# 被删除的北方时报消息：作者名（分类）改为"匿名"。
		category.text = "匿名" if deleted else str(message.get("category", "消息"))
		category.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category.add_theme_font_size_override("font_size", 9 if not deleted else 7)
		category.modulate = Color("686f78") if deleted else (Color("6e7980") if history_gray else Color("8da0a5"))
		var date := Label.new()
		date.text = _relative_day_label(int(message.get("received_day_id", 0)))
		date.add_theme_font_size_override("font_size", 7)
		date.custom_minimum_size.x = 30.0
		date.modulate = Color("5d646c") if history_gray else Color("686f78")
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(category)
		header.add_child(date)
		var body := Label.new()
		body.text = "该信息已被创作者删除" if deleted else str(message.get("text", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = content_width
		body.add_theme_font_size_override("font_size", 7 if deleted else 9)
		body.modulate = Color("686f78") if deleted else (Color("7e828a") if history_gray else Color("b2afb5"))
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		category.mouse_filter = Control.MOUSE_FILTER_IGNORE
		date.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header)
		card.add_child(body)
		message_list.add_child(card)
		var separator := HSeparator.new()
		separator.modulate = Color(0.4, 0.4, 0.45, 0.4)
		message_list.add_child(separator)
	var ending := Label.new()
	ending.text = "这里是宇宙尽头"
	ending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending.add_theme_font_size_override("font_size", 8)
	ending.modulate = Color("5f626c")
	message_list.add_child(ending)
	# 底部 padding：让最后一条消息能完整滚出屏幕底部遮挡区。
	var bottom_padding := Control.new()
	bottom_padding.custom_minimum_size.y = ONLINE_BOTTOM_PADDING
	bottom_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_list.add_child(bottom_padding)
	call_deferred("_scroll_online_to_top")


func _is_message_newer(a: Variant, b: Variant) -> bool:
	if not a is Dictionary:
		return false
	if not b is Dictionary:
		return true
	var a_day := int(a.get("received_day_id", 0))
	var b_day := int(b.get("received_day_id", 0))
	if a_day != b_day:
		return a_day > b_day
	return int(a.get("message_sequence", 0)) > int(b.get("message_sequence", 0))


func _relative_day_label(received_day_id: int) -> String:
	var days_ago := int(persistent_state.get("calendar_day_id", 0)) - received_day_id
	return "今天" if days_ago <= 0 else "%d天前" % days_ago


func _on_message_card_input(event: InputEvent, message: Dictionary) -> void:
	# 消息删除由悬停触发（_on_message_card_hovered），点击不再处理删除。
	pass


## 播放一次全屏 glitch 效果（<1 秒），覆盖整个游戏画面后自动消失，
## 同时触发短暂的屏幕震动。
func _play_screen_glitch(duration: float = 0.4) -> void:
	var layer := get_parent()  # PhoneLayer（CanvasLayer）
	if layer == null:
		return
	var overlay := ColorRect.new()
	overlay.name = "ScreenGlitch"
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = GLITCH_SHADER
	overlay.material = material
	overlay.modulate.a = 0.0
	layer.add_child(overlay)
	# 最后添加 → 绘制在 PhoneLayer 最上层，覆盖整个屏幕。
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.08)
	tween.tween_interval(maxf(0.0, duration - 0.16))
	tween.tween_property(overlay, "modulate:a", 0.0, 0.08)
	tween.tween_callback(overlay.queue_free)
	# 屏幕震动：抖动卧室根节点，让整个画面随故障一起震动。
	if layer is CanvasLayer:
		var bedroom_root := layer.get_parent() as Node2D
		if bedroom_root != null:
			_apply_screen_shake(bedroom_root, duration)


## 对目标节点做短暂随机位移抖动（屏幕震动），结束后归位。
func _apply_screen_shake(target: Node2D, duration: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var home_position := target.position
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var steps := maxi(6, int(duration / 0.035))
	var step_seconds := duration / float(steps)
	for _step in steps:
		var offset := Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
		tween.tween_property(target, "position", home_position + offset, step_seconds)
	tween.tween_property(target, "position", home_position, step_seconds * 1.5)
	_shake_tween = tween


## 鼠标悬停到北方时报消息时触发删除：消息变成灰色小字
## "该信息已被创作者删除"，作者名（分类）改为"匿名"，并播放全屏 glitch 效果。
func _on_message_card_hovered(message: Dictionary) -> void:
	if str(message.get("id", "")) != "day5_northern_times":
		return
	if bool(persistent_state.get("day5_northern_times_deleted", false)):
		return
	message.is_read = true
	persistent_state.day5_northern_times_deleted = true
	persistent_state.online_messages = messages
	_build_online_messages()
	state_changed.emit()
	_play_screen_glitch()


func _scroll_online_to_top() -> void:
	if is_instance_valid(online_scroll):
		online_scroll.scroll_vertical = 0


func _app_rect(index: int) -> Rect2:
	var grid := get_node_or_null("ScreenClip/AppGrid") as GridContainer
	if grid != null and index >= 0 and index < grid.get_child_count():
		var cell := grid.get_child(index) as Control
		if cell != null and cell.size.x > 0.0:
			# 图标命中矩形换算回手机局部坐标（绘制与点击共用同一坐标）。
			return Rect2(screen_clip.position + grid.position + cell.position, cell.size)
	var column := index % 2
	var row := index / 2
	return Rect2(screen_clip.position + Vector2(8.0 + column * 68.0, 139.0 + row * 56.0), Vector2(64, 53))


## 当前页面可点击收回手机的区域：仅手机整体高度的顶部 1/3（最新规则覆盖
## “全背景可收”），且仅背景空白处生效；内容层由 _is_content_point 优先拦截，
## 因此点击 APP 图标（包括 ONLINE）或 APP 内容不会再误触发收起。


## 当前页面的内容层命中：APP 图标、锁屏指纹、APP 顶栏与内容视口等。
## 这些区域优先响应交互，点击它们绝不触发收起。
func _is_content_point(point: Vector2) -> bool:
	match screen_state:
		ScreenState.HOME:
			for index in APP_IDS.size():
				if _app_rect(index).has_point(point):
					return true
		ScreenState.LOCKED:
			return FINGERPRINT_AREA.has_point(point)
		_:
			if APP_TOP_BAR.has_point(point):
				return true
			var content_rect := Rect2(6, APP_CONTENT_TOP, 148, SCREEN_RECT.end.y - APP_CONTENT_BOTTOM_MARGIN - APP_CONTENT_TOP)
			return content_rect.has_point(point)
	return false


func _phone_action_at(point: Vector2) -> String:
	if state != PhoneState.EXPANDED or interaction_locked:
		return ""
	if screen_state == ScreenState.HOME:
		for index in APP_IDS.size():
			if _app_rect(index).has_point(point):
				return "app_" + APP_IDS[index]
	elif screen_state == ScreenState.LOCKED:
		if FINGERPRINT_AREA.has_point(point):
			return "fingerprint"
	else:
		if BACK_BUTTON.has_point(point):
			return "back"
	if screen_state == ScreenState.SETTINGS:
		var content_point := point + Vector2(0, settings_scrollbar.value)
		if SETTINGS_MASTER_SLIDER.has_point(content_point): return "settings_master"
		if SETTINGS_MUSIC_SLIDER.has_point(content_point): return "settings_music"
		if SETTINGS_SFX_SLIDER.has_point(content_point): return "settings_sfx"
		if SETTINGS_SLEEPWALK.has_point(content_point): return "settings_sleepwalk"
		if SETTINGS_FAST_SLEEP.has_point(content_point): return "settings_fast_sleep"
	# 内容层优先：点到内容返回空动作；只有点到手机顶部 1/3 的背景空白处
	# 才返回 collapse，下方 2/3 完全不触发收起。
	if _is_content_point(point):
		return ""
	if _retract_area_rect().has_point(point):
		return "collapse"
	return ""


## 收起触发区 = 手机整体高度的顶部 1/3（phone_height * ratio，不是上半部再取 1/3）。
func _retract_area_rect() -> Rect2:
	return Rect2(0, 0, size.x, size.y * config.phone_retract_height_ratio)


func _update_phone_setting(point: Vector2) -> void:
	point.y += settings_scrollbar.value
	if SETTINGS_MASTER_SLIDER.has_point(point):
		SettingsManager.set_volume(&"master_volume", _slider_percent(SETTINGS_MASTER_SLIDER, point.x))
	elif SETTINGS_MUSIC_SLIDER.has_point(point):
		SettingsManager.set_volume(&"music_volume", _slider_percent(SETTINGS_MUSIC_SLIDER, point.x))
	elif SETTINGS_SFX_SLIDER.has_point(point):
		SettingsManager.set_volume(&"sfx_volume", _slider_percent(SETTINGS_SFX_SLIDER, point.x))
	elif SETTINGS_SLEEPWALK.has_point(point):
		SettingsManager.set_sleepwalk_mode(not SettingsManager.get_sleepwalk_mode())
	elif SETTINGS_FAST_SLEEP.has_point(point):
		SettingsManager.set_fast_sleep_enabled(not SettingsManager.get_fast_sleep_enabled())


func _activate_scrolled_page_point(point: Vector2) -> void:
	if screen_state == ScreenState.SETTINGS:
		SFX.play_event(&"phone_operation")
		_update_phone_setting(point)


func _slider_percent(rect: Rect2, mouse_x: float) -> float:
	return clampf((mouse_x - rect.position.x) / maxf(rect.size.x, 1.0) * 100.0, 0.0, 100.0)


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	if screen_state == ScreenState.SETTINGS:
		queue_redraw()


func _on_phone_page_scrolled(_value: float) -> void:
	queue_redraw()


func _animate_phone(expand: bool) -> void:
	if state == PhoneState.EXPANDING or state == PhoneState.COLLAPSING:
		return
	state = PhoneState.EXPANDING if expand else PhoneState.COLLAPSING
	interaction_locked = true
	var target_y := config.phone_expanded_y if expand else config.phone_collapsed_y
	movement_tween = create_tween()
	movement_tween.tween_property(self, "position:y", target_y, config.phone_animation_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await movement_tween.finished
	state = PhoneState.EXPANDED if expand else PhoneState.COLLAPSED
	interaction_locked = false
	state_changed.emit()


func _unlock_with_fingerprint() -> void:
	interaction_locked = true
	fingerprint_progress = 0.0
	var tween := create_tween()
	tween.tween_method(_set_fingerprint_progress, 0.0, 1.0, config.phone_fingerprint_animation_seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished
	SFX.play_event(&"phone_unlock")
	screen_state = ScreenState.HOME
	_sync_content_visibility()
	interaction_locked = false
	queue_redraw()


func _set_fingerprint_progress(value: float) -> void:
	fingerprint_progress = value
	queue_redraw()


func _load_array(path: String, key: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.has(key) and parsed[key] is Array:
		return parsed[key]
	return []


func _merge_online_templates() -> void:
	var existing: Array = persistent_state.get("online_messages", [])
	var templates := _load_array("res://resources/phone_messages.json", "messages")
	for message in existing:
		if not message is Dictionary:
			continue
		if str(message.get("category", "")) == "生活": message.category = "妈妈"
		elif str(message.get("category", "")) == "工作": message.category = "项目组长-速联科技控股"
	var known_ids: Dictionary = {}
	for message in existing:
		if not message is Dictionary:
			continue
		for template in templates:
			if template is Dictionary and str(message.get("text", "")) == str(template.get("text", "")):
				message.id = str(template.get("id", ""))
				message.category = str(template.get("category", message.get("category", "消息")))
				break
		if not str(message.get("id", "")).is_empty():
			known_ids[str(message.id)] = true
	for template in templates:
		if template is Dictionary and not known_ids.has(str(template.get("id", ""))):
			existing.append(template.duplicate(true))
	persistent_state.online_messages = existing


func _migrate_online_message_schema() -> void:
	var existing: Array = persistent_state.get("online_messages", [])
	var current_day_id := int(persistent_state.get("calendar_day_id", 0))
	var next_sequence := maxi(1, int(persistent_state.get("online_message_sequence_next", 1)))
	for index in existing.size():
		var message: Variant = existing[index]
		if not message is Dictionary:
			continue
		if not message.has("received_day_id"):
			message.received_day_id = maxi(0, current_day_id - (existing.size() - 1 - index))
		if not message.has("message_sequence") or int(message.get("message_sequence", 0)) <= 0:
			message.message_sequence = next_sequence
			next_sequence += 1
		else:
			next_sequence = maxi(next_sequence, int(message.message_sequence) + 1)
		if not message.has("is_read"):
			message.is_read = false
	persistent_state.online_message_sequence_next = next_sequence
	persistent_state.online_messages = existing


func _purchase_melatonin() -> void:
	if purchase_locked:
		return
	purchase_locked = true
	var balance := int(persistent_state.get("balance", 0))
	var inventory := int(persistent_state.get("melatonin_inventory", 0))
	if balance >= config.melatonin_price and inventory < config.melatonin_inventory_cap:
		STATE_RULES.change_balance(persistent_state, -config.melatonin_price)
		persistent_state.melatonin_inventory = inventory + 1
		persistent_state.melatonin_ever_purchased = true
		persistent_state.melatonin_bottle_present = true
		SFX.play_event(&"purchase")
		_flash_balance()
	else:
		SFX.play_event(&"forbidden")
	purchase_locked = false
	queue_redraw()


func _purchase_cheap_meal() -> void:
	if purchase_locked:
		return
	purchase_locked = true
	var balance := int(persistent_state.get("balance", 0))
	var purchase_count := int(persistent_state.get("cheap_meal_purchases_today", 0))
	var at_daily_limit := purchase_count >= config.cheap_meal_daily_purchase_limit
	if not at_daily_limit and balance >= config.cheap_meal_price:
		STATE_RULES.change_balance(persistent_state, -config.cheap_meal_price)
		persistent_state.cheap_meal_purchased_today = true
		persistent_state.cheap_meal_purchases_today = purchase_count + 1
		persistent_state.delivery_state = "DELIVERING"
		persistent_state.delivery_seconds_remaining = config.cheap_meal_delivery_seconds
		SFX.play_event(&"purchase")
		_flash_balance()
		state_changed.emit()
	else:
		SFX.play_event(&"forbidden")
	purchase_locked = false
	queue_redraw()


func _purchase_sunshade() -> void:
	if purchase_locked:
		return
	purchase_locked = true
	if bool(persistent_state.get("sunshade_purchased", false)):
		SFX.play_event(&"forbidden")
		purchase_locked = false
		queue_redraw()
		return
	var balance := int(persistent_state.get("balance", 0))
	if balance >= config.sunshade_price:
		STATE_RULES.change_balance(persistent_state, -config.sunshade_price)
		persistent_state.sunshade_purchased = true
		# Newly arrived: default to deployed. The bedroom renders it on the window.
		if not persistent_state.has("sunshade_visible"):
			persistent_state.sunshade_visible = true
		SFX.play_event(&"purchase")
		_flash_balance()
		state_changed.emit()
		# 购买只刷新当前商品状态；手机、APP和滚动位置保持不变。
		quicklink_content.queue_redraw()
	else:
		SFX.play_event(&"forbidden")
	purchase_locked = false
	queue_redraw()


func _flash_balance() -> void:
	balance_flash_left = 0.45
	balance_changed.emit()


func _draw() -> void:
	# Phone.png is drawn by the input-ignoring PhoneShell child behind this runtime content.
	# 屏幕内的全部内容改由 ScreenClip 画布绘制并严格裁剪在手机屏幕区内，
	# 手机本体只绘制屏幕外底部下巴（屏幕底边 325 以下）的 home 指示条。
	draw_line(Vector2(size.x * 0.5 - 18, size.y - 6), Vector2(size.x * 0.5 + 18, size.y - 6), Color("6f7179"), 3.0)


## 由 ScreenClip 委托绘制：所有屏幕内容画到 canvas 上，坐标仍为手机局部坐标
## （ScreenClip 已用 draw_set_transform 平移补偿），并被裁剪在屏幕可显示区内。
func _draw_screen(canvas: CanvasItem) -> void:
	var font := PixelFont.get_font()
	# 收起交互区视觉完全隐藏：不画任何 hover 高亮/边框/色块，
	# 交互判定（_phone_action_at / _retract_area_rect）保持不变。
	match screen_state:
		ScreenState.LOCKED: _draw_lock_screen(canvas, font)
		ScreenState.HOME: _draw_home_screen(canvas, font)
		ScreenState.ONLINE: _draw_online(canvas, font)
		ScreenState.QUICKLINK: _draw_quicklink_header(canvas, font)
		ScreenState.SETTINGS: _draw_settings(canvas, font)


# 速联跑腿™ 只在此绘制共用的顶部返回按钮与标题；商品列表由
# QuicklinkScroll/QuicklinkContent 自绘（支持滚动）。
func _draw_quicklink_header(canvas: CanvasItem, font: Font) -> void:
	PhoneShopUI.draw_app_header(canvas, SCREEN_RECT, BACK_BUTTON, get_local_mouse_position(), "速联跑腿™", "QUICKLINK™", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size, phone_option_triangle_elapsed)


func _draw_lock_screen(canvas: CanvasItem, font: Font) -> void:
	canvas.draw_rect(_lock_time_rect(), Color("102437"))
	canvas.draw_string(font, Vector2(0, 76), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color("b2b3bb"))
	canvas.draw_string(font, Vector2(0, 102), _weekday_name(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("696c76"))
	var pulse := 0.25 + fingerprint_progress * 0.65
	canvas.draw_circle(FINGERPRINT_AREA.get_center(), 22.0, Color(0.35, 0.45, 0.5, pulse), false, 3.0)
	canvas.draw_circle(FINGERPRINT_AREA.get_center(), 13.0, Color(0.5, 0.62, 0.68, pulse), false, 2.0)


func _weekday_name() -> String:
	return ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"][int(persistent_state.get("weekday_index", 0)) % 7]


func _lock_time_rect() -> Rect2:
	return Rect2(12, 40, size.x - 24, 78)


func _home_time_rect() -> Rect2:
	# 紧凑的像素时间卡：与顶部状态栏分离，并为2×2图标保留稳定留白。
	return Rect2(12, 47, size.x - 24, 82)


func _draw_home_screen(canvas: CanvasItem, font: Font) -> void:
	# 深冷蓝桌面底色 + 像素分段，不使用现代渐变或圆角控件。
	canvas.draw_rect(SCREEN_RECT, Color("09131e"))
	canvas.draw_rect(Rect2(SCREEN_RECT.position, Vector2(SCREEN_RECT.size.x, 84)), Color("102437"))
	canvas.draw_rect(Rect2(SCREEN_RECT.position + Vector2(0, 84), Vector2(SCREEN_RECT.size.x, 96)), Color("0d1d2c"))
	canvas.draw_rect(Rect2(SCREEN_RECT.position + Vector2(0, 180), Vector2(SCREEN_RECT.size.x, SCREEN_RECT.size.y - 180)), Color("0a1622"))
	_draw_home_status_bar(canvas, font)
	var widget_rect := _home_time_rect()
	_draw_pixel_panel(canvas, widget_rect, Color("142b3d"), Color("416d88"), Color("07101a"))
	canvas.draw_string(font, Vector2(0, 77), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("d8eef4"))
	canvas.draw_string(font, Vector2(0, 101), _weekday_name(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("8eb6c8"))
	for index in APP_IDS.size():
		var rect := _app_rect(index)
		_draw_app_icon(canvas, rect, APP_NAMES[index][0], APP_NAMES[index][1], index, font, hovered_app_index == index)
		if index == 0 and _has_unread_online_messages():
			var icon_top_right := rect.position + Vector2(45.0, 2.0)
			var dot_center := icon_top_right + config.online_unread_dot_offset
			canvas.draw_circle(dot_center, config.online_unread_dot_size, Color("d84b56"))
	_draw_home_navigation(canvas)


func _draw_home_status_bar(canvas: CanvasItem, font: Font) -> void:
	var bar := Rect2(9, 24, 142, 17)
	canvas.draw_rect(bar, Color("0a1825"))
	canvas.draw_line(bar.position + Vector2(0, bar.size.y - 1), bar.end, Color("294a60"), 1.0)
	canvas.draw_string(font, Vector2(13, 35), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_LEFT, 45, 7, Color("9ec3d1"))
	# 右侧用硬边像素信号格和电池，不引入额外功能或点击区域。
	for bar_index in range(3):
		canvas.draw_rect(Rect2(112 + bar_index * 4, 34 - bar_index * 2, 2, 2 + bar_index * 2), Color("7faabd"))
	canvas.draw_rect(Rect2(128, 28, 17, 8), Color("7faabd"), false, 1.0)
	canvas.draw_rect(Rect2(145, 30, 2, 4), Color("7faabd"))
	var fill_width := roundi(11.0 * _get_battery_ratio())
	if fill_width > 0:
		canvas.draw_rect(Rect2(130, 30, fill_width, 4), Color("477b98"))


func _get_battery_ratio() -> float:
	var stress := clampf(float(persistent_state.get("stress_value", config.stress_default)), 0.0, float(config.stress_max))
	return 1.0 - clampf(stress / maxf(float(config.stress_max), 1.0), 0.0, 1.0)


func _draw_home_navigation(canvas: CanvasItem) -> void:
	var nav := Rect2(24, 296, 112, 21)
	_draw_pixel_panel(canvas, nav, Color("0e2130"), Color("315b78"), Color("050d16"))
	# 返回、主页、任务三个轻量像素符号；当前只作为视觉导航，不改变原交互。
	canvas.draw_line(Vector2(43, 307), Vector2(49, 302), Color("749caf"), 2.0)
	canvas.draw_line(Vector2(43, 307), Vector2(49, 312), Color("749caf"), 2.0)
	canvas.draw_rect(Rect2(76, 302, 8, 10), Color("c7e1ea"), false, 2.0)
	canvas.draw_rect(Rect2(110, 303, 9, 9), Color("749caf"), false, 1.0)


func _draw_pixel_panel(canvas: CanvasItem, rect: Rect2, fill: Color, highlight: Color, shadow: Color) -> void:
	canvas.draw_rect(rect, shadow)
	canvas.draw_rect(rect.grow(-2), fill)
	canvas.draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(rect.size.x - 3, 2), highlight, 1.0)
	canvas.draw_line(rect.position + Vector2(2, rect.size.y - 3), rect.position + Vector2(rect.size.x - 3, rect.size.y - 3), shadow, 1.0)


func _draw_app_icon(canvas: CanvasItem, rect: Rect2, chinese: String, english: String, index: int, font: Font, hovered: bool) -> void:
	var brightness := config.phone_app_hover_brightness if hovered else 0.0
	var icon_modulate := Color.WHITE.lightened(brightness)
	var panel := Rect2(rect.position + Vector2(7, -3), Vector2(rect.size.x - 14, 36))
	_draw_pixel_panel(
		canvas,
		panel,
		Color("183248") if hovered else Color("102638"),
		Color("5a8ca6") if hovered else Color("315b78"),
		Color("050d16")
	)
	var icon_position := rect.position + Vector2(16, -1 if hovered else 0)
	canvas.draw_texture(APP_ICONS[index], icon_position, icon_modulate)
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 39), chinese, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color("d3e7ed").lightened(brightness))
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 49), english, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 6, Color("7899a9").lightened(brightness))


func _draw_online(canvas: CanvasItem, font: Font) -> void:
	PhoneShopUI.draw_app_header(canvas, SCREEN_RECT, BACK_BUTTON, get_local_mouse_position(), "在线！™", "ONLINE!™", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size, phone_option_triangle_elapsed)


func _draw_settings(canvas: CanvasItem, font: Font) -> void:
	canvas.draw_set_transform(-screen_clip.position + Vector2(0, -settings_scrollbar.value))
	_draw_phone_slider(canvas, font, "总音量", &"master_volume", SETTINGS_MASTER_SLIDER)
	_draw_phone_slider(canvas, font, "音乐", &"music_volume", SETTINGS_MUSIC_SLIDER)
	_draw_phone_slider(canvas, font, "音效", &"sfx_volume", SETTINGS_SFX_SLIDER)
	var enabled := SettingsManager.get_sleepwalk_mode()
	# 开关项：16bit 像素斜面底 + 方块指示灯，命中矩形不变。
	var sleepwalk_hovered := hovered_phone_action == "settings_sleepwalk"
	canvas.draw_rect(SETTINGS_SLEEPWALK, Color("000000") if enabled and sleepwalk_hovered else (Color("1b2b3d") if enabled else Color("151d27")))
	canvas.draw_line(SETTINGS_SLEEPWALK.position, SETTINGS_SLEEPWALK.position + Vector2(SETTINGS_SLEEPWALK.size.x, 0), Color("3e627a") if enabled else Color("26323d"), 1.0)
	canvas.draw_line(SETTINGS_SLEEPWALK.position + Vector2(0, SETTINGS_SLEEPWALK.size.y - 1), SETTINGS_SLEEPWALK.end, Color("0a0e15"), 1.0)
	canvas.draw_rect(Rect2(SETTINGS_SLEEPWALK.position + Vector2(5, 7), Vector2(12, 12)), Color("4fb3c9") if enabled else Color("252933"))
	canvas.draw_rect(Rect2(SETTINGS_SLEEPWALK.position + Vector2(5, 7), Vector2(12, 12)), Color("8fd0de") if enabled else Color("38424c"), false, 1.0)
	canvas.draw_string(font, SETTINGS_SLEEPWALK.position + Vector2(23, 17), "梦游模式  %s" % ("ON" if enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 98, 9, Color("cfe0e7") if enabled else Color("8fa0a9"))


	var fast_sleep_enabled := SettingsManager.get_fast_sleep_enabled()
	var fast_sleep_hovered := hovered_phone_action == "settings_fast_sleep"
	canvas.draw_rect(SETTINGS_FAST_SLEEP, Color("000000") if fast_sleep_enabled and fast_sleep_hovered else (Color("1b2b3d") if fast_sleep_enabled else Color("151d27")))
	canvas.draw_line(SETTINGS_FAST_SLEEP.position, SETTINGS_FAST_SLEEP.position + Vector2(SETTINGS_FAST_SLEEP.size.x, 0), Color("3e627a") if fast_sleep_enabled else Color("26323d"), 1.0)
	canvas.draw_line(SETTINGS_FAST_SLEEP.position + Vector2(0, SETTINGS_FAST_SLEEP.size.y - 1), SETTINGS_FAST_SLEEP.end, Color("0a0e15"), 1.0)
	canvas.draw_rect(Rect2(SETTINGS_FAST_SLEEP.position + Vector2(5, 7), Vector2(12, 12)), Color("4fb3c9") if fast_sleep_enabled else Color("252933"))
	canvas.draw_rect(Rect2(SETTINGS_FAST_SLEEP.position + Vector2(5, 7), Vector2(12, 12)), Color("8fd0de") if fast_sleep_enabled else Color("38424c"), false, 1.0)
	canvas.draw_string(font, SETTINGS_FAST_SLEEP.position + Vector2(23, 17), "快速睡觉  %s" % ("ON" if fast_sleep_enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 98, 9, Color("cfe0e7") if fast_sleep_enabled else Color("8fa0a9"))
	canvas.draw_set_transform(-screen_clip.position)
	PhoneShopUI.draw_app_header(canvas, SCREEN_RECT, BACK_BUTTON, get_local_mouse_position(), "设置", "SETTINGS", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size, phone_option_triangle_elapsed)


func _draw_phone_slider(canvas: CanvasItem, font: Font, label_text: String, setting_name: StringName, rect: Rect2) -> void:
	var value := SettingsManager.get_volume(setting_name)
	canvas.draw_string(font, rect.position + Vector2(0, -3), "%s  %d%%" % [label_text, value], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 8, Color("aeb9bf"))
	# 分段音量条：16bit 风格青蓝填充段 + 硬边框凹槽。
	var bar := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 8))
	canvas.draw_rect(bar, Color("0c141d"))
	var segment_width := bar.size.x / 10.0
	for segment in range(10):
		var segment_rect := Rect2(bar.position + Vector2(segment * segment_width + 1.0, 1.0), Vector2(maxf(segment_width - 2.0, 2.0), 6.0))
		canvas.draw_rect(segment_rect, Color("4fb3c9") if value >= (segment + 1) * 10 else Color("1d2733"))
	canvas.draw_rect(bar, Color("3e627a"), false, 1.0)
