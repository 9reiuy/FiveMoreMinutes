extends Control

## Pure solid-color flat vector crosshair rendered via SDF anti-aliasing.
## Replaces the legacy pixel-block reticle while retaining the exact runtime API.

const CROSSHAIR_SHADER: Shader = preload("res://shaders/ui/solid_crosshair.gdshader")
const SURFACE_SIZE := Vector2(72.0, 72.0)

var _cached_dream_world: Node
@export var config: DemoConfig
@export var style_variant: StyleVariant = StyleVariant.HAIRLINE_WHITE:
	set(value):
		style_variant = value
		_last_draw_style = -1
		_apply_style_to_material()
		queue_redraw()

var player: Node
var current_color := Color.WHITE
var recoil_rotation := 0.0
var recoil_kick_rotation := 0.0
var recoil_active := false
var throw_aim_weight := 0.0
var _reload_was_active := false
var _reload_complete_flash := 0.0

var _surface: ColorRect
var _material: ShaderMaterial

var _last_draw_color := Color(-1, -1, -1, -1)
var _last_draw_recoil := INF
var _last_draw_position := Vector2(INF, INF)
var _last_draw_ammo: Dictionary = {}
var _last_draw_shape: int = -1
var _last_draw_style: int = -1
var _last_draw_throw := -1.0
var _last_draw_flash := -1.0

static var _shared_ammo_font: SystemFont

enum CrosshairShape {
	SQUARE,   ## 近战武器 (Melee: lucille, books, fist)
	T_SHAPE,  ## 连发武器 (Automatic / Rapid-fire: assault_rifle, mp5, smg)
	BRACKET,  ## 霰弹枪 (Shotgun: shotgun, sawed_off)
	CIRCLE,   ## 手枪或以后的狙击类武器 (Pistol / Sniper: basic)
}

enum StyleVariant {
	HAIRLINE_WHITE,       ## A · 微衬纯白（极细深色防走光背衬，全地形清晰）
	PURE_FLAT_WHITE,      ## B · 纯净无边纯白
	DUAL_ACCENT_CRIMSON,  ## C · 纯白外框 + 警示红芯
	PURE_FLAT_CRIMSON,    ## D · 纯净无边信号红
}


static func _get_ammo_font() -> SystemFont:
	if _shared_ammo_font == null:
		_shared_ammo_font = SystemFont.new()
		_shared_ammo_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Microsoft YaHei UI", "Noto Sans", "DejaVu Sans"])
		_shared_ammo_font.font_weight = 700
		_shared_ammo_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_shared_ammo_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return _shared_ammo_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_visuals()


func _ensure_visuals() -> void:
	if _surface == null:
		_material = ShaderMaterial.new()
		_material.shader = CROSSHAIR_SHADER
		_material.set_shader_parameter(&"canvas_size", SURFACE_SIZE)
		_surface = ColorRect.new()
		_surface.name = "ReticleSurface"
		_surface.size = SURFACE_SIZE
		_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_surface.material = _material
		_surface.visible = false
		add_child(_surface)
	_apply_style_to_material()


func _dream_world() -> Node:
	if is_instance_valid(_cached_dream_world):
		return _cached_dream_world
	if not is_inside_tree():
		return null
	_cached_dream_world = get_tree().get_first_node_in_group(&"dream_world")
	return _cached_dream_world


