extends "res://tests/h06_crawler_chapter_test.gd"

func next_region(id: int) -> void:
	world.prepared=world._plan_region(id)
	while not world.prepared.build_steps.is_empty():world.prepared.prepare_step()
	world._enter_prepared()
	for i in 1800:
		if world.unload_queue.is_empty():break
		world._drain_retired_region()
		await process_frame
	await frames(3)

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	create_timer(90).timeout.connect(func():push_error("H06_CRAWLER_LIFECYCLE_TIMEOUT");quit(2))
	await open_motion_chapter(CHAPTER.Save.CROSS_DOCK)
	world.player.set_physics_process(false)
	world.player.set_process(false)
	var body:MOTION=world.crawler_motion
	body.set_physics_process(false)
	body.teleport(Vector3(58,0,32),PI)
	var body_id:=body.get_instance_id()
	var model_id:=body.model.get_instance_id()
	var previous_roots:Array[WeakRef]=[]
	for node:Node in [world.blockout.floor_root,world.blockout.wall_root,world.blockout.physics_root,world.blockout.lights_root]:previous_roots.append(weakref(node))
	await next_region(PLAN.Visit.STAFF)
	check(world.crawler_motion.get_instance_id()==body_id and world.blockout.mech.get_instance_id()==model_id,"leaving freight transfers the same model, leg rig and physical body")
	check(previous_roots.all(func(item:WeakRef):return item.get_ref()==null),"freight visual and player collision roots can unload while the crawler keeps moving")
	world.stage=CHAPTER.Stage.STAFF
	world.chase_distance=world.mech_path.get_baked_length()
	world.ramp_distance=0
	var climbed:=false
	var on_roof:=false
	var joint_error:=0.
	for i in 1500:
		world._run_to_roof(1./60)
		if body.model.position.y>2 and body.model.position.y<6 and body.model.rotation.x<-.18:climbed=true
		for state:Dictionary in body.gait.debug_state():
			if not state.swing:joint_error=maxf(joint_error,state.error)
		if world.ramp_distance>=world.escape_path.get_baked_length()-.001:
			on_roof=true
			break
		await physics_frame
	check(climbed and on_roof,"grounded steps climb the full inclined ramp and turn onto the elevated hoist")
	check(joint_error<.10,"ramp transitions keep stance feet connected to their actual support")
	await next_region(PLAN.Visit.ARENA)
	check(world.crawler_motion.get_instance_id()==body_id,"entering the arena preserves the crawler body instead of leaving a duplicate behind")
	world.blockout.inclined_lift.snap_to_dock()
	world._start_drop()
	for i in 250:
		world._update_drop(1./60)
		await physics_frame
		if world.stage==CHAPTER.Stage.BOSS:break
	check(world.stage==CHAPTER.Stage.BOSS and world.crawler_motion.damage_owner==world.boss,"the transferred machine jumps down, settles and becomes the boss")
	var old_body:WeakRef=weakref(body)
	var old_model:WeakRef=weakref(body.model)
	var old_road:WeakRef=weakref(body.road)
	display.queue_free()
	await frames(8)
	check(old_body.get_ref()==null and old_model.get_ref()==null and old_road.get_ref()==null,"world unload clears the transferred rig, colliders and road geometry")
	await open_motion_chapter(CHAPTER.Save.ARENA)
	check(world.crawler_motion.get_instance_id()!=body_id and get_nodes_in_group(&"dream_enemies").is_empty(),"retry constructs one fresh machine without retained boss registrations")
	display.queue_free()
	await frames(8)
	FileAccess.open(evidence.path_join("lifecycle-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"stance_error":joint_error,"muted":AudioServer.is_bus_mute(0)},"\t"))
	var failures:=checks.filter(func(item):return not item.pass)
	print("H06_CRAWLER_LIFECYCLE ",checks.size()," checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
