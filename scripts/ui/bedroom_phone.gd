extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")
const GLITCH_SHADER := preload("res://shaders/glitch_overlay.gdshader")
# 手机时间区域背景壁纸：只在锁屏/主页时间块内 cover 裁剪绘制，不超出手机屏幕区。
const PHONE_WALLPAPER: Texture2D = preload("res://art/wallpaper/phone_background.png")

enum PhoneState { COLLAPSED, EXPANDING, EXPANDED, COLLAPSING }
enum ScreenState { LOCKED, HOME, ONLINE, SOMNIA, QUICKLINK, SETTINGS }

signal balance_changed
signal permanent_upgrade_changed
signal state_changed

const FINGERPRINT_AREA := Rect2(54, 220, 52, 52)
const BACK_BUTTON := Rect2(14, 40, 48, 22)
const SETTINGS_MASTER_SLIDER := Rect2(16, 92, 128, 22)
const SETTINGS_MUSIC_SLIDER := Rect2(16, 137, 128, 22)
const SETTINGS_SFX_SLIDER := Rect2(16, 182, 128, 22)
const SETTINGS_SLEEPWALK := Rect2(16, 222, 128, 26)
const SETTINGS_FAST_SLEEP := Rect2(16, 254, 128, 26)
const APP_IDS := ["online", "somnia", "quicklink", "settings"]
const APP_NAMES := [
	["在线！™", "ONLINE!™"],
	["眠网™", "SOMNIA NET™"],
	["速联跑腿™", "QUICKLINK™"],
	["设置", "SETTINGS"]
]
const APP_ICONS := [
	preload("res://assets/ui/icons/online_icon.png"),
	preload("res://assets/ui/icons/somnia_icon.png"),
	preload("res://assets/ui/icons/delivery_icon.png"),
	preload("res://assets/ui/icons/settings_icon.png")
]
const UPGRADE_IDS := ["visual_cortex", "brainstem", "hippocampus", "prefrontal"]
const UPGRADE_NAMES := ["枕叶视觉皮层", "脑干", "海马体", "前额叶皮层"]
const PRODUCT_ICONS := {
	"melatonin": preload("res://assets/ui/products/melatonin_icon.png"),
	"cheap_meal": preload("res://assets/ui/products/cheap_meal_icon.png"),
	"sunshade": preload("res://art/Badroom/sunshade.png"),
	"visual_cortex": preload("res://assets/ui/products/visual_cortex_icon.png"),
	"brainstem": preload("res://assets/ui/products/brainstem_icon.png"),
	"hippocampus": preload("res://assets/ui/products/hippocampus_icon.png"),
	"prefrontal": preload("res://assets/ui/products/prefrontal_icon.png")
}

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
var bedroom_time_minutes := 1260.0
var movement_tween: Tween
var hovered_app_index := -1
var hovered_phone_action := ""
# 手机静止基准位置：所有震动坐标都基于它计算，不基于当前 position 累计加减，
# 保证震动结束后准确恢复原位，不会越震越偏。
var phone_rest_position := Vector2.ZERO
var lock_background_texture: AtlasTexture
var home_background_texture: AtlasTexture
@onready var app_grid: GridContainer = $AppGrid
@onready var online_scroll: PhoneDragScroll = $OnlineScroll
@onready var content_safe_margin: MarginContainer = $OnlineScroll/ContentSafeMargin
@onready var message_list: VBoxContainer = $OnlineScroll/ContentSafeMargin/MessageList
@onready var quicklink_scroll: PhoneDragScroll = $QuicklinkScroll
@onready var quicklink_content: Control = $QuicklinkScroll/QuicklinkContent


