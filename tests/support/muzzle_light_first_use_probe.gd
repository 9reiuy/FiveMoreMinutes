extends RefCounted
## Test-only formal-world light preparation. Caller must freeze gameplay and
## cover the world while this existing pulse renders. No shot/damage is created.
static func run(tree: SceneTree,world: Node3D) -> Dictionary:
	var lighting: Node3D=world.night_lighting
	var saved: Array=[]
	for light in lighting.muzzle_lights:
		saved.append({"visible":light.visible,"shadow":light.shadow_enabled,"energy":light.light_energy,"transform":light.transform})
	var fields: Dictionary={}
	for key in [&"next_flash",&"remaining",&"_pulse_deadlines_usec",&"_muzzle_shadow_slot",&"_muzzle_shadow_frame",&"_muzzle_shadow_score"]:
		var value: Variant=lighting.get(key)
		fields[key]=value.duplicate() if value is Array or value is Dictionary or value is PackedInt64Array or value is PackedFloat32Array else value
	var started:=Time.get_ticks_usec()
	var temporary_sources: Array[Node]=[]
	var projectile_id:=0
	var rng_state: int=world._content_rng.state
	if "--prime-shot-visuals" in OS.get_cmdline_user_args():
		var retained: Dictionary={}
		for node in world.world_effects_root.get_children(): retained[node.get_instance_id()]=true
		var origin: Vector2=world.player.get_projectile_origin()
		var projectile: Node2D=preload("res://scenes/entities/basic_projectile.tscn").instantiate()
		projectile.process_mode=Node.PROCESS_MODE_DISABLED
		preload("res://scripts/dream/dream_firearm_rules.gd").setup_projectile(projectile,Vector2.RIGHT,0.0,1024.0,1500.0,&"player",world.player,&"assault_rifle")
		projectile.global_position=origin; world.add_projectile(projectile,world.player); projectile_id=projectile.get_instance_id()
		world.spawn_weapon_muzzle(origin,Vector2.RIGHT,&"assault_rifle",world.player)
		world.spawn_shell_ejection(origin,Vector2.RIGHT,&"assault_rifle")
		for node in world.world_effects_root.get_children():
			if not retained.has(node.get_instance_id()): temporary_sources.append(node); node.process_mode=Node.PROCESS_MODE_DISABLED
	else:
		lighting.flash_muzzle_world(world.player_depth_bridge.actor_sprite.global_position,&"assault_rifle")
	await RenderingServer.frame_post_draw
	if not temporary_sources.is_empty():
		for frame in 2: await RenderingServer.frame_post_draw
	# Submit/finish the actual world view, not another artificial material view.
	var image: Image=world.camera_3d.get_viewport().get_texture().get_image()
	for index in lighting.muzzle_lights.size():
		var light: Light3D=lighting.muzzle_lights[index]
		light.visible=saved[index].visible; light.shadow_enabled=saved[index].shadow
		light.light_energy=saved[index].energy; light.transform=saved[index].transform
	for key in fields: lighting.set(key,fields[key])
	world._content_rng.state=rng_state
	if projectile_id!=0: world._release_projectile_local_light(projectile_id)
	for node in temporary_sources: node.queue_free()
	return {"elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,"world_readback_bytes":image.get_data().size(),"light_slots":lighting.muzzle_lights.size(),"temporary_sources":temporary_sources.size()}
