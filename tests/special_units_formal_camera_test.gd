extends SceneTree
const OUT="res://.runtime/special_units_20261023"
var main: Node
var world: Node
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=8) -> void:
	for i in n: await process_frame
func settle() -> void:
	var end:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<end: await process_frame
	await frames(15)
func shot(label: String) -> void:
	await frames(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func death_stages(container: Node,label: String) -> void:
	var effect: Node
	for child in container.get_children():
		if child.get_meta(&"unit_death_effect",false): effect=child
	check(is_instance_valid(effect),label+" has floor-owned visual death animation")
	if not is_instance_valid(effect): return
	effect.set_process(false)
	effect._process(.3 if effect.flying else .2)
	await shot(label+"_tumble")
	check(effect.model.visible and not effect.burst_started,label+" original model is visible during tumble")
	effect._process(.36 if effect.flying else .23)
	if is_instance_valid(effect.elemental):
		effect.elemental.effects.set_process(false)
		for i in 6:effect.elemental.effects.step(1.0/60.0)
	await shot(label+"_burst")
	check(effect.burst_started and is_instance_valid(effect.elemental),label+" renders shared particle explosion and smoke")
	effect._process(.55)
	if is_instance_valid(effect.elemental):
		for i in 33:effect.elemental.effects.step(1.0/60.0)
	await shot(label+"_smoke")
	if is_instance_valid(effect.elemental):effect.elemental.effects.set_process(true)
	effect.set_process(true)
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true); settings.set_palette_enabled(true)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state.tutorial_completed=true
	seed(120); main._show_dream("basic"); await settle()
	world=main._supported_dream_world
	var end:=Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<end: await process_frame
	world.player.maximum_health=1000000; world.player.current_health=1000000; world.player.dash_invulnerability_left=3600
	world.player.set_physics_process(false)
	var robots: Array=[]
	for child in world.enemy_root.get_children():
		if child.get_meta(&"content_kind","")==&"hotel_robot": robots.append(child)
	check(robots.size()==1,"Normal Main generates one delivery robot without a preview shortcut")
	check(world._exterior_drone_root.get_child_count()>0 and world._exterior_drone_root.get_child_count()<=2,"Normal Main generates window patrol drones")
	if robots.is_empty() or world._exterior_drone_root.get_child_count()==0: main.free(); quit(1); return
	var robot: Node=robots[0]
	world.player.global_position=robot.global_position+Vector2(0,90)
	world._update_camera_and_actor_projection(0.0)
	await frames(60)
	await shot("robot_palette")
	check(is_instance_valid(robot.visual) and robot.visual._model.is_visible_in_tree(),"Robot uses existing 3D model in formal world")
	check(is_equal_approx(robot.visual._model.scale.x,1.6) and robot.health_bar_3d==null,"Formal robot is two-thirds size without a health bar")
	robot.take_damage(1,world.player.global_position)
	robot.visual.hit_flash.set_process(false)
	await shot("robot_hit_white")
	check(robot.visual._model.get_node("Body").material_override==robot.visual.hit_flash.white,"Actual camera uses robot white hit material")
	robot.visual.hit_flash._process(.2)
	var sides: Array=[]
	for side in [-1.0,1.0]: sides.append(robot.visual.gameplay_muzzle(side))
	check(sides[0].distance_to(sides[1])>20.0,"Rendered side guns map to separate gameplay muzzles")
	robot.set_physics_process(false)
	robot.deploy=1.0; robot._face(robot.global_position.direction_to(world.player.global_position))
	for index in 2:
		var before: Array=get_nodes_in_group(&"dream_projectiles")
		robot._reload_left=0.0; robot._fire(robot.global_position.direction_to(world.player.global_position))
		var emitted: Array=[]
		for item in get_nodes_in_group(&"dream_projectiles"):
			if not before.has(item): emitted.append(item)
		check(emitted.size()==1,"A side-gun shot emits one real bullet")
		if not emitted.is_empty():
			var item: Node=emitted[0]; item.set_physics_process(false)
			check(item.get_meta(&"shot_visual_origin").distance_to(robot.visual.muzzle_node(robot.last_shot_side).global_position)<.01,"Bullet capture starts at rendered gun barrel")
		await shot("robot_gun_%d" % index)
	robot._magazine_primed=false; robot._reload_left=0
	robot._aiming=true; robot._aim_elapsed=.1; robot._aim_target=world.player.global_position
	await shot("robot_aim_early")
	robot._aim_elapsed=.45
	await shot("robot_aim_late")
	check(world.floor_root.get_node("EnemyAimTelegraph").last_drawn_enemy_ids.has(robot.get_instance_id()),"Actual camera draws the robot initial red line")
	robot._aiming=false
	var muzzle_effects:=preload("res://scripts/dream/burning_effects.gd").install(world)
	muzzle_effects.effects.set_process(false)
	robot.global_position=world.player.global_position+Vector2(-30,35)
	robot.visual._process(0)
	robot.visual.flash_muzzle(-1.0); robot.visual._process(0); robot.visual.set_process(false)
	muzzle_effects.effects.step(.025)
	await shot("robot_muzzle")
	check(muzzle_effects.effects.particles.any(func(p: Dictionary)->bool:return int(p.kind)==2 and bool(p.burst)),"Formal muzzle includes hot spray sparks")
	muzzle_effects.effects.set_process(true)
	robot.visual.set_process(true)
	robot.global_position=world.player.global_position+Vector2(-30,35)
	robot.take_damage(robot.hp-25.0,world.player.global_position)
	var burning:=preload("res://scripts/dream/burning_effects.gd").install(world)
	burning.set_physics_process(false)
	check(burning.burning.has(robot.get_instance_id()),"Low-health formal robot ignites")
	await frames(35)
	for i in 60:burning.effects.step(1.0/60.0)
	await shot("robot_low_health_fire")
	check(burning.effects.preserve_flame_colors,"Formal flames use palette exemption")
	var human: Node
	for candidate in world.enemy_root.get_children():
		if candidate.has_method("set_burning_panic") and not candidate.dead and not candidate.boss_variant:
			human=candidate;break
	if is_instance_valid(human):
		human.global_position=world.player.global_position+Vector2(32,-8)
		human.set_physics_process(false);human.equip_weapon("assault_rifle")
		burning.ignite(human)
		check(human.burning_panic and human.held_weapon_id.is_empty(),"Formal human enemy drops gun on ignition")
		await shot("human_burning_panic")
	robot.defeat_by_parry(world.player.global_position)
	burning.advance(0.0)
	await death_stages(world._hotel_robot_visual_root,"robot_death")
	var drone: Node=world._exterior_drone_root.get_child(0)
	var drone_start: Vector3=drone.global_position
	var local: Vector3=world.to_local(drone.global_position)
	world.player.global_position=Vector2(local.x,local.z)*32.0+drone.inward_normal*100.0
	world._update_camera_and_actor_projection(0.0)
	await frames(60)
	await shot("drone_palette")
	check(drone.MAX_HP==100 and drone.hp>0 and drone.hp<=100 and drone._proxy.is_in_group(&"dream_enemies"),"Drone remains a live damageable enemy with 100 HP maximum during combat capture")
	check(is_equal_approx(drone._body.scale.x,1.3*2.0/3.0) and drone.health_bar()==null,"Formal drone is two-thirds size without a health bar")
	drone.take_damage(1,world.player.global_position); drone.hit_flash.set_process(false)
	await shot("drone_hit_white")
	check(drone._body.get_node("Body").material_override==drone.hit_flash.white,"Actual camera uses drone white hit material")
	drone.hit_flash._process(.2)
	drone.take_damage(drone.hp-25.0,world.player.global_position)
	check(burning.burning.has(drone.get_instance_id()),"Low-health drone also ignites")
	for i in 45:burning.effects.step(1.0/60.0)
	await shot("drone_low_health_fire")
	check(drone._muzzle_2d.global_position.distance_to(drone.boundary_2d+drone.inward_normal*14.4)>16,"Drone no longer fires from fake indoor window point")
	for index in 8:
		await frames(4); await shot("patrol_%02d" % index)
		local=world.to_local(drone.global_position)
		check(not world.floor_cells.has(Vector2i(Vector2(local.x,local.z).round())),"Moving drone stays outside building")
	check(drone.patrol_points.size()>1 and drone_start.distance_to(drone.global_position)>.02,"Drone moves along actual window run")
	settings.set_setting(&"pixelation_enabled",false); settings.set_palette_enabled(false)
	await shot("drone_native")
	drone.set_physics_process(false); drone._spot_elapsed=.4; drone._aim_target=world.player.global_position
	# Freeze the recoil pose before measuring the beam; physics aiming is
	# disabled for this capture and otherwise a later render tick moves it.
	drone.body_recoil=0.0;drone._process(1.0)
	drone._apply_facing(); drone._sync_2d(); drone._set_light(5.2)
	await shot("drone_aim")
	var expected_beam: Vector3=world.get_gameplay_world_position(world.player.global_position,.35)-drone._spot_light.global_position
	check((-drone._spot_light.global_basis.z).normalized().dot(expected_beam.normalized())>.999,"Formal spotlight points at target instead of spreading as an omnidirectional bulb")
	check(world.floor_root.get_node("EnemyAimTelegraph").last_drawn_enemy_ids.has(drone._proxy.get_instance_id()),"Actual camera draws the exterior drone red line")
	drone._spot_elapsed=-1
	burning.effects.set_process(false)
	drone._reload_left=0; drone._fire(); drone._process(0); drone.set_process(false); drone._rig.set_process(false)
	burning.effects.step(.025)
	await shot("drone_muzzle")
	burning.effects.set_process(true)
	drone.set_process(true); drone._rig.set_process(true)
	var falls: Node=world.floor_root.get_node("ExteriorFalls")
	falls.previous.erase(drone._proxy.get_instance_id())
	falls._physics_process(.016)
	check(not falls.falling.has(drone._proxy.get_instance_id()),"Open windows do not turn flying drone into falling ground object")
	check(not falls.falling.has(drone._muzzle_2d.get_instance_id()),"Flying muzzle is not deleted by exterior fall controller")
	for index in 3:
		drone._reload_left=0.0
		var before: Array=get_nodes_in_group(&"dream_projectiles")
		drone._fire()
		for item in get_nodes_in_group(&"dream_projectiles"):
			if before.has(item): continue
			item.set_physics_process(false)
			check(item.shooter_instance_id==drone._proxy.get_instance_id(),"Drone shot remembers actual drone damage owner")
			check(item.source_weapon_id==&"basic" and item.damage==drone.firearm_parameters().damage,"Drone uses formal handgun damage")
			check(item.speed==drone.firearm_parameters().speed and item.max_distance==drone.firearm_parameters().range,"Drone uses formal handgun speed and range")
			item.reflect_from_player(world.player,item.global_position)
			check(item.direction.dot(item.global_position.direction_to(drone._proxy.global_position))>.99,"Reflected drone shot returns to drone")
			if index==2: item._handle_collision(drone._proxy)
			item.queue_free()
	var old_proxy: Node=drone._proxy
	check(drone._dead,"Actual reflected projectile collision instantly destroys drone")
	await death_stages(world._exterior_drone_root,"drone_death")
	await frames(45)
	check(not is_instance_valid(old_proxy),"Destroyed drone retires gameplay proxy")
	main.free(); await frames()
	print("SPECIAL_UNITS_GPU checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
