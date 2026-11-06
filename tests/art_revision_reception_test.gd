extends SceneTree
const OUT:="res://.runtime/layout_redraw_20261103/reception_route"
const WALK=preload("res://tests/support/world_walk_input.gd")
var main: Node
var room: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func frames(n:=4) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func key_e() -> void:
	Input.action_press("pickup_weapon")
	var e:=InputEventKey.new(); e.keycode=KEY_E; e.physical_keycode=KEY_E; e.pressed=true
	root.push_input(e,true); await frames(2); e=e.duplicate(); e.pressed=false; root.push_input(e,true)
	Input.action_release("pickup_weapon"); await frames(4)
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
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps=60; root.size=Vector2i(1280,720); AudioServer.set_bus_mute(0,true)
	create_timer(160.,true,false,true).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(80)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new()
	main.chapter_one.state.stage="RECEPTION"; main.chapter_one.resume()
	while main.transition_running: await process_frame
	await frames(35); room=main._supported_dream_world
	check(room.floor_cells.size()<=128,"lobby is less than one third of the former footprint")
	check(room.player.global_position.x>room.RECEPTION_DESK_POS_2D.x and room.RECEPTION_DESK_POS_2D.x>room.ELEVATOR_POS_2D.x,"right entrance, middle counter, left elevator")
	check(room.props_root.find_children("*ReceptionDesk*","Node3D",false,false).size()==1,"only one service counter remains")
	var plants:=0
	for item in room.props_root.get_children():
		if item.get_meta(&"lobby_kind","")=="plant": plants+=1
	check(plants==2,"two corner planters keep the compact aisle clear")
	check(room.door_root.get_child_count()==1,"one visible and functional elevator remains")
	for point in [Vector2(15.5,4.5),Vector2(13.,4.5),Vector2(10.,4.5),Vector2(8.,4.4)]:
		await walk(point); await snap("walk_%d"%checks)
	check(not room.dialogue_controller.is_active(),"NPC stays passive until E")
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
	for point in [Vector2(5.,4.5),Vector2(1.5,4.5),Vector2(1.5,1.3)]: await walk(point)
	check(room.elevator_approach_active,"elevator entry remains reachable after tarot")
	await snap("elevator_approach")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	main.queue_free(); await frames(10); quit(0 if failures.is_empty() else 1)
