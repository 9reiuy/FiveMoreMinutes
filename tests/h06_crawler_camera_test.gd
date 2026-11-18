extends "res://tests/h06_crawler_chapter_test.gd"
var recording := false
var phase := 0.0
var raw_samples: Array[Dictionary] = []
var motion_checks: Array[Dictionary] = []

func move_for_sample() -> void:
	if not recording or not is_instance_valid(world): return
	phase += 1./60
	var point := BOSS_MARK_3D+Vector3(2.0*sin(phase),0,2.0*cos(phase))
	var goal: Vector3=world.blockout.mech.position.move_toward(point,3./60)
	world._move_mech(goal,1./60)

func prepare_pose() -> void:
	world.blockout.inclined_lift.snap_to_dock()
	world.player.set_physics_process(false)
	world.player.set_process(false)
	world._place_feet(PLAN.BOSS_MARK+Vector2(0,8.))
	world.stage=CHAPTER.Stage.BOSS
	world.blockout.mech.show()
	world.blockout.mech.position=BOSS_MARK_3D+Vector3(0,0,2.)
	world.blockout.mech.rotation=Vector3.ZERO
	if is_instance_valid(world.crawler_motion):
		world.crawler_motion.arena=true
		world.crawler_motion.collision_mask=4|1|2|8|32
		world.crawler_motion.teleport(BOSS_MARK_3D+Vector3(0,0,2.),0)
	world._frame_encounter(world._feet(),1.,null)
	world._update_camera_and_actor_projection(1.)

func measure_motion(label: String) -> void:
	phase=0
	recording=true
	await frames(120)
	var raw: Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in 480:
		await process_frame
		var now:=Time.get_ticks_usec()
		raw.append((now-previous)*.001)
		previous=now
	recording=false
	var sorted:=raw.duplicate(); sorted.sort()
	raw_samples.append({"label":label,"frames_ms":raw,"p50":sorted[239],"p95":sorted[455],"p99":sorted[475],"max":sorted[-1],"over20":raw.filter(func(v):return v>20).size()})
	print("MOTION_SAMPLE ",label," p95=",sorted[455]," max=",sorted[-1])

func camera_frame(folder: String, index: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	display.world_viewport.get_texture().get_image().save_png(folder.path_join("%03d.png"%index))

func capture_motion() -> void:
	var folder:=evidence.path_join("walk")
	DirAccess.make_dir_recursive_absolute(folder)
	phase=0
	recording=true
	for i in 60:
		await frames(2)
		await camera_frame(folder,i)
	recording=false
	check(world.crawler_motion.gait.total_steps>10,"actual game camera records alternating planted-foot walking and turning")
	world.crawler_motion.arena=false
	world.crawler_motion.set_physics_process(false)
	world.crawler_motion.collision_mask=MOTION.ROAD_LAYER|1|2|8|32
	world._start_drop()
	var phases: Array[int]=[]
	folder=evidence.path_join("jump")
	DirAccess.make_dir_recursive_absolute(folder)
	var index:=0
	var min_landing_y:=0.
	for i in 250:
		world._update_drop(1./60)
		var body: MOTION=world.crawler_motion
		if not phases.has(body.jump):phases.append(body.jump)
		if body.jump in [MOTION.Jump.COMPRESS,MOTION.Jump.RECOVER]:min_landing_y=minf(min_landing_y,body.model.position.y)
		world._frame_encounter(world._feet(),1./60,null)
		world._update_camera_and_actor_projection(1./60)
		await physics_frame
		if i%2==0:
			await camera_frame(folder,index)
			index+=1
		if world.stage==CHAPTER.Stage.BOSS:break
	check(phases.has(MOTION.Jump.FLIGHT) and phases.has(MOTION.Jump.COMPRESS) and phases.has(MOTION.Jump.RECOVER)
		and not phases.has(MOTION.Jump.CROUCH),"the ambush enters airborne and runs the full landing recovery")
	check(min_landing_y<-.25 and is_instance_valid(world.boss),"boss becomes active after landing suspension recovers")
	var boss=world.boss
	boss.set_physics_process(false)
	world.crawler_motion.set_physics_process(false)
	var body: MOTION=world.crawler_motion
	check(body.gait.debug_state().all(func(state:Dictionary):return state.error<.015 and absf((state.ankle as Vector3).y-.317)<.02),"all six landing feet settle on the docked cargo deck")
	check(body.damage_owner==boss and body.is_in_group(&"dream_enemies") and boss.collision_layer==0,"leg and chassis hits resolve to one shared boss health owner")
	var leg:Dictionary=body.gait.legs[1]
	var foot:Vector3=leg.ankle.global_position
	var aim:=Vector2(foot.x,foot.z)*32
	var shot: Node2D=preload("res://scenes/entities/basic_projectile.tscn").instantiate()
	var start:=aim+Vector2(-5,0)*32
	shot.position=start
	preload("res://scripts/dream/dream_firearm_rules.gd").setup_projectile(shot,Vector2.RIGHT,10,340,28*32,&"player",world.player,&"basic")
	var shield_hits: Array[Vector2]=[]
	boss.attacks.event.connect(func(kind:StringName,data:Dictionary):
		if kind==&"shield_block":shield_hits.append(data.at))
	world.player.critical_chance=0.0
	boss.take_damage(81.)
	world.add_projectile(shot,world.player)
	var hp:float=boss.current_health
	for i in 30:
		if not shield_hits.is_empty():break
		await physics_frame
	check(is_equal_approx(boss.current_health,hp-1.0) and shield_hits.size()==1,"the extended leg catches the side shot and the phase-two armor receives a tenth of its damage")
	boss.take_damage(10000)
	check(world.stage==CHAPTER.Stage.EXIT and world.blockout.inclined_lift.travel==world.blockout.inclined_lift.Travel.ARRIVING
		and body.collision_layer==0 and not body.is_in_group(&"dream_enemies"),"defeat releases collision and continues the upward ride")
	await frames(40)
	await photograph("boss-grounded")

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	create_timer(115).timeout.connect(func():push_error("H06_CAMERA_TIMEOUT");quit(2))
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	physics_frame.connect(move_for_sample)
	var variants:Array=[{"label":"A-before","enabled":false},{"label":"B-physical","enabled":true},{"label":"A-after","enabled":false}]
	if OS.get_environment("H06_CAPTURE_ONLY")=="1": variants=[{"label":"B-final","enabled":true}]
	for variant: Dictionary in variants:
		await open_motion_chapter(CHAPTER.Save.ARENA,variant.enabled)
		prepare_pose()
		await measure_motion(variant.label)
		if variant.enabled:await capture_motion()
		var old_body:WeakRef=weakref(world.crawler_motion) if is_instance_valid(world.crawler_motion) else null
		display.queue_free()
		await frames(8)
		if old_body!=null:check(old_body.get_ref()==null,"unload removes the full production collision and gait controller")
	world=null
	FileAccess.open(evidence.path_join("camera-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"samples":raw_samples,"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	var failures:=checks.filter(func(item):return not item.pass)
	print("H06_CAMERA_RESULT ",checks.size()," checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
