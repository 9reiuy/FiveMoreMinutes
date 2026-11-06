extends SceneTree
const OUT := "res://.runtime/test_lab_20261102/"
var checks:=0
var failures:Array[String]=[]
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print("LAB_CHECK ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
func run()->void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("Lab test timeout");quit(2))
	var native:=DisplayServer.get_name()!="headless"
	if native:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		DisplayServer.window_set_position(Vector2i(-30000,-30000))
	AudioServer.set_bus_mute(0,true)
	var scene=load("res://scenes/testing/GameTestLab.tscn")
	check(scene!=null,"Lab scene loads")
	if scene==null: quit(1); return
	var lab=scene.instantiate()
	lab.output_root=OUT+"exports"
	root.add_child(lab)
	while lab.busy or not lab.ready_world:
		await process_frame
		if not lab.busy and not lab.ready_world:
			check(false,"Lab initial generation");quit(1);return
	check(lab.world.rooms.size()==4,"Whitebox has four connected stations")
	check(lab.world.floor_cells.size()==672,"Whitebox exact floor coverage")
	check(not lab.world.persist_profile,"Profile persistence disabled")
	check(lab.world.furniture_root.get_child_count()>0,"Real furniture spawned")
	check(lab.world.enemy_root.get_child_count()==8,"Bounded eight-enemy population")
	check(lab.world.rendered_edge_failures==0,"Formal wall/door/glass edge contracts")
	check(lab.world.get_node_or_null("StandalonePauseMenu")==null,"No campaign pause menu")
	check(lab.world.player.selected_weapon_id=="assault_rifle","Real player equipped")
	check(lab.world.player.get_script().resource_path=="res://scripts/testing/lab_player.gd","Immunity isolated in lab player")
	var hp:float=lab.world.player.current_health
	lab.world.player.receive_damage(10.0)
	check(lab.world.player.current_health==hp and lab.world.player.invulnerability_left<1.0,"No damage or perpetual flashing in lab immunity")
	for enemy in lab.world.enemy_root.get_children(): check(enemy.process_mode==Node.PROCESS_MODE_DISABLED,"AI off also disables weapon children")
	for i in 5:
		lab.weapon.select(i);lab.equip()
		check(lab.world.player.selected_weapon_id==lab.WEAPONS[i],"Weapon slot %d correct"%i)
	lab.weapon.select(2);lab.equip()
	for i in 4:
		lab.teleport(i)
		check(lab.world.floor_cells.has(lab.world._cell_for_gameplay_position(lab.world.player.global_position)),"Station %d is walkable floor"%i)
	lab.teleport(1)
	lab.panel.hide()
	await process_frame
	var position_before:Vector2=lab.world.player.global_position
	Input.action_press("move_right")
	for i in 10: await physics_frame
	Input.action_release("move_right")
	check(lab.world.player.global_position.distance_to(position_before)>3.0,"WASD authority works with panel closed")
	lab.panel.show(); await process_frame
	position_before=lab.world.player.global_position
	Input.action_press("move_right")
	for i in 5: await physics_frame
	Input.action_release("move_right")
	check(lab.world.player.global_position.distance_to(position_before)<1.0,"Panel prevents accidental movement")
	lab.panel.hide()
	var motion:=InputEventMouseMotion.new();motion.position=root.get_visible_rect().size*.5+Vector2(100,0)
	Input.parse_input_event(motion)
	var click:=InputEventMouseButton.new();click.position=motion.position;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	Input.parse_input_event(click)
	var shots_before:int=lab.shot_count
	for i in 20: await physics_frame
	check(lab.shot_count>shots_before,"Mouse left click fires through real display mapping")
	lab.panel.show();shots_before=lab.shot_count
	for i in 10: await physics_frame
	check(lab.shot_count==shots_before,"Panel blocks click-through shooting")
	click.pressed=false;Input.parse_input_event(click)
	await lab.rebuild()
	lab.teleport(1)
	var layout_before:Dictionary=lab.world.floor_cells.duplicate()
	if native:
		for i in 120: await process_frame
		lab.panel.show()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"whitebox_panel.png")
		await lab.capture()
	lab.trigger("smoke")
	var smoke=lab.world.floor_root.get_node_or_null("FireExtinguisherSystem")
	check(smoke!=null and smoke.sources.size()>0,"Real smoke source emitted")
	lab.trigger("blood"); lab.trigger("break"); lab.trigger("extinguisher"); lab.trigger("fire")
	for i in 10: await process_frame
	check(lab.event_history.has("break") and lab.event_history.has("blood"),"Actions recorded")
	var old_world_id:int=lab.world.get_instance_id()
	await lab.rebuild()
	check(not is_instance_id_valid(old_world_id),"Old world freed on reset")
	check(lab.world.floor_cells==layout_before,"Same seed/layout after reset")
	check(lab.world.floor_root.get_node("FireExtinguisherSystem").sources.is_empty(),"No smoke source carried across reset")
	lab.checks.furniture.button_pressed=false; lab.enemies.value=0
	await lab.rebuild()
	check(lab.world.furniture_root.get_child_count()==0,"Furniture ablation does not generate props")
	check(lab.world.enemy_root.get_child_count()==0,"Zero enemies really omitted")
	lab.mode.select(1); lab.checks.furniture.button_pressed=true
	await lab.rebuild()
	check(not lab.world.lab_whitebox,"Formal art on identical four-room layout")
	if native:
		for i in 90: await process_frame
		await lab.capture()
	lab.duration.value=5; lab.scenario.select(3)
	await lab.toggle_recording()
	while lab.recorder.active: await process_frame
	check(FileAccess.file_exists(lab.last_export.path_join("frames.csv")),"Frame CSV exported")
	var report=JSON.parse_string(FileAccess.get_file_as_string(lab.last_export.path_join("report.json")))
	check(report!=null and report.all_sampled.frames>5,"Bounded summary has frames")
	check(lab.event_history.has("sample_stopped"),"Sample stop event")
	check(not Input.is_action_pressed("attack"),"Auto fire released")
	check(lab.shot_count>0,"Automatic workload actually fires the real weapon")
	lab.panel.hide()
	check(lab.world.player.movement_enabled,"Movement restored")
	lab.mode.select(2)
	await lab.rebuild()
	check(lab.world.rooms.size()>4,"Native randomized floor mode")
	check(lab.world.enemy_root.get_child_count()==0,"Native mode honors exclusion")
	check(not lab.world._current_floor_path_adjacency().is_empty(),"Lab uses production path adjacency cache")
	if native:
		for i in 90: await process_frame
		await lab.capture()
	lab.free(); await process_frame; await process_frame
	check(root.find_children("LabWorld","",true,false).is_empty(),"Lab lifecycle clean")
	var file=FileAccess.open(OUT+("gpu.json" if native else "logic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_camera":native},"\t"));file.close()
	print("LAB_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
