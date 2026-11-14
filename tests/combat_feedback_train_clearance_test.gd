extends SceneTree
const TRAIN := preload("res://scripts/testing/metro_station/train_chapter.gd")
var display: Control
var world: Node3D
var output := ""
var checks := 0
var failures: Array[String] = []


func _initialize() -> void: call_deferred("run")


func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title)
	print("PASS " if ok else "FAIL ",title)


func ticks(count: int) -> void:
	for i in count: await physics_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = display.world_viewport.get_texture().get_image()
	check(picture.save_png(output.path_join(label+".png")) == OK,"Actual Camera "+label)


func stationary_enemy(at: Vector2, weapon := "basic") -> EmployeeEnemy:
	var enemy: EmployeeEnemy = world._spawn_regular_employee(2,at*32.0,&"employee",false,weapon)
	enemy.maximum_health = 10000.0
	enemy.current_health = 10000.0
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func check_body_hits(enemy: EmployeeEnemy) -> void:
	var player: CharacterBody2D = world.player
	var bridge: Node3D = enemy.get_meta(&"depth_visual_bridge").get_ref()
	for yaw: float in [0.0,-PI*.75]:
		world.camera_rig.rotation.y = yaw
		for offset: Vector2 in [Vector2(-2,0),Vector2(2,0),Vector2(0,2),Vector2(0,-2)]:
			player.global_position = enemy.global_position+offset*32.0
			world._update_camera_and_actor_projection(0.0)
			await ticks(3)
			var hits := 0
			for lift: float in [-.10,0.0,.22,.45]:
				var aim_world: Vector3 = bridge.get_hit_feedback_world_position()+world.camera_3d.global_basis.y*lift
				var screen: Vector2 = world.camera_3d.unproject_position(aim_world)
				player._update_held_weapon_aim_at(screen)
				var direction: Vector2 = player._camera_muzzle_aim_direction_at(screen)
				var muzzle: Vector2 = player.projectile_origin.global_position
				var query := PhysicsRayQueryParameters2D.create(muzzle,muzzle+direction*200.0,16)
				query.collide_with_areas = true
				query.collide_with_bodies = false
				query.hit_from_inside = true
				var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
				if hit.get("collider") == enemy.hurtbox: hits += 1
				else: print("MISS lift=",lift," closest local=",Geometry2D.get_closest_point_to_segment(enemy.global_position,muzzle,muzzle+direction*200.0)-enemy.global_position)
			print("BODY AIM yaw=",yaw," from=",offset," hits=",hits,"/4")
			check(hits == 4,"Visible legs/torso/head hit from "+str(offset)+" at yaw "+str(yaw))
	await capture("01_body_aim")
	# Isolate the live projectile from unrelated equipment between this test's
	# aim origin and muzzle. The west branch is a real, empty floor corridor.
	enemy.global_position = Vector2(-25,6)*32.0
	enemy.set_meta(&"dream_room_id",0)
	player.global_position = enemy.global_position+Vector2(-64,0)
	world.camera_rig.rotation.y = 0.0
	world._update_camera_and_actor_projection(0.0)
	await ticks(5)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(-25,6)*32.0
	enemy.velocity = Vector2.ZERO
	await ticks(2)
	var screen: Vector2 = world.camera_3d.unproject_position(bridge.get_hit_feedback_world_position())
	player._update_held_weapon_aim_at(screen)
	var direction: Vector2 = player._camera_muzzle_aim_direction_at(screen)
	var bullet: Node2D = load("res://scenes/entities/basic_projectile.tscn").instantiate()
	bullet.position = player.projectile_origin.global_position
	bullet.setup(direction,2.0,300.0,-1.0,&"player",player)
	var before: float = enemy.current_health
	world.add_projectile(bullet,player)
	var trace: Dictionary = bullet._cast_movement_segment(bullet.global_position,bullet.global_position+direction*200.0)
	print("ACTUAL TORSO SHOT first collider=",trace.get("collider")," expected=",enemy.hurtbox," muzzle=",bullet.global_position," direction=",direction)
	await ticks(45)
	check(enemy.current_health < before,"An actual projected projectile damages the visible torso")


