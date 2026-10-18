extends Node2D

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")

signal sleep_requested(melatonin_count: int, is_hungry_run: bool)
signal save_requested
signal story_weapon_changed(weapon_id: String)
signal phone_open_requested(page: StringName)
signal phone_close_requested
signal phone_story_effect_requested(effect: StringName)

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
# 电脑 Sprite：默认息屏素材，当天首次打开后切换为亮屏素材（见 _sync_computer_visual）。
@onready var computer_sprite: Sprite2D = $Layout/ArtRoot/BedroomComputer
@onready var bedroom_chr_sprite: Sprite2D = $Layout/ArtRoot/BedroomChrRoot/BedroomChrOnBed
@onready var bedroom_chr_glow_sprite: Sprite2D = $Layout/ArtRoot/BedroomChrRoot/BedroomChrOnBedLight
@onready var bedroom_chr_glow_timer: Timer = $Layout/ArtRoot/BedroomChrRoot/GlowFlickerTimer
@onready var bed_click_area: Area2D = $Layout/BedClickArea
@onready var bottle_click_area: Area2D = $Layout/MelatoninClickArea
@onready var sunshade_click_area: Area2D = $Layout/SunshadeClickArea
@onready var computer_click_polygon: CollisionPolygon2D = $Layout/ComputerClickArea/CollisionPolygon2D
@onready var bed_click_polygon: CollisionPolygon2D = $Layout/BedClickArea/CollisionPolygon2D
@onready var bottle_click_polygon: CollisionPolygon2D = $Layout/MelatoninClickArea/CollisionPolygon2D
@onready var sunshade_click_polygon: CollisionPolygon2D = $Layout/SunshadeClickArea/CollisionPolygon2D
@onready var bedroom_chr_click_polygon: CollisionPolygon2D = $Layout/BedroomChrClickArea/CollisionPolygon2D
@onready var bottle_anchor: Marker2D = $Layout/MelatoninBottleAnchor
@onready var door_interaction: BedroomDoorInteraction = $Layout/BottomEdgeInteraction
@onready var status_hud: BedroomStatusHUD = $PhoneLayer/BedroomStatusHUD
@onready var weather: BedroomWeather = $Layout/WeatherBackLayer
@onready var hallway: HallwayView = $Hallway
# 像素风动态光照：CanvasModulate 控制卧室基础环境亮度，
# ComputerScreenLight 为电脑屏幕发光（卧室当前唯一的动态光源；窗户光照系统已废弃删除）。
@onready var ambient_modulate: CanvasModulate = $Layout/BedroomLighting/CanvasModulate
@onready var computer_screen_light: PointLight2D = $Layout/BedroomLighting/ComputerScreenLight
# 21:00→00:00 动态暗角：只覆盖卧室主画布，不影响 CanvasLayer 上的 UI。
@onready var vignette_material: ShaderMaterial = $Layout/VignetteLayer.material as ShaderMaterial
@onready var computer_overlay: ComputerOverlay = $ComputerLayer/ComputerOverlay

var after_dream := false
var summary: Dictionary = {}
var persistent_state: Dictionary = {}
var input_locked := false
var current_minutes := 1260.0
var highlighted := ""
var melatonin_used_count := 0
var weekday_name := "星期一"
var bed_image: Image
var bottle_image: Image
var sunshade_image: Image
# 电脑 alpha 检测用图像：亮/息屏两张素材的不透明区域完全一致，用亮屏图即可。
var computer_image: Image
var bedroom_chr_image: Image
var bed_outline_material: ShaderMaterial
var bottle_outline_material: ShaderMaterial
var sunshade_outline_material: ShaderMaterial
var computer_outline_material: ShaderMaterial
var bedroom_chr_outline_material: ShaderMaterial
var hungry_sleep_committed := false
var bedroom_chr_interaction_enabled := true
var bedroom_chr_interaction_before_dialog := true
var bedroom_chr_dialogue_visibility: Dictionary = {}
var bedroom_chr_dialogue_hidden := false

