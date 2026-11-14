extends SceneTree
## Actual 0-6 world: window trigger, inside-car contact, timed curved departure.
const TRAIN := preload("res://scripts/testing/metro_station/train_chapter.gd")
var display: Control
var world: Node3D
var train: TRAIN
var output := ""
var checks := 0
var failures: Array[String] = []
var departure_seconds := 0.0
var recording := false
var recording_start := 0
var last_recording_frame := 0
var movie_frames: Array[Dictionary] = []

func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in count:await physics_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func pose_contact(at: Vector2) -> void:
	var offset: Vector2=world.player.body_collision.global_position-world.player.global_position
	world.player.global_position=train._pixels(at)-offset
	world.player.velocity=Vector2.ZERO
	world._update_camera_and_actor_projection(0.0)
	await ticks(3)
func wait_phase(target: int,limit: float) -> void:
	var end:=Time.get_ticks_usec()+int(limit*1000000)
	while train.phase!=target and Time.get_ticks_usec()<end:
		record_frame()
		await process_frame
func seconds(value: float) -> void:
	var end:=Time.get_ticks_usec()+int(value*1000000)
	while Time.get_ticks_usec()<end:
		record_frame()
		await process_frame
func record_frame() -> void:
	if not recording or DisplayServer.get_name()=="headless":return
	var now:=Time.get_ticks_usec()
	if last_recording_frame>0 and now-last_recording_frame<33333:return
	last_recording_frame=now
	var file: String="frames/frame_%04d.png" % movie_frames.size()
	display.world_viewport.get_texture().get_image().save_png(output.path_join(file))
	movie_frames.append({"file":file,"seconds":(now-recording_start)/1000000.0})
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image=display.world_viewport.get_texture().get_image()
	check(img.get_size()==Vector2i(1280,720),"Native 0-6 Camera resolution: "+label)
	check(img.save_png(output.path_join(label+".png"))==OK,"Actual Camera: "+label)
func boss_contact_inside(label: String) -> void:
	var bridge: Node3D=train.boss.get_meta(&"depth_visual_bridge").get_ref()
	var contact: Vector3=train._boss_carriage.to_local(bridge._character_ground())
	check(contact.is_equal_approx(train._boss_seat),"Visual contact follows the actual carriage anchor: "+label)
	check(absf(contact.z)<.70 and absf(contact.x)<TRAIN.CONSIST.D.HALF_CAR-.7 and absf(contact.y-.12)<.005,"Boss contact remains inside the cabin and on its floor: "+label)
	print("BOSS_CONTACT ",label," local=",contact," actor=",train._local(train.boss.global_position)," rival_offset=",train.art.rival_train.root.position.x)

