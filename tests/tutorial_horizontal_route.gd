extends SceneTree
const OUT:="res://.runtime/tutorial_horizontal_20261030"
const WALK=preload("res://tests/support/world_walk_input.gd")
var main: Node
var world: Node
var training: Node
var checks:=0
var failures:=0
var timeline: Array=[]
var serial:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int=3) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func pause_real(seconds: float) -> void: await create_timer(seconds,true,false,true).timeout
func key(code: Key) -> void:
	var action: String={KEY_E:"pickup_weapon",KEY_R:"reload_weapon",KEY_SPACE:"dash"}.get(code,"")
	if not action.is_empty(): Input.action_press(action)
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; root.push_input(event,true)
	await frames(2)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	if not action.is_empty(): Input.action_release(action)
	await frames(2)
func snapshot(label: String) -> Image:
	await frames(3); await RenderingServer.frame_post_draw
	var im: Image=world.camera_3d.get_viewport().get_texture().get_image(); im.save_png(OUT+"/"+label+".png"); return im
func gate_snapshot(name: String,label: String,want_green: bool,scheme: int=1) -> void:
	root.get_node("SettingsManager").set_palette_scheme(scheme)
	var gate: Node3D=training._gate(name)
	var old: Vector2=world.player.global_position
	world.player.global_position=Vector2(11.,clampf(gate.global_position.z,4.,21.))*32.
	world.camera_aim_offset=Vector3.ZERO; world._update_camera_and_projection(0.); world.set_process(false)
	var im:=await snapshot(label)
	var pos: Vector2=world.camera_3d.unproject_position(gate.get_node("Indicator").global_position)
	var red:=0; var green:=0
	for y in range(maxi(0,int(pos.y)-8),mini(im.get_height(),int(pos.y)+9)):
		for x in range(maxi(0,int(pos.x)-24),mini(im.get_width(),int(pos.x)+25)):
			var c:=im.get_pixel(x,y)
			if c.r>.2 and c.r>c.g*1.7 and c.r>c.b*1.7: red+=1
			if c.g>.2 and c.g>c.r*1.4 and c.g>c.b*1.15: green+=1
	check(green>0 if want_green else red>0,"Camera palette %d shows %s header in %s (%d red / %d green pixels)"%[scheme,name,"green" if want_green else "red",red,green])
	world.player.global_position=old; world._update_camera_and_projection(0.); world.set_process(true); await frames(3)
func walk(point: Vector2) -> void:
	var until:=Time.get_ticks_msec()+14000
	while world.player.global_position.distance_to(point)>12. and Time.get_ticks_msec()<until:
		var delta: Vector2=point-world.player.global_position
		WALK.hold(world.player,Vector2(0 if absf(delta.x)<7 else delta.x,0 if absf(delta.y)<7 else delta.y))
		await physics_frame; await process_frame
	WALK.release(); await frames(4)
	check(world.player.global_position.distance_to(point)<25.,"real input reaches "+str(point)+" actual="+str(world.player.global_position))
	if world.player.global_position.distance_to(point)>=25.: await snapshot("blocked_walk")
func speed_sample(label: String) -> float:
	world.player.global_position=Vector2(11,21)*32.; world._update_camera_and_projection(0.)
	WALK.hold(world.player,Vector2.UP); await pause_real(.55)
	var start: Vector2=world.player.global_position; var stamp:=Time.get_ticks_usec()
	await clip(.50,label)
	var elapsed: float=(Time.get_ticks_usec()-stamp)/1000000.
	var speed: float=world.player.global_position.distance_to(start)/elapsed
	WALK.release(); await frames(4)
	print("TUTORIAL_SPEED ",label," px_per_real_second=",speed," engine_scale=",Engine.time_scale," locomotion=",world.player.get_time_locomotion_speed())
	return speed
func clip(seconds: float,label: String) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await RenderingServer.frame_post_draw
		var file:="motion/%04d.png"%serial
		world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/"+file)
		timeline.append({"file":file,"time":Time.get_ticks_msec(),"label":label}); serial+=1
		await pause_real(.06)
