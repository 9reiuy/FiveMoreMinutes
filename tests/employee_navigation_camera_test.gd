extends "res://tests/employee_wall_navigation_test.gd"
## Independent lab, production Camera/art, no changes to campaign entrances.
var display: Control
var old_cache: Dictionary = {}
var old_ray := PhysicsRayQueryParameters2D.new()

func wall(center: Vector2, dimensions: Vector2) -> StaticBody2D:
	var result := super.wall(center,dimensions)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(dimensions.x/32.0,0.72,dimensions.y/32.0)
	var material := StandardMaterial3D.new(); material.albedo_color = Color("667687"); material.roughness = 0.9
	visual.mesh = mesh; visual.material_override = material
	world.add_child(visual); visual.position = Vector3(center.x/32.0,0.36,center.y/32.0)
	return result

func actor(point: Vector2) -> EmployeeEnemy:
	var enemy := super.actor(point)
	# Room activation may re-enable individual callbacks. Freeze the node while
	# retaining its real collision body, until this fixture explicitly starts it.
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	world.register_depth_visual(enemy,[^"Shadow",^"CharacterVisual",^"WeaponRoot"])
	enemy.set_player_vision_visible(true)
	return enemy

func old_target(enemy: EmployeeEnemy, destination: Vector2) -> Vector2:
	# Exact pre-fix navigation seam for matched CPU timing, not a gameplay option.
	old_ray.collision_mask = 4; old_ray.from = enemy.position; old_ray.to = destination
	if enemy.get_world_2d().direct_space_state.intersect_ray(old_ray).is_empty(): return destination
	var start := Vector2i((enemy.position/32.0).round())
	var finish := Vector2i((destination/32.0).round())
	var id := enemy.get_instance_id()
	var now := Time.get_ticks_msec()
	var entry: Dictionary = old_cache.get(id,{})
	if entry.get("start") != start or entry.get("finish") != finish or now-int(entry.get("time",0)) > 700:
		entry = {"start":start,"finish":finish,"time":now,"path":world.find_floor_path(start,finish,false)}
		old_cache[id] = entry
	var path: Array = entry.path
	return Vector2(path[1])*32.0 if path.size()>1 else destination

func run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var time_control := root.get_node_or_null("TimeController")
	if time_control != null:
		time_control.end_tactical_planning(); time_control.set_slow_time_enabled(false)
	Engine.time_scale = 1
	var folder := "res://.runtime/navigation_20261113/camera_final"
	DirAccess.make_dir_recursive_absolute(folder)
	world = LAB.instantiate()
	world.generate_on_ready = false; world.spawn_content = false
	world.persist_profile = false; world.lab_furniture = false
	world.lab_enemy_count = 0; world.lab_whitebox = false
	var display_scene: PackedScene = load("res://scenes/dream/preview/SelectivePixelPreview.tscn")
	display = display_scene.instantiate(); display.world = world; display.preview_mode = false
	root.add_child(display)
	await frames(2)
	check(world.regenerate(71432),"production-art lab generation")
	world.populate_lab()
	world.player.set_physics_process(false); world.player.invulnerability_left = 100
	world.target_highlight.set_physics_process(false)
	world.player.position = Vector2(11,7)*32
	world._update_camera_and_actor_projection(0.0)
	var obstacles := [wall(Vector2(9,7)*32,Vector2(12,140)),wall(Vector2(7,5)*32,Vector2(140,12)),wall(Vector2(7,9)*32,Vector2(140,12))]
	var enemy := actor(Vector2(7,7)*32)
	enemy.hostile = true; enemy.equip_weapon("books")
	enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
	enemy.has_last_known_target_position = true
	enemy.last_known_target_position = world.player.position; enemy.last_known_room = 1
	await frames(40)
	check(enemy.position == Vector2(7,7)*32,"actor stays inside U throughout renderer warmup")
	var captures := 0
	var trace: Array = []
	var frame_ms: Array = []
	var capture_times_ms: Array = []
	var capture_start := Time.get_ticks_usec()
	var previous_time := Time.get_ticks_usec()
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.set_process(true); enemy.set_physics_process(true)
	var reached := false
	for i in 360:
		await frames(1)
		var now := Time.get_ticks_usec(); frame_ms.append((now-previous_time)/1000.0); previous_time = now
		if i%4 == 0:
			await RenderingServer.frame_post_draw
			capture_times_ms.append((Time.get_ticks_usec()-capture_start)/1000.0)
			display.world_viewport.get_texture().get_image().save_png(folder.path_join("%04d.png" % captures))
			captures += 1; trace.append([enemy.position.x,enemy.position.y])
		if enemy.position.distance_to(world.player.position) < 48:
			reached = true
			if captures > 50: break
	check(reached,"native real AI reaches Player around U")
	check(Vector2(trace[0][0],trace[0][1]).distance_to(Vector2(7,7)*32)<24,"recording includes the beginning inside U")
	enemy.free()
	# Same twelve stationary actors, destinations, geometry and driver. CPU
	# navigation seam only; these timings are not whole-game FPS certification.
	var actors: Array[EmployeeEnemy] = []
	for i in 12: actors.append(actor(Vector2(5.5+(i%3)*0.5,6+(i/3)*0.5)*32))
	var initial_positions: Array[Vector2] = []
	for e in actors: initial_positions.append(e.position)
	var old_us: Array = []; var new_us: Array = []
	for frame in 180:
		await frames(1)
		var elapsed: Array = [0,0]
		# Alternate order to avoid assigning the warm cache advantage to one side.
		for mode in ([0,1] if frame%2==0 else [1,0]):
			var started := Time.get_ticks_usec()
			for e in actors:
				if mode == 0: old_target(e,world.player.position)
				else: world.get_employee_navigation_target(e,world.player.position)
			elapsed[mode] = Time.get_ticks_usec()-started
		if frame >= 20: old_us.append(elapsed[0]); new_us.append(elapsed[1])
	var stationary := true
	for i in actors.size(): stationary = stationary and actors[i].position == initial_positions[i]
	check(stationary,"matched CPU actors remain stationary for the whole sample")
	var nav = world._employee_navigation
	var output := {"renderer":RenderingServer.get_current_rendering_method(),"captures":captures,"capture_times_ms":capture_times_ms,"native_reached":reached,"cpu_actors_stationary":stationary,"trace":trace,"frame_ms":frame_ms,"cpu_scope":"12 navigation requests per sample, same stationary actors and U geometry, no locomotion or GPU attribution","old_us":old_us,"new_us":new_us,"searches":nav.searches,"search_usec":nav.search_usec,"max_search_usec":nav.max_search_usec,"graph_build_usec":nav.graph_build_usec,"failures":failures}
	var file := FileAccess.open("res://.runtime/navigation_20261113/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print("NAVIGATION CAMERA ",JSON.stringify({"reached":reached,"captures":captures,"renderer":output.renderer,"failures":failures}))
	for e in actors: e.free()
	for obstacle in obstacles: obstacle.free()
	display.free(); await frames(4)
	quit(0 if failures.is_empty() else 1)
