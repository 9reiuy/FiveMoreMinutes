extends Control

signal opening_finished
signal return_to_menu_requested

const SILENT_CHARACTERS := " \t\n，。！？、；：,.!?;:\"“”‘’"
const CITY_FRAME_SECONDS := 2.0
const CITY_MOVE_DURATION_SECONDS := 6.0

@export var config: DemoConfig
@export var replacement_text_sound: AudioStream
@export var ending_mode := false
@export var text_event_id: StringName = &"opening_first_night"
var ending_paragraphs = []:
	set(value):
		_set_ending_paragraphs(value)
## 需要醒目显示的段落文本（如"你饿死了"）：红色 + 两倍字号 + 轻微抖动。
var dramatic_text := "" # Legacy compatibility; new events use line.style = "dramatic".

@onready var return_button: Button = $ReturnToMenu
@onready var option_group: PixelOptionGroup = $OptionGroup
@onready var city_night: TextureRect = $NightCityBackground
@onready var story_text: Label = $FrameArea/StoryText
@onready var continue_arrow: Polygon2D = $FrameArea/ContinueArrow
@onready var ending_canvas: EndingTextCanvas = $EndingCanvas

var city_textures: Array[Texture2D] = [
	preload("res://art/Background/citynight_1.png"),
	preload("res://art/Background/citynight_2.png"),
]
var city_move_tween: Tween
var city_frame_elapsed := 0.0
var city_frame_index := 0


func setup_paragraphs(values: Array) -> void:
	presentation_lines.clear()
	for value in values:
		presentation_lines.append({"text": str(value), "typewriter_speed": 0.05, "text_color": "#C4C0C3", "font_size": 20, "wait_for_input": true, "blip": true})
	paragraphs = values.duplicate()
	paragraph_index = 0
	visible_characters = 0
	character_accumulator = 0.0
	audible_character_count = 0
	if is_node_ready():
		_apply_current_line()
		queue_redraw()


func setup_text_event(event_id: StringName, replacements: Dictionary = {}) -> void:
	text_event_id = event_id
	presentation_lines = TextContent.get_event_lines(event_id, replacements)
	paragraphs.clear()
	for line in presentation_lines:
		paragraphs.append(str(line.get("text", "")) if line is Dictionary else "")
	paragraph_index = 0
	visible_characters = 0
	character_accumulator = 0.0
	audible_character_count = 0
	if is_node_ready():
		_apply_current_line()
		queue_redraw()


func _set_ending_paragraphs(value: Variant) -> void:
	var normalized: Array = []
	if value is Array:
		normalized = value.duplicate()
	elif value is PackedStringArray:
		normalized = Array(value)
	setup_paragraphs(normalized)

var paragraph_index := 0
var visible_characters := 0
var character_accumulator := 0.0
var audible_character_count := 0
var input_enabled := false
var text_audio: AudioStreamPlayer
var paragraphs: Array = []
var presentation_lines: Array = []
var current_line: Dictionary = {}
var pre_delay_remaining := 0.0
var post_delay_remaining := 0.0
var line_ready := false
var line_fade_alpha := 1.0
var line_fade_elapsed := 0.0


func _ready() -> void:
	if presentation_lines.is_empty():
		setup_text_event(text_event_id)
	$FrameArea.visible = not ending_mode
	ending_canvas.visible = ending_mode
	ending_canvas.configure(self)
	return_button.visible = false
	return_button.add_theme_font_override("font", PixelFont.get_font())
	return_button.add_theme_color_override("font_color", Color("8fb3bc"))
	return_button.add_theme_color_override("font_hover_color", Color("d5dde0"))
	return_button.add_theme_color_override("font_pressed_color", Color("d5dde0"))
	option_group.register_options([return_button])
	return_button.pressed.connect(_on_return_to_menu)
	text_audio = AudioStreamPlayer.new()
	text_audio.bus = &"UI"
	text_audio.volume_db = config.opening_text_sound_volume_db
	text_audio.stream = replacement_text_sound if replacement_text_sound != null else TextBlipFactory.create(config)
	add_child(text_audio)
	story_text.add_theme_font_override("font", PixelFont.get_font())
	if not ending_mode:
		_start_city_sequence()
	_apply_current_line()
	_update_story_text()
	queue_redraw()
	await get_tree().create_timer(0.25, false).timeout
	input_enabled = true


