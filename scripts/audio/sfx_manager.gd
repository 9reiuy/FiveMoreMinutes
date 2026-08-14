extends Node

signal sfx_played(event_id: StringName)

const CONFIG := preload("res://resources/demo_config.tres")
const MUSIC_STREAMS := {
	&"bedroom": preload("res://sfx/卧室背景音乐.mp3"),
	&"bedroom_short": preload("res://sfx/卧室背景音乐短.mp3"),
	&"battle": preload("res://sfx/游戏中战斗音乐.mp3"),
	&"battle_short": preload("res://sfx/游戏中战斗音乐短.mp3")
}
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
	&"laser": preload("res://sfx/激光武器音效.mp3"),
	&"home_door": preload("res://sfx/回家开门音效.mp3"),
	&"work": preload("res://sfx/上班音效.mp3"),
	&"confirm": preload("res://sfx/确定按钮音效.mp3"),
	&"experience": preload("res://sfx/获取经验值的音效.mp3"),
	&"phone_unlock": preload("res://sfx/手机解锁音效.mp3"),
	&"phone_operation": preload("res://sfx/手机操作按键.mp3"),
	&"bottle_shake": preload("res://sfx/摇晃药瓶.mp3"),
	&"door_knock": preload("res://sfx/敲门.mp3")
}
const EVENT_BUSES := {
	&"forbidden": &"UI",
	&"new_message": &"UI",
	&"purchase": &"UI",
	&"confirm": &"UI",
	&"experience": &"UI",
	&"laser": &"Weapons",
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
	&"pistol_fire": &"Weapons",
	&"shotgun_fire": &"Weapons",
	&"enemy_kill": &"Characters",
	&"door_knock": &"Environment",
	&"thunder": &"Environment",
	&"crt_off": &"UI",
	&"phone_buzz": &"UI",
	&"heal": &"Characters",
	&"text_blip": &"UI",
	&"slot_tick": &"UI"
}
const GENERATED_EVENTS := [&"ui_hover", &"dash", &"player_hurt", &"weapon_fire", &"pistol_fire", &"shotgun_fire", &"enemy_kill", &"thunder", &"crt_off", &"phone_buzz", &"heal", &"text_blip", &"slot_tick"]

var players: Dictionary = {}
var last_experience_play_msec := -1000000
var last_bottle_shake_play_msec := -1000000
var last_slot_tick_play_msec := -1000000
var music_player: AudioStreamPlayer
var weather_player: AudioStreamPlayer
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


static func play_event(event_id: StringName) -> bool:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop == null:
		return false
	var manager := main_loop.root.get_node_or_null("SFXManager")
	return manager.play(event_id) if manager != null else false


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


static func play_battle_music(use_short: bool = false, owner_id: int = 0) -> void:
	var manager := _manager()
	if manager != null:
		manager.play_music(&"battle_short" if use_short else &"battle", owner_id)


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
	_ensure_bus(&"SFX")
	_ensure_bus(&"Music")
	for bus_name in [&"UI", &"Weapons", &"Characters", &"Environment"]:
		_ensure_bus(bus_name)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), &"SFX")
	_ensure_weapon_lowpass()
	_ensure_music_lowpass()
	for event_id in STREAMS:
		_register_player(event_id, STREAMS[event_id])
	for event_id in GENERATED_EVENTS:
		_register_player(event_id, _create_placeholder_stream(event_id))
	music_player = _create_unique_player("MusicPlayer", &"Music")
	weather_player = _create_unique_player("WeatherPlayer", &"Environment")
	for stream in MUSIC_STREAMS.values():
		_set_loop(stream, true)
	for stream in WEATHER_STREAMS.values():
		_set_loop(stream, true)


func _process(_delta: float) -> void:
	# 战斗、角色和环境声音随场景树暂停；暂停菜单的UI反馈仍可播放。
	var paused := get_tree().paused
	# 暂停时背景音乐变朦胧（低通滤波），恢复时平滑还原。
	if paused != last_muffle_paused:
		last_muffle_paused = paused
		_apply_music_muffled(paused)
	for event_id in players:
		var player: AudioStreamPlayer = players[event_id]
		if EVENT_BUSES[event_id] != &"UI":
			player.stream_paused = paused


