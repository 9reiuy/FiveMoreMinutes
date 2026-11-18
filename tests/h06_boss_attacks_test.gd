extends "res://tests/h06_crawler_chapter_test.gd"
const PATTERNS := preload("res://scripts/testing/h06_chapter/crawler_attacks.gd")
const PLAYER_SHOT := preload("res://scenes/entities/basic_projectile.tscn")
const RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
var director: PATTERNS
var log_events: Array[Dictionary] = []
var peak := 0.0

func events(kind: StringName) -> Array[Dictionary]:
	return log_events.filter(func(row:Dictionary):return row.kind==kind)

func tick(count: int = 1) -> void:
	for i in count:
		director.advance(1./60)
		peak=maxf(peak,world.blockout.mech.position.y)
		world._frame_encounter(world._feet(),1./60,null)
		world._update_camera_and_actor_projection(1./60)
		await physics_frame

func finish(limit: int = 1000) -> bool:
	for i in limit:
		if director.state==PATTERNS.State.RECOVER:return true
		await tick()
	print("ATTACK_NOT_FINISHED ",director.attack," state=",director.state," age=",director.age," spin=",director.spin_progress)
	return false

func reset_case(at: Vector2 = PLAN.BOSS_MARK+Vector2(0,7.6)) -> void:
	log_events.clear()
	director.cancel_projectiles()
	director.rig.reset()
	world.crawler_motion.teleport(BOSS_MARK_3D,0)
	world.crawler_motion.set_arena(world.boss)
	world._place_feet(at)
	world.player.maximum_health=1000
	world.player.current_health=1000
	world.player.invulnerability_left=0
	world.player.dash_invulnerability_left=0
	world.player.helmet_equipped=false
	world.player.movement_enabled=false
	world.player.set_scripted_locomotion(Vector2.ZERO,0)
	director.state=PATTERNS.State.REST
	director.wait=1000
	director.stomp_cooldown=0
	director.practice_single=false
	peak=0

func shot_at(from: Vector2, at: Vector2) -> WeakRef:
	var shot: Node2D = PLAYER_SHOT.instantiate()
	shot.position = from*32.
	RULES.setup_projectile(shot, from.direction_to(at), 9., 30.*32., 29.*32., &"player", world.player, &"assault_rifle")
	world.add_projectile(shot, world.player)
	shot.max_penetrations = 3
	shot.penetration_chance = 1.0
	return weakref(shot)