func _ready() -> void:
	size = Vector2(config.phone_panel_width, config.phone_panel_height)
	position = Vector2(config.phone_position_x, config.phone_collapsed_y)
	var content_margin := config.phone_app_content_margin
	online_scroll.position = Vector2(content_margin, 76.0)
	online_scroll.size = Vector2(size.x - content_margin * 2.0, size.y - 100.0)
	content_safe_margin.add_theme_constant_override("margin_right", int(config.online_message_right_safe_margin))
	message_list.custom_minimum_size.x = online_scroll.size.x - config.online_scrollbar_width - config.online_message_right_safe_margin
	online_scroll.drag_threshold = config.phone_scroll_drag_threshold
	online_scroll.get_v_scroll_bar().custom_minimum_size.x = config.online_scrollbar_width
	# 速联跑腿™复用与在线！™完全相同的拖动滚动组件、阈值与像素滚动条。
	quicklink_scroll.position = Vector2(content_margin, 76.0)
	quicklink_scroll.size = Vector2(size.x - content_margin * 2.0, size.y - 100.0)
	quicklink_scroll.drag_threshold = config.phone_scroll_drag_threshold
	quicklink_scroll.get_v_scroll_bar().custom_minimum_size.x = config.online_scrollbar_width
	# 商品内容宽度预留滚动条 + 右侧安全边距，避免被滚动条遮挡。
	quicklink_content.custom_minimum_size.x = quicklink_scroll.size.x - config.online_scrollbar_width - config.online_message_right_safe_margin
	quicklink_content.phone = self
	screen_state = ScreenState.LOCKED if config.phone_lock_on_bedroom_entry else ScreenState.HOME
	lock_background_texture = _build_time_background(_lock_time_rect())
	home_background_texture = _build_time_background(_home_time_rect())
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
	if not persistent_state.has("permanent_upgrades"):
		persistent_state.permanent_upgrades = {}
	for id in UPGRADE_IDS:
		if not persistent_state.permanent_upgrades.has(id):
			persistent_state.permanent_upgrades[id] = 0
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
	if balance_flash_left > 0.0:
		balance_flash_left = maxf(0.0, balance_flash_left - delta)
		queue_redraw()
		if is_instance_valid(quicklink_content):
			quicklink_content.queue_redraw()


func _clear_app_hover() -> void:
	hovered_app_index = -1
	hovered_phone_action = ""
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
		if not next_action.is_empty() and next_action != hovered_phone_action:
			SFX.play_event(&"ui_hover")
		if next_action != hovered_phone_action:
			hovered_phone_action = next_action
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
	# 点击手机上部区域向下收回：HOME/LOCKED 使用原有较大区域；
	# 其他 APP 页使用返回按钮上方的细条（不遮挡返回按钮），收回时返回主界面。
	if _collapse_area_for_state().has_point(event.position):
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
		ScreenState.ONLINE, ScreenState.SOMNIA, ScreenState.QUICKLINK, ScreenState.SETTINGS:
			if BACK_BUTTON.has_point(event.position):
				SFX.play_event(&"phone_operation")
				screen_state = ScreenState.HOME
				_sync_content_visibility()
				queue_redraw()
			elif screen_state == ScreenState.SOMNIA:
				for index in UPGRADE_IDS.size():
					if _upgrade_buy_rect(index).has_point(event.position):
						_purchase_permanent_upgrade(UPGRADE_IDS[index])
						break
			elif screen_state == ScreenState.SETTINGS:
				SFX.play_event(&"phone_operation")
				_update_phone_setting(event.position)


