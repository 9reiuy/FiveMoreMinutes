extends Control

@export var replacement_alarm_stream: AudioStream
@export var config: DemoConfig

var alarm_active := false
var alarm_elapsed := 0.0
var player_near_wake_point := false
var hold_progress := 0.0
var required_hold := 5.0
var hand_transition_progress := -1.0
var alarm_player: AudioStreamPlayer
var sunshade_active := false


func _ready() -> void:
	alarm_player = AudioStreamPlayer.new()
	alarm_player.bus = &"Environment"
	add_child(alarm_player)
	alarm_player.volume_db = -12.0
	alarm_player.stream = replacement_alarm_stream if replacement_alarm_stream != null else _create_placeholder_alarm()


func start_alarm() -> void:
	alarm_active = true
	if not alarm_player.playing:
		alarm_player.play()
	queue_redraw()


func update_alarm(elapsed: float, near_point: bool, progress: float, required: float) -> void:
	alarm_elapsed = elapsed
	player_near_wake_point = near_point
	hold_progress = progress
	required_hold = required
	queue_redraw()


func play_hand_transition() -> void:
	hand_transition_progress = 0.0
	var tween := create_tween()
	tween.tween_method(_set_hand_progress, 0.0, 1.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	alarm_player.stop()
	await get_tree().create_timer(0.35, false).timeout


func _set_hand_progress(value: float) -> void:
	hand_transition_progress = value
	queue_redraw()


func stop_alarm() -> void:
	alarm_player.stop()
	alarm_active = false
	queue_redraw()


func update_sunshade(active: bool) -> void:
	sunshade_active = active
	queue_redraw()


func _draw() -> void:
	if not alarm_active and hand_transition_progress < 0.0:
		return
	var font := PixelFont.get_font()
	if alarm_active:
		var intensity := clampf(alarm_elapsed / maxf(config.alarm_visual_ramp_seconds, 0.1), 0.0, 1.0)
		if sunshade_active:
			intensity *= config.sunshade_alarm_brightness_multiplier
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.95, 0.82, intensity * config.alarm_screen_brightness_alpha))
		var lid_size := lerpf(8.0, config.alarm_eyelid_max_height, intensity)
		draw_rect(Rect2(0, 0, size.x, lid_size), Color(0.025, 0.02, 0.028, 0.84))
		draw_rect(Rect2(0, size.y - lid_size, size.x, lid_size), Color(0.025, 0.02, 0.028, 0.84))
		draw_string(font, Vector2(0, 88), RunSettlement.format_time(config.alarm_start_minutes) + "  闹钟正在响", HORIZONTAL_ALIGNMENT_CENTER, 640, 18, Color("5b3338"))
		draw_string(font, Vector2(0, 112), "回到床边，让自己醒来", HORIZONTAL_ALIGNMENT_CENTER, 640, 14, Color("604d53"))
		if player_near_wake_point:
			draw_rect(Rect2(155, 300, 330, 43), Color(0.03, 0.025, 0.04, 0.86))
			draw_rect(Rect2(177, 326, 286, 8), Color("302f3b"))
			draw_rect(Rect2(177, 326, 286.0 * clampf(hold_progress / maxf(required_hold, 0.001), 0.0, 1.0), 8), Color("a68383"))
			draw_string(font, Vector2(0, 319), "按住 F 醒来  %.1f / %.1f 秒" % [hold_progress, required_hold], HORIZONTAL_ALIGNMENT_CENTER, 640, 14, Color("d4c9c9"))
	if hand_transition_progress >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.018, 0.025, 0.72))
		var alarm_position := Vector2(320, 117)
		draw_rect(Rect2(alarm_position - Vector2(48, 24), Vector2(96, 48)), Color("2b2930"))
		draw_string(font, alarm_position + Vector2(-27, 7), RunSettlement.format_time(config.alarm_start_minutes).left(3) + "??", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b35f5b"))
		var hand_y := lerpf(390.0, 118.0, hand_transition_progress)
		draw_rect(Rect2(289, hand_y, 62, 210), Color("8e7b79"))
		draw_circle(Vector2(320, hand_y), 34.0, Color("9b8582"))


func _create_placeholder_alarm() -> AudioStreamWAV:
	# Generated at runtime: no third-party audio or unclear license is introduced.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var sample_count := int(stream.mix_rate * 0.55)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var t := float(index) / float(stream.mix_rate)
		var gate := 1.0 if fmod(t, 0.22) < 0.13 else 0.0
		var sample := int(sin(TAU * 920.0 * t) * 9000.0 * gate)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	stream.data = bytes
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream
