class_name PixelOptionGroup
extends Control

signal confirm_spring_finished
## Emitted when the active row changes (hover / keyboard / back restore).
signal selection_changed(option: Button)

const CONFIG := preload("res://resources/demo_config.tres")
const SFX := preload("res://scripts/audio/sfx_manager.gd")
const OPTION_FRAME_TEXTURE := preload("res://art/icon/space-worm-theme/general/Blue.png")

@export var show_selection_frame := true
@export var enable_hover_scale := true
## NieR-style list: solid accent fill + inverted selected text. Off by default so
## opening/results/confirmation/upgrade keep the legacy Blue.png chrome.
@export var solid_fill := false
@export var selected_text_color := Color("f2efe6")
@export var unselected_text_color := Color("396fe2")
## Settled highlight width for solid_fill. 0 = auto shared settle from longest selectable label.
@export var option_frame_fixed_width := 0.0
## Vertical pad for solid NieR fill only. 0 = ink-hug (avoid bleeding into neighbor rows).
@export_range(0.0, 6.0, 0.5) var option_frame_solid_v_pad := 0.0
## Progress-bar spring duration (fill L→R → overshoot → soft settle). ~ref 0.18–0.22s.
@export_range(0.06, 0.35, 0.01) var option_frame_spring_duration := 0.12
## Start fill as fraction of settle (~ref 15/121 ≈ 0.12). Thin stub, not a half bar.
@export_range(0.05, 0.40, 0.01) var option_frame_spring_start_scale := 0.20
## Peak fill / settle (~ref 146/121 ≈ 1.21). Soft retract after overshoot.
@export_range(1.05, 1.40, 0.01) var option_frame_spring_overshoot := 1.20
## Label scale_x peak (options spring). Milder than the bar so text stays readable.
@export_range(1.02, 1.25, 0.01) var option_text_spring_overshoot := 1.12
## Label scale_x start (options spring). Not the bar stub width — keep text visible.
@export_range(0.50, 0.95, 0.01) var option_text_spring_start_scale := 0.82

var _options: Array[Button] = []
var _connections: Dictionary = {}
var _button_tweens: Dictionary = {}
var _text_tweens: Dictionary = {}
var _active_option: Button
var _frame_tween: Tween
var _frame_style := StyleBoxTexture.new()
var _triangle_anim_elapsed := 0.0
## True while a confirm/click width+text spring is running. clear_highlight waits.
var _confirm_spring_busy := false
var _pending_clear_highlight := false

