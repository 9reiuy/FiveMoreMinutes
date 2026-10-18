class_name PixelOptionGroup
extends Control

const CONFIG := preload("res://resources/demo_config.tres")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const OPTION_FRAME_TEXTURE := preload("res://art/icon/space-worm-theme/general/Blue.png")

@export var show_selection_frame := true
@export var enable_hover_scale := true

var _options: Array[Button] = []
var _connections: Dictionary = {}
var _button_tweens: Dictionary = {}
var _active_option: Button
var _frame_tween: Tween
var _frame_style := StyleBoxTexture.new()
var _triangle_anim_elapsed := 0.0

var _frame_position := Vector2.ZERO:
	set(value):
		_frame_position = value
		queue_redraw()
var _frame_size := Vector2.ZERO:
	set(value):
		_frame_size = value
		queue_redraw()
var _frame_alpha := 0.0:
	set(value):
		_frame_alpha = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style.texture = OPTION_FRAME_TEXTURE
	_frame_style.set_texture_margin_all(8.0)
	set_process(true)


func _process(delta: float) -> void:
	for option in _options:
		if is_instance_valid(option):
			option.mouse_default_cursor_shape = Control.CURSOR_ARROW if option.disabled else Control.CURSOR_POINTING_HAND
	if _active_option != null and (
		not is_instance_valid(_active_option)
		or not _active_option.is_visible_in_tree()
		or _active_option.disabled
	):
		clear_highlight()
	elif _active_option != null:
		_triangle_anim_elapsed += delta
		queue_redraw()


func register_options(new_options: Array[Button]) -> void:
	clear_options()
	for option in new_options:
		if not is_instance_valid(option):
			continue
		_options.append(option)
		_apply_plain_text_style(option)
		var entered := _on_option_entered.bind(option)
		var exited := _on_option_exited.bind(option)
		var focus_entered := _on_option_focus_entered.bind(option)
		var focus_exited := _on_option_focus_exited.bind(option)
		option.mouse_entered.connect(entered)
		option.mouse_exited.connect(exited)
		option.focus_entered.connect(focus_entered)
		option.focus_exited.connect(focus_exited)
		_connections[option.get_instance_id()] = {
			"entered": entered,
			"exited": exited,
			"focus_entered": focus_entered,
			"focus_exited": focus_exited,
		}


func clear_options() -> void:
	clear_highlight()
	for option in _options:
		if not is_instance_valid(option):
			continue
		var callbacks: Dictionary = _connections.get(option.get_instance_id(), {})
		_disconnect_if_connected(option.mouse_entered, callbacks.get("entered", Callable()))
		_disconnect_if_connected(option.mouse_exited, callbacks.get("exited", Callable()))
		_disconnect_if_connected(option.focus_entered, callbacks.get("focus_entered", Callable()))
		_disconnect_if_connected(option.focus_exited, callbacks.get("focus_exited", Callable()))
		option.scale = Vector2.ONE
	_options.clear()
	_connections.clear()
	_button_tweens.clear()


func clear_highlight() -> void:
	_active_option = null
	_triangle_anim_elapsed = 0.0
	_kill_frame_tween()
	for option in _options:
		if is_instance_valid(option):
			_kill_button_tween(option)
			option.scale = Vector2.ONE
	_frame_alpha = 0.0


func _apply_plain_text_style(option: Button) -> void:
	option.flat = true
	option.mouse_default_cursor_shape = Control.CURSOR_ARROW if option.disabled else Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		option.add_theme_stylebox_override(state, empty)


func _on_option_entered(option: Button) -> void:
	if option.disabled or not option.is_visible_in_tree():
		option.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	_activate(option, true)


func _on_option_exited(option: Button) -> void:
	_set_option_scale(option, Vector2.ONE)
	call_deferred("_refresh_active_option")


func _on_option_focus_entered(option: Button) -> void:
	if not option.disabled and option.is_visible_in_tree():
		_activate(option, false)


func _on_option_focus_exited(option: Button) -> void:
	_set_option_scale(option, Vector2.ONE)
	call_deferred("_refresh_active_option")


func _refresh_active_option() -> void:
	for option in _options:
		if not is_instance_valid(option) or option.disabled or not option.is_visible_in_tree():
			continue
		if option.is_hovered() or option.has_focus():
			_activate(option, false)
			return
	_fade_out()


