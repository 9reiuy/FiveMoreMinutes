extends "res://tests/forklift_revision_test.gd"
## Actual 1-2 map, ordinary player movement, and the complete production forklift hull.
var bollards: Array[StaticBody2D] = []
var drive_contacts: Array[String] = []


func enter_chapter(checkpoint: int, vehicle: Dictionary = {}) -> void:
	await super.enter_chapter(checkpoint, vehicle)
	if native:
		for i in 2400:
			if world.chapter_stream_ready and current_scene.presentation.entry_loading == null:
				break
			await physics_frame
		check(world.chapter_stream_ready and current_scene.presentation.entry_loading == null,
			"Normal scene preparation completes before the live Camera checks")
	lift = world.blockout.forklift


func walk_gap(x: float, southbound: bool) -> bool:
	var start := Vector2(x, -4.90 if southbound else -2.60)
	var goal := Vector2(x, -2.60 if southbound else -4.90)
	place_feet(start)
	await frames(2)
	for i in 120:
		var offset: Vector2 = goal - world._feet()
		if offset.length() < 0.14:
			world.player.clear_scripted_locomotion()
			return true
		world.player.set_scripted_locomotion(offset.normalized(), minf(world.player.movement_speed, offset.length() * 32.0 * 20.0))
		await physics_frame
	world.player.clear_scripted_locomotion()
	return false


func drive_at(x: float, yaw: float, reverse := false, boosted := false) -> void:
	park(Vector2(x, -7.50), yaw)
	await frames(2)
	if not is_instance_valid(lift.driver):
		place_feet(Vector2(x + 1.1, -7.50))
		await frames(2)
		check(lift.board(world.player), "Forklift boards for the barrier approach")
	if boosted:
		check(lift.start_boost(), "Production Shift boost starts before the impact")
	var action := &"move_down" if reverse else &"move_up"
	Input.action_press(action)
	var furthest := -INF
	for i in 90:
		await physics_frame
		furthest = maxf(furthest, lift.global_position.y / 32.0)
		for j in lift.get_slide_collision_count():
			var hit: Object = lift.get_slide_collision(j).get_collider()
			if is_instance_valid(hit) and String(hit.name).begins_with("StairSafetyBollard"):
				drive_contacts.append(hit.name)
	Input.action_release(action)
	lift.speed = 0.0
	lift.velocity = Vector2.ZERO
	check(furthest < PLAN.WEST_STAIR_BOLLARDS[0].y - 0.30,
		"Forklift cannot cross the row at x=%.2f yaw=%.2f reverse=%s boost=%s" % [x, yaw, reverse, boosted])


