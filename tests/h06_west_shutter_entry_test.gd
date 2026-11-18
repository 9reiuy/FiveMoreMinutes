extends "res://tests/h06_hangar_crew_entry_test.gd"
const OUT:="res://.runtime/h06_shutter_cycle_20261117"
var timings:Array[Dictionary]=[]
var cycles:Array[Dictionary]=[]

func sample(label:String,count:int)->void:
	var previous:=Time.get_ticks_usec()
	for frame in count:
		await process_frame
		var now:=Time.get_ticks_usec()
		timings.append({"stage":label,"frame":frame,"wall_ms":(now-previous)/1000.0})
		var encounter=world.west_shutter_encounter
		cycles.append({"stage":label,"frame":frame,"phase":encounter.phase,"cycle":encounter.door_cycle,"open":world.blockout.is_west_shutter_open("inspection")})
		previous=now

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):quit(2);return
	create_timer(180,true,false,true).timeout.connect(func():quit(3))
	var stamp:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf((now-stamp[0])/1000000.0,0.0,.05))
		stamp[0]=now)
	root.size=Vector2i(1280,720)
	evidence=ProjectSettings.globalize_path(OUT)
	await enter(CHAPTER.Save.CALIBRATED)
	world.player.maximum_health=100000.0
	world.player.current_health=100000.0
	var encounter:RefCounted=world.west_shutter_encounter
	check(world.chapter_stream_ready and display.entry_loading==null,"normal entry completes covered scene preparation before releasing control")
	check(encounter.phase==encounter.Phase.WAITING and encounter.first.size()==5 and encounter.second.size()==5,"normal launcher prepares both cohorts without activating them inside the calibration bay")
	var ids:Array=encounter.first.map(func(u:EmployeeEnemy):return u.get_instance_id())
	await sample("prepared_idle",120)
	world.player.set_scripted_locomotion(Vector2.LEFT,world.player.movement_speed)
	await sample("prepared_entry_and_release",240)
	world.player.clear_scripted_locomotion()
	await sample("prepared_first_active",120)
	check(world._feet().x<-12.5 and world.warehouse_triggered.has("inspection") and world.warehouse_triggered.has("archive"),"normal launcher triggers the paired shutters after actual player movement into 1-2")
	check(encounter.first.all(func(u:EmployeeEnemy):return u.room_runtime_active) and encounter.first.map(func(u:EmployeeEnemy):return u.get_instance_id())==ids,"normal first release activates the original prepared actors")
	check(encounter.second.all(func(u:EmployeeEnemy):return not u.room_runtime_active),"normal first release leaves the second cohort waiting")
	check(root.get_node("SettingsManager").is_music_suppressed() and display.world_viewport.size==Vector2i(1280,720),"normal whitebox entry keeps background music suppressed and native rendering enabled")
	world._place_feet(Vector2(-41.0,-24.0))
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for squad:Array in world.warehouse_squads.values():
		for unit:EmployeeEnemy in squad:unit.set_physics_process(false)
	await frames(40)
	await photograph("05-normal-gameplay-camera-curtains")
	var failures:Array=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(OUT+"/entry_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings,"door_trace":cycles,"pid":OS.get_process_id(),"scope":"normal H06 launcher with its actual covered loading and scene preparation, then actual warehouse entry; bounded wall-clock sample, not whole-game FPS certification"},"\t"))
	current_scene.queue_free()
	await frames(8)
	print("WEST_ENTRY checks=",checks.size()," failures=",failures.size()," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