func check_drops() -> void:
	var enemy := stationary_enemy(Vector2(-40,.60),"melee_pipe")
	var before: int = world.world_weapon_root.get_child_count()
	enemy.start_knockdown(Vector2.UP,&"lucille",1200.0)
	await ticks(3)
	check(world.world_weapon_root.get_child_count() == before+1,"A real melee knockdown drops exactly one weapon")
	var drop: WorldWeaponPickup = world.world_weapon_root.get_child(world.world_weapon_root.get_child_count()-1)
	check(drop.drop_motion_active and drop.collision_layer == 0 and drop.collision_mask == drop.DROP_SCENERY_MASK,"Scattering drop collides with scenery without blocking actors")
	var stayed := true
	var maximum_speed := 0.0
	for i in 80:
		await physics_frame
		stayed = stayed and world._is_blood_ground_allowed(drop.global_position)
		maximum_speed = maxf(maximum_speed,drop.linear_velocity.length())
	check(stayed and maximum_speed <= drop.MAX_DROP_SPEED+.1,"Large melee impulses cannot send loot through the map boundary")
	check(not drop.drop_motion_active and drop.collision_mask == 0 and drop.is_available_for(world.player),"The settled weapon returns to ordinary pickup-only state")
	# A floor edge without a wall exercises the independent floor guard.
	drop.place_after_swap(Vector2(-44,11.3)*32.0,Vector2.DOWN*5000.0)
	for i in 80:
		await physics_frame
		stayed = stayed and world._is_blood_ground_allowed(drop.global_position)
	check(stayed and not drop.drop_motion_active,"Floor-edge guard retains loot even when scenery has no wall")
	drop.set_thrown(Vector2.RIGHT*150.0,8.0,20.0,world.player.get_instance_id())
	check(drop.thrown_active and not drop.drop_motion_active and drop.throw_damage == 8.0,"Manual throw keeps its own original damaging flight")
	drop.queue_free()
	enemy.queue_free()
	await ticks(3)


func check_text(enemy: EmployeeEnemy) -> void:
	var fx: Node = world.floor_root.get_node("EnemyCombatText")
	fx.set_process(false)
	fx.clear()
	world.player.critical_chance = 0.0
	world.player.run_damage_multiplier = 1.0
	var health: float = enemy.current_health
	world.resolve_player_hit(enemy,10.0,world.player.global_position,&"player_projectile")
	check(enemy.current_health == health-10.0 and fx.records.is_empty(),"Accepted damage still applies while numeric damage text stays hidden")
	world.player.critical_chance = 1.0
	world.resolve_player_hit(enemy,10.0,world.player.global_position,&"player_projectile")
	check(fx.records[enemy.get_instance_id()].text.is_empty() and fx.records[enemy.get_instance_id()].critical,"Critical word remains available without a numeric damage label")
	fx.clear()
	fx.rng.seed = 7182
	enemy.current_health = 0.0
	var shown := 0
	var omitted := 0
	for i in 40:
		var id := 700000+i
		var snapshot := {"id":id,"health":100.0,"origin":world.get_gameplay_world_position(enemy.global_position,.8)}
		fx.accept(snapshot,enemy,{})
		if i < 3: check(not fx.records.has(id),"No praise on consecutive kill "+str(i+1))
		elif fx.records.has(id):
			shown += 1
			check(fx.records[id].text in fx.KILL_WORDS,"Post-threshold display contains a kill phrase only")
		else: omitted += 1
		fx.accept(snapshot,enemy,{})
		check(fx.kill_streak_count == i+1,"Duplicate accepted event cannot count the same death twice")
	check(shown > 0 and omitted > 0,"After the third kill praise is probabilistic rather than guaranteed")
	fx.last_kill_timestamp = Time.get_ticks_msec()/1000.0-float(world.run_interface.KILL_STREAK_WINDOW)-.1
	fx.accept({"id":800000,"health":100.0,"origin":world.get_gameplay_world_position(enemy.global_position,.8)},enemy,{})
	check(fx.kill_streak_count == 1 and not fx.records.has(800000),"The existing combo timeout restarts praise eligibility")
	enemy.current_health = health
	fx.clear()
	fx.set_process(true)
	world.player.critical_chance = 0.0


