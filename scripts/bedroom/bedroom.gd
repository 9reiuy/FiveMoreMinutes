extends Node2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")

signal sleep_requested(melatonin_count: int, is_hungry_run: bool)
signal save_requested

# The art shares a 2560×1440 transparent canvas and is uniformly scaled to 640×360.
# These bounds are the scaled non-transparent extents; the final hit test also checks alpha.
const BED_CLICK_RECT := Rect2(217.75, 154.0, 412.5, 206.0)
const BOTTLE_CLICK_SIZE := Vector2(15.5, 28.25)
# 收起（拉开）时遮光帘以半透明呈现，保证悬停描边在两种状态下都可见。
const SUNSHADE_RETRACTED_ALPHA := 0.35
const SUNSHADE_HOVER_BRIGHTNESS := 1.25

@export var config: DemoConfig
@onready var phone: Control = $PhoneLayer/BedroomPhone
@onready var melatonin_ui: Control = $PhoneLayer/MelatoninInteraction
@onready var confirmation_dialog: BedroomConfirmationDialog = $PhoneLayer/ConfirmationDialog
@onready var art_root: Node2D = $Layout/ArtRoot
@onready var bed_sprite: Sprite2D = $Layout/ArtRoot/BedroomBed
@onready var bottle_sprite: Sprite2D = $Layout/ArtRoot/MelatoninBottle
@onready var sunshade_sprite: Sprite2D = $Layout/ArtRoot/Sunshade
@onready var bed_click_area: Area2D = $Layout/BedClickArea
@onready var bottle_click_area: Area2D = $Layout/MelatoninClickArea
@onready var sunshade_click_area: Area2D = $Layout/SunshadeClickArea
@onready var bed_click_polygon: CollisionPolygon2D = $Layout/BedClickArea/CollisionPolygon2D
@onready var bottle_click_polygon: CollisionPolygon2D = $Layout/MelatoninClickArea/CollisionPolygon2D
@onready var sunshade_click_polygon: CollisionPolygon2D = $Layout/SunshadeClickArea/CollisionPolygon2D
@onready var bottle_anchor: Marker2D = $Layout/MelatoninBottleAnchor
@onready var door_interaction: BedroomDoorInteraction = $Layout/DoorInteraction
@onready var status_hud: BedroomStatusHUD = $PhoneLayer/BedroomStatusHUD
@onready var weather: BedroomWeather = $Layout/WeatherBackLayer

var after_dream := false
var summary: Dictionary = {}
var persistent_state: Dictionary = {}
var input_locked := false
var current_minutes := 1260.0
var highlighted := ""
var melatonin_used_count := 0
var weekday_name := "星期一"
var pending_confirmation := ""
var bed_image: Image
var bottle_image: Image
var sunshade_image: Image
var bed_outline_material: ShaderMaterial
var bottle_outline_material: ShaderMaterial
var sunshade_outline_material: ShaderMaterial
var hungry_sleep_committed := false


