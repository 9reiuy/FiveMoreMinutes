extends Node3D
## Platform recording of one Paris metro arrival, stop and departure.
## The voices sit on the train, so distance follows the real carriage.

const ROLL := preload("res://sfx/metro/metro_roll.wav")
const BRAKE := preload("res://sfx/metro/metro_brake.wav")
const START := preload("res://sfx/metro/metro_start.wav")
const DOOR_OPEN := preload("res://sfx/metro/door_air_open.wav")
const DOOR_CLOSE := preload("res://sfx/metro/door_air_close.wav")

var train: AnimatableBody3D
var roll_voice: AudioStreamPlayer3D
var brake_voice: AudioStreamPlayer3D
var start_voice: AudioStreamPlayer3D
var door_voice: AudioStreamPlayer3D
var heard_phase := ""
var door_open_played := false
var door_close_played := false
var arrival_engaged := false


func _ready() -> void:
	train = get_parent() as AnimatableBody3D
	roll_voice = _voice("MetroRoll", ROLL, true, -8.0, Vector3(0.0, 1.3, 0.35))
	brake_voice = _voice("MetroBrake", BRAKE, false, -2.5, Vector3(0.0, 0.8, 0.55))
	start_voice = _voice("MetroStart", START, false, -4.0, Vector3(0.0, 1.5, 0.2))
	door_voice = _voice("MetroDoorAir", DOOR_OPEN, false, -1.0, Vector3(0.0, 1.45, 1.2))


func _physics_process(_delta: float) -> void:
	if train == null:
		return
	var phase := str(train.phase)
	if phase != heard_phase:
		_enter_phase(phase)
		heard_phase = phase
	var duration := maxf(float(train.journey_duration), 0.01)
	var travelled := float(train.journey_time)
	if phase == "ARRIVING":
		var speed := _journey_speed(travelled / duration)
		roll_voice.volume_db = lerpf(-24.0, -7.0, speed)
		roll_voice.pitch_scale = lerpf(0.94, 1.05, speed)
		if not arrival_engaged:
			arrival_engaged = true
			_restart(start_voice, -6.0)
		if start_voice.playing and travelled > 1.25:
			_fade(start_voice, 0.3)
		if not brake_voice.playing and travelled >= duration - BRAKE.get_length():
			_fade(roll_voice, 0.45)
			brake_voice.play()
	elif phase == "DEPARTING":
		var speed := _journey_speed(travelled / duration)
		if roll_voice.playing:
			roll_voice.volume_db = lerpf(-18.0, -8.0, speed)
			roll_voice.pitch_scale = lerpf(0.97, 1.06, speed)


func _enter_phase(phase: String) -> void:
	match phase:
		"ARRIVING":
			arrival_engaged = false
			door_open_played = false
			_stop_now(brake_voice)
			_restart(roll_voice, -24.0)
		"DOCKED":
			_fade(roll_voice, 0.25)
			_fade(start_voice, 0.12)
			_fade(brake_voice, 0.2)
			if bool(train.doors_wanted_open) and float(train.door_fraction) < 1.0:
				_play_door(true)
		"CLOSING":
			_play_door(false)
		"DEPARTING":
			arrival_engaged = false
			_stop_now(brake_voice)
			_fade(roll_voice, 0.15)
			_restart(start_voice, -4.0)
		"AWAY":
			_fade(roll_voice, 0.7)
			_fade(start_voice, 0.45)


func _play_door(open: bool) -> void:
	if open:
		if door_open_played:
			return
		door_open_played = true
		door_close_played = false
		door_voice.stream = DOOR_OPEN
	else:
		if door_close_played:
			return
		door_close_played = true
		door_open_played = false
		door_voice.stream = DOOR_CLOSE
	_restart(door_voice, -1.0)


func _journey_speed(progress: float) -> float:
	var x := clampf(progress, 0.0, 1.0)
	return clampf(30.0 * x * x * (1.0 - x) * (1.0 - x) / 1.875, 0.0, 1.0)


func _voice(title: String, stream: AudioStream, looping: bool, db: float, at: Vector3) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = title
	voice.bus = &"Environment"
	voice.volume_db = db
	voice.unit_size = 16.0
	voice.max_distance = 120.0
	voice.attenuation_model = 0
	voice.panning_strength = 1.0
	voice.position = at
	if looping and stream is AudioStreamWAV:
		var looped := stream.duplicate() as AudioStreamWAV
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		voice.stream = looped
	else:
		voice.stream = stream
	add_child(voice)
	return voice


func _restart(voice: AudioStreamPlayer3D, db: float) -> void:
	_kill_fade(voice)
	voice.volume_db = db
	voice.play()


func _fade(voice: AudioStreamPlayer3D, seconds: float) -> void:
	if not is_instance_valid(voice) or not voice.playing:
		return
	_kill_fade(voice)
	var tween := create_tween()
	voice.set_meta(&"fade", tween)
	tween.tween_property(voice, "volume_db", -42.0, seconds)
	tween.tween_callback(voice.stop)


func _kill_fade(voice: AudioStreamPlayer3D) -> void:
	if not voice.has_meta(&"fade"):
		return
	var fade: Variant = voice.get_meta(&"fade")
	if fade is Tween and (fade as Tween).is_valid():
		(fade as Tween).kill()
	voice.remove_meta(&"fade")


func _stop_now(voice: AudioStreamPlayer3D) -> void:
	if is_instance_valid(voice) and voice.playing:
		voice.stop()