# 电脑素材路径（亮屏 / 息屏）：
#   亮屏：res://art/Badroom/bedroom_computer_light.png（当天首次打开电脑后显示）
#   息屏：res://art/Badroom/bedroom_computer_dark.png（新的一天开始时的默认状态）
const COMPUTER_LIGHT_TEXTURE := preload("res://art/Badroom/bedroom_computer_light.png")
const COMPUTER_DARK_TEXTURE := preload("res://art/Badroom/bedroom_computer_dark.png")


func _ready() -> void:
	SFX.play_bedroom_music(false, get_instance_id())
	current_minutes = config.bedroom_start_minutes
	bed_image = bed_sprite.texture.get_image()
	bottle_image = bottle_sprite.texture.get_image()
	sunshade_image = sunshade_sprite.texture.get_image()
	computer_image = COMPUTER_LIGHT_TEXTURE.get_image()
	bedroom_chr_image = bedroom_chr_sprite.texture.get_image()
	bed_outline_material = bed_sprite.material as ShaderMaterial
	bottle_outline_material = bottle_sprite.material as ShaderMaterial
	sunshade_outline_material = sunshade_sprite.material as ShaderMaterial
	computer_outline_material = computer_sprite.material as ShaderMaterial
	bedroom_chr_outline_material = bedroom_chr_sprite.material as ShaderMaterial
	var outline_source_width := config.bedroom_interaction_outline_width / maxf(absf(art_root.scale.x), 0.001)
	var outline_color := config.bedroom_interaction_outline_color
	outline_color.a = config.bedroom_interaction_outline_opacity
	bed_outline_material.set_shader_parameter("outline_color", outline_color)
	bottle_outline_material.set_shader_parameter("outline_color", outline_color)
	sunshade_outline_material.set_shader_parameter("outline_color", outline_color)
	computer_outline_material.set_shader_parameter("outline_color", outline_color)
	bedroom_chr_outline_material.set_shader_parameter("outline_color", outline_color)
	bed_outline_material.set_shader_parameter("outline_width_source_pixels", outline_source_width)
	bottle_outline_material.set_shader_parameter("outline_width_source_pixels", outline_source_width)
	# 电脑描边与床使用同一套 shader 与同一宽度参数（统一描边组件）。
	computer_outline_material.set_shader_parameter("outline_width_source_pixels", outline_source_width)
	bedroom_chr_outline_material.set_shader_parameter("outline_width_source_pixels", outline_source_width)
	_setup_bedroom_chr_glow()
	# 遮光帘使用独立材质实例，描边宽度单独控制（3 屏幕像素 = 12 源像素）。
	sunshade_outline_material.set_shader_parameter("outline_width_source_pixels", 3.0 / maxf(absf(art_root.scale.x), 0.001))
	bed_click_area.mouse_entered.connect(_set_highlighted.bind("bed"))
	bed_click_area.mouse_exited.connect(_clear_highlighted.bind("bed"))
	bottle_click_area.mouse_entered.connect(_set_highlighted.bind("bottle"))
	bottle_click_area.mouse_exited.connect(_clear_highlighted.bind("bottle"))
	# 遮光帘与电脑的悬停检测完全由 _update_mouse_highlight（逐帧多边形+alpha 检测）负责，
	# 不连接 Area2D 信号，避免与状态切换后的 hover 刷新产生竞争。
	_sync_art_visibility()
	_sync_sunshade_visibility()
	_apply_sunshade_ambient()
	_setup_lighting()
	_sync_computer_visual()
	computer_overlay.closed.connect(_close_computer)
	computer_overlay.shutdown_requested.connect(_shutdown_computer)
	computer_overlay.balance_changed.connect(_on_balance_changed)
	computer_overlay.story_weapon_changed.connect(_on_story_weapon_changed)
	computer_overlay.configure(persistent_state)
	phone.balance_changed.connect(_on_balance_changed)
	phone.state_changed.connect(_on_persistent_state_changed)
	phone.configure_state(persistent_state)
	# Only Main opts into the shared phone. Direct bedroom previews and the
	# data/purchase backend retain their existing standalone contract.
	if phone_open_requested.get_connections().size() > 0:
		phone.open_requested.connect(_on_shared_phone_open_requested)
		phone.external_close_requested.connect(_on_shared_phone_close_requested)
		phone.external_story_effect_requested.connect(_on_shared_phone_story_effect_requested)
		phone.set_external_ui_enabled(true)
	status_hud.bind_state(persistent_state)
	status_hud.set_stress(int(persistent_state.get("stress_value", config.stress_default)))
	weather.configure(str(persistent_state.get("daily_weather_type", "overcast")))
	melatonin_ui.completed.connect(_on_melatonin_completed)
	melatonin_ui.cancelled.connect(_on_melatonin_cancelled)
	confirmation_dialog.action_requested.connect(_on_dialogue_action_requested)
	confirmation_dialog.session_started.connect(_on_dialogue_session_started)
	confirmation_dialog.session_ended.connect(_on_dialogue_session_ended)
	hallway.door_clicked.connect(_on_hallway_door_clicked)
	hallway.return_requested.connect(_close_hallway)
	_show_pending_entry_notice()
	queue_redraw()


