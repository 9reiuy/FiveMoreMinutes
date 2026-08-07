extends Control

const SFX := preload("res://scripts/audio/sfx_manager.gd")
const FORMAT := preload("res://scripts/ui/display_format.gd")

signal new_day_requested

const EARLY_TEXT := ["闹钟停了。", "你及时坐了起来。", "今天还要去上班。", "去上班了。"]
const LATE_TEXT := ["闹钟已经响了很久。", "你看了一眼时间。", "今天又迟到了。", "迟到了。"]
const SILENT_CHARACTERS := " \t\n，。！？、；：,.!?;:\"“”‘’"

@export var config: DemoConfig

@onready var start_button: Button = $StartNewDay

var summary: Dictionary = {}
var paragraphs: Array = []
var paragraph_index := 0
var visible_characters := 0
var character_accumulator := 0.0
var audible_character_count := 0
var showing_summary := false
var text_audio: AudioStreamPlayer
var door_transition_alpha := 0.0
var new_day_sequence_running := false
var work_sfx_played := false


func _ready() -> void:
	var early_special := (
		not bool(summary.get("is_sunday", false))
		and str(summary.get("reason", "")) == "梦中倒下"
		and float(summary.get("dream_end_minutes", 9999.0)) < float(config.early_nightmare_death_cutoff_minutes)
	)
	if early_special:
		paragraphs = ["闹钟还没响", "今天又是一场噩梦"]
	else:
		match str(summary.get("attendance_status", "正常上班")):
			"正常上班": paragraphs = EARLY_TEXT.duplicate()
			"轻微迟到": paragraphs = ["闹钟响了一会儿。","你匆忙坐了起来。","还来得及赶过去。","轻微迟到。"]
			"严重迟到": paragraphs = ["闹钟已经响了很久。","你看了一眼时间。","今天又迟到了。","严重迟到。"]
			"休息日": paragraphs = ["今天是休息日，我需要找点有意义的事情做"]
			"失业": paragraphs = ["手机没有再响。", "今天也没有工作。"]
			_: paragraphs = ["房间里已经很亮。","你终于睁开了眼睛。","今天不用再赶了。","旷工。"]
	for weapon_name in summary.get("weapon_unlocks", []):
		paragraphs.append("%s已永久解锁。" % weapon_name)
	if bool(summary.get("unemployment_triggered", false)):
		paragraphs.append("项目组发来了终止合作通知。")
		paragraphs.append("你失业了。")
	text_audio = AudioStreamPlayer.new()
	text_audio.bus = &"UI"
	text_audio.volume_db = config.opening_text_sound_volume_db
	text_audio.stream = TextBlipFactory.create(config)
	add_child(text_audio)
	start_button.pressed.connect(_on_start_new_day)
	queue_redraw()


func _process(delta: float) -> void:
	if showing_summary or _paragraph_is_complete():
		queue_redraw()
		return
	character_accumulator += delta * config.results_characters_per_second
	while character_accumulator >= 1.0 and not _paragraph_is_complete():
		character_accumulator -= 1.0
		visible_characters += 1
		_play_character_sound(paragraphs[paragraph_index].substr(visible_characters - 1, 1))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if showing_summary or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not _paragraph_is_complete():
		visible_characters = paragraphs[paragraph_index].length()
	elif paragraph_index < paragraphs.size() - 1:
		paragraph_index += 1
		visible_characters = 0
		character_accumulator = 0.0
		audible_character_count = 0
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
		draw_string(font, Vector2(0, 178), visible_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 20, Color("c4c0c3"))
		if _paragraph_is_complete():
			var bounce := sin(Time.get_ticks_msec() * 0.008) * 3.0
			var p := Vector2(320, 298 + bounce)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-7,-4),p+Vector2(7,-4),p+Vector2(0,5)]),Color("8d8e98"))
		return
	draw_rect(Rect2(106, 55, 428, 200), Color("20212a"))
	_draw_result_row(font, 102, "醒来时间", str(summary.get("wake_time", "--:--")))
	_draw_result_row(font, 138, "本局 RAM", "+%d" % int(summary.get("run_ram", 0)))
	var wage := int(summary.get("wage", 0))
	_draw_result_row(font, 174, "工资", ("+" if wage > 0 else "") + FORMAT.format_currency(wage))
	_draw_result_row(font, 210, "余额", FORMAT.format_currency(int(summary.get("total_balance", 0))))
	if door_transition_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.015, door_transition_alpha))


func _draw_result_row(font: Font, y: float, label: String, value: String) -> void:
	draw_string(font, Vector2(178, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("858590"))
	draw_string(font, Vector2(360, y), value, HORIZONTAL_ALIGNMENT_RIGHT, 100, 16, Color("d2c7c5"))
