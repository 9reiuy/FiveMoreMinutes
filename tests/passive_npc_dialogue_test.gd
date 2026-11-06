extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func press(action: String) -> void:
	var event:=InputEventAction.new(); event.action=action; event.pressed=true
	Input.parse_input_event(event)
	await process_frame; await process_frame
	event=InputEventAction.new(); event.action=action; event.pressed=false
	Input.parse_input_event(event)
func run() -> void:
	print("PASSIVE_DIALOGUE_TEST PID=",OS.get_process_id()," audio=",AudioServer.get_driver_name())
	if AudioServer.get_driver_name()!="Dummy" or not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")):
		AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"),true)
		push_error("Private muted settings were not active before scene entry")
		quit(2); return
	root.size=Vector2i(640,360)
	var room=load("res://scenes/dream/Dream3D_ReceptionRoom.tscn").instantiate()
	root.add_child(room); await process_frame; await process_frame
	if room.dialogue_bubble==null: quit(2); return
	room.player.global_position=room.RECEPTION_DESK_POS_2D+Vector2(0,45)
	for i in 6: await process_frame
	check(room.interaction_resolver.current_target==room.waitress_npc,"Existing proximity resolver reaches NPC")
	check(not room.dialogue_controller.is_active(),"Passive NPC never automatically starts dialogue on proximity")
	check(room.npc_hint_bubble.visible and room.interaction_prompt.visible and room.interaction_prompt.text=="交流","Proximity displays emotion and talk prompt")
	check(room.npc_hint_bubble.emotion==&"nervous" and room.npc_hint_bubble.get_node_or_null("ProgressBarContainer")==null,"Independent emotion hint has no dialogue countdown")
	await press("pickup_weapon"); await create_timer(.2).timeout
	var controller=room.dialogue_controller
	var bubble=room.dialogue_bubble
	check(controller.is_active() and controller._sequence_index==0,"E starts first stage without skipping it")
	check(not bubble.options_container.visible,"No dialogue choice or interrupt buttons")
	check(bubble.gradient_panel.visible and not bubble.background.visible and not bubble.speaker_arrow.visible,"Dialogue uses the gradient panel without the old solid frame")
	check(bubble.dialogue_label.get_theme_font(&"font").resource_path.ends_with("BoutiqueBitmap9x9_Bold_1.9.ttf"),"Character dialogue uses the bold pixel font")
	check(bubble.size.x<220,"Early characters do not preallocate full sentence width")
	await create_timer(1.4).timeout
	check(bubble.size.x<=220.1 and bubble.size.y<100,"Longer prefix remains compact with bounded wrap width")
	check(bubble.progress_bar_container.visible,"Progress strip remains present")
	await press("pickup_weapon"); await create_timer(.16).timeout
	check(controller._sequence_index==1,"E directly advances even without completing old text")
	controller._process(controller.line_total_duration+.01)
	await create_timer(.16).timeout
	check(controller._sequence_index==2,"Countdown automatically advances next stage")
	await press("ui_cancel"); await create_timer(.25).timeout
	check(not controller.is_active() and not bubble.visible,"Esc finishes with fade-out")
	check(not room.tarot_overlay.visible and not room.tarot_visit_state.selected,"Dialogue does not draw tarot or mark a selection")
	await press("pickup_weapon"); await create_timer(.2).timeout
	for i in 5:
		await press("pickup_weapon"); await create_timer(.22).timeout
	check(not controller.is_active(),"E on final stage closes rather than reopening the same dialogue")
	room.player.global_position=room.PLAYER_SPAWN
	for i in 3: await process_frame
	check(room.interaction_resolver.current_target!=room.waitress_npc,"Leaving range removes NPC target")
	room.waitress_npc.conversation_mode=0
	room.player.global_position=room.RECEPTION_DESK_POS_2D+Vector2(0,45)
	for i in 4: await process_frame
	check(controller.is_active(),"Configured active NPC automatically speaks on approach")
	controller.dismiss_if_active(); room.waitress_npc.conversation_mode=1
	room.set_process(false)
	bubble.show_dialogue("短句",Vector2(320,180),[])
	bubble.set_typing_progress(.2,2); await create_timer(.2).timeout
	for speaker in [Vector2(10,15),Vector2(630,15),Vector2(10,340),Vector2(630,340)]:
		bubble.set_speaker_hud_position(speaker)
		check((bubble.arrow_tip+bubble.position).distance_to(speaker)<=4.1,"Speaker anchor remains aligned after edge clamping")
		check(bubble.position.x>=10 and bubble.position.x+bubble.size.x<=630.1,"Bubble stays within horizontal screen bounds")
	var long_text: String="只要撑到发奖金就好了……他们都这么说。可上去的人……怎么越来越少了……"
	bubble.show_dialogue(long_text,Vector2(320,180),[])
	for count in range(1,long_text.length()+1):
		bubble.set_typing_progress(.3,count)
		await process_frame
		check(Rect2(Vector2.ZERO,bubble.size).encloses(Rect2(bubble.text_clip.position,bubble.text_clip.size)),"Animated text viewport remains inside bubble")
		check(bubble.text_clip.position.y+bubble.text_clip.size.y<=bubble.progress_bar_container.position.y,"Text cannot overlap countdown during expansion")
	await create_timer(.2).timeout
	check(bubble.dialogue_label.get_line_count()>1,"Long complete sentence wraps into multiple lines")
	check(bubble.dialogue_label.get_minimum_size().y<=bubble.text_clip.size.y+.1,"Complete wrapped sentence fits without hidden lines")
	check(bubble.dialogue_label.text==long_text,"Containment preserves the complete sentence")
	var styled=load("res://scenes/ui/dialogue/growing_dialogue_bubble.tscn").instantiate()
	root.add_child(styled)
	styled.show_dialogue("普通对话",Vector2(320,180),[{"text":"继续","action_id":"continue"}],"打断")
	check(styled.options_container.visible and is_instance_valid(styled._interrupt_button),"Non-compact dialogue keeps interrupt and choice controls")
	styled.set_typing_progress(.3,2)
	await create_timer(.3).timeout
	check(styled.normal_options_container.visible,"Non-compact dialogue still transitions to its choices")
	var fall=preload("res://scripts/ui/dialogue/dream_dialogue_glyph_fall_fx.gd").spawn_from_label(root,styled.dialogue_label,2)
	check(is_instance_valid(fall) and fall.get_child_count()>0,"Interrupted text still creates falling glyphs")
	if is_instance_valid(fall) and fall.get_child_count()>0:
		var glyph: Label=fall.get_child(0)
		check(glyph.get_theme_font(&"font")==styled.dialogue_label.get_theme_font(&"font") and glyph.get_theme_font_size(&"font_size")==14,"Falling glyphs inherit the dialogue's bold face and size")
		fall.queue_free()
	styled.queue_free()
	room.queue_free(); await process_frame
	var tutorial=load("res://scenes/dream/Dream3D_TutorialRoom.tscn").instantiate()
	tutorial.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(tutorial); await process_frame; await process_frame
	var tutorial_bubble: Node=tutorial.dialogue_bubble
	check(tutorial_bubble.get_script().resource_path.ends_with("growing_dialogue_bubble.gd"),"Tutorial uses the same growing character dialogue")
	tutorial.dialogue_controller.start_dialogue(tutorial_bubble,"欢迎来到办公室。请跟我来。",[],Vector2(320,180),{"compact_dialogue":true,"interrupt_text":""})
	tutorial.dialogue_controller._process(.20)
	var tutorial_early: float=tutorial_bubble.size.x
	tutorial.dialogue_controller._process(.65)
	check(tutorial_bubble.size.x>tutorial_early,"Tutorial text and gradient panel grow with typing")
	check(tutorial_bubble.gradient_panel.visible and not tutorial_bubble.background.visible,"Tutorial uses the gradient and halftone panel")
	check(tutorial_bubble.dialogue_label.get_theme_font(&"font").resource_path.ends_with("BoutiqueBitmap9x9_Bold_1.9.ttf"),"Tutorial dialogue uses the bold pixel font")
	tutorial.dialogue_controller.dismiss_if_active()
	tutorial.queue_free(); await process_frame
	print("PASSIVE_NPC_DIALOGUE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
