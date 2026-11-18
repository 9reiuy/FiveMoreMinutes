extends "res://tests/forklift_contact_test.gd"
## Production 1-2 architecture and elevated contact sparks, then a real enemy ram.
var controller_times: Array[Dictionary] = []

class ContactTimer extends Node:
	var probe: SceneTree
	var before := false
	var stamp: Array[int]
	func _physics_process(_delta: float) -> void:
		if before:
			stamp[0] = Time.get_ticks_usec()
		else:
			var pending: Object = probe.world.prepared
			probe.controller_times.append({"frame":Engine.get_physics_frames(),"controller_ms":(Time.get_ticks_usec()-stamp[0])*0.001,
				"contacts":probe.lift.get_slide_collision_count(),"pending_build_steps":pending.build_steps.size() if is_instance_valid(pending) else 0})

func run() -> void:
	create_timer(140,true,false,true).timeout.connect(func(): quit(3))
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(evidence)
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1
	Engine.max_fps = 60
	await enter_chapter(CHAPTER.Save.CALIBRATED)
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	check(lift.contact_response_enabled,"normal chapter defaults to the new contact response")
	place_feet(PLAN.FORKLIFT_START + Vector2(-1.2,0))
	await frames(3)
	check(lift.board(world.player),"E-compatible cab boarding at the actual 1-2 entrance")
	var stamp: Array[int] = [0]
	var before_timer := ContactTimer.new()
	before_timer.probe = self; before_timer.before = true; before_timer.stamp = stamp
	before_timer.process_physics_priority = -51
	root.add_child(before_timer)
	var after_timer := ContactTimer.new()
	after_timer.probe = self; after_timer.stamp = stamp
	after_timer.process_physics_priority = -49
	root.add_child(after_timer)
	lift.speed = 8.0
	Input.action_press("move_up")
	begin_trace()
	var touched := await contact_frame(180)
	Input.action_release("move_up")
	check(touched,"northbound drive hits actual chapter architecture")
	check(lift.velocity.length() > 8.0,"real obstacle returns a nonzero collision reaction")
	check(lift._supported(lift.global_transform),"reaction stays on the elevated chapter floor")
	var fx: Node = world._firearm_fx()
	check(not fx._hot_particles.is_empty(),"actual chapter contact emits the shared sparks")
	var elevated: bool = not fx._hot_particles.is_empty()
	for particle in fx._hot_particles:
		elevated = elevated and particle.origin.y > 3.0 and particle.origin.y < 3.8
	check(elevated,"contact sparks use the correct elevated floor height")
	end_trace("first-authored-chapter-contact")
	check(not controller_times.is_empty(),"controller timing captures the real contact window")
	before_timer.queue_free()
	after_timer.queue_free()
	await capture("chapter-contact-sparks")
	check_seat("after collision")
	park(PLAN.FORKLIFT_START, PLAN.FORKLIFT_HEADING)
	fx.clear()
	var target: Vector2 = PLAN.FORKLIFT_START + Vector2(0,-3.2)
	var enemy: EmployeeEnemy = world._spawn_regular_employee(0,target*32,&"employee",false,"")
	enemy.set_room_runtime_active(true)
	enemy.set_physics_process(false)
	enemy.global_position += target*32-enemy.get_node("CollisionShape2D").global_position
	enemy.maximum_health = 1000
	enemy.current_health = 1000
	await frames(3)
	var before: float = enemy.current_health
	lift.speed = 8
	Input.action_press("move_up")
	for i in 80:
		await physics_frame
		if enemy.current_health < before: break
	Input.action_release("move_up")
	check(enemy.current_health < before and enemy.impact_blood_spawned,"existing enemy damage and blood still occur")
	check(lift.velocity.length()/32 > 3.5,"ramming a lighter enemy preserves forward momentum")
	check(fx._hot_particles.is_empty(),"enemy impacts keep blood instead of metal sparks")
	lift.reset_motion()
	await frames(85)
	var surface: Node = world.office_art_root.get_node("SurfaceBlood")
	check(surface.hit_count > 0 and surface.use_surface_meshes,"nonflickering attached blood remains active after the new collision")
	await capture("chapter-ram-blood")
	check(lift.try_exit(),"driver can dismount after the real collision and ram")
	var old: WeakRef = weakref(lift)
	current_scene.queue_free()
	await frames(6)
	check(not is_instance_valid(old.get_ref()),"chapter unload clears collision and spark ownership")
	verify_audio()
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"metrics":metrics,"controller_times":controller_times,"scope":"Actual 1-2 entrance and architecture, elevated sparks and existing ram blood. Controller timings bracket physics priority -50; full frame timings also include region preparation. Enemies frozen for reproducibility; not a full playthrough."},"\t"))
	print("H06_FORKLIFT_CONTACT checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
