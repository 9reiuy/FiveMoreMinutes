extends SceneTree
## Basement contract: prefired bullet, poster-only .05 opening until first death,
## industrial equipment, five cold pools and a moving bounded exit gunner.
var checks: Array[Dictionary]=[]
var artifact_dir := "res://.runtime/megastructure_rebuild_20261107/validation"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): artifact_dir=argument.trim_prefix("--artifact-dir=")
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks.append({"pass":condition,"description":description})
	print("PASS: " if condition else "FAIL: ",description)

func _check_wall_faces(world: Node3D) -> void:
	var correct_winding := true
	var outward_normals := true
	for title in ["NorthContour","SouthContour"]:
		var wall: MeshInstance3D=world.wall_root.get_node(title)
		var body: Node=world.collision_root.get_node(title)
		var polygon: PackedVector2Array=body.get_meta(&"whitebox_contour")
		for surface in wall.mesh.get_surface_count():
			var arrays := wall.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for index in range(0,vertices.size(),3):
				var a := vertices[index];var b := vertices[index+1];var c := vertices[index+2]
				var normal := normals[index]
				correct_winding=correct_winding and (b-a).cross(c-a).dot(normal)<-.00001
				if absf(normal.y)>.5:outward_normals=outward_normals and normal.dot(Vector3.UP)>.99
				else:
					var center := (a+b+c)/3.0
					var outside := Vector2(center.x+normal.x*.02,center.z+normal.z*.02)
					outward_normals=outward_normals and not Geometry2D.is_point_in_polygon(outside,polygon)
	check(correct_winding,"Wall front-face winding agrees with lighting normals")
	check(outward_normals,"Wall sides point out of solid geometry and wall caps face upward")
	for title in ["LeftBoundary","RightBoundary"]:
		check(world.collision_root.has_node(title) and not world.wall_root.has_node(title),
			"%s retains only its invisible boundary at the faded opening" % title)

