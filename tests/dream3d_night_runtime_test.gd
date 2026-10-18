extends "res://tests/dream3d_combat_parity_test.gd"
var max_hit_step := 0.0
var min_floor_y := INF

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41004), "generation")
	player = world.player
	player.set_physics_process(false)
	player.invulnerability_left = 10000
	world.run_interface.auto_open_upgrades = false
	world.target_highlight.set_physics_process(false)
	check(world.find_child("RandomBuildingPlayerVision",true,false)==null, "old reveal removed")
	check(world.find_child("PlayerFlashlight",true,false) is SpotLight3D, "real spotlight")
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell)*32
	player.global_position = anchor + Vector2(-100,0)
	var e := enemy_at(anchor,100000)
	# Reproduce a crossing: stale original arena far from the current ground.
	# Neither normal movement nor hit/death can snap the root back there.
	e.arena_bounds = Rect2(anchor-Vector2(1600,1600),Vector2(100,100))
	e.set_physics_process(true)
	var sources: Array[StringName] = [&"punch",&"kick",&"lucille",&"player_projectile",&"shotgun",&"assault_rifle",&"weapon_throw",&"furniture",&"door_impact"]
	for index in 100:
		var previous := e.global_position
		var health_before := e.current_health
		var direction := Vector2.RIGHT.rotated(float(index)*2.399963)
		e.take_damage(1,previous-direction*20,90+index%4*80,sources[index%sources.size()])
		check(e.current_health==health_before-1,"hit damage applied %d"%index)
		check(e.global_position.distance_to(previous)<0.01,"hit has no discrete ground write %d"%index)
		for frame in 4:
			await frames(1)
			max_hit_step = maxf(max_hit_step,e.global_position.distance_to(previous))
			check(e.global_position.distance_to(previous)<25,"continuous hit physics %d"%index)
			previous=e.global_position
	e.free()
	await frames(2)
	# Twenty actual formal deaths (half forced dismember to exercise both paths),
	# twenty formal furniture destroys, not free-standing RigidBody3D substitutes.
	var victims: Array[WeakRef] = []
	for index in 20:
		var dead_enemy := enemy_at(anchor+Vector2((index%5)*20,(index/5)*18),10,1.0 if index%2 else 0.0)
		victims.append(weakref(dead_enemy))
		dead_enemy.take_damage(100,dead_enemy.position-Vector2(20,0),120,sources[index%sources.size()])
		check(dead_enemy.dead,"formal death %d"%index)
		var prop := prop_at(anchor+Vector2((index%5)*20-100,(index/5)*18))
		prop.take_damage(10000,Vector2.RIGHT,1.0)
	for frame in 95:
		await frames(1)
		for bridge in world.actor_depth_bridges_root.get_children():
			if not is_instance_valid(bridge.source_actor) or bridge.ground_only or not bridge.actor_sprite.visible:
				continue
			var source: Node2D = bridge.source_actor
			if not (source is EmployeeEnemy or source is EnemyBodyPart or source.get_script()==preload("res://scenes/dream/effects/shatter_piece.gd") or source.is_in_group("damageable_props")):
				continue
			var bottom := -INF
			for copy in bridge.clone_roots:
				bottom=maxf(bottom,bridge._lowest_pixel(copy))
			if bottom == -INF: continue
			var y: float = bridge.actor_sprite.global_position.y + (bridge.render_viewport.size.y*0.5-bottom)/32.0*world.camera_3d.global_basis.y.y
			min_floor_y=minf(min_floor_y,y)
			if y < -0.002 and failures.size() < 5: print("FLOOR source=",source.get_script().resource_path," bottom=",bottom," lift=",bridge.floor_contact_lift," y=",y)
			check(y>=-0.002,"opaque landing stays above floor")
	for victim in victims: check(victim.get_ref()==null,"death cleanup")
	# Formal gun fire invokes one pooled light pulse, not one permanent light per pellet.
	var lights: Node3D = world.night_lighting
	for gun in ["basic","shotgun","assault_rifle"]:
		player.equip_weapon(gun,CONFIG,{})
		var weapon: Node = player.auto_weapon if gun=="basic" else player.shotgun_weapon if gun=="shotgun" else player.assault_rifle_weapon
		if gun=="shotgun": weapon._fire_full_volley(Vector2.RIGHT,false)
		else: weapon._fire(Vector2.RIGHT,false)
		check(lights.muzzle_lights.any(func(light):return light.visible),"muzzle pulse "+gun)
		await frames(12)
		check(not lights.muzzle_lights.any(func(light):return light.visible),"muzzle expires "+gun)
	check(lights.muzzle_lights.size()==6,"bounded muzzle pool")
	var camera_rotation: Vector3 = world.camera_3d.rotation
	var camera_size: float = world.camera_3d.size
	for index in 36:
		var aim_point := anchor + Vector2.RIGHT.rotated(index*TAU/36)*160
		Input.warp_mouse(world.camera_3d.unproject_position(Vector3(aim_point.x/32,0,aim_point.y/32)))
		await frames(1)
		check(lights.flashlight.global_position.x==player.global_position.x/32,"body centered flashlight")
		check(world.camera_3d.rotation==camera_rotation and world.camera_3d.size==camera_size,"camera unchanged")
	# Five full-content seeds, with actual old/new density runs on identical topology.
	var old_totals := Vector2i.ZERO
	var new_totals := Vector2i.ZERO
	for seed in range(41001,41006):
		world.spawn_content=true
		world.furniture_density=0.012
		world.max_furniture_per_room=4
		world.enemy_density=0.004
		world.max_enemies_per_room=3
		world.global_enemy_cap=18
		check(world.regenerate(seed),"old density baseline")
		old_totals+=Vector2i(world.furniture_count,world.enemy_count)
		world.furniture_density=0.024
		world.max_furniture_per_room=8
		world.enemy_density=0.007
		world.max_enemies_per_room=5
		world.global_enemy_cap=32
		check(world.regenerate(seed),"new density seed %d"%seed)
		new_totals+=Vector2i(world.furniture_count,world.enemy_count)
		for prop in world.furniture_root.get_children():
			var collision: CollisionShape2D = prop.get_node("CollisionShape2D")
			for cell in world.reserved_content_cells:
				check(not collision.shape.get_rect().grow(10).has_point(collision.to_local(Vector2(cell)*32)),"reserved passage clear")
		for enemy in world.enemy_root.get_children():
			var bridge: Node = enemy.get_meta("depth_visual_bridge").get_ref()
			# 正式单投影架构：可见精灵 cast_shadow=OFF（不进 shadow pass，防手电摩尔纹），
			# 由 SHADOWS_ONLY 的 ShadowProxy 孪生负责投射。这里验证的是
			# "Enemy 整体仍具备有效阴影投射能力"，而不是旧架构的"可见精灵自己投影"。
			check(bridge.actor_sprite.shaded and bridge.actor_sprite.alpha_cut==1,"alpha shaded carrier")
			check(bridge.actor_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"visible enemy carrier stays out of shadow pass")
			var enemy_proxy: Sprite3D = bridge.get("shadow_proxy")
			check(enemy_proxy != null,"enemy keeps a shadow proxy")
			if enemy_proxy != null:
				check(enemy_proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"enemy shadow proxy still casts")
				check(enemy_proxy.texture == bridge.actor_sprite.texture,"enemy shadow proxy shares the pixel capture")
			check(world._room_id_at_position(enemy.position)>=0,"spawn is usable floor")
		check(not world.find_floor_path(world.spawn_cell,world.rooms[world.key_room_id].center_cell,false).is_empty(),"key reachable")
		check(not world.find_floor_path(world.spawn_cell,world.rooms[world.boss_room_id].center_cell,true).is_empty(),"boss route reachable")
		if not world.enemy_root.get_children().is_empty():
			player.position=world.enemy_root.get_child(0).position-Vector2(100,0)
		await frames(35)
		if "--render" in OS.get_cmdline_user_args():
			Input.warp_mouse(Vector2(850,330))
			await frames(20)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/night_seed_%d.png"%seed)
	print("NIGHT RUNTIME hits=100 max_step=",max_hit_step," deaths=20 destroys=20 min_floor_y=",min_floor_y," old_density=",old_totals," new_density=",new_totals," FPS=",Engine.get_frames_per_second()," checks=",checks," failures=",failures.size())
	world.free()
	await frames(25)
	quit(1 if failures.size() else 0)