func _exit_tree() -> void:
	# CanvasModulate/PointLight2D 都严格属于 Bedroom；转场释放前先关闭，
	# 避免 queue_free 延迟到帧末时短暂影响下一个场景。
	ambient_modulate.visible = false
	computer_screen_light.visible = false
	bedroom_chr_glow_timer.stop()
	SFX.stop_music(config.music_fade_duration, get_instance_id())
	SFX.stop_weather_ambience(config.ambience_fade_duration)


func _on_shared_phone_open_requested(page: StringName) -> void:
	phone_open_requested.emit(page)


func _on_shared_phone_close_requested() -> void:
	phone_close_requested.emit()


func _on_shared_phone_story_effect_requested(effect: StringName) -> void:
	phone_story_effect_requested.emit(effect)


func set_game_phone_active(active: bool) -> void:
	phone.set_external_ui_active(active)
	_update_mouse_highlight()
	_update_door_and_status()


func _process(delta: float) -> void:
	_update_delivery(delta)
	# Preserve the existing rule: ordinary dialogue pauses bedroom time; the phone does not.
	if not confirmation_dialog.visible:
		current_minutes += delta / maxf(config.bedroom_real_seconds_per_game_minute, 0.001)
	phone.set_bedroom_time(current_minutes)
	computer_overlay.set_bedroom_time(current_minutes)
	_sync_art_visibility()
	if not input_locked and not confirmation_dialog.visible and current_minutes >= config.bedroom_force_sleep_minutes:
		_begin_sleep(not bool(persistent_state.get("food_eaten_today", false)))
	_update_mouse_highlight()
	_update_door_and_status()
	_update_vignette()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if hallway.visible or input_locked or melatonin_ui.visible or confirmation_dialog.visible or computer_overlay.visible or phone.blocks_bedroom_interaction():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if highlighted == "bed":
			_request_confirmation("bed")
		elif highlighted == "bottle":
			_request_confirmation("bottle")
		elif highlighted == "sunshade":
			_toggle_sunshade()
		elif highlighted == "computer":
			_open_computer()
		elif highlighted == "bedroom_chr":
			_request_confirmation("bedroom_chr")
		elif highlighted == "door":
			_request_door_interaction()
		else:
			return
		get_viewport().set_input_as_handled()


