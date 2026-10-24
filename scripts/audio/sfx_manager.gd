extends Node

signal sfx_played(event_id: StringName)

const CONFIG := preload("res://resources/demo_config.tres")
const MUSIC_STREAMS := {
	&"bedroom": preload("res://sfx/卧室背景音乐.mp3"),
	&"bedroom_short": preload("res://sfx/卧室背景音乐短.mp3"),
	&"safe": preload("res://art/Dream/BGM/Sweet_Vermouth.ogg"),
	&"sweet_vermouth": preload("res://art/Dream/BGM/Sweet_Vermouth.ogg"),
	&"sing_swing_bada_bing": preload("res://art/Dream/BGM/Sing_Swing_Bada_Bing.mp3"),
	&"battle_sing_swing": preload("res://art/Dream/BGM/Sing_Swing_Bada_Bing.mp3"),
	&"groovy_ignition": preload("res://art/Dream/BGM/Groovy_Ignition.mp3"),
	&"battle_groovy": preload("res://art/Dream/BGM/Groovy_Ignition.mp3"),
	&"battle": preload("res://art/Dream/BGM/Sing_Swing_Bada_Bing.mp3"),
	&"battle_short": preload("res://art/Dream/BGM/Sing_Swing_Bada_Bing.mp3"),
	&"elevator": preload("res://art/Dream/BGM/Nocturne_Op9_No2.mp3"),
	&"nocturne": preload("res://art/Dream/BGM/Nocturne_Op9_No2.mp3")
}
const MUSIC_START_OFFSETS := {
	&"safe": 41.0,
	&"sweet_vermouth": 41.0,
	&"sing_swing_bada_bing": 12.0,
	&"battle_sing_swing": 12.0,
	&"battle": 12.0,
	&"battle_short": 12.0,
	&"groovy_ignition": 15.0,
	&"battle_groovy": 15.0
}
const BATTLE_TRACKS: Array[StringName] = [&"sing_swing_bada_bing", &"groovy_ignition"]
const WEATHER_STREAMS := {
	&"rain": preload("res://sfx/雨天.mp3"),
	&"thunder": preload("res://sfx/雨天打雷.mp3"),
	&"wind": preload("res://sfx/大风.mp3"),
	&"stars": preload("res://sfx/普通晚上.mp3"),
	&"overcast": preload("res://sfx/普通晚上.mp3")
}
const STREAMS := {
	&"forbidden": preload("res://sfx/禁止选择音效.mp3"),
	&"death": preload("res://sfx/角色死亡音.mp3"),
	&"new_message": preload("res://sfx/手机新讯息.mp3"),
	&"purchase": preload("res://sfx/购买音效.mp3"),
	&"home_door": preload("res://sfx/回家开门音效.mp3"),
	&"work": preload("res://sfx/上班音效.mp3"),
	&"confirm": preload("res://sfx/确定按钮音效.mp3"),
	&"experience": preload("res://sfx/获取经验值的音效.mp3"),
	&"phone_unlock": preload("res://sfx/手机解锁音效.mp3"),
	&"phone_operation": preload("res://sfx/手机操作按键.mp3"),
	&"bottle_shake": preload("res://sfx/摇晃药瓶.mp3"),
	&"door_knock": preload("res://sfx/敲门.mp3"),
	&"dash": preload("res://sfx/dash.wav"),
	&"phone_buzz": preload("res://sfx/phone_buzz.wav"),
	&"heal": preload("res://sfx/heal.wav"),
	&"glass_shatter": preload("res://sfx/glass_shatter.wav"),
	&"wood_shatter": preload("res://sfx/wood_shatter.wav"),
	&"wilhelm_scream": preload("res://sfx/wilhelm_scream.wav"),
	&"canned_laughter": preload("res://sfx/canned_laughter.wav"),
	&"audience_applause": preload("res://sfx/audience_applause.wav"),
	&"golf_clap": preload("res://sfx/golf_clap.wav"),
	&"rimshot": preload("res://sfx/rimshot.wav"),
	&"vinyl_scratch_brake": preload("res://sfx/vinyl_scratch_brake.wav"),
	## Footstep is deliberately absent from this table.  It is a multi-clip
	## random group rather than a single authored stream, registered separately
	## in _ready() from FOOTSTEP_STREAMS.  Bus and volume stay in EVENT_BUSES /
	## _volume_for so the generic world-event path keeps treating it normally.
	## Official firearm pack events.  Keep these as normal registered players so
	## Player-owned weapon sounds use the existing WorldSFX/time-scale path.
	&"weapon_fire": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Fire - 1.wav"),
	&"weapon_reload": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Reload - 1.wav"),
	&"weapon_pickup": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Equip - 1.wav"),
	&"weapon_dry_fire": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Fire (Dry) - 1.wav"),
	&"gunshot": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Fire - 1.wav"),
	## Legacy aliases remain registered for older scene/script references, but
	## use the same official Dream firearm sample as the unified gunshot event.
	&"pistol_fire": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Fire - 1.wav"),
	&"shotgun_fire": preload("res://art/Dream/gunshot/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Fire - 1.wav"),
	&"melee_hit_1": preload("res://art/Dream/hit/Impact 1.wav"),
	&"melee_hit_2": preload("res://art/Dream/hit/Impact 2.wav"),
	&"melee_hit_3": preload("res://art/Dream/hit/Impact 3.wav"),
	&"melee_hit_4": preload("res://art/Dream/hit/Impact 4.wav"),
	&"enemy_kill": preload("res://sfx/enemy_kill.mp3"),
	&"tarot_shuffle": preload("res://sfx/tarot/tarot_shuffle.wav"),
	&"tarot_deal": preload("res://sfx/tarot/tarot_deal.wav"),
	&"tarot_flip": preload("res://sfx/tarot/tarot_flip.wav"),
	&"tarot_select": preload("res://sfx/tarot/tarot_select.wav"),
	## Elevator cues.  Both deliberately route around the WorldSFX treatment:
	## a floor-arrival prompt must not be pitched or low-passed by the gameplay
	## time-scale path, exactly like the weather bed.
	&"elevator_ding": preload("res://sfx/elevator_candidates/ding_classic_dingdong.wav"),
	&"elevator_badge": preload("res://sfx/elevator_candidates/ding_airy_gong.wav")
}

## Player footstep group: five Kenney concrete single-step recordings (CC0).
## These are separate OGG files, one footfall each, so they cannot be expressed
## as AUTHORED_SOUND_SET_CONFIG time slices over a single WAV.  They are
## instead handed to an AudioStreamRandomizer, which picks a clip per playback
## in random order without repeating the previous one, and applies the pitch
## jitter that keeps a 4.4-steps-per-second walk from sounding mechanical.
const FOOTSTEP_STREAMS := [
	preload("res://sfx/footsteps/concrete/footstep_concrete_000.ogg"),
	preload("res://sfx/footsteps/concrete/footstep_concrete_001.ogg"),
	preload("res://sfx/footsteps/concrete/footstep_concrete_002.ogg"),
	preload("res://sfx/footsteps/concrete/footstep_concrete_003.ogg"),
	preload("res://sfx/footsteps/concrete/footstep_concrete_004.ogg")
]