func _activate(option: Button, play_sound: bool) -> void:
	if _active_option == option:
		return
	_active_option = option
	# Triangle motion is local to the current frame. Restarting it here avoids a
	# stale offset while the shared SelectionFrame slides to a different option.
	_triangle_anim_elapsed = 0.0
	if play_sound:
		SFX.play_event(&"ui_hover")
	for other in _options:
		if is_instance_valid(other) and other != option:
			_set_option_scale(other, Vector2.ONE)
	_set_option_pivot(option)
	_set_option_scale(option, Vector2.ONE * (CONFIG.option_hover_scale if enable_hover_scale else 1.0))
	_move_frame_to(option)


func _set_option_scale(option: Button, target: Vector2) -> void:
	if enable_hover_scale:
		_animate_option_scale(option, target)
	else:
		_kill_button_tween(option)
		option.scale = Vector2.ONE


func _set_option_pivot(option: Button) -> void:
	if bool(option.get_meta(&"pixel_option_center_pivot", false)):
		option.pivot_offset = option.size * 0.5
		return
	match option.alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			option.pivot_offset = Vector2(0.0, option.size.y * 0.5)
		HORIZONTAL_ALIGNMENT_RIGHT:
			option.pivot_offset = Vector2(option.size.x, option.size.y * 0.5)
		_:
			option.pivot_offset = option.size * 0.5


func _animate_option_scale(option: Button, target: Vector2) -> void:
	if not is_instance_valid(option):
		return
	_kill_button_tween(option)
	var tween := option.create_tween()
	_button_tweens[option.get_instance_id()] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(option, "scale", target, minf(CONFIG.option_hover_tween_duration, 0.10))


func _kill_button_tween(option: Button) -> void:
	var existing: Variant = _button_tweens.get(option.get_instance_id())
	if existing is Tween and existing.is_valid():
		existing.kill()
	_button_tweens.erase(option.get_instance_id())


func _move_frame_to(option: Button) -> void:
	var target := _target_rect(option)
	_kill_frame_tween()
	if _frame_alpha <= 0.001:
		_frame_position = target.position
		_frame_size = target.size
	_frame_tween = create_tween().set_parallel(true)
	_frame_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(self, "_frame_position", target.position, CONFIG.option_hover_tween_duration)
	_frame_tween.tween_property(self, "_frame_size", target.size, CONFIG.option_hover_tween_duration)
	_frame_tween.tween_property(self, "_frame_alpha", 1.0, minf(CONFIG.option_hover_tween_duration, 0.12))


func _target_rect(option: Button) -> Rect2:
	var visual_scale := CONFIG.option_hover_scale if enable_hover_scale else 1.0
	var text_size := _measure_button_text(option) * visual_scale
	var option_global := option.get_global_rect()
	var host_global := get_global_rect()
	var text_left_global: float
	match option.alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			var normal_style := option.get_theme_stylebox(&"normal")
			text_left_global = option_global.position.x + normal_style.get_content_margin(SIDE_LEFT)
		HORIZONTAL_ALIGNMENT_RIGHT:
			text_left_global = option_global.end.x - text_size.x
		_:
			text_left_global = option_global.get_center().x - text_size.x * 0.5
	var content_width := CONFIG.option_triangle_size + CONFIG.option_triangle_text_gap + text_size.x
	var target_size := Vector2(
		ceilf(content_width + CONFIG.option_frame_padding.x * 2.0),
		ceilf(maxf(text_size.y, CONFIG.option_triangle_size) + CONFIG.option_frame_padding.y * 2.0)
	)
	# Control没有Node2D.to_local()。两个Control的Global Rect相减，得到本组件坐标中的目标Rect。
	var target_position := Vector2(
		text_left_global - CONFIG.option_triangle_size - CONFIG.option_triangle_text_gap - CONFIG.option_frame_padding.x - host_global.position.x,
		option_global.get_center().y - target_size.y * 0.5 - host_global.position.y
	)
	return Rect2(target_position.round(), target_size)


func _measure_button_text(option: Button) -> Vector2:
	var font := option.get_theme_font(&"font")
	var font_size := option.get_theme_font_size(&"font_size")
	var width := 0.0
	var lines := option.text.split("\n")
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return Vector2(width, font.get_height(font_size) * maxf(1.0, float(lines.size())))