## ESC 优先级钩子（由 main.gd 的 _input 在打开暂停菜单前调用）：
## 电脑界面打开时，ESC 先关闭电脑界面而不是打开暂停菜单。
## 返回 true 表示已消费本次 ESC。
func consume_escape() -> bool:
	if computer_overlay.visible:
		_close_computer()
		return true
	# 走廊没有新增返回按钮；复用主流程已有的 ESC/Back 优先级返回卧室。
	if hallway.visible and not confirmation_dialog.visible:
		_close_hallway()
		return true
	return false


func _update_mouse_highlight() -> void:
	if hallway.visible or input_locked or melatonin_ui.visible or confirmation_dialog.visible or computer_overlay.visible or phone.blocks_bedroom_interaction():
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
	# 电脑在桌面上，位于床的左上方，与床/药瓶区域不重叠；同样做逐像素 alpha 检测，
	# 避免电脑素材周围的透明空白区域可点。
	elif _click_polygon_has_point(computer_click_polygon, mouse_position) and _is_opaque_at(computer_sprite, computer_image, mouse_position):
		_set_highlighted("computer")
	elif bedroom_chr_interaction_enabled and bedroom_chr_sprite.visible and _click_polygon_has_point(bedroom_chr_click_polygon, mouse_position) and _is_opaque_at(bedroom_chr_sprite, bedroom_chr_image, mouse_position):
		_set_highlighted("bedroom_chr")
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
	# 发光层只跟随主体显隐，不参与角色的点击、碰撞或悬停描边。
	var glow_should_be_visible := config.bedroom_chr_glow_enabled and bedroom_chr_sprite.visible and not bedroom_chr_dialogue_hidden
	bedroom_chr_glow_sprite.visible = glow_should_be_visible
	if glow_should_be_visible:
		if bedroom_chr_glow_timer.is_stopped():
			_restart_bedroom_chr_glow_flicker()
	else:
		bedroom_chr_glow_timer.stop()


func _setup_bedroom_chr_glow() -> void:
	if not bedroom_chr_glow_timer.timeout.is_connected(_on_bedroom_chr_glow_flicker_timeout):
		bedroom_chr_glow_timer.timeout.connect(_on_bedroom_chr_glow_flicker_timeout)
	_sync_art_visibility()


func _restart_bedroom_chr_glow_flicker(reset_alpha: bool = true) -> void:
	if reset_alpha:
		var normal_min := minf(config.bedroom_chr_glow_alpha_normal_min, config.bedroom_chr_glow_alpha_normal_max)
		var normal_max := maxf(config.bedroom_chr_glow_alpha_normal_min, config.bedroom_chr_glow_alpha_normal_max)
		bedroom_chr_glow_sprite.self_modulate = Color(config.bedroom_chr_glow_color, randf_range(normal_min, normal_max))
	_schedule_bedroom_chr_glow_flicker()


func _schedule_bedroom_chr_glow_flicker() -> void:
	var interval_min := minf(config.bedroom_chr_glow_interval_min, config.bedroom_chr_glow_interval_max)
	var interval_max := maxf(config.bedroom_chr_glow_interval_min, config.bedroom_chr_glow_interval_max)
	bedroom_chr_glow_timer.start(randf_range(maxf(interval_min, 0.05), maxf(interval_max, 0.05)))


func _on_bedroom_chr_glow_flicker_timeout() -> void:
	if not config.bedroom_chr_glow_enabled or bedroom_chr_dialogue_hidden or not bedroom_chr_sprite.visible:
		bedroom_chr_glow_timer.stop()
		return
	var next_alpha := _next_bedroom_chr_glow_alpha(bedroom_chr_glow_sprite.self_modulate.a)
	# 视频画面切换采用直接硬切，不创建Tween，也不在_process中逐帧随机。
	bedroom_chr_glow_sprite.self_modulate = Color(config.bedroom_chr_glow_color, next_alpha)
	_schedule_bedroom_chr_glow_flicker()


