extends SceneTree
const WORLD := "res://scenes/testing/H06ChapterWhitebox.tscn"
const PREVIEW := "res://scenes/dream/preview/SelectivePixelPreview.tscn"
const CHAPTER := preload("res://scripts/testing/h06_chapter/chapter_world.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
var world: Node3D
var display: Control
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var evidence := ""
var test_activities := true
var force_dynamic_crew_blood := false
## Existing corpse/blood regressions explicitly exercise the killed-scientist branch.
var test_staff_story:Dictionary={"scientist_killed":true}

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"pass":ok})
	print("PASS " if ok else "FAIL ",label)

func enter(save: int, crew := true) -> void:
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":save,"staff_story":test_staff_story.duplicate(true)})
	world = load(WORLD).instantiate()
	world.generate_on_ready = false
	world.hangar_crew_enabled = crew
	world.hangar_crew_activity_enabled = test_activities
	world.set_meta(&"test_dynamic_hangar_crew_blood",force_dynamic_crew_blood)
	display = load(PREVIEW).instantiate()
	display.preview_mode = false
	display.world = world
	root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(1)
		return
	check(world.regenerate(11011),"authored chapter generates")
	world._setup_chapter_session()
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1
	world._spotlight_triggered = true
	if world.blockout.visit in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]: world.blockout.play_spotlight_reveal(true)
	await frames(12)

