extends "res://tests/h06_hangar_crew_entry_test.gd"

func run() -> void:
	create_timer(150,true,false,true).timeout.connect(func():push_error("H06_CRAWLER_ENTRY_TIMEOUT");quit(3))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	await enter(CHAPTER.Save.ENTRANCE)
	check(not world.has_meta(&"h06_physical_crawler") and is_instance_valid(world.crawler_motion),"ordinary chapter entry enables physical H06 without test metadata")
	check(world.crawler_motion.gait.legs.size()==6 and world.crawler_motion.collision_layer==0,"gallery robot keeps six complete legs and respects the player's separate upper floor")
	check(world.blockout.wall_root.has_node("GalleryTopBlack") and world.blockout.hangar_crew.actors.size()==3,"normal entry preserves topblack, exhibit art and working crew")
	var exhibit_body:WeakRef=weakref(world.crawler_motion)
	await enter(CHAPTER.Save.MIDPOINT)
	check(exhibit_body.get_ref()==null,"checkpoint reload removes the previous exhibit body")
	var start:Vector3=world.blockout.mech.position
	# The checkpoint intentionally gives a 1.4 s head start; wait beyond it.
	await frames(100)
	check(world.blockout.mech.position.distance_to(start)>.1,"ordinary unpaused chase advances the physical crawler")
	var physical:Vector2=world.crawler_motion.global_position/32
	check(physical.distance_to(Vector2(world.blockout.mech.position.x,world.blockout.mech.position.z))<.002,"visible model and real swept body remain synchronized in normal gameplay")
	for i in 450:
		if world.player.dead:break
		await frames(1)
	check(world.player.dead and world.player.last_damage_source==&"h06_chase","standing still lets the real crawler contact defeat the player")
	await enter(CHAPTER.Save.ARENA)
	var body_id:int=world.crawler_motion.get_instance_id()
	var door:Dictionary=PLAN.PASSAGES[PLAN.Visit.STAFF]
	world.previous_feet=door.at-door.forward
	var cross:Vector2=door.at+door.forward*(PLAN.ENTRY_DEPTH+.4)
	world._place_feet(cross)
	world._update_passage(cross)
	await frames(24)
	check(world.blockout.visit==PLAN.Visit.ARENA and world.crawler_motion.get_instance_id()==body_id,"ordinary arena passage retains the same physical crawler")
	for i in 320:
		if world.blockout.inclined_lift.is_docked:break
		await physics_frame
	world._place_feet(PLAN.LIFT_ENTRY+Vector2(0,-4.9))
	var phases:Array[int]=[]
	for i in 310:
		if not phases.has(world.crawler_motion.jump):phases.append(world.crawler_motion.jump)
		if world.stage==CHAPTER.Stage.BOSS:break
		await frames(1)
	check(world.stage==CHAPTER.Stage.BOSS and phases.has(world.CRAWLER_MOTION.Jump.FLIGHT)
		and phases.has(world.CRAWLER_MOTION.Jump.COMPRESS) and phases.has(world.CRAWLER_MOTION.Jump.RECOVER),
		"the offscreen ambush enters in flight and completes landing recovery")
	check(world.crawler_motion.damage_owner==world.boss and world.boss.current_health==world.boss.MAX_HEALTH,"normal boss uses one health owner after the jump")
	check(world.crawler_motion.gait.debug_state().all(func(state:Dictionary):return state.error<.02),"normal landed legs remain connected")
	await photograph("normal-landing")
	world.boss.take_damage(10000)
	check(world.stage==CHAPTER.Stage.EXIT and world.blockout.inclined_lift.travel==world.blockout.inclined_lift.Travel.ARRIVING
		and world.crawler_motion.collision_layer==0,"boss defeat releases chassis collision and continues the upward ride")
	var ended:WeakRef=weakref(world.crawler_motion)
	await enter(CHAPTER.Save.ENTRANCE)
	check(ended.get_ref()==null and world.crawler_motion.damage_owner==null and not world.crawler_motion.dead,"starting again builds one fresh exhibit robot")
	current_scene.queue_free()
	await frames(8)
	var failures:Array=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(evidence.path_join("entry-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_CRAWLER_ENTRY ",checks.size()," checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
