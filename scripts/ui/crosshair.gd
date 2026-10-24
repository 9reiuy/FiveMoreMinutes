extends Control

var _cached_dream_world: Node
@export var config: DemoConfig
var player: Node
var current_color := Color.GRAY
var recoil_rotation := 0.0
var recoil_kick_rotation := 0.0
var recoil_active := false
var _last_draw_color := Color(-1, -1, -1, -1)
var _last_draw_recoil := INF
var _last_draw_position := Vector2(INF, INF)
var _last_draw_ammo: Dictionary = {}
var _last_draw_shape: int = -1

enum CrosshairShape {
	SQUARE,   ## 近战武器 (Melee: lucille, books, fist)
	T_SHAPE,  ## 连发武器 (Automatic / Rapid-fire: assault_rifle)
	BRACKET,  ## 霰弹枪 (Shotgun: shotgun)
	CIRCLE,   ## 手枪或以后的狙击类武器 (Pistol / Sniper: basic)
}


func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world


func configure(target: Node) -> void:
	player = target
	# The confirmed event is emitted only after a formal firearm actually
	# spawned its projectile(s).  Keep the legacy signal as a compatibility
	# fallback for older Player scenes that do not expose that event.
	if target.has_signal("confirmed_projectile_fired"):
		target.confirmed_projectile_fired.connect(_on_confirmed_projectile_fired)
	elif target.has_signal("weapon_fired"):
		target.weapon_fired.connect(_on_weapon_fired)
	if target.has_signal("active_weapon_changed"):
		target.active_weapon_changed.connect(_on_active_weapon_changed)


func _on_active_weapon_changed(_weapon_id: String) -> void:
	_last_draw_shape = -1
	queue_redraw()


func get_current_crosshair_shape() -> CrosshairShape:
	if not is_instance_valid(player):
		return CrosshairShape.CIRCLE
	var weapon_id := "basic"
	if "selected_weapon_id" in player:
		weapon_id = str(player.get("selected_weapon_id"))
	return get_shape_for_weapon_id(weapon_id)


static func get_shape_for_weapon_id(weapon_id: String) -> CrosshairShape:
	if weapon_id.is_empty():
		return CrosshairShape.SQUARE
	match weapon_id:
		"lucille", "books":
			return CrosshairShape.SQUARE
		"assault_rifle", "smg", "machine_gun", "rifle":
			return CrosshairShape.T_SHAPE
		"shotgun", "sawed_off", "double_barrel":
			return CrosshairShape.BRACKET
		"basic", "pistol", "revolver", "sniper", "marksman":
			return CrosshairShape.CIRCLE
		_:
			if ClassDB.class_exists(&"DreamGunAtlas"):
				var cat: StringName = DreamGunAtlas.get_category(weapon_id)
				if cat == DreamGunAtlas.CATEGORY_MELEE:
					return CrosshairShape.SQUARE
			return CrosshairShape.CIRCLE


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var progress: float = clampf(float(player.get_weapon_cooldown_progress()), 0.0, 1.0)
	var target_color := config.crosshair_cooldown_color.lerp(config.crosshair_ready_color, progress)
	current_color = current_color.lerp(target_color, clampf(delta * config.crosshair_color_lerp_speed, 0.0, 1.0))

	if recoil_active:
		if progress >= 0.999:
			recoil_rotation = 0.0
			recoil_active = false
		else:
			# Cooldown progress is the weapon's authoritative recovery clock.  It
			# makes the kick return to exactly zero as soon as the weapon is ready,
			# including during SUPERHOT time scaling.
			recoil_rotation = recoil_kick_rotation * (1.0 - progress)
	else:
		recoil_rotation = 0.0

	# CanvasItem retains its last draw commands. A ready, stationary weapon can
	# keep the same colour/recoil while the pointer, HUD mapping, ammo, or weapon changes.
	var draw_position := _world_to_ui(player.get_constrained_aim_position())
	var ammo: Dictionary = player.get_ammo_status()
	var draw_ammo := {
		"uses_ammo": ammo.get("uses_ammo", false) == true,
		"current": int(ammo.get("current", 0)),
		"capacity": int(ammo.get("capacity", 0)),
		"reloading": ammo.get("reloading", false) == true,
		"reload_progress": _get_reload_progress(ammo) if ammo.get("uses_ammo", false) == true and ammo.get("reloading", false) == true else 0.0
	}
	var current_shape := int(get_current_crosshair_shape())

	if current_color.is_equal_approx(_last_draw_color) and is_equal_approx(recoil_rotation, _last_draw_recoil) \
		and draw_position.is_equal_approx(_last_draw_position) and draw_ammo == _last_draw_ammo \
		and current_shape == _last_draw_shape:
		return

	_last_draw_color = current_color
	_last_draw_recoil = recoil_rotation
	_last_draw_position = draw_position
	_last_draw_ammo = draw_ammo
	_last_draw_shape = current_shape
	queue_redraw()


