extends Node3D

const STEPS := [
	preload("res://sfx/h06/quick_step_1.res"),
	preload("res://sfx/h06/quick_step_2.res"),
]
const STEP_DB := -28.0
const MIN_STEP_INTERVAL := 0.14

var motion: Node2D
var step_voice: AudioStreamPlayer3D
var _last_steps := 0
var _next_step := 0
var _cooldown := 0.0
var _manager: Node

func configure(body: Node2D) -> void:
	motion = body
	_last_steps = int(motion.gait.total_steps)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 110
	_manager = get_tree().root.get_node_or_null("SFXManager")
	step_voice = AudioStreamPlayer3D.new()
	step_voice.name = "TripodStep"
	step_voice.volume_db = STEP_DB
	step_voice.bus = &"Environment"
	step_voice.max_distance = 42.0
	step_voice.max_polyphony = 1
	step_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	step_voice.panning_strength = 0.6
	add_child(step_voice)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(motion) or motion.dead or not is_instance_valid(motion.model) or not motion.model.is_visible_in_tree() or int(motion.jump) != 0:
		stop_all()
		return
	var player: Node = motion.world.get("player")
	if is_instance_valid(player) and player.get("dead") == true:
		stop_all()
		return

	_cooldown = maxf(_cooldown - delta, 0.0)
	var pitch := float(_manager.current_gameplay_audio_pitch) if is_instance_valid(_manager) else 1.0
	step_voice.pitch_scale = clampf(pitch, 0.05, 3.0)
	var gait: RefCounted = motion.gait
	var steps := int(gait.total_steps)
	var planted := steps > _last_steps
	_last_steps = steps
	# Drop excess contacts while the current step is still audible.
	if not planted or _cooldown > 0.0 or step_voice.playing:
		return

	var at := Vector3.ZERO
	var count := 0
	var planted_group := 1 - int(gait.swing_group)
	for leg: Dictionary in gait.legs:
		if int(leg.group) == planted_group:
			at += leg.plant
			count += 1
	if count == 0:
		return
	step_voice.global_position = at / float(count)
	step_voice.stream = STEPS[_next_step]
	step_voice.play()
	_next_step = 1 - _next_step
	_cooldown = MIN_STEP_INTERVAL

func stop_all() -> void:
	if is_instance_valid(motion) and motion.gait != null:
		_last_steps = int(motion.gait.total_steps)
	if is_instance_valid(step_voice):
		step_voice.stop()
	_cooldown = 0.0
	_next_step = 0