func _fade_out() -> void:
	_active_option = null
	_triangle_anim_elapsed = 0.0
	_kill_frame_tween()
	_frame_tween = create_tween()
	_frame_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(self, "_frame_alpha", 0.0, minf(CONFIG.option_hover_tween_duration, 0.10))


func _kill_frame_tween() -> void:
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()


func _disconnect_if_connected(signal_value: Signal, callback: Callable) -> void:
	if callback.is_valid() and signal_value.is_connected(callback):
		signal_value.disconnect(callback)


func _draw() -> void:
	if _frame_alpha <= 0.001 or _frame_size.x <= 0.0 or _frame_size.y <= 0.0:
		return
	_frame_style.modulate_color = Color(1.0, 1.0, 1.0, _frame_alpha)
	var frame_rect := Rect2(_frame_position, _frame_size)
	if show_selection_frame:
		draw_style_box(_frame_style, frame_rect)
	var triangle_center := Vector2(
		frame_rect.position.x + CONFIG.option_frame_padding.x + CONFIG.option_triangle_size * 0.5 + triangle_animation_offset(_triangle_anim_elapsed),
		frame_rect.get_center().y
	)
	var half := CONFIG.option_triangle_size * 0.5
	draw_colored_polygon(PackedVector2Array([
		triangle_center + Vector2(-half, -half),
		triangle_center + Vector2(-half, half),
		triangle_center + Vector2(half, 0.0),
	]), Color(CONFIG.option_triangle_color, CONFIG.option_triangle_color.a * _frame_alpha))


static func triangle_animation_offset(elapsed: float) -> float:
	var period := maxf(CONFIG.option_triangle_animation_period, 0.001)
	# Cosine produces a curved base -> right -> base loop without ever writing
	# the SelectionFrame/anchor position animated by the frame tween.
	var phase := fmod(maxf(elapsed, 0.0), period) / period
	return (1.0 - cos(phase * TAU)) * 0.5 * CONFIG.option_triangle_animation_amplitude


static func draw_custom_option(
	canvas: CanvasItem,
	hit_rect: Rect2,
	text: String,
	hovered: bool,
	enabled: bool,
	font: Font,
	font_size: int,
	triangle_anim_elapsed: float = 0.0
) -> void:
	var draw_size := maxi(1, roundi(float(font_size) * (CONFIG.option_hover_scale if hovered and enabled else 1.0)))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size)
	var text_color := Color("d5dde0") if enabled else Color("56616a")
	if hovered and enabled:
		var width := text_size.x + CONFIG.option_triangle_size + CONFIG.option_triangle_text_gap + CONFIG.option_frame_padding.x * 2.0
		var height := maxf(text_size.y, CONFIG.option_triangle_size) + CONFIG.option_frame_padding.y * 2.0
		var text_left := hit_rect.get_center().x - text_size.x * 0.5
		var frame_rect := Rect2(
			Vector2(
				text_left - CONFIG.option_triangle_size - CONFIG.option_triangle_text_gap - CONFIG.option_frame_padding.x,
				hit_rect.get_center().y - height * 0.5
			).round(),
			Vector2(width, height).round()
		)
		var style := StyleBoxTexture.new()
		style.texture = OPTION_FRAME_TEXTURE
		style.set_texture_margin_all(8.0)
		canvas.draw_style_box(style, frame_rect)
		var triangle_center := Vector2(
			frame_rect.position.x + CONFIG.option_frame_padding.x + CONFIG.option_triangle_size * 0.5 + triangle_animation_offset(triangle_anim_elapsed),
			frame_rect.get_center().y
		)
		var half := CONFIG.option_triangle_size * 0.5
		canvas.draw_colored_polygon(PackedVector2Array([
			triangle_center + Vector2(-half, -half),
			triangle_center + Vector2(-half, half),
			triangle_center + Vector2(half, 0.0),
		]), CONFIG.option_triangle_color)
	canvas.draw_string(
		font,
		Vector2(hit_rect.position.x, hit_rect.get_center().y + text_size.y * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		hit_rect.size.x,
		draw_size,
		text_color
	)