func _ready() -> void:
	SFX.play_bedroom_music()
	current_minutes = config.bedroom_start_minutes
	bed_image = bed_sprite.texture.get_image()
	bottle_image = bottle_sprite.texture.get_image()
	sunshade_image = sunshade_sprite.texture.get_image()
	bed_outline_material = bed_sprite.material as ShaderMaterial
	bottle_outline_material = bottle_sprite.material as ShaderMaterial
	sunshade_outline_material = sunshade_sprite.material as ShaderMaterial
	var outline_source_width := config.bedroom_interaction_outline_width / maxf(absf(art_root.scale.x), 0.001)
	var outline_color := config.bedroom_interaction_outline_color
	outline_color.a = config.bedroom_interaction_outline_opacity
	bed_outline_material.set_shader_parameter("outline_color", outline_color)
	bottle_outline_material.set_shader_parameter("outline_color", outline_color)
	sunshade_outline_material.set_shader_parameter("outline_color", outline_color)
	bed_outline_material.set_shader_parameter("outline_width_source_pixels", outline_source_width)
	bottle_outline_material.set_shader_parameter("outline_width_source_pixels", outline_source_width)
	# 遮光帘使用独立材质实例，描边宽度单独控制（3 屏幕像素 = 12 源像素）。
	sunshade_outline_material.set_shader_parameter("outline_width_source_pixels", 3.0 / maxf(absf(art_root.scale.x), 0.001))
	bed_click_area.mouse_entered.connect(_set_highlighted.bind("bed"))
	bed_click_area.mouse_exited.connect(_clear_highlighted.bind("bed"))
	bottle_click_area.mouse_entered.connect(_set_highlighted.bind("bottle"))
	bottle_click_area.mouse_exited.connect(_clear_highlighted.bind("bottle"))
	# 遮光帘的悬停检测完全由 _update_mouse_highlight（逐帧多边形+alpha 检测）负责，
	# 不连接 Area2D 信号，避免与状态切换后的 hover 刷新产生竞争。
	_sync_art_visibility()
	_sync_sunshade_visibility()
	_apply_sunshade_ambient()
	phone.balance_changed.connect(_on_balance_changed)
	phone.permanent_upgrade_changed.connect(_on_persistent_state_changed)
	phone.state_changed.connect(_on_persistent_state_changed)
	phone.configure_state(persistent_state)
	status_hud.set_stress(int(persistent_state.get("stress_value", config.stress_default)))
	weather.configure(str(persistent_state.get("daily_weather_type", "overcast")))
	melatonin_ui.completed.connect(_on_melatonin_completed)
	melatonin_ui.cancelled.connect(_on_melatonin_cancelled)
	confirmation_dialog.confirmed.connect(_on_confirmation_confirmed)
	confirmation_dialog.cancelled.connect(_on_confirmation_cancelled)
	_show_pending_entry_notice()
	queue_redraw()


func _exit_tree() -> void:
	SFX.stop_music(config.music_fade_duration)
	SFX.stop_weather_ambience(config.ambience_fade_duration)


func _process(delta: float) -> void:
	_update_delivery(delta)
	# Preserve the existing rule: ordinary dialogue pauses bedroom time; the phone does not.
	if not confirmation_dialog.visible:
		current_minutes += delta / maxf(config.bedroom_real_seconds_per_game_minute, 0.001)
	phone.set_bedroom_time(current_minutes)
	_sync_art_visibility()
	if not input_locked and not confirmation_dialog.visible and current_minutes >= config.bedroom_force_sleep_minutes:
		_begin_sleep(not bool(persistent_state.get("food_eaten_today", false)))
	_update_mouse_highlight()
	_update_door_and_status()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or melatonin_ui.visible or confirmation_dialog.visible or phone.blocks_bedroom_interaction():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if highlighted == "bed":
			_request_confirmation("bed")
		elif highlighted == "bottle":
			_request_confirmation("bottle")
		elif highlighted == "sunshade":
			_toggle_sunshade()
		elif highlighted == "door":
			_request_door_interaction()
		else:
			return
		get_viewport().set_input_as_handled()


func _update_mouse_highlight() -> void:
	if input_locked or melatonin_ui.visible or confirmation_dialog.visible or phone.blocks_bedroom_interaction():
		_set_highlighted("")
		return
	var mouse_position := get_viewport().get_mouse_position()
	if door_interaction.get_interaction_rect().has_point(mouse_position):
		_set_highlighted("door")
		return
	# The sunshade sits above the window and the bottle above the table; both win
	# over the bed. Order matters: drawn items are checked top-to-bottom.
	if bool(persistent_state.get("sunshade_purchased", false)) and _click_polygon_has_point(sunshade_click_polygon, mouse_position) and _is_opaque_at(sunshade_sprite, sunshade_image, mouse_position):
		_set_highlighted("sunshade")
		return
	# The bottle is visually above the table and therefore wins before the bed.
	if persistent_state.get("melatonin_bottle_present", false) and _click_polygon_has_point(bottle_click_polygon, mouse_position) and _is_opaque_at(bottle_sprite, bottle_image, mouse_position):
		_set_highlighted("bottle")
	elif _click_polygon_has_point(bed_click_polygon, mouse_position) and _is_opaque_at(bed_sprite, bed_image, mouse_position):
		_set_highlighted("bed")
	else:
		_set_highlighted("")


