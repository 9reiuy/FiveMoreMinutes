extends SceneTree
const TRAIN := preload("res://scripts/testing/metro_station/train_chapter.gd")
const INPUTS := preload("res://scripts/app/game_input_actions.gd")
const WALK := preload("res://tests/support/world_walk_input.gd")
var display: Control
var world: Node3D
var train: TRAIN
var output := ""
var checks := 0
var failures: Array[String] = []
var frames: Array[float] = []
var _last_usec := 0
var _opening_presented_usec := 0
var _opening_card_ms := 0.0
var _blocked_start_survived := false


func observe_cue(node: Node) -> void:
	if not node.has_signal(&"cue_presented"): return
	node.cue_started.connect(func(message: String):
		if message != "扔出去" or _opening_presented_usec != 0: return
		# Reproduce a first-use loading stall longer than the entire short card.
		OS.delay_msec(700)
		_blocked_start_survived = node.active and not node.presented and not world.opening_complete and is_zero_approx(world.opening_elapsed_real))
	node.cue_presented.connect(func(message: String):
		if message == "扔出去":
			_opening_presented_usec = Time.get_ticks_usec()
			if DisplayServer.get_name() != "headless" and not FileAccess.file_exists(output.path_join("00_opening_cue.png")):
				check(root.get_texture().get_image().save_png(output.path_join("00_opening_cue.png")) == OK,"Actual root HUD shows the opening cue over the rendered level"))
	node.cue_finished.connect(func(message: String, completed: bool):
		if message == "扔出去" and completed:
			_opening_card_ms = (Time.get_ticks_usec()-_opening_presented_usec)/1000.0)


func _initialize() -> void: call_deferred("run")


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last_usec > 0: frames.append((now-_last_usec)/1000.0)
	_last_usec = now
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
	return false


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ",label)


func ticks(count: int) -> void:
	for i in count: await physics_frame


func seconds(value: float) -> void:
	var end := Time.get_ticks_usec()+roundi(value*1000000.0)
	while Time.get_ticks_usec() < end: await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = display.world_viewport.get_texture().get_image()
	check(picture.save_png(output.path_join(label+".png")) == OK,"Actual Camera "+label)