## The supplied Dream impact recordings are authored multi-clip WAVs.  Their
## quiet gaps were measured from the actual PCM data rather than assuming an
## equal five-way split.  The first five complete regions are the five clips
## used by gameplay; the source WAVs remain untouched in the art folder.
## Each Vector2 stores [start_seconds, end_seconds].
const MELEE_ENEMY_HIT_SOURCE = preload("res://art/wallpaper/近战击打敌人.wav")
const MELEE_FURNITURE_HIT_SOURCE = preload("res://art/wallpaper/近战击打家具.wav")
const BULLET_ENEMY_HIT_SOURCE = preload("res://art/wallpaper/射击被击中.wav")
const MELEE_SWING_SOURCE = preload("res://art/wallpaper/挥动.wav")
const MELEE_ENEMY_HIT_REGIONS := [
	# The first impact begins around 0.66s; retain ~20ms of pre-roll.
	Vector2(0.64, 4.0),
	Vector2(4.90, 8.0),
	Vector2(8.90, 12.0),
	Vector2(12.90, 16.0),
	Vector2(16.90, 20.0),
]
const MELEE_FURNITURE_HIT_REGIONS := [
	# The first impact begins around 0.66s; subsequent clips begin around 0.42s.
	Vector2(0.64, 4.0),
	Vector2(4.90, 8.0),
	Vector2(8.90, 12.0),
	Vector2(12.90, 16.0),
	Vector2(16.90, 20.0),
]
const BULLET_ENEMY_HIT_REGIONS := [
	# The first impact begins around 0.50s; subsequent clips begin around 0.25s.
	Vector2(0.48, 4.0),
	Vector2(4.73, 8.0),
	Vector2(8.73, 12.0),
	Vector2(12.73, 16.0),
	Vector2(16.73, 20.0),
]
const MELEE_SWING_REGIONS := [Vector2(0.0, 0.1068)]
const AUTHORED_SOUND_SET_CONFIG := {
	&"melee_hit_enemy": {
		"source": MELEE_ENEMY_HIT_SOURCE,
		"regions": MELEE_ENEMY_HIT_REGIONS,
		"bus": &"Characters",
		"voices": 8,
	},
	&"melee_hit_furniture": {
		"source": MELEE_FURNITURE_HIT_SOURCE,
		"regions": MELEE_FURNITURE_HIT_REGIONS,
		"bus": &"Environment",
		"voices": 8,
	},
	&"bullet_hit_enemy": {
		"source": BULLET_ENEMY_HIT_SOURCE,
		"regions": BULLET_ENEMY_HIT_REGIONS,
		"bus": &"Characters",
		"voices": 8,
	},
	&"melee_swing": {
		"source": MELEE_SWING_SOURCE,
		"regions": MELEE_SWING_REGIONS,
		"bus": &"Weapons",
		"voices": 6,
	},
}
const EVENT_BUSES := {
	&"forbidden": &"UI",
	&"new_message": &"UI",
	&"purchase": &"UI",
	&"confirm": &"UI",
	&"experience": &"UI",
	&"death": &"Characters",
	&"home_door": &"Environment",
	&"work": &"Environment",
	&"phone_unlock": &"UI",
	&"phone_operation": &"UI",
	&"bottle_shake": &"Environment",
	&"ui_hover": &"UI",
	&"dash": &"Characters",
	&"player_hurt": &"Characters",
	&"weapon_fire": &"Weapons",
	&"weapon_reload": &"Weapons",
	&"weapon_pickup": &"Weapons",
	&"weapon_throw": &"Weapons",
	&"weapon_dry_fire": &"Weapons",
	&"gunshot": &"Weapons",
	&"pistol_fire": &"Weapons",
	&"shotgun_fire": &"Weapons",
	&"melee_hit_1": &"Characters",
	&"melee_hit_2": &"Characters",
	&"melee_hit_3": &"Characters",
	&"melee_hit_4": &"Characters",
	&"melee_hit_enemy": &"Characters",
	&"melee_hit_furniture": &"Environment",
	&"glass_shatter": &"Environment",
	&"wood_shatter": &"Environment",
	&"bullet_hit_enemy": &"Characters",
	&"enemy_kill": &"Characters",
	&"enemy_hit": &"Characters",
	&"body_impact": &"Characters",
	&"wall_impact": &"Environment",
	&"furniture_impact": &"Environment",
	&"melee_swing": &"Weapons",
	&"door_knock": &"Environment",
	&"footstep": &"Characters",
	&"thunder": &"Environment",
	&"crt_off": &"UI",
	&"phone_buzz": &"UI",
	&"heal": &"Characters",
	&"text_blip": &"UI",
	&"slot_tick": &"UI",
	&"watch_tick": &"UI",
	&"watch_tick_early": &"UI",
	&"tarot_shuffle": &"UI",
	&"tarot_deal": &"UI",
	&"tarot_flip": &"UI",
	&"tarot_select": &"UI",
	## The arrival prompt rides the raw SFX bus: it fires mid-transition, and
	## the Environment -> WorldSFX chain would modulate it.  The badge cue is an
	## acquisition confirmation, so it follows the purchase/experience
	## convention and goes to UI (also a direct child of SFX).
	&"elevator_ding": &"SFX",
	&"elevator_badge": &"UI",
	&"enemy_fire_cue": &"SFX",
	&"wilhelm_scream": &"SFX",
	&"canned_laughter": &"SFX",
	&"audience_applause": &"SFX",
	&"golf_clap": &"SFX",
	&"rimshot": &"SFX",
	&"vinyl_scratch_brake": &"UI"
}
const GENERATED_EVENTS := [&"ui_hover", &"player_hurt", &"enemy_hit", &"body_impact", &"wall_impact", &"furniture_impact", &"thunder", &"crt_off", &"text_blip", &"slot_tick", &"watch_tick", &"watch_tick_early", &"enemy_fire_cue"]
const EVENT_MIN_INTERVALS := {
	&"enemy_kill": 0.04,
	&"enemy_hit": 0.025,
	&"melee_hit_enemy": 0.025,
	&"melee_hit_furniture": 0.04,
	&"bullet_hit_enemy": 0.025,
	&"body_impact": 0.08,
	&"wall_impact": 0.10,
	&"furniture_impact": 0.08,
	&"melee_swing": 0.06,
	&"weapon_dry_fire": 0.10,
	&"tarot_shuffle": 0.2,
	&"tarot_deal": 0.05,
	&"tarot_flip": 0.05,
	&"tarot_select": 0.2,
	## Footsteps fire off the walk gait phase, and that phase snaps back to zero
	## the moment the player releases input.  Tapping the stick would otherwise
	## machine-gun the clip; this floor sits below the natural 0.227s step gap,
	## so it only ever trims that pathological case.
	&"footstep": 0.10
}

var players: Dictionary = {}
var sound_sets: Dictionary = {}
var sound_set_players: Dictionary = {}
var sound_set_last_indices: Dictionary = {}
var sound_set_next_voice: Dictionary = {}
var sound_set_buses: Dictionary = {}
var sound_set_stop_times: Dictionary = {}
## Source playback end positions for segmented WAV voices.  Unlike a wall-clock
## timeout, this remains correct when pitch_scale changes during a clip.
var sound_set_stop_positions: Dictionary = {}
var last_event_play_msec: Dictionary = {}
var last_experience_play_msec := -1000000
var last_bottle_shake_play_msec := -1000000
var last_slot_tick_play_msec := -1000000
var last_watch_tick_play_msec := -1000000
var last_watch_tick_early_play_msec := -1000000
var enemy_kill_pitch_random := 1.0
var music_player: AudioStreamPlayer
var weather_player: AudioStreamPlayer
var elevator_rumble_player: AudioStreamPlayer
var elevator_rumble_tween: Tween
var current_music_id: StringName = &""
var current_music_owner_id: int = 0
var current_weather_id: StringName = &""
var music_tween: Tween
var weather_tween: Tween
var music_duck_tween: Tween
var music_duck_reasons: Dictionary = {}
var weather_volume_multiplier: float = 1.0
var music_lowpass: AudioEffectLowPassFilter
var music_muffle_tween: Tween
var last_muffle_paused := false

const WORLD_SFX_BUS: StringName = &"WorldSFX"
const DEFAULT_AUDIO_WORLD_MIN_SCALE := 0.005
const DEFAULT_AUDIO_WORLD_MAX_SCALE := 1.0
const DEFAULT_AUDIO_MIN_PITCH := 0.35
const DEFAULT_AUDIO_MAX_PITCH := 1.0
const DEFAULT_AUDIO_CURVE_EXPONENT := 0.5
const DEFAULT_AUDIO_RESUME_TAU := 0.045
const DEFAULT_AUDIO_SLOWDOWN_TAU := 0.09
const DEFAULT_AUDIO_LOWPASS_MIN_HZ := 2500.0
const DEFAULT_AUDIO_LOWPASS_MAX_HZ := 20000.0
const DEFAULT_AUDIO_3D_MAX_DISTANCE := 64.0
const DEFAULT_AUDIO_3D_UNIT_SIZE := 10.0
const DEFAULT_AUDIO_3D_VOICE_COUNT := 12

## Elevator ride ambience.  A sustained loop is not a one-shot event, so it owns
## a dedicated player (mirroring the weather bed) rather than a registry entry:
## one voice, explicit start/stop, explicit fade in and out.  The clip is
## authored ring-crossfaded so repeats butt up without a gap or a click -- see
## scripts/audio/generate_elevator_sfx.py.
const ELEVATOR_RUMBLE_STREAM := preload("res://sfx/elevator_candidates/rumble_power_station_reuse.wav")
const ELEVATOR_RUMBLE_DB := -4.0
const ELEVATOR_RUMBLE_FADE_IN := 0.55
const ELEVATOR_RUMBLE_FADE_OUT := 0.40

var world_sfx_lowpass: AudioEffectLowPassFilter
var world_3d_voices: Array[AudioStreamPlayer3D] = []
var world_3d_next_voice := 0
var current_gameplay_audio_pitch := 1.0
var current_gameplay_audio_activity := 1.0
var target_gameplay_audio_pitch := 1.0
var target_gameplay_audio_activity := 1.0
var _last_audio_real_usec := 0


static func play_event(event_id: StringName) -> bool:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop == null:
		return false
	var manager := main_loop.root.get_node_or_null("SFXManager")
	return manager.play(event_id) if manager != null else false


## Unified formal weapon-event entry points.  Keeping these wrappers here
## prevents individual weapon scripts from owning sound resources or bypassing
## the shared WorldSFX time-scale processing.
static func play_weapon_fire() -> bool:
	# `gunshot` is the long-standing event observed by existing Dream hooks and
	# tests; it is an alias of the same official Fire recording.  Keeping the
	# compatibility event here avoids a second playback while exposing the
	# explicit weapon API to new callers.
	return play_event(&"gunshot")


static func play_weapon_reload() -> bool:
	return play_event(&"weapon_reload")


static func play_weapon_pickup() -> bool:
	return play_event(&"weapon_pickup")


static func play_weapon_dry_fire() -> bool:
	return play_event(&"weapon_dry_fire")


static func play_weapon_throw() -> bool:
	# No dedicated throw recording in the supplied folder.  The
	# optional API below intentionally remains silent until an appropriate
	# resource is added; Equip/Reload must not be misused as a throw cue.
	return play_event(&"weapon_throw")


static func play_glass_shatter() -> bool:
	return play_event(&"glass_shatter")


static func play_wood_shatter() -> bool:
	return play_event(&"wood_shatter")


static func play_enemy_kill() -> bool:
	return play_event(&"enemy_kill")


static func play_tarot_shuffle() -> bool:
	return play_event(&"tarot_shuffle")


static func play_tarot_deal() -> bool:
	return play_event(&"tarot_deal")


static func play_tarot_flip() -> bool:
	return play_event(&"tarot_flip")


static func play_wilhelm_scream() -> bool:
	return play_event(&"wilhelm_scream")


static func play_tarot_select() -> bool:
	return play_event(&"tarot_select")


