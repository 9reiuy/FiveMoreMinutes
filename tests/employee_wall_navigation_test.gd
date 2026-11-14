extends SceneTree
## Real Employee steering, real floor policy and swept CharacterBody collisions.
const LAB := preload("res://scenes/testing/LabWorld.tscn")
const ENEMY := preload("res://scenes/entities/employee_enemy.tscn")
const CONFIG := preload("res://resources/demo_config.tres")
var world: Node3D
var failures: Array[String] = []
var results: Dictionary = {}
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL ", label)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func wall(center: Vector2, dimensions: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 4; body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new(); rect.size = dimensions; shape.shape = rect
	body.add_child(shape); world.collision_root.add_child(body); body.position = center
	return body

func actor(point: Vector2) -> EmployeeEnemy:
	var enemy := ENEMY.instantiate() as EmployeeEnemy
	world.enemy_root.add_child(enemy)
	enemy.position = point
	enemy.configure(world.player, 1000, 96, world._room_bounds_pixels(1, 2), 0, 16, CONFIG)
	enemy.set_meta(&"dream_room_id", 1)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy

func run() -> void:
	var time_control := root.get_node_or_null("TimeController")
	if time_control != null:
		time_control.end_tactical_planning()
		time_control.set_slow_time_enabled(false)
	Engine.time_scale = 1.0
	world = LAB.instantiate()
	world.generate_on_ready = false; world.spawn_content = false
	world.persist_profile = false; world.lab_furniture = false
	world.lab_enemy_count = 0; world.lab_whitebox = true
	root.add_child(world)
	await frames(2)
	check(world.regenerate(71432), "lab generation")
	world.player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	world.player.global_position = Vector2(11,11) * 32
	var goal := Vector2(11,7)*32
	var obstacles: Array[StaticBody2D] = [
		wall(Vector2(9,7)*32, Vector2(12,140)),
		wall(Vector2(7,5)*32, Vector2(140,12)),
		wall(Vector2(7,9)*32, Vector2(140,12)),
	]
	await frames(3)
	var enemy := actor(Vector2(7,7)*32)
	var trace: Array = []
	var max_step := 0.0
	var reached := false
	var previous := enemy.position
	for i in 720:
		# Isolate the actual locomotion seam; advance its normal commit clock.
		enemy.steering_commit_left = maxf(0,enemy.steering_commit_left - 1.0/60)
		enemy.velocity = enemy._steer_toward(goal)
		enemy.move_and_slide()
		await frames(1)
		max_step = maxf(max_step,enemy.position.distance_to(previous))
		previous = enemy.position
		if i % 6 == 0: trace.append([enemy.position.x,enemy.position.y])
		if enemy.position.distance_to(goal) < 8:
			reached = true; break
	results["u_trap"] = {"reached":reached,"end":[enemy.position.x,enemy.position.y],"max_step":max_step,"trace":trace}
	check(reached,"escape concave U and reach remembered target")
	check(max_step < 8,"continuous motion without teleport")
	enemy.free()
	if reached:
		# The same trap with the actual attack/search state machine and timers.
		world.player.global_position = goal
		world.player.invulnerability_left = 100
		enemy = actor(Vector2(7,7)*32)
		enemy.equip_weapon("books")
		enemy.hostile = true; enemy.state = EmployeeEnemy.State.ATTACK_PLAYER
		enemy.has_last_known_target_position = true
		enemy.last_known_target_position = goal; enemy.last_known_room = 1
		enemy.can_see_target = false
		enemy.set_process(true); enemy.set_physics_process(true)
		var ai_reached := false
		for i in 720:
			await frames(1)
			if enemy.position.distance_to(goal) < 48: ai_reached = true; break
		results["actual_attack_ai"] = {"reached":ai_reached,"state":enemy.state,"end":[enemy.position.x,enemy.position.y]}
		check(ai_reached,"real hostile search state escapes U")
		enemy.free()
	for obstacle in obstacles: obstacle.free()
	await frames(2)
	if reached:
		enemy = actor(Vector2(4,7)*32)
		# Endpoints clear, but a thin wall blocks the swept body in between.
		var thin := wall(Vector2(5,7)*32,Vector2(2,80))
		await frames(2)
		check(world.is_employee_position_clear(Vector2(6,7)*32,enemy),"endpoint beyond thin wall is free")
		check(not world.is_employee_path_clear(enemy.position,Vector2(6,7)*32,enemy),"sweep rejects crossing thin wall")
		enemy.steering_waypoint = Vector2(6,7)*32; enemy.steering_commit_left = 0.4
		var velocity := enemy._steer_toward(Vector2(6,7)*32)
		check(world.is_employee_path_clear(enemy.position,enemy.position+velocity*0.12,enemy),"stale local commitment is revalidated")
		thin.free(); await frames(2)
		check(world.get_employee_navigation_target(enemy,Vector2(6,7)*32) == Vector2(6,7)*32,"breached wall permits new direct route")
		var furniture := wall(Vector2(5,7)*32,Vector2(32,96)); furniture.collision_layer = 8
		await frames(2)
		var detour: Vector2 = world.get_employee_navigation_target(enemy,Vector2(6,7)*32)
		check(detour != Vector2(6,7)*32 and world.is_employee_path_clear(enemy.position,detour,enemy),"new furniture invalidates cached direct route")
		var outside := Vector2(-500,-500)
		var safe: Vector2 = world.get_employee_navigation_target(enemy,outside)
		check(safe != outside and world.is_employee_position_clear(safe,enemy),"unreachable void target holds at legal floor")
		furniture.free(); await frames(2)
		enemy.state = EmployeeEnemy.State.ATTACK_PLAYER; enemy.attack_movement_intent = true
		enemy.has_last_known_target_position = true; enemy.last_known_target_position = enemy.position+Vector2(0,-80)
		enemy.stuck_anchor = enemy.position-Vector2(5,0)
		enemy.navigation_progress_waypoint = enemy.last_known_target_position
		enemy.stuck_progress_waypoint = enemy.navigation_progress_waypoint
		enemy.stuck_progress_distance = 80.15
		world.employee_path_cache[enemy.get_instance_id()] = {"watchdog_marker":true}
		enemy._update_stuck_detection(0.6)
		check(not world.employee_path_cache.get(enemy.get_instance_id(),{}).has("watchdog_marker"),"sideways wall jitter does not count as route progress")
		enemy.state = EmployeeEnemy.State.MOVE_TO_DOOR
		enemy.route_approach_point = enemy.position
		enemy.door_transit_granted = false
		enemy._update_stuck_detection(0.6)
		check(enemy.state == EmployeeEnemy.State.MOVE_TO_DOOR,"intentional doorway queue wait is not treated as stuck")
		# A narrow opening that fits the actual 14px feet collider.
		var upper := wall(Vector2(6,5)*32-Vector2(0,3),Vector2(12,110))
		var lower := wall(Vector2(6,9)*32-Vector2(0,3),Vector2(12,110))
		await frames(2)
		check(world.is_employee_path_clear(Vector2(5,7)*32,Vector2(7,7)*32,enemy),"18px opening fits the real offset collider")
		upper.free(); lower.free(); enemy.free()
		# The independent robot route must sweep between its free grid nodes too.
		world.player.position = Vector2(11,11)*32
		var robot = preload("res://scripts/entities/hotel_robot_unit.gd").new()
		world.enemy_root.add_child(robot)
		robot.position = Vector2(4,7)*32
		robot.configure(world,world.player,world._room_bounds_pixels(1,2))
		robot.set_physics_process(false)
		var robot_wall := wall(Vector2(144,224),Vector2(2,80))
		await frames(2)
		var robot_nav = preload("res://scripts/dream/units/robot_navigation.gd")
		check(robot_nav.clear(robot,Vector2(160,224)),"robot endpoint is free beyond thin wall")
		check(not robot_nav.segment_clear(robot,robot.position,Vector2(160,224)),"robot sweep catches wall between grid nodes")
		var robot_path: Array[Vector2] = robot_nav.path(robot,Vector2(192,224))
		check(not robot_path.is_empty(),"robot finds a detour around thin wall")
		var robot_previous: Vector2 = robot.position
		for point in robot_path:
			check(robot_nav.segment_clear(robot,robot_previous,point),"robot path segment is body-clear")
			robot_previous = point
		robot_wall.free(); robot.free()
		results["searches"] = world._employee_navigation.searches
		results["sweep_queries"] = world._employee_navigation.sweep_queries
		var old_graph_id: int = world._employee_navigation.graph.get_instance_id()
		var old_floor: int = world._layout_generation
		check(world.regenerate(71433),"repeat lab floor generation")
		check(world.employee_path_cache.is_empty(),"floor reset releases old actor routes")
		check(world._layout_generation != old_floor,"new floor owns a fresh generation token")
		enemy = actor(Vector2(4,7)*32)
		var reset_wall := wall(Vector2(5,7)*32,Vector2(2,80))
		await frames(2)
		world.get_employee_navigation_target(enemy,Vector2(6,7)*32)
		check(world._employee_navigation.floor_revision == world._layout_generation,"navigation graph follows regenerated floor")
		check(world._employee_navigation.graph.get_instance_id() != old_graph_id,"old graph is replaced after reset")
		reset_wall.free(); enemy.free()
	var output := "res://.runtime/navigation_20261113/candidate.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"results":results,"failures":failures},"\t")); file.close()
	print("WALL NAVIGATION ",JSON.stringify({"checks":checks,"results":results.keys(),"failures":failures,"u_reached":reached,"end":previous}))
	world.free(); await frames(4)
	quit(0 if failures.is_empty() else 1)
