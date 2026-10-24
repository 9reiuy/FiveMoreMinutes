extends "res://tests/dream3d_combat_parity_test.gd"
var refresh_events := 0
func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(120),"Formal dungeon generation")
	player = world.player
	root.get_node("SFXManager").sfx_played.connect(func(event: StringName) -> void:
		if event==&"dash_refresh": refresh_events += 1)
	player.set_physics_process(false)
	anchor = Vector2(12000,12000)
	for x in range(370,385):
		for y in range(370,385): world.floor_cells[Vector2i(x,y)] = true
	player.global_position = anchor
	player.equip_weapon("lucille",CONFIG,{})
	player.set_meta(&"presentation_pointer_position",func() -> Vector2:
		return world.camera_3d.unproject_position(world.get_gameplay_world_position(player.global_position+Vector2(300,0),0)))
	# Probe real actors on both sides and both endpoint caps, not an elevated
	# mock hurtbox. The ordinary base-health enemy must die from a real bat hit.
	for point in [Vector2(-24,0),Vector2(80,-24),Vector2(80,24),Vector2(192,0),Vector2(80,-28),Vector2(80,28)]:
		var probe := enemy_at(anchor+point,1000,0)
		probe.sky_drop_active = false
		probe.sky_drop_height = 0
		probe.set_process(false)
		await frames(2)
		var hit: Dictionary = world.resolve_phase_dash_attack(anchor,anchor+Vector2(168,0),16,1,&"player_punch",null,false)
		check(int(hit.hits)==(0 if absf(point.y)>26 else 1),"Ground capsule/caps symmetry at %s" % point)
		probe.free()
		await frames(2)
	var enemy := enemy_at(anchor+Vector2(80,0),CONFIG.base_enemy_health,0)
	enemy.sky_drop_active = false
	enemy.sky_drop_height = 0
	enemy.set_process(false)
	await frames(3)
	check(player.try_start_phase_dash(),"Formal player starts phase")
	player._update_dash(.14)
	check(enemy.dead and player.phase_dash.last_result.kills==1,"Real enemy damage/death authority and immediate refresh")
	check(player.dash_charges==1 and player.dash_cooldown_left==0,"Formal lethal hit refreshes charge")
	check(refresh_events==0,"Direct kill has no independent refresh sound")
	check(not root.get_node("SFXManager").players.has(&"dash_refresh"),"Refresh sound is no longer registered")
	check(root.get_node("SFXManager").players.has(&"dash"),"Original dash whoosh remains available")
	check(world._player_melee_damage_depth==0,"Aggregate damage scope is released")
	await frames(5)
	var effect: Node = player.phase_dash.effect
	check(effect.get_parent()==world.floor_root,"Effect belongs to disposable floor")
	check(effect.mesh.material_override==effect.material,"Reflection registration preserves animated material")
	for next_seed in [121,122,123]:
		var old_effect: WeakRef = weakref(effect)
		check(world.regenerate(next_seed),"Regenerate floor %d" % next_seed)
		await frames(3)
		check(old_effect.get_ref()==null,"No residual phase effect on floor %d" % next_seed)
		player = world.player
		player.set_physics_process(false)
		# Create only a floor-owned visual to exercise the next cleanup cycle.
		effect = preload("res://scripts/dream/phase_dash_visual_3d.gd").new()
		world.floor_root.add_child(effect)
	print("PHASE_DASH_WORLD checks=",checks," failures=",failures.size())
	world.free()
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"dash")
	await create_timer(.15,true,false,true).timeout
	await frames(4)
	quit(0 if failures.is_empty() else 1)
