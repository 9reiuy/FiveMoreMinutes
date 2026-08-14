extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const CONFIG := preload("res://resources/demo_config.tres")

signal upgrade_chosen(option: Dictionary)
signal jackpot_chosen(options: Array[Dictionary])
signal reroll_requested
signal exit_finished

enum State { CLOSED, ENTERING, SPINNING, SELECT_ONE, JACKPOT, RESOLVING, EXITING }

const SLOT_SIZE := Vector2(156.0, 190.0)
const SLOT_GAP := 18.0
const CELL_HEIGHT := 54.0
const REROLL_RECT := Rect2(246, 318, 148, 28)
const OFFSCREEN_Y := 390.0

var state := State.CLOSED
var target_level := 2
var options: Array[Dictionary] = []
var reel_scroll := [0.0, 0.0, 0.0]
var reel_locking := [false, false, false]
var reel_locked := [false, false, false]
var reel_lock_elapsed := [0.0, 0.0, 0.0]
var reel_lock_start := [0.0, 0.0, 0.0]
var reel_lock_target := [0.0, 0.0, 0.0]
var reel_results: Array[Dictionary] = [{}, {}, {}]
var next_reel_to_lock := 0
var hovered_index := -1
var reroll_hovered := false
var rerolls_remaining := 0
var jackpot_left := 0.0
var reel_spin_elapsed := 0.0
var reel_cell_indices := [0, 0, 0]
var radial_rotation := 0.0
var panel_tween: Tween

@onready var crt_overlay: ColorRect = $CRTOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var crt_material := crt_overlay.material as ShaderMaterial
	if crt_material != null:
		crt_material.set_shader_parameter(&"overlay_screen_scale", crt_overlay.size / get_viewport_rect().size)
		crt_material.set_shader_parameter(&"scanline_strength", CONFIG.upgrade_crt_scanline_strength)
		crt_material.set_shader_parameter(&"noise_strength", CONFIG.upgrade_crt_noise_strength)
		crt_material.set_shader_parameter(&"vignette_strength", CONFIG.upgrade_crt_vignette_strength)
	set_process(false)


