extends "res://tests/tarot_reception_delivery.gd"
func tap(action: String) -> void:
	var event:=InputEventAction.new(); event.action=action; event.pressed=true
	Input.parse_input_event(event); await frames(2)
	event=InputEventAction.new(); event.action=action; event.pressed=false
	Input.parse_input_event(event); await frames(2)
func run() -> void:
	output="res://.runtime/npc_bubble_join_20261015/camera"
	if DisplayServer.get_name()=="headless": quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps=60; AudioServer.set_bus_mute(0,true); root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(3)
	main.persistent_day_state=main._create_initial_state(); main._show_reception("basic")
	for i in 600:
		await frames(1)
		if main._supported_dream_world is Dream3DReceptionRoom and not main.transition_running:
			room=main._supported_dream_world; break
	check(room!=null,"Actual Main reception entry")
	if room==null: quit(1); return
	check(await move_to(Vector2(12.5,7.2)),"Ordinary input crosses entrance gates")
	check(await move_to(Vector2(16,5)),"Ordinary input approaches passive NPC")
	await frames(20); capture("ellipsis")
	check(not room.dialogue_controller.is_active(),"Proximity displays hint without automatically opening dialogue")
	check(room.npc_hint_bubble.visible and room.interaction_prompt.text=="交流","Actual Camera shows emotion and short talk action")
	check(room.npc_hint_bubble.get_node_or_null("ProgressBarContainer")==null,"Emotion has no dialogue countdown")
	recording=true
	await frames(20)
	await tap("pickup_weapon"); await frames(5); capture("first_letters")
	check(room.dialogue_controller.is_active() and room.dialogue_controller._sequence_index==0,"E starts first dialogue stage")
	check(not room.dialogue_bubble.options_container.visible,"No choice or interrupt buttons")
	await frames(20); capture("growing")
	await frames(65); capture("wrapped")
	await tap("pickup_weapon"); await frames(40); capture("second_stage")
	check(room.dialogue_controller._sequence_index==1,"E skips directly to second stage")
	var mouse:=InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=true
	Input.parse_input_event(mouse); await frames(2); mouse=InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=false; Input.parse_input_event(mouse)
	await frames(40); capture("third_stage")
	check(room.dialogue_controller._sequence_index==2,"Left click advances third stage")
	check((room.dialogue_bubble.arrow_tip+room.dialogue_bubble.position).distance_to(room._get_waitress_hud_pos())<4.1,"Tail follows actual projected NPC head after camera movement")
	await tap("pickup_weapon"); await frames(50); capture("fourth_stage")
	check(room.dialogue_controller._sequence_index==3,"Fourth approved stage displayed")
	await tap("pickup_weapon"); await frames(75); capture("fifth_stage")
	check(room.dialogue_controller._sequence_index==4,"Fifth approved stage displayed")
	await tap("ui_cancel"); await frames(20); capture("dismissed")
	check(not room.dialogue_controller.is_active() and not room.dialogue_bubble.visible,"Esc closes with fade-out")
	check(not room.tarot_overlay.visible and not room.tarot_visit_state.selected,"No tarot entry or accidental selection")
	recording=false
	for point in [Vector2(12.5,5.5),Vector2(3.5,5.5),Vector2(3.5,1.3)]:
		check(await move_to(point),"Ordinary movement reaches elevator after dialogue")
	await tap("pickup_weapon")
	for i in 1200:
		await frames(1)
		if is_instance_valid(main._supported_dream_world) and not main._supported_dream_world is Dream3DReceptionRoom and not main.transition_running: break
	check(not main._supported_dream_world is Dream3DReceptionRoom,"Actual elevator enters formal floor without tarot")
	var file=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"gpu":RenderingServer.get_video_adapter_name(),"minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"scope":"Actual Main, ordinary movement and real input events; original game camera follows dialogue."},"\t")); file.close()
	print("PASSIVE_DIALOGUE_DELIVERY checks=",checks," failures=",failures)
	main.queue_free(); await process_frame; quit(1 if failures else 0)
