extends "res://tests/floor_reflection_rollout_delivery.gd"
func shot(label:String)->void:
	await wait(.18)
	root.get_texture().get_image().save_png(output+"/"+label+".png")
	reflection.viewport.get_texture().get_image().save_png(output+"/"+label+"_raw.png")
func run()->void:
	process_frame.connect(func()->void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	if not await ready_world(): quit(1); return
	var time:Node=root.get_node_or_null("DreamTimeController")
	if time!=null: time.set_process(false)
	Engine.time_scale=1; Engine.max_fps=60
	var room:Dictionary={}
	for candidate in world.rooms:
		if String(candidate.get("archetype",""))=="reception": room=candidate; break
	if room.is_empty(): quit(1); return
	world.activate_room(room.id)
	var point:=Vector2(room.grid_rect.get_center())*32
	var candidates:Array=room.get("usable_cells",[]).duplicate()
	candidates.sort_custom(func(a:Variant,b:Variant)->bool:return (Vector2(a)*32).distance_squared_to(point)<(Vector2(b)*32).distance_squared_to(point))
	for cell in candidates:
		if world._content_position_is_clear(Vector2(cell)*32,32): point=Vector2(cell)*32; break
	for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
	world.player.global_position=point; world.player.invulnerability_left=0; world.player.dash_invulnerability_left=3600
	world.player.set_attacking_enabled(false); world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	await wait(.8)
	reflection=world.get_node("FloorReflections"); reflection.process_mode=Node.PROCESS_MODE_ALWAYS
	paused=true
	if "--verify-fix" in OS.get_cmdline_user_args():
		await verify_fix()
		return
	await shot("baseline")
	var shadow_lights:Array=[]
	for light in world.find_children("*","Light3D",true,false):
		if light.shadow_enabled and light.is_visible_in_tree():
			shadow_lights.append(light)
	for light in shadow_lights:
		print("PROBE_SHADOW_LIGHT ",light.get_path()," mask=",light.light_cull_mask," opacity=",light.shadow_opacity," player_distance=",light.global_position.distance_to(world.get_gameplay_world_position(world.player.global_position))," energy=",light.light_energy)
		light.shadow_enabled=false
		await shot("no_light_shadow_"+str(shadow_lights.find(light)))
		light.shadow_enabled=true
	for record in reflection.surfaces: record.material.set_shader_parameter("sample_reflection_strength",0.0)
	await shot("no_reflected_colour")
	for record in reflection.surfaces: record.material.set_shader_parameter("sample_reflection_strength",REFLECTION.profile(record.style).x)
	var bridge:Node=world.player_depth_bridge
	var weapon_layers:int=bridge.weapon_sprite.layers
	bridge.weapon_sprite.layers=REFLECTION.EXCLUDED; await shot("no_reflected_weapon"); bridge.weapon_sprite.layers=weapon_layers
	if bridge.volume_shadow!=null:
		if bridge.volume_shadow.weapon!=null:
			bridge.volume_shadow.weapon.visible=false; await shot("no_weapon_shadow")
			bridge.volume_shadow.weapon.visible=true
		bridge.volume_shadow.visible=false; await shot("no_volume_shadow"); bridge.volume_shadow.visible=true
	var ground_shadows:Array=[]
	for child in world.actor_depth_bridges_root.get_children():
		if child.get("source_actor")==world.player and child.get("ground_only")==true:
			ground_shadows.append(child); child.hide()
	await shot("no_ground_shadow")
	for child in ground_shadows: child.show()
	for record in reflection.surfaces: record.material.set_shader_parameter("sample_surface_gloss",0.0)
	await shot("no_gloss")
	print("ACTOR_ARTIFACT_PROBE ",JSON.stringify({"body_layers":bridge.actor_sprite.layers,"weapon_layers":weapon_layers,"volume":bridge.volume_shadow!=null,"ground_shadows":ground_shadows.size(),"viewport":reflection.viewport.size}))
	paused=false; main.free(); quit(0)

func verify_fix()->void:
	var manager:Node=world.shadow_manager
	var bridge:Node=world.player_depth_bridge
	var volume:Node=bridge.volume_shadow
	check(volume.weapon==null and volume.get_node_or_null("WeaponVolume")==null,"Player no longer creates the coarse gun caster")
	var lamp:Light3D=manager.player_shadow_light
	check(lamp!=null,"Player retains a primary shadow lamp")
	var toward_camera:=Vector3(world.camera_3d.global_basis.z.x,0,world.camera_3d.global_basis.z.z).normalized()
	check((volume.global_position-lamp.global_position).dot(toward_camera)>0,"Retained lamp projects the long shadow toward the foreground")
	var masks:Dictionary={}
	for light in world.find_children("*","Light3D",true,false): masks[light]=light.shadow_caster_mask
	await shot("fixed_frozen")
	# Reconstruct the previous caster/masks only for a frozen same-frame A/B.
	var rod:MeshInstance3D=volume._make_caster("DiagnosticOldWeaponVolume",volume.box_mesh,4)
	volume.add_child(rod); volume.weapon=rod
	bridge._sync_volume_shadow(world.camera_3d,0.0)
	for light in masks: light.shadow_caster_mask=int(masks[light])|4
	await shot("legacy_frozen")
	volume.weapon=null; rod.free()
	for light in masks: light.shadow_caster_mask=masks[light]
	await shot("fixed_restored")
	check(bridge.actor_sprite.is_visible_in_tree(),"Visible character stays intact")
	check(bridge.weapon_sprite.layers==2,"Normal held-weapon layer remains unchanged")
	var sources:=0
	for light in masks:
		if light.shadow_enabled and light.is_visible_in_tree() and light.shadow_caster_mask&4!=0 and light.light_cull_mask&4!=0: sources+=1
	check(sources==1,"Exactly one active light projects the player's existing body")
	print("PLAYER_SHADOW_PRIMARY ",lamp.get_path())
	paused=false
	world.player.set_attacking_enabled(true)
	await wait(.25)
	check(bridge.weapon_sprite.is_visible_in_tree(),"Normal held weapon remains visible with combat enabled")
	begin("walk_turn")
	world.player.set_scripted_locomotion(Vector2.RIGHT,42); await wait(.9)
	world.player.set_meta(&"aim_direction_override",Vector2.LEFT)
	world.player.set_scripted_locomotion(Vector2.LEFT,42); await wait(.9)
	world.player.clear_scripted_locomotion()
	for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		world.player.set_meta(&"aim_direction_override",direction); await wait(.25)
	finish()
	check(volume.weapon==null,"Walk/turn does not recreate the removed gun caster")
	check(manager.player_shadow_light!=null,"Body shadow remains assigned after walk and turn")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"GPU verification stayed minimized")
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"clips":clips,"primary":str(lamp.get_path()),"scope":"Real Main Camera, frozen legacy-mask comparison and actual walking/turning; no FPS claim."},"\t"));file.close()
	print("PLAYER_SHADOW_ARTIFACT_FIX ",checks," checks ",failures.size()," failures")
	main.free();quit(1 if failures.size() else 0)
