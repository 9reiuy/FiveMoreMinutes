extends "res://tests/h06_boss_attacks_test.gd"
var movie: Array[Dictionary] = []
var event_pending := false

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	create_timer(130).timeout.connect(func():push_error("H06_ATTACK_CAMERA_TIMEOUT");quit(2))
	await open_motion_chapter(CHAPTER.Save.ARENA)
	world.blockout.mech.show()
	world.crawler_motion.teleport(BOSS_MARK_3D,0)
	world._begin_crawler_boss()
	director=world.boss.attacks
	world.boss.set_physics_process(true)
	world.crawler_motion.set_physics_process(true)
	director.event.connect(func(kind:StringName,data:Dictionary):
		log_events.append({"kind":kind,"data":data.duplicate(true)})
		if kind in [&"cannon_fired",&"missile_launched",&"slam_impact",&"charge_started",&"stomp_impact",&"burst_fired",&"shield_block",&"barrage_row_fired",&"barrage_row_impact"]:event_pending=true)
	var folder:=evidence.path_join("frames")
	DirAccess.make_dir_recursive_absolute(folder)
	# A native full-arena camera makes the stationary chassis, beams and missile arcs
	# readable in this recording. Ordinary gameplay retains its follow camera.
	var camera:Camera3D=world.camera_3d
	camera.global_position=world.to_global(BOSS_MARK_3D+Vector3(0,23,20.5))
	camera.look_at(world.to_global(BOSS_MARK_3D+Vector3(0,0,3.5)))
	camera.fov=60
	var offsets:Array[Vector2]=[Vector2(0,10),Vector2(-3,8),Vector2(3,11),Vector2(2,7.3),Vector2(-2,11.5),Vector2(-1,5.5)]
	for kind in [PATTERNS.Attack.CANNON,PATTERNS.Attack.MISSILES,PATTERNS.Attack.LASER,PATTERNS.Attack.BURST,PATTERNS.Attack.BARRAGE]:
		reset_case(PLAN.BOSS_MARK+Vector2(0,9.))
		director.fx.BURN.install(world).clear()
		world.crawler_motion.set_physics_process(true)
		world.player.set_physics_process(true)
		if kind==PATTERNS.Attack.CANNON:
			world._place_feet(PLAN.BOSS_MARK+Vector2(0,-7.))
			world.crawler_motion.teleport(BOSS_MARK_3D,PI)
		if kind==PATTERNS.Attack.BURST:world.boss.take_damage(81.)
		director.begin(kind)
		var fired:=false
		var last_capture:float=-1.
		var quiet_since := -1.
		var started:=Time.get_ticks_msec()
		for i in 1100:
			await physics_frame
			if kind==PATTERNS.Attack.MISSILES and director.attack==kind and director.state==PATTERNS.State.WINDUP:
				world._place_feet(PLAN.BOSS_MARK+offsets[mini(5,director.targets.size())])
			if kind==PATTERNS.Attack.CANNON and director.state==PATTERNS.State.ACTIVE and not fired:
				fired=true
				world._place_feet(PLAN.BOSS_MARK+Vector2(5,10.))
			var t:float=(Time.get_ticks_msec()-started)*.001
			if t-last_capture>=.078 or event_pending:
				event_pending=false
				last_capture=t
				await process_frame
				await RenderingServer.frame_post_draw
				var path:=folder.path_join("%04d.png"%movie.size())
				display.world_viewport.get_texture().get_image().save_png(path)
				movie.append({"file":path,"attack":kind,"time":t})
			if not events(&"attack_finished").is_empty() and director.rockets.is_empty() and not director.shell_active:
				if quiet_since<0.:quiet_since=t
				if t-quiet_since>.22:break
		check(quiet_since>=0.,"actual automatic gameplay camera sequence completes "+str(PATTERNS.NAMES[kind]))
		world.boss.set_physics_process(false)
		# Allow the final cloud to advance before the next reset, with no frozen VFX.
		await frames(12)
		world.boss.set_physics_process(true)
	reset_case(PLAN.BOSS_MARK+Vector2(0,9.))
	world.boss.set_physics_process(false)
	world.crawler_motion.set_physics_process(false)
	director.fx.BURN.install(world).clear()
	shot_at(PLAN.BOSS_MARK+Vector2(0,8.1),PLAN.BOSS_MARK)
	for i in 30:
		await physics_frame
		if events(&"shield_block").is_empty():continue
		await photograph("front-shield-impact")
		break
	check(events(&"shield_block").size()==1,"native camera catches the real protected front impact")
	var weak:WeakRef=weakref(director.fx)
	display.queue_free()
	await frames(8)
	check(weak.get_ref()==null,"recording exit releases every attack visual")
	var failures:=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(evidence.path_join("camera-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"frames":movie,"events":log_events,"muted":AudioServer.is_bus_mute(0),"renderer":RenderingServer.get_current_rendering_method(),"camera":"fixed native overview for attack review"},"\t"))
	print("H06_ATTACK_CAMERA checks=",checks.size()," failures=",failures.size()," frames=",movie.size())
	quit(0 if failures.is_empty() else 1)
