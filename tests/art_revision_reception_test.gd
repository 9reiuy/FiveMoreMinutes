extends SceneTree
var OUT:="res://.runtime/layout_redraw_20261103/reception_route"
const WALK=preload("res://tests/support/world_walk_input.gd")
var main: Node
var room: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):OUT=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(n:=4) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func key_e() -> void:
	var e:=InputEventKey.new(); e.keycode=KEY_E; e.physical_keycode=KEY_E; e.pressed=true
	# Feed one physical key edge through Input. Combining action_press with
	# Viewport.push_input bypasses the ordinary singleton/event ordering.
	Input.parse_input_event(e); await frames(3)
	e=e.duplicate(); e.pressed=false; Input.parse_input_event(e); await frames(4)
func walk(point: Vector2) -> void:
	var deadline:=Time.get_ticks_msec()+12000
	while room.player.global_position.distance_to(point*32.)>9. and Time.get_ticks_msec()<deadline:
		var desired: Vector2=(point*32.-room.player.global_position).normalized()
		var best:=Vector2.ZERO; var score:=-INF
		for candidate in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var mapped: Vector2=room.player._camera_relative_movement_input(candidate.normalized())
			var value: float=mapped.normalized().dot(desired)
			if value>score: score=value; best=candidate
		WALK.release()
		if best.x!=0: Input.action_press("move_right" if best.x>0 else "move_left")
		if best.y!=0: Input.action_press("move_down" if best.y>0 else "move_up")
		await physics_frame; await process_frame
	WALK.release(); await frames(3)
	check(room.player.global_position.distance_to(point*32.)<20.,"ordinary walking reaches "+str(point))
func run() -> void:
	if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps=60; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	create_timer(160.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(80)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new()
	main.chapter_one.state.stage="RECEPTION"; main.chapter_one.resume()
	while main.transition_running: await process_frame
	await frames(35); room=main._supported_dream_world
	check(room.floor_cells.size()==383,"Reference atrium has the contracted T-shaped lift hall")
	check(room.player.global_position.x>room.RECEPTION_DESK_POS_2D.x and room.RECEPTION_DESK_POS_2D.x>room.ELEVATOR_POS_2D.x,"foreground arrival, left service counter and rear-left elevator")
	check(room.props_root.find_children("*ReceptionDesk*","Node3D",false,false).size()==1,"only one service counter remains")
	var plants:=0
	for item in room.props_root.get_children():
		if item.get_meta(&"lobby_kind","")=="plant": plants+=1
	check(plants==2,"two planters frame the raised side waiting bays")
	check(room.door_root.get_child_count()==6,"Two inner banks contain six functional lifts")
	for point in [Vector2(17.5,19.1),Vector2(17.5,20.2),Vector2(17.5,19.1),Vector2(13.,19.1),Vector2(10.,19.1),Vector2(7.2,19.1)]:
		await walk(point); await snap("walk_%d"%checks)
	check(not room.dialogue_controller.is_active(),"NPC stays passive until E")
	check(room.interaction_resolver.current_target==room.waitress_npc,"Ordinary walking selects the receptionist before E")
	print("INTERACTION before E: target=",room.interaction_resolver.current_target," blocking=",room.dialogue_bubble.visible," consumed=",room.interaction_consumed_until_release," elevator=",room.elevator_approach_active)
	await key_e(); await frames(5)
	check(room.dialogue_controller.is_active(),"real E starts reception dialogue")
	await snap("dialogue")
	for i in 90:
		if not room.dialogue_controller.is_active(): break
		await key_e(); await create_timer(.12,true,false,true).timeout
	check(bool(room.get_meta(&"chapter_dialogue_heard",false)),"actual conversation records completion")
	# The completed line still fades out before the next interaction is legal.
	await frames(45)
	await key_e()
	var deadline:=Time.get_ticks_msec()+16000
	while room.tarot_overlay.current_state!=TarotOverlay.State.CHOOSING and Time.get_ticks_msec()<deadline: await frames(2)
	check(room.tarot_overlay.visible and room.tarot_overlay.cards.size()==3,"second E deals the existing three-card tarot flow")
	await snap("tarot_choice")
	if room.tarot_overlay.current_state==TarotOverlay.State.CHOOSING:
		var card: Control=room.tarot_overlay.cards[0]
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=card.get_global_rect().get_center(); event.pressed=true
		card.get_viewport().push_input(event,true); await frames(2)
		event=event.duplicate(); event.pressed=false; card.get_viewport().push_input(event,true)
		var until:=Time.get_ticks_msec()+8000
		while room.tarot_overlay.visible and Time.get_ticks_msec()<until: await frames(2)
	check(not str(main.chapter_one.state.tarot_id).is_empty(),"actual card click saves the chapter tarot choice")
	check(room.player.movement_enabled,"tarot completion restores movement")
	for point in [Vector2(13.2,19.1),Vector2(13.2,16),Vector2(12,14),Vector2(12,12),Vector2(12,8.4),Vector2(7,8.4)]:
		await walk(point);await snap("reference_route_%d"%checks)
		if point==Vector2(12,8.4):check(absf(room.player_depth_bridge._character_ground().y-.634)<.01,"Actor passes the relocated gates onto the raised carpet surface")
	check(room.elevator_approach_active,"elevator entry remains reachable after tarot")
	await snap("elevator_approach")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"checks":checks,"failures":failures},"\t"))
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW);Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	main.queue_free(); await frames(10); preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0); await frames(3); quit(0 if failures.is_empty() else 1)
