extends "res://tests/h06_boss_attacks_test.gd"

const CARGO := preload("res://scripts/testing/h06_chapter/crawler_cargo.gd")
var cargo: CARGO
var record := false
var cargo_frames: Array[Image] = []

func prepare_match(random_seed: int) -> void:
	await open_motion_chapter(CHAPTER.Save.ARENA,true,true)
	world.blockout.mech.show()
	world.crawler_motion.teleport(BOSS_MARK_3D,0.)
	world._begin_crawler_boss()
	world.blockout.inclined_lift.start_ascent()
	world.boss.set_physics_process(false)
	world.crawler_motion.set_physics_process(false)
	world.player.set_physics_process(false)
	director = world.boss.attacks
	cargo = director.cargo
	cargo.random.seed = random_seed
	reset_case(PLAN.BOSS_MARK+Vector2(0,4.9))
	world.player.critical_chance = 0.
	director.event.connect(func(kind: StringName,data: Dictionary):
		log_events.append({"kind":kind,"data":data.duplicate(true)}))

func move_mech(at: Vector2, yaw: float = 0.) -> void:
	world.crawler_motion.teleport(Vector3(at.x,0.,at.y),yaw)
	world.boss.position = world.crawler_motion.position

func arm_drops() -> void:
	var phase_hp: float = world.boss.MAX_HEALTH*PATTERNS.SHIELD_HEALTH
	world.boss.take_damage(world.boss.current_health-phase_hp+.01)
	director.practice_single = true

