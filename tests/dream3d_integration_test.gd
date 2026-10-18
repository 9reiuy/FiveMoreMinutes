extends "res://tests/dream3d_combat_parity_test.gd"
const PICKUP = preload("res://scenes/dream/world_weapon_pickup.tscn")

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	root.add_child(world)
	await frames(2)
	player = world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	world.run_interface.auto_open_upgrades = false
	for test_seed in [41001,41002,41003,41004,41005]:
		var old_wall: WeakRef = weakref(world.wall_root.get_child(0)) if world.wall_root.get_child_count() > 0 else null
		check(world.regenerate(test_seed), "seed "+str(test_seed))
		await frames(5)
		check(old_wall == null or old_wall.get_ref() == null, "regenerate frees old geometry")
		var cam: Camera3D = world.camera_3d
		var fixed_rotation := cam.rotation
		var fixed_size := cam.size
		var floor_batch: MultiMeshInstance3D = world.floor_root.get_child(0) as MultiMeshInstance3D
		var mesh := floor_batch.multimesh.mesh as ArrayMesh
		var uv: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		for room_id in [world.spawn_room_id, world.key_room_id, world.boss_room_id]:
			player.global_position = Vector2(world.rooms[room_id].center_cell)*32
			await frames(8)
			check(world.room_visibility.current_room_id == room_id, "stable room-cell identification")
			var faded := 0
			for wall in world.wall_root.get_children():
				var expected: bool = world.room_visibility.near_walls.get(room_id,[]).has(wall)
				if expected: faded += 1
				if not is_equal_approx(wall.wall_opacity,0.3 if expected else 1.0):
					check(false, "only CURRENT near wall fades")
			check(faded > 0, "near wall exists")
			check(cam.rotation.is_equal_approx(fixed_rotation) and cam.size == fixed_size, "fixed camera rotation/size")
			check(mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == uv, "static floor UV under follow")
			check(world.door_root.get_child(0).door_visual.transparency == 0.0, "door does not fade")
			# Independent world/screen roundtrip of the same ground ray used by Player.
			var ground := Vector3(player.position.x/32+2,0,player.position.y/32-1)
			var screen := cam.unproject_position(ground)
			var result: Variant = Plane(Vector3.UP,0).intersects_ray(cam.project_ray_origin(screen),cam.project_ray_normal(screen))
			check(result is Vector3 and Vector3(result).distance_to(ground)<0.001, "mouse-ground ray roundtrip")
		check(not world.find_floor_path(world.spawn_cell,world.get_room_center_cell(world.key_room_id),false).is_empty(), "Start -> Key unlocked route")
		check(world.find_floor_path(world.spawn_cell,world.get_room_center_cell(world.boss_room_id),false).is_empty(), "Boss blocked without key")
		world.collect_boss_key(null)
		check(not world.find_floor_path(world.spawn_cell,world.get_room_center_cell(world.boss_room_id),false).is_empty(), "Key -> Boss route")
	# Formal UI: fast Tab reversals and the non-progression character card.
	var ui: Node = world.run_interface
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell)*32
	player.global_position = anchor
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	check(InputMap.has_action("skill_menu") and tab.is_action_pressed("skill_menu"),"standalone uses formal Tab binding")
	for i in 10:
		ui._unhandled_input(tab)
		await frames(1)
		ui._unhandled_input(tab)
		await frames(1)
	await frames(30)
	check(not ui.card.visible and not paused, "rapid Tab fully closes and unpauses")
	ui._open_card()
	await frames(30)
	check(paused and not ui.crosshair.visible, "card pauses without combat input")
	check(ui.card.find_child("HealthPlus", true, false) == null, "XP stat-point health button was removed from the card")
	check(ui.card.find_child("ExperienceValue", true, false) == null, "EXP display was removed from the card")
	check(ui.card.find_child("PointsValue", true, false) == null, "upgrade-point display was removed from the card")
	# Speed and progression controls are not part of the formal card anymore.
	var card_root: Node = ui.card
	check(card_root.find_child("SpeedPlus", true, false) == null, "Speed upgrade button was removed from the card")
	check(card_root.find_child("SpeedCells", true, false) == null, "Speed segments were removed from the card")
	check(is_equal_approx(float(player.movement_speed), 200.0), "normal movement speed is fixed at 200")
	ui._close_card()
	await frames(30)
	check(ui.crosshair.visible and not paused, "crosshair resumes in UI")
	check(ui.upgrade_panel == null, "formal Dream does not instantiate the upgrade slot panel")
	# All ranged and melee options use the same first-hit target ray.
	var prop := prop_at(anchor)
	await frames(3)
	for weapon_id in ["basic","shotgun","assault_rifle","lucille","books"]:
		player.equip_weapon(weapon_id,CONFIG,{})
		var reach: float = player.get_effective_attack_range()
		var origin := anchor-Vector2(minf(reach*0.5,40),0)
		var aim: Node = world.target_highlight
		check(aim.find_target(origin,Vector2.RIGHT,reach,player.get_rid()) == prop,weapon_id+" actual range target")
		aim._select(prop)
		check(prop.get_meta("depth_visual_bridge").get_ref().actor_sprite.material_overlay != null,weapon_id+" furniture white carrier")
		aim._select(null)
	prop.free()
	# E, kick impact frame, projectiles and outline use the SAME generated Door.
	var door: Node3D
	for candidate in world.door_root.get_children():
		if candidate.door_id != world.boss_door_id:
			door = candidate
			break
	var center: Vector2 = door.get_leaf_center_2d()
	var normal := Vector2(door.global_basis.z.x,door.global_basis.z.z)
	player.global_position = center-normal*22
	await frames(3)
	check(not player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(center-normal*22,center+normal*22,world.get_vision_occluder_collision_mask())).is_empty(),"closed door blocks gameplay LOS")
	check(world.request_player_door_push(),"formal E resolver")
	await frames(55)
	check(absf(door.get_open_angle())>0.05,"E rotates actual leaf")
	check(player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(center-normal*22,center+normal*22,world.get_vision_occluder_collision_mask())).is_empty(),"open passage restores gameplay LOS")
	# Kick a fresh closed door, not the side of an already swinging leaf.
	world.regenerate(41002)
	await frames(4)
	for candidate in world.door_root.get_children():
		if candidate.door_id != world.boss_door_id:
			door = candidate
			break
	center = door.get_leaf_center_2d()
	normal = Vector2(door.global_basis.z.x,door.global_basis.z.z)
	player.global_position = center-normal*22
	player.last_move_direction = normal
	player.dashing = false
	check(player.start_kick(), "formal F begins")
	player._update_kick(CONFIG.kick_animation_duration*0.37)
	check(door.latched, "kick does not hit before impact frame")
	player._update_kick(CONFIG.kick_animation_duration*0.03)
	check(not door.latched and door.get_meta("last_impact_source")==&"kick","F hits at formal 38 percent frame")
	await frames(20)
	var leaf_point: Vector2 = door.get_leaf_center_2d()
	var leaf_normal := Vector2(door.door_leaf.global_basis.z.x,door.door_leaf.global_basis.z.z)
	check(world.target_highlight.find_target(leaf_point-leaf_normal*20,leaf_normal,40,player.get_rid())==door,"open physical door is aim target")
	door.set_target_highlight(true)
	check(door.door_visual.material_overlay != null,"door white outline carrier")
	for weapon_id in ["basic","shotgun","assault_rifle"]:
		var b: Node2D = BULLET.instantiate()
		b.setup(leaf_normal,10,200,1800,&"player",player,StringName(weapon_id))
		b.position = door.get_leaf_center_2d()
		world.add_projectile(b)
		b._handle_collision(door._collision_body_2d)
		check(b.consumed and str(door.get_meta("last_impact_source")).begins_with("projectile"),weapon_id+" door consumes bullet and receives impulse")
		await frames(10)
	door.set_locked(true)
	check(not world.apply_door_impact_to_node(door,door.get_leaf_center_2d(),normal,5000,&"lucille"),"locked door rejects melee")
	# Formal thrown weapon damage/skin/scale and once-only impact.
	anchor = Vector2(world.rooms[world.spawn_room_id].center_cell)*32
	player.global_position = anchor-Vector2(150,0)
	for weapon_id in ["basic","shotgun","assault_rifle","lucille","books"]:
		var e := enemy_at(anchor,1000)
		var weapon: WorldWeaponPickup = PICKUP.instantiate()
		weapon.weapon_id = weapon_id
		weapon.skin_index = 2 if weapon_id=="books" else 0
		world.world_weapon_root.add_child(weapon)
		weapon.position = anchor-Vector2(35,0)
		world.register_depth_visual(weapon,[^"Shadow",^"WeaponSprite"])
		weapon.set_physics_process(false)
		var texture := weapon.weapon_sprite.texture
		var scale := weapon.weapon_sprite.global_scale
		weapon.set_thrown(Vector2(800,0),10,1000,player.get_instance_id())
		weapon._on_physics_body_entered(e)
		check(is_equal_approx(e.current_health,990),weapon_id+" throw damage before break")
		weapon._on_physics_body_entered(e)
		check(is_equal_approx(e.current_health,990),weapon_id+" one impact per target")
		check(weapon.weapon_sprite.texture==texture and weapon.weapon_sprite.global_scale==scale,weapon_id+" skin/scale retained")
		if weapon_id in ["basic","shotgun","assault_rifle"]:
			check(not weapon.throw_break_checked and not weapon.is_queued_for_deletion(),weapon_id+" no firearm break")
		else:
			check(weapon.throw_break_checked,weapon_id+" one melee break roll")
		if not weapon.is_queued_for_deletion(): weapon.queue_free()
		e.queue_free()
		await frames(25)
	print("INTEGRATION CHECKS ",checks," failures ",failures.size())
	world.free()
	await frames(20)
	quit(0 if failures.is_empty() else 1)