func zone_check(expected: Array) -> void:
	for i in 3: check(world.training_zone_states.get(i)==expected[i],"zone %d light availability is %s at stage %d"%[i,expected[i],training.stage])
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60; AudioServer.set_bus_mute(0,true)
	create_timer(260.,true,false,true).timeout.connect(func(): push_error("tutorial route watchdog"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUT+"/motion")
	if not InputMap.has_action("attack"): InputMap.add_action("attack")
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(80)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume(); await frames(130)
	world=main._supported_dream_world; training=world.get_node("ChapterTraining")
	world.player.set_meta(&"presentation_pointer_gate",func():return true)
	root.get_node("SettingsManager").set_palette_enabled(true)
	var architecture: Node=world.get_node("TutorialGeometry/ChapterLayout/Architecture")
	check(not architecture.has_node("GalleryCheckpointB") and not architecture.has_node("GalleryCheckpointC") and not architecture.has_node("RangeSafety"),"intermediate corridor and redundant range doors are removed")
	check(architecture.find_children("*","Node3D",false,false).filter(func(n):return n.has_method("set_open")).size()==4,"only three room entries and the corridor terminal hatch remain")
	var a: Vector2=world.camera_3d.unproject_position(Vector3(11,0,19)); var b: Vector2=world.camera_3d.unproject_position(Vector3(11,0,4))
	check(absf(a.y-b.y)<.1 and b.x>a.x,"corridor runs horizontally left to right without diagonal camera yaw")
	zone_check([true,false,false]); await snapshot("start")
	await gate_snapshot("EntryToDash","movement_locked",false)
	check(not world.is_player_dash_landing_allowed(Vector2(4,13)*32.) and not world.is_player_dash_landing_allowed(Vector2(4,4)*32.),"locked lessons reject phase-dash landing before prerequisites")
	await walk(Vector2(128,21*32.)); world._spawn_guide_once(); await pause_real(.8)
	await walk(world.guide.global_position+Vector2(-35,20)); await key(KEY_E)
	for i in 60:
		if training.stage>=2: break
		await key(KEY_E); await pause_real(.10)
	check(training.stage==2,"actual guide conversation unlocks the dash room")
	if training.stage!=2: await snapshot("registration_failed"); quit(1); return
	zone_check([true,true,false]); await gate_snapshot("EntryToDash","movement_unlocked",true)
	await gate_snapshot("EntryToDash","movement_unlocked_palette2",true,2)
	await gate_snapshot("DashToRange","range_locked",false)
	var before:=await speed_sample("before_dash")
	await walk(Vector2(11,15)*32.); await walk(Vector2(4,15)*32.); await walk(Vector2(4,14.4)*32.)
	WALK.hold(world.player,Vector2.UP); await key(KEY_SPACE); await clip(.65,"dash"); WALK.release(); await frames(8)
	check(training.stage==3 and training.dashed,"real Space phase dash completes the second lesson")
	if training.stage!=3: await snapshot("dash_failed"); quit(1); return
	zone_check([true,true,true]); await gate_snapshot("DashToRange","range_unlocked",true)
	var after:=await speed_sample("after_dash")
	check(after>world.player.movement_speed*.80 and after>before*.85,"running speed stays normal after the dash lesson disables further dashes")
	check(not world.player.dash_enabled,"range keeps its intended dash-disabled permission")
	world.player.receive_damage(99999.)
	check(world.player.dead,"real lethal damage enters tutorial retry")
	var retry_until:=Time.get_ticks_msec()+16000
	while world.player.dead and Time.get_ticks_msec()<retry_until: await frames(1)
	check(not world.player.dead and training.stage==3 and not world.player.dash_enabled,"retry restores the current lesson without re-enabling completed dash")
	zone_check([true,true,true])
	# Enter below the ammunition desk's footprint rather than steering into its corner.
	await walk(Vector2(11,7.8)*32.); await walk(Vector2(7,7.8)*32.)
	await walk(training.pickup.global_position+Vector2(0,20)); await key(KEY_E)
	check(training.picked,"actual E picks up the two-round training pistol")
	await walk(Vector2(4,7.5)*32.)
	var target: Node2D=training.training_target
	world.player.set_meta(&"presentation_pointer_position",func():return world.camera_3d.unproject_position(Vector3(target.global_position.x/32.,.65,target.global_position.y/32.)))
	Input.action_press("attack"); await clip(.20,"first_shot"); Input.action_release("attack")
	await key(KEY_R); await clip(2.4,"reload")
	check(training.reload_done,"real manual reload completes after firing")
	var timeout:=Time.get_ticks_msec()+22000
	while is_instance_valid(target) and not target.dead and Time.get_ticks_msec()<timeout:
		Input.action_press("attack"); await clip(.18,"target"); Input.action_release("attack"); await pause_real(.18)
	Input.action_release("attack"); await pause_real(.8)
	check(training.stage==6 and training.target_defeated,"real projectile damage completes the final lesson")
	check(training._gate("Exit").is_open and training.can_exit(),"only the terminal hatch unlocks after all lessons")
	await gate_snapshot("Exit","exit_unlocked",true)
	await snapshot("completed")
	# Real corridor route remains unobstructed after removal of its checkpoint gates.
	await walk(Vector2(7,7)*32.); await walk(Vector2(11,7)*32.)
	await walk(Vector2(11,3.5)*32.)
	WALK.hold(world.player,Vector2.UP); await clip(.55,"corridor_exit"); WALK.release()
	for i in 180:
		if main._supported_dream_world!=world: break
		await frames(1)
	check(main.chapter_one.state.stage=="EVENING" and main.current_screen.scene_file_path=="res://scenes/bedroom/bedroom.tscn","terminal exit preserves tutorial to illustrated-bedroom story flow")
	FileAccess.open(OUT+"/timing.json",FileAccess.WRITE).store_string(JSON.stringify(timeline))
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"before_px_s":before,"after_px_s":after,"gpu":RenderingServer.get_video_adapter_name()},"	"))
	main.queue_free(); await frames(8)
	print("TUTORIAL_HORIZONTAL checks=",checks," failures=",failures); quit(1 if failures else 0)
