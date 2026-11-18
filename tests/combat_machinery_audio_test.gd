extends "res://tests/h06_crawler_cargo_test.gd"
## Real arena cargo/rig plus the shared explosion owners and muted native mix.
const SFX := preload("res://scripts/audio/sfx_manager.gd")
var played: Array[StringName] = []
var captured: Array[Dictionary] = []
var manager: Node
var tap: AudioEffectCapture
var probe_bus := -1

class Walker extends Node:
	var body: Node2D
	var enabled := false
	var phase := 0.0
	var center: Vector3
	func _physics_process(delta: float) -> void:
		if enabled and is_instance_valid(body):
			phase += 2.5 * delta
			body.move_toward_point(center+Vector3(cos(phase),0,sin(phase))*3.6,delta)

func stop_global_voices() -> void:
	for voice: AudioStreamPlayer3D in manager.world_3d_voices:voice.stop()

func event_voice(id: StringName) -> AudioStreamPlayer3D:
	for voice: AudioStreamPlayer3D in manager.world_3d_voices:
		if voice.playing and voice.stream==SFX.STREAMS[id]:return voice
	return null

func route_voice(voice: AudioStreamPlayer3D) -> void:
	if tap!=null:voice.bus=&"CombatAudioProbe"

func read_mix(label: String, audible: bool) -> void:
	if tap==null:return
	await create_timer(.08,true,false,true).timeout
	tap.clear_buffer()
	await create_timer(.16,true,false,true).timeout
	var data := tap.get_buffer(tap.get_frames_available())
	var peak_value := 0.0
	var power := 0.0
	for sample in data:
		peak_value=maxf(peak_value,maxf(absf(sample.x),absf(sample.y)))
		power+=sample.length_squared()
	var level := {"label":label,"frames":data.size(),"peak_dbfs":linear_to_db(maxf(peak_value,1e-8)),
		"rms_dbfs":linear_to_db(maxf(sqrt(power/maxf(1.,data.size()*2.)),1e-8))}
	captured.append(level)
	check(data.size()>1000 and float(level.peak_dbfs)>-85. and float(level.peak_dbfs)<-23. if audible else peak_value<.00003,
		label+" has quiet real audio" if audible else label+" is silent in the real mixer")