func run() -> void:
	evidence = OS.get_environment("BOLLARD_EVIDENCE")
	if evidence.is_empty(): evidence = "res://.runtime/h06_bollards_20261117"
	DirAccess.make_dir_recursive_absolute(evidence)
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or root.get_node("SettingsManager").get_volume(&"master_volume") != 0:
		AudioServer.set_bus_mute(0, true)
		quit(2)
		return
	native = DisplayServer.get_name() != "headless"
	if native: preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(180, true, false, true).timeout.connect(func(): quit(3))
	root.get_node("DreamTimeController").slow_time_enabled = false
	Engine.time_scale = 1.0
	await enter_chapter(CHAPTER.Save.PUMP)
	world.stage = CHAPTER.Stage.RETURN
	world.blockout.set_gate("pump", false)
	for unit in world.enemy_root.get_children(): unit.set_physics_process(false)
	for body in world.blockout.upper_bodies:
		if String(body.name).begins_with("StairSafetyBollard"): bollards.append(body)
	check(bollards.size() == 6, "Six independent physical posts stand at the staircase mouth")
	var mesh: MeshInstance3D = world.blockout.floor_root.get_node("StairSafetyBollards")
	check(mesh.mesh.get_aabb().position.y >= 3.04 and mesh.mesh.get_surface_count() == 3,
		"Black steel, yellow bands and bolts share one baked mesh on the actual upper floor")
	var radius: float = world.player.body_collision.shape.radius / 32.0
	for i in bollards.size():
		check(bollards[i].global_position.is_equal_approx(PLAN.WEST_STAIR_BOLLARDS[i] * 32.0)
			and bollards[i].get_child(0).shape is CircleShape2D
			and is_equal_approx(bollards[i].get_child(0).shape.radius, PLAN.WEST_BOLLARD_RADIUS * 32.0),
			"Post %d collision matches its visible footplate" % i)
	for i in PLAN.WEST_STAIR_BOLLARDS.size() - 1:
		var x: float = (PLAN.WEST_STAIR_BOLLARDS[i].x + PLAN.WEST_STAIR_BOLLARDS[i + 1].x) * 0.5
		var gap: float = PLAN.WEST_STAIR_BOLLARDS[i + 1].x - PLAN.WEST_STAIR_BOLLARDS[i].x - 2.0 * PLAN.WEST_BOLLARD_RADIUS
		check(gap > radius * 2.0 and gap < MODEL.OUTER_WIDTH, "Gap %d has genuine pedestrian-only width" % i)
		check(await walk_gap(x, true), "Player walks south through gap %d" % i)
		check(await walk_gap(x, false), "Player walks north through gap %d" % i)
	place_feet(Vector2(-19.1, -5.0))
	world.player.set_scripted_locomotion(Vector2.DOWN, world.player.movement_speed)
	await frames(45)
	world.player.clear_scripted_locomotion()
	check(world._feet().y < -4.10, "Player also collides with the posts themselves")
	place_feet(Vector2(-18.5, -5.25))
	await frames(40)
	if native:
		if is_instance_valid(root.get_node("PerformanceMonitor").hud_root): root.get_node("PerformanceMonitor").hud_root.hide()
		await capture("01-pedestrian-passage")
	for i in PLAN.WEST_STAIR_BOLLARDS.size() - 1:
		var x: float = (PLAN.WEST_STAIR_BOLLARDS[i].x + PLAN.WEST_STAIR_BOLLARDS[i + 1].x) * 0.5
		await drive_at(x, PI * 0.5)
	await drive_at(-18.5, PI * 0.5, false, true)
	if native: await capture("02-forklift-stopped")
	await drive_at(-18.5, -PI * 0.5, true)
	for angle in [-0.35, 0.35]:
		await drive_at(-18.5, PI * 0.5 + angle)
	check(not drive_contacts.is_empty(), "Vehicle contacts the actual posts, rather than a floor-support boundary")
	# The complete chassis cannot slip between the posts at any orientation.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = lift.get_node("CollisionShape2D").shape
	query.exclude = [lift.get_rid(), world.player.get_rid()]
	query.collision_mask = lift.collision_mask
	for i in PLAN.WEST_STAIR_BOLLARDS.size() - 1:
		var x: float = (PLAN.WEST_STAIR_BOLLARDS[i].x + PLAN.WEST_STAIR_BOLLARDS[i + 1].x) * 0.5
		for yaw in [0.0, PI / 6, PI / 3, PI / 2]:
			query.transform = Transform2D(yaw, Vector2(x, -6.8) * 32.0)
			query.motion = Vector2(0, 5.0) * 32.0
			var fractions := lift.get_world_2d().direct_space_state.cast_motion(query)
			check(fractions[0] < 0.99, "Swept chassis remains blocked at gap %d angle %.2f" % [i, yaw])
	park(Vector2(-18.5, -7.5))
	check(lift.try_exit(), "Driver can dismount after stopping at the row")
	check(await walk_gap(-18.5, true), "Dismounted driver walks through the same row")
	world._set_lower(true)
	check(bollards.all(func(body: StaticBody2D): return body.collision_layer == 0), "Upper posts never block the lower storey")
	world._set_lower(false)
	world.blockout.set_live(false)
	check(bollards.all(func(body: StaticBody2D): return body.collision_layer == 0), "Streamed-out geometry releases its physics")
	world.blockout.set_live(true)
	check(bollards.all(func(body: StaticBody2D): return body.collision_layer == world.blockout.ACTOR_EDGE), "Reactivated geometry restores individual collisions")
	var old_row: WeakRef = weakref(mesh)
	await enter_chapter(CHAPTER.Save.PUMP)
	var rebuilt: Array = world.blockout.upper_bodies.filter(func(body: StaticBody2D): return String(body.name).begins_with("StairSafetyBollard"))
	check(not is_instance_valid(old_row.get_ref()) and rebuilt.size() == 6, "Retry builds exactly one clean six-post row")
	var report := {"checks": checks, "failures": failures, "contact_posts": drive_contacts,
		"gap_metres": 0.8, "forklift_width_metres": MODEL.OUTER_WIDTH,
		"renderer": RenderingServer.get_current_rendering_method(), "audio": AudioServer.get_driver_name(),
		"pid": OS.get_process_id(), "scope": "Actual chapter 1-2 entrance and staircase, original player and forklift physics. Native mode also captures the production Camera."}
	FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	current_scene.queue_free()
	await frames(8)
	print("PEDESTRIAN_BOLLARDS checks=", checks.size(), " failures=", failures.size(), " pid=", OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