func _run() -> void:
	await process_frame
	var master := AudioServer.get_bus_index(&"Master")
	check(master>=0 and AudioServer.is_bus_mute(master),"Private Master=0 before scene entry")
	if master<0 or not AudioServer.is_bus_mute(master):
		if master>=0: AudioServer.set_bus_mute(master,true)
		quit(1);return
	var display: Node=load("res://scenes/testing/MegastructureWhiteboxDisplay.tscn").instantiate()
	root.add_child(display);current_scene=display
	for frame in 8: await process_frame
	var world: Node3D=display.world
	var player: CharacterBody2D=world.player
	player.dash_invulnerability_left=100.0
	check(bool(world.last_validation_report.get("valid",false)),"Actual floor and room connectivity")
	check(world.building_rect.size==Vector2i(38,12) and world.rooms.size()==3 and world.connections.size()==2,"Original-size 38x12 m, three phases and one continuous route")
	_check_wall_faces(world)
	check(player.global_position.x<4*32 and world.enemy_root.get_child_count()==5,"Left-side spawn and five production enemies")
	check(player.get_script().resource_path=="res://scripts/entities/dream_player.gd","Production DreamPlayer")
	check(player.selected_weapon_id=="books" and player.melee_weapon_id=="books" and player.ranged_weapon_id.is_empty(),"Poster is the only starting weapon; no hidden firearm")
	check(is_equal_approx(Engine.time_scale,.05),"Opening runs at exactly x0.05")
	check(is_instance_valid(world.opening_projectile) and bool(world.opening_projectile.get_meta(&"whitebox_prefired",false)) and world.opening_enemy.current_ammo<12,"First rendered state contains a genuine enemy bullet already in flight")
	check(is_equal_approx(world.opening_projectile.speed,world.config.basic_projectile_speed*.2) and world.opening_enemy.feedback_config!=world.config,"Only the opening enemy's native projectile runs at 20 percent of baseline speed")
	var projectile_speeds := {"opening_native_shot":float(world.opening_projectile.speed),"shared_baseline":float(world.config.basic_projectile_speed),"exit_guard":float(world.exit_guard.feedback_config.basic_projectile_speed),"player":float(player.auto_weapon.projectile_speed)}
	check(is_equal_approx(world.exit_guard.feedback_config.basic_projectile_speed,world.config.basic_projectile_speed) and is_equal_approx(player.auto_weapon.projectile_speed,world.config.basic_projectile_speed),"Exit guard, player and shared world retain their original projectile speed")
	var cold_lights: Array=world.ceiling_light_root.find_children("ColdPool","OmniLight3D",true,false)
	check(cold_lights.size()==5 and cold_lights.all(func(light):return light.visible and light.light_color.b>light.light_color.r),"Exactly five visible cold local light pools")
	var environment: Environment=world.get_node("Lighting/WorldEnvironment").environment
	check(environment.ambient_light_energy<.1 and world.sparse_lighting==null and world.shadow_manager.sun==null,"Dark ambient and no office directional fill or exterior moon")
	check(world.furniture_root.get_child_count()==6 and world.furniture_root.get_children().all(func(prop):return prop.has_meta(&"maintenance_kind") and not prop.has_meta(&"office_furniture_kind")),"Six authored maintenance props; no office furniture")
	var floor_material: Material=world.floor_root.get_node("WhiteboxFloor_entry").material_override
	check(floor_material is ShaderMaterial and float(floor_material.get_shader_parameter("wetness"))>.5,"Concrete floor has roughness variation and wet specular response")
	# Picking up a disarmed gun while the first enemy is alive must retain slow time.
	world._spawn_room_drop(0,{"type":&"weapon","weapon_id":"basic","ground_position":player.global_position},world._layout_generation)
	var probe_gun: Node2D=null
	for pickup in world.world_weapon_root.get_children():
		if String(pickup.weapon_id)=="basic":probe_gun=pickup;break
	if is_instance_valid(probe_gun):world._swap_world_weapon(probe_gun)
	check(player.selected_weapon_id=="basic" and not world.opening_enemy.dead and not world.opening_complete and is_equal_approx(Engine.time_scale,.05),"Gun pickup alone does not release x0.05 while the first enemy lives")
	if player.selected_weapon_id!="basic" or world.opening_complete or not is_equal_approx(Engine.time_scale,.05):print("PICKUP_PROBE weapon=",player.selected_weapon_id," dead=",world.opening_enemy.dead," complete=",world.opening_complete," scale=",Engine.time_scale," gun=",is_instance_valid(probe_gun))
	world.restart_current_floor_after_death()
	for frame in 8:await process_frame
	player.dash_invulnerability_left=100.0
	check(display.world_viewport.size==Vector2i(640,360),"Production 640x360 pixel display")
	var melee: Array=[]
	var initial_x: Array[float]=[]
	for enemy in world.enemy_root.get_children():
		if int(enemy.get_meta(&"dream_room_id",-1))==1:
			melee.append(enemy);initial_x.append(enemy.global_position.x)
	check(melee.size()==3 and melee.all(func(enemy):return not enemy.held_weapon_id.is_empty() and enemy._weapon_is_melee()),"All three corridor enemies start with melee weapons")
	for frame in 75: await physics_frame
	var all_approach := true
	for index in melee.size(): all_approach=all_approach and melee[index].global_position.x<initial_x[index]-.1
	check(all_approach,"All three melee enemies advance toward the player from the start")
	check(is_equal_approx(Engine.time_scale,.05),"Time remains x0.05 while the first enemy lives")
	# Exercise the same extraction, signal, thrown pickup and collision path as RMB.
	var target: EmployeeEnemy=world.opening_enemy
	player.last_aim_direction=player.global_position.direction_to(target.global_position)
	var throw_data: Dictionary=player.take_active_weapon_for_throw()
	throw_data.direction=player.global_position.direction_to(target.global_position)
	player.weapon_drop_requested.emit(throw_data)
	check(player.is_empty_handed(),"Throwing the poster leaves the player empty handed")
	var gun: Node2D=null
	for frame in 1000:
		await physics_frame
		for pickup in world.world_weapon_root.get_children():
			if bool(pickup.get_meta(&"whitebox_opening_gun",false)): gun=pickup;break
		if is_instance_valid(gun):break
	check(is_instance_valid(gun),"Native thrown poster disarms the opening enemy and drops its gun")
	check(bool(world.opening_complete)==bool(target.dead),"Slow-motion completion follows first-enemy death rather than disarm or pickup")
	if not target.dead:target.take_damage(target.maximum_health,player.global_position,0.0,&"whitebox_validation")
	for frame in 3:await process_frame
	if not is_equal_approx(Engine.time_scale,1.0):
		var clock: Node=world._get_dream_time_controller()
		print("OPENING_CLOCK scale=",Engine.time_scale," planning=",clock.tactical_planning_active," slow=",clock.slow_time_enabled," reaction=",clock.reaction_remaining_real," hitstop=",clock.hitstop_active," dead=",target.dead)
	check(world.opening_complete and is_equal_approx(Engine.time_scale,1.0),"First-enemy death restores x1.0 before collecting the gun")
	if is_instance_valid(gun):
		player.global_position=gun.global_position
		for frame in 100:
			await physics_frame
			if world.opening_gun_collected:break
	check(world.opening_gun_collected and player.selected_weapon_id=="basic","Walking over the real dropped gun commits pickup")
	for frame in 5:await process_frame
	check(is_equal_approx(Engine.time_scale,1.0),"Gun pickup after the first kill preserves x1.0 speed")
	# Final shooter uses real perception and firing while its movement is bounded.
	var guard: EmployeeEnemy=world.exit_guard
	player.global_position=Vector2(25.5,5.5)*32.0
	var minimum_guard_x := guard.global_position.x
	var guard_origin := guard.global_position
	var guard_displacement := 0.0
	var guard_fired := false
	var guard_original_speed := true
	for frame in 300:
		await physics_frame
		minimum_guard_x=minf(minimum_guard_x,guard.global_position.x)
		guard_displacement=maxf(guard_displacement,guard_origin.distance_to(guard.global_position))
		for projectile in get_nodes_in_group(&"dream_projectiles"):
			if int(projectile.shooter_instance_id)==guard.get_instance_id():
				guard_fired=true
				guard_original_speed=guard_original_speed and is_equal_approx(projectile.speed,world.config.basic_projectile_speed)
	check(guard_fired,"Exit guard fires native projectiles into the corridor")
	check(guard_fired and guard_original_speed,"Live exit-guard shots retain their original speed")
	if not guard_fired:print("GUARD_PROBE state=",guard.state," seen=",guard.can_see_target," active=",guard.room_runtime_active," physics=",guard.is_physics_processing()," pos=",guard.global_position," ammo=",guard.current_ammo," cooldown=",guard.attack_cooldown_left," reaction=",guard.reaction_left," windup=",guard.ranged_attack_windup_pending," time=",Engine.time_scale)
	check(minimum_guard_x>=30.75*32.0-.1 and guard.movement_speed>0.0 and guard_displacement>12.0,"Exit guard moves and fires inside the right arena without entering the narrow corridor")
	world._begin_elevator_entry_transition()
	var corridor_blocked: bool = not world.level_cleared
	player.global_position=Vector2(36,5.5)*32.0
	world._begin_elevator_entry_transition()
	check(corridor_blocked and world.level_cleared,"Only the right-side exit finishes the level; no added return or clear-all gate")
	world.level_cleared=false
	player.global_position=Vector2(25.5,5.5)*32.0
	var routes: Dictionary=await preload("res://tools/verify_all_whitebox_routes.gd").verify(world)
	for route in routes.routes:check(bool(route.pass),"Physical route: "+String(route.name))
	check(bool(routes.no_void_escape),"Outer wall prevents walking into the void")
	for enemy in world.enemy_root.get_children():
		if not enemy.dead:enemy.take_damage(10000.0,player.global_position,0.0,&"whitebox_validation")
	for frame in 8:await process_frame
	player.global_position=Vector2(36,5.5)*32.0
	world._begin_elevator_entry_transition()
	check(world.level_cleared and world.floor_index==0,"Right-side exit finishes this level without a return journey")
	var restarted: bool=world.restart_current_floor_after_death()
	for frame in 8:await process_frame
	check(restarted and not world.level_cleared and not world.opening_complete and world.enemy_root.get_child_count()==5,"Restart recreates the original five-enemy opening")
	check(player.selected_weapon_id=="books" and player.ranged_weapon_id.is_empty() and is_equal_approx(Engine.time_scale,.05),"Restart restores poster-only inventory and x0.05 time")
	check(is_instance_valid(world.opening_projectile) and is_equal_approx(world.opening_projectile.speed,world.config.basic_projectile_speed*.2),"Restart keeps exactly 20 percent of baseline speed without compounding the multiplier")
	var opening_clock: Node=world._get_dream_time_controller()
	opening_clock.begin_reaction_time(&"near_miss")
	world.opening_enemy.take_damage(world.opening_enemy.maximum_health,player.global_position,0.0,&"whitebox_validation")
	# Visible text owns an absolute .05 override until its real-time card ends.
	if is_instance_valid(world.run_interface.player_cue) and world.run_interface.player_cue.active:
		await world.run_interface.player_cue.cue_finished
	for frame in 3:await process_frame
	check(world.opening_complete and not opening_clock.is_reaction_time_active() and is_equal_approx(Engine.time_scale,1.0),"First death clears a pending opening near-miss slowdown and restores x1.0")
	var report := {"pid":OS.get_process_id(),"audio_driver":AudioServer.get_driver_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"checks":checks,"routes":routes,"projectile_speeds":projectile_speeds,
		"scope":"Headless native gameplay integration; AI isolated only for physical routes; no performance claim"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir))
	var file := FileAccess.open(artifact_dir.path_join("validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	var failed := checks.filter(func(item):return not item.pass).size()
	print("WHITEBOX_RESULT checks=%d failures=%d PID=%d" % [checks.size(),failed,OS.get_process_id()])
	current_scene=null;display.queue_free()
	for frame in 8:await process_frame
	quit(1 if failed else 0)
