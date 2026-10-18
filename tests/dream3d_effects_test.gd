extends "res://tests/dream3d_combat_parity_test.gd"
const PICKUP = preload("res://scenes/dream/world_weapon_pickup.tscn")

func _run() -> void:
	world = SCENE.instantiate()
	world.set_meta(&"test_legacy_floor_object_capture","--legacy-floor-object-capture" in OS.get_cmdline_user_args())
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41005),"generation")
	player = world.player
	player.set_physics_process(false)
	player.invulnerability_left = 10000
	world.target_highlight.set_physics_process(false)
	world.run_interface.auto_open_upgrades = false
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell)*32
	player.position = anchor-Vector2(140,0)
	# Statistical check of the ONE shared probability gate.
	seed(8472)
	var bullet: Node2D = BULLET.instantiate()
	bullet.setup(Vector2.RIGHT,37,300,1800,&"enemy",player,&"basic")
	var successes := 0
	for i in 10000:
		bullet.penetration_count = 0
		if bullet._roll_enemy_penetration():
			successes += 1
			check(not bullet._roll_enemy_penetration(),"max one penetration")
	check(successes > 700 and successes < 1300,"10 percent shared gate distribution")
	print("PENETRATION ",successes,"/10000")
	bullet.position = anchor
	bullet.penetration_count = 0
	bullet.penetration_chance = 1.0
	world.add_projectile(bullet)
	bullet.set_physics_process(false)
	var a := enemy_at(anchor,1000)
	var b := enemy_at(anchor+Vector2(40,0),1000)
	bullet._handle_collision(a)
	check(not bullet.consumed and bullet._should_ignore_collider(a.get_node("Hurtbox")),"penetration ignores same Enemy colliders")
	bullet._handle_collision(b)
	check(bullet.consumed and a.current_health==963 and b.current_health==963,"second target same damage then terminate")
	a.queue_free()
	b.queue_free()
	await frames(25)
	var broken := 0
	for i in 500:
		var weapon: WorldWeaponPickup = PICKUP.instantiate()
		weapon.weapon_id = "books" if i%2==0 else "lucille"
		world.world_weapon_root.add_child(weapon)
		weapon.position = anchor
		weapon.set_thrown(Vector2(800,0),10,1000,player.get_instance_id())
		weapon._handle_melee_throw_impact(800)
		check(weapon.throw_break_checked,"one throw break gate")
		var was_broken := weapon.is_queued_for_deletion()
		if was_broken:
			broken += 1
			check(not weapon.is_in_group("world_weapon_pickups") and not weapon.thrown_active,"broken pickup/damage disabled immediately")
		else:
			weapon._handle_melee_throw_impact(800)
			check(not weapon.is_queued_for_deletion(),"same throw never re-rolls")
		weapon.free()
	check(broken > 205 and broken < 295,"50 percent melee break distribution")
	print("MELEE BREAK ",broken,"/500")
	# The shadow is a separate world-ground capture throughout weapon spin.
	var weapon: WorldWeaponPickup = PICKUP.instantiate()
	weapon.weapon_id = "assault_rifle"
	world.world_weapon_root.add_child(weapon)
	weapon.position = anchor
	world.register_depth_visual(weapon,[^"Shadow",^"WeaponSprite"])
	weapon.rotation = 1.4
	weapon._physics_process(0.01)
	check(is_zero_approx(weapon.shadow.global_rotation),"weapon shadow does not spin")
	check(weapon.shadow.global_position.is_equal_approx(weapon.global_position+weapon.shadow_ground_offset),"weapon shadow remains ground anchored")
	weapon.queue_free()
	# Capacity is per room and counts ONLY debris, never blood/shatter pieces.
	world.config = CONFIG.duplicate()
	world.config.environment_debris_max_per_room = 3
	world.spawn_environment_debris(anchor,world.spawn_room_id,3)
	var oldest: Node = world.ground_debris_root.get_child(world.ground_debris_root.get_child_count()-3)
	world.spawn_environment_debris(anchor+Vector2(8,0),world.spawn_room_id,2)
	check(oldest.is_queued_for_deletion(),"oldest settled debris recycled")
	var alive := 0
	for item in world.ground_debris_root.get_children():
		if item.is_in_group("environment_debris") and not item.is_queued_for_deletion(): alive += 1
	check(alive==3,"same-frame burst respects per-room debris cap")
	world.config = CONFIG
	var spray_prop := prop_at(anchor+Vector2(70,0))
	await frames(3)
	check(world.spawn_environment_debris(spray_prop.global_position,world.spawn_room_id,1,Vector2.RIGHT,82,spray_prop)==1,"furniture spray spawns outside source")
	var spray: Node = world.ground_debris_root.get_child(world.ground_debris_root.get_child_count()-1)
	check(world.is_environment_debris_position_allowed(spray.global_position,world.spawn_room_id),"spray origin legal without ignoring furniture")
	spray_prop.queue_free()
	# Real wall surfaces in all four orientations, not old inflated collider faces.
	var tested_normals: Array[Vector2] = []
	for wall in world.wall_root.get_children():
		if not wall.has_meta(&"edge"): continue # Wall fixtures are not wall segments.
		var edge: Dictionary = wall.get_meta("edge")
		var sides: Array = world._edge_side_cells(edge)
		for i in 2:
			if not world.floor_cells.has(sides[i]):
				continue
			var normal := Vector2(sides[i]-sides[1-i])
			if tested_normals.has(normal):
				continue
			var point := Vector2(wall.position.x,wall.position.z)*32+normal*10
			var before: int = world.world_effects_root.get_child_count()
			world.spawn_wall_blood_from_hit(point,normal,int(world.room_cells.get(sides[i],-1)))
			check(world.world_effects_root.get_child_count()==before+1,"wall blood source "+str(normal))
			var blood: Node2D = world.world_effects_root.get_child(world.world_effects_root.get_child_count()-1)
			var bridge: Node3D = blood.get_meta("depth_visual_bridge").get_ref()
			var projected := Vector2(bridge.actor_sprite.global_position.x,bridge.actor_sprite.global_position.z)*32
			var expected: Vector2 = Vector2(wall.position.x,wall.position.z)*32+normal*(world.wall_thickness*16+0.05)
			check(projected.distance_to(expected)<0.1,"blood on real 3D face "+str(normal))
			if projected.distance_to(expected)>=0.1:
				print("BLOOD FACE actual=",projected," expected=",expected," edge=",edge)
			var facing: Vector3 = bridge.actor_sprite.global_basis.z
			check(Vector2(facing.x,facing.z).dot(normal)>0.99,"blood correct wall normal")
			tested_normals.append(normal)
	check(tested_normals.size()==4,"four wall faces checked")
	var effects_before: int = world.world_effects_root.get_child_count()
	world.spawn_wall_blood_from_hit(anchor,Vector2.RIGHT,world.spawn_room_id)
	check(world.world_effects_root.get_child_count()==effects_before,"no floating wall blood without real surface")
	# Knockdown changes only visual height; shadow and fixed camera stay ground.
	var e := enemy_at(anchor)
	e.start_knockdown(Vector2.RIGHT,&"kick",CONFIG.get_kick_knockback_force())
	var bridge: Node3D = e.get_meta("depth_visual_bridge").get_ref()
	e.knockdown_height = 24
	bridge._process(0)
	# 正式放置公式（bridge 引入 floor_contact_lift 寻地逻辑后的正式行为）：
	#   Y = actor_center_height + height/32 + floor_contact_lift
	# 断言直接验证该正式公式（height=24 只应用一次），而不是旧的无 lift 表达式。
	check(is_equal_approx(bridge.actor_sprite.position.y,
		bridge.actor_center_height + 24.0 / 32.0 + bridge.floor_contact_lift),
		"fake height once on 3D Y")
	check(e.character_visual.scale.abs().is_equal_approx(Vector2.ONE*1.5),"knockdown keeps actor scale")
	e.queue_free()
	await frames(25)
	# Full playable population: no substitute Enemy/Furniture entities.
	world.spawn_content = true
	check(world.regenerate(41004),"full content regeneration")
	await frames(10)
	check(world.enemy_root.get_child_count()>0 and world.furniture_root.get_child_count()>0,"formal Enemy/Furniture population")
	var full_debris := get_nodes_in_group("environment_debris")
	check(full_debris.size()>12,"ambient density uses shared 2D area configuration")
	for item in full_debris:
		check(world.is_environment_debris_position_allowed(item.global_position,item.room_id),"ambient debris on legal visible floor")
		check(item.settled and not item.is_physics_processing(),"ambient remains settled without updates")
	for enemy in world.enemy_root.get_children():
		check(enemy is EmployeeEnemy and enemy.has_meta("depth_visual_bridge"),"formal Enemy plus visual only")
	for prop in world.furniture_root.get_children():
		check(prop.has_method("take_damage") and prop.has_meta("depth_visual_bridge"),"formal damageable furniture")
	var room_id: int = int(world.enemy_root.get_child(0).get_meta("dream_room_id"))
	player.position = Vector2(world.rooms[room_id].center_cell)*32
	await frames(120)
	var audio_manager: Node = root.get_node("SFXManager")
	check(audio_manager.current_music_id==&"battle" and audio_manager.music_player.playing,"formal combat music active")
	var play_position: float = audio_manager.music_player.get_playback_position()
	audio_manager.play_music(&"battle",world.get_instance_id())
	audio_manager.play_music(&"battle",world.get_instance_id())
	await frames(10)
	check(audio_manager.music_player.get_playback_position()>=play_position,"repeated combat requests do not restart music")
	print("FULL CONTENT enemy=",world.enemy_root.get_child_count()," furniture=",world.furniture_root.get_child_count()," debris=",get_nodes_in_group("environment_debris").size()," bridges=",world.actor_depth_bridges_root.get_child_count()," FPS=",Engine.get_frames_per_second())
	if "--render" in OS.get_cmdline_user_args():
		Input.warp_mouse(Vector2(420,200))
		await frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/parity_full_content.png")
	# Formal death CRT completes, not a stuck living Player.
	player.invulnerability_left = 0
	player.receive_damage(100000,&"parity_test")
	await frames(100)
	check(player.dead and world.run_interface.death_transition_finished,"formal Player death CRT completion")
	print("EFFECTS CHECKS ",checks," failures ",failures.size())
	world.free()
	await frames(25)
	quit(0 if failures.is_empty() else 1)
