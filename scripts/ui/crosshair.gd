extends Control
@export var config: DemoConfig
var player: Node
var current_color := Color.GRAY
var recoil_rotation := 0.0
var recoil_kick_rotation := 0.0
var recoil_active := false
var _last_draw_color := Color(-1, -1, -1, -1)
var _last_draw_recoil := INF


func configure(target: Node) -> void:
	player = target
	# The confirmed event is emitted only after a formal firearm actually
	# spawned its projectile(s).  Keep the legacy signal as a compatibility
	# fallback for older Player scenes that do not expose that event.
	if target.has_signal("confirmed_projectile_fired"):
		target.confirmed_projectile_fired.connect(_on_confirmed_projectile_fired)
	elif target.has_signal("weapon_fired"):
		target.weapon_fired.connect(_on_weapon_fired)


func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var progress: float = clampf(float(player.get_weapon_cooldown_progress()), 0.0, 1.0)
	var target_color := config.crosshair_cooldown_color.lerp(config.crosshair_ready_color, progress)
	current_color = current_color.lerp(target_color, clampf(delta * config.crosshair_color_lerp_speed,0,1))
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
	if current_color.is_equal_approx(_last_draw_color) and is_equal_approx(recoil_rotation, _last_draw_recoil):
		return
	_last_draw_color = current_color
	_last_draw_recoil = recoil_rotation
	queue_redraw()


func _on_weapon_fired(_multiplier: float) -> void:
	# Compatibility fallback for a Player scene without the confirmed event.
	_trigger_recoil(_multiplier)


func _on_confirmed_projectile_fired() -> void:
	_trigger_recoil(1.0)


func _trigger_recoil(_multiplier: float = 1.0) -> void:
	recoil_kick_rotation = deg_to_rad(config.crosshair_recoil_angle_degrees)
	recoil_rotation = recoil_kick_rotation
	recoil_active = true


func _draw() -> void:
	if not is_instance_valid(player):
		return
	# 准星位于 CanvasLayer 的屏幕坐标系，必须把瞄准点世界坐标换算为屏幕坐标，
	# 否则会随相机/玩家移动漂移（不再跟随 WASD/相机）。
	var p: Vector2 = _world_to_ui(player.get_constrained_aim_position())
	var axis_x := Vector2.RIGHT.rotated(recoil_rotation)
	var axis_y := axis_x.orthogonal()
	draw_line(p-axis_x*9.0,p-axis_x*3.0,current_color,2)
	draw_line(p+axis_x*3.0,p+axis_x*9.0,current_color,2)
	draw_line(p-axis_y*9.0,p-axis_y*3.0,current_color,2)
	draw_line(p+axis_y*3.0,p+axis_y*9.0,current_color,2)
	draw_circle(p,2,current_color,false,1)
	var ammo: Dictionary = player.get_ammo_status()
	if ammo.get("uses_ammo", false) == true:
		var ammo_position := p + Vector2(12.0, 18.0)
		var reloading: bool = ammo.get("reloading", false) == true
		var ammo_color := Color(current_color, 0.55) if reloading else current_color
		var ammo_text := "%d / %d" % [int(ammo.get("current", 0)), int(ammo.get("capacity", 0))]
		draw_string(PixelFont.get_font(), ammo_position, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, ammo_color)
		if reloading:
			var reload_progress := _get_reload_progress(ammo)
			var bar_rect := Rect2((p + config.crosshair_reload_bar_offset).round(), Vector2(config.crosshair_reload_bar_width, config.crosshair_reload_bar_height))
			draw_rect(bar_rect.grow(1.0), Color(0.02, 0.04, 0.07, 0.88))
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * reload_progress, bar_rect.size.y)), current_color)


func _get_reload_progress(ammo: Dictionary) -> float:
	var reload_duration := maxf(config.weapon_reload_duration, 0.001)
	return clampf(1.0 - float(ammo.get("reload_left", reload_duration)) / reload_duration, 0.0, 1.0)


## 世界坐标 → 屏幕坐标：以相机实际屏幕中心为基准，乘相机缩放后平移到视口中心。
## 手动模式下瞄准点即鼠标世界坐标，换算后准星精确贴合鼠标位置。
func _world_to_ui(world_position: Vector2) -> Vector2:
	var world := get_tree().get_first_node_in_group(&"dream_world")
	if world != null and world.has_method("get_gameplay_aim_position"):
		return player.get_presentation_hud_position(player.get_presentation_pointer_position())
	var camera: Camera2D = player.get_node_or_null("DreamCamera")
	if camera == null:
		return world_position
	return (world_position - camera.get_screen_center_position()) * camera.zoom + get_viewport_rect().size * 0.5