func run() -> void:
	create_timer(100.0,true,false,true).timeout.connect(func() -> void:quit(2))
	AudioServer.set_bus_mute(0,true)
	Engine.max_fps=60
	preload("res://tests/support/background_gpu.gd").start(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):output=arg.trim_prefix("--artifact-dir=")
	display=load("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene=display
	world=display.world
	await world.begin_train_chapter(true)
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	train=world._train
	check(RenderingServer.get_current_rendering_method()=="forward_plus","Project uses Forward+ for the actual 0-6 world")
	world.player.set_physics_process(false)
	world.player.dash_invulnerability_left=1000.0
	train.active_car=2
	for i in [0,1]:TRAIN.CONSIST.open_gate(train.art.player_train.car_gates[i],1.0)
	await pose_contact(Vector2(TRAIN.CONSIST.joint(1)+.6,.92))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"Third-car connection does not trigger the boss")
	await pose_contact(Vector2(TRAIN.CONSIST.center(2),.92))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"Central window mullion does not trigger")
	await pose_contact(Vector2(TRAIN.BOSS_TRIGGER_CENTER+2.5,.92))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"Solid wall infill does not trigger the glass encounter")
	await pose_contact(Vector2(TRAIN.BOSS_TRIGGER_X,0.0))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"Third-car middle aisle does not trigger")
	await pose_contact(Vector2(TRAIN.BOSS_TRIGGER_X,-.92))
	check(train.phase==TRAIN.Phase.RIDE and train.boss==null,"Opposite-side window does not trigger")
	await pose_contact(Vector2(TRAIN.BOSS_TRIGGER_X,.92))
	check(train.phase==TRAIN.Phase.APPROACH and is_instance_valid(train.boss),"Facing glass in car three triggers the encounter")
	var captured_arrival:=false
	var captured_talk:=false
	var end:=Time.get_ticks_usec()+12000000
	while train.phase==TRAIN.Phase.APPROACH and Time.get_ticks_usec()<end:
		if not captured_arrival and train._phase_elapsed>=TRAIN.APPROACH_SECONDS-.05:
			captured_arrival=true
			await capture("01_parallel_window_arrival")
		if not captured_talk and train._taunt_line==0:
			captured_talk=true
			await seconds(.25)
			await capture("02_speaker_inside_car")
		await process_frame
	check(train.phase==TRAIN.Phase.BOSS,"Dialogue completes into ordinary boss combat")
	if train.phase!=TRAIN.Phase.BOSS:quit(1);return
	check(absf(train._local(train.boss.body_collision.global_position).x-train._local(world.player.body_collision.global_position).x)<.12,"Boss arrives parallel to the player's window")
	boss_contact_inside("combat")
	await capture("03_combat_inside_car")
	var actual_car:=train._boss_carriage
	check(actual_car==train.art.rival_train._car(TRAIN.FRONT),"Speaker belongs to the rival's actual front carriage despite the relative offset")
	var alive_before:=0
	for crew: Array in train.crews:
		for enemy in crew:
			if is_instance_valid(enemy) and not enemy.dead:alive_before+=1
	check(alive_before>0 and train._local(world.player.global_position).x<TRAIN.CONSIST.joint(TRAIN.FRONT-1),"Early defeat fixture still has frontward combat and is far from the first carriage")
	var defeated_at:=Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	recording=true
	recording_start=defeated_at
	train.boss.take_damage(TRAIN.BOSS_HEALTH+100.0,world.player.global_position,0.0,&"boss_window_test")
	check(train.phase==TRAIN.Phase.FALL and not world.player.movement_enabled,"Defeat immediately starts the timed cinematic wait")
	check(not train._intro_frozen.is_empty(),"Nearby guards and shots pause during the departure cinematic")
	await seconds(1.65)
	check(train.phase==TRAIN.Phase.FALL,"Train remains parallel during the two-second defeat pause")
	await wait_phase(TRAIN.Phase.SPLIT,2.0)
	departure_seconds=(Time.get_ticks_usec()-defeated_at)/1000000.0
	check(train.phase==TRAIN.Phase.SPLIT and departure_seconds>=1.90 and departure_seconds<2.25,"Turning begins two seconds after defeat without waiting for the front carriage")
	print("DEPARTURE_SECONDS ",departure_seconds)
	await seconds(.45)
	check(absf(actual_car.rotation.y)>.02,"Rival follows a curved turnout immediately after the delay")
	boss_contact_inside("turning")
	await capture("04_curved_departure")
	await wait_phase(TRAIN.Phase.CLEAR_CARS,5.0)
	record_frame()
	recording=false
	FileAccess.open(output.path_join("movie_timing.json"),FileAccess.WRITE).store_string(JSON.stringify(movie_frames,"\t"))
	check(train.phase==TRAIN.Phase.CLEAR_CARS and world.player.movement_enabled,"Rival departure restores movement for remaining carriage combat")
	check(not train.art.rival_train.root.visible and train.boss==null and train._intro_frozen.is_empty(),"Departed boss and frozen-combat state clean up")
	check(train.art.station==null,"Station does not bypass remaining live guards")
	var alive_after:=0
	for crew: Array in train.crews:
		for enemy in crew:
			if is_instance_valid(enemy) and not enemy.dead:
				alive_after+=1
				enemy.take_damage(enemy.maximum_health+100.0,world.player.global_position,0.0,&"route_finish_test")
	check(alive_after==alive_before,"Departure does not delete remaining player-train enemies")
	train.active_car=TRAIN.FRONT
	await pose_contact(Vector2(TRAIN.CONSIST.center(TRAIN.FRONT),0))
	check(train.phase==TRAIN.Phase.COAST,"Completing the player train starts the original station approach")
	await wait_phase(TRAIN.Phase.PLATFORM,10.0)
	check(train.phase==TRAIN.Phase.PLATFORM and world.player.movement_enabled,"Departure still leads to a usable station exit")
	await capture("05_station_after_departure")
	var previous: WeakRef=weakref(train.art.root)
	world.regenerate(world.seed)
	await ticks(5)
	check(previous.get_ref()==null and world._train==null,"Reset releases train anchors, countdown and turnout")
	await world.begin_train_chapter(true)
	train=world._train
	world.player.set_physics_process(false)
	train.active_car=2
	await pose_contact(Vector2(TRAIN.CONSIST.joint(1)+.6,.92))
	check(train.phase==TRAIN.Phase.RIDE,"Repeat entry does not retain an old boss trigger")
	await pose_contact(Vector2(TRAIN.BOSS_TRIGGER_X,.92))
	check(train.phase==TRAIN.Phase.APPROACH,"Repeat entry still triggers at the glass")
	world.regenerate(world.seed)
	await ticks(5)
	check(world._train==null and world.player.movement_enabled,"Reset during dialogue restores player control")
	await world.begin_train_chapter(true)
	train=world._train
	world.player.set_physics_process(false)
	train.active_car=2
	await pose_contact(Vector2(TRAIN.BOSS_TRIGGER_CENTER+.8,.92))
	check(train.phase==TRAIN.Phase.APPROACH,"Restored central glass also triggers, without requiring one particular pane")
	world.regenerate(world.seed)
	await ticks(5)
	check(world._train==null and world.player.movement_enabled,"Repeated central-window reset leaves no control lock")
	display.free()
	await ticks(3)
	FileAccess.open(output.path_join("validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"departure_seconds":departure_seconds,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Actual 0-6 window trigger, cabin contact, 2s early-defeat curved departure with live guards, remaining own-train combat, station and repeated/reset activation; Camera readbacks are not a performance sample."},"\t"))
	print("BOSS_WINDOW checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