func run() -> void:
	create_timer(80.,true,false,true).timeout.connect(func():quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	var native := DisplayServer.get_name()!="headless"
	if native:preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled=false
	Engine.time_scale=1.;Engine.max_fps=60
	manager=root.get_node("SFXManager")
	manager.sfx_played.connect(func(id: StringName):played.append(id))
	print("COMBAT_MACHINERY_AUDIO_PID=",OS.get_process_id())
	await prepare_match(18296)
	if native:check(RenderingServer.get_current_rendering_method()=="forward_plus","actual arena uses project Forward+ rendering")
	check(SFX.STREAMS[&"explosion"].resource_path=="res://sfx/combat_machinery/explosion.res" and SFX.STREAMS[&"container_impact"].resource_path=="res://sfx/combat_machinery/container_impact.res","both selected impacts are registered independently")
	check(SFX.STREAMS[&"wall_break"].resource_path=="res://sfx/destruction/wall_break.wav","ordinary wall destruction keeps its existing recording")
	check(manager._volume_for(&"explosion")==-27. and manager._volume_for(&"container_impact")==-28.,"explosion and container events have quiet authored trims")
	check(preload("res://scripts/testing/metro_station/train_derailment.gd").CRASH==SFX.STREAMS[&"explosion"],"train coupling explosions use the same selected recording")
	if native:
		AudioServer.add_bus();probe_bus=AudioServer.bus_count-1
		AudioServer.set_bus_name(probe_bus,&"CombatAudioProbe");AudioServer.set_bus_send(probe_bus,&"Environment")
		tap=AudioEffectCapture.new();tap.buffer_length=.6;AudioServer.add_bus_effect(probe_bus,tap)
	stop_global_voices()
	var near: Vector3=world.get_gameplay_world_position(world.player.global_position,.5)
	var burn: Node3D=preload("res://scripts/dream/burning_effects.gd").install(world)
	played.clear();burn.explosion(near)
	var blast := event_voice(&"explosion")
	check(blast!=null and played==[&"explosion"],"a real shared gameplay explosion emits one new sound without a wall-break double")
	check(blast.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED and blast.bus==&"Environment","explosion retains the Environment bus without near-field amplification")
	route_voice(blast);await read_mix("explosion",true)
	stop_global_voices();played.clear()
	var debris := preload("res://scripts/dream/units/unit_death_effect.gd").new()
	var unit_model := Node3D.new();world.add_child(unit_model);world.add_child(debris)
	debris.begin(unit_model,false,world);debris.burst()
	check(played==[&"explosion"],"robot/drone death routes once through the shared new explosion")
	debris.queue_free();stop_global_voices()
	manager._play_world_sfx_3d(&"wall_break",near)
	var wall := event_voice(&"wall_break")
	check(wall!=null and wall.attenuation_model==AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,"reusing a quiet pooled voice restores ordinary event attenuation")
	stop_global_voices();played.clear()
	arm_drops()
	var first: CARGO.Drop=cargo.drops[0]
	# The release deliberately aims near H06. Move its real six-leg footprint
	# away so this case tests floor landing, rather than a hit-and-break stun.
	var clear := PLAN.ARENA_DECK.grow(-5.)
	var far := clear.position
	for corner: Vector2 in [clear.position,clear.end,Vector2(clear.end.x,clear.position.y),Vector2(clear.position.x,clear.end.y)]:
		if corner.distance_squared_to(first.rect.get_center())>far.distance_squared_to(first.rect.get_center()):far=corner
	move_mech(far)
	world._place_feet(first.rect.get_center()+Vector2(0,4.9))
	for frame in 200:
		await tick()
		if first.phase==CARGO.Phase.LANDED:break
	check(first.phase==CARGO.Phase.LANDED and (first.body.collision_layer&4)!=0,"the real suspended container reaches the floor and becomes solid cover")
	check(played.count(&"container_impact")==1 and not played.has(&"wall_break"),"one real container landing triggers only its selected metal impact")
	var cargo_voice := event_voice(&"container_impact")
	check(cargo_voice!=null and cargo_voice.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED,"container landing uses a quiet positional voice")
	route_voice(cargo_voice);await read_mix("container landing",true)
	played.clear()
	cargo._break(first,first.rect.get_center(),&"cargo_floor")
	check(played.is_empty(),"a landing that immediately breaks on a vehicle does not add a louder duplicate")
	stop_global_voices()
	var body: MOTION=world.crawler_motion
	body.teleport(BOSS_MARK_3D,0.)
	world._place_feet(PLAN.BOSS_MARK+Vector2(0.,4.5))
	world._update_camera_and_actor_projection(10.)
	var audio: Node3D=body.move_audio
	var step_voice: AudioStreamPlayer3D=audio.step_voice
	check(audio.get_parent()==body.model and audio.get_child_count()==1 and step_voice.max_polyphony==1,"the six-legged model owns a single non-overlapping walking voice")
	check(audio.STEPS.size()==2 and audio.STEPS.all(func(stream: AudioStream): return stream.get_length()<audio.MIN_STEP_INTERVAL),"both short step variants fit within the minimum interval")
	check(step_voice.bus==&"Environment" and step_voice.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED,"crawler voice uses existing sound settings without close-range gain")
	route_voice(step_voice)
	await frames(8)
	check(not step_voice.playing,"standing still does not start crawler movement audio")
	var walker := Walker.new()
	walker.body = body
	walker.center = BOSS_MARK_3D
	walker.process_physics_priority = 99
	world.add_child(walker)
	var before := int(body.gait.total_steps)
	walker.enabled=true
	var used: Dictionary = {}
	for frame in 90:
		await physics_frame
		if step_voice.playing:
			used[step_voice.stream.resource_path]=true
	check(int(body.gait.total_steps)>before+3 and used.size()==2,"rapid actual tripod motion alternates both short impacts")
	await read_mix("single-voice crawler movement",true)
	paused=true;await process_frame;await process_frame
	check(audio.process_mode==Node.PROCESS_MODE_PAUSABLE and (not step_voice.playing or step_voice.stream_paused),"pausing the game suspends the crawler voice")
	await read_mix("paused crawler",false)
	paused=false;await frames(4)
	check(not step_voice.stream_paused,"resuming the game resumes the crawler audio path")
	walker.enabled=false
	await frames(75)
	check(not step_voice.playing,"stopping leaves no footstep tails")
	await read_mix("stationary crawler",false)
	stop_global_voices()
	walker.enabled=true;await frames(15);walker.enabled=false
	check(body.begin_jump(body.model.position+Vector3(0,0,.5)),"the actual crawler can begin its existing jump")
	await frames(3)
	check(not step_voice.playing,"jump preparation/flight cannot leave walking sounds playing")
	body.teleport(BOSS_MARK_3D,0.)
	walker.enabled=true;await frames(15);body.model.hide();await frames(3)
	check(not step_voice.playing,"hiding the streamed machine clears its movement sounds")
	body.model.show();await frames(10);body.disable();walker.enabled=false;await frames(2)
	check(not step_voice.playing,"defeat/disable stops the walking voice")
	var old_audio: WeakRef=weakref(audio)
	display.queue_free();await frames(8)
	check(old_audio.get_ref()==null,"unloading the real arena frees the emitter with its model")
	stop_global_voices()
	if probe_bus>=0:AudioServer.remove_bus(probe_bus)
	check(AudioServer.is_bus_mute(0),"private Master mute remains in effect")
	var failures := checks.filter(func(row):return not row.pass)
	var result := {"pid":OS.get_process_id(),"checks":checks,"mix":captured,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"scope":"Actual arena cargo fall, imported six-leg gait, shared explosion/death events, voice-pool reuse and native mix before private muted Master; no performance claim."}
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("COMBAT_MACHINERY_AUDIO checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
