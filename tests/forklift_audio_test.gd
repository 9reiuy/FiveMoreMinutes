extends "res://tests/forklift_revision_test.gd"
## Actual chapter controller/input path; native mode also captures the quiet 3D mix.
var mix: Array[Dictionary] = []
var tap: AudioEffectCapture
var probe_bus := -1


func silent() -> bool:
	return not lift.drive_audio.motor.playing and not lift.drive_audio.boost.playing and not lift.drive_audio.skid.playing


func capture_mix(label: String) -> void:
	if tap == null: return
	# Let the actual audio output/mix buffers drain before reading a new state.
	await create_timer(.08,true,false,true).timeout
	tap.clear_buffer()
	await create_timer(.12,true,false,true).timeout
	var data := tap.get_buffer(tap.get_frames_available())
	var peak := 0.0
	var power := 0.0
	for sample in data:
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		power+=sample.length_squared()
	var level := {"label":label,"frames":data.size(),"peak_dbfs":linear_to_db(maxf(peak,1e-8)),
		"rms_dbfs":linear_to_db(maxf(sqrt(power/maxf(1.0,data.size()*2.0)),1e-8))}
	mix.append(level)
	if label in ["parked","stopped","paused"]:
		# Godot may put a bus with no playing voices to sleep (zero captured frames).
		check(peak<.00003,label+" is silent in the real mixer")
	else:
		check(data.size()>1000 and float(level.peak_dbfs)>-80.0 and float(level.peak_dbfs)<-25.0,
			label+" emits quiet nonzero audio before muted Master")