func press(key: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func freeze_guards() -> void:
	for enemy: EmployeeEnemy in world.enemy_root.get_children(): enemy.set_physics_process(false)


func defeat_crew(index: int) -> void:
	for enemy in train.crews[index]:
		if is_instance_valid(enemy) and not enemy.dead: enemy.take_damage(enemy.maximum_health+100.0,world.player.global_position,0.0,&"train_route_check")


func pose(at: Vector2) -> void:
	world.player.global_position = train._pixels(at)
	world.player.velocity = Vector2.ZERO
	world._update_camera_and_actor_projection(0.0)
	await ticks(3)


func opening_and_keys() -> void:
	INPUTS.configure()
	var reserved_free := true
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and (event.physical_keycode in [KEY_SHIFT,KEY_T] or event.keycode in [KEY_SHIFT,KEY_T]): reserved_free = false
	check(reserved_free and InputMap.action_get_events("dash").is_empty() and InputMap.action_get_events("toggle_slow_time").is_empty() and InputMap.action_get_events("bullet_time").is_empty(),"Shift/T have no actions and fast-dash/manual-time bindings are empty")
	check(InputMap.action_get_events("roll").any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_SPACE),"Space still binds the roll")
	var injected := InputEventKey.new()
	injected.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("dash",injected)
	INPUTS.configure()
	INPUTS.configure()
	check(InputMap.action_get_events("dash").is_empty(),"Repeated startup removes a stale Shift binding")
	node_added.connect(observe_cue)
	var entry := "res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn" if OS.get_cmdline_user_args().has("--case=linked-opening") else "res://scenes/testing/MegastructureWhiteboxDisplay.tscn"
	display = load(entry).instantiate()
	root.add_child(display)
	current_scene = display
	world = display.world
	world.player.dash_invulnerability_left = 1000.0
	freeze_guards()
	await ticks(3)
	check(not world.opening_complete and Engine.time_scale < .06,"0-1 still starts at x0.05")
	var ready_deadline := Time.get_ticks_msec()+30000
	while not world._opening_clock_ready and Time.get_ticks_msec() < ready_deadline: await process_frame
	check(_blocked_start_survived and _opening_presented_usec > 0,"Loading longer than the short card cannot consume the opening cue or slow-motion clock")
	var start := _opening_presented_usec/1000
	if is_instance_valid(world.run_interface.player_cue) and world.run_interface.player_cue.active:
		await world.run_interface.player_cue.cue_finished
	check(_opening_card_ms >= 450.0 and _opening_card_ms < 700.0,"The complete short card is displayed after its first rendered frame")
	root.get_node("PauseManager").request_pause(&"TEST_OPENING")
	await seconds(.30)
	root.get_node("PauseManager").release_pause(&"TEST_OPENING")
	await seconds(1.8)
	print("OPENING EARLY complete=",world.opening_complete," enemy_dead=",world.opening_enemy.dead," speed=",Engine.time_scale," real_ms=",Time.get_ticks_msec()-start," paused=",paused)
	check(not world.opening_complete and not world.opening_enemy.dead,"Pause and the first two real seconds do not end the opening")
	while not world.opening_complete and Time.get_ticks_msec()-start < 4800: await process_frame
	await ticks(3)
	print("OPENING LATE complete=",world.opening_complete," enemy_dead=",world.opening_enemy.dead," speed=",Engine.time_scale," real_ms=",Time.get_ticks_msec()-start," controller=",world._get_dream_time_controller().tactical_planning_active)
	check(world.opening_complete and not world.opening_enemy.dead and is_equal_approx(Engine.time_scale,1.0),"Opening returns to normal after three unpaused real seconds even with the enemy alive")
	check(world.opening_elapsed_real >= 3.0 and world.opening_elapsed_real < 3.2,"Three-second timeout is measured from visible entry and excludes pause")
	print("OPENING VISIBLE card_ms=",_opening_card_ms," active_real_seconds=",world.opening_elapsed_real)
	# Keep the key comparison independent of a live incoming round's near-miss
	# feedback. The real projectile was already verified moving under the card.
	freeze_guards()
	for projectile: Node in get_nodes_in_group(&"dream_projectiles"): projectile.set_physics_process(false)
	world._get_dream_time_controller().clear_reaction_time()
	world._get_dream_time_controller().reset_hit_stop()
	await ticks(2)
	for key: int in [KEY_SHIFT,KEY_T]:
		var before_scale := Engine.time_scale
		press(key,true)
		await ticks(3)
		press(key,false)
		print("KEY CHECK key=",key," before=",before_scale," after=",Engine.time_scale," dash=",world.player.dashing," toggle=",world._get_dream_time_controller().is_slow_time_enabled()," reaction=",world._get_dream_time_controller().is_reaction_time_active()," hitstop=",world._get_dream_time_controller().hitstop_active," events=",InputMap.action_get_events("toggle_slow_time"))
		check(not world.player.dashing and not world._get_dream_time_controller().is_slow_time_enabled() and is_equal_approx(Engine.time_scale,1.0),"Physical key is inert: "+str(key))
	world.regenerate(world.seed)
	world._apply_opening_time()
	world.player.dash_invulnerability_left = 1000.0
	freeze_guards()
	await seconds(.3)
	world.opening_enemy.take_damage(world.opening_enemy.maximum_health+100.0,world.player.global_position,0.0,&"opening_test")
	await ticks(3)
	check(world.opening_complete and is_equal_approx(Engine.time_scale,1.0),"Killing the first enemy still ends slow motion early")
	display.free()
	await ticks(4)


