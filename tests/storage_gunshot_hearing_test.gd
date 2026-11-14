extends SceneTree
## Real 0-3 geometry, actors, physical service door and production sound event.
const WORLD := preload("res://scenes/testing/LinkedMaintenanceGarage.tscn")
var world: Node3D
var checks := 0
var failures: Array[String] = []
var evidence: Array = []
var label := "candidate"

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); print("FAIL ",text)

func frames(n: int) -> void:
	for i in n:
		await physics_frame; await process_frame

func guard(name: String, local_position: Vector2) -> EmployeeEnemy:
	var point := (local_position+Vector2(world.STORAGE_OFFSET))*32.0
	var enemy: EmployeeEnemy = world._spawn_regular_employee(world.STORAGE_ROOM_ID,point,&"employee",false,"basic")
	enemy.name = name
	enemy.set_room_runtime_active(true)
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	reset(enemy)
	return enemy

func reset(enemy: EmployeeEnemy) -> void:
	enemy.hostile = false; enemy.can_see_target = false
	enemy.state = EmployeeEnemy.State.NEUTRAL_WANDER
	enemy.has_last_known_target_position = false
	enemy.gunshot_investigate_left = 0; enemy.gunshot_source_room_id = -1
	enemy.gunshot_threat_position = Vector2.ZERO; enemy.panic_decision_room_id = -1
	enemy.velocity = Vector2.ZERO

func door_pose(angle: float) -> void:
	var door: PhysicalDoor3D = world._storage_door
	door.set_physics_process(false)
	for leaf in door._leaves:
		leaf.freeze = true; leaf.angular_velocity = Vector3.ZERO
		leaf.rotation.y = angle
	door._sync_gameplay_collision()

func shoot(at: Vector2, guards: Array[EmployeeEnemy], event_name: String) -> void:
	for enemy in guards: reset(enemy)
	world.notify_gunshot((at+Vector2(world.STORAGE_OFFSET))*32.0,world.STORAGE_ROOM_ID)
	var states: Dictionary = {}
	for enemy in guards: states[enemy.name] = {"state":enemy.state,"heard":enemy.gunshot_investigate_left>0,"hostile":enemy.hostile,"knows_player":enemy.has_last_known_target_position}
	evidence.append({"event":event_name,"door_angle":world._storage_door.get_open_angle(),"states":states})

func run() -> void:
	var folder := "res://.runtime/storage_hearing_20261113"
	DirAccess.make_dir_recursive_absolute(folder)
	world = WORLD.instantiate(); world.generate_on_ready = false
	world.spawn_content = false; world.persist_profile = false
	root.add_child(world); await frames(2)
	check(world.regenerate(31113),"linked level generation")
	# Complete the real 0-1 slow-time lifecycle before testing later-level AI.
	world._finish_opening_time()
	world.player.set_physics_process(false)
	world.player.invulnerability_left = 1000
	world.player.position = (Vector2(world.STORAGE_OFFSET)+Vector2(3,5))*32
	world._arrive_in_storage()
	world.current_room_id = world.STORAGE_ROOM_ID
	world.player_has_left_elevator_cab = true
	world.set_physics_process(false)
	Engine.time_scale = 1
	var corridor := guard("CorridorGuard",Vector2(3,4))
	var inside := guard("StockroomGuard",Vector2(10,-1))
	var exit_guard := guard("ExitPassageGuard",Vector2(23,2))
	var actors: Array[EmployeeEnemy] = [corridor,inside,exit_guard]
	door_pose(0); await frames(3)
	check(is_equal_approx(Engine.time_scale,1.0),"0-3 AI runs at normal time after opening lifecycle")
	check(world._room_id_at_position(corridor.position) == world._room_id_at_position(inside.position),"corridor and stockroom currently share one logical room id")
	check(not inside._has_target_line_of_sight(world.player.position),"closed real wall / door prevents visual acquisition")
	shoot(Vector2(3,5),actors,"closed_door_corridor_shot")
	check(corridor.gunshot_investigate_left>0,"corridor guard hears a shot on its own side")
	check(inside.gunshot_investigate_left==0,"closed service door blocks corridor gunshot from stockroom")
	check(exit_guard.gunshot_investigate_left==0,"exit passage belongs to stockroom side of service door")
	check(not inside.hostile and not inside.has_last_known_target_position,"blocked gunshot reveals no Player target")
	for enemy in actors: reset(enemy)
	world.player.configure_weapon("basic",world.config,{})
	world.player.weapon_fired.emit(1.0)
	check(corridor.gunshot_investigate_left>0 and inside.gunshot_investigate_left==0,"actual Player weapon-fired event respects closed door")
	var station: Array[Vector2] = [inside.position]
	inside.set_authored_patrol_route(station)
	inside.process_mode = Node.PROCESS_MODE_INHERIT
	inside.set_process(true); inside.set_physics_process(true)
	await frames(45)
	check(inside.state == EmployeeEnemy.State.NEUTRAL_WANDER and not inside.hostile,"running AI remains neutral after closed-door corridor fire")
	check(inside.position.distance_to(station[0])<4.0,"stockroom guard does not start following from closed-door sound")
	inside.process_mode = Node.PROCESS_MODE_DISABLED
	shoot(Vector2(10,-1),actors,"closed_door_stockroom_shot")
	check(inside.gunshot_investigate_left>0 and exit_guard.gunshot_investigate_left>0,"stockroom and exit passage hear each other")
	check(corridor.gunshot_investigate_left==0,"closed door blocks sound in reverse direction")
	door_pose(deg_to_rad(0.5)); await frames(2)
	shoot(Vector2(3,4),actors,"closed_door_small_hinge_jitter")
	check(inside.gunshot_investigate_left==0,"small closed-door hinge jitter does not open hearing")
	door_pose(PI*0.5); await frames(2)
	shoot(Vector2(3,5),actors,"open_door_corridor_shot")
	check(inside.gunshot_investigate_left>0,"open physical door admits nearby gunshot")
	check(not inside.hostile and not inside.has_last_known_target_position,"hearing starts sound investigation without live Player lock")
	var sound := inside.gunshot_threat_position
	var search_start := inside.position
	inside.process_mode = Node.PROCESS_MODE_INHERIT
	inside.set_process(true); inside.set_physics_process(true)
	await frames(24)
	evidence.append({"event":"open_door_running_ai","start":str(search_start),"end":str(inside.position),"state":inside.state,"time_scale":Engine.time_scale})
	check(inside.position.distance_to(search_start)>8.0,"running AI can investigate after the door is opened")
	inside.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.position += Vector2(32,0)
	inside._update_investigate_gunshot()
	check(inside.gunshot_threat_position == sound,"unseen Player movement does not move recorded sound target")
	shoot(Vector2(0,0.5),actors,"open_door_range_limit")
	check(exit_guard.gunshot_investigate_left==0,"existing 700px hearing range remains enforced")
	door_pose(0); await frames(2)
	shoot(Vector2(3,4),actors,"reclosed_door_enemy_return_fire")
	check(inside.gunshot_investigate_left==0,"closing door blocks later enemy return-fire events")
	world._storage_door.shatter(Vector2.UP); await frames(2)
	shoot(Vector2(3,5),actors,"destroyed_door_corridor_shot")
	check(inside.gunshot_investigate_left>0,"destroyed door restores sound connection")
	var file := FileAccess.open(folder.path_join(label+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":evidence},"\t")); file.close()
	print("STORAGE_HEARING ",JSON.stringify({"checks":checks,"failures":failures}))
	world.free(); await frames(6)
	quit(0 if failures.is_empty() else 1)