func _register_player(event_id: StringName, stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "SFX_" + str(event_id)
	player.stream = stream
	player.bus = EVENT_BUSES[event_id]
	player.volume_db = _volume_for(event_id)
	add_child(player)
	players[event_id] = player


func play(event_id: StringName) -> bool:
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
	var player: AudioStreamPlayer = players[event_id]
	player.stop()
	player.play()
	sfx_played.emit(event_id)
	return true


func stop(event_id: StringName) -> void:
	if players.has(event_id):
		(players[event_id] as AudioStreamPlayer).stop()


func play_music(track_id: StringName, owner_id: int = 0) -> void:
	if not MUSIC_STREAMS.has(track_id) or not is_instance_valid(music_player):
		return
	var owner_changed := owner_id != 0 and owner_id != current_music_owner_id
	if owner_changed:
		# 场景切换时清除上一场升级UI留下的临时Duck；玩家Music Bus设置不在此处改写。
		music_duck_reasons.clear()
		if music_duck_tween != null and music_duck_tween.is_valid():
			music_duck_tween.kill()
		music_player.volume_db = 0.0
	current_music_owner_id = owner_id
	if current_music_id == track_id and music_player.playing:
		music_player.stream_paused = false
		return
	current_music_id = track_id
	_crossfade_unique(music_player, MUSIC_STREAMS[track_id], CONFIG.music_fade_duration, true)


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


func request_music_duck(reason: StringName, duck_db: float, fade_duration: float) -> void:
	if reason == &"":
		return
	music_duck_reasons[reason] = minf(0.0, duck_db)
	_tween_music_volume(_current_music_duck_db(), fade_duration)


func release_music_duck(reason: StringName, fade_duration: float) -> void:
	music_duck_reasons.erase(reason)
	_tween_music_volume(_current_music_duck_db(), fade_duration)


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


func _crossfade_unique(player: AudioStreamPlayer, stream: AudioStream, duration: float, is_music: bool) -> void:
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
		player.stream = stream
		player.volume_db = -60.0 if duration > 0.0 else settle_volume
		player.play()
	)
	if duration > 0.0:
		tween.tween_property(player, "volume_db", settle_volume, maxf(duration - half, 0.01))
	if is_music:
		music_tween = tween
	else:
		weather_tween = tween


func _crossfade_settle_volume(is_music: bool) -> float:
	if is_music:
		return _current_music_duck_db()
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


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _ensure_weapon_lowpass() -> void:
	var bus_index := AudioServer.get_bus_index(&"Weapons")
	if bus_index < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var existing := AudioServer.get_bus_effect(bus_index, effect_index)
		if existing is AudioEffectLowPassFilter:
			existing.cutoff_hz = CONFIG.sfx_weapon_lowpass_cutoff_hz
			return
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = CONFIG.sfx_weapon_lowpass_cutoff_hz
	AudioServer.add_bus_effect(bus_index, lowpass)


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
		&"laser": return CONFIG.sfx_laser_volume_db
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
		&"pistol_fire": return CONFIG.sfx_pistol_fire_volume_db
		&"shotgun_fire": return CONFIG.sfx_shotgun_fire_volume_db
		&"enemy_kill": return CONFIG.sfx_enemy_kill_volume_db
		&"door_knock": return CONFIG.sfx_door_knock_volume_db
		&"thunder": return CONFIG.sfx_thunder_volume_db
		&"phone_buzz": return CONFIG.sfx_phone_buzz_volume_db
		&"heal": return CONFIG.sfx_heal_volume_db
		&"text_blip": return CONFIG.dialogue_text_blip_volume_db
		&"slot_tick": return CONFIG.sfx_slot_tick_volume_db
		_: return 0.0


func _create_placeholder_stream(event_id: StringName) -> AudioStreamWAV:
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
