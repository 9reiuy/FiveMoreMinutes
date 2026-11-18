extends "res://tests/h06_hangar_crew_test.gd"
## Normal chapter launcher regression after the isolated crew gate has passed.

func enter(save: int, _crew := true) -> void:
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":save,"staff_story":test_staff_story.duplicate(true)})
	check(change_scene_to_file("res://scenes/testing/H06ChapterWhiteboxLab.tscn")==OK,"normal chapter launcher opens")
	await scene_changed
	await frames(12)
	display = current_scene.presentation
	world = display.world
	for i in 360:
		if world._session_initialized and world.player != null: break
		await frames(1)
	if world.get_meta(&"h06_render_warmup",true):
		for i in 2400:
			if world.chapter_stream_ready and display.entry_loading==null:break
			await frames(1)
		check(world.chapter_stream_ready and display.entry_loading==null,"normal entry finishes covered native scene preparation before gameplay")
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(1)
		return
	check(world.hangar_crew_enabled,"normal entry enables the crew without test overrides")
	check(world.hangar_crew_activity_enabled,"normal entry enables the work and scattered-aftermath revision")
	world._spotlight_triggered = true
	if world.blockout.visit in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]: world.blockout.play_spotlight_reveal(true)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1
	await frames(40)

func run() -> void:
	create_timer(120,true,false,true).timeout.connect(func(): quit(3))
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	preload("res://tests/support/background_gpu.gd").start(self)
	await enter(CHAPTER.Save.ENTRANCE)
	var crew: Node3D = world.blockout.hangar_crew
	check(is_instance_valid(crew) and crew.actors.size()==3 and not crew.aftermath,"normal first visit shows three living workers")
	if not is_instance_valid(crew): quit(1); return
	for actor: EmployeeEnemy in crew.actors: check_registration(actor)
	var initial: Vector2=crew.actors[2].position
	await frames(90)
	check(crew.actors.all(func(actor:EmployeeEnemy)->bool:return actor.work_activity!=null) and crew.actors[2].position.distance_to(initial)>8.0,"ordinary launcher advances the three working routines")
	world._place_feet(Vector2(5.3,0.7))
	await frames(40)
	await photograph("01-formal-entry-living")
	var old_crew: WeakRef = weakref(crew)
	await enter(CHAPTER.Save.PUMP)
	check(old_crew.get_ref()==null and world.blockout.hangar_crew==null,"normal scene reload releases workers and keeps 1-2 free of duplicates")
	world.stage = CHAPTER.Stage.RETURN
	world._set_lower(true)
	world.blockout.set_gate("pump",false)
	var gate: Dictionary = PLAN.PASSAGES[PLAN.Visit.WEST]
	world.previous_feet = gate.at-gate.forward
	var crossed: Vector2 = gate.at+gate.forward*(PLAN.ENTRY_DEPTH+0.4)
	world._place_feet(crossed)
	world._update_passage(crossed)
	await frames(65)
	crew = world.blockout.hangar_crew
	check(world.blockout.visit==PLAN.Visit.EMPTY_HANGAR and is_instance_valid(crew),"the actual 1-2 exit passage activates the return hangar")
	if is_instance_valid(crew):
		check(crew.aftermath and crew.blood_created and crew.actors.all(func(actor: EmployeeEnemy) -> bool: return actor.dead),"actual exit replaces the three workers with corpses and drag blood")
		check(crew.actors.all(func(actor: EmployeeEnemy) -> bool: return not actor.is_in_group(&"dream_enemies") and not actor.is_damage_runtime_active()),"return scenery stays outside combat and clear-enemy gates")
	world._place_feet(Vector2(3.4,1.5))
	await frames(40)
	await photograph("02-formal-return-aftermath")
	await enter(CHAPTER.Save.RETURN_BAY)
	crew = world.blockout.hangar_crew
	check(is_instance_valid(crew) and crew.aftermath and crew.blood_created,"normal retry restores the corpse scenery")
	await enter(CHAPTER.Save.ENTRANCE)
	crew = world.blockout.hangar_crew
	check(is_instance_valid(crew) and not crew.aftermath and not crew.blood_created,"normal restart restores living workers without old blood")
	current_scene.queue_free()
	await frames(8)
	var failures: Array = checks.filter(func(row: Dictionary) -> bool: return not row.pass)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0),"scope":"Normal chapter launcher, actual passage activation, reload, return checkpoint and new chapter reset; no export."},"\t"))
	print("H06_HANGAR_CREW_ENTRY checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
