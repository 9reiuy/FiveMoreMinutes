extends SceneTree
## Navigation setup is explicit; keys, damage, reload and story commits stay live.
const WALK=preload("res://tests/support/world_walk_input.gd")
const OUT = "res://.runtime/visual_overhaul_20261029/art"
var main: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int = 5) -> void:
	for i in n: await process_frame
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
	print("PASS " if ok else "FAIL ", text)
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(16)
func key(code: int) -> void:
	var action: String = {KEY_SPACE:"dash", KEY_R:"reload_weapon",KEY_E:"pickup_weapon"}.get(code, "")
	if not action.is_empty(): Input.action_press(action)
	var event := InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=true
	root.push_input(event,true); await frames(2)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	if not action.is_empty(): Input.action_release(action)
	await frames()
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(OUT+"/"+name+".png")
func movie(name: String, seconds: float) -> void:
	for i in int(seconds*10):
		await snap(name+"_%03d"%i); await create_timer(.1,true,false,true).timeout
func run() -> void:
	load("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	create_timer(240,true,false,true).timeout.connect(func(): quit(2))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.show_room(false); await settle()
	var room: Node=main._supported_dream_world; room.mode="EVENING"
	await snap("bedroom")
	check(not room.panel.status.visible,"no corner HUD restored")
	check(room.get_node("Furniture/Rug").position==room.get_node("Furniture/Bed").position,"bed retains rug and approved placement")
	check(room.has_node("Vestibule/Base") and room.has_node("Window/Slat4"),"authored entry support and window slats editable")
	room.player.position=Vector2(-2.3,.6)*32.; await frames(); await key(KEY_E)
	check(room.computer_overlay.visible,"real E opens laptop")
	room.computer_overlay._open_app("archive"); await frames()
	var archive: Control=room.computer_overlay.archive_app
	archive.tabs.current_tab=1; await frames(); await snap("notebook_empty")
	check(archive.notebook.get_child_count()==1,"unobserved profile reveals no symbols")
	main.chapter_one.state.clues=["ch1_S"]; archive._refresh_notes(); await frames()
	check(main.chapter_one.state.observations[0].translation=="","legacy observation doesn't auto-translate")
	var edit: LineEdit=archive.notebook.get_child(1); edit.grab_focus()
	var letter:=InputEventKey.new(); letter.keycode=KEY_X; letter.physical_keycode=KEY_X; letter.unicode=120; letter.pressed=true; root.push_input(letter,true); await frames()
	check(main.chapter_one.state.observations[0].translation=="x","real text input updates player transcription")
	check(main._save_progress(),"transcription profile can be saved")
	var disk: Dictionary=main._load_current_version_progress()
	check(disk.chapter_one.observations[0].translation=="x","transcription survives actual disk serialization")
	await snap("notebook_observed")
	archive.tabs.current_tab=2; await frames(); await snap("morse_table")
	archive.tabs.current_tab=0; archive.input.text="S"; check(not archive.verify(),"first fragment never unlocks full archive")
	await snap("archive")
	await key(KEY_ESCAPE); await frames()
	main.chapter_one.state.flow_revision=1; main.chapter_one.state.stage="WAKE"; main.chapter_one.show_room(true); await settle(); room=main._supported_dream_world; room.mode="EVENING"
	room.player.position=room.destination; await frames(); await snap("sleeping_self")
	var day: int=main.persistent_day_state.calendar_day_id
	await key(KEY_F); await key(KEY_F)
	check(room.finishing and main.persistent_day_state.calendar_day_id==day,"wake animation locks repeat F before commit")
	await movie("wake",1.3); await settle()
	check(main.chapter_one.state.complete and main.persistent_day_state.calendar_day_id==day+1,"single F animation commits exactly one day")
	await create_timer(.8).timeout
	for child in main.get_children():
		if child.get_script()==load("res://scripts/story/chapter_panel.gd") and child.center.visible: child.choices.get_child(0).pressed.emit()
	main.chapter_one.start_new(); main.chapter_one.state.stage="TUTORIAL"; main.chapter_one.resume(); await settle()
	var world: Node=main._supported_dream_world
	var training: Node=world.get_node("ChapterTraining")
	world.player.set_meta("presentation_pointer_gate",func(): return true)
	check(is_instance_valid(training.training_target) and is_instance_valid(training.pickup) and not training.picked,"target and weapon preplaced before dialogue")
	for prop in world.get_node("TutorialGeometry/ChapterLayout/Range").get_children():
		if str(prop.name).begins_with("AmmoCrate"): check(prop.get_meta("approved_kind","")=="cabinet","ammo prop has cabinet geometry")
	check(absf(world.guide.position.x-world.PLAYER_SPAWN.x)>40.,"guide stands clear of central passage")
	check(world.floor_cells.size()==239,"three-room floor has 239 walkable cells")
	check(not training._gate("EntryToDash").is_open and not training._gate("DashToRange").is_open,"both lesson gates initially locked")
	WALK.hold(world.player,Vector2.UP); await key(KEY_SPACE); Input.action_release("move_up"); await create_timer(.7).timeout
	check(not training.dashed,"early dash cannot satisfy later exercise")
	world.player.position=Vector2(128,21*32.); await frames()
	check(training.stage==1,"registration arrival starts conversation objective")
	world._spawn_guide_once(); await create_timer(.8).timeout
	world.player.position=world.guide.position+Vector2(-35,20); await frames(); await snap("tutorial_guide")
	check(world.interaction_prompt.visible and world.interaction_prompt.position.y<300,"single contextual talk prompt visible")
	await key(KEY_E)
	for i in 60:
		if training.stage>=2: break
		await key(KEY_E); await create_timer(.1).timeout
	check(training.stage==2 and training._gate("EntryToDash").is_open,"actual registration unlocks first gate")
	world.player.position=Vector2(128,12.0*32.); await frames()
	check(training.stage==2 and not training.dashed,"walking across stripe does not pass dash exercise")
	world.player.position=Vector2(128,14.4*32.); await frames()
	WALK.hold(world.player,Vector2.UP); await key(KEY_SPACE); await movie("dash",.7); WALK.release(); await frames(20)
	check(training.dashed and training.stage==3 and training._gate("DashToRange").is_open,"actual dash crossing opens live range")
	world.player.position=training.pickup.position+Vector2(0,20); await frames(); await key(KEY_E)
	check(training.picked and world.player.get_ammo_status().current==2,"loan pistol starts with two rounds")
	check(not world.player.begin_throw_aim(),"range loan cannot disappear through unhandled throw")
	world.player.set_meta("presentation_pointer_position",func(): return world.camera_3d.unproject_position(Vector3(4.,.65,2.6)))
	world.player.position=Vector2(128,7.5*32.); await frames()
	if not InputMap.has_action("attack"): InputMap.add_action("attack")
	Input.action_press("attack"); await movie("range",.65); Input.action_release("attack"); await frames()
	check(training.fired>=2 and world.player.get_ammo_status().current==0,"real projectiles empty tutorial magazine")
	check(not world.player.get_ammo_status().reloading and not training.reload_done,"automatic reload cannot pass R lesson")
	await key(KEY_R); await create_timer(2.).timeout
	check(training.reload_done and world.player.get_ammo_status().current==12,"manual R completes actual reload")
	check(not world.player.has_meta("tutorial_manual_reload"),"normal automatic reload restored after learning R")
	paused=true; await frames(); check(not training.hint.visible,"hint hides during pause"); paused=false
	await snap("tutorial_range")
	print("CHAPTER1_ART_REVISION checks=",checks," failures=",failures)
	main.queue_free(); await frames(); quit(failures)
