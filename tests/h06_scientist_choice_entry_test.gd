extends "res://tests/h06_hangar_crew_entry_test.gd"
const OUT:="res://.runtime/h06_scientist_choice_20261117"
var timings:Array[Dictionary]=[]
var retirement_frames:Array[int]=[]

func _initialize()->void:call_deferred("run")

func sample(label:String,count:int,started:=0)->void:
	var stamp:int=Time.get_ticks_usec() if started==0 else started
	for frame in count:
		await process_frame
		var now:=Time.get_ticks_usec()
		timings.append({"stage":label,"frame":frame,"wall_ms":(now-stamp)/1000.0})
		stamp=now

func transfer(visit:int)->void:
	var gate:Dictionary=PLAN.PASSAGES[world.blockout.visit]
	if visit==PLAN.Visit.EMPTY_HANGAR:
		world.stage=CHAPTER.Stage.RETURN
		world.checkpoint=CHAPTER.Save.PUMP
		world._set_lower(true)
		world.blockout.set_gate("pump",false)
	world._place_feet(gate.at+gate.forward)
	if world.prepared==null or world.prepared.visit!=visit:world.prepared=world._plan_region(visit)
	world._enter_prepared()

func screenshot(label:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func run_case(kill:bool)->void:
	test_staff_story={}
	await enter(CHAPTER.Save.OBSERVATION)
	var event=world.blockout.monitoring_scientist
	check(is_instance_valid(event.actor) and event.actor.story_active and not world.staff_story.scientist_killed,"normal entry starts with a living, damageable scientist")
	check(world.chapter_staged_regions.has(PLAN.Visit.EMPTY_HANGAR),"normal covered loading prepares the return hangar before the choice")
	var cached=world.chapter_staged_regions[PLAN.Visit.EMPTY_HANGAR]
	var actor_ids:Array=cached.hangar_crew.actors.map(func(actor:EmployeeEnemy):return actor.get_instance_id())
	check(not cached.hangar_crew.aftermath and not cached.hangar_crew.blood_scenery.visible,"loading does not expose cached blood in the surviving branch")
	await sample("normal_seated_speech_"+("kill" if kill else "spare"),120)
	check(event.current_line>=0 and (event.bubble.visible or world.staff_story.introduction_seen),"the scientist's speech runs after normal covered loading releases gameplay")
	if kill:world.resolve_player_hit(event.actor,100000.0,world.player.global_position)
	check(world.staff_story.scientist_killed==kill,"the current run records the actual choice after the return room was prepared")
	if not kill:
		world._place_feet(Vector2(10.18,6.08))
		await frames(38)
		await screenshot("normal-gallery-right-fade")
	var layer:WeakRef=weakref(event)
	var old_actor:WeakRef=weakref(event.actor)
	transfer(PLAN.Visit.WEST)
	await sample("normal_gallery_to_west_"+("kill" if kill else "spare"),45)
	check(world.blockout.visit==PLAN.Visit.WEST and world.staff_story.scientist_killed==kill,"the choice survives the ordinary 1-1 to 1-2 room handoff")
	var retiring:Node=old_actor.get_ref()
	check(retiring==null or (not retiring.story_active and retiring.collision_layer==0),"the retired scientist cannot leave an active invisible collider while cleanup is queued")
	if not kill:
		world._set_lower(true)
		world._place_feet(Vector2(-11.45,8.0))
		await frames(38)
		var env:Environment=world.get_node("Lighting/WorldEnvironment").environment
		check(env.background_color==Color.BLACK,"the west exit uses the black clear colour through its open transition")
		await screenshot("normal-west-exit")
	var began:=Time.get_ticks_usec()
	transfer(PLAN.Visit.EMPTY_HANGAR)
	await sample("normal_prepared_return_"+("kill" if kill else "spare"),120,began)
	var crew:Node3D=world.blockout.hangar_crew
	check(crew.actors.map(func(actor:EmployeeEnemy):return actor.get_instance_id())==actor_ids,"return entry reuses all three original prepared actors")
	check(crew.aftermath==kill and crew.actors.all(func(actor:EmployeeEnemy):return actor.dead==kill),"actual prepared-room entry selects the current fate instead of the cached initial fate")
	check(crew.blood_scenery.visible==kill and crew.blood_created==kill,"actual return shows corpse blood only in the killed-scientist branch")
	if not kill:
		await sample("normal_survivors_running",180)
		check(crew.escape.started and world.blockout.secret_roof.visible and not world.blockout.secret_visible,
			"the real return keeps the room covered during the escape")
		world._place_feet(Vector2(-6.05,7.85))
		await frames(38)
		await screenshot("normal-hangar-west-fade")
		for i in 510:
			if crew.escape.finished:break
			await physics_frame
		world._place_feet(Vector2(6.0,1.5))
		await frames(38)
		check(crew.escape.finished and world.blockout.secret_roof.visible and not world.blockout.secret_visible,"the room stays covered beside the hatch after all three enter")
		await screenshot("normal-hidden-covered")
		world._place_feet(Vector2(17.0,2.22))
		await frames(38)
		check(world.blockout.secret_visible and not world.blockout.secret_roof.visible and crew.bridges.all(func(bridge:Node3D)->bool:return bridge.is_visible_in_tree()),"entering the room uncovers the surviving crew")
		await screenshot("normal-hidden-interior")
	var drained:=0
	while (not world.unload_queue.is_empty() or layer.get_ref()!=null) and drained<1200:
		await process_frame
		drained+=1
	retirement_frames.append(drained)
	check(world.unload_queue.is_empty() and layer.get_ref()==null,"budgeted room retirement releases the monitoring scientist and speech owner")
	check(root.get_node("SettingsManager").is_music_suppressed(),"normal whitebox entry keeps background music suppressed")
	await screenshot("normal-return-"+("killed" if kill else "spared"))
	current_scene.queue_free()
	await frames(8)

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):quit(2);return
	create_timer(180,true,false,true).timeout.connect(func():quit(3))
	var stamp:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf((now-stamp[0])/1000000.0,0.0,.05))
		stamp[0]=now)
	root.size=Vector2i(1280,720)
	evidence=OS.get_environment("H06_BOUNDARY_EVIDENCE")
	if evidence.is_empty():evidence=ProjectSettings.globalize_path(OUT)
	await run_case(true)
	await run_case(false)
	var failures:Array=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(evidence.path_join("entry_result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pid":OS.get_process_id(),"timings":timings,"retirement_frames":retirement_frames,"scope":"normal authored chapter loading prepares rooms before the choice, then actual existing room-handoff methods claim the prepared 1-2 and returned hangar; warehouse combat completion is a controlled fixture; both fate branches, identity reuse, blood and cover visibility, retirement and bounded native frame timings"},"\t"))
	print("SCIENTIST_ENTRY checks=",checks.size()," failures=",failures.size()," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