func _next_bedroom_chr_glow_alpha(current_alpha: float) -> float:
	var normal_min := minf(config.bedroom_chr_glow_alpha_normal_min, config.bedroom_chr_glow_alpha_normal_max)
	var normal_max := maxf(config.bedroom_chr_glow_alpha_normal_min, config.bedroom_chr_glow_alpha_normal_max)
	var big_change_chance := clampf(config.bedroom_chr_glow_big_change_chance, 0.0, 1.0)
	if randf() < big_change_chance:
		# 强切换总是选当前亮度的另一侧，避免抽到数值接近的“伪强切换”。
		if current_alpha >= (normal_min + normal_max) * 0.5:
			var dark_min := minf(config.bedroom_chr_glow_alpha_dark_min, config.bedroom_chr_glow_alpha_dark_max)
			var dark_max := maxf(config.bedroom_chr_glow_alpha_dark_min, config.bedroom_chr_glow_alpha_dark_max)
			return randf_range(dark_min, dark_max)
		var bright_min := minf(config.bedroom_chr_glow_alpha_bright_min, config.bedroom_chr_glow_alpha_bright_max)
		var bright_max := maxf(config.bedroom_chr_glow_alpha_bright_min, config.bedroom_chr_glow_alpha_bright_max)
		return randf_range(bright_min, bright_max)
	# 同一视频镜头内优先围绕当前值小幅跳变；离开极端亮/暗画面后回到普通区间。
	if current_alpha < normal_min or current_alpha > normal_max:
		return randf_range(normal_min, normal_max)
	var change_amount := randf_range(0.03, 0.10)
	if current_alpha <= normal_min + 0.03:
		return minf(current_alpha + change_amount, normal_max)
	if current_alpha >= normal_max - 0.03:
		return maxf(current_alpha - change_amount, normal_min)
	return clampf(current_alpha + change_amount * (-1.0 if randf() < 0.5 else 1.0), normal_min, normal_max)


func _sync_sunshade_visibility() -> void:
	if not bool(persistent_state.get("sunshade_purchased", false)):
		sunshade_sprite.visible = false
		if highlighted == "sunshade":
			_set_highlighted("")
		return
	# 已购买后交互区域始终可检测；sprite 的显示由状态 + 悬停共同决定。
	# 遮阳帘不再影响任何光源（窗户光照已删除），只保留美术与交互。
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


# ============================================================
# 电脑交互与息屏逻辑
# ============================================================

## 电脑当天状态字段：persistent_state.computer_opened_today（bool）。
##   - 新的一天开始：main.gd _reset_daily_state() 重置为 false
##   - 当天首次打开电脑：置为 true 并存档
##   - false -> 息屏素材 computer_dark，true -> 亮屏素材 computer_light

## 打开电脑界面：当天首次打开时记录状态并点亮卧室中的电脑屏幕。
## Overlay 覆盖全屏（mouse_filter=STOP），自动阻断手机/床/药瓶/遮光帘交互。
func _open_computer() -> void:
	if input_locked or computer_overlay.visible:
		return
	if not bool(persistent_state.get("computer_opened_today", false)):
		persistent_state.computer_opened_today = true
		save_requested.emit()
	_sync_computer_visual()
	_set_highlighted("")
	phone.force_collapse()
	SFX.play_event(&"confirm")
	computer_overlay.open()


## 关闭电脑界面：恢复卧室交互（高亮检测会在下一帧自动恢复）。
func _close_computer() -> void:
	computer_overlay.close()


func _shutdown_computer() -> void:
	# 关机只改变电脑电源状态，不碰房间时间、手机、余额或配送状态。
	persistent_state.computer_opened_today = false
	_sync_computer_visual()
	save_requested.emit()


## 电脑亮屏/息屏素材切换与屏幕光同步：
## 本函数是唯一更新电脑灯光状态的入口（bedroom.gd）。
func _sync_computer_visual() -> void:
	var opened_today := bool(persistent_state.get("computer_opened_today", false))
	computer_sprite.texture = COMPUTER_LIGHT_TEXTURE if opened_today else COMPUTER_DARK_TEXTURE
	# 电脑光只在 Bedroom 地点显示；Hallway 虽与 Bedroom 共用同一夜状态，但不继承其灯光。
	ambient_modulate.visible = not hallway.visible
	computer_screen_light.visible = opened_today and not hallway.visible