func chase_and_derailment() -> void:
	display = load("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene = display
	world = display.world
	world.player.dash_invulnerability_left = 1000.0
	await world.begin_train_chapter(true)
	train = world._train
	world.player.configure_weapon("assault_rifle",world.config,{})
	world.player.dash_invulnerability_left = 1000.0
	check(train.crews[0].is_empty() and train.derailment.next_car == 0,"The rear car starts empty and its destruction clock starts fresh")
	await pose(Vector2(TRAIN.CONSIST.joint(0)-1,0))
	await ticks(50)
	check(train.active_car == 1 and train.phase == TRAIN.Phase.RIDE and train.boss == null,"Opening the second car does not trigger the boss")
	defeat_crew(1)
	await pose(Vector2(TRAIN.CONSIST.joint(1)-1,0))
	await ticks(50)
	check(train.active_car == 2 and train.phase == TRAIN.Phase.RIDE and train.boss == null,"Opening the third gate still waits for the player to enter")
	await pose(Vector2(TRAIN.CONSIST.joint(1)+.5,0))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"The third-car connection does not trigger the boss")
	await pose(Vector2(TRAIN.CONSIST.center(2),0))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"Standing in the middle of car three does not trigger the window scene")
	await pose(Vector2(TRAIN.BOSS_TRIGGER_X,.92)-world.player.body_collision.position/world.CELL_PIXELS)
	var intro_player_x: float=train._local(world.player.global_position).x
	check(train.phase == TRAIN.Phase.APPROACH and is_instance_valid(train.boss),"Reaching the third-car facing window starts the boss train")
	check(absf(TRAIN.BOSS_START_X+train._rival_intro_offset-intro_player_x)<.01,"Enemy's arrival targets the player's actual longitudinal position")
	check(not train._intro_frozen.is_empty() and not world.player.movement_enabled,"Nearby combat waits during the close-up dialogue")
	await capture("01_third_car_approach")
	var stopped_clock: float = train.derailment.elapsed_real
	var deadline := Time.get_ticks_msec()+12000
	var arrival_captured := false
	while train.phase == TRAIN.Phase.APPROACH and Time.get_ticks_msec() < deadline:
		if not arrival_captured and train._phase_elapsed >= TRAIN.APPROACH_SECONDS-.08:
			arrival_captured = true
			check(absf(train._local(train.boss.global_position).x-intro_player_x)<.12,"Arrival reaches the player's side before dialogue focus begins")
			await capture("01b_parallel_arrival")
		await process_frame
	print("CHASE INTRO phase=",train.phase," elapsed=",train._phase_elapsed," dialogue=",world.dialogue_camera.state," line=",train._taunt_line," pause=",paused," speed=",Engine.time_scale," player_dead=",world.player.dead," cause=",world.player.last_damage_source," clock=",train.derailment.elapsed_real)
	check(train.phase == TRAIN.Phase.BOSS and train.derailment.elapsed_real-stopped_clock < .3,"Uncontrollable dialogue suspends the destruction countdown")
	check(absf(train._local(train.boss.global_position).x-intro_player_x)<.12,"Speaker appears beside the player rather than at the front of their carriage")
	if train.phase != TRAIN.Phase.BOSS: return
	# Keep the real Space roll available while the old Shift action stays empty.
	world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	press(KEY_SPACE,true)
	await ticks(2)
	press(KEY_SPACE,false)
	deadline = Time.get_ticks_msec()+2500
	while is_instance_valid(train._slow_owner) and Time.get_ticks_msec() < deadline: await process_frame
	check(not is_instance_valid(train._slow_owner) and world.player.phase_dash != null and world.player.phase_dash.dive_roll,"Space roll releases the authored boss slow-motion intro")
	world.player.dash_invulnerability_left = 1000.0
	world.player.remove_meta(&"aim_direction_override")
	var relative_before := train._local(train.boss.body_collision.global_position)-Vector2(train.art.rival_train.root.position.x,0)
	var x_before: float = train.art.rival_train.root.position.x
	await seconds(.8)
	var relative_after := train._local(train.boss.body_collision.global_position)-Vector2(train.art.rival_train.root.position.x,0)
	check(relative_before.is_equal_approx(relative_after) and absf(relative_after.x-TRAIN.BOSS_START_X) < .01 and absf(relative_after.y-TRAIN.BOSS_WINDOW_Z) < .01,"Boss stands at a fixed window while the train carries it")
	check(train.art.rival_train.root.position.x > x_before and train.art.rival_train.root.position.x <= 0.0,"Rival train overtakes toward the front alignment")
	check(absf(train.art.rival_train._solids.position.x-(TRAIN.ART.OFFSET.x+train.art.rival_train.root.position.x)*32.0) < .01,"The moving rival train keeps glass and walls aligned with the visual")
	await capture("02_window_shooter")
	var clock_start := Time.get_ticks_msec()
	var elapsed_before: float = train.derailment.elapsed_real
	while train.derailment.next_car == 0 and Time.get_ticks_msec()-clock_start < 23000: await process_frame
	var active_wait := (Time.get_ticks_msec()-clock_start)/1000.0
	check(train.derailment.next_car == 1 and absf(active_wait-(20.0-elapsed_before)) < .8,"The first real 20-second deadline explodes exactly the last car")
	check(not world.player.dead and not train.derailment.wrecks.is_empty(),"A player in a live frontward car survives and the original rear model derails")
	check(not world.floor_cells.has(TRAIN.ART.OFFSET+Vector2i(8,0)) and world.room_states[0] == &"RETIRED" and not train.rooms_open(0,1),"Exploded car loses floor support and cannot be re-entered")
	await capture_wreck()
	train.derailment.elapsed_real = 39.9
	train.derailment.advance(.2)
	await ticks(3)
	check(train.derailment.next_car == 2 and train.derailment.retired.has(1) and not train.derailment.retired.has(2),"Subsequent 20-second deadline retires the next rear car in order")
	for index in range(2,TRAIN.CONSIST.CAR_COUNT): defeat_crew(index)
	train._finish_dodge_intro()
	train.boss.take_damage(TRAIN.BOSS_HEALTH+100.0,world.player.global_position,0.0,&"boss_route_check")
	await ticks(4)
	check(train._boss_defeated_pending and train.phase == TRAIN.Phase.FALL and not world.player.movement_enabled,"Boss defeat immediately begins the two-second departure wait")
	train.boss.death_presentation_left=.05
	await ticks(12)
	check(is_instance_valid(train.boss) and train.boss.death_presentation_left>0.0,"Early defeated speaker remains owned by the chapter until its train departs")
	deadline=Time.get_ticks_msec()+8000
	while train.phase in [TRAIN.Phase.FALL,TRAIN.Phase.SPLIT] and Time.get_ticks_msec()<deadline:await process_frame
	check(train.phase==TRAIN.Phase.CLEAR_CARS and world.player.movement_enabled and not train.art.rival_train.root.visible,"Rival leaves before the player reaches the front and restores normal movement")
	print("CHASE WALK start=",train._local(world.player.global_position)," body_offset=",world.player.body_collision.position," active_car=",train.active_car," clock=",train.derailment.elapsed_real," speed=",Engine.time_scale)
	deadline = Time.get_ticks_msec()+45000
	while train.phase == TRAIN.Phase.CLEAR_CARS and Time.get_ticks_msec() < deadline and not world.player.dead:
		# Steer the actual walking circle through the narrow gangway after the
		# Space roll; its local offset need not equal the actor's sprite origin.
		var at := train._local(world.player.body_collision.global_position)
		WALK.hold(world.player,Vector2(1.0,clampf(-at.y*2.0,-1.0,1.0)))
		await physics_frame
	WALK.release()
	print("CHASE WALK end=",train._local(world.player.global_position)," phase=",train.phase," active_car=",train.active_car," dead=",world.player.dead," cause=",world.player.last_damage_source," clock=",train.derailment.elapsed_real)
	check(not world.player.dead and train.phase == TRAIN.Phase.COAST and train._local(world.player.global_position).x >= TRAIN.CONSIST.joint(TRAIN.FRONT-1),"Ordinary movement clears the remaining gates before the station approach")
	var count: int = train.derailment.next_car
	deadline = Time.get_ticks_msec()+18000
	while train.phase < TRAIN.Phase.PLATFORM and Time.get_ticks_msec() < deadline: await process_frame
	check(train.phase == TRAIN.Phase.PLATFORM and train.derailment.next_car == count,"Defeat, departure and docking still complete with the destruction clock stopped")
	check(not world.floor_cells.has(TRAIN.ART.OFFSET+Vector2i(8,0)),"Docking does not resurrect the exploded rear floors")
	await capture("04_front_car_arrival")
	var old: WeakRef = weakref(train.derailment)
	world.regenerate(world.seed)
	await ticks(15)
	check(old.get_ref() == null and world._train == null,"Restart removes timers, explosion particles and derailed car models")
	await world.begin_train_chapter(true)
	train = world._train
	check(train.derailment.next_car == 0 and train.derailment.retired.is_empty(),"Entering again gives all six cars and a new destruction clock")
	train.derailment.advance(20.0)
	await ticks(3)
	check(world.player.dead and world.player.last_damage_source == &"train_derailment","Staying in the exploding rear carriage causes a real hazard death")
	check(world.restart_current_floor_after_death(),"The public death-restart path accepts a derailment death")
	await ticks(15)
	check(not world.player.dead and world._train == null,"A derailment death can restart cleanly")
	await world.begin_train_chapter(true)
	train = world._train
	world.player.global_position = train._pixels(Vector2(TRAIN.CONSIST.center(TRAIN.FRONT),0))
	train.derailment.advance(120.0)
	await ticks(3)
	check(train.derailment.next_car == TRAIN.CONSIST.CAR_COUNT and train.derailment.retired.size() == TRAIN.CONSIST.CAR_COUNT and world.player.dead,"Injected 120-second deadline retires all six cars in order and destroys the first car last")
	check(world.restart_current_floor_after_death(),"The completely derailed train also restarts")
	await ticks(10)


