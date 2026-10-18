extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")

signal new_day_requested

const SILENT_CHARACTERS := " \t\n，。！？、；：,.!?;:\"“”‘’"

@export var config: DemoConfig

@onready var start_button: Button = $StartNewDay
@onready var option_group: PixelOptionGroup = $OptionGroup

var summary: Dictionary = {}
var paragraphs: Array = []
var presentation_lines: Array = []
var current_line: Dictionary = {}
var paragraph_index := 0
var visible_characters := 0
var character_accumulator := 0.0
var audible_character_count := 0
var showing_summary := false
var text_audio: AudioStreamPlayer
var door_transition_alpha := 0.0
var new_day_sequence_running := false
var work_sfx_played := false
var pre_delay_remaining := 0.0
var post_delay_remaining := 0.0
var line_ready := false
var line_fade_alpha := 1.0
var line_fade_elapsed := 0.0


func _ready() -> void:
	var early_special := (
		not bool(summary.get("is_sunday", false))
		and str(summary.get("reason", "")) == "梦中倒下"
		and float(summary.get("dream_end_minutes", 9999.0)) < float(config.early_nightmare_death_cutoff_minutes)
	)
	if early_special:
		presentation_lines = TextContent.get_event_lines(&"nightmare_early_death")
	else:
		match str(summary.get("attendance_status", "正常上班")):
			"正常上班": presentation_lines = TextContent.get_event_lines(&"wake_normal")
			"轻微迟到": presentation_lines = TextContent.get_event_lines(&"wake_slightly_late")
			"严重迟到": presentation_lines = TextContent.get_event_lines(&"wake_severely_late")
			"休息日": presentation_lines = TextContent.get_event_lines(&"wake_sunday")
			"失业": presentation_lines = TextContent.get_event_lines(&"wake_unemployed")
			_: presentation_lines = TextContent.get_event_lines(&"wake_absent")
	for weapon_name in summary.get("weapon_unlocks", []):
		presentation_lines.append_array(TextContent.get_event_lines(&"weapon_unlock_notice", {"weapon_name": weapon_name}))
	if bool(summary.get("unemployment_triggered", false)):
		presentation_lines.append_array(TextContent.get_event_lines(&"unemployment_notice"))
	for line in presentation_lines:
		paragraphs.append(str(line.get("text", "")) if line is Dictionary else "")
	_apply_current_line()
	text_audio = AudioStreamPlayer.new()
	text_audio.bus = &"UI"
	text_audio.volume_db = config.opening_text_sound_volume_db
	text_audio.stream = TextBlipFactory.create(config)
	add_child(text_audio)
	start_button.add_theme_font_override("font", PixelFont.get_font())
	start_button.add_theme_color_override("font_color", Color("8fb3bc"))
	start_button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	start_button.add_theme_color_override("font_pressed_color", Color("d5dde0"))
	option_group.register_options([start_button])
	start_button.pressed.connect(_on_start_new_day)
	queue_redraw()


func _process(delta: float) -> void:
	_update_line_fade(delta)
	if showing_summary:
		queue_redraw()
		return
	if pre_delay_remaining > 0.0:
		pre_delay_remaining = maxf(0.0, pre_delay_remaining - delta)
		queue_redraw()
		return
	if _paragraph_is_complete():
		if post_delay_remaining > 0.0:
			post_delay_remaining = maxf(0.0, post_delay_remaining - delta)
			if post_delay_remaining <= 0.0:
				_mark_line_ready()
		queue_redraw()
		return
	var seconds_per_character := maxf(0.001, float(current_line.get("typewriter_speed", 1.0 / maxf(config.results_characters_per_second, 1.0))))
	character_accumulator += delta / seconds_per_character
	while character_accumulator >= 1.0 and not _paragraph_is_complete():
		character_accumulator -= 1.0
		visible_characters += 1
		_play_character_sound(paragraphs[paragraph_index].substr(visible_characters - 1, 1))
	if _paragraph_is_complete():
		_start_post_delay()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if showing_summary or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if pre_delay_remaining > 0.0:
		return
	if not _paragraph_is_complete():
		visible_characters = paragraphs[paragraph_index].length()
		_start_post_delay()
	elif not line_ready:
		return
	elif paragraph_index < paragraphs.size() - 1:
		paragraph_index += 1
		visible_characters = 0
		character_accumulator = 0.0
		audible_character_count = 0
		_apply_current_line()
	else:
		showing_summary = true
		start_button.visible = true
		text_audio.stop()
		_play_work_if_applicable()
	queue_redraw()
	accept_event()


func _paragraph_is_complete() -> bool:
	return visible_characters >= paragraphs[paragraph_index].length()


func _play_character_sound(character: String) -> void:
	if not bool(current_line.get("blip", true)):
		return
	if SILENT_CHARACTERS.contains(character):
		return
	audible_character_count += 1
	if (audible_character_count - 1) % maxi(1, config.opening_text_sound_every_characters) == 0:
		text_audio.stop()
		text_audio.play()