func _bottle_click_rect() -> Rect2:
	return Rect2(bottle_anchor.position - BOTTLE_CLICK_SIZE * 0.5, BOTTLE_CLICK_SIZE)


func _click_polygon_has_point(collision_polygon: CollisionPolygon2D, viewport_position: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(collision_polygon.to_local(viewport_position), collision_polygon.polygon)


func _is_opaque_at(sprite: Sprite2D, image: Image, viewport_position: Vector2) -> bool:
	if image == null or image.is_empty():
		return false
	var texture_position := sprite.to_local(viewport_position)
	var pixel := Vector2i(floori(texture_position.x), floori(texture_position.y))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return false
	return image.get_pixelv(pixel).a > 0.1


func _sync_art_visibility() -> void:
	bottle_sprite.visible = bool(persistent_state.get("melatonin_bottle_present", false)) and (not melatonin_ui.visible or not bool(melatonin_ui.call("is_table_bottle_taken")))
	if not bottle_sprite.visible and highlighted == "bottle":
		_set_highlighted("")


func _sync_sunshade_visibility() -> void:
	if not bool(persistent_state.get("sunshade_purchased", false)):
		sunshade_sprite.visible = false
		if highlighted == "sunshade":
			_set_highlighted("")
		return
	# 已购买后交互区域始终可检测；sprite 的显示由状态 + 悬停共同决定。
	_apply_sunshade_state_visual()


func _apply_sunshade_state_visual() -> void:
	var is_deployed := bool(persistent_state.get("sunshade_visible", true))
	var hovering := highlighted == "sunshade"
	if is_deployed:
		# 放下：显示窗帘；悬停时描边 + 轻微提亮。
		sunshade_sprite.visible = true
		sunshade_outline_material.set_shader_parameter("outline_only", 0.0)
		var brightness := SUNSHADE_HOVER_BRIGHTNESS if hovering else 1.0
		sunshade_sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	elif hovering:
		# 收起 + 悬停：只显示描边轮廓提示（主体透明），点击时才切换显示。
		sunshade_sprite.visible = true
		sunshade_outline_material.set_shader_parameter("outline_only", 1.0)
		sunshade_sprite.modulate = Color.WHITE
	else:
		# 收起 + 不悬停：完全隐藏（收回效果）。
		sunshade_sprite.visible = false
		sunshade_outline_material.set_shader_parameter("outline_only", 0.0)


func _refresh_sunshade_hover_visual() -> void:
	if not bool(persistent_state.get("sunshade_purchased", false)):
		return
	var mouse_position := get_viewport().get_mouse_position()
	var inside := _click_polygon_has_point(sunshade_click_polygon, mouse_position) and _is_opaque_at(sunshade_sprite, sunshade_image, mouse_position)
	_set_highlighted("sunshade" if inside else "")
	# _set_highlighted 对相同值会短路，状态切换后必须强制刷新视觉。
	_apply_sunshade_state_visual()


func _apply_sunshade_ambient() -> void:
	if not bool(persistent_state.get("sunshade_purchased", false)):
		SFX.set_weather_volume_multiplier(1.0)
		return
	SFX.set_weather_volume_multiplier(config.sunshade_ambient_volume_multiplier if bool(persistent_state.get("sunshade_visible", true)) else 1.0)


func _toggle_sunshade() -> void:
	if not bool(persistent_state.get("sunshade_purchased", false)):
		return
	persistent_state.sunshade_visible = not bool(persistent_state.get("sunshade_visible", true))
	_sync_sunshade_visibility()
	_apply_sunshade_ambient()
	# 鼠标仍停留在区域内时，立即对新状态 Sprite 恢复描边，无需移出再移入。
	_refresh_sunshade_hover_visual()
	save_requested.emit()
	SFX.play_event(&"phone_operation")


func _set_highlighted(next_highlight: String) -> void:
	if highlighted == next_highlight:
		return
	highlighted = next_highlight
	bed_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "bed" else 0.0)
	bottle_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "bottle" else 0.0)
	if sunshade_outline_material != null:
		sunshade_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "sunshade" else 0.0)
	# 遮光帘悬停时提亮、离开恢复（收起状态也随描边恢复全不透明度）。
	_apply_sunshade_state_visual()


