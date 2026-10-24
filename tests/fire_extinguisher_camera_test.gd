extends SceneTree
const OUT="res://.runtime/fire_extinguisher_20261023"
var main: Node
var world: Node
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func frames(count:=8) -> void:
	for i in count:await process_frame
func settle() -> void:
	var end:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<end:await process_frame
	await frames(15)
func shot(name: String) -> Image:
	await frames();await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	frame.save_png(OUT+"/"+name+".png")
	return frame
func red_pixels(frame: Image) -> int:
	var count:=0
	var colors: Array[Color]=[Color(.91,.25,.26),Color(.72,.12,.18),Color(.43,.055,.095)]
	for y in frame.get_height():
		for x in frame.get_width():
			var color:=frame.get_pixel(x,y)
			for target in colors:
				if Vector3(color.r,color.g,color.b).distance_to(Vector3(target.r,target.g,target.b))<.025:count+=1;break
	return count
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func()->void:quit(2))
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true);settings.set_palette_enabled(true)
	main=load("res://scenes/app/main.tscn").instantiate();root.add_child(main);await settle()
	main.persistent_day_state=main._create_initial_state();main.persistent_day_state.tutorial_completed=true
	seed(120);main._show_dream("basic");await settle()
	world=main._supported_dream_world
	var monitor:=root.get_node_or_null("PerformanceMonitor")
	if monitor!=null:
		monitor.current_mode=0;monitor._update_display_mode()
	while world.floor_transition_in_progress:await process_frame
	var system: Node=world.floor_root.get_node("FireExtinguisherSystem")
	system.set_physics_process(false)
	var tanks:=get_nodes_in_group(&"fire_extinguishers")
	check(tanks.size()>0 and tanks.size()<=18,"Main formal floor generates a bounded wall-mounted extinguisher set")
	if tanks.is_empty():main.free();quit(1);return
	for tank in tanks:
		var key: String=tank.get_meta("wall_edge_key")
		check(not world.glass_wall_edges.has(key) and not world.window_wall_edges.has(key) and world.wall_edges.has(key),"Formal cylinder is mounted only on a solid wall")
	var tank: Node=tanks[0]
	world.player.set_physics_process(false)
	world.player.current_health=100000;world.player.maximum_health=100000;world.player.dash_invulnerability_left=3600
	world.player.global_position=tank.global_position+tank.inward*64
	var room_id: int=tank.get_meta("dream_room_id")
	if room_id>=0:world.reveal_room(room_id)
	world._update_camera_and_actor_projection(0)
	await frames(25)
	for enemy in world.enemy_root.get_children():
		enemy.set_physics_process(false)
	var mounted:=await shot("wall_mounted")
	var cylinder_mesh: MeshInstance3D=tank.visual.get_child(0)
	print("EXTINGUISHER_PAINT surfaces=",cylinder_mesh.mesh.get_surface_count()," preserve=",cylinder_mesh.get_surface_override_material(1).get_shader_parameter("preserve_red")," vertices=",cylinder_mesh.mesh.surface_get_array_len(1)," palette=",world.get_viewport().get_node_or_null("WorldPaletteLayer")!=null)
	check(cylinder_mesh.get_surface_override_material(1).get_shader_parameter("preserve_red"),"Paint detects palette layer installed after floor generation")
	check(red_pixels(mounted)>8,"Mounted cylinder remains visibly red with palette enabled")
	# A clear-space material probe separates palette errors from wall occlusion.
	var original_position: Vector2=tank.global_position
	tank.global_position=world.player.global_position+Vector2(28,25);tank._sync_visual()
	await shot("paint_clear_space")
	settings.set_palette_enabled(false)
	var unfiltered:=await shot("paint_filter_off")
	check(red_pixels(unfiltered)>8,"Red paint survives switching the palette off")
	settings.set_palette_enabled(true)
	tank.global_position=original_position;tank._sync_visual()
	for i in 2:
		var bullet=load("res://scenes/entities/basic_projectile.tscn").instantiate()
		bullet.damage=10;bullet.direction=tank.inward;bullet.set_meta("shot_height_pixels",40.0)
		world.gameplay_world.add_child(bullet);bullet.set_physics_process(false)
		bullet.global_position=tank.global_position
		bullet._handle_collision(tank)
	check(tank.broken and tank.flying,"Actual bullet hit entrypoint breaks and releases the formal cylinder")
	tank.set_physics_process(false);tank._sync_visual()
	var burn:=preload("res://scripts/dream/burning_effects.gd").install(world)
	burn.set_physics_process(false);burn.effects.set_process(false)
	check(burn.ignite(world.player),"Player can burn before gas arrives")
	for i in 20:system.advance(.05)
	print("SMOKE_SIZE smallest_room_cells=",system.smallest_room_cells," actual_cells=",system.cells.size()," radius_cells=",system.coverage_radius)
	check(system.cells.size()<=system.smallest_room_cells,"Single cloud area is bounded by the real smallest room")
	check(system.contains(world.player.global_position),"Gas reaches player in the source room")
	check(not burn.burning.has(world.player.get_instance_id()) and not burn.ignite(world.player),"Gas extinguishes player and prevents repeated ignition")
	var bridge: Node=world.player_depth_bridge
	check(bridge.lit_material.get_shader_parameter("smoke_silhouette")==true,"Formal body shader switches to silhouette")
	check(bridge.weapon_material.get_shader_parameter("smoke_silhouette")==true,"Held weapon shares silhouette state")
	check(bridge.lit_material.get_shader_parameter("enemy_rim_enabled")==false,"White readability rim is disabled inside smoke")
	check(tank.smoke_silhouette and cylinder_mesh.material_overlay!=null,"Formal cylinder becomes a black silhouette inside smoke")
	var hidden_count:=0
	for record in system.hidden_enemies.values():
		for entry in record.nodes:
			var visual: Node3D=entry.ref.get_ref()
			if is_instance_valid(visual):
				hidden_count+=1
				check(not visual.visible,"Actual enemy model/weapon/outline carrier is hidden behind smoke")
	check(hidden_count>0,"Main scene contains actual enemy presentation hidden from the player by smoke")
	await shot("room_smoke_silhouette")
	var trail_source: Dictionary=system.sources[0]
	for i in 5:
		tank.advance_flight(.025);tank._sync_visual();system.advance(.025)
		await shot("flight_smoke_%02d" % i)
	check(not trail_source.trail.is_empty(),"Formal moving cylinder deposits smoke along real swept flight segments")
	tank.stop_flight();tank._sync_visual()
	# Capture actual Camera animation while stepping the same floor-owned system.
	for i in 12:
		system.advance(.10)
		await shot("smoke_%02d" % i)
	check(system.puffs.size()<=192,"Actual Camera smoke remains in particle budget")
	check(system.clouds.size()+system.puffs.size()<=192,"Volumetric clouds and jet exhaust share one budget")
	check(system.banks[0].mesh is QuadMesh,"Gas uses camera-facing illustrated cards layered in 3D")
	check(system.materials.size()==2 and system.materials[0].get_shader_parameter("clip_at_floor")==true,"Fused cloud base clipping is enabled on the formal floor")
	check(system.materials[0].get_shader_parameter("fusion_enabled")==true and system.materials[1].get_shader_parameter("outer_outline_pass")==true,"Main uses separate outer silhouette and inner shadow passes")
	check(system.fusion_pairs>0,"Actual Main cloud groups form light fusion pairs")
	for cloud in system.clouds:
		check(float(cloud.clearance)>0.0,"Whole cards have positive structural clearance")
		check(float(cloud.life)>=4.0 and float(cloud.life)<=6.0,"Cloud puffs renew on slow staggered 4-6 second lifetimes")
	var bank: MultiMesh=system.banks[0]
	for index in bank.visible_instance_count:
		if bank.get_instance_color(index).g<.5:
			var fringe_pose:=bank.get_instance_transform(index)
			var fringe_point: Vector3=world.global_transform.affine_inverse()*(system.global_transform*fringe_pose.origin)
			check(not system.contains(Vector2(fringe_point.x,fringe_point.z)*32),"Sparse fringe lies outside the silhouette coverage")
			continue
		var pose:=bank.get_instance_transform(index)
		var point: Vector3=world.global_transform.affine_inverse()*(system.global_transform*pose.origin)
		var flat:=Vector2(point.x,point.z)
		var clearance: float=system.card_clearance(flat,Vector2i(flat.round()))
		check(pose.basis.x.length()*.707107<=clearance+.002,"Whole card corners stay inside coverage and structural boundaries")
		var normal: Vector3=(system.global_basis*pose.basis.z).normalized()
		check(normal.dot(world.camera_3d.global_basis.z)>.999,"Smoke card faces the actual game camera")
	if system.clouds.size()>2:
		var heights: Array=[]
		for cloud in system.clouds:heights.append(float(cloud.height))
		heights.sort()
		check(heights[-1]-heights[0]>1.0,"Smoke fills multiple heights instead of one repeated tile plane")
	var timings: Array[float]=[]
	for i in 120:
		var started:=Time.get_ticks_usec()
		system.advance(1.0/60.0)
		timings.append(float(Time.get_ticks_usec()-started)/1000.0)
	timings.sort()
	print("EXTINGUISHER_CPU manual_step_median_ms=",timings[60]," p95_ms=",timings[114]," active_clouds=",system.clouds.size()," cells=",system.cells.size()," scope=one_source_formal_camera_not_full_frame")
	var before_size:=0.0
	for index in bank.visible_instance_count:before_size=maxf(before_size,bank.get_instance_transform(index).basis.x.length())
	system.advance(maxf(0.0,system.DURATION-.25-float(system.sources[0].age)))
	var after_size:=0.0
	for index in bank.visible_instance_count:after_size=maxf(after_size,bank.get_instance_transform(index).basis.x.length())
	check(after_size<before_size*.8,"Late smoke contracts whole cards instead of clipping the outer rim")
	await shot("smoke_cards_dissipating")
	system.advance(12)
	await shot("smoke_cleared")
	check(not bridge.lit_material.get_shader_parameter("smoke_silhouette"),"Clearing gas restores original player materials")
	check(bridge.lit_material.get_shader_parameter("enemy_rim_enabled"),"Player white outline returns after gas clears")
	check(system.hidden_enemies.is_empty() and not tank.smoke_silhouette,"Expiration clears enemy concealment and cylinder silhouette together")
	main.free();await frames(3)
	print("FIRE_EXTINGUISHER_GPU checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