func capture_wreck() -> void:
	if DisplayServer.get_name() == "headless": return
	# Same gameplay Camera and renderer, temporarily framed on the remote wreck.
	var saved: Transform3D = world.camera_rig.transform
	world.set_process(false)
	world.set_physics_process(false)
	var car: Node3D = train.derailment.wrecks[0].node
	world.camera_rig.position = world.to_local(car.global_position)
	await ticks(9)
	await capture("03_derailment_detail_camera")
	world.camera_rig.transform = saved
	world.set_process(true)
	world.set_physics_process(true)


func run() -> void:
	# Headless can advance fixed engine frames faster than wall-clock time.
	# Match the real-time controller's clock for timer/key/animation checks.
	Engine.max_fps = 60
	INPUTS.configure()
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		process_frame.connect(func(): RenderingServer.force_draw(false))
	if not OS.get_cmdline_user_args().has("--case=choreography"): await opening_and_keys()
	if not OS.get_cmdline_user_args().has("--case=opening") and not OS.get_cmdline_user_args().has("--case=linked-opening"): await chase_and_derailment()
	frames.sort()
	var timing := {}
	for q: float in [.5,.95,.99,1.0]: timing[str(q)] = frames[clampi(ceili(frames.size()*q)-1,0,frames.size()-1)]
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"frames":frames.size(),"frame_ms_percentiles":timing,"scope":"Opening timeout, real keys, third-car chase, actual first 20s deadline, later injected deadline, walking gates and docking/death/restart; not whole-game performance"},"\t"))
	print("TRAIN CHASE checks=",checks," failures=",failures)
	if is_instance_valid(display): display.free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