func _on_weapon_fired(_multiplier: float) -> void:
	# Compatibility fallback for a Player scene without the confirmed event.
	_trigger_recoil(_multiplier)


func _on_confirmed_projectile_fired() -> void:
	_trigger_recoil(1.0)


func _trigger_recoil(_multiplier: float = 1.0) -> void:
	recoil_kick_rotation = deg_to_rad(config.crosshair_recoil_angle_degrees if config else 45.0)
	recoil_rotation = recoil_kick_rotation
	recoil_active = true


func _draw() -> void:
	if not is_instance_valid(player):
		return
	# 准星位于 CanvasLayer 的屏幕坐标系，把瞄准点换算为屏幕坐标并对齐整数像素。
	var p_raw: Vector2 = _world_to_ui(player.get_constrained_aim_position())
	var p := Vector2i(roundi(p_raw.x), roundi(p_raw.y))

	var recoil_amount := 0.0
	if recoil_active and recoil_kick_rotation > 0.001:
		recoil_amount = (recoil_rotation / recoil_kick_rotation) * (config.crosshair_recoil_pixels if config else 5.0)

	var shape := get_current_crosshair_shape()
	var rects := _get_shape_pixel_rects(shape, p, recoil_amount)

	# Pass 1: 1px 像素风格纯黑描边
	var outline_color := Color.BLACK
	for rect in rects:
		draw_rect(Rect2(rect.position - Vector2i.ONE, rect.size + Vector2i(2, 2)), outline_color, true)

	# Pass 2: 内部主体像素颜色
	for rect in rects:
		draw_rect(Rect2(rect.position, rect.size), current_color, true)

	# 弹药状态与换弹进度条
	var ammo: Dictionary = player.get_ammo_status()
	if ammo.get("uses_ammo", false) == true:
		var ammo_position := Vector2(p.x + 14, p.y + 19)
		var reloading: bool = ammo.get("reloading", false) == true
		var ammo_color := Color(current_color, 0.55) if reloading else current_color
		var ammo_text := "%d / %d" % [int(ammo.get("current", 0)), int(ammo.get("capacity", 0))]
		# 黑色描边与主体文字
		draw_string_outline(PixelFont.get_font(), ammo_position, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, 2, Color.BLACK)
		draw_string(PixelFont.get_font(), ammo_position, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, ammo_color)
		if reloading:
			var reload_progress := _get_reload_progress(ammo)
			var bar_rect := Rect2((Vector2(p) + config.crosshair_reload_bar_offset).round(), Vector2(config.crosshair_reload_bar_width, config.crosshair_reload_bar_height))
			draw_rect(bar_rect.grow(1.0), Color.BLACK)
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * reload_progress, bar_rect.size.y)), current_color)