func check_barrage() -> void:
	var arena := PLAN.ARENA_DECK
	reset_case(Vector2(48.6,arena.position.y+arena.size.y/3.))
	director.begin(PATTERNS.Attack.BARRAGE)
	var rows := director.fx.salvo_rows
	var across_arena := rows.size()==3
	for row: MeshInstance3D in rows:
		var half: Vector2 = (row.material_override as ShaderMaterial).get_shader_parameter("half_size")
		across_arena = across_arena and row.visible and is_equal_approx(half.y*2,arena.size.x)
	check(across_arena and rows[0].position.z<rows[1].position.z and rows[1].position.z<rows[2].position.z,"all three marked rows span the full width of the real room")
	var maximum_in_flight := 0
	var gap_safe := false
	var moved_into_row := false
	for i in 180:
		await tick()
		maximum_in_flight=maxi(maximum_in_flight,director.rockets.size())
		var landed := events(&"barrage_row_impact").size()
		if landed==1 and not moved_into_row:
			gap_safe=world.player.current_health==1000
			world._place_feet(Vector2(48.6,arena.get_center().y))
			moved_into_row=true
		if landed==3:break
	var launches := events(&"barrage_row_fired")
	var impacts := events(&"barrage_row_impact")
	var correct_rows := launches.size()==3 and impacts.size()==3
	if correct_rows:
		for i in 3:
			correct_rows = correct_rows and launches[i].data.count==6 and impacts[i].data.row==i
			correct_rows = correct_rows and absf(impacts[i].data.time-launches[i].data.time-.72)<.025
	check(correct_rows and maximum_in_flight==18,"three fast six-round waves fly directly and strike from the back of the arena to the front")
	check(gap_safe and is_equal_approx(world.player.current_health,982.),"the gap is safe and standing in a marked row takes a single hit")
	check(rows.all(func(row:MeshInstance3D):return not row.visible) and director.rockets.is_empty(),"each row warning expires at impact and releases all projectile slots")
	var winds := events(&"windup")
	check(correct_rows and winds.size()>=2 and winds[1].data.time<impacts[-1].data.time,"full-room barrage also overlaps the next attack")
	await photograph("barrage-aftermath")

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	create_timer(100).timeout.connect(func():push_error("H06_BOSS_ATTACK_TIMEOUT");quit(2))
	await open_motion_chapter(CHAPTER.Save.ARENA)
	world.blockout.mech.show()
	world.crawler_motion.teleport(BOSS_MARK_3D,0)
	world.stage=CHAPTER.Stage.BOSS
	world._begin_crawler_boss()
	world.boss.set_physics_process(false)
	world.crawler_motion.set_physics_process(false)
	director=world.boss.attacks
	check(director!=null,"combat director runs in the actual elevator arena")
	director.event.connect(func(kind:StringName,data:Dictionary):log_events.append({"kind":kind,"data":data.duplicate(true)}))
	var wall:=StaticBody2D.new()
	wall.name="CannonTestWall"
	wall.collision_layer=4
	wall.collision_mask=0
	wall.position=(PLAN.BOSS_MARK+Vector2(0,6.))*32
	var collision:=CollisionShape2D.new()
	var box:=RectangleShape2D.new()
	box.size=Vector2(8,.4)*32
	collision.shape=box
	wall.add_child(collision)
	world.collision_root.add_child(wall)
	reset_case()
	await frames(2)
	var before_shot := director.origin()
	director.begin(PATTERNS.Attack.CANNON)
	var recoil:=false
	for i in 180:
		await tick()
		recoil=recoil or director.rig.barrel.position.z<director.rig.barrel_rest.z-.10
		if director.state==PATTERNS.State.RECOVER:break
	check(events(&"cannon_fired").size()==1 and recoil,"cannon firing drives the actual imported barrel backward and recovers")
	var body_kick := (before_shot-director.origin()).dot(director.shell_direction)
	check(body_kick>.30 and body_kick<.91 and director.motion.position.distance_to(director.origin()*MOTION.PIXELS)<.01,"the cannon kicks the real collision body backward with its mesh")
	print("H06_CANNON_KICK_METRES ",body_kick)
	var impacts:=events(&"cannon_impact")
	check(impacts.size()==1 and impacts[0].data.collider=="CannonTestWall" and absf((impacts[0].data.at as Vector2).y-PLAN.BOSS_MARK.y-5.80)<.08,"straight shell uses a real swept wall hit before exploding")
	check(world.player.current_health==1000,"wall blocks blast damage to the nearby player on its far side")
	await photograph("cannon-impact")
	reset_case()
	director.begin(PATTERNS.Attack.CANNON)
	for i in 100:
		if director.state==PATTERNS.State.ACTIVE:break
		await tick()
	var near_wall_origin := director.origin()
	var rear_foot_z := near_wall_origin.y
	for leg: Dictionary in director.motion.gait.legs:
		rear_foot_z=minf(rear_foot_z,leg.ankle.global_position.z)
	var rear_wall:=StaticBody2D.new()
	rear_wall.collision_layer=4
	var wall_edge := rear_foot_z-.48
	rear_wall.position=Vector2(38,wall_edge-.10)*MOTION.PIXELS
	var rear_shape:=CollisionShape2D.new()
	var rear_box:=RectangleShape2D.new()
	rear_box.size=Vector2(12,.20)*MOTION.PIXELS
	rear_shape.shape=rear_box
	rear_wall.add_child(rear_shape)
	world.collision_root.add_child(rear_wall)
	await frames(2)
	var rear_limit := 999.0
	for i in 40:
		if director.state==PATTERNS.State.RECOVER:break
		await tick()
		for leg: Dictionary in director.motion.gait.legs:
			rear_limit=minf(rear_limit,leg.ankle.global_position.z-.42)
	var wall_kick := (near_wall_origin-director.origin()).dot(director.shell_direction)
	print("H06_BLOCKED_KICK ",wall_kick," wall clearance=",rear_limit-wall_edge)
	check(director.state==PATTERNS.State.RECOVER and wall_kick<body_kick-.16 and rear_limit>=wall_edge-.05,"the recoil loses travel against the back wall and keeps the feet out of it")
	rear_wall.queue_free()
	await frames(2)
	world._clear_muzzle_and_burning_vfx()
	reset_case()
	director.begin(PATTERNS.Attack.LASER)
	var angular_steps: Array[float] = []
	var initial_yaw: float = world.blockout.mech.rotation.y
	var initial_position := director.origin()
	var max_body_yaw := 0.
	var max_body_shift := 0.
	var has_active_warning := false
	var seen_open_emitter := false
	var beam_matches_sweep := true
	var charge_start := 0.
	var charge_end := INF
	var charge_captured := false
	var charge_cleared := true
	var frames_of_laser: Array[Image] = []
	var record_laser := OS.get_environment("H06_RECORD_LASER")=="1"
	for i in 150:
		if director.state==PATTERNS.State.RECOVER:break
		var was_active := director.state==PATTERNS.State.ACTIVE
		var previous := director.spin_progress
		await tick()
		max_body_yaw=maxf(max_body_yaw,absf(angle_difference(initial_yaw,world.blockout.mech.rotation.y)))
		max_body_shift=maxf(max_body_shift,initial_position.distance_to(director.origin()))
		if director.state==PATTERNS.State.WINDUP and director.fx.charge_streams.visible:
			var source := director.fx.charge_ports.multimesh.get_instance_transform(0).origin
			var stream := director.fx.charge_streams.multimesh.get_instance_transform(0).origin
			charge_start = maxf(charge_start,stream.distance_to(source))
			charge_end = minf(charge_end,stream.distance_to(source))
			if not charge_captured and director.age>=.27:
				charge_captured = true
				await photograph("laser-charge")
		if was_active:
			angular_steps.append(director.spin_progress-previous)
			has_active_warning = has_active_warning or director.fx.lane.visible
			charge_cleared = charge_cleared and not director.fx.charge_streams.visible and not director.fx.charge_light.visible
			if director.fx.beam.visible:
				seen_open_emitter = seen_open_emitter or (director.rig.lid_open>.99 and director.fx.core.visible)
				var laser_axis := director.fx.beam.basis.y.normalized()
				var angle := atan2(laser_axis.x,laser_axis.z)
				beam_matches_sweep = beam_matches_sweep and absf(angle_difference(angle,initial_yaw+director.spin_progress))<.02
	var spins := events(&"laser_complete")
	check(charge_captured and charge_start>3.7 and charge_end<.31 and charge_cleared,
		"red energy contracts into the actual port and clears when the beam starts")
	check(spins.size()==1 and spins[0].data.duration<=.57 and absf(spins[0].data.rotation-TAU)<.02,"single beam sweeps the full circle in under .57 seconds")
	check(angular_steps.size()>29 and angular_steps[27]>angular_steps[15] and angular_steps[15]>angular_steps[4],"fast laser sweep still accelerates")
	check(seen_open_emitter and beam_matches_sweep and max_body_shift<.01 and max_body_yaw<.01,"canopy opens and the actual beam rotates with the chassis held in place")
	print("H06_SINGLE_SWEEP ",spins," yaw drift=",max_body_yaw," shift=",max_body_shift)
	check(not has_active_warning,"ground range is hidden throughout the active laser rotation")
	check(world.player.current_health==1000,"laser stops at the wall and cannot damage the player behind it")
	check(not director.fx.beam.visible and not director.fx.lane.visible,"laser and ground warning disappear after the attack")
	wall.queue_free()
	await frames(3)
	if record_laser:
		reset_case()
		director.begin(PATTERNS.Attack.LASER)
		for i in 45:
			await tick(2)
			await RenderingServer.frame_post_draw
			frames_of_laser.append(display.world_viewport.get_texture().get_image())
			if director.state==PATTERNS.State.RECOVER and director.age>.12: break
	reset_case(PLAN.BOSS_MARK+Vector2(0,10.))
	director.begin(PATTERNS.Attack.MISSILES)
	var positions:Array[float]=[10.,8.,11.,7.3,9.,5.5]
	var max_elevation:=0.
	var previous_points := {}
	var continuous_flight := true
	var independent_warning := false
	for i in 400:
		if director.state==PATTERNS.State.WINDUP and director.attack==PATTERNS.Attack.MISSILES:
			var next:=mini(5,director.targets.size())
			world._place_feet(PLAN.BOSS_MARK+Vector2(0,positions[next]))
		await tick()
		max_elevation=maxf(max_elevation,director.rig.elevation)
		for flight: PATTERNS.Rocket in director.rockets:
			var point: Vector3=director.fx.missiles[flight.slot].position
			var id := flight.get_instance_id()
			if previous_points.has(id):continuous_flight=continuous_flight and point.distance_to(previous_points[id])>.008
			previous_points[id]=point
			if director.attack != PATTERNS.Attack.MISSILES:
				independent_warning=independent_warning or director.fx.marks[flight.marker].visible
		if events(&"missile_impact").size()==6:break
	var locks := events(&"lock")
	var launches := events(&"missile_launched")
	check(locks.size()==6 and launches.size()==6 and events(&"missile_impact").size()==6,"exactly six player locks, launches and impacts complete")
	var interleaved := locks.size()==6 and launches.size()==6
	if interleaved:
		for i in 5:interleaved = interleaved and launches[i].data.time < locks[i+1].data.time
	check(interleaved,"each of the first five missiles is already airborne before the next lock marker appears")
	check(max_elevation>.99 and events(&"missile_launched").all(func(row:Dictionary):return row.data.elevation>.99),"launcher is physically raised before the first missile leaves a tube")
	var hits:=events(&"missile_impact")
	check(continuous_flight and hits.size()==6 and hits.all(func(row:Dictionary):return row.data.flight<.805),"a continuous arc hits each lock in under .81 seconds with no holding phase")
	check(launches.size()==6 and hits.size()==6 and hits.all(func(row:Dictionary):return row.data.at==launches[row.data.index].data.target),"missiles hit the recorded locks instead of continuing to track the player")
	var next_windup := events(&"windup").filter(func(row:Dictionary):return row.data.attack!=&"missiles")
	check(independent_warning and hits.size()==6 and not next_windup.is_empty() and next_windup[0].data.time<hits[-1].data.time,"the next attack starts before impact and preserves the outstanding missile warning")
	await photograph("missile-aftermath")
	await check_barrage()
	reset_case(PLAN.BOSS_MARK+Vector2(5.5,-.5))
	director.begin(PATTERNS.Attack.SLAM)
	var windup_time := director.elapsed
	var saw_flight := false
	var valid_range := false
	var peak_time := 0.
	for i in 140:
		await tick()
		if world.crawler_motion.jump==MOTION.Jump.FLIGHT:
			saw_flight=true
			peak_time=director.elapsed-windup_time
			var mark_material := director.fx.marks[0].material_override as ShaderMaterial
			var half: Vector2 = mark_material.get_shader_parameter("half_size")
			valid_range = is_equal_approx(half.x,4.6)
			world._place_feet(director.aim+Vector2.UP*3.5)
			break
	check(await finish(400),"charged jump runs through impact suspension recovery")
	check(saw_flight and peak_time<=.86 and valid_range,"combat takeoff is approximately half as long and the radius display is widened to 4.6 metres")
	check(absf(director.origin().x-38)>3.5,"the real jump can land laterally without turning the chassis first")
	check(peak>2.5 and events(&"slam_impact").size()==1,"big jump gains actual height and only damages on its single landing impact")
	check(director.fx.smoke_bursts>0 and world.player.current_health<1000,"larger landing attack damages a player 3.5 metres away and emits smoke")
	check(world.crawler_motion.gait.debug_state().all(func(row:Dictionary):return row.error<.035),"slam leaves the original six legs connected after landing")
	await photograph("slam-landing")
	reset_case(PLAN.BOSS_MARK+Vector2(0,10.3))
	director.begin(PATTERNS.Attack.CHARGE)
	var hp:float=world.player.current_health
	check(await finish(260),"charged rush completes and returns to a punishable recovery")
	check(events(&"charge_contact").size()==1 and world.player.current_health<hp,"rush uses actual player collision and applies one contact hit")
	check(director.charge_distance>4.0,"rush covers real ground at substantially more than the idle walking pace")
	check(events(&"charge_started").size()==1 and events(&"charge_started")[0].data.time-events(&"windup")[0].data.time<=.524,"charge starts in approximately half a second")
	await photograph("charge-contact")
	reset_case(PLAN.BOSS_MARK+Vector2(2.8,3.2))
	await tick(2)
	check(director.attack==PATTERNS.Attack.STOMP and director.state==PATTERNS.State.WINDUP,"getting close during a ready period triggers a single-foot stomp")
	var lifted := 0.
	for i in 30:
		if director.state==PATTERNS.State.RECOVER:break
		await tick()
		if director.stomp_leg>=0:
			lifted = maxf(lifted,world.crawler_motion.gait.legs[director.stomp_leg].ankle.global_position.y)
	check(lifted>.7 and events(&"stomp_impact").size()==1 and world.player.current_health<1000,"selected foot visibly lifts, plants and damages at its actual contact point")
	reset_case(PLAN.BOSS_MARK+Vector2(0,9.1))
	await tick(27)
	check(absf(director.origin().x-38)>.35 and absf(world.blockout.mech.rotation.y)<.07,"regular movement includes a real sideways step with the original facing")
	reset_case(PLAN.BOSS_MARK+Vector2(0,9.1))
	world.player.critical_chance=0.0
	var boss_hp: float=world.boss.current_health
	var front := PLAN.BOSS_MARK+Vector2(0,8.5)
	var rear := PLAN.BOSS_MARK-Vector2(0,5.7)
	shot_at(front,PLAN.BOSS_MARK)
	shot_at(PLAN.BOSS_MARK+Vector2(7,0),PLAN.BOSS_MARK)
	for i in 38: await physics_frame
	check(not director.fx.shield.is_shield_active() and events(&"shield_block").is_empty(),"full-health H06 has no active shield")
	check(is_equal_approx(world.boss.current_health,boss_hp-1.8),"a real nine-damage shot to either front or side inflicts exactly one tenth damage")
	boss_hp=world.boss.current_health
	world._place_feet(rear)
	for i in 36:
		world._frame_encounter(world._feet(),1./60,null)
		world._update_camera_and_actor_projection(1./60)
		await physics_frame
	shot_at(rear,PLAN.BOSS_MARK)
	for i in 28: await physics_frame
	print("H06_REAR_HIT hp=",world.boss.current_health," before=",boss_hp," blocked=",events(&"shield_block").size())
	check(is_equal_approx(world.boss.current_health,boss_hp-9.),"a real swept shot through the rear grille inflicts full damage")
	var shield_at: float = world.boss.MAX_HEALTH*PATTERNS.SHIELD_HEALTH
	world.boss.take_damage(world.boss.current_health-shield_at-.01)
	check(not director.fx.shield.is_shield_active(),"the shield stays off above two thirds health")
	world.boss.take_damage(world.boss.current_health-shield_at)
	check(director.fx.shield.is_shield_active() and not director.burst_pending,
		"the blue field activates at exactly two thirds health before the separate laser phase")
	world.boss.take_damage(world.boss.current_health-80.)
	check(not director.burst_pending and director.fx.shield.is_shield_active(),
		"exactly half health keeps the laser phase pending and the shield on")
	world.boss.take_damage(1.)
	check(director.burst_pending and director.fx.shield.is_shield_active(),"crossing below half health still arms the six-beam attack")
	var shield = director.fx.shield
	var record_shield := OS.get_environment("H06_RECORD_SHIELD")=="1"
	world._place_feet(front+Vector2(0,.1))
	for i in 26:
		world._frame_encounter(world._feet(),1./60,null)
		world._update_camera_and_actor_projection(1./60)
		await physics_frame
	var armored_hp: float = world.boss.current_health
	var blocked := shot_at(front,PLAN.BOSS_MARK)
	for i in 38: await physics_frame
	check(blocked.get_ref()==null and events(&"shield_block").size()==1 and is_equal_approx(world.boss.current_health,armored_hp-.9),"phase two shield stops penetration and allows one tenth damage to the armor")
	var front_hit := Vector3(shield.impacts[0].x,shield.impacts[0].y,shield.impacts[0].z)
	check(is_equal_approx(front_hit.length(),1.) and front_hit.z>.85,
		"the blocked front shot places its flash on the surface in front of H06")
	world._place_feet(rear)
	for i in 36:
		world._frame_encounter(world._feet(),1./60,null)
		world._update_camera_and_actor_projection(1./60)
		await physics_frame
	armored_hp=world.boss.current_health
	shot_at(rear,PLAN.BOSS_MARK)
	await frames(25)
	check(is_equal_approx(world.boss.current_health,armored_hp-9.) and events(&"shield_block").size()==1,"phase two rear weak point remains unshielded and takes full damage")
	world._place_feet(front+Vector2(0,.1))
	for i in 24:
		world._frame_encounter(world._feet(),1./60,null)
		world._update_camera_and_actor_projection(1./60)
		await physics_frame
	if record_shield: await photograph("energy-field")
	shot_at(PLAN.BOSS_MARK+Vector2(-4.8,7.2),PLAN.BOSS_MARK+Vector2(-.5,0))
	shot_at(PLAN.BOSS_MARK+Vector2(4.1,7.6),PLAN.BOSS_MARK+Vector2(.35,0))
	var shield_frames: Array[Image] = []
	for i in 21:
		await frames(2)
		if record_shield:
			await RenderingServer.frame_post_draw
			shield_frames.append(display.world_viewport.get_texture().get_image())
	check(events(&"shield_block").size()==3 and shield.next_impact==3
		and shield.impacts[1].x*shield.impacts[2].x<0.
		and absf(shield.impacts[1].w-shield.impacts[2].w)<.17,
		"two real hits retain separate simultaneous ripples on opposite sides of the field")
	var open_height := 0.
	var six_beams := false
	var even_spacing := false
	var first_heading := Vector3.ZERO
	var beam_angle := 0.
	var burst_origin := director.origin()
	var burst_heading: float = world.blockout.mech.rotation.y
	var body_static := true
	var seen_six_charge_ports := false
	for i in 160:
		await tick()
		open_height=maxf(open_height,director.rig.upper_body.position.y-director.rig.lid_rest.y)
		body_static=body_static and burst_origin.distance_to(director.origin())<.01 and absf(angle_difference(burst_heading,world.blockout.mech.rotation.y))<.01
		if director.fx.charge_ports.visible and director.fx.charge_ports.multimesh.visible_instance_count==6:
			seen_six_charge_ports = true
		if director.fx.beam.visible:
			var axis := director.fx.beam.basis.y.normalized()
			if first_heading==Vector3.ZERO:first_heading=axis
			beam_angle=maxf(beam_angle,first_heading.angle_to(axis))
		if not six_beams and director.fx.beam.visible and director.fx.extra_beams.all(func(beam:MeshInstance3D):return beam.visible):
			six_beams=true
			var beams: Array[MeshInstance3D]=[director.fx.beam]
			beams.append_array(director.fx.extra_beams)
			even_spacing = true
			for j in 6:
				var a:=beams[j].basis.y.normalized()
				var b:=beams[(j+1)%6].basis.y.normalized()
				even_spacing = even_spacing and absf(a.dot(b)-.5)<.02
			if even_spacing:await photograph("six-way-burst")
		if events(&"burst_fired").size()==1 and director.state==PATTERNS.State.REST:break
	check(open_height>.8 and seen_six_charge_ports and six_beams and even_spacing,"below half health charges six ports then fires six simultaneous 60-degree beams")
	var bursts := events(&"burst_complete")
	check(body_static and beam_angle>.90 and bursts.size()==1 and bursts[0].data.duration<=.36
		and is_equal_approx(bursts[0].data.rotation,TAU/6.),"the six fast beams cover one full turn in their respective sectors")
	check(director.rig.lid_open==0.0 and not director.fx.core.visible and not director.fx.beam.visible,"the phase attack closes the lid and clears the complete laser burst")
	world.boss.take_damage(1.)
	await tick(35)
	check(events(&"burst_fired").size()==1 and director.burst_used and not director.burst_pending,"lower health does not repeat the once-per-fight six-way attack")
	reset_case()
	director.begin(PATTERNS.Attack.MISSILES)
	await tick(64)
	var effects_ref:WeakRef=weakref(director.fx)
	world.boss.take_damage(10000)
	await frames(4)
	check(director.stopped and effects_ref.get_ref()==null and world.stage==CHAPTER.Stage.EXIT,"death during a salvo cancels missiles, warnings and damage before opening the lift")
	var body_ref:WeakRef=weakref(world.crawler_motion)
	display.queue_free()
	await frames(8)
	check(body_ref.get_ref()==null,"world exit cleans the attack director and physical mech")
	if record_laser:
		var folder := evidence.path_join("laser")
		DirAccess.make_dir_recursive_absolute(folder)
		for i in frames_of_laser.size():
			frames_of_laser[i].save_png(folder.path_join("%03d.png"%i))
	if record_shield:
		var folder := evidence.path_join("shield")
		DirAccess.make_dir_recursive_absolute(folder)
		for i in shield_frames.size():
			shield_frames[i].save_png(folder.path_join("%03d.png"%i))
	var failures:=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(evidence.path_join("attack-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"events":log_events,"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)},"\t"))
	print("H06_ATTACK_RESULT checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