func _open_app(id: String) -> void:
	match id:
		"online":
			screen_state = ScreenState.ONLINE
			_mark_online_messages_read()
		"somnia": screen_state = ScreenState.SOMNIA
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
	if quicklink_scroll.visible:
		quicklink_scroll.scroll_vertical = 0
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
		var category := Label.new()
		# 被删除的北方时报消息：作者名（分类）改为"匿名"。
		category.text = "匿名" if deleted else str(message.get("category", "消息"))
		category.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category.add_theme_font_size_override("font_size", 9 if not deleted else 7)
		category.modulate = Color("8da0a5") if not deleted else Color("686f78")
		var date := Label.new()
		date.text = _relative_day_label(int(message.get("received_day_id", 0)))
		date.add_theme_font_size_override("font_size", 7)
		date.custom_minimum_size.x = 30.0
		date.modulate = Color("686f78")
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(category)
		header.add_child(date)
		var body := Label.new()
		body.text = "该信息已被创作者删除" if deleted else str(message.get("text", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = content_width
		body.add_theme_font_size_override("font_size", 7 if deleted else 9)
		body.modulate = Color("686f78") if deleted else Color("b2afb5")
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
	var grid := get_node_or_null("AppGrid") as GridContainer
	if grid != null and index >= 0 and index < grid.get_child_count():
		var cell := grid.get_child(index) as Control
		if cell != null and cell.size.x > 0.0:
			return Rect2(grid.position + cell.position, cell.size)
	var column := index % 2
	var row := index / 2
	return Rect2(14 + column * 67, 170 + row * 56, 64, 53)


func _upper_collapse_area() -> Rect2:
	return Rect2(0, 0, size.x, config.phone_upper_collapse_height)


## 当前页面可点击收回手机的区域。HOME/LOCKED 使用配置的较大区域；
## 其他 APP 页限定在返回按钮上方，避免遮挡返回按钮。
func _collapse_area_for_state() -> Rect2:
	if screen_state == ScreenState.HOME or screen_state == ScreenState.LOCKED:
		return _upper_collapse_area()
	return Rect2(0, 0, size.x, maxf(4.0, BACK_BUTTON.position.y - 4.0))


func _upgrade_buy_rect(index: int) -> Rect2:
	return Rect2(96, 84 + index * 47, 48, 16)


func _phone_action_at(point: Vector2) -> String:
	if state != PhoneState.EXPANDED or interaction_locked:
		return ""
	if screen_state == ScreenState.HOME:
		for index in APP_IDS.size():
			if _app_rect(index).has_point(point):
				return "app_" + APP_IDS[index]
		if _upper_collapse_area().has_point(point):
			return "collapse"
		return ""
	if BACK_BUTTON.has_point(point):
		return "back"
	if screen_state == ScreenState.SOMNIA:
		for index in UPGRADE_IDS.size():
			if _upgrade_buy_rect(index).has_point(point):
				return "upgrade_" + UPGRADE_IDS[index]
	if screen_state == ScreenState.SETTINGS:
		if SETTINGS_MASTER_SLIDER.has_point(point): return "settings_master"
		if SETTINGS_MUSIC_SLIDER.has_point(point): return "settings_music"
		if SETTINGS_SFX_SLIDER.has_point(point): return "settings_sfx"
		if SETTINGS_SLEEPWALK.has_point(point): return "settings_sleepwalk"
		if SETTINGS_FAST_SLEEP.has_point(point): return "settings_fast_sleep"
	return ""


func _update_phone_setting(point: Vector2) -> void:
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


func _slider_percent(rect: Rect2, mouse_x: float) -> float:
	return clampf((mouse_x - rect.position.x) / maxf(rect.size.x, 1.0) * 100.0, 0.0, 100.0)


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	if screen_state == ScreenState.SETTINGS:
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
		# 收起手机，让玩家立刻能点击卧室里的遮阳帘切换显示/隐藏。
		force_collapse()
	else:
		SFX.play_event(&"forbidden")
	purchase_locked = false
	queue_redraw()


func _purchase_permanent_upgrade(id: String) -> void:
	if purchase_locked:
		return
	purchase_locked = true
	var levels: Dictionary = persistent_state.get("permanent_upgrades", {})
	var level := int(levels.get(id, 0))
	if level < config.permanent_upgrade_max_level:
		var price := int(config.permanent_upgrade_prices[level])
		var ram := int(persistent_state.get("ram", 0))
		if ram >= price:
			persistent_state.ram = ram - price
			levels[id] = level + 1
			persistent_state.permanent_upgrades = levels
			balance_flash_left = 0.45
			SFX.play_event(&"purchase")
			permanent_upgrade_changed.emit()
		else:
			SFX.play_event(&"forbidden")
	else:
		SFX.play_event(&"forbidden")
	purchase_locked = false
	queue_redraw()


func _flash_balance() -> void:
	balance_flash_left = 0.45
	balance_changed.emit()


func _draw() -> void:
	# Phone.png is drawn by the input-ignoring PhoneShell child behind this runtime content.
	var font := PixelFont.get_font()
	match screen_state:
		ScreenState.LOCKED: _draw_lock_screen(font)
		ScreenState.HOME: _draw_home_screen(font)
		ScreenState.ONLINE: _draw_online(font)
		ScreenState.SOMNIA: _draw_somnia(font)
		ScreenState.QUICKLINK: _draw_quicklink_header(font)
		ScreenState.SETTINGS: _draw_settings(font)
	draw_line(Vector2(size.x * 0.5 - 18, size.y - 17), Vector2(size.x * 0.5 + 18, size.y - 17), Color("6f7179"), 3.0)


# 速联跑腿™ 只在此绘制共用的顶部返回按钮与标题；商品列表由
# QuicklinkScroll/QuicklinkContent 自绘（支持滚动）。
func _draw_quicklink_header(font: Font) -> void:
	PhoneShopUI.draw_app_header(self, BACK_BUTTON, "速联跑腿™", "QUICKLINK™", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size)


func _draw_lock_screen(font: Font) -> void:
	if lock_background_texture != null:
		var background_rect := _lock_time_rect()
		draw_texture_rect(lock_background_texture, background_rect, false)
		# 暗化薄层保证时间文字在壁纸上仍清晰可读。
		draw_rect(background_rect, Color(0.02, 0.05, 0.09, 0.3))
	draw_string(font, Vector2(0, 76), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color("b2b3bb"))
	draw_string(font, Vector2(0, 102), _weekday_name(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("696c76"))
	var pulse := 0.25 + fingerprint_progress * 0.65
	draw_circle(FINGERPRINT_AREA.get_center(), 22.0, Color(0.35, 0.45, 0.5, pulse), false, 3.0)
	draw_circle(FINGERPRINT_AREA.get_center(), 13.0, Color(0.5, 0.62, 0.68, pulse), false, 2.0)
	draw_string(font, Vector2(0, 233), "点击指纹解锁", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("71757e"))


func _weekday_name() -> String:
	return ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"][int(persistent_state.get("weekday_index", 0)) % 7]


func _lock_time_rect() -> Rect2:
	return Rect2(12, 40, size.x - 24, 78)


func _home_time_rect() -> Rect2:
	return Rect2(12, 36, size.x - 24, 112)


## 按目标矩形对壁纸做 cover 式居中裁剪，绘制时永远不超出该矩形。
func _build_time_background(target_rect: Rect2) -> AtlasTexture:
	var texture_size := PHONE_WALLPAPER.get_size()
	var crop := AtlasTexture.new()
	crop.atlas = PHONE_WALLPAPER
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		crop.region = Rect2(Vector2.ZERO, texture_size)
		return crop
	var cover_scale := maxf(target_rect.size.x / texture_size.x, target_rect.size.y / texture_size.y)
	var source_size := target_rect.size / maxf(cover_scale, 0.001)
	crop.region = Rect2((texture_size - source_size) * 0.5, source_size)
	return crop


func _draw_home_screen(font: Font) -> void:
	var widget_rect := _home_time_rect()
	draw_rect(widget_rect, Color("20232d"))
	if home_background_texture != null:
		draw_texture_rect(home_background_texture, widget_rect, false)
		draw_rect(widget_rect, Color(0.02, 0.05, 0.09, 0.28))
	draw_string(font, Vector2(0, 72), RunSettlement.format_time(bedroom_time_minutes), HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, Color("b2b3bb"))
	draw_string(font, Vector2(0, 94), _weekday_name(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color("6f7380"))
	for index in APP_IDS.size():
		var rect := _app_rect(index)
		_draw_app_icon(rect, APP_NAMES[index][0], APP_NAMES[index][1], index, font, hovered_app_index == index)
		if index == 0 and _has_unread_online_messages():
			var icon_top_right := rect.position + Vector2(45.0, 2.0)
			var dot_center := icon_top_right + config.online_unread_dot_offset
			draw_circle(dot_center, config.online_unread_dot_size, Color("d84b56"))


func _draw_app_icon(rect: Rect2, chinese: String, english: String, index: int, font: Font, hovered: bool) -> void:
	var brightness := config.phone_app_hover_brightness if hovered else 0.0
	var icon_modulate := Color.WHITE.lightened(brightness)
	draw_texture(APP_ICONS[index], rect.position + Vector2(16, -2), icon_modulate)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 38), chinese, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color("c0bdc4").lightened(brightness))
	draw_string(font, Vector2(rect.position.x, rect.position.y + 49), english, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 7, Color("858893").lightened(brightness))


func _draw_online(font: Font) -> void:
	PhoneShopUI.draw_app_header(self, BACK_BUTTON, "在线！™", "ONLINE!™", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size)


func _draw_somnia(font: Font) -> void:
	PhoneShopUI.draw_app_header(self, BACK_BUTTON, "眠网™", "SOMNIA NET™", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size)
	draw_string(font, Vector2(72, 78), "RAM %04d" % int(persistent_state.get("ram", 0)), HORIZONTAL_ALIGNMENT_RIGHT, 66, 10, Color("9fb5c1"))
	var levels: Dictionary = persistent_state.get("permanent_upgrades", {})
	for index in UPGRADE_IDS.size():
		var id: String = UPGRADE_IDS[index]
		var level := int(levels.get(id, 0))
		var y := 82.0 + index * 47.0
		var card := Rect2(10, y, 140, 45)
		draw_rect(card, Color("151b26"))
		draw_rect(card, Color("3f6075"), false, 1.0)
		draw_line(card.position + Vector2(4, 4), card.position + Vector2(14, 4), Color("7595aa"), 1.0)
		draw_texture_rect(PRODUCT_ICONS[id], Rect2(14, y + 8, 26, 26), false)
		draw_string(font, Vector2(44, y + 10), "%s  %d/%d" % [UPGRADE_NAMES[index], level, config.permanent_upgrade_max_level], HORIZONTAL_ALIGNMENT_LEFT, 92, 6, Color("c1cbd1"))
		var button := _upgrade_buy_rect(index)
		var capped := level >= config.permanent_upgrade_max_level
		var price := 0 if capped else int(config.permanent_upgrade_prices[level])
		var ram := int(persistent_state.get("ram", 0))
		var disabled := capped or ram < price
		var label := _somnia_button_label(level, ram)
		PhoneShopUI.draw_pixel_shop_button(self, button, label, disabled, hovered_phone_action == "upgrade_" + id, font)
		draw_string(font, Vector2(44, y + 21), "当前：%s" % _permanent_effect_value(id, level), HORIZONTAL_ALIGNMENT_LEFT, 96, 5, Color("8799a4"))
		draw_string(font, Vector2(44, y + 30), "下一级：%s" % ("--" if capped else _permanent_effect_value(id, level + 1)), HORIZONTAL_ALIGNMENT_LEFT, 96, 5, Color("8799a4"))
		draw_string(font, Vector2(44, y + 39), "需要：%s  持有：%d RAM" % ["--" if capped else "%d RAM" % price, ram], HORIZONTAL_ALIGNMENT_LEFT, 100, 5, Color("718894"))


func _permanent_effect_text(id: String, level: int) -> String:
	match id:
		"visual_cortex": return "范围 +%d → +%d px" % [int(level * config.visual_cortex_range_per_level), int(mini(level + 1, 5) * config.visual_cortex_range_per_level)]
		"brainstem": return "经验 ×%.1f → ×%.1f" % [1.0 + level * config.brainstem_experience_per_level, 1.0 + mini(level + 1, 5) * config.brainstem_experience_per_level]
		"hippocampus": return "生命 +%d → +%d" % [int(level * config.hippocampus_health_per_level), int(mini(level + 1, 5) * config.hippocampus_health_per_level)]
		_: return "攻速 ×%.1f → ×%.1f" % [1.0 + level * config.prefrontal_attack_speed_per_level, 1.0 + mini(level + 1, 5) * config.prefrontal_attack_speed_per_level]


func _permanent_effect_value(id: String, level: int) -> String:
	match id:
		"visual_cortex": return "范围 +%dpx" % int(level * config.visual_cortex_range_per_level)
		"brainstem": return "经验 ×%.1f" % (1.0 + level * config.brainstem_experience_per_level)
		"hippocampus": return "生命 +%d" % int(level * config.hippocampus_health_per_level)
		_: return "攻速 ×%.1f" % (1.0 + level * config.prefrontal_attack_speed_per_level)


func _somnia_button_label(level: int, ram: int) -> String:
	if level >= config.permanent_upgrade_max_level:
		return "已达到最高等级"
	var price := int(config.permanent_upgrade_prices[level])
	return "升级 %d RAM" % price if ram >= price else "RAM不足 需要%d" % price


func _draw_settings(font: Font) -> void:
	PhoneShopUI.draw_app_header(self, BACK_BUTTON, "设置", "SETTINGS", font, config.phone_app_chinese_title_font_size, config.phone_app_english_title_font_size)
	_draw_phone_slider(font, "总音量", &"master_volume", SETTINGS_MASTER_SLIDER)
	_draw_phone_slider(font, "音乐", &"music_volume", SETTINGS_MUSIC_SLIDER)
	_draw_phone_slider(font, "音效", &"sfx_volume", SETTINGS_SFX_SLIDER)
	var enabled := SettingsManager.get_sleepwalk_mode()
	draw_rect(SETTINGS_SLEEPWALK, Color("26303a"))
	draw_rect(SETTINGS_SLEEPWALK, Color("7894a5") if enabled else Color("46515d"), false, 2.0)
	draw_rect(Rect2(SETTINGS_SLEEPWALK.position + Vector2(5, 7), Vector2(12, 12)), Color("517b98") if enabled else Color("252933"))
	draw_string(font, SETTINGS_SLEEPWALK.position + Vector2(23, 17), "梦游模式  %s" % ("ON" if enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 98, 9, Color("bdc8cd"))


	var fast_sleep_enabled := SettingsManager.get_fast_sleep_enabled()
	draw_rect(SETTINGS_FAST_SLEEP, Color("26303a"))
	draw_rect(SETTINGS_FAST_SLEEP, Color("7894a5") if fast_sleep_enabled else Color("46515d"), false, 2.0)
	draw_rect(Rect2(SETTINGS_FAST_SLEEP.position + Vector2(5, 7), Vector2(12, 12)), Color("517b98") if fast_sleep_enabled else Color("252933"))
	draw_string(font, SETTINGS_FAST_SLEEP.position + Vector2(23, 17), "快速睡觉  %s" % ("ON" if fast_sleep_enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 98, 9, Color("bdc8cd"))


func _draw_phone_slider(font: Font, label_text: String, setting_name: StringName, rect: Rect2) -> void:
	var value := SettingsManager.get_volume(setting_name)
	draw_string(font, rect.position + Vector2(0, -3), "%s  %d%%" % [label_text, value], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 8, Color("aeb9bf"))
	var bar := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 8))
	draw_rect(bar, Color("171c24"))
	for segment in range(10):
		var segment_rect := Rect2(bar.position + Vector2(segment * 13.0 + 1.0, 1.0), Vector2(10.0, 6.0))
		draw_rect(segment_rect, Color("517b98") if value >= (segment + 1) * 10 else Color("303945"))
	draw_rect(bar, Color("657b88"), false, 1.0)