## Plays a WorldSFX event from a real 3D world position.  The pool is owned by
## this autoload so high-rate enemy fire does not allocate one node per shot.
## UI, dialogue and menu events are deliberately rejected here; callers must
## use play_event() for those non-world sounds.
static func play_world_sfx_3d(
	event_id: StringName,
	world_position: Vector3,
	volume_offset_db: float = 0.0,
	max_distance: float = -1.0
) -> bool:
	var manager := _manager()
	if manager == null or not manager.has_method("_play_world_sfx_3d"):
		return false
	return bool(manager.call(
		"_play_world_sfx_3d",
		event_id,
		world_position,
		volume_offset_db,
		max_distance
	))


static func stop_event(event_id: StringName) -> void:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop == null:
		return
	var manager := main_loop.root.get_node_or_null("SFXManager")
	if manager != null:
		manager.stop(event_id)


static func play_bedroom_music(use_short: bool = false, owner_id: int = 0) -> void:
	var manager := _manager()
	if manager != null:
		manager.play_music(&"bedroom_short" if use_short else &"bedroom", owner_id)


static func play_safe_music(owner_id: int = 0) -> void:
	var manager := _manager()
	if manager != null:
		manager.play_music(&"sweet_vermouth", owner_id)


static func play_battle_music(use_short: bool = false, owner_id: int = 0, track_id: StringName = &"") -> void:
	var manager := _manager()
	if manager != null:
		var selected_track: StringName = track_id
		if selected_track == &"":
			selected_track = manager.next_battle_track()
		manager.play_music(selected_track, owner_id)


static func trigger_multi_kill_reaction(reaction_id: StringName = &"") -> void:
	var manager := _manager()
	if manager != null:
		manager.play_multi_kill_reaction(reaction_id)


static func finish_combat_music(style: String = "") -> void:
	var manager := _manager()
	if manager != null:
		manager.apply_combat_finish(style)


static func finish_player_death_music() -> void:
	var manager := _manager()
	if manager != null:
		manager.apply_player_death_finish()


static func trigger_combat_duck() -> void:
	var manager := _manager()
	if manager != null:
		manager.apply_combat_duck()


static func play_elevator_music(owner_id: int = 0) -> void:
	var manager := _manager()
	if manager != null:
		manager.apply_elevator_music(owner_id)


static func stop_elevator_music() -> void:
	var manager := _manager()
	if manager != null:
		manager.apply_stop_elevator_music()


static func finish_floor_badge_music() -> void:
	var manager := _manager()
	if manager != null:
		manager.apply_floor_badge_music_finish()


static func play_weather_ambience(weather_type: StringName) -> void:
	var manager := _manager()
	if manager != null:
		manager.play_weather(weather_type)


static func stop_music(fade_duration: float = -1.0, owner_id: int = 0) -> void:
	var manager := _manager()
	if manager != null:
		manager.fade_out_music(CONFIG.music_fade_duration if fade_duration < 0.0 else fade_duration, owner_id)


static func stop_weather_ambience(fade_duration: float = -1.0) -> void:
	var manager := _manager()
	if manager != null:
		manager.fade_out_weather(CONFIG.ambience_fade_duration if fade_duration < 0.0 else fade_duration)


## Elevator ride bed entry points.  The dungeon calls these in lockstep with its
## camera rumble so the shake and the rumble can never disagree about whether a
## ride is in progress.
static func play_elevator_rumble(fade_in: float = ELEVATOR_RUMBLE_FADE_IN) -> void:
	var manager := _manager()
	if manager != null:
		manager.call("_start_elevator_rumble", fade_in)


static func stop_elevator_rumble(fade_out: float = ELEVATOR_RUMBLE_FADE_OUT) -> void:
	var manager := _manager()
	if manager != null:
		manager.call("_stop_elevator_rumble", fade_out)


static func set_weather_volume_multiplier(multiplier: float) -> void:
	var manager := _manager()
	if manager != null:
		manager._apply_weather_volume_multiplier(multiplier)


static func set_music_muffled(muffled: bool) -> void:
	var manager := _manager()
	if manager != null:
		manager._apply_music_muffled(muffled)


static func play_door_knock() -> bool:
	return play_event(&"door_knock")


## Compatibility alias used by older callers.  New code should use the
## explicit enemy/furniture helpers below so the hit target remains clear.
static func play_random_melee_hit() -> bool:
	return play_melee_enemy_hit()


static func play_melee_enemy_hit() -> bool:
	var manager := _manager()
	return manager._play_random_sound_set(&"melee_hit_enemy") if manager != null else false


static func play_melee_furniture_hit() -> bool:
	var manager := _manager()
	return manager._play_random_sound_set(&"melee_hit_furniture") if manager != null else false


static func play_bullet_enemy_hit() -> bool:
	var manager := _manager()
	return manager._play_random_sound_set(&"bullet_hit_enemy") if manager != null else false


static func set_music_duck(reason: StringName, duck_db: float, fade_duration: float) -> void:
	var manager := _manager()
	if manager != null:
		manager.request_music_duck(reason, duck_db, fade_duration)


static func clear_music_duck(reason: StringName, fade_duration: float) -> void:
	var manager := _manager()
	if manager != null:
		manager.release_music_duck(reason, fade_duration)


static func _manager() -> Node:
	var main_loop := Engine.get_main_loop() as SceneTree
	return main_loop.root.get_node_or_null("SFXManager") if main_loop != null else null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_audio_real_usec = Time.get_ticks_usec()
	_ensure_bus(&"SFX")
	_ensure_bus(&"Music")
	_ensure_bus(WORLD_SFX_BUS)
	AudioServer.set_bus_send(AudioServer.get_bus_index(WORLD_SFX_BUS), &"SFX")
	for bus_name in [&"UI", &"Weapons", &"Characters", &"Environment"]:
		_ensure_bus(bus_name)
		AudioServer.set_bus_send(
			AudioServer.get_bus_index(bus_name),
			&"SFX" if bus_name == &"UI" else WORLD_SFX_BUS
		)
	_ensure_world_sfx_lowpass()
	_ensure_music_lowpass()
	for event_id in STREAMS:
		_register_player(event_id, STREAMS[event_id])
	# Footstep rides the ordinary player path so it inherits the Characters bus,
	# the -18 dB trim and the WorldSFX time-scale pitch, but its stream is a
	# randomizer group instead of a single clip.
	_register_player(&"footstep", _build_footstep_randomizer())
	for event_id in GENERATED_EVENTS:
		if not AUTHORED_SOUND_SET_CONFIG.has(event_id):
			_register_player(event_id, _create_placeholder_stream(event_id))
	for event_id_variant in AUTHORED_SOUND_SET_CONFIG.keys():
		var event_id: StringName = StringName(event_id_variant)
		var set_config: Dictionary = AUTHORED_SOUND_SET_CONFIG[event_id]
		_register_sound_set(
			event_id,
			set_config.get("source") as AudioStreamWAV,
			set_config.get("regions", []) as Array,
			StringName(set_config.get("bus", &"Characters")),
			int(set_config.get("voices", 6))
		)
	music_player = _create_unique_player("MusicPlayer", &"Music")
	# Weather ambience is not a gameplay voice: keep it on the unprocessed SFX
	# bus so SUPERHOT WorldSFX pitch/low-pass presentation does not slow or
	# muffle the background bed.  Imported gameplay environment events still use
	# the Environment→WorldSFX route above.
	weather_player = _create_unique_player("WeatherPlayer", &"SFX")
	# Elevator ride bed: same unprocessed-bus rationale as the weather bed, and
	# the loop flag is asserted here so the clip can never start one-shot.
	elevator_rumble_player = _create_unique_player("ElevatorRumblePlayer", &"SFX")
	elevator_rumble_player.stream = ELEVATOR_RUMBLE_STREAM
	_create_world_3d_voice_pool()
	for stream in MUSIC_STREAMS.values():
		_set_loop(stream, true)
	for stream in WEATHER_STREAMS.values():
		_set_loop(stream, true)
	_set_loop(ELEVATOR_RUMBLE_STREAM, true)


func _process(_delta: float) -> void:
	var real_delta := _consume_audio_real_delta()
	_update_gameplay_audio_time(real_delta)
	# 战斗、角色和环境声音随场景树暂停；暂停菜单的UI反馈仍可播放。
	var paused := get_tree().paused
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	for event_id_variant in sound_set_stop_positions.keys():
		var event_id: StringName = StringName(event_id_variant)
		var stop_positions_variant: Variant = sound_set_stop_positions.get(event_id, {})
		if not stop_positions_variant is Dictionary:
			continue
		var stop_positions: Dictionary = stop_positions_variant
		var stop_times_variant: Variant = sound_set_stop_times.get(event_id, {})
		var stop_times: Dictionary = stop_times_variant if stop_times_variant is Dictionary else {}
		for voice_id_variant in stop_positions.keys():
			var voice_id: int = int(voice_id_variant)
			var voice: AudioStreamPlayer = null
			if is_instance_id_valid(voice_id):
				voice = instance_from_id(voice_id) as AudioStreamPlayer
			var source_end: float = float(stop_positions.get(voice_id_variant, 0.0))
			var fallback_stop_at: float = float(stop_times.get(voice_id_variant, 0.0))
			var playback_position := voice.get_playback_position() if voice != null and voice.playing else -1.0
			var reached_source_end := playback_position >= source_end - 0.005
			var reached_fallback_end := fallback_stop_at > 0.0 and now_seconds >= fallback_stop_at
			if voice == null or not voice.playing or reached_source_end or reached_fallback_end:
				if voice != null and voice.playing and (reached_source_end or reached_fallback_end):
					voice.stop()
				stop_positions.erase(voice_id_variant)
				stop_times.erase(voice_id_variant)
	_update_gameplay_audio_voices(paused)
	# 暂停时背景音乐变朦胧（低通滤波），恢复时平滑还原。
	if paused != last_muffle_paused:
		last_muffle_paused = paused
		_apply_music_muffled(paused)
	for event_id in players:
		var player: AudioStreamPlayer = players[event_id]
		if EVENT_BUSES[event_id] != &"UI":
			player.stream_paused = paused
	for event_id_variant in sound_set_players.keys():
		var event_id: StringName = StringName(event_id_variant)
		var voices_variant: Variant = sound_set_players.get(event_id, [])
		if not voices_variant is Array:
			continue
		var bus_name: StringName = StringName(sound_set_buses.get(event_id, &"Characters"))
		if bus_name == &"UI":
			continue
		var voices: Array = voices_variant
		for voice_variant in voices:
			var voice: AudioStreamPlayer = voice_variant as AudioStreamPlayer
			if voice != null:
				voice.stream_paused = paused


