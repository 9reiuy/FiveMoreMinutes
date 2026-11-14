extends SceneTree
var out := "res://.runtime/tutorial_revision_20261108/check"
var checks: Array[Dictionary]=[]
func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):out=argument.trim_prefix("--artifact-dir=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"description":label});print("PASS: " if ok else "FAIL: ",label)
func frames(count: int=4) -> void:
	for frame in count:await process_frame
func finish_dialogue(world: Node) -> void:
	for attempt in 50:
		if not world.dialogue_controller.is_active():return
		world.dialogue_controller._process(.8);world.dialogue_controller.advance_sequence()
		await create_timer(.12,true,false,true).timeout
func run() -> void:
	await process_frame
	var master:=AudioServer.get_bus_index(&"Master")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0:AudioServer.set_bus_mute(master,true)
		quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var display: Node=load("res://scenes/testing/TutorialMaintenanceDisplay.tscn").instantiate();root.add_child(display);current_scene=display
	await frames(12)
	var world: Node3D=display.world;var lesson: Node=world.get_node("ChapterTraining")
	world.player.set_physics_process(false)
	var hint: Control = world.control_hint
	check(hint.visible and hint.label.text == "使用键盘 WASD 控制移动\n使用鼠标移动镜头", "First room presents movement and camera controls")
	var entered_at: int = hint._started_at_msec
	await create_timer(0.40, true, false, true).timeout
	check(hint.content.position == Vector2.ZERO and hint.position == Vector2(10, 40), "Control hint fades in below the compact health meter without sliding")
	paused = true
	while hint.visible and Time.get_ticks_msec() - entered_at < 3250:
		await process_frame
	check(not hint.visible and Time.get_ticks_msec() - entered_at <= 3150, "Hint expires within three real seconds including entry, even during pause")
	paused = false
	await frames()
	check(not hint.visible, "The same room does not repeat an expired hint")
	var layout: Node3D=world.get_node("TutorialGeometry/ChapterLayout")
	check(not layout.has_node("Range/ShootingChestWall") and not layout.has_node("Range/ChestWallCap") and layout.has_node("Range/ShootingLine"),"Shooting obstruction is replaced by a painted floor line")
	var line: MeshInstance3D=layout.get_node("Range/ShootingLine")
	check(line.mesh.size.y<.01 and not line.has_meta("solid_size") and not line.material_override.emission_enabled,"White line has no gameplay collision or emitted light")
	check(lesson.training_target.current_health==50.0,"Mannequin starts with 50 health")
	check(world.config!=world.CONFIG and world.config.basic_projectile_speed==world.FORMAL_WORLD.FIREARM_PROJECTILE_SPEED_3D and world.config.basic_projectile_speed==1500.0,"Tutorial owns a copy using formal-run projectile speed")
	check(world.CONFIG.basic_projectile_speed==550.0,"Shared baseline configuration is unchanged")
	var right_wall := true
	for index in 3:
		var fixture: Node3D=world.tutorial_ceiling_lights.get_child(index)
		var rect: Rect2i=world.FLOOR_SECTIONS[index]
		right_wall=right_wall and absf(fixture.position.z-(rect.position.y-.28))<.01 and absf(fixture.rotation.y)<.01
	check(right_wall,"All teaching-room fixtures remain mounted on their room wall")
	var corridor_mounted := true
	for index in range(3,world.tutorial_ceiling_lights.get_child_count()):
		var fixture: Node3D = world.tutorial_ceiling_lights.get_child(index)
		var mounting_point: Vector3 = world.to_local(fixture.to_global(Vector3(0,0,-.11)))
		corridor_mounted = corridor_mounted and absf(mounting_point.x-(world.ROOM_WIDTH-.5)) < .04
	check(corridor_mounted,"Corridor fixtures attach to the actual outside wall")
	var initial: Array=[world.training_zone_states.get(0),world.training_zone_states.get(1),world.training_zone_states.get(2)]
	check(initial==[true,false,false] and not lesson._gate("PreparationDoor").is_open,"Only first room is powered until its television is used")
	world.player.global_position=Vector2(4,13)*32.0;await frames()
	check(world.training_zone_states.get(0) and not lesson.lights_retired[0],"An unavailable future room cannot retire the current lesson's light")
	world.player.global_position=world.get_tutorial_terminal(0).global_position+Vector2(36,0);await frames()
	world.get_tutorial_terminal(0).request_interaction(world.player);await frames()
	check(world.dialogue_controller._sequence_lines.map(func(row):return row.text)==["这里简单做个入职测试","到隔壁房间去"],"First television uses the exact requested two lines")
	await finish_dialogue(world);await frames()
	check(lesson.stage==lesson.Stage.JUMP_CALL and world.training_zone_states.get(1) and not world.training_zone_states.get(2),"First conversation unlocks only the jump room")
	var first_call: Dictionary=lesson.get_call_state();lesson.call_elapsed=2.2
	check(first_call.text=="请到这边来" and lesson.get_call_state().visible,"Second television call repeats while waiting for E")
	world.player.global_position=Vector2(10,21)*32.0;await frames()
	check(lesson.sealed[0] and world.training_zone_states.get(0) and not lesson._gate("PreparationDoor").is_open and lesson._gate("PreparationDoor").status_light.visible,"First room stays lit in the corridor while its completed door closes")
	check(not world.monitor_feed.stations[0].screen_active and world.monitor_feed.stations[0].power_available,"First television switches its screen off on leaving without cutting room power")
	world.player.global_position=world.get_tutorial_terminal(1).global_position+Vector2(36,0);await frames()
	world.get_tutorial_terminal(1).request_interaction(world.player);await frames()
	check(not world.training_zone_states.get(0) and lesson.lights_retired[0] and not lesson._gate("PreparationDoor").status_light.visible,"Entering room two commits the first room's lighting handoff")
	check(world.dialogue_controller._sequence_lines.map(func(row):return row.text)==["这里测试一下跳跃能力","请在左边线向右边进行起跳"],"Second TV uses the exact jump briefing")
	await finish_dialogue(world);await frames()
	check(lesson.stage==lesson.Stage.JUMP_TEST and world.player.dash_enabled,"Jumping is enabled after its briefing")
	check(hint.visible and hint.label.text == "使用空格键进行翻滚", "Second room shows the roll cue after controls unlock")
	world.player.global_position=Vector2(10,13)*32.0;world.player.velocity=Vector2.ZERO;await frames()
	check(lesson.vacated[1] and not lesson.sealed[1] and world.training_zone_states.get(1) and not lesson._gate("EntryToDash").is_open,"Leaving an unfinished lesson keeps its light on and preserves the return gate")
	world.player.velocity=Vector2.LEFT;await frames()
	check(not lesson.vacated[1] and lesson._gate("EntryToDash").is_open and world.training_zone_states.get(1),"Walking back toward an unfinished lesson reopens it")
	world.player.global_position=Vector2(4,13)*32.0;world.player.velocity=Vector2.ZERO;await frames()
	lesson.dashed=true;lesson.stage=lesson.Stage.JUMP_DONE;lesson._run_dialogue(1,&"tutorial_jump_good",lesson.Stage.RANGE_CALL);await frames()
	check(world.dialogue_controller._sequence_lines[0].text=="好的","Successful jump is acknowledged by the television")
	await finish_dialogue(world);await frames()
	world.player.global_position=Vector2(10,13)*32.0;await frames()
	check(lesson.sealed[1] and world.training_zone_states.get(1) and not lesson._gate("EntryToDash").is_open,"Completed second room stays lit while the player is in the corridor")
	check(layout.get_node("Movement/DashStrip").material_override.emission_enabled and not world.monitor_feed.stations[1].screen_active,"Second-room floor glow stays on while its television screen switches off")
	check(lesson.get_call_state().text=="到这边来" and world.training_zone_states.get(2),"Third room calls the player after the jump lesson")
	world.player.global_position=Vector2(8.6,5)*32.0;await frames()
	check(world.training_zone_states.get(1),"Walking up to the next doorway still keeps the previous room illuminated")
	world.player.global_position=Vector2(8.4,5)*32.0;await frames()
	check(not world.training_zone_states.get(1) and lesson.lights_retired[1],"Crossing into room three turns the second room off")
	world.player.global_position=Vector2(8.7,5)*32.0;await frames()
	check(not world.training_zone_states.get(1),"Stepping back across the threshold cannot flicker the retired room back on")
	var all_off:=true
	for fixture in world.tutorial_ceiling_lights.get_children():
		if int(fixture.get_meta(&"training_zone",-1)) in [0,1]:
			for light in fixture.find_children("*","Light3D",true,false):all_off=all_off and not light.visible
	check(all_off and not world.monitor_feed.stations[0].screen_light.visible and not world.monitor_feed.stations[1].screen_light.visible,"Every departed room lamp and television light is disabled")
	world.player.global_position=world.get_tutorial_terminal(2).global_position+Vector2(36,0)
	world.get_tutorial_terminal(2).request_interaction(world.player);await frames()
	check(world.dialogue_controller._sequence_lines.map(func(row):return row.text)==["拿起武器柜里的枪","朝着假人射过去"],"Third TV directs the player to the actual weapon cabinet")
	await finish_dialogue(world);await frames()
	check(lesson.stage==lesson.Stage.RANGE_TEST and not world.player.dash_enabled,"Shooting begins after interaction without a forced reload lesson")
	check(hint.visible and hint.label.text == "接近物品后按 E 拿取", "Third room shows the pickup cue")
	check(world.get_node("TutorialGeometry/TrainingFacilityArt").has_node("WeaponCabinet") and not layout.get_node("Range/WeaponTray").visible,"The range has a weapon cabinet and retires the original floor tray")
	var pickup_bridge: Node3D=lesson.pickup.get_meta(&"depth_visual_bridge").get_ref()
	check(lesson.pickup.global_position.is_equal_approx(lesson.WEAPON_POSITION) and pickup_bridge.actor_center_height>1.0 and is_zero_approx(pickup_bridge.actor_center_depth_offset),"The real pickup is raised into the cabinet instead of duplicated on the floor")
	world.player.equip_weapon("basic", world.config)
	check(not world.player.begin_throw_aim(), "Loan weapon remains locked during the shooting exercise")
	lesson.picked=true;lesson.fired=1;lesson.training_target.take_damage(50.0);await frames()
	check(lesson.target_defeated and lesson.training_target.dead and world.dialogue_controller._sequence_lines.map(func(row):return row.text)==["好的","训练所用的武器归公司所属，请不要带走"],"Shooting completion explains the company's weapon ownership")
	await finish_dialogue(world);await frames()
	check(lesson.stage == lesson.Stage.RETURN_WEAPON and not lesson.can_exit() and not lesson._gate("Exit").is_open, "Exit waits for the weapon return")
	check(hint.visible and hint.label.text == "按右键丢掉武器", "Weapon return cue follows the ownership dialogue")
	check(world.player.begin_throw_aim(), "Right-click throw unlocks for the return step")
	world.player._commit_throw_aim()
	await frames()
	check(lesson.weapon_returned and world.player.selected_weapon_id.is_empty(), "Return commits the actual inventory extraction")
	check(world.dialogue_controller._sequence_lines[0].text == "谢谢配合，本次训练的子弹武器磨损费将从本月工资扣除", "Throwing the weapon starts the payroll dialogue")
	await create_timer(0.36, true, false, true).timeout
	check(not hint.visible and not lesson.can_exit(), "Return cue clears while the reply is playing")
	await finish_dialogue(world);await frames()
	check(lesson.can_exit() and lesson._gate("Exit").is_open,"Exit opens after the return acknowledgement")
	# Exercise the actual standalone reload while an asynchronous TV line is active.
	lesson.stage = lesson.Stage.COMPLETING
	lesson._run_dialogue(2, &"tutorial_weapon_returned", lesson.Stage.DONE)
	await frames()
	var old_world_id := world.get_instance_id()
	var reload_event := InputEventKey.new()
	reload_event.physical_keycode = KEY_F5
	reload_event.pressed = true
	display._unhandled_input(reload_event)
	await frames(16)
	display = current_scene
	world = display.world
	lesson = world.get_node("ChapterTraining")
	check(world.get_instance_id() != old_world_id and lesson.stage == lesson.Stage.INTRO and not lesson.dialogue_busy, "F5 resets the tutorial even during the weapon-return dialogue")
	check(world.control_hint.visible and world.control_hint.label.text == "使用键盘 WASD 控制移动\n使用鼠标移动镜头" and lesson._shown_control_hints.size() == 1, "Fresh tutorial shows the movement hint again without stale cues")
	check(not lesson.weapon_returned and world.player.selected_weapon_id.is_empty() and bool(world.player.get_meta(&"tutorial_loan_weapon", false)), "Reload restores the original unarmed loan-weapon lock")
	check(not lesson.lights_retired[0] and not lesson.lights_retired[1],"F5 clears the deferred lighting handoff state")
	var file:=FileAccess.open(out.path_join("validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name(),"checks":checks,"scope":"Headless lesson/room-power/dialogue and config contract; jump input, visual hand alignment and projectile velocity are separately checked in GPU replay."},"\t"));file.close()
	var failures: int=checks.filter(func(row):return not row.pass).size()
	current_scene=null;display.queue_free();await frames(8)
	print("TUTORIAL_REVISION checks=",checks.size()," failures=",failures);quit(1 if failures else 0)