func open(new_level: int, new_options: Array[Dictionary], reroll_count: int = 0) -> void:
	target_level = new_level
	rerolls_remaining = maxi(0, reroll_count)
	visible = true
	_start_reels(new_options)
	state = State.ENTERING
	position = Vector2(0, OFFSCREEN_Y)
	if panel_tween != null and panel_tween.is_valid(): panel_tween.kill()
	panel_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.tween_property(self, "position:y", 0.0, CONFIG.upgrade_panel_enter_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	panel_tween.tween_callback(func() -> void: state = State.SPINNING)


func replace_options(new_options: Array[Dictionary]) -> void:
	_start_reels(new_options)


func _start_reels(new_options: Array[Dictionary]) -> void:
	options = new_options.duplicate(true)
	state = State.SPINNING
	next_reel_to_lock = 0
	hovered_index = -1
	reroll_hovered = false
	jackpot_left = 0.0
	reel_spin_elapsed = 0.0
	for index in 3:
		reel_scroll[index] = float(index) * CELL_HEIGHT * 0.37
		reel_cell_indices[index] = floori(reel_scroll[index] / CELL_HEIGHT)
		reel_locking[index] = false
		reel_locked[index] = false
		reel_lock_elapsed[index] = 0.0
		reel_results[index] = {}
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	radial_rotation += delta * 0.22
	if state == State.JACKPOT:
		jackpot_left = maxf(0.0, jackpot_left - delta)
		queue_redraw()
		if jackpot_left <= 0.0:
			_resolve_jackpot()
		return
	if state != State.SPINNING or options.is_empty():
		queue_redraw()
		return
	reel_spin_elapsed += delta
	var cycle := CELL_HEIGHT * float(options.size())
	for index in 3:
		if reel_locked[index]:
			continue
		if reel_locking[index]:
			reel_lock_elapsed[index] += delta
			var duration := maxf(CONFIG.upgrade_slot_lock_deceleration, 0.01)
			var progress := clampf(reel_lock_elapsed[index] / duration, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - progress, 3.0)
			reel_scroll[index] = lerpf(reel_lock_start[index], reel_lock_target[index], eased)
			if progress >= 1.0:
				_finish_reel_lock(index)
		else:
			var previous_total: float = reel_scroll[index]
			var travel: float = _reel_speed(index) * delta
			var crossed_cells := maxi(0, floori((previous_total + travel) / CELL_HEIGHT) - floori(previous_total / CELL_HEIGHT))
			reel_scroll[index] = fmod(previous_total + travel, cycle)
			var current_cell: int = floori(reel_scroll[index] / CELL_HEIGHT)
			# 累计距离判定不会因高速跨过边界而漏算；同帧上限和SFX节流共同避免爆音。
			for _crossed in mini(crossed_cells, 3):
				SFX.play_event(&"slot_tick")
			reel_cell_indices[index] = current_cell
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or state != State.SPINNING or options.is_empty():
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_lock_next_reel()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var old_hover := hovered_index
		var old_refresh := reroll_hovered
		reroll_hovered = _can_reroll() and REROLL_RECT.has_point(event.position)
		hovered_index = -1
		if state == State.SELECT_ONE or state == State.SPINNING:
			for index in 3:
				if reel_locked[index] and _slot_rect(index).has_point(event.position):
					hovered_index = index
					break
		if old_hover != hovered_index or old_refresh != reroll_hovered:
			if hovered_index >= 0 or reroll_hovered:
				SFX.play_event(&"ui_hover")
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_index >= 0 or reroll_hovered else Control.CURSOR_ARROW
			queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _can_reroll() and REROLL_RECT.has_point(event.position):
			if rerolls_remaining > 0:
				rerolls_remaining -= 1
				SFX.play_event(&"confirm")
				reroll_requested.emit()
			else:
				SFX.play_event(&"forbidden")
			accept_event()
			return
		if state == State.SELECT_ONE:
			for index in 3:
				if _slot_rect(index).has_point(event.position):
					_resolve_single(index)
					accept_event()
					return


func _lock_next_reel() -> void:
	if next_reel_to_lock >= 3 or reel_locking[next_reel_to_lock]:
		return
	var index := next_reel_to_lock
	reel_locking[index] = true
	reel_lock_elapsed[index] = 0.0
	reel_lock_start[index] = reel_scroll[index]
	# 再前进一个小段后吸附到最近完整Cell，形成短Ease-Out而不夹在两格之间。
	var projected: float = float(reel_scroll[index]) + _reel_speed(index) * CONFIG.upgrade_slot_lock_deceleration * 0.58
	reel_lock_target[index] = round(projected / CELL_HEIGHT) * CELL_HEIGHT
	SFX.play_event(&"confirm")


func _finish_reel_lock(index: int) -> void:
	reel_scroll[index] = reel_lock_target[index]
	reel_locking[index] = false
	reel_locked[index] = true
	var option_index := posmod(int(round(reel_scroll[index] / CELL_HEIGHT)), options.size())
	reel_results[index] = options[option_index].duplicate(true)
	next_reel_to_lock += 1
	if next_reel_to_lock >= 3:
		_evaluate_results()


func _evaluate_results() -> void:
	var first_id := str(reel_results[0].get("id", ""))
	var is_jackpot := not first_id.is_empty() and first_id == str(reel_results[1].get("id", "")) and first_id == str(reel_results[2].get("id", ""))
	# 武器是替换型奖励；同武器三同不会叠加实例，退化为普通单选并只装备一次。
	if is_jackpot and str(reel_results[0].get("reward_type", "upgrade")) == "weapon":
		is_jackpot = false
	if is_jackpot:
		state = State.JACKPOT
		jackpot_left = CONFIG.upgrade_jackpot_feedback_seconds
		SFX.play_event(&"confirm")
	else:
		state = State.SELECT_ONE
	queue_redraw()


func _resolve_single(index: int) -> void:
	if state != State.SELECT_ONE or index < 0 or index >= reel_results.size():
		return
	state = State.RESOLVING
	SFX.play_event(&"confirm")
	_exit_with_reward(reel_results[index].duplicate(true), false)


func _resolve_jackpot() -> void:
	if state != State.JACKPOT:
		return
	state = State.RESOLVING
	var rewards: Array[Dictionary] = []
	for result in reel_results:
		rewards.append(result.duplicate(true))
	_exit_with_reward(rewards, true)


func _exit_with_reward(payload: Variant, is_jackpot: bool) -> void:
	await get_tree().create_timer(CONFIG.upgrade_reward_confirm_seconds, true, false, true).timeout
	# 先结算奖励，再播放退场；战斗恢复/下一次升级由exit_finished统一接续。
	if is_jackpot: jackpot_chosen.emit(payload)
	else: upgrade_chosen.emit(payload)
	state = State.EXITING
	if panel_tween != null and panel_tween.is_valid(): panel_tween.kill()
	panel_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.tween_property(self, "position:y", OFFSCREEN_Y, CONFIG.upgrade_panel_exit_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await panel_tween.finished
	visible = false
	position = Vector2.ZERO
	set_process(false)
	exit_finished.emit()


func _can_reroll() -> bool:
	return state == State.SELECT_ONE and rerolls_remaining > 0


func _reel_speed(index: int) -> float:
	var starts := [CONFIG.upgrade_reel_start_speeds.x, CONFIG.upgrade_reel_start_speeds.y, CONFIG.upgrade_reel_start_speeds.z]
	var maximums := [CONFIG.upgrade_reel_max_speeds.x, CONFIG.upgrade_reel_max_speeds.y, CONFIG.upgrade_reel_max_speeds.z]
	var progress := clampf(reel_spin_elapsed / maxf(CONFIG.upgrade_reel_acceleration_duration, 0.001), 0.0, 1.0)
	var curved := CONFIG.upgrade_reel_acceleration_curve.sample(progress) if CONFIG.upgrade_reel_acceleration_curve != null else progress * progress
	return lerpf(float(starts[index]), float(maximums[index]), clampf(curved, 0.0, 1.0))


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.025, 0.91))
	_draw_radial_rays()
	var font := PixelFont.get_font()
	draw_string(font, Vector2(0, 55), "梦境正在加深 · 等级 %d" % target_level, HORIZONTAL_ALIGNMENT_CENTER, 640, 18, Color("bcd7e2"))
	draw_string(font, Vector2(0, 78), "连续按 SPACE 锁定左 / 中 / 右" if state == State.SPINNING else ("点击一个格子获得奖励" if state == State.SELECT_ONE else "JACKPOT · 三个奖励全部获得"), HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color("769caf"))
	for index in 3:
		_draw_reel(index, font)
	_draw_hover_description(font)
	if state == State.SELECT_ONE and rerolls_remaining > 0:
		draw_rect(REROLL_RECT, Color("24455a") if reroll_hovered else Color("122535"))
		draw_rect(REROLL_RECT, Color("517b98"), false, 1.0)
		draw_string(font, Vector2(REROLL_RECT.position.x, REROLL_RECT.position.y + 19), "重新抽取  %d" % rerolls_remaining, HORIZONTAL_ALIGNMENT_CENTER, REROLL_RECT.size.x, 10, Color("c6dce4"))