func _get_shape_pixel_rects(shape: CrosshairShape, center: Vector2i, recoil: float) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var cx := center.x
	var cy := center.y

	# 中心精准瞄准点 (2x2 像素)
	rects.append(Rect2i(cx - 1, cy - 1, 2, 2))

	match shape:
		CrosshairShape.SQUARE:
			# 近战武器 (Melee): 方形框架，匹配原版 9px 半径 (18-20px 跨度)
			var s: int = 9 + int(round(recoil))
			# 左上角
			rects.append(Rect2i(cx - s, cy - s, 5, 2))
			rects.append(Rect2i(cx - s, cy - s + 2, 2, 3))
			# 右上角
			rects.append(Rect2i(cx + s - 4, cy - s, 5, 2))
			rects.append(Rect2i(cx + s - 1, cy - s + 2, 2, 3))
			# 左下角
			rects.append(Rect2i(cx - s, cy + s - 1, 5, 2))
			rects.append(Rect2i(cx - s, cy + s - 4, 2, 3))
			# 右下角
			rects.append(Rect2i(cx + s - 4, cy + s - 1, 5, 2))
			rects.append(Rect2i(cx + s - 1, cy + s - 4, 2, 3))

		CrosshairShape.T_SHAPE:
			# 连发武器 (Automatic/Rapid-fire): T字形，原版 3px~9px 射线跨度，上方通透
			var g: int = 3 + int(round(recoil))
			var l: int = 6
			# 左横线 (2px 厚)
			rects.append(Rect2i(cx - g - l + 1, cy - 1, l, 2))
			# 右横线 (2px 厚)
			rects.append(Rect2i(cx + g, cy - 1, l, 2))
			# 下竖线 (2px 厚)
			rects.append(Rect2i(cx - 1, cy + g, 2, l))

		CrosshairShape.BRACKET:
			# 霰弹枪 (Shotgun): 左右扇形扩散括号 ( · )，18px 高度，外沿达 9px 半径
			var g: int = 8 + int(round(recoil * 1.3))
			# 左括号 '('
			rects.append(Rect2i(cx - g + 2, cy - 9, 3, 2))  # 顶端向内收
			rects.append(Rect2i(cx - g, cy - 7, 2, 3))      # 上弧
			rects.append(Rect2i(cx - g - 1, cy - 4, 2, 9))  # 中央立柱 (9px 高)
			rects.append(Rect2i(cx - g, cy + 5, 2, 3))      # 下弧
			rects.append(Rect2i(cx - g + 2, cy + 8, 3, 2))  # 底端向内收

			# 右括号 ')'
			rects.append(Rect2i(cx + g - 4, cy - 9, 3, 2))  # 顶端向内收
			rects.append(Rect2i(cx + g - 1, cy - 7, 2, 3))  # 上弧
			rects.append(Rect2i(cx + g, cy - 4, 2, 9))      # 中央立柱 (9px 高)
			rects.append(Rect2i(cx + g - 1, cy + 5, 2, 3))  # 下弧
			rects.append(Rect2i(cx + g - 4, cy + 8, 3, 2))  # 底端向内收

		CrosshairShape.CIRCLE:
			# 手枪及以后的狙击类武器 (Pistol / Precision): 像素圆环，外沿达 9px 半径
			var r: int = 8 + int(round(recoil))
			# 上下左右 4 轴弧段 (5px 宽/高, 2px 厚)
			rects.append(Rect2i(cx - 2, cy - r - 1, 5, 2)) # 上
			rects.append(Rect2i(cx - 2, cy + r, 5, 2))     # 下
			rects.append(Rect2i(cx - r - 1, cy - 2, 2, 5)) # 左
			rects.append(Rect2i(cx + r, cy - 2, 2, 5))     # 右
			# 四个对角连接过渡段
			rects.append(Rect2i(cx - r + 1, cy - r + 1, 2, 2)) # 左上
			rects.append(Rect2i(cx - r + 3, cy - r, 2, 1))
			rects.append(Rect2i(cx - r, cy - r + 3, 1, 2))

			rects.append(Rect2i(cx + r - 2, cy - r + 1, 2, 2)) # 右上
			rects.append(Rect2i(cx + r - 4, cy - r, 2, 1))
			rects.append(Rect2i(cx + r, cy - r + 3, 1, 2))

			rects.append(Rect2i(cx - r + 1, cy + r - 2, 2, 2)) # 左下
			rects.append(Rect2i(cx - r + 3, cy + r, 2, 1))
			rects.append(Rect2i(cx - r, cy + r - 4, 1, 2))

			rects.append(Rect2i(cx + r - 2, cy + r - 2, 2, 2)) # 右下
			rects.append(Rect2i(cx + r - 4, cy + r, 2, 1))
			rects.append(Rect2i(cx + r, cy + r - 4, 1, 2))

	return rects


func _get_reload_progress(ammo: Dictionary) -> float:
	var reload_duration := maxf(config.weapon_reload_duration if config else 1.2, 0.001)
	return clampf(1.0 - float(ammo.get("reload_left", reload_duration)) / reload_duration, 0.0, 1.0)


## 世界坐标 → 屏幕坐标：以相机实际屏幕中心为基准，乘相机缩放后平移到视口中心。
## 手动模式下瞄准点即鼠标世界坐标，换算后准星精确贴合鼠标位置。
func _world_to_ui(world_position: Vector2) -> Vector2:
	var world := _dream_world()
	if world != null and world.has_method("get_gameplay_aim_position"):
		return player.get_presentation_hud_position(player.get_presentation_pointer_position())
	var camera: Camera2D = player.get_node_or_null("DreamCamera")
	if camera == null:
		return world_position
	return (world_position - camera.get_screen_center_position()) * camera.zoom + get_viewport_rect().size * 0.5
