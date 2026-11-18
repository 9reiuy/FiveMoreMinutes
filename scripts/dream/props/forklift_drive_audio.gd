extends Node3D
## Quiet vehicle-owned voices; driving physics owns every playback decision.
const MOTOR := preload("res://sfx/forklift/motor.res")
const BOOST := preload("res://sfx/forklift/boost.res")
const SKID := preload("res://sfx/forklift/skid.res")
const MOTOR_DB := -28.0
const BOOST_DB := -24.0
const SKID_DB := -26.0
const SILENT_DB := -70.0

var motor: AudioStreamPlayer3D
var boost: AudioStreamPlayer3D
var skid: AudioStreamPlayer3D
var _boosting := false
var _manager: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_manager = get_tree().root.get_node_or_null("SFXManager")
	motor = _voice("Motor", MOTOR)
	boost = _voice("Boost", BOOST)
	skid = _voice("Skid", SKID)


func _voice(label: String, sound: AudioStream) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = label
	voice.stream = sound
	voice.bus = &"Environment"
	# Keep positional panning and max-distance falloff without near-field gain.
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	voice.max_distance = 32.0
	voice.max_polyphony = 1
	voice.panning_strength = 0.6
	voice.volume_db = SILENT_DB
	add_child(voice)
	return voice


func sync_motion(speed_ratio: float, boosting: bool, skidding: bool, delta: float) -> void:
	var ratio := clampf(speed_ratio, 0.0, 1.7)
	var moving := ratio > 0.035
	var time_pitch := float(_manager.current_gameplay_audio_pitch) if is_instance_valid(_manager) else 1.0
	if moving and not motor.playing:
		motor.play()
	_blend(motor, moving, MOTOR_DB - 4.0 * (1.0 - minf(ratio, 1.0)),
		(0.86 + 0.22 * ratio) * time_pitch, delta)
	# A held key or rejected cooldown must never retrigger the one-shot.
	if boosting and not _boosting:
		boost.volume_db = SILENT_DB
		boost.play()
	_boosting = boosting
	_blend(boost, boosting, BOOST_DB, time_pitch, delta)
	if skidding and moving and not skid.playing:
		skid.play()
	_blend(skid, skidding and moving, SKID_DB - 5.0 * (1.0 - minf(ratio, 1.0)),
		0.88 * time_pitch, delta)


func _blend(voice: AudioStreamPlayer3D, audible: bool, gain: float, pitch: float, delta: float) -> void:
	voice.pitch_scale = clampf(pitch, 0.05, 3.0)
	voice.volume_db = move_toward(voice.volume_db, gain if audible else SILENT_DB, 480.0 * delta)
	if not audible and voice.volume_db <= SILENT_DB:
		voice.stop()


func stop_all() -> void:
	_boosting = false
	for voice in [motor, boost, skid]:
		if is_instance_valid(voice):
			voice.stop()
			voice.volume_db = SILENT_DB