func _process(delta: float) -> void:
	_update_city_frames(delta)
	_update_line_fade(delta)
	if pre_delay_remaining > 0.0:
		pre_delay_remaining = maxf(0.0, pre_delay_remaining - delta)
		_update_story_text()
		queue_redraw()
		return
	if _paragraph_is_complete():
		if post_delay_remaining > 0.0:
			post_delay_remaining = maxf(0.0, post_delay_remaining - delta)
			if post_delay_remaining <= 0.0:
				_mark_line_ready()
		_update_story_text()
		queue_redraw()
		return
	var seconds_per_character := maxf(0.001, float(current_line.get("typewriter_speed", 1.0 / maxf(config.opening_characters_per_second, 1.0))))
	character_accumulator += delta / seconds_per_character
	while character_accumulator >= 1.0 and not _paragraph_is_complete():
		character_accumulator -= 1.0
		visible_characters += 1
		_play_character_sound_if_needed(paragraphs[paragraph_index].substr(visible_characters - 1, 1))
	if _paragraph_is_complete() and not line_ready and post_delay_remaining <= 0.0:
		_start_post_delay()
	_update_story_text()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if pre_delay_remaining > 0.0:
		return
	if not _paragraph_is_complete():
		# First press completes the current paragraph without playing a burst of sounds.
		visible_characters = paragraphs[paragraph_index].length()
		_update_story_text()
		queue_redraw()
		_start_post_delay()
	elif not line_ready:
		return
	elif paragraph_index < paragraphs.size() - 1:
		_advance_line()
	else:
		text_audio.stop()
		if ending_mode:
			input_enabled = false
			return_to_menu_requested.emit()
		else:
			input_enabled = false
			opening_finished.emit()
	accept_event()


func _paragraph_is_complete() -> bool:
	return visible_characters >= paragraphs[paragraph_index].length()


func _on_return_to_menu() -> void:
	if not ending_mode:
		return
	input_enabled = false
	return_button.disabled = true
	return_to_menu_requested.emit()


func _play_character_sound_if_needed(character: String) -> void:
	if not bool(current_line.get("blip", true)):
		return
	if SILENT_CHARACTERS.contains(character):
		return
	audible_character_count += 1
	var interval := maxi(1, config.opening_text_sound_every_characters)
	if (audible_character_count - 1) % interval != 0:
		return
	# Reusing one player prevents overlapping beeps from clipping.
	text_audio.stop()
	text_audio.play()


func _start_city_sequence() -> void:
	# NightCity 按当前视口和纹理比例计算 Cover 尺寸，只做一次从下往上的位移。
	# 帧循环由 _update_city_frames 独立驱动，因此位移结束后仍继续播放。
	city_night.texture = city_textures[0]
	city_frame_index = 0
	city_frame_elapsed = 0.0
	var viewport_size := get_viewport_rect().size
	var source_size := city_night.texture.get_size()
	# 预留视口高度 12% 的纵向超扫描区域，保证不同宽高比下移动全程也不会露黑边。
	var desired_travel := viewport_size.y * 0.12
	var cover_scale := maxf(
		viewport_size.x / maxf(source_size.x, 1.0),
		(viewport_size.y + desired_travel) / maxf(source_size.y, 1.0)
	)
	var display_size := (source_size * cover_scale).ceil()
	var vertical_overflow := maxf(display_size.y - viewport_size.y, 0.0)
	var travel_distance := minf(desired_travel, vertical_overflow)
	var final_y := viewport_size.y - display_size.y
	var start_position := Vector2((viewport_size.x - display_size.x) * 0.5, final_y + travel_distance).round()
	var final_position := Vector2((viewport_size.x - display_size.x) * 0.5, final_y).round()
	city_night.position = start_position
	city_night.size = display_size
	city_move_tween = create_tween()
	city_move_tween.tween_property(city_night, "position", final_position, CITY_MOVE_DURATION_SECONDS).set_trans(Tween.TRANS_LINEAR)
	city_move_tween.finished.connect(func() -> void:
		# 位移只执行一次；结束时落在整数像素且不重启 Tween。
		city_night.position = final_position.round()
	)


