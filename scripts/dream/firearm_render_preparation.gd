extends RefCounted
## Loading-only first-use rendering. Caller must freeze gameplay and cover
## this world. No player's weapon is fired; ammo/spread/cooldowns stay intact.
static func run(tree: SceneTree,world: Node3D,include_shot_visuals: bool=true) -> Dictionary:
	if DisplayServer.get_name()=="headless": return {"skipped":"headless"}
	if not tree.paused and (not is_instance_valid(world) or world.can_process()): return {"skipped":"gameplay_not_frozen"}
	if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true}
	preload("res://scripts/app/performance_markers.gd").lighting_event(world,"prewarm_start")
	var whole_started:=Time.get_ticks_usec()
	var phase_timings: Dictionary={}
	var destruction: Dictionary=await preload("res://scripts/dream/destruction_render_preparation.gd").run(tree,world)
	if destruction.get("cancelled",false) or not is_instance_valid(world): return {"cancelled":true,"destruction":destruction}
	var floor_token: int=world.get_current_floor_token()
	var lighting: Node3D=world.night_lighting
	if not is_instance_valid(lighting) or not is_instance_valid(world.player_depth_bridge): return {"skipped":"world_not_ready"}
	var saved: Array=[]
	var saved_interior: Array=[]
	if is_instance_valid(world.shadow_manager):
		for light in world.shadow_manager.active:
			if is_instance_valid(light):
				saved_interior.append([light,light.shadow_opacity])
				# A zero-opacity initial fade can skip shadow variants entirely.
				# Render the normal completed fade while covered, then restore it.
				light.shadow_opacity=1.0
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
	var build_started:=Time.get_ticks_usec()
	if include_shot_visuals:
		# CPU-particle instancing needs the formal viewport/material render path;
		# the private destruction mesh viewport alone leaves its first draw cold.
		# Covered and paused: deterministic display carriers, never collision hits.
		for surface in [&"solid",&"metal",&"glass",&"soft"]:
			var impact=preload("res://scripts/dream/firearm_impact_visual_3d.gd").new()
			impact.setup(Vector3.UP,surface)
			world.world_effects_root.add_child(impact)
			impact.global_position=world.get_gameplay_world_position(world.player.global_position+Vector2(32,32),.8)
			impact.process_mode=Node.PROCESS_MODE_DISABLED
			impact._emitter.use_fixed_seed=true; impact._emitter.seed=1234
			impact._emitter.restart(); impact._emitter.request_particles_process(.07)
			temporary_sources.append(impact)
		phase_timings["impact_build_ms"]=(Time.get_ticks_usec()-build_started)/1000.0
		var impact_draw_started:=Time.get_ticks_usec()
		for frame in 2: await RenderingServer.frame_post_draw
		phase_timings["impact_draw_wait_ms"]=(Time.get_ticks_usec()-impact_draw_started)/1000.0
		if not is_instance_valid(world) or not world.is_inside_tree() or world.get_current_floor_token()!=floor_token:
			for node in temporary_sources:
				if is_instance_valid(node): node.queue_free()
			_clear_firearm_render_vfx(world)
			return {"cancelled":true,"destruction":destruction}
		build_started=Time.get_ticks_usec()
		var retained: Dictionary={}
		for node in world.world_effects_root.get_children(): retained[node.get_instance_id()]=true
		var origin: Vector2=world.player.get_projectile_origin()
		var projectile: Node2D=preload("res://scenes/entities/basic_projectile.tscn").instantiate()
		projectile.process_mode=Node.PROCESS_MODE_DISABLED
		preload("res://scripts/dream/dream_firearm_rules.gd").setup_projectile(projectile,Vector2.RIGHT,0.0,1024.0,1500.0,&"player",world.player,&"assault_rifle")
		projectile.global_position=origin; world.add_projectile(projectile,world.player); projectile_id=projectile.get_instance_id()
		world.spawn_weapon_muzzle(origin,Vector2.RIGHT,&"assault_rifle",world.player)
		world.spawn_shell_ejection(origin,Vector2.RIGHT,&"assault_rifle")
		if world.uses_pixel_combat_vfx():
			for kind in [&"pistol",&"shotgun"]:
				world.spawn_weapon_muzzle(origin,Vector2.RIGHT,kind,world.player)
			world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT,false,true,world.player)
			world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT,true,true,world.player)
			var manager: Node=world.floor_root.get_node_or_null("FootstepSmoke")
			if manager!=null and manager.get_child_count()>0:
				# Render one disposable copy, leaving native slots, distances and
				# the independent smoke RNG unchanged throughout loading.
				var native: Sprite3D=manager.get_child(0).duplicate()
				manager.add_child(native); native.visible=true; native.scale=Vector3.ONE*.6
				native.modulate.a=.6
				native.global_position=world.get_gameplay_world_position(world.player.global_position+Vector2(16,0),.12)
				temporary_sources.append(native)
		for node in world.world_effects_root.get_children():
			if not retained.has(node.get_instance_id()): temporary_sources.append(node); node.process_mode=Node.PROCESS_MODE_DISABLED
	else:
		lighting.flash_muzzle_world(world.player_depth_bridge.actor_sprite.global_position,&"assault_rifle")
	phase_timings["shot_build_ms"]=(Time.get_ticks_usec()-build_started)/1000.0
	var shot_draw_started:=Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	if include_shot_visuals:
		# Submit both the bright birth and textured smoke/late halo branches.
		# Paused captures require one explicit passive refresh after age changes.
		for source in temporary_sources:
			if not is_instance_valid(source) or not source is Node2D: continue
			if source.get_script()==preload("res://scripts/entities/weapon_muzzle_effect.gd") and source.nyangeon_style:
				source.lifetime=source.initial_lifetime-.11
			elif source.get_script()==preload("res://scripts/entities/combat_feedback_effect.gd") and source.nyangeon_style:
				source.elapsed=.10
			else: continue
			source.queue_redraw()
			var reference: Variant=source.get_meta(&"depth_visual_bridge") if source.has_meta(&"depth_visual_bridge") else null
			var bridge: Node=reference.get_ref() if reference is WeakRef else null
			if is_instance_valid(bridge): bridge._process(0.0)
		for frame in 2: await RenderingServer.frame_post_draw
	phase_timings["shot_draw_wait_ms"]=(Time.get_ticks_usec()-shot_draw_started)/1000.0
	# The initial player starts at the threshold, but first control is handed
	# back at the existing corridor landing. Prepare that receiver set too;
	# do not teleport the actor/camera or change the scripted exit animation.
	var receiver_started:=Time.get_ticks_usec()
	if is_instance_valid(world) and world.is_inside_tree() and world.get_current_floor_token()==floor_token and is_instance_valid(world.elevator_floor_door):
		var landing: Vector2=world.elevator_floor_door.get_corridor_approach_position_2d()
		for light in lighting.muzzle_lights: light.visible=false; light.shadow_enabled=false
		lighting._muzzle_shadow_slot=-1
		lighting.flash_muzzle_world(world.get_gameplay_world_position(landing,.8),&"assault_rifle")
		for frame in 2: await RenderingServer.frame_post_draw
	phase_timings["receiver_ms"]=(Time.get_ticks_usec()-receiver_started)/1000.0
	preload("res://scripts/app/performance_markers.gd").lighting_event(world,"prewarm_completed_draws")
	var cancelled: bool=not is_instance_valid(world) or not world.is_inside_tree()
	if not cancelled: cancelled=world.get_current_floor_token()!=floor_token or not is_instance_valid(lighting)
	var readback_bytes:=0
	if not cancelled:
		# Complete actual GPU work; allocating dormant pool slots is insufficient.
		var readback_started:=Time.get_ticks_usec()
		var image: Image=world.camera_3d.get_viewport().get_texture().get_image()
		phase_timings["readback_ms"]=(Time.get_ticks_usec()-readback_started)/1000.0
		readback_bytes=image.get_data().size()
		for index in lighting.muzzle_lights.size():
			var light: Light3D=lighting.muzzle_lights[index]
			light.visible=saved[index].visible; light.shadow_enabled=saved[index].shadow
			light.light_energy=saved[index].energy; light.transform=saved[index].transform
		for key in fields: lighting.set(key,fields[key])
		for state in saved_interior:
			if is_instance_valid(state[0]): state[0].shadow_opacity=state[1]
		world._content_rng.state=rng_state
	var cleanup_started:=Time.get_ticks_usec()
	if is_instance_valid(world) and projectile_id!=0: world._release_projectile_local_light(projectile_id)
	for node in temporary_sources:
		if is_instance_valid(node): node.queue_free()
	_clear_firearm_render_vfx(world)
	# Release capture ownership and submit the restored world before revealing it.
	for frame in 2: await tree.process_frame
	if not cancelled: await RenderingServer.frame_post_draw
	phase_timings["cleanup_ms"]=(Time.get_ticks_usec()-cleanup_started)/1000.0
	return {"elapsed_ms":float(Time.get_ticks_usec()-whole_started)/1000.0,"firearm_elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,"phase_timings":phase_timings,"destruction":destruction,"world_readback_bytes":readback_bytes,"temporary_sources":temporary_sources.size(),"cancelled":cancelled}

static func _clear_firearm_render_vfx(world: Node) -> void:
	if not is_instance_valid(world): return
	var host: Node = world.floor_root if is_instance_valid(world.get("floor_root")) else world
	var burning_node: Node = host.get_node_or_null("BurningEffects") if is_instance_valid(host) else null
	if is_instance_valid(burning_node) and burning_node.has_method("clear"):
		burning_node.clear()
	if world.has_method("_muzzle_smoke"):
		var smoke: Node = world.call("_muzzle_smoke")
		if is_instance_valid(smoke) and smoke.has_method("clear"):
			smoke.clear()