## When true, hover/focus refresh will not move the selection chrome.
var _hover_suppressed := false

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
## Horizontal expand factor for solid_fill spring (1.0 = settled). May overshoot > 1.
var _frame_expand := 1.0:
	set(value):
		_frame_expand = value
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
	elif _active_option != null and not solid_fill:
		# Legacy Blue.png triangle bob only. Solid NieR triangle stays fixed.
		_triangle_anim_elapsed += delta
		queue_redraw()
	elif solid_fill and (_confirm_spring_busy or absf(_frame_expand - 1.0) > 0.001):
		# Progress-bar fill must redraw every frame while expanding / retracting.
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
		var pressed := _on_option_pressed.bind(option)
		option.mouse_entered.connect(entered)
		option.mouse_exited.connect(exited)
		option.focus_entered.connect(focus_entered)
		option.focus_exited.connect(focus_exited)
		if not option.pressed.is_connected(pressed):
			option.pressed.connect(pressed)
		_connections[option.get_instance_id()] = {
			"entered": entered,
			"exited": exited,
			"focus_entered": focus_entered,
			"focus_exited": focus_exited,
			"pressed": pressed,
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
		_disconnect_if_connected(option.pressed, callbacks.get("pressed", Callable()))
		_kill_text_tween(option)
		option.scale = Vector2.ONE
	_options.clear()
	_connections.clear()
	_button_tweens.clear()
	_text_tweens.clear()


func clear_highlight() -> void:
	# Menu handlers often clear on the same pressed frame that starts the spring.
	# Defer so the left-anchored click spring can finish (~0.11s) in real menus.
	if _confirm_spring_busy:
		_pending_clear_highlight = true
		return
	_pending_clear_highlight = false
	_active_option = null
	_triangle_anim_elapsed = 0.0
	_frame_expand = 1.0
	_kill_frame_tween()
	for option in _options:
		if is_instance_valid(option):
			_kill_button_tween(option)
			_kill_text_tween(option)
			option.scale = Vector2.ONE
			_apply_option_text_color(option, false)
	_frame_alpha = 0.0
	_frame_position = Vector2.ZERO
	_frame_size = Vector2.ZERO


func _apply_plain_text_style(option: Button) -> void:
	option.flat = true
	option.mouse_default_cursor_shape = Control.CURSOR_ARROW if option.disabled else Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		option.add_theme_stylebox_override(state, empty)


func set_hover_suppressed(suppressed: bool) -> void:
	_hover_suppressed = suppressed


func _on_option_entered(option: Button) -> void:
	if _hover_suppressed:
		return
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


func _on_option_pressed(option: Button) -> void:
	if option.disabled or not option.is_visible_in_tree():
		return
	if _active_option != option:
		_activate(option, false)
	_play_confirm_spring(option)


func _refresh_active_option() -> void:
	if _hover_suppressed:
		return
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
	_triangle_anim_elapsed = 0.0
	selection_changed.emit(option)
	if play_sound:
		SFX.play_event(&"watch_tick")
	for other in _options:
		if not is_instance_valid(other):
			continue
		if other != option:
			_set_option_scale(other, Vector2.ONE)
			_kill_text_tween(other)
			if solid_fill:
				other.scale = Vector2.ONE
		_apply_option_text_color(other, other == option)
	_set_option_pivot(option)
	_set_option_scale(option, Vector2.ONE * (CONFIG.option_hover_scale if enable_hover_scale else 1.0))
	# Solid NieR: spring on every selection change (hover / keyboard / back restore).
	# Legacy chrome: soft move without width spring.
	if solid_fill:
		_play_selection_spring(option)
	else:
		_move_frame_to(option, false)


func _set_option_scale(option: Button, target: Vector2) -> void:
	if solid_fill:
		# Solid path owns scale for the confirm text spring; don't fight it with hover scale.
		return
	if enable_hover_scale:
		_animate_option_scale(option, target)
	else:
		_kill_button_tween(option)
		option.scale = Vector2.ONE


func _set_option_pivot(option: Button) -> void:
	if solid_fill:
		# Left-anchored so confirm spring expands text to the right with the fill.
		option.pivot_offset = Vector2(0.0, option.size.y * 0.5)
		return
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


func _kill_text_tween(option: Button) -> void:
	var existing: Variant = _text_tweens.get(option.get_instance_id())
	if existing is Tween and existing.is_valid():
		existing.kill()
	_text_tweens.erase(option.get_instance_id())


func _move_frame_to(option: Button, with_spring: bool) -> void:
	# Skip pre-layout / zero rects — writing (0,0) made the NieR bar flash at viewport TL.
	var option_global := option.get_global_rect()
	if option_global.size.x < 0.5 or option_global.size.y < 0.5:
		return
	var target := _target_rect(option)
	if target.size.x < 0.5 or target.size.y < 0.5:
		return
	_kill_frame_tween()
	if solid_fill:
		# Progress-bar model: Y + left X snap; width = settle * expand.
		# Keep alpha 0 until geometry is set so expand-first never draws at Vector2.ZERO.
		_frame_alpha = 0.0
		_frame_position = target.position
		_frame_size = target.size
		if with_spring:
			_frame_expand = option_frame_spring_start_scale
		else:
			_frame_expand = 1.0
		_frame_alpha = 1.0
		if with_spring:
			# Fill uses EASE_IN so early frames stay near the 20% stub (EASE_OUT looked like ~80% immediately).
			var expand_dur := maxf(option_frame_spring_duration * 0.55, 0.04)
			var retract_dur := maxf(option_frame_spring_duration - expand_dur, 0.04)
			_frame_tween = create_tween()
			_frame_tween.tween_property(self, "_frame_expand", option_frame_spring_overshoot, expand_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_frame_tween.tween_property(self, "_frame_expand", 1.0, retract_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		return
	if _frame_alpha <= 0.001:
		_frame_position = target.position
		_frame_size = target.size
	_frame_expand = 1.0
	_frame_tween = create_tween().set_parallel(true)
	_frame_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(self, "_frame_position", target.position, CONFIG.option_hover_tween_duration)
	_frame_tween.tween_property(self, "_frame_size", target.size, CONFIG.option_hover_tween_duration)
	_frame_tween.tween_property(self, "_frame_alpha", 1.0, minf(CONFIG.option_hover_tween_duration, 0.12))



func _play_selection_spring(option: Button) -> void:
	## Left-anchored width + text spring. Used for hover, keyboard, back restore, click.
	if not solid_fill or not is_instance_valid(option):
		return
	_set_option_pivot(option)
	_move_frame_to(option, true)
	_spring_option_text(option)


func _play_confirm_spring(option: Button) -> void:
	## Click/accept: same visible spring, plus busy flag so navigators can await.
	if not solid_fill or not is_instance_valid(option):
		return
	_confirm_spring_busy = true
	_pending_clear_highlight = false
	_play_selection_spring(option)
	if _frame_tween != null and _frame_tween.is_valid():
		# Avoid duplicate one-shot if already connected this tween.
		if not _frame_tween.finished.is_connected(_on_confirm_spring_finished):
			_frame_tween.finished.connect(_on_confirm_spring_finished, CONNECT_ONE_SHOT)
	else:
		_on_confirm_spring_finished()


func _on_confirm_spring_finished() -> void:
	_confirm_spring_busy = false
	confirm_spring_finished.emit()
	if _pending_clear_highlight:
		_pending_clear_highlight = false
		clear_highlight()


func is_confirm_spring_busy() -> bool:
	return _confirm_spring_busy


## Await from pressed handlers that navigate/hide the menu.
## Poll busy flag (avoids missing confirm_spring_finished if it fired already).
func wait_confirm_spring(min_seconds: float = -1.0) -> void:
	if not solid_fill:
		return
	var tree := get_tree()
	if tree == null:
		return
	if not _confirm_spring_busy:
		# Rare: this handler connected before register_options — give spring a frame.
		await tree.process_frame
	var floor_s := option_frame_spring_duration if min_seconds < 0.0 else min_seconds
	floor_s = maxf(floor_s, option_frame_spring_duration)
	var elapsed := 0.0
	while _confirm_spring_busy and elapsed < floor_s + 0.25:
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time() if tree.root else 0.016
	if _confirm_spring_busy:
		# Safety: don't hang navigators if tween was killed.
		_confirm_spring_busy = false
		confirm_spring_finished.emit()


func _spring_option_text(option: Button) -> void:
	## Options spring: left-pivoted scale_x punch, same timing family as the bar.
	if not is_instance_valid(option):
		return
	_kill_text_tween(option)
	_set_option_pivot(option)
	option.scale = Vector2(option_text_spring_start_scale, 1.0)
	var expand_dur := maxf(option_frame_spring_duration * 0.55, 0.04)
	var retract_dur := maxf(option_frame_spring_duration - expand_dur, 0.04)
	var tween := option.create_tween()
	_text_tweens[option.get_instance_id()] = tween
	tween.tween_property(option, "scale", Vector2(option_text_spring_overshoot, 1.0), expand_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(option, "scale", Vector2.ONE, retract_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _target_rect(option: Button) -> Rect2:
	var visual_scale := CONFIG.option_hover_scale if enable_hover_scale and not solid_fill else 1.0
	var text_size := _measure_button_text(option) * visual_scale
	var option_global := option.get_global_rect()
	var host_global := get_global_rect()
	var text_left_global := _option_text_left_global(option, text_size)
	var target_size: Vector2
	var target_position: Vector2
	if solid_fill:
		# Shared settle width (max selectable label) + ink-hug height so neighbors stay readable.
		var frame_width := _solid_frame_width()
		var ink_h := ceilf(text_size.y + option_frame_solid_v_pad * 2.0)
		var frame_height := maxf(ink_h, float(CONFIG.option_triangle_size))
		if option.size.y > 1.0:
			# Prefer row_h-4; if the button is already font-tall, shrink below metric.
			var row_lim := maxf(option.size.y - 4.0, float(CONFIG.option_triangle_size))
			frame_height = minf(frame_height, row_lim)
			if option.size.y <= text_size.y + 2.0:
				frame_height = minf(frame_height, maxf(text_size.y - 4.0, float(CONFIG.option_triangle_size)))
		target_size = Vector2(frame_width, frame_height)
		var per_option_left := text_left_global - CONFIG.option_triangle_size - CONFIG.option_triangle_text_gap - CONFIG.option_frame_padding.x - host_global.position.x
		target_position = Vector2(
			per_option_left,
			option_global.get_center().y - target_size.y * 0.5 - host_global.position.y
		)
	else:
		var content_width := CONFIG.option_triangle_size + CONFIG.option_triangle_text_gap + text_size.x
		target_size = Vector2(
			ceilf(content_width + CONFIG.option_frame_padding.x * 2.0),
			ceilf(maxf(text_size.y, CONFIG.option_triangle_size) + CONFIG.option_frame_padding.y * 2.0)
		)
		# Control没有Node2D.to_local()。两个Control的Global Rect相减，得到本组件坐标中的目标Rect。
		target_position = Vector2(
			text_left_global - CONFIG.option_triangle_size - CONFIG.option_triangle_text_gap - CONFIG.option_frame_padding.x - host_global.position.x,
			option_global.get_center().y - target_size.y * 0.5 - host_global.position.y
		)
	return Rect2(target_position.round(), target_size)


func _option_text_left_global(option: Button, text_size: Vector2) -> float:
	var option_global := option.get_global_rect()
	match option.alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			var normal_style := option.get_theme_stylebox(&"normal")
			return option_global.position.x + normal_style.get_content_margin(SIDE_LEFT)
		HORIZONTAL_ALIGNMENT_RIGHT:
			return option_global.end.x - text_size.x
		_:
			return option_global.get_center().x - text_size.x * 0.5


func _solid_frame_width(_for_option: Button = null) -> float:
	if option_frame_fixed_width > 0.5:
		return ceilf(option_frame_fixed_width)
	# NieR equal-width boxes: settle from longest selectable label in this group.
	# Per-option hug made pause 「设置」 much narrower than 「退出到主菜单」 and jittered settings handoff.
	var text_x := 0.0
	for option in get_selectable_options():
		text_x = maxf(text_x, _measure_button_text(option).x)
	if text_x <= 0.0:
		for option in _options:
			if not is_instance_valid(option):
				continue
			text_x = maxf(text_x, _measure_button_text(option).x)
	# Trailing pad so start_scale 0.20 still reads as a stub on the shared settle.
	var fill_w := maxf(text_x + 12.0, 36.0)
	return ceilf(CONFIG.option_triangle_size + CONFIG.option_triangle_text_gap + fill_w + CONFIG.option_frame_padding.x)


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
	for option in _options:
		if is_instance_valid(option):
			_apply_option_text_color(option, false)
			_kill_text_tween(option)
			if solid_fill:
				option.scale = Vector2.ONE
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
	var frame_rect := Rect2(_frame_position, _frame_size)
	if solid_fill:
		var fill := CONFIG.option_frame_fill_color
		# Keep the triangle outside the solid block (NieR: ▶ then fill+inverted text).
		var tri_span := CONFIG.option_triangle_size + CONFIG.option_triangle_text_gap
		var fill_settle := Rect2(
			Vector2(frame_rect.position.x + CONFIG.option_frame_padding.x + tri_span, frame_rect.position.y),
			Vector2(maxf(0.0, frame_rect.size.x - CONFIG.option_frame_padding.x - tri_span), frame_rect.size.y)
		)
		# Progress-bar fill: left edge fixed; width = settle * expand (0.20→1.20→1.0).
		var expand := maxf(_frame_expand, 0.01)
		var fill_w := fill_settle.size.x * expand
		var fill_rect := Rect2(
			Vector2(fill_settle.position.x, fill_settle.position.y),
			Vector2(fill_w, fill_settle.size.y)
		)
		draw_rect(fill_rect, Color(fill.r, fill.g, fill.b, fill.a * _frame_alpha), true)
	elif show_selection_frame:
		_frame_style.modulate_color = Color(1.0, 1.0, 1.0, _frame_alpha)
		draw_style_box(_frame_style, frame_rect)
	var triangle_color := unselected_text_color if solid_fill else CONFIG.option_triangle_color
	# Solid NieR: triangle X is fixed (no bob). Legacy path keeps the idle bob.
	var tri_bob := 0.0 if solid_fill else triangle_animation_offset(_triangle_anim_elapsed)
	var triangle_center := Vector2(
		frame_rect.position.x + CONFIG.option_frame_padding.x + CONFIG.option_triangle_size * 0.5 + tri_bob,
		frame_rect.get_center().y
	)
	var half := CONFIG.option_triangle_size * 0.5
	draw_colored_polygon(PackedVector2Array([
		triangle_center + Vector2(-half, -half),
		triangle_center + Vector2(-half, half),
		triangle_center + Vector2(half, 0.0),
	]), Color(triangle_color.r, triangle_color.g, triangle_color.b, triangle_color.a * _frame_alpha))


func _apply_option_text_color(option: Button, selected: bool) -> void:
	if not solid_fill or not is_instance_valid(option):
		return
	var color := selected_text_color if selected else unselected_text_color
	option.add_theme_color_override("font_color", color)
	option.add_theme_color_override("font_hover_color", color)
	option.add_theme_color_override("font_pressed_color", color)
	option.add_theme_color_override("font_focus_color", color)


func get_active_index() -> int:
	if _active_option == null:
		return -1
	return _options.find(_active_option)


func get_selectable_options() -> Array[Button]:
	var result: Array[Button] = []
	for option in _options:
		if is_instance_valid(option) and option.visible and option.is_visible_in_tree() and not option.disabled:
			result.append(option)
	return result


func activate_delta(delta: int, play_sound: bool = true) -> void:
	var selectable := get_selectable_options()
	if selectable.is_empty() or delta == 0:
		return
	var current := selectable.find(_active_option)
	var next_index: int
	if current < 0:
		next_index = 0 if delta > 0 else selectable.size() - 1
	else:
		next_index = posmod(current + delta, selectable.size())
	_activate(selectable[next_index], play_sound)


func activate_option(option: Button, play_sound: bool = true) -> void:
	if option == null or not is_instance_valid(option):
		return
	if option not in _options or option.disabled or not option.visible:
		return
	_activate(option, play_sound)


func activate_index(index: int, play_sound: bool = false) -> void:
	var selectable := get_selectable_options()
	if index < 0 or index >= selectable.size():
		return
	_activate(selectable[index], play_sound)


func trigger_active() -> bool:
	if _active_option == null or not is_instance_valid(_active_option):
		return false
	if _active_option.disabled or not _active_option.visible:
		return false
	# pressed → _on_option_pressed plays the confirm spring once (avoid double-fire).
	_active_option.pressed.emit()
	return true


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
