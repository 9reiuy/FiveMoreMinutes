extends SceneTree
## Automated real-projectile route. Teleports are explicit navigation setup,
## not claimed as manual play; objectives/card/build/exit still use live systems.
const WALK=preload("res://tests/support/world_walk_input.gd")
const OUT="res://.runtime/visual_overhaul_20261029/route"
var main: Node
var checks:=0
var failures:=0
var shots:=0
var tutorial: Node
var recordings: Dictionary={}
var recording_times: Dictionary={}
func _initialize() -> void: call_deferred("run")
func frames(n: int=3) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(8)
func key(code: int) -> void:
	var actions: Dictionary={KEY_E:"pickup_weapon",KEY_R:"reload_weapon",KEY_SPACE:"dash",KEY_ENTER:"confirm"}
	if actions.has(code): Input.action_press(actions[code])
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=true; root.push_input(event,true)
	await frames(2)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	if actions.has(code): Input.action_release(actions[code])
	await frames(2)
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(OUT+"/route_"+label+".png")
func record_seconds(seconds: float,label: String) -> void:
	var start_ms:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start_ms<seconds*1000.:
		await RenderingServer.frame_post_draw
		var serial: int=recordings.get(label,0); recordings[label]=serial+1
		var file: String="movie_"+label+"_%04d.png"%serial
		root.get_texture().get_image().save_png(OUT+"/"+file)
		if not recording_times.has(label): recording_times[label]=[]
		recording_times[label].append({"file":file,"time_ms":Time.get_ticks_msec()})
		await create_timer(.1,true,false,true).timeout
	FileAccess.open(OUT+"/timing_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(recording_times[label]))
func shoot(world: Node,target: Node2D,limit: float=35.) -> void:
	var player: Node2D=world.player
	var target_ref: WeakRef=weakref(target)
	var outcome: Dictionary={"killed":target.dead}
	if target.has_signal("defeated"): target.defeated.connect(func(_point,_count): outcome.killed=true,CONNECT_ONE_SHOT)
	player.set_meta("presentation_pointer_gate",func(): return true)
	player.set_meta("presentation_pointer_position",func():
		var live: Node2D=target_ref.get_ref()
		if not is_instance_valid(live): return Vector2(320,180)
		return world.camera_3d.unproject_position(world.to_global(Vector3(live.global_position.x/32.,.65,live.global_position.y/32.))))
	var started:=Time.get_ticks_msec()
	var attempts:=0
	while is_instance_valid(target) and not target.dead and (Time.get_ticks_msec()-started)<limit*1000:
		player.invulnerability_left=1000.
		if attempts%5==0 and not world.has_node("ChapterTraining"):
			# Navigation setup chooses a free firing lane; bullets, cover, enemy
			# movement and damage still run normally. No injected enemy damage.
			for i in 16:
				var candidate: Vector2=target.global_position+Vector2.RIGHT.rotated((i+attempts)*TAU/16.)*90.
				if not world.floor_cells.has(Vector2i((candidate/32.).round())): continue
				var ray:=PhysicsRayQueryParameters2D.create(candidate,target.global_position,12)
				if player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					player.global_position=candidate; break
		attempts+=1
		Input.action_press("attack"); await create_timer(.12).timeout; Input.action_release("attack"); await create_timer(.18).timeout
	Input.action_release("attack")
	check(bool(outcome.killed) or (is_instance_valid(target) and target.dead),"real projectile defeated target")
	player.remove_meta("presentation_pointer_position")
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	# Virtual test driver for the same held-fire branch as LMB; no game binding changes.
	if not InputMap.has_action("attack"): InputMap.add_action("attack")
	create_timer(1200,true,false,true).timeout.connect(func(): push_error("route watchdog"); quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	if "--resume-bedroom" in OS.get_cmdline_user_args():
		main._continue_game(); await settle(); await finish_story(); return
	if "--resume-combat" in OS.get_cmdline_user_args():
		main._continue_game(); await settle()
	else:
		main._start_new_game(); await settle()
		for i in 70:
			if main.current_screen.scene_file_path!="res://scenes/ui/opening.tscn": break
			var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(320,180)
			main.current_screen._gui_input(click); await create_timer(.2).timeout
		await settle()
		check(main.chapter_one.state.stage=="TUTORIAL" and main._supported_dream_world.has_node("ChapterTraining"),"formal New Game enters tutorial before bedroom")
		tutorial=main._supported_dream_world
		tutorial.player.set_meta("presentation_pointer_gate",func(): return true)
		var training: Node=tutorial.get_node("ChapterTraining")
		await walk_to(tutorial,Vector2(128,21*32.))
		tutorial._spawn_guide_once(); await create_timer(.8).timeout
		await walk_to(tutorial,tutorial.guide.position+Vector2(-35,20)); await key(KEY_E)
		for i in 60:
			if training.stage>=2: break
			await key(KEY_E); await create_timer(.12).timeout
		check(training.stage==2,"real registration conversation opens first gate")
		await walk_to(tutorial,Vector2(224,21*32.))
		await walk_to(tutorial,Vector2(352,21*32.))
		await walk_to(tutorial,Vector2(352,15*32.))
		await walk_to(tutorial,Vector2(128,15*32.))
		await walk_to(tutorial,Vector2(128,14.4*32.))
		WALK.hold(tutorial.player,Vector2.UP); await key(KEY_SPACE); await create_timer(.6).timeout; WALK.release(); await frames(20)
		check(training.stage==3,"real doorway traversal and dash unlock range")
		if training.stage!=3: quit(1); return
		await walk_to(tutorial,Vector2(128,15*32.))
		await walk_to(tutorial,Vector2(352,15*32.))
		await walk_to(tutorial,Vector2(352,7*32.))
		await walk_to(tutorial,Vector2(224,7*32.))
		tutorial.player.global_position=training.pickup.global_position+Vector2(0,20); await key(KEY_E)
		check(training.picked,"E picks up a real world weapon")
		tutorial.player.global_position=Vector2(128,7.5*32.)
		tutorial.player.confirmed_projectile_fired.connect(func(): shots+=1)
		# First shot then reload teaches both real systems.
		var target: Node2D=training.training_target
		tutorial.player.set_meta("presentation_pointer_gate",func(): return true)
		tutorial.player.set_meta("presentation_pointer_position",func(): return tutorial.camera_3d.unproject_position(tutorial.to_global(Vector3(target.global_position.x/32.,.65,target.global_position.y/32.))))
		Input.action_press("attack"); await record_seconds(.2,"training"); Input.action_release("attack"); await key(KEY_R); await record_seconds(2.,"training")
		check(training.reload_done,"actual reload completion observed")
		await shoot(tutorial,target); await create_timer(2.).timeout; await frames(4); check(training.can_exit(),"all training objectives complete")
		await snap("tutorial_completed")
		if "--tutorial-only" in OS.get_cmdline_user_args():
			print("CHAPTER1_TUTORIAL_REVISION checks=",checks," failures=",failures," shots=",shots)
			main.queue_free(); await frames(); quit(failures); return
		tutorial.player.global_position=tutorial.EXIT_TRIGGER_POSITION; tutorial.call_deferred("_begin_exit_sequence")
		for i in 35:
			if main._supported_dream_world!=tutorial: break
			await key(KEY_E); await create_timer(.12).timeout
		await settle()
		check(main.chapter_one.state.stage=="EVENING" and main.current_screen.scene_file_path=="res://scenes/bedroom/bedroom.tscn","tutorial exit restores illustrated bedroom")
		if main.chapter_one.state.stage!="EVENING": quit(1); return
		await illustrated_evening()
		var lobby: Node=main._supported_dream_world
		check(main.chapter_one.state.stage=="RECEPTION","illustrated bedroom sleep enters reception")
		# Actual deck animation/card click; the conversation is independently smoke-tested.
		lobby._start_tarot_sequence(); await create_timer(3.5).timeout
		var cards: Array=lobby.tarot_overlay.cards
		print("TAROT_CARDS ",cards.size())
		if cards.size()>0: lobby.tarot_overlay._on_card_selected(cards[0])
		await create_timer(2.).timeout
		check(main.chapter_one.state.tarot_id!="","real tarot choice commits once")
		if main.chapter_one.state.tarot_id=="": quit(1); return
		# Use existing reception elevator handler after placing at its approach.
		await snap("reception")
		lobby.player.global_position=Vector2(lobby.ELEVATOR_POS_3D.x,lobby.ELEVATOR_POS_3D.z)*32.+Vector2(0,48)
		main.set_meta("test_fail_reception_generation",true)
		lobby.call_deferred("_start_elevator_entry")
		while main.get_meta("last_reception_journey",{}).is_empty() or main.transition_running: await process_frame
		check(not main.get_meta("last_reception_journey").success and lobby.player.movement_enabled and not lobby.elevator_transition_in_progress,"failed generation restores live lobby and control")
		main.set_meta("test_fail_reception_generation",false)
		print("ENTER_LOBBY_CAB paused=",paused," transitioning=",lobby.elevator_transition_in_progress)
		lobby.call_deferred("_start_elevator_entry")
		await record_seconds(4.,"enter_cab")
		while main._supported_dream_world==lobby: await process_frame
		await settle()
	var world: Node=main._supported_dream_world
	while world.floor_transition_in_progress: await process_frame
	await frames(90)
	check(world.rooms.size()>1 and world.last_validation_report.get("valid",false),"chapter reuses validated formal office skeleton")
	await snap("floor1")
	for floor in range(world.floor_index,2):
		for room in world.rooms.duplicate():
			if int(room.id)==world.spawn_room_id or not world._is_combat_room(room): continue
			world.player.global_position=Vector2(room.center_cell)*32.; world.activate_room(int(room.id)); await frames(12)
			for wave in 4:
				var enemies: Array=world.enemy_root.get_children().filter(func(enemy): return (enemy is EmployeeEnemy or enemy.get_meta("content_kind",&"")==&"hotel_robot") and enemy.get_meta("dream_room_id",-1)==int(room.id) and not enemy.dead)
				for enemy in enemies:
					if not is_instance_valid(enemy) or enemy.dead: continue
					world.player.global_position=enemy.global_position+Vector2(0,85)
					await frames(3); await shoot(world,enemy,25.)
				await frames(10)
				if world.get_node("ChapterOneRun").required_hostiles(int(room.id))==0: break
			await frames(8)
			# Re-entering uses the same live room-clear contract as a player
			# returning from a corridor after the last enemy was knocked out.
			world.activate_room(int(room.id)); await frames(8)
			if world.get_room_state(int(room.id))!=&"CLEARED":
				print("ROOM_DIAGNOSTIC ",room.id," state=",world.get_room_state(int(room.id))," alive=",world._get_alive_employee_count_in_room(int(room.id))," boss=",world.boss_room_id," player_dead=",world.player.dead," transition=",world.floor_transition_in_progress," token=",world.get_current_floor_token()," adapter_token=",world.get_node("ChapterOneRun").token)
				for e in world.enemy_root.get_children():
					if e is EmployeeEnemy and not e.dead: print("ALIVE ",e.name," home=",e.get_meta("dream_room_id",-1)," pos=",e.global_position)
			check(world.get_room_state(int(room.id))==&"CLEARED","room clear follows actual enemy deaths")
		await frames(12)
		# Cross-room shots can expose additional authored hostiles after a room
		# pass. Sweep live actors again instead of assuming that snapshot is final.
		for sweep in 6:
			if world.get_node("ChapterOneRun").can_advance(): break
			var remaining: Array=world.enemy_root.get_children().filter(func(enemy):
				var home: int=enemy.get_meta("dream_room_id",-1)
				return (enemy is EmployeeEnemy or enemy.get_meta("content_kind",&"")==&"hotel_robot") and not enemy.dead and home>=0 and home<world.rooms.size() and world._is_combat_room(world.rooms[home]))
			for enemy in remaining:
				if not is_instance_valid(enemy) or enemy.dead: continue
				world.activate_room(int(enemy.get_meta("dream_room_id"))); await shoot(world,enemy,30.)
			await frames(15)
		check(world.get_node("ChapterOneRun").can_advance(),"all required rooms cleared before elevator")
		if not world.get_node("ChapterOneRun").can_advance():
			for room in world.rooms: print("FINAL_ROOM ",room.id," state=",world.get_room_state(int(room.id))," remaining=",world.get_node("ChapterOneRun").required_hostiles(int(room.id))," combat=",world._is_combat_room(room))
			quit(1); return
		await collect_badge(world)
		await snap("combat%d_cleared"%(floor+1))
		await next_floor(world)
	check(world.floor_index==2,"two live combat floors reach rest")
	check(world.enemy_root.get_children().is_empty(),"rest floor contains no employees, robots or attack drones")
	await frames(15)
	var adapter: Node=world.get_node("ChapterOneRun")
	check(is_instance_valid(adapter.terminal_collision) and adapter.cameras.has_node("MaintenanceBay"),"workbench has a real pixel mesh and physical footprint")
	world.player.global_position=adapter.terminal_position+Vector2(0,28); await key(KEY_E)
	check(adapter.modal and paused,"rest workbench pauses world for choice")
	await snap("build_choice")
	var damage_before: float=world.player.acquired_damage_multiplier
	adapter.panel.choices.get_child(0).pressed.emit(); await frames(6)
	check(main.chapter_one.state.build=="damage" and world.player.acquired_damage_multiplier>damage_before,"real temporary damage buff applied")
	var buff: float=world.player.acquired_damage_multiplier
	await frames(20); check(is_equal_approx(world.player.acquired_damage_multiplier,buff),"buff not multiplied every frame")
	var retry_seed: int=world.active_seed
	check(await world.restart_current_floor_after_death(),"formal current-floor retry rebuild succeeds")
	await frames(30)
	check(world.floor_index==2 and world.active_seed==retry_seed and main.chapter_one.state.build=="damage","retry preserves floor, layout seed and saved build")
	check(is_equal_approx(world.player.acquired_damage_multiplier,buff),"retry preserves one copy of tarot and build bonuses")
	check(world.enemy_root.get_children().is_empty(),"rest remains safe after retry")
	await collect_badge(world); await next_floor(world); await frames(12)
	check(world.floor_index==3,"rest leads to chapter Boss floor")
	var boss_room: int=world.boss_room_id
	world.player.global_position=Vector2(world.rooms[boss_room].center_cell)*32.; world.activate_room(boss_room); await frames(20)
	var boss: Node2D=world.boss_enemy
	check(is_instance_valid(boss) and boss.boss_variant,"dedicated host encounter uses real boss behavior")
	await snap("boss")
	world.player.global_position=boss.global_position+Vector2(0,96); await shoot(world,boss,60.); await frames(15)
	check(main.chapter_one.state.stage=="RETURN","target Boss commits return stage once")
	await collect_badge(world)
	world.player.global_position=world.elevator_floor_door.get_corridor_approach_position_2d(); await frames(5)
	world.call_deferred("_begin_elevator_entry_transition")
	while main.chapter_one.state.stage=="RETURN": await process_frame
	await settle(); check(main.chapter_one.state.stage=="WAKE","actual return cab arrives at topdown self-wake bedroom")
	await finish_story()
func finish_story() -> void:
	var day_before: int=main.persistent_day_state.calendar_day_id
	if main.chapter_one.state.stage=="WAKE":
		await snap("self_wake")
		await walk_bed(KEY_F)
		while main.chapter_one.state.stage=="WAKE": await process_frame
		check(main.persistent_day_state.calendar_day_id==day_before,"bedside F opens dream without premature day advance")
	await settle()
	check(main.chapter_one.state.stage in ["COAST","COAST_READ"],"self-wake animation precedes coast")
	await snap("coast_arrival")
	var coast: Node=main.current_screen.coast
	var last: Vector3=coast.player_position
	var blocked:=0
	for i in 90:
		if coast.camera_reveal>=.85: break
		Input.action_press("move_up"); await create_timer(.4).timeout; Input.action_release("move_up")
		if coast.player_position.distance_to(last)<.04:
			var lateral: String="move_left" if blocked%2==0 else "move_right"
			blocked+=1; Input.action_press(lateral); await create_timer(.7).timeout; Input.action_release(lateral)
		last=coast.player_position
	check(coast.camera_reveal>=.85,"real movement reaches coastal overlook")
	print("COAST_WALK pos=",coast.player_position," reveal=",coast.camera_reveal)
	await snap("coast_moon")
	while main.chapter_one.state.stage!="COAST_READ": await process_frame
	await snap("coast_signal"); check(main.chapter_one.state.clues==["ch1_S"],"actual dark reading window commits first fragment")
	await record_seconds(2.,"coast_signal")
	main._exit_to_main_menu_from_pause(); await settle(); main._continue_game(); await settle()
	check(main.chapter_one.state.stage=="COAST_READ" and main.current_screen.already_observed,"continue restores observed coast without duplicating clue")
	await key(KEY_E); await settle(); await frames(60)
	check(main.chapter_one.state.complete and main.persistent_day_state.calendar_day_id==day_before+1,"coast exit finishes exactly one day after bedside F")
	check(main.current_screen.scene_file_path=="res://scenes/bedroom/bedroom.tscn","completed day returns to preserved illustrated bedroom")
	await key(KEY_F); check(main.persistent_day_state.calendar_day_id==day_before+1,"extra F cannot increment day again")
	await snap("chapter_complete")
	print("CHAPTER1_ROUTE checks=",checks," failures=",failures," shots=",shots)
	main.queue_free(); await frames(); quit(failures)
func collect_badge(world: Node) -> void:
	await frames(10)
	if not is_instance_valid(world.floor_badge_pickup):
		check(false,"real floor badge exists"); return
	world.player.global_position=world.floor_badge_pickup.global_position+Vector2(0,8); await frames(5); await key(KEY_E); await frames(4)
	check(world.has_floor_badge,"E collects actual floor badge")
func next_floor(world: Node) -> void:
	var old: int=world.floor_index
	world.player.global_position=world.elevator_floor_door.get_corridor_approach_position_2d(); await frames(5)
	world.call_deferred("_begin_elevator_entry_transition")
	while world.floor_index==old or world.floor_transition_in_progress: await process_frame
	await frames(20)
	check(world.floor_index==old+1 and main.chapter_one.state.floor==world.floor_index,"actual elevator changes floor and commits checkpoint")
func walk_bed(code: int) -> void:
	var room: Node=main._supported_dream_world
	# The authored entrance is a narrow throat, not a line-of-sight shortcut.
	# Walk through it before turning toward the bed; no teleported navigation.
	await walk_to(room,Vector2(2.8,3.5)*32.)
	await walk_to(room,Vector2(2.8,1.5)*32.)
	await walk_to(room,Vector2(-1.,1.5)*32.)
	await walk_to(room,Vector2(-1.,-2.5)*32.)
	await walk_to(room,room.destination)
	if room.actor.position.distance_to(room.destination)>=42.:
		print("BED_NAV_BLOCKED position=",room.actor.position," destination=",room.destination," movement=",room.player.movement_enabled," door=",room.entry_open," selected=",room.selected)
		await snap("bed_nav_blocked")
	check(room.actor.position.distance_to(room.destination)<42.,"real walk reaches bedside interaction")
	await key(code)
	if code==KEY_F: await record_seconds(1.3,"bedside_F")
func walk_to(room: Node,point: Vector2) -> void:
	var deadline:=Time.get_ticks_msec()+12000
	while room.player.global_position.distance_to(point)>12. and Time.get_ticks_msec()<deadline:
		var delta: Vector2=point-room.player.global_position
		WALK.hold(room.player,Vector2(0 if absf(delta.x)<8 else delta.x,0 if absf(delta.y)<8 else delta.y))
		await physics_frame; await process_frame
	for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
	await frames(4)
	check(room.player.global_position.distance_to(point)<25.,"walk to "+str(point)+" actual="+str(room.player.global_position))
	if room.player.global_position.distance_to(point)>=25.: await snap("blocked_walk")

func illustrated_evening() -> void:
	var bedroom: Node=main.current_screen
	await snap("illustrated_bedroom")
	await key(KEY_TAB); await create_timer(.8).timeout
	check(main.game_phone.is_open(),"Tab opens existing phone in illustrated bedroom")
	await key(KEY_TAB); await create_timer(.8).timeout
	# Use the bedroom's own interaction handlers and the real bottle GUI.
	bedroom._open_melatonin(); await frames()
	var medicine: Control=bedroom.melatonin_ui
	while not medicine.hand_ready: await process_frame
	var grab:=InputEventMouseButton.new(); grab.button_index=MOUSE_BUTTON_LEFT; grab.pressed=true; grab.position=medicine.bottle_grab_marker.position; medicine._gui_input(grab)
	for stroke in 8:
		if medicine.dispensing: break
		var motion:=InputEventMouseMotion.new(); motion.relative=Vector2(120 if stroke%2==0 else -120,0); motion.position=Vector2(320+motion.relative.x,240); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; medicine._gui_input(motion); await create_timer(.03).timeout
	while medicine.visible: await process_frame
	check(bedroom.melatonin_used_count==1 and main.persistent_day_state.melatonin_inventory==0,"illustrated bedroom uses original shake and swallow interaction")
	bedroom._begin_sleep(false)
	await settle()
