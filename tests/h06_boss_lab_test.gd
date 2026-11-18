extends SceneTree
const PATTERNS := preload("res://scripts/testing/h06_chapter/crawler_attacks.gd")
const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
var checks: Array[Dictionary]=[]
var evidence := ""
var lab: Control
var display: Control
var world: Node3D

func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func check(value: bool, label: String) -> void:
	checks.append({"pass":value,"label":label})
	print("PASS " if value else "FAIL ",label)
func press(key: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.pressed=true
	Input.parse_input_event(event)
	await frames(3)
	event=InputEventKey.new()
	event.physical_keycode=key
	Input.parse_input_event(event)
	await frames(2)

func open_lab() -> void:
	check(change_scene_to_file("res://scenes/testing/H06BossAttackLab.tscn")==OK,"the dedicated playable scene opens")
	await scene_changed
	for i in 2500:
		await process_frame
		if current_scene.presentation!=null and current_scene.presentation.ready_lab and current_scene.presentation.entry_loading==null:break
	lab=current_scene
	display=lab.presentation
	world=display.world

func photograph(file: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	display.world_viewport.get_texture().get_image().save_png(evidence.path_join(file+".png"))
	root.get_texture().get_image().save_png(evidence.path_join(file+"-ui.png"))

func run() -> void:
	create_timer(110,true,false,true).timeout.connect(func():push_error("H06_BOSS_LAB_TIMEOUT");quit(2))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	await open_lab()
	check(display.ready_lab and world.stage==world.Stage.BOSS and world.boss.attacks!=null,"entry goes directly to the active real H06 arena without chapter travel or drop")
	check(world.blockout.visit==world.PLAN.Visit.ARENA and world.chapter_staged_regions.is_empty(),"only the elevator arena is loaded, without the preceding staff and freight regions")
	check(world.blockout.evacuation==null,"direct attack practice starts with the fight-ready deck")
	check(world.player.lab_ignore_damage and not world.persist_profile,"practice defaults to isolated player immunity without campaign persistence")
	print("PRACTICE_PANEL ",display.panel.size)
	check(display.panel.size.y<260 and display.panel.size.x<170,"practice controls stay compact beside the playable arena")
	display._pointer_window=display.panel.get_global_rect().get_center()
	check(not display._pointer_inside(),"clicking the practice panel cannot shoot into the arena")
	await press(KEY_F1)
	check(not display.panel.visible,"F1 hides the entire practice panel")
	await press(KEY_F1)
	check(world.boss.current_health==160 and world.player.selected_weapon_id=="assault_rifle","practice retains actual boss health and equips a real assault rifle")
	var fx=world.boss.attacks.fx
	check(fx.soft_warnings and fx.lane.mesh is PlaneMesh and fx.marks.all(func(node:MeshInstance3D):return node.mesh is PlaneMesh),"range warnings use ground planes with the soft reference shader")
	for i in 5:
		await press((KEY_1+i) as Key)
		check(world.selected_attack==i and world.boss.attacks.attack==i and world.boss.attacks.state==PATTERNS.State.WINDUP,"number key switches immediately to "+str(PATTERNS.NAMES[i]))
	await press(KEY_P)
	var age:float=world.boss.attacks.age
	await frames(20)
	check(world.attacks_paused and is_equal_approx(age,world.boss.attacks.age),"P freezes the boss attack while the practice scene remains interactive")
	await press(KEY_P)
	await frames(4)
	check(not world.attacks_paused and world.boss.attacks.age>age,"P resumes the same attack")
	await press(KEY_F2)
	world.player.invulnerability_left=0
	world.player.dash_invulnerability_left=0
	var hp:float=world.player.current_health
	world.player.receive_damage(1,&"lab_probe")
	check(not world.player.lab_ignore_damage and world.player.current_health<hp,"F2 enables real damage through the original player method")
	await press(KEY_F2)
	hp=world.player.current_health
	world.player.receive_damage(1000,&"lab_probe")
	check(world.player.lab_ignore_damage and world.player.current_health==hp,"F2 restores practice immunity")
	await press(KEY_3)
	for i in 200:
		await physics_frame
		if world.crawler_motion.jump==world.crawler_motion.Jump.FLIGHT:break
	await press(KEY_4)
	print("SWITCH_JUMP selected=",world.selected_attack," attack=",world.boss.attacks.attack," jump=",world.crawler_motion.jump," shell=",fx.shell.visible)
	check(world.crawler_motion.jump==world.crawler_motion.Jump.NONE and world.boss.attacks.attack==PATTERNS.Attack.LASER and not fx.shell.visible,"switching during a leap safely restores grounded support and cancels the old attack")
	await press(KEY_1)
	var repeated:=0
	world.boss.attacks.event.connect(func(kind:StringName,data:Dictionary):
		if kind==&"windup" and data.attack==&"cannon":world.set_meta("lab_cannon_repeated",true))
	for i in 260:
		if world.get_meta("lab_cannon_repeated",false):repeated=1;break
		await physics_frame
	check(repeated==1 and world.selected_attack==0,"single attack selection repeats after its normal recovery")
	await press(KEY_0)
	print("SWITCH_LOOP selected=",world.selected_attack," attack=",world.boss.attacks.attack," jump=",world.crawler_motion.jump)
	check(world.selected_attack==-1 and world.boss.attacks.attack==0,"0 returns to the normal attack cycle")
	await press(KEY_6)
	check(world.boss.attacks.attack==PATTERNS.Attack.STOMP and world.boss.attacks.stomp_leg>=0,"6 stages a reachable single-foot stomp in the actual arena")
	await press(KEY_7)
	for i in 100:
		await physics_frame
		if world.boss.attacks.burst_used:break
	check(world.boss.current_health<80 and world.boss.attacks.burst_used,"7 moves H06 below half health and runs its six-way attack")
	await photograph("half-health-burst")
	await press(KEY_8)
	check(world.selected_attack==PATTERNS.Attack.BARRAGE and fx.salvo_rows.all(func(row:MeshInstance3D):return row.visible),"8 opens the three-row barrage practice")
	for i in 80:
		if not world.boss.attacks.rockets.is_empty():break
		await physics_frame
	check(not world.boss.attacks.rockets.is_empty(),"barrage practice sends real missiles downrange")
	await press(KEY_4)
	check(world.boss.attacks.rockets.is_empty() and fx.salvo_rows.all(func(row:MeshInstance3D):return not row.visible),"switching practice clears in-flight missiles and their warning rows")
	await press(KEY_P)
	fx.clear()
	fx.mark(0,PLAN.BOSS_MARK+Vector2(-4.5,7.3),1.95)
	fx.warn_line(PLAN.BOSS_MARK+Vector2(0,10.),PLAN.BOSS_MARK+Vector2(9,10.),1.6,.65)
	fx.charge_mark(0,.75)
	check((fx.marks[0].material_override as ShaderMaterial).get_shader_parameter("half_size")==Vector2(1.95,1.95) and (fx.lane.material_override as ShaderMaterial).get_shader_parameter("half_size")==Vector2(.8,4.5),"bright contours retain the requested radius and rectangular damage dimensions")
	await photograph("reference-warnings")
	fx.clear()
	check(not fx.lane.visible and fx.marks.all(func(node:MeshInstance3D):return not node.visible),"clearing an attack removes fill, outlines and halos together")
	var old_body:WeakRef=weakref(world.crawler_motion)
	var old_fx:WeakRef=weakref(fx)
	await press(KEY_F5)
	for i in 2000:
		await process_frame
		if current_scene!=lab and current_scene.presentation!=null and current_scene.presentation.ready_lab and current_scene.presentation.entry_loading==null:break
	display=current_scene.presentation
	world=display.world
	check(old_body.get_ref()==null and old_fx.get_ref()==null and world.stage==world.Stage.BOSS and not world.boss.dead,"F5 releases the old robot and warnings then restarts directly in the boss arena")
	check(world.boss.current_health==160 and not world.boss.attacks.burst_used,"restart restores full health and resets the one-time attack")
	await photograph("direct-entry")
	var direct_scene := current_scene
	var direct_deck: WeakRef = weakref(world.blockout.inclined_lift)
	await press(KEY_9)
	for i in 2000:
		await process_frame
		if current_scene!=direct_scene and current_scene.presentation!=null and current_scene.presentation.ready_lab and current_scene.presentation.entry_loading==null:break
	display=current_scene.presentation
	world=display.world
	check(direct_deck.get_ref()==null and world.stage==world.Stage.APPROACH and world.boss==null and world.blockout.inclined_lift.is_docked,"9 starts on the lower landing beside the docked deck")
	check(world.blockout.evacuation!=null and world.blockout.evacuation.actors.size()==7,"boarding replay includes the seven logistics evacuees")
	for i in 18:await physics_frame
	check(not world.blockout.closed.boarding and world.blockout.inclined_lift.is_docked,"replay waits until the player boards")
	world.player.set_scripted_locomotion(Vector2.UP,3.3*32.)
	for i in 660:
		if not world.blockout.inclined_lift.is_docked:world.player.clear_scripted_locomotion()
		if world.stage==world.Stage.BOSS:break
		await physics_frame
	check(world.stage==world.Stage.BOSS and world.boss.attacks!=null and not world.boss.attacks.fx.shield.is_shield_active(),"replay follows combat takeover with the full-health shield inactive")
	check(world.blockout.evacuation.crushed and world.blockout.evacuation.actors.all(func(actor: EmployeeEnemy):return actor.dead),
		"replayed touchdown resolves the seven scripted casualties")
	var platform: Node3D = world.blockout.inclined_lift
	world.forklift_restore_state = {"visit":PLAN.Visit.ARENA,"position":PLAN.BOSS_MARK+Vector2(4,-4.65),"height":0.0,"heading":0.0}
	world.blockout._build_forklift()
	var truck = world.blockout.forklift
	world._place_feet(truck._seat_position()/32.)
	check(truck.board(world.player),"the player can remain aboard the real forklift when the lift departs")
	var feet_before: Vector2 = world._feet()
	var truck_before: Vector2 = truck.global_position
	var travel_before: float = platform.distance
	var frame_intervals: Array[float] = []
	var last := [0]
	var sample := func():
		var now := Time.get_ticks_usec()
		if last[0]>0:frame_intervals.append((now-last[0])*.001)
		last[0]=now
	process_frame.connect(sample)
	world.boss.take_damage(10000.)
	check(world.stage==world.Stage.EXIT and platform.travel==platform.Travel.ARRIVING
		and not world.blockout.gates.has("lift"),"defeating H06 continues the active ride into the upper stop")
	for i in 320:
		if world.stage==world.Stage.DONE:break
		await physics_frame
	process_frame.disconnect(sample)
	check(world.stage==world.Stage.DONE and platform.travel==platform.Travel.UPPER and platform.distance>travel_before+1.
		and world._feet().distance_to(feet_before)<.02,"upward replay keeps the character at the same place on the deck and comes to a stop")
	check(truck.driver==world.player and is_zero_approx(truck.floor_height)
		and truck.global_position.distance_to(truck_before)<.05
		and world._feet().distance_to(truck._seat_position()/32.)<.02,"forklift and mounted player reach the high stop with the seat and floor aligned")
	var sorted := frame_intervals.duplicate()
	sorted.sort()
	if not sorted.is_empty():
		var receipt := {"frames_ms":frame_intervals,"renderer":RenderingServer.get_current_rendering_method(),"pid":OS.get_process_id(),
			"summary":{"p50":sorted[floori(sorted.size()*.5)],"p95":sorted[floori(sorted.size()*.95)],
			"p99":sorted[floori(sorted.size()*.99)],"max":sorted[-1],"over20":sorted.filter(func(v:float):return v>20.).size()}}
		FileAccess.open(evidence.path_join("ride-load.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt))
		print("H06_RIDE_LOAD ",receipt.summary)
	await photograph("ascent-arrival")
	check(world.get_node("/root/SettingsManager").is_music_suppressed(),"test entry keeps background music suppressed")
	check(AudioServer.is_bus_mute(0),"background run keeps its private audio mute after restarting")
	current_scene.queue_free()
	await frames(8)
	var failed:=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(evidence.path_join("lab-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_BOSS_LAB checks=",checks.size()," failures=",failed.size())
	quit(0 if failed.is_empty() else 1)