func _on_start_new_day() -> void:
	if new_day_sequence_running:
		return
	new_day_sequence_running = true
	start_button.disabled = true
	SFX.play_event(&"home_door")
	var transition := create_tween()
	transition.tween_method(func(value: float): door_transition_alpha = value; queue_redraw(), 0.0, 1.0, maxf(0.12, config.door_open_close_gap_seconds))
	await transition.finished
	await get_tree().create_timer(0.18, false).timeout
	new_day_requested.emit()


func _play_work_if_applicable() -> void:
	if work_sfx_played or str(summary.get("attendance_status", "")) != "正常上班":
		return
	work_sfx_played = true
	SFX.play_event(&"work")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("14151d"))
	var font := PixelFont.get_font()
	if not showing_summary:
		var visible_text: String = paragraphs[paragraph_index].substr(0, visible_characters)
		var line_color := Color.from_string(str(current_line.get("text_color", "#C4C0C3")), Color("c4c0c3"))
		draw_string(font, Vector2(0, _current_text_y()), visible_text, _current_alignment(), 640, maxi(8, int(current_line.get("font_size", 20))), Color(line_color, line_color.a * line_fade_alpha))
		if _paragraph_is_complete() and line_ready:
			var bounce := sin(Time.get_ticks_msec() * 0.008) * 3.0
			var p := Vector2(320, 298 + bounce)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-7,-4),p+Vector2(7,-4),p+Vector2(0,5)]),Color("8d8e98"))
		return
	draw_rect(Rect2(106, 55, 428, 200), Color("20212a"))
	_draw_result_row(font, 102, "醒来时间", str(summary.get("wake_time", "--:--")))
	var wage := int(summary.get("wage", 0))
	_draw_result_row(font, 156, "今日工资", ("+" if wage > 0 else "") + FORMAT.format_currency(wage))
	_draw_result_row(font, 210, "余额", FORMAT.format_currency(int(summary.get("total_balance", 0))))
	if door_transition_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.015, door_transition_alpha))


func _draw_result_row(font: Font, y: float, label: String, value: String) -> void:
	draw_string(font, Vector2(178, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("858590"))
	draw_string(font, Vector2(360, y), value, HORIZONTAL_ALIGNMENT_RIGHT, 100, 16, Color("d2c7c5"))


func _apply_current_line() -> void:
	current_line = presentation_lines[paragraph_index] if paragraph_index >= 0 and paragraph_index < presentation_lines.size() and presentation_lines[paragraph_index] is Dictionary else {}
	pre_delay_remaining = maxf(0.0, float(current_line.get("pre_delay", 0.0)))
	post_delay_remaining = 0.0
	line_ready = false
	line_fade_elapsed = 0.0
	line_fade_alpha = 0.0 if float(current_line.get("fade_in", 0.0)) > 0.0 else 1.0
	if paragraphs[paragraph_index].is_empty() or float(current_line.get("typewriter_speed", 0.05)) <= 0.0:
		visible_characters = paragraphs[paragraph_index].length()
		_start_post_delay()


func _start_post_delay() -> void:
	post_delay_remaining = maxf(0.0, float(current_line.get("post_delay", current_line.get("display_duration", 0.0))))
	if post_delay_remaining <= 0.0:
		_mark_line_ready()


func _current_alignment() -> HorizontalAlignment:
	match str(current_line.get("alignment", "center")):
		"left": return HORIZONTAL_ALIGNMENT_LEFT
		"right": return HORIZONTAL_ALIGNMENT_RIGHT
		_: return HORIZONTAL_ALIGNMENT_CENTER


func _current_text_y() -> float:
	match str(current_line.get("position", "center")):
		"top": return 82.0
		"bottom": return 282.0
		_: return 178.0


func _mark_line_ready() -> void:
	if line_ready:
		return
	line_ready = true
	if not bool(current_line.get("wait_for_input", true)) and bool(current_line.get("auto_continue", false)):
		call_deferred("_advance_result_line_automatically")


func _advance_result_line_automatically() -> void:
	if showing_summary or not line_ready:
		return
	if paragraph_index < paragraphs.size() - 1:
		paragraph_index += 1
		visible_characters = 0
		character_accumulator = 0.0
		audible_character_count = 0
		_apply_current_line()
	else:
		showing_summary = true
		start_button.visible = true
		text_audio.stop()
		_play_work_if_applicable()
	queue_redraw()


func _update_line_fade(delta: float) -> void:
	var fade_in := maxf(0.0, float(current_line.get("fade_in", 0.0)))
	if fade_in > 0.0 and line_fade_elapsed < fade_in:
		line_fade_elapsed += delta
		line_fade_alpha = clampf(line_fade_elapsed / fade_in, 0.0, 1.0)
	var fade_out := maxf(0.0, float(current_line.get("fade_out", 0.0)))
	if fade_out > 0.0 and _paragraph_is_complete() and post_delay_remaining > 0.0 and post_delay_remaining <= fade_out:
		line_fade_alpha = clampf(post_delay_remaining / fade_out, 0.0, 1.0)