## 初始化像素风动态光照参数（统一从 DemoConfig 读取，便于调参）。
## 节点位置/旋转/贴图在 bedroom.tscn 的 Layout/BedroomLighting 下配置。
## 窗户光照系统（WindowLight / CurtainLightOccluder）已彻底删除，卧室只保留电脑屏幕光。
## 注意：点光必须使用 Mix 混合（blend_mode=1 的 Add 在本渲染环境下
## 会把照射区渲染成黑色）。电脑光增强倍率只在配置乘数一处生效，不重复叠加。
func _setup_lighting() -> void:
	ambient_modulate.color = config.bedroom_ambient_modulate_color
	computer_screen_light.blend_mode = PointLight2D.BLEND_MODE_MIX
	computer_screen_light.color = config.bedroom_computer_light_color
	computer_screen_light.energy = config.bedroom_computer_light_energy * config.computer_light_energy_multiplier


## 越接近 00:00（强制睡觉时间）暗角越强；用卧室游戏时间驱动，不用系统时间。
## Ease-In（progress²）避免线性过强；跨午夜时按当天夜间分钟归一化，防止插值反向。
## 强度不设置任何人为上限：final = (min_strength + progress²) × vignette_intensity_multiplier，
## 正常流程 00:00 会强制睡觉；Debug 让时间超过 00:00 时 progress > 1，计算值继续增长不截断。
func _update_vignette() -> void:
	if vignette_material == null:
		return
	var progress := _vignette_progress()
	var base_strength := config.bedroom_vignette_min_strength + progress * progress
	vignette_material.set_shader_parameter("strength", maxf(base_strength * config.vignette_intensity_multiplier, 0.0))


func _vignette_progress() -> float:
	var start_minutes := config.bedroom_vignette_start_minutes
	var end_minutes := config.bedroom_vignette_end_minutes
	if end_minutes < start_minutes:
		end_minutes += 1440.0
	var minutes := current_minutes
	if minutes < start_minutes:
		minutes += 1440.0
	return maxf((minutes - start_minutes) / maxf(end_minutes - start_minutes, 1.0), 0.0)


func _set_highlighted(next_highlight: String) -> void:
	if highlighted == next_highlight:
		return
	highlighted = next_highlight
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not highlighted.is_empty() else Input.CURSOR_ARROW)
	bed_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "bed" else 0.0)
	bottle_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "bottle" else 0.0)
	if sunshade_outline_material != null:
		sunshade_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "sunshade" else 0.0)
	if computer_outline_material != null:
		computer_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "computer" else 0.0)
	if bedroom_chr_outline_material != null:
		bedroom_chr_outline_material.set_shader_parameter("outline_enabled", 1.0 if highlighted == "bedroom_chr" else 0.0)
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
	_close_hallway()
	confirmation_dialog.close_without_signal()
	melatonin_ui.force_cancel()
	phone.force_collapse()
	_set_highlighted("")
	sleep_requested.emit(melatonin_used_count, is_hungry)