func observe_stun_sources() -> void:
	var lamps: StandardMaterial3D = world.boss.red_lamp_material
	var full_light := lamps.emission_energy_multiplier if lamps!=null else 0.0
	var bound_surfaces := 0
	for mesh: MeshInstance3D in world.boss.model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var authored := mesh.mesh.surface_get_material(i)
			if authored.resource_name=="M_Emissive_Red" and mesh.get_surface_override_material(i)==lamps and authored!=lamps:
				bound_surfaces += 1
	check(full_light>0.0 and bound_surfaces==4,"the stripe, two sensors and launcher share a boss-local lamp material")
	var untouched := cargo.drops.all(func(drop: CARGO.Drop):return drop.body.collision_layer==0 and not drop.model.visible)
	check(not cargo.released and untouched and not director.fx.shield.is_shield_active(),
		"two prebuilt containers and the blue shield are dormant at full health")
	arm_drops()
	var first := cargo.drops[0]
	var second := cargo.drops[1]
	check(cargo.released and director.fx.shield.is_shield_active() and not director.burst_pending
		and PLAN.ARENA_DECK.encloses(first.rect) and PLAN.ARENA_DECK.encloses(second.rect)
		and not first.rect.grow(3.).intersects(second.rect),
		"two-thirds health schedules exactly two separated drops within the platform and raises the shield")
	var first_at := first.rect.get_center()
	world._place_feet(first_at+Vector2(0.,4.85))
	move_mech(first_at)
	for beat in 42:
		await tick(2)
		if record:
			await RenderingServer.frame_post_draw
			cargo_frames.append(display.world_viewport.get_texture().get_image())
		if beat==5:
			check(first.warning.visible and first.model.visible and first.body.collision_layer==0
				and not second.warning.visible,
				"the first overhead load and its floor warning precede any solid collision")
		if director.state==PATTERNS.State.STUNNED: break
	check(first.phase==CARGO.Phase.BROKEN and events(&"cargo_broken").size()==1
		and events(&"cargo_broken")[0].data.source==&"cargo_fall"
		and director.state==PATTERNS.State.STUNNED
		and director.stun_left>=PATTERNS.STUN_DURATION-1./60.-.00001
		and not director.fx.shield.is_shield_active(),
		"a real falling load collides with the H06 hull, breaks and disables the shield for three seconds")
	await frames(15)
	check(lamps!=null and is_equal_approx(lamps.emission_energy_multiplier,full_light*.18),
		"stun visibly dims all the red lamps on the real imported model")
	if record: await photograph("cargo-stun-from-above")
	check(not director.begin(PATTERNS.Attack.CANNON) and not director.shell_active and director.rockets.is_empty(),
		"stunned H06 cannot start attacks or retain a pending projectile")
	var rear: Vector2 = director.motion.to_global(Vector2(0.,-1.9)*32.)
	world.boss.take_damage(25.,rear,1.,&"player_projectile_assault_rifle")
	world.boss.take_damage(2.,rear,1.,&"enemy_projectile_basic")
	world.boss.take_damage(25.,rear,1.,&"player_projectile_mp5")
	check(is_equal_approx(director.stun_damage,50.) and director.state==PATTERNS.State.STUNNED
		and not director.fx.shield.is_shield_active(),
		"only player health loss counts and exactly 50 damage keeps H06 stunned")
	world.boss.take_damage(1.,rear,1.,&"player_projectile_basic")
	check(director.state!=PATTERNS.State.STUNNED and director.fx.shield.is_shield_active()
		and events(&"cargo_stun_finished").size()==1 and events(&"cargo_stun_finished")[0].data.reason==&"damage",
		"the first point over 50 ends the stun and reactivates the shield immediately")
	await frames(16)
	check(lamps!=null and is_equal_approx(lamps.emission_energy_multiplier,full_light),
		"recovering from accumulated damage brings the red lamps back to full brightness")
	director.wait = 1000.
	for frame in 176:
		if second.phase==CARGO.Phase.LANDED: break
		await tick()
	check(second.phase==CARGO.Phase.LANDED and (second.body.collision_layer&4)!=0
		and not second.warning.visible and events(&"cargo_warning").size()==2,
		"the second load settles with real cover, after the first load's separate fall")
	if record: await photograph("cargo-landed-cover")
	var target := second.rect.get_center()
	var forward := Vector2.RIGHT if target.x>38. else Vector2.LEFT
	var inset := PLAN.ARENA_DECK.grow(-4.8)
	var start := (target-forward*8.).clamp(inset.position,inset.end)
	var bearing := start.direction_to(target)
	var player_area := PLAN.ARENA_DECK.grow(-.72)
	move_mech(start,atan2(bearing.x,bearing.y))
	world._place_feet((target+bearing*3.).clamp(player_area.position,player_area.end))
	await tick(2)
	check(director.begin(PATTERNS.Attack.CHARGE),"the real charge starts with the second container in its path")
	for frame in 130:
		if director.state==PATTERNS.State.STUNNED: break
		await tick()
	check(second.phase==CARGO.Phase.BROKEN and second.body.collision_layer==0
		and events(&"cargo_stun").size()==2 and events(&"cargo_stun")[-1].data.source==&"cargo_charge"
		and director.origin().distance_to(start)>.25 and not director.fx.shield.is_shield_active(),
		"chassis movement strikes the solid container, shatters it and stuns H06")
	if record:
		await frames(14)
		await photograph("cargo-charge-stun")
	await tick(179)
	check(director.state==PATTERNS.State.STUNNED and not director.fx.shield.is_shield_active(),
		"an undamaged stun lasts through the last frame before three seconds")
	await tick(1)
	check(director.state!=PATTERNS.State.STUNNED and director.fx.shield.is_shield_active()
		and events(&"cargo_stun_finished")[-1].data.reason==&"timer",
		"the shield returns just as the full three seconds end")
	var loot: Array[Node] = world.world_weapon_root.get_children()
	var is_ranged_loot := loot.all(func(item: Node):
		return (item.is_in_group(&"world_weapon_pickups") and item.get("weapon_id") in CARGO.FIREARMS
			and item.has_meta(&"depth_visual_bridge")))
	check(loot.size()==2 and is_ranged_loot,
		"each destroyed container leaves exactly one real rendered ranged weapon pickup")
	if not loot.is_empty():
		var pickup: Node2D = loot[0]
		var weapon_id: String = pickup.get("weapon_id")
		world._place_feet(pickup.global_position/32.)
		await tick(2)
		world._swap_world_weapon(pickup)
		check(world.player.ranged_weapon_id==weapon_id,"the cargo weapon equips through the normal pickup action")