func _draw_radial_rays() -> void:
	var center := Vector2(320, 205)
	var jackpot := state in [State.JACKPOT, State.RESOLVING] and not reel_results[0].is_empty() and str(reel_results[0].get("id", "")) == str(reel_results[1].get("id", "")) and str(reel_results[0].get("id", "")) == str(reel_results[2].get("id", ""))
	var colors := [Color(0.18,0.44,0.62,0.16), Color(0.34,0.24,0.62,0.18), Color(0.18,0.65,0.66,0.16), Color(0.72,0.35,0.58,0.14), Color(0.76,0.62,0.25,0.12)]
	for index in 16:
		var angle := radial_rotation + TAU * float(index) / 16.0
		var half := 0.075
		var color: Color = colors[index % colors.size()] if jackpot else (Color(0.18,0.43,0.59,0.13) if index % 2 == 0 else Color(0.31,0.55,0.67,0.08))
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.RIGHT.rotated(angle-half)*350.0, center + Vector2.RIGHT.rotated(angle+half)*350.0]), color)


func _draw_reel(index: int, font: Font) -> void:
	var rect := _slot_rect(index)
	var hovered: bool = hovered_index == index and bool(reel_locked[index])
	var jackpot_pulse := state == State.JACKPOT and sin(jackpot_left * 24.0) > 0.0
	draw_rect(rect, Color("07101a"))
	draw_rect(rect.grow(-3), Color("173247") if hovered or jackpot_pulse else Color("0f2232"))
	draw_rect(rect, Color("72a5ba") if hovered or jackpot_pulse else Color("315b78"), false, 2.0)
	if options.is_empty():
		return
	var center := rect.get_center()
	var base_index := int(round(reel_scroll[index] / CELL_HEIGHT))
	var fractional: float = float(reel_scroll[index]) - float(base_index) * CELL_HEIGHT
	for relative in range(-1, 2):
		var option_index := posmod(base_index + relative, options.size())
		var option: Dictionary = options[option_index]
		var cell_center_y: float = center.y + float(relative) * CELL_HEIGHT - fractional
		var alpha := 1.0 if relative == 0 else 0.38
		_draw_upgrade_symbol(str(option.get("family", "")), Vector2(center.x, cell_center_y - 10.0), Color(_rarity_color(str(option.get("rarity", "blue"))), alpha))
		draw_string(font, Vector2(rect.position.x + 8, cell_center_y + 20), str(option.get("name", "未知")), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 10, Color(0.82, 0.9, 0.93, alpha))
	# 中央锁定线明确最终实际奖励所在Cell。
	draw_line(Vector2(rect.position.x + 5, center.y - 27), Vector2(rect.end.x - 5, center.y - 27), Color("527f96"), 1.0)
	draw_line(Vector2(rect.position.x + 5, center.y + 27), Vector2(rect.end.x - 5, center.y + 27), Color("527f96"), 1.0)
	if reel_locked[index]:
		draw_string(font, Vector2(rect.position.x, rect.end.y - 8), "LOCK", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color("9cc8d7"))