func _update_city_frames(delta: float) -> void:
	if ending_mode or city_textures.is_empty():
		return
	city_frame_elapsed += delta
	while city_frame_elapsed >= CITY_FRAME_SECONDS:
		city_frame_elapsed -= CITY_FRAME_SECONDS
		city_frame_index = (city_frame_index + 1) % city_textures.size()
		city_night.texture = city_textures[city_frame_index]


func _update_story_text() -> void:
	if ending_mode or paragraphs.is_empty() or paragraph_index >= paragraphs.size():
		return
	story_text.text = paragraphs[paragraph_index].substr(0, visible_characters)
	story_text.modulate.a = line_fade_alpha
	story_text.add_theme_color_override("font_color", _current_text_color())
	story_text.add_theme_font_size_override("font_size", _current_font_size())
	story_text.horizontal_alignment = _current_alignment()
	continue_arrow.visible = _paragraph_is_complete() and line_ready and input_enabled and not return_button.visible
	if continue_arrow.visible:
		continue_arrow.position.y = 310.0 + sin(Time.get_ticks_msec() * 0.008) * 3.0


func _draw() -> void:
	if ending_mode:
		return
	var font := PixelFont.get_font()
	var visible_text: String = paragraphs[paragraph_index].substr(0, visible_characters)
	var is_dramatic := _is_current_line_dramatic()
	if is_dramatic:
		# 醒目结局文本：红色 + 两倍字号 + 字间距 + 每个字独立轻微抖动。
		_draw_dramatic_text(self, font, visible_text)
	story_text.visible = not ending_mode and not is_dramatic
	continue_arrow.visible = not ending_mode and not is_dramatic and _paragraph_is_complete() and line_ready and input_enabled and not return_button.visible


func draw_ending_content(canvas: CanvasItem) -> void:
	if not ending_mode or paragraphs.is_empty() or paragraph_index >= paragraphs.size():
		return
	var font := PixelFont.get_font()
	var visible_text: String = paragraphs[paragraph_index].substr(0, visible_characters)
	var is_dramatic := _is_current_line_dramatic()
	if is_dramatic:
		_draw_dramatic_text(canvas, font, visible_text)
	else:
		canvas.draw_string(font, Vector2(0, _current_text_y()), visible_text, _current_alignment(), size.x, _current_font_size(), Color(_current_text_color(), _current_text_color().a * line_fade_alpha))


## 逐字绘制醒目文本：每字独立抖动（相位错开）+ 字间距，整行居中。
func _draw_dramatic_text(canvas: CanvasItem, font: Font, text: String) -> void:
	var glyph_size := _current_font_size()
	var letter_spacing := 10.0
	var chars: PackedStringArray = []
	for index in text.length():
		chars.append(text[index])
	# 测量每个字宽度并计算总宽，保证整行居中。
	var widths: Array[float] = []
	var total := 0.0
	for character in chars:
		var char_width := maxf(font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x, float(glyph_size) * 0.9)
		widths.append(char_width)
		total += char_width
	if chars.size() > 1:
		total += letter_spacing * float(chars.size() - 1)
	var cursor_x := (size.x - total) * 0.5
	var time := Time.get_ticks_msec() * 0.001
	for index in chars.size():
		# 每个字独立的抖动相位，互不同步。
		var shake := Vector2(
			sin(time * 41.0 + float(index) * 2.3) * 2.0,
			cos(time * 33.0 + float(index) * 1.7) * 2.0
		)
		var dramatic_color := _current_text_color()
		canvas.draw_string(font, Vector2(cursor_x, _current_text_y()) + shake, chars[index], HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, Color(dramatic_color, dramatic_color.a * line_fade_alpha))
		cursor_x += widths[index] + letter_spacing


