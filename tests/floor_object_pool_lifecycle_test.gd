extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world)
	check(world.regenerate(42001),"formal generated floor")
	paused=true
	var pool: Node3D=world._get_floor_object_capture_pool()
	var sources: Array[Node2D]=[]
	var identities: Array[int]=[]
	var states: Array=[]
	for index in 160:
		var source: Node2D=(world.ENVIRONMENT_DEBRIS_SCENE if index<120 else world.WORLD_WEAPON_SCENE).instantiate()
		(world.ground_debris_root if index<120 else world.world_weapon_root).add_child(source)
		source.position=world.player.position+Vector2(128,0)
		if index<120:
			source.monitoring=false; source.sprite.frame=index%42
			source.spray_velocity=Vector2(80,10); source.vertical_velocity=40; source.fake_height=6
		else:
			source.freeze=true; source.set_weapon_id("assault_rifle",index%3)
			source.fake_height=6; source.linear_velocity=Vector2(80,10); source.angular_velocity=0.7
		var rng_before: int=world._content_rng.state
		if index<120: world._spawn_depth_bridge(source,[^"Sprite2D"],Vector2(64,64),BaseMaterial3D.BILLBOARD_DISABLED,0.02,0.0,Vector3(-PI/2,0,0),true)
		else: world._spawn_depth_bridge(source,[^"Shadow",^"WeaponSprite"])
		check(world._content_rng.state==rng_before,"binding never consumes gameplay RNG")
		identities.append(source.get_instance_id())
		states.append([source.spray_velocity,source.vertical_velocity,source.fake_height] if index<120 else [source.linear_velocity,source.angular_velocity,source.fake_height,source.pickup_shine_phase_offset,source.ownership_state])
		sources.append(source)
	for source in sources: source.get_parent().remove_child(source)
	for frame in 3: await process_frame
	check(pool.idle[&"debris"].size()==96 and pool.idle[&"weapon"].size()==24 and pool.idle[&"shadow"].size()==24,"idle retention limits")
	var live_slots: Dictionary={}
	for index in sources.size():
		var source:=sources[index]
		(world.ground_debris_root if index<120 else world.world_weapon_root).add_child(source)
		pool.restore_binding(source,world.camera_3d,world.dynamic_shadows_enabled)
		check(source.get_instance_id()==identities[index],"overflow does not replace source identities")
		var state: Array=[source.spray_velocity,source.vertical_velocity,source.fake_height] if index<120 else [source.linear_velocity,source.angular_velocity,source.fake_height,source.pickup_shine_phase_offset,source.ownership_state]
		check(state==states[index],"restoration preserves velocity, height, ownership and shine")
		for key in ([&"depth_visual_bridge"] if index<120 else [&"depth_visual_bridge",&"floor_object_shadow_bridge"]):
			var reference: WeakRef=source.get_meta(key)
			var bridge: Node3D=reference.get_ref()
			check(is_instance_valid(bridge) and bridge.configured and bridge.source_actor==source,"overflow restores exact source binding")
			check(not live_slots.has(bridge.get_instance_id()),"no slot stolen from another live object")
			check(not pool.idle[bridge.get_meta(&"floor_object_capture_kind")].has(bridge),"live slot cannot also be idle")
			live_slots[bridge.get_instance_id()]=true
	check(live_slots.size()==200,"all 200 requested display carriers exist")
	for source in sources: source.free()
	for frame in 3: await process_frame
	for kind in pool.idle:
		for bridge in pool.idle[kind]:
			check(not bridge.configured and bridge.source_actor==null,"released source not retained")
			check(not bridge.actor_sprite.visible and bridge.render_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"released display hidden and capture disabled")
	# A nonstandard capture must retain its original geometry/material policy.
	var odd: Node2D=world.ENVIRONMENT_DEBRIS_SCENE.instantiate(); world.ground_debris_root.add_child(odd)
	var legacy: Node3D=world._spawn_depth_bridge(odd,[^"Sprite2D"],Vector2(96,96))
	check(not legacy.has_meta(&"floor_object_capture_kind"),"nonstandard projection bypasses pool")
	world.free(); paused=false
	for frame in 3: await process_frame
	print("FLOOR_OBJECT_LIFECYCLE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