func _clear_highlighted(expected_highlight: String) -> void:
	if highlighted == expected_highlight:
		_set_highlighted("")


func _begin_sleep(is_hungry: bool = false) -> void:
	if input_locked:
		return
	if is_hungry and not hungry_sleep_committed:
		hungry_sleep_committed = true
		persistent_state.is_hungry_run = true
		_change_stress(config.stress_hungry_sleep_gain, &"hungry_sleep")
	else:
		persistent_state.is_hungry_run = false
	input_locked = true
	pending_confirmation = ""
	confirmation_dialog.close_without_signal()
	melatonin_ui.force_cancel()
	phone.force_collapse()
	_set_highlighted("")
	sleep_requested.emit(melatonin_used_count, is_hungry)


func _request_confirmation(kind: String) -> void:
	pending_confirmation = kind
	_set_highlighted("")
	phone.force_collapse()
	if kind == "bed":
		if bool(persistent_state.get("food_eaten_today", false)):
			confirmation_dialog.open("要睡觉了吗？", "睡觉", "再等等")
		else:
			var attempts := int(persistent_state.get("hungry_bed_attempts_today", 0))
			if attempts < config.hungry_bed_attempts_before_force:
				pending_confirmation = "hungry_block"
				confirmation_dialog.open("吃点什么再睡吧", "买点什么吃吧", "算了")
			else:
				pending_confirmation = "hungry_force"
				confirmation_dialog.open("那就这样睡吧", "确认", "算了")
	else:
		var stock := int(persistent_state.get("melatonin_inventory", 0))
		if melatonin_used_count >= config.melatonin_nightly_use_limit:
			confirmation_dialog.open_message("已经够多了。")
		elif stock <= 0:
			confirmation_dialog.open_message("已经没有药了。")
		else:
			var prompt := "要吃药吗？" if melatonin_used_count == 0 else "还要再吃吗？"
			confirmation_dialog.open(prompt, "吃", "不吃")


func _on_confirmation_confirmed() -> void:
	var choice := pending_confirmation
	pending_confirmation = ""
	if choice == "bed":
		_begin_sleep(false)
	elif choice == "hungry_block":
		_increment_hungry_bed_attempt()
		phone.open_quicklink_from_bedroom()
	elif choice == "hungry_force":
		_begin_sleep(true)
	elif choice == "bottle":
		_open_melatonin()


func _on_confirmation_cancelled() -> void:
	var choice := pending_confirmation
	pending_confirmation = ""
	if choice == "hungry_block":
		_increment_hungry_bed_attempt()
	elif choice == "door_received":
		_finish_eating_delivery()


func _open_melatonin() -> void:
	if melatonin_used_count >= config.melatonin_nightly_use_limit or int(persistent_state.get("melatonin_inventory", 0)) <= 0:
		return
	melatonin_ui.open(persistent_state)


func _on_melatonin_completed() -> void:
	melatonin_used_count = mini(melatonin_used_count + 1, config.melatonin_nightly_use_limit)
	status_hud.set_stress(int(persistent_state.get("stress_value", config.stress_default)))
	save_requested.emit()