func _apply_current_line() -> void:
	if paragraph_index < 0 or paragraph_index >= presentation_lines.size():
		current_line = {}
		return
	current_line = presentation_lines[paragraph_index] if presentation_lines[paragraph_index] is Dictionary else {}
	pre_delay_remaining = maxf(0.0, float(current_line.get("pre_delay", 0.0)))
	post_delay_remaining = 0.0
	line_ready = false
	line_fade_elapsed = 0.0
	line_fade_alpha = 0.0 if float(current_line.get("fade_in", 0.0)) > 0.0 else 1.0
	if is_instance_valid(story_text):
		match str(current_line.get("position", "bottom")):
			"top": story_text.position.y = 55.0
			"center", "middle": story_text.position.y = 152.0
			_: story_text.position.y = 245.0
	if paragraphs[paragraph_index].is_empty() or float(current_line.get("typewriter_speed", 0.05)) <= 0.0:
		visible_characters = paragraphs[paragraph_index].length()
		_start_post_delay()


func _advance_line() -> void:
	paragraph_index += 1
	visible_characters = 0
	character_accumulator = 0.0
	audible_character_count = 0
	_apply_current_line()
	_update_story_text()
	queue_redraw()


func _start_post_delay() -> void:
	post_delay_remaining = maxf(0.0, float(current_line.get("post_delay", current_line.get("display_duration", 0.0))))
	if post_delay_remaining <= 0.0:
		_mark_line_ready()


func _mark_line_ready() -> void:
	if line_ready:
		return
	line_ready = true
	if not bool(current_line.get("wait_for_input", true)) and bool(current_line.get("auto_continue", false)):
		if paragraph_index < paragraphs.size() - 1:
			_advance_line()
		elif ending_mode:
			input_enabled = false
			return_to_menu_requested.emit()
		else:
			input_enabled = false
			opening_finished.emit()


func _update_line_fade(delta: float) -> void:
	var fade_in := maxf(0.0, float(current_line.get("fade_in", 0.0)))
	if fade_in > 0.0 and line_fade_elapsed < fade_in:
		line_fade_elapsed += delta
		line_fade_alpha = clampf(line_fade_elapsed / fade_in, 0.0, 1.0)
	var fade_out := maxf(0.0, float(current_line.get("fade_out", 0.0)))
	if fade_out > 0.0 and _paragraph_is_complete() and post_delay_remaining > 0.0 and post_delay_remaining <= fade_out:
		line_fade_alpha = clampf(post_delay_remaining / fade_out, 0.0, 1.0)


func _current_text_color() -> Color:
	return Color.from_string(str(current_line.get("text_color", "#C4C0C3")), Color("c4c0c3"))


func _current_font_size() -> int:
	return maxi(8, int(current_line.get("font_size", 20)))


func _current_alignment() -> HorizontalAlignment:
	match str(current_line.get("alignment", "center")):
		"left": return HORIZONTAL_ALIGNMENT_LEFT
		"right": return HORIZONTAL_ALIGNMENT_RIGHT
		_: return HORIZONTAL_ALIGNMENT_CENTER


func _current_text_y() -> float:
	match str(current_line.get("position", "center")):
		"top": return 82.0
		"bottom": return 282.0
		_: return 180.0


func _is_current_line_dramatic() -> bool:
	return str(current_line.get("style", "")) == "dramatic" or (not dramatic_text.is_empty() and paragraphs[paragraph_index] == dramatic_text)