func _request_confirmation(kind: String) -> void:
	_set_highlighted("")
	phone.force_collapse()
	if kind == "bedroom_chr":
		confirmation_dialog.open_dialogue(&"bedroom_self", {"computer_name": _get_computer_name()})
	elif kind == "bed":
		if bool(persistent_state.get("food_eaten_today", false)):
			confirmation_dialog.open_dialogue(&"bed_ready_sleep")
		elif int(persistent_state.get("balance", 0)) < config.hungry_bed_direct_sleep_balance_threshold:
			# 余额不足一份便当时不先闪现购买劝告，直接进入现有饥饿入睡确认。
			confirmation_dialog.open_dialogue(&"bed_hungry_force")
		else:
			var attempts := int(persistent_state.get("hungry_bed_attempts_today", 0))
			if attempts < config.hungry_bed_attempts_before_force:
				confirmation_dialog.open_dialogue(&"bed_hungry_food_prompt")
			else:
				confirmation_dialog.open_dialogue(&"bed_hungry_force")
	else:
		var stock := int(persistent_state.get("melatonin_inventory", 0))
		if melatonin_used_count >= config.melatonin_nightly_use_limit:
			confirmation_dialog.open_dialogue(&"melatonin_nightly_limit")
		elif stock <= 0:
			confirmation_dialog.open_dialogue(&"melatonin_empty")
		else:
			confirmation_dialog.open_dialogue(&"melatonin_first_prompt" if melatonin_used_count == 0 else &"melatonin_repeat_prompt")


func _on_dialogue_action_requested(action_id: StringName) -> void:
	# Safe action whitelist: JSON provides only a symbolic action; this match is
	# the sole place where Bedroom turns it into gameplay behavior.
	match action_id:
		&"begin_sleep":
			_begin_sleep(false)
		&"begin_hungry_sleep":
			_begin_sleep(true)
		&"open_quicklink":
			_increment_hungry_bed_attempt()
			phone.open_quicklink_from_bedroom()
		&"defer_food_purchase":
			_increment_hungry_bed_attempt()
		&"take_melatonin":
			_open_melatonin()
		&"finish_delivery_meal":
			_finish_eating_delivery()
		_:
			push_error("[DIALOGUE DATA ERROR]\nfile: res://data/dialogue/bedroom.json\nid: action\nline: -\nreason: unsupported Bedroom action '%s'" % action_id)


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


func _on_story_weapon_changed(_weapon_id: String) -> void:
	# 交给主流程的既有剧情武器入口，同时更新存档与当天快照。
	story_weapon_changed.emit(_weapon_id)


func _on_persistent_state_changed() -> void:
	_sync_sunshade_visibility()
	_apply_sunshade_ambient()
	save_requested.emit()


func _increment_hungry_bed_attempt() -> void:
	if bool(persistent_state.get("food_eaten_today", false)):
		return
	persistent_state.hungry_bed_attempts_today = int(persistent_state.get("hungry_bed_attempts_today", 0)) + 1


## 仅用于 bedroom_self 对话的一句问候文本：运行时读取本机电脑名。
## 优先 Windows 环境变量 COMPUTERNAME，其次其它平台的 HOSTNAME，
## 读取失败时回退到"玩家"。结果只做本地显示，不写入存档、不外发。
func _get_computer_name() -> String:
	var computer_name := OS.get_environment("COMPUTERNAME").strip_edges()
	if computer_name.is_empty():
		computer_name = OS.get_environment("HOSTNAME").strip_edges()
	# 清理内部换行，避免破坏对话框布局；再次去空白兜底。
	computer_name = computer_name.replace("\r", "").replace("\n", "").strip_edges()
	if computer_name.is_empty():
		computer_name = "玩家"
	return computer_name


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


## 底部边缘交互（开门/取餐）统一输入优先级判断：
## 手机展开、电脑界面、对话/确认弹窗、褪黑素界面、输入锁定期间一律禁用，
## 不依赖节点视觉遮挡碰运气阻断输入。
func can_use_bottom_edge_interaction() -> bool:
	if input_locked:
		return false
	if hallway.visible:
		return false
	if phone.blocks_bedroom_interaction() or not phone.is_fully_collapsed():
		return false
	if computer_overlay.visible:
		return false
	if confirmation_dialog.visible or melatonin_ui.visible:
		return false
	return true


