extends SceneTree
var OUT:="res://.runtime/tutorial_revision_20261108/manual_route"
const WALK=preload("res://tests/support/world_walk_input.gd")
var lab: Control
var world: Node
var training: Node
var checks:=0
var failures:=0
var timeline: Array=[]
var serial:=0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):OUT=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func frames(n: int=3) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func pause_real(seconds: float) -> void: await create_timer(seconds,true,false,true).timeout
func key(code: Key) -> void:
	var action: String={KEY_E:"pickup_weapon",KEY_R:"reload_weapon",KEY_SPACE:"roll"}.get(code,"")
	if not action.is_empty(): Input.action_press(action)
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; root.push_input(event,true)
	await frames(2)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	if not action.is_empty(): Input.action_release(action)
	await frames(2)
func fire(pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	event.position=root.get_visible_rect().size*.5;event.global_position=event.position
	Input.parse_input_event(event)
func snapshot(label: String) -> Image:
	await frames(3); await RenderingServer.frame_post_draw
	var im: Image=world.camera_3d.get_viewport().get_texture().get_image(); im.save_png(OUT+"/"+label+".png")
	root.get_texture().get_image().save_png(OUT+"/"+label+"_ui.png")
	return im

var dialogue_history: Array=[]
var bullet_speeds: Array=[]
func walk(point: Vector2) -> void:
	var deadline:=Time.get_ticks_msec()+14000
	while world.player.global_position.distance_to(point)>12.0 and Time.get_ticks_msec()<deadline:
		var delta: Vector2=point-world.player.global_position
		WALK.hold(world.player,Vector2(0 if absf(delta.x)<7 else delta.x,0 if absf(delta.y)<7 else delta.y))
		await physics_frame;await process_frame
	WALK.release();await frames(4)
	check(world.player.global_position.distance_to(point)<25.0,"Real input reaches "+str(point)+" actual="+str(world.player.global_position))
func converse(room: int,next_stage: int) -> void:
	await walk(world.get_tutorial_terminal(room).global_position+Vector2(36,0))
	await snapshot("tv_%d_before_e"%room);await key(KEY_E)
	await pause_real(.9);await snapshot("tv_%d_dialogue"%room)
	var deadline:=Time.get_ticks_msec()+16000
	while training.stage!=next_stage and Time.get_ticks_msec()<deadline:
		await key(KEY_E);await pause_real(.16)
	check(training.stage==next_stage,"Actual TV %d E interaction completes its dialogue"%(room+1))
func _capture_bullet(node: Node) -> void:
	if is_instance_valid(node):bullet_speeds.append(float(node.get("speed")))
func _node_added(node: Node) -> void:
	var script: Script=node.get_script()
	if script!=null and script.resource_path=="res://scripts/entities/basic_projectile.gd":call_deferred("_capture_bullet",node)
func room_state(room: int,powered: bool,closed: bool) -> void:
	check(bool(world.training_zone_states.get(room,false))==powered,"Room %d power is %s"%[room+1,powered])
	var gate: Node3D=training._gate(["PreparationDoor","EntryToDash","DashToRange"][room])
	check(gate.is_open!=closed,"Room %d door state is correct"%(room+1))
	if not powered:
		check(not gate.status_light.visible and not world.monitor_feed.stations[room].screen_active,"Room %d door light and TV are off"%(room+1))

func check_hands(armed: bool) -> void:
	var mouse: Array[Vector2]=[Vector2.ZERO]
	var previous_pointer: Callable=world.player.get_meta(&"presentation_pointer_position",Callable())
	world.player.set_meta(&"presentation_pointer_position",func():return mouse[0])
	var torso: Vector2=world.camera_3d.unproject_position(world.get_gameplay_world_position(world.player.global_position,.65))
	for index in 8:
		mouse[0]=torso+Vector2.RIGHT.rotated(index*TAU/8.0)*100.0
		await frames(8)
		if not armed:
			var hand: Sprite2D=world.player.right_hand_part
			var point: Vector2=hand.position+hand.texture.get_size()*.5
			var angle:=Vector2(point.x/12.0,(point.y-8.0)/6.0).angle()-.8
			var expected: float=world.get_hand_presentation_direction().angle()
			check(absf(wrapf(angle-expected,-PI,PI))<.03,"Unarmed hands follow screen mouse quadrant "+str(index))
		else:
			world.player._update_held_weapon_aim_at(mouse[0])
			var shot: Dictionary=world.player_depth_bridge.get_weapon_visual_snapshot(world.player.projectile_origin.global_position)
			var origin: Vector3=shot.world_origin
			var direction: Vector2=world.player.get_aim_direction()
			var a: Vector2=world.camera_3d.unproject_position(origin)
			var b: Vector2=world.camera_3d.unproject_position(origin+Vector3(direction.x,0,direction.y))
			check(absf(wrapf((b-a).angle()-(mouse[0]-a).angle(),-PI,PI))<.04,"Armed muzzle follows mouse quadrant "+str(index))
		if index in [0,2,4,6]:await snapshot(("armed_" if armed else "hands_")+str(index))
	if previous_pointer.is_valid():world.player.set_meta(&"presentation_pointer_position",previous_pointer)
	else:world.player.remove_meta(&"presentation_pointer_position")

func run() -> void:
	var master:=AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		quit(1);return
	preload("res://tests/support/background_gpu.gd").start(self)
	DirAccess.make_dir_recursive_absolute(OUT+"/motion")
	create_timer(200.0,true,false,true).timeout.connect(func():push_error("Revision route timeout");quit(2))
	lab = load("res://scenes/testing/GameTestLab.tscn").instantiate()
	lab.presentation_scene_path = "res://scenes/testing/TutorialMaintenanceDisplay.tscn"
	root.add_child(lab)
	await frames(12)
	world = lab.presentation.world
	training = world.get_node("ChapterTraining")
	var finished: Array[int] = [0]
	world.tutorial_finished.connect(func():finished[0] += 1)
	world.player.set_meta(&"presentation_pointer_gate",func():return true)
	world.dialogue_controller.dialogue_line_started.connect(func(_index,row):dialogue_history.append(String(row.text)))
	node_added.connect(_node_added)
	await snapshot("start");await check_hands(false)
	await converse(0,training.Stage.JUMP_CALL)
	check(dialogue_history==["这里简单做个入职测试","到隔壁房间去"],"First TV exact dialogue order")
	await walk(Vector2(11,21)*32.0);room_state(0,true,true)
	await walk(Vector2(11,13)*32.0)
	await walk(Vector2(4,13)*32.0)
	room_state(0,false,true)
	await snapshot("jump_call");await pause_real(2.3)
	check(training.stage==training.Stage.JUMP_CALL,"Second TV call loops without advancing the lesson")
	await converse(1,training.Stage.JUMP_TEST)
	await pause_real(.25)
	check(world.control_hint.visible and world.control_hint.label.text == "使用空格键进行翻滚", "Roll hint is visible after the TV releases control")
	await snapshot("roll_hint")
	await walk(Vector2(4,14.4)*32.0)
	var origin: Vector2=world.player.global_position
	WALK.hold(world.player,Vector2.UP);await key(KEY_SPACE);await pause_real(.65);WALK.release();await frames(8)
	var landing: Vector2=world.player.global_position
	for attempt in 35:
		if training.stage==training.Stage.RANGE_CALL:break
		await key(KEY_E);await pause_real(.12)
	check(training.dashed and training.stage==training.Stage.RANGE_CALL,"Real left-to-right jump crosses the finish line and receives 好的")
	check(origin.y>=training.START_LINE-10 and landing.y<=training.FINISH_LINE+10,"Jump begins at the left line and lands beyond the right line")
	await snapshot("jump_complete")
	await walk(Vector2(4,13)*32.0);await walk(Vector2(11,13)*32.0);room_state(1,true,true)
	await snapshot("corridor_previous_room_still_lit")
	await walk(Vector2(11,5)*32.0);await walk(Vector2(4,5)*32.0)
	room_state(1,false,true)
	await snapshot("range_call")
	await converse(2,training.Stage.RANGE_TEST)
	await pause_real(.25)
	check(world.control_hint.visible and world.control_hint.label.text == "接近物品后按 E 拿取", "Pickup hint is visible before collecting the pistol")
	await snapshot("pickup_hint")
	await walk(training.WEAPON_APPROACH)
	await snapshot("weapon_cabinet_before_pickup")
	await key(KEY_E)
	check(training.picked and world.player.runtime_config.basic_projectile_speed==1500.0,"Real E picks up the formal-speed pistol")
	await walk(Vector2(4,6.5)*32.0)
	await check_hands(true)
	var target: Node2D=training.training_target
	world.player.set_meta(&"presentation_pointer_position",func():return world.camera_3d.unproject_position(world.get_gameplay_world_position(target.global_position,.65)))
	var deadline:=Time.get_ticks_msec()+6000
	while not target.dead and Time.get_ticks_msec()<deadline:
		fire(true);await pause_real(.14);fire(false);await pause_real(.18)
	check(target.dead and training.target_defeated,"Real projectile damage defeats the 50-health mannequin")
	check(not bullet_speeds.is_empty() and bullet_speeds.all(func(speed):return speed==world.FORMAL_WORLD.FIREARM_PROJECTILE_SPEED_3D),"Emitted projectile instances use formal speed 1500")
	await frames(4)
	await key(KEY_E)
	await key(KEY_E)
	await pause_real(.8)
	await snapshot("weapon_ownership_dialogue")
	for attempt in 50:
		if training.stage == training.Stage.RETURN_WEAPON:break
		await key(KEY_E);await pause_real(.12)
	check(training.stage == training.Stage.RETURN_WEAPON and not training.can_exit(), "Weapon return follows the shooting dialogue")
	await snapshot("return_weapon_hint")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = root.get_final_transform() * root.get_visible_rect().size * 0.5
		Input.parse_input_event(event)
		await physics_frame
		await frames(4)
	check(training.weapon_returned and world.player.selected_weapon_id.is_empty(), "Real right-click release returns the training pistol")
	await pause_real(1.1)
	await snapshot("weapon_return_dialogue")
	check(world.dialogue_controller.is_active() and not training.can_exit(), "Payroll line waits for acknowledgement before the exit opens")
	for attempt in 50:
		if training.can_exit():break
		await key(KEY_E);await pause_real(.12)
	check(training.can_exit() and dialogue_history==["这里简单做个入职测试","到隔壁房间去","这里测试一下跳跃能力","请在左边线向右边进行起跳","好的","拿起武器柜里的枪","朝着假人射过去","好的","训练所用的武器归公司所属，请不要带走","谢谢配合，本次训练的子弹武器磨损费将从本月工资扣除"],"All requested TV lines appear in the exact lesson order")
	await snapshot("completed")
	await walk(Vector2(7.8,5)*32.0);await walk(Vector2(11,5)*32.0);await walk(Vector2(11,3.5)*32.0)
	WALK.hold(world.player,Vector2.UP);await pause_real(.6);WALK.release()
	for frame in 150:
		if finished[0] > 0:break
		await process_frame
	check(finished[0] == 1 and world.exit_sequence_started, "Standalone tutorial completes once after returning the weapon")
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name(),"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"dialogue":dialogue_history,"projectile_speeds":bullet_speeds,"jump_origin":origin,"jump_landing":landing},"\t"))
	lab.queue_free();await frames(8);print("REVISION_ROUTE checks=",checks," failures=",failures);quit(1 if failures else 0)
