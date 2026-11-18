extends "res://tests/h06_hangar_crew_test.gd"
const MOTION := preload("res://scripts/testing/h06_chapter/crawler_motion.gd")
const BOSS_MARK_3D := Vector3(PLAN.BOSS_MARK.x,0.,PLAN.BOSS_MARK.y)
var captures: Array[Dictionary] = []
var route: Array[Dictionary] = []

func open_motion_chapter(save: int, enabled := true, cargo_enabled := false) -> void:
	set_meta(CHAPTER.RETRY_KEY,{"checkpoint":save})
	world = load(WORLD).instantiate()
	world.generate_on_ready=false
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.set_meta(&"h06_physical_crawler",enabled)
	world.set_meta(&"h06_evacuation_enabled",false)
	world.set_meta(&"h06_cargo_enabled",cargo_enabled)
	display=load(PREVIEW).instantiate()
	display.preview_mode=false
	display.world=world
	root.add_child(display)
	await frames(1)
	if not AudioServer.is_bus_mute(0): AudioServer.set_bus_mute(0,true); quit(2); return
	check(world.regenerate(11011),"production chapter generates checkpoint "+str(save))
	world._setup_chapter_session()
	world.process_mode=Node.PROCESS_MODE_INHERIT
	world.set_process(false)
	world.set_physics_process(false)
	if save==CHAPTER.Save.ARENA:
		world.prepared=world._plan_region(PLAN.Visit.ARENA)
		while not world.prepared.build_steps.is_empty():world.prepared.prepare_step()
		world._enter_prepared()
		for i in 180:
			if world.unload_queue.is_empty():break
			world._drain_retired_region()
			await process_frame
		check(world.blockout.visit==PLAN.Visit.ARENA and world.blockout.floor_root.is_visible_in_tree(),"camera and shots use the actual active elevator arena")
	root.get_node("DreamTimeController").slow_time_enabled=false
	Engine.time_scale=1
	await frames(3)

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	create_timer(115).timeout.connect(func():push_error("H06_CHAPTER_MOTION_TIMEOUT");quit(2))
	await open_motion_chapter(CHAPTER.Save.CHASE)
	var body: MOTION = world.crawler_motion
	check(is_instance_valid(body),"chapter uses the new persistent swept body")
	world.player.set_physics_process(false)
	world.player.set_process(false)
	world._place_feet(Vector2(2.4,18.4))
	var ok := true
	var max_joint := 0.
	var previous := body.model.position
	var stopped := 0
	for index in range(1,PLAN.CHASE_PATH.size()):
		var point: Vector2=PLAN.CHASE_PATH[index]
		for i in 1800:
			var pos:=Vector2(body.model.position.x,body.model.position.z)
			if pos.distance_to(point)<.15:break
			if pos.y>32.5 and not world.breached:world.breached=true;world.blockout.breach_freight()
			world._tick_freight_containers(1./60,world._feet())
			var goal:=pos.move_toward(point,7./60)
			world._move_mech(Vector3(goal.x,0,goal.y),1./60)
			for state: Dictionary in body.gait.debug_state():
				if state.error>max_joint+.10:print("ROUTE_JOINT index=",index," at=",body.model.position," state=",state)
				max_joint=maxf(max_joint,state.error)
			stopped=stopped+1 if body.model.position.distance_to(previous)<.001 else 0
			previous=body.model.position
			if stopped>45:
				ok=false
				print("ROUTE_BLOCKED index=",index," at=",body.model.position," target=",point," colliders=",body.get_slide_collision_count())
				print("ROUTE_STOP_LEGS ",body.gait.debug_state()," step=",body.gait.stepping," group=",body.gait.swing_group," time=",body.gait.step_time," total=",body.gait.total_steps)
				break
			await physics_frame
		if not ok:break
		route.append({"index":index,"at":str(body.model.position)})
		print("ROUTE_POINT ",index," at=",body.model.position)
	check(ok,"full-scale H06 physically traverses the authored freight route and retracting shutter")
	check(max_joint<.10,"production turns and pursuit speed keep connected legs on their targets")
	FileAccess.open(evidence.path_join("chapter-route.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"route":route,"max_joint":max_joint,"muted":AudioServer.is_bus_mute(0)},"\t"))
	display.queue_free()
	await frames(5)
	var failures:=checks.filter(func(item):return not item.pass)
	quit(0 if failures.is_empty() else 1)