func _update_door_and_status() -> void:
	var ordinary_state := not hallway.visible and not input_locked and not melatonin_ui.visible and not confirmation_dialog.visible and not computer_overlay.visible
	var phone_collapsed: bool = bool(phone.is_fully_collapsed())
	var waiting := str(persistent_state.get("delivery_state", "NONE")) == "WAITING_AT_DOOR"
	door_interaction.set_state(can_use_bottom_edge_interaction(), highlighted == "door", waiting)
	status_hud.visible = ordinary_state and phone_collapsed
	status_hud.set_stress(int(persistent_state.get("stress_value", config.stress_default)))


func _request_door_interaction() -> void:
	if not phone.is_fully_collapsed():
		return
	_set_highlighted("")
	if str(persistent_state.get("delivery_state", "NONE")) != "WAITING_AT_DOOR":
		_open_hallway()
		return
	_claim_delivery()


func _open_hallway() -> void:
	if hallway.visible or not can_use_bottom_edge_interaction():
		return
	_set_highlighted("")
	hallway.open()
	_sync_computer_visual()


func _close_hallway() -> void:
	if hallway.visible:
		hallway.close()
		_sync_computer_visual()


func _on_hallway_door_clicked() -> void:
	if not hallway.visible or confirmation_dialog.visible:
		return
	if str(persistent_state.get("delivery_state", "NONE")) == "WAITING_AT_DOOR":
		_claim_delivery()
		return
	confirmation_dialog.open_dialogue(&"hallway_no_one")


func _claim_delivery() -> void:
	if str(persistent_state.get("delivery_state", "NONE")) != "WAITING_AT_DOOR":
		return
	persistent_state.delivery_state = "RECEIVED"
	persistent_state.delivery_seconds_remaining = 0.0
	input_locked = true
	hallway.set_interaction_enabled(false)
	SFX.play_event(&"home_door")
	await get_tree().create_timer(config.door_open_close_gap_seconds, false).timeout
	SFX.play_event(&"home_door")
	confirmation_dialog.open_dialogue(&"delivery_received")
	input_locked = false


func _finish_eating_delivery() -> void:
	if bool(persistent_state.get("food_eaten_today", false)):
		return
	persistent_state.food_eaten_today = true
	persistent_state.hungry_bed_attempts_today = 0
	persistent_state.is_hungry_run = false
	_change_stress(-config.stress_food_reduction, &"food")
	status_hud.refresh()
	save_requested.emit()


func _on_dialogue_session_started() -> void:
	hallway.set_interaction_enabled(false)
	# Hallway 对话不操作卧室角色；卧室角色只是被不透明 Hallway 背景自然遮住。
	if hallway.visible or bedroom_chr_dialogue_hidden:
		return
	bedroom_chr_dialogue_hidden = true
	bedroom_chr_glow_timer.stop()
	bedroom_chr_dialogue_visibility.clear()
	bedroom_chr_interaction_before_dialog = bedroom_chr_interaction_enabled
	bedroom_chr_interaction_enabled = false
	if highlighted == "bedroom_chr":
		_set_highlighted("")
	for node in get_tree().get_nodes_in_group("bedroom_chr_visuals"):
		if node is CanvasItem and is_ancestor_of(node):
			bedroom_chr_dialogue_visibility[node.get_instance_id()] = node.visible
			node.visible = false


func _on_dialogue_session_ended() -> void:
	if hallway.visible:
		hallway.set_interaction_enabled(true)
	if not bedroom_chr_dialogue_hidden:
		return
	for node in get_tree().get_nodes_in_group("bedroom_chr_visuals"):
		if node is CanvasItem and is_ancestor_of(node):
			var original_visibility := bool(bedroom_chr_dialogue_visibility.get(node.get_instance_id(), false))
			node.visible = original_visibility
	bedroom_chr_interaction_enabled = bedroom_chr_interaction_before_dialog
	bedroom_chr_dialogue_visibility.clear()
	bedroom_chr_dialogue_hidden = false
	_sync_art_visibility()


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
	confirmation_dialog.open_dialogue(&"common_dynamic_notice", {"notice": "\n\n".join(notices)})
	save_requested.emit()
