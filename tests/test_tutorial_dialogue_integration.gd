extends SceneTree
const TUTORIAL=preload("res://scenes/dream/Dream3D_TutorialRoom.tscn")
var failures: Array[String]=[]
var checks:=0
var played_events: Array[StringName]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count: int) -> void:
	for frame in count:await process_frame
func run() -> void:
	await process_frame
	var master:=AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		quit(1);return
	root.get_node("SFXManager").sfx_played.connect(func(event_id: StringName):played_events.append(event_id))
	var room: Node3D=TUTORIAL.instantiate();root.add_child(room)
	await frames(8)
	var training: Node=room.get_node("ChapterTraining")
	room.player.set_physics_process(false)
	check(room.dialogue_bubble is DreamDialogueBubble and room.dialogue_controller is DreamDialogueController,"Shared dialogue components exist")
	check(not room.has_node("GameplayCanvas/GameplayWorld/TutorialGuide"),"No tutorial person is instantiated")
	check(not room.dialogue_bubble.visible,"Dialogue starts hidden")
	var speech: AudioStreamPlayer=room.tv_speech_audio
	check(speech != null and not speech.playing and speech.stream.resource_path=="res://sfx/preview/screen_wall_static.res" and speech.bus==&"UI","Tutorial owns one quiet player using the selected television-static resource")
	room.terminal.request_interaction(room.player)
	check(not room.dialogue_controller.is_active() and not training.talked,"Remote interaction cannot answer the television")
	room.player.global_position=room.terminal.global_position+Vector2(36,0)
	room.interaction_resolver.update_target();room._update_interaction_prompt()
	check(room.interaction_resolver.current_target==room.terminal,"Nearby television is selected")
	check(room.interaction_prompt.dialogue_label.text=="交谈","Reception-style interaction bubble only says 交谈")
	check(not speech.playing,"The interaction hint does not make the television speak")
	room.terminal.request_interaction(room.player)
	await frames(3)
	check(room.dialogue_controller.is_active() and room.dialogue_bubble.visible,"Actual television request starts its dialogue")
	var intro:=TextContent.get_dialogue(&"tutorial_tv_intro")
	check(intro.lines.size()==2 and intro.lines.map(func(row):return row.text)==["这里简单做个入职测试","到隔壁房间去"] and room.dialogue_bubble._current_text==intro.lines[0].text,"Television begins the requested two-line introduction")
	check(room.dialogue_controller.blip_sound==&"" and speech.playing and speech.volume_db<=-26.0,"Television typing replaces the old blips with low-volume static")
	check(room.monitor_feed.stations[0].speaking and bool(room.monitor_feed.stations[0].screen_material.get_shader_parameter("speech_static")),"The speaking television switches its actual screen material to snow")
	check(not room.monitor_feed.stations[1].speaking and not room.monitor_feed.stations[2].speaking,"Only the speaking television switches to snow")
	room.dialogue_controller._process(maxf(0.0,room.dialogue_controller.typewriter_duration-room.dialogue_controller.elapsed)+.01)
	await frames(3)
	check(room.dialogue_controller.is_active() and room.dialogue_bubble.visible and not speech.playing,"Finished text stays readable while its speech noise stops")
	check(not room.monitor_feed.stations[0].speaking and not bool(room.monitor_feed.stations[0].screen_material.get_shader_parameter("speech_static")),"Text completion restores live-camera mode before the reading hold ends")
	await create_timer(.2,true,false,true).timeout
	check(not room.interaction_prompt.visible,"Interaction hint disappears during the broadcast")
	room._process(.016)
	check(room.dialogue_bubble._speaker_hud_pos!=Vector2.ZERO,"Dialogue remains anchored to the television")
	room.player.global_position=room.terminal.global_position+Vector2(200,0)
	room._process(.016);await frames(3)
	check(not room.dialogue_controller.is_active(),"Leaving the television closes the local dialogue")
	check(not speech.playing,"Cancelled television dialogue leaves no static audio")
	check(room.monitor_feed.stations.all(func(tv):return not tv.speaking),"Cancelling dialogue clears snow on every television")
	check(training.stage==training.Stage.INTRO and room.terminal.interaction_enabled,"Interrupted introduction remains available without unlocking the next lesson")
	room.player.global_position=room.terminal.global_position+Vector2(36,0)
	room.terminal.request_interaction(room.player);await frames(3)
	check(speech.playing,"Restarting an interrupted introduction resumes static speech")
	var station: Node3D=room.monitor_feed.stations[0]
	station.set_power_available(false);room._update_tv_speech_audio();await frames(3)
	check(not speech.playing,"An unpowered television stops speaking")
	check(not station.speaking and not bool(station.screen_material.get_shader_parameter("screen_power")),"Power loss clears speech snow and keeps the glass black")
	station.set_power_available(true);room.monitor_feed.update_frame();room._update_tv_speech_audio();await frames(3)
	check(speech.playing,"Restoring power resumes the current typing line")
	check(station.speaking,"Restoring power during speech resumes the matching snow screen")
	for attempt in 30:
		if not room.dialogue_controller.is_active():break
		room.dialogue_controller._process(.8);room.dialogue_controller.advance_sequence()
		await create_timer(.12,true,false,true).timeout
	await frames(3)
	check(training.stage==training.Stage.JUMP_CALL and not room.terminal.interaction_enabled,"Completing both introduction lines unlocks the next lesson once")
	check(room.training_zone_states.get(1,false) and not room.training_zone_states.get(2,true),"Only the second room lights after first-room completion")
	check(not speech.playing,"A call from a room whose television is still off does not leak static")
	room.player.global_position=Vector2(4,13)*32.0
	room.monitor_feed.update_frame();training.call_elapsed=.3
	room._update_interaction_prompt();room._update_tv_speech_audio();await frames(3)
	check(room.interaction_prompt.dialogue_label.text=="请到这边来" and speech.playing,"The powered jump-room television uses static for its repeated call")
	check(room.monitor_feed.stations[1].speaking and not room.monitor_feed.stations[0].speaking,"A repeated call switches only its own room's television to snow")
	training.call_elapsed=1.7
	room._update_interaction_prompt();room._update_tv_speech_audio();await frames(3)
	check(not speech.playing,"Repeated calls stop the static in their silent interval")
	check(not room.monitor_feed.stations[1].speaking,"Call intervals restore the live game image")
	training.call_elapsed=.3;room._update_tv_speech_audio();await frames(3)
	paused=true;await frames(3)
	check(speech.stream_paused,"Pausing the lesson pauses the speech audio with its dialogue clock")
	paused=false;training.call_elapsed=1.7;room._update_tv_speech_audio();await frames(3)
	check(not speech.playing,"Returning to a silent call interval stays quiet")
	check(not played_events.has(&"text_blip"),"Tutorial television dialogue never triggers the removed text-blip sound")
	var other_controller:=DreamDialogueController.new();root.add_child(other_controller)
	other_controller.start_dialogue(room.dialogue_bubble,"测试",[],Vector2(200,100),{"compact_dialogue":true,"typewriter_speed":.01,"countdown_extra":.2})
	other_controller._process(.025)
	check(other_controller.blip_sound==&"text_blip" and played_events.has(&"text_blip"),"Other shared dialogue retains its original voice behaviour")
	other_controller.dismiss_if_active();other_controller.queue_free()
	var speech_ref: WeakRef=weakref(speech)
	room.queue_free();await frames(8)
	check(speech_ref.get_ref()==null,"Unloading the tutorial frees its speech player")
	print("TUTORIAL_DIALOGUE checks=",checks," failures=",failures.size()," pid=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	quit(1 if not failures.is_empty() else 0)