func check_trains() -> void:
	world.player.set_process(true)
	world.player.set_physics_process(true)
	await world.begin_train_chapter()
	var train: TRAIN = world._train
	var source := TRAIN.CONSIST.ASSETS.instantiate()
	var original: Mesh = source.get_node("MetroTrain/Carriage_01/Interior/SeatsHandrailsAndLights").mesh
	for index in TRAIN.CONSIST.CAR_COUNT:
		var own := train.art.player_train._car(index)
		var rival := train.art.rival_train._car(index)
		var fittings: MeshInstance3D = rival.get_node("Interior/SeatsHandrailsAndLights")
		check(not own.has_node("Interior/SeatsHandrailsAndLights") and fittings.get_aabb().end.y <= 1.601,"Both trains clear overhead rails in carriage "+str(index+1))
		check(not own.get_node("Interior/InteriorLightDiffusers").visible,"Player overhead tubes stay hidden in carriage "+str(index+1))
		for car: Node3D in [own,rival]:
			var headers_clear := true
			for path: String in ["Body/WindowWall","NearWall/WindowWall","Body/EndCapsAndDriverCab"]:
				headers_clear = headers_clear and car.get_node(path).get_aabb().end.y <= 2.551
			check(headers_clear,"Ceiling headers clear heads on "+String(car.get_parent().get_parent().name)+" carriage "+str(index+1))
		check(fittings.mesh != original and original.get_aabb().end.y > 1.601,"Source train remains unmodified while rival seats stay")
	source.free()
	world.player.global_position = train._pixels(Vector2(TRAIN.BOSS_START_X,0.0))
	train._start_approach()
	await ticks(145)
	var hidden := true
	for strip: Node3D in train.art.rival_train._overhead_strips: hidden = hidden and not strip.visible
	check(hidden,"All opposing overhead tubes hide when the boss train opens for combat")
	world._update_camera_and_actor_projection(0.0)
	await ticks(8)
	var optics: Node3D = world.get_node("OfficeLightOptics")
	var no_ghosts := true
	var current_bounds := true
	for fixture in optics._fixtures:
		for emitter in fixture.sources:
			if not is_instance_valid(emitter.mesh): continue
			if not train.art.root.is_ancestor_of(emitter.mesh): continue
			current_bounds = current_bounds and emitter.mesh.get_aabb().grow(.01).has_point(emitter.bounds.get_center())
	for slot in optics._slots:
		if slot.fixture == null: continue
		for i in mini(slot.tubes.size(),slot.fixture.sources.size()):
			var emitter = slot.fixture.sources[i]
			if is_instance_valid(emitter.mesh) and not emitter.mesh.is_visible_in_tree(): no_ghosts = no_ghosts and not slot.tubes[i].visible
	check(current_bounds and no_ghosts,"Hidden and removed ceiling lamps leave no stale optics source or ghost halo")
	await capture("02_boss_trains")
	var old: WeakRef = weakref(train.art.root)
	world.regenerate(world.seed)
	await ticks(15)
	check(old.get_ref() == null and world._train == null,"Reset removes the modified train instances cleanly")


func run() -> void:
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	display = load("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene = display
	world = display.world
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		process_frame.connect(func(): RenderingServer.force_draw(false))
	world.player.dash_invulnerability_left = 600.0
	for enemy: EmployeeEnemy in world.enemy_root.get_children():
		enemy.set_process(false)
		enemy.set_physics_process(false)
		if not enemy.dead: enemy.take_damage(enemy.maximum_health+100.0,world.player.global_position,0.0,&"regression_setup")
	await ticks(20)
	world.player.configure_weapon("basic",world.config,{})
	world.player.set_process(false)
	world.player.set_physics_process(false)
	var target := stationary_enemy(Vector2(34,6))
	world.player.global_position = Vector2(32,6)*32.0
	await ticks(10)
	await check_body_hits(target)
	check_text(target)
	world.resolve_player_hit(target,target.current_health+100.0,world.player.global_position,&"player_projectile")
	await ticks(3)
	check(target.hurtbox_collision.disabled and target.hurtbox.get_node("BodyCollision").disabled,"Death disables both head and body damage volumes")
	await check_drops()
	target.queue_free()
	await ticks(3)
	await check_trains()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"scope":"Shared drop/hit/text rules and 0-6 overhead visibility and reset, not whole-game performance"},"\t"))
	print("COMBAT AND TRAIN checks=",checks," failures=",failures)
	display.free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