func _draw_upgrade_symbol(family: String, center: Vector2, color: Color) -> void:
	match family:
		"damage_boost":
			draw_line(center + Vector2(-8, 7), center + Vector2(8, -9), color, 3.0)
			draw_line(center + Vector2(-7, 3), center + Vector2(-2, 8), color, 2.0)
		"attack_speed_boost":
			for x in [-8.0, -2.0, 4.0]: draw_line(center + Vector2(x, 7), center + Vector2(x + 7, -7), color, 2.0)
		"range_boost":
			draw_circle(center, 11, color, false, 2.0)
			draw_circle(center, 4, color, false, 1.0)
		_:
			draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), color, false, 2.0)
			draw_circle(center, 3, color)


func _draw_hover_description(font: Font) -> void:
	if not state in [State.SPINNING, State.SELECT_ONE] or hovered_index < 0 or not reel_locked[hovered_index]:
		return
	var result: Dictionary = reel_results[hovered_index]
	var rect := Rect2(62, 294, 516, 21)
	draw_rect(rect, Color("091824"))
	draw_rect(rect, Color("315b78"), false, 1.0)
	var title := str(result.get("name", "未知"))
	var description := str(result.get("description", ""))
	draw_string(font, Vector2(rect.position.x + 8, rect.position.y + 14), title + " · " + description, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 9, Color("bcd7e2"))


func _slot_rect(index: int) -> Rect2:
	var total_width := SLOT_SIZE.x * 3.0 + SLOT_GAP * 2.0
	return Rect2(Vector2((640.0 - total_width) * 0.5 + index * (SLOT_SIZE.x + SLOT_GAP), 103.0), SLOT_SIZE)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"purple": return Color("a779c7")
		"gold": return Color("d7b45f")
		_: return Color("668fc3")