func observe_ranged_breakage() -> void:
	arm_drops()
	var first := cargo.drops[0]
	var second := cargo.drops[1]
	var safe := PLAN.BOSS_MARK+Vector2(0.,6.65)
	var best_clearance := 0.
	for offset: Vector2 in [Vector2(-8.,6.5),Vector2(7.,6.5),Vector2(-8.,-3.5),Vector2(7.,-3.5),Vector2(0.,6.5)]:
		var candidate := PLAN.BOSS_MARK+offset
		var clearance := minf(candidate.distance_to(first.rect.get_center()),candidate.distance_to(second.rect.get_center()))
		if clearance>best_clearance:
			best_clearance = clearance
			safe = candidate
	move_mech(safe)
	world._place_feet(safe+Vector2(0.,3.6))
	for frame in 188:
		if first.phase==CARGO.Phase.LANDED and second.phase==CARGO.Phase.LANDED:break
		await tick()
	check(first.phase==CARGO.Phase.LANDED and second.phase==CARGO.Phase.LANDED,
		"another seed drops two physical covers at different platform positions")
	world._place_feet(Vector2(first.rect.end.x+.46,first.rect.get_center().y))
	check(director.begin(PATTERNS.Attack.MISSILES),"the real missile sequence aims at the container vicinity")
	for frame in 180:
		if first.phase==CARGO.Phase.BROKEN: break
		await tick()
	check(first.phase==CARGO.Phase.BROKEN and events(&"cargo_broken")[0].data.source==&"h06_missile"
		and events(&"cargo_stun").is_empty() and director.fx.shield.is_shield_active(),
		"missile splash breaks container cover and leaves normal boss attacks active")
	director.cancel_projectiles()
	check(director.begin(PATTERNS.Attack.LASER),"the normal sweep begins with the other crate intact")
	for frame in 105:
		if second.phase==CARGO.Phase.BROKEN:break
		await tick()
	check(second.phase==CARGO.Phase.BROKEN and events(&"cargo_broken").size()==2
		and events(&"cargo_broken")[-1].data.source==&"h06_laser" and events(&"cargo_stun").is_empty(),
		"the fast laser sweep hits and breaks its own cover without stunning H06")
	if record: await photograph("cargo-broken-loot")
	world.boss.take_damage(1000.)
	await tick(24)
	check(world.boss.dead and world.stage==CHAPTER.Stage.EXIT and director.stopped
		and cargo.drops.all(func(drop:CARGO.Drop):return not drop.warning.visible),
		"boss defeat leaves the freight deck on its normal arrival path without any cargo warning")
	var lamps: StandardMaterial3D = world.boss.red_lamp_material
	check(lamps!=null and lamps.emission_energy_multiplier<.06 and lamps.albedo_color.r<.04,
		"the defeated boss remains barely lit through the existing arrival animation")
	if record: await photograph("cargo-dim-on-defeat")

func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self)
	evidence = OS.get_environment("FORKLIFT_EVIDENCE")
	create_timer(120).timeout.connect(func():push_error("H06_CARGO_TIMEOUT");quit(2))
	record = OS.get_environment("H06_RECORD_CARGO")=="1"
	await prepare_match(12296)
	await observe_stun_sources()
	var first_events := log_events.duplicate(true)
	var first_positions := cargo.drops.map(func(drop:CARGO.Drop):return drop.rect.get_center())
	var old_cargo: WeakRef = weakref(cargo)
	var old_body: WeakRef = weakref(cargo.drops[1].body)
	display.queue_free()
	await frames(15)
	check(old_cargo.get_ref()==null and old_body.get_ref()==null,"leaving the arena releases cargo bodies and visuals")
	await prepare_match(71871)
	check(not cargo.released and world.world_weapon_root.get_child_count()==0,
		"a new arena starts with no old pickups, active drops or stun")
	await observe_ranged_breakage()
	check(first_positions!=cargo.drops.map(func(drop:CARGO.Drop):return drop.rect.get_center()),
		"two different random seeds choose different valid landing positions")
	var second_events := log_events.duplicate(true)
	display.queue_free()
	await frames(12)
	if record:
		var folder := evidence.path_join("cargo-fall")
		DirAccess.make_dir_recursive_absolute(folder)
		for i in cargo_frames.size(): cargo_frames[i].save_png(folder.path_join("%03d.png"%i))
	var failures := checks.filter(func(row:Dictionary):return not row.pass)
	var result := {"pid":OS.get_process_id(),"checks":checks,"fall_and_charge":first_events,
		"ranged":second_events,"renderer":RenderingServer.get_current_rendering_method(),
		"audio":AudioServer.get_driver_name(),"muted":AudioServer.is_bus_mute(0)}
	FileAccess.open(evidence.path_join("cargo-result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("H06_CARGO_RESULT checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