func run() -> void:
	create_timer(75,true,false,true).timeout.connect(func():quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	print("FORKLIFT_AUDIO_PID=",OS.get_process_id())
	verify_audio()
	native=DisplayServer.get_name()!="headless"
	if native:
		preload("res://tests/support/background_gpu.gd").start(self)
		check(RenderingServer.get_current_rendering_method()=="forward_plus","native scene inherits Forward+ from project.godot")
	root.get_node("DreamTimeController").slow_time_enabled=false
	Engine.time_scale=1.0;Engine.max_fps=60
	await enter_chapter(CHAPTER.Save.CALIBRATED)
	for enemy in world.enemy_root.get_children():enemy.set_physics_process(false)
	var audio: Node3D=lift.drive_audio
	check(audio.get_parent()==lift.visual and audio.get_child_count()==3,"one vehicle-owned 3D emitter has exactly three voices")
	check(audio.motor.bus==&"Environment" and audio.boost.bus==&"Environment" and audio.skid.bus==&"Environment","all three use the existing Environment / WorldSFX / SFX volume path")
	check(audio.MOTOR_DB==-28.0 and audio.BOOST_DB==-24.0 and audio.SKID_DB==-26.0,"authored trims keep every vehicle layer quiet")
	check(audio.motor.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED and audio.motor.max_distance>0,"positional audio falls off with distance without amplifying the nearby driver")
	check(audio.motor.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and audio.motor.stream.loop_begin>0 and audio.skid.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and audio.boost.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"motor preserves its startup then loops; skid loops; boost plays once")
	if native:
		AudioServer.add_bus();probe_bus=AudioServer.bus_count-1
		AudioServer.set_bus_name(probe_bus,&"ForkliftAudioProbe");AudioServer.set_bus_send(probe_bus,&"Environment")
		tap=AudioEffectCapture.new();tap.buffer_length=.5;AudioServer.add_bus_effect(probe_bus,tap)
		for voice in [audio.motor,audio.boost,audio.skid]:voice.bus=&"ForkliftAudioProbe"
	park(PLAN.FORKLIFT_START)
	place_feet(PLAN.FORKLIFT_START+Vector2(-.13,1.2));await frames(3)
	check(lift.board(world.player),"actual chapter forklift boards")
	await frames(5)
	check(silent(),"boarding a parked forklift stays silent")
	await capture_mix("parked")
	Input.action_press("move_up");await frames(9)
	check(absf(lift.speed)>.4 and audio.motor.playing and not audio.boost.playing and not audio.skid.playing,"moving with W starts only the chosen electric motor")
	await capture_mix("motor")
	await key(KEY_SHIFT);await key(KEY_SHIFT,false)
	check(lift.boost_left>0 and audio.boost.playing,"physical Shift starts the selected acceleration recording")
	var position_before: float=audio.boost.get_playback_position()
	await key(KEY_SHIFT,true,true);await key(KEY_SHIFT,false)
	check(not lift.start_boost() and audio.boost.get_playback_position()>=position_before,"echo and a rejected cooldown do not restart acceleration audio")
	await capture_mix("boost")
	# Restore an open-road pose for the separate handbrake case, retaining the real controller.
	park(PLAN.FORKLIFT_START)
	lift.speed=7.0
	Input.action_press("move_up");Input.action_press("move_right")
	await key(KEY_SPACE);await frames(8)
	check(lift.handbraking and audio.skid.playing and not audio.boost.playing,"moving handbrake starts the tyre recording and cancels boost audio")
	await capture_mix("skid")
	await key(KEY_SPACE,false);Input.action_release("move_right");await frames(8)
	check(not audio.skid.playing,"releasing the handbrake stops its loop")
	var holder := Node2D.new();world.collision_root.add_child(holder)
	var art_holder := Node3D.new();world.add_child(art_holder)
	lift.transfer_to(holder,art_holder);await frames(3)
	check(lift.drive_audio==audio and audio.get_child_count()==3 and lift.driver==world.player,"a mounted region transfer preserves one emitter and its driver")
	lift.transfer_to(world.collision_root,world);holder.queue_free();art_holder.queue_free()
	paused=true;await process_frame;await process_frame
	check(audio.motor.stream_paused,"pausing the game pauses vehicle playback")
	await capture_mix("paused")
	paused=false;await frames(2)
	check(not audio.motor.stream_paused,"resuming the game resumes the driving sound")
	park(PLAN.FORKLIFT_START);Input.action_press("roll");Input.action_press("move_up");await frames(12)
	check(silent() and lift.speed==0.0,"holding throttle and handbrake while stationary emits no movement or skid")
	Input.action_release("roll");await frames(12)
	check(audio.motor.playing,"releasing the stationary handbrake lets movement audio restart")
	check(lift.try_exit() and silent(),"dismount immediately stops all vehicle layers")
	await capture_mix("stopped")
	place_feet(lift.global_position/32.0+Vector2(-.13,1.2));await frames(3)
	check(lift.board(world.player),"the same forklift can be boarded again")
	Input.action_press("move_up");await frames(10)
	lift.set_active(false)
	check(silent(),"deactivating a moving forklift stops every sound")
	lift.set_active(true);park(PLAN.FORKLIFT_START)
	place_feet(PLAN.FORKLIFT_START+Vector2(-.13,1.2));await frames(3)
	check(lift.board(world.player),"reactivated forklift boards")
	Input.action_press("move_up");await frames(10)
	lift.take_damage(lift.hp);await frames(3)
	check(lift.destroyed and silent(),"destroying a moving forklift stops its driving voices")
	for action in ["move_up","move_down","move_left","move_right","roll"]:Input.action_release(action)
	var audio_ref: WeakRef = weakref(audio)
	current_scene.queue_free();await frames(6)
	check(audio_ref.get_ref()==null,"unloading the chapter frees its emitter and streams")
	if probe_bus>=0:AudioServer.remove_bus(probe_bus)
	check(AudioServer.is_bus_mute(0),"private Master remains muted throughout")
	var report := {"checks":checks,"failures":failures,"mix":mix,"pid":OS.get_process_id(),
		"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"audio":AudioServer.get_driver_name(),"scope":"Actual chapter vehicle, input, mounted reparenting, lifecycle and optional muted native 3D audio capture. No performance claim."}
	var file := FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FORKLIFT_AUDIO checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