func configure(target: Node) -> void:
	_ensure_visuals()
	player = target
	# The confirmed event is emitted only after a formal firearm actually
	# spawned its projectile(s).  Keep the legacy signal as a compatibility
	# fallback for older Player scenes that do not expose that event.
	if target.has_signal("confirmed_projectile_fired") and not target.confirmed_projectile_fired.is_connected(_on_confirmed_projectile_fired):
		target.confirmed_projectile_fired.connect(_on_confirmed_projectile_fired)
	elif target.has_signal("weapon_fired") and not target.weapon_fired.is_connected(_on_weapon_fired):
		target.weapon_fired.connect(_on_weapon_fired)
	if target.has_signal("active_weapon_changed") and not target.active_weapon_changed.is_connected(_on_active_weapon_changed):
		target.active_weapon_changed.connect(_on_active_weapon_changed)
	if config != null:
		current_color = config.crosshair_ready_color
	_last_draw_shape = -1
	_surface.visible = is_instance_valid(player)
	queue_redraw()


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
	if DreamGunAtlas.get_category(weapon_id) == DreamGunAtlas.CATEGORY_MELEE:
		return CrosshairShape.SQUARE
	match weapon_id:
		"lucille", "books":
			return CrosshairShape.SQUARE
		"assault_rifle", "mp5", "smg", "machine_gun", "rifle":
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
	_ensure_visuals()
	if not is_instance_valid(player):
		_surface.visible = false
		return
	_surface.visible = true

	var cooldown_color := config.crosshair_cooldown_color if config != null else Color(0.35, 0.36, 0.4, 1.0)
	var ready_color := config.crosshair_ready_color if config != null else Color.WHITE
	var lerp_speed := config.crosshair_color_lerp_speed if config != null else 10.0

	var progress: float = clampf(float(player.get_weapon_cooldown_progress()), 0.0, 1.0)
	var target_color := cooldown_color.lerp(ready_color, progress)
	current_color = current_color.lerp(target_color, clampf(delta * lerp_speed, 0.0, 1.0))

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

	var throw_active := false
	if player.has_method("is_throw_aim_active"):
		throw_active = bool(player.call("is_throw_aim_active"))
	var target_throw := 1.0 if throw_active else 0.0
	throw_aim_weight = lerpf(throw_aim_weight, target_throw, clampf(delta * 18.0, 0.0, 1.0))
	if absf(throw_aim_weight - target_throw) < 0.01:
		throw_aim_weight = target_throw

	# CanvasItem retains its last draw commands. A ready, stationary weapon can
	# keep the same colour/recoil while the pointer, HUD mapping, ammo, or weapon changes.
	var draw_position := _world_to_ui(player.get_constrained_aim_position())
	var ammo: Dictionary = player.get_ammo_status()
	var is_reloading := bool(ammo.get("uses_ammo", false)) and bool(ammo.get("reloading", false))
	if _reload_was_active and not is_reloading:
		_reload_complete_flash = 1.0
	_reload_was_active = is_reloading
	if _reload_complete_flash > 0.0:
		_reload_complete_flash = maxf(0.0, _reload_complete_flash - delta * 6.0)

	var draw_ammo := {
		"uses_ammo": bool(ammo.get("uses_ammo", false)),
		"current": int(ammo.get("current", 0)),
		"capacity": int(ammo.get("capacity", 0)),
		"reloading": is_reloading,
		"reload_progress": _get_reload_progress(ammo) if is_reloading else 0.0,
	}
	var current_shape := int(get_current_crosshair_shape())
	var recoil_px := _compute_recoil_pixels()

	_sync_surface_and_material(draw_position, current_shape, recoil_px, draw_ammo, throw_aim_weight)

	if current_color.is_equal_approx(_last_draw_color) and is_equal_approx(recoil_rotation, _last_draw_recoil) \
		and draw_position.is_equal_approx(_last_draw_position) and draw_ammo == _last_draw_ammo \
		and current_shape == _last_draw_shape and int(style_variant) == _last_draw_style \
		and is_equal_approx(throw_aim_weight, _last_draw_throw) \
		and is_equal_approx(_reload_complete_flash, _last_draw_flash):
		return

	_last_draw_color = current_color
	_last_draw_recoil = recoil_rotation
	_last_draw_position = draw_position
	_last_draw_ammo = draw_ammo
	_last_draw_shape = current_shape
	_last_draw_style = int(style_variant)
	_last_draw_throw = throw_aim_weight
	_last_draw_flash = _reload_complete_flash
	queue_redraw()


func _compute_recoil_pixels() -> float:
	if not recoil_active or recoil_kick_rotation <= 0.001:
		return 0.0
	var max_px := config.crosshair_recoil_pixels if config != null else 5.0
	return (recoil_rotation / recoil_kick_rotation) * max_px


func _on_weapon_fired(_multiplier: float) -> void:
	# Compatibility fallback for a Player scene without the confirmed event.
	_trigger_recoil(_multiplier)


func _on_confirmed_projectile_fired() -> void:
	_trigger_recoil(1.0)


func _trigger_recoil(_multiplier: float = 1.0) -> void:
	recoil_kick_rotation = deg_to_rad(config.crosshair_recoil_angle_degrees if config != null else 45.0)
	recoil_rotation = recoil_kick_rotation
	recoil_active = true


func _resolve_colors(ammo: Dictionary) -> Dictionary:
	var uses_ammo := bool(ammo.get("uses_ammo", false))
	var current_ammo := int(ammo.get("current", 0))
	var capacity := maxi(int(ammo.get("capacity", 1)), 1)
	var is_reloading := bool(ammo.get("reloading", false))
	var is_empty := uses_ammo and current_ammo <= 0 and not is_reloading
	var is_low := uses_ammo and not is_reloading and current_ammo > 0 and float(current_ammo) / float(capacity) <= 0.25

	var crimson := Color("eb3b4b")
	var pure_crimson := Color("f03a47")
	var reticle_col := current_color
	var pip_col := Color.WHITE
	var ammo_col := current_color
	var reload_col := Color.WHITE

	match style_variant:
		StyleVariant.HAIRLINE_WHITE:
			reticle_col = crimson if is_empty else current_color
			pip_col = crimson if is_empty else Color.WHITE
			ammo_col = crimson if (is_empty or is_low) else current_color
			reload_col = Color.WHITE
		StyleVariant.PURE_FLAT_WHITE:
			reticle_col = crimson if is_empty else current_color
			pip_col = crimson if is_empty else Color.WHITE
			ammo_col = crimson if (is_empty or is_low) else current_color
			reload_col = Color.WHITE
		StyleVariant.DUAL_ACCENT_CRIMSON:
			reticle_col = crimson if is_empty else current_color
			pip_col = crimson
			ammo_col = crimson if (is_empty or is_low) else current_color
			reload_col = Color.WHITE
		StyleVariant.PURE_FLAT_CRIMSON:
			var ready_ratio := clampf((current_color.r + current_color.g + current_color.b) / 3.0, 0.35, 1.0)
			reticle_col = Color(pure_crimson.r * ready_ratio, pure_crimson.g * ready_ratio, pure_crimson.b * ready_ratio, 1.0)
			pip_col = pure_crimson
			ammo_col = pure_crimson if (is_empty or is_low) else reticle_col
			reload_col = pure_crimson

	if _reload_complete_flash > 0.01:
		reticle_col = reticle_col.lerp(Color.WHITE, _reload_complete_flash * 0.6)

	return {
		"reticle": reticle_col,
		"pip": pip_col,
		"ammo": ammo_col,
		"reload": reload_col,
	}