func photograph(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	display.world_viewport.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func record_work(crew: Node3D) -> void:
	# Actual camera frames, deliberately outside performance samples.
	var folder := evidence.path_join("work-motion")
	DirAccess.make_dir_recursive_absolute(folder)
	for actor in crew.actors:
		actor.work_activity.age=0
		actor.work_activity.present()
	crew.set_process(true)
	var timing: Array[Dictionary]=[]
	for i in 90:
		await frames(4)
		await RenderingServer.frame_post_draw
		display.world_viewport.get_texture().get_image().save_png(folder.path_join("%03d.png"%i))
		timing.append({"frame":i,"elapsed":crew.elapsed,"positions":crew.actors.map(func(actor:EmployeeEnemy)->String:return str(actor.position)),"tasks":crew.actors.map(func(actor:EmployeeEnemy)->String:return str(actor.work_activity.current_task))})
	FileAccess.open(folder.path_join("timing.json"),FileAccess.WRITE).store_string(JSON.stringify(timing,"\t"))

func measure(label: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var processing: bool = world.is_processing()
	world.set_process(false)
	var pose: Transform3D = world.camera_rig.transform
	var raw: Array[float] = []
	for i in 24: await process_frame
	var previous := Time.get_ticks_usec()
	for i in 240:
		world.camera_rig.transform = pose
		world.camera_rig.position += Vector3(sin(i*TAU/240)*0.65,0,cos(i*TAU/240)*0.45)
		await process_frame
		var now := Time.get_ticks_usec()
		raw.append((now-previous)*0.001)
		previous = now
	world.camera_rig.transform = pose
	world.set_process(processing)
	var sorted := raw.duplicate(); sorted.sort()
	samples.append({"label":label,"frames_ms":raw,"p50_ms":sorted[119],"p95_ms":sorted[227],"p99_ms":sorted[237],"max_ms":sorted[-1],"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"muted":AudioServer.is_bus_mute(0)})

func check_registration(actor: EmployeeEnemy) -> void:
	if actor.work_activity != null: actor.work_activity.reset_pose()
	var original: Vector2 = actor.last_facing_direction
	var pixels := Image.new()
	pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(actor.portrait_atlas.resource_path))
	for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2(-1,-1),Vector2(1,-1)]:
		actor.face(direction)
		var cell := Rect2i(actor.head.texture.region)
		var hem_row := pixels.get_region(Rect2i(cell.position+Vector2i(0,28),Vector2i(32,1)))
		var hem_mid_x := Rect2(hem_row.get_used_rect()).get_center().x
		var hem := actor.head.to_global(actor.head.get_rect().position+Vector2(hem_mid_x,28))
		var left := actor.left_leg.to_global(actor.left_leg.get_rect().get_center())
		var right := actor.right_leg.to_global(actor.right_leg.get_rect().get_center())
		check(absf(hem.x-(left.x+right.x)*0.5)<0.01,str(actor.name)+" coat stays centered over both feet "+str(direction))
		var coat_bottom := actor.head.to_global(actor.head.get_rect().position+Vector2(hem_mid_x,31)).y
		check(actor.left_leg.to_global(actor.left_leg.get_rect().position).y<coat_bottom and actor.left_leg.to_global(actor.left_leg.get_rect().end).y>coat_bottom,str(actor.name)+" legs overlap the coat with exposed boots "+str(direction))
		if actor.engineer:
			check(actor.safety_helmet.sprite.position==actor.SAFETY_HELMET.HEAD_OFFSET+actor.head.offset,"independent helmet follows the registered rear head")
	actor.face(original)

func check_activities(crew: Node3D) -> void:
	crew.set_process(false)
	var origins: Array[Vector2] = []
	var travel := [0.0,0.0,0.0]
	var tasks := [{},{},{}]
	var visible_closed := [false,false,false]
	var first_blinks := [-1.0,-1.0,-1.0]
	var floors_valid := true
	var pad := Rect2(-6.17,-0.87,6.34,4.94)
	for actor in crew.actors: origins.append(actor.position)
	for step in 750:
		crew.advance_activity(0.04)
		for i in 3:
			var actor: EmployeeEnemy = crew.actors[i]
			travel[i] = maxf(travel[i],actor.position.distance_to(origins[i])/32)
			tasks[i][actor.work_activity.current_task] = true
			if actor.enemy_head_frame_index>0 and first_blinks[i]<0: first_blinks[i]=step*0.04
			if not actor.facing_back and actor.enemy_head_frame_index==2: visible_closed[i]=true
			var p: Vector2 = actor.position/32
			floors_valid = floors_valid and PLAN.ATRIUM.H06_BAY_RECT.grow(0.1).has_point(p) and not pad.has_point(p)
	for i in 3:
		check(travel[i]>0.6,str(crew.actors[i].name)+" takes short working walks instead of staying planted")
		check(tasks[i].size()>=3,str(crew.actors[i].name)+" alternates walking, working and observing")
		check(visible_closed[i],str(crew.actors[i].name)+" visibly closes the front-facing eyes during its routine")
	check(first_blinks[0]!=first_blinks[1] and first_blinks[1]!=first_blinks[2],"blink timings are staggered")
	check(floors_valid,"all work routes stay on the bay deck and clear the raised mech pad")
	check(tasks[0].has(&"point") and tasks[1].has(&"record") and tasks[2].has(&"repair"),"three roles have distinct work routines")
	for actor in crew.actors:
		actor.work_activity.age=0
		actor.work_activity.present()
	crew.elapsed=0
	crew.set_process(true)

func unload() -> void:
	display.queue_free()
	await frames(8)

func run() -> void:
	create_timer(240,true,false,true).timeout.connect(func(): quit(3))
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	if DisplayServer.get_name() != "headless": preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await enter(CHAPTER.Save.ENTRANCE,false)
	world._place_feet(Vector2(5.3,0.7))
	await frames(60)
	await measure("gallery-without-crew")
	await unload()
	await enter(CHAPTER.Save.ENTRANCE)
	world._place_feet(Vector2(5.3,0.7))
	await frames(60)
	var crew: Node3D = world.blockout.hangar_crew
	check(is_instance_valid(crew) and crew.actors.size() == 3,"first hangar contains two scientists and one engineer")
	if not is_instance_valid(crew): quit(1); return
	check(not crew.aftermath and not crew.blood_created,"first visit keeps everyone alive without aftermath blood")
	check(world.enemy_root.get_child_count() == 0,"crew do not count as room enemies")
	for actor: EmployeeEnemy in crew.actors:
		check_registration(actor)
		var health: float = actor.current_health
		actor.take_damage(10000,Vector2.ZERO,1000,&"player_projectile")
		actor.set_room_runtime_active(true)
		check(not actor.dead and actor.current_health == health and not actor.is_damage_runtime_active(),str(actor.name)+" cannot be damaged")
		check(not actor.hostile and actor.target == null and actor.process_mode == Node.PROCESS_MODE_DISABLED,"crew have no active hostile or attack simulation")
		check(actor.collision_layer == 0 and actor.collision_mask == 0 and not actor.is_in_group(&"dream_enemies"),"crew have no combat collision or enemy-group membership")
		check(actor.get_signal_connection_list(&"defeated").is_empty(),"crew do not award kills or loot")
	check(crew.actors[2].helmet_equipped,"engineer retains the authored safety helmet")
	for bridge: Node3D in crew.bridges: check(bridge.character_projection and bridge._cached_is_enemy,"decorative pose uses the normal lit character renderer")
	check_activities(crew)
	await frames(5)
	var paused_at: float=crew.elapsed
	paused=true
	await frames(5)
	check(is_equal_approx(crew.elapsed,paused_at),"work animation respects the normal game pause")
	paused=false
	await frames(3)
	check(crew.elapsed>paused_at,"work animation resumes with the game")
	await photograph("01-living-crew-normal-camera")
	crew.set_process(false)
	await measure("gallery-static-crew-A")
	crew.set_process(true)
	await measure("gallery-animated-crew-B")
	await photograph("01b-living-different-activities")
	crew.set_process(false)
	await measure("gallery-static-crew-A-repeat")
	crew.set_process(true)
	await frames(90)
	await photograph("01c-living-working-and-blinking")
	if OS.get_environment("HANGAR_CREW_RECORD_WORK")=="1": await record_work(crew)
	var old_crew: WeakRef = weakref(crew)
	var old_actor: WeakRef = weakref(crew.actors[0])
	world.prepared = world._plan_region(PLAN.Visit.WEST)
	world._enter_prepared()
	# Imported scenery is retired under the current per-frame unload budget.
	for frame in 1600:
		if old_crew.get_ref()==null and old_actor.get_ref()==null:break
		await process_frame
	check(old_crew.get_ref() == null and old_actor.get_ref() == null,"entering 1-2 unloads the original decorative actors")
	check(world.blockout.hangar_crew == null,"1-2 does not duplicate the hangar crew")
	world.prepared = world._plan_region(PLAN.Visit.EMPTY_HANGAR)
	while not world.prepared.build_steps.is_empty(): world.prepared.prepare_step()
	var returned: Node3D = world.prepared.hangar_crew
	check(returned.aftermath and not returned.blood_created and not world.prepared.live,"prepared return scenery stays hidden and does not spawn blood early")
	world._set_lower(true)
	world._place_feet(Vector2(-8.8,7.5))
	var enter_started := Time.get_ticks_usec()
	world._enter_prepared()
	var enter_ms := (Time.get_ticks_usec()-enter_started)*0.001
	print("CREW_AFTERTH_ENTER_MS ",enter_ms)
	await frames(70)
	crew = world.blockout.hangar_crew
	check(crew == returned and crew.actors.all(func(actor: EmployeeEnemy) -> bool: return actor.dead and actor.death_landed),"leaving 1-2 activates all three staged corpses")
	check(not is_instance_valid(world.blockout.mech),"crew aftermath accompanies the missing mech")
	check(crew.blood_created and crew.blood_segments >= 25,"return visit creates the longer drag trails and larger corpse pools")
	for i in 3:
		var p: Vector2 = crew.actors[i].position/32
		check(p.distance_to(crew.STANDING[i])>3.0,"corpse was displaced away from its original working position")
		var path_length := 0.0
		for j in crew.LONG_TRAILS[i].size()-1: path_length += crew.LONG_TRAILS[i][j].distance_to(crew.LONG_TRAILS[i][j+1])
		check(path_length>5.0,"corpse has a drag trail longer than five metres")
		for j in range(i+1,3): check(p.distance_to(crew.actors[j].position/32)>8.0,"corpses are scattered across different parts of the hangar")
	var count: int = crew.blood_segments
	world.blockout.activate_hangar_crew()
	check(crew.blood_segments == count,"repeated activation does not duplicate blood")
	var scenery: Node3D = crew.blood_scenery
	check(is_instance_valid(scenery) and scenery.visible and scenery.marks.size()==7,"return displays the compact static blood scenery")
	for mark: Sprite3D in scenery.marks:
		check(is_equal_approx(mark.global_position.y,crew.BLOOD_HEIGHT),"actual static blood geometry stays above the steel grate")
		check(mark.texture.get_image().get_used_rect().has_area() and mark.material_override.shader==scenery.SHADER,"blood uses the original painted alpha and approved material")
	check(scenery.pixel_count>1500 and world.world_effects_root.get_children().all(func(effect:Node)->bool:return not effect.get_meta(&"hangar_crew_scenery",false)),"long blood trails need no new blood simulation or capture viewports")
	await photograph("02-return-corpses-normal-camera")
	await measure("return-with-corpses-and-smears")
	world._place_feet(Vector2(3.4,1.5))
	await frames(50)
	await photograph("02b-return-bay-normal-camera")
	world._place_feet(Vector2(-3.5,-1.0))
	await frames(50)
	await photograph("02c-return-north-corpse")
	world._place_feet(Vector2(-2.5,10.2))
	await frames(50)
	await photograph("02d-return-south-corpse")
	await frames(100)
	check(crew.actors.all(func(actor: EmployeeEnemy) -> bool: return is_instance_valid(actor) and actor.dead and not actor.is_physics_processing()),"staged corpses remain still and persistent")
	var corpse_ref: WeakRef = weakref(crew.actors[0])
	await unload()
	check(corpse_ref.get_ref() == null,"chapter unload releases corpse pose sources")
	await enter(CHAPTER.Save.RETURN_BAY)
	crew = world.blockout.hangar_crew
	check(crew.aftermath and crew.blood_created and crew.actors.size() == 3,"retry at the return checkpoint restores the aftermath directly")
	await photograph("03-return-checkpoint")
	await unload()
	await enter(CHAPTER.Save.ENTRANCE)
	crew = world.blockout.hangar_crew
	check(not crew.aftermath and crew.actors.all(func(actor: EmployeeEnemy) -> bool: return not actor.dead),"a fresh chapter starts with the living crew again")
	await unload()
	var failures: Array = checks.filter(func(row: Dictionary) -> bool: return not row.pass)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0),"scope":"Actual chapter camera and original lighting; decorative crew combat isolation, streaming, checkpoint and reset. Bounded 240-frame samples are not whole-game performance certification."},"\t"))
	print("H06_HANGAR_CREW checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
