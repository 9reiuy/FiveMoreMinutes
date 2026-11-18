extends "res://tests/h06_crawler_chapter_test.gd"
const PATTERNS := preload("res://scripts/testing/h06_chapter/crawler_attacks.gd")
var enabled := true
var sampling := false
var sim_age := 0.
var previous_usec := 0
var raw: Array[float] = []
var attack_events: Array[Dictionary] = []
var frame_events: Array[Dictionary] = []
var phase_requested := false
var phase_probe := false
var shield_requested := false
var impact_shudder_sampled := false

func advance_fight() -> void:
	if not sampling or not is_instance_valid(world):return
	Engine.time_scale=1
	sim_age+=1./60
	var lift = world.blockout.inclined_lift
	if sim_age >= 3.05 and not impact_shudder_sampled:
		lift.shake_on_landing()
		impact_shudder_sampled = true
	lift.advance(1./60)
	# Identical player route in both versions, retaining real hit reception and scene geometry.
	var p:=PLAN.BOSS_MARK+Vector2(4.5*sin(sim_age*.7),8.5+1.5*cos(sim_age*.7))
	var offset:Vector2=p-world._feet()
	world.player.set_scripted_locomotion(offset.normalized(),minf(4.5*32,offset.length()*32*12))
	world.player.current_health=world.player.maximum_health
	if phase_probe and sim_age >= 10.0 and not shield_requested:
		shield_requested = true
		world.boss.take_damage(world.boss.current_health-world.boss.MAX_HEALTH*PATTERNS.SHIELD_HEALTH+.01)
	if phase_probe and sim_age >= 14. and not phase_requested:
		phase_requested = true
		world.boss.take_damage(world.boss.current_health-(world.boss.MAX_HEALTH*.5-1.))
	world.boss._physics_process(1./60)
	frame_events.append({"frame":Engine.get_process_frames(),"time":sim_age,"boss":str(world.blockout.mech.position)})

func sample_frame() -> void:
	if not sampling:return
	var now:=Time.get_ticks_usec()
	if previous_usec>0:raw.append((now-previous_usec)*.001)
	previous_usec=now

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	enabled=OS.get_environment("H06_ATTACK_BASELINE")!="1"
	phase_probe=OS.get_environment("H06_PHASE_LOAD")=="1"
	create_timer(90).timeout.connect(func():push_error("H06_ATTACK_LOAD_TIMEOUT");quit(2))
	node_added.connect(func(node:Node):
		if node.get_script()!=CHAPTER:return
		node.set_meta(&"h06_boss_patterns",enabled)
	)
	await open_motion_chapter(CHAPTER.Save.ARENA,true,true)
	world.blockout.mech.show()
	world.crawler_motion.teleport(BOSS_MARK_3D,0)
	world._begin_crawler_boss()
	world.boss.attacks.cargo.random.seed = 59520
	world.blockout.inclined_lift.start_ascent()
	world.boss.set_physics_process(false)
	world.crawler_motion.set_physics_process(false)
	world.player.set_physics_process(true)
	world.player.maximum_health=1000
	world.player.current_health=1000
	world._place_feet(PLAN.LIFT_ENTRY+Vector2(0,-1.7))
	var camera:Camera3D=world.camera_3d
	camera.global_position=world.to_global(BOSS_MARK_3D+Vector3(0,22,21.5))
	camera.look_at(world.to_global(BOSS_MARK_3D+Vector3(0,0,3.5)))
	camera.fov=65
	if enabled:
		world.boss.attacks.event.connect(func(kind:StringName,data:Dictionary):attack_events.append({"kind":kind,"data":data,"at":sim_age}))
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(120)
	physics_frame.connect(advance_fight)
	process_frame.connect(sample_frame)
	sampling=true
	for i in 2100:await physics_frame
	sampling=false
	var sorted:=raw.duplicate();sorted.sort()
	var completed:Array=attack_events.filter(func(row:Dictionary):return row.kind==&"attack_finished").map(func(row:Dictionary):return row.data.attack)
	if enabled:
		check(PATTERNS.CYCLE.all(func(kind:int):return completed.has(PATTERNS.NAMES[kind])),"continuous production-art sample executes the full regular rotation")
		check(attack_events.filter(func(row:Dictionary):return row.kind==&"barrage_row_impact").size()>=3,"the matched run includes all three landed waves of the barrage")
	if phase_probe and enabled:
		check(completed.count(&"burst")==1,"the combat sample crosses half health and renders the one-time six-way laser")
		check(attack_events.filter(func(row: Dictionary):return row.kind==&"cargo_warning").size()==2
			and attack_events.any(func(row: Dictionary):return row.kind==&"cargo_broken"),
			"the combat sample includes both real crane drops and at least one shattering event")
	check(not world.player.dead and AudioServer.is_bus_mute(0),"load sample retains the real actor and private mute throughout")
	check(world.blockout.inclined_lift.distance>90.,"the sample includes continuously moving walls and lamps for the full battle window")
	var summary:Dictionary={"p50":sorted[floori(sorted.size()*.50)],"p95":sorted[floori(sorted.size()*.95)],"p99":sorted[floori(sorted.size()*.99)],"max":sorted[-1],"over20":raw.filter(func(v:float):return v>20).size(),"frames":raw.size()}
	var record:Dictionary={"pid":OS.get_process_id(),"enabled":enabled,"summary":summary,"frames_ms":raw,"physics":frame_events,"events":attack_events,"checks":checks,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)}
	FileAccess.open(evidence.path_join("attack-load.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	print("H06_ATTACK_LOAD ",summary," completed=",completed)
	display.queue_free()
	await frames(8)
	var failures:=checks.filter(func(row:Dictionary):return not row.pass)
	quit(0 if failures.is_empty() else 1)