func _on_melatonin_cancelled() -> void:
	pass


func _on_balance_changed() -> void:
	_sync_art_visibility()
	save_requested.emit()


func _on_persistent_state_changed() -> void:
	_sync_sunshade_visibility()
	_apply_sunshade_ambient()
	save_requested.emit()


func _increment_hungry_bed_attempt() -> void:
	if bool(persistent_state.get("food_eaten_today", false)):
		return
	persistent_state.hungry_bed_attempts_today = int(persistent_state.get("hungry_bed_attempts_today", 0)) + 1


func _change_stress(change: int, reason: StringName) -> void:
	STATE_RULES.change_stress(persistent_state, change, reason, config)
	status_hud.set_stress(int(persistent_state.stress_value))


func _update_delivery(delta: float) -> void:
	if str(persistent_state.get("delivery_state", "NONE")) != "DELIVERING":
		return
	var remaining := maxf(0.0, float(persistent_state.get("delivery_seconds_remaining", config.cheap_meal_delivery_seconds)) - delta)
	persistent_state.delivery_seconds_remaining = remaining
	if remaining <= 0.0:
		persistent_state.delivery_state = "WAITING_AT_DOOR"
		SFX.play_door_knock()
		# 外卖送达时如果手机展开，播放收回动画并返回主界面，方便玩家去开门。
		if not phone.is_fully_collapsed():
			phone.screen_state = phone.ScreenState.HOME
			phone._sync_content_visibility()
			phone._animate_phone(false)
		save_requested.emit()


func _update_door_and_status() -> void:
	var ordinary_state := not input_locked and not melatonin_ui.visible and not confirmation_dialog.visible
	var phone_collapsed: bool = bool(phone.is_fully_collapsed())
	var waiting := str(persistent_state.get("delivery_state", "NONE")) == "WAITING_AT_DOOR"
	door_interaction.set_state(ordinary_state and phone_collapsed, highlighted == "door", waiting)
	status_hud.visible = ordinary_state and phone_collapsed
	status_hud.set_stress(int(persistent_state.get("stress_value", config.stress_default)))


func _request_door_interaction() -> void:
	if not phone.is_fully_collapsed():
		return
	_set_highlighted("")
	if str(persistent_state.get("delivery_state", "NONE")) != "WAITING_AT_DOOR":
		pending_confirmation = "door_empty"
		confirmation_dialog.open_message("门外没有人")
		return
	persistent_state.delivery_state = "RECEIVED"
	persistent_state.delivery_seconds_remaining = 0.0
	pending_confirmation = "door_received"
	input_locked = true
	SFX.play_event(&"home_door")
	await get_tree().create_timer(config.door_open_close_gap_seconds, false).timeout
	SFX.play_event(&"home_door")
	confirmation_dialog.open_message("你拿到了廉价便当。\n……勉强能吃。")
	input_locked = false


func _finish_eating_delivery() -> void:
	if bool(persistent_state.get("food_eaten_today", false)):
		return
	persistent_state.food_eaten_today = true
	persistent_state.hungry_bed_attempts_today = 0
	persistent_state.is_hungry_run = false
	_change_stress(-config.stress_food_reduction, &"food")
	save_requested.emit()


func _show_pending_entry_notice() -> void:
	var notices: Array[String] = []
	var unlock_notice := str(persistent_state.get("pending_unlock_notice", ""))
	if not unlock_notice.is_empty():
		notices.append(unlock_notice)
		persistent_state.erase("pending_unlock_notice")
	var sunday_notice := str(persistent_state.get("pending_sunday_notice", ""))
	if not sunday_notice.is_empty():
		notices.append(sunday_notice)
		persistent_state.erase("pending_sunday_notice")
	if notices.is_empty():
		return
	pending_confirmation = "entry_notice"
	confirmation_dialog.open_message("\n\n".join(notices))
	save_requested.emit()