func _consume_audio_real_delta() -> float:
	var now_usec: int = Time.get_ticks_usec()
	if _last_audio_real_usec <= 0:
		_last_audio_real_usec = now_usec
		return 1.0 / 60.0
	var real_delta: float = clampf(
		float(now_usec - _last_audio_real_usec) / 1000000.0,
		0.0,
		0.1
	)
	_last_audio_real_usec = now_usec
	return real_delta if real_delta > 0.0 else 1.0 / 60.0


func _config_float(property_name: StringName, fallback: float) -> float:
	var value: Variant = CONFIG.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


func _resolved_world_time_scale() -> float:
	# Pause is a lifecycle state, not the slowest point of Dream time.  Keeping
	# the audio presentation at unity here prevents paused voices from becoming
	# long, low-pitched tails when the menu opens.
	if get_tree().paused:
		return _config_float(&"superhot_max_time_scale", DEFAULT_AUDIO_WORLD_MAX_SCALE)
	var resolved: float = _config_float(&"superhot_max_time_scale", DEFAULT_AUDIO_WORLD_MAX_SCALE)
	var tree := get_tree()
	if tree != null and tree.root != null:
		var controller: Node = tree.root.get_node_or_null("DreamTimeController") as Node
		if controller != null and controller.has_method("get_resolved_time_scale"):
			resolved = float(controller.call("get_resolved_time_scale"))
	var min_scale: float = _config_float(&"superhot_min_time_scale", DEFAULT_AUDIO_WORLD_MIN_SCALE)
	var max_scale: float = _config_float(&"superhot_max_time_scale", DEFAULT_AUDIO_WORLD_MAX_SCALE)
	max_scale = maxf(max_scale, min_scale)
	return clampf(resolved, min_scale, max_scale)


func _update_gameplay_audio_time(real_delta: float) -> void:
	var min_scale: float = _config_float(&"superhot_min_time_scale", DEFAULT_AUDIO_WORLD_MIN_SCALE)
	var max_scale: float = _config_float(&"superhot_max_time_scale", DEFAULT_AUDIO_WORLD_MAX_SCALE)
	max_scale = maxf(max_scale, min_scale + 0.0001)
	var world_scale: float = _resolved_world_time_scale()
	var normalized: float = clampf(
		(world_scale - min_scale) / maxf(max_scale - min_scale, 0.0001),
		0.0,
		1.0
	)
	var exponent: float = maxf(
		_config_float(&"gameplay_sfx_curve_exponent", DEFAULT_AUDIO_CURVE_EXPONENT),
		0.01
	)
	target_gameplay_audio_activity = pow(normalized, exponent)
	var min_pitch: float = _config_float(&"gameplay_sfx_min_pitch", DEFAULT_AUDIO_MIN_PITCH)
	var max_pitch: float = _config_float(&"gameplay_sfx_max_pitch", DEFAULT_AUDIO_MAX_PITCH)
	max_pitch = maxf(max_pitch, min_pitch)
	target_gameplay_audio_pitch = lerpf(min_pitch, max_pitch, target_gameplay_audio_activity)
	var tau: float = (
		_config_float(&"gameplay_sfx_resume_tau", DEFAULT_AUDIO_RESUME_TAU)
		if target_gameplay_audio_pitch > current_gameplay_audio_pitch
		else _config_float(&"gameplay_sfx_slowdown_tau", DEFAULT_AUDIO_SLOWDOWN_TAU)
	)
	tau = maxf(tau, 0.001)
	var alpha: float = clampf(1.0 - exp(-real_delta / tau), 0.0, 1.0)
	current_gameplay_audio_pitch = lerpf(
		current_gameplay_audio_pitch,
		target_gameplay_audio_pitch,
		alpha
	)
	current_gameplay_audio_activity = lerpf(
		current_gameplay_audio_activity,
		target_gameplay_audio_activity,
		alpha
	)
	if world_sfx_lowpass != null:
		var lowpass_min: float = _config_float(&"gameplay_sfx_lowpass_min_hz", DEFAULT_AUDIO_LOWPASS_MIN_HZ)
		var lowpass_max: float = _config_float(&"gameplay_sfx_lowpass_max_hz", DEFAULT_AUDIO_LOWPASS_MAX_HZ)
		world_sfx_lowpass.cutoff_hz = lerpf(lowpass_min, maxf(lowpass_max, lowpass_min), current_gameplay_audio_activity)


func _update_gameplay_audio_voices(paused: bool) -> void:
	var pitch: float = 1.0 if paused else current_gameplay_audio_pitch
	for event_id_variant in players.keys():
		var event_id: StringName = StringName(event_id_variant)
		if not _is_world_event(event_id):
			continue
		var player: AudioStreamPlayer = players[event_id] as AudioStreamPlayer
		if player != null:
			if event_id == &"enemy_kill":
				player.pitch_scale = pitch * enemy_kill_pitch_random
			else:
				player.pitch_scale = pitch
	for event_id_variant in sound_set_players.keys():
		var event_id: StringName = StringName(event_id_variant)
		var bus_name: StringName = StringName(sound_set_buses.get(event_id, &"Characters"))
		if not _is_world_bus(bus_name):
			continue
		var voices_variant: Variant = sound_set_players.get(event_id, [])
		if not voices_variant is Array:
			continue
		for voice_variant in (voices_variant as Array):
			var voice: AudioStreamPlayer = voice_variant as AudioStreamPlayer
			if voice != null:
				voice.pitch_scale = pitch
	for voice in world_3d_voices:
		if voice != null and is_instance_valid(voice):
			voice.pitch_scale = pitch
			voice.stream_paused = paused


func _is_world_bus(bus_name: StringName) -> bool:
	return bus_name != &"UI" and bus_name != &"Music"


func _is_world_event(event_id: StringName) -> bool:
	return EVENT_BUSES.has(event_id) and _is_world_bus(StringName(EVENT_BUSES[event_id]))