func _apply_style_to_material() -> void:
	if _material == null:
		return
	var use_outline := style_variant == StyleVariant.HAIRLINE_WHITE or style_variant == StyleVariant.DUAL_ACCENT_CRIMSON
	_material.set_shader_parameter(&"outline_width", 0.50 if use_outline else 0.0)
	_material.set_shader_parameter(&"outline_color", Color(0.035, 0.047, 0.075, 0.85))
	_material.set_shader_parameter(&"reload_track_color", Color(0.04, 0.055, 0.085, 0.54))


func _sync_surface_and_material(center: Vector2, shape: int, recoil_px: float, ammo: Dictionary, throw_amount: float) -> void:
	if _surface == null or _material == null:
		return
	_surface.position = center - SURFACE_SIZE * 0.5
	var colors := _resolve_colors(ammo)
	_material.set_shader_parameter(&"shape_type", shape)
	_material.set_shader_parameter(&"recoil_px", recoil_px + _reload_complete_flash * 1.4)
	_material.set_shader_parameter(&"throw_aim", throw_amount)
	_material.set_shader_parameter(&"reticle_color", colors.reticle)
	_material.set_shader_parameter(&"pip_color", colors.pip)
	_material.set_shader_parameter(&"reloading", 1.0 if bool(ammo.get("reloading", false)) else 0.0)
	_material.set_shader_parameter(&"reload_progress", float(ammo.get("reload_progress", 0.0)))
	_material.set_shader_parameter(&"reload_fill_color", colors.reload)


func _draw() -> void:
	_ensure_visuals()
	if not is_instance_valid(player):
		return
	var center := _world_to_ui(player.get_constrained_aim_position())
	var raw_ammo: Dictionary = player.get_ammo_status()
	var is_reloading := bool(raw_ammo.get("uses_ammo", false)) and bool(raw_ammo.get("reloading", false))
	var ammo := {
		"uses_ammo": bool(raw_ammo.get("uses_ammo", false)),
		"current": int(raw_ammo.get("current", 0)),
		"capacity": int(raw_ammo.get("capacity", 0)),
		"reloading": is_reloading,
		"reload_progress": _get_reload_progress(raw_ammo) if is_reloading else 0.0,
	}

	if not bool(ammo.get("uses_ammo", false)):
		return

	var colors := _resolve_colors(ammo)
	var ammo_col: Color = colors.ammo
	if is_reloading:
		ammo_col.a *= 0.65

	var font := _get_ammo_font()
	var ammo_text := "%d / %d" % [int(ammo.get("current", 0)), int(ammo.get("capacity", 0))]
	var text_pos := center + Vector2(13.0, 18.0)
	var use_outline := style_variant == StyleVariant.HAIRLINE_WHITE or style_variant == StyleVariant.DUAL_ACCENT_CRIMSON
	if use_outline:
		draw_string_outline(font, text_pos, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, 2, Color(0.035, 0.047, 0.075, 0.78 * ammo_col.a))
	draw_string(font, text_pos, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, ammo_col)


func _get_reload_progress(ammo: Dictionary) -> float:
	var reload_duration := maxf(config.weapon_reload_duration if config != null else 0.75, 0.001)
	return clampf(1.0 - float(ammo.get("reload_left", reload_duration)) / reload_duration, 0.0, 1.0)


## 世界坐标 → 屏幕坐标：以相机实际屏幕中心为基准，乘相机缩放后平移到视口中心。
## 手动模式下瞄准点即鼠标世界坐标，换算后准星精确贴合鼠标位置。
func _world_to_ui(world_position: Vector2) -> Vector2:
	var world := _dream_world()
	if world != null and world.has_method("get_gameplay_aim_position") and player.has_method("get_presentation_hud_position"):
		return player.get_presentation_hud_position(player.get_presentation_pointer_position())
	var camera: Camera2D = player.get_node_or_null("DreamCamera")
	if camera == null:
		return world_position
	return (world_position - camera.get_screen_center_position()) * camera.zoom + get_viewport_rect().size * 0.5