func _register_player(event_id: StringName, stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "SFX_" + str(event_id)
	player.stream = stream
	player.bus = EVENT_BUSES[event_id]
	player.volume_db = _volume_for(event_id)
	if event_id in [&"gunshot", &"weapon_fire", &"pistol_fire", &"shotgun_fire", &"enemy_kill"]:
		player.max_polyphony = 8
	elif event_id in [&"tarot_deal", &"tarot_flip"]:
		player.max_polyphony = 4
	elif event_id == &"enemy_fire_cue":
		player.max_polyphony = 4
	elif event_id == &"footstep":
		# At 4.4 steps per second the tail of one footfall can still be ringing
		# when the next begins; overlapping voices keep the gait continuous
		# instead of truncating every step.
		player.max_polyphony = 4
	add_child(player)
	players[event_id] = player


func _build_footstep_randomizer() -> AudioStreamRandomizer:
	var randomizer := AudioStreamRandomizer.new()
	# PLAYBACK_RANDOM_NO_REPEATS supplies the "random order" the gait calls for
	# while never letting the same clip land twice in a row.
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	# ±5% pitch jitter.  AudioStreamPlayer.pitch_scale still carries the WorldSFX
	# time-scale on top and the two multiply, so slow motion stays coherent.
	randomizer.random_pitch = 1.05
	var slot := 0
	for stream_variant in FOOTSTEP_STREAMS:
		var footstep: AudioStream = stream_variant as AudioStream
		if footstep != null:
			randomizer.add_stream(slot, footstep)
			slot += 1
	return randomizer


func _register_sound_set(
	event_id: StringName,
	source: AudioStreamWAV,
	regions: Array,
	bus_name: StringName,
	voice_count: int
) -> void:
	if source == null:
		return
	var valid_regions: Array = []
	for region_variant in regions:
		var region: Vector2 = Vector2(region_variant)
		if region.y > region.x and region.x >= 0.0:
			valid_regions.append(region)
	if valid_regions.is_empty():
		valid_regions.append(Vector2(0.0, maxf(source.get_length(), 0.001)))
	# A sound-set stores measured playback windows over the original imported
	# stream.  This is important for the project's QOA-imported WAVs: slicing
	# compressed bytes would make an invalid AudioStreamWAV.  Each voice starts
	# at its selected region and is stopped at that region's measured end.
	sound_sets[event_id] = {"source": source, "regions": valid_regions}
	sound_set_players[event_id] = []
	sound_set_last_indices[event_id] = -1
	sound_set_next_voice[event_id] = 0
	sound_set_buses[event_id] = bus_name
	sound_set_stop_times[event_id] = {}
	sound_set_stop_positions[event_id] = {}
	var safe_voice_count: int = clampi(voice_count, 2, 12)
	var voices: Array = sound_set_players[event_id]
	for voice_index in range(safe_voice_count):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%s_Voice_%02d" % [String(event_id), voice_index]
		player.bus = bus_name
		player.volume_db = _volume_for(event_id)
		add_child(player)
		voices.append(player)

func play(event_id: StringName) -> bool:
	if sound_sets.has(event_id):
		return _play_random_sound_set(event_id)
	if not players.has(event_id):
		return false
	if event_id == &"experience":
		var now := Time.get_ticks_msec()
		if now - last_experience_play_msec < int(CONFIG.sfx_experience_min_interval * 1000.0):
			return false
		last_experience_play_msec = now
	elif event_id == &"bottle_shake":
		var shake_now := Time.get_ticks_msec()
		if shake_now - last_bottle_shake_play_msec < int(CONFIG.sfx_bottle_shake_min_interval * 1000.0):
			return false
		last_bottle_shake_play_msec = shake_now
	elif event_id == &"slot_tick":
		var tick_now := Time.get_ticks_msec()
		if tick_now - last_slot_tick_play_msec < int(CONFIG.sfx_slot_tick_min_interval * 1000.0):
			return false
		last_slot_tick_play_msec = tick_now
	elif event_id == &"watch_tick":
		var watch_now := Time.get_ticks_msec()
		if watch_now - last_watch_tick_play_msec < int(CONFIG.sfx_watch_tick_min_interval * 1000.0):
			return false
		last_watch_tick_play_msec = watch_now
	elif event_id == &"watch_tick_early":
		var watch_early_now := Time.get_ticks_msec()
		if watch_early_now - last_watch_tick_early_play_msec < int(CONFIG.sfx_watch_tick_early_min_interval * 1000.0):
			return false
		last_watch_tick_early_play_msec = watch_early_now
	var player: AudioStreamPlayer = players[event_id]
	if EVENT_MIN_INTERVALS.has(event_id):
		var now_msec := Time.get_ticks_msec()
		var last_msec := int(last_event_play_msec.get(event_id, -1000000))
		if now_msec - last_msec < int(float(EVENT_MIN_INTERVALS[event_id]) * 1000.0):
			return false
		last_event_play_msec[event_id] = now_msec
	if event_id == &"enemy_kill":
		enemy_kill_pitch_random = randf_range(0.97, 1.03)
		var base_pitch: float = 1.0 if get_tree().paused else current_gameplay_audio_pitch
		player.pitch_scale = base_pitch * enemy_kill_pitch_random
	elif event_id == &"tarot_flip":
		player.pitch_scale = randf_range(0.96, 1.04)
	if player.max_polyphony <= 1:
		player.stop()
	player.play()
	_check_combat_duck(event_id)
	sfx_played.emit(event_id)
	return true


func _play_random_melee_hit() -> bool:
	return _play_random_sound_set(&"melee_hit_enemy")


func _play_random_sound_set(event_id: StringName) -> bool:
	var sound_set_variant: Variant = sound_sets.get(event_id, {})
	if not sound_set_variant is Dictionary:
		return false
	var sound_set: Dictionary = sound_set_variant
	var regions_variant: Variant = sound_set.get("regions", [])
	if not regions_variant is Array:
		return false
	var regions: Array = regions_variant
	if regions.is_empty():
		return false
	var source: AudioStreamWAV = sound_set.get("source") as AudioStreamWAV
	if source == null:
		return false
	if EVENT_MIN_INTERVALS.has(event_id):
		var now_msec: int = Time.get_ticks_msec()
		var last_msec: int = int(last_event_play_msec.get(event_id, -1000000))
		if now_msec - last_msec < int(float(EVENT_MIN_INTERVALS[event_id]) * 1000.0):
			return false
		last_event_play_msec[event_id] = now_msec
	var last_index: int = int(sound_set_last_indices.get(event_id, -1))
	var clip_index: int = randi_range(0, regions.size() - 1)
	if regions.size() > 1 and clip_index == last_index:
		clip_index = (clip_index + 1) % regions.size()
	sound_set_last_indices[event_id] = clip_index
	var voices_variant: Variant = sound_set_players.get(event_id, [])
	if not voices_variant is Array:
		return false
	var voices: Array = voices_variant
	if voices.is_empty():
		return false
	var selected_voice: AudioStreamPlayer = null
	for voice_variant in voices:
		var voice: AudioStreamPlayer = voice_variant as AudioStreamPlayer
		if voice != null and not voice.playing:
			selected_voice = voice
			break
	if selected_voice == null:
		var next_voice: int = int(sound_set_next_voice.get(event_id, 0)) % voices.size()
		sound_set_next_voice[event_id] = (next_voice + 1) % voices.size()
		selected_voice = voices[next_voice] as AudioStreamPlayer
	if selected_voice == null:
		return false
	var region: Vector2 = Vector2(regions[clip_index])
	if region.y <= region.x:
		return false
	selected_voice.stream = source
	selected_voice.volume_db = _volume_for(event_id)
	selected_voice.pitch_scale = current_gameplay_audio_pitch
	selected_voice.play(region.x)
	var stop_times_variant: Variant = sound_set_stop_times.get(event_id, {})
	if not stop_times_variant is Dictionary:
		stop_times_variant = {}
	var stop_times: Dictionary = stop_times_variant
	var voice_id := selected_voice.get_instance_id()
	# Keep a generous wall-clock fallback for audio backends that report no
	# playback position in headless mode.  The normal path below uses the source
	# position and therefore remains correct when pitch changes mid-clip.
	var minimum_pitch := _config_float(&"gameplay_sfx_min_pitch", DEFAULT_AUDIO_MIN_PITCH)
	stop_times[voice_id] = Time.get_ticks_msec() / 1000.0 + (region.y - region.x) / maxf(minimum_pitch, 0.05) + 0.5
	var stop_positions_variant: Variant = sound_set_stop_positions.get(event_id, {})
	if not stop_positions_variant is Dictionary:
		stop_positions_variant = {}
	var stop_positions: Dictionary = stop_positions_variant
	stop_positions[voice_id] = region.y
	_check_combat_duck(event_id)
	sfx_played.emit(event_id)
	return true


func stop(event_id: StringName) -> void:
	if players.has(event_id):
		(players[event_id] as AudioStreamPlayer).stop()
	var voices_variant: Variant = sound_set_players.get(event_id, [])
	if voices_variant is Array:
		for voice_variant in (voices_variant as Array):
			var voice: AudioStreamPlayer = voice_variant as AudioStreamPlayer
			if voice != null:
				voice.stop()
	var stop_times_variant: Variant = sound_set_stop_times.get(event_id, {})
	if stop_times_variant is Dictionary:
		(stop_times_variant as Dictionary).clear()
	var stop_positions_variant: Variant = sound_set_stop_positions.get(event_id, {})
	if stop_positions_variant is Dictionary:
		(stop_positions_variant as Dictionary).clear()


var battle_track_index: int = 0
var multi_kill_duck_tween: Tween = null


func next_battle_track() -> StringName:
	var track: StringName = BATTLE_TRACKS[battle_track_index % BATTLE_TRACKS.size()]
	battle_track_index = (battle_track_index + 1) % BATTLE_TRACKS.size()
	return track


func play_multi_kill_reaction(reaction_id: StringName = &"") -> void:
	var chosen: StringName = reaction_id
	if chosen == &"":
		var options := [&"canned_laughter", &"audience_applause", &"golf_clap"]
		chosen = options[randi() % options.size()]
	play_event(chosen)

	# Sidechain ducking: 1.5s duck combat BGM by -4.5dB
	request_music_duck(&"multi_kill_reaction", -4.5, 0.08)
	if multi_kill_duck_tween != null and multi_kill_duck_tween.is_valid():
		multi_kill_duck_tween.kill()
	var duck_tw := create_tween()
	duck_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	duck_tw.tween_interval(1.5)
	duck_tw.tween_callback(func() -> void:
		release_music_duck(&"multi_kill_reaction", 0.4)
	)
	multi_kill_duck_tween = duck_tw


func apply_combat_finish(style: String = "") -> void:
	if style.is_empty():
		style = CONFIG.combat_finish_style if ("combat_finish_style" in CONFIG) else "both"
	if not is_instance_valid(music_player) or not music_player.playing:
		return
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	if multi_kill_duck_tween != null and multi_kill_duck_tween.is_valid():
		multi_kill_duck_tween.kill()

	current_music_id = &""
	current_music_owner_id = 0

	match style:
		"rimshot":
			music_player.stop()
			music_player.pitch_scale = 1.0
			play_event(&"rimshot")
		"tape_stop":
			play_event(&"vinyl_scratch_brake")
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(music_player, "pitch_scale", 0.05, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				music_player.stop()
				music_player.pitch_scale = 1.0
			)
			music_tween = tw
		"both", _:
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(music_player, "pitch_scale", 0.05, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				music_player.stop()
				music_player.pitch_scale = 1.0
				play_event(&"rimshot")
			)
			music_tween = tw


const COMBAT_DUCK_EVENTS: Array[StringName] = [
	&"weapon_fire", &"gunshot", &"pistol_fire", &"shotgun_fire",
	&"enemy_fire_cue", &"melee_hit_enemy", &"bullet_hit_enemy",
	&"melee_swing", &"enemy_hit", &"player_hurt"
]
var combat_duck_tween: Tween = null


func apply_combat_duck() -> void:
	var duck_db: float = float(CONFIG.combat_duck_db) if ("combat_duck_db" in CONFIG) else -7.0
	var hold: float = float(CONFIG.combat_duck_hold_duration) if ("combat_duck_hold_duration" in CONFIG) else 0.8
	var release: float = float(CONFIG.combat_duck_release_duration) if ("combat_duck_release_duration" in CONFIG) else 0.5
	request_music_duck(&"combat_fire", duck_db, 0.04)
	if combat_duck_tween != null and combat_duck_tween.is_valid():
		combat_duck_tween.kill()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(hold)
	tw.tween_callback(func() -> void:
		release_music_duck(&"combat_fire", release)
	)
	combat_duck_tween = tw


func apply_player_death_finish() -> void:
	if not is_instance_valid(music_player) or not music_player.playing:
		return
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	if combat_duck_tween != null and combat_duck_tween.is_valid():
		combat_duck_tween.kill()
	if multi_kill_duck_tween != null and multi_kill_duck_tween.is_valid():
		multi_kill_duck_tween.kill()

	current_music_id = &""
	current_music_owner_id = 0

	var stop_seconds: float = float(CONFIG.player_death_tape_stop_seconds) if ("player_death_tape_stop_seconds" in CONFIG) else 0.4
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(music_player, "pitch_scale", 0.05, stop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		music_player.stop()
		music_player.pitch_scale = 1.0
	)
	music_tween = tw


func apply_elevator_music(owner_id: int = 0) -> void:
	if not MUSIC_STREAMS.has(&"elevator"):
		return
	if current_music_id in [&"elevator", &"nocturne"] and is_instance_valid(music_player) and music_player.playing:
		return
	var stream: AudioStream = MUSIC_STREAMS[&"elevator"]
	var total_length := stream.get_length() if stream != null else 0.0
	# 随机进度播放，不得离结束小于 30s
	var max_offset := maxf(0.0, total_length - 30.0)
	var random_offset := randf_range(0.0, max_offset) if max_offset > 0.0 else 0.0
	play_music(&"elevator", owner_id, random_offset)


func apply_stop_elevator_music() -> void:
	if current_music_id in [&"elevator", &"nocturne"]:
		current_music_id = &""
		current_music_owner_id = 0
		if is_instance_valid(music_player):
			music_player.stop()


func apply_floor_badge_music_finish() -> void:
	if not is_instance_valid(music_player) or not music_player.playing:
		play_event(&"elevator_badge")
		return
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	if combat_duck_tween != null and combat_duck_tween.is_valid():
		combat_duck_tween.kill()
	if multi_kill_duck_tween != null and multi_kill_duck_tween.is_valid():
		multi_kill_duck_tween.kill()

	current_music_id = &""
	current_music_owner_id = 0

	# 瞬间磁带停转不被其他声音打扰：临时将 WORLD_SFX_BUS 屏蔽静音
	var world_bus_idx := AudioServer.get_bus_index(WORLD_SFX_BUS)
	if world_bus_idx >= 0:
		AudioServer.set_bus_mute(world_bus_idx, true)

	# 播放电梯卡音效（在UI总线上，不受WorldSFX静音影响，清脆可闻）
	play_event(&"elevator_badge")
	play_event(&"vinyl_scratch_brake")

	# 0.3s 磁带减速断电停转
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(music_player, "pitch_scale", 0.05, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		music_player.stop()
		music_player.pitch_scale = 1.0
		if world_bus_idx >= 0:
			AudioServer.set_bus_mute(world_bus_idx, false)
	)
	music_tween = tw


func _check_combat_duck(event_id: StringName) -> void:
	if event_id in COMBAT_DUCK_EVENTS:
		apply_combat_duck()


func play_music(track_id: StringName, owner_id: int = 0, start_offset: float = -1.0) -> void:
	if not MUSIC_STREAMS.has(track_id) or not is_instance_valid(music_player):
		return
	var owner_changed := owner_id != 0 and owner_id != current_music_owner_id
	if owner_changed:
		# 场景切换时清除上一场升级UI留下的临时Duck；玩家Music Bus设置不在此处改写。
		music_duck_reasons.clear()
		if music_duck_tween != null and music_duck_tween.is_valid():
			music_duck_tween.kill()
		music_player.volume_db = _music_target_volume_db()
	current_music_owner_id = owner_id
	if current_music_id == track_id and music_player.playing:
		music_player.stream_paused = false
		return
	current_music_id = track_id
	var offset: float = start_offset if start_offset >= 0.0 else float(MUSIC_START_OFFSETS.get(track_id, 0.0))
	_crossfade_unique(music_player, MUSIC_STREAMS[track_id], CONFIG.music_fade_duration, true, offset)


func play_weather(weather_type: StringName) -> void:
	if not WEATHER_STREAMS.has(weather_type) or not is_instance_valid(weather_player):
		fade_out_weather(CONFIG.ambience_fade_duration)
		return
	if current_weather_id == weather_type and weather_player.playing:
		return
	current_weather_id = weather_type
	_crossfade_unique(weather_player, WEATHER_STREAMS[weather_type], CONFIG.ambience_fade_duration, false)


func fade_out_music(duration: float, owner_id: int = 0) -> void:
	# 旧场景的_exit_tree可能晚于新场景_ready执行；它只能停止自己拥有的音乐。
	if owner_id != 0 and current_music_owner_id != owner_id:
		return
	current_music_id = &""
	current_music_owner_id = 0
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_tween = _fade_out_player(music_player, duration, music_tween)


func fade_out_weather(duration: float) -> void:
	current_weather_id = &""
	weather_tween = _fade_out_player(weather_player, duration, weather_tween)


## Starts the elevator ride bed with a fade in.
##
## Idempotent by design: if the bed is already audible this only re-asserts the
## target level instead of restarting the clip, because restarting a loop is an
## audible click and a repeated call is a legitimate case (a transition can be
## superseded while the ride is still under way).
func _start_elevator_rumble(fade_in: float = ELEVATOR_RUMBLE_FADE_IN) -> void:
	if not is_instance_valid(elevator_rumble_player):
		return
	if elevator_rumble_tween != null and elevator_rumble_tween.is_valid():
		elevator_rumble_tween.kill()
	var duration := maxf(fade_in, 0.01)
	if elevator_rumble_player.playing:
		var resume := create_tween()
		resume.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		resume.tween_property(elevator_rumble_player, "volume_db", ELEVATOR_RUMBLE_DB, duration)
		elevator_rumble_tween = resume
		return
	elevator_rumble_player.volume_db = -60.0
	elevator_rumble_player.play()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(elevator_rumble_player, "volume_db", ELEVATOR_RUMBLE_DB, duration)
	elevator_rumble_tween = tween


## Fades the elevator ride bed out.  Safe to call when it is not playing, so the
## abort/rollback paths can call it unconditionally.
func _stop_elevator_rumble(fade_out: float = ELEVATOR_RUMBLE_FADE_OUT) -> void:
	if not is_instance_valid(elevator_rumble_player):
		return
	if elevator_rumble_tween != null and elevator_rumble_tween.is_valid():
		elevator_rumble_tween.kill()
	elevator_rumble_tween = _fade_out_player(elevator_rumble_player, maxf(fade_out, 0.0), null)


## True while the ride bed is (still) producing sound, including fades.
func is_elevator_rumble_active() -> bool:
	return is_instance_valid(elevator_rumble_player) and elevator_rumble_player.playing


func _music_target_volume_db() -> float:
	var base: float = float(CONFIG.music_baseline_volume_db) if ("music_baseline_volume_db" in CONFIG) else -6.0
	return base + _current_music_duck_db()


func request_music_duck(reason: StringName, duck_db: float, fade_duration: float) -> void:
	if reason == &"":
		return
	music_duck_reasons[reason] = minf(0.0, duck_db)
	_tween_music_volume(_music_target_volume_db(), fade_duration)


func release_music_duck(reason: StringName, fade_duration: float) -> void:
	music_duck_reasons.erase(reason)
	_tween_music_volume(_music_target_volume_db(), fade_duration)


func _current_music_duck_db() -> float:
	var result := 0.0
	for value in music_duck_reasons.values():
		result = minf(result, float(value))
	return result


func _tween_music_volume(target_db: float, duration: float) -> void:
	if not is_instance_valid(music_player) or not music_player.playing:
		return
	if music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = create_tween()
	music_duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_duck_tween.tween_property(music_player, "volume_db", target_db, maxf(duration, 0.001))


func _create_unique_player(player_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _create_world_3d_voice_pool() -> void:
	world_3d_voices.clear()
	var configured_count: int = int(_config_float(
		&"gameplay_sfx_3d_voice_count",
		DEFAULT_AUDIO_3D_VOICE_COUNT
	))
	var voice_count: int = clampi(configured_count, 4, 32)
	var max_distance: float = maxf(
		_config_float(&"gameplay_sfx_3d_max_distance", DEFAULT_AUDIO_3D_MAX_DISTANCE),
		4.0
	)
	var unit_size: float = maxf(
		_config_float(&"gameplay_sfx_3d_unit_size", DEFAULT_AUDIO_3D_UNIT_SIZE),
		0.01
	)
	for voice_index in range(voice_count):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "WorldSFX3D_%02d" % voice_index
		voice.bus = WORLD_SFX_BUS
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.max_distance = max_distance
		voice.unit_size = unit_size
		voice.panning_strength = 1.0
		# Godot's first attenuation enum is inverse distance.  Assigning the
		# numeric enum keeps this pool compatible with minor 4.x enum renames.
		voice.attenuation_model = 0
		voice.max_polyphony = 1
		add_child(voice)
		world_3d_voices.append(voice)


func _play_world_sfx_3d(
	event_id: StringName,
	world_position: Vector3,
	volume_offset_db: float = 0.0,
	max_distance: float = -1.0
) -> bool:
	if not _is_world_event(event_id) or world_3d_voices.is_empty():
		return false
	var stream: AudioStream = null
	if players.has(event_id):
		var registered: AudioStreamPlayer = players[event_id] as AudioStreamPlayer
		if registered != null:
			stream = registered.stream
	if stream == null and STREAMS.has(event_id):
		stream = STREAMS[event_id] as AudioStream
	if stream == null or not world_position.is_finite():
		return false
	var selected: AudioStreamPlayer3D = null
	for voice in world_3d_voices:
		if voice != null and is_instance_valid(voice) and not voice.playing:
			selected = voice
			break
	if selected == null:
		var next_index: int = world_3d_next_voice % world_3d_voices.size()
		world_3d_next_voice = (next_index + 1) % world_3d_voices.size()
		selected = world_3d_voices[next_index]
	if selected == null or not is_instance_valid(selected):
		return false
	selected.stop()
	selected.stream = stream
	selected.global_position = world_position
	selected.volume_db = _volume_for(event_id) + volume_offset_db
	if EVENT_BUSES.has(event_id):
		selected.bus = EVENT_BUSES[event_id]
	else:
		selected.bus = WORLD_SFX_BUS
	selected.unit_size = maxf(
		_config_float(&"gameplay_sfx_3d_unit_size", DEFAULT_AUDIO_3D_UNIT_SIZE),
		0.01
	)
	selected.max_distance = max_distance if max_distance > 0.0 else maxf(
		_config_float(&"gameplay_sfx_3d_max_distance", DEFAULT_AUDIO_3D_MAX_DISTANCE),
		4.0
	)
	selected.pitch_scale = current_gameplay_audio_pitch
	selected.stream_paused = get_tree().paused
	selected.play()
	_check_combat_duck(event_id)
	sfx_played.emit(event_id)
	return true


func _crossfade_unique(player: AudioStreamPlayer, stream: AudioStream, duration: float, is_music: bool, from_position: float = 0.0) -> void:
	if is_music and music_duck_tween != null and music_duck_tween.is_valid():
		music_duck_tween.kill()
	var active_tween: Tween = music_tween if is_music else weather_tween
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var half := maxf(duration * 0.5, 0.0)
	var settle_volume := _crossfade_settle_volume(is_music)
	if player.playing and half > 0.0:
		tween.tween_property(player, "volume_db", -60.0, half)
	tween.tween_callback(func() -> void:
		player.stop()
		player.pitch_scale = 1.0
		player.stream = stream
		player.volume_db = -60.0 if duration > 0.0 else settle_volume
		player.play(from_position)
	)
	if duration > 0.0:
		tween.tween_property(player, "volume_db", settle_volume, maxf(duration - half, 0.01))
	if is_music:
		music_tween = tween
	else:
		weather_tween = tween


func _crossfade_settle_volume(is_music: bool) -> float:
	if is_music:
		return _music_target_volume_db()
	if weather_volume_multiplier < 1.0:
		return linear_to_db(weather_volume_multiplier)
	return 0.0


func _apply_weather_volume_multiplier(multiplier: float) -> void:
	weather_volume_multiplier = clampf(multiplier, 0.0, 1.0)
	if not is_instance_valid(weather_player):
		return
	if weather_tween != null and weather_tween.is_valid():
		weather_tween.kill()
	var target_db := linear_to_db(weather_volume_multiplier)
	weather_player.volume_db = target_db
	if weather_player.playing:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(weather_player, "volume_db", target_db, 0.2)
		weather_tween = tween


func _fade_out_player(player: AudioStreamPlayer, duration: float, active_tween: Tween) -> Tween:
	if not is_instance_valid(player) or not player.playing:
		return active_tween
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if duration > 0.0:
		tween.tween_property(player, "volume_db", -60.0, duration)
	tween.tween_callback(func() -> void: player.stop(); player.volume_db = 0.0)
	return tween


func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		stream.loop = enabled
	elif stream is AudioStreamOggVorbis:
		stream.loop = enabled
	elif stream is AudioStreamWAV:
		# AudioStreamWAV was previously unsupported here, so every imported WAV
		# was silently stuck one-shot: MP3/OGG were the only formats that could
		# ever loop.  loop_end == 0 means "loop to the end of the sample", and it
		# is used as the fallback because a frame count cannot be read straight
		# off QOA-compressed data.
		var wav := stream as AudioStreamWAV
		if not enabled:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return
		var frames := int(round(wav.get_length() * float(wav.mix_rate)))
		wav.loop_begin = 0
		wav.loop_end = frames if frames > 0 else 0
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _ensure_world_sfx_lowpass() -> void:
	var bus_index: int = AudioServer.get_bus_index(WORLD_SFX_BUS)
	if bus_index < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var existing: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if existing is AudioEffectLowPassFilter:
			world_sfx_lowpass = existing as AudioEffectLowPassFilter
			world_sfx_lowpass.cutoff_hz = _config_float(&"gameplay_sfx_lowpass_max_hz", DEFAULT_AUDIO_LOWPASS_MAX_HZ)
			return
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = _config_float(&"gameplay_sfx_lowpass_max_hz", DEFAULT_AUDIO_LOWPASS_MAX_HZ)
	AudioServer.add_bus_effect(bus_index, lowpass)
	world_sfx_lowpass = lowpass


func _ensure_music_lowpass() -> void:
	var bus_index := AudioServer.get_bus_index(&"Music")
	if bus_index < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var existing := AudioServer.get_bus_effect(bus_index, effect_index)
		if existing is AudioEffectLowPassFilter:
			music_lowpass = existing
			music_lowpass.cutoff_hz = _music_clear_cutoff()
			return
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = _music_clear_cutoff()
	AudioServer.add_bus_effect(bus_index, lowpass)
	music_lowpass = lowpass


func _music_clear_cutoff() -> float:
	return 20000.0


## 暂停时把音乐总线的低通截止频率降到配置值（朦胧效果），恢复时平滑升回。
func _apply_music_muffled(muffled: bool) -> void:
	if music_lowpass == null:
		return
	if music_muffle_tween != null and music_muffle_tween.is_valid():
		music_muffle_tween.kill()
	var target := CONFIG.music_muffled_cutoff_hz if muffled else _music_clear_cutoff()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(music_lowpass, "cutoff_hz", target, CONFIG.music_muffled_fade_seconds)
	music_muffle_tween = tween


func _volume_for(event_id: StringName) -> float:
	match event_id:
		&"forbidden": return CONFIG.sfx_forbidden_volume_db
		&"death": return CONFIG.sfx_death_volume_db
		&"new_message": return CONFIG.sfx_new_message_volume_db
		&"purchase": return CONFIG.sfx_purchase_volume_db
		&"home_door": return CONFIG.sfx_home_door_volume_db
		&"work": return CONFIG.sfx_work_volume_db
		&"confirm": return CONFIG.sfx_confirm_volume_db
		&"experience": return CONFIG.sfx_experience_volume_db
		&"phone_unlock": return CONFIG.sfx_phone_unlock_volume_db
		&"phone_operation": return CONFIG.sfx_phone_operation_volume_db
		&"bottle_shake": return CONFIG.sfx_bottle_shake_volume_db
		&"ui_hover": return CONFIG.sfx_ui_hover_volume_db
		&"dash": return CONFIG.sfx_dash_volume_db
		&"player_hurt": return CONFIG.sfx_player_hurt_volume_db
		&"weapon_fire": return CONFIG.sfx_weapon_fire_volume_db
		&"weapon_reload": return CONFIG.sfx_weapon_reload_volume_db
		&"weapon_pickup": return CONFIG.sfx_weapon_pickup_volume_db
		&"weapon_throw": return CONFIG.sfx_weapon_throw_volume_db
		&"weapon_dry_fire": return CONFIG.sfx_weapon_dry_fire_volume_db
		&"gunshot": return CONFIG.sfx_weapon_fire_volume_db
		&"pistol_fire": return CONFIG.sfx_pistol_fire_volume_db
		&"shotgun_fire": return CONFIG.sfx_shotgun_fire_volume_db
		&"glass_shatter", &"wood_shatter": return CONFIG.sfx_melee_hit_furniture_volume_db
		&"footstep": return -18.0
		&"enemy_fire_cue": return -12.0
		&"melee_hit_1", &"melee_hit_2", &"melee_hit_3", &"melee_hit_4", &"melee_hit_enemy": return CONFIG.sfx_melee_hit_enemy_volume_db
		&"bullet_hit_enemy": return CONFIG.sfx_bullet_hit_enemy_volume_db
		&"melee_hit_furniture": return CONFIG.sfx_melee_hit_furniture_volume_db
		&"enemy_kill": return CONFIG.sfx_enemy_kill_volume_db
		&"enemy_hit": return CONFIG.sfx_enemy_hit_volume_db
		&"body_impact": return CONFIG.sfx_body_impact_volume_db
		&"wall_impact": return CONFIG.sfx_wall_impact_volume_db
		&"furniture_impact": return CONFIG.sfx_furniture_impact_volume_db
		&"melee_swing": return CONFIG.sfx_melee_swing_volume_db
		&"door_knock": return CONFIG.sfx_door_knock_volume_db
		&"thunder": return CONFIG.sfx_thunder_volume_db
		&"phone_buzz": return CONFIG.sfx_phone_buzz_volume_db
		&"heal": return CONFIG.sfx_heal_volume_db
		&"text_blip": return CONFIG.dialogue_text_blip_volume_db
		&"slot_tick": return CONFIG.sfx_slot_tick_volume_db
		&"watch_tick": return CONFIG.sfx_watch_tick_volume_db
		&"watch_tick_early": return CONFIG.sfx_watch_tick_early_volume_db
		&"tarot_shuffle", &"tarot_deal", &"tarot_flip", &"tarot_select": return 0.0
		# Both elevator cues are peak-normalised at authoring time, so these are
		# modest trims that keep them level with home_door (-10) without the
		# long airy tail becoming intrusive.
		&"elevator_ding": return -11.0
		&"elevator_badge": return -13.0
		&"wilhelm_scream": return -4.0
		&"canned_laughter": return CONFIG.sfx_canned_laughter_volume_db if ("sfx_canned_laughter_volume_db" in CONFIG) else -6.0
		&"audience_applause": return CONFIG.sfx_audience_applause_volume_db if ("sfx_audience_applause_volume_db" in CONFIG) else -6.0
		&"golf_clap": return CONFIG.sfx_golf_clap_volume_db if ("sfx_golf_clap_volume_db" in CONFIG) else -6.0
		&"rimshot": return CONFIG.sfx_rimshot_volume_db if ("sfx_rimshot_volume_db" in CONFIG) else -4.0
		&"vinyl_scratch_brake": return 0.0
		_: return 0.0


func _create_placeholder_stream(event_id: StringName) -> AudioStreamWAV:
	if event_id==&"enemy_fire_cue": return _create_enemy_fire_ding()
	if event_id == &"watch_tick": return _create_watch_tick()
	if event_id == &"watch_tick_early": return _create_watch_tick_early()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	stream.stereo = false
	var duration := 0.06
	var start_frequency: float = CONFIG.sfx_ui_hover_tone_hz
	var end_frequency: float = CONFIG.sfx_ui_hover_tone_hz * 0.72
	match event_id:
		&"text_blip":
			duration = CONFIG.dialogue_text_blip_duration
			start_frequency = CONFIG.dialogue_text_blip_frequency_hz
			end_frequency = CONFIG.dialogue_text_blip_frequency_hz * 0.82
		&"dash":
			duration = 0.11
			start_frequency = 180.0
			end_frequency = 760.0
		&"player_hurt":
			duration = 0.09
			start_frequency = 170.0
			end_frequency = 85.0
		&"weapon_fire":
			duration = 0.07
			start_frequency = 310.0
			end_frequency = 120.0
		&"pistol_fire":
			duration = 0.055
			start_frequency = 240.0
			end_frequency = 105.0
		&"shotgun_fire":
			duration = 0.14
			start_frequency = 135.0
			end_frequency = 48.0
		&"enemy_kill":
			duration = 0.12
			start_frequency = 360.0
			end_frequency = 70.0
		&"enemy_hit":
			duration = 0.045
			start_frequency = 520.0
			end_frequency = 260.0
		&"body_impact":
			duration = 0.10
			start_frequency = 110.0
			end_frequency = 58.0
		&"wall_impact":
			duration = 0.075
			start_frequency = 150.0
			end_frequency = 72.0
		&"furniture_impact":
			duration = 0.095
			start_frequency = 185.0
			end_frequency = 78.0
		&"melee_swing":
			duration = 0.085
			start_frequency = 720.0
			end_frequency = 220.0
		&"door_knock":
			duration = 0.19
			start_frequency = 92.0
			end_frequency = 54.0
		&"thunder":
			duration = 0.65
			start_frequency = 78.0
			end_frequency = 34.0
		&"crt_off":
			duration = 0.32
			start_frequency = 620.0
			end_frequency = 58.0
		&"heal":
			# 升调正向 blip：短促上扬，区别于受伤降调。
			duration = 0.16
			start_frequency = 420.0
			end_frequency = 880.0
		&"slot_tick":
			# 原创45ms低音量像素铃声；单播放器重触发并配合最短间隔限制叠音。
			duration = 0.045
			start_frequency = 760.0
			end_frequency = 610.0
	var sample_count := int(stream.mix_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count)
	if event_id == &"phone_buzz":
		_fill_phone_buzz(stream, bytes)
		stream.data = bytes
		return stream
	var phase := 0.0
	for index in sample_count:
		var progress := float(index) / float(maxi(1, sample_count - 1))
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / float(stream.mix_rate)
		var square := 1.0 if sin(phase) >= 0.0 else -1.0
		if event_id == &"text_blip":
			# 原创柔和短音：正弦为主、少量三角波，单播放器重触发避免叠加爆音。
			var sine := sin(phase)
			var triangle := asin(sin(phase)) * (2.0 / PI)
			square = sine * 0.82 + triangle * 0.18
		if event_id == &"shotgun_fire":
			var noise := sin(float(index * 73 + 19))
			square = square * 0.68 + noise * 0.32
		var envelope := pow(1.0 - progress, 1.6)
		if event_id == &"ui_hover" and progress > 0.58:
			envelope += pow(1.0 - (progress - 0.58) / 0.42, 2.0) * 0.16
		if event_id == &"crt_off" and progress > 0.82:
			envelope += pow(1.0 - (progress - 0.82) / 0.18, 2.0) * 0.5
		var amplitude := 15.0 if event_id == &"text_blip" else (16.0 if event_id == &"ui_hover" else (48.0 if event_id == &"shotgun_fire" else 34.0))
		bytes[index] = clampi(int(128.0 + square * amplitude * envelope), 0, 255)
	stream.data = bytes
	return stream



func _create_watch_tick() -> AudioStreamWAV:
	# Soft mechanical watch click for option hover (menus / settings rows / controls).
	# Warm ~1.15kHz; not the harsh square slot_tick and not the bright early pass.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var duration := 0.028
	var count := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / float(stream.mix_rate)
		var attack := minf(t / 0.0008, 1.0)
		var env := attack * exp(-t * 110.0) * clampf((duration - t) / 0.005, 0.0, 1.0)
		# Body ~1.15kHz + soft 2nd partial; warmer / less piercing than 1.7kHz early.
		var body := sin(TAU * 1150.0 * t) * 0.78 + sin(TAU * 2300.0 * t) * 0.12 * exp(-t * 180.0)
		var noise := 0.0
		if t < 0.0015:
			var n := fmod(sin(float(i) * 19.191 + 41.7) * 29157.13, 1.0)
			noise = (n * 2.0 - 1.0) * 0.14 * (1.0 - t / 0.0015)
		var sample := (body + noise) * env * 0.34
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream


func _create_watch_tick_early() -> AudioStreamWAV:
	# First (pre-soften) watch tick: brighter ~1.7kHz mechanical click for volume drag.
	# Crisp / shorter than soft watch_tick; still sine+noise, not square slot_tick.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var duration := 0.022
	var count := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / float(stream.mix_rate)
		var attack := minf(t / 0.0005, 1.0)
		var env := attack * exp(-t * 145.0) * clampf((duration - t) / 0.004, 0.0, 1.0)
		var body := sin(TAU * 1700.0 * t) * 0.82 + sin(TAU * 3400.0 * t) * 0.22 * exp(-t * 150.0)
		var noise := 0.0
		if t < 0.0020:
			var n := fmod(sin(float(i) * 19.191 + 41.7) * 29157.13, 1.0)
			noise = (n * 2.0 - 1.0) * 0.22 * (1.0 - t / 0.0020)
		var sample := (body + noise) * env * 0.40
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream


func _create_enemy_fire_ding() -> AudioStreamWAV:
	# Original short bell, rounded attack and bounded polyphony avoid harsh clicks.
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=44100
	var count:=int(.095*stream.mix_rate)
	var bytes:=PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t:=float(i)/stream.mix_rate
		var envelope:=minf(t/.0015,1.0)*exp(-t*48.0)*clampf((.095-t)/.008,0,1)
		var bell:=sin(TAU*1480*t)+.28*sin(TAU*2960*t)*exp(-t*25.0)
		bytes.encode_s16(i*2,int(clampf(bell*envelope*.38,-1,1)*32767))
	stream.data=bytes
	return stream

## 临时程序化手机震动音效（占位，待人工替换 res://sfx/手机震动.wav）：
## 低沉（约 145Hz）短包络 buzz，两段振动中间留与视觉震动相同的停顿，
## 音画同步：第一轮震动→第一声 buzz，第二轮震动→第二声 buzz。
func _fill_phone_buzz(stream: AudioStreamWAV, bytes: PackedByteArray) -> void:
	var step := maxf(CONFIG.phone_vibration_step_duration, 0.01)
	var pause := maxf(CONFIG.phone_vibration_pause_duration, 0.0)
	var rounds := maxi(1, int(CONFIG.phone_vibration_rounds))
	var burst_seconds := step * 5.0
	var total_seconds := burst_seconds * float(rounds) + pause * float(rounds - 1)
	var sample_count := int(stream.mix_rate * total_seconds)
	bytes.resize(sample_count)
	var phase := 0.0
	var buzz_hz := 145.0
	var tremolo_hz := 26.0
	for index in sample_count:
		var t := float(index) / float(stream.mix_rate)
		# 判断当前采样落在第几段振动内，段间为静音停顿。
		var cycle := burst_seconds + pause
		var local := fmod(t, cycle) if rounds > 1 else t
		var envelope := 0.0
		if local < burst_seconds:
			var burst_progress := local / burst_seconds
			var attack := clampf(burst_progress / 0.06, 0.0, 1.0)
			var release := clampf((1.0 - burst_progress) / 0.12, 0.0, 1.0)
			envelope = minf(attack, release)
		phase += TAU * buzz_hz / float(stream.mix_rate)
		var square := 1.0 if sin(phase) >= 0.0 else -1.0
		var tremolo := 0.62 + 0.38 * sin(TAU * tremolo_hz * t)
		bytes[index] = clampi(int(128.0 + square * tremolo * envelope * 30.0), 0, 255)
